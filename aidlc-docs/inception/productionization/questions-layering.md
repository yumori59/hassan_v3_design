# Questions (増分: layering): 層構成の再定義に伴う未確定論点

> 本書は増分 **layering** の質問ファイル。親: [questions.md](questions.md) (Q-1〜Q-9。本書は Q-1 / Q-8 に踏み込まない)。
> 要件: [requirements-layering.md](requirements-layering.md) / 計画: [plan-layering.md](plan-layering.md)
> 改訂対象の設計書: [architecture.md](../../../docs/design/architecture.md)
>
> **回答は `[Answer]:` 行に書く**。未回答のまま進める場合は `> 推奨:` を暫定既定として
> requirements-layering.md §9 に「既定採用」と明記して設計を進める。
> 各問いには **この回答が何を左右するか** を添えた — 回答が来るまで着手できないタスクは
> [plan-layering.md](plan-layering.md) §5 が示す。

**前提**: 層構成そのもの (C-L1〜C-L12) は 2026-07-29 のユーザー決定として確定済みで、本書では再議論しない
(一覧: [requirements-layering.md](requirements-layering.md) §3)。本書が問うのは **その決定を規約として
実装リポで守らせるための粒度・範囲・値**である。

---

## Q-L1. `fmt.Errorf` 禁止の粒度

v2 の規約は「**`constants.NewCodedError(...)` の使用は必須。`fmt.Errorf` 禁止**」
(`hassan-v2-backend/CLAUDE.md:43`)。しかし実測では**非テストコードに `fmt.Errorf` が約 113 件**
(prompt 49 / dify 29 / azuredi 12 / aws 6 / hassanresend 4 / auth 3 ほか)、`errors.New` が 7 件残っている
(`hassan-v2-backend/docs/refactoring-plan.md:62`)。= **全面禁止は 3 年運用しても守られなかった規約**である。
v3 でどちらを採るかを決める。

- **A. v2 と同じ全面禁止** — 非テストコードで `fmt.Errorf` / `errors.New` を使わせず、
  すべて `CodedError` を返す。CI で `fmt.Errorf` の出現をゼロ件検査する
- **B. 層境界のみ `CodedError` 必須** — **gateway → 上位、Service / UseCase → Controller の戻り値は
  `CodedError`**。パッケージ内部での文脈追加は `fmt.Errorf("...: %w", err)` を許可し、
  境界で `CodedError` に包み直す。CI は「境界を越える公開関数の戻り値」を検査対象にする
- C. Other (please describe after [Answer]: tag below)

> 推奨: **B**。理由: 全面禁止は Go のイディオム (`%w` によるラップ) から外れるため、
> 「守れない規約 → 違反が溜まる → 規約自体が信用されない」という v2 の経路 (113 件) を再現する。
> B は**エラー型の契約を層境界に限定する**ので、CI 検査の対象が小さく機械強制が現実的になる。
> なお A を選ぶ場合、v2 から移植するコードは 113 件の書き換えを伴う (Q-L3 の適用範囲と連動)。

**この回答が左右するもの**: AC-6.11 のエラー契約表の粒度 / CI 検査の対象範囲と実装コスト /
gateway が LLM 起因の失敗 (`stop_reason == max_tokens`・JSON パース失敗) を上位へ伝える型 (AC-6.17 / O-4) /
Controller の HTTP 変換を 1 箇所に集約する際の判定関数の形 (F5: v2 は `err.(*constants.CodedError)` を
**8 ファイル 61 箇所**にコピペ。`hassan-v2-backend/docs/refactoring-plan.md:545`)。

[Answer]: **B** (層境界では `CodedError` 必須、パッケージ内部の文脈追加は `fmt.Errorf("%w", err)` 可) —
ユーザー決定 2026-07-29。根拠: 全面禁止は v2 で 113 件の違反が溜まり (F4)、規約として機能しなかった。
CI 検査は**層境界の関数の戻り値**に絞る (誤検知を減らし、検査対象を明示できる)。

---

## Q-L2. 監査ログ・アクティビティログの書き込み失敗時の挙動 (O-6 への回答)

