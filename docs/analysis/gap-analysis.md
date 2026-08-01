# ギャップ分析: PoC → 本番 (v3)

> **v2 の搭載機能の全件台帳は [v2-feature-inventory.md](v2-feature-inventory.md)** (全 132 ルート × v3 の対応先。C-16 の照合の入力)。本書はギャップの分析、同書は**引き継ぎ漏れの検出**を担う。

> PoC ([poc-inventory.md](poc-inventory.md)) と本番既存システム (hassan-v2-backend / hassan-v2-frontend) の
> 差分を、**本番化で埋めなければならない穴**として整理する。設計判断は [architecture.md](../design/architecture.md)、
> 必須観点の ID は `.claude/rules/08-production-gates.md`。
> 実測日: **2026-07-28**。

## 0. サマリ (ギャップの大きさ順)

| # | ギャップ | 深刻度 | 主な影響 |
|---|---|---|---|
| G-1 | **認証・テナント分離が PoC に存在しない** | 最大 | データモデル・全 API・LLM ツール実行に波及 (A-1〜A-7) |
| G-2 | **アプリ構造が別物** (net/http 直書き ↔ gin + 3 層 + sqlc/wire) | 大 | 移植は「コピー」ではなく「書き直し」になる (DR-4) |
| G-3 | **LLM 基盤の二重化** (v2 = Dify 経由 / PoC = Managed Agents) | 大 | 併存させるか片方に寄せるかで運用コストが変わる |
| G-4 | **データモデルの重複** (themes / assets / ideas が両方に存在) | 大 | 既存本番データとの統合か分離かで移行計画が変わる (DR-3) |
| G-5 | **可観測性・LLM コスト管理が無い** | 中〜大 | 本番運用で障害調査・費用制御ができない (O-1〜O-7) |
| G-6 | **デプロイ経路が無い** (PoC はローカル起動のみ) | 中 | ECS + ecspresso への載せ替えが必要 (D-1〜D-7) |
| G-7 | **Managed Agent のライフサイクル管理が手作業** | 中 | プロンプト変更がデプロイと非同期になり、静かな機能停止を招く (D-6) |
| G-8 | **フロントエンドのスタック差** (Vite SPA ↔ Next.js + orval) | 中 | UI は再実装。API 型は生成に寄せられる |

---

## G-1. 認証・テナント分離

### 現状

| | PoC | v2 (本番) |
|---|---|---|
| 認証 | **なし**。`127.0.0.1` のみで待ち受け | JWT。ヘッダ `X-Token` を `AuthRequiredMiddleware` が検証 (`hassan-v2-backend/auth/middleware.go`) |
| ロール | なし | 一般アカウント / コンサルタント / 管理者 (`hassan-v2-backend/auth/client.go` の `AuthRole`) |
| 所有権 | なし | `accounts` / `companies` / `contracts` を軸に、主要テーブルが `account_id` を持つ (`hassan-v2-backend/db/schema.sql`) |
| 監査 | なし | `activity_logs` / `event_logs` テーブルあり (同上) |

### 埋めるべき穴

1. PoC 由来の全テーブルに**所有者カラムの設計**が要る (A-3)。既存 v2 テーブルとの関係 (G-4) と同時に決める
2. 全エンドポイントで**絞り込みをどの層で行うか**を決める (A-4)。PoC のハンドラには置き場所が無い (G-2 と連動)
3. **LLM custom tool のテナント越境 (A-6)** — PoC の 9 tools は ID を受け取ってそのまま参照する。
   LLM は他テナントの ID を渡し得るため、ツール実行時の所有者チェックが必須。
   **PoC のコードをそのまま移植すると、この穴がそのまま本番に出る**
4. 401 / 403 / 404 の使い分け (A-5)。v2 では取り違えが頻出バグとして記録されている
   (`hassan-v2-backend/CLAUDE.md`)

---

## G-2. アプリ構造

