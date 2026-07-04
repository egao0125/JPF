import { NextRequest } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/db";
import { handler, ok, parseBody, ApiError } from "@/lib/api";
import { requireUser } from "@/lib/auth";
import { randomAlias } from "@/lib/aliases";
import { toPostDtos } from "@/lib/serialize";

const schema = z.object({
  channelSlug: z.string().min(1),
  text: z.string().trim().min(1, "本文を入力してください").max(1000),
  imageUrl: z
    .string()
    .regex(/^\/api\/v1\/images\/[a-f0-9]{24}\.(jpg|png|webp|heic)$/)
    .optional(),
  poll: z
    .object({ options: z.array(z.string().trim().min(1).max(50)).min(2).max(4) })
    .optional(),
});

export const POST = handler(async (req: NextRequest) => {
  const user = await requireUser(req);
  const body = await parseBody(req, schema);

  const channel = await prisma.channel.findUnique({ where: { slug: body.channelSlug } });
  if (!channel) throw new ApiError(404, "チャンネルが見つかりません");
  if (body.poll && body.imageUrl) throw new ApiError(400, "画像とアンケートは同時に投稿できません");

  const post = await prisma.post.create({
    data: {
      authorId: user.id,
      schoolId: user.schoolId,
      channelId: channel.id,
      text: body.text,
      imageUrl: body.imageUrl ?? null,
      poll: body.poll
        ? { create: { options: { create: body.poll.options.map((text, i) => ({ text, order: i })) } } }
        : undefined,
    },
    include: { channel: true, poll: { include: { options: true } } },
  });

  await prisma.threadAlias.create({
    data: { postId: post.id, userId: user.id, ...randomAlias(), isOp: true },
  });

  const [dto] = await toPostDtos([post], user.id);
  return ok({ post: dto }, 201);
});
