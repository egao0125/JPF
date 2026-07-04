// Opaque keyset cursors. Offset pagination degrades linearly with depth and
// breaks when rows shift; keyset stays O(log n) via the index regardless of
// how deep the client scrolls.
export function encodeCursor(parts: (string | number)[]): string {
  return Buffer.from(parts.join("|"), "utf8").toString("base64url");
}

export function decodeCursor(cursor: string | null): string[] | null {
  if (!cursor) return null;
  try {
    return Buffer.from(cursor, "base64url").toString("utf8").split("|");
  } catch {
    return null;
  }
}
