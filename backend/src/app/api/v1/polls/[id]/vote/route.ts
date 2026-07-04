import { NextRequest } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/db";
import { handler, ok, parseBody, ApiError } from "@/lib/api";
import { requireUser } from "@/lib/auth";

const schema = z.object({ optionId: z.string().min(1) });

export const POST = handler(async (req: NextRequest, ctx: { params: Promise<{ id: string }> }) => {
  const user = await requireUser(req);
  const { id: pollId } = await ctx.params;
  const { optionId } = await parseBody(req, schema);

  const option = await prisma.pollOption.findFirst({ where: { id: optionId, pollId } });
  if (!option) throw new ApiError(404, "選択肢が見つかりません");

  const existing = await prisma.pollVote.findUnique({
    where: { userId_pollId: { userId: user.id, pollId } },
  });

  if (existing && existing.optionId !== optionId) {
    // Changing your vote moves the count.
    await prisma.pollOption.update({
      where: { id: existing.optionId },
      data: { voteCount: { decrement: 1 } },
    });
    await prisma.pollVote.update({ where: { id: existing.id }, data: { optionId } });
    await prisma.pollOption.update({ where: { id: optionId }, data: { voteCount: { increment: 1 } } });
  } else if (!existing) {
    await prisma.pollVote.create({ data: { userId: user.id, pollId, optionId } });
    await prisma.pollOption.update({ where: { id: optionId }, data: { voteCount: { increment: 1 } } });
  }

  const options = await prisma.pollOption.findMany({
    where: { pollId },
    orderBy: { order: "asc" },
  });
  return ok({
    id: pollId,
    totalVotes: options.reduce((s, o) => s + o.voteCount, 0),
    myOptionId: optionId,
    options: options.map((o) => ({ id: o.id, text: o.text, voteCount: o.voteCount })),
  });
});
