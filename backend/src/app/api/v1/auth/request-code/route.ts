import { NextRequest } from "next/server";
import { z } from "zod";
import { createHash, randomInt } from "crypto";
import { prisma } from "@/lib/db";
import { handler, ok, parseBody, ApiError } from "@/lib/api";
import { isEligibleDomain } from "@/lib/schools";

const schema = z.object({ email: z.string().email().max(254) });

export const POST = handler(async (req: NextRequest) => {
  const { email: raw } = await parseBody(req, schema);
  const email = raw.toLowerCase().trim();
  const domain = email.split("@")[1];

  const registered = (await prisma.schoolDomain.findMany()).map((d) => d.domain);
  if (!isEligibleDomain(domain, registered)) {
    throw new ApiError(400, "大学のメールアドレス（.ac.jp など）で登録してください");
  }

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing?.isBanned) throw new ApiError(403, "このアカウントは利用停止されています");

  const code = String(randomInt(0, 1_000_000)).padStart(6, "0");
  const codeHash = createHash("sha256").update(code).digest("hex");

  await prisma.verificationCode.deleteMany({ where: { email } });
  await prisma.verificationCode.create({
    data: { email, codeHash, expiresAt: new Date(Date.now() + 10 * 60_000) },
  });

  // No mail provider in dev — surface the code in logs and (dev only) the response.
  console.log(`[auth] verification code for ${email}: ${code}`);
  const dev = process.env.NODE_ENV !== "production";
  return ok({ sent: true, ...(dev ? { devCode: code } : {}) });
});