v2 は**監査ログの書き込みエラーを `_ =` で無言破棄**している (実測: `usecase/` 配下 4 ファイル 14 箇所
+ `controller/` 2 ファイル 3 箇所 = 計 6 ファイル 17 箇所。列挙は
`hassan-v2-backend/docs/refactoring-plan.md:123-129`。例: `hassan-v2-backend/usecase/idea_board/activity_log.go:25`)。
v3 では**無言破棄を禁止する**ことは確定 (C-L12 ③) で、決めるのは「失敗したときに本処理をどうするか」。

- **A. 本処理と同一トランザクションに入れる** — 監査ログの書き込み失敗で本処理も巻き戻る。
  監査記録の欠落が構造的に起きない
- **B. 別トランザクションの best-effort + 失敗時の警告ログ必須** — 本処理は成功させ、
  監査ログ失敗を **WARN ログ + メトリクス**として観測可能にする (握り潰さない)
- C. Other (please describe after [Answer]: tag below)

> 推奨: **B**。理由: 監査ログ基盤の一時障害でユーザー操作 (アイデア生成・企画書保存) が失敗するのは
> 可用性の損失が大きい。**v2 の問題は「別トランザクションだったこと」ではなく「失敗が見えないこと」**
> なので、観測可能にすれば O-6 の要求は満たせる。ただし「認証・権限に関わる操作」だけは A 相当
> (失敗させる) にする余地があり、その線引きが必要なら Other で指定してほしい。

**この回答が左右するもの**: AC-6.13 / [architecture.md](../../../docs/design/architecture.md) §5 の
O-6 (現状「**未回答**」) / [observability.md](../../../docs/design/observability.md) §4.5 の記述 /
監査ログ Repository のメソッド形 (A を採ると `XxxWithTx` が必須になり、
Service から監査ログを書く経路すべてに `tx` が要る = L-6 の適用範囲が広がる)。

[Answer]: **B** (別トランザクションの best-effort + 失敗時の WARN ログ + メトリクス必須) —
ユーザー決定 2026-07-29。根拠: v2 の問題は「別トランザクションだったこと」ではなく
「失敗が見えないこと」(F11 の 6 ファイル 17 箇所)。
なお「認証・権限に関わる操作だけ A 相当にする」例外は**本増分では設けない** —
必要性が観測された時点で追加する。

---

## Q-L3. 依存規則 L-1〜L-6 の適用範囲

[design_memo.md](../../../docs/design/design_memo.md):94 は
「**v2 から移植する認証・アカウント等は v2 の 3 層構成のまま移植する**」と決めている。
一方 L-1〜L-6 ([requirements-layering.md](requirements-layering.md) §4) は 4 層 + entity + gateway を前提とする。
= **同一リポジトリに 2 つの層規約が並ぶ**。depguard の対象範囲を決める必要がある。

- **A. v3 新規ドメインのみ適用** — テーマ / アセット / 会話・アイデア創出のパッケージにのみ
  L-1〜L-6 を機械強制する。移植コードは v2 規約 (3 層・禁止依存のみ) を維持
- **B. リポジトリ全体に適用** — 移植コードも entity / gateway / Service に再配置する
- C. Other (please describe after [Answer]: tag below)

> 推奨: **A**。理由: B は移植時に「動いているコードの再設計」を強制し、
> `fmt.Errorf` 113 件 (F4) と型エイリアス 20 箇所 (F6) の書き換えが移植の前提条件になる。
> depguard は**パス単位で規則を切り替えられる**ため、A でも機械強制は成立する。
> ただし A は「どのパッケージがどちらの規約か」を一覧で持たない限り曖昧になるので、
> **対象パスの一覧を architecture.md に書く**ことを条件とする (AC-6.19)。

**この回答が左右するもの**: depguard 設定の対象パスと除外リスト (AC-6.14) /
architecture.md に書く「2 規約併存」の記述 (AC-6.19) / UseCase サイズ上限 lint の対象 (Q-L4) /
Q-L1 で A (全面禁止) を選んだ場合の書き換え量。

[Answer]: **A** (v3 新規ドメインのみ機械強制。移植コードは v2 規約を維持) — ユーザー決定 2026-07-29。
**条件**: 「どのパッケージがどちらの規約か」の**対象パス一覧を architecture.md に書く** (AC-6.19)。
Q-L8 (repository のドメイン別分割) も同じ範囲 = 新規ドメインのみに揃える。

