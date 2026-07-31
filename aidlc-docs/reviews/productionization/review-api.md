# レビュー: API 設計 (`docs/design/API/` 全 7 ファイル) — Task-3b / AC-1.1・AC-1.4

> 実施日: 2026-07-29 / レビュアー: `design-reviewer` (別セッション、本番基準)
> 判定: **重大 7 件 — 修正後に再レビューが必要 (Design Freeze 不可)**

## レビュー結果サマリ

- **対象 (レビューした成果物のリポジトリ相対パス)**
  - `docs/design/API/README.md`
  - `docs/design/API/themes.md`
  - `docs/design/API/assets.md`
  - `docs/design/API/knowledge.md`
  - `docs/design/API/idea-boards.md`
  - `docs/design/API/news.md`
  - `docs/design/API/settings.md`
  - `docs/design/auth.md` (§6.6 参照先更新・§8 の訂正完了記述)
  - `docs/design/architecture.md` (§5 A-5 行)
  - `aidlc-docs/inception/productionization/plan.md` (Task-3b 行)
- **件数**: 重大 **7** / 中 **7** / 軽微 **6**
- **実行した検証**
  - `make doc-lint` → **エラー 0 / 警告 18 (exit 0)**
  - `make check-traceability` → **productionization: 22/22 カバー — OK (exit 0)**
  - **一次ソース抜き取り照合 約 70 件** (`hassan-v2-backend` / `hassan-v2-frontend` / `docs/prototype`)。
    **誤り・ズレ 8 件** (うち**結論を左右する意味的誤り 2 件** = 重大 3・重大 4)
  - エンドポイント件数の機械照合: 各ドメインファイル 9+17+15+21+5+6 = **73**、README 総覧 §3.1〜3.6 = **73** → **一致**

---

## 重大 (Must Fix)

### 重大 1. `idea-boards.md` §2 / D-IB-8 — v2 の 3 段ボールドロール (admin/editor/viewer) を平坦化しており、切替時に既存 viewer が編集権限を得る

**該当**: `docs/design/API/idea-boards.md:75-76` (`GET`/`PUT /idea-boards/{board_id}/members` の `{account_ids:[...]}` / `{account_id, name, icon_url}`)、`:126` (D-IB-8)、`:151` (A-7)

**一次ソースで確認した v2 の実態**:

| 事実 | 出典 |
|---|---|
| ボード内ロールは **3 値** `admin` / `editor` / `viewer` | `hassan-v2-backend/entity/idea_board.go:14-16` |
| `Role()` は 作成者=admin、`EditorAccountIDs` に居れば editor、`ViewerAccountIDs` に居れば viewer、それ以外は `""` | `hassan-v2-backend/entity/idea_board.go:95-110` |
| **メモ・フェーズ編集は `CanEdit` = admin か editor のみ** (viewer は不可) | `hassan-v2-backend/entity/idea_board.go:118-121`、`hassan-v2-backend/usecase/idea_board/update_board_idea.go:47` (`if !board.CanEdit(input.AccountID) { IdeaBoardForbidden }`) |
| `PUT /members` は **メンバーごとに `role` (viewer\|editor) を受け取り**、admin のみ実行可、同一契約検証・作成者の viewer/editor 化拒否・重複拒否を行う | `hassan-v2-backend/usecase/idea_board/manage_board_members.go:46` (`IsAdmin`) / `:52-53` (role 検証) / `:68-70` (同一契約検証)、swag: `hassan-v2-backend/controller/idea_board.go:498` (`"account_id, role（viewer\|editor）"`) |
| `GET /members` は `Role` を返す (非メンバーは `""`) | `hassan-v2-backend/usecase/idea_board/get_board_members.go:20-23` / `:64`、`hassan-v2-backend/controller/dto/idea_board.go:75-81` (`BoardMember.Role`) |
| 保持カラムは `viewer_account_ids uuid[]` / `editor_account_ids uuid[]` の **2 本** | `hassan-v2-backend/db/schema.sql:604-605` |

**なぜ本番で問題になるか**: §1.1 は `GET/PUT /idea-boards/:id/members` を「踏襲」としているが、v3 の入出力は `role` を落としている。
D-IB-8 は「参照・アイテム操作・コメントは**共有メンバー全員**」としており、**v2 で read-only だった viewer が、切替後にフェーズ移動・メモ編集・アイテム追加削除・コメント削除を行えるようになる**。
これは既存本番データに対する**サイレントな権限昇格**であり、A-2 / A-7 / DR-3 の同時違反。加えて `PUT /members` は既存の `role` 付き入力を**破壊的に狭める**ため、v2 の viewer/editor 区分が移行時に消える (どちらに寄せるかの決定が無い)。

**修正案**: (a) `BoardMember` に `role` (`admin`\|`editor`\|`viewer`) を持たせ、`PUT /members` の body を `{members:[{account_id, role}]}` にする。(b) D-IB-8 の権限表を admin/editor/viewer の 3 段で書き直す (v2 の `CanEdit` / `IsAdmin` に対応)。(c) 3 段を採らない判断をする場合は、**既存 viewer をどちらに寄せるか (viewer→editor 昇格 / viewer 切り捨て) を移行手順として明記**する。いずれも `themes.md` TH-Q5 (メンバー権限差) と整合させる。

---

### 重大 2. `idea-boards.md` — v2 のボード内容は `idea_boards.filter` (jsonb) 由来であり board-item テーブルが存在しない。`idea_board_items` 前提の設計では、切替後に**既存ボードが全て空**になる

**該当**: `docs/design/API/idea-boards.md:33` (「v2 はアイテムの追加・削除エンドポイントを持たない」)、`:68-71` (`/items` 4 本)、`:26`/`:160` (`PUT /idea-boards/:id/filter` を「採らない」/ IB-Q1)

**一次ソースで確認した v2 の実態**:

| 事実 | 出典 |
|---|---|
| `CREATE TABLE` はボード関連で **`idea_boards` と `idea_board_phases` の 2 つだけ**。**board-item に相当する中間テーブルは存在しない** | `hassan-v2-backend/db/schema.sql` の `CREATE TABLE` 全走査 (599 / 615 のみ) |
| `idea_boards.filter jsonb` を保持 | `hassan-v2-backend/db/schema.sql:606` |
| **ボードの中身は保存済み filter で毎回算出される**。`ListIdeasForBoard` のクエリに `board_id` は**一切現れず**、`contract_id` + filter 条件 (creator / theme / star / phase / asset_usage / created_from-to) だけで `ideas` を絞る | `hassan-v2-backend/db/queries/idea_board.sql:80-135` |
| 呼び出し側も `b.Filter` を渡している | `hassan-v2-backend/usecase/idea_board/list_idea_boards.go:47` (`ListIdeasForBoard(ctx, input.ContractID, b.Filter, 1, 0, restrictToSelf, input.AccountID)`) |
| filter は旧単数キーからの後方互換 `UnmarshalJSON` まで持つ**現役の機能** | `hassan-v2-backend/entity/idea_board.go:29-79` |

**なぜ本番で問題になるか**: v3 は「明示的アイテム集合 (`POST /items` に `idea_ids[]`)」というv2 と**別のデータモデル**を採っているが、その事実 (v2 は filter 由来) が設計書に書かれていない。
結果として **(a)** 既存ボードには item 行が 1 件も無く、移行で filter を materialize しない限り**全ボードが空になる**、**(b)** IB-Q1 は「フィルタをサーバに保存する必要があるか未確認」という**問いの立て方自体が誤り** (filter はボードの定義そのものであり、廃止は本番データの破棄)、**(c)** 全面切替 (C-11) 前提なので並走で救済できない。DR-1 + DR-3。

**修正案**: §1.1 に「v2 のボード内容は `idea_boards.filter` 由来で、board-item テーブルは存在しない」を出典付きで**事実として記載**し、D-IB-x として「明示的アイテム集合を採る」判断 + 却下案 (filter 継続) + **移行手順 (既存 filter を `ListIdeasForBoard` 相当で評価して item 行へ materialize、評価時点のスナップショットになる旨)** を書く。IB-Q1 は「フィルタの要否」ではなく「materialize の基準時点と、以後 filter を廃止するか」に書き換える。

---

### 重大 3. `idea-boards.md` D-IB-2 の根拠が**事実誤り** — `UpdateBoardIdea` は `ideas` テーブルを更新している。memo/phase は v2 では**アイデア単位のグローバル値**

**該当**: `docs/design/API/idea-boards.md:120` (D-IB-2)

設計書の記述:
> v2 でも**この経路の `PUT` は `ideas` テーブルではなくボード上の属性を更新している** (`UpdateBoardIdea`)

