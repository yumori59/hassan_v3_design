# PoC 会話型フロー実測 (`POST /api/conversation`)

> 実測日: 2026-07-29 / 対象: claude_managed_agents (作業ツリー)

## 調査対象と問い

PoC の会話型フロー (オーケストレーター Managed Agent + 9 custom tools + SSE + JSONB 台帳) を
本番の 4 層アーキテクチャへ移植する設計の入力として、**現行の SSE イベント契約・台帳の読み書き経路・
ツール引数の 3 者整合・エラー時の挙動・永続化と再開・1 ターンの呼び出し順序**を出典付きで確定する。
設計提案は書かない (それは後段の `architecture-designer` の仕事)。

---

## 事実

### 1. SSE イベント仕様 (`POST /api/conversation`)

#### 1.1 トランスポート

| 項目 | 値 | 出典 |
|---|---|---|
| ルート登録 | `mux.HandleFunc("/api/conversation", handleConversation(...))` | claude_managed_agents/cmd/devui/main.go:593 |
| メソッド | POST のみ (それ以外は 405) | claude_managed_agents/cmd/devui/conversation.go:329 |
| リクエストボディ上限 | 32 KiB (`http.MaxBytesReader`) | claude_managed_agents/cmd/devui/conversation.go:80 |
| リクエストボディ | `{message (必須), session_id, theme_id, selected_domains?: [{name, rationale?}]}` | claude_managed_agents/cmd/devui/conversation.go:43 |
| レスポンスヘッダ | `Content-Type: text/event-stream; charset=utf-8` / `Cache-Control: no-cache` / `Connection: keep-alive` | claude_managed_agents/cmd/devui/conversation.go:367 |
| ステータス | SSE writer 構築後に 200 で確定 (以降の失敗は `error` イベントで表現) | claude_managed_agents/cmd/devui/conversation.go:370 |
| ワイヤ形式 | `event: <name>\ndata: <JSON>\n\n` (1 イベント 1 回の `Fprintf` + `Flush`) | claude_managed_agents/internal/sse/writer.go:39 |
| keep-alive | SSE コメント `: keepalive` を 30 秒間隔。イベントではない | claude_managed_agents/internal/sse/writer.go:114 / claude_managed_agents/cmd/devui/sse_keepalive.go:14 |

#### 1.2 イベント全種類 (9 種 + keep-alive コメント)

`cmd/devui/conversation*.go` の `sw.Event(...)` 呼び出しを全列挙した結果。

| event 名 | payload (フィールド名: 型) | 送出契機 | 出典 |
|---|---|---|---|
| `session` | `{"id": string}` — **FE 側 session_id のみ**。Managed Agent session_id は隠蔽 | ハンドラ先頭で必ず 1 回 | claude_managed_agents/cmd/devui/conversation.go:380 |
| `message_delta` | `{"text": string}` — 行末の `\n` を保持。1 行 = 1 イベント | agent 発話行ごと (bridge) | claude_managed_agents/cmd/devui/conversation_stream.go:126 / :139 |
| `tool_start` | `{"tool": string, "label": string}` — label は日本語固定文言 | 全 custom tool ディスパッチの直前 | claude_managed_agents/cmd/devui/conversation.go:591 |
| `tool_end` | `{"tool": string, "ok": bool, "elapsed_ms": int64}` | 同ツールの完了直後 | claude_managed_agents/cmd/devui/conversation.go:610 / :637 / :646 / :663 / :678 |
| `generate_progress` | `{"step": int, "total": int, "label": string, "detail"?: string}` — `total` は定数 5。`detail` は空文字のときキー自体を出さない | `generate_ideas` 実行中 | claude_managed_agents/cmd/devui/conversation.go:597 / :757 |
| `plan_progress` | `{"tab_id": string, "label": string, "done_count": int, "total": int, "phase": string}` — `total` は定数 8。status 系中継では `tab_id`/`label` が空文字 | `generate_plan` 実行中 | claude_managed_agents/cmd/devui/conversation.go:618 / claude_managed_agents/cmd/devui/conversation_plan_stream.go:129 |
| `artifact` | kind ごとに形が異なる (§1.3) | ツール成功時のみ | claude_managed_agents/cmd/devui/conversation.go:606 / :630 / :659 / :687 / :692 / :705 |
| `error` | `{"message": string}` — `runErr.Error()` を**そのまま**載せる (Anthropic API のエラー文言が FE に素通しされる) | runner が最終的に error を返したとき。1 ターンに最大 1 回 | claude_managed_agents/cmd/devui/conversation.go:482 |
| `done` | `{"elapsed_sec": float64}` — ハンドラ入口からの経過秒 | 常に最後。異常時も必ず出る | claude_managed_agents/cmd/devui/conversation.go:484 |

`tool_end.ok` の判定は `err == nil && !isStructuredToolError(result)`。`isStructuredToolError` は結果 JSON を
`{"error": string}` として unmarshal でき、かつ `error` が非空のときに true
(claude_managed_agents/cmd/devui/conversation.go:677 / :761)。

`tool_start.label` の値 (claude_managed_agents/cmd/devui/conversation.go:772):
`list_assets`=アセット一覧を取得中 / `load_asset`=アセット情報を読み込み中 / `research_market`=市場調査を実行中 /
`deep_dive`=裏付けを検証中 / `generate_ideas`=アイデアを生成中 / `generate_plan`=企画書を生成中 /
`record_rejection`=見送りを記録中 / `set_theme_name`=テーマ名を設定中 / `match_functions`=マッチングを評価中。
未知ツール名はツール名そのまま。

#### 1.3 `artifact` の kind 別 payload 形状 (6 種)

| kind | payload 形状 | 備考 | 出典 |
|---|---|---|---|
| `ideas` | `{"kind":"ideas","payload":{session_id, theme_id?, generated_at, count, ideas:[{idea_id,num,title,summary,score,grade,pattern?,competition_density?,competitors?}], note?}}` | payload = ツール結果 JSON と同一 | claude_managed_agents/cmd/devui/conversation.go:606 / claude_managed_agents/cmd/devui/conversation_tools_generate.go:255 |
| `plan` | `{"kind":"plan","payload":{idea_title, generated_at, version, theme_id?, idea_num?, service, hassan_v2?, summary, pestel, market, competitor, tech, legal, sources_by_tab?}}` | `bmc` タブは `hassan_v2` キーで運ぶ | claude_managed_agents/cmd/devui/conversation.go:630 / claude_managed_agents/cmd/devui/conversation_tools_plan.go:215 |
| `matching` | `{"kind":"matching","payload":{"pairs":[{rank:int,function_name,domain_name,score:float,rationale?}]}}` | payload = ツール結果 JSON と同一 | claude_managed_agents/cmd/devui/conversation.go:659 / claude_managed_agents/cmd/devui/conversation_tools_matching.go:84 |
| `research` | `{"kind":"research","pattern":string,"payload":{title, rows:[{name, summary, source_urls:[{url,title,kind?}], confidence?, hype_warning?, market_size?, cagr?, social_issue?, customer_pain?}]}}` | **`pattern` は payload の sibling** (additive) | claude_managed_agents/cmd/devui/conversation.go:687 / claude_managed_agents/cmd/devui/conversation_tools_research.go:26 |
| `deepdive` | `{"kind":"deepdive","payload":{title, pattern, target, confidence, notes:[string], source_urls:[{url,title,kind?}], details?}}` | `details` は LLM 応答オブジェクト全体のパススルー | claude_managed_agents/cmd/devui/conversation.go:692 / claude_managed_agents/cmd/devui/conversation_tools_deepdive.go:168 |
| `asset` | `{"kind":"asset","name":string,"function_tree":[FunctionTreeL1]}` — **`payload` ラッパを持たない**。他 5 種と形が違う | `function_tree` が nil のときは空配列にする | claude_managed_agents/cmd/devui/conversation.go:705 |

`set_theme_name` と `record_rejection` は artifact を出さない
(claude_managed_agents/cmd/devui/conversation.go:641 / :711)。

#### 1.4 `stream.Processor` → bridge → FE の変換

1. `session.RunWithOptions` に渡す `out io.Writer` は `sseConversationBridge`
   (claude_managed_agents/cmd/devui/conversation.go:428 / :826)。
2. `stream.Processor.Handle` は agent メッセージを `[agent] <text>\n` の行として書く。1 content block = 1 行
   (claude_managed_agents/internal/stream/processor.go:96)。テキストが複数段落を含む場合、
   2 行目以降はプレフィックスなしの継続行として届く。
3. Processor が出す agent 以外の行は必ず既知プレフィックスを持つ:
   `[status]` `[span]` `[tool:` `[tool_end:` `[tool_result]` `[mcp_tool:` `[mcp_tool_result]`
   `[mcp_tool_end:` `[custom_tool:` `[ref]` `[stream]` `[user]`
   (claude_managed_agents/internal/stream/processor.go:52 / 列挙は claude_managed_agents/cmd/devui/conversation_stream.go:58)。
