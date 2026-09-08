# インフラ構成と IaC 管理範囲

> 本書が回答する本番観点: **D-8** (主) / **D-1・D-3・D-5** (インフラ側の具体化) /
> **O-1・O-5・O-7** (計測・アラートの受け皿となるリソース)。
> 対応する受入基準: **AC-3.6** (+ AC-3.1 のうち「環境ごとの値の持ち方」のインフラ側、
> AC-3.5 の切替に必要なリソース)。
> **対象外の ID と理由は §8.2** (無言の省略をしない)。
> 前提とする事実: [../analysis/v2-deploy-observability.md](../analysis/v2-deploy-observability.md) (実測・抜き取り検証済み)。
> 確定制約: [../../aidlc-docs/inception/productionization/requirements.md](../../aidlc-docs/inception/productionization/requirements.md) の
> C-6 / C-7 / C-12 / C-14 / C-15。決定の経緯: [../../aidlc-docs/inception/productionization/questions.md](../../aidlc-docs/inception/productionization/questions.md) Q-7。
> 必須観点の一覧: [../../.claude/rules/08-production-gates.md](../../.claude/rules/08-production-gates.md)

## 0. 本書の位置づけと未確定の扱い

**本書は infra リポジトリ立ち上げの直接の入力**である (C-15 により staging 環境 (旧 dev。INF-U) の先行構築が最優先)。

ただし **「必要なインフラ構成要素の一覧」はユーザー確認が完了していない**
([design_memo.md](design_memo.md) の未完事項「その他インフラ何が必要か一覧化してあるふぁさんに確認する」)。
そこで本書は次の 2 段構成を採る:

1. **§3 = 確認に使う提案一覧**。要素ごとに用途・環境差・管理主体・**確認ステータス**を持つ。
   一覧そのものの確定は §11.1 の `[Answer]:` で求める。**確認前の要素を「確定」として扱わない**
2. **§2 / §4〜§7 = 一覧の中身に依存しない設計判断**。役割分担・state・環境差の付け方・
   構築順序・IaC 範囲外の線引きは、要素が 1〜2 個増減しても変わらない

| 本書で確定するもの | 本書で確定しないもの (先送り先) |
|---|---|
| Terraform / ecspresso の分担、tfstate の保管と apply 主体 (§4) | 個々のリソースのサイジング根拠 (実測後に §5 の値を改訂) |
| dev / prod の構成差の**付け方**と初期値 (§5) | マイグレーションツールの選定 ([architecture.md](architecture.md) の D-4) |
| 構築順序とリポ間依存 (§6) | 通知先の実体 (Slack チャンネル名) — 運用設計 |
| IaC 範囲外の線引きと理由 (§7) | インフラ要素一覧の最終確定 (§11.1 の `[Answer]:`) |

## 1. 現状 (v2 / PoC) — 事実のみ

### 1.1 v2 の AWS 構成に関する実測事実

すべて [../analysis/v2-deploy-observability.md](../analysis/v2-deploy-observability.md) が SSOT
(下記は本書の判断に直接効くものの再掲。出典は同書の該当節)。

