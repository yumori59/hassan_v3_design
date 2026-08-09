# ディレクトリ構成 (backend 実装リポジトリの骨格)

設計リポ hassan_v3 の `docs/design/architecture.md` §3 を、実装リポジトリのディレクトリとして写したもの。
**決定の正は設計リポ側**であり、本ファイルは「どこに何を置くか」の索引に徹する
(責務・禁止事項・依存規則の本文は `.claude/rules/05-architecture-coding-rules.md` に持たせてある。同じ表を二重に持たない)。

- 空ディレクトリは `.gitkeep` で保持している。**最初のファイルを置いたら `.gitkeep` を消す**
- `<module-path>` は `go.mod` の module path に読み替える
- **本ファイルに無いパッケージを新設するときは §4 の手順を踏む** (登録漏れは CI の `D-2⑦` が落とす)

## 1. ツリー

```
.
├── main.go                     エントリポイント (v2 踏襲: hassan-v2-backend/main.go)
├── go.mod / go.sum
├── Makefile                    run / psqldef (または migrate) / sqlc / wire / docs / golden
├── .golangci.yml               depguard による L-1〜L-6 + dupl / cyclop / funlen (雛形あり)
├── layering-scopes.yml         層規約の適用範囲 (CI 検査 D-2⑦ の入力。雛形あり)
├── CLAUDE.md.tmpl              立ち上げ時に CLAUDE.md へリネーム (§1.2)
├── .claude/                    Claude Code 運用ルール一式 (§1.2)
│   ├── agents/                 go-developer.md (実装) / code-reviewer.md (レビュー)
│   ├── rules/                  05-architecture-coding-rules.md (雛形あり・backend 固有) + shared/ から
│   │                           コピーして合流 (01〜04 + feedback_review_patterns.md)
│   └── skills/                 shared/ からコピーして合流 (implementing-robustly / test-driven-development)
├── common/                     ドメインを持たない技術基盤 (層規約 L-1〜L-6 の対象外。§1.1)
│   ├── router/                 ルート登録と認証ミドルウェアの適用 (v2 踏襲)
│   ├── auth/                   JWT 検証・ミドルウェア (v2 踏襲。X-Token + HS256)
│   ├── logger/                 構造化ログ (v2 踏襲。O-1)
│   ├── constants/              CodedError とエラーコード体系 (v2 踏襲)
│   ├── config/                 設定値の SSOT。os.Getenv を呼んでよい唯一の場所
│   └── di/                     provider.go / wire.go / wire_gen.go (具体パッケージを import する唯一の層)
├── controller/                 HTTP 受信・認可・SSE 書き出し・CodedError → HTTP 変換
│   └── dto/                    HTTP リクエスト/レスポンス構造体 (v2 踏襲。§1.3)
├── usecase/<domain>/           手続き・ドメイン間協調・トランザクション境界・IF 定義
├── service/<domain>/           1 ドメインに閉じた業務ロジック・Agent のツールループ
├── repository/<domain>/        SQL 実行 (sqlc 生成クエリ) と entity への変換
├── gateway/<外部システム>/       外部 SDK / HTTP 呼び出し。LLM 計測値 (CallMeta) の生成点
├── entity/                     副作用のない計算・ドメイン型・sqlc 生成 enum の置き換え先
│   └── toolresult/             ツール結果の型 (書き手・読み手・テストの単一 SSOT)
├── db/
│   ├── schema.sql              スキーマ定義の SSOT (適用方式は D-4 で確定してから)
│   ├── queries/<domain>/*.sql  sqlc の入力 (ドメイン別)
│   └── rdb/<domain>/           sqlc の出力 (生成物。repository/<domain> だけが import する)
├── prompts/
│   ├── agents.yaml             Managed Agent の宣言的な列挙 (再発行トリガの SSOT)
│   └── <domain>/               プロンプトのテンプレートファイル
├── env/                        非秘密の環境値 (env/<env>.env。git 管理・秘密は置かない)
├── scripts/                    CI 検査スクリプトと git hooks
├── testdata/golden/toolresult/ 型から生成する golden (手書き禁止)
└── .github/                    workflows (ci / deploy / rollback) と issue / PR テンプレート
```

### 1.1 `common/` の位置づけ (決定の正: `architecture.md` §3.5.1)

`docs/design/architecture.md` §3.5.1 が **layer-first** (`controller/` `usecase/<domain>/` …を最上位に置く)
を採用し、**domain-first** (`<domain>/{controller,usecase,...}` の feature フォルダ) を却下案としている
(v2 の既存構造と揃わなくなり、移植コードとの二重構造になるため)。**この決定は変わっていない** —
`usecase/` `service/` `repository/` `entity/` `gateway/` `controller/` は引き続き最上位にある。