> **v3 の方針**: アプリ構造はユーザー指定で **4 層 (Controller → UseCase → Service → Repository)**
> に **`entity/` / `gateway/` を加えた計 6 パッケージ層** ([architecture.md](../design/architecture.md) §3.3)
> ([design_memo.md](../design/design_memo.md))。v2 の 3 層に Service 層を足す形になるため、
> **v2 からの規約流用は「3 層分 + 新設 3 層 (`service/` / `entity/` / `gateway/`) の定義」**になる
> (増分 layering で `entity/` と `gateway/` も層として追加された。[architecture.md](../design/architecture.md) §3.3)。

| 観点 | PoC | v2 (本番規約) |
|---|---|---|
| HTTP | `net/http` + `mux.HandleFunc` + 自前パスパース | gin + router |
| 層 | ハンドラ + internal ドメイン (UseCase 層なし) | Controller → UseCase → Repository の 3 層 |
| DB アクセス | 手書き pgx store | sqlc 生成 + Repository |
| DI | 手動配線 | wire (`hassan-v2-backend/di`) |
| エラー | `http.Error` + JSON 文字列 | `constants.NewCodedError` |
| スキーマ | golang-migrate (連番 SQL、起動時自動適用) | psqldef (`db/schema.sql` を正とする差分適用) |
| API ドキュメント | なし | Swagger コメント → 生成 → orval で FE 型生成 |

**移植は書き直し**。PoC のハンドラ 59 ファイルを 1:1 で移すのではなく、
「振る舞い (受入基準) を PoC から抽出し、v2 の層に載せ直す」作業になる。
PoC のコード構造をそのまま持ち込むのは DR-4 (レビュー指摘対象)。

**未決**: マイグレーション方式を psqldef (v2) と golang-migrate (PoC) のどちらに寄せるか (D-4)。

---

## G-3. LLM 基盤の二重化 → **Dify 廃止が決定** (2026-07-28)

- v2 は Dify + 自前 LLM クライアント経由 (`hassan-v2-backend/llm`, `hassan-v2-backend/dify`,
  `hassan-v2-backend/prompt`)
- PoC は Anthropic Managed Agents (Agent リソース + custom tools + SSE)

**ユーザー決定**: **Dify は廃止**。エージェント性が要る処理は Managed Agent、
不要な処理は既存の LLM API を直接使う (使用モデルは見直す) — [questions.md](../../aidlc-docs/inception/productionization/questions.md) Q-4。

### 廃止対象の実測 (2026-07-28)

| 項目 | 実測 |
|---|---|
| Dify クライアント実装 | `hassan-v2-backend/dify` の 9 ファイル + `workflow` ディレクトリ |
| Dify を担っている機能 | `business_plan.go` (企画書生成) / `chatbot.go` / `research_chat.go` / `idea.go` / `extract_asset_titles.go` / `generate_asset_descriptions.go` / `comany_info_from_url.go` |
| 参照している箇所 | 14 ファイル (`hassan-v2-backend/usecase/business_plan`, `hassan-v2-backend/usecase/idea`, `hassan-v2-backend/prompt/template.go` 等) |
| **受け皿は既にある** | `hassan-v2-backend/llm` に抽象 (`factory.go` / `interface.go`) と **gemini / claude / openai / exa** の実装が存在する |

**評価**: 「不要なところは既存 API」という方針は、v2 の `llm/` 抽象がそのまま受け皿になるため
**技術的な障壁は低い**。

### 移行方針の決定 (Q-9=A。2026-07-28)

**Dify 依存機能は v2 に残さず、すべて v3 で作り直す**。v3 側での実装形態は D-B' の判定基準
(ツールを使う / 複数ターン回る / 出力が次の入力を決める → Managed Agent、それ以外 → 直接 API) で振り分ける。

### ⚠️ 前提の訂正 (Task-2e の実測結果。2026-07-28)

**当初「v2 は Dify 経由で稼働中」と書いていたが、実測すると Dify からの移行は v2 で
すでに大部分完了している**。詳細と出典は [dify-inventory.md](dify-inventory.md)。要点:

| 実測結果 | 出典 |
|---|---|
| `dify/` パッケージは**実コードから参照されていない (dead code)**。`dify.` の参照はコメント 2 件のみ | `hassan-v2-backend/usecase/business_plan/interfaces.go:16` / `usecase/idea/interfaces.go:13` |
| DI に DifyService は不要と明記 (「企画書チャット・履歴は BE LLM に移行済み」) | `hassan-v2-backend/di/wire.go:160` |
| 企画書生成は「Dify を使わない」実装に置換済み | `hassan-v2-backend/usecase/business_plan/generate_business_plan.go:216` `:323` |
| アセット抽出・説明生成も BE LLM へ移行済み (プロンプト関数名に `Dify` が残存するだけ) | `hassan-v2-backend/usecase/asset/extract_asset_titles_llm.go` / `generate_asset_descriptions_llm.go` |
| **プロンプト資産はリポジトリ内の YAML に存在** (Dify SaaS 上ではない) | `hassan-v2-backend/dify/workflow/prod/*.yml` (prod 7 本 / dev 8 本) |
| 残存しているのは設定と資産 (Dify API キー env 9 個 + `DIFY_API_ENDPOINT` 3 環境) | `hassan-v2-backend/di/provider.go:37`〜`:45` / `hassan-v2-backend/env/.prod.env` |

**したがって G-3 の性質が変わる**: 「LLM 基盤の二重化」というギャップは v2 側では既に解消しており、
残るのは **(1) v2 の掃除 (dify/ 削除・env 削除・`Dify` 命名の整理)** と
**(2) v3 への移植 (v2 の llm 層で動いている現行機能を 4 層 + Managed Agents へ載せ替える)**。
Q-9 の「v3 で全部作り直す」は実質 (2) を指す。

**未調査**: `research_chat` / `idea` / `company_info_from_url` / `extract_json` の現行経路
(移行済みか機能廃止か)、および各機能が現在実際に使っているモデル。

**残る設計論点**: **使用モデルの見直し基準** (処理ごとの品質 / レイテンシ / 単価のトレードオフ)。
モデル管理の枠組みは v2 に既にある (`hassan-v2-backend/llm/types.go` の列挙 + 用途別許可リスト
`llm/factory.go:57` `:82`) ため、**v3 で作り直すか引き継ぐか**が判断対象。

---

## G-4. データモデルの重複

両方に「テーマ」「アセット」「アイデア」「企画書」が存在する:

| 概念 | PoC | v2 |
|---|---|---|
| テーマ | `themes` (所有者なし) | `themes` (`account_id` あり) |
| アセット | `assets` + `asset_tags` / `asset_specs` / `asset_patents` / `function_tree_l1` / `function_tree_l2` | `assets` / `asset_documents` / `asset_usage_histories` |
| アイデア | `hassan_v2_ideas` / `idea_versions` / `idea_evaluations` / `idea_self_ratings` | `ideas` / `idea_hassans` / `idea_boards` / `idea_board_phases` |
| 企画書 | `plan_tab_versions` | `business_plans` / `business_plans_detailed` / `business_plan_histories` |
| 会話 | `conversation_sessions` | `business_plan_chats` / `research_chats` |

**PoC 側のテーブル名 `hassan_v2_ideas` が示すとおり、PoC は v2 のアイデア概念を意識して作られている**が、
スキーマは独立している。本番化では次のいずれかを選ぶ必要がある (設計の最重要分岐):

- (a) v2 の既存テーブルを拡張して統合する — 既存データと機能を活かせるが、移行と後方互換が重い
- (b) v3 用の新テーブル群を追加し、v2 とは参照で連携する — 独立性は高いが、二重管理と整合の問題
- (c) 新システムとして分離し、v2 からは段階的に移行する — クリーンだが移行コストが最大

**この判断が済むまで、データモデル設計は着手できない** (DR-3 の温床)。

### 全面切替 (Q-5=C) 決定による評価の変化 (2026-07-28)

**v3 が v2 を置き換える**前提になったため、(b) の利点である「併存できる」が消えた:

| 案 | 全面切替下での評価 |
|---|---|
| (a) v2 テーブル拡張 | **有力**。既存データがそのまま使え、切替時のデータ移行が不要。ただし v3 backend が v2 の DB を直接触るため、リポジトリ 3 分割 (Q-2=A) の独立性と噛み合わない |
| (b) 新テーブル + 参照連携 | **不利**。併存のための二重管理コストを払った上で、切替時に結局データ移行が必要になる |
| (c) 分離 + 段階移行 | **有力**。v3 のスキーマを制約なく設計でき、移行は「一度の ETL + 切替」に集約できる |

