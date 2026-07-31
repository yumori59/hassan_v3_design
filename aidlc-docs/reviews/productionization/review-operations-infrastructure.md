# レビュー結果 — Task-3d / 3e (運用設計・インフラ設計)

> レビュー実施: 2026-07-30 / レビュアー: `design-reviewer` (別セッション。起草者ではない)
> 基準: [08-production-gates.md](../../../.claude/rules/08-production-gates.md) /
> [feedback_review_patterns.md](../../../.claude/rules/feedback_review_patterns.md) / ルート `CLAUDE.md` (ハイブリッド方針)
> **PoC 基準では判定しない**。「PoC では対象外だった」を省略理由として認めない

## レビュー結果サマリ

- **対象 (レビューした設計成果物・リポジトリ相対パス)**:
  - `docs/design/operations.md` (608 行。環境 / シークレット / デプロイ / 全面切替 RL-0〜RL-5 / 環境戦略・DB 適用範囲。OP-A〜OP-J)
  - `docs/design/infrastructure.md` (566 行。インフラ要素 40 件 / Terraform・ecspresso 分担 / 環境差 / 構築順序 / IaC 範囲外。INF-A〜INF-O)
- **整合確認のために読んだ (レビュー対象外・未編集)**: `docs/analysis/v2-deploy-observability.md` /
  `docs/analysis/poc-prompt-inventory.md` / `docs/design/observability.md` / `docs/design/architecture.md` /
  `docs/design/design_memo.md` / `docs/design/API/README.md` /
  `templates/shared/.claude/rules/04-human-checkpoints.md` / `templates/shared/.claude/rules/02-issue-granularity.md` /
  `templates/backend-repo/.github/workflows/deploy.yml` / `templates/infra-repo/CLAUDE.md.tmpl` / `templates/README.md` /
  `aidlc-docs/inception/productionization/requirements.md`
- **件数**: **重大 4 件 / 中 9 件 / 軽微 5 件**
- **判定 (この 2 文書のスコープ)**: **Freeze 不可**。重大 4 件はいずれも「実装リポで手が止まる or 本番で静かに壊れる」種類であり、修正後に再レビューが必要

### 実行した検証

```
$ make doc-lint
[WARN ] ./docs/design/infrastructure.md:506 未回答の [Answer]:
[WARN ] ./docs/design/infrastructure.md:514 未回答の [Answer]:
[WARN ] ./docs/design/infrastructure.md:521 未回答の [Answer]:
[WARN ] ./docs/design/infrastructure.md:527 未回答の [Answer]:
[WARN ] ./docs/design/operations.md:503 未回答の [Answer]:
[WARN ] ./docs/design/operations.md:514 未回答の [Answer]:
[doc-lint] 対象 75 ファイル / エラー 0 件 / 警告 20 件
```

(残り 14 件の警告は既存ファイル内の未確定マーカー語の検出。本 2 文書由来は上記 6 件の未回答 `[Answer]:` のみ。
いずれも「ユーザー回答待ちを明示するための意図的な未回答」であり、確定条件と影響範囲が
`operations.md` §10.1 / `infrastructure.md` §11 に書かれている — DR-5 違反ではない)

```
$ make check-traceability
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 44/44 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
```

### 抜き取り照合 (18 件実施 / 網羅照合は未実施)

**照合したもの (一次ソースで確認)**:

| # | 主張 (出典) | 結果 |
|---|---|---|
| 1 | `operations.md:35` / `infrastructure.md` F-1〜F-13 の「CI が image タグを `main` へ commit」 | **一致** (`hassan-v2-backend/.github/workflows/dev-deploy.yml:35-45` に `jq` 書き換え → `git commit` → `git push origin HEAD`) |
| 2 | `operations.md:36` の `di/provider.go:83-94` (`GO_ENV` で `.env` を読む) | **一致** (`loadConfig` の `switch os.Getenv("GO_ENV")`、`godotenv.Load("env/.prod.env")` 等) |
| 3 | `operations.md:148` / F-6 の「`.dockerignore` の除外は `vendor` のみ」 | **一致** (`hassan-v2-backend/.dockerignore` は 1 行 `vendor`) |
| 4 | `infrastructure.md` F-2 (ecspresso の管理範囲は 5 キーのみ) | **一致** (`stacks/prod/ecspresso.yml` = region/cluster/service/service_definition/task_definition/timeout) |
| 5 | F-3 (サービス定義に `loadBalancers` が無い) | **一致** (`stacks/prod/ecs-service-def.json` にキー無し) |
| 6 | F-4 (`desiredCount: 1` / コンテナ `healthCheck` 未定義) | **一致** (service-def `"desiredCount": 1` / task-def に `healthCheck` キー無し) |
| 7 | F-5 (`assignPublicIp: ENABLED`) | **一致** |
| 8 | `infrastructure.md:286` の「ローリング更新 min 100% / max 200% は v2 と同じ」 | **一致** (`minimumHealthyPercent: 100` / `maximumPercent: 200`) |
| 9 | F-6 (task 定義に `secrets` 無し・`environment` は `GO_ENV` 1 個) | **一致** (`stacks/prod/ecs-task-def.json:28` の `GO_ENV` のみ) |
| 10 | F-11 (公開エンドポイントが ALB の生 DNS 名) | **一致** (`hassan-v2-backend/README.md:14` 前後の表) |
| 11 | F-12 (RDS エンドポイントと `is-cluster=true`) | **一致** (`README.md:24`, `:25`) |
| 12 | F-10 (踏み台 SSH トンネル + 手動 `psqldef`) | **一致** (`README.md:74` 以降の `ssh -N -L 5432:...`) |
| 13 | F-13 (`ACL: ObjectCannedACLPublicRead`) | **一致** (`hassan-v2-backend/aws/s3.go:46`) |
| 14 | INF-D の「v2 に `/alive` が存在する」 | **一致** (`hassan-v2-backend/router/router.go:56-58`、`controller/middleware.go:36` でログ抑制対象) |
| 15 | `operations.md:214` の 6 ジョブ順序と承認位置 | **一致** (`templates/backend-repo/.github/workflows/deploy.yml` の `needs` 連鎖・`environment` 指定) |
| 16 | `operations.md:141` の「GitHub environment 5 つ」 | **一致** (04 §4.2 の表と同一。ただし**保持シークレットの記述が本書と衝突** → 重大 4) |
| 17 | `infrastructure.md:299` / `operations.md:510` の「dev は AL-6 のみ通知 (出典: observability §4.6)」 | **不一致**。observability.md §4.6 には環境差・重大度分類の記述が無い → 中 5 |
| 18 | `operations.md:246` の Agent 再発行トリガ (`prompts/` 全体) と `poc-prompt-inventory.md` §2 の「再発行対象は 4 ファイルのみ」 | **不整合** → 中 2 |
| (追加) | C-14 の射程 (image タグ commit 廃止 + v2 の import しない) | **一致** (`requirements.md:36` に両方が明記。infrastructure の C-14 引用は正しい) |
| (追加) | `design_memo.md:156-157` (主負荷は接続保持 / keep-alive 30 秒 対 ALB 60 秒) · `API/README.md:131` J-6 · `observability.md:42` O-A · `02-issue-granularity.md:127` §2.2.1 · `templates/README.md:47` · `templates/infra-repo/CLAUDE.md.tmpl:25` 絶対ルール 2 | **すべて一致** |

**対象外にした範囲 (正直な申告)**:

- `infrastructure.md` §3 の 40 要素すべての妥当性 (AWS リソースの選定粒度・サイジング値の妥当性) は
  実測前提の暫定値であり、値の妥当性はレビュー対象にしていない (本書自身が §5.2 で暫定と宣言している)
- `operations.md` §6.2 が参照する `API/idea-boards.md` §4 M-1〜M-4 / `API/settings.md` §3.2 / `API/news.md` NW-Q3 の
  本文照合は未実施 (リンク切れは doc-lint で確認済み。内容の一致は未検証)
- `auth.md` §6.8 (JWT 鍵ローテーション) · `observability.md` §4.4 (安全弁) の内容照合は未実施 (参照の形のみ確認)
- v2 の AWS 実環境 (コンソール) の照合は不可能 (両文書とも未調査として明記済みで、これは適切)

---

## 重大 (Must Fix)

### 重大 1. マイグレーションの実行経路が deploy.yml と INF-H で矛盾しており、どちらも「書き換えが必要」と引き渡していない

- 該当: `docs/design/infrastructure.md:96` (INF-H) / `docs/design/operations.md:211`,`:485`,`:550` /
  `templates/backend-repo/.github/workflows/deploy.yml` の `apply_migration`
- **事実**: `deploy.yml` の `apply_migration` は `runs-on: ubuntu-latest` で
  `env: DATABASE_URL: ${{ secrets.DATABASE_URL }}` を渡し、**GitHub ランナーから直接 DB へ接続する形**になっている。
  一方 INF-H は「**CI ランナー自身は RDS に到達しない**。ECS RunTask で VPC 内から接続する」を採用案とし、
  却下案 (b) に「RDS をパブリックアクセス可にして CI から直接接続」を明記している。
  INF-F では RDS は private subnet である。
- **なぜ本番で問題になるか**: 実装リポはこの雛形をそのまま埋める前提 (`operations.md:549`「`deploy.yml` の
  プレースホルダを埋める」= ECR 名 / ロール ARN / ecspresso 設定の 3 つのみ) なので、
  ①ランナーから private RDS に到達できず `apply_migration` が実行不能になるか、
  ②到達させるために **RDS をパブリック化する** (INF-H の却下案そのもの) のどちらかに倒れる。
  RL-0 の段 8 (`infrastructure.md:336`) が最初に踏む経路であり、立ち上げ初日に詰まる。
- **修正案**: (a) `operations.md` §5.1 の 6 ジョブ表と §9 の backend 引き渡しに
  「`apply_migration` は **ECS RunTask 起動 + 完了待ち + CloudWatch Logs の取得**として実装する
  (ランナーから DB へ直接接続しない)」を明記する。(b) `infrastructure.md` §3.2 の
  「マイグレーション実行タスク定義」に、**deploy.yml 側の書き換えが前提であること**を追記する。
  (c) 併せて `DATABASE_URL` を GitHub environment secret に置く必要が無くなる (重大 4 と同時に解消する)

### 重大 2. Agent ID を「実行中に読み替える値 (§3.3 の④)」に分類したことで、「Agent 再発行 → リリース」の順序保証が壊れている

- 該当: `docs/design/operations.md:120` (§3.3 の④に `**Agent ID** (OP-E)`) / `:56` (OP-E) /
  `:241`-`:242` (apply_agent → release) / `:258` (ロールバックは「SSM を戻す → **タスクを置換**」)
- **矛盾**: ④の定義は「アプリが実行中に値を読み替える (`config` が TTL 60 秒でキャッシュし再取得)・反映は最大 60 秒」。
  一方 §5.3 の Agent ロールバックは「SSM の値を戻す → **BE のタスクを置換**」と書いており、
  **同じ値の反映条件が 2 通りに書かれている**。
- **なぜ本番で問題になるか**: 04 §2.3 / `deploy.yml` は `apply_agent` (新 Agent ID を SSM へ書く) を
  **`release` (新コード) の前**に置く。これが安全なのは「稼働中タスクは古い Agent ID を保持し続け、
  タスク置換で新コードと新 Agent が同時に切り替わる」場合のみ。
  ④のホットリロードだと **apply_agent の 60 秒後に「旧コード + 新 tool schema の Agent」**という
  組み合わせが必ず発生し、prod では H-3 承認から H-4 承認までの待ち時間ぶんこの状態が続く。
  これは BE-8 (新しい引数が黙って捨てられる) / BE-10 (台帳の前提チェックが常に失敗) が起きる窓を
  設計自身が作っていることになり、`operations.md:242` の「古い Agent のまま新コードを出さない」の裏返しが無防備。
- **修正案**: Agent ID を **③相当 (タスク起動時に解決し、実行中は読み替えない)** に分類し直す
  (保管先は SSM のままでよい — 版履歴を切り戻し手段に使う OP-E は維持できる)。
  §3.3 の④は「安全弁のしきい値 / 単価テーブルの版 / 失効しきい値」に限定し、
  **「④に置いてよいのは、旧コードが古い値で動き続けても壊れない値だけ」**という判定基準を明文化する。

### 重大 3. Anthropic の **Environment ID** が D-6 の回答から欠落している (08 が名指ししている構成要素)

- 該当: `docs/design/operations.md:56` (OP-E) / `:193` (§4.5 棚卸し) / `:235`-`:250` (§5.2) /
  `docs/design/infrastructure.md:161` / `:382` (X-4)
- **事実**: 08 の D-6 は「**Agent ID / Environment ID** を環境ごとにどう発行・更新するか」を要求している。
  PoC は Agent ID と**別に** `ENVIRONMENT_ID` を必須設定として持ち、未設定時は明示的にエラーを返す
  (`claude_managed_agents/cmd/devui/domain_discovery.go:440`,`:453`「`ENVIRONMENT_ID` が `.env` に未設定です。
  Anthropic コンソールで Environment を作成し…」、`internal/config/config_test.go:37` も `AGENT_ID` と
  `ENVIRONMENT_ID` を対で扱う)。
  にもかかわらず、2 文書の**どこにも Environment ID が現れない**。
  §4.5 は「新しい設定値の追加漏れを防ぐ棚卸し」を目的とした表だが、その表の LLM 行は
  「Anthropic API キー / 用途別の既定モデル名 / Agent ID」の 3 つで閉じている。
