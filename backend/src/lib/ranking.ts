// Write-time hot ranking (Reddit-style): computed when a post is created or
// voted on, stored in Post.hotScore, and indexed — so the hot feed is a plain
// indexed ORDER BY instead of an in-memory sort over a time window. The epoch
// term makes newer posts outrank older ones at equal score, so old posts sink
// without any periodic recompute.
export function hotScore(score: number, createdAt: Date): number {
  const order = Math.log10(Math.max(Math.abs(score), 1));
  const sign = score > 0 ? 1 : score < 0 ? -1 : 0;
  return sign * order + createdAt.getTime() / 1000 / 45000;
}