---

## Q-L4. UseCase のサイズ上限を lint で機械強制するか (するなら指標と値)

「跨ぎは UseCase」に寄せると UseCase が太る。v2 の実例: `hassan-v2-backend/usecase/idea/web_search.go`
**1381 行** (うち `EnsureValuesFromCitedURL` の 150 行が重複)、
`hassan-v2-backend/usecase/business_plan/detailed/brush_up_business_plan_detailed.go` **919 行**
(6 関数が「プロンプト構築 → LLM → JSON 抽出 → パース → OGP 付与 → 保存」をほぼ同一骨格で重複)
— `hassan-v2-backend/docs/refactoring-plan.md:66-67`。
**v2 には golangci-lint 設定が無く** CI は `go test` のみ (`hassan-v2-backend/.github/workflows/test.yml`) なので、
サイズの歯止めは存在しなかった。

- **A. 強制しない** — レビューで見る
- **B. 関数長のみ強制** — `funlen` (例: 80 行 / 50 ステートメント)。ファイル行数は制限しない
- **C. 関数長 + ファイル行数** — `funlen` + ファイル 500 行超で CI 失敗 (独自スクリプト)
- **D. 循環的複雑度で強制** — `cyclop` / `gocyclo` (例: 複雑度 15)
- E. Other (please describe after [Answer]: tag below)

> 推奨: **B** (`funlen` 80 行 / 50 ステートメント)。理由: v2 の実害は「ファイルが長い」ことより
> **1 関数に同一骨格が溜まる**形で現れた (919 行の 6 関数)。関数長を締めると共通部分の抽出が強制され、
> 抽出先が entity / gateway / UseCase 内ヘルパーのどれかへ振り分けられる (§5 の抜け道)。
> C のファイル行数は「別ファイルへ移すだけ」で回避でき、D は「長いが単純」な手続き的 UseCase を
> 誤検知しやすい。B で不足が観測されたら D を追加する。

**この回答が左右するもの**: `templates/app-monorepo/backend` に追加する `.golangci.yml` の内容 (AC-6.15) /
CI の失敗条件 (D-2) / 既存移植コードを対象に含めるか (Q-L3 と連動 —
B を全体適用すると v2 移植分が即座に落ちる)。

[Answer]: **E (推奨 B から差し替え)** — ユーザー決定 2026-07-29。**重複検出を主役にし、行数は補助**にする:

| linter | 設定 | 狙い |
|---|---|---|
| **`dupl`** (主) | しきい値 150 トークン | v2 の実害を直接狙う — R7 (`web_search.go` の 150 行重複) / R8 (`brushXxx` 6 関数の同一骨格) はどちらも `dupl` が検出する |
| `cyclop` | 複雑度 15 | 長さではなく分岐の多さを締める |
| `funlen` (補助) | **150 行 / 80 ステートメント** | 明確な外れ値のみ |

根拠 (実測 2026-07-29。`hassan-v2-backend/usecase/` 配下の非テスト関数 **573 個**の分布):
80 行以上 **40 個 (7.0%)** / 100 行以上 28 / **150 行以上 21 (3.7%)** / 200 行以上 14 / 300 行以上 3。
推奨 B の 80 行では `usecase/research_sheet/handle_create_sheet.go` (385 行) や
`usecase/business_plan/detailed/web_research.go` (356 行) のような
**「順に呼ぶだけの長い手続き」を大量に誤検知する** — UseCase は手続きなので行数は自然に伸びる。
実害は長さではなく**重複**だったため (F3 / R7 / R8)、`dupl` を主役に据える。

---

## Q-L5. Service が他ドメインの Repository を読む例外を認めるか

C-L2 は「Service → Repository は**自ドメインのみ**」。他ドメインのデータは UseCase が取得して引数で渡す。
read-only の横断参照 (例: `conversation` の Service が `theme` の名称を読むだけ) を例外として許すか。

- **A. 例外なし** — 全面禁止。他ドメインのデータは UseCase が取得して引数で渡す
- **B. read-only の横断参照のみ許可** — 書き込みは禁止、読み取りは許可
- C. Other (please describe after [Answer]: tag below)

