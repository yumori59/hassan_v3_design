# Dify 依存の棚卸し (Task-2e)

> Q-4「Dify は廃止」/ Q-9「v3 で全部作り直す」の実行計画を立てるための事実収集。
> **設計判断は書かない** (判断は [architecture.md](../design/architecture.md) と `docs/design/llm-migration.md` 予定)。
> 実測日: **2026-07-28**。対象: `/Users/yuyamorishita/aillio/hassan/hassan-v2-backend` の作業ツリー。

## 0. 結論 (先に要点)

**v2 における Dify からの移行は、すでに大部分が完了している**。`dify/` パッケージは
**実コードから参照されていない (dead code)** 状態で、主要機能は v2 自身の LLM 層 (`hassan-v2-backend/llm`) に
移行済み。したがって:

- **「Dify 廃止」は v3 設計の作業ではなく、v2 側の掃除** (パッケージ削除・env 削除・命名整理) が残っているだけ
- **Q-9 の実質的な意味は「v2 の既存 LLM 機能を v3 へ移植する」** — Dify からの移行作業ではない
- 移植時の参照実装は `hassan-v2-backend/llm` + `hassan-v2-backend/prompt` + `usecase/*/*_llm.go`

## 1. 事実: dify パッケージは未配線

| # | 事実 | 出典 |
|---|---|---|
| 1 | `dify.` の package-qualified 参照は**コメント 2 件のみ**。実コードからの参照はゼロ | `hassan-v2-backend/usecase/business_plan/interfaces.go:16` / `hassan-v2-backend/usecase/idea/interfaces.go:13` (どちらも「Note: dify.Client …」というコメント) |
| 2 | DI (wire) に DifyService は不要と明記されている | `hassan-v2-backend/di/wire.go:160`「Services（企画書チャット・履歴はBE LLMに移行済みのため DifyService は不要）」 |
| 3 | 企画書生成は Dify を使わない実装に置き換わっている | `hassan-v2-backend/usecase/business_plan/generate_business_plan.go:216`「BEのLLMストリームを使用、Difyは使わない」/ `:323`「Difyを使わない」 |
| 4 | `dify/` の公開メソッド (ResearchChat / Idea / CompanyInfoFromURL / ExtractAssetTitles / GenerateAssetDescriptions / JsonExtractionChat / GetBusinessPlan*) の呼び出し元は**非 dify コードに存在しない** | 各メソッド名で `grep -rln "\.<Method>("` (dify/ 除外) → 0 件 |
| 5 | ただし `dify/` はビルド対象に含まれる (削除されていない) | `go list ./dify` が成功 |

## 2. 事実: 設定と資産は残存している

| 項目 | 実測 | 出典 |
|---|---|---|
| Dify API キーの env 定義 | **9 個**残存 (`DIFY_GET_COMPANY_FROM_URL_API_KEY` / `DIFY_BUSINESS_PLAN_CHAT_API_KEY` / `DIFY_IDEA_API_KEY` / `DIFY_BUSINESS_PLAN_API_KEY` / `DIFY_RESEARCH_CHAT_API_KEY` / `DIFY_EXTRACT_ASSET_TITLES_API_KEY` / `DIFY_GENERATE_ASSET_DESCRIPTIONS_API_KEY` / `DIFY_EXTRACT_JSON_API_KEY` / `DIFY_API_ENDPOINT`) | `hassan-v2-backend/di/provider.go:37`〜`:45` |
| エンドポイント設定 | 3 環境すべてに残存 | `hassan-v2-backend/env/.local.env` / `.dev.env` / `.prod.env` (いずれも `DIFY_API_ENDPOINT=https://api.dify.ai/v1`) |
| ワークフロー定義 (プロンプト本体) | **リポジトリ内に YAML で存在**。prod 7 本 / dev 8 本 | `hassan-v2-backend/dify/workflow/prod/` (`research-chat.yml` は 3467 行、他は 183〜249 行) |
| ワークフロー内のモデル | **OpenAI GPT-4o 系が主**、Gemini 2.0 Flash が 1 箇所 | `dify/workflow/prod/*.yml` の `name:` 指定を集計 (gpt-4o-prod ×6 / gpt-4o-mini-prod ×6 / gpt-4o-2024-08-06 ×5 / gpt-4o-mini-2024-07-18 ×4 / gpt-4o ×1 / gemini-2.0-flash-001 ×1) |

**含意**: プロンプト資産は Dify SaaS 上ではなく**リポジトリ内の YAML に入っている**ため、
移植時に読み出せる。ただし Dify のワークフロー構造 (ノード・分岐) を含む形式なので、
プロンプト本文の抽出作業が必要。

## 3. 事実: 機能ごとの現状

