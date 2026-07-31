# Requirements: construction-workflow (実装リポの AI 駆動開発ワークフロー)

> ステータス: **確定** (2026-07-29 — [questions.md](questions.md) の Q-1〜Q-7 全問回答済み。
> Q-2 のみ推奨案と異なる B を採用)。
> 親 feature: [productionization](../productionization/requirements.md) —
> 本 feature はその C-8 (TDD + CI 機械強制 + GitHub issue 駆動) と AC-5.2
> (ハーネスが TDD/lint を機械的に担保) を**実装リポの運用規約として具体化する**増分。
>
> **AC-ID は本 feature 内でユニーク**。番号は feature ごとに独立しており、
> productionization の同番号 AC とは別物 (`make check-traceability` は feature 単位で照合する)。

## 1. 目的とスコープ

実装リポジトリ (backend / frontend / infra の 3 リポ) で **1 issue を受け取ってから PR がマージされるまで**の
作業手順・担当 (人間 / オーケストレーター / サブエージェント)・停止条件を規約として確定し、
[templates/](../../../templates/README.md) に反映する。

**背景 (現状の穴。実測 2026-07-29)**: 雛形にはエージェント定義・CI・pre-commit・skills が揃っているが、
**作業の順序を定める運用ルール (設計リポの `.claude/rules/01`〜`06` に相当するもの) が存在しない**
(詳細は [questions.md](questions.md) の F-1〜F-6)。結果として次の 4 点が未定義:

1. 1 issue の作業ループ (issue → 計画 → 実装委譲 → Red/Green 確認 → レビュー → 反映 → PR)
2. issue の粒度 (1 issue = AC 群 / 1 PR / 1 コミットのどれか)
3. モデル・エスカレーションの運用 (誰が・いつ・何を根拠に判断するか)
4. 人間のチェックポイント (PR マージ / DB マイグレーション / Managed Agent 再発行 / 本番デプロイ)

### スコープ内 (本 feature の成果物)

- `templates/backend-repo/.claude/rules/` · `templates/frontend-repo/.claude/rules/` ·
  `templates/infra-repo/.claude/rules/` への**運用ルールの追加** (共通部分は `templates/shared/` 側)
- 各 `CLAUDE.md.tmpl` の運用ルール表・ハーネス節の更新 (追加ルールの索引)
- GitHub issue / PR テンプレートの雛形 (`.github/ISSUE_TEMPLATE/` · `.github/pull_request_template.md`)
- 既存エージェント定義 (`go-developer` / `code-reviewer` / `react-developer` / `frontend-reviewer` /
  `infra-engineer`) の**モデル運用に関する記述の整合**

### スコープ外 (やらないこと)

- 製品コードの実装、実装リポの実作成 (雛形の整備までが本リポジトリの責務)
- `docs/design/` の既存設計 (architecture.md / auth.md / API/ / observability.md) の変更
- 参照リポジトリ (`claude_managed_agents` / `hassan-v2-backend` / `hassan-v2-frontend`) の調査・変更
- 新規の認証・テナント・可観測性の**設計** (親 feature productionization の責務。§5 参照)
- AIDLC 以外の開発手法への乗り換え (C-1)

## 2. 制約 (確定事項 — 再議論しない)

| # | 制約 | 出典 |
|---|---|---|
| C-1 | **AIDLC ベースを維持する**。他手法への乗り換えはしない。ただし他手法の部分的な取り込み (例: tasks 粒度規約) は設計判断として可 | ユーザー指示 (2026-07-29) |
| C-2 | **TDD は確定**。受入基準を失敗するテストへ翻訳してから実装する (Red → Green → Refactor)。テスト名に AC-ID を埋める | 親 C-8 / [go-developer.md](../../../templates/backend-repo/.claude/agents/go-developer.md) の TDD 節 |
| C-3 | **実装とレビューはサブエージェントに委譲する**。実装 = `go-developer` / `react-developer` / `infra-engineer`、レビュー = **別セッション**の `code-reviewer` / `frontend-reviewer` (infra は Q-7) | ユーザー指示 / [.claude/rules/04-review.md](../../../.claude/rules/04-review.md) |
| C-4 | **CI で UT と lint を機械強制する**。マージ条件は CI ゲートで担保する | 親 C-8 |
| C-5 | **GitHub issue 駆動**。作業の起点は issue とする | 親 C-8 |
| C-6 | **`templates/` は雛形 (初期値) であり SSOT ではない**。切り出し後は実装リポ側が正になる。この位置づけを変えない | [templates/README.md](../../../templates/README.md) の注意節 |
| C-7 | リポジトリは **backend / frontend / infra の 3 分割**。OpenAPI スキーマが backend → frontend の契約 | 親 C-10 / [templates/README.md](../../../templates/README.md) |
| C-8 | **要件・設計の変更が必要になったら実装で辻褄を合わせず、設計リポ (hassan_v3) に差し戻す** | 各 `CLAUDE.md.tmpl` の運用ルール節 |
| C-9 | 本リポジトリに製品コードを置かない。参照リポジトリは読み取り専用 | ルート `CLAUDE.md` |

