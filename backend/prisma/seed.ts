import { PrismaClient } from "@prisma/client";
import { randomAliasAvoiding } from "../src/lib/aliases";
import { hotScore } from "../src/lib/ranking";

const prisma = new PrismaClient();

// Domain matching is suffix-based (see auth/request-code), so one root domain
// per school covers student subdomains like g.ecc.u-tokyo.ac.jp or fuji.waseda.jp.
const SCHOOLS: { name: string; shortName: string; domains: string[] }[] = [
  { name: "東京大学", shortName: "東大", domains: ["u-tokyo.ac.jp"] },
  { name: "京都大学", shortName: "京大", domains: ["kyoto-u.ac.jp"] },
  { name: "早稲田大学", shortName: "早稲田", domains: ["waseda.jp", "waseda.ac.jp"] },
  { name: "慶應義塾大学", shortName: "慶應", domains: ["keio.jp", "keio.ac.jp"] },
  { name: "大阪大学", shortName: "阪大", domains: ["osaka-u.ac.jp"] },
  { name: "東北大学", shortName: "東北大", domains: ["tohoku.ac.jp"] },
  { name: "名古屋大学", shortName: "名大", domains: ["nagoya-u.ac.jp", "nagoya-u.jp", "s.thers.ac.jp"] },
  { name: "九州大学", shortName: "九大", domains: ["kyushu-u.ac.jp"] },
  { name: "北海道大学", shortName: "北大", domains: ["hokudai.ac.jp"] },
  { name: "東京科学大学", shortName: "科学大", domains: ["isct.ac.jp", "titech.ac.jp"] },
  { name: "一橋大学", shortName: "一橋", domains: ["hit-u.ac.jp"] },
  { name: "筑波大学", shortName: "筑波", domains: ["tsukuba.ac.jp"] },
  { name: "神戸大学", shortName: "神大", domains: ["kobe-u.ac.jp"] },
  { name: "上智大学", shortName: "上智", domains: ["sophia.ac.jp"] },
  { name: "明治大学", shortName: "明治", domains: ["meiji.ac.jp"] },
  { name: "立教大学", shortName: "立教", domains: ["rikkyo.ac.jp"] },
  { name: "青山学院大学", shortName: "青学", domains: ["aoyama.ac.jp"] },
  { name: "中央大学", shortName: "中央", domains: ["chuo-u.ac.jp"] },
  { name: "法政大学", shortName: "法政", domains: ["hosei.ac.jp"] },
  { name: "同志社大学", shortName: "同志社", domains: ["doshisha.ac.jp"] },
  { name: "立命館大学", shortName: "立命館", domains: ["ritsumei.ac.jp"] },
  { name: "関西大学", shortName: "関大", domains: ["kansai-u.ac.jp"] },
  { name: "関西学院大学", shortName: "関学", domains: ["kwansei.ac.jp"] },
];

const CHANNELS: { slug: string; nameJa: string; emoji: string }[] = [
  { slug: "zatsudan", nameJa: "雑談", emoji: "💬" },
  { slug: "jugyou", nameJa: "授業・履修", emoji: "📚" },
  { slug: "circle", nameJa: "サークル・部活", emoji: "🎾" },
  { slug: "renai", nameJa: "恋愛", emoji: "💘" },
  { slug: "baito", nameJa: "バイト", emoji: "💼" },
  { slug: "shukatsu", nameJa: "就活", emoji: "🎓" },
  { slug: "gourmet", nameJa: "グルメ", emoji: "🍜" },
  { slug: "market", nameJa: "売ります・買います", emoji: "🛒" },
  { slug: "shitsumon", nameJa: "質問", emoji: "❓" },
];

const hoursAgo = (h: number) => new Date(Date.now() - h * 3_600_000);

type SeedComment = { user: number; text: string; score?: number; replies?: SeedComment[] };
type SeedPost = {
  user: number;
  channel: string;
  text: string;
  score: number;
  hoursAgo: number;
  poll?: string[];
  comments?: SeedComment[];
};

