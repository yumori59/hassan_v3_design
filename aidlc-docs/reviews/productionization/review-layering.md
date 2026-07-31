# 設計レビュー: 増分 layering (層構成の再定義と層間規約)

> レビュー日: 2026-07-30 / レビュアー: `design-reviewer` (別セッション。起草者ではない)
> 判定基準: 本番基準 ([../../../.claude/rules/08-production-gates.md](../../../.claude/rules/08-production-gates.md) /
> [../../../.claude/rules/feedback_review_patterns.md](../../../.claude/rules/feedback_review_patterns.md) / rule 04 の 7 観点)。
> 「PoC では対象外だった」は省略理由として認めない。

## レビュー結果サマリ

- **判定: Design Freeze 不可** (重大 4 件)。重大を修正のうえ再レビューが必要 (rule 04)。
- 重大 **4 件** / 中 **9 件** / 軽微 **4 件**
- 実行した検証: `make check` (doc-lint エラー 0 / 警告 20、traceability 44/44 + 24/24) /
  参照リポジトリへの抜き取り照合 **22 件** (うち結論を左右するもの 6 件) / grep による層名残存確認 / pgx v5 の実型確認

### レビュー対象 (リポジトリ相対パス)

設計成果物:

- `docs/design/architecture.md`
- `docs/design/observability.md`
- `docs/design/auth.md`
- `docs/design/API/README.md`
- `docs/design/API/assets.md`
- `docs/design/API/knowledge.md`
- `docs/analysis/gap-analysis.md`

Inception 産物:

- `aidlc-docs/inception/productionization/questions-layering.md`
- `aidlc-docs/inception/productionization/requirements-layering.md`
- `aidlc-docs/inception/productionization/plan-layering.md`
- `aidlc-docs/inception/productionization/requirements.md`

ハーネス雛形:

- `templates/backend-repo/CLAUDE.md.tmpl`
- `templates/backend-repo/.golangci.yml`
- `templates/backend-repo/.github/workflows/ci.yml`
- `templates/backend-repo/.github/ISSUE_TEMPLATE/task.yml`
- `templates/backend-repo/.claude/agents/go-developer.md`
- `templates/backend-repo/.claude/agents/code-reviewer.md`
- `templates/README.md`
- `templates/shared/.claude/rules/02-issue-granularity.md`
- `templates/shared/.claude/rules/03-model-escalation.md`
- `templates/infra-repo/.github/ISSUE_TEMPLATE/task.yml`

その他:

- `CLAUDE.md` (`:15` のアプリ構造行)

対象外 (別セッション作業中のためレビューしていない): `docs/design/infrastructure.md` / `docs/design/operations.md` /
`aidlc-docs/inception/construction-workflow/` / `docs/design/design_memo.md`。

---

## 検証コマンドと出力

### `make check`

```
[WARN ] ./.claude/rules/05-harness.md:23 未確定マーカー: ...
[WARN ] ./aidlc-docs/inception/productionization/plan.md:120 未確定マーカー: ...
[WARN ] ./docs/design/design_memo.md:13 未確定マーカー: TODO: その他インフラ何が必要か ...
[WARN ] ./docs/design/infrastructure.md:506 未回答の [Answer]:
[WARN ] ./docs/design/infrastructure.md:514 未回答の [Answer]:
[WARN ] ./docs/design/infrastructure.md:521 未回答の [Answer]:
[WARN ] ./docs/design/infrastructure.md:527 未回答の [Answer]:
[WARN ] ./docs/design/operations.md:503 未回答の [Answer]:
[WARN ] ./docs/design/operations.md:514 未回答の [Answer]:
[doc-lint] 対象 75 ファイル / エラー 0 件 / 警告 20 件
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 44/44 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
```

- **エラー 0 / 未カバー AC 0**。警告 20 件はすべて対象外ファイル (`infrastructure.md` / `operations.md` の
  `[Answer]` 未回答) と `design_memo.md` / ルール文書の「TODO」語そのものへの反応で、**本増分の成果物には無い**
- **未カバー AC (DR-6) はゼロ**。ただし後述の中 5 のとおり、**AC が振られていない決定 (Q-L11) が 1 件ある** —
  この形の漏れは `check-traceability` では検出できない

### 事実の抜き取り照合 (DR-1)

| # | 設計の記述 | 照合コマンド / 結果 | 判定 |
|---|---|---|---|
| 1 | F1 層違反ゼロ (`hassan-v2-backend/docs/refactoring-plan.md:546`) | `sed -n '544,548p'` → `:546` に「`usecase/` 配下に `gin.Context` 依存: 0件 / `controller/` 配下に repository 直接参照: 0件（層違反なし）」 | **一致** |
| 2 | F4 `fmt.Errorf` 113 件 / `errors.New` 7 件 (`:62` / `:544`) | `:544` に「約113件。`errors.New`: 7件」、`:62` に内訳 (prompt 49 / dify 29 / azuredi 12 / aws 6 / hassanresend 4 / auth 3) | **一致** |
| 3 | F5 8 ファイル 61 箇所 + 直接アサーションの取りこぼし (`:545` / `:384`) | `:545` / `:384` に該当記述 (`errors.As` は `controller/idea_board.go:556`、直接アサーションは 2 ファイル) | **一致** |
| 4 | **F8 `service/` 追加レイヤー禁止 (`hassan-v2-backend/CLAUDE.md:39`)** | `sed -n '26,47p' CLAUDE.md` → `:39`「**禁止**: `helper/` フォルダ、`utils.go`、過度な抽象化（`internal/`/`service/` 追加レイヤー）」 | **一致 (結論を左右)** |
| 5 | **F7 Repository IF は UseCase 層で定義 (`:33`)** / **F6 外部サービスは外部側で IF 定義 + 型エイリアス (`:34`)** | 同上。`:33`「**Repository IF**: UseCase 層で定義」、`:34`「**外部パッケージ側で IF 定義**、UseCase は型エイリアスで直接使用（例: `type LLMService = llm.Service`）。アダプター層は作らない」 | **一致 (結論を左右)** |
| 6 | `fmt.Errorf` 全面禁止は規約 (`:43`) | `:43`「`constants.NewCodedError(...)` の使用は必須。`fmt.Errorf` 禁止。」 | **一致** |
| 7 | F6 型エイリアス 20 箇所 | `grep -rnE "^type [A-Za-z]+ = (llm|dify|prompt|ogp|microcms)\." usecase/ --include='*.go' \| wc -l` → **20** | **一致 (再現)** |
| 8 | `hassan-v2-backend/usecase/business_plan/interfaces.go:27` = `type LLMService = llm.Service` | `sed -n '20,30p'` → `:27` に該当 | **一致** |
| 9 | F2 usecase 相互 import 0 件 | `grep -rho "hassan-v2-backend/usecase/" usecase/ --include='*.go' \| wc -l` → **0** | **一致 (再現)** |
| 10 | **F15 関数長分布 (573 / 80+:40 / 100+:28 / 150+:21 / 200+:14 / 300+:3)** | `find usecase -name '*.go' ! -name '*_test.go' \| xargs awk '/^func /{start=NR} /^}$/{...}'` → **573 / 40 / 28 / 21 / 14 / 3** | **完全一致 (再現。funlen 150 の根拠が成立)** |
| 11 | F3 1381 行 / 919 行 | `wc -l` → `usecase/idea/web_search.go` **1381** / `brush_up_business_plan_detailed.go` **919** | **一致** |
| 12 | `handle_create_sheet.go:57` の `Execute` (385 行・ファイル 676 行) / `web_research.go:55` の `Execute` (356 行・ファイル 427 行) | `grep -n "^func"` で `:57` / `:55` に `Execute`、`wc -l` で 676 / 427 | **一致** |
| 13 | F10 LLM 抽象 11 メソッド・全て `ctx` なし・usage を載せられる戻り型は 1 つ | `cat llm/interface.go` (45 行) → `Service` 5 + `IdeaService` +2 + `ResearchService` +4 = **11**、全メソッドに `ctx` 引数なし | **一致 (結論を左右)** |
| 14 | F11 監査ログの `_ =` 無言破棄 6 ファイル 17 箇所 (`:123`〜`:129`) | 列挙を計数 → usecase 4 ファイル 14 + controller 2 ファイル 3 = **17** (件数は一致) | **件数は一致 / 性格付けが誤り → 中 2** |
| 15 | `usecase/idea_board/activity_log.go:25` の `_ = alr.CreateIdeaBoardActionSuccessLog` | `sed -n '20,35p'` → `:25` に該当 | **一致** |
| 16 | F9 golangci-lint 設定が無い / CI は `go test` のみ (`:57`〜`:58`) | `ls -a \| grep golangci` → **0 件**。`:57`〜`:58` に pre-commit の `go build`/`go vet`、CI の `go test -v -race` | **一致 (再現)** |
| 17 | F13 `entity/` はテストを持つ既存パッケージ (`:55`) | `:55` のテストありパッケージ 16 に `entity` が含まれる | **一致** |
| 18 | F14 LLM 4 プロバイダの HTTP/JSON 重複 (`:68`) | `:68` に「`llm/{openai,gemini,claude,perplexity}/service.go` … 4プロバイダで重複」 | **一致** |
| 19 | v2 `repository/` は 31 ファイル単一パッケージ | `ls repository/*.go \| wc -l` → **31** | **一致** |
| 20 | `usecase/repository_interfaces.go:21` が `tx pgx.Tx` を引数で受ける | `sed -n '15,25p'` → `:21` に `CreateAccountWithTx(ctx, tx pgx.Tx, ...)` | **一致** |
| 21 | PoC の tool 名 9 件 (`claude_managed_agents/cmd/devui/conversation.go:774`〜`:790`) | `sed -n '770,795p'` → `list_assets` / `load_asset` / `research_market` / `deep_dive` / `generate_ideas` / `generate_plan` / `record_rejection` / `set_theme_name` / `match_functions` = **9** | **一致** (ただし当該箇所は `toolLabel` = 表示ラベル関数。ディスパッチャではない) |
| 22 | usage 4 カウンタの受け取り (`claude_managed_agents/internal/stream/processor.go:65`〜`:68`) | `sed -n '60,72p'` → `u := v.ModelUsage` と `InputTokens` / `OutputTokens` / `CacheReadInputTokens` / `CacheCreationInputTokens` | **一致** |

**結論**: 出典なしの断定 (DR-1) は無く、**照合した 22 件のうち 21 件が完全一致**。
残り 1 件 (F11) は件数は正しいが**性格付けが実態より広い** (中 2)。実測系 (F15 / F2 / F6 / F9) は
コマンドごと再現でき、**funlen 150 / dupl 150 の根拠は成立している**。この水準は本リポジトリの過去レビューより高い。

### 旧層名の残存確認

```
$ grep -rn "AgentRunner\|ToolDispatcher\|再利用される処理\|再利用されているか" docs/ templates/ aidlc-docs/
docs/design/design_memo.md:168                                   … ユーザーの生メモ (対象外)
aidlc-docs/inception/productionization/plan.md:23                … ★現行の検証手段として残存 (中 7)
aidlc-docs/inception/productionization/plan-layering.md (複数)   … 追随対象の記述 (履歴として可)
aidlc-docs/inception/productionization/requirements-layering.md  … 却下案・旧定義の記録 (可)
aidlc-docs/reviews/productionization/review-*.md                 … 過去レビュー (可)
```

`docs/design/` 配下 (`auth.md` / `API/README.md` / `API/assets.md` / `API/knowledge.md` / `observability.md`) の
**現行指示としての旧層名はゼロ**。追随は完了している。例外は `aidlc-docs/inception/productionization/plan.md:23` (中 7)。

### pgx v5 の実型確認 (重大 2 の根拠)

```
$ awk '/^type Tx interface/,/^}/' /Users/yuyamorishita/go/pkg/mod/github.com/jackc/pgx/v5@v5.7.4/tx.go
type Tx interface {
	Begin(ctx context.Context) (Tx, error)      // pseudo nested transaction
	Commit(ctx context.Context) error
	Rollback(ctx context.Context) error
	CopyFrom(...) / SendBatch(...) / LargeObjects() / Prepare(...) / Exec(...) / Query(...) / QueryRow(...)
	Conn() *Conn                                 // 生コネクションへ到達できる
}
```

---

## 重大 (Must Fix — これがある限り Design Freeze 不可)

### 重大 1. `service/**` → `usecase` / `controller` の deny が depguard に無い — L-1 の逆流禁止と L-2 の抜け道が機械強制されていない

**① 事実**

- `docs/design/architecture.md:193` (L-1) は CI 強制の形を「各層パッケージの deny list」と書き、
  `:200`「**違反した PR はマージできない**」、`:583` (§5 の D-2 ①) は「**depguard による L-1〜L-6**」と書く
- `docs/design/architecture.md:177`「**`service` → `usecase` は禁止**」、同 `:139` の責務表も Service の禁止事項に
  「UseCase への依存」を挙げる
- `templates/backend-repo/.golangci.yml` の depguard 規則は 14 本 (`:59`, `:76`, `:85`, `:98`, `:111`, `:125`,
  `:138`, `:151`, `:164`, `:177`, `:193`, `:207`, `:226`, `:242`)。このうち **`files: ["**/service/**"]` を対象に
  `<module-path>/usecase` または `<module-path>/controller` を deny する規則は 1 本も無い**
  (`L2-L3-service-*` は `service` と `repository` のみ deny、`L6-service-no-connection-pool` は `pgxpool` のみ)
- `list-mode: lax` は「deny に無ければ許可」なので、`service/theme` → `usecase/asset` は**警告なく通る**

**② 何が問題か**

`service/A` → `usecase/B` は L-2 (`service/A` → `service/B` 禁止) の**完全な迂回路**である。
`usecase/B` は B ドメインの Service と Repository を自由に呼べるので、Service が他ドメインのロジックへ
到達する経路が残る。しかも UseCase はトランザクションを張り所有者スコープを確定する層なので、
Service から UseCase を呼ばれると **`tx` の二重開始 (L-6 違反) と所有者スコープの再確定**が起き、
本設計が A-6 / BE-10 / BE-11 の防御として立てた「境界は 1 箇所」という前提が崩れる。
同一ドメイン内の循環 (`service/A` → `usecase/A`) は Go のコンパイラが弾くが、**異ドメインは弾かない** —
つまり「コンパイルエラーになるから大丈夫」も成立しない。
`templates/backend-repo/.claude/agents/code-reviewer.md:28` は人手のレビュー項目として挙げているが、
同 `:24`〜`:25` が「**depguard が L-1〜L-6 を機械強制する。lint が通ったことを前提に**、機械では見られない
責務の中身をレビューする」と明示しているため、**レビュアー側は機械で見られている前提で読む**。
F9 (v2 は lint 無しで 113 件の規約違反が溜まった) を根拠に機械強制を選んだ設計として、この穴は致命的である。