## 3. 受入基準

### 3.1 1 issue の作業ループ (最重要)

- **AC-1.1** 実装リポの「1 issue の作業ループ」が**順序付きのステップ**として定義され、
  各ステップの**入力・出力・担当** (人間 / オーケストレーター / サブエージェント / CI) が表で示されていること。
  ステップは少なくとも「issue 受領 → 現状把握と計画 → テスト先行 (Red) → 実装委譲 (Green) →
  検証 → レビュー (別セッション) → 指摘反映 → PR → マージ」を含む
- **AC-1.2** **Red → Green の確認が誰の責務か**と、その**裏取り手段**が定義されていること。
  サブエージェントの自己申告 (「Red を確認しました」) を鵜呑みにしない検証方法
  (テスト出力の提示 / AC-ID とテスト名の照合) を含む
- **AC-1.3** **レビュー差し戻しの条件・再レビューの反復上限・上限到達時のエスカレーション先**が
  定義されていること (Q-6)
- **AC-1.4** **設計リポへの差し戻し (C-8) の判断基準と手順**が定義されていること
  (「設計書に無いパターンに到達した」を誰がどう判定し、issue をどの状態にして止めるか)
- **AC-1.5** ループのどのステップが**並列実行可能**か / **直列必須**かが明示されていること
  (例: 独立 issue は並列可 / 同一 issue 内の Red → Green → レビューは直列)
- **AC-1.6** **中断・再開の記録方法**が定義されていること (DF-6) — ループの現在位置を issue コメントに
  残す形式・更新するタイミング・再開手順 (位置コメントが無い場合の扱いを含む)

### 3.2 issue の粒度と完了条件

- **AC-2.1** 「**1 issue = 何単位か**」が AC-ID との対応で定義されていること
  (1 issue が含む AC の範囲・1 PR / 1 コミットとの関係)
- **AC-2.2** **3 リポ跨ぎの機能**の issue 分割と **PR のマージ順序** (API 契約の互換順序:
  backend で新旧併存 → frontend 切替 → 旧削除) が定義されていること
- **AC-2.3** **issue テンプレート**が雛形として存在し、少なくとも「対象 AC-ID / 影響する層 /
  実行すべき検証コマンド / 人間チェックポイントの該当有無 / 親 issue」の欄を持つこと
- **AC-2.4** issue の**完了条件 (Definition of Done)** が定義され、**機械検証可能な項目**
  (CI グリーン / AC-ID を含むテストの存在 / 生成物の再生成) と**人間判断の項目**が区別されていること

### 3.3 モデル選択とエスカレーション

- **AC-3.1** 実装・レビューの**既定モデル**と、**エスカレーション / デエスカレーションの
  判断主体・タイミング・根拠**が定義されていること。「reviewer は実装者の tier 以上」の原則を含む
- **AC-3.2** **実行中の昇格トリガー**が定義されていること
  (Red が意図した失敗にならない / 重大指摘が反復する / 設計に無いパターンへ到達した 等)

### 3.4 人間のチェックポイント

- **AC-4.1** **人間が必ず判断するポイントの一覧**と、各ポイントで**何を見るか**・
  **承認の記録先** (PR レビュー / GitHub environment の承認 / issue コメント) が定義されていること