const POSTS: SeedPost[] = [
  {
    user: 0, channel: "zatsudan", score: 42, hoursAgo: 2,
    text: "学食のカレー、また値上がりしてた。もう財布が限界",
    comments: [
      { user: 1, text: "わかる。290円時代に戻ってほしい", score: 12 },
      { user: 2, text: "自炊しろって話なんだけど自炊する時間もない", score: 8, replies: [{ user: 0, text: "それな。詰んでる" }] },
    ],
  },
  {
    user: 3, channel: "jugyou", score: 35, hoursAgo: 5,
    text: "線形代数の過去問持ってる人いませんか…単位がかかってます🙏",
    comments: [
      { user: 4, text: "去年のならある。どの先生？", score: 15, replies: [{ user: 3, text: "神。DMできないからここで…〇〇先生です" }] },
      { user: 5, text: "過去問より演習書やった方が受かるよ", score: 5 },
    ],
  },
  {
    user: 6, channel: "renai", score: 89, hoursAgo: 8,
    text: "サークルの同期を好きになってしまったかもしれない。卒業まであと2年、動くべきか耐えるべきか",
    comments: [
      { user: 7, text: "動け。後悔するのは動かなかった時だけ", score: 34 },
      { user: 8, text: "サー内恋愛は気まずくなった時が地獄。よく考えて", score: 21 },
      { user: 6, text: "みんなありがとう。ちょっと勇気出た", score: 18 },
    ],
  },
  {
    user: 1, channel: "shukatsu", score: 27, hoursAgo: 12,
    text: "3年の夏インターン、みんな何社くらい出した？",
    poll: ["0〜3社", "4〜7社", "8〜15社", "16社以上"],
    comments: [{ user: 9, text: "出しすぎても ES 書く時間なくなるから7社くらいが限界だった", score: 9 }],
  },
  {
    user: 2, channel: "gourmet", score: 56, hoursAgo: 20,
    text: "大学周辺のコスパ最強ランチ選手権開催します。エントリーどうぞ",
    comments: [
      { user: 0, text: "裏門近くの中華。半チャンラーメン650円", score: 22 },
      { user: 5, text: "学食が結局最強という説", score: 11, replies: [{ user: 2, text: "それを言ったら終わりなんよ" }] },
    ],
  },
  {
    user: 4, channel: "baito", score: 31, hoursAgo: 26,
    text: "時給1500円超えのバイト、塾講以外で知ってたら教えてほしい",
    comments: [
      { user: 8, text: "試験監督。座ってるだけで1600円のときある", score: 19 },
      { user: 7, text: "治験は最強（自己責任）", score: 13 },
    ],
  },
  {
    user: 5, channel: "circle", score: 24, hoursAgo: 30,
    text: "新歓で勢いで入ったサークル、正直合わない気がしてきた。辞めるタイミングっていつがいい？",
    comments: [{ user: 6, text: "夏合宿の前。金銭的にもそこがライン", score: 16 }],
  },
  {
    user: 7, channel: "zatsudan", score: 73, hoursAgo: 36,
    text: "1限に出席するだけで偉いという風潮、もっと広まってほしい",
    comments: [
      { user: 3, text: "起きた時点で偉い", score: 28 },
      { user: 9, text: "1限取らないという解決策", score: 14 },
    ],
  },
  {
    user: 8, channel: "market", score: 12, hoursAgo: 44,
    text: "ミクロ経済学の教科書（ほぼ新品）譲ります。書き込みなし。学内手渡しで",
    comments: [{ user: 1, text: "ほしいです！受け渡し場所どこらへんですか", score: 3 }],
  },
  {
    user: 9, channel: "shitsumon", score: 18, hoursAgo: 50,
    text: "図書館って何時ごろが一番空いてる？テスト前で席取れない",
    comments: [
      { user: 4, text: "朝イチ。開館直後なら余裕", score: 10 },
      { user: 0, text: "むしろ21時以降が穴場", score: 7 },
    ],
  },
  {
    user: 0, channel: "jugyou", score: 22, hoursAgo: 60,
    text: "履修登録、抽選落ちまくって時間割が虫食いになった。同じ人いる？",
    comments: [{ user: 2, text: "全落ちして週3日登校が確定した。逆に勝ちかもしれない", score: 20 }],
  },
  {
    user: 3, channel: "zatsudan", score: 15, hoursAgo: 66,
    text: "テスト期間の深夜って謎のテンションになるよね。今カラムーチョ3袋目",
    comments: [],
  },
  {
    user: 6, channel: "gourmet", score: 38, hoursAgo: 70,
    text: "深夜に食べるラーメンはなぜあんなにうまいのか。研究テーマにしたい",
    poll: ["醤油", "豚骨", "味噌", "塩"],
    comments: [{ user: 8, text: "深夜補正は+30%うまさ", score: 12 }],
  },
  {
    user: 5, channel: "renai", score: 47, hoursAgo: 1,
    text: "好きな人と同じ授業を取るために抽選に人生を賭けた結果→落ちた",
    comments: [{ user: 7, text: "抽選の神は残酷", score: 15 }],
  },
];