> 推奨: **A**。理由: B を許すと C-L1 (Service → 他ドメイン Service 禁止) が **Repository 経由で実質無効化**
> される (他ドメインのロジックを呼ぶ代わりに他ドメインのテーブルを直接読む形になり、依存は残ったまま
> 経路が見えにくくなる)。加えて **depguard は「read-only かどうか」を静的に判定できない** ため、
> B の機械強制はメソッド命名規約 (`Get*` のみ許可) に頼ることになり、規約の抜けが生まれる。
> A の代償 (UseCase が太る) は §5 の抜け道 3 つと Q-L4 の lint で受ける。

**この回答が左右するもの**: L-3 の depguard 規則の書き方 (パッケージ単位の全面禁止 か 例外リスト方式) /
AC-6.3 の文言 / 代表ユースケース表 (会話 1 ターン) のステップ 5・6 の層配置。

[Answer]: **A** (例外なし。Service が触れる Repository は自ドメインのみ) — ユーザー決定 2026-07-29。
代償 (UseCase が太る) は §5 の抜け道 3 つと Q-L4 の `dupl` / `cyclop` / `funlen` で受ける。

---

## Q-L6. Agent 実行 (ツールループ) と Anthropic API 呼び出しの層分割、および LLM 計測点

**矛盾が生じている**: C-L4 は「外部 API 呼び出しは gateway」と決めたが、
[architecture.md](../../../docs/design/architecture.md) の D-D と
[observability.md](../../../docs/design/observability.md):44 (決定 O-C) は
「**Service 層の単一ラッパ (`AgentRunner`) で全経路を計測する**」と書いている。
`AgentRunner` は Anthropic API を呼ぶので、C-L4 に従えば gateway になる。どちらに寄せるかを決める。

- **A. 分割する** — ツールループ・停止条件・安全弁 (O-3)・SSE イベント変換 = **Service** (`conversation.Runner`) /
  Anthropic SDK 呼び出し = **`gateway/anthropic`**。**1 回の LLM 呼び出しの計測は gateway**、
  **ターン単位の集計 (ツール呼び出し回数・累積トークン・打ち切り判定) は Runner**
- **B. Agent 実行まるごと gateway に置く** — Runner も gateway 内に入れ、計測点を 1 つに保つ
- C. Other (please describe after [Answer]: tag below)

> 推奨: **A**。理由: 停止条件と安全弁は**業務ルール**であり、差し替え可能な外部アダプタに置くと
> プロバイダ実装ごとに重複する (v2 の `llm/{openai,gemini,claude,perplexity}` で
> HTTP/JSON 送受信が 4 重複した形と同じ轍 —
> `hassan-v2-backend/docs/refactoring-plan.md:68`)。計測の単一点は
> **「全 LLM 呼び出しが gateway を通る」ことで担保**でき、直接 API 経路も同じ gateway を通るため
> O-2 はむしろ強くなる (v2 は OpenAI 実装のみ usage を詰めていた —
> [v2-llm-inventory.md](../../../docs/analysis/v2-llm-inventory.md))。

**この回答が左右するもの**: AC-6.16 / [observability.md](../../../docs/design/observability.md) の
決定 O-C (:44) ・§4.2 ・:196 の記述更新 /
[API/README.md](../../../docs/design/API/README.md):208-209 と
[API/assets.md](../../../docs/design/API/assets.md):108 / :161-162、
[API/knowledge.md](../../../docs/design/API/knowledge.md):161 / :193 の `AgentRunner` 参照 /
[auth.md](../../../docs/design/auth.md):429 / :454 の `ToolDispatcher` 参照 (C-L9 と連動)。

[Answer]: **A** (ツールループ・停止条件・安全弁・所有者スコープ強制 = `service/conversation.Runner` /
Anthropic SDK 呼び出し・SSE 受信・usage 抽出 = `gateway/anthropic`) — ユーザー決定 2026-07-29。

**併せて確定した計測のスコープ** (ユーザー決定 2026-07-29):