**一次ソース**:

```
-- hassan-v2-backend/db/queries/idea_board.sql:64-67
-- name: UpdateIdeaMemoPhase :exec
UPDATE ideas
SET memo = $2, phase = $3, updated_at = CURRENT_TIMESTAMP
WHERE id = $1;
```

`hassan-v2-backend/usecase/idea_board/update_board_idea.go:58` が `uc.ibr.UpdateIdeaMemoPhase(ctx, input.IdeaID, input.Memo, input.Phase)` を呼ぶ。
カラムは `ideas.memo text` / `ideas.phase text` (`hassan-v2-backend/db/schema.sql:173-174`)。

**なぜ本番で問題になるか**: 記述は事実と逆であり、それが `/items` 改名 (D-IB-2) の**唯一の根拠**として置かれている (DR-1)。
さらに正しい事実からは、設計に無い 2 つの帰結が出る:

1. **v2 では memo/phase がアイデア単位のグローバル値**なので、同じアイデアが 2 つのボードに現れると memo/phase が共有される。v3 は item 単位に持つため**意味が変わる** (移行時にどのボードの item へ写すかの決定が必要)。
2. **`ideas.phase` は phase の「名前」を持つ text**。`RenameIdeasPhaseLabelForContract` (`hassan-v2-backend/db/queries/idea_board.sql:49-56`) が契約内の `ideas.phase` を一括リネームしている。v3 は `phase_id` (FK) を使うため、**既存 `ideas.phase` の text → `idea_board_phases.id` への写像が移行に必要** (`uq_idea_board_phases_contract_id_name` があるため名前一致で写像可能)。この移行が設計に無い (DR-3)。

**修正案**: D-IB-2 の根拠文を正しい事実 (`UPDATE ideas SET memo, phase` — 出典付き) に差し替え、改名の理由を「同一 URL が 2 概念を指す」だけに絞る。§3.1 の逸脱表に「memo/phase のスコープ変更 (アイデア単位 → item 単位)」と「`ideas.phase` text → `phase_id` の写像」を移行影響として追記する。

---

### 重大 4. `knowledge.md` D-KN-10 / `README.md` D-API-14 — 「v2 に S3 の前例あり」の引用が**意味的に誤り**。v2 の実装は `public-read` ACL + 恒久公開 URL であり、機密ファイルをそのまま載せると認証なしで読める

**該当**: `docs/design/API/knowledge.md:120` (D-KN-10「**v2 も S3 の URL を返す方式** (`hassan-v2-backend/aws/s3.go:41-72`)」)、`docs/design/API/README.md:99` (D-API-14「保存先は S3 (`hassan-v2-backend/aws/s3.go` に前例)」)、`docs/design/API/assets.md:65`

**一次ソース** (`hassan-v2-backend/aws/s3.go:41-58`):

```go
func (s3Client *S3Client) uploadFile(ctx context.Context, key string, imageData []byte, contentType *string) (string, error) {
	input := &s3.PutObjectInput{
		Bucket: aws.String(s3Client.bucketName),
		Key:    aws.String(key),
		Body:   bytes.NewBuffer(imageData),
		ACL:    types.ObjectCannedACLPublicRead,     // ★ 公開読み取り
	}
	...
	return fmt.Sprintf("https://%s.s3.amazonaws.com/%s", s3Client.bucketName, key), nil  // ★ 恒久・無署名 URL
}
```

- **`Presign` / `presign` の参照は `aws/` `usecase/` `controller/` に 0 件** (grep)。**v2 に署名付き URL の実装は存在しない**。
- v2 の用途はアイコンと企画書サムネイル (`UploadIcon` `:61-64`、`UploadBusinessPlanThumbnail` `:66-70`) であり、公開前提の画像。

**なぜ本番で問題になるか**: v3 が S3 に置くのは**ヒアリング議事録・技術資料・アセット添付**という機密データ。
D-KN-10 は「署名付き URL + `expires_at`」という正しい判断をしているが、**根拠として提示された v2 の前例は真逆の実装**であり、実装者が「前例に倣う」と `ObjectCannedACLPublicRead` をコピーして**認証なしで URL を知る誰でも読める状態**になる。A-3 / A-6 の境界がストレージ層で崩れる形で、`auth.md` §2.2 の `asset_documents` 問題 (本文がテナント境界の外) と同じ事故を新規に作る。

**修正案**: (a) D-KN-10 / D-API-14 の引用を「**v2 の `aws/s3.go:46` は `ObjectCannedACLPublicRead` を付け恒久公開 URL を返す。v3 はこれを踏襲しない (逸脱)**」と明示的な逸脱として書き換える。(b) 「バケットは非公開・ACL を付けない・GET は presigned URL のみ・`expires_at` の既定値は定数 1 箇所 (D-API-7 と同じ SSOT)」を決定として書く。(c) presign は v2 に前例が無い新規実装であることを実装リポ引き渡し (§6.2) に明記する。

---

### 重大 5. `README.md` §2.5 — **AC-1.4 の SSOT である 403/404 の一覧が内部矛盾**しており、`idea-boards.md` の 403 (4 本) を規約が禁止している

**該当**: `docs/design/API/README.md:176-189`、`:358`、`:361`、`:344-349` / `docs/design/API/idea-boards.md:66,67,74,76,149` / `docs/design/API/settings.md:60-62,64,146`

矛盾の内訳:

| # | README の記述 | 他ファイルの実態 |
|---|---|---|
| a | `:177` 「自契約だが**個人スコープの他人のリソース**を更新・削除 → **404**。**書き込みは作成者のみ**を既定とする」 | `idea-boards.md:66,67` は `PUT`/`DELETE /idea-boards/{board_id}` を**作成者以外 403**。**同一状況に 404 と 403 の 2 規則**が並立 |
| b | `:186` 「**403 を使うのは §2.2 のロール不足のみ**」 / `:361` 「403 はロール不足のみ」 | `idea-boards.md:149` は「403 はボード作成者限定操作とコメント投稿者限定操作の 2 種類」= **README が禁じた用途で 4 本**が 403 |
| c | `:179` 「§2.2 の **1 種類** (settings.md §3 の **2 本**)」 / `:358` A-2「契約内管理者限定は **2 本**」 | `settings.md:64` 「契約内管理者限定の **3 本**」 / `settings.md:146` 「403 は §3.1 の **3 本**のみ」 |
| d | `:344-349` 総覧で 403 マークは `/usage-summary` と `/activity-logs` の 2 本のみ | `settings.md:60` は `PUT /settings/workspace` にも **403** |
| e | `idea-boards.md:126` 「この 403 は README §2.5 の**「自テナントだが操作権限が無い」に該当**」 | README §2.5 に**その行は存在しない** (存在するのは `auth.md` §6.6) |

**なぜ本番で問題になるか**: 本成果物が回答すると宣言している **AC-1.4 (401/403/404 の使い分けの一覧化)** そのものが破綻している。
`auth.md` §4 / §5-3 が「v2 の頻出バグ = 403 と 404 の取り違え」を明示し、README §2.5 は「これを構造的に消す」と書いているが、**実装者は同じ状況 (自契約・他人のリソースへの書き込み) について 404 と 403 の 2 つの指示を受ける**。D-API-6 の単一マッピングテーブルはコード → HTTP の対応であり、この矛盾を機械検出できない。

**修正案**: README §2.5 に **`auth.md` §6.6 の「自テナントだが操作権限が無い → 403」に対応する行を追加**し、「リソース所有権に基づく操作制限 (ボード作成者・コメント投稿者)」を 403 の第 2 用途として明記。`:177` の 404 行は「**読み取り可能性が無いリソース**への書き込み」に限定して 403 との判定境界を書く (例: 個人スコープのテーマ = 404 / 契約スコープで読めるボード = 403)。件数表記 (1 種類 / 2 本 / 3 本) を **settings.md 3 本 + idea-boards 4 本 = 7 本**に統一し、総覧 §3.6 の `PUT /settings/workspace` に 403 を付ける。

---

### 重大 6. `themes.md` / `assets.md` — `scope=contract` の**許可条件が未定義**。v2 は `sharing_settings` でゲートしており、増分 1 では per-theme visibility も無いため、共有 OFF の契約でテーマ・アセットが契約内に一斉露出する

**該当**: `docs/design/API/README.md:93` (D-API-8)、`:145-154` (§2.3)、`docs/design/API/themes.md:45-46,88,121`、`docs/design/API/assets.md:50,54,56,59,64,96,127`、`docs/design/API/settings.md:94` (D-ST-3)

**一次ソースで確認した v2 の実態**:

| 事実 | 出典 |
|---|---|
| `sharing_settings(contract_id, category, is_shared)` PK(contract_id, category) — **契約 × カテゴリ単位の ON/OFF** | `hassan-v2-backend/db/schema.sql:491-499` |
| テーマ一覧: `is_shared == false` なら `accountIDForList` を**認証ユーザーへ強制**し、契約スコープ経路に入れない (コメント「レコード未作成時は false 扱い」= **既定は非共有**) | `hassan-v2-backend/usecase/theme/list_themes.go:42-52` |
| アセット一覧: `(useContract \|\| accountID != input.AccountID) && !isShared` なら `SharingSettingDisabled` → Controller が **403** | `hassan-v2-backend/usecase/asset/list_assets.go:71-79`、`hassan-v2-backend/controller/asset.go:119-120` |
| ボード一覧のみ「共有された viewer/editor は `sharing_settings` をバイパス」 | `hassan-v2-backend/usecase/idea_board/list_idea_boards.go:44-47` (コメント `:45`) |

**なぜ本番で問題になるか**:

1. v3 の `scope=contract` は**無条件に契約全体を返す設計**として書かれている (`themes.md:121` 「`scope=contract` のときは `contract_id`」/ `assets.md:127` も同旨)。**共有の可否を決めるゲートが設計のどこにも無い**。
2. `themes.md` の per-theme `visibility` (D-TH-3) と `PUT /visibility` は **増分 2** (`:51-53`, D-TH-5) だが、`GET /themes?scope=contract` は**増分 1**。したがって**増分 1 には絞り込む属性が存在しない** = 契約内の全テーマが見える。
3. `assets.md` には **`visibility` / 可視性 / 共有 の記述が 1 箇所も無い** (grep 0 件)。一方 `settings.md` D-ST-3 は `default_asset_visibility` を新設し ST-Q5 で「v2 の既存共有 ON/OFF は移行対象」としている。**設定を書く側だけがあり、それを適用するフィールド (アセットの `visibility`) と読む側が存在しない** — BE-10 (読む側と書く側を対で設計する) の再発形。
4. 全面切替 (C-11) のため、既定 OFF (v2 のコメントで確認) の契約が切替と同時に契約内公開へ変わる。DR-3。

**修正案**: (a) D-API-8 に「`scope=contract` が許されるかを何が決めるか」を書く。候補: (i) v2 の `sharing_settings` 相当 (契約 × カテゴリの ON/OFF) を v3 に引き継ぎ、OFF なら `scope=contract` を **403** or 空一覧、(ii) per-resource `visibility` のみで判定 (この場合 visibility を**増分 1** に前倒しし、既定を `private` とする)。(b) `assets.md` の `Asset` / `POST /assets` / `PUT /assets` に `visibility` を追加し `default_asset_visibility` の適用先を明示する (または D-ST-3 を先送りにする)。(c) いずれの案でも **v2 の `sharing_settings` 既存値をどう写すか**を ST-Q5 から本文の移行手順へ昇格させる。

---

### 重大 7. 非同期 3 経路 (202 / `processing`) の**実行主体・再実行・進捗配信の一貫性が全ファイルで無言**。設計入力 (`design_memo.md`) が要求している「失敗時再実行の保証」に回答が無い

**該当**: `docs/design/API/assets.md:61-63` (`POST /asset-extractions` 202 → `GET /{id}` → `GET /{id}/stream`)、`:91` (D-AS-3)、`docs/design/API/knowledge.md:62,119` (`POST /knowledge-files` 201 + `status:"processing"`、D-KN-9)、`docs/design/API/README.md:97` (D-API-12)、`:368` (O-5)

`docs/design/API/` 配下で ワーカー / worker / キュー / queue / SQS / バックグラウンド / goroutine への言及は **0 件** (grep)。一方、設計入力側には決定がある:

- `docs/design/design_memo.md:133` 「エージェント実行は Anthropic 側のため Go サーバの主負荷は接続保持 — **ワーカー分離は初期不要**」
- `docs/design/design_memo.md:136` 「アセット AI 抽出 (PDF/CSV/URL) は PoC の status 状態機械 + **失敗時再実行の保証** (デプロイで処理が死んでも復旧可能)。**ジョブキューは初期導入しない**」

**なぜ本番で問題になるか**:

1. **`running` のまま取り残されるジョブの回収規則が無い**。`assets.md:62` の値域は `queued`/`running`/`succeeded`/`failed` だが、ECS のタスク入れ替え (D-3) でプロセスが消えたジョブは永久に `running` のまま残る。`design_memo.md:136` が名指しで要求している「デプロイで処理が死んでも復旧可能」に対する回答が無い (タイムアウト・再実行・冪等キーのいずれも未定義)。
2. **`GET /asset-extractions/{id}/stream` が別タスクに着地すると進捗が流れない**。ジョブがタスク A のプロセス内で走る (= キュー無し) 前提なら、ALB がタスク B に振った SSE 接続は進捗イベントを一生受け取らない。`architecture.md` §8 が「v2 prod は desiredCount 1」と記録しているとおり現状は偶然成立するが、v3 のタスク数は未決 (同 §8 の残課題)。
3. 「対象外」でも「先送り」でもなく**無言の省略**であり、DR-2 の定義に該当する。O-5 の先送りは「イベント名・再接続・タイムアウト」に限られ、実行基盤は含まれていない。

**修正案**: (a) `assets.md` §2.1 / `knowledge.md` D-KN-9 に「非同期処理はキュー無し (`design_memo.md:136`) の in-process 実行を前提とする」と**前提を明記**し、(b) **`running` の失効判定 (`updated_at` からの経過時間) と再実行の冪等性** (BE-11 と同じ観点) を決定として書く、(c) **SSE 進捗を単一タスク前提にするのか、共有ストア (DB の progress 列) をポーリングして配信するのか**を決める (後者なら複数タスクで成立し、`GET /{id}` と同じ経路で済む)、(d) 決めない部分は `docs/design/observability.md` / `operations.md` のどちらが担うかを ID 付きで先送りする。

---

## 中 (Should Fix)

### 中 1. O-2 — LLM 経路の本数が文書間で不一致。埋め込み生成が「LLM 列」に現れていない

`README.md:365` は「計測対象となる LLM 経路を **2 本に特定**した (`POST /asset-extractions`, `POST /knowledge-threads/{thread_id}/messages`)」とするが、`knowledge.md:180` は「**埋め込み生成も LLM API 呼び出しであり計測対象に含める** (D-KN-9)」と書いている。
`knowledge.md:62` の `POST /knowledge-files` の **LLM 列は「—」** であり、README 総覧 `:243` も knowledge の LLM を 1 と数えている。
O-2 の失敗形はまさに「経路の見落とし」であり、**表の LLM 列が実装者の唯一の索引**になる。`POST /knowledge-files` の LLM 列を ✓ にし、README §3 総覧と §4 O-2 の本数 (3 本) を揃えること。あわせて KN-Q4 (候補質問) / KN-Q6 (タイトル自動生成) が LLM 化された場合に本数が増える旨は既に書かれており、これは良い。

### 中 2. `idea-boards.md` IB-Q5 / `/idea-board-phases` — v2 の `idea_board_phases` は**色カラムを持ち**、`order` は無く、`UNIQUE(contract_id, name)` があり、v2 は**upsert** している

一次ソース (`hassan-v2-backend/db/schema.sql:615-625`): `color_code text NOT NULL DEFAULT '#0455C5'`、`CONSTRAINT uq_idea_board_phases_contract_id_name UNIQUE (contract_id, name)`、**`order` 相当のカラムは無い**。
`hassan-v2-backend/db/queries/idea_board.sql:38-42` (`UpsertIdeaBoardPhase` — `ON CONFLICT (contract_id, name) DO UPDATE SET color_code = ...`) (**同名は upsert**)。

- `:164` IB-Q5「色カラムがあるかは未確認」/ `:45`「色カラムの有無は data-model で確認」→ **1 行の grep で確定できる。未確認のまま残さない** (名前は `color_code`。API 側 `color` との対応を書く)
- `:78-79` の `order` は**新規カラム**である旨が明示されていない (v2 に無い)
- `POST /idea-board-phases` の固有ステータスが **201 のみ**。UNIQUE 制約が本番データに実在するため **409 が必要** (README §2.5 の「一意制約との衝突 → 409」の適用漏れ)。`PUT /idea-board-phases/{phase_id}` も同様。加えて **v2 は同名を upsert している**ため、409 に変える判断を逸脱として書くこと

### 中 3. `idea-boards.md` IB-Q3 — v2 のボード可視性は**メンバー限定で確定できる** (1 ファイルで判明)。結論は D-IB-11 を支持する

