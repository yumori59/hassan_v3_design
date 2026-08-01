# 運用設計 (環境・シークレット・デプロイ・切替)

> 本書が回答する本番観点: **D-1 / D-3 / D-5 / D-7** (+ 部分回答: **D-4** の自動適用範囲のみ / **O-7** の通知先の形)
> 対応する受入基準: **AC-3.1 / AC-3.3 / AC-3.5 / AC-3.7**
> 前提とする事実 (実測・抜き取り検証済み): [v2-deploy-observability.md](../analysis/v2-deploy-observability.md)
> 必須観点の ID 一覧: [08-production-gates.md](../../.claude/rules/08-production-gates.md)

## 0. 本書の位置づけと SSOT 境界

本書は **「どの環境に・どの値を・どの順で・誰の承認で適用するか」** の SSOT である。
次は他が正であり、**本書では再定義しない** (参照のみ):

| 事項 | SSOT |
|---|---|
| 人間の承認点 (H-1〜H-5)・承認機構 (GitHub environment / ブランチ保護 / deny 設定)・破壊的マイグレーションの**機械判定の定義** | [templates/shared/.claude/rules/04-human-checkpoints.md](../../templates/shared/.claude/rules/04-human-checkpoints.md) |
| デプロイパイプラインの実体 (6 ジョブ・承認位置・出力契約) | [templates/backend-repo/.github/workflows/deploy.yml](../../templates/backend-repo/.github/workflows/deploy.yml) |
| CI ゲートの内容 (D-2) とループ上の位置 | [templates/shared/.claude/rules/01-construction-loop.md](../../templates/shared/.claude/rules/01-construction-loop.md) §7 + [templates/backend-repo/.github/workflows/ci.yml](../../templates/backend-repo/.github/workflows/ci.yml) |
| 層配置・設定値の SSOT 規約 (`config` パッケージ)・シークレット注入方式の決定 (D-5) | [architecture.md](architecture.md) §3.9② / §5 の D-5 行 |
| アラートの監視対象としきい値 (AL-1〜AL-7)・ログ/計測の項目 | [observability.md](observability.md) §4.4 / §4.6。**ただし重大度の分類・環境差・SNS トピックの本数は本書 §7.5 が SSOT** (同節に記述が無いため本書で決める) |
| JWT 署名鍵の固有事情 (新規発行・複数鍵ローテーション) | [auth.md](auth.md) §6.8 |
| インフラ構成要素・Terraform の管理範囲 (D-8 / AC-3.6)・**環境ごとのリソース差分と FE/BE の環境対応** | [infrastructure.md](infrastructure.md) §3〜§7 (§5.2 = 環境差の初期値 / §5.3 = FE/BE 対応 / §7 = IaC 範囲外) |
| DB マイグレーションの方式・後方互換・ロールバック手順 (AC-3.4) | [data-model.md](data-model.md) §6。**本書は「自動適用してよい範囲」(AC-3.7) のみを定める** |
| 移行するデータの対象と写像 (AC-3.5 のデータ移行方式) | `docs/design/data-model.md` (Q-1 のデータ引き継ぎ範囲が未確定。§6.2) |

## 1. 現状 (v2) と継承可否

> 本節が回答する ID: なし (事実の整理)

事実の出典は [v2-deploy-observability.md](../analysis/v2-deploy-observability.md) に集約する。
**「v2 に合わせる」を省略の理由にできない領域**を明示するために要点のみ再掲する:

| # | v2 の現状 | 出典 | v3 で継承するか |
|---|---|---|---|
| 1 | dev = `main` への push で自動デプロイ / prod = `workflow_dispatch` に git タグを渡す手動デプロイ | `hassan-v2-backend/.github/workflows/dev-deploy.yml` / `hassan-v2-backend/.github/workflows/prod-deploy.yml` | **形は継承** (dev 自動 / prod 手動)。ただし prod は「タグ指定」ではなく `main` 限定 + environment 承認にする (§5.1) |
| 2 | CI が `stacks/{dev,prod}/ecs-task-def.json` の image タグを書き換え **`main` に直接コミット・push する** | 同 `dev-deploy.yml:35-45` | **継承しない** (C-14。CI 内でレンダリング) |
| 3 | シークレットは ECS の `secrets` を使わず、`env/.dev.env` / `env/.prod.env` を **Docker イメージに焼き込み、dev/prod で同一イメージを共有** | `hassan-v2-backend/stacks/ecs.Dockerfile` (`COPY . .`) / `hassan-v2-backend/.dockerignore` (除外は `vendor` のみ) / `hassan-v2-backend/di/provider.go:83-94` | **継承しない** (§4) |
| 4 | 環境ファイル 3 本 (`hassan-v2-backend/env/.dev.env` 等) が **git 追跡下** | 同分析 §5 | **継承しない**。v3 の鍵は新規発行 ([auth.md](auth.md) §6.8-2) |
| 5 | 明示的なロールバック手順・ワークフローが無い (`deploymentCircuitBreaker` の自動戻しのみ) | `hassan-v2-backend/stacks/prod/ecs-service-def.json` | **継承しない** (§5.3 で手順化) |
| 6 | IaC が存在しない (VPC / ALB / RDS / IAM はコンソール手作業) | 同分析 §8 | **継承しない** (C-7 / C-14) |
| 7 | prod は `desiredCount: 1` / コンテナヘルスチェック無し | 同分析の抜き取り検証 | **継承しない** (§5.1 の前提。値の決定は `docs/design/infrastructure.md`) |
| 8 | 環境の切替キーは `GO_ENV` (どの `.env` を読むか) と `APP_ENV` (アプリ内分岐) の**2 変数**で、参照元が異なる | 同分析 §4 補足 | **継承しない** (§3.1 で 1 変数に統一) |

PoC 側: `claude_managed_agents/internal/config/dotenv.go` の `WriteEnv` は固定キーのみを書き戻すため
他のキーが消える (BE-3)。**`.env` をプログラムが書き換える方式は v3 で採らない** (§4.4)。

## 2. 設計判断

> 本節が回答する ID: **D-1 / D-3 / D-5 / D-7** (各判断の詳細は §3〜§7)

| # | 論点 | 採用案 | 却下案と理由 |
|---|---|---|---|
| OP-A | 環境の数と FE/BE の対応 | **local / dev / prod の 3 環境** (ユーザー指定)。FE は **Vercel の 1 プロジェクト**で `Development` / `Preview` / `Production` の 3 スコープを使い、**Preview = dev / Production = prod** に対応させる (§3.2) | (a) `main` を Vercel の Production Branch にする: H-4 (本番昇格を人間の操作にする) が消える — 04 §2.4 の確定に反する。(b) dev 用に別 Vercel プロジェクトを作る: ビルド設定と環境変数が二重管理になり、`production` ブランチ保護 (04 §4.1) との対応も二重化する。Preview スコープで同じ分離が得られる。(c) Vercel の Custom Environments を追加する: 設定要素が増えるだけで、3 環境では Preview / Production の 2 スコープで表現できる |
| OP-B | 設定値の置き場 | **5 分類に固定する**: ①**コード内定数** (環境で変わらない値) ②**ECS タスク定義の `environment`** (非秘密で環境ごとに変わる値。Terraform / ecspresso が管理) ③**Secrets Manager** (秘密。起動時に解決) ④**SSM Parameter Store で実行中に読み替える値** (非秘密で**再デプロイなしに変えたい**値) ⑤**SSM Parameter Store に置くが起動時に 1 回だけ解決する値** (**Agent ID / Environment ID**。版履歴を切り戻し手段に使う)。読み出しは `config` パッケージのみ ([architecture.md](architecture.md) §3.9②) | (a) `.env` をイメージに焼く (v2 方式): イメージを取得できる範囲すべてに秘密が渡り、dev/prod の分離も失われる。(b) すべてを Secrets Manager に入れる: 非秘密値の変更にも秘密の変更手順 (承認・監査) が掛かり、運用が重くなる。(c) すべてを ECS の `environment` に入れる: 秘密がタスク定義とコンソールの表示に残る。(d) **⑤ を作らず Agent ID / Environment ID を ④ (実行中に読み替える) に置く**: `apply_agent` は `release` より前に走るため、**稼働中の旧コードのタスクが最大 60 秒後に新 Agent を掴み「旧コード + 新 tool schema」という組み合わせが必ず発生する** (prod では H-3 承認から H-4 承認までの待ち時間ぶん継続する)。BE-8 (新しい引数が黙って捨てられる) / BE-10 (台帳の前提チェックが常に失敗する) の窓を設計自身が作ることになる |
| OP-C | シークレットの粒度 | **用途単位で 1 シークレット** (`/hassan-v3/<env>/db/url` `.../auth/jwt-key` `.../anthropic/api-key` …) | (a) 環境ごとに 1 つの JSON シークレットへまとめる: 参照は減るが、**IAM を用途別に絞れず**、1 つのローテーションが全参照者を巻き込む。JWT 鍵 ([auth.md](auth.md) §6.8) と LLM キーは漏洩時の影響が別物なので分ける |
| OP-D | ローカル開発の値 | **開発者が手で作る `.env.local` (git 管理外) に dev 相当の値を置く**。**prod の値は誰のローカルにも置かない** (04 §3.3 と同じ線) | (a) Secrets Manager から取得するスクリプトを配る: 開発者全員に AWS 認証情報が必要になり、退職時の失効漏れが「秘密の失効漏れ」になる。(b) PoC の `WriteEnv` 方式でプログラムが `.env` を書き換える: BE-3 (キー脱落) が再発し、`DATABASE_URL` の消失が静かなデータ喪失につながる |
| OP-E | Managed Agent ID と **Environment ID** の保管 | **SSM Parameter Store** (`/hassan-v3/<env>/agent/<name>/id` / `/hassan-v3/<env>/anthropic/environment-id` / `/hassan-v3/<env>/agent/<name>/source-hash`)。**バージョン履歴を旧 ID への切り戻し手段として使う** (§5.3)。**反映は次のタスク起動時** (§3.3 の⑤) | (a) Secrets Manager: Agent ID / Environment ID は秘密ではなく、版の扱いが `AWSCURRENT` / `AWSPREVIOUS` の 2 段に限られる。(b) リポジトリにコミットする (PoC の `.env` 相当): 環境ごとに値が違うため衝突し、`main` へのデプロイ用コミットが復活する (C-14 で廃止した運用)。**PoC は `AGENT_ID` と `ENVIRONMENT_ID` を対で `.env` に置いており** (`claude_managed_agents/internal/config/config_test.go:37`)、**Environment ID が未設定なら実行時にエラーを返す必須設定である** (`claude_managed_agents/cmd/devui/domain_discovery.go:453`) — したがって Agent ID だけを管理対象にすると必須設定が引き渡しから落ちる |
| OP-F | デプロイの起動方法 | **BE = `deploy.yml`** (dev は `main` への push で自動 / prod は `workflow_dispatch` + `main` 限定 + environment 承認)。**FE = Vercel の Git 連携** (`main` → Preview 自動 / `production` → Production)。**infra = 人間が `terraform apply`** | (a) FE も GitHub Actions から Vercel CLI で deploy する: Vercel の Promote / Instant Rollback (§5.3) を捨てることになり、**最短のロールバック手段が失われる**。(b) infra の `apply` を CI に持たせる: `replace` が RDS / ECS の作り直しになる経路を機械に任せることになる (04 §1.1 の注記) |
| OP-G | ロールバックの第一手段 | **前のバージョンへ戻す操作**を第一手段にする: BE = `ecspresso rollback` / FE = Vercel の前デプロイを Promote / Agent = SSM の前バージョンの ID に戻す / DB = 非破壊は戻さない・破壊的はスナップショット復元 (04 §2.2) | (a) `git revert` + 再デプロイを第一手段にする: ビルド時間ぶん障害が延びる。revert は**戻した後の是正手段**として使う。(b) `deploymentCircuitBreaker` の自動戻しだけに頼る (v2 の実態): ヘルスチェックが通る種類の不具合 (誤ったレスポンス・越境) では発火しない |
| OP-H | 環境戦略 (ブランチ運用) | **trunk-based + 環境変数フラグ** (questions.md Q-8 の推奨案 A。**暫定既定 — Q-8 は未回答**。§7.1) | (a) release ブランチ運用 (B): cherry-pick 漏れとマージ衝突が恒常化する。(b) 環境ごとにブランチを固定 (C): dev ブランチと `main` の差分が育ち、「dev で検証済み」の意味が薄れる。**回答が A 以外になった場合、§7.1〜§7.3 を差し替える** |
| OP-I | フラグの実装形態 | **環境変数のみ** (BE = ECS タスク定義の `environment` → `config`、FE = Vercel の環境変数)。**判定の正は BE** (フラグ OFF のエンドポイントは 404)。FE は導線を隠すだけ。**フラグを API で配らない** | (a) `GET /features` のような API で配る: API 契約 ([API/README.md](API/README.md) の 6 ドメイン — 本数は同書 §3 が正) に**第 1 リリースまでの一時的な仕組み**を載せることになり、削除時に破壊的変更になる。(b) `feature_flags` テーブル (DB) で持つ: アカウント単位の限定公開が要るときの方式だが、C-11 (全面切替) では要求が無い。**必要になった時点で移行する** (移行の契機: 特定アカウントだけに機能を出す要求が発生したとき) |
| OP-J | DB マイグレーションの自動適用範囲 | **非破壊 × dev のみ自動**。破壊的変更は environment 承認 (04 §2.2 が判定と承認先の SSOT)。加えて **破壊的変更は「2 段階リリース (拡張 → 縮小)」を必須**とする (§7.4) | (a) 全て手動承認: dev への継続デプロイ (C-15) が人間律速になり、1 日に複数回の検証が回らない。(b) 全て自動適用: dev の検証データ (会話ログ・生成物) が消えると受入確認そのものができない (04 §1.1 の注記と同じ線引き)。(c) アプリ起動時に自動適用 (PoC 方式): ECS の複数タスク起動時に同時適用が競合する |