4. bridge の `flushLine` の判定 (除外リスト方式 / claude_managed_agents/cmd/devui/conversation_stream.go:121):
   - `[agent] ` プレフィックス行 → `inAgent=true`、本文 + `"\n"` を `message_delta`。**本文が空文字のときは送らない**
   - 既知プレフィックス行 → `inAgent=false` にして破棄
   - それ以外 (空行を含む) → `inAgent==true` のとき本文として `message_delta`。**空行はリセットしない**
     (2026-07-04 のアセット一覧欠落バグの回帰防止)
5. `<options>` / `<questions>` / `<domain_select>` / `<divergence_design>` / `<idea_input>` / `<turn type=".."/>`
   といったタグは**素通し**され、FE が `message_delta` の text を結合してパースする
   (claude_managed_agents/cmd/devui/conversation_stream.go:14 / タグ仕様は claude_managed_agents/prompts/conversational_orchestrator_system.md:252)。
6. `custom_tool_use` は Processor が `[custom_tool:*]` 行を出すだけで tool_end 行を持たないため、
   ツール進捗は bridge ではなく **dispatch ラッパ (`wrapDispatchWithSSE`)** が emit する
   (claude_managed_agents/cmd/devui/conversation_stream.go:16 / claude_managed_agents/cmd/devui/conversation.go:589)。
7. `bridge.Close()` は改行未到達の残バッファを 1 行として flush する。ハンドラは `error`/`done` の**前**に呼ぶ
   (claude_managed_agents/cmd/devui/conversation.go:477 / claude_managed_agents/cmd/devui/conversation_stream.go:97)。

#### 1.5 順序契約 (テストが仕様の出典)

| 契約 | 出典 (実装) | 出典 (テスト) |
|---|---|---|
| `session` が先頭・`done` が末尾 (異常時も) | claude_managed_agents/cmd/devui/conversation.go:380 / :484 | claude_managed_agents/cmd/devui/conversation_test.go:776 |
| `generate_ideas`: `tool_start` → `generate_progress`* (step 昇順) → `artifact(ideas)` → `tool_end` | claude_managed_agents/cmd/devui/conversation.go:594 | claude_managed_agents/cmd/devui/conversation_generate_stream_test.go:44 |
| `artifact.kind == "ideas"` | claude_managed_agents/cmd/devui/conversation.go:606 | claude_managed_agents/cmd/devui/conversation_generate_stream_test.go:104 |
| `generate_plan`: `tool_start` → `plan_progress`* (done_count 昇順) → `artifact(plan)` → `tool_end` | claude_managed_agents/cmd/devui/conversation.go:616 | claude_managed_agents/cmd/devui/conversation_plan_stream_test.go |
| マルチライン `[agent]` ブロック全行 + 空行 + 末尾タグが欠落せず届く | claude_managed_agents/cmd/devui/conversation_stream.go:121 | claude_managed_agents/cmd/devui/conversation_stream_test.go:93 / :133 |
| 既知プレフィックス行は `message_delta` に混ざらない | claude_managed_agents/cmd/devui/conversation_stream.go:132 | claude_managed_agents/cmd/devui/conversation_stream_test.go:172 |
| ツール成功時に `tool_start`/`tool_end`/`artifact` が揃う | claude_managed_agents/cmd/devui/conversation.go:681 | claude_managed_agents/cmd/devui/conversation_test.go:840 |
| `artifact(research)` の `pattern` sibling + payload 不変 | claude_managed_agents/cmd/devui/conversation.go:687 | claude_managed_agents/cmd/devui/conversation_test.go:884 |
| `artifact(asset)` は `{kind,name,function_tree}` 形状 | claude_managed_agents/cmd/devui/conversation.go:705 | claude_managed_agents/cmd/devui/conversation_test.go:949 |
| 復旧 (pending tool) 成功時は `error` を出さず契約不変 | claude_managed_agents/cmd/devui/conversation.go:464 | claude_managed_agents/cmd/devui/conversation_test.go:726 |

---

### 2. 台帳 (`ConversationLedger`) — 全 13 フィールドの読み書き経路

型定義は claude_managed_agents/internal/db/conversation_store.go:148 (`conversation_sessions.ledger` JSONB に格納)。

| # | フィールド (JSON タグ) | 型 | 書き込み経路 | 読み出し経路 |
|---|---|---|---|---|
| 1 | `Entrypoint` (`entrypoint`) | string | **なし** — 非テストコードに代入が存在しない (テストと型定義のみ) | **なし** |
| 2 | `Theme` (`theme`) | string | `mergeArgsIntoLedger` = `generate_ideas` の `theme` 引数 (claude_managed_agents/cmd/devui/conversation_tools_generate.go:185)。永続化は claude_managed_agents/cmd/devui/conversation_tools_generate.go:144 | 前提チェック (claude_managed_agents/cmd/devui/conversation_tools_generate.go:403) / テーマ文字列組み立て (:421) / `generate_plan` の theme フォールバック (claude_managed_agents/cmd/devui/conversation_tools_plan.go:161) / `display_title` 導出 (claude_managed_agents/internal/db/conversation_store.go:216) |
| 3 | `AssetDefinition` (`asset_definition`) | `*AssetDefinitionLedger` | (a) `load_asset` 成功時 `setAssetDefinitionFromLoadAsset` (claude_managed_agents/cmd/devui/conversation.go:696 / claude_managed_agents/cmd/devui/conversation_ledger.go:124)。(b) `generate_ideas` の `asset_name`/`asset_summary` (claude_managed_agents/cmd/devui/conversation_tools_generate.go:189) | `deep_dive` の `asset_context` 生成 (claude_managed_agents/cmd/devui/conversation_tools_deepdive.go:360) / `match_functions` の機能フラット化 (claude_managed_agents/cmd/devui/conversation_tools_matching.go:222) / 前提チェック / 発散入力 / `display_title` / `copyLedgerPremise` |
| 3a | ↳ `FunctionTree` (`function_tree`) | `[]FunctionTreeL1` | `parseAssetDefinitionLedgerEntry` (= `load_asset` 経路) のみ (claude_managed_agents/cmd/devui/conversation_ledger.go:138)。(b) 経路は既存値を保持する (claude_managed_agents/cmd/devui/conversation_tools_generate.go:226) | `flattenMatchFunctions` (claude_managed_agents/cmd/devui/conversation_tools_matching.go:222) のみ |
| 4 | `Approach` (`approach`) | string | `mergeArgsIntoLedger` = `generate_ideas` の `approach` 引数 (claude_managed_agents/cmd/devui/conversation_tools_generate.go:218) | 発散 pattern 解決 (claude_managed_agents/cmd/devui/conversation_tools_generate.go:312) / 前提チェック (:400) / 発散入力 (:455) / テーマ組み立て (:439) / `copyLedgerPremise` |
| 5 | `Constraints` (`constraints`) | `[]string` | `mergeArgsIntoLedger` = `generate_ideas` の `constraints` 引数 (claude_managed_agents/cmd/devui/conversation_tools_generate.go:206) | 発散入力 (claude_managed_agents/cmd/devui/conversation_tools_generate.go:474) / `copyLedgerPremise` |
| 6 | `Interests` (`interests`) | `[]string` | **なし** — `copyLedgerPremise` の深いコピー (claude_managed_agents/cmd/devui/conversation_ledger.go:433) 以外に代入が存在しない | 前提チェックの「文脈」条件 (claude_managed_agents/cmd/devui/conversation_tools_generate.go:400) / 発散入力の【関心】ブロック (:471) |
| 7 | `SelectedDomains` (`selected_domains`) | `[]SelectedDomainLedger` | (a) HTTP body の `selected_domains` → `setSelectedDomains` (**上書き** / claude_managed_agents/cmd/devui/conversation.go:401 / claude_managed_agents/cmd/devui/conversation_ledger.go:105)。(b) `generate_ideas` の `domains` 引数 → `mergeArgsIntoLedger` (**上書き・Name のみ** / claude_managed_agents/cmd/devui/conversation_tools_generate.go:194) | `match_functions` の領域選択 (claude_managed_agents/cmd/devui/conversation_tools_matching.go:264) / 前提チェック / 発散入力 / テーマ組み立て / `display_title` / `stage` 導出 |
| 7a | ↳ `Rationale` (`rationale`) | string | **(a) 経路のみ**。(b) 経路は Name だけを書くため Rationale が消える | 発散入力 (claude_managed_agents/cmd/devui/conversation_tools_generate.go:465) / `match_functions` の Summary 代用 (claude_managed_agents/cmd/devui/conversation_tools_matching.go:270) |
| 8 | `ResearchedDomains` (`researched_domains`) | `[]ResearchedDomainLedger` | `research_market` 成功時 `appendResearchMarket` (**追記** / claude_managed_agents/cmd/devui/conversation.go:690 / claude_managed_agents/cmd/devui/conversation_ledger.go:466) | 発散入力の【市場調査の知見】ブロック (claude_managed_agents/cmd/devui/conversation_tools_generate.go:495) / `match_functions` の領域フォールバック (claude_managed_agents/cmd/devui/conversation_tools_matching.go:273) / `stage` 導出 |
| 8a | ↳ `SourceURLs` (`source_urls`) | `[]SourceURLLedger` | `parseResearchMarketLedgerEntries` (claude_managed_agents/cmd/devui/conversation_ledger.go:541) | **Go 側に読み出しなし** (GET `/api/conversations/{id}` で FE へ出るのみ) |
| 8b | ↳ `Pattern` / `ResearchedAt` | string | ツール引数由来 / 追記時に Go が RFC3339 を設定 (claude_managed_agents/cmd/devui/conversation_ledger.go:471) | **Go 側に読み出しなし** |
| 9 | `DeepDiveResults` (`deep_dive_results`) | `[]DeepDiveResultLedger` | `deep_dive` 成功時 `appendDeepDive` (**追記** / claude_managed_agents/cmd/devui/conversation.go:693 / claude_managed_agents/cmd/devui/conversation_ledger.go:35) | `generate_plan` の grounding 還流 `mergeDeepDiveIntoGrounding` (claude_managed_agents/cmd/devui/conversation_tools_plan.go:169) |
| 9a | ↳ `SummaryRaw` (`summary_raw`) | `json.RawMessage` | `deep_dive` のツール結果 JSON 全文 (claude_managed_agents/cmd/devui/conversation_ledger.go:596) | `formatDeepDiveReflowLine` (claude_managed_agents/cmd/devui/conversation_plan_grounding.go:109) — **キー不一致あり (§3.3-(a))** |
| 9b | ↳ `Target` (`target`) | string | `parseDeepDiveLedgerEntry` (claude_managed_agents/cmd/devui/conversation_ledger.go:593) | **Go 側に読み出しなし** (`.Target` の grep で本番読み出しは `deep_dive` ハンドラのツール引数のみ) |
| 10 | `GeneratedIdeas` (`generated_ideas`) | `[]GeneratedIdeasLedger` | `artifact(ideas)` から `appendGeneratedIdeasFromArtifact` (**追記** / claude_managed_agents/cmd/devui/conversation.go:607 / claude_managed_agents/cmd/devui/conversation_ledger.go:184) | `generate_plan` の最新エントリ解決 (claude_managed_agents/cmd/devui/conversation_tools_plan.go:128) / `stage` 導出 |
| 11 | `GeneratedPlans` (`generated_plans`) | `[]GeneratedPlanLedger` | `artifact(plan)` から `appendGeneratedPlan` (**追記** / claude_managed_agents/cmd/devui/conversation.go:632 / claude_managed_agents/cmd/devui/conversation_ledger.go:257) | `stage` 導出 (claude_managed_agents/internal/db/conversation_store.go:251) のみ |
| 12 | `RejectedCandidates` (`rejected_candidates`) | `[]RejectedCandidateLedger` | `record_rejection` 成功時 `appendRejectedCandidate` (**追記** / claude_managed_agents/cmd/devui/conversation.go:714 / claude_managed_agents/cmd/devui/conversation_ledger.go:297) | `copyLedgerPremise` (claude_managed_agents/cmd/devui/conversation_ledger.go:434) のみ。ツール入力・プロンプトへ戻す経路は未発見 |
| 12a | ↳ `Confidence` (`confidence`) | string | **なし** — `record_rejection` の結果 JSON に `confidence` が無く、`parseRejectedCandidateLedgerEntry` も parse しない (claude_managed_agents/cmd/devui/conversation_tools_rejection.go:48 / claude_managed_agents/cmd/devui/conversation_ledger.go:341) | なし |
| 13 | `Matching` (`matching`) | `*MatchingLedger` | `match_functions` 成功時 `appendMatching` (**全置換** / claude_managed_agents/cmd/devui/conversation.go:660 / claude_managed_agents/cmd/devui/conversation_ledger.go:370) | `stage` 導出 (claude_managed_agents/internal/db/conversation_store.go:257) のみ |

