# API: 会話型アイデア創出 (会話セッション・ターン・SSE・custom tool)

> 共通規約 (認証・レスポンス形・エラー・ページネーション・ステータスコード) の SSOT: [README.md](README.md)
> 本ファイルが回答する本番観点: **A-1, A-3 (参照), A-4, A-5, A-6, A-7 (参照), O-2, O-3, O-4, O-5, O-6 (参照), D-6, D-7 (参照)**
> 対応する受入基準: **AC-CV-2.1〜2.8 / AC-CV-5.1〜5.9 / AC-CV-6.1・6.3** (+ AC-1.1 / AC-1.3 / AC-1.4 / AC-2.1 / AC-2.3 / AC-3.3 の維持)
> 要件の SSOT: [requirements-conversation.md](../../../aidlc-docs/inception/productionization/requirements-conversation.md)
> 必須観点 ID 一覧: [../../../.claude/rules/08-production-gates.md](../../../.claude/rules/08-production-gates.md)

## 0. 本書の範囲

### 0.1 範囲内 / 範囲外

| 区分 | 内容 | 所在 |
|---|---|---|
| **範囲内** | 会話セッションのライフサイクル / 会話ターン (同期 SSE) / SSE イベント型 / 発話履歴 / custom tool の集合と契約 / 台帳の読み書き / `stage` の導出 / オーケストレーターの処理順序と安全弁 | 本書 |
| **範囲外 (別セッションが起草)** | アイデアの生成物 API・更新・版・評価・v2 アイデア系の対応表 | **[ideas.md](ideas.md)** (2026-08-02 起草済み) |
| **範囲外 (別セッションが起草)** | 企画書 8 タブ・タブ再生成・版・お気に入り・チャット・詳細版・サムネイル・v2 企画書 18 本の対応表 | **[plans.md](plans.md)** (2026-08-02 起草済み) |
| **範囲外** | 層構成・ツール注入の内部構造・LLM 計測点の実装配置 | [../architecture.md](../architecture.md) §3.8 / §3.10 |
| **範囲外** | 会話まわりのテーブル定義 | [../data-model.md](../data-model.md) §4.5 / §4.11 |
| **範囲外** | 安全弁の**数値**・失敗分類・監査ログの項目 | [../observability.md](../observability.md) §4.3 / §4.4 / §4.5 |

> **リンクを張っていない理由**: `ideas.md` / `plans.md` は本書と同じ増分で並列起草中であり、
> 本書の確定時点で**ファイルが存在しない**。存在しないパスへの相対リンクは `make doc-lint` が
> リンク切れとして落とすため、起草時は本文で `[未作成]` と明示していた。**2026-08-02 に両ファイルが揃ったためリンク化済み**。

### 0.2 本書が回答する本番観点 ID

| ID | 回答節 |
|---|---|
| A-1 認証方式 | §1.1 (全 7 本が認証必須。方式の SSOT は [../auth.md](../auth.md) §6.1) |
| A-2 ロール | §1.1 (`AuthRoleUser` のみ。**403 を返すエンドポイントを持たない**) |
| A-3 テナント境界 | **参照** — [../data-model.md](../data-model.md) §4.5 の 4 テーブルが所有者列を持つ。本書は新規テーブルを定義しない |
| A-4 絞り込みの層 | §4.4 (UseCase が確定し Repository のクエリ条件で強制。ツール経路も同じ) |
| A-5 ステータスコード | §1.1 / §6.1 (**409 = 並行ターン**が新しい分岐) |
| A-6 LLM への越境 | §4.4 (4 点すべて) + §4.1 のツール別スコープ列 |
| A-7 共有・公開 | **参照 (対象外の理由付き)** — 会話は**個人スコープのみ**で共有機能を持たない (§1.1)。`scope=contract` を受け付けない理由は §7 の D-CV-3 |
| O-2 LLM 呼び出しの記録 | §3.3 (`feature` 値の列挙。個別ツールに計測コードを書かない) |
| O-3 コスト集計と上限 | §2.5 (安全弁の適用点)。**上限による拒否は設けない** (C-12) |
| O-4 失敗の可観測性 | §6 (5 分類との対応 + 成功を装うフォールバックを作らない) |
| O-5 SSE / 長時間処理 | §2.4 / §5.3 / §6.2 (切断時の回復経路 2 本・打ち切りの表現) |
| O-6 監査ログ | **参照** — 記録対象と項目は [../observability.md](../observability.md) §4.5 が SSOT。本書は「アイデア・企画書の生成が会話ターン経由でも同方針の対象になる」ことのみ確認する (§6.3) |
| O-1 / O-7 | **対象外** — [../observability.md](../observability.md) §4.1 / §4.6 が SSOT。会話経路に固有のアラートは本増分では追加しない (先送り先: 同書 §4.6) |
| D-6 Agent ライフサイクル | §3.4 (再発行対象・追加は後方互換・削除は 2 段階) |
| D-7 段階リリース | **参照** — [../operations.md](../operations.md) §6 が SSOT |
| D-1〜D-5 / D-8 | **対象外** (インフラ・CI/CD は API 設計の範囲外。SSOT は [../operations.md](../operations.md) / [../infrastructure.md](../infrastructure.md)) |

---

## 1. エンドポイント一覧

**本節が回答する ID: A-1, A-2, A-4, A-5, A-7** / 対応 AC: **AC-CV-2.1, AC-CV-2.5, AC-CV-2.8, AC-CV-6.3**

### 1.1 一覧

すべて認証必須 (`X-Token`)・**すべて個人スコープ**・すべて増分 1・**403 を返すものは無い**。
共通の 400 / 401 / 500 は [README.md](README.md) §2.5 に従い、本表では**固有のコードのみ**挙げる。
ID の型は [../data-model.md](../data-model.md) §3.2 の規約 (機能テーブルの PK は `bigint`) に従う。

| メソッド | パス | 概要 | 主なリクエスト / レスポンス項目 | 固有ステータス | LLM | SSE |
|---|---|---|---|---|---|---|
| POST | `/conversations` | 会話セッション作成 | B: `theme_id` (**必須**) / `title` (任意) — R: `Conversation` | **201** / **400** (`theme_id` 欠落) / **404** (テーマが他人 or 不存在) | — | — |
| GET | `/conversations` | 一覧 | Q: `theme_id` / `keyword` / `limit` / `offset` / `sort` (`updated_at:desc` 既定) — R: `{items:[ConversationSummary], total_count}` | 200 | — | — |
| GET | `/conversations/{session_id}` | 取得 (**台帳 + `stage` を返す**。切断時の回復経路①) | R: `Conversation` (+ `ledger` / `stage`) | 200 / 404 | — | — |
| PUT | `/conversations/{session_id}` | タイトル更新 | B: `title` (必須) — R: `Conversation` | 200 / 404 | — | — |
| DELETE | `/conversations/{session_id}` | 削除 (論理削除 = `deleted_at`) | — | **204** / 404 | — | — |
| POST | `/conversations/{session_id}/messages` | **会話ターンの実行 (同期 SSE)** | B: `message` (**必須**) / `selected_domains` (任意。`[{name, rationale?}]`) — R: `text/event-stream` (§5) | **ストリーム開始前**: 200 (開始) / 400 (`message` 空・ボディ上限超過) / 404 (セッションが他人 or 不存在) / **409** (**同一セッションで別のターンが実行中**) / **502** (Agent への接続自体が失敗)。**開始後の失敗は SSE の `error` イベント** ([README.md](README.md) D-API-12) | **✓** | **✓** |
| GET | `/conversations/{session_id}/messages` | 発話履歴 (切断時の回復経路②) | Q: `after_seq` (既定 0) / `limit` — R: `{items:[Message], total_count}` | 200 / 404 | — | — |

Q = クエリパラメータ / B = リクエストボディ / R = レスポンス。

- **会話の作成にテーマが必須** (AC-CV-2.5): `POST /conversations` の `theme_id` は必須パラメータで、
  欠落は 400。**PoC の暗黙テーマ作成 (`set_theme_name` / `generate_ideas` 実行時の `themes` 行の作成) は移植しない**
  (§4.1 の変更点 1)。**テーマ名の変更は既存のテーマ更新 API** (`PUT /themes/{theme_id}` — [themes.md](themes.md)) で行う
- **`scope` パラメータを持たない** (個人スコープ固定)。理由は §7 の D-CV-3
- `GET /conversations` の `keyword` の対象は **`title` と導出タイトルの元になる台帳の `theme`** (§1.4)
- ページングの既定・上限は [README.md](README.md) D-API-7 に従う (本書に値を再掲しない)
- `after_seq` は「**その値より大きい `seq` の行を古い順に返す**」。`0` は先頭から。
  1 回の応答件数は `limit` で、既定・上限は D-API-7 と同じ

### 1.2 v2 の `idea-hassans` 5 本の受け先 (AC-CV-2.8 / C-16)

v2 の発散セッション API は `hassan-v2-backend/router/router.go:143` の `/idea-hassans` グループ
(5 ルート)。テーブルは `hassan-v2-backend/db/schema.sql:119` の `idea_hassans`
(`title text` / `num_of_ideas` / `asset_ids` / `ai_role` / `industry` / `trend` / `issue` / … の発散条件列を持つ)。

| v2 | v2 の機能 | v3 の受け先 | 備考 |
|---|---|---|---|
| `POST /idea-hassans` | 発散セッションの作成 | **`POST /conversations`** | v2 は作成時に発散条件を全部渡す。v3 は**テーマだけを必須**にし、条件は会話ターンで台帳に積む |
| `GET /idea-hassans` | 発散セッション一覧 | **`GET /conversations`** | `theme_id` での絞り込みを引き継ぐ |
| `GET /idea-hassans/:id` | 発散セッション取得 | **`GET /conversations/{session_id}`** | v2 の発散条件列に相当するのは台帳の前提フィールド (§2.2 の表) |
| `PUT /idea-hassans/:hassan_id` | 発散セッションの更新 | **`PUT /conversations/{session_id}`** (タイトル) + **会話ターン** (発散条件) | **操作は 2 つに割れる**。理由は §7 の D-CV-4 |
| `DELETE /idea-hassans/:hassan_id` | 発散セッションの削除 | **`DELETE /conversations/{session_id}`** | 論理削除 (`deleted_at`)。v2 の物理/論理の別は移行計画の範囲 |

**落とした操作は無い** (C-16)。v2 の発散条件フォーム (`ai_role` / `industry` / `trend` / `issue` /
`other_condition` / `free_description` / `idea_target` / `idea_issue`) は、v3 では
**独立したフィールドではなく会話の発話と台帳の前提**になる — これは
[../llm-migration.md](../llm-migration.md) §4.2 の V-1 (アイデア生成) を会話型フローへ統合する決定の帰結であり、
本書で新たに落とす判断はしていない。

### 1.3 `Conversation` オブジェクト (暫定)

```json
{
  "id": 41,
  "theme_id": 12,
  "title": "超音波センシングの新規事業探索",
  "stage": "market",
  "message_count": 14,
  "last_turn_at": "2026-08-01T09:12:00Z",
  "created_at": "2026-07-30T04:00:00Z",
  "updated_at": "2026-08-01T09:12:00Z",
  "ledger": { "...": "§2.2 の前提フィールド + 生成物の参照。GET /conversations/{session_id} のみが返す" }
}
```