**③ 修正案**

`.golangci.yml` に 1 規則を追加し、`architecture.md:193` の L-1 行の「CI 強制の形」を具体化する:

```yaml
L1-service-no-upper-layers:
  list-mode: lax
  files: ["**/service/**"]
  deny:
    - pkg: "<module-path>/usecase"
      desc: "L-1 / L-2 (§3.5.1): service → usecase は禁止。跨ぐ協調は UseCase が両方を呼ぶ。tx は引数で受け取る (L-6)"
    - pkg: "<module-path>/controller"
      desc: "L-1 (§3.5.1): service は HTTP 層に依存しない"
```

併せて `architecture.md` §3.5.1 の L-1 行に「`service/*` から `usecase/*` / `controller/*` を deny」を明記し、
`code-reviewer.md:24`〜`:25` の「lint が通ったことを前提に」を、**機械で見る規則と人手で見る規則の対応表**に
置き換える (どの L-x が機械強制で、どれがレビュー対象かを明示する)。

### 重大 2. L-6 の「型で担保」が `pgx.Tx` の実型と矛盾する — Service / ツールハンドラは Commit / Rollback を呼べる

**① 事実**

- `docs/design/architecture.md:198` (L-6) 「**型で担保** (Service は `tx` (`pgx.Tx` 相当) のみ受け取る)」
- 同 `:261`「Service は `Begin` / `Commit` / `Rollback` を**呼ばない** (**呼べる型を受け取らない**)」
- 同 `:300` / `templates/backend-repo/CLAUDE.md.tmpl` の Agent 節:
  `type ToolHandler = func(ctx context.Context, tx pgx.Tx, args json.RawMessage) (any, error)`
- `aidlc-docs/inception/productionization/requirements-layering.md:94` (L-6) 「型で担保 (Service は `tx`
  インターフェースのみ受け取る)」/ 同 `:194` (AC-6.7) 「`*sql.Tx` はドメイン型ではない」
- 実型 (pgx v5.7.4 `tx.go`): `pgx.Tx` は **`Begin` / `Commit` / `Rollback` / `Conn() *Conn` を公開する
  11 メソッドのインターフェース**である (上記「pgx v5 の実型確認」参照)。`database/sql` の `*sql.Tx` も
  `Commit` / `Rollback` を持つ

**② 何が問題か**

「型で担保」という**唯一の強制手段**が成立していない。`pgx.Tx` を受け取った Service / ツールハンドラは
`tx.Commit(ctx)` を呼べ、さらに `tx.Conn()` から生コネクションを得て新しいトランザクションも開始できる。
depguard 側の担保 (`L6-service-no-connection-pool`) は `pgxpool` の import しか塞がないため、
`pgx.Tx` 経由の到達は検出されない (そして `service/conversation` は `ToolHandler` の型定義のために
`github.com/jackc/pgx/v5` を必ず import する)。
本設計は「ツールループの途中でコミットされること」を **BE-10 (台帳 write-through の欠落) /
BE-11 (採番のサイレント失敗) の再発形**として明示的に排除しており (`architecture.md:48` の D-A'' 却下案 b、
`:541` の「ターン全体で 1 トランザクション」)、その排除が実装者の善意に戻る。
これは本設計自身が繰り返し否定している「規約として書いたが機構が無い」状態である。

**③ 修正案**

**利用側が narrow な IF を定義する** (C-L6「IF は小さく (1〜3 メソッド)、利用側が定義」と完全に整合する):

```go
// service/conversation/runner.go — 利用側が必要な分だけ定義する
type Tx interface {
    Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
    Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
    QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}
type ToolHandler = func(ctx context.Context, tx Tx, args json.RawMessage) (any, error)
```

`pgx.Tx` はこの IF を暗黙に満たすので UseCase 側の受け渡しは変わらず、**Commit / Rollback / Conn が
型として見えなくなる**。あわせて:

- `architecture.md:198` / `:261` / `requirements-layering.md:94` の「`pgx.Tx` 相当」を
  「**利用側パッケージが定義する 3 メソッドの `Tx` IF**」に改める (`pgx.Tx` をそのまま渡さない旨を明記)
- 実際に repository のメソッドが `pgx.Tx` を要求する場合の受け渡し (Repository IF 側も narrow な `Tx` を
  取る形にする) を §3.7 に 1 行で書く
- depguard で `service/**` からの `github.com/jackc/pgx/v5` 直接 import を残す必要があるかを再検討する
  (narrow IF を `entity/` か専用パッケージに置けば service は pgx を import しなくて済む)

### 重大 3. 新ドメイン追加時に検査が静かに外れる — §3.5.2 が前提にする「対象パス表と depguard の一致検査」が雛形に存在しない

**① 事実**

- `docs/design/architecture.md:219`「depguard 設定の対象パス集合と本表を **CI で突き合わせ、不一致で落とす**
  (§5 の D-2)」。同 `:218`「追記漏れは『新規ドメインが除外側に落ちて無検査になる』形の事故になる」
- `docs/design/architecture.md:583` (§5 の D-2) は本増分で追加する検査を **①〜⑧** 列挙し、
  「**検査スクリプト本体は実装リポで実装する** (雛形は**未実装なら落ちるステップ**を配置)」と書く
- 実物 `templates/backend-repo/.github/workflows/ci.yml` は **105 行**で、ステップは
  build / vet / golangci-lint / test / sqlc・wire 差分 / OpenAPI 差分 / **A-1 検査** / **A-4 検査** /
  **D-6 検査** のみ。**②層境界 `CodedError` 検査・③型エイリアス検出・④`errors.As` 以外の型アサーション禁止・
  ⑥`os.Getenv` 禁止・⑦対象パス表の一致検査・⑧`_ =` 破棄検出・`math/rand` 禁止検査の 7 つはステップ自体が無い**
  (A-1 / A-4 / D-6 は「未実装なら `exit 1`」の placeholder があるのに、この 7 つには placeholder すら無い)
- `templates/backend-repo/.golangci.yml` の未登録ドメイン番犬 (`L2-L3-service-unregistered-domain`, `:193`) は
  **`**/service/**` だけ**を見る。`L5-no-external-sdk` (`:226`) の対象は
  `usecase/{theme,asset,conversation,idea,plan}/**` の **5 ドメイン列挙**、
  `exclusions.rules[].path-except` (`:255`) も同じ 5 ドメインの正規表現列挙

**② 何が問題か**

`usecase/knowledge/` や `repository/knowledge/` のような **v3 新規ドメインを 6 つ目として追加したとき、
L-5 (外部 SDK 直接 import 禁止) と `dupl` / `cyclop` / `funlen` の対象から自動的に外れ、CI は緑のまま通る**。
これは設計が `:218` で自ら「事故」と名指した形そのもので、緩和策として書かれた⑦の一致検査が
**存在しない (スクリプト名も決まっていない)**。`service/` だけは番犬があるが、
`usecase/` と `repository/` には無い。
§8 の残課題どおり移植ドメインは今後表へ追記され続けるため、**この穴は必ず踏まれる**。
さらに ci.yml のコメントは「雛形の時点で TODO を残し、未実装なら CI が落ちるようにしてある —
『設計には書いたが機構が無い』状態を防ぐため」と書いており、**成果物内で主張と実物が食い違っている**。

**③ 修正案**

1. `ci.yml` に②③④⑥⑦⑧ + `math/rand` 検査の**落ちる placeholder ステップ**を追加する
   (A-1 / A-4 / D-6 と同じ形。`scripts/check-layer-error-contract.sh` /
   `scripts/check-lint-scope.sh` 等、スクリプト名を設計側で確定する)
2. ⑦ (対象パス一致検査) は最小実装を雛形に置ける — `architecture.md` §3.5.2 の表と
   `.golangci.yml` の `files:` / `path-except` から抽出したドメイン集合を比較する 20 行程度の
   シェル/Go スクリプトで足りる。**設計書側にこの検査の入力 (表の機械可読性: 表形式・パスの書式) を規定する**
3. `.golangci.yml` に `usecase/` と `repository/` の未登録ドメイン番犬を追加する
   (`files: ["**/usecase/**", "!**/usecase/{5 ドメイン}/**", "!**/usecase/{移植ドメイン}/**"]` の形)。
   移植ドメインの列挙が必要になるため、**§8 の「移植ドメインの区分一覧は移植計画で確定」を
   「第 1 リリース時点の列挙は本増分で確定する」に前倒す**ことを検討する
   (列挙が無いと番犬が作れず、無検査の穴が残る)

### 重大 4. BE-12 (生成物の還流でフィールド契約が食い違う) が未対応 — 新しいハンドラ契約が `any` 戻りで、読み手・書き手・テストを縛る仕組みが無い

**① 事実**

- `docs/design/architecture.md:300` / `templates/backend-repo/CLAUDE.md.tmpl`:
  `type ToolHandler = func(ctx context.Context, tx pgx.Tx, args json.RawMessage) (any, error)`
- `.claude/rules/feedback_review_patterns.md` の **BE-12**: 「読み手の構造体が、書き手に存在しない
  フィールドを期待している (PoC 実例: 読み手 `claude_managed_agents/cmd/devui/conversation_plan_grounding.go:100`〜`:102`
  が `finding`/`notes:string` を期待するが、書き手 `conversation_tools_deepdive.go:168`〜`:176` に `finding` は無く
  `notes` は `[]string`)。**テストが合成 JSON を渡していると契約違反が隠れる** — 読み手・書き手・テストを
  同じスキーマ定義から導くこと」
- 本増分の成果物 (`architecture.md` / `requirements-layering.md` / `plan-layering.md` /
  `templates/backend-repo/*`) に **BE-12 への言及は 0 件** (`grep -rn "BE-12"` のヒットは
  `docs/analysis/poc-conversation-flow.md:535` のみ)。BE-10 は §3.7-5 (LedgerStore を読み書き対で定義)、
  BE-11 は §3.7-3 (採番を Repository メソッドに閉じる) で構造的に潰されており、**BE-12 だけが抜けている**
- 本増分が触る経路は BE-12 の発生箇所そのものである — §3.10 のステップ 12 (深掘りの外部検索) →
  14 (生成物の永続化) → プロンプトへの還流 (D-E / BE-1)

**② 何が問題か**

`any` 戻りのハンドラ結果は (a) LLM への tool_result JSON、(b) 台帳・生成物として DB に保存される JSON、
(c) 後続ターンのプロンプトへ還流する入力の 3 経路に流れる。**型が `any` である限り、書き手 (ハンドラ) と
読み手 (プロンプト構築・還流処理・FE) のフィールド契約はコンパイラも CI も検査しない**。
§3.8.4 は tool 名と**引数**の 3 者一致 (BE-8) を CI 検査に載せたが、**戻り値の契約は対象外**である。
BE-12 は PoC で「テストが合成 JSON を渡していたため隠れた」形で起きており、
`docs/design/API/*` の schema とも自動では結びつかない。**「静かに壊れる」種類の欠陥**として
F-1 / F-3 (`observability.md:156`〜`:158`) と同じ扱いが必要なのに、設計に登場しない。

**③ 修正案**

`architecture.md` §3.8 に 1 小節 (§3.8.5 相当) を追加し、次を決める:

1. **ツール結果の型を 1 箇所で定義する** — `entity/` (副作用のない型定義) か
   `service/conversation` のツール結果型として**名前付き構造体**を置き、ハンドラは
   `(any, error)` ではなく**その型を返す** (`ToolHandler` を維持するなら、`any` に入れる値は
   「登録済みのツール結果型のいずれか」であることを起動時チェックに含める)
2. **還流・プロンプト構築・FE 表示が同じ型定義を読む**ことを規約にする (BE-12 の「読み手・書き手・
   テストを同じスキーマ定義から導く」)
3. **テストで合成 JSON を使わない**ことをテスト規約に落とす (書き手の型を経由して生成する)
4. §3.8.4 の 3 者一致検査に **「ツール結果型 ↔ 還流側の読み取り」** を追加するか、対象外なら理由を書く

---

## 中 (Should Fix)

### 中 1. メトリクス送出の先送り (observability §6.1 ⑦) が、O-4 と監査ログ規約の「メトリクス必須」と矛盾する

- **事実**: `docs/design/observability.md:206`〜`:208` (§6.1 の表) は「**⑦ メトリクス送出**・コスト算出・集計・
  アラート」を **v2 併用期間中**に先送りする。一方 同 `:152`「**5 分類すべてを warn ログ + メトリクスに出す**。
  握り潰し禁止」(O-4 / AC-2.3)、同 `:47` (O-F)「warn ログ + メトリクスの**両方**に出す」、
  `docs/design/architecture.md:451`「失敗時は **WARN ログ + メトリクスを必須**とする」(§3.9③ / O-6) は
  **初期実装の要求**として書かれている
- **問題**: 実装者が「第 1 増分でメトリクス基盤 (CloudWatch への送出) を作るのか」を判断できない。
  §6.1 の ⑦ は括弧内で「O-D のメトリクス / O-H の単価テーブル / §4.6 の AL-4」と**利用量系に限定**して
  読めるが、図 (`:82` の ⑦) は「メトリクスを送出 (CloudWatch)」と一般的に書かれている。
  ここが割れると **O-4 の失敗検知が「ログだけ」になり、AL-3 (切り詰めの全件通知) が動かない**まま
  第 1 リリースに出る。O-2 の先送りは理由付きで十分に書けているだけに、この一点が惜しい
- **修正案**: §6.1 の ⑦ を「**利用量メトリクスとコスト系アラート**」に限定して書き直し、
  「**失敗系メトリクス (F-1〜F-6) と監査ログ失敗メトリクスは初期実装**」を同表に別行で明記する
  (どちらの意図でも、表に 1 行足せば読み分けられる)

