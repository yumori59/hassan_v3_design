# Workflow Plan (増分: layering): architecture.md 層構成の改訂

> 対応する要件: [requirements-layering.md](requirements-layering.md) / 質問: [questions-layering.md](questions-layering.md)
> 親計画: [plan.md](plan.md) (本増分は親の Task-3f「層配置の判断基準」を**上書き改訂**する)
> 改訂対象: [architecture.md](../../../docs/design/architecture.md)
> ステータス: **完了 (2026-07-30)**。改訂 12 点 (C-L1〜C-L12) と追随タスクを全て実施し、
> **`design-reviewer` の 3 巡 (初回 → 再 → 再々) を経て重大ゼロ = Design Freeze 可**の判定を得た
> ([review-layering.md](../../reviews/productionization/review-layering.md))。
> 前提だった **Q-L1〜Q-L11 は全て回答済み** (Q-L1〜Q-L10 は 2026-07-29、Q-L11 は 2026-07-30。
> [requirements-layering.md](requirements-layering.md) §9)。
>
> **2026-07-30 追加対応 (軽微 B の解消 → 設計上の誤りの訂正)**: `di/` を層として明示した結果、
> **L-4 / L-5 が機械強制に格上げ**され (`di/**` をどの規則の `files` にも含めないので wire の誤検知が起きない)、
> 反対に **L-3 は depguard では表現できないことが判明**した (`service/**` が `repository` を一切 import しなくなるため)。
> L-3 の担保は **3 段** (①IF のメソッド ②`di/` の配線レビュー ③A-4 の CI 検査) に書き換え、
> **Q-L8 (repository のドメイン別分割) の根拠も「`di/` の配線可読性」へ差し替えた** (決定自体は維持)。
> 対応する AC: **AC-6.3 の書き換え** / **AC-6.23 の新設** (`di/` の責務定義)。
>
> **レビューで未対応のまま残した軽微事項** (Freeze を止めない。後続増分で処理する):
> ① 軽微 2 / 3 / 4 (詳細は review-layering.md の初回レビュー節)
> ② `operations.md` §7.5 への配線 — **AWS Budgets の通知経路** (AL-4 の代替。observability.md §4.6 で決定済み) と
> SSE 接続数メトリクスがデプロイ判断に使える前提の記載
>
> **実装リポの最初の PR に必ず含めるもの**: **depguard 全 18 規則 + 必須 3 ケース**
> (`service/theme` → `usecase/asset` / → sqlc 生成パッケージ / → `repository/theme`) の違反サンプル検証と、
> **`di/` からの同じ import が落ちないことの確認** (誤検知が無いことの裏取り)。
> 本レビューは「depguard の規則は独立評価される」「`**/usecase/**` が `di/` にマッチしない」を
> **文献ベースで判定**しており、実測での裏取りが残っている

## 1. この計画の性質 (先に読むこと)

改訂対象の**大半が単一ファイル ([architecture.md](../../../docs/design/architecture.md)) の編集**である。
したがって **12 点の改訂タスクは原則すべて直列**で、並列化できるのは
「architecture.md を触らない作業」だけになる (§4)。
rule 03 の「同一ファイルの編集は直列必須」に従い、**改訂は 1 セッション (または 1 エージェント) が
Wave 順に行う**。並列で 12 点を分担すると衝突する。

## 2. 影響範囲

### 2.1 設計成果物 (本リポジトリ)