#### 2.1 書き込み経路が無いフィールド (BE-10 の観点)

| フィールド | 状況 |
|---|---|
| `ConversationLedger.Entrypoint` | 書き込み・読み出しの**両方**が非テストコードに存在しない。型定義とテストのみ (claude_managed_agents/internal/db/conversation_store.go:150) |
| `ConversationLedger.Interests` | **読み出しが 2 箇所ある (前提チェック / 発散入力) のに書き込み経路が無い**。tool schema にも `interests` 引数は無い (claude_managed_agents/cmd/update-agent-prompt/main.go:384)。結果として「前提チェックの文脈条件を Interests で満たす」経路が実現不能 |
| `RejectedCandidateLedger.Confidence` | 書き込み経路が無く常に空。schema にも `confidence` 引数は無い (claude_managed_agents/cmd/update-agent-prompt/main.go:445) |
| `DeepDiveResultLedger.Target` | 書き込みはあるが Go 側の読み出しが無い (FE 経由の表示専用と思われる) |
| `ResearchedDomainLedger.SourceURLs` / `Pattern` / `ResearchedAt` | 書き込みはあるが Go 側の読み出しが無い。発散入力への注入は `social_issue`/`customer_pain`/`market_size`/`cagr` の 4 つのみ (claude_managed_agents/cmd/devui/conversation_tools_generate.go:517) |

#### 2.2 台帳の保存セマンティクス

- 保存は 2 系統ある。(i) `appendXxx` 系 = 自前で `Get` → append → `Upsert` (`ManagedSessionID` を読み直して渡す /
  claude_managed_agents/cmd/devui/conversation_ledger.go:41)。(ii) `getLedger` → `saveLedger` 系
  (`setSelectedDomains` / `setAssetDefinitionFromLoadAsset` / `appendMatching` / `generate_ideas` の引数マージ /
  claude_managed_agents/cmd/devui/conversation_ledger.go:79)。いずれも**トランザクション無しの read-modify-write**。
- `Upsert` は `ledger` を**全置換**、`updated_at` は常に `NOW()`。`theme_id` は空文字のとき NULL を書き、
  `ON CONFLICT` 側で `COALESCE(EXCLUDED.theme_id, conversation_sessions.theme_id)` により既存値を維持する
  (claude_managed_agents/internal/db/conversation_store.go:406)。
- 保存失敗はすべて `log.Printf` のみで、SSE には出さず session を落とさない
  (claude_managed_agents/cmd/devui/conversation_ledger.go:45 など)。

---

### 3. 9 tools の 3 者整合 (tool schema / Go handler / system prompt)

- **tool schema の唯一の定義箇所** = `conversationToolDefs()`
  (claude_managed_agents/cmd/update-agent-prompt/main.go:280)。`update-agent-prompt -conversation-tools` で
  Managed Agent に登録・全置換される (claude_managed_agents/cmd/update-agent-prompt/main.go:215)。
- **handler** = registry (claude_managed_agents/cmd/devui/conversation_tools.go:27) または
  `wrapDispatchWithSSE` の専用分岐 (claude_managed_agents/cmd/devui/conversation.go:589)。
- **system prompt** = claude_managed_agents/prompts/conversational_orchestrator_system.md

#### 3.1 引数の 3 者対照表

