# レビュー結果 — Task-3h (LLM 機能の移行設計)

> レビュー実施: 2026-07-30 / レビュアー: `design-reviewer` (別セッション。起草者ではない) / 1 巡目
> 基準: [08-production-gates.md](../../../.claude/rules/08-production-gates.md) /
> [feedback_review_patterns.md](../../../.claude/rules/feedback_review_patterns.md) / ルート `CLAUDE.md`
> **PoC 基準では判定しない**。「PoC では対象外だった」を省略理由として認めない

## レビュー結果サマリ

- **対象 (レビューした設計成果物・リポジトリ相対パス)**:
  - `docs/design/llm-migration.md` (659 行。§1 現状 / §2 LM-A〜LM-J / §3 判定手順 / §4 移行表 (PoC 13 + v3 新規 2 + v2 17 + 廃止 11) / §5 モデル / §6 プロンプト資産 / §7 切替順序 M-0〜M-9 / §8 品質確認 / §9 未確定 / §10 引き渡し)
- **整合確認のために読んだ (レビュー対象外・未編集)**: `docs/analysis/poc-prompt-inventory.md` /
  `docs/analysis/v2-llm-inventory.md` / `docs/analysis/dify-inventory.md` / `docs/design/architecture.md` /
  `docs/design/observability.md` / `docs/design/operations.md` / `docs/design/API/knowledge.md` ·
  `API/README.md` · `API/settings.md` · `API/themes.md` / `templates/backend-repo/CLAUDE.md.tmpl` /
  `aidlc-docs/inception/productionization/plan.md`
- **件数**: **重大 1 件 / 中 5 件 / 軽微 4 件**
- **判定**: **Freeze 不可**。重大 1 件は「生きているコードを廃止対象として引き渡す」種類であり、
  実装リポが表を字義通りに読むと本番機能が欠落する

### 実行した検証

```
$ make doc-lint
[doc-lint] 対象 78 ファイル / エラー 0 件 / 警告 29 件
  (本書由来は意図的な未回答 [Answer]: 5 件 = llm-migration.md:571 / :579 / :586 / :595 / :601
   → LM-Q1〜LM-Q5。リンク切れ・参照リポの不在ゼロ)

$ make check-traceability
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 46/46 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
  (AC-3.8 は本書 §0 の対応表・§4・§5・§7・§8 から参照されており宙吊りなし。
   **本レビュー中に AC 総数が 45 → 46 に増えた** — 別セッションが requirements.md を更新したため。
   最終実行は 46/46 で未カバーゼロ)
```

### 抜き取り照合 (本書について 10 件実施 / 網羅照合は未実施)

**「廃止」判断 (X-1〜X-11) を優先して照合した** — 誤って生きている機能を廃止すると本番で機能欠落になるため。

| # | 主張 (箇所) | 一次ソースでの結果 |
|---|---|---|
| 1 | **X-5**: 発散の自前ツールループ一式が未配線 (`internal/agent/diverge/` + `prompts/diverge/` 9 ファイル) | **プロンプト 9 ファイルは一致** (`find prompts/diverge` = orchestrator / input_validator / tools 3 / patterns 4 の計 9)。`diverge.Service` の生成が非テストコードに無いことも一致 (`grep "diverge\.NewService\|Service\b"` はコメント 2 件のみ = `cmd/devui/conversation_tools_generate.go:39`,`:60`)。**しかし `internal/agent/diverge/` パッケージ全体は生きている** → 重大 1 |
| 2 | **X-6**: `prompts.ResearchSystem` は宣言のみ | **一致** (`grep -rn "ResearchSystem" --include="*.go"` の結果が `prompts/embed.go:8` の 1 行のみ) |
| 3 | **X-4**: 企画書 8 タブ一括 (`idea_plan_system.md`) は同期 (非 SSE) 分岐のみ・MaxTokens 48000 | **一致** (`cmd/devui/idea_plan.go:73` に `const ideaPlanMaxTokens int64 = 48000`、`:421` の `callIdeaPlan` に「**同期経路 (AC-6) で全 8 タブを 1 ショット生成する従来ロジック**」、参照は `:429` の 1 箇所) |
| 4 | **X-2 / X-3**: `/api/evaluate` / `/api/deepdive` はルーティング登録のみで FE から呼ばれない | **ルーティング登録は一致** (`cmd/devui/main.go:620`-`:621`)。FE からの呼び出しが無いことは grep で 0 件 (`--include="*.ts" --include="*.tsx"`)。**置換の断定は確信度中**という出典の留保が本書にも引き継がれている |
| 5 | **X-8**: v2 の LLM による JSON 抽出は決定論的コードに置換済み・呼び出しゼロ | **一致** (`hassan-v2-backend/util/json.go` に `ExtractJSONFromResponse` / `HasMatchingBraces` / `CleanJSONString` / `IsValidJSON`。`GetJSONExtractionSystem` / `GetJSONExtractionUser` は `prompt/template.go:249`,`:257` の**定義のみで呼び出し元ゼロ**) |
| 6 | **X-9**: `hassan-v2-backend/dify` は dead code / YAML prod 7・dev 8 / `DIFY_*` env 9 個 | **全一致** (非 dify コードからの import 0 件 / `dify/workflow/prod/*.yml` = 7 · `dev/*.yml` = 8 / `DIFY_[A-Z_]*` のユニーク 9 件 / `dify/workflow/prod/research-chat.yml` = 3467 行 (LM-J の却下理由の根拠)) |
| 7 | **X-10 / X-11**: `Dify` を名に含むプロンプト関数 8 個 / `dto.ResearchUsage`・`ResearchChoice.FinishReason` | **一致** (`grep "func .*Dify" prompt/` = 8 件 / `controller/dto/research.go:181` の `FinishReason`・`:191` の `ResearchUsage`) |
| 8 | **P-4**: PoC は Agent で 6 タブ / service・bmc の 2 タブは直接 API | **一致** (`cmd/devui/idea_plan_managed.go:19`-`:27` に「engine=agent で managed agent が生成する 6 タブ」「service / bmc は engine に関係なく常に API 直叩き」+ 6 タブの列挙) |
| 9 | **§6.3 / D-6**: Agent 再発行対象は 4 本のみ | **一致** (`docs/analysis/poc-prompt-inventory.md:46`-`:53` の 4 行 = `idea_diverge_system` / `post_diverge_chat_system` / `idea_plan_agent_system` / `conversational_orchestrator_system`。本書 P-1〜P-4 に 1 対 1 対応) |
| 10 | **§1.2 a / b**: usage を詰めるのは OpenAI 実装のみ / §5.1 の候補モデル名が v2 に定義済み | **一致** (`hassan-v2-backend/llm/openai/service.go:178` が `llm.TokenUsage` を詰める唯一の箇所 / `llm/types.go:60`-`:61` に `claude-sonnet-4-5` と `claude-haiku-4-5-20251001`) |