- **なぜ本番で問題になるか**: ①必須設定が引き渡し物から落ちるため、RL-0 段 9 (dev の Agent 発行) で
  初めて発覚する。②より重いのは**環境分離**の問題で、「dev と prod で Anthropic の Environment を
  分けるのか共有するのか」が未決のまま。共有した場合、**dev の tool 定義変更が prod の Agent 実行環境に
  影響し得る**経路が残る (`operations.md:598` の仮定は「Agent を環境ごとに発行できる」ことだけを扱い、
  Environment には触れていない)。③`plan_agent` のハッシュ比較対象・`apply_agent` の書き込み対象・
  切り戻し対象がすべて「Agent ID」単位で書かれているため、Environment の更新が要る変更 (tool 定義側) は
  差分検出も切り戻しも設計されていない。
- **修正案**: (a) §4.5 の棚卸し表と §3.3 の分類に **Environment ID** を追加する (Agent ID と同分類)。
  (b) §5.2 に「Environment を環境ごとに分ける / 共有する」の決定 (または `[Answer]:` と暫定既定 + 影響範囲) を書く。
  (c) §10.3 の仮定を「Agent と Environment の**両方**を環境ごとに持てる」に改め、
  持てない場合の影響 (dev の変更が prod に及ぶ) を明記する。
  (d) `infrastructure.md` X-4 の対象に Environment を含める。

### 重大 4. シークレット/Agent ID の「唯一の所在」が 3 文書で食い違っている (Secrets Manager / SSM / GitHub environment secret)

- 該当: `docs/design/operations.md:122` (「同じ値を 2 つの分類に置かない」) / `:141` (CI は GitHub environment secret) /
  `:56` (OP-E: Agent ID は SSM) / `docs/design/infrastructure.md:380` (X-2「**値のリストは Secrets Manager が唯一の所在**」) /
  `templates/shared/.claude/rules/04-human-checkpoints.md` §4.2 (environment の「保持するシークレット」列 =
  「dev の DB 接続情報 / dev の Anthropic API キー / **dev の Agent ID**」「prod-db: prod の DB 接続情報」
  「prod-agent: prod の Anthropic API キー / Agent ID の書き込み先」)
- **矛盾の内容**: `operations.md` は「値の所在の SSOT」を自称し (§0)、③秘密 = Secrets Manager、
  ④ = SSM と決め、「同じ値を 2 つの分類に置かない」を規則にしている。
  しかし §4.1 の CI 行は 04 §4.2 を参照しており、その 04 §4.2 では
  **DB 接続情報・Anthropic API キー・Agent ID が GitHub environment secret として重複保持**される。
  `deploy.yml` も実際に `secrets.DATABASE_URL` / `secrets.ANTHROPIC_API_KEY` を読む。
  さらに Agent ID は OP-E で「SSM が保管先・版履歴が切り戻し手段」なのに、04 §4.2 では GitHub secret にも置かれる。
- **なぜ本番で問題になるか**: ①**ローテーションが片方に効かない** — §4.3 の手順 (Secrets Manager 更新 → タスク置換) を
  実施しても GitHub secret 側が古いまま残り、次の `apply_migration` / `apply_agent` が旧値で動く
  (原因が分かりにくい形で失敗する)。②Agent ID が 3 箇所に存在すると、§5.3 の切り戻し (SSM の前バージョンへ戻す) が
  「どこを戻せば効くのか」を運用者が判断できない。③無言の重複は BE-2 (設定値の SSOT 不在) の再演。
- **修正案**: §4.1 に「**CI が GitHub environment secret として保持してよい値**」を限定列挙する
  (原則は「AWS ロールを引き受けるための情報のみ。DB 接続情報・API キー・Agent ID は Secrets Manager / SSM から
  実行時に取得する」)。RunTask 化 (重大 1) により `DATABASE_URL` は不要になり、`apply_agent` の
  `ANTHROPIC_API_KEY` も OIDC ロール経由の `secretsmanager:GetSecretValue` に置き換えられる。
  そのうえで **04 §4.2 の「保持するシークレット」列の是正が必要であること**を §9 の引き渡しに書く
  (現状 04 が SSOT と宣言されているため、本書側で上書きするなら明示が要る)。

---

## 中 (Should Fix)

### 中 1. ロールバックの「第一手段」に実行経路が無い (infra と operations で実行主体が食い違う)

- `docs/design/infrastructure.md:257`: 「`ecspresso rollback` = **人間が CI から起動**」
- `docs/design/operations.md:256`: 生の CLI (`ecspresso rollback --config=... --wait-until=service-stable`) を第一手段とし、
  「`deploy.yml` の失敗時ステップがこのコマンドを**出力する**」
- `deploy.yml` は文字列を `echo` するだけで、**rollback を起動する経路 (workflow_dispatch など) は雛形に無い**。
  一方 `operations.md:142`,`:55` は「開発者に AWS 認証情報を配らない」を方針にしている。
  結果、OP-G の第一手段を**誰がどこから実行するのか**が決まっていない (障害時に最も困る箇所)。
- 修正案: rollback 専用の `workflow_dispatch` ジョブ (環境と対象を入力に取り、`prod` は environment 承認) を
  引き渡し物に加えるか、「AWS 権限を持つ運用者が誰か」を §4.1 の経路表に 1 行追加する。

### 中 2. Agent 再発行のトリガが `prompts/` 全体のハッシュで、Agent 登録対象外のプロンプト変更でも再発行が走る

- `docs/design/operations.md:240`,`:246`: 「`prompts/` と tool schema のハッシュを比較」
  「`prompts/<domain>/` の 1 行修正でも `plan_agent` がハッシュ差分を検出し、prod では H-3 の承認を要求する」
- しかし `architecture.md` D-E / D-B' は **直接 LLM API 用のプロンプトも `prompts/<domain>/` に集約**する方針で、
  `docs/analysis/poc-prompt-inventory.md:46` は「**Anthropic 側 Agent リソースに登録され、変更時に再発行が必要なのは
  4 ファイルのみ**」「それ以外はコードのデプロイのみで反映 (再発行は不要)」と確定している。
- 影響: 直接 API 用プロンプトの誤字修正でも Agent ID が更新され、**進行中セッションが切れる**
  (`operations.md:240` 自身が避けたいと書いている事象) / prod では不要な H-3 承認が発生し、承認の意味が薄れる。
- 修正案: 「Agent に登録されるプロンプトと tool schema の集合を**宣言的に列挙したファイル** (例 `prompts/agents.yaml`) を
  ハッシュ対象にする」と決め、その列挙と実発行対象の一致を `check-tool-contract.sh` の検査項目に含める
  (列挙漏れが「再発行されない」に倒れないよう、検査側で担保する)。

### 中 3. `infrastructure.md` §9.2 / §11.2 が `operations.md` §6.4 の確定を反映していない (stale)

- `docs/design/infrastructure.md:444`: 「切り戻し可能な期間の定義…は **Q-1 (データ移行方式) の確定と同時に決める**」/
  `:534`: 「データ移行の方式 ← Q-1 待ち → §9.2 の切り戻し可能期間」
- `docs/design/operations.md:385`-`:391`: 切り戻し可能期間を **公開後 7 日**と確定し、
  「**この根拠は Q-1 の回答に依存しない**」と明示している。
- 並行起草の結果、infra 側だけが「未確定」のまま残っている。infra §9.2 の 5 (v2 の停止) が
  「切り戻し期間の経過後」を条件にしているため、**読者がどちらを信じるかで v2 削除の判断が変わる**。
- 修正案: `infrastructure.md` §9.2 の 4 と §11.2 の当該行を「期間は `operations.md` §6.4 (公開後 7 日) が SSOT」に差し替える。

### 中 4. `infrastructure.md` §9.2 に公開方式 (ケース A / B) の分岐が無く、v2 の実測事実 (F-11) と噛み合わない

- `operations.md:350`-`:356` は公開方式を **未確定 (ケース A = 既存ドメイン付け替え / ケース B = 別 URL)** とし、
  ケース A の前提として `infrastructure.md` §9.2 を参照している。
  しかし `infrastructure.md:436`-`:445` は §9.2 を「全面切替のリソース面の手順」として**無条件に**記述しており、
  ケース B の場合に何が変わるかが書かれていない (infra だけを読む実装者はケース A で確定済みと読む)。
- さらに §9.2 の 3「**API のホスト名を v3 の ALB へ向ける**」/ 4「DNS を元のレコードへ戻す」は、
  自身の実測事実 **F-11 (v2 の API 公開エンドポイントは ALB の生 DNS 名。Route53 レコードが存在しない)** と
  INF-J (v3 は最初から別ホスト名で自分の ALB を指す) の下では**成立しない**
  — 付け替えるレコードが無く、切り戻しのレバーも API 側には存在しない。
  実質的な切替・切り戻しのレバーは **FE の公開ドメイン 1 レコード**のみである。
- 修正案: §9.2 に「①ケース A / B の分岐 ②切替対象のレコードは FE ドメインのみで、API は v3 の
  ホスト名を FE の環境変数で切り替える (Vercel の Promote が実質のレバー)」を明記する。
  DNS を切り戻しの第一手段として書くなら、対象レコードを具体名で特定する。

### 中 5. アラートの環境差の出典が実在しない主張になっている (DR-1) / dev で全アラートを試験できない

- `docs/design/infrastructure.md:299`「アラート通知: dev = AL-6 のみ / prod = AL-1〜AL-7 全件
  (根拠: `docs/design/observability.md` §4.6)」・`docs/design/operations.md:510`「dev は AL-6 のみ通知する
  — infrastructure.md §5.2」。
  **`observability.md` §4.6 には環境差・重大度分類の記述が無い** (AL-1〜AL-7 のしきい値と通知先のみ)。
  2 文書が互いを根拠にし合っており、一次の決定がどこにも無い (循環参照)。
- 併せて整合しない点: `operations.md:310` の RL-1 完了条件 ③ は
  「**アラート AL-1〜AL-7 が dev で発火することを試験済み**」を要求するが、dev では AL-6 以外は通知されない。
  加えて `operations.md:508` で新設した **prod の 2 トピック (critical / warning) と メール経路は dev に存在しない**ため、
  **prod の通知経路は本番で初めて使われる**。RL-2 の完了条件 (`:311`) に到達確認が無い。
- 修正案: (a) 環境差の決定を 1 箇所 (observability §4.6 か本書のどちらか) に置き、他方は参照にする。
  (b) RL-1 ③ を「dev で**アラーム状態遷移**を試験」と「dev の通知経路 1 本の到達試験」に分ける。
  (c) RL-2 の完了条件に「prod の critical / warning 各トピックへのテスト通知が Slack とメールの両方に届く」を追加する。

### 中 6. SNS トピックの本数とメール購読が 2 文書で一致しない

- `docs/design/operations.md:508`-`:511`: prod は **2 トピック** (`alerts-critical` / `alerts-warning`)、
  critical は **Slack とメールの 2 経路**を購読させる。
- `docs/design/infrastructure.md:172`: 「SNS トピック | prod / dev で別トピック」= 環境ごとに 1 本と読める。
  §3.5 の要素一覧に **メール購読 (SNS email subscription) の行が無い**。INF-K の却下案 (b) は「メールのみ」を却下しているが、
  「Slack + メールの併用」は要素として洗い出されていない。
- 影響: §3 の一覧は Q-INF-1 でユーザー確認に出す表であり、ここから漏れると**確認自体から落ちる** (AC-3.6 の洗い出し漏れ)。
- 修正案: `infrastructure.md` §3.5 を「SNS トピック: prod 2 本 (critical / warning) / dev 1 本」に直し、
  「SNS email subscription (宛先は要確認)」を 1 行追加する。

### 中 7. 「アクティブな SSE 接続数」メトリクスが可観測性の SSOT に存在しない

- `docs/design/operations.md:340` (RL-3 の事前確認)・`:370` (prod デプロイ前に必ず確認する運用)・
  `:552` (backend 引き渡し 6) が、このメトリクスの存在に依存している。
- `docs/design/observability.md` には SSE の**異常終了 (F-5)** と keep-alive しか無く、
  **接続数メトリクスの定義が無い** (grep: `SSE 接続数` / `アクティブな SSE` はヒットせず)。
  observability.md は計測項目の SSOT を自称しているため、このままでは実装漏れになり、
  §6.3 の「起動前に SSE セッション数を確認する」手順が実行不能になる (「利用の少ない時間帯に」に退行する)。
- 修正案: observability 側に計測項目として追加することを §10.2 の先送り表に明記するか、
  本書が定義する項目として「名前・単位・出力元 (メトリクスフィルタか EMF か)」まで書く。

### 中 8. フィーチャーフラグの値の置き場が「infra または backend」で確定していない (DR-5)

- `docs/design/operations.md:118` (§3.3 の②): 「ECS タスク定義の `environment` (ecspresso のテンプレート、
  **値は Terraform の出力または `envs/<env>` の変数**)」/ 変更手順は「**infra または backend の PR**」。
  §7.2 (`:440`) はフラグを②に置くと決めている。