| Dify の機能 (ファイル) | 現状 | 出典 / 補足 |
|---|---|---|
| 企画書生成 `business_plan.go` (概要 / 機能 / ペルソナ / BMC の 4 メソッド) | **BE LLM へ移行済み** | `usecase/business_plan/generate_business_plan.go:216` `:323`。同 `:286` に「dify/business_plan.go と同様」の実装コメント |
| 企画書チャット・履歴 `chatbot.go` | **BE LLM へ移行済み** | `di/wire.go:160` |
| アセットタイトル抽出 `extract_asset_titles.go` | **BE LLM へ移行済み**。ただし**プロンプト関数名に `Dify` が残存** | 現行実装: `usecase/asset/extract_asset_titles_llm.go` が `prompt.GetDifyExtractAssetTitlesSystem/User` を使用 (`prompt/template.go:283` `:292`、テンプレートは `dify_extract_asset_titles.tmpl`) |
| アセット説明生成 `generate_asset_descriptions.go` | **BE LLM へ移行済み**。同様に `Dify` 名が残存 (テスト付き) | `usecase/asset/generate_asset_descriptions_llm.go` / `_test.go` が `prompt.GetDifyGenerateAssetDescriptions*` を使用 (`prompt/template.go:296` `:305`) |
| リサーチチャット `research_chat.go` (Blocking / Stream / 履歴取得) | **未配線**。移行先の特定は**未調査** | v2 には `research_chats` / `research_conversation_histories` テーブルが存在するため、別経路で稼働している可能性が高い (**推測・確信度中**) |
| アイデア生成 `idea.go` | **未配線**。移行先の特定は**未調査** | `llm/factory.go:54` に `GetIdeaServiceByModel` / `IdeaGenerationModels` があり、llm 層にアイデア生成の口がある (**推測・確信度高**) |
| URL からの企業情報取得 `comany_info_from_url.go` | **未配線**。移行先・機能の存続は**未調査** | — |
| JSON 抽出 `extract_json.go` | **未配線**。移行先・機能の存続は**未調査** | — |
| Dify 固有の配管 `client.go` | 未配線 (上記メソッドの HTTP クライアント) | — |

## 4. 事実: 現行 LLM 層 (移植時の参照実装)

- 抽象: `hassan-v2-backend/llm` (`factory.go` / `interface.go` / `types.go`)。
  プロバイダ実装は `llm/openai` / `llm/gemini` / `llm/claude` / `llm/exa`
- **モデルは列挙型で管理**され、用途別に許可リストがある
  (`llm/factory.go:57` `IdeaGenerationModels` / `:82` `ResearchModels`)
- 定義済みモデル (`hassan-v2-backend/llm/types.go:34`〜`:61`) — 抜粋:
  - OpenAI: `gpt-4.1` / `gpt-4o` / `gpt-4o-mini` / `gpt-5-nano` / `gpt-5-mini` / `gpt-5.2` / 各 search-preview / `gpt-image-1`
  - Gemini: `gemini-2.5-pro` / `gemini-2.5-flash` / `gemini-3-flash-preview` / `gemini-3.1-pro-preview` / `gemini-2.5-flash-image`
  - Claude: `claude-sonnet-4-5` / `claude-haiku-4-5-20251001`
- プロンプトは `hassan-v2-backend/prompt` の Go テンプレート (`*.tmpl`) として管理され、
  用途別の関数で取得する (`prompt/template.go`)

**含意**: 「使用モデルの見直し」(C-9) の作業対象は **Dify YAML の GPT-4o 系ではなく、
現行 llm 層で各機能が実際に選んでいるモデル**。どの機能がどのモデルを使っているかは
`usecase/*/*_llm.go` の呼び出しを個別に見る必要がある (**未調査**)。

## 5. 未調査 / 要確認

- **research_chat / idea / company_info_from_url / extract_json の現行経路** —
  移行済みなのか、機能自体が廃止されたのか。`usecase/` 側から機能名で追う必要がある
- **各機能が現在使っているモデル** — 上記 §4 の含意。C-9「モデル見直し」の入力になる
- **`dify/` を削除して良いか** — 参照ゼロだが、削除は v2 リポジトリへの変更なので v3 設計の範囲外。
  v2 側の課題として起票するかは要判断
- **Dify SaaS 側の課金・アカウントの停止手続き** — コードから廃止しても契約が残る可能性

## 6. 設計への影響 (判断は設計書側で行う)

1. **Q-9 の回答「v3 で全部作り直す」の実体が変わる** — Dify からの移行ではなく、
   **v2 の llm 層で動いている現行機能を v3 の 4 層 + Managed Agents へ移植する**作業
2. **`Dify` という名前を v3 に持ち込まない** — プロンプト関数名・テンプレートファイル名に
   `dify_` が残っているため、移植時に命名を整理する (そのままコピーすると
   廃止済み基盤の名前が新システムに残る)
3. **PoC と v2 で機能が重複する** — 企画書生成・アイデア生成・リサーチはどちらにも実装がある。
   v3 でどちらを正とするかは移植スコープ (Q-3) の判断対象
4. **モデル選定の枠組みは v2 に既にある** (`llm/types.go` の列挙 + 用途別許可リスト)。
   v3 で作り直すのではなく、この設計を引き継ぐのが妥当か検討する
