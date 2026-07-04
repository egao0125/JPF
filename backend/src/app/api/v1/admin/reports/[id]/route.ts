import { NextRequest } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/db";
import { handler, ok, parseBody, ApiError } from "@/lib/api";
import { requireModerator } from "@/lib/auth";

const schema = z.object({ action: z.enum(["remove", "dismiss", "ban"]) });

export const POST = handler(async (req: NextRequest, ctx: { params: Promise<{ id: string }> }) => {
  await requireModerator(req);
  const { id } = await ctx.params;
  const { action } = await parseBody(req, schema);

  const report = await prisma.report.findUnique({ where: { id } });
  if (!report) throw new ApiError(404, "通報が見つかりません");

  if (action === "dismiss") {
    await prisma.report.update({ where: { id }, data: { status: "dismissed" } });
    return ok({ status: "dismissed" });
  }

  // remove & ban both take the content down and resolve every open report on it.
  const target =
    report.targetType === "post"
      ? await prisma.post.findUnique({ where: { id: report.targetId }, select: { authorId: true } })
      : await prisma.comment.findUnique({ where: { id: report.targetId }, select: { authorId: true } });
  if (!target) throw new ApiError(404, "対象が見つかりません");

  if (report.targetType === "post") {
    await prisma.post.update({ where: { id: report.targetId }, data: { isRemoved: true } });
  } else {
    await prisma.comment.update({ where: { id: report.targetId }, data: { isRemoved: true } });
  }
  if (action === "ban") {
    await prisma.user.update({ where: { id: target.authorId }, data: { isBanned: true } });
  }
  await prisma.report.updateMany({
    where: { targetType: report.targetType, targetId: report.targetId, status: "open" },
    data: { status: "resolved" },
  });

  return ok({ status: "resolved", banned: action === "ban" });
});
