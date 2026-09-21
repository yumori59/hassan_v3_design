# レビュー: Q-12 preview の FE/BE 接続先 PR 上書き

> レビュアー: `design-reviewer` (起草セッションとは別セッション) / 日付: **2026-09-21**
> 対象範囲: `origin/main...HEAD` (コミット 917e405 の 1 本のみ)
> 決定: **Q-12 = B** (2026-09-21 ユーザー決定) — PR 本文の HTML コメントで接続先 BE を上書き。
> 実装リポ issue: hassan-v3 **#420** (`blocked-by-design`)
> 参照ルール: [04-review.md](../../../.claude/rules/04-review.md) /
> [08-production-gates.md](../../../.claude/rules/08-production-gates.md) /
> [feedback_review_patterns.md](../../../.claude/rules/feedback_review_patterns.md)

## レビュー結果サマリ

### 対象ファイル (リポジトリ相対パス。`git diff origin/main...HEAD --stat` の全 4 ファイル)

**設計成果物**
- `docs/design/operations.md` (§5.1.2 に「FE/BE の接続先 PR 上書き」を追加。13 行)
- `aidlc-docs/inception/productionization/questions.md` (Q-12 追加。39 行)

**状態管理**
- `aidlc-docs/aidlc-state.md` (履歴 1 行)
- `todo.html` (SEED 2 行: Q-12 設計を完了、レビューを追加)

### 件数

| 分類 | 件数 |
|---|---|
| **重大 (Must Fix)** | **0** |
| **中 (Should Fix)** | **0** |
| **軽微 (Nice to Have)** | **3** |
| 良かった点 | 5 |

### 実行した検証

| # | 検証 | 結果 |
|---|---|---|
| 1 | `make check` (全ゲート) | **エラー 0・全ゲート緑** (詳細は §「make check の出力」) |
| 2 | `make doc-lint` | 対象 123 ファイル / **エラー 0** / 警告 59 件 (既存の「TODO」語・未回答 `[Answer]` のみ。Q-12 由来の新規警告なし) |
| 3 | `make check-traceability` | construction-workflow 25/25 / productionization **125/125** — OK |
| 4 | 抜き取り照合 **3 件** (うち 1 件は結論を左右するもの) | 全件一致 (下記 §「抜き取り照合」) |
| 5 | DR-8 波及 grep (`preview-connect` / `BACKEND_ORIGIN` / `接続先`) | Q-12 が触れない文書に取り残し無し |

---

## 重大 (Must Fix)

**なし (重大ゼロ)**。

---

## 中 (Should Fix)

**なし**。

---

## 軽微 (Nice to Have)

### 軽微 1: §5.1.2 の既存 PR 値表の `NEXT_PUBLIC_API_BASE_URL` との同一セクション内の名前不一致

- `docs/design/operations.md:410` (既存。Q-12 以前から存在) — PR ごとの値と注入経路の表に
  `NEXT_PUBLIC_API_BASE_URL=https://pr-<N>-api.dev.<domain>` と記載。
  Q-12 追加テキスト (`docs/design/operations.md:425`) は正しく `BACKEND_ORIGIN` を使用。
- **問題**: 同一セクション §5.1.2 内で FE → BE の接続変数が 2 つの名前で登場する。
  `questions.md` Q-12 が「段階1 名 `NEXT_PUBLIC_API_BASE_URL` との名前差は本 Q の範囲外
  （preview 経路では `BACKEND_ORIGIN` が正）」と明記しており Q-12 の判断として正当。
- **推奨**: 先送り先の追跡用に、operations.md:410 の表の FE 行に 1 文の注記
  (例:「BFF 方式への統一後は `BACKEND_ORIGIN` に改名。下記 Q-12 参照」) を添えるか、
  aidlc-state.md の Q-12 行に先送り先を書く。次に operations.md §5.1.2 を触る差分で是正でもよい。
- **実装への影響**: 実装リポの `task-def-fe.json:26` は既に `BACKEND_ORIGIN` を使用しており
  (`deploy-preview.yml:355-356` のコメントで `NEXT_PUBLIC_API_BASE_URL` 不使用を明記)、
  設計文書の旧名が実装を誤導するリスクは低い。

### 軽微 2: 「teardown が SSM をまだ消さない」の出典不記載

- `docs/design/operations.md:428` — 「生存判定に SSM `/hassan-v3/dev/pr-<N>/active` は使わない
  — **teardown が SSM をまだ消さない**ため」。