**技術基盤 6 パッケージを `common/` 配下に置くことも同 §3.5.1 の決定である** (却下案とその理由も同節)。
`router/` `auth/` `logger/` `constants/` `config/` `di/` は
**layer-first/domain-first のどちらの分類にも属さない技術基盤**であり (4 層 + entity + gateway の
どの層にも当てはまらず、L-1〜L-6 の依存規則の対象にもならない)、ルート直下に 6 つ並ぶとリポジトリ直下が
層構成とそれ以外の混在で見通しにくくなる。**技術基盤を 1 段掘って集約しただけ**で、以下は変わらない:

- Go の**パッケージ名**は変わらない (`common/config` の package 名は `config`)。
  コード上の参照 (`config.XXX` 等) やプロンプト・設計書内の「`config` パッケージ」という言及はそのまま有効
- depguard の対象パッケージ名 (`<module-path>/service` 等) は元々 `router` / `auth` / `logger` /
  `constants` / `config` / `di` を含んでいない。移動による `.golangci.yml` の変更は不要
- `layering-scopes.yml` の `common_layers` (`config` を含む) はトップレベルの層集合を指す設計側の写しで、
  ①の走査対象 (`usecase/` `service/` `repository/` の**2 段目**ディレクトリ名) とは別物 — 影響しない
  (同ファイルの注記を参照)

### 1.2 `.claude/` の配置 (雛形は `agents/` + backend 固有の `rules/05-architecture-coding-rules.md`。
共通 `rules/` `skills/` は立ち上げ時に合流)

**決定と立ち上げ手順の正は [`../../README.md`](../../README.md)** (本節は概要のみ。二重管理しない)。

- **`aidlc-planner` / `architecture-designer` / `design-reviewer` / `poc-analyst` は設計リポ (hassan_v3) 側に残す** —
  実装リポには持ってこない (設計判断は hassan_v3 で行う。役割分離は `.claude/rules/02-agents.md` と同じ理由)
- 本テンプレートが持つのは **実装リポ固有のエージェント** (`go-developer.md` / `code-reviewer.md`) と
  **backend 固有の `rules/05-architecture-coding-rules.md`** (層の責務・依存規則 L-1〜L-6・エラー契約・
  Managed Agent 運用・DB 変更フロー。frontend / infra には無い。旧 `CLAUDE.md` の埋め込み節を切り出した)。
  **3 リポ (backend / frontend / infra) で共通の rules・skills は `templates/shared/.claude/` にあり**、
  立ち上げ時に `.claude/rules/` `.claude/skills/` へコピーして合流させる
  (`cp -R templates/shared/.claude/{rules,skills} <impl-repo>/.claude/`)
- **`.claude/rules/feedback_review_patterns.md` は `templates/shared/.claude/rules/` 経由でコピーする**
  (他の共通 rules と同じ `cp -R` に含まれる)。**SSOT は設計リポ直下の `.claude/rules/feedback_review_patterns.md`**
  であり、`templates/shared/` 側はその同期コピー — 設計リポ側で更新したら
  `cp .claude/rules/feedback_review_patterns.md templates/shared/.claude/rules/` を同じ差分で実行し、
  同期を怠らないこと (`templates/README.md` が正)
- `.claude/settings.json` (エージェントの自律範囲) は雛形に置いていない — **立ち上げ時に作る**
  (許可 / 拒否の初期値は `shared/.claude/rules/04-human-checkpoints.md` §3.2 が正)

### 1.3 DTO と入出力構造体の置き場所 (決定の正: `architecture.md` §3.3)

**DTO (HTTP のリクエスト/レスポンス構造体) は `controller/dto/` に集約する** (v2 踏襲。
`hassan-v2-backend/controller/dto/` はドメイン別ファイル・1 パッケージ)。
**`usecase/<domain>/` や `service/<domain>/` が使う入出力構造体は DTO ではない** —
それぞれの UseCase / Service **自身が定義する**。

| 層 | 入出力構造体の置き場所 | 命名 | v2 の実例 |
|---|---|---|---|
| Controller | `controller/dto/<domain>.go` | `XxxReq` / `XxxRes` | `hassan-v2-backend/controller/dto/theme.go` |
| UseCase | `usecase/<domain>/<機能名>.go` (UseCase 本体と同じファイル。「1 エンドポイント = 1 ファイル」の原則) | `XxxInput` / `XxxOutput` | `hassan-v2-backend/usecase/theme/create_theme.go:18` の `CreateThemeInput` |
| Service | `service/<domain>/` 内、その振る舞いを持つファイル | 用途に応じた型名 (`TurnResult` 等。§3.8.1) | — (v2 に相当層が無いため v3 新規) |

