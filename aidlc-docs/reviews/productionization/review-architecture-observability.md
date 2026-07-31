# レビュー: アーキテクチャ / 可観測性 / 実装リポ雛形

> 実施日: 2026-07-29 / レビュアー: `design-reviewer` (別セッション・第三者視点・本番基準)
> 判定: **重大 5 件 — 修正後に再レビューが必要 (この 3 領域の Design Freeze 不可)**

## 対象 (レビューした成果物のリポジトリ相対パス)

- `docs/design/architecture.md` (244 行・全節)
- `docs/design/observability.md` (217 行・全節)
- `templates/README.md`
- `templates/backend-repo/CLAUDE.md.tmpl` / `templates/backend-repo/.github/workflows/ci.yml` /
  `templates/backend-repo/scripts/hooks/pre-commit` /
  `templates/backend-repo/.claude/agents/go-developer.md` / `templates/backend-repo/.claude/agents/code-reviewer.md`
- `templates/frontend-repo/CLAUDE.md.tmpl` / `templates/frontend-repo/.github/workflows/ci.yml` /
  `templates/frontend-repo/scripts/hooks/pre-commit` /
  `templates/frontend-repo/.claude/agents/react-developer.md` / `templates/frontend-repo/.claude/agents/frontend-reviewer.md`
- `templates/infra-repo/CLAUDE.md.tmpl` / `templates/infra-repo/.github/workflows/ci.yml` /
  `templates/infra-repo/scripts/hooks/pre-commit` / `templates/infra-repo/.claude/agents/infra-engineer.md`
- `templates/shared/.claude/skills/test-driven-development/SKILL.md` /
  `templates/shared/.claude/skills/implementing-robustly/SKILL.md`

**対象外** (別レビュアー担当): `docs/design/auth.md`、`docs/design/API/`。
参照のみ (事実の出典として): `docs/analysis/`、`aidlc-docs/inception/productionization/requirements.md` / `plan.md`。

## 実行した検証

```
$ make doc-lint
...
[WARN ] ./docs/design/architecture.md:227 未確定マーカー: 227:  (design_memo.md への相対リンク) の TOD…
[WARN ] ./docs/design/auth.md:537 未回答の [Answer]:
[WARN ] ./docs/design/auth.md:542 未回答の [Answer]:
[WARN ] ./docs/design/auth.md:548 未回答の [Answer]:
[WARN ] ./docs/design/design_memo.md:13 未確定マーカー: ...
[doc-lint] 対象 54 ファイル / エラー 0 件 / 警告 18 件      → exit 0
```

```
$ make check-traceability
[traceability] productionization: 22/22 カバー — OK
[traceability] 照合 1 feature / 未カバーあり 0 feature      → exit 0
```

**リンク切れ・参照先不在は 0 件** (本レビュー対象の 2 文書が引用する参照リポパスはすべて実在)。
警告 18 件は `design_memo.md` (ユーザーの生メモ) と `auth.md` の未回答 `[Answer]` 由来で、
本レビュー対象の 2 文書に起因するのは `architecture.md:227` の 1 件 (memo の未確定事項の引用) のみ。

```
$ bash scripts/doc-lint.sh aidlc-docs/reviews/productionization/review-architecture-observability.md
[doc-lint] 対象 1 ファイル / エラー 0 件 / 警告 0 件      → exit 0
```

> **申し送り (本レビューの範囲外)**: 上記の後に別セッションが作成した
> `aidlc-docs/reviews/productionization/review-auth-api.md` にリンク切れ (`../observability.md`) があり、
> 現時点の `make doc-lint` はエラー 1 件で落ちる。本レビュー対象の成果物に起因するものではないため
> 修正していない (起草側で `../../../docs/design/observability.md` へ直す必要がある)。

> **注意**: `check-traceability` は **AC-ID の出現**を照合するだけで、**回答の有無は検証しない**。
> 22/22 カバーでも AC-3.3 / AC-3.4 / AC-3.6 / AC-3.7 は「未回答のまま ID 参照だけが存在する」状態
> (`aidlc-docs/inception/productionization/plan.md:32`-`:36`)。カバレッジ表はこれを区別して記載した。

## 一次ソースで照合した事実 (17 件・すべて読み取り専用)

| # | 設計の記述 | 一次ソース | 結果 |
|---|---|---|---|
| 1 | **`stop_reason` が公開型に無い** (D-B''②・F-1 の前提) | `hassan-v2-backend/llm/types.go` 全 284 行 | **一致**。`TokenUsage` は `PromptTokens`/`CompletionTokens` のみ、`stop_reason` 相当は公開型に無い。プロバイダ内部型には存在 (`hassan-v2-backend/llm/gemini/types.go:39`・`hassan-v2-backend/llm/claude/types.go:23`) — 「公開型に無い」という限定が正確 |
| 2 | **usage を詰めるのは OpenAI 実装のみ / 読み出しは 1 箇所 / DB 保存なし** | `hassan-v2-backend/llm/openai/service.go:178` (リポ全体の `TokenUsage` 参照 4 件のうち唯一の書き込み)、読み出しは `hassan-v2-backend/usecase/idea/idea_market_cagr_web_research.go:162`、`hassan-v2-backend/db/schema.sql` にトークン/コスト列なし | **一致** |
| 3 | **主系モデルは Gemini** | `hassan-v2-backend/usecase/idea/generate_idea.go:198` / `hassan-v2-backend/usecase/idea/evaluate_ideas.go:192` が `ModelGemini3Pro` を既定 | **一致** (アイデア生成・評価の既定)。ただし OpenAI 系モデル定数の参照も多数あり、「主系」はアイデア系経路に限る表現 |
| 4 | **未知モデルが暗黙に OpenAI へ落ちる** (D-B''③) | `hassan-v2-backend/llm/factory.go:117` `default: return ProviderOpenAI` | **一致** |
| 5 | **prod でリクエストログが出ない** | `hassan-v2-backend/router/router.go:50`-`:51` (`AppEnv` が local/dev のときだけ `RequestLoggerMiddleware` を登録) | **一致** (行番号も一致) |
| 6 | **zap を常に production 設定で生成** | `hassan-v2-backend/logger/logger.go:10` | **一致** (行番号も一致) |
| 7 | **`secrets` 未使用 / `.env` をイメージに焼き込み** (D-5) | `hassan-v2-backend/stacks/prod/ecs-task-def.json` (`secrets` ブロック無し、`environment` は `GO_ENV` のみ)、`hassan-v2-backend/Dockerfile` の `COPY . .` | **一致**。追加事実: prod の CMD が `air` (ホットリロード) で、SDK 入りイメージをそのまま実行 → 中 12 |
| 8 | **ログは awslogs で `/ecs/hassan-v2-api` へ** | `hassan-v2-backend/stacks/prod/ecs-task-def.json` | **一致** |
| 9 | **prod は desiredCount 1・コンテナヘルスチェック無し・ロールバックは circuit breaker のみ** | `hassan-v2-backend/stacks/prod/ecs-service-def.json` (`desiredCount: 1`、`deploymentCircuitBreaker.rollback: true`)、task-def に `healthCheck` 無し | **一致** |
| 10 | **`activity_logs` / `event_logs` が稼働中** (O-6) | `hassan-v2-backend/db/schema.sql:482` / `:586` | **一致** |
| 11 | **PoC のコスト推定は単価ハードコード** | `claude_managed_agents/internal/agent/diverge/result_helpers.go:180`-`:190` | **一致**。追加リスク: `default` 分岐で**未知モデルに既定単価を当てて黙って誤る** → 重大 4 |
| 12 | **custom tool は 9 件** (`architecture.md:94`) | `claude_managed_agents/cmd/devui/conversation.go:774`-`:790` の 9 分岐 (registry は 8 件 + `generate_ideas` は SSE ブリッジ側) | **一致** (出典が付いていないのみ → 軽微 5) |
| 13 | **PoC は一部経路のみ `stop_reason` を検出** | `claude_managed_agents/cmd/devui/conversation_tools_matching.go:112`、`claude_managed_agents/cmd/devui/idea_evaluate.go:192` 他 5 箇所 | **一致** |
| 14 | **PoC はタイムアウト・回数上限を持たない** (§4.4 の「実測がない」) | `claude_managed_agents/internal/session/` / `internal/stream/` に `WithTimeout` は `interruptTimeout` のみ | **一致** |
| 15 | **(結論を左右) Managed Agent の usage は 4 カウンタで届く** | `claude_managed_agents/internal/stream/processor.go:65`-`:68` — `InputTokens` / `OutputTokens` / `CacheReadInputTokens` / `CacheCreationInputTokens` | **設計に反映されていない** → **重大 4** |
| 16 | **(結論を左右) v2 のトランザクション規約** | `hassan-v2-backend/CLAUDE.md:30`「UseCase 層が `db.Begin()`〜`Commit()` を管理。Repository は `XxxWithTx` を提供するのみ」、`hassan-v2-backend/usecase/repository_interfaces.go:21` (`tx pgx.Tx` を引数で渡す)。ただし `hassan-v2-backend/repository/asset.go:150`・`hassan-v2-backend/repository/business_plan_detailed.go:100` 他で Repository 内 `db.Begin` の逸脱が実在 | **設計に機構が書かれていない** → **重大 1** |
| 17 | **(結論を左右) v2 LLM 抽象の形** | `hassan-v2-backend/llm/interface.go:8`-`:45` — 全 11 メソッド中 usage を載せられる戻り型は `GenerateTextContentResponse` の 1 つのみ。`WriteReport` は `(string, error)`、ストリームチャンクは `Content`/`Error` のみ。`ctx` は `GenerateTextContentRequest.Ctx` (「省略可」) だけ | **D-B'' の 3 点追加では不足** → **重大 5** |