**判断に必要な追加情報**: v2 本番の既存データ量 (themes / ideas / business_plans の件数) と、
切替時にどこまで引き継ぐ必要があるか (全件 / 直近のみ / 引き継がない)。
**引き継ぎ不要なら (c) が明確に有利、全件引き継ぎ必須でダウンタイム不可なら (a)** が現実的。

---

## G-5. 可観測性・LLM コスト

| 観点 | PoC | v2 | 必要なこと |
|---|---|---|---|
| ログ | 標準出力への ad-hoc ログ | `hassan-v2-backend/logger` | 構造化 + リクエスト/アカウント/セッション ID (O-1) |
| LLM 計測 | 発散経路のみ (`claude_managed_agents/internal/agent/diverge/result_helpers.go` の `EstimateUSD`) | Dify 側に依存 | **全経路**でトークン・コスト・stop_reason・所要時間 (O-2) |
| コスト制御 | なし | なし | アカウント/テーマ単位の集計と上限超過時の挙動 (O-3) |
| 失敗の可観測性 | JSON パース失敗・`max_tokens` 切り詰め (BE-6) が静かに起きる | — | 警告として観測可能にする (O-4) |
| SSE | keep-alive あり | — | 切断・再接続・タイムアウトの検知 (O-5) |
| 監査 | なし | `activity_logs` / `event_logs` | 生成・削除操作の記録 (O-6) |
| アラート | なし | 未調査 | しきい値と通知先の設計 (O-7) |

**LLM を主機能とするプロダクトで計測が 1 経路しかないのは、実質「計測なし」**。
コストと品質の両方が制御不能になるため、本番化の初期増分に含める必要がある。

---

## G-6. デプロイ・CI/CD

| 観点 | PoC | v2 | v3 (ユーザー指定) |
|---|---|---|---|
| 実行環境 | ローカル (`127.0.0.1:8765`) | AWS ECS + ALB / RDS | AWS ECS + PostgreSQL / FE は **Vercel** |
| デプロイ | なし | ecspresso (`hassan-v2-backend/stacks/dev/ecspresso.yml` / `hassan-v2-backend/stacks/prod/ecspresso.yml`) + GitHub Actions (`hassan-v2-backend/.github/workflows/dev-deploy.yml` / `prod-deploy.yml`) | GitHub Actions + **全て IaC (Terraform 想定)** |
| CI | build/vet/test + FE 4 点 (`claude_managed_agents/.github/workflows/ci.yml`) | `hassan-v2-backend/.github/workflows/test.yml` | **UT + lint を機械強制** |
| 環境分離 | `.env` 1 ファイル | local / dev / prod (タスク定義 + 環境変数) | local / dev / prod。**開発環境の未リリース変更を本番に出さない仕組みが要求されている** |
| シークレット | `.env` に平文。`WriteEnv` が書き換え (BE-3) | ECS タスク定義 / Secrets (要確認) | 同 (`.env` 自動書き換えは不採用) |

**PoC の `.env` 自動書き換え方式は本番に持ち込まない** (D-5)。

**追加のギャップ**: v2 リポジトリで IaC 化されているのは **ECS のサービス/タスク定義のみ**
(`hassan-v2-backend/stacks` の中身は `ecspresso.yml` / `ecs-service-def.json` / `ecs-task-def.json`)。
`hassan-v2-backend` 直下 3 階層に Terraform (`*.tf`) / CDK (`cdk.json`) / CloudFormation の定義は
**見当たらない** (2026-07-28 実測。別リポジトリで管理されている可能性は**未確認**)。
したがって v3 の「全て IaC」は v2 からの流用ではなく**新規構築**になる見込み。
必要なインフラ構成要素の一覧も未確定 ([design_memo.md](../design/design_memo.md) の TODO)。

---

## G-7. Managed Agent のライフサイクル

