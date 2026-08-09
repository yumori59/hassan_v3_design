# API: テーマ管理

> 共通規約 (認証・レスポンス形・エラー・ページネーション・ステータスコード) の SSOT: [README.md](README.md)
> 本ファイルが回答する本番観点: **A-4, A-5, A-7 (部分)** / 受入基準: **AC-1.1, AC-1.4**

## 1. 対応する画面と参照する既存実装

| 区分 | 所在 |
|---|---|
| プロトタイプ | `home` ビュー — `../../prototype/hassan_agent_prototype_v2.html` の HTML `:6649-6669` / JS `:10478-11913` (2026-07-30 更新版の実測) |
| プロトタイプのモックデータ | `TM_THEMES` (`:10478`)、新規テーマウィザードの状態 `_twState` (`:11128-11136`) |
| v2 の既存実装 | `hassan-v2-backend/controller/theme.go`、`hassan-v2-backend/usecase/theme/`、`hassan-v2-backend/db/queries/theme.sql` |
| v2 の既存テーブル | `themes` (`hassan-v2-backend/db/schema.sql:94-102`) — `id` / `account_id` / `name` / `hex` / `created_at` / `updated_at` の **6 カラムのみ** |

### 1.1 v2 と プロトタイプの対応表

| プロトタイプの概念 | v2 に相当するもの | 判定 |
|---|---|---|
| テーマ名 (`name`) | `themes.name` | あり |
| 色 (`iconClass` / `icon`) | `themes.hex` (色のみ。アイコン名は無い) | 部分 |
| ミッション (`mission`) — **2026-07-30 更新でサブタイトル (`sub`) / 目的 (`purpose`) が単一フィールドに統合された** (`TM_THEMES` `:10478-10605` に `sub`/`purpose` は無く、ウィザード Step1 も「テーマ名 + ミッション」のみ — `:11176-11179`) | **無い** | 新規 (TH-Q7) |
| 主アセット (`asset`) | **無い** (v2 はアセットとテーマを `idea_hassans.asset_ids` で間接的に結ぶ — `hassan-v2-backend/db/schema.sql:119-135`) | 新規 |
| ステージ (`stage` / `stageName` / `stageDone`) | **無い**。**更新版プロトタイプでは seed データ (`TM_THEMES`) に無く、一覧にも表示されない** — 新規作成時に `saveNewTheme` (`:11258-11294`) が書くだけで読み手が無い | 新規 (TH-Q3) |
| 進捗 (`progress` / `progressTxt`) | **無い** (同上 — 更新版では書くだけで読み手が無い) | 新規 (TH-Q3) |
| メンバー (`team` / `teamExtra`) | **無い** (v2 の共有は `sharing_settings` によるカテゴリ単位の ON/OFF — `hassan-v2-backend/db/schema.sql:491-499`) | 新規 |
| 可視性 (`visibility`: private / team / open) | **無い** (更新版でもウィザード Step2 に 3 値で存在 — `TW_VISIBILITY` `:11122-11126`) | 新規 |
| ステータス (`status`: progress / done / archive) | **無い**。**更新版プロトタイプでは seed に無く、ステータス別件数タブも消えた** (TH-Q6 / TH-Q8) | 新規 |
| アイデア数・企画書数 | `dto.ThemeRes.idea_count` / `business_plan_count` (`hassan-v2-backend/controller/dto/theme.go:13-14`) | あり |
| ナレッジ件数 (`knowledgeCount`) — **2026-07-30 更新で一覧列 (`:10863-10866`) と統計カード (`:10802-10808`) に追加** | **無い** | 新規 (TH-Q9) |
| 一覧の集計 | **無い** (プロトタイプはクライアント側で算出 — `_tmCounts()` `:10729-10736`。**更新版の統計カードは「テーマ数 / アイデア数 / 企画書数 / ナレッジ数」の 4 種で、ステータス別件数ではない** — `renderTmStats` `:10738-10810`) | 新規 (TH-Q6) |
| テーマ詳細ページ | **無い** (**更新版では行クリックがテーマ内アイデア一覧のドリルダウンに遷移する** — `:10877-10888` → `renderTmIdeasTable` `:10900`〜。発散画面へは「アイデア発散を開く」ボタン経由 — `:10686` / `:11069`) | — (実質のテーマ詳細に相当) |