| # | 事実 | 出典 |
|---|---|---|
| F-1 | **IaC が存在しない**。`*.tf` / CDK / CloudFormation はリポジトリに無く、VPC / ALB / RDS / IAM / SG は AWS コンソール手作業で構築されている | 同書 §8 |
| F-2 | ecspresso が管理するのは **ECS のサービス定義とタスク定義のみ** (`region` / `cluster` / `service` / 2 つの定義ファイル) | `hassan-v2-backend/stacks/prod/ecspresso.yml` |
| F-3 | **サービス定義に `loadBalancers` が無い**。ALB との紐付けは ecspresso 管理外で行われている | 同書 §3 |
| F-4 | **prod の `desiredCount` が 1**、**コンテナ `healthCheck` が未定義** | 同書 §2 / §3 の抜き取り検証 |
| F-5 | タスクは `assignPublicIp: ENABLED` の awsvpc。SG は dev 1 個 / prod 2 個、subnet は dev/prod で同一 | 同書 §3 |
| F-6 | task 定義の `secrets` キーが存在せず、`environment` は `GO_ENV` 1 個のみ。設定・秘密は `env/*.env` を Docker イメージへ焼き込んで渡している (dev/prod 同一イメージ) | 同書 §2 / §5 |
| F-7 | CI の AWS 認証は**長期 IAM アクセスキー** (GitHub Secrets の `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`)。OIDC 未使用 | 同書 §1.1 / §8 |
| F-8 | リージョンは `ap-northeast-1` 固定 | 同書 §1.1 |
| F-9 | ロググループは `/ecs/hassan-v2-api` (prod) / `/ecs/hassan-v2-api-dev` (dev)、`awslogs-create-group: true` で**アプリのデプロイ時に自動作成**される (保持期間の設定が定義に無い) | 同書 §2 |
| F-10 | DB スキーマ適用は**踏み台サーバーへの SSH トンネル + `psqldef` の手動実行** | `hassan-v2-backend/README.md:74`, `:81`, `:87` |
| F-11 | API の公開エンドポイントは **ALB の生 DNS 名**が README に記載されている (`hassan-v2-api-dev-alb-….elb.amazonaws.com`。**dev 環境の記述**) | `hassan-v2-backend/README.md:14` |
| **F-13** (2026-09-07 追加。issue #5 の実測) | **prod は生 DNS 名ではなく `api.hassan.jp` の Route53 A (alias) レコードで公開されている** (dev は `dev-api.hassan.jp`)。F-11 は README (dev) 由来の記述で、**prod の実態は別**だった — README を「v2 全体の事実」に一般化した推測が誤りだった (DR-1) | `hassan-terraform` (v2 の Terraform。最終コミット 2025-11-08) の `prod/route53_records.tf` / `dev/route53_records.tf` |
| F-12 | RDS のエンドポイントは `hassan-v2-{dev,prod}-instance-1.….rds.amazonaws.com`。コンソールリンクに `is-cluster=true` が含まれる | `hassan-v2-backend/README.md:24`, `:25` |
| F-13 | S3 は稼働中 (`S3_BUCKET_NAME` を設定に持つ)。`uploadFile` が `ACL: ObjectCannedACLPublicRead` を付けて**恒久・無署名の公開 URL** を返す | `hassan-v2-backend/aws/s3.go`、[API/README.md](API/README.md) D-API-14' |

**F-12 についての注意**: `is-cluster=true` と `-instance-1` という命名から Aurora PostgreSQL
クラスタである可能性があるが、**リポジトリからは確定できない** (エンジン種別・バージョン・
インスタンスクラス・Multi-AZ の有無はいずれも未調査)。§9 の確認事項に含める。

### 1.2 PoC (`claude_managed_agents`) の現状

**インフラは存在しない**。ローカル 127.0.0.1 起動が前提で、設定は `.env` の自動書き換え
(`claude_managed_agents/internal/config/dotenv.go`。BE-3) に依存する。
したがって**本書に移植元は無く、v3 のインフラは全面的に新規設計**である
(v2 も F-1 により IaC 資産ゼロ)。

### 1.3 v2 / v3 の対応表

| 項目 | v2 の現状 | v3 | 継承可否 |
|---|---|---|---|
| インフラの定義 | コンソール手作業 (F-1) | Terraform (C-7) | **新規** |
| ECS のリリース | ecspresso + タスク定義 JSON のリポジトリ commit | ecspresso (**タグの commit は廃止** C-14) | 方式は継承 / 運用は変更 |
| ALB 紐付け | ecspresso 管理外 (F-3) | **ecspresso のサービス定義に含める** (§4.3) | **継承しない** |
| 秘密の受け渡し | `.env` をイメージへ焼き込み (F-6) | Secrets Manager / SSM → task 定義の `secrets` | **継承しない** ([architecture.md](architecture.md) D-5) |
| CI の AWS 認証 | 長期アクセスキー (F-7) | **GitHub OIDC + IAM ロール** | **継承しない** |
| 可用性 | prod 単一タスク・ヘルスチェック無し (F-4) | prod 複数タスク + ALB ヘルスチェック (§5) | **継承しない** |
| DB スキーマ適用 | 踏み台 SSH + 手動 `psqldef` (F-10) | CI から **ECS RunTask** で VPC 内実行 (§2 INF-H) | **継承しない** |
| ログ | `awslogs-create-group` による暗黙作成・保持期間なし (F-9) | **Terraform でロググループを明示作成 + 保持期間を環境別に設定** | **継承しない** |

---

## 2. 設計判断

> 本節が回答する ID: **D-8** / **D-1** (環境ごとの値の持ち方のインフラ側) / **D-5** (器と値の分離) /
> **O-5** (SSE を切らないための ALB 設定)。

| # | 論点 | 採用案 | 却下案と理由 |
|---|---|---|---|
| **INF-A** | tfstate の保管とロック | **S3 (バージョニング + SSE-KMS + パブリックアクセス全ブロック) に保管し、ロックは Terraform の S3 backend が持つロック機構を使う** (`use_lockfile` 相当。採用バージョンで利用可能かを infra リポ立ち上げ時に backend ドキュメントで確認し、満たせない場合のみ DynamoDB ロックテーブルを併設する)。**state ファイルは環境ごとに別キー** | (a) ローカル state: CI から `plan` できず、端末の紛失で state が消える。複数人での作業が成立しない。(b) Terraform Cloud / HCP: 承認フローが GitHub environment (H-4) と二重化し、承認の所在が分かれる。外部 SaaS への依存とコストが増える。(c) DynamoDB ロックを既定で併設: ロック専用テーブルの運用が増える。**新しい Terraform では S3 側のロックで足りるため、必要性が確認できた場合のみ作る** |
| **INF-B** | 環境の分離方式 | **環境ごとに別ルートモジュール (`envs/dev` / `envs/prod`) + 別 tfstate**。共通部分は `modules/` に置き、**差分は変数だけで表現する** ([../../templates/infra-repo/CLAUDE.md.tmpl](../../templates/infra-repo/CLAUDE.md.tmpl) の構成と一致) | (a) Terraform workspace: 同一ルートモジュールで環境を切り替えるため、**`terraform workspace select` の失敗が dev の変更を prod へ適用する経路になる**。C-15 (prod は開発完了後に 1 回) の運用と噛み合わない。(b) 単一 state に両環境: dev の `apply` が prod のリソースを差分対象に含める。(c) `envs/dev` と `envs/prod` にリソース定義をコピー: 片方だけ更新される (v2 の `stacks/dev` と `stacks/prod` で実際に同じ値が二重管理されている — F-4) |
| **INF-C** | ALB のアイドルタイムアウトと SSE | **アイドルタイムアウト 300 秒**。アプリ側の keep-alive 15 秒 ([observability.md](observability.md) §4.4 が SSOT) と**二重化**する。300 秒は 1 ターンの実行時間上限 5 分 (同 §4.4) に合わせた値 | (a) 既定の 60 秒のまま: keep-alive の実装だけが切断防止の手段になり、**最初のイベントまでの遅延 (LLM の初回応答待ち) が 60 秒を超えると接続が落ちる**。[design_memo.md](design_memo.md) の「keep-alive 30 秒で ALB 60 秒に対抗」は v2 の既定値を前提とした暫定策であり、**ALB を IaC で管理する v3 では設定側でも余裕を持たせる**。(b) 3600 秒など極端に長い値: 異常な接続が滞留し、デプロイ時のドレインが長引く。上限が長いほど「切れないこと」を暗黙に期待した実装が入る |
| **INF-D** | ヘルスチェックの主体 | **ALB ターゲットグループのヘルスチェックを唯一の判定主体にする** (パス `/alive`。v2 に同エンドポイントが存在する — [../analysis/v2-deploy-observability.md](../analysis/v2-deploy-observability.md) の推測節)。**ECS コンテナ定義の `healthCheck` は置かない** | (a) 両方に置く: 判定主体が 2 つになり、タスクが落ちたときに「ALB が外したのか ECS が殺したのか」を切り分ける手間が増える。(b) v2 と同じくどちらも置かない (F-4): **プロセスが応答しなくなっても入れ替わらない**。本番水準に達していないため継承しない |
| **INF-E** | タスク数とスケーリング | **dev: `desiredCount` 1 / prod: 2 (2 AZ に分散)**。prod はまず**固定 2** で運用し、Auto Scaling ポリシーは**接続保持型の負荷特性を実測してから**入れる (先送り先: 運用設計) | (a) prod も 1 (v2 の F-4): デプロイ中に全断し、タスク障害が即サービス停止になる。**[API/README.md](API/README.md) J-6 が「`desiredCount 1` を前提にしない」設計 (DB 状態のポーリング配信) を既に採っている**ため、複数タスクは設計の前提でもある。(b) 最初から CPU ターゲット追跡: 主負荷が SSE の接続保持であり CPU 使用率と相関しない ([design_memo.md](design_memo.md) の「主負荷は接続保持」)。**指標を決めずに入れたスケーリングは誤動作する** |
| **INF-F** | ネットワーク配置 | **ECS タスクと RDS を private subnet に置き、外向き通信は NAT Gateway 経由** (dev 1 個 / prod 2 個)。S3 は Gateway エンドポイント (追加課金なし) を使う | (a) v2 方式 (public subnet + `assignPublicIp: ENABLED`。F-5): タスクにパブリック IP が付き、**SG の設定ミスが即インターネット公開になる**。(b) 全経路を Interface エンドポイントで閉じる: **Anthropic API (外部) への通信は VPC エンドポイントで代替できない**ため NAT は必須で、NAT を持ちながらエンドポイントも全種類置くのは費用対効果が悪い (ECR / Secrets Manager / CloudWatch Logs のエンドポイントは、NAT の転送量が問題化した時点で追加する) |
| **INF-G** | 秘密の「器」と「値」 | **器 (シークレット名・KMS キー・IAM 権限・task 定義からの参照) を Terraform で管理し、値は Terraform で管理しない**。値の投入は ①人が AWS コンソール / CLI で 1 回入れる ②アプリ・CI が書き込む (Agent ID など) のいずれか。**非秘密の環境依存値 (Agent ID・エンドポイント URL) は SSM Parameter Store**、**秘密 (DB 接続情報・`ANTHROPIC_API_KEY`・JWT 署名鍵) は Secrets Manager** | (a) 値も Terraform で管理 (`aws_secretsmanager_secret_version` に平文): **tfstate に平文で残る**。tfstate は S3 上の 1 ファイルであり、これを読める範囲すべてに秘密が渡る (v2 が `.env` をイメージに焼き込んでいるのと同じ失敗の再演 — F-6)。(b) すべて Secrets Manager に統一: Agent ID のような非秘密値まで従量課金対象になり、**切り戻し用の版管理は SSM の parameter version でも足りる** ([../../templates/app-monorepo/.github/workflows/deploy-backend.yml](../../templates/app-monorepo/.github/workflows/deploy-backend.yml) の `apply_agent` が「旧 Agent ID を前バージョンとして保持する」ことを要求している) |
| **INF-H** | マイグレーションの実行経路 | **CI (GitHub Actions) から ECS RunTask で「マイグレーション実行専用タスク」を起動し、VPC 内から RDS に接続する**。CI ランナー自身は RDS に到達しない。ログは CloudWatch Logs で読む。**差分検査 (`plan_migration`) が DB 接続を要する方式でも同じ経路を使う**。**この採用案は `deploy-backend.yml` の書き換えを前提とする** — 雛形は当初ランナーから `secrets.DATABASE_URL` で直接接続する形だったため、2026-07-30 に RunTask 方式へ是正済み ([operations.md](operations.md) §5.1 の実行場所表 / 同 §9 の雛形是正表)。**待ち合わせとログ取得の構造 (起動 → 完了待ち → 終了コード判定 → CloudWatch Logs の取得) も同節が SSOT** | (a) 踏み台 + SSH トンネル (v2 の F-10): 鍵の配布と保管が必要で、CI に置くと鍵が長期シークレットになる。**人手前提の手順であり `deploy-backend.yml` の `apply_migration` ジョブに載らない**。(b) RDS をパブリックアクセス可にして CI から直接接続: DB を露出させる。(c) SSM セッションマネージャのポートフォワード: 踏み台インスタンスを維持し続ける必要がある。(d) VPC 内のセルフホストランナー: ランナーの維持管理 (パッチ・スケール) が増える。**RunTask はデプロイ用イメージをそのまま使えるため追加の実行基盤が不要** |
| **INF-I** | CI の AWS 認証 | **GitHub OIDC + 用途別 IAM ロール** (`plan` 用 read-only / `deploy` 用 (ECR push + ecspresso) / `migration` 用 (**`ecs:RunTask` + `ecs:DescribeTasks` + `iam:PassRole` + `logs:GetLogEvents`**) / Agent 再発行用 / E2E 用)。**ロールの一覧・環境ごとの分割・許す `sub` は [§4.5](#45-oidc-の信頼条件-sub-クレーム--モノレポでは-environment-で分ける) の表が SSOT**。本行は用途と権限の内容だけを定め、**本数はここで数えない** (DR-9。2026-08-05 に「3 本」を落とした — §4.5 の新設で 3 リポ時代の本数が実態とずれたため)。**`deploy` ロールには `apply_agent` 用に `secretsmanager:GetSecretValue` (`/hassan-v3/<env>/anthropic/api-key` のみ) と `ssm:PutParameter` (`/hassan-v3/<env>/agent/*` と `.../anthropic/environment-id` のみ) を与える** ([operations.md](operations.md) §4.1 により CI は API キー・Agent ID を GitHub 側に持たない)。長期アクセスキーを作らない / **`ssm:GetParameter` + `ssm:GetParameterHistory` (同じパス。`rollback-backend.yml` の切り戻しが版履歴を読むため。無いと ① が `AccessDenied` で失敗する)**。**信頼条件 (`sub` クレーム) の設計は §4.5** — モノレポ化で `repo:` による分離が使えなくなったため必須 (2026-08-05 追加) | (a) v2 方式の長期アクセスキー (F-7): 失効期限が無く、漏洩時の影響範囲が全操作に及ぶ。v2 自身のドキュメントが「OIDC 未使用・失効なし」をリスクとして記録している。(b) OIDC でロール 1 本に集約: `plan` しかしない CI ジョブが `apply` 相当の権限を持つ。**用途別に分けることで、`plan` を PR にコメントするジョブが書き込み権限を持たない状態を作れる** |
| **INF-J** | v3 のホスト名 | **v2 とは別ホスト名 (別 ALB) を割り当てる**。**ホスト名は `hassan.jp` を親ドメインとし、prod は FE = `app.hassan.jp` (Vercel) / BE = `api.hassan.jp` (ALB) とする** (**2026-08-29 のユーザー決定。§9.3 の Q-INF-3**。dev の 2 件は未確定 = 同項の派生①)。ACM 証明書は Terraform で DNS 検証により発行し、Route53 のレコードのみ管理する (**ホストゾーン自体は既存のものを data source で参照し、Terraform の管理対象にしない**)。**FE と BE を同一親ドメイン配下に置くのは、[frontend.md](frontend.md) の段階2 (HttpOnly Cookie 化) で `Domain=hassan.jp` の Cookie を共有できるようにするため**である (同書 §12.1)。**段階1 の時点では両者は別オリジンであり CORS が必要** (同書 §12.3) | (a) v2 と同一ドメイン・同一 ALB に相乗り: `/themes` などのパスが v2 と衝突し、v3 側にパスプレフィックスが必要になる ([API/README.md](API/README.md) の API-Q1 が**別ドメイン前提でプレフィックス無しの API 設計を確定済み**。相乗りにすると API 設計全体が変わる)。(b) v2 の ALB を Terraform に import して共用: C-14 で import しない方針が確定している。(c) ALB の生 DNS 名を公開エンドポイントにする (v2 の F-11): 全面切替 (C-11) 時に**クライアント側の URL 変更が必須**になり、切り戻しも DNS で行えない。(d) **FE と BE を別の親ドメインに置く** (例: FE = Vercel の既定ドメイン / BE = `hassan.jp` 配下): 段階1 は成立するが、**段階2 で Cookie を共有できず、移行時にドメイン変更 (DNS + ACM + Vercel の独自ドメイン + BE の CORS 許可リスト) を同時に行うことになる**。**段階1 の時点で揃えておけば移行時にドメインを触らずに済む** ([frontend.md](frontend.md) §12.1) |
| **INF-K** | 通知経路 | **CloudWatch アラーム → SNS トピック → AWS Chatbot (Slack)**。**prod は critical に限り SNS の email 購読も併設する** (Slack が使えない間の経路。束ね方と環境差は [operations.md](operations.md) §7.5 が SSOT)。SNS トピックとアラームを Terraform で管理し、**Slack ワークスペース側の連携承認は範囲外** (§7) | (a) Lambda を自作して Slack へ POST: 運用対象のコードが増え、通知経路自身の監視が必要になる。(b) メール (SNS の email サブスクリプション) **のみ**: [observability.md](observability.md) §4.6 が通知先を「開発チーム (Slack)」と定めているため、経路が一致しない。**Slack + メールの併用は採用側**であり、この却下は「メール単独」に対するものである。(c) 環境ごとに 1 トピックへ集約する: prod で「今すぐ見るべきか」が判断できない ([operations.md](operations.md) §7.5 の重大度 2 分類) |
| **INF-L** | WAF | **prod の ALB に AWS WAF をアタッチし、マネージドルール (共通脅威 / 既知の不正入力 / IP レピュテーション) + レートベースルールを入れる。dev には同じルールを `count` モードで入れる** (誤検知を dev で先に観測するため)。**アプリ層のレート制限を WAF に置き換えない** ([auth.md](auth.md) §6.11-3 の決定) | (a) WAF を入れない: 未認証エンドポイントへのボリューム型攻撃がアプリのミドルウェアだけで受け止められる。auth.md が「WAF はアプリ側制限の上位防御として検討する」と本書へ委ねている。(b) dev には一切入れない: prod 固有の誤検知が本番で初めて出る。`count` モードなら **dev の自動テストをブロックせずにルールの当たりを観測できる**。(c) WAF でレート制限を代替してアプリ側を持たない: local / dev で WAF が無い環境の挙動が prod と変わり、**制限の単体テストが書けない** (auth.md の決定に反する) **2026-08-10 (ユーザー決定)**: **管理者経路 (`/admin/*`) の IP 許可リストは本増分では入れない** — [auth.md](auth.md) §6.2 の「追加の層」③ が要求していたが、FE を Vercel に置くと ALB が見る送信元 IP が Vercel の Function になり成立しない ([frontend.md](frontend.md) FE-Q7 = ③ で確定)。**マネージドルールとレートベースルールは本決定の対象外** (引き続き入れる)。**2026-08-29 の追記 (Geo Match)**: **v2 は `AllowJapanOnly` (Geo Match Statement) を運用している** (オーナー確認済み。**IaC が無いため v2 の WAF 設定はリポジトリから確認できない** — §11.3)。**v3 も prod で Geo Match (JP のみ許可) を入れる**。**この判断は [frontend.md](frontend.md) の FE-D 段階移行と対で成立する** — 同書が段階1 で「ブラウザから BE を直接叩く」を採ったため、**ALB に届く送信元 IP はエンドユーザーのもの**であり、Geo ルールが意図どおりに機能する。**段階2 (BE 呼び出しを Vercel のサーバ側へ寄せる) に移ると、送信元は常に Vercel の Function になり、Geo ルールは「全通し」か「全断」のどちらかにしかならない** — したがって**段階2 へ移る増分で Geo ルールの扱いを必ず再設計する** (同書 §2.0 の段階2 作業 5)。**dev は他のルールと同じく `count` モード**にする (E2E や開発者の接続元を先に観測するため)。**2026-08-10 の管理者 IP 許可リストの決定 (入れない) は変えない** — 段階1 では技術的に成立するようになったが、入れるかどうかは別の判断であり FE-Q7 のままである。**2026-09-02 の追記 (レートベースルールのみ dev も block)**: **ルールの性質によって dev の扱いを分ける** — マネージドルール (共通脅威/不正入力パターン/IPレピュテーション) と Geo Match は引き続き `count` (誤検知の観測・E2E/開発者の海外接続元を許容するため)。**レートベースルールだけは dev でも `block` にする** — 単位時間あたりのリクエスト数という単純な閾値であり誤検知がほぼ発生しないため、dev を count のままにして得られるものが無い一方、dev の ALB は公開されているためボリューム型攻撃・スクレイピング・ブルートフォースに対する保護を欠く。**却下**: dev のレートベースルールも `count` のまま (現行) にする案 — dev の ALB が実質無防御になり、レートベースルールは誤検知リスクが低いため block にして失うものがない |
| **INF-M** | 運用アクセス手段 (コンテナ内調査) | **ECS Exec を dev で有効・prod で無効**にし、prod で必要になった場合は**その都度 Terraform で有効化して apply する** (有効化の履歴が残る)。**~~踏み台サーバーを作らない~~ → 2026-08-07 (Q-INF-5) で撤回。踏み台は INF-S として作る** (理由は INF-S 参照) | (a) 常時 prod でも有効: 本番コンテナへ入る経路が常に開く。(b) 踏み台サーバーを維持 (v2 の F-10 の前提): SSH 鍵の配布・パッチ適用・アクセスログの管理が増える。**マイグレーションは INF-H の RunTask で足りるため、踏み台の主用途 (スキーマ適用) は消える** — **ただし「人間が GUI クライアントで DB の中身を見る」用途は ECS Exec では代替できない** (ECS Exec はコンテナへのインタラクティブシェルのみを提供し、ローカルの GUI クライアントへのポートフォワード機能を持たない)。**この抜け漏れが Q-INF-5 で顕在化し、INF-M の「踏み台を作らない」判断を撤回する根拠になった** |
| **INF-S** | 運用アクセス手段 (DB への GUI 接続。2026-08-07 追加。Q-INF-5) | **SSM ポートフォワード専用の踏み台 EC2 (`t4g.nano`) を dev / prod に 1 台ずつ置く**。キーペアなし・inbound ルール 0 本 (SSM Agent の outbound 443 のみで成立)。**常時 stopped、使う時だけ起動し 60 分で自動停止**。RDS への到達は `:5432` のみ、SG は踏み台からの通信のみ許可。`ssm:StartSession` は人間の IAM ロールにのみ付与し、CI の OIDC ロールには付けない (prod は dev と別ロール)。**承認は挟まない** — 誰がいつ繋いだかは CloudTrail の `StartSession` に残るが、ポートフォワードの通信内容自体は記録できない (Session Manager のセッションログはシェル用)。**人間が使う DB 認証情報はアプリ用と分離した read-only ロール** ([INF-Q](#) 参照。書込が要る調査は都度払い出しの別ロール)。**AMI とパッチ適用の方針 (2026-09-02 追記)**: 起動時に SSM パラメータ (`al2023-ami-kernel-default-arm64`) から最新 AMI を解決するが、`lifecycle.ignore_changes` で以降の AMI 更新を無視する (**起動のたびに作り直されるのを避けるため**)。**この結果、明示的に `terraform taint` / `-replace` で再作成しない限り、OS パッケージは初回作成時点のまま更新されない** — 常時 stopped で稼働時間が短いとはいえ、起動している間は攻撃対象になり得るため、**四半期ごと (または CVE 公表時) に `-replace` で再作成する運用手順を持つ** (自動化はせず、手順として明記するに留める。頻繁な自動再作成は「使う時だけ起動する」設計と衝突する) | (a) v2 と同じ SSH 踏み台 (F-10): 秘密鍵の配布・失効管理が要り、22 番ポートの inbound が「開いた入口」になる。監査は sshd のログ止まり。(b) ECS Exec だけで済ませる (INF-M の当初案): GUI クライアントへのポートフォワードができず、SQL を使った調査手段として現実的でない。(c) RDS をパブリックアクセス可にする: DB を直接インターネットに晒す。(d) 常時起動の踏み台: 攻撃対象時間が常に開き、EC2 のパッチ運用も継続的に発生する。**常時 stopped + 使う時だけ起動 + 自動停止**なら、稼働中のみが攻撃対象になり課金も EBS 8GB のみで済む |
| **INF-N** | ログの保持期間 | **ロググループを Terraform で明示作成し、保持期間を dev 30 日 / prod 400 日に設定する** (`awslogs-create-group` による暗黙作成をやめる。**本書がロググループと保持期間の SSOT** — [observability.md](observability.md) §8 の残課題のうちインフラ側をここで確定する) | (a) v2 方式 (F-9): デプロイ時に暗黙作成されるため**保持期間が「無期限」になり、費用が単調増加する**。IaC の管理対象から外れ、削除・変更の履歴も残らない。(b) prod も 30 日: 監査ログ ([observability.md](observability.md) §4.5) の追跡可能期間が 1 か月になり、四半期単位の調査ができない |
| **INF-O** | v2 インフラとの関係 | **v2 の稼働中リソースを Terraform に import せず、v3 のリソースを新規に作る** (C-14)。共有するのは**既存の Route53 ホストゾーン (参照のみ)** に限る | (a) v2 を import して同じ IaC で管理 (Q-7 の選択肢 C): 稼働中リソースの import に本番停止リスクがあり、全面切替 (C-11) で廃止予定のものに投資することになる。(b) ホストゾーンも新規作成: ドメインの委譲 (NS レコードの変更) が必要になり、v2 の名前解決に影響する |
| **INF-Q** | **DB 運用アクセス (踏み台経由 GUI 接続) の権限分離** (2026-09-02 ユーザー決定) | **人間が DB に接続する際の認証情報を、アプリ用 (書込可) とは別の read-only 専用 DB ロール・別 Secrets Manager シークレットとして用意する**。踏み台経由の GUI 接続は既定でこの read-only シークレットを渡す。**書込を要する調査は都度払い出しの別ロールとし、人間用の常設アクセスに書込可を持たない**。RDS パラメータグループで `rds.force_ssl` を有効化し、踏み台↔RDS 間を含め TLS を必須にする | (a) アプリ用シークレットをそのまま人間の接続に流用: 誤って本番データを UPDATE/DELETE できる上、担当者交代時のローテーションがアプリの再デプロイを要求する (人間用とアプリ用が分離されていないため)。(b) 人間用ロールを都度払い出しのみにし常設を持たない: 障害調査で read だけ即座に確認したい場面まで払い出し待ちになる。**read-only は常設・write は都度払い出しという非対称構成**が両立する |
| **INF-R** | **ECS タスクの outbound (egress) 制御** (2026-09-02 ユーザー決定) | **ECS タスクの SG egress を 443/tcp のみに制限する**。Managed Agent 側が `networking.type = limited` + `allowed_hosts` で接続先を明示列挙する (X-4) のと対称に、**ECS 側も NAT を経由する行き先を意識的に絞る対象として明記**する。3.1 節で「要確認」のままになっている Interface エンドポイント (ECR / Secrets Manager / CloudWatch Logs) の先出しは、コスト最適化だけでなく **NAT を通る通信を Anthropic API 相当に限定する**セキュリティ上の効果も持つため、要否の検討時にこの観点を含める | (a) 現行のまま (全ポート/全宛先許可): LLM を扱うアプリではプロンプトインジェクション等でコンテナが乗っ取られた場合、任意の外部サーバーへのデータ持ち出し (exfiltration) を防げない。Managed Agent 側だけ `allowed_hosts` で絞り、ECS 側は無制限という非対称な状態を放置することになる。(b) AWS Network Firewall でドメイン単位に絞る: 確実だが導入・運用コストが増える。**まず SG での 443 限定を採用し**、ドメイン単位の制御は Interface エンドポイントの前倒し導入や必要性が具体的に出た時点で追加検討する |
| **INF-T** | **監査証跡 (CloudTrail)** (2026-09-02 ユーザー決定) | **アカウント全体の管理イベントを記録する Trail を Terraform で作成し、専用 S3 バケット (ログファイル検証を有効化) へ保存する**。保持期間は INF-N のロググループとは独立に、**Trail のイベント履歴自体は CloudTrail の既定 90 日保持に加え、S3 側でライフサイクルを設定して長期保存する** (期間は運用開始後に確定。§5.1 の規則 3 に準じ dev/prod で差を付けない — 監査証跡を dev だけ薄くする理由が無い)。**データイベント (S3 の `GetObject` 等) は最初は有効化しない** — 対象を絞る必要が具体的に出た時点で追加する。**踏み台の `StartSession` (INF-S) を含む全操作の記録の起点**になる | (a) 現行のまま作らない: CloudTrail の既定保持 (90 日) すら Trail が無ければ有効にならず、**同一アカウントに同居する v2 (コンソール手作業構築。F-1) を含め、いつ・誰が何を変更したかを追跡する手段が無い**。踏み台経由の DB アクセス (INF-S) が「誰がいつ繋いだかは CloudTrail に残る」と前提にしている以上、Trail 自体が資源として存在しないとその前提が成立しない。(b) AWS Organizations 全体の Trail: マルチアカウント化していない (Q-INF-2 で単一アカウント確定) ため、組織単位の集約は過剰な複雑さになる。(c) データイベントも最初から全種有効化: S3 の読み取りアクセスまで全記録するとログ量とコストが跳ね上がる。**必要になったら対象バケットを絞って追加する**方が費用対効果に合う |
| **INF-P** | **信頼プロキシ CIDR のアプリへの受け渡し** (2026-08-29 追加。[auth.md](auth.md) §6.11-3 の R-13 / 実装リポ `aillio-dev-org/hassan-v3` の issue #37) | **Terraform が VPC の CIDR と ALB を収容する subnet の CIDR を `output` として公開し、ecspresso のタスク定義テンプレートが tfstate 経由でそれを ECS タスク定義の `environment` に渡す** (§4.2 の一方向連携に乗せる。値は**非秘密**なので Secrets Manager / SSM を使わない = [operations.md](operations.md) §3.3 の**分類② のインフラ由来**)。**アプリは受け取った CIDR を `gin.SetTrustedProxies` に設定し、`c.ClientIP()` をレート制限の IP キーに使う** ([auth.md](auth.md) §6.11-3 が SSOT。**この値が渡らないと、`X-Forwarded-For` ヘッダを偽装するだけで未認証レート制限を回避できる**)。**dev / prod で値が空ならアプリを起動させない** (同節)。**local は空値 = プロキシを 1 つも信頼しない** | (a) **CIDR を infra リポの README に書き、backend の env ファイルへ人が書き写す**: §4.2 が却下済みの「出力値を手で書き写す」と同型で、VPC の作り直し・subnet 追加が backend 側に反映されず**制限が静かに無効化される** (F-3 と同種の乖離)。(b) **`0.0.0.0/0` を渡して全プロキシを信頼する**: `SetTrustedProxies` を設定しないのと等価で、issue #37 が塞ごうとしている穴がそのまま残る。(c) **SSM Parameter Store に置いて実行中に読み替える (分類④)**: 信頼境界はネットワーク構成と一体で変わる値であり、**タスク置換と同時に切り替わる方が安全**。再デプロイなしで変えたい要求も無い。(d) **ALB の固定 IP を渡す**: ALB のノード IP は AWS 側の都合で変動するため、固定値として扱えない |

| **INF-U** | **環境モデルの改訂 — staging の追加と dev のブランチ単位プレビュー化** (2026-09-07 ユーザー決定。Q-INF-6) | **local / dev / staging / prod の 4 環境**。**staging** = 従来の dev (`main` の継続デプロイ・受入確認 = C-15 の先行構築対象。FE = Vercel の Preview / BE = `envs/staging`)。**dev** = **PR 単位の使い捨てプレビュー**: FE (Next.js `output: standalone`) と BE を同じ ECS クラスタで動かし、`pr-<N>.dev.<domain>` (FE) / `pr-<N>-api.dev.<domain>` (BE) を自動発行する。**共有基盤 (VPC / クラスタ / ALB / RDS 1 本 / ワイルドカード ACM・Route53 / ECR / OIDC ロール / Fargate Spot キャパシティプロバイダ) は Terraform `envs/dev` が持ち、PR 単位のリソース (ECS サービス・TG・ALB リスナールール・DB スキーマ・Managed Agent) は app リポの `deploy-preview.yml` + ecspresso が作成・破棄する** (X-11)。契機は PR の `preview` ラベル (付与 = 構築 / 除去・close = 破棄 / 付いた状態での push = 再デプロイ。[operations.md](operations.md) §5.1.2)。DB は RDS 1 本を **PR 単位のスキーマ** (`br_pr_<N>`。`search_path` で切替) で分離し、マイグレーションは承認なしで自動適用 (使い捨てのため H-2 の対象外)。**FE ホストのリスナールールに ALB の OIDC 認証** (IdP は Google Workspace を暫定既定) を付けて社内に閉じる。BE ホストは OIDC を付けない (ブラウザの XHR が IdP リダイレクトを辿れないため。アプリの JWT 認証 + WAF で staging / prod と同じ扱い)。**preview のみ Fargate Spot**。同時数の上限は 10 (超過時は新規の構築を失敗させ PR にコメント。上限値は暫定)。**旧記述で「dev」が「`main` の継続デプロイ先」を意味する箇所は staging に読み替える** (本書 §4.5 / §5 / §6 と [operations.md](operations.md) §3 / §5 / §7、rule 04 の環境表は本決定で書き換えた) | (a) 環境を増やさず feature ブランチの Vercel Preview + 共有 dev BE で検証する (旧方針): BE の変更をマージ前に検証できず、prompt / tool schema を変える PR は `main` に入れて初めて動く。(b) PR 単位のリソースも Terraform で管理する: 個数が動的で state が肥大し、`plan` の差分が読めなくなる (infra リポの絶対ルール 2 と衝突)。(c) PR ごとに `CREATE DATABASE`: 接続文字列が PR ごとに変わり Secrets の払い出しが要る。スキーマなら接続情報は共有 1 本で足りる。(d) Managed Agent を dev で 1 本共有: D-6 が検証したい変更 (prompt / tool schema) を preview で見られない。(e) IP 許可リストで閉じる: リモートワークの IP 変動に弱い。(f) FE / BE を同一ホストに置きパスで振り分ける: BE にパス接頭辞を要求するか FE でプロキシする必要があり、staging / prod と実行形が変わる (段階1 はブラウザが BE を直接叩く — [frontend.md](frontend.md) §12.2) |

---

## 3. インフラ構成要素の提案一覧 (ユーザー確認用)

> **2026-09-07 (INF-U)**: 本節の表の「dev」列の値は **staging (旧 dev) と dev (preview 基盤) の両方**に当てはまる。
> 両者で異なる要素 (Fargate Spot / OIDC 認証 / FE 用 ECR / ワイルドカード証明書 / PR 単位リソース) だけを §3.2 に「dev のみ」として追記した。

> 本節が回答する ID: **AC-3.6** (洗い出し) / **D-8** (管理範囲)。
> **この一覧は提案であり確定ではない**。確定は §11.1 の `[Answer]:` で求める。

**管理主体の記号**: `TF` = Terraform (infra リポ) / `ECS` = ecspresso (app モノレポの `backend/`) /
`手動` = IaC 範囲外 (理由は §7) / `外部` = AWS 外のサービス側で設定。
**確認ステータス**: `要確認` = あるふぁさん確認の対象 / `前提` = 既存の確定制約から導かれ確認不要
(C-6 / C-7 / C-14 / 既存設計書の決定に紐づくもの)。

### 3.1 ネットワーク

| 要素 | 用途 | dev / prod の差 | 管理主体 | 確認 |
|---|---|---|---|---|
| VPC | v3 専用の VPC を新規作成 (v2 と分離。INF-O) | CIDR が異なるだけ | TF | 前提 |
| public subnet × 2 AZ | ALB / NAT Gateway の配置 | 同一構成 | TF | 前提 |
| private subnet × 2 AZ | ECS タスク / RDS の配置 (INF-F) | 同一構成 | TF | 前提 |
| NAT Gateway | タスクの外向き通信 (Anthropic API・ECR・Secrets Manager) | **dev (preview) 1 個 / staging 1 個 / prod 2 個 (AZ 冗長)** | TF | 前提 (2026-09-09 ユーザー回答。B-1: dev/staging はコスト優先で 1 個、prod のみ AZ 冗長) |
| S3 Gateway エンドポイント | S3 通信を NAT を通さない | 同一 | TF | 前提 |
| セキュリティグループ (ALB / ECS / RDS / RunTask) | 三段構成 (ALB→ECS→RDS のみ許可)。**ECS の egress は 443/tcp のみ** (INF-R) | 同一 | TF | 前提 |
| Interface エンドポイント (ECR / Secrets / Logs) | NAT 転送量の削減。**NAT を通る通信を Anthropic API 相当に限定するセキュリティ上の効果も持つ** (INF-R) | — | TF | 前提 (2026-09-09 ユーザー回答。B-2: **初期導入しない**。NAT 転送量が問題化した時点、またはセキュリティ要件が具体的に出た時点で追加する) |
| **S3 Gateway エンドポイントのポリシー** (2026-09-09 追加。#17 確認事項 1) | 既定 (ポリシー無し) は全 S3 アクション・全バケットを許可し、private subnet から他アカウントの任意バケットへ到達できてしまう (データ持ち出し経路) | 同一 | TF | 前提 (2026-09-09 ユーザー回答。D-1: **ポリシーを付ける**。許可範囲は「自アカウントのバケット」+ **ECR のレイヤ格納バケット** (`arn:aws:s3:::prod-<region>-starport-layer-bucket/*` など、AWS が公開しているリージョン別バケット名。ECR pull がここを経由するため絞りすぎるとイメージ取得が壊れる) に限定する |
| **VPC Flow Logs** (2026-09-09 追加。#17 確認事項 2) | ネットワーク層の事後追跡・疎通トラブルの切り分け。設計に記述が無かった欠落 | **prod のみ取得** (dev / staging は取らない。転送量課金を避ける) | TF | 前提 (2026-09-09 ユーザー回答。D-2: **REJECT のみを S3 へ出力し 90 日保持**。ALL を取らない — 許可された通信の全量記録は費用対効果が低い) |
| 踏み台 EC2 (`t4g.nano`。private subnet) | 人間が DB へ GUI 接続するための SSM ポートフォワード専用ホスト (INF-S) | 環境ごとに 1 台・常時 stopped。IAM ロールは環境ごとに別 | TF | 前提 (2026-08-07 ユーザー決定・Q-INF-5) |

### 3.2 コンピュート・配信

| 要素 | 用途 | dev / prod の差 | 管理主体 | 確認 |
|---|---|---|---|---|
| ALB + リスナー (443) + ターゲットグループ | HTTPS 終端・SSE の通し口 | **アイドルタイムアウト 300 秒は共通** (INF-C)。証明書のドメインが異なる | TF | 前提 |
| ターゲットグループのヘルスチェック | `/alive` / 判定主体はここだけ (INF-D) | 同一 | TF | 前提 |
| ALB のアクセスログ (S3) | リクエスト単位の事後調査 | **prod のみ有効** | TF | 前提 (2026-09-09 ユーザー回答。B-3: dev / staging では有効にしない) |
| ECR リポジトリ (backend) | backend イメージ。**タグ不変 (immutable) + スキャン有効 + ライフサイクル (直近 N 世代保持)** | **環境ごとに分ける** (`hassan-v3-dev-backend` / `hassan-v3-staging-backend` / `hassan-v3-prod-backend`) | TF | 前提 (2026-09-09 ユーザー回答。B-4: **分割する**。共有だと preview ロール (`hassan-v3-dev-preview`。#42) の削除権限が prod のイメージへ届く経路が生まれる — 実装リポ `hassan-v3-infra` の `modules/iam/README.md` の残存リスクを参照。分割は #34 / #44 で実施する) |
| ECS クラスタ (Fargate) | タスクの実行基盤 | 環境ごとに 1 クラスタ | TF | 前提 |
| **ECS サービス / タスク定義** | アプリの実行単位・リリース | `desiredCount` dev 1 / prod 2 (INF-E) | **ECS** | 前提 (C-14) |
| マイグレーション実行タスク定義 | INF-H の RunTask 用。**接続情報は `secrets` で Secrets Manager から注入する** (CI に DB 接続情報を渡さない — [operations.md](operations.md) §4.1) | 同一 (イメージは同じ) | **ECS** | 前提 |
| **ECR リポジトリ (frontend)** | dev (preview) の FE イメージ (Next.js `output: standalone`) | **dev のみ** (staging / prod の FE は Vercel) | TF | 前提 (INF-U) |
| **ACM ワイルドカード証明書 + Route53 ワイルドカードレコード** (`*.dev.<domain>` → ALB) | preview の URL 自動発行 | **dev のみ** | TF | 前提 (INF-U。ホスト名は Q-INF-3 派生①) |
| **ALB リスナールール (PR 単位)** | ホストヘッダ `pr-<N>.dev.<domain>` → FE の TG (**`authenticate-oidc` 付き**) / `pr-<N>-api.dev.<domain>` → BE の TG。リスナーの既定アクションは 404 | **dev のみ** | **`deploy-preview.yml`** (Terraform 管理外。X-11) | 前提 (INF-U) |
| **Fargate Spot キャパシティプロバイダ** | preview のコスト削減。中断されても使い捨て環境なので再起動で足りる | **dev のみ** (staging / prod は通常 Fargate) | TF | 前提 (INF-U) |
| **ALB の OIDC 認証用 IdP クライアント** | preview の FE ホストを社内に閉じる。クライアントシークレットは Secrets Manager (INF-G の器) | **dev のみ** | TF (器) / 値は人が投入 | 前提 (INF-U。IdP は Google Workspace を暫定既定) |
| AWS WAF (ALB にアタッチ) | 未認証エンドポイントの上位防御 + **Geo Match (非 JP を block)** (INF-L) | **prod = block / dev,staging = count** | TF | 前提 (2026-09-09 ユーザー回答。B-5: マネージドルール (Common / KnownBadInputs / IPReputation) + レートベース + Geo Match を導入する。**v2 の `AllowJapanOnly` は `default_action allow` の no-op だったため引き継ぐ実体が無く、v3 は `not_statement` で「JP 以外」を block として新規定義する** (#9 の PR #41 で実装済み)。**prod へ block で適用する前に #49 (WAF ログ配信・`SizeRestrictions_BODY` の扱い・Geo Block の副作用確認) を解消すること** |

### 3.3 データストア

| 要素 | 用途 | dev / prod の差 | 管理主体 | 確認 |
|---|---|---|---|---|
| **Aurora PostgreSQL (Provisioned)** | アプリの DB (C-6) | **dev(preview)・staging: Single-AZ 相当 (1 ライター) / prod: Multi-AZ (ライター + リーダー)**。インスタンスクラスは §5 | TF | 前提 (2026-09-09 ユーザー回答。B-6: **Aurora PostgreSQL (Provisioned) に確定** — RDS for PostgreSQL ではない。F-12 により v2 の実クラスは未調査のままだが、種別自体は Serverless v2 ではなく Provisioned を採る。**`modules/rds` は既にこの構成で実装済み** — 本行はその実装に設計側を追随させたもの) |
| 自動バックアップ + PITR | 復旧手段 | **dev(preview)・staging 7 日 / prod 30 日** | TF | 前提 (2026-09-09 ユーザー回答。B-7: prod 30 日で確定) |
| ストレージ暗号化 (KMS) | 保管時の暗号化 | 両環境で有効 | TF | 前提 |
| 削除保護 (`deletion_protection`) | 誤削除防止 | **dev 無効 / prod 有効** | TF | 前提 |
| パラメータグループ | ログ設定 (`log_min_duration_statement` 等) | 同一 (全環境) | TF | 前提 (2026-09-09 ユーザー回答。B-8: **`log_min_duration_statement = 1000` (ms) を全環境で有効化**。運用開始後の実測で調整する) |
| S3 バケット (アセット・ナレッジのファイル) | 添付ファイルの保管。**非公開 + ACL を付けない + presigned URL のみ** ([API/README.md](API/README.md) D-API-14') | バケットを環境ごとに分離 | TF | 前提 |
| 同バケットの CORS | ブラウザから presigned URL で GET する場合に必要 | **許可オリジン = FE のホスト名** (prod は `https://app.hassan.jp`。dev は Q-INF-3 の派生①) | TF | **前提** — [frontend.md](frontend.md) §12.3 の末尾が「FE はダウンロード URL をブラウザで直接開く」と回答済み |
| 同バケットのライフサイクル | 不完全マルチパートの削除・世代管理 | 同一 | TF | 前提 (2026-09-09 ユーザー回答。B-9: **不完全マルチパートを 7 日で削除、世代管理 (バージョニング) は導入しない** — 添付ファイルは削除 API で消す前提であり、S3 側の世代保持は要求されていない) |
| S3 バケット (ALB アクセスログ用) | 3.2 のログ出力先 | prod のみ | TF | 前提 (§3.2 の ALB アクセスログと同じ判断。B-3) |

### 3.4 設定・シークレット

| 要素 | 用途 | dev / prod の差 | 管理主体 | 確認 |
|---|---|---|---|---|
| Secrets Manager のシークレット (器) | DB 接続情報 / `ANTHROPIC_API_KEY` / JWT 署名鍵 (`JWT_KEY` / `ADMIN_JWT_KEY`) / 外部 API キー | 環境ごとに別シークレット | TF (**値は手動** INF-G) | 前提 ([auth.md](auth.md) §6.8) |
| **DB 運用アクセス用シークレット (人間用 read-only)** | 踏み台経由 GUI 接続で使う、アプリ用とは別の read-only DB ロールの認証情報 (INF-Q) | 環境ごとに別シークレット。**アプリ用シークレットと共有しない** | TF (**値は手動** INF-G と同様) | 前提 (2026-09-02 ユーザー決定) |
| SSM Parameter Store | **Agent ID / Environment ID** (版管理で切り戻し可能に) / 環境依存の非秘密値 / **Agent 発行元のハッシュ記録** | 環境ごとに別パス (`/hassan-v3/<env>/...`) | TF (器) / **CI が値を書く** | 前提 (D-6。分類は [operations.md](operations.md) §3.3 の④・⑤) |
| **Terraform の `output` (信頼プロキシ CIDR)** | **VPC / ALB 収容 subnet の CIDR をアプリへ渡す** (INF-P)。ecspresso が tfstate から解決し、ECS タスク定義の `environment` に載せる (§4.2)。用途は `gin.SetTrustedProxies` = 未認証レート制限の IP キーの信頼境界 ([auth.md](auth.md) §6.11-3) | **環境ごとに値が異なる** (VPC が別。INF-B) | TF (**出力の定義**) / ECS (**タスク定義への転記**) | 前提 |
| KMS キー | Secrets / RDS / S3 / tfstate の暗号化 | 環境ごとに別キー | TF | 前提 |
| ECS タスク実行ロール / タスクロール | `secrets` の取得 / S3・SSM へのアクセス | 環境ごとに別ロール (**dev のロールが prod のリソースを参照できないこと**) | TF | 前提 |

### 3.5 可観測性

| 要素 | 用途 | dev / prod の差 | 管理主体 | 確認 |
|---|---|---|---|---|
| CloudWatch ロググループ (アプリ / RunTask) | アプリログの集約 (O-1) | **保持期間 dev 30 日 / prod 400 日** (INF-N) | TF | 前提 |
| CloudTrail Trail + 専用 S3 バケット | アカウント全体の管理イベントの監査証跡 (INF-T)。踏み台の `StartSession` (INF-S) を含む | 環境差なし (アカウント共通の Trail 1 本) | TF | 前提 (2026-09-02 ユーザー決定) |
| GuardDuty / IAM Access Analyzer | 脅威検知・意図しない外部アクセス許可の検出 | — | — | 前提 (2026-09-09 ユーザー回答。B-14: **今回は導入しない**。運用体制が整った時点で別途判断する) |
| メトリクスフィルタ | ログから LLM 失敗・429 等を抽出 ([observability.md](observability.md) §4.3 / §8 の仮定「ログからのフィルタで始める」) | 同一定義 | TF | 前提 |
| CloudWatch アラーム | [observability.md](observability.md) §4.6 の AL-1〜AL-7 (しきい値の SSOT) | **アラーム自体は dev / prod とも AL-1〜AL-7 の全件を作る**。**通知先に繋ぐ範囲が環境で変わる** (dev は AL-6 のみ) — 環境差の SSOT は [operations.md](operations.md) §7.5 | TF | 前提 |
| SNS トピック | アラームの通知先 (INF-K) | **prod 2 本** (`alerts-critical` / `alerts-warning`) **/ dev 1 本** (`alerts-dev`)。束ね方と対応するアラーム番号は [operations.md](operations.md) §7.5 | TF | 前提 |
| **SNS の email 購読** | Slack が使えない間の経路。**prod の `alerts-critical` のみに付ける** ([operations.md](operations.md) §7.5) | prod のみ | TF (**確認メールの承認は受信者本人** = 外部) | 前提 (2026-09-09 ユーザー回答。B-13: **仕組みは確定** (prod の critical のみ)。**宛先アドレスそのものは設計の管理対象にしない** — INF-G の「器と値の分離」と同じ扱いで、値は構築時に人が Terraform 変数として投入する (`.tf` に平文で書かない) |
| AWS Chatbot (Slack 連携) | Slack への配信 | 同一 | TF (**ワークスペース承認は外部** §7) | 前提 (2026-09-09 ユーザー回答。B-10: **Slack を使う**) |
| CloudWatch ダッシュボード | [observability.md](observability.md) §6 の最低限ダッシュボード | prod のみ | TF | 前提 (2026-09-09 ユーザー回答。B-11: prod のみ・§6 の最低限セットで確定) |
| AWS Budgets + 予算アラート | **AWS 利用料**の急増検知 (LLM コストは AWS 課金ではないため別系統 — [observability.md](observability.md) AL-4 が担当) | prod に予算アラート / dev,staging は少額のしきい値 | TF | 前提 (2026-09-09 ユーザー回答。B-12: 導入する。**具体的な金額は構築時に変数として投入する** (器と値の分離。INF-G と同じ扱い) |

### 3.6 CI/CD・その他

| 要素 | 用途 | dev / prod の差 | 管理主体 | 確認 |
|---|---|---|---|---|
| GitHub OIDC プロバイダ | CI からのロール引き受け (INF-I) | アカウントに 1 個 | TF | 前提 |
| IAM ロール (用途別。一覧は §4.5) | 用途別権限。**信頼条件は `environment` で絞る** (モノレポでは `repo:` で分離できない — §4.5) | 環境ごとに別ロール | TF | 前提 |
| Route53 レコード (API のホスト名 / **FE のホスト名**) | v3 API と FE の公開名 (INF-J) | dev / prod で別ホスト名 | TF (**ホストゾーンは参照のみ**) | **前提 (prod は確定)** — `api.hassan.jp` / `app.hassan.jp` (§9.3 の Q-INF-3)。**dev の 2 件は未確定** (同項の派生①) |
| ACM 証明書 | ALB の TLS | 環境ごとに発行 | TF | 前提 |
| tfstate 用 S3 バケット + KMS | state の保管 (INF-A) | 1 バケット・環境ごとにキー分離 | **手動** (§7 の例外 1 件) | 前提 |
| Vercel プロジェクト・環境変数・独自ドメイン | FE のホスティング (C-6)。**staging / prod のみ** (dev = preview の FE は ECS。INF-U) | Preview (staging) / Production。**feature ブランチはビルドしない** (Ignored Build Step) | **外部** (§7) | 前提 |
| GitHub のブランチ保護・environment・承認者 | 人間承認点の機構 (H-1〜H-4) | — | **手動** (§7。[../../templates/shared/.claude/rules/04-human-checkpoints.md](../../templates/shared/.claude/rules/04-human-checkpoints.md) §4 が SSOT) | 前提 |

**一覧の確定を求める `[Answer]:` は §9 に置く。**

---

## 4. Terraform / ecspresso の役割分担 (C-14 の具体化)

> 本節が回答する ID: **D-8** / **D-3** (デプロイ手順の前提となるリソース所有)。

### 4.1 分担の線

```
┌──────────────────────── Terraform (infra リポ) ────────────────────────┐
│ VPC / subnet / SG / NAT / VPC エンドポイント                            │
│ ALB / リスナー / ターゲットグループ / WAF / ACM / Route53 レコード       │
│ ECR / **ECS クラスタ**                                                  │
│ RDS / パラメータグループ / サブネットグループ                            │
│ Secrets Manager の器 / SSM のパス / KMS                                 │
│ IAM (タスク実行ロール・タスクロール・OIDC の 3 ロール)                   │
│ CloudWatch ロググループ・メトリクスフィルタ・アラーム / SNS / Chatbot     │
│ S3 (アセット / ALB ログ)                                                │
└────────────────────────────────┬───────────────────────────────────────┘
                                 │ 出力 (tfstate 経由で参照)
                                 │ クラスタ名 / subnet ID / SG ID / TG ARN /
                                 │ ロール ARN / シークレット ARN / ロググループ名
                                 ▼
┌────────────── ecspresso (app モノレポの backend/) ─────────────────────┐
│ **ECS サービス定義** (desiredCount / ネットワーク / **loadBalancers**)    │
│ **タスク定義** (イメージ / CPU・メモリ / environment / **secrets** /      │
│                logConfiguration / RunTask 用の定義)                      │
│ リリース (deploy) と **rollback**                                        │
└────────────────────────────────────────────────────────────────────────┘
```

**Terraform 側で ECS サービスとタスク定義のリソースを一切定義しない**。
片方だけを IaC にして他方を `ignore_changes` で除外する構成を採らないため、二重管理が発生しない。

### 4.2 tfstate 連携の方向 (一方向)

- ecspresso は **tfstate を読む側**であり、書かない。`ecspresso.yml` の tfstate プラグインで
  S3 上の state を参照し、定義ファイル内でクラスタ名・subnet ID・SG ID・ターゲットグループ ARN・
  シークレット ARN を解決する
- そのため **`deploy` 用 IAM ロールに tfstate バケットの読み取り権限を与える** (書き込みは与えない)
- **infra を apply していない環境へはリリースできない**。これは事故ではなく順序の担保であり、
  リポ間依存 (§6.3) と一致する
- **却下案: 出力値を app モノレポの設定ファイルへ手で書き写す** — infra 側の変更 (subnet の追加・
  ターゲットグループの作り直し) が backend 側に反映されず、`ecspresso deploy` が古い ID を使う。
  v2 で ALB の紐付けが定義から抜けている状態 (F-3) と同種の乖離が再発する

### 4.3 ALB 紐付けの所有者 (v2 の失敗を再発させない)

**ECS サービスの初回作成を `ecspresso deploy` で行い、その時点のサービス定義に
`loadBalancers` (ターゲットグループ ARN) を含める**。

理由: **ECS は稼働中サービスのロードバランサ関連付けを `UpdateService` で変更できない**
(v2 ではこれが原因で ALB 紐付けが ecspresso 管理外に置かれている — F-3 と同書 §3 の分析)。
初回作成時に含めておかないと、後から IaC に取り込むにはサービスの作り直しが必要になる。

- **サービスをコンソールで手作成しない** (v2 の経緯と同じ状態になる)
- ターゲットグループは Terraform が作り、その ARN を ecspresso が tfstate から読む (§4.2)

### 4.4 apply の実行主体と承認

| 操作 | 実行主体 | 機構 |
|---|---|---|
| `terraform fmt` / `validate` / `tflint` / `plan` | **CI** (PR ごと。結果を PR にコメント) | [../../templates/infra-repo/.github/workflows/ci.yml](../../templates/infra-repo/.github/workflows/ci.yml) (apply ジョブを持たない) |
| `terraform apply` (**dev も prod も**) | **人間** | エージェントは `apply` / `destroy` / state 操作を deny ([../../templates/shared/.claude/rules/04-human-checkpoints.md](../../templates/shared/.claude/rules/04-human-checkpoints.md) §3。H-4 の infra 行) |
| `ecspresso deploy` (staging) | **CI** (`main` への push で自動。承認なし) | C-15 の継続デプロイ (INF-U 以前は dev) |
| `ecspresso deploy` / `delete` (dev = preview) | **CI** (`deploy-preview.yml`。PR の `preview` ラベルで自動。承認なし) | INF-U。PR 単位の使い捨て |
| `ecspresso deploy` (prod) | **CI** (手動起動 + `prod` environment 承認) | H-4 |
| `ecspresso rollback` | **人間が CI から起動** — **app モノレポの `rollback-backend.yml` (`workflow_dispatch`)**。起動できるのは `prod*` environment の承認者 (prod は `environment: prod` の承認を通す)。**実行経路と入力の仕様は [operations.md](operations.md) §5.3 が SSOT** (雛形は `templates/app-monorepo/.github/workflows/rollback-backend.yml` に作成済み。2026-07-30) | [architecture.md](architecture.md) D-3 |

**apply の記録**: infra は CI に記録が残らないため、**実行者が PR に適用結果の要約をコメントする**
(同 §5 の H-4 (infra) 行)。**dev の apply も人間が行う**根拠は同 §1.1 の注記
(Terraform の差分は非破壊を機械判定しにくく、`replace` が RDS / ECS の作り直しになる)。

---

### 4.5 OIDC の信頼条件 (`sub` クレーム) — モノレポでは `environment` で分ける

> **2026-08-05 に新設** (design-reviewer 指摘 D-4)。**それまで信頼条件は設計に 1 行も無かった**。

**3 リポ構成では `sub` の `repo:<org>/<repo>` が権限分離になっていた** — backend リポのワークフローは
backend 用ロールしか引き受けられず、frontend リポからは AWS に一切届かなかった。
**モノレポでは backend / frontend / E2E が同一リポジトリなので `repo:` では分離できない**
(`feedback_review_patterns.md` の DR-10: 構造が副産物として担保していたものが消える例)。

**したがって信頼条件は `environment` で分ける**。IAM ロールの信頼ポリシーの `sub` を次で固定する:

| IAM ロール | 許す `sub` | 用途 |
|---|---|---|
| `plan` (read-only) | `repo:<org>/<app-repo>:pull_request` | PR の検査ジョブ。**書き込み権限を持たない** |
| `deploy-staging` | `repo:<org>/<app-repo>:environment:staging` | staging の ECR push + `ecspresso deploy` + Agent 再発行 (**旧 `deploy-dev`**。INF-U) |
| **`deploy-preview`** | **`repo:<org>/<app-repo>:environment:dev-preview`** | **dev (preview) の PR 単位リソースの作成・破棄** (INF-U / X-11): FE・BE の ECR push + `ecspresso deploy/delete` + **dev の ALB に限定した** TG / リスナールールの作成・削除 (`elasticloadbalancing:*` を ALB / リスナー ARN で絞る) + Agent の発行・削除 (`/hassan-v3/dev/pr-<N>/...` の SSM 書込) + マイグレーションの RunTask。**承認者なし。`pull_request` から起動するため Deployment branches を制限しない** |
| `deploy-prod` | `repo:<org>/<app-repo>:environment:prod` | prod の `ecspresso deploy` |
| `agent-prod` | `repo:<org>/<app-repo>:environment:prod-agent` | prod の Agent 再発行 (Secrets Manager 読み取り + SSM 書き込み) |
| `migration-staging` | `repo:<org>/<app-repo>:environment:staging` / `:environment:staging-db-destructive` | staging のマイグレーション (RunTask) |
| `migration-prod` | `repo:<org>/<app-repo>:environment:prod-db` | prod のマイグレーション (RunTask) |
| **`e2e-staging`** | **`repo:<org>/<app-repo>:environment:staging-e2e`** | **E2E の資格情報取得 (Secrets Manager の read のみ)** |
| infra 用 (`plan` / なし) | `repo:<org>/<infra-repo>:pull_request` | infra リポは**別リポなので `repo:` で分離できる**。`apply` は人間が手元で行うため CI 用ロールは `plan` のみ |

**要点 3 つ**:

1. **`environment: staging` を E2E とデプロイで共有しない** — 共有すると `sub` が同一になり、
   **E2E のワークフローが staging のデプロイ用ロール (ECR push / ecspresso) を引き受けられる**。
   **専用 environment `staging-e2e` を作る** (承認者は設定しない = 自動実行のまま)。
   同様に **`dev-preview` を staging 系と共有しない** — preview は feature ブランチの `pull_request` から
   起動するため、共有すると **任意の PR が staging を書き換えられる** (INF-U)。
   これが D-4 の実体である
2. **`ref:` 条件だけに頼らない** — `repo:<org>/<repo>:ref:refs/heads/main` は
   **`workflow_dispatch` を feature ブランチから起動されると通らないが、
   逆に `main` に入った任意のワークフローは通る**。ジョブ単位の分離には `environment` を使う
3. **prod 系ロールには `Deployment branches: main のみ` を併用する**
   ([../../templates/shared/.claude/rules/04-human-checkpoints.md](../../templates/shared/.claude/rules/04-human-checkpoints.md) §4.2)。
   信頼条件 (AWS 側) と environment のブランチ制限 (GitHub 側) の**二重化**にする

> **要確認**: OIDC の信頼条件に `environment:` を使う形が推奨されるか、
> `job_workflow_ref` を併用すべきかは**未検証**。立ち上げ時に AWS / GitHub の最新ドキュメントで確認する
> (推測を事実として書かないため明示する)。

## 5. 環境の構成差 (dev / staging / prod)

> 本節が回答する ID: **D-1** (AWS 側の環境分離。FE との対応は §5.3) / **D-8**。
> **2026-09-07 (INF-U)**: staging を追加し、dev を PR 単位のプレビュー基盤にした。**staging 列の値は従来の dev 列の値**である。

### 5.1 差分の付け方 (規則)

1. **リソース定義は `modules/` に 1 つだけ持ち、差は `envs/<env>` の変数値で表す** (INF-B)。`envs/dev` は **PR 単位のサービスを持たない共有基盤** (クラスタ + ALB + RDS) であり、サービスは `deploy-preview.yml` が作る (INF-U / X-11)
2. **「dev には作らない」要素は、モジュールの `count` / `for_each` を変数で切る** (定義を分岐でコピーしない)
3. **変数のうち「本番の安全性に効くもの」は既定値を prod 側の安全な値にする** —
   `deletion_protection` / `skip_final_snapshot` / WAF のモードは、**変数を書き忘れたときに
   prod が危険側に倒れない向き**に既定値を置く

### 5.2 初期値の表

**値の根拠**: 実測トラフィックが無いため、**INF-E / INF-N を除く数値は暫定値**である。
運用開始後に §10 の手順で改訂する (改訂の SSOT は本表)。

| 項目 | **dev (preview 基盤)** | staging | prod | 根拠・備考 |
|---|---|---|---|---|
| ECS `desiredCount` | **PR ごとに FE 1 / BE 1** (サービスは `deploy-preview.yml` が作る) | 1 | **2** | INF-E。v2 の単一タスク (F-4) を継承しない |
| ECS タスクの CPU / メモリ | FE 256 / 512、BE 512 / 1024 (**Fargate Spot**。INF-U) | 512 / 1024 | **1024 / 2048** | v2 は両環境 512/1024 (同書 §2)。v3 は SSE 接続を保持するため prod のみ引き上げる (暫定) |
| ローリング更新 | min 100% / max 200% | min 100% / max 200% | 同左 | v2 と同じ (同書 §3)。**SSE は更新時に切れる前提** ([design_memo.md](design_memo.md)) |
| デプロイサーキットブレーカー | 有効 + 自動ロールバック | 有効 + 自動ロールバック | 同左 | v2 で既に有効 (同書 §1.4)。**継承する** |
| ターゲットグループの登録解除待ち | 30 秒 | 30 秒 | **60 秒** | 進行中ターンの一部が完了できる猶予。**切断前提の設計は変えない** (FE が再接続する — [API/README.md](API/README.md) J-6) |
| ALB アイドルタイムアウト | 300 秒 | 300 秒 | 300 秒 | INF-C |
| ECS Exec | 有効 | 有効 | **無効** | INF-M |
| 踏み台 (DB への GUI 接続用) | 1 台 (常時 stopped。全 PR のスキーマを同じ RDS で見る) | 1 台 (常時 stopped) | **1 台 (常時 stopped・IAM ロールは dev と別)** | INF-S |
| RDS 構成 | Single-AZ **1 本を全 PR で共有 (スキーマ分離)** | Single-AZ | **Multi-AZ** | prod の可用性 |
| RDS インスタンスクラス | 小 (`db.t4g` 系) | 小 (`db.t4g` 系) | 中 (`db.m7g` 系) | **暫定**。v2 の実クラスは未調査 (F-12)。**この 2 つは RDS for PostgreSQL 前提の値である** — §3.3 の確認で **Aurora PostgreSQL** に決まった場合、`db.t4g`/`db.m7g` ではなく Aurora が対応するクラス (`db.t4g.medium` 以上 / `db.r7g` 系) に置き換わり、**Multi-AZ の表現も「クラスタ + リーダーインスタンス」に変わる** (Single-AZ / Multi-AZ の行も同時に読み替える) |
| RDS バックアップ保持 | 7 日 | 7 日 | **30 日** | §3.3 の確認対象 |
| RDS 削除保護 | 無効 | 無効 | **有効** | §5.1 の規則 3 |
| NAT Gateway | 1 | 1 | **2** | AZ 障害時に prod が全断しない |
| WAF | `count` モード | `count` モード | **block モード** | INF-L |
| ログ保持期間 | 30 日 | 30 日 | **400 日** | INF-N |
| ALB アクセスログ | 無効 | 無効 | **有効** | §3.2 の確認対象 |
| アラート通知 (**通知先に繋ぐ範囲**) | AL-6 のみ (staging と同じ) | AL-6 (タスク異常) のみ | AL-1〜AL-7 全件 (critical / warning の 2 トピックに振り分け) | dev の通知過多を避ける。**この環境差と重大度分類の決定は [operations.md](operations.md) §7.5 が SSOT** (本書はそれを実装する側)。**アラーム自体は両環境で全件作る** (§3.5) |
| **Fargate キャパシティ** | **Spot** | 通常 | 通常 | INF-U。中断されても使い捨て環境なので再起動で足りる |
| **ALB の OIDC 認証** | **FE ホストに付ける (社内限定)** | なし | なし | INF-U。BE ホストはアプリの JWT + WAF |
| **同時プレビュー数の上限** | **10** (超過時は新規構築を失敗させ PR にコメント) | — | — | INF-U。暫定値。リスナールール上限 (100) と RDS 接続数で見直す |

### 5.3 FE (Vercel) と BE (AWS) の環境対応 (D-1)

| 論理環境 | BE | FE | DB | デプロイ契機 | 承認 |
|---|---|---|---|---|---|
| local | 開発者のマシン (docker compose 等) | `next dev` | ローカル PostgreSQL | — | — |
| **dev (preview)** | `envs/dev` のクラスタ上に **PR ごとの ECS サービス** | **ECS** (Next.js standalone。Vercel を使わない) | dev の RDS 1 本を **PR 単位のスキーマ**で分離 | PR の `preview` ラベル ([operations.md](operations.md) §5.1.2) | なし (マイグレーション・Agent 発行も自動。使い捨て) |
| **staging** | `envs/staging` の ECS / RDS | **`main` ブランチの Preview** | staging の RDS | `main` への push | なし (継続デプロイ。非破壊マイグレーションのみ自動) |
| **prod** | `envs/prod` の ECS / RDS | **`production` ブランチ = Production** | prod の RDS | 手動起動 | H-2 / H-3 / H-4 |

- **FE の Production Branch を `main` にしない**のは既定値からの意図的な変更である
  ([../../templates/shared/.claude/rules/04-human-checkpoints.md](../../templates/shared/.claude/rules/04-human-checkpoints.md) §2.4 / §4.4)
- **FE の環境変数 (API のベース URL) が両系統をつなぐ唯一の結び目**である。
  Preview → staging の ALB ホスト名、Production → **`https://api.hassan.jp`** を Vercel 側に設定する。
  **dev (preview) の FE は Vercel ではなく ECS で動くため、同じ変数を ECS タスク定義の `environment` で `https://pr-<N>-api.dev.<domain>` として注入する** (`deploy-preview.yml` が PR 番号から生成)
  (この値の管理は Vercel 側 = §7 の範囲外)。**変数名は段階で変わる** —
  **段階1 は `NEXT_PUBLIC_API_BASE_URL` (ブラウザに露出) / 段階2 は `API_BASE_URL` (サーバ専用)**
  ([frontend.md](frontend.md) §12.2)
- **CORS の許可オリジンは BE 側の設定値**として持つ。**2026-08-29 に FE 側から回答が出た**
  ([frontend.md](frontend.md) §12.3): ①**BE の環境別設定ファイル (`env/<env>.env`) の 1 キー**で持ち、
  Go のソースにハードコードしない (v2 の F-14 を移植しない) ②**Vercel の Preview の
  「デプロイごとに変わる URL」を許可しない** — staging の BE が許可するのは
  **staging の FE の固定ホスト名 1 件 + `http://localhost:3000`** だけ。
  **dev (preview) の BE は `https://pr-<N>.dev.<domain>` の 1 件だけを許可する** — 値は PR ごとに決まるため env ファイルではなく
  **ECS タスク定義の `environment` で `deploy-preview.yml` が上書き注入する** (feature ブランチの Vercel Preview は使わないので「変動する URL」は発生しない)
  ③**`Access-Control-Allow-Credentials` を有効にしない** (段階1 の資格情報はヘッダで送るため)。
  **これは「BE の設定値」であってインフラのリソースではない**ので、本書の管理対象ではない —
  **[operations.md](operations.md) §3.3 の②「非秘密のアプリ由来値」に載る**

---

## 6. 構築順序 (staging 先行。C-15)

> **2026-09-07 (INF-U)**: 本節の「継続デプロイ先」は旧 dev = **staging** である。dev (preview 基盤) の構築は §6.1.1。

> 本節が回答する ID: **AC-3.6** / **D-8** / **D-7** (順序のうちインフラ側)。

### 6.1 staging 環境の構築手順 (旧 dev)

**各段の完了条件を満たすまで次に進まない**。段 0〜2 は infra リポ立ち上げと同時に行う。

| 段 | 内容 | 完了条件 (観測可能な形) |
|---|---|---|
| **0** | §11.1 の `[Answer]:` を解消する。**2026-09-09 に Q-INF-1 / Q-INF-3 派生① を回答し §3 の「要確認」はゼロになった**。残るのは **Q-INF-3 派生② のライブ確認** (`aws route53 list-resource-record-sets` を人間が実行する。設計判断としては完結済み) のみ | §3 の「要確認」がゼロ (**達成**)。派生②のライブ確認は段 5 着手前のチェックリスト項目として残す |
| **1** | **tfstate の置き場を作る** — S3 バケット (バージョニング + SSE-KMS + パブリックブロック) を **CLI で 1 回だけ手作業で作成** (§7 の例外) | `terraform init` が S3 backend で成功する |
| **2** | **OIDC プロバイダ + [§4.5](#45-oidc-の信頼条件-sub-クレーム--モノレポでは-environment-で分ける) の表のロール一式** (INF-I) を apply。**表の行を 1 つでも落とさない** — 落とした分は「その機能を初めて動かしたとき」まで気付けない | ①CI の `plan` ジョブが PR にコメントできる (キーを一切置いていないこと) ②**§4.5 の表の各ロールについて `aws iam get-role` が成功する** (`plan` だけの確認では `staging-e2e` / `prod-agent` / `prod-db` の欠落を見逃す) |
| **3** | **network** — VPC / subnet / SG / NAT / S3 エンドポイント | `plan` の差分ゼロ。private subnet からの外向き通信が確認できる |
| **4** | **RDS + Secrets の器** — RDS を private subnet に作り、DB 接続情報のシークレットを作成 | シークレットに**値を投入済み** (INF-G の手順①)。tfstate に平文が無いこと |
| **5** | **ECR + ECS クラスタ + ALB / TG / ACM / Route53** | ホスト名で ALB に HTTPS 接続でき、TG がまだ unhealthy であること |
| **6** | **CloudWatch (ロググループ / フィルタ / アラーム) + SNS + Chatbot** | **staging のトピック 1 本へのテスト通知が Slack に届く** (prod は 2 トピック + メール購読の到達確認が RL-2 の完了条件 — [operations.md](operations.md) §6.1) |
| **7** | **backend: ecspresso 設定 + 初回 `deploy`** — サービス定義に `loadBalancers` を含める (§4.3) | TG が healthy になり、`/alive` が ALB 経由で 200 |
| **8** | **マイグレーション実行タスク定義 + RunTask で初回適用** (INF-H) | スキーマが適用され、ログが CloudWatch に出る |
| **9** | **Managed Agent と Environment の staging 発行** (**staging は承認不要。prod は H-3**。`deploy-backend.yml` の `apply_agent`) | **Agent ID と Environment ID が SSM に書かれ** ([operations.md](operations.md) §3.3 の⑤)、会話系 API が staging で動く |
| **10** | **frontend: Vercel プロジェクト + 環境変数 + Preview デプロイ** | Preview から staging API を叩けて認証が通る |
| **11** | **staging への継続デプロイ運用開始** (`main` への push で 7〜10 が自動で回る) | 2 回連続で無人デプロイが成功する |

### 6.1.1 dev (preview 基盤) の構築手順 (INF-U)

staging の段 1〜6 と同じ手順を `envs/dev` に対して行い、次を加える。**PR 単位のサービスは作らない** (X-11):

| 段 | 内容 | 完了条件 (観測可能な形) |
|---|---|---|
| **P-1** | ワイルドカード ACM (`*.dev.<domain>`) + Route53 ワイルドカードレコード → ALB。HTTPS リスナーの既定アクションは 404 | 任意の `pr-0.dev.<domain>` が 404 で応答する (証明書エラーが出ない) |
| **P-2** | FE 用 ECR + Fargate Spot キャパシティプロバイダ + OIDC 認証用 IdP クライアントの器 (Secrets Manager) | `aws ecr describe-repositories` で FE / BE の 2 本が見える。シークレットに値が投入済み |
| **P-3** | `deploy-preview` ロール (§4.5) | `aws iam get-role` が成功し、信頼条件が `environment:dev-preview` のみ |
| **P-4** | app リポの `deploy-preview.yml` で **試験 PR に `preview` ラベルを付ける** | FE / BE の URL が PR にコメントされ、OIDC ログイン後に FE が開き、API が応答する。**ラベルを外すとサービス・TG・ルール・スキーマ・Agent が消える** |

### 6.2 prod 環境の構築 (開発完了後。C-15)

**同じ手順を `envs/prod` に対して実行する**。staging と異なるのは次の 3 点のみ:

1. 段 1 (tfstate バケット) は共通のため不要 (キーのみ分離)
2. 段 2 の IAM ロールは prod 用を追加で作成し、**信頼条件は §4.5 の表のとおり prod 系 environment
   (`prod` / `prod-db` / `prod-agent`) の `sub` に固定する**。**`ref:refs/heads/main` で絞る形にしない** —
   `main` に入った任意のワークフローが通ってしまうため (§4.5 要点 2)。
   ブランチの限定は GitHub 側の environment の **Deployment branches** で行い、
   AWS 側の `sub` 固定と**二重化**する (§4.5 要点 3)
3. 段 7〜9 は **`workflow_dispatch` + environment 承認**を通る (H-2 / H-3 / H-4)

**全面切替 (C-11 / AC-3.5) の DNS 手順は §9.2** (データ移行そのものは Q-1 の回答待ちで本書の対象外)。

### 6.3 リポジトリ間の依存

[../../templates/README.md](../../templates/README.md) の「リポジトリ間の依存 (立ち上げ順序)」と一致させる:

```
infra リポ (Terraform)
   ↓ 出力: RDS エンドポイント (シークレット経由) / ECS クラスタ名 / subnet・SG ID /
   ↓        ターゲットグループ ARN / シークレット・SSM の ARN / ロググループ名
app モノレポ
   backend/ (ecspresso で ECS へ) → api/openapi.yaml → frontend/ (型生成 / Vercel)
   ※ BE→FE の契約はリポ内に閉じ、CI の contract ジョブ (MR-3) が同期を機械検証する
```

- **infra の PR はマージだけでは効かない。`apply` 済みであることが app の着手条件**
  ([../../templates/shared/.claude/rules/02-issue-granularity.md](../../templates/shared/.claude/rules/02-issue-granularity.md) §2.2 の「infra の出力値を backend が使う」行)
- **並列可能**: 段 3 (network) の完了後、段 4 (RDS) と段 5 (ECR / ALB) と段 6 (CloudWatch) は並列に進められる
- **直列必須**: 段 1 → 2 → 3、および段 7 → 8 → 9 (§4.3 の初回作成順序と H-2 / H-3 の適用順序)

---

## 7. IaC の範囲外とするもの (理由付き)

> 本節が回答する ID: **D-8** (範囲外の明示)。
> **範囲外にした理由をコードのコメントにも残す** ([../../templates/infra-repo/CLAUDE.md.tmpl](../../templates/infra-repo/CLAUDE.md.tmpl) の「設計との対応」)。
> 「漏れ」と「意図した除外」を後から区別できるようにするため。

| # | 対象 | 範囲外にする理由 | 誰がどう管理するか |
|---|---|---|---|
| X-1 | **tfstate 用の S3 バケット + KMS キー** | state を管理する state という入れ子を作らないため。**除外は 1 段だけに限定する** | 構築時に CLI で 1 回作成し、作成コマンドを infra リポの README に残す |
| X-2 | **シークレットの値** (DB パスワード・API キー・JWT 署名鍵) | Terraform で管理すると **tfstate に平文で残る** (INF-G)。器 (名前・KMS・IAM) は Terraform 管理 | 人が 1 回投入 / CI が書く (Agent ID)。**値のリストは Secrets Manager が唯一の所在** |
| X-3 | **ECS サービス定義・タスク定義** | ecspresso が管理する (C-14)。二重管理を作らない (§4.1) | app モノレポの `backend/stacks/<env>/` |
| X-4 | **Anthropic の Managed Agent リソースと Environment** (Agent ID / **Environment ID** / prompt / tool schema) | AWS リソースではない。発行・作成はデプロイ手順の一部 (D-6)。**Environment は dev / prod で分ける (2026-07-30 確定)** — 複数作成できることを一次ソースで確認済み ([operations.md](operations.md) §5.2 の `[Answer]`)。**同節の含意 2・4 が本書に及ぶ**: ①**Environment は不変として扱い、設定変更は新規作成 + ID 差し替えで行う** (Anthropic 側に設定の版履歴が無い) ②**prod の Environment は `networking.type = limited` を既定とし `allowed_hosts` を明示列挙する** — 外部検索 (Exa) 等をサンドボックスから直接叩く経路があれば本書の egress 設計と対を取る | app モノレポの `deploy-backend.yml` の `apply_agent` (H-3)。**ID の保管先 (SSM のパスと版履歴) だけは Terraform が器として管理する** (§3.4 / INF-G) |
| X-5 | **Vercel の設定** (Production Branch・環境変数・独自ドメイン) | AWS 外。**H-4 の承認機構が Vercel 側の Promote 権限とブランチ保護で担保されており**、Terraform provider で二重管理すると承認の所在が分かれる | 人手チェックリスト ([../../templates/shared/.claude/rules/04-human-checkpoints.md](../../templates/shared/.claude/rules/04-human-checkpoints.md) §4.4) |
| X-6 | **GitHub の設定** (ブランチ保護・environment・承認者・ラベル) | **承認者設定を IaC 化すると、承認機構そのものをコードの変更で外せる** (自己参照的な穴になる)。承認は人がリポジトリ設定として持つべきもの | 同 §4.1〜§4.3 の人手チェックリスト |
| X-7 | **Slack ワークスペース側の Chatbot 連携承認** | OAuth の承認操作であり、コードで表現できない | 構築時に人が 1 回実施 (AWS 側の Chatbot 設定は Terraform 管理) |
| X-8 | **v2 の稼働中リソース** (VPC / ALB / RDS / ECS / S3) | C-14 により import しない。全面切替で廃止予定 (C-11) | v2 のまま (コンソール手作業)。**v3 から参照しない** |
| X-9 | **既存の Route53 ホストゾーン** | v2 の名前解決に影響するため作り直さない (INF-O)。**レコードのみ Terraform 管理** | data source で参照 |
| **X-11** | **dev (preview) の PR 単位リソース** (ECS サービス・タスク定義・TG・ALB リスナールール・DB スキーマ・Managed Agent) | 個数が PR 数に応じて動的に変わり、Terraform state に載せると `plan` の差分が読めなくなる (INF-U の却下案 b) | app リポの `deploy-preview.yml` が作成・破棄する。放置分は日次の掃除ジョブが削除 ([operations.md](operations.md) §5.1.2) |
| X-10 | ~~**踏み台サーバー**~~ (2026-08-07 撤回。Q-INF-5) | ~~v3 では作らない (INF-M)。RunTask と ECS Exec で用途を満たす~~ → **RunTask (INF-H) はスキーマ適用を、ECS Exec (INF-M) はコンテナ内調査を満たすが、人間が GUI で DB を見る用途は満たさない。踏み台を INF-S として作る**ことにした | 該当なし (X から除外) |

---

## 8. 本番観点への回答

### 8.1 本書が回答する ID

| ID | 状態 | 回答 |
|---|---|---|
| **D-8 IaC の管理範囲** | **回答** | §4 (分担・tfstate 連携・apply 主体) / §3 (要素ごとの管理主体) / §7 (範囲外と理由)。tfstate は S3 + ロック (INF-A)、apply は**人間** (§4.4)、v2 の import はしない (INF-O)。**アプリへ値を渡す出力の管理も範囲に含む** — 信頼プロキシ CIDR を Terraform の `output` として公開する (INF-P。手写しは §4.2 で却下済み) |
| **AC-3.6** | **回答 (一覧は確認待ち)** | §3 に VPC / ALB / ECS / RDS / Secrets / ログ・監視 / OIDC / S3 / WAF / Vercel を洗い出し、管理主体と範囲外理由を付けた。**一覧の最終確定は §11.1 の `[Answer]:`** — 未確認の要素を確定として扱わない |
| **D-1 環境** | **部分 (インフラ側は回答)** | §5.2 の環境差表と §5.3 の FE / BE 対応表 (**prod のホスト名は `app.hassan.jp` / `api.hassan.jp` = INF-J**。dev は Q-INF-3 派生①)。環境ごとの値は `envs/<env>` の変数 (INF-B)、秘密は Secrets Manager の器 + 値の分離 (INF-G)。**アプリ内の設定値の持ち方は [architecture.md](architecture.md) §3.9② が SSOT**。**環境で値が変わるインフラ由来の非秘密値の実例として信頼プロキシ CIDR を追加した** (INF-P。分類は [operations.md](operations.md) §3.3 の②) |
| **D-3 デプロイ手順** | **部分 (リソース前提を回答)** | §4.3 (初回作成で ALB 紐付けを含める) / §4.4 (実行主体) / §5.2 (サーキットブレーカーと登録解除待ち)。**手順そのものは [../../templates/app-monorepo/.github/workflows/deploy-backend.yml](../../templates/app-monorepo/.github/workflows/deploy-backend.yml) と [architecture.md](architecture.md) D-3 が SSOT** |
| **D-5 シークレット管理** | **回答 (具体化)** | INF-G。**器 = Terraform / 値 = Terraform 管理外**。秘密は Secrets Manager、非秘密の環境依存値は SSM。方式の SSOT は [architecture.md](architecture.md) D-5、鍵の扱いは [auth.md](auth.md) §6.8 |
| **O-1 構造化ログ** | **回答 (受け皿のみ)** | §3.5 / INF-N。ロググループを Terraform で明示作成し保持期間を設定する (**v2 の暗黙作成 F-9 を継承しない**)。ログの内容・必須フィールドは [observability.md](observability.md) §4.1 |
| **O-5 SSE / 長時間処理** | **回答 (インフラ側)** | INF-C (アイドルタイムアウト 300 秒) / §5.2 (登録解除待ち)。**切断の検知と再接続の仕様は [observability.md](observability.md) §4.3 F-5 / [API/README.md](API/README.md) J-6** |
| **O-7 アラート** | **回答 (受け皿のみ)** | §3.5 / INF-K。CloudWatch アラーム → SNS (**prod 2 本 / dev 1 本**) → Chatbot (Slack) + **prod critical はメール購読も併設**。**しきい値の SSOT は [observability.md](observability.md) §4.6 / 重大度分類・環境差・トピック本数の SSOT は [operations.md](operations.md) §7.5** (本書はどちらも参照する側) |
| (関連) **O-3** | **参照 + 補足** | LLM コストの上限は設けない (C-12)。**AWS 利用料そのものの監視 (AWS Budgets) は §3.5 の確認対象**として別に提案する (LLM 費用は AWS 課金ではないため同じ仕組みで見えない) |
| (関連) **API-Q1** | **回答** | INF-J。**v2 とは別ホスト名 (別 ALB)** を採る。[API/README.md](API/README.md) の「別ドメイン前提・パスプレフィックス無し」という API 設計の前提が成立する |
| (関連) **auth.md の WAF 要否** | **回答** | INF-L。**prod = block / dev = count**。アプリ層のレート制限は置き換えない ([auth.md](auth.md) §6.11-3)。**Geo Match (JP のみ許可) を v2 から引き継ぐ** — **[frontend.md](frontend.md) の段階1 (ブラウザ直叩き) と対で成立する**判断であり、**段階2 へ移る増分で再設計が要る** |

### 8.2 本書では対象外とする ID (理由と先送り先)

| ID | 対象外の理由 | 先送り先 / SSOT |
|---|---|---|
| A-1〜A-7 | 認証・テナント境界はアプリ層の設計であり、インフラ構成では表現しない (**A-4 の所有者絞り込みを Postgres RLS で担保する案は既に却下されている** — [design_memo.md](design_memo.md) の「テナント境界」) | [auth.md](auth.md) |
| O-2 / O-4 / O-6 | LLM 計測・失敗の分類・監査ログはアプリ層の実装。インフラは §3.5 の受け皿を用意するのみ | [observability.md](observability.md) |
| D-2 CI ゲート | infra リポの CI ゲートは [../../templates/infra-repo/.github/workflows/ci.yml](../../templates/infra-repo/.github/workflows/ci.yml) (fmt / validate / tflint / plan) と [../../templates/shared/.claude/rules/01-construction-loop.md](../../templates/shared/.claude/rules/01-construction-loop.md) §1.3 が定める。本書で重複定義しない | 同ファイル群 / [architecture.md](architecture.md) D-2 |
| D-4 マイグレーション | **実行経路 (ネットワーク到達性) は INF-H で回答**。**方式は psqldef で確定** (2026-07-31。SSOT は [data-model.md](data-model.md) §6.1)。適用タイミング・承認は [operations.md](operations.md) §7.4 | [architecture.md](architecture.md) D-4 / [../../templates/shared/.claude/rules/04-human-checkpoints.md](../../templates/shared/.claude/rules/04-human-checkpoints.md) §2.2 |
| D-6 Agent ライフサイクル | Agent / Environment は AWS リソースではない。**インフラ側の関与は「Agent ID と Environment ID を SSM に版付きで置く」ことのみ** (INF-G / §3.4 / X-4) | [architecture.md](architecture.md) D-6 / [operations.md](operations.md) §5.2 (発行・再発行トリガ・Environment の分離) / `deploy-backend.yml` の `apply_agent` |
| D-7 段階リリース | **構築順序 (§6) とリソース面の切替手段 (§9.2) は回答**。機能単位の切替順序・v2 併用期間の運用は対象外 | [architecture.md](architecture.md) D-7 / 移行計画 |

---

## 9. 移行と運用

### 9.1 既存 v2 との共存 (D-3 / D-7 / DR-3)

- **v3 は v2 の稼働中リソースに一切触らない** (X-8)。v3 の VPC・RDS・ALB・S3 はすべて新規
- 共有するのは **Route53 のホストゾーン (レコード追加のみ)** に限る (X-9)。
  v2 のレコードを変更・削除しない
- **v2 の DB データの移行そのものは本書の対象外** (Q-1 の回答待ち)。
  インフラ側で必要になる手段は「v2 RDS から v3 RDS への一方向のデータ転送経路」であり、
  経路の候補 (RunTask から両 DB に接続 / スナップショット復元 + 変換) は Q-1 確定後に本書へ追記する
- **v2 廃止時のリソース削除順序**: Route53 レコード → ECS サービス → ALB → RDS (最終スナップショット取得後) →
  S3 (データ移行完了の確認後)。**RDS と S3 は最後**に残す (復旧可能性を最後まで保つ)

### 9.2 全面切替のリソース面の手順 (AC-3.5 のインフラ側)

**前提 (2026-09-09 に是正。F-13 の実測を反映)**: ~~v2 の API 公開エンドポイントは ALB の生 DNS 名であり (F-11)、
API 用の Route53 レコードが存在しない~~ — **これは誤りだった** (F-11 は dev 環境の README 由来の記述を
prod にも一般化した推測。F-13: **v2 prod は `api.hassan.jp` の Route53 レコードで公開されている**)。
**API 側にも DNS レバーがある**。v3 は最初から別ホスト名 `api.hassan.jp` を使う設計 (INF-J) だが、
**この名前は v2 prod が既に使っているため、全面切替時に v2 → v3 へレコードを付け替える必要がある**
(Q-INF-3 の追記・案 B)。**切替・切り戻しのレバーは FE の公開ドメインと API (`api.hassan.jp`) の
2 レコード (と Vercel の Promote)** になる。

**公開方式は 2 ケースあり、どちらを採るかは未確定**。
**2026-08-29 に Q-INF-3 が回答され、v3 のホスト名は `app.hassan.jp` (FE) / `api.hassan.jp` (BE) に確定した**
が、**それは「v3 を別ホスト名で立てる」ことの確定であって、切替の方式 (A / B) の確定ではない**。
**A / B を分けるのは「エンドユーザーに案内する URL を最終的にどれにするか」**である:

| | ケース A | ケース B |
|---|---|---|
| 最終的に案内する URL | **v2 が今使っている FE の公開ドメイン** (`hassan.jp`。**2026-09-07 に実測確認済み** — `hassan-terraform` の `route53_records_app.tf` に `hassan.jp` A → Vercel の記録がある。F-13 と同じ実測) を v3 の Vercel へ向け替える | **`app.hassan.jp` のまま**案内する |
| DNS 操作 | **あり** (FE のレコードのみ。切替時と切り戻し時) | **なし** |
| 未確定の理由 | **v2 の FE がどのレコードで公開されているかが未確認**である (§11.3)。**確認できれば A を選べる** | — |

(運用側の SSOT は [operations.md](operations.md) §6.3 の ⑥):

| # | 手順 | ケース A (既存の公開ドメインを v3 へ付け替える) | ケース B (v3 を別 URL で公開する) |
|---|---|---|---|
| 1 | **切替前** | v3 の prod を §6.2 で構築し、**v3 のホスト名**で FE の Production を動作確認する (この時点で v2 は無変更のまま稼働) | 同左 |
| 2 | **TTL の短縮** | **FE と API 両方の公開ドメインレコード**の TTL を 60 秒に下げ、旧 TTL の期間だけ待つ (**2026-09-09 追記: `api.hassan.jp` も対象に追加** = F-13 / Q-INF-3 案 B) | **API のみ** TTL を下げる (FE は既に `app.hassan.jp` で運用中のため対象外) |
| 3 | **切替** | **FE の公開ドメインを v3 の Vercel Production へ向け、`api.hassan.jp` の A (alias) を v2 の ALB → v3 の ALB へ付け替える** (2026-09-09 追記。**この 2 レコードは同時に切り替える** — 片方だけ先行すると FE/BE の対向がずれる) | **`api.hassan.jp` を v2 の ALB → v3 の ALB へ付け替える**。**v3 の URL (`app.hassan.jp`) をユーザーへ案内する**。既存 FE ドメイン (`hassan.jp`) は v2 のまま |
| 4 | **切り戻し (ロールバック)** | **FE と API 両方の公開ドメインレコードを旧レコード (v2) へ戻す** (TTL 60 秒のまま作業する)。v2 側は無変更のため再構築は不要 | **`api.hassan.jp` を v2 の ALB へ戻す**。**v3 FE の Production を利用停止の案内表示に Promote し、v2 の URL を案内する** |
| 5 | **期間** | **切り戻し可能期間は v3 公開後 7 日**。**この定義と根拠は [operations.md](operations.md) §6.4 が SSOT** (Q-1 のデータ移行方式の確定に依存しない) | 同左 |
| 6 | **v2 の停止** | 上記 7 日の経過後、§9.1 の順序で削除する | 同左 |

**切替後に v3 へ書き込まれたデータは v2 に存在しない**ため、切り戻しは「v3 のデータを残したまま
ユーザーを v2 に戻す」操作になる (手順と判断基準は [operations.md](operations.md) §6.4)。
**TTL 期間中に両系へ書き込みが分散する問題**はケース A 固有で、対策は同 §6.3 が決める。

### 9.3 継続運用

| 項目 | 手順 |
|---|---|
| **暫定値の改訂** | §5.2 の「暫定」と書かれた値 (タスクサイズ・RDS クラス・登録解除待ち) は、**運用開始から 1〜2 週間の実測で見直す**。改訂は §5.2 の表を更新する PR として行う |
| **`plan` の差分レビュー** | `destroy` / `replace` が 1 件でも出たら、理由を PR にコメントするまで apply しない ([../../templates/infra-repo/CLAUDE.md.tmpl](../../templates/infra-repo/CLAUDE.md.tmpl) の絶対ルール 2) |
| **RDS の作り直しを伴う変更** | 承認前に**手動スナップショットを取得**し、承認コメントにスナップショット ID を書く ([../../templates/shared/.claude/rules/04-human-checkpoints.md](../../templates/shared/.claude/rules/04-human-checkpoints.md) §2.2 と同じ規約をインフラ変更にも適用する) |
| **KMS キーの削除** | Terraform でキーを消す変更は、**暗号化済みデータの復号不能**を意味する。`prevent_destroy` を付ける |
| **コスト** | AWS 利用料は AWS Budgets (§3.5)、LLM コストは [observability.md](observability.md) AL-4 の二系統で見る。**片方だけでは総額が見えない** |

---

## 10. 実装リポへの引き渡し

### 10.1 infra リポのモジュール構成 (提案)

| モジュール | 含むもの | 依存する出力 |
|---|---|---|
| `modules/network` | VPC / subnet / SG / NAT / VPC エンドポイント | — |
| `modules/iam-oidc` | OIDC プロバイダ / CI 用ロール (一覧と信頼条件は §4.5) | — |
| `modules/alb` | ALB / リスナー / TG / ACM / Route53 レコード / WAF / アクセスログ用 S3 | network |
| `modules/ecs-cluster` | ECS クラスタ / ECR / タスク実行ロール / タスクロール | network |
| `modules/rds` | RDS / パラメータグループ / サブネットグループ / 接続情報シークレットの器 | network |
| `modules/storage` | アセット用 S3 (非公開 + CORS + ライフサイクル) | — |
| `modules/observability` | ロググループ / メトリクスフィルタ / アラーム / SNS / Chatbot / ダッシュボード / Budgets | ecs-cluster, alb, rds |
| `envs/dev` · `envs/prod` | 上記の呼び出しと変数値のみ (リソース定義を書かない) | 全モジュール |

### 10.2 依存順序と並列可能タスク

- **直列**: `network` → (`alb` / `ecs-cluster` / `rds`) → `observability`
- **並列可能**: `iam-oidc` と `storage` は `network` に依存しないため最初から着手できる。
  `alb` / `ecs-cluster` / `rds` は `network` の完了後に並列
- **backend 側の着手条件**: `ecs-cluster` と `alb` と `rds` が **apply 済み** (§6.3)

### 10.3 参照すべき既存実装 (v2)

| 目的 | 参照先 | 踏襲するか |
|---|---|---|
| ecspresso の設定形式 | `hassan-v2-backend/stacks/prod/ecspresso.yml` / `hassan-v2-backend/stacks/dev/ecspresso.yml` | **形式は踏襲**。tfstate プラグインの参照を追加する (§4.2) |
| サービス定義 | `hassan-v2-backend/stacks/prod/ecs-service-def.json` | **`desiredCount` と `assignPublicIp` は踏襲しない** (INF-E / INF-F)。**`loadBalancers` を追加する** (§4.3)。サーキットブレーカーは踏襲 |
| タスク定義 | `hassan-v2-backend/stacks/prod/ecs-task-def.json` | **`secrets` を使う形に変える** (F-6 を継承しない)。`logConfiguration` は `awslogs-create-group` を外す (INF-N) |
| デプロイ手順 | `hassan-v2-backend/.github/workflows/dev-deploy.yml` / `prod-deploy.yml` | **イメージタグのリポジトリ commit は廃止** (C-14)。認証は OIDC へ (INF-I)。雛形は [../../templates/app-monorepo/.github/workflows/deploy-backend.yml](../../templates/app-monorepo/.github/workflows/deploy-backend.yml) |
| Dockerfile とビルドコンテキスト | `hassan-v2-backend/stacks/ecs.Dockerfile` | **秘密の焼き込み (F-6) を踏襲しない** — `.dockerignore` で `.env*` / `*.pem` を除外する。**非秘密のアプリ由来値 `env/<env>.env` は意図的にイメージへ同梱する** ([operations.md](operations.md) §3.3 の②。キー集合は CI が `config` の②定義と照合する) |
| S3 クライアントの構成 | `hassan-v2-backend/aws/s3.go` | **`ACL: ObjectCannedACLPublicRead` と恒久 URL を流用しない** ([API/README.md](API/README.md) D-API-14')。バケットは非公開 |
| 手動 DB 適用手順 (置き換え対象) | `hassan-v2-backend/README.md:74` (踏み台 SSH + `psqldef`) | **踏襲しない** (INF-H の RunTask に置き換える) |
| infra リポの雛形 | [../../templates/infra-repo/CLAUDE.md.tmpl](../../templates/infra-repo/CLAUDE.md.tmpl) / [../../templates/infra-repo/.github/workflows/ci.yml](../../templates/infra-repo/.github/workflows/ci.yml) | そのまま使う (`<...>` を本書 §10.1 の構成で埋める) |

---

## 11. 残課題 / 要確認

### 11.1 ユーザー確認 (回答されるまで確定しない)

**Q-INF-1. §3 のインフラ構成要素一覧を、これで確定してよいか** (design_memo の
「その他インフラ何が必要か一覧化して確認する」に対応)。特に「要確認」の付いた 12 行
(NAT の個数 / Interface エンドポイント / ALB アクセスログ / ECR の分割 / **WAF の要否** /
RDS の種別・バックアップ日数・パラメータ / S3 の CORS とライフサイクル / **Slack 通知** /
ダッシュボード / **AWS Budgets**) の要否。

[Answer]: **確定 (2026-09-09 ユーザー回答)**。12 行それぞれの決定は §3 の各行に **前提** として記載した
(B-1〜B-14。要旨: NAT は dev/staging 1・prod 2 / Interface エンドポイントは初期導入しない /
ALB アクセスログは prod のみ / ECR は環境ごとに分割 / WAF はマネージドルール + レートベース + Geo Match block /
RDS は Aurora PostgreSQL Provisioned / バックアップは prod 30 日 / スロークエリログは全環境 1000ms /
S3 は不完全マルチパート 7 日削除・世代管理なし / Slack 通知は使う / ダッシュボードは prod のみ最低限 /
AWS Budgets は prod に予算アラート・金額は構築時に変数投入 / GuardDuty 等は今回導入しない)。
併せて **S3 Gateway エンドポイントのポリシー**と **VPC Flow Logs** (issue #17 の確認事項 2 点) も
本回答で決定した (D-1 / D-2。§3.1 に前提として追加)。

**Q-INF-2. AWS アカウント構成**: v3 を **v2 と同一の AWS アカウント**に新規リソースとして作るか、
**別アカウント**にするか。dev / prod をアカウントで分けるか。
(本書は「同一アカウント・同一リージョン `ap-northeast-1` (F-8)・環境は VPC と tfstate キーで分離」を
**仮定**して書いた。別アカウントになる場合、§4.2 の tfstate 参照と INF-I の IAM 信頼条件、
§6.1 の段 1〜2 が変わる)

[Answer]: **同一アカウント (仮定どおり) で確定** (2026-07-31 ユーザー回答)。
v2 と同一の AWS アカウント・`ap-northeast-1`。dev / prod は VPC + tfstate キーで分離

**Q-INF-3. v3 で使用するドメイン名** (API 用 / FE 用、dev と prod の各 2 件) と、
**既存の Route53 ホストゾーンがどの AWS アカウントにあるか**。
(本書は INF-J で「v2 とは別ホスト名・既存ホストゾーンを参照のみ」を採用した。
v2 は ALB の生 DNS 名を使っている (F-11) ため、v3 で独自ドメインを使うなら新規発行が必要)

[Answer]: **prod の 2 件を確定 (2026-08-29 ユーザー回答)** —
**FE = `app.hassan.jp` (Vercel) / BE = `api.hassan.jp` (ALB)**。
**`hassan.jp` は v2 と同一ドメインで取得済みであり、新規のホストゾーン作成は不要** (INF-O / X-9 と整合)。
**FE と BE を同一親ドメイン配下に置くのは [frontend.md](frontend.md) §12.1 の要求** —
同書の段階2 (HttpOnly Cookie 化) で `Domain=hassan.jp` の Cookie を共有できるようにし、
**移行時にドメイン変更を伴わせない**ため。**dev の 2 件と既存レコードとの衝突確認は下記の派生①②で残す**。

**追記 (2026-09-09。issue #5 の実測 F-13 を受けて)**: **`api.hassan.jp` は v2 prod の ALB が既に使用中**であることが判明した
(F-13。想定していた「API 側に切替レバーが無い」という §9.2 の前提が誤りだった)。この衝突への対応を確定する:

| 案 | 内容 | 影響 |
|---|---|---|
| A | prod BE を別名にする (`api-v3.hassan.jp` 等) | FE の CORS 許可オリジン・Vercel 環境変数・§5.3 の対応表を変更する必要がある |
| **B (採用)** | **`api.hassan.jp` を維持し、全面切替時に v2 の A (alias) レコードを v3 の ALB へ付け替える** | INF-J の判断 (ホスト名そのもの) は変わらない。**§9.2 の切替手順に「API 側にも DNS レバーがある」ことを反映する必要がある** (下記) |

**2026-09-09 ユーザー回答: 案 B を採用**。段 5 (ALB / ACM / Route53) の staging 構築では `api-staging.hassan.jp` 等の別名で検証し、
`api.hassan.jp` の付け替えは全面切替 (§9.2) のときに一度だけ行う。§9.2 を本回答に合わせて改訂した。

**Q-INF-3 派生①: staging (旧 dev) 環境のホスト名 2 件** (FE / BE)。
**`dev.hassan.jp` は v2 の dev FE が使っている**ため使えない
(`hassan-v2-backend/internal/corsutil/origin.go:14` の許可オリジンに存在する。
**ただしこれは CORS の許可リストであって Route53 のレコードではない** — 実レコードの確認は派生②)。

[Answer]: **`app-staging.hassan.jp` / `api-staging.hassan.jp` で確定** (2026-09-09 ユーザー回答)。
**当初の暫定既定は `app-dev.hassan.jp` / `api-dev.hassan.jp` だったが、INF-U で dev の意味が変わったため、
staging と分かる名前に改める** (2025-11 時点の衝突確認 = 派生② では `app-dev` / `api-dev` は空きだったが、
`app-staging` / `api-staging` は未確認の新しい名前のため、**着手前 (段 5) に改めて衝突確認を行う** — 派生②参照)。
dev (preview) 用の **`*.dev.hassan.jp` のワイルドカード** (FE `pr-<N>.dev.` / BE `pr-<N>-api.dev.`) は
Q-INF-6 (INF-U) のとおり据え置く — v2 の `dev.hassan.jp` は**完全一致のレコード**であり、
`*.dev.hassan.jp` の**ワイルドカード**とは階層が同じでも一致条件が異なるため**共存できる**
(DNS はより詳細な完全一致を優先する。ワイルドカードは他に一致するレコードが無いときだけ使われる)。
**決まったもの**: BE の CORS 許可オリジン設定 ([frontend.md](frontend.md) §12.3 の決定 2) と
ACM 証明書の SAN、Vercel の独自ドメイン設定に使う。

**Q-INF-3 派生②: 既存の Route53 レコードとの衝突確認** (**v2 Terraform の実測で部分的に判明。ライブ確認は未実施**)。

**2026-09-07 の実測 (issue #5。v2 Terraform `hassan-terraform` の 2025-11-08 スナップショット)**:

| ホスト名 | 状態 | 備考 |
|---|---|---|
| `api.hassan.jp` | **衝突 (v2 prod の ALB が使用中)** | 上記 Q-INF-3 の追記のとおり案 B (全面切替時に付け替え) で対応 |
| `app.hassan.jp` / `app-dev.hassan.jp` / `api-dev.hassan.jp` | 2025-11 時点では空き | ただしスナップショット時点の情報であり、ライブ確認ではない |
| `app-staging.hassan.jp` / `api-staging.hassan.jp` (2026-09-09 に新規決定) | **未確認** | 上記 2025-11 スナップショットの調査対象に含まれていない新しい名前 |

**本リポジトリから実行できないため、次の 1 手は人間が行う**:
`aws route53 list-resource-record-sets --hosted-zone-id <id>` で `app` / `api` / `app-dev` / `api-dev` /
`app-staging` / `api-staging` の現物を確認する。**§6.1 の段 5 (ALB / ACM / Route53) の着手前に実施する**
(staging の段 5 着手前後どちらでもよいが、`api.hassan.jp` の付け替えは全面切替の直前に確認し直す)。

[Answer]: 方針は確定 (上記 2 表)。**ライブでの衝突確認は運用手順として残る** (段 5 着手前のチェックリスト項目。
設計判断としてはここまでで完結する — 確認の結果ホスト名を変える必要が生じても INF-J の判断構造は変わらない)。

**Q-INF-4. dev 環境のコストと可用性のバランス**: §5.2 の dev 側の値 (Single-AZ / NAT 1 個 /
タスク 1 本 / ログ 30 日) でよいか。dev は開発期間中フル稼働する (C-15) ため、
**夜間・週末の停止 (RDS の停止 / タスク数 0) を運用に入れるか**。

[Answer]: **提案値を採用し、夜間・週末の停止は入れない** (2026-07-31 ユーザー回答)。
nightly E2E ([testing.md](testing.md) §7.4) との干渉が無く運用が単純。コストが問題化したら後から導入を検討する

**Q-INF-6. 環境構成の改訂 — staging の追加と、dev をブランチ単位のプレビュー環境にする** (2026-09-07 追加)。
検証環境を「`main` の継続デプロイ先 1 つ」ではなく、**開発ブランチごとに FE / BE を ECS で起こして URL を発行する**形にできるか。

[Answer]: **できる。次のとおり確定** (2026-09-07 ユーザー回答。採用案と却下案は §2 の INF-U):

1. **4 環境**: local / **dev = PR 単位のプレビュー (FE も ECS)** / **staging = 従来の dev** (FE = Vercel Preview、BE = `envs/staging`) / prod
2. **契機はラベル**: PR に `preview` ラベルを付けると構築、外す・close で破棄、付いた状態で push すると再デプロイ (§5.3 / [operations.md](operations.md) §5.1.2)
3. **DB は RDS 1 本を PR 単位のスキーマで分離** (`br_pr_<N>`。`CREATE DATABASE` ではない)。マイグレーションは承認なしで自動
4. **Managed Agent は PR 単位で発行** (dev 共有 1 本ではない) — prompt / tool schema を変える PR を検証するため
5. **アクセス制限は ALB の OIDC 認証** (IP 許可リストではない)。IdP は Google Workspace を暫定既定
6. **feature ブランチの Vercel Preview は使わない** (Ignored Build Step で `main` / `production` 以外をビルドしない)
7. **preview のみ Fargate Spot** (コスト削減)。同時数の上限は **10** (暫定値。超過時は新規構築を失敗させ PR にコメント)

**ホスト名への影響**: staging の 2 件と preview のワイルドカード (`*.dev.<domain>`) は **Q-INF-3 派生①に統合する**
(派生①の暫定既定 `app-dev.` / `api-dev.` は staging 用の候補として読み替える。`*.dev.hassan.jp` は v2 の `dev.hassan.jp` (A レコード) と
名前空間が重なるため、派生②の衝突確認の対象に加える)。

### 11.2 他の設計判断の確定待ち (本書がブロックされている項目)

| 項目 | 待っているもの | 決まると本書のどこが変わるか |
|---|---|---|
| マイグレーションの方式 | [architecture.md](architecture.md) D-4 (psqldef / golang-migrate) | INF-H の RunTask が実行するコマンド。**経路 (RunTask) は方式に依存しない** |
| データ移行の方式 | Q-1 (データ引き継ぎの要否) | §9.1 の転送経路のみ。**§9.2 の切り戻し可能期間は Q-1 に依存せず確定済み** (公開後 7 日。[operations.md](operations.md) §6.4 が SSOT) |
| 公開方式 (ケース A / B) | **v2 の FE がどの Route53 レコードで公開されているかの確認** (§11.3。**v3 のホスト名は Q-INF-3 で確定済み**) | §9.2 の手順 2〜4 (ケース A のみ DNS 操作がある) |
| ~~Vercel の Preview URL の扱い~~ | **回答済み (2026-08-29)** — [frontend.md](frontend.md) §12.3 の決定 2 | §5.3 の CORS 許可オリジン: **可変 URL を許可せず、dev の固定ホスト名 1 件 + `localhost:3000` に限る**。**Preview から BE を叩く必要が生じたら Vercel の branch alias を 1 件足す** |
| dev のホスト名 | §11.1 の Q-INF-3 派生① | §5.3 の対応表・ACM の SAN・BE の CORS 許可オリジン |

### 11.3 未調査の事実 (推測で埋めていない項目)

- ~~v2 の RDS のエンジン種別・バージョン・インスタンスクラス・Multi-AZ の有無~~ — **解消 (2026-09-09)**。
  v3 の RDS 種別は v2 の実態を待たずに **Aurora PostgreSQL (Provisioned) に確定した** (§3.3 B-6)。
  v2 の実クラスタ種別 (F-12) は引き続き未調査のままだが、v3 の判断はそれに依存しない
- **v2 の ALB のリスナー・ターゲットグループ・ヘルスチェック設定** — IaC が無いためリポジトリから
  確認できない (F-1)。INF-D の `/alive` は v2 のコードにエンドポイントが存在する事実
  ([../analysis/v2-deploy-observability.md](../analysis/v2-deploy-observability.md) の推測節) に基づく提案であり、
  **v2 の ALB が実際にそこを見ているかは未確認**
- **v2 の CloudWatch アラーム・通知先の有無** — 未調査 ([observability.md](observability.md) §8 と同じ残課題)。
  既存の通知先を再利用できるなら INF-K の実装が軽くなる
- **v2 の WAF 設定の有無** — コンソール構築のため確認不能 ([auth.md](auth.md) §6.11-3 の断定範囲)。
  **ただしオーナー確認により、Geo Match ルール `AllowJapanOnly` を運用していることは判明している**
  (2026-08-29。ルールの詳細 — 適用先・優先度・例外 — は未確認)。
  INF-L はこの未確認に依存しない (v3 で新規に入れる判断)
- ~~v2 の FE がどの Route53 レコードで公開されているか~~ — **解消 (2026-09-07。issue #5 の実測 = F-13)**。
  `hassan-terraform` の `route53_records_app.tf` に **`hassan.jp` A → Vercel** の記録があり、
  §9.2 のケース A (`hassan.jp` を v3 へ向け替える) は選択可能と確認された。
  **ただしケース A / B のどちらを最終的に採るかは別途未確定のまま** (§9.2 参照)
- **Vercel の Function の egress IP がどの国と判定されるか** — v2 は通常 API を
  Vercel のサーバ経由で叩きながら (`hassan-v2-frontend/src/lib/api-client.ts:38-41`)
  `AllowJapanOnly` を運用できているため **JP と判定されている可能性が高い**が、
  **本リポジトリからは確認できない**。**v3 の段階1 の設計はこの事実に依存しない**
  (ブラウザ直叩きのため ALB に届くのは常にエンドユーザーの IP)。
  **[frontend.md](frontend.md) の段階2 へ移る前に必須の調査になる**
- **Terraform の S3 backend が持つロック機構の利用可否** — 採用する Terraform バージョンに依存する。
  infra リポ立ち上げ時に backend のドキュメントで確認する。**満たせない場合は DynamoDB ロックを併設**
  (INF-A に代替を明記済み)

### 11.4 本書の仮定 (違えば §2 の判断が変わる)

1. **同一 AWS アカウント・同一リージョン `ap-northeast-1`** (F-8 の v2 実測に合わせた) と仮定した。
   → 違えば INF-A / INF-I / §6.1 の段 1〜2
2. **v3 の BE は単一の ECS サービス**で、ワーカー分離を初期に行わない ([design_memo.md](design_memo.md)
   「ワーカー分離は初期不要」) と仮定した。→ 非同期ジョブを別サービスに分ける場合、§10.1 の
   `ecs-cluster` モジュールとアラーム定義が増える
3. **アセットのアップロードは API 経由 (multipart)** で、ブラウザから S3 への直接 PUT を行わない
   ([API/README.md](API/README.md) D-API-14) と仮定した。→ 直接 PUT を採る場合、S3 の CORS と
   バケットポリシーの設計が変わる
4. **Slack を通知先とする** ([observability.md](observability.md) §4.6 の記述に合わせた) と仮定した。
   → 別の通知先なら INF-K
