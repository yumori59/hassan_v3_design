# Workflow Plan: construction-workflow (実装リポの AI 駆動開発ワークフロー)

> 要件: [requirements.md](requirements.md) / 質問: [questions.md](questions.md)
> 親 feature: [productionization](../productionization/plan.md) (C-8 / AC-5.2 の具体化増分)
> ステータス: **Task-1〜7 完了 (2026-07-30)**。レビュー 2 巡: 1 巡目 重大 2 / 中 4 / 軽微 6 → 全件修正、
> 2 巡目 新規 中 1 / 軽微 1 → 修正済み。残タスクは Task-8 (実装リポ立ち上げ後の実測) のみ — Freeze 条件外。
> Q-1〜Q-7 全問回答済み。Q-2 のみ推奨と異なる **B** (独立 issue) — 順序担保の補完 3 点は
> `02-issue-granularity.md` §2 に反映済み。ID 名前空間: S-x (ループ) / V-x (DoD 機械検証) /
> M-x (モデル判定観点) / T-x (昇格トリガー) / H-x (人間承認点)。

## 1. 影響範囲

### 設計リポ側の成果物 (本 feature が変更するもの)

| 成果物 | 変更内容 | 新規/更新 |
|---|---|---|
| `templates/shared/.claude/rules/01-construction-loop.md` | 1 issue の作業ループ (**2 リポ共通**) | **新規** |
| `templates/shared/.claude/rules/02-issue-granularity.md` | issue の粒度・DoD・**リポ跨ぎ / サブツリー跨ぎ**の順序 | **新規** |
| `templates/shared/.claude/rules/03-model-escalation.md` | 既定モデル・昇格/降格の主体と基準 | **新規** |
| `templates/shared/.claude/rules/04-human-checkpoints.md` | 人間が必ず判断する点と記録先 | **新規** |
| `templates/<repo>/.github/ISSUE_TEMPLATE/` · `pull_request_template.md` | issue / PR テンプレート (**issue は 3 本: app の `task-backend.yml` / `task-frontend.yml` + infra の `task.yml` / PR は 2 本: app / infra**) | **新規** |
| `templates/infra-repo/.claude/agents/infra-reviewer.md` | infra のレビュー役 (Q-7=A の場合) | **新規** |
| `templates/app-monorepo/{CLAUDE.md.tmpl,backend/CLAUDE.md.tmpl,frontend/CLAUDE.md.tmpl}` · `templates/infra-repo/CLAUDE.md.tmpl` | 運用ルール表への索引追加・ハーネス節の更新 | 更新 |
| `templates/README.md` | 立ち上げ手順に rules / テンプレートのコピーを追加、`.claude/settings.json` の deny 指示を具体化 | 更新 |
| `templates/app-monorepo/backend/.claude/agents/go-developer.md` ほか計 5 定義 | モデル運用の記述をルールへの参照に統一 | 更新 |
| `aidlc-docs/aidlc-state.md` | feature 行の追加・進行更新 | 更新 |

### 実装リポ側で影響を受ける「層」

本 feature は製品コードの層ではなく**開発プロセスの層**に効く。対応関係:

| プロセス層 | 影響 |
|---|---|
| issue 管理 (GitHub) | テンプレート・ラベル (親/子・想定モデル)・DoD |
| ローカル開発 (Claude Code セッション) | オーケストレーターの手順・委譲プロンプト・中断/再開の記録 |
| pre-commit | 変更なし (既存のまま。ループのどこで走るかを明文化するだけ) |
| CI (`ci.yml`) | 変更なし。**マージ条件としての位置づけ**をループに明記 (AC-6.1) |
| デプロイ (`deploy-backend.yml`) | 人間承認 (environment) の適用範囲を確定 (AC-4.2) |
| GitHub 設定 (リポジトリ側) | ブランチ保護・必須レビュー・environment 承認者 — **雛形で自動化できないため手順書として渡す** |

### 本番ゲート (`08-production-gates.md`) の該当 ID

- **主対象**: D-2 (CI ゲート) / D-4 (マイグレーション承認) / D-6 (Agent 再発行)
- **レビュー観点としての担保のみ**: A-1 / A-4 / A-6 / O-2 / O-4 (設計は親 feature。AC-6.3 で先送り先を明記)

## 2. 受入基準 → 検証方法

「設計側 (本リポジトリ) でどう確認するか」と「実装リポでどう効くか」を分けて書く。
**★ の付いた行は機械照合 (grep / doc-lint) が可能** — 残りは `design-reviewer` の確認事項。

