import { prisma } from "@/lib/db";
import { handler, ok } from "@/lib/api";

export const GET = handler(async () => {
  const schools = await prisma.school.findMany({
    orderBy: { name: "asc" },
    select: { id: true, name: true, shortName: true },
  });
  return ok({ schools });
});
