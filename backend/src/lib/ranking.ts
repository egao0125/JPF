// Reddit-style hot score: recent activity beats raw score over time.
export function hotScore(score: number, createdAt: Date, now = new Date()): number {
  const ageHours = Math.max(0, (now.getTime() - createdAt.getTime()) / 3_600_000);
  return score / Math.pow(ageHours + 2, 1.5);
}