**事実**: v2 の `themes` は 6 カラムしかない。プロトタイプのテーマ行に見えるものの**大半は v3 の新規概念**であり、
`docs/design/data-model.md` の確定が必要。本ファイルは**エンドポイントの形**を確定し、
フィールドは **(暫定)** として扱う。
**2026-07-30 のプロトタイプ更新で上表の前提が複数変わった** — 差分に依存する判断は §6 に `[Answer]:` で起票した。

---

## 2. エンドポイント一覧

すべて認証必須 (`X-Token`)。401 の扱いは [README.md](README.md) §2.1、
共通の 400/500 は [README.md](README.md) §2.5 に従い、本表では**エンドポイント固有のコードのみ**挙げる。

| メソッド | パス | 概要 | スコープ | 主なリクエスト / レスポンス項目 (暫定) | 固有ステータス | LLM | SSE | 増分 |
|---|---|---|---|---|---|---|---|---|
| GET | `/themes` | 一覧 | 個人 / 契約 | Q: `scope` (`mine`\|`contract`, 既定 `mine`。**`contract` は増分 1 から有効** — C-16。§3.2) / `keyword` / `limit` / `offset` / `sort` (`updated_at`\|`created_at`\|`name`) — **`status` クエリは持たない** (TH-Q6=a) | 200 / **400** (`scope` の値域外) | — | — | 1 |
| GET | `/themes/stats` | 集計サマリ | 個人 / 契約 (**`contract` は増分 1 から有効**) | Q: `scope` / `keyword` — R: `{theme_count, idea_count, business_plan_count, knowledge_count}` (**TH-Q6=a で確定。ステータス別件数は返さない**) | 200 / **400** (`scope` の値域外) | — | — | 1 |
| POST | `/themes` | 作成 | 個人 | B: `name` (必須) / `mission` / `hex` / `icon` / `primary_asset_id` (null 可) — R: `Theme` (**TH-Q7=a: `subtitle`/`purpose` は `mission` に統合**) | **201** / **409** (同一アカウント内の名前重複) | — | — | 1 |
| GET | `/themes/{theme_id}` | 取得 | 個人 / 契約 (§3.2) | R: `Theme` (+ `idea_count` / `business_plan_count` / `knowledge_count`) | 200 / 404 | — | — | 1 |
| PUT | `/themes/{theme_id}` | 更新 | 個人 | B: `name` / `mission` / `hex` / `icon` / `primary_asset_id` — R: `Theme` | 200 / 404 / **409** (名前重複) | — | — | 1 |
| DELETE | `/themes/{theme_id}` | 削除 | 個人 | — | **204** / 404 | — | — | 1 |
| GET | `/themes/{theme_id}/members` | メンバー一覧 | 契約 | R: `{items:[{account_id, name, icon_url}]}` (**`role` は持たない** — メンバーの権限差は未確定 (TH-Q5)。持たせる場合は `PUT` 側と対で追加する = BE-10) | 200 / 404 | — | — | **2** |
| PUT | `/themes/{theme_id}/members` | メンバー置換 | 契約 | B: `{account_ids:[...]}` (**自契約のアカウントのみ許可**) — R: `{items:[Member]}` | 200 / 404 / **400** (契約外のアカウント ID) | — | — | **2** |
| PUT | `/themes/{theme_id}/visibility` | 可視性変更 | 個人 | B: `{visibility: "private"\|"contract"}` — R: `Theme` | 200 / 404 | — | — | **1** |

Q = クエリパラメータ / B = リクエストボディ / R = レスポンス。

### 2.1 `Theme` オブジェクト (暫定)