- `ConversationSummary` は上記から **`ledger` を除いたもの** (一覧で台帳を返さない — 1 行が数十 KiB になり得るため)
- **`managed_session_id` を API に出さない** (PoC は `GET /api/conversations` で返していた —
  `claude_managed_agents/cmd/devui/conversation_list.go:39`)。理由は §7 の D-CV-5
- `stage` の値域と導出は §2.3

### 1.4 `title` と表示タイトル

`conversation_sessions` に **`title text NULL`** を持つ (§8 の R-CVA-1 で
[../data-model.md](../data-model.md) へ追加を起票)。API が返す `title` は次の順で決まる:

1. `conversation_sessions.title` (ユーザーが `PUT` で設定した値)
2. 台帳の `theme`
3. 台帳の `asset_definition.asset_name`
4. 台帳の `selected_domains[0].name`
5. `「無題の対話 (YYYY-MM-DD HH:MM)」`

2〜5 は PoC の `display_title` 導出と同じ順序 (`claude_managed_agents/internal/db/conversation_store.go:213`)。
**導出結果を列に保存しない** ([../data-model.md](../data-model.md) §4.5 の「`display_title` / `stage` は列に持たない」を維持し、
ユーザーが明示的に決めた `title` だけを列にする)。

---

## 2. オーケストレーターの設計

**本節が回答する ID: A-4, A-6, O-3, O-5** / 対応 AC: **AC-CV-2.1, AC-CV-2.4, AC-CV-2.6, AC-CV-2.7, AC-CV-5.9**

### 2.1 会話ターン 1 回の処理順序

`POST /conversations/{session_id}/messages` の 1 リクエスト = 1 ターン。
**「配置」列は [../architecture.md](../architecture.md) §3.10 の配置例のステップ番号**であり、
本節はその配置を時系列に並べ直したもの (層の判断は同節が SSOT)。

| # | 処理 | 層 | §3.10 | 備考 |
|---|---|---|---|---|
| 1 | トークン検証・ロール判定 | Controller | 1 | 401 (本文なし) |
| 2 | パスパラメータ / ボディの検証 | Controller | 2 | 400 |
| 3 | 所有者スコープ (`ContractID` / `AccountID`) の確定 | UseCase | 4 | A-4 |
| 4 | セッション取得 + **`SELECT … FOR UPDATE NOWAIT`** | UseCase → `repository/conversation` | 5 | 他人 or 不存在 → **404** / ロック取得失敗 → **409** (DM-13)。**ここまでは SSE 開始前** |
| 5 | **ユーザー発話を `conversation_messages` に保存** (`role=user` / `status=complete`) | UseCase → repository (**別トランザクション・即コミット**) | — | ここで採番した `seq` が**そのターンの `turn_seq`** になる (§7 の D-CV-8) |
| 6 | SSE ヘッダ + `WriteHeader(200)` → **`session` イベント** | Controller | 3 | 以降の失敗は HTTP ステータスで表現しない (D-API-12) |
| 7 | `selected_domains` の台帳 write-through (指定時のみ) | UseCase → `repository/conversation` | 13 | 同一ターンの `generate_ideas` が読めるように**ツールループ前**に書く (PoC と同じ順序) |
| 8 | 台帳・会話履歴の読み出し | UseCase → `repository/conversation` | 6 | |
| 9 | **注入する状態ブロックの構築** | **entity/conversation** (副作用なし) | 16 | §2.2。UT 必須 |
| 10 | ツールハンドラ表の組み立て (スコープをクロージャ束縛) | UseCase (`tool_registry.go`) | 7 | **A-6 の束縛点** |
| 11 | Runner 起動 (ターン deadline を `context.WithTimeout` で設定) | Service (`conversation.Runner`) | 10 | 安全弁は §2.5 |
| 12 | Managed Agent セッションの継続 / 新規作成・`user.message` 送信 | gateway (`gateway/anthropic`) | 11 | `managed_session_id` は **DB のみ**から解決する ([../data-model.md](../data-model.md) §4.5) |
| 13 | agent 発話 → **`message_delta`** | Service | 15 | **除外リスト方式・空行も本文として通す** (BE-7) |
| 14 | `tool_use` → **`tool_start`** → ハンドラ実行 | Service → UseCase 側クロージャ | 8 / 9 | 引数の所有者検証は所有者条件付きクエリ (§4.4) |
| 15 | ツール内の LLM 呼び出し・外部検索 | gateway (`anthropic` / `exa`) | 11 / 12 | 入れ子の Agent 実行は §3.2 |
| 16 | 生成物 (アイデア / 企画書タブ) の永続化と採番 | ハンドラ → `repository/{idea,plan}` | 14 | 採番は 1 SQL に閉じる ([../data-model.md](../data-model.md) §4.11.1) |
| 17 | **台帳 write-through** | Service → `repository/conversation` | 13 | **`artifact` 送出より前**に行う (§7 の D-CV-9) |
| 18 | `conversation_tool_calls` へ 1 行 append | Service → `repository/conversation` | — | `turn_seq` = 5 で採番した値 |
| 19 | **`progress` / `artifact` / `tool_end`** の送出 | Service | 15 | 順序契約は §5.3 |
| 20 | 安全弁の判定 (ツール回数 / 累積出力トークン / 実行時間) | Service | 10 | §2.5 |
| 21 | ターン終端の判定 → `outcome` の確定 | Service → UseCase | 18 | §2.4 の表 |
| 22 | 主トランザクションの commit / rollback | UseCase | 18 | §2.4 |
| 23 | **assistant 発話を `conversation_messages` に保存** | UseCase → repository (**別トランザクション**) | — | `status` は §2.4 の写像 |
| 24 | LLM 明細 (`llm_call_records`) の記録 | UseCase → repository (**別トランザクション**) | 17 | append-only。gateway は永続化しない |
| 25 | **`turn_summary`** → **`done`** | Service / Controller | 19 | `done` が必ず末尾 |

**ステップ 5 と 23 が主トランザクションの外にある理由**は §2.4。
**ステップ 4 の 409 は SSE 開始前**なので HTTP ステータスで返せる (SSE ヘッダを書く前にロックを取る順序にしてある)。

### 2.2 毎ターン注入する状態 (AC-CV-2.6)

#### 2.2.1 渡し方の決定

**ユーザーメッセージの前置きブロックとして渡す** (system prompt のテンプレート引数にしない)。

- **理由**: Managed Agents の system prompt は **Agent リソース側に登録され、`Tools` ごと全置換される**
  (`claude_managed_agents/cmd/update-agent-prompt/main.go:215` が登録・全置換の実装。BE-9)。
  ターンごとに system prompt を差し替えるには**毎ターン Agent を更新する**ことになり、
  D-6 のハッシュ差分による再発行判定 ([../operations.md](../operations.md) §5.2) と正面から衝突する
- **却下 (a) system prompt のテンプレート引数**: 上記の通り、状態が変わるたびに Agent の再発行が必要になる
- **却下 (b) プロンプト本文に「今どの段か」を書く**: 状態の SSOT が台帳とプロンプトの 2 箇所になり、
  BE-1 (旧バージョン参照で数値が食い違う) の余地を作る。**CV-D4 が明示的に禁じている**
- **却下 (c) 注入しない (Agent が会話履歴から推論する)**: Managed Agent の session が archived になった場合や
  会話が長い場合に前提が失われ、前提不足のツール呼び出しが増える (= 構造化エラーの往復で LLM コストが増える)

#### 2.2.2 形式

ターンごとに、ユーザーの原文の**前**に次のブロックを 1 つだけ置く。値は台帳から
`entity/conversation` の**副作用のない関数**が組み立てる (ステップ 9)。

```
<conversation_state>
{"stage":"market",
 "premises":{
   "theme":"超音波センシングの新規事業",
   "asset":{"name":"超音波センシング技術","has_function_tree":true},
   "approach":"domain",
   "constraints":["3 年以内に PoC"],
   "selected_domains":[{"name":"水素インフラ保安"}],
   "researched_domains":[{"name":"水素インフラ保安","pattern":"domain"}],
   "matching":{"pair_count":8},
   "generated_ideas":{"count":12,"latest_entry_id":"…"},
   "generated_plans":{"count":1,"latest_entry_id":"…"},
   "rejected_candidates":[{"name":"…","reason":"…"}]},
 "tool_readiness":{
   "generate_ideas":{"ready":true,"missing":[]},
   "generate_plan":{"ready":false,"missing":["generated_ideas"]},
   "match_functions":{"ready":false,"missing":["asset_definition.function_tree"]}}}
</conversation_state>
```

| 決定 | 内容 |
|---|---|
| **入れるもの** | 台帳の**前提フィールドの要約** (上記) と `stage` と `tool_readiness` |
| **入れないもの** | 本文 (`deep_dive` の `notes` / `research` の `rows` / アイデア本文 / 企画書本文)。**識別子と件数だけ**を入れる |
| **理由** | 本文を入れるとターンごとの入力トークンがセッションの長さに比例して増え、O-2 のコストが会話の後半で発散する。本文が必要なツールは**ハンドラが台帳から直接読む** (CV-D13) |
| **`rejected_candidates` の件数上限** | **`config` に置く** (値を本書・プロンプト・FE に書かない。BE-2 / [../architecture.md](../architecture.md) §3.9②) |
| **`tool_readiness`** | 前提チェックの**結果**をツール単位で渡す。**ツール集合は常に全数**であり、`ready:false` のツールも Agent からは見える (CV-D4)。呼ばれた場合はハンドラが `missing` 付きの構造化エラーで拒否する (§6.4) |
| **`entry_id`** | `generated_ideas` / `generated_plans` は**最新エントリの `entry_id`** を渡す ([../data-model.md](../data-model.md) §4.11.2 の安定 ID)。`generate_plan` が「どの発散結果に対する企画書か」を取り違えない (BE-1) |

**`<conversation_state>` は Agent → FE のタグ (`<options>` / `<questions>` など) とは逆向き**であり、
**SSE には流さない** (FE には `GET /conversations/{session_id}` の `ledger` を返す。同じ事実の 2 経路を作らない)。

### 2.3 `stage` の値域・導出・表示用の畳み込み (AC-CV-2.7 / TH-Q3 / IB-Q7 の受け先)

#### 2.3.1 会話セッションの `stage` (**本書が SSOT**)

値域は **`asset` / `market` / `match` / `ideation` / `plan_draft`** の 5 値。
`entity/conversation` の**副作用のない関数** `DeriveStage(ledger) Stage` が台帳から導出し、**列に持たない**。
判定順序は PoC と同じ (`claude_managed_agents/internal/db/conversation_store.go:250`):

| 順 | 条件 | 値 |
|---|---|---|
| 1 | `generated_plans` が非空 | `plan_draft` |
| 2 | `generated_ideas` が非空 | `ideation` |
| 3 | `matching.pairs` が非空 | `match` |
| 4 | `selected_domains` または `researched_domains` が非空 | `market` |
| 5 | 上記以外 (初期値) | `asset` |

**`deep_dive_results` は判定に使わない** (PoC と同じ。深掘りは段の進行ではなく裏付けの追加であり、
使うと「深掘りしたら段が進んだ」という誤った表示になる)。