async function main() {
  console.log("Seeding…");

  // Idempotent-ish: wipe content tables (keep it simple for dev)
  await prisma.message.deleteMany();
  await prisma.conversation.deleteMany();
  await prisma.friendRequest.deleteMany();
  await prisma.notification.deleteMany();
  await prisma.report.deleteMany();
  await prisma.pollVote.deleteMany();
  await prisma.pollOption.deleteMany();
  await prisma.poll.deleteMany();
  await prisma.vote.deleteMany();
  await prisma.threadAlias.deleteMany();
  await prisma.comment.deleteMany();
  await prisma.post.deleteMany();
  await prisma.channel.deleteMany();
  await prisma.verificationCode.deleteMany();
  await prisma.user.deleteMany();
  await prisma.schoolDomain.deleteMany();
  await prisma.school.deleteMany();

  const schoolByName = new Map<string, string>();
  for (const s of SCHOOLS) {
    const school = await prisma.school.create({
      data: {
        name: s.name,
        shortName: s.shortName,
        domains: { create: s.domains.map((domain) => ({ domain })) },
      },
    });
    schoolByName.set(s.name, school.id);
  }

  const channelBySlug = new Map<string, string>();
  for (let i = 0; i < CHANNELS.length; i++) {
    const c = await prisma.channel.create({ data: { ...CHANNELS[i], order: i } });
    channelBySlug.set(c.slug, c.id);
  }

  const todai = schoolByName.get("東京大学")!;
  const USERNAMES: (string | null)[] = [
    "taro_2026", "hana_hongo", "yakisoba_panda", null, "shibuya_neko",
    null, "todai_umeshu", null, null, "zenzen_dame",
  ];
  const users = [];
  for (let i = 0; i < 10; i++) {
    users.push(
      await prisma.user.create({
        data: {
          email: `demo${i}@g.ecc.u-tokyo.ac.jp`,
          username: USERNAMES[i],
          schoolId: todai,
          karma: 10 + i * 7,
        },
      })
    );
  }
  await prisma.user.create({
    data: { email: "mod@u-tokyo.ac.jp", username: "mod", schoolId: todai, isModerator: true, karma: 120 },
  });

  // Friends & chat demo: demo0 ↔ demo1 are friends with a conversation;
  // demo2 has a pending request to demo0.
  await prisma.friendRequest.create({
    data: { fromId: users[1].id, toId: users[0].id, status: "accepted" },
  });
  await prisma.friendRequest.create({
    data: { fromId: users[2].id, toId: users[0].id, status: "pending" },
  });
  const [userAId, userBId] = [users[0].id, users[1].id].sort();
  const conversation = await prisma.conversation.create({ data: { userAId, userBId } });
  const CHAT: { from: number; text: string; minutesAgo: number }[] = [
    { from: 1, text: "きのうの雑談チャンネルの投稿、あれ書いたのお前だろw", minutesAgo: 95 },
    { from: 0, text: "なんのことかな〜（すっとぼけ）", minutesAgo: 90 },
    { from: 1, text: "カレーの値上げに一番キレてたの学部で一人しかいない", minutesAgo: 88 },
    { from: 0, text: "バレてるじゃん。てか今日3限出る？", minutesAgo: 30 },
    { from: 1, text: "出る出る。図書館の前で待ち合わせしよ", minutesAgo: 12 },
  ];
  for (const m of CHAT) {
    await prisma.message.create({
      data: {
        conversationId: conversation.id,
        senderId: users[m.from].id,
        text: m.text,
        createdAt: new Date(Date.now() - m.minutesAgo * 60_000),
        readAt: m.from === 1 && m.minutesAgo < 20 ? null : new Date(),
      },
    });
  }
  await prisma.conversation.update({
    where: { id: conversation.id },
    data: { lastMessageAt: new Date(Date.now() - 12 * 60_000) },
  });

  for (const p of POSTS) {
    const createdAt = hoursAgo(p.hoursAgo);
    const usedAliases = new Set<string>();
    const opAlias = randomAliasAvoiding(usedAliases);
    usedAliases.add(opAlias.alias);

    const commentList: { user: number; text: string; score: number; parentKey: number | null; key: number }[] = [];
    let key = 0;
    const flatten = (cs: SeedComment[], parentKey: number | null) => {
      for (const c of cs) {
        const k = key++;
        commentList.push({ user: c.user, text: c.text, score: c.score ?? 0, parentKey, key: k });
        if (c.replies) flatten(c.replies, k);
      }
    };
    flatten(p.comments ?? [], null);

    const post = await prisma.post.create({
      data: {
        authorId: users[p.user].id,
        schoolId: todai,
        channelId: channelBySlug.get(p.channel)!,
        text: p.text,
        score: p.score,
        hotScore: hotScore(p.score, createdAt),
        commentCount: commentList.length,
        createdAt,
      },
    });

    await prisma.threadAlias.create({
      data: { postId: post.id, userId: users[p.user].id, ...opAlias, isOp: true },
    });

    if (p.poll) {
      await prisma.poll.create({
        data: {
          postId: post.id,
          options: {
            create: p.poll.map((text, i) => ({
              text,
              order: i,
              voteCount: Math.floor(Math.random() * 40) + 3,
            })),
          },
        },
      });
    }

    const idByKey = new Map<number, string>();
    for (const c of commentList) {
      // Stable alias per participant within the thread
      const existing = await prisma.threadAlias.findUnique({
        where: { postId_userId: { postId: post.id, userId: users[c.user].id } },
      });
      if (!existing) {
        const a = randomAliasAvoiding(usedAliases);
        usedAliases.add(a.alias);
        await prisma.threadAlias.create({
          data: { postId: post.id, userId: users[c.user].id, ...a },
        });
      }
      const created = await prisma.comment.create({
        data: {
          postId: post.id,
          parentId: c.parentKey === null ? null : idByKey.get(c.parentKey),
          authorId: users[c.user].id,
          text: c.text,
          score: c.score,
          createdAt: new Date(createdAt.getTime() + (c.key + 1) * 600_000),
        },
      });
      idByKey.set(c.key, created.id);
    }
  }

  console.log(`Seeded ${SCHOOLS.length} schools, ${CHANNELS.length} channels, 11 users, ${POSTS.length} posts.`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