| AC | 設計側の検証 | 実装リポでの効き方 |
|---|---|---|
| AC-1.1 | `01-construction-loop.md` にステップ表 (入力/出力/担当) が存在 ★ | オーケストレーターがループ表どおりに委譲する |
| AC-1.2 | 同ルールに Red/Green の裏取り手段が明記 | テスト出力の提示なしの「完了」報告を受理しない |
| AC-1.3 | 同ルールに差し戻し上限とエスカレーション先 (Q-6 の値) | 3 巡目に入る前に issue へコメントして停止 |
| AC-1.4 | 同ルールに設計リポ差し戻しの判定条件と issue の状態遷移 | 設計に無いパターンで実装を止め、設計リポへ質問を起票 |
| AC-1.5 | 同ルールに直列必須/並列可の区別表 | 独立 issue の並列着手・同一 issue 内の直列を守る |
| AC-1.6 | 同ルール §6 に中断・再開の記録形式・更新タイミング・再開手順 ★ | 中断した issue を別セッション・別日でも再開できる |
| AC-2.1 | `02-issue-granularity.md` に 1 issue の単位定義 (Q-1 の値) | issue 起票時の分割判断 |
| AC-2.2 | 同ルールにリポ跨ぎ / サブツリー跨ぎの分割と PR マージ順序 (API 互換順序を含む) | 親 issue に順序を書き、子 issue から参照 |
| AC-2.3 | `.github/ISSUE_TEMPLATE/` の issue テンプレートが **3 本** (app の `task-backend.yml` / `task-frontend.yml` + infra リポの `task.yml`) 存在し必須 5 欄を含む ★ | issue 起票時に欄が強制される |
| AC-2.4 | 同ルールに DoD (機械検証項目 / 人間判断項目の区別) | PR テンプレートのチェックリストとして機能 |
| AC-3.1 | `03-model-escalation.md` に既定モデル表 + 昇格/降格の主体・根拠 ★ | 委譲時に `model:` を明示指定 |
| AC-3.2 | 同ルールに実行中の昇格トリガー (3 条件) | Red 不成立・重大指摘反復で opus へ切替 |
| AC-4.1 | `04-human-checkpoints.md` に承認点一覧 (見るもの・記録先) ★ | 人間が待ち行列になる箇所が事前に分かる |
| AC-4.2 | `deploy-backend.yml` の environment 承認 + `settings.json` deny 指示 + 手順書に反映 ★ | 機構で止まる (規約文書だけにしない) |
| AC-4.3 | `templates/README.md` の立ち上げ手順に自律範囲の deny/allow 指示 ★ | `.claude/settings.json` に落ちる |
| AC-5.1 | 共通ルールが `templates/shared/` に 1 部だけ存在し、各リポに複製が無い ★ | 規約の二重管理が起きない |
| AC-5.2 | infra のレビュー役が実装役と分離 (Q-7 の値) ★ | 自己レビュー禁止が backend / frontend / infra のすべてで成立 |
| AC-5.3 | 3 つの `CLAUDE.md.tmpl` の運用ルール表に追加ルールが索引され `make doc-lint` が 0 エラー ★ | 実装リポで参照漏れが起きない |
| AC-5.4 | 追加ルールと親 feature の確定制約 (4 層 / TDD / CI ゲート 3 本 / Agent 再発行 / dev 継続デプロイ) の矛盾なし | 既存設計と衝突しない |
| AC-5.5 | **MR-1〜MR-6 が ①雛形に実体としてある ②機械検査できるものは `make check-monorepo-ci` の対象 ③できないものは立ち上げチェックリストの設定項目**、の 3 分類に全件が入っている ★ | モノレポ化で新規に要る担保が「宣言だけ」で終わらない (**MR-1 の指定を誤ると PR が永久 pending**) |
| AC-6.1 | ループ表の各ステップに CI ジョブとマージ条件が対応付けられている | PR のマージ条件が機械強制される |
| AC-6.2 | 承認点一覧に D-4 / D-6 が含まれ、`deploy-backend.yml` の該当ステップと対応 ★ | マイグレーションと Agent 再発行が人間承認を通る |
| AC-6.3 | A / O 領域の扱いと**先送り先の明記** (親 feature の該当設計書) がルール本文にある | 「レビュー観点として通す」だけと分かる |
| AC-7.1 | `make doc-lint` / `make check-traceability` が本 feature の追加分でエラーを増やさない ★ | — |
| AC-7.2 | `aidlc-docs/reviews/construction-workflow/review.md` が存在し、変更した成果物の相対パスを含む ★ | push ゲートが通る |

## 3. タスクと依存関係

### 直列必須

