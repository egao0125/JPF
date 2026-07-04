import { NextRequest } from "next/server";
import { prisma } from "@/lib/db";
import { handler, ok } from "@/lib/api";
import { requireUser } from "@/lib/auth";

// Everything the friends screen needs in one call:
// accepted friends + incoming/outgoing pending requests.
export const GET = handler(async (req: NextRequest) => {
  const user = await requireUser(req);

  const requests = await prisma.friendRequest.findMany({
    where: {
      OR: [{ fromId: user.id }, { toId: user.id }],
      status: { in: ["pending", "accepted"] },
    },
    include: {
      from: { select: { id: true, username: true } },
      to: { select: { id: true, username: true } },
    },
    orderBy: { createdAt: "desc" },
  });

  const friends: { userId: string; username: string | null }[] = [];
  const incoming: { requestId: string; userId: string; username: string | null }[] = [];
  const outgoing: { requestId: string; userId: string; username: string | null }[] = [];

  for (const r of requests) {
    const other = r.fromId === user.id ? r.to : r.from;
    if (r.status === "accepted") {
      friends.push({ userId: other.id, username: other.username });
    } else if (r.toId === user.id) {
      incoming.push({ requestId: r.id, userId: other.id, username: other.username });
    } else {
      outgoing.push({ requestId: r.id, userId: other.id, username: other.username });
    }
  }

  return ok({ friends, incoming, outgoing });
});