| 項目 | 初期開発 |
|---|---|
| gateway の戻り型が **usage 4 カウンタ** (`InputTokens` / `OutputTokens` / `CacheReadInputTokens` / `CacheCreationInputTokens`) と **`stop_reason`** を載せられること | **入れる** |
| **安全弁** (ツール呼び出し回数・トークン・実行時間の打ち切り。O-3 / O-E) | **入れる** |
| 明細の永続化・コスト算出・集計・アラート | **先送り** (先送り先は Q-L10) |

理由: 記録先は後から 1 箇所に足せるが、**戻り型が usage を載せられない状態は後付けできない** —
v2 は OpenAI 実装のみ usage を詰め `stop_reason` を公開型に持たないため計測が原理的に不可能
(`docs/analysis/v2-llm-inventory.md` / 過去レビュー重大 5)。

**明記が必要な読み分け**: [observability.md](../../../docs/design/observability.md):44 の O-C 却下案 (b)
「プロキシ/ゲートウェイを挟む」は**別プロセスの LLM プロキシ**を指しており、
本増分の `gateway/` (同一プロセス内のパッケージ層) とは**別物**である。
この区別を書かないと「既に却下された案の再提案」に見える。

---

## Q-L7. 関数注入されたツールハンドラが `tx` と所有者スコープを受け取る方法

C-L9 の例示シグネチャは `RunTurn(ctx, tx, scope, tools map[string]func(ctx, args) (any, error), input)`。
このとき**ハンドラ側**が `tx` と所有者スコープをどう受け取るかで 2 通りある。

- **A. クロージャ束縛** — UseCase が `tx` と所有者スコープを閉じ込めたクロージャを作って渡す。
  Runner のシグネチャは最小のまま
- **B. `tx` は引数で明示** — ハンドラを `func(ctx, tx, args) (any, error)` にし、Runner が受け取った `tx` を
  そのまま渡す。**所有者スコープはクロージャ束縛のまま**にする
- C. Other (please describe after [Answer]: tag below)

> 推奨: **B**。理由 (2 点):
> ① [architecture.md](../../../docs/design/architecture.md) §3「トランザクションの受け渡し機構」(D-A'') は
> 「**`tx` をシグネチャで受け取る = トランザクション内で動くことが型に現れる**」を原則にしている。
> クロージャに `tx` を隠すと、どのハンドラが書き込みトランザクション内で動くかがコードから読めず、
> **BE-10 (台帳への write-through 欠落) / BE-11 (採番のサイレント失敗)** を型で防げない。
> `*sql.Tx` はドメイン型ではないので、引数に出しても C-L9 の「Runner が型依存を持たない」は保たれる。
> ② 所有者スコープは**クロージャ束縛のまま**にする — 引数にすると Runner (= LLM 出力を扱う層) が
> スコープを組み替えられる余地が生まれ、A-6 の強制が「Runner の実装が正しいこと」に依存してしまう。

**この回答が左右するもの**: AC-6.7 / AC-6.8 / L-6 の文言 / 代表ユースケース表 (会話 1 ターン) の
ステップ 12 (台帳 write-through) と 13 (生成物の採番) の層配置 /
既存レビュー指摘への対応形 ([review-architecture-observability.md](../../reviews/productionization/review-architecture-observability.md) の
重大 1 が挙げた「outbound port 方式」との整合)。

[Answer]: **B** (`tx` はハンドラのシグネチャに出す。所有者スコープはクロージャ束縛) —
ユーザー決定 2026-07-29。根拠: `tx` をクロージャに隠すと、どのハンドラが書き込みトランザクション内で
動くかがコードから読めず BE-10 / BE-11 を型で防げない。所有者スコープを引数にすると
Runner (LLM 出力を扱う層) がスコープを組み替えられる余地が生まれ、A-6 の強制が Runner の実装依存になる。

---

## Q-L8. `repository/` をドメイン別パッケージに分割するか (2026-07-29 追加)

v2 は `repository/asset.go` のようなフラット構成 (`hassan-v2-backend/repository/` に 31 ファイル、
すべて同一パッケージ)。一方 **L-3「Service が触れる Repository は自ドメインのみ」を depguard で
検査するにはパッケージ境界が必要**である (同一パッケージ内は import 制約で表現できない)。

