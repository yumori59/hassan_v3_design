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

**本書は infra リポジトリ立ち上げの直接の入力**である (C-15 により dev 環境の先行構築が最優先)。

ただし **「必要なインフラ構成要素の一覧」はユーザー確認が完了していない**
([design_memo.md](design_memo.md) の未完事項「その他インフラ何が必要か一覧化してあるふぁさんに確認する」)。
そこで本書は次の 2 段構成を採る:

1. **§3 = 確認に使う提案一覧**。要素ごとに用途・環境差・管理主体・**確認ステータス**を持つ。
   一覧そのものの確定は §9 の `[Answer]:` で求める。**確認前の要素を「確定」として扱わない**
2. **§2 / §4〜§7 = 一覧の中身に依存しない設計判断**。役割分担・state・環境差の付け方・
   構築順序・IaC 範囲外の線引きは、要素が 1〜2 個増減しても変わらない

| 本書で確定するもの | 本書で確定しないもの (先送り先) |
|---|---|
| Terraform / ecspresso の分担、tfstate の保管と apply 主体 (§4) | 個々のリソースのサイジング根拠 (実測後に §5 の値を改訂) |
| dev / prod の構成差の**付け方**と初期値 (§5) | マイグレーションツールの選定 ([architecture.md](architecture.md) の D-4) |
| 構築順序とリポ間依存 (§6) | 通知先の実体 (Slack チャンネル名) — 運用設計 |
| IaC 範囲外の線引きと理由 (§7) | インフラ要素一覧の最終確定 (§9 の `[Answer]:`) |

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
| F-11 | API の公開エンドポイントは **ALB の生 DNS 名**が README に記載されている (`hassan-v2-api-dev-alb-….elb.amazonaws.com`) | `hassan-v2-backend/README.md:14` |
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
| **INF-J** | v3 のホスト名 | **v2 とは別ホスト名 (別 ALB) を割り当てる**。ACM 証明書は Terraform で DNS 検証により発行し、Route53 のレコードのみ管理する (**ホストゾーン自体は既存のものを data source で参照し、Terraform の管理対象にしない**) | (a) v2 と同一ドメイン・同一 ALB に相乗り: `/themes` などのパスが v2 と衝突し、v3 側にパスプレフィックスが必要になる ([API/README.md](API/README.md) の API-Q1 が**別ドメイン前提でプレフィックス無しの API 設計を確定済み**。相乗りにすると API 設計全体が変わる)。(b) v2 の ALB を Terraform に import して共用: C-14 で import しない方針が確定している。(c) ALB の生 DNS 名を公開エンドポイントにする (v2 の F-11): 全面切替 (C-11) 時に**クライアント側の URL 変更が必須**になり、切り戻しも DNS で行えない |
| **INF-K** | 通知経路 | **CloudWatch アラーム → SNS トピック → AWS Chatbot (Slack)**。**prod は critical に限り SNS の email 購読も併設する** (Slack が使えない間の経路。束ね方と環境差は [operations.md](operations.md) §7.5 が SSOT)。SNS トピックとアラームを Terraform で管理し、**Slack ワークスペース側の連携承認は範囲外** (§7) | (a) Lambda を自作して Slack へ POST: 運用対象のコードが増え、通知経路自身の監視が必要になる。(b) メール (SNS の email サブスクリプション) **のみ**: [observability.md](observability.md) §4.6 が通知先を「開発チーム (Slack)」と定めているため、経路が一致しない。**Slack + メールの併用は採用側**であり、この却下は「メール単独」に対するものである。(c) 環境ごとに 1 トピックへ集約する: prod で「今すぐ見るべきか」が判断できない ([operations.md](operations.md) §7.5 の重大度 2 分類) |
| **INF-L** | WAF | **prod の ALB に AWS WAF をアタッチし、マネージドルール (共通脅威 / 既知の不正入力 / IP レピュテーション) + レートベースルールを入れる。dev には同じルールを `count` モードで入れる** (誤検知を dev で先に観測するため)。**アプリ層のレート制限を WAF に置き換えない** ([auth.md](auth.md) §6.11-3 の決定) | (a) WAF を入れない: 未認証エンドポイントへのボリューム型攻撃がアプリのミドルウェアだけで受け止められる。auth.md が「WAF はアプリ側制限の上位防御として検討する」と本書へ委ねている。(b) dev には一切入れない: prod 固有の誤検知が本番で初めて出る。`count` モードなら **dev の自動テストをブロックせずにルールの当たりを観測できる**。(c) WAF でレート制限を代替してアプリ側を持たない: local / dev で WAF が無い環境の挙動が prod と変わり、**制限の単体テストが書けない** (auth.md の決定に反する) **2026-08-10 (ユーザー決定)**: **管理者経路 (`/admin/*`) の IP 許可リストは本増分では入れない** — [auth.md](auth.md) §6.2 の「追加の層」③ が要求していたが、FE を Vercel に置くと ALB が見る送信元 IP が Vercel の Function になり成立しない ([frontend.md](frontend.md) FE-Q7 = ③ で確定)。**マネージドルールとレートベースルールは本決定の対象外** (引き続き入れる) |
| **INF-M** | 運用アクセス手段 | **ECS Exec を dev で有効・prod で無効**にし、prod で必要になった場合は**その都度 Terraform で有効化して apply する** (有効化の履歴が残る)。**踏み台サーバーを作らない** | (a) 常時 prod でも有効: 本番コンテナへ入る経路が常に開く。(b) 踏み台サーバーを維持 (v2 の F-10 の前提): SSH 鍵の配布・パッチ適用・アクセスログの管理が増える。**マイグレーションは INF-H の RunTask で足りるため、踏み台の主用途が消える** |
| **INF-N** | ログの保持期間 | **ロググループを Terraform で明示作成し、保持期間を dev 30 日 / prod 400 日に設定する** (`awslogs-create-group` による暗黙作成をやめる。**本書がロググループと保持期間の SSOT** — [observability.md](observability.md) §8 の残課題のうちインフラ側をここで確定する) | (a) v2 方式 (F-9): デプロイ時に暗黙作成されるため**保持期間が「無期限」になり、費用が単調増加する**。IaC の管理対象から外れ、削除・変更の履歴も残らない。(b) prod も 30 日: 監査ログ ([observability.md](observability.md) §4.5) の追跡可能期間が 1 か月になり、四半期単位の調査ができない |
| **INF-O** | v2 インフラとの関係 | **v2 の稼働中リソースを Terraform に import せず、v3 のリソースを新規に作る** (C-14)。共有するのは**既存の Route53 ホストゾーン (参照のみ)** に限る | (a) v2 を import して同じ IaC で管理 (Q-7 の選択肢 C): 稼働中リソースの import に本番停止リスクがあり、全面切替 (C-11) で廃止予定のものに投資することになる。(b) ホストゾーンも新規作成: ドメインの委譲 (NS レコードの変更) が必要になり、v2 の名前解決に影響する |