`hassan-v2-backend/usecase/idea_board/list_idea_boards.go:29-44` は `ListIdeaBoardsByContractID` (= `WHERE contract_id = $1`、`hassan-v2-backend/db/queries/idea_board.sql:9-12`) で全件取得した後、**`if b.HasAccess(input.AccountID)` で絞っている** (`hassan-v2-backend/entity/idea_board.go:113-115`)。
したがって v2 の挙動は「**メンバー (作成者/editor/viewer) のボードのみ**」であり、D-IB-11 の採用案と一致する = **切替でボードが見えなくなる懸念は発生しない**。
IB-Q3 を「確認済み: v2 もメンバー限定 (出典 2 件)」に書き換え、D-IB-11 の却下案 (b) を削除すること (要確認を 1 件減らせる)。

### 中 4. `idea-boards.md` §4 A-3 / D-IB-7 — `ideas` テーブルの所有者列と `is_deleted` に触れていない

`ideas` は `account_id` / `contract_id` を持たず、`idea_hassan_id → idea_hassans.account_id` の **2 段チェーン**で所有者に到達する (`hassan-v2-backend/db/schema.sql:151-152`、`docs/design/auth.md` §2.2 / §2.3 と一致)。また **`is_deleted` カラムは無い**。
本ファイルは `/ideas` 3 本を定義し `PUT /ideas/{idea_id}/star` を個人スコープ、D-IB-7 で「アイデアは**論理削除**」を前提にしているが、A-3 の回答 (`:147`) は `idea_boards` / `idea_board_phases` / `idea_board_items` / `idea_board_comments` のみを列挙し、**`ideas` の所有者列 1 段化 (auth.md §6.3) と `is_deleted` 追加が新規である事実**が書かれていない。Q-1 待ちで確定できないのは妥当だが、**「`ideas` は v2 で 2 段チェーン + `is_deleted` 無し。1 段化と論理削除列の追加が必要」を事実として記載**し、data-model へ ID 付きで渡すこと。

### 中 5. `auth.md` §7 の A-7 が「対象外 (暫定)」のまま — 2 つの SSOT が食い違ったまま並立している

`docs/design/auth.md:475` は A-7 を「**対象外 (暫定)** 本増分では共有機能を持たない」とするが、`idea-boards.md:151` は「**回答**: ボードは v2 の契約内共有をそのまま引き継ぐ」と書いている。
README §5 の **API-Q3** で正しく flag されており、確定先も「auth.md の A-7 判断の更新 (要ユーザー確認)」と明示されているのは良い。ただし `auth.md` §8 が今回「訂正済み (完了)」に更新された一方で **A-7 行には前方参照が無い**ため、`auth.md` を単体で読む実装者は「共有なし」と結論する。`auth.md` §7 の A-7 行に「**ただし `API/idea-boards.md` §4 が既存データを理由に異なる判断を提案している (API-Q3)**」の 1 行を足すこと (A-5 について §8 で行ったのと同じ扱い)。

### 中 6. `knowledge.md` §2 `POST /knowledge-threads/{thread_id}/messages` — SSE 経路のエラー表現が README §2.5 と噛み合っていない

`knowledge.md:58` は固有ステータスに **502 (LLM 失敗)** を挙げているが、同じ行のレスポンスは `text/event-stream` である。`architecture.md` §3 の「迷いやすい 3 点」3 が「Controller は既に 200 を返し始めているため、**エラーイベントを SSE で送って正常終了させる** (HTTP ステータスでの表現は不可)」と決めている。
したがって**ストリーム開始後の LLM 失敗は 502 では表現できない**。「ストリーム開始前 (スレッド取得・スコープ確定まで) の失敗は 502、開始後は SSE の error イベント」に分けて書くこと。`assets.md:63` の `GET /asset-extractions/{id}/stream` (200/404) も同じ観点で、開始後の失敗表現を明記すると良い。

### 中 7. `README.md` §1.3 の機械強制表に **D-API-5 / D-API-8 / D-API-2 の検査が無い**

§1.3 は「D-API-3 / D-API-6 / D-API-7 は宣言だけでは守られない」として 4 検査を挙げており、この姿勢は良い。ただし**同じ理由で守られない規約が漏れている**:

- **D-API-8 (`account_id` パラメータを置かない)** — 最も事故が大きい規約 (F-15 の再発防止) なのに検査が無い。`swagger.json` の全 query パラメータに `account_id` が現れないことを CI で検査できる (`GET /activity-logs` の `account_id` のみ許可リスト)
- **D-API-5 (`{items, total_count}` 統一)** — レスポンススキーマの機械検査が可能
- **D-API-2 (パスパラメータ `{<単数>_id}`)** — ルート定義の正規表現検査が可能

D-API-13 で `swagger.json` をコミットする決定があるため、上記はすべて**コミット済み JSON に対する検査として実装できる**。§1.3 に追記すること。

---

## 軽微 (Nice to Have)

1. **行番号ズレ (v2)**: `README.md:69` / `:96` の `hassan-v2-backend/controller/asset.go:104` → 実際は **`:102`** (`RequestAccountID: c.Query("account_id")`)。`README.md:64` の `同:78` (limit 全件コメント) → **`:79`**、`同:74` (keyword) → **`:75`**。`README.md:58` の `controller/theme.go:136` (BindJSON) → **`:137`** (`badRequest` は `:139`)。
2. **行番号ズレ (プロトタイプ)**: `themes.md:134` TH-Q1 のエクスポートボタン `:4916` → 実際は **`:4918`**。`assets.md:110` の URL 5 件上限 `:9553` → 実際は **`:9557`** (`_newAssetState.urls.length < 5`)。`assets.md:144` AS-Q4 の注意書き `:9536` → **`:9544`** (§3.1 が引く `:9544` が正しい)。`knowledge.md:131` の許可拡張子 `:10804 付近` → **`:10793`** (`const allowedRe = /\.(pdf|docx?|pptx?|xlsx?|csv|txt|md)$/i`)。
3. `knowledge.md:131` の許可拡張子リストに **`.xls`** が漏れている (プロトタイプの `xlsx?` は `.xls` も通す)。実装で allow-list を確定する際に落とさないこと。
4. `README.md:365` O-2 の「会話型アイデア創出の経路は対象外ファイルが担う」は良い書き方。同様に **`GET /companies/genai` (v2 の Dify 経路。`settings.md:133`)** も O-2 の対象外理由として README §4 O-2 に 1 行あると索引が閉じる。
5. `idea-boards.md:82` `GET /ideas/{idea_id}` のスコープが「個人 / 契約」だが、`scope` はパスパラメータを持つ単体取得では意味を持たない (README §2.3 の表記凡例では `scope` パラメータ前提)。単体取得の可視性判定規則 (契約内で読めるのはどの条件か) を 1 行で書くと曖昧さが消える。
6. `README.md:405` の依存順序図で `knowledge.md` が `assets.md` の後に来る理由は書かれているが、**`idea-boards.md` の `/ideas` 3 本が「会話型アイデア創出の設計」に依存する**関係が図に現れていない (§6.1 の箇条書きにはある)。図に破線で足すと引き渡し時に読み違えにくい。

---

## 本番観点カバレッジ (`08-production-gates.md`)

