import { NextRequest } from "next/server";
import { prisma } from "@/lib/db";
import { handler, ok, ApiError } from "@/lib/api";
import { requireUser } from "@/lib/auth";
import { encodeCursor, decodeCursor } from "@/lib/pagination";
import { toPostDtos, PostWithRelations } from "@/lib/serialize";

const PAGE_SIZE = 20;
const include = { channel: true, poll: { include: { options: true } } } as const;

// All sorts use keyset pagination over indexed columns — no offsets, no
// in-memory windows — so page N is as cheap as page 1 at any table size.
export const GET = handler(async (req: NextRequest) => {
  const user = await requireUser(req);
  const params = req.nextUrl.searchParams;
  const sort = params.get("sort") ?? "new";
  const channelSlug = params.get("channel");
  const range = params.get("range") ?? "week"; // for top
  const cursor = decodeCursor(params.get("cursor"));

  const where: Record<string, unknown> = { schoolId: user.schoolId, isRemoved: false };
  if (channelSlug) {
    const channel = await prisma.channel.findUnique({ where: { slug: channelSlug } });
    if (!channel) throw new ApiError(404, "チャンネルが見つかりません");
    where.channelId = channel.id;
  }

  let page: PostWithRelations[];
  let nextCursor: string | null = null;

  if (sort === "hot") {
    if (cursor && cursor.length === 2) {
      const [hot, id] = [parseFloat(cursor[0]), cursor[1]];
      where.OR = [{ hotScore: { lt: hot } }, { hotScore: hot, id: { lt: id } }];
    }
    page = await prisma.post.findMany({
      where,
      include,
      orderBy: [{ hotScore: "desc" }, { id: "desc" }],
      take: PAGE_SIZE + 1,
    });
    if (page.length > PAGE_SIZE) {
      page = page.slice(0, PAGE_SIZE);
      const last = page[page.length - 1];
      nextCursor = encodeCursor([last.hotScore, last.id]);
    }
  } else if (sort === "top") {
    if (range !== "all") {
      const days = range === "today" ? 1 : 7;
      where.createdAt = { gte: new Date(Date.now() - days * 86_400_000) };
    }
    if (cursor && cursor.length === 2) {
      const [score, id] = [parseInt(cursor[0], 10), cursor[1]];
      where.OR = [{ score: { lt: score } }, { score, id: { lt: id } }];
    }
    page = await prisma.post.findMany({
      where,
      include,
      orderBy: [{ score: "desc" }, { id: "desc" }],
      take: PAGE_SIZE + 1,
    });
    if (page.length > PAGE_SIZE) {
      page = page.slice(0, PAGE_SIZE);
      const last = page[page.length - 1];
      nextCursor = encodeCursor([last.score, last.id]);
    }
  } else {
    if (cursor && cursor.length === 2) {
      const [createdAt, id] = [new Date(cursor[0]), cursor[1]];
      where.OR = [{ createdAt: { lt: createdAt } }, { createdAt, id: { lt: id } }];
    }
    page = await prisma.post.findMany({
      where,
      include,
      orderBy: [{ createdAt: "desc" }, { id: "desc" }],
      take: PAGE_SIZE + 1,
    });
    if (page.length > PAGE_SIZE) {
      page = page.slice(0, PAGE_SIZE);
      const last = page[page.length - 1];
      nextCursor = encodeCursor([last.createdAt.toISOString(), last.id]);
    }
  }

  return ok({ posts: await toPostDtos(page, user.id), nextCursor });
});