- **A. v2 と同じフラット構成** — L-3 の機械強制は不可 (レビュー頼みになる)
- **B. v3 新規ドメインのみ分割** — `repository/theme/` `repository/asset/` … 移植コードはフラット維持
- **C. 全面分割** — 移植コードの import パスも書き換える
- D. Other

[Answer]: **B** (新規ドメインのみドメイン別パッケージに分割。移植コードはフラット維持) —
ユーザー決定 2026-07-29。Q-L3=A (依存規則は新規ドメインのみ) と適用範囲を揃える。
C は移植コードの import パス書き換えを移植の前提条件にしてしまう。

**この回答が左右するもの**: L-3 の depguard 規則が成立するか / AC-6.3 の検証方法 /
`db/queries/` と sqlc の出力先構成 (`db/rdb/` を分割するかは別問題として残る)。

---

## Q-L9. `prompt/` の置き場 (2026-07-29 追加)

v2 は `prompt/` を**外部サービス扱い**にしている (`hassan-v2-backend/CLAUDE.md:34` の列挙に含まれる) が、
実体はテンプレート構築 = 副作用のない純粋ロジックである。**`fmt.Errorf` 49 件を抱える最大の巣**でもある
(F4)。加えて D-E で「プロンプトはリポジトリ内のファイルを正とし、Agent 発行を CI/デプロイ手順に
組み込む」と決まっているため、**テンプレートファイル自体の置き場**も同時に決まる。

- **A. 独立した `prompt/` を維持** (v2 方式)
- **B. `entity/prompt/` に置く** (純粋ロジックなので entity 層)
- **C. ハイブリッド** — テンプレートファイルは `prompts/<domain>/` に集約、構築ロジックは `service/<domain>/`
- D. Other

[Answer]: **C** — ユーザー決定 2026-07-29。根拠 2 点:
① テンプレートファイルを 1 箇所に集約すると、**D-E の Agent 発行スクリプトと D-6 の
schema ↔ handler ↔ prompt 3 者一致検査が単一のディレクトリを見れば済む** (散在すると検査が漏れる)。
② 「どのバージョンのデータをプロンプトに渡すか」は**ドメインの業務ルール** (BE-1 の再発防止点) なので、
構築ロジックは `service/<domain>/` に置くのが責務として正しい。

**この回答が左右するもの**: フォルダ構成 (AC-6.5 の entity 層の範囲) / D-6 の検査スクリプトが走査する
パス / 移植時に v2 の `prompt/` 49 件をどこへ移すか (Q-L1=B により `CodedError` 化は境界のみ)。

---

## Q-L10. 計測 (明細永続化・コスト算出・集計・アラート) の先送り先 (2026-07-29 追加)

Q-L6 の回答で「**型 (usage 4 カウンタ + `stop_reason`) と安全弁は初期実装、記録・集計・コスト・アラートは
先送り**」が確定した。`.claude/rules/08-production-gates.md` は**対象外とする場合も理由と先送り先
(どの増分で扱うか) を書くこと**を要求するため、増分を特定する必要がある。

- **A. すべて v3 第 1 リリース前**
- **B. 明細の永続化は第 1 リリース前 / コスト算出・集計・アラートは v2 併用期間中**
- **C. すべて v2 併用期間中**
- D. Other

[Answer]: **B** — ユーザー決定 2026-07-29。根拠: 利用量明細は **append-only なので後から遡って
補完できない** (過去レビュー重大 4 と同じ論理) — 本番で課金が発生し始めた時点で明細が無いと、
後日のコスト分析・請求根拠が永久に失われる。一方、集計とアラートは既存の明細から後付けできる。

**この回答が左右するもの**: 既存 **AC-2.1 / AC-2.2 の扱い** (削除せず「先送り」と明記する。
`make check-traceability` が壊れるため) / [observability.md](../../../docs/design/observability.md) の
O-C・O-D・O-H と §3 の図 (:61) に先送り節を設ける / D-7 の増分計画。

---

## Q-L11. 移植ドメインの LLM 呼び出しを O-2 の対象に含めるか (2026-07-30 追加)

