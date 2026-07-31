# PoC プロンプト資産の棚卸し (Task-2d)

> 調査日: 2026-07-30 / 調査: `poc-analyst` (オーケストレーターが 6 件を一次ソースで抜き取り照合済み)。
> 対象: `claude_managed_agents` (PoC)。**事実の記録** — v3 での実装形態の判断は
> `docs/design/llm-migration.md` (Task-3h) が行う。
> 用途: ①機能別の v3 実装形態・使用モデル見直しの入力 ②Managed Agent ライフサイクル設計
> (どのプロンプトが Agent 再発行対象か = D-6) の入力。

## 1. プロンプト一覧

### 1.1 `prompts/` 配下 (専用ディレクトリ。`go:embed` または CLI がファイル読込)

| ファイル (パス:行) | 用途 | 呼び出し経路 | 実行形態 | 出力形式 | MaxTokens |
|---|---|---|---|---|---|
| `claude_managed_agents/prompts/idea_diverge_system.md:1` | アイデア発散 + 4 出力モード (`output_mode: domain/trend/usage/spec_discovery` が同一ファイルに同居 `:5-156`) | `/api/diverge/{domains,trends,usages,specs}` (`cmd/devui/domain_discovery.go:8` ほか) / `/api/diverge-managed` | **Managed Agent** (`DIVERGE_AGENT_ID`) の system prompt。加えて `prompts.IdeaDivergeSystem` 変数 (`prompts/embed.go:10-11`) として raw 経路にも直接送信 | 自由文 | Agent 側設定 / raw 経路は 8192 (`internal/agent/diverge/providers/anthropic.go:28`) |
| `claude_managed_agents/prompts/idea_diverge_system.original.md:1` | 上記から並列化指示等を除いた切り分け用 | `update-agent-prompt --revert` 時のみ | Managed Agent system prompt (代替版) | 自由文 | 同上 |
| `claude_managed_agents/prompts/post_diverge_chat_system.md:1` | 発散済みアイデア参照アシスタント (再発散しない) | `POST /api/diverge-managed/chat` (`cmd/devui/diverge_chat.go:18`) | **Managed Agent** (`CHAT_AGENT_ID`) | 自由文 | Agent 側設定 |
| `claude_managed_agents/prompts/idea_evaluate_system.md:1` | アイデア 1 件のリッチ評価 | `POST /api/ideas/evaluate` (`cmd/devui/idea_evaluate.go:178`) | 直接 API messages | JSON (1 オブジェクト厳守) | 8192 (`cmd/devui/idea_evaluate.go:44`)。`StopReason==max_tokens` 検出あり (`:192-193`) |
| `claude_managed_agents/prompts/asset_extract_system.md:1` | PDF からアセット棚卸し情報の構造化抽出 | `internal/asset_extract/llm.go:34` (PDF) / `url_llm.go:66` (URL) | 直接 API | JSON | 16384 (`llm.go:20` / `url_llm.go:25`) |
| `claude_managed_agents/prompts/asset_extract_patent_fallback_system.md:1` | Web 検索結果からの特許情報抽出 (PDF 失敗時の 2 段目) | `internal/asset_extract/patent_fallback.go:409` | 直接 API | JSON | 4096 (`patent_fallback.go:24`) |
| `claude_managed_agents/prompts/asset_merge_system.md:1` | 重複アセット候補のグルーピング判定 | `POST /api/asset/merge-candidates` (`cmd/devui/asset_merge.go:157`) | 直接 API | 小さな JSON | 2048 (`asset_merge.go:54`) |
| `claude_managed_agents/prompts/idea_plan_system.md:1` | 企画書 8 タブの 1 ショット全生成 (従来ロジック) | `/api/ideas/plan` の**同期 (非 SSE) 分岐のみ** (`cmd/devui/idea_plan.go:323`)。FE は常時 SSE で呼ぶため **FE からは到達しない** | 直接 API (streaming) | JSON (8 タブ) | 48000 (`idea_plan.go:73`) |
| `claude_managed_agents/prompts/idea_plan_agent_system.md:1` | 企画書 1 タブ分の生成 (Managed Agent 版) | `engine=agent` の 6 タブ (summary/pestel/market/competitor/tech/legal — `cmd/devui/idea_plan_managed.go:21-27`)。service/bmc タブは常に API 直叩き | **Managed Agent** (`PLAN_AGENT_ID`) | JSON (1 タブ) | Agent 側設定 |
| `claude_managed_agents/prompts/conversational_orchestrator_system.md:1` | 会話型オーケストレーター (5 ステップ探索パートナー) | `POST /api/conversation` (`cmd/devui/conversation.go:6` ほか) | **Managed Agent** (`ORCHESTRATOR_AGENT_ID`)。custom tool は Go 側ディスパッチ | 自由文 (対話) | Agent 側設定 |
| `claude_managed_agents/prompts/research_system.md:1` | リサーチャー用 system prompt (情報源優先度ルール等) | **呼び出し元なし** — `prompts.ResearchSystem` (`prompts/embed.go:8`) は宣言のみ (照合済み)。発行コマンド例も無い | **未配線** | 自由文 | — |
| `claude_managed_agents/prompts/diverge/orchestrator.md:1` | 発散オーケストレータ (Go 自前ツールループ版) | `internal/agent/diverge/service.go:44` — **ただしこの Service 一式が未配線** (§4) | 直接 API | 自由文 | 8192 |
| `claude_managed_agents/prompts/diverge/input_validator.md:1` | 発散前の入力バリデーター | `internal/agent/diverge/service.go:19` — 同上**未配線** | 直接 API | `READY` or 質問 JSON | 300 |
| `claude_managed_agents/prompts/diverge/tools/research.md:1` ほか 2 ファイル (ideation / critique) | 発散オーケストレータの custom tool 3 種の内部 system prompt | `internal/agent/diverge/toolset.go:12-14` — 同上**未配線** | Go 側で別 LLM 呼び出し | ツール依存 | 各 tools/*.go |
| `claude_managed_agents/prompts/diverge/patterns/domain.md:1` ほか 3 ファイル (trend / usage / spec) | 4 軸別の発散指示 (`orchestrator.md` と動的連結 `internal/agent/diverge/pattern_prompt.go:31-37`) | 同上**未配線** | 直接 API | 自由文 | 8192 |
| `claude_managed_agents/prompts/conversational/deepdive_credibility.md:1` ほか 5 ファイル (competition / momentum / demand / counterevidence / problem_structure) | 会話 `deep_dive` custom tool の 6 パターン別 system prompt | `cmd/devui/conversation_tools_deepdive.go:33-66` (レジストリ) | 直接 API (`:128-134`) | JSON (1 オブジェクト厳守) | 8192 (`:124`)。max_tokens 検出あり (`:139-141`) |

### 1.2 Go コード埋め込み文字列 (`.md` ファイル化されていない)

| パス:行 | 用途 | 呼び出し経路 | 出力形式 | MaxTokens |
|---|---|---|---|---|
| `cmd/devui/conversation_tools_matching.go:46` | `match_functions` tool (機能×市場ペアのスコアリング) | 会話 custom tool | JSON | 4096 (`:43`。照合済み)。max_tokens 検出あり (`:112-113`) |
| `cmd/devui/conversation_tools_research.go:149` | `research_market` tool (pattern=domain) の候補領域抽出 | 会話 custom tool | JSON 配列 | 4096 (`:189`) |
| `cmd/devui/conversation_tools_research.go:290` | 同 (pattern=trend) | 同上 | JSON 配列 | 4096 (`:336`) |
| `cmd/devui/themes_tags.go:46` | テーマのタグ推定 | `POST /api/themes/tags/suggest` (`cmd/devui/main.go:584`) | 未確認 (タグ配列想定 — 推測) | 256 (`:71`) |
| `cmd/devui/evaluate.go:89` / `:102` | 旧アイデア評価 (1 次/2 次) | `POST /api/evaluate` — **FE からの呼び出し確認できず** | JSON | 4096 (`:173`) |
| `cmd/devui/deepdive.go` (`deepDiveSystemPrompt` 関数で組み立て) | 旧 BMC 深掘り文章生成 | `POST /api/deepdive` — **FE からの呼び出し確認できず** | 自由文 | 2048 (`:286`) |
| `internal/exaresearch/search_guidance.go:7` | Exa 検索の情報源優先度方針 (`research_system.md` の該当節の**再実装**とコメント明記 `:6` — 照合済み) | `internal/exaresearch/exa.go:102` / `deep.go:55` | Exa API の `systemPrompt` フィールド (Anthropic ではない) | — |

## 2. Agent 再発行対象 vs コードデプロイのみ (D-6 の入力)

**Anthropic 側 Agent リソースに登録され、変更時に再発行が必要なのは 4 ファイルのみ**:

| プロンプト | Agent ID (env key) | 発行コマンドの出典 |
|---|---|---|
| `idea_diverge_system.md` | `DIVERGE_AGENT_ID` | `cmd/update-agent-prompt/main.go:60` (既定引数) |
| `post_diverge_chat_system.md` | `CHAT_AGENT_ID` | 明示的なコマンド例は未発見 (**推測: 確信度高** — 他 3 Agent と同パターン + `cmd/devui/diverge_chat_context.go:8` のコメント) |
| `idea_plan_agent_system.md` | `PLAN_AGENT_ID` | `claude_managed_agents/CLAUDE.md:18-20` |
| `conversational_orchestrator_system.md` | `ORCHESTRATOR_AGENT_ID` | `claude_managed_agents/CLAUDE.md:29-37` (照合済み。`-conversation-tools` 指定時は tools が全置換される — BE-9。`cmd/update-agent-prompt/main.go:124-130` にガードあり) |

上記以外の全プロンプト (asset_extract 系・idea_evaluate・idea_plan_system・diverge/*・
conversational/deepdive_*・Go 埋め込み全部) は**直接 API messages 呼び出し**で、
コードのビルド・デプロイのみで反映される (Agent 再発行は不要)。
反映タイミング: Agent 再発行は devui 再起動不要・**次回セッションから** (`cmd/update-agent-prompt/main.go:193`)。

## 3. 重複・散在 (BE-2 型。v3 で構造的に潰す対象)

1. **domain/trend/usage/spec 4 軸の実装が 2 系統に分裂** — 生きている系統 (`idea_diverge_system.md` の `output_mode` 節 + Managed Agent) と未配線の系統 (`prompts/diverge/patterns/*` + `internal/agent/diverge/`)。両者は文言が異なり同一挙動ではない
2. **research_market の候補領域抽出が 2 箇所** — スタンドアロン REST (Managed Agent 経由) と会話 custom tool (直接 API + インライン Go 文字列)。入出力スキーマも別実装
3. **情報源優先度ルールの二重実装** — `research_system.md:28-34` (未配線) と `internal/exaresearch/search_guidance.go:7` (実使用)。「整合させた」コメントはあるが同期の仕組みは無く手作業追従
4. **アイデア評価が 3 実装並存** — `idea_evaluate_system.md` (現行) / `evaluate.go` の 2 プロンプト (旧・FE 呼び出しなし)
5. **企画書生成の system prompt が 3 方式並存** — `idea_plan_system.md` (8 タブ一括・FE 未使用) / `idea_plan.go` 内 per-tab 組み立て (ファイル化なし) / `idea_plan_agent_system.md` (Agent・1 タブ)。MaxTokens も個別 (48000 / タブ別 / Agent 側)

## 4. 未配線・レガシーの判定根拠 (事実と推測の区別)

**事実 (grep で照合済み)**:
- `internal/agent/diverge/` の `Service` 一式 (`NewService` / `RunWithHistory` / `RunOnceWithEvents` / `ValidateInput`) は、非テストコードからの呼び出しが**コメント内の言及のみ** (オーケストレーターが再照合済み)。`cmd/devui/conversation_tools_generate.go:60` のコメントに「増分 2 の軽量経路を Managed Agent 経由に置き換え」と明記 — **過去は生きていたが現在は置換済み**
- `prompts.ResearchSystem` は `prompts/embed.go:8` の宣言のみ (再照合済み)
- `/api/evaluate` と `/api/deepdive` はルーティング登録済み (`cmd/devui/main.go:620-621`) だが `frontend/src` に呼び出しなし

**推測 (確信度)**:
- `/api/evaluate` / `/api/deepdive` は `idea_evaluate` / `deep_dive` tool に機能的に置き換えられたレガシー — 確信度: 中 (手動 curl 等での利用可能性は否定できない)

## 5. 未調査の範囲

- FE 側 (`frontend/src`) のプロンプト由来文言・上限値の重複 (BE-2 の 3 層目) は未照合
- `CHAT_AGENT_ID` の正式な発行コマンド全文 (Makefile・scripts 配下は未探索)
- `themes_tags.go` のプロンプト本文全文 (出力形式が JSON 配列かは未確認)
- Managed Agent の tool schema と system prompt の整合 (BE-8 観点) は本調査のスコープ外
