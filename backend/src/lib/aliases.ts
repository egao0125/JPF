// Anonymous alias generator: adjective × animal, Japanese campus flavor.
// A user keeps the same alias within one thread (ThreadAlias row), fresh per thread.

const ADJECTIVES = [
  "ねむい",
  "ひまな",
  "まじめな",
  "ゆるい",
  "謎の",
  "陽気な",
  "冷静な",
  "腹ぺこの",
  "俊足の",
  "夜型の",
  "単位不足の",
  "留年寸前の",
  "天才の",
  "崖っぷちの",
  "無敵の",
  "さすらいの",
  "陰キャの",
  "陽キャの",
  "早起きの",
  "遅刻気味の",
];

const ANIMALS: { name: string; emoji: string }[] = [
  { name: "タヌキ", emoji: "🦝" },
  { name: "キツネ", emoji: "🦊" },
  { name: "パンダ", emoji: "🐼" },
  { name: "ペンギン", emoji: "🐧" },
  { name: "ネコ", emoji: "🐱" },
  { name: "ウサギ", emoji: "🐰" },
  { name: "コアラ", emoji: "🐨" },
  { name: "フクロウ", emoji: "🦉" },
  { name: "ハリネズミ", emoji: "🦔" },
  { name: "クマ", emoji: "🐻" },
  { name: "トラ", emoji: "🐯" },
  { name: "カエル", emoji: "🐸" },
  { name: "ヒヨコ", emoji: "🐤" },
  { name: "イルカ", emoji: "🐬" },
  { name: "タコ", emoji: "🐙" },
  { name: "ラッコ", emoji: "🦦" },
  { name: "シカ", emoji: "🦌" },
  { name: "ハムスター", emoji: "🐹" },
  { name: "オオカミ", emoji: "🐺" },
  { name: "ナマケモノ", emoji: "🦥" },
];

export function randomAlias(): { alias: string; emoji: string } {
  const adj = ADJECTIVES[Math.floor(Math.random() * ADJECTIVES.length)];
  const animal = ANIMALS[Math.floor(Math.random() * ANIMALS.length)];
  return { alias: `${adj}${animal.name}`, emoji: animal.emoji };
}

// Pick an alias not already used in the thread (best effort — falls back after retries).
export function randomAliasAvoiding(used: Set<string>): { alias: string; emoji: string } {
  for (let i = 0; i < 20; i++) {
    const candidate = randomAlias();
    if (!used.has(candidate.alias)) return candidate;
  }
  return randomAlias();
}
