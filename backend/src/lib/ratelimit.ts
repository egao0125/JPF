import { ApiError } from "./api";

// Fixed-window rate limiter, in-memory per process. Good for a single node;
// swap the store for Redis (same interface) when running multiple instances —
// the call sites don't change.
type Window = { count: number; resetAt: number };
const windows = new Map<string, Window>();

// Periodically drop expired windows so the map doesn't grow unbounded.
const SWEEP_INTERVAL_MS = 60_000;
let lastSweep = 0;

export function rateLimit(key: string, limit: number, windowMs: number): void {
  const now = Date.now();

  if (now - lastSweep > SWEEP_INTERVAL_MS) {
    lastSweep = now;
    for (const [k, w] of windows) {
      if (w.resetAt <= now) windows.delete(k);
    }
  }

  const window = windows.get(key);
  if (!window || window.resetAt <= now) {
    windows.set(key, { count: 1, resetAt: now + windowMs });
    return;
  }
  window.count += 1;
  if (window.count > limit) {
    throw new ApiError(429, "リクエストが多すぎます。しばらくしてからお試しください");
  }
}