#### 2.3.2 表示用の畳み込み (他ドメインが使う場合)

| 参照元 | 何を表示したいか | 決定 |
|---|---|---|
| **アイデアボード** ([idea-boards.md](idea-boards.md) の **IB-Q7** = `items[].stage`) | アイデア 1 件の進行状況 (発散 / 企画作成) | **会話の `stage` を配らない**。`entity/idea` の関数で**アイデア自身の事実**から導く: `plans` 行が存在すれば `plan`、無ければ `diverged` |
| **テーマ** ([themes.md](themes.md) の **TH-Q3** / D-TH-4) | — | **テーマ API は `stage` を返さない** (D-TH-4 で確定済み)。再導入が必要になった場合も**会話の `stage` の最大値ではなく、上記アイデア単位の集計**を使う |

**理由**: 1 つの会話は複数のアイデアを生み、企画書は**その一部にしか作られない**。
会話の `stage` をアイデアに配ると、企画書の無いアイデアまで「企画作成」と表示される。
**却下 (a) 会話の `stage` をそのままアイデア・テーマに配る**: 上記の誤表示が起きる。
**却下 (b) アイデアに `stage` 列を持たせる**: `plans` の有無と二重管理になり、どちらが正か決まらない
(D-TH-4 が同じ理由でテーマの `stage` 列を却下している)。

### 2.4 トランザクション境界と中断時の保存 (AC-CV-2.4)

**ターン全体で 1 トランザクション**を既定とする ([../architecture.md](../architecture.md) §3.10 の「迷いやすい 4 点」3)。
このトランザクションが持つのは **台帳・`conversation_tool_calls`・生成物 (アイデア / 企画書タブ)** で、
`FOR UPDATE NOWAIT` のロックもこの中に入る。

**`conversation_messages` への書き込みは、常に主トランザクションの外**で行う。

| `outcome` | 主トランザクション | `conversation_messages.status` | 理由 |
|---|---|---|---|
| `completed` | **commit** | `complete` | 正常終了 |
| `tool_limit` / `token_limit` / `timeout` | **commit** | `aborted` | **打ち切りは正常終了** ([../observability.md](../observability.md) §4.4)。それまでのツール結果・生成物は確定させる |
| `failed` | **rollback** | `failed` | LLM 呼び出し失敗・DB エラー。中途半端な台帳を残さない |
| クライアント切断 (`ctx` キャンセル) | **rollback** | `aborted` | ユーザーは結果を受け取っていない。**部分状態を次ターンの前提にしない** |

- **ユーザー発話 (ステップ 5) も別トランザクションで即コミットする**。
  **却下**: 主トランザクション内で書く — `failed` / 切断で **rollback すると質問ごと履歴から消える**。
  「さっき何を聞いたか」が残らない状態は O-4 とユーザー体験の両方を損なう
- **assistant 発話 (ステップ 23) も別トランザクション**で、**その時点までに `message_delta` で流した本文**を保存する。
  ロールバックされない経路であることが CV-D7 の要求
- **1 メッセージ = 1 行**。デルタごとの追記をしない (`conversation_messages` は
  [../data-model.md](../data-model.md) §3.4 で「最も行数が伸びるテーブル」に分類されている)
- `seq` の採番は `COALESCE(MAX(seq),0)+1` を **1 SQL** で行う (同 §4.11.1。BE-11)。
  **別トランザクションであっても採番規則は変わらない**
- **`status` の値域は `complete` / `aborted` / `failed` で確定**する
  ([../data-model.md](../data-model.md) §8.4 の仮定 4 をクローズ → §8 の R-CVA-4)

### 2.5 安全弁の適用点 (AC-CV-5.9 / O-3)

**しきい値の数値は [../observability.md](../observability.md) §4.4 が SSOT**。本書に再掲しない (DR-9)。
本書が確定させるのは**どこで測り、発火したら何が起きるか**である。

| 安全弁 | 測る場所 | 発火時 |
|---|---|---|
| ツール呼び出し回数 / ターン | Runner の dispatch **直前**にカウント (§2.1 のステップ 14) | ループを止め `outcome=tool_limit` |
| 累積出力トークン | gateway が返す `CallMeta` を Runner が加算 ([../architecture.md](../architecture.md) §3.8.3) | `outcome=token_limit` |
| 1 ターンの実行時間 | ターン開始時 (ステップ 11) の `context.WithTimeout` | `outcome=timeout` |
| SSE keep-alive | Controller が SSE コメントを送出 (**イベントではない**) | 打ち切りではない |

- 発火は **`error` イベントではなく `turn_summary.outcome`** で表す (AC-CV-2.3④)。
  `error` を出すと FE が異常として扱い、確定済みの生成物を捨てる実装を誘発する
- 発火時も **`turn_summary` → `done` の順序契約は変わらない** (§5.3)
- **入れ子の Agent 実行 (P-2 / P-4) は外側のターンの `context` を継承し、独自の deadline を持たない** (§3.2)。
  ツール呼び出し回数は**外側のターンだけ**数える (内側の Agent が内部で行うツール実行は別勘定にしない —
  内側の上限はそれぞれの Agent 実装が持つ)
- **課金上限による拒否は設けない** (C-12)

---

## 3. Agent 構成

**本節が回答する ID: O-2, D-6** / 対応 AC: **AC-CV-5.7, AC-CV-5.8**

### 3.1 Managed Agent は 3 本 (責務境界)

[../llm-migration.md](../llm-migration.md) §4.1 / §6.3 で確定済み。本書は**呼び出し関係**を確定させる。

| Agent | 対応 | 責務 | 呼び出し元 | 使うプロンプト |
|---|---|---|---|---|
| **P-1 orchestrator** | `ORCHESTRATOR_AGENT_ID` 相当 | ユーザーとの対話・custom tool の呼び出し判断。**P-3 (発散後チャット) を節として統合** | `service/conversation.Runner` (会話ターンの本体) | `prompts/conversation/orchestrator.md` |
| **P-2 diverge** | `DIVERGE_AGENT_ID` 相当 | アイデア発散 (domain / trend / usage / spec の 4 軸)。**v2 の V-1 / V-3 を吸収** | **`generate_ideas` の custom tool ハンドラ** | `prompts/idea/diverge.md` |
| **P-4 plan tab** | `PLAN_AGENT_ID` 相当 | 企画書タブの生成。**8 タブすべてを Agent 経路に統一**。**v2 の V-6 を吸収** | **`generate_plan` の custom tool ハンドラ** / **[plans.md](plans.md) のタブ再生成 REST** | `prompts/plan/tab.md` |

**`CHAT_AGENT_ID` 相当は発行しない** (LM-Q1 の統合結果)。`prompts/conversation/post_diverge_chat.md` も作らない
([../llm-migration.md](../llm-migration.md) §6.1)。

### 3.2 Managed Agent ではない LLM 経路 (直接 API)

**custom tool の中から呼ばれる LLM は、Managed Agent とは限らない**。取り違えると D-6 の再発行対象を誤る。

| 経路 | 実装形態 | どこから | プロンプト |
|---|---|---|---|
| P-5 アイデア評価 | **直接 API** | [ideas.md](ideas.md) の評価 REST (**tool にしない** — §4.2) | `prompts/idea/evaluate.md` |
| P-6 深掘り 6 パターン | **直接 API** | `deep_dive` ハンドラ | `prompts/conversation/deepdive_*.md` |
| P-7 機能 × 市場のスコアリング | **直接 API** | `match_functions` ハンドラ | `prompts/conversation/match_functions.md` |
| P-8 市場調査の候補領域抽出 | **直接 API + `gateway/exa`** | `research_market` ハンドラ | `prompts/conversation/research_market.md` |

**入れ子実行の扱い** (P-1 のハンドラから P-2 / P-4 の Managed Agent を起動する形):

| # | 決定 |
|---|---|
| 1 | 内側の Agent 実行は**外側のターンの `context` を継承**する。独自の deadline を持たない (§2.5) |
| 2 | 内側の LLM 呼び出しも **`gateway/anthropic` の単一関門**を通る。`feature` は §3.3 の表で分ける |
| 3 | **`turn_summary.tool_calls` は外側のツール呼び出し回数**であり、内側の Agent の内部ツール実行を含まない |
| 4 | 内側が失敗した場合は**構造化エラーとしてハンドラが Agent に返す** (`tool_end.ok=false`)。ターンは `failed` にしない — 外側の Agent が別の手順を選べる |

### 3.3 `feature` 値 (O-2 / AC-CV-5.7)

`feature` は **`entity/` の const 群 1 ファイルに列挙**し、リテラルの直書きを禁止する
([../observability.md](../observability.md) §4.2)。**個別ツールに計測コードを書かない** (CV-DF3) —
計測値は `gateway` が `CallMeta` として返し、ターン集計は Runner が持つ。

| `feature` | 経路 | `route_kind` |
|---|---|---|
| `conversation.turn` | P-1 のターン実行 | `managed_agent` |
| `idea.diverge` | `generate_ideas` → P-2 | `managed_agent` |
| `plan.generate` | `generate_plan` → P-4 / **[plans.md](plans.md) のタブ再生成 REST** (**同じ値**) | `managed_agent` |
| `idea.evaluate` | P-5 (評価) | `direct_api` |
| `conversation.deepdive` | `deep_dive` → P-6 | `direct_api` |
| `conversation.match` | `match_functions` → P-7 | `direct_api` |
| `conversation.research` | `research_market` → P-8 (LLM 抽出) | `direct_api` |
| `conversation.research` | 同ツール内の Exa 検索 | **`external_search`** (同じ `feature` で `route_kind` が違う) |

**`plan.generate` が会話経路と REST 経路で共通である**ことにより、計測 (O-2) と安全弁の適用が入口によって変わらない
(CV-D10)。**この const 群は [../testing.md](../testing.md) の LLM 経路テストの対象集合になる**ため、
値を増やしたら同じ PR で const を足す (§8 の R-CVA-5)。

### 3.4 D-6 (Agent のライフサイクル) への回答 (AC-CV-5.8)

| # | 決定 |
|---|---|
| 1 | **再発行対象は §3.1 の 3 本**。手順・ハッシュ差分判定・ロールバックの SSOT は [../operations.md](../operations.md) §5.2 / §5.3 |
| 2 | **ツールの追加は後方互換**。新ツールを含む Agent version を発行してからハンドラを配線しても、旧 version は呼ばない。**先にハンドラをデプロイし、次に Agent を発行する** |
| 3 | **ツールの削除は 2 段階**。①Agent 定義から外して再発行 ②**次のリリースで**ハンドラを削除する。逆順にすると、旧 Agent が呼んだツールが「未対応のツール」で黙って失敗する |
| 4 | **`set_theme_name` の廃止は 3 の手順で行う** (§4.2)。第 1 リリースは v3 の新規発行なので、初回発行時点で既に含まれない |
| 5 | `prompts/agents.yaml` の列挙が実体の SSOT。**§3.1 の 3 本と一致すること**を `scripts/check-tool-contract.sh` が検査する ([../llm-migration.md](../llm-migration.md) §6.3) |

---

## 4. custom tool の一覧と契約

**本節が回答する ID: A-6, D-6, O-4** / 対応 AC: **AC-CV-5.1, AC-CV-5.2, AC-CV-5.3, AC-CV-5.4, AC-CV-5.5**