- 一方 `infrastructure.md:222` は「**Terraform 側で ECS サービスとタスク定義のリソースを一切定義しない**」、
  §4.1 で `environment` は ecspresso の所有物としている。
- 影響: §7.3 の仕組み 3「未完成機能は prod で `FEATURE_*` が false」の担保が、
  「backend リポの ecspresso テンプレート (レビュー対象のコード)」なのか「infra の変数 (人間の apply)」なのかで
  変わる。前者ならフラグ切替が通常の PR、後者なら infra PR + 人間の apply が必要で、リードタイムが別物。
- 修正案: 「フラグは backend リポの `stacks/<env>/` のタスク定義テンプレートに書く (infra の変数にしない)」のように
  1 つに決め、②の「Terraform の出力または `envs/<env>` の変数」は
  **インフラ由来の値 (RDS ホスト名等) に限る**と書き分ける。

### 中 9. `infrastructure.md` §6.1 段 9 の「H-3」表記が dev でも承認必須と読める

- `docs/design/infrastructure.md:337`: 「**Managed Agent の dev 発行** (H-3。`deploy.yml` の `apply_agent`)」
- 04 §2.3 と `operations.md:219` は **dev の Agent 発行は承認不要 (自動)** と確定している。
  構築順序表に H-3 が付いていると、立ち上げ担当が「dev でも承認者設定が必要」と誤読する
  (§6.2 の 3 では prod だけが承認を通ると正しく書かれているため、表記の不統一)。
- 修正案: 段 9 の `(H-3。…)` を「(dev は承認不要。prod は H-3)」に改める。

---

## 軽微 (Nice to Have)

1. `docs/design/operations.md:141`: 「**GitHub environment secret** (`dev` / `dev-db-destructive` / … の **5 つ**)」は
   environment 名の列挙であって secret の列挙ではない。「5 つの environment に紐づく environment secret」と表記を直す
   (重大 4 の修正時に併せて)。
2. `docs/design/operations.md:508`: 重大度 2 分類 (critical = AL-1/AL-4/AL-6 / warning = 残り) に
   **分類根拠と却下案が無い** (§2 の他の判断は却下案付きで書かれているため浮いている)。
   特に AL-3 (切り詰めの発生) を warning に置く判断は BE-6 の再発検知に直結するので一言根拠が欲しい。
3. `docs/design/operations.md:240`: `plan_agent` が比較する「前回発行時の記録 (SSM)」のパスが
   §3.3 の④ / §9 の SSM パス階層 (`/hassan-v3/<env>/...`) の例に含まれていない (Agent ID とハッシュ記録は別キー)。
4. `docs/design/operations.md:71`,`:250`: local は「dev の Agent ID を共有」だが、
   §5.2 の「開発者専用 Agent を作る」場合の **ID の置き場 (`.env.local` のみか)** が書かれていない。
   併せて、開発者専用 Agent の**削除**の責任者が未記述 (放置すると棚卸し対象外の Agent が増える)。
5. `docs/design/infrastructure.md:146` の RDS 種別 (Aurora / RDS for PostgreSQL) は「要確認」だが、
   §5.2 のインスタンスクラス (`db.t4g` / `db.m7g`) は RDS for PostgreSQL 前提の値になっている。
   Aurora になった場合に変わることを §5.2 の備考に 1 行入れると、暫定値の前提が明確になる。

---

## 本番観点カバレッジ (08-production-gates)

**D 領域** (この 2 文書の主担当):

| ID | 状態 | 箇所 | レビュアーの所見 |
|---|---|---|---|
| D-1 環境 | **回答あり** | `operations.md` §3 / `infrastructure.md` §5.2・§5.3 | 3 環境 + FE/BE 対応が両文書で一致。SSOT 分割 (対応表 = infra、運用ルール = operations) も破綻なし |
| D-2 CI ゲート | **対象外 (理由あり・先送り先明示)** | `operations.md` §8 / `infrastructure.md` §8.2 | `01-construction-loop.md` §7・`ci.yml`・`architecture.md` D-2 が SSOT。妥当 |
| D-3 デプロイ手順 | **回答あり (欠落 1 件)** | `operations.md` §5 / `infrastructure.md` §4 | 手順・順序・API 変更時の順序は良い。**ロールバックの実行経路が未定 (中 1)** |
| D-4 マイグレーション | **部分回答 (理由あり)** | `operations.md` §7.4・§7.5 `[Answer]` / `infrastructure.md` INF-H・§8.2 | 自動適用範囲 (AC-3.7) は確定。ツール選定は未確定で影響範囲も明記。**ただし実行経路が矛盾 (重大 1)** |
| D-5 シークレット | **回答あり (矛盾 1 件)** | `operations.md` §4 / `infrastructure.md` INF-G・X-2 | 器と値の分離・不採用方式の明示は良い。**所在の重複が未解決 (重大 4)** |
| D-6 Agent ライフサイクル | **部分回答 (欠落あり)** | `operations.md` §5.2 / `infrastructure.md` X-4 | **Environment ID が未回答 (重大 3)**、再発行トリガの粒度が過大 (中 2)、ID の反映条件が矛盾 (重大 2) |
| D-7 段階リリース | **回答あり** | `operations.md` §6 (RL-0〜RL-5)・§7.3 / `infrastructure.md` §6 | C-11 と C-15 と D-J の関係整理 (§6.0) は特に良い。4 段の「prod に出さない仕組み」も具体的 |
| D-8 IaC の管理範囲 | **回答あり** | `infrastructure.md` §4・§7 (X-1〜X-10) | 範囲外 10 件すべてに理由がある。X-1 の「除外は 1 段だけ」・X-6 の「承認機構を IaC 化しない」は妥当 |

**A / O 領域** (この 2 文書では主担当ではない — 対象外の申告状況):

| ID | 状態 | 箇所 |
|---|---|---|
| A-1〜A-7 | **対象外 (理由 + 先送り先あり)** | `operations.md` §8 の A 行 (運用上の接点のみ扱う) / `infrastructure.md` §8.2 (RLS 却下の言及付き) |
| O-1 | **回答あり (受け皿)** | `infrastructure.md` INF-N・§3.5 (v2 の暗黙作成 F-9 を継承しない) |
| O-2 / O-4 / O-6 | **対象外 (理由 + 先送り先あり)** | `infrastructure.md` §8.2 / `operations.md` §8 の O 行 |
| O-3 | **参照 + 補足あり** | `infrastructure.md` §8.1 (AWS Budgets を LLM コストと別系統として提案) |
| O-5 | **回答あり (インフラ側)** | INF-C (ALB 300 秒) / §5.2 (登録解除待ち)。**接続数メトリクスの定義が欠落 (中 7)** |
| O-7 | **部分回答** | `operations.md` §7.5 (束ね方) / `infrastructure.md` INF-K。**環境差の出典と本数が不整合 (中 5・中 6)** |

**無言の省略 (DR-2) は無し**。全 ID に回答・部分回答・対象外理由のいずれかがある。

## 頻出パターン (feedback_review_patterns.md) の確認結果

| # | 判定 |
|---|---|
| DR-1 出典なしの断定 | **1 件検出** (中 5: observability §4.6 を根拠とする環境差が同節に無い)。他の v2 実測事実は 18 件抜き取りで全件一致 |
| DR-2 本番観点の無言の省略 | **なし** (両文書に対象外理由の節がある)。ただし D-6 の Environment ID は**観点内の要素が丸ごと落ちている** (重大 3) |
| DR-3 既存データの不在 | **なし**。`operations.md` §6.2 が「範囲は未確定・実行位置と満たすべき性質は確定」と切り分け、写像 0 件・v2 を書き換えない原則・切り戻し期間まで書いている |
| DR-4 PoC 実装のコピー設計 | **なし**。PoC の `.env` 書き換え (BE-3) と踏み台 (F-10) をいずれも明示的に不採用 |
| DR-5 曖昧語による丸投げ | **1 件** (中 8: フラグ値の置き場が「infra または backend」)。他は「気を付けて切り替える で済ませない」等、曖昧語を自ら禁じており良質 |
| DR-6 AC の宙吊り | **なし** (traceability 44/44)。AC-3.5 の「移行方式」が Q-1 待ちである点は §6.2 / §10.1 OP-R4 で理由と先送り先が明示済み |
| DR-7 プロトタイプを仕様として扱う | **該当なし** (本 2 文書はプロトタイプを参照していない) |
| BE-3 (`.env` 書き換え) | 構造的に潰している (`operations.md` §4.1・§4.4) |
| BE-5 (DB 未接続フォールバック) | 構造的に潰している (`operations.md:184` 起動失敗・フォールバックを持たない) |
| BE-6 (MaxTokens 切り詰め) | `MaxTokens` をコード内定数 (§3.3 の①) に置く方針は妥当。検知は observability AL-3 側 (中 5 で分類根拠を要望) |
| BE-9 (Tools 全置換) | `operations.md:244` で承認材料に Tools 一覧を出す運用として潰している |
| BE-2 (設定値の SSOT 散在) | §3.3 の 4 分類 + 「同じ値を 2 つの分類に置かない」+ FE へは API で配る、で潰している — **ただし重大 4 が同じ規則を自ら破っている** |

---

## 良かった点

1. **`operations.md` §6.0 が C-11 / C-15 / D-J の見かけの矛盾を先に固定している**。
   「全面切替 = ユーザーを分割しない」「1 回で切替 = 段階開放しない」「v2 併用期間は存在する」の
   3 者を分けたうえで RL-3 (公開) と RL-4 (機能移送) に切り分けた整理は、実装リポの誤解を確実に減らす。
2. **未確定の扱いが徹底している**。OP-H (Q-8 未回答) を「暫定既定 + 回答が変わったら差し替える節の名指し」で扱い、
   §10.1 に影響節と確定条件を表で持ち、doc-lint の `[Answer]:` に接続している。
   `infrastructure.md` §0 の 2 段構成 (提案一覧と、一覧に依存しない設計判断の分離) も同種の良い構造。
3. **v2 の失敗を「継承しない」形で個別に潰している**。F-3 (ALB 紐付けが ecspresso 管理外) に対する
   INF-D / §4.3 の「初回作成時に `loadBalancers` を含める。`UpdateService` では変更できない」は、
   実測事実から**再発の機構**まで踏み込んだ良い設計判断。
4. **`operations.md` §6.3 の「TTL 期間中の書き込み分散」**を自力で検出し、
   「①v2 を読み取り専用にする ②その間の更新を引き継がない」の二択に落として
   「『気を付けて切り替える』で済ませない」と書いている点。設計レビューで最も出にくい種類の指摘を起草側が先に潰している。
5. **§7.4 の 2 段階 / 3 段階分解**が 04 §2.2 の機械判定 1〜6 と 1 対 1 で対応しており、
   「1 回のデプロイに 2 段階の両方を含めない」という運用制約まで書かれている。
6. **INF-A が「S3 backend のロック機構が使えない場合は DynamoDB を併設」と代替を先に書いている**。
   未確認事項を「確認する」で終わらせず、どちらに転んでも進める形になっている (§11.3 も同様)。

---

## この 2 文書のスコープでの Freeze 可否

**Freeze 不可 (重大 4 件)**。

- **重大 1・重大 4** は `templates/backend-repo/.github/workflows/deploy.yml` と
  `templates/shared/.claude/rules/04-human-checkpoints.md` §4.2 の是正を伴う (設計文書だけでは閉じない)。
  引き渡し先が雛形をそのまま使う前提なので、雛形の是正要求を §9 / §10 に書くところまでが修正範囲。
- **重大 2・重大 3** は `operations.md` 内で閉じる修正 (分類の変更と、Environment ID の追記 + `[Answer]:` 追加)。
- 中 1〜中 9 のうち **中 3・中 4・中 5・中 6 は `infrastructure.md` 側の追記/差し替え**で、
  operations 側の確定内容を反映すれば閉じる (2 文書間の stale の解消)。
- 修正後、**この 2 文書と `templates/` 側の是正差分**を対象に再レビューを行うこと。
  feature `productionization` 全体の Freeze 判定は他の設計成果物のレビュー結果に依存するため、本レビューでは扱わない。

---

## 修正の反映 (2026-07-30)

**指摘 18 件すべてに対応済み** (起草側による反映。再レビューは別セッションで行う)。
変更したファイル: `docs/design/operations.md` / `docs/design/infrastructure.md` /
`templates/backend-repo/.github/workflows/deploy.yml` /
`templates/shared/.claude/rules/04-human-checkpoints.md` (§4.2 のみ) / 本ファイル (本節の追記)。

### 重大