PoC では Agent (system prompt + tool schema) が **Anthropic 側のリソース**として存在し、
`claude_managed_agents/cmd/update-agent-prompt` を手で叩いて発行・更新する。
`.env` の `*_AGENT_ID` が実体への参照。

本番では次が必要 (D-6):

- 環境ごと (dev / prod) の Agent をどう発行・識別するか
- **プロンプト / tool schema の変更をデプロイ手順の一部にする** (コードだけデプロイして
  再発行を忘れると、引数が黙って捨てられ機能が死ぬ = BE-8 / BE-10)
- Agent の Tools が更新時に**全置換**される問題 (BE-9) を、宣言的な定義で回避する

---

## G-8. フロントエンド

| 観点 | PoC | v2 |
|---|---|---|
| フレームワーク | React + Vite (SPA) | Next.js (`hassan-v2-frontend/package.json`) |
| API 型 | 手書きパーサー (`parseXxxResponseBody`) | orval で OpenAPI から生成 (`hassan-v2-frontend/orval.config.js`) |
| テスト | vitest + testing-library | Playwright (E2E) + Storybook (`hassan-v2-frontend/playwright.config.ts`) |
| デザイン | 独自 Tailwind トークン | Tailwind + Radix UI + shadcn 系 (`hassan-v2-frontend/components.json`) |

UI は再実装になる。**手書きパーサー起因の不具合 (FE-2 / FE-4) は orval 生成型で構造的に解消できる**が、
LLM 出力のパース (FE-6) は生成型では解決しないため、テスト方針として設計に残す。

---

## 9. 未解決の分岐 (設計を始める前に決めるべきこと)

| # | 論点 | 影響 |
|---|---|---|
| Q-1 | **G-4 の (a)/(b)/(c)** — v2 データモデルと統合するか分離するか | データモデル設計・移行計画の全体 |
| Q-2 | ~~v3 は v2 のリポジトリを拡張するのか、新規リポジトリなのか~~ → **回答済み: backend / frontend / infra の 3 分割** | ハーネス・CI・デプロイの構成 |
| Q-3 | 移植対象のスコープ (会話型フローのみ / PoC 全機能) | 増分計画の規模 |
| Q-4 | Dify 経路との併存方針 (G-3) | LLM 層の設計とコスト集計 |
| Q-5 | 既存 v2 ユーザーへの出し方 (置換 / 併存 / 限定公開) | 段階リリースと移行 (D-7) |
| Q-6 | LLM コストの上限方針 (拒否 / 警告 / 可視化のみ) | 可観測性設計 (O-3) |
| Q-7 | IaC の範囲と ecspresso との役割分担 | インフラ設計 (D-8) |
| Q-8 | 環境戦略 (フラグ / ブランチ) と DB 自動適用範囲 | 運用設計 (D-4 / D-7) |
| Q-9 | Dify 廃止の移行方針 (機能ごとの移行先) | G-3 の実行計画・第 1 増分のスコープ |

これらは `aidlc-docs/inception/productionization/questions.md` に `[Answer]:` 付きで起票済み。

**回答状況 (2026-07-28)**: Q-2=A (3 リポ分割) / Q-4=Dify 廃止 / Q-5=C (全面切替) / Q-6=C (上限なし) /
**Q-9=A (Dify 依存機能を v3 で全部作り直す)** が確定。Q-1 は保留 (データ引き継ぎの要否が事業判断待ち)、
Q-3 と Q-8 は検討中、Q-7 は v2 の ecspresso 使用実態を追記して再質問中。
確定分の反映先は `aidlc-docs/inception/productionization/requirements.md` の C-9〜C-13。

**Q-9=A の波及**: v3 の最終的な移植範囲が「PoC 全機能 + v2 の Dify 依存機能」になるため、
**G-4 のデータモデル判断は第 1 増分ではなく最終範囲を見据えて行う必要がある** (2 度目の移行を避けるため)。

**Q-7 の前提が未確定**: 必要なインフラ構成要素の一覧 (VPC / ALB / RDS / Secrets / 監視 / WAF 等) が
洗い出されていない ([design_memo.md](../design/design_memo.md) の TODO)。ここが決まらないと
IaC の範囲も工数も見積もれない。
