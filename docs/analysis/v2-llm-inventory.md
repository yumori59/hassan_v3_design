# v2 現行 LLM 機能の棚卸し (機能 × 経路 × モデル)

> 実測日: 2026-07-29 / 対象: hassan-v2-backend (作業ツリー) / 先行調査: dify-inventory.md の §5 を埋めるもの

## 調査対象と問い

「v2 の現行 LLM 機能を v3 へ移植する」設計 (`docs/design/llm-migration.md` 予定) の入力として、
**(a) 各機能が今どの経路で動いているか (b) それぞれが実際にどのモデルを使っているか** を出典付きで確定する。
**設計提案・モデルの推奨は書かない** (事実の列挙のみ)。

探索の前提: `hassan-v2-backend` の作業ツリーには `.worktrees/` と `.claude/worktrees/` に
6 本の worktree コピーが存在し、`*_llm.go` などが重複ヒットする。
**本ドキュメントの grep は全て worktree を除外した本体 (HEAD = `main`, `c001518`) を対象とする**。

---

## 1. 未配線だった 4 機能の現行経路

先行調査 (dify-inventory.md §3) で「未配線・移行先未調査」とされた 4 機能の判定結果。

| Dify の機能 | 判定 | 現行の実装 (出典) |
|---|---|---|
| `research_chat` (リサーチチャット) | **v2 の llm 経路に移行済み**。名称は「カスタムリサーチ」に変わり、Dify の 1 回のチャット呼び出しが**多段パイプライン**に置き換わった | `hassan-v2-backend/usecase/research/custom_research_stream.go` |
| `idea` (アイデア生成) | **v2 の llm 経路に移行済み**。`llm.IdeaService` 経由 | `hassan-v2-backend/usecase/idea/generate_idea.go` |
| `company_info_from_url` (URL から企業情報) | **v2 の llm 経路に移行済み**。入出力の形も維持 | `hassan-v2-backend/usecase/company/generate_company_from_gen_ai.go` + `hassan-v2-backend/usecase/company/company_from_url_llm.go` |
| `extract_json` (JSON 抽出) | **LLM 呼び出しとしては廃止**。決定論的な Go コードに置き換わった。プロンプト資産と取得関数だけが dead code として残存 | 置換先: `hassan-v2-backend/util/json.go` + `hassan-v2-backend/llm/util.go`。残骸: `hassan-v2-backend/prompt/template.go:249` / `:257` |

### 1-1. research_chat → カスタムリサーチ (SSE ストリーム)

- エンドポイントは Dify 時代と同じ `POST /research-chats` で、ハンドラが
  `ResearchController.CustomResearchStream` に差し替わっている
  — 出典: `hassan-v2-backend/router/router.go:178`
- 履歴系 3 エンドポイント (`GET ""` / `GET /:conversation_id` / `DELETE /:conversation_id`) も同じ
  グループに残っており、Dify の `GetResearchChatHistory` (HTTP) ではなく **DB から読む**
  — 出典: `hassan-v2-backend/router/router.go:173`〜`:175`、
  `hassan-v2-backend/usecase/research/get_research_chat_history.go:43`
  (`uc.rcr.GetResearchHistory` = `research_conversation_histories` 由来)
- Dify 側は「1 回の `POST /chat-messages` (blocking / streaming)」だった
  — 出典: `hassan-v2-backend/dify/research_chat.go:30` (Blocking) / `:58` (streaming)
- 現行は **planning → 反復 (検索クエリ生成 → 検索実行 → 下書き修正 → 自己批判) → 最終レポート**
  の多段構成。フェーズごとに別モデルを引ける
  — 出典: `hassan-v2-backend/usecase/research/custom_research_stream.go:100`〜`:106`、
  `hassan-v2-backend/usecase/research/custom_research_stream_operations.go:142`〜`:212`
- **注意**: Dify のレスポンス型だった `dto.ResearchResponse` / `ResearchUsage` / `FinishReason` は
  DB 履歴のパース時に**内部的な入れ物として再利用**されている (LLM の実応答ではない)
  — 出典: `hassan-v2-backend/usecase/research/get_research_chat_history.go:57`〜`:63`
  (`&dto.ResearchResponse{Choices: ...}` を手組みして `parseResearchContent` に渡している)

### 1-2. idea → GenerateIdeaUseCase

- `llm.Factory.GetIdeaServiceByModel` 経由で `llm.IdeaService.GenerateIdea` を呼ぶ
  — 出典: `hassan-v2-backend/usecase/idea/generate_idea.go:249` / `:272`
- Dify の `IdeaHassanResponse{Title, Ideas[]}` に相当する型は `llm.GenerateIdeaResponse` /
  `llm.IdeaContent` として llm 層に移っている
  — 出典: `hassan-v2-backend/llm/types.go:131` / `:137`、対比: `hassan-v2-backend/dify/idea.go:19`
- 派生機能も同じ llm 層に載っている: アイデア評価 `hassan-v2-backend/usecase/idea/evaluate_ideas.go`、
  マイアイデア補完 `hassan-v2-backend/usecase/idea/create_my_idea.go`

### 1-3. company_info_from_url → GenerateCompanyFromGenAIUseCase

- URL 本文取得 (`PageTextService`) → プロンプト生成 → `GenerateTextContent` → JSON パース
  — 出典: `hassan-v2-backend/usecase/company/generate_company_from_gen_ai.go:43`〜`:66`
- 返却フィールド (`name` / `url` / `business_summary` / `strengths`) は Dify 版と同じ `entity.Company`
  — 出典: `hassan-v2-backend/usecase/company/company_from_url_llm.go:14`〜`:19`、
  対比: `hassan-v2-backend/dify/comany_info_from_url.go:13` (戻り値が `*entity.Company`)
- プロンプトはリポジトリ内テンプレートに移植済み
  — 出典: `hassan-v2-backend/prompt/company/system/from_url.tmpl` /
  `hassan-v2-backend/prompt/company/user/from_url.tmpl` (取得関数は `hassan-v2-backend/prompt/template.go:313` / `:323`)

### 1-4. extract_json → 決定論的 Go コードへ (LLM 呼び出しは廃止)

- Dify 版は「壊れた JSON を LLM に修復させる」チャット呼び出しだった
  — 出典: `hassan-v2-backend/dify/extract_json.go:11` (`JsonExtractionChat`)
- 現行はコードブロックの剥離・括弧数チェック・制御文字除去・`json.Unmarshal` を**Go だけで**行う
  — 出典: `hassan-v2-backend/util/json.go:10` (`ExtractJSONFromResponse`) / `:42` (`HasMatchingBraces`) /
  `:53` (`CleanJSONString`) / `:75` (`IsValidJSON`)、それらを束ねる
  `hassan-v2-backend/llm/util.go:14` (`ValidateAndParseJSON`) と `:42` (リトライ付き実行)
- 呼び出し元 (LLM 応答の JSON 化) は 14 箇所以上に散っている。例:
  `hassan-v2-backend/usecase/asset/generate_asset_description.go:376`、
  `hassan-v2-backend/usecase/business_plan/detailed/market_analysis.go:265`
