# API: アセット管理

> 共通規約 (認証・レスポンス形・エラー・ページネーション・ステータスコード) の SSOT: [README.md](README.md)
> 本ファイルが回答する本番観点: **A-3 (部分), A-4, A-5, A-6, A-7, O-2, O-4, O-5** / 受入基準: **AC-1.1, AC-1.4**

## 1. 対応する画面と参照する既存実装

| 区分 | 所在 |
|---|---|
| プロトタイプ | `assets` ビュー — `../../prototype/hassan_agent_prototype_v2.html` の HTML `:7399-7523` / JS `:13001-13674` (2026-07-30 更新版の実測) |
| プロトタイプのモックデータ | `V2_FOLDERS` (`:7780`、2 階層ツリー 8 件) / `V2_ASSETS` (`:7793`、22 件) / `FUNCTION_TREES` (`:8290`) |
| 新規登録ウィザード | 4 ステップ (①ソース入力 → ②AI 抽出 → ③確認・修正 → ④完了) — `renderNewAssetWizard` `:13001-13309` |
| v2 の既存実装 | `hassan-v2-backend/controller/asset.go`、`hassan-v2-backend/usecase/asset/`、`hassan-v2-backend/db/queries/asset.sql` |
| v2 の既存テーブル | `assets` (`hassan-v2-backend/db/schema.sql:104-116`) / `asset_documents` (`同:510-516`) / `asset_usage_histories` (`同:350`) |
| PoC の既存実装 | `claude_managed_agents/cmd/devui/asset_extract_4turns.go` / `asset_function_tree.go` / `asset_bulk_import.go`、`claude_managed_agents/internal/asset_extract/` |

### 1.1 v2 / PoC / プロトタイプの対応表

| プロトタイプの概念 | v2 | PoC | 判定 |
|---|---|---|---|
| アセット名 (`name`) | `assets.title` | `assets` テーブル ([../../analysis/poc-inventory.md](../../analysis/poc-inventory.md) §4) | あり (名称差) |
| 説明 (`desc`) | `assets.description` / `asset_description` | あり | あり |
| 分類 (`cat`) | `assets.asset_type` | あり | あり |
| タグ (`tags`) | **無い** (`assets.components text[]` が近い) | `asset_tags` テーブル | 新規 (PoC に前例) |
| **フォルダ (`folderId` / 親子)** | **無い** | **無い** | **新規** |
| 制作者 (`createdBy`) | `assets.account_id` (作成者 = 所有者) | あり | あり |
| 特許件数 (`patents`) | **無い** | `asset_patents` テーブル | 新規 (PoC に前例) |
| ステータス (`status`: ready/progress/draft) | **無い** (`is_deleted` のみ) | `claude_managed_agents/cmd/devui/asset_status.go` | 新規 (PoC に前例) |
| スペック表 | **無い** | `asset_specs` テーブル | 新規 (PoC に前例) |
| **機能分解ツリー** | **無い** | `function_tree_l1` / `function_tree_l2` テーブル | 新規 (PoC に前例) |
| 参照 URL | `assets.ref_url` | あり | あり (**更新版プロトタイプでは抽出ソースの入力ステップのみ**で、登録処理 `:13262-13265` は URL をアセットに保存せず、詳細エディタにも表示が無い) |
| AI 抽出 (資料/URL から) | `POST /assets/generate` (タイトル抽出 + 説明生成) / `POST /assets/generate-description` (`hassan-v2-backend/router/router.go:115-118`) | `/api/asset-extract` (SSE 4 ターン) 他 ([../../analysis/poc-inventory.md](../../analysis/poc-inventory.md) §2) | あり (方式差 — §3 D-AS-3) |
| CSV 一括取り込み | `POST /assets/upload` (`hassan-v2-backend/router/router.go:113`) | `/api/assets/bulk-import`, `/api/asset/parse-csv` | あり |
| 重複検出・マージ | **無い** | `/api/asset/merge-candidates`、`claude_managed_agents/internal/asset_extract/dedup.go` | PoC のみ |
| 利用テーマ欄 | `asset_usage_histories` (`hassan-v2-backend/db/schema.sql:350`) | — | あり (プロトタイプは静的表示のため §5) |

