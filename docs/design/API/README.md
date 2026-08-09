# API 設計 (アイデア発散以外の全ドメイン)

> 本書が回答する本番観点: **A-1, A-2, A-4, A-5** (A-3 / A-6 は参照、O-2 / O-5 は該当経路の明示 + 委譲)
> 対応する受入基準: **AC-1.1** (全エンドポイントが認証を通る) / **AC-1.4** (401/403/404 の一覧化)
> 判定規則の SSOT: [../auth.md](../auth.md) §6.6 / 層構造の SSOT: [../architecture.md](../architecture.md) §3
> 必須観点 ID 一覧: [../../../.claude/rules/08-production-gates.md](../../../.claude/rules/08-production-gates.md)

## 0. 本ディレクトリの位置づけ

[plan.md](../../../aidlc-docs/inception/productionization/plan.md) の **Task-3b** に相当する。
`docs/design/api.md` 単一ファイルの代わりに、**ドメインごとにファイルを分割**した
(理由: 9 ドメイン × 各 5〜22 エンドポイントを 1 ファイルに置くと、増分ごとの更新で
コンフリクト範囲が全ドメインに広がる。SSOT は「1 ドメイン 1 ファイル」で保つ)。

### 対象と対象外

**2026-08-02 追記**: 会話型アイデア創出 (アイデア発散) は当初「本ディレクトリの対象外」としていたが、
[conversation.md](conversation.md) / [ideas.md](ideas.md) / [plans.md](plans.md) の 3 ファイルが確定したため、
**本ディレクトリの対象に含める**。これにより「6 ドメイン」は**9 ドメイン**になる。

