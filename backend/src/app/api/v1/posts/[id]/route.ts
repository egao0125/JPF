import { NextRequest } from "next/server";
import { prisma } from "@/lib/db";
import { handler, ok, ApiError } from "@/lib/api";
import { requireUser } from "@/lib/auth";
import { toPostDtos, toCommentDtos } from "@/lib/serialize";

type Ctx = { params: Promise<{ id: string }> };

export const GET = handler(async (req: NextRequest, ctx: Ctx) => {
  const user = await requireUser(req);
  const { id } = await ctx.params;

  const post = await prisma.post.findUnique({
    where: { id },
    include: { channel: true, poll: { include: { options: true } } },
  });
  if (!post || post.isRemoved) throw new ApiError(404, "投稿が見つかりません");
  if (post.schoolId !== user.schoolId) throw new ApiError(403, "他大学の投稿は閲覧できません");

  const comments = await prisma.comment.findMany({
    where: { postId: id },
    orderBy: { createdAt: "asc" },
  });

  const [dto] = await toPostDtos([post], user.id);
  return ok({ post: dto, comments: await toCommentDtos(comments, id, user.id) });
});

export const DELETE = handler(async (req: NextRequest, ctx: Ctx) => {
  const user = await requireUser(req);
  const { id } = await ctx.params;

  const post = await prisma.post.findUnique({ where: { id }, select: { authorId: true } });
  if (!post) throw new ApiError(404, "投稿が見つかりません");
  if (post.authorId !== user.id && !user.isModerator) {
    throw new ApiError(403, "自分の投稿のみ削除できます");
  }

  await prisma.post.update({ where: { id }, data: { isRemoved: true } });
  return ok({ deleted: true });
});