**誤りは見つからなかった** (17 件すべて記述と一致)。結論を左右する 3 件 (#15 / #16 / #17) は
「記述が誤っている」のではなく **一次ソースにある事実が設計に取り込まれていない**類の欠落で、
重大 1 / 4 / 5 として指摘した。事実の出典密度は高く、DR-1 (出典なしの断定) は軽微 1 件のみ。

---

## レビュー結果サマリ

- **件数**: 重大 **5** / 中 **16** / 軽微 **9**
- **DR-2 (本番観点の無言の省略) は無し** — `08-production-gates.md` の A/O/D 全 22 ID に
  `architecture.md` §5 の行が存在する。ただし **D-6 は「回答」と書かれているが機構が存在しない**
  (重大 2)、**O-5/O-6/O-7 は `observability.md` で回答済みなのに `architecture.md` では未回答**
  (中 1) という**状態表記の不正確さ**が残る
- 最も費用対効果が高い修正は **重大 1 (トランザクション機構)** と **重大 3 (フックの実行権限)** —
  どちらも記述量は数行だが、放置すると設計で決めた保証が実装リポで丸ごと無効になる

---

## 重大 (Must Fix)

### 重大 1. トランザクションの受け渡し機構が未定義。さらに「Service→UseCase 禁止」と §3 の指示が正面から矛盾しており、15 ステップ配置例をそのまま実装できない

**該当**: `docs/design/architecture.md:124`-`:126` (補助原則)、`:146`-`:149` (ステップ 12・13・15)、
`:153`-`:155` (迷いやすい点 1)、`:83` (責務表の Service 禁止事項)。
雛形側の同趣旨: `templates/backend-repo/CLAUDE.md.tmpl:45`、
`templates/backend-repo/.claude/agents/go-developer.md:44`、
`templates/backend-repo/.claude/agents/code-reviewer.md:25`-`:26`。

**矛盾の中身**:

| 行 | 記述 |
|---|---|
| `architecture.md:124` | 「**Service から UseCase は禁止**」 |
| `architecture.md:154` | 「採番・一意制約に関わる書き込みは **UseCase 側の関数を呼び出す形にする**」 |
| `templates/backend-repo/CLAUDE.md.tmpl:45` | 「禁止依存: … **Service→UseCase** …」 |

`generate_plan` / `set_theme_name` / `match_functions` は **ツールとしてループ中に呼ばれ**
(`claude_managed_agents/cmd/devui/conversation.go:616` / `:642` / `:655`)、そこで生成物を保存する。
つまりステップ 13 (生成物の永続化と採番 = UseCase) は**ステップ 7 の Agent ループの内側で発生する**。
実装者は「Service から UseCase を呼ぶ (禁止依存に違反)」か「Service が独自にトランザクションを張る
(責務表に違反)」の二択に追い込まれる。

**機構の不在**: `:126` は「トランザクションは UseCase が張ったものを引き継ぐ」と書くが、
**引き継ぎ方が書かれていない**。v2 の実装は `tx pgx.Tx` を Repository メソッドの引数で明示的に渡す方式
(`hassan-v2-backend/usecase/repository_interfaces.go:21`、規約は `hassan-v2-backend/CLAUDE.md:30`)。
この方式を Service 経由に延長すると Service のシグネチャに `pgx.Tx` が現れ、
責務表 `:83` の「Service の禁止事項: トランザクション管理」と衝突して見える。
`context.Context` に tx を載せる方式もあるが、v2 に前例が無く、選ばないまま実装に入ると
**リポジトリ内で 2 方式が混在する** (v2 では既に `hassan-v2-backend/repository/asset.go:150`・
`hassan-v2-backend/repository/business_plan_detailed.go:100` 他で Repository 内 `db.Begin` の逸脱が起きている)。

**なぜ本番で壊れるか**: ステップ 12 (台帳 write-through / Service) と ステップ 13 (生成物の採番 / UseCase)
が別トランザクションになると、ステップ 15 (失敗時の巻き戻し / UseCase) が台帳を戻せない。
会話 1 ターンの中で「企画書は保存されたが台帳は未更新」「採番だけ進んで本体が無い」という
中間状態が本番データに残る — **BE-10 (台帳への write-through 欠落)** と
**BE-11 (バージョン採番のサイレント失敗)** が、設計段階で潰したはずの形で再発する。

**修正案** (いずれか 1 つを選び §3 に明記する):

1. **outbound port 方式 (推奨)**: 採番・一意制約を伴う書き込みを `interface` (例
   `PlanWriter interface { SavePlan(ctx, tx, input) (version int, err error) }`) として **UseCase 側に定義**し、
   実体を UseCase が `ToolDispatcher` に注入する。依存方向は Service→port のままなので
   「Service→UseCase 禁止」を破らない。`:154` の「UseCase 側の関数を呼び出す形にする」をこの表現に置き換える。
2. **tx 明示渡し方式**: Service の書き込み系メソッドを `func (s *X) Do(ctx context.Context, tx pgx.Tx, …)`
   に統一し、責務表の Service 禁止事項を「トランザクションの**開始・コミットをしない** (受け取った tx で書く)」
   に精密化する (v2 と同形なので学習コストが最小)。

あわせて `:157`-`:158` の「ターン全体で 1 トランザクション」既定は、ステップ 7 のツールループが
外部 API 待ちを含む (数十秒〜分) ことと両立しない可能性が高い。**「台帳と生成物のどちらを
逐次コミットするか」を『要検証』ではなく既定として決める**こと (推奨: 生成物は各ツール成功時に
1 トランザクションでコミット、会話状態は最後に更新。長時間トランザクションで RDS の接続と
vacuum を詰まらせる方が本番リスクが大きい)。

---

### 重大 2. 設計が「CI で機械強制する」と書いたゲート 3 件が雛形に 1 つも実装されていない (A-1 / A-4 / D-6)

**該当**: `docs/design/architecture.md:182` (A-4「所有者引数の無い単一取得メソッドを **CI で禁止**」)、
`:198` (D-6「**CI で** schema ↔ handler ↔ prompt の 3 者一致を検査する」)、
`:194` (D-2 の実現物として `templates/backend-repo/.github/workflows/ci.yml` を指名)。
`docs/design/auth.md:450` / `:491` も CI 検査をマージ条件に含めると規定 (別レビュー範囲だが
`architecture.md` §5 が参照している)。

**雛形の実態** (`templates/backend-repo/.github/workflows/ci.yml` 全 64 行):
`go build` / `go vet` / `golangci-lint` / `go test` / 生成物差分 / OpenAPI 差分の **6 ステップのみ**。
上記 3 検査はいずれも無い。`templates/backend-repo/scripts/hooks/pre-commit:57`-`:64` の
Agent 関連は `echo` による注意喚起だけで**非ブロック**。人手の観点として
`templates/backend-repo/.claude/agents/code-reviewer.md:49`-`:50` に残っているのみ。

**裏取り**: AC-3.3 (「Managed Agent の発行・更新がデプロイ手順に組み込まれている / コードだけ先行して
デプロイされない仕組みがある」) を参照している成果物は
`aidlc-docs/inception/productionization/requirements.md` と `plan.md` **だけ**で、
設計書・雛形のどこにも無い。`plan.md:32` は AC-3.3 を「骨格で方針のみ (D-6)」と正しく評価しているのに、
`architecture.md:198` は D-6 を「**回答**」としている。**雛形には deploy ワークフローが 1 本も無い**
(3 リポいずれも `ci.yml` のみ) ため、Agent 再発行をデプロイ手順に組み込む場所自体が存在しない。

**なぜ本番で壊れるか**: BE-8 / BE-10 は「機能が黙って死ぬ」故障で、テストが通り CI が緑のまま出る。
`08-production-gates.md` が「D-6 は PoC と本番の最大の運用差」と書いているとおり、
人手のレビュー観点に落とした時点で必ず抜ける。A-4 の検査欠落はテナント越境 (v2 の
`GET /themes/:id` で実際に漏れた事象) の再発を許す。

**修正案**:

1. `templates/backend-repo/.github/workflows/ci.yml` に 3 ジョブを追加する:
   - **agent-consistency**: `prompts/*.md` のツール説明・tool schema (JSON)・Go handler のパースキーを
     突き合わせ、不一致で `exit 1`。実装は Go の小さな `tools/agentcheck` として雛形に骨格を置く
     (schema を単一ソースから生成する構成なら「生成物差分チェック」に統合してもよい)
   - **tenancy-signature**: `go/ast` で Repository の公開メソッドを走査し、所有者型引数
     (`AccountID` / `ContractID` 型) を持たない `Get*ByID` / `List*` を検出して `exit 1`
   - **route-auth**: router 登録の全パスが認証ミドルウェアを通ることを検査 (許可リストは
     `/alive` 等に限定し、リストの変更は PR で目に見えるようにする)
2. `templates/backend-repo/.github/workflows/deploy.yml` を追加し、**Agent 発行/更新ステップを
   イメージデプロイの前段に置く** (`prompts/` または schema に差分がある場合のみ実行し、失敗したら
   デプロイを止める)。
3. `architecture.md` §5 の D-6 を「**部分** (方針のみ。手順は `docs/design/operations.md` = Task-3d)」に、
   A-4 の「CI で禁止」を「CI 検査を雛形に実装済み/未実装」のどちらかが分かる表現に修正する。

---

### 重大 3. pre-commit フックが実行権限なしで配布されており、README の手順どおり導入しても 1 度も走らない

**該当**: `templates/backend-repo/scripts/hooks/pre-commit`、
`templates/frontend-repo/scripts/hooks/pre-commit`、`templates/infra-repo/scripts/hooks/pre-commit`
(3 ファイルすべて `-rw-r--r--`)。導入手順は `templates/README.md:36`
(`ln -sf ../../scripts/hooks/pre-commit .git/hooks/pre-commit` のみ。`chmod` が無い)。

**何が起きるか**: git は**実行可能でないフックを黙って無視する** (エラーも警告も出ない)。
`cp -R` はモードを保持するので、`templates/README.md:19`-`:30` の手順を正確に実行した実装リポでは、
以下のゲートが**すべて無効な状態で運用が始まる**:

- backend: `go build` / `go vet` / 差分パッケージの `go test` (`CLAUDE.md.tmpl:98`-`:99` が
  「pre-commit で強制」と明記)
- frontend: `tsc --noEmit` / 関連テスト (`CLAUDE.md.tmpl:85`)
- infra: `terraform fmt -check` / `validate`、および
  **`.tfstate` / `.terraform/` のコミット防止** (`templates/infra-repo/scripts/hooks/pre-commit:14`-`:22`)

**なぜ本番で壊れるか**: 最悪ケースは infra の state コミット防止が効かず、
`terraform.tfstate` (RDS 接続情報を含む) が git 履歴に入ること。履歴からの除去は force push を伴う
不可逆な後始末になる。加えて AC-5.2 (「ハーネスが TDD と lint 強制を**機械的に**担保」) が
成立しない — `plan.md:42` の「雛形済み」という評価が誤りになる。

**修正案**:

1. 3 ファイルに実行ビットを付けてコミットする (`git update-index --chmod=+x templates/*/scripts/hooks/pre-commit`)
2. `templates/README.md` の手順を `chmod +x scripts/hooks/pre-commit` を含む形にし、
   **導入検証ステップ**を書く (例: `git commit --allow-empty -m "hook check"` で
   `[pre-commit] OK` が出ることを確認する)
3. できれば symlink 方式をやめ、`git config core.hooksPath scripts/hooks` に変える
   (symlink の張り忘れ・相対パス誤りという事故面が消える)

---

### 重大 4. LLM 呼び出しレコードに cache トークンが無く、Managed Agent 経路のコストが構造的に誤る。明細は append-only なので後から補完できない

**該当**: `docs/design/observability.md:105` (`input_tokens` / `output_tokens` のみ)、`:109`
(`estimated_cost` / `price_table_version`)、`:112` (「明細は append-only テーブルに保存する」)、
`:114` (メトリクスの粒度)、§2 の O-H (`:49`)。

**一次ソース**: `claude_managed_agents/internal/stream/processor.go:65`-`:68` は
Managed Agent の `SpanModelRequestEnd` から
**`InputTokens` / `OutputTokens` / `CacheReadInputTokens` / `CacheCreationInputTokens` の 4 カウンタ**を
すでに受け取っている。設計はこのうち 2 つしか記録項目に入れていない。

**なぜ本番で問題になるか**: 会話型フローは毎ターン同じ system prompt + 会話履歴 + 台帳を送るため、
**入力トークンの大半がキャッシュ読取になる**。キャッシュ読取と通常入力は単価が大きく違い、
キャッシュ書込は割増になるため、2 カウンタからの推定コストは実額から系統的に外れる。
結果として:

- O-3 の「可視化」が意思決定に使えない数字になる (課金上限を設けない方針なので、
  **可視化の精度が唯一の防衛線**である)
- AL-4 (`observability.md:162`「前日比 200% 超」) が誤検知・検知漏れを起こす
- 明細テーブルは append-only (`:112`) なので、後でカラムを足しても**過去分は復元不可能** —
  「分析用の明細を持つ」という O-D の目的が最初の数か月分について失われる

**修正案**:

1. §4.2 の必須項目に **`cache_read_input_tokens` / `cache_creation_input_tokens`** を追加する
   (直接 API 経路でプロバイダが返さない場合は 0 ではなく NULL とし、区別できるようにする)
2. 単価テーブル (O-H) を **入力 / 出力 / キャッシュ読取 / キャッシュ書込の 4 レート**に拡張し、
   `estimated_cost` を 4 項の合計と定義する
3. **単価が未登録のモデルは `estimated_cost` を NULL + `price_missing` フラグで記録する**。
   PoC は未知モデルに既定単価を当てて黙って誤る実装
   (`claude_managed_agents/internal/agent/diverge/result_helpers.go:186`-`:188` の `default` 分岐) —
   これを踏襲しないことを明記する (D-B''③ の「未知モデルはエラーにする」と同じ思想)

---

### 重大 5. D-B'' の 3 点追加では O-2 / AC-2.1 を満たせない — v2 の LLM 抽象は usage を載せる場所と `ctx` が構造的に足りない

**該当**: `docs/design/architecture.md:26` (D-B''「v2 の `hassan-v2-backend/llm` の構造を**踏襲する**が、
次の 3 点を追加した上で採用する」)、`docs/design/observability.md:174` (O-2 の回答が D-B'' に依存)、
`:194` (引き渡し要件も 3 点のまま)。

**一次ソースで確認した抽象の形** (`hassan-v2-backend/llm/interface.go:8`-`:45`、
`hassan-v2-backend/llm/types.go`):

| メソッド | 戻り型 | usage を載せられるか |
|---|---|---|
| `GenerateTextContent` | `*GenerateTextContentResponse` (`types.go:109`) | **可** (`Usage` フィールドあり) |
| `GenerateTextContentStream` | `<-chan GenerateTextContentStreamChunk` (`types.go:97`) | **不可** (`Content` / `Error` のみ) |
| `WriteReport` | `(string, error)` (`interface.go:19`) | **不可** |
| `GenerateIdea` | `*GenerateIdeaResponse` (`types.go:131`) | **不可** |
| `EvaluateIdeas` | `*IdeaEvaluationResponse` (`types.go:165`) | **不可** |
| `GenerateDraft` / `GenerateResearchPlan` / `GenerateSearchQuery` / `ReviseContent` | `types.go:226` / `:240` / `:255` / `:273` | **いずれも不可** |

さらに **`ctx` を受けるのは 1 メソッドだけで、しかも任意**
(`types.go:80`-`:81`「`Ctx` は省略可」)。`GenerateIdeaRequest` (`types.go:122`) 以下のリクエスト型に
`ctx` フィールドは無く、`WriteReport` の引数にも無い。

**なぜ本番で問題になるか**:

- D-B'' を字義どおり (「①全プロバイダで usage を取得する」) 実装すると、**usage は取れるが載せる場所が
  無い経路が 10 個残る**。アイデア生成・評価・リサーチは主要機能そのものであり、
  AC-2.1 (「**すべての** LLM 呼び出し経路で…共通層で行うこと」) と O-2 が達成不可能になる。
  「1 経路だけの計測は計測なしと同じ」(`08-production-gates.md` O-2) の再来
- `ctx` が無い経路には**タイムアウトもキャンセルも効かない**。`observability.md:140` の
  「1 ターンの実行時間上限 5 分」と F-4 (`:125`「context キャンセル」) は、直接 API 経路について
  実装できない
- 後から抽象を直すと**全呼び出し箇所の修正**になる (D-B'' の却下案 (a) が挙げているのと同じコスト)

**修正案**: D-B'' に ④⑤ を追加し、`observability.md` §7 の引き渡し要件も揃える。

- ④ **全メソッドの戻り値を共通エンベロープに統一する**。例:
  `type Result[T any] struct { Data T; Meta CallMeta }` /
  `type CallMeta struct { Provider, Model string; InputTokens, OutputTokens, CacheReadTokens, CacheCreationTokens int; StopReason string; DurationMS int64 }`。
  計測は**エンベロープを返すデコレータ 1 枚**で行う (メソッドを増やしても計測を書き忘れられない構造 =
  D-D / O-C の「書かせない構造」を型で担保する)。ストリーミングは**終端チャンクで `Meta` を返す**契約を明記する
- ⑤ **全メソッドが `ctx context.Context` を第 1 引数で受ける** (リクエスト構造体の任意フィールドにしない)。
  これが安全弁 (§4.4) と F-4 の前提になる

---

## 中 (Should Fix)

### 中 1. `architecture.md` §5 の O-* 行が `observability.md` と矛盾し、しかも `observability.md` への参照が 1 つも無い

`grep observability docs/design/architecture.md` のヒットは
`v2-deploy-observability.md` (分析文書) の 3 件だけで、**設計文書 `docs/design/observability.md` への
リンクが 0 件**。その結果、状態表記が食い違ったまま並存している:

| ID | `architecture.md` §5 | `observability.md` §5 |
|---|---|---|
| O-4 | 部分 (要件を追加) | **回答** |
| O-5 | **未回答** | **回答** (§4.3 F-5 / §4.4) |
| O-6 | **未回答** | **回答** (§4.5) |
| O-7 | **未回答** (運用設計) | **回答** (§4.6 AL-1〜AL-6) |

`CLAUDE.md` のドキュメント規約は「1 トピック 1 ファイル・SSOT を明示。同じ事実を 2 箇所に書かない」。
現状は O-1〜O-7 の回答が 2 箇所にあり、**新しい方 (observability.md、実測日 2026-07-29) が
古い方から参照されていない**。`architecture.md` だけを読む実装者・計画者は O-5/O-6/O-7 を
未設計と誤認する。

**修正案**: §5 の O-1〜O-7 行を **`docs/design/observability.md` §5 への 1 行参照に置き換える**
(「O-* の SSOT は observability.md。本書は層配置のみを規定する」)。冒頭の「本書が回答する本番観点」
からも O-1/O-2/O-3 を外し、代わりに前提文書として `observability.md` を挙げる。

### 中 2. D-4 (マイグレーション) の依存先が誤っている — Q-2 は回答済みで、しかも無関係な論点

`architecture.md:196`「psqldef 推奨 (v2 準拠)… 適用を CI/デプロイに組み込むか、承認付き手動かを
**Q-2 と同時に確定**」。Q-2 は `aidlc-docs/inception/productionization/questions.md:46`
「リポジトリ構成」で、**すでに回答済み** (3 分割。`templates/README.md:4` が「Q-2=A の回答」と明記)。
`plan.md:33` も「Q-1/Q-2 待ち」と同じ誤りを持つ。
正しい依存は **Q-8 (環境戦略と DB 自動適用範囲 = AC-3.7)** と Q-1 (データモデル)。

さらに**雛形は既に psqldef で確定している**: `templates/backend-repo/CLAUDE.md.tmpl:15` (`make psqldef`)、
`:71`-`:78` (DB 変更フロー)、`templates/backend-repo/scripts/hooks/pre-commit:41`
(`db/schema.sql` / `db/queries/` を検出)。設計が「未回答」なのに雛形が確定している逆転状態。

**修正案**: D-4 の依存を Q-8 / Q-1 に直し、「**方式は psqldef で確定** (雛形もこの前提)、
未確定なのは**適用タイミングと自動適用の範囲**」と切り分けて書く。

### 中 3. D-A' の確定状況が同一文書内で 3 通りに読める

- `architecture.md:23` (D-A' 行)「…**要確定** — §8 の残課題」
- `:108`「### 層配置の判断基準 (**D-A' の確定**。AC-5.1)」
- `:221` (§8 残課題)「**Service 層の責務境界 (D-A')** — …切り分け基準を、代表ユースケースで
  具体化して確定する」← §3 で既に実施済みの内容

AC-5.1 の受入基準 (「責務境界と禁止依存が定義され、代表ユースケース 1 本で具体例が示されている」) は
§3 で満たされている。にもかかわらず 2 箇所が「未確定」と書いているため、実装者は
「この判断基準に従ってよいのか」を判断できない (DR-5 の構造的な変種)。

**修正案**: `:23` を「確定 (§3 の判断基準と配置例)」に更新し、`:221` は削除するか、
残る未確定点 (重大 1 で指摘したトランザクション機構) に具体化して残す。

### 中 4. 生成物差分チェックが `git diff --exit-code` のみで、**新規生成ファイルをすり抜ける**

`templates/backend-repo/.github/workflows/ci.yml:49`-`:64` と
`templates/frontend-repo/.github/workflows/ci.yml:41`-`:50` は
`make sqlc wire` / `make docs` / `npm run generate` の後に `git diff --exit-code` を実行する。
`git diff` は**追跡済みファイルの変更しか見ない**ため、新エンドポイント・新クエリ追加時に
生成物が**新規ファイル (untracked) として作られるケースでは差分 0 と判定されて緑になる**。

影響が大きいのは OpenAPI 定義と FE の生成型で、`templates/README.md:49`
(「**OpenAPI スキーマが backend → frontend の契約**」) という 3 分割構成の唯一の機械的な担保が
すり抜ける。FE は型が無いまま (または古い型で) マージされる。

**修正案**: `git status --porcelain --untracked-files=all` が空であることを検査する
(または `git add -A && git diff --cached --exit-code`) に変更。
併せて `ci.yml:51` のコメント「生成コマンドが未整備の間は**このステップを削除しておくこと**」は
D-2 のゲートを合法的に外す指示なので、「生成コマンドを整備するまでこの雛形をマージしない」に改める。

### 中 5. infra CI の `terraform plan` がパイプで終了コードを落としており、**plan 失敗でもジョブが緑になる**

`templates/infra-repo/.github/workflows/ci.yml:67`:

```
run: terraform -chdir=<envs/dev> plan -no-color -out=tfplan | tee plan.txt
```

GitHub Actions の既定シェルは `bash -e` (pipefail なし) なので、パイプラインの終了コードは
最後の `tee` の 0 になる。**plan がエラーで落ちてもステップは成功**し、続く
「destroy / replace の検出」(`:69`-`:75`) は不完全な `plan.txt` を grep し、
PR コメント (`:77`-`:88`) にエラー文が貼られるだけで**マージはブロックされない**。
「CI で plan まで行う」という D-3 / 絶対ルール 2 の担保が実質存在しない。

**修正案**: ステップに `shell: bash` + 先頭 `set -euo pipefail` を付ける。
または `terraform plan -out=tfplan -detailed-exitcode > plan.txt` を使い、
終了コード 1 = 失敗 (ジョブを落とす) / 2 = 差分あり (成功扱い) を明示的に分岐する。

### 中 6. infra pre-commit が `.tfvars` を無条件にブロックしており、自分のメッセージと `CLAUDE.md` の方針に矛盾する

`templates/infra-repo/scripts/hooks/pre-commit:15` の `bad` パターンに `\.tfvars$` が含まれ、
該当すると `exit 1` (`:21`)。ところが同じブロックの `:20` は
「`.tfvars` は環境固有値を含むため、**コミットするなら**秘密が入っていないことを確認してください」と
案内している — **コミットする道が無いのに「コミットするなら」と書いている**。
また `:12` は `tf_staged` に `.tfvars` を含めているが、`:15` で先に落ちるため到達しない (デッドコード)。

`templates/infra-repo/CLAUDE.md.tmpl:40`「環境間の差分は変数で表現する」を素直に実装すると
`envs/dev/terraform.tfvars` / `envs/prod/terraform.tfvars` をコミットする構成になり、
実装者は禁止されている `--no-verify` 以外の逃げ道が無い (= ハーネスが `--no-verify` の常用を教育してしまう)。

**修正案**: ブロック対象を `.tfstate` / `.tfstate.backup` / `.terraform/` に限定する。
`.tfvars` は「秘密を入れない」規約 + 値パターン検査 (gitleaks 等) で守り、
秘密を含むものは `*.secret.tfvars` として `.gitignore` に入れる、という形に分ける。

### 中 7. frontend pre-commit は「関連テストが 0 件」でコミットを止める

`templates/frontend-repo/scripts/hooks/pre-commit:34` `npx vitest related --run $ts_staged`。
vitest は対象テストが 0 件のとき既定で終了コード 1 を返す (`--passWithNoTests` が必要)。
設定ファイル・型定義・まだテストが無いコンポーネントを触るたびに commit が失敗するため、
これも `--no-verify` の常用圧力になる。
加えて `:20`-`:23` の `node_modules` 未インストール時 `exit 0` は**無言スキップ**で、
CI に到達するまで型エラーに気付けない (二層化の意図としては許容範囲だが、README に明記が必要)。

**修正案**: `--passWithNoTests` を付ける。TDD の担保は「テストが**存在すること**の検査」で別に行う (中 8)。

### 中 8. AC-5.2 の「TDD を機械的に担保」が雛形で未実装 — CI はテストが**通ること**しか強制していない

`aidlc-docs/inception/productionization/requirements.md` AC-5.2 は
「雛形が TDD と lint 強制を**機械的に**担保していること」を求め、`plan.md:42` は「雛形済み」と評価している。
しかし 3 リポの `ci.yml` にはカバレッジ下限も「新規の振る舞いに対応するテストの存在検査」も無い。
現状 TDD を支えているのは `templates/backend-repo/.claude/agents/go-developer.md:17`-`:24` と
`templates/shared/.claude/skills/test-driven-development/SKILL.md` の**文章だけ**で、
`feedback_review_patterns.md` が禁じる「実装時に気をつける」に等しい。

**修正案**: 次のいずれかを雛形に入れる。(a) `go test -coverprofile` + 全体カバレッジ下限、
(b) 差分カバレッジ (変更行のうちテストで実行された割合) の下限、
(c) 最低限「変更された非生成 `.go` / `.ts` に対応するテストファイルの有無」を PR コメントで可視化。
併せて `go-developer.md:24` の「テスト名に AC-ID を埋める」を機械照合する簡易チェックを
入れると、AC ↔ テストのトレーサビリティも CI で守れる。

### 中 9. backend CI は Postgres を起動して `DATABASE_URL` を渡すが、**スキーマを適用していない**

`templates/backend-repo/.github/workflows/ci.yml:17`-`:26` で `postgres:16` を立て、
`:44`-`:47` で `DATABASE_URL` を渡して `go test ./...` を実行する。しかし
`make psqldef` (スキーマ適用) に相当するステップが無いため、**DB を使う UT は空のデータベースに当たる**。
BE-5 (「本番ではインメモリ・フォールバックを持たない」) を守る設計なら、
テストは実 DB 前提になるので、この雛形はそのままでは動かない。

**修正案**: `go test` の前に schema 適用ステップを追加する (`make psqldef` またはスキーマ SQL の直接適用)。
アプリのマイグレーション方式が確定するまでは、ステップを置いて `<スキーマ適用コマンド>` プレースホルダにする。

### 中 10. `docs/design/infrastructure.md` は存在しないのに、infra 雛形 3 箇所が SSOT として参照している

`templates/infra-repo/CLAUDE.md.tmpl:3`、`templates/infra-repo/.github/workflows/ci.yml:5`、
`templates/infra-repo/.claude/agents/infra-engineer.md:19`。
AC-3.6 は `plan.md:35` で「未着手 (Q-7 待ち)」と正しく管理されているので**未作成であること自体は正当**だが、
雛形は「あるもの」として書いているため、切り出した実装リポでは最初から参照切れになる。
`infra-engineer.md:70` は「**設計書に無いリソースの追加**」を禁止しているので、
設計書が存在しない状態ではエージェントが何も追加できない (または禁止を無視する) 詰みになる。

**修正案**: 3 箇所に「**未作成** (Q-7 の回答後に作成。それまで infra リポは着手しない)」と明記する。
`templates/README.md` の立ち上げ順序 (`:41`-`:47`) にも「infra は AC-3.6 確定後」と条件を書く。

### 中 11. infra の `CLAUDE.md` が「autoMode で deny 設定済み」と書いているが、`settings.json` を同梱していない

`templates/infra-repo/CLAUDE.md.tmpl:24`「(autoMode で deny **設定済み**)」、`:70`
「`apply` / `destroy` / state 操作 / `.tfstate` の読み取りは autoMode で deny」。
しかし `templates/` 配下に `.claude/settings.json` は 1 つも無く、
`templates/README.md:33`-`:35` は「`.claude/settings.json` を**作る**」を手作業手順として置いている。
つまり立ち上げ直後は `terraform apply` / `destroy` / `.tfstate` 読み取りが**無防備**なのに、
エージェントは CLAUDE.md を読んで「設定済み」と理解する。
(散文の禁止規定は `CLAUDE.md.tmpl:23` と `infra-engineer.md:10` / `:68` に重複してあるため、
防御は完全に無いわけではない。よって重大ではなく中と判定した。)

**修正案**: 3 リポ分の `.claude/settings.json` を deny リスト込みで雛形に同梱する
(backend: `.env` 読取 / `DROP`・`TRUNCATE` / migration 削除 / force push、
infra: `terraform apply`・`destroy`・`state`・`import`・`.tfstate` 読取)。
同梱しない方針なら、CLAUDE.md の文言を「settings.json を作成して deny すること
(未作成の間は apply 禁止を人手で担保)」に変える。

### 中 12. 本番コンテナイメージの要件が設計に無く、v2 の開発用イメージを引き継ぐ余地が残っている

`architecture.md:195` (D-3) はイメージの**作り方**に触れていない。実測した v2 の実態は
`hassan-v2-backend/Dockerfile` = `golang:1.24.3-alpine` に `air` (ホットリロード) を入れ、
`COPY . .` でビルドコンテキストごとイメージへ入れ、`CMD ["air", "-c", ".air.toml"]` で
**prod でもホットリロード実行**している。D-5 で否定した「`.env` の焼き込み」はこの `COPY . .` の帰結であり、
**イメージ設計を書かないと D-5 の対策 (Secrets Manager 注入) だけでは `.env` の混入を防げない**
(`.dockerignore` が無ければイメージに残る)。雛形にも Dockerfile / `.dockerignore` が無い。

**修正案**: D-3 に「マルチステージビルド / 実行用は最小イメージ (distroless 等) / 非 root /
`.dockerignore` で `.env`・`.git`・テストを除外 / タグは immutable (コミット SHA)」を追加し、
`templates/backend-repo/` に `Dockerfile` と `.dockerignore` の雛形を置く。

### 中 13. A-6 の「該当なし」応答が観測項目になっていない — 実装バグと越境試行が両方とも静かに消える

`architecture.md:100`-`:103` は所有者スコープ不一致のツール引数を「該当なし」として LLM に返す
(存在を推測させない)。**方針としては正しい**が、`observability.md` §4.3 の失敗 5 分類に
「所有者不一致」が無いため、次の 2 つが無言で消える:

- **実装バグ**: UseCase がスコープを渡し忘れた / 誤ったスコープを渡した (機能が「該当なし」を返し続ける)
- **越境の試行**: 会話履歴やプロンプト経由で他テナントの ID が入り込んだケース

AC-1.3 は設計要件としては満たされているが、**運用でそれが守られていることを確認する手段が無い**。

**修正案**: §4.3 に **F-6「ツール引数の所有者不一致」** を追加し、warn ログ + メトリクスに出す
(ログには要求された ID を出さず、ツール名・件数・request_id に留める)。
§4.6 に「F-6 が定常的に発生したら通知」の AL を 1 行追加する。

### 中 14. LLM レコードの粒度が Agent 経路で曖昧 (1 model_request か 1 ターンか)

`observability.md:97`「**1 回の LLM 呼び出しごと**に記録する」に対し、`:108` の `tool_calls` は
「**そのターンでの**ツール呼び出し回数」。Managed Agent では usage は
`SpanModelRequestEnd` = **model_request 単位**で届く (`claude_managed_agents/internal/stream/processor.go:63`-`:68`)。
1 ターンは複数 model_request を含むため、粒度を決めないと
「レコードごとに同じ `tool_calls` を入れて二重計上する」「ターン集計にしてトークンを合算し、
モデル別の内訳を失う」のどちらかが実装依存で起きる。

**修正案**: 「**1 レコード = 1 model_request**。`turn_id` を持たせてターンで束ねる。
`tool_calls` はターン単位の値なのでレコードに持たせず、ターン集計 (または最終レコードのみ) に置く」
のように明記する。§4.4 の安全弁 (ツール呼び出し回数・累積出力トークン) も同じ `turn_id` 粒度で数える。

### 中 15. 安全弁の「打ち切り方」が未指定 — サーバ側で回るループを Go 側からどう止めるかが最大の実装リスク

`observability.md:136`-`:141` は上限値と「ループを打ち切り」だけを書いている。
Managed Agent のツールループは **Anthropic 側で進行する**ため、Go 側は
「次の `custom_tool_result` を返さない」「エラー結果を返す」「セッションに割り込む」のいずれかを選ぶ必要があり、
選択によってユーザー体験 (SSE の終わり方) と課金が変わる。
PoC には既に手段がある: `claude_managed_agents/internal/session/interrupt.go:18` の `SendInterrupt`
(`user.interrupt` を送って pending を解除)、`:41` の `bestEffortInterrupt` (退出時の best-effort)。

**修正案**: §4.4 に打ち切り手順を書く。例:「上限到達 → 以降の `custom_tool_use` には
打ち切り理由を載せた `custom_tool_result` を返す → `user.interrupt` を送る →
SSE に理由イベントを流す → `outcome=tool_limit` で記録」。出典として上記 PoC 実装を引く。
併せて `:145`「打ち切りはエラーではなく正常な終了」を、**HTTP は 200 のまま SSE の
エラーイベントで表現する** (`architecture.md:159`-`:161`) と整合させる。

### 中 16. PoC からの移植で構造的に潰すべき 2 パターン (BE-5 / BE-2) が引き渡し注記に無い

- **BE-5 (DB 未接続フォールバック)**: `architecture.md:215` は
  `claude_managed_agents/cmd/devui/conversation_tools.go` を「振る舞いの正」として引き渡すが、
  当該ファイルは**依存が nil のとき機能を落とさずエラー JSON を返す設計**
  (`:22`-`:23` のコメント「assetStore / exaClient が nil の場合、該当ツールはエラー JSON を返す
  (DB 未接続フォールバック / AC-N4)」、`:56`-`:72` に 3 つの fallback ハンドラ)。
  そのまま移植すると本番で「DB や外部検索が落ちていても会話は続き、生成物だけ保存されない」
  = 静かなデータ喪失を許す
- **BE-2 (hard cap の散在)**: §4.4 は安全弁を外部化したが、**LLM 呼び出しごとの `MaxTokens` と
  生成件数の既定/上限**の SSOT がどこにも無い。PoC は各ファイルの const に散在している
  (`claude_managed_agents/cmd/devui/plan_brushup.go:40`、
  `claude_managed_agents/cmd/devui/asset_merge.go:54`、
  `claude_managed_agents/cmd/devui/conversation_tools_matching.go:43`)

**修正案**: `architecture.md` §7 の引き渡し注記に
「**nil 依存フォールバックは移植しない。依存欠如は起動時に fail-fast**」を追加。
併せて「LLM 呼び出しパラメータ (model / max_tokens) と生成件数の既定・上限は 1 つの設定源に置き、
prompts と FE に複製しない」を D-B'' か `observability.md` §4.4 に明記する。

---

## 軽微 (Nice to Have)

1. **エージェント定義の description が古い**: `templates/backend-repo/.claude/agents/go-developer.md:3`
   と `templates/backend-repo/.claude/agents/code-reviewer.md:3` が「**3 層**」と書いている
   (本文の表は正しく 4 層)。`code-reviewer.md:3` は backend リポなのに「Next.js」を含み、
   D-I (3 分割) と不整合。description は呼び出し側が読む部分なので直す価値がある
2. **`golangci-lint-action` のバージョン非固定**: `templates/backend-repo/.github/workflows/ci.yml:41`-`:42`
   に `version:` 指定が無く、lint 本体が上がった日に無関係な PR が赤くなる。`concurrency` group も無く、
   `push` と `pull_request` の両方に反応するため同一コミットで 2 重実行される (3 リポ共通)
3. **`permissions` の粒度**: `templates/infra-repo/.github/workflows/ci.yml:13`-`:16` の
   `id-token: write` / `pull-requests: write` がワークフロー全体に付いており、`validate` ジョブにも及ぶ。
   ジョブ単位に下げる
4. **先送り先の文書名が無い箇所**: `architecture.md:189` (O-4)「具体の項目は**実装設計**で確定」の
   「実装設計」がどの成果物か不明。`:195` (D-3)「ロールバックは新規設計が必要」も、
   本文には先送り先が無い (`plan.md:32` の `docs/design/operations.md` を明記すべき)。
   全面切替 (D-J) を採る以上、切り戻し手段の所在は本文から辿れるようにしたい
5. **出典が無い数値**: `architecture.md:94`「(9 tools)」。実測では 9 件で**正しい**
   (`claude_managed_agents/cmd/devui/conversation.go:774`-`:790`) が、出典を付ければ DR-1 の指摘余地が消える
6. **`templates/README.md` のコピー手順に `.claude/settings.json` が含まれない** (`:22`-`:30`)。
   手順 2 を飛ばすとガード無しで動き出す (中 11 と同根)。手順 2 を「必須」と強調するか、
   雛形を同梱してコピー対象にする
7. **シェルの引用**: `templates/infra-repo/scripts/hooks/pre-commit:42` の `for d in $(...)` と
   `templates/backend-repo/scripts/hooks/pre-commit:28` の `xargs -n1 dirname` は、
   空白を含むパスで壊れる。`while IFS= read -r` + `-0` 系に寄せると安全
8. **`tflint` の初期化**: `templates/infra-repo/.github/workflows/ci.yml:42`-`:44` は
   `tflint --recursive` を直接実行しており、プラグイン利用時は `tflint --init` が必要
9. **図と本文の距離**: `architecture.md:44`-`:75` の図で Repository が Service からの矢印を受けているが、
   その根拠 (補助原則 `:125`-`:126`) は 50 行離れている。図の直下に 1 行注記があると読み違いが減る

---

## 本番観点カバレッジ

`08-production-gates.md` の全 22 ID。「回答」= 実装可能な粒度で書かれている、
「部分」= 方針のみ / 前提が未確定、「未回答」= 先送り先はあるが中身が無い。
**無言の省略 (DR-2) は 0 件**。

| ID | 状態 | 箇所 / 備考 |
|---|---|---|
| A-1 認証方式 | 回答 | `docs/design/architecture.md:179` → `docs/design/auth.md` §6.1 (別レビュー範囲)。`:135` で Controller 層に配置 |
| A-2 ロールと適用範囲 | 回答 | `docs/design/architecture.md:180` → `docs/design/auth.md` §6.2。本増分は一般ユーザーのみ (先送り先明記) |
| A-3 テナント境界 | 回答 (テーブルは Q-1 待ち) | `docs/design/architecture.md:181` / `:170` → `docs/design/auth.md` §6.3 |
| A-4 絞り込みの層 | **部分** | `docs/design/architecture.md:182` / `:138`。層の配置は明確だが「CI で禁止」の機構が雛形に無い → **重大 2** |
| A-5 ステータスコード | 回答 | `docs/design/architecture.md:183` → `docs/design/API/README.md` §2.5 / `docs/design/auth.md` §6.6 |
| A-6 LLM への越境 | 回答 (観測が不足) | `docs/design/architecture.md:100`-`:103` / `:142`。所有者不一致の観測項目が無い → **中 13** |
| A-7 共有・公開 | 対象外 (理由あり) | `docs/design/architecture.md:185`「初期増分では共有機能を持たない」 |
| O-1 構造化ログ | 回答 | `docs/design/observability.md` §4.1 / O-A / O-B。`architecture.md:186` も一致 |
| O-2 LLM 呼び出しの記録 | **部分** | `docs/design/observability.md` §4.2。計測点の集約は妥当だが、抽象に載せる場所が足りず全経路化が不可 → **重大 5**、cache トークン欠落 → **重大 4**、粒度未定 → **中 14** |
| O-3 コスト集計と上限 | 回答 (打ち切り手段が未指定) | `docs/design/observability.md` §4.4 / O-E。上限を設けない判断と安全弁の分離は明確。打ち切り方 → **中 15** |
| O-4 失敗の可観測性 | 回答 (`architecture.md` は「部分」と表記) | `docs/design/observability.md` §4.3 の F-1〜F-5。表記の食い違い → **中 1**。F-6 の追加を推奨 → **中 13** |
| O-5 SSE / 長時間処理 | 回答 (`architecture.md` は「未回答」と表記) | `docs/design/observability.md:126` (F-5) / `:141` (keep-alive 15 秒)。再接続の仕様は未記載 → **中 1** で併せて整理 |
| O-6 監査ログ | 回答 (`architecture.md` は「未回答」と表記) | `docs/design/observability.md` §4.5 |
| O-7 アラート | 回答 (`architecture.md` は「未回答」と表記) | `docs/design/observability.md` §4.6 AL-1〜AL-6。通知先の実体は運用設計 (先送り先明記) |
| D-1 環境 | **部分** | `docs/design/architecture.md:193`。3 環境は確定、切り分けは Q-8 待ち (正当な依存) |
| D-2 CI ゲート | **部分** | `docs/design/architecture.md:194` + `templates/*/.github/workflows/ci.yml`。UT/lint/生成物は実装済みだが、A-1/A-4/D-6 の検査が無く (→ **重大 2**)、差分検知にすり抜けがある (→ **中 4**) |
| D-3 デプロイ手順 | **部分** | `docs/design/architecture.md:195`。ロールバックは「新規設計が必要」までで本文に先送り先が無い (→ **軽微 4**)。イメージ設計が欠落 (→ **中 12**)。deploy ワークフロー雛形が無い (→ **重大 2**) |
| D-4 DB マイグレーション | **未回答** | `docs/design/architecture.md:196`。方式は psqldef 推奨で雛形も確定済みだが、適用タイミング・自動/手動の区別が未確定。**依存先の記述が誤り** → **中 2**。先送り先: `plan.md:33` (Task-3a) |
| D-5 シークレット管理 | 回答 | `docs/design/architecture.md:197`。Secrets Manager / SSM から task 定義の `secrets` で注入。`.dockerignore` の明記が要る → **中 12** |
| D-6 Agent ライフサイクル | **「回答」と書かれているが機構が無い** | `docs/design/architecture.md:198`。CI 検査・デプロイ手順・雛形のいずれも未実装 (AC-3.3 は設計成果物から未参照) → **重大 2** |
| D-7 段階リリース | **部分** | `docs/design/architecture.md:199`。全面切替は確定、フラグ方式は Q-8 待ち (正当な依存)。FE 側の扱いは `templates/frontend-repo/CLAUDE.md.tmpl:46` に「判定の正は backend」と先行記述あり |
| D-8 IaC の管理範囲 | **未回答** | `docs/design/architecture.md:200`。Q-7 とインフラ構成要素の確認待ち (正当な依存)。先送り先: `plan.md:35` (Task-3e)。雛形が未作成文書を参照 → **中 10** |

**本番観点で未回答のまま残る ID**: **D-4 / D-8** (どちらも先送り先は `plan.md` にあり、
D-8 は Q-7 依存で正当。D-4 は依存先の記述が誤っているため実質的に宙吊り)。
**部分回答**: A-4 / O-2 / D-1 / D-2 / D-3 / D-7。
**`architecture.md` の表記が古い**: O-4 / O-5 / O-6 / O-7 (実体は `observability.md` で回答済み)。

---

## 良かった点

- **事実の出典密度が高い**。17 件の抜き取り照合で**誤りが 0 件**。特に
  `hassan-v2-backend/router/router.go:50`-`:51` や `hassan-v2-backend/logger/logger.go:10` のような
  行番号指定が実際に一致しており、`docs/analysis/` の実測が設計に正確に転記されている。
  「`stop_reason` が**公開型に**無い」のように、プロバイダ内部型には存在するという微妙な区別まで
  正確に書けている (`hassan-v2-backend/llm/claude/types.go:23` は `StopReason` を持つ)
- **「v2 だからそうする」を明示的に切っている**。`observability.md` §1 の継承可否テーブルは
  「継承できるのは zap JSON / CloudWatch 集約 / 監査ログ方式の 3 つだけ」と結論まで書いており、
  `08-production-gates.md` の警告 (D-1/D-3/D-5/D-8/O-1 は v3 で新規設計) を正面から満たしている
- **計測を「書かせない構造」に落とす方針** (D-D / O-C / `observability.md:74`-`:75`) は、
  PoC で発散経路だけが計測された原因を構造的に潰す正しいアプローチ。
  `claude_managed_agents/internal/session/run.go` の `ToolDispatchFunc` の設計コメントも
  同じラップ方針を支持しており、移植可能性がある
- **課金上限 (拒否) と暴走の安全弁を明確に分離**している (`observability.md` O-E / §4.4)。
  「上限は設けない」というユーザー決定を守りながら無限ループ対策を機能要件として立てる整理は、
  O-3 の意図を正しく解釈している。初期値を「暫定・外部化・運用開始 1〜2 週で見直し」と
  条件付きで出しているのも誠実 (曖昧語の丸投げになっていない)
- **層配置の 15 ステップ表**は、実装者が最初に迷う箇所を具体的に潰そうとしており方向性が正しい。
  「迷いやすい 3 点」を自ら列挙している姿勢も良い (重大 1 はその 3 点を**もう一段具体化する**だけで解ける)
- **雛形の失敗パターン対応が具体的**。`templates/infra-repo/.claude/agents/infra-engineer.md:32`-`:45` の
  「危険な差分」表 (RDS replace = データ消失) と、`templates/infra-repo/.github/workflows/ci.yml:90`-`:91` の
  「apply は意図的に定義していない」というコメントは、意図が後任に伝わる書き方になっている
- **`templates/README.md:56`-`:61`** が「この雛形は初期値であって SSOT ではない」と明記しており、
  切り出し後のドリフトを認識した上で還流ルールを定めている
