import { NextRequest } from "next/server";
import { z } from "zod";
import { Prisma } from "@prisma/client";
import { prisma } from "@/lib/db";
import { handler, ok, parseBody } from "@/lib/api";

const schema = z.object({ email: z.string().email().max(254) });

export const GET = handler(async () => {
  return ok({ count: await prisma.waitlistEntry.count() });
});

export const POST = handler(async (req: NextRequest) => {
  const { email: raw } = await parseBody(req, schema);
  const email = raw.toLowerCase().trim();

  let alreadyJoined = false;
  try {
    await prisma.waitlistEntry.create({ data: { email } });
  } catch (e) {
    if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === "P2002") {
      alreadyJoined = true; // joining twice is fine — stay in line
    } else {
      throw e;
    }
  }

  return ok({ joined: true, alreadyJoined, count: await prisma.waitlistEntry.count() }, alreadyJoined ? 200 : 201);
});
