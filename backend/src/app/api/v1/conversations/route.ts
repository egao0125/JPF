import { NextRequest } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/db";
import { handler, ok, parseBody, ApiError } from "@/lib/api";
import { requireUser } from "@/lib/auth";

// List my conversations, most recently active first.
export const GET = handler(async (req: NextRequest) => {
  const user = await requireUser(req);

  const conversations = await prisma.conversation.findMany({
    where: { OR: [{ userAId: user.id }, { userBId: user.id }] },
    orderBy: { lastMessageAt: "desc" },
    take: 50,
    include: { messages: { orderBy: { createdAt: "desc" }, take: 1 } },
  });

  const otherIds = conversations.map((c) => (c.userAId === user.id ? c.userBId : c.userAId));
  const [others, unreadRows] = await Promise.all([
    prisma.user.findMany({ where: { id: { in: otherIds } }, select: { id: true, username: true } }),
    prisma.message.groupBy({
      by: ["conversationId"],
      where: {
        conversationId: { in: conversations.map((c) => c.id) },
        senderId: { not: user.id },
        readAt: null,
      },
      _count: { id: true },
    }),
  ]);
  const otherMap = new Map(others.map((u) => [u.id, u]));
  const unreadMap = new Map(unreadRows.map((r) => [r.conversationId, r._count.id]));

  return ok({
    conversations: conversations.map((c) => {
      const otherId = c.userAId === user.id ? c.userBId : c.userAId;
      const last = c.messages[0];
      return {
        id: c.id,
        friend: { userId: otherId, username: otherMap.get(otherId)?.username ?? null },
        lastMessage: last
          ? { text: last.text, isMine: last.senderId === user.id, createdAt: last.createdAt.toISOString() }
          : null,
        unreadCount: unreadMap.get(c.id) ?? 0,
      };
    }),
  });
});

const createSchema = z.object({ userId: z.string().min(1) });

// Open (or create) the conversation with a friend.
export const POST = handler(async (req: NextRequest) => {
  const user = await requireUser(req);
  const { userId: otherId } = await parseBody(req, createSchema);
  if (otherId === user.id) throw new ApiError(400, "自分とは会話できません");

  const friendship = await prisma.friendRequest.findFirst({
    where: {
      status: "accepted",
      OR: [
        { fromId: user.id, toId: otherId },
        { fromId: otherId, toId: user.id },
      ],
    },
  });
  if (!friendship) throw new ApiError(403, "フレンドとだけメッセージできます");

  const [userAId, userBId] = [user.id, otherId].sort();
  const conversation = await prisma.conversation.upsert({
    where: { userAId_userBId: { userAId, userBId } },
    create: { userAId, userBId },
    update: {},
  });

  const other = await prisma.user.findUnique({ where: { id: otherId }, select: { username: true } });
  return ok({ id: conversation.id, friend: { userId: otherId, username: other?.username ?? null } });
});