| tool | schema (引数: 型 / required) | handler がパースする JSON タグ | prompt の記載 | 一致 |
|---|---|---|---|---|
| `list_assets` | (引数なし。`properties:{}` / `required:[]`) — claude_managed_agents/cmd/update-agent-prompt/main.go:288 | 入力を一切読まない — claude_managed_agents/cmd/devui/conversation_tools_asset.go:99 | 「引数は不要」「補助用途のみ」 — claude_managed_agents/prompts/conversational_orchestrator_system.md:319 | 一致 |
| `load_asset` | `asset_id`: integer / **required** — claude_managed_agents/cmd/update-agent-prompt/main.go:299 | `asset_id` (`*int64`。nil で構造化エラー) — claude_managed_agents/cmd/devui/conversation_tools_asset.go:127 | 「指定した `asset_id` のアセット登録情報」 — claude_managed_agents/prompts/conversational_orchestrator_system.md:320 | 一致 |
| `set_theme_name` | `name`: string / **required** — claude_managed_agents/cmd/update-agent-prompt/main.go:316 | `name` (`SetThemeNameArgKey = "name"`) — claude_managed_agents/cmd/devui/conversation_tools_theme.go:28 / :35 | 「20 字程度」 — claude_managed_agents/prompts/conversational_orchestrator_system.md:322 | 引数名は一致 / **文字数上限に差 (§3.3-(d))** |
| `research_market` | `query`: string / **required**、`pattern`: string enum[`domain`,`trend`] / **required**、`industry_mode`: string enum[`cross_industry`,`balanced`,`intra_industry_novel`] / 任意 — claude_managed_agents/cmd/update-agent-prompt/main.go:333 | `query` / `pattern` / `industry_mode` — claude_managed_agents/cmd/devui/conversation_tools_research.go:433 | 同 3 引数 + 既定 `balanced` — claude_managed_agents/prompts/conversational_orchestrator_system.md:328 | 一致 |
| `deep_dive` | `pattern`: string enum[`credibility`,`competition`,`momentum`,`demand`,`counterevidence`,`problem_structure`] / **required**、`target`: string / **required** — claude_managed_agents/cmd/update-agent-prompt/main.go:360 | `pattern` / `target` / **`asset_context` (schema 未宣言)** — claude_managed_agents/cmd/devui/conversation_tools_deepdive.go:195 | 6 パターン + target のみ。`asset_context` の記載なし — claude_managed_agents/prompts/conversational_orchestrator_system.md:341 | **不一致 (§3.3-(a))** |
| `generate_ideas` | `theme`: string / **required**、`asset_name` / `asset_summary` / `focus`: string 任意、`domains` / `constraints`: string[] 任意、`approach`: string enum[`domain`,`trend`,`usage`,`spec`] 任意 — claude_managed_agents/cmd/update-agent-prompt/main.go:382 | `theme` / `asset_name` / `asset_summary` / `domains` / `constraints` / `approach` / `focus` — claude_managed_agents/cmd/devui/conversation_tools_generate.go:170 | 同 7 引数を明示列挙 — claude_managed_agents/prompts/conversational_orchestrator_system.md:161 | 一致 |
| `generate_plan` | `idea_num`: string / 任意 (`required:[]`) — claude_managed_agents/cmd/update-agent-prompt/main.go:426 | `idea_num` — claude_managed_agents/cmd/devui/conversation_tools_plan.go:38 | 「`idea_num` (任意)」「engine は選ばせない」 — claude_managed_agents/prompts/conversational_orchestrator_system.md:193 | 一致 |
| `record_rejection` | `name`: string / **required**、`reason`: string / **required**、`sources`: string[] / 任意 — claude_managed_agents/cmd/update-agent-prompt/main.go:443 | `name` / `reason` / `sources` — claude_managed_agents/cmd/devui/conversation_tools_rejection.go:20 | 同 3 引数 — claude_managed_agents/prompts/conversational_orchestrator_system.md:359 | 引数は一致 / **台帳側に書けない `confidence` がある (§2.1)** |
| `match_functions` | `domains`: string[] 任意、`focus`: string 任意 (`required:[]`) — claude_managed_agents/cmd/update-agent-prompt/main.go:469 | `domains` / `focus` — claude_managed_agents/cmd/devui/conversation_tools_matching.go:63 | 同 2 引数 + 「ゼロベース起点では呼ばない」 — claude_managed_agents/prompts/conversational_orchestrator_system.md:334 | 一致 |

#### 3.2 出力 (ツール結果 JSON) の形

| tool | 結果 JSON | 出典 |
|---|---|---|
| `list_assets` | `{"assets":[{id,name,summary,category?,maturity?}]}` — 最大 50 件 | claude_managed_agents/cmd/devui/conversation_tools_asset.go:111 / 上限は :56 |
| `load_asset` | `{id,name,summary,elements,source_url?,category_code?,specs?,function_tree?}` | claude_managed_agents/cmd/devui/conversation_tools_asset.go:25 |
| `set_theme_name` | `{"theme_id":string,"name":string}` | claude_managed_agents/cmd/devui/conversation_tools_theme.go:40 |
| `research_market` | `{"title":string,"rows":[researchDomainRow]}` | claude_managed_agents/cmd/devui/conversation_tools_research.go:92 |
| `deep_dive` | `{title,pattern,target,confidence,notes:[],source_urls:[],details?}` | claude_managed_agents/cmd/devui/conversation_tools_deepdive.go:168 |
| `generate_ideas` | `{session_id,theme_id?,generated_at,count,ideas:[],note?}` (= artifact payload) | claude_managed_agents/cmd/devui/conversation_tools_generate.go:255 |
| `generate_plan` | `{generated:true,idea_num?,idea_title,tab_count,tab_errors?,note?}` (artifact とは**別形状**) | claude_managed_agents/cmd/devui/conversation_tools_plan.go:281 |
| `record_rejection` | `{name,reason,sources}` (正規化のみ。台帳追記は dispatch ラッパ側) | claude_managed_agents/cmd/devui/conversation_tools_rejection.go:48 |
| `match_functions` | `{"pairs":[{rank,function_name,domain_name,score,rationale?}]}` — 上位 8 件・score は [0,5] クランプ + 小数第 1 位 | claude_managed_agents/cmd/devui/conversation_tools_matching.go:84 / :369 / :406 |
| 未登録ツール名 | `{"error":"未対応のツール","name":"<名前>"}` | claude_managed_agents/cmd/devui/conversation_tools.go:96 |

#### 3.3 3 者不一致・要注意点 (BE-8)

- **(a) `deep_dive.asset_context` が schema・prompt に無い** — handler は
  `asset_context` (string) をパースし LLM プロンプトへ含める
  (claude_managed_agents/cmd/devui/conversation_tools_deepdive.go:197 / :241)。
  schema には `pattern`/`target` しか宣言されておらず (claude_managed_agents/cmd/update-agent-prompt/main.go:362)、
  prompt にも記載が無い。サーバが台帳 `AssetDefinition` から `input["asset_context"]` に**注入**して補う設計
  (claude_managed_agents/cmd/devui/conversation.go:671 / :741)。コメント上は意図的だが、
  「Agent が渡せない引数を handler が読む」という 3 者の非対称が現に存在する。
- **(b) `deep_dive` の SummaryRaw 読み出しキーが書き手と一致しない** — 書き手の結果 JSON
  (`deepDiveToolResult`) は `title` / `pattern` / `target` / `confidence` / `notes` (**配列**) / `source_urls` / `details`
  (claude_managed_agents/cmd/devui/conversation_tools_deepdive.go:168)。一方 grounding 還流の読み手
  `deepDiveSummaryFields` は `finding` (string) / `notes` (**string**) / `title` を期待する
  (claude_managed_agents/cmd/devui/conversation_plan_grounding.go:100)。`finding` はどのプロンプトにも無く
  (deep_dive プロンプトの出力キーは `findings` の**配列** / claude_managed_agents/prompts/conversational/deepdive_credibility.md:19)、
  `notes` は型不一致。テストは合成 JSON `{"finding":...,"notes":"..."}` を渡しているため検出されていない
  (claude_managed_agents/cmd/devui/conversation_plan_grounding_test.go:32)。
- **(c) ツール本数の記述がコード内で食い違う** — フラグのヘルプは「custom tools **8 本**」で
  `match_functions` を含まない列挙 (claude_managed_agents/cmd/update-agent-prompt/main.go:67。
  同じ 8 本列挙が :513 と :536 のコメントにもある)。実際に `conversationToolDefs()` が返すのは **9 本**
  (claude_managed_agents/cmd/update-agent-prompt/main.go:280)、dry-run 表示の `conversationToolNote` は 9 本列挙
  (:275)。また registry のコメントは「3 ツール」と書きつつ 4 ツールを列挙している
  (claude_managed_agents/cmd/devui/conversation_tools.go:21)。
- **(d) `set_theme_name` の文字数上限が 3 者で異なる** — schema/prompt は「20 字程度」
  (claude_managed_agents/cmd/update-agent-prompt/main.go:323 / claude_managed_agents/prompts/conversational_orchestrator_system.md:323)、
  handler のクランプは **60 rune** (claude_managed_agents/cmd/devui/conversation_tools_theme.go:32)。
- **(e) `industry_mode` は実質 `cross_industry` のみが挙動を変える** — schema は 3 値の enum だが、
  handler は未知値もそのまま `searchDomain` に渡し、`cross_industry` 以外は空の接尾辞になる
  (claude_managed_agents/cmd/devui/conversation_tools_research.go:125)。`pattern="trend"` のときは
  `searchTrend` が `industryMode` を受け取らないため完全に無視される
  (claude_managed_agents/cmd/devui/conversation_tools_research.go:466)。schema の description は
  「domain 軸の検索にのみ反映する」と明記しており、この点は整合。
- **(f) `generate_ideas.focus` は台帳に保存されない** — 発散 userInput の末尾に
  「【絞り込み】」として追記されるだけ (claude_managed_agents/cmd/devui/conversation_tools_generate.go:306)。
  schema の description も「台帳には保存せず」と明記 (claude_managed_agents/cmd/update-agent-prompt/main.go:416) → 整合。
- **(g) `approach` の値域は 3 者一致** — schema enum は `domain`/`trend`/`usage`/`spec`
  (claude_managed_agents/cmd/update-agent-prompt/main.go:412)、handler は `diverge.IsValidPattern`
  (空文字 + 同 4 値を許可 / claude_managed_agents/internal/agent/diverge/pattern.go:26) を通す。
