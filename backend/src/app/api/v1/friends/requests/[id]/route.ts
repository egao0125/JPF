import { NextRequest } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/db";
import { handler, ok, parseBody, ApiError } from "@/lib/api";
import { requireUser } from "@/lib/auth";

const schema = z.object({ action: z.enum(["accept", "decline"]) });

export const POST = handler(async (req: NextRequest, ctx: { params: Promise<{ id: string }> }) => {
  const user = await requireUser(req);
  const { id } = await ctx.params;
  const { action } = await parseBody(req, schema);

  const request = await prisma.friendRequest.findUnique({ where: { id } });
  if (!request || request.toId !== user.id || request.status !== "pending") {
    throw new ApiError(404, "リクエストが見つかりません");
  }

  await prisma.friendRequest.update({
    where: { id },
    data: { status: action === "accept" ? "accepted" : "declined" },
  });
  return ok({ status: action === "accept" ? "accepted" : "declined" });
});