**事実**: プロトタイプの `FUNCTION_TREES` (`:8290`) は 22 アセット中 **4 件のみ実データ**で、
残りは「まだ登録されていません」を表示する。スペック表・利用テーマ欄は**選択に関わらず固定の静的表示**で
実データと連動していない。したがってこれらは**設計入力ではあるが挙動の根拠にはならない** (DR-7)。

---

## 2. エンドポイント一覧

すべて認証必須 (`X-Token`)。共通の 400/401/500 は [README.md](README.md) §2.5 に従い、
本表では**エンドポイント固有のコードのみ**挙げる。

| メソッド | パス | 概要 | スコープ | 主なリクエスト / レスポンス項目 (暫定) | 固有ステータス | LLM | SSE |
|---|---|---|---|---|---|---|---|
| GET | `/asset-folders` | フォルダツリー取得 | 個人 / 契約 | Q: `scope` (**`contract` は増分 1 から有効** — C-16) — R: `{items:[{id, name, parent_id, depth, asset_count}]}` (**フラット配列 + `parent_id`**) | 200 / **400** (増分 1 で `scope=contract`) | — | — |
| POST | `/asset-folders` | フォルダ作成 | 個人 | B: `name` (必須) / `parent_id` (null = 最上位) — R: `Folder` | **201** / **400** (深さ上限超過・親が他人) | — | — |
| PUT | `/asset-folders/{folder_id}` | 改名・親の変更 | 個人 | B: `name` / `parent_id` — R: `Folder` | 200 / 404 / **400** (循環参照・深さ上限超過) | — | — |
| DELETE | `/asset-folders/{folder_id}` | 削除 | 個人 | Q: `on_conflict` (`reject` 既定 \| `move_to_parent`) | **204** / 404 / **409** (配下にアセットまたは子フォルダがあり `reject` の場合) | — | — |
| GET | `/assets` | 一覧 | 個人 / 契約 | Q: `scope` (**`contract` は増分 1 から有効** — C-16) / `folder_id` / `include_descendants` (bool, 既定 `true`) / `status` / `created_by` / `asset_type` / `keyword` / `limit` / `offset` / `sort` (`updated_at`\|`name`\|`patent_count`) — R: `{items:[Asset], total_count}` | 200 / **400** (増分 1 で `scope=contract`) | — | — |
| POST | `/assets` | 作成 (抽出結果のレビュー確定を含む) | 個人 | B: `folder_id` / `name` (必須) / `asset_type` / `description` / `tags[]` / `ref_urls[]` / `status` / **`visibility` (`private`\|`contract`。既定 `private`。**増分 2 で有効**)** / `function_tree` / `extraction_id` (任意。抽出由来を示す) — R: `Asset` | **201** / **404** (`extraction_id` が他人 or 不存在) / **409** (`extraction_id` が既に確定済み) | — | — |
| GET | `/assets/{asset_id}` | 取得 | 個人 / 契約 (§3.2) | R: `Asset` (+ `visibility` / `function_tree_summary` / `used_by_themes[]`) | 200 / 404 | — | — |
| PUT | `/assets/{asset_id}` | 更新 | 個人 | B: `POST /assets` と同じ項目 (`extraction_id` を除く) — R: `Asset` | 200 / 404 | — | — |
| DELETE | `/assets/{asset_id}` | 削除 (論理削除) | 個人 | — | **204** / 404 | — | — |
| GET | `/assets/{asset_id}/function-tree` | 機能分解ツリー取得 | 個人 / 契約 (§3.2) | R: `{version, nodes:[{id, parent_id, level, name, description}]}` | 200 / 404 | — | — |
| PUT | `/assets/{asset_id}/function-tree` | ツリー全体置換 | 個人 | B: `{version (必須), nodes:[...]}` — R: `{version, nodes}` | 200 / 404 / **409** (`version` 不一致 = 他者が更新済み) | — | — |
| POST | `/asset-extractions` | AI 抽出ジョブ開始 | 個人 | B: `document_ids[]` / `ref_urls[]` / `manual_text` / `hint_asset_type` — R: `{extraction_id, status:"queued"}` | **202** / **200** (冪等キー一致の既存ジョブを返す — [README.md](README.md) §1.3 J-5) / **400** (ソースが 0 件・URL 件数上限超過) / **502** (Agent 呼び出しの同期的な失敗) | **✓** | — |
| GET | `/asset-extractions/{extraction_id}` | 状態・結果取得 | 個人 | R: `{extraction_id, status:"queued"\|"running"\|"succeeded"\|"failed", progress, updated_at, result:{...}, failure:{code, message}}` (**状態機械と `failure.code` は [README.md](README.md) §1.3 が SSOT**) | 200 / 404 | — | — |
| GET | `/asset-extractions/{extraction_id}/stream` | 抽出進捗ストリーム | 個人 | R: `text/event-stream`。**DB の状態をポーリングして配信**するため、ジョブを実行しているタスク以外に接続が着地しても流れる ([README.md](README.md) §1.3 J-6) | 200 / 404 (**ストリーム開始後の失敗は SSE の `error` イベント** — D-API-12) | — | **✓** |
| GET | `/assets/{asset_id}/documents` | 添付資料一覧 | 個人 / 契約 (§3.2) | R: `{items:[{id, file_name, byte_size, content_type, status, created_at}]}` | 200 / 404 | — | — |
| POST | `/assets/{asset_id}/documents` | 添付資料追加 | 個人 | `multipart/form-data`: `file` — R: `Document` | **201** / 404 / **400** (拡張子・サイズ違反) | — | — |
| DELETE | `/assets/{asset_id}/documents/{document_id}` | 添付資料削除 | 個人 | — | **204** / 404 | — | — |