| ID | 反映先と内容 |
|---|---|
| 重大 1 | **(a)** `operations.md` §5.1 に「各ジョブの実行場所と DB への到達経路」表を新設し、`apply_migration` = **ECS RunTask (①起動 → ②完了待ち → ③終了コード判定 → ④CloudWatch Logs 取得)** と確定。§7.4 の共通前提 1 にも追記。**(b)** `infrastructure.md` INF-H に「この採用案は `deploy.yml` の書き換えを前提とする (2026-07-30 に是正済み)」と §3.2 のマイグレーション実行タスク定義行に `secrets` 注入を追記。**(c)** `DATABASE_URL` を GitHub 側から削除 (重大 4 と同時)。**deploy.yml**: `apply_migration` を RunTask 方式へ全面書き換え (`secrets.DATABASE_URL` 参照を削除 / ポーリング上限 `WAIT_TIMEOUT_SECONDS=1800` を明示し `aws ecs wait` の 10 分上限に依存しない / ログ取得は `always()`)。`plan_migration` も「差分生成が DB 接続を要する方式では同じ RunTask 経路を使う」を経路として確定 (コマンド実体は D-4 未確定のためプレースホルダ) |
| 重大 2 | `operations.md` §3.3 に **分類 ⑤ (SSM に置くが起動時に 1 回だけ解決し、実行中は読み替えない)** を新設し、Agent ID / Environment ID を ④ から移動。**④ に置いてよい値の判定基準**を明文化 (「旧コードが旧い値で動き続けても壊れず、新しい値をコード変更なしで解釈できる値だけ」)。OP-B の却下案 (d) に「④ に置くと『旧コード + 新 tool schema』が必ず発生する」を追加。§5.3 の Agent 行を「SSM を戻すだけでは反映されない・タスク置換が必須」に修正。§8 の D-1 / D-6 行、§9 の引き渡しも 5 分類に更新 |
| 重大 3 | **(a)** §4.5 の棚卸し表と §3.3 の分類 ⑤ に **Environment ID** を追加 (出典: `claude_managed_agents/cmd/devui/domain_discovery.go:453` / `internal/config/config_test.go:37` を一次ソースで再確認)。OP-E を「Agent ID と Environment ID の保管」に改題。**(b)** §5.2 に「Anthropic の Environment を環境ごとに分けるか」節を新設し、**暫定既定 = 分ける / 影響範囲 / `[Answer]:`** を記載 (§10.1 に OP-R8 として登録)。**(c)** §10.4 の仮定 1 を「Agent と Environment の両方を環境ごとに持てる」に改め、共有時の影響を明記。**(d)** `infrastructure.md` X-4 / §3.4 / §6.1 段 9 / §8.2 D-6 行の対象に Environment を追加。**deploy.yml** の `apply_agent` に Environment ID と source-hash の書き込みを追加 |
| 重大 4 | `operations.md` §4.1 に **「CI が GitHub environment secret / variable として保持してよい値」の限定列挙表** (IAM ロール ARN・リージョン・ECR / クラスタ名等) と **置かない値** (DB 接続情報 / Anthropic API キー / Agent ID・Environment ID) を追加し、理由 (ローテーションが片方に効かない / 切り戻し先が判断できない / BE-2 の再演) を明記。**04 §4.2 の「保持するシークレット」列を是正** (列名を「保持する値」に変更し 4 種に限定 + §4.5 のチェック項目も更新。**environment の一覧・承認者・Deployment branches の仕組みは未変更**)。是正の経緯は `operations.md` §9 の「雛形側の是正」表に記載。**deploy.yml** の `apply_agent` は `secrets.ANTHROPIC_API_KEY` を廃止し OIDC + `secretsmanager:GetSecretValue` に変更。**04 §2.6 の H-3 行 (二重化列) は編集範囲外のため未是正** — `operations.md` §10.2 の OP-F3 として起票 |

### 中

| ID | 反映先と内容 |
|---|---|
| 中 1 | `operations.md` §5.3 の表に **「実行経路 (誰がどこから)」列**を追加し、BE / Agent のロールバックを **backend リポの `rollback.yml` (`workflow_dispatch`。起動できるのは `prod*` environment の承認者)** と確定。`rollback.yml` に要求する形 (入力 3 種・environment・出力) を明記。§4.1 の経路表に **運用者行** (AWS 権限を持つのは承認者のみ・個人に長期認証情報を配らない) を追加。§9 の backend 引き渡し 7 と §10.2 の OP-F4 (雛形未整備) に登録。`infrastructure.md` §4.4 の `ecspresso rollback` 行を `rollback.yml` 参照に差し替え。**deploy.yml** の失敗時ステップを「`rollback.yml` の起動コマンドを出力する (自動起動しない)」に修正 |
| 中 2 | `operations.md` §5.2 に **「再発行のトリガは `prompts/agents.yaml` の列挙とする」**決定を追加 (事実 = `docs/analysis/poc-prompt-inventory.md` §2 の「再発行対象は 4 ファイルのみ」を一次確認 / 判断 / 決定 / 却下案 2 件)。列挙漏れを防ぐため `scripts/check-tool-contract.sh` の検査項目に「発行コマンドが送る集合と列挙の一致」を追加。「列挙外のプロンプト変更は H-3 を要求しない」も明記。**deploy.yml** の `plan_agent` のコメントと検査ステップ名を更新 |
| 中 3 | `infrastructure.md` §9.2 の期間を「**公開後 7 日。定義と根拠は `operations.md` §6.4 が SSOT**」に差し替え、§11.2 の「データ移行の方式」行を「§9.1 の転送経路のみ。切り戻し可能期間は Q-1 に依存せず確定済み」に修正 |
| 中 4 | `infrastructure.md` §9.2 を **ケース A / B の 2 列表**に再構成し、冒頭に「**F-11 により API 側には付け替えるレコードも DNS の戻しレバーも無い。実質のレバーは FE の公開ドメイン 1 レコードと Vercel の Promote**」を明記。§11.2 に「公開方式 (ケース A / B)」の待ち項目を追加 |
| 中 5 | **環境差の決定を `operations.md` §7.5 に一次の決定として置いた** (prod = 2 トピック / critical は Slack + メール / dev = 1 トピック・**AL-6 のみ通知**・ただし**アラーム自体は両環境で AL-1〜AL-7 全件作る**)。§0 の SSOT 表にも「重大度分類・環境差・トピック本数は本書 §7.5」と追記。`infrastructure.md` §5.2 / §3.5 / §8.1 の O-7 行は本書参照に差し替え (循環参照を解消)。**RL-1 ③ を ③-a (dev で全件のアラーム状態遷移を試験) と ③-b (dev の通知経路 1 本の到達試験) に分割**、**RL-2 に完了条件 ⑥ (prod の critical / warning へのテスト通知が Slack とメールに届く)** を追加。`observability.md` は編集禁止のため、相互参照の追記要求を §10.2 の **OP-F2** に起票 |
| 中 6 | `infrastructure.md` §3.5 の SNS 行を「**prod 2 本 (`alerts-critical` / `alerts-warning`) / dev 1 本 (`alerts-dev`)**」に修正し、**SNS email 購読の行を追加** (prod の critical のみ・宛先は要確認)。INF-K の採用案に「prod critical はメール購読を併設」を追加し、却下案 (b) を「メール**のみ**」の却下と明示 + 却下案 (c) (環境ごと 1 トピックに集約) を追加。CloudWatch アラーム行も「アラームは全件作り、通知先に繋ぐ範囲が環境で変わる」に修正 |
| 中 7 | `operations.md` §6.3 に**暫定定義**を追加 (名前 `sse.active_connections` / 単位 = 接続数のゲージ / 次元 / 出力元 = **EMF** / 出力間隔 30 秒) し、**SSOT は `observability.md`** であることを明記。同書への追記要求を §10.2 の **OP-F1** に起票 (§9 の backend 引き渡し 9 からも参照) |
| 中 8 | `operations.md` §7.2 に **「値の置き場 (確定)」行**を追加し、**フラグは backend リポの `stacks/<env>/` のタスク定義テンプレートに書く (infra の変数にしない)** と確定 (却下案 2 件付き)。§3.3 の ② 行を **インフラ由来の値 (Terraform 出力) とアプリ由来の値 (backend の PR のみ)** に書き分け。§9 の backend 引き渡し 8 に追加 |
| 中 9 | `infrastructure.md` §6.1 段 9 を「**Managed Agent と Environment の dev 発行 (dev は承認不要。prod は H-3)**」に修正 |

### 軽微

| ID | 反映先と内容 |
|---|---|
| 軽微 1 | `operations.md` §4.1 の CI 行を「**5 つの environment に紐づく environment secret / variable**」の表現に修正 (environment 名の列挙と secret の列挙を混同しない形にし、限定列挙表へ接続) |
| 軽微 2 | §7.5 に **重大度 2 分類の根拠** (critical = 放置するとユーザーが使えないか費用が増え続ける / warning = 被害が単調増加しない) と **AL-3 を warning に置く根拠** (1 件発火のため critical に置くとアラート疲れで AL-1 / AL-6 を見落とす。24 時間連続発生時は critical へ昇格) と **却下案 3 件**を追加 |
| 軽微 3 | `plan_agent` が比較する記録のパスを **`/hassan-v3/<env>/agent/<name>/source-hash`** として §3.3 の ⑤ 行・OP-E・§4.5・§5.2・§9 の引き渡しに明記 (Agent ID とは別キー。CI のみが読み書きする) |
| 軽微 4 | §4.4 に **開発者専用 Agent の ID の置き場 (`.env.local` のみ・SSM に書かない)** と **削除の責任者・命名規約 (`dev-<ユーザー名>-` 接頭辞)・削除期限 (対応 PR のマージ / クローズ時)** を追加。RL-2 の完了条件 ② に棚卸し (接頭辞付き Agent が残っていないこと) を追加 |
| 軽微 5 | `infrastructure.md` §5.2 の RDS インスタンスクラス行の備考に「**この 2 つは RDS for PostgreSQL 前提の値**。Aurora になった場合はクラスと Multi-AZ の表現が変わる」を追記 |

### 反映後の検証

```
$ make doc-lint
[doc-lint] 対象 78 ファイル / エラー 0 件 / 警告 29 件
  (本 2 文書由来の警告は意図的な未回答 [Answer]: のみ — operations.md 3 件 / infrastructure.md 4 件。
   operations.md の 1 件増は重大 3 で新設した「Environment を分けるか」の [Answer]。残りは他ファイルの既存警告)

$ make check-traceability
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 45/45 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature

$ ruby -ryaml -e '... deploy.yml ...'
YAML OK
 - build: steps=5 / plan_migration: steps=5 / apply_migration: steps=7
 - plan_agent: steps=6 / apply_agent: steps=4 / release: steps=5
```

### 本反映で新たに生じた未確定・是正要求 (再レビューの対象)

| # | 内容 | 記録先 |
|---|---|---|
| 1 | **Anthropic の Environment を dev / prod で分けるか共有するか** (暫定既定 = 分ける) | `operations.md` §5.2 の `[Answer]:` / §10.1 の OP-R8 |
| 2 | `observability.md` への **SSE 接続数メトリクスの追加** | `operations.md` §10.2 の OP-F1 |
| 3 | `observability.md` §4.6 への **相互参照 1 行の追記** (重大度分類・環境差の SSOT の明示) | 同 OP-F2 |
| 4 | **04 §2.6 の H-3 行「二重化」列の是正** (§4.2 は是正済み。§2.6 は本タスクの編集範囲外) | 同 OP-F3 |
| 5 | **`rollback.yml` の雛形追加** (`templates/backend-repo/.github/workflows/`) | 同 OP-F4 / §5.3 |

---

## 再レビュー (2 巡目・2026-07-30)

> レビュアー: `design-reviewer` (別セッション)。**上の 1 巡目の記述と「修正の反映」節は改変していない**。
> 基準は 1 巡目と同じ (08-production-gates / feedback_review_patterns / 本番基準)。

### 対象 (レビューした成果物・リポジトリ相対パス)

| パス | 見た範囲 |
|---|---|
| `docs/design/operations.md` | 全文 (813 行) |
| `docs/design/infrastructure.md` | 全文 (580 行) |
| `templates/backend-repo/.github/workflows/deploy.yml` | 全文 (465 行。`apply_migration` / `apply_agent` の書き換え) |
| `templates/backend-repo/.github/workflows/rollback.yml` | 全文 (138 行。**新規作成物**) |
| `templates/shared/.claude/rules/04-human-checkpoints.md` | §2.6 / §4.2 / §4.5 |
| `docs/design/observability.md` | §4.4.1 (新設) / §4.6 冒頭 / §4.3 / §4.4 / §5 |

**照合のために読んだ (レビュー対象外・未編集)**: `docs/analysis/poc-prompt-inventory.md` /
`docs/design/architecture.md` / `templates/shared/.claude/rules/01-construction-loop.md` ·
`02-issue-granularity.md` / `aidlc-docs/inception/construction-workflow/requirements.md` /
`aidlc-docs/inception/productionization/plan.md`。

### 実行した検証

