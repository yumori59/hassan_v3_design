# API: アイデアボード + アイデア参照

> 共通規約 (認証・レスポンス形・エラー・ページネーション・ステータスコード) の SSOT: [README.md](README.md)
> 本ファイルが回答する本番観点: **A-2, A-3 (部分), A-4, A-5, A-7, O-6, D-7 (移行)** / 受入基準: **AC-1.1, AC-1.4**

## 1. 対応する画面と参照する既存実装

| 区分 | 所在 |
|---|---|
| プロトタイプ | `board` ビュー — `../../prototype/hassan_agent_prototype_v2.html` の HTML `:7361-7397` / JS `:11928-12972` (2026-07-30 更新版の実測) |
| プロトタイプのモックデータ | `BOARDS` (`:11928`、4 件) / `PHASE_OPTIONS` (`:12003`) / `boardViewState` (`:12011`) / 新規ボードウィザード `renderNewBoardWizard` (`:12705-12972`) / ボード作成用のテーマ選択肢 `PAST_THEMES` (`:12630`) |
| v2 の既存実装 | `hassan-v2-backend/controller/idea_board.go`、`hassan-v2-backend/usecase/idea_board/`、`hassan-v2-backend/db/queries/idea_board.sql` |
| v2 の既存テーブル | `idea_boards` (`hassan-v2-backend/db/schema.sql:599-613`) / `idea_board_phases` (`同:615-625`) / `ideas` (`同:151-178`) |
| v2 の既存ルート | `hassan-v2-backend/router/router.go:130-141` (11 本) |

### 1.0 v2 のデータモデル (**v3 と最も大きく違う 3 点。ここを読まずに実装すると既存データを壊す**)

| # | v2 の事実 | 出典 |
|---|---|---|
| **V-1** | **ボードの中身を保持するテーブルが存在しない**。ボード関連の `CREATE TABLE` は `idea_boards` と `idea_board_phases` の **2 つだけ** | `hassan-v2-backend/db/schema.sql` の `CREATE TABLE` 全走査 (599 と 615 のみ) |
| | **ボードの中身は `idea_boards.filter` (jsonb) を毎回評価して算出される**。`ListIdeasForBoard` のクエリに `board_id` は**一切現れず**、`contract_id` + filter 条件 (creator / theme / star / phase / asset_usage / created_from-to) で `ideas` を絞る | `hassan-v2-backend/db/schema.sql:606` (`filter jsonb`)、`hassan-v2-backend/db/queries/idea_board.sql:80-140`、呼び出し側は `hassan-v2-backend/usecase/idea_board/list_idea_boards.go:47` が `b.Filter` を渡す |
| | filter は旧単数キーからの後方互換 `UnmarshalJSON` を持つ**現役の機能** (`creator_account_id` → `creator_account_ids` 等) | `hassan-v2-backend/entity/idea_board.go:29-77` |
| **V-2** | **メモ・フェーズは `ideas` テーブルのカラム** (`ideas.memo text` / `ideas.phase text`) であり、**アイデア単位のグローバル値**。ボード単位ではない | `hassan-v2-backend/db/schema.sql:173-174`、`hassan-v2-backend/db/queries/idea_board.sql:64-67` (`UPDATE ideas SET memo = $2, phase = $3 WHERE id = $1`)、呼び出しは `hassan-v2-backend/usecase/idea_board/update_board_idea.go:58` |
| | `ideas.phase` は**フェーズの「名前」を持つ text** (FK ではない)。契約内の一括リネーム用クエリがある | `hassan-v2-backend/db/queries/idea_board.sql:49-56` (`RenameIdeasPhaseLabelForContract`) |
| **V-3** | **ボード内ロールは 3 段** (`admin` / `editor` / `viewer`)。保持カラムは `viewer_account_ids uuid[]` / `editor_account_ids uuid[]` の 2 本で、**作成者が admin** | `hassan-v2-backend/entity/idea_board.go:14-16` (定数)、`同:95-110` (`Role()`)、`hassan-v2-backend/db/schema.sql:604-605` |
| | 権限判定は 3 つ: `HasAccess` (何らかのロール) / `CanEdit` (admin か editor) / `IsAdmin` | `hassan-v2-backend/entity/idea_board.go:113-115`, `:118-121`, `:124-126` |

**V-1〜V-3 の含意**: v3 は「明示的なアイテム集合 (board-item 実体)」を採るため
(§3 D-IB-0)、**移行で filter を評価してアイテム行を作らないと、切替後に既存ボードが全て空になる**。
また V-2 のとおり memo/phase はアイデア単位なので、**item 単位に移すと意味が変わる**。
V-3 のロールを平坦化すると **viewer が編集できるようになる (サイレントな権限昇格)**。
移行手順は §4 にまとめた。

### 1.1 v2 の既存エンドポイントとの対応 (**このドメインは v2 に既存機能がある**)

