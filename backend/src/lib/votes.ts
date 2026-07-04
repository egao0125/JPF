import { prisma } from "./db";
import { ApiError } from "./api";
import { hotScore } from "./ranking";

// Apply an up/down/clear vote to a post or comment.
// Keeps the cached score on the target and the author's karma in sync.
export async function applyVote(
  userId: string,
  targetType: "post" | "comment",
  targetId: string,
  value: -1 | 0 | 1
): Promise<{ score: number; myVote: number }> {
  const target =
    targetType === "post"
      ? await prisma.post.findUnique({
          where: { id: targetId },
          select: { authorId: true, isRemoved: true, createdAt: true },
        })
      : await prisma.comment.findUnique({
          where: { id: targetId },
          select: { authorId: true, isRemoved: true, createdAt: true },
        });
  if (!target || target.isRemoved) throw new ApiError(404, "対象が見つかりません");

  const existing = await prisma.vote.findUnique({
    where: { userId_targetType_targetId: { userId, targetType, targetId } },
  });
  const delta = value - (existing?.value ?? 0);

  if (value === 0) {
    if (existing) await prisma.vote.delete({ where: { id: existing.id } });
  } else {
    await prisma.vote.upsert({
      where: { userId_targetType_targetId: { userId, targetType, targetId } },
      create: { userId, targetType, targetId, value },
      update: { value },
    });
  }

  let score: number;
  if (targetType === "post") {
    const updated = await prisma.post.update({
      where: { id: targetId },
      data: { score: { increment: delta } },
      select: { score: true },
    });
    score = updated.score;
    await prisma.post.update({
      where: { id: targetId },
      data: { hotScore: hotScore(score, target.createdAt) },
    });
  } else {
    const updated = await prisma.comment.update({
      where: { id: targetId },
      data: { score: { increment: delta } },
      select: { score: true },
    });
    score = updated.score;
  }

  if (delta !== 0 && target.authorId !== userId) {
    await prisma.user.update({ where: { id: target.authorId }, data: { karma: { increment: delta } } });
  }

  return { score, myVote: value };
}