**プロンプト資産の件数も再計算した**: `claude_managed_agents/prompts/` の `.md` は
10 (ルート) + 1 (`.original`) + 2 (`diverge/` 直下) + 3 (`diverge/tools/`) + 4 (`diverge/patterns/`) +
6 (`conversational/`) = **26 ファイル** (§1.3 と一致)。廃止 12 (X-4 の 1 + X-5 の 9 + X-6 + X-7) →
**移植対象 14 ファイル**も一致。

**対象外にした範囲 (正直な申告)**:

- **§4.2 の V-1〜V-17 の全数照合は未実施**。抜き取りは V-5 (「唯一 usage を読んでいる経路」) と
  V-16 (`o4-mini` の定義) のみで、残る 15 行の出典 (`v2-llm-inventory.md` §2-N と v2 のパス) は
  リンク・パスの実在のみ確認した
- **§3 の判定を全 32 行に適用し直す再判定は行っていない** (レビュアーが独立に分類し直すのは
  起草のやり直しに当たる)。判定基準の整合 (§3 ↔ `CLAUDE.md.tmpl` ↔ D-B') のみ確認した
- **§8 の品質確認手順の実行可能性** (ゴールデンセット 20 件を v2 の本番系で実行できるか・
  評価者 2 名を確保できるか) は運用側の未確定に依存するため判定していない
- **外部サービスの仕様** (Anthropic に埋め込み API があるか・Exa の検索品質) は検証不能。
  中 2 はこの点を「本書に書かれていない」として指摘している

---

## 重大 (Must Fix)

### 重大 1. X-5 の廃止対象が `internal/agent/diverge/` 全体になっており、**生きているドメイン型が廃止扱いで引き渡される**

- 該当: `docs/design/llm-migration.md:235` (§4.3 の X-5)
- **記述**: 対象 = 「発散の自前ツールループ一式: `claude_managed_agents/internal/agent/diverge/` +
  `claude_managed_agents/prompts/diverge/` 配下 9 ファイル」、Q0 の条件 = **①非テストコードからの呼び出しが無い**。
- **事実 (一次ソースで確認)**: 条件①が成り立つのは **`diverge.Service` (自前ツールループの入口) だけ**である。
  同じパッケージは**生きている経路から 200 回以上参照されている**:

  ```
  $ grep -rhno "divergeagent\.[A-Z][A-Za-z]*" --include="*.go" cmd/devui internal/db internal/agent/planner
    211 Idea          138 PlanTabID     67 PlanTabCompetitor   49 IdeaPlan
     37 Score          24 IdeaEvaluation  22 EmitAction        17 SSEEmitter …
  ```

  参照元には**廃止対象でない機能**が含まれる — `cmd/devui/conversation_tools_plan.go` (企画書タブ生成 = P-4)、
  `cmd/devui/idea_evaluate.go` (アイデア評価 = P-5)、`internal/db/idea_evaluations_store.go` (評価の永続化)、
  `internal/agent/planner/` (企画書オーケストレータ)、`internal/exaresearch/` (P-8 / P-12 の検索)。
  つまり **`PlanTabID` の 8 タブ定義・`Idea` / `IdeaPlan` / `Score` / `IdeaEvaluation` の構造・
  SSE エミッタは、本書が移植対象とした P-4 / P-5 / P-6 / P-8 の仕様そのもの**である。
- **なぜ本番で問題になるか**: §4.3 は「**無言で落とさないために**」根拠付きで列挙した表であり、
  §10.3 の引き渡しチェックリスト 1 が「廃止判定は §4.3 の 11 件」として実装リポに渡る。
  実装者がこの行を字義通りに読むと「`internal/agent/diverge/` は移植しない」と解釈し、
  **企画書 8 タブの ID 集合・評価スコアの構造・発散結果の型を移植元から外す**。
  これは本書が最も避けたいと宣言した「**移植したつもりの機能が無い**」(LM-B 却下案 (b)) の実現であり、
  しかも P-4 (Agent 再発行対象) と P-5 の仕様が消えるため影響が第 1 リリースの中核に及ぶ。
  加えて**この表の 根拠 列自身が「`Service` 一式」に限定している** — 対象列が自らの根拠より広い。
- **修正案**: X-5 の対象を実際に未配線な範囲に限定して列挙する
  (`internal/agent/diverge/service.go` / `orchestrator.go` / `toolset.go` / `prefetch.go` /
  `pattern_prompt.go` + `tools/` の 3 ツール実装 + `prompts/diverge/` の 9 ファイル)。
  そのうえで **「同パッケージの型・スキーマ・永続化・SSE エミッタは移植対象であり、
  v3 では `entity/` と `service/` に再配置する ([architecture.md](../../../docs/design/architecture.md) §3)」を
  1 行明記する** (どこへ行くかを書かないと、次の読者が同じ誤読をする)。
  §4.3 末尾の「廃止によって減る資産」は**プロンプトファイル 12 本の集計であり Go の型を含まない**ので、
  集計値は変わらない。

---

## 中 (Should Fix)

### 中 1. P-12 が要求する `route_kind` の新しい値が、計測項目の SSOT (observability.md) に存在しない

- 該当: `docs/design/llm-migration.md:191` (P-12) / `:551` (§9 の O-2 行)
- 本書は「Exa の検索呼び出しは LLM 呼び出しではないが、**課金を伴う外部 API 呼び出しであり
  `route_kind` を分けて記録する**」と決めている。
- 一方 `docs/design/observability.md` §4.2 の `route_kind` は **`managed_agent` / `direct_api` の 2 値**で、
  第 3 の値も「LLM 以外の課金 API を明細に載せる」という要求も書かれていない。
  `input_tokens` / `stop_reason` / `estimated_cost` などの必須フィールドが Exa 呼び出しでは埋まらないため、
  **同じ append-only テーブルに載せるのかも決まっていない**。
- **なぜ本番で問題になるか**: 1 巡目レビューの 中 7 (SSE 接続数メトリクスが SSOT に無い) と同型で、
  **要求元だけが知っている計測項目は実装されない**。C-5 (Exa) は §4 の 8 機能が使う経路なので、
  漏れると「LLM コストは見えるが検索コストは見えない」状態になり、
  AL-4 (日次コストの急増) が総額を捉えられない ([observability.md](../../../docs/design/observability.md) §4.6)。
- 修正案: `observability.md` §4.2 への追記要求として起票する
  (`operations.md` §10.2 の OP-F1 と同じ形)。最低限、①`route_kind` に `external_search` 等を追加するか
  別テーブルにするか ②トークン系フィールドを NULL 許容にするか ③単価テーブル (O-H) に検索単価を持つか、の 3 点。

### 中 2. C-7 (埋め込み) が LM-D の「例外は 2 つのみ」と両立するかが書かれていない (第 1 リリースに含まれる)

- 該当: `docs/design/llm-migration.md:110` (LM-D) / `:268` (C-7) / `:199` (N-2 の優先度 1) / `:447` (M-4 = RL-1)
- LM-D は「**Anthropic を主系とする。例外は 2 つのみ**: Web 検索 = Exa / 画像生成 = Gemini」と断定している。
  一方 C-7 (埋め込み) は「**未確定**」で、プロバイダの候補も「Anthropic に埋め込み機能があるか」も書かれていない。
  N-2 は**優先度 1 (第 1 リリース)**・M-4 は RL-1 なので、**先送りできる項目ではない**。
- **なぜ問題になるか**: 埋め込みが Anthropic 以外になるなら **LM-D の「例外は 2 つ」が事実として崩れ**、
  3 番目のプロバイダの gateway 実装 (§10.1 の 2)・単価テーブルの追加・API キーの Secrets 追加
  (`operations.md` §4.5 の棚卸し) が第 1 リリースのスコープに増える。
  逆に Anthropic に埋め込みがあるなら C-7 は「未確定」ではなく確定できる。
  **どちらでも影響が出るのに、影響範囲が書かれていない**のが問題 (LM-Q3 は画像生成について同じ論点を
  「維持するなら Gemini が 3 番目のプロバイダとして残る」と正しく書いており、C-7 だけが抜けている)。
- 修正案: C-7 の行に「①Anthropic に埋め込み API があるかの確認 ②無い場合の候補
  (OpenAI / Voyage / Gemini 等) ③選定が LM-D の例外数・§10.1 の gateway 実装数・単価テーブルに与える影響」を
  書き、§9.1 の `[Answer]` (LM-Q6) として起票する。**RAG を第 1 リリースから外す**選択肢も併記すると
  スコープ判断 (Q-3) に接続できる。

### 中 3. §6.3 の「再発行対象 4 本」と `operations.md` §5.2 の `prompts/agents.yaml` の関係が書かれていない

- 該当: `docs/design/llm-migration.md:420`-`:430` (§6.3)
- `operations.md` §5.2 は 2026-07-30 に「**再発行のトリガは `prompts/agents.yaml` の列挙**」を決定し、
  「発行コマンドが実際に送る集合と `agents.yaml` の列挙の一致」を `check-tool-contract.sh` の検査項目にした。
  本書 §6.3 は「対象がこの 4 本であること」を確定させると宣言しているが、**`agents.yaml` に一言も触れていない**。
- **なぜ問題になるか**: 「Agent に登録するプロンプトの集合」という同じ事実を、
  本書 (§6.3 の 4 本) と `agents.yaml` (実体) の 2 箇所が持つことになり、
  **どちらが正で、両者の一致を誰が担保するのかが決まらない**。
  §6.3 は「§4 の表の Managed Agent 行が増えたら D-6 の対象も増える」という対応関係だけを書いており、
  **その増加が `agents.yaml` に反映されないと再発行が走らない** (中 2 の決定の裏返し) ことに触れていない。
  LM-Q1 (P-3 を P-1 に統合するか) が「Agent が 3 本になる」形で決まった場合、
  `agents.yaml` の更新漏れは「統合したのに旧 Agent が再発行され続ける」になる。
- 修正案: §6.3 に「**`prompts/agents.yaml` が実体の SSOT であり、本節の 4 本はその初期値である**」
  「§4 の表で Managed Agent 行が増減したら `agents.yaml` と本節を同じ PR で更新する」を明記し、
  `operations.md` §5.2 へ相互参照を張る。

### 中 4. 「廃止 11 件」の内訳が LM-B の定義を満たさない行を含み、その数字が他文書へ転記されている

- 該当: `docs/design/llm-migration.md:240` (X-10) / `:239` (X-9) / `:241` (X-11) / `:653` (引き渡し 1)
- LM-B は「**3 条件のいずれかを満たすものを廃止**」と定義しているが、
  - **X-10** の Q0 条件列は「**— (命名整理)**」で、本文も「**4 本は現役だが、v3 では機能名で命名する**」。
    これは廃止ではなく**リネーム**であり、3 条件のどれも満たさない
  - **X-9** は「v2 リポジトリからの削除は v2 側の課題であり**本書の範囲外**」と自ら書いている
  - **X-11** は型 (`dto.ResearchUsage`) の非移植で、機能の廃止ではない
- **なぜ問題になるか**: 「廃止 11 件」は `aidlc-docs/inception/productionization/plan.md:124` と
  `aidlc-docs/aidlc-state.md:36` にも**数字として転記済み**で、
  「11 件の機能が v3 に無い」という理解が残る。実際に**機能として消えるのは 5 件**
  (X-1 テーマタグ推定 / X-2 旧評価 / X-3 旧深掘り / X-4 8 タブ一括 / X-5 自前ツールループ) と
  **v2 側 1 件** (X-8 LLM による JSON 抽出) であり、残りは資産整理である。
  廃止件数はユーザーへの「機能が減る」説明に直結するため、粒度が混ざっていると合意が取れない。
- 修正案: §4.3 を「**機能の廃止 (ユーザーに見える変化がある)**」と「**資産・命名の整理 (機能は不変)**」の
  2 群に分け、件数を別々に数える。X-10 は Q0 条件列を持たないので後者へ移す。
  併せて plan.md / aidlc-state.md の「廃止 11」も直す (本書の変更に追随する箇所として §10 に書く)。

### 中 5. §3 が判定線の SSOT と呼んでいる `CLAUDE.md.tmpl` 側に、§3 の「3 つの読み方」が無い

- 該当: `docs/design/llm-migration.md:124`-`:126` / `templates/backend-repo/CLAUDE.md.tmpl:296`-`:301`
- 本書は「`CLAUDE.md.tmpl` の『LLM の使い分け』表と D-B' が判定線の SSOT。本節はそれを適用手順に
  具体化するだけで判定線を変えない」と書いている。しかし tmpl の表は
  **「ツールを使う / 複数ターン回る / 出力が次の入力を決める → 1 つでも当てはまれば Agent」の 3 行だけ**で、
  §3 が加えた 3 つの読み方 (①固定パイプラインは複数ターンではない ②分類 → 分岐は自律判断ではない
  ③会話履歴を持つ chat は Agent ではない) が入っていない。
- **なぜ本番で問題になるか**: `CLAUDE.md.tmpl` は**実装リポに配られて常時ロードされる規約**であり、
  設計リポの本書を読まない実装者・エージェントの唯一の判定材料になる。
  tmpl だけを読むと **v2 の多段処理 5 系統・リサーチシートの分類 → 分岐・企画書チャット・ナレッジ RAG が
  すべて Agent 判定になる** — 本書 §4 が直接 API と決めた行と真逆で、
  §3 が「誤判定すると起きること」として列挙した状態そのものである。
  D-6 の再発行対象が 4 本から 9 本以上に増える (§3 の表が自ら書いている影響)。
- 修正案: tmpl の「LLM の使い分け」節に **3 つの読み方を 3 行で追記**し、
  「機能ごとの判定結果は設計リポの `docs/design/llm-migration.md` §4 が正」を 1 行入れる。
  本書 §10 の引き渡しに「tmpl への追記」を要求として起票する (`operations.md` §10.2 と同じ形)。

---

## 軽微 (Nice to Have)

1. **§1.3 の f の「Go インライン 7 箇所」の内訳が出典と一致しない** (`:82`)。
   本書は「match_functions / research_market ×2 / themes_tags / **evaluate ×2** / deepdive」を挙げるが、
   出典 `docs/analysis/poc-prompt-inventory.md` §1.2 の 7 行は
   「matching / research ×2 / themes_tags / **evaluate (1 行・:89 と :102 の 2 プロンプト)** / deepdive /
   **`internal/exaresearch/search_guidance.go`**」である。
   本書は `search_guidance` を落として `evaluate` を 2 と数えており、**合計 7 は偶然一致**している。
   §4.3 末尾の「移植対象は 14 ファイル + **4 箇所**」は出典の行数え基準 (7 − 3 = 4) で正しいため、
   §1.3 の f の内訳だけを直せば閉じる (`search_guidance` は P-12 として移植対象)。
2. **§5.3 の合否条件 3 が v3 新規機能に適用できない** (`:353`)。
   「⑤の平均が比較基準 (§8.1 の凍結出力) より 0.5 点以上下がらない」は
   N-1 / N-2 に比較基準が無い (§8.1 は「例外」として §8.3 の絶対基準のみで判定すると書いている)。
   §5.3 側にも同じ例外を 1 行置く (C-4 は N-1 を含み、C-7 は N-2 のみのカテゴリである)。
3. **§8.1 の凍結理由の記述が不正確** (`:491`)。「v2 は RL-4 で止まる」とあるが、
   `operations.md` §6.1 では **v2 の停止は RL-5**、RL-4 はドメイン単位の移送である
   (ドメインごとに「新規アクセスが 0 件」を確認するので、そのドメインについては RL-4 で実質使えなくなる)。
   「切替前にしか取れない」という結論は変わらないので、理由を「該当ドメインは RL-4 で
   新規アクセスを止めるため」に直す。
4. **本書の存在が他文書に反映されていない** (本書側では直せないが §10 に要求として残すべき)。
   `docs/design/API/settings.md:184`,`:197` と `docs/design/API/README.md:449` は
   `docs/design/llm-migration.md` を「**(未着手)**」と書いたままである。
   `docs/design/API/knowledge.md:217` の KN-Q2 も確定先が「D-B' の判定基準を適用して決める」のままで、
   **本書 `:198` の「`API/knowledge.md` §6 が本書に委譲」という記述は knowledge.md の実文言と一致しない**
   (委譲ではなく「自分で適用して決める」と書かれている)。
   `aidlc-docs/inception/productionization/plan.md:127` の **Task-3j** で追跡されているため実害は小さいが、
   本書側の「委譲」という表現は事実に合わせて直す。

---

## 本番観点カバレッジ (08-production-gates)

| ID | 状態 | 箇所 | レビュアーの所見 |
|---|---|---|---|
| **D-6** Agent ライフサイクル | **回答 (対象の特定)** | §6.3 / §9 | 再発行対象 4 本を出典付きで確定し、v2 移送でも増えないことを §4 の判定から導いている。**`agents.yaml` との接続が欠落 (中 3)** |
| **D-7** 段階リリース | **回答** | §7.1 / §9 | M-0〜M-9 と RL 段階の対応・並列可否・直列必須・順序の理由 4 点。RL-4 の完了条件を再定義せず参照している点も良い |
| **O-2** 全 LLM 経路の計測 | **回答 (索引)** | §4 / §9 | §4 の表が全経路の索引という位置づけは妥当で、`API/README.md` §4 の「3 本」との関係も明示済み。**Exa の `route_kind` が SSOT に無い (中 1)** |
| **O-3** コストと上限 | **部分回答 (理由あり)** | §5 / §9 | 上限は C-12 により設けない。モデル選定によるコスト決定と §5.3 の指標④で事前見積り。集計・アラートは observability へ委譲 |
| **O-4** 失敗の可観測性 | **参照** | §8.2 ③ / §8.3 Q-1・Q-2 | F-1〜F-5 を移行判定の入力に使う設計。分類の再定義をしていない |
| **A-6** LLM の越境 | **部分回答** | §3 / §8.3 の Q-5 | 「Agent を増やさないこと自体が越境面の縮小」という論理は妥当。強制点は architecture へ委譲し、Q-5 (他テナント ID を混ぜた入力で 0 件) を移行時の機械検査に入れているのは良い |
| **D-1 / D-5** | **参照 (境界を明示)** | §5.2 / §9 | プロファイル表にキーを書かない・環境オーバーレイは全フィールド必須、の 2 点のみ本書が持つ |
| **D-2** CI ゲート | **部分回答** | §6.1 R-2 / §8.3 | R-2 (80 文字以上の文字列リテラル禁止) は具体的。ゲート一覧の SSOT は他文書 |
| **D-3 / D-4 / D-8** | **対象外 (理由 + 先送り先あり)** | §9 | 妥当 |
| **A-1〜A-5 / A-7** | **対象外 (理由 + 先送り先あり)** | §9 | 妥当 |
| **O-1 / O-5 / O-6 / O-7** | **対象外 (理由 + 先送り先あり)** | §9 | 妥当 |

**無言の省略 (DR-2) は無し**。全 ID に回答・部分回答・対象外理由のいずれかがある。

### AC-3.8 の 4 要素

| 要素 | 回答 | 判定 |
|---|---|---|
| 機能ごとの v3 実装形態 (Agent / 直接 API / 廃止) | §4.1 (PoC 13 + v3 新規 2) / §4.2 (v2 17) / §4.3 (廃止 11)。判定基準は §3 | **回答あり**。ただし廃止の粒度が混在 (中 4)、X-5 の範囲が誤り (重大 1) |
| 使用モデルの見直し結果 | §5.1 (用途カテゴリ C-1〜C-7 + 初期モデル + 選定理由 + 確定方法) / §5.1 末尾の「v2 の実効モデルからの変更点」4 行 | **回答あり**。C-7 のみ未確定で、その影響が未記載 (中 2)。**PoC からの変更点は未調査として明記** (LM-R4) — 推測で埋めていない点は適切 |
| 機能単位の切替順序 | §7.1 の M-0〜M-9 + 並列 / 直列 + 順序の理由 | **回答あり** |
| 切替時の品質確認方法 | §8.1 (凍結) / §8.2 (3 段) / §8.3 (機械検査 Q-1〜Q-7) / §8.4 (合否を数値で + 不合格時の調査順序) | **回答あり**。DR-5 を最も強く潰している節 |

## 頻出パターン (feedback_review_patterns.md) の確認結果

| # | 判定 |
|---|---|
| DR-1 出典なしの断定 | **1 件検出** (軽微 4: knowledge.md §6 が「本書に委譲」しているという記述は実文言と不一致)。廃止判断 X-1〜X-11 は 10 件の抜き取りで**すべて出典が実在し内容も一致**。X-2 / X-3 の「確信度中」の留保も引き継がれている |
| DR-2 本番観点の無言の省略 | **なし** (§9 に対象外の理由と先送り先)。ただし **中 1 / 中 2 は「他文書に要求すべき事項の起票漏れ」**であり、放置すると実装されない種類の欠落 |
| DR-3 既存データの不在 | **該当なし (本書の論点外)**。プロンプト資産と LLM 経路の移行が対象で、データ移行は `data-model.md` / `operations.md` §6.2 が持つ。§8.1 が「切替後に現行系を動かして比べられない」という**既存系との時間的制約**を正しく扱っている |
| DR-4 PoC 実装のコピー設計 | **なし**。§10.1 の 4 で `conversation_tools.go` を「**構造は移植しない**」と明記、§10.1 の 2 で v2 の `default: OpenAI` を「踏襲しない」と明記。プロンプトの Go インラインを CI で禁止 (R-2) するのも構造的な潰し込み |
| DR-5 曖昧語による丸投げ | **なし** (特筆して良い)。「実測で決める」を §5.3 で入力・件数・指標・合否・時期・記録先まで数値化し、§8.4 で合否 3 条件と不合格時の調査順序まで固定している |
| DR-6 AC の宙吊り | **なし** (traceability 45/45)。AC-3.8 の 4 要素に §0 の対応表がある |
| DR-7 プロトタイプを仕様として扱う | **なし**。LM-R3 (テーマタグ推定の UI) と LM-Q4 (リサーチシートの画面) を「プロトタイプに確認できていない = **未調査**」として扱い、仕様としていない |
| BE-1 / BE-4 (データのバージョン参照) | R-4 (どのバージョンのデータを渡すかを構築ロジックで明示) + §8.4 の調査順序 1 (「**モデルを疑う前にここを見る**」) で構造的に潰している |
| BE-2 (設定値の散在) | LM-C / §5.2 のプロファイル表 1 箇所 + 「許可リスト・エラーメッセージのモデル一覧・単価キーをここから導出する」で潰している。§4 の表がモデル名を持たずカテゴリ ID を指す設計も同趣旨 |
| BE-6 (MaxTokens 切り詰め) | R-6 (MaxTokens はプロファイル表) + §8.3 の Q-2 (0 件) + §5.3 の合否 2 (「モデルの不採用ではなく設定の不足として扱う」) |
| BE-8 (schema と handler の乖離) | §8.3 の Q-6 + M-0 の ④ (tool 契約検査を共通基盤に置く) |
| BE-9 (Tools 全置換) | LM-A の却下案 (a) で Agent 固有の事故面として言及。承認材料の運用は operations へ委譲 (再定義していない) |
| BE-12 (還流のフィールド契約) | §8.3 の Q-4 (**読み手・書き手・テストが同一スキーマ定義から導かれる / 合成 JSON をテストに直書きしない**) で明示的に潰している |
| FE-6 (数値パーサのレンジ誤抽出) | §8.3 の Q-3 が「`120-420億円` 等を必ずテストケースに含める」と具体値で指定している |

---

## 良かった点

1. **「実測で決める」を検証可能な手順に落としている** (§5.3)。
   ゴールデンセット 20 件 / 選定基準 3 つ (入力長上位 3 件・現行で失敗した入力 2 件を含む) /
   指標 5 つ / 合否 5 条件 / 実施時期 (RL-1 内) / 記録先 (未作成ファイルを LM-R5 として起票) まで固定し、
   「**日付の無い測定結果を根拠にしない**」まで書いている。DR-5 の対策として本リポジトリで最も具体的な節。
2. **判定手順に「誤判定すると起きること」を実例と出典付きで併記している** (§3 の ※ 表)。
   「固定パイプラインは複数ターンではない」を `usecase/research/custom_research_stream.go` の
   段構成という実物で裏付けており、判定線の解釈が実装者ごとにぶれない。
3. **未調査を推測で埋めていない**。LM-R4 は「PoC が使っているモデル名が未調査 →
   **したがって『PoC からのモデル変更点』は本書では確定できない**」と、
   AC-3.8 の 2 要素目に穴が空くことを隠さずに書いている。LM-R7 (`CHAT_AGENT_ID` の発行コマンド未発見) も同様。
4. **比較基準の凍結を切替の前に置いた** (§8.1)。
   「切替後に現行系を動かして比べることができない」という時間的な一方向性を先に固定しており、
   移行の品質確認が「後から測れない」形で失敗する経路を塞いでいる。
5. **廃止を無言にしない仕組みを自分で用意している** (LM-B の却下案 (b) →§4.3 の表)。
   Q0 の条件番号 + パスを 1 行ずつ持たせた形式は、レビュー側が機械的に照合でき、
   実際に本レビューで 10 件の照合が短時間で行えた (重大 1 が見つかったのもこの形式のおかげである)。
6. **`route_kind` を分けて Exa も計測対象に含める判断** (P-12 / §9 の O-2 行)。
   「LLM 呼び出しではないから計測外」にせず、課金を伴う外部呼び出しとして総額に載せる方針は、
   O-3 の「片方だけでは総額が見えない」(`infrastructure.md` §9.3) と整合する。
   SSOT への起票が抜けている (中 1) だけで、判断自体は正しい。

---

## 判定 (Freeze 可否)

**Freeze 不可 (重大 1 件)**。

- **重大 1** は §4.3 の X-5 の**対象列を根拠列に合わせる**修正で閉じる (本書内で完結。数行)。
  ただし「生きている型をどこへ移すか」の 1 行を足さないと同じ誤読が再発する。
- **中 1 / 中 2 / 中 5** は**他文書への起票**を伴う (observability.md §4.2 / §9.1 の新しい `[Answer]` /
  `templates/backend-repo/CLAUDE.md.tmpl`)。`operations.md` §10.2 の OP-F1〜F4 と同じ形式で
  §10 に要求表を作るのが本リポジトリの既存作法と揃う。
- **中 3 / 中 4** は本書内で閉じる (§6.3 への相互参照 / §4.3 の 2 群への分割 + 転記先 2 ファイルの修正)。
- 修正後の再レビューは**本書の §4.3・§5.1・§6.3・§10 と、起票先文書の差分**を対象にすれば足る。

feature `productionization` 全体の Freeze 判定は他の設計成果物のレビュー結果
([review-operations-infrastructure.md](review-operations-infrastructure.md) の 2 巡目・未着手の `data-model.md`) にも
依存するため、本レビューでは扱わない。


---

## 指摘の反映 (2026-07-30・メインセッション)

| 指摘 | 反映先 |
|---|---|
| **重大 1: X-5 の廃止対象が `internal/agent/diverge/` 全体** | `docs/design/llm-migration.md` §4.3 の X-5 行を **`Service` 一式 + `prompts/diverge/` 9 本に限定**。加えて §4.3 に注記を新設し、**生きている型の行き先を表で明示** (`PlanTabID` / `IdeaPlan` → `entity/plan` / `Idea` / `IdeaEvaluation` → `entity/idea`)。「**パッケージ名の一致で廃止判断をしない**」を原則として明記。一次ソースで再照合済み (同パッケージの型が `cmd/devui/` の 10 ファイル以上から参照されていることを確認) |
| 中 1: `route_kind` の新値が observability に無い | `docs/design/observability.md` §4.2 の `route_kind` 行に **`external_search`** を追加 (Exa 等。値の追加は同表を SSOT として行う旨も明記) |
| 中 2: C-7 (埋め込み) と LM-D の両立が未記載 | §4.3 に注記を追加し、**LM-Q6 として §9.1 に起票** (Anthropic の埋め込み有無 / 候補 / 影響範囲 / RAG を第 1 リリースから外す選択肢)。暫定既定 = 「無ければ RAG を第 1 リリースから外す」(3 番目のプロバイダを増やさない) |
| 中 3: §6.3 と `agents.yaml` の関係が未接続 | §6.3 に「**`prompts/agents.yaml` が実体の SSOT・本節の 4 本はその初期値**」「§4 の表の増減と `agents.yaml` を同一 PR で更新」「一致は `check-tool-contract.sh` で機械担保」を追記 |
| 中 4: 「廃止 11 件」の粒度混在と他文書への転記 | §4.3 を **(1) 機能の廃止 6 件 (X-1〜X-5・X-8) / (2) 資産・命名の整理 5 件 (X-6・X-7・X-9〜X-11)** の 2 群に分離。X-10 はリネームとして (2) へ。**`plan.md` と `aidlc-state.md` の転記も同時に修正** |
| 中 5: `CLAUDE.md.tmpl` に §3 の 3 つの読み方が無い | `templates/backend-repo/CLAUDE.md.tmpl` の「LLM の使い分け」節に **誤りやすい 3 形の判定表** (固定パイプライン / 分類→分岐 / 履歴だけの chat) を追記し、機能ごとの確定判定は llm-migration.md §3 / §4 が SSOT と明記 |
| 軽微 4 件 | (別途対応。Freeze の阻害要因ではない) |

検証: `make doc-lint` エラー 0 (警告は意図的な `[Answer]` のみ。LM-Q6 追加で 1 件増) /
`make check-traceability` productionization 46/46・construction-workflow 24/24。

---

## 3 巡目 (確認・2026-07-30)

> レビュアー: `design-reviewer` (別セッション)。**1 巡目の記述と「指摘の反映」節は改変していない**。
> 範囲を **1 巡目指摘 (重大 1 / 中 5 / 軽微 4) の解消判定 + 回帰検査**に限定した確認レビュー。

### 対象 (レビューした成果物・リポジトリ相対パス)

| パス | 見た範囲 |
|---|---|
| `docs/design/llm-migration.md` | §1.3 f / §4.1 (P-2 / P-12) / **§4.3 全体 (2 群分離・X-5・2 つの注記)** / §5.3 / §6.3 / §7.1 / §8.1 / §9.1 / §10 |
| `docs/design/observability.md` | §4.2 (`route_kind` / 必須フィールド) / §4.4.1 / §4.6 の AL-4 / §5 の O-7 / O-H (`:49`) |
| `templates/backend-repo/CLAUDE.md.tmpl` | 「LLM の使い分け」節 (`:296`-`:311`) |
| `docs/design/API/knowledge.md` | KN-Q2 (`:217`) |
| `docs/design/API/settings.md` | `:186` / `:199` (llm-migration への参照) |
| `aidlc-docs/inception/productionization/plan.md` | `:124` (Task-3h の成果記述) |
| `aidlc-docs/aidlc-state.md` | `:36` (Task-3h 完了記録) |

**照合のために読んだ (レビュー対象外・未編集)**: `claude_managed_agents/internal/agent/diverge/plan.go` ·
`schema.go` · `cmd/devui/idea_plan.go` · `plan_tab_versions.go` · `idea_evaluations.go` ·
`theme_ideas.go` · `plan_brushup.go` · `conversation_tools_plan.go` / `docs/design/architecture.md` (D-A / §3.8.5)。

### 実行した検証

```
$ make doc-lint
[doc-lint] 対象 79 ファイル / エラー 0 件 / 警告 33 件
  (本書由来は意図的な未回答 [Answer]: 6 件 = llm-migration.md:615 / :623 / :630 / :639 / :645 / :654
   → LM-Q1〜LM-Q6。1 巡目の 5 件から LM-Q6 (埋め込みプロバイダ) が増えている。リンク切れ・参照リポの不在ゼロ)

$ make check-traceability
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 46/46 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
```

**抜き取り照合: 本節で 7 件** (operations / infrastructure 側の 10 件と合わせて計 17 件)。

| # | 主張 (箇所) | 一次ソースでの結果 |
|---|---|---|
| 1 | **X-5 の生きた型の所在** (`:255`-`:257`: `PlanTabID` / `IdeaPlan` は `plan.go`、`Idea` / `IdeaEvaluation` は `schema.go`) | **一致** (`internal/agent/diverge/plan.go:10` / `:69`、`schema.go:13` / `:156`) |
| 2 | 同注記が挙げる参照元 6 ファイル | **一致** (`divergeagent.` の出現数 = `idea_plan.go` 105 / `conversation_tools_plan.go` 19 / `plan_tab_versions.go` 3 / `theme_ideas.go` 3 / `idea_evaluations.go` 2 / `plan_brushup.go` 1) |
| 3 | 型の行き先 `entity/plan` / `entity/idea` が v3 の層規約に沿うか | **沿う**。`architecture.md` は `entity/` 配下のドメイン別サブパッケージを既に採っている (`entity/toolresult`。同 §3.8.5 の規約 1・`:517`)。`entity/**` は「共通層」扱いだがサブパッケージを禁じていない |
| 4 | `route_kind` への `external_search` 追加 (中 1) | **一致** (`observability.md:138`。「値の追加はこの表を SSOT として行う」も明記)。**ただし同表の必須フィールドとの両立が未処理** → 新規 中 1 |
| 5 | 「機能の廃止 6 + 資産整理 5」の転記 (中 4) | **一致** (`llm-migration.md:232`-`:235` / `plan.md:124` / `aidlc-state.md:36` の 3 箇所が同じ内訳。X-10 が (2) に移り「廃止ではなくリネーム」と明記) |
| 6 | §6.3 と `agents.yaml` の接続 (中 3) | **一致** (`:432`-`:441`。「4 本は初期値・実体の正は `agents.yaml`」「§4 の増減と同一 PR で更新」「一致は `check-tool-contract.sh` で担保」) |
| 7 | `CLAUDE.md.tmpl` の 3 形の判定表 (中 5) | **一致** (`:303`-`:309` に固定パイプライン / 分類→分岐 / 履歴だけの chat の 3 行 + 「機能ごとの確定判定は `llm-migration.md` §3 / §4 が SSOT」) |

**対象外にした範囲 (正直な申告)**: §4.2 の V-1〜V-17 の全数照合 (1 巡目と同じ) / §3 の判定の再適用 /
外部サービスの仕様 (Anthropic の埋め込み API の有無・Exa の課金単位) は検証不能。

### 1. 1 巡目指摘 (重大 1 / 中 5 / 軽微 4 = 10 件) の解消判定

| ID | 判定 | 確認した実体 |
|---|---|---|
| **重大 1** X-5 の範囲が広すぎ生きた型が廃止扱い | **解消** | `:245` の対象列が「**自前ツールループの実行部分のみ**: `Service` 一式 (`NewService` / `RunOnce` / `RunOnceWithEvents` / `RunWithHistory` / `ValidateInput` / `orchestratorForPattern` + `Orchestrator` / `toolset` / `pattern_prompt`) + `prompts/diverge/` 9 ファイル」に限定され、根拠列と一致した。`:253`-`:268` の注記で**生きた型の実測・行き先 (`entity/plan` / `entity/idea`)・「パッケージ名の一致で廃止判断をしない」原則**を明示。P-2 行 (`:181`) の「未配線の自前ツールループ版は廃止」も範囲と矛盾しない |
| **中 1** Exa の `route_kind` が計測 SSOT に無い | **部分解消** → **新規 中 1** | ① (値の追加) は `observability.md:138` で解消。**②③ (トークン系フィールドの扱い / 検索単価) が未処理** |
| **中 2** C-7 と LM-D の「例外は 2 つ」の両立 | **解消** | `:270`-`:275` に注記を新設 (LM-D が崩れる条件 / 増えるスコープ 3 点 = gateway 実装・単価テーブル行・Secrets 登録 / N-2 が優先度 1 であること) + **LM-Q6 として §9.1 に起票** (`:654` の `[Answer]`) + 暫定既定「Anthropic に無ければ RAG を第 1 リリースから外す」。`API/knowledge.md:217` も同じ暫定既定を引用しており整合 |
| **中 3** §6.3 と `agents.yaml` の関係 | **解消** | 上表 6。`operations.md` §5.2 への相互参照も入っている |
| **中 4** 「廃止 11 件」の粒度混在と他文書への転記 | **解消** | 上表 5。§4.3 が 2 群表 (`:230`-`:235`) を持ち、X-10 の扱いも明記。転記先 2 ファイルも同時修正済み。**§10.3 の 1 行だけ「廃止判定は §4.3 の 11 件」が残る** → 新規 軽微 1 |
| **中 5** `CLAUDE.md.tmpl` に §3 の 3 つの読み方が無い | **解消** | 上表 7 |
| **軽微 1** §1.3 f の内訳が出典と不一致 | **解消** | `:82` が「match_functions / research_market ×2 / themes_tags / **evaluate (1 行に 2 プロンプト)** / deepdive / **`internal/exaresearch/search_guidance.go`**」に修正され、「`search_guidance` は P-12 として移植対象 (廃止ではない)」も追記 |
| **軽微 2** §5.3 の合否条件 3 が v3 新規機能に適用不能 | **解消** | §5.3 の合否 3 に「**例外: v3 新規機能 (N-1 / N-2) は比較基準を持たないため §8.3 の絶対基準のみで判定する**」(C-4 は N-1 を含み C-7 は N-2 のみ、という注記付き) |
| **軽微 3** §8.1 の「v2 は RL-4 で止まる」 | **解消** | `:535`「**該当ドメインは RL-4 で新規アクセスを止める** — v2 サービス自体の停止は RL-5 だが…」に修正 |
| **軽微 4** 他文書が本書を「(未着手)」と記述 | **解消 (指摘した 3 箇所)** | `API/settings.md:186` / `:199` が `llm-migration.md` へのリンクに、`API/README.md:449` も「`llm-migration.md` が扱う」に。`API/knowledge.md:217` の KN-Q2 は「**回答済み (2026-07-30) — 直接 LLM API**。SSOT は `llm-migration.md` §4」に確定し、本書 `:198` の「委譲」表現との食い違いも解消。**同種の stale が他 13 箇所に残る** → 新規 軽微 3 |

**解消 9 / 部分解消 1 (中 1) / 未解消 0**。

### 2. 回帰検査

| 検査項目 | 結果 |
|---|---|
| X-5 の範囲限定が §4.1 / §7.1 (M-0〜M-9) / §10 と整合しているか | **矛盾なし**が、**型移植の作業が §7.1 と §10.1 に現れない** (§10.1 の影響レイヤー表は `config` / `gateway` / `prompts` / `service` / `usecase` / CI の 6 行で `entity/` が無い)。§10.3 の 1 が §4.3 を指しているため注記までは辿れる → 新規 軽微 1 |
| 「機能の廃止 6 + 資産整理 5」が §4.3 内と他文書で一貫しているか | **一貫** (上表 5)。件数の内訳 (X-1〜X-5 + X-8 / X-6・X-7・X-9〜X-11) が 3 文書で同一 |
| LM-Q6 の追加が §9.1 / doc-lint / 他文書と整合しているか | **整合** ([Answer] 6 件で doc-lint はエラーなし。`API/knowledge.md` が同じ暫定既定を引用) |
| `observability.md` §4.2 への値追加が同書内で矛盾を作っていないか | **1 件矛盾** → 新規 中 1 |
| 新規の SSOT 重複が生じていないか | **なし**。モデル名は §5.1 と `config` のみ、Agent 集合は `agents.yaml`、`route_kind` は `observability.md` §4.2 に単一化されている |

### 3. 新規指摘

#### 新規 中 1. `external_search` を LLM 明細に載せる決定が、同表の必須フィールドと単価テーブルと両立しない

- 該当: `docs/design/observability.md:138` (`route_kind`) / `:141`-`:146` (必須フィールド群) / `:49` (O-H 単価テーブル) /
  `docs/design/llm-migration.md:191` (P-12)
- **事実**: `route_kind` に `external_search` が追加された一方、同じ表は
  `input_tokens` / `output_tokens` を「**全プロバイダで取得する**」、`stop_reason` を
  「**抽象に必須フィールドとして持たせる**」と宣言している。Exa の検索呼び出しにはトークンも
  `stop_reason` も存在しない。さらに O-H の単価テーブルは「**モデル単価**」「**4 種のトークン単価を
  別々に持つ**」(`:154`) と定義されており、**リクエスト単位で課金される検索 API の単価行を持つ形になっていない**。
- **なぜ本番で問題になるか**: ①実装リポは「必須フィールドが埋まらないレコードをどう書くか」を
  設計に無い形で決めることになる (NULL 許容にするか別テーブルにするか) — `A-4` ではなく DR-5 型の丸投げ。
  ②`estimated_cost` が算出できないため、**AL-4 (日次コストの急増) が検索コストを含まない総額で発火する**。
  1 巡目の中 1 が指摘した「LLM コストは見えるが検索コストは見えない」状態が、値を追加しただけでは
  解消していない (`infrastructure.md` §9.3 の「片方だけでは総額が見えない」と同じ論点)。
- **修正案**: `observability.md` §4.2 に 3 行で足りる — ①`external_search` のレコードでは
  トークン 4 種と `stop_reason` を NULL 許容とする (または `route_kind` ごとの必須フィールドを表で分ける)
  ②`tool_calls` の代わりに検索件数など何を入れるかを決める ③O-H に「**リクエスト単価**」の行種別を追加し、
  `price_table_version` が検索単価の版も含むことを明記する。

#### 新規 軽微

1. **§10.3 の 1 が「うち廃止判定は §4.3 の 11 件」のまま**で、中 4 で分けた 2 群 (機能の廃止 6 / 資産整理 5) が
   **引き渡し点で再び 1 つの数字に戻っている**。plan.md / aidlc-state.md は直っているので、
   ここも「機能の廃止 6 + 資産・命名の整理 5」に揃える。
   併せて **§10.1 の影響レイヤー表に `entity/` 行 (X-5 の注記が指す `entity/plan` / `entity/idea` への型移植)** を
   足すと、重大 1 の修正が引き渡し表からも辿れるようになる (現状は §4.3 の注記のみ)。
2. §7.1 の M-1 / M-3 は `entity/plan` · `entity/idea` の型移植を前提にするが、依存列に現れない。
   軽微 1 と同時に「M-1 / M-3 の作業に型移植を含む」を 1 行足せば閉じる。
3. **`docs/design/` に「(未着手)」の stale が 13 箇所残っている** — `operations.md` / `observability.md` /
   `infrastructure.md` はすでに存在するのに未着手と書かれている
   (`docs/design/API/README.md:42`,`:135` ×2,`:443`,`:454`,`:463`,`:469` / `docs/design/API/news.md:116` /
   `docs/design/API/idea-boards.md:277` / `docs/design/architecture.md:709`,`:751`,`:759`,`:814`。
   `data-model.md` を未着手とする記述は正しい)。1 巡目の軽微 4 と同型で、
   **本書の指摘範囲外だが同じコミットで機械的に直せる** (`grep -rn "未着手" docs/design/` で全件が出る)。

### 4. Freeze 可否 (3 巡目)

| スコープ | 判定 |
|---|---|
| `docs/design/llm-migration.md` | **重大ゼロ → Freeze 可**。新規 軽微 1 / 2 は引き渡しの読みやすさの問題で、Freeze の阻害要因ではない。未確定 (LM-Q1〜LM-Q6) は `[Answer]` として起票済みで、影響範囲も本文にある |
| `docs/design/observability.md` (本書由来の変更分) | **重大ゼロ**。**新規 中 1 を反映してから Freeze する** (`external_search` を載せる決定と必須フィールド・単価テーブルの整合。3 行程度) |
| `templates/backend-repo/CLAUDE.md.tmpl` / `docs/design/API/knowledge.md` / `docs/design/API/settings.md` | **Freeze 可** |
| `aidlc-docs/inception/productionization/plan.md` / `aidlc-docs/aidlc-state.md` | **Freeze 可** (転記が本書と一致) |

feature `productionization` 全体の Freeze は、operations / infrastructure 側の残り 2 件
([review-operations-infrastructure.md](review-operations-infrastructure.md) の 3 巡目 新規 中 1 / 中 2) と
未着手の `docs/design/data-model.md` に依存する。