```
$ make doc-lint
[doc-lint] 対象 78 ファイル / エラー 0 件 / 警告 29 件
  (本 2 文書由来は意図的な未回答 [Answer]: のみ — operations.md 3 件 (§5.2 Environment / §7.5 D-4 /
   §7.5 アラート宛先) / infrastructure.md 4 件 (Q-INF-1〜4)。他は llm-migration.md 5 件と既存ファイルの
   「TODO」語への反応)

$ make check-traceability
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 46/46 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
  (**本レビュー中に productionization の AC 総数が 45 → 46 に増えた** — 別セッションが
   requirements.md を更新したため。最終実行は 46/46 で未カバーゼロ)

$ ruby -ryaml (deploy.yml / rollback.yml)
deploy.yml: OK  jobs=build,plan_migration,apply_migration,plan_agent,apply_agent,release
  apply_migration: steps=7 / environment=${{ needs.plan_migration.outputs.approval_env }}
  apply_agent:     steps=4 / environment=${{ needs.plan_agent.outputs.approval_env }}
  release:         steps=5 / environment=(prod|dev)
rollback.yml: OK jobs=rollback / steps=8 / environment=${{ inputs.environment }}

$ grep -rn "secrets\." templates/backend-repo/.github/workflows/
(0 件 — GitHub secret への参照が雛形から消えている)
```

**抜き取り照合: 本節で 8 件** (llm-migration 側の 10 件と合わせて計 18 件。両 review に内訳を記載):

| # | 主張 (箇所) | 結果 |
|---|---|---|
| 1 | `deploy.yml` に `secrets.DATABASE_URL` / `secrets.ANTHROPIC_API_KEY` が残っていない (重大 1・重大 4) | **一致** (`grep "secrets\."` が 0 件。`ANTHROPIC_API_KEY` は `:390` の `aws secretsmanager get-secret-value` のみ) |
| 2 | `apply_migration` の 4 段構造 (起動 → 完了待ち → ログ取得 → 判定) | **一致** (`:202` ①/`:224` ②/`:245` ③ (`always()`)/`:263` ④。`WAIT_TIMEOUT_SECONDS: "1800"` は `:189`。②は意図的に失敗させず判定を④に集約している) |
| 3 | PoC の `ENVIRONMENT_ID` 必須性 (重大 3 の根拠) | **一致** (`claude_managed_agents/cmd/devui/domain_discovery.go:453` が「`ENVIRONMENT_ID` が `.env` に未設定です。Anthropic コンソールで Environment を作成し…」/ `internal/config/config_test.go:37` が `AGENT_ID=a\nENVIRONMENT_ID=e`) |
| 4 | 04 §4.2 の「保持する値」列が限定列挙に是正済み (重大 4) | **一致** (`:317`-`:341`。DB 接続情報 / API キー / Agent ID・Environment ID を置かない旨と理由が明記) |
| 5 | 04 §2.6 の H-3 行が Secrets Manager 方式に是正済み (OP-F3) | **一致** (`:200`「prod の Anthropic API キーは Secrets Manager が唯一の所在」+ OIDC 取得) |
| 6 | `observability.md` §4.4.1 の `sse.active_connections` 新設 (OP-F1) | **一致** (§4.4.1 に名前 / ゲージ / 次元 / EMF / 30 秒。§4.3 F-5・§4.4 keep-alive との内容重複は**無い**) |
| 7 | `observability.md` §4.6 冒頭の相互参照 (OP-F2) | **一致** (「重大度分類・環境差・通知経路は `operations.md` §7.5 が SSOT」) |
| 8 | `rollback.yml` の SSM パスが operations.md §3.3 の⑤ と一致するか | **不一致** → 新規 中 1 (`rollback.yml:92` が `/hassan-v3/<env>/agent/<name>/environment-id`、他はすべて `/hassan-v3/<env>/anthropic/environment-id`) |

**対象外にした範囲 (正直な申告)**: AWS / Anthropic の実 API 挙動 (RunTask のログストリーム名の形・Environment を
複数持てるか) は検証不能で、両文書とも未確認として扱っている / `infrastructure.md` §3 の 40 要素の値の妥当性
(1 巡目と同じく暫定値として対象外) / `API/*.md` 本文の全数照合。

---

### 1. 18 件の解消判定

| ID | 判定 | 確認した実体 |
|---|---|---|
| **重大 1** マイグレーション経路の矛盾 | **解消** | `operations.md:259`-`:277` に実行場所表 (`apply_migration` = ECS RunTask / private subnet / `secrets` 注入) と 3 つの禁止事項 (ランナー直結しない・ログは `always()`・`aws ecs wait` の 10 分既定に依存しない)。`infrastructure.md` INF-H に「`deploy.yml` の書き換えを前提とする (2026-07-30 に是正済み)」・§3.2 のマイグレーション実行タスク定義行に `secrets` 注入。`deploy.yml` は 4 段が実装され `secrets.DATABASE_URL` 参照が消滅。`plan_migration` も同経路を明記 (`:116`-`:122`) |
| **重大 2** Agent ID の反映条件の矛盾 | **解消** | §3.3 に分類 **⑤** を新設 (`:121`。起動時 1 回解決・実行中は再取得しない) + **④ に置いてよい値の判定基準**を明文化 (`:127`-`:132`)。OP-B 却下案 (d) に「④ に置くと旧コード + 新 tool schema が必ず発生」。§5.3 の Agent 行が「SSM を戻すだけでは反映されない・タスク置換が必須」。`deploy.yml:402`-`:403` と `rollback.yml:14`-`:15` にも同じ前提が書かれ、3 文書が一致 |
| **重大 3** Environment ID の欠落 | **解消** | 棚卸し (§4.5 `:230`) / 分類 (§3.3 の⑤) / 決定と `[Answer]` + 影響範囲 (§5.2 `:328`-`:351`) / 切り戻し (§5.3 の Agent 行) / 引き渡し (§9 infra 1・backend 2・6) / 仮定 (§10.4 の仮定 1) / `infrastructure.md` X-4・§3.4・§6.1 段 9・§8.2 D-6 の**すべて**に登場。出典 2 件を一次ソースで再照合済み (上表 3) |
| **重大 4** 秘密の所在の 3 文書食い違い | **解消 (中核)** — ただし列挙の外縁が不一致 → **新規 中 5** | §4.1 に限定列挙表 (`:152`-`:157`) + 置かない値 3 種と理由。04 §4.2 の列名を「保持する値」に変更し 4 種に限定。`deploy.yml` は `secrets.*` 参照ゼロ。04 §2.6 も是正済み。**残る不一致**: 04 §4.2 の `prod-db` 行が「タスク定義名・ロググループ名」を保持値に挙げているが §4.1 の列挙にはこの 2 つが無く、「4 種」の内訳が両文書で一意に決まらない |
| **中 1** ロールバックの実行経路 | **解消** | §5.3 に「実行経路 (誰がどこから)」列 + `rollback.yml` の要求仕様 (`:364`-`:371`)。§4.1 に運用者行。`infrastructure.md` §4.4 が `rollback.yml` 参照に差し替え。`deploy.yml:453`-`:464` が起動コマンドを出力し自動起動しない。**雛形も新規作成された** (別途 新規 重大 1 / 中 1 あり) |
| **中 2** 再発行トリガの粒度 | **解消** | §5.2 に「トリガは `prompts/agents.yaml` の列挙」の事実 / 判断 / 決定 / 却下案 2 件 (`:301`-`:316`)。列挙漏れを `check-tool-contract.sh` の検査項目で担保。`deploy.yml:311`-`:339` も agents.yaml 基準に更新 |
| **中 3** infra §9.2 / §11.2 の stale | **解消** | `infrastructure.md:453`「切り戻し可能期間は v3 公開後 7 日。**この定義と根拠は operations.md §6.4 が SSOT**」/ `:547`「§9.2 の切り戻し可能期間は Q-1 に依存せず確定済み」 |
| **中 4** 公開方式の分岐と F-11 | **解消** | `infrastructure.md:439`-`:454` を 2 列表に再構成し、冒頭に「**F-11 により API 側には付け替えるレコードも DNS の戻しレバーも無い。実質のレバーは FE の公開ドメイン 1 レコードと Vercel の Promote**」。§11.2 に「公開方式 (ケース A / B)」の待ち項目 |
| **中 5** アラート環境差の循環参照 | **解消** | 一次の決定を `operations.md` §7.5 (`:636`-`:642`) に置き、§0 の SSOT 表にも明記。`infrastructure.md` §5.2 `:300` / §3.5 `:171`-`:174` / §8.1 `:406` が本書参照に。RL-1 ③ を ③-a (全件のアラーム状態遷移) / ③-b (dev の通知経路 1 本) に分割 (`:420`)、RL-2 に完了条件 ⑥ (prod 2 トピックへのテスト通知が Slack とメールに届く) を追加 (`:421`) |
| **中 6** SNS トピック本数とメール購読 | **解消** | `infrastructure.md:172`-`:173` (prod 2 本 / dev 1 本 + **SNS email 購読行を新設**)。INF-K の却下案 (b) を「メール**のみ**」の却下と明示 + (c) 環境ごと 1 トピック集約の却下を追加 |
| **中 7** SSE 接続数メトリクスの不在 | **解消** — ただし二重定義が残る → **新規 中 3** | `observability.md` §4.4.1 に計測項目として新設 (上表 6)。`operations.md` §6.3 の暫定定義がそのまま残り、同節が「現時点で observability.md に定義が無い」と書いたままになっている |
| **中 8** フラグ値の置き場 | **解消** | §7.2 に「値の置き場 (確定)」行 (`:562`。backend リポの `stacks/<env>/` のタスク定義テンプレート・却下案 2 件)。§3.3 の②をインフラ由来 / アプリ由来に書き分け (`:118`)。§9 backend 8 |
| **中 9** infra 段 9 の H-3 表記 | **解消** | `infrastructure.md:338`「**Managed Agent と Environment の dev 発行** (**dev は承認不要。prod は H-3**)」 |
| **軽微 1** environment secret の表記 | **解消** | §4.1 `:148`「5 つの environment に紐づく environment secret / variable として登録」+ 限定列挙表へ接続 |
| **軽微 2** 重大度分類の根拠 | **解消** | §7.5 `:644`-`:661` に critical / warning の定義、AL-3 を warning に置く根拠 (アラート疲れ) と 24 時間連続時の昇格、却下案 3 件 |
| **軽微 3** source-hash のパス | **解消** | `/hassan-v3/<env>/agent/<name>/source-hash` が §3.3 の⑤ / OP-E / §4.5 / §5.2 / §9 に一貫して登場。`deploy.yml:315`,`:397` も同一 |
| **軽微 4** 開発者専用 Agent | **解消** | §4.4 `:215`-`:220` (置き場 = `.env.local` のみ / `dev-<GitHub ユーザー名>-` 接頭辞 / 削除責任者と期限) + RL-2 完了条件 ② に棚卸し |
| **軽微 5** RDS クラスの前提 | **解消** | `infrastructure.md:293` の備考に「この 2 つは RDS for PostgreSQL 前提の値」+ Aurora 時の読み替え |

**解消 18 / 部分 0 / 未解消 0**。1 巡目の指摘に**取りこぼしは無い**。

---

### 2. 新規指摘 (2 巡目)

#### 新規 重大 1. `rollback.yml` の Agent 切り戻しが**未実装でも成功扱いになる** (成功と報告して何もしない)

- 該当: `templates/backend-repo/.github/workflows/rollback.yml:86`-`:98` (ステップ ①)
- **事実**: ① の `run` は `echo "TODO: …"` と `::warning` だけで、**実装が無くても exit 0** する。
  その後 ② `ecspresso rollback` が成功すればジョブは緑になり、③ の出力にも ECS のタスク定義だけが出る。
  つまり `target=service+agent` で起動しても **SSM の Agent ID / Environment ID は前バージョンへ戻らず、
  ジョブは「ロールバック完了」として終わる**。
- **同じ雛形の中に反例がある**: `deploy.yml:333`-`:339` は `check-tool-contract.sh` が無ければ
  `::error` + `exit 1` で落とす (「未実装なら CI が落ちる」= 本リポの雛形の既定方針。
  `aidlc-docs/reviews/productionization/review-layering.md:266` でも同方針が確認されている)。
  **最も安全側に倒すべきロールバック経路だけがこの方針から外れている**。
- **なぜ本番で問題になるか**: `operations.md` §5.3 は Agent の切り戻しを「SSM を戻す → タスク置換」と定義し、
  §6.4 の切り戻し判断基準や RL-1 完了条件 ④ (dev で 1 回実行して戻ることを確認) がこの workflow に依存する。
  ①が no-op のまま「戻った」と報告されると、**新 tool schema の Agent + 旧コード**という
  BE-8 / BE-10 の窓が、障害対応の直後に (誰も気付かない形で) 開いたまま残る。
  これは設計自身が OP-B 却下案 (d) で避けたはずの状態そのものである。
- **修正案**: ① を「実装が無ければ失敗する」形にする。例: `scripts/rollback-agent.sh` の存在を前提にし、
  無ければ `::error` + `exit 1`。加えて **`target=service+agent` のときは①の成功を②の前提条件にする**
  (`set -e` の下で実装スクリプトを呼ぶ)。合わせて③の出力に **SSM の現在値と戻したバージョン番号**を含める
  (現状は ECS の状態のみで、①の結果が観測できない)。

#### 新規 中 1. `rollback.yml` の SSM パスが SSOT と食い違う (Environment ID の切り戻しが空振りする)

- 該当: `rollback.yml:90`-`:93` — コメントで「SSM のパス階層は operations.md §3.3 の⑤ / §9 が SSOT」と
  宣言した直後に `/hassan-v3/<env>/agent/<name>/environment-id` と書いている。