```
Q-1〜Q-7 の回答 (または暫定既定の確定)
  → Task-1 (作業ループの骨格) … 他タスクの参照枠になる
  → Task-2 / Task-3 / Task-4 / Task-5 (並列)
  → Task-6 (索引・整合。全成果物を参照するので最後)
  → Task-7 (別セッションで design-reviewer)
```

理由: Task-2〜5 は「ループのどのステップの話か」を参照して書くため、**ステップ表が先に無いと
節の切り方が揃わない**。Task-6 は 3 つの `CLAUDE.md.tmpl` と `README.md` を触るため、
他タスクと**同一ファイルの同時編集**になるのを避けて最後に単独で行う (`03-parallel-development.md`)。

### タスク一覧

| # | タスク | 成果物 | 担当 | 依存 | 対応 AC |
|---|---|---|---|---|---|
| Task-1 | **1 issue の作業ループの起草** — ステップ表 (入力/出力/担当)・Red/Green の裏取り・差し戻し上限・設計リポ差し戻し・並列可否・中断/再開の記録 (DF-6) | `templates/shared/.claude/rules/01-construction-loop.md` | `architecture-designer` | Q 回答 (暫定可) | AC-1.1〜AC-1.6 / AC-6.1 |
| Task-2 | **issue 粒度・DoD・リポ跨ぎ / サブツリー跨ぎの順序** + issue/PR テンプレート | `templates/shared/.claude/rules/02-issue-granularity.md` / `templates/<repo>/.github/ISSUE_TEMPLATE/*` / `pull_request_template.md` | `architecture-designer` | Task-1 | AC-2.1〜AC-2.4 |
| Task-3 | **モデル運用ルール** + 既存エージェント定義 5 本のモデル記述の整合 | `templates/shared/.claude/rules/03-model-escalation.md` + `go-developer.md` / `code-reviewer.md` / `react-developer.md` / `frontend-reviewer.md` / `infra-engineer.md` の該当ブロック | `architecture-designer` | Task-1 | AC-3.1 / AC-3.2 |
| Task-4 | **人間チェックポイントの確定と機構への落とし込み** — 承認点一覧 + `deploy-backend.yml` の environment 承認 + `settings.json` deny 指示 + GitHub 設定手順書 | `templates/shared/.claude/rules/04-human-checkpoints.md` / `templates/app-monorepo/.github/workflows/deploy-backend.yml` (更新) | `architecture-designer` | Task-1 | AC-4.1〜AC-4.3 / AC-6.2 |
| Task-5 | **infra のレビュー役の整備** (Q-7=A なら新設。B/C なら運用ルールのみ) | `templates/infra-repo/.claude/agents/infra-reviewer.md` | `architecture-designer` | Q-7 | AC-5.2 |
| Task-6 | **索引と整合** — 3 つの `CLAUDE.md.tmpl` の運用ルール表・ハーネス節、`templates/README.md` の立ち上げ手順 (rules / テンプレートのコピー・deny 指示)、共通ルールの重複が無いことの確認 | 上記 4 ファイル (更新) | メインセッション | Task-1〜5 | AC-5.1 / AC-5.3 / AC-5.4 / AC-6.3 / AC-7.1 |
| Task-7 | **レビュー** — 別セッションで `design-reviewer` (本番基準・DR 全件 + 08 の D 領域) | `aidlc-docs/reviews/construction-workflow/review.md` | `design-reviewer` (別セッション) | Task-6 | AC-7.2 |
| Task-8 | **(先送り) 最初の 1 issue でループを実測**し、ルールを実態に合わせて更新 | 実装リポ側の issue / PR + 本 feature のルール更新 | 手動 (実装リポ立ち上げ後) | 実装リポの存在 | AC-1.1 の実効性確認 |

> Task-8 は本リポジトリでは完了できない (実装リポが未作成)。**Design Freeze の条件には含めず**、
> 「雛形は初期値であって SSOT ではない」(C-6) の運用として引き渡す。

## 4. 並列実行可能なタスク

| フェーズ | 並列可能 | 直列必須の理由 |
|---|---|---|
| 起票直後 | **Q 回答の取得 (ユーザー)** と **Task-1 の起草** (暫定既定で先行可) | Task-1 は枠組み。値 (粒度・上限・承認点) は後から差し替え可能な構造にする |
| 本体 | **Task-2 / Task-3 / Task-4 / Task-5 の 4 並列** ← すべて `architecture-designer` | 触るファイルが重複しない (shared の別ファイル / 各リポの別ファイル)。ただし Task-3 は 5 つのエージェント定義を単独で触るため、他タスクにそれらを触らせない |
| 仕上げ | なし (Task-6 は単独) | `CLAUDE.md.tmpl` × 3 と `README.md` に全タスクの結果が集約されるため |
| レビュー | なし (Task-7 は 1 セッションで差分全体) | レビューは集約する (`03-parallel-development.md`) |

