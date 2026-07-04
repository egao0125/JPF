# JPF 🎓 — 日本の大学生のための匿名キャンパスSNS

Fizz / Sidechat スタイルの匿名キャンパスコミュニティ。大学メールアドレス（`.ac.jp`）で認証し、**投稿はすべて匿名** — 自分の大学の学生だけが見えるフィードで、本音で話せる場所。

An anonymous campus community app for Japanese university students, in the style of Fizz / Sidechat. Students verify with their university email (`.ac.jp`), then post anonymously to a feed visible only to their own campus.

| オンボーディング | ようこそ | フィード |
| --- | --- | --- |
| ![Onboarding](docs/screenshot-onboarding.png) | ![Welcome](docs/screenshot-welcome.png) | ![Feed](docs/screenshot-feed.png) |

## 特徴 / Features

- 🏫 **大学スコープ** — メールドメインで大学を判定（サブドメイン対応）。未登録の `*.ac.jp` は自動で大学を作成
- 🎭 **匿名エイリアス** — 投稿ごとにランダムな日本語エイリアス（例: 🦊 ねむいキツネ）。**同じスレッド内では同じ人は同じエイリアス**、投稿主には「主」バッジ
- 📈 **フィード** — 新着 / 急上昇（Reddit式 hot ランキング）/ トップ、チャンネル絞り込み、無限スクロール
- 💬 **ネストコメント**、⬆️⬇️ 投票、カルマ
- 📊 **アンケート**（2〜4択、投票後に結果バー表示）
- 📷 **画像投稿**（JPEG/PNG/WebP/HEIC、5MBまで）
- 🔔 **通知** — 自分の投稿へのコメント、コメントへの返信
- 🚨 **通報 & モデレーション** — 3件の通報で自動非表示、Web管理画面（`/admin`）で削除・BAN
- 👤 **投稿者の選択** — 匿名（ランダムエイリアス）か自分のユーザーネーム（@handle）かを投稿・コメントごとに選べる
- 🤝 **フレンド** — ユーザーネームで申請 → 承認（相互申請は自動承認）
- 💬 **メッセージ** — フレンド同士の1対1チャット（未読バッジ付き）
- 📱 iOS（SwiftUI, iOS 17+）+ Next.js API バックエンド

## 構成 / Architecture

```
JPF/
├── backend/   Next.js 15 (App Router, TypeScript) + Prisma + SQLite
│              REST API (/api/v1/*) + ティザーサイト (/) + モデレーション管理画面 (/admin)
└── ios/       SwiftUI アプリ (iOS 17+, 外部依存なし)
```

> 🕯️ `http://localhost:3000/` はローンチ前のミステリアスなティザーサイト（ウェイトリスト登録付き）。

## セットアップ / Getting started

### 1. バックエンド

```bash
cd backend
npm install
cp .env.example .env
npm run setup      # DB作成 + シードデータ投入（23大学・9チャンネル・デモ投稿）
npm run dev        # http://localhost:3000
```

> 📧 開発モードではメールは送信されません。認証コードは **APIレスポンスの `devCode`** と **サーバーログ** に表示されます（アプリの画面にもヒントとして表示されます）。

### 2. iOSアプリ

```bash
open ios/JPF.xcodeproj
```

Xcode でスキーム `JPF` を選び、iOS シミュレータで実行。デフォルトで `http://localhost:3000` に接続します（マイページ → ⚙️ → サーバー設定で変更可能。実機の場合は Mac の IP アドレスを指定）。

**デモログイン**: `demo0@g.ecc.u-tokyo.ac.jp` などシード済みユーザーのメールを入力 → 画面に表示される開発用コードでログイン。

**モデレーター**: `mod@u-tokyo.ac.jp` でログインすると http://localhost:3000/admin の管理画面が使えます。

### コマンド一覧（backend）

