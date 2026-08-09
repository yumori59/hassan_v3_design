## 技術スタック

- FE
  - Vercel
  - Next JS
- BE
  - Go
- aws 
  - 全部IaCでやりたい
  - Terraform?
  - ECS
  - PostgreSQL
  - TODO: その他インフラ何が必要か一覧化してあるふぁさんに確認する

~~TODO: 現在のv2の技術スタックを更新する必要があるかを確認~~
→ 確認済み (2026-07-28): 大きな更新は不要。v2 は最新水準 (BE: Go 1.24.3 / gin 1.10.1 / sqlc 1.29、FE: Next 15.5.9 / React 19.1.2 / orval 7.1)。実装リポ立ち上げ時にマイナー追従のみ。PoC の React 18 + Vite / Go 1.25 は v2 系に寄せる

## 開発環境

~~TODO: DevとProd~~
→ 確定 (2026-07-29): local / dev / prod の 3 環境。**dev を先行構築し開発と並行して継続デプロイ、
本番は開発完了後に 1 回で全面切替** (C-15)。IaC は **Terraform = 基盤 / ecspresso = ECS リリース** (Q-7=B)

~~TODO: 開発環境に入っている修正を切り分けて本番リリースできるようにしたい~~
→ 一部確定 (2026-07-30): 本番リリースは手動起動 + GitHub environment 承認 + `main` 限定で dev と分離
([templates/shared/.claude/rules/04-human-checkpoints.md](../../templates/shared/.claude/rules/04-human-checkpoints.md) H-4)。
**未完成機能を隠すフラグ方式 (Q-8) のみ検討中** (暫定: trunk-based + 環境変数フラグ)

~~TODO: DB更新を自動化できないか~~
→ 半自動化で確定 (2026-07-30): deploy-backend.yml で **差分検査 → 破壊的変更の機械判定 → 承認 (environment) → 適用**
の流れを設計 (H-2)。非破壊は dev で自動。**マイグレーションツールの選定 (D-4: psqldef か golang-migrate か) は未確定**

## アーキテクチャ

- クリーンアーキテクチャ
  - controller -> usecase -> service -> repositoryの構成にしたい
- 

## 開発手法

- TDD開発
  - UTも記載する
- CI / CDでUT実行する形にする
  - lintもやりたい
- github issue駆動でできればやりたい
- 結合テストやりたい
  - playwright

## 開発ルール

~~TODO: V2をベースにAI駆動で開発できるようにちゃんとルールを定めたい~~
→ 確定 (2026-07-30・feature `construction-workflow`。design-reviewer 3 巡で重大ゼロ = Design Freeze 可):

- **手法**: AIDLC を維持 (設計 = 本リポの Inception / 実装 = 実装リポで TDD)。実装・レビューはサブエージェント委譲
- **作業ループ**: 1 issue を S-1 (受領) 〜 S-10 (マージ) の固定ステップで回す —
  [templates/shared/.claude/rules/01-construction-loop.md](../../templates/shared/.claude/rules/01-construction-loop.md)
- **issue 粒度**: 1 issue = 1 PR = 「同じ層・同じ検証で閉じる AC 群」(Q-1=A)。リポ跨ぎ (infra ↔ app) は独立 issue + 固定マージ順序 (Q-2=B)。**FE/BE 跨ぎは後方互換なら 1 issue に統合可** (2026-08-03 のモノレポ化) —
  [02-issue-granularity.md](../../templates/shared/.claude/rules/02-issue-granularity.md)
- **モデル運用**: 実装 sonnet / レビュー opus、オーケストレーターが着手前判定 + 実行中トリガーで昇格 (Q-5=A) —
  [03-model-escalation.md](../../templates/shared/.claude/rules/03-model-escalation.md)
- **人間の承認点**: PR マージ / DB マイグレーション / Agent 再発行 / 本番デプロイの 4 点 + 条件付き着手前承認 (Q-3)。
  エージェントは PR 作成まで自律・マージは人間 (Q-4=A) —
  [04-human-checkpoints.md](../../templates/shared/.claude/rules/04-human-checkpoints.md)
- **レビュー**: 別セッションのレビュアーで重大ゼロまで。差し戻し 2 回で人間へ (Q-6=A)。infra も `infra-reviewer` を新設し自己レビュー禁止 (Q-7=A)