- **残骸 (dead code)**: LLM で JSON 抽出するためのプロンプトと取得関数が残っている。
  非テストコードからの呼び出し元はゼロ
  — 出典: `hassan-v2-backend/prompt/template.go:246`〜`:259`
  (`GetJSONExtractionSystem` / `GetJSONExtractionUser`)、
  テンプレート実体 `hassan-v2-backend/prompt/json_extraction/system/system.tmpl` /
  `hassan-v2-backend/prompt/json_extraction/user/user.tmpl`。
  `prompt.PromptService` インターフェースにも公開されていない (`hassan-v2-backend/prompt/service.go` に定義なし)
- 履歴による裏取り: 呼び出し元は `controller/asset.go` にあり、
  Perplexity → OpenAI 移行のコミットで LLM 版 JSON 抽出ごと削除された
  — `git log --oneline -S "GetJSONExtractionSystem" -- controller/asset.go` → `62814cb` (追加) / `d1e51c9` (再追加)、
  `git log --oneline -S "JsonExtractionChat" -- controller/ usecase/` → `082e33c fix: アセット説明文生成処理の修正` (削除)

---

## 2. 機能 × モデルの対応表

「モデル指定の実体」の分類:
**R** = リクエストパラメータで選べる / **E** = env で上書き可能 (実配線あり) /
**C** = コード内定数・ハードコード / **P** = プロバイダ直指定 (モデルはプロバイダ実装内で固定)。

`env/*.env` の 3 環境すべてに `DEFAULT_` で始まる行は 1 件も無い
(`grep -c "^DEFAULT_" env/.local.env env/.dev.env env/.prod.env` → いずれも 0)。
したがって **「実効モデル」列はコード内の既定値がそのまま効いている値**である。

| # | 機能 / UseCase | 指定の実体 | 実効モデル (現状) | 出典 |
|---|---|---|---|---|
| 1 | アイデア生成 `GenerateIdeaUseCase` | R + E + C | think (既定): `gemini-3.1-pro-preview` → `gpt-5.2` / fast: `gemini-3-flash-preview` → `gpt-5-nano` | `hassan-v2-backend/usecase/idea/generate_idea.go:178`〜`:221` |
| 2 | アイデア評価 `EvaluateIdeasUseCase` | R + E + C + DB | 同上。`modelType` 未指定時は DB の `idea_hassans.model_name` を使う | `hassan-v2-backend/usecase/idea/evaluate_ideas.go:184`〜`:233` |
| 3 | マイアイデア補完 `CreateMyIdeaUseCase` | R + C (**env を見ない**) | think (既定): `gemini-3.1-pro-preview` → `gpt-5.2` / fast: `gemini-3-flash-preview` → `gpt-5-nano` | `hassan-v2-backend/usecase/idea/create_my_idea.go:605`〜`:635` |
| 4 | アイデア Web 検索 (市場規模 / CAGR / OGP 選択) | C | `gpt-5-nano` (3 箇所ハードコード) | `hassan-v2-backend/usecase/idea/web_search.go:490` / `:531` / `:1049` |
| 5 | 同 ページ本文からの市場規模 / CAGR 抽出 | C | 引数モデルが空なら `gpt-5-mini` | `hassan-v2-backend/usecase/idea/web_search.go:1136` |
| 6 | アイデア市場規模・CAGR Web リサーチ `IdeaMarketCAGRWebResearchUseCase` | C (DI 固定) | plan / search / revision = `gemini-3-flash-preview`、検索実行 = `gpt-4o-mini-search-preview`、抽出 = 設定値 → `o4-mini` → `gpt-4o-mini` | `hassan-v2-backend/usecase/idea/idea_market_cagr_web_research.go:78` / `:101` / `:113` / `:152` / `:206`、既定値 `hassan-v2-backend/entity/business_plan_detailed_config.go:35`、DI `hassan-v2-backend/di/wire.go:205` |
| 7 | 企画書 簡易モード生成 `GenerateBusinessPlanUseCase` | C (DI 固定) | `gemini-3-flash-preview` | `hassan-v2-backend/usecase/business_plan/generate_business_plan.go:389`、既定値 `hassan-v2-backend/entity/business_plan_simple_config.go:12`、DI `hassan-v2-backend/di/wire.go:116` |
| 8 | 企画書 ブラッシュアップ stage-1 (クエリ補強) | C (DI 固定) | `gemini-3-flash-preview` (空なら `Model` にフォールバック) | `hassan-v2-backend/usecase/business_plan/generate_business_plan.go:175`〜`:183` |
| 9 | 企画書チャット `BusinessPlanChatUseCase` | C (DI 固定) | `gemini-3-flash-preview` | `hassan-v2-backend/usecase/business_plan/business_plan_chat.go:114` |
| 10 | 企画書サムネイル生成 | **P** | `gemini-2.5-flash-image` (プロバイダ実装内で URL に埋め込み) | `hassan-v2-backend/usecase/business_plan/generate_business_plan_thumbnail.go:85` → `hassan-v2-backend/llm/gemini/service.go:835` |
| 11 | 企画書詳細 セクション分析 (競合 / PESTEL / 市場 / 仮説検証 / 法規制 / 評価サマリ / ブラッシュアップ) | C (DI 固定) | `gemini-3-flash-preview` → `o4-mini` → `gpt-4o-mini` | `hassan-v2-backend/usecase/business_plan/detailed/competitor_analysis.go:225` 他 7 箇所、fallback 定義 `hassan-v2-backend/usecase/business_plan/detailed/fallback.go:7` |
| 12 | 企画書詳細 Web リサーチ | C (DI 固定) | plan / draft / search / revision / critic = `gemini-3-flash-preview`、検索実行 = `gpt-4o-mini-search-preview` → `exa-search` | `hassan-v2-backend/usecase/business_plan/detailed/web_research.go:87`〜`:371`、既定値 `hassan-v2-backend/entity/business_plan_detailed_config.go:35` |
| 13 | カスタムリサーチ (= 旧 research_chat) | **R** + E | draft / plan / search / revision / critic / final = `gemini-3-flash-preview`、検索実行 = `gpt-4o-mini-search-preview` | `hassan-v2-backend/usecase/research/custom_research_stream.go:81`〜`:85`、マージ規則 `hassan-v2-backend/usecase/research/config_merge.go:8`、既定値 `hassan-v2-backend/entity/custom_research.go:21`、env 配線 `hassan-v2-backend/di/wire.go:263` |
| 14 | リサーチシート — テーブル作成・修正系 (作成 / 列追加 / 行追加 / 列削除 / 行削除 / 更新) | C (DI 固定) | `gpt-4o` → `o4-mini` → `gpt-4o-mini` | `hassan-v2-backend/usecase/research_sheet/handle_create_sheet.go:479`、`hassan-v2-backend/usecase/research_sheet/update_research_sheet.go:157` 他、既定値 `hassan-v2-backend/entity/research_sheet_action.go:82` |
| 15 | リサーチシート — アクション分類 | C (DI 固定) | `gpt-4o-mini` (fallback も `gpt-4o-mini` なので実質 1 本) | `hassan-v2-backend/usecase/research_sheet/action_classifier.go:55`、`hassan-v2-backend/usecase/research_sheet/fallback.go:41` |
| 16 | リサーチシート — 質問応答 (LLM のみ) / その他 | C (DI 固定) | `gpt-4o-mini` → `o4-mini` → (重複除去) | `hassan-v2-backend/usecase/research_sheet/handle_query_sheet_llm_only.go:132`、`hassan-v2-backend/usecase/research_sheet/handle_other.go:137` |
| 17 | リサーチシート — 質問応答 (Web 検索付き) | C (DI 固定) | `gpt-4o-mini-search-preview` (fallback も同一) | `hassan-v2-backend/usecase/research_sheet/handle_query_sheet_with_web_search.go:139`、`hassan-v2-backend/usecase/research_sheet/fallback.go:36` |
| 18 | リサーチシート — Web リサーチ | C (DI 固定) | plan / draft / search / revision / critic = `gpt-4o-mini`、検索実行 = `gpt-4o-mini-search-preview` → `exa-search` | `hassan-v2-backend/usecase/research_sheet/web_research.go:85`〜`:238`、`hassan-v2-backend/usecase/research_sheet/fallback.go:26` |
| 19 | アセットタイトル抽出 `extractAssetTitlesWithLLM` | **E** | `o4-mini` → `gpt-4o-mini` | `hassan-v2-backend/usecase/asset/extract_asset_titles_llm.go:42`、`hassan-v2-backend/usecase/asset/llm_json_helper.go:31`、既定 `hassan-v2-backend/usecase/asset/fallback.go:5` |
| 20 | アセット説明生成 (ドキュメント経路) `generateAssetDescriptionsWithLLM` | **E** | `o4-mini` → `gpt-4o-mini` | `hassan-v2-backend/usecase/asset/generate_asset_descriptions_llm.go:59`、`hassan-v2-backend/usecase/asset/generate_assets_operations.go:116` |
| 21 | アセット説明生成 (タイトルのみ経路 / WriteReport) | **E + P** | `o4-mini` → `gpt-4o-mini`。プロバイダは OpenAI 固定。`WriteReport` 側の既定も `o4-mini` | `hassan-v2-backend/usecase/asset/generate_asset_description.go:355`〜`:366`、`hassan-v2-backend/llm/openai/service.go:1053` |
| 22 | URL から企業情報 `GenerateCompanyFromGenAIUseCase` | **E** + C | `o4-mini` (**フォールバック無し**) | `hassan-v2-backend/usecase/company/company_from_url_llm.go:12` / `:29`〜`:34`、env 配線 `hassan-v2-backend/di/wire.go:294` |