---

## 3. インフラ構成要素の提案一覧 (ユーザー確認用)

> 本節が回答する ID: **AC-3.6** (洗い出し) / **D-8** (管理範囲)。
> **この一覧は提案であり確定ではない**。確定は §9 の `[Answer]:` で求める。

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
| NAT Gateway | タスクの外向き通信 (Anthropic API・ECR・Secrets Manager) | **dev 1 個 / prod 2 個 (AZ 冗長)** | TF | **要確認** (dev のコスト削減として 1 個にする案の可否) |
| S3 Gateway エンドポイント | S3 通信を NAT を通さない | 同一 | TF | 前提 |
| セキュリティグループ (ALB / ECS / RDS / RunTask) | 三段構成 (ALB→ECS→RDS のみ許可) | 同一 | TF | 前提 |
| Interface エンドポイント (ECR / Secrets / Logs) | NAT 転送量の削減 | — | TF | **要確認** (初期導入するか、転送量が問題化してから足すか。§2 INF-F は後者を提案) |

### 3.2 コンピュート・配信

| 要素 | 用途 | dev / prod の差 | 管理主体 | 確認 |
|---|---|---|---|---|
| ALB + リスナー (443) + ターゲットグループ | HTTPS 終端・SSE の通し口 | **アイドルタイムアウト 300 秒は共通** (INF-C)。証明書のドメインが異なる | TF | 前提 |
| ターゲットグループのヘルスチェック | `/alive` / 判定主体はここだけ (INF-D) | 同一 | TF | 前提 |
| ALB のアクセスログ (S3) | リクエスト単位の事後調査 | **prod のみ有効** | TF | **要確認** (dev でも有効にするか) |
| ECR リポジトリ | backend イメージ。**タグ不変 (immutable) + スキャン有効 + ライフサイクル (直近 N 世代保持)** | 共通 (1 リポジトリを両環境で共有) | TF | **要確認** (dev/prod でリポジトリを分けるか) |
| ECS クラスタ (Fargate) | タスクの実行基盤 | 環境ごとに 1 クラスタ | TF | 前提 |
| **ECS サービス / タスク定義** | アプリの実行単位・リリース | `desiredCount` dev 1 / prod 2 (INF-E) | **ECS** | 前提 (C-14) |
| マイグレーション実行タスク定義 | INF-H の RunTask 用。**接続情報は `secrets` で Secrets Manager から注入する** (CI に DB 接続情報を渡さない — [operations.md](operations.md) §4.1) | 同一 (イメージは同じ) | **ECS** | 前提 |
| AWS WAF (ALB にアタッチ) | 未認証エンドポイントの上位防御 (INF-L) | **prod = block / dev = count** | TF | **要確認** (要否そのもの) |

