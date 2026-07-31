# Rule 08: 本番品質ゲート (必須観点 SSOT)

PoC (`claude_managed_agents`) は **認証なし・単一テナント・ローカル 127.0.0.1 起動**を前提に
作られており、本番で必要な層がまるごと存在しない。**「PoC では対象外だった」は設計の省略理由にならない**。

本ファイルが本番観点の **SSOT**。`design-reviewer` はこれをチェックリストとして使い、
設計書 (`docs/design/`) は各項目に **ID で回答**する (例:「§4.2 で A-3 に対応」)。
**対象外とする場合も、理由と先送り先 (どの増分で扱うか) を書く**。無言の省略は重大指摘。

---

## A. 認証・テナント分離・権限

v2 の既存機構を正とする。**新設計で独自方式を発明しない** — 逸脱には却下案と理由が必要。

| ID | 観点 | 確認内容 |
|---|---|---|
| A-1 | 認証方式 | トークン検証は v2 の `AuthRequiredMiddleware` 系に載るか (`hassan-v2-backend/auth/middleware.go`)。新エンドポイントが素通りになっていないか |
| A-2 | ロールと適用範囲 | 一般ユーザー / コンサルタント / 管理者のどれが使う機能か。ロールごとの許可・拒否が設計に書かれているか (`hassan-v2-backend/auth/client.go` の AuthRole) |
| A-3 | テナント境界 | 新規テーブルに所有者カラム (`account_id` = 個人 / `contract_id` = 契約) があるか。**`company_id` は v2 に存在しない**。**v2 は 36 テーブル中 14 が所有者列を持たず親を最大 4 段辿る** — v3 は全テーブル必須にして 1 段にする (分布と出典: [../../docs/design/auth.md](../../docs/design/auth.md) §2.2) |
| A-4 | 絞り込みの層 | 一覧・取得系で所有者による絞り込みをどの層で行うか (UseCase か Repository か) を明示。**「後で足す」は不可**。**所有者 ID をパラメータで受け取る API では「その所有者が呼び出し元と同じ契約に属すること」の検証を必須にする** — 存在確認 (レコードが nil でない) は所有権の検証にならない (v2 の theme 一覧で実例を確認: `docs/analysis/v2-auth-tenancy.md`) |
| A-5 | ステータスコード | 401 (未認証) / 403 (権限なし) / 404 (不存在) の使い分けを設計時点で決める。v2 の頻出バグ (404 vs 403 の取り違え) を再発させない |
| A-6 | LLM への越境 | エージェント/ツールが**他テナントのデータを読み得る経路がないか**。PoC の custom tool (`list_assets` / `load_asset` 等) はテナント概念なしで実装されている — 本番ではツール実行時に必ず所有者スコープを渡す設計にする |
| A-7 | 共有・公開 | 共有機能を持つなら、共有範囲の表現 (v2 の `sharing_settings` 相当) と失効の扱い |

**A-6 は本番化で最も危険な穴**。PoC の会話エージェントは Go 側ディスパッチで custom tool を実行するが
(`claude_managed_agents/cmd/devui/conversation_tools.go`)、引数のアセット ID を所有者チェックなしで
参照する。ツール実行を「認証済みユーザーの操作」として扱う設計にすること。

---

## O. 可観測性・LLM コスト

PoC には**構造化ログもメトリクスもトレースもない**。コスト推定は発散エージェントの一経路にのみ存在する
(`claude_managed_agents/internal/agent/diverge/result_helpers.go` の `EstimateUSD`、
`claude_managed_agents/internal/agent/diverge/orchestrator.go` の `UsageTotals`) — 会話・企画書生成・
アセット抽出の各経路では計測されていない。

| ID | 観点 | 確認内容 |
|---|---|---|
| O-1 | 構造化ログ | リクエスト ID / アカウント ID / セッション ID を全ログに載せるか。v2 の `logger` パッケージに載せるか (`hassan-v2-backend/logger/logger.go`) |
| O-2 | LLM 呼び出しの記録 | **全 LLM 呼び出し**でモデル・入出力トークン・所要時間・stop_reason・ツール呼び出し回数を記録するか。1 経路だけの計測は「計測なし」と同じ。**LLM 抽象が全プロバイダで usage と stop_reason を返せるか**を先に確認する — v2 の抽象は OpenAI のみ usage を詰め、`stop_reason` を公開型に持たないため、そのまま流用すると計測が原理的に不可能 (`docs/analysis/v2-llm-inventory.md`) |
| O-3 | コスト集計と上限 | アカウント / テーマ単位のコスト集計。**上限超過時の挙動** (拒否 / 降格 / 警告) を設計に含める。無制限の自走エージェントを本番に出さない |
| O-4 | 失敗の可観測性 | LLM の JSON パース失敗・`max_tokens` 切り詰め (BE-6)・タイムアウト・ツール引数の不整合 (BE-8) を**警告として観測可能にする**。握り潰さない |
| O-5 | SSE / 長時間処理 | ストリーミング切断・再接続・タイムアウトの検知。処理の途中終了をユーザーとログの両方で分かるようにする |
| O-6 | 監査ログ | 誰がどのアイデア・企画書を生成／削除したか (v2 の `activity_logs` / `event_logs` 相当) |
| O-7 | アラート | 何をしきい値に誰へ通知するか (エラー率・レイテンシ・コスト急増)。**アラート設計のない可観測性は事後調査専用** |