要件・経緯: [aidlc-docs/inception/construction-workflow/](../../aidlc-docs/inception/construction-workflow/requirements.md) /
レビュー: [aidlc-docs/reviews/construction-workflow/review.md](../../aidlc-docs/reviews/construction-workflow/review.md)

## 開発役割分担

## アプリ

### FE

- 認証
- テーマ
- お知らせ
- アイデア発散
- ナレッジ
- アイデアボード
- アセット
- 設定

### BE

- 認証
- テーマ
- お知らせ
- アイデア発散
- ナレッジ
- アイデアボード
- アセット
- 設定

## インフラ

### AWS

### CI / CD



## テーブル定義

- 

## API一覧

- 

## 2026-07-28 アーキテクチャ検討の決定ログ

v2 / PoC の実コード調査に基づくセッションでの決定。[architecture.md](architecture.md) に未反映の差分は末尾に明記。

### 層構成

- v2 の 3 層をベースに、**v3 新規ドメイン (テーマ / アセット / 会話・アイデア創出) のみ** service を挟んだ 4 層 (controller → usecase → service → repository)。**v2 から移植する認証・アカウント等は v2 の 3 層構成のまま**移植する (作り直しと再レビューのコスト回避)
- service = **入口非依存のビジネスロジック**。根拠: v3 はロジックの入口が HTTP とエージェント custom tools の 2 つあり、PoC の tools 9 本は全てドメインデータを読み書きする。エンドポイント単位の usecase はツールからの再利用粒度に合わない
- 依存方向: usecase → agent、agent の tools → service。**agent は usecase を知らない** (循環なし)。ツール実装は wire で注入

> **注記 (2026-07-30。原文は入力の履歴として残す)**: 上の 3 点は増分 layering で次のように具体化・変更された
> (設計の正は [architecture.md](architecture.md) §3)。
> - **1 点目 (新規ドメインのみ 4 層 / 移植は 3 層) はそのまま採用**され、§3.5.2 の対象パス一覧として明文化された。
>   ただし **Q-L11=A-1 により「移植分も LLM 呼び出しだけは `gateway/` 経由」という例外が加わった**
> - **2 点目の「入口非依存のビジネスロジック」という原意は維持**しつつ、定義を
>   **「1 ドメイン (集約) に閉じたビジネスロジック」**に絞った (§3.3)。加えて **`entity/` と `gateway/` を層として追加**し、
>   計 6 パッケージ層になっている
> - **3 点目は変更**: 「agent の tools → service」の直結は採らない。**ツールハンドラは UseCase が関数注入する**
>   (§3.8.1)。理由はツールが他ドメイン (asset / plan / idea) のデータを触るため、直結すると
>   **`service/A` → `service/B` の禁止 (L-2) に違反する**こと。関数注入なら循環も層飛ばしも起きない

### エージェント層

- `agent/` をトップレベルの外部サービスパッケージとして配置 (v2 の `llm/` と同格。参考にするのは `llm/factory.go` パターンのみ — `dify/` はデッドコードにつき参照しない)
- SSE は **usecase の Output に型付きイベント channel** を持たせ、controller が書き出す (v2 先例: `hassan-v2-backend/controller/research.go:210-234`)
- PoC の「イベント → テキスト行 → 文字列プレフィックスで再パース」の二段変換は**廃止**。SDK イベント型 → 型付き struct の一段変換に再設計
- セッション対応表 (PoC は `sync.Map`) と台帳は DB 所有にする — プロセス再起動・水平スケール耐性

### テナント境界

- **型で強制**: `ContractID` を専用型にして service / repository の必須引数にする。渡し忘れ・`AccountID` との取り違えをコンパイルエラー化 (v2 の「手渡し + レビュー頼み」による 404/403 頻出バグへの構造的対策)
- v3 新規テーブルは `contract_id NOT NULL` + FK を必須 (スキーマレビューの機械チェック項目)
- 404/403 の判定ロジックは service に一元化
- Postgres RLS は却下 (接続プーリングとの相性・運用コスト)。将来の多層防御候補として記録

### API 契約

- REST は v2 踏襲 (swaggo → OpenAPI → orval)
- **SSE イベント型も OpenAPI の components/schemas に discriminated union で定義**し、型生成を単一ソース化 (v2 で実在するドリフト: `create-stream-research-chat.ts` が orval 生成型と手書き `StreamResponse` を並存。PoC のツール定義ドリフトと同型の問題の再発防止)
- FE の SSE 読み取りループは**共通クライアント 1 本**に集約 (v2 の `// TODO: ストリーム処理は共通化する` を v3 で果たす。現状 7 ファイル以上に複製)