### 4.1 採用する tool (PoC 9 本 → v3 8 本)

**判定基準 (CV-D5)**: 「**LLM が呼び出しを決める必要があるか**」。
ユーザー操作で起動が決まるものは REST にし、tool にしない。

`set_theme_name` を廃止したため **PoC の 9 本 (`claude_managed_agents/cmd/update-agent-prompt/main.go:280` の
`conversationToolDefs()`) から 1 本減って 8 本**になる。

| tool | 目的 | 引数 (schema。**すべて Agent が値を決める**) | 出力 (`entity/toolresult`) | 前提 (不足時は `missing` 付き構造化エラー) | `artifact` | LLM |
|---|---|---|---|---|---|---|
| `list_assets` | 登録済みアセットの一覧 | (なし) | `AssetList` | なし | — | — |
| `load_asset` | アセット 1 件の詳細 + 機能ツリー | `asset_id`: integer (**必須**) | `AssetDetail` | なし | `asset` | — |
| `research_market` | 候補領域 / トレンドの抽出 | `query`: string (**必須**) / `pattern`: enum(`domain`,`trend`) (**必須**) / `industry_mode`: enum(`cross_industry`,`balanced`,`intra_industry_novel`) | `Research` | なし | `research` | ✓ (P-8 + Exa) |
| `deep_dive` | 6 パターンの裏付け検証 | `pattern`: enum(`credibility`,`competition`,`momentum`,`demand`,`counterevidence`,`problem_structure`) (**必須**) / `target`: string (**必須**) | `DeepDive` | なし | `deepdive` | ✓ (P-6) |
| `match_functions` | 機能 × 領域のスコアリング | `domains`: string[] / `focus`: string | `Matching` | `asset_definition.function_tree` と (`selected_domains` または `researched_domains`) | `matching` | ✓ (P-7) |
| `generate_ideas` | アイデア発散 | `theme`: string (**必須**) / `asset_name` / `asset_summary` / `focus` / `seed_idea`: string / `domains`: string[] / `constraints`: string[] / `approach`: enum(`domain`,`trend`,`usage`,`spec`) | `GeneratedIdeas` | `theme` と (`asset_definition` または `selected_domains` または `researched_domains` または `seed_idea`) | `ideas` | ✓ (P-2) |
| `generate_plan` | 企画書 8 タブの生成 | `idea_id`: integer | `GeneratedPlan` | `generated_ideas` が非空 | `plan` | ✓ (P-4) |
| `record_rejection` | 見送り候補の記録 | `name`: string (**必須**) / `reason`: string (**必須**) / `sources`: string[] | `Rejection` | なし | — | — |

**PoC からの変更点と理由**:

| # | 変更 | 理由 |
|---|---|---|
| 1 | **`set_theme_name` を廃止** | CV-D8 でテーマ必須になり、会話開始時点で `theme_id` が確定している。テーマ名の変更は `PUT /themes/{theme_id}` ([themes.md](themes.md)) で行う。**PoC の暗黙テーマ作成 (「対話生成: <本体>」) は移植しない** |
| 2 | **`deep_dive` から `asset_context` を落とす** | PoC は schema にもプロンプトにも無い引数をサーバが注入していた (`claude_managed_agents/cmd/devui/conversation_tools_deepdive.go:197` が `asset_context` をパースする一方、schema は `pattern` / `target` のみ)。**v3 はハンドラが台帳の `asset_definition` を直接読む** (CV-D13)。これにより 3 者一致検査が常に成立する |
| 3 | **`generate_plan` の `idea_num` (表示番号) を `idea_id` に変える** | 表示番号はアイデアの追加・削除で意味がずれる ([../data-model.md](../data-model.md) §4.6 が同じ理由で PoC の文字列キーを却下している)。`artifact(ideas)` の payload が `idea_id` を持つので Agent は値を知っている |
| 4 | **`generate_ideas` に `seed_idea` を追加** | v2 の V-3 (マイアイデア補完) を**新ツールを作らず引数で吸収**する (CV-D5)。**却下 (a) PoC 踏襲 (`<idea_input>` タグのみ)**: 原文がツール引数にも台帳にも残らず、発散のやり直しで同じ入力を再現できない (BE-1)。**却下 (b) 新ツール `diverge_from_my_idea`**: D-6 の再発行対象・3 者一致検査・A-6 の検証点が 1 本増える |
| 5 | **`record_rejection` の読み手を実装する** | PoC は台帳コピー以外に読み手が無かった (BE-10。`claude_managed_agents/cmd/devui/conversation_ledger.go:297` が書き手、読み手は `copyLedgerPremise` のみ)。**v3 は §2.2 の注入ブロックと `generate_ideas` の発散入力の 2 箇所で読む** (§4.5) |

**`focus` / `seed_idea` / `constraints` の台帳保存**: PoC は `focus` を台帳に保存しない設計だった。
v3 は **`seed_idea` を台帳に保存する** (やり直しで再現するため) が、`focus` は保存しない (1 回の絞り込み指示であり、
次ターンに引き継ぐと BE-1 の温床になる)。**台帳フィールドの追加は §8 の R-CVA-2 で起票**する。

**持ち込みアイデアには 2 つの経路がある (2026-08-02 追加。[ideas.md](ideas.md) §8 の R-IDA-3)**:
v2 は「マイアイデアの登録・生成」(`POST /ideas/generate/my-idea`) と
**「下書き生成」(`POST /ideas/generate/my-idea/draft`)** の 2 本を持っており、
**後者は発散せず、持ち込んだ断片から本文だけを補完して返す** (保存もしない)。
`generate_ideas` の `seed_idea` は**前者 (種にして発散する)** しか表せないため、
**`prompts/conversation/orchestrator.md` に「補完だけを行うモード」の節を持たせる**:

| ユーザーの意図 | Agent の振る舞い | 生成物 |
|---|---|---|
| 「このアイデアを広げたい」 | `generate_ideas` を `seed_idea` 付きで呼ぶ | 複数のアイデア (`ideas` テーブルに保存) |
| **「このアイデアの中身を埋めたい」** | **ツールを呼ばず、`message_delta` で補完した本文を返す** | **保存しない** — ユーザーが内容を確認してから `POST /ideas` ([ideas.md](ideas.md) §1) で登録する |

**却下**: 補完専用の custom tool を足す — **LLM が呼び出しを決める必要がない**
(ユーザーの依頼文がそのまま入力で、出力は本文テキストのみ) ため CV-Q5=A の足切り基準に掛かる。
**ツールを増やすと D-6 の再発行対象と 3 者一致検査の対象が増える**。
**この節が無いと**、C-16 の対応表 ([ideas.md](ideas.md) §3.1) は埋まっているのに
**実装がどこにも生まれない**状態になる。

### 4.2 tool にしなかった操作の REST 対応 (AC-CV-5.1③)

| 操作 | 起動を決めるのは | v3 の受け先 | 担当文書 |
|---|---|---|---|
| アイデアのタグ編集 | ユーザー | `PUT /ideas/{idea_id}` | **[ideas.md](ideas.md)** |
| アイデアの本文編集 / 削除 / 手動登録 | ユーザー | `PUT` / `DELETE /ideas/{idea_id}` / `POST /ideas` | **[ideas.md](ideas.md)** |
| アイデアのスター評価 | ユーザー | `PUT /ideas/{idea_id}/star` | [idea-boards.md](idea-boards.md) §7 → **[ideas.md](ideas.md)** へ移設 |
| **アイデアの再評価** | ユーザー | REST (パスは [ideas.md](ideas.md) §1)。**tool にしない** — 判定と理由は下記 | **[ideas.md](ideas.md)** |
| アイデアの版一覧・復元 | ユーザー | `GET /ideas/{idea_id}/versions` + 復元操作 | **[ideas.md](ideas.md)** |
| 企画書タブの再生成 | ユーザー | `POST /plans/{plan_id}/tabs/{tab_id}/regenerate` (SSE) | **[plans.md](plans.md)** |
| 企画書タブの版一覧・復元 | ユーザー | `GET /plans/{plan_id}/tabs/{tab_id}/versions` + 復元操作 | **[plans.md](plans.md)** |
| 持ち込み PDF のアップロード | ユーザー | `POST /asset-extractions` → `POST /assets` (**既存②の経路**) | [assets.md](assets.md) (§4.3) |
| テーマ名の設定・変更 | ユーザー | `PUT /themes/{theme_id}` | [themes.md](themes.md) |

**アイデア再評価を tool にしない判定** (AC-CV-3.5 のうち tool 側の結論):

- 発散結果には既に `score` / `grade` が入っている (`artifact(ideas)` の payload)。
  **ターンの途中で LLM が「今 1 件を評価すべきか」を判断する場面が無い**
- **却下**: `evaluate_idea` tool を足す — CV-D5 の基準 (LLM が呼び出しを決める必要があるか) を満たさず、
  D-6 の再発行対象・3 者一致検査・A-6 の越境検証点が 1 本ずつ増える
- REST のパス・入出力・v2 の V-2 との評価軸統合は **[ideas.md](ideas.md)** が確定させる

### 4.3 持ち込み PDF の扱い (AC-CV-5.5 / CV-D12 / AS-Q11)

| # | 決定 |
|---|---|
| 1 | **会話専用のアップロードエンドポイントを作らない**。既存②「抽出用の未紐付けアップロード」= `POST /asset-extractions` を使う ([assets.md](assets.md) の D-AS-4 が前提にする「3 系統」を維持する) |
| 2 | **ターン内で抽出の完了を待たない**。抽出は非同期ジョブ ([README.md](README.md) §1.3) で、完了後にユーザーが `POST /assets` で確定させ、**次のターンから `list_assets` / `load_asset` で参照できる**ようになる |
| 3 | **未確定の抽出結果を会話から直接読む経路を作らない**。会話が参照するのは**アセットとして確定した行**だけ |
| 4 | 会話から参照する際の所有者スコープ検証は**ハンドラのクロージャ**で行う (§4.4)。`load_asset` の `asset_id` は所有者条件付きクエリの入力になる |

**却下 (a) `load_extraction` tool を新設**: CV-D5 の基準に反し、A-6 の越境検証点が増える。
**却下 (b) ターン内で抽出完了を待つ**: ターンの実行時間上限 ([../observability.md](../observability.md) §4.4) を
抽出の待ちに使うことになり、抽出が遅いと会話全体が `timeout` で打ち切られる。
**却下 (c) 確定前の抽出結果を読む**: レビュー前の抽出結果が発散の前提に入り、
後でユーザーが修正しても発散結果は追随しない (BE-4 と同型の stale)。

### 4.4 A-6 (LLM のテナント越境) への回答 (AC-CV-5.3)

**強制点の SSOT は [../architecture.md](../architecture.md) §3.8.2** (束縛 = `usecase/conversation/tool_registry.go` の 1 箇所)。
本書は**会話ドメインでの適用**を確定させる。