- **AC-4.2** **DB マイグレーション適用 / Managed Agent 再発行 / 本番デプロイ**の承認が
  **機構で担保**されていること (CI の environment 承認・deny ガード・PR チェック)。
  規約文書だけの「注意する」で終わらせないこと
- **AC-4.3** **エージェントの自律範囲** (commit / push / PR 作成 / マージ / force push /
  ブランチ削除) が許可・拒否の形で定義され、実装リポの `.claude/settings.json` に落とす指示が
  雛形の立ち上げ手順に含まれていること

### 3.5 3 リポジトリ間の整合

- **AC-5.1** 追加するルールが backend / frontend / infra の 3 リポで**一貫**していること。
  共通部分は 1 箇所 (`templates/shared/`) に置き、リポ固有部分のみ各リポに置く (同じ規約を 3 箇所に複製しない)
- **AC-5.2** infra-repo のレビュー体制が「**自己レビュー禁止**」と矛盾しないこと (Q-7)
- **AC-5.3** 各 `CLAUDE.md.tmpl` の運用ルール表に追加ルールが**索引**され、索引されたパスが
  **実装リポへのコピー後に解決する**こと。`*.tmpl` は `make doc-lint` の走査対象外
  (`scripts/doc-lint.sh` は `*.md` のみ) のため、この照合は手動または grep で行う
- **AC-5.4** 追加ルールが親 feature の確定制約と矛盾しないこと
  (4 層構成 / TDD / CI ゲート 3 本 / Agent 再発行の必須化 / dev 継続デプロイと本番一括切替)

### 3.6 本番ゲート (`08-production-gates.md`) との対応

- **AC-6.1** **D-2 (CI ゲート)** — 作業ループのどのステップで CI が回り、
  **マージ条件が何か**が定義されていること (雛形の `ci.yml` の各ジョブとループの対応)
- **AC-6.2** **D-4 (DB マイグレーション)** / **D-6 (Managed Agent のライフサイクル)** の
  人間承認が作業ループに埋め込まれていること (AC-4.2 と対応)
- **AC-6.3** **A 領域 (認証・テナント) / O 領域 (可観測性・LLM コスト)** については、
  本 feature は「**作業ループが必ずそのレビュー観点を通ることの担保**」に限定する。
  新規の A/O 設計は本 feature のスコープ外とし、**先送り先を親 feature productionization**
  (`docs/design/auth.md` · `observability.md`) と明記すること

### 3.7 設計プロセスの要件

- **AC-7.1** `make doc-lint` と `make check-traceability` が通ること (本 feature の追加分でエラーを増やさない)
- **AC-7.2** 成果物が**別セッションの `design-reviewer`** レビューを経て
  `aidlc-docs/reviews/construction-workflow/review.md` に記録されていること

## 4. 既定採用 (質問にせず推奨案をそのまま採る判断)

分岐がユーザー判断を要しない、または明らかに一択のものは質問にせず既定採用する。
**異論があれば指摘を** — その時点で questions へ格上げする。

| # | 判断 | 理由 |
|---|---|---|
| DF-1 | 実装リポに**独立した AIDLC ドキュメント一式を置かない**。作業計画は **issue 本文のテンプレート欄**で表現する | 設計リポの `requirements.md` / `plan.md` が唯一の要件・計画の SSOT (C-6 / C-8)。実装リポに計画文書を持つと二重管理になり、どちらが正か曖昧になる |
| DF-2 | 追加ルールの置き場所は **`templates/<repo>/.claude/rules/`** とし、番号付きファイル名 (設計リポと同じ命名) にする | 設計リポの rules 01〜08 と同じ手触りにすることで、両リポを往復する人間・エージェントの学習コストを下げる |
| DF-3 | 3 リポ共通のループ規約は **`templates/shared/.claude/rules/`** に置き、立ち上げ手順でコピーする (skills と同じ扱い) | AC-5.1 (同じ規約を 3 箇所に複製しない) の実装形。skills が既に同じ方式 ([templates/README.md](../../../templates/README.md) の立ち上げ手順) |
| DF-4 | **レビュー結果の保存先は PR 上** (レビューコメント or PR 本文) とし、実装リポにレビュー文書ファイルを置かない | 設計リポは push ゲートのために `review.md` をファイルで持つが、実装リポは PR という記録場所が既にある。ファイル化は差分ノイズになる |
| DF-5 | レビュー未実施の PR を止める仕組みは **GitHub 側のブランチ保護 (必須レビュー)** で担保し、設計リポのような push フックは実装リポに持ち込まない | F-5 の差 (実装リポ雛形に review ゲートが無い) の解消手段として、GitHub 標準機能の方が確実 (ローカルフックは回避できる) |
| DF-6 | **1 issue の作業ループは 1 セッションで完結させることを前提としない**。中断・再開のためにループの現在位置を issue コメントに残す | AI 駆動でもコンテキスト上限・人間承認待ちで中断は必ず起きる。再開点が残らないと二重実装・作業漏れになる |