- **正**: `operations.md` OP-E (`:56`) / §3.3 の⑤ (`:121`) / §5.2 (`:298`) / §5.2 の暫定既定 (`:335`-`:336`) /
  §9 infra 1 (`:694`) / `deploy.yml:399` はすべて **`/hassan-v3/<env>/anthropic/environment-id`**。
- **なぜ本番で問題になるか**: `infrastructure.md` INF-I は `ssm:PutParameter` を
  `/hassan-v3/<env>/agent/*` と `.../anthropic/environment-id` に許可しているため、
  **誤ったパスへの書き込みは IAM でも弾かれず成功する**。アプリが読むのは別パスなので、
  Environment ID の切り戻しだけが静かに効かない (§5.3 が「Environment を変更していた場合は
  Environment ID も同じ手順で戻す」と要求しているのに、実体が別の場所を触る)。
- **修正案**: `rollback.yml` のパスを `/hassan-v3/<env>/anthropic/environment-id` に直す
  (Agent 名に紐づかない 1 本のパラメータであることをコメントにも書く)。

#### 新規 中 2. 是正済みの事項が「未整備 / 未是正 / 定義が無い」と書かれたまま残っている (4 箇所)

修正は行われたのに**本文が旧状態を主張している**ため、読者が引き渡し物の状態を誤認する。
`§10.2` 末尾の追記 (`:778`-`:782`) だけが解消を伝えており、本文と矛盾している。

| # | 箇所 | 現在の記述 | 事実 |
|---|---|---|---|
| a | `docs/design/operations.md:171`-`:173` | 「04 §2.6 の H-3 行の二重化列 … **本節と矛盾したまま残っている**」 | 04 §2.6 は `:200` で是正済み |
| b | `docs/design/operations.md:480`,`:483`-`:484` | 「**このメトリクスは現時点で observability.md に定義が無い**」「同書への追記が済むまでの暫定値」 | `observability.md` §4.4.1 に定義済み |
| c | `docs/design/operations.md:720`-`:721`,`:741` | 引き渡し 7「**雛形は `templates/` に無いため、実装リポで新規に作る**」/ 雛形是正表「`rollback.yml` の雛形 = **未整備 (要求)**」 | `templates/backend-repo/.github/workflows/rollback.yml` は作成済み |
| d | `docs/design/infrastructure.md:258` | 「(**雛形は未整備** = 同 §10.2 の OP-F4)」 | 同上 |

修正案: a〜d を「是正済み (2026-07-30)」に書き換える。b は下記 中 3 と同時に処理する。

#### 新規 中 3. SSE 接続数メトリクスが 2 文書で二重定義になった (SSOT 規約違反)

- `docs/design/operations.md:483`-`:492` の暫定定義表 (名前 / 単位 / 次元 / 出力元 / 出力間隔) と
  `docs/design/observability.md` §4.4.1 が**同じ 5 項目を別々に持っている**。
  ルート `CLAUDE.md` の「同じ事実を 2 箇所に書かない」に反し、
  次元の記述も微妙に違う (operations = 「環境 / タスク ID。確認では全タスクの合計を見る」/
  observability = 「環境・ECS タスク単位。合計はダッシュボード側で集約」)。
- **なぜ問題か**: しきい値や出力間隔を変えるときに片方だけが直る (BE-2 の再演)。
  operations.md 自身が「計測項目の SSOT は observability.md」と宣言しているので、
  暫定定義は役目を終えている。
- 修正案: `operations.md` §6.3 の表を削除し、`observability.md` §4.4.1 への参照 1 行に置き換える。

#### 新規 中 4. `rollback.yml` が要求する IAM 権限が引き渡し (infra) に入っていない

- `rollback.yml:73`-`:75` が要求するのは `ecs:UpdateService` / `ecs:DescribeServices` /
  `ecs:RegisterTaskDefinition` / `ecs:DescribeTaskDefinition` / **`ssm:GetParameter` /
  `ssm:GetParameterHistory`** / `ssm:PutParameter` / `iam:PassRole`。
- 一方 `infrastructure.md` INF-I (`:97`) の `deploy` ロールは「ECR push + ecspresso」+
  `secretsmanager:GetSecretValue` + `ssm:PutParameter` で、**`ssm:GetParameterHistory` が無い**。
  `operations.md` §9 infra 3 も `apply_agent` 用の 2 権限しか挙げていない。
- **なぜ本番で問題になるか**: 切り戻しは**障害対応中に初めて実行される**ことが多く、
  そこで `AccessDenied` になると「第一手段が使えない」に直結する。RL-1 完了条件 ④ (dev で 1 回実行) で
  検出はできるが、**権限の要求が引き渡しに書かれていなければ dev でも失敗する**。
- 修正案: INF-I の `deploy` ロール (またはロールバック用 4 本目のロール) に
  `ssm:GetParameter` / `ssm:GetParameterHistory` と `ecs:UpdateService` 系を明記し、
  `operations.md` §9 infra 3 にも 1 行追加する。

#### 新規 中 5. 「置いてよい値」の限定列挙が 04 §4.2 と一致しない (重大 4 の残り)

- `operations.md` §4.1 の列挙は **①IAM ロール ARN ②リージョン / ECR リポジトリ名 / ECS クラスタ名 /
  ecspresso 設定パス** の 2 行。
- `04-human-checkpoints.md:317`-`:323` は列名を「保持する値 (**この 4 種以外を置かない**)」としつつ、
  `prod-db` 行に「クラスタ名・**タスク定義名・ロググループ名**」を挙げている。
  **タスク定義名 / ロググループ名は §4.1 の列挙に無い**。また「4 種」が何と何を指すかが
  どちらの文書からも一意に決まらない (§4.1 は 2 行 5 品目、04 は行ごとに品目が違う)。
- **なぜ問題か**: 04 が実装リポの立ち上げチェックリスト (§4.5 で機械確認する対象) であるため、
  「置いてよい値」の集合が曖昧なままだと、**運用者が判断できずに元の運用 (何でも secret に入れる) へ戻る**。
  `deploy.yml` は現状これらを `<プレースホルダ>` としてワークフロー内に直書きしており、
  3 者目の実体としても一致していない。
- 修正案: §4.1 の列挙を「**AWS ロールを引き受けるための情報 + デプロイ先の識別子 (リージョン /
  ECR / クラスタ / タスク定義 / ロググループ / subnet / SG / ecspresso 設定パス)**」のように
  品目を確定し、04 §4.2 の「4 種」を同じ語で書き直す (数を書くなら列挙と一致させる)。

#### 新規 中 6. `rollback.yml` の②失敗時に残る危険な状態が、運用者に伝わる形で出力されない

- `rollback.yml:108`-`:111` のコメントは「② が失敗した場合は①の書き戻しだけが適用された状態になる」と
  正しく認識しているが、**実際の出力 (③) は ECS の状態のみ**で、SSM が旧 Agent を指したまま
  タスクが新コードのままという状態は読み取れない。
- この状態が危険なのは、**その後の任意のタスク再起動 (障害・スケール・次のデプロイ) で
  「旧 Agent ID + 新コード」が起動する**点で、§3.3 の④を却下した理由 (OP-B の (d)) と同じ事故が
  時間差で発生する。
- 修正案: ③ または ④ に「**② が失敗した場合の必須アクション**」を出す
  (SSM を元に戻して前進修正する / タスクを起動させずに再実行する のどちらかを選ばせる)。
  現在値の出力 (新規 重大 1 の修正案) と対で実装する。

#### 新規 軽微

1. `deploy.yml:459` が出力する起動コマンド `gh workflow run rollback.yml -f environment=… -f target=service` は、
   `rollback.yml` の **`reason` (required: true)** を欠くため**そのままでは実行できない**。
   障害時にコピー&ペーストされる文字列なので `-f reason="<障害の症状>"` を含める。
2. `templates/shared/.claude/rules/04-human-checkpoints.md:150` の `plan_agent` の説明が
   「prompt / tool schema のハッシュを前回発行時の記録と比較」のままで、**`prompts/agents.yaml` の列挙が
   基準であること (中 2 の決定) が反映されていない**。実装リポは 04 を承認機構の SSOT として読むため、
   ここだけを読むと `prompts/` 全体を対象と誤読し得る。
3. `docs/design/observability.md` の §5 の O-7 行が「§4.6 の **AL-1〜AL-6**」と書いており、
   AL-7 (レート制限のスパイク) が漏れている (1 巡目以前からの既存の表記漏れ。
   §4.6 の表と `operations.md` §7.5 は AL-7 を含む)。
4. `rollback.yml:105` は `stacks/${{ inputs.environment }}/ecspresso.yml` を直接書いているが、
   `deploy.yml:447` は `<stacks/${ENV_NAME}/ecspresso.yml>` とプレースホルダ扱い。
   同じ値の扱いを 2 つの雛形で揃えると、埋め忘れの検出が容易になる。

---

### 3. 回帰の検査 (修正が新たな矛盾を作っていないか)

| 検査項目 | 結果 |
|---|---|
| `observability.md` §4.4.1 が §4.3 F-5 (SSE 異常終了) / §4.4 (keep-alive 15 秒) と重複していないか | **重複なし**。F-5 = 失敗の検知 / keep-alive = 打ち切りではない送出パラメータ / §4.4.1 = ゲージ計測項目で、3 者の役割が分かれている。出力間隔 30 秒が keep-alive 15 秒の 2 倍という関係も両文書で一致 |
| `operations.md` §7.5 を一次決定にしたことで observability §4.6 と競合していないか | **競合なし**。§4.6 は「監視対象としきい値」、§7.5 は「重大度・環境差・トピック本数」で、双方が冒頭で境界を宣言している |
| 分類 ⑤ の新設が §3.3 / §4.1 / §4.5 / §9 / `infrastructure.md` §3.4 で一貫しているか | **一貫**。④ と ⑤ の混在箇所 (`infrastructure.md:161`) も「④・⑤」と両方を指しており誤りではない |
| 新設の SSOT が二重定義になっていないか | **1 件違反** → 新規 中 3 (SSE メトリクス) |
| 是正後の文書が旧状態を主張していないか | **4 件違反** → 新規 中 2 |
| `deploy.yml` の承認位置 (H-2 / H-3 / H-4) と `needs` 連鎖が保たれているか | **保たれている** (YAML パースで environment 指定を確認。`release` の `if` は「スキップは許容・失敗は不許容」を維持) |
| `rollback.yml` の `concurrency` が `deploy.yml` と同じグループか | **一致** (`deploy-<env>`)。デプロイとロールバックの同時実行を防げている |

### 4. construction-workflow (Design Freeze 済み feature) への影響

| AC | 判定 | 根拠 |
|---|---|---|
| **AC-4.1** (人間の判断ポイントの一覧と確認観点・承認機構) | **壊れていない** | H-1〜H-5 の一覧・確認観点・機構 (§1.1 / §2.6) は不変。是正は §2.6 の「二重化」列 1 セルと §4.2 の「保持する値」列のみで、**承認点・承認者・回避可能性の列は無変更** |
| **AC-4.2** (マイグレーション / Agent 再発行 / 本番デプロイの承認が機構で担保) | **壊れていない** | environment 5 つ・required reviewers・Deployment branches の要求 (§4.2 のチェックリスト) は無変更。`deploy.yml` の承認位置も 3 箇所とも維持 (YAML で確認) |
| **AC-6.2** (D-4 / D-6 の人間承認がループに埋め込まれている) | **壊れていない** | 04 §2.2 / §2.3 の承認先と適用順序は不変。`apply_migration` の実行場所が RunTask に変わったが、**承認が挟まる位置 (environment ゲート) は同じジョブのまま** |
| (付帯) | **軽微な stale 1 件** | `aidlc-docs/inception/construction-workflow/requirements.md:155` が本増分の成果を「D-5 (**environment secret 経由の受け渡し**) にも機構面で回答している」と記述しており、是正後の設計 (GitHub 側に秘密を置かない) と食い違う。AC 自体には影響しないが、Freeze 済み文書の付記として直すべき |

### 5. 判定 (Freeze 可否)

| スコープ | 判定 |
|---|---|
| `docs/design/operations.md` / `docs/design/infrastructure.md` | **重大ゼロ**。新規 中 2 / 中 3 / 中 5 (と 中 4 の infra 側 1 行) を反映すれば **Freeze 可**。中 2・中 3 は「文書が自分の是正結果を否定している」種類の事実誤りで、**1 コミットで閉じる**。再レビューは軽量 (`model: sonnet`) で足る |
| `templates/backend-repo/.github/workflows/rollback.yml` | **Freeze 不可 (新規 重大 1)**。新規 中 1 / 中 6 も同ファイルで同時に直す。**ロールバックが「成功したのに戻っていない」形で壊れる**のは、この設計が最も避けたい種類の障害である |
| `templates/backend-repo/.github/workflows/deploy.yml` / `templates/shared/.claude/rules/04-human-checkpoints.md` / `docs/design/observability.md` | **重大ゼロ**。軽微 1 / 軽微 2 / 軽微 3 と 中 5 (04 側) の反映を推奨。Freeze の阻害要因ではない |

feature `productionization` 全体の Freeze は、本レビュー範囲外の設計成果物
(`llm-migration.md` — [review-llm-migration.md](review-llm-migration.md) / 未着手の `data-model.md`) に依存する。

