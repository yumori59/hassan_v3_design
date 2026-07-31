# PoC 棚卸し (claude_managed_agents)

> 本番化の移植元となる PoC の**現状の事実**。設計判断は書かない (それは [architecture.md](../design/architecture.md))。
> 実測日: **2026-07-28**。実測はリポジトリ `/Users/yuyamorishita/aillio/hassan/claude_managed_agents` の
> 作業ツリーに対して行った (git のコミット状態ではなく、その時点のファイル)。
> 出典は「リポジトリ相対パス」で書く。

## 1. 全体像

| 項目 | 値 | 出典・備考 |
|---|---|---|
| Go module | `github.com/aillio/hassan/claude_managed_agents` / go 1.25.0 | `claude_managed_agents/go.mod` |
| バックエンド | Go 標準 `net/http` + `mux.HandleFunc`。フレームワーク不使用 | `claude_managed_agents/cmd/devui/main.go` |
| フロントエンド | React + Vite + Tailwind。`frontend/dist` を Go の FileServer が配信 | `claude_managed_agents/frontend` |
| 永続化 | PostgreSQL + pgx v5 (手書き store)。golang-migrate を起動時に embed.FS で自動適用 | `claude_managed_agents/internal/db/migrations` |
| LLM | Anthropic Managed Agents (Go SDK) + custom tools + SSE | `claude_managed_agents/internal/session` |
| 認証 | **なし**。単一テナント。`127.0.0.1:8765` のみで待ち受け | `claude_managed_agents/CLAUDE.md` |
| 規模 | Go 276 ファイル (うちテスト 126) / `frontend/src` 296 ファイル (うちテスト 157) | 実測 (vendor・node_modules 除く) |
| ハンドラ層 | `cmd/devui` に 123 ファイル (非テスト 59 / テスト 64) | 実測 |

## 2. HTTP API (登録ルート 28 本)

`claude_managed_agents/cmd/devui/main.go` に登録されているパターン。末尾 `/` のものは
**プレフィックスルータ**で、ハンドラ内でサブパスを自前パースして多数のエンドポイントに分岐する
(例: `/api/themes/` 配下にアイデア・評価・企画書タブ・自己評価の各操作が入る)。

| グループ | ルート |
|---|---|
| テーマ | `/api/themes`, `/api/themes/`, `/api/themes/tags/suggest` |
| 発散 (従来) | `/api/diverge-managed`, `/api/diverge-managed/chat`, `/api/diverge-managed/models`, `/api/diverge-sessions`, `/api/diverge-sessions/` |
| 発散 (軸探索) | `/api/diverge/domains`, `/api/diverge/trends`, `/api/diverge/usages`, `/api/diverge/specs` |
| **会話型** | `/api/conversation`, `/api/conversations`, `/api/conversations/{id}` |
| アセット | `/api/assets`, `/api/assets/`, `/api/assets/bulk-import`, `/api/asset-extract`, `/api/asset/extract-urls`, `/api/asset/parse-csv`, `/api/asset/merge-candidates` |
| 評価・企画書 | `/api/ideas/evaluate`, `/api/ideas/plan`, `/api/evaluate`, `/api/deepdive` |
| その他 | `/api/chat`, `/api/ready` |

- エラー返却は `http.Error(w, '{"error":"..."}', status)` 形式 (`CodedError` は存在しない)
- 長時間処理は SSE で 4 ターン (plan / action / observation / thought) を流す設計

## 3. 内部パッケージ

| パッケージ | 役割 |
|---|---|
| `claude_managed_agents/internal/agent/diverge` | アイデア発散のマルチラウンド orchestration。`UsageTotals` / `EstimateUSD` によるコスト推定を**この経路のみ**で実装 |
| `claude_managed_agents/internal/agent/planner` | 企画書生成 |
| `claude_managed_agents/internal/asset_extract` | PDF / URL からのアセット抽出・正規化・dedup |
| `claude_managed_agents/internal/asset_related` | 関連アセット探索 |
| `claude_managed_agents/internal/exaresearch` | Exa 検索 + Claude 要約パイプライン |
| `claude_managed_agents/internal/db` | 永続化 (手書き store 13 本 + migrations) |
| `claude_managed_agents/internal/config` | `.env` 読み書き (`WriteEnv` は固定キーのみ書き出す = BE-3 の原因) |
| `claude_managed_agents/internal/session` `sse` `stream` `jsonutil` | セッション・SSE・ストリーム処理・JSON ユーティリティ |

依存方向は `cmd/devui` → `internal/*` の一方向。**UseCase 層に相当するものは無く、
ビジネスロジックはハンドラと internal ドメインパッケージに分散している**。

## 4. データモデル (migration 32 本で作られるテーブル)

`claude_managed_agents/internal/db/migrations` の `*.up.sql` で作成されるテーブル:

```
themes / assets / asset_tags / asset_specs / asset_patents / extracted_assets
function_tree_l1 / function_tree_l2 / hassan_v2_ideas
diverge_sessions / diverge_brushups / diverge_idea_status
idea_versions / idea_evaluations / idea_self_ratings
plan_tab_versions / conversation_sessions
```