| ID | 状態 | 箇所 / 指摘 |
|---|---|---|
| A-1 認証方式 | **回答あり** | `README.md` §2.1 / D-API-3。全 73 本が認証必須、公開は `GET /alive` のみ。各ドメインファイル §4 で本数も一致 (9/17/15/21/5/6)。**問題なし** |
| A-2 ロール | **回答あり (要修正)** | `README.md` §2.2 / `settings.md` §3.1。本数が 1 種類 / 2 本 / 3 本で不一致 (**重大 5c/5d**)。ボードのロールは v2 の 3 段を落としている (**重大 1**) |
| A-3 テナント境界 | **参照 + 部分回答** | `README.md` §4 (auth.md §6.3 へ委譲)。各ドメインの新テーブルに所有者列を明記。`ideas` の 2 段チェーンと `is_deleted` 不在が欠落 (**中 4**) |
| A-4 絞り込みの層 | **回答あり (要修正)** | `README.md` §2.3 / D-API-8。UseCase 確定 → Repository の WHERE で強制、`account_id` パラメータ廃止は妥当。**`scope=contract` の許可条件が未定義** (**重大 6**)。機械強制に D-API-8 の検査が無い (**中 7**) |
| A-5 ステータスコード | **回答あり (内部矛盾)** | `README.md` §2.5 (= AC-1.4)。**403/404 の規則が矛盾** (**重大 5**)。フェーズ一意制約の 409 漏れ (**中 2**)。SSE 開始後の 502 (**中 6**) |
| A-6 LLM への越境 | **回答あり** | `knowledge.md` §4 が本成果物の中心的回答。①LLM 出力の `file_id` を引用に採らない ②スコープ外は「該当なし」 ③他人の `file_id` 紐付けは 404 — **AC-1.3 に対して十分**。`assets.md` §4 A-6 も抽出ソースを所有者検証済み `document_ids` に限定。**問題なし** |
| A-7 共有・公開 | **部分回答 (SSOT 不整合)** | `README.md` API-Q3 で食い違いを明示しているのは良い。`auth.md` 側に前方参照が無い (**中 5**)。v2 の viewer/editor が落ちている (**重大 1**)、`sharing_settings` の扱い未定 (**重大 6**) |
| O-1 構造化ログ | **参照** | D-API-6 の `request_id`。フィールド定義は observability へ先送り (先送り先あり) |
| O-2 LLM 計測 | **回答あり (本数不一致)** | 経路の特定という正しいアプローチ。埋め込み生成が LLM 列に無い (**中 1**) |
| O-3 コスト | **先送り (理由あり)** | C-12 と整合。`GET /usage-summary` は件数のみでコストを含まない旨を明記。**問題なし** |
| O-4 失敗の可観測性 | **部分回答** | `assets.md` D-AS-11 の `failure.code` で切り詰め/パース失敗/タイムアウトを区別、502 で外部起因を識別。値域は observability へ先送り。**問題なし** |
| O-5 SSE / 長時間処理 | **先送り (範囲が不足)** | SSE の特定と一覧化は完了。切断時の復元 (`assets.md` §2.1) も良い。**非同期ジョブの実行主体・`running` の回収・進捗の複数タスク配信が無言** (**重大 7**) |
| O-6 監査ログ | **回答あり** | `GET /activity-logs` の新設。「v2 は `activity_logs` テーブルがあるのに参照 API が無い」は**照合して正しい** (`db/queries/activity_log.sql:2` は INSERT のみ、router に該当ルート無し)。記録項目は observability へ先送り |
| O-7 アラート | **対象外 (理由あり)** | 運用設計へ先送り |
| D-1〜D-8 | **対象外 (理由あり)** | ただし **D-2 のマージ条件に §1.3 の 4 検査**を要求しているのは良い設計。検査の追加は中 7 |
| D-5 (news) | **回答あり** | `news.md` D-NW-2 / §4。`NEXT_PUBLIC_MICRO_CMS_API_KEY` がクライアントバンドルに載り得る名前空間である指摘は**一次ソースで確認済み** (`hassan-v2-frontend/src/lib/microcms-server-client.ts`)。サーバに寄せる判断は妥当 |

**AC トレーサビリティ**: `make check-traceability` = 22/22 OK。AC-1.1 は `README.md` §2.1 + 各ファイル §4 A-1、AC-1.4 は `README.md` §2.5 + 各ファイルの固有ステータス列で参照されており、**宙吊り (DR-6) は無い**。ただし AC-1.4 の内容が矛盾している (重大 5) ため、「参照されている」=「満たされている」ではない。

**DR パターン**: DR-1 → **重大 3・重大 4** で該当。DR-2 → **重大 7**。DR-3 → **重大 1・2・3・6**。DR-4 → 該当なし (PoC 構造の持ち込みは無く、v2 規約に沿っている)。DR-5 → 「適切に」「必要に応じて」「後で検討」の判断ポイントでの使用は**発見されず**。DR-6 → 該当なし。DR-7 → **良好** (配線なし UI を要確認節へ隔離する方式が全ファイルで一貫。`settings.md:16-20` / `assets.md:37-39` / `knowledge.md:191` の「プロトタイプは根拠にならない」明示は模範的)。
**BE/FE**: BE-1/BE-4 → `D-IB-1` (参照 vs スナップショット) で構造的に潰している。BE-2 → `assets.md` §3.1 / `knowledge.md` §3.1 / D-API-7 / D-API-14 の SSOT 化で対応済み。BE-6 → D-KN-6 (b) / D-AS-11 で言及。BE-10 → **`default_asset_visibility` に読む側が無い形で再発 (重大 6-3)**、`ST-Q7` (Slack 設定に配信基盤が無い) は正しく自己検出している。BE-11 → `PUT /function-tree` の `version` 楽観ロック (D-AS-6) で該当箇所を潰している。FE-2 → D-ST-7 の変換層 1 箇所 + orval 2 系統。FE-6 → **D-IB-3 が `"B+・4.1"` の分解をサーバ側 1 回に寄せており、FE-6 を名指しで潰している (良い)**。

---

## 良かった点

1. **`knowledge.md` §4 (A-6 / AC-1.3)** — 呼び出しから引用生成までの各段でスコープをどう強制するかを図で示し、「LLM が出力した `file_id` を引用に採らない」「検索層の `account_id` を省略可能な引数にしない」という**実装で守れる形の不変条件**に落としている。本成果物で最も価値の高い節。
2. **DR-7 の扱いが一貫している** — 配線なし UI を「エンドポイント一覧」から外し「要確認」節に隔離するという方式を README §0 で宣言し、7 ファイル全部で守っている。`settings.md` §1 の「全セクションのボタンが配線なし → 確定できるのは表示項目までであり更新系の挙動は読み取れない」は、プロトタイプ由来の過剰確定を最もよく防いでいる記述。
3. **v2 の欠陥を「入力形で防ぐ」設計に翻訳している** — F-15 (テーマ一覧の契約一致検証欠落) を「検証を書き忘れないようにする」ではなく「**`account_id` パラメータをそもそも受け取らない**」(D-API-8) に変換したのは、`auth.md` §5-1 の教訓の正しい適用。一次ソース照合でも F-15 の記述内容 (テーマ側は `GetAccountByID` の存在確認のみ / アセット側は `input.ContractID != account.ContractID` を検証) は**正確**だった。
4. **§1.3 の機械強制表** — 規約を「気をつける」に落とさず CI 検査として列挙し、D-2 のマージ条件へ接続している。設計書がハーネスに接続されている稀な例。
5. **事実の出典密度が高い** — 約 70 件の抜き取り照合で、行番号ズレ 6 件・意味的誤り 2 件。特に `news.md` の MicroCMS 構成 (FE の server action が SDK を直接呼ぶ / `GET /news` は `has_unread` だけを返す / Webhook の HMAC 検証 / `read_news_accounts` の複合主キー) は **BE・FE・schema の 3 リポジトリにまたがって全件正確**だった。
6. **同種の判断の差分に理由が付いている** — 削除方式 (themes=物理 [D-TH-7] / assets=論理 [D-AS-7] / ideas=論理 [D-IB-7]) はいずれも v2 の実態と参照関係を根拠にしており、`assets.is_deleted` の実在 (`hassan-v2-backend/db/schema.sql:113`) と `themes` の物理削除 (`db/queries/theme.sql:32-33`) も照合で確認できた。HTML を返す/返さない (D-KN-6 vs D-NW-5) を**信頼境界の違い**で切り分けた説明も明快。
7. **`idea-boards.md` §6** — アイデア参照 API の配置理由と却下した配置を書いた上で「生成側が確定するまで読み取り専用」という制約を置いており、対象外ファイルとの境界が明確。

---

## 再レビューの条件

重大 1〜7 の修正後に再レビューする。特に **重大 1・2・3 (idea-boards の v2 実態との乖離)** は同一ファイルの同一節に集まっているため、`hassan-v2-backend/entity/idea_board.go` / `usecase/idea_board/` / `db/queries/idea_board.sql` / `db/schema.sql:599-627` を**一次ソースとして読み直したうえで §1.1 の対応表を作り直す**ことを推奨する (`poc-analyst` に `model: opus` で「v2 のアイデアボード機能の権限モデル・ボード内容の決定方式・memo/phase の格納先」を調査させるのが最短)。

---

## 検証コマンドの出力

```
$ make doc-lint
[doc-lint] 対象 52 ファイル / エラー 0 件 / 警告 18 件
（exit 0）

警告 18 件はすべて既存かつ本レビュー対象外:
  - 05-harness.md / design_memo.md / gap-analysis.md / architecture.md /
    questions.md / plan.md の未確定マーカー文字列 (規約説明・引用・design_memo の残課題)
  - auth.md の未回答 3 件 = Q-A1 / Q-A2 / Q-A3
  ※ 本ファイル追加後の再実行: 53 ファイル / エラー 0 件 / 警告 18 件 (本ファイル由来の警告 0 件)

$ make check-traceability
[traceability] productionization: 22/22 カバー — OK
[traceability] 照合 1 feature / 未カバーあり 0 feature
（exit 0）

$ 件数照合 (エンドポイント表の行数)
themes        9
assets       17
knowledge    15
idea-boards  21
news          5
settings      6
合計         73   ← README 総覧 §3.1-3.6 = 73 で一致
```