---

## D. CI/CD・デプロイ・IaC

ユーザー指定: **AWS (ECS + PostgreSQL) を全て IaC で管理する (Terraform 想定)**、FE は **Vercel**、
**CI で UT と lint を機械強制**、**GitHub issue 駆動**。
参考実装は v2: ecspresso (`hassan-v2-backend/stacks/prod/ecspresso.yml`) +
GitHub Actions (`hassan-v2-backend/.github/workflows/dev-deploy.yml` / `prod-deploy.yml` / `test.yml`)。

> ⚠️ **「v2 に合わせる」を省略の理由にできない領域がある**。実測 (`docs/analysis/v2-deploy-observability.md`) で
> 次が判明している: **シークレットは Secrets Manager/SSM を使わず `.env` を Docker イメージに焼き込み
> dev/prod で同一イメージを共有** / **明示的なロールバック手段が無い** / **prod でリクエストログが出ない** /
> **IaC が存在せず AWS コンソール手作業で構築** / **prod は単一タスク・ヘルスチェック無し**。
> これらは D-1 / D-3 / D-5 / D-8 / O-1 において **v3 で新規に設計する対象**であり、
> 「既存もそうだから」で通してはいけない。

| ID | 観点 | 確認内容 |
|---|---|---|
| D-1 | 環境 | local / dev / prod の 3 環境を前提にした設定分離。環境ごとの値の持ち方 (env var / Secrets Manager)。**FE (Vercel) と BE (AWS) で環境が二系統になる**ため、対応関係を明示する |
| D-2 | CI ゲート | PR で何を機械強制するか (build / vet / **UT** / 型チェック / **lint** / 生成物の再生成漏れ)。**マージ条件を設計時点で決める** |
| D-3 | デプロイ手順 | イメージビルド → タスク定義更新 → ロールアウトの手順と、ロールバック方法。**FE (Vercel) と BE (ECS) のリリース順序と互換性** (API 変更時) を含む |
| D-4 | DB マイグレーション | 適用タイミング (デプロイ前 / 起動時) と後方互換。**v2 は psqldef、PoC は golang-migrate** — どちらを採るか決め、混在させない。**自動適用してよい変更と手動承認が要る変更を区別する** |
| D-5 | シークレット管理 | `ANTHROPIC_API_KEY` 等の保管先と受け渡し。**PoC の `.env` + `WriteEnv` 方式 (BE-3) は本番に持ち込まない** |
| D-6 | Managed Agent のライフサイクル | Agent ID / Environment ID を**環境ごとにどう発行・更新するか**。PoC は手動コマンド (`update-agent-prompt`) で発行し `.env` に書く運用 — 本番ではプロンプト変更が**デプロイ手順の一部**になる設計が必要 (BE-8/BE-10: schema と Agent の乖離で機能が黙って死ぬ) |
| D-7 | 段階リリース | 既存 v2 ユーザーへの出し方 (フラグ / 限定公開 / 全面切替) とデータ移行の順序。**開発環境の未リリース変更を本番に出さない仕組み**を含む |
| D-8 | IaC の管理範囲 | どのリソースを IaC で管理し、何を範囲外にするか (理由付き)。**Terraform と ecspresso の役割分担**、tfstate の保管場所、apply の実行主体 (人 / CI)、v2 の既存インフラとの関係 |

**D-6 は PoC と本番の最大の運用差**。system prompt / custom tool schema がコードと別管理 (Anthropic 側の
Agent リソース) になるため、「コードだけデプロイして Agent 再発行を忘れる」が本番障害の形で現れる。

---

## 運用

- 設計書は各章の冒頭または末尾に **「本節が回答する ID: A-3, A-6, O-2」** を書く
- `design-reviewer` は上表を舐め、**回答も「対象外の理由」も無い ID を重大指摘**として挙げる
- 本番運用で新たに問題化した観点は、本ファイルに ID を追記する (SSOT は追記で伸びる)