```json
{
  "id": 12,
  "name": "超音波センシング 新規事業探索 v2",
  "mission": "水素インフラの安全性を非破壊センシングで抜本的に高める",
  "hex": "#0455c5",
  "icon": "sensors",
  "visibility": "private",
  "primary_asset": { "id": 3, "name": "超音波センシング技術" },
  "idea_count": 8,
  "business_plan_count": 2,
  "knowledge_count": 3,
  "created_at": "2026-07-01T02:00:00Z",
  "updated_at": "2026-07-28T10:12:00Z"
}
```

**2026-07-30 のユーザー回答 (§6) を反映済み**: `subtitle`/`purpose` は `mission` に統合 (TH-Q7=a)、
`status` / `stage` / `progress` は持たない (TH-Q6=a / TH-Q8=a — ステージ・進捗を返す必要が生じたら
会話型アイデア創出の設計と同時に再導入する)、`knowledge_count` は派生値 (TH-Q9=a。
アイデア経由で紐づくナレッジスレッド数のサーバ集計)。
`primary_asset` は `null` を取り得る (プロトタイプの「未定 (発散で選定)」—
`TM_THEMES` の `asset: null` に相当する状態)。
`visibility` は**増分 1 から読み書きする** (**2026-07-31 改訂**。旧記述は「増分 1 では常に `private`」。
C-16 により v2 の `POST /sharing-settings` の操作を落とせない — [../auth.md](../auth.md) §6.12)。
**既定値は契約設定から決まる** (同 §6.12 の 3)。

---

## 3. 設計判断