| ファイル | 章 / 行 (2026-07-29 時点) | 変更内容 |
|---|---|---|
| [architecture.md](../../../docs/design/architecture.md) | §2 の D-A / D-A' / D-B'' | D-A' を C-L3 の定義に差し替え。D-B'' に C-L6 (IF 粒度) との両立を追記 |
| 同 | §3 構成図 (`:42-74`) | C-L11 で依存方向が読める図に差し替え |
| 同 | §3 責務表 (`:76-83`) | entity / gateway の行を追加。Service / UseCase / Repository の禁止事項を更新。**`prompts/<domain>/` (テンプレート) と `service/<domain>/` (構築ロジック) の分担を追記** (Q-L9=C) |
| 同 | §3 Agent サービスの内部 (`:85-97`) + A-6 / O-2 への回答 (`:99-105`) | C-L9 の関数注入方式へ差し替え。A-6 の強制点と O-2 の計測点を再定義 |
| 同 | §3 層配置の判断基準 (`:107-126`) | 決定木の「外部サービス → Service」を「→ gateway」へ、最終行を「→ entity」へ。「Service から Service を呼んでよい」を削除 |
| 同 | §3 トランザクションの受け渡し機構 (`:127-146`) | L-6 として**維持**。**ツールハンドラの型 `func(ctx, tx, args) (any, error)` を追記** (Q-L7=B。所有者スコープはクロージャ束縛のため引数に出さない) |
| 同 | §3 代表ユースケース (`:148-182`) | 15 ステップの層を新層構成に更新 (AC-6.18) |
| 同 | §5 の O-2 / O-4 / O-6 / D-2 | O-6 を「未回答」から回答へ。O-2 の計測層、O-4 のエラー契約、D-2 の依存規則検査を追記 |
| 同 | §3 に**新節 3 つ**を追加 | ①位置づけ (CA + DDD ハイブリッドと 2 逸脱。C-L10) ②横断規約 (エラー契約 / 設定値 SSOT / 監査ログ。C-L12) ③依存規則 L-1〜L-6 と CI 強制 (C-L8) |
| [observability.md](../../../docs/design/observability.md) | 決定 O-C (`:44`) / §3 の図 (`:60-62`) / §5 の O-2 行 (`:184`) / §7 引き渡し (`:203`) | 「Service 層の単一ラッパ (`AgentRunner`)」→ **呼び出し計測 = gateway / ターン集計 = `service/conversation.Runner`** へ追随 (**C-L4 と現行記述が矛盾**)。**O-C の却下案 (b)「プロキシ/ゲートウェイを挟む」は別プロセスの LLM プロキシであり、本増分の `gateway/` (同一プロセス内のパッケージ層) とは別物であることを明記**する (書かないと却下済み案の再提案に見える) |
| 同 | O-D (`:45`) / O-H (`:49`) / §3 の図 (`:53-72`) / §6 (`:194`) | **計測の先送り節を追加** (Q-L10=B): 型 (usage 4 カウンタ + `stop_reason`) と安全弁は初期実装 / **明細の永続化は v3 第 1 リリース前** / **コスト算出・集計・アラートは v2 併用期間中**。§6 の「計測は第 1 増分から入れる」(`:194`) と読み分けられる形にする |
| [auth.md](../../../docs/design/auth.md) | `:4` / `:429` / `:454` | `ToolDispatcher` 参照を C-L9 の強制点へ追随 |
| [API/README.md](../../../docs/design/API/README.md) | `:208-209` / `:437` | `AgentRunner` / `ToolDispatcher` 参照の追随 |
| [API/assets.md](../../../docs/design/API/assets.md) | `:108` (D-AS-10) / `:161-162` | 同上 |
| [API/knowledge.md](../../../docs/design/API/knowledge.md) | `:161` / `:193` | 同上 |
| [design_memo.md](../../../docs/design/design_memo.md) | `:145` (反映状況 1.) | 「D-A' は実質反映済み」の記述が本増分で無効化される → 反映状況の更新 (**ユーザーの生メモのため追記のみ・要確認**) |
| `templates/backend-repo/.claude/rules/05-architecture-coding-rules.md` (旧 `CLAUDE.md.tmpl:31-45` + `:47`) | **実施済み (2026-08-03)** — 層説明・エラー規約は本増分どおりに反映済み。**2026-08-03 に `CLAUDE.md.tmpl` から `.claude/rules/05-architecture-coding-rules.md` へ本文を切り出した** (`CLAUDE.md.tmpl` は要点 + 参照ポインタのみに圧縮)。旧懸念 (Service の旧定義・L-2 の禁止依存欠落・gateway/entity 行の欠落・直列図・`fmt.Errorf` 全面禁止) はいずれも解消済み。**実装リポ立ち上げ時はこのファイルが雛形の実体** |
| `templates/backend-repo/.github/workflows/ci.yml` | golangci-lint ステップ (**実施後の実測値: `:46-49`**。着手時点では `:41-42`) | **`templates/backend-repo/` に `.golangci*` が存在しない**ため既定ルールのみ = 層規約もサイズも検査されない → `.golangci.yml` を新規追加し (depguard **18 規則** + **`dupl` 150 / `cyclop` 15 / `funlen` 150 行・80 ステートメント**) 参照させる |
| [plan.md](plan.md) / [requirements.md](requirements.md) | Task-3f / AC-5.1 の行 | 本増分への参照を追記 (AC-5.1 の定義更新の記録) |

> **追随対象の特定方法** (実施済み 2026-07-29):
> `grep -rn "AgentRunner\|ToolDispatcher\|再利用される処理単位\|Service 層" docs/ templates/ --include='*.md' --include='*.tmpl'`
> で上表の行を洗い出した。**改訂後に同じ grep を再実行し、旧用語の残存がゼロであることを確認する** (§3 の検証方法)。

### 2.2 本番実装層 (実装リポジトリ側の影響)

本増分は設計規約の変更なので、**実装リポの全レイヤーに影響する**:

| 層 | 影響 |
|---|---|
| Controller | HTTP ステータス変換を単一箇所へ集約 (AC-6.11)。F5 の 61 箇所コピペを構造で禁止 |
| UseCase | 他ドメインのデータ取得と引数渡しの責務が増える (C-L2)。サイズ上限 lint の対象 (AC-6.15) |
| Service | パッケージをドメイン単位に切る。型名を振る舞い由来へ。外部 API 呼び出しを gateway へ移す |
| Repository | IF は UseCase 定義のまま (F7)。**v3 新規ドメインのみ `repository/<domain>/` にパッケージ分割する** (Q-L8=B) — **根拠は `di/` の配線から所有関係が読めるようにするため** (2026-07-30 差し替え。L-3 は depguard で検査できない)。移植分はフラット維持 |
| **di (層として明示)** | **全層の具体パッケージを import して依存グラフを組み立てる唯一の場所** (AC-6.23)。v2 の `provider.go` + `wire.go` + `wire_gen.go` を踏襲。**`wire_gen.go` は生成物で手編集禁止**。条件分岐による実装の切り替えを持たない (環境差は `config` で) |
| **gateway (新規)** | LLM / 検索 / ストレージ / 外部 SaaS の実装。**全 LLM 呼び出しの計測点** (AC-6.16)。**戻り型に usage 4 カウンタ + `stop_reason` を載せることは初期実装必須** (後付け不可) |
| **entity (層として明示)** | 副作用のない計算・変換・バリデーション |
| **`prompts/<domain>/` (新規)** | プロンプトのテンプレートファイル置き場 (Q-L9=C)。**D-6 の 3 者一致検査と D-E の Agent 発行スクリプトが走査する単一パス** (AC-6.5 / AC-6.9) |
| LLM / Agent 層 | Runner が tool handler を関数注入で受け取る形に変わる (AC-6.7)。**ハンドラ型は `func(ctx, tx, args) (any, error)`** (Q-L7=B)。tool 名の文字列キー検査が必要 (AC-6.9)。**安全弁 (回数・トークン・時間の打ち切り) は初期実装必須** (AC-6.16) |
| DB スキーマ | **本増分では影響なし** (層構成はスキーマに触らない)。ただし AC-2.1 の**利用量明細テーブルは v3 第 1 リリース前に必要** (Q-L10=B。設計は observability.md O-D が SSOT) |
| FE | **影響なし** (BE 内部の層構成のため) |
| CI | depguard / **`dupl` + `cyclop` + `funlen`** / tool contract check の追加 (AC-6.14 / AC-6.15 / AC-6.9)。`fmt.Errorf` 検査は**層境界の関数の戻り値のみ**が対象 (AC-6.11。Q-L1=B) |

