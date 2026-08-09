# API: 企画書 (8 タブ・生成/再生成・版・お気に入り・チャット・詳細版・サムネイル)

  共通規約 (認証・レスポンス形・エラー・ページネーション・ステータスコード) の SSOT: [README.md](README.md)
  会話ターン・SSE イベント型・custom tool・台帳・`stage` の SSOT: [conversation.md](conversation.md)
> 要件の SSOT: [requirements-conversation.md](../../../aidlc-docs/inception/productionization/requirements-conversation.md)
> 必須観点 ID 一覧: [../../../.claude/rules/08-production-gates.md](../../../.claude/rules/08-production-gates.md)

## 0. 本書の範囲と、本書が回答する ID

### 0.1 範囲内 / 範囲外

| 区分 | 内容 | 所在 |
|---|---|---|
| **範囲内** | 企画書 (`plans`) のライフサイクル / 8 タブの生成・再生成 (SSE) / タブの手動編集 / タブ別の版と復元 / 版に紐づく生成指示の編集 / お気に入り / 企画書チャット / v2 詳細版 7 セクションの受け先 / サムネイル / **v2 企画書 18 エンドポイントの対応表** | 本書 |
| **範囲外 (別セッションが起草)** | アイデアの生成物 API・更新・版・評価・v2 アイデア系 13 本の対応表 | **[ideas.md](ideas.md)** (2026-08-02 起草済み) |
| **範囲外** | 会話セッション・会話ターン・SSE イベント型の値域・custom tool の契約 | [conversation.md](conversation.md) §1 / §4 / §5 |
| **範囲外** | 企画書まわりのテーブル定義そのもの | [../data-model.md](../data-model.md) §4.6 / §4.11 (本書は §12 の是正要求でのみ関与する) |
| **範囲外** | 安全弁の**数値**・失敗分類・監査ログの項目・単価テーブル | [../observability.md](../observability.md) §4.3 / §4.4 / §4.5 |
| **範囲外** | 層構成・ツール注入の内部構造・LLM 計測点の実装配置 | [../architecture.md](../architecture.md) §3.8 / §3.10 |

> **[ideas.md](ideas.md) へのリンク**: 起草時は同ファイルが並列起草中で存在しなかったため
> プレーンテキストで書いていたが、**2026-08-02 に両ファイルが揃ったためリンク化済み**。

### 0.2 対応する受入基準

**AC-CV-1.1 / AC-CV-1.3 / AC-CV-1.4 / AC-CV-4.1 / AC-CV-4.2 / AC-CV-4.3 / AC-CV-4.4 / AC-CV-4.5 /
AC-CV-4.6 / AC-CV-4.7 / AC-CV-4.8 / AC-CV-4.9 / AC-CV-6.1 / AC-CV-6.3**
(+ AC-1.1 / AC-1.2 / AC-1.4 / AC-2.1 / AC-2.3 / AC-2.5 の維持)

### 0.3 本書が回答する本番観点 ID

| ID | 回答節 |
|---|---|
| A-1 認証方式 | §1.1 (全 17 本が認証必須。方式の SSOT は [../auth.md](../auth.md) §6.1) |
| A-2 ロール | §1.1 (`AuthRoleUser` のみ。**403 を返すエンドポイントを持たない**) |
| A-3 テナント境界 | §9.2 / §7.2 / §12 (新規 2 テーブルはいずれも `contract_id` + `account_id` を持つ) |
| A-4 絞り込みの層 | §1.3 (UseCase がスコープを確定し Repository のクエリ条件で強制)。**`account_id` クエリを移植しない** (§11 の D-PL-13) |
| A-5 ステータスコード | §2.9 (**409 = 同一アイデアに企画書が既にある / 同一タブの生成が実行中**が新しい分岐) |
| A-6 LLM への越境 | §4.5 (3 入口すべてで所有者スコープの確定点が同じであること) |
| A-7 共有・公開 | §10.4 (`plans.visibility`。[../auth.md](../auth.md) §6.12 の 3 カテゴリの `business_plan` を受ける) |
| O-2 LLM 呼び出しの記録 | §4.6 (`feature` 値 3 種と、入口によって値が変わらないこと) |
| O-3 コスト集計と上限 | §4.7 (安全弁の適用点)。**上限による拒否は設けない** (C-12) |
| O-4 失敗の可観測性 | §4.8 (5 分類との対応 + 部分保存を作らない) |
| O-5 SSE / 長時間処理 | §4.4 (順序契約) / §4.9 (切断時の回復経路) |
| O-6 監査ログ | §10.5 (記録対象と項目の SSOT は [../observability.md](../observability.md) §4.5。本書は対象操作を確定させる) |
| O-1 / O-7 | **対象外** — [../observability.md](../observability.md) §4.1 / §4.6 が SSOT。企画書経路に固有のアラートは本増分で追加しない (先送り先: 同書 §4.6) |
| D-6 Agent ライフサイクル | §4.2 (P-4 の再発行対象性。手順の SSOT は [../operations.md](../operations.md) §5.2) |
| D-7 段階リリース | §12 の R-PL-7 (CV-D1 により M-8 が第 1 リリースへ移る)。切替段階の SSOT は [../operations.md](../operations.md) §6 |
| D-1〜D-5 / D-8 | **対象外** (インフラ・CI/CD は API 設計の範囲外。SSOT は [../operations.md](../operations.md) / [../infrastructure.md](../infrastructure.md)) |

---

## 1. エンドポイント一覧

**本節が回答する ID: A-1, A-2, A-4, A-5** / 対応 AC: **AC-CV-4.9, AC-CV-6.1, AC-CV-6.3**

### 1.1 一覧 (17 本)

すべて認証必須 (`X-Token`)・**すべて個人スコープ**・すべて増分 1・**403 を返すものは無い**。
共通の 400 / 401 / 500 は [README.md](README.md) §2.5 に従う。
ID の型は [../data-model.md](../data-model.md) §3.2 の規約 (機能テーブルの PK は `bigint`) に従い、
`tab_id` のみ**文字列 enum** (§4.1)。

| メソッド | パス | 概要 | 認証 | 所有者スコープ | 403 | SSE | LLM |
|---|---|---|---|---|---|---|---|
| GET | `/plans` | 一覧 (テーマ / アイデア / お気に入り / キーワード絞り込み) | 必須 | 個人 (`scope` は §10.4) | — | — | — |
| POST | `/plans` | 作成 (アイデアに対する企画書の器を作る。タブは未生成) | 必須 | 個人 | — | — | — |
| GET | `/plans/{plan_id}` | 取得 (**8 タブの最新版を同梱**。版一覧は含めない) | 必須 | 個人 | — | — | — |
| PUT | `/plans/{plan_id}` | メタ更新 (`visibility`) | 必須 | 個人 | — | — | — |
| DELETE | `/plans/{plan_id}` | 削除 (論理削除 = `deleted_at`) | 必須 | 個人 | — | — | — |
| POST | `/plans/{plan_id}/generate` | **8 タブの一括生成** | 必須 | 個人 | — | **✓** | **✓** |
| POST | `/plans/{plan_id}/tabs/{tab_id}/regenerate` | **タブの再生成** (`sections` / `instruction` を任意で受ける) | 必須 | 個人 | — | **✓** | **✓** |
| PUT | `/plans/{plan_id}/tabs/{tab_id}` | タブ本文の**手動更新** (新版を作る) | 必須 | 個人 | — | — | — |
| GET | `/plans/{plan_id}/tabs/{tab_id}/versions` | 版一覧 (**メタのみ**。本文を含めない) | 必須 | 個人 | — | — | — |
| GET | `/plans/{plan_id}/tabs/{tab_id}/versions/{ver_no}` | 版 1 件の取得 (**本文を含む**) | 必須 | 個人 | — | — | — |
| POST | `/plans/{plan_id}/tabs/{tab_id}/versions/{ver_no}/restore` | **復元** (対象版の内容で新版を作る) | 必須 | 個人 | — | — | — |
| PUT | `/plans/{plan_id}/tabs/{tab_id}/versions/{ver_no}/instruction` | 版に紐づく**生成指示の編集** | 必須 | 個人 | — | — | — |
| POST | `/plans/{plan_id}/favorite` | お気に入り登録 | 必須 | 個人 | — | — | — |
| DELETE | `/plans/{plan_id}/favorite` | お気に入り解除 | 必須 | 個人 | — | — | — |
| GET | `/plans/{plan_id}/chat/messages` | 企画書チャットの履歴 | 必須 | 個人 | — | — | — |
| POST | `/plans/{plan_id}/chat/messages` | **企画書チャット** (ブラッシュアップ相談) | 必須 | 個人 | — | **✓** | **✓** |
| POST | `/plans/{plan_id}/thumbnail` | **サムネイル生成** (画像生成) | 必須 | 個人 | — | — | **✓** |