### 6. 良かった点 (2 巡目)

1. **18 件を「反映した」で終わらせず、判定基準を明文化して再発を止めている**。
   特に §3.3 の「④ に置いてよい値の判定基準」(旧コードが旧い値で動き続けても壊れないこと) は、
   指摘された 1 件を直すのではなく**同種の誤配置を将来も防ぐ形**になっている。
2. **`deploy.yml` の `apply_migration` が「②で失敗させず判定を④に集約する」**構造になっている点。
   ログ取得 (③) をタイムアウト時にも必ず通すための設計で、
   RunTask 方式の唯一の弱点 (失敗理由が読めない) を正面から潰している。
3. **RL-1 ③ を ③-a / ③-b に割ったこと**。「dev で全アラートを試験」という実行不能な条件を
   「アラーム状態遷移は全件 / 通知の到達は 1 本」に分解し、RL-2 に prod 経路の到達試験を足したのは、
   指摘の趣旨 (本番で初めて使う経路を作らない) を正確に実装している。
4. **`rollback.yml` が①→②の順序と「②が失敗したときに①だけが適用された状態になる」ことを
   自ら書いている**。出力が足りていない (中 6) だけで、危険の所在の認識は正しい。
5. **`infrastructure.md` §9.2 が F-11 から「実質のレバーは FE の 1 レコードだけ」を導いた**こと。
   実測事実を手順の前提条件として書き直しており、DNS 切り戻しという幻の手段を消している。


---

## 2 巡目指摘の反映 (2026-07-30・メインセッション)

| 指摘 | 反映先 |
|---|---|
| **重大 (新規): `rollback.yml` の Agent 切り戻しが未実装でも exit 0** | `templates/backend-repo/.github/workflows/rollback.yml` の ① を `scripts/rollback-agent.sh` の実行に変え、**未実装なら `exit 1`** (deploy.yml の 3 者一致検査と同じ扱い)。要求動作をエラーメッセージに明記し、`target=service` での再実行を案内 |
| 中 1: SSM パスの不一致 | 同ファイルのコメントとエラーメッセージを **`/hassan-v3/<env>/anthropic/environment-id`** (環境単位) に統一。3 パスの一覧をコメントに固定 |
| 中 2: stale 4 箇所 | `operations.md` の 04 §2.6 / SSE メトリクス / `rollback.yml` 雛形の 3 箇所、`infrastructure.md` §4.4 の 1 箇所を是正済みの記述へ差し替え |
| 中 3: SSE 接続数の二重定義 | `operations.md` §6.3 の暫定定義表を削除し、**observability.md §4.4.1 への参照 + 「リリース判断での使い方」だけを残す**形に変更 |
| 中 4: `rollback.yml` の IAM 権限が引き渡しに無い | 同ファイルの AWS 認証ステップのコメントに要求権限を列挙 (`ssm:GetParameterHistory` / `ssm:PutParameter` / `ecs:UpdateService` 等)。`operations.md` §10.2 の OP-F4 行に雛形作成済みと `scripts/rollback-agent.sh` の要求を記載 |
| 中 5: 04 §4.2 の値と §4.1 の列挙の不一致 | `04-human-checkpoints.md` §4.2 の見出しを「IAM ロール ARN と非秘密の識別子のみ」に変更し、`prod-db` 行に RunTask の宛先 (サブネット / SG / タスク定義名 / ロググループ名) を明記。§4.5 の「4 種」表現も修正 |
| 中 6: ② 失敗時の危険状態が出力されない | `rollback.yml` に **ステップ ②' を新設** (`failure() && target == 'service+agent'`)。「SSM は旧値・稼働タスクは新 Agent」の中途状態と、次にタスクが起動した時点で切り替わること、対応の選択肢 2 つをジョブサマリと `::error::` に出す |
| 付帯: construction-workflow requirements の D-5 stale | `aidlc-docs/inception/construction-workflow/requirements.md` §5 の D-5 記述を「GitHub 側に置かず OIDC 経由で取得する形」に是正 |
| 軽微 4 件 | (別途対応。Freeze の阻害要因ではない) |

検証: `make doc-lint` エラー 0 / `make check-traceability` construction-workflow 24/24・productionization 46/46 /
`rollback.yml` の YAML パース OK (1 ジョブ 9 ステップ)。

**追加修正 (2026-07-30・3 巡目レビュー起動後にオーケストレーターが自己検出)**:
`rollback.yml` の ②' の条件が `failure() && target == 'service+agent'` だったため、
**① 自身が失敗した場合にも発火し「①は成功した」という誤った文言を出す**状態だった
(`failure()` は直前までのどのステップの失敗でも true になる)。
① に `id: revert_ssm` / ② に `id: ecspresso_rollback` を付与し、条件を
`always() && steps.revert_ssm.outcome == 'success' && steps.ecspresso_rollback.outcome == 'failure'`
に限定した (① 失敗時は SSM が戻っていないため「中途状態」ではなく「何も変わっていない」状態であり、
別の扱いが必要 = ジョブが ① の `exit 1` で落ちて止まるのが正しい)。

---

## 3 巡目 (確認・2026-07-30)

> レビュアー: `design-reviewer` (別セッション)。**1 巡目・2 巡目の記述と「反映」節は改変していない**。
> 範囲を **2 巡目指摘の解消判定 + 回帰検査**に限定した確認レビュー (新規の網羅レビューではない)。

### 対象 (レビューした成果物・リポジトリ相対パス)