### 2.3 本番観点 (08-production-gates)

**A-6** (ツールの越境) / **O-2** (LLM 計測の単一点) / **O-3** (安全弁は初期実装・集計は先送り) /
**O-4** (失敗の可観測性) / **O-6** (監査ログ。現行「未回答」を解消) /
**D-2** (CI ゲート) / **D-6** (schema ↔ handler の対応漏れ)。
対応表は [requirements-layering.md](requirements-layering.md) §8。
**O-2 / O-3 の一部は先送り**するため、**理由と先送り先を設計書に書くこと自体が受入基準** (AC-6.20) になる —
[08-production-gates.md](../../../.claude/rules/08-production-gates.md) は無言の省略を重大指摘とする。

## 3. 受入基準 → 検証方法

> 「設計リポでの検証」は**本増分の完了判定**、「実装リポでの検証」は**実装リポの TDD の素**
> (テストまたは CI ジョブとして先に書く対象)。

| AC | 設計リポでの検証 | 実装リポでの検証 |
|---|---|---|
| **AC-6.1** (CA+DDD ハイブリッドと 2 逸脱) | architecture.md §3 に位置づけの節があり、逸脱 2 点と v2 が `service/` を禁止している事実 (F8) への言及がある | — (規約の前文) |
| **AC-6.2** (Service = 1 ドメイン / 命名) | 責務表と定義が「1 ドメイン (集約)」になっている。`grep -n "再利用される処理単位\|再利用されているかを配置基準にしない" docs/design/architecture.md` が **0 件** | `XxxService` 型名の禁止を lint (revive の naming ルール) か code-reviewer チェックリストで検査 |
| **AC-6.3** (Service 間禁止 / 扱えるデータは自ドメインのみ) | `grep -n "Service から Service を呼んでよい" docs/design/architecture.md` が **0 件**。L-2 / L-3 が明記され、**read-only 例外なし (Q-L5=A)** と **L-3 の担保 3 段** (IF のメソッド / `di/` の配線レビュー / A-4 の CI 検査) と **`repository/<domain>/` の分割方針 (Q-L8=B。根拠は `di/` の配線可読性)** が書かれている。**「depguard で L-3 を検査する」という記述が無いこと** | depguard: `service/A` → `service/B` (L-2) と **`service/theme` → `repository/theme`** (`L4-L5-no-concrete-adapters`) の import で CI 失敗するテスト。**L-3 は depguard の対象外** — 担保はレビュー観点 (①②) と A-4 の CI 検査 (③)。**`di/` の配線レビューをコードレビューのチェックリストに入れる**ことが実装リポ側の受入条件 |
| **AC-6.4** (gateway 層 / IF は利用側定義) | 責務表に gateway 行があり、却下案として F6 (型エイリアス 20 箇所) と F7 の対比が出典付きで書かれている | depguard: `usecase/*` / `service/*` から SDK パッケージの import を deny (L-5)。gateway パッケージに IF 定義が無いことを検査 |
| **AC-6.5** (entity 層 / 判断基準の最終行 / プロンプトの置き場) | 責務表に entity 行がある。判断基準の最終行が「→ entity」。`domain/` 不採用の理由がある。**`prompts/<domain>/` (テンプレート) と `service/<domain>/` (構築ロジック) の分担と、D-6 検査 / D-E の Agent 発行が走査するパスが `prompts/<domain>/` に確定することが書かれている** (Q-L9=C)。却下案に v2 の独立 `prompt/` 方式 (`hassan-v2-backend/CLAUDE.md:34`) がある | depguard: `entity/*` が他層を import しないことを deny。entity パッケージの UT (DB 不要) が存在すること。**`prompts/` 配下に Go コードが無いこと (テンプレートファイルのみ) を CI で検査**し、構築ロジックが `service/<domain>/` にあることを確認 |
| **AC-6.6** (IF 粒度 1〜3 メソッド) | 規約が明記され、F10 が却下例として出典付きで参照されている。D-B'' の共通エンベロープとの両立が 1 文以上 | IF のメソッド数を検査する簡易スクリプト (`go/ast`) か code-reviewer チェックリスト |
| **AC-6.7** (tool の関数注入) | Runner のシグネチャと「Runner がドメインを import しない」ことが図または表にある。旧 ToolDispatcher 図が残っていない。**ハンドラ型が `func(ctx, tx, args) (any, error)` で `tx` が引数に出ている** (Q-L7=B) こととその理由 (BE-10 / BE-11 を型で防ぐ) が書かれている | Runner パッケージが `service/<domain>` / `repository` を import しないことを depguard で deny。UT: 偽のハンドラ 2 本を注入して Runner が呼ぶことを検証。**UT: 書き込みを行うハンドラが `tx` を受け取らずにコンパイルできないこと (型で担保)** |
| **AC-6.8** (A-6 の強制点) | 所有者スコープの束縛点と検証点が 1 箇所に特定され、AC-1.3 の「該当なし扱い」が維持されている。**所有者スコープがハンドラ引数ではなくクロージャ束縛である** (Q-L7=B) ことと理由 (引数にすると A-6 の強制が Runner の実装依存になる) が書かれている | UT: 他テナントの ID を LLM が返した想定でハンドラが「該当なし」を返し、**404/403 ではなく空結果**になること。ハンドラ生成関数 (ファクトリ) に所有者スコープが必須引数であることを型で担保し、**Runner のシグネチャに所有者スコープが現れないことを確認** |
| **AC-6.9** (schema ↔ handler の対応漏れ) | 検査の置き場 (起動時 / CI) と検査対象 3 種が書かれ、BE-8 / D-6 との関係が示されている | 起動時チェックの UT (schema にあって handler が無い / 逆 / 引数名不一致の 3 ケースで起動失敗)。CI: `scripts/check-tool-contract.sh` |
| **AC-6.10** (構成図の依存方向) | 図が矢印の向きを持ち、Repository / gateway が内向きであることが読み取れる。直列図が残っていない | — (図の要件) |
| **AC-6.11** (エラー型の層間契約) | 境界ごとの返却型の表がある。Controller の HTTP 変換が単一箇所 + `errors.As` と明記。**`fmt.Errorf` は「層境界を越える公開関数の戻り値では禁止・パッケージ内部の `%w` ラップは許可」と明記**され (Q-L1=B)、**CI 検査の対象が層境界の関数の戻り値に限定**されていること。却下案として v2 の全面禁止 (`hassan-v2-backend/CLAUDE.md:43`) と 113 件の違反 (F4) が出典付きで記載 | CI: **層境界パッケージの公開関数の戻り値**に対する `CodedError` 検査 (パッケージ内部の `fmt.Errorf` は検査対象外 = 誤検知を作らない)。UT: ラップされた `CodedError` が Controller で正しいステータスに変換される (F5 の取りこぼし再発防止) |
| **AC-6.12** (設定値の SSOT) | `config` の置き場と値の列挙 (タイムアウト / リトライ / モデル / 安全弁しきい値 / 生成数) がある。3 重管理の禁止が明記 | UT: しきい値を `config` から読むことを検証。CI: マジックナンバー検査 (`mnd` linter) を対象パスに適用 |
| **AC-6.13** (監査ログ失敗時の挙動) | **別トランザクションの best-effort + WARN ログとメトリクスの両方が必須**であり、**操作の種類による例外を設けない**ことが明記 (Q-L2=B)。`_ =` 無言破棄の禁止が明記。§5 の O-6 が「回答」になり observability.md §4.5 と矛盾しない | CI: `grep '_ = .*Log('` 相当の検査。UT: 監査ログ書き込み失敗時に **WARN ログとメトリクスの両方**が出て、**本処理は成功する**こと (2 つの期待を同一テストで確認) |
| **AC-6.14** (依存規則の CI 強制) | D-2 に L-1〜L-6 とツール・違反時の挙動が書かれ、`templates/backend-repo` に `.golangci.yml` が存在して `ci.yml:46-49` (D-2①⑤ ステップ) から使われる。**対象パスが v3 新規ドメインのみ (Q-L3=A) で、除外パスが AC-6.19 の一覧と一致**している | **depguard の全 18 規則それぞれ**について違反サンプルで CI が落ちることを確認 (規則ごとに 1 件。**規則を追加したらこの件数も更新する**)。**必須 3 ケース**: ① `service/theme` → `usecase/asset` (`L1-service-no-upper-layers`。無いと `service/A` → `usecase/B` → `service/B` で L-2 を迂回できる) ② `service/theme` → sqlc 生成パッケージ (`L3-no-sqlc-outside-repository`) ③ `service/theme` → `repository/theme` (`L4-L5-no-concrete-adapters`。**自ドメインでも具体パッケージへの直接依存は禁止** — IF は利用側で定義する)。**併せて `di/` からの同じ import が落ちないことを確認する** (誤検知が無いことの裏取り。`di/**` はどの規則の `files` にも含まれない)。**除外パス (v2 移植分) に同じ違反サンプルを置いて落ちないことも確認** |
| **AC-6.15** (肥大化の抜け道 + 重複 lint) | 抜け道 5 分類 (entity / gateway / service / usecase 内ファイル分割 / `prompts/`) と「共通 Service 新設禁止」が明記。**`dupl` 150 トークン (主役) / `cyclop` 15 / `funlen` 150 行・80 ステートメント (補助)** が値付きで書かれ、`funlen` を 80 行にしない理由が F15 の実測分布で記載され、雛形の `.golangci.yml` に反映されている | 3 linter が CI で有効。**同一骨格の関数を 2 つ置いて `dupl` が落ちること** / 複雑度 16 の関数で `cyclop` が落ちること / 151 行の関数で `funlen` が落ちることを規則ごとに確認。**85 行の順次呼び出し関数で落ちないこと**も確認 (誤検知しない値であることの裏取り) |
| **AC-6.16** (LLM 計測点) | 呼び出し単位 = gateway / ターン単位 = `service/conversation.Runner` が明記され、observability.md の O-C (`:44`) と**同じ層名**を指している。**O-C 却下案 (b) が別プロセスのプロキシであり `gateway/` 層とは別物である読み分け**が書かれている。**初期スコープの表 (型と安全弁 = 初期 / 明細 = 第 1 リリース前 / 集計・アラート = v2 併用期間中) がある** | CI: gateway を通らない LLM 呼び出しが存在しないことを検査 (SDK パッケージの import 箇所を 1 パッケージに限定)。UT: **gateway の戻り値が usage 4 カウンタと `stop_reason` を保持すること** / ターン集計と**安全弁の打ち切り** (回数・トークン・時間の 3 条件) |
| **AC-6.17** (LLM 失敗の区別) | `stop_reason == max_tokens` / JSON パース失敗 / タイムアウト / ツール引数不整合が型またはコードで区別され、握り潰さないことが書かれている | UT: 4 種の失敗をそれぞれ再現し、上位層で区別可能な値が返ること (BE-6 の再発防止) |
| **AC-6.18** (代表ユースケース表の更新) | **19 ステップ**の層が新層構成になり、L-1〜L-6 違反が無い (entity / gateway が現れる) | 統合テスト: 会話 1 ターンの経路が設計表の層順で動くこと |
| **AC-6.19** (2 規約の併存範囲) | 適用パスの一覧があり、CI 強制の対象 / 除外パスが対応づいている (Q-L3=A)。**AC-6.3 の repository 分割範囲 (Q-L8=B) と同一範囲であることが明記**されている | depguard の対象パス設定が一覧と一致することの目視 + 除外パスに新規ドメインが混ざっていないことの検査。**`repository/` の分割済みパス一覧と依存規則の対象パス一覧が一致することの照合** |
| **AC-6.20** (計測の先送りの明記) | observability.md の O-D / O-H / §3 の図 / §6 に、**「明細の永続化 = v3 第 1 リリース前」「コスト算出・集計・アラート = v2 併用期間中」が実施時期付きで**書かれ、**先送りの理由が項目ごと**にある (明細は append-only で後から遡れない / 集計は後付けで再計算できる)。**§6.1 が実施時期の SSOT**であり「計測は第 1 増分から入れる」の対象が ④⑤ であると読み分けられる。**加えて先送りされないものが明示されている** — メトリクス基盤と失敗系 warn メトリクス (⑧) は初期実装で、**§4.6 の AL-1〜AL-7 が ⑦ / ⑧ のどちらかに割り当てられている** | 実装リポの検証対象は AC-6.16 の「型と安全弁」+ **⑧ の失敗系メトリクス**(明細・利用量集計は後続増分のため本増分ではテストを持たない)。**先送り分は実装リポの issue として起票されていること**を引き渡し条件にする。**⑧ の混同が O-4 / O-6 / A-6 の初回欠落に直結する**ため、⑧ の記述の有無を Freeze 条件に含める |
| **AC-6.21** (ツール結果のフィールド契約。BE-12) | ハンドラの戻り値が「ツールごとに 1 箇所で宣言した型」であること・読み手が独自構造体を定義しないこと・テストが合成 JSON を手書きしないこと・**§3.8.4 の 3 者一致検査が戻り値スキーマにも及ぶこと**の 4 点が architecture.md にあり、`ci.yml` の D-6 ステップの説明が追随している | 実装リポで**読み手・書き手・テストが同一の型定義を参照していることを検査**する (PoC の実例と同型の不整合 — 読み手が `finding` を期待し書き手に無い — を注入して落ちることを確認)。**`grep -rn "BE-12"` が architecture.md にヒットする**ことを doc 側の最低条件にする |
| **AC-6.22** (移植分の LLM 呼び出しも gateway 経由。Q-L11=A-1) | §3.5.2 の適用範囲に「移植分は 3 層のままだが LLM 呼び出しだけは `gateway/` 経由必須」が**移植の受入条件**として書かれ、`API/README.md:438` の計測対象 3 本との矛盾が解消していること。移植計画への申し送りがあること | **移植ドメインの LLM 呼び出し経路を列挙し、すべてが gateway を通ることを検査**する (実装リポ)。設計側は `grep -rn "Q-L11" docs/design/architecture.md` がヒットし、§3.5.2 の運用ルールに受入条件として現れることを確認 |
| **AC-2.1 / AC-2.2** (既存。実施時期を先送り) | 親 [requirements.md](requirements.md) の AC を**削除・改番せず**、[requirements-layering.md](requirements-layering.md) §7 に先送りの時期と理由が記録されていること。**型の要件 (usage / `stop_reason`) は初期から満たす** | AC-2.1 の型部分は AC-6.16 の UT で検証。明細永続化・集計・アラートは後続増分の検証対象 |
| **AC-5.1** (既存。定義を更新) | 上記 AC-6.1〜AC-6.23 の反映後、AC-5.1 の要求 (責務境界 + 禁止依存 + 代表ユースケース 1 本) が新層構成で満たされていること。`make check-traceability` が AC-5.1 のカバーを維持 | (親 requirements.md のとおり) |