### 2-1. 「env で上書き可能」が実際には効かない箇所 (反証探索の結果)

コメント上は「env で上書き可能」と書かれているが、**DI の provider が `*Config` を受け取らないため
env は届かない**設定が 3 つある。

| 設定 | コメント | 実際の provider | 出典 |
|---|---|---|---|
| `entity.ResearchSheetConfig` | 各フィールドに「env で上書き可能」 | `providerResearchSheetConfig()` — **引数なし**。`DefaultResearchSheetConfig()` をそのまま返す | `hassan-v2-backend/entity/research_sheet_action.go:57`〜`:78` (コメント) vs `hassan-v2-backend/di/wire.go:101` |
| `entity.BusinessPlanWebResearchConfig` | 「未設定時はコード内フォールバック。env で上書き可能」 | `providerBusinessPlanDetailedWebResearchConfig()` — **引数なし** | `hassan-v2-backend/entity/business_plan_detailed_config.go:33` vs `hassan-v2-backend/di/wire.go:200` |
| `entity.BusinessPlanSimpleConfig` | — | `providerBusinessPlanSimpleConfig()` — **引数なし** | `hassan-v2-backend/di/wire.go:116` |

さらに、env 変数が定義されているのに DI で読まれていないものが 1 つある。

- `DEFAULT_IDEA_THINK_FALLBACK_MODEL` は `Config` に定義され
  (`hassan-v2-backend/di/provider.go:78`)、UseCase 側でも参照される
  (`hassan-v2-backend/usecase/idea/generate_idea.go:188`、
  `hassan-v2-backend/usecase/idea/evaluate_ideas.go:204`) が、
  **`providerIdeaModelDefaults` が `DefaultIdeaModel` と `DefaultIdeaFallbackModel` の 2 つしか
  詰めていない** ため常に空文字列になり、コード内定数 `"gpt-5.2"` が使われる
  — 出典: `hassan-v2-backend/di/wire.go:212`〜`:217`、`hassan-v2-backend/di/wire_gen.go:364`〜`:369`

### 2-2. カスタムリサーチの config マージ挙動 (部分指定時の落とし穴)

- リクエスト body に `config` が**無い**場合のみ `entity.DefaultCustomResearchConfig()` が使われる
  — 出典: `hassan-v2-backend/usecase/research/custom_research_stream.go:82`〜`:84`
- `config` が**部分的に**指定された場合、空フィールドは env 既定 (現状すべて空) で補完されるだけで
  `DefaultCustomResearchConfig()` には**戻らない** → 空文字列のモデル名が
  `buildFallbacks("")` に渡り、1 本目が失敗してから `o4-mini` → `gpt-4o-mini` に落ちる
  — 出典: `hassan-v2-backend/usecase/research/config_merge.go:8`、
  `hassan-v2-backend/usecase/research/fallback.go:19`
- 例外: 検索実行モデルのみ空チェックがあり `DefaultCustomResearchConfig().SearchExecutionModel` に戻る
  — 出典: `hassan-v2-backend/usecase/research/custom_research_stream_operations.go:364`〜`:367`

### 2-3. モデル指定がリクエストから来る経路 (一覧)

| 経路 | 受け口 | 受け付ける値 |
|---|---|---|
| アイデア生成 / 評価 / マイアイデア | クエリパラメータ `?model=` | `fast` / `think` / モデル名の直指定。空なら `think` |
| カスタムリサーチ | リクエスト body の `config` (JSON) | 7 フェーズ分のモデル名 + `max_iterations` 等 |

出典: `hassan-v2-backend/controller/idea.go:221`〜`:223` (他に `:289` / `:367` / `:527`)、
`hassan-v2-backend/controller/dto/research.go:70`〜`:77` (`Config *entity.CustomResearchConfig`)

なお **リサーチシート・企画書系にリクエストからのモデル指定口は無い** (dto に該当フィールドなし)
— `grep -n "Config\|Model" controller/dto/research_sheet.go` → 0 件。

---

## 3. 用途別の許可リスト

`llm/factory.go` の 2 つのゲートは `llm/types.go` の map を参照する。**map の実体は以下のとおり**。

### 3-1. `IdeaGenerationModels` — 10 モデル

出典: `hassan-v2-backend/llm/types.go:65`〜`:76` (定義順)