### 中 2. F11 の性格付けが実態より広い — 17 箇所のうち controller 3 箇所は監査ログではない

- **事実**: `docs/design/architecture.md:34` (F11) / `:453` は「**監査ログ・アクティビティログの
  書き込みエラー**を `_ =` で無言破棄。実測 **6 ファイル 17 箇所** (`usecase/` 4 ファイル 14 箇所 +
  `controller/` 2 ファイル 3 箇所)」と書く。出典 `hassan-v2-backend/docs/refactoring-plan.md:123`〜`:129` の
  実物は「**エラー破棄箇所**」の列挙であり、controller の 3 箇所は
  `controller/middleware.go:29` (`requestBody, _ = io.ReadAll(...)`) と
  `controller/business_plan.go:155,174` (`_, _ = c.Writer.WriteString(...)` = **SSE 送信**) である。
  さらに `usecase/business_plan/generation_job_manager.go:355` は `_ = m.generateUC.MarkGenerationFailed` で
  監査ログではない
- **問題**: (a) 出典の内容と設計書の主張が一致しない (DR-1 の軽度形)。実装リポの開発者は
  「17 箇所すべてが監査ログ」と読んで転記する。(b) より実質的な問題として、
  **SSE 書き込み失敗の握り潰し (2 箇所) は O-5 / F-5 (`observability.md:160`) の観測対象**であり、
  §3.9③ (監査ログ = 別 tx best-effort) の規約では覆えない。v2 の実害の一部が
  「監査ログ」に丸められて対策から漏れている
- **修正案**: F11 を「**エラー破棄 6 ファイル 17 箇所 (うち監査/アクティビティログ 12〜13 箇所、
  SSE 書き込み 2 箇所、リクエストボディ読み取り 1 箇所、ジョブ状態更新 1 箇所)**」に修正し、
  §3.9③ の適用対象を「監査ログ」に限定していることを明示する。
  **SSE 書き込み失敗の扱い**は `observability.md` §4.3 F-5 への参照を 1 行足して閉じる

### 中 3. `usecase` → `gateway` の具体依存が可なのか不可なのかが 2 箇所で食い違う

- **事実**: `docs/design/architecture.md:127`〜`:129` (図の読み方 3) 「**`usecase` は `repository` /
  `gateway` の具体パッケージに依存しない**」。一方 同 `:196` (L-4) 「`service` / `usecase` → `gateway` は**可**」。
  `templates/backend-repo/CLAUDE.md.tmpl` も両方の記述をそのまま持つ。
  depguard 側は `usecase/**` → `gateway/**` を deny していない (`L5-no-external-sdk` は SDK パッケージのみ)
- **問題**: L-5 (「gateway 実装の型を公開 IF に露出させない」) の担保が、
  「`usecase` が `gateway/anthropic` を import しないこと」に依存するのか、
  「import はしてよいが公開 IF に出さないこと」なのかで実装が変わる。前者なら depguard で表現できるが、
  現状の設計文はどちらとも読める (DR-5)
- **修正案**: L-4 の行を「`service` / `usecase` は **gateway の IF (利用側定義) を通してのみ使う。
  gateway パッケージの import は wire の組み立て箇所に限る**」と具体化し、
  可能なら `.golangci.yml` に `usecase/**` / `service/**` → `<module-path>/gateway` の deny を追加する
  (wire ファイルを除外パスにする)。**これができれば L-5 の CI 検査③の負担も減る**

### 中 4. `dupl` / `cyclop` / `funlen` の対象から `controller/` / `gateway/` / `entity/` が除外されている — F5 / F14 の再発地点が検査対象外

- **事実**: `templates/backend-repo/.golangci.yml:255` の
  `path-except: '(^|/)(usecase/(theme|asset|conversation|idea|plan)|service|repository/(theme|asset|conversation|idea|plan))/'`
  により、`controller/` / `gateway/` / `entity/` は 3 linter すべての対象外。
  `docs/design/architecture.md:487`「対象パスは §3.5.2 の『v3 新規ドメイン』区分に限る」と整合はしている
- **問題**: v2 の重複の実害は **F5 = `controller/` の 8 ファイル 61 箇所コピペ** と
  **F14 = `llm/{openai,gemini,claude,perplexity}` の HTTP/JSON 送受信 4 重複** であり、
  後者は v3 では **`gateway/<プロバイダ>/`** に移る (`architecture.md:55` の D-D 却下案 c が
  「F14 で 4 重複したのと同じ轍」と自ら書いている)。
  **`dupl` を主役に据えた根拠 (F3 / F14) のうち F14 の再発地点が除外側にある**。
  F5 は CI 検査④ (型アサーション禁止) で部分的に覆われるが、`gateway/` の重複は何にも覆われていない
- **修正案**: `path-except` から `gateway/` を外す (= `gateway/**` を `dupl` / `cyclop` / `funlen` の対象に含める)。
  `controller/` / `entity/` を除外し続けるなら、**除外理由を §3.9④ に 1 行書く**
  (現状は除外の事実だけがあり理由が無い)

### 中 5. Q-L11 (2026-07-30 のユーザー決定) が requirements / plan に未反映 — AC が無く、機械照合の対象外

- **事実**: `grep -rn "Q-L11"` のヒットは `questions-layering.md` / `docs/design/architecture.md:224` /
  `docs/design/observability.md:98,215,256` / `docs/design/API/README.md:442` /
  `docs/design/API/knowledge.md:205` のみ。
  **`requirements-layering.md` と `plan-layering.md` のヒットは 0 件**。
  `requirements-layering.md:12`〜`:14` は「**Q-L1〜Q-L10 も 2026-07-29 に全て回答済み**。…
  **暫定既定は残っていない**」、同 `:342` の §9 見出しも「(Q-L1〜Q-L10。全て回答済み)」で Q-L11 の行が無い
- **問題**: Q-L11 の帰結「**移植分でも LLM 呼び出しは gateway 経由を必須とし、これを移植の受入条件にする**」
  (`architecture.md:223`〜`:230`) は、**今後のすべての移植 PR に掛かる受入条件**でありながら
  **AC-ID を持たない**。`make check-traceability` は AC-ID の宙吊りしか見ないので、
  この決定が設計書から落ちても検出できない (DR-6 の逆パターン)。
  また requirements の「暫定既定は残っていない / Q-L10 まで」という記述が現状と合わず、
  次のセッションが最新決定を見落とす
- **修正案**: `requirements-layering.md` に **AC-6.21** (移植ドメインの LLM 呼び出しが `gateway/` 経由であること /
  「gateway を通らない LLM 呼び出しを残さない」が移植の受入条件として設計書に書かれていること) を追加し、
  §9 の表に Q-L11 の行、§8 の O-2 行に AC-6.21 を追記する。`plan-layering.md` に追随タスクを 1 行足す

### 中 6. `plan-layering.md` のステータスとチェックボックスが実態と乖離 / 影響範囲表に本増分で実際に触ったファイルの一部が無い

- **事実**: `aidlc-docs/inception/productionization/plan-layering.md:6`「ステータス: **未着手 (着手可)**」。
  Task-L3 以降のチェックボックスは**すべて `[ ]`** (完了は Task-L0a / L0b のみ)。
  実際には `architecture.md` は 264 → 669 行に改訂済み、`.golangci.yml` は新規作成済み、
  `templates/backend-repo/*` は更新済み。
  また §2.1 の影響範囲表に **`.golangci.yml` の新規作成**は ci.yml 行の中で言及されるのみで独立行が無く、
  `templates/README.md` / `templates/shared/.claude/rules/02-issue-granularity.md` / `03-model-escalation.md` /
  `templates/backend-repo/.claude/agents/*` / `templates/infra-repo/.github/ISSUE_TEMPLATE/task.yml` は**行が無い**
- **問題**: rule 05 の「完了報告」と push ゲートの鮮度チェックが依拠する計画の状態が信用できなくなる。
  次のセッションが「未着手」と読んで二重に着手する / 逆に触ったファイルが影響範囲に無いため
  レビュー対象の特定が漏れる (今回は依頼側が §2 で列挙してくれたので事故にならなかった)
- **修正案**: 完了タスクを `[x]` にし、ステータスを「Wave 1〜6 完了・Task-L24 (レビュー) 実施中」に更新する。
  §2.1 に上記 5 ファイル + `.golangci.yml` (新規) の行を追加する

### 中 7. `aidlc-docs/inception/productionization/plan.md:23` に `ToolDispatcher` が現行の検証手段として残存

- **事実**: `aidlc-docs/inception/productionization/plan.md:23`
  「| AC-1.3 | `docs/design/architecture.md` §3 の **`ToolDispatcher` 設計** + レビューで A-6 確認 | **骨格で回答済み** |」。
  `architecture.md` に `ToolDispatcher` は既に存在しない (grep 0 件)
- **問題**: AC-1.3 (custom tool の所有者スコープ) の**検証手段が存在しない設計要素を指している**。
  `requirements-layering.md:320` は「強制点が ToolDispatcher から『UseCase が注入するハンドラ』へ移る」と
  書いているので、親 plan の追随漏れ。`plan-layering.md` の Task-L23 は
  「plan.md / requirements.md / design_memo.md:145 の反映状況の更新」を挙げているが、この行を指していない
- **修正案**: `plan.md:23` の検証手段を「`docs/design/architecture.md` §3.8.2 (束縛 = `usecase/conversation/tool_registry.go`
  のクロージャ / 検証 = Repository のクエリ条件) + AC-6.8」に差し替える

### 中 8. 「depguard 6 規則」という記述が実物 14 規則と合わず、受入手順が実物を覆えない

- **事実**: `docs/design/architecture.md:201`「**depguard の 6 規則それぞれについて、違反サンプルで CI が
  落ちることを実装リポで確認する**」/ 同 `:606`「`.golangci.yml` (depguard 6 規則 + `dupl` / `cyclop` / `funlen`)」。
  `aidlc-docs/inception/productionization/plan-layering.md:39` も「depguard 6 規則」。
  実物 `templates/backend-repo/.golangci.yml` の規則名は **14 本**
  (L-1 系 5 本 / L-2・L-3 系 6 本 / L-4 / L-5 / L-6)
- **問題**: 「6 規則を違反サンプルで検証する」という受入手順に従うと、**14 本のうち 8 本が未検証で通る**。
  特に `L2-L3-service-unregistered-domain` (`:193`) は `files` の否定パターン (`!**/service/theme/**`) と
  モジュールルート deny (`pkg: "<module-path>/"`) という**特殊な書き方をしており、実際に落ちるかの
  確認が最も必要な規則**である
- **修正案**: 「6 規則」を「**L-1〜L-6 の各 ID につき、`.golangci.yml` の該当規則すべて (現行 14 本) を
  違反サンプルで検証する**」に改める。`plan-layering.md` の AC-6.14 行の検証手段にも
  「規則名の一覧と検証済みチェックの対応表を実装リポに残す」を追記する

### 中 9. §3.8.2 の「検証」が依拠する CI 検査は `Get*` 限定で、`list_assets` 系の一覧クエリを覆わない

- **事実**: `docs/design/architecture.md:340` (§3.8.2 の検証行) 「所有者引数の無い単一取得メソッドは
  CI で禁止する (auth.md §6.4)」。`docs/design/auth.md` §6.4 の機械強制は
  「`db/queries/*.sql` の `-- name: Get*` に所有者条件があるかを検査する」。
  PoC のツールには `list_assets` が実在する (`claude_managed_agents/cmd/devui/conversation.go:774`。照合済み)
- **問題**: ツール経路で最も件数が出るのは**一覧系** (`list_assets`) であり、`-- name: List*` は検査対象外。
  A-6 の「検証」段が機械強制で覆われていない部分を持つ。
  `auth.md` §6.4 の Repository 行は「**単一取得系も含め、すべてのクエリが所有者条件を `WHERE` に持つ**」と
  書いているので、規約と検査範囲がずれている
- **修正案**: `auth.md` §6.4 の検査を「`-- name: Get*` / `List*` / `Count*` を対象に所有者条件の有無を検査」に
  拡張し、`architecture.md:340` の文言も「所有者引数の無い取得系メソッド (単一・一覧の両方)」に改める

---

## 軽微 (Nice to Have)

1. **`docs/design/architecture.md:5`〜`:6` の前提ラベルが古い** — 「§2 (F1〜F14)」と書くが §1.1 の表は
   F2 / F13 を含まず、§3.9④ が使う分布は **F15**。「Q-L1〜Q-L10 の回答」も §3.5.2 で使う **Q-L11** を含まない。
   `:66` の「回答済み」列挙も Q-L11 が抜けている → 「F1〜F15」「Q-L1〜Q-L11」に更新
2. **`docs/design/architecture.md:525` (§3.10 ステップ 12)** 「`gateway/exa`。**ハンドラまたは Service から呼ぶ**」 —
   判断ポイントが両立のまま残っている (DR-5 の軽度形)。どちらでもよいなら「どちらでもよい (理由: 検索は
   ドメインを跨がないため)」と明記する
3. **`docs/design/architecture.md:356`〜`:361` (§3.8.3 の表) に「メトリクス送出」の行が無い** —
   `observability.md:206`〜`:208` の 3 段 (④⑤ / ⑥ / ⑦) と粒度が 1 項目ずれる。
   両者の SSOT 関係 (層 = architecture / 時期 = observability §6.1) は明記されているので実害は小さいが、
   §3.8.3 に「メトリクス送出は observability §6.1 の ⑦」と 1 行足すと読み替えが不要になる
4. **行番号参照の陳腐化** — `requirements-layering.md:174` / `:301` が
   「`templates/backend-repo/.github/workflows/ci.yml:41-42` の golangci-lint ステップ」を指すが、
   実物では 42〜46 行付近。行番号ではなくステップ名 (`- name: golangci-lint`) で参照する方が腐らない

---

## 本番観点カバレッジ (`.claude/rules/08-production-gates.md`)

**無言の省略 (DR-2) はゼロ**。本増分が触る ID はすべて回答か「先送り + 理由 + 先送り先」を持つ。

