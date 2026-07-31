# テスト戦略 (段・層・LLM 経路・テナント越境・E2E)

> 本書が回答する本番観点: **D-2** (段の割り当てのみ。ゲート内容は再定義しない) / **A-4** / **A-6** /
> **O-4** / **A-1・A-5・O-5** (部分) / 対応 AC: **AC-5.2** / ユーザー制約: **C-8** (TDD・CI で UT と lint を機械強制)
> 前提とする事実: [architecture.md](architecture.md) §3 (6 パッケージ層・L-1〜L-6・Agent 実行の 3 層分割) /
> [auth.md](auth.md) §6.4〜§6.6 / [observability.md](observability.md) §4.2〜§4.4 /
> 必須観点の ID 一覧: [08-production-gates.md](../../.claude/rules/08-production-gates.md)

本書は **「何を・どの層で・どうテストするか」** を確定させる。
[design_memo.md](design_memo.md) の「結合テストやりたい — playwright」に対する設計上の回答が本書である。

## 0. 本書の位置づけと SSOT 境界

**本書は次を再定義しない**。参照し、「テストでどう担保するか」だけを書く。

| 事項 | SSOT |
|---|---|
| **いつテストを書くか** (Red → Green → Refactor・Red の受理条件) | [01-construction-loop.md](../../templates/shared/.claude/rules/01-construction-loop.md) §2 + [test-driven-development/SKILL.md](../../templates/shared/.claude/skills/test-driven-development/SKILL.md) |
| **モック・テストダブルの禁じ手** | [testing-anti-patterns.md](../../templates/shared/.claude/skills/test-driven-development/testing-anti-patterns.md) |
| **CI ゲートの内容とマージ条件** | [01-construction-loop.md](../../templates/shared/.claude/rules/01-construction-loop.md) §7 + [architecture.md](architecture.md) §5 の D-2 + [ci.yml](../../templates/backend-repo/.github/workflows/ci.yml) |
| **DoD の機械検証項目 (V-1〜V-10)** | [02-issue-granularity.md](../../templates/shared/.claude/rules/02-issue-granularity.md) §3.1 |
| **LLM 出力の品質評価** (ゴールデンセット 20 件・ブラインド A/B・合否) | **[llm-migration.md](llm-migration.md) §8** — 本書の対象外 |
| テナント境界の規約 (所有者列・クエリ条件・401/403/404) | [auth.md](auth.md) §6.3〜§6.6 |
| 計測項目・失敗 5 分類・安全弁のしきい値 | [observability.md](observability.md) §4.2〜§4.4 |
| 環境・シークレットの経路 | [operations.md](operations.md) §3 / §4 |
| **FE の構造・依存規則 (L-F1〜L-F6)・トークン体系・機械検査の中身** | **[frontend.md](frontend.md) §3.3 / §7.2 / §8.2 / §11.2.3 / §12** — 本書は**それらを段に割り当て、PR の必須チェックかどうかを宣言するだけ** (§9.1.1)。検査の内容そのものを再定義しない |

**本書が新規に決めるのは**: 段の集合と境界 (§3) / 層ごとのモック境界 (§4) / LLM 経路の再現方法 (§5) /
越境テストの必須範囲 (§6) / E2E の対象・環境・タイミング (§7) / テストデータ (§8) / 段の CI 割り当て (§9) /
カバレッジの扱い (§10)。

---

## 1. 現状 (v2 / PoC) — 事実

### 1.1 v2 backend

| # | 事実 | 出典 |
|---|---|---|
| T-F1 | テストファイルは **114 件** (vendor・worktree を除く)。非テスト Go ファイルは **1715 件** | 実測 `find . -path ./vendor -prune -o -path ./.worktrees -prune -o -name '*_test.go' -print \| wc -l` |
| T-F2 | **DB を伴うテストが 1 件も無い** — `pgxmock` / `sqlmock` / `dockertest` / `testcontainers` の import が **0 件**、`_test.go` 内の `DATABASE_URL` / `pgxpool` 参照も **0 件** | 実測 grep (非テストコード・vendor・worktree を除外) |
| T-F3 | **`repository/` 配下のテストは 0 件** — SQL が実際に所有者条件で絞るかを検証する経路が存在しない | 実測 `find repository -name '*_test.go' \| wc -l` → 0 |
| T-F4 | UseCase のテストは**手書きスタブ**で行う。1 つのスタブが Repository IF の全メソッドを実装させられ、テストに使わないメソッドが no-op で並ぶ | `hassan-v2-backend/usecase/idea_board/repository_stubs_test.go`、`hassan-v2-backend/usecase/theme/list_themes_test.go:16`〜`:57` |
| T-F5 | `httptest` は**外部 HTTP クライアントのテストにのみ**使われ、**gin ハンドラのテストには使われていない**。`controller/` 配下のテストは validator と DTO の 3 件のみ | `hassan-v2-backend/llm/exa/client_test.go` / `hassan-v2-backend/ogp/client_test.go` / 実測 `find controller -name '*_test.go'` → `custom_validator_test.go`・`dto/idea_test.go`・`dto/idea_board_test.go` |
| T-F6 | CI は **PR (base=main) で `go test -race -coverprofile` のみ**。lint ジョブが無い (F9 と一致)。カバレッジは Codecov に送るが **`fail_ci_if_error: false`** で**しきい値による強制が無い** | `hassan-v2-backend/.github/workflows/test.yml:4`〜`:5`・`:31`・`:36`〜`:40` |
| T-F7 | マスタデータの seed が 1 ファイルで用意されている (`auth_roles` / `admin_auth_roles` 等) | `hassan-v2-backend/db/seeds/initial_data.sql:9`〜`:18` |
| T-F8 | DB 拡張は **`uuid-ossp` のみ** | `hassan-v2-backend/db/schema.sql:1` |

### 1.2 v2 frontend

| # | 事実 | 出典 |
|---|---|---|
| T-F9 | **CI が存在しない** — リポジトリ直下に `.github/` ディレクトリが無い (実測 `ls -a` / `ls .github` はエラー) | 実測 (hassan-v2-frontend のリポジトリ直下) |
| T-F10 | **単体テストのフレームワークが無い** — `package.json` の scripts に `test` が無く (`e2e` / `tsc` / `lint` / `storybook` のみ)、`vitest` / `jest` も依存に入っていない。テストは **Playwright の E2E 2 本だけ** | `hassan-v2-frontend/package.json:8`〜`:23` (scripts ブロック全体) |
| T-F11 | Playwright は **`setup` プロジェクトでログインし `storageState` を保存 → `chromium` プロジェクトが `dependencies: ['setup']` で再利用**する構成。`baseURL` は `PLAYWRIGHT_BASE_URL` (既定 `http://localhost:3000`) | `hassan-v2-frontend/playwright.config.ts` |
| T-F12 | ログインは UI 操作で行い、資格情報は `E2E_LOGIN_EMAIL` / `E2E_LOGIN_PASSWORD` / **`E2E_MFA_CODE` (固定文字列)** を環境変数で受け取る | `hassan-v2-frontend/e2e/auth.setup.ts:5`〜`:8`・`:32` |
| T-F13 | **E2E が対象データを見つけられないと `test.skip` で自分をスキップして緑になる** (2 箇所)。前提データの不在が失敗にならない | `hassan-v2-frontend/e2e/idea/idea-history-edit.spec.ts:33`・`:37` |

### 1.3 PoC (claude_managed_agents)

| # | 事実 | 出典 |
|---|---|---|
| T-F14 | Go テスト **126 ファイル**、frontend テスト **157 ファイル** (vitest) | 実測 `find` |
| T-F15 | CI は **PostgreSQL を起動しない**。`go test` は `DATABASE_URL` 未設定のインメモリ経路を前提にしている (BE-5) | `claude_managed_agents/.github/workflows/ci.yml:27`〜`:30` |
| T-F16 | DB ストアのテストは **nil プールのときの no-op 契約**だけを固定し、「実 DB を伴う統合テストは testcontainer 等で別途実施 (本 PoC 範囲外)」とコメントで明記されている | `claude_managed_agents/internal/db/idea_status_store_test.go:8`〜`:10` |
| T-F17 | **BE-12 の実害はテストが合成 JSON を手書きしていたことで隠れた** — 読み手のテストが `{"finding":"...","notes":"要確認"}` を直書きしており、書き手が `finding` を持たず `notes` が `[]string` である事実と食い違ったまま緑になる | 読み手 `claude_managed_agents/cmd/devui/conversation_plan_grounding.go:100`〜`:103` / 書き手 `claude_managed_agents/cmd/devui/conversation_tools_deepdive.go:168`〜`:176` / **テスト** `claude_managed_agents/cmd/devui/conversation_plan_grounding_test.go:32`・`:98`・`:121` |

### 1.4 事実からの含意 (本書の出発点)

1. **v2 は「SQL とテナント境界が最もテストされていない」**。T-F2 / T-F3 により、
   [auth.md](auth.md) §5-1 (IDOR) / §5-7 (UUID 直読み) / §6.4 の F-15 (存在確認だけで契約未検証) は
   **テストで検出できる状態になかった**。v3 で最初に埋めるべき穴はここである (§6)。
2. **v2 frontend にはテストの土台が無い** (T-F9 / T-F10)。Playwright だけがあり、CI で回っていない。
   v3 の FE テストは**新規に立てる**必要がある (v2 から継承できない)。
3. **v2 の E2E は「緑でも何も保証しない」形になっている** (T-F13)。v3 は self-skip を禁止する (§8)。
4. **PoC の CI は DB を持たない前提で組まれている** (T-F15 / T-F16)。v3 は統合段を持つため、
   この前提を持ち込まない。
5. **カバレッジ数値は既に v2 で「集めるだけ」になっている** (T-F6)。同じことを繰り返さない (§10)。

---

## 2. 設計判断

> 本節が回答する ID: **C-8, AC-5.2** (段と機械強制の全体像)