- **(h) `generate_plan` / `set_theme_name` / `match_functions` は registry にフォールバックが登録済み** —
  deps が nil (DB/API キー未接続) のとき「〜は現在利用できません (依存が未初期化です)」を返す
  (claude_managed_agents/cmd/devui/conversation_tools.go:56 / :62 / :69)。
  **`generate_ideas` だけ registry に登録が無い**ため、`genFn` が nil のときは
  「未対応のツール」エラーになる (claude_managed_agents/cmd/devui/conversation_tools.go:47 の一覧に不在)。

---

### 4. エラー時の挙動

#### 4.1 SSE 開始前 (通常の HTTP エラー / ボディは `{"message": string}`)

| 条件 | ステータス | 本文 | 出典 |
|---|---|---|---|
| POST 以外 | 405 | `method not allowed` (`http.Error` = text/plain) | claude_managed_agents/cmd/devui/conversation.go:329 |
| `ORCHESTRATOR_AGENT_ID` 未設定 | **503** | 「`ORCHESTRATOR_AGENT_ID` が `.env` に未設定です。…」 | claude_managed_agents/cmd/devui/conversation.go:335 (テスト claude_managed_agents/cmd/devui/conversation_test.go:820) |
| JSON decode 失敗 (32 KiB 超もここに落ちる) | 400 | `invalid json: <err>` | claude_managed_agents/cmd/devui/conversation.go:340 |
| `message` 空 (TrimSpace 後) | 400 | `message required` | claude_managed_agents/cmd/devui/conversation.go:347 (テスト :1075) |
| `ResponseWriter` が Flusher でない | 500 | `streaming unsupported` | claude_managed_agents/cmd/devui/conversation.go:363 |

#### 4.2 SSE 開始後 (すべて 200 + `error` → `done`。session は落とさない)

| 事象 | FE に返るもの | 出典 |
|---|---|---|
| runner が error を返した | `error {"message": runErr.Error()}` → `done` | claude_managed_agents/cmd/devui/conversation.go:478 |
| `ANTHROPIC_API_KEY` / `ENVIRONMENT_ID` / `ORCHESTRATOR_AGENT_ID` 未設定 (runner 内) | 同上 (日本語の診断文言が `error.message` に入る) | claude_managed_agents/cmd/devui/conversation.go:808 |
| ツールレベルの失敗 | `tool_end {ok:false}` のみ。**artifact は出さず台帳にも書かない**。Agent には構造化エラー JSON `{"error":…, "missing"?:[…]}` が `custom_tool_result` で返る | claude_managed_agents/cmd/devui/conversation.go:677 / claude_managed_agents/cmd/devui/conversation_tools.go:109 |
| dispatch が Go の error を返した場合 (現行 handler は返さない設計) | `{"error":"<err>","name":"<tool>"}` に包んで `custom_tool_result` へ | claude_managed_agents/internal/session/customtool.go:41 |
| 台帳保存失敗 / テーマ作成失敗 / plan_tab_versions 保存失敗 | **SSE には出ない** (`log.Printf` のみ) | claude_managed_agents/cmd/devui/conversation_ledger.go:45 / claude_managed_agents/cmd/devui/conversation.go:216 / claude_managed_agents/cmd/devui/conversation_tools_plan.go:343 |

#### 4.3 LLM 側の失敗

| 事象 | 挙動 | 出典 |
|---|---|---|
| `research_market` の LLM 応答 JSON パース失敗 | **エラーにしない**。Exa 検索結果のタイトルをそのまま領域名にするフォールバック → `tool_end.ok=true` で artifact も出る | claude_managed_agents/cmd/devui/conversation_tools_research.go:227 (domain) / :377 (trend) |
| `deep_dive` の JSON 抽出/unmarshal 失敗 | `{"error":"LLM 応答 JSON パースエラー: …"}` / `{"error":"LLM 応答 unmarshal エラー: …"}` | claude_managed_agents/cmd/devui/conversation_tools_deepdive.go:255 |
| `match_functions` の抽出/parse 失敗・pairs 0 件 | `{"error":"マッチング評価結果の解析に失敗しました: …"}` / `{"error":"マッチング評価結果が空でした"}` | claude_managed_agents/cmd/devui/conversation_tools_matching.go:191 |
| `generate_ideas` 委譲先の応答解析失敗 | `{"error":"アイデア生成に失敗しました: managed 発散の応答解析に失敗しました: …"}` | claude_managed_agents/cmd/devui/conversation_tools_generate.go:102 / :332 |
| `max_tokens` 切り詰め | `StopReason == max_tokens` を検出して `maxTokensError` → 構造化エラー。**再試行しない**。上限は `research_market` 4096 / `deep_dive` 8192 / `match_functions` 4096 | claude_managed_agents/cmd/devui/conversation_tools_research.go:197 / :344 / :419 / claude_managed_agents/cmd/devui/conversation_tools_deepdive.go:124 / claude_managed_agents/cmd/devui/conversation_tools_matching.go:43 |
| `confidence` が空 (deep_dive) | 「確度不明」に補完。`sources` nil は空配列、`caveats` nil は空配列 | claude_managed_agents/cmd/devui/conversation_tools_deepdive.go:265 |
| Exa グラウンディングなし (EXA 未設定 / 検索失敗 / 0 件) | パラメトリック継続。`notes` 先頭に「ライブ検索なし: …」caveat を挿入 | claude_managed_agents/cmd/devui/conversation_tools_deepdive.go:180 / :283 |

#### 4.4 タイムアウト

- ハンドラ・ツールに**独自のタイムアウトは無い**。`http.Server` も `ReadTimeout` / `WriteTimeout` /
  `IdleTimeout` を設定していない (claude_managed_agents/cmd/devui/main.go:634 は `&http.Server{Addr, Handler}` のみ)。
- 実質の打ち切りは `r.Context()` のキャンセル (クライアント切断) のみ。`RunWithOptions` は `ctx.Done()` で
  best-effort interrupt を送って `ctx.Err()` を返す (claude_managed_agents/internal/session/run.go:199)。
  `custom_tool_result` の Send 失敗時も同様に interrupt を送る (claude_managed_agents/internal/session/run.go:176)。
  interrupt は `context.Background()` + 5 秒固定 timeout (claude_managed_agents/internal/session/interrupt.go:13 / :41)。
- proxy / browser のアイドル切断対策として 30 秒間隔の SSE コメントを流す
  (claude_managed_agents/cmd/devui/conversation.go:374 / claude_managed_agents/cmd/devui/sse_keepalive.go:14)。

#### 4.5 archived session の自動リトライ

- 判定は `isArchivedSessionErr` = `"archived session"` または `"Cannot send events to archived"` の contains
  (claude_managed_agents/cmd/devui/diverge_managed.go:1337)。
- `reuseManagedSessionID != ""` かつ archived のとき、map から削除して **`reuseID=""` で 1 回だけ**再実行
  (claude_managed_agents/cmd/devui/conversation.go:458。テスト claude_managed_agents/cmd/devui/conversation_test.go:440)。
- 再実行後も archived なら map を削除して `error` → `done` (claude_managed_agents/cmd/devui/conversation.go:478)。

#### 4.6 pending tool の復旧 (`conversation-pending-tool-recovery`)

- 判定は `isPendingToolResponseErr` = `"waiting on responses to events"` の contains (多段ラップ対応)
  (claude_managed_agents/cmd/devui/conversation.go:510。テスト claude_managed_agents/cmd/devui/conversation_test.go:488)。
- `reuseManagedSessionID != ""` かつ該当のとき、`conversationInterrupt` (= `session.SendInterrupt`) を **1 回**送り、
  **成功時のみ同一 `reuseManagedSessionID`** で 1 回だけ再実行する。map / DB は掃除しない (会話履歴を継続利用するため)
  (claude_managed_agents/cmd/devui/conversation.go:464 / :525。テスト :528)。
- interrupt 自体が失敗したら**再送しない**で `error` → `done` (テスト claude_managed_agents/cmd/devui/conversation_test.go:591)。
- 再送も失敗したら `error` → `done` (テスト :645)。
- `reuseManagedSessionID == ""` (新規セッション) のときは復旧分岐に入らない (テスト :693)。
- 復旧成功時の SSE 契約は不変 (`session` 先頭 / `error` 無し / `done` 末尾。テスト :726)。
- **分岐順序**: archived 判定が `if`、pending 判定が `else if` なので、両方の文言を含むエラーは
  archived 扱いになる (claude_managed_agents/cmd/devui/conversation.go:458)。

---

### 5. セッションの永続化と再開

#### 5.1 `conversation_sessions` テーブル

