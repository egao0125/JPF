import { NextRequest } from "next/server";
import { prisma } from "@/lib/db";
import { handler, ok } from "@/lib/api";
import { requireUser } from "@/lib/auth";

export const GET = handler(async (req: NextRequest) => {
  const auth = await requireUser(req);
  const user = await prisma.user.findUniqueOrThrow({
    where: { id: auth.id },
    include: { school: true, _count: { select: { posts: true, comments: true } } },
  });
  return ok({
    id: user.id,
    email: user.email,
    karma: user.karma,
    isModerator: user.isModerator,
    postCount: user._count.posts,
    commentCount: user._count.comments,
    school: { id: user.school.id, name: user.school.name, shortName: user.school.shortName },
  });
});