---

# 再レビュー (2026-07-29)

> 対象: 初回レビューの重大 7 / 中 7 / 軽微 6 に対する修正差分
> **最終判定: 重大 0 件 — 重大指摘はすべて解消。残るのは中 3 件 / 軽微 3 件 (いずれも新規に発見したもの)**

## 再レビューで実行した検証

```
$ make doc-lint
[doc-lint] 対象 54 ファイル / エラー 0 件 / 警告 18 件   （exit 0。本レビュー由来の警告 0 件）

$ make check-traceability
[traceability] productionization: 22/22 カバー — OK
[traceability] 照合 1 feature / 未カバーあり 0 feature   （exit 0）

$ 件数機械照合
  エンドポイント表: themes 9 / assets 17 / knowledge 15 / idea-boards 21 / news 5 / settings 6 = 73
  README 総覧 §3.1-3.6                                                              = 73  ← 一致
  403 の付いたエンドポイント行: idea-boards 4 / settings 3 = 7  ← README §2.5「合計 7 本」と一致
  README §3 総覧の LLM 列: 0+1+2+0+0+0 = 3  ← §4 O-2 の「3 本」と一致
  README §3 総覧の SSE 列: 0+1+1+0+0+0 = 2  ← 一致
```

**一次ソース照合: 新規追加された出典 26 件を照合。誤り 1 件** (下記の軽微 1)。

---

## 各重大指摘の解消判定

| # | 初回指摘 | 判定 | 根拠 (修正内容と照合結果) |
|---|---|---|---|
| **1** | ボード 3 段ロールの平坦化 | **解消** | `idea-boards.md` §1.0 **V-3** が v2 の 3 ロール・2 カラム・3 判定関数を出典付きで事実化。§2 の `GET /members` は `role` (`admin`\|`editor`\|`viewer`\|`""`) を返し、`PUT /members` は **`{members:[{account_id, role}]}`** に変更 (v2 の `manage_board_members.go:52-53` と同形)。§3.1 に **8 操作 × 4 ロールの権限表**を新設し各行に v2 の判定関数 (`HasAccess` / `CanEdit` / `IsAdmin`) を対応付け。D-IB-8 は平坦化案を「**当初案・却下**」として明記。§4 **M-4** が「viewer を editor に昇格させない」を禁止事項として書き、検証を「(ボード, アカウント) → ロールの完全一致。**件数一致では不十分**」と規定。**表面的な文言修正ではなく、権限モデル・API 形・移行・検証方法の 4 点が揃っている** |
| **2** | ボード内容が filter 由来である事実の欠落 | **解消** | §1.0 **V-1** が「ボードの中身を保持するテーブルが存在しない」「`ListIdeasForBoard` に `board_id` が現れない」を出典付きで事実化。**D-IB-0** を新設し「実体アイテム採用」を却下案 (filter 継続 / 併存) 付きで判断。§4 **M-1** が materialize 手順を定義し、**旧単数キー形式の後方互換ロジックを移行スクリプトにも実装する**という非自明な要点まで押さえている。`filter` NULL のボードは「契約内全アイデアが対象」になる点も IB-Q9 として計測依頼に落としている。IB-Q1 は「フィルタ保存の要否」から「**動的 → 静的転換を受け入れるか**」に書き換えられ README API-Q6 と対応 |
| **3** | D-IB-2 の根拠が事実誤り | **解消** | D-IB-2 の根拠が「**v2 ではこの `PUT` が実際に `ideas` テーブルを更新している** (`UPDATE ideas SET memo = $2, phase = $3 WHERE id = $1` — `idea_board.sql:64-67`)」に差し替わり、**照合と一致**。派生する 2 つの帰結も設計に入った: §3.2 の逸脱 4 (memo/phase スコープ変更) → §4 **M-2** (全 item に複製 + 代償の告知 IB-Q10)、逸脱 5 (phase text → FK) → §4 **M-3** (名前照合 + 一致しない場合はログ出力し握り潰さない) |
| **4** | S3 の「v2 に前例あり」引用が意味的に誤り | **解消** | **D-API-14'** を新設。「非公開バケット + ACL を付けない + presigned URL のみ + `expires_at`」を決定とし、却下案に v2 の実装を**明示的な逸脱対象**として記載 (`ACL: types.ObjectCannedACLPublicRead` — `aws/s3.go:46`、恒久 URL — `同:58`、用途はアイコン `:62-65` / サムネイル `:68-71`、`Presign` 参照 0 件)。**照合結果と完全一致**。`knowledge.md` D-KN-10 は「当初は『v2 に前例あり』と書いていたが事実誤認だった」と自己訂正、`assets.md` D-AS-5 も「流用しない」を明記。README §6.2 は参照先を「クライアント初期化 (`:23-37`) と削除 (`:74-107`)」に限定し「`uploadFile` の ACL と恒久 URL は**流用禁止**」と書いた上で presign を「v2 に前例が無い新規実装」として別行に立てた |
| **5** | README §2.5 の 403/404 が内部矛盾 | **解消** | §2.5 冒頭に「**見えるか (取得できるか)**」を基準とする**判定境界表**を新設。§2.2 に **R-1 (契約内ロール) / R-2 (リソース単位ロール・投稿者)** の 2 系統を定義し、**403 = 合計 7 本 (R-1 3 + R-2 4)** に統一。初回指摘した 5 つの不整合すべてが消えた: (a) 404 行が「**個人スコープのドメイン** (themes/assets/knowledge)」に限定され idea-boards と衝突しなくなった (b)「403 はロール不足のみ」の断定を削除 (c) 件数を 3 本 (settings) に統一 — `settings.md` §3.1・§6 A-5、README §2.2・§2.5・§4 A-2/A-5 の全箇所で一致 (d) 総覧 §3.6 の `PUT /settings/workspace` に 403 を追記 (e) R-2 の行を §2.5 に新設 |
| **6** | `scope=contract` の許可条件が未定義 | **解消** | **F-16** を新設し `sharing_settings` の実在・既定 OFF・3 ドメインでの適用差 (テーマは自分へ強制 / アセットは 403 / ボードは viewer/editor がバイパス) を出典付きで事実化 (**照合と一致**)。**D-API-8'** が「`scope=contract` は増分 2。増分 1 は 400 で拒否」と決定し、`themes.md` §3.2 (TM-1/TM-2) と `assets.md` §3.2 (D-AS-12/13 + AS-M1〜M3) が「既存 `sharing_settings` から `visibility` 初期値を決めて**切替前後で見える範囲を変えない**」移行を規定。**BE-10 の指摘 (設定を書く側だけがある) は `assets.md` に `visibility` を新設し、`settings.md` の `default_asset_visibility` を増分 2 に移して「読む側と書く側を同じ増分に入れる」ことで構造的に解消** (README §6.1 の増分 2 作業単位にも明記)。増分 1 で `default_asset_visibility` を指定すると 400 という歯止めまで入っている |
| **7** | 非同期ジョブの実行主体・回収・進捗配信が無言 | **解消** | **§1.3 (D-API-15)** を新設し J-1〜J-7 で回答。設計入力を正しく引いている (`design_memo.md:133` / `:135` / `:136` — **照合と一致**)。指摘の核心 2 点が両方埋まった: **J-3** = `updated_at` を heartbeat とし閾値超過を `failed` + `failure.code = stale_aborted` に落とす (起動時 + 定期実行の 2 経路)、**J-6** = 「SSE ハンドラは DB の状態をポーリングする。ジョブ実行 goroutine と SSE 接続が同一プロセスにいることを前提にしない」(却下案で ALB のタスク振り分けと `desiredCount 1` を前提にできない点を明記)。J-5 の冪等キーは指摘に無かった追加改善。先送り部分 (定期実行の仕組み・閾値の最終値) は API-Q7 として確定先付きで残されている |

**中 7 件・軽微 6 件**: 中 1〜7 はすべて解消 (O-2 の 3 本統一 / D-IB-4' の `color_code`・`order`・409 / IB-Q3 を確認済みへ / A-3' で `ideas` の 2 段チェーンと `is_deleted` 不在を申し送り / `auth.md:500` の A-7 に前方参照追記 / SSE 開始前後の分離 / §1.4 に 8 検査へ拡張)。軽微は 5/6 解消 (残り 1 件は下記軽微 3)。

---

## 新規に見つかった問題

### 中 A. `README.md:129` (J-4) が、`knowledge.md` が明示的に却下したエンドポイントを再実行経路として名指ししている

