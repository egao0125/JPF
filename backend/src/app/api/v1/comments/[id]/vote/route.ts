import { NextRequest } from "next/server";
import { z } from "zod";
import { handler, ok, parseBody } from "@/lib/api";
import { requireUser } from "@/lib/auth";
import { applyVote } from "@/lib/votes";

const schema = z.object({ value: z.union([z.literal(-1), z.literal(0), z.literal(1)]) });

export const POST = handler(async (req: NextRequest, ctx: { params: Promise<{ id: string }> }) => {
  const user = await requireUser(req);
  const { id } = await ctx.params;
  const { value } = await parseBody(req, schema);
  return ok(await applyVote(user.id, "comment", id, value));
});