**並列時の衝突回避**: 4 並列で走らせる場合、各委譲プロンプトに
「**このタスクが編集してよいファイルは以下のみ**」を明記する (他タスクの成果物ファイル名を列挙して禁止する)。

## 5. 各タスクの委譲プロンプト要点 (`06-delegation-prompts.md` の 7 要素)

Task-1 の例 (他タスクも同形式で書く):

1. **目的/背景**: 実装リポ (backend / frontend / infra) で 1 issue を回す手順が未定義 (F-1)。
   出力は実装リポの `.claude/rules/` にコピーされ、オーケストレーターの行動規範になる
2. **対象**: `/Users/yuyamorishita/aillio/hassan/hassan_v3/templates/` (読み)、
   出力先 `templates/shared/.claude/rules/01-construction-loop.md` (新規)
3. **やること**: ①ステップ表 (入力/出力/担当) ②Red/Green の裏取り手段 ③差し戻し上限と
   エスカレーション ④設計リポ差し戻しの判定 ⑤並列可否 ⑥中断/再開の記録方法
4. **従うべき既存例**: 設計リポの `.claude/rules/01-aidlc.md` · `02-agents.md` · `04-review.md` の
   書式と粒度 / `templates/app-monorepo/backend/.claude/agents/go-developer.md` の完了条件節
5. **制約**: 参照リポジトリ (`claude_managed_agents` / `hassan-v2-*`) を読まない・編集しない /
   `docs/design/` を変更しない / 製品コードを書かない / **Task-2〜5 の対象ファイルを触らない** /
   確定制約 C-1〜C-9 と暫定既定 (Q-1〜Q-7 の推奨案) を前提にする
6. **完了条件**: `make doc-lint` が本タスクの追加分で 0 エラー / AC-1.1〜AC-1.5 と AC-6.1 に
   1 対 1 で対応する記述があること (対応表を報告に含める)
7. **報告フォーマット**: 日本語で ①成果物のパス ②検証結果 (実行コマンドと出力)
   ③残課題・要確認 (暫定既定に依存した箇所を明記)

## 6. 完了の定義 (Design Freeze)

- [ ] `make check` (4 ゲート) が通る — 本 feature の追加分でエラーを増やさない (AC-7.1)
- [ ] Q-1〜Q-7 に回答済み、または**暫定既定を採用した旨がルール本文と requirements §6 に明記**されている
- [ ] `08-production-gates.md` の D-2 / D-4 / D-6 に回答があり、A / O 領域は
      「レビュー観点としての担保 + 先送り先」が明記されている (AC-6.3)
- [ ] 別セッションの `design-reviewer` で**重大ゼロ** (AC-7.2)
- [ ] 実装リポへの引き渡しが揃っている: 追加ルール 4 本 + テンプレート + 立ち上げ手順の更新 +
      **GitHub 側で人手設定が必要な項目のリスト** (ブランチ保護・必須レビュー・environment 承認者)

## 7. リスクと前提

| # | リスク / 前提 | 扱い |
|---|---|---|
| R-1 | **ルールを書いても実行されない** (設計リポの rules と同じ問題)。実装リポでは `CLAUDE.md` からの索引と pre-commit / CI が唯一の強制経路 | AC-4.2 で「機構で担保」を要求。文書だけの承認点を作らない |
| R-2 | **雛形と実装リポの乖離** (C-6)。切り出し後にルールを直しても反映されない | Task-8 として明示的に先送りし、引き渡し時に「乖離は実装リポ側が正」を伝える |
| R-3 | 暫定既定で書いたルールが後から覆る | ルールの値 (粒度・上限・承認点) を**表の 1 セル**に集約し、差し替え箇所を局所化する |
| R-4 | issue テンプレートの必須欄が多すぎて運用されない | 必須欄は AC-2.3 の 5 欄に限定し、任意欄と分ける |
| R-5 | **並行する増分 `layering` と CI ゲートが競合する** — [requirements-layering.md](../productionization/requirements-layering.md) の AC-6.14 / AC-6.15 が depguard・`funlen` の CI 検査を追加する予定であり、本 feature の AC-6.1 (ループ上の CI ゲートとマージ条件) と同じ `ci.yml` を指す | Task-6 で**両者の CI ゲート一覧を突き合わせる**。本 feature はゲートの「追加」をせず、既存 + layering 側のゲートを**ループ上のどのステップでどう効くか**の記述に限定する |
