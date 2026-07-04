import { prisma } from "@/lib/db";
import { handler, ok } from "@/lib/api";

export const GET = handler(async () => {
  const channels = await prisma.channel.findMany({
    orderBy: { order: "asc" },
    select: { slug: true, nameJa: true, emoji: true },
  });
  return ok({ channels });
});