## 5. 本番ゲート (08) の扱い

`.claude/rules/08-production-gates.md` の 3 領域に対する本 feature の立場:

| 領域 | 本 feature での扱い |
|---|---|
| **D (CI/CD・デプロイ・IaC)** | **主対象**。D-2 (CI ゲート) / D-4 (マイグレーション承認) / D-6 (Agent 再発行) を作業ループと人間チェックポイントに組み込む (AC-6.1 / AC-6.2)。成果物は D-3 (deploy.yml のロールバック手順) / D-5 (シークレットを GitHub 側に置かず、OIDC ロール経由で Secrets Manager / SSM から実行時に取得する形。2026-07-30 に親 feature の `docs/design/operations.md` §4.1 と整合させて是正) / D-7 (本番リリースの承認) にも機構面で回答している。**D-1 / D-8 の設計回答は親 feature が持つ** (`docs/design/architecture.md` §5 の表 — D-8 は回答済み、D-1 は部分回答で環境間の切り分けは運用設計で確定予定)。本増分は機構化のみ |
| **A (認証・テナント分離・権限)** | **レビュー観点としての担保のみ**。観点は [code-reviewer.md](../../../templates/backend-repo/.claude/agents/code-reviewer.md) に既に定義済み (A-1 / A-4 / A-6 相当) で、本 feature は「その レビューを必ず通す」ループを定める。**A の設計自体は先送り先 = 親 feature productionization** (`docs/design/auth.md`) |
| **O (可観測性・LLM コスト)** | 同上。**先送り先 = 親 feature productionization** (`docs/design/observability.md`)。本 feature では扱わない (AC-6.3) |

## 6. 回答状況 (2026-07-29 時点)

| Q | 内容 | 回答 | 反映先 |
|---|---|---|---|
| Q-1 | issue の粒度 | **A** (1 issue = 1 PR = 同じ層・同じ検証で閉じる AC 群) | AC-2.1 / AC-2.3 / AC-2.4 |
| Q-2 | 3 リポ跨ぎの issue / PR 構成 | **B** (リポごとに独立 issue。親子関係なし) — **推奨 A と異なる**。順序の担保は共通ルールのマージ順序規約 + issue テンプレートの「依存 issue (他リポ)」欄 + 人間による横断完了判定で補う ([questions.md](questions.md) Q-2 の回答注記) | AC-2.2 |
| Q-3 | 人間チェックポイントの範囲 | **B + 条件付き着手前承認** (4 点 + 新規ドメイン / 設計に無いパターン / 3 リポ跨ぎのみ着手前確認) | AC-4.1 / AC-4.2 |
| Q-4 | エージェントの自律範囲 | **A** (commit / push / PR 作成まで自律。マージのみ人間) | AC-4.3 |
| Q-5 | モデルエスカレーションの主体と基準 | **A + 実行中の昇格トリガー** (オーケストレーターが着手前判定 + 実行中 3 トリガー) | AC-3.1 / AC-3.2 |
| Q-6 | レビュー差し戻しの反復上限 | **A** (2 回まで。3 巡目前に人間へエスカレーション) | AC-1.3 |
| Q-7 | infra-repo のレビュー体制 | **A** (`infra-reviewer` を新設。`apply` の人間承認は維持) | AC-5.2 |

全問回答済み (2026-07-29)。回答は questions.md の `[Answer]:` 行を正とする。