## 3. 環境 (D-1 / AC-3.1)

> 本節が回答する ID: **D-1** / 対応 AC: **AC-3.1**

### 3.1 3 環境の定義

| 環境 | 用途 | BE の実行場所 | DB | LLM | 誰が変更を入れられるか |
|---|---|---|---|---|---|
| **local** | 開発者の手元。UT と手動確認 | ローカルプロセス (docker compose の PostgreSQL) | ローカル | **dev と同じ Anthropic 組織の dev 用キー**。Agent ID は **dev の値を共有** (再発行は CI のみ) | 開発者本人 |
| **dev** | 継続デプロイと受入確認 (C-15) | AWS ECS (dev クラスタ) | RDS (dev インスタンス) | dev 用キー / dev の Agent ID | `main` へのマージ (承認は H-1 のみ) |
| **prod** | 本番 | AWS ECS (prod クラスタ) | RDS (prod インスタンス) | prod 用キー / prod の Agent ID | H-4 の承認を得た手動起動のみ |

- **環境の識別は `APP_ENV` の 1 変数に統一する** (`local` / `dev` / `prod`)。
  v2 は `GO_ENV` (どの `.env` を読むか) と `APP_ENV` (アプリ内分岐) が別変数で、
  ログ出力の抑制条件が両者に分かれていた (§1 の 8)。**v3 は `.env` ファイルを読まないため
  「どのファイルを読むか」の変数が不要**になり、1 変数で足りる
- **`APP_ENV` による挙動分岐は次の 2 つに限定する**: ①ログレベル (prod=info / dev,local=debug。
  [observability.md](observability.md) §2 の O-A) ②Swagger UI の公開 (prod では無効)。
  **リクエストログ・LLM 計測・監査ログは環境で分岐させない** (v2 は prod でリクエストログを出していない。
  [observability.md](observability.md) §1)
- dev と prod は **同一の Terraform モジュールに変数差分のみを与えて作る** (`envs/dev` / `envs/prod`)。
  **差分の付け方と初期値 (タスク数・サイジング・ログ保持・WAF のモード等) は
  [infrastructure.md](infrastructure.md) §5.1 / §5.2 が SSOT** — 本書では再掲しない

### 3.2 FE (Vercel) と BE (AWS) の環境対応 — 運用ルール

**論理環境と FE / BE の対応表そのものは [infrastructure.md](infrastructure.md) §5.3 が SSOT**
(local / dev = `main` の Preview / prod = `production` の Production)。
本節は**その対応を運用で崩さないためのルール**と、対応表に無いデプロイ契機を定める:

| Vercel のスコープ | 対応する論理環境 | デプロイ契機 | 登録してよい値 |
|---|---|---|---|
| `Development` | local | 開発者の操作 (`next dev`) | 開発者の `.env.local` (API ベース URL は local または dev) |
| **`Preview`** | **dev** | `main` および feature ブランチへの push (自動) | **dev の API ベース URL のみ** |
| **`Production`** | **prod** | `main` → `production` の PR マージ + Promote (H-4) | prod の API ベース URL |

- **FE の環境は 2 系統 (Preview / Production) しか無い**ため、`Preview` を dev に固定する。
  この対応関係が崩れる唯一の経路は「Preview の環境変数に prod の API ベース URL を入れる」ことなので、
  **prod 向けの値を `Preview` スコープに登録しない**ことを運用ルールにする
- **feature ブランチの Preview も dev の BE を指す** — dev の BE は不特定の Preview から呼ばれる前提で扱う
  (dev に本番データを置かない理由の 1 つ。§10.4 の仮定)。
  Preview の URL が変動する場合の CORS 許可の扱いは [infrastructure.md](infrastructure.md) §5.3 の確認事項
- **秘密情報を `NEXT_PUBLIC_*` に置かない** (ブラウザバンドルに載る。
  [templates/frontend-repo/CLAUDE.md.tmpl](../../templates/frontend-repo/CLAUDE.md.tmpl) の Vercel 節)。
  FE が必要とする秘密 (存在する場合) は Server Actions / Route Handler 側の環境変数に置く
- **infra リポは環境の概念を `envs/<env>` で持つ**。**Vercel の設定は Terraform 管理外**
  ([infrastructure.md](infrastructure.md) §7 の X-5。理由: H-4 の承認機構が Vercel 側の Promote 権限と
  ブランチ保護で担保されているため、provider で二重管理すると承認の所在が分かれる) —
  したがって上表の登録は **04 §4.4 の人手チェックリスト**で担保する

### 3.3 設定値の持ち方 (OP-B の 5 分類)

| 分類 | 置き場 | 変更手順 | 反映のタイミング | 例 |
|---|---|---|---|---|
| ① コード内定数 | Go のコード (`config` パッケージ) | PR → マージ → デプロイ | デプロイ時 | HTTP / LLM のタイムアウト、リトライ回数、`MaxTokens`、生成数の既定と上限 (BE-2) |
| ② 非秘密の環境値 | **ECS タスク定義の `environment`** (backend リポの `stacks/<env>/` にある ecspresso のタスク定義テンプレート) | **値の出所で手順が分かれる**: **インフラ由来の値** (RDS ホスト名・S3 バケット名・ロググループ名) は Terraform の出力を ecspresso が tfstate から解決するため **infra の PR → `apply`** / **アプリ由来の値** (`APP_ENV`・既定モデル名・**フィーチャーフラグ**) は **backend の PR → デプロイ**のみ | デプロイ時 | `APP_ENV`、RDS のホスト名 (インフラ由来)、S3 バケット名 (インフラ由来)、**フィーチャーフラグ** (アプリ由来。§7.2)、用途別の既定モデル名 (アプリ由来) |
| ③ 秘密 | **Secrets Manager** (ARN をタスク定義の `secrets` で注入。[architecture.md](architecture.md) §5 の D-5) | §4.2 の手順 | **次のタスク起動時** (= デプロイまたはタスク置換) | `DATABASE_URL`、JWT 署名鍵、Anthropic / Exa / Resend / MicroCMS の API キー |
| ④ 再デプロイなしに変えたい非秘密値 | **SSM Parameter Store** (`/hassan-v3/<env>/...`) | パラメータ更新のみ (デプロイ不要) | **最大 60 秒** (`config` が TTL 60 秒でキャッシュし再取得する) | **暴走の安全弁のしきい値** ([observability.md](observability.md) §4.4 — 「再デプロイなしで変更できる形にする」への回答)、**単価テーブルの版** (同 O-H)、非同期ジョブの失効しきい値 |
| ⑤ **起動時に 1 回だけ解決する非秘密値** (版履歴を切り戻し手段に使う) | **SSM Parameter Store** (`/hassan-v3/<env>/agent/<name>/id` / `/hassan-v3/<env>/anthropic/environment-id`) | `apply_agent` (CI) がパラメータの新バージョンを書く (§5.2) | **次のタスク起動時**。**プロセスは起動時に読んだ値を保持し続け、実行中は再取得しない** | **Agent ID** / **Environment ID** (OP-E)。同じパス階層に置く**発行元ハッシュの記録** (`.../agent/<name>/source-hash`) は CI だけが読み書きし、アプリは読まない |

- **同じ値を 2 つの分類に置かない**。①〜⑤のどれに置くかは `config` パッケージの定義が正
  ([architecture.md](architecture.md) §3.9②)。**他のパッケージが `os.Getenv` を直接呼ぶことは CI で禁止**
- ④ は**アプリが実行中に値を読み替える**ため、**変更が反映されたことをログで確認できる形にする**
  (`config` が値の変更を info ログに 1 行出す)。反映の確認手段が無い設定は運用で使えない
- **④ に置いてよい値の判定基準 (これを満たさない値は ⑤ か ② に置く)**:
  **稼働中の旧コードがその値の「旧い版」で動き続けても壊れず、かつ新しい値をコード変更なしで解釈できる**こと。
  しきい値・件数・単価テーブルの版はこれを満たす (どちらの値でも旧コードは正しく動く)。
  **Agent ID / Environment ID は満たさない** — コードが期待する tool schema と Agent の schema が
  1 対 1 に対応するため、値だけが先に切り替わると引数が黙って捨てられる (BE-8) /
  台帳の前提チェックが常に失敗する (BE-10)。**この 2 つは ⑤ に置き、タスク置換と同時に切り替える** (§5.2 / §5.3)
- FE が必要とする上限値 (生成数など) は **API レスポンスに含めて配る** (BE-2 の再発防止。
  [architecture.md](architecture.md) §3.9②)。Vercel の環境変数に**同じ値を二重に持たせない**

## 4. シークレット管理 (D-5 / AC-3.1)

> 本節が回答する ID: **D-5** / 対応 AC: **AC-3.1**
> 注入方式の決定 (Secrets Manager → ECS タスク定義の `secrets`) は [architecture.md](architecture.md) §5 の D-5 が SSOT。
> 本節は**運用手順** (登録・変更・ローテーション・ローカル開発・棚卸し) を定める。

### 4.1 経路 (誰が読むか別)

| 読み手 | 経路 | 認証 |
|---|---|---|
| **ECS のアプリ** | Secrets Manager → タスク定義の `secrets` で環境変数として注入 (値はタスク起動時に解決) | タスク実行ロール (`ecsTaskExecutionRole` 相当) に**当該シークレットの ARN のみ**を許可 |
| **ECS のアプリ (④ の可変値 / ⑤ の起動時解決値)** | SSM Parameter Store を SDK で読む (④ は実行中に再取得 / ⑤ は起動時に 1 回) | タスクロールに `/hassan-v3/<env>/*` の読み取りを許可 |
| **CI (`deploy.yml`)** | **OIDC で AWS ロールを引き受け、値は AWS 側から取る**。GitHub 側に持つのは下記の限定列挙のみ (5 つの environment に紐づく environment secret / variable として登録。environment の一覧は 04 §4.2) | OIDC。長期アクセスキーを置かない (v2 は長期キー運用) |
| **運用者 (障害対応)** | **AWS 権限を持つのは、GitHub の `prod*` environment の承認者に設定された者に限る**。ロールバックも AWS コンソール / CLI ではなく **CI の `rollback.yml` (workflow_dispatch)** から起動する (§5.3) | OIDC (CI 経由)。**個人に長期の AWS 認証情報を配らない** |
| **開発者 (local)** | 手で作る `.env.local` (git 管理外) | AWS 認証情報を配らない (OP-D) |

**CI が GitHub environment secret / variable として保持してよい値 (限定列挙。これ以外を置かない)**:

| 置いてよい値 | 理由 | 種別 |
|---|---|---|
| **AWS の IAM ロール ARN** (`deploy` / `migration` 用。環境ごとに別ロール) | OIDC でロールを引き受けるための宛先であり、それ自体では何もできない。環境ごとに値が違うため environment に紐づける | variable でよい (秘密ではない) |
| **AWS リージョン / ECR リポジトリ名 / ECS クラスタ名 / ecspresso の設定パス** | デプロイ先の識別子。秘密ではない | variable |
| **`E2E_DISPATCH_TOKEN`** (backend → frontend リポへの `repository_dispatch` 送信用。**唯一の例外** — 2026-07-31 のユーザー回答 = [testing.md](testing.md) §13.1 T-Q5 の案 A) | E2E を「dev デプロイ完了」で自動起動するために必要で、AWS 側から取得できる値ではない。**dev environment のみ・frontend リポの dispatch 権限のみに絞った fine-grained トークン**に限定する | secret (**例外はこの 1 件だけ**。増やす場合は本表への追記 + レビューを必須とする) |

- **置かない値 (実行時に AWS から取得する)**: **DB 接続情報** (`DATABASE_URL`) /
  **Anthropic API キー** / **Agent ID・Environment ID**。
  - `DATABASE_URL` は **`apply_migration` を ECS RunTask 方式にした結果、CI が持つ必要が無くなった**
    (マイグレーション実行タスクが Secrets Manager から `secrets` で受け取る。§5.1 / [infrastructure.md](infrastructure.md) INF-H)
  - `ANTHROPIC_API_KEY` は `apply_agent` が **OIDC ロールの `secretsmanager:GetSecretValue` で取得する**
    (`/hassan-v3/<env>/anthropic/api-key`)
  - Agent ID / Environment ID は **SSM が唯一の所在** (OP-E)。CI は SSM に書き、アプリは SSM から読む
- **この規則を置く理由**: 同じ値を GitHub secret と Secrets Manager / SSM の両方に持つと、
  §4.3 のローテーション (Secrets Manager 更新 → タスク置換) を実施しても **GitHub 側が古いまま残り、
  次の `apply_migration` / `apply_agent` が旧値で動く** (原因の分かりにくい失敗になる)。
  Agent ID が 3 箇所に存在すると §5.3 の切り戻し (SSM の前バージョンへ戻す) が
  「どこを戻せば効くのか」を運用者が判断できない。**BE-2 (設定値の SSOT 不在) の再演を避ける**