## 4. タスクと依存関係

### Wave 0: 前提 (直列)

- [x] **Task-L0a** (完了 2026-07-29): **Q-L1〜Q-L10 の回答取得** ← ユーザー判断。
      証跡は [questions-layering.md](questions-layering.md) の各 `[Answer]:` 行、
      決定一覧は [requirements-layering.md](requirements-layering.md) §9。
      **暫定既定の採用は 1 件も無い** (全問がユーザー決定で確定)
- [x] **Task-L0b** (完了 2026-07-29): 旧用語の全出現箇所の棚卸し (§2.1 の grep) → 追随対象を §2.1 の表に確定

### Wave 1: 層の定義 (architecture.md。直列)

- [x] **Task-L3** (C-L3 / C-L7 → **AC-6.2**): §2 の D-A' と §3 の Service 定義を「1 ドメイン (集約) に閉じた
      ビジネスロジック」へ差し替え。ドメイン名パッケージ / 振る舞い命名 (例 3 つ) を追記。
      旧定義 2 文を**削除** ← `architecture-designer`
- [x] **Task-L5** (C-L5 → **AC-6.5**): 責務表に entity の行を追加。判断基準の最終行を「→ entity」に変更。
      `domain/` 不採用の理由を記載 ← `architecture-designer`
- [x] **Task-L26** (Q-L9=C → **AC-6.5** / **AC-6.9**): プロンプトの置き場を記載 —
      **テンプレートファイル = `prompts/<domain>/` / 構築ロジック = `service/<domain>/`**、
      D-6 の 3 者一致検査と D-E ([architecture.md](../../../docs/design/architecture.md):29) の
      Agent 発行が走査するパスが `prompts/<domain>/` に確定すること、
      却下案 (v2 の独立 `prompt/` = `hassan-v2-backend/CLAUDE.md:34`) ← `architecture-designer`
      (**Task-L5 と同じ責務表・同じ決定木を触るため Wave 1 の 1 回の編集に含める**)