| コマンド | 説明 |
| --- | --- |
| `npm run dev` | 開発サーバー起動 |
| `npm run setup` | DB スキーマ反映 + シード |
| `npm run db:seed` | シードのみ再実行（コンテンツはリセット） |
| `npm run typecheck` | TypeScript チェック |

## API リファレンス

Base URL: `/api/v1` — 認証は `Authorization: Bearer <JWT>`

| Method | Path | 説明 |
| --- | --- | --- |
| POST | `/auth/request-code` | 認証コード送信 `{email}` |
| POST | `/auth/verify` | コード検証 → JWT `{email, code}` |
| GET / PATCH | `/me` | 自分のプロフィール / ユーザーネーム設定 `{username}` |
| GET | `/me/posts` | 自分の投稿一覧 |
| GET | `/schools` | 大学一覧 |
| GET | `/channels` | チャンネル一覧 |
| GET | `/feed?sort=new\|hot\|top&channel=&cursor=` | フィード（自分の大学のみ） |
| POST | `/posts` | 投稿作成 `{channelSlug, text, anonymous?, imageUrl?, poll?}` |
| GET / DELETE | `/posts/:id` | 詳細（コメント込み）/ 削除 |
| POST | `/posts/:id/vote` | 投票 `{value: -1\|0\|1}` |
| POST | `/posts/:id/comments` | コメント `{text, parentId?}` |
| POST | `/comments/:id/vote` | コメント投票 |
| POST | `/polls/:id/vote` | アンケート投票 `{optionId}` |
| POST | `/uploads` | 画像アップロード (multipart `file`) |
| GET | `/images/:name` | 画像取得 |
| POST | `/reports` | 通報 `{targetType, targetId, reason}` |
| GET | `/notifications` / POST `/notifications/read` | 通知 / 既読化 |
| GET | `/friends` | フレンド一覧・届いた申請・申請中 |
| POST | `/friends/requests` | フレンド申請 `{username}` |
| POST | `/friends/requests/:id` | 申請に応答 `{action: accept\|decline}` |
| GET / POST | `/conversations` | 会話一覧 / 会話を開く `{userId}` |
| GET / POST | `/conversations/:id/messages` | メッセージ取得（既読化）/ 送信 `{text}` |
| POST / GET | `/waitlist` | ウェイトリスト登録 `{email}` / 待機人数 |
| GET | `/admin/reports` | 通報一覧（モデレーター） |
| POST | `/admin/reports/:id` | 対応 `{action: remove\|dismiss\|ban}` |

## スケーラビリティ / Scalability notes

- **Keyset（カーソル）ページネーション** — 全フィード・メッセージ取得はインデックス列に対するキーセット方式。オフセット方式と違い、何ページ目でもコストが一定
- **書き込み時 hot スコア** — Reddit式 `sign·log10(|score|) + epoch/45000` を投稿・投票時に `Post.hotScore` へ保存（インデックス付き）。人気フィードは単なる `ORDER BY` で、メモリ内ソートなし
- **レート制限** — 投稿10/分・コメント20/分・DM60/分など（`src/lib/ratelimit.ts`）。単一ノードはインメモリ、水平スケール時はストアをRedisに差し替えるだけ
- **ステートレス認証** — JWT のみでセッションストア不要。アプリサーバーは何台でも並べられる
- **PostgreSQL 移行** — `prisma/schema.prisma` の `provider` を `postgresql` に変えて `DATABASE_URL` を差し替えるだけ（スキーマはPostgres互換で設計）。画像は S3/R2 へ

## 本番運用に向けて / Production TODO

- 📮 メール送信（Resend / SES）— 現状はdevモードでコードをレスポンスに含めるだけ
- 🐘 SQLite → PostgreSQL（Prisma の `provider` 切り替え）
- 🖼️ 画像を S3/R2 等のオブジェクトストレージへ
- 🔐 `JWT_SECRET` の変更、レート制限
- 💬 DM、プッシュ通知（v2）