| ID | 状態 | 箇所 |
|---|---|---|
| A-1 認証方式 | 回答 (SSOT は auth.md) | `docs/design/architecture.md:568` / `:514` (§3.10-1) |
| A-2 ロール | 回答 (本増分対象外・先送り先明記) | `docs/design/architecture.md:569` / `requirements-layering.md:337` |
| A-3 テナント境界 | 回答 (テーブル確定は §4 = Q-1 待ち。理由明記) | `docs/design/architecture.md:570` / `:556` |
| A-4 絞り込みの層 | 回答 | `docs/design/architecture.md:571` / `:517`〜`:522` / `docs/design/auth.md` §6.4 の層別責務表 (Service / gateway 行が新設され、スコープを組み替えられない旨が明記) |
| A-5 ステータスコード | 回答 (対象外・SSOT 委譲) | `docs/design/architecture.md:572` / `docs/design/auth.md` §6.6 |
| **A-6 LLM の越境** | **回答 (本増分の主眼。構造で潰している)** | `docs/design/architecture.md:333`〜`:347` (§3.8.2) / `:520`〜`:522` / `docs/design/auth.md` §6.5 / `docs/design/API/README.md:206`〜`:218` / `docs/design/API/assets.md:161`。**ただし検証段の機械強制に穴 (中 9)** |
| A-7 共有・公開 | 回答 (参照。SSOT は auth.md / idea-boards.md) | `docs/design/architecture.md:574` |
| O-1 構造化ログ | 回答 (SSOT は observability §4.1) | `docs/design/architecture.md:575` |
| **O-2 LLM 計測** | **回答 + 先送りの理由と先送り先あり** | `docs/design/architecture.md:349`〜`:371` (§3.8.3) / `:576` / `docs/design/observability.md:44` (O-C) / `:194`〜`:208` (§6.1 = 時期の SSOT) / `docs/design/API/README.md:442` / `docs/design/API/knowledge.md:205` / `docs/design/API/assets.md:162`。移植ドメインも gateway 経由必須 (Q-L11)。**AC が無い (中 5)** |
| **O-3 コスト上限** | **回答** (拒否は設けない + 安全弁は初期実装必須。理由付き) | `docs/design/architecture.md:577` / `:359` / `docs/design/observability.md:46` (O-E) / `:172`〜`:180` (§4.4) |
| **O-4 失敗の可観測性** | **回答** (5 分類 + エラー契約で判別可能に) | `docs/design/architecture.md:417`〜`:425` / `:578` / `docs/design/observability.md:150`〜`:165`。**メトリクス送出時期が O-2 の先送りと衝突 (中 1)** |
| O-5 SSE | 回答 (実体は observability に委譲) | `docs/design/architecture.md:579` / `docs/design/observability.md:160` (F-5) / `:176`。**v2 の SSE 書き込み握り潰しは扱われていない (中 2)** |
| **O-6 監査ログ** | **回答 (本増分で「未回答」から解消)** | `docs/design/architecture.md:449`〜`:463` (§3.9③) / `:580` / `docs/design/observability.md` §4.5 |
| O-7 アラート | 回答 (通知先の実体は運用設計へ先送り。理由明記) | `docs/design/architecture.md:581` / `docs/design/observability.md` §4.6 |
| D-1 環境 | 部分 (先送り先明記) | `docs/design/architecture.md:582` / `:440` |
| **D-2 CI ゲート** | **回答 (本増分で 8 検査を追加)** | `docs/design/architecture.md:583` / `:191`〜`:202` (§3.5.1) / `:465`〜`:487` (§3.9④) / `templates/backend-repo/.golangci.yml` / `templates/backend-repo/.github/workflows/ci.yml`。**重大 1 / 重大 3 / 中 4 / 中 8 の欠落あり** |
| D-3 デプロイ手順 | 部分 (対象外・先送り先明記) | `docs/design/architecture.md:584` |
| D-4 マイグレーション | 未回答 (理由と決定タイミング明記) | `docs/design/architecture.md:585` / `:561` |
| D-5 シークレット | 回答 | `docs/design/architecture.md:586` |
| **D-6 Agent ライフサイクル** | **回答** (3 者一致検査 + 起動時チェック) | `docs/design/architecture.md:373`〜`:387` (§3.8.4) / `:587` / `templates/backend-repo/.github/workflows/ci.yml` の D-6 ステップ |
| D-7 段階リリース | 回答 | `docs/design/architecture.md:588` / `:595`〜`:597` (層規約併存下の移植手順) |
| D-8 IaC | 回答 (対象外・先送り先明記) | `docs/design/architecture.md:589` |

**頻出パターン (DR / BE / FE)**:

| # | 判定 |
|---|---|
| DR-1 出典なしの断定 | **無し** (22 件照合で 21 件一致。F11 の性格付けのみ中 2) |
| DR-2 本番観点の無言の省略 | **無し** (上表のとおり全 ID に回答か理由付き先送り) |
| DR-3 既存データの不在 | 該当なし (本増分はスキーマを扱わない。`architecture.md:560` で DR-3 を §4 = Q-1 待ちとして明示。移植側の 2 規約併存は §3.5.2 / §6 で手順化済み) |
| DR-4 PoC 実装のコピー設計 | **無し**。PoC は「振る舞いの正」としてのみ参照し (`:618`〜`:626`)、`net/http`・手書き store・DB 未接続フォールバックを**移植しない実装**として明記 |
| DR-5 曖昧語の丸投げ | ほぼ無し。中 3 (usecase→gateway の可否) と軽微 2 (ハンドラまたは Service) のみ |
| DR-6 AC の宙吊り | 機械照合は 44/44。ただし**逆方向の漏れ 1 件** (Q-L11 に AC が無い → 中 5) |
| DR-7 プロトタイプを仕様扱い | 該当なし |
| BE-1 プロンプトのデータ参照ミス | 構造で対応 (`:56` D-E 却下案 c で「どのバージョンを渡すか」を業務ルールとして `service/` に置く) |
| BE-2 hard cap 散在 | 構造で対応 (§3.9② の `config` SSOT。FE へは API レスポンスで配り、prompt へはテンプレート引数) |
| BE-3 `WriteEnv` | 構造で対応 (D-5 で `.env` 自動書き換えを不採用) |
| BE-5 DB 未接続フォールバック | 構造で対応 (`:382` 起動時チェックで fail-fast / `:626`) |
| BE-6 MaxTokens 切り詰め | 構造で対応 (`:421` `stop_reason` を `CallMeta` に常に載せる + §3.9② の MaxTokens 余裕) |
| BE-7 SSE マルチライン | 構造で対応 (`:528` 除外リスト方式・空行も本文) |
| BE-8 schema と handler の乖離 | 構造で対応 (§3.8.4 の起動時 + CI 検査) |
| BE-9 Agent Update の tools 全置換 | 構造で対応 (D-E: リポジトリのファイルを正とし発行をデプロイ手順に) |
| **BE-10 台帳 write-through 欠落** | **構造で対応** (`:267`〜`:269` LedgerStore を読み書き対で定義) |
| **BE-11 採番の冪等性** | **構造で対応** (`:262`〜`:265` 採番を Repository メソッド/単一 SQL に閉じる + 失敗を握り潰さない)。**ただし L-6 の型担保が崩れている (重大 2) ため、部分コミットの余地は残る** |
| **BE-12 フィールド契約の食い違い** | **未対応 (重大 4)** |
| FE-2 snake_case 漏れ | 触れていない (D-F の OpenAPI 型生成で構造的に解消される前提。本増分の対象外で妥当) |
| FE-6 数値パーサのレンジ誤抽出 | 構造で対応 (`:529` LLM 出力の数値化は `entity/` で **UT 必須**) |

---

## 良かった点

1. **実測の質が高く、再現可能**。F15 の関数長分布 (573 / 40 / 28 / 21 / 14 / 3) はコマンドごと再現でき、
   `funlen` を 80 行にしない判断が**推測ではなく分布**で支えられている。
   `dupl` 主役という選択も F3 の実害 (150 行重複 + 6 関数の同一骨格) に直結している
2. **v2 規約からの逸脱 (F8 = `service/` 禁止) を正面から扱っている**。`architecture.md:85`〜`:89` /
   §3.1 が「v2 は層規約を守りながら中身が肥大した (F1 + F3)」という**実測に基づく反証**を示し、
   「層の追加 + 機械強制 + 逃げ場」の 3 点セットが欠けたら v2 と同じ結果になると明言している。
   却下案 (a)(b)(c) も具体的で、DR 基準を満たす
3. **A-6 を「実装の正しさ」から「パッケージ依存」へ移した設計**が本増分の最大の成果。
   スコープをクロージャ束縛にし `tx` だけ引数に出す判断 (Q-L7=B) は、
   A-6 (Runner がスコープを組み替えられない) と BE-10 / BE-11 (トランザクション内で動くことが型に現れる)
   の**両方を同時に満たす**数少ない解で、理由も `:325`〜`:331` に明記されている
4. **却下済み案との混同を先回りして潰している** — `observability.md:44` の O-C 却下案 (b)
   「別プロセスの LLM プロキシ」と本増分の `gateway/` (同一プロセスのパッケージ層) の読み分けを
   両文書に書いており、「却下済み案の再提案」に見える事故を防いでいる
5. **SSOT の宣言が徹底している** — 層配置 = `architecture.md` §3.3 / §3.8.3、
   計測フィールド = `observability.md` §4.2、実施時期 = `observability.md` §6.1、
   認証判定 = `auth.md` §6.6。**同じ事実が 2 箇所で別の値を持つ状態が (中 1 を除いて) 無い**
6. **先送りの線引きに「後付けできるか」という一貫した基準がある** —
   型 (後付け不可) → 初期実装 / 明細 (append-only で遡れない) → 第 1 リリース前 /
   集計・コスト算出 (明細から再計算できる) → v2 併用期間中。08 が要求する
   「理由 + 先送り先」を満たすだけでなく、**基準が読者に再利用できる形**になっている
7. **雛形 (`templates/backend-repo/*`) への反映が設計と同時に行われている**。
   `.golangci.yml` の冒頭に転記元の節番号 (§3.5.1 / §3.5.2 / §3.9④ / §3.3) と
   実装リポでの置換手順が書かれており、雛形が「設計から切れた初期値」になっていない
8. **`entity/` を層として立て、CA との差 (逸脱 2 点) を明示**したことで、
   「Service が副作用を持つのは CA 違反ではないか」というレビュー時の議論が事前に閉じている (C-L10 の効果)

---

## 再レビューの条件

重大 1〜4 の修正後、次を確認して重大ゼロを判定する:

1. `.golangci.yml` に `service/**` → `usecase` / `controller` の deny があること (重大 1)
2. Service / ツールハンドラが受け取る `tx` の型が **利用側定義の narrow な IF** であり、
   `Commit` / `Rollback` / `Conn` が型に現れないこと (重大 2)
3. `ci.yml` に D-2 の②③④⑥⑦⑧ + `math/rand` の**落ちる placeholder**があり、
   `usecase/` / `repository/` の未登録ドメイン番犬が存在すること (重大 3)
4. ツール結果の型契約 (読み手・書き手・テストを同一定義から導く) が §3.8 に節として存在すること (重大 4)
5. `make check` がエラー 0 / 未カバー AC 0 で通ること

---

# 再レビュー (2026-07-30)

> 対象: 前回の重大 1〜4 に対する修正差分 + 前回指摘の棚卸し。
> 判定は本番基準 (`.claude/rules/08-production-gates.md` / `feedback_review_patterns.md`)。
> **判定: Design Freeze 不可 (新規の重大 1 件)。前回の重大 4 件はすべて解消。**

## 再レビュー サマリ

- 前回の重大 **4 件 → 全件解消** (うち 2 件は条件付き。条件は後述)
- **新規: 重大 1 件 / 中 4 件 / 軽微 2 件**
- 前回の中 9 件は **9 件すべて未対応** (今回の修正対象外)。うち **6 件は Freeze 条件に含めるべき** (優先度付けは §棚卸し)
- 前回の軽微 4 件は 4 件未対応 (軽微 4 は行番号がさらにずれた)
- 実行した検証: `make check` / `ci.yml` のステップ名の 1 対 1 照合 / `pgx.Tx` 引用の実在確認 (v2 vendor) /
  v2 における sqlc 生成パッケージの import 分布の実測 / `.golangci.yml` の逆流方向 20 通りの突き合わせ

### 追加レビュー対象 (リポジトリ相対パス)

- `templates/backend-repo/layering-scopes.yml` (**新規作成**)
- `templates/backend-repo/.github/workflows/ci.yml`
- `templates/backend-repo/.golangci.yml`
- `templates/backend-repo/CLAUDE.md.tmpl`
- `templates/backend-repo/.claude/agents/code-reviewer.md`
- `templates/backend-repo/.claude/agents/go-developer.md`
- `docs/design/architecture.md`
- `docs/design/observability.md`
- `docs/design/auth.md`
- `docs/design/API/README.md`
- `docs/design/API/assets.md`
- `docs/design/API/knowledge.md`
- `docs/analysis/gap-analysis.md`
- `aidlc-docs/inception/productionization/requirements-layering.md`
- `aidlc-docs/inception/productionization/plan-layering.md`
- `aidlc-docs/inception/productionization/questions-layering.md`
- `aidlc-docs/inception/productionization/requirements.md`
- `aidlc-docs/inception/productionization/plan.md`
- `CLAUDE.md`
- `templates/README.md`
- `templates/shared/.claude/rules/02-issue-granularity.md`
- `templates/shared/.claude/rules/03-model-escalation.md`
- `templates/infra-repo/.github/ISSUE_TEMPLATE/task.yml`
- `templates/backend-repo/.github/ISSUE_TEMPLATE/task.yml`

### `make check` (再実行)

```
[WARN ] ./docs/design/infrastructure.md:527 未回答の [Answer]:
[WARN ] ./docs/design/infrastructure.md:534 未回答の [Answer]:
[WARN ] ./docs/design/infrastructure.md:540 未回答の [Answer]:
[WARN ] ./docs/design/llm-migration.md:571 未回答の [Answer]:  (以下 llm-migration.md 5 件)
[WARN ] ./docs/design/operations.md:351 / :626 / :667 未回答の [Answer]:
[doc-lint] 対象 78 ファイル / エラー 0 件 / 警告 29 件
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 45/45 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
```