| # | 決定 |
|---|---|
| ① | **LLM が渡す ID (`asset_id` / `idea_id`) はすべて「所有者条件付きクエリの入力」として扱う**。ハンドラは `WHERE account_id = <クロージャ束縛値>` を必ず含むクエリにしか渡さない |
| ② | **存在確認を所有権の検証に使わない** (A-4)。「行が nil でない」で通すコードを書かない。0 件かどうかは**所有者条件込みのクエリの結果**で判定する |
| ③ | **該当なしの応答は「見つからない」で統一**する。「他の契約のアセットです」「権限がありません」のように**他人のリソースの存在を推測させる文言を返さない** ([../auth.md](../auth.md) §6.5) |
| ④ | **所有者不一致を warn ログ + メトリクスに出す** (ツール名・件数・`request_id`)。無言にすると「スコープの渡し忘れ (実装バグ)」と「越境の試行」が両方とも検知できない |

**ツール別の適用点**:

| tool | LLM 由来の ID | スコープを効かせる場所 |
|---|---|---|
| `list_assets` | なし | クエリが常に `account_id` で絞る (一覧なので ID を受け取らない) |
| `load_asset` | `asset_id` | `repository/asset` の所有者条件付き単一取得 |
| `generate_plan` | `idea_id` | `repository/idea` の所有者条件付き単一取得。**さらにそのアイデアが当該会話のテーマ配下であること**を UseCase が確認する |
| `generate_ideas` / `match_functions` / `deep_dive` / `research_market` / `record_rejection` | なし (文字列引数のみ) | 台帳の読み書きは**当該セッションに束縛**され、セッション自体が §2.1 のステップ 4 で所有者検証済み |

**`generate_plan` にテーマ配下チェックを足す理由**: 所有者条件だけだと「自分の別テーマのアイデア」に対して
企画書を作れてしまい、`plans.theme_id` と会話の `theme_id` が食い違う。
**却下**: 所有者条件のみ — 上記の不整合が黙って発生する。

### 4.5 台帳フィールドの書き手と読み手 (AC-CV-5.4 / BE-10)

**フィールド一覧と v3 で持つか持たないかの SSOT は [../data-model.md](../data-model.md) §4.11.2**。
本書は**会話ドメインでの書き手・読み手の対応**を確定させる (片方だけのフィールドを作らない)。

| 台帳フィールド | 書き手 (契機) | 読み手 (本書で確定) |
|---|---|---|
| `theme` | `generate_ideas` の引数マージ | §2.2 の注入 / 発散入力 / §1.4 の表示タイトル |
| `asset_definition` (+ `function_tree`) | `load_asset` 成功時 | `deep_dive` ハンドラの文脈構築 (**引数注入をやめた分の受け皿**) / `match_functions` の機能列 / §2.2 の注入 |
| `approach` / `constraints` | `generate_ideas` の引数 | 発散 pattern の解決 / 発散入力 / §2.2 の注入 |
| **`seed_idea`** (新規) | `generate_ideas` の引数 | 発散入力 / §2.2 の注入 (**§8 の R-CVA-2 で data-model へ起票**) |
| `selected_domains` (+ `rationale`) | ①`POST .../messages` の `selected_domains` ②`generate_ideas` の `domains` 引数 | `match_functions` / 発散入力 / §2.3 の `stage` 導出 / §2.2 の注入。**②の経路で `rationale` を消さない** (PoC の欠陥) |
| `researched_domains` | `research_market` 成功時 (append) | 発散入力 / `match_functions` のフォールバック / `stage` 導出 / `GET /conversations/{id}` の FE 表示 |
| `deep_dive_results` | `deep_dive` 成功時 (append) | `generate_plan` の grounding 還流 (**`entity/toolresult` の同じ型から読む** — BE-12) |
| `generated_ideas` / `generated_plans` | 生成成功時 (append) | 最新エントリの解決 / `stage` 導出 / §2.2 の注入 (`entry_id` と件数のみ) |
| **`rejected_candidates`** | `record_rejection` 成功時 (append) | **①§2.2 の注入ブロック ②`generate_ideas` の発散入力の「既に見送った候補」ブロック** — **どちらも第 1 リリースで実装する** (BE-10 のクローズ) |
| `matching` | `match_functions` 成功時 (全置換) | `stage` 導出 / 発散入力 / §2.2 の注入 |

### 4.6 3 者一致検査が照合するもの (AC-CV-5.2)

`scripts/check-tool-contract.sh` ([../architecture.md](../architecture.md) §3.8.4 の検査 3〜5) と
起動時チェック (同 検査 1〜2) の**入力になるのが §4.1 の表**である。

| 検査 | 照合対象 | 本書が与える期待値 |
|---|---|---|
| 起動時 1・2 | schema の tool 名集合 ↔ ハンドラ表のキー集合 | §4.1 の 8 行の `tool` 列 |
| CI 3 | schema の引数名 ↔ ハンドラのパースキー ↔ `prompts/conversation/orchestrator.md` の記載 | §4.1 の「引数」列 |
| CI 4 | ハンドラの戻り値が `entity/toolresult` の型か | §4.1 の「出力」列 |
| CI 5 | 読み手が参照するフィールド ↔ 書き手の型 | §4.5 の「読み手」列 |
| operations §5.2 | `prompts/agents.yaml` の列挙 ↔ 発行コマンドが送る集合 | §3.1 の 3 本 |

**CV-D13 (サーバ注入の廃止) により、検査 3 の不一致が原理的に発生しない**:
「schema にあってハンドラが読まない引数」も「ハンドラが読んで schema に無い引数」も、
**引数の集合が 1 つしかない**ため作れない。PoC の `asset_context` (`claude_managed_agents/cmd/devui/conversation_tools_deepdive.go:197`)
がまさに後者で、**Agent が値を決められない引数を handler が読む**状態だった。

---

## 5. SSE イベント型

**本節が回答する ID: O-4, O-5** / 対応 AC: **AC-CV-2.2, AC-CV-2.3**

### 5.1 イベント一覧 (**本節が値域の SSOT**)

**OpenAPI の `components/schemas` に `event` フィールドをディスクリミネータとする discriminated union として置く**
(D-API-12 / [../frontend.md](../frontend.md) §6.2 の S-8)。FE は orval の生成型で受け、
**手書きの型を作らない**。**未知イベントは捨てずに上位へ渡す** (同 S-6) を維持する。

| event | payload | 送出契機 |
|---|---|---|
| `session` | `{session_id: integer, turn_seq: integer}` | ターン先頭に必ず 1 回 |
| `message_delta` | `{text: string}` | agent 発話。行末の `\n` を保持し、**空行も本文として通す** (BE-7) |
| `tool_start` | `{tool: string, label: string}` | ツール dispatch の直前 |
| `tool_end` | `{tool: string, ok: boolean, elapsed_ms: integer, error_code?: string}` | ツール完了直後。`ok=false` のとき `error_code` に `CodedError` のコードを載せる (O-4) |
| `progress` | `{scope: "ideas"\|"plan", step: integer, total: integer, label: string, detail?: string}` | 生成ツールの進捗。**`generate_progress` / `plan_progress` を 1 種に統合** |
| `artifact` | `{kind: "ideas"\|"plan"\|"matching"\|"research"\|"deepdive"\|"asset", payload: object}` | ツール成功時。**全 kind で `{kind, payload}` の単一形** |
| `turn_summary` | `{outcome: "completed"\|"tool_limit"\|"token_limit"\|"timeout"\|"failed", tool_calls: integer, elapsed_ms: integer, message_seq?: integer}` | **`done` の直前に必ず 1 回**。**`message_seq` は任意** (§5.3.1) |
| `error` | `{code: string, message: string, request_id: string}` | ストリーム開始後の失敗。1 ターンに最大 1 回 |
| `done` | `{}` | 常に最後に 1 回 |

- keep-alive は **SSE コメント** (`: keepalive`) でありイベントではない。間隔は
  [../observability.md](../observability.md) §4.4 (本書に値を再掲しない)
- `turn_summary.message_seq` は**そのターンで保存した assistant メッセージの `seq`**。
  FE は切断後に `GET /conversations/{session_id}/messages?after_seq=` でここまでを取り直せる。
  **任意フィールドである** (2026-08-02。[plans.md](plans.md) §12 の R-PL-5) — 本書のイベント型は
  **会話ターン以外の SSE 経路 (企画書のタブ生成・再生成) でも使う**が、それらには会話メッセージが無く
  `message_seq` に入れる値が存在しないため。**会話ターン経路では必ず入れる**
- `error.message` は**表示可能な文言**であり、**プロバイダのエラー文言を素通ししない** (§6.2)

### 5.2 `artifact` の kind 別 payload

| kind | payload | PoC からの変更 |
|---|---|---|
| `ideas` | `{session_id, theme_id, generated_at, count, ideas:[{idea_id, num, title, summary, score, grade, pattern?, competition_density?, competitors?}], note?}` | 変更なし |
| `plan` | `{plan_id, idea_id, idea_title, generated_at, tabs:[{tab_id, ver_no, label}]}` | **タブ本文を SSE に載せない** (§7 の D-CV-11) |
| `matching` | `{pairs:[{rank, function_name, domain_name, score, rationale?}]}` | 変更なし |
| `research` | `{pattern, title, rows:[{name, summary, source_urls:[{url,title,kind?}], confidence?, hype_warning?, market_size?, cagr?, social_issue?, customer_pain?}]}` | **`pattern` を payload の中へ**移す (PoC は payload の sibling) |
| `deepdive` | `{title, pattern, target, confidence, notes:[string], source_urls:[{url,title,kind?}], details?}` | 変更なし。**型は `entity/toolresult` の 1 宣言から読む** (BE-12) |
| `asset` | `{asset_id, name, summary, function_tree:[…]}` | **`payload` ラッパを持つ形に揃える** (PoC は `{kind, name, function_tree}` の直置き — `claude_managed_agents/cmd/devui/conversation.go:705`) |

`function_tree` が空のときは **`null` ではなく空配列**を返す (FE の分岐を増やさない。PoC と同じ扱い)。

### 5.3 順序契約

```
session                                  ← 1 回・先頭
  ( message_delta
  | tool_start → progress* → artifact? → tool_end )*
  error?                                 ← 最大 1 回
turn_summary                             ← 1 回
done                                     ← 1 回・末尾
```

| # | 契約 |
|---|---|
| 1 | `session` が先頭・`done` が末尾。**異常時も必ずこの 2 つが出る** |
| 2 | `turn_summary` は **`done` の直前に必ず 1 回**。`error` が出た場合も出る (`outcome=failed`) |
| 3 | `progress.step` はスコープ内で昇順。`total` はスコープごとの固定値 (`ideas` / `plan` の値は `entity/` の定数が SSOT。§9 の CV-R2) |
| 4 | `artifact` は**ツール成功時のみ**。`tool_end.ok=false` のときは出さない |
| 5 | **打ち切り (`tool_limit` / `token_limit` / `timeout`) は `error` を出さない**。`turn_summary.outcome` だけで表す |
| 6 | 台帳・生成物の書き込みは `artifact` 送出**より前**に完了している (§2.1 のステップ 17→19) |

#### 5.3.1 本書のイベント型を使う経路 (2026-08-02 追加)

**§5 のイベント型は会話ターン専用ではない** — 企画書ドメインの SSE 経路も同じ型を使う
([plans.md](plans.md) §1。起票元は同 §12 の R-PL-5)。**型を経路ごとに分岐させない**ことで、
FE の `lib/sse/decode-event.ts` が 1 つの discriminated union で全経路を扱える。