### 2.1 抽出フロー (プロトタイプ 4 ステップの API 対応)

```
① ソース入力     POST /assets/{asset_id}/documents  … 資料アップロード (アセット未作成時は §3 D-AS-4)
                 POST /asset-extractions            … 202 + extraction_id
② AI 抽出        GET  /asset-extractions/{id}/stream … SSE で進捗 (PoC の 4 ターン相当)
                 GET  /asset-extractions/{id}        … 切断時の状態復元・結果取得
③ 確認・修正     (クライアント内。サーバ呼び出し無し)
④ 完了           POST /assets  (body に extraction_id + 修正後の内容) … 201
```

**②の SSE が切れても ③に進める**ことが設計上の要件 (O-5)。
`GET /asset-extractions/{id}` が結果の取得経路を兼ねるため、SSE は**進捗表示専用**であり
**結果の唯一の受け取り口ではない** ([README.md](README.md) §1.3 J-7)。

**実行基盤の前提** ([README.md](README.md) §1.3 = D-API-15 が SSOT。ここでは該当箇所のみ再掲しない):

| 論点 | 本エンドポイントでの現れ方 |
|---|---|
| 実行主体 (J-1) | BE プロセス内の goroutine。**ジョブキューを導入しない** (`design_memo.md:136`) |
| 状態の SSOT (J-2) | `GET /asset-extractions/{id}` が返す `status` は DB の値。メモリ上の進捗を正にしない |
| 取り残しの回収 (J-3) | `running` のまま `updated_at` が閾値を超えたジョブは `failed` + `failure.code = stale_aborted` になる。**ECS のローリング更新で処理が死んでも UI が回り続けない** |
| 再実行 (J-4) | `failed` の再試行は `POST /asset-extractions` を**もう一度呼ぶ** (新しい `extraction_id` が発行される)。自動リトライはしない |
| 冪等性 (J-5) | 同一ソースの二重送信は既存ジョブを 200 で返す。**同じ PDF に対する抽出が 2 本走って LLM コストが倍にならない** |

