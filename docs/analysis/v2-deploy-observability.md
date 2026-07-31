# v2 デプロイ・環境分離・シークレット管理・可観測性 実態調査

> 実測日: 2026-07-29 / 対象: hassan-v2-backend (作業ツリー)

本番設計の入力になる事実収集 (デプロイ・環境分離・シークレット管理・可観測性 D-1〜D-8 / O-1)。
**設計提案は書かない**。v3 は AWS を Terraform で IaC 管理し FE は Vercel という方針だが、まず
v2 の現行構成を事実として把握する。

## 調査対象と問い

v2 (hassan-v2-backend) の dev/prod デプロイ手順・タスク定義・サービス定義・設定項目・環境ファイル管理・
ロギング実装・CI ゲート・IaC の有無を漏れなく確認し、「v3 で踏襲するか作り直すか」を判断するための
事実 (現状の挙動・既知のリスクとして repo 自身が記録している事項を含む) を出典付きで揃える。

---

## 1. デプロイ手順の完全な列挙

### 1.1 dev — トリガー: `main` への push (自動)

`main` ブランチへの push で自動実行される — 出典: `hassan-v2-backend/.github/workflows/dev-deploy.yml:1-4`

1. checkout (`fetch-depth: 0`、全履歴) — `hassan-v2-backend/.github/workflows/dev-deploy.yml:9-13`
2. AWS 認証情報を設定 (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` を GitHub Secrets から、リージョン `ap-northeast-1` 固定) — `hassan-v2-backend/.github/workflows/dev-deploy.yml:14-19`
3. Amazon ECR にログイン — `hassan-v2-backend/.github/workflows/dev-deploy.yml:20-22`
4. git remote/user を GitHub Actions bot として設定 — `hassan-v2-backend/.github/workflows/dev-deploy.yml:23-27`
5. タグ名を生成 (`日付-短縮コミットハッシュ`、例 `20260706-37e258a4`) — `hassan-v2-backend/.github/workflows/dev-deploy.yml:28-34`
6. **`stacks/dev/ecs-task-def.json` と `stacks/prod/ecs-task-def.json` の両方**の `image` タグをこのタグに書き換え、`git add` → `git commit` → **`git push origin HEAD` で `main` に直接コミットを push** — `hassan-v2-backend/.github/workflows/dev-deploy.yml:35-45`
7. 生成したタグで git tag を作成し push — `hassan-v2-backend/.github/workflows/dev-deploy.yml:46-50`
8. `stacks/ecs.Dockerfile` で Docker イメージをビルドし、ECR (`hassan-v2-api` リポジトリ) にそのタグでビルド・push — `hassan-v2-backend/.github/workflows/dev-deploy.yml:51-58`
9. `ecspresso` (v2.0.0) をセットアップ — `hassan-v2-backend/.github/workflows/dev-deploy.yml:59-61`
10. `ecspresso deploy --config=stacks/dev/ecspresso.yml` で dev クラスタへデプロイ — `hassan-v2-backend/.github/workflows/dev-deploy.yml:63-65`

備考: ステップ 9 と 10 の間に `- run: |` という中身の無いステップが存在する (`hassan-v2-backend/.github/workflows/dev-deploy.yml:62`)。エラーにはならないが空コマンドであり、編集の残骸に見える。

### 1.2 prod — トリガー: `workflow_dispatch` (手動、`prod_tag` 必須入力)

自動トリガーは無い。オペレーターが `prod_tag` (デプロイしたい git タグ文字列) を指定して手動実行する — 出典: `hassan-v2-backend/.github/workflows/prod-deploy.yml:1-8`

1. 指定された `prod_tag` を `ref` として checkout — `hassan-v2-backend/.github/workflows/prod-deploy.yml:13-16`
2. AWS 認証情報を設定 (dev と同じ GitHub Secrets・同リージョン) — `hassan-v2-backend/.github/workflows/prod-deploy.yml:17-22`
3. `ecspresso` (v2.0.0) をセットアップ — `hassan-v2-backend/.github/workflows/prod-deploy.yml:23-25`
4. `ecspresso deploy --config=stacks/prod/ecspresso.yml` で prod クラスタへデプロイ — `hassan-v2-backend/.github/workflows/prod-deploy.yml:27-29`

**prod-deploy.yml はイメージのビルド・push を一切行わない**。`prod_tag` で checkout した時点の `stacks/prod/ecs-task-def.json` に書かれている image タグ (dev デプロイ時に 1.1-6 で既に書き込み・push 済み) をそのまま ECS に適用するだけ。したがって prod にデプロイされるイメージは、必ず一度 dev デプロイフローを経て ECR に push 済みのものになる。

dev と同様、ecspresso セットアップとデプロイの間に中身の無い `- run: |` ステップがある (`hassan-v2-backend/.github/workflows/prod-deploy.yml:26`)。

### 1.3 image タグのコミット挙動 (明示)

**ある**。dev デプロイのたびに、CI が `stacks/dev/ecs-task-def.json` と `stacks/prod/ecs-task-def.json` の image タグを書き換えて `main` に直接コミット・push する — 出典: `hassan-v2-backend/.github/workflows/dev-deploy.yml:35-45`。

これは `hassan-v2-backend/rules-bank/04-git-workflow.md:7` が定める「**main: 直接コミット禁止**」という規約と矛盾する (規約は develop→main を PR 経由と想定しているが、実際の dev-deploy.yml は `main` push をトリガーにし、CI 自身が `main` に直接コミットする)。判断ルールに従い、実際に走る workflow を正としてこの矛盾を報告する。

### 1.4 ロールバック手段

- **CI/CD 上の明示的なロールバック手順・ワークフローは無い** (`rollback` という名前のジョブ・ステップは dev-deploy.yml / prod-deploy.yml のいずれにも存在しない)。
- ECS のデプロイ設定に **`deploymentCircuitBreaker` (`enable: true`, `rollback: true`) が有効**であり、デプロイが失敗 (ヘルスチェック等) した場合は ECS が自動的に直前のタスクセットへロールバックする — 出典: `hassan-v2-backend/stacks/dev/ecs-service-def.json:3-6`, `hassan-v2-backend/stacks/prod/ecs-service-def.json:3-6`。
- 手動ロールバックの経路としては、`prod-deploy.yml` が `workflow_dispatch` で任意の `prod_tag` を受け付けるため、**過去の git タグを `prod_tag` に指定して再実行すれば、その時点の `ecs-task-def.json` (=古いイメージタグ) で再デプロイできる** — 出典: `hassan-v2-backend/.github/workflows/prod-deploy.yml:2-16`。ただし「ロールバック」という名前の手順・ドキュメントとしては存在せず、通常のデプロイ手順の転用である。
- dev 側は `workflow_dispatch` が無いため、同様の手動ロールバックは `git revert` して `main` に push するか、直接 `ecspresso deploy` をローカル実行する以外に repo 内に手段が無い。

---

## 2. タスク定義の中身

| 項目 | dev | prod | 出典 |
|---|---|---|---|
| CPU (タスク) | 512 | 512 | `hassan-v2-backend/stacks/dev/ecs-task-def.json:34`, `hassan-v2-backend/stacks/prod/ecs-task-def.json:34` |
| メモリ (タスク) | 1024 | 1024 | `hassan-v2-backend/stacks/dev/ecs-task-def.json:38`, `hassan-v2-backend/stacks/prod/ecs-task-def.json:38` |
| コンテナ CPU | 0 (未指定) | 0 (未指定) | `hassan-v2-backend/stacks/dev/ecs-task-def.json:4`, `hassan-v2-backend/stacks/prod/ecs-task-def.json:4` |
| ポート | containerPort/hostPort とも 5000 | 同左 | `hassan-v2-backend/stacks/dev/ecs-task-def.json:20-21`, `hassan-v2-backend/stacks/prod/ecs-task-def.json:20-21` |
| ログドライバ | `awslogs` | `awslogs` | `hassan-v2-backend/stacks/dev/ecs-task-def.json:8`, `hassan-v2-backend/stacks/prod/ecs-task-def.json:8` |
| ログ設定 | group `/ecs/hassan-v2-api-dev`、`awslogs-create-group: true`、region `ap-northeast-1`、stream-prefix `ecs` | group `/ecs/hassan-v2-api` (他同じ) | `hassan-v2-backend/stacks/dev/ecs-task-def.json:9-14`, `hassan-v2-backend/stacks/prod/ecs-task-def.json:9-14` |
| FireLens | **使っていない** (`awslogs` のみ) | 同左 | 同上 |
| ヘルスチェック | **container 定義に `healthCheck` キーは無い** | 同左 | `hassan-v2-backend/stacks/dev/ecs-task-def.json` (全体), `hassan-v2-backend/stacks/prod/ecs-task-def.json` (全体) |
| 環境変数の渡し方 | `environment` のみ。値は `GO_ENV=dev` の1個だけ | `environment` のみ。`GO_ENV=prod` の1個だけ | `hassan-v2-backend/stacks/dev/ecs-task-def.json:26-31`, `hassan-v2-backend/stacks/prod/ecs-task-def.json:26-31` |
| `secrets` キー | **存在しない** | **存在しない** | 同上 (container 定義全体を確認、`secrets` フィールド自体が無い) |

**`secrets` を Secrets Manager / SSM Parameter Store のどちらで参照しているか、という問い自体が成立しない**: task 定義の `environment` に渡されるのは `GO_ENV` (dev/prod の切替キー) 1個のみで、それ以外の設定・シークレット (DB 接続文字列、JWT 鍵、各種 API キー等、§4 参照) は ECS の `secrets` 機構を一切使っていない。

代わりに、アプリ起動時に `GO_ENV` の値で `env/.dev.env` / `env/.prod.env` を `godotenv.Load` で読み込む方式になっている — 出典: `hassan-v2-backend/di/provider.go:83-94`。これらの `.env` ファイルは `stacks/ecs.Dockerfile` の `COPY . .` (`hassan-v2-backend/stacks/ecs.Dockerfile:8`) でイメージに焼き込まれる。ルートの `.dockerignore` は `vendor` しか除外していないため — 出典: `hassan-v2-backend/.dockerignore:1` — `env/` ディレクトリはビルドコンテキストに含まれ、**dev/prod 両方の `.env` ファイルが同一の Docker イメージに同梱される**。dev デプロイでビルドされたイメージと同じタグが後の prod デプロイでもそのまま使われる (§1.2) ため、**dev/prod 共通の単一イメージ**に両環境分の設定ファイルが同梱された状態で運用されている。

---

## 3. サービス定義

| 項目 | dev | prod | 出典 |
|---|---|---|---|
| desiredCount | 1 | 1 | `hassan-v2-backend/stacks/dev/ecs-service-def.json:13`, `hassan-v2-backend/stacks/prod/ecs-service-def.json:13` |
| デプロイ方式 | `deploymentController.type: "ECS"` (ローリング)。CodeDeploy (Blue/Green) は不使用 | 同左 | `hassan-v2-backend/stacks/dev/ecs-service-def.json:10-12`, `hassan-v2-backend/stacks/prod/ecs-service-def.json:10-12` |
| 最小・最大パーセント | min 100% / max 200% | 同左 | `hassan-v2-backend/stacks/dev/ecs-service-def.json:7-8`, `hassan-v2-backend/stacks/prod/ecs-service-def.json:7-8` |
| デプロイサーキットブレーカー | enable + rollback とも true | 同左 | `hassan-v2-backend/stacks/dev/ecs-service-def.json:3-6`, `hassan-v2-backend/stacks/prod/ecs-service-def.json:3-6` |
| 起動タイプ | FARGATE | FARGATE | `hassan-v2-backend/stacks/dev/ecs-service-def.json:16`, `hassan-v2-backend/stacks/prod/ecs-service-def.json:16` |
| ネットワーク構成 | awsvpc、`assignPublicIp: ENABLED`、SG 1個、subnet 2個 | awsvpc、`assignPublicIp: ENABLED`、SG **2個**、subnet 2個 (dev と同じ subnet) | `hassan-v2-backend/stacks/dev/ecs-service-def.json:17-23`, `hassan-v2-backend/stacks/prod/ecs-service-def.json:17-23` |
| ロードバランサ設定 | **`loadBalancers` キーが存在しない** | **`loadBalancers` キーが存在しない** | 同上 (ファイル全体を確認) |
| `enableExecuteCommand` | false | false | `hassan-v2-backend/stacks/dev/ecs-service-def.json:15`, `hassan-v2-backend/stacks/prod/ecs-service-def.json:15` |

**サービス定義に ALB との紐付けが一切書かれていない点は重要な食い違い**: `hassan-v2-backend/README.md:9-15` は dev/prod それぞれの ALB の DNS 名を記載しており (`hassan-v2-api-dev-alb-...`, `hassan-v2-api-alb-...`)、`hassan-v2-backend/docs/file-integrity-monitoring/implementation.md:163-168` にも同じ ALB 情報がある。しかし ecspresso が管理する `ecs-service-def.json` には `loadBalancers` が定義されていない。ECS は稼働中サービスの LB 関連付けを `UpdateService` では変更できない仕様のため、ALB は ecspresso 管理外 (AWS コンソールでの初回手動作成時) で紐付けられたものと推測される (§「推測」参照)。

---

## 4. 設定項目の全体像 (`di/provider.go` の `env` タグ、全 51 個・キー名のみ)

出典: `hassan-v2-backend/di/provider.go:27-80`

| カテゴリ | キー |
|---|---|
| DB | `DATABASE_URL` |
| 認証 | `JWT_KEY`, `ADMIN_JWT_KEY`, `PRIVATE_API_AUTH_TOKEN`, `MICROCMS_WEBHOOK_SECRET` |
| AWS | `S3_BUCKET_NAME` |
| LLM | `AOAI_API_KEY`, `AOAI_API_DEPLOY_NAME`, `AOAI_API_END_POINT`, `OPENAI_API_KEY`, `OPENAI_ENDPOINT`, `GEMINI_API_KEY`, `GEMINI_ENDPOINT`, `CLAUDE_API_KEY`, `CLAUDE_ENDPOINT`, `EXA_API_KEY`, `EXA_ENDPOINT`, `DIFY_GET_COMPANY_FROM_URL_API_KEY`, `DIFY_BUSINESS_PLAN_CHAT_API_KEY`, `DIFY_IDEA_API_KEY`, `DIFY_BUSINESS_PLAN_API_KEY`, `DIFY_RESEARCH_CHAT_API_KEY`, `DIFY_EXTRACT_ASSET_TITLES_API_KEY`, `DIFY_GENERATE_ASSET_DESCRIPTIONS_API_KEY`, `DIFY_EXTRACT_JSON_API_KEY`, `DIFY_API_ENDPOINT`, `DEFAULT_CUSTOM_RESEARCH_DRAFT_MODEL`, `DEFAULT_CUSTOM_RESEARCH_PLAN_MODEL`, `DEFAULT_CUSTOM_RESEARCH_SEARCH_MODEL`, `DEFAULT_CUSTOM_RESEARCH_SEARCH_EXECUTION_MODEL`, `DEFAULT_CUSTOM_RESEARCH_REVISION_MODEL`, `DEFAULT_CUSTOM_RESEARCH_CRITIC_MODEL`, `DEFAULT_CUSTOM_RESEARCH_FINAL_REPORT_MODEL`, `DEFAULT_IDEA_MODEL`, `DEFAULT_IDEA_FALLBACK_MODEL`, `DEFAULT_IDEA_THINK_FALLBACK_MODEL`, `DEFAULT_WRITE_REPORT_MODEL`, `DEFAULT_COMPANY_FROM_URL_MODEL` (32 キー) |
| 外部 API | `RESEND_API_KEY`, `RESEND_FROM_EMAIL`, `MICROCMS_API_KEY`, `MICROCMS_ENDPOINT`, `GOOGLE_SEARCH_API_KEY`, `GOOGLE_SEARCH_ENGINE_ID`, `SERP_API_KEY`, `AZURE_DOCUMENT_INTELLIGENCE_URL_ENDPOINT`, `AZURE_DOCUMENT_INTELLIGENCE_API_KEY`, `GA_PROPERTY_ID`, `GOOGLE_APPLICATION_CREDENTIALS_JSON` |
| その他 | `APP_ENV`, `SWAGGER_HOST` |

補足:
- `GO_ENV` (ECS task 定義の `environment` に載る) は `Config` 構造体のフィールドではなく、`os.Getenv("GO_ENV")` で直接読まれ「どの `.env` ファイルを読むか」だけに使われる — 出典: `hassan-v2-backend/di/provider.go:83-94`。一方 `Config.AppEnv` (`env:"APP_ENV,required"`) は `.env` ファイル内のキーとして別途必須 — `hassan-v2-backend/di/provider.go:28`。両者は別変数だが、運用上は `.env` ファイル内で整合するよう作られている。
- ポート番号は `Config` に含まれず、`router.go` が `os.Getenv("PORT")` を直接読み、未設定時は `5000` にフォールバックする — 出典: `hassan-v2-backend/router/router.go:40-43`。上記 51 キーの一覧には含まれない。

---

## 5. 環境ファイルの管理方式

- `hassan-v2-backend/env/` には `.dev.env` / `.local.env` / `.prod.env` の3ファイルが存在する。
- **3ファイルとも git 管理下 (コミット済み)**。`git ls-files env/` で全て追跡対象と確認 — 出典: `hassan-v2-backend/env/.dev.env`, `hassan-v2-backend/env/.local.env`, `hassan-v2-backend/env/.prod.env` (追跡確認は `git ls-files` コマンドによる、キー名以外は未読)。
- `hassan-v2-backend/.gitignore` に `env/` (または `*.env`) を除外するエントリは無い — 出典: `hassan-v2-backend/.gitignore:1-12` (全12行を確認、該当パターン無し)。
- **疑いあり**: 上記の通り環境変数ファイルが git 追跡下にあり、かつ `di/provider.go` の `Config` 構造体が要求するキー (DB 接続文字列・JWT 鍵・各種 LLM/外部 API キー等、§4 参照) がこれらのファイルに定義されている (`grep` でキー名のみ確認、値は読んでいない)。git 追跡下である以上、過去のコミット履歴にも同名キーの値が残っている可能性がある。
  - この疑いは v2 リポジトリ自身の未追跡ドキュメント `hassan-v2-backend/docs/file-integrity-monitoring/design.md:213` の記述 (「機密の平文コミット＋イメージ焼き込み」) によっても裏付けられている。ただしこのファイル自体は `git status` 上 `??` (untracked) であり、作業ツリーにのみ存在するドキュメントである点に注意。
- `hassan-v2-backend/di/provider.go:91-92` は `GO_ENV=smoke` の場合に `env/.smoke.env` を読む実装になっているが、**現在の作業ツリーの `env/` 配下に `.smoke.env` は存在しない** (`.dev.env` / `.local.env` / `.prod.env` の3つのみ)。過去の git 履歴には `env/.smoke.env` への変更コミットが複数存在する (例: `ee012f7 smoke.env修正` 等)ため、後に削除されたか、リネームされた可能性がある。
- `hassan-v2-backend/rules-bank/01-init.md:159` は「必要な環境変数については `env/.example` を参照してください」と案内しているが、**`env/.example` は現在の `env/` ディレクトリに存在しない**。ドキュメントの案内先が実体と食い違っている。

---

## 6. logger の実装

- 実装は `hassan-v2-backend/logger/logger.go` の1ファイルのみ。`zap.NewProduction()` を環境に関わらず常に使い、`SugaredLogger` をパッケージ変数 `SuggerLogger` としてグローバル公開している — 出典: `hassan-v2-backend/logger/logger.go:7-14`。
- **構造化ログ (JSON)**。`zap.NewProduction()` は JSON エンコーダを使う zap の標準プリセットであり、dev/local/prod で切り替える専用設定は無い (env 別のロガー初期化コードは見つからなかった)。
- リクエスト完了ログは専用ミドルウェアで出力: `request_id` (リクエストごとに `uuid.New()` で生成し `X-Request-ID` ヘッダにも付与)、`status`、`latency`、`method`、`path` — 出典: `hassan-v2-backend/controller/middleware.go:17-46`。
- **本番ではこの完了ログが出ない**。二重の抑制がある。
  1. ミドルウェア内部で `os.Getenv("GO_ENV") == "prod"` または `/alive` へのリクエストならログ出力せず `return` する — 出典: `hassan-v2-backend/controller/middleware.go:36-38`。
  2. さらに `router.go` 側で、`app.Config.AppEnv` が `local` か `dev` のときだけ `RequestLoggerMiddleware()` を `Use` に登録し、それ以外 (prod や他の値) では**ミドルウェア自体を登録しない** — 出典: `hassan-v2-backend/router/router.go:50-53`。
  - 1. は `os.Getenv("GO_ENV")` (raw 環境変数)、2. は `app.Config.AppEnv` (`.env` ファイル内の `APP_ENV` キー) と、**参照している変数が異なる**点に注意 (§4 補足と同じ非対称性)。運用上は連動する想定だが、コード上は別変数。
- アカウント ID / user_id はリクエスト全体には載らず、個別のエラーログ呼び出しでその都度手動で付与されている。例: `controller/business_plan_detailed.go:174` の `logger.SuggerLogger.Errorw("...", "error", err.Error(), "user_id", authAccount.ID.String())`。共通ミドルウェアでの自動付与は無い。
- エラーログの一部は `entity.CodedError.LogFields()` 経由で `error_code` / `error_category` / `error_message` (+ ラップ元がある場合は `error`) を構造化フィールドとして付与する — 出典: `hassan-v2-backend/constants/errors.go:49-59`、呼び出し例 `hassan-v2-backend/controller/controller.go:148`。
- ログレベルの扱い: `zap.NewProduction()` の既定 (Info 以上を出力) から変更する仕組みは見当たらない。環境変数でログレベルを切り替える実装は見つからなかった (`LOG_LEVEL` 等のキーは `di/provider.go` の `Config` に無い)。
- 呼び出し側の一貫性の揺れ: `controller/middleware.go` は `Infow` (キー・バリュー形式) を正しく使う一方、`auth/middleware.go:34` などは `logger.SuggerLogger.Info(fmt.Sprintf(...), err)` のように `Info` (非 `w`) にエラー値を追加引数として渡しており、構造化フィールドにならない書き方が混在している。

---

## 7. CI (`test.yml`) のゲート内容

出典: `hassan-v2-backend/.github/workflows/test.yml`

- トリガー: `main` への pull request — `hassan-v2-backend/.github/workflows/test.yml:3-5`。
- 実行内容:
  1. Go 1.21 セットアップ・モジュールキャッシュ — `hassan-v2-backend/.github/workflows/test.yml:14-25`
  2. `go mod download` — `hassan-v2-backend/.github/workflows/test.yml:27-28`
  3. `go test -v -race -coverprofile=coverage.out ./...` — `hassan-v2-backend/.github/workflows/test.yml:30-31`
  4. カバレッジレポート生成 (`go tool cover -html`) — `hassan-v2-backend/.github/workflows/test.yml:33-34`
  5. Codecov へのアップロード。**`fail_ci_if_error: false`** — `hassan-v2-backend/.github/workflows/test.yml:36-40`
- **マージ不可になる条件**: `go test -race` がテスト失敗すればジョブが失敗する。Codecov アップロード自体はエラーでも CI を失敗させない設定になっている (`fail_ci_if_error: false`) ため、カバレッジ取得の失敗はマージ阻害要因にならない。
- **含まれていないもの**: `go vet` や lint (golangci-lint 等) の専用ステップは無い。`make smoke` (スモークテスト、`hassan-v2-backend/Makefile:21-22`) は CI ワークフローからは呼ばれておらず、ローカル専用と見られる。
- **この CI が実際に「マージをブロックする必須チェック」として GitHub 側 (branch protection / required status checks) に設定されているかは、リポジトリのファイルからは確認できない** (`.github/` 配下には3つの workflow ファイルのみで、`CODEOWNERS` や branch protection を表すコード (例: `.github/settings.yml`) は存在しない)。`hassan-v2-backend/rules-bank/04-git-workflow.md:77-79` には「レビュー1名以上」「CI/CD が成功していること」という運用規約の記述はあるが、これは規約文書であり GitHub 側の強制設定の実在を保証しない。

---

## 8. IaC の範囲

- `*.tf` / `cdk.json` / `template.yaml` / `template.yml` / `cloudformation*` を `vendor` 等を除外してリポジトリ全体から検索したが、**該当ファイルは (vendor 配下の無関係な `template.yml` 1件を除き) 存在しない**。Terraform / CDK / CloudFormation の定義はこのリポジトリに無い。
- VPC / RDS / IAM / ALB / Secrets がどう作られたかの痕跡:
  - `hassan-v2-backend/README.md:9-25` および同内容の `hassan-v2-backend/docs/file-integrity-monitoring/implementation.md:161-177` に、dev/prod の ALB DNS 名・ECS コンソールへのリンク、RDS インスタンスのエンドポイント・DB 名・RDS コンソールへのリンクが**手書きの表として**記載されている。IaC のコード上の定義ではなく、既に作成済みのリソースへの参照表である。
  - `hassan-v2-backend/README.md:72-102` (DB スキーマ更新手順) は、踏み台サーバー経由の SSH トンネル + `psqldef` による**手動**スキーマ適用手順を説明しており、「現在は手動でやってますが、自動化したい...」という記述がある (README.md:70 相当)。IaC/自動化されていないことを repo 自身が認めている。
  - `hassan-v2-backend/docs/file-integrity-monitoring/design.md` (untracked の作業ツリー限定ドキュメント) に、より明示的な記述がある:
    - 「CI は長期 IAM アクセスキーでデプロイしており」「OIDC 未使用・失効なし」 — `docs/file-integrity-monitoring/design.md:152`
    - 「タスク定義はミュータブルなタグ参照 (digest ピン留めなし)。ECR の imageTagMutability を強制する IaC は repo に存在しない」 — `docs/file-integrity-monitoring/design.md:153`
    - 「フェーズ0 (MVP): ... AWS コンソール手作業、または短い AWS CLI スクリプトで立ち上げる。IaC はこの段階では導入しない」「フェーズ1 以降: ... Terraform 化 (`infra/terraform/`) を検討する」 — `docs/file-integrity-monitoring/design.md:279-282`
  - これらから、VPC / ALB / RDS / IAM ロール / セキュリティグループは AWS マネジメントコンソールでの手動作成が前提になっていると読める (repo 内に自動化の痕跡は無い)。ただし `docs/file-integrity-monitoring/design.md` 自体が git 未追跡のローカルファイルである点は明記しておく。

---

## 経路・バリエーション

| 経路 | 実装 | 挙動の差 |
|---|---|---|
| dev デプロイ (push to main, 自動) | `hassan-v2-backend/.github/workflows/dev-deploy.yml` | イメージのビルド・push・タグ書き込みコミット・git tag 作成をすべて実行してからデプロイ |
| prod デプロイ (workflow_dispatch, 手動) | `hassan-v2-backend/.github/workflows/prod-deploy.yml` | ビルド・push・コミットは一切行わず、指定タグの `ecs-task-def.json` をそのままデプロイするのみ |
| リクエストロギング (AppEnv=local/dev) | `hassan-v2-backend/router/router.go:50-51` | `RequestLoggerMiddleware` が登録され、`/alive` 以外はリクエスト完了ログが出る |
| リクエストロギング (AppEnv=prod もしくはそれ以外) | `hassan-v2-backend/router/router.go:52-53` | `RequestLoggerMiddleware` 自体が登録されず、完了ログは一切出ない |
| Swagger UI (AppEnv != prod) | `hassan-v2-backend/router/router.go:32-39` | `/swagger/*any` と `/` が有効 |
| Swagger UI (AppEnv == prod) | 同上 (else 分岐なし、単に未登録) | 上記2ルートが存在しない |

---

## 推測 (確信度つき)

- ALB は ecspresso (`ecs-service-def.json`) の管理外で、AWS コンソールでの初回サービス作成時に手動で紐付けられている — 確信度: 中。根拠: README / implementation.md に ALB の DNS 名・稼働の記載があるのに `loadBalancers` フィールドがどちらの `ecs-service-def.json` にも無く、かつ ECS は既存サービスの LB 関連付けを `UpdateService` で変更できない制約があるため。
- ALB (もし存在するなら) のヘルスチェックパスは `/alive` を指している — 確信度: 中。根拠: `router.go:56-59` に `/alive` エンドポイントがあり、`controller/middleware.go:36` のログ抑制条件にも明示的に `/alive` が特別扱いされている (ヘルスチェック由来のログ洪水を避ける典型パターン)。ただし ALB ターゲットグループの設定自体は repo に無く確認不能。
- VPC / セキュリティグループ / IAM ロールの実体は AWS コンソールで手動作成されたもの — 確信度: 中。根拠: §8 の記述群 (design.md の「フェーズ0は手作業」「IaC は repo に存在しない」という repo 自身の言及)。
- `env/.smoke.env` は過去に存在したが削除された (di/provider.go のコードは残置) — 確信度: 低。根拠: git 履歴に smoke.env への複数コミットがあるが、現在の作業ツリーには存在しない。削除の経緯・意図的かどうかは未確認。
- GitHub 側の branch protection / required status checks で `test.yml` が実際に必須化されているか — 確信度: 低 (推測ではなく未調査に近い)。repo 内に settings-as-code が無いため、rules-bank の運用規約が実態と一致しているかは確認できていない。

---

## 未調査・対象外

- GitHub のブランチ保護ルール・required status checks の実際の設定 (GitHub 側の設定であり、リポジトリのファイルからは検証不可)。
- AWS 側の実リソース (ALB のリスナー/ターゲットグループ設定、VPC/サブネット/セキュリティグループの中身、RDS のパラメータグループ、IAM ロール `ecsTaskExecutionRole` のポリシー本体) は、ARN・DNS 名など repo に記載された参照情報以外は未確認 (コンソールへのアクセスが必要)。
- `env/.dev.env` / `env/.local.env` / `env/.prod.env` の値そのもの、および git 履歴中に実際に平文の秘密情報が含まれているか否かの内容確認 (指示によりキー名以外は読んでいない)。
- `docs/file-integrity-monitoring/design.md` / `implementation.md` に記載された EventBridge/SNS/Chatbot による改ざん検知の仕組みが実際に AWS 上へ導入済みかどうか (ドキュメントは untracked の構想/手順書であり、実施済みかは repo からは確認できない)。
- CI (`test.yml`) 以外の品質ゲート (例えば PR 上のコードレビュー実施状況、`golangci-lint` 等の外部 lint 設定ファイルの有無) は、repo にそれらの設定ファイル自体が見当たらないことのみ確認し、実運用でどう運用されているかは未調査。
- `.worktrees/` および `.claude/worktrees/` 配下は並行作業用の git worktree の複製であり、調査対象から除外した (メインツリーのみを対象とした)。
- hassan-v2-frontend 側のデプロイ・環境分離・可観測性は本調査のスコープ外 (バックエンドのみ)。
- `aws/s3.go` など個別の AWS SDK クライアント実装の詳細 (S3 バケットポリシー等) は今回のデプロイ/可観測性調査の主眼ではないため深掘りしていない。

---

## 抜き取り検証 (オーケストレーター実施。2026-07-29)

本報告は `poc-analyst` 相当のサブエージェントが作成した。`orchestrating-delegation` skill ③ に従い、
**設計に影響する load-bearing な事実を一次ソースで照合した**。結果: **照合した 5 件すべて一致**
(誤りが見つからなかったため全数照合には切り替えていない)。

| 照合項目 | 照合方法 | 結果 |
|---|---|---|
| task 定義の `secrets` 未使用・`environment` は `GO_ENV` のみ | `hassan-v2-backend/stacks/prod/ecs-task-def.json` を JSON パースして `secrets` / `environment` を出力 | **一致** (`secrets` キーなし / `environment` は `GO_ENV` 1 件) |
| `.env` がイメージへ焼き込まれる | `hassan-v2-backend/.dockerignore` の中身は `vendor` のみ / `hassan-v2-backend/stacks/ecs.Dockerfile` は `COPY . .` | **一致** (除外指定がないため `env/` を含む全ファイルがコピーされる) |
| ロールバックは circuit breaker のみ | `hassan-v2-backend/stacks/prod/ecs-service-def.json` の `deploymentConfiguration` | **一致** (`deploymentCircuitBreaker: {enable: true, rollback: true}`) |
| ロガーは常に `zap.NewProduction()` | `hassan-v2-backend/logger/logger.go:10` | **一致** |
| リクエストログが prod で出ない | `hassan-v2-backend/router/router.go:50`〜`:51` (`AppEnv == "local" \|\| AppEnv == "dev"` の条件下でのみ `RequestLoggerMiddleware()` を登録) | **一致** |

### 照合中に追加で判明した事実 (報告に無かったもの)

| 事実 | 出典 |
|---|---|
| **task 定義に `healthCheck` が無い** (コンテナレベルのヘルスチェック未設定) | `hassan-v2-backend/stacks/prod/ecs-task-def.json` (`healthCheck` キーなし) |
| **prod の `desiredCount` が 1** — タスク 1 本構成で冗長性がない | `hassan-v2-backend/stacks/prod/ecs-service-def.json` |
| ログドライバは `awslogs`、ロググループ `/ecs/hassan-v2-api` (`awslogs-create-group: true`) | 同 `ecs-task-def.json` の `logConfiguration` |
| task 定義の `image` に**具体的なタグがコミットされている** (例: `...:20260706-37e258a4`) — CI がリポジトリへコミットする運用の裏付け | 同 `ecs-task-def.json` |

### v3 設計への含意 (判断は設計書側で行う)

**「v2 に合わせる」を理由に以下を省略できない** — v2 の現行方式が本番水準に達していない領域である:

1. **D-5 シークレット管理**: v2 は Secrets Manager / SSM を使っておらず、`.env` をイメージに焼き込み、
   dev/prod で同一イメージを共有している。**v3 は新規に設計する必要がある** (v2 から継承できない)
2. **D-3 ロールバック**: 明示的な手段が無い。**v3 では手順として設計する必要がある**
3. **O-1 構造化ログ**: prod でリクエストログが出ない。アカウント ID の付与も個別実装。
   **v3 では共通ミドルウェアで全環境に出す設計が必要**
4. **D-8 IaC**: v2 に IaC は存在せず、AWS コンソール手作業で構築されている。
   v3 の「全て IaC」は**新規構築**であり、v2 からの移植ではない
5. 可用性: prod が単一タスク・ヘルスチェック無しのため、v3 の非機能要件として
   タスク数とヘルスチェックを明示的に決める必要がある
