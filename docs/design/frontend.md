# フロントエンド設計 (構造・依存方向・状態・SSE・トークン)

> 本書が回答する本番観点: **A-1 (FE 側のトークン保持)** / **A-2 (ロールによる導線制御)** /
> **A-4 (FE が送れるスコープの形)** / **A-5 (401/403/404 の画面挙動)** / **A-7 (共有 UI の増分)** /
> **O-1 (相関 ID の送出)** /
> **O-4 (失敗をユーザーとログの双方に出す)** / **O-5 (SSE 切断と再接続)** / **D-1 (Vercel の環境)** /
> **D-2 (FE の CI ゲート)**。対象外とした ID とその理由は §13。
> 必須観点 ID 一覧: [../../.claude/rules/08-production-gates.md](../../.claude/rules/08-production-gates.md)
> 対応する受入基準: **AC-1.1 / AC-1.4** (FE 側の振る舞い) / **AC-1.5** (失効・回復に到達できる UI —
> §11.1 の管理者ルート群) / **AC-2.3 / AC-2.4** (FE 起点の観測) /
> **AC-5.2** (CI の機械強制 — 段の定義は [testing.md](testing.md) が SSOT)
> 本書は [plan.md](../../aidlc-docs/inception/productionization/plan.md) の **Task-3l** に相当する。

## 0. 本書の位置づけと SSOT 境界

**backend / frontend / infra のうち frontend だけ構造の設計書が無い**状態を埋める
(リポジトリ構成は 2026-08-03 に app モノレポ + infra リポの 2 分割へ変わり、
`frontend/` は app モノレポのサブツリーになった。構成は [architecture.md](architecture.md) §3.11)。
既にある規約の断片 ([../../templates/app-monorepo/frontend/CLAUDE.md.tmpl](../../templates/app-monorepo/frontend/CLAUDE.md.tmpl)
の 9 節) は**個々の禁止事項**を並べたもので、「どのディレクトリに何を置き、どちらからどちらへ依存してよいか」
という構造が無い。本書はそこを決める。**雛形と矛盾させず、雛形の禁止事項を構造で実現する**関係にある。

**他書が SSOT を持つ事項は本書で再定義しない**。参照して「**FE がどう振る舞うか**」だけを書く:

| 事項 | SSOT | 本書が書くこと |
|---|---|---|
| API の契約 (パス・形・エラー本文・SSE の有無・非同期ジョブ J-1〜J-7) | [API/README.md](API/README.md) と同ディレクトリの各ドメインファイル (一覧は同 §3 の総覧) | 契約を FE がどう消費するか (型の出所・SSE クライアント・エラー表示) |
| 認証・401/403/404 の判定・トークンの有効期間と失効 | [auth.md](auth.md) §6.1 / §6.6 / §6.9 | **ブラウザ側でトークンをどこに置くか**と、各コードで画面がどうなるか |
| テスト方針 (段・FE の UT・E2E 5 本・self-skip 禁止) | [testing.md](testing.md) §4.2 / §7 | テストを可能にする**構造**(純粋関数の分離・依存方向)。テストの中身は書かない |
| Vercel の環境・リリース順序・Production Branch | [operations.md](operations.md) §3.2 / §5.4 | FE 固有の環境変数の分類と、秘密を露出させない置き方 |
| 計測項目・失敗分類 (F-1〜F-6)・keep-alive 15 秒 | [observability.md](observability.md) §4.1 / §4.3 / §4.4 | FE が送る相関 ID と、FE が検知する失敗の出し方 |
| データモデル (ID の型・列) | [data-model.md](data-model.md) | 画面が扱う ID の型は同書に従う (**3 種類ある**。下記) |
| 層構造・依存規則 (backend の L-1〜L-6) | [architecture.md](architecture.md) §3.5 | **FE 側の依存規則 (L-F1〜L-F6)**。backend の規則を FE に流用しない |

**ID の型は 1 種類ではない** ([data-model.md](data-model.md) DM-1)。**FE は 3 種類を区別する**:

| 対象 | DB の型 | TS の型 | 該当する画面 (§11.1) |
|---|---|---|---|
| 機能リソース (テーマ・アセット・アイデア・ボード・スレッド・抽出ジョブ) | `bigint` | **`number`** | 大半の詳細画面 |
| **アカウント・契約** (アイデンティティ基盤) | **`uuid`** | **`string`** | `/settings/members` / `/themes/[themeId]/members` / `(admin)/admin/accounts` |
| **外部 CMS の ID** (`read_news_accounts.news_id`) | **`text`** | **`string`** | `/news/[newsId]` |

**Next.js のルートパラメータは常に `string`** である。したがって
**`number` 側だけが「ルートパラメータ → ID」の変換を必要とする**。
この変換は `features/<d>/lib/` の純粋関数 1 つに閉じ (§8.1)、`Number.isSafeInteger` で検証し、
不正なら 404 相当の画面 (`notFound()`) にする。**`uuid` / `text` の ID は変換しない** —
`Number()` を通すと `NaN` になり、通ってしまうと別リソースを引く。
**却下**: 全 ID を `string` として扱い API 呼び出し時に変換する案 — 生成型 (`number`) と食い違い、
tsc の防御 (§5.3) が効かなくなる。

**プロトタイプの扱い (DR-7)**: [../prototype/hassan_agent_prototype_v2.html](../prototype/hassan_agent_prototype_v2.html)
は**設計入力であって仕様ではない** ([../prototype/README.md](../prototype/README.md))。
本書で画面を列挙する §11 では、**API 設計で契約が確定している画面**と
**プロトタイプにしか根拠が無い画面**を列に分けて区別する。後者は仕様として確定させない。
**注 (2026-07-30)**: プロトタイプが更新版 (15,022 行) に差し替わった。本書のプロトタイプ引用行番号は
更新版の実測値へ更新済み。**更新で画面側の前提が変わった箇所は各 API 設計の再確認事項に起票した**
([API/themes.md](API/themes.md) §6 / [API/settings.md](API/settings.md) §7.1 / [API/idea-boards.md](API/idea-boards.md) §6.1 /
[API/knowledge.md](API/knowledge.md) KN-Q8〜Q10)。**TH-Q6〜Q9 / ST-Q8〜Q9 / IB-Q11〜Q13 は 2026-07-30 に回答済み**
(各ファイルの `[Answer]:` を参照) — ルート表 (§11.1) には反映済み (`/settings/workspace` は増分 2 へ)。

---

## 1. 現状 (v2 / PoC) と継承可否

### 1.1 v2 frontend の実測 (事実)

**調査範囲**: 指示により 6 点 (ディレクトリ構成 / 状態管理 / orval / SSE / デザイントークン / PoC の SSE と lib) に限定した。
**未調査**: コンポーネントの粒度と命名、Storybook の運用実態、`src/utils` と `src/lib` の使い分け、
`features/*/` 内部の下位ディレクトリ規約の一貫性、`src/app/api/` の 3 つの Route Handler の役割
(`draft` / `disable-draft` は microCMS のプレビュー用と推測されるが未確認)。

| # | 事実 | 出典 |
|---|---|---|
| V-1 | トップレベルは `src/{app, components, features, generated, lib, providers, styles, utils}` + `src/middleware.ts`。`features/` は 9 ドメイン (`admin` / `ai-sheet` / `auth` / `business-plan` / `idea` / `idea-board` / `news` / `research` / `settings`) | 実測 `ls src` / `ls src/features` (`hassan-v2-frontend/src`) |
| V-2 | Next.js **15.5.9** / React **19.1.2** / TypeScript **5.3.3** / Tailwind **3.4.1** / Node **22.x** | `hassan-v2-frontend/package.json` |
| V-3 | **サーバ状態の取得・更新は Server Component と Server Actions が担う**。`'use server'` を持つファイルが **107 件**、`'use client'` が **192 件**。`features/<domain>/actions/` に API 呼び出しが集まる | 実測 `grep -rl "^'use server'" src \| wc -l` / 同 `'use client'` / `ls src/features/ai-sheet/actions` |
| V-4 | **サーバ状態のキャッシュライブラリは無い** (TanStack Query / SWR は依存に無い)。クライアント状態は **zustand** が **6 ファイル**で、うち **4 つがストリーミング用の store** (`stream-research` / `stream-idea` / `stream-business-plan` / `stream-ai-sheet-store`) | `hassan-v2-frontend/package.json:85` (zustand) / 実測 `grep -rln zustand src` → `hassan-v2-frontend/src/features/research/states/stream-research.ts` 他 5 件 |
| V-5 | URL クエリ状態は **nuqs**。フォームは **react-hook-form + zod** と **@conform-to/react + @conform-to/zod** の **2 系統が併存**。UI は **Radix UI primitives + class-variance-authority + tailwind-merge** (shadcn/ui 方式。`components.json` が存在) | `hassan-v2-frontend/package.json:64` (nuqs) / 同ファイルの `@conform-to/*` と `react-hook-form` / `hassan-v2-frontend/components.json` |
| V-6 | orval は **稼働中サーバの URL を入力**にする (`input.target: 'http://localhost:8081/swagger/doc.json'`)。出力は `mode: 'tags-split'` で `src/generated/models` (スキーマ) と `src/generated/petstore.ts`、`client: 'fetch'`、mutator は `src/lib/api-client.ts` の `apiClient` | `hassan-v2-frontend/orval.config.js:20-22` (入力) / `:6-9` (出力) / `:13-17` (mutator) |
| V-7 | `apiClient` は **`getServerSession` を呼ぶ**ためサーバ側でしか動かない。ヘッダは **`X-Token` と `X-Admin-Token` の両方に同じセッショントークンを常に入れる**。タイムアウトは **8 分固定**、`AbortController` で中断する | `hassan-v2-frontend/src/lib/api-client.ts:38-49` (ヘッダ) / `:4` (タイムアウト) / `:51-79` |
| V-8 | API のベース URL は **`NEXT_PUBLIC_API_BASE_URL`** = **ブラウザバンドルに載る** | `hassan-v2-frontend/src/lib/api-client.ts:21` |
| V-9 | **SSE の読み取りループが 7 ファイルに複製**されている。うち 1 つに**「ストリーム処理は共通化する」という未対応コメント**が残る (原文は出典の行を参照) | 実測 `grep -rl "text/event-stream\|getReader()" src` → 7 件 (`features/ai-sheet/{actions,hooks}` 2 件 / `features/business-plan/actions` 4 件 / `features/research/actions` 1 件) / `hassan-v2-frontend/src/features/research/actions/create-stream-research-chat.ts:17` |
| V-10 | その SSE 実装は **orval 生成型と並行して手書きの `StreamResponse` 型を持つ** (型のドリフト) | `hassan-v2-frontend/src/features/research/actions/create-stream-research-chat.ts:9-15` (手書き型) と `:73` (生成型 `DtoCustomResearchStreamRes` を同時に使う) |
| V-11 | その SSE 実装は **`'\n'` 単位で分割し、空行を捨て (`if (!trimmedLine) continue`)、`data: ` 前置詞の行だけを見る**。`event:` 名は読まない。**`AbortSignal` を `fetch` に渡していない**。さらに **JSON パース失敗を `console.error` 1 行で捨てる** (ユーザーにも構造化ログにも出ない) | `hassan-v2-frontend/src/features/research/actions/create-stream-research-chat.ts:61-63` (分割) / `:66-68` (空行を捨てる) / `:71-72` (`data: ` のみ) / `:23-35` (signal 無し) / `:100-104` (パース失敗の握り潰し) |
| V-12 | **SSE はブラウザから BE を直接叩く**。呼び出し元は `'use client'` のコンポーネントで、**`session.data?.user.token` (BE の JWT) をヘッダに入れて渡す** = **JWT がブラウザの JS から読める** | `hassan-v2-frontend/src/features/research/components/research-list-form.tsx:1` (`'use client'`) / `:37-41` (JWT をヘッダへ) |
| V-13 | セッションは **next-auth の JWT 戦略**で、`session.maxAge` / `jwt.maxAge` が **1 週間**。`session` コールバックで **BE の JWT を `session.user.token` に載せる** | `hassan-v2-frontend/src/lib/auth.ts:126-132` / `:134-141` |
| V-14 | 未認証の遮断は **`src/middleware.ts`** が担う。`getToken` でセッション Cookie を読み、`token.requiredMfaType !== 'totp'` を認可条件にして満たさなければ `/login` にリダイレクトする。**除外パスは matcher の否定正規表現 1 本**で表現されている | `hassan-v2-frontend/src/middleware.ts:23-27` / `:29-34` / `:39-42` |
| V-15 | **デザイントークンは存在する** — `tailwind.config.ts` の `theme.extend` に色・角丸・フォントサイズ・margin・padding・影が定義されている。ただし**名前が意味を持たない**: 色は `blue.10`〜`blue.90` / `gray.10`〜`gray.110` のような**番号連番 + 生の hex**、間隔は `sizeXS`〜`size5XL` | `hassan-v2-frontend/tailwind.config.ts:12-54` (色) / `:55-59` (角丸) / `:60-72` (フォントサイズ) / `:73-97` (margin / padding) |
| V-16 | それでも**トークン外の手書き CSS が残っている** (`globals.css` に `.status-message-*` 等のクラスと keyframes) | `hassan-v2-frontend/src/styles/globals.css:43-60` |
| V-17 | **eslint に依存方向・トークン強制のルールが無い**。設定されているのは `no-console` / `consistent-type-imports` / `unused-imports` / `as` 禁止 / `no-unused-vars` の 5 つ。`eslint-plugin-import` も `eslint-plugin-tailwindcss` も入っていない | `hassan-v2-frontend/.eslintrc.json:9-19` |
| V-18 | **CI が無い / 単体テストの基盤が無い** (`.github/` が無く、`package.json` の scripts に `test` が無い。Playwright の E2E 2 本のみ)。**E2E は対象データが無いと `test.skip` で緑になる** | [testing.md](testing.md) §1.2 の **T-F9 / T-F10 / T-F13** (同書が SSOT。本書で再測しない) |
| **V-19** | **社内管理者 UI は一般ユーザーと同一の Next.js アプリに同居している** — 管理者サインインは `(auth)/admin/login`、管理者向け画面は `app/admin/` 配下に 8 ページ (`activity-status` / `admin-setting` ×3 / `company` / `settings/account` 系 / `user`)。**next-auth のインスタンスは 1 つで、`signIn` / `adminSignIn` / `mfaSignIn` の 3 provider が同じセッション Cookie を書く** | 実測 `find src/app -name page.tsx` (`hassan-v2-frontend`) / `hassan-v2-frontend/src/lib/auth.ts:31-33` (`signIn`), `:66-67` (`adminSignIn`), `:97-98` (`mfaSignIn`), `:126-132` (3 provider が共有する単一の `session.maxAge` / `jwt.maxAge`) |
| **V-20** | **`X-Token` と `X-Admin-Token` に同じ値を送る構造的な原因が V-19 にある** — セッションに入っているのが一般ユーザーのトークンか管理者トークンかを**セッションからは区別できない**ため、両方のヘッダに入れる以外の実装がない | `hassan-v2-frontend/src/lib/api-client.ts:38-49` (両ヘッダに同一値。V-7) と `hassan-v2-frontend/src/lib/auth.ts:134-153` (session / jwt コールバックが provider を区別せず `token.token` に詰める) |
| **V-21** | **`/mfa` は middleware の matcher から除外されている** = **未認証でも `/mfa` に到達できる**。除外されているのは `signup` / `reset-password` / `admin/login` / `admin/accounts/password` / `login/lock` / **`mfa`** / `one-time-password` / `api` / 静的ファイル。MFA 検証画面は `(auth)/mfa/page.tsx`、ワンタイムパスワード画面は `(auth)/one-time-password/page.tsx` に実在する | `hassan-v2-frontend/src/middleware.ts:39-42` (matcher の否定正規表現) / 実測 `find src/app -name page.tsx` |

### 1.2 PoC frontend の実測 (事実)

| # | 事実 | 出典 |
|---|---|---|
| P-1 | React 18 + Vite + vitest。orval は無く、**API クライアントは手書き**。`src/lib/api.ts` は **4330 行** | 実測 `wc -l` (`claude_managed_agents/frontend/src/lib/api.ts`) |
| P-2 | `src/lib/` に **47 の非テストファイル**が並び、**API クライアント・純粋パーサ・localStorage 永続化・デザイントークンが同じ階層に混在**する | 実測 `ls src/lib \| grep -v test` (`claude_managed_agents/frontend/src/lib`) / `claude_managed_agents/frontend/src/lib/idea-local-storage.ts` |
| P-3 | **SSE のブロックパーサは 1 本に共通化されている** (`parseSSEBlock`)。`event:` 名を読み、複数の `data:` 行を `\n` で連結する | `claude_managed_agents/frontend/src/lib/sse.ts` |
| P-4 | ただし **各 `data:` 行を `.trim()` している**ため、本文行の先頭・末尾の空白が落ちる (markdown のインデント・コードブロックが壊れる)。また **`data:` 行が 0 本のブロックは `null` を返す**ため、`event:` だけのイベントを表現できない | `claude_managed_agents/frontend/src/lib/sse.ts:15` / `:19-21` |
| P-5 | **`AbortError` は既に正常系として握り潰されている** (FE-1 への対処が PoC には入っている) | `claude_managed_agents/frontend/src/lib/conversation-api.ts:74-75` |
| P-6 | デザイントークンは **TS 定数 + hex** (`design-tokens.ts`)。コメントに「Phase 1 までは `AssetsView.tsx` に直接 hex を書いていたが、トークン化した」と記録がある = **機械強制が無いと hex 直書きに戻る**ことの実例 | `claude_managed_agents/frontend/src/lib/design-tokens.ts:21-25` |
| P-7 | LLM 出力の数値化 (市場規模のレンジ) は純粋関数に分離されていたが、**それでも FE-6 (「120-420億円」を「-420億円」と誤抽出) が起きた** = 分離だけでは足りず、テストが必要 | `claude_managed_agents/frontend/src/lib/plan-market-chart.ts` / [../../.claude/rules/feedback_review_patterns.md](../../.claude/rules/feedback_review_patterns.md) FE-6 |

### 1.3 継承可否