**エラー 0 / 未カバー AC 0**。警告 29 件はすべて対象外ファイル (`infrastructure.md` / `operations.md` /
`llm-migration.md` の `[Answer]` 未回答) と「TODO」語への反応で、本増分の成果物には無い。
**AC が 44 → 45 に増え全数カバー**されていることを確認 (AC-6.21 の追加が機械照合に載った)。

---

## 重大 1〜4 の判定

### 重大 1 (depguard に `service → usecase` / `controller` の deny が無い) → **解消**

- **確認した実物**: `templates/backend-repo/.golangci.yml:126`〜`:134` に **`L1-service-no-upper-layers`** が新設され、
  `files: ["**/service/**"]` / `deny: <module-path>/usecase`, `<module-path>/controller`。
  `allow` を持たない独立規則なので、`L2-L3-service-<domain>` (`:179` 以降) の `allow` とは干渉しない
- **「規則は独立評価される」という前提の判定**: 妥当。depguard v2 は 1 ファイルに対して
  **`files` がマッチした全規則を個別に評価し、いずれかの `deny` に当たれば違反を報告する**モデルであり、
  `allow` は**その規則の中でのみ** `deny` を打ち消す。したがって
  `L2-L3-service-theme` の `allow: [service/theme, repository/theme]` が
  `L1-service-no-upper-layers` の `usecase` deny を打ち消すことはない。
  ただし**これは未実行の前提**なので、`plan-layering.md` の受入手順にある違反サンプルに
  **「`service/theme` が `usecase/asset` を import する」ケースを必ず含めること** (→ 中 8 と連動。後述)
- **逆流方向の網羅**: `.golangci.yml:35`〜`:53` の対応表 17 行を、6 層 (controller / usecase / service /
  repository / gateway / entity) の全方向と突き合わせた。**内部層どうしの逆流に穴は無い**
  (`repository → gateway` の追加も確認: `:161`〜`:162`)。残る穴は 2 つで、いずれも
  「内部層どうし」ではないため表の範囲外だった:
  1. **`entity` → 外部 SDK / DB ドライバ / `net/http`** (→ 新規 中 3)
  2. **`service` / `usecase` → sqlc 生成パッケージ** (→ **新規 重大 A**)

### 重大 2 (L-6 の「型で担保」が `pgx.Tx` の実型と矛盾) → **解消**

- **確認した実物**: `docs/design/architecture.md` §3.7 の **2 を新設** (narrow IF の定義コードと理由)、
  §3.5.1 の L-6 行を **3 段の担保 (①型 = narrow IF / ②depguard = プールの import 禁止 / ③残余 = D-2⑨)** に分解、
  §3.8.1 の `ToolHandler` を `func(ctx, tx Tx, args) (any, error)` に変更 (`:341` に `service/conversation/tx.go` の
  `Tx` 宣言、`:325` に「`pgx.Tx` の実型を持つのはこの関数の中だけ」)。
  `.golangci.yml:23`〜`:27` / `:293`〜`:300` と `CLAUDE.md.tmpl` / `code-reviewer.md` も追随
- **出典の照合 (結論を左右するので全数)**: `hassan-v2-backend/vendor/github.com/jackc/pgx/v5/tx.go` の
  **`:122` = `type Tx interface {`** / **`:124` = `Begin(ctx context.Context) (Tx, error)`** /
  **`:130` = `Commit(ctx context.Context) error`** / **`:137` = `Rollback(ctx context.Context) error`** —
  **4 箇所すべて一致** (v2 は vendor ディレクトリを持つため、この引用は `make doc-lint` の実在チェックにも載る)
- **BE-10 / BE-11 の防御として機能するか**: **する**。宣言された引数型に `Commit` / `Rollback` が無いため、
  Service / ツールハンドラのコードは**コンパイル時に**トランザクション境界を動かせない。
  `sqlc` の `DBTX` と同形という指摘 (§3.7 の 2) も正しく、Repository の `XxxWithTx` の引数型として使える
- **残余の判定**: (a) Go では `tx.(pgx.Tx)` の型アサーションで `Commit` を再取得できる (言語仕様上、
  narrow IF は事故防止であって封鎖ではない) → **新規 軽微 1**。
  (b) `D-2⑨` の grep (`\.(Exec|Query|QueryRow)\(ctx`) は「narrow IF 経由の生 SQL」を狙う検査として妥当だが、
  **sqlc 生成メソッド名 (`GetAssetByID` 等) 経由の実行は検出しない** → **新規 重大 A**

### 重大 3 (D-2 の宣言と `ci.yml` の乖離 / 新ドメインの無検査化) → **解消 (条件付き)**

- **1 対 1 の照合結果** (`grep -n "^      - name:" templates/backend-repo/.github/workflows/ci.yml`):

  | 宣言 (§5 の D-2) | ci.yml のステップ | 未実装時 |
  |---|---|---|
  | ①⑤ | `:46` `D-2①⑤ golangci-lint …` | 設定ファイル同梱済み |
  | ② | `:116` `D-2② 層境界の公開関数の戻り値が CodedError か` | **`exit 1`** (placeholder) |
  | ③ | `:128` `D-2③ 外部 SDK 型の型エイリアス検出` | 雛形で実装済み |
  | ④ | `:141` `D-2④ CodedError の型アサーション…` | 雛形で実装済み |
  | ⑥ | `:152` `D-2⑥ config 以外での os.Getenv 禁止` | 雛形で実装済み |
  | ⑦ | `:162` `D-2⑦ 層規約の対象パスの登録漏れ検査` | **`exit 1`** (placeholder) |
  | ⑧ | `:176` `D-2⑧ 監査ログ戻り値の無言破棄 (_ =) の検出` | 雛形で実装済み |
  | ⑨ | `:188` `D-2⑨ Service / UseCase が SQL を直接実行していないか` | 雛形で実装済み |
  | `math/rand` | `:200` | **`exit 1`** (placeholder) |

  **①〜⑨ + `math/rand` が全数対応し、placeholder はすべて `else` 分岐で `exit 1`** している
  (無言スキップは無い)。ステップ名に検査 ID を入れた設計 (§5 の D-2 が明文化) により、
  **今後の乖離が grep で照合できる**形になった。D-2 の宣言を絞らずに検査を増やして一致させた判断も妥当
- **新ドメインの無検査化**: `templates/backend-repo/layering-scopes.yml` の新設と D-2⑦ により、
  `usecase/<新>` / `repository/<新>` が `.golangci.yml` の列挙から漏れた場合に落ちる経路ができた。
  `.golangci.yml:12`〜`:19` に「(a) L-2/L-3 規則 (b) L5 の files (c) exclusions (d) layering-scopes.yml を
  同一 PR で更新」という手順も入った
- **条件 (これが残るため「条件付き」)**: **D-2⑦ の仕様に欠陥がある** — `ported_domains` が非空になった瞬間に
  ①②③ の単純比較が必ず食い違う (→ **新規 中 1**)。加えて `layering-scopes.yml` の `common_layers` が
  すでに §3.5.2 の表とずれている (→ **新規 中 2**)

### 重大 4 (BE-12 未対応) → **解消 (条件付き)**

- **確認した実物**: `docs/design/architecture.md` **§3.8.5 を新設** (`:438`〜)。
  PoC の実例を出典付き (`conversation_plan_grounding.go:100`〜`:103` / `conversation_tools_deepdive.go:168`〜`:176`) で提示し、
  規約 6 点 (①型は `entity/toolresult/` に 1 箇所 ②`any` に入れてよい値をその型に限る・匿名 struct と
  `map[string]any` を禁止 ③読み手 4 経路すべてが同じ宣言から読む ④Runner は共通エンベロープ
  `Result` (`ToolName` / `Summary` / `Payload`) だけを扱い `Payload` を解釈しない ⑤テストは合成 JSON を
  手書きしない ⑥§3.8.4 の検査 4・5 で機械強制) を理由付きで定義。
  §3.8.4 の検査は **3 種 → 5 種**に拡張 (`:431`〜`:432`)、§3.8.1 の表にも
  「ハンドラ戻り値の構造が未定義にならない」の行が追加 (`:365`)。
  `ci.yml:98` の D-6 ステップ説明も 5 種に追随。`requirements-layering.md:286`〜 に **AC-6.21**、
  `plan-layering.md:102` に検証方法 (**PoC と同型の不整合を注入して落ちることを確認**)、`:171` に **Task-L28**
- **`entity/toolresult` に置く判断は妥当** — 書き手 (usecase のハンドラ) と読み手 (`service/conversation.Runner`) の
  両方が import できる層は L-1 上 `entity/` だけであり、理由も §3.8.5 の 1 に書かれている
- **`any` を維持した判断の判定 (コーディネータ Q3 への回答)**: **妥当。ただし 1 段の強化を推奨する** (中 4)。
  `any` は C-L9 (Runner が型依存を持たない) の境界表現として合理的で、規約 + CI 検査 +
  「placeholder が未実装なら CI が落ちる」形になっているため、**「実装時に気をつける」水準は脱している**。
  一方で規約①②は現状 **未実装スクリプトに依存**しており、コンパイラは何も守らない。
  **`Result.Payload` の型を marker interface にすれば、規約①②がコンパイラ強制に変わる**
  (`type Payload interface { isToolResultPayload() }` を `entity/toolresult` に置き、
  同パッケージの型だけが非公開メソッドで満たす)。これは **C-L9 の `ToolHandler` シグネチャを変えない**ため
  逸脱にならず、ユーザー判断も不要である → **要判断ではなく設計で解決できる** (中 4)
- **条件**: 上記の marker interface 化を採らない場合、BE-12 の担保は
  `scripts/check-tool-contract.sh` の実装品質 (読み手が参照するフィールドの静的解析) に全面依存する。
  その旨を §8 の残課題に明記すること (現在の §8 は「`any` の採否はユーザー判断」としか書いていない)

---

## 新規指摘

### 重大 A. sqlc 生成パッケージが `service/**` / `usecase/**` から import できる — L-3 と「SQL 実行は Repository の責務」の迂回路

**① 事実**

