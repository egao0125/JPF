import { NextRequest } from "next/server";
import { prisma } from "@/lib/db";
import { handler, ok, ApiError } from "@/lib/api";
import { requireUser } from "@/lib/auth";
import { hotScore } from "@/lib/ranking";
import { toPostDtos, PostWithRelations } from "@/lib/serialize";

const PAGE_SIZE = 20;
const include = { channel: true, poll: { include: { options: true } } } as const;

export const GET = handler(async (req: NextRequest) => {
  const user = await requireUser(req);
  const params = req.nextUrl.searchParams;
  const sort = params.get("sort") ?? "new";
  const channelSlug = params.get("channel");
  const range = params.get("range") ?? "week"; // for top
  const cursor = Math.max(0, parseInt(params.get("cursor") ?? "0", 10) || 0);

  const where: Record<string, unknown> = { schoolId: user.schoolId, isRemoved: false };
  if (channelSlug) {
    const channel = await prisma.channel.findUnique({ where: { slug: channelSlug } });
    if (!channel) throw new ApiError(404, "チャンネルが見つかりません");
    where.channelId = channel.id;
  }

  let page: PostWithRelations[];
  let hasMore: boolean;

  if (sort === "hot") {
    // Rank the recent window in memory — plenty for campus-scale traffic.
    const recent = await prisma.post.findMany({
      where: { ...where, createdAt: { gte: new Date(Date.now() - 14 * 86_400_000) } },
      include,
      orderBy: { createdAt: "desc" },
      take: 500,
    });
    const now = new Date();
    recent.sort((a, b) => hotScore(b.score, b.createdAt, now) - hotScore(a.score, a.createdAt, now));
    page = recent.slice(cursor, cursor + PAGE_SIZE);
    hasMore = recent.length > cursor + PAGE_SIZE;
  } else {
    if (sort === "top" && range !== "all") {
      const days = range === "today" ? 1 : 7;
      where.createdAt = { gte: new Date(Date.now() - days * 86_400_000) };
    }
    const orderBy =
      sort === "top"
        ? [{ score: "desc" as const }, { createdAt: "desc" as const }]
        : [{ createdAt: "desc" as const }];
    const rows = await prisma.post.findMany({
      where,
      include,
      orderBy,
      skip: cursor,
      take: PAGE_SIZE + 1,
    });
    hasMore = rows.length > PAGE_SIZE;
    page = rows.slice(0, PAGE_SIZE);
  }

  return ok({
    posts: await toPostDtos(page, user.id),
    nextCursor: hasMore ? cursor + PAGE_SIZE : null,
  });
});
