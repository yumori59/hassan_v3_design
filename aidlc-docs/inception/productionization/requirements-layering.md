# Requirements (増分: layering): 層構成の再定義と層間規約

> 親要件: [requirements.md](requirements.md) (AC-1.1〜AC-5.2 は有効。本書は **AC-6.1〜AC-6.23 を追加**し、
> **AC-5.1 の定義内容を更新**、**AC-2.1 / AC-2.2 の実施時期を先送りとして明記**する — §7)。
> 質問: [questions-layering.md](questions-layering.md) /
> 計画: [plan-layering.md](plan-layering.md)
> 改訂対象: [architecture.md](../../../docs/design/architecture.md) (§2 の D-A / D-A' / D-B''、§3 全体、§5 の O-2 / O-3 / O-4 / O-6 / D-2) と
> [observability.md](../../../docs/design/observability.md) (O-C / O-D / O-H / §3 の図 / §5 の O-2 行 / §6 / §7)
> 一次要求: [design_memo.md](../../../docs/design/design_memo.md):28-29 / :94-96 / :107 / :109 / :145
> 本番観点の ID 一覧: [08-production-gates.md](../../../.claude/rules/08-production-gates.md)
>
> ステータス: **確定 (C-L1〜C-L12 はユーザー決定 2026-07-29)**。
> [questions-layering.md](questions-layering.md) の **Q-L1〜Q-L10 (規約の粒度・範囲・値) も 2026-07-29 に
> 全て回答済み**。決定内容は §9 の表と本書の各 AC に反映済みで、**暫定既定は残っていない**。

## 1. 目的とスコープ

[architecture.md](../../../docs/design/architecture.md) は 4 層 (Controller → UseCase → Service → Repository) の
責務境界を定義済みだが、**Service の定義 (「再利用される処理単位」) と外部 API の置き場 (Service) を
変更する決定**が出た。本増分はその決定を **実装リポで機械強制できる規約**へ落とし込み、
architecture.md を改訂するための要件を定める。

**スコープ内**:

- 層の定義と依存規則 (C-L1〜C-L11、L-1〜L-6)
- 層をまたぐ横断規約 3 点 (エラー型の契約 / 設定値の SSOT / 監査ログ失敗時の挙動 — C-L12)
- 上記を CI で機械強制する要件 (C-L8) と、実装リポ雛形 (`templates/app-monorepo/backend`) への反映
- 決定の変更によって**参照が古くなる他の設計書**の追随 (影響範囲は [plan-layering.md](plan-layering.md) §2)

**スコープ外** (本増分では扱わない):

- データモデル (親 [questions.md](questions.md) Q-1) / フラグ方式 (同 Q-8) — 未解決のまま据え置く
- [API/](../../../docs/design/API/) のエンドポイント設計の内容 (層の名称の追随のみ行う)
- v2 から移植するコードの実際の書き換え (適用範囲の決定のみ行う — Q-L3)
- 製品コードの実装 (本リポジトリに製品コードは置かない)

## 2. 前提事実 (実測。出典付き)

> すべてメインセッションで実測済み。**推測は含まない**。DR-1 (出典なしの断定) を避けるため、
> 以降の要件は本表の ID を参照する。

| ID | 事実 | 出典 |
|---|---|---|
| F1 | v2 の**層違反はゼロ** — `usecase/` 配下の `gin.Context` 依存 0 件、`controller/` 配下の repository 直接参照 0 件 | `hassan-v2-backend/docs/refactoring-plan.md:546` |
| F2 | v2 の **usecase 相互 import も 0 件** (UseCase を跨がない設計は既に守られている) | 実測 `grep -rho "hassan-v2-backend/usecase/" usecase/ --include='*.go' \| wc -l` = 0 |
| F3 | 一方で UseCase にロジックが溜まり重複した — `hassan-v2-backend/usecase/idea/web_search.go` **1381 行** (うち `EnsureValuesFromCitedURL` 150 行が重複)、`hassan-v2-backend/usecase/business_plan/detailed/brush_up_business_plan_detailed.go` **919 行** (6 関数が「プロンプト構築 → LLM → JSON 抽出 → パース → OGP 付与 → 保存」をほぼ同一骨格で重複) | 実測 `wc -l` + `hassan-v2-backend/docs/refactoring-plan.md:66-67` |
| F4 | 非テストコードの `fmt.Errorf` 約 **113 件** (prompt 49 / dify 29 / azuredi 12 / aws 6 / hassanresend 4 / auth 3 ほか)、`errors.New` 7 件。**規約は全面禁止** (`hassan-v2-backend/CLAUDE.md:43`) | `hassan-v2-backend/docs/refactoring-plan.md:62` |
| F5 | Controller の `err.(*constants.CodedError)` 直接型アサーションが **8 ファイル 61 箇所**のコピペ。判定方法も `errors.As` と直接アサーションで不統一 (直接アサーションはラップされた `CodedError` を取りこぼす) | `hassan-v2-backend/docs/refactoring-plan.md:545` / `:384` |
| F6 | v2 は**外部サービス (`llm/`,`dify/`,`prompt/`,`ogp/`,`microcms/`) 側で IF を定義し、UseCase が型エイリアスで直接使用**、「アダプター層は作らない」。実測: `usecase/` 配下の型エイリアス **20 箇所** (例: `hassan-v2-backend/usecase/business_plan/interfaces.go:27` の `type LLMService = llm.Service`) | `hassan-v2-backend/CLAUDE.md:34` + 実測 `grep -rnE "^type [A-Za-z]+ = (llm\|dify\|prompt\|ogp\|microcms)\." usecase/ --include='*.go' \| wc -l` = 20 |
| F7 | 一方で **Repository の IF は UseCase 層で定義**している (= repository については DIP が成立している) | `hassan-v2-backend/CLAUDE.md:33` |
| F8 | v2 は **`service/` 追加レイヤーを明示的に禁止**している (「禁止: `helper/` フォルダ、`utils.go`、過度な抽象化 (`internal/`/`service/` 追加レイヤー)」) | `hassan-v2-backend/CLAUDE.md:39` |
| F9 | v2 に **golangci-lint 設定は無く**、CI は `go test -v -race -coverprofile ./...` のみ (`hassan-v2-backend/.github/workflows/test.yml`)、`go build` / `go vet` は pre-commit のみ = **層規約の機械強制が無い** | `hassan-v2-backend/docs/refactoring-plan.md:57-58` + 実測 (リポジトリ直下に `.golangci*` が存在しない) |
| F10 | v2 の LLM 抽象は **メソッド 11 本すべてが `ctx` を取らず**、用途別に `IdeaService` / `ResearchService` が継承で膨らんでいる | `hassan-v2-backend/llm/interface.go` (既に [architecture.md](../../../docs/design/architecture.md) D-B'' に記載) |
| F11 | 監査ログ・アクティビティログの書き込みエラーを `_ =` で無言破棄。実測の内訳: **`usecase/` 4 ファイル 14 箇所** (`hassan-v2-backend/usecase/idea_board/activity_log.go:25,32` / `hassan-v2-backend/usecase/mfa/verify_totp.go:58,81,85` / `hassan-v2-backend/usecase/idea/generate_idea.go:96,109,115,128,133,490,497` / `hassan-v2-backend/usecase/business_plan/generation_job_manager.go:328,355`) + **`controller/` 2 ファイル 3 箇所** = 計 **6 ファイル 17 箇所**。**ただし「監査ログの破棄」は `usecase/` の 14 箇所のみ** — `controller/` 側の 3 箇所は `controller/middleware.go:29` の `io.ReadAll` と `controller/business_plan.go:155,174` の SSE `WriteString` で**監査ログではない** (前者は本文読み取り失敗、後者はクライアント切断で正常系でも起きる。`refactoring-plan.md:143` はこの 3 箇所を `Warnw` 扱いとして `Errorw` の監査ログと区別している)。**AC-6.13 の対象は前者 14 箇所**であり、SSE 書き込み失敗の扱いは O-5 (本増分の対象外) に属する | `hassan-v2-backend/docs/refactoring-plan.md:123-129` の列挙を計数 + `:143` のログレベル区分 |
| F12 | タイムアウト (`5*time.Minute` / `7*time.Minute` / `60*time.Second`)・リトライ間隔・サービスドメイン URL の直書きが散在 | `hassan-v2-backend/docs/refactoring-plan.md:64` |
| F13 | v2 の `entity/` パッケージはテストを持つ既存パッケージである (テストありパッケージ 16 のうちの 1 つ) | `hassan-v2-backend/docs/refactoring-plan.md:55` |
| F14 | LLM プロバイダ 4 種 (openai / gemini / claude / perplexity) で HTTP/JSON 送受信処理が重複している | `hassan-v2-backend/docs/refactoring-plan.md:68` |
| F15 | v2 の `usecase/` 配下の**非テスト関数 573 個**の長さ分布: 80 行以上 **40 個 (7.0%)** / 100 行以上 28 / 150 行以上 **21 個 (3.7%)** / 200 行以上 14 / 300 行以上 3。最長は `hassan-v2-backend/usecase/research_sheet/handle_create_sheet.go` の `HandleCreateSheetUseCase.Execute` (385 行) と `hassan-v2-backend/usecase/business_plan/detailed/web_research.go` の `BusinessPlanWebResearchUseCase.Execute` (356 行) で、いずれも**分岐ではなく順次呼び出しの手続き** | 実測 2026-07-29 (再現 2026-07-30): `find usecase -name '*.go' ! -name '*_test.go' \| xargs awk '/^func /{start=NR} /^}$/{if(start){print NR-start+1; start=0}}' \| sort -rn` の件数集計 |

**F1 + F2 + F3 の含意 (本増分の出発点)**: v2 は**層の規約は守られたのに、層の中身が肥大した**。
したがって本増分の要件は「新しい層を足す」だけでは足りず、**「肥大の逃げ場をどこに用意し、
どこを機械強制するか」までを含めて初めて完成する** (§5 / AC-6.15)。

## 3. 確定制約 (C-L1〜C-L12。ユーザー決定 2026-07-29)

| ID | 決定 | architecture.md 現行記述との関係 | 却下案と理由 (設計書に明記すること) |
|---|---|---|---|
| C-L1 | **Service から他ドメインの Service を呼ぶことを禁止する**。Service は「部品」であり、繋ぐのは UseCase の責務 | §3「層配置の判断基準」の「**Service から Service を呼んでよい**」を**差し替える** | (a) Service 間呼び出しを許す (現行): 呼び出しの連鎖が UseCase を経由せず伸び、トランザクション境界と所有者スコープの通り道が追えなくなる |
| C-L2 | **Service が扱えるデータは自ドメインのみ**。他ドメインのデータは UseCase が取得して引数で渡す。**2026-07-30 訂正**: 当初「Service → Repository は可能。ただし自ドメインの Repository のみ」と表現したが、**IF は利用側で定義する (C-L4) ため Service は repository パッケージを import しない** — v2 も同じモデルで動いている (実測: `usecase` → `repository` の import 0 件)。したがって制約の対象は「import」ではなく「**扱えるデータ**」であり、担保は L-3 の 3 段になる | §3 の「Repository を Service から呼んでよい」を**制限付き**に変更 | (a) 無制限に許す: C-L1 が Repository 経由で実質無意味になる (他ドメインのロジックを呼ぶ代わりにテーブルを直接読む形になる) |
| C-L3 | **Service = 1 ドメイン (集約) に閉じたビジネスロジック**。ドメイン名でパッケージを切る | §2 の D-A' と §3 の「Service = **再利用される処理単位**」「再利用されているかを配置基準にしない」を**差し替える**。[design_memo.md](../../../docs/design/design_memo.md):95 の「入口非依存のビジネスロジック」という原意は維持 | (a) 「再利用される処理単位」(現行): 再利用は結果であって設計基準にならず、**ドメインを跨ぐ Service** が生まれて C-L1 と両立しない。(b) Service を薄い委譲層にする: 層が増えるだけで責務が生まれない |
| C-L4 | **外部 API 呼び出しは Service ではなく `gateway/` 層 (Repository と同格の adapter 層) に置く**。**インターフェースは利用側 (usecase / service) が定義し、gateway は実装のみ**を持つ | §3「層配置の判断基準」の「外部サービス (LLM / 検索 / ストレージ) を呼ぶか → **Service**」を「→ **gateway**」に変更 | (a) v2 方式 = 外部パッケージ側で IF を定義し UseCase が型エイリアスで使う (F6。20 箇所): 利用側が外部パッケージの型に直接依存するため、差し替え時に UseCase の公開 IF が壊れ、テストのモック境界も外部パッケージが決めることになる。**F7 との対比が説明の要** — v2 が Repository で既に成立させている DIP を gateway にも適用するだけであり、新方式の発明ではない |
| C-L5 | **`domain/` パッケージを新設せず、v2 の `entity/` を拡張する** (副作用のない計算・変換・バリデーションの置き場) | §3 の責務表に **entity の行が存在しない** (entity は Repository の責務「SQL 実行・entity 変換」にしか登場しない) → **層として追加する** | (a) `domain/` を新設: Go では `domain` が曖昧な名前として避けられる。(b) 置き場を作らず Service に置く: 副作用のない計算が Repository / gateway を持つ Service に混ざり、テストが DB/外部 API のモックを要求し始める |
| C-L6 | **インターフェースは小さく (1〜3 メソッド)、利用側が必要な分だけ定義する**。gateway ごとの巨大 IF 1 本を作らない。**実装 1 : IF N** を正常とする | 新規。D-B'' の「共通エンベロープ」(戻り型の共通化) とは**両立する** (エンベロープは戻り型の統一、本項は IF の分割) | (a) gateway ごとに 1 本の大きな IF: F10 (11 メソッド・`ctx` なし・用途別サブ IF が継承で膨らむ) の再現。利用側は使わないメソッドまでモックする必要が出る |
| C-L7 | **型名は `XxxService` を避け、振る舞いで命名する** (例: `asset.Extractor` / `conversation.Runner` / `plan.Composer`)。**ディレクトリ名は `service/` のままでよい** | 新規 (現行は `AgentRunner` / `ToolDispatcher` という名前を使用) | (a) `XxxService` を許す: 名前が責務を語らないため「とりあえず Service」の受け皿になり、C-L3 の「1 ドメインに閉じる」が崩れる |
| C-L8 | **層間の依存規則を CI で機械強制する** (depguard 等)。layer-first パッケージングを選ぶ代償として必須 | §5 の D-2 (CI ゲート) に**追加**する | (a) レビューで守る: F9 (v2 に lint 設定なし) の状態で F4 の 113 件が溜まった。人手のレビューは規約違反の検出手段として実績がない |
| C-L9 | **Agent の custom tool は UseCase が handler を関数注入する形にする**。`RunTurn(ctx, tx, scope, tools map[string]func(ctx, args) (any, error), input)` のように**型依存を持たない関数の集合**で渡し、Runner は触るドメインを知らない | §3「Agent サービスの内部」(ToolDispatcher が Service 内で Repository を直接叩く図) と [design_memo.md](../../../docs/design/design_memo.md):96「agent の tools → service」を**変更する** | (a) 現行の ToolDispatcher 方式: ツールは他ドメイン (asset / plan) のデータを触るため **C-L1 / C-L2 に違反する**。(b) Agent 層から UseCase を呼ぶ: パッケージ循環になる。関数注入なら**循環なし・層飛ばしなし**で解決する (既存レビュー [review-architecture-observability.md](../../reviews/productionization/review-architecture-observability.md) 重大 1 の「outbound port 方式」の系譜) |
| C-L10 | architecture.md に **「本設計は Clean Architecture + DDD のハイブリッドである」ことと 2 つの意図的逸脱を明記する**。逸脱 (1) `service/` は CA の 4 層に存在しない (DDD の Domain Service に相当)、逸脱 (2) Service が Repository / gateway を呼ぶため副作用を持つ (CA 厳密には Entities 層は純粋で、副作用は Use Cases 層が持つ) | 新規 | (a) 明記しない: 実装者が CA の教科書と照らして混乱し、レビューが「教科書との差」の議論に費やされる (DR-5)。**v2 が `service/` 追加レイヤーを明示的に禁止している (F8) こととの関係も同じ理由で明記が必要** |
| C-L11 | architecture.md の**構成図を依存方向が読み取れる形に差し替える**。現行は Controller → UseCase → Service → Repository の直列で描かれ「UseCase が Repository に依存する」と誤読される。CA では Repository / gateway は UseCase が定義した IF の実装であり**矢印は内向き** | §3 の構成図を**差し替える** | (a) 直列図のまま (現行): F7 (Repository IF は UseCase 層で定義) という v2 の既存事実すら図と食い違う |
| C-L12 | 横断規約を追加する: ① **層境界で返すエラー型の契約** (F4 / F5 の再発防止) ② **設定値の SSOT** (`config` パッケージ。タイムアウト・モデル・**O-3 の安全弁しきい値**を含む。F12 / BE-2) ③ **監査ログ書き込み失敗時の挙動** (F11 / O-6 への回答) | architecture.md にエラー規約・設定値の置き場の記述が**一切ない**。§5 の O-6 は「**未回答**」 | (a) 実装リポの CLAUDE.md にだけ書く: 設計判断 (どの層がどの型を返すか) が設計書に無いと、実装リポごとに解釈が分かれる |

## 4. 依存規則 (L-1〜L-6)

**採用するパッケージング**: layer-first (`controller/` `usecase/` `service/<domain>/` `repository/` `gateway/<provider>/` `entity/`)。
domain-first (`<domain>/{controller,usecase,...}`) を却下する理由は「v2 の既存構造と揃うこと (F1: 層違反ゼロ = 既存構造が機能している)」
— この却下理由も設計書に書く。

| ID | 規則 | 由来 | CI 強制の形 (depguard 等) |
|---|---|---|---|
| L-1 | 依存方向は `controller` → `usecase` → {`service`, `repository`, `gateway`} → `entity`。**逆流禁止** | C-L10 / v2 の「禁止依存」(F1 の対象) | 各層パッケージの deny list |
| L-2 | **`service/A` → `service/B` の import 禁止** | C-L1 | `service/*` から `service/*` を deny |
| L-3 | **`service/<domain>` が扱えるデータは自ドメインのみ** (他ドメインのデータは UseCase が引数で渡す)。**read-only の横断参照も例外にしない** | C-L2 / **Q-L5=A** (例外なし) | **depguard では表現できない** (**2026-07-30 訂正**) — L-4 の機械強制により `service/**` は `repository` を一切 import しなくなるため、L-3 は import グラフに現れない。**担保は 3 段**: ①Service が宣言する repository IF のメソッドが自ドメインのものだけか (レビュー) ②**`di/` の配線レビュー** ③A-4 の所有者スコープ CI 検査。**`repository/<domain>/` への分割 (Q-L8=B) は担保 ② を成立させるため** (フラットだと配線から所有関係が読めない) |
| L-4 | `service` / `usecase` → `gateway` は可。**`gateway` → `service` / `usecase` / `repository` は禁止** | C-L4 | `gateway/*` から上位層を deny |
| L-5 | **外部パッケージ (SDK・gateway 実装) の型を `usecase` の公開 IF に露出させない** (F6 の型エイリアス方式の禁止) | C-L4 | `usecase/*` から SDK パッケージを deny (IF は利用側で定義するため SDK を import する必要がない) |
| L-6 | **`tx` は UseCase が張り、引数で渡す**。`Begin` / `Commit` / `Rollback` を呼べる型を Service に渡さない | 現行 [architecture.md](../../../docs/design/architecture.md) §3「トランザクションの受け渡し機構」(D-A'') を**維持** | 型で担保 (Service は `tx` インターフェースのみ受け取る) + `service/*` から `Begin` を持つ型を deny |

## 5. UseCase 肥大化への備え (F3 の再発防止)

「跨ぎは UseCase」に寄せると UseCase が太る (F3 の 1381 行 / 919 行がその実例)。
**抜け道を設計時点で固定する**:

| 溢れたものの性質 | 置き場 |
|---|---|
| 副作用のない計算・変換・バリデーション | **`entity/`** (C-L5) |
| 外部 API 呼び出し | **`gateway/<provider>/`** (C-L4) |
| 1 ドメインに閉じた業務ロジック | **`service/<domain>/`** (C-L3) |
| 手続きの断片 (複数ドメインを跨ぐ協調の一部) | **`usecase/<domain>/` 内のファイル分割** (v2 の「複数で使うヘルパーは機能名ファイルへ分離」= `hassan-v2-backend/CLAUDE.md:38` を踏襲) |
| プロンプトのテンプレート文字列 | **`prompts/<domain>/` (テンプレートファイル) + `service/<domain>/` (構築ロジック)** (Q-L9=C) |

**禁止**: 「共通 Service」の新設 (ドメインに属さない Service は C-L3 違反であり、C-L1 の抜け道になる)。

**加えて lint で締める対象は「行数」ではなく「重複」を主役にする** (Q-L4=E。値と根拠は AC-6.15):
`dupl` (しきい値 150 トークン) を主役に、`cyclop` (複雑度 15) と `funlen` (150 行 / 80 ステートメント) を補助に置く。
**ファイル行数は制限しない** — 別ファイルへ移すだけで回避でき、抑止力にならない。

## 6. 受入基準 (AC-6.1〜AC-6.23)

> すべて **[architecture.md](../../../docs/design/architecture.md) の記述に対する受入基準**
> (実装コードではない)。各 AC の検証方法は [plan-layering.md](plan-layering.md) §3 が定める。
> 「適切に」「必要に応じて」等の曖昧語を使わず、**記述の有無・一致・不在**で判定できる形にしてある。

### 6.1 層の定義

- **AC-6.1** architecture.md に「本設計は **Clean Architecture + DDD のハイブリッド**である」ことと、
  **2 つの意図的逸脱**が理由付きで明記されていること: (1) `service/` は CA の 4 層に存在せず
  DDD の Domain Service に相当する (2) Service は Repository / gateway を呼ぶため副作用を持つ。
  併せて **v2 が `service/` 追加レイヤーを禁止している事実 (F8) と、v3 で追加する理由**が書かれていること (C-L10)
- **AC-6.2** Service の定義が「**1 ドメイン (集約) に閉じたビジネスロジック**」であり、
  パッケージをドメイン名で切ること・型名は振る舞いで命名し `XxxService` を使わないこと
  (例示 3 つ以上) が書かれていること。**旧定義「再利用される処理単位」および
  「再利用されているかを配置基準にしない」の記述が残っていないこと** (grep で不在を確認可能) (C-L3 / C-L7)
- **AC-6.5** 責務表に **entity の行**が追加され、責務が「副作用のない計算・変換・バリデーション」、
  禁止事項が「SQL 実行・外部 API 呼び出し・他層への依存」と定義されていること。
  **`domain/` パッケージを新設しない理由**が書かれ、**層配置の判断基準の最終行が
  「SQL を実行するか → No かつ副作用なし → entity」に更新されている**こと (C-L5)。
  加えて **プロンプトの置き場**が次のとおり書かれていること (Q-L9=C で確定):
  1. **テンプレートファイルは `prompts/<domain>/` に集約**し、**テンプレートを組み立てる構築ロジックは
     `service/<domain>/`** に置く (entity にも、独立した `prompt/` パッケージにも置かない)
  2. この配置により **D-6 の 3 者一致検査 (schema ↔ handler ↔ prompt) と
     [architecture.md](../../../docs/design/architecture.md):29 の D-E (Agent 発行を CI/デプロイ手順に組み込む) が
     走査するパスが `prompts/<domain>/` に確定する**ことが明記されている (AC-6.9 と対応)
  3. 却下案として **v2 の独立 `prompt/` パッケージ方式** (外部サービスとして IF を自分側で定義 =
     `hassan-v2-backend/CLAUDE.md:34`。F4 の `fmt.Errorf` 113 件のうち 49 件を抱える最大の巣) が
     出典付きで記載されている
- **AC-6.4** **`gateway/` 層**が Repository と同格の adapter 層として責務表に追加され、
  「**IF は利用側 (usecase / service) が定義し、gateway は実装のみを持つ**」と明記されていること。
  却下案として **v2 の「外部パッケージ側で IF 定義 + 型エイリアス」方式 (F6。20 箇所)** が
  出典付きで記載され、**F7 (v2 は Repository では既に利用側定義) との対比**が書かれていること (C-L4 / L-4 / L-5)
- **AC-6.6** インターフェース粒度の規約 (**1〜3 メソッド / 利用側が必要な分だけ定義 / 実装 1 : IF N を正常とする**) が
  明記され、**F10 (`hassan-v2-backend/llm/interface.go` の 11 メソッド・`ctx` なし)** が却下例として
  出典付きで参照されていること。**D-B'' の共通エンベロープ (戻り型の統一) と両立する**ことが
  1 文以上で説明されていること (C-L6)

### 6.2 依存規則

- **AC-6.3** 「**Service から他ドメインの Service を呼ぶことを禁止**」「**`service/<domain>` が扱えるデータは
  自ドメインのみ**」「他ドメインのデータは **UseCase が取得して引数で渡す**」が明記され、
  **現行の「Service から Service を呼んでよい」の記述が残っていないこと** (grep で不在を確認可能) (C-L1 / C-L2 / L-2 / L-3)。
  加えて次の 3 点が書かれていること:
  1. **read-only の横断参照も例外にしない** (Q-L5=A)。例外を設けない理由 =
     ①C-L1 が Repository 経由で実質無効化される ②depguard は「read-only かどうか」を静的に判定できない
  2. **L-3 の担保が 3 段で書かれていること** (**2026-07-30 訂正**)。L-4 を機械強制した結果、
     `service/**` は `repository` パッケージを一切 import しなくなる (IF は利用側で定義するため。§3.6) ので、
     **「自ドメインのみ」は import グラフに現れず depguard では検査できない**:
     ①**Service が宣言する repository IF のメソッドが自ドメインのものだけであること** (レビュー観点。
     IF は 1〜3 メソッドなので目視可能) ②**`di/` の配線レビュー** (どのドメインの実装をどの Service に渡しているか)
     ③**A-4 の所有者スコープ CI 検査** (越境した場合の実害を捕まえる最終防壁)。
     **「depguard で L-3 を検査する」と書いてはいけない**
  3. **`repository/` をドメイン別パッケージ (`repository/<domain>/`) に分割する**こと (Q-L8=B)。
     **根拠は「`di/` の配線から所有関係が一目で読めるようにするため」** (担保 ②。**2026-07-30 に差し替え** —
     旧根拠「L-3 を depguard で検査する前提」は上記 2 により成立しない)。
     **分割対象は v3 新規ドメインのみ**で、移植分は v2 と同じフラット構成
     (`hassan-v2-backend/repository/` は 31 ファイルが同一パッケージ) を維持する。
     却下案として ①全面分割 (移植コードの import パス書き換えが移植の前提条件になる)
     ②フラット維持 (`repository.NewRepository()` 1 個が全ドメインを持つため配線から所有関係が読めず担保 ② が成立しない) を記載する
- **AC-6.23** **`di/` が層として責務表に定義されていること** (**2026-07-30 追加**。L-4 の機械強制の前提)。
  次の 3 点を満たすこと:
  1. **責務 = 「全層の具体パッケージを import して依存グラフを組み立てる唯一の場所」**。
     v2 の構成 (`hassan-v2-backend/di/provider.go` + `wire.go` + `wire_gen.go`) を踏襲する
  2. **禁止事項 = ビジネスロジック / 条件分岐による実装の切り替え** (環境差は `config` の設定値で行い配線を分岐させない
     — 分岐すると本番でどの実装が動いているかコードから読めない) / **`wire_gen.go` の手編集**
     (出典: `hassan-v2-backend/di/wire_gen.go:1` の `// Code generated by Wire. DO NOT EDIT.`)
  3. **`di/**` がどの depguard 規則の `files` にも含まれないこと**が設計書と `.golangci.yml` の両方に書かれている。
     これにより **L-4 / L-5 を「wire の誤検知」なしで機械強制できる**。
     v2 の実測を根拠として引くこと: **`usecase` → `repository` の import は 0 件 / `controller` → `repository` も 0 件**、
     具体パッケージを import するのは `di/wire.go` だけ (自リポジトリ import 29 件)
- **AC-6.10** 構成図が**依存方向 (矢印の向き)** を表現し、**Repository / gateway が UseCase の定義した IF の
  実装であること (矢印が内向き)** が図から読み取れること。
  現行の「Controller → UseCase → Service → Repository の直列図」が置き換えられていること (C-L11)
- **AC-6.14** L-1〜L-6 が **CI で機械強制される**ことが D-2 に追記され、次を満たすこと (C-L8 / D-2。Q-L3=A で範囲確定):
  1. 使用するツール (depguard 等) と**規則ごとの設定方針**が L-1〜L-6 の各 ID に対応づけて書かれている
  2. **違反した PR がマージできない**ことが明記されている
  3. `templates/app-monorepo/backend` に **lint 設定ファイル (`.golangci.yml`) が配置され**、
     CI (`templates/app-monorepo/.github/workflows/ci.yml` の「D-2①⑤ golangci-lint」ステップ) から使われる状態になっている
     (現状は `templates/app-monorepo/backend/` に `.golangci*` が存在せず既定ルールのみ = 層規約は検査されない)
  4. **機械強制の対象は v3 新規ドメインのパスのみ**であり (Q-L3=A)、除外パス (v2 移植分) は
     AC-6.19 の一覧と一致していること。**L-3 の検査は `repository/<domain>/` の分割 (AC-6.3) が
     成立しているパスでのみ有効**であることが書かれていること
- **AC-6.19** **2 つの層規約の併存範囲**が明記されていること: v3 新規ドメイン (4 層 + entity + gateway) と
  v2 移植分 (3 層) のどちらを適用するかが**パッケージパスの一覧**で示され、
  **CI 強制の対象パスと除外パス**が対応づけられていること ([design_memo.md](../../../docs/design/design_memo.md):94 との整合。Q-L3=A で確定)。
  加えて **AC-6.3 の repository 分割範囲 (Q-L8=B) と本一覧の適用範囲が同一である**ことが明記されていること —
  依存規則の適用範囲と repository のパッケージ分割範囲がずれると、L-3 の検査対象に
  「分割されていない = 検査不能なパス」が混入する

### 6.3 Agent / ツール実行 (A-6)

- **AC-6.7** Agent の custom tool 実行が「**UseCase が handler を関数注入する**」形で定義され、
  ① Runner のシグネチャ (注入される関数の型を含む) ② **Runner が触るドメインのパッケージを import しない**こと
  ③ パッケージ循環が発生しないこと が図または表で示されていること。
  **現行の「ToolDispatcher が Service 内で Repository を直接叩く」図が置き換えられている**こと (C-L9)。
  **ハンドラの型は `func(ctx, tx, args) (any, error)` とし、`tx` を引数で明示する** (Q-L7=B) —
  これが §3 のトランザクション受け渡し原則 (D-A'': `tx` をシグネチャで受け取る = トランザクション内で
  動くことが型に現れる) と同じ根拠であることと、**`*sql.Tx` はドメイン型ではないため
  C-L9 の「Runner が型依存を持たない」が保たれる**ことが書かれていること。
  却下案としてクロージャに `tx` を隠す案 (どのハンドラが書き込みトランザクション内で動くかがコードから
  読めず、BE-10 の台帳 write-through 欠落・BE-11 の採番サイレント失敗を型で防げない) を記載する
- **AC-6.8** 新構造における **A-6 の強制点**が明記されていること: 所有者スコープを
  **どこで束縛し、どこで検証するか**が 1 箇所に特定され、「LLM が渡した ID の所有者不一致は
  『該当なし』として扱い、エラー内容から他テナントのリソース存在を推測させない」という
  既存の要求 (AC-1.3) が維持されていること (C-L9 / A-6)。
  **所有者スコープは `tx` と異なりハンドラ引数にせず、UseCase が生成するクロージャに束縛する** (Q-L7=B) —
  引数にすると Runner (= LLM 出力を扱う層) がスコープを組み替えられる余地が生まれ、
  **A-6 の強制が「Runner の実装が正しいこと」に依存する**ことが理由として書かれていること
- **AC-6.9** tool 名が**文字列キー**になることで生じる **schema ↔ handler の対応漏れ**が、
  **起動時チェックまたは CI 検査で検出される**ことが書かれていること
  (検査の対象: schema に存在する tool 名に handler が無い / handler があるのに schema に無い /
  引数名の不一致)。BE-8 / D-6 の 3 者一致 (schema ↔ handler ↔ prompt) との関係が示されていること

### 6.4 横断規約 (C-L12)

- **AC-6.11** **層境界で返すエラー型の契約**が表で定義されていること (C-L12 ① / F4 / F5):
  1. 各境界 (gateway → 上位 / Service → UseCase / UseCase → Controller) で**返す型**が指定されている
  2. **Controller での HTTP ステータス変換が単一箇所に集約**され、`errors.As` を使うことが明記されている
     (F5 の「8 ファイル 61 箇所のコピペ + 直接型アサーションでラップを取りこぼす」の再発防止)
  3. **`fmt.Errorf` の許容範囲が「層境界のみ `CodedError` 必須」として明記**されていること (Q-L1=B):
     **層境界を越える公開関数の戻り値は `CodedError`**、**パッケージ内部での文脈追加は
     `fmt.Errorf("...: %w", err)` を許可**し、境界で `CodedError` に包み直す。
     v2 の全面禁止方式 (`hassan-v2-backend/CLAUDE.md:43`) を却下案として、
     **3 年運用しても非テストコードに 113 件の違反が溜まった事実 (F4)** を出典付きで記載する
  4. **CI 検査の対象範囲が「層境界の関数の戻り値」に限定される**ことが明記されていること —
     パッケージ内部の `fmt.Errorf` は検査しない (誤検知を減らし、検査対象を明示できる)。
     検査対象となる境界の一覧 (gateway → 上位 / Service → UseCase / UseCase → Controller) が
     AC-6.11-1 の表と一致していること
- **AC-6.17** **LLM 起因の失敗が上位層で区別できる**ことがエラー契約に含まれていること (O-4 / BE-6 / BE-8):
  `stop_reason == max_tokens` による切り詰め / JSON パース失敗 / タイムアウト / ツール引数の不整合が
  **型または判別可能なコードで区別**され、**握り潰されず**上位へ伝わることが書かれていること。
  これらは **`gateway/anthropic` から上位への層境界を越える**ため (Q-L6=A)、
  **Q-L1=B の「境界では `CodedError`」が適用される**ことと、
  **区別のためのコード (または判別用の型) が gateway の戻り型に載る**ことが書かれていること
  (`stop_reason` を公開型に持たない v2 の LLM 抽象では原理的に不可能だった —
  [v2-llm-inventory.md](../../../docs/analysis/v2-llm-inventory.md))
- **AC-6.12** **設定値の SSOT** が定義されていること (C-L12 ② / F12 / BE-2):
  1. 置き場 (`config` パッケージ) が明記され、**そこに置く値の種類が列挙**されている
     (少なくとも: タイムアウト・リトライ間隔・使用モデル・**O-3 の安全弁しきい値** (ツール呼び出し回数 /
     トークン / 実行時間)・生成数の既定値と上限)
  2. **同じ値を Go / FE / prompt の 3 箇所に持たない**ことが明記されている (BE-2 の再発防止)
  3. 環境ごとに変わる値 (D-1) と変わらない値の区別が書かれている
- **AC-6.13** **監査ログ書き込み失敗時の挙動**が定義され、`_ =` による無言破棄を禁止する規約が
  書かれていること (C-L12 ③ / F11 の 6 ファイル 17 箇所)。
  [architecture.md](../../../docs/design/architecture.md) §5 の **O-6 が「未回答」から「回答」に更新**され、
  [observability.md](../../../docs/design/observability.md) §4.5 と矛盾しないこと。
  挙動は次のとおり明記されること (Q-L2=B で確定):
  1. **監査ログは本処理とは別トランザクションの best-effort** とし、書き込み失敗で本処理を巻き戻さない
  2. 失敗時に **WARN ログとメトリクスの両方を出す**ことが必須 (どちらか一方では不可)。
     v2 の問題は「別トランザクションだったこと」ではなく「失敗が見えないこと」である点を理由として書く
  3. **「認証・権限に関わる操作だけ同一トランザクションにする」等の例外を設けない** —
     操作の種類による分岐を作らない。必要性が観測された時点で追加する扱いであることを明記する
  4. 却下案として同一トランザクション方式 (監査ログ基盤の一時障害でユーザー操作が失敗する /
     監査ログ Repository が `XxxWithTx` 必須になり L-6 の適用範囲が Service 全体へ広がる) を記載する

### 6.5 計測点と整合性

- **AC-6.16** **LLM 計測点**が明記され、次のすべてが満たされていること (O-2 / C-L4。Q-L6=A で確定):
  1. **すべての LLM 呼び出しが単一の層 (`gateway/anthropic` 等の gateway) を通る**こと、および
     1 呼び出しあたりの記録項目 (モデル / 入出力トークン / 所要時間 / `stop_reason`) の担当層 = **gateway**
  2. **ターン単位の集計** (ツール呼び出し回数・累積トークン・安全弁の打ち切り判定) の担当層 =
     **`service/conversation.Runner`** (ツールループ・停止条件・安全弁・所有者スコープ強制も Runner)
  3. [observability.md](../../../docs/design/observability.md) の決定 O-C (`:44`) と本節が
     **同じ層名を指している**こと (現行 observability.md は「Service 層の単一ラッパ (`AgentRunner`)」と
     記述 = C-L4 と矛盾する)。**併せて O-C の却下案 (b)「プロキシ/ゲートウェイを挟む」は
     別プロセスの LLM プロキシを指しており、本増分の `gateway/` (同一プロセス内のパッケージ層) とは
     別物である**という読み分けが書かれていること (書かないと「却下済み案の再提案」に見える)
  4. **初期スコープの線引き**が書かれていること (Q-L6 / Q-L10=B で確定):

  | 項目 | 実施時期 | 理由 |
  |---|---|---|
  | gateway の戻り型が **usage 4 カウンタ** (`InputTokens` / `OutputTokens` / `CacheReadInputTokens` / `CacheCreationInputTokens`) と **`stop_reason`** を載せられること | **初期実装 (必須)** | 記録先は後から 1 箇所に足せるが、**戻り型が usage を載せられない状態は後付けできない** (利用側の IF が全経路で壊れる)。v2 は OpenAI 実装のみ usage を詰め `stop_reason` を公開型に持たないため計測が原理的に不可能だった ([v2-llm-inventory.md](../../../docs/analysis/v2-llm-inventory.md)) |
  | **安全弁** (ツール呼び出し回数・累積トークン・実行時間による打ち切り。O-3 / O-E) | **初期実装 (必須)** | 会話フローは LLM がツールを繰り返す構造で、打ち切りが無いと停止条件が LLM 任せになる (コスト制限ではなく無限ループ対策) |
  | **利用量明細の永続化** (append-only テーブル。O-D) | **v3 第 1 リリース前** | 明細は **append-only なので後から遡って補完できない** — 本番で課金が発生し始めた時点で明細が無いと、後日のコスト分析・請求根拠が永久に失われる |
  | **コスト算出・集計・アラート** (O-D のメトリクス / O-H の単価テーブル / AL-4) | **v2 併用期間中** | 既存の明細から**後付けで再計算できる**ため、初期実装から外しても情報が失われない |

  この線引きは **AC-2.1 / AC-2.2 の先送り**として §7 に対応づけられていること
- **AC-6.20** 上記 AC-6.16-4 の**先送りが設計書に節として明記**されていること
  ([08-production-gates.md](../../../.claude/rules/08-production-gates.md) が「対象外とする場合も
  **理由と先送り先 (どの増分で扱うか)** を書くこと」を要求するため):
  1. [observability.md](../../../docs/design/observability.md) の **O-D / O-H と §3 の構成図 (`:60-61`)** に、
     「明細の永続化 = v3 第 1 リリース前 / コスト算出・集計・アラート = v2 併用期間中」という
     **実施時期が読み取れる形**で書かれている (図中の要素に時期の注記を付ける、または直後に先送り節を置く)
  2. **先送りの理由が項目ごとに書かれている** (append-only で後から遡れない / 後付けで再計算できる)。
     「初期スコープ外」だけの記述は不可
  3. observability.md **§6.1「計測の実施時期 (3 段の線引き)」**が実施時期の SSOT であり、
     「**計測は第 1 増分から入れる**」の対象が §3 の ④ (計測値の生成) と ⑤ (安全弁を含むターン集計) であること —
     第 1 増分から入れるのは **型 (usage / `stop_reason`) と安全弁**であり、
     集計・アラートが後続であることが読み分けられる状態になっている
  4. **先送りされないものが明示されていること** — **メトリクスの出力手段 (基盤) そのものと、
     失敗系の warn メトリクス** (§4.3 の失敗 5 分類 / §4.5 の監査ログ書き込み失敗 /
     ツール引数の所有者不一致 / §4.4.1 の SSE 接続数) は**初期実装 (第 1 増分)** であり、
     ⑦ (利用量・コスト系) の先送り対象ではないことが書かれている。
     **理由も書かれていること**: Q-L2=B が監査ログ失敗を「WARN ログ + **メトリクス**必須」と定めている /
     失敗系は発生した事実そのものが観測対象で**明細から後付け再計算できない** /
     混同すると **O-4 (失敗の可観測性) / O-6 (監査ログ) / A-6 (越境の観測) が初回リリースで欠落する**。
     **§4.6 のアラート AL-1〜AL-7 も、それぞれが依存するメトリクスの段 (⑦ / ⑧) に割り当てられていること**
     (**design-reviewer の中 1 指摘 2026-07-30 への対応**)
- **AC-6.21** **ツール結果のフィールド契約が構造的に担保されていること** (**BE-12** への対応。
  [feedback_review_patterns.md](../../../.claude/rules/feedback_review_patterns.md) の BE-12。
  **design-reviewer の重大 4 指摘 2026-07-30 により追加**)。C-L9 のハンドラ型
  `func(ctx, tx, args) (any, error)` の `any` は **Runner が型依存を持たないための境界表現**であり、
  **値の構造が未定義でよいことを意味しない** — 次の 4 点が architecture.md に書かれていること:
  1. **ハンドラが返す値は「ツールごとに 1 箇所で宣言した型」であること**。ハンドラ内で無名の
     `map[string]any` を組み立てて返す形を禁止する
  2. **その結果を読む側 (台帳への write-through / SSE 変換 / 後続ツールの入力 / 生成物の永続化) が
     同じ型定義から読むこと**。読み手が独自の構造体を定義することを禁止する
  3. **テストが合成 JSON を手書きしないこと** — 同じ型定義から組み立てる
     (BE-12 の「テストが合成 JSON を渡していると契約違反が隠れる」への対応)
  4. **§3.8.4 の 3 者一致検査の対象が戻り値スキーマにも及ぶこと** (現状は引数のみ)。
     `templates/app-monorepo/.github/workflows/ci.yml` の D-6 ステップの説明が追随していること

  **根拠となる PoC の実例**: 読み手 `claude_managed_agents/cmd/devui/conversation_plan_grounding.go:100`〜`:102` が
  `finding` / `notes:string` を期待するのに対し、書き手 `conversation_tools_deepdive.go:168`〜`:176` に
  `finding` は無く `notes` は `[]string` — **BE-10 / BE-11 は本増分で構造的に潰せているが、BE-12 だけ抜けていた**
- **AC-6.22** **移植ドメインの LLM 呼び出しも `gateway/` 経由であることが受入条件として明記**されていること
  (**Q-L11=A-1**。ユーザー決定 2026-07-30。**design-reviewer の中 5 指摘により AC 化**)。
  次の 3 点を満たすこと:
  1. `architecture.md` §3.5.2 の適用範囲に「**v2 移植分は 3 層規約のままだが、LLM 呼び出しだけは
     `gateway/` 経由を必須とする**」が**移植の受入条件**として書かれている (層構成の据え置きと
     LLM 経路の例外が区別されている)
  2. **矛盾が解消していることが示されている** — [API/README.md](../../../docs/design/API/README.md):438 の
     「計測対象となる LLM 経路 3 本」に**移植ドメインである ナレッジの埋め込み生成
     (`POST /knowledge-files`) が含まれる**ため、この例外なしでは O-2 が破れる
  3. **移植計画への申し送りがある** — 差し替え対象 (v2 の `llm/` を呼んでいる箇所) の洗い出しが
     [llm-migration.md](../../../docs/design/llm-migration.md) または移植計画の範囲として記載されている

  **根拠**: v2 の `llm/` は**そもそも usage を載せられない** (OpenAI 実装のみ・`ctx` なし。
  [v2-llm-inventory.md](../../../docs/analysis/v2-llm-inventory.md))。移植先で計測したくなった時点で
  gateway 相当が必要になるため、例外を設けない方が後で払うコストが大きい
- **AC-6.18** §3 の**代表ユースケース (会話 1 ターン) の層配置表**が新層構成に更新され、
  各ステップの層が **L-1〜L-6 に違反しないこと** (特にツール実行のステップが Service から
  他ドメイン Repository を呼ぶ形になっていないこと)。entity / gateway が配置先として現れること
- **AC-6.15** **UseCase 肥大化の抜け道**が §5 の 5 分類 (entity / gateway / service / usecase 内のファイル分割 /
  `prompts/`) として architecture.md に明記され、「**共通 Service の新設禁止**」が書かれていること。
  加えて **肥大化対策の lint が「重複検出を主役、行数を補助」の構成である**ことと、
  次の 3 種が値付きで書かれていること (F3。Q-L4=E で確定):

  | linter | 設定値 | 狙い |
  |---|---|---|
  | **`dupl`** (主役) | しきい値 **150 トークン** | v2 の実害を直接狙う — `hassan-v2-backend/usecase/idea/web_search.go` の 150 行重複と `hassan-v2-backend/usecase/business_plan/detailed/brush_up_business_plan_detailed.go` の 6 関数の同一骨格 (F3) はどちらも重複であり、`dupl` が検出する |
  | `cyclop` | 複雑度 **15** | 長さではなく**分岐の多さ**を締める |
  | `funlen` (補助) | **150 行 / 80 ステートメント** | 明確な外れ値のみを止める |

  **検証可能な形での要求**: `templates/app-monorepo/backend/.golangci.yml` に上記 3 linter が
  **上表の値で有効化**され、`templates/app-monorepo/.github/workflows/ci.yml` の「D-2①⑤ golangci-lint」ステップが
  その設定を使い、**違反で CI が失敗する**こと (対象パスは AC-6.19 の一覧に従う)。

  **`funlen` を 80 行にしない理由を実測値 (F15) で記載すること** (却下案の記録):
  `hassan-v2-backend/usecase/` 配下の**非テスト関数 573 個**の分布は 80 行以上 **40 個 (7.0%)** /
  100 行以上 28 / 150 行以上 **21 個 (3.7%)** / 200 行以上 14 / 300 行以上 3。
  80 行では `hassan-v2-backend/usecase/research_sheet/handle_create_sheet.go` の
  `HandleCreateSheetUseCase.Execute` (**385 行**) や
  `hassan-v2-backend/usecase/business_plan/detailed/web_research.go` の
  `BusinessPlanWebResearchUseCase.Execute` (**356 行**) のような
  **「順に呼ぶだけの長い手続き」を大量に誤検知する** — UseCase は手続きなので行数は自然に伸びる
  (実測: 両ファイルはそれぞれ 676 行 / 427 行で、上記の 1 関数が大半を占める)。
  **ファイル行数の上限を設けない理由** (別ファイルへ移すだけで回避できる) も併記する

## 7. 既存 AC との関係

| 既存 AC | 本増分での扱い |
|---|---|
| **AC-5.1** (4 層の責務境界と禁止依存の定義 + 代表ユースケース 1 本での具体例) | **本増分で定義内容を更新する**。C-L3 (Service = 1 ドメイン) / C-L4 (外部 API = gateway) / C-L5 (entity 層の追加) に沿って責務境界を書き換え、代表ユースケース表を AC-6.18 で更新する。**AC-5.1 自体は削除・改番しない** (機械照合が壊れるため) — 「4 層」の内訳が Controller → UseCase → Service → Repository のままである点も維持される (entity / gateway は adapter / 内側の層として追加される位置づけ) |
| **AC-1.3** (custom tool の所有者スコープ) | 維持。ただし**強制点が ToolDispatcher から「UseCase が注入するハンドラ」へ移る** → AC-6.8 が新しい強制点を要求する |
| **AC-2.1** (全 LLM 経路の計測) | 維持。**計測層が Service → gateway に移る** → AC-6.16。**AC-ID は削除・改番しない** (`make check-traceability` が壊れる)。Q-L10=B により**実施時期を分ける**: **型の要件 (usage 4 カウンタ + `stop_reason` を gateway の戻り型に載せる) は初期実装で満たす**が、**明細の永続化は v3 第 1 リリース前に先送り**する (理由: 明細は append-only で後から遡って補完できないため、本番課金開始までに必要。一方で記録先は後から 1 箇所に足せる) → AC-6.16-4 / AC-6.20 |
| **AC-2.2** (コスト集計とアラート) | 維持。**AC-ID は削除・改番しない**。Q-L10=B により**コスト算出・集計・アラートは v2 併用期間中に先送り**する (理由: 既存の明細から後付けで再計算できるため、初期実装から外しても情報が失われない)。**安全弁 (O-3 / O-E) は先送りしない** — 初期実装必須 (コスト制限ではなく無限ループ対策) → AC-6.16-4 / AC-6.20 |
| **AC-2.3** (LLM 起因の失敗が握り潰されない) | 維持。**エラー型の契約として具体化される** → AC-6.17 |
| **AC-2.5** (生成・削除操作の監査記録の方針) | 維持。**失敗時の挙動が本増分で確定する** → AC-6.13 |
| **AC-3.2** (CI ゲート) | 維持。**依存規則の検査とサイズ lint が追加される** → AC-6.14 / AC-6.15 |

## 8. 本番観点 (08-production-gates) との対応

| ID | 本増分での回答 | 対応する AC |
|---|---|---|
| **A-6** (LLM のテナント越境) | ツール handler を UseCase が関数注入し、**所有者スコープをクロージャで束縛**する。Runner はドメインを知らないため、越境の経路が構造的に存在しない | AC-6.7 / AC-6.8 |
| **O-2** (全 LLM 呼び出しの計測) | **gateway 1 箇所**を全 LLM 呼び出しの通り道にし、ターン単位の集計は Runner が持つ。**初期実装は「型 (usage 4 カウンタ + `stop_reason`) を戻り値に載せられること」まで**で、**明細の永続化は v3 第 1 リリース前、コスト算出・集計は v2 併用期間中に先送り** (理由は AC-6.16-4 の表) | AC-6.16 / AC-6.20 |
| **O-4** (失敗の可観測性) | `stop_reason` / JSON パース失敗 / タイムアウト / ツール引数不整合を**エラー型の契約で区別可能にする** | AC-6.17 / AC-6.11 |
| **O-6** (監査ログ) | 書き込み失敗時の挙動を確定し、`_ =` 無言破棄を禁止する (現行「未回答」を解消) | AC-6.13 |
| **D-2** (CI ゲート) | 依存規則 L-1〜L-6 と UseCase サイズ上限を depguard / golangci-lint で機械強制する | AC-6.14 / AC-6.15 |
| **D-6** (Agent ライフサイクル) | 関数注入で tool 名が文字列キーになるため、**schema ↔ handler の対応漏れ検査**を起動時 / CI に置く | AC-6.9 |
| A-1 / A-3 / A-4 / A-5 / A-7 | **本増分の対象外**。[auth.md](../../../docs/design/auth.md) が SSOT で、層構成の変更によって影響を受けるのは「絞り込みを行う層の名称」のみ (A-4) → 追随のみ ([plan-layering.md](plan-layering.md) §2) | — |
| **O-3** (コスト集計と上限) | **安全弁 (打ち切り) は初期実装必須**、**コスト集計とアラートは v2 併用期間中に先送り** (Q-L10=B)。しきい値の置き場は `config` (AC-6.12)。課金上限による拒否は設けない (C-12 / O-E) | AC-6.16 / AC-6.20 / AC-6.12 |
| O-1 / O-5 / O-7 | **本増分の対象外**。O-7 のアラートは O-3 と同じく v2 併用期間中 (AC-6.20) | — |
| D-1 / D-3 / D-4 / D-5 / D-7 / D-8 | **本増分の対象外** (層構成と独立)。先送り先は親 [plan.md](plan.md) の Task-3d / 3e | — |

## 9. 規約の粒度・範囲・値の決定 (Q-L1〜Q-L11。全て回答済み)

[questions-layering.md](questions-layering.md) の Q-L1〜Q-L10 は **2026-07-29 にユーザー決定として全て回答済み**。
**暫定既定 (推奨案の既定採用) は 1 件も残っていない**。証跡は questions-layering.md の各 `[Answer]:` 行。

| Q | 論点 | 決定 (2026-07-29) | 影響 AC |
|---|---|---|---|
| Q-L1 | `fmt.Errorf` 禁止の粒度 | **B** — 層境界のみ `CodedError` 必須。パッケージ内部は `fmt.Errorf("...: %w", err)` 可。**CI 検査は層境界の関数の戻り値に限定** | AC-6.11 / AC-6.17 |
| Q-L2 | 監査ログ失敗時の挙動 | **B** — 別トランザクションの best-effort + **WARN ログとメトリクスの両方が必須**。**操作の種類による例外 (認証・権限操作だけ失敗させる等) は設けない** | AC-6.13 |
| Q-L3 | 依存規則 L-1〜L-6 の適用範囲 | **A** — v3 新規ドメインのみ機械強制。移植分は v2 の 3 層規約を維持。**条件: 対象パス一覧を architecture.md に書く** | AC-6.14 / AC-6.19 |
| Q-L4 | 肥大化対策の lint | **E (推奨 B から差し替え)** — **`dupl` 150 トークンを主役**、`cyclop` 15、`funlen` は **150 行 / 80 ステートメント**に緩和。ファイル行数の上限は設けない。根拠は F15 の分布 | AC-6.15 |
| Q-L5 | 他ドメイン Repository の read-only 例外 | **A** — 例外なし | AC-6.3 |
| Q-L6 | Agent 実行の層分割と計測点 | **A** — ツールループ・停止条件・安全弁・所有者スコープ強制 = `service/conversation.Runner` / SDK 呼び出し・SSE 受信・usage 抽出 = `gateway/anthropic`。**計測は「型 (usage 4 カウンタ + `stop_reason`) と安全弁」のみ初期実装**、明細永続化・コスト算出・集計・アラートは Q-L10 の時期へ先送り。**observability.md O-C 却下案 (b) の「プロキシ/ゲートウェイ」は別プロセスのプロキシであり `gateway/` 層とは別物**である読み分けを明記する | AC-6.16 / AC-6.20 |
| Q-L7 | ツールハンドラの `tx` / スコープの受け取り方 | **B** — `tx` はハンドラのシグネチャに出す (`func(ctx, tx, args)`)。**所有者スコープはクロージャ束縛** | AC-6.7 / AC-6.8 |
| Q-L8 | `repository/` のドメイン別分割 | **B** — **v3 新規ドメインのみ** `repository/<domain>/` に分割。移植分はフラット維持 (Q-L3=A と同一範囲)。**L-3 の depguard 検査が成立する前提条件** | AC-6.3 / AC-6.14 / AC-6.19 |
| Q-L9 | プロンプトの置き場 | **C** — **テンプレートファイルは `prompts/<domain>/`**、**構築ロジックは `service/<domain>/`**。D-6 の 3 者一致検査と D-E の Agent 発行が走査するパスが確定する | AC-6.5 / AC-6.9 |
| Q-L10 | 計測の先送り先 | **B** — **明細の永続化は v3 第 1 リリース前** / **コスト算出・集計・アラートは v2 併用期間中**。既存 AC-2.1 / AC-2.2 は削除せず「先送り」として §7 に記録する | AC-2.1 / AC-2.2 / AC-6.16 / AC-6.20 |

## 10. 残課題 / 前提としている解釈

### 10.1 解消済み (2026-07-29 の Q-L 回答による)

| 旧残課題 | 解消した回答 | 決着 |
|---|---|---|
| **C-L9 と `tx` 受け渡し原則 (D-A'') の不整合** — C-L9 の例示シグネチャは `tx` をハンドラ引数に含めていなかった | **Q-L7=B** | ハンドラ型を `func(ctx, tx, args) (any, error)` とし `tx` を引数に出す。所有者スコープのみクロージャ束縛 → AC-6.7 / AC-6.8 |
| **C-L4 と D-D / observability.md の矛盾** — 「Service 層の `AgentRunner` で計測」と複数文書に書かれていた | **Q-L6=A** | Runner = Service (ループ・停止条件・安全弁)、SDK 呼び出しと usage 抽出 = gateway。observability.md の O-C・図・§5 O-2 行・§7 を追随させる ([plan-layering.md](plan-layering.md) の Task-L20) → AC-6.16 |
| **depguard で L-3 を表現するには Repository のパッケージ分割方針が要る** (v2 は `repository/` に 31 ファイル・単一パッケージ) | **Q-L8=B** | v3 新規ドメインのみ `repository/<domain>/` に分割。分割しない範囲では L-3 は機械強制されずレビュー対象になることを明記 → AC-6.3 / AC-6.14 |
| **プロンプト構築ロジックの置き場が未定** (entity か Service か独立パッケージか) | **Q-L9=C** | テンプレートファイル = `prompts/<domain>/`、構築ロジック = `service/<domain>/` → AC-6.5 |
| **計測の初期スコープと先送り先が未定** (08 が要求する「理由と先送り先」が書けない状態だった) | **Q-L6 / Q-L10=B** | 型と安全弁は初期実装 / 明細は第 1 リリース前 / 集計・アラートは v2 併用期間中 → AC-6.16-4 / AC-6.20 |

### 10.2 残っている前提と未調査範囲

- **C-L5 の「v2 の `entity/` を拡張する」の解釈**: v3 backend は**新規リポジトリ** (親 requirements.md の C-10 /
  Q-1=C により v3 の資源は全て新規) なので、literal に「v2 の `entity/` を編集する」ことはできない。
  本書は「**v3 backend のパッケージ名を `entity/` とし (v2 命名の踏襲。F13 のとおり v2 の `entity/` は
  テストを持つ既存パッケージ)、v2 から移植するコードの entity 定義もそこへ集める**」と解釈している。
  異なる意図であれば指摘を要する
- **F11 の件数を修正した**: 依頼時の前提は「6 ファイル 15 箇所」だったが、
  `hassan-v2-backend/docs/refactoring-plan.md:123-129` の列挙を計数すると
  **6 ファイル 17 箇所** (usecase 4 ファイル 14 箇所 + controller 2 ファイル 3 箇所)。本書は 17 箇所を採る
- **未調査**: v2 に `gateway/` 相当のパッケージが存在しないことは確認したが (F6 のとおり外部サービスは
  トップレベルパッケージ + 型エイリアス方式)、
  **v2 の `llm/` / `prompt/` / `ogp/` / `microcms/` を v3 の `gateway/` へ移す際の具体的な再配置単位**は
  本増分では調べていない (移植計画の範囲。親 plan.md の Task-3h)。
  Q-L9=C により **`prompt/` の行き先だけは確定**した (テンプレート = `prompts/<domain>/` /
  構築ロジック = `service/<domain>/`) が、v2 の `prompt/` 内の 49 件の `fmt.Errorf` (F4) の
  書き換え単位は移植計画側で決める (Q-L1=B により境界のみ `CodedError` 化すれば足りる)
- **未調査**: `db/queries/` と sqlc の出力先 (`db/rdb/`) を repository 分割に合わせて分けるかは
  本増分の対象外 (Q-L8 の「左右するもの」に記載のとおり別問題)。データモデル増分 (親 Q-1) で扱う
- **未確定 (architecture.md 側で決まる)**: `repository/<domain>/` の**ドメインの切り方**
  (テーマ / アセット / 会話・アイデア創出の 3 つか、さらに細分するか) は
  [architecture.md](../../../docs/design/architecture.md) の改訂で確定する。
  AC-6.19 の対象パス一覧と AC-6.3 の分割範囲が同一になることのみ本書が要求する
