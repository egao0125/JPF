import { NextRequest } from "next/server";
import { prisma } from "@/lib/db";
import { handler, ok } from "@/lib/api";
import { requireUser } from "@/lib/auth";
import { toPostDtos } from "@/lib/serialize";

export const GET = handler(async (req: NextRequest) => {
  const user = await requireUser(req);
  const posts = await prisma.post.findMany({
    where: { authorId: user.id, isRemoved: false },
    include: { channel: true, poll: { include: { options: true } } },
    orderBy: { createdAt: "desc" },
    take: 100,
  });
  return ok({ posts: await toPostDtos(posts, user.id) });
});
