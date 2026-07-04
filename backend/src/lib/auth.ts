import { SignJWT, jwtVerify } from "jose";
import { NextRequest } from "next/server";
import { prisma } from "./db";
import { ApiError } from "./api";

const secret = () => new TextEncoder().encode(process.env.JWT_SECRET ?? "dev-secret-change-me");

export async function signToken(userId: string): Promise<string> {
  return new SignJWT({ sub: userId })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("30d")
    .sign(secret());
}

export type AuthedUser = {
  id: string;
  email: string;
  schoolId: string;
  karma: number;
  isModerator: boolean;
  isBanned: boolean;
};

export async function requireUser(req: NextRequest): Promise<AuthedUser> {
  const header = req.headers.get("authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (!token) throw new ApiError(401, "認証が必要です");
  let userId: string;
  try {
    const { payload } = await jwtVerify(token, secret());
    userId = payload.sub as string;
  } catch {
    throw new ApiError(401, "トークンが無効です");
  }
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, email: true, schoolId: true, karma: true, isModerator: true, isBanned: true },
  });
  if (!user) throw new ApiError(401, "ユーザーが見つかりません");
  if (user.isBanned) throw new ApiError(403, "このアカウントは利用停止されています");
  return user;
}

export async function requireModerator(req: NextRequest): Promise<AuthedUser> {
  const user = await requireUser(req);
  if (!user.isModerator) throw new ApiError(403, "モデレーター権限が必要です");
  return user;
}