- **README §1.3 J-4**: 「…`knowledge.md` は **`POST /knowledge-files/{file_id}/reprocess`**」
- **`knowledge.md:107-115`**: 「**`failed` のファイルは同じファイルを `POST /knowledge-files` に再アップロードする**」「**専用の再実行エンドポイントは設けない**」「却下 (a) `POST /knowledge-files/{file_id}/reprocess` を作る」

`POST /knowledge-files/{file_id}/reprocess` は README §3.3 の 15 本にも総計 73 本にも含まれない (grep で確認: 出現は README J-4 と knowledge.md の却下行のみ)。
**§1.3 は非同期ジョブ仕様の SSOT として宣言されている**ため、そこだけを読んだ実装者は存在しないエンドポイントを実装する。
**修正案**: J-4 の当該箇所を「`knowledge.md` は同じファイルを `POST /knowledge-files` へ再アップロード (専用の reprocess は設けない — `knowledge.md` §2.2)」に差し替える (1 行)。

### 中 B. `README.md` §2.5 の適用一覧に「viewer の書き込み権限不足 → 404」の行が無く、判定境界表だけを読むと 403 と読める

`idea-boards.md` §2 (`:90`, `:91`, `:92`) と §3.1 の権限表は **viewer の編集操作を 404** と明記しており、operative spec としては曖昧さが無い。しかし README §2.5 側は:

- 判定境界表 (`:225-229`) が「**見える (取得できる) + 操作権限 無し → 403**」と断言している。viewer にはアイテムが見える (`GET /items` が 200) ため、この表の規則を機械的に当てると **403**
- 404 行 (`:246`) は適用範囲を「**個人スコープのドメイン** (`themes.md` / `assets.md` / `knowledge.md`)」に限定しており、**idea-boards が含まれない**
- 403 行 (`:249`) は R-2 の 4 本のみを列挙しており viewer の編集は含まれない

つまり **README §2.5 の適用一覧に該当する行が 1 つ無い**。`idea-boards.md:186` は「`README.md` §2.5 の基準を適用」と書いているが、README の基準からは逆の結論 (403) が出る。
初回の重大 5 の**残余**であり、**AC-1.4 (401/403/404 の一覧化) に直結するため Design Freeze 前に閉じることを推奨**する。
**修正案**: §2.5 の適用一覧に 1 行追加 — 「**契約スコープで読めるリソースへの、リソース単位ロールによる『書き込み』権限不足 (board viewer) → 404** / 適用範囲: `idea-boards.md` の `POST`・`PUT`・`DELETE /items`」。あわせて判定境界表に「**閲覧専用ロールの書き込みは 404 に寄せる**」の但し書きを入れ、403 (リソース自体の管理権限不足) との切り分けを明文化する。

### 中 C. `themes.md` のメンバー API に読み書きの非対称が残っている (BE-10)

`themes.md:51` は `GET /themes/{theme_id}/members` が **`role` を返す**と書いているが、`:52` の `PUT /themes/{theme_id}/members` の body は **`{account_ids:[...]}`** で `role` を書けない。
`role` の値域も本文のどこにも定義されていない (TH-Q5 は「メンバーの権限差」を増分 2 の要件確認としているだけ)。
今回 `idea-boards.md` が `{members:[{account_id, role}]}` に揃えられた結果、**テーマ側だけが「読む側はあるが書く側が無い」状態**として残った — BE-10 (読む側と書く側を対で設計する) の形。
`idea-boards.md` IB-Q4 が「`themes.md` TH-Q5 と揃えるかも同時に判断する」と書いているのは正しい認識だが、**判断が出るまでは GET のレスポンスから `role` を外す**か、`PUT` を `{members:[{account_id, role}]}` に揃えるかのどちらかにしないと、増分 2 の実装者が値域を推測することになる (DR-5)。既存データが無い増分 2 の話なので重大ではない。

### 軽微 1. `hassan-v2-backend/db/schema.sql:618` は `name` であり、`color_code` は **`:619`**