---

## 3. 設計判断

| # | 論点 | 採用案 | 却下案と理由 |
|---|---|---|---|
| D-AS-1 | フォルダの表現 | **自己参照 `parent_id` の 1 テーブル**。API は**フラット配列 + `parent_id`** を返し、ツリー構築は FE が行う。**深さ上限 3 をサーバで検証**し、超過は 400 | (a) `category` / `subcategory` の 2 カラム固定 (プロトタイプは 2 階層 — `V2_FOLDERS`): 3 階層目の要求でスキーマ変更 + データ移行が発生する。(b) 深さ無制限: 再帰 CTE のコスト上限が読めず、循環参照の検証がすべての更新経路に必要になる。(c) レスポンスをネスト構造で返す: 部分更新のキャッシュ無効化範囲が広くなり、`asset_count` の集計位置も曖昧になる |
| D-AS-2 | フォルダ削除時の配下 | **既定は 409 で拒否** (`on_conflict=reject`)。明示指定で親へ移動 (`move_to_parent`) | (a) 配下ごと削除 (カスケード): 誤操作で 22 件のアセットが一括で消える経路を既定にできない。(b) 常に親へ移動: 「削除したのに残っている」という結果になり、ユーザーの意図と乖離する |
| D-AS-3 | AI 抽出の方式 | **非同期ジョブ (202) + SSE 進捗 + 結果は別 GET**。抽出結果を**サーバ側に一時保存** (`extraction`) し、レビュー後の `POST /assets` で確定する。**実行主体・状態機械・回収・再実行の共通仕様は [README.md](README.md) §1.3 (D-API-15)** | (a) 同期 POST で完結 (v2 の `POST /assets/generate` — `hassan-v2-backend/router/router.go:115`): PoC の 4 ターン抽出は複数の LLM 呼び出しを含み、ALB / ECS のリクエストタイムアウトに当たる。進捗も出せない。(b) SSE 1 本で抽出と登録を行う (PoC 方式 — `claude_managed_agents/cmd/devui/asset_extract_4turns.go`): 途中切断で結果が失われ (O-5)、プロトタイプの③レビュー工程を挟めない。(c) 抽出結果をクライアントに持たせて再送信: 数百行の抽出 JSON を往復させることになり、`max_tokens` 切り詰め (BE-6) の検知がクライアント側の責務になる |
| D-AS-4 | 抽出ソースの置き場 | **アセットに紐づく `documents`** を正とし、**アセット作成前の抽出は `POST /asset-extractions` の `document_ids` に「アセット未紐付けのアップロード」を渡す**。未紐付け文書は **`POST /knowledge-files` とは別系統**で、`POST /assets` 時にアセットへ紐付けられる | (a) 抽出用に別のアップロード API を作る: アップロード実装が 3 系統 (アセット添付 / 抽出用 / ナレッジ) になり、拡張子・サイズ検証の SSOT が割れる (BE-2)。(b) ナレッジのファイル基盤を共用する: ナレッジは RAG 用の埋め込み生成を伴い、アセット抽出には不要な処理が走る。**要確認 AS-Q5** |
| D-AS-5 | `asset_documents` の所有者と保存先 | **`account_id` を必須カラムにする** ([../auth.md](../auth.md) §6.3)。**S3 は非公開バケット + 取得は署名付き URL** ([README.md](README.md) D-API-14')。**v2 の `uploadFile` (`ACL: ObjectCannedACLPublicRead` + 恒久 URL — `hassan-v2-backend/aws/s3.go:46`, `:58`) を流用しない** | (a) v2 踏襲: v2 の `asset_documents` は `id` / `file_text` / `created_at` / `updated_at` の **4 カラムのみで所有者へ辿る外部キーを一切持たない** (`hassan-v2-backend/db/schema.sql:510-516`、[../auth.md](../auth.md) §2.2)。**アセット本文がテナント境界の外にある**状態を持ち込めない (A-3) |
| D-AS-6 | 機能分解ツリーの更新 | **全体置換 PUT + `version` による楽観ロック** (不一致は 409) | (a) ノード単位の CRUD: プロトタイプの編集 UI がツリー全体のフォームであり、粒度の細かい API の恩恵が無い。同時編集の整合はどちらでも別途必要。(b) 版管理なしの全体置換: 2 人が同時に編集すると後勝ちで片方の編集が黙って消える。(c) PoC の `function_tree_l1` / `l2` の 2 段固定を踏襲: 3 段目が必要になった時に API が変わる — `level` を持つ 1 テーブルにする |
| D-AS-7 | 削除の方式 | **論理削除** (v2 の `assets.is_deleted` — `hassan-v2-backend/db/schema.sql:104-116` を踏襲)。一覧・取得は既定で除外 | (a) 物理削除: アセットは会話型アイデア創出やボードから参照されるため、参照が壊れる。v2 が既に論理削除である |
| D-AS-8 | 一覧の絞り込み | `scope` + `folder_id` + `include_descendants` + `status` + `created_by` + `asset_type` + `keyword`。**`account_id` パラメータは持たない** ([README.md](README.md) D-API-8) | (a) v2 の `account_id` クエリ踏襲 (`hassan-v2-backend/controller/asset.go:102`): アセット側は契約一致を検証しており (`hassan-v2-backend/usecase/asset/list_assets.go:60-66`) テーマ側より安全だが、**検証を「実装したかどうか」に依存させない**方針を全ドメインで揃える |
| D-AS-9 | `keyword` の対象 | **アセット名 (`name`) と説明 (`description`) とタグ (`tags`)** の部分一致 | (a) v2 と同じくタイトルのみ: プロトタイプの検索プレースホルダは「名前・技術概要・タグで検索」(`:7476`) とタグを含む探索を想定している (**ただし実装のフィルタは `name` と `desc` のみ — `:13611-13616`。タグはチップ表示のみ**)。(b) 添付資料の本文 (`file_text`) も対象にする: 全文検索インデックスの設計が必要で、ナレッジの RAG 検索と機能が重複する — アセット本文の横断検索は [knowledge.md](knowledge.md) の責務 |
| D-AS-10 | LLM 呼び出しの層 | 抽出の LLM 呼び出しは **`gateway/<プロバイダ>` 経由**、抽出のドメインロジック (ソース選択・結果の組み立て) は **`service/asset.Extractor`**、手続きとトランザクション境界は `usecase/asset` ([../architecture.md](../architecture.md) §3.3 / §3.8.3)。**Controller / UseCase / Service は LLM SDK を直接呼ばない** | (a) UseCase から直接 Anthropic SDK を呼ぶ: 計測が経路ごとの実装になり、O-2 (全経路計測) が守られない。(b) **Service (`asset.Extractor`) が SDK を直接呼ぶ (旧 D-AS-10 の「Service 層経由」)**: 外部 API 呼び出しは `gateway/` に置く決定 ([../architecture.md](../architecture.md) の D-A''') に反し、計測の単一関門が Service と gateway に割れる |
| D-AS-11 | 抽出失敗の可観測性 | `GET /asset-extractions/{id}` の `failure` に **`code` を持たせ**、`max_tokens` 切り詰め・JSON パース失敗・タイムアウト・ソース解析失敗・**`stale_aborted` (取り残しの回収 — [README.md](README.md) §1.3 J-3)** を**区別できる値域**にする (O-4 / BE-6) | (a) `status:"failed"` だけを返す: ユーザーが再試行すべきか (一時障害) 入力を直すべきか (ソース不備) を判断できず、サポート問い合わせでしか原因が分からない |

### 3.1 上限値・許可値の SSOT (BE-2 の構造的回避)

プロトタイプに現れる制限値は**すべてサーバ側定数 1 箇所に置き**、OpenAPI 経由で FE へ伝播させる
([README.md](README.md) D-API-7 / D-API-14)。**FE のバリデーションとプロンプトに数値を書かない**。

| 項目 | プロトタイプの値 (暫定) | 出典 |
|---|---|---|
| 添付ファイルの許可拡張子 | `.pdf` / `.docx` / `.pptx` / `.xlsx` / `.csv` | `../../prototype/hassan_agent_prototype_v2.html:13055` |
| 添付ファイルの最大サイズ | 20 MB | 同上 |
| 抽出ソースの URL 件数上限 | 5 件 | `../../prototype/hassan_agent_prototype_v2.html:13064` (ラベル) / `:13068` (`_newAssetState.urls.length < 5` の実際の制限) |
| フォルダの深さ上限 | 3 (プロトタイプは 2 階層) | D-AS-1 で決定 (プロトタイプ由来ではない) |

**特許明細書は抽出ソース対象外** (プロトタイプが明示 —
`../../prototype/hassan_agent_prototype_v2.html:13055`「特許明細書は不可」)。
これは検証可能なルールではない (ファイル種別から判定できない) ため、
**API では拒否せず、UI の注意書きと抽出プロンプト側の指示**として扱う。この扱いは要確認 (AS-Q4)。

### 3.2 `visibility` と `scope=contract` のゲート (重要 — DR-3 / BE-10)

**本節が回答する ID: A-7 / A-4** — [README.md](README.md) D-API-8' の具体化。
[themes.md](themes.md) §3.2 と**同じ規則**を適用する (2 ドメインで判定を揃える)。

v2 ではアセットの契約内共有も `sharing_settings` が決めており、
**共有 OFF で契約スコープ or 他人指定を行うと `SharingSettingDisabled` → 403** を返す
(`hassan-v2-backend/usecase/asset/list_assets.go:71-79`、`hassan-v2-backend/controller/asset.go:119-120`)。

| # | 決定 | 却下案と理由 |
|---|---|---|
| D-AS-12 | **`Asset` に `visibility` (`private`\|`contract`。既定 `private`) を持たせる**。`scope=contract` は「`visibility = contract` のアセット + 自分のアセット」を返す。**書き込み経路 (`POST` / `PUT` の `visibility`) と `scope=contract` はどちらも増分 2** | (a) `visibility` を持たず `scope=contract` を増分 1 で許す (**当初案・却下**): 契約内の全アセットが露出する。v2 の既定は非共有なので**切替が一斉公開**になる。(b) **[settings.md](settings.md) の `default_asset_visibility` だけを作る** (**当初案の欠陥・却下**): 設定を**書く側**はあるのに、それを適用する**アセット側のフィールドと読む側が存在しない** — BE-10 (読む側と書く側を対で設計する) の再発形。**両者を同じ増分 2 に入れることで構造的に潰す** |
| D-AS-13 | **フォルダの可視性はフォルダ自身の `visibility` で判定**し、配下アセットの可視性とは独立に評価する | (a) 配下アセットの可視性から導出する: 1 件でも `contract` のアセットがあるとフォルダが見え、**フォルダ名から他人の技術領域が推測できる**。(b) フォルダは常に契約内公開: 同じ理由で不可 |

**移行 (切替時に 1 度だけ実行)**:

| # | 処理 | 理由 |
|---|---|---|
| AS-M1 | 既存アセットの `visibility` を、**所属契約の `sharing_settings` (category = asset) から決める**: `is_shared = true` → `contract` / `false` またはレコード無し → `private` | **切替前後で見える範囲を変えない** ([themes.md](themes.md) TM-1 と同じ規則。カテゴリのみ asset) |
| AS-M2 | `visibility` カラムは増分 1 でスキーマに用意し、**書き込み API (`PUT /assets/{id}/visibility`) と `scope=contract` も増分 1 で開ける** (**2026-07-31 改訂**。[requirements.md](../../../aidlc-docs/inception/productionization/requirements.md) **C-16**。理由の SSOT は [../auth.md](../auth.md) §6.12) | 後から足すと初期値決定が増分 2 まで遅れ、その間のアセットの既定が二重管理になる |
| AS-M3 | **フォルダは v2 に存在しない**ため、既存アセットは全て「フォルダ未割当」として移行する。フォルダ分けはユーザーが切替後に行う | v2 の `assets` にフォルダ相当のカラムが無い (`hassan-v2-backend/db/schema.sql:104-116`)。推測でフォルダを自動生成しない (DR-1) |

---

## 4. 本番観点への回答

| ID | 回答 | 備考 |
|---|---|---|
| A-1 | [README.md](README.md) §2.1。全 17 本が認証必須 | AC-1.1 |
| A-2 | `AuthRoleUser` のみ | — |
| A-3 | `assets` / `asset_folders` / `asset_documents` / `asset_extractions` / 機能ツリーの**全テーブルに `account_id`** (D-AS-5) | data-model で確定 |
| A-4 | 一覧・取得・更新・削除・抽出・添付のすべてで Repository のクエリ条件に所有者。`folder_id` / `extraction_id` / `document_id` も**所有者と組で検証**する (他人の ID を指定したら 404)。`scope=contract` (増分 2) は `contract_id` + `visibility` 条件 (§3.2)。**更新・削除は増分 2 でも作成者のみ** | D-AS-8 / §3.2 |
| A-5 | 本表の「固有ステータス」列 + [README.md](README.md) §2.5 | **AC-1.4** |
| A-6 | 抽出の LLM 呼び出しは `gateway/` 経由 (D-AS-10)。**抽出ジョブが読むソースは `document_ids` の所有者検証済みのものだけ**で、所有者スコープは `usecase/asset` が確定して渡す。LLM が出力した ID を参照経路にしない | [../architecture.md](../architecture.md) §3.8.2 |
| O-2 | LLM 経路は `POST /asset-extractions` の 1 本。**計測値の生成は `gateway/<プロバイダ>` の単一関門**、明細の記録は `usecase/asset` ([../observability.md](../observability.md) の O-C) | — |
| O-4 | `failure.code` で切り詰め・パース失敗・タイムアウトを区別 (D-AS-11) | 値域は [../observability.md](../observability.md) §4.3 が定める |
| A-7 | **回答**: `visibility` (2 値) と `scope=contract` は**増分 1** (**2026-07-31 に C-16 で改訂**。旧案は増分 2。判断の SSOT は [../auth.md](../auth.md) §6.12)。既存 `sharing_settings` からの初期値決定を移行手順に含めた (AS-M1)。増分 1 は個人スコープのみ | [README.md](README.md) §5 API-Q3 |
| O-5 | SSE は進捗専用。切断しても `GET /asset-extractions/{id}` で復元できる (§2.1)。**非同期ジョブの実行主体・取り残しの回収・進捗配信は [README.md](README.md) §1.3 (D-API-15)** が SSOT | イベント名・閾値の最終値は observability / operations 設計 |
| O-6 | アセットの作成・削除、抽出ジョブの実行は監査対象 | 記録項目は [../observability.md](../observability.md) §4.5 が定める |

---

## 5. 要確認 (プロトタイプに UI のみ / 判断待ち)

| # | 項目 | プロトタイプの状態 | 確定先 |
|---|---|---|---|
| AS-Q1 | **CSV エクスポート** | ボタンがあるがトーストのみのダミー (更新版 `:7498` / `:13341`) | 要件確認。v2 に `GET /ideas/csv` の前例あり |
| AS-Q2 | **「AI で探す」** | **クローズ (2026-07-30)**: 更新版プロトタイプからボタン自体が消えた (「AI で探す」の文言 0 件。ツールバーは「新規アセットを登録」`:7407` と「CSV エクスポート」`:7498` のみ)。設計対象外とする | — (復活したら再起票。PoC の `claude_managed_agents/internal/asset_related` が実装候補) |
| AS-Q3 | **一括インポート** | **クローズ (2026-07-30)**: 更新版プロトタイプからボタン自体が消えた (「一括インポート」の文言 0 件)。設計対象外とする | — (復活したら再起票。v2 `POST /assets/upload` と PoC `/api/assets/bulk-import` に前例) |
| AS-Q4 | **特許明細書の除外** | 注意書きのみ (`:13055`)。判定手段が無い | 抽出プロンプト設計 (§3.1) |
| AS-Q5 | **アップロード基盤の共用** | プロトタイプはアセットとナレッジで別 UI | data-model / 実装リポ設計 (D-AS-4 の却下案 (b)) |
| **AS-Q11** | **アップロード経路が 4 系統目になる** (2026-07-31 のエンドポイント一覧の再照合で発見) | **D-AS-4 は「アップロード実装が 3 系統になり、拡張子・サイズ検証の SSOT が割れる (BE-2)」を理由に専用 API を却下した**が、更新版プロトタイプの**会話画面の「持ち込みアイデア入力」が PDF のドラッグ&ドロップを持つ** (`setFile` `:9720`〜`:9728` が `File` を受け取り `PDF · N KB` と表示、`summarizeIdeaInput` `:9742` 経由で送信。ウィジェット全体は `:9606`〜`:9861`)。これは①アセット添付 ②抽出用の未紐付けアップロード ③ナレッジファイル に続く **4 系統目**にあたる | **会話型アイデア創出の API 設計** ([README.md](README.md) §0 の対象外領域)。**同設計に「4 系統目を作らず、既存 3 系統のどれかに寄せる (または共通のアップロード基盤へ統合する)」制約として引き継ぐ** — D-AS-4 の却下理由が 3 系統を前提にしているため、4 系統目が黙って増えると同じ判断の根拠が崩れる。**本ファイルの範囲では新規エンドポイントを追加しない** |
| AS-Q6 | **スペック表** | 選択アセットに関わらず固定の静的表示 (実データ非連動) | data-model 設計。PoC の `asset_specs` が入力 |
| AS-Q7 | **特許情報** | `patents` は件数のみのモック。個々の特許データの入出力 UI が無い | data-model 設計。PoC の `asset_patents` が入力 |
| AS-Q8 | **利用テーマ欄** | 固定の静的表示 | v2 の `asset_usage_histories` (`hassan-v2-backend/db/schema.sql:350`) を引き継ぐかを data-model で判断 |
| AS-Q9 | **重複検出・マージ** | プロトタイプに UI が無い (PoC のみ)。**更新版に痕跡あり**: `status` の 4 番目の値 `duplicate_pending` に対応する CSS (`:2668`) と一覧の分岐 (`:13620`) が存在する (モックデータに使用例は無い死んだ分岐) | 移植スコープ (Q-3) の確定後 |
| AS-Q10 | **編集・削除・タグ追加** | **更新版で前提が変化**: 右側詳細エディタの主要アクションも**すべてトーストのみのダミーになった** (「AI で分解を再実行」`:13338` / 「技術資料を追加」`:13339` / 削除 `:13340` / 「基本情報を編集」`:13344` / 「タグを追加」`:13346`)。実際に動くのは選択切替・新規登録ウィザード・一覧の検索/フィルタのみ | 本ファイルは `PUT /assets/{asset_id}` / `DELETE /assets/{asset_id}` を定義済み (**プロトタイプがダミー化しても編集・削除 API は維持** — 登録済みアセットを直せない製品は成立しない)。**一覧行からの一括操作**の要否のみ未確定 |