- **04 §4.2 の「保持するシークレット」列は本節に合わせて是正済み** (2026-07-30。§9 の引き渡しに経緯を記載)。
  **04 §2.6 の H-3 行の二重化列も 2026-07-30 に是正済み** (「Secrets Manager が唯一の所在。`apply_agent` は OIDC ロールで取得する」へ差し替え。OP-F3 解消)。

### 4.2 登録と変更の手順

| 操作 | 手順 | 実行者 |
|---|---|---|
| **新規のシークレットを追加する** | ①infra リポで Secrets Manager のリソースを作る PR (**値は入れない**。`ignore_changes` で値を Terraform 管理外にする) → ②人間が `apply` → ③人間が AWS コンソール / CLI で値を投入 → ④backend リポで `config` の項目とタスク定義の `secrets` を追加する PR → ⑤デプロイ | infra PR + 人間の `apply` + backend PR |
| **値を変更する** | Secrets Manager の値を更新 → **タスクを置き換える** (`ecspresso deploy` または `ecspresso refresh` 相当の再デプロイ)。**値の更新だけでは稼働中タスクに反映されない** | 人間 (prod は H-4 に相当する判断) |
| **削除する** | ④の逆順 (コードの参照を消してデプロイ → シークレットを削除)。**参照が残った状態で削除するとタスクが起動しなくなる** | backend PR → infra PR |

- **値を Terraform の state に入れない**。tfstate に平文で残り、PR の `plan` 出力に出る経路も生まれる。
  **器 (名前 / KMS / IAM) = Terraform、値 = Terraform 管理外**という線は
  [infrastructure.md](infrastructure.md) §7 の X-2 で「IaC 範囲外」として理由付きで確定済み。
  本書はその上で**誰がいつ値を入れるか**を上表で定める

### 4.3 ローテーション

| 対象 | 方式 | サービス停止 |
|---|---|---|
| **JWT 署名鍵** | **検証時に複数鍵を許容する** (新鍵で署名・旧鍵でも一定期間検証)。手順と根拠は [auth.md](auth.md) §6.8-3 | 無し |
| **DB のパスワード** | ①新パスワードを Secrets Manager の新バージョンとして投入 → ②RDS のユーザーパスワードを変更 → ③タスク置換。**①〜③の間は旧タスクが旧パスワードで接続を維持している**ため、②の直後に③を行う | 短時間の接続エラーが起き得る。**prod は H-4 と同じ承認を経て実施する** |
| **外部 API キー** (Anthropic / Exa / Resend / MicroCMS) | ①提供者側で新キーを発行 (旧キーは有効なまま) → ②Secrets Manager を更新 → ③タスク置換 → ④動作確認後に旧キーを失効 | 無し (**新旧が同時に有効な期間を作る**のが条件) |
| **AWS の権限** | 長期アクセスキーを持たない (OIDC) ため、ローテーション対象にしない | — |

- **ローテーションの定期実行は設けない**。実行契機を「漏洩の疑い / 担当者の離任 / 提供者からの要請」に限る。
  理由: 定期実行は**手順が確立していないと定期的な障害要因になる**。上記 3 手順は
  「新旧が同時に有効な期間を作れるか」で成否が決まり、DB パスワードだけが作れない
- **v2 の鍵の値を v3 へ移設しない** ([auth.md](auth.md) §6.8-2。v2 の環境ファイルは git 追跡下)

### 4.4 ローカル開発時の扱い

- 各リポジトリに **`.env.example` (キー名と説明のみ・値なし)** を置き、`.env.local` は git 管理外にする
- **local に置いてよい値**: dev の DB (ローカルの docker compose) / dev 用の外部 API キー /
  dev の Agent ID と Environment ID。**置いてはいけない値**: prod のいずれか
  (04 §3.3 の「認証情報の非配置」と同じ線)
- **プログラムが `.env` を書き換えない** (BE-3)。Agent ID / Environment ID が変わった場合は
  開発者が `.env.local` を手で直す (dev の値は SSM から `aws ssm get-parameter` で読める)
- **開発者専用 Agent (§5.2 の例外) を作った場合の扱い**:
  - **ID の置き場は作った開発者の `.env.local` のみ**とする (SSM に書かない。
    SSM の dev のパスは共有 Agent の唯一の所在であり、個人の試行で上書きしない)
  - **削除の責任者は作った開発者本人**。作成時に **Agent の名前へ `dev-<GitHub ユーザー名>-` を接頭辞として付ける**
    ことを規約にし、**RL-2 の棚卸し (§6.1 の完了条件②) で接頭辞付きの Agent が残っていたら作成者に削除させる**。
    削除の期限は「その試行に対応する PR がマージまたはクローズされた時点」とする
- **依存が欠けたら起動時に失敗させる** (BE-5。`config` の必須項目が未設定ならプロセスを起動しない)。
  DB 未接続でインメモリ動作するフォールバックを持たない

### 4.5 棚卸し (追加漏れを防ぐ運用)

| カテゴリ | 例 | 分類 (§3.3) |
|---|---|---|
| DB | 接続文字列 | ③ |
| 認証 | JWT 署名鍵 (ユーザー用 / 管理者用の 2 本。[auth.md](auth.md) §6.8-4) | ③ |
| LLM | Anthropic API キー / 用途別の既定モデル名 / **Agent ID** / **Environment ID** (Anthropic の実行環境。PoC では必須設定 — OP-E) / **Agent 発行元のハッシュ記録** (CI のみが読み書き) | ③ (キー) / ② (モデル名) / ⑤ (Agent ID) / ⑤ (Environment ID) / ⑤ と同じパス階層 (ハッシュ記録) |
| 外部 API | 検索 (Exa) / メール送信 / CMS のキーとエンドポイント | ③ (キー) / ② (エンドポイント) |
| 運用 | 安全弁のしきい値 / 単価テーブルの版 / フラグ | ④ / ④ / ② |

**運用ルール**: **新しい設定値を追加する PR は、`config` の定義と §3.3 の分類の対応を PR 本文に書く**。
分類が書かれていない追加は H-1 (PR マージ) で approve しない。
v2 は設定が 51 キーに達した時点で秘密と非秘密が同じ `.env` に同居していた (§1 の 3) ため、
**分類の宣言を追加時点で強制する**。

## 5. デプロイ手順 (D-3 / AC-3.3)

> 本節が回答する ID: **D-3** / 対応 AC: **AC-3.3**
> 承認点 (H-2 / H-3 / H-4) の定義・確認観点・機構は
> [04-human-checkpoints.md](../../templates/shared/.claude/rules/04-human-checkpoints.md) が SSOT。
> ジョブ構成の実体は [deploy.yml](../../templates/backend-repo/.github/workflows/deploy.yml)。

### 5.1 リポジトリごとの手順

**BE (backend リポ)** — `deploy.yml` の 6 ジョブ。**この順序を変えない**:

```
build (イメージ) → plan_migration → apply_migration (H-2) → plan_agent → apply_agent (H-3) → release (H-4)
```

| 環境 | 起動 | 承認 | 備考 |
|---|---|---|---|
| dev | `main` への push (自動) | 非破壊マイグレーションと Agent 再発行は自動 / **破壊的マイグレーションのみ承認** (`dev-db-destructive`) | C-15 の継続デプロイを人間で律速させない |
| prod | `workflow_dispatch` (手動) | `prod-db` / `prod-agent` / `prod` の 3 段 | **`main` 以外の ref からの prod 起動は最初のジョブで失敗する** (04 §2.4) |

**各ジョブの実行場所と DB への到達経路 (この形以外で実装しない)**:

| ジョブ | 実行場所 | DB / 外部への到達 |
|---|---|---|
| `build` | GitHub ランナー | ECR への push のみ |
| `plan_migration` | GitHub ランナー + **必要なら ECS RunTask (mode=plan)** | **差分生成が DB 接続を要する方式 (現行スキーマとの比較・適用済みバージョンの問い合わせ) を選んだ場合、`apply_migration` と同じ RunTask 経路で実行する**。ランナーから RDS へ接続しない |
| `apply_migration` (H-2) | **ECS RunTask** (マイグレーション実行専用タスク定義。VPC 内 private subnet) | **①RunTask 起動 → ②完了待ち (タスクの `lastStatus=STOPPED` をポーリング) → ③終了コードの判定 → ④CloudWatch Logs の取得**。接続情報は**タスク定義の `secrets`** で Secrets Manager から注入する |
| `plan_agent` | GitHub ランナー | **SSM の発行元ハッシュ記録の読み取りのみ** (Anthropic API を呼ばない) |
| `apply_agent` (H-3) | GitHub ランナー | Anthropic API (インターネット経由) + SSM への書き込み。**API キーは OIDC ロールで Secrets Manager から取得する** (§4.1。GitHub 側に置かない) |
| `release` (H-4) | GitHub ランナー | `ecspresso deploy` (ECS API) |

- **`apply_migration` を GitHub ランナーから直接 DB に接続する形で実装しない**。RDS は private subnet に
  あり ([infrastructure.md](infrastructure.md) INF-F)、到達させるには **RDS をパブリックアクセス可にする**
  しかないが、これは INF-H が却下案 (b) として明示的に退けた案である
- **④のログ取得は成否によらず行う** (`if: always()` 相当)。ジョブサマリに出力を貼る —
  RunTask 方式は「タスクが失敗した」だけがジョブの結果に出るため、**ログを取らないと失敗理由が読めない**
- **完了待ちのタイムアウトは AWS CLI の既定 (`aws ecs wait tasks-stopped` = 6 秒 × 100 回 = 約 10 分) に
  依存させない**。マイグレーションの所要が 10 分を超え得るため、**ポーリング間隔と上限をワークフロー側の
  変数で明示する** (既定値 1800 秒。超過時はジョブを失敗させ、タスクの状態をログに出す)

**FE (frontend リポ)**: `main` への push で Preview (dev 相当)。本番は `main` → `production` の PR を
マージし、**人間が Promote する** (H-4)。ビルドとデプロイは Vercel が行う (GitHub Actions からは起動しない。OP-F)。

**infra (infra リポ)**: PR で `terraform plan` を CI が出し、**dev / prod とも人間が `apply` する**
(実行主体の表は [infrastructure.md](infrastructure.md) §4.4)。
`destroy` / `replace` が 1 件でもある場合は理由を説明できるまで適用しない
([templates/infra-repo/CLAUDE.md.tmpl](../../templates/infra-repo/CLAUDE.md.tmpl) の絶対ルール 2)。
**適用結果の要約を PR にコメントする**ことが記録手段 (04 §5)。

**3 リポの依存順序**: `infra → backend → frontend`
([templates/README.md](../../templates/README.md))。infra の出力 (RDS エンドポイント / ECS クラスタ名 /
Secrets の ARN) が backend の入力、backend の OpenAPI が frontend の入力。

### 5.2 Managed Agent の発行・更新をどこで行うか (AC-3.3 / D-6)

| 位置 | 内容 |
|---|---|
| **CI (`ci.yml`)** | `scripts/check-tool-contract.sh` による **schema ↔ handler ↔ prompt の 3 者一致検査** + **`prompts/agents.yaml` の列挙と実発行対象の一致検査** (下記)。**マージ前**に落とす |
| **`plan_agent`** | **`prompts/agents.yaml` が列挙したファイル群と tool schema のハッシュ**を **前回発行時の記録 (SSM の `/hassan-v3/<env>/agent/<name>/source-hash`) と比較**。差分が無ければ発行しない (Agent ID が変わると**進行中セッションが切れる**ため毎回発行しない)。3 者一致検査と列挙一致検査をここでも実行する |
| **`apply_agent`** | 再発行 → 新 Agent ID を SSM (`.../agent/<name>/id`) へ書く → **同時に発行元ハッシュを `.../agent/<name>/source-hash` へ書く** → **旧 ID は前バージョンとして残る** (SSM の版履歴)。**Environment ID を新規作成した場合は `.../anthropic/environment-id` も更新する**。prod は `prod-agent` の承認必須 |
| **`release` の前** | 上記が成功していること。**古い Agent のまま新コードを出さない** (BE-8: 新しい引数が黙って捨てられる / BE-10: 台帳の前提チェックが常に失敗する) |

**再発行のトリガは `prompts/` 全体ではなく、宣言的な列挙ファイル (`prompts/agents.yaml`) の内容とする**:

- **事実**: PoC で **Anthropic 側 Agent リソースに登録され、変更時に再発行が必要なプロンプトは 4 ファイルのみ**で、
  それ以外は直接 API 呼び出しであり**コードのデプロイのみで反映される**
  ([../analysis/poc-prompt-inventory.md](../analysis/poc-prompt-inventory.md) §2)。
  一方 v3 は**直接 API 用のプロンプトも `prompts/<domain>/` に集約する** ([architecture.md](architecture.md) の D-E / D-B')
- **判断**: `prompts/` 全体をハッシュ対象にすると、**直接 API 用プロンプトの誤字修正でも Agent ID が更新され、
  進行中セッションが切れる**。prod では不要な H-3 承認が毎回発生し、承認の意味が薄れる
- **決定**: **`prompts/agents.yaml` に「Agent 名 → 登録する system prompt のパス + 登録する tool schema の一覧」を
  宣言的に列挙し、この列挙が指すファイルのみをハッシュ対象にする**。
  列挙漏れが「再発行されない」に倒れないよう、**`scripts/check-tool-contract.sh` の検査項目に
  「Agent 発行コマンドが実際に送る prompt / tool の集合と `agents.yaml` の列挙が一致すること」を含める**
  (不一致は CI で落とす)。**却下案**: ①`prompts/` 全体のハッシュ — 上記のとおり不要な再発行が発生する。
  ②Agent 登録用プロンプトを別ディレクトリ (`prompts/agents/`) に物理分離してディレクトリ単位でハッシュする —
  ディレクトリの置き場が「Agent 用か直接 API 用か」の唯一の宣言になり、
  **同じプロンプトを両方から使う場合に複製が発生する** (BE-2 型の散在)。列挙ファイルなら参照で済む

- **`Tools` は更新時に全置換される** (BE-9)。承認材料に**置き換わる `Tools` の一覧**を出し、
  `web_search` 等の既存ツールの欠落を人間が目視で確認する (04 §2.3)
- **プロンプトの変更のうち、`agents.yaml` が列挙したものはデプロイ手順の一部**である。
  列挙対象の 1 行修正でも `plan_agent` がハッシュ差分を検出し、prod では H-3 の承認を要求する。
  **列挙外のプロンプト (直接 API 用) の変更はコードのデプロイのみで反映され、H-3 を要求しない**
- **手動コマンドでの発行を運用に残さない** (PoC の `update-agent-prompt` + `.env` 書き込み方式は不採用)。
  例外は「dev で試行するための開発者ローカルからの発行」だが、その場合も **dev の Agent ID を上書きせず
  開発者専用の Agent を作る** (dev の共有 Agent ID を個人の試行で書き換えない)。
  **ID の置き場と削除の責任者は §4.4** に定める

#### Anthropic の Environment を環境ごとに分けるか (D-6。**2026-07-30 確定 = 分ける**)

**事実**: PoC は Agent ID とは**別に** `ENVIRONMENT_ID` を必須設定として持ち、未設定なら実行時に
エラーを返す (`claude_managed_agents/cmd/devui/domain_discovery.go:453` /
`claude_managed_agents/internal/config/config_test.go:37` が `AGENT_ID` と `ENVIRONMENT_ID` を対で扱う)。
**したがって v3 でも Agent ID と対で管理する対象**である (OP-E / §3.3 の⑤ / §4.5)。

**暫定既定: dev と prod で Environment を分ける** (`/hassan-v3/dev/anthropic/environment-id` と
`/hassan-v3/prod/anthropic/environment-id` に別の値を置く)。

| 分ける (暫定既定) | 共有する |
|---|---|
| dev の tool 定義変更・試行が prod の Agent 実行環境に影響しない。§5.2 の「dev は自動・prod は承認」という分離が Environment レベルでも成立する | Environment の作成・管理が 1 つで済む。ただし **dev の変更が prod の Agent 実行環境に及ぶ経路が残る** (承認を経ずに prod の挙動が変わり得る) |

**影響範囲 (共有せざるを得ない場合に変わる箇所)**: ①§5.2 の「dev は自動 / prod は H-3 承認」が
Environment に対しては成立しなくなるため、**Environment を変更する操作そのものを prod の承認対象に
昇格させる**必要がある (`apply_agent` の承認を dev でも要求する形になり、C-15 の継続デプロイが人間律速になる)。
②§5.3 の切り戻しで「Environment を戻す」手段が無い場合、Agent ID だけを戻しても復旧しない経路が残る。
③§10.4 の仮定 1 が崩れる。

**確認事項 (ユーザー / Anthropic の仕様確認)**: **Environment を 1 組織内で複数作成でき、
Agent を Environment ごとに発行できるか**。できない場合は上記の影響範囲を適用する。

[Answer]: (2026-07-30) **確認済み — 複数作成できる。暫定既定 (dev と prod で分ける) をそのまま確定とする**。
一次ソース: `https://platform.claude.com/docs/en/managed-agents/environments.md`。根拠と、そこから
**新たに判明した設計上の含意 4 点**:

| # | 一次ソースの事実 | v3 設計への含意 |
|---|---|---|
| 1 | 「You create an environment once, then reference its ID each time you start a session」+ `POST /v1/environments` と `GET /v1/environments` (list) が存在し、「Use a unique, descriptive `name` so you can tell environments apart」と複数前提で案内している | **複数作成は仕様として成立**。`environment_id` はセッション作成時のパラメータなので、**Agent は Environment に紐づかない** — 同じ Agent を dev / prod の別 Environment で走らせられる (上表の「分ける」を選んでも Agent 定義の二重化は起きない) |
| 2 | **「Environments are not versioned. If you update an environment frequently, keep your own record of the changes so you can tell which configuration each session used.」** | **Environment の設定変更は Anthropic 側に履歴が残らない**。OP-E が Environment **ID** を SSM の版履歴で戻せるようにしている設計は正しいが、**ID が同じまま設定だけ変わると切り戻せない**。→ **Environment の設定は不変として扱い、変更時は新しい Environment を作って ID を差し替える** (in-place `update` を使わない) 運用を §5.3 の前提に加える。設定内容自体は IaC / リポジトリ側に記録する (`ant beta:environments create` に渡す YAML を版管理する形が公式の推奨フロー) |
| 3 | 「Each session gets its own sandbox instance, even when multiple sessions reference the same environment. **Sessions do not share filesystem state**」 | **サンドボックスのファイルシステム分離はセッション単位で Anthropic が保証する**。A-6 (LLM への越境) で「同一 Environment を共有すると他テナントのファイルが見える」懸念は成立しない — 越境の経路は**ツール引数の所有者チェック**に絞られる (`08-production-gates.md` A-6 の設計方針は変更不要) |
| 4 | 「For production deployments, use `limited` networking with an explicit `allowed_hosts` list」。`allow_mcp_servers` / `allow_package_managers` は**既定 `false`** | **prod の Environment は `networking.type = limited` を既定にする**。`allowed_hosts` はホスト名のみ (スキーム・ポート・パス不可、`*.example.com` のワイルドカード可)。**外部検索 (Exa) を tool から直接叩く経路があれば `allowed_hosts` に載せる必要がある** — [infrastructure.md](infrastructure.md) の egress 設計と対を取る |

**ライフサイクル (切り戻し手順の前提)**: archive は**読み取り専用化** (既存セッションは継続、新規セッションから参照不可・unarchive 不可)、
delete は**参照するセッションが無い場合のみ**。→ §5.3 で「壊れた Environment を捨てる」場合、
**稼働中セッションが残っている限り delete できない**ため、手順は「新 Environment を作って ID を差し替え → 旧を archive」になる。

**補足 (2026-07-31 の再調査で追加)**: Environment と異なり **Agent は versioning される**
(`agent-setup.md` — 更新のたびに version が発行され、セッション作成時に version を pin できる)。
公式の推奨は「同一 Agent ID + version pinning」であり、**OP-E の切り戻し (SSM の Agent ID 差し替え) より
単純になる可能性がある**ため、実装リポ立ち上げ時に version pin 方式の採用を評価する (D-6)。

### 5.3 ロールバック (OP-G)

| 対象 | 第一手段 | 実行経路 (誰がどこから) | 所要 | 前提・注意 |
|---|---|---|---|---|
| **BE (ECS)** | `ecspresso rollback --config=stacks/<env>/ecspresso.yml --wait-until=service-stable` | **backend リポの `rollback.yml` (`workflow_dispatch`)** を **`prod*` environment の承認者が起動する**。prod は `environment: prod` の承認を通す (dev は承認なし)。**個人の AWS 認証情報では実行しない** (§4.1 の運用者行) | 数分 | 直前のタスク定義に戻す。`deploy.yml` の失敗時ステップは**この workflow の起動先とコマンドを出力する** |
| **FE (Vercel)** | 前の Production デプロイを **Promote** (Instant Rollback) | **Vercel の Promote 権限を持つ者** (04 §4.4 で限定した者) が Vercel の画面から実行 | 即時 | ビルドをやり直さない。これが OP-F で Vercel の Git 連携を残す理由 |
| **Managed Agent** | SSM の Agent ID を**前バージョンの値に戻す** → **BE のタスクを置換する** (`rollback.yml` の入力で「Agent の切り戻しを含む」を選ぶ) | 同上 (`rollback.yml`) | 数分 | **Agent ID は §3.3 の⑤ (起動時に 1 回解決) なので、SSM を戻すだけでは稼働中タスクに反映されない**。タスク置換が必須。旧 Agent は削除しない (§5.2)。**Environment を変更していた場合は Environment ID も同じ手順で戻す** |
| **DB (非破壊)** | **戻さない**。旧イメージが新スキーマで動くことが非破壊の定義 (§7.4) | — (操作しない) | — | 逆方向のマイグレーションを本番で走らせない |
| **DB (破壊的)** | **RDS スナップショットから復元** (承認コメントに記録したスナップショット ID。04 §2.2) | **承認者が AWS コンソール / CLI で実行** (復元はワークフロー化しない — 復元先の指定と切り替えに人間の判断が要るため) | 十数分〜 | 復元中はサービス停止。**破壊的変更を「戻せる」と扱わない** |
| **infra** | 変更を戻す PR → `plan` を読んで `apply` | **人間が `apply`** ([infrastructure.md](infrastructure.md) §4.4) | 変更次第 | **`terraform apply` の巻き戻しは新たな変更**である。RDS の `replace` は戻せない |

**`rollback.yml` に要求する形** (実体は backend リポで実装する。§9 の引き渡し 7):

- 入力: ①対象環境 (`dev` / `prod`) ②戻す対象 (`service` / `service+agent`) ③理由 (自由記述。ジョブサマリに残す)
- `environment`: prod を選んだ場合は `prod` (承認者必須)。**dev は承認なしで即実行**
- 実行内容: `ecspresso rollback` (+ 指定時は SSM の Agent ID / Environment ID を前バージョンへ戻して
  タスクを置換) → **完了後にサービスが `service-stable` になったことを出力する**
- **`deploy.yml` の失敗時ステップは「`rollback.yml` を起動せよ」と出力するだけにする** (自動起動しない)。
  自動で戻すと、原因が DB 側にある場合にアプリだけが戻り、状態の組み合わせが増える

**戻す順序は適用順序の逆**: `release` → `apply_agent` → `apply_migration`。
つまり **アプリを先に戻し、Agent を戻し、DB は最後 (原則戻さない)**。
逆順にすると「新スキーマ前提の旧 Agent」という組み合わせが発生する。

### 5.4 API 変更時の FE / BE のリリース順序

| 変更の種類 | 順序 | 根拠 |
|---|---|---|
| **後方互換な追加・変更** | **BE を先に本番へ出す** → FE を Promote | FE が新 API を呼ぶ時点で BE 側に存在している必要がある |
| **破壊的変更** | **3 段**: ①BE で新旧併存 → ②FE 切替 → ③BE で旧を削除 | issue の切り方とマージ順序は [02-issue-granularity.md](../../templates/shared/.claude/rules/02-issue-granularity.md) §2.2.1 が SSOT |
| **FE のみ / infra のみ** | 制約なし | — |

**③ (旧 IF の削除) を本番で行う条件**: ②の FE が **`production` に Promote 済み**であること。
`main` へのマージ (= Preview 反映) だけでは、稼働中の本番 FE が旧 IF を使い続けている。

## 6. 全面切替 (AC-3.5 / C-11 / C-15)

> 本節が回答する ID: **D-7** (段階) / 対応 AC: **AC-3.5**

### 6.0 「全面切替」と「v2 併用期間」の関係 (確定事項の整合)

3 つの確定事項が別のことを言っているように見えるため、先に関係を固定する:

| 確定事項 | 内容 | 出典 |
|---|---|---|
| C-11 | 既存 v2 ユーザーへは**全面切替**で提供する (併存・限定公開・段階開放をしない) | [questions.md](../../aidlc-docs/inception/productionization/questions.md) Q-5 `[Answer]` = C |
| C-15 | 本番への段階リリースをしない。**dev 先行構築 → 継続デプロイ → 開発完了後に本番へ 1 回で切替** | 同 Q-5 の追加回答 |
| D-J | 第 1 リリースは **PoC 由来機能セット**。その後 **v2 と併用**し、v2 既存機能を順次移植してから v2 を廃止 | 同 Q-3 `[Answer 3]` / [architecture.md](architecture.md) の D-J |

**整合の読み方**: 「全面切替 (C-11)」は**ユーザーの分割 (一部アカウントだけに出す) をしない**という意味であり、
「1 回で切替 (C-15)」は **v3 第 1 リリースを段階開放しない**という意味である。
一方 **v2 は第 1 リリース時点では止まらない** (v3 に無い既存機能があるため) ので、
**併用期間が存在する**。したがって切替は次の 2 種類に分かれる:

1. **v3 の公開 (RL-3)** — 全ユーザーに一斉。フラグでの段階開放をしない
2. **機能単位の移送 (RL-4)** — v2 の機能を v3 へ移植し終えたものから順に v3 側へ寄せる。
   **同一ドメインを両系で同時に更新させない** (切替単位はドメイン)

### 6.1 段階と完了条件

**段階 ID は `RL-0`〜`RL-5`** とする。実装リポの作業ループのステップ ID (`S-1`〜`S-10`。
[01-construction-loop.md](../../templates/shared/.claude/rules/01-construction-loop.md) §1.1) と
**番号空間を衝突させない**ため、`S-` を使わない。

| 段階 ID | 内容 | 完了条件 (**すべて満たすまで次へ進まない**) | 承認 |
|---|---|---|---|
| **RL-0** | **dev 基盤の先行構築** (infra リポ) | ①`terraform plan` の差分ゼロ ②出力値 (RDS エンドポイント / ECS クラスタ名 / Secrets ARN) が取得できる ③backend の空実装が dev へデプロイでき、ヘルスチェックが通る ④04 §4 の立ち上げチェックリスト (ブランチ保護 / environment / ラベル) が 3 リポで完了 | 人間の `apply` |
| **RL-1** | **dev への継続デプロイと受入確認** (開発期間の全体) | ①第 1 リリース対象の全 AC が dev で確認済み ②**LLM 呼び出し明細が dev で記録されている** ([architecture.md](architecture.md) §3.8.3 の「第 1 リリース前」要件) ③-a **AL-1〜AL-7 の全件が dev で「アラーム状態へ遷移する」ことを試験済み** (CloudWatch アラームの状態遷移で確認。**dev は AL-6 以外を通知しない** (§7.5) ため、通知の到達ではなく**アラーム自体の発火**を確認する) ③-b **dev の通知経路 1 本 (AL-6 → dev の SNS トピック → Slack) の到達を試験済み** ④`rollback.yml` を dev で 1 回実行して戻ることを確認済み (§5.3) | H-1 のみ |
| **RL-2** | **prod 基盤の構築** ([infrastructure.md](infrastructure.md) §6.2 が手順の SSOT) | ①`envs/prod` と `envs/dev` の差分が**変数のみ**であることを `plan` で確認 ②§4.5 の棚卸し表の全行に prod の値が投入済み (**Environment ID を含む**) + **dev に開発者専用 Agent (`dev-<ユーザー名>-` 接頭辞) が残っていないことを確認** (§4.4) ③`prod-db` / `prod-agent` / `prod` の承認者が設定済み ④**prod の Agent を発行済み** (`apply_agent` を prod で 1 回通す) ⑤RDS のバックアップ保持と削除保護が prod の値 ([infrastructure.md](infrastructure.md) §5.2) で有効 ⑥**prod の通知経路の到達試験**: `alerts-critical` と `alerts-warning` の各トピックへテスト通知を送り、**critical は Slack とメールの両方に、warning は Slack に届くことを確認**する (§7.5。**prod の 2 トピックとメール購読は dev に存在しないため、本番で初めて使われることを避ける**) ⑦**prod の初期スキーマを投入済み** (2026-07-30 追加。`apply_migration` を **`release` を伴わずに 1 回単独で起動**し、`prod-db` の承認を通す。手順の SSOT は [data-model.md](data-model.md) §6.3)。**RL-3 の §6.3 ②データ移送はテーブルが存在する前提**なので、初期投入をここで終える — §7.4 の「リリースより前に適用」は**差分適用の規則**であり、初期投入はその特例である | 人間の `apply` + H-3 + **H-2** |
| **RL-3** | **本番リリース (v3 の公開)** | §6.3 の手順を完了し、①スモーク (認証 → 会話 1 ターン → 生成物の保存 → 再取得) が prod で成功 ②5xx 率と LLM 失敗率が AL-1 / AL-2 のしきい値未満で **24 時間経過** ③LLM 明細が prod に記録されている | H-2 / H-3 / H-4 |
| **RL-4** | **v2 併用期間 (機能単位の移送)** | ドメイン単位に: ①v3 に同等機能がある ②(該当時) データ移送が完了し写像できなかった件数が 0 ③v2 側の当該機能への**新規アクセスが 0 件**であることをアクセスログで確認 ④[architecture.md](architecture.md) §3.5.2 の対象パス表に移植ドメインを追記済み ⑤**gateway を通らない LLM 呼び出しが残っていない** (O-2 の移植受入条件) | ドメインごとに H-4 |
| **RL-5** | **v2 の廃止** | ①v2 の全機能が v3 に存在する ②v2 の DB スナップショットを取得し**保管期限を決めて記録**した ③v2 の外部連携 (CMS の webhook 受信先・メールのリンク先) が v3 に移設済み ④アカウント基盤の一本化が完了 (**未確定**。§6.5) ⑤v2 の ECS サービスを `desiredCount: 0` にして **14 日間**維持し (この間は起動し直せる)、その後 [infrastructure.md](infrastructure.md) §9.1 の削除順序 (Route53 → ECS → ALB → RDS (最終スナップショット取得後) → S3) で破棄する | 人間 (RL-5 は不可逆) |

**RL-0 と RL-1 の並行**: RL-0 (インフラ) は RL-1 (dev での検証) の前提だが、
**アプリの開発作業自体は RL-0 と並行して進む** (local 環境で開発できる)。
C-15 が「インフラ先行」と言っているのは **dev への継続デプロイが RL-0 の完了に依存する**という意味である。

### 6.2 データ移行の位置づけ (**方式は未確定**)

- **v3 の資源 (インフラ / DB / スキーマ) は全て新規で、v2 の DB には相乗りしない**
  ([questions.md](../../aidlc-docs/inception/productionization/questions.md) Q-1 `[Answer 3]` = C 方向)。
  したがって移行は **v2 → v3 の一方向コピー**であり、**v2 のデータを書き換えない**
- **引き継ぐデータの範囲 (全件 / 直近のみ / 引き継がない) は事業判断待ちで未確定**
  (同 Q-1。`Task-2f` のデータ量確認も未完了)。**対象・写像・検証は `docs/design/data-model.md` が決める**
- 本書が確定させるのは**実行位置と満たすべき性質**のみ:

| # | 確定事項 |
|---|---|
| 1 | **移送は RL-3 の最初 (BE のデプロイより前) と RL-4 の各ドメイン切替時**の 2 箇所でのみ行う。開発中の dev への移送は本番データを使わない |
| 2 | **v2 のデータを読み取るだけで書き換えない**。これによりロールバックが「v3 側を捨てる」だけで成立する ([API/idea-boards.md](API/idea-boards.md) §4 の M-1〜M-4 と同じ原則) |
| 3 | **写像できなかった件数を 0 件になるまで確認する**。0 でない状態で切替を進めない (握り潰し禁止)。件数一致だけでは不十分な項目 (権限・ロールの入れ替わり) は**組の完全一致**で照合する (同 M-4) |
| 4 | **移送中に v2 側でデータが更新され続ける**ため、①移送 → ②差分の再取り込み → ③公開 の順にするか、②を省いて「移送開始時刻以降の v2 の更新は引き継がない」と決めるかを**範囲確定と同時に決める** (`data-model.md`) |
| 5 | 既存の共有設定 (`sharing_settings`) の写し込みは [API/settings.md](API/settings.md) §3.2 が方式の SSOT。**実行タイミングは本表の 1 に従う** (ST-Q5 の残っていた未確定はこれで閉じる) |

### 6.3 RL-3 (本番リリース) の手順とダウンタイム

```
① 事前確認   … §6.1 の RL-2 完了条件 + 進行中の SSE セッション数 (メトリクス) が 0
② データ移送 … (該当時) v2 → v3 の一方向コピー + 写像 0 件の確認 (§6.2)
③ BE         … deploy.yml を prod で手動起動 (H-2 → H-3 → H-4)
④ スモーク   … 認証 → 会話 1 ターン → 生成物の保存 → 再取得
             （v3 のホスト名に対して実施。この時点で v2 は無変更のまま稼働）
⑤ FE         … main → production の PR をマージし Promote (H-4)
⑥ 公開       … 公開方式に依存 (下記 ケース A / B)。DNS 操作は infrastructure.md §9.2 が手順の SSOT
⑦ 監視       … 24 時間、AL-1 / AL-2 / AL-4 を注視 (RL-3 の完了条件)
```

**⑥ の公開方式は 2 ケースあり、どちらを採るかは未確定** (使用ドメイン名の確認待ち。
[infrastructure.md](infrastructure.md) §3.6 の Route53 行が「要確認 (使用するドメイン名)」。§10.1 の OP-R7):

| ケース | 内容 | 切り戻し (§6.4) |
|---|---|---|
| **A. 既存の公開ドメインを v3 へ付け替える** ([infrastructure.md](infrastructure.md) §9.2 の前提) | TTL を 60 秒に下げて待つ → DNS を v3 (Vercel Production / v3 の ALB) へ向ける | **DNS を旧レコードへ戻す** (v2 は無変更で残っているため再構築は不要) |
| **B. v3 を別 URL で公開する** | v3 の URL をユーザーへ案内する。既存ドメインは v2 のまま | **v3 の入口を閉じ、v2 の URL を案内する** |

**ケース A 固有の注意 (TTL 期間中の書き込み分散)**: DNS の切替は瞬間的ではないため、
**旧 TTL が抜けるまで一部のユーザーが v2 に、一部が v3 にアクセスする**。
この期間に**両系へ書き込みが発生する**と、移送済みデータと v2 の新規更新が食い違う。
対策は 2 つのどちらかで、**§6.2 の 4 (差分の再取り込みをするか) と同時に決める**:
①切替前に v2 を読み取り専用にする (v2 のダウンタイム相当が発生) ②TTL 期間の分散を許容し、
その間の v2 側の更新は引き継がないと決める。**「気を付けて切り替える」で済ませない**。

| 項目 | 方針 |
|---|---|
| **ダウンタイム (v3)** | **無い**。v3 は新規構築であり、切り替える既存トラフィックが無い |
| **ダウンタイム (v2)** | **原則無い** (v2 は併用期間中も稼働)。**例外**: ケース A で上記の対策①を採る場合、および §6.2 の 4 で「移送中は v2 を読み取り専用にする」を選ぶ場合 (どちらも未確定) |
| **通常デプロイのダウンタイム** | ECS のローリング更新 (最小 100% / 最大 200%) で**無い**。ただし **rolling update で SSE 接続は切れる** ([design_memo.md](design_memo.md) のデプロイ節) — FE は「会話履歴 GET で復元 + 再接続」で復旧する |
| **SSE 切断の運用手順** | prod デプロイは手動起動なので、**起動前に進行中の SSE セッション数をメトリクスで確認する** (0 でなければ、切断される会話があることを承認材料に含める)。「利用の少ない時間帯に行う」といった判断基準を持たない運用にしない。**メトリクスの定義 (名前 `sse.active_connections` / ゲージ / EMF / 30 秒) は [observability.md](observability.md) §4.4.1 が SSOT** (2026-07-30 に追記済み。OP-F1 解消) — 本書は「リリース判断でそれを見る」運用だけを定める |
| **切替前後で参照が壊れないことの確認** | ①移送を行う場合は写像 0 件 (§6.2 の 3) ②**外部から v2 を指す経路の棚卸し** (メール本文のリンク先ドメイン / CMS の webhook 送信先 / 送信元メールアドレス) を切替前チェックリストにする。v3 は v2 のテーブルを参照しないため、**DB レベルの参照切れは構造的に発生しない** |

**アクティブな SSE 接続数メトリクスの暫定定義** (本書は運用側の要求元であり、**計測項目の SSOT は
[observability.md](observability.md) §4.4.1**。2026-07-30 に同節へ追記済み — 本書は値を持たない
(名前 `sse.active_connections` / ゲージ / EMF / 30 秒。二重定義を避けるため、
しきい値や次元の変更は同書側で行う):

| 本書が定めること | 内容 |
|---|---|
| **リリース判断での使い方** | prod の `release` を起動する前に**全タスクの合計値**を見る。0 でなければ「切断される会話がある」ことを H-4 の承認材料に含める |
| **判断基準を持たない運用の禁止** | 「利用の少ない時間帯に行う」で代替しない (観測せずに出す運用に退行するため) |

### 6.3.1 切替時のユーザー告知 (2026-07-31 追加 — [llm-migration.md](llm-migration.md) LM-R9 への回答)

RL-3 の公開前に、**v2 との差分のうちユーザーに見えるもの**を告知する。告知文の起草は RL-3 の
完了条件に含める (無言で消さない — [data-model.md](data-model.md) §6.2 の項目 7 と同じ原則)。

| # | 告知対象 | 出典 |
|---|---|---|
| 1 | **リサーチシートの提供終了** (v2 で稼働中の機能を v3 に作らない — 2026-07-31 のユーザー決定) | [llm-migration.md](llm-migration.md) §4.3 X-12 |
| 1' | **企業ミッション (会社単位) の提供終了** — v3 はテーマ単位の `mission` に一本化 (2026-07-31 の AA-Q1=a) | [API/auth-accounts.md](API/auth-accounts.md) AA-D-1 / §6.1 AA-Q1 |
| 2 | **memo のスコープ変更** (同じアイデアの memo がボードごとに独立する) | [API/idea-boards.md](API/idea-boards.md) §4 M-2 / IB-Q10 |
| 3 | 切り戻し時の制約 (v3 公開後のパスワード変更等は v2 に戻らない) | [data-model.md](data-model.md) §6.5 の 5 |
| 4 | データ引き継ぎ範囲の確定後に「引き継がないもの」があれば追記 (DM-A2 待ち) | [data-model.md](data-model.md) §6.2 の項目 7 |

### 6.4 切り戻し (RL-3 の失敗時)

**切り戻し = 「ユーザーを v2 に戻す」**である (v2 が無変更で稼働しているため、v2 側の復旧作業は無い)。
**操作は §6.3 の公開方式で変わるが、原則と期間・判断基準は共通**:

| # | 操作 | ケース A (ドメイン付け替え) | ケース B (別 URL) |
|---|---|---|---|
| 1 | **ユーザーの入口を v2 へ戻す** (最優先) | **DNS を旧レコードへ戻す** (TTL 60 秒のまま作業する。[infrastructure.md](infrastructure.md) §9.2 の 4) | **v3 FE の Production を利用停止の案内表示に Promote** し、v2 の URL を案内する |
| 2 | **v3 の BE は稼働させたまま**にする | 共通 (v3 で作られたデータを保全する。停止すると調査もできない) | 同左 |
| 3 | 原因調査 → 前進修正 (hotfix) または再リリース | 共通。DB を破壊的に変更していた場合のみスナップショット復元 (§5.3) | 同左 |
| 4 | 復帰時の扱い | **v3 に残ったデータは v3 のまま**。切り戻し中に v2 側で行われた更新の再移送が必要になるため、§6.2 の 4 の決定に従う | 同左 |

**切り戻し可能期間は v3 公開後 7 日間とする** ([infrastructure.md](infrastructure.md) §9.2 の 4 が
「切り戻し可能な期間の定義」を運用設計へ渡している箇所への回答)。
根拠: **v3 で作られたデータ (会話・生成物・ボードアイテム) は v2 に相当する構造が無く、v2 へ戻せない**
([API/idea-boards.md](API/idea-boards.md) §4 のロールバック節)。7 日を超えると
「v3 でしか存在しないデータ」が実用上の量に達し、切り戻しが**データの破棄**を意味するようになる。
**この根拠は Q-1 (データ引き継ぎ範囲) の回答に依存しない** — 引き継ぎが「無し」に決まっても、
公開後に v3 で作られるデータは同じように戻せない。

| 期間 | 取れる手段 |
|---|---|
| 公開〜7 日 | 上記 1〜4 の切り戻し (v3 のデータは残すが、ユーザーは v2 を使う) |
| 7 日以降 | **切り戻しを行わない**。前進修正のみ (hotfix / `ecspresso rollback` によるアプリ単位の戻し) |

**切り戻しの判断基準** (いずれか 1 つで発動。判断者は H-4 の承認者):

1. **認証・テナント境界の欠陥**が確認された (他テナントのデータが見え得る) — **即時**
2. **5xx 率が AL-1 のしきい値を継続して超え、原因が 2 時間以内に特定できない**
3. **LLM コストが AL-4 のしきい値の 3 倍を超え、原因が特定できない** (C-12 により上限拒否は無いため、
   コストの暴走はアラートと切り戻しでしか止まらない)
4. **データの破損** (移送したデータの不整合が利用中に判明した)

### 6.5 RL-5 (v2 廃止) に残る未確定

- **アカウント基盤の一本化**: 認証系 API を v3 で実装する決定 ([auth.md](auth.md) §9.3 Q-A8) により、
  併用期間中は **v2 と v3 の双方にアカウント情報が存在する**。どちらを正とするか・
  いつ一本化するかは `docs/design/data-model.md` (Task-3a の追加要件) が決める。
  **本書はこれを RL-5 の完了条件 ④として位置づけるだけ**とする
- **CMS の webhook 受信先の移設**: 第 1 リリース時点では v2 が受信する
  ([API/news.md](API/news.md) の NW-Q3)。**移設は「お知らせ機能を v3 へ移植する RL-4 のドメイン切替」に含める**
  (移設だけを単独で行うと、受信した更新を反映する先が無い状態が生まれる)

## 7. 環境戦略と DB 適用範囲 (D-7 / AC-3.7)

> 本節が回答する ID: **D-7** / 対応 AC: **AC-3.7**
> **前提: Q-8 は未回答**。本節は推奨案 A (trunk-based + 環境変数フラグ) を**暫定既定**として書いている
> ([questions.md](../../aidlc-docs/inception/productionization/questions.md) Q-8 `[Answer 2]`)。
> 回答が A 以外になった場合、§7.1〜§7.3 を差し替える (§7.5)。

### 7.1 ブランチ運用 (暫定既定: trunk-based)

| ブランチ | 役割 | 保護 |
|---|---|---|
| `feature/*` (`<type>/<issue番号>-<slug>`) | 作業ブランチ。壊れてよい | なし (エージェントが push 可) |
| **`main`** | **常時リリース可能**。dev へ継続デプロイ | 直接 push 禁止 / 必須レビュー 1 / 必須ステータスチェック (04 §4.1) |
| **`production`** (frontend のみ) | Vercel の Production Branch | `main` からの PR のみ / 必須レビュー 1 (04 §4.1 の最後の項目) |

- **backend / infra に `production` ブランチを作らない**。BE の本番は「`main` の特定コミットを
  手動起動でデプロイする」形であり、ブランチで表現しない (FE は Vercel の仕組みが
  Production Branch を要求するため例外)
- リリースブランチを持たない代償は **`main` に未完成機能が入り得る**ことで、これを §7.2 のフラグで塞ぐ

### 7.2 フィーチャーフラグ (OP-I)

| 項目 | 確定値 |
|---|---|
| **実装** | 環境変数のみ。BE = ECS タスク定義の `environment` (§3.3 の②) を `config` が読む。FE = Vercel の環境変数 |
| **値の置き場 (確定)** | **backend リポの `stacks/<env>/` にある ecspresso のタスク定義テンプレート**に直接書く。**infra リポの `envs/<env>` の変数にしない** — 理由: フラグの切替を**通常の PR + dev への継続デプロイ**で回したい (infra の変数にすると infra PR + 人間の `apply` が必要になり、リードタイムが別物になる)。また [infrastructure.md](infrastructure.md) §4.1 は「Terraform 側で ECS サービスとタスク定義のリソースを一切定義しない」と決めているため、`environment` の所有者は ecspresso である。**却下案**: ①infra の変数にする — 上記のリードタイムと所有者の二重化。②SSM (§3.3 の④) に置いて再デプロイなしに切り替える — 「未完成機能を prod で無効にする」用途では**コードとフラグが同時に切り替わる**必要があり、④ の判定基準 (§3.3) を満たさない |
| **命名** | `FEATURE_<機能名>` (真偽値。既定は **false** = 未定義なら無効) |
| **判定の正** | **BE**。フラグ OFF のエンドポイントは **404** を返す (経路が存在しないのと同じ扱い。403 は「権限が無い」の意味なので使わない。[auth.md](auth.md) §6.6 の判定規則と整合) |
| **FE の役割** | **導線を隠すだけ**。FE のフラグが古くても、BE が 404 を返すため機能は露出しない |
| **置く層** | Controller (ルーティングの有効化) を既定とする。UseCase 以下に分岐を置かない (フラグ削除時の除去範囲を Controller に閉じる) |
| **削除** | **フラグを追加する PR で、削除の issue を同時に起票する**。本番リリース後に削除する。恒久的なフラグを作らない |
| **DB テーブル方式への移行契機** | 「特定アカウントにだけ機能を出す」要求が発生したとき (それまでは環境変数で足りる) |

**フラグは第 1 リリースまでの一時的な仕組み**である。C-11 (全面切替) では段階開放のフラグは要らず、
必要なのは **「dev で検証中の未完成機能を prod で無効にする」用途だけ**である。

### 7.3 dev の未リリース変更を prod に出さない仕組み

**3 段で担保する** (どれか 1 つでは漏れる):

| # | 仕組み | 塞ぐ経路 | 機械か人間か |
|---|---|---|---|
| 1 | **prod デプロイは `workflow_dispatch` の手動起動のみ** + `main` 以外の ref を最初のジョブで失敗させる (04 §2.4) | `main` へのマージが自動で prod に流れる経路 | **機械** |
| 2 | **`environment: prod` の承認** (承認前にジョブが待機) + Deployment branches を `main` のみに制限 | 承認なしのリリース | **機械** |
| 3 | **未完成機能は `FEATURE_*` が prod で false** (§7.2) | 「`main` に入っているが出したくない機能」がリリースに含まれてしまう経路 | **機械** (既定 false) |
| 4 | **H-4 の承認材料に「その commit が dev で検証済みであること」を含める** (04 §1.1 の確認観点②) | dev を経ていないコミットの本番投入 | **人間** |

**4 だけが人間の確認事項**である。機械化しない理由: 「dev で検証済み」は
**デプロイ済みであること (機械で分かる) と受入確認が済んでいること (issue / PR の状態)** の 2 つを
突き合わせる判断であり、後者が機械判定できない。**代わりに 1〜3 で「承認を経ずに出る経路」を全て塞ぐ**。

### 7.4 DB マイグレーションの自動適用範囲 (AC-3.7)

**判定 (破壊的か否か) と承認先の定義は
[04-human-checkpoints.md](../../templates/shared/.claude/rules/04-human-checkpoints.md) §2.2 が SSOT** (機械判定の 1〜6)。
本節は**変更の種類ごとの運用手順** (2 段階リリースの要否・適用順序・戻し方) を定める。

| # | 変更の種類 | 04 §2.2 の判定 | 適用 | 手順 | 戻し方 |
|---|---|---|---|---|---|
| 1 | テーブル追加 / インデックス追加 (CONCURRENTLY) | 非破壊 | dev 自動 / prod 承認 | 単発 | 戻さない (未使用のまま残る) |
| 2 | **NULL 許容**の列追加 / 既定値付きの列追加 | 非破壊 | 同上 | 単発 | 戻さない |
| 3 | **既定値の無い `NOT NULL` 列の追加** | 破壊的 (3) | 承認 | **2 段階**: ①NULL 許容で追加 + バックフィル (非破壊) → ②`NOT NULL` 化 (破壊的) | ①は戻さない / ②は制約を外す |
| 4 | **列の削除** | 破壊的 (1) | 承認 | **2 段階**: ①コードから参照を消してリリース (アプリ変更のみ) → ②`DROP COLUMN` | ②はスナップショット復元のみ |
| 5 | **列 / テーブルの名称変更** | 破壊的 (5) | 承認 | **3 段階**: ①新名で追加 + 二重書き → ②読み取りを新名へ切替 → ③旧名を削除。**`RENAME` を単発で行わない** | 段ごとに戻せる (③のみ復元) |
| 6 | **列の型変更** | 破壊的 (2) | 承認 | 5 と同じ 3 段階 (新列を追加して移す) | 同上 |
| 7 | **既存データがある列への UNIQUE 制約** | 破壊的 (4) | 承認 | ①重複の有無を確認する SQL を承認材料に添付 → ②制約追加 | 制約を外す |
| 8 | **データ移行 SQL** (`UPDATE` / `DELETE` を含む) | 破壊的 (6) | 承認 | 承認前に**影響行数**を提示 (`SELECT count(*)`) | スナップショット復元 |

**共通の前提 (すべての変更に適用)**:

1. **マイグレーションはアプリのリリースより前に適用される** (`deploy.yml` の
   `apply_migration` → `release`)。したがって **「旧イメージが新スキーマで動く」ことが全変更の必要条件**である。
   これを満たさない変更は、必ず上表の 2 段階 / 3 段階に分解する。
   **適用は ECS RunTask で VPC 内から行う** (§5.1 の実行場所表 / [infrastructure.md](infrastructure.md) INF-H)
2. **破壊的変更の承認条件に RDS スナップショットの取得を含める** (承認コメントにスナップショット ID を書く。04 §2.2)
3. **prod は「非破壊でも承認必須」** (04 §2.2 の表)。dev の非破壊のみが自動適用
4. **1 回のデプロイに 2 段階の両方を含めない**。①と②は別 PR・別デプロイにする
   (同一デプロイに入れると、①の完了を確認せずに②が走る)

### 7.5 未確定 (回答が入ったら本節を更新する)

**マイグレーションツールの選定 (D-4)** — psqldef (v2 が使用。宣言的で逆方向の SQL を持たない) か
golang-migrate (PoC が使用。up/down のバージョン管理) か。
`deploy.yml` の `plan_migration` / `apply_migration` の**コマンド実体は選定までプレースホルダ**である
(承認が挟まる位置と**実行経路 (ECS RunTask) は方式に依存しないため既に確定している** — §5.1)。
**選定が §7.4 に与える影響**: 表の「戻し方」列で「制約を外す」「①は戻さない」と書いた操作を
**逆方向のマイグレーションとして記述できるか**が変わる (psqldef なら宣言を戻す形になり、
中間状態を経る 3 段階 (5 / 6) の各段の表現方法も変わる)。

**回答済み (2026-07-31): psqldef で確定** — `[Answer]` の実体は [data-model.md](data-model.md) §6.1
(同節が比較表・選定基準・採用を持つ SSOT)。**同じ問いを 2 箇所で管理しない** (本節は参照のみ — R-DM-6 実施済み)。
§7.4 の「戻し方」列への影響: 逆方向は「宣言を戻して再適用」で表現し、破壊的差分は H-2 の機械判定 + 承認で守る。
3 段階リリース (5 / 6) の中間状態は宣言を段ごとに置く形で表現する。

**アラートの通知先の実体 (O-7)** — **監視対象としきい値の SSOT は [observability.md](observability.md) §4.6**
(AL-1〜AL-7)。同節は通知先を「開発チーム」「管理者」と定義しており、**重大度の分類・環境差・
トピックの本数は定義していない** (確認済み)。SNS トピック / Chatbot のリソース定義は
[infrastructure.md](infrastructure.md) §3.5 が持つ。

**本書 (運用の SSOT) が確定させるのは、束ね方と環境差である** — 以下が一次の決定であり、
`infrastructure.md` §5.2 / §3.5 は本節を参照する (循環参照にしない):

| 項目 | 決定 |
|---|---|
| **prod のトピック** | **2 本**。`alerts-critical` = **AL-1 / AL-4 / AL-6** / `alerts-warning` = **AL-2 / AL-3 / AL-5 / AL-7** |
| **prod の購読** | **critical = Slack + メールの 2 経路** / **warning = Slack のみ** |
| **dev のトピック** | **1 本** (`alerts-dev`)。購読は Slack のみ |
| **dev で通知する項目** | **AL-6 (ECS タスクの異常終了 / ヘルスチェック失敗) のみ** |
| **dev でのアラーム自体** | **AL-1〜AL-7 の全件を作成する** (通知先を dev トピックに繋ぐのは AL-6 のみ)。理由: しきい値とメトリクスの定義誤りを dev で検出するには**アラームの状態遷移**が観測できれば足りる (RL-1 の完了条件③-a) |

**重大度 2 分類の根拠と却下案**:

- **critical の定義**: **「放置するとユーザーが機能を使えないか、費用が増え続けるもの」** —
  AL-1 (5xx 率) は機能停止、AL-6 (タスク異常) は全断の前兆、AL-4 (日次コストの急増) は
  **C-12 により上限拒否を設けない**ため、アラートと切り戻し以外に止める手段が無い (§6.4 の判断基準 3)
- **warning の定義**: **「品質は劣化しているが、放置しても被害が単調増加しないもの」** —
  AL-2 (LLM 失敗率) / AL-5 (安全弁の発火) / AL-7 (レート制限のスパイク) は個々のリクエストの失敗であり、
  リトライと再実行で利用は継続できる
- **AL-3 (`max_tokens` 切り詰めの発生) を warning に置く判断の根拠**: BE-6 の再発検知に直結するため
  **見落としてはいけない**が、**1 件でも発生で発火する設定** ([observability.md](observability.md) §4.6) のため
  critical に置くと**出力フィールドを 1 つ増やしただけで critical が鳴り続け、critical の意味が薄れる**
  (アラート疲れで AL-1 / AL-6 を見落とす方が被害が大きい)。**代わりに warning は「1 営業日以内に必ず一次確認する」
  運用とし、AL-3 が 24 時間で連続発生した場合は critical へ昇格させる** (しきい値の変更は
  [observability.md](observability.md) §4.6 側の改訂として行う)
- **却下案**: ①**重大度を分けず 1 本にする** — 通知の量が同じでも「今すぐ見るべきか」が判断できず、
  結果として全件が事後調査用になる。②**3 段階 (critical / warning / info)** にする —
  AL-1〜AL-7 の 7 項目に対して 3 分類は粒度が細かすぎ、info が誰も見ないトピックになる。
  ③**AL-3 を critical に置く** — 上記のとおりアラート疲れを招く

**未確定なのは①Slack を使うか②宛先の値** (ワークスペース / チャンネル名・メールアドレス)。
**メールアドレスは SNS の email 購読で確認メールの受信が必要**なため、
[infrastructure.md](infrastructure.md) §3.5 の要素として洗い出す対象に含める。

[Answer]:

## 8. 本番観点への回答

| ID | 状態 | 回答 / 先送り先 |
|---|---|---|
| **D-1 環境** | **回答** | §3。local / dev / prod の 3 環境。**FE (Vercel の Preview / Production) と BE (AWS の dev / prod) の対応表は §3.2**。設定値の持ち方は §3.3 の 5 分類 (コード内定数 / ECS `environment` / Secrets Manager / SSM で実行中に読み替える値 / SSM で起動時に 1 回解決する値) |
| **D-3 デプロイ手順** | **回答** | §5。BE = `deploy.yml` の 6 ジョブ (dev 自動 / prod 手動 + 承認)。**`apply_migration` は ECS RunTask で VPC 内から実行する** (§5.1 の実行場所表)、FE = Vercel、infra = 人間の `apply`。**ロールバックは §5.3** (`rollback.yml` から `ecspresso rollback` / Vercel の Promote / Agent ID の前バージョン + タスク置換 / DB は原則戻さない)。**戻す順序は適用順序の逆**。API 変更時の順序は §5.4 |
| **D-5 シークレット** | **回答** | §4。Secrets Manager (秘密) と SSM Parameter Store (非秘密) を分ける。**用途単位で 1 シークレット**。**CI が GitHub environment secret / variable に持ってよい値は §4.1 の限定列挙のみ** (DB 接続情報 / API キー / Agent ID・Environment ID は置かず、OIDC ロール経由で AWS から取得する)。登録・変更・ローテーション・ローカル開発の手順は §4.2〜§4.4。**PoC の `WriteEnv` (BE-3) と v2 の `.env` 焼き込みは不採用** (§4.1) |
| **D-7 段階リリース** | **回答** | §6 (段階と完了条件 RL-0〜RL-5) + §7.3 (未リリース変更を prod に出さない 4 段の仕組み)。**フラグは環境変数のみ・判定の正は BE** (§7.2) |
| **D-4 マイグレーション** | **部分 (本書の担当分は回答)** | **自動適用範囲は §7.4 で確定** (dev の非破壊のみ自動 / 破壊的は 2〜3 段階に分解)。**ツール選定は未確定** (§7.5 の `[Answer]`)。方式・後方互換・ロールバック手順の全体 (AC-3.4) は `docs/design/data-model.md` |
| **D-2 CI ゲート** | **参照 (本書は SSOT ではない)** | [01-construction-loop.md](../../templates/shared/.claude/rules/01-construction-loop.md) §7 + [architecture.md](architecture.md) §5 の D-2 + [ci.yml](../../templates/backend-repo/.github/workflows/ci.yml)。本書は**デプロイ側のゲート**のみを扱う |
| **D-6 Agent ライフサイクル** | **参照 + 運用手順を追加** | 機構は [04-human-checkpoints.md](../../templates/shared/.claude/rules/04-human-checkpoints.md) §2.3 と [deploy.yml](../../templates/backend-repo/.github/workflows/deploy.yml)。**本書が追加するのは §5.2 の運用**: ①**Agent ID と Environment ID** の保管先 = SSM のバージョン履歴 (§3.3 の⑤。**起動時に 1 回解決し実行中は読み替えない**) ②再発行トリガは `prompts/agents.yaml` の列挙 (`prompts/` 全体ではない) ③開発者ローカルからの発行時に dev の共有 ID を上書きしない (§4.4 に ID の置き場と削除責任) ④切り戻しは SSM の前バージョン + **タスク置換** (§5.3) ⑤**dev / prod で Environment は分ける (2026-07-30 確定。複数作成可を一次ソースで確認)** — 加えて **Environment の設定は不変として扱い、変更は新規作成 + ID 差し替え + 旧を archive** (Anthropic 側に設定の版履歴が無いため。§5.2 の含意 2) |
| **D-8 IaC の管理範囲** | **対象外 (参照)** | [infrastructure.md](infrastructure.md) §4 / §7 が SSOT。**本書と一致していることを確認した点**: ①Secrets の値は Terraform 管理外 (同 §7 の X-2 = 本書 §4.2) ②`envs/dev` / `envs/prod` の差分は変数のみ (同 §5.1 = 本書 §3.1) ③SSM に Agent ID を版付きで置き CI が書く (同 §3.4 = 本書 OP-E / §5.2) ④apply は dev も人間 (同 §4.4 = 本書 §5.1) |
| **O-7 アラート** | **部分** | 通知の**形と環境差** (prod = 2 トピック / critical は Slack + メール、dev = 1 トピック・AL-6 のみ通知) を §7.5 で確定 — **本書がこの決定の SSOT**。**宛先の値は未確定** (`[Answer]`)。監視対象としきい値は [observability.md](observability.md) §4.6 |
| **A 領域 (A-1〜A-7)** | **対象外** | 本書は運用設計であり、認証・テナント境界の設計は [auth.md](auth.md) が SSOT。ただし**運用上の接点**は本書で扱った: JWT 鍵のローテーション手順 (§4.3)・prod の接続情報をローカルに置かない (§4.4) |
| **O-1〜O-6** | **対象外** | [observability.md](observability.md) が SSOT。本書は**運用側の接点**のみ扱った: ログレベルの環境差 (§3.1)・安全弁のしきい値を SSM に置く (§3.3 の④)・アラート通知先の形 (§7.5) |

## 9. 実装リポへの引き渡し

**infra リポ** (最初に着手。他 2 リポの前提。**モジュール構成と要素一覧は
[infrastructure.md](infrastructure.md) §3 / §10.1 が SSOT**。ここには**本書由来の要求だけ**を挙げる):

1. **SSM Parameter Store のパス階層を `/hassan-v3/<env>/...` に固定する** (§3.3 の④・⑤ / §4.1)。
   アプリが読むため、タスクロールに `/hassan-v3/<env>/*` の読み取りを与える
   (④ の安全弁のしきい値・単価テーブルの版と、⑤ の **Agent ID / Environment ID** が同じ経路で読まれる)。
   **CI (`apply_agent`) が書き込むパスは `/hassan-v3/<env>/agent/*` と
   `/hassan-v3/<env>/anthropic/environment-id` に限定する**
2. **シークレットは用途単位で 1 つずつ作る** (OP-C。`/hassan-v3/<env>/db/url` 等)。
   1 つの JSON にまとめない — IAM を用途別に絞れなくなる
3. CI 用の IAM ロールは **OIDC** で引き受ける (長期アクセスキーを作らない。§4.1)。
   **`migration` ロールには `ecs:RunTask` / `ecs:DescribeTasks` / `iam:PassRole` (マイグレーション実行タスクの
   タスク実行ロール・タスクロール) / `logs:GetLogEvents` を与える** (§5.1 の RunTask 経路)。
   **`apply_agent` が使うロールに `secretsmanager:GetSecretValue` (`/hassan-v3/<env>/anthropic/api-key` のみ) と
   `ssm:PutParameter` を与える** (§4.1 の限定列挙により CI は API キーを GitHub 側に持たない)。
   **`rollback.yml` の切り戻しに `ssm:GetParameter` と `ssm:GetParameterHistory` も必要**
   (`/hassan-v3/<env>/agent/*` と `.../anthropic/environment-id`)。**これが無いと ① が `AccessDenied` で失敗する**
4. **prod の SNS トピックを 2 本 (`alerts-critical` / `alerts-warning`)、dev は 1 本作る。
   critical にはメール購読を付ける** (§7.5 が決定の SSOT。[infrastructure.md](infrastructure.md) §3.5 が要素一覧)

**backend リポ**:

1. `config` パッケージが §3.3 の 5 分類を読む (④ は **TTL 60 秒で再取得し、値の変更を info ログに出す** /
   **⑤ (Agent ID・Environment ID) は起動時に 1 回だけ解決し、実行中は再取得しない**)
2. 必須項目が未設定なら**起動を失敗させる** (BE-5。§4.4)。**`Environment ID` を必須項目に含める**
   (PoC は未設定時に実行時エラーを返していた — OP-E の出典)
3. `.env.example` (キー名のみ) の配置と `.dockerignore` への `env*` / `.env*` / `*.pem` の追加 (§4.1)
4. `deploy.yml` のプレースホルダを埋める (ECR リポジトリ名 / IAM ロール ARN / `stacks/<env>/ecspresso.yml` /
   **マイグレーション実行タスク定義名・クラスタ名・subnet / SG・ロググループ名**)。
   **`plan_migration` / `apply_migration` のコマンド実体はツール選定 (§7.5) まで未実装のまま**にする。
   **RunTask の起動・完了待ち・ログ取得の構造は雛形側で確定済み**なので、この構造を壊さずにコマンドだけを埋める
5. **マイグレーション実行専用のタスク定義**を `stacks/<env>/` に置く (接続情報は `secrets` で
   Secrets Manager から注入。[infrastructure.md](infrastructure.md) §3.2)
6. Agent 発行コマンド (`apply_agent` から呼ぶ。**Agent ID と Environment ID の両方を扱う**) と
   `scripts/check-tool-contract.sh` (§5.2。**`prompts/agents.yaml` の列挙と実発行対象の一致検査を含める**)
7. **`rollback.yml` (`workflow_dispatch`)** — **雛形は `templates/backend-repo/.github/workflows/rollback.yml`
   に作成済み** (2026-07-30)。**新規に書き直さずコピーして使う** — 雛形には次の安全機構が入っており、
   再実装すると失われる: ①`scripts/rollback-agent.sh` が未実装なら `exit 1` (無言で「戻した」と報告しない)
   ②`②'` で「① 成功・② 失敗」の中途状態だけを警告 ③`③` で SSM の現在値とバージョンを出力。
   **実装リポで用意するのは `scripts/rollback-agent.sh`** (SSM の版履歴から旧値へ書き戻す)
8. **フィーチャーフラグは `stacks/<env>/` のタスク定義テンプレートに書く** (infra の変数にしない。§7.2)
9. **アクティブな SSE 接続数のメトリクス** — prod デプロイ前の確認に使う。
   **定義の SSOT は [observability.md](observability.md) §4.4.1** (2026-07-30 に追記済み。
   `sse.active_connections` / ゲージ / EMF / 30 秒)。本書 §6.3 はリリース判断での使い方のみを定める

**frontend リポ**:

1. Vercel の Production Branch を `production` に変更し、`main` は Preview (§3.2 / 04 §4.4)
2. 環境変数を `Preview` = dev の BE / `Production` = prod の BE に登録する。
   **`Preview` に prod 向けの値を入れない** (§3.2)
3. `FEATURE_*` は導線の表示可否にのみ使う (判定の正は BE。§7.2)

**雛形 (`templates/`) 側の是正** (本書の決定に合わせて 2026-07-30 に実施 / 未実施の分は要求として残す):

| 対象 | 状態 | 内容 |
|---|---|---|
| [deploy.yml](../../templates/backend-repo/.github/workflows/deploy.yml) の `apply_migration` | **是正済み** | GitHub ランナーから `secrets.DATABASE_URL` で直接 DB に接続する形を廃止し、**ECS RunTask の起動 → 完了待ち → 終了コード判定 → CloudWatch Logs の取得**に置き換えた (§5.1)。コマンド実体のみプレースホルダ |
| [deploy.yml](../../templates/backend-repo/.github/workflows/deploy.yml) の `apply_agent` | **是正済み** | `secrets.ANTHROPIC_API_KEY` の参照を廃止し、**OIDC ロール + Secrets Manager からの取得**に置き換えた (§4.1)。SSM への書き込み対象に **Environment ID** を追加 |
| [04-human-checkpoints.md](../../templates/shared/.claude/rules/04-human-checkpoints.md) §4.2 の「保持するシークレット」列 | **是正済み** | DB 接続情報 / Anthropic API キー / Agent ID を GitHub environment secret として保持する記述を、**§4.1 の限定列挙 (ロール ARN 等) に置き換えた**。**environment の一覧・承認者設定・Deployment branches の仕組みは変更していない** (04 が SSOT のまま) |
| 同 §2.6 の H-3 行「二重化」列 | **是正済み** (2026-07-30。OP-F3 解消) | 「prod の Anthropic API キーは Secrets Manager が唯一の所在。`apply_agent` は environment `prod-agent` の OIDC ロールで `secretsmanager:GetSecretValue` して取得する (GitHub secret には置かない)」へ差し替えた |
| `rollback.yml` の雛形 | **作成済み** (2026-07-30。OP-F4 解消) | `templates/backend-repo/.github/workflows/rollback.yml`。§5.3 の要求どおり入力 3 種・prod は environment 承認・Agent 切り戻しはタスク置換とセット。**`scripts/rollback-agent.sh` (SSM の版履歴から旧値へ戻す) は実装リポで用意する** — 未実装ならジョブが `exit 1` で落ちる (無言のスキップにしない) |

**参照すべき v2 既存実装** (踏襲する部分 / しない部分を明示):

- 踏襲: `hassan-v2-backend/stacks/prod/ecspresso.yml` (ecspresso の設定の形) /
  `hassan-v2-backend/.github/workflows/prod-deploy.yml` (prod を手動起動にする形)
- **踏襲しない**: `hassan-v2-backend/.github/workflows/dev-deploy.yml:35-45` (image タグを `main` に
  コミットする経路) / `hassan-v2-backend/di/provider.go:83-94` (`GO_ENV` で `.env` を読み込む方式) /
  `hassan-v2-backend/stacks/ecs.Dockerfile` + `hassan-v2-backend/.dockerignore` (`.env` の焼き込み)

## 10. 残課題 / 要確認

### 10.1 本書の未確定 (回答が入ると本書の記述が変わる)

| # | 項目 | 影響する節 | 確定条件 |
|---|---|---|---|
| OP-R1 | **Q-8 (環境戦略・フラグ方式)** が未回答。暫定既定 A で書いている | §7.1〜§7.3 (OP-H) | ユーザー回答。B (リリースブランチ) なら §7.1 のブランチ表と §7.3 の 1〜2 を差し替える |
| OP-R2 | **マイグレーションツール (D-4)** | §7.4 の「戻し方」列 / §9 の backend 4 | §7.5 の `[Answer]` |
| OP-R3 | **アラート通知先の宛先の値** | §7.5 / [observability.md](observability.md) §4.6 | 同 `[Answer]` |
| OP-R4 | **データ引き継ぎの範囲 (Q-1)** | §6.2 (移送の実行位置は確定済み・対象と方式は未確定) / §6.3 の「v2 のダウンタイム」 | 事業判断 + `Task-2f` (データ量確認)。確定先は `docs/design/data-model.md` |
| OP-R5 | **アカウント基盤の一本化** (併用期間中の二重化をどちらを正とするか) | §6.1 の RL-5 完了条件 ④ / §6.5 | `docs/design/data-model.md` (Task-3a の追加要件) |
| OP-R6 | **許容ダウンタイム (SLO)** — タスク数・ヘルスチェック・登録解除待ちは [infrastructure.md](infrastructure.md) §5.2 / §3.2 で暫定確定した (v2 の単一タスク・ヘルスチェック無しは継承しない) が、**「どれだけ止まってよいか」の目標値が無い** | §6.3 (ダウンタイムの許容判断) / §6.4 の切り戻し判断基準 2 | ユーザー判断。SLO が決まると §6.4 の基準 2 (5xx 率と 2 時間) を SLO と整合させる |
| OP-R7 | **v3 の公開方式** (既存ドメインを付け替えるか、別 URL で公開するか) | §6.3 の ⑥ (ケース A / B) / §6.4 の操作 1 | 使用ドメイン名の確認 ([infrastructure.md](infrastructure.md) §3.6 の Route53 行)。**ケース A を採る場合は TTL 期間中の書き込み分散の対策 (§6.3) も同時に決める**。**v2 の API は ALB の生 DNS 名で公開されている ([infrastructure.md](infrastructure.md) F-11) ため、切替・切り戻しのレバーは FE の公開ドメイン 1 レコードのみである** (同 §9.2) |
| OP-R8 | **Anthropic の Environment を dev / prod で分けるか共有するか** (D-6)。暫定既定は「分ける」 | §5.2 の Environment 節 / §3.3 の⑤ / §4.5 / §10.4 の仮定 1 / [infrastructure.md](infrastructure.md) X-4 | **解消 (2026-07-30)** — §5.2 の `[Answer]` で「分ける」を確定。複数作成できることを一次ソースで確認したため共有ケースの影響範囲は発動しない。**代わりに新規要求 2 件が発生**: Environment を不変として扱う運用 (設定に版履歴が無い) と prod の `limited` networking (同 `[Answer]` の含意 2・4) |

### 10.2 他の設計文書 / 雛形への是正・追記要求 (本書からの先送り)

**本書の編集範囲外にあるため、別の変更として実施する必要がある項目**。
放置すると本書の記述が実装で担保されない:

| # | 対象ファイル | 要求内容 | 本書の該当箇所 |
|---|---|---|---|
| OP-F1 | [observability.md](observability.md) §4.3 または §4.4 | **「アクティブな SSE 接続数」メトリクスを計測項目として追加する** (名前 `sse.active_connections` / 単位 = 接続数のゲージ / 出力元 = アプリからの EMF / 出力間隔 30 秒)。**計測項目の SSOT は同書**であり、本書 §6.3 の暫定定義は追記までのつなぎである。追記されない場合、§6.3 の「起動前に SSE セッション数を確認する」手順が実行不能になり「利用の少ない時間帯に行う」に退行する | §6.3 |
| OP-F2 | [observability.md](observability.md) §4.6 | **「重大度の分類・環境差・トピックの本数は `operations.md` §7.5 が SSOT」の相互参照を 1 行加える** (同節にはしきい値と通知先しか無く、本書がそれを前提にしていることが同書側から辿れない)。しきい値の改訂で分類が変わる場合は本書 §7.5 も同時に直す | §7.5 |
| OP-F3 | [templates/shared/.claude/rules/04-human-checkpoints.md](../../templates/shared/.claude/rules/04-human-checkpoints.md) §2.6 の H-3 行「二重化」列 | 「prod の Anthropic API キーを CI の environment secret に限定して置く」を **「prod の Anthropic API キーは Secrets Manager に置き、CI は OIDC ロールで取得する (GitHub 側に置かない)」** へ差し替える (§4.1 の限定列挙と矛盾している。§4.2 の表は是正済み) | §4.1 / §9 |
| OP-F4 | `templates/backend-repo/.github/workflows/` | **`rollback.yml` の雛形を追加する** (§5.3 の「`rollback.yml` に要求する形」)。現状は雛形が無く、OP-G の第一手段を起動する経路が引き渡し物に含まれていない | §5.3 / §9 |

> **OP-F1〜F4 は 2026-07-30 に解消済み** (メインセッションが対応):
> OP-F1 → [observability.md](observability.md) §4.4.1 に `sse.active_connections` を計測項目として追加 (本書 §6.3 の暫定定義は同節への参照に置き換わる) /
> OP-F2 → 同 §4.6 冒頭に「重大度分類・環境差・通知経路は本書 §7.5 が SSOT」の相互参照を追加 /
> OP-F3 → `04-human-checkpoints.md` §2.6 の H-3 行を「Secrets Manager が唯一の所在。CI は OIDC で取得」へ差し替え /
> OP-F4 → `templates/backend-repo/.github/workflows/rollback.yml` を新規作成 (§5.3 の要求仕様どおり。入力 3 種・prod は environment 承認・Agent 切り戻しはタスク置換とセット)。

### 10.3 他の設計文書から本書に先送りされていた項目の処理

| 出典 | 項目 | 本書での扱い |
|---|---|---|
| [API/settings.md](API/settings.md) ST-Q5 | `sharing_settings` 既存値の移行の**実行タイミング** | **回答** (§6.2 の 5) |
| [API/settings.md](API/settings.md) ST-Q6 | v2 退役時のアカウント基盤の移行 | **先送り** (§6.5 / OP-R5。`data-model.md`) |
| [API/idea-boards.md](API/idea-boards.md) §4 | 切り戻し期限と判断基準 | **回答** (§6.4。公開後 7 日 + 発動基準 4 件) |
| [API/news.md](API/news.md) NW-Q3 | CMS の webhook 受信先の移設時期 | **回答** (§6.5。お知らせ機能の RL-4 ドメイン切替に含める) |
| [observability.md](observability.md) §4.6 | アラート通知先の実体 | **形は回答・宛先は未確定** (§7.5 / OP-R3) |
| [observability.md](observability.md) §4.4 | 安全弁のしきい値を「再デプロイなしで変更できる形」にする | **回答** (§3.3 の④。SSM Parameter Store + TTL 60 秒) |
| [architecture.md](architecture.md) §8 | ツールループ中のトランザクション粒度 (ターン全体で 1 トランザクションの分割可否) | **先送り (条件付き)**: 既定 (ターン全体で 1 トランザクション) を維持する。**再検討の契機を確定**: ①RDS の接続数が上限の 70% に達する ②長時間トランザクションによる vacuum の遅延がメトリクスで観測される。どちらも実測が要るため RL-1 (dev 継続デプロイ) 以降に判断する |
| [API/README.md](API/README.md) API-Q7 | 非同期ジョブの heartbeat しきい値と定期実行の仕組み | **本書の対象外**。値の置き場のみ確定 (§3.3 の④ = SSM)。しきい値と実行方式は**アセット / ナレッジの非同期処理を含む増分**で API 設計側が確定する |

### 10.4 仮定 (違えば §2 の判断が変わる)

- **仮定 1**: Anthropic の **Managed Agent と Environment の両方**を、**環境ごとに別リソースとして
  発行・作成できる** (dev / prod で別の Agent ID・別の Environment ID を持てる)。
  - **Agent を共有せざるを得ない場合**: §5.2 の「dev は自動・prod は承認」という分離が成立せず、
    dev の発行が prod に影響する
  - **Environment を共有せざるを得ない場合**: **dev の tool 定義変更が prod の Agent 実行環境に
    影響し得る経路が残る** (承認を経ずに prod の挙動が変わる)。影響範囲と対応は §5.2 の Environment 節 /
    未確定として OP-R8 に登録済み
- **仮定 2**: Vercel の環境変数スコープ (Development / Preview / Production) で FE の 3 環境を表現する。
  feature ブランチの Preview も dev の BE を指すため、**dev の BE は不特定の Preview から呼ばれる**
  前提で運用する (dev に本番データを置かない理由の 1 つ)
- **依存 (仮定ではなく確認済み)**: §6.1 の RL-2 完了条件 ⑤ と §5.3 の破壊的変更のロールバックは
  **RDS のバックアップ / 手動スナップショットが有効であること**に依存する。
  [infrastructure.md](infrastructure.md) §5.2 (バックアップ保持 dev 7 日 / prod 30 日・prod は削除保護) と
  同 §9.3 (RDS の作り直しを伴う変更では手動スナップショットを承認条件にする) で担保されている