| # | 定数 | モデル文字列 | コメント上の役割 |
|---|---|---|---|
| 1 | `Medelo3` | `o3` | OpenAI o3 |
| 2 | `ModelO4Mini` | `o4-mini` | OpenAI o4-mini |
| 3 | `ModelGemini15Pro` | `gemini-2.5-pro` | Gemini 2.5-pro |
| 4 | `ModelGemini15Flash` | `gemini-2.5-flash` | Gemini 2.5-flash |
| 5 | `ModelGemini3Flash` | `gemini-3-flash-preview` | fast デフォルト |
| 6 | `ModelGemini3Pro` | `gemini-3.1-pro-preview` | think デフォルト |
| 7 | `ModelGPT5Nano` | `gpt-5-nano` | fast フォールバック |
| 8 | `ModelGPT5Mini` | `gpt-5-mini` | — |
| 9 | `ModelGPT52` | `gpt-5.2` | think フォールバック |
| 10 | `ModelClaude4Sonnet` | `claude-sonnet-4-5` | Claude 4-sonnet |

ゲート: `Factory.GetIdeaServiceByModel` (`hassan-v2-backend/llm/factory.go:57`) と
`Factory.IsIdeaGenerationSupported` (`:76`)。
UseCase 側でも呼び出し前に `IsIdeaGenerationSupported` でスキップ判定している
— 出典: `hassan-v2-backend/usecase/idea/generate_idea.go:241`

### 3-2. `ResearchModels` — 16 モデル

出典: `hassan-v2-backend/llm/types.go:195`〜`:212` (定義順)

| # | 定数 | モデル文字列 |
|---|---|---|
| 1 | `Medelo3` | `o3` |
| 2 | `ModelGPT4` | `gpt-4.1` |
| 3 | `ModelGemini15Pro` | `gemini-2.5-pro` |
| 4 | `ModelClaude4Sonnet` | `claude-sonnet-4-5` |
| 5 | `ModelGPT4o` | `gpt-4o` |
| 6 | `ModelGPT4oMini` | `gpt-4o-mini` |
| 7 | `ModelGPT4oMiniSearchPreview` | `gpt-4o-mini-search-preview` |
| 8 | `ModelGPT4oMiniSearchPreview2025` | `gpt-4o-mini-search-preview-2025-03-11` |
| 9 | `ModelGPT5Nano` | `gpt-5-nano` |
| 10 | `ModelGPT5Mini` | `gpt-5-mini` |
| 11 | `ModelO4Mini` | `o4-mini` |
| 12 | `ModelO4MiniDeepResearch` | `o4-mini-deep-research` |
| 13 | `ModelGPT4SearchPreview2025` | `gpt-4o-search-preview-2025-03-11` |
| 14 | `ModelGemini15Flash` | `gemini-2.5-flash` |
| 15 | `ModelGemini3Flash` | `gemini-3-flash-preview` |
| 16 | `ModelExaSearch` | `exa-search` |

ゲート: `Factory.GetResearchServiceByModel` (`hassan-v2-backend/llm/factory.go:82`) と
`Factory.IsResearchSupported` (`:102`)。

**リストに入っていない定義済みモデル** (22 定数中 6 つは `ResearchModels` に無い):
`gpt-4o-search-preview` (`ModelGPT4SearchPreview`)、`gpt-image-1`、`gpt-5.2`、
`gemini-3.1-pro-preview` (`ModelGemini3Pro`)、`gemini-2.5-flash-image`、
`claude-haiku-4-5-20251001`。
つまり **アイデア生成の think 既定 `gemini-3.1-pro-preview` はリサーチ系では使えない**。

### 3-3. その他の分岐・許可リスト

| 種類 | 内容 | 出典 |
|---|---|---|
| エラーメッセージ内の**手書きモデル一覧** | `"o3, gpt-4o-mini, gpt-5-nano, gpt-5-mini, gemini-2.5-pro, claude-sonnet-4-5 など（ResearchModels 参照）"` — map と独立した文字列なので同期していない可能性がある | `hassan-v2-backend/llm/factory.go:83` |
| OpenAI 実装内の **Responses API / Chat Completions 分岐** | `o3` / `gpt-4.1` / 各 search-preview / `o4-mini` / `o4-mini-deep-research` / `gpt-5-nano` / `gpt-5-mini` / `gpt-5.2` **以外**は別処理へ。同じ 11 モデル並びが 7 箇所に重複している | `hassan-v2-backend/llm/openai/service.go:120` / `:225` / `:356` / `:419` / `:482` / `:546` / `:652` |
| Exa 実装のモデル固定チェック | `req.Model != llm.ModelExaSearch` ならエラー | `hassan-v2-backend/llm/exa/service.go:31` |
| 用途別フォールバック列 (許可リストとは別の「実際に試す順序」) | §3-4 参照 | — |

### 3-4. フォールバック列 (パッケージごとに別実装・4 系統)

同じ発想の `buildFallbacks` が **4 パッケージに重複定義**されている
(`research` / `research_sheet` / `business_plan/detailed` / `asset`、加えて `idea` に別名の 1 本)。

| パッケージ | 既定フォールバック列 | 出典 |
|---|---|---|
| `usecase/research` | 汎用: primary → `o4-mini` → `gpt-4o-mini` / 検索実行: primary → `gpt-4o-mini-search-preview` → `exa-search` | `hassan-v2-backend/usecase/research/fallback.go:19` / `:52` |
| `usecase/research_sheet` | table / plan / draft / search / query-llm-only: primary → `o4-mini` → `gpt-4o-mini` / 検索実行: primary → `gpt-4o-mini-search-preview` → `exa-search` / query-web-search: primary → `gpt-4o-mini-search-preview` / classification: primary → `gpt-4o-mini` | `hassan-v2-backend/usecase/research_sheet/fallback.go:6`〜`:43` |
| `usecase/business_plan/detailed` | 汎用: primary → `o4-mini` → `gpt-4o-mini` / 検索実行: primary → `gpt-4o-mini-search-preview` → `exa-search` | `hassan-v2-backend/usecase/business_plan/detailed/fallback.go:7`〜`:40` |
| `usecase/asset` | primary (空なら `o4-mini`) → `o4-mini` → `gpt-4o-mini` | `hassan-v2-backend/usecase/asset/fallback.go:5`〜`:17` |
| `usecase/idea` (抽出用) | primary → `o4-mini` → `gpt-4o-mini` | `hassan-v2-backend/usecase/idea/fallback_extraction.go:7` |
| `usecase/idea` (生成 / 評価 / 補完) | 上記とは別方式。`gemini-3.1-pro-preview`→`gpt-5.2` / `gemini-3-flash-preview`→`gpt-5-nano` / `gemini-2.5-pro`→`o3` / `gemini-2.5-flash`→`o4-mini` の**ペア表** | `hassan-v2-backend/usecase/idea/create_my_idea.go:605`〜`:623`、`hassan-v2-backend/usecase/idea/generate_idea.go:211`〜`:218` |

---

## 4. プロバイダの選択ロジック