- `docs/design/architecture.md:141` (責務表) は Repository の責務を「**SQL 実行 (sqlc 生成クエリ)**」と定め、
  §3.4 の決定木も「SQL を実行するか → **Repository**」。D-A'''' (`:50`) は
  「**同一パッケージ内の参照は import 制約で表現できないため、L-3 の機械強制にはパッケージ境界が必要**」として
  `repository/<domain>/` の分割を決めている
- `templates/backend-repo/.golangci.yml` の 15 規則に、**sqlc 生成パッケージ (v2 では `db/rdb`) を
  `repository/**` 以外から deny する規則は無い**。`L2-L3-service-<domain>` は
  `<module-path>/service` と `<module-path>/repository` しか deny しない
- **v2 の実測 (2026-07-30)**: `grep -rl "hassan-v2-backend/db/rdb" --include='*.go'` の結果を
  ディレクトリ別に集計すると **`repository` 29 ファイル / `usecase/*` 8 ディレクトリ 27 ファイル /
  `controller` 3 / `entity` 1 / `auth` 1** = **repository 以外から 32 ファイルが import している**。
  ただし `rdb.New(` / `rdb.Queries` の使用は **repository 外に 0 件**で、実際の用途は
  生成された enum / 型の参照 (例: `usecase/research_sheet/handle_other.go:72` の
  `rdb.ConversationTypeEnumAiSheet`、`controller/company.go:222` の `rdb.LanguageTypeEnum`)
- `docs/design/architecture.md:562` (§4) は「`db/queries/` と sqlc 出力先の構成」を**データモデル増分へ先送り**している
- `ci.yml:188` の D-2⑨ は `\.(Exec|Query|QueryRow)\(ctx` の grep であり、
  **sqlc 生成メソッド名 (`GetAssetByID` 等) 経由の実行は検出しない**

**② 何が問題か**

sqlc 生成パッケージは **全ドメインの全クエリを 1 パッケージに含む**。これを `service/theme` から import できる限り、
`rdb.New(tx).GetAssetByID(ctx, ...)` の形で **他ドメインのデータへ到達でき、L-2 / L-3 が実質無効化される**。
本増分は「repository をドメイン別に分割してこそ L-3 が機械強制できる」という理屈で分割を決めているのに、
**分割されていない巨大パッケージが横に 1 つ残っている**状態である。
さらに §3.3 の「SQL 実行は Repository」も、A-4 / A-6 の「所有者条件付きクエリを Repository で強制」も、
この経路では効かない (BE-11 の「採番を Repository のメソッドに閉じる」も同様)。
**v2 の実測が示すとおり、sqlc パッケージを repository 以外から import する慣行は既定で発生する** —
v2 は幸いクエリ実行までは漏れていないが、それは規約ではなく偶然であり、
v3 の depguard はこの方向を一切見ていない。

**③ 修正案 (3 択。①が最も安いが移植コストとの兼ね合いで決める)**

1. **sqlc 生成パッケージを `repository/**` 以外から deny する** (`.golangci.yml` に 1 規則 +
   §3.5.1 の L-3 行に 1 文)。ただし v2 移植コードは **enum / 型の参照で 32 ファイルが import している**ため、
   移植分 (`usecase/` の移植ドメイン・`controller/`) を除外パスにする必要がある
2. **生成 enum / 型を `entity/` へ変換して露出させる** (sqlc パッケージを repository の内側に完全に閉じる)。
   最も規約が単純になるが、移植時の書き換え量が増える
3. **D-2⑨ を「sqlc `Queries` 型の使用検出」まで拡張する** (import は許すが実行を禁止する)。
   grep では弱く、go/ast が必要

いずれを採るにしても、**設計側で決めるべきことは「sqlc 生成パッケージを import できる層」の 1 行**である。
出力先パスの確定はデータモデル増分でよいが、**規則自体を今決めないと、パスが決まった時点で
既に移植コードが依存してしまい後戻りコストが跳ね上がる** (v2 の 32 ファイルが前例)。
`docs/design/architecture.md` §3.5.1 (L-3 の行) と §4 の残課題、および §8 に申し送りを書くこと。

### 中 1. D-2⑦ の仕様が `ported_domains` を扱えない (非空になった瞬間に必ず落ちる)

- **事実**: `templates/backend-repo/layering-scopes.yml:12`〜`:15` と `ci.yml:162`〜`:174` は、
  検査⑦を「①実ディレクトリ集合 ②`v3_domains + ported_domains` ③`.golangci.yml` に現れるドメイン名 の
  **3 つを突き合わせ、1 つでも食い違えば落とす**」と定義している。
  一方 `.golangci.yml` に登録すべきなのは **`v3_domains` だけ** (移植分は L-2 / L-3 / L-5 と肥大化 lint の
  強制対象外 = `architecture.md:214` / `layering-scopes.yml:26`〜`:33`)
- **問題**: 仕様どおり実装すると、`ported_domains` に 1 つでも値が入った時点で
  ②に含まれ③に含まれないドメインが生じ、**CI が恒久的に落ちる**。実装者は検査を緩めるか除外するかを迫られ、
  「登録漏れの検出」という⑦の目的が失われる。`ported_domains: []` の現状では潜在しているが、
  **最初の移植 PR で必ず踏む**
- **修正案**: 検査の比較を非対称に定義し直す — **①(実ディレクトリ) == ②(v3 + ported) の一致**、
  **③(`.golangci.yml` のドメイン名) == `v3_domains` の一致**、加えて
  **`ported_domains` のドメイン名が③に現れないこと**の 3 条件。`ci.yml:167`〜`:172` の echo 文と
  `layering-scopes.yml` の冒頭コメント、`architecture.md:219` の記述を同じ 3 条件に揃える
- (コーディネータ Q4 への回答) **`ported_domains: []` 自体は妥当**。空のまま
  `usecase/<移植ドメイン>` を作れば①と②が食い違って落ちる = 意図した挙動であり、
  「移植を始めるまで空」で問題ない。**破綻するのは空でなくなった後**なので、上記の非対称化が前提条件になる

### 中 2. `layering-scopes.yml` と §3.5.2 の表がすでにずれている / 設計リポ側は機械照合できるのに残課題扱いになっている

- **事実**: `templates/backend-repo/layering-scopes.yml:35`〜`:40` の `common_layers` は
  **`entity` / `gateway` / `controller` / `config` の 4 つ**。
  `docs/design/architecture.md:213` (§3.5.2 の共通層の行) は
  **`entity/**` / `gateway/**` / `controller/**` の 3 つ**で、`config` は含まれない
  (`config` は §3.9② で置き場として定義されるだけで、§3.5.2 の区分表には現れない)
- **問題**: **二重管理のドリフトが、写しを作った当日にすでに 1 件発生している**。
  §3.5.2 が「本表に無いパッケージを新設する PR は本表への追記を同一 PR に含める」を運用ルールにしている以上、
  `config` がどの区分に属するのか (共通層なのか、区分外なのか) は表側で決める必要がある
- **加えて**: `architecture.md:709`〜`:712` (§8) は「**写しの同期は機械では検査できない**ため
  レビュー観点として残る」と書くが、**`templates/backend-repo/layering-scopes.yml` は設計リポ内にある**ので、
  **設計リポ側の同期は機械照合できる** (`scripts/doc-lint.sh` か新しい make ターゲットで
  §3.5.2 の表と yml のドメイン集合を突き合わせられる)。機械化できないのは
  **実装リポへ切り出した後の写し**だけである
- **修正案**: (a) `config` を §3.5.2 の共通層の行に追記する (または yml から外す)。
  (b) §8 の記述を「**設計リポ側は `make check` で照合する (未実装 → 追加する)** / 切り出し後の
  実装リポ側の写しは D-2⑦ が見る」に改める。(c) 可能なら `scripts/` に照合を追加する
  (本リポジトリの検証ゲートが「設計と雛形の一致」を見る唯一の機会である)

### 中 3. `entity/` の「SQL 実行・外部 API 呼び出し禁止」が depguard で未強制

- **事実**: `docs/design/architecture.md:140` (責務表) は entity の禁止事項を
  「**SQL 実行、外部 API 呼び出し**、他層への依存」と定める。
  `.golangci.yml:96`〜`:110` の `L1-entity-no-other-layers` は **内部層 5 つしか deny していない** —
  `github.com/jackc/pgx/v5` / `database/sql` / `net/http` / 外部 SDK は deny リストに無い
- **問題**: 「他層への依存」だけが機械強制され、**同じ行に並ぶ 2 つの禁止事項が検査されていない**。
  今回 **`entity/toolresult` がツール結果の型の唯一の宣言場所**になり (§3.8.5)、
  entity は「読み手・書き手が共有する中心」に格上げされた。ここに DB / HTTP が混入すると
  L-1 の最内側が汚れ、`entity` のテストが DB・外部 API を要求し始める (C-L5 の却下理由そのもの)
- **修正案**: `L1-entity-no-other-layers` の deny に
  `database/sql` / `github.com/jackc/pgx/v5` / `net/http` / `github.com/anthropics/anthropic-sdk-go` を追加する
  (`.golangci.yml:11` の「実装リポで依存が確定した SDK を追記する」手順に entity 側も含める)。
  併せて `.golangci.yml:35`〜`:53` の対応表に「entity → 外部 SDK / DB ドライバ / HTTP」の行を足す

### 中 4. BE-12 の規約①② をコンパイラ強制にできる (marker interface) — 現状は未実装スクリプトに全面依存

- **事実**: `docs/design/architecture.md:365` / §3.8.5 の規約①② は
  「戻り値は `any` のまま / 入れてよい値は `entity/toolresult` の宣言に限る / 匿名 struct・`map[string]any` を禁止」。
  この禁止を検査するのは `scripts/check-tool-contract.sh` (§3.8.4 の検査 4・5) だが、
  **本体は実装リポで未実装** (`ci.yml:98` の placeholder)。`architecture.md:713`〜`:716` (§8) は
  「戻り値の型を `entity/toolresult.Result` に変えれば型で担保できるが C-L9 からの逸脱になるため
  採否はユーザー判断」としている
- **問題**: C-L9 が縛っているのは **`ToolHandler` のシグネチャ** (`func(ctx, tx, args) (any, error)`) であり、
  **エンベロープ内部の `Payload` の型は C-L9 の対象外**である。
  したがって「`Payload any` を `Payload toolresult.Payload` (非公開メソッドを持つ marker interface) にする」は
  **C-L9 からの逸脱にならず、ユーザー判断も不要**で、規約①② が**コンパイル時に**強制される
  (`map[string]any` や匿名 struct は marker を満たせないため代入できない)。
  現在の §8 の書き方は「型で担保するには C-L9 を破るしかない」と読めるため、
  **より強い選択肢が検討されないまま残課題化している**
- **修正案**: §3.8.5 の規約② に「`Result.Payload` の型は `entity/toolresult` が定義する marker interface とし、
  同パッケージの型のみが満たす」を追加する。採らない場合は
  §8 の残課題を「`Payload` を marker interface にする案を検討したが〜の理由で採らない。
  したがって BE-12 の担保は `check-tool-contract.sh` の実装品質に依存する」に書き換える (判断の記録)

### 軽微 1. narrow IF は `tx.(pgx.Tx)` の型アサーションで迂回できる

- **事実**: §3.7 の 2 / §3.8.1 の表は「`Begin` / `Commit` / `Rollback` を持たない**ので
  Service がトランザクション境界を動かせない**」と書く。Go では、渡された値の実体が `pgx.Tx` である以上
  `if t, ok := tx.(pgx.Tx); ok { t.Commit(ctx) }` が成功する
- **判定**: 言語仕様上の限界で、**事故防止としては十分** (ヘルパー関数の中で誤って Commit する形は封じられる)。
  ただし「動かせない」という断定は 1 段強い
- **修正案**: §3.7 の 2 に 1 文 (「型アサーションで実型に戻す抜け道は残るため、
  `D-2⑨` の検査対象に `.(pgx.Tx)` / `.(*sql.Tx)` の型アサーション検出を含める」) を足すか、
  `code-reviewer.md` の L-6 観点に 1 行足す

### 軽微 2. D-2③ (型エイリアス検出) の grep が module 内パッケージへのエイリアスも一律に落とす / D-2④ が雛形限定のファイル名規約に依存する

- **事実**: `ci.yml:130`〜`:131` の正規表現は `^type +X += +[a-z]\w*\.` で、
  **`type Result = toolresult.Result` のような module 内パッケージへのエイリアスも一致する**。
  L-5 が禁止しているのは「**外部 SDK・gateway 実装**の型」(`architecture.md:197`) であって module 内ではない。
  また `ci.yml:141`〜`:148` の D-2④ は除外パスに **`controller/errresp.go`** を決め打ちしているが、
  この命名は `architecture.md` §3.9① に無い (設計は「`controller/` 内の変換関数 1 本」までしか決めていない)
- **問題**: 前者は誤検知で「除外して黙らせる」運用に流れやすい (`code-reviewer.md` が
  「除外設定で黙らせた形跡があれば重大指摘」としているのと衝突する)。
  後者は雛形コメントに「別のファイル名にする場合は除外パスだけを変える」と書かれており実害は小さいが、
  設計側に命名が無いため実装リポごとに揺れる
- **修正案**: D-2③ の grep を「右辺のパッケージが module 内でないもの」に絞る
  (`grep -v "= *\(entity\|toolresult\|config\)\."` のような後処理、または go/ast へ移す)。
  D-2④ は `architecture.md` §3.9① に「変換関数の所在は `controller/errresp.go` (1 箇所)」と 1 行書いて SSOT にする

---

## 前回指摘の棚卸し (中 9 件 / 軽微 4 件)

| # | 内容 | 状態 | 優先度 |
|---|---|---|---|
| 中 1 | メトリクス送出の先送り (`observability.md:257`) と O-4 の「5 分類すべてを warn ログ + メトリクス」(`:152`) / §3.9③ の「WARN + メトリクス必須」(`architecture.md:524` 付近) の矛盾 | **未対応** (両記述とも変更なし) | **高 (Freeze 条件)** — 第 1 増分でメトリクス基盤を作るのかが決まらない。§6.1 の表に 1 行足すだけで解ける |
| 中 2 | F11 の性格付け (17 箇所のうち controller 3 箇所は `io.ReadAll` と SSE `WriteString`) | **未対応** (`architecture.md:34` / `:526` / `:653` とも「監査ログ…6 ファイル 17 箇所」のまま) | **中** — 事実の精度。今回追加された `D-2⑧` の grep が `Log\|Audit\|Activity\|Event` を含む行だけを見るため、**SSE 書き込みの握り潰しは検査対象外**であることが実物で確認できた。F11 の記述を直すと同時に「SSE は `observability.md` §4.3 F-5 が扱う」の 1 行を足すのが安い |
| 中 3 | `usecase` → `gateway` の具体依存が可 (`:196` の L-4) か不可 (`:127` の図の読み方 3) か食い違う | **未対応** | **高 (Freeze 条件)** — 実装者が最初に迷う。L-4 の 1 文を具体化するだけ |
| 中 4 | `dupl` / `cyclop` / `funlen` が `controller/` / `gateway/` / `entity/` を除外 (F5 / F14 の再発地点) | **未対応** (`.golangci.yml:314` の `path-except` は変更なし) | **高 (Freeze 条件)** — F14 (LLM 4 プロバイダの HTTP/JSON 重複) は v3 では `gateway/` に移るのに、`dupl` の対象外。`path-except` から `gateway/` を外すか、除外理由を §3.9④ に書く |
| 中 5 | Q-L11 (移植分も gateway 経由必須) に AC が無い / `requirements-layering.md:12`〜`:14` が「Q-L1〜Q-L10」「暫定既定は残っていない」のまま | **未対応** (`grep -c Q-L11` = requirements-layering **0** / plan-layering **0**) | **高 (Freeze 条件)** — 移植の受入条件が機械照合の外。AC-6.22 相当を 1 つ足し §9 に行を追加するだけ |
| 中 6 | `plan-layering.md` のステータスが「未着手 (着手可)」/ 完了タスクが `[ ]` のまま (`[x]` 2 件 : `[ ]` 24 件) / 影響範囲表に `.golangci.yml` 新規・`templates/README.md`・`templates/shared/*`・`agents/*`・`layering-scopes.yml` が無い | **未対応** (Task-L28 も `[ ]`) | **中 (Freeze と同時に必須)** — Design Freeze を宣言する時点で計画が完了状態を示していないと、次のセッションが二重着手する |
| 中 7 | `aidlc-docs/inception/productionization/plan.md:23` の AC-1.3 検証手段が `ToolDispatcher` (存在しない設計要素) | **未対応** | **高 (Freeze 条件)** — 1 行の差し替え。AC-1.3 (A-6 の中核) の検証手段が宙に浮いている |
| 中 8 | 「depguard **6 規則**」の記述が実物と合わない (`architecture.md:201` / `:679`、`plan-layering.md:41` / `:95` / `:231`)。実物は **15 規則** | **未対応** (規則が 14 → 15 に増えてさらに乖離) | **高 (Freeze 条件)** — 受入手順が「6 規則ぶんの違反サンプル」なので、**今回の重大 1 の修正で追加した `L1-service-no-upper-layers` が検証対象に入らない**。重大 1 の再発防止が手順から漏れる |
| 中 9 | A-6 の「検証」が依拠する CI 検査 (`auth.md:580`) が `-- name: Get*` 限定で、`list_assets` 等の一覧クエリを覆わない | **未対応** | **中〜高** — ツール経路で最も件数が出るのは一覧系。`Get*` / `List*` / `Count*` に広げる 1 行 |
| 軽微 1 | `architecture.md:5`〜`:6` の「§2 (F1〜F14)」「Q-L1〜Q-L10」ラベル (実際は F15 / Q-L11 まで) | **未対応** | 低 |
| 軽微 2 | `architecture.md:598` (§3.10 ステップ 12) 「ハンドラまたは Service から呼ぶ」 | **未対応** | 低 |
| 軽微 3 | §3.8.3 の表に「メトリクス送出」の行が無い (`observability.md` §6.1 の ⑦ と粒度が 1 項目ずれる) | **未対応** | 低 (中 1 と同時に直すのが自然) |
| 軽微 4 | 行番号参照の陳腐化 — `requirements-layering.md:174` / `:301` と `plan-layering.md:95` が指す `ci.yml:41-42` | **未対応 (悪化)** — golangci-lint ステップは現在 **`ci.yml:46`** | 低〜中 (AC-6.14-3 の検証手順が実物とずれるため、ステップ名参照に変えるのが安い) |

---

## Design Freeze の可否 (再判定)

**不可**。理由は次の 1 点:

- **重大 A (sqlc 生成パッケージの import 制約が無い)** — 本増分の中核不変条件 (L-2 / L-3 と
  「SQL 実行は Repository」) を迂回できる経路が残っており、**v2 で 32 ファイルが同種の import を
  既定で行っている**ため、実装リポで必ず踏まれる。設計側の決定は 1〜2 行で書ける

**併せて Freeze 条件に含めることを推奨する 6 件** (いずれも 1 行〜数行の修正で、
放置すると実装リポで手戻りになるもの): **中 8** (重大 1 の修正が受入手順から漏れる) /
**中 5** (移植の受入条件が機械照合の外) / **中 7** (AC-1.3 の検証手段が存在しない要素を指す) /
**中 3** (usecase → gateway の可否) / **中 4** (F14 の再発地点が `dupl` の対象外) /
**中 1** (メトリクス送出の実施時期の矛盾)。加えて **中 6** は Freeze 宣言と同時に必須
(計画が完了状態を示すこと)。

新規の中 1〜4 / 軽微 1〜2 は、上記と同じ改訂サイクルで併せて処理するのが安い。

## 良かった点 (再レビュー分)

1. **指摘の受け止め方が正しい方向に一段進んでいる** — 重大 1 に対して「1 規則を足す」で終わらせず、
   **逆流方向 20 通りの対応表を `.golangci.yml` のコメントに埋め込み、`repository → gateway` の
   欠落まで自力で見つけて塞いだ**。次に規則を追加する人が同じ検査をやり直せる形になっている
2. **重大 2 の修正が「指摘された記述の書き換え」ではなく「機構の差し替え」になっている** —
   narrow IF の導入・実型の出典 (`vendor/.../tx.go:122`・`:124`・`:130`・`:137`) の提示・
   残余 (SQL は実行できる) を D-2⑨ として明示的に切り出した 3 段構成は、
   **「型で担保」という主張の射程を正確に述べている**。引用 4 箇所はすべて実在を確認した
3. **D-2 の宣言を絞らず、検査を増やして実物と一致させた** — 楽な方向 (宣言を削る) を採らず、
   **ステップ名に検査 ID を入れて grep で 1 対 1 照合できる形**にしたのは、
   本リポジトリの「宣言と機構の乖離」を将来にわたって検出可能にする良い設計判断である
4. **BE-12 の節が「PoC の実害 → 規約 → 検査」の順で書かれている** — 出典 (読み手・書き手の行番号) を
   先に置き、規約 6 点それぞれに理由列を付け、最後に CI 検査へ接続している。
   `Runner` が `Payload` を解釈しない (規約 4) という判断は、C-L9 の「Runner は触るドメインを知らない」を
   結果の読み取りにまで一貫させたもので、設計の筋が通っている
5. **`layering-scopes.yml` を「機械可読な写し」と明示し、正が architecture.md §3.5.2 であることを
   ファイル冒頭に書いた** — 二重管理を隠さず、同期の責任がどこにあるかを明記している
   (ドリフト 1 件が既に発生している点は中 2 で指摘したが、構造としては正しい)

---

# 再々レビュー (2026-07-30) — 最終判定

> 対象: 重大 A + 優先度高の中 6 件 + 新規中 4 件 + 新規軽微 2 件への修正差分。
> **判定: Design Freeze 可 (重大ゼロ)**。ただし **Freeze コミットと同時に閉じるべき事務項目が 2 件**ある (後述)。

## 最終サマリ

- **重大: 0 件** (前回の重大 A は解消。前回までの重大 1〜4 も解消済み)
- **中: 3 件** (新規 1 件 / 前回からの残り 2 件) / **軽微: 5 件** (新規 1 件 / 残り 4 件) —
  **いずれも Freeze を止めない**。うち 2 件は Freeze と同時に処理すべき事務項目
- 実行した検証: `make check` / v2 における `db/rdb` の import 分布の**独立再測定** /
  新規引用 6 件の実在確認 / `.golangci.yml` 17 規則の逆流方向の突き合わせ /
  `ci.yml` の D-2①〜⑨ の 1 対 1 照合 / `observability.md` §6.1 の ⑧ と 3 段の整合確認

### レビュー対象 (リポジトリ相対パス。前回分 + 今回)

`docs/design/architecture.md` / `docs/design/observability.md` / `docs/design/auth.md` /
`docs/design/API/README.md` / `docs/design/API/assets.md` / `docs/design/API/knowledge.md` /
`docs/analysis/gap-analysis.md` /
`templates/backend-repo/.golangci.yml` / `templates/backend-repo/.github/workflows/ci.yml` /
`templates/backend-repo/layering-scopes.yml` / `templates/backend-repo/CLAUDE.md.tmpl` /
`templates/backend-repo/.claude/agents/code-reviewer.md` /
`templates/backend-repo/.claude/agents/go-developer.md` /
`templates/backend-repo/.github/ISSUE_TEMPLATE/task.yml` /
`templates/infra-repo/.github/ISSUE_TEMPLATE/task.yml` / `templates/README.md` /
`templates/shared/.claude/rules/02-issue-granularity.md` /
`templates/shared/.claude/rules/03-model-escalation.md` /
`aidlc-docs/inception/productionization/requirements-layering.md` /
`aidlc-docs/inception/productionization/plan-layering.md` /
`aidlc-docs/inception/productionization/questions-layering.md` /
`aidlc-docs/inception/productionization/requirements.md` /
`aidlc-docs/inception/productionization/plan.md` / `CLAUDE.md`

### `make check` (最終)

```
[WARN ] ./docs/design/operations.md:619 未回答の [Answer]:
[WARN ] ./docs/design/operations.md:660 未回答の [Answer]:
[doc-lint] 対象 79 ファイル / エラー 0 件 / 警告 33 件
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 46/46 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
```

エラー 0 / 未カバー AC 0。警告 33 件はすべて対象外ファイル (`infrastructure.md` / `operations.md` /
`llm-migration.md` の `[Answer]` 未回答) と「TODO」語への反応。**AC は 45 → 46 に増え全数カバー**
(AC-6.22 の追加が機械照合に載った)。

---

## ① 重大 A (sqlc 生成パッケージの import 制約) → **解消**

**確認した実物**:

| # | 対応 | 確認箇所 |
|---|---|---|
| 1 | `L3-no-sqlc-outside-repository` の新設 | `templates/backend-repo/.golangci.yml:305`〜。`files` = `usecase/{theme,asset,conversation,idea,plan}/**` + `service/**` + `controller/**` + `entity/**` の 8 件、`deny` = `<module-path>/db/rdb` |
| 2 | 設計側の規則化 | `docs/design/architecture.md:195` (L-3 行の更新) / **`:212`〜 の「sqlc 生成パッケージの扱い」節** (規則 1〜4 + 担保列) / `:310` (§3.6 に「『外部の型』には sqlc の生成物も含める」) |
| 3 | backstop | `ci.yml` の **`D-2⑨`** が (a) `Exec`/`Query`/`QueryRow` (b) **sqlc パッケージの import** (c) `.(pgx.Tx)` / `.(*sql.Tx)` の 3 種を検出し、いずれかで `fail=1` |
| 4 | 適用範囲 | `files` が `**/usecase/**` ではなく **5 ドメインの個別列挙**なので `usecase/account` 等の移植分はマッチしない。§6 に「移植時に発生する作業 (sqlc 生成型の切り離し)」、§8 に残課題 |
| 5 | 出力先構成の申し送り | §3.5.1 の規則 4 と §8。`.golangci.yml:302` 付近に「`<module-path>/db/rdb` を実際の出力先に置換。複数パッケージなら共通の親パスを指定」 |

**事実の再測定 (独立に実施。前回の「32 件」は集計条件の誤りだったため再確認)**:

```
$ grep -rl "hassan-v2-backend/db/rdb" --include='*.go' . | grep -v vendor | grep -v "^./db/" | grep -v _test.go | wc -l
73                     # うち repository 29 → repository 以外 = 44
   1 auth / 3 controller / 1 entity / 29 repository / 39 usecase
$ grep -rn "rdb\.New(" --include='*.go' . | grep -v /vendor/ | grep -v _test | grep -vE "(^|/)(repository|db)/" | wc -l
0
```

→ 設計書の記述 (**44 件** / `usecase/` 39 / `controller/` 3 / `entity/` 1 / `auth/` 1 / **`rdb.New(` の
repository 外は 0 件**) は**完全一致**。新規引用 4 件も実在を確認した:
`hassan-v2-backend/usecase/mfa/reset_totp.go:26` = `rdb.MfaTypeEnumTotp` /
`hassan-v2-backend/controller/company.go:222` = `rdb.LanguageTypeEnum(languageType)` /
`hassan-v2-backend/usecase/repository_interfaces.go:37` = `GetAllActiveAccountsJA(...) ([]rdb.Account, error)` /
同 `:235` = `UpdateUserPasswordByID(ctx, params rdb.UpdateAdminAccountPasswordByIDParams) error`。
**`repository_interfaces.go` が Repository IF の定義ファイル (F7) である**という指摘も正しく、
規則 2 (生成型を上位層の契約に出さない) の狙いが具体例と結びついている。

**抜け道の検査 (コーディネータ Q1)**:

| 検査した抜け道 | 判定 |
|---|---|
| `db/rdb` 以外の生成パッケージ (sqlc が複数パッケージを吐く場合) | **塞がっている** — depguard は prefix 一致なので共通の親パス (`<module-path>/db`) を指定すれば足り、その手順が `.golangci.yml` のコメントに明記されている |
| `entity/` 経由の間接参照 (entity に生成型を再輸出する) | **塞がっている** — `L3-no-sqlc-outside-repository` の `files` に **`**/entity/**` が含まれる**。加えて `L1-entity-no-side-effects` が `pgx` / `database/sql` を deny |
| wire 生成コードの誤検知 | **起きない** — wire の生成物は `usecase/<domain>/` ではなく DI の組み立て場所に置かれ、`files` の 8 パターンに該当しない。**ただし配置場所が設計に書かれていない** (下記 軽微 B) |
| `gateway/**` からの import | **塞がっていない** → **中 A (新規)** |
| 移植分の誤検知 | **起きない** — `files` の usecase 側が 5 ドメイン個別列挙であることを YAML の実物で確認 |

## ② 棚卸し (前回の中 9 / 軽微 4 / 新規中 4 / 新規軽微 2)

| # | 内容 | 状態 | Freeze を止めるか |
|---|---|---|---|
| 中 1 | メトリクス送出の時期矛盾 | **解消** — `observability.md` §6.1 に **⑧ 行**を新設し「メトリクス基盤 (出力手段) + 失敗系 warn メトリクス = 初期実装」を明記。**⑧ は 3 段の一部ではない**ことを明示して Q-L10=B の線引きを保持 (`:293`)。§3 の図の直後 (`:106`〜`:110`)・§4.6・§5 の O-3 / O-7 行から到達可能。誤読時に O-4 / O-6 / A-6 が初回リリースで欠落することも明記 | 止めない |
| 中 2 | F11 の性格付け | **半解消** — `requirements-layering.md:54` は訂正済み (監査ログの破棄は `usecase/` 14 箇所のみ / `controller/` 3 箇所は `io.ReadAll` と SSE で、`refactoring-plan.md:143` の `Warnw` 区分を出典に区別 / AC-6.13 の対象を 14 箇所に限定)。**`docs/design/architecture.md:34` (F11) と `:590` (§3.9③) は旧記述のまま** | 止めない (→ 軽微 A) |
| 中 3 | `usecase` → `gateway` の可否 | **解消** — L-4 行を「依存するのは利用側が定義した IF。具体パッケージを import するのは wire だけ」に具体化し、**depguard で表現しない理由 (wire 生成コードの誤検知) と、機械で見られない残余を `code-reviewer.md` で見ること**まで書かれた |
| 中 4 | `dupl` / `cyclop` / `funlen` が共通層を除外 | **解消** — 対象を「v3 で新規に書くコード全体」に拡大 (`controller` / `gateway` / `entity` / `config` を追加)。除外は v2 移植分のみ。**F14 (gateway) / F5 (controller) を出典付きで理由に挙げている**。`.golangci.yml:383` の `path-except` も一致 |
| 中 5 | Q-L11 に AC が無い | **解消** — **AC-6.22** を新設 (`requirements-layering.md:312`〜)。3 条件 + 根拠付き。`plan-layering.md:103` に検証方法。traceability 46/46 |
| 中 6 | `plan-layering.md` のステータス / チェックボックス / 影響範囲表 | **未対応** — `:6` は「**未着手 (着手可)**」のまま、`[x]` 2 件 : `[ ]` **24 件**。`layering-scopes.yml` 新規・`templates/README.md`・`templates/shared/*`・`agents/*` の行も無い | **Freeze と同時に必須** (→ 中 B) |
| 中 7 | `plan.md:23` の `ToolDispatcher` | **解消** — §3.8.2 の強制点 (束縛 = `tool_registry.go` のクロージャ / 検証 = Repository のクエリ条件) へ差し替え済み。`:43` の AC-5.1 行も 6 パッケージ層 / L-1〜L-6 / 19 ステップへ更新 |
| 中 8 | 「depguard 6 規則」 | **半解消** — `architecture.md` §3.5.1 は「**17 規則**」「全 17 規則それぞれについて違反サンプルで確認」+ **必須 2 ケース**に更新され、`.golangci.yml` のコメントにも規則数 17 と対応表がある。**`plan-layering.md:41` / `:95` / `:235` は「depguard 6 規則」「6 規則ぶんの違反サンプル」のまま** | **Freeze と同時に必須** (→ 中 B) |
| 中 9 | A-4 / A-6 の SQL 検査が `Get*` 限定 | **解消** — `auth.md:617` が **`Get*` / `List*` / `Count*` / `Search*`** に拡張 (`list_assets` 系の一覧クエリを覆う) |
| 新規中 1 | D-2⑦ が `ported_domains` を扱えない | **解消** — `ci.yml` の D-2⑦ が**非対称な 3 条件** (① == v3 ∪ ported / ③ == v3 / ported は ③ に現れない) に修正され、対称比較が破綻する理由まで placeholder の出力に書かれている |
| 新規中 2 | `layering-scopes.yml` と §3.5.2 のドリフト / 「機械検査できない」の誤り | **解消** — §3.5.2 の共通層に **`config/**`** を追記 (`:250`。D-2⑦ の対象から除外することも明記)。§8 (`:805`〜) が「**雛形は本リポジトリ内にあるので設計リポ側の照合は可能** (実装は残課題) / 機械化できないのは切り出し後の写しだけ」に訂正 |
| 新規中 3 | `entity/` の副作用禁止が未強制 | **解消** — `L1-entity-no-side-effects` を新設 (`database/sql` / `pgx/v5` / `net/http` / `anthropic-sdk-go` を deny)。`entity/toolresult` が中心になったことを理由として明記 |
| 新規中 4 | `Result.Payload` の marker interface 化 | **解消** — §3.8.5 の規約 2 が `type Payload interface { isToolResultPayload() }` を要求し、§3.8.4 の検査 4 を「**一次担保はコンパイラ / CI は backstop**」に格下げ。§8 の未決事項も「解決」へ。**C-L9 が縛るのは `ToolHandler` のシグネチャだけ**という読み分けも書かれた (BE-12 の担保がスクリプト依存から外れた) |
| 新規軽微 1 | 型アサーションの抜け道 | **解消** — §3.7 (`:353`) に「narrow IF は**事故防止であって封鎖ではない**」と限界を明示し、D-2⑨(c) で検出 |
| 新規軽微 2 | D-2③ の誤検知 / `errresp` の SSOT | **解消** — D-2 の宣言 ③ が「**module 内パッケージへのエイリアスは対象外**」に、§3.9① (`:548`) が「所在は `controller/errresp.go` に固定」に更新 |
| 軽微 1 | `architecture.md:5`〜`:6` のラベル | **解消** — 「F1〜**F15**」「Q-L1〜**Q-L11**」 |
| 軽微 2 | §3.10 ステップ 12 「ハンドラまたは Service から呼ぶ」 | **未対応** (`:680`) | 止めない |
| 軽微 3 | §3.8.3 に「メトリクス送出」の行が無い | **未対応** — `observability.md` §6.1 が時期の SSOT であることは明記済みなので実害は小さい | 止めない |
| 軽微 4 | 行番号参照 `ci.yml:41-42` | **未対応** — 実物の golangci-lint ステップは `ci.yml:46`。`requirements-layering.md:174` / `:342`、`plan-layering.md:41` / `:95` / `:235` | 止めない (→ 中 B と同時) |

## ③ 新規指摘 (今回の修正で生じた / 残った問題)

### 中 A. `gateway/**` だけが sqlc 生成パッケージと DB ドライバを import できる (同一クラスの最後の開口部)

- **事実**: `L3-no-sqlc-outside-repository` の `files` は `usecase/{5}` / `service/**` / `controller/**` /
  `entity/**` の **8 件で、`**/gateway/**` を含まない** (`templates/backend-repo/.golangci.yml:305`〜`:320`)。
  `ci.yml` の D-2⑨ の `targets` も
  `"service usecase/theme usecase/asset usecase/conversation usecase/idea usecase/plan controller entity"` で
  **gateway が入っていない**。`L4-gateway-no-upper-layers` が deny するのは `<module-path>/repository` までで、
  sqlc 生成パッケージ・`database/sql`・`pgx` は対象外
- **問題**: `docs/design/architecture.md:142` (責務表) は gateway の禁止事項に **「DB アクセス」**を挙げ、
  `observability.md:44` (O-C) は **「L-4 により gateway は DB を触れないため、永続化は呼び出し元の UseCase が行う」**を
  明細記録点を usecase に置く**根拠**にしている。gateway が sqlc / DB ドライバを import できる状態では、
  この根拠が機械的には成立しない (repository を経由しない DB アクセスが可能)。
  今回 4 つの非 repository 層 (usecase / service / controller / entity) を塞いだのに gateway だけ残っており、
  判断ではなく見落としに見える
- **修正案 (2 行)**: `.golangci.yml` の `L3-no-sqlc-outside-repository` の `files` に `**/gateway/**` を追加し、
  `ci.yml` の D-2⑨ の `targets` に `gateway` を追加する。
  併せて `L4-gateway-no-upper-layers` の deny に `database/sql` / `github.com/jackc/pgx/v5` を足すと
  §3.3 の「DB アクセス禁止」がそのまま機械強制になる (`L1-entity-no-side-effects` と同じ形)
- **Freeze を止めるか**: 止めない。gateway にはドメインロジックもツールハンドラも無く、
  テナント分離の迂回に直結しないため。ただし**同一 PR で塞ぐのが最も安い**

### 中 B. `plan-layering.md` の 3 点 (ステータス / 「6 規則」 / 行番号) — 1 ファイルの 1 回の編集で閉じる

- **事実**: (a) `:6` のステータスが「未着手 (着手可)」で `[x]` 2 件 : `[ ]` 24 件 (Task-L28 も未チェック)、
  影響範囲表 (§2.1) に `layering-scopes.yml` (新規) / `templates/README.md` / `templates/shared/*` /
  `.claude/agents/*` の行が無い。(b) `:41` / `:95` / `:235` が **「depguard 6 規則」「6 規則ぶんの違反サンプル」**の
  まま (`architecture.md` §3.5.1 は 17 規則 + 必須 2 ケースに更新済み)。(c) 同じ行が `ci.yml:41-42` を指す
  (実物は `:46`)
- **問題**: (b) が最も重い — **`plan-layering.md` §3 は AC-6.14 の検証方法の表**であり、
  ここが「6 規則ぶん」のままだと、**今回 重大 1 と 重大 A の修正として追加した
  `L1-service-no-upper-layers` / `L3-no-sqlc-outside-repository` が違反サンプルの対象から漏れる**。
  設計書側 (SSOT) は正しいので実装リポには正しい指示が渡るが、設計リポ内で数が食い違ったままになる。
  (a) は Design Freeze の宣言と両立しない (計画が未着手を示していると次のセッションが二重着手する)
- **修正案**: 完了タスクを `[x]` に / ステータスを「Wave 1〜6 完了・Task-L24 (レビュー) 完了」に /
  「6 規則」を「17 規則 (+ 必須 2 ケース)」に / `ci.yml:41-42` をステップ名 (`D-2①⑤ golangci-lint`) 参照に /
  §2.1 に 4 行追加。**`requirements-layering.md:174` / `:342` の `ci.yml:41-42` も同時に**
- **Freeze を止めるか**: **Freeze コミットと同時に必須** (計画の状態が Freeze の一部であるため)

### 軽微 A. `architecture.md:34` / `:590` の F11 記述が未訂正 (requirements 側のみ訂正済み)

- **事実**: `requirements-layering.md:54` は「監査ログの破棄は `usecase/` の 14 箇所のみ / `controller/` 3 箇所は
  `io.ReadAll` と SSE `WriteString`」と訂正され AC-6.13 の対象を 14 箇所に限定した。
  `docs/design/architecture.md:34` (F11) は「監査ログ・アクティビティログの書き込みエラーを `_ =` で無言破棄。
  実測 6 ファイル 17 箇所」のまま、`:590` (§3.9③) も「v2 は 6 ファイル 17 箇所で無言破棄していた」のまま
- **問題**: 実装者が読むのは設計書 (SSOT) の方であり、17 箇所すべてが監査ログだと転記される。
  D-2⑧ の grep は `Log|Audit|Activity|Event` を含む行しか見ないため、SSE 書き込みの破棄は検出されない
  (= 設計と検査の対象は 14 箇所側で一致している)
- **修正案**: `:34` の F11 を「エラー破棄 6 ファイル 17 箇所 (**うち監査ログは `usecase/` の 14 箇所**。
  `controller/` の 3 箇所は `io.ReadAll` と SSE 書き込みで O-5 に属する)」に、`:590` を 14 箇所に改める

### 軽微 B. wire 生成コードの配置場所が設計に無い

- **事実**: `architecture.md:196` (L-4) が「具体パッケージを import するのは **DI の組み立て (wire) だけ**」と定め、
  同じ行で「`usecase` / `service` が `gateway/*` を import しない」を depguard で表現しない理由を
  「**wire の生成コードが同じパッケージ配下に置かれるため誤検知**」と説明している。
  一方で**wire 生成物をどこに置くか** (`di/` / `cmd/` / `usecase/<domain>/`) は設計書に書かれていない
- **問題**: `usecase/<v3 新規ドメイン>/` に `wire_gen.go` を置くと、**`L3-no-sqlc-outside-repository` と
  `L5-no-external-sdk` が誤検知する** (wire 生成物は実装パッケージと SDK を import する)。
  逆に `di/` に置けば誤検知は起きないので、**置き場を 1 行決めるだけで L-4 の「depguard で表現しない」判断の
  前提が固まる**
- **修正案**: §3.5.1 か §3.2 に「wire の生成物は `di/` (層に属さない DI 専用パッケージ) に置く。
  depguard の対象外とする」を 1 行追加する

### 軽微 C. `dupl` 発火時の一次対応が書かれていない (gateway 拡大に伴う運用)

- **事実**: `architecture.md:633` 以降が `dupl` の対象に `gateway/**` を含める理由を F14 で説明し、
  `templates/backend-repo/.claude/agents/code-reviewer.md` は
  「`dupl` / `cyclop` / `funlen` の指摘を**除外設定で黙らせた形跡があれば重大指摘**」と定めている
- **問題**: LLM プロバイダごとの gateway 実装は **SDK の型が異なるため共通化できない形の重複**が残り得る
  (F14 が 4 重複したのは共通化しなかったからだが、型が違えば共通化に generics か reflection が要る)。
  **「抽出が型的に不可能な場合にどうするか」が決まっていない**ため、
  実装者は `nolint` を書くしかなく、しかしそれは「黙らせた形跡」として重大指摘になる — 手詰まりになる
- **修正案**: §3.9④ に 1 文 — 「発火時の一次対応は共通ヘルパーへの抽出。型の相違で抽出できない場合のみ
  **理由コメント付きの `nolint` を許可**し、`code-reviewer` は**理由の妥当性**を見る (無記名の `nolint` は重大指摘)」

## ④ Design Freeze の可否 — **可 (重大ゼロ)**

rule 04 の完了条件 (**重大事項ゼロ**) を満たした。前回までの重大 1〜4 と重大 A の 5 件はすべて
「記述の書き換え」ではなく**機構の追加または差し替え**で解消しており、根拠となる v2 / PoC の事実は
本レビューで独立に再測定して一致を確認した。

**Freeze コミットと同時に閉じるべき事務項目 (2 件。いずれも設計判断を含まない)**:

1. **中 B** — `plan-layering.md` のステータス / チェックボックス / 「6 規則 → 17 規則」/ 行番号参照。
   特に「6 規則ぶんの違反サンプル」は**今回追加した 2 規則を検証対象から落とす**ため、
   Freeze 前に 17 規則 + 必須 2 ケースへ揃えること
2. **中 A** — `.golangci.yml` と `ci.yml` に `gateway` を 2 行追加 (同一クラスの最後の開口部)

**後続で処理してよいもの**: 軽微 A (F11 の記述) / 軽微 B (wire の置き場) / 軽微 C (`dupl` 発火時の対応) /
軽微 2 (§3.10 ステップ 12) / 軽微 3 (§3.8.3 のメトリクス行) /
`requirements-layering.md:12`〜`:14` と §9 の見出しが「Q-L1〜Q-L10」のまま (AC-6.22 は追加済みなので実害は小さい)。

**実装リポへ引き渡す時点で残る「機械で見られない残余」** (設計に明記済み。引き渡し時に再確認すること):
①`usecase` / `service` が gateway の具体パッケージを import しないこと (L-4。理由付きで depguard 対象外) —
`code-reviewer.md` の観点 ②`repository/` をフラットに保つ移植分の L-3 ③②⑦ の検査スクリプト本体の実装
④全 17 規則 + 必須 2 ケースの違反サンプルによる depguard の実挙動確認。
**④は「depguard の規則が独立評価される」という本レビューの判定を実測で裏取りする作業**なので、
実装リポの最初の PR に含めること。

## 良かった点 (最終)

1. **指摘の範囲を超えて自ら穴を探している** — 重大 A の対応で `entity/**` を `files` に含めた
   (間接参照の封鎖)、`code-reviewer.md` の観点まで追随、v2 の実測を**用途 (enum / モデル型 / params 構造体) まで
   分解して 4 例の出典を付けた**。指摘に対する最小対応ではなく、同じクラスの穴を潰す形になっている
2. **「機械で見られないもの」を隠さず分類した** — L-4 を depguard で表現しない理由 (wire の誤検知) と
   その残余の行き先 (`code-reviewer.md`)、narrow IF の限界 (事故防止であって封鎖ではない)、
   D-2⑨ を backstop と位置づけたこと。**担保の強さを 3 段 (型 / depguard / 検査) で書き分ける様式**が
   §3.5.1 の L-6 行と §3.8.4 の検査 4 で一貫している
3. **`observability.md` §6.1 の ⑧ の入れ方が正確** — ⑧ を「3 段の一部ではなく、
   失敗系メトリクスがどの段にも属さないことを明示する行」と位置づけ、**Q-L10=B の 3 段の線引きを変えずに**
   矛盾を解消した。さらに **AL-1〜AL-7 に実施時期を割り当て、⑦ に属するのは AL-4 のみ**と結論まで出しており、
   「アラート基盤を第 2 増分にはできない」という運用上の帰結が読み取れる
4. **誤読の帰結を明記する書き方** — 「メトリクス基盤ごと第 2 増分と読むと O-4 / O-6 / A-6 が
   初回リリースで欠落する」「v2 でクエリ実行まで漏れていないのは規約ではなく偶然」など、
   **読み手が判断を誤ったときに何が起きるか**を書いている。設計書を実装リポへ渡す形式として適切
5. **marker interface の採用判断** — 「C-L9 が縛るのは `ToolHandler` のシグネチャだけで、
   エンベロープ内部の `Payload` は対象外」という読み分けを明示したうえで採用し、
   BE-12 の担保を**未実装スクリプト依存からコンパイラ担保へ移した**。
   §8 の未決事項を「解決」に落とすところまで処理されている