| カラム | 型 | NULL | 既定 | 出典 |
|---|---|---|---|---|
| `id` | TEXT | NOT NULL (PRIMARY KEY) | — | claude_managed_agents/internal/db/migrations/000032_conversation_sessions.up.sql:10 |
| `managed_session_id` | TEXT | NOT NULL | `''` | claude_managed_agents/internal/db/migrations/000032_conversation_sessions.up.sql:11 |
| `ledger` | JSONB | NOT NULL | `'{}'` | claude_managed_agents/internal/db/migrations/000032_conversation_sessions.up.sql:12 |
| `created_at` | TIMESTAMPTZ | NOT NULL | `NOW()` | claude_managed_agents/internal/db/migrations/000032_conversation_sessions.up.sql:13 |
| `updated_at` | TIMESTAMPTZ | NOT NULL | `NOW()` | claude_managed_agents/internal/db/migrations/000032_conversation_sessions.up.sql:14 |
| `theme_id` | TEXT | **NULL 可** | 既定なし (既存行は backfill せず NULL のまま) | claude_managed_agents/internal/db/migrations/000033_conversation_sessions_theme_id.up.sql:8 |

- `theme_id` は `REFERENCES themes(id) ON DELETE SET NULL` (テーマ削除時に会話は残る)。
- 部分インデックス `idx_conversation_sessions_theme_id ON conversation_sessions (theme_id) WHERE theme_id IS NOT NULL`
  (claude_managed_agents/internal/db/migrations/000033_conversation_sessions_theme_id.up.sql:12)。
- Go 側は `theme_id` の NULL を `COALESCE(theme_id, '')` で空文字にマップする
  (claude_managed_agents/internal/db/conversation_store.go:370)。
- **会話メッセージ本文を保存するカラム・テーブルは無い**。`RunWithOptions` に `outputsDir=""` を渡して
  ファイル保存も行わない (claude_managed_agents/cmd/devui/conversation.go:826)。
  会話履歴は Anthropic の Managed Agent session 側にのみ存在する。

#### 5.2 再開時に復元されるもの

| 対象 | 復元経路 | 出典 |
|---|---|---|
| Managed Agent session ID | まず in-memory `conversationSessions` (sync.Map)。ミス時は `ConversationStore.GetManagedSessionID` で DB から読み戻し、map に再登録 | claude_managed_agents/cmd/devui/conversation.go:84 / :407 / :496 / claude_managed_agents/internal/db/conversation_store.go:396 (テスト claude_managed_agents/cmd/devui/conversation_test.go:1096) |
| 台帳 | `conversationLedgerSaver.getLedger` (DB / インメモリ両対応。行なし・失敗時はゼロ値) | claude_managed_agents/cmd/devui/conversation_ledger.go:162 |
| 会話履歴 (発話) | **DB から復元しない**。reuse した Managed Agent session に依存する | claude_managed_agents/cmd/devui/conversation.go:826 |
| 生成アイデア本体 | `diverge_sessions` (台帳には `session_id` などの生成参照のみ) | claude_managed_agents/cmd/devui/conversation_tools_generate.go:563 |
| 企画書 8 タブ本体 | `plan_tab_versions` (theme_id と idea_num が揃うときのみ保存。ver は `NextVer` で採番) | claude_managed_agents/cmd/devui/conversation_tools_plan.go:318 |

#### 5.3 `GET /api/conversations` / `GET /api/conversations/{id}`

| 項目 | 内容 | 出典 |
|---|---|---|
| 一覧のレスポンス | JSON 配列 `[{id, managed_session_id, theme_id, display_title, stage, created_at, updated_at}]`。`theme_id` は空文字でも省略しない | claude_managed_agents/cmd/devui/conversation_list.go:39 / claude_managed_agents/internal/db/conversation_store.go:199 |
| 並び順 / 件数 | `ORDER BY updated_at DESC, id DESC LIMIT $1`。既定 50。`limit <= 0` または `> 100` は 50 にクランプ | claude_managed_agents/internal/db/conversation_store.go:282 |
| `?theme_id=` | `ListByTheme` に切り替え (`WHERE theme_id = $1`)。TrimSpace 後に空なら未指定扱い | claude_managed_agents/cmd/devui/conversation_list.go:55 / claude_managed_agents/internal/db/conversation_store.go:307 |
| DB 未接続時の一覧 | 200 + `[]` | claude_managed_agents/cmd/devui/conversation_list.go:47 |
| 一覧の異常時 | GET 以外 → 405 / store エラー → 500 `internal error` | claude_managed_agents/cmd/devui/conversation_list.go:41 / :63 |
| 単体取得のレスポンス | `{id, managed_session_id, theme_id, ledger, created_at, updated_at}` — `ledger` は `ConversationLedger` をそのまま JSON 化 | claude_managed_agents/cmd/devui/conversation_list.go:82 |
| 日時書式 | `UTC` に変換して `"2006-01-02T15:04:05Z07:00"` (= RFC3339) | claude_managed_agents/cmd/devui/conversation_list.go:127 |
| 単体取得の異常時 | GET 以外 → 405 / DB 未接続・id 空・行なし → 404 `not found` / store エラー → 500 | claude_managed_agents/cmd/devui/conversation_list.go:94 |
| `display_title` の導出 | `Theme` → `AssetDefinition.AssetName` → `SelectedDomains[0].Name` → `「無題の対話 (YYYY-MM-DD HH:MM)」` | claude_managed_agents/internal/db/conversation_store.go:213 |
| `stage` の導出 | `GeneratedPlans` 有 → `plan_draft` / `GeneratedIdeas` 有 → `ideation` / `Matching.Pairs` 非空 → `match` / `SelectedDomains` or `ResearchedDomains` 有 → `market` / それ以外 → `asset` (初期値も `asset`)。`DeepDiveResults` は工程判定に使わない | claude_managed_agents/internal/db/conversation_store.go:250 |

会話の削除・リネーム API は未発見 (main.go に登録されているのは上記 2 ルートのみ /
claude_managed_agents/cmd/devui/main.go:605)。

---

### 6. 1 ターンの処理順序 (関数名 + パス:行)

```
POST /api/conversation
 └─ handleConversation が返す HandlerFunc = makeConversationHandler の戻り値
    conversation.go:148 → conversation.go:326
```