| v2 のエンドポイント | 出典 | v3 での扱い |
|---|---|---|
| `POST /idea-boards` | `hassan-v2-backend/router/router.go:131` | 踏襲 |
| `GET /idea-boards` | `同:132` | 踏襲 |
| `PUT /idea-boards/:id` (名前更新) | `同:133` | 踏襲 (名前 + 説明に拡張) |
| `DELETE /idea-boards/:id` | `同:134` | 踏襲 |
| `GET /idea-boards/:id/ideas` | `同:135` | **`/items` に改名** (§3 D-IB-2)。**中身の決定方式が filter → 実体アイテムに変わる** (D-IB-0) |
| `PUT /idea-boards/:id/ideas/:idea_id` (メモ・フェーズ更新) | `同:136` | **`/items/{item_id}` に改名** (§3 D-IB-2)。**更新先が `ideas` → board-item に変わる** (V-2 / D-IB-0) |
| `PUT /idea-boards/:id/filter` | `同:137` | **採らない** — ただし**廃止ではなく置き換え**。filter はボード定義そのもの (V-1) なので、切替時に評価して実体化する (§4)。以後の「ボードの中身の変更」は `POST` / `DELETE /items` が担う (§6 IB-Q1) |
| `GET /idea-boards/:id/members` | `同:138` | 踏襲 (**`role` を返す形も踏襲** — D-IB-8) |
| `PUT /idea-boards/:id/members` | `同:141` | 踏襲 (**`{members:[{account_id, role}]}` の形も踏襲** — D-IB-8) |
| `POST /idea-boards/phases` | `同:139` | **`/idea-board-phases` に改名** (§3 D-IB-4)。**同名 upsert → 409 に変更** (D-IB-4') |
| `PUT /idea-boards/phases/:phase_id` | `同:140` | 同上 |
| (無い) | — | **コメント 3 本を新設** (§3 D-IB-5) |
| (無い) | — | **`GET /idea-boards/{board_id}`** (単体取得) を新設。v2 は一覧のみで単体取得が無い |
| (無い) | — | **`POST` / `DELETE /idea-boards/{board_id}/items`** を新設。v2 はアイテムの追加・削除という概念自体が無い (中身は filter が決める — V-1) |
| (無い) | — | **`DELETE /idea-board-phases/{phase_id}`** を新設 |

**事実**: v2 の `idea_boards` は `contract_id` と `create_account_id` の両方を持ち
(`hassan-v2-backend/db/schema.sql:599-613`)、**3 段ロール付きの契約内共有を既に実装している** (V-3、
[../auth.md](../auth.md) §2.2)。`idea_board_phases` も `contract_id` を持つ (`同:615-625`)。

### 1.2 プロトタイプで増えた概念

| プロトタイプの概念 | v2 | 判定 |
|---|---|---|
| ボードの説明 (`desc`) | 名前のみ (`PUT /idea-boards/:id` は名前更新) | 新規 |
| フェーズの色 (`phases[].color`) | **`idea_board_phases.color_code text NOT NULL DEFAULT '#0455C5'` が実在**する (`hassan-v2-backend/db/schema.sql:619`) | **あり** (名前が `color_code`。API 側の項目名との対応は D-IB-4') |
| フェーズの並び順 | **無い**。v2 は `ORDER BY name ASC` で返す (`hassan-v2-backend/db/queries/idea_board.sql:32-36`) | **新規** (`order` は v3 の新設カラム — D-IB-4') |
| ボードごとのフェーズ集合 (`BOARDS[].phases`) | フェーズは**契約単位のマスタ**。v2 は全ボードに同じ集合を渡す (`hassan-v2-backend/usecase/idea_board/list_idea_boards.go:38`, `:52` — N+1 回避のためループ外で 1 回取得) | 契約マスタ + 件数集計で再現 (D-IB-4) |
| メモ (`items[].memo` 相当) | **`ideas.memo`** = アイデア単位のグローバル値 (V-2) | **スコープが変わる** (item 単位へ。§4) |
| フェーズ別の件数 (`phases[].n`) | 無い (集計) | 新規 (派生値) |
| **コメントスレッド** (`items[].thread[]`: `author` / `authorId` / `at` / `text`) | **無い** | **新規** |
| 共有メンバー (`members[]`) | `GET/PUT /idea-boards/:id/members`。**v2 は 3 段ロール付き** (V-3) | あり (**プロトタイプはロールの区別を持たない** — §6 IB-Q4) |
| スター (`items[].stars`) | `PUT /ideas/:id/star` (`hassan-v2-backend/router/router.go:128`) | あり |
| 評価 (`items[].verdict`: `"B+・4.1"`) | `ideas` の評価情報 | あり (形式差 — §3 D-IB-3) |
| ステージ (`items[].stage`: 発散 / 企画作成) | アイデアの進行状況 | あり (派生値) |
| テーマ名 (`items[].theme`) | `ideas` → `idea_hassans` → `themes` | あり (**参照 vs スナップショット** — §3 D-IB-1) |

### 1.3 プロトタイプ更新 (2026-07-30) で観測された差分

| 事実 (更新版プロトタイプ) | 本ファイルへの影響 |
|---|---|
| ボード詳細が**表レイアウト**になり、各行に**企画書由来のフィールド** (事業コンセプト / 想定顧客 / 課題 / 解決方法) をインライン展開表示する (`renderBoardDetail` `:12227`〜、詳細展開 `:12295-12337`、データ取得 `_ideaDetails` 経由 `:12132-12225`) | `BoardItem` (§2.1) にこれらのフィールドは無い。**企画書ドメインは [README.md](README.md) §0 の対象外**のため本ファイルでは追加しない — 会話型アイデア創出 / 企画書 API の設計時に「ボードが企画書サマリを表示する」要件として引き継ぐ (IB-Q11) |
| ボード一覧ヘッダに**横断 KPI 統計** (作成中ボード 内訳自分/共有・登録中アイデア合計・参加メンバー・合計コメント数 — HTML `:7373-7391` / `:12067-12071`) | `GET /idea-boards` は `{items, total_count}` のみで横断集計を返さない (IB-Q12) |
| ボード詳細に**テーマ絞り込み select と並び順 select** (「追加が新しい順 / 評価が高い順 / コメント数順」— `pm-toolbar` `:12255-12265`)。**ただし配線なしのダミー** (イベントリスナー無し) | `GET /items` の `sort` 値域 (`stars`\|`created_at`\|`phase`) に `comment_count` は無く、テーマ絞り込みクエリも未定義 (IB-Q13) |
| 自己評価スターは**同値クリックで 0 にトグル**する (`renderStarRater` `:12121-12129`) | `PUT /ideas/{idea_id}/star` が `stars: 0` を受けるので API 変更は不要 (FE 実装の挙動メモ) |
| フェーズ変更ポップオーバーに**「未設定にする」ボタン** (`openPhasePopover` `:12461-12510`) | `PUT /items/{item_id}` の `phase_id` に null を許す形で表現可能 (API 変更は不要。null 許容を実装時に落とさないこと) |
| ヘッダの**「ボード削除」ボタンは配線なし** (`:12251`) | `DELETE /idea-boards/{board_id}` は定義済み。ダミーである事実のみ記録 |

---

## 2. エンドポイント一覧

すべて認証必須 (`X-Token`)・すべて増分 1。
共通の 400 / 401 / 500 は [README.md](README.md) §2.5 に従い、本表では**固有のコードのみ**挙げる。

| メソッド | パス | 概要 | スコープ | 主なリクエスト / レスポンス項目 (暫定) | 固有ステータス |
|---|---|---|---|---|---|
| GET | `/idea-boards` | ボード一覧 (+ 横断 KPI) | 契約 | Q: `keyword` / `limit` / `offset` / `sort` (`updated_at` 既定) — R: `{items:[Board], total_count, stats:{board_count, my_board_count, shared_board_count, item_count, member_count, comment_count}}` (**IB-Q12=b: 一覧に同梱**。`stats` は `keyword` / ページングに**依存しない**「自分が見える全ボード」の集計 — [themes.md](themes.md) D-TH-2 の却下 (b) と異なりボードにはタブ切替との循環が無く、一覧画面 1 画面でしか使わないため同梱が成立する) | 200 |
| POST | `/idea-boards` | ボード作成 | 契約 | B: `name` (必須) / `description` / `member_account_ids[]` / `theme_ids[]` / `idea_ids[]` — R: `Board` | **201** / **400** (契約外のアカウント ID / 他人のアイデア ID) |
| GET | `/idea-boards/{board_id}` | ボード取得 | 契約 | R: `Board` (+ `phase_counts[]` / `item_count` / `comment_count`) | 200 / 404 |
| PUT | `/idea-boards/{board_id}` | 名前・説明の更新 | 契約 | B: `name` / `description` — R: `Board` | 200 / 404 / **403** (board admin 以外) |
| DELETE | `/idea-boards/{board_id}` | ボード削除 | 契約 | — | **204** / 404 / **403** (board admin 以外) |
| GET | `/idea-boards/{board_id}/items` | アイテム一覧 | 契約 | Q: `phase_id` / **`theme_id`** / `limit` / `offset` / `sort` (`stars`\|`created_at`\|`phase`\|**`comment_count`**) — R: `{items:[BoardItem], total_count}` (**`theme_id` と `comment_count` ソートは IB-Q13=a で追加**) | 200 / 404 |
| POST | `/idea-boards/{board_id}/items` | アイデア追加 | 契約 | B: `{idea_ids:[...], phase_id (任意)}` — R: `{items:[BoardItem]}` | **201** / 404 / **403** (viewer — §3.1) / **409** (既に同じアイデアが載っている) |
| PUT | `/idea-boards/{board_id}/items/{item_id}` | フェーズ・メモ更新 | 契約 | B: `phase_id` / `memo` — R: `BoardItem` | 200 / 404 / **403** (viewer — §3.1) |
| DELETE | `/idea-boards/{board_id}/items/{item_id}` | アイテム削除 | 契約 | — (**コメントも削除される** — §3 D-IB-6) | **204** / 404 / **403** (viewer — §3.1) |
| GET | `/idea-boards/{board_id}/items/{item_id}/comments` | コメント一覧 | 契約 | Q: `limit` / `offset` (**古い順**) — R: `{items:[Comment], total_count}` | 200 / 404 |
| POST | `/idea-boards/{board_id}/items/{item_id}/comments` | コメント投稿 | 契約 | B: `body` (必須) — R: `Comment` | **201** / 404 / **403** (viewer — §3.1) |
| DELETE | `/idea-boards/{board_id}/items/{item_id}/comments/{comment_id}` | コメント削除 | 契約 | — | **204** / 404 / **403** (投稿者でも board admin でもない) |
| GET | `/idea-boards/{board_id}/members` | 共有メンバー一覧 | 契約 | R: `{items:[{account_id, name, email, icon_url, role}]}`。**`role` は `admin`\|`editor`\|`viewer`\|`""` (非メンバー)** — v2 と同形 (`hassan-v2-backend/controller/dto/idea_board.go:75-81`) | 200 / 404 |
| PUT | `/idea-boards/{board_id}/members` | 共有メンバー置換 | 契約 | B: **`{members:[{account_id, role}]}`** (`role` は `editor`\|`viewer` のみ。**`admin` は指定不可 = 作成者固定**)。自契約のアカウントのみ — R: `{items:[Member]}` | 200 / 404 / **403** (board admin 以外) / **400** (契約外のアカウント ID / `role` が列挙外 / 作成者を指定 / 同一アカウントの重複) |
| GET | `/idea-board-phases` | フェーズマスタ一覧 | 契約 | R: `{items:[{id, name, color_code, order}]}` (**`color_code` は v2 と同名** — D-IB-4') | 200 |
| POST | `/idea-board-phases` | フェーズ作成 | 契約 | B: `name` (必須) / `color_code` / `order` — R: `Phase` | **201** / **409** (同一契約内の `name` 重複 — v2 に `UNIQUE(contract_id, name)` が実在。D-IB-4') |
| PUT | `/idea-board-phases/{phase_id}` | フェーズ更新 | 契約 | B: `name` / `color_code` / `order` — R: `Phase` | 200 / 404 / **409** (改名先の `name` が既存と重複) |
| DELETE | `/idea-board-phases/{phase_id}` | フェーズ削除 | 契約 | Q: `on_conflict` (`reject` 既定 \| `unassign`) | **204** / 404 / **409** (使用中のフェーズで `reject`) |

Q = クエリパラメータ / B = リクエストボディ / R = レスポンス。

> **`GET /ideas` / `GET /ideas/{idea_id}` / `PUT /ideas/{idea_id}/star` / `GET /ideas/csv` の 4 本は
> [ideas.md](ideas.md) へ移設した** (2026-08-02。§7 / [ideas.md](ideas.md) §1.2)。
> `ideas` テーブルの API SSOT は本ファイルではなく [ideas.md](ideas.md) 1 箇所になった。

### 2.1 `BoardItem` オブジェクト (暫定)

```json
{
  "id": "bi-01J9Z8QP0000000000000000",
  "idea": {
    "id": 101,
    "num": 7,
    "title": "半導体製造装置の配管詰まり 予兆検知IoT",
    "tag": "半導体検査",
    "stars": 4,
    "stage": { "code": "plan", "label": "企画作成" },
    "evaluation": { "grade": "B+", "score": 4.1 },
    "theme": { "id": 12, "name": "超音波センシング 新規事業探索 v2" },
    "deleted": false
  },
  "phase": { "id": 3, "name": "投資判断", "color_code": "#10a04d" },
  "memo": "来週の戦略会議で優先案として提示予定",
  "comment_count": 3,
  "created_at": "2026-07-16T00:22:00Z"
}
```

**`idea` はスナップショットではなく結合結果** (§3 D-IB-1)。`evaluation.grade` と `score` は
プロトタイプの `"B+・4.1"` という**表示用の連結文字列を分解した形**で返す (§3 D-IB-3)。
**IB-Q11=a (2026-07-30)**: ボード詳細の表表示のため、`idea` に**企画書サマリ
(事業コンセプト / 想定顧客 / 課題 / 解決方法 相当) をサーバ結合で含める**方針を採る。
**具体的なフィールド名と形は企画書ドメインの API 設計時に確定**し、本 JSON 例へ追記する
(D-IB-1 と同じ「参照が正・表示用はサーバ結合」の原則に従う。FE に文字列スナップショットを持たせない)。

**`evaluation.grade` の値域は A / B+ / B / C の 4 段**である
(2026-08-23 の proto-v4 増分で A/B/C/D から変更。AC-PV-2.3)。
値域そのものの定義元は `entity/idea` のバンド関数 ([ideas.md](ideas.md) §6.3 が SSOT) —
本書では値域を再定義しない。

### 2.2 単体取得の可視性判定 → [ideas.md](ideas.md) へ移設済み (2026-08-02)

`GET /ideas/{idea_id}` の可視性判定 (所有者 / ボードメンバーシップ / `visibility=contract` の 3 条件)
は [ideas.md](ideas.md) §1.4 へ移設した。**ボードメンバーシップによる可視性条件は同節の②**であり、
`GET /idea-boards/{board_id}/items` のメンバーシップ判定と揃っている必要がある点は変わらない
([ideas.md](ideas.md) §8 の **R-IDA-1**)。

### 2.4 CSV エクスポートの応答仕様 → [ideas.md](ideas.md) へ移設済み (2026-08-02)

`GET /ideas/csv` の応答仕様 (Content-Type・BOM・改行・列の写像・v2 との差分) は
[ideas.md](ideas.md) §2.6 へ移設した ([ideas.md](ideas.md) §8 の **R-IDA-1**)。

---

## 3. 設計判断

| # | 論点 | 採用案 | 却下案と理由 |
|---|---|---|---|
| **D-IB-0** | **ボードの中身の決定方式** (filter 評価 か 実体アイテム か) | **実体アイテム (`idea_board_items` テーブル)** を採る。ボードに載っているアイデアは行として存在し、`POST` / `DELETE /items` で増減する | (a) **v2 の filter 方式を継続する** (V-1。`idea_boards.filter` jsonb を評価して毎回算出): **プロトタイプが要求する per-item のコメントスレッドとフェーズ・メモに実体が必要**。filter 方式では「どのアイデアにどのコメントが付いたか」を保持する先が無く、条件に合致しなくなったアイデアのコメントが行き場を失う。またフェーズを per-item で持てないため、フェーズ変更が filter の条件と循環する (フェーズで絞ったボードでフェーズを変えると、そのアイテムがボードから消える)。(b) filter + 実体アイテムの併存 (動的 + 手動追加): 「なぜこのアイデアが載っているのか」が 2 系統になり、削除の意味 (filter から除外 か item 削除 か) が決まらない。**却下の代償**: v2 の filter が持つ「条件に合う新アイデアが自動で載る」性質を失う (§6 IB-Q1 で要確認として明示) |
| D-IB-1 | **アイデアの参照 vs スナップショット** | **参照 (`idea_id`) を正**とし、表示用フィールド (テーマ名・アイデア名・評価・ステージ) は**サーバが結合して返す** | (a) プロトタイプ方式 (文字列を転記して保存 — `BOARDS[].items[].theme` / `ideaTitle` / `verdict` が `:11936-11957` で文字列リテラル): **アイデアをブラッシュアップして評価が変わってもボードが古い値を表示し続ける** (BE-1 / BE-4 の再発形)。プロトタイプの `PAST_THEMES` (`:12630`) が `TM_THEMES` と別系統のモックである点も、スナップショット設計が整合を失う実例。(b) 参照 + スナップショットの両持ち: 「どちらを表示するか」の判断が UI ごとに散り、`verdict` の不一致がユーザーから見て不可解になる |
| D-IB-2 | パス命名 (`ideas` → `items`) | **`/idea-boards/{board_id}/items`** に改名 | (a) v2 の `/idea-boards/:id/ideas/:idea_id` 踏襲 (`hassan-v2-backend/router/router.go:135-136`): 同じ URL が「アイデア」と「ボード上のアイデア (フェーズ・メモ・コメントを持つ別エンティティ)」の 2 概念を指す。**v2 ではこの `PUT` が実際に `ideas` テーブルを更新している** (`UPDATE ideas SET memo = $2, phase = $3 WHERE id = $1` — `hassan-v2-backend/db/queries/idea_board.sql:64-67`、呼び出しは `hassan-v2-backend/usecase/idea_board/update_board_idea.go:58`)。つまり **URL はボード配下なのに、更新結果は同じアイデアを載せた全ボードに波及する** — この曖昧さを v3 では item 単位に変え、URL の形でも表明する。**改名と更新先の変更はどちらも v2 からの意図的な逸脱**であり、移行が必要 (§4) |
| D-IB-3 | 評価の返し方 | **`{grade, score}` に分解**して返す (**キー名は `rank` ではなく `grade`** — [ideas.md](ideas.md) §2.1 の `evaluation.grade` に統一。[ideas.md](ideas.md) §8 の **R-IDA-1** で改名)。**`grade` の値域は A/B+/B/C の 4 段** (2026-08-23 の proto-v4 増分で A/B/C/D から変更。定義元は [ideas.md](ideas.md) §6.3 のバンド関数 — 本書では再定義しない。AC-PV-2.3) | (a) プロトタイプの `"B+・4.1"` をそのまま返す: FE で文字列を分解する処理が必要になり、**「120-420億円」を「-420億円」と誤抽出した FE-6 と同種のパーサ**を書かせることになる。数値化はサーバ側で 1 度だけ行う |
| D-IB-4 | フェーズの所有単位 | **契約単位のマスタ** (`/idea-board-phases`) + ボードアイテムが参照 (v2 踏襲) | (a) ボードごとのフェーズ定義 (プロトタイプは `BOARDS[].phases` としてボード内に持つ — `:11932`): **v2 の `idea_board_phases` は `contract_id` を持つ既存テーブル** (`hassan-v2-backend/db/schema.sql:615-625`) であり、本番 DB に既存データがある。v2 も全ボードに同じ集合を渡している (`hassan-v2-backend/usecase/idea_board/list_idea_boards.go:38`, `:52`)。ボード単位に変えると移行が必要になる (DR-3)。プロトタイプの「ボードごとのフェーズ」表示は、契約マスタの部分集合 + 件数集計で再現できる |
| D-IB-4' | フェーズのカラムと一意性 | **`color_code` は v2 と同名を使う** (`text NOT NULL DEFAULT '#0455C5'` — `hassan-v2-backend/db/schema.sql:619`)。**`order` は v3 の新設カラム** (v2 に相当カラムは無く `ORDER BY name ASC` で返している — `hassan-v2-backend/db/queries/idea_board.sql:32-36`)。**同名フェーズの作成・改名は 409** | (a) API 側の項目名を `color` にする: DB カラム名と API 項目名が無意味に食い違い、DTO で毎回変換が必要になる。(b) **v2 の upsert 挙動を踏襲する** (`UpsertIdeaBoardPhase` は `ON CONFLICT (contract_id, name) DO UPDATE SET color_code = ...` — `hassan-v2-backend/db/queries/idea_board.sql:38-42`): **「作成したつもりが既存フェーズの色を書き換えていた」が起きる**。`POST` が既存リソースを黙って更新するのは D-API-11 (作成は 201) と矛盾する。色を変えたいなら `PUT /idea-board-phases/{phase_id}` を使う明示的な経路に寄せる。**この 409 化は v2 からの逸脱** (§3.2)。(c) `order` を作らない: プロトタイプのフェーズは選定プロセスの段階 (要検討 → 深掘り中 → 投資判断) を表し、名前のアルファベット順では意味が壊れる |
| D-IB-5 | コメント | **アイテムに紐づく新テーブル + 3 エンドポイント**。**編集は提供せず、削除のみ** (投稿者本人または board admin。それ以外は 403 — §3.1) | (a) 編集も提供する: プロトタイプに編集 UI が無く (`items[].thread` は表示と投稿のみ)、議論の記録が後から書き換わることの是非が未確認。(b) v2 の `business_plan_chats` を流用: あちらは LLM チャットの履歴であり、人間同士のコメントとは検索・通知の要件が異なる |
| D-IB-6 | アイテム削除とコメント | **アイテムを削除するとコメントも削除される** | (a) コメントを残す: 親が無いコメントを表示する画面が無く、参照できないデータが増える。**ただしボードからアイデアを外す操作は「議論の破棄」を意味する**ため、UI 側で確認を要求する前提を明記する |
| D-IB-7 | 削除されたアイデアの扱い | アイデアは**論理削除**とし、ボードアイテムは参照を保つ。`idea.deleted: true` を返し、FE は「削除済み」と表示する | (a) 物理削除 + アイテムのカスケード削除: **コメント (議論) が連鎖して消える**。ボードは合意形成の記録であり、元アイデアの削除で議論が消えるのは情報損失。(b) アイテムを残して `idea` を null にする: FE が null チェックを全表示箇所で行うことになる |
| D-IB-8 | ボードの権限 | **v2 の 3 段ロール (`admin` / `editor` / `viewer`) をそのまま引き継ぐ**。権限表は §3.1、既存データの移行は §4 の M-4。`admin` = 作成者 (固定)、`editor` / `viewer` は `PUT /members` で付与 | (a) **ロールを平坦化して「共有メンバー全員が編集可」にする** (**当初案・却下**): v2 は `CanEdit` = admin か editor でメモ・フェーズ編集を制限しており (`hassan-v2-backend/entity/idea_board.go:118-121`、`hassan-v2-backend/usecase/idea_board/update_board_idea.go:47`)、**v2 で read-only だった viewer が切替後にフェーズ移動・メモ編集・アイテム追加削除を行えるようになる**。既存本番データに対する**サイレントな権限昇格**であり DR-3 違反。(b) すべて admin のみ: 共有ボードでフェーズを動かせず、プロトタイプの共同レビュー用途 (`BOARDS[].shared`) が成立しない。(c) v3 で独自の 2 段ロールを定義する: v2 の `viewer_account_ids` / `editor_account_ids` から写す先が曖昧になり、どちらに寄せても既存ユーザーの権限が変わる |
| D-IB-9 | フェーズ削除時の使用中アイテム | **既定は 409 で拒否**。明示指定で未割当に戻す (`unassign`) | (a) 使用中でも削除してアイテムのフェーズを null にする: フェーズは選定プロセスの状態であり、消えると「どこまで進んでいたか」が失われる |
| D-IB-10 | アイデアの重複追加 | **同一ボードに同じアイデアは 1 つまで** (409) | (a) 重複を許す: プロトタイプに重複表示の想定が無く、フェーズ別件数の集計が二重になる |
| D-IB-11 | ボード一覧のスコープ | **契約スコープ固定** (`scope` パラメータを持たない)。**自分が作成したボード + 自分が editor/viewer のボード**を返す。**これは v2 の挙動と一致する** (`hassan-v2-backend/usecase/idea_board/list_idea_boards.go:28` が `ListIdeaBoardsByContractID` = `WHERE contract_id = $1` (`hassan-v2-backend/db/queries/idea_board.sql:9-12`) で取得したのち、`同:44` の `if b.HasAccess(input.AccountID)` で絞る) | (a) `scope=mine\|contract` を持つ: 「契約内の全ボード」を返すと**メンバーでないボードまで見えてしまう**。ボードの可視性はメンバーシップで決まる。(b) `sharing_settings` でゲートする ([README.md](README.md) F-16): v2 はボード一覧で**共有された viewer/editor には `sharing_settings` をバイパスさせている** (`hassan-v2-backend/usecase/idea_board/list_idea_boards.go:44-47`)。ここに契約カテゴリのスイッチを持ち込むと、招待されたボードが見えなくなる回帰になる |

### 3.1 ボード内ロールと権限表 (D-IB-8 / 403 の SSOT)

**ロールの決まり方** (v2 と同一): 作成者 = `admin` / `editor_account_ids` に居れば `editor` /
`viewer_account_ids` に居れば `viewer` / それ以外は非メンバー
(`hassan-v2-backend/entity/idea_board.go:95-110`)。

| 操作 | admin | editor | viewer | 非メンバー | v2 の対応する判定 |
|---|---|---|---|---|---|
| ボード一覧・取得 (`GET /idea-boards`, `GET /idea-boards/{board_id}`) | ✓ | ✓ | ✓ | **404** | `HasAccess` (`hassan-v2-backend/entity/idea_board.go:113-115`) |
| アイテム一覧・コメント一覧・メンバー一覧 | ✓ | ✓ | ✓ | **404** | 同上 |
| **メモ・フェーズ更新** (`PUT /items/{item_id}`) | ✓ | ✓ | **403** | **404** | `CanEdit` (`同:118-121`)。v2 も `IdeaBoardForbidden` = 403 を返す — **v2 と同じ判断** |
| **アイテム追加・削除** (`POST` / `DELETE /items`) | ✓ | ✓ | **403** | **404** | v2 に該当操作が無い (V-1)。**`CanEdit` に揃える** |
| **コメント投稿** (`POST /comments`) | ✓ | ✓ | **403** | **404** | v2 に該当操作が無い。**`CanEdit` に揃える** (下記の採用理由) |
| **コメント削除** (`DELETE /comments/{comment_id}`) | ✓ (他人のコメントも可) | 自分のコメントのみ (他人は **403**) | **403** | **404** | v2 に該当操作が無い |
| **ボード更新・削除・メンバー変更** (`PUT`/`DELETE /idea-boards/{board_id}`, `PUT /members`) | ✓ | **403** | **403** | **404** | `IsAdmin` (`同:124-126`、`hassan-v2-backend/usecase/idea_board/manage_board_members.go:46`) |
| フェーズマスタの作成・更新・削除 (`/idea-board-phases`) | 契約内の全メンバーが可 | 同左 | 同左 | — | v2 も契約単位で誰でも可 (`hassan-v2-backend/router/router.go:139-140` にロール判定なし) |

**404 と 403 の使い分け** ([README.md](README.md) §2.5 の判定境界をそのまま適用):

- **メンバー (viewer 含む) の権限不足はすべて 403** — viewer はボード・アイテム・コメントを
  **GET で取得できる** (見えている)。見えているリソースへの書き込みに 404 を返しても
  存在の秘匿にならず (直前の GET で存在を知っている)、「取得できたものが更新では存在しない」
  という矛盾したクライアント挙動を生むだけ。v2 も同じ状況で `IdeaBoardForbidden` = 403 を返す
  (`hassan-v2-backend/usecase/idea_board/update_board_idea.go:47-48`)
- **非メンバーは 404** — ボード自体が見えない (D-IB-11: 可視性はメンバーシップで決まる) ため、
  存在を漏らさない
- **却下 (当初案): viewer の編集操作を 404 にする** — 「漏らさない方に寄せる」つもりの選択だが、
  上記のとおり viewer には既に見えており秘匿効果が無い。README §2.5 の判定境界・
  [../auth.md](../auth.md) §6.6・v2 の実装のすべてと矛盾する 3 重の逸脱になる

**コメント投稿を viewer に許すか** (レビューで判断を委ねられた点):

- **採用: `CanEdit` (admin / editor) のみに許す**
- **却下 (a) viewer にも許す**: 「閲覧専用」として招待された相手がボード上の議論に書き込めるのは、
  v2 で `viewer` を選んだ管理者の意図 (read-only) と食い違う。**招待時の選択の意味が変わる**のは
  D-IB-8 が避けている「サイレントな権限変更」と同種
- **却下 (b) コメントだけ別のロール軸を作る** (`can_comment`): v2 の 2 カラム
  (`viewer_account_ids` / `editor_account_ids`) から写せず、移行時に既定値の決定が必要になる
- **代償と先送り**: 「読むだけだがコメントはしたい」という要件が出た場合、
  `viewer` に投稿を許すか第 4 のロールを足すかの判断が必要 (§6 IB-Q8)

### 3.2 v2 規約からの逸脱 (移行時に読み替えが必要なもの)

| # | 逸脱 | v2 | v3 | 移行時の影響 |
|---|---|---|---|---|
| 1 | パス | `/idea-boards/:id/ideas` `/idea-boards/phases` | `/idea-boards/{board_id}/items` `/idea-board-phases` | FE の呼び出し箇所の書き換え。**全面切替 (C-11) 前提のため並走期間は無い** |
| 2 | **ボードの中身の決定方式** | `idea_boards.filter` (jsonb) の評価結果 (V-1) | `idea_board_items` の実体行 (D-IB-0) | **§4 M-1 の materialize が必須**。やらないと全ボードが空になる |
| 3 | **memo / phase のスコープ** | `ideas.memo` / `ideas.phase` = **アイデア単位のグローバル値** (V-2) | **board-item 単位** | **§4 M-2**。同じアイデアが複数ボードに載っている場合、どのボードへ写すかの決定が必要 |
| 4 | **phase の表現** | `ideas.phase text` = フェーズ**名** (V-2) | `idea_board_items.phase_id` = `idea_board_phases.id` への FK | **§4 M-3** の名前照合による写像 |
| 5 | **同名フェーズの作成** | upsert (色を上書き) | **409** (D-IB-4') | FE がフェーズ作成時に重複エラーを扱う必要がある |

> 権限違反のステータスコードは**逸脱ではない** — viewer の編集操作は v2 の
> `IdeaBoardForbidden` (403) と同じ判断 (§3.1)。

---

## 4. 移行手順 (v2 → v3。**この節を実施しないと既存ボードが機能しない**)

**本節が回答する観点: DR-3 (既存データの共存・移行・ロールバック) / D-7 (段階リリース)**

前提: 全面切替 (C-11) であり並走期間が無い。**切替時に 1 度だけ実行するデータ移行**として設計する。
実行順序は M-1 → M-2 → M-3 → M-4 (M-3 は M-2 の結果に依存)。

### M-1. `idea_boards.filter` を評価して `idea_board_items` を実体化する

| 項目 | 内容 |
|---|---|
| 入力 | `idea_boards` の全行 (`id` / `contract_id` / `filter` jsonb) |
| 処理 | 各ボードについて **v2 の `ListIdeasForBoard` と同じ条件** (`hassan-v2-backend/db/queries/idea_board.sql:80-140`) で `ideas` を評価し、ヒットしたアイデアを `idea_board_items` に 1 行ずつ INSERT する |
| 注意 | `filter` は**旧単数キー形式が残っている可能性がある** (`creator_account_id` / `theme_id` / `phase` / 廃止済み `asset_type`)。v2 の `UnmarshalJSON` (`hassan-v2-backend/entity/idea_board.go:44-77`) と**同じ後方互換ロジックを移行スクリプトにも実装する**。片方だけ対応すると古いボードの中身が変わる |
| `filter` が NULL / 空の場合 | 契約内の全アイデアが対象になる (v2 のクエリは条件が全て `NOT @use_*` で無効化されるため)。**件数が大きくなり得るので、移行前に契約ごとの件数を計測する** (§6 IB-Q9) |
| 冪等性 | `UNIQUE(board_id, idea_id)` (D-IB-10) により再実行で重複しない。**中断しても再実行できる**設計にする |
| 検証 | 移行前後で「各ボードの `ListIdeasForBoard` 件数」と「`idea_board_items` の件数」が一致することを全ボードで照合する |

### M-2. `ideas.memo` を item へ写す

| 項目 | 内容 |
|---|---|
| 入力 | `ideas.memo` (アイデア単位。V-2) |
| 処理 | そのアイデアを含む**すべての `idea_board_items` に同じ値をコピーする** |
| 採用理由 | v2 では同じアイデアがどのボードから見えても同じ memo が表示されていた。**全 item に複製すれば切替直後の表示が変わらない** |
| 却下案 | (a) 最初に作られたボードだけに写す: 他のボードで memo が消えたように見える。(b) どこにも写さず破棄する: ユーザーが書いた内容の消失 |
| 代償 | 切替後は item 単位に分岐するため、**同じアイデアの memo をボード A で編集してもボード B に反映されない**。この挙動変更は**リリースノートで告知する**必要がある (§6 IB-Q10) |

### M-3. `ideas.phase` (text) を `phase_id` へ写像する

| 項目 | 内容 |
|---|---|
| 入力 | `ideas.phase` (フェーズ名の text) と `idea_board_phases` (`contract_id`, `name`) |
| 処理 | **アイデアの所属契約内で `name` が一致する `idea_board_phases.id` を引き当てて `phase_id` に入れる** |
| 一致が保証される根拠 | `uq_idea_board_phases_contract_id_name` (`hassan-v2-backend/db/schema.sql:624`) により契約内で名前が一意。さらに v2 は `RenameIdeasPhaseLabelForContract` (`hassan-v2-backend/db/queries/idea_board.sql:49-56`) でフェーズ改名時に `ideas.phase` を**一括リネームして整合を保っている**ため、名前照合が成立する |
| 一致しない場合 | (a) `ideas.phase` が空文字 / NULL → `phase_id = NULL` (未割当)。(b) マスタに無い名前が残っている (リネーム漏れ) → **`phase_id = NULL` にし、移行ログに契約 ID・アイデア ID・元の名前を出力する**。黙って捨てない (BE-10 と同じ「握り潰さない」観点) |
| 検証 | 写像できなかった件数を 0 件になるまで確認する。0 でない場合は該当フェーズ名をマスタに追加してから再実行 |

### M-4. ボード内ロールを移行する (**サイレントな権限昇格を起こさない**)

| 項目 | 内容 |
|---|---|
| 入力 | `idea_boards.create_account_id` / `viewer_account_ids uuid[]` / `editor_account_ids uuid[]` (`hassan-v2-backend/db/schema.sql:603-605`) |
| 処理 | **そのまま 1:1 で写す**。`create_account_id` → `admin` / `editor_account_ids` → `editor` / `viewer_account_ids` → `viewer` |
| 禁止事項 | **viewer を editor に昇格させない**。「共有メンバー全員が編集可」という平坦化は行わない (D-IB-8 の却下案 a) |
| 検証 | 移行前後で「(ボード, アカウント) → ロール」の組が完全一致することを照合する。**件数一致では不十分** (viewer と editor の入れ替わりを検出できない) |

### ロールバック

| 対象 | 方法 |
|---|---|
| M-1 / M-2 / M-3 | **v2 のテーブルを読み取り専用で残す**。v3 側の `idea_board_items` を DROP すれば v2 の状態に戻る (v2 側のデータは変更しないため) |
| 切替後に v3 で行われた変更 | v2 へは戻せない (`idea_board_items` に相当する構造が v2 に無い)。**切り戻し期限を設ける**必要がある — 期限と判断基準は [operations.md](../operations.md) が担う |

**重要**: M-1〜M-4 は**すべて v2 のデータを読み取るだけで書き換えない**。
これによりロールバックが「v3 側を捨てる」だけで成立する。

---

## 5. 本番観点への回答

| ID | 回答 | 備考 |
|---|---|---|
| A-1 | [README.md](README.md) §2.1。**全 18 本**が認証必須 (2026-08-02。`/ideas` 系 4 本の [ideas.md](ideas.md) への移設後の実測 — 移設前は旧版で「21 本」と自称していたが、その時点の表の実測は 22 本で既に不一致だった。移設に伴う機械照合は `scripts/check-endpoint-mapping.sh` の検査④) | AC-1.1 |
| A-2 | 認証ロールは `AuthRoleUser` のみ。その上で **ボード内ロール (`admin` / `editor` / `viewer`) がリソース単位の権限を決める** ([README.md](README.md) §2.2 の R-2)。権限表は §3.1 | v2 の 3 段ロールを引き継ぐ (D-IB-8) |
| A-3 | `idea_boards` / `idea_board_phases` は `contract_id` + 作成者列 (v2 の既存構造を踏襲)。新設する `idea_board_items` / `idea_board_comments` にも **`contract_id` と作成者列**を持たせる ([../auth.md](../auth.md) §6.3 の 2 番) | data-model で確定 |
| A-3' | **`ideas` テーブルは v2 の構造が [../auth.md](../auth.md) §6.3 の方針を満たしていない**。事実: ① 所有者列 (`account_id` / `contract_id`) を持たず `idea_hassan_id` → `idea_hassans.account_id` の **2 段チェーン**で所有者に到達する (`hassan-v2-backend/db/schema.sql:151-178`。[../auth.md](../auth.md) §2.3 の集計と一致) ② **`is_deleted` カラムが無い** (同スキーマ)。したがって v3 では **`ideas` への所有者列 1 段化と論理削除列の追加が新規作業**として必要 (D-IB-7 が論理削除を前提にしている) | **data-model 設計への申し送り** (Q-1 待ち。本ファイルでは確定できない) |
| A-4 | 全エンドポイントで Repository のクエリ条件に `contract_id`。`board_id` / `item_id` / `comment_id` / `phase_id` / `idea_id` は**すべて契約と組で検証**する (他契約の ID は 404) | §2 |
| A-5 | 本表の「固有ステータス」列 + **§3.1 の権限表** + [README.md](README.md) §2.5。**403 は 8 本** — admin 限定 3 本 (`PUT`/`DELETE /idea-boards/{board_id}` / `PUT /members`)、投稿者限定 1 本 (`DELETE /comments/{comment_id}`)、viewer の編集操作 4 本 (`POST`/`PUT`/`DELETE .../items` 系 + `POST .../comments`)。v2 の `IdeaBoardForbidden` (403) と同じ判断 (§3.1)。非メンバーは一律 404 | **AC-1.4** |
| A-6 | 本ファイルに LLM 経路は無い。アイデアの参照・生成・評価は [ideas.md](ideas.md) / [conversation.md](conversation.md) が担う (§7 の移設後) | — |
| A-7 | **回答**: ボードは v2 の契約内共有 (`idea_boards.contract_id` + `viewer_account_ids` / `editor_account_ids`) と **3 段ロールをそのまま引き継ぐ** (D-IB-8 / §3.1 / §4 M-4)。可視性はメンバーシップで決まる (D-IB-11)。**[../auth.md](../auth.md) §7 の「本増分では共有機能を持たない」と食い違う** — 既存データがある機能に対しては A-7 を「対象外」にできない ([README.md](README.md) §5 API-Q3) | 要ユーザー確認 |
| O-6 | ボードの作成・削除、アイテムの追加・削除、コメントの投稿・削除、**メンバー・ロールの変更**は監査対象。契約内の他メンバーに影響する操作であり、v2 の `activity_logs` 相当に記録する。**v2 も `PUT /members` の成功・失敗を活動ログに記録している** (`hassan-v2-backend/usecase/idea_board/manage_board_members.go:80-95` の `recordIdeaBoardActionFailed` / `recordIdeaBoardActionSuccess`) | 記録項目は [../observability.md](../observability.md) §4.5 |
| DR-3 (既存データ) | **§4 の移行手順 M-1〜M-4 が回答**。v2 のデータは読み取るだけで書き換えないため、ロールバックは v3 側を捨てるだけで成立する | 切り戻し期限は operations 設計 |

---

## 6. 要確認 (プロトタイプに UI のみ / 判断待ち)

| # | 項目 | プロトタイプ / v2 の状態 | 確定先 |
|---|---|---|---|
| **IB-Q1** | **動的フィルタボード → 静的アイテムボードへの転換を受け入れるか** (**要確認の最重要項目**)。v2 の `filter` は「保存フィルタ機能」ではなく**ボード定義そのもの** (V-1)。§4 M-1 で切替時点の評価結果を凍結するため、**切替後は条件に合致する新しいアイデアが自動でボードに載らなくなる** (以後は `POST /items` の手動追加のみ)。プロトタイプのフィルタ select は配線なしのダミーであり、UI からは判断できない | **ユーザー判断** ([README.md](README.md) §5 API-Q6)。受け入れられない場合は D-IB-0 の却下案 (b) (filter + 実体アイテムの併存) に戻す必要があり、**コメント・フェーズの帰属設計が変わる** |
| IB-Q2 | **アイデア追加 UI** | ボード詳細ヘッダの「アイデア追加」ボタンは**配線なし** (選択元がテーマかアイデア一覧か未定義) | 要件確認。本ファイルは `POST /idea-boards/{board_id}/items` を `idea_ids[]` で定義済み |
| IB-Q3 | ~~v2 のボード可視性の実際~~ → **確認済み (要確認から除外)** | v2 は `ListIdeaBoardsByContractID` (`WHERE contract_id = $1` — `hassan-v2-backend/db/queries/idea_board.sql:9-12`) で取得後に `if b.HasAccess(input.AccountID)` で絞っており (`hassan-v2-backend/usecase/idea_board/list_idea_boards.go:28`, `:44`)、**メンバー限定**。D-IB-11 の採用案と一致するため、**切替でボードが見えなくなる懸念は発生しない** | 解決済み |
| IB-Q4 | **共有メンバー編集 UI のロール選択** | ボード詳細ヘッダの共有メンバー編集ボタンは**配線なし**で、プロトタイプの `BOARDS[].members` は**ロールの区別を持たない** (アカウント ID の配列のみ — `:11934`)。一方 v2 の API は `role` (viewer\|editor) を要求する (`hassan-v2-backend/usecase/idea_board/manage_board_members.go:52-53`) | **UI 要件の確認**。API は v2 を踏襲して `role` を必須にした (D-IB-8) ため、**FE にロール選択 UI が必要**。[themes.md](themes.md) TH-Q5 (テーマメンバーの権限差) と揃えるかも同時に判断する |
| IB-Q5 | **フェーズの色の値域** | ~~色カラムの有無~~ → **確認済み**: `color_code text NOT NULL DEFAULT '#0455C5'` が実在 (`hassan-v2-backend/db/schema.sql:619`)。**残る未確定は値域の検証**のみ — プロトタイプは任意の 16 進色 (`PHASE_OPTIONS` — `:12003`)、v2 は text で検証なし | 実装設計 (`#RRGGBB` 形式のバリデーションを入れるかを決める。入れる場合 400 が増える) |
| IB-Q6 | **アイデア参照 API のスコープ** | プロトタイプのボード作成ウィザードは「過去のテーマから統合アイデアを選ぶ」(`:12705-12972`)。**他メンバーのアイデアを選べるのか**が未定義 | 要件確認。暫定で `scope=mine` を既定とした (他人のアイデアを既定で見せない) |
| IB-Q7 | **アイテムのステージ表示** | **クローズ (2026-08-01)**。[conversation.md](conversation.md) §2.3 が「**会話の `stage` を他ドメインへ配らない**」と決めたため、`items[].stage` は**会話セッションの stage を引かず、アイデア自身の事実から導出する** — 「企画書 (`plans`) が 1 件以上あれば企画作成、無ければ発散」。**会話セッションを持たないアイデア (手動登録・v2 移行分) でも成立する**のが採用理由 (会話の stage を引くと `conversation_session_id` が NULL の行でステージが決まらない) | **クローズ済み** (導出規則は本表のとおり。stage の値域そのものは [conversation.md](conversation.md) §2.3 が SSOT) |
| IB-Q8 | **コメント投稿を viewer に許すか** | §3.1 で `CanEdit` (admin / editor) のみに限定した。プロトタイプにロールの概念が無いため要件から判断できない | 要件確認。許す場合は「閲覧のみ」の招待の意味が変わる (§3.1 の却下案 a) |
| IB-Q9 | **`filter` が空のボードの件数** | §4 M-1 で `filter` が NULL / 空のボードは**契約内の全アイデアが対象**になる (v2 のクエリは条件が全て無効化される)。契約ごとの件数が未計測 | **移行前にユーザー側で件数を計測**する (plan.md の Task-2f と同じ性質の作業)。件数が大きい契約では M-1 の実行時間と `idea_board_items` の行数見積もりが必要 |
| IB-Q10 | **memo のスコープ変更の告知** | §4 M-2 の代償として、切替後は同じアイデアの memo がボードごとに独立する (v2 はグローバル) | リリースノート / ユーザー告知の要否 (`docs/design/operations.md` の切替手順) |

### 6.1 プロトタイプ更新 (2026-07-30) による再確認事項 (§1.3 の差分に対応)

- **IB-Q11: ボード詳細に企画書サマリ列 (事業コンセプト / 想定顧客 / 課題 / 解決方法) を表示するか**。
  事実: 更新版のボード詳細は表レイアウトで、これらを行内に展開表示する (§1.3 の 1 行目)。
  選択肢: (a) `BoardItem.idea` にサーバ結合で企画書サマリを含める (企画書 API 設計と同時に確定) /
  (b) FE が企画書 API を別途呼ぶ / (c) 表示自体を採用しない。
  [Answer]: **(a) サーバ結合で含める** (2026-07-30 ユーザー回答)。§2.1 に方針を反映済み。
  ~~フィールドの具体形は企画書ドメインの API 設計タスクで確定する~~
  **訂正 (2026-07-31。フィールド単位の照合で判明)**: **この 4 項目は企画書 (`plans`) ではなく
  `ideas` テーブル自身の列である** — [../data-model.md](../data-model.md) §4.6 の `ideas` は
  `summary` / `customer` / `issue` / `solution` を持ち、v2 も同じ 4 列を持つ
  (`hassan-v2-backend/db/schema.sql:155`〜`:158` = `concept` / `customer` / `issue` / `solution`)。
  **したがって「企画書ドメインの API 設計待ち」ではなく、`Idea` オブジェクトに 4 列を載せるだけで確定できる**
  (`plans` / `plan_tab_versions` からの結合は不要)。**Task-3p のブロッカーではない** —
  ただし v3 の列名 `summary` と v2 の `concept` の対応は未記録 (IB-Q14 の 4)

- **IB-Q12: ボード一覧の横断 KPI 統計 (作成中ボード内訳 / 登録アイデア合計 / 参加メンバー / 合計コメント数) を返すか**。
  事実: 更新版の一覧ヘッダに表示される (§1.3 の 2 行目)。現行の `GET /idea-boards` に集計は無い。
  選択肢: (a) `GET /idea-boards/stats` を新設 (themes.md TH-Q6 と同型) / (b) 一覧レスポンスに同梱 / (c) 採用しない。
  [Answer]: **(b) 一覧レスポンスに同梱** (2026-07-30 ユーザー回答。推奨 (a) ではなくこちらを選択 —
  リクエスト 1 本で済む)。§2 の `GET /idea-boards` に反映済み。**同梱が themes.md D-TH-2 の却下 (b) と
  矛盾しない理由も §2 に明記した** (ボードにはタブ切替との循環が無い / `stats` は絞り込み非依存の全体集計)

- **IB-Q13: `GET /items` に `sort=comment_count` とテーマ絞り込みを足すか**。
  事実: 更新版の詳細ツールバーに select があるが**配線なしのダミー** (§1.3 の 3 行目)。
  選択肢: (a) sort 値域に `comment_count`、クエリに `theme_id` を追加 / (b) ダミー UI とみなし現行のまま。
  [Answer]: **(a) 追加する** (2026-07-30 ユーザー回答)。§2 の `GET /items` に反映済み

---

## 7. アイデア参照 API の暫定配置 → [ideas.md](ideas.md) へ移設済み (2026-08-02)

**参照系は [ideas.md](ideas.md) へ移設済み**。`GET /ideas` / `GET /ideas/{idea_id}` /
`PUT /ideas/{idea_id}/star` / `GET /ideas/csv` の 4 本は、旧版の本節が暫定配置していた
参照専用 API だったが、生成系 (会話型アイデア創出) の設計が [conversation.md](conversation.md) /
[ideas.md](ideas.md) として確定したため、`ideas` テーブルを主対象とする API の SSOT を
[ideas.md](ideas.md) 1 箇所に統合した ([ideas.md](ideas.md) §8 の **R-IDA-1**。移設の判断は同書 §1.2)。

**旧版が置いていた制約 (アイデアの作成・本文更新・削除のエンドポイントを本ファイルに追加しない) は解除した**
— 当時の制約は「生成側の設計が確定するまで」という条件付きであり ([README.md](README.md) §6.1 の依存順序)、
その条件が満たされたため。**作成・本文更新・削除・版・評価は [ideas.md](ideas.md) §1.1 が定義する**。
本ファイルの範囲は §0 のとおりボードとその中身 (`idea_board_items` / コメント / フェーズ) に限られ、
アイデア自体の CRUD をここに追加することはない。

配置の判断 (集約する案の採用理由・却下した代替案) は [ideas.md](ideas.md) §7 の **D-IDA-1** が持つ。

---

## 8. `Idea` オブジェクトのフィールド照合 (2026-07-31 追加)

**経緯**: 更新版プロトタイプとエンドポイント一覧の再照合で、**本ファイルには
他ドメインファイル (§2 相当) が持っている「プロトタイプ ↔ v2 ↔ v3」の
フィールド対応表が `Idea` について存在しない**ことが分かった。参照系 3 本を
§7 の理由で後から本ファイルに置いたため、対応表を作る手順が抜けた。
以下がその対応表で、**当初 IB-Q14 として未確定 4 件を起票した (2026-07-31)**。
**IB-Q14-1〜3 は解決済み** (2026-08-02。下表参照)。**残る未確定は IB-Q14-4 の 1 件のみ**。

| プロトタイプの表示・データ | 出典 | v2 の列 | v3 の列 ([../data-model.md](../data-model.md) §4.6) | 現在の `Idea` (§2.1) | 判定 |
|---|---|---|---|---|---|
| `num` (通番) | `TM_THEMES[].ideas[].num` | — | `seq_no` | `num` | あり |
| `title` | 同上 | `title` | `title` | `title` | あり |
| `score` / `tier` | 同上 | `score` + 各軸スコア | `score` + 各軸スコア | `evaluation.{grade,score}` | あり (D-IB-3 で分解済み。**キー名は `grade`** — [ideas.md](ideas.md) §8 の R-IDA-1) |
| スター | `renderStarRater` | `star_rating` | `star_rating` | `stars` | あり |
| **`tags` (配列)** | `TM_THEMES[].ideas[].tags:["脱炭素","内部検査"]` (`:10488`)。ボード一覧のモックも配列 (`:12675`) | **無い** (`asset_tags` はアセット専用) | **無い** (§4.6 に `tag` 列・タグテーブルなし。`asset_tags` のみ — 同 §4.4) | **`tag` (単数)** — JSON 例 (§2.1) に 1 回だけ現れ、フィールド表・出典・格納先の記述が無い | **IB-Q14-1 (要確定)** |
| **`tam` (市場規模)** | テーマ内アイデア一覧の列 `i.tam` (`renderTmIdeasTable` が表示) | **`market_size text`** (`hassan-v2-backend/db/schema.sql:160`) | **`market_size`** | [ideas.md](ideas.md) §2.1 の `market_size` (表示用文字列をそのまま返す) | **IB-Q14-2 (回答済み — [ideas.md](ideas.md) §2.1)** |
| **`cagr` (成長率)** | 同上 `i.cagr` | **`cagr text`** (`hassan-v2-backend/db/schema.sql:161`) | **`cagr`** | [ideas.md](ideas.md) §2.1 の `cagr` (同上) | **IB-Q14-2 (回答済み — [ideas.md](ideas.md) §2.1)** |
| **`hasPlan` / `hasKnowledge`** | テーマ内アイデア一覧のバッジ | — | `plans` の存在 / `knowledge_*` の存在で導出可能 | [ideas.md](ideas.md) §2.1 の `has_knowledge` (**`has_plan` は持たない** — `stage.code=="plan"` と同値になるため) | **IB-Q14-3 (回答済み — [ideas.md](ideas.md) §2.1 / D-IDA-12)** |
| 事業コンセプト / 想定顧客 / 課題 / 解決方法 | `_ideaDetails` → ボード詳細の行内展開・企画書モーダル | `concept` / `customer` / `issue` / `solution` (`同:155`〜`:158`) | **`summary`** / `customer` / `issue` / `solution` | IB-Q11=a で「含める」と決定済み・形は未定 | **IB-Q14-4 (列名の対応が未記録)** |
| `projectRef` | `TM_THEMES[].projectRef` (`:10485` / `:11283`) | — | — | — | **対象外** — 宣言のみで**参照箇所 0 件の死んだフィールド**。設計に持ち込まない |

### IB-Q14 (要確認 — 残るは IB-Q14-4 の 1 件)

| # | 項目 | 論点 | 確定先 |
|---|---|---|---|
| ~~**IB-Q14-1**~~ | **`Idea.tag` の単複と格納先** → **回答済み (2026-07-31)** | §2.1 の JSON 例は `"tag": "半導体検査"` の**単数**だが、プロトタイプは**配列**。さらに **v2・v3 のどちらにもアイデア用のタグ列・タグテーブルが無かった** — **API が返すと宣言しているフィールドに書き込む側が存在しない** (BE-10 の「読む側と書く側を対で設計する」に該当) | **(a) 配列で持ち `idea_tags` テーブルを新設する** (ユーザー決定)。却下: (b) 単数の `ideas.tag` 列 — プロトタイプが 2 個以上のタグを表示しており 1 件目しか出せない / (c) タグを採らない — 探索の手掛かりを落とす。**API 側の確定**: `Idea.tag` (単数) を **`tags: string[]`** に改める (下記 §8.1)。**data-model.md への是正要求は §8.2** |
| ~~**IB-Q14-2**~~ | **`market_size` / `cagr` を `Idea` に載せるか** → **回答済み (2026-08-01。[ideas.md](ideas.md) §2.1)** | v2・v3 の双方に列があり、**プロトタイプのテーマ内アイデア一覧が列として表示している**のに `Idea` に無かった | **(a) 載せる。表示用の文字列 (`"12.4 兆円"`) をそのまま返し、数値には分解しない** ([ideas.md](ideas.md) §2.1) — この 2 つの文字列の**採点はサーバ側の Go が閾値表で行う** (同 §6.3.2) ため、FE が文字列をパースする必要が無い (FE-6 の再発点を作らない)。**2026-08-23 更新 (proto-v4 の 3 軸化)**: 旧記述にあった `evaluation.axis_scores.market_size` / `.market_cagr` は 3 軸化で存在しなくなった (`axis_scores` は 3 軸のみ — 同 §2.1) |
| ~~**IB-Q14-3**~~ | **`has_plan` / `has_knowledge` を返すか** → **回答済み (2026-08-01。[ideas.md](ideas.md) §2.1 / §7 D-IDA-12)** | プロトタイプはバッジで企画書・ナレッジの有無を示す。`stage.code` は進行段階であって「企画書が存在するか」とは別 | **`has_knowledge` のみ返す。`has_plan` は持たない** — `stage.code == "plan"` と同値になり、同じ事実を 2 つの名前で返すことになるため ([ideas.md](ideas.md) D-IDA-12) |
| **IB-Q14-4** | **v2 `ideas.concept` → v3 `ideas.summary` の写像** | v3 の列名は `summary` だが、[../data-model.md](../data-model.md) に **`concept` の言及が 1 件も無い** (リネームなのか意味が変わったのかが未記録)。移行時にどちらへ入れるかが決まらない | **[../data-model.md](../data-model.md) §6 の写像規則**への是正要求。IB-Q11=a の「4 項目を含める」を実装する前提になる |

### 8.1 IB-Q14-1 の反映 (API 側・確定)

**`Idea.tag` (単数) を `tags: string[]` に改める**。§2.1 の JSON 例の該当行は
`"tag": "半導体検査"` → `"tags": ["半導体検査", "予兆検知"]` となる。

| 項目 | 確定内容 |
|---|---|
| 型 | `tags: string[]` (**空配列可**。null は返さない — FE の分岐を増やさない) |
| 並び順 | **登録順** (`idea_tags.sort_order` 昇順)。`asset_tags` と同じ規約 ([../data-model.md](../data-model.md) §4.4) |
| 検索 | `GET /ideas` の `keyword` の対象に**タグを含める** — [assets.md](assets.md) D-AS-9 が `name` / `description` / `tags` を対象にしたのと同じ扱いに揃える |
| 更新経路 | **本ファイルでは持たない**。[ideas.md](ideas.md) §5 が `PUT /ideas/{idea_id}` の `tags` (全置換) として書き手を確定させた (**BE-10 クローズ** — 読む側だけあって書く側が無い状態を解消済み) |

### 8.2 [../data-model.md](../data-model.md) への是正要求 (IB-Q14-1 の帰結。**2026-07-31 に全 15 箇所を反映済み**)

**`idea_tags` テーブルを新設する**。`asset_tags` (同 §4.4) と同型:

| 項目 | 値 |
|---|---|
| テーブル | `idea_tags` |
| 主キー | `id` |
| 主要カラム | `tag` / `sort_order` |
| FK | `idea_id`→`ideas` (CASCADE) |
| 所有者列 | **`contract_id` + `account_id`** (個人スコープ。`asset_tags` と同じ — 同 §4.1.1 の 5 行目) |
| インデックス | `(idea_id)` / GIN trgm on `tag` (`keyword` 検索のため。`asset_tags` と同じ) |

**連動して更新が必要な箇所 (2026-07-31 に grep で実測。反映時はこの全件を同じ差分で直すこと — DR-8)**:

| # | 箇所 | 現在の値 → 変更後 |
|---|---|---|
| 1 | [../data-model.md](../data-model.md) **§4.1.1 の見出し** | 機能テーブル **39 件** → **40 件**。表に `idea_tags` の行を追加 (境界: 個人 / 所有者列: 両方) |
| 2 | 同 **§4.1.1 の注記** (「行番号 1〜N のうち欠番は無い」) | **39 → 40** |
| 3 | 同 **§5 の A-3 行** | 「機能テーブル **39 件**すべてが `contract_id`… 個人スコープの **31 件**」→ **40 件 / 32 件** (契約スコープ 8 件は不変) |
| 4 | [../auth.md](../auth.md) **§6.3 の分布注記** | 「**39 テーブル**の内訳 = 個人境界 **31** / 契約境界 8」→ **40 / 32 / 8** |
| 5 | [../architecture.md](../architecture.md) **§4 の所有者カラム方針** | 「テーブル **39**」→ **40**。**例外の件数は 2026-07-31 に転記そのものを廃止した** (下記の訂正を参照) |
| 6 | §4.6 の `ideas` 行 | `idea_tags` を子テーブルとして関連に追記 |
| **7** | [../data-model.md](../data-model.md) **§3.3 の検査②-2** | 「分類① ∪ ② ∪ ③ (**31 件**)」→ **32 件**。**機械検査の期待値**なので、直さないと実装した検査が必ず落ちる |
| **8** | 同 **§7.2 の検査 2-2** | 「`account_id` を持つテーブル (**31 件**)」→ **32 件**。同じく機械検査の期待値 |
| **9** | [../../aidlc-docs/inception/productionization/plan.md](../../../aidlc-docs/inception/productionization/plan.md) **Task-3a の記述** | 「**テーブル 39** (全件に `contract_id`)」→ **40** |

> **行番号を書かない方針にした (2026-07-31。4 巡目レビュー 中 2)**: 本表は初版で行番号 (`:360` / `:814` /
> `:1061` / `:362`) を引用していたが、**反映後の編集で 4 箇所すべてがずれ、`:1061` は別の検査 (検査 1) を
> 指すようになっていた**。本表は「テーブルを 1 件増やしたときに何を直すか」の唯一の実測リストとして
> `.claude/rules/05-harness.md` と `feedback_review_patterns.md` から参照され続けるため、
> **節番号 + 見出し語で書く** (行番号より寿命が長い)。

**例外列挙 (§4.1.2) は変更不要** — `idea_tags` は所有者列を持つため検査①の除外リストに入らない。

> **訂正 (2026-07-31。3 巡目レビュー 重大 2 の指摘)**: 本節の初版は**連動箇所を 6 件と書いたが実測は 9 件**で、
> **漏れていた 3 件はいずれも上表の 7・8・9** だった。**7・8 は機械検査の期待値**であり、
> 落とすと「設計どおりに実装した検査が必ず落ちる」形で実装リポに出る。
>
> **さらに初版は「`architecture.md` の『例外 11』は訂正済みの旧記述」と書いたが、これは誤り**。
> 2 つの別の数を混同していた: **「機能テーブル以外の N テーブル」** ([../data-model.md](../data-model.md)
> §4.1.2 の見出し) と **「検査①の除外リストの件数」** (同 §7.2) は別の数である。
>
> **その後の経緯 (2026-07-31 夜)**: **この種の件数は転記をやめる方針に切り替えた** —
> `auth.md` §6.3 と `architecture.md` §4 から**例外・除外リストの件数を削除**し、
> [../data-model.md](../data-model.md) §4.1.2 の 2 表を SSOT にしたうえで、
> **`make check-table-counts` が (a)(b) 表を実測して除外リスト件数・グループ行ラベルまで検算する**
> ようにした (照合 22 → 36 件)。**したがって上表の 4・5 は「今後は連動しない」** (件数が書かれていないため)。
> DR-9 の運用「検算に入れる **か** 書かない」のうち、**動きの速い集合は「書かない」を採る**。

> **反映完了 (2026-07-31)**: 上表 1〜9 に加え、**3 巡目レビュー後の再調査で分類側の連動 6 箇所が判明**し、
> **計 15 箇所**を 1 つの差分で反映した。§8.2 初版が 6 件、3 巡目レビューが 9 件と見積もったのに対し、
> **実際は 15 件**だった — 増えたのは `account_id` を持つテーブルを追加すると
> **§3.4.2 の 3 分類 (メンバー削除時の扱い) にも必ず入れる必要がある** (同節が「新規に `account_id` を持つ
> テーブルを追加するときは必ずどれかに入れる」と定めており、検査②-2 が未分類を落とす) ためで、
> **分類①の件数 28 → 29 が 4 箇所に現れる**ことを初版・レビューとも見落としていた。
>
> | # | 箇所 | 変更 |
> |---|---|---|
> | 1 | §4.1.1 見出し | 機能テーブル 39 → **40 件** |
> | 2 | §4.1.1 の表 | **`idea_tags` を 20 番として挿入**し、旧 20〜39 を 21〜40 へ繰り上げ (ドメイン順を維持) |
> | 3 | §4.1.1 の注記 | 「行番号 1〜39 / 39 行」→ **1〜40 / 40 行** |
> | 4 | §3.3 の検査②-1 | 分類① 28 → **29 件** |
> | 5 | §3.3 の検査②-2 | 分類① ∪ ② ∪ ③ 31 → **32 件** |
> | 6 | §3.4.2 の見出し | `account_id` を持つ 31 → **32 テーブル** |
> | 7 | §3.4.2 分類①の見出し | 移管する 28 → **29 件** |
> | 8 | §3.4.2 分類①の「アイデア・企画書」行 | 6 → **7 件**。`idea_tags` を列挙に追加 |
> | 9 | §4.6 のテーブル定義表 | **`idea_tags` の行を新設** (`tag` / `sort_order`、`idea_id`→`ideas` CASCADE、GIN trgm on `tag`) |
> | 10 | §5 の A-3 行 | 39/31 → **40/32** + 追加の出典 |
> | 11 | §7.2 の検査 2-1 | 28 → **29 件** |
> | 12 | §7.2 の検査 2-2 | 31 → **32 件** |
> | 13 | [../auth.md](../auth.md) `:592` | 39 / 個人境界 31 → **40 / 32** |
> | 14 | [../architecture.md](../architecture.md) `:759` | テーブル 39 → **40** (**「例外 11」は変更せず** — 上記の訂正のとおり) |
> | 15 | `aidlc-docs/inception/productionization/plan.md` Task-3a | テーブル 39 → **40** |
>
> **加えて 1 箇所**: [auth-accounts.md](auth-accounts.md) の AA-D-1 が「§4.1.1 の機能テーブル **39 件**にも無い」と
> 引用していたため **40 件**へ更新した (本表の作成後に別セッションが追加したファイルで、初版の実測時には存在しなかった)。
>
> **検証**: `テーブル 39` / `39 テーブル` / `39 件` / `39 行` / `1〜39` / `(31 件)` / `個人境界 31` /
> `31 テーブル` / `(28 件)` を `docs/` `aidlc-docs/` 全体に grep し、**残ヒットは本節の是正要求表
> (旧値→新値を記録している箇所) のみ**であることを確認した。
