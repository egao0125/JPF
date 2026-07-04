import { NextRequest } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/db";
import { handler, ok, parseBody, ApiError } from "@/lib/api";
import { requireUser } from "@/lib/auth";
import { rateLimit } from "@/lib/ratelimit";
import { encodeCursor, decodeCursor } from "@/lib/pagination";

const PAGE_SIZE = 50;

async function requireMembership(conversationId: string, userId: string) {
  const conversation = await prisma.conversation.findUnique({ where: { id: conversationId } });
  if (!conversation || (conversation.userAId !== userId && conversation.userBId !== userId)) {
    throw new ApiError(404, "会話が見つかりません");
  }
  return conversation;
}

// Newest page first (keyset); fetching marks the other side's messages read.
export const GET = handler(async (req: NextRequest, ctx: { params: Promise<{ id: string }> }) => {
  const user = await requireUser(req);
  const { id } = await ctx.params;
  await requireMembership(id, user.id);

  const cursor = decodeCursor(req.nextUrl.searchParams.get("cursor"));
  const where: Record<string, unknown> = { conversationId: id };
  if (cursor && cursor.length === 2) {
    const [createdAt, msgId] = [new Date(cursor[0]), cursor[1]];
    where.OR = [{ createdAt: { lt: createdAt } }, { createdAt, id: { lt: msgId } }];
  }

  let messages = await prisma.message.findMany({
    where,
    orderBy: [{ createdAt: "desc" }, { id: "desc" }],
    take: PAGE_SIZE + 1,
  });
  let nextCursor: string | null = null;
  if (messages.length > PAGE_SIZE) {
    messages = messages.slice(0, PAGE_SIZE);
    const last = messages[messages.length - 1];
    nextCursor = encodeCursor([last.createdAt.toISOString(), last.id]);
  }

  await prisma.message.updateMany({
    where: { conversationId: id, senderId: { not: user.id }, readAt: null },
    data: { readAt: new Date() },
  });

  return ok({
    messages: messages
      .reverse() // oldest-first within the page for straightforward rendering
      .map((m) => ({
        id: m.id,
        text: m.text,
        isMine: m.senderId === user.id,
        createdAt: m.createdAt.toISOString(),
      })),
    nextCursor,
  });
});

const sendSchema = z.object({ text: z.string().trim().min(1).max(1000) });

export const POST = handler(async (req: NextRequest, ctx: { params: Promise<{ id: string }> }) => {
  const user = await requireUser(req);
  rateLimit(`message:${user.id}`, 60, 60_000);
  const { id } = await ctx.params;
  await requireMembership(id, user.id);
  const { text } = await parseBody(req, sendSchema);

  const message = await prisma.message.create({
    data: { conversationId: id, senderId: user.id, text },
  });
  await prisma.conversation.update({
    where: { id },
    data: { lastMessageAt: message.createdAt },
  });

  return ok(
    {
      message: {
        id: message.id,
        text: message.text,
        isMine: true,
        createdAt: message.createdAt.toISOString(),
      },
    },
    201
  );
});