- [x] **Task-L4** (C-L4 → **AC-6.4**): 責務表に gateway の行を追加。判断基準の「外部サービス → Service」を
      「→ gateway」に変更。却下案に F6 / F7 の対比を記載 ← `architecture-designer`

> Wave 1 の 4 点 (Task-L3 / L5 / L26 / L4) は**同じ責務表と同じ決定木を触る**ため、1 回の編集で
> まとめて行う。分割すると同一表の 4 回書き換えになる。

### Wave 2: 依存規則 (Wave 1 完了後)

- [x] **Task-L1L2** (C-L1 / C-L2 / Q-L5=A → **AC-6.3**): 「Service から Service を呼んでよい」を削除し、
      L-2 / L-3 を明記。他ドメインのデータは UseCase が引数で渡すことを追記。
      **read-only の横断参照も例外にしない**ことと理由 2 点 (C-L1 が Repository 経由で無効化される /
      depguard は read-only を静的判定できない) を記載 ← `architecture-designer`
- [x] **Task-L25** (Q-L8=B → **AC-6.3** / **AC-6.14** / **AC-6.19**): **`repository/` のパッケージ分割方針**を記載 —
      v3 新規ドメインのみ `repository/<domain>/` に分割 / 移植分はフラット維持
      (`hassan-v2-backend/repository/` は 31 ファイルが単一パッケージ) /
      **分割は L-3 を depguard で検査するための前提条件**であり、分割しない範囲では L-3 が
      機械強制されずレビュー対象になること / 却下案 (全面分割 = 移植コードの import 書き換えが前提条件になる)
      ← `architecture-designer`
