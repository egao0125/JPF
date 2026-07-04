import { NextRequest } from "next/server";
import { prisma } from "@/lib/db";
import { handler, ok } from "@/lib/api";
import { requireModerator } from "@/lib/auth";

export const GET = handler(async (req: NextRequest) => {
  await requireModerator(req);

  const reports = await prisma.report.findMany({
    where: { status: "open" },
    orderBy: { createdAt: "desc" },
    take: 100,
  });

  const postIds = reports.filter((r) => r.targetType === "post").map((r) => r.targetId);
  const commentIds = reports.filter((r) => r.targetType === "comment").map((r) => r.targetId);
  const [posts, comments] = await Promise.all([
    prisma.post.findMany({ where: { id: { in: postIds } }, include: { school: true } }),
    prisma.comment.findMany({ where: { id: { in: commentIds } }, include: { post: { include: { school: true } } } }),
  ]);
  const postMap = new Map(posts.map((p) => [p.id, p]));
  const commentMap = new Map(comments.map((c) => [c.id, c]));

  return ok({
    reports: reports.map((r) => {
      const post = r.targetType === "post" ? postMap.get(r.targetId) : undefined;
      const comment = r.targetType === "comment" ? commentMap.get(r.targetId) : undefined;
      return {
        id: r.id,
        targetType: r.targetType,
        targetId: r.targetId,
        reason: r.reason,
        createdAt: r.createdAt.toISOString(),
        targetText: post?.text ?? comment?.text ?? "（削除済み）",
        targetRemoved: post?.isRemoved ?? comment?.isRemoved ?? true,
        school: post?.school.name ?? comment?.post.school.name ?? "-",
      };
    }),
  });
});