`idea-boards.md` の 3 箇所 (`:63` §1.2 / `:160` D-IB-4' / `:305` IB-Q5) が `color_code` の出典を `:618` としているが、一次ソースは:

```
618:     name text NOT NULL,
619:     color_code text NOT NULL DEFAULT '#0455C5',
```

同じ行で引いている `uq_idea_board_phases_contract_id_name` の `:624` は**正しい**。新規追加された 26 件の出典のうち誤りはこの 1 件のみ (他 25 件は照合一致: `idea_board.sql:9-12`/`:32-36`/`:38-42`/`:49-56`/`:64-67`/`:80-140`、`entity/idea_board.go:14-16`/`:29-77`/`:44-77`/`:95-110`/`:113-115`/`:118-121`/`:124-126`、`list_idea_boards.go:28`/`:38`/`:44`/`:44-47`/`:52`、`manage_board_members.go:46`/`:52-53`/`:80-95`、`schema.sql:603-605`/`:624`、`aws/s3.go:46`/`:58`/`:62-65`/`:68-71`、`router.go:139-140`、`design_memo.md:133`/`:135`/`:136`)。

### 軽微 2. `README.md:456` の空行が API-Q 表を 2 つに分断している

`:449-455` (API-Q1〜Q5) と `:457-458` (API-Q6/Q7) の間に空行があり、後半が**ヘッダ行の無い別テーブル**としてレンダリングされる (API-Q6 の行がヘッダとして解釈される)。`:456` の空行を削除するだけで解消する。

### 軽微 3. `assets.md` に残る 2 件の小さな不整合

- `:50` `GET /asset-folders` は `scope` を受ける (「増分 1 は `mine` のみ」) のに、固有ステータス列が **`200` のみ**で `400` が無い。同じ性質の `GET /assets` (`:54`) は「200 / **400** (増分 1 で `scope=contract`)」と書いており不揃い
- `:177` AS-Q4 の特許明細書注意書きの出典が **`:9536`** のまま (同ファイル §3.1 の `:9544` が正しい行。初回レビューの軽微 2 で指摘したうち唯一未修正)

---

## 最終判定

**重大 0 件**。初回の重大 7 件はいずれも「文言の言い換え」ではなく、**事実の訂正 + 設計判断 (却下案付き) + 移行手順 + 検証方法**のセットで解消されている。特に評価できるのは:

- **`idea-boards.md` §1.0 (V-1〜V-3) の新設** — 「ここを読まずに実装すると既存データを壊す」という位置づけで v2 のデータモデルを 3 点に絞って先頭に置いた構成は、実装リポへの引き渡し物として最も効く形
- **§4 の移行手順 M-1〜M-4** — 入力・処理・却下案・検証方法・冪等性を各手順に持たせ、「**v2 のデータは読み取るだけで書き換えない**のでロールバックは v3 側を捨てるだけで成立する」という不変条件を明示した点。DR-3 への回答として過不足がない
- **`README.md` §1.3 (J-1〜J-7)** — 指摘した「無言の省略」を、設計入力 (`design_memo.md`) の該当行を引いた上で 7 論点の決定 + 却下案に展開した
- **BE-10 の潰し方** — `visibility` (読む側) と `default_asset_visibility` (書く側) を**同じ増分に入れる**という増分設計での解決は、パターン表の意図どおりの使い方

**Design Freeze の可否**: 重大ゼロなので `01-aidlc.md` の Design Freeze 条件 3 (重大事項ゼロ) は満たす。ただし **中 A (存在しないエンドポイントの記載) と 中 B (AC-1.4 の一覧に 1 行欠落)** はいずれも 1〜2 行の修正で閉じられ、かつ AC-1.4 と総覧の整合に直結するため、**Freeze 宣言の前に処理することを推奨**する (再レビューは不要。修正後 `make check` の再実行のみで足りる)。

---

## 最終修正の確認 (2026-07-29)

> 対象: 再レビューの中 A/B/C・軽微 1〜3 に対する修正差分
> **判定: 重大 0 件。中 A / 中 C / 軽微 1〜3 は解消。中 B は「判断」としては解消したが、
> 403 件数の更新が 4 箇所に伝播しておらず内部矛盾が残っている (中 1 件)**

### 実行した機械照合

```
$ 403 の付いたエンドポイント行数 (各ドメインファイルの表)
  themes 0 / assets 0 / knowledge 0 / idea-boards 8 / news 0 / settings 3   → 合計 11

$ idea-boards.md の 403 付きエンドポイント (実体 8 本)
  PUT /idea-boards/{board_id}                                   … admin 限定
  DELETE /idea-boards/{board_id}                                … admin 限定
  PUT /idea-boards/{board_id}/members                           … admin 限定
  DELETE /.../items/{item_id}/comments/{comment_id}             … 投稿者または admin
  POST /idea-boards/{board_id}/items                            … viewer の編集
  PUT /idea-boards/{board_id}/items/{item_id}                   … viewer の編集
  DELETE /idea-boards/{board_id}/items/{item_id}                … viewer の編集
  POST /.../items/{item_id}/comments                            … viewer の編集
  → README §2.2 R-2 の内訳「admin 限定 3 + 投稿者限定 1 + viewer の編集操作 4 = 8」と一致

$ make doc-lint            → 対象 54 ファイル / エラー 0 件 / 警告 18 件 (exit 0)
$ make check-traceability  → productionization: 22/22 カバー — OK (exit 0)
$ エンドポイント総数        → 9+17+15+21+5+6 = 73 = README 総覧 73 (一致を維持)
```

### 各指摘の解消判定

| # | 指摘 | 判定 | 確認内容 |
|---|---|---|---|
| **中 A** | README J-4 が却下済みエンドポイントを名指し | **解消** | `README.md:129` が「`knowledge.md` は**同じファイルの再アップロード** (`POST /knowledge-files`) — 専用の再実行エンドポイントは設けない (knowledge.md D-KN-9)」に修正済み。`reprocess` の出現は `knowledge.md` の却下行のみになり、総覧 73 本との齟齬も消えた |
| **中 B** | viewer の書き込み権限不足の扱いが README と idea-boards で食い違う | **判断は解消 / 件数の伝播に漏れ** | **403 統一という選択は妥当**。理由: ① viewer は対象を `GET` で取得できるため 404 に秘匿効果が無く、「取得できたものが更新では存在しない」という矛盾した挙動になる ② v2 自身が同じ状況で `IdeaBoardForbidden` = 403 を返している (`hassan-v2-backend/usecase/idea_board/update_board_idea.go:47-48` — 照合一致) ③ README §2.5 の判定境界表 (見える + 権限なし → 403) と `auth.md` §6.6 の双方と整合する。**初回レビューが指摘した「矛盾する 2 規則」が、SSOT 側 (403) に寄せる形で一本化された**。`idea-boards.md` §3.1 の権限表 (viewer 列が全編集操作で 403)・使い分け節 (却下案として「viewer を 404 にする」を明記)・エンドポイント表 8 行・§5 A-5・§3.2 (旧「逸脱 2」を削除し「権限違反のコードは逸脱ではない — v2 と同じ判断」の注記に置換) はすべて一貫。**ただし下記の残存 4 箇所**が未更新 |
| **中 C** | themes.md のメンバー API の読み書き非対称 | **解消** | `themes.md:51` の `GET /themes/{theme_id}/members` から `role` を削除し、「**`role` は持たない** — メンバーの権限差は未確定 (TH-Q5)。持たせる場合は `PUT` 側と対で追加する = BE-10」と注記。**読む側だけが存在する状態が消え、判断保留の理由と再開条件が明示された** — BE-10 の正しい扱い |
| **軽微 1** | `schema.sql:618` → `:619` | **解消** | `:618` の残存 0 件 / `:619` が 3 箇所 (§1.2・D-IB-4'・IB-Q5)。一次ソースは `619: color_code text NOT NULL DEFAULT '#0455C5'` |
| **軽微 2** | README API-Q 表の分断 | **解消** | `:449-457` が API-Q1〜Q7 の単一テーブルになった (空行なし) |
| **軽微 3** | assets.md の 2 件 | **解消** | `GET /asset-folders` の固有ステータスが「200 / **400** (増分 1 で `scope=contract`)」に統一 (`GET /assets` と同形) / AS-Q4 の出典が `:9544` に修正 (§3.1 と一致) |

### 新規に見つかった問題 (中 1 件)

#### 中 D. 403 = 11 本への更新が 4 箇所に伝播しておらず、README 総覧が「7 本 / 4 本」のまま

中 B の修正で 403 は **11 本 (R-1 3 + R-2 8)** になり、README のプロース側 (§2.2 の R-2 行 / §2.5 の 2 箇所 / §3 の注記 / §4 の A-2・A-5) と `idea-boards.md` は正しく 11 / 8 に更新されている。
しかし以下 4 箇所が旧値 (7 / 4) のまま残っている:

| # | 箇所 | 現状 | あるべき値 |
|---|---|---|---|
| 1 | `README.md` §3 総覧サマリ表 | idea-boards の **403 列 = 4**、**合計 = 7** | **8** / **11** |
| 2 | `README.md` §3.4 の総覧 | 403 マークが **4 エンドポイントのみ** (`PUT`/`DELETE /idea-boards/{board_id}` / `DELETE /comments/{comment_id}` / `PUT /members`)。**viewer の編集 4 本** (`POST /items` / `PUT /items/{item_id}` / `DELETE /items/{item_id}` / `POST /comments`) に 403 の注記が無い | 8 本すべてに 403 を注記 |
| 3 | `settings.md:81-82` | 「本ディレクトリの 403 は合計 **7 本** — 本節の 3 本 (R-1) と `idea-boards.md` §3.1 の **4 本** (R-2)」 | 11 本 / 8 本 |
| 4 | `settings.md:172` (§6 A-5 行) | 「ディレクトリ全体では **7 本** (`idea-boards.md` の **4 本**を含む)」 | 11 本 / 8 本 |

**なぜ問題か**: #1 は **`README.md:318` の「403 の 11 本 = §2.2 の R-1 (3 本) + R-2 (8 本)」という注記の直上の表**が 7 と書いている状態で、同一画面内で矛盾している。#2 は総覧が「どのエンドポイントが 403 を返すか」の索引として機能しなくなる (初回レビューで指摘した「総覧 ⇄ ドメイン表のマーク不一致」の再発形)。#3/#4 は初回レビューの重大 5c (件数が文書間で 1/2/3 本と食い違う) と同じパターンであり、**同じ種類の指摘が再発している**。

**修正案** (いずれも数値と注記の置換のみ。設計判断の変更を伴わない):

1. `README.md` §3 総覧サマリ表の idea-boards 行を `**8**`、合計行を `**11**` に
2. `README.md` §3.4 の該当 4 行に `(**403**: viewer は編集不可)` 相当の注記を追加
3. `settings.md:81-82` を「合計 **11 本** — 本節の 3 本 (R-1) と `idea-boards.md` §3.1 の **8 本** (R-2)」に
4. `settings.md:172` を「ディレクトリ全体では **11 本** (`idea-boards.md` の **8 本**を含む)」に

修正後は `grep -c 403` による件数照合 (本節の機械照合コマンド) で再確認できる。**再レビューは不要**。

### 最終判定

**重大 0 件 / 中 1 件 (中 D) / 軽微 0 件**。

初回レビューの重大 7 件・中 7 件・軽微 6 件、および再レビューの中 3 件・軽微 3 件は、**中 B の件数伝播を除いてすべて解消**した。
中 B の設計判断 (viewer → 403) は v2 の実装・README §2.5 の判定境界・`auth.md` §6.6 の 3 つと整合する形で一本化されており、**初回レビューで最も懸念した AC-1.4 の内部矛盾は解消している**。

**Design Freeze の可否**: `01-aidlc.md` の条件 3 (重大事項ゼロ) は満たす。
中 D は**数値 4 箇所の置換のみ**で設計判断を伴わないため、**修正 → `make check` の再実行 → Freeze 宣言**の順で進めて差し支えない。

---

## 中 D の修正反映 (2026-07-29・オーケストレーター追記)

指摘どおり数値・注記の置換のみを実施 (設計判断の変更なし):

1. `docs/design/API/README.md` §3 総覧サマリ表 — idea-boards の 403 列 4 → **8**、合計 7 → **11**
2. `docs/design/API/README.md` §3.4 — viewer 編集不可の 4 本 (`POST /items` / `PUT /items/{item_id}` / `DELETE /items/{item_id}` / `POST /comments`) に `(**403**: viewer 不可)` を追記 (§3.4 の 403 注記は 8 行)
3. `docs/design/API/settings.md` §3.1 の全体像 — 合計 7 → **11**、idea-boards 4 → **8**
4. `docs/design/API/settings.md` §6 A-5 行 — 7 → **11**、4 → **8**

検証: `make doc-lint` エラー 0 / `make check-traceability` 22/22 / 旧値 (合計 7 本・R-2 4 本) の残存 grep 0 件 /
README §3.4 の 403 注記 8 行と `idea-boards.md` §3.1・README §2.2 R-2 の内訳 (admin 限定 3 + 投稿者限定 1 + viewer 編集 4) が一致。

**最終状態: 重大 0 / 中 0 / 軽微 0** (レビュー指摘は全件解消)。