- [x] **Task-L6** (C-L6 → **AC-6.6**): IF 粒度の規約を新設し、F10 を却下例に。D-B'' に共通エンベロープとの
      両立を 1 文追記 ← `architecture-designer`
- [x] **Task-L15** (F3 の再発防止 / Q-L4=E → **AC-6.15** の設計側): 抜け道 5 分類と
      「共通 Service 新設禁止」を明記。**lint は `dupl` 150 トークン (主役) / `cyclop` 15 /
      `funlen` 150 行・80 ステートメント (補助)** とし、`funlen` を 80 行にしない理由を
      **F15 の実測分布 (非テスト関数 573 個 / 80 行以上 40 個 = 7.0% / 150 行以上 21 個 = 3.7%)** で記載。
      **ファイル行数の上限を設けない理由**も併記 ← `architecture-designer`

### Wave 3: Agent とツール実行 (Wave 1・2 完了後)

- [x] **Task-L9** (C-L9 / Q-L6=A / Q-L7=B → **AC-6.7** / **AC-6.8** / **AC-6.9**):
      §3「Agent サービスの内部」を関数注入方式へ差し替え。
      **ツールループ・停止条件・安全弁・所有者スコープ強制 = `service/conversation.Runner` /
      SDK 呼び出し・SSE 受信・usage 抽出 = `gateway/anthropic`** の分割を記載。
      **ハンドラ型 `func(ctx, tx, args) (any, error)`** (`tx` は引数・所有者スコープはクロージャ束縛) と
      それぞれの理由を記載。A-6 の強制点を再定義。tool 名の文字列キー検査を追記
      ← `architecture-designer` (**前提: Wave 1 の gateway 定義**)
- [x] **Task-L16** (O-2 / Q-L6 / Q-L10=B → **AC-6.16** / **AC-6.20** の architecture.md 側):
      計測点 (呼び出し単位 = gateway / ターン単位 = Runner) を明記し、§5 の O-2 を更新。
      **初期スコープの線引き** (型 = usage 4 カウンタ + `stop_reason` と安全弁は初期実装 /
      明細の永続化は v3 第 1 リリース前 / コスト算出・集計・アラートは v2 併用期間中) と
      **項目ごとの先送り理由**を記載。**先送り先の SSOT は observability.md** とし相互参照を張る。
      **前提: Task-L9** ← `architecture-designer`

- [x] **Task-L28** (design-reviewer 重大 4 → **AC-6.21**): **ツール結果のフィールド契約 (BE-12)** を
      architecture.md に追記 — ハンドラの戻り値型の単一宣言 / 読み手が同じ型定義から読むこと /
      テストが合成 JSON を手書きしないこと / §3.8.4 の 3 者一致検査を**戻り値スキーマへ拡張**。
      `templates/backend-repo/.github/workflows/ci.yml` の D-6 ステップの説明も追随させる。
      **前提: Task-L9** ← `architecture-designer`

### Wave 4: 横断規約 (Wave 1〜3 と独立に書けるが同一ファイルのため直列)

- [x] **Task-L12a** (C-L12 ① / Q-L1=B → **AC-6.11** / **AC-6.17**): エラー型の層間契約の表を新設。
      Controller の HTTP 変換の単一化 + `errors.As`。LLM 失敗 4 種の区別。
      **`fmt.Errorf` は層境界の戻り値でのみ禁止 (内部の `%w` ラップは許可)** と、
      **CI 検査対象を層境界の関数の戻り値に限定**することを記載。
      却下案に v2 の全面禁止 (`hassan-v2-backend/CLAUDE.md:43` / F4 の 113 件) ← `architecture-designer`
- [x] **Task-L12b** (C-L12 ② → **AC-6.12**): 設定値の SSOT (`config`) を新設。
      O-3 の安全弁しきい値を含む値の列挙。3 重管理の禁止 (BE-2) ← `architecture-designer`
- [x] **Task-L12c** (C-L12 ③ / Q-L2=B → **AC-6.13**): 監査ログ失敗時の挙動を定義し §5 の O-6 を「回答」に更新。
      **別トランザクションの best-effort + WARN ログとメトリクスの両方が必須**、
      **操作の種類による例外を設けない**ことを記載 ← `architecture-designer`

### Wave 5: 統合 (すべての決定が固まった後。直列)

- [x] **Task-L8** (C-L8 / Q-L3=A / Q-L4=E / Q-L8=B → **AC-6.14** / **AC-6.19**):
      L-1〜L-6 の CI 強制と `dupl` / `cyclop` / `funlen` を §5 の D-2 に追記。
      2 規約の併存範囲と**対象パス一覧 (v3 新規ドメイン) / 除外パス一覧 (v2 移植分)** を記載し、
      **Task-L25 の repository 分割範囲と同一であることを明記**。
      **前提: Wave 2 完了 (Task-L1L2 / L25 / L15)** ← `architecture-designer`
