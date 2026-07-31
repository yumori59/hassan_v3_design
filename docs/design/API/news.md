# API: お知らせ

> 共通規約 (認証・レスポンス形・エラー・ページネーション・ステータスコード) の SSOT: [README.md](README.md)
> 本ファイルが回答する本番観点: **A-4, A-5, D-5 (部分)** / 受入基準: **AC-1.1, AC-1.4**

## 1. 対応する画面と参照する既存実装

| 区分 | 所在 |
|---|---|
| プロトタイプ | `news` ビュー — `../../prototype/hassan_agent_prototype_v2.html` の HTML `:7590-7627` / JS `:13700-13848` (2026-07-30 更新版の実測) |
| プロトタイプのモックデータ | `NEWS_ITEMS` (`:13700`、5 件。うち未読 3 件)。ナビバッジは未読数から算出 (`updateNewsBadge` `:13825-13831`)、「すべて既読にする」は `:13842-13847` |
| v2 の既存実装 (BE) | `hassan-v2-backend/controller/news.go` (2 本のみ) / `hassan-v2-backend/usecase/news/` / `hassan-v2-backend/microcms/` (`client.go` / `microcms.go`) / `hassan-v2-backend/controller/webhook.go` |
| v2 の既存実装 (FE) | `hassan-v2-frontend/src/features/news/actions/get-news-list.ts` / `get-news.ts` / `hassan-v2-frontend/src/lib/micro-cms-client.ts` / `microcms-server-client.ts` |
| v2 の既存テーブル | `read_news_accounts` (`hassan-v2-backend/db/schema.sql:555-561`。`news_id TEXT` + `account_id` の複合主キー) / `news_email_logs` (`同:563`) |

### 1.1 v2 の構成 (事実)

**お知らせの本文は v2 の DB に無い。MicroCMS (外部 CMS) が持っている。**

| 責務 | 担い手 | 出典 |
|---|---|---|
| 本文・タイトル・公開日の管理 (入稿) | **MicroCMS** | `hassan-v2-backend/microcms/microcms.go`、`hassan-v2-frontend/src/features/news/type.ts` の `News` 型 (`id` / `title` / `content` / `importance[]` / `publishedAt` / `image[]`) |
| 一覧・詳細の取得 | **FE (Next.js の server action) が MicroCMS SDK を直接呼ぶ** | `hassan-v2-frontend/src/features/news/actions/get-news-list.ts` (`'use server'` + `microCmsClient.getList`、`orders: '-publishedAt'`、`limit: 10`)、`get-news.ts` (`getListDetail` + Draft Mode) |
| 既読状態 | **v2 backend** (`read_news_accounts`) | `GET /news` = 未読有無 (`hassan-v2-backend/controller/news.go:35`)、`POST /news` = 既読登録 (`同:59`) |
| 新着通知メール | v2 backend が Webhook で受信 | `POST /webhook/microcms/news` (`hassan-v2-backend/router/router.go:192`)。**HMAC 署名検証** (`X-MICROCMS-Signature` — `hassan-v2-backend/controller/webhook.go:31-39`)。送信記録は `news_email_logs` |

**v2 の `GET /news` は本文を返さない**。返すのは `dto.UnreadNewsResponse{has_unread}` だけ
(`hassan-v2-backend/controller/news.go:35-46`)。つまり **v2 では「本文は CMS から / 既読は API から」を
FE が結合している**。

### 1.2 プロトタイプとの差分

| プロトタイプの概念 | v2 | 判定 |
|---|---|---|
| 一覧 (タイトル・日時・要約・未読フラグ) | 本文は MicroCMS、未読は `GET /news` の真偽値のみ | **未読フラグの粒度が違う** (v2 は「未読があるか」だけで、どれが未読かを返さない) |
| カテゴリ (`cat`: release / maintenance / incident。ラベル辞書に info も定義) | MicroCMS の `importance[]` (FE は `importance[contains]` でフィルタ — `get-news-list.ts`) | **値域の対応が未確認** (§4 NW-Q1) |
| フィルタタブ (すべて / 未読 / 新機能 / メンテナンス / 障害) | FE が MicroCMS のフィルタを使う。**未読タブは v2 に相当機能が無い** | 新規 |
| 詳細表示 (同一ビュー内トグル) + 既読化 | `POST /news` (**どの記事を読んだかを指定しない**) | **設計変更が必要** (§3 D-NW-3) |
| すべて既読にする | **無い** | 新規 |
| ナビバッジ (未読件数) | `has_unread` (真偽値のみ) | **件数が必要** (§3 D-NW-4) |
| アプリ内の作成・編集 UI | 無い (入稿は MicroCMS の管理画面) | 対象外 |

---

## 2. エンドポイント一覧

すべて認証必須 (`X-Token`)・**すべて個人スコープ** (既読状態がアカウント単位)・すべて増分 1。
共通の 400 / 401 / 500 は [README.md](README.md) §2.5 に従い、本表では**固有のコードのみ**挙げる。