Q-L3=A により、依存規則 L-1〜L-6 の適用範囲は **v3 新規ドメインのみ** (テーマ / アセット /
会話型アイデア創出とその生成物) となった ([architecture.md](../../../docs/design/architecture.md) §3.5.2 の対象パス一覧)。
**ナレッジ・アイデアボード・お知らせ・設定は「v2 移植分」= v2 の 3 層規約のまま**であり、`gateway/` を通らない。

**すでに矛盾が発生している**: [API/README.md](../../../docs/design/API/README.md):438 は
「計測対象となる LLM 経路を **3 本**に特定」しており、**その 1 本が `POST /knowledge-files` の埋め込み生成**
([API/knowledge.md](../../../docs/design/API/knowledge.md):193 も同じ)。
つまり **API 設計は計測対象に数えているが、層規約では計測できない経路**になっている。
どちらの既存決定に寄せるかを決める必要がある。

- **A-1. 移植分も LLM 呼び出しだけは `gateway/` 経由を必須にする** — 層構成は 3 層のまま据え置き、
  変えるのは LLM を呼ぶ箇所だけ。O-2 と API 設計の両方を守れる
- **A-2. 移植分は計測対象外にする** — `API/README.md`:438 と `API/knowledge.md`:193 の「計測対象 3 本」を
  書き換え、O-2 に「移植分は対象外・先送り先」を明記する
- A-3. Other

[Answer]: **A-1** — ユーザー決定 2026-07-30。根拠: v2 の `llm/` は**そもそも usage を載せられない**
(OpenAI 実装のみ・`ctx` なし。`docs/analysis/v2-llm-inventory.md`) ため、移植先で計測したくなった時点で
結局 gateway 相当が必要になる = A-2 は「後で払う」だけ。加えて
`.claude/rules/08-production-gates.md` の O-2 は「**1 経路だけの計測は計測なしと同じ**」と定めている。

**この回答が左右するもの**: [architecture.md](../../../docs/design/architecture.md) §3.5.2 の
対象パス一覧に「**移植分でも LLM 呼び出しは `gateway/` 経由**」を**移植の受入条件として明記**する
(architecture-designer が補完済みだが、決定として裏付けが必要だった箇所) /
移植計画 (Q-9 / `docs/design/llm-migration.md`) に差し替え対象の洗い出しを含める /
AC-6.16 と AC-2.1 の適用範囲。

---

## 回答状況 (2026-07-30 時点)

**Q-L1〜Q-L11 すべて回答済み** (Q-L1〜Q-L10 は 2026-07-29、Q-L11 は 2026-07-30 のユーザー決定)。

| Q | 決定 | 影響を受ける AC |
|---|---|---|
| Q-L1 | **B** 層境界のみ `CodedError` 必須 | AC-6.11 / AC-6.17 |
| Q-L2 | **B** best-effort + 警告ログ必須 | AC-6.13 |
| Q-L3 | **A** v3 新規ドメインのみ | AC-6.14 / AC-6.19 |
| Q-L4 | **E** `dupl` 150 トークン (主) + `cyclop` 15 + `funlen` 150 行/80 ステートメント (補助) | AC-6.15 |
| Q-L5 | **A** 例外なし | AC-6.3 |
| Q-L6 | **A** Runner = Service / SDK = gateway。**計測は型と安全弁のみ初期実装** | AC-6.16 |
| Q-L7 | **B** `tx` は引数で明示・スコープはクロージャ束縛 | AC-6.7 / AC-6.8 |
| Q-L8 | **B** repository は新規ドメインのみ分割 | AC-6.3 |
| Q-L9 | **C** テンプレートは `prompts/`、構築ロジックは `service/<domain>/` | AC-6.5 |
| Q-L10 | **B** 明細は第 1 リリース前 / 集計・アラートは併用期間中 | AC-2.1 / AC-2.2 (先送り明記) / AC-6.16 |
| Q-L11 | **A-1** 移植分も LLM 呼び出しは `gateway/` 経由を必須 (2026-07-30) | AC-6.16 / AC-2.1 / AC-6.19 |

これらを [requirements-layering.md](requirements-layering.md) の AC へ反映し、
[architecture.md](../../../docs/design/architecture.md) の改訂に進む。
