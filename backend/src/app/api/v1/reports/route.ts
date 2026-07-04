import { NextRequest } from "next/server";
import { z } from "zod";
import { Prisma } from "@prisma/client";
import { prisma } from "@/lib/db";
import { handler, ok, parseBody, ApiError } from "@/lib/api";
import { requireUser } from "@/lib/auth";

const AUTO_HIDE_THRESHOLD = 3;

const schema = z.object({
  targetType: z.enum(["post", "comment"]),
  targetId: z.string().min(1),
  reason: z.string().trim().min(1).max(200),
});

export const POST = handler(async (req: NextRequest) => {
  const user = await requireUser(req);
  const body = await parseBody(req, schema);

  const target =
    body.targetType === "post"
      ? await prisma.post.findUnique({ where: { id: body.targetId }, select: { id: true, isRemoved: true } })
      : await prisma.comment.findUnique({ where: { id: body.targetId }, select: { id: true, isRemoved: true } });
  if (!target || target.isRemoved) throw new ApiError(404, "対象が見つかりません");

  try {
    await prisma.report.create({ data: { reporterId: user.id, ...body } });
  } catch (e) {
    if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === "P2002") {
      throw new ApiError(409, "すでに通報済みです");
    }
    throw e;
  }

  // Community safety valve: enough distinct reports hides content pending review.
  const count = await prisma.report.count({
    where: { targetType: body.targetType, targetId: body.targetId, status: "open" },
  });
  if (count >= AUTO_HIDE_THRESHOLD) {
    if (body.targetType === "post") {
      await prisma.post.update({ where: { id: body.targetId }, data: { isRemoved: true } });
    } else {
      await prisma.comment.update({ where: { id: body.targetId }, data: { isRemoved: true } });
    }
  }

  return ok({ reported: true }, 201);
});
