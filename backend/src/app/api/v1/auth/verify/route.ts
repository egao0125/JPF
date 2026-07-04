import { NextRequest } from "next/server";
import { z } from "zod";
import { createHash } from "crypto";
import { prisma } from "@/lib/db";
import { handler, ok, parseBody, ApiError } from "@/lib/api";
import { signToken } from "@/lib/auth";
import { resolveSchoolByEmail } from "@/lib/schools";

const schema = z.object({
  email: z.string().email().max(254),
  code: z.string().regex(/^\d{6}$/),
});

export const POST = handler(async (req: NextRequest) => {
  const body = await parseBody(req, schema);
  const email = body.email.toLowerCase().trim();

  const record = await prisma.verificationCode.findFirst({
    where: { email },
    orderBy: { createdAt: "desc" },
  });
  const codeHash = createHash("sha256").update(body.code).digest("hex");
  if (!record || record.expiresAt < new Date() || record.codeHash !== codeHash) {
    throw new ApiError(400, "認証コードが正しくないか、期限切れです");
  }
  await prisma.verificationCode.deleteMany({ where: { email } });

  let user = await prisma.user.findUnique({ where: { email }, include: { school: true } });
  if (!user) {
    const school = await resolveSchoolByEmail(email);
    if (!school) throw new ApiError(400, "大学のメールアドレスで登録してください");
    user = await prisma.user.create({
      data: { email, schoolId: school.id },
      include: { school: true },
    });
  }
  if (user.isBanned) throw new ApiError(403, "このアカウントは利用停止されています");

  const token = await signToken(user.id);
  return ok({
    token,
    user: {
      id: user.id,
      email: user.email,
      karma: user.karma,
      isModerator: user.isModerator,
      school: { id: user.school.id, name: user.school.name, shortName: user.school.shortName },
    },
  });
});