### データモデル (保留 — DB 検討中)

確定させず叩き台のみ記録:
- Asset は PoC 構造化モデル (スペック表 / 機能ツリー / 棚卸し状態機械 / 重複マージ) をベースに v3 で新規設計 + テナント列
- v2 `asset_type` (使い方区分) と PoC `category` (技術分野) は**別軸の概念**なので 2 カラム共存 (統合すると v2 の `AssetTypeMyIdea` 分岐が壊れる)
- 紐付けは v2 の `asset_ids bigint[]` (FK 不能な配列) をやめ**中間テーブルで正規化** (PoC でフロントにしかない「クロスアセット複数選択」の永続化にもなる)
- 台帳は `ledger` JSONB 踏襲 (横断検索の主対象ではないため過剰正規化しない)

### 可観測性・LLM コスト (軽量スタート)

- 初期は**使用量記録 + 構造化ログ + 相関 ID のみ**: ターン単位で contract / account / conversation / model / 入出力トークン / レイテンシを記録。全ログ・SSE イベントに conversation_id / session_id を通す
- テナント別クォータ・OTel・ダッシュボードは後回し (architecture.md O-3「上限拒否なし・可視化 + アラート」と整合)

### デプロイ・スケーリング

- BE は v2 踏襲 (ECS + GitHub Actions)。エージェント実行は Anthropic 側のため Go サーバの主負荷は接続保持 — ワーカー分離は初期不要
- SSE keep-alive 30 秒を維持 (ALB アイドルタイムアウト 60 秒対策)
- **rolling update で SSE は必ず切れる前提**で設計: 会話状態は台帳 (DB) にあるので「会話履歴 GET で復元 + 再接続」を FE 仕様に入れる (O-5 への入力)
- アセット AI 抽出 (PDF/CSV/URL) は PoC の status 状態機械 + **失敗時再実行の保証** (デプロイで処理が死んでも復旧可能)。ジョブキューは初期導入しない

### v2 との関係・リポ構成 (architecture.md と同じ決定の再確認)

- v3 は v2 の**全面置き換え** (D-J と一致)。データは v2 → v3 移行
- FE / BE は**同一の app モノレポ内のサブツリー** (**2026-08-03 に 3 分割から方針転換**。infra リポのみ分離。D-I / [architecture.md](architecture.md) §3.11 参照)

### architecture.md への反映待ち差分 → 反映状況 (2026-07-29 更新)

1. **D-A / D-A'** → **実質反映済み**: [architecture.md](architecture.md) §3「層配置の判断基準」が D-A' を確定 (基準は「トランザクション境界を持つか」の決定木)。「新規ドメインのみ」の明文ルールは無いが、この基準なら移植 CRUD は自然に Service なしになるため同等。入口二重化の根拠は ToolDispatcher → Service/Repository の構造として具現化
   - **追記 (2026-07-30。上の記述は 2026-07-29 時点のもので、増分 layering により 2 点が変わった)**:
     ① **判断基準は「トランザクション境界を持つか」の決定木ではなくなった** — [architecture.md](architecture.md) §3.4 の
     **6 問の決定木**に差し替わり、Service の定義も「1 ドメイン (集約) に閉じたビジネスロジック」に絞られた。
     ② **`ToolDispatcher` は存在しない** — ツールハンドラを **UseCase が関数注入する**方式 (§3.8.1) に置き換わった。
     `service/A` → `service/B` を禁止した (L-2) ため、ツールから他ドメインの Service を直接呼ぶ形が取れなくなったのが理由。
     ③ 「新規ドメインのみ」は **§3.5.2 の対象パス一覧として明文化された** (この点は当初メモのとおり確定)
2. **A-3 / A-4** → **反映済み (2026-07-29)**: `ContractID` / `AccountID` 専用型を [auth.md](auth.md) §6.4 の機械強制に追記 (SQL の CI 検査と補完関係として両方採用)
3. **A-5 / O-5** → **反映済み・発展**: [API/README.md](API/README.md) D-API-12 / J-6 / J-7、observability.md (keep-alive は 15 秒に更新)。**発展**: 非同期ジョブの SSE 進捗はプロセス内 channel でなく **DB 状態のポーリング配信** (複数 ECS タスクで接続とジョブ実行が別タスクに乗るため)。同一リクエスト内で完結する会話ターンの SSE は channel 方式のまま