| 対象 | v3 で | 理由 |
|---|---|---|
| Next.js App Router / React / TypeScript / Tailwind / Node のバージョン水準 | **継承** (マイナー追従のみ) | [design_memo.md](design_memo.md):16 で「大きな更新は不要」と確認済み |
| Server Component + Server Actions によるサーバ状態の扱い (V-3) | **継承** | 稼働中の方式であり、RSC 前提の Next.js 15 と整合。§4 の FE-C |
| ディレクトリのトップレベル構成 (V-1) | **継承** + 内部規約を追加 | 骨格は妥当。欠けているのは `features/` 内部の規約と依存方向の強制 (§3) |
| Radix + cva + tailwind-merge の UI 層 (V-5) | **継承** | §2 の FE-N |
| orval + swaggo (V-6) | **方式は継承・入力は変更** | 稼働サーバ URL 入力は CI で型ズレを検知できない ([API/README.md](API/README.md) の D-API-13 が既に決定済み)。§5 |
| フォームライブラリ 2 系統併存 (V-5) | **1 系統に統一** | §2 の FE-O |
| `X-Token` と `X-Admin-Token` を常に両方送る (V-7) | **継承しない** | 一般ユーザーの経路で管理者トークンヘッダを送る理由が無く、[auth.md](auth.md) §6.7 の系統別検査と食い違う |
| **単一の next-auth セッションで一般ユーザーと社内管理者を兼ねる (V-19 / V-20)** | **継承しない** | セッションからトークンの系統を区別できないことが V-7 の直接の原因。**Cookie を系統ごとに分ける** (§2 の FE-D') |
| **`/mfa` を middleware の対象外にする (V-21)** | **継承しない** | 「未認証で入れるパス」と「MFA 未検証で入れるパス」を同じ除外リストで表現しているため、MFA 検証画面が未認証に開いている。**許可リストを 2 本に分ける** (§11.2) |
| **ブラウザに BE の JWT を渡す構造 (V-12)** | **継承しない** | §2 の FE-D (XSS 1 件で 7 日有効なトークンが漏れ、失効手段は手動ロックのみ — [auth.md](auth.md) §6.9) |
| `NEXT_PUBLIC_API_BASE_URL` (V-8) | **継承しない** | FE-D でブラウザから BE を直接叩かなくなるため、ベース URL はサーバ専用の環境変数になる (§12) |
| SSE の per-feature 実装 (V-9〜V-11) | **継承しない** | 共通クライアント 1 本にする ([design_memo.md](design_memo.md):150 の決定)。§6 |
| デザイントークンの命名 (V-15) | **体系を作り直す** | 番号連番の名前は「どれを使うか」を実装者判断にする (DR-5)。§7 |
| eslint の設定 (V-17) | **拡張する** | 依存方向とトークンを機械強制する (§3.3 / §7.2) |
| CI・単体テストの基盤 (V-18) | **新規に作る** | 継承できるものが無い ([testing.md](testing.md) §1.4 の 2) |
| PoC の `parseSSEBlock` (P-3 / P-4) | **仕様は参考にし、実装は書き直す** | `.trim()` と「`data:` 0 本で `null`」は v3 の要件 (空行を本文として通す / `event:` のみのイベント) と両立しない |
| PoC の `lib/` 平置き (P-1 / P-2) | **継承しない** | 4330 行の API クライアントと純粋関数が同階層にあると依存方向を機械強制できない (DR-4) |

---

## 2. 設計判断

判断が割れた場合は **v2 の既存規約に寄せる** (ルート `CLAUDE.md`)。逸脱には却下案と理由を書く。

| # | 論点 | 採用案 | 却下案と理由 |
|---|---|---|---|
| **FE-A** | ディレクトリ規約 | **v2 のトップレベル (V-1) を踏襲**し、`features/<domain>/` の内部を **`api/` `components/` `hooks/` `lib/` `types.ts` の固定 5 種**に定める (§3.1)。`app/` はルーティングと `page.tsx` / `layout.tsx` / `loading.tsx` / `error.tsx` のみを置き、**画面の実装は `features/` に置く** | (a) **PoC の平置き `lib/`** (P-1 / P-2): 47 ファイルが同階層に並び、API クライアントと純粋関数の境界が消えて依存方向を強制できない。(b) **`app/` に画面実装をコロケーションする**: ルーティングの都合 (ルートグループ・並行ルート) でファイルが移動するとテストと import が一斉に壊れる。v2 の 9 features はこの形を採らずに成立している。(c) **ドメイン層を切り出した完全な DDD 分割** (`domain/` `application/` `infrastructure/`): backend の 6 層と対称になるが、FE には**トランザクション境界も永続化も無い**ため層が空になり、`features/` との二重管理になる |
| **FE-B** | 依存方向の機械強制 | **`eslint-plugin-import` の `import/no-restricted-paths` で zone を定義**し、`npm run lint` = CI ゲート (D-2) で落とす (§3.3 の L-F1〜L-F6) | (a) **規約文書に書くだけ**: 雛形 [CLAUDE.md.tmpl](../../templates/app-monorepo/frontend/CLAUDE.md.tmpl) は既に「純粋ロジックに React hook / JSX を持ち込まない (FE-5)」を禁止として書いているが、**それを検知する仕組みが無い** — v2 の eslint 設定にも依存方向のルールは 1 つも無い (V-17)。FE-5 は PoC で実際に起きたパターンであり、禁止の記述だけでは再発を防げない。(b) **`dependency-cruiser`**: 表現力は高いが CI 専用のツールが 1 つ増え、**エディタ上で違反が出ない**ため気付くのがコミット後になる。(c) **`eslint-plugin-boundaries`**: 宣言は読みやすいが v2 に前例が無く、`eslint-plugin-import` は他ルール (`import/order` 等) でも使うため導入コストが小さい方を採る |
| **FE-C** | サーバ状態の扱い | **既定は Server Component が orval の生成関数を直接呼ぶ** (v2 踏襲。V-3)。更新は **Server Action** + `revalidateTag`。**クライアント主導の再取得が必要な 2 経路だけを例外**にする: ①非同期ジョブの状態ポーリング ([API/README.md](API/README.md) J-6 / J-7) ②会話ターンの SSE。この 2 つは **`features/<domain>/hooks/` の専用フックが持ち、キャッシュライブラリを使わない** | (a) **TanStack Query / SWR を全面導入**: v2 に前例が無く (V-4)、**RSC のキャッシュと二重のキャッシュ層**になる。さらに SSE と長時間ジョブは Query のモデル (キー + fetcher + 再検証) に載らないため、結局例外実装が要る。(b) **v2 の zustand store 方式をストリーミング以外にも広げる** (V-4): サーバ状態のコピーがクライアントに増え、更新後の同期が手動になる。(c) **例外を認めず全てを RSC の再検証で回す**: ジョブの進捗は数秒間隔で変わるため、ページ全体の再検証はコストが合わない |
| **FE-C'** | クライアント状態の置き場 | **3 分類に固定する** (§4.2): ①**URL に置く** (一覧の絞り込み・ソート・ページ・選択タブ) = **nuqs** (v2 に既存。V-5) ②**画面ローカルの複合状態** (会話ターン・ジョブ進捗・ウィザード) = **`useReducer` + 純粋 reducer** ③**画面を跨いで共有する一時状態のみ zustand**。**②を zustand に置かない** | (a) **v2 の形 (ストリーミング状態を zustand の global store に置く。V-4 の 4 store)**: 会話は「履歴 GET で復元 + 再接続」が仕様 ([design_memo.md](design_memo.md):169) なので、**global store と履歴 API が同じ状態の 2 つのソースになる**。加えて store をまたぐテストは reducer 単体テストより書きにくい (FE-4)。(b) **すべて `useState` で持つ**: 会話ターンは「本文追記 + ツール状態 + オプション + 中断」の複合状態で、`useState` の分割は更新順序のバグを生む。(c) **絞り込み状態を React state に持つ**: 再読込・共有・戻る操作で消える (v2 が nuqs を入れた理由と同じ) |
| **FE-D** | **トークンの保持と BE の呼び出し経路** | **BE の JWT は next-auth の HttpOnly セッション Cookie 内にのみ置き、ブラウザの JS から触れない**。BE への呼び出しは**すべてサーバ側** (Server Component / Server Action / **Route Handler**) から行い `X-Token` を付ける。**SSE も Next.js の Route Handler で中継する** (§6.3)。**`X-Admin-Token` は送らない** | (a) **v2 方式 (ブラウザに JWT を渡して BE を直接叩く。V-12)**: XSS 1 件で**有効期間 7 日・リフレッシュなし**のトークンが漏れる ([auth.md](auth.md) §6.9)。失効手段は**手動ロック API のみ**で、漏洩に気付いてから人が操作するまで有効。加えてブラウザ直叩きは **Vercel の Preview URL が変動するため BE の CORS 許可リストを維持できない** ([operations.md](operations.md) §3.2 の確認事項 / v2 の許可リストはハードコード — [API/README.md](API/README.md) F-14)。(b) **`localStorage` に保持**: (a) より悪く、Cookie の `HttpOnly` すら失う。(c) **BE に FE 専用の Cookie 認証を新設**: [auth.md](auth.md) §6.1 が `X-Token` 踏襲を決めており、BE 側の逸脱を FE の都合で作ることになる。(d) **BE が SSE 用の短命チケットを発行し、ブラウザが直接 SSE を張る**: 中継のホップが消える利点はあるが、**(a) で却下した CORS の問題 (Preview URL の可変オリジン) をそのまま再現する** — (d) は「(a) より漏洩耐性の高い資格情報を使う案」であって CORS を解く案ではない。加えて BE の新規 API (チケット発行) と失効管理が増える。**FE-Q2 (Vercel で 5 分の中継ができるか) が不成立だった場合の唯一の代替**として §16.1 に骨子を残すが、**成立条件 (許可オリジンの決め方) が未解決であり、採否はユーザー決定を要する** |
| **FE-D'** | **社内管理者経路 (サインイン / ロック解除 / アカウント検索 / 管理者一覧) の置き場とトークンの分離** | **`(admin)` ルートグループに分け、`X-Admin-Token` を別ストアで保持する**。**2026-08-10 の AA-D-22 で MFA の登録・検証・リセットの 3 画面が消え、`(admin)` は 4 画面になった** | (a) 一般ユーザーと同じレイアウトに混ぜる: トークンの取り違えが型で防げない |
| **FE-E** | 型の唯一のソース | **orval 生成物 (`src/generated/`) が唯一の API 型**。入力は **同一リポジトリの `api/` にコミットされた OpenAPI 定義** (D-API-13。**2026-08-03 のモノレポ化で「別リポからの取得」が不要になった**)。**手書きの API 型を作らない**。生成物は**コミットし、CI で再生成差分を検査**する (雛形 [ci.yml](../../templates/app-monorepo/.github/workflows/ci.yml) の `contract` ジョブ が既にこの形) | (a) **v2 方式 (稼働サーバ URL を入力。V-6)**: BE をローカル起動しないと型を更新できず、**CI が型ズレを検知できない** (D-API-13 で既に却下済み)。(b) **`openapi-typescript` に替える**: v2 は orval に加えて `openapi-typescript` も依存に持つが、生成関数 (fetch ラッパ) と **MSW ハンドラ**を得られるのは orval 側で、[testing.md](testing.md) T-O が MSW ハンドラの生成を前提にしている。(c) **backend リポを git submodule にする**: 3 リポ構成での案。FE の `npm ci` に BE の取得が要り、Vercel のビルドが BE リポの権限に依存する。**モノレポ化により検討不要になった** |
| **FE-E'** | **snake_case の扱い (FE-2)** | **変換しない**。BE の JSON キーは snake_case ([API/README.md](API/README.md) D-API-4) で、**生成型のまま使う**。表示のために別の形が必要な場合のみ、`features/<domain>/lib/` に **ViewModel 型と一方向の変換関数 (生成型 → ViewModel)** を置き、テストを併置する | (a) **API 境界で全レスポンスを camelCase に自動変換**: 変換器が**第 2 のスキーマ**になり、BE のフィールド追加が黙って落ちる (BE-12 の FE 版。PoC の手書きマッパー `claude_managed_agents/frontend/src/lib/conversation-api.ts` がこの形)。(b) **orval の命名変換で camelCase の型を生成する**: 生成型と実際の JSON キーが食い違い、**SSE の payload (生成型を通る経路と通らない経路が混在する) と MSW ハンドラで不整合**が出る。(c) **ViewModel を作らず生成型を全コンポーネントに流す**: 表示都合の整形がコンポーネントに散り、FE-6 のようなパースがテスト対象外の場所に生まれる |
| **FE-F** | SSE クライアント | **共通クライアント 1 本** (`src/lib/sse/`) に集約する。仕様は §6.2 (ブロック分割・`event:` 名・空行を本文として通す・discriminated union への振り分け・`AbortError` は正常系・無通信タイムアウト・履歴 GET からの復元) | (a) **v2 の per-feature 実装** (V-9 の 7 ファイル): 共通化の未対応コメントが残ったまま複製が増えた実例そのもの。1 箇所の修正が他 6 箇所に伝播しない。(b) **`EventSource` を使う**: **ヘッダを付けられず POST もできない** — `X-Token` / `X-Request-Id` を送れないため FE-D と両立しない。(c) **PoC の `parseSSEBlock` をそのまま流用**: 各 `data:` 行を `.trim()` するため本文のインデントが壊れ (P-4)、`data:` 0 本のブロックを `null` にするため `event:` のみのイベントを表現できない |
| **FE-G** | デザイントークン | **Tailwind の `theme.extend` を唯一の定義場所**にし、**意味ベースの名前**に作り直す (§7.1)。**hex リテラル・任意値 (`w-[13px]`)・トークン外のクラス新規追加を lint で禁止**する (§7.2) | (a) **v2 の命名を踏襲** (V-15 の `blue.10`〜`blue.90`): 名前が意味を持たないため実装者が既存例を探して判断することになり、結果として**トークン外の手書き CSS が積む** (V-16 が実例)。(b) **PoC の TS 定数 + inline style** (P-6): Tailwind と二重管理になり lint で強制できない。**強制が無いと hex 直書きに戻る**ことを PoC のコメントが記録している。(c) **shadcn/ui の既定トークンのみ**: 中立的だが、プロトタイプが持つ配色・角丸・余白の体系を表現できず、実装時に任意値が増える |
| **FE-H** | LLM 出力の変換処理の置き場 | **`features/<domain>/lib/` の純粋関数として置き、必ず `export` し、同名の `*.test.ts` を併置する** (存在検査を CI で行う。§8)。**数値・レンジ・単位のパースは `src/lib/parse/` に集約**する | (a) **コンポーネント内に inline で書く**: テストできず FE-4 (パーサーの非 export) と同じ状態になる。(b) **分離するだけでテストを必須にしない**: PoC は分離していたが FE-6 が起きた (P-7) — 分離は必要条件でしかない。(c) **BE 側で数値化して構造で返す**: 正しい方向だが、[API/README.md](API/README.md) の対象外 (会話・企画書) を含めて全経路を BE 構造化に寄せる決定はまだ無い。**FE は「与えられた文字列を数値化する処理が残る前提」で構造を用意する** (BE 構造化が進めば §8 の対象は減る) |
| **FE-I** | エラー表示 | **HTTP ステータスで分岐し、文言は BE の `message` を既定で表示する** ([API/README.md](API/README.md) D-API-6)。**FE 側にコード → 文言の辞書を持たない**。`request_id` をエラー表示に含める (§9) | (a) **FE がコード別の文言辞書を持つ**: BE のコード追加が FE に伝播せず、辞書に無いコードが空表示になる (BE-2 型の 2 層散在)。(b) **ステータスだけで分岐し `message` を捨てる**: 409 の理由 (テーマ名重複 / フェーズ名重複 / 二重追加) を区別できない。(c) **`request_id` を出さない**: [observability.md](observability.md) §4.1 で全ログに `request_id` が載るのに、ユーザー報告から突き合わせる手段が無くなる |
| **FE-J** | 生成中・ローディングの表現 | **ストリーミング状態を 5 値の判別可能な union で持つ** (`idle` / `streaming` / `done` / `canceled` / `failed`)。一覧・詳細は RSC の `loading.tsx` + Suspense。**ストリーミング中は常に中断ボタンを出し、中断は正常系**。**無通信 45 秒でタイムアウト表示**にする (keep-alive 15 秒の 3 倍。[observability.md](observability.md) §4.4) | (a) **スピナーのみで状態を持たない**: 中断・失敗・完了が同じ見た目になり、**無言で止まる UI** になる (雛形 CLAUDE.md.tmpl の禁止事項)。(b) **タイムアウトを持たない**: v2 は 8 分の固定タイムアウト (V-7) しか無く、その間ユーザーは処理中と区別できない。(c) **keep-alive と同じ 15 秒で切る**: 1 回の欠落で切断扱いになり誤検知する |
| **FE-K** | ルーティング | **App Router + ルートグループ `(auth)` / `(app)`**。未認証の遮断は **`middleware.ts` で行い、除外パスを配列の許可リストで宣言する** (§11.2) | (a) **v2 の matcher 否定正規表現 1 本** (V-14): 新しい公開パスの追加が正規表現の編集になり、**書き間違えると全ページが素通り**する。[auth.md](auth.md) §6.7 が BE 側で「公開だけを別グループに切り出す」形を採ったのと同じ構造にする。(b) **各 `page.tsx` でセッションを確認する**: 追加漏れが素通りとして現れ、機械検出できない (v2 BE の §5-5 と同型) |
| **FE-L** | 相関 ID | **FE が `X-Request-Id` (ULID) を生成して BE への全リクエストに付ける** ([observability.md](observability.md) §4.1 が「あれば尊重」と定義済み)。生成はサーバ側の 1 箇所 (API クライアントの mutator と SSE 中継) | (a) **BE 生成に任せる**: BE に到達しなかった失敗 (中継層・ネットワーク・Vercel 側のタイムアウト) を BE のログと突き合わせられず、O-4 の FE 側が観測不能になる。(b) **ブラウザで生成してヘッダに載せる**: FE-D で直叩きしないため経路が無い |
| **FE-M** | UI コンポーネントライブラリ | **v2 と同じ Radix UI primitives + cva + tailwind-merge (shadcn/ui 方式) を継承**する (V-5) | (a) **MUI 等の完成品**: v2 のコンポーネント資産とトークン体系を捨てることになり、プロトタイプの見た目にも寄せにくい。(b) **フルスクラッチ**: ダイアログ・セレクト・タブのアクセシビリティを自前で持つコストが大きい。(c) **プロトタイプの HTML/CSS を移植する**: プロトタイプは仕様ではなく (DR-7)、単体 HTML の CSS には状態管理もアクセシビリティも無い |
| **FE-N** | フォーム | **react-hook-form + zod に統一**する。zod スキーマは**生成型から導出できる範囲は導出し、独自定義を最小にする** | (a) **v2 の 2 系統併存を継承** (V-5 の conform + react-hook-form): 実装者が毎回どちらかを選ぶことになり、レビュー観点も二重になる (DR-5)。(b) **conform に統一**: Server Actions との相性は良いが、v2 の既存コンポーネント (`react-hook-form` を前提にした `TextAreaWithSendButton` 等) の移植量が増える |

**本節が回答する ID: A-1 (FE-D) / A-2 (FE-D') / O-1 (FE-L) / O-4 (FE-I / FE-J) / O-5 (FE-F / FE-J) /
D-2 (FE-B / FE-E)**

---

## 3. ディレクトリ構成と依存方向

> 本節が回答する ID: **D-2** (lint による機械強制) / 対応パターン: **FE-4 / FE-5**

### 3.1 構成 (FE-A)

```
src/
  app/                       ルーティングのみ (page / layout / loading / error / route.ts)
    (auth)/…                 未認証 / MFA 未検証で到達する画面 (§11.2)
    (app)/…                  認証必須 + MFA 検証済みの画面
    (admin)/admin/…          社内管理者の画面 (§11.3。セッション Cookie が別)
    api/auth/[...nextauth]   一般ユーザーの next-auth
    api/admin-auth/[...]     社内管理者の next-auth (Cookie 名が別。FE-D')
    api/logout/route.ts      セッション破棄の単一経路 (§5.2 の責務 7)
    api/stream/…             SSE 中継。**エンドポイントごとに 1 ファイル** (§6.3。catch-all を置かない)
  features/<domain>/         画面の実装。domain = §11.1 のルート群に対応する単位
                             (themes / conversation / knowledge / idea-boards / ideas /
                              assets / news / settings + **auth** + **admin**)
    api/                     BE 呼び出し (Server Action / 生成関数の薄いラッパ)。'use server'
    components/              その domain 専用の React コンポーネント
    hooks/                   その domain 専用のフック (SSE 購読・ジョブポーリング)
    lib/                     純粋関数のみ (整形・パース・reducer・ViewModel 変換)
    types.ts                 ViewModel 型 (生成型の再エクスポートはしない)
  components/                domain 非依存の共通 UI (Radix ベースの primitives・レイアウト)
  lib/                       domain 非依存の純粋ロジックと基盤
    api/                     API クライアントの mutator・エラー正規化
                             (`mutator.ts` = `X-Token` / `admin-mutator.ts` = `X-Admin-Token`。§5.2)
    sse/                     SSE 共通クライアント (§6)
    parse/                   数値・レンジ・単位のパース (§8)
    tokens/                  デザイントークンの参照ヘルパ (§7)
  generated/                 orval 生成物 (手編集禁止)
  providers/ styles/ utils/  v2 踏襲
  middleware.ts              未認証の遮断 (§11.2)
```

**`features/` の内部を固定 5 種にする理由**: v2 は `features/<domain>/` 配下の名前が
`actions/` / `states/` / `hooks/` / `components/` / `(routes)/` と揺れており (V-1 / V-4 / V-5 の出典に現れる)、
**依存規則を「どのディレクトリからどのディレクトリへ」で書けない**。5 種に固定して初めて
§3.3 の lint zone を宣言できる。

### 3.2 依存方向

```
app/  ──────────────► features/<domain>/{components,hooks,api}
  │                        │        │        │
  │                        ▼        ▼        ▼
  │                   features/<domain>/lib  ──► lib/{parse,sse,tokens}
  │                        │                          │
  ▼                        ▼                          ▼
components/ ──────────► lib/  ◄──────────────── generated/ (型のみ)
```

**responsibility 表**:

| 層 | 置くもの | 置かないもの |
|---|---|---|
| `app/` | ルーティング・メタデータ・Suspense 境界・`error.tsx` | 画面のロジック・BE 呼び出し |
| `features/<d>/api/` | Server Action、生成関数の呼び出し、`X-Request-Id` の付与 | JSX、DOM 参照 |
| `features/<d>/components/` | JSX、`useReducer` の配線、イベントハンドラ | パース、数値化、SSE の生バイト処理 |
| `features/<d>/hooks/` | SSE 購読、ジョブポーリング、`AbortController` の管理 | JSX |
| `features/<d>/lib/` | 純粋関数・reducer・ViewModel 変換 | `react` / `next` の import、`fetch`、`window` 参照 |
| `components/` | domain 非依存の UI primitives | 特定 domain の型・API 呼び出し |
| `lib/` | domain 非依存の純粋ロジック + API/SSE の基盤 | JSX、React hook、特定 domain の知識 |
| `generated/` | orval の生成物 | 手編集した内容 (CI が差分を検出する) |

### 3.3 機械強制する依存規則 (L-F1〜L-F6)

`eslint-plugin-import` の `import/no-restricted-paths` で宣言し、`npm run lint` (CI ゲート) で落とす。
**「気をつける」に落とさない** — v2 は雛形と同じ禁止事項を文書に持ちながら FE-5 が起きた (V-17)。

**実体**: 雛形の [.eslintrc.json.tmpl](../../templates/app-monorepo/frontend/.eslintrc.json.tmpl) に
2026-07-30 に追加された (`:55`〜 が L-F2 / L-F3 / L-F6 の zone、その後の overrides が
L-F1 / L-F4 / L-F5)。**未充足の 1 件と、実装リポで詰める必要がある 2 件は §16.2-1 の表**に挙げる。

| # | 規則 | 潰すもの |
|---|---|---|
| **L-F1** | `src/lib/**` と `src/features/*/lib/**` から **`react` / `react-dom` / `next/*` を import しない** | **FE-5** (lib への JSX/hook 混入による循環依存) |
| **L-F2** | `src/lib/**` から `src/features/**` を import しない (`lib` は domain を知らない) | 共通層が特定ドメインに依存して再利用不能になる |
| **L-F3** | `src/components/**` から `src/features/**` を import しない | 共通 UI がドメイン型に固定される |
| **L-F4** | `src/features/A/**` から `src/features/B/**` を import しない (**共有したいものは `components/` か `lib/` に上げる**) | ドメイン間の暗黙結合 |
| **L-F5** | `src/features/*/components/**` と `src/app/**` から **`fetch` の直接呼び出しを禁止** (`no-restricted-globals` / `no-restricted-syntax`)。BE 呼び出しは `features/*/api/` と `lib/api/`・`lib/sse/` のみ | 認証ヘッダ・`X-Request-Id`・エラー正規化を通らない呼び出し (v2 の V-11 が実例: `AbortSignal` も相関 ID も無い `fetch` がコンポーネント側から使われる) |
| **L-F6** | `src/generated/**` を **import 以外で参照しない** (再エクスポート禁止・手編集禁止)。`src/generated` への import は `features/*/api/`・`features/*/lib/`・`features/*/types.ts`・`lib/api/`・`lib/sse/` のみ | 生成物の型がコンポーネントの深部に散り、再生成時の破壊的変更の影響範囲が読めなくなる |

**L-F5 の例外**: `src/app/api/**` の Route Handler は BE への中継が役割なので `fetch` を使う
(zone から除外する)。除外は**ディレクトリ 1 つだけ**にして、例外の追加を PR レビューの対象にする。

**却下した強制手段**: `tsconfig` の project references によるパッケージ分割 —
依存を型レベルで切れるが、`app/` と `features/` を別パッケージにすると Next.js のビルド構成と
Vercel のキャッシュ設定が複雑になり、得られる強制は eslint zone と同等。

---

## 4. 状態管理

> 本節が回答する ID: **O-5** (会話状態の復元) / 対応パターン: **FE-4 / FE-7**

### 4.1 サーバ状態 (FE-C)

| 経路 | 手段 | 再取得の契機 |
|---|---|---|
| 一覧・詳細の初期表示 | **Server Component が orval の生成関数を呼ぶ** | ナビゲーション / `revalidateTag` |
| 作成・更新・削除 | **Server Action** → `revalidateTag('<domain>')` | 操作完了時 |
| **非同期ジョブの進捗** (アセット抽出・ナレッジファイル) | `features/<d>/hooks/` の専用フックが **状態 GET をポーリング** + SSE 併用 ([API/README.md](API/README.md) J-6 / J-7) | フック内のタイマー (§4.3) |
| **会話ターン** | `features/conversation/hooks/` が **SSE を購読** (§6) | ユーザー発話ごと |

**ジョブ・会話の 2 経路が例外になる理由**: どちらも**サーバ側の状態が数秒単位で変わる**ため、
RSC の再検証 (ページ単位) では粒度が合わない。**ただし結果の正は常にサーバ**であり、
FE 側の状態は表示用のコピーに過ぎない ([API/README.md](API/README.md) J-7 の
「SSE は結果の唯一の受け取り口ではない」と同じ立場)。

### 4.2 クライアント状態の 3 分類 (FE-C')

| 分類 | 置き場 | 対象 | 理由 |
|---|---|---|---|
| ① URL | **nuqs** (`?status=&keyword=&sort=&limit=&offset=&scope=`) | 一覧の絞り込み・ソート・ページ・選択タブ | 再読込・共有・戻る操作で保持される。**クエリ名は API のパラメータ名と一致させる** ([API/README.md](API/README.md) D-API-7〜D-API-10) |
| ② 画面ローカル | **`useReducer` + 純粋 reducer** (`features/<d>/lib/*-reducer.ts`) | 会話ターン・ジョブ進捗・ウィザード・複数選択 | reducer を単体テストできる (FE-4)。復元 (履歴 GET) は「初期 state を作る純粋関数」として同じ場所に置ける |
| ③ 全画面共有 | **zustand** (`src/lib/stores/`) | トースト・グローバルなモーダル・サイドバー開閉 | 画面を跨いで 1 つしか存在しない UI 状態のみ |

**②を zustand に置かない** (v2 の 4 store と異なる点。V-4):
会話状態は「履歴 GET で復元 + 再接続」が仕様 ([design_memo.md](design_memo.md):169) であり、
global store に置くと**同じ会話の状態が store と API の 2 ソースになる**。
reducer に閉じれば「復元 = 初期 state の再計算」で一意に決まる。

**reducer の必須要件** (テスト可能性のため):

1. **`(state, action) => state` の純粋関数として `export` する** (FE-4)
2. **`action` は discriminated union** にし、SSE イベント型 ([API/README.md](API/README.md) D-API-12 の
   OpenAPI 由来 union) を**そのまま action に載せられる形**にする — 変換層を増やさない
3. **本文の追記は「末尾に連結」ではなく「イベント列から再構築できる」形**にする
   (再接続時に重複追記が起きない。§6.4)

### 4.3 ジョブポーリングの規約 (J-6 / J-7 の FE 側)

- ポーリング間隔は **2 秒**から始め、**60 秒を超えたら 5 秒**に落とす (指数バックオフはしない —
  進捗表示の反応性が落ちる)
- **`status` が `succeeded` / `failed` になったら停止**する。**`running` のまま
  [API/README.md](API/README.md) J-3 の失効しきい値 (既定 15 分) を超えた場合はポーリングを止め、
  「処理が中断された可能性がある」と表示して再実行導線を出す** — サーバ側が `stale_aborted` に
  落とすまでの間、画面が回り続けるのを防ぐ
- **間隔・上限は `src/lib/config.ts` の 1 箇所**に置く (BE-2 の FE 版。値を複数箇所に書かない)

---

## 5. API クライアントと型

> 本節が回答する ID: **A-1 / A-4 (FE が送れる形) / O-1** / 対応パターン: **FE-2**

### 5.1 型の流れ (FE-E)

```
backend/: swaggo アノテーション → api/openapi.yaml (コミット済み・生成物。D-API-13)
                    │  CI / 開発者が取得
                    ▼
frontend/: npm run generate (orval)。入力は ../api/openapi.yaml
                    ├─► src/generated/models/**      スキーマ型
                    ├─► src/generated/<tag>/*.ts     fetch 関数 + URL ヘルパ
                    └─► src/generated/msw/**         MSW ハンドラ (testing.md T-O)
```

- **`swagger.json` の取得方法 (FE-Q3。2026-08-03 に解消)**: **モノレポ化により同一リポジトリ内の
  `api/openapi.yaml` を直接読む**ため、取得手段の検討そのものが不要になった (§16 の FE-Q3 参照)。
  **旧 3 リポ構成での検討 (記録)**: backend リポの**リリース成果物 (GitHub Actions の artifact) または
  リポジトリの raw ファイル**を CI と開発者が取得する。**private リポジトリの取得にトークンが要る**ため、
  `E2E_DISPATCH_TOKEN` と同型の論点になっていた
- **CI で `npm run generate` を実行し差分ゼロを検査する** (雛形
  [ci.yml](../../templates/app-monorepo/.github/workflows/ci.yml) の `contract` ジョブ が既にこの形)
- **生成物は手編集しない**。pre-commit が生成物の変更を警告する
  ([pre-commit](../../templates/app-monorepo/scripts/hooks/pre-commit) の「生成型の手編集検出」ブロック に既にある)

### 5.2 mutator (`src/lib/api/mutator.ts`) の責務

v2 の `apiClient` (V-7) を置き換える。**サーバ側でのみ動く**前提を維持する。

| # | 責務 | v2 からの変更 |
|---|---|---|
| 1 | セッションから BE の JWT を取り出し **`X-Token`** に入れる | **`X-Admin-Token` は送らない** (v2 は同じ値を両方に入れていた。V-7)。**例外は `admin-mutator.ts` 1 ファイルのみ** (下記) |
| 2 | **`X-Request-Id` (ULID) を生成して付ける** (FE-L) | 新規 |
| 3 | ベース URL を **サーバ専用の環境変数 `API_BASE_URL`** から取る | v2 は `NEXT_PUBLIC_API_BASE_URL` (V-8) = ブラウザに露出。§12 |
| 4 | **エラー応答を 1 つの型に正規化して throw する** (`ApiError { status, code, message, requestId }`) | v2 は `{status, data}` を返して呼び出し側が判定 (V-7) |
| 5 | タイムアウト: **通常 API 30 秒 / LLM を伴う 3 本は 120 秒** ([API/README.md](API/README.md) §3 の LLM 列) | v2 は全経路 8 分固定 (V-7) |
| 6 | `AbortSignal` を尊重し、**`AbortError` はそのまま伝播させる** (正常系として上位で扱う。FE-1) | v2 は中断を握らない |
| 7 | **401 を受けたら `ApiError` を投げるだけ**にし、**Cookie の破棄はしない** (破棄は下記の単一経路が行う) | v2 は 401 を呼び出し側に返すだけで破棄経路が無い |

**5 の根拠**: LLM を伴う 3 本 (`POST /asset-extractions` / `POST /knowledge-threads/{thread_id}/messages` /
`POST /knowledge-files`) は同期完了しないか長い。**タイムアウト値は `src/lib/config.ts` の 1 箇所**に置く。
**却下**: v2 の 8 分一律 — 通常 API の障害時に画面が 8 分間ローディングのままになる。

#### 5.2.1 管理者用 mutator (`src/lib/api/admin-mutator.ts`。FE-D')

- **`X-Admin-Token` を付ける実装は本ファイル 1 つに限る**。セッションの取得元も
  管理者用 next-auth (`api/admin-auth`) 側であり、一般ユーザーのセッションを読まない
- **機械検査 (2026-07-30 に雛形へ実装済み — eslint の `no-restricted-syntax` で `admin-mutator.ts` 以外を禁止。[.eslintrc.json.tmpl](../../templates/app-monorepo/frontend/.eslintrc.json.tmpl):163〜220)**: `grep -rn "X-Admin-Token" src` の結果が
  `src/lib/api/admin-mutator.ts` 以外に無いことを CI で確認する。
  **v2 の V-7 (両ヘッダに同一値) は「どこからでも付けられた」ことで起きた**ため、
  規約ではなく検査で局所化する
- 逆向きの検査も同じスクリプトで行う: **`admin-mutator.ts` を import できるのは
  `src/features/admin/**` だけ** (L-F4 の zone に管理者ドメインを含める)

#### 5.2.2 セッションに載せる表示用の最小属性 (A-2 の FE 側)

**判定の正は BE (403)** という方針 (§5.4 / §9) は変えない。ただし**導線を出さない**判断には
FE がロールを知る必要があるため、**出所を 1 箇所に固定する**。

| 属性 | 用途 | 出所 |
|---|---|---|
| `role` (契約内管理者かどうか) | §11.1 の契約内管理者限定 3 画面の導線の出し分け | **サインイン API のレスポンス** |
| `requiredMfaType` / `mfaVerified` | §11.2 の MFA ゲート | 同上 |
| `accountId` (uuid) / 表示名 / 会社名 | ヘッダ表示・自分の行の判別 | 同上 |

- **経路**: サインイン API の応答 → next-auth の `authorize` が返す `User` → `jwt` コールバック →
  `session` コールバック → Server Component が `getServerSession()` で読む。
  **v2 が `requiredMfaType` / `mfaEnabled` に対して既に採っている形** と同じ
  (`hassan-v2-frontend/src/lib/auth.ts:49-57` が signin 応答から `User` を組み、
  `:134-153` の session / jwt コールバックがセッションへ載せる)
- **`role` は v2 のサインイン応答に無い** (同 `:49-57` に `role` の項目が無い) が、
  **v3 では解決済み (2026-07-31)** — [API/auth-accounts.md](API/auth-accounts.md) §2.5 の `SignInResult` が
  `auth_role` / `mfa.required_type` / `mfa.verified` / `account.id` / `name` / `company_name` を含む。
  **「応答に入るまで導線を全員に出す」暫定挙動は解除する** — 契約内管理者限定 3 画面の導線は
  `auth_role` で出し分ける (判定の正は BE。導線を隠すのは表示上の配慮であり §9 の 403 行の方針は変えない)
- **却下 (a) BE の JWT を FE で復号して `role` クレームを読む** ([auth.md](auth.md) §6.1 のクレームに
  `role` はある): 署名鍵は BE のみが持つ (同 §6.8) ため**検証なしの復号**になり、
  「検証していない値で画面を変える」実装が 1 箇所でも入ると、以後それが前例になる。
  **却下 (b) 403 を受けてから隠す**: 初回描画で導線が出て、押すと失敗する。
  **却下 (c) 専用の me API を各画面で呼ぶ**: 全画面に 1 往復増え、RSC のキャッシュ境界も増える

#### 5.2.3 401 を受けたときのセッション破棄とセッションの寿命

- **破棄経路は `app/api/logout/route.ts` の 1 本だけ**にする。`GET /api/logout?next=<元の URL>` が
  ①next-auth のセッション Cookie を削除 (`cookies().delete()`) ②`/login?next=…` へ 303 で送る
- **すべての 401 が破棄経路に入るわけではない (2026-07-31 のレビュー 重大 1)**: 破棄するのは
  **`code` が `AU-T-` で始まる 401 と、本文なし・未知のコード**だけ (§9 の分類 T)。
  **`AU-C-` で始まる 401 (サインイン・MFA コードの不一致) はセッションを破棄せず、フォーム内エラーにする**。
  値域の SSOT は [API/auth-accounts.md](API/auth-accounts.md) §3.1.1。
  **「破棄経路が 1 本」は「破棄するときの経路が 1 本」の意味であり、「401 なら必ず破棄する」ではない**
- **分類 T の 401 を受けた場所ごとの動き**: Server Component は `redirect('/api/logout?next=…')`、
  Server Action は同じ URL への `redirect()`、Route Handler (SSE 中継) は
  **`401` をそのままクライアントへ返し**、クライアント側の hook が `/api/logout` へ遷移させる
- **`signOut()` (next-auth のクライアント API) を 401 の処理に使わない** — 401 を最初に受けるのは
  サーバ側であり、そこから呼べない。**明示的なサインアウトボタンのみ `signOut()` を使う**
- **`/api/logout` は §11.2 の 2 本の許可リストの両方に載せる** (未認証でも MFA 未検証でも
  サインアウトできる必要がある。載せ忘れるとロック状態から抜けられない)
- **next-auth の `session.maxAge` / `jwt.maxAge` = BE の JWT 有効期間 = 7 日に一致させる**
  ([auth.md](auth.md) §6.9-3 が 7 日据え置きを決定済み。v2 も一致させている — V-13)。
  **v3 は Cookie が唯一の保持先**なので、ずれると「Cookie は生きているが BE の JWT が期限切れ」で
  全リクエストが 401 になる。**BE 側の期限を変える PR では FE の `maxAge` も同じ増分で変える**
  (値の SSOT は [auth.md](auth.md) §6.9-3。FE は同書を参照するコメントを設定に添える)

### 5.3 snake_case を境界で止める構造 (FE-2 / FE-E')

| 場所 | 型 | 命名 |
|---|---|---|
| `generated/` | orval 生成型 | **snake_case** (BE の JSON キーそのまま) |
| `features/<d>/lib/` の変換関数 | 生成型 → ViewModel の**一方向** | 入力 snake_case / 出力 camelCase |
| `features/<d>/types.ts` | ViewModel 型 | **camelCase** |
| `features/<d>/components/` | ViewModel 型または生成型 | **どちらでもよい** |

**「どちらでもよい」とする理由**: 表示に整形が不要なフィールドまで ViewModel を作ると、
**フィールド追加のたびに 2 箇所を直す作業**が生まれ、それが漏れると表示だけ古くなる (FE-2 の本質は
「手書きの変換層が型の第 2 のソースになること」であって snake_case そのものではない)。
**ViewModel を作る条件を限定する**: ①複数フィールドを合成する ②単位・書式を変換する
③LLM 出力をパースする ④API 形と画面の構造が 1 対 1 でない — **このいずれかに該当する場合のみ**。

### 5.4 FE が送れるスコープの形 (A-4 の FE 側)

- 一覧の `scope` は **生成型の enum (`mine` / `contract`)** としてしか送れない
  ([API/README.md](API/README.md) D-API-8)。**FE に `account_id` を送る経路を作らない**
- **`scope` の UI は増分 1 から出す** (2026-08-02 改訂。旧記述は「増分 1 では出さない — BE が 400 で拒否する」だったが、**D-API-8' が C-16 の適用で `scope=contract` を増分 1 から有効にした**ため成立しない。共有の切り替え UI も同じ増分に出す = BE-10)。
  共有・可視性の UI は**増分 2 で追加**する (A-7)
- 所有者の判定・絞り込みは **すべて BE**。FE は「返ってきたものを表示する」だけで、
  **FE 側に可視性の判定ロジックを持たない** (雛形 CLAUDE.md.tmpl のフィーチャーフラグ規約と同じ立場)

---

## 6. SSE 共通クライアント

> 本節が回答する ID: **O-5** (切断・再接続・タイムアウトの検知) / **O-4** (異常終了の可視化) /
> 対応パターン: **FE-1 / BE-7 の FE 側**

### 6.1 構成 (FE-F)

```
features/<d>/components/  (JSX)
      │ dispatch(action)
      ▼
features/<d>/hooks/useXxxStream.ts     AbortController の生存管理・reducer への dispatch
      │
      ▼
lib/sse/subscribe.ts                  ★共通クライアント 1 本
      │  ├ lib/sse/parse-block.ts     ブロック → {event, data} (純粋関数・テスト対象)
      │  └ lib/sse/decode-event.ts    {event, data} → 生成型の discriminated union
      ▼
app/api/stream/<エンドポイントごとに 1 ファイル>/route.ts
      │                              許可リスト = ファイルの存在 (§6.3.1)
      └ lib/sse/relay.ts             中継の共通実装 (§6.3.2)
      ▼
backend (SSE)
```

**`lib/sse/parse-block.ts` を純粋関数として切り出す理由**: ネットワークを介さずに
「chunk 境界がブロックを跨ぐ」「本文に空行が含まれる」ケースをテストできる
([testing.md](testing.md) §4.2 の SSE 行が要求するケース)。

### 6.2 パーサの仕様 (BE-7 の FE 側を構造で潰す)

| # | 規則 | v2 / PoC との差 |
|---|---|---|
| S-1 | **イベントの区切りは `\n\n` (空行)**。`\r\n` も同等に扱う | v2 は `\n` 単位で分割し空行を捨てる (V-11) ため**ブロックの概念が無い** |
| S-2 | ブロック内の **`event:` 行を読み、イベント名として使う** | v2 は `data: ` だけを見る (V-11) |
| S-3 | **`data:` 行は複数あり得る。値を `\n` で連結する。各行を trim しない** (先頭 1 スペースの除去のみ SSE 仕様どおり行う) | PoC は各行を `.trim()` する (P-4) ため markdown のインデントが壊れる |
| S-4 | **`data:` が空の行 (`data:`) は空行として本文に含める** — 空行は markdown の段落区切りとして意味を持つ | v2 は空行を捨てる (V-11) |
| S-5 | **`:` で始まる行 (コメント) は捨てる**。keep-alive はこれで届く ([observability.md](observability.md) §4.4 の 15 秒) | v2 / PoC ともコメント行の扱いが明示されていない |
| S-6 | **未知の `event:` 名は捨てずに「未知イベント」として上位に渡し、warn ログに出す** | 除外リスト方式 (既知のプレフィックスだけ捨てる) — BE-7 の教訓 |
| S-7 | **バッファに残った不完全なブロックは次の chunk まで保持する**。ストリーム終了時に残っていたら**不完全終了として扱う** (§6.4 の失敗表示) | v2 は末尾の不完全行をバッファに残すが、終了時の残骸を無視する |
| S-8 | イベント型への振り分けは **生成型の discriminated union** (`event` フィールド) で行う。**手書きの `StreamResponse` 型を作らない** | v2 は手書き型と生成型が並存 (V-10) |

| S-9 | **型が未定義の経路では `{ event: string; data: unknown }` 固定で扱う**。`unknown` を具体型に narrow するのは **`lib/sse/decode-event.ts` の 1 ファイルだけ**。他の場所 (hooks / reducer / components) は `unknown` を受け取らない = **decode を通っていない値がそこまで来ない**。**2026-08-01 時点で該当する経路は無い** — 唯一の対象だった会話は [API/conversation.md](API/conversation.md) §5 で型が確定した。**規約自体は残す** (今後型未定義の SSE 経路を足したときの既定) | 新規 (歯止め) |

**S-8 の前提**: SSE イベント型は OpenAPI の `components/schemas` に discriminated union で定義される
([design_memo.md](design_memo.md):149 の決定 / [API/README.md](API/README.md) D-API-12)。
**会話型アイデア創出のイベント型は 2026-08-01 に確定した** ([API/conversation.md](API/conversation.md) §5) —
**S-9 の `unknown` 固定を解除してよい唯一の経路**であり、他に型未定義の SSE 経路は残っていない。
**新たに型未定義の SSE 経路を作る場合は、S-9 を再び適用する** (手書き型で先行すると V-10 と同じドリフトになる)。

**S-9 が必要な理由 (暫定既定の歯止め)**: FE-Q1 の暫定既定は「汎用形で先に作り、
型の確定後に decode 層だけ差し替える」だが、**payload の型を決めておかないと実装者が
「暫定の payload 型」を手書きする** — それは V-10 (生成型と手書き型の並存) の再生産である。
したがって次の 3 つを規約にする:

1. 汎用形の payload の型は **`unknown` 固定**。`interface ConversationEvent { … }` のような
   **暫定の構造体を書かない**
2. `JSON.parse` の戻り値に**型アサーション (`as`) を書かない** (雛形の eslint が `as` を禁止している —
   [.eslintrc.json.tmpl](../../templates/app-monorepo/frontend/.eslintrc.json.tmpl):28-30)。
   narrow は `decode-event.ts` 内の型ガード関数で行う
3. **`decode-event.ts` に会話用の分岐を書くのは、OpenAPI に union が入った後**。
   それまでは「未知イベント」(S-6) として上位に渡し、画面は本文の追記だけを行う

### 6.3 中継 Route Handler (FE-D の帰結)

#### 6.3.1 中継してよいエンドポイントの許可リスト (catch-all を置かない)

**catch-all (`[...path]`) を置かない**。**中継対象ごとに Route Handler のファイルを 1 つ作る**。

| BE のエンドポイント | メソッド | Route Handler のパス | 対応画面 (§11.1) | 増分 |
|---|---|---|---|---|
| `GET /asset-extractions/{extraction_id}/stream` ([API/assets.md](API/assets.md) §2) | **GET** | `app/api/stream/asset-extractions/[extractionId]/route.ts` | `/assets/extractions/[extractionId]` | 1 |
| `POST /knowledge-threads/{thread_id}/messages` ([API/knowledge.md](API/knowledge.md) §2) | **POST** | `app/api/stream/knowledge-threads/[threadId]/messages/route.ts` | `/knowledge/[threadId]` | 1 |
| `POST /conversations/{session_id}/messages` ([API/conversation.md](API/conversation.md) §1) | **POST** | `app/api/stream/conversations/[sessionId]/messages/route.ts` | `/themes/[themeId]/conversations/[conversationId]` | 1 |
| `POST /plans/{plan_id}/generate` ([API/plans.md](API/plans.md) §1) — 8 タブの一括生成 | **POST** | `app/api/stream/plans/[planId]/generate/route.ts` | 企画書ビュー (§11.1) | 1 |
| `POST /plans/{plan_id}/tabs/{tab_id}/regenerate` ([API/plans.md](API/plans.md) §1) — タブの再生成 | **POST** | `app/api/stream/plans/[planId]/tabs/[tabId]/regenerate/route.ts` | 企画書ビュー (§11.1) | 1 |
| `POST /plans/{plan_id}/chat/messages` ([API/plans.md](API/plans.md) §1) — 企画書チャット | **POST** | `app/api/stream/plans/[planId]/chat/messages/route.ts` | 企画書ビュー (§11.1) | 1 |

- **SSE 以外を中継しない**。通常の API は Server Component / Server Action が
  生成関数を直接呼ぶ (§5.1) ため、中継の必要が無い。
  **「便利だから」で通常 API を中継する Route Handler を追加しない**
- 新しい SSE を中継するには**ファイルを追加する PR が必要**になる = 上表が許可リストそのものになる。
  **上表に無いパスは Next.js のルーティングが 404 を返す** (許可リスト定数の更新漏れという失敗形が存在しない)
- **却下 (a) `[...path]` + 中継可能パスの定数配列**: 定数の更新漏れが
  「**Cookie の `X-Token` を付ける汎用プロキシ**」への退行として現れる。
  ファイル単位なら退行が起こり得ない。
  **却下 (b) 現行案 (`[...path]` で 1 対 1 中継)**: ブラウザ JS から `POST /api/stream/themes/1` のような
  **任意の BE 操作**が実行可能になり、FE-D が獲得した性質 (ブラウザは BE を直接叩けない) が消える。
  §12 で BE の CORS 許可リストを縮小できると回答していることと合わせると、
  **BE 側の防御を緩めた上で FE に開いた踏み台を置く**形になる

#### 6.3.2 各ハンドラの共通要件

- サーバ側でセッションから JWT を取り出し `X-Token` を付ける。**`X-Request-Id` も付けて BE のログと繋ぐ** (FE-L)
- **BE からの本文をバッファせずそのまま流す** (`ReadableStream` をパススルー)。
  **レスポンスヘッダに `Cache-Control: no-cache, no-transform` と `X-Accel-Buffering: no` を付ける**
  (中間層のバッファリングで逐次表示が死ぬのを防ぐ)
- **Node.js ランタイムで動かす。Edge ランタイムは選択肢から外す** (2026-07-30 確定) — next-auth の
  セッション取得の制約に加え、**Edge はストリーム継続が最大 300 秒でプランによる延長ができない**ため
  会話 1 ターンの上限 5 分に余裕が残らない (§16.1 FE-Q2 の一次調査)。
  **Node.js ランタイムでは `maxDuration` を明示設定する必要がある** — 既定 300 秒では余裕がゼロで、
  **Pro 以上で 800 秒まで伸ばせる**。同時実行数は制約にならないことを確認済み。
  課金は active CPU ではなく provisioned memory time が主項 (いずれも §16.1 FE-Q2)。
  会話 1 ターンの上限は 5 分 ([observability.md](observability.md) §4.4)
- **クライアントの切断を BE に伝播させる**: Route Handler が受け取った `request.signal` の abort で
  上流の `fetch` を abort する。**伝播しないと BE の LLM 呼び出しが走り続けて課金が発生する** (O-3)
- **共通処理は `lib/sse/relay.ts` の 1 関数**に置き、各 Route Handler は
  「BE のパスを組み立てて `relay()` を呼ぶ」だけにする (ファイルが増えても実装は 1 箇所)

#### 6.3.3 クロスサイトからの呼び出しを弾く (Cookie 認証の中継であることの帰結)

中継は **HttpOnly Cookie のセッションを使って BE を叩く**ため、
**中継 Route Handler 自体が CSRF の対象**になる (LLM を伴う POST が第三者サイトから起動され得る)。

| 検査 | 規則 | 弾く対象 |
|---|---|---|
| 1 | **`Sec-Fetch-Site: same-origin` を必須**にする。ヘッダが無い / 値が違う → **403** | `<img>` / `<script>` / リンク / 他サイトの `fetch` からの起動 (いずれも `cross-site` か `none` になる)。**ヘッダを送らないクライアント (curl 等) も弾く** — 中継はブラウザからしか呼ばれない |
| 2 | POST は加えて **`Origin` ヘッダが自オリジンと一致**すること → 不一致は 403 | 検査 1 の二重化。`Origin` は同一オリジンの POST にも必ず付くため追加コストが無い |
| 3 | **GET の中継は `Sec-Fetch-Mode: cors` または `same-origin` のみ許可**し、`navigate` を 403 | アドレスバー直打ち・リンク遷移での SSE 起動 (課金を伴う経路をナビゲーションで起動させない) |

- **却下: `SameSite=Lax` に依存する案** — Lax はクロスサイトの POST に Cookie を送らないので
  検査 2 の代替にはなるが、**GET のトップレベルナビゲーションでは Cookie が送られる**ため
  検査 3 を代替しない。v2 の Cookie 設定は `sameSite: 'lax'`
  (`hassan-v2-frontend/src/lib/auth.ts:17-27`) であり、v3 も同じ設定を踏襲するので
  **Lax は前提であって防御の全部ではない**
- **E2E への影響**: Playwright は実ブラウザなので `Sec-Fetch-*` を送る
  ([testing.md](testing.md) §7.3 の構成で追加対応は不要)

### 6.4 切断・再接続・中断 (O-5 / FE-1)

| 事象 | FE の振る舞い | 根拠 |
|---|---|---|
| **ユーザーが中断** (ボタン / 画面遷移 / `useEffect` クリーンアップ) | `AbortController.abort()` → **`AbortError` は正常系として握る** (エラー表示しない)。状態は `canceled` | **FE-1**。PoC は既にこの形 (P-5) |
| **無通信が 45 秒続く** | ストリームを打ち切り、状態 `failed` + 「接続が中断されました」+ **再接続ボタン** | keep-alive 15 秒の 3 倍 ([observability.md](observability.md) §4.4)。FE-J |
| **ECS のローリング更新で切れる** (必ず起きる前提) | 同上。再接続ボタンは **①会話履歴 GET で状態を復元 ②続きを購読** の 2 段 | [design_memo.md](design_memo.md):169 / [API/README.md](API/README.md) J-7 |
| **SSE の `error` イベントを受信** (ストリーム開始後の失敗) | 状態 `failed` + BE の `message` を表示 + `request_id` を併記 | [API/README.md](API/README.md) D-API-12 / §9 |
| **ストリームが不完全終了** (S-7 の残骸あり / 完了イベント無しで終了) | 状態 `failed` として扱い、**「完了していない」ことを明示**する | O-4。**無言で成功に見せない** |
| **再接続時の重複** | reducer は**イベント列から state を再構築**するため (§4.2 の要件 3)、同じイベントが再送されても本文が二重にならない | BE-7 / FE-7 |

**却下**: 自動再接続 (指数バックオフでの再購読) — LLM を伴うターンは再実行に課金が伴い、
`POST` の再送が**同じターンを 2 回実行し得る** ([API/README.md](API/README.md) J-4 が
「自動リトライは行わない」と決めているのと同じ理由)。**再接続はユーザーの明示操作**にする。

---

## 7. デザイントークン

> 本節が回答する ID: **D-2** (lint 強制) / 対応パターン: **FE-3**

### 7.1 体系 (FE-G)

**Tailwind の `theme.extend` を唯一の定義場所**にし、**CSS 変数 + 意味ベースの名前**で定義する。
粒度は次の 5 系統に限る (増やすときは本節を更新する = SSOT を 1 箇所に保つ)。

| 系統 | トークン名の例 | 使う場面 | v2 との差 |
|---|---|---|---|
| **色 (意味)** | `bg-surface` / `bg-surface-muted` / `text-primary` / `text-muted` / `border-default` / `accent` / `danger` / `warning` / `success` / `info` | すべての配色 | v2 は `blue.10`〜`blue.90` のような**番号連番 + 生 hex** (V-15) で、名前から用途が分からない |
| **間隔** | `space-xs` / `sm` / `md` / `lg` / `xl` / `2xl` (4/8/12/16/24/32px) | margin / padding / gap | v2 は `sizeXS`〜`size5XL` で margin と padding に別々の同名スケールを定義 (V-15) |
| **文字** | `text-body` / `text-body-sm` / `text-heading-1〜3` / `text-caption` | すべての文字サイズ・行間・太さの組 | v2 は `sizeXS`〜`size4XL` で**サイズのみ**。行間・太さがトークン化されていない |
| **角丸・影** | `rounded-card` / `rounded-control` / `shadow-card` / `shadow-overlay` | 面の表現 | v2 は `lg/md/sm` (16/8/4px) と `header` / `button` の影 (V-15) |
| **状態レイヤ** | `ring-focus` / `bg-hover` / `bg-selected` / `opacity-disabled` | インタラクション状態 | v2 に体系が無く、各コンポーネントが個別に指定 |

- **色は `globals.css` の CSS 変数 (`--color-surface` 等) で定義し、`theme.extend` から参照する**。
  ダークモード (v2 は `darkMode: ['class']` を設定済み) を変数の切り替えで表現できる
- **プロトタイプの配色は「入力」として参照するが、値をそのまま採らない** (DR-7)。
  プロトタイプは単体 HTML で状態レイヤもダークモードも持たないため、
  **意味ベースの名前に写した上で値を確定する作業が実装リポの最初のタスク**になる (§15)

### 7.2 lint による強制 (FE-3)

| 検査 | 手段 | 雛形の実体 (2026-07-30) | 落ちる例 |
|---|---|---|---|
| 任意値の禁止 | `eslint-plugin-tailwindcss` の `no-arbitrary-value` | 実装済み: [.eslintrc.json.tmpl](../../templates/app-monorepo/frontend/.eslintrc.json.tmpl) の `tailwindcss/no-arbitrary-value` (2026-07-30) | `w-[13px]` / `text-[#0455c5]` |
| トークン外クラスの禁止 | 同 `no-custom-classname` | **実装済み** (2026-07-30): [.eslintrc.json.tmpl](../../templates/app-monorepo/frontend/.eslintrc.json.tmpl):30〜33 | `status-message-shimmer` (v2 の V-16 のような手書きクラス) |
| **hex リテラルの禁止** | `no-restricted-syntax` の **AST セレクタ** `Literal[value=/^#[0-9a-fA-F]{3,8}$/]` (**正規表現単体では指定できない** — ESLint の同ルールはセレクタを取る)。例外は `src/styles/**` と `tailwind.config.ts` のみ | 実装済み: [.eslintrc.json.tmpl](../../templates/app-monorepo/frontend/.eslintrc.json.tmpl):46〜 | `style={{ color: '#B34A00' }}` (PoC の P-6 が戻った形) |
| **`style` 属性の禁止** | `no-restricted-syntax` の `JSXAttribute[name.name='style']`。例外は**計算値が必要な箇所のみ** ESLint の行コメントで明示 | 実装済み: 同 `:50`〜 | 動的でない inline style |
| **`globals.css` の増加検知** | CI で `src/styles/globals.css` の行数増加を PR に表示する (**ブロックはしない**) | 実装済み: [ci.yml](../../templates/app-monorepo/.github/workflows/ci.yml) の `frontend` ジョブの「検査 4 globals.css の行数」ステップ | トークンで表現できずに CSS を足した箇所をレビューの対象にする |

**`style` 属性の禁止に `react/forbid-dom-props` を使わない理由**: 同ルールのためだけに
プラグインを 1 つ増やすことになり、hex 禁止と同じ `no-restricted-syntax` に並べれば
**1 ルールの配列で両方を表現できる** (雛形はこの形を採った)。
**限界の明示**: セレクタは `Literal` を見るため、**テンプレートリテラル内の hex
(`` `${x} #fff` ``) と CSS ファイル内の hex は検出しない**。前者は稀で、
後者は `globals.css` の行数可視化がレビュー対象に載せる。

**「ブロックはしない」検査を混ぜる理由**: CSS が必要な正当なケース (keyframes・
サードパーティのスタイル上書き) は残る。**ブロックすると `eslint-disable` で回避されて可視性が下がる**ため、
**可視化してレビューに載せる**方を選ぶ。

**却下**: Stylelint の導入 — 検査対象の CSS が `globals.css` 1 ファイル程度に収まる設計なので、
ツールを 1 つ増やす利得が小さい。CSS が増える設計に変わった時点で再検討する。

---

## 8. LLM 出力を数値・構造に変換する処理

> 本節が回答する ID: **O-4** / 対応パターン: **FE-4 / FE-6**

### 8.1 置き場と規約 (FE-H)

| 対象 | 置き場 | 規約 |
|---|---|---|
| 数値・レンジ・単位のパース (「120-420億円」「約 3 割」「2026年Q2」) | **`src/lib/parse/`** (domain 非依存) | **必ず `export`** / **`*.test.ts` を併置** / **`react` を import しない** (L-F1) |
| markdown・`<options>` 等の構造抽出 | `src/lib/parse/` | 同上。**SSE の本文をそのまま入力に取れる純粋関数**にする |
| ドメイン固有の整形 (ステータス表示・スコアの丸め) | `features/<d>/lib/` | 同上 |
| 図表用のデータ整形 (Recharts 等への変換) | `features/<d>/lib/` | 同上。**コンポーネント内で整形しない** |

### 8.2 機械強制

- **存在検査**: `src/lib/parse/**/*.ts` と `features/*/lib/**/*.ts` に**同名の `*.test.ts` が無ければ CI で落とす**
  (`index.ts` と型のみのファイルは除外)。[testing.md](testing.md) §10 の
  「必須テストの存在検査を機械強制する」方針の FE 版として実装する。
  **実体**: [ci.yml](../../templates/app-monorepo/.github/workflows/ci.yml) の `frontend` ジョブの「検査 1 併置テストの存在」ステップ (2026-07-30 に追加)
- **[testing.md](testing.md) §10 への登録は完了済み** (2026-07-30 に同節が **6 種**へ拡張され本検査が
  **#6** として登録された。2026-07-31 に I 段の `t.Skip` 禁止が **#7** として加わり現在は **7 種**)。
  当初この検査は同節の 5 種 (AC-ID / X-1・X-2 / tool の A-1' / `entity/` のレンジ入力 / F-1〜F-5 —
  いずれも backend) に含まれておらず、**D-2 の SSOT が [testing.md](testing.md) §9 / §10 である**ため
  §16.2-1 の是正要求として登録を求めていた。**要求は解消済み**で、
  「`frontend` ジョブにだけ存在する、SSOT の外の検査」ではなくなっている
- **L-F1** (`react` / `next` の import 禁止) が FE-5 を、**export + 併置テスト**が FE-4 を潰す
- **テストの必須ケースは [testing.md](testing.md) §4.2 が SSOT** (レンジ誤抽出・空・欠損・想定外形式)。
  本書では再定義しない

**PoC の教訓 (P-7)**: `plan-market-chart.ts` は既に純粋関数として分離されていたが FE-6 が起きた。
**分離は必要条件、テストが十分条件**。存在検査を CI に入れるのはこのためである。

---

## 9. エラー表示と 401 / 403 / 404

> 本節が回答する ID: **A-1 / A-2 / A-5 (FE 側) / O-4**。**判定規則の SSOT は
> [auth.md](auth.md) §6.6**、エンドポイント別の適用は [API/README.md](API/README.md) §2.5。
> 本節は**その結果として画面がどうなるか**だけを定める。

| ステータス | 画面の振る舞い | 文言 | 補足 |
|---|---|---|---|
| **401 / 分類 T** (`code` が **`AU-T-` で始まる**、**または本文が無い・未知のコード**) | **`/api/logout?next=<元の URL>` へリダイレクトする** — セッション破棄は**この 1 経路だけ**が行い、その後 `/login?next=…` へ送る (**手段と経路は §5.2.3**)。トーストは出さない | 固定文言 (「再度サインインしてください」) | トークン自体の失効 (署名不正 / 期限切れ / アカウント不存在 / ロック / MFA ゲート)。**理由は区別しない** — [auth.md](auth.md) §6.9 のロック可視化はメンバー一覧側の仕事。**未知のコードと本文なしをここに寄せるのは fail-safe** (判定できないものを破棄側に倒す) |
| **401 / 分類 C** (`code` が **`AU-C-` で始まる**) | **セッションを破棄しない**。**フォーム内のエラーとして表示**し、画面に留まる (再入力できる状態を保つ) | BE の `message` | **2026-07-31 のレビュー 重大 1 で追加**。リクエストボディで提示した資格情報の不一致 (サインイン / MFA コード)。**この分岐が無いと TOTP の打ち間違い 1 回で強制サインアウトになる** (レート制限と重なると正規ユーザーが自分をロックアウトする)。**`/login` では `AU-C-00002` (ロック) を受けたら「管理者に解除を依頼してください」と案内する** — パスワードリセットではロックが外れないため ([auth-accounts.md](API/auth-accounts.md) §3.4) |

**401 の分岐は「コードの接頭辞」だけで行う (経路で分岐しない)**: 判定規則は 3 行 —
`AU-T-` → 破棄 / `AU-C-` → フォーム内 / **それ以外 (本文なし・未知・ALB 由来) → 破棄 (分類 T の扱い)**。
**エンドポイントごとの分岐表を FE に持たない** — 経路を数える形にすると API の追加で漏れる。
値域の SSOT は [auth-accounts.md](API/auth-accounts.md) §3.1.1。
**なお認証済みの状態変更に添える本人確認の不一致 (現在パスワード・MFA 再登録のコード) は 400**
であり 401 の分岐に入らない (同書 AA-D-17) — フィールドエラーとして表示する。
| **403** | **画面遷移しない**。操作した箇所にインラインでエラーを出し、**以後その操作の導線を無効化**する | **BE の `message`** | 403 は 11 本のみ ([API/README.md](API/README.md) §2.5)。**FE 側で権限判定をしない** — 導線を隠すのは表示上の配慮で、判定の正は BE (雛形 CLAUDE.md.tmpl のフラグ規約と同じ) |
| **404** | 詳細画面なら**一覧へ戻し**、一覧内の操作なら**その行を消してトースト**。**「権限がありません」とは出さない** | BE の `message` | 404 は「他テナント / 個人スコープの他人 / 実在しない」を区別しない ([auth.md](auth.md) §6.6)。**FE がこの 3 つを推測して文言を変えてはならない** (存在の漏洩になる) |
| **400** | **フォームのフィールドエラー**として表示。フィールドが特定できない場合はフォーム全体のエラー | BE の `message` | zod による事前検証で大半は防ぐが、**FE の検証を BE の代替にしない** |
| **409** | フォーム全体のエラー (「同じ名前が既にあります」等) | BE の `message` | 重複の種類は `message` で区別する |
| **429** | 再試行までの残り時間を表示し、送信ボタンを無効化 | BE の `message` + `Retry-After` | 認証系エンドポイントのみ ([auth.md](auth.md) §6.11-3) |
| **502** | 「外部サービスの応答に失敗しました」+ **再試行ボタン** | BE の `message` | LLM / 外部検索の失敗。500 と区別して表示する (O-4) |
| **500** | 「サーバでエラーが発生しました」+ 再試行ボタン。**BE の `message` は出さない** | 固定文言 | 内部情報を画面に出さない |
| **ネットワーク失敗 / 中継層の失敗** | 「通信に失敗しました」+ 再試行ボタン | 固定文言 | **FE が生成した `request_id` を表示する** (BE に到達していないため BE 側の ID は無い。FE-L の根拠) |
| **中継の同時実行上限 / 実行時間上限に到達** (Vercel 側。FE-Q2) | **ストリーム開始前**なら上行と同じ (「通信に失敗しました」+ 再試行)。**開始後**なら §10.1 の `failed` + `reason='disconnected'` として §6.4 の「無通信 45 秒」と同じ表示 + 再接続ボタン | 固定文言 | **BE 側は正常に処理を続けている可能性がある**ため、「失敗しました」ではなく**「接続が中断されました」**と表示し、再接続 (履歴 GET + 再購読) に導く。ログは Route Handler 側に出る (§16.1 FE-Q2 の計測項目) |

**全エラー表示に共通の要件**:

1. **`request_id` を表示する** (折りたたみ or 小さい文字で可)。ユーザー報告とログを突き合わせる唯一の手段
   ([observability.md](observability.md) §4.1)
2. **`console.error` を使わない** (v2 は `no-console: error` を設定済み。V-17)。
   **失敗は Route Handler / Server Action 側の構造化ログに出す** —
   FE のログ送信先と形式は §16 の FE-Q4 (未確定)
3. **無言の失敗を作らない**: `catch` して何もしない分岐を lint で禁止する
   (`no-empty` + `@typescript-eslint/no-unused-vars` の `caughtErrors`)。**`AbortError` だけが例外**で、
   その分岐は**専用のヘルパ `isAbortError()` を通す** (握り潰しの箇所を 1 つに限定して検索可能にする)

---

## 10. ローディング / 生成中の表現

> 本節が回答する ID: **O-5 / O-4** / 対応パターン: **FE-7**

### 10.1 状態の型 (FE-J)

```ts
type StreamState =
  | { kind: 'idle' }
  | { kind: 'streaming'; startedAt: number; lastEventAt: number; … }
  | { kind: 'done'; … }
  | { kind: 'canceled' }                       // ユーザー操作。エラーではない
  | { kind: 'failed'; reason: FailureReason; requestId?: string }
```

`FailureReason` は **`timeout` / `disconnected` / `server_error` / `incomplete`** の 4 値。
**[observability.md](observability.md) §4.3 の F-4 / F-5 と対応**させ、
「何が起きたか」を画面とログの両方で同じ語彙で表す。

### 10.2 画面の要件

| 場面 | 表現 | 禁止 |
|---|---|---|
| 一覧・詳細の初期表示 | RSC の `loading.tsx` + **スケルトン** (レイアウトシフトを避ける) | 中央スピナーのみ |
| **会話ターンの生成中** | ①**中断ボタンを常に表示** ②直前のツール実行状況を 1 行で表示 (`event:` 由来) ③本文は**到着順に追記** | プログレスバー (残り時間が不明なため嘘になる) |
| **非同期ジョブ** (抽出・ファイル取り込み) | `status` と `progress` を表示。**画面を離れても継続する**ことを明示し、一覧に戻っても状態が見える | モーダルで操作をブロックする |
| **完了** | 完了を示す**単一の観測可能な要素**を出す (`data-testid="turn-complete"` 等) | 完了の合図が複数箇所に散る (E2E がフレークする。[testing.md](testing.md) §7.2 の規約 1) |
| **中断・失敗** | §9 の表に従って**必ず画面に出す** | 無言で `idle` に戻る |

**`data-testid` を仕様に含める理由**: [testing.md](testing.md) §7.2 が
「期待は終端の観測可能な 1 状態に置く」ことを E2E の規約にしており、
**その 1 状態を FE が提供しないと規約が守れない** (BE-10 の「読む側と書く側を対で設計する」と同型)。
**完了マーカーの `data-testid` はストリーミングを持つ全画面の必須要件**とする。

---

## 11. 画面構成とルーティング

> 本節が回答する ID: **A-2 (ロールによる導線)** / **A-7 (共有 UI の増分)**。
> **根拠の区分を必ず読むこと** — 「API 確定」の画面だけが仕様として確定している (DR-7)。

### 11.1 ルート一覧

**根拠の凡例**: **[API]** = [API/README.md](API/README.md) にエンドポイントが確定している /
**[未確定]** = API 設計が未着手 (仕様として確定していない)。
**プロトタイプにしか根拠が無い画面 (かつては [P] と表記する予定だった) は 1 件も無い** —
下表は全行が API 契約か [auth.md](auth.md) の決定に紐づく。
プロトタイプ由来の論点 (ナビゲーションの階層・配線されていないボタン) は**本表ではなく
下の散文**にまとめる (DR-7)。

**グループ列**: `(auth)` = 未認証 / MFA 未検証で到達する / `(app)` = 認証 + MFA 検証済みが必須 /
`(admin)` = 社内管理者のセッションが必須 (§11.3)。**遷移の規則は §11.2**。

| ルート | グループ | 画面名 | データ源 | 根拠 | 増分 |
|---|---|---|---|---|---|
| `/login` | `(auth)` | サインイン (email + パスワード) | [auth-accounts.md](API/auth-accounts.md) `POST /accounts/signin` | **[API]** (同書 §2.1)。**401 (`AU-C-`) はサインアウト経路へ流さずフォーム内エラー** (§9 の分類 C)。**`AU-C-00002` (ロック) は「管理者に解除を依頼」と案内する** — リセットではロックが外れないため (同書 §3.4) | 1 |
| **`/mfa`** | `(auth)` | **MFA (TOTP) の検証** — サインイン後に `requiredMfaType` が残っている間の唯一の到達先 | [auth-accounts.md](API/auth-accounts.md) `POST /mfa/totp/verify` | **[API]** (同書 §2.2)。到達条件は [auth.md](auth.md) §6.6。**コード不一致の 401 はフォーム内エラー** (§9 の②) | 1 |
| **`/mfa/setup`** | `(auth)` | **MFA (TOTP) の登録** (QR 表示 → コード検証) | [auth-accounts.md](API/auth-accounts.md) `POST /mfa/totp/generate` + `/verify` | **[API]** (同書 §2.2)。[auth.md](auth.md) §6.2 が本増分に含める | 1 |
| `/signup` | `(auth)` | サインアップ (招待受諾) | [auth-accounts.md](API/auth-accounts.md) 招待検証 + `POST /accounts/signup` | **[API]** (同書 §2.1)。**リンクの秘密文字列は URL に置かず POST のボディで送る** (同書 AA-D-4) | 1 |
| `/reset-password` | `(auth)` | パスワード再設定 (要求 + 確定) | [auth-accounts.md](API/auth-accounts.md) `POST /accounts/reset-password` + `/confirm` | **[API]** (同書 §2.1)。**アカウント不存在でも成功応答** (存在の漏洩防止)。**リセットはロックを解除しない** — ロック中の案内はサインイン画面で行う (同書 §3.4) | 1 |
| `/api/logout` | (Route Handler) | セッション破棄の単一経路 (画面ではない) | — | §5.2.3 | 1 |
| `/` → `/themes` | `(app)` | **ホーム = テーマ管理** (一覧・統計 4 指標 = テーマ / アイデア / 企画書 / ナレッジ件数 — [themes.md](API/themes.md) TH-Q6 で確定) | [themes.md](API/themes.md) `GET /themes` `GET /themes/stats` | **[API]**。プロトタイプもホーム = テーマ管理 (`hassan_agent_prototype_v2.html:6648-6649`。ナビ上のラベルは「テーマ」— `:6636`) | 1 |
| `/themes/[themeId]` | `(app)` | テーマ詳細 | `GET /themes/{theme_id}` | **[API]** | 1 |
| `/themes/[themeId]/members` | `(app)` | テーマのメンバー共有 | `GET/PUT /themes/{theme_id}/members` `PUT …/visibility` | **[API]** (増分 2。**増分 1 では導線を出さない** — §5.4 / A-7) | 2 |
| `/themes/[themeId]/conversations/[conversationId]` | `(app)` | **アイデア発散 (会話)** | [API/conversation.md](API/conversation.md) §1 の 7 本 (ターンは SSE — §6.3.1 の中継表) | **[API]** (2026-08-01 に FE-Q1 クローズ。実装着手可) | 1 |
| `/knowledge` | `(app)` | ナレッジ (スレッド一覧) | `GET /knowledge-threads` | **[API]** | 1 |
| `/knowledge/[threadId]` | `(app)` | ナレッジ チャット (**SSE**) | `GET/POST /knowledge-threads/{thread_id}/messages` | **[API]** | 1 |
| `/knowledge/files` | `(app)` | ナレッジ ファイル管理 (アップロード・一括削除) | `/knowledge-files` 系 5 本 | **[API]** | 1 |
| `/idea-boards` | `(app)` | アイデアボード 一覧 | `GET /idea-boards` | **[API]** | 1 |
| `/idea-boards/[boardId]` | `(app)` | ボード詳細 (フェーズ別カンバン・コメント) | `/idea-boards/{board_id}/items` 系 | **[API]** (ロール別の 403 は §9) | 1 |
| `/idea-boards/phases` | `(app)` | フェーズマスタ管理 | `/idea-board-phases` 系 4 本 | **[API]** | 1 |
| `/ideas` | `(app)` | アイデア一覧 (参照・スター・**本文/タグ編集・削除・手動登録**) + **CSV エクスポートボタン** (2026-08-01 に R-12 で追加 — v2 は発散画面に置いていたが、v3 は一覧の絞り込み結果を出す形のため本画面に置く) | [API/ideas.md](API/ideas.md) §1 の 13 本 (**2026-08-02 に `idea-boards.md` §7 から移設**) | **[API]** | 1 |
| `/ideas/[ideaId]` | `(app)` | アイデア詳細 | `GET /ideas/{idea_id}` | **[API]** | 1 |
| `/assets` | `(app)` | アセット一覧 + フォルダツリー | `/assets` `/asset-folders` 系 | **[API]** | 1 |
| `/assets/[assetId]` | `(app)` | アセット詳細 (スペック・機能ツリー・添付) | `/assets/{asset_id}` 系 | **[API]** | 1 |
| `/assets/extractions/[extractionId]` | `(app)` | **AI 抽出の進捗とレビュー確定** (**SSE** + ジョブ) | `/asset-extractions` 系 3 本 | **[API]** | 1 |
| `/news` | `(app)` | お知らせ 一覧 (未読バッジ) | `/news` 系 5 本 | **[API]** | 1 |
| `/news/[newsId]` | `(app)` | お知らせ 詳細 | `GET /news/{news_id}` | **[API]** | 1 |
| `/settings` | `(app)` | 設定 (通知) | `/settings/notifications` | **[API]** | 1 |
| **`/settings/profile`** | `(app)` | **自分のアカウント設定** — 氏名・所属・役割 / アイコン (アップロード・削除) / メールアドレス変更 (現在パスワード確認) / パスワード変更 / **MFA (TOTP) の再登録**。**2026-07-31 のレビュー 重大 3 で追加** — [auth-accounts.md](API/auth-accounts.md) §2.3.1 の 6 本に消費者となる画面が本表に無く、v2 で提供していた機能 (`hassan-v2-backend/router/router.go:66`, `:69`, `:71`-`:74`, `:233`) が v3 で使えなくなる状態だった | [auth-accounts.md](API/auth-accounts.md) `PUT /accounts/me` / `PUT /accounts/me/email` / `PUT /accounts/me/password` / `POST`・`DELETE /accounts/me/icon` / `POST /mfa/totp/reset` | **[API]** ([auth-accounts.md](API/auth-accounts.md) §2.3.1)。**メール変更・パスワード変更・MFA 再登録の「現在の資格情報が違う」は 400** (同書 AA-D-17。`old_password` / `password` / `totp_code` という**フィールドに紐づく**エラーのため) — **401 ではないのでサインアウト経路に入らない**。§9 の 400 行どおりフィールドエラーとして表示する | 1 |
| `/settings/workspace` | `(app)` | ワークスペース設定 = アセット可視性の既定 (**契約内管理者のみ**) | `GET/PUT /settings/workspace` | **[API]** (R-1。403)。**ST-Q8 により増分 2 へ後ろ倒し** | **2** |
| `/settings/usage` | `(app)` | 利用量集計 — 月 × メンバー × 活動種別のクロス集計 + CSV (**契約内管理者のみ**) | `GET /usage-summary` | **[API]** (R-1。403)。形は ST-Q9 で確定 | 1 |
| `/settings/activity-logs` | `(app)` | 活動ログ (**契約内管理者のみ**) | `GET /activity-logs` | **[API]** (R-1。403) | 1 |
| `/settings/members` | `(app)` | メンバー管理・会社情報 + **アカウントの解除 / ロック状態の表示** (⚠️ **手動ロックの UI は 2026-08-10 の AA-Q10 で実装スコープ外**) ([auth.md](auth.md) §6.9 の実行者 2 経路のうち**契約内管理者の経路**。**ロックの実行 UI はここだけにある** — 社内管理者の `/admin/accounts` は解除専用なので、**この画面が無いと製品内に即時遮断手段が存在しない**) | [auth-accounts.md](API/auth-accounts.md) §2.3.2 (メンバー管理・ロック) / §2.3.3 (会社情報) | **[API]**。403 が正常系になるガード (最後の管理者・自分自身) は同書 §3.1 の R-3 | 1 |
| **`/admin/signin`** | `(admin)` | **社内管理者のサインイン** | [auth-accounts.md](API/auth-accounts.md) `POST /admin/signin` | **[API]** (同書 §2.1)。[auth.md](auth.md) §6.2 の例外 (公開エンドポイント) | 1 |
| **`/admin/accounts`** | `(admin)` | **アカウント検索 + ロック状態表示 + ロック解除** (全契約横断・**解除専用**) | [auth-accounts.md](API/auth-accounts.md) §2.4.2 (アカウント検索 + ロック解除) | **[API]**。[auth.md](auth.md) §6.9 の実行者 2 経路 (社内管理者は解除のみ) | 1 |
| **`/admin/admins`** | `(admin)` | 社内管理者の一覧 (**MFA リセットは AA-D-22 で消滅**) | [auth-accounts.md](API/auth-accounts.md) `GET /admin/admins` | **[API]** (同書 §2.4) |

> **`Idea` 型の SSOT は [API/ideas.md](API/ideas.md) §2.1** (2026-08-02 確定。同書 §8 の R-IDA-11)。
> **手書きの型を作らず orval の生成型を使う** (§6.2 の FE-2 対策)。**旧 `idea-boards.md` §2.1 の型を参照しないこと** —
> `tag` (単数) → **`tags`** (配列)、`evaluation.rank` → **`evaluation.grade`** に変わっており、
> 旧型を正として実装すると生成型と手書きの期待が食い違う。新たに読める項目は
> `market_size` / `cagr` / `stage` / `has_knowledge` / `is_owner` / `latest_version`。

**ロック操作の UI 要件** (2026-07-30 の 2 巡目レビューで追加。[auth.md](auth.md) §6.9 のガードに対応):

- **403 が正常系として返る操作である** — 「最後の契約内管理者をロックしようとした」「自分自身をロックしようとした」の 2 つは
  仕様どおりの拒否なので、**エラーバナーではなく操作前の無効化 + 理由の表示**で表現する
  (`§9` の 403 の既定表示に任せると「失敗した」に見え、運用者が再試行を繰り返す)
- **確認ダイアログを必須にする** — ロックは対象ユーザーを即座に締め出す操作で、誤操作の影響が大きい
  (解除は自分でできるが、**最後の管理者を締め出すと解除できる者がいなくなる**ため §6.9 がガードを置いている)
- **ロック状態は一覧に常時表示する** — 「ロックされたことを管理者が知る経路」が無いと解除に到達できない
  (BE-10 の「読む側」。[auth.md](auth.md) §6.9 のロック状態の可視化)

**プロトタイプにあるが本書で仕様化しないもの (DR-7)**:
プロトタイプのナビゲーションは 7 項目 (`お知らせ` / `テーマ` / `アイデア発散` / `ナレッジ` /
`アイデアボード` / `アセット` / `設定` — `hassan_agent_prototype_v2.html:6635-6641`。
2026-07-30 更新版でホームのラベルが「テーマ」になり、お知らせが先頭へ移動) で、
**「アイデア発散」が単独のナビ項目**になっている。本書は上表でアイデア発散を
**テーマ配下 (`/themes/[themeId]/conversations/...`)** に置いた — 会話がテーマに従属することは
[design_memo.md](design_memo.md) の PoC 移植方針から導かれるが、**ナビゲーションの階層は未確定** (§16 の FE-Q5)。
**プロトタイプの画面遷移をそのまま仕様にしない**。
また、プロトタイプの各ビュー内には**配線されていないボタンが多数ある** ([API/README.md](API/README.md) §0)。
**上表に無い操作は実装対象ではない**。

### 11.2 認証の遮断 (FE-K)

- **`(auth)` / `(app)` / `(admin)` のルートグループ**で分ける。`(app)` 配下は
  **認証済み かつ MFA 検証済み**が必須
- `middleware.ts` は**許可リスト (配列) と照合**する。
  **v2 の否定正規表現 1 本 (V-14) を採らない** — 公開パスの追加が正規表現の編集になり、
  誤りが「全ページ素通り」として現れる

#### 11.2.1 許可リストは 2 本立てにする (v2 の穴を塞ぐ)

**v2 は 1 本の除外リストで 2 つの意味を兼ねている** — matcher の否定正規表現に `mfa` が入っているため
**middleware がそもそも動かず、未認証でも `/mfa` に到達できる** (V-21。
`hassan-v2-frontend/src/middleware.ts:39-42`)。v3 は意味ごとに分ける:

| 定数 | 対象グループ | 意味 | 内容 (2026-07-30 時点) |
|---|---|---|---|
| `PUBLIC_PATHS` | `(auth)` | **セッションが無くても入れる** | `/login` / `/signup` / `/reset-password` / `/api/logout` |
| `MFA_PENDING_PATHS` | `(auth)` | **セッションはあるが MFA 未検証でも入れる** | `/mfa` / `/mfa/setup` / `/api/logout` |
| `ADMIN_PUBLIC_PATHS` | `(admin)` | 管理者セッションが無くても入れる | `/admin/signin` |
| `ADMIN_MFA_PENDING_PATHS` | `(admin)` | 管理者セッションはあるが MFA 未検証・未登録でも入れる | `/admin/mfa` / `/admin/mfa/setup` |

**4 本に分ける理由**: 一般ユーザーと社内管理者は**別の Cookie を読む別の判定**であり (§11.3.1)、
1 本にまとめると「一般ユーザーのセッションで `/admin/accounts` に入れるか」の判定が
リストの中身に依存してしまう。**グループごとに判定関数を持ち、リストはその入力にする**。

#### 11.2.2 3 状態 × 到達可能ルートの遷移表

| セッションの状態 | `PUBLIC_PATHS` | `MFA_PENDING_PATHS` | `(app)` 配下 | `(admin)` 配下 |
|---|---|---|---|---|
| **未認証** (セッション Cookie 無し / 復号失敗) | 到達可 | **`/login` へ 302** | **`/login?next=…` へ 302** | §11.3 |
| **認証済み・MFA 未検証** (`requiredMfaType` が残る) | **`/mfa` へ 302** (サインイン画面に戻さない) | 到達可 | **`/mfa` へ 302** | §11.3 |
| **認証済み・MFA 検証済み** | **`/` へ 302** (サインイン済みの人にサインイン画面を見せない) | **`/` へ 302** | 到達可 | §11.3 |

- **判定に使う値**: `getToken()` で読んだセッションの `requiredMfaType`
  (v2 の `token.requiredMfaType !== 'totp'` と同じ判定。V-14。値の出所は §5.2.2)
- **MFA 必須でないアカウント**は `requiredMfaType` が入らないため、
  「認証済み・MFA 検証済み」の行に落ちる (会社単位で MFA を無効にできる —
  [auth.md](auth.md) §6.2 の「一般ユーザーの MFA 要否は会社単位の設定」)
- **`(app)` 配下に到達できるのは 3 行目だけ**という形にすることで、
  「`/mfa` を許可リストに入れたら未認証でも入れてしまった」(v2 の V-21) が構造的に起きない
- **`(admin)` 配下の判定は一般ユーザーのセッション状態と無関係**である (別 Cookie を読む別分岐。§11.3.1)。
  上表の右端列を「§11.3」としているのはそのため — **一般ユーザーとして認証済みであることが
  `(admin)` への到達条件に一切ならない**

#### 11.2.3 CI での照合 (D-2)

**`middleware.ts` の許可リストと、対応するルートグループ配下の実ページ一覧が一致することを検査する**
(page があるのにどのリストにも無い = **認証必須になってしまっている**、
逆にリストにあるのに page が無い = **消したページの許可が残っている**)。
**照合は 2 組**: `(auth)` ↔ `PUBLIC_PATHS ∪ MFA_PENDING_PATHS` /
`(admin)` ↔ `ADMIN_PUBLIC_PATHS ∪ ADMIN_MFA_PENDING_PATHS`
(`(admin)` の残り = `/admin/accounts` / `/admin/admins` は「管理者認証 + MFA 検証済み」必須)。

- **実体**: [ci.yml](../../templates/app-monorepo/.github/workflows/ci.yml) の `frontend` ジョブの「検査 2 公開パスの許可リストとルートグループの一致」ステップ が
  許可リストの存在確認と `scripts/check-public-paths.sh` の呼び出しまでを持つ。
  **照合スクリプト本体は実装リポで書く** (雛形は「無ければ落ちる」形にしてある)
- **集合の一致は和集合で見る**: `(auth)` の page 集合 = `PUBLIC_PATHS ∪ MFA_PENDING_PATHS`
  から `/api/logout` (画面ではない) を除いたもの
- **和集合の一致だけでは「どちらのリストに入っているか」の誤りを検出できない**
  (`/mfa` が `PUBLIC_PATHS` に移っていても和集合は変わらない = **v2 の V-21 と同じ状態**)。
  したがって**検査に 1 行加える**: **`/mfa` で始まるパスが `PUBLIC_PATHS` に現れたら落とす**。
  これは**リストの中身に対する検査**であり、**遮断の判定にパスの前方一致を使うことではない**
  ([auth.md](auth.md) §6.7 が前方一致による判定を却下しているのはゲート側の話。
  ゲートは §11.2.2 の 3 状態で判定する)
- **[auth.md](auth.md) §6.7 が BE 側で行う「パス → 要求する認証系統」の宣言と照合**の FE 版であり、
  同節が「認証あり / なしだけの検査にしない」と決めたのと同じ理由で**系統単位で照合する**

### 11.3 社内管理者経路 (FE-D' の詳細。auth.md §6.2 の例外に対応)

> 本節が回答する ID: **A-2** (社内管理者の UI) / **A-1** (系統の分離) / 対応 AC: **AC-1.5**

**なぜ FE に必要か**: [auth.md](auth.md) §6.9 の「トークン漏洩時に即座に遮断する」設計と
「契約内管理者が全員ロックされたときの回復」は、**ロック解除に到達できる UI があること**を前提にしている。
UI がどの設計書にも無いまま増分 1 を出すと、**回復手段が製品内に存在しない状態で本番稼働する**。

#### 11.3.1 セッションとトークンの分離

| 項目 | 一般ユーザー | 社内管理者 |
|---|---|---|
| next-auth のマウント先 | `app/api/auth/[...nextauth]` | **`app/api/admin-auth/[...nextauth]`** |
| セッション Cookie | `__Host-next-auth.session-token` (v2 と同じ命名。HTTPS 時) | **別名の Cookie** (`__Host-admin-session-token` 相当) |
| BE へ付けるヘッダ | `X-Token` (`lib/api/mutator.ts`) | **`X-Admin-Token`** (`lib/api/admin-mutator.ts` のみ。§5.2.1) |
| セッションの寿命 | 7 日 ([auth.md](auth.md) §6.9-3) | **7 日で確定** (2026-07-31 の FE-Q8 回答 = 一般ユーザーと同じ。[auth-accounts.md](API/auth-accounts.md) §2.4 の管理者トークンも 7 日)。FE の `maxAge` は BE の値に一致させる |

- **2 つのセッションは同時に成立してよい** (Cookie 名が違うため上書きし合わない)。
  v2 は 1 つの Cookie を 3 provider が共有するため、**管理者作業中に一般ユーザーとしてサインインすると
  管理者セッションが消える** (V-19 / V-20)
- **`(admin)` 配下の判定は `middleware.ts` の別分岐**で行う: 管理者 Cookie が無ければ `/admin/signin` へ、
  **`mfaVerified` が偽なら `/admin/mfa`** (未登録なら `/admin/mfa/setup`) へ。
  §11.2.2 の 3 状態と同じ形を管理者系にも適用する
- **`(admin)` から一般ユーザーの API を呼ばない / `(app)` から管理者 API を呼ばない**。
  L-F4 の zone で `features/admin/**` と他ドメインの相互 import を禁止する (§5.2.1)

#### 11.3.2 WAF の IP 許可リストとの衝突 (未解決。設計上の申し送り)

[auth.md](auth.md) §6.2 は多層防御の 1 つとして
**「社内管理者系エンドポイントを WAF の IP 許可リストで社内からのみ到達可能にする」**を決めている
([infrastructure.md](infrastructure.md) の INF-L が prod の ALB に WAF をアタッチする決定を持つ)。

**FE-D (BE 呼び出しは全てサーバ側) と組み合わせると、この IP 制限が成立しない** —
ALB が見る送信元 IP は**運用者のオフィスの IP ではなく Vercel の Function の IP** になる。
**Vercel の egress IP を許可リストに入れると、実質的に「誰でも通る」に等しくなる**
(Vercel 上の任意のプロジェクトが同じ帯域から出る)。

- **本書の立場**: **MFA の必須化 (auth.md §6.2) とレート制限・監査記録を主たる防御とし、
  IP 制限は「Vercel を経由しない経路が用意できた場合のみ」有効な追加層として扱う**。
  同節が「MFA を主たる防御とし、IP 制限は多層防御として併用する (どちらかで代替しない)」と
  書いているため、**IP 制限が外れることは同節の前提を弱める** — したがって
  **[auth.md](auth.md) §6.2 と [infrastructure.md](infrastructure.md) INF-L への是正要求**を出す (§16.2-7)
- **選択肢は 3 つあり、いずれもユーザー決定を要する** ([Answer] FE-Q7):
  ①Vercel の固定 egress IP 機能を使う (**利用可否・プラン要件は未調査**) ②管理者 UI を
  Vercel ではなく BE の ALB 配下 (WAF の内側) に配信する (**FE-D' の却下 (b) に戻る + 新規インフラ**)
  ③IP 制限を管理者経路について諦め、MFA + レート制限 + 監査 + `SuperAdmin` の複数運用で担保する
- **無言で ③ を採らない**。③ は本書の暫定既定だが、**auth.md の決定を弱める変更**なので
  FE 側だけで確定させない

---

## 12. Vercel との関係

> 本節が回答する ID: **D-1**。**環境の対応表・Production Branch・リリース順序の SSOT は
> [operations.md](operations.md) §3.2 / §5.4 と [infrastructure.md](infrastructure.md) §5.3**。
> 本節は **FE 固有の環境変数の分類**だけを定める。

| 変数 | スコープ | 分類 | 値 |
|---|---|---|---|
| `API_BASE_URL` | **サーバのみ** (`NEXT_PUBLIC_` を付けない) | 非秘密の環境値 | Preview → dev の BE / Production → prod の BE |
| `NEXTAUTH_URL` (または `AUTH_URL`) | サーバのみ | 非秘密 | 各環境の FE の URL |
| `NEXTAUTH_SECRET` (または `AUTH_SECRET`) | **サーバのみ** | **秘密** | 環境ごとに別値。Vercel の環境変数 (暗号化) に置く |
| `NEXT_PUBLIC_APP_ENV` | ブラウザに露出 | 非秘密 | `dev` / `prod`。**表示・計測のラベル用途のみ**。**分岐ロジックに使わない** |
| **`FEATURE_<機能名>`** (フィーチャーフラグ) | **サーバのみ** (**`NEXT_PUBLIC_` を付けない**) | 非秘密 | **Vercel の環境変数** (`Preview` = dev の値 / `Production` = prod の値)。命名と既定値 (未定義 = 無効) は [operations.md](operations.md) §7.2 (OP-I) が SSOT |
| **管理者用 next-auth の秘密** (`ADMIN_AUTH_SECRET` 相当) | **サーバのみ** | **秘密** | §11.3.1 で next-auth を 2 系統に分ける帰結。**一般ユーザー側と同じ値を使わない** (片方の漏洩がもう片方に及ぶ) |
| 上限値・既定値 (生成数・`limit` の上限等) | — | **環境変数に置かない** | **API レスポンスで配る** ([operations.md](operations.md) §3.3 の末尾 / BE-2) |

- **`API_BASE_URL` をサーバ専用にできるのは FE-D の帰結**。ブラウザから BE を直接叩かないため
  公開する必要が無く、**v2 の `NEXT_PUBLIC_API_BASE_URL` (V-8) をやめられる**
- **フラグの判定は Server Component / Server Action で行い、ブラウザに配らない**。
  [operations.md](operations.md) §7.2 (OP-I) が **「フラグを API で配らない」「判定の正は BE
  (フラグ OFF のエンドポイントは 404)」「FE の役割は導線を隠すだけ」**を確定済みなので、
  **FE のフラグはサーバ側で導線を出すかどうかを決めるだけ**であり、
  **`NEXT_PUBLIC_` を付ける必要が無い** (付けるとフラグの内容がブラウザバンドルに載る)
- **秘密を `NEXT_PUBLIC_*` に置かない** (雛形 [CLAUDE.md.tmpl](../../templates/app-monorepo/frontend/CLAUDE.md.tmpl)
  の Vercel 節 / [operations.md](operations.md) §3.2)。
  **機械強制**: CI で `NEXT_PUBLIC_` の付いた変数名の一覧を出力し、
  **許可リスト (上表の `NEXT_PUBLIC_APP_ENV` 1 件のみ) と一致しなければ落とす**
  ([ci.yml](../../templates/app-monorepo/.github/workflows/ci.yml) の `frontend` ジョブの「検査 3 NEXT_PUBLIC_ の許可リスト」ステップの `ALLOWED`)。
  **フラグを追加しても許可リストは増えない** — 増やす必要が生じたら、それは
  「サーバ側で判定していない」ことの徴候なので PR で設計に戻す
- **Preview には prod の値を登録しない** ([operations.md](operations.md) §3.2 の運用ルール)。
  feature ブランチの Preview も dev の BE を指す
- **CORS**: FE-D により**ブラウザから BE へのクロスオリジン要求が無くなる**ため、
  Preview URL が変動しても BE の許可リスト更新が不要になる
  ([operations.md](operations.md) §3.2 / [infrastructure.md](infrastructure.md) §5.3 の確認事項に対する
  **FE 側からの回答**)。**ただし次の 2 つの条件が付く**:
  1. **FE-Q2 (Vercel で 5 分の SSE 中継ができるか) が肯定された後にのみ成立する**。
     不成立時の代替 (§2 FE-D の却下 (d) = ブラウザが直接 SSE を張る) は
     **クロスオリジン要求を復活させる**ため、**BE の許可リストを先に縮小すると退避路を自ら塞ぐ**。
     したがって §16.2-5 の是正要求 (operations への反映) は **FE-Q2 の実測後**に出す
  2. **中継対象は §6.3.1 の許可リストに限る**。catch-all プロキシを置かないことが
     「ブラウザは BE を直接叩けない」という性質の前提である
- **CORS が必要なまま残る経路が 1 つある**: **S3 の署名付き URL からのダウンロード**
  ([API/README.md](API/README.md) D-API-14' が非公開バケット + presigned GET を決定)。
  これは**ブラウザ → S3** であって ブラウザ → BE ではないため FE-D の対象外であり、
  **S3 バケット側の CORS 設定 (許可オリジン = Vercel の環境別 URL) が別途必要**になる
  ([infrastructure.md](infrastructure.md) §3.3 の S3 CORS の要確認項目に対する FE 側の回答:
  **FE はダウンロード URL をブラウザで直接開く前提で設計する** — 中継すると
  Vercel の帯域と実行時間を消費するため)

---

## 13. 本番観点への回答

| ID | 回答 | 備考 |
|---|---|---|
| **A-1** | **§2 FE-D / §5.2 / §6.3**: BE の JWT は HttpOnly セッション Cookie 内のみ。ブラウザの JS から触れず、BE 呼び出しは全てサーバ側から `X-Token` を付ける。SSE の中継は**エンドポイントごとの Route Handler (許可リスト = ファイルの存在。§6.3.1)** に限り、**`Sec-Fetch-Site` / `Origin` でクロスサイト起動を弾く** (§6.3.3)。`X-Admin-Token` は `admin-mutator.ts` 1 ファイルのみ (§5.2.1)。401 時の破棄は `/api/logout` の 1 経路 (§5.2.3) | v2 の V-12 (ブラウザに JWT) と V-19 / V-20 (単一セッションで系統を兼ねる) を明示的に却下 |
| **A-2** | **§9 / §11.1 / §11.3**: ①契約内管理者限定の 3 画面は**導線を出さない**が**判定の正は BE (403)** ②導線判定に使うロールの出所は**サインイン応答 → セッション**の 1 経路に固定 (§5.2.2。**応答に `role` を追加する是正要求は §16.2-6**) ③**社内管理者の 5 画面を `(admin)` グループとして本増分に含める** (§11.3。[auth.md](auth.md) §6.2 の例外に対応) | **WAF の IP 許可リストが FE-D と両立しない**点は §11.3.2 で未解決として起票 (FE-Q7 / §16.2-7) |
| **A-3** | **対象外** (FE に所有者列の概念が無い) | SSOT は [data-model.md](data-model.md) / [auth.md](auth.md) §6.3 |
| **A-4** | **§5.4**: FE は `scope` の列挙値しか送れず、`account_id` を送る経路を作らない。絞り込みは全て BE | [API/README.md](API/README.md) D-API-8 |
| **A-5** | **§9 / §11.2**: 401/403/404/400/409/429/502/500 ごとの画面の振る舞いを表で確定。**404 の理由を FE が推測して文言を変えない**。**MFA 未検証 (BE は 401) の遷移先 `/mfa` をルートとして定義**し (§11.1)、3 状態 × 到達可能ルートの遷移表と 2 本の許可リストで表現 (§11.2.1 / §11.2.2) | 判定規則の SSOT は [auth.md](auth.md) §6.6。v2 の V-21 (未認証でも `/mfa` に入れる) を却下 |
| **A-6** | **対象外 (BE の責務)**。FE は LLM にツールを実行させる経路を持たず、ツールのスコープは UseCase がクロージャに束縛する | [architecture.md](architecture.md) §3.8.2 / [API/README.md](API/README.md) §2.4 |
| **A-7** | **§5.4 / §11.1**: 共有・可視性の UI は**増分 2**。増分 1 では `scope` セレクタとメンバー共有画面の導線を出さない (BE が 400 を返すため) | [API/README.md](API/README.md) D-API-8' |
| **O-1** | **§2 FE-L / §5.2 / §6.3**: FE が `X-Request-Id` (ULID) を生成し、API・SSE 中継の両方に付ける。エラー表示にも出す (§9) | [observability.md](observability.md) §4.1 が「あれば尊重」 |
| **O-2** | **対象外 (BE の責務)**。FE は LLM を直接呼ばない | SSOT は [observability.md](observability.md) §4.2 |
| **O-3** | **§6.3.2**: クライアント切断を BE に伝播させ、**放置された LLM 実行を止める**。しきい値の判定と打ち切りは BE。**加えて FE-D が新規に作った課金・容量の面 (Vercel の Function 実行時間課金と同時実行上限 = 同時 SSE 接続数の上限) を §16.1 FE-Q2 の実測項目として起票**し、上限到達時のユーザー表示を §9 に 1 行として定義した | LLM のコスト上限は BE / [observability.md](observability.md) §4.4。**Vercel 側のコストは本書の担当**として明示した (中継を導入したのは本書の判断であるため) |
| **O-4** | **§6.4 / §9 / §10.1**: 失敗を 4 分類 (`timeout` / `disconnected` / `server_error` / `incomplete`) で画面に出す。**不完全終了を成功に見せない**。空 `catch` を lint で禁止 | [observability.md](observability.md) §4.3 の F-4 / F-5 と語彙を対応 |
| **O-5** | **§6.4**: 切断・無通信 45 秒・ローリング更新の 3 経路すべてに画面の振る舞いと復元手順 (履歴 GET + 再購読)。自動再接続は却下 | [API/README.md](API/README.md) J-7 |
| **O-6** | **対象外 (BE の責務)** | [observability.md](observability.md) §4.5 |
| **O-7** | **対象外 (BE / インフラの責務)**。**先送り先**: FE 起点のエラーをどこに送るか (§16 FE-Q4) が決まればアラート対象に追加を検討する | — |
| **D-1** | **§12**: FE の環境変数を 7 行で確定 (**フィーチャーフラグ = Vercel の環境変数**を [operations.md](operations.md) §7.2 OP-I に合わせて追加、**管理者用 next-auth の秘密**を §11.3.1 の帰結として追加)。`API_BASE_URL` はサーバ専用。環境の対応表は [operations.md](operations.md) §3.2 | — |
| **D-2** | **§3.3 / §7.2 / §8.2 / §11.2.3 / §12**: 検査 7 種を CI ゲートにする。**雛形の実装状況と残りは §16.2-1 の表**が SSOT (2026-07-30 に eslint 設定 + CI 検査 4 本が入り、**2026-07-30 に tailwind プラグインの 2 ルールと `X-Admin-Token` の局所化検査も追加され、7 検査すべてに機構が入った**)。**段とマージ条件の SSOT は [testing.md](testing.md) §9 / §10** であり、**FE の検査を同書に登録する是正要求を §16.2-1 に出した** | 登録しないと「SSOT の外にある検査」になる (§8.2) |
| **D-3** | **参照**: FE のデプロイ手順・BE との互換順序は [operations.md](operations.md) §5.1 / §5.4 | 本書では再定義しない |
| **D-4 / D-5 / D-6 / D-7 / D-8** | **対象外**。DB マイグレーション・シークレットの保管基盤・Managed Agent のライフサイクル・段階リリース・IaC は FE の責務外。**先送り先**: [operations.md](operations.md) / [infrastructure.md](infrastructure.md) | FE に関わる範囲 (Vercel の環境変数・フラグによる導線の非表示) のみ §12 で扱った |

---

## 14. FE-1〜FE-7 を構造で潰す対応表

**全 7 件に対応**。「気をつける」で終わらせず、**構造 (依存方向) / lint / テストの存在検査**のいずれかに落とす。

| # | パターン | 本書の判断 | 担保手段 |
|---|---|---|---|
| **FE-1** | AbortError 未処理 (useEffect クリーンアップで unhandled rejection) | **§5.2 の 6 / §6.4**: 中断は**正常系**として仕様化。状態 `canceled` を型に持つ (§10.1)。握り潰しは**専用ヘルパ `isAbortError()` 1 箇所**に限定 | **構造** (型に `canceled` がある) + **lint** (空 `catch` 禁止 / `isAbortError()` 以外の握り潰しを検索可能に) + **テスト** ([testing.md](testing.md) §4.2 の必須ケース) |
| **FE-2** | snake_case 漏れ | **§5.3 / §2 FE-E'**: **変換層を作らない**のが既定。生成型を唯一の型ソースにし、ViewModel は 4 条件のいずれかに該当する場合のみ作る (一方向変換) | **構造** (orval 生成型 + L-F6) + **CI** (生成物の再生成差分検査。雛形 [ci.yml](../../templates/app-monorepo/.github/workflows/ci.yml) の `contract` ジョブ) |
| **FE-3** | デザイントークン未使用 (ハードコード px / 汎用クラス) | **§7**: 意味ベースのトークン体系を 5 系統に限定して定義し、`theme.extend` を唯一の定義場所にする | **lint**: hex リテラル禁止と `style` 属性禁止は**実装済み** ([.eslintrc.json.tmpl](../../templates/app-monorepo/frontend/.eslintrc.json.tmpl):31-38)。`no-arbitrary-value` / `no-custom-classname` は実装済み: [.eslintrc.json.tmpl](../../templates/app-monorepo/frontend/.eslintrc.json.tmpl) の `tailwindcss/no-arbitrary-value` (2026-07-30) + **可視化** (`globals.css` の行数。[ci.yml](../../templates/app-monorepo/.github/workflows/ci.yml) の `frontend` ジョブの「検査 4 globals.css の行数」ステップ) |
| **FE-4** | パーサーの非 export (テスト不能) | **§8.1**: パースは `lib/parse/` と `features/*/lib/` に置き、**必ず `export`**。reducer も純粋関数として `export` (§4.2 の要件 1) | **CI の存在検査** (対象ファイルに同名 `*.test.ts` が無ければ落とす。§8.2)。**実装済み**: [ci.yml](../../templates/app-monorepo/.github/workflows/ci.yml) の `frontend` ジョブの「検査 1 併置テストの存在」ステップ — export されていなければテストが書けないため、存在検査が export を強制する。**[testing.md](testing.md) §10 の存在検査に 6 番として登録済み** (2026-07-30。同書 §10 の表を参照。以前の「未了」は状態語の stale だった = DR-8) |
| **FE-5** | lib への JSX/hook 混入 (循環依存) | **§3.3 の L-F1 / L-F2**: `lib/**` と `features/*/lib/**` から `react` / `react-dom` / `next/*` を import 禁止。`lib` は `features` を知らない | **lint** (`import/no-restricted-paths` + `no-restricted-imports`)。**実装済み**: [.eslintrc.json.tmpl](../../templates/app-monorepo/frontend/.eslintrc.json.tmpl):55〜 (zone) と後続の overrides。v2 の eslint には依存方向のルールが 1 つも無く (V-17)、雛形も 2026-07-30 まで設定ファイルを持っていなかった — **2026-07-30 の 2 巡目レビューで `no-restricted-imports` にも「override は上書き」の欠陥が見つかり修正済み** — `src/features/*/lib/**` 用の override (:164 付近) に **L-F1 と L-F4 の両方を再掲**した (片方だけ書くと後勝ちで react / next 禁止が消え、FE-5 の担保が失われる)。**残作業は L-F4 の `@/features/*` パターンを実ドメイン名へ展開すること** (実装リポ。§15.1 の 1-b) |
| **FE-6** | 数値パーサのレンジ誤抽出 (「120-420億円」→「-420億円」) | **§8**: 数値・レンジ・単位のパースを `src/lib/parse/` に**集約**し、**併置テストを CI で必須化**。PoC は分離済みでも発生した (P-7) ため、分離ではなくテストで潰す | **CI の存在検査** + **テストの必須ケース** ([testing.md](testing.md) **§4.2 の `lib/` 行**が FE の SSOT。§4.1 は backend の表なので参照しない) |
| **FE-7** | 分割 waitFor による中間レンダーの誤検知 | **§10.2**: **完了を示す単一の観測可能な要素 (`data-testid`) を FE が提供する**ことを仕様にする。§4.2 の要件 3 (イベント列から state を再構築) で中間状態の非決定性を減らす | **構造** (完了マーカーの提供義務) + **テスト規約** ([testing.md](testing.md) §7.2 の規約 1〜4 と 雛形 CLAUDE.md.tmpl のテスト規約が SSOT) |

**BE 由来だが FE 側に対処が必要なもの**:

| # | 内容 | 本書の対応 |
|---|---|---|
| **BE-7** | SSE のマルチライン取りこぼし | **§6.2 の S-1〜S-8** (ブロック分割・空行を本文として通す・`data:` 行を trim しない・未知イベントを捨てない) |
| **BE-2** | 設定値の hard cap 散在 | **§4.3 / §5.2**: 間隔・タイムアウトは `src/lib/config.ts` の 1 箇所。**上限値は API レスポンスで受け取り FE に定数を持たない** (§12) |
| **BE-10** | 読む側と書く側の対 | **§10.2**: [testing.md](testing.md) §7.2 が要求する完了マーカーを FE が**書く側**として提供する |
| **BE-12** | 生成物のフィールド契約の食い違い | **§5.1 / §6.2 の S-8**: 型は生成物のみ。**SSE の手書き型を作らない** (v2 の V-10 が FE 側の実例) |

---

## 15. 実装リポへの引き渡し

### 15.1 依存順序 (直列必須)

0. **FE-Q2 の実測 (雛形展開より前)** — **公式ドキュメントによる一次調査は 2026-07-30 に完了し、
   ①は「Vercel Pro 以上 + Node.js ランタイム + `maxDuration` 明示設定」で成立する見込み、
   ②③は解消**した (§16.1 の FE-Q2)。**この段に残るのは 2 つだけ**:
   (a) **`maxDuration = 800` の Route Handler が 5 分超のストリームを実際に完走するかの実測 1 回**
   (Preview と Production の両方。空の Next.js プロジェクト 1 つで足り、他の作業と独立)
   (b) ~~「Vercel Pro 以上を前提にしてよいか」のユーザー確認~~ → **回答済み (2026-07-31): Pro 以上を前提にする** (§16.1 FE-Q2)。
   **(a) が不成立、または (b) が否なら §2 FE-D の採用案が崩れ、
   BE の新規 API・[auth.md](auth.md) の是正・plan.md への Task 追加が連鎖する** —
   後の段で判明すると手戻りが最大になるため、**最初に潰す**
1. **雛形の展開 + 基盤設定** — `templates/app-monorepo/frontend/` をコピーし、次を**引き渡し物として作る**:

   | # | 成果物 | 由来 |
   |---|---|---|
   | 1-a | `package.json` (scripts: `dev` / `build` / `lint` / `test` / `generate`) + `tsconfig.json` + `.node-version` | 雛形の [ci.yml](../../templates/app-monorepo/.github/workflows/ci.yml) が前提にしている |
   | 1-b | **`.eslintrc.json`** (雛形の `.eslintrc.json.tmpl` をリネーム。**L-F4 の `@/features/*` パターンを実ドメイン名に展開**し、**`eslint-plugin-tailwindcss` の `no-arbitrary-value` / `no-custom-classname` を追加**する) | §3.3 / §7.2 / §16.2-1 |
   | 1-c | **vitest 設定** (`vitest.config.ts` + `setup` ファイル。Testing Library) | [testing.md](testing.md) §4.2 |
   | 1-d | **`scripts/check-public-paths.sh`** (§11.2.3 の照合。雛形は呼び出し側だけを持つ) | §11.2.3 |
   | 1-e | **`X-Admin-Token` の局所化検査** (§5.2.1 の検査 7。雛形に無い) | §5.2.1 |
   | 1-f | `middleware.ts` の 2 本の許可リスト定数 (`PUBLIC_PATHS` / `MFA_PENDING_PATHS`) | §11.2.1 |

   **§3.3 の lint zone と §7.2 のトークン規則をこの時点で入れる**
   (後から入れると既存コードが一斉に落ちて無効化される)
2. **デザイントークンの確定** (§7.1) — プロトタイプの値を意味ベースの名前に写す。
   **1 と同時、かつ最初の画面より前**。トークンが無い状態で画面を書くと任意値が入る
3. **`swagger.json` の取得と `npm run generate` の配線** (§5.1) — BE の OpenAPI が
   1 ドメイン分でも出た時点で着手可能
4. **`lib/api/mutator.ts` + 認証 (next-auth) + `middleware.ts`** (§5.2 / §11.2) — 全画面の前提
5. **`lib/sse/`** (§6) — **SSE イベント型が OpenAPI に定義された後**。定義前に着手すると V-10 のドリフトになる
6. 画面 (§11.1) — 3〜4 の完了後、**ドメインごとに並列可能**

### 15.2 並列可能

- **ドメインごとの画面実装** (テーマ / アセット / ナレッジ / アイデアボード / お知らせ / 設定 /
  **admin** (§11.3)) — L-F4 (features 間の import 禁止) により**衝突しない構造になっている**。
  **`admin` は認証基盤 (4 の完了) の後、他ドメインと並行して着手できる**
  (依存するのは管理者用 next-auth と `admin-mutator.ts` のみ)
- `components/` の共通 UI primitives の整備
- `lib/parse/` のパーサとテスト (BE の実装と無関係に書ける)

### 15.3 参照すべき既存実装

| 目的 | 参照先 | 使い方 |
|---|---|---|
| Server Actions + orval の組み合わせ | `hassan-v2-frontend/src/features/ai-sheet/actions` | **形は踏襲**。`'use server'` の置き方と生成関数の呼び出し方 |
| orval 設定 | `hassan-v2-frontend/orval.config.js:6-17` | **出力設定は踏襲、`input.target` は変更** (`:20-22` を採らない。§5.1) |
| API クライアントの mutator | `hassan-v2-frontend/src/lib/api-client.ts:51-79` | **骨格は参考、§5.2 の 7 点を変更**して書き直す。**両ヘッダに同一値を入れる `:38-49` は採らない** (§5.2.1) |
| next-auth の設定 | `hassan-v2-frontend/src/lib/auth.ts:126-132` (session / jwt の maxAge) / `:134-153` (コールバック) | **踏襲**。BE の JWT をセッションに載せる形と、サインイン応答の属性をセッションに載せる形 (`:49-57`) は同じ (**ブラウザに渡さない**点と `role` の追加が違う。§5.2.2) |
| **管理者用 next-auth を分ける形** | v2 に前例が無い (`同:31-33` / `:66-67` / `:97-98` が**1 つの設定に 3 provider**。V-19) | **反面教師**。§11.3.1 のとおり Cookie とマウント先を分ける |
| middleware | `hassan-v2-frontend/src/middleware.ts:23-34` | **判定ロジックは踏襲、matcher は許可リスト方式に変更** (`:39-42` を採らない。§11.2)。**`/mfa` を除外リストに入れる形 (V-21) は採らない** |
| **MFA / 管理者の画面構成** | `hassan-v2-frontend/src/app/(auth)/mfa/page.tsx` / `src/app/(auth)/admin/login/page.tsx` / `src/app/admin/` 配下 8 ページ / `src/features/admin/` | **画面の作りとフォームの流れは参考**。v3 が作るのは §11.1 の管理者 5 画面のみ (v2 の一覧・会社管理は [auth.md](auth.md) §6.2 で対象外) |
| SSE の読み取り | `hassan-v2-frontend/src/features/research/actions/create-stream-research-chat.ts:37-108` | **反面教師**。§6.2 の S-1〜S-8 と §9 の要件 3 が、この実装の各問題に 1 対 1 で対応する |
| SSE のブロックパーサ | `claude_managed_agents/frontend/src/lib/sse.ts` | **`event:` 名を読み複数 `data:` を連結する形は踏襲**。`.trim()` (`:15`) と `null` 返し (`:19-21`) は採らない |
| Tailwind の設定 | `hassan-v2-frontend/tailwind.config.ts:104-176` | **keyframes / animation は流用可**。`theme.extend` の色・間隔の命名 (`:12-97`) は採らない |
| Playwright の構成 | `hassan-v2-frontend/playwright.config.ts` | [testing.md](testing.md) §7.3 が踏襲を決定済み (storageState 方式) |
| 雛形 (CI / pre-commit / エージェント定義) | [../../templates/app-monorepo/frontend/](../../templates/app-monorepo/frontend/CLAUDE.md.tmpl) | **そのまま使い、§16 の是正要求を反映してから展開する** |

---

## 16. 残課題 / 要確認

### 16.1 ユーザー・調査待ち (暫定既定で設計を進めている)

- **FE-Q1: 会話 (アイデア発散) の SSE イベント型が未定義** →
  **クローズ済み (2026-08-01)**。[API/conversation.md](API/conversation.md) §5 が
  **イベント型を discriminated union として確定**した (PoC 9 種を土台に、`artifact` を単一形 `{kind, payload}` へ統一・
  進捗を `progress` 1 種へ統合・`error` を `CodedError` 形へ・`turn_summary` を追加。同 §5.4 に PoC からの対応表)。
  **解けたブロック**: ①§6.3.1 の中継 Route Handler が確定 (`app/api/stream/conversations/[sessionId]/messages/route.ts`)
  ②§6.2 の **S-9 (`unknown` 固定) の対象経路が無くなった** ③§11.1 の会話画面が `[未確定]` → `[API]` になり
  **増分 1 のスコープが閉じた**。以下は当時の記録 (経緯として残す)。
  **暫定既定**: §6 の共通クライアントは「イベント名 + payload」の汎用形で先に作り、
  **型の確定後に decode 層 (`lib/sse/decode-event.ts`) だけを差し替える**。
  **暫定既定の歯止め (§6.2 の S-9)**: 汎用形の payload の型は **`unknown` 固定**。
  暫定の構造体を手書きしない・`as` を書かない・narrow は `decode-event.ts` の中だけ。
  **影響範囲**: 会話画面 (§11.1) の実装着手は型確定後。**先に手書き型で実装すると V-10 のドリフトを再生産する**。
  **確認したいこと**: 会話 API の設計着手時期。
  **§11.1 は会話画面を増分 1 に置きながら「実装着手不可」としているため、
  Task が立たないと増分 1 のスコープが閉じない** → **plan.md への Task 追加を §16.2-3 の是正要求に含めた**。
  **設計入力の追記 (2026-07-30)**: 更新版プロトタイプの会話ビュー (`viewProject` `:6672-7360` / JS `:7877-10459`) に
  会話 API 設計の入力になる UI が大幅に追加された — **アーティファクトのバージョン管理**
  (スナップショット保存/復元/削除 — `:9116-9375`。BE-1 の旧バージョン参照ミスと直結)、
  **発散設計コンポジットウィジェット** (起点 + 差別化要素を 1 メッセージで確定 — `:9881-10049`)、
  **持ち込みアイデア入力** (PDF ドラッグ&ドロップ — `:9605-9861`。**アップロード経路が 4 系統目になる制約は
  [API/assets.md](API/assets.md) §5 の AS-Q11 が SSOT** — D-AS-4 は 3 系統を前提に専用 API を却下している)、**企画書 8 サブタブ**
  (サブタブ単位のバージョン・履歴・再生成 — `:6911-7349`)。会話 API 設計タスクの起草時に必ず参照する
  [Answer]: **会話 API 設計は Task-3i (認証・アカウント基盤 API) の後に着手する** (2026-07-31 ユーザー回答。
  plan.md に Task-3p として起票済み)。スコープには LM-Q1 (P-3 の P-1 への統合) と LM-Q2 (v2 のアイデア生成・
  企画書生成・カスタムリサーチの会話フロー統合) の統合設計を含む ([llm-migration.md](llm-migration.md) §9.1)

- **FE-Q2: Vercel の Route Handler で SSE を 5 分間中継できるか / いくらかかるか**
  (**公式ドキュメントによる一次調査は 2026-07-30 に完了。残るのは実測 1 回とプラン決定**)。

  > **一次ソースで判明した事実** (`https://vercel.com/docs/functions/limitations`。同ページの
  > `last_updated: 2026-07-01`):
  >
  > | 事実 | 出典の記述 | ①〜④ への影響 |
  > |---|---|---|
  > | **Node.js ランタイムの `maxDuration` は Hobby が「300s default and maximum」、Pro / Enterprise が「300s default, 800s maximum, 1800s extended maximum」** | 同ページ「Max duration」の表 | **①はプラン依存で成立する**。会話 1 ターンの上限 5 分 = 300 秒に対し、**Hobby は既定=上限=300 秒で余裕がゼロ**(「5 分 + 余裕」の判定基準を満たせない)。**Pro で `maxDuration` を明示設定すれば 800 秒 (GA) まで伸ばせる**ため、**FE-D の採用案の成立条件は「Vercel Pro 以上」**になる。1800 秒はベータかつ関数単位の設定と特定ランタイムが前提なので当てにしない |
  > | **`maxDuration` は「including streamed responses」と明記**。超過は **504 `FUNCTION_INVOCATION_TIMEOUT`** | 同「Max duration」 | **④の「上限到達時の応答」は 504** と確定。§9 の「中継の実行時間上限に到達」の行に落ちる |
  > | **Edge ランタイムは「must begin sending a response within 25 seconds」+ ストリーム継続は最大 300 秒** | 同「Edge runtime」 | **§6.3 が Node.js ランタイム前提で設計したのは正しい** — Edge を選ぶと 300 秒で打ち切られ、Pro でも延長できない。**Edge を選択肢から外すことを設計判断として固定する** |
  > | **同時実行は「Auto-scales up to 30,000 (Hobby and Pro) or 100,000+ (Enterprise) concurrency」** | 同表の Concurrency 行 | **②は実質的に制約にならない**。§4.4.1 の `sse.active_connections` の想定値 (数十〜数百規模) は 3 桁以上の余裕がある。**同時 SSE 接続数の上限として設計に書くべきなのは Vercel 側ではなく BE / ALB 側**になる |
  > | **課金は「active CPU time and provisioned memory time」で、「Waiting for I/O (e.g. calling AI models, database queries) does not count towards active CPU time」** | 同「Cost and usage」 | **③の測り方が誤っていた** — 「1 接続あたりの Function 実行時間 = 接続時間」を CPU 時間として概算すると**大幅な過大見積もり**になる。SSE 中継はほぼ全区間が I/O 待ちなので **active CPU はごく僅か**で、費用の主項は**provisioned memory time (メモリ量 × 起動時間)**。概算式を「**割当メモリ (既定 2GB) × 同時接続数 × 平均ターン長**」に置き換える |
  >
  > **残る実測項目 (公式ドキュメントでは決まらないもの)**: ①の**実挙動の確認 1 回**
  > (`maxDuration = 800` を設定した Route Handler が実際に 5 分超のストリームを完走するか。
  > Preview と Production の両方) と、③の**実測に基づく月額**。**ユーザー判断が必要な点は
  > 「Vercel Pro 以上を前提にしてよいか」**(Hobby では余裕ゼロで設計が成立しない)。
  会話 1 ターンの上限は 5 分 ([observability.md](observability.md) §4.4)。
  **暫定既定**: Node.js ランタイムの Function で中継できる前提で §6.3 を設計した。
  **§15.1 の第 0 ステップとして、雛形展開より前に実測で確定させる**。

  **測ること (4 項目。①が本体、②〜④は O-3 / D-1 の入力)**:

  | # | 項目 | 測り方 | 判定 |
  |---|---|---|---|
  | ① | **5 分のストリームを中継できるか** | 空の Next.js プロジェクトに Route Handler を 1 本置き、10 分間 15 秒間隔で送出し続ける上流を中継して**どこで切れるか**を見る (Preview と Production の両方) | 5 分 + 余裕を持って切れなければ肯定 |
  | ② | **同時実行上限** | ~~同時接続数を増やし、新規接続が待たされる / 失敗する点を見る~~ → **測定不要 (上記の一次調査で解消)**。Vercel は Hobby / Pro で 30,000 同時実行まで自動スケールするため制約にならない | **同時 SSE 接続数の上限は BE / ALB 側で決める** (§4.4.1 の `sse.active_connections` はそちらのしきい値と比較する) |
  | ③ | **実行時間課金の概算** | ~~「1 接続あたりの Function 実行時間 = 接続時間」として概算~~ → **式を差し替え**: active CPU は I/O 待ちを含まないため、主項は **provisioned memory time = 割当メモリ (既定 2GB) × 同時接続数 × 平均ターン長**。①の実測時に Vercel の Usage 画面で両者の実額を読む | 想定運用で許容できるか |
  | ④ | **上限到達時の応答** | ②で失敗した接続がクライアントに何を返すか (ステータス / 切断の仕方) | §9 の「中継の同時実行上限 / 実行時間上限に到達」の行に落ちることを確認 |

  **①が不成立の場合の代替 = §2 FE-D の却下案 (d)。ただし成立未確認である**:

  - **骨子 (BE 側に新規に必要なもの。[auth.md](auth.md) / plan.md Task-3i への是正要求の中身になる)**:
    ①**発行 API 1 本** (対象リソースの種別と ID を受け、不透明な文字列と `expires_at` を返す)
    ②**有効期間は接続確立までの短時間** (60 秒程度。接続後のストリーム継続は期限に依存しない)
    ③**スコープは 1 リソース × 1 メソッドに限定** (`X-Token` の代替として使えないこと)
    ④**単回使用** (接続時に無効化。再接続は再発行)
    ⑤**渡し方はクエリ文字列** (`EventSource` はヘッダを付けられない) = **アクセスログに残る**ため
    ②③④が前提条件になる
  - **未解決の成立条件 (CORS)**: (d) は**ブラウザ → BE のクロスオリジン要求を復活させる**ため、
    **FE-D の却下 (a) が挙げた「Preview URL が変動して許可リストを維持できない」問題がそのまま再現する**。
    解き方の候補は ①**Preview のブランチ別固定ドメイン (branch alias) のみを許可し、
    デプロイごとの可変 URL を使わない** ([testing.md](testing.md):360 が E2E で
    「Preview URL を使わない・dev の固定 URL を使う」と既に決めているのと同じ方向)
    ②dev の BE だけ `*.vercel.app` を許可し prod は固定ドメインのみ (dev の緩和を明示的に受け入れる)。
    **どちらもユーザー決定を要する**
  - **したがって「不成立なら (d)」は成立が確認された代替ではない**。
    ①が不成立と判明した時点で、**(d) の CORS 方針をユーザーに確認してから設計を変更する**。
    **v2 方式 (7 日有効な JWT をブラウザに渡す) には戻さない**
  [Answer]: **実測で確定させる方針を承認** (2026-07-31 ユーザー回答)。2026-07-30 の一次調査 (上の表) で
  ②は測定不要・③は式差し替え・④は 504 と確定済みのため、**実装リポ立ち上げの第 0 ステップで残るのは
  ①の実挙動確認 1 回 (`maxDuration=800` で 5 分超ストリームの完走。Preview / Production) と ③の実額読み取り**。
  それまでは中継可能の前提で設計を維持し、不成立ならその時点で (d) の CORS 方針を再確認する。
  **派生問いも回答済み**: 「**Vercel Pro 以上を前提にする**」(2026-07-31 ユーザー回答。Hobby は上限 300 秒で
  余裕ゼロのため。`maxDuration` を明示設定して 800 秒まで確保する)

- ~~**FE-Q3: `swagger.json` を FE の CI が private リポジトリから取得する手段**~~ →
  **解消 (2026-08-03)**。**リポジトリ構成が app モノレポ + infra リポの 2 分割になり**
  ([architecture.md](architecture.md) §3.11)、`frontend/` と `api/openapi.yaml` が同一リポジトリに
  なったため**クロスリポジトリの取得が不要**になった。CI の `contract` ジョブ (モノレポ機構の MR-3) が
  `make -C backend docs` → **`scripts/check-regen.sh api/openapi.yaml`** → `npm run generate` →
  **`scripts/check-regen.sh frontend/src/generated`** を実行して同期を機械検証する
  (**裸の `git diff` は使わない** — 未追跡ファイルを見ないため**新規に生成された型の追加漏れ**が
  素通りする。2026-08-04 の design-reviewer 指摘 重大 1 / 2026-08-05 の D-5)。
  **同型の論点だった `E2E_DISPATCH_TOKEN` も同時に廃止された** ([testing.md](testing.md) §13.1 T-Q5 の [Answer 2]) —
  `operations.md` §4.1 の限定列挙は**例外ゼロ件**に戻っている。
  **以下は旧 3 リポ構成での検討 (記録として残す)**:
  **暫定既定**: BE の CI が成功時に `swagger.json` を artifact として公開し、
  FE の CI が **`gh` CLI + GitHub App のインストールトークン**で取得する。
  **影響範囲**: 不可なら「BE リポが FE リポへ PR を出して `swagger.json` をコミットする」方式に変わり、
  §5.1 の生成手順とマージ順序 ([operations.md](operations.md) §5.4) が変わる
  [Answer]: **暫定既定で確定 — BE の CI artifact を GitHub App のインストールトークンで取得**
  (2026-07-31 ユーザー回答)

- **FE-Q4: FE 起点のエラーをどこに送るか (未確定)**。
  §9 で `console.error` を禁止したが、**送信先を決めていない**。
  **暫定既定**: Server Action / Route Handler での失敗は**サーバ側の構造化ログに出す** (Vercel のログに残る)。
  **ブラウザ内で完結する失敗 (レンダリングエラー・パース失敗) は当面 `error.tsx` の表示のみ**とし、
  収集しない。**影響範囲**: O-7 (アラート) の対象に FE を含めるかが決まらない。
  **選択肢**: (a) 収集しない (b) BE に FE ログ受け口を作る (v2 に `src/lib/post-logs.ts` があるため前例あり
  — ただし用途は未調査) (c) Sentry 等の外部 SaaS を入れる (コストと契約が必要)
  [Answer]: **(a) 当面収集しない、で確定** (2026-07-31 ユーザー回答)。ブラウザ内で完結する失敗は
  `error.tsx` の表示のみ。O-7 のアラート対象に FE は含めない。必要が生じたら (c) を後付けで検討する

- **FE-Q5: ナビゲーションの階層** — プロトタイプは「アイデア発散」を独立したナビ項目にしている
  (`hassan_agent_prototype_v2.html:6635-6641`) が、本書は会話をテーマ配下に置いた (§11.1)。
  **暫定既定**: テーマ配下。**影響範囲**: ルート設計 (§11.1) と、テーマを選ばずに会話を始められるかの体験
  [Answer]: **テーマ配下で確定** (2026-07-31 ユーザー回答)。ルートは §11.1 の
  `/themes/[themeId]/conversations/[conversationId]` のまま。ナビに「アイデア発散」ショートカットを
  置く場合も遷移先はテーマ選択とする

- **FE-Q6: Tailwind のバージョン** — v2 は **3.4.1** (V-2)。**暫定既定**: v3 も Tailwind 3 系で始める
  (v2 の設定と `eslint-plugin-tailwindcss` の対応が確実)。**影響範囲**: Tailwind 4 の
  CSS-first なトークン定義を採る場合、§7.1 の「`theme.extend` を唯一の定義場所」が
  「`@theme` ブロック」に変わる (体系そのものは変わらない)
  [Answer]: **Tailwind 3 系で確定** (2026-07-31 ユーザー回答)

- **FE-Q7: 社内管理者経路の WAF による IP 制限をどうするか (新規 2026-07-30)**。
  [auth.md](auth.md) §6.2 は多層防御として「社内管理者系エンドポイントを WAF の IP 許可リストで
  社内からのみ到達可能にする」を決めているが、**FE-D (BE 呼び出しは全てサーバ側) では
  ALB が見る送信元 IP が Vercel の Function になり、この制限が成立しない** (§11.3.2)。
  **暫定既定**: ③(IP 制限を管理者経路について諦め、**MFA 必須 + レート制限 + 監査記録 +
  SuperAdmin の複数運用**で担保する)。**選択肢**: ①Vercel の固定 egress IP 機能を使う
  (**利用可否とプラン要件は未調査**) ②管理者 UI を Vercel ではなく BE の ALB 配下に配信する
  (FE-D' の却下 (b) に戻り、新規インフラが必要)。
  **影響範囲**: ①なら [infrastructure.md](infrastructure.md) の WAF ルールと Vercel のプラン、
  ②なら FE-D' の採用案と [operations.md](operations.md) §3.2 の環境対応表、
  ③なら [auth.md](auth.md) §6.2 の「IP 制限を併用する」という記述の是正 (§16.2-7)
  [Answer]:

- **FE-Q8: 管理者セッションの寿命 (新規 2026-07-30)**。
  一般ユーザーは 7 日 = BE の JWT 期限に一致させる ([auth.md](auth.md) §6.9-3。§5.2.3)。
  **管理者トークンの有効期間は [auth.md](auth.md) が明示していない** (§6.2 は MFA 必須化を決めたが
  期間には触れていない)。**暫定既定**: Task-3i が管理者トークンの有効期間を決めるまで
  **7 日を上限とし、FE 側の `maxAge` は BE の決定値に一致させる**。
  **影響範囲**: 短くすると解除作業中に切れる可能性があり、長くすると漏洩時の窓が広がる。
  **一般ユーザーと同じ 7 日にするかどうかを Task-3i で決める**
  [Answer]: **一般ユーザーと同じ 7 日** (2026-07-31 ユーザー回答)。FE の `maxAge` は BE の決定値に一致させる。
  Task-3i の管理者トークン仕様はこの値を既定とする (漏洩時の失効は手動ロック — [auth.md](auth.md) §6.9 — が担う)

### 16.2 他文書・雛形への是正要求 (本書では編集していない)

1. **FE の機械検査 7 種の実装状況と、D-2 の SSOT への登録** (**D-2 の宙吊りを防ぐための最重要項目**)

   **経緯**: 本書の初版は「lint zone は `npm run lint` に含まれる」と書いたが、
   **当時の雛形には eslint 設定ファイルが 1 件も存在せず、その記述は誤りだった**。
   2026-07-30 にメインセッションが
   [.eslintrc.json.tmpl](../../templates/app-monorepo/frontend/.eslintrc.json.tmpl) を新規作成し、
   [ci.yml](../../templates/app-monorepo/.github/workflows/ci.yml) に検査 4 本を追加した。
   **現状と残りを表で確定させる**:

   | # | 検査 | 雛形の実体 (2026-07-30) | 残作業 |
   |---|---|---|---|
   | 1 | 依存方向 zone (L-F1〜L-F6。§3.3) | `.eslintrc.json.tmpl:55〜` (L-F2 / L-F3 / L-F6) + 後続の overrides (L-F1 / L-F4 / L-F5) | **L-F4 の `@/features/*` パターンを実ドメイン名に展開する** (実装リポ。§15.1 の 1-b) |
   | 2 | トークン強制 (FE-3。§7.2) | 同 `:46`〜 (hex) / `:50`〜 (`style` 属性) / **`:30`〜 (`no-arbitrary-value` / `no-custom-classname`。2026-07-30 追加)** | **`eslint-plugin-tailwindcss` の依存追加**が実装リポで必要 (§15.1 の 1-b) |
   | 3 | 併置テストの存在 (FE-4 / FE-6。§8.2) | `ci.yml` の `frontend` ジョブの「検査 1 併置テストの存在」ステップ | — |
   | 4 | 公開パス許可リストの照合 (§11.2.3) | `ci.yml` の `frontend` ジョブの「検査 2 公開パスの許可リストとルートグループの一致」ステップ (許可リストの存在確認 + スクリプト呼び出し) | **照合スクリプト本体** (`scripts/check-public-paths.sh`) を実装リポで書く。**2 本の許可リストを区別したまま照合する** (§11.2.3) |
   | 5 | `NEXT_PUBLIC_` 許可リスト (§12) | `ci.yml` の `frontend` ジョブの「検査 3 NEXT_PUBLIC_ の許可リスト」ステップ | — |
   | 6 | `globals.css` 行数の可視化 (§7.2) | `ci.yml` の `frontend` ジョブの「検査 4 globals.css の行数」ステップ | — |
   | 7 | **`X-Admin-Token` の局所化** (§5.2.1) | **実装済み** (2026-07-30): 同 `:163`〜`:220` — eslint の `no-restricted-syntax` で `lib/api/admin-mutator.ts` 以外での使用を禁止 (`ci.yml` ではなく lint で担保) | 残作業なし |

   **[testing.md](testing.md) §9 / §10 への登録** — **①は 2026-07-30 に反映済み** (下記)。
   §13 の D-2 が「段とマージ条件の SSOT は [testing.md](testing.md) §9」と宣言している一方、
   起票時点では**同書 §10 の「必須テストの存在検査 5 種」が 5 件すべて backend で、FE の検査が 1 つも無かった**。
   登録しないと上表が「SSOT の外にある検査」になる。**要求の内容と状態**:
   ①§10 の一覧に **FE の併置テスト存在検査 (検査 3)** を加える → **反映済み**
   (同節は **#6** として登録し 6 種へ、2026-07-31 に **#7** が加わり現在 **7 種**)
   ②§9.1 の段の表に **FE の検査 1〜7 が PR 必須チェック (`gate` 経由) に含まれる**ことを明記する
   (§9.1 は「新しい必須チェックを増やさない」と書いているが、これは backend の CI ジョブについての
   記述であり、**`ci.yml` に既存の `frontend` ジョブがある**ので新ジョブは増えない)
   ③[testing.md](testing.md) §7 の **E-1 の「Vercel の FE と ECS の BE の間の CORS」という記述**は
   FE-D により**ブラウザ → BE のクロスオリジンが無くなる**ため陳腐化する
   (E2E で確認すべきは Cookie と MFA 遷移であって CORS ではない) → **FE-Q2 の実測後に是正する**

2. **[../../templates/app-monorepo/frontend/CLAUDE.md.tmpl](../../templates/app-monorepo/frontend/CLAUDE.md.tmpl)**:
   ①`:37` の「`fetch` には **AbortSignal** を渡し」が**ブラウザから直接 BE を叩く前提**に読める —
   §2 FE-D (サーバ経由) と整合する記述に直す (「BE 呼び出しは `features/*/api` / `lib/api` / `lib/sse` を通す」)
   ②`:46-51` のフィーチャーフラグ節が**「配布方法は未確定」のまま**だが、
   **[operations.md](operations.md) §7.2 (OP-I) は既に確定済み** —
   「実装は環境変数のみ (BE = `env/<env>.env`、**FE = Vercel の環境変数**)」「**フラグを API で配らない**」
   (専用エンドポイント案は同節の却下案 (a))。雛形の 2 択の提示は不要になったので、
   **OP-I を参照する記述に差し替える** (併せて `GET /api/features` の例示は 2026-07-30 に削除済み =
   本書初版の指摘②は解消済み)
   ③ディレクトリ規約 (§3.1) と依存規則 (§3.3)・`.eslintrc.json` へのリネーム手順への参照を追記する
3. **[API/README.md](API/README.md) と [plan.md](../../aidlc-docs/inception/productionization/plan.md)**
   — **SSE の契約が FE から見て未完成**:
   ①SSE エンドポイントの**イベント名と payload の一覧がどこにも無い**
   (D-API-12 が [observability.md](observability.md) へ委譲しているが、
   同書に `event:` 名の記述は 0 件 — 実測 `grep -c "event:" docs/design/observability.md` = 0)。
   **FE は `event:` 名で振り分ける (S-2 / S-8)** ため、**どちらかに一覧が必要**。
   該当は `GET /asset-extractions/{extraction_id}/stream` と
   `POST /knowledge-threads/{thread_id}/messages`
   ②**会話 (アイデア発散) API の設計 Task を plan.md に追加する** — §11.1 は会話画面を**増分 1** に
   置きながら「SSE イベント型が未定のため実装着手不可」としており、Task が無いと増分 1 のスコープが閉じない
   (FE-Q1 の「確認したいこと」に対応する。既存の Task-3i / Task-3b はいずれも会話 API を含まない)
4. **[operations.md](operations.md) §7.2 (OP-I) の FE 側**: フラグを **Vercel の環境変数**として置く
   ことは確定済みだが、**`NEXT_PUBLIC_` を付けないこと**(§12) と
   **導線の出し分けを Server Component で行うこと**が同節に書かれていない。
   FE 側の実装形態として 1 行の追記が必要 (付けるとフラグ構成がブラウザバンドルに載る)
5. **[operations.md](operations.md) §3.2 / [infrastructure.md](infrastructure.md) §5.3**:
   「Preview URL が変動する場合の CORS 許可の扱い」の確認事項に対し、本書 §12 が
   **FE 側からブラウザ直叩きを無くす**という回答を出した。**BE の CORS 許可リストを縮小できる**が、
   **この要求は FE-Q2 (①の実測) が肯定された後に出す** — 不成立時の代替 (FE-D の却下 (d)) は
   クロスオリジン要求を復活させるため、**先に縮小すると退避路を塞ぐ** (§12 の条件 1)。
   併せて [infrastructure.md](infrastructure.md) §3.3 の **S3 の CORS** は
   **FE がブラウザから presigned URL を直接開く前提で必要**である旨を確定させる (§12 の末尾)
6. ~~**Task-3i (認証・アカウント基盤 API) への 3 件**~~ → **全件解決済み (2026-07-31)**。
   Task-3i の成果物 [API/auth-accounts.md](API/auth-accounts.md) が 3 件すべてに回答した:
   ①`POST /accounts/signin` の応答 (`SignInResult`) に **`auth_role` を含む** (同書 §2.5) →
   §5.2.2 の暫定挙動を解除済み ②**社内管理者の機能の入出力仕様**は同書 §2.4 (管理者 8 本) →
   §11.1 の管理者 5 画面の根拠列を `[API]` へ更新済み ③**管理者トークンの有効期間 = 7 日**
   (FE-Q8 の回答どおり。同書 §2.4) → §11.3.1 を「7 日で確定」に更新済み。
   **本項は履歴として残す** (受け手が「まだ未対応」と誤読しないよう状態を明示する)
7. **[auth.md](auth.md) §6.2 / [infrastructure.md](infrastructure.md) INF-L**:
   「社内管理者系エンドポイントを WAF の IP 許可リストで社内からのみ到達可能にする」は
   **FE-D と両立しない** (ALB が見る送信元 IP が Vercel の Function になる。§11.3.2)。
   **「MFA を主たる防御とし IP 制限を併用する」という記述を、FE-Q7 の結論に合わせて是正する**
8. **[plan.md](../../aidlc-docs/inception/productionization/plan.md)**: Task-3l の完了マーク
   (**本レビュー反映後**。`aidlc-docs/reviews/productionization/review-frontend.md` の指摘 16 件に対応済み)

### 16.3 本書の仮定 (違えば §2 の判断が変わる)

1. **FE から BE への呼び出しは全てサーバ側 (Next.js のサーバ) を経由できる**と仮定した
   (FE-D)。**Vercel の Function 実行時間・同時実行数・帯域が SSE 中継に耐えない**場合、
   FE-D の採用案が崩れ FE-Q2 の代替に切り替わる
2. **BE の JSON キーは snake_case で確定している** ([API/README.md](API/README.md) D-API-4) と仮定した。
   camelCase に変わるなら §5.3 の ViewModel 条件は不要になる
3. **SSE イベント型が OpenAPI の discriminated union で提供される**と仮定した
   ([design_memo.md](design_memo.md):149)。提供されないなら §6.2 の S-8 が成立せず、
   **FE に手書きの型が必要になる = V-10 のドリフトを設計として受け入れることになる**
4. **会話画面は 1 画面 1 会話**と仮定した (複数会話のタブ並行表示は想定していない)。
   並行表示が要件なら §4.2 の②(画面ローカル reducer) が③(zustand) に移る
5. **プロトタイプの配色・余白は「入力」であり、値の変更は許される**と仮定した (DR-7)。
   ピクセル単位の一致が要件なら §7.1 の意味ベース命名の粒度を増やす必要がある
6. **社内管理者 UI は本 FE リポ・同一 Next.js アプリの対象**と仮定した (FE-D')。
   別アプリに切り出す決定 (却下 (b)) が出るなら §11.3 と §15.1 の成果物がそちらへ移り、
   [operations.md](operations.md) §3.2 の Vercel スコープ表に 1 プロジェクト増える
7. **同一 Next.js アプリに next-auth を 2 系統マウントでき、Cookie 名を系統ごとに分けられる**と仮定した
   (§11.3.1)。**この可否はライブラリのバージョンに依存し、本リポジトリでは未検証**である。
   不可なら ①管理者側だけ自前のセッション Cookie 実装にする ②FE-D' の却下 (b) (別アプリ) に切り替える
   のいずれかになる。**「1 つの next-auth に provider を並べる」(v2 の V-19) には戻さない** —
   それは V-7 (両ヘッダに同一値) の原因そのものである
