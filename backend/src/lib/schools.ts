import { prisma } from "./db";

// Suffix match: student addresses live on subdomains (g.ecc.u-tokyo.ac.jp,
// fuji.waseda.jp), so a school's registered root domain matches them all.
export async function resolveSchoolByEmail(email: string): Promise<{ id: string; name: string } | null> {
  const domain = email.split("@")[1]?.toLowerCase();
  if (!domain) return null;

  const rows = await prisma.schoolDomain.findMany({ include: { school: true } });
  for (const row of rows) {
    if (domain === row.domain || domain.endsWith("." + row.domain)) {
      return { id: row.school.id, name: row.school.name };
    }
  }

  // Any other *.ac.jp address is a university we haven't registered yet —
  // auto-create so no student is locked out.
  if (domain.endsWith(".ac.jp")) {
    const root = domain; // keep full domain; admins can merge/rename later
    const school = await prisma.school.create({
      data: { name: root, domains: { create: [{ domain: root }] } },
    });
    return { id: school.id, name: school.name };
  }

  return null;
}

export function isEligibleDomain(domain: string, registered: string[]): boolean {
  return (
    domain.endsWith(".ac.jp") ||
    registered.some((d) => domain === d || domain.endsWith("." + d))
  );
}