| 経路 | 使うイベント | 使わないイベント | `turn_summary.message_seq` |
|---|---|---|---|
| **会話ターン** (`POST /conversations/{session_id}/messages`) | 全種 | — | **必ず入れる** |
| **企画書のタブ生成 / 再生成** (`POST /plans/{plan_id}/generate` / `.../tabs/{tab_id}/regenerate`) | `session` / `progress` / `artifact` / `error` / `turn_summary` / `done` | `message_delta` / `tool_start` / `tool_end` (**ツールループを持たない**) | **入れない** (会話メッセージが無い) |
| **企画書チャット** (`POST /plans/{plan_id}/chat/messages`) | `session` / `message_delta` / `error` / `turn_summary` / `done` | `progress` / `artifact` / `tool_start` / `tool_end` (**ツールを持たない chat**) | **入れない** (`plan_chat_messages.seq` は別系列であり、会話の `seq` と混同させない) |

**§5.3 の順序契約 1・2・5 は全経路に適用する** (`session` 先頭 / `done` 末尾 / `turn_summary` は `done` の直前 /
打ち切りは `error` を出さない)。**契約 3・4・6 はイベントを出す経路にのみ適用する**。

### 5.4 PoC → v3 の対応表 (移植時の突き合わせ用)

PoC の 9 種の出典は [../../analysis/poc-conversation-flow.md](../../analysis/poc-conversation-flow.md) §1.2。

| PoC の event | v3 | 変更内容 |
|---|---|---|
| `session` (`{id}`) | `session` | payload を `{session_id, turn_seq}` に。**`managed_session_id` は出さない** (PoC も出していない) |
| `message_delta` | `message_delta` | 変更なし |
| `tool_start` | `tool_start` | 変更なし |
| `tool_end` | `tool_end` | `error_code` を追加 (O-4) |
| `generate_progress` (`total`=5) | **`progress` (`scope="ideas"`)** | 統合 |
| `plan_progress` (`total`=8。`tab_id`/`label` が空文字になる中継あり) | **`progress` (`scope="plan"`)** | 統合。**空文字のフィールドを送らない** (`detail` は値があるときだけ) |
| `artifact` (kind ごとに形が違う) | `artifact` | **単一形 `{kind, payload}` に統一**。`asset` のラッパ欠落と `research.pattern` の sibling を解消 |
| `error` (`{message}` = `runErr.Error()` の素通し) | `error` | **`{code, message, request_id}` の `CodedError` 形**に変更 |
| `done` (`{elapsed_sec}`) | `done` (`{}`) + **`turn_summary` を新設** | 経過時間は `turn_summary.elapsed_ms` の 1 箇所に置く |
| (無し) | **`turn_summary`** | 新設 |
| `: keepalive` コメント | 同じ | イベントではない |

---

## 6. エラーと失敗の扱い

**本節が回答する ID: A-5, O-4, O-6 (参照)** / 対応 AC: **AC-CV-5.6, AC-CV-2.3**

### 6.1 ストリーム開始前 (HTTP ステータスで表現する)

判定規則の SSOT は [../auth.md](../auth.md) §6.6、類型別の適用は [README.md](README.md) §2.5。

| 事象 | コード | 本文 |
|---|---|---|
| `X-Token` 欠落・不正・期限切れ | **401** | なし |
| `message` が空 / ボディ上限超過 / `theme_id` 欠落 | **400** | `CodedError` |
| セッション or テーマが**他人 or 不存在** | **404** | `CodedError` (**403 にしない**) |
| **同一セッションで別のターンが実行中** | **409** | `CodedError` (`ConversationTurnInProgress` 相当。DM-13 の `FOR UPDATE NOWAIT` に対応) |
| Agent への接続自体が失敗 (SSE ヘッダを書く前) | **502** | `CodedError` |
| 上記以外のサーバ内部エラー | **500** | `CodedError` |

**403 を返すエンドポイントは無い** — 会話は個人スコープのみで、
「見えるが操作できない」状態が存在しない ([README.md](README.md) §2.5 の判定境界)。

### 6.2 ストリーム開始後 (SSE で表現する)

**200 とヘッダを既に送出済みなので HTTP ステータスでは表現できない** (D-API-12)。

| 事象 | SSE |
|---|---|
| LLM 呼び出しの失敗・DB エラー・想定外の例外 | `error` (`outcome=failed`) → `turn_summary` → `done` |
| 安全弁の発火 | **`error` を出さない**。`turn_summary` (`outcome=tool_limit` / `token_limit` / `timeout`) → `done` |
| ツール 1 本の失敗 | `tool_end {ok:false, error_code}` のみ。**`artifact` は出さず台帳にも書かない**。Agent には構造化エラーを返し、ターンは続行する |
| クライアント切断 | イベントは届かない。サーバは `outcome=aborted` 相当として §2.4 の rollback + `aborted` 保存を行い、[../observability.md](../observability.md) §4.3 の **F-5** として記録する |

**`error.message` にプロバイダの文言を素通ししない**。PoC は `runErr.Error()` をそのまま載せており
(`claude_managed_agents/cmd/devui/conversation.go:482`)、Anthropic API のエラー文言が FE に出ていた。
v3 は `CodedError` に包み直し、**原文は構造化ログ側にだけ残す**。

### 6.3 区別すべき失敗と O-4 の 5 分類との対応

**`CodedError` のコード値は本書に列挙しない** — 新規コードの一覧は
**実装リポの `constants` パッケージが SSOT** ([README.md](README.md) §2.6)。本書は**区別すべき事象**を確定させる。

| 事象 | 判別 | 伝え方 | [../observability.md](../observability.md) §4.3 |
|---|---|---|---|
| 出力の切り詰め | `stop_reason == max_tokens` | ツール内なら構造化エラー + `tool_end.ok=false` / ターン本体なら `error` | **F-1** |
| LLM 出力の JSON パース失敗 | 構造化出力のパースエラー | 同上。**フォールバックで成功にしない** | **F-2** |
| ツール引数の不整合 (必須欠落・enum 外) | ハンドラのパース | 構造化エラー `{error, missing:[…]}` を Agent に返す | **F-3** |
| 安全弁の発火 | Runner の判定 | **`turn_summary.outcome`** (エラーではない) | **F-4** |
| SSE の送出中の切断・書き込み失敗 | Controller | ログとメトリクスのみ (相手がいない) | **F-5** |
| 所有者不一致 | ハンドラのクエリ結果 0 件 | Agent には「見つからない」/ サーバは warn + メトリクス | (§4.4 の④) |
| 台帳のサイズ上限超過による退避 | 書き込み時 | warn + メトリクス。**無言で減らさない** ([../data-model.md](../data-model.md) §4.11.2) | — |

**すべて warn ログ + メトリクスに出す。握り潰さない** (CV-DF4)。

**成功を装うフォールバックを作らない (AC-CV-5.6)**: PoC の `research_market` は LLM 応答の JSON パースに
失敗すると、**Exa 検索結果のタイトルをそのまま領域名にして `tool_end.ok=true` で artifact まで出す**
([../../analysis/poc-conversation-flow.md](../../analysis/poc-conversation-flow.md) §4.3)。
**この挙動は移植しない**。パース失敗は F-2 として構造化エラーにし、Agent に再試行または別手順を選ばせる。

**監査ログ (O-6)**: 会話ターン経由のアイデア生成・企画書生成も
[../observability.md](../observability.md) §4.5 の記録対象 (「生成」「LLM を伴う操作の実行」) に入る。
**本書で新しい記録対象を追加しない**。書き込み失敗時の扱い (別トランザクションの best-effort + warn) は
[../architecture.md](../architecture.md) §3.9③ が SSOT。

### 6.4 前提不足の拒否 (CV-D4)

**ツール集合は `stage` によらず常に全数**であり、前提を満たさない呼び出しは**ハンドラが拒否**する。

- 返す形: `{"error":"<日本語の説明>","missing":["generated_ideas"]}` の構造化エラー (PoC と同形)
- `tool_end.ok=false` になり、`artifact` は出さず**台帳にも書かない**
- **ターンは失敗しない**。Agent は `missing` を見て不足を埋める手順に戻れる
- 前提の一覧は §4.1 の「前提」列、Agent への事前提示は §2.2 の `tool_readiness`

---

## 7. 設計判断

