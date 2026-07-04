# JPF — Build todo

Plan: Fizz/Sidechat-style anonymous campus app for Japanese universities.
SwiftUI iOS app + Next.js (App Router) API backend, SQLite dev DB.

## Backend
- [x] Scaffold: package.json / tsconfig / next.config / .env / Prisma schema
- [x] Seed: schools (23), 9 channels, demo users/posts/comments/polls
- [x] Auth: request-code → verify → JWT; school from email domain; auto-create unknown *.ac.jp
- [x] Core API: feed (new/hot/top), posts CRUD, votes, nested comments, polls, karma
- [x] Anonymity: per-thread stable aliases (ThreadAlias), OP badge
- [x] Images: multipart upload + serving route (path-traversal safe)
- [x] Reports: auto-hide at 3 reports; notifications on replies
- [x] Admin page: moderator login, report queue, remove/ban
- [x] E2E verify: scripted curl flow — **47/47 checks pass**

## iOS (SwiftUI, iOS 17+)
- [x] Hand-written JPF.xcodeproj (objectVersion 77, synchronized groups) + shared scheme
- [x] Models + APIClient (async/await) + Keychain token store
- [x] Auth flow: welcome → email → code (Return-key submit)
- [x] Feed: sort control, channel chips, pull-to-refresh, infinite scroll, FAB compose
- [x] Post detail: nested comments, reply composer, votes, report/delete
- [x] Compose: text / poll editor / PhotosPicker image
- [x] Profile (karma, my posts, server URL setting) + Notifications tab
- [x] Build verify via xcodebuild — **BUILD SUCCEEDED** (no wedge this time)
- [x] Runtime verify in simulator — login + live feed screenshotted

## Ship
- [x] README (JP+EN, setup + API reference + screenshots)
- [x] Commit + push to github.com/egao0125/JPF

## Review

**Shipped**: full-MVP Fizz/Sidechat clone. Backend: Next.js 15 + Prisma/SQLite,
20 route handlers, all E2E-tested (47 checks: auth, school scoping, feeds,
votes/karma, thread-stable aliases, OP badge, polls, uploads, reports/auto-hide,
moderation, notifications). iOS: 13 Swift files, dark gradient design, verified
running against the live backend in the iPhone 17 Pro simulator.

**Bugs found & fixed during verification**:
1. Seed forgot to wipe Channel table → unique-slug crash on reseed.
2. `URL.appendingPathComponent` percent-escaped `?` in feed query → 通信エラー.
   Fixed with `URL(string:relativeTo:)`.
3. Unsigned sim builds (`CODE_SIGNING_ALLOWED=NO`) can't write Keychain →
   token never persisted. Build signed (ad-hoc) + in-memory token cache.

**Known environment quirk**: this Mac's iOS 26.2 simulator renders ALL emoji as
tofu (verified source bytes are correct UTF-8; Japanese text renders fine).
Works on healthy simulators/devices.