- **LLM 経路は 4 本** (#6 / #7 / #16 / #17)、**SSE は 3 本** (#6 / #7 / #16)、**403 は 0 本**。
- **会話ターン経由の生成 (`generate_plan` tool) は本表に現れない** — 入口は
  [conversation.md](conversation.md) §1.1 の `POST /conversations/{session_id}/messages` であり、
  本書の #6 と**同じ UseCase を共有する** (§4.3)
- ページングの既定・上限は [README.md](README.md) D-API-7 に従う (本書に値を再掲しない)
- `tab_id` は §4.1 の 8 値のいずれか。値域外は **400**

### 1.2 v2 との差分 (共通規約からの逸脱がないことの確認。AC-CV-6.3)

| 規約 | 本書での適用 |
|---|---|
| D-API-2 (パス命名) | `/plans` (kebab-case + 複数形)。パスパラメータは `{plan_id}` / `{tab_id}` / `{ver_no}`。**ネストは 2 段まで**の規約に対し #11 / #12 は **3 段**になる — 逸脱と理由は §11 の D-PL-18 |
| D-API-4 / D-API-5 | 単一は裸オブジェクト、一覧は `{items, total_count}` |
| D-API-6 | `CodedError` 1 系統。コード値は本書に列挙しない (実装リポの `constants` が SSOT) |
| D-API-8 | **`account_id` クエリを持たない**。v2 は `GET /business-plans` に持っていた (`hassan-v2-backend/controller/business_plan.go:549`) — §11 の D-PL-13 |
| D-API-11 | 作成 201 / 更新 200 / 削除 204 |
| D-API-12 | SSE 3 本。ストリーム開始後の失敗は `error` イベント |
| D-API-14' | サムネイルは**非公開バケット + 署名付き URL**。v2 の public-read (`hassan-v2-backend/aws/s3.go:46`) を移植しない — §8 |

**規約の適用外にする項目は無い**。

### 1.3 所有者スコープの強制点 (A-4)

- Controller が `GetAuthenticatedAccount` から `account_id` / `contract_id` を取り出し UseCase の Input に詰める
- **UseCase がスコープを確定**し、`repository/plan` のクエリ条件に必ず渡す ([../auth.md](../auth.md) §6.4)
- `plan_id` / `idea_id` / `tab_id` / `ver_no` は**すべて所有者条件付きクエリの入力**として扱う。
  **存在確認 (行が nil でない) を所有権の検証に使わない** (A-4)
- 他人・他契約の企画書は **404** (403 にしない。[README.md](README.md) §2.5 の判定境界)

---

## 2. 各エンドポイントの入出力

**本節が回答する ID: A-5** / 対応 AC: **AC-CV-4.1, AC-CV-4.3, AC-CV-4.9**

### 2.1 オブジェクト定義

#### `Plan`

```json
{
  "id": 87,
  "idea_id": 412,
  "idea_title": "水素配管の常時モニタリングサービス",
  "theme_id": 12,
  "visibility": "private",
  "is_favorite": true,
  "thumbnail_url": "https://<bucket>.s3.../plans/87/thumb.jpg?X-Amz-Signature=...",
  "thumbnail_url_expires_at": "2026-08-01T10:12:00Z",
  "thumbnail_generated_at": "2026-07-31T08:00:00Z",
  "generated_at": "2026-07-31T07:55:00Z",
  "created_at": "2026-07-31T07:50:00Z",
  "updated_at": "2026-08-01T09:12:00Z",
  "tabs": [ "…PlanTab を 8 件。GET /plans/{plan_id} のみが返す…" ]
}
```

- `PlanSummary` (一覧用) は上記から **`tabs` を除いたもの**。8 タブ本文は 1 件で数百 KiB になり得るため一覧に載せない
- `thumbnail_url` は**保存された恒久 URL ではなく、応答のたびに発行する署名付き URL** (§8)。
  未生成なら `thumbnail_url` / `thumbnail_url_expires_at` / `thumbnail_generated_at` はいずれも `null`
- `idea_title` は `ideas.title` の写しであり **`plans` の列ではない** (同じ値を 2 箇所に持たない)

#### `PlanTab`

```json
{
  "tab_id": "market",
  "label": "市場",
  "ver_no": 4,
  "version_count": 4,
  "status": "ready",
  "content": { "…タブ別の構造化 JSON…" },
  "instruction": "TAM の根拠を国内統計で置き換えて",
  "sections": ["tam_sam_som", "growth_drivers"],
  "source_idea_version_id": 903,
  "source_deep_dive_entry_ids": ["8f1c…", "b204…"],
  "is_stale": true,
  "stale_reason": "idea_version_outdated",
  "created_at": "2026-08-01T09:12:00Z",
  "create_account_id": "…uuid…"
}
```

| フィールド | 意味 |
|---|---|
| `status` | **`empty`** (版が 1 件も無い) / **`ready`** (最新版がある) / **`generating`** (生成中。§4.9) / **`failed`** (直近の生成が失敗し版が増えていない) |
| `content` | `plan_tab_versions.content` の最新版。**タブごとに構造が異なる** (PoC の型を移植。§4.1) |
| `instruction` | その版を作ったときの**ユーザーの指示** (§5.1)。手動編集・初回生成では空文字 |
| `sections` | その版の生成で**更新対象にしたセクション** (§4.3)。全体生成では `null` |
| `is_stale` / `stale_reason` | 派生物の無効化 ([../data-model.md](../data-model.md) §4.11.3)。値域は §4.10 |
| `source_deep_dive_entry_ids` | grounding に使った台帳エントリ ([../data-model.md](../data-model.md) §4.11.2 の 3)。**空配列は「grounding 未使用」で `null` を使わない** |

#### `PlanTabVersion` (版一覧の 1 要素)

```json
{
  "ver_no": 3,
  "label": "競合の 2 社を差し替え",
  "instruction": "国内の類似サービスを 2 社追加して",
  "sections": ["competitors"],
  "origin": "regenerate",
  "restored_from_ver_no": null,
  "source_idea_version_id": 901,
  "is_stale": true,
  "created_at": "2026-07-31T11:04:00Z",
  "create_account_id": "…uuid…"
}
```

- **`content` を含めない** (§11 の D-PL-12)。本文は #10 で 1 件ずつ取る
- `origin` の値域: **`generate`** (一括生成) / **`regenerate`** (タブ再生成) / **`manual`** (手動編集) /
  **`restore`** (復元) / **`conversation`** (会話ターンの `generate_plan`)。
  **`entity/plan` の const 群 1 箇所に持つ** (リテラル直書きを禁止)

### 2.2 `GET /plans` — 一覧

| 項目 | 内容 |
|---|---|
| クエリ | `theme_id` / `idea_id` / `keyword` / `favorite`(`true` のみ意味を持つ) / `stale`(`true` のみ) / `scope` (§10.4) / `limit` / `offset` / `sort` |
| `keyword` の対象 | **`ideas.title` と `ideas.summary`** (企画書自身に表題列が無いため。§11 の D-PL-19) |
| `sort` の許可値 | `updated_at:desc` (既定) / `updated_at:asc` / `created_at:desc` / `created_at:asc` |
| 応答 | `{items: [PlanSummary], total_count}` / **200** |
| 固有ステータス | **400** (`sort` 許可外・`limit` 範囲外・`scope` の値域外) |

### 2.3 `POST /plans` — 作成

| 項目 | 内容 |
|---|---|
| ボディ | `idea_id` (**必須**) / `visibility` (任意。既定 `private`) |
| 応答 | `Plan` (`tabs` は 8 件すべて `status=empty`) / **201** |
| 固有ステータス | **400** (`idea_id` 欠落) / **404** (アイデアが他人 or 不存在) / **409** (**そのアイデアに企画書が既にある**。§11 の D-PL-1) |

- 409 の本文には既存の `plan_id` を含めない (`CodedError` の `message` のみ)。クライアントは
  `GET /plans?idea_id=` で取得する。**理由**: 他人のアイデアに対する 409 で ID が漏れる経路を作らない

### 2.4 `GET /plans/{plan_id}` / `PUT /plans/{plan_id}` / `DELETE /plans/{plan_id}`

| エンドポイント | 入出力 | ステータス |
|---|---|---|
| `GET` | R: `Plan` (`tabs` 8 件) | 200 / 404 |
| `PUT` | B: `visibility` (**必須**) — R: `Plan` (`tabs` 無し) | 200 / 400 / 404 |
| `DELETE` | — | **204** / 404 |

- `DELETE` は**論理削除** (`deleted_at`)。`plan_tab_versions` / `plan_chat_messages` / `plan_favorites` は
  物理削除しない (FK の `CASCADE` は親行の物理削除時のみ効く)
- **削除しても `UNIQUE (idea_id) WHERE deleted_at IS NULL` により同じアイデアに新しい企画書を作れる**

### 2.5 `POST /plans/{plan_id}/generate` — 8 タブの一括生成 (SSE)

| 項目 | 内容 |
|---|---|
| ボディ | `instruction` (任意。全タブに共通で渡す指示) |
| 応答 | `text/event-stream` (§4.4) |
| ストリーム開始前 | **200** (開始) / **400** / **404** / **409** (**同じ企画書で生成が実行中**) / **502** (Agent への接続自体が失敗) |
| 開始後の失敗 | SSE の `error` イベント ([README.md](README.md) D-API-12) |

### 2.6 `POST /plans/{plan_id}/tabs/{tab_id}/regenerate` — 再生成 (SSE)

| 項目 | 内容 |
|---|---|
| ボディ | `instruction` (任意) / `sections` (任意。`string[]`。§4.3) |
| 応答 | `text/event-stream` (§4.4) |
| ストリーム開始前 | **200** / **400** (`tab_id` 値域外・`sections` 値域外) / **404** / **409** (**同じタブの生成が実行中**) / **502** |

### 2.7 タブの手動更新と版

| エンドポイント | 入出力 | ステータス |
|---|---|---|
| `PUT /plans/{plan_id}/tabs/{tab_id}` | B: `content` (**必須**) / `label` (任意) — R: `PlanTab` | 200 / 400 / 404 / **409** (同じタブの生成が実行中) |
| `GET .../versions` | Q: `limit` / `offset` — R: `{items:[PlanTabVersion], total_count}` | 200 / 404 |
| `GET .../versions/{ver_no}` | R: `PlanTabVersion` + `content` | 200 / 404 |
| `POST .../versions/{ver_no}/restore` | B: `label` (任意) — R: `PlanTab` (新版) | **201** / 404 / **409** (同じタブの生成が実行中) |
| `PUT .../versions/{ver_no}/instruction` | B: `instruction` (**必須**。空文字は 400) — R: `PlanTabVersion` | 200 / 400 / 404 |

- **版の削除エンドポイントを持たない** (§5.2)
- `PUT .../instruction` は **`content` を変えない**。変わるのは次回再生成に渡る履歴 (§5.1)

### 2.8 お気に入り / チャット / サムネイル

| エンドポイント | 入出力 | ステータス |
|---|---|---|
| `POST /plans/{plan_id}/favorite` | — R: なし | **201** / 404。**既に登録済みでも 201** (冪等) |
| `DELETE /plans/{plan_id}/favorite` | — | **204** / 404。**未登録でも 204** (冪等) |
| `GET /plans/{plan_id}/chat/messages` | Q: `after_seq` (既定 0) / `limit` — R: `{items:[PlanChatMessage], total_count}` | 200 / 404 |
| `POST /plans/{plan_id}/chat/messages` | B: `message` (**必須**) — R: `text/event-stream` (§7.3) | 200 / 400 / 404 / **409** (同じ企画書で別のチャットが実行中) / 502 |
| `POST /plans/{plan_id}/thumbnail` | — R: `{thumbnail_url, thumbnail_url_expires_at, thumbnail_generated_at}` | 200 / 404 / **502** (画像生成の失敗) |

`PlanChatMessage` = `{seq, role: "user"|"assistant", content, status: "complete"|"aborted"|"failed", created_at}`。
`role` / `status` の値域は [conversation.md](conversation.md) §2.4 の `conversation_messages` と**同じ値域を使う**
(FE のレンダラを 2 種類作らないため)。

### 2.9 ステータスコードの適用 (A-5)

| 事象 | コード |
|---|---|
| `X-Token` 欠落・不正・期限切れ | **401** (本文なし) |
| ボディ・クエリのバリデーション違反 / `tab_id`・`sections`・`sort` の値域外 | **400** |
| 企画書・アイデア・タブの版が**他人 or 不存在** | **404** (**403 にしない**) |
| **同じアイデアに企画書が既にある** (`POST /plans`) | **409** |
| **同じ企画書 / タブで生成が実行中** (#6 / #7 / #8 / #11 / #16) | **409** |
| 下流 LLM / 画像生成の失敗 (ストリーム開始前 / 非 SSE) | **502** |
| ストリーム開始後の失敗 | HTTP では表現しない → SSE の `error` |
| 上記以外 | **500** |

**403 を返すエンドポイントは無い** — 企画書は個人スコープのみで、「見えるが操作できない」状態が存在しない。
`visibility=contract` で契約内の他メンバーから**見える**ようになった場合の編集操作は
[../auth.md](../auth.md) §6.12 の適用範囲であり、**本増分では読み取りのみを契約に開く**ため 403 は生じない (§10.4)。

---

## 3. v2 → v3 対応表 (AC-CV-1.1 / C-16)

**本節が回答する ID: D-7** / 対応 AC: **AC-CV-1.1, AC-CV-1.3**

[../../analysis/v2-feature-inventory.md](../../analysis/v2-feature-inventory.md) §2.7 の **18 行と同じ行数・同じ順序**で並べる。
行番号は `hassan-v2-backend/router/router.go` の実測 (2026-08-01)。
**「増分 2」「後ろ倒し」「対象外」と書いた行は 0 行**である (CV-D1 = CV-Q1=B)。

| # | v2 エンドポイント | 行 | v2 の機能 | v3 の受け先 | 第 1 リリース |
|---|---|---|---|---|---|
| 1 | `POST /business-plans/generate` | `:151` | セクション 1 つの生成 / ブラッシュアップ (**実体は SSE** — `hassan-v2-backend/controller/business_plan.go:242`) | **`POST /plans/{plan_id}/tabs/{tab_id}/regenerate`** (`sections` に v2 の `business_plan_type` を写像。§6.2) | **入る** |
| 2 | `POST /business-plans/jobs/start` | `:152` | 12 セクションを並列生成するジョブの開始 | **`POST /plans/{plan_id}/generate`** (8 タブ一括。**ジョブにしない** — §11 の D-PL-4) | **入る** |
| 3 | `GET /business-plans/jobs/:job_id` | `:153` | ジョブ状態の取得 | **`GET /plans/{plan_id}`** (`tabs[].status` が生成状態を持つ。§2.1) | **入る** |
| 4 | `GET /business-plans/jobs/:job_id/stream` | `:154` | ジョブ進捗の SSE | **#2 の応答そのもの (同期 SSE)** + 切断時は **`GET /plans/{plan_id}`** (J-7 を満たす経路。§4.9) | **入る** |
| 5 | `POST /business-plans` | `:155` | 企画書の作成 (生成済み内容の確定) | **`POST /plans`** (器の作成) + **`POST /plans/{plan_id}/generate`** (内容の生成) の 2 段 | **入る** |
| 6 | `PUT /business-plans/:id` | `:156` | 更新。`update_type=manual` (手動編集) と `brush_up` (指示付き再生成) の 2 モード | **`PUT /plans/{plan_id}/tabs/{tab_id}`** (manual) / **`POST /plans/{plan_id}/tabs/{tab_id}/regenerate`** (brush_up)。メタ (`visibility`) は **`PUT /plans/{plan_id}`** | **入る** |
| 7 | `GET /business-plans/:id` | `:158` | 企画書の取得 (**`histories` を同梱**) | **`GET /plans/{plan_id}`** (8 タブの最新版)。**版一覧は同梱せず** `GET /plans/{plan_id}/tabs/{tab_id}/versions` に分ける (§11 の D-PL-12) | **入る** |
| 8 | `GET /business-plans` | `:160` | 企画書一覧 (`account_id` / `theme_id` クエリ) | **`GET /plans`** (**`account_id` クエリは移植しない** — §11 の D-PL-13) | **入る** |
| 9 | `DELETE /business-plans/:id` | `:159` | 企画書の削除 | **`DELETE /plans/{plan_id}`** (論理削除) | **入る** |
| 10 | `PUT /business-plans/:id/histories/:history_id/prompt` | `:157` | **版履歴のプロンプト編集** | **`PUT /plans/{plan_id}/tabs/{tab_id}/versions/{ver_no}/instruction`** (§5.1)。**`plan_tab_versions.instruction` 列の追加を §12 の R-PL-3 で起票** | **入る** |
| 11 | `GET /business-plans/:id/chat/history` | `:161` | 企画書チャットの履歴取得 | **`GET /plans/{plan_id}/chat/messages`** (§7) | **入る** |
| 12 | `POST /business-plans/:id/chat` | `:162` | 企画書チャット (SSE) | **`POST /plans/{plan_id}/chat/messages`** (SSE。§7) | **入る** |
| 13 | `POST /business-plans/:id/favorite` | `:163` | **お気に入り登録** | **`POST /plans/{plan_id}/favorite`** (§9)。**`plan_favorites` テーブルの追加を §12 の R-PL-1 で起票** | **入る** |
| 14 | `DELETE /business-plans/:id/favorite` | `:164` | お気に入り解除 | **`DELETE /plans/{plan_id}/favorite`** (§9) | **入る** |
| 15 | `GET /business-plans/generate-image` | `:165` | **サムネイルの生成** (Gemini。`idea_id` クエリ) | **`POST /plans/{plan_id}/thumbnail`** (§8。**GET から POST に変える** — §11 の D-PL-10) | **入る** |
| 16 | `GET /business-plans/detailed` | `:168` | 詳細版企画書の取得 (`business_plan_id` クエリ) | **`GET /plans/{plan_id}`** (詳細版は別リソースにせず 8 タブへ統合。§6) | **入る** |
| 17 | `POST /business-plans/detailed` | `:169` | 詳細版セクションの生成 / ブラッシュアップ (SSE。6 セクション) | **`POST /plans/{plan_id}/tabs/{tab_id}/regenerate`** (§6.1 の写像表) | **入る** |
| 18 | `POST /business-plans/detailed/brush-up/prepare` | `:170` | ブラッシュアップ用の**新バージョンの事前確保** | **受け先を持たない (操作が構造的に消滅する)** — v3 は版採番を**保存時の 1 SQL に閉じる** ([../data-model.md](../data-model.md) §4.11.1。BE-11) ため「事前確保」という段が存在しない。**同じ結果 (版が 1 つ増える) は #17 の再生成が達成する**。C-16 の「統合」に該当し、落とした操作ではない (§11 の D-PL-5) | **入る (統合)** |

**#18 についての補足**: v2 は `PrepareBusinessPlanDetailedBrushUp` が新 `version` を先に確保し、
セクション更新はその番号に書き込む形になっている
(`hassan-v2-backend/usecase/business_plan/detailed/prepare_business_plan_detailed_brush_up.go:44` の
「新バージョンを事前確保して返す。セクション内容はブラッシュアップリクエスト時に更新する」)。
v3 でこれを移植すると「確保したが書かれなかった版」が残り、`ver_no` に穴が空く。
**採番と Insert を 1 文にする規約 ([../data-model.md](../data-model.md) §4.11.1 の 1) と両立しない**。

### 3.1 [../../analysis/v2-feature-inventory.md](../../analysis/v2-feature-inventory.md) §5 の未解決 2 件のクローズ (AC-CV-1.3)

| # | 内容 | 解消先 | 状態 |
|---|---|---|---|
| **#9** | 企画書のお気に入り (`business_plan_favorites` に相当する v3 テーブル・API が無い) | **本書 §9** (API) + **§12 の R-PL-1** (`plan_favorites` テーブルの追加要求) | **解消 (本書で受けた)** |
| **#10** | 版履歴のプロンプト編集 (版履歴の編集操作が v3 の設計に無い) | **本書 §5.1** (API) + **§12 の R-PL-3** (`plan_tab_versions.instruction` 列の追加要求) | **解消 (本書で受けた)** |

同書 §5 の「対象外 (要確認)」からの削除と §2.7 の「v3 の対応」列の追加は **§12 の R-PL-8** で起票する
(本書は参照リポジトリ以外の他文書も編集しない)。

---

## 4. タブの生成・再生成

**本節が回答する ID: A-6, O-2, O-3, O-4, O-5, D-6** / 対応 AC: **AC-CV-4.1, AC-CV-4.2**

### 4.1 8 タブの ID 値域 (AC-CV-4.2)

**`entity/plan` の `PlanTabID` に 1 箇所で持つ。DB の CHECK / enum を付けない** (G-9。
[../data-model.md](../data-model.md) §4.6 の既存判断を維持する)。
値と表示順は PoC の実装を移植する (`claude_managed_agents/internal/agent/diverge/plan.go:13`〜`:20` が定義、
表示順は同 `:27`〜`:35`)。

| 順 | `tab_id` | ラベル | 主な `content` の構造 (PoC の型を移植) |
|---|---|---|---|
| 1 | `service` | サービス概要 | コンセプト概要 / 提供機能 / ペルソナ |
| 2 | `bmc` | BMC | ビジネスモデルキャンバスの 9 ブロック |
| 3 | `summary` | 評価サマリ | 投資委員会向け 1 ページ |
| 4 | `pestel` | PESTEL | マクロ環境分析 |
| 5 | `market` | 市場 | TAM / SAM / SOM |
| 6 | `competitor` | 競合 | 競合一覧と差別化 |
| 7 | `tech` | 技術 | `rank` / `core_technology` / `items` / `risks` (+ **§6.1 で `hypothesis_poc` を追加**) |
| 8 | `legal` | 法規制 | 主要な関連法規制 |

- **ラベル (日本語) はサーバが返す** (`PlanTab.label`)。多言語化が必要になったら FE が持つ形に変える (§13 の PL-R4)
- **タブを増やす変更はマイグレーションを伴わない**が、`progress.total` (§4.4)・FE の union 型・
  本書と 12 文書の「8 タブ」表記が連動する。**本増分ではタブを増やさない** (§11 の D-PL-7 の却下 a)

### 4.2 生成に使う Agent (D-6)

**P-4 (plan tab) の Managed Agent 1 本**に統一する ([../llm-migration.md](../llm-migration.md) §4.1 の P-4)。
PoC の「6 タブは Agent / service・bmc の 2 タブは直接 API」という 2 系統も、
v2 の簡易モード (V-6) の独立 streaming 経路も**作らない** (同 §6.2 の 5)。

| # | 決定 |
|---|---|
| 1 | **P-4 は D-6 の再発行対象**。手順・ハッシュ差分判定・ロールバックの SSOT は [../operations.md](../operations.md) §5.2 / §5.3 |
| 2 | **タブごとに別 Agent を作らない**。タブの違いは**プロンプトの引数** (`prompts/plan/tab.md` + タブ別引数) で表す ([../llm-migration.md](../llm-migration.md) §6.2 の 5)。タブを増やすたびに D-6 の再発行対象が増える形にしない |
| 3 | **P-4 が使うツール (`web_search` 等) の増減は [conversation.md](conversation.md) §3.4 の規則に従う** (追加は後方互換・削除は 2 段階) |
| 4 | **`prompts/agents.yaml` の列挙が実体の SSOT**。P-4 が列挙されていることを `scripts/check-tool-contract.sh` が検査する ([../llm-migration.md](../llm-migration.md) §6.3) |

### 4.3 3 つの入口と UseCase の共有 (AC-CV-4.1 / CV-D10)

| 入口 | 呼び出し元 | 生成範囲 |
|---|---|---|
| **会話ターンの `generate_plan` tool** | [conversation.md](conversation.md) §4.1 | 8 タブ一括 |
| **`POST /plans/{plan_id}/generate`** | 本書 #6 | 8 タブ一括 |
| **`POST /plans/{plan_id}/tabs/{tab_id}/regenerate`** | 本書 #7 | 1 タブ (任意で `sections` に限定) |

| # | 決定 |
|---|---|
| 1 | **3 入口とも `usecase/plan` の同一 UseCase (`GeneratePlanTabs`) を呼ぶ**。入口の違いは「対象タブ集合」「指示」「SSE の送出先」の 3 引数だけにする |
| 2 | **`feature` は 3 入口とも `plan.generate`** ([conversation.md](conversation.md) §3.3 と同じ値)。計測 (O-2) と安全弁 (O-3) の適用が入口によって変わらない |
| 3 | **所有者スコープの確定点も 3 入口で同じ** — UseCase が `ContractID` / `AccountID` を確定し、`repository/plan` / `repository/idea` のクエリ条件に渡す (§4.5) |
| 4 | **`sections` の値域は `entity/plan` の `PlanTabSections` (タブ → セクション ID 集合) の 1 箇所**に持つ。`tab_id` と同じく DB の CHECK を付けない |
| 5 | **`sections` 指定時も保存は「タブ 1 版」**。LLM には「指定セクションだけを更新し、他のセクションは入力の現状を維持する」と指示し、**応答はタブ全体の `content`** を受け取って 1 版として保存する |

**`sections` を持つ理由 (C-16)**: v2 は**セクション / フィールド単位**で生成・ブラッシュアップする
(簡易モード 12 種 = `hassan-v2-backend/entity/business_plan.go:71`〜`:82`、
詳細版 6 種 = `hassan-v2-backend/controller/business_plan_detailed.go:105`〜`:118` の分岐)。
タブ単位しか持たないと **「BMC の顧客セグメントだけ直したい」が BMC タブ全体の作り直し**になり、
**手動編集した他セルが失われる**。v2 はこれを明示的に守っている
(`hassan-v2-backend/usecase/business_plan/generate_business_plan.go:160`〜`:161` が、直近が手動編集の
セクションに「最小限の変更に留める」指示を足す)。**この保護を v3 で失わせない**。

### 4.4 SSE (AC-CV-4.1)

**イベント型の値域の SSOT は [conversation.md](conversation.md) §5.1**。本書は**企画書経路の順序契約**だけを定める。
**新しいイベント名を追加しない**。

| event | 企画書経路での使い方 |
|---|---|
| `progress` | **`scope: "plan"`**。`step` は完了タブ数、`total` は**対象タブ数** (一括生成 = 8 / 再生成 = 1)。`label` はタブのラベル、`detail` はセクション名 (`sections` 指定時のみ) |
| `artifact` | **`kind: "plan"`**。payload は `{plan_id, idea_id, idea_title, generated_at, tabs:[{tab_id, ver_no, label}]}` ([conversation.md](conversation.md) §5.2)。**タブ本文を載せない** (D-CV-11 を維持) |
| `tool_start` / `tool_end` | **P-4 が使うツール (web_search 等) の実行**に対して送出する。`tool_end.ok=false` のとき `error_code` を載せる |
| `error` | ストリーム開始後の失敗。`{code, message, request_id}`。**プロバイダの文言を素通ししない** |
| `turn_summary` | **`done` の直前に必ず 1 回**。`outcome` の値域は会話ターンと同じ 5 値。`tool_calls` は**この生成で P-4 が呼んだツール回数** |
| `done` | 常に最後に 1 回 |
| `session` / `message_delta` | **送出しない** (会話ターンではないため。`message_delta` はタブ本文の逐次配信に使わない — 本文は版として保存され `GET` で取る) |

順序契約 (**企画書経路**):

```
( progress → tool_start? → tool_end? → artifact? )*      ← タブごとに 1 周
  error?                                                  ← 最大 1 回
turn_summary                                              ← 1 回
done                                                      ← 1 回・末尾
```

| # | 契約 |
|---|---|
| 1 | **`turn_summary` → `done` は異常時も必ず出る** ([conversation.md](conversation.md) §5.3 の 1・2 と同じ) |
| 2 | `artifact` は**タブの版を保存し終えた後**にのみ送出する (書き込み → 送出の順。D-CV-9 と同じ) |
| 3 | **打ち切り (`tool_limit` / `token_limit` / `timeout`) は `error` を出さない**。`turn_summary.outcome` だけで表す |
| 4 | `turn_summary.message_seq` は**この経路では使わない** — 同フィールドの任意化を §12 の R-PL-5 で起票する |
| 5 | keep-alive は SSE コメント (`: keepalive`)。間隔は [../observability.md](../observability.md) §4.4 |

### 4.5 A-6 (LLM のテナント越境) への回答

**強制点の SSOT は [../architecture.md](../architecture.md) §3.8.2**。本書は**企画書ドメインでの適用**を確定させる。

| # | 決定 |
|---|---|
| ① | **P-4 に渡す入力は UseCase が所有者条件付きクエリで取得した行だけ**。アイデア本文・アセット・台帳の deep dive はすべて `WHERE account_id = <UseCase が確定した値>` を通ったものに限る |
| ② | **会話ターン経由 (`generate_plan`) の `idea_id` は所有者条件 + テーマ配下チェックの両方**を通す ([conversation.md](conversation.md) §4.4 の `generate_plan` 行)。REST 経路 (#6 / #7) は `plan_id` から `idea_id` を引くので、**LLM 由来の ID が入る余地が無い** |
| ③ | **P-4 が使う web_search の結果を所有者スコープの根拠にしない** — 外部検索結果は本文であって権限ではない |
| ④ | **該当なしは「見つからない」で統一**する ([../auth.md](../auth.md) §6.5)。「他の契約の企画書です」を返さない |
| ⑤ | **所有者不一致を warn ログ + メトリクスに出す** (経路名・`request_id`)。無言にすると実装バグと越境試行が両方とも検知できない |

### 4.6 O-2 (LLM 呼び出しの記録)

**個別の生成コードに計測を書かない** — 計測値は `gateway` が `CallMeta` として返し、集計は
`service/conversation.Runner` 相当が持つ ([conversation.md](conversation.md) §3.3 / CV-DF3)。

| `feature` | 経路 | `route_kind` | 備考 |
|---|---|---|---|
| `plan.generate` | #6 / #7 / 会話の `generate_plan` → P-4 | `managed_agent` | **3 入口で同一値** (§4.3 の 2) |
| `plan.generate` | P-4 内の web_search (Exa) | `external_search` | 同じ `feature` で `route_kind` が違う ([../observability.md](../observability.md) §4.2 の規則) |
| **`plan.chat`** | #16 (V-8) | `direct_api` | **新規。§12 の R-PL-6 で起票** |
| **`plan.thumbnail`** | #17 (V-9) | **`image_generation`** | **新規。既存の `route_kind` 3 値に無い** — §12 の R-PL-6 で起票 |

- `llm_call_records.theme_id` は `plans.theme_id` から必ず埋まる (企画書はテーマ必須のアイデアに紐づくため、
  O-3 のテーマ単位集計に穴が空かない)
- **`feature` の const を増やしたら同じ PR で [../testing.md](../testing.md) の LLM 経路テストを足す**
  (const が無いと存在検査が 0 件を検査して緑になる)

### 4.7 安全弁の適用点 (O-3 / AC-CV-5.9 の企画書経路)

**しきい値の数値は [../observability.md](../observability.md) §4.4 が SSOT**。本書に再掲しない (DR-9)。

| 適用単位 | 決定 |
|---|---|
| **会話ターン経由** | 外側のターンの安全弁に**含まれる** ([conversation.md](conversation.md) §2.5)。P-4 は外側の `context` を継承し独自 deadline を持たない |
| **REST 経路 (#6 / #7)** | **1 リクエストを 1 単位として、会話ターンと同じ 3 種の安全弁 (ツール回数 / 累積出力トークン / 実行時間) を適用**する。数値も同じ値を使う |
| **8 タブ一括生成の実行時間** | **タブ単位ではなくリクエスト全体に適用**する。8 タブが上限に届いた場合、**それまでに保存済みのタブは確定させ** `outcome=timeout` で終える (§4.8 の 3) |
| **上限による拒否** | **設けない** (C-12) |

### 4.8 O-4 (失敗の可観測性) と部分保存

| # | 事象 | 扱い | [../observability.md](../observability.md) §4.3 |
|---|---|---|---|
| 1 | `stop_reason == max_tokens` (出力の切り詰め) | **そのタブの版を保存しない**。`tool_end`/`error` で表し warn + メトリクス | **F-1** |
| 2 | タブ JSON のパース失敗 | 同上。**部分的にパースできた分を保存しない** (成功を装うフォールバックを作らない) | **F-2** |
| 3 | 安全弁の発火 | **それまでに保存済みのタブは確定**。`turn_summary.outcome` で表す (エラーではない) | **F-4** |
| 4 | SSE 送出中の切断 | 保存済みのタブは確定。ログとメトリクスのみ | **F-5** |
| 5 | 所有者不一致 | 「見つからない」/ warn + メトリクス | §4.5 の⑤ |

**トランザクション境界**: **タブ 1 件の保存が 1 トランザクション**。
[../data-model.md](../data-model.md) §4.11.1 の規約 5 は「**企画書 8 タブの保存は 1 トランザクション**」
(全タブ成功か全タブ失敗) と定めており、**本節はこれと矛盾する** —
**本書は §11 の D-PL-16 で「タブ単位トランザクション」を採用し、同規約の改訂を §12 の R-PL-3 で起票する**。
無言で逸脱しない。

### 4.9 生成中の状態と切断時の回復 (O-5 / J-7)

| # | 決定 |
|---|---|
| 1 | **生成中であることを DB で表す** — `plans.generating_tabs`(タブ ID の配列) ではなく、**`plan_tab_generations` のような新テーブルも作らない**。`plans.generating_started_at` と `plans.generating_tab_id` の **2 列**で表す (§12 の R-PL-3)。一括生成では `generating_tab_id` は `null` |
| 2 | **409 の判定はこの 2 列に対する `SELECT … FOR UPDATE NOWAIT`** ([../data-model.md](../data-model.md) DM-13 と同じ機構)。**SSE ヘッダを書く前**にロックを取るので HTTP ステータスで返せる |
| 3 | **取り残しの回収**: `generating_started_at` が閾値 (実行時間上限 + 余裕。`config` が SSOT) を超えていたら**新しい生成が奪える**。デプロイでプロセスが消えても「永久に 409」にならない ([README.md](README.md) J-3 と同じ思想) |
| 4 | **切断時の回復は `GET /plans/{plan_id}`** — `tabs[].status` と `ver_no` で「どこまでできたか」が分かる。**SSE は結果の唯一の受け取り口ではない** (J-7 を満たす) |
| 5 | **J-6 の対象外** — SSE を返すリクエスト自身が生成を実行するため、ALB が「生成が走っていないタスク」へ SSE を振る事象が起こり得ない ([conversation.md](conversation.md) の D-CV-2 と同じ理由)。§12 の R-PL-9 で [README.md](README.md) §1.3 への明記を起票する |

### 4.10 stale の表現 (BE-4 / AC-CV-4.2)

**判定規則の SSOT は [../data-model.md](../data-model.md) §4.11.3**。本書は**応答での表し方**を確定させる。

| `stale_reason` | 条件 | 応答 |
|---|---|---|
| `null` | 最新 | `is_stale: false` |
| **`idea_version_outdated`** | `source_idea_version_id` が `idea_versions` の最新でない | `is_stale: true`。**本文は返す** |
| **`idea_content_changed`** | `source_hash` != 現在のアイデア内容のハッシュ | 同上 |

| # | 決定 |
|---|---|
| 1 | **自動再生成しない** (LLM コストが暗黙に発生する)。再生成はユーザー操作 (#7) |
| 2 | **`source_idea_version_id` を NOT NULL にする** — 生成時にどの版を入力にしたかが記録されない行を作らない (BE-1)。**アイデアは生成時点で `idea_versions` の ver 1 を持つ**ことを前提にする → **`ideas.md` への依頼として §12 の R-PL-13 で起票** |
| 3 | 復元 (#11) で作られる版は、**復元元の `source_idea_version_id` / `source_hash` をコピーする** (§5.2 の 3)。復元時点の最新アイデア版を書くと、古い本文が「最新アイデアに基づく」と嘘をつく |
| 4 | **`plan_tab_versions.content` に `sections` と `source_deep_dive_entry_ids` を記録する** ([../data-model.md](../data-model.md) §4.11.2 の 3) |

---

## 5. 版管理 (AC-CV-4.3)

**本節が回答する ID: O-6** / 対応 AC: **AC-CV-4.3, AC-CV-4.5**

**CV-Q9=A の適用**: 既存の版テーブル `plan_tab_versions` の操作として API 化し、
「スナップショット」という別概念を作らない。

| 操作 | エンドポイント | 版番号 |
|---|---|---|
| 一覧 | `GET /plans/{plan_id}/tabs/{tab_id}/versions` | — |
| 取得 | `GET .../versions/{ver_no}` | — |
| **復元** | `POST .../versions/{ver_no}/restore` | **増える** (新版を作る) |
| 指示の編集 | `PUT .../versions/{ver_no}/instruction` | 増えない (内容を変えないため) |
| 削除 | **持たない** | — |

| # | 決定 |
|---|---|
| 1 | **採番は `COALESCE(MAX(ver_no),0)+1` を 1 SQL で行う** ([../data-model.md](../data-model.md) §4.11.1。BE-11)。`UNIQUE (plan_id, tab_id, ver_no)` 違反は握り潰さず `CodedError` にし、同一トランザクション内で **1 回だけ**再試行する |
| 2 | **版番号を引数で受け取る保存メソッドを作らない** (同 §4.11.1 の規約 4)。復元も「復元元の `ver_no`」を**読み取りにだけ**使う |
| 3 | **復元は内容のコピー** — `content` / `instruction` / `sections` / `source_idea_version_id` / `source_hash` / `source_deep_dive_entry_ids` を複製し、`origin=restore` / `restored_from_ver_no=<元の版>` / `create_account_id=<操作者>` を新しく書く |
| 4 | **手動編集 (#8) も版を切る** (`origin=manual`)。「編集は版を増やさない」にすると、手動編集の内容が次の再生成で黙って消える |

### 5.1 版履歴のプロンプト編集 (#10 / AC-CV-4.5)

**判定: `plan_tab_versions` に生成指示を保持する列が必要である。** 理由は「読み手と書き手が対で存在する」こと (BE-10)。

**v2 の実測**:

| # | 事実 | 出典 |
|---|---|---|
| 1 | `business_plan_histories.prompt text NOT NULL DEFAULT ''` が編集対象の列 | `hassan-v2-backend/db/schema.sql:238` |
| 2 | **書き手①** ブラッシュアップ時はユーザーの指示原文をそのまま入れる | `hassan-v2-backend/usecase/business_plan/update_business_plan.go:82` |
| 3 | **書き手②** 手動編集時は「変更後の内容の先頭 30 文字」を入れる | 同 `:79` |
| 4 | **読み手** 次回のブラッシュアップで、直近の履歴から「`[対象] 更新種別: 指示`」の履歴コンテキストを組み立てて LLM に渡す | `hassan-v2-backend/usecase/business_plan/brush_up_history_context.go:15` → `hassan-v2-backend/usecase/business_plan/generate_business_plan.go:171` |

**v3 の設計**:

| # | 決定 |
|---|---|
| 1 | **`plan_tab_versions.instruction text NOT NULL DEFAULT ''` を持つ** (§12 の R-PL-3 で起票) |
| 2 | **書き手** — 再生成 (#7) はリクエストの `instruction` を、一括生成 (#6) と会話ターンは空文字を、手動編集 (#8) は**空文字**を入れる。**v2 の「本文の先頭 30 文字」方式は移植しない** (指示ではない文字列が「指示」の列に入り、読み手の LLM が混乱する。§11 の D-PL-6 の却下 b) |
| 3 | **読み手** — 再生成時に**同じタブの直近 N 版の `instruction` (空文字を除く) を「これまでの指示」として P-4 に渡す**。N は `config` が SSOT (BE-2。本書に値を書かない) |
| 4 | **`PUT .../instruction` は読み手側の入力だけを変える** — 過去の指示を言い直すと、次の再生成の履歴コンテキストが変わる。**`content` は変えない** |
| 5 | **編集を監査ログの対象にする** (§10.5)。過去の指示を書き換えられる操作なので、誰がいつ変えたかが残らないと「なぜこの内容になったか」が追えなくなる |

### 5.2 削除操作を持たない理由

- 版を消すと、`plan_tab_versions.source_idea_version_id` を辿る **BE-4 の stale 判定が成立しなくなる**
- **却下 (a) 論理削除にする**: 版一覧から消えるが採番は飛ぶため、「v3 の次が v5」というユーザーに説明できない状態になる
- **却下 (b) 物理削除**: PoC は「`created_at > target` の行を物理削除する」方式だった
  (`claude_managed_agents/internal/db/migrations/000022_idea_versions.up.sql:11`)。
  誤操作が不可逆で、監査でも「何を戻したか」が追えない。
  [../data-model.md](../data-model.md) §4.6 が既に同じ理由でこの方式を却下している

---

## 6. 詳細版 (AC-CV-4.6)

**本節が回答する ID: D-7** / 対応 AC: **AC-CV-4.6**

### 6.1 v2 の詳細版 7 セクション → v3 の 8 タブ

v2 の詳細版は `business_plans_detailed` の 7 つの jsonb 列
(`hassan-v2-backend/db/schema.sql:273`〜`:279`)。**7 行すべてに写像先がある**。

| # | v2 の列 | v2 の生成経路 | v3 の受け先 | 種別 |
|---|---|---|---|---|
| 1 | `evaluation_summary` | `POST /business-plans/detailed?section=evaluation_summary` | **`summary` タブ** | 既存タブ |
| 2 | `pestel_analysis` | 同 `?section=pestel_analysis` | **`pestel` タブ** | 既存タブ |
| 3 | `market_analysis` | 同 `?section=market_analysis` | **`market` タブ** | 既存タブ |
| 4 | `competitor_analysis` | 同 `?section=competitor_analysis` | **`competitor` タブ** | 既存タブ |
| 5 | `hypothesis_poc` | 同 `?section=hypothesis_verification_poc` | **`tech` タブの `hypothesis_poc` セクション** (§4.3 の `sections` で単独再生成できる) | 既存タブ内のセクション |
| 6 | `technology_analysis` | **生成経路が無い** (下記) | **`tech` タブ** | 既存タブ |
| 7 | `legal_regulations` | 同 `?section=legal_regulations` | **`legal` タブ** | 既存タブ |

**#6 が「生成経路が無い」ことの実測**: `POST /business-plans/detailed` の分岐
(`hassan-v2-backend/controller/business_plan_detailed.go:105`〜`:118`) に `technology_analysis` は無く、
書き込みは**ブラッシュアップ確定時に旧値をそのまま引き継ぐ 1 箇所だけ**
(`hassan-v2-backend/usecase/business_plan/detailed/finalize_business_plan_detailed_brush_up.go:174`)。
**列と enum (`hassan-v2-backend/entity/business_plan_detailed.go:28`) はあるが、値を作る経路が無い**。
したがって **v3 の `tech` タブは v2 の生成対象と競合しない** (v3 は P-4 が生成するため機能は増える)。

**#5 を `tech` タブに入れる判断は §11 の D-PL-7** (却下案つき)。

**新タブを作らない / タブ外の別リソースにしない**ため、**「新タブ」「タブ外」に分類された行は 0 行**である。

### 6.2 v2 の簡易モード (V-6) の出力粒度が 8 タブに写像できるか (F-CV8 の判定)

**判定: 写像できる。** v2 の簡易モードの生成単位 12 種
(`hassan-v2-backend/entity/business_plan.go:71`〜`:82`。ジョブが並列生成するのはこの 12 種 =
`hassan-v2-backend/usecase/business_plan/generation_job_manager.go:21`〜`:34`) は、
**`service` と `bmc` の 2 タブに収まる**。

| v2 の `business_plan_type` | v3 の (タブ, セクション) |
|---|---|
| `concept-overview` | (`service`, `concept_overview`) |
| `concept-function` | (`service`, `concept_function`) |
| `persona` | (`service`, `persona`) |
| `bmc-collaborator` / `bmc-activity` / `bmc-resource` / `bmc-worth` / `bmc-relationship` / `bmc-sales-channel` / `bmc-client` / `bmc-cost` / `bmc-earnings` (**9 種**) | (`bmc`, 同名セクション) |
| `thumbnail-url` (`hassan-v2-backend/entity/business_plan.go:83`) | **タブ外** — §8 のサムネイル |

**ただし出力粒度は v2 のほうが細かい** (12 セクション vs 2 タブ)。
**タブに写像できないから新タブを足す、のではなく、§4.3 の `sections` でこの粒度を表現する** —
[../llm-migration.md](../llm-migration.md) §6.2 の 5 が「写像できない出力がある場合はタブの追加ではなく
プロンプト側で吸収する」を出発点にしており、その方針どおりの結論である。

### 6.3 V-7 / V-10 / V-11 の受け先

| 機能 | v2 の実体 | v3 |
|---|---|---|
| **V-6** 簡易モード生成 | `POST /business-plans/generate` (SSE) | **P-4 に統合** (§6.2)。独立 streaming 経路を作らない |
| **V-7** ブラッシュアップ stage-1 (クエリ補強) | 履歴コンテキスト + 指示を別 LLM 呼び出しで補強してから本生成に渡す (`hassan-v2-backend/usecase/business_plan/generate_business_plan.go:171`〜`:180`) | **独立呼び出しにせず、§5.1 の 3 の履歴を P-4 にそのまま渡す** (§11 の D-PL-14) |
| **V-10** 詳細セクション分析 7 種 | `POST /business-plans/detailed` の 6 分岐 + 生成経路の無い 1 列 | **P-4 に統合** (§6.1)。[../llm-migration.md](../llm-migration.md) §6.2 の 5 は「V-10 は統合対象ではなく独立移送」と書いており**衝突する** → §12 の R-PL-7 で起票 |
| **V-11** 詳細版 Web リサーチ (plan / draft / search / revision / critic の 5 フェーズ) | `hassan-v2-backend/usecase/business_plan/detailed/web_research.go` | **P-4 の web_search 経路に統合** (PoC の企画書 Agent は既に web_search を任意で使う — `claude_managed_agents/prompts/idea_plan_agent_system.md:21`)。**5 フェーズの固定パイプラインは移植しない** (§11 の D-PL-15)。品質差は [../llm-migration.md](../llm-migration.md) §8 の確認対象 |

---

## 7. 企画書チャット (AC-CV-4.7)

**本節が回答する ID: A-3, O-2, O-5** / 対応 AC: **AC-CV-4.7**

### 7.1 v2 の実測

| # | 事実 | 出典 |
|---|---|---|
| 1 | 履歴は **2 テーブル**。`business_plan_chats` が `(business_plan_id, conversation_id)` の対応表、`business_plan_chat_messages` が本文 | `hassan-v2-backend/db/schema.sql:216` / `:225` |
| 2 | **`business_plan_chat_messages` は所有者列も FK も持たない** — 列は `id` / `conversation_id text` / `role` / `content` / `created_at` のみ | 同 `:225`〜`:232` |
| 3 | `conversation_id` は企画書ごとに 1 本を取得または新規作成する | `hassan-v2-backend/usecase/business_plan/business_plan_chat.go:92` |
| 4 | **ツールを持たない chat** ([../llm-migration.md](../llm-migration.md) §4.2 の V-8。判定は Q3=No) | 同書 §4.2 |

### 7.2 v3 の設計 (専用テーブル 1 本)

**採用: `plan_chat_messages` の 1 テーブルを新設し、会話セッション (`conversation_sessions`) には相乗りしない。**
判断と却下理由は §11 の D-PL-9。

| 項目 | 決定 |
|---|---|
| テーブル | **`plan_chat_messages`** (新設。§12 の R-PL-2 で起票) |
| 所有者列 | **`contract_id` + `account_id`** (個人境界。[../data-model.md](../data-model.md) §3.3 の全件必須に従う) |
| 主なカラム | `plan_id` (FK → `plans` CASCADE) / `seq integer` / `role` / `content` / `status` / `created_at` |
| 採番 | `UNIQUE (plan_id, seq)` + `COALESCE(MAX(seq),0)+1` を 1 SQL ([../data-model.md](../data-model.md) §4.11.1) |
| **`conversation_id text` を持たない** | v2 の同列は Dify の会話 ID を保持するための列であり、v3 は Dify を廃止する。`plan_id` が同じ役割を果たす |
| 保存契約 | **1 メッセージ = 1 行**。ユーザー発話は受信時、assistant 発話はターン終了時。**中断時もその時点までの本文を `aborted` で保存**し、**ロールバックされない別トランザクション**で行う ([conversation.md](conversation.md) §2.4 と同じ規則) |

### 7.3 API と SSE

- `GET /plans/{plan_id}/chat/messages` — `after_seq` の意味は [conversation.md](conversation.md) §1.1 と同じ
  (「その値より大きい `seq` の行を古い順に返す」)
- `POST /plans/{plan_id}/chat/messages` — **SSE**。送出するイベントは
  **`message_delta` / `error` / `turn_summary` / `done`** ([conversation.md](conversation.md) §5.1 の集合から使う分だけ)。
  **`progress` / `artifact` / `tool_start` / `tool_end` は送出しない** (ツールを持たない chat のため)
- **チャットは企画書の内容を変更しない** — ブラッシュアップの実行は #7 (再生成)。
  **却下**: チャットから直接タブを書き換える — 版の作成契機が 2 系統になり、`instruction` の書き手が
  「チャットの発話のどれか」に曖昧化する (BE-1)
- `feature = plan.chat` / `route_kind = direct_api` (§4.6)

---

## 8. サムネイル (AC-CV-4.8)

**本節が回答する ID: A-3, O-2, O-4** / 対応 AC: **AC-CV-4.8**

### 8.1 v2 の実測 — LLM ではなく画像生成

| # | 事実 | 出典 |
|---|---|---|
| 1 | **Gemini の画像生成**を使う (テキスト LLM ではない) | `hassan-v2-backend/usecase/business_plan/generate_business_plan_thumbnail.go:85` (プロバイダ取得) / `:91` (生成呼び出し) |
| 2 | 生成結果は base64 → デコード → 固定サイズへリサイズ → JPEG/PNG で S3 へ | 同 `:97` 以降 |
| 3 | エンドポイントは **`GET`** で `idea_id` をクエリに取り、`{image_url}` を返す | `hassan-v2-backend/router/router.go:165` (GET のルート定義) / `controller/business_plan.go:824` (`idea_id` のクエリ取得) / `:856` (`GenerateImageRes` の返却) |
| 4 | 保存列は `business_plans.thumbnail_url` ほか 2 箇所 | `hassan-v2-backend/db/schema.sql:198` / `:253` / `:270` |
| 5 | v2 の S3 アップロードは **public-read ACL** を付け、恒久・無署名の URL を返す | `hassan-v2-backend/aws/s3.go:46` ([README.md](README.md) D-API-14' が既に却下している) |

**[../llm-migration.md](../llm-migration.md) の LM-Q3 と矛盾しないこと**: 同書 §4.2 の V-9 は
「**直接 API (Gemini)。機能は維持する。Gemini が LM-D の例外**」と決めており、本節はこれをそのまま適用する。

### 8.2 v3 の設計

| # | 決定 |
|---|---|
| 1 | **`POST /plans/{plan_id}/thumbnail`** (副作用のある操作を GET にしない。§11 の D-PL-10) |
| 2 | **保存するのはオブジェクトキー** — `plans.thumbnail_object_key text NULL` + `plans.thumbnail_generated_at timestamptz NULL` (§12 の R-PL-3)。**URL を列に持たない** |
| 3 | **配布は署名付き URL** ([README.md](README.md) D-API-14')。`Plan` の `thumbnail_url` は応答のたびに発行し、`thumbnail_url_expires_at` を必ず添える。有効期限の既定値はサーバ側定数 1 箇所 |
| 4 | **版ごとにサムネイルを持たない** — v2 は `business_plan_histories.thumbnail_url` / `business_plans_detailed.thumbnail_url` にも持つが、**サムネイルはタブの派生物ではなく企画書 1 件の表紙**であり、版を持つと「どの版の表紙か」の判定が増えるだけで使い道が無い。**却下**: v2 の 3 箇所を踏襲 (同じ値が 3 テーブルに散り、更新漏れが表示のずれとして出る) |
| 5 | **再生成は上書き** (`plans` の 2 列を更新)。旧オブジェクトは削除する。**却下**: 世代を残す (課金対象のストレージが単調増加し、参照する経路が無い) |
| 6 | 計測は `feature=plan.thumbnail` / `route_kind=image_generation`。**トークン系 4 カウンタと `stop_reason` は NULL** になるため、`route_kind` の値追加と「1 枚あたりの単価行型」を §12 の R-PL-6 で起票する |
| 7 | 失敗は **502** (`CodedError`)。**成功を装って旧サムネイルの URL を返さない** |

---

## 9. お気に入り (AC-CV-4.4)

**本節が回答する ID: A-3, A-4** / 対応 AC: **AC-CV-4.4**

### 9.1 v2 の実測

| # | 事実 | 出典 |
|---|---|---|
| 1 | `business_plan_favorites` は `(account_id, business_plan_id)` の複合主キー。`account_id` は `accounts` への FK | `hassan-v2-backend/db/schema.sql:206`〜`:214` |
| 2 | **書き手は `POST` / `DELETE /business-plans/:id/favorite` の 2 本** | `hassan-v2-backend/router/router.go:163` / `:164` |
| 3 | **読み手は企画書側ではなくアイデア一覧** — `GET /ideas` に「お気に入りの企画書があるアイデアだけ」の絞り込みと `is_business_plan_favorite` フィールドがある | `hassan-v2-backend/repository/idea.go:171` (絞り込み) / `:223` (フィールド) |

### 9.2 v3 の設計

| 項目 | 決定 |
|---|---|
| テーブル | **`plan_favorites`** (新設。§12 の R-PL-1 で起票) |
| 主キー | **`(plan_id, account_id)`** の複合主キー (`idea_assets` と同じ join テーブルの前例に揃える。[../data-model.md](../data-model.md) §4.6) |
| 所有者列 | **`contract_id` + `account_id`** (A-3。**`account_id` は主キーの一部でもあり所有者列でもある**) |
| FK | `plan_id` → `plans` (CASCADE) / `account_id` → `accounts` (CASCADE) |
| **読み手 (BE-10)** | ①**`GET /plans` の `favorite=true` 絞り込み** ②**`Plan.is_favorite` フィールド** ③**`GET /ideas` の絞り込みとフィールド** (v2 の読み手を落とさない → `ideas.md` への依頼として §12 の R-PL-13 で起票) |
| スコープ | **個人**。他人の企画書はそもそも 404 なので、お気に入りに登録できない |
| 冪等性 | `POST` は既に登録済みでも **201**、`DELETE` は未登録でも **204**。**却下**: 409 / 404 を返す (ボタンの二度押しがエラーになり、FE が状態を持ち直す処理を書くことになる) |

---

## 10. 企画書 CRUD と横断事項 (AC-CV-4.9)

**本節が回答する ID: A-4, A-7, O-6** / 対応 AC: **AC-CV-4.9**

### 10.1 会話を経由せず企画書を開ける経路

**PoC は会話セッション経由でしか企画書に辿り着けない**。v3 は次の 3 経路で開ける:

1. **`GET /plans`** → **`GET /plans/{plan_id}`** (テーマ・アイデアで絞り込む)
2. **`GET /plans?idea_id=`** (アイデア詳細画面から)
3. 会話ターンの `artifact(plan)` が返す `plan_id` → **`GET /plans/{plan_id}`**

### 10.2 会話セッションとの関係

- **`plans` は `conversation_session_id` を持たない** — 企画書はアイデアに紐づき (`plans.idea_id`)、
  アイデアが会話セッションに紐づく (`ideas.conversation_session_id`。[../data-model.md](../data-model.md) §4.6)。
  **同じ関係を 2 段持たない**
- 会話セッションを削除しても企画書は残る (`ideas.conversation_session_id` は `SET NULL`)

### 10.3 v2 の `business_plans` 固有列の扱い

| v2 の列 | v3 |
|---|---|
| `concept_overview` / `concept_function` / `persona` | `plan_tab_versions.content` (`service` タブ) |
| `bmc_*` 9 列 | 同 (`bmc` タブ) |
| `generation_status` | **列に持たない** — `plans.generating_started_at` / `generating_tab_id` (§4.9) と `tabs[].status` (§2.1) で表す |
| `thumbnail_url` | `plans.thumbnail_object_key` (§8) |

### 10.4 共有・公開 (A-7)

- **`plans.visibility` (`private` / `contract`。既定 `private`) を持つ** (§12 の R-PL-3 で起票)。
  [../auth.md](../auth.md) §6.12 は v2 の `sharing_settings` の 3 カテゴリ (`idea` / `asset` / **`business_plan`**) を
  per-resource の `visibility` へ移すと決めており、**企画書の受け皿が無いとその決定が実装できない**
- 移行時の初期値は v2 の `sharing_settings` の `business_plan` カテゴリの値
  (ON → `contract` / OFF → `private`)。同書 (a) の方式に揃える
- **`GET /plans` は `scope` パラメータを持つ**。**`scope=contract` は増分 1 から受け付ける** —
  [themes.md](themes.md) / [assets.md](assets.md) / [ideas.md](ideas.md) と同一。
  **食い違いは解消済み (2026-08-02。§12 の R-PL-11)**: [README.md](README.md) D-API-8' を
  [../auth.md](../auth.md) §6.12 (c) / [../data-model.md](../data-model.md) DM-9 に合わせて「増分 1」へ改訂した。
  **旧記述の「解消までは 400 で拒否する」は撤回する** (暫定挙動を実装に持ち込まない)
- **`visibility` の書き込みは `PUT /plans/{plan_id}`** で受ける。読み取りが契約に開くまでは
  値を設定しても表示範囲は変わらない (列と API を先に用意する = 移行時の初期値投入が可能になる)
- **契約外公開 (`open`) は持たない** ([../auth.md](../auth.md) §6.12 (d))

### 10.5 監査ログ (O-6)

**記録対象と項目の SSOT は [../observability.md](../observability.md) §4.5**。本書は**対象操作**を確定させる。

| 操作 | 記録 | 理由 |
|---|---|---|
| 企画書の作成 / 削除 (#2 / #5) | **する** | v2 も `event_logs` に記録している |
| タブの生成 / 再生成 (#6 / #7 / 会話ターン) | **する** (LLM を伴う操作の実行) | [conversation.md](conversation.md) §6.3 と同方針 |
| タブの手動編集・版の復元 (#8 / #11) | **する** | 内容が変わる操作 |
| **版の指示の編集 (#12)** | **する** | §5.1 の 5 |
| サムネイル生成 (#17) | **する** (LLM を伴う操作) | 課金を伴う |
| お気に入り (#13 / #14) | **する** | v2 は `business_plan_favorite` を `event_logs` に持つ (`hassan-v2-backend/entity/event_log.go:75`)。C-16 |
| 一覧・取得・チャット履歴の取得 | **しない** | 参照は対象外 ([../observability.md](../observability.md) §4.5) |

**本書で新しい記録項目を追加しない**。書き込み失敗時の扱い (別トランザクションの best-effort + warn) は
[../architecture.md](../architecture.md) §3.9③ が SSOT。

---

## 11. 設計判断

| # | 論点 | 採用案 | 却下案と理由 |
|---|---|---|---|
| **D-PL-1** | **`plans` の `UNIQUE (idea_id)`** (AC-CV-1.4 / F-CV1) | **維持する** (`UNIQUE (idea_id) WHERE deleted_at IS NULL`)。**`POST /plans` は既存があれば 409**。v2 に複数行がある場合の移行規則は下段 | (a) **制約を外す (v2 に合わせて 1 アイデアに複数の企画書を許す)**: ①「別案の企画書」は**タブの版**で表現できるため plans 行を増やす必要が無い ②[conversation.md](conversation.md) §2.3.2 が「`plans` 行が存在すれば `plan` ステージ」と定めており、複数行だとどれを指すか決まらない ③[themes.md](themes.md) の企画書件数と [idea-boards.md](idea-boards.md) の表示が「アイデア 1 件に企画書 3 件」を表現できない ④会話の `generate_plan` tool は `idea_id` しか受け取らない ([conversation.md](conversation.md) §4.1) ため、Agent がどの企画書に書くか決められない ⑤[../data-model.md](../data-model.md) §4.6 の既存判断 (「どれが正か決まらず、タブ版の採番の親が曖昧になる」) を覆すことになる。(b) **「移行時に確認する」と先送りする**: AC-CV-1.4 が明示的に禁じている (`POST /business-plans` を第 1 リリースで受ける以上、409 / 201 の分岐がここで決まる) |
| **D-PL-2** | 生成の入口 | **3 入口 (会話 tool / `POST .../generate` / `POST .../regenerate`) が同一 UseCase を共有し、`feature` は `plan.generate` で共通** (§4.3) | (a) 会話ターン経由のみ: 1 タブの作り直しに会話 1 往復が要り LLM コストと待ち時間が増える (CV-Q10 の却下 B)。(b) 入口ごとに UseCase を分ける: 安全弁・所有者スコープ・stale 記録の 3 つが入口ごとに書かれ、片方だけ直す修正漏れが起きる |
| **D-PL-3** | 再生成の粒度 | **タブ単位 + 任意の `sections`** (§4.3) | (a) タブ単位のみ: v2 の 18 の生成ターゲット (簡易 12 + 詳細 6) が 8 タブに丸められ、**手動編集した他セルが再生成で失われる**。v2 はこれを明示的に守っている (`hassan-v2-backend/usecase/business_plan/generate_business_plan.go:160`)。(b) セクション単位の REST (`/tabs/{tab_id}/sections/{section_id}/regenerate`): 版の親が (plan, tab) なので、セクション単位で版を切ると `UNIQUE (plan_id, tab_id, ver_no)` の親が 2 系統になる。(c) セクションごとに部分保存する: 1 タブの `content` が複数版に分裂し「今表示している内容」を組み立てる処理が必要になる |
| **D-PL-4** | v2 の生成ジョブ 3 本の受け方 | **非同期ジョブにせず、同期 SSE 1 本にする** (§3 の #2〜#4) | (a) [README.md](README.md) §1.3 の J-1〜J-7 に載せる: 進捗の DB ポーリング機構・`plan_generation_jobs` テーブル・購読権検証が増える。[conversation.md](conversation.md) の D-CV-1 と同じ理由。(b) **v2 のジョブ機構を移植する**: v2 は状態も購読者もプロセスのメモリに持つ (`hassan-v2-backend/usecase/business_plan/generation_job_manager.go:57`〜`:80` の `jobsByID` / `subscribers`) ため、**J-2 (状態の SSOT は DB) と J-6 (goroutine と SSE 接続の分離) の両方に反する**。ECS のローリング更新でジョブが消え、`GET /jobs/:id` が「存在しないジョブ」を返す |
| **D-PL-5** | v2 の「版の事前確保」(#18) | **受け先を作らない (採番は保存時の 1 SQL に閉じる)** | (a) `POST /plans/{plan_id}/tabs/{tab_id}/versions` で空版を先に作る: 「確保したが書かれなかった版」が残り `ver_no` に穴が空く。[../data-model.md](../data-model.md) §4.11.1 の規約 1・4 (採番と Insert を 1 文に / 版番号を引数で受け取らない) と両立しない (BE-11) |
| **D-PL-6** | 版に紐づく指示の保持 | **`plan_tab_versions.instruction` 列を持ち、読み手 (次回再生成の履歴) と対で実装する** (§5.1) | (a) 列を持たない: `PUT /business-plans/:id/histories/:history_id/prompt` の受け先が消え C-16 違反。v2 の「過去の指示を履歴として次の生成に渡す」挙動も再現できない。(b) **v2 の「手動編集時は本文の先頭 30 文字を入れる」を踏襲** (`hassan-v2-backend/usecase/business_plan/update_business_plan.go:79`): 指示ではない文字列が「指示」の列に入り、読み手の LLM に「先頭 30 文字」が指示として渡る。(c) 台帳 (`conversation_sessions.ledger`) に持つ: REST 経路の再生成には会話セッションが存在しない |
| **D-PL-7** | v2 の `hypothesis_poc` の写像先 | **`tech` タブの `hypothesis_poc` セクション** (§4.3 の `sections` で単独再生成できる) | (a) **9 番目のタブを新設**: 「8 タブ」という前提が本リポジトリの設計文書・FE の union 型・`progress.total` の定数・プロトタイプに広く埋まっており、タブを 1 本増やすと連動先が全域に及ぶ (**件数は書かない** — 検算の対象外の数値は必ずずれる。DR-9。影響範囲を数えるなら `grep -rl '8 タブ' docs/ aidlc-docs/ templates/` の出力が正)。**C-16 が求めるのは操作の維持であってタブ本数ではない**。(b) `summary` タブに入れる: `summary` は「投資委員会向け 1 ページ」であり、v2 の `evaluation_summary` が既に写像されている。検証計画の詳細 (対象設備・期間・成功指標 — `hassan-v2-backend/entity/business_plan_detailed.go:289`〜`:309`) を入れると 1 ページの目的が壊れる。(c) `service` タブに入れる: サービス概要はコンセプトの定義であり、時間軸を持つ検証計画とは編集の契機が違う。(d) タブ外の別リソースにする: 版管理・stale 判定・再生成の入口をもう 1 系統作ることになる |
| **D-PL-8** | 簡易モード (V-6) の写像 | **`service` + `bmc` の 2 タブへ写像し、12 の生成単位は `sections` で表す** (§6.2) | (a) 12 セクションぶんのタブを作る: 8 → 20 タブになり UI と版管理が破綻する。(b) 写像せず簡易モードの独立経路を残す: [../llm-migration.md](../llm-migration.md) §6.2 の 5 (企画書 3 方式の 1 本化) と LM-Q2 の統合決定に反する |
| **D-PL-9** | 企画書チャットの保存先 | **専用テーブル `plan_chat_messages` 1 本** (§7.2) | (a) **`conversation_sessions` / `conversation_messages` に相乗りする**: ①会話セッションは `theme_id` NOT NULL と台帳を前提にしており (CV-D8)、企画書チャットには台帳が無いため `DeriveStage` が空台帳に対して常に `asset` を返す行が増える ②`GET /conversations` の一覧に企画書チャットが混ざる ③`conversation_tool_calls.turn_seq` の意味 (D-CV-8) が経路によって変わる。(b) **v2 の 2 テーブル構成を移植する** (`business_plan_chats` + `business_plan_chat_messages`): 中間表は `business_plan_id` ↔ Dify の `conversation_id` の対応表にすぎず、Dify を廃止する v3 では `plan_id` が同じ役割を果たす。加えて v2 の本文テーブルは**所有者列も FK も持たない** (`hassan-v2-backend/db/schema.sql:225`〜`:232`) ため、そのまま移植すると A-3 に反する |
| **D-PL-10** | サムネイル生成のメソッドと保存 | **`POST /plans/{plan_id}/thumbnail`。オブジェクトキーを列に持ち、署名付き URL を応答のたびに発行** | (a) **v2 踏襲の `GET /business-plans/generate-image`** (`hassan-v2-backend/controller/business_plan.go:817`): 課金を伴う生成が GET なので、ブラウザのプリフェッチ・リトライ・キャッシュ制御で意図しない生成が走る。(b) **恒久 URL を列に保存する** (v2 の `thumbnail_url` + public-read ACL — `hassan-v2-backend/aws/s3.go:46`): URL を知る誰でも認証なしで読める。[README.md](README.md) D-API-14' が既に却下している |
| **D-PL-11** | お気に入りの持ち方 | **専用テーブル `plan_favorites` (複合主キー + 所有者列)** | (a) `plans` に `is_favorite boolean` 列を足す: お気に入りは**アカウントごと**の状態であり、企画書 1 行に持たせると契約内共有時に他人の状態を上書きする。(b) `ideas` 側に持つ: v2 の読み手がアイデア一覧にあるからといって**状態の所有者は企画書**であり、企画書を消したときに孤児が残る |
| **D-PL-12** | `GET /plans/{plan_id}` に版一覧を同梱するか | **同梱しない** (最新版 + `version_count` のみ) | (a) **v2 踏襲 (`GET /business-plans/:id` が `histories` を同梱)** (`hassan-v2-backend/usecase/business_plan/get_business_plan.go:66`): v2 は 1 企画書 = 1 履歴系列だが、v3 は 8 タブ × N 版になる。全部載せると 1 応答が数 MiB になり、企画書を開くたびに全履歴を転送する |
| **D-PL-13** | 一覧の絞り込み | **`account_id` クエリを持たない** (`scope` と認証情報で決まる) | (a) **v2 踏襲** (`hassan-v2-backend/controller/business_plan.go:549` が `c.Query("account_id")` を読む): [README.md](README.md) D-API-8 が「最も事故が大きい規約」として機械検査を必須にしている入力形そのもの (F-15) |
| **D-PL-14** | V-7 (ブラッシュアップ stage-1 のクエリ補強) | **独立した LLM 呼び出しにせず、§5.1 の 3 の履歴を P-4 にそのまま渡す** | (a) **v2 踏襲 (補強専用の LLM 呼び出しを 1 回挟む)**: ①LLM 呼び出しが 1 経路増え、`feature`・失敗分類・安全弁の適用点が増える ②v2 の実装は**補強に失敗しても原文で続行する best-effort** (`hassan-v2-backend/usecase/business_plan/generate_business_plan.go:194`〜`:200` が失敗時に原文へフォールバックする) であり、必須の段ではない ③Managed Agent は同一セッション内で文脈を保持できるため、補強を別呼び出しにする前提が弱い。**品質差は [../llm-migration.md](../llm-migration.md) §8 の確認対象にする** (§13 の PL-R2) |
| **D-PL-15** | V-11 (詳細版 Web リサーチ 5 フェーズ) | **P-4 の web_search 経路に統合する** | (a) 5 フェーズの固定パイプラインを直接 API として移送する: 企画書の生成経路が P-4 と固定パイプラインの 2 系統になり、[../llm-migration.md](../llm-migration.md) §6.2 の 5 (1 本化) の目的が達成されない。計測とプロンプト管理も 2 系統になる。**品質差は同 §8 の確認対象** (§13 の PL-R3) |
| **D-PL-16** | 生成のトランザクション境界 | **タブ 1 件の保存 = 1 トランザクション** (§4.8) | (a) **8 タブを 1 トランザクションにする** ([../data-model.md](../data-model.md) §4.11.1 の規約 5 の現行記述): ①タブ単位の再生成 (#7) では対象が 1 タブなので規約が適用できず、入口によってトランザクション粒度が変わる ②安全弁の発火 (§4.7) で「それまでのタブを確定させる」ことができず、5 分の実行で全部が捨てられる ③SSE の `artifact` は**保存後に送る**契約 (§4.4 の 2) なので、1 トランザクションだと全タブ完了までユーザーに何も出せない。**規約 5 の改訂を §12 の R-PL-3 で起票する** (無言で逸脱しない) |
| **D-PL-17** | 手動編集 (#8) が版を切るか | **切る** (`origin=manual`) | (a) 切らない (最新版を上書き): 手動編集の内容が次の再生成で黙って消え、戻す手段が無い。v2 も手動編集で履歴行を作る (`hassan-v2-backend/usecase/business_plan/update_business_plan.go:99`) |
| **D-PL-18** | パスのネスト段数 | **版の操作 (#11 / #12) は 3 段ネストを許す** (`/plans/{plan_id}/tabs/{tab_id}/versions/{ver_no}/…`) | (a) [README.md](README.md) D-API-2 の「ネストは 2 段まで」を守るため `/plan-tab-versions/{version_id}` をトップレベルに置く: 版 ID 単独では所有者・タブへの所属が URL から読めず、**所有者条件付きクエリの入力が 1 つ (version_id) だけ**になる。所有チェックは可能だが、**誤って親を検証しないクエリを書ける形**を作る。(b) `ver_no` ではなく版の PK を使って 2 段にする: `ver_no` はユーザーに見える番号 (「v3 に戻す」) であり、PK を URL に出すと FE が 2 種類の識別子を持つ。**この逸脱は本書だけの局所的なもの**で、他ドメインへ広げない。**却下 (b) の適用範囲は企画書タブの版に限る** (2026-08-02 追記) — [ideas.md](ideas.md) は `{version_id}` (PK) を使うが、**アイデアの版は PK が `plan_tab_versions.source_idea_version_id` / `idea_evaluations.source_idea_version_id` から参照されており FE に既に渡っている**ため、そちらでは PK を使う方が識別子が 1 種類で済む (理由は [ideas.md](ideas.md) §4.2.1)。**識別子だけが違い、版の意味論 (復元は新版・削除なし・採番 1 SQL) は同一** |
| **D-PL-19** | 一覧の `keyword` の対象 | **`ideas.title` と `ideas.summary`** | (a) タブ本文 (`plan_tab_versions.content` の JSONB) を対象にする: 全タブ全版に対する全文検索になり、GIN インデックスの設計と更新コストが本増分の範囲を超える。**必要になった時点で追加する** (追加は後方互換)。(b) 対象を書かない: 実装者判断に丸投げ (DR-5) |

---

## 12. 他文書への是正要求 / 受信欄

### 12.1 本書が起票するもの (状態列つき)

**状態は「未対応 / 実施済み / 対応不要」+ 日付**。統合作業 (CV-D の単位) で消化する。
[requirements-conversation.md](../../../aidlc-docs/inception/productionization/requirements-conversation.md) §5 に
既に同じ内容の起票がある場合は「既存 ID」列で対応付ける (二重管理しない)。

| ID | 起票先 | 内容 | 理由 (やらないと何が壊れるか) | 既存 ID | 状態 |
|---|---|---|---|---|---|
| **R-PL-1** | [../data-model.md](../data-model.md) §4.6 | **`plan_favorites` テーブルを追加**する (§9.2 の定義)。**DR-9 の連動あり** — [idea-boards.md](idea-boards.md) §8.2 の 15 箇所リストを手順として使い、**`make check-table-counts` の期待値まで同じ差分で更新する** | AC-CV-4.4 が実装できない。件数の取り残しは「設計どおりに実装した検査が必ず落ちる」形で実装リポに出る | R-CV-4 | **実施済み** (2026-08-02。data-model.md §4.1.1 に `plan_favorites` を追加 = 機能テーブル 42・分類① 31。`make check-table-counts` は照合 37 件・エラー 0) |
| **R-PL-2** | [../data-model.md](../data-model.md) §4.6 | **`plan_chat_messages` テーブルを追加**する (§7.2 の定義)。**DR-9 の連動あり** (R-PL-1 と同じ手順)。**`make check-table-counts` の期待値更新を伴う** | AC-CV-4.7 が実装できない。**R-PL-1 と合わせて機能テーブルが 2 件増える** ため、両者を 1 差分で入れる | R-CV-6 (前半) | **実施済み** (2026-08-02。同じ差分で `plan_chat_messages` を追加。転記先 13 箇所を全件更新した) |
| **R-PL-3** | [../data-model.md](../data-model.md) §4.6 / §4.11.1 | **列の追加・変更 6 点** (**新規テーブルではないので `check-table-counts` の件数には影響しない**): ①`plan_tab_versions.instruction text NOT NULL DEFAULT ''` (§5.1) ②`plan_tab_versions.source_idea_version_id` を **NOT NULL** 化 (§4.10 の 2) ③`plans.thumbnail_object_key text NULL` + `plans.thumbnail_generated_at timestamptz NULL` (§8.2) ④`plans.visibility` (`private`/`contract`。既定 `private`。§10.4) ⑤`plans.generating_started_at timestamptz NULL` + `plans.generating_tab_id text NULL` (§4.9) ⑥**§4.11.1 の規約 5 (「企画書 8 タブの保存は 1 トランザクション」) を「タブ 1 件の保存が 1 トランザクション」へ改訂**する (§11 の D-PL-16) | ①が無いと #10 の受け先が消える (C-16)。②が無いと BE-1 の記録に穴が空く。③④が無いと V-9 と A-7 の受け皿が無い。⑤が無いと 409 の判定と切断時の回復が実装できない。⑥は**本書が既存規約から逸脱する唯一の点**であり、放置すると実装が 2 つの規約の間で判断を迫られる | R-CV-5 (①) / R-CV-6 (③) | **実施済み** (2026-08-02。`plan_tab_versions.instruction` / `plans.visibility` / `thumbnail_object_key` / `thumbnail_generated_at` を追加し、§4.11.1 の規約 5 を「タブ 1 件 = 1 トランザクション」へ改訂。§4.6 の対応 API 欄も 3 ファイルへのリンクに更新) |
| **R-PL-4** | [../data-model.md](../data-model.md) §4.6 / §6.4 | **`plans` の `UNIQUE (idea_id)` を維持する**ことを AC-CV-1.4 の結論として明記し、**v2 の既存データに 1 アイデア複数行がある場合の移行規則**を §6.4 に加える: **`business_plans` を `idea_id` ごとに `updated_at DESC`(同値なら `id DESC`) で 1 行だけ `plans` に写像し、残りは `plan_tab_versions` の版として古い順に取り込む** (`ver_no` は 1 SQL 採番)。**移行時に複数行が存在した `idea_id` の一覧を移行レポートに出す** | 制約の可否は `POST /plans` の 409 / 201 の分岐を決める。移行規則が無いと、複数行のある契約で移行が落ちるか、黙って 1 行が捨てられる (DR-3) | R-CV-7 (前半) | **実施済み** (2026-08-02。data-model.md §6.4 の新規一意制約の表に「維持 + 移行規則 (最新 1 行を `plans` へ・残りを版として取り込む・複数行のあった `idea_id` を移行レポートに出す)」を記載) |
| **R-PL-5** | [conversation.md](conversation.md) §5.1 / §5.3 | ①**`turn_summary.message_seq` を任意フィールドにする** (企画書 REST 経路には会話メッセージが無い) ②§5.3 の順序契約に「**会話ターン経路**」の見出しを付け、「企画書経路の順序契約は `plans.md` §4.4」への参照を加える | ①が無いと、企画書経路が必須フィールドを埋められず OpenAPI の discriminated union が破れる。②が無いと「`session` が先頭」という契約に企画書経路が違反しているように読める | — | **実施済み** (2026-08-02。conversation.md §5.1 で `message_seq` を任意化し、§5.3.1 を新設して 3 経路 (会話ターン / タブ生成・再生成 / 企画書チャット) が使うイベントと順序契約の適用範囲を表にした) |
| **R-PL-6** | [../observability.md](../observability.md) §4.2 | ①`feature` の const 群に **`plan.chat` / `plan.thumbnail`** を追加する (R-CVA-5 の 7 値に加えて 2 値) ②**`route_kind` に `image_generation` を追加**し、**トークン系 4 カウンタと `stop_reason` の NULL 許容を `external_search` と同じ扱いにする** ③**単価テーブル (O-H) に「1 枚あたりの単価」の行型**を追加する | ②③が無いと、画像生成のコストが `estimated_cost=0` で総額から丸ごと落ち、O-3 の集計が構造的に誤る。①が無いと [../testing.md](../testing.md) の LLM 経路テスト存在検査が 0 件を検査して緑になる | R-CVA-5 (①の一部) | **実施済み (2026-08-02 に完了)**。当初は observability.md だけに反映し **`data-model.md` のスキーマ SSOT を取り残していた** (レビュー重大 1)。同日中に是正: `data-model.md` §4.10 の `route_kind` 値域に `image_generation` を追加し、**NULL 許容の CHECK を `route_kind IN ('external_search','image_generation')` の 2 値に拡張**、§5 の O-2 行も更新した。observability.md 側は §4.2.1 に 2 値追加 + §4.2.2 を新設済み |
| **R-PL-7** | [../llm-migration.md](../llm-migration.md) §4.2 / §6.2 の 5 / §7.1 | ①**V-7 / V-8 / V-9 / V-10 / V-11 の優先度を 1 (第 1 リリース) へ引き上げ**、§7.1 の **M-8 を RL-4 → RL-1 相当**へ移す (R-CV-1 に **V-7 を追加**する) ②**V-7 / V-10 / V-11 の実装形態を「直接 API」から「P-4 へ統合」に変更**する (§6.3) ③§6.2 の 5 の「**V-10 は統合対象ではなく独立移送**」という記述を撤回し、「簡易モード (V-6) の写像判定は完了 (`plans.md` §6.2)」を反映する | CV-D1 と正面から衝突する判定が残ると、実装リポが第 1 リリースから外す (F-CV7)。②③を直さないと、企画書の生成経路が P-4 と直接 API の 2 系統として実装される | R-CV-1 | **実施済み** (2026-08-02。①V-7〜V-11 の優先度を 1 へ ②V-7 / V-10 / V-11 の実装形態を「P-4 へ統合」へ ③§6.2 の 5 の「V-10 は独立移送」を撤回し簡易モードの写像判定を反映。**M-8 の段割りだけは未変更**で LM-R10 として起票済み) |
| **R-PL-8** | [../../analysis/v2-feature-inventory.md](../../analysis/v2-feature-inventory.md) §2.7 / §5 | ①§2.7 に **「v3 の対応」列**を追加し、本書 §3 の 18 行を転記する (**リンク先は `docs/design/API/plans.md`**) ②§5 の **#9 / #10 を「解消済み」に更新**し解消先を書く (§3.1) ③**`POST /business-plans/generate` の説明「企画書の生成 (同期)」を訂正**する — 実体は **SSE** (`hassan-v2-backend/controller/business_plan.go:242` が `streamChannelAsSSE` を呼ぶ) ④**`GET /business-plans/generate-image` の状態が「引き継ぐ」で他 17 行と粒度が違う**点を、他行と同じ「統合 / 引き継ぐ」の基準で見直す | ②は C-16 の完了条件 (「§5 の『対象外 (要確認)』が空になること」)。③は事実の誤りで、v3 の SSE 本数の見積りに影響する | R-CV-10 | **実施済み** (2026-08-02。§2.7 の見出しを `plans.md` 参照へ / `POST /business-plans/generate` の「同期」を SSE に訂正 / §5 の #9・#10 を解消済みに更新) |
| **R-PL-9** | [README.md](README.md) §0 / §1.3 / §3 + `scripts/check-endpoint-mapping.sh` | ①§0 の「会話型アイデア創出は対象外」宣言の解除に**企画書ドメインを含める** ②§3 の総覧に**企画書ドメイン (本書 §1.1 の 17 本・LLM 4 / SSE 3 / 403 0)** を追加し、小計・合計・「共通規約が対象にするのは N 本」の注記・§3.x 明細を**同じ差分で**更新する ③検査④の対象集合に `plans` を加える ④§1.3 に「**企画書の生成 (`POST /plans/{plan_id}/generate` / `.../regenerate`) は同期 SSE であり J-6 の対象外。ただし J-7 は満たす**」を明記する (§4.9 の 5) | ③をやらないと、機構を直さずに文書だけ増える形になり検査が新ファイルを見ないまま「通った」ことになる (F-CV11 / DR-9)。④が無いと J-1〜J-7 からの無言の逸脱になる | R-CV-9 / R-CV-2 | **実施済み** (2026-08-02。README §3 の総覧に企画書 17 本 (LLM 4 / SSE 3) を追加し §3.9 を新設。§1.3.1 に企画書 SSE 3 本が J-6 対象外・J-7 充足である旨を追記。検査④の対象集合も拡張) |
| **R-PL-10** | [../frontend.md](../frontend.md) §6.3.1 | 中継 Route Handler の許可リストに **`POST /plans/{plan_id}/generate`** と **`POST /plans/{plan_id}/chat/messages`** の 2 行を追加し、既存の「`POST /plans/{plan_id}/tabs/{tab_id}/regenerate` (企画書タブの再生成)」行の参照先を **`API/plans.md` §1** に更新する (現在は参照先が無い) | 許可リストがファイルの存在そのものなので、行が無い = **Next.js が 404 を返して機能が動かない**。SSE の中継が 3 本になることが FE の実装量に直結する | R-CV-11 (一部) | **実施済み** (2026-08-02。frontend.md §6.3.1 に `generate` / `regenerate` / `chat/messages` の 3 行を追加し、参照先を `API/plans.md` §1 に確定) |
| **R-PL-11** | [README.md](README.md) D-API-8' / [../auth.md](../auth.md) §6.12 | **`scope=contract` を有効化する増分の食い違いを解消する** — D-API-8' は「テーマ / アセット / アイデアは増分 2」、auth.md §6.12 (c) は「契約内共有の読み取りと `visibility` の書き込みは増分 1」と書いており、**両者が矛盾している**。あわせて **`business_plan` カテゴリ (企画書) を対象リソースの列挙に明記**する (現在どちらの列挙にも企画書が無い) | 企画書の `scope=contract` の可否が決まらず、§10.4 が「解消まで 400」という暫定状態で残る。v2 の `sharing_settings` は `business_plan` カテゴリを持つため (auth.md §6.12 の実測)、企画書が列挙から漏れると切替時に**機能退行か一斉公開のどちらか**が起きる | — | **実施済み (2026-08-02 に完了)**。当初は D-API-8' 本体しか直さず **README §5 の A-7 行・API-Q3・§6.1 の増分 2 の作業単位、および `ideas.md` の 6 箇所・本書 §10.4 の暫定挙動を取り残していた** (レビュー重大 3)。同日中に全件を「増分 1」へ統一し、`auth.md` §10.4 の R-9 の状態列も更新した |
| **R-PL-12** | [../testing.md](../testing.md) | LLM 経路テストの対象集合に **`plan.generate` / `plan.chat` / `plan.thumbnail`** を追加する。**`plan.generate` は 3 入口すべて** (会話 tool / `POST .../generate` / `POST .../regenerate`) をテスト対象にする | 入口が 3 つあるのに 1 つしかテストしないと、「入口によって所有者スコープ・安全弁・計測が変わる」退行を検出できない (§4.3 の 2・3 が担保できない) | — | **実施済み** (2026-08-02。testing.md の存在検査 #5 に「`feature` 単位の検査では入口の複数性を検出できない」限界と、`plan.generate` の 3 入口を対象にする要求を追記) |
| **R-PL-13** | [ideas.md](ideas.md) §4 | ①**アイデアの生成時点で `idea_versions` の ver 1 を必ず作る**ことを定義する — `plan_tab_versions.source_idea_version_id` を NOT NULL にするための前提 (§4.10 の 2) ②**`GET /ideas` に「お気に入りの企画書があるアイデアだけ」の絞り込みと `is_plan_favorite` フィールドを持たせる** — v2 の読み手 (`hassan-v2-backend/repository/idea.go:171` / `:223`) を落とさない (C-16) ③**アイデアの論理削除時に企画書をどうするか**を定義する (`plans.idea_id` は FK CASCADE のため、物理削除時は企画書も消える) | ①が無いと、企画書の初回生成で `source_idea_version_id` に入れる値が無い。②が無いと v2 の絞り込みが落ちる。③が無いと「アイデアを消したら企画書がどうなるか」が実装者判断になる | — | **実施済み** (2026-08-02。ideas.md §4 が版の規則を確定済みであることを確認し、相互リンクを張った) |

### 12.2 本書が受け取った是正要求 / 委譲 (受信欄。DR-8 の受信側)

| 起票元 | ID | 内容 | 本書での回答 | 状態 |
|---|---|---|---|---|
| [conversation.md](conversation.md) §4.2 | 企画書タブの再生成 / 版一覧・復元を REST で受けること | パスと入出力の確定 | **§1.1 の `POST /plans/{plan_id}/tabs/{tab_id}/regenerate` と版の 3 本 (`versions` 一覧・取得・`restore`)** | **回答済み** (2026-08-01) |
| [conversation.md](conversation.md) §3.1 / §3.3 | P-4 の呼び出し元に「`plans.md` のタブ再生成 REST」が含まれること / `feature` が `plan.generate` で共通であること | 3 入口の共有 | **§4.2 / §4.3 / §4.6** | **回答済み** (2026-08-01) |
| [conversation.md](conversation.md) §5.1 / §5.2 | `progress` の `scope:"plan"` と `artifact(plan)` の payload | 企画書経路での使い方と順序契約 | **§4.4** | **回答済み** (2026-08-01) |
| [requirements-conversation.md](../../../aidlc-docs/inception/productionization/requirements-conversation.md) §7 の 3 | v2 の企画書に複数行が実在するか (F-CV1) | AC-CV-1.4 の決定 | **§11 の D-PL-1** (維持 + 移行規則を R-PL-4 で起票) | **回答済み** (2026-08-01) |
| [requirements-conversation.md](../../../aidlc-docs/inception/productionization/requirements-conversation.md) §7 の 4 | 簡易モード (V-6) の 8 タブ写像可否 (F-CV8) | 判定 | **§6.2** (写像できる。粒度は `sections` で表す) | **回答済み** (2026-08-01) |
| [../llm-migration.md](../llm-migration.md) §6.2 の 5 | 「簡易モードの出力粒度が 8 タブに写像できるか未確認」「統合の設計は会話型 API 設計が担う」 | 判定と統合設計 | **§6.2 / §6.3** (+ 同書への是正要求 R-PL-7) | **回答済み** (2026-08-01) |
| [../data-model.md](../data-model.md) §4.6 | 「生成系は会話型 API 設計 (対象外)」の対応 API 欄 | 企画書の対応 API の確定 | **本書 §1.1** (同書の「対応 API」列の更新は R-PL-3 に含める) | **回答済み** (2026-08-01) |
| [../../analysis/v2-feature-inventory.md](../../analysis/v2-feature-inventory.md) §2.7 | 「v3 の対応先は未設計 (Task-3p が受ける)」 | 18 本の受け先 | **§3** | **回答済み** (2026-08-01) |
| [../../analysis/v2-feature-inventory.md](../../analysis/v2-feature-inventory.md) §5 | #9 (お気に入り) / #10 (版履歴のプロンプト編集) | 解消先 | **§9 / §5.1** (同書の更新は R-PL-8 で起票) | **回答済み** (2026-08-01) |
| [../auth.md](../auth.md) §6.12 (a) | `sharing_settings` の 3 カテゴリを per-resource `visibility` へ移す (`business_plan` を含む) | 企画書側の受け皿 | **§10.4** (`plans.visibility`。列追加は R-PL-3、増分の食い違いは R-PL-11) | **回答済み** (2026-08-01) |
| [../llm-migration.md](../llm-migration.md) §9.2 の **LM-R10** | **企画書系の優先度を 1 (第 1 リリース) にした一方で §7.1 の移送段 M-8 が RL-4 (併用期間) のままで整合していない。判定主体に本書が指定されている** (2026-08-02 起票) | 「v2 の既存企画書データを第 1 リリース時点で v3 へ移すか」の判断 | **§13 の PL-R10** (本書では決めきれない — 判断材料が v2 本番 DB の実データと [../operations.md](../operations.md) の移送設計にあるため) | **受信済み・未回答** (2026-08-02) |

---

## 13. 残課題 / 要確認

**仮定を添えて書く。違えば §11 の判断が変わる。**

| ID | 内容 | 仮定 (この前提で設計した) | 確定先 |
|---|---|---|---|
| **PL-R1** | **v2 の `business_plans` に 1 アイデア複数行が実在するか** (F-CV1。本番 DB の実測が未実施) | **「あってもなくても成立する移行規則」を書いた** (R-PL-4)。実在しなければ規則は空振りするだけで、`UNIQUE (idea_id)` 維持の判断は変わらない | 移行計画 (plan.md の Task-2f 系) の実測 |
| **PL-R2** | **V-7 (ブラッシュアップ stage-1 のクエリ補強) を落としても品質が落ちないか** | **落ちないと仮定した** (§11 の D-PL-14)。v2 の実装が best-effort であること (`hassan-v2-backend/usecase/business_plan/generate_business_plan.go:194`) を根拠にしている。**落ちる場合は P-4 のプロンプト側で吸収する** — 独立 LLM 呼び出しを復活させる前に、プロンプトでの吸収を先に試す | [../llm-migration.md](../llm-migration.md) §8 の品質確認 |
| **PL-R3** | **V-11 の 5 フェーズ Web リサーチを P-4 の web_search に置き換えて品質が保てるか** | **保てると仮定した** (§11 の D-PL-15)。PoC の企画書 Agent が既に web_search を使っている (`claude_managed_agents/prompts/idea_plan_agent_system.md:21`) ことを根拠にしている。**保てない場合、5 フェーズは P-4 のプロンプト内の手順として書く** (独立エンドポイントを増やさない) | 同上 |
| **PL-R4** | **タブラベル・セクション名の多言語化** — 本書はサーバが日本語ラベルを返す前提 | **第 1 リリースは日本語のみと仮定した**。多言語化が必要になったら `label` を廃してコード化し FE が表示文言を持つ ([conversation.md](conversation.md) の CV-R3 と同じ扱い) | [../frontend.md](../frontend.md) の i18n 方針 |
| **PL-R5** | **`sections` の値域 (タブごとのセクション ID 集合) の具体値** | **`entity/plan` の `PlanTabSections` 1 箇所に持つ**前提で設計し、本書には v2 から写像される分 (§6.1 / §6.2) しか書いていない。PoC のタブ本文の構造から導く残りのセクション ID は実装時に確定する | 実装リポ (P-4 のプロンプトとタブ型の実装時) |
| **PL-R6** | **`instruction` を何版ぶん P-4 に渡すか** (§5.1 の 3 の N) | **`config` に置く**前提で設計し、本書に数値を書いていない (BE-2)。v2 は直近 `brushUpHistoryLimit` 件に制限している (`hassan-v2-backend/usecase/business_plan/generate_business_plan.go:156`) ため、同等の制限が要る | 実装リポの `config` |
| **PL-R7** | **`tabs[].status = generating` の粒度** — §4.9 は `plans` の 2 列で表す設計 | **同時に走る生成は企画書あたり 1 本**と仮定した (409 で排他)。「タブ 1 と タブ 5 を同時に再生成したい」という要求が出た場合、2 列では表せずタブ単位の状態列 (または新テーブル) が要る。**その要求は現時点で確認できていない** | プロトタイプではなく利用実態 (第 1 リリース後) |
| **PL-R8** | **企画書チャットの LLM に渡す文脈の量** — 8 タブ全文を毎回渡すか、要約を渡すか | **8 タブの最新版全文を渡す**前提で設計した (v2 も企画書全体を system prompt に入れる — `hassan-v2-backend/usecase/business_plan/business_plan_chat.go:121`)。タブが大きくなると入力トークンが発散するため、上限と切り詰め方は実装時に決める | 実装リポ (V-8 の実装時) / [../observability.md](../observability.md) の実測 |
| **PL-R10** | **LM-R10 (企画書系の優先度 1 ↔ 移送段 M-8 = RL-4 の不整合) への回答**。「優先度 = v3 に機能を作る段」と「M-x = v2 からトラフィックとデータを移す段」は別物なので、**「v3 に企画書機能がある状態で第 1 リリースし、移送は RL-4」は論理的には成立する** | **成立するかは v2 の既存企画書データの扱い次第**と仮定した — 第 1 リリース時点で移さないと利用者は「企画書が空の v3」を見ることになり、C-16 の「操作を落とさない」は満たしても実質的な後退になる。**本書は移行規則 (§12 の R-PL-4 = 最新 1 行を `plans` へ・残りを版として取り込む) までは決めたが、いつ移すかは決めていない**。判断には v2 本番 DB の企画書件数の実測 (PL-R1 と同じ調査) と [../operations.md](../operations.md) の RL 段の見直しが要る |
| **PL-R9** | **アイデアの論理削除時に企画書をどう見せるか** | **`plans` は残り、アイデアが削除済みであることを応答に含める**と仮定した ([idea-boards.md](idea-boards.md) D-IB-7 と同じ扱い)。`ideas.md` が別の結論を出した場合、§2.1 の `idea_title` の返し方が変わる | `docs/design/API/ideas.md` (R-PL-13 の③) |

---

## 14. 実装リポへの引き渡し

### 14.1 依存順序

```
data-model.md の企画書テーブル (+ R-PL-1/2/3/4 の反映)
   ↓
entity/plan (PlanTabID 8 値 / PlanTabSections / origin の const / タブ本文の型)  ← UT 必須
   ↓
gateway/anthropic (CallMeta) / gateway/gemini (画像生成。R-PL-6 の route_kind)
   ↓
repository/plan (版採番 1 SQL・所有者条件・generating の FOR UPDATE NOWAIT)
   ↓
service (P-4 の実行・SSE 変換・安全弁)      ← conversation.md §9.1 の Runner と共有
   ↓
usecase/plan (GeneratePlanTabs = 3 入口共通 / トランザクション境界)
   ↓
controller (SSE ヘッダ・CodedError 変換 1 箇所)
```

**`usecase/plan.GeneratePlanTabs` は [conversation.md](conversation.md) §4.1 の `generate_plan` ハンドラの
呼び出し先でもある** — 会話ドメインの実装より先に固める。

### 14.2 並列可能

- **§2 のオブジェクト定義の OpenAPI 化**は上記と並列に着手できる (FE のブロック解除が最速になる)
- **`prompts/plan/tab.md` + タブ別引数**の起こしは Go の実装と並列
  (レイアウトは [../llm-migration.md](../llm-migration.md) §6.1)
- **お気に入り (#13 / #14) とチャット (#15 / #16)** は生成経路に依存しないため独立に実装できる
- **サムネイル (#17)** は `gateway/gemini` の追加が先行条件 (他の経路と独立)

### 14.3 参照すべき既存実装

| 目的 | 参照先 | 扱い |
|---|---|---|
| 8 タブの ID・表示順・タブ本文の型 | `claude_managed_agents/internal/agent/diverge/plan.go` | **移植元** (`PlanTabDefaultVersions` は移植しない — v3 の版番号は連番採番) |
| タブ生成の SSE 中継 (タブ完了・タブ失敗の扱い) | `claude_managed_agents/cmd/devui/conversation_plan_stream.go` | 順序の参考。**net/http・手書き store は持ち込まない** |
| **反面教師** (BE-11 の実バグ) | `claude_managed_agents/cmd/devui/conversation_tools_plan.go` | 固定 ver での Insert を**しない**。採番は 1 SQL |
| **反面教師** (BE-12 の実バグ) | `claude_managed_agents/cmd/devui/conversation_plan_grounding.go` | 読み手が独自構造体を定義しない。`entity/toolresult` の 1 宣言から導く |
| 版履歴の指示を LLM へ渡す形 | `hassan-v2-backend/usecase/business_plan/brush_up_history_context.go` | **組み立て方の手本** (§5.1 の 3)。ただし「本文の先頭 30 文字」を指示として扱う部分は移植しない |
| 詳細版セクションの出力スキーマ | `hassan-v2-backend/entity/business_plan_detailed.go` | タブ本文の型を起こすときの入力 (§6.1 の写像先ごとに参照) |
| サムネイル生成 (リサイズ・エンコード) | `hassan-v2-backend/usecase/business_plan/generate_business_plan_thumbnail.go` | 画像処理は手本にする。**S3 の public-read ACL は移植しない** (`hassan-v2-backend/aws/s3.go:46`) |
| SSE ヘルパー | `hassan-v2-backend/controller/controller.go` の `SetupSSEHeaders` 系 | v3 の Controller 共通層の手本 (D-API-12) |
| `CodedError` の集約ハンドラ | `hassan-v2-backend/controller/idea_board.go` | 変換 1 箇所の手本 |