- 実体は `Factory.getProviderByModel` の **1 本の switch** (モデル定数 → `Provider`)
  — 出典: `hassan-v2-backend/llm/factory.go:106`〜`:119`
- 対応: OpenAI 14 定数 / Exa 1 定数 / Gemini 4 定数 / Claude 2 定数。
  **`default` は `ProviderOpenAI`** (`:117`)。未知のモデル文字列は黙って OpenAI に流れる
- サービス実体は `Factory.services map[Provider]Service` に DI 時点で 4 つ登録される
  — 出典: `hassan-v2-backend/di/provider.go:141`〜`:169` (openai / gemini / claude / exa)
- 登録は `RegisterService` で重複登録がエラー、取得は `GetService` で未登録がエラー
  — 出典: `hassan-v2-backend/llm/factory.go:23` / `:36`

### 4-1. プロバイダ / モデル追加時に触る箇所

| # | 箇所 | 内容 |
|---|---|---|
| 1 | `hassan-v2-backend/llm/types.go:32`〜`:62` | `Model` 定数の追加 |
| 2 | `hassan-v2-backend/llm/factory.go:108`〜`:115` | `getProviderByModel` の case に追加 (**漏れると OpenAI に流れる**) |
| 3 | `hassan-v2-backend/llm/types.go:65` / `:195` | 用途別許可リスト (`IdeaGenerationModels` / `ResearchModels`) への追加 |
| 4 | `hassan-v2-backend/llm/types.go:8`〜`:13` | 新プロバイダなら `Provider` 定数 |
| 5 | `hassan-v2-backend/llm/interface.go:8` | 新プロバイダは `Service` の 5 メソッド (+ 用途により `IdeaService` / `ResearchService`) を実装 |
| 6 | `hassan-v2-backend/di/provider.go:141` | `providerLLMFactory` への `RegisterService` 追加 |
| 7 | `hassan-v2-backend/di/provider.go:27`〜`:81` | API キー / エンドポイントの env 追加 |
| 8 | `hassan-v2-backend/llm/openai/service.go:120` 他 6 箇所 | OpenAI 系モデルの場合は Responses / Chat の分岐条件 (7 箇所) |
| 9 | `hassan-v2-backend/llm/factory.go:83` | リサーチ非対応エラーの手書きモデル一覧 |

### 4-2. switch から漏れている定義済みモデル

- `ModelGemini25FlashImage` (`gemini-2.5-flash-image`) は `getProviderByModel` の
  Gemini case に**入っていない** — 出典: `hassan-v2-backend/llm/types.go:55` vs `hassan-v2-backend/llm/factory.go:112`
- ただし実害は確認できない: この定数はサムネイル生成で **`GetService(llm.ProviderGemini)` による
  プロバイダ直指定**の後、`GeminiService` 内部の URL 組み立てにしか使われず、
  `getProviderByModel` を経由しない
  — 出典: `hassan-v2-backend/usecase/business_plan/generate_business_plan_thumbnail.go:85`、
  `hassan-v2-backend/llm/gemini/service.go:835`。
  リポジトリ全体で `ModelGemini25FlashImage` の参照はこの 1 箇所のみ
- テストは `exa-search` → `ProviderExa` の解決のみを検証している (他モデルの検証は無い)
  — 出典: `hassan-v2-backend/llm/factory_test.go:34`

---

## 5. プロンプト資産の構成

### 5-1. ディレクトリ構造

`hassan-v2-backend/prompt` 直下に **機能別ディレクトリ 8 個**、テンプレートは **`*.tmpl` 計 130 本**
(`find prompt -name "*.tmpl" | wc -l` → 130)。

| ディレクトリ | 構成 | `*.tmpl` 本数 | うち `.en.tmpl` |
|---|---|---|---|
| `hassan-v2-backend/prompt/asset` | `system/` + `user/` | 8 | 2 |
| `hassan-v2-backend/prompt/business_plan` | `common/` + `user/` + `detailed/` (さらに `query/` `system/` `user/` `web_research/system/` `web_research/user/`) + 直下 4 本 | 46 | 1 |
| `hassan-v2-backend/prompt/company` | `system/` + `user/` | 2 | 0 |
| `hassan-v2-backend/prompt/custom_research` | `system/` + `user/` | 12 | 0 |
| `hassan-v2-backend/prompt/idea` | **直下フラット** (`system.tmpl` / `user.tmpl` / `evaluation_system.tmpl` 等) + `web_research/system/` `web_research/user/` | 40 | 13 |
| `hassan-v2-backend/prompt/json_extraction` | `system/` + `user/` (**未使用**。§1-4 参照) | 2 | 0 |
| `hassan-v2-backend/prompt/research` | `system/exa_normal.tmpl` + `user/exa_easy.tmpl` (カスタムリサーチの「簡単リサーチ」クエリ組み立て用) | 2 | 0 |
| `hassan-v2-backend/prompt/research_sheet` | `system/` + `user/` | 18 | 0 |

- **system / user の分け方は統一されていない**。`asset` / `company` / `custom_research` /
  `json_extraction` / `research` / `research_sheet` はサブディレクトリで分けるが、
  `idea` は直下にフラットに置き **ファイル名の接尾辞** (`_system` / `_user`) や
  ファイル名そのもの (`system.tmpl` / `user.tmpl` / `user_myidea.tmpl`) で区別している
  — 出典: `hassan-v2-backend/prompt/template.go:26`〜`:127` (パスを直書き)、
  `hassan-v2-backend/prompt/idea/system.tmpl` / `hassan-v2-backend/prompt/idea/user.tmpl`
- `business_plan/detailed` はさらに `query/` (検索クエリ用) と `web_research/` を持つ 3 階層

### 5-2. 言語別対応

- 方式: **同名 + `.en` 中間拡張子**。`GetTemplateWithLanguage` が
  `entity.LanguageEnglish` のとき `<base>.en<ext>` の存在を `filepath.Glob` で確認し、
  **あれば英語版、無ければ日本語版に暗黙フォールバック**する
  — 出典: `hassan-v2-backend/prompt/template.go:130`〜`:163`
- 英語版が用意されているのは **16 / 130 本のみ** (`idea` 13、`asset` 2、`business_plan` 1)。
  他は英語リクエストでも日本語テンプレートが使われる
- **言語を受け取らない取得関数が別系統で存在する**: `getTemplateNoLanguage` は
  `languageType` を取らず、末尾の空白も `TrimSpace` する
  (`GetTemplateWithLanguage` は TrimSpace しない)
  — 出典: `hassan-v2-backend/prompt/template.go:262`〜`:280`。
  利用箇所は `dify_*` 4 関数 (`:283` / `:292` / `:296` / `:305`) と
  `GetCompanyFromURL*` 2 関数 (`:313` / `:323`)
- テンプレート関数も 2 系統で異なる: `GetTemplateWithLanguage` は `wd` (withDefault) と `add`、
  `getTemplateNoLanguage` は `add` のみ
  — 出典: `hassan-v2-backend/prompt/template.go:150`〜`:153` vs `:263`〜`:267`