- [x] **Task-L18** (Q-L7=B → **AC-6.18**): 代表ユースケース (会話 1 ターン。旧 15 → **19 ステップ**) の層を新層構成へ更新。
      各ステップが L-1〜L-6 に違反しないことを確認。**ステップ 12 (台帳 write-through) と
      13 (生成物の採番) は `tx` を引数で受け取るハンドラ**として層配置する。
      **前提: Wave 1〜4 完了** ← `architecture-designer`
- [x] **Task-L10** (C-L10 → **AC-6.1**): 位置づけの節 (CA + DDD ハイブリッド / 2 逸脱 / F8 との関係) を追加。
      **前提: 層集合の確定 (Wave 1)** ← `architecture-designer`
- [x] **Task-L11** (C-L11 → **AC-6.10**): 構成図を依存方向が読める形に差し替え。
      **前提: 他の全決定 (Wave 1〜5 の他タスク) が固まった後** — 図は最後 ← `architecture-designer`

### Wave 6: 追随と引き渡し

- [x] **Task-L20**: [observability.md](../../../docs/design/observability.md) の追随 —
      **O-C (`:44`) / §3 の図 (`:60-62`) / §5 の O-2 行 (`:184`) / §7 (`:203`)** の
      「Service 層の単一ラッパ (`AgentRunner`)」を**呼び出し計測 = gateway / ターン集計 = Runner** へ。
      **併せて O-C の却下案 (b)「プロキシ/ゲートウェイを挟む」は別プロセスの LLM プロキシであり、
      本増分の `gateway/` (同一プロセス内のパッケージ層) とは別物であることを O-C の欄に明記**する
      (書かないと却下済み案の再提案に見え、レビューで矛盾指摘になる)。
      **前提: Task-L16** ← 起草セッション (**observability.md の起草者と同一セッションが望ましい**)
- [x] **Task-L27** (Q-L10=B → **AC-6.20**): [observability.md](../../../docs/design/observability.md) に
      **計測の先送り節を追加** — O-D (`:45`) / O-H (`:49`) / §3 の図 (`:53-72`) / §6 (`:194`) に
      「型 (usage 4 カウンタ + `stop_reason`) と安全弁 = 初期実装」「**明細の永続化 = v3 第 1 リリース前**」
      「**コスト算出・集計・アラート = v2 併用期間中**」を実施時期付きで記載し、
      **項目ごとの先送り理由** (明細は append-only で後から遡って補完できない / 集計は既存明細から
      後付けで再計算できる) を書く。§6 の「計測は第 1 増分から入れる」(`:194`) と読み分けられる形にする。
      **前提: Task-L16 / Task-L20 (同一ファイルのため Task-L20 と同一セッションで実施)** ← 起草セッション
- [x] **Task-L21**: [auth.md](../../../docs/design/auth.md) と [API/](../../../docs/design/API/) 3 ファイルの
      `AgentRunner` / `ToolDispatcher` 参照の追随。**前提: Task-L9** ← 起草セッション
- [x] **Task-L22**: `templates/backend-repo` の更新 ← 手動。**前提: Task-L8 / Task-L12a / Task-L25**
      1. `CLAUDE.md.tmpl:31-45` の層説明を差し替え — **図 (`:34`) に gateway / entity を追加**、
         **Service の定義 (`:41`) を「1 ドメイン (集約) に閉じたビジネスロジック」へ**、
         **禁止依存 (`:45`) に `service`→`service` (L-2) と `service`→他ドメイン `repository` (L-3)・
         `gateway`→上位層 (L-4) を追加**、**`prompts/<domain>/` の位置づけを追記**
      2. `CLAUDE.md.tmpl:47` のエラー規約を **「層境界では `CodedError` 必須 / パッケージ内部は `%w` 可」**へ
         (現行は v2 の全面禁止方式のまま)
      3. **`.golangci.yml` の新規追加** — depguard **18 規則** (L-1〜L-6 を表現。L-ID と規則名は 1 対 1 ではない。
         **実施後の最終値は 18** — レビュー指摘の中 A で `gateway/**` を `L3-no-sqlc-outside-repository` の
         対象に加えたぶんを含む) +
         **`dupl` (150 トークン) / `cyclop` (15) / `funlen` (150 行・80 ステートメント)**。
         対象パスは AC-6.19 の一覧、除外パスは v2 移植分
      4. `ci.yml` の golangci-lint ステップ (**実施後: `:46-49` の D-2①⑤**) から `.golangci.yml` を参照させる
- [x] **Task-L23**: [plan.md](plan.md) / [requirements.md](requirements.md) / [design_memo.md](../../../docs/design/design_memo.md):145 の
      反映状況の更新 (親計画 Task-3f の上書きを記録)。**design_memo.md はユーザーの生メモのため追記のみ・要確認** ← 手動
- [x] **Task-L24**: 別セッションで `design-reviewer` (AC-4.2)。
      結果は `aidlc-docs/reviews/productionization/review-layering.md` へ。
      **前提: Wave 5 完了 + Task-L20 / L27 / L21 完了** (レビューは差分全体を 1 セッションで見る)

## 5. 着手順序の根拠 (Q-L 待ちは解消済み)

**Q-L1〜Q-L10 は 2026-07-29 に全て回答済み**なので、**「回答待ちで着手できないタスク」は存在しない**。
着手順序を決めるのは**成果物間の依存**だけである (下表)。各タスクが持ち込む決定は
[requirements-layering.md](requirements-layering.md) §9 の表が SSOT。