| # | ステップ | 関数 | 出典 |
|---|---|---|---|
| 1 | メソッド判定 (405) | (inline) | claude_managed_agents/cmd/devui/conversation.go:329 |
| 2 | `ORCHESTRATOR_AGENT_ID` 判定 (503) | `writeJSONError` | claude_managed_agents/cmd/devui/conversation.go:335 |
| 3 | ボディ読み取り (32 KiB) + JSON decode (400) | `http.MaxBytesReader` / `json.NewDecoder` | claude_managed_agents/cmd/devui/conversation.go:340 |
| 4 | `message` 必須チェック (400) | (inline) | claude_managed_agents/cmd/devui/conversation.go:347 |
| 5 | `feSessionID` 決定 (空なら `uuid.NewString()`)・新規判定 | (inline) | claude_managed_agents/cmd/devui/conversation.go:353 |
| 6 | SSE writer 構築 + ヘッダ + `WriteHeader(200)` | `sse.NewWriter` | claude_managed_agents/cmd/devui/conversation.go:362 |
| 7 | keep-alive 起動 (30 秒) | `sw.StartKeepAlive` | claude_managed_agents/cmd/devui/conversation.go:374 |
| 8 | **`session` イベント送出** | `sw.Event("session", …)` | claude_managed_agents/cmd/devui/conversation.go:380 |
| 9 | copy-on-create (新規 + `theme_id` 指定時のみ) | `applyConversationCopyOnCreate` → `copyLedgerPremise` → `Upsert` | claude_managed_agents/cmd/devui/conversation.go:387 → :278 → claude_managed_agents/cmd/devui/conversation_ledger.go:425 |
| 10 | テーマ作成 + `theme_id` write-through | `ensureConversationTheme` → `buildThemeCreator` → `ThemeStore.Insert` | claude_managed_agents/cmd/devui/conversation.go:394 → :210 → claude_managed_agents/cmd/devui/conversation_theme_seams.go:31 |
| 11 | `selected_domains` write-through (上書き) | `ledger.setSelectedDomains` | claude_managed_agents/cmd/devui/conversation.go:401 → claude_managed_agents/cmd/devui/conversation_ledger.go:105 |
| 12 | reuse ID 解決 (map → DB) | `conversationSessions.Load` / `rehydrateManagedSessionIDFromDB` | claude_managed_agents/cmd/devui/conversation.go:407 / :496 |
| 13 | bridge 構築 | `newSSEConversationBridge` | claude_managed_agents/cmd/devui/conversation.go:428 → claude_managed_agents/cmd/devui/conversation_stream.go:40 |
| 14 | SSE 専用ツール関数 + dispatch 構築 | `makeGenerateIdeasSSEFunc` / `makeGeneratePlanSSEFunc` / `makeSetThemeNameSSEFunc` / `makeMatchFunctionsSSEFunc` / `wrapDispatchWithSSE(…, buildToolDispatchFunc(reg), …)` | claude_managed_agents/cmd/devui/conversation.go:433 |
| 15 | **runner 実行** | `runner(...)` = `executeConversationViaManagedAgent` | claude_managed_agents/cmd/devui/conversation.go:457 → :799 |
| 15a | 資格情報 / `ENVIRONMENT_ID` / Agent ID 検証 | `config.LoadCredentials` / `config.LoadOrchestratorAgentID` | claude_managed_agents/cmd/devui/conversation.go:808 |
| 15b | Managed Agent 1 ターン実行 | `session.RunWithOptions` | claude_managed_agents/cmd/devui/conversation.go:826 → claude_managed_agents/internal/session/run.go:83 |
| 15c | reuse 空なら Session 新規作成 → `onSessionID` → map 登録 | `client.Beta.Sessions.New` / `onSession` | claude_managed_agents/internal/session/run.go:90 / :103 → claude_managed_agents/cmd/devui/conversation.go:420 |
| 15d | イベントストリーム購読 goroutine 起動 | `Sessions.Events.StreamEvents` + `proc.Handle` | claude_managed_agents/internal/session/run.go:107 / :120 |
| 15e | `user.message` 送信 | `Sessions.Events.Send` | claude_managed_agents/internal/session/run.go:147 |
| 15f | agent 発話を行として `out` (= bridge) に書く → `message_delta` | `stream.Processor.Handle` | claude_managed_agents/internal/stream/processor.go:96 → claude_managed_agents/cmd/devui/conversation_stream.go:121 |
| 15g | `custom_tool_use` を pending に積む | `Processor.pending` | claude_managed_agents/internal/stream/processor.go:110 |
| 15h | `status_idle(requires_action)` で pending を replies として返す | `Processor.handleIdle` | claude_managed_agents/internal/stream/processor.go:136 |
| 15i | replies を batch 単位で**逐次** dispatch | `userCustomToolResultEvent` → `resolveCustomToolResultText` → `dispatch` | claude_managed_agents/internal/session/run.go:170 → claude_managed_agents/internal/session/customtool.go:41 |
| 15j | **ツールループ本体**: `tool_start` → (`deep_dive` なら asset_context 注入) → ツール実行 → 進捗 → `artifact` → `tool_end` → 台帳 write-through | `wrapDispatchWithSSE` | claude_managed_agents/cmd/devui/conversation.go:589 (順に :591 / :671 / :674 / :601 / :606 / :610 / :607) |
| 15k | `custom_tool_result` を送信し `ack` でストリーム再開 | `Sessions.Events.Send` | claude_managed_agents/internal/session/run.go:176 |
| 15l | `status_idle(end_turn)` で terminal → `Run` が蓄積テキストを返す | `Processor.handleIdle` / `doneCh` | claude_managed_agents/internal/stream/processor.go:164 / claude_managed_agents/internal/session/run.go:185 |
| 16 | archived リトライ判定 (1 回) | `isArchivedSessionErr` | claude_managed_agents/cmd/devui/conversation.go:458 |
| 17 | pending tool 復旧判定 (interrupt + 1 回再送) | `isPendingToolResponseErr` / `conversationInterrupt` | claude_managed_agents/cmd/devui/conversation.go:464 |
| 18 | bridge の残行 flush | `bridge.Close` | claude_managed_agents/cmd/devui/conversation.go:477 → claude_managed_agents/cmd/devui/conversation_stream.go:97 |
| 19 | `error` イベント (runErr があるときのみ) | `sw.Event("error", …)` | claude_managed_agents/cmd/devui/conversation.go:478 |
| 20 | **`done` イベント** | `sw.Event("done", …)` | claude_managed_agents/cmd/devui/conversation.go:484 |
| 21 | keep-alive 停止 | `defer stopKA()` | claude_managed_agents/cmd/devui/conversation.go:375 |

#### 6.1 順序に関する重要な事実

- **台帳への write-through は SSE 送出の後**。`artifact` を出してから台帳に書く
  (claude_managed_agents/cmd/devui/conversation.go:606 → :607、:630 → :632、:659 → :660、:687 → :690)。
  FE は台帳保存の成否を待たずに描画される。
- **`generate_ideas` の引数マージによる台帳保存はツール本体の前**
  (claude_managed_agents/cmd/devui/conversation_tools_generate.go:144)。同じマージが `runGenerateIdeas` 内でも
  再実行される (:291) が、そちらは保存しない。
- **生成物本体の永続化はツール本体の中・`artifact` 送出より前**
  (アイデア: claude_managed_agents/cmd/devui/conversation_tools_generate.go:371、
  企画書タブ: claude_managed_agents/cmd/devui/conversation_tools_plan.go:190)。
- **テーマ作成・`selected_domains` 書き込みは runner 実行より前**。同一ターンの `generate_ideas` が
  読めるようにするため (claude_managed_agents/cmd/devui/conversation.go:391 / :398)。
- **copy-on-create は themeLinker より前**。`theme_id` を先に書くことで暗黙テーマの二重作成を防ぐ
  (claude_managed_agents/cmd/devui/conversation.go:382)。
- 同一 batch 内の複数 `custom_tool_use` は `for i := range batch` で**逐次** dispatch される
  (claude_managed_agents/internal/session/run.go:172)。

---

## 経路・バリエーション

| 経路 | 実装 | 挙動の差 |
|---|---|---|
| DB 接続あり | `ConversationStore` (pool 非 nil) | 台帳は `conversation_sessions.ledger` JSONB。テーマ作成・copy-on-create・`plan_tab_versions` 保存が有効 |
| DB 未接続 (`conversationStore == nil`) | `conversationLedgerSaver.inMem` (sync.Map) — claude_managed_agents/cmd/devui/conversation_ledger.go:25 | 台帳はプロセス内のみ。`themeLinker` / `copyOnCreate` は nil で skip (claude_managed_agents/cmd/devui/conversation.go:196 / :265)。`generate_plan` は「DB 未接続のため…復元できません」で失敗 (claude_managed_agents/cmd/devui/conversation_tools_plan.go:135)。`GET /api/conversations` は `[]`、`{id}` は 404 |
| `pool == nil` の `ConversationStore` を渡した場合 | `Get` → `(nil, nil)` / `Upsert` → `nil` (claude_managed_agents/internal/db/conversation_store.go:365 / :409) | saver は「store 非 nil」と判断して DB 分岐に入るため、**台帳がどこにも保存されない** (インメモリ退避も走らない)。`conversationStore == nil` のときと挙動が異なる |
| managed session 継続 (map ヒット) | `conversationSessions.Load` | DB アクセスなし |
| managed session 継続 (map ミス + DB) | `rehydrateManagedSessionIDFromDB` | サーバ再起動後の再開経路 (claude_managed_agents/cmd/devui/conversation.go:412) |
| ツール実体 = registry (session 非依存) | `buildToolDispatchFunc` — claude_managed_agents/cmd/devui/conversation_tools.go:92 | `list_assets` / `load_asset` / `research_market` / `deep_dive` / `record_rejection` |
| ツール実体 = SSE 専用分岐 (feSessionID 必須) | `wrapDispatchWithSSE` — claude_managed_agents/cmd/devui/conversation.go:594 / :616 / :642 / :655 | `generate_ideas` / `generate_plan` / `set_theme_name` / `match_functions`。deps が nil のとき registry の fallback へ落ちる (`generate_ideas` だけ fallback 未登録) |
| `research_market` `pattern=domain` | `searchDomain` — claude_managed_agents/cmd/devui/conversation_tools_research.go:136 | `industry_mode` を反映。`confidence` / `hype_warning` は付かない |
| `research_market` `pattern=trend` | `searchTrend` — claude_managed_agents/cmd/devui/conversation_tools_research.go:274 | ソースに `kind` を付与し、Go 側 `triangulationConfidence` が確度を決定的に算出 (news 以外の distinct kind 数で 低/中/中高/高)。`industry_mode` は無視 |
| `research_market` それ以外の pattern | (検証で弾く) | `{"error":"未対応の pattern です (domain / trend のみ対応)"}` (claude_managed_agents/cmd/devui/conversation_tools_research.go:455) |
| `deep_dive` グラウンディングあり | `exaDeepDiveSearcher` (Exa 6 件) — claude_managed_agents/cmd/devui/conversation_tools_deepdive.go:89 | 実在 URL のみ引用させるブロックを userPrompt に注入 |
| `deep_dive` グラウンディングなし | `EXA_API_KEY` 未設定 / 検索失敗 / 0 件 | パラメトリック継続 + `notes` 先頭に caveat (claude_managed_agents/cmd/devui/conversation_tools_deepdive.go:283) |
| `match_functions` の領域ソース | `SelectedDomains` 非空 → それを使う / 空 → `ResearchedDomains` | 引数 `domains` でのフィルタは 1 件も一致しなければ**無視**して全候補を使う (claude_managed_agents/cmd/devui/conversation_tools_matching.go:282) |
| `generate_ideas` の `theme_id` | `themeResolver` が解決 | 会話に紐づく既存 `theme_id` を再利用 (claude_managed_agents/cmd/devui/conversation_tools_generate.go:340) |
| `generate_ideas` の `theme_id` | resolver 空 + `creator` あり | 「対話生成: <本体>」名で themes 行を新規作成 (claude_managed_agents/cmd/devui/conversation_tools_generate.go:347 / :548) |
| 起点「アセットから発散」(5 ステップ) | prompt 指示 | `load_asset` → `research_market` → `match_functions` → `generate_ideas` → `generate_plan` (claude_managed_agents/prompts/conversational_orchestrator_system.md:22) |
| 起点「ゼロベースで発散」(4 ステップ) | prompt 指示 | アセット解析を省略し、**`match_functions` を呼ばない** (機能ツリー不在でエラーになるため / claude_managed_agents/prompts/conversational_orchestrator_system.md:119) |
| 起点「自分のアイデアから発散」 | prompt 指示 (`<idea_input>` タグ) | 新ツールを増やさず既存 9 ツールに合流 (claude_managed_agents/prompts/conversational_orchestrator_system.md:230) |
| `generate_plan` のバージョン採番 | `nextVer` あり → `NextVer` / nil → fallback `"v" + PlanTabDefaultVersions[tab]` | 再実行時の UNIQUE 違反によるサイレント無保存を防ぐ (claude_managed_agents/cmd/devui/conversation_tools_plan.go:318) |