### 5-3. `dify_` の名前が残っているテンプレート (全 4 本)

`find prompt -name "dify_*"` の結果は以下の 4 本のみ。**いずれも現役で参照されている**。

| # | テンプレート | 取得関数 (`prompt/template.go`) | 呼び出し元 |
|---|---|---|---|
| 1 | `hassan-v2-backend/prompt/asset/system/dify_extract_asset_titles.tmpl` | `GetDifyExtractAssetTitlesSystem` (`:283`) | `hassan-v2-backend/usecase/asset/extract_asset_titles_llm.go:28` |
| 2 | `hassan-v2-backend/prompt/asset/user/dify_extract_asset_titles.tmpl` | `GetDifyExtractAssetTitlesUser` (`:292`) | `hassan-v2-backend/usecase/asset/extract_asset_titles_llm.go:33` |
| 3 | `hassan-v2-backend/prompt/asset/system/dify_generate_asset_descriptions.tmpl` | `GetDifyGenerateAssetDescriptionsSystem` (`:296`) | `hassan-v2-backend/usecase/asset/generate_asset_descriptions_llm.go:40` |
| 4 | `hassan-v2-backend/prompt/asset/user/dify_generate_asset_descriptions.tmpl` | `GetDifyGenerateAssetDescriptionsUser` (`:305`) | `hassan-v2-backend/usecase/asset/generate_asset_descriptions_llm.go:50` |

`Dify` を含む識別子は他に `prompt/service.go` のインターフェース宣言 4 件 + 実装 4 件
(`hassan-v2-backend/prompt/service.go:54`〜`:57` / `:261`〜`:274`)、
引数型 `DifyExtractAssetTitlesUserArgs` (`hassan-v2-backend/prompt/template.go:287`) /
`DifyGenerateAssetDescriptionsUserArgs` (`hassan-v2-backend/prompt/template.go:300`)、
テストのスタブ (`hassan-v2-backend/usecase/asset/generate_asset_descriptions_llm_test.go:26` / `:33`)。
`prompt/template.go:282` にはセクションコメント `// Dify Asset用のプロンプト関数` も残っている。

---

## 6. ストリーミングの実装

**SSE (Server-Sent Events) のみ。chunked ボディを直接返す経路は見つからなかった。**

### 6-1. 2 層構造

| 層 | 内容 | 出典 |
|---|---|---|
| LLM 層 | `Service.GenerateTextContentStream` が `<-chan GenerateTextContentStreamChunk` を返す。chunk は `Content` と `Error` の 2 フィールドのみ (**トークン数・停止理由は運ばない**) | `hassan-v2-backend/llm/interface.go:13`、`hassan-v2-backend/llm/types.go:89`〜`:100` |
| HTTP 層 | Gin。`SetupSSEHeaders` で `text/event-stream; charset=utf-8` + `Cache-Control: no-cache` + `Connection: keep-alive` + `X-Accel-Buffering: no` を設定 | `hassan-v2-backend/controller/controller.go:128`〜`:140` |

プロバイダ 4 実装すべてが `GenerateTextContentStream` を持つが、**中身の性質が異なる**:

| プロバイダ | 実装 | 出典 |
|---|---|---|
| OpenAI | 真のストリーム (`data:` 行を読み `finish_reason == "stop"` で終了) | `hassan-v2-backend/llm/openai/service.go:857` / `:976` |
| Gemini | ストリーム | `hassan-v2-backend/llm/gemini/service.go:762` |
| Claude | ストリーム | `hassan-v2-backend/llm/claude/service.go:344` |
| Exa | **非ストリーミング検索を実行し、結果をルーン単位で分割して擬似ストリーム化** (コメントに「後方互換」と明記) | `hassan-v2-backend/llm/exa/service.go:79`〜`:104` |

### 6-2. SSE を返す UseCase / エンドポイント

| # | エンドポイント | UseCase | イベント形式 | LLM ストリームを使うか |
|---|---|---|---|---|
| 1 | `POST /research-chats` (カスタムリサーチ) | `CustomResearchStreamUseCase` | **`event:` 行なしの生 `data: {json}`**。`type` フィールドで `status` / `content` / `complete` / `error` を区別 | **最終レポート生成のみ**ストリーム。planning・反復フェーズは非ストリーム |
| 2 | `POST /research-sheets` | `ResearchSheetAgentUseCase` | `SendSSEMessage` (`event:` + `data:`) | 未確認 (SSE ヘッダのみ確認) |
| 3 | 企画書チャット | `BusinessPlanChatUseCase` | `c.SSEvent("message", ...)` | **する** |
| 4 | 企画書 簡易モード生成 | `GenerateBusinessPlanUseCase` | `c.SSEvent("message", ...)` (`streamChannelAsSSE`) | **する** |
| 5 | 企画書詳細 (5 系統) | `businessplandetailed*` UseCase | `SendSSEMessage` で `status` / `complete` / `error` の 3 種 | しない (進捗通知のみ) |

出典: 1 = `hassan-v2-backend/controller/research.go:207` (`SetupSSEHeaders`) / `:231`〜`:232`
(`fmt.Fprintf(c.Writer, "data: %s\n\n", ...)` + `Flush`)、
ストリーム部は `hassan-v2-backend/usecase/research/custom_research_stream_operations.go:612`
(`generateFinalReportStream`)。
2 = `hassan-v2-backend/controller/research_sheet.go:190` (`@Produce text/event-stream`) / `:210`。
3 = `hassan-v2-backend/controller/business_plan.go:696` / `:704`。
4 = `hassan-v2-backend/controller/business_plan.go:862`〜`:870` (`streamChannelAsSSE`)。
5 = `hassan-v2-backend/controller/business_plan_detailed.go:130` / `:208`〜`:216` (他 4 箇所)。

### 6-3. 実装上の特徴

- **フォールバックはストリーム開始前に決まる**。`generateFinalReportStream` は
  フォールバック列を順に試し、チャンク途中でエラーが出た場合は次モデルで**先頭から再送**する
  (クライアントには既に途中まで送信済みのチャンクが残る)
  — 出典: `hassan-v2-backend/usecase/research/custom_research_stream_operations.go:618`〜`:656`
- SSE 送出前に不正 UTF-8 / BOM / U+FFFD を除去している
  — 出典: `hassan-v2-backend/usecase/research/custom_research_stream.go:435`〜`:451`
- 企画書チャットはストリーム完走時のみ DB 保存 (途中切断では保存しない)
  — 出典: `hassan-v2-backend/controller/business_plan.go:709`〜`:712`
- `GenerateTextContentStreamRequest` には `Ctx` フィールドが**無い**
  (非ストリームの `GenerateTextContentRequest` にはある)。
  クライアント切断でのキャンセル伝播はストリーム経路では効かない
  — 出典: `hassan-v2-backend/llm/types.go:79`〜`:94`、`hassan-v2-backend/llm/request_context.go:6`

---

## 7. 利用量・コストの計測

**結論: ほぼ計測していない。1 機能・1 プロバイダ・ログ出力のみ。DB 保存や集計は存在しない。**