### 3.3 データストア

| 要素 | 用途 | dev / prod の差 | 管理主体 | 確認 |
|---|---|---|---|---|
| RDS PostgreSQL (インスタンス) | アプリの DB (C-6) | **dev: Single-AZ / prod: Multi-AZ**。インスタンスクラスは §5 | TF | **要確認** (Aurora PostgreSQL にするか RDS for PostgreSQL にするか。F-12 により v2 の種別が未確定) |
| 自動バックアップ + PITR | 復旧手段 | **dev 7 日 / prod 30 日** | TF | **要確認** (prod の保持日数) |
| ストレージ暗号化 (KMS) | 保管時の暗号化 | 両環境で有効 | TF | 前提 |
| 削除保護 (`deletion_protection`) | 誤削除防止 | **dev 無効 / prod 有効** | TF | 前提 |
| パラメータグループ | ログ設定 (`log_min_duration_statement` 等) | 同一 | TF | **要確認** (スロークエリログの取得方針) |
| S3 バケット (アセット・ナレッジのファイル) | 添付ファイルの保管。**非公開 + ACL を付けない + presigned URL のみ** ([API/README.md](API/README.md) D-API-14') | バケットを環境ごとに分離 | TF | 前提 |
| 同バケットの CORS | ブラウザから presigned URL で GET する場合に必要 | **許可オリジンが Vercel の環境別 URL** | TF | **要確認** (FE から直接 GET するか、BE 経由にするか) |
| 同バケットのライフサイクル | 不完全マルチパートの削除・世代管理 | 同一 | TF | **要確認** |
| S3 バケット (ALB アクセスログ用) | 3.2 のログ出力先 | prod のみ | TF | 要確認 (3.2 と同じ判断) |

### 3.4 設定・シークレット

| 要素 | 用途 | dev / prod の差 | 管理主体 | 確認 |
|---|---|---|---|---|
| Secrets Manager のシークレット (器) | DB 接続情報 / `ANTHROPIC_API_KEY` / JWT 署名鍵 (`JWT_KEY` / `ADMIN_JWT_KEY`) / 外部 API キー | 環境ごとに別シークレット | TF (**値は手動** INF-G) | 前提 ([auth.md](auth.md) §6.8) |
| SSM Parameter Store | **Agent ID / Environment ID** (版管理で切り戻し可能に) / 環境依存の非秘密値 / **Agent 発行元のハッシュ記録** | 環境ごとに別パス (`/hassan-v3/<env>/...`) | TF (器) / **CI が値を書く** | 前提 (D-6。分類は [operations.md](operations.md) §3.3 の④・⑤) |
| KMS キー | Secrets / RDS / S3 / tfstate の暗号化 | 環境ごとに別キー | TF | 前提 |
| ECS タスク実行ロール / タスクロール | `secrets` の取得 / S3・SSM へのアクセス | 環境ごとに別ロール (**dev のロールが prod のリソースを参照できないこと**) | TF | 前提 |

### 3.5 可観測性

| 要素 | 用途 | dev / prod の差 | 管理主体 | 確認 |
|---|---|---|---|---|
| CloudWatch ロググループ (アプリ / RunTask) | アプリログの集約 (O-1) | **保持期間 dev 30 日 / prod 400 日** (INF-N) | TF | 前提 |
| メトリクスフィルタ | ログから LLM 失敗・429 等を抽出 ([observability.md](observability.md) §4.3 / §8 の仮定「ログからのフィルタで始める」) | 同一定義 | TF | 前提 |
| CloudWatch アラーム | [observability.md](observability.md) §4.6 の AL-1〜AL-7 (しきい値の SSOT) | **アラーム自体は dev / prod とも AL-1〜AL-7 の全件を作る**。**通知先に繋ぐ範囲が環境で変わる** (dev は AL-6 のみ) — 環境差の SSOT は [operations.md](operations.md) §7.5 | TF | 前提 |
| SNS トピック | アラームの通知先 (INF-K) | **prod 2 本** (`alerts-critical` / `alerts-warning`) **/ dev 1 本** (`alerts-dev`)。束ね方と対応するアラーム番号は [operations.md](operations.md) §7.5 | TF | 前提 |
| **SNS の email 購読** | Slack が使えない間の経路。**prod の `alerts-critical` のみに付ける** ([operations.md](operations.md) §7.5) | prod のみ | TF (**確認メールの承認は受信者本人** = 外部) | **要確認** (宛先メールアドレス) |
| AWS Chatbot (Slack 連携) | Slack への配信 | 同一 | TF (**ワークスペース承認は外部** §7) | **要確認** (Slack を使うか) |
| CloudWatch ダッシュボード | [observability.md](observability.md) §6 の最低限ダッシュボード | prod のみ | TF | **要確認** |
| AWS Budgets + 予算アラート | **AWS 利用料**の急増検知 (LLM コストは AWS 課金ではないため別系統 — [observability.md](observability.md) AL-4 が担当) | prod のみ / dev は少額のしきい値 | TF | **要確認** (C-12 は LLM の上限なしを定めるが、AWS 側の予算監視は別論点) |

### 3.6 CI/CD・その他

| 要素 | 用途 | dev / prod の差 | 管理主体 | 確認 |
|---|---|---|---|---|
| GitHub OIDC プロバイダ | CI からのロール引き受け (INF-I) | アカウントに 1 個 | TF | 前提 |
| IAM ロール (用途別。一覧は §4.5) | 用途別権限。**信頼条件は `environment` で絞る** (モノレポでは `repo:` で分離できない — §4.5) | 環境ごとに別ロール | TF | 前提 |
| Route53 レコード (API のホスト名) | v3 API の公開名 (INF-J) | dev / prod で別ホスト名 | TF (**ホストゾーンは参照のみ**) | **要確認** (使用するドメイン名) |
| ACM 証明書 | ALB の TLS | 環境ごとに発行 | TF | 前提 |
| tfstate 用 S3 バケット + KMS | state の保管 (INF-A) | 1 バケット・環境ごとにキー分離 | **手動** (§7 の例外 1 件) | 前提 |
| Vercel プロジェクト・環境変数・独自ドメイン | FE のホスティング (C-6) | Preview (dev 相当) / Production | **外部** (§7) | 前提 |
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
| `ecspresso deploy` (dev) | **CI** (`main` への push で自動。承認なし) | C-15 の継続デプロイ |
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
| `deploy-dev` | `repo:<org>/<app-repo>:environment:dev` | dev の ECR push + `ecspresso deploy` + Agent 再発行 |
| `deploy-prod` | `repo:<org>/<app-repo>:environment:prod` | prod の `ecspresso deploy` |
| `agent-prod` | `repo:<org>/<app-repo>:environment:prod-agent` | prod の Agent 再発行 (Secrets Manager 読み取り + SSM 書き込み) |
| `migration-dev` | `repo:<org>/<app-repo>:environment:dev` / `:environment:dev-db-destructive` | dev のマイグレーション (RunTask) |
| `migration-prod` | `repo:<org>/<app-repo>:environment:prod-db` | prod のマイグレーション (RunTask) |
| **`e2e-dev`** | **`repo:<org>/<app-repo>:environment:dev-e2e`** | **E2E の資格情報取得 (Secrets Manager の read のみ)** |
| infra 用 (`plan` / なし) | `repo:<org>/<infra-repo>:pull_request` | infra リポは**別リポなので `repo:` で分離できる**。`apply` は人間が手元で行うため CI 用ロールは `plan` のみ |

**要点 3 つ**:

1. **`environment: dev` を E2E とデプロイで共有しない** — 共有すると `sub` が同一になり、
   **E2E のワークフローが dev のデプロイ用ロール (ECR push / ecspresso) を引き受けられる**。
   **専用 environment `dev-e2e` を作る** (承認者は設定しない = 自動実行のまま)。
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

## 5. 環境の構成差 (dev / prod)

> 本節が回答する ID: **D-1** (AWS 側の環境分離。FE との対応は §5.3) / **D-8**。

### 5.1 差分の付け方 (規則)

1. **リソース定義は `modules/` に 1 つだけ持ち、差は `envs/<env>` の変数値で表す** (INF-B)
2. **「dev には作らない」要素は、モジュールの `count` / `for_each` を変数で切る** (定義を分岐でコピーしない)
3. **変数のうち「本番の安全性に効くもの」は既定値を prod 側の安全な値にする** —
   `deletion_protection` / `skip_final_snapshot` / WAF のモードは、**変数を書き忘れたときに
   prod が危険側に倒れない向き**に既定値を置く

### 5.2 初期値の表

**値の根拠**: 実測トラフィックが無いため、**INF-E / INF-N を除く数値は暫定値**である。
運用開始後に §10 の手順で改訂する (改訂の SSOT は本表)。

| 項目 | dev | prod | 根拠・備考 |
|---|---|---|---|
| ECS `desiredCount` | 1 | **2** | INF-E。v2 の単一タスク (F-4) を継承しない |
| ECS タスクの CPU / メモリ | 512 / 1024 | **1024 / 2048** | v2 は両環境 512/1024 (同書 §2)。v3 は SSE 接続を保持するため prod のみ引き上げる (暫定) |
| ローリング更新 | min 100% / max 200% | 同左 | v2 と同じ (同書 §3)。**SSE は更新時に切れる前提** ([design_memo.md](design_memo.md)) |
| デプロイサーキットブレーカー | 有効 + 自動ロールバック | 同左 | v2 で既に有効 (同書 §1.4)。**継承する** |
| ターゲットグループの登録解除待ち | 30 秒 | **60 秒** | 進行中ターンの一部が完了できる猶予。**切断前提の設計は変えない** (FE が再接続する — [API/README.md](API/README.md) J-6) |
| ALB アイドルタイムアウト | 300 秒 | 300 秒 | INF-C |
| ECS Exec | 有効 | **無効** | INF-M |
| RDS 構成 | Single-AZ | **Multi-AZ** | prod の可用性 |
| RDS インスタンスクラス | 小 (`db.t4g` 系) | 中 (`db.m7g` 系) | **暫定**。v2 の実クラスは未調査 (F-12)。**この 2 つは RDS for PostgreSQL 前提の値である** — §3.3 の確認で **Aurora PostgreSQL** に決まった場合、`db.t4g`/`db.m7g` ではなく Aurora が対応するクラス (`db.t4g.medium` 以上 / `db.r7g` 系) に置き換わり、**Multi-AZ の表現も「クラスタ + リーダーインスタンス」に変わる** (Single-AZ / Multi-AZ の行も同時に読み替える) |
| RDS バックアップ保持 | 7 日 | **30 日** | §3.3 の確認対象 |
| RDS 削除保護 | 無効 | **有効** | §5.1 の規則 3 |
| NAT Gateway | 1 | **2** | AZ 障害時に prod が全断しない |
| WAF | `count` モード | **block モード** | INF-L |
| ログ保持期間 | 30 日 | **400 日** | INF-N |
| ALB アクセスログ | 無効 | **有効** | §3.2 の確認対象 |
| アラート通知 (**通知先に繋ぐ範囲**) | AL-6 (タスク異常) のみ | AL-1〜AL-7 全件 (critical / warning の 2 トピックに振り分け) | dev の通知過多を避ける。**この環境差と重大度分類の決定は [operations.md](operations.md) §7.5 が SSOT** (本書はそれを実装する側)。**アラーム自体は両環境で全件作る** (§3.5) |

### 5.3 FE (Vercel) と BE (AWS) の環境対応 (D-1)

| 論理環境 | BE (AWS) | FE (Vercel) | DB | 承認 |
|---|---|---|---|---|
| local | 開発者のマシン (docker compose 等) | `next dev` | ローカル PostgreSQL | — |
| **dev** | `envs/dev` の ECS / RDS | **`main` ブランチの Preview** | dev の RDS | なし (継続デプロイ) |
| **prod** | `envs/prod` の ECS / RDS | **`production` ブランチ = Production** | prod の RDS | H-2 / H-3 / H-4 |

- **FE の Production Branch を `main` にしない**のは既定値からの意図的な変更である
  ([../../templates/shared/.claude/rules/04-human-checkpoints.md](../../templates/shared/.claude/rules/04-human-checkpoints.md) §2.4 / §4.4)
- **FE の環境変数 (API のベース URL) が両系統をつなぐ唯一の結び目**である。
  Preview → dev の ALB ホスト名、Production → prod の ALB ホスト名を Vercel 側に設定する
  (この値の管理は Vercel 側 = §7 の範囲外)
- **CORS の許可オリジンは BE 側の設定値**として持つ (Vercel の Preview URL が変動する場合の扱いは §9 の確認事項)

---

## 6. 構築順序 (dev 先行。C-15)

> 本節が回答する ID: **AC-3.6** / **D-8** / **D-7** (順序のうちインフラ側)。

### 6.1 dev 環境の構築手順

**各段の完了条件を満たすまで次に進まない**。段 0〜2 は infra リポ立ち上げと同時に行う。

| 段 | 内容 | 完了条件 (観測可能な形) |
|---|---|---|
| **0** | §9 の `[Answer]:` を解消する (要素一覧・AWS アカウント構成・ドメイン名) | 一覧が確定し、本書の §3 の「要確認」がゼロになる |
| **1** | **tfstate の置き場を作る** — S3 バケット (バージョニング + SSE-KMS + パブリックブロック) を **CLI で 1 回だけ手作業で作成** (§7 の例外) | `terraform init` が S3 backend で成功する |
| **2** | **OIDC プロバイダ + [§4.5](#45-oidc-の信頼条件-sub-クレーム--モノレポでは-environment-で分ける) の表のロール一式** (INF-I) を apply。**表の行を 1 つでも落とさない** — 落とした分は「その機能を初めて動かしたとき」まで気付けない | ①CI の `plan` ジョブが PR にコメントできる (キーを一切置いていないこと) ②**§4.5 の表の各ロールについて `aws iam get-role` が成功する** (`plan` だけの確認では `dev-e2e` / `prod-agent` / `prod-db` の欠落を見逃す) |
| **3** | **network** — VPC / subnet / SG / NAT / S3 エンドポイント | `plan` の差分ゼロ。private subnet からの外向き通信が確認できる |
| **4** | **RDS + Secrets の器** — RDS を private subnet に作り、DB 接続情報のシークレットを作成 | シークレットに**値を投入済み** (INF-G の手順①)。tfstate に平文が無いこと |
| **5** | **ECR + ECS クラスタ + ALB / TG / ACM / Route53** | ホスト名で ALB に HTTPS 接続でき、TG がまだ unhealthy であること |
| **6** | **CloudWatch (ロググループ / フィルタ / アラーム) + SNS + Chatbot** | **dev のトピック 1 本へのテスト通知が Slack に届く** (prod は 2 トピック + メール購読の到達確認が RL-2 の完了条件 — [operations.md](operations.md) §6.1) |
| **7** | **backend: ecspresso 設定 + 初回 `deploy`** — サービス定義に `loadBalancers` を含める (§4.3) | TG が healthy になり、`/alive` が ALB 経由で 200 |
| **8** | **マイグレーション実行タスク定義 + RunTask で初回適用** (INF-H) | スキーマが適用され、ログが CloudWatch に出る |
| **9** | **Managed Agent と Environment の dev 発行** (**dev は承認不要。prod は H-3**。`deploy-backend.yml` の `apply_agent`) | **Agent ID と Environment ID が SSM に書かれ** ([operations.md](operations.md) §3.3 の⑤)、会話系 API が dev で動く |
| **10** | **frontend: Vercel プロジェクト + 環境変数 + Preview デプロイ** | Preview から dev API を叩けて認証が通る |
| **11** | **dev への継続デプロイ運用開始** (`main` への push で 7〜10 が自動で回る) | 2 回連続で無人デプロイが成功する |

### 6.2 prod 環境の構築 (開発完了後。C-15)

**同じ手順を `envs/prod` に対して実行する**。dev と異なるのは次の 3 点のみ:

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
| X-10 | **踏み台サーバー** | v3 では作らない (INF-M)。RunTask と ECS Exec で用途を満たす | 作成しない (v2 のものに v3 から依存しない) |

---

## 8. 本番観点への回答

### 8.1 本書が回答する ID

| ID | 状態 | 回答 |
|---|---|---|
| **D-8 IaC の管理範囲** | **回答** | §4 (分担・tfstate 連携・apply 主体) / §3 (要素ごとの管理主体) / §7 (範囲外と理由)。tfstate は S3 + ロック (INF-A)、apply は**人間** (§4.4)、v2 の import はしない (INF-O) |
| **AC-3.6** | **回答 (一覧は確認待ち)** | §3 に VPC / ALB / ECS / RDS / Secrets / ログ・監視 / OIDC / S3 / WAF / Vercel を洗い出し、管理主体と範囲外理由を付けた。**一覧の最終確定は §9 の `[Answer]:`** — 未確認の要素を確定として扱わない |
| **D-1 環境** | **部分 (インフラ側は回答)** | §5.2 の環境差表と §5.3 の FE / BE 対応表。環境ごとの値は `envs/<env>` の変数 (INF-B)、秘密は Secrets Manager の器 + 値の分離 (INF-G)。**アプリ内の設定値の持ち方は [architecture.md](architecture.md) §3.9② が SSOT** |
| **D-3 デプロイ手順** | **部分 (リソース前提を回答)** | §4.3 (初回作成で ALB 紐付けを含める) / §4.4 (実行主体) / §5.2 (サーキットブレーカーと登録解除待ち)。**手順そのものは [../../templates/app-monorepo/.github/workflows/deploy-backend.yml](../../templates/app-monorepo/.github/workflows/deploy-backend.yml) と [architecture.md](architecture.md) D-3 が SSOT** |
| **D-5 シークレット管理** | **回答 (具体化)** | INF-G。**器 = Terraform / 値 = Terraform 管理外**。秘密は Secrets Manager、非秘密の環境依存値は SSM。方式の SSOT は [architecture.md](architecture.md) D-5、鍵の扱いは [auth.md](auth.md) §6.8 |
| **O-1 構造化ログ** | **回答 (受け皿のみ)** | §3.5 / INF-N。ロググループを Terraform で明示作成し保持期間を設定する (**v2 の暗黙作成 F-9 を継承しない**)。ログの内容・必須フィールドは [observability.md](observability.md) §4.1 |
| **O-5 SSE / 長時間処理** | **回答 (インフラ側)** | INF-C (アイドルタイムアウト 300 秒) / §5.2 (登録解除待ち)。**切断の検知と再接続の仕様は [observability.md](observability.md) §4.3 F-5 / [API/README.md](API/README.md) J-6** |
| **O-7 アラート** | **回答 (受け皿のみ)** | §3.5 / INF-K。CloudWatch アラーム → SNS (**prod 2 本 / dev 1 本**) → Chatbot (Slack) + **prod critical はメール購読も併設**。**しきい値の SSOT は [observability.md](observability.md) §4.6 / 重大度分類・環境差・トピック本数の SSOT は [operations.md](operations.md) §7.5** (本書はどちらも参照する側) |
| (関連) **O-3** | **参照 + 補足** | LLM コストの上限は設けない (C-12)。**AWS 利用料そのものの監視 (AWS Budgets) は §3.5 の確認対象**として別に提案する (LLM 費用は AWS 課金ではないため同じ仕組みで見えない) |
| (関連) **API-Q1** | **回答** | INF-J。**v2 とは別ホスト名 (別 ALB)** を採る。[API/README.md](API/README.md) の「別ドメイン前提・パスプレフィックス無し」という API 設計の前提が成立する |
| (関連) **auth.md の WAF 要否** | **回答** | INF-L。**prod = block / dev = count**。アプリ層のレート制限は置き換えない ([auth.md](auth.md) §6.11-3) |

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

**前提 (実測事実から導かれる制約)**: **v2 の API 公開エンドポイントは ALB の生 DNS 名であり (F-11)、
API 用の Route53 レコードが存在しない**。v3 は最初から別ホスト名で自分の ALB を指す (INF-J)。
したがって **API 側には「付け替えるレコード」も「DNS で戻すレバー」も無い**。
**実質的な切替・切り戻しのレバーは FE の公開ドメイン 1 レコード (と Vercel の Promote) だけ**である。

**公開方式は 2 ケースあり、どちらを採るかは未確定** (使用ドメイン名の確認待ち。§11.1 の Q-INF-3 /
[operations.md](operations.md) §6.3 の ⑥ が運用側の SSOT):

| # | 手順 | ケース A (既存の公開ドメインを v3 へ付け替える) | ケース B (v3 を別 URL で公開する) |
|---|---|---|---|
| 1 | **切替前** | v3 の prod を §6.2 で構築し、**v3 のホスト名**で FE の Production を動作確認する (この時点で v2 は無変更のまま稼働) | 同左 |
| 2 | **TTL の短縮** | **FE の公開ドメインのレコード**の TTL を 60 秒に下げ、旧 TTL の期間だけ待つ (**対象は FE のレコード 1 件のみ**。API 側には対象レコードが無い) | **不要** (DNS を触らない) |
| 3 | **切替** | **FE の公開ドメインを v3 の Vercel Production へ向ける**。**API のホスト名は DNS ではなく FE (Vercel) の環境変数で切り替わる** — Production スコープの API ベース URL が v3 の ALB ホスト名を指しており、**Promote が実質の切替操作**である (§5.3) | **v3 の URL をユーザーへ案内する**。既存ドメインは v2 のまま |
| 4 | **切り戻し (ロールバック)** | **FE の公開ドメインのレコードを旧レコード (v2 の FE) へ戻す** (TTL 60 秒のまま作業する)。v2 側は無変更のため再構築は不要 | **v3 FE の Production を利用停止の案内表示に Promote し、v2 の URL を案内する** (DNS 操作は無い) |
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

[Answer]:

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

[Answer]:

**Q-INF-4. dev 環境のコストと可用性のバランス**: §5.2 の dev 側の値 (Single-AZ / NAT 1 個 /
タスク 1 本 / ログ 30 日) でよいか。dev は開発期間中フル稼働する (C-15) ため、
**夜間・週末の停止 (RDS の停止 / タスク数 0) を運用に入れるか**。

[Answer]: **提案値を採用し、夜間・週末の停止は入れない** (2026-07-31 ユーザー回答)。
nightly E2E ([testing.md](testing.md) §7.4) との干渉が無く運用が単純。コストが問題化したら後から導入を検討する

### 11.2 他の設計判断の確定待ち (本書がブロックされている項目)

| 項目 | 待っているもの | 決まると本書のどこが変わるか |
|---|---|---|
| マイグレーションの方式 | [architecture.md](architecture.md) D-4 (psqldef / golang-migrate) | INF-H の RunTask が実行するコマンド。**経路 (RunTask) は方式に依存しない** |
| データ移行の方式 | Q-1 (データ引き継ぎの要否) | §9.1 の転送経路のみ。**§9.2 の切り戻し可能期間は Q-1 に依存せず確定済み** (公開後 7 日。[operations.md](operations.md) §6.4 が SSOT) |
| 公開方式 (ケース A / B) | 使用ドメイン名の確認 (§11.1 の Q-INF-3) | §9.2 の手順 2〜4 (ケース A のみ DNS 操作がある) |
| Vercel の Preview URL の扱い | FE 設計 | §5.3 の CORS 許可オリジン (可変 URL を許可するか、固定の Preview ドメインを使うか) |

### 11.3 未調査の事実 (推測で埋めていない項目)

- **v2 の RDS のエンジン種別・バージョン・インスタンスクラス・Multi-AZ の有無** — README には
  エンドポイントと DB 名のみ (F-12)。コンソールアクセスが必要。
  **v3 の RDS 種別 (Aurora / RDS for PostgreSQL) の判断材料として要る** (§3.3 の確認対象)
- **v2 の ALB のリスナー・ターゲットグループ・ヘルスチェック設定** — IaC が無いためリポジトリから
  確認できない (F-1)。INF-D の `/alive` は v2 のコードにエンドポイントが存在する事実
  ([../analysis/v2-deploy-observability.md](../analysis/v2-deploy-observability.md) の推測節) に基づく提案であり、
  **v2 の ALB が実際にそこを見ているかは未確認**
- **v2 の CloudWatch アラーム・通知先の有無** — 未調査 ([observability.md](observability.md) §8 と同じ残課題)。
  既存の通知先を再利用できるなら INF-K の実装が軽くなる
- **v2 の WAF 設定の有無** — コンソール構築のため確認不能 ([auth.md](auth.md) §6.11-3 の断定範囲)。
  INF-L はこの未確認に依存しない (v3 で新規に入れる判断)
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