- **事実は確認済み** (下記抜き取り照合 #3)。ただし実装リポのファイル:行への明示的な出典がない。
  設計の根拠となる実装状態の事実であるため、出典があると読者が裏取りしやすい
  (例:「deploy-preview.yml teardown ⑤ が未実装のため」)。
- **実装への影響**: 設計判断 (ECS サービス存在で判定) は teardown ⑤ が将来実装されても正しい
  (ECS サービスの存在は SSM マーカーより直接的な生存証拠)。出典の有無は設計の正しさに影響しない。

### 軽微 3: questions.md Q-12 の「回答の含意」に実装リポ deploy-preview.yml の具体パスへの参照がない

- `aidlc-docs/inception/productionization/questions.md:492`〜`:505` — 回答の含意は
  設計文書へのリンク (`operations.md` / `infrastructure.md` / `frontend.md`) を持つが、
  実装リポのワークフロー (`deploy-preview.yml`) や タスク定義 (`stacks/dev-preview/task-def-fe.json`)
  への参照がない。
- **推奨**: issue #420 へ転記する際に実装リポのパスを書けば足りるため、questions.md 側は任意。
  起票経緯に「実装リポ hassan-v3 issue #420」が記載されており追跡は可能。

---

## 良かった点

1. **却下案が充実し、各案の却下理由が具体的** — operations.md の却下案 5 件
   (①`workflow_dispatch` / ②BE の CORS 追加 / ③自動復帰 / ④`/active` マーカー / ⑤`/deploy` 相乗り)
   はすべて「なぜ不採用か」が 1 文で明記されている。特に ④は teardown の未実装状態を根拠にしており、
   実装者が代替案を再検討する際の判断材料が揃っている。

2. **BFF による CORS 不要の理由が正確に記述** — 「preview FE は BFF なのでブラウザ → BE の CORS は
   通常発火しない」が、BE の `ALLOWED_ORIGINS` / `FRONTEND_BASE_URL` を変えない理由として
   明示されている。これにより `infrastructure.md` §5.3 の「1 件だけ許可」規則を
   維持しながらクロス接続を実現する設計根拠が閉じている。

3. **fail-closed の条件が網羅的かつ明確** — 存在しない PR / ECS サービス不在 /
   コメント複数・未知キー / fork PR の 4 条件が列挙され、各々の結果
   (構築ジョブ失敗 + PR コメント) まで書かれている。曖昧語 (DR-5) がない。

4. **影響範囲の限定が明示的** — Q-12 が変えるのは「FE タスクの `BACKEND_ORIGIN` だけ」、
   変えないのは「BE の `ALLOWED_ORIGINS` / `FRONTEND_BASE_URL`」「同時プレビュー上限」
   「infrastructure.md の INF-U」と、変更 / 非変更の両面が書かれている。
   設計の修正波及 (DR-8) を最小化する意識が見える。

5. **接続先 teardown 時の非対称な振る舞いが意図的に設計されている** — 「自動復帰しない +
   PR にコメントする + 次回 provision/redeploy で fail-closed」は、
   却下案③ (自動復帰すると検証結果が黙って別 BE を指す) の裏返しとして一貫している。

---

## 抜き取り照合

### 照合 #1: `SERVICE_NAME_BE=hassan-v3-preview-be-pr-${PR_NUMBER}` (結論を左右する事実)

- **設計の主張**: `docs/design/operations.md:428` — 「ECS 上に BE サービス
  `hassan-v3-preview-be-pr-<N>` が無い」場合に fail-closed。
- **実装リポの実物**: `/Users/yuyamorishita/aillio/hassan/hassan-v3/hassan-v3/.github/workflows/deploy-preview.yml:601`
  — `SERVICE_NAME_BE="hassan-v3-preview-be-pr-${PR_NUMBER}"`。同 `:772` (redeploy) / `:900` (teardown) /
  `:989` (delete 時の check_and_delete 呼び出し) でも同一の命名パターン。
- **結果**: **一致**。設計のサービス名パターンと実装が同一。

### 照合 #2: FE タスク定義で `BACKEND_ORIGIN` が環境変数として注入されていること

- **設計の主張**: `docs/design/operations.md:425` — 「変える値: FE タスクの **`BACKEND_ORIGIN` だけ**」。
- **実装リポの実物**: `/Users/yuyamorishita/aillio/hassan/hassan-v3/hassan-v3/stacks/dev-preview/task-def-fe.json:26`
  — `"name": "BACKEND_ORIGIN", "value": "https://{{ must_env HOST_BE }}"` (BFF 方式のサーバー専用環境変数)。
  `deploy-preview.yml:591` / `:763` で `export BACKEND_ORIGIN="https://${HOST_BE}"` として注入。
  同 `:355-356` のコメント: `NEXT_PUBLIC_API_BASE_URL は frontend/src で未使用 (BFF 方式。BACKEND_ORIGIN を
  タスク定義の実行時環境変数として別途注入する)`。
- **結果**: **一致**。`BACKEND_ORIGIN` が FE タスクの唯一の BE 接続変数であり、BFF 方式の事実も確認。

### 照合 #3: teardown が SSM `/active` マーカーを消さないこと

- **設計の主張**: `docs/design/operations.md:428` — 「teardown が SSM をまだ消さないため、
  『マーカーがある = 生きている』は成立しない」。
- **実装リポの実物**: `/Users/yuyamorishita/aillio/hassan/hassan-v3/hassan-v3/.github/workflows/deploy-preview.yml:1045-1049`
  — teardown ステップ ⑤ は `echo` のみのプレースホルダ:
  `echo "(Agent を削除し、/hassan-v3/dev/pr-${PR_NUMBER}/ 配下の SSM パラメータを再帰的に削除する)"`。
  実際の `aws ssm delete-parameters` は実装されていない。
- **結果**: **一致**。teardown ⑤ は未実装であり、SSM `/active` マーカーは破棄後も残る。

---

## 本番観点カバレッジ

Q-12 は**既存のプレビュー環境機構への小規模な追加** (接続先の上書き) であり、新しいテーブル・
エンドポイント・LLM 経路・認証経路を追加しない。本番観点の網羅チェックは以下の通り:

| ID | 状態 | 備考 |
|---|---|---|
| A-1〜A-7 | **対象外 (変更なし)** | 認証・テナント・権限に新規経路を追加しない。既存の preview の認証はワークフローの OIDC + `environment: dev-preview` で担保 |
| O-1〜O-7 | **対象外 (変更なし)** | 新規のログ・計測・コスト経路を追加しない |
| D-1 | **回答あり** | operations.md §5.1.2 の既存の環境分離に追加。変えるのは FE の `BACKEND_ORIGIN` のみ |
| D-2〜D-5 | **対象外 (変更なし)** | CI ゲート・デプロイ手順・DB マイグレーション・シークレット管理に変更なし |
| D-6 | **対象外 (変更なし)** | Agent の発行経路に変更なし |
| D-7〜D-8 | **対象外 (変更なし)** | 段階リリース・IaC 管理範囲に変更なし |

Q-12 が「クロス接続では BE の env を変えない」と限定しているため、本番観点の新規対応が不要なのは妥当。
**無言の省略 (DR-2) は無い** — Q-12 自身が「変えない」ものを明示的に列挙している。

---

## make check の出力 (2026-09-21 実行)

```
[doc-lint]          対象 123 ファイル / エラー 0 件 / 警告 59 件 (既存の TODO 語・未回答 [Answer] のみ)
[traceability]      construction-workflow: 25/25 カバー — OK
[traceability]      productionization: 125/125 カバー — OK
[workflow-shell]    検査 61 ブロック / エラー 0 件
[table-counts]      機能テーブル 44 (個人 35 / 契約 9) / 照合 37 件 / エラー 0 件
[endpoint-mapping]  9 ドメイン 114 本 / 403 17 本 / 照合 44 件 / エラー 0 件
[template-sync]     照合 1 組 / エラー 0 件
[monorepo-ci]       照合 59 件 / エラー 0 件
```

**エラー 0・全ゲート緑**。

---

## 総評 (Freeze 可否)

**Freeze 可 (push/PR 可)**。**重大ゼロ・中ゼロ**。

Q-12 は影響範囲の小さい追加 (operations.md §5.1.2 に 13 行 + questions.md に質問と回答) で、
設計判断の核 (変えるのは `BACKEND_ORIGIN` のみ / BFF なので CORS 不問 / fail-closed /
自動復帰しない) がすべて理由と却下案つきで書かれている。事実の抜き取り照合 3 件で
実装リポとの整合を確認し、`make check` 全ゲート緑。

軽微 3 件はいずれも Freeze をブロックしない (先送り先の追跡 / 出典の補完 / 実装リポパスの参照)。
次に operations.md §5.1.2 を触る差分 (または BFF 統一確定時) で軽微 1 を是正すればよい。