| # | 論点 | 採用案 | 却下案と理由 |
|---|---|---|---|
| D-TH-1 | 一覧の所有者絞り込み | **`scope=mine\|contract` の列挙値**。`account_id` パラメータを持たない ([README.md](README.md) D-API-8)。**`contract` は増分 1 から有効** (§3.2 / [README.md](README.md) D-API-8'。**2026-08-02 に「増分 2」から改訂** — C-16 により v2 の `POST /sharing-settings` でできていた共有の切り替えを落とせないため) | (a) v2 の `account_id` クエリ踏襲 (`hassan-v2-backend/controller/theme.go:46-53`): **v2 のテーマ一覧は契約一致を検証していない** (`hassan-v2-backend/usecase/theme/list_themes.go:56-62` は `GetAccountByID` の存在確認のみで、当該クエリは `SELECT * FROM accounts WHERE id = $1` — `hassan-v2-backend/db/queries/account.sql:1-2`)。同じ入力形を持ち込むと同じ検証漏れを招く。アセット側には契約一致検証がある (`hassan-v2-backend/usecase/asset/list_assets.go:60-66`) という**非対称が現に存在する**ことが、パラメータ設計で防ぐ根拠 |
| D-TH-2 | 集計値の返し方 | **サーバが `GET /themes/stats` で返す** (FE 算出にしない)。**指標は「テーマ数 / アイデア数 / 企画書数 / ナレッジ数」の 4 種で確定** (TH-Q6=a。2026-07-30 のプロトタイプ更新の統計カード — `renderTmStats` `:10738-10810` — に一致させた) | (a) FE 側で算出 (プロトタイプ方式 — `_tmCounts()` `:10729-10736`): ページネーション (`limit=50`) と両立しない。1 ページ分しか数えられず、件数が実データと食い違う。(b) 一覧レスポンスに件数を同梱: タブ切替のたびに一覧を再取得する必要があり、絞り込みと循環する |
| D-TH-3 | 可視性の値域 | **`private` (作成者のみ) と `contract` (契約内) の 2 値**。プロトタイプの `team` を `contract` に写像し、**`open` は採らない**。**既定は `private`** で、`scope=contract` の判定条件になる (§3.2) | (a) プロトタイプの 3 値 (`private`/`team`/`open`) をそのまま採用: **`open` の公開先が未定義**。契約外への公開はテナント境界を越えるため、要件が確認されないまま実装者が解釈するとデータ漏洩の形で現れる (DR-7)。`open` が必要になった場合は [../auth.md](../auth.md) A-7 の共有設計と同時に決める。(b) v2 の `sharing_settings` (カテゴリ単位の ON/OFF) をそのまま使う: テーマ 1 件ごとの可視性を表現できない |
| D-TH-4 | ステージ・進捗の扱い | **テーマ API は `stage` / `progress` を返さない** (TH-Q6=a で確定。2026-07-30 の更新版プロトタイプは一覧にステージ・進捗を表示しない — §1.1)。ステージの概念自体は会話型アイデア創出の設計 (SSOT) が持ち、テーマ画面で再び必要になったら**派生値の読み取り専用**として再導入する (当初案) | (a) テーマに `stage` / `progress` カラムを持たせ、クライアントが更新する: 会話フローの進行と二重管理になり、どちらが正か決まらない (BE-10 の「読む側と書く側の対応」が壊れる形)。(b) 当初案 (派生値を返す): 表示する画面が更新版プロトタイプに存在しなくなったため、消費者のいないフィールドになる |
| D-TH-5 | メンバー・可視性の増分 | **可視性 (`PUT /visibility`) と `scope=contract` は増分 1** (**2026-07-31 改訂** — C-16。v2 の共有切替の操作を落とせない。[../auth.md](../auth.md) §6.12)。**テーマメンバー機能 (`theme_members`) だけは増分 2 のまま** — **v2 にテーマ単位のメンバー共有は存在しない**ため C-16 の対象外 (v2 の共有は契約 × カテゴリの 1 段のみ) | (a) 増分 1 に含める: [../auth.md](../auth.md) §7 の A-7 が「本増分では共有機能を持たない」と判断しており、矛盾したまま実装すると認可設計 (誰がメンバーを変更できるか) が未確定のまま入る。(b) 設計もしない: プロトタイプの新規テーマウィザードがステップ 2 で必ずメンバー・可視性を聞く (`:11188-11231`) ため、後付けだと作成フローの API が変わる。(c) **`visibility` は増分 2 だが `scope=contract` は増分 1 で出す** (**当初案・却下**): 増分 1 には絞り込む属性が無いため契約内の全テーマが見える。v2 の既定は非共有 ([README.md](README.md) F-16) なので、切替が一斉公開になる (DR-3) |
| D-TH-6 | 名前重複 | **同一アカウント内で一意**とし、衝突は **409** | (a) 重複を許す: v2 に `ThemeNameDuplicationError` (`hassan-v2-backend/controller/apperror/error.go:188`) が既に定義されており、既存の運用ルールを緩めることになる。(b) 契約内で一意: 他人のテーマ名が見えない状態で 409 が返り、**存在の漏洩**になる ([README.md](README.md) §2.5 の 404 方針と矛盾) |
| D-TH-7 | 削除の方式 | **アーカイブ (`status=archive`) は採らない** (TH-Q8=a で確定)。削除は**確認 UI 必須の単一経路**とし、更新版プロトタイプの確認モーダル (`openDeleteThemeModal` `:11831-11883`。「チャット履歴・アーティファクト・バージョン履歴が全て失われる」警告付き) を FE 要件にする。**削除の物理/論理は data-model.md DM-5 (全テーブル論理削除 `deleted_at`) が SSOT** — API の見え方は「削除後は 404」で、論理削除は誤削除時の運用復元手段として下層に持つ | (a) アーカイブ状態を UI の既定の「消し方」とする (当初案): 更新版プロトタイプからアーカイブ UI が消滅し、`status` 概念ごと落とす TH-Q6=a とも整合しない。(b) v2 と同じ物理削除 (`DELETE FROM themes` — `hassan-v2-backend/db/queries/theme.sql:32-33`): テーマは配下にアイデア・企画書を持ち、ボード上のアイデアとコメントまで連鎖で消える — data-model.md DM-5 が却下済み |
| D-TH-8 | 更新の粒度 | **PUT で全項目置換** | (a) `PATCH` で部分更新: v2 に `PATCH` の前例が無く (`hassan-v2-backend/router/router.go` に `PATCH` の登録は無い)、null と「未指定」の区別を実装ごとに決めることになる |

### 3.1 検索対象フィールドの明示 (D-API-10 の具体化)

プロトタイプの検索の実装は「テーマ名・ミッション・主要アセット名・メンバー名」を対象にする
(`renderTmTable` のフィルタ `:10816-10821`。プレースホルダ文言は `:6658`)。
v3 の `keyword` の対象を**次の 2 つに限定**する:

| 対象 | 理由 |
|---|---|
| テーマ名 (`name`) | v2 も `name LIKE` で検索している (`hassan-v2-backend/db/queries/theme.sql:13`) |
| ミッション (`mission`) | 一覧行に表示される情報であり、見えている文字列が検索できないと混乱する (TH-Q7=a により `subtitle` から差し替え。プロトタイプの検索実装 `:10817`〜`:10821` も `mission` を対象にしている (`mission` の行は `:10819`)) |

**メンバー名は対象外**とする (増分 2 でメンバー機能が入るまで検索対象が存在しない)。
**主アセット名は対象外**とする (JOIN 先の部分一致は `assets` 側の全文検索設計と重複するため、
アセット起点の探索は `GET /assets` を使う)。増分 2 でメンバー検索を追加する場合は
`sort` と同様にホワイトリストへ追加する。

---

### 3.2 `scope=contract` のゲートと既存データの移行 (重要 — DR-3)

**本節が回答する ID: A-7 / A-4** — [README.md](README.md) D-API-8' の具体化。

v2 では**契約内の他人のテーマが見えるかを `sharing_settings` (契約 × カテゴリの ON/OFF) が決めている**。
テーマ一覧は `is_shared == false` のとき絞り込み対象を認証ユーザーへ強制し、契約スコープ経路に入れない
(`hassan-v2-backend/usecase/theme/list_themes.go:42-52`。**レコード未作成時は false 扱い = 既定は非共有**)。

| 増分 | `scope` | 判定 | 理由 |
|---|---|---|---|
| **1** | `mine` のみ (`contract` は 400) | `WHERE account_id = <認証ユーザー>` | 可視性を表す属性がまだ無い。**切替時点で見える範囲を v2 と同じか狭い側に保つ** |
| **2** | `mine` / `contract` | `contract`: `WHERE contract_id = <契約> AND (visibility = 'contract' OR account_id = <認証ユーザー>)` | per-theme `visibility` (D-TH-3) が判定条件になる |

**移行 (切替時に 1 度だけ実行)**:

| # | 処理 | 理由 |
|---|---|---|
| TM-1 | 既存テーマの `visibility` の初期値を、**所属契約の `sharing_settings` (category = idea) から決める**: `is_shared = true` → `contract` / `false` またはレコード無し → `private` | **切替前後で見える範囲を変えない**。v2 で共有していた組織はそのまま共有され、していない組織は非公開のまま |
| TM-2 | `visibility` を持つカラムを増分 1 の時点で**スキーマに用意**し、**書き込み API (`PUT /themes/{id}/visibility`) と `scope=contract` も増分 1 で開ける** (**2026-07-31 改訂**。旧案は「書き込みは増分 2」— [requirements.md](../../../aidlc-docs/inception/productionization/requirements.md) **C-16** により v2 の `POST /sharing-settings` の操作を落とせない。理由の SSOT は [../auth.md](../auth.md) §6.12)。**既定値は契約設定から決める** (同 §6.12 の 3) | カラムを後から足すと TM-1 の初期値決定を増分 2 まで遅らせることになり、**その間に作られたテーマの既定が二重管理**になる |

**却下**: v2 の `sharing_settings` を v3 にそのまま引き継いで契約 × カテゴリで判定する案 —
プロトタイプが要求する**テーマ 1 件ごとの可視性** (`TM_THEMES[].visibility`) を表現できない。
ただし**既存値は TM-1 の初期値として使う** ([settings.md](settings.md) ST-Q5 と対応)。

## 4. 本番観点への回答

| ID | 回答 | 備考 |
|---|---|---|
| A-1 | [README.md](README.md) §2.1。全 9 本が認証必須 | AC-1.1 |
| A-2 | `AuthRoleUser` のみ。契約内管理者限定の操作は無い | — |
| A-3 | `themes` 相当の新テーブルは `account_id` 必須。可視性が `contract` のとき `contract_id` も持つ ([../auth.md](../auth.md) §6.3) | data-model で確定 |
| A-4 | 一覧・単体取得・更新・削除のすべてで Repository のクエリ条件に所有者を入れる。`mine` は `account_id`、`contract` (**増分 1 から有効**) は `contract_id` + `visibility` 条件 (§3.2)。**更新・削除は増分 2 でも作成者のみ** (他人のテーマ指定は 404) | D-TH-1 / §3.2 |
| A-5 | 本表の「固有ステータス」列 + [README.md](README.md) §2.5 | **AC-1.4** |
| A-6 | 本ファイルに LLM 経路は無い | — |
| A-7 | **回答**。可視性は 2 値に限定 (D-TH-3)。**可視性変更と `scope=contract` は増分 1** / **テーマメンバー機能のみ増分 2** (D-TH-5。**2026-07-31 に C-16 で改訂**。判断の SSOT は [../auth.md](../auth.md) §6.12)。**既存 `sharing_settings` からの初期値決定を移行手順に含めた** (§3.2 TM-1) | [README.md](README.md) §5 API-Q3 |
| O-2 / O-5 | 該当なし (LLM / SSE エンドポイントを持たない) | — |
| O-6 | テーマの作成・削除は監査対象。記録項目は [../observability.md](../observability.md) §4.5 | — |

---

## 5. 要確認 (プロトタイプに UI のみ / 判断待ち)

| # | 項目 | プロトタイプの状態 | 確定先 |
|---|---|---|---|
| TH-Q1 | **エクスポート** | **再オープン → 決着 (2026-07-31 ユーザー回答 = 「csv はあったほうが良い」)**。**v2 の `GET /ideas/csv` (`hassan-v2-backend/router/router.go:127`) を v3 に引き継ぐ** — C-16 ([../../aidlc-docs/inception/productionization/requirements.md](../../../aidlc-docs/inception/productionization/requirements.md))。**2026-07-30 のクローズは撤回した**: 根拠が「更新版プロトタイプのヘッダにボタンが無い」ことだけで、**プロトタイプは設計入力であって仕様ではない** (DR-7) / v2 に実装が実在する。**エクスポートの対象はテーマ一覧ではなくアイデア一覧** (v2 と同じ) で、仕様は [idea-boards.md](idea-boards.md) §2.4 が SSOT (`GET /ideas/csv`)。**本書側の残作業は FE のボタン配置のみ** ([../frontend.md](../frontend.md) への是正要求 = [../auth.md](../auth.md) §10.4 R-12) | **決着済み** |
| TH-Q2 | **可視性 `open` の公開先** | ウィザードに 3 番目の選択肢として存在する (`TW_VISIBILITY` `:11122-11126`) が、公開先の説明がない | 要件確認 (D-TH-3 で暫定的に不採用) |
| TH-Q3 | **ステージの段数** | **完全にクローズ (2026-08-01)**。①テーマ API の論点としては 2026-07-30 にクローズ済み (TH-Q6=a により**テーマ API は stage/progress を返さない** = D-TH-4) ②残っていたステージ定義の SSOT は **[conversation.md](conversation.md) §2.3 が確定**した — **`stage` は PoC と同じ 5 値** (`asset` → `market` → `match` → `ideation` → `plan_draft`) を**台帳から `entity/conversation` の純粋関数で導出**する。**会話の `stage` を他ドメインへ配らない**方針も同節が定めており、D-TH-4 (テーマは返さない) と整合する | **クローズ済み** ([conversation.md](conversation.md) §2.3 が SSOT) |
| TH-Q4 | **テーマ削除時の配下データ** | **更新版に物理削除の確認モーダルあり** (`openDeleteThemeModal` `:11831-11883`。「チャット履歴・アーティファクト・バージョン履歴が全て失われる」と警告)。リネーム UI もある (`renameThemeById` `:11598-11613`) | data-model 設計 (D-TH-7 / TH-Q8 と連動。アイデア・企画書・ボードアイテムの参照をどうするか) |
| TH-Q5 | **メンバーの権限差** | ウィザードでメンバーを選ぶだけで、権限の区別が無い (`TW_MEMBERS` `:11115-11120`) | 増分 2 の要件確認 ([../auth.md](../auth.md) §9 Q-A2 と連動) |

---

## 6. プロトタイプ更新 (2026-07-30) による再確認事項

更新版プロトタイプで**画面側の前提が変わった**ため起票した再確認事項。
**TH-Q6〜TH-Q9 は 2026-07-30 にすべて回答済みで、本文 (§2 / §2.1 / §3) へ反映済み**。

- **TH-Q6: `GET /themes/stats` が返す指標**。
  事実: ステータス別件数タブが消滅し、統計カードは「テーマ数 / アイデア数 / 企画書数 / ナレッジ数」
  (`renderTmStats` `:10738-10810`)。`status` は一覧 UI のどこにも現れない。
  選択肢: (a) 4 指標に変更し、`status` クエリと `stage`/`progress` フィールドも落とす /
  (b) 現行設計 (`{all, progress, done, archive}`) を維持し、画面差分は FE 実装で吸収する。
  [Answer]: **(a) 4 指標に変更** (2026-07-30 ユーザー回答)。§2 の `GET /themes/stats` レスポンス・
  `GET /themes` の `status` クエリ削除・§2.1 Theme・D-TH-2 / D-TH-4 に反映済み

- **TH-Q7: `subtitle` / `purpose` を `mission` に統合するか**。
  事実: プロトタイプは単一の `mission` に統合 (ウィザード Step1 は「テーマ名 + ミッション」のみ — `:11176-11179`)。
  ミッションはアイデア評価の軸 (`missionFit` / `missionScore` — `:10493`) としても参照される。
  選択肢: (a) `Theme` を `mission` 単一フィールドに変更する (POST/PUT・§3.1 の検索対象も連動) /
  (b) `subtitle` / `purpose` を維持する。
  [Answer]: **(a) `mission` に統合** (2026-07-30 ユーザー回答)。§2 の POST/PUT・§2.1 Theme・
  §3.1 の検索対象に反映済み。data-model.md の `themes` テーブル定義も同時に是正

- **TH-Q8: アーカイブ (`status=archive`) の存否**。
  事実: アーカイブ UI が消滅し (文言 0 件)、物理削除モーダルに置き換わった (`:11831-11883`)。
  選択肢: (a) `status` 概念ごと落とし、削除のみにする (TH-Q6-(a) と連動) /
  (b) D-TH-7 どおりアーカイブを残す (誤削除への安全弁として設計側の判断で維持)。
  [Answer]: **(a) `status` 概念ごと落とす** (2026-07-30 ユーザー回答)。削除は確認 UI 必須の単一経路。
  誤削除への安全弁は data-model.md DM-5 の論理削除 (`deleted_at`) が運用復元手段として担う。D-TH-7 に反映済み

- **TH-Q9: テーマのナレッジ件数**。
  事実: 一覧列 (`:10863-10866`) と統計カード (`:10802-10808`) に `knowledgeCount` が表示される。
  テーマとナレッジスレッドの関連は [knowledge.md](knowledge.md) の設計ではアイデア経由 (1 アイデア = 1 スレッド)。
  選択肢: (a) `Theme` に `knowledge_count` (派生値) を追加する / (b) 返さない (FE がナレッジ API から引く)。
  [Answer]: **(a) 派生値で返す** (2026-07-30 ユーザー回答)。算出はアイデア経由で紐づくナレッジスレッド数の
  サーバ集計 (テーブルに保持しない)。§2 の一覧/取得/stats に反映済み