---

## 推測 (確信度つき)

- **`deep_dive` → 企画書 grounding の還流は、実運用では `title` だけが入る** — 確信度: **高**。
  根拠: 書き手 `deepDiveToolResult` に `finding` キーが無く `notes` は `[]string`
  (claude_managed_agents/cmd/devui/conversation_tools_deepdive.go:168)、読み手は `finding`/`notes` を string で期待
  (claude_managed_agents/cmd/devui/conversation_plan_grounding.go:100)。`encoding/json` は型不一致でも他フィールドの
  decode を続けるため、`title` フォールバック (claude_managed_agents/cmd/devui/conversation_plan_grounding.go:119) だけが効く。
  実際の LLM 出力キーは `findings` の配列 (claude_managed_agents/prompts/conversational/deepdive_credibility.md:19)。
  実機での還流テキストは未確認。
- **`conversationSessions` map はプロセスローカルなので、多インスタンス構成では reuse が DB 経路のみになる** —
  確信度: **高**。根拠: `sync.Map` のコメントに「サーバ再起動で消える PoC スコープ」と明記
  (claude_managed_agents/cmd/devui/conversation.go:82)。
- **同一 `feSessionID` への並行 HTTP リクエストで台帳の後勝ち上書きが起きる** — 確信度: **中**。
  根拠: `appendXxx` / `getLedger`→`saveLedger` はいずれも独立した `Get`→`Upsert` で、`ledger` を全置換する
  (claude_managed_agents/cmd/devui/conversation_ledger.go:41 / :79 / claude_managed_agents/internal/db/conversation_store.go:406)。
  同一 batch 内の dispatch は逐次なので (claude_managed_agents/internal/session/run.go:172)、
  単一リクエスト内では発生しない。並行リクエストの実挙動は未検証。
- **`generate_progress` は必ず step 1..5 の 5 回出る** — 確信度: **高**。
  根拠: `runGenerateIdeas` が委譲前に 1/2/3、委譲後に 4/5 を固定で emit する
  (claude_managed_agents/cmd/devui/conversation_tools_generate.go:326 / :358 / :368)。
  ただしツールが早期に構造化エラーを返す場合 (前提不足) は emit 前に return するため 0 回になる (:295)。
- **`plan_progress` の `phase` は企画書コアの `status.phase` をそのまま中継するため値域はコア側依存** —
  確信度: **中**。根拠: `planStreamCollector.onEvent` が `status` の `phase` をそのまま emit し、
  `tab` / `tab_error` のときは文字列リテラル `"tab"` / `"tab_error"` を渡す
  (claude_managed_agents/cmd/devui/conversation_plan_stream.go:129)。コア側 (`streamIdeaPlanCoreWithSelector`) は未調査。

---

## 未調査・対象外

- **FE 側 (`claude_managed_agents/frontend`) の SSE 消費**: イベント名・payload の解釈、
  `<options>` / `<questions>` / `<domain_select>` / `<divergence_design>` / `<idea_input>` / `<turn>` タグのパース、
  artifact の kind 別描画先 (タブ) は未調査。`artifact(asset)` だけ payload ラッパを持たない理由も FE 契約側は未確認。
- **実行時挙動**: 実際に Managed Agent を叩いた際のイベント列・レイテンシ・トークン消費は未確認
  (`go test` / 実機実行を行っていない。指示により参照リポジトリは読み取り専用)。
- **`generate_ideas` の委譲先**: `buildDivergeUserMessageMulti` / `resolveTargetIdeas` / `ExtractIdeasJSON` /
  idea-diverge-agent 側の system prompt は未調査 (件数既定・上限の knob は本調査の対象外)。
- **企画書 8 タブ生成コア**: `streamIdeaPlanCoreWithSelector` / `groundingResult` の生成側 (`newPlanGroundingFunc`) /
  `planSource` / `dedupPlanSources` の詳細は未調査。`plan_progress.phase` の値域はコア側依存で未確定。
- **deep_dive 各パターンの出力スキーマ**: `credibility` のみ確認。`competition` / `momentum` / `demand` /
  `counterevidence` / `problem_structure` の JSON スキーマ差分は未調査。
- **従来モード経路**: `diverge_chat.go` / `diverge_managed.go` / `/api/diverge/domains` 等は会話モードの比較対象外。
- **`hassan-v2-backend` / `hassan-v2-frontend` 側の相当物**: テーブル・エンドポイント・UseCase の対応付けは
  本タスクのスコープ外 (別調査で扱う)。
- **マイグレーションの down 側**: `000032_conversation_sessions.down.sql` /
  `000033_conversation_sessions_theme_id.down.sql` の内容は未確認。

---

## 抜き取り検証 (オーケストレーター実施。2026-07-29)

`orchestrating-delegation` skill ③ に従い、設計に影響する load-bearing な主張を一次ソースで照合した。
**照合 3 件すべて一致** (誤りが見つからなかったため全数照合には切り替えていない)。

| 照合項目 | 照合方法 | 結果 |
|---|---|---|
| 台帳 `Interests` に書き込み経路が無い (BE-10) | `Interests` をリポジトリ横断 grep (テスト除く) | **一致**。読み出しは `claude_managed_agents/cmd/devui/conversation_tools_generate.go:400` (前提チェック) と `:471`〜`:472` (発散入力) の 2 箇所。書き込みは台帳コピー `conversation_ledger.go:433` のみで**新規セット経路が無い**。tool schema・system prompt に `interests` の語も無い |
| `deep_dive.asset_context` が schema/prompt に無く、サーバ注入で補われる | handler のパース箇所と注入箇所、prompt の出現回数 | **一致**。注入は `claude_managed_agents/cmd/devui/conversation.go:745`〜`:752`、`prompts/conversational_orchestrator_system.md` の出現回数は **0** |
| 企画書 grounding の還流でフィールド契約が食い違う | 読み手と書き手の構造体を両方読む | **一致 (実バグ)**。下記参照 |

### 確認された実バグ: grounding 還流のフィールド不一致

| 側 | 定義 | 出典 |
|---|---|---|
| **読み手** | `Finding string` (`json:"finding"`) / `Notes string` (`json:"notes"`) | `claude_managed_agents/cmd/devui/conversation_plan_grounding.go:100`〜`:102` |
| **書き手** | `finding` フィールド**が存在しない** / `Notes []string` (`json:"notes"`) | `claude_managed_agents/cmd/devui/conversation_tools_deepdive.go:168`〜`:176` |

読み手は書き手が出力しないフィールドを期待しており、`notes` は型も違う (string vs 配列)。
**テストが合成 JSON (`{"finding":"…"}`) を渡しているため検出されていない**
(`claude_managed_agents/cmd/devui/conversation_plan_grounding_test.go:32` `:98` `:121` /
`conversation_tools_plan_test.go:206`)。実運用では `title` フォールバックしか効かず、
deep_dive の検証済み論点が企画書生成のプロンプトへ十分に還流していない可能性が高い。

**v3 への含意**: 移植時に PoC の grounding 還流ロジックをそのまま持ち込むと同じ穴が入る。
**deep_dive の出力スキーマを SSOT として定義し、読み手・書き手・テストの 3 者を同じ定義から導く**
必要がある (テストが合成データを使うと契約違反が隠れる — 本件がその実例)。
本パターンは `.claude/rules/feedback_review_patterns.md` の **BE-12** として登録した。