| 観点 | 実測 | 出典 |
|---|---|---|
| 型の定義 | `llm.TokenUsage{PromptTokens, CompletionTokens}` が存在。`GenerateTextContentResponse.Usage` は `*TokenUsage` で「未設定の場合は nil」とコメント | `hassan-v2-backend/llm/types.go:102`〜`:113` |
| 値を詰めるプロバイダ | **OpenAI のみ**。`GenerateTextContent` の応答から `Usage` をマップする | `hassan-v2-backend/llm/openai/service.go:177`〜`:181` |
| Gemini / Claude / Exa | レスポンス型には `UsageMetadata` / `Usage` フィールドが**ある**が、`llm.TokenUsage` へマップする箇所は無い (`grep -n "TokenUsage" llm/gemini llm/claude llm/exa` → 0 件) | `hassan-v2-backend/llm/gemini/types.go:34` / `:108`、`hassan-v2-backend/llm/claude/types.go:25` / `:33` |
| ストリーム経路 | `GenerateTextContentStreamChunk` に usage フィールドが無いため、**ストリームでは一切取得できない** | `hassan-v2-backend/llm/types.go:96`〜`:100` |
| `Usage` を読む唯一の呼び出し元 | アイデア市場規模・CAGR の**検索実行フェーズのみ**。goroutine 間で mutex 下に加算 | `hassan-v2-backend/usecase/idea/idea_market_cagr_web_research.go:162`〜`:165` |
| コスト算出 | 同じ箇所に 1 件だけ。**単価がハードコード** (`costInputPer1M = 0.15` / `costOutputPer1M = 0.60`、コメントに「gpt-4o-mini-search-preview」と明記)。実際に使われたモデルに依らず同じ単価で計算する | `hassan-v2-backend/usecase/idea/idea_market_cagr_web_research.go:190`〜`:193` |
| 出力先 | `logger.SuggerLogger.Infow` に `query_count` / `prompt_tokens` / `completion_tokens` / `search_cost_usd` を出すだけ。**DB 保存・課金連携は無し** | `hassan-v2-backend/usecase/idea/idea_market_cagr_web_research.go:194`〜`:199` |
| `stop_reason` / `finish_reason` | `llm` の公開型 (`GenerateTextContentResponse` / `...StreamChunk`) には**フィールドが存在しない**。プロバイダ内部の JSON 型にはあるが、OpenAI のストリーム終端判定 (`== "stop"`) にしか使われず、外へは出ない | `hassan-v2-backend/llm/claude/types.go:23` (`StopReason`)、`hassan-v2-backend/llm/gemini/types.go:39` (`FinishReason`)、`hassan-v2-backend/llm/openai/types.go:30`、判定 `hassan-v2-backend/llm/openai/service.go:976` |
| 別系統の「トークン数」 | `hassan-v2-backend/usecase/idea/create_my_idea.go:562` に `"total_tokens_estimate"` というログがあるが、LLM 応答の usage ではなく**自前の推定値** | `hassan-v2-backend/usecase/idea/create_my_idea.go:562` |
| 紛らわしい dto | `dto.ResearchUsage{PromptTokens, CompletionTokens, TotalTokens}` と `ResearchChoice.FinishReason` は Dify / Perplexity 時代のレスポンス型の残骸。現在は履歴パースの入れ物として空のまま使われる (§1-1 参照) | `hassan-v2-backend/controller/dto/research.go:181` / `:191`〜`:195` |

イベントログは別系統で存在する (`EventLogsRepository` / `createEventLog`) が、
記録するのは**イベント種別のみでトークン・コストは含まない**
— 出典: `hassan-v2-backend/controller/research.go:200`〜`:204`
(`entity.EventTypeResearchStart` / `EventTypeResearchSimpleStart` を記録)。

---

## 8. `dify/` が dead code である裏取り

先行調査 (dify-inventory.md §1) の追認。**自分で実行したコマンドと結果**を示す。
すべて `hassan-v2-backend` のリポジトリルートで実行し、worktree コピー
(`.worktrees/` / `.claude/worktrees/`) を除外している。

### 8-1. 実行コマンドと結果

| # | コマンド | 結果 |
|---|---|---|
| A | `grep -rn "dify\." --include="*.go" . \| grep -v "/.worktrees/\|/.claude/worktrees/" \| grep -v "^./dify/"` | **2 件、いずれもコメント**。`usecase/business_plan/interfaces.go:16` と `usecase/idea/interfaces.go:13` の「Note: dify.Client, llm.Factory, aws.S3Clientなどは構造体のため、」。実コードの参照はゼロ |
| B | `grep -rn "hassan-v2-backend/dify" --include="*.go" . \| grep -v "/.worktrees/\|/.claude/worktrees/"` | **0 件** (exit 1)。`dify` パッケージを import している Go ファイルは存在しない |
| C | `for p in $(go list ./...); do go list -f '{{join .Imports "\n"}}' $p \| grep -q "hassan-v2-backend/dify" && echo "IMPORTER: $p"; done` | **`IMPORTER:` の出力なし**。ビルドグラフ上でも `dify` を import するパッケージは無い |
| D | `go list ./dify` | `github.com/aillio-dev/hassan-v2-backend/dify` — **成功**。パッケージ自体は削除されておらずビルド対象に含まれる (先行調査 §1 の 5 番と一致) |

### 8-2. 補足事実

- コメント B / C の結果は「`dify` パッケージへの参照が非 dify コードに一切無い」ことを
  **import 解決レベルで**示す。A は grep レベルの確認で、両者で二重に裏取りできている
- 一方で **設定・資産は残っている**: Dify API キー env 9 個
  (`hassan-v2-backend/di/provider.go:37`〜`:45`)、
  ワークフロー YAML (prod 7 本 / dev 8 本。dev のみ `company-info-from-url.yml` が
  prod に無く、代わりに dev には `extract-json-format.yml` を含む 8 本
  — `ls dify/workflow/prod dify/workflow/dev` で確認)、
  `Dify` 名を含むプロンプト関数 8 個 + テンプレート 4 本 (§5-3)
- **先行調査との差分**: dify-inventory.md §2 の「prod 7 本 / dev 8 本」は今回の実測と一致した。
  内訳も確認済み: prod / dev 共通が 7 本
  (`business-plan-chat.yml` / `business-plan.yml` / `company-info-from-url.yml` /
  `extract-asset-titles.yml` / `extract-json-format.yml` / `idea.yml` / `research-chat.yml`)、
  **dev のみに存在するのが `generate-asset-descriptions.yml` の 1 本**

---

## 9. 推測 (確信度つき)

- **リサーチシート・企画書系の「env で上書き可能」コメントは、後から provider を
  `*Config` 受け取りに直す前提で書かれたが直されなかった** — 確信度: 中。
  根拠: カスタムリサーチ・アイデア・アセット・企業情報の 4 系統は `*Config` を受け取る
  provider が実装済みで (`hassan-v2-backend/di/wire.go:212` / `:263` / `:287` / `:294`)、
  同じ書式のコメントを持つ 3 系統だけが引数なし (`:101` / `:116` / `:200`) という
  非対称になっているため。ただし設計意図を示すコミットメッセージ等は未確認
