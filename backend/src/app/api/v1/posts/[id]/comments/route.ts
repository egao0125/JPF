import { NextRequest } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/db";
import { handler, ok, parseBody, ApiError } from "@/lib/api";
import { requireUser } from "@/lib/auth";
import { randomAliasAvoiding } from "@/lib/aliases";
import { rateLimit } from "@/lib/ratelimit";
import { toCommentDtos } from "@/lib/serialize";

const schema = z.object({
  text: z.string().trim().min(1, "本文を入力してください").max(500),
  parentId: z.string().optional(),
  anonymous: z.boolean().default(true),
});

export const POST = handler(async (req: NextRequest, ctx: { params: Promise<{ id: string }> }) => {
  const user = await requireUser(req);
  rateLimit(`comment:${user.id}`, 20, 60_000);
  const { id: postId } = await ctx.params;
  const body = await parseBody(req, schema);

  if (!body.anonymous) {
    const me = await prisma.user.findUnique({ where: { id: user.id }, select: { username: true } });
    if (!me?.username) throw new ApiError(400, "ユーザーネームを設定すると実名コメントができます");
  }

  const post = await prisma.post.findUnique({
    where: { id: postId },
    select: { id: true, authorId: true, isRemoved: true, schoolId: true },
  });
  if (!post || post.isRemoved) throw new ApiError(404, "投稿が見つかりません");
  if (post.schoolId !== user.schoolId) throw new ApiError(403, "他大学の投稿にはコメントできません");

  let parent: { id: string; authorId: string } | null = null;
  if (body.parentId) {
    parent = await prisma.comment.findFirst({
      where: { id: body.parentId, postId },
      select: { id: true, authorId: true },
    });
    if (!parent) throw new ApiError(404, "返信先のコメントが見つかりません");
  }

  // Stable per-thread alias: reuse if this user already participated.
  let alias = await prisma.threadAlias.findUnique({
    where: { postId_userId: { postId, userId: user.id } },
  });
  if (!alias) {
    const used = new Set(
      (await prisma.threadAlias.findMany({ where: { postId } })).map((a) => a.alias)
    );
    alias = await prisma.threadAlias.create({
      data: { postId, userId: user.id, ...randomAliasAvoiding(used) },
    });
  }

  const comment = await prisma.comment.create({
    data: {
      postId,
      parentId: parent?.id ?? null,
      authorId: user.id,
      text: body.text,
      isAnonymous: body.anonymous,
    },
  });
  await prisma.post.update({ where: { id: postId }, data: { commentCount: { increment: 1 } } });

  // Notify the person being answered (never yourself).
  const notifyUserId = parent ? parent.authorId : post.authorId;
  if (notifyUserId !== user.id) {
    let actorAlias = alias.alias;
    let actorEmoji = alias.emoji;
    if (!body.anonymous) {
      const me = await prisma.user.findUnique({ where: { id: user.id }, select: { username: true } });
      if (me?.username) {
        actorAlias = `@${me.username}`;
        actorEmoji = "";
      }
    }
    await prisma.notification.create({
      data: {
        userId: notifyUserId,
        type: parent ? "reply_to_comment" : "comment_on_post",
        postId,
        commentId: comment.id,
        actorAlias,
        actorEmoji,
        preview: body.text.slice(0, 80),
      },
    });
  }

  const [dto] = await toCommentDtos([comment], postId, user.id);
  return ok({ comment: dto }, 201);
});
