import { NextRequest } from "next/server";
import { z } from "zod";
import { Prisma } from "@prisma/client";
import { prisma } from "@/lib/db";
import { handler, ok, parseBody, ApiError } from "@/lib/api";
import { requireUser } from "@/lib/auth";

async function meDto(userId: string) {
  const user = await prisma.user.findUniqueOrThrow({
    where: { id: userId },
    include: { school: true, _count: { select: { posts: true, comments: true } } },
  });
  return {
    id: user.id,
    email: user.email,
    username: user.username,
    karma: user.karma,
    isModerator: user.isModerator,
    postCount: user._count.posts,
    commentCount: user._count.comments,
    school: { id: user.school.id, name: user.school.name, shortName: user.school.shortName },
  };
}

export const GET = handler(async (req: NextRequest) => {
  const auth = await requireUser(req);
  return ok(await meDto(auth.id));
});

const patchSchema = z.object({
  username: z
    .string()
    .regex(/^[a-zA-Z0-9_]{3,20}$/, "3〜20文字の英数字とアンダースコアが使えます"),
});

export const PATCH = handler(async (req: NextRequest) => {
  const auth = await requireUser(req);
  const { username } = await parseBody(req, patchSchema);
  try {
    await prisma.user.update({ where: { id: auth.id }, data: { username: username.toLowerCase() } });
  } catch (e) {
    if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === "P2002") {
      throw new ApiError(409, "このユーザーネームは使われています");
    }
    throw e;
  }
  return ok(await meDto(auth.id));
});