- **`DEFAULT_IDEA_THINK_FALLBACK_MODEL` の未配線は意図的ではなく漏れ** — 確信度: 中。
  根拠: env 定義・UseCase 側の参照・型のコメント (`hassan-v2-backend/usecase/idea/interfaces.go:30`)
  の 3 層すべてが揃っているのに provider だけが欠けている。ただし
  `hassan-v2-backend/di/wire_gen.go` は wire 生成物なので、`wire.go` 側の修正漏れが
  そのまま生成物に反映された形
- **`llm/factory.go:83` のエラーメッセージ内モデル一覧は `ResearchModels` と同期していない**
  — 確信度: 高。根拠: メッセージは `o3, gpt-4o-mini, gpt-5-nano, gpt-5-mini, gemini-2.5-pro,
  claude-sonnet-4-5 など` の 6 モデルだが、実際の map は 16 モデル (§3-2)。
  文字列リテラルなので map 変更時に自動追従しない
- **カスタムリサーチが「旧 research_chat の後継」である** — 確信度: 高。
  根拠: エンドポイント (`POST /research-chats`)・DB テーブル (`research_chats` /
  `research_conversation_histories`)・履歴 API の 3 点が Dify 時代から一致し、
  かつ Dify の `ResearchChat` を呼ぶコードが `controller/` に存在しない
  (`git log --oneline -S "dc.ResearchChat\|ResearchChatBlocking" -- controller/` → 0 件)。
  ただし「Dify のワークフロー内容と現行パイプラインが機能等価か」は**未検証**
  (`dify/workflow/prod` の `research-chat.yml` は 3467 行あり、内容比較は未実施)

---

## 10. 未調査・対象外

- **フロントエンド (`hassan-v2-frontend`) は未調査**。モデル選択 UI が
  `?model=fast|think` 以外の値を送る可能性、`config` を送る画面の有無は未確認
- **Dify ワークフロー YAML と現行パイプラインのプロンプト内容比較は未実施**。
  「機能等価か」「移植で落ちている指示が無いか」は本調査の範囲外
  (先行調査 dify-inventory.md §2 の「プロンプト本文の抽出作業が必要」がそのまま残る)
- **実行時挙動は未確認**。すべて静的読解。フォールバックが実際に発火する頻度、
  `default: ProviderOpenAI` に落ちるケースの有無は未測定
- **`llm/openai` / `gemini` / `claude` / `exa` の各実装内部の挙動差は未調査**。
  リトライ・タイムアウト・温度などのパラメータ既定値、`GenerateBusinessThumbnail` を
  Gemini 以外がどう扱うか (スタブか) は未確認
- **`usecase/research_sheet/research_sheet_agent.go` の LLM 呼び出し詳細は未確認**。
  §6-2 の表 2 行目「LLM ストリームを使うか」は SSE ヘッダの存在のみ確認しており、
  内部で `GenerateTextContentStream` を使うかは**未特定**
- **`idea_board` / `news` / `theme` / `company_mission` など §2 の表に現れない UseCase は
  LLM を呼ばないと判断した**が、これは `GetService*` 系の grep 結果に出てこなかったこと
  による判断であり、間接呼び出し (共通ヘルパ経由) の可能性は排除していない
- **`dify/` を削除して良いか、Dify SaaS の課金停止手続き**は先行調査どおり未解決。
  v2 リポジトリへの変更なので本調査では扱わない

---

## 抜き取り検証 (オーケストレーター実施。2026-07-29)

`orchestrating-delegation` skill ③ に従い、設計に影響する load-bearing な主張を一次ソースで照合した。
**モデル名は推測が混入すると設計を直接誤らせる**ため重点的に確認した。**照合 6 件すべて一致**。

| 照合項目 | 照合方法 | 結果 |
|---|---|---|
| 4 機能の移行先ファイルの実在 | `usecase/research/custom_research_stream.go` / `usecase/idea/generate_idea.go` / `usecase/company/generate_company_from_gen_ai.go` / `usecase/company/company_from_url_llm.go` / `util/json.go` / `llm/util.go` の存在確認 | **一致** (6 件すべて存在) |
| モデル名が実在する定数か | `hassan-v2-backend/llm/types.go` を grep | **一致**。`o4-mini` (`:46`) / `gemini-3-flash-preview` (`:56`) / `gemini-3.1-pro-preview` (`:57`) / `gpt-5.2` (`:44`) すべて定義済み。**捏造されたモデル名は無い** |
| `env/*.env` に `DEFAULT_` 行が無い | 3 環境ファイルからキー名のみ抽出 (値は読まない) | **一致** (0 件) → 実効モデルはコード内既定値 |
| fast / think の既定モデル | `hassan-v2-backend/llm/types.go:70` `:71` `:74` のコメント | **一致**。`ModelGemini3Flash` =「fast デフォルト」/ `ModelGemini3Pro` =「think デフォルト」/ `ModelGPT52` =「think フォールバック」 |
| `TokenUsage` を詰めるのは OpenAI のみ | `TokenUsage` をリポジトリ横断 grep (テスト除く) | **一致**。書き込みは `hassan-v2-backend/llm/openai/service.go:178` の 1 箇所のみ |
| think 既定モデルが `ResearchModels` に無い | `llm/types.go` の `ResearchModels` (〜`:212`) を確認 | **一致**。`ModelGemini3Flash` (`:210`) は含まれるが `ModelGemini3Pro` は含まれない |

### v3 設計への含意 (最重要: LLM 抽象の要件)

**v2 の LLM 抽象はそのままでは本番の可観測性要件 (O-2 / O-4) を満たせない**。理由:

1. **主系モデルが Gemini なのに、`TokenUsage` を詰めるのは OpenAI 実装のみ** —
   企画書・カスタムリサーチ・アイデア think の**主要経路でトークン数が取得できない**。
   「計測が 1 箇所にしかない」以前に、**主要プロバイダで計測不能**
2. **`stop_reason` / `finish_reason` が公開型に存在しない** — BE-6 (`max_tokens` 切り詰めの検出) が
   現在の抽象では**実装不可能**。v3 の LLM 抽象には必須フィールドとして持たせる必要がある
3. **未知モデルは `default` で OpenAI にルーティングされる** — 新モデル追加時に
   プロバイダを黙って間違える。**未知モデルはエラーにする**設計が要る
4. **用途別許可リストの不整合** — think 既定の `gemini-3.1-pro-preview` が `ResearchModels` に無い。
   許可リストと既定値を**同じ定義から導く**必要がある
5. コスト単価はハードコードで、集計結果は**ログのみで DB 保存なし** →
   アカウント単位の集計 (AC-2.2) は新規実装

**したがって D-B'' (「v2 の llm 抽象を v3 に持ち込む」) は「構造は踏襲するが、
usage / stop_reason / 未知モデル拒否を追加した上で」という条件付きになる**。