| メソッド | パス | 概要 | 主なリクエスト / レスポンス項目 (暫定) | 固有ステータス |
|---|---|---|---|---|
| GET | `/news` | 一覧 (既読状態を結合) | Q: `category` (`release`\|`maintenance`\|`incident`\|`info`) / `unread_only` (bool) / `limit` / `offset` — R: `{items:[{id, category, title, summary, published_at, unread}], total_count}` | 200 / **502** (CMS 障害) |
| GET | `/news/{news_id}` | 詳細 (**既読化しない**) | R: `{id, category, title, summary, body, published_at, unread}` | 200 / 404 / **502** (CMS 障害) |
| POST | `/news/{news_id}/read` | 既読化 | — R: `{unread_count}` | 200 / 404 |
| POST | `/news/read-all` | すべて既読化 | — R: `{unread_count: 0, marked_count}` | 200 / **502** (CMS 障害) |
| GET | `/news/unread-count` | 未読件数 | R: `{unread_count}` | 200 / **502** (CMS 障害) |

`body` は CMS が返す HTML (`hassan-v2-frontend/src/features/news/type.ts` の `content`) をそのまま渡す。
**LLM 出力ではなく運用者が入稿した内容**なので、[knowledge.md](knowledge.md) D-KN-6 (HTML を返さない) とは
判断が異なる — その差分の理由は §3 D-NW-5。

---

## 3. 設計判断

| # | 論点 | 採用案 | 却下案と理由 |
|---|---|---|---|
| D-NW-1 | **本文の管理場所** | **MicroCMS に残す** (v2 踏襲)。v3 は本文を DB に持たない | (a) v3 の DB に本文を持ち CMS を廃止: **非エンジニアの運用者が使う入稿 UI を新規実装**することになり、Draft Mode (`hassan-v2-frontend/src/features/news/actions/get-news.ts` が `draftMode()` を使う) や画像管理まで作り直しになる。スコープが本番化の目的から外れる。(b) 本文を v3 DB に同期コピーする: CMS を正としたまま複製を持つと、更新反映のタイムラグと不整合の調査コストが増える |
| D-NW-2 | **取得経路** | **v3 backend が CMS を呼び、既読状態と結合して返す集約プロキシにする** | (a) v2 方式 (FE が MicroCMS SDK を直接呼ぶ — `hassan-v2-frontend/src/features/news/actions/get-news-list.ts`): ① **未読フラグを行ごとに出せない** (既読情報は v3 の DB にあり、CMS のページングと突き合わせる必要がある)。② `unread_only` フィルタと未読件数の集計が FE では成立しない (CMS から全件取ってこないと数えられない)。③ CMS の API キーが `NEXT_PUBLIC_MICRO_CMS_API_KEY` として渡されており (`hassan-v2-frontend/src/lib/microcms-server-client.ts`)、`NEXT_PUBLIC_` 接頭辞はクライアントバンドルに載り得る名前空間である。**サーバに寄せればキーがブラウザに出る経路をそもそも作らない** (D-5) |
| D-NW-3 | **既読化の契機** | **明示的な `POST /news/{news_id}/read`** | (a) `GET /news/{news_id}` で既読化 (プロトタイプは行クリックで詳細表示 + 既読化 — `:13801-13808`): **GET が副作用を持つ**ため、ブラウザのプリフェッチ・リトライ・共有リンクのクロールで意図せず既読になる。FE は詳細を開いたときに 2 本呼べばよい。(b) v2 方式 (`POST /news` に記事 ID なし — `hassan-v2-backend/controller/news.go:59`): **どの記事を読んだかを記録できない**ため、行ごとの未読表示 (プロトタイプの必須要素) が実装できない |
| D-NW-4 | **未読件数** | **件数を返す** (`{unread_count}`) | (a) v2 の `has_unread` (真偽値 — `hassan-v2-backend/controller/news.go:35-46`) を踏襲: プロトタイプのナビバッジは**件数を表示する** (`:13825-13831`)。真偽値では実装できない。**v2 の既存テーブル `read_news_accounts` はそのまま使える** (既読レコードの差分を数えるだけ) ので、テーブル変更を伴わない拡張 |
| D-NW-5 | **本文の形式** | **CMS が返す HTML をそのまま返す** | (a) Markdown に変換して返す: CMS のリッチエディタ出力 (画像・表) を損失なく変換できない。(b) [knowledge.md](knowledge.md) D-KN-6 と同じく HTML を禁止する: あちらは **LLM 出力**であり信頼できないが、こちらは**運用者が入稿した内容**で、v2 でも既に HTML として描画されている。**信頼境界が違うため判断を分ける** (FE 側でサニタイズする前提は明記する) |
| D-NW-6 | **Webhook の受け口** | **第 1 増分では v2 に残す** (v3 は受けない) | (a) v3 に移す: 新着メール送信は `news_email_logs` (v2 の DB) と結びついており、v3 に移すと**メールの二重送信**のリスクが出る (v2 と v3 の両方が Webhook を受ける期間が生じる)。**ただし全面切替 (C-11) で v2 が退役する時点で v3 へ移設が必要** — 切替手順に含める (§4 NW-Q3) |
| D-NW-7 | **CMS 障害時の応答** | **502** を返す (500 と区別する) | (a) 500 を返す: v3 の障害と外部 CMS の障害が区別できず、アラートの切り分けができない (O-4)。(b) 空一覧を 200 で返す: 「お知らせが 0 件」と「取得できなかった」が同じ見え方になり、障害が気付かれない |
| D-NW-8 | **配信対象の絞り込み** | **全ユーザー共通** (契約単位・個人単位の配信をしない) | (a) 契約単位の配信を作る: v2 の `read_news_accounts` / MicroCMS のどちらにも配信対象の概念が無く (`hassan-v2-frontend/src/features/news/type.ts` の `News` 型に対象フィールドが無い)、要件も未確認。**必要になった時点で CMS 側のフィールド追加とセットで設計する** |