| # | 論点 | 採用案 | 却下案と理由 |
|---|---|---|---|
| **D-CV-1** | 会話ターンの入口 | **`POST /conversations/{session_id}/messages` が同期 SSE を返す** (CV-D3)。回復は `GET /conversations/{session_id}` (台帳) + `GET /conversations/{session_id}/messages?after_seq=` (履歴) | (a) ターンのジョブ化 (`202` + `turn_id` + 購読): 進捗の DB ポーリング機構・`turns` テーブル・購読権検証が増え、応答レイテンシにポーリング間隔が乗る。(b) 企画書生成だけジョブ化: 入口が 2 系統になり計測と安全弁の適用が分かれる |
| **D-CV-2** | **J-6 / J-7 との関係** | **J-6 (実行 goroutine と SSE 接続の分離) の対象外**。理由: **SSE を返すリクエスト自身がターンを実行する**ため、ALB が「ジョブが走っていないタスク」へ SSE を振る事象が起こり得ない。**J-7 (結果の取得口を SSE 以外にも持つ) は満たす** — 台帳 GET + 履歴 GET の 2 本 | (a) J-1〜J-7 に完全準拠させる (= D-CV-1 の却下 a と同じ)。(b) 無言で逸脱する: 規約からの逸脱が読者に見えない。**[README.md](README.md) §1.3 への明記を §8 の R-CVA-6 で起票する** |
| **D-CV-3** | スコープ | **個人スコープ固定。`scope` パラメータを持たない** | (a) `scope=mine\|contract` を置く (他ドメインと揃える): 会話は**未整理の思考過程と持ち込み資料**を含み、契約内共有の要求が確認できていない。増分 1 で `contract` を拒否する形 (D-API-8') にしても、パラメータの存在自体が「いずれ共有される」という誤った期待を作る。共有が必要になった時点で追加する (追加は後方互換) |
| **D-CV-4** | v2 の `PUT /idea-hassans` の受け方 | **タイトル更新 (`PUT /conversations/{session_id}`) と発散条件の変更 (会話ターン) の 2 経路に割る** | (a) 発散条件のフィールドを持つ `PUT` を作る: v2 の条件列 (`ai_role` / `industry` / `trend` / …) を v3 のテーブルに再現することになり、**台帳と列の二重管理**になる。V-1 を会話型フローへ統合する決定 ([../llm-migration.md](../llm-migration.md) §4.2) と矛盾する。(b) タイトル更新も会話ターン経由にする: リネームに LLM 1 往復が要る |
| **D-CV-5** | `managed_session_id` の露出 | **API に出さない** | (a) PoC 踏襲 (一覧・単体で返す — `claude_managed_agents/cmd/devui/conversation_list.go:39`): 外部サービス (Anthropic) の内部 ID を FE に配ると、**FE がそれを使う実装**が生まれ、セッションの張り替え (archived からの再作成) で壊れる。v3 は DB のみで保持する ([../data-model.md](../data-model.md) §4.5) |
| **D-CV-6** | 会話作成のパス | **`POST /conversations` (ボディに `theme_id` 必須)** | (a) `POST /themes/{theme_id}/conversations`: 取得・更新・削除がフラットなので、**1 リソースに 2 系統のパス**ができる。一覧 `GET /conversations?theme_id=` もフラットで、作成だけネストすると orval の生成関数名が揃わない |
| **D-CV-7** | テーマの必須化 | **`theme_id` 必須。PoC の暗黙テーマ作成を移植しない** (CV-D8) | (a) PoC 踏襲 (テーマ無しで開始し `generate_ideas` 時に暗黙作成): 紐づく前の `llm_call_records.theme_id` が NULL で残り、O-3 のテーマ単位集計に穴が空く。(b) 遡及更新: 明細の append-only ([../data-model.md](../data-model.md) §7.2 の検査 5) と矛盾する |
| **D-CV-8** | `turn_seq` の採番 | **そのターンのユーザー発話の `conversation_messages.seq` を `conversation_tool_calls.turn_seq` に使う** | (a) 独立採番 (`conversation_tool_calls` 側で `MAX+1`): **同じ「ターン」を指す採番が 2 系統**になり、ズレたときにどちらが正か決まらない。加えてツールを 1 本も呼ばないターンでは行が生まれず、番号が飛ぶ |
| **D-CV-9** | 台帳 write-through と `artifact` の順序 | **台帳・生成物の書き込みを先に行い、その後に `artifact` を送出する** | (a) PoC 踏襲 (`artifact` → 台帳。`claude_managed_agents/cmd/devui/conversation.go:606` → `:607` の順。保存失敗は `log.Printf` のみ): **FE が見た内容が DB に無い**状態が起き得る (静かなデータ喪失)。体感レイテンシの差は 1 回の DB 書き込み分にすぎない |
| **D-CV-10** | 状態注入の渡し方 | **ユーザーメッセージの前置きブロック** (§2.2.1) | (a) system prompt のテンプレート引数: Agent リソース側の全置換が要り D-6 と衝突する。(b) プロンプト本文に段を書く: 状態の SSOT が 2 箇所になる (BE-1) |
| **D-CV-11** | `artifact(plan)` の中身 | **タブ本文を載せず、`plan_id` と各タブの `tab_id` / `ver_no` だけを載せる** | (a) PoC 踏襲 (8 タブの本文を丸ごと SSE に流す — `claude_managed_agents/cmd/devui/conversation_tools_plan.go:215`): 1 イベントが数百 KiB になり、**同じ本文が SSE と `GET /plans/{plan_id}` の 2 経路**で配られる。FE は `plan_id` を受けて取得する形にすれば、版の復元・再生成と経路が揃う |
| **D-CV-12** | `conversation_tool_calls` の API 公開 | **公開しない** (運用・監査用の append-only 記録に留める) | (a) `GET /conversations/{id}/tool-calls` を作る: 切断時の回復は台帳 GET + 履歴 GET で足りる (D-CV-2)。ツール実行履歴は O-4 / O-6 の観測対象であり、**ユーザー向けの表示要件が確認できていない**。必要になった時点で追加する (追加は後方互換) |
| **D-CV-13** | V-4 / V-5 を `research_market` に吸収するか (LM-R8 の判定) | **吸収しない (独立移送のまま)**。[../llm-migration.md](../llm-migration.md) §7.1 の **M-7 は消滅しない** | (a) 吸収する: V-4 / V-5 は「**アイデア 1 件**に対する Web 検索で市場規模・CAGR を埋める」経路で、入力が確定したアイデア・出力が特定フィールド。`research_market` は「**テーマに対する候補領域の抽出**」で入力がクエリ・出力が領域行。**目的・入出力・呼び出し契機のすべてが違い**、吸収すると 1 つの tool の出力スキーマに 2 用途が混ざる (BE-12 の温床) |
| **D-CV-14** | 持ち込み PDF の待ち方 | **ターン内で待たない。完了・確定後の次ターンから参照する** (§4.3) | §4.3 の却下 (a)(b)(c) |
| **D-CV-15** | アイデア再評価の入口 | **tool にしない (REST)** (§4.2) | §4.2 の却下 |

---

## 8. 他文書への是正要求 / 受信欄

### 8.1 本書が起票するもの (状態列つき)

**状態は「未対応 / 実施済み / 対応不要」+ 日付**。統合作業 (CV-D の単位) で消化する。
[requirements-conversation.md](../../../aidlc-docs/inception/productionization/requirements-conversation.md) §5 に
既に同じ内容の起票がある場合は「既存 ID」列で対応付ける (二重管理しない)。

| ID | 起票先 | 内容 | 理由 (やらないと何が壊れるか) | 既存 ID | 状態 |
|---|---|---|---|---|---|
| **R-CVA-1** | [../data-model.md](../data-model.md) §4.5 | `conversation_sessions` に **`title text NULL`** を追加する。`display_title` の導出は §1.4 のとおり `title` を第 1 候補にする | v2 の `PUT /idea-hassans` (リネーム) の受け先が無くなり C-16 の例外承認が要る | — | **実施済み** (2026-08-01。data-model.md §4.5 に `title text NULL` を追加し、導出順序は本書 §1.4 が SSOT であることを明記) |
| **R-CVA-2** | [../data-model.md](../data-model.md) §4.11.2 | 台帳に **`seed_idea`** (string) を追加する。書き手 = `generate_ideas` の引数、読み手 = 発散入力 + §2.2 の注入 | v2 の V-3 (マイアイデア補完) の入力原文がどこにも残らない (BE-1)。**書き手だけ・読み手だけのフィールドを作らない** (BE-10) | — | **実施済み** (2026-08-01。data-model.md §4.11.2 の書き手・読み手表に `seed_idea` 行を追加) |
| **R-CVA-3** | [../data-model.md](../data-model.md) §4.5 | `conversation_tool_calls.turn_seq` の定義を「**そのターンのユーザー発話の `conversation_messages.seq`**」と注記する (D-CV-8) | 採番主体が書かれていないと実装が独立採番を作り、2 系統がズレる (BE-11) | — | **実施済み** (2026-08-01。data-model.md §4.5 の判断リストに注記) |
| **R-CVA-4** | [../data-model.md](../data-model.md) §4.5 / §4.6 / §8.4 | ①`conversation_messages` への書き込みが**ターンの主トランザクションの外**であることを注記する (§2.4) ②**§8.4 の仮定 4 (`status` の値域) を「変更なしで確定」としてクローズ**する ③**§4.5 / §4.6 の「対応 API」列**の「会話型 API 設計は別途起草 (対象外)」を `API/conversation.md` (アイデア・企画書は **[ideas.md](ideas.md)** / `plans.md`) への参照に更新する ④§8.4 の仮定 4 の直上にある「会話型 API 設計が §4.5 のテーブルを前提にする」仮定を「確認済み」に更新する | ①が無いと「ターン全体で 1 トランザクション」だけを読んだ実装が主 tx 内で書き、rollback で質問ごと消える。②は AC-CV-2.4③。③④は起草済みの文書を「未起草」と書いたまま残すと、実装者が仕様不在と判断して着手を止める (`06-delegation-prompts.md` の「機構を直したら、その機構を語る文書を同じ差分で直す」) | R-CV-7 (②) | **実施済み** (2026-08-02 に③も完了。①主トランザクション外の注記と②仮定 4 のクローズは 2026-08-01。③§4.5 は `API/conversation.md`、**§4.6 は `API/ideas.md` / `API/plans.md` / `API/conversation.md` の 3 リンク**に更新) |
| **R-CVA-5** | [../observability.md](../observability.md) §4.2 | `feature` の const 群に §3.3 の 7 値を登録する (`conversation.turn` / `idea.diverge` / `plan.generate` / `idea.evaluate` / `conversation.deepdive` / `conversation.match` / `conversation.research`) | const が無いと [../testing.md](../testing.md) の LLM 経路テスト存在検査が 0 件を検査して緑になる | — | **実施済み** (2026-08-01。observability.md に §4.2.1 を新設し 7 値を表で登録。あわせて `theme_id` 行の「テーマ確定前の呼び出しがある」を CV-Q8=A に合わせて撤回) |
| **R-CVA-6** | [README.md](README.md) §1.3 | 「**会話ターンは同期 SSE であり J-6 の対象外。ただし J-7 は満たす**」を明記する (D-CV-2) | J-1〜J-7 からの無言の逸脱になる | R-CV-2 | **実施済み** (2026-08-01。README.md に §1.3.1「会話ターンは J-1〜J-7 の適用外」を新設) |
| **R-CVA-7** | [README.md](README.md) §0 / §3 + `scripts/check-endpoint-mapping.sh` | §0 の「会話型アイデア創出は対象外」宣言を解除し、§3 の総覧に**会話ドメイン (§1.1 の 7 本・LLM 1 / SSE 1 / 403 0)** を追加する。検査④の対象集合 (`themes assets knowledge idea-boards news settings`) に `conversation` を加える | 機構を直さずに文書だけ増やすと、検査が新ファイルを見ないまま「通った」ことになる (F-CV11 / DR-9) | R-CV-9 | **実施済み** (2026-08-02。README §0 の対象外宣言を解除、§3 の総覧を 9 ドメイン 112 本 + 認証 37 = 149 に更新、§3.7 を新設。`check-endpoint-mapping.sh` は `DOMAINS` 配列 + `NDOM` 方式にして 9 ドメインへ拡張 — 照合 23 → **29 件**、故障注入 3 種で検出を確認) |
| **R-CVA-8** | [../frontend.md](../frontend.md) §16.1 / §6.2 / §6.3.1 / §11.1 | **FE-Q1 をクローズ**する。§6.3.1 の中継 Route Handler 表の「会話ターン (パス未定)」を **`POST /conversations/{session_id}/messages`** で確定、§6.2 の **S-9 (`unknown` 固定) の解除条件が満たされた**ことを記載、§11.1 の `[未確定]` を `[API]` へ | FE は「イベント型が確定するまで実装に着手しない」と決めており、クローズしないと会話画面が着手できない | R-CV-11 | **実施済み** (2026-08-01。FE-Q1 をクローズ扱いに更新 / §6.3.1 の中継表に会話ターンと企画書タブ再生成の 2 行を確定 / S-8・S-9 の「型未定義の経路」記述を更新 / §11.1 の `[未確定]` を `[API]` へ) |
| **R-CVA-9** | [themes.md](themes.md) / [idea-boards.md](idea-boards.md) | **TH-Q3 / D-TH-4 と IB-Q7 をクローズ**し、参照先を本書 §2.3 にする。**IB-Q7 の結論は「会話の `stage` を配らず、アイデア自身の事実から導く」** | 放置すると 2 文書が独自にステージを定義する | R-CV-13 | **実施済み** (2026-08-01。themes.md TH-Q3 と idea-boards.md IB-Q7 をクローズ。IB-Q7 は「会話の stage を引かず、企画書の有無から導く」と明記 — 会話セッションを持たないアイデアでも成立させるため) |
| **R-CVA-10** | [assets.md](assets.md) §5 | **AS-Q11 をクローズ**し、「4 系統目を作らず既存②に寄せた」ことと **D-AS-4 の 3 系統の根拠が維持されている**ことを記載する | クローズしないと D-AS-4 の却下根拠が宙に浮く | R-CV-12 | **実施済み** (2026-08-01。assets.md §5 の AS-Q11 をクローズし、D-AS-4 の 3 系統の根拠が維持されていることを明記) |
| **R-CVA-11** | [../llm-migration.md](../llm-migration.md) §9.2 / §7.1 | **LM-R8 の判定結果 (V-4 / V-5 を `research_market` に吸収しない = M-7 は消滅しない)** を反映する (D-CV-13) | 「判定の実施主体は本増分」と名指しされており、未反映だと M-7 の存廃が宙吊りのまま残る | R-CV-14 (前半) | **実施済み** (2026-08-01。llm-migration.md §9.2 の LM-R8 をクローズし、§4.2 の直前の注も「吸収しない」で確定。**あわせて R-CV-1 (企画書系 V-7〜V-11 の優先度を 2〜3 → 1) も反映**し、§7.1 の段割りとの不整合を **LM-R10** として起票した) |
| **R-CVA-12** | [../../analysis/v2-feature-inventory.md](../../analysis/v2-feature-inventory.md) §2.5 | **V ラベルの誤記を訂正する** — `POST /ideas/generate/my-idea` と `.../draft` は **V-3 (マイアイデア補完)**、`POST /ideas/evaluate` は **V-2 (アイデア評価)** である ([../llm-migration.md](../llm-migration.md) §4.2 の V-1〜V-6 の定義)。旧記述は順に V-2 / V-3 / V-6 だった | 誤ったラベルのまま `ideas.md` が対応表を作ると、V-6 (企画書簡易モード) の受け先がアイデア側に紛れ込む | — | **実施済み** (2026-08-01。メインセッションが訂正。`.../draft` も同じ UseCase = `hassan-v2-backend/usecase/idea/create_my_idea.go:207` の `ExecuteDraft` であることを出典として追記した) |
| **R-CVA-13** | [../data-model.md](../data-model.md) §4.5 / §8.4 | **`conversation_sessions.theme_id` を NOT NULL 化**する (FK の `SET NULL` とパーシャルインデックスの条件も連動)。**§8.4 の仮定 6 をクローズ**する | CV-D8 の帰結。NULL 可のままだと `llm_call_records.theme_id` に穴が空く | R-CV-3 | **実施済み** (2026-08-01。data-model.md §4.5 で `theme_id` を NOT NULL + FK CASCADE + 通常インデックスへ変更し、§8.4 の仮定 6 をクローズ) |

**R-CVA-1 / R-CVA-2 は列・フィールドの追加を伴う**ため、[../data-model.md](../data-model.md) の
テーブル件数 (DR-9) には影響しない (**新規テーブルではない**) が、**台帳フィールド表の行が増える**ため
§4.11.2 の CI 検査 (書き手の存在検査) の対象が 1 件増える。

### 8.2 本書が受け取った是正要求 / 委譲 (受信欄。DR-8 の受信側)

| 起票元 | ID | 内容 | 本書での回答 | 状態 |
|---|---|---|---|---|
| [themes.md](themes.md) | **TH-Q3 / D-TH-4** | ステージ定義の SSOT | **§2.3** (5 値 + 導出 + テーマは畳まない) | **回答済み** (2026-08-01) |
| [idea-boards.md](idea-boards.md) | **IB-Q7** | `items[].stage` の定義 | **§2.3.2** (会話の stage を配らない) | **回答済み** (2026-08-01) |
| [idea-boards.md](idea-boards.md) §8.1 | `tags` の書き込み側 (BE-10) | tool にするか REST か | **§4.2** (REST。パスは `ideas.md`) | **回答済み** (2026-08-01) |
| [assets.md](assets.md) §5 | **AS-Q11** | 4 系統目を作らない | **§4.3** | **回答済み** (2026-08-01) |
| [../frontend.md](../frontend.md) §16.1 | **FE-Q1** | SSE イベント型の確定 | **§5** | **回答済み** (2026-08-01) |
| [../llm-migration.md](../llm-migration.md) §9.2 | **LM-R8** | V-4 / V-5 の吸収可否 | **§7 の D-CV-13** (吸収しない) | **回答済み** (2026-08-01) |
| [../llm-migration.md](../llm-migration.md) §4.1 | **LM-Q1 の委譲** (P-3 統合後のプロンプト・ツール構成・会話状態) | | **§2.2 / §3.1 / §4.1** | **回答済み** (2026-08-01) |
| [requirements-conversation.md](../../../aidlc-docs/inception/productionization/requirements-conversation.md) §7 の 5 | 抽出ジョブの完了を会話がどう待つか | | **§4.3** (待たない) | **回答済み** (2026-08-01) |
| [../data-model.md](../data-model.md) §8.4 の仮定 4 | `conversation_messages.status` の値域 | | **§2.4** (`complete`/`aborted`/`failed` で確定) | **回答済み** (2026-08-01) |
| [../llm-migration.md](../llm-migration.md) §9.2 | **LM-R6** (評価軸の統合) | | **本書の範囲外** — **[ideas.md](ideas.md)** (CV-B) が調査して決める | **委譲** (2026-08-01) |

---

## 9. 実装リポへの引き渡し

### 9.1 依存順序

```
data-model.md の会話 4 テーブル (+ R-CVA-1/2/3/4/13 の反映)
   ↓
entity/conversation (台帳の型・stage 導出・注入ブロック構築)  ← UT 必須
entity/toolresult   (8 tool の結果型 + marker interface)      ← 先に固める (後付け不可)
   ↓
gateway/anthropic (CallMeta = usage 4 カウンタ + stop_reason) / gateway/exa
   ↓
repository/conversation (台帳 IF・メッセージ採番・tool_calls)
   ↓
service/conversation.Runner (ツールループ・安全弁・SSE 変換・台帳 write-through)
   ↓
usecase/conversation (tool_registry のクロージャ束縛・トランザクション境界)
   ↓
controller (SSE ヘッダ・CodedError 変換 1 箇所)
```

### 9.2 並列可能

- **§5 の SSE イベント型の OpenAPI 定義**は上記と並列に着手できる (FE のブロック解除が最速になる)
- **`scripts/check-tool-contract.sh` の実装**も並列可能 (期待値は §4.1 / §4.5 / §3.1 の表)
- **`prompts/conversation/` の 8 ファイル** (`orchestrator.md` / `deepdive_*` 6 本 / `research_market.md` /
  `match_functions.md`) の起こしは Go の実装と並列 (レイアウトは [../llm-migration.md](../llm-migration.md) §6.1)

### 9.3 参照すべき既存実装

| 目的 | 参照先 | 扱い |
|---|---|---|
| SSE のマルチライン取りこぼし対策 (BE-7 の**修正済み**実装) | `claude_managed_agents/cmd/devui/conversation_stream.go` | **手本にする** (除外リスト方式・空行を本文として通す) |
| 1 ターンの処理順序 | `claude_managed_agents/cmd/devui/conversation.go` | 順序の参考。**net/http・手書き store・`http.Error` は持ち込まない** |
| tool schema の定義 (9 本) | `claude_managed_agents/cmd/update-agent-prompt/main.go:280` | 引数名・enum・description の**移植元**。`set_theme_name` は除く |
| `stage` 導出 | `claude_managed_agents/internal/db/conversation_store.go:250` | 判定順序をそのまま移す |
| Managed Agent のツールループ | `claude_managed_agents/internal/session/run.go` | 同一 batch の**逐次** dispatch を維持する |
| SSE ヘルパー | `hassan-v2-backend/controller/controller.go` の `SetupSSEHeaders` 系 | v3 の Controller 共通層の手本 (D-API-12) |
| `CodedError` の集約ハンドラ | `hassan-v2-backend/controller/idea_board.go` | 変換 1 箇所の手本 |
| **反面教師** (BE-12 の実バグ) | `claude_managed_agents/cmd/devui/conversation_plan_grounding.go` (読み手) / `claude_managed_agents/cmd/devui/conversation_tools_deepdive.go` (書き手) | **同じ構造にしない**。読み手・書き手・テストを `entity/toolresult` の 1 宣言から導く |

---

## 10. 残課題 / 要確認

**仮定を添えて書く。違えば §7 の判断が変わる。**

| ID | 内容 | 仮定 (この前提で設計した) | 確定先 |
|---|---|---|---|
| **CV-R1** | **Managed Agents で Session 単位に system prompt を上書きできるか**が未調査 (PoC は Agent リソース側にのみ登録している — `claude_managed_agents/cmd/update-agent-prompt/main.go:215`) | **できないものとして設計した** (§2.2.1)。仮にできても採らない — 毎ターン変わる状態を Agent 側に置くと D-6 のハッシュ差分判定と衝突するため。**この仮定が崩れても §2.2 の「注入する内容」は変わらない** (渡し方だけが変わる) | 実装リポの技術検証 |
| **CV-R2** | **`progress.total` の値域** (PoC は `ideas`=5 / `plan`=8 の固定値) | **`entity/` の定数 1 箇所を SSOT とする**前提で設計した (BE-2)。発散の工程数が v3 で変わる場合は定数だけが変わり、SSE の契約は変わらない | 実装リポ (P-2 / P-4 の実装時) |
| **CV-R3** | **`tool_start.label` の多言語化** — PoC 踏襲で**サーバが日本語の固定文言を送る** | 第 1 リリースは日本語のみと仮定した。多言語化が必要になったら `label` を廃してコード化し、FE が表示文言を持つ (**CV-D6 の 4 点を超える変更なので本増分では行わない**) | [../frontend.md](../frontend.md) の i18n 方針 |
| **CV-R4** | **注入ブロックのサイズ上限** (`rejected_candidates` の件数など) | **`config` に置く**前提で設計し、本書に数値を書いていない。実測前の初期値は実装リポで決める | [../observability.md](../observability.md) / 実装リポの `config` |
| **CV-R5** | **入れ子の Agent 実行 (P-1 → P-2 / P-4) が `llm_call_records` で二重計上にならないか** | **ならない**と仮定した — 明細は 1 呼び出し 1 行で `feature` が違うため、合算は集計側の責務。ただし「ターンのコスト」を出すときに内側を含めるかは集計クエリの定義次第 | [../observability.md](../observability.md) §6.1 の集計設計 |
| **CV-R6** | **v2 の `idea_hassans` 既存データを v3 の `conversation_sessions` へ移行するか** | **移行しない**前提で設計した (v2 の発散条件は台帳の構造と対応が付かず、会話履歴も v2 に存在しない)。移行するなら `title` と `theme_id` のみの写像になる | 移行計画 (plan.md の Task-2f 系) |
| **CV-R7** | **`GET /conversations` の `keyword` が台帳 JSONB を対象にする場合のインデックス** | `title` 列 + 台帳の `theme` を対象と仮定した。JSONB への GIN が要るかは実データ量次第 | [../data-model.md](../data-model.md) §3.5 |
| **CV-R8** | **評価軸の統合 (LM-R6)** | **本書の範囲外**。[ideas.md](ideas.md) (CV-B) が v2 (V-2) と PoC (P-5) を突き合わせて決める。本書は「再評価を tool にしない」ことだけを確定させた | **解消済み** (2026-08-02。[ideas.md](ideas.md) §6.2 が対照表を確定し、[llm-migration.md](../llm-migration.md) §9.2 の LM-R6 もクローズした) |