| タスク | 前提 (成果物間の依存) | 依存の理由 |
|---|---|---|
| Task-L3 / L5 / L26 / L4 (Wave 1) | **なし** — 最初に着手する | 層の集合 (Controller / UseCase / Service / Repository / gateway / entity / `prompts/`) が決まらないと、以降の規則が参照する層名が定まらない |
| Task-L1L2 / L25 / L15 / L6 (Wave 2) | Wave 1 | 依存規則は層名を前提にする。L-3 の表現は Task-L25 の repository 分割方針に依存する |
| Task-L9 (Wave 3) | Wave 1 の gateway 定義 | Runner と gateway の責務分割を書くため。**Q-L6 が解消した矛盾** (現行 observability.md の「Service 層の単一ラッパ」と C-L4) を固定する箇所なので、Wave 1 の gateway 定義より後 |
| Task-L16 (Wave 3) | Task-L9 | 計測点は Runner / gateway の責務分割の上に載る |
| Task-L12a / L12b / L12c (Wave 4) | 同一ファイル (architecture.md) のため Wave 3 の後 | 決定自体は独立。編集の衝突回避のみが理由 |
| Task-L8 (Wave 5) | Wave 2 完了 (L-1〜L-6 と repository 分割範囲の確定) | CI 強制の対象パス一覧は、依存規則と分割範囲が確定してからしか書けない |
| Task-L18 (Wave 5) | Wave 1〜4 完了 | 代表ユースケース表は全層・全規則の帰結を並べるため最後 |
| Task-L11 (Wave 5) | Wave 5 の他タスク完了 | 図は決定の帰結。先に描くと描き直しになる |
| Task-L20 / L27 (Wave 6) | Task-L16 | observability.md の追随は計測点の確定後。**L20 と L27 は同一ファイルのため同一セッションで実施** |
| Task-L21 (Wave 6) | Task-L9 | `AgentRunner` / `ToolDispatcher` の後継名が決まってから |
| Task-L22 (Wave 6) | Task-L8 / L12a / L25 | `.golangci.yml` の内容 (対象パス・除外パス・linter 値) が確定してから |
| Task-L24 (レビュー) | Wave 5 + Task-L20 / L27 / L21 | 差分全体を 1 セッションで見る (rule 04) |

**Q-L6 が解消した矛盾の扱い** (着手時の注意): 現行の observability.md (`:44` / `:60-62` / `:184` / `:203`) と
[API/](../../../docs/design/API/) 3 ファイル・[auth.md](../../../docs/design/auth.md) は
「Service 層の `AgentRunner`」「`ToolDispatcher`」を前提に書かれている。
**architecture.md だけを改訂して Task-L20 / L21 を後回しにすると、リポジトリ内に 2 つの計測層が併記された
状態が残る** — Task-L24 (レビュー) の前に必ず消化する (§7 の完了条件 2)。

## 6. 並列実行可能なタスク

| 系列 | 並列可能なもの | 直列必須の理由 |
|---|---|---|
| A (architecture.md) | **なし** — Wave 1 → 2 → 3 → 4 → 5 は直列 | **同一ファイルの編集** (rule 03) + 決定の依存 (層定義 → 依存規則 → Agent → 図) |
| B (雛形) | **Task-L22** を系列 A の Wave 5 (Task-L8) 完了後に並列実行可 | 別リポジトリ雛形のファイルなので A の完了は待たないが、**対象パス一覧と linter 値が確定する Task-L8 / L12a / L25 より後**でなければ書き直しになる |
| C (追随) | **Task-L21** は **Task-L20 / L27** と並列可 (別ファイル) | Task-L20 と L27 は**同一ファイル (observability.md) のため相互には直列**。いずれも A の Task-L9 / L16 の確定後 |
| D (記録) | **Task-L23** は A と並列可 | 触るのは plan.md / requirements.md / design_memo.md |
| レビュー | **なし** — Task-L24 は集約する | レビューは差分全体を 1 セッションで見る (rule 04) |

**推奨する実行形**: Wave 1 から直列で A を進め、Task-L8 完了時点で Task-L22 (雛形) を別担当へ出す。
Task-L20 / L27 (observability.md) は 1 セッションでまとめ、Task-L21 (auth.md / API 3 ファイル) と並列に走らせる。
**Task-L0a (回答取得) は完了済みのため待ちが無い** (§5)。

## 7. 完了の定義 (本増分の Design Freeze)

1. `make check` が通る (リンク切れ・参照先不在ゼロ / AC 未カバーゼロ — **AC-6.1〜AC-6.23 を含む**)
2. §2.1 の追随対象すべてが更新され、
   `grep -rn "AgentRunner\|ToolDispatcher\|再利用される処理単位\|Service 層の単一ラッパ" docs/ templates/` の
   **残存がゼロ** (意図的に歴史的経緯として残す場合は「旧称」と併記して明示する)
3. **Q-L1〜Q-L10 の決定が requirements-layering.md §9 と各 AC に反映済み** (2026-07-29 に全問回答済み。
   暫定既定の採用は無い)
4. [08-production-gates.md](../../../.claude/rules/08-production-gates.md) の
   **A-6 / O-2 / O-3 / O-4 / O-6 / D-2 / D-6** に本増分の回答が入っている (§2.3)。
   **先送りする O-2 / O-3 の一部 (明細永続化・コスト算出・集計・アラート) は理由と先送り先が
   書かれている** (AC-6.20 — 無言の省略は重大指摘)
5. 別セッションの `design-reviewer` レビューで重大事項ゼロ
   (`aidlc-docs/reviews/productionization/review-layering.md`)
6. 実装リポへの引き渡し情報が揃っている: **§3 の「実装リポでの検証」列が、depguard 規則 6 本・
   golangci 設定 (`dupl` / `cyclop` / `funlen`)・tool contract 検査・UT の一覧として
   `templates/backend-repo` に反映されている**
7. **先送り分 (AC-2.1 の明細永続化 = v3 第 1 リリース前 / AC-2.2 の集計・アラート = v2 併用期間中) が
   引き渡し情報に含まれている** — 実装リポの issue として起票できる粒度で書かれていること