- **所有者カラム (account_id / company_id) は存在しない** — 単一テナント前提
- store は手書き (`claude_managed_agents/internal/db/theme_store.go` 他 12 本)。sqlc 不使用
- `DATABASE_URL` 未設定時は**インメモリにフォールバック**する (CI もこの経路前提。BE-5)

## 5. LLM / Managed Agent 層

### 5.1 Agent の種類 (すべて `.env` の ID で参照)

| 環境変数 | Agent | 用途 |
|---|---|---|
| `ENVIRONMENT_ID` | — | Managed Agents の Environment |
| `DIVERGE_AGENT_ID` | idea-diverge-agent | アイデア発散 |
| `CHAT_AGENT_ID` | idea-chat-agent | 発散セッションへの追質問 |
| `PLAN_AGENT_ID` | idea-plan-agent | 企画書生成 (`engine=agent` 経路) |
| `ORCHESTRATOR_AGENT_ID` | idea-orchestrator-agent | **会話型フロー** (`/api/conversation`) |

Agent は Anthropic 側のリソースで、system prompt と tool schema は **Agent 発行時に固定**される。
変更にはコマンド (`claude_managed_agents/cmd/update-agent-prompt`) による再発行が必要
(未設定時は該当機能が 503 を返す)。

### 5.2 会話型フローの custom tools (9 種)

`claude_managed_agents/cmd/devui/conversation_tools.go` で宣言し、Go 側でディスパッチする:

```
set_theme_name / list_assets / load_asset / match_functions
research_market / deep_dive / generate_ideas / generate_plan / record_rejection
```

- 実行は Go 側 (`session.RunWithOptions`)。**引数に所有者スコープの概念は無い**
- 台帳 (ledger) パターン: ツール引数・結果を `claude_managed_agents/cmd/devui/conversation_ledger.go` の
  台帳へ write-through し、前提チェックがそれを読む (BE-10 の発生源)

### 5.3 プロンプト資産

`claude_managed_agents/prompts` に system prompt を配置し `go:embed` で取り込む。
主要ファイル: `idea_diverge_system.md` / `idea_evaluate_system.md` / `idea_plan_system.md` /
`idea_plan_agent_system.md` / `conversational_orchestrator_system.md` /
`asset_extract_system.md` / `research_system.md` ほか。
サブディレクトリ `prompts/conversational` (深掘り 6 種) と `prompts/diverge` (orchestrator・patterns・tools) がある。

## 6. 機能フロー (PoC で動くもの)

1. **テーマ管理**: 一覧 → 作成 → 発散 (Stage 2) → 企画書作成 (Stage 3) → 完了
2. **アセット管理**: 登録 (PDF / URL / CSV / 手動) → 抽出 (SSE 4 ターン) → 機能ツリー編集 → 重複検出・マージ
3. **アイデア発散**: 4 軸 (domain / trend / usage / spec) の候補探索 → 発散 → 評価 (7 軸スコア) → ブラッシュアップ (版管理)
4. **企画書**: 8 タブ生成 (`engine=api` / `engine=agent` の 2 経路) → タブ単位ブラッシュアップ (版管理)
5. **会話型アイデア創出**: `/api/conversation` で orchestrator agent が 9 tools を使い、
   対話しながら 1〜4 を横断する (**PoC で最も新しく、v3 プロトタイプの中心**)

## 7. 品質・運用の現状

| 項目 | 現状 |
|---|---|
| テスト | Go 126 / FE 157 ファイル。CI (`claude_managed_agents/.github/workflows/ci.yml`) で build/vet/test + tsc/vitest/build/eslint |
| 認証・認可 | **なし** |
| 可観測性 | 構造化ログ・メトリクス・トレースは**なし**。コスト推定は発散経路のみ (`claude_managed_agents/internal/agent/diverge/result_helpers.go`) |
| デプロイ | **なし** (ローカル起動のみ。`make devui`) |
| シークレット | `.env` 直置き。`bootstrap` が `.env` を書き換える際に一部キーが消える既知挙動 (BE-3) |
| ドキュメント | `claude_managed_agents/spec.md` (75KB) / `claude_managed_agents/docs` / `claude_managed_agents/aidlc-docs` に多数の AIDLC 産物 (inception 40+ feature) |

## 8. 注意 (この棚卸しの限界)

- `claude_managed_agents/docs/codebase-index.md` は **2026-06-27 時点の自動生成**で、
  会話型フロー (`conversation*.go`) が含まれていない。**最新の一次ソースはコード**
- `claude_managed_agents/spec.md` は PoC 初期の仕様書で、現行実装と乖離している箇所がある。
  仕様の根拠にはコードを使う
- 本書は**構成・規模・入出口の棚卸し**であり、各機能の詳細な挙動 (プロンプト内容・
  スコアリングロジック・SSE イベント仕様) は未調査。移植対象を決めた後、
  `poc-analyst` で機能単位に深掘りする
