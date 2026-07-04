import { NextRequest, NextResponse } from "next/server";
import { readFile } from "fs/promises";
import path from "path";
import { handler, ApiError } from "@/lib/api";

const NAME_RE = /^[a-f0-9]{24}\.(jpg|png|webp|heic)$/;
const TYPE_BY_EXT: Record<string, string> = {
  jpg: "image/jpeg",
  png: "image/png",
  webp: "image/webp",
  heic: "image/heic",
};

export const GET = handler(async (_req: NextRequest, ctx: { params: Promise<{ name: string }> }) => {
  const { name } = await ctx.params;
  // Strict allowlist prevents path traversal.
  if (!NAME_RE.test(name)) throw new ApiError(404, "画像が見つかりません");

  const data = await readFile(path.join(process.cwd(), "uploads", name)).catch(() => {
    throw new ApiError(404, "画像が見つかりません");
  });
  const ext = name.split(".")[1];
  return new NextResponse(new Uint8Array(data), {
    headers: {
      "Content-Type": TYPE_BY_EXT[ext],
      "Cache-Control": "public, max-age=31536000, immutable",
    },
  });
});
