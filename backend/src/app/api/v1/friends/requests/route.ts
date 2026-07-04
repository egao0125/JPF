import { NextRequest } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/db";
import { handler, ok, parseBody, ApiError } from "@/lib/api";
import { requireUser } from "@/lib/auth";
import { rateLimit } from "@/lib/ratelimit";

const schema = z.object({ username: z.string().min(1).max(30) });

export const POST = handler(async (req: NextRequest) => {
  const user = await requireUser(req);
  rateLimit(`friendreq:${user.id}`, 20, 3_600_000);
  const { username } = await parseBody(req, schema);

  const me = await prisma.user.findUnique({ where: { id: user.id }, select: { username: true } });
  if (!me?.username) {
    throw new ApiError(400, "フレンド申請にはユーザーネームの設定が必要です");
  }

  const target = await prisma.user.findUnique({
    where: { username: username.toLowerCase().replace(/^@/, "") },
    select: { id: true, username: true, isBanned: true },
  });
  if (!target || target.isBanned) throw new ApiError(404, "そのユーザーは見つかりません");
  if (target.id === user.id) throw new ApiError(400, "自分にフレンド申請はできません");

  const existing = await prisma.friendRequest.findFirst({
    where: {
      OR: [
        { fromId: user.id, toId: target.id },
        { fromId: target.id, toId: user.id },
      ],
      status: { in: ["pending", "accepted"] },
    },
  });

  if (existing?.status === "accepted") throw new ApiError(409, "すでにフレンドです");
  if (existing && existing.fromId === user.id) throw new ApiError(409, "申請済みです");
  if (existing) {
    // They already asked us — a request back means mutual consent.
    await prisma.friendRequest.update({ where: { id: existing.id }, data: { status: "accepted" } });
    return ok({ status: "accepted", userId: target.id, username: target.username });
  }

  await prisma.friendRequest.create({ data: { fromId: user.id, toId: target.id } });
  return ok({ status: "pending", userId: target.id, username: target.username }, 201);
});
