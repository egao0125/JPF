import { NextRequest } from "next/server";
import { prisma } from "@/lib/db";
import { handler, ok } from "@/lib/api";
import { requireUser } from "@/lib/auth";

export const GET = handler(async (req: NextRequest) => {
  const user = await requireUser(req);
  const [items, unreadCount] = await Promise.all([
    prisma.notification.findMany({
      where: { userId: user.id },
      orderBy: { createdAt: "desc" },
      take: 50,
    }),
    prisma.notification.count({ where: { userId: user.id, isRead: false } }),
  ]);
  return ok({
    unreadCount,
    notifications: items.map((n) => ({
      id: n.id,
      type: n.type,
      postId: n.postId,
      commentId: n.commentId,
      actorAlias: n.actorAlias,
      actorEmoji: n.actorEmoji,
      preview: n.preview,
      isRead: n.isRead,
      createdAt: n.createdAt.toISOString(),
    })),
  });
});