| 区分 | 内容 | 所在 |
|---|---|---|
| **対象** | **§3 の総覧に載る全ドメイン** (テーマ管理 / アセット管理 / ナレッジ (RAG チャット) / アイデアボード / お知らせ / 設定 / 会話 / アイデア / 企画書) | 本ディレクトリの各ドメインファイル。**ドメイン数と本数は §3 の総覧が正** — ここに件数を書かない (DR-9。`make check-endpoint-mapping` が §3 を機械照合する) |
| **対象** | 会話型アイデア創出 (会話セッション・同期 SSE ターン・custom tool・台帳・`stage`) | [conversation.md](conversation.md) (**2026-08-02 追加**) |
| **対象** | アイデア (参照・人手編集・版・タグ・評価。生成物の受け先) API。**`ideas` テーブルを主対象とする API の SSOT** | [ideas.md](ideas.md) (**2026-08-02 追加**。旧版が [idea-boards.md](idea-boards.md) §7 に暫定配置していた参照系 3 本 + CSV 1 本を移設して統合した) |
| **対象** | 企画書 (8 タブ・生成/再生成・版・お気に入り・チャット・詳細版・サムネイル) API | [plans.md](plans.md) (**2026-08-02 追加**) |
| **対象** | 認証・アカウント基盤の API (サインイン・サインアップ・パスワードリセット・MFA・メンバー管理・会社情報 + **アカウント手動ロック / 解除** + 社内管理者経路) | [auth-accounts.md](auth-accounts.md) (**2026-07-31 追加**。ユーザー決定 2026-07-30 = [settings.md](settings.md) §4 の **D-ST-1'** により v3 で実装する)。移植対象の一覧は [settings.md](settings.md) §5、認証・認可の規約は [../auth.md](../auth.md) |

> **§1・§2 の共通規約は上表の 9 ドメインを対象に書かれている** (本数は §3 の総覧が正 — DR-9)。
> [auth-accounts.md](auth-accounts.md) は同じ規約に載るが、**認証系であるがゆえの差分 3 点**を持つ:
> ①**公開エンドポイント 6 本がある** (§2.1 の「本ディレクトリに公開エンドポイントは無い」の例外)
> ②**資格情報エラーの 401 に `CodedError` 本文を持つ** (§2.5 の「401 は本文なし」の例外)
> ③**429 を返す 11 本がある** (§2.5 の 429 行が「本ディレクトリの対象外」としている範囲の例外。
> 未認証で叩ける 6 本 + MFA 検証 2 本 + **認証済みで資格情報を提示する 3 本** = メール変更 / パスワード変更 / MFA 再登録)。
> 加えて **403 の第 3 系統 (契約の不変条件ガード)** を持つため、§2.2 / §2.5 の「403 は R-1 / R-2 の
> 2 系統・合計 16 本」は**9 ドメインについての数**である。差分の根拠は
> [auth-accounts.md](auth-accounts.md) §3.1 (AA-D-9 / AA-D-12 / AA-D-17) / §3.1.1 (コードの値域) / §3.7、
> SSOT 側への是正要求は同 §5 **R-AA-2a** ([../auth.md](../auth.md) §6.6 宛て) / **R-AA-2b**。

### プロトタイプの扱い (DR-7)

[../../prototype/hassan_agent_prototype_v2.html](../../prototype/hassan_agent_prototype_v2.html) は
**設計入力であって仕様ではない**。プロトタイプは静的モックであり、**配線されていないボタンが多数ある**。
本ディレクトリでは:

- プロトタイプに由来するフィールドは表内で **(暫定)** と明記する
- **配線のないダミー UI** は「エンドポイント一覧」に載せず、各ドメインファイルの
  **「要確認 (プロトタイプに UI のみ)」節**に分けて置く。仕様を勝手に確定しない
- したがって「README の総覧表 = 各ドメインファイルの**エンドポイント一覧表**」であり、
  要確認節の候補は総覧に含まれない

### データモデル未確定の扱い

`docs/design/data-model.md` は**確定済み** (2026-08-02 時点。当初この行は「未着手 (Q-1 未回答)」だった)。本ディレクトリは
**Q-1 の回答に依存しない範囲**(パス・メソッド・スコープ・ステータスコード・SSE/LLM の有無) を確定させ、
**リクエスト/レスポンスのフィールドはプロトタイプ由来の暫定**として書く。
データモデル確定後に、各ドメインファイルの「主なリクエスト/レスポンス項目」列を更新する。

---

## 1. 現状 (v2 の API 規約) と v3 の決定

### 1.1 v2 の事実 (出典付き)

| # | 項目 | v2 の現状 |
|---|---|---|
| F-1 | バージョニング | **無い**。ルート直下に `r.Group("/themes")` 等を登録 (`hassan-v2-backend/router/router.go:85`) |
| F-2 | パス命名 | kebab-case・複数形が基本 (`/idea-boards` `:130`, `/idea-hassans` `:143`, `/sharing-settings` `:188`)。ただし `/company-mission` (単数)・`/event_logs` (snake_case, `:235`) が混在。パスパラメータも同一リソース内で `:id` と `:hassan_id` が不一致 (`hassan-v2-backend/controller/idea_hassan.go`) |
| F-3 | 認証の適用 | **ルート個別指定**が原則。約 90 ルートが第 1 ハンドラに `AuthRequiredMiddleware(auth.AuthRoleUser)` を書く (`hassan-v2-backend/router/router.go:62-237`)。`Group.Use()` は 3 箇所のみ ([../auth.md](../auth.md) §1.7) |
| F-4 | リクエスト | `c.BindJSON(&req)` (`hassan-v2-backend/controller/theme.go:137`) → 失敗時 `badRequest(c, apperror.InvalidRequestBodyError())` (`同:139`)。DTO に `binding:"required"`。カスタムバリデータ登録あり (`hassan-v2-backend/controller/custom_validator.go:11`) |
| F-5 | 正常レスポンス | **エンベロープ無し**。`json(c, obj)` が `X-Server-Latency` を付けて返す (`hassan-v2-backend/controller/controller.go:72`)。単一リソースは裸オブジェクト (`hassan-v2-backend/controller/asset.go:177`)。JSON キーは snake_case (`hassan-v2-backend/controller/dto/theme.go:8-17`) |
| F-6 | 一覧レスポンス | **3 パターン混在**: ① `{assets, total_count}` (`hassan-v2-backend/controller/dto/asset.go:49-53`) ② **裸配列** (ListThemes — `hassan-v2-backend/controller/theme.go:86`) ③ `gin.H{"ideas","total","filter"}` (`hassan-v2-backend/controller/idea_board.go:256`) |
| F-7 | エラー 2 系統 | Controller 層の `apperror.Error` (4 桁文字列コード。`{"code","msg"}` を返す — `hassan-v2-backend/controller/apperror/error.go:5-11`, `hassan-v2-backend/controller/controller.go:105-125`) と UseCase 層の `constants.CodedError` (`hassan-v2-backend/constants/errors.go`) |
| F-8 | コード → HTTP 変換 | **controller ごとの手書き**。`hassan-v2-backend/controller/asset.go:161-174` は `if` の連鎖、`hassan-v2-backend/controller/idea_board.go:554-576` は集約ヘルパー `handleIdeaBoardError` の switch。**両方式が併存** |
| F-9 | 404/403 の本文 | `notFound()` / `forbidden()` / `internalServerError()` は**ボディ無し** (`hassan-v2-backend/controller/controller.go:42-70`)。`badRequest()` / `conflict()` のみ `{"code","msg"}` を返す (`同:83-125`) |
| F-10 | ページネーション | `limit` / `offset` でおおむね統一 (`hassan-v2-backend/controller/asset.go:79-96`)。**`limit` 未指定は「全件取得」** (`同:79` のコメント `limit が 0 の場合は全て取得する`)。ソートパラメータは無い。検索は `keyword` (`同:75`) |
| F-11 | SSE | 共通ヘルパーが既にある: `SetupSSEHeaders` / `SendSSEMessage` / `SendSSEError` (`hassan-v2-backend/controller/controller.go:128`, `:143`, `:172`)。使用例は企画書生成ジョブ (`hassan-v2-backend/controller/business_plan.go:154`) とリサーチ (`hassan-v2-backend/controller/research.go:207`) |
| F-12 | OpenAPI 生成 | ハンドラ直上の swag アノテーション → `swag init --parseDependency ./main.go` (`hassan-v2-backend/Makefile:31-33`)。`/swagger/*any` は **`AppEnv != "prod"` のみ登録** (`hassan-v2-backend/router/router.go:32-38`) |
| F-13 | orval の入力 | **稼働中サーバの URL** を読む: `input.target: 'http://localhost:8081/swagger/doc.json'` (`hassan-v2-frontend/orval.config.js`)。出力は `tags-split` / `client: fetch` / mutator `src/lib/api-client.ts` |
| F-14 | CORS 許可 | **ハードコードされた固定リスト** (`hassan-v2-backend/internal/corsutil/origin.go` の `productionWebOrigins`)。local/dev のみ localhost を追加許可 (`hassan-v2-backend/router/router.go:249`) |
| F-15 | 一覧の所有者絞り込み | `GET /themes` と `GET /assets` は **`account_id` クエリを受け取る** (`hassan-v2-backend/controller/theme.go:46-53`, `hassan-v2-backend/controller/asset.go:102`)。`sharing_settings` が有効なら他人の ID を指定できる |
| F-16 | **契約スコープのゲート** | 契約内の他人のデータを見られるかは **`sharing_settings(contract_id, category, is_shared)`** が決める (PK は `(contract_id, category)`。`hassan-v2-backend/db/schema.sql:491-499`)。**レコード未作成時は `false` 扱い = 既定は非共有** (`hassan-v2-backend/usecase/theme/list_themes.go:42-44` のコメント) |

**F-15 の重大な非対称**: アセット側は契約一致を検証する
(`hassan-v2-backend/usecase/asset/list_assets.go:60-66` — `input.ContractID != account.ContractID` なら
`AccountNotFound`)。**テーマ側は検証しない** (`hassan-v2-backend/usecase/theme/list_themes.go:56-62` は
`GetAccountByID` の存在確認のみ。当該クエリは `SELECT * FROM accounts WHERE id = $1`
— `hassan-v2-backend/db/queries/account.sql:1-2`)。結果として v2 では、
**自契約でアイデア共有が有効な場合に `GET /themes?account_id=<他契約のアカウント UUID>` が
他契約のテーマを返し得る**。v3 でこの入力形を再現しない (§2 の D-API-8)。

**F-16 の適用のされ方** (v3 の `scope` 設計の前提 — D-API-8):

| 対象 | 挙動 | 出典 |
|---|---|---|
| テーマ一覧 | `is_shared == false` なら絞り込み対象を**認証ユーザーに強制**し、契約スコープ経路に入れない (エラーにしない) | `hassan-v2-backend/usecase/theme/list_themes.go:42-52` |
| アセット一覧 | `(契約スコープ or 他人指定) && !is_shared` なら `SharingSettingDisabled` → Controller が **403** | `hassan-v2-backend/usecase/asset/list_assets.go:71-79`、`hassan-v2-backend/controller/asset.go:119-120` |
| ボード一覧 | **共有された viewer/editor は `sharing_settings` をバイパスする** (`restrictToSelf` は「非共有かつ自分が作成者」のときだけ true) | `hassan-v2-backend/usecase/idea_board/list_idea_boards.go:44-47` |

つまり **v2 には契約 × カテゴリ単位の共有スイッチが実在し、既定は OFF**。
v3 が `scope=contract` を無条件に許すと、**切替と同時に非共有だった契約のデータが契約内に露出する** (DR-3)。
この帰結への対応が D-API-8 の増分ゲート。

### 1.2 v3 の決定 (共通規約)

**判断が割れた場合は v2 の既存規約に寄せる**という方針 (ルート `CLAUDE.md`) を適用し、
逸脱には却下案と理由を書く。

| # | 論点 | 採用案 | 却下案と理由 |
|---|---|---|---|
| D-API-1 | ベースパス / バージョニング | **ルート直下・バージョンプレフィックス無し** (v2 の F-1 準拠)。ホスト名で v2 API と v3 API を区別し、OpenAPI の `servers` に環境別ホストを書く | (a) `/api/v1` を付ける: v3 は全面切替 (C-11) が前提で API の複数バージョン併存計画が無いため、運用されないバージョン軸を URL に固定してしまう。(b) `/v3` を付ける: 製品世代を API パスに埋め込むと次世代で必ず嘘になる。**ただし v2 と v3 を同一ドメインに相乗りさせる構成に決まった場合、`/themes` 等が v2 と衝突する** — その場合のみ v3 側に `/v3` を付ける (要確認 **API-Q1**) |
| D-API-2 | パス命名 | **kebab-case + 複数形**に統一。パスパラメータは常に `{<単数リソース名>_id}` (`{theme_id}` `{asset_id}` `{board_id}`)。ネストは 2 段まで | (a) v2 の現状踏襲 (F-2): `/company-mission` `/event_logs` `:id`/`:hassan_id` の不統一がそのまま orval 生成関数名の揺れになり、実装者が毎回既存例を探す。(b) `{id}` で統一: ネスト時 (`/idea-boards/{id}/items/{id}`) に衝突し、gin がルートを登録できない |
| D-API-3 | 認証の適用方式 | **要求する認証系統をパスごとに宣言し、CI が系統単位の一致を検査する** ([../auth.md](../auth.md) §6.7 が SSOT。**公開 / ユーザー認証 / 社内管理者認証 / 社内管理者認証 (MFA 未検証で可) の 4 系統**)。**v3 の公開エンドポイントは `GET /alive` に加え、認証系 API (`signin` / `signup` / パスワードリセット 2 本 / 招待リンク取得 / `POST /admin/signin`) がある** — 認証系を v3 で実装する決定 (同 §9.3 Q-A8) の帰結。**本ディレクトリには公開エンドポイントは無い**。`X-Token` ヘッダ + JWT ([../auth.md](../auth.md) §6.1) | (a) v2 のルート個別指定 (F-3): 追加時の書き忘れが「素通り」として現れ、機械検出手段が無い ([../auth.md](../auth.md) §5-5)。**AC-1.1 を「実装者が気をつける」に落とすため不可** |
| D-API-4 | 単一リソースのレスポンス | **裸オブジェクト** (v2 の F-5 準拠)。JSON キーは **snake_case** | (a) `{data: {...}}` エンベロープ: v2 のどの経路とも異なり、v2 API と併用する FE (settings) が 2 形式を扱うことになる |
| D-API-5 | 一覧レスポンス | **`{"items": [...], "total_count": N}` に統一**。キー名は常に `items` | (a) リソース名キー (`{assets: []}` — v2 の F-6 ①): FE のページネーション処理を共通化できず、ドメインごとに同型のコードが増える。(b) 裸配列 (F-6 ②): `total_count` を返せず、後からページネーションを足すと**破壊的変更**になる。(c) `{"ideas","total","filter"}` (F-6 ③): 一覧に状態 (filter) を混ぜており、キャッシュ単位が曖昧になる |
| D-API-6 | エラーレスポンス | **`CodedError` 1 系統**に統一し、**Controller 層に「CodedError → HTTP ステータス」の単一マッピングテーブル**を置く。本文は `{"code":"<文字列コード>","message":"<表示文言>","request_id":"<リクエスト ID>"}`。**404 / 403 も本文を返す** ([../auth.md](../auth.md) §6.6 の表と整合) | (a) v2 の 2 系統維持 (F-7): 変換が controller ごとの手書きになり、v2 では既に 2 方式が併存している (F-8)。(b) `apperror` 側に寄せる: UseCase 層が controller パッケージに依存し、層の依存方向 ([../architecture.md](../architecture.md) §3 責務表) に違反する。(c) 404/403 をボディ無しにする (F-9): FE がエラー種別を判別できず、v2 では「どのリソースが無いのか」がログにしか出ない |
| D-API-7 | ページネーション | **`limit` / `offset`** (v2 準拠)。**既定 `limit=50` / 最大 `limit=200`**。`limit=0` は「全件」として扱わず 400。**既定値・上限値の SSOT は backend の定数 1 箇所**とし、OpenAPI の `default`/`maximum` に反映して orval 経由で FE に伝播させる (BE-2) | (a) v2 の `limit` 未指定 = 全件 (F-10): データ増加でレイテンシが静かに劣化し、既定が最悪ケースになる。(b) カーソルページネーション: 「◯件目まで」の表示 (プロトタイプの一覧に件数表示がある) と相性が悪く、v2 に前例が無い。(c) 既定値を FE と prompts にも書く: BE-2 (hard cap の 3 層散在) の再発 |
| D-API-8 | 一覧の絞り込みパラメータ | **`account_id` パラメータを置かない**。代わりに **`scope=mine\|contract`** (列挙値・既定 `mine`) を使う。契約スコープでの作成者絞り込みが必要な場合のみ `created_by=<列挙されたメンバー ID>` を許すが、**サーバが必ず自契約メンバーであることを検証**する | (a) v2 の `account_id` クエリ踏襲 (F-15): テーマ側に契約一致検証が無く**他契約のデータが読める入力形**であり、同じ形を持ち込むと同じ検証漏れを招く。(b) `scope` を持たず常に個人スコープ: v2 の `idea_boards` は契約単位で共有されており ([../auth.md](../auth.md) §2.2)、既存データを表現できない |
| D-API-8' | **`scope=contract` を許す条件** | **テーマ / アセット / アイデアの `scope=contract` は増分 1 から有効化**する (**2026-08-02 改訂。旧「増分 2」を撤回**。[../auth.md](../auth.md) §6.12 (c) / [../data-model.md](../data-model.md) DM-9 が「per-resource `visibility` 列と、その書き込み API はどちらも増分 1」と改訂したことに追随する。理由 = C-16 — v2 の `POST /sharing-settings` でできていた「共有の切り替え」を増分で落とさない)。**per-resource の `visibility` (`private`\|`contract`。既定 `private`) を判定条件**とし、`scope=contract` は「`visibility=contract` のリソース + 自分のリソース」を返す。**増分 2 に残るのはテーマメンバー機能 (`GET`/`PUT /themes/{theme_id}/members`) のみ**。**アイデアボードは対象外** (v2 の既存メンバーシップで可視性が決まる — F-16 の 3 行目 / [idea-boards.md](idea-boards.md) D-IB-11) | (a) 増分 1 から `scope=contract` を無条件に許す (**当初案・却下**): 増分 1 に絞り込む属性 (`visibility`) が無いままだと契約内の全テーマ・全アセットが露出する。v2 の既定が非共有 (F-16) なので**切替が一斉公開になる** (DR-3)。**列と書き込み API をどちらも増分 1 に含めることでこの懸念を解消した** (既定値 `private` により露出しない)。(b) v2 の `sharing_settings` (契約 × カテゴリの ON/OFF) を v3 に引き継ぐ: 粒度が「契約 × カテゴリ」しかなく、プロトタイプが要求する**テーマ 1 件ごとの可視性** ([themes.md](themes.md) D-TH-3) を表現できない。既存値の扱いは (c) で吸収する。(c) 移行方針: **v2 の `sharing_settings` が ON の契約は、移行時に既存テーマ・アセットの `visibility` を `contract` に、OFF の契約は `private` に設定する** — これにより切替前後で見える範囲が変わらない ([themes.md](themes.md) §3.2 / [assets.md](assets.md) §3.2)。(d) 列は増分 1・書き込み API は増分 2 (**旧案・撤回**): 増分 1 で作られたリソースの既定値決定が増分 2 まで宙に浮き、二重管理になる |
| D-API-9 | ソート | **`sort=<フィールド>:<asc\|desc>`**。許可値はエンドポイントごとのホワイトリストで、範囲外は 400 | (a) v2 準拠でソート無し (F-10): プロトタイプに並べ替え UI がある (**2026-07-30 更新版ではアセット一覧のソート UI は消えたが、ナレッジのファイル一覧 `:14059-14063` とボード詳細 `:12261` に並び順 select が現存**) ため、FE 側の全件取得ソートになり D-API-7 と矛盾する。(b) 任意フィールドを許可: インデックスの無い列でのソートが本番の遅延要因になる |
| D-API-10 | 検索 | **`keyword`** (v2 準拠 F-10)。**部分一致の対象フィールドをエンドポイントごとに明記**する | (a) `q` にする: v2 との差分に意味が無い。(b) 検索対象を書かない: 「テーマ名・ミッション・主要アセット名・メンバー名」を検索するプロトタイプ挙動 (`hassan_agent_prototype_v2.html:10816-10821`) が実装者判断になる (DR-5) |
| D-API-11 | 作成・更新・削除の応答 | **作成 201 + 本文にリソース / 更新 200 + 本文にリソース / 削除 204 本文なし** | (a) v2 の `success(c)` (200 ボディ無し) 踏襲: 作成後に FE が採番された ID を得るため追加の GET が必要になる |
| D-API-12 | SSE | **v2 の共通ヘルパー (F-11) を踏襲**し、`SetupSSEHeaders` 相当を v3 の Controller 共通層に置く。**ストリーム開始後のエラーは HTTP ステータスで表現できないため、SSE の `error` イベントで送って接続を正常終了させる** ([../architecture.md](../architecture.md) §3 の「迷いやすい 3 点」3 = `architecture.md:159-161` の決定に従う)。したがって各表の「固有ステータス」列は**ストリーム開始前の失敗のみ**を表す。**イベント名・再接続・タイムアウトの仕様は [../observability.md](../observability.md) §4.3 (F-5) / §4.4 / §4.4.1 (O-5) に委譲**。本ディレクトリは**どのエンドポイントが SSE か**を表で明示する | (a) WebSocket: v2・PoC の双方に前例が無く、ALB / Vercel 側の設定が増える。(b) ポーリング: PoC の 4 ターン表示 (plan/action/observation/thought) の体験を再現できない。(c) ストリーム開始後の失敗を HTTP ステータスで返す: 200 とヘッダを既に送出済みのため**技術的に不可能** |
| D-API-13 | OpenAPI → orval | **swag アノテーションを正**とし (F-12 準拠)、**生成した `docs/swagger.json` をリポジトリにコミット**する。orval は**コミットされた JSON ファイルを入力**にする。CI で「再生成して差分が出たら落とす」を D-2 のマージ条件に入れる | (a) v2 方式 (稼働サーバから取得 — F-13): **CI が型生成の漏れを検知できず**、FE 開発者は BE をローカル起動しないと型を更新できない。(b) OpenAPI YAML を手書き (spec-first): 型の二重管理になり、v2 の実装者の慣れとアノテーション資産を捨てる |
| D-API-14 | ファイルアップロード | **`multipart/form-data`** (v2 の前例: `c.FormFile("file")` — `hassan-v2-backend/controller/asset.go:485`, `hassan-v2-backend/controller/account.go:747`)。**許可拡張子・サイズ上限の SSOT はサーバ側定数 1 箇所** (BE-2) | (a) ブラウザから S3 への署名付き直接アップロード: 転送は速いが、拡張子・サイズ検証がクライアント任せになり、検証の SSOT が消える |
| D-API-14' | **ファイルの保存と配布** | **非公開バケット + ACL を付けない + GET は署名付き URL (presigned URL) のみ**。`expires_at` を必ず返し、**有効期限の既定値はサーバ側定数 1 箇所** (D-API-7 と同じ SSOT)。**これは v2 に前例が無い新規実装**である | (a) **v2 方式の踏襲 (明示的な逸脱の対象)**: v2 の `uploadFile` は `ACL: types.ObjectCannedACLPublicRead` を付け (`hassan-v2-backend/aws/s3.go:46`)、`https://<bucket>.s3.amazonaws.com/<key>` という**恒久・無署名の URL を返す** (`同:58`)。v2 での用途はアイコン (`同:62-65`) と企画書サムネイル (`同:68-71`) という**公開前提の画像**であり、v3 が置くヒアリング議事録・技術資料・アセット添付は機密データ。**同じ実装を流用すると URL を知る誰でも認証なしで読める** ([../auth.md](../auth.md) §2.2 の `asset_documents` がテナント境界の外にある問題を、ストレージ層で新規に作ることになる)。**`Presign` の参照は v2 の本体コードに 0 件** (grep) のため、実装は新規に書く必要がある (§6.2) |
| D-API-15 | **非同期ジョブ (202 / `processing`)** | **§1.3 で定義する** (実行主体・状態機械・回収・再実行・進捗配信)。該当は [assets.md](assets.md) の `asset-extractions` と [knowledge.md](knowledge.md) の `knowledge-files` の 2 系統 | §1.3 に併記 (J-1〜J-7 の各行が却下案を持つ) |

### 1.3 非同期ジョブの共通仕様 (D-API-15)

**本節が回答する ID: O-5 (実行基盤の部分), O-4** — 設計入力
[design_memo.md](../design_memo.md) の `:133` (「ワーカー分離は初期不要」) と
`:136` (「PoC の status 状態機械 + **失敗時再実行の保証** (デプロイで処理が死んでも復旧可能)。
**ジョブキューは初期導入しない**」) への回答。

| # | 論点 | 決定 | 却下案と理由 |
|---|---|---|---|
| J-1 | 実行主体 | **BE プロセス内の goroutine** で実行する。**ジョブキュー (SQS 等) とワーカーサービスは初期導入しない** (`design_memo.md:133,136` の明示指定) | (a) SQS + 専用ワーカー: 初期の負荷 (エージェント実行は Anthropic 側) に対して運用対象が 1 つ増える。**指定に反する** |
| J-2 | 状態の SSOT | **DB の `status` 列 (状態機械)**。`queued` → `running` → `succeeded` / `failed`。**プロセスのメモリ上の状態を正にしない** | (a) メモリ上の進捗マップを正にする: プロセスが消えると状態が消え、`GET` が「存在しないジョブ」を返す |
| J-3 | **取り残されたジョブの回収** | **`running` / `processing` の `updated_at` を heartbeat として更新**し、**閾値 (既定 15 分) を超えたものを `failed` (`failure.code = stale_aborted`) に落とす**。判定は **①プロセス起動時に 1 回 ②定期実行 (既定 1 分間隔)** の 2 経路。閾値・間隔はサーバ側定数 1 箇所 (BE-2) | (a) 回収しない (**当初案の欠落**): ECS のローリング更新 (D-3) でプロセスが消えたジョブが**永久に `running` のまま残り**、UI が回り続ける。`design_memo.md:136` が名指しで要求している「デプロイで処理が死んでも復旧可能」に反する。(b) 起動時のみ回収: タスクが落ちて再起動しない場合 (スケールイン) に回収されない |
| J-4 | 再実行 | **明示的なリトライ経路を持つ**。`failed` のジョブに対する再実行は**同じジョブを再利用せず新しいジョブを作る** ([assets.md](assets.md) は `POST /asset-extractions` を再度呼ぶ、[knowledge.md](knowledge.md) は**同じファイルの再アップロード** (`POST /knowledge-files`) — 専用の再実行エンドポイントは設けない (knowledge.md D-KN-9))。**自動リトライは行わない** | (a) サーバが自動で再試行: LLM 呼び出しは課金を伴い、同一 deadline を共有した再試行が `context deadline exceeded` を誘発した PoC の実例がある (BE-6)。(b) 同じジョブ行を `queued` に戻す: 失敗の履歴が上書きされ、何回失敗したかが追えなくなる (O-4) |
| J-5 | 冪等性 | ジョブ作成時に **`idempotency_key` (ソースのハッシュ + 種別) を保存**し、`queued` / `running` の同一キーが存在する場合は**新規作成せず既存のジョブを返す** (200)。結果の確定書き込み (`POST /assets`) 側は `extraction_id` の一意制約で二重登録を防ぐ | (a) 冪等キーなし: ユーザーの二重クリックで同じ PDF に対する抽出が 2 本走り、LLM コストが倍になる。(b) 採番の固定 Insert に頼る: BE-11 (ver 固定 Insert の UNIQUE 違反によるサイレント失敗) の再発形 |
| J-6 | **SSE 進捗の配信** | **SSE ハンドラは DB の状態 (`status` / `progress` / 進捗イベント行) をポーリングして配信する**。ジョブを実行している goroutine と SSE 接続が**同一プロセスにいることを前提にしない** | (a) 実行中の goroutine から直接チャネルで配信 (単一タスク前提): ALB が SSE 接続を**ジョブが走っていないタスクに振ると進捗が一生流れない**。[../architecture.md](../architecture.md) §8 のとおり v3 のタスク数は未決であり、`desiredCount 1` を設計の前提にできない。(b) スティッキーセッションで同一タスクに固定: ALB の設定依存が増え、タスク入れ替え時に結局切れる |
| J-7 | 切断時の回復 | **状態 GET + 再接続**。SSE は進捗表示専用であり、**結果の唯一の受け取り口ではない** (`design_memo.md:135` の「会話履歴 GET で復元 + 再接続」と同じ方針) | (a) SSE のみで結果を返す: 切断で結果が失われる (O-5) |

**先送り**: 定期実行の仕組み (アプリ内 ticker か ECS スケジュールタスクか)・heartbeat 閾値の最終値・
アラート条件は [operations.md](../operations.md) と [observability.md](../observability.md) が担う。
**API の契約 (`status` の値域・`failure.code` の存在・再実行の経路) は本節で確定**しており、
実行基盤の選択で変わらない。

#### 1.3.1 会話ターンと企画書の生成系は J-1〜J-7 の適用外 (2026-08-01 追加 / 2026-08-02 に企画書 3 本を追加)

**J-1〜J-7 は「投げっぱなしの非同期ジョブ」の規約**であり、`asset-extractions` と `knowledge-files` の
2 系統を対象にしている (D-API-15)。**会話ターン (`POST /conversations/{session_id}/messages`) はこれに含まれない**。

| 項目 | 会話ターンの扱い |
|---|---|
| 形式 | **同期 SSE**。1 リクエスト = 1 ターンで、**実行がユーザーの待機と一致する** (投げっぱなしにしない) |
| **J-6 (SSE ハンドラが DB をポーリング)** | **対象外**。**SSE を返すリクエスト自身がターンを実行する**ため、「ジョブが走っていないタスクに SSE 接続が振られる」という J-6 が防いでいる事象が起こり得ない |
| **J-7 (結果の受け取り口を SSE 以外にも持つ)** | **満たす**。切断時は `GET /conversations/{session_id}` (台帳) と `GET /conversations/{session_id}/messages?after_seq=` (履歴) から回復する |
| 同時実行 | ジョブの再実行ではなく、**同一セッションへの並行ターンを 409 で拒否**する (`data-model.md` の DM-13) |

**企画書ドメインの SSE 3 本も同じ扱い** (2026-08-02 追加。[plans.md](plans.md) §12 の R-PL-9):
`POST /plans/{plan_id}/generate` / `POST /plans/{plan_id}/tabs/{tab_id}/regenerate` /
`POST /plans/{plan_id}/chat/messages` は**いずれも同期 SSE** であり、**J-6 の対象外・J-7 は満たす**。

| 項目 | 企画書 3 本の扱い |
|---|---|
| **J-6** | **対象外** (会話ターンと同じ理由 — SSE を返すリクエスト自身が生成を実行する) |
| **J-7** | **満たす**。切断時は `GET /plans/{plan_id}` (8 タブの最新版) と `GET /plans/{plan_id}/chat/messages?after_seq=` から回復する |
| 同時実行 | **企画書あたり 1 本**に制限し、競合は 409 ([plans.md](plans.md) §13 の PL-R7) |
| 保存の粒度 | **タブ 1 件の保存 = 1 トランザクション** ([../data-model.md](../data-model.md) §4.11.1 の規約 5。2026-08-02 改訂) — 打ち切り時にそこまでのタブが残る |

**この節がある理由**: 規約からの逸脱を無言で行わないため
([conversation.md](conversation.md) §7 の D-CV-2 / 同 §8 の R-CVA-6)。
**新しい SSE 経路を足すときは、J-1〜J-7 に載せるか本節の例外に該当するかを設計時に明示する**。

### 1.4 機械強制 (規約を「気をつける」に落とさないための CI 検査)

D-API-3 / D-API-5 / D-API-6 / D-API-7 / D-API-8 は宣言だけでは守られない。
**実装リポの CI で検査する** (D-2 のマージ条件)。
D-API-13 で `swagger.json` をコミットするため、**下表の多くはコミット済み JSON への検査として実装できる**。

| 検査 | 内容 | 対応する決定 |
|---|---|---|
| 公開ルートのホワイトリスト照合 | 認証グループ外に登録されたルートが、ホワイトリスト (1 箇所) に列挙されたパスのみであること | D-API-3 / AC-1.1 |
| エラーコードの網羅 | `CodedError` の全コードが「コード → HTTP ステータス」マッピングに登録されていること (未登録は 500 に落ちるため、漏れを検知する) | D-API-6 |
| 所有者引数の強制 | `db/queries/*.sql` の **`-- name: Get*` / `List*` / `Count*` / `Search*`** に所有者条件があること。**例外は [../auth.md](../auth.md) §6.4 の許可リスト (7 種) に列挙されたものだけ** — 同節の機械強制と同一の検査。**`Get*` のみを見る形にしない** (v2 で実測された越境は一覧・集計系にも現れる。F-15) | AC-1.2 |
| **所有者 ID の生成経路** | 専用型 `AccountID` / `ContractID` が **①認証コンテキスト由来** または **②契約検証を通したコンストラクタ** の 2 経路でのみ生成されること (リクエストパラメータからの直接キャストを弾く)。**F-15 型の越境は SQL 側では検出できない** — クエリは所有者条件を持っており、渡す値が呼び出し元の所有者でないことが問題だから ([../auth.md](../auth.md) §6.4) | AC-1.2 |
| **`account_id` クエリの禁止** | `swagger.json` の全 query パラメータに `account_id` が現れないこと。**許可リストは `GET /activity-logs` の 1 本のみ** (契約内管理者限定 + 自契約検証あり)。**最も事故が大きい規約なので機械検査を必須にする** (F-15 の再発防止) | **D-API-8** |
| **一覧レスポンス形の統一** | `swagger.json` の 200 レスポンススキーマのうち配列を返すものが `{items, total_count}` の形であること (裸配列・リソース名キーを弾く) | D-API-5 |
| **パスパラメータの命名** | ルート定義のパスパラメータが `{<単数リソース名>_id}` に一致すること (`{id}` を弾く正規表現検査) | D-API-2 |
| **`scope` の値域** | `scope` パラメータの enum が `mine` / `contract` のみであること。**テーマ / アセット / アイデアは増分 1 から `contract` を受け付ける** (2026-08-02 改訂)。**増分 2 に残るのはテーマメンバー機能 (`GET`/`PUT /themes/{theme_id}/members`) のみ**であり、増分 1 ではこの 2 本自体を実装・登録しないことを UT で担保する | D-API-8' |
| swagger 再生成差分 | `swag init` の結果が commit 済み JSON と一致すること | D-API-13 |

---

## 2. 認証・スコープ・ステータスコードの共通規約

**本節が回答する ID: A-1, A-2, A-4, A-5** (AC-1.1 / AC-1.4)

### 2.1 認証 (A-1 / AC-1.1)

- 本ディレクトリの**全エンドポイントが認証必須**。`X-Token` ヘッダの JWT を検証する
  ([../auth.md](../auth.md) §6.1)。適用は**グループ既定** (D-API-3)
- **本ディレクトリに公開エンドポイントは無い** (全エンドポイントが認証必須)。v3 全体の公開エンドポイントは `GET /alive` + 認証系 API であり、一覧と系統別の検査は [../auth.md](../auth.md) §6.7 が SSOT
- 未認証・トークン不正・期限切れ・アカウント不存在・ロック済み・MFA 未検証は**すべて 401 (本文なし)**
  ([../auth.md](../auth.md) §6.6)

### 2.2 ロール (A-2)

対象ロールは **`AuthRoleUser` (一般ユーザー) のみ** ([../auth.md](../auth.md) §6.2)。
社内管理者 (`X-Admin-Token`) 向けエンドポイントは本ディレクトリに作らない。

ただし**権限が「認証ロール」以外で決まる操作が 2 系統ある**。どちらも 403 の用途 (§2.5)。

| # | 系統 | 判定の根拠 | 該当 | v2 の前例 |
|---|---|---|---|---|
| R-1 | **契約内の管理者/メンバー区別** (`accounts.auth_role_id`) | `authAccount.AuthRoleID.IsAdmin()` | [settings.md](settings.md) §3.1 の **3 本** (`PUT /settings/workspace` / `GET /usage-summary` / `GET /activity-logs`) | `hassan-v2-backend/controller/event_logs.go:47-50` が同じ判定で `forbidden(ctx, apperror.RequestUserNotAdmin())` を返す。ロール定義は `hassan-v2-backend/entity/auth_role.go:7-10` (1 = 管理者 / 2 = メンバー) |
| R-2 | **リソース単位のロール / 投稿者 / 所有者** | ボード内ロール (`admin` / `editor` / `viewer`) とコメント投稿者 / **アイデアの所有者かどうか** | [idea-boards.md](idea-boards.md) §3.1 の権限表 (**8 本** = admin 限定 3 + 投稿者限定 1 + viewer の編集操作 4) + [ideas.md](ideas.md) §1.3 の**5 本** (共有ボード経由や `visibility=contract` で見えるだけの相手による書き込みを拒否。所有者のみ可) = **合計 13 本** | `hassan-v2-backend/entity/idea_board.go:14-16` (3 ロール)、`同:118-121` (`CanEdit` = admin か editor)、`同:124-126` (`IsAdmin`)。違反時は `IdeaBoardForbidden` (`hassan-v2-backend/usecase/idea_board/update_board_idea.go:47`) |

**R-1 は [../auth.md](../auth.md) §9 の Q-A2 (契約内管理者/メンバー区別を v3 で使うか) への回答**であり、
**「使う。ただし用途は R-1 の 3 本に限る」**を提案する (詳細は [settings.md](settings.md) §3.1)。

**R-2 は認証ロールではなくリソースの所有権・共有関係で決まる**ため、`AuthRoleUser` のみという
A-2 の方針と矛盾しない (認証は全員 `AuthRoleUser`、その上でリソースごとの権限を評価する)。

### 2.3 所有者スコープ (A-4 / AC-1.2)

- Controller が `GetAuthenticatedAccount` から `account_id` / `contract_id` を取り出し UseCase の Input に詰める
- **UseCase がスコープを確定**し、Repository のクエリ条件に必ず渡す ([../auth.md](../auth.md) §6.4)
- 一覧 API のスコープ指定は **`scope=mine|contract` の列挙値のみ** (D-API-8)。
  **クライアントが任意の `account_id` を渡せる入力形を作らない**
- **`scope=contract` はテーマ / アセット / アイデアで増分 1 から有効化する** (D-API-8'。2026-08-02 改訂)。
  `visibility` (既定 `private`) が契約内露出を防ぐため、無条件許可による一斉公開 (DR-3) は起きない。
  **増分 2 に残るのはテーマメンバー機能のみ**

各エンドポイント表の「スコープ」列の意味:

| 表記 | 意味 |
|---|---|
| **個人** | `WHERE account_id = <認証ユーザー>` のみ。他人のデータは 404 |
| **契約** | `WHERE contract_id = <認証ユーザーの契約>`。契約内の他メンバーのデータを含む。**アイデアボードはさらにメンバーシップで絞る** ([idea-boards.md](idea-boards.md) D-IB-11) |
| **個人 / 契約 (増分 2)** | `scope` パラメータで切り替わる。既定は **個人**。**テーマ / アセット / アイデアは増分 1 から `contract` を受け付ける** (D-API-8')。この表記のまま残る増分 2 の対象はテーマメンバー機能のみ |

### 2.4 LLM 経路のスコープ (A-6 / AC-1.3)

LLM を伴うエンドポイント (表の「LLM」列が ✓) は、**外部 API 呼び出しを `gateway/<プロバイダ>` に置き、
ツールループ (Agent 経路) を `service/conversation.Runner` が持つ**構造で実行する
([../architecture.md](../architecture.md) §3.8。責務表は同 §3.3)。
**Controller / UseCase から LLM SDK を直接呼ばない**。
**ツールや検索に渡すスコープは UseCase が確定した `account_id` を使い、
LLM が生成した ID を所有者の根拠にしない** — スコープは
**`usecase/<domain>` が組み立てるツールハンドラのクロージャに束縛**され、
Runner が組み替えられない構造になっている ([../architecture.md](../architecture.md) §3.8.2)。
スコープ違反は「該当なし」として扱う ([../auth.md](../auth.md) §6.5)。

RAG 検索のスコープ強制は [knowledge.md](knowledge.md) §4 が詳細を持つ。

### 2.5 ステータスコードの適用一覧 (A-5 / **AC-1.4**)

**判定規則の SSOT は [../auth.md](../auth.md) §6.6**。本節は**エンドポイント類型への適用**を定める
(規則の再掲はしない)。

#### 403 と 404 の判定境界 (これを先に読む)

**判定の基準は「そのリソースが呼び出しユーザーから見えるか (取得できるか)」**。

| 見えるか | 操作権限 | コード | 理由 |
|---|---|---|---|
| **見えない** (所有者条件で 0 件になる) | — | **404** | 存在を漏らさない。他契約・個人スコープの他人のリソースはすべてここ |
| **見える** (取得できる) | 有り | 200 系 | — |
| **見える** (取得できる) | **無い** | **403** | 「あるのは知っているが操作できない」— 隠す意味が無く、403 の方がユーザーに正確 |

**403 は「見えるリソースへの権限不足」の 2 系統のみ** (§2.2 の R-1 / R-2) — **これは 9 ドメイン
(themes / assets / knowledge / idea-boards / news / settings / conversation / ideas / plans) についての規則である**。
**合計 16 本** = [settings.md](settings.md) の 3 本 (R-1) + [idea-boards.md](idea-boards.md) の 8 本 + [ideas.md](ideas.md) の 5 本 (R-2、計 13 本)。
**conversation.md / plans.md に 403 を返すエンドポイントは無い** (会話ターンは個人スコープのみ、企画書は個人スコープのみで見える他人が存在しない)。
**認証・アカウント基盤 ([auth-accounts.md](auth-accounts.md)) は第 3 系統 (R-3 = 不変条件ガード。
「最後の契約内管理者をロック / 降格 / 削除できない」「自分自身をロック / 削除できない」) を持ち、
同書の 403 は 10 本ある** — 系統と本数の SSOT は同書 §3.1。
それ以外のすべての権限エラーは 404 に落ちる — Repository が所有者条件を `WHERE` に持つため
0 件として返り、UseCase が `NotFound` 系 `CodedError` に変換するだけでよい
([../auth.md](../auth.md) §6.6 の帰結)。
**これが v2 の頻出バグ (404 と 403 の取り違え) を構造的に消す** ([../auth.md](../auth.md) §4)。

#### 適用一覧

| 状況 | コード | 本文 | 適用範囲 |
|---|---|---|---|
| `X-Token` 欠落・不正・期限切れ / アカウント不存在・ロック / MFA 未検証 | **401** | なし | **9 ドメイン (themes / assets / knowledge / idea-boards / news / settings / conversation / ideas / plans) の全エンドポイント**。**[auth-accounts.md](auth-accounts.md) は例外** — **トークンの発行・昇格を目的とする経路** (サインイン 2 本 / MFA 検証 2 本) の資格情報不一致を 401 + `CodedError` 本文で返す。**FE の「401 → 強制サインアウト」の分岐は本文のコード接頭辞で切り分ける** (`AU-T-` = 破棄 / `AU-C-` = フォーム内)。規則と値域は同書 §3.1 / §3.1.1 が持つ。**認証済みの状態変更に添える本人確認の不一致 (現在パスワード・MFA 再登録のコード) は 401 ではなく 400** — 下の 400 行に含まれる (同書 AA-D-17) |
| リクエストボディ・クエリのバリデーション違反 (必須欠落・型不一致・`limit` 範囲外・`sort` 許可外・`scope=contract` を増分 1 で指定) | **400** | `CodedError` | 全エンドポイント (D-API-6 / D-API-7 / D-API-8' / D-API-9) |
| **認証済みの状態変更に添える本人確認の不一致** (現在パスワード / MFA 再登録の TOTP コード) | **400** | `CodedError` (`AU-C-00004` / `AU-C-00005`) | **[auth-accounts.md](auth-accounts.md) のみ** (同書 AA-D-17)。**`old_password` / `password` / `totp_code` という送信フィールドに紐づくエラー**なので、401 ではなくフィールドエラーとして扱う |
| パスパラメータが数値/UUID として解釈できない | **400** | `CodedError` | パスパラメータを持つ全エンドポイント |
| **他テナント (他契約) のリソースを指定** | **404** | `CodedError` | ID を受け取る全エンドポイント。**403 にしない** ([../auth.md](../auth.md) §6.6) |
| 自契約だが**個人スコープの他人のリソース**を指定 (取得・更新・削除のいずれも) | **404** | `CodedError` | 個人スコープのドメイン ([themes.md](themes.md) / [assets.md](assets.md) / [knowledge.md](knowledge.md))。**そもそも読めないリソースなので 403 にしない** |
| リソースが実在しない | **404** | `CodedError` | 上 2 行と区別できないのが正しい状態 |
| **契約内管理者限定の操作を一般メンバーが叩いた** (R-1) | **403** | `CodedError` | [settings.md](settings.md) §3.1 の **3 本** |
| **契約スコープで読めるリソースへの、ロール / 投稿者 / 所有者による権限不足** (R-2) | **403** | `CodedError` | [idea-boards.md](idea-boards.md) §3.1 の **8 本** (ボード更新・削除・メンバー変更 = board admin のみ / コメント削除 = 投稿者または board admin / アイテム追加・更新・削除とコメント投稿 = viewer 不可) + [ideas.md](ideas.md) §1.3 の **5 本** (本文・タグ更新・削除・スター更新・版の復元・評価の生成 = 所有者のみ。ボード経由や `visibility=contract` で見えるだけの相手は 403) = **合計 13 本** |
| 一意制約との衝突 (同一アイデアのナレッジスレッド二重作成・テーマ名重複・フェーズ名重複・同一アイデアの二重追加) | **409** | `CodedError` | [knowledge.md](knowledge.md) `POST /knowledge-threads`、[themes.md](themes.md) `POST /themes` / `PUT /themes/{theme_id}`、[idea-boards.md](idea-boards.md) `POST /idea-board-phases` / `PUT /idea-board-phases/{phase_id}` / `POST /idea-boards/{board_id}/items` |
| 削除対象が使用中 (フォルダに配下がある・フェーズが使用中) | **409** | `CodedError` | [assets.md](assets.md) `DELETE /asset-folders/{folder_id}`、[idea-boards.md](idea-boards.md) `DELETE /idea-board-phases/{phase_id}` |
| アップロードの拡張子・サイズ違反 | **400** | `CodedError` | `multipart` を受ける全エンドポイント (D-API-14) |
| 非同期ジョブが未完了の状態で結果を要求 | **200** (状態 `processing` / `running` を本文で返す) | — | [assets.md](assets.md) `GET /asset-extractions/{extraction_id}`、[knowledge.md](knowledge.md) `GET /knowledge-files/{file_id}` (D-API-15) |
| 下流 LLM / 外部サービスの失敗 (**ストリーム開始前**) | **502** | `CodedError` | LLM 列が ✓ のエンドポイントと [news.md](news.md) の CMS 経路。**500 と区別**して外部起因を識別可能にする (O-4) |
| 下流 LLM / 外部サービスの失敗 (**ストリーム開始後**) | **HTTP では表現しない** | SSE の `error` イベント | SSE 列が ✓ のエンドポイント (D-API-12 / [../architecture.md](../architecture.md) §3) |
| **レート制限の超過** | **429** | `CodedError` (`Retry-After` 付き) | **9 ドメインは対象外** (全て認証必須 = §2.1。認証済み経路の暴走抑止は O-3 の安全弁が担う — [../observability.md](../observability.md) §4.4)。**[auth-accounts.md](auth-accounts.md) は 429 を返す (11 本)** — 同書 §3.7 が対象エンドポイントを列挙する (未認証で叩ける 6 本 + MFA 検証 2 本 + 認証済みで資格情報を提示する 3 本)。値と方式の SSOT は [../auth.md](../auth.md) §6.11-3。**403 で返さない** |
| 上記以外のサーバ内部エラー | **500** | `CodedError` | 全エンドポイント |

### 2.6 代表的なリクエスト / レスポンス例

一覧 (D-API-5 / D-API-7 / D-API-8):

```
GET /themes?scope=mine&keyword=超音波&limit=50&offset=0&sort=updated_at:desc
X-Token: <JWT>
```

```json
{
  "items": [
    {
      "id": 12,
      "name": "超音波センシング 新規事業探索 v2",
      "mission": "水素インフラの安全性を非破壊センシングで抜本的に高める",
      "visibility": "private",
      "primary_asset": { "id": 3, "name": "超音波センシング技術" },
      "idea_count": 8,
      "business_plan_count": 2,
      "knowledge_count": 3,
      "updated_at": "2026-07-28T10:12:00Z"
    }
  ],
  "total_count": 8
}
```

エラー (D-API-6):

```json
{
  "code": "TH-E-00002",
  "message": "指定されたテーマは存在しません",
  "request_id": "01J9Z8Q0R7T3V5X7Y9A1B3C5D7"
}
```

> `code` の採番規則 (プレフィックス・桁) は v2 の `hassan-v2-backend/constants/errors.go` の
> 既存規則に合わせる。**新規コードの一覧は実装リポの `constants` パッケージが SSOT** とし、
> 本ディレクトリでは個別コードを列挙しない (二重管理の防止)。

---

## 3. エンドポイント総覧

**合計 149 エンドポイント** = 下表の 9 ドメイン **112 本** + 認証・アカウント基盤
[auth-accounts.md](auth-accounts.md) の **37 本** (同書 §2)。

> **§1・§2 の共通規約が対象にするのは 9 ドメインの 112 本**である (§0 の注)。
> 認証・アカウント基盤は D-ST-1' (2026-07-30) により v3 が実装し、
> **入出力仕様は [auth-accounts.md](auth-accounts.md) で確定した** (2026-07-31。plan.md の **Task-3i**)。
> 工数・依存の見積りでは 37 本を必ず加算すること。

| ドメイン | ファイル | 数 | LLM | SSE | 403 |
|---|---|---|---|---|---|
| テーマ管理 | [themes.md](themes.md) | 9 | 0 | 0 | 0 |
| アセット管理 | [assets.md](assets.md) | **22** | 1 | 1 | 0 |
| ナレッジ (RAG チャット) | [knowledge.md](knowledge.md) | 15 | **2** | 1 | 0 |
| アイデアボード | [idea-boards.md](idea-boards.md) | **18** | 0 | 0 | **8** |
| お知らせ | [news.md](news.md) | 5 | 0 | 0 | 0 |
| 設定 | [settings.md](settings.md) | 6 | 0 | 0 | **3** |
| 会話型アイデア創出 | [conversation.md](conversation.md) | **7** | **1** | **1** | 0 |
| アイデア (参照・人手編集・版・タグ・評価) | [ideas.md](ideas.md) | **13** | **1** | 0 | **5** |
| 企画書 | [plans.md](plans.md) | **17** | **4** | **3** | 0 |
| **小計 (9 ドメイン)** | — | **112** | **9** | **6** | **16** |
| 認証・アカウント基盤 | [auth-accounts.md](auth-accounts.md) | **37** | 0 | 0 | **10** |
| **合計** | — | **149** | **9** | **6** | **26** |

LLM 9 本 = `POST /asset-extractions` / `POST /knowledge-threads/{thread_id}/messages` /
`POST /knowledge-files` (埋め込み生成) / `POST /conversations/{session_id}/messages` (会話ターン) /
`POST /idea-evaluations` / `POST /plans/{plan_id}/generate` / `POST /plans/{plan_id}/tabs/{tab_id}/regenerate` /
`POST /plans/{plan_id}/chat/messages` / `POST /plans/{plan_id}/thumbnail`。
**O-2 の計測対象はこの 9 本** (§4 の O-2 行)。
**認証・アカウント基盤に LLM / SSE 経路は無い** ([auth-accounts.md](auth-accounts.md) §4 の A-6 / O-2 / O-5)。
403 の 16 本 = §2.2 の R-1 (3 本) + R-2 (idea-boards 8 本 + ideas 5 本 = 13 本)。
**認証・アカウント基盤の 10 本は別勘定** = 契約内管理者限定 9 本 + SuperAdmin 限定 1 本 (同書 §2.3 / §2.4)。
**§3.1〜§3.9 は 9 ドメインの内訳**であり、認証・アカウント基盤の一覧は
[auth-accounts.md](auth-accounts.md) §2 が持つ (系統別に 4 節)。

### 3.1 テーマ管理 → [themes.md](themes.md)

| メソッド | パス | 概要 | スコープ | 増分 |
|---|---|---|---|---|
| GET | `/themes` | 一覧 (検索・ステータス絞り込み・ソート) | 個人 / 契約 (増分 1) | 1 |
| GET | `/themes/stats` | 集計サマリ (テーマ / アイデア / 企画書 / ナレッジ件数 — TH-Q6) | 個人 / 契約 (増分 1) | 1 |
| POST | `/themes` | 作成 | 個人 | 1 |
| GET | `/themes/{theme_id}` | 取得 | 個人 / 契約 (増分 1) | 1 |
| PUT | `/themes/{theme_id}` | 更新 | 個人 | 1 |
| DELETE | `/themes/{theme_id}` | 削除 | 個人 | 1 |
| GET | `/themes/{theme_id}/members` | メンバー一覧 | 契約 | 2 |
| PUT | `/themes/{theme_id}/members` | メンバー置換 | 契約 | 2 |
| PUT | `/themes/{theme_id}/visibility` | 可視性変更 | 個人 | 1 |

### 3.2 アセット管理 → [assets.md](assets.md)

| メソッド | パス | 概要 | スコープ | 増分 |
|---|---|---|---|---|
| GET | `/asset-folders` | フォルダツリー取得 | 個人 / 契約 (増分 1) | 1 |
| POST | `/asset-folders` | フォルダ作成 | 個人 | 1 |
| PUT | `/asset-folders/{folder_id}` | フォルダ更新 (改名・移動) | 個人 | 1 |
| DELETE | `/asset-folders/{folder_id}` | フォルダ削除 | 個人 | 1 |
| GET | `/assets` | 一覧 (フォルダ・状態・制作者・検索・ソート) | 個人 / 契約 (増分 1) | 1 |
| POST | `/assets` | 作成 (抽出結果のレビュー確定を含む) | 個人 | 1 |
| GET | `/assets/{asset_id}` | 取得 | 個人 / 契約 (増分 1) | 1 |
| PUT | `/assets/{asset_id}` | 更新 | 個人 | 1 |
| DELETE | `/assets/{asset_id}` | 削除 (論理削除) | 個人 | 1 |
| GET | `/assets/{asset_id}/function-tree` | 機能分解ツリー取得 | 個人 / 契約 (増分 1) | 1 |
| PUT | `/assets/{asset_id}/function-tree` | 機能分解ツリー全体置換 | 個人 | 1 |
| POST | `/asset-extractions` | AI 抽出ジョブ開始 (**LLM**) | 個人 | 1 |
| GET | `/asset-extractions/{extraction_id}` | 抽出ジョブの状態・結果取得 | 個人 | 1 |
| GET | `/asset-extractions/{extraction_id}/stream` | 抽出進捗のストリーム (**SSE**) | 個人 | 1 |
| GET | `/assets/{asset_id}/documents` | 添付資料一覧 | 個人 / 契約 (増分 1) | 1 |
| POST | `/assets/{asset_id}/documents` | 添付資料追加 (multipart) | 個人 | 1 |
| DELETE | `/assets/{asset_id}/documents/{document_id}` | 添付資料削除 | 個人 | 1 |
| POST | `/assets/bulk` | 複数アセットの一括作成 (C-16) | 個人 | 1 |
| DELETE | `/assets/bulk` | 一括削除 (論理削除。C-16) | 個人 | 1 |
| POST | `/asset-imports` | CSV 一括取り込み (v2 の `POST /assets/upload` の後継。C-16) | 個人 | 1 |
| GET | `/asset-imports/{import_id}` | 取り込みの状態・結果取得 | 個人 | 1 |
| GET | `/assets/recent` | 最近使ったアセット (C-16) | 個人 / 契約 (増分 1) | 1 |

### 3.3 ナレッジ → [knowledge.md](knowledge.md)

| メソッド | パス | 概要 | スコープ | 増分 |
|---|---|---|---|---|
| GET | `/knowledge-threads` | スレッド一覧 | 個人 | 1 |
| POST | `/knowledge-threads` | スレッド作成 (通常 / アイデア引継ぎ) | 個人 | 1 |
| GET | `/knowledge-threads/{thread_id}` | スレッド取得 | 個人 | 1 |
| PUT | `/knowledge-threads/{thread_id}` | スレッド更新 (タイトル) | 個人 | 1 |
| DELETE | `/knowledge-threads/{thread_id}` | スレッド削除 | 個人 | 1 |
| GET | `/knowledge-threads/{thread_id}/messages` | メッセージ履歴 | 個人 | 1 |
| POST | `/knowledge-threads/{thread_id}/messages` | 質問送信 (**LLM** / **SSE**) | 個人 | 1 |
| GET | `/knowledge-threads/{thread_id}/files` | スレッドの参照ファイル一覧 | 個人 | 1 |
| PUT | `/knowledge-threads/{thread_id}/files` | 参照ファイルの紐付け置換 | 個人 | 1 |
| GET | `/knowledge-files` | ファイル一覧 (種別・検索・ソート) | 個人 | 1 |
| POST | `/knowledge-files` | ファイルアップロード (multipart。**LLM** = 埋め込み生成) | 個人 | 1 |
| GET | `/knowledge-files/{file_id}` | ファイルメタ取得 | 個人 | 1 |
| GET | `/knowledge-files/{file_id}/download` | 原本ダウンロード (署名 URL 発行) | 個人 | 1 |
| DELETE | `/knowledge-files/{file_id}` | ファイル削除 | 個人 | 1 |
| POST | `/knowledge-files/bulk-delete` | ファイル一括削除 | 個人 | 1 |

### 3.4 アイデアボード → [idea-boards.md](idea-boards.md)

| メソッド | パス | 概要 | スコープ | 増分 |
|---|---|---|---|---|
| GET | `/idea-boards` | ボード一覧 | 契約 | 1 |
| POST | `/idea-boards` | ボード作成 | 契約 | 1 |
| GET | `/idea-boards/{board_id}` | ボード取得 | 契約 | 1 |
| PUT | `/idea-boards/{board_id}` | ボード更新 (名前・説明。**403**: board admin のみ) | 契約 | 1 |
| DELETE | `/idea-boards/{board_id}` | ボード削除 (**403**: board admin のみ) | 契約 | 1 |
| GET | `/idea-boards/{board_id}/items` | ボードアイテム一覧 | 契約 | 1 |
| POST | `/idea-boards/{board_id}/items` | アイデア追加 (**403**: viewer 不可) | 契約 | 1 |
| PUT | `/idea-boards/{board_id}/items/{item_id}` | フェーズ・メモ更新 (**403**: viewer 不可) | 契約 | 1 |
| DELETE | `/idea-boards/{board_id}/items/{item_id}` | アイテム削除 (**403**: viewer 不可) | 契約 | 1 |
| GET | `/idea-boards/{board_id}/items/{item_id}/comments` | コメント一覧 | 契約 | 1 |
| POST | `/idea-boards/{board_id}/items/{item_id}/comments` | コメント投稿 (**403**: viewer 不可) | 契約 | 1 |
| DELETE | `/idea-boards/{board_id}/items/{item_id}/comments/{comment_id}` | コメント削除 (**403**: 投稿者または board admin) | 契約 | 1 |
| GET | `/idea-boards/{board_id}/members` | 共有メンバー一覧 | 契約 | 1 |
| PUT | `/idea-boards/{board_id}/members` | 共有メンバー置換 (**403**: board admin のみ) | 契約 | 1 |
| GET | `/idea-board-phases` | フェーズマスタ一覧 | 契約 | 1 |
| POST | `/idea-board-phases` | フェーズ作成 | 契約 | 1 |
| PUT | `/idea-board-phases/{phase_id}` | フェーズ更新 | 契約 | 1 |
| DELETE | `/idea-board-phases/{phase_id}` | フェーズ削除 | 契約 | 1 |

### 3.5 お知らせ → [news.md](news.md)

| メソッド | パス | 概要 | スコープ | 増分 |
|---|---|---|---|---|
| GET | `/news` | 一覧 (カテゴリ・未読絞り込み、既読状態を結合) | 個人 | 1 |
| GET | `/news/{news_id}` | 詳細 (既読化しない) | 個人 | 1 |
| POST | `/news/{news_id}/read` | 既読化 | 個人 | 1 |
| POST | `/news/read-all` | すべて既読化 | 個人 | 1 |
| GET | `/news/unread-count` | 未読件数 (ナビバッジ) | 個人 | 1 |

### 3.6 設定 → [settings.md](settings.md)

| メソッド | パス | 概要 | スコープ | 増分 |
|---|---|---|---|---|
| GET | `/settings/notifications` | 通知設定取得 | 個人 | 1 |
| PUT | `/settings/notifications` | 通知設定更新 | 個人 | 1 |
| GET | `/settings/workspace` | v3 側ワークスペース設定取得 (アセット可視性の既定 — ST-Q8) | 契約 | **2** |
| PUT | `/settings/workspace` | v3 側ワークスペース設定更新 (**契約内管理者のみ / 403**) | 契約 | **2** |
| GET | `/usage-summary` | 契約の利用量集計 (月 × メンバー × 活動種別のクロス集計 — ST-Q9。**契約内管理者のみ / 403**) | 契約 | 1 |
| GET | `/activity-logs` | 契約の活動ログ一覧 (**契約内管理者のみ / 403**) | 契約 | 1 |

### 3.7 会話型アイデア創出 → [conversation.md](conversation.md)

| メソッド | パス | 概要 | スコープ | 増分 |
|---|---|---|---|---|
| POST | `/conversations` | 会話セッション作成 | 個人 | 1 |
| GET | `/conversations` | 一覧 | 個人 | 1 |
| GET | `/conversations/{session_id}` | 取得 (台帳 + `stage` を同梱。切断時の回復経路①) | 個人 | 1 |
| PUT | `/conversations/{session_id}` | タイトル更新 | 個人 | 1 |
| DELETE | `/conversations/{session_id}` | 削除 (論理削除) | 個人 | 1 |
| POST | `/conversations/{session_id}/messages` | 会話ターンの実行 (**同期 SSE** / **LLM**。**409**: 同一セッションの並行ターン) | 個人 | 1 |
| GET | `/conversations/{session_id}/messages` | 発話履歴 (切断時の回復経路②) | 個人 | 1 |

### 3.8 アイデア (参照・人手編集・版・タグ・評価) → [ideas.md](ideas.md)

| メソッド | パス | 概要 | スコープ | 増分 |
|---|---|---|---|---|
| GET | `/ideas` | アイデア一覧 | 個人 / 契約 (増分 1) | 1 |
| GET | `/ideas/csv` | CSV エクスポート (v2 踏襲。C-16) | 個人 / 契約 (増分 1) | 1 |
| POST | `/ideas` | アイデアの手動登録 (v2 のマイアイデアの受け先) | 個人 | 1 |
| GET | `/ideas/{idea_id}` | アイデア取得 | 個人 / 契約 (増分 1) / ボード経由 | 1 |
| PUT | `/ideas/{idea_id}` | 本文・タグの更新 (**403**: 所有者以外。版を切る) | 個人 (所有者のみ) | 1 |
| DELETE | `/ideas/{idea_id}` | 削除 (論理削除。**403**: 所有者以外) | 個人 (所有者のみ) | 1 |
| PUT | `/ideas/{idea_id}/star` | スター評価更新 (**403**: 所有者以外) | 個人 (所有者のみ) | 1 |
| GET | `/ideas/{idea_id}/versions` | 版一覧 (本文を含まない) | 取得と同じ | 1 |
| GET | `/ideas/{idea_id}/versions/{version_id}` | 版 1 件の取得 (本文を含む) | 取得と同じ | 1 |
| POST | `/ideas/{idea_id}/versions/{version_id}/restore` | 復元 (**403**: 所有者以外) | 個人 (所有者のみ) | 1 |
| GET | `/ideas/{idea_id}/evaluation` | リッチ評価の取得 (stale 判定つき) | 取得と同じ | 1 |
| POST | `/idea-evaluations` | リッチ評価の生成 (**非同期ジョブ** / **LLM**。**403**: 所有者以外) | 個人 (所有者のみ) | 1 |
| GET | `/idea-evaluations` | 評価ジョブの状態一括取得 | 個人 | 1 |

### 3.9 企画書 → [plans.md](plans.md)

| メソッド | パス | 概要 | スコープ | 増分 |
|---|---|---|---|---|
| GET | `/plans` | 一覧 | 個人 | 1 |
| POST | `/plans` | 作成 (アイデアに対する企画書の器を作る。**409**: 既に企画書がある) | 個人 | 1 |
| GET | `/plans/{plan_id}` | 取得 (8 タブの最新版を同梱) | 個人 | 1 |
| PUT | `/plans/{plan_id}` | メタ更新 (`visibility`) | 個人 | 1 |
| DELETE | `/plans/{plan_id}` | 削除 (論理削除) | 個人 | 1 |
| POST | `/plans/{plan_id}/generate` | 8 タブの一括生成 (**SSE** / **LLM**。**409**: 生成中) | 個人 | 1 |
| POST | `/plans/{plan_id}/tabs/{tab_id}/regenerate` | タブの再生成 (**SSE** / **LLM**。**409**: 生成中) | 個人 | 1 |
| PUT | `/plans/{plan_id}/tabs/{tab_id}` | タブ本文の手動更新 (新版を作る。**409**: 生成中) | 個人 | 1 |
| GET | `/plans/{plan_id}/tabs/{tab_id}/versions` | 版一覧 (メタのみ) | 個人 | 1 |
| GET | `/plans/{plan_id}/tabs/{tab_id}/versions/{ver_no}` | 版 1 件の取得 (本文を含む) | 個人 | 1 |
| POST | `/plans/{plan_id}/tabs/{tab_id}/versions/{ver_no}/restore` | 復元 (**409**: 生成中) | 個人 | 1 |
| PUT | `/plans/{plan_id}/tabs/{tab_id}/versions/{ver_no}/instruction` | 版に紐づく生成指示の編集 | 個人 | 1 |
| POST | `/plans/{plan_id}/favorite` | お気に入り登録 (冪等) | 個人 | 1 |
| DELETE | `/plans/{plan_id}/favorite` | お気に入り解除 (冪等) | 個人 | 1 |
| GET | `/plans/{plan_id}/chat/messages` | 企画書チャットの履歴 | 個人 | 1 |
| POST | `/plans/{plan_id}/chat/messages` | 企画書チャット (**SSE** / **LLM**。**409**: 実行中) | 個人 | 1 |
| POST | `/plans/{plan_id}/thumbnail` | サムネイル生成 (**LLM**。画像生成) | 個人 | 1 |

---

## 4. 本番観点への回答

| ID | 状態 | 回答 / 先送り先 |
|---|---|---|
| A-1 認証方式 | **回答** | §2.1。全エンドポイント認証必須・グループ既定 (D-API-3)。方式の SSOT は [../auth.md](../auth.md) §6.1 |
| A-2 ロールと適用範囲 | **回答** | §2.2。認証ロールは `AuthRoleUser` のみ。その上で **R-1 契約内管理者限定 3 本** ([settings.md](settings.md) §3.1) と **R-2 リソース単位ロール / 所有者 13 本** ([idea-boards.md](idea-boards.md) §3.1 の 8 本 + [ideas.md](ideas.md) §1.3 の 5 本) が 403 を返す |
| A-3 テナント境界 (所有者カラム) | **参照** | [../auth.md](../auth.md) §6.3 が SSOT。テーブル定義は [../data-model.md](../data-model.md) が担う (**確定済み**) |
| A-4 絞り込みの層 | **回答** | §2.3 + D-API-8。UseCase が確定し Repository のクエリ条件で強制 |
| A-5 ステータスコード | **回答** | §2.5 (= **AC-1.4**)。判定基準は「**見えるリソースへの権限不足 = 403 / 見えないリソース = 404**」。403 は合計 **16 本** (R-1 3 + R-2 13)。SSE 開始後の失敗は HTTP で表現しない (D-API-12) |
| A-6 LLM への越境 | **参照 + 回答** | [../architecture.md](../architecture.md) §3 が SSOT。本ディレクトリは LLM 経路を表で明示 (§3)、RAG のスコープは [knowledge.md](knowledge.md) §4 |
| A-7 共有・公開 | **部分回答** | ボードは v2 の既存契約共有 (メンバーシップ + 3 段ロール) を**そのまま引き継ぐ** ([idea-boards.md](idea-boards.md) §3.1)。テーマ・アセット・アイデアの `visibility` と `scope=contract` は**増分 1** (D-API-8'。2026-08-02 改訂 — C-16 により v2 でできていた共有の切り替えを落とせない。SSOT は [../auth.md](../auth.md) §6.12 (c) / [../data-model.md](../data-model.md) DM-9)。**増分 2 に残るのはテーマメンバー機能のみ**。**[../auth.md](../auth.md) §7 の「本増分では共有機能を持たない」と食い違うため §5 API-Q3 に残課題として記載** |
| O-1 構造化ログ | **参照** | エラー本文に `request_id` を含める (D-API-6)。ログフィールド定義は [observability.md](../observability.md) |
| O-2 LLM 計測 | **参照 + 回答** | 計測値の生成は **`gateway/<プロバイダ>` の単一関門** 1 箇所 ([../architecture.md](../architecture.md) §3.8.3 / [../observability.md](../observability.md) の O-C)。**本ディレクトリの「計測対象 9 本」は Q-L11=A-1 により維持される** — ナレッジは v2 移植ドメイン (v2 の 3 層規約のまま) だが、**移植分も LLM 呼び出しだけは `gateway/` 経由を必須**とするユーザー決定 (2026-07-30。[../../../aidlc-docs/inception/productionization/questions-layering.md](../../../aidlc-docs/inception/productionization/questions-layering.md) Q-L11) があるため、埋め込み生成も計測対象として成立する。本ディレクトリは**計測対象となる LLM 経路を 9 本に特定**した: `POST /asset-extractions` / `POST /knowledge-threads/{thread_id}/messages` / `POST /knowledge-files` (埋め込み生成) / `POST /conversations/{session_id}/messages` (会話ターン。詳細は [conversation.md](conversation.md) §3.3) / `POST /idea-evaluations` (詳細は [ideas.md](ideas.md) §6.6) / `POST /plans/{plan_id}/generate` / `POST /plans/{plan_id}/tabs/{tab_id}/regenerate` / `POST /plans/{plan_id}/chat/messages` / `POST /plans/{plan_id}/thumbnail` (詳細は [plans.md](plans.md) §4.6)。§3 の総覧表の LLM 列がこの 9 本の索引。**対象外の LLM 経路**: v2 の `GET /companies/genai` (Dify 経路。v2 の管轄で `docs/design/llm-migration.md` が扱う — [settings.md](settings.md) §5 の注) |
| O-3 コスト集計と上限 | **先送り** | C-12 (上限なし) により拒否は設けない。可視化は [../observability.md](../observability.md) §4.2 / §6.1 へ。`GET /usage-summary` は**利用件数**のサマリでありコスト表示は含めない ([settings.md](settings.md) §4) |
| O-4 失敗の可観測性 | **部分回答** | 外部/LLM 起因を **502** で識別可能にする (§2.5)。非同期ジョブは `failure.code` で原因を区別し、**取り残されたジョブを `stale_aborted` として観測可能にする** (§1.3 J-3)。`max_tokens` 切り詰め・JSON パース失敗の値域は [../observability.md](../observability.md) §4.3 |
| O-5 SSE / 長時間処理 | **回答 (一部先送り)** | SSE エンドポイントの特定と一覧化 (§3) + **ストリーム開始後のエラー表現** (D-API-12) + **非同期ジョブの実行主体・状態機械・取り残しの回収・再実行・進捗配信** (**§1.3 = D-API-15**)。イベント名・heartbeat 閾値の最終値・定期実行の仕組みは observability / operations 設計へ先送り (§1.3 末尾) |
| O-6 監査ログ | **部分回答** | `GET /activity-logs` を新設 ([settings.md](settings.md) §3)。**何を記録するか**の定義は [../observability.md](../observability.md) §4.5 |
| O-7 アラート | **対象外** | API 設計の範囲外。運用設計 ([../operations.md](../operations.md) §7 のアラート表。**確定済み**) |
| D-1〜D-8 | **対象外** | CI/CD・IaC は API 設計の範囲外。ただし **D-2 のマージ条件に §1.4 の 8 検査を要求**する。**D-3 (デプロイ) は §1.3 J-3 の前提** (ローリング更新でジョブが死ぬことを織り込む) |

---

## 5. 残課題 / 要確認

| ID | 内容 | 仮定 (この前提で設計した) | 確定先 |
|---|---|---|---|
| **API-Q1** | v2 API と v3 API を**同一ドメインに相乗り**させるか。相乗りなら `/themes` 等が衝突し、v3 側にパスプレフィックスが必要になる | 別ドメイン (別 ALB / 別ホスト) を前提に**プレフィックス無し**で設計した (D-API-1) | [infrastructure.md](../infrastructure.md) |
| ~~**API-Q2**~~ | ~~v2 の CORS 許可リストに Vercel のドメインを追加する作業が必要~~ | **不要になった (2026-07-30)**: D-ST-1' により**認証・アカウント API も v3 が提供する**ため、FE が v2 を叩く前提が消えた ([settings.md](settings.md) §4.1)。**併用期間中に未移植の v2 機能を FE から叩く場合は再浮上する**が、その範囲は `plan.md` Task-3i / R-1 の結論に依存する | — (v2 リポジトリへの変更は不要) |
| **API-Q3** | **共有機能のスコープ** — [../auth.md](../auth.md) §7 は A-7 を「本増分では共有機能を持たない」としているが、プロトタイプはテーマのメンバー・可視性、ボードの共有メンバーを持ち、v2 の `idea_boards` は既に **3 段ロール (admin/editor/viewer) 付きの契約共有**である (`hassan-v2-backend/entity/idea_board.go:14-16`) | **A-7 の判断部分はクローズ済み (2026-08-02)** — ボードは v2 の共有とロールを**そのまま引き継ぎ** (増分 1)、テーマ・アセット・アイデアの `visibility` と `scope=contract` も**増分 1** (D-API-8'。C-16 の適用で「増分 2」から改訂。SSOT は [../auth.md](../auth.md) §6.12)。**残る未確認はテーマメンバーの権限差のみ** ([themes.md](themes.md) TH-Q5) | **テーマメンバーの権限差 (TH-Q5) の要件確認のみ** |
| **API-Q4** | **エラー本文の形式変更** (`{"code","msg"}` → `{"code","message","request_id"}`) により、FE は v2 API と v3 API で 2 形式を扱う | v3 FE は新規実装なので変換層を 1 箇所に置ける前提 (FE-2 と同じ「変換は API 境界のみ」) | 実装リポの FE 設計 |
| **API-Q5** | Q-1 (データモデル統合方針) の既定が文書間で食い違う。[requirements.md](../../../aidlc-docs/inception/productionization/requirements.md) §6 は「Q-1=C を暫定既定」、[../architecture.md](../architecture.md) §2 の注記は「D-J (全面切替) により (a) 統合 か (c) 分離+移行 が候補」 | **本ディレクトリは Q-1 に依存しない範囲のみ確定**し、フィールドは暫定とした (§0) | `docs/design/data-model.md` (Q-1 回答後) |
| **API-Q6** | **既存ボードの materialize 基準時点** — v2 のボード内容は `idea_boards.filter` (jsonb) の**評価結果**であり、切替時に静的アイテムへ凍結する ([idea-boards.md](idea-boards.md) §4)。凍結後は**条件に合致する新しいアイデアが自動で載らなくなる** | 切替時点の評価結果を凍結し、以後 `filter` は廃止する前提で設計した | ユーザー判断 ([idea-boards.md](idea-boards.md) IB-Q1) |
| **API-Q7** | **非同期ジョブの heartbeat 閾値と定期実行の仕組み** — §1.3 J-3 で「既定 15 分 / 1 分間隔」を仮置きした | in-process の ticker で足りる前提 (キュー無し = `design_memo.md:136`) | [operations.md](../operations.md) |

**先送りの明示**: 上記のうち API-Q1 / API-Q3 / API-Q6 が変わると §3 の総覧 (パス・増分) または
移行手順が変わる。API-Q2 / API-Q4 / API-Q5 / API-Q7 は表のパス・メソッド・ステータスコードを変えない。

---

## 6. 実装リポへの引き渡し

### 6.1 依存順序

```
data-model.md 確定 (Q-1)
   ↓
共通層 (§1.2 の D-API-4/5/6/7 + §1.3 の非同期基盤 + §1.4 の CI 検査) ── 最初に 1 度だけ実装する
   ↓
┌─────────────┬─────────────┬──────────────┬───────────┬────────────┐
themes.md    assets.md     idea-boards.md  news.md    settings.md      ← 並列可
                 ↓              ┊
           knowledge.md         ┊ (破線 = 設計依存)
       (assets の抽出基盤 /     ┊
        S3 + presign 層を再利用) ┊
                                ▼
                   会話型アイデア創出の API 設計 (本ディレクトリの対象外)
                   ── idea-boards.md §7 の /ideas 3 本は同じ ideas テーブルを読むため、
                      生成側が確定するまで読み取り専用で実装する
```

- **共通層を先に確定させる**。D-API-6 のマッピングテーブル・§1.3 の非同期ジョブ基盤・
  §1.4 の CI 検査が後回しになると、ドメインごとの手書き実装 (v2 の F-8) が再発する
- `idea-boards.md` §7 の**アイデア参照 API** は、会話型アイデア創出 (対象外ファイル) と
  **同じ `ideas` テーブルを読む**。生成側の設計が確定するまで**読み取り専用**として実装する
- **増分 2 の作業単位**: **テーマメンバー機能のみ** (`GET`/`PUT /themes/{theme_id}/members` + `PUT …/visibility` の
  メンバー部分)。**2026-08-02 に縮小した** — `visibility` と `scope=contract` の有効化と
  [settings.md](settings.md) の `default_asset_visibility` は **C-16 の適用で増分 1 へ前倒し**になった
  (D-API-8' / [../auth.md](../auth.md) §6.12 (c))。
  **読む側と書く側を必ず同じ増分に入れる** (BE-10)

### 6.2 参照すべき v2 既存実装

| 目的 | 参照先 |
|---|---|
| Controller のレスポンス/エラーヘルパー | `hassan-v2-backend/controller/controller.go:17-125` |
| SSE ヘルパー | `hassan-v2-backend/controller/controller.go:128-193` |
| SSE の使用例 (ジョブ進捗) | `hassan-v2-backend/controller/business_plan.go:154-175` |
| CodedError の集約ハンドラ (v3 の共通マッピングの手本) | `hassan-v2-backend/controller/idea_board.go:554-576` |
| 一覧 + ページネーション + 共有判定 | `hassan-v2-backend/controller/asset.go:73-131`, `hassan-v2-backend/usecase/asset/list_assets.go:44-78` |
| multipart アップロード | `hassan-v2-backend/controller/asset.go:485`, `hassan-v2-backend/controller/account.go:747` |
| S3 クライアントの構成 (**アップロード方式は踏襲しない**) | `hassan-v2-backend/aws/s3.go:23-37` (クライアント初期化) / `:74-107` (削除)。**`uploadFile` の `ACL: ObjectCannedACLPublicRead` (`同:46`) と恒久 URL (`同:58`) は流用禁止** (D-API-14') |
| **署名付き URL (presigned URL)** | **v2 に前例が無い** (`Presign` の参照 0 件)。AWS SDK for Go v2 の `s3.NewPresignClient` を新規に実装する。有効期限は定数 1 箇所 (D-API-14') |
| swag アノテーション | `hassan-v2-backend/controller/news.go:25-33` |
| バリデータ登録 | `hassan-v2-backend/controller/custom_validator.go:11-18` |
| orval 設定 (入力の変更点は D-API-13) | `hassan-v2-frontend/orval.config.js` |

### 6.3 参照すべき PoC 既存実装

| 目的 | 参照先 |
|---|---|
| アセット抽出の 4 ターン SSE | `claude_managed_agents/cmd/devui/asset_extract_4turns.go` |
| 機能分解ツリーの構造 | `claude_managed_agents/cmd/devui/asset_function_tree.go` |
| 一括インポート / CSV マッピング | `claude_managed_agents/cmd/devui/asset_bulk_import.go`, `claude_managed_agents/internal/asset_extract/csv_mapper.go` |
| 重複検出・マージ | `claude_managed_agents/internal/asset_extract/dedup.go`, `claude_managed_agents/internal/asset_extract/merge.go` |
| SSE のマルチライン取りこぼし対策 (BE-7 の修正済み実装) | `claude_managed_agents/cmd/devui/conversation_stream.go` |