- **DTO を UseCase / Service まで持ち込まない**。Controller のハンドラが DTO を bind した後、
  UseCase の入力型に変換して呼び出す (`hassan-v2-backend/controller/theme.go:137`〜)。
  **v2 実測: `usecase/` から `controller/dto` を import しているファイルは 0 件**
- 理由は UseCase / Service が HTTP の形に依存しないという層の禁止事項そのもの — DTO の
  バリデーションタグ (`binding:"required"` 等) がビジネスロジックの型に混入するのを防ぐ
- ドメイン型 (`ContractID` / `AccountID` 等) やツール結果の型 (`entity/toolresult`) はこの表の対象外 —
  それらは `entity/` に置く (§3.6 は IF の定義場所、本節は struct の定義場所という違いがある)

**バリデーションの責務分離 (同じ制約を DTO と entity の両方に書かない)**: DTO (`binding` タグ) は
**HTTP リクエストとして受理可能か** (必須・型・大まかな長さ) だけを検証し、**ドメインとして意味を持つ値か**
(許可された enum 値・複合的な整合性ルール) は **entity のコンストラクタ** (`func NewXxx(...) (Xxx, error)`)
が唯一の関所になる。v2 実例: `hassan-v2-backend/controller/dto/account.go:25` の
`binding:"required,min=8,max=255"` (パスワードの形式) に対し、
`hassan-v2-backend/entity/account.go:44` の `NewAccount` は `AuthRoleID` の enum 妥当性だけを検証し、
パスワードの長さは検証しない — **重複していない**。詳細と判断基準は `architecture.md` §3.3 が正。

## 2. ドメイン別ディレクトリ (第 1 リリース)

`usecase/` `service/` `repository/` `db/queries/` に置くドメインは
`layering-scopes.yml` の `v3_domains` と**完全に一致させる** (CI 検査 `D-2⑦` の条件 1)。
現在の骨格は **theme / asset / conversation / idea / plan** の 5 ドメイン。

| ドメイン | 主な担当 | 備考 |
|---|---|---|
| `theme` | テーマ管理 | — |
| `asset` | アセット管理・抽出 | Service 型名は `asset.Extractor` |
| `conversation` | 会話型アイデア創出 (Agent 実行) | Service 型名は `conversation.Runner` |
| `idea` | アイデアの版・タグ・評価 | — |
| `plan` | 企画書の生成・タブ | Service 型名は `plan.Composer` |

**Service の型名に `XxxService` を使わない** (振る舞いで命名する)。ディレクトリ名は `service/` のままでよい。

## 3. 名前が設計で固定されているファイル

新規に作るとき、**次のファイルは名前と置き場が決まっている** (CI 検査や設計の参照先になっているため、
勝手に変えると検査の除外パスや設計側の記述とずれる)。

| パス | 何を置くか | 名前が固定されている理由 |
|---|---|---|
| `controller/errresp.go` | `CodedError` → HTTP ステータスの変換関数 **1 本のみ** | CI の `D-2④` がこのパスだけを型アサーションの除外にしている。変えるなら `ci.yml` の除外パスも同じ PR で変える |
| `usecase/conversation/send_message.go` | 会話ターンの UseCase。`pgx.Tx` の実型を持つのはここだけ | 設計 §3.8.1 |
| `usecase/conversation/tool_registry.go` | `ToolHandlers(scope, deps)` — 所有者スコープをクロージャに束縛する **A-6 の束縛点** | 設計 §3.8.1 / §3.8.2 (束縛は 1 箇所のみ) |
| `service/conversation/tx.go` | `Begin` / `Commit` / `Rollback` を持たない narrow IF (`Exec` / `Query` / `QueryRow`) | 設計 §3.7 の 2 (L-6) |
| `service/conversation/runner.go` | `ToolHandler` 型と `RunTurn`。ツールループ・停止条件・安全弁・ターン集計 | 設計 §3.8.1 |
| `gateway/anthropic/session.go` · `stream.go` | SDK 呼び出しと SSE 受信。usage 4 カウンタと `stop_reason` を `CallMeta` に載せる | 設計 §3.8.1 (全 LLM 呼び出しの単一関門) |
| `entity/toolresult/` | ツール 1 本ごとの結果型 + 共通エンベロープ `Result` (`Payload` は marker interface) | 設計 §3.8.5 (BE-12)。書き手・読み手・テストが同じ宣言を使う |
| `common/di/provider.go` · `wire.go` · `wire_gen.go` | 依存グラフの組み立て。`wire_gen.go` は生成物で**手編集禁止** | v2 踏襲 (`hassan-v2-backend/di/`) |
| `prompts/agents.yaml` | Agent 名 → system prompt のパス + tool schema の列挙 | 再発行トリガのハッシュ対象。`check-tool-contract.sh` が実発行対象との一致を検査する |
| `testdata/golden/toolresult/<tool>.json` | 型から生成した golden。**手書きしない** | 設計 `testing.md` §5.3。CI の `make golden` + **`scripts/check-regen.sh backend/testdata/golden`** が再生成漏れを落とす (**新規 golden の追加漏れ**も見るため裸の `git diff` は使わない) |