| パス | 見た範囲 |
|---|---|
| `templates/backend-repo/.github/workflows/rollback.yml` | 全文 (184 行。①/②/②'/③/④ の条件と本文) |
| `templates/backend-repo/.github/workflows/deploy.yml` | 失敗時ステップ (`:447`-`:461`) + YAML パース |
| `templates/shared/.claude/rules/04-human-checkpoints.md` | §2.3 (`:141`-`:160`) / §2.6 (`:197`-`:203`) / §4.2 (`:313`-`:342`) |
| `docs/design/operations.md` | §3.3 / §4.1 / §5.3 / §6.3 / §9 (引き渡し・雛形是正表) / §10.2 |
| `docs/design/infrastructure.md` | INF-I (`:97`) / §4.4 (`:258`) |
| `docs/design/observability.md` | §4.2 / §4.4.1 / §4.6 / §5 の O-5・O-7 行 / §6.1 の ⑧ |
| `aidlc-docs/inception/construction-workflow/requirements.md` | §5 の D-5 行 (`:155`) + AC-4.1 / AC-4.2 / AC-6.2 |

**照合のために読んだ (レビュー対象外)**: `claude_managed_agents/internal/agent/diverge/plan.go` ·
`schema.go` · `cmd/devui/idea_plan.go` ほか (llm-migration 側の照合と共用)。

### 実行した検証

```
$ make doc-lint
[doc-lint] 対象 79 ファイル / エラー 0 件 / 警告 33 件
  (本 2 文書由来は意図的な未回答 [Answer]: のみ — operations.md 3 件 (:345 / :619 / :660) /
   infrastructure.md 4 件 (:519 / :527 / :534 / :540)。増分は llm-migration.md の 6 件 (LM-Q6 追加) と
   review 文書・ルール文書の「TODO」語への反応)

$ make check-traceability
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 46/46 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature

$ ruby -ryaml (YAML パース)
deploy.yml:   OK jobs=build,plan_migration,apply_migration,plan_agent,apply_agent,release
              apply_migration env=${{ needs.plan_migration.outputs.approval_env }} / steps=7
              apply_agent     env=${{ needs.plan_agent.outputs.approval_env }}     / steps=4
              release         env=${{ ... 'prod' || 'dev' }}                        / steps=5
rollback.yml: OK jobs=rollback / steps=9 / environment=${{ inputs.environment }}
              [4] ① if=inputs.target == 'service+agent'                (id=revert_ssm)
              [5] ②  if=なし                                           (id=ecspresso_rollback)
              [6] ②' if=always() && target=='service+agent' && revert_ssm.outcome=='success'
                                                        && ecspresso_rollback.outcome=='failure'
              [7] ③ if=always() / [8] ④ if=always()

$ bash -n -c 'for NAME in <対象 Agent 名の一覧 (prompts/agents.yaml の列挙)>; do echo $NAME; done'
syntax error near unexpected token `<'      ← 新規 軽微 1 の根拠
```

**抜き取り照合: 本節で 10 件** (llm-migration 側の 7 件と合わせて計 17 件)。
**対象外にした範囲**: AWS / Anthropic の実 API 挙動 (SSM 版履歴・Environment の複数保持) /
`infrastructure.md` §3 の 40 要素の値の妥当性 / 1 巡目・2 巡目で照合済みの事実の再照合。

> **レビュー中に対象ファイルが更新された**: `rollback.yml` を最初に読んだ時点の ②' は
> `if: failure() && inputs.target == 'service+agent'` (① 失敗時にも発火する形) だったが、
> 2026-07-30 08:06 の更新で `steps.revert_ssm.outcome == 'success' && steps.ecspresso_rollback.outcome == 'failure'`
> に修正されている。**判定は最終状態 (08:06 版) に対して行った**。

### 1. 2 巡目指摘 (重大 1 / 中 6 / 軽微 4 = 11 件) の解消判定

| ID | 判定 | 確認した実体 |
|---|---|---|
| **重大 1** Agent 切り戻しが未実装でも成功扱い | **解消** | `rollback.yml:97`-`:109` が `scripts/rollback-agent.sh` を `set -euo pipefail` 下で実行し、無ければ `::error::` + **`exit 1`**。エラーメッセージに要求動作 (agents.yaml の列挙ごとに `get-parameter-history` の直前バージョンへ `put-parameter`) と `target=service` での再実行案内。①失敗時に② はスキップされる (`if` 無しのため既定で先行失敗時は実行されない) ので「戻っていないのに緑」は成立しない。③ に SSM 現在値と `version` の出力 (`:157`-`:171`) が入り、①の結果が観測可能になった |
| **中 1** SSM パスの不一致 | **解消** | `rollback.yml:88`-`:91` が 3 パスを SSOT として固定 (`/hassan-v3/<env>/agent/<name>/id` / `/hassan-v3/<env>/anthropic/environment-id` (**環境単位**と明記) / `.../source-hash`)。`:104`-`:105` のエラー文言と `:163`・`:167` の実コマンドも同一。`operations.md` §3.3 の⑤ (`:121`) / `deploy.yml` と一致 |
| **中 2** 是正済み事項が旧状態のまま (4 箇所) | **部分解消** → **新規 中 1** | 指摘した 4 箇所 (a: §4.1 の 04 §2.6 言及 / b: §6.3 / c: 引き渡し 7・雛形是正表 / d: `infrastructure.md:258`) のうち **a・b・d は解消**。**c は §9 の 3 箇所が旧状態のまま**: 引き渡し 7 (`:713`-`:714`)「**雛形は `templates/` に無いため、実装リポで新規に作る**」/ 引き渡し 9 (`:716`-`:717`)「§6.3 に暫定定義。同書への追記は §10.2 の先送り表で**要求している**」/ 雛形是正表 (`:733`)「同 §2.6 の H-3 行『二重化』列 = **未是正 (要求)**」 |
| **中 3** SSE 接続数の二重定義 | **解消** | `operations.md:477`-`:485` の定義表 (名前 / 単位 / 次元 / 出力元 / 出力間隔) が削除され、**「リリース判断での使い方」と「判断基準を持たない運用の禁止」の 2 行だけ**になった。`observability.md` §4.4.1 が SSOT である旨を §6.3 の 2 箇所 (`:474` / `:477`) で宣言。残る値の再掲は軽微 (新規 軽微 3) |
| **中 4** rollback の IAM 権限が引き渡しに無い | **部分解消** → **新規 中 2** | `rollback.yml:73`-`:75` のコメントに要求権限が列挙された (雛形側)。しかし**権限を実際に作る側**が未更新: `infrastructure.md:97` の INF-I は `deploy` ロールに `secretsmanager:GetSecretValue` + **`ssm:PutParameter` のみ**、`operations.md:690`-`:694` (§9 infra 3) も同じ 2 権限で、**`ssm:GetParameter` / `ssm:GetParameterHistory` がどちらにも無い** |
| **中 5** 「置いてよい値」の列挙不一致 | **解消** | 04 §4.2 (`:318`) の列名が「保持する値 (**IAM ロール ARN と非秘密の識別子のみ。下記以外を置かない**)」になり「4 種」の数え上げが消えた。`prod-db` 行 (`:322`) に RunTask の宛先 (クラスタ名 / タスク定義名 / ロググループ名 / サブネット ID / SG ID) が明記され、`operations.md:706` の引き渡し 4 の列挙と一致。§4.5 (`:340`) も「上表の値 (IAM ロール ARN と非秘密の識別子)」に修正 |
| **中 6** ② 失敗時の危険状態が出力されない | **解消** | `rollback.yml:123`-`:141` に ②' を新設。中途状態の内容 (稼働タスクは起動時に読んだ新 Agent を保持 / SSM だけ旧値 / **次のタスク起動時に切り替わる**) と対応の選択肢 2 つをジョブサマリ + `::error::` に出す。発火条件が「①成功 かつ ②失敗」に限定されており、**① 失敗時に誤った文言を出す穴も塞がっている** (`:120`-`:122` に理由をコメント) |
| **軽微 1** 起動コマンドに `reason` が無い | **解消** | `deploy.yml:459` = `gh workflow run rollback.yml -f environment=${ENV_NAME} -f target=service -f reason="<障害の症状を 1 行で>"` |
| **軽微 2** 04 §2.3 の `plan_agent` 基準 | **解消** | 04 `:150`-`:151`「**`prompts/agents.yaml` が列挙した集合のハッシュ**を `/hassan-v3/<env>/agent/<name>/source-hash` と比較」+「**`prompts/` 全体ではない**」+ 一致検査は `check-tool-contract.sh` |
| **軽微 3** observability §5 の O-7 行が AL-6 まで | **解消** | `observability.md:281`「§4.6 の AL-1〜**AL-7**」+「AL-4 のみ ⑦、残る 6 件は初期実装 (⑧)」 |
| **軽微 4** ecspresso 設定パスの表記 | **解消** | `rollback.yml:117` が `<stacks>/${{ inputs.environment }}/ecspresso.yml` とプレースホルダ表記になった (置換対象であることが grep で拾える)。括り方の差は新規 軽微 4 |

**解消 9 / 部分解消 2 (中 2・中 4) / 未解消 0**。取りこぼしは無く、部分解消の 2 件はいずれも
「**雛形は直ったが、それを支える設計文書側が追随していない**」型である。

### 2. 回帰検査

| 検査項目 | 結果 |
|---|---|
| `rollback.yml` の ①→②→②'→③ の順序と `if` に穴が無いか | **穴なし**。① は `target=='service+agent'` のみ。② は無条件だが**先行失敗でスキップ**される。②' は `always()` + ①成功 + ②失敗の 3 条件で、**① 失敗時に「①は成功し」と誤報する経路が消えた**。③④ は `always()` で必ず出る |
| ① が失敗した場合に運用者が状態を判断できるか | **できる** (①自身の `::error::` が「実行できていない」ことと `target=service` での再実行を案内、③ が SSM 現在値と `version` を出す)。ただし**スクリプトが途中まで書き込んで失敗した場合**を明示するステップは無い → 新規 軽微 2 |
| `concurrency` が `deploy.yml` と同一グループか | **一致** (`deploy-${{ inputs.environment }}`。`cancel-in-progress: false`) |
| `rollback.yml` の SSM 3 パスが `operations.md` §3.3 の⑤ / `deploy.yml` と一致するか | **一致** (中 1 の欄) |
| `04-human-checkpoints.md` の変更が AC-4.1 / AC-4.2 / AC-6.2 を壊していないか | **壊れていない**。AC-4.1 (承認点の一覧・確認観点・機構) は §1.1 / §2.6 が無変更 (§2.6 は H-3 行の「二重化」列 1 セルのみ是正)。AC-4.2 は environment 5 つ・required reviewers・Deployment branches の要求 (`:337`-`:339`) が無変更で、変更は「保持する値」列と §4.5 の文言のみ。AC-6.2 は §2.2 / §2.3 の**承認先 (`prod-agent`) と適用順序が不変**で、変わったのは `apply_agent` をスキップ判定する**ハッシュの入力集合**のみ (承認機構ではない)。`make check-traceability` も 24/24 |
| 新設の SSOT が二重定義を作っていないか | **新規の二重定義なし** (中 3 で 1 件解消)。`operations.md` §6.3 に値の再掲が 1 箇所残るのみ (新規 軽微 3) |
| 是正後の文書が旧状態を主張していないか | **3 件違反** → 新規 中 1 (§9 に集中している) |
| 権限・引き渡しの整合 | **1 件不足** → 新規 中 2 (`ssm:GetParameter` / `GetParameterHistory`) |

### 3. 新規指摘

#### 新規 中 1. `operations.md` §9 (引き渡し) の 3 箇所が旧状態を主張している

- 該当: `docs/design/operations.md:713`-`:714` (backend 引き渡し 7) / `:716`-`:717` (同 9) / `:733` (§9 の雛形是正表)
- **事実**: §4.1 (`:171`-`:172`)・§6.3 (`:474`)・§10.2 末尾 (`:771`-`:775`)・`infrastructure.md:258` は
  いずれも「是正済み / 作成済み (OP-F1〜F4 解消)」と書いているのに、**§9 だけが**
  「雛形は `templates/` に無いため、実装リポで新規に作る」「(SSE メトリクスの) 追記は §10.2 の先送り表で要求している」
  「04 §2.6 の H-3 行は未是正 (要求)」と書いている。同じ文書内で矛盾している。
- **なぜ本番で問題になるか**: §9 は「**実装リポへの引き渡し**」節であり、実装リポが最初に読む指示である。
  引き渡し 7 を字義通りに読むと **`rollback.yml` を雛形から使わず新規に書き起こす** — 2 巡目で潰した
  「未実装でも exit 0」「SSM パスの取り違え」「②' の中途状態の明示」がすべて再発し得る
  (この 3 つは雛形の中にしか無い)。中 2 (2 巡目) と同型の再発であり、今回は**引き渡し点で起きている**ため
  影響が大きい。
- **修正案**: 引き渡し 7 を「雛形 `templates/backend-repo/.github/workflows/rollback.yml` をコピーし、
  プレースホルダと `scripts/rollback-agent.sh` を実装する」に差し替える。引き渡し 9 を
  「定義は `observability.md` §4.4.1 (追記済み)」に、雛形是正表の 04 §2.6 行を「是正済み」に直す。

#### 新規 中 2. ロールバックに必要な SSM 読み取り権限が IaC 側の設計に無い (2 巡目 中 4 の核心)

- 該当: `docs/design/infrastructure.md:97` (INF-I) / `docs/design/operations.md:690`-`:694` (§9 infra 3)
- **事実**: `rollback.yml` の ① は `scripts/rollback-agent.sh` に
  「`get-parameter-history` の直前バージョンを読んで `put-parameter` する」ことを要求している
  (`rollback.yml:104`-`:106`)。一方 INF-I の `deploy` ロールに与える SSM 権限は **`ssm:PutParameter` のみ**、
  §9 infra 3 も同じ 2 権限しか列挙していない。**`ssm:GetParameter` / `ssm:GetParameterHistory` が無い**。
- **なぜ本番で問題になるか**: 書き込みだけ許可されているため、**旧値を読めずに ① が `AccessDenied` で失敗する**。
  失敗は loud (exit 1) なので誤って緑になることは無いが、**切り戻しは障害対応中に初めて実行される**ため
  「第一手段が実行不能」に直結する。RL-1 完了条件 ④ (dev で 1 回実行) で検出できるが、
  **権限が設計に書かれていなければ dev でも同じく失敗する**ので、検出は「引き渡し漏れの発覚」でしかない。
- **修正案**: INF-I の `deploy` ロール (またはロールバック専用の 4 本目) に
  `ssm:GetParameter` / `ssm:GetParameterHistory` (`/hassan-v3/<env>/agent/*` と `.../anthropic/environment-id`) を
  明記し、`operations.md` §9 infra 3 にも同じ 1 行を足す。**ecspresso 側の `ecs:UpdateService` /
  `ecs:RegisterTaskDefinition` は既存の「`deploy` 用 (ECR push + ecspresso)」に含まれる**と読めるので、
  こちらは表現の明示で足りる。

#### 新規 軽微

1. **`rollback.yml:161` の `for NAME in <対象 Agent 名の一覧 (prompts/agents.yaml の列挙)>;` は
   bash の構文エラーになる** (`bash -n` で確認済み。`<` がリダイレクトとして解釈される)。
   プレースホルダの置換を忘れると **③ のステップ全体が失敗し、ECS の状態出力 (`always()` で必ず出すはずのもの) まで失われる**。
   `AGENT_NAMES="<対象 Agent 名の一覧>"` を変数に置いて `for NAME in ${AGENT_NAMES:?未設定}` とすれば、
   置換漏れが「未設定」という読めるエラーになる。
2. **① がスクリプト実行中に途中失敗した場合** (一部のパラメータだけ書き戻された状態) を明示するステップが無い。
   ②' は「①成功 かつ ②失敗」に限定されているため発火せず、③ の SSM 現在値から人間が読み取ることになる。
   ②' と同じ文面を `revert_ssm.outcome == 'failure'` 用に 1 つ足すか、③ に「①が失敗した場合は
   `version` を見て一部だけ戻っていないか確認する」の 1 行を足すと閉じる。
3. `operations.md:477` の見出しが「**アクティブな SSE 接続数メトリクスの暫定定義**」のままで、
   直後の括弧に値 (名前 / ゲージ / EMF / 30 秒) が再掲されている (`:474` にも同じ 4 値がある)。
   中 3 の趣旨 (値は `observability.md` §4.4.1 のみが持つ) に合わせ、見出しを
   「SSE 接続数メトリクスの使い方 (定義は observability.md §4.4.1)」にし、値の再掲を 1 箇所に減らす。
4. ecspresso 設定パスのプレースホルダの括り方が 2 雛形で違う
   (`deploy.yml:447` = `<stacks/${ENV_NAME}/ecspresso.yml>` / `rollback.yml:117` = `<stacks>/${{ inputs.environment }}/ecspresso.yml`)。
   どちらも置換対象と分かるので実害は無いが、揃えると置換漏れの検出 (`grep '<'`) が単純になる。

### 4. Freeze 可否 (3 巡目)

| スコープ | 判定 |
|---|---|
| `docs/design/operations.md` / `docs/design/infrastructure.md` | **重大ゼロ**。**新規 中 1 / 中 2 を反映すれば Freeze 可**。どちらも文書 3〜4 行の修正で閉じ、設計判断の変更を伴わない (再レビューは軽量 = `model: sonnet` で足る) |
| `templates/backend-repo/.github/workflows/rollback.yml` · `deploy.yml` | **Freeze 可** (2 巡目の重大 1・中 1・中 6 はすべて解消)。新規 軽微 1 / 2 / 4 の反映を推奨 |
| `templates/shared/.claude/rules/04-human-checkpoints.md` | **Freeze 可**。construction-workflow の AC-4.1 / AC-4.2 / AC-6.2 は無傷 |
| `docs/design/observability.md` | **重大ゼロ**。ただし `llm-migration` 側の指摘 (`external_search` の必須フィールドと検索単価) が残る — [review-llm-migration.md](review-llm-migration.md) の 3 巡目を参照 |
| `aidlc-docs/inception/construction-workflow/requirements.md` | **Freeze 可** (§5 の D-5 記述が OIDC + Secrets Manager 方式に是正済み。`:155`) |

feature `productionization` 全体の Freeze は未着手の `docs/design/data-model.md` に依存する (本レビューの範囲外)。


## 3 巡目指摘の反映 (2026-07-30・メインセッション)

| 指摘 | 反映先 |
|---|---|
| **中 1: 引き渡し節が旧状態を主張 (3 件)** | `operations.md` §9 の引き渡し 7 を「**雛形は作成済み。新規に書き直さずコピーして使う**」に変更し、**再実装で失われる安全機構 3 点** (未実装なら `exit 1` / 中途状態だけを警告する `②'` / SSM 現在値とバージョンの出力) を明記。引き渡し 9 は observability.md §4.4.1 を SSOT とする形へ。§9 の是正表の「同 §2.6 の H-3 行」を **是正済み** に更新 |
| **中 2: SSM 読み取り権限の欠落** | `infrastructure.md` INF-I の `deploy` ロールに **`ssm:GetParameter` + `ssm:GetParameterHistory`** を追加 (`/hassan-v3/<env>/agent/*` と `.../anthropic/environment-id`)。`operations.md` §9 infra 1 にも同じ要求を追記し、**無いと ① が `AccessDenied` で失敗する**ことを明記 |
| **中 3: `external_search` の明細フィールドとの両立** | `observability.md` §4.2 の `input_tokens` / `output_tokens` 行と `stop_reason` 行に「**`external_search` は対象外 / NULL**」を明記し、**専用の注記ブロック**を新設 (同一明細に載せる理由 = AL-4 が総額を捉えるため / NULL を許すのはこの `route_kind` のみ / **単価テーブルに「1 リクエストあたりの単価」の行型を持たせる** / `provider` `model` の入れ方)。O-H の判断にも 1 リクエスト単価の行型を追記 |
| 軽微: `rollback.yml` ③ の `for NAME in <...>` が bash 構文エラー | プレースホルダを `AGENT_NAMES` 環境変数の展開に変更。**全 `run` ブロックを `bash -n` で検査して OK** を確認 |
| 軽微: `docs/design/` の「未着手」stale | **8 箇所**を実ファイルへの相対リンクに置換 (`architecture.md` 1 / `API/README.md` 5 / `API/news.md` 1 / `API/idea-boards.md` 1)。残る `(未着手)` は `data-model.md` と Task-3i で、**実際に未着手なので正しい** |

検証: `make doc-lint` エラー 0 / `make check-traceability` productionization 46/46・construction-workflow 24/24 /
`rollback.yml` の YAML パース OK (1 ジョブ 9 ステップ) + **全 run ブロックの `bash -n` OK** / `deploy.yml` YAML パース OK。