### 3.1 既読状態の持ち方 (v2 の既存データとの共存 — DR-3)

**v2 の `read_news_accounts` をそのまま引き継ぐ**ことを推奨する。

| 項目 | 内容 |
|---|---|
| 構造 | `news_id TEXT` (CMS のコンテンツ ID) + `account_id UUID` の複合主キー (`hassan-v2-backend/db/schema.sql:555-561`) |
| 既存データ | v2 の本番 DB に既読レコードがある。**移行しないと全ユーザーの既読が未読に戻る** (ナビバッジが一斉に点く) |
| 未読の算出 | 「CMS の公開済み記事集合」−「そのアカウントの既読レコード」。**CMS 側の件数取得が必要**なため、未読件数はキャッシュを検討する (§4 NW-Q2) |
| `news_id` の型 | `TEXT` のまま (CMS の ID 体系に依存するため、v3 で採番しない) |

**移行の含意**: Q-1 (データモデル統合方針) が「v3 用新テーブル」になる場合、
`read_news_accounts` は **v3 側にコピーして移行する**か **v2 のテーブルを共有する**かの判断が要る。
本ファイルは**コピー移行**を前提にした (v3 backend が別デプロイ単位で v2 の DB を直接読まない方針 —
[settings.md](settings.md) §5 の横断判断と同じ理由)。

---

## 4. 本番観点への回答と要確認

| ID | 回答 | 備考 |
|---|---|---|
| A-1 | [README.md](README.md) §2.1。全 5 本が認証必須 | AC-1.1。**v2 でも `/news` は認証必須** (`hassan-v2-backend/router/router.go:226-227`) |
| A-2 | `AuthRoleUser` のみ。**入稿は MicroCMS の管理画面で行うため、管理者ロールの API は不要** | — |
| A-3 | 既読テーブルは `account_id` を持つ (v2 の既存構造。§3.1) | — |
| A-4 | 既読の読み書きは常に `WHERE account_id = <認証ユーザー>`。**`news_id` は CMS 側の ID であり所有者概念を持たない**ため、他テナントのデータに到達する経路が構造上存在しない | — |
| A-5 | 本表の「固有ステータス」列 + [README.md](README.md) §2.5。**404 は「CMS に存在しない `news_id`」のみ** | **AC-1.4** |
| A-6 | LLM 経路は無い | — |
| A-7 | 共有の概念なし (全ユーザー共通配信 — D-NW-8) | — |
| O-4 | CMS 障害を 502 で識別 (D-NW-7) | — |
| O-6 | 既読化は監査対象外とする (ユーザーの閲覧行動であり、v2 でも記録していない) | 判断の記録として明示 |
| D-5 | CMS の API キーは **backend のシークレット**として扱う (D-NW-2)。FE の環境変数に置かない | シークレット管理は operations 設計 |

### 要確認

| # | 項目 | 状態 | 確定先 |
|---|---|---|---|
| NW-Q1 | **カテゴリの値域対応** | プロトタイプは `release` / `maintenance` / `incident` (+ ラベル辞書に `info`)。v2 の MicroCMS は `importance[]` という**配列**フィールドで、値域が未確認 (`hassan-v2-frontend/src/features/news/actions/get-news-list.ts` が `importance[contains]` でフィルタ) | MicroCMS のコンテンツ定義の確認 (ユーザー側)。**配列 → 単一カテゴリへの写像が必要かもしれない** |
| NW-Q2 | **未読件数のキャッシュ** | 毎回 CMS の全件数を取るとナビ表示のたびに外部 API を叩く | 実装設計。CMS の記事 ID 一覧を短期キャッシュする案が有力 |
| NW-Q3 | **Webhook の移設時期** | 第 1 増分は v2 が受信 (D-NW-6)。全面切替時に v3 へ移す必要がある | [operations.md](../operations.md) の切替手順 |
| NW-Q4 | **既読データの移行** | v2 本番 DB の `read_news_accounts` を v3 へコピーする前提 (§3.1) | `docs/design/data-model.md` (Q-1 回答後) |
| NW-Q5 | **新着通知メールの継続** | `news_email_logs` による送信記録が v2 にある。v3 で継続するか | 要件確認 (D-NW-6 と連動) |