### gateway に置くもの (第 1 リリース)

| パッケージ | 用途 |
|---|---|
| `gateway/anthropic` | Managed Agent + 直接 API。全 LLM 呼び出しの単一関門 |
| `gateway/exa` | 外部検索 (`research_market` / `deep_dive`) |
| `gateway/gemini` | 画像生成 (企画書サムネイル) |
| `gateway/mail` | メール送信 (招待・パスワードリセット)。dev / test はキャプチャ実装に差し替える |
| `gateway/s3` | ファイル保管と署名付き URL |

**埋め込み (RAG) のプロバイダは未選定**のためディレクトリを作っていない
(設計 `llm-migration.md` §9.1 の LM-Q6)。選定後に `gateway/<プロバイダ>` を足す。

### db/queries と db/rdb

`db/queries/<domain>/*.sql` → `db/rdb/<domain>` の 1 対 1 対応。
**`repository/<domain>` が import してよい生成パッケージは `db/rdb/<domain>` のみ**
(depguard の allow list に書く)。他ドメインのテーブルを主対象とするクエリを
`db/queries/<domain>/` に置かない — ドメインを跨ぐ読み取りは UseCase が両方の Repository を呼ぶ (L-2 / L-3)。

`db/rdb/` の中身は生成物なので、`.gitkeep` 以外は `make sqlc` が作る。

## 4. ドメイン / パッケージを追加するときの手順

**次の 3 つを同一 PR で更新する**。1 つでも欠けると CI が落ちる (落ちるのが正しい挙動)。

1. `layering-scopes.yml` の `v3_domains` (4 層 + entity + gateway で書くドメイン) または
   `ported_domains` (v2 の 3 層規約のまま移植するドメイン) に追記する
2. `.golangci.yml` に `L2-service-no-cross-domain-<domain>` 規則などを追加する
   (**`ported_domains` に入れたドメインは `.golangci.yml` に登録してはいけない** — 検査の条件 3)
3. 設計リポ `docs/design/architecture.md` §3.5.2 の対象パス表に追記する
   (`layering-scopes.yml` はこの表の機械可読な写しであり、決定の正は設計側)

`db/queries/<domain>/` を足すときは `sqlc.yaml` の出力設定と、
`repository/<domain>` の depguard allow list も同じ PR で更新する。

## 5. まだ作っていないディレクトリ

**API 設計上は存在するが、`layering-scopes.yml` に未登録のため骨格を作っていないドメインがある**。
先に §4 の登録を行ってからディレクトリを作ること (未登録のまま作ると `D-2⑦` の条件 1 で落ちる)。

| 未作成 | 何のためのものか | 登録が保留されている理由 |
|---|---|---|
| `knowledge` | ナレッジ (RAG チャット) の 15 本 | 移植ドメインの区分一覧が未確定 (設計 `architecture.md` §8) |
| `board` | アイデアボードの 18 本 | 同上 |
| `news` · `settings` | お知らせ 5 本 / 設定 6 本 | 同上 |
| `account` | 認証・アカウント基盤の 37 本 | 同上。`db/queries/account/` は v2 移植分として設計 `data-model.md` §3.6 に記載がある |
| `ops` | `llm_call_records` / `audit_logs` / レート制限 | 同上。ドメインではなく運用系のため、どの区分に置くかが未決 |

### OpenAPI 定義の出力先 (2026-08-03 に確定)

**`make docs` の生成先は `../api/openapi.yaml`** (app モノレポのルート直下 `api/`)。
**`backend/` の中には置かない** — `frontend/` の orval が入力として読むため、
**どちらのサブツリーにも属さない契約の置き場**として `api/` を切っている
(設計 `architecture.md` §3.11 / D-I。3 リポ構成では出力先も受け渡し方法も未確定だった)。

- **`api/openapi.yaml` は生成物。手編集しない**
- 再生成漏れは CI の `contract` ジョブ (MR-3) が落とす。
  検査は **`scripts/check-regen.sh api/openapi.yaml`** を通す —
  裸の `git diff --exit-code` は**未追跡ファイルを見ない**ため、
  **初回生成 (雛形の `api/` は `.gitkeep` のみ) が必ず素通りする**