| # | 論点 | 採用案 | 却下案と理由 |
|---|---|---|---|
| **T-A** | 段の集合 | **4 段: U (単体) / I (統合・実 DB) / C (契約) / E (E2E・Playwright)**。段の境界は「何を担保しないか」で切る (§3.1) | (a) **U + E の 2 段**: v2 の実害 (T-F3) がある SQL・所有者条件は U では見えず、E では他テナントの ID を得る手段が無いため**構造的に検証不能**な穴が残る。(b) **U / I / E の 3 段** (契約を段にしない): OpenAPI・tool schema・`entity/toolresult` のズレは「実行しても緑になる」種類の欠陥 (BE-8 / BE-12 / FE-2) で、振る舞いテストでは捕まらない。(c) **段を 5 つに増やし FE のコンポーネントテストを独立段にする**: 実行環境と担保範囲が U と同じ (jsdom・実 DB なし) で、境界が「何を担保しないか」で切れない |
| **T-B** | Repository の検証方法 | **実 PostgreSQL を使う** (CI の `services: postgres` — [ci.yml](../../templates/backend-repo/.github/workflows/ci.yml):17〜26 に既にある) | (a) **`sqlmock` で SQL 文字列を照合**: 「`WHERE account_id = $1` という文字列があるか」は見えるが、**実際に行が絞られるか**は見えない。[auth.md](auth.md) §6.4 の F-15 は「クエリは正しいのに呼び出し側が越境していた」実例であり、文字列照合はこれを通す。(b) **`testcontainers` / `dockertest`**: 起動制御はできるが、CI では `services` で同じことができ、依存が 1 つ増える。ローカルでの起動は `docker compose` で足りる。(c) **Repository をテストしない (v2 の現状)**: T-F3 がそのまま v3 に来る |
| **T-C** | モックの境界 | **テストダブルに差し替えてよいのは「利用側が定義した repository IF / gateway IF」だけ**。`entity/` と `service/` は常に実物、SQL は実 DB (§3.2) | (a) **層ごとに直下をモックする**: `usecase` のテストで `service` をモックすると、L-2 / L-3 を守るために UseCase に集まった協調ロジック (§3.9⑤) がまるごと未検証になる。(b) **何もモックせず全部実物 (外部 API も)**: LLM を毎テスト叩くことになり、時間・コスト・非決定性で U 段が成立しない。(c) **モック生成ツール (mockery / gomock) を導入**: v2 に前例が無く生成物が増える。[architecture.md](architecture.md) §3.6 が IF を 1〜3 メソッドに縛るため**手書きの方が短い** (T-F4 の巨大スタブは v2 の巨大 IF の帰結であり、IF が小さければ再発しない) |
| **T-D** | LLM を叩かない担保 | **`gateway` IF (利用側定義の小さい IF) をテストダブルに差し替える**。差し替え点は **1 つだけ** | (a) **Anthropic SDK をモックする**: SDK の型が `service` / `usecase` のテストに漏れ、L-5 (外部型を上位層に出さない) をテストが破る。(b) **HTTP レベルの録画再生 (VCR 方式)**: 記録の更新が手作業になり、`stop_reason` や usage を任意に変えた異常系 (§5.4) を作れない。(c) **CI で実 LLM を叩く**: 非決定性・コスト・外部障害で赤くなる。実 LLM は E 段と [llm-migration.md](llm-migration.md) §8 の品質評価に限る |
| **T-E** | BE-12 (読み手・書き手・テストの契約不一致) の潰し方 | **`entity/toolresult` の Go 型を単一の SSOT とし、テストは型を組み立てて `json.Marshal` する**。加えて**型から生成した golden ファイル** (`testdata/golden/toolresult/<tool>.json`) を置き、**読み手のテストは golden を入力に使う** (§5.3) | (a) **golden ファイルのみ**: golden を**手書き**すると T-F17 と同じ状態になる (「golden」という名前の合成 JSON)。生成された golden でなければ意味がない。(b) **JSON Schema を SSOT にして Go 型を生成**: ツールが増え、しかも tool の**入力**スキーマ (Anthropic に登録するもの) と**出力**型で SSOT が 2 つになる。(c) **CI 検査だけに任せる** (`check-tool-contract.sh`): 読み手が独自構造体を作らないことは検査できるが、**テスト内の手書き JSON リテラルは残る** — T-F17 はまさにそれで隠れた |
| **T-F** | BE-8 (schema ↔ handler ↔ prompt) の担保 | **CI 検査 (`check-tool-contract.sh`) に任せ、テストで重複させない**。テストが担うのは**「起動時チェックが起動を失敗させること」の 1 点だけ** (§5.5) | (a) **テストで 3 者一致を検証する**: schema は Anthropic に登録するリソース、prompt はテンプレートファイルで、どちらもコードではない。走査は静的検査の仕事であり、テストに書くと検査と二重管理になる ([architecture.md](architecture.md) §3.8.4 が既に検査を定義済み)。(b) **どちらもやらない**: BE-8 は「機能が黙って死ぬ」形で現れる |
| **T-G** | 異常系 (O-4) の作り方 | **gateway のテストダブルが `CallMeta` と応答本文を任意に返せる形にし、[observability.md](observability.md) §4.3 の F-1〜F-5 に 1 対 1 のケースを持つ** (§5.4)。安全弁のしきい値は `config` を小さい値に差し替えて発火させる | (a) **実 LLM で `max_tokens` を再現する**: 再現性が無く、時間とコストがかかる。(b) **異常系を E2E で見る**: 実 LLM が都合よく失敗しないため**テストを書けない**。(c) **異常系をテストしない**: F-1 / F-3 は「静かに壊れる」分類 ([observability.md](observability.md) §4.3) であり、テストが無ければ観測コードの欠落に気づけない |
| **T-H** | テナント越境テストの範囲 | **全エンドポイント必須**。共通ヘルパ 1 本 + route 一覧からのテーブル駆動で書く (§6.1) | (a) **代表エンドポイントのみ**: v2 の実害 3 件 ([auth.md](auth.md) §5-1 / §5-7 / §6.4 の F-15) は**いずれも「代表」に選ばれない地味な経路**で起きた。代表主義は選ばれなかった経路を無防備にする。(b) **Repository の SQL 検査だけで足りるとする**: F-15 は SQL 検査を通る (クエリ側は正しい)。(c) **E2E で越境を見る**: ブラウザ経由では他テナントの ID を得る手段が無い |
| **T-I** | custom tool 経由の越境 (A-6) の検証段 | **I 段でツールハンドラを直接呼ぶ** (ハンドラは UseCase 側の関数 — [architecture.md](architecture.md) §3.8.1)。**LLM を介さない** (§6.2) | (a) **E2E で LLM にツールを呼ばせる**: LLM がそのツールを呼ぶかどうかが非決定的で、**テストが安定しない上に「呼ばれなかった」と「越境しなかった」を区別できない**。(b) **U 段でモックした Repository に対して見る**: 所有者条件が SQL に効いているかを検証できない (T-B と同じ理由) |
| **T-J** | E2E の対象と本数 | **①価値の中心経路 ②複数リポの結合が壊れても他段で気づけない ③実ブラウザ・実 SSE・実認証が要る — の 3 つすべてを満たすものだけ**。暫定 **5 本** (§7.1。本数は §13 の T-Q1) | (a) **画面ごとに 1 本 (網羅)**: 実行時間と保守コストが線形に増え、FE のリファクタで一斉に落ちる。(b) **スモーク 1 本 (起動確認のみ)**: 「結合テストやりたい」という一次要求 ([design_memo.md](design_memo.md):46) に対して、結合の中心 (SSE・生成物の還流) を担保しない |
| **T-K** | E2E の実行環境とタイミング | **dev 環境に対して、`main` マージ後の dev デプロイ完了をトリガーに実行 + nightly**。**PR の必須チェックにしない** (§7.4) | (a) **PR で全件回す**: E2E は**デプロイ済みのコード**に対してしか回せない。PR 時点のコードは dev に無いため原理的に不可能 (PR ごとに環境を作る = (c))。(b) **ローカルのみ**: CI で回らない = 機械強制でない (AC-5.2 に反する)。(c) **PR ごとにエフェメラル環境**: Terraform + RDS + **Managed Agent の発行**を PR 単位で行うことになり、D-6 の管理対象 (Agent ID) が PR 数だけ増える。(d) **prod に対して回す**: 本番データを汚す (§8.4 に反する) |
| **T-L** | E2E での LLM の扱い | **実 LLM を叩く** (dev のモデルプロファイル。[llm-migration.md](llm-migration.md) §5.2)。**アサーションは構造だけに限る** (イベント種別・要素の出現・文字数の下限) | (a) **dev の BE に LLM スタブを差す**: E2E が検証する経路が本番と別物になる (BE-5 と同型の「本番に無い経路が動く」問題)。(b) **Playwright の route interception で BE 応答をモック**: E2E が FE 単体テストに退化し、結合を担保しない。(c) **LLM の文言をアサートする**: 出力が毎回変わるため恒常的にフレークする |
| **T-M** | 統合段の DB 初期化 | **既定は「1 テスト = 1 トランザクション + 末尾で必ず ROLLBACK」**。**別トランザクションの相互作用を見るテストだけ専用スキーマ方式**にする (§8.2) | (a) **全テーブル TRUNCATE**: 遅く、並列実行できない。(b) **テンプレート DB から `CREATE DATABASE`**: 並列度は上がるがテストごとに接続が増え、CI の `services` の接続上限に当たる。(c) **ロールバック方式のみ**: [architecture.md](architecture.md) §3.9③ の監査ログは**別トランザクション**の best-effort であり、単一トランザクション内では本体の未コミットデータを見られないため**この経路のテストが書けない** |
| **T-N** | カバレッジ | **数値目標を置かない** (BE / FE とも)。代わりに **7 種の「必須テストの存在検査」を機械強制する** (§10。うち 1 種は FE の併置テスト検査 = §9.1.1 の F-C3。**#7 = I 段のテストが `t.Skip` で自分をスキップしないこと** — 2026-07-31 追加) | (a) **80% 目標**: v2 は既に `-coverprofile` + Codecov を持ちながらしきい値が無く (T-F6)、数字は集まっても何も強制していない。加えて率目標は「書きやすい `entity/` を厚く、書きにくい `repository/` を薄く」する誘因になり、**実効性が最も必要な場所 (A-4) が薄くなる**。(b) **差分カバレッジ目標**: v2 からの移植 PR (既存コードの移動) で意味を失う |
| **T-O** | FE のテスト土台 | **vitest + Testing Library**。API は **orval が生成する MSW ハンドラ**を使う (§4.2) | (a) **jest**: v2 に前例が無く (T-F10)、**雛形の pre-commit が既に `npx vitest related --run` を呼んでいる** ([pre-commit](../../templates/frontend-repo/scripts/hooks/pre-commit):34)。PoC も vitest (T-F14)。(b) **手書きの MSW ハンドラ**: 「テストが独自にスキーマを持つ」形になり、FE で BE-12 と同型の問題が起きる。(c) **`global.fetch` を差し替える**: orval の生成形 (クライアント種別) に依存し、生成設定を変えるとテストが一斉に壊れる。(d) **Storybook の play function を主役にする**: v2 は Storybook を持つが CI が無く (T-F9)、実行が担保された前例になっていない |

---

## 3. テストの段と担保範囲

> 本節が回答する ID: **D-2** (段の定義。ゲートへの割り当ては §9) / **AC-5.2**

### 3.1 段の表

**段 ID (U / I / C / E) は本書と実装リポの issue・PR で共通に使う識別子**。
**「何を担保しないか」が段の境界**であり、ここに書かれたものを別の段で必ず担保する。

| 段 | 対象 | 実行場所 | 何を担保するか | **何を担保しないか** (どの段が担保するか) | 実行時間の予算 |
|---|---|---|---|---|---|
| **U** (単体) | Go: `entity/` の純粋関数 / `service/` のロジックとツールループ / `usecase/` の手続き / `gateway/` の応答正規化。TS: `lib/` の純粋関数 / コンポーネント (jsdom) | ローカル (`go test ./...` / `npm run test`) + PR CI | 分岐・境界値・不正入力 / 失敗 5 分類の扱い (§5.4) / 安全弁の発火 / SSE イベント変換 (BE-7) / LLM 出力の数値化 (FE-6) / 巻き戻し順序 | **SQL が実際に所有者条件で絞ること** (→ I) / **マイグレーション後のスキーマとの整合** (→ I) / **HTTP ステータスの実応答** (→ I) / **生成型・schema とのズレ** (→ C) / **実ブラウザでの描画・遷移** (→ E) | Go 全体 **90 秒** / TS 全体 **120 秒** |
| **I** (統合) | `repository/` の全クエリ / `usecase` → `repository` の縦串 / `controller` を含む HTTP 層 (`httptest` + gin router) / **ツールハンドラの直接呼び出し** | PR CI (`services: postgres`) + ローカル (`docker compose`) | **所有者条件の実効性 (§6)** / 採番と一意制約 (BE-11) / トランザクションの巻き戻し / 401・403・404・429 の実応答 / 監査ログの別トランザクション (§8.2) / **custom tool 経由の越境 (A-6)** / **マイグレーション適用後のスキーマとの整合** (U から委譲されたもの。テスト DB を本番と同じツールで作るため — §8.2) | **LLM の実挙動** (→ U でダブル、**E で実物**) / **Exa の実挙動** (→ **E 段の nightly 疎通確認 1 本 (E-S1) のみ。U / I / C・E の通常実行では非担保** — §7.6) / **ブラウザと FE の描画** (→ E) / **LLM 出力の品質** (→ [llm-migration.md](llm-migration.md) §8) | 全体 **5 分** |
| **C** (契約) | OpenAPI 定義 ↔ 実装 ↔ orval 生成型 / tool schema ↔ handler ↔ prompt / `entity/toolresult` の読み手・書き手・テスト | PR CI (生成物の差分 + 検査スクリプト + golden 差分) | 型・フィールド名・必須性・enum 値のズレ (BE-8 / BE-12 / FE-2) / SSE イベント型が OpenAPI に載っていること | **値の妥当性・振る舞い** (→ U / I) / 実行時の型変換の失敗 (→ U) | **60 秒** |
| **E** (E2E) | 実ブラウザ (Playwright) で FE + BE + DB + **実 LLM** の縦串。**nightly のみ E-S1 (Exa の疎通確認) を追加で回す** (§7.6) | **dev 環境**。`main` マージ後の dev デプロイ完了 + nightly (§7.4) | 認証 (サインイン。**MFA 遷移は対象外** — §7.3 T-Q3=B) / 画面遷移 / **SSE が実ブラウザに届くこと** / 非同期ジョブの完了表示 / 生成物が別画面で参照できること / 再接続での復元 / **nightly のみ: Exa の応答形式と資格情報が生きていること (E-S1)** | **分岐網羅** (→ U) / **失敗 5 分類の全種** (→ U) / **越境** (→ I。ブラウザから他テナント ID を得られない) / **計測値の正しさ** (→ U / I) / **LLM 出力の品質** (→ [llm-migration.md](llm-migration.md) §8) | 1 本 **3 分** / 全体 **15 分** |

**実行時間は「予算 (上限)」であり実測値ではない** — v2 / PoC に統合段と CI 実行の実績が無いため
(T-F2 / T-F6 / T-F15)、根拠のある推定を置けない。**超えたときの対処順序は §9.2 で先に決めておく**。

### 3.2 モックの境界 (T-C の具体化)

**層ではなく「IF」に境界を固定する**。この 1 行が守れれば、モックの是非を PR ごとに議論しなくなる。

| 差し替えてよい | 差し替えてはいけない | 理由 |
|---|---|---|
| **利用側 (`usecase/<domain>` / `service/<domain>`) が定義した repository IF** | `entity/` (純粋なので実物で足りる) | [architecture.md](architecture.md) §3.6 が IF を 1〜3 メソッドに縛るため、手書きダブルが短い |
| **利用側が定義した gateway IF** (LLM / 検索 / ストレージ) | **`service/<domain>`** — `usecase` のテストでも実物を使う | Service をモックすると、L-2 / L-3 で UseCase に集まった協調ロジックが未検証になる |
| `config` の値 (安全弁のしきい値・`MaxTokens`) | **sqlc 生成クエリ / SQL** (I 段で実 DB) | T-B。`WHERE` 句の**存在**ではなく**実効性**を見る必要がある |
| 時刻・乱数 (関数注入) | **認証ミドルウェア** (I 段では実物を通す) | ミドルウェアを飛ばすと A-1 の担保がテストから消える |

**`testing-anti-patterns.md` の適用**: ダブルの戻り値は**実物と同じ完全な構造**にする (Anti-Pattern 4)。
`CallMeta` の usage 4 カウンタを「テストで使わないから」省略したダブルは作らない —
**省略した瞬間、計測欠落 (O-2) を検出できないテストになる**。

---

## 4. 層ごとのテスト方針

> 本節が回答する ID: **A-4** (絞り込みの層をテストで裏打ちする) / **O-4** (失敗分類の担当層)

### 4.1 backend (6 パッケージ層)

| 層 | 主な段 | 何をテストするか | 差し替えるもの | **必須ケース** (省略を認めない) |
|---|---|---|---|---|
| **`entity/`** | U | **全公開関数を網羅的に**。副作用が無く速いため、境界値・不正入力・空・巨大入力まで書く | なし | **LLM 出力の数値化にレンジ表記を含む入力** (`120-420億円` 等。FE-6 / [llm-migration.md](llm-migration.md) §8.3 の Q-3) / `ContractID` / `AccountID` の生成経路が 2 本に限られること ([auth.md](auth.md) §6.4) |
| **`repository/<domain>/`** | **I (実 DB)** | 全クエリ。**所有者条件が効くこと**・採番・一意制約違反・NULL と空文字の扱い・`XxxWithTx` が渡された `tx` で動くこと | なし (実 DB) | 他契約のレコードが **0 件**で返ること (§6.1) / **同一の採番を 2 回実行して UNIQUE 違反がエラーとして返ること** (BE-11。握り潰されないこと) |
| **`service/<domain>/`** | U | ツールループの停止条件・安全弁の発火・台帳の read/write-through の**対**・SSE イベント変換・プロンプト構築 | 自ドメイン repository IF / gateway IF | **F-1〜F-4 の 4 分類** (§5.4) / 安全弁 3 種 (回数・トークン・時間) / **BE-7: 複数行・空行を含む agent メッセージが欠落しないこと** / **BE-10: 台帳に書いた値を読み手が読めること (対で 1 テスト)** |
| **`usecase/<domain>/`** | U + I | 手続きの順序・トランザクション境界と巻き戻し・所有者スコープの確定・ツールハンドラ表の組み立て | repository IF / gateway IF (**service は実物**) | **越境 (§6.1)** / 途中失敗で生成物と台帳の両方が巻き戻ること / **ハンドラのクロージャに束縛されたスコープが LLM 引数で上書きされないこと (§6.2)** |
| **`gateway/<外部>/`** | U | 応答の正規化・**`CallMeta` の生成**・エラー変換・タイムアウト・リトライ | 外部 HTTP をローカルサーバで立てる (`httptest`) | **usage 4 カウンタが 1 つも欠けないこと** / **`stop_reason` が常に載ること** (欠けると O-2 が原理的に成立しない) / `ctx` キャンセルで即座に戻ること |
| **`controller/`** | **I** | ステータスコードの分岐・バリデーション・SSE のヘッダと書き出し・`CodedError` → HTTP 変換 | **UseCase を差し替えない** (実物 + 実 DB) | **[auth.md](auth.md) §6.6 の全行** (401 / 403 / 404 / 429) / **ラップされた `CodedError` が正しいステータスになること** (F5 の再発防止 — 直接型アサーションでは取りこぼす) / SSE 途中のエラーが**イベントとして**返ること |

**`gateway` の外部 HTTP の立て方**: SDK がベース URL の差し替えを許すなら `httptest` のサーバを向ける。
**Anthropic Go SDK でこれが可能かは未調査** (§13 の T-Q6)。不可能な場合は
**SDK クライアントを 1〜3 メソッドの IF で 1 段包み、その IF をダブルにする** (層は増やさず `gateway/` 内に閉じる)。

### 4.2 frontend

| 対象 | 段 | 方針 | 必須ケース |
|---|---|---|---|
| `lib/` の純粋関数 (パース・整形) | U | 実物のみ。**LLM 出力を数値化する関数は必ずテスト対象** | FE-6 のレンジ誤抽出 / 空・欠損・想定外形式 |
| コンポーネント | U | Testing Library。**関連する複数の期待は同一 `waitFor` コールバックに置く** (FE-7。[CLAUDE.md.tmpl](../../templates/frontend-repo/CLAUDE.md.tmpl) のテスト規約と一致) | **`AbortError` が正常系として扱われること** (FE-1) / ストリーミング中断・タイムアウトが画面に出ること |
| API クライアント | U | **orval が生成する MSW ハンドラ**を使う (T-O)。手書きのレスポンス定義を作らない | 生成型に無いフィールドを参照していないこと (tsc が担保) |
| SSE 読み取りの共通クライアント | U | `\n\n` 区切りの分割・**空行を本文として通す**・改行を含む本文 (BE-7 の FE 側)・再接続 | 分割が chunk 境界を跨いだ場合 / 途中切断 |
| 画面遷移・実 SSE | **E** | §7 | — |

---

## 5. LLM を含む経路のテスト (本書の中核)

> 本節が回答する ID: **O-4** / 参照: **O-2** (計測点は [architecture.md](architecture.md) §3.8.3 が SSOT)
> **LLM 出力の品質評価は本節の対象外** — [llm-migration.md](llm-migration.md) **§8** が SSOT。
> 本節は「**実際の LLM を叩かずに、経路の正しさを担保する**」方法のみを定める。

### 5.1 差し替え点は 1 つ

```
usecase/conversation (実物)
  └ service/conversation.Runner (実物 — ツールループ・安全弁・台帳・SSE 変換はテスト対象)
       └ gateway IF  ←←← ここだけをテストダブルに差し替える (T-D)
```

ダブルが持つ能力 (これが揃っていないと §5.4 の異常系が作れない):

1. **イベント列を台本として与えられる** — `text` / `tool_use(name, args)` / `message_stop` の並びを指定
2. **`CallMeta` を任意に返せる** — usage 4 カウンタ / `stop_reason` / provider / model / duration
3. **応答本文を壊せる** — 構造化出力のパース失敗を作る
4. **待てる / 失敗できる** — `ctx` の期限切れ・ネットワークエラー
5. **同じ tool_use を無限に返せる** — 安全弁 (回数上限) の発火を作る

**却下**: ダブルを「正常系 1 パターンだけ返す簡易実装」にする案 — それでは F-1〜F-4 が書けず、
[observability.md](observability.md) §4.3 の 5 分類が**設計にはあるがテストが無い**状態になる。

### 5.2 ツールハンドラのテスト

ハンドラは **UseCase 側の関数** ([architecture.md](architecture.md) §3.8.1) なので、
**Runner も LLM も介さずに直接呼べる**。これを利用して:

| 検証 | 段 | 方法 |
|---|---|---|
| 引数のパース (schema の引数名と一致すること) | U | 実際の schema から作った引数 JSON を渡す (手書きしない。§5.3) |
| **所有者スコープの強制** | **I** | §6.2 |
| 戻り値が `entity/toolresult` の型であること | C | コンパイラ (marker interface) + `check-tool-contract.sh` |
| 書き込み系ハンドラが渡された `tx` で書くこと | I | UseCase が張った `tx` をロールバックすると書き込みが消えること |

### 5.3 BE-12 の再発防止 (T-E の具体化)

**PoC で起きたことの機構** (出典は §1.3 の T-F17): 読み手・書き手・**テスト**が別々にスキーマを持ち、
テストが手書き JSON (`{"finding":"...","notes":"要確認"}`) を渡していたため、
書き手に `finding` が無く `notes` が `[]string` である事実と食い違ったまま緑になった。

**v3 の規約 (4 点)**:

| # | 規約 | 担保 |
|---|---|---|
| 1 | **テストは `entity/toolresult` の型を組み立て、`json.Marshal` した値を使う**。JSON 文字列リテラルをテストに書かない | [architecture.md](architecture.md) §3.8.5 の規約 5 を機械強制する (§13 の是正要求 3) |
| 2 | **golden ファイルは型から生成する** — `go test -update` 相当のフラグで `testdata/golden/toolresult/<tool>.json` を再生成し、**差分を PR に出す**。手書きしない | 生成の入力が型なので、フィールドを増減すると golden 差分として必ず見える |
| 3 | **読み手のテストは golden を入力に使う** — 台帳への write-through / SSE 変換 / 還流 / 永続化の 4 経路すべて | 読み手が独自構造体を作れば golden をパースできず落ちる |
| 4 | **`entity/toolresult` の型を変更した PR は、golden の差分を含まなければ落ちる** | **CI に golden 再生成の専用ステップがある** (2026-07-30 に追加済み: [ci.yml](../../templates/backend-repo/.github/workflows/ci.yml):88〜 の「golden ファイルの差分チェック」。`make golden` → `git diff --exit-code`。`Makefile` に `golden` ターゲットが無ければ `exit 1`)。**生成物差分チェックとは別ステップにした** — 落ちた原因が sqlc/wire か golden かをジョブ名で切り分けられるようにするため |

**なぜ golden と型の両方が必要か**: 型だけだと「読み手と書き手が同じ型を使っている」ことしか担保されず、
**JSON 表現 (フィールド名・省略・型) が変わったこと**が PR のレビューに見えない。
golden は「外部に出る形」のスナップショットであり、`json` タグの変更や `omitempty` の追加を差分にする。

### 5.4 異常系の再現 (O-4 / [observability.md](observability.md) §4.3 の F-1〜F-6 と 1 対 1)

| # | 失敗 | 段 | 再現方法 | 何を assert するか |
|---|---|---|---|---|
| **F-1** | 出力の切り詰め | U | ダブルが `CallMeta{StopReason: "max_tokens"}` を返す | **応答が成功扱いでも** warn ログ + メトリクスが出る / ターン集計の `outcome = truncated` |
| **F-2** | JSON パース失敗 | U | ダブルが途中で切れた JSON を返す | 専用コードの `CodedError` が返る / **部分結果が「成功」として保存されない** |
| **F-3** | ツール引数の不整合 | U | ダブルが schema に無い引数名・必須欠落の `tool_use` を返す | 専用コードの `CodedError` / warn ログ + メトリクス / **引数が黙って捨てられない** |
| **F-4** | タイムアウト / 打ち切り | U | ①`ctx` の期限を極小にしてダブルが待つ ②ダブルが同じ `tool_use` を無限に返し、`config` の回数上限を **2** に差し替える | ①専用コードの `CodedError` ②**エラーではなく正常終了**として扱われ、`outcome = tool_limit` と SSE の理由イベントが出る ([observability.md](observability.md) §4.4) |
| **F-5** | SSE の異常終了 | U (Go) + U (FE) | Go: 途中で書き込みが失敗する `ResponseWriter` を渡す。FE: 途中で切れるストリームを与える | Go: 書き込み失敗が warn に出て**無言破棄されない** ([architecture.md](architecture.md) §3.9③)。FE: 中断が画面に出る |
| **F-6** | レート制限の発動 | **I** | 認証エンドポイントを上限 + 1 回叩く | **429** と `Retry-After` ([auth.md](auth.md) §6.6) / セキュリティイベントとして記録される |

**安全弁のしきい値は `config` から読む** ([architecture.md](architecture.md) §3.9②) ため、
**テストは `config` を小さい値に差し替えて回す**。20 回のループを毎テスト回さない
(U 段の時間予算 90 秒を守るため)。**しきい値を定数に埋め込む実装はテスト不能になるので許可しない**。

### 5.5 テストと CI 検査の分界 (T-F の具体化)

| 対象 | 担保手段 | 本書の立場 |
|---|---|---|
| schema ↔ handler ↔ prompt の 3 者一致 | **CI 検査** `scripts/check-tool-contract.sh` ([architecture.md](architecture.md) §3.8.4 の検査 1〜5) | **テストで重複させない** |
| 起動時チェックが**起動を失敗させる**こと | **U 段のテスト** — ハンドラ表から 1 本抜いた状態で初期化関数を呼び、エラーが返ることを確認 | **これだけはテストで持つ**。検査が緑でも「起動時チェックの実装が実際に落とすか」は別問題であり、BE-5 (依存欠如でも動く) の再発点 |
| 所有者条件を持たないクエリの禁止 | **CI 検査** ([auth.md](auth.md) §6.4) | テストで重複させない。ただし**実効性**は I 段で見る (§6.1) |

---

## 6. テナント越境のテスト (最重要)

> 本節が回答する ID: **A-4, A-6** / 参照: [auth.md](auth.md) §6.4〜§6.6

### 6.1 HTTP エンドポイント: 全件必須 (T-H)

**要求**: **認証を要する全エンドポイントに対し、次の 2 ケースを I 段で必須にする**。

| ケース | 入力 | 期待 |
|---|---|---|
| **X-1** | 契約 B のトークンで、契約 A のリソース ID を指定 | **404** (`CodedError`)。**403 を返さない** ([auth.md](auth.md) §6.6) / 応答本文に対象の存在を示す情報が無い |
| **X-2** | トークン無し / 不正 / 期限切れ | **401**、本文なし |

**書き方 (これが無いと「全件」は運用で崩れる)**:

1. **fixture ヘルパ 1 本**: `testfixture.NewTwoContracts(t, tx)` が契約 A / B とそれぞれのアカウント・
   有効なトークン・各ドメインの最小リソース 1 件を作って返す (§8.1)
2. **テーブル駆動**: `{method, path, ownedIDBuilder}` の表を 1 ファイルに持ち、X-1 / X-2 を回す
3. **表の網羅を機械検査する** — **route 登録一覧に存在して表に無い route があれば CI で落とす**。
   route 一覧は **A-1 の `check-route-auth.sh` が既に走査するもの**を再利用する
   (呼び出し元は [ci.yml](../../templates/backend-repo/.github/workflows/ci.yml):97〜105)。実装は `check-owner-scope.sh` に足す
   (呼び出し元は同 :107〜116)
   (§13 の是正要求 4)
4. **パスパラメータ以外の入り口も表に含める** — クエリパラメータ・リクエストボディで**所有者 ID を受け取る API**
   ([auth.md](auth.md) §6.4 の経路②) は、**「B のトークンで A の `account_id` を指定 → 404」**を必ず持つ。
   v2 の F-15 (`list_themes` が存在確認だけで契約未検証) はこのケースでのみ検出できる

**「全件必須」の運用コストへの答え**: 1 route あたりの追加は**表に 1 行**である。
ヘルパと検査が先にあれば、新 route の越境テストを書く方が書かないより速い。
**この順序 (ヘルパ → 検査 → 機能実装) は §12 の依存順序に入れる**。

### 6.2 custom tool 経由の越境 (A-6。T-I)

**LLM を介さずに I 段でハンドラを直接呼ぶ**。理由: LLM がそのツールを呼ぶかは非決定的で、
E2E では「呼ばれなかった」と「越境しなかった」を区別できない。

| # | ケース | 期待 |
|---|---|---|
| **A-1'** | 契約 B のスコープで組んだハンドラに、契約 A のリソース ID を引数で渡す | **「該当なし」**が LLM 向けの結果として返る / エラー本文に他テナントのリソースの存在を示す情報が無い ([auth.md](auth.md) §6.5) |
| **A-2'** | 同上 | **所有者不一致が warn ログ + メトリクスに出る** (ツール名・件数・`request_id`。[observability.md](observability.md) §4.3) — 無言だと「スコープの渡し忘れ」と「越境試行」の両方が検知できない |
| **A-3'** | ハンドラの引数に所有者 ID らしきフィールドを混ぜる | **クロージャに束縛されたスコープが変わらない** ([architecture.md](architecture.md) §3.8.2 の束縛点) |

**全 tool 必須**。tool 集合は 1 箇所 (ハンドラ表) にあるので、
**`check-tool-contract.sh` の tool 名一覧と越境テストがカバーする tool 名一覧を突き合わせ、
欠落があれば落とす** (§13 の是正要求 4 に含める)。PoC の tool は 9 本
(`claude_managed_agents/cmd/devui/conversation.go:774`〜`:790`)。

### 6.3 Repository 段での越境 (§4.1 の再掲ではない部分)

**`repository/` の全クエリに「他契約のレコードが 0 件で返る」ケースを持つ**。
これは §6.1 (呼び出し側) とは別の担保である —
**§6.1 は「呼び出し側が正しい所有者を渡すか」、§6.3 は「クエリが所有者で絞るか」**を見る。
[auth.md](auth.md) §6.4 の F-15 は前者だけが壊れた例、§5-1 の IDOR は後者だけが壊れた例であり、
**片方だけでは両方を検出できない**。

---

## 7. E2E (Playwright)

> 本節が回答する ID: **C-8** (「結合テストやりたい — playwright」への回答) / **A-1・O-5** (部分)

### 7.1 シナリオの選び方と暫定 5 本

**選定基準 (3 つすべてを満たすものだけ E2E にする)**:
① ユーザーにとっての価値の中心経路である ② 複数リポ (FE / BE / infra) の結合が壊れたとき
他の段では気づけない ③ 実ブラウザ・実 SSE・実認証のいずれかが必要である。

| # | シナリオ | ①②③ の該当 | E2E でしか見えないもの |
|---|---|---|---|
| **E-1** | サインイン → 初期画面到達 (**MFA 画面遷移は対象外** — T-Q3=B。§7.3 の代償欄) | ①②③ | Vercel の FE と ECS の BE の間の Cookie / トークン受け渡し。**CORS は E-1 の対象から外す**見込み — [frontend.md](frontend.md) §12 の FE-D (BE 呼び出しを Next.js のサーバ経由にする) が成立すると**ブラウザ → BE のクロスオリジンが無くなる**ため。**確定は FE-Q2 (Vercel で SSE 中継が可能か) の実測後** ([frontend.md](frontend.md) §16.1)。不成立なら CORS は E-1 の担保対象に戻る |
| **E-2** | テーマ作成 → アセット登録 (ファイル) → 抽出完了が画面に出る | ①②③ | 非同期ジョブの状態機械 + **DB 状態のポーリング配信** ([design_memo.md](design_memo.md):187 の決定ログ 3 — 「非同期ジョブの SSE 進捗はプロセス内 channel でなく DB 状態のポーリング配信」) が実ブラウザで完結すること |
| **E-3** | 会話 1 ターン: 発話 → SSE で本文が流れ始める → 完了イベント | ①②③ | **ALB / Vercel を跨いだ SSE が実ブラウザに届くこと** (keep-alive 15 秒・バッファリングの有無) |
| **E-4** | 会話からアイデアを生成 → アイデア一覧に現れる | ①②③ | ツール実行 → 永続化 → **別画面での参照**という還流が端から端まで通ること |
| **E-5** | 企画書生成 → タブ表示 → バージョン復元 | ①②③ | 生成物の採番と復元 (BE-11) が UI 操作で成立すること |

**本数の確定は §13 の T-Q1** (工数に直結するため選択肢と代償を提示している)。

**E2E に入れないもの (意図的な除外)**: 一覧の絞り込み・並び替え・バリデーションメッセージ・
権限による表示制御 — いずれも U (コンポーネント) または I (HTTP) で担保でき、
**E2E に入れると本数が線形に増えて 15 分の予算を超える**。

### 7.2 SSE の E2E をどう書くか (FE-7 を構造で潰す)

**規約 4 点**:

1. **期待は「終端の観測可能な 1 状態」に置く**。ターン完了を示す 1 つの要素
   (例: `data-testid="turn-complete"`) を待ち、**その到達後に本文・オプションの内容を確認する**。
   中間の逐次描画を別々の `expect` で待たない — 分割すると中間レンダーを拾ってフレークする (FE-7)
2. **`page.waitForTimeout` (固定待ち) を禁止する**。待つのは常に状態 (要素・URL・ネットワーク) に対して行う
3. **逐次描画そのものを検証したい場合は U 段 (Testing Library) で行う** —
   関連する期待は同一 `waitFor` コールバックに置く ([CLAUDE.md.tmpl](../../templates/frontend-repo/CLAUDE.md.tmpl) のテスト規約)
4. **アサーションを LLM の文言に依存させない** (T-L) — 「特定の語が出る」ではなく
   「本文が N 文字以上」「イベント種別が観測された」で見る

**中断・再接続も 1 本持つ** (O-5 / rolling update で SSE は必ず切れる前提):
送信中にリロード → **会話履歴 GET で復元されて続きが読めること**を確認する。
これは E-3 に含めてよい (シナリオを増やさない)。

### 7.3 認証の扱い

**v2 の storageState 方式を踏襲する** (T-F11): `setup` プロジェクトでログインして
`storageState` を保存し、以降のプロジェクトが `dependencies: ['setup']` で再利用する。

| 項目 | 決定 | v2 との差 |
|---|---|---|
| テストアカウント | **第 1 リリースでは E2E 専用契約 A を 1 つ + 1 アカウントだけ作る**。§6 の越境は I 段で見るため E2E に 2 契約は不要である。**契約 B は共有機能 (A-7) を E2E に載せる時点で追加する** — それまで作らない (作ると資格情報が 1 組増え、使われないまま失効してローテーション対象になる) | v2 は 1 アカウント |
| 資格情報の所在 | **dev の Secrets Manager**。E2E ジョブが `dev` environment の OIDC ロールで取得する ([operations.md](operations.md) §4.1 の経路に合わせる。GitHub secret に置かない) | v2 は環境変数 (CI が無いのでローカルのみ) |
| **MFA** | **E2E 専用アカウントは MFA 無効とする** (**2026-07-31 のユーザー決定 = §13.1 T-Q3 の案 B**。当初推奨の「TOTP を実行時生成」はシークレット 1 件増と時刻ずれ起因のフレークを理由に不採用)。**代償**: E-1 は MFA 画面遷移を担保しない (U / I 段に委ねる — §7.1 の E-1 行に明記)。**歯止め**: MFA 無効の例外は **dev の E2E 専用アカウントに限定し、prod には作らない**。例外の表現方法は Task-3i が定義する。**却下: 固定コードを環境変数で渡す** — TOTP は時刻依存で固定値では成立しない (v2 の `E2E_MFA_CODE` はこの形。T-F12) | v2 は固定コード |
| `baseURL` | **dev の固定 URL** を渡す。**環境変数名は `E2E_BASE_URL` に固定**し (雛形の [e2e.yml](../../templates/frontend-repo/.github/workflows/e2e.yml):104 が渡している名前)、**`playwright.config.ts` は既定値を持たず、未設定なら読み込み時に throw する**。Vercel の Preview URL は使わない (デプロイごとに変わる)。**却下: v2 の `PLAYWRIGHT_BASE_URL` を踏襲する** — v2 は既定 `http://localhost:3000` を持つため (T-F11)、CI で env が落ちたときに**存在しないローカルへ接続して全件赤**になり、原因が「env 落ち」か「dev の障害」か切り分けられない。既定値を持たない方が失敗メッセージが 1 行で確定する | v2 は `PLAYWRIGHT_BASE_URL` (既定 `localhost:3000`) |

### 7.4 実行タイミングと、その代償への対処 (T-K)

| タイミング | 対象 | ブロックするもの |
|---|---|---|
| **`main` マージ後の dev デプロイ完了** | 全 5 本 | 何もブロックしない (**赤は通知**) |
| **nightly 1 回** | 全 5 本 | 同上 |
| **PR** | **回さない** | — |

**代償**: E2E の赤は `main` に入った後に判明する。**緩和策 3 点**:

1. **PR では I 段が同じ縦串を `httptest` で通す** — FE の描画以外は PR で検出できる
2. **E2E が赤の状態で prod デプロイ (H-4) を進めない** — 最新の E2E 結果を H-4 の承認材料に含める
   ([04-human-checkpoints.md](../../templates/shared/.claude/rules/04-human-checkpoints.md) §1.1 への追記。§13 の是正要求 6)。
   **承認材料として成立する条件: E2E の結果が「BE のどの commit を検証したか」と対応が取れること**。
   E2E は frontend リポで走るため `github.sha` は **FE 側の commit** であり、
   H-4 が承認しようとしている **BE の commit とは別物**である。
   **dispatch の `client_payload.sha` (BE 側 commit) と FE 側 commit の両方を実行サマリに出す**
   (雛形の [e2e.yml](../../templates/frontend-repo/.github/workflows/e2e.yml):177〜 は **2026-07-30 に BE / FE 両方の commit を出すよう是正済み**。`repository_dispatch` 以外の起動では **BE の commit は不明**として出力し、「H-4 の承認材料に使わない」ことを明示する)。
   nightly / 手動実行には `client_payload` が無く BE の commit を特定できないため、
   **サマリに「対象 BE commit: 不明 (nightly / 手動)」と明示し、その実行結果は H-4 の承認材料に使わない**
   (dev の継続監視用と位置づける)。**「対象 commit 不明」を承認材料に載せない** —
   稼働中の BE の revision を外部から知る手段が現状の設計に無いため (§13.2 の T-Q10)
3. **赤の切り分け手順を先に決めておく** — 実 LLM を叩くため、赤の原因が「回帰」か「LLM / 外部障害」かを
   区別する必要がある。順序: ①[observability.md](observability.md) §4.3 の F-1〜F-5 の発生率を見る
   ②同じ commit で 1 回だけ再実行する ③再実行も赤なら回帰として扱う。
   **「フレークだから再実行して緑にする」を無制限に許さない** (再実行は 1 回まで)

**トリガーの送信側 (2026-07-30 に追加)**: FE の `e2e.yml` は `repository_dispatch` (`types: [dev-deployed]`) を
待つ形にしたため、**送信側が無いとこのトリガーは永久に発火しない**。
`templates/backend-repo/.github/workflows/deploy.yml` の `release` ジョブ末尾に、
**dev のときだけ frontend リポへ dispatch する**ステップを追加した。

- **クロスリポジトリの dispatch には frontend リポへの権限を持つトークンが必要** (`GITHUB_TOKEN` は自リポジトリのみ)。
  GitHub App のインストールトークンか fine-grained PAT を `E2E_DISPATCH_TOKEN` として dev environment に登録する
- **これは [operations.md](operations.md) §4.1 の「GitHub 側に置いてよい値」の限定列挙に無い** —
  例外として認めるか、別の起動方式 (nightly のみ) に寄せるかは **要確認** (§13.1 の T-Q5)
- トークン未設定でもデプロイは失敗させない (E2E はブロックしない) が、**警告を出す** —
  無言のスキップにするとトリガーが死んでいることに気付けない
- **警告を出す条件は 2 つ**(どちらもデプロイは失敗させない):
  ①**トークンが未設定**のとき ②**dispatch の HTTP ステータスが 204 でないとき**
  (`204 No Content` が GitHub の `POST /repos/{repo}/dispatches` の成功応答)。
  **②を明示する理由**: `curl -sS` は 401 / 403 / 404 でも終了コード 0 を返すため、
  `|| echo` だけの実装では**実務で最も起きやすい「トークンの権限不足」「repo 名の誤り」が無言になる**。
  ステータスを `-o /dev/null -w '%{http_code}'` で取り出して分岐する。
  **雛形は 2026-07-30 にこの形で実装済み** ([deploy.yml](../../templates/backend-repo/.github/workflows/deploy.yml):491〜507)

**Playwright の retry 設定**: `retries: 1` (CI のみ)。**却下: `retries: 2` 以上** —
リトライで隠れるフレークは仕様の非決定性を示しており、隠すべきではない。

### 7.5 並列度

**暫定 `workers: 1` (直列)**。5 本 × 3 分 = 15 分で予算内に収まる。
**却下: 並列実行 (worker ごとに専用契約を切る)** — 実行時間は縮むが、
**同一の dev 環境に対して複数の会話ターンが同時に走ると LLM のレート制限に当たり得る**
(dev のクォータは未調査。**§13.2 の T-Q8**)。本数が 5 本を超える判断 (T-Q1) をした時点で並列化を再検討する。

### 7.6 外部 API (Exa) の実挙動をどこで担保するか

**穴の指摘**: §3.1 の I 段は外部 API の実挙動を「U でダブル、E で実物」に委譲していたが、
**U のダブルは定義上実挙動を担保せず、E-1〜E-5 に検索 (Exa) を通る経路が無い**
(E-3 は会話 1 ターンの SSE、E-4 はアイデア生成)。結果として
**Exa の応答形式変更・API キー失効・課金停止がどの段でも検出されない**。

**採用: nightly 限定の疎通確認 1 本 (E-S1) を E2E ワークフローに置く**。

| 項目 | 内容 |
|---|---|
| 名前 | **E-S1** (E-1〜E-5 とは別枠。**シナリオ本数 T-Q1 の 5 本には数えない**) |
| 実行 | **nightly のみ** (`github.event_name == 'schedule'` のときだけ動く Playwright プロジェクト)。dev デプロイ後の実行には含めない |
| 内容 | dev の BE の**検索を伴うエンドポイントを 1 回叩き**、Exa 由来のフィールドが**構造として**返ることを確認する (ブラウザ操作なし = Playwright の `request` fixture)。件数・文言はアサートしない (T-L と同じ理由) |
| 時間予算 | **30 秒**。§3.1 の E 段の 15 分予算に対する影響は無視できる |
| 失敗時 | **赤にする** (通知のみ・prod をブロックしない点は §7.4 と同じ)。赤の切り分けは §7.4 の 3 手順に従う |

**却下案**:

- **(a) E-3 / E-4 に research 経路を含める**: LLM が `research_market` / `deep_dive` を呼ぶかは
  **非決定的**で、「呼ばれなかった」と「Exa が壊れている」を区別できない (T-I と同じ理由で却下したもの)
- **(b) 非担保のまま放置する**: 応答形式変更と資格情報失効を**本番の障害で知る**ことになる。
  Exa は [llm-migration.md](llm-migration.md) V-11 の企画書リサーチが依存する外部依存であり、無担保にできない
- **(c) U 段のダブルを厚くする**: ダブルは**こちらが書いた想定**しか再現しない。
  「相手が形を変えた」ことは原理的に検出できない
- **(d) 独立した監視 (合成監視) に寄せる**: [observability.md](observability.md) のアラート設計に載せる形も採り得るが、
  **アラートのしきい値・通知先の SSOT は observability 側**であり、テスト戦略から新規のアラートを増やすと
  SSOT が 2 つになる。**まず nightly の 1 本で検出可能にし、常時監視が必要と判明したら observability へ移す**

**実体**: 雛形の [e2e.yml](../../templates/frontend-repo/.github/workflows/e2e.yml) に nightly 限定プロジェクトが無い
(§13 の是正要求 10)。

---

## 8. テストデータ

> 本節が回答する ID: **A-4** (2 テナントの用意) / **AC-5.2**

### 8.1 fixture の持ち方

| 対象 | 方式 | 却下案と理由 |
|---|---|---|
| **テナント・アカウント・トークン** | **Go のビルダー関数** (`testfixture.NewContract(t, tx)` / `NewTwoContracts(t, tx)`)。トークンは実際の署名鍵で発行する | **SQL の直書き**: スキーマ変更が実行時エラーになる。ビルダーなら**コンパイルエラーになる** (変更を漏らせない) |
| **マスタデータ** (`auth_roles` 等) | **本番と同じ seed をテスト DB 作成時に 1 回投入する** (v2 の `hassan-v2-backend/db/seeds/initial_data.sql` 相当) | **テスト内でマスタを作る**: テストごとに値が違い、本番の値との差異が検出できない |
| **各ドメインの最小リソース** | ビルダー関数 (`NewTheme(t, tx, contract)` 等)。**必須項目のみを埋め、任意項目はオプション引数**にする | **1 つの巨大な fixture ファイル**: どのテストがどのデータに依存するか読めず、変更が全テストに波及する |
| **LLM 応答の固定入力** (ゴールデンセット 20 件) | **[llm-migration.md](llm-migration.md) §5.3 / §8.1 が SSOT**。本書では重複定義しない | — |
| **ツール結果の JSON** | **型から生成した golden** (§5.3) | 手書き JSON (T-F17) |

**テーブル名・カラム名は本書に書かない** — データモデルが未確定
([architecture.md](architecture.md) §4。Q-1 待ち) のため。確定後にビルダー関数の一覧を §12 に追記する。

### 8.2 DB の初期化戦略 (T-M)

| 用途 | 方式 | 後片付け |
|---|---|---|
| **既定 (I 段のほぼ全て)** | **1 テスト = 1 トランザクション**。fixture もテストもその `tx` 内で動く | **末尾で必ず ROLLBACK** (`t.Cleanup`)。`COMMIT` しないので後片付けが不要 |
| **別トランザクションの相互作用を見るテスト** (監査ログの best-effort — [architecture.md](architecture.md) §3.9③ / 採番の競合 — BE-11) | **テストごとに専用スキーマを作る** (`CREATE SCHEMA test_<n>` + `search_path`) | 末尾で `DROP SCHEMA ... CASCADE` |
| **マイグレーションの適用** | **本番と同じマイグレーションツールのコマンドで CI のテスト DB を作る** (方式は D-4 で未確定 — [architecture.md](architecture.md) §5) | — |

**「テスト用のスキーマ SQL を別に持つ」ことを禁止する** — 本番のマイグレーションとテスト DB のスキーマが
別管理になると、**マイグレーションのバグがテストを通り抜ける** (I 段の存在意義が消える)。

**雛形は 2026-07-30 に是正済み**: [ci.yml](../../templates/backend-repo/.github/workflows/ci.yml) に
**「スキーマ適用 (統合段の前提)」ステップ**を追加した (`SCHEMA_APPLY_TARGET` が未設定なら `exit 1` — 
方式 (D-4) の確定前に「テーブル無しで統合段が緑になる」のを防ぐ)。

**あわせて必須の規約 (重大 3 の指摘。これが無いと上記の機構が無意味になる)**:

> **統合段のテストは `DATABASE_URL` 未設定を `t.Skip` にせず、失敗させる**。

Go の慣習では「DB が無い環境ではスキップ」と書きがちだが、**それを許すと CI で I 段が 0 件実行で緑になり、
§6 の越境テスト (A-4 / A-6 の実効性のすべて) が消える** — PoC が `DATABASE_URL` 未設定で
インメモリ動作していた BE-5 の再演になる。実装は次のいずれかに固定する:

| 方式 | 内容 |
|---|---|
| **採用: `TestMain` で必須化** | `DATABASE_URL` が空なら `log.Fatal` で**パッケージごと失敗**させる。ローカルで DB を立てずに走らせたい場合は `-short` を明示させ、**`-short` は CI で使わない** |
| 却下: `t.Skip` | スキップは緑になる。「テストが無い」と「テストが通った」を CI が区別できない |
| 却下: ビルドタグ (`//go:build integration`) | タグを付け忘れた統合テストが単体扱いで DB 無しに走り、別の形で沈黙する |

> **この規約だけでは塞げない残余を §10 の存在検査 #7 が閉じる** (2026-07-30 の 2 巡目レビュー 中 R-2)。
> **CI は常に `DATABASE_URL` を設定する** ([ci.yml](../../templates/backend-repo/.github/workflows/ci.yml):73〜74) ため
> `TestMain` の `log.Fatal` は **CI では発火しない** — 実際の抜け道は個別テストに
> `if os.Getenv("DATABASE_URL") == "" { t.Skip() }` を書く形であり、**規約の遵守に依存する限り残る**。
> #7 は `repository/` · `controller/` の `_test.go` に `t.Skip` / `t.Skipf` が現れたら落とす
> (許可は `testing.Short()` 判定の 1 箇所のみ)。

### 8.3 テナントを跨ぐデータ

`testfixture.NewTwoContracts(t, tx)` を**標準ヘルパ**にし、§6.1 の越境テストが 1 行で書ける形にする。
**これが無いと「全 route 必須」は実行不能な要求になる** (テストごとに 2 契約を手で組む工数がボトルネックになる)。

### 8.4 本番データを使わない

- **本番 DB のダンプをテスト環境・dev・ローカルに入れない**。理由は
  [observability.md](observability.md) §4.1 がログに個人情報・アセット本文を出さないとしたのと同じ
  (テスト環境の方がアクセス制御が緩いため、ログより漏洩リスクが高い)
- **dev のデータは E2E と手動検証が作ったものだけ**とする
- **例外は移行リハーサルのみ** — 本番データを扱う手順は [operations.md](operations.md) §6.2 の移行設計に従う。
  **本書はテストで使わないことだけを定める**
- **E2E は自分が使うデータを API 経由で作り、末尾で削除する**。
  **v2 の「対象データが無ければ `test.skip` で緑にする」形を禁止する** (T-F13:
  `hassan-v2-frontend/e2e/idea/idea-history-edit.spec.ts:33`・`:37`) —
  **前提データの不在は失敗として扱う**。削除できない append-only の記録 (LLM 利用量明細) は残してよい
  (E2E 専用契約に閉じるため他に影響しない)

---

## 9. CI 実行時間とマージ条件への接続

> 本節が回答する ID: **D-2** (段の割り当てのみ。**マージ条件は変更しない**) / **AC-5.2**

### 9.1 段の割り当て

**[01-construction-loop.md](../../templates/shared/.claude/rules/01-construction-loop.md) §7.2 のマージ条件を変更しない**。
本書が決めるのは「どの段がその CI に含まれるか」だけである。

| 段 | pre-commit | PR の必須チェック (V-1) | `main` マージ後 | nightly |
|---|---|---|---|---|
| **U** | 変更パッケージのみ | **✓** | — | — |
| **I** | — | **✓** | — | — |
| **C** | 警告 (非ブロック) | **✓** | — | — |
| **E** | — | **回さない** | **✓** (dev デプロイ後) | **✓** |

- **U / I / C は既存の CI ジョブに収まる** (`go test ./...` が U と I の両方を含む。`services: postgres` があるため)。
  **backend リポに新しい必須チェックのジョブを増やさない**
- **E は frontend リポの `e2e.yml`** が実行主体 —
  **2026-07-30 に雛形へ作成済み** ([e2e.yml](../../templates/frontend-repo/.github/workflows/e2e.yml))。
  **PR の必須チェックではない** (`repository_dispatch` / `schedule` / `workflow_dispatch` のみで起動し、
  `pull_request` トリガーを持たない)
- **S-6 (検証) で OR が実行するコマンドは変えない** ([01-construction-loop.md](../../templates/shared/.claude/rules/01-construction-loop.md) §1.3)。
  E は S-6 の対象外である (dev にデプロイされていないコードに対して回せない)

#### 9.1.1 frontend リポの機械検査 7 種の割り当て (D-2 の SSOT への登録)

**[frontend.md](frontend.md) §16.2-1 が要求する登録項目**。同書が定義した FE の機械検査 7 種は
**すべて frontend リポの既存 CI ジョブ (`ci.yml` の `frontend` ジョブ) の中にある**ため、
**新しいワークフローもジョブも増えない**。§9.1 の「新しい必須チェックを増やさない」は
**backend リポの CI ジョブについての記述**であり、frontend リポの既存ジョブへのステップ追加は含まない。

| # | 検査 | 段 | PR の必須チェック | 実体 (2026-07-30 実測) |
|---|---|---|---|---|
| **F-C1** | 依存方向 zone (L-F1〜L-F6。[frontend.md](frontend.md) §3.3) | **C** (構造の契約) | **✓** (`npm run lint`) | [.eslintrc.json.tmpl](../../templates/frontend-repo/.eslintrc.json.tmpl):55〜 (`import/no-restricted-paths` の zone = L-F2 / L-F3 / L-F6) + :92〜 (L-F1) + :164〜 (**L-F1 と L-F4 の再掲**。`no-restricted-imports` は override で上書きされるため — 2026-07-30 修正) |
| **F-C2** | デザイントークン強制 (FE-3。[frontend.md](frontend.md) §7.2) | **C** | **✓** (`npm run lint`) | 同 :30 (`tailwindcss/no-arbitrary-value`) / :31〜38 (`no-custom-classname` + whitelist `^(app\|admin)-.*`) / :45〜48 (生 hex) / :49〜52 (`style` 属性)。例外は `src/styles/**` と `tailwind.config.*` のみ (同 :196〜224) |
| **F-C3** | **併置テストの存在** (FE-4 / FE-6。[frontend.md](frontend.md) §8.2) | **U** (存在検査。§10 の 6 番) | **✓** | [ci.yml](../../templates/frontend-repo/.github/workflows/ci.yml):58〜71 |
| **F-C4** | 公開パス許可リストとルートグループの一致 ([frontend.md](frontend.md) §11.2.3) | **C** | **✓** | 同 :73〜97 (許可リスト `PUBLIC_PATHS` の存在確認 + `scripts/check-public-paths.sh` の呼び出し。**スクリプト本体は実装リポで書く** — 未実装なら :95〜96 で落ちる) |
| **F-C5** | `NEXT_PUBLIC_` 許可リスト ([frontend.md](frontend.md) §12) | **C** | **✓** | 同 :99〜117 (`ALLOWED="NEXT_PUBLIC_APP_ENV"`) |
| **F-C6** | `globals.css` の行数可視化 (FE-3) | **C** | **✗ (非ブロック)** | 同 :119〜129 (`if: always()` + `::notice` のみ。ブロックしないのは [frontend.md](frontend.md) §7.2 の判断) |
| **F-C7** | **`X-Admin-Token` の局所化** ([frontend.md](frontend.md) §5.2.1) | **C** | **✓** (`npm run lint`) | [.eslintrc.json.tmpl](../../templates/frontend-repo/.eslintrc.json.tmpl):162〜195 (`src/**` から `admin-mutator.ts` を除外し `Literal` / `Property` の 2 セレクタで禁止) + :196〜224 (styles 側の override でも維持) |

- **U / I / C / E の段への当てはめ**: FE には**実 DB を伴う段が無い**ため **I 段は空**である
  (BE 呼び出しは MSW / E 段が担う。§4.2)。F-C1〜F-C7 のうち **F-C3 だけが「テストの存在」を見る検査**なので
  **U 段**に置き、残りは「型・構造・設定のズレを実行せずに見る」ものなので **C 段**に置く
  (§3.1 の C 段の定義 = 「実行しても緑になる種類の欠陥」)
- **frontend リポの `ci.yml` は `push` / `pull_request` の両方で全ブランチに走る** (同 :7〜11) ため、
  **F-C1〜F-C5・F-C7 は PR のマージ条件に入る** (V-1 の「CI が緑」に含まれる。マージ条件そのものの SSOT は
  [01-construction-loop.md](../../templates/shared/.claude/rules/01-construction-loop.md) §7.2 で、本書は変更しない)
- **雛形の記述との差異 (2026-07-30 実測)**: [frontend.md](frontend.md) §16.2-1 の表は
  **F-C2 の `no-custom-classname` を「未設定」、F-C7 を「未実装」**と書いているが、
  **どちらも eslint 設定として実装済み**である (上表の実体を参照)。
  また同表・同 §3.3 の `.eslintrc.json.tmpl` の行番号 (`:42-73` / `:76-125`) と
  §7.2 の `:31-34` / `:35-38` は**現ファイルとずれている**。→ **§13.3 の是正要求 11**
  (本書は frontend.md を編集しない)
- **実装リポに残る作業は 3 つだけ** (雛形では閉じられない): ①`eslint-plugin-tailwindcss` と
  `eslint-plugin-import` を `devDependencies` に追加する (設定は雛形にあるが**依存が入っていないと eslint が
  ルール不明でエラーになる**) ②F-C1 の L-F4 パターン `@/features/*/!(types)` を実ドメイン名に展開する
  ③F-C4 の `scripts/check-public-paths.sh` を書く。**①〜③が終わるまで frontend の CI は赤である**
  (雛形が意図的に「未実装なら落ちる」形にしてあるため。§12.1 の 0 番)

### 9.2 予算超過時の対処順序 (先に決めておく)

**PR の CI 全体で 10 分以内**を目標とする。超えた場合、**この順に対処する**:

1. **I 段の並列化** — `t.Parallel()` + テストごとのトランザクション分離 (§8.2 の既定方式は並列可)
2. **U 段の並列化** — Go は既定で並列。TS は vitest の worker 数
3. **段の再配置** — U で足りるものを I から降ろす (実 DB が要らないテストを I に置かない)
4. **CI のキャッシュ** — Go modules / npm / golangci-lint のキャッシュ

**削ってはいけないもの (超過を理由に外さない)**:

- **§6 の越境テスト** (A-4 / A-6) — v2 の実害が最も多い箇所
- **C 段** (60 秒) — 実行時間が短く、検出する欠陥が「静かに壊れる」種類
- **§5.4 の失敗 5 分類** — 観測コードの欠落を検出する唯一の手段

**却下**: 「時間がかかるので I 段を nightly に移す」 — PR で SQL の越境が検出されなくなり、
T-H の判断 (全件必須) が実質無効化される。

**E 段が 15 分を超えた場合の順序 (PR CI とは別に決めておく)**:
上の 1〜4 は PR CI (U / I / C) 向けであり、**E 段には効かない** (E は実 LLM の応答待ちが支配的で、
キャッシュも段の再配置も時間を縮めない)。T-Q1 で本数を増やす判断をした時点でこの順序が効く。

1. **`workers` を 2 以上にする** (§7.5) — **前提: T-Q8 (dev の LLM / Exa のクォータ) の実測**と、
   **worker ごとに E2E 専用契約を切ること**。クォータが足りないなら 2 へ進む
2. **dev デプロイ後の実行本数を絞り、残りを nightly に回す** — dev デプロイ後は
   **E-1 (認証) と E-3 (SSE) の 2 本**に限る (「デプロイで壊れやすい結合」がこの 2 本に集中している)。
   E-2 / E-4 / E-5 は nightly で回す。**代償: 生成物の還流の回帰が最大 24 時間気付かれない**
   (§7.4 の緩和策 1 = PR の I 段への依存が増える)
3. **`timeout-minutes` を上げる** ([e2e.yml](../../templates/frontend-repo/.github/workflows/e2e.yml):54 が 30 分) —
   **最後の手段**。実行時間の上限を上げるだけで、赤の切り分け時間は延びる

**E 段で削ってはいけないもの**: **E-1 (認証)** — サインインが通らなければ他の 4 本も回らないため、
本数を削る判断をしても E-1 は常に含める。

---

## 10. カバレッジ (T-N)

> 本節が回答する ID: **AC-5.2** (「TDD を機械的に担保」の実体) / **D-2** (ゲートに何を入れないかの判断)

**数値目標を置かない**。理由は 2 つ:

1. **v2 で既に「集めるだけ」になっている** — `-coverprofile` を取り Codecov に送っているが、
   `fail_ci_if_error: false` でしきい値が無い (T-F6:
   `hassan-v2-backend/.github/workflows/test.yml:31`・`:36`〜`:40`)。同じことを繰り返しても何も強制されない
2. **率目標は誘因が逆を向く** — 書きやすい `entity/` を厚くし、書きにくい `repository/` (実 DB が必要) を
   薄くする方向に働く。**v2 で最も未検証だったのは `repository/` (T-F3) であり、率目標はそこを埋めない**

**代わりに機械強制する「必須テストの存在検査」7 種**:

**実体は 3 つに集約する** (スクリプトを検査ごとに増やさない): 既存の **V-2** /
**`check-owner-scope.sh`** (route・tool の一覧を既に走査するもの) / **`scripts/check-required-tests.sh`** (新規)。
**新規スクリプトが必要なのは #4 / #5 / #7 だけ**であり、それを 1 本にまとめる。

| # | 検査 | 段 | 実体 (未実装なら CI が落ちる形にする) |
|---|---|---|---|
| 1 | 対象 AC-ID がテスト名に存在する | U / I | 既存 **V-2** ([02-issue-granularity.md](../../templates/shared/.claude/rules/02-issue-granularity.md) §3.1) |
| 2 | **認証を要する全 route に X-1 / X-2 がある** | I | §6.1 の 3 (`check-owner-scope.sh` に追加。§13.3 の是正要求 4) |
| 3 | **全 tool に A-1' がある** | I | §6.2 (同スクリプト。同上) |
| 4 | **LLM 出力を数値化する `entity/` の関数に、レンジ表記を含む入力ケースがある** | U | **`scripts/check-required-tests.sh`** (新規。§13.3 の是正要求 12)。**判定規則**: `entity/` 配下で [llm-migration.md](llm-migration.md) §8.3 の Q-3 が対象とする関数 (**関数名または `//nolint` ではなく、`// llmparse:` マーカーコメントを付けた関数**を対象集合とする) それぞれについて、対応する `_test.go` に**ハイフンを挟んだ数値レンジのリテラル** (`[0-9]+ *[-〜–] *[0-9]+`) が 1 件以上現れることを確認する。**Q-3 は「ケースを含める」という規約であって欠落を検出する検査ではない**ため、検査は本書で新規に定める |
| 5 | **各 LLM 経路に F-1〜F-5 のケースが 1 件以上ある** | U | 同スクリプト。**判定規則**: [observability.md](observability.md) §4.2 の `feature` 識別子の**定数一覧** (**`entity/` の 1 ファイルに置く Go の const 群。この要求は同 §4.2 の `feature` 行が SSOT** — 2026-07-30 に追記。定義が無いと本検査は 0 件を検査して緑になる) を対象集合とし、各識別子について `service/` 配下のテスト名に `F1`〜`F5` の 5 つのサフィックスが揃っていることを確認する (例: `TestConversationTurn_F1_Truncated`)。**テスト名の命名規則を検査の入力にする**のは V-2 (AC-ID をテスト名に入れる) と同じ方式であり、新しい仕組みを増やさない |
| **6** | **FE: `src/lib/parse/**` と `features/*/lib/**` に併置テストがある** | U | **F-C3** (§9.1.1) = [ci.yml](../../templates/frontend-repo/.github/workflows/ci.yml):58〜71。**[frontend.md](frontend.md) §8.2 が本節への登録を要求していたもの** — 登録しないと「SSOT の外にある検査」になる |
| **7** | **I 段のテストが自分をスキップする経路を持たない** | I | 同 **`scripts/check-required-tests.sh`**。**判定規則**: `repository/` · `controller/` 配下の `_test.go` に `t.Skip` / `t.Skipf` が現れたら `exit 1`。**許可は `-short` フラグ判定の 1 箇所のみ** (`if testing.Short()`) とし、それ以外の条件でのスキップを認めない。**§8.2 の `TestMain` 規約だけでは塞げない**ため必要 — CI は常に `DATABASE_URL` を設定する ([ci.yml](../../templates/backend-repo/.github/workflows/ci.yml):73〜74) ので `TestMain` の `log.Fatal` は CI では発火せず、実際の抜け道は個別テストへの `if os.Getenv("DATABASE_URL") == "" { t.Skip() }` である。**v2 の E2E が `test.skip` で緑になっていた形 (T-F13) と BE-5 (DB 未接続フォールバック) の再演余地を、規約の遵守ではなく検査で閉じる** |

**#4 / #5 / #7 を「規約」で済ませない理由**: §11 は「『テストが通ること』だけでなく『必要なテストが在ること』を
機械で見る形にした」と主張している。**実装先の無い 3 件を残すとこの主張が 7 分の 4 しか裏付けを持たない**
(実装者が「気をつける」に落とす = DR-5)。**判定規則を上表に書いたのは、スクリプトを書く人が
仕様を推測せずに済むようにするため**である。

### 10.1 frontend 側のカバレッジの担保 (frontend.md §8.2 からの要求)

**FE も数値目標を置かない**。理由は BE と同じ 2 点に加えて、**FE は v2 に単体テストの土台が無く
(T-F9 / T-F10) 基準となる実測値が存在しない**ため、置いた数値が根拠を持たない。

**代わりの担保は 3 点**:

| # | 担保 | 実体 | 何を防ぐか |
|---|---|---|---|
| 1 | **併置テストの存在検査** (上表の 6 番 = F-C3) | [ci.yml](../../templates/frontend-repo/.github/workflows/ci.yml):58〜71 | **FE-6** (数値パーサのレンジ誤抽出)。PoC は純粋関数として分離済みでも FE-6 が起きた — **分離は必要条件、テストが十分条件** ([frontend.md](frontend.md) §8.2 の P-7) |
| 2 | **必須ケースの指定** (率ではなく内容) | §4.2 の表 (レンジ誤抽出 / 空・欠損・想定外形式 / `AbortError` が正常系 / SSE の chunk 境界) | 「テストファイルはあるが正常系 1 本だけ」 |
| 3 | **カバレッジは計測して PR に出すが、ゲートにしない** | `vitest --coverage` の出力を PR のサマリに出す | 率を上げるための無意味なテスト (誘因の逆転) |

**却下案**:

- **(a) FE に率目標 (例 70%) を置く**: 母数の大半が `components/` の JSX になり、
  **本当に守りたい `lib/parse/` (FE-6 の再発点) が薄いままでも達成できる**。BE と同じ誘因の逆転が起きる
- **(b) `src/lib/parse/` 配下にだけ率目標を置く**: 併置テストの存在検査 (担保 1) と
  必須ケース (担保 2) を両方満たしたファイルは**分岐が細かいので率は自然に高くなる**。
  率の管理コストに対して追加で防げる欠陥が無い
- **(c) 何も担保しない (計測もしない)**: 併置テストの存在検査は「ファイルがあるか」しか見ないため、
  **中身が `expect(true).toBe(true)` でも通る**。計測して PR に出すことが、その状態をレビューに載せる唯一の手段

**カバレッジ自体は BE / FE ともに計測して PR に出す** (数字を見えるようにする)。**ゲートにはしない** —
低下の理由をレビューで議論する材料として使う。

---

## 11. 本番観点への回答

| ID | 状態 | 回答 / 対象外の理由と先送り先 |
|---|---|---|
| **C-8** (ユーザー制約) | **回答** | TDD の順序は既存ルールが SSOT。本書は**何をテストするか**を 4 段 (§3) + 層別方針 (§4) で確定。**「結合テストやりたい — playwright」への回答は §7** (対象・環境・タイミング・SSE の書き方・認証) |
| **AC-5.2** | **回答** | 機械強制の実体: PR 必須チェックに U / I / C を割り当て (§9.1) + **FE の機械検査 7 種の登録** (§9.1.1) + **存在検査 7 種** (§10。#4 / #5 / #7 の実装先を `scripts/check-required-tests.sh` に確定) + 越境テストの網羅検査 (§6.1 の 3)。**「テストが通ること」だけでなく「必要なテストが在ること」を機械で見る**形にした |
| **D-2** | **部分回答 (段の割り当てのみ)** | ゲート内容とマージ条件は [01-construction-loop.md](../../templates/shared/.claude/rules/01-construction-loop.md) §7 + [architecture.md](architecture.md) §5 の D-2 が SSOT。本書は §9.1 の割り当て表・§9.1.1 の FE 検査の登録・§9.2 の予算超過時の順序のみを決める。**新規に増えるワークフローは E 段の `e2e.yml` 1 本のみで、これは PR の必須チェックではない** (§9.1)。**PR の必須チェックに増えるのは既存ジョブ内のステップだけ** (backend = `check-owner-scope.sh` への追加 + `check-required-tests.sh` / frontend = 既存 `ci.yml` ジョブ内の F-C1〜F-C7) |
| **A-4** | **回答** | **全 route に X-1 / X-2 を必須** (§6.1)。呼び出し側 (§6.1 の 4) と クエリ側 (§6.3) を**別の担保として両方持つ** — v2 の 2 種の欠陥はそれぞれ片方でしか検出できない |
| **A-6** | **回答** | **全 tool に A-1'〜A-3' を必須** (§6.2)。**I 段でハンドラを直接呼ぶ** (LLM を介さない — 非決定性を排除)。クロージャ束縛が LLM 引数で上書きされないことを A-3' で見る |
| **O-4** | **回答** | [observability.md](observability.md) §4.3 の **F-1〜F-6 に 1 対 1 のテストケース** (§5.4)。gateway ダブルが `CallMeta` と本文を任意に返せることを設計要件にした (§5.1) — これが無いと異常系が原理的に書けない |
| **A-1** | **部分回答** | 適用漏れの検出は CI 検査 ([auth.md](auth.md) §6.7)。テストとしては **X-2 (401) の全 route 必須** (§6.1) と **E-1** (§7.1) で担保。**ミドルウェアを差し替えない**ことを §3.2 で規約化 |
| **A-5** | **部分回答** | [auth.md](auth.md) §6.6 の表の**全行**を `controller/` の I 段で必須ケースにする (§4.1)。**ラップされた `CodedError` が正しいステータスになること**を含める (F5 の再発防止) |
| **O-5** | **部分回答** | F-5 (§5.4) + **E-3 の中断・再接続** (§7.2)。keep-alive・接続数メトリクスの仕様は [observability.md](observability.md) §4.4 が SSOT |
| **O-2** | **参照** | 計測点の層は [architecture.md](architecture.md) §3.8.3、フィールドは [observability.md](observability.md) §4.2 が SSOT。本書が加えるのは **「usage 4 カウンタと `stop_reason` が欠けないこと」を `gateway/` の必須テストケースにする**こと (§4.1) と、**ダブルが値を省略しないこと** (§3.2) |
| **O-3** | **参照** | 安全弁の発火を F-4 でテストする (§5.4)。しきい値は `config` から差し替える。**上限値そのもの**は [observability.md](observability.md) §4.4 が SSOT |
| **A-2 / A-3 / A-7** | **対象外** | ロール・所有者列の設計は [auth.md](auth.md) §6.2 / §6.3 が SSOT。**A-2 のロール別テストは、契約内管理者/メンバーの区別を使うかが未確定** ([auth.md](auth.md) §9 Q-A2) のため、確定後に §6.1 の表へ「ロール不足 → 403」の行を追加する (先送り先: 本書 §6.1) |
| **O-1 / O-6 / O-7** | **対象外** | ログ項目・監査項目・アラートは [observability.md](observability.md) が SSOT。ただし**監査ログの書き込み失敗が warn になること**は §8.2 の専用スキーマ方式でテストする (別トランザクションのため) |
| **D-1 / D-3 / D-5 / D-7 / D-8** | **対象外** | 環境・デプロイ・シークレット・段階リリース・IaC 範囲は [operations.md](operations.md) / [infrastructure.md](infrastructure.md) が SSOT。本書は **E2E が dev を使うこと**と**資格情報の所在** (§7.3) のみを決め、経路は operations に合わせる |
| **D-4** | **対象外 (依存)** | マイグレーション方式が未確定 ([architecture.md](architecture.md) §5 の D-4)。**本書は「本番と同じツールでテスト DB を作る」という条件だけを決める** (§8.2)。方式が決まれば CI のステップが埋まる |
| **D-6** | **参照** | Agent 再発行は [operations.md](operations.md) §5.2 が SSOT。本書は **3 者一致を検査に任せ、起動時チェックが落ちることだけをテストで持つ** (§5.5) |

---

## 12. 実装リポへの引き渡し

### 12.1 影響レイヤーと依存順序

**テスト基盤は機能実装より前に置く** — 後から入れると「既存テストを全部書き直す」になる。

0. **frontend の CI を緑にする 3 作業** (§9.1.1 の末尾) — `eslint-plugin-tailwindcss` /
   `eslint-plugin-import` の依存追加・L-F4 パターンの実ドメイン展開・`scripts/check-public-paths.sh` の実装。
   **雛形は未実装なら落ちる形にしてある**ため、これが済むまで frontend の PR は全て赤になる
1. **CI のテスト DB 作成** — `services: postgres` + **本番と同じマイグレーション適用ステップ** (§8.2) + マスタ seed
2. **`testfixture` パッケージ** — `NewContract` / `NewTwoContracts` / ドメイン別ビルダー (§8.1)
3. **越境テストの共通ヘルパ + route 網羅検査** (§6.1) — **機能実装より前**。
   これが後回しになると、その間に作られた route の越境テストが漏れる
4. **gateway テストダブル** (`CallMeta` と本文を任意に返せる形。§5.1)
5. **`entity/toolresult` の golden 生成** (§5.3)
6. **Playwright の setup project + E-1** (§7.3) → 画面が揃い次第 E-2〜E-5

### 12.2 並列可能

- **0 は 1〜6 と完全に独立** (frontend リポの作業。backend の着手を待たない)
- **4 と 5 は 1〜3 と独立**に着手できる (DB を使わない)
- **6 の setup project (E-1) は FE のサインイン画面ができ次第**着手可。E-2〜E-5 は各画面に依存。
  **E-S1 (§7.6) は画面に依存しない**ため、BE の検索エンドポイントができ次第着手できる
- **§10 の存在検査 7 種のスクリプト** (`check-required-tests.sh` を含む) は 1〜6 と並列に書ける
  (対象が出揃う前に枠だけ作れる)

### 12.3 参照すべき既存実装

**踏襲するもの**:

- **E2E の storageState + setup project の形**: `hassan-v2-frontend/playwright.config.ts`、
  `hassan-v2-frontend/e2e/auth.setup.ts` (MFA の扱いだけ §7.3 のとおり変える)
- **テストダブルの書き方 (関数フィールド + no-op 既定)**: `hassan-v2-backend/usecase/theme/list_themes_test.go:16`〜`:57`。
  **ただし IF が 1〜3 メソッドになるため、v2 のような巨大スタブにはならない** ([architecture.md](architecture.md) §3.6)
- **外部 HTTP のテスト (`httptest` でサーバを立てる)**: `hassan-v2-backend/llm/exa/client_test.go`、
  `hassan-v2-backend/ogp/client_test.go`
- **マスタデータ seed**: `hassan-v2-backend/db/seeds/initial_data.sql`
- **FE の vitest**: PoC の `claude_managed_agents/frontend/src/lib/plan-market-chart.ts` に対応するテスト群
  (LLM 出力の数値化をテスト対象にしている前例)

**踏襲しないもの**:

- `hassan-v2-frontend/e2e/idea/idea-history-edit.spec.ts:33`・`:37` の **self-skip** (§8.4)
- `hassan-v2-backend/.github/workflows/test.yml:36`〜`:40` の **しきい値の無いカバレッジ収集** (§10)
- `claude_managed_agents/.github/workflows/ci.yml:27`〜`:30` の **DB を立てない CI** (§8.2)
- `claude_managed_agents/cmd/devui/conversation_plan_grounding_test.go:32` の **手書き合成 JSON** (§5.3)
- `hassan-v2-backend/usecase/idea_board/repository_stubs_test.go` の**巨大スタブ** —
  IF を小さくすることで回避する (原因は IF の粒度であってスタブの書き方ではない)

---

## 13. 残課題 / 要確認

### 13.1 ユーザー判断が必要な未確定 (暫定既定で設計を進めている)

**T-Q1: E2E を何本・どこまで作るか** (工数に直結)

| 案 | 内容 | 実行時間 | 代償 |
|---|---|---|---|
| A | **スモーク 1〜2 本** (E-1 + E-3) | 6 分 | 生成物の還流 (E-4 / E-5) と非同期ジョブ (E-2) の結合が未担保。**「結合テストやりたい」の中心が抜ける** |
| **B (暫定既定)** | **5 本** (E-1〜E-5。§7.1) | 15 分 | 初期の実装工数が最大 (画面が揃うまで着手できない本数が多い) |
| C | **10 本以上** (画面ごと) | 30 分以上 | FE のリファクタで一斉に落ち、保守が実装を上回る |

[Answer]: **B — 5 本 (E-1〜E-5) で確定** (2026-07-31 ユーザー回答)。§7.1 のとおり

**T-Q2: E2E の実行環境と並列度**

| 案 | 内容 | 代償 |
|---|---|---|
| **A (暫定既定)** | **dev 共有環境 + `workers: 1`** | 15 分かかる。他の開発者が dev を触っていると干渉し得る |
| B | dev + worker ごとに専用契約を切って並列 | 速いが、**dev の LLM レート制限が未調査** (§13.2) |
| C | PR ごとのエフェメラル環境 | 干渉ゼロだが Terraform + RDS + **Agent 発行**が PR 単位で必要 (D-6 の管理対象が増える) |

[Answer]: **A — dev 共有 + `workers: 1` で確定** (2026-07-31 ユーザー回答)

**T-Q3: E2E 専用アカウントの MFA**

| 案 | 内容 | 代償 |
|---|---|---|
| **A (暫定既定)** | **TOTP シークレットを Secrets Manager に置き、実行時にコードを生成** | シークレットが 1 つ増える。時刻ずれで失敗し得る |
| B | E2E アカウントのみ MFA を無効にする | **E-1 が本番と違う認証経路を通る** (MFA 画面遷移が未担保になる) |

[Answer]: **B — MFA 無効の E2E 専用アカウントを使う** (2026-07-31 ユーザー回答。**暫定既定 A ではない**)。
**代償と歯止めを設計に含める**: ①代償 = E-1 が MFA 画面 (`/mfa` 遷移・TOTP 入力) を通らないため、
**MFA フローは U/I 段の担保に委ねる** (E2E では未担保と明記する) ②歯止め = 「MFA を無効化できるアカウント」は
本番の認証設計に対する例外なので、**dev 環境の E2E 専用アカウントに限定し、prod には MFA 無効アカウントを
作らない**。無効化の実現方法 (シードデータで MFA 未登録のまま `mfa_required` を免除するフラグ等) は
**Task-3i (認証 API 仕様) が「例外の表現」として定義する** — 無言の裏口にしない ([auth.md](auth.md) §6.2 との整合)

**T-Q4: E2E の赤で本番デプロイ (H-4) をどう扱うか**

| 案 | 内容 | 代償 |
|---|---|---|
| **A (暫定既定)** | **承認材料に含める** (人間が判断。機械ブロックしない) | 承認者が見落とすと赤のまま本番に出る |
| B | **機械的にブロックする** (最新の E2E が緑でなければ prod ワークフローを失敗させる) | 外部 (LLM / dev 環境) の一時障害で本番リリースが止まる |

[Answer]: **A — 承認材料に含める (機械ブロックしない) で確定** (2026-07-31 ユーザー回答)。
見落とし対策として H-4 の承認テンプレートに「最新 E2E の結果」欄を必須項目で置く


**T-Q5: E2E のトリガーに使うクロスリポジトリ dispatch のトークンを認めるか** —
FE の E2E を「dev デプロイ完了」で起動するには、backend の CI が frontend リポへ
`repository_dispatch` を送る必要があり、**frontend リポへの権限を持つトークンを
GitHub environment secret に置く**ことになる。これは [operations.md](operations.md) §4.1 の
限定列挙 (IAM ロール ARN と非秘密の識別子のみ) の**例外**にあたる。

| 案 | 内容 | 代償 |
|---|---|---|
| **A (暫定既定)** | `E2E_DISPATCH_TOKEN` を dev environment に置く。**dev のみ・frontend リポの `dispatch` 権限のみ**に絞った fine-grained トークンとし、operations.md §4.1 に例外として 1 行追記する | 限定列挙に例外が 1 つ増える (「例外はこれだけ」を維持する運用が必要) |
| B | dispatch をやめ、**nightly のみ**にする | `main` マージから最大 24 時間、E2E の結果が分からない。テスト戦略 §7.4 の緩和策 1 (PR の I 段) に依存が集中する |
| C | E2E を frontend リポの `push: main` で起動し、**冒頭で dev の稼働バージョンを確認して合わなければ待つ** | 実装が増え、待ち時間が読めない (Vercel と ECS のデプロイ完了時刻が別) |

[Answer]: **A — 例外として認める** (2026-07-31 ユーザー回答)。dev のみ・frontend リポの
`repository_dispatch` 権限のみの fine-grained トークン。**[operations.md](operations.md) §4.1 の
限定列挙に「唯一の例外」として追記済み** (例外を増やす場合は同表への追記 + レビューを必須とする)

### 13.2 調査が必要 (推測で埋めない)

**ID は §13.1 (T-Q1〜T-Q5) の続きで通し番号にする** — 以前は §13.1 と §13.2 で T-Q5 / T-Q6 が
重複しており、本文からの参照が別項目を指していた (§4.1 の SDK 参照・§7.5 のクォータ参照)。
**T-Q は本書全体で一意**とする。

- **T-Q6: Anthropic Go SDK がベース URL の差し替えを許すか** — 許すなら `gateway/anthropic` の U 段は
  `httptest` で書ける。許さないなら SDK クライアントを 1 段 IF で包む (§4.1)。**未調査**
- **T-Q7: orval の MSW ハンドラ生成が採用バージョンで使えるか** — 使えないなら
  「OpenAPI から MSW ハンドラを生成する別手段」または「生成型を使った手書きハンドラ + 型で縛る」に切り替える (§4.2)。**未調査**
- **T-Q8: dev の LLM / Exa のレート制限とクォータ** — E2E の並列度 (T-Q2) と nightly の実行本数、
  §9.2 の E 段の対処順序 1 を左右する。**未調査**
- **T-Q9: v3 のデータモデルが必要とする PostgreSQL 拡張** — v2 は `uuid-ossp` のみ
  (`hassan-v2-backend/db/schema.sql:1`)。ナレッジのベクトル検索等で拡張が増えるなら CI の
  `postgres` イメージを差し替える必要がある。データモデル確定 ([architecture.md](architecture.md) §4) 待ち
- **T-Q10: dev で稼働中の BE の commit / image tag を外部から知る手段があるか** —
  現状の設計にはヘルスチェック用の `/alive` しか無く ([infrastructure.md](infrastructure.md) §2 の INF-D)、
  **応答に revision を含めるかは決まっていない**。無いままだと nightly / 手動実行の E2E 結果を
  「どの BE commit を検証したか」に紐付けられず、**H-4 の承認材料に使えない** (§7.4 の緩和策 2)。
  必要と判断するなら [observability.md](observability.md) / [infrastructure.md](infrastructure.md) 側の決定になる。**未調査**

### 13.3 他文書・雛形への是正要求 (本書では編集していない)

| # | 対象 | 内容 |
|---|---|---|
| 1 | [templates/backend-repo/.github/workflows/ci.yml](../../templates/backend-repo/.github/workflows/ci.yml) | **2026-07-30 に解消済み** — 「スキーマ適用 (統合段の前提)」ステップを追加 (`SCHEMA_APPLY_TARGET` 未設定なら `exit 1`)。**残る要求は §8.2 の「`DATABASE_URL` 未設定を skip にしない」規約を実装リポの `TestMain` に落とすこと** |
| 2 | [templates/frontend-repo/.github/workflows/e2e.yml](../../templates/frontend-repo/.github/workflows/e2e.yml) | **2026-07-30 に作成済み** — dev デプロイ後 (`repository_dispatch`) + nightly + 手動のトリガー、`environment: dev`、retries は Playwright 設定側、**スキップ検出 (0 件実行とレポート欠損も失敗扱い)**、資格情報は **OIDC + Secrets Manager** から取得。送信側は [deploy.yml](../../templates/backend-repo/.github/workflows/deploy.yml) の `release` 末尾 |
| 3 | [architecture.md](architecture.md) §3.8.4 の検査 5 | **検査対象に「テストファイル内の手書き JSON リテラル」を含める** — 同 §3.8.5 の規約 5 (テストは合成 JSON を手書きしない) に対応する機械強制が現状の検査 1〜5 に無い。T-F17 はこれで隠れた |
| 4 | [auth.md](auth.md) §6.4 の CI 検査 / [ci.yml](../../templates/backend-repo/.github/workflows/ci.yml):107〜116 の `check-owner-scope.sh` | **「全 route に越境テスト (X-1 / X-2) が存在すること」と「全 tool に A-1' が存在すること」の網羅検査を追加する** (§6.1 の 3 / §6.2)。route 一覧は `check-route-auth.sh` (同 :97〜105) が既に走査するものを再利用する |
| 5 | [operations.md](operations.md) §4.1 の限定列挙 | **E2E 専用アカウントの資格情報の所在を追加する** — 現在の列挙にこの用途が無く、GitHub secret に置かれる余地が残る (§7.3)。**組数は 1 組 (契約 A の 1 アカウント分: メールアドレス + パスワード + TOTP シークレット)**。§7.3 の決定どおり**契約 B は第 1 リリースでは作らない**ため、B の資格情報は列挙に加えない (共有機能を E2E に載せる時点で追加する) |
| 6 | [04-human-checkpoints.md](../../templates/shared/.claude/rules/04-human-checkpoints.md) §1.1 の H-4 | **確認観点に「最新の E2E 結果」を追加する** (§7.4 の緩和策 2)。T-Q4 が B なら機械ブロックに変える |
| 7 | [02-issue-granularity.md](../../templates/shared/.claude/rules/02-issue-granularity.md) §3.1 | **E2E の追加が必要な issue の扱いが V-x に無い** — E 段は PR で回らないため V-1〜V-4 では検証できない。「E2E シナリオに影響する変更を含む PR は、E2E の追加・更新をしたことを PR 本文に書く」を V-10 (ドキュメント更新) と同じ形で足す |
| **8** | [ci.yml](../../templates/backend-repo/.github/workflows/ci.yml):88〜 | **2026-07-30 に実施済み** — golden 再生成の**専用ステップ**「golden ファイルの差分チェック」を追加 (`make golden` → `git diff --exit-code`。`Makefile` に `golden` ターゲットが無ければ `exit 1`)。**設計は当初「生成物差分チェックに追加」と書いていたが、別ステップにした** — 落ちた原因を sqlc/wire と golden で切り分けられるようにするため (§5.3 の規約 4 を実態に合わせて更新済み) |
| **9** | [e2e.yml](../../templates/frontend-repo/.github/workflows/e2e.yml):177〜 | **2026-07-30 に実施済み** — サマリに FE の commit と BE の commit (`client_payload.sha`) を出す。`repository_dispatch` 以外の起動では **BE の commit を「不明」と明示し、H-4 の承認材料に使わない**旨も出力する |
| **10** | [e2e.yml](../../templates/frontend-repo/.github/workflows/e2e.yml) | **nightly 限定の Playwright プロジェクト (E-S1 = Exa の疎通確認) を追加する** (§7.6)。`github.event_name == 'schedule'` のときだけ実行する形にし、dev デプロイ後の実行には含めない (15 分予算を守る) |
| **11** | [frontend.md](frontend.md) §16.2-1 の表 / 同 §3.3 / 同 §7.2 | **雛形の実装状況と行番号が現ファイルとずれている** (2026-07-30 実測。§9.1.1): ①§16.2-1 の検査 2 「`no-custom-classname` が未設定」→ **設定済み** ([.eslintrc.json.tmpl](../../templates/frontend-repo/.eslintrc.json.tmpl):31〜38) ②同 検査 7 「`X-Admin-Token` の局所化は未実装」→ **実装済み** (同 :162〜195) ③§3.3 の `:42-73` / `:76-125` と §7.2 の `:31-34` / `:35-38` を実測値 (§9.1.1 の表) に更新する ④**§8.2 の「testing.md §10 の 5 種に本検査は含まれていない」という記述は解消済み** — 本書 §10 の 6 番として登録した (§9.1.1 の F-C3)。**残る実作業は「npm 依存の追加」「L-F4 のドメイン名展開」「`check-public-paths.sh` の実装」の 3 件**であり、eslint 設定側の未実装はもう無い |
| **12** | [ci.yml](../../templates/backend-repo/.github/workflows/ci.yml):104〜 | **2026-07-30 に CI ステップは実施済み** — 「必須テストの存在検査」で `scripts/check-required-tests.sh` を呼び、未実装なら `exit 1`。**残る作業は実装リポでのスクリプト本体の実装** (§10 の #4 / #5 / **#7** の判定規則に従う。**#7 = `repository/` · `controller/` のテストに `t.Skip` が無いこと** — 2026-07-30 の 2 巡目レビュー 中 R-2 で追加。CI のエラーメッセージも 3 検査を列挙する形に更新済み) |
| **13** | [deploy.yml](../../templates/backend-repo/.github/workflows/deploy.yml):478〜507 (E2E の起動通知) | **2026-07-30 に是正済み** — `curl` の HTTP ステータスを `-w '%{http_code}'` で取り、**204 以外を警告にする**形になっている (`curl -sS` は 4xx でも exit 0 のため `\|\| echo` だけでは無言になる)。**残る要求は無い**。§7.4 に警告条件 2 つとして明記した |

### 13.4 仮定 (違えば本書の判断が変わる)

- **会話 1 ターンの SSE が実ブラウザで観測できる UI が存在する**前提で §7.1 の E-3 / E-4 を書いた。
  FE の構造設計 ([frontend.md](frontend.md)) で画面構成が変わればシナリオを組み替える
- **tool は 9 本**という前提で §6.2 のテーブル駆動を設計した (PoC の実測:
  `claude_managed_agents/cmd/devui/conversation.go:774`〜`:790`)。v3 の tool 集合が変われば件数が変わる
- **第 1 リリースのドメインは テーマ / アセット / 会話 (idea / plan を含む)** という前提で
  §7.1 の 5 本を選んだ ([architecture.md](architecture.md) §3.5.2 の区分)。
  ナレッジ / アイデアボード / お知らせ / 設定が第 1 リリースに入るなら E2E の対象を再選定する
- **CI ランナーは GitHub Actions の標準 (ubuntu-latest) を使う**前提で §3.1 の時間予算を置いた。
  大型ランナーを使う判断があれば予算は変わる (§9.2 の対処順序は変わらない)
- **越境テストは「契約 (`contract_id`) 単位」で書けば足りる**前提で §6 を設計した。
  個人スコープ (`account_id`) の絞り込みが契約スコープと別に存在するリソース
  ([auth.md](auth.md) §6.3) については、**X-1 に「同一契約の別アカウント → 404 か 200 か」の行を足す必要がある**。
  どちらになるかは A-2 のロール設計 ([auth.md](auth.md) §9 Q-A2) 待ち
