# Questions: construction-workflow (実装リポの AI 駆動開発ワークフロー)

> 本 feature が決めるのは「**実装リポジトリ (backend / frontend / infra) で 1 issue をどう回すか**」の運用規約。
> 対象成果物は [templates/](../../../templates/README.md) 配下のルール追加と `CLAUDE.md.tmpl` の更新のみ
> (製品コード・`docs/design/` の設計は本 feature のスコープ外)。
> 要件: [requirements.md](requirements.md) / 計画: [plan.md](plan.md)
>
> **確定事項は問わない**: AIDLC ベースの維持 / TDD / 実装とレビューのサブエージェント委譲 /
> templates は雛形 (切り出し後は実装リポ側が正) — 一覧は [requirements.md](requirements.md) §2。
>
> 回答は `[Answer]:` 行に書く。未回答のまま進める場合は `> 推奨:` を暫定既定として
> [requirements.md](requirements.md) §6 に「既定採用」と明記して設計を進める。

**現状の穴 (実測 2026-07-29)**:

| # | 事実 | 出典 |
|---|---|---|
| F-1 | 実装リポ雛形に `.claude/rules/` が無い。コピー対象は `feedback_review_patterns.md` 1 本のみで、**作業の順序を定める運用ルール (設計リポの rules 01〜06 相当) が存在しない** | [templates/README.md](../../../templates/README.md) の立ち上げ手順 |
| F-2 | `templates/` 全体で「issue」の語が出るのは GitHub API 呼び出しの 2 行だけ (`github.rest.issues.createComment`)。**C-8「GitHub issue 駆動」を担保する機構が実装リポ側に無い** | [templates/infra-repo/.github/workflows/ci.yml](../../../templates/infra-repo/.github/workflows/ci.yml) の PR コメント処理 |
| F-3 | モデルの昇格は「**呼び出し側が `model: opus` を指定してエスカレーションする**」と書かれているのみで、判断主体・タイミング・根拠が未定義 | [go-developer.md](../../../templates/backend-repo/.claude/agents/go-developer.md) 冒頭の引用ブロック / [code-reviewer.md](../../../templates/backend-repo/.claude/agents/code-reviewer.md) 同 |
| F-4 | 人間の承認は断片的に存在する (prod デプロイ = `workflow_dispatch` + GitHub environment / infra の `apply` = autoMode deny) が、**一覧として定義されていない**。DB マイグレーションと Agent 再発行はワークフロー雛形で未実装のまま | [templates/backend-repo/.github/workflows/deploy.yml](../../../templates/backend-repo/.github/workflows/deploy.yml) / [templates/infra-repo/CLAUDE.md.tmpl](../../../templates/infra-repo/CLAUDE.md.tmpl) のハーネス節 |
| F-5 | 設計リポには push 前レビューを強制するフック (`scripts/hooks/require-review-before-push.sh`) があるが、**実装リポ雛形の hooks は `pre-commit` 1 本のみ**でレビューゲートが無い | `templates/*/scripts/hooks/` の内容 |
| F-6 | infra-repo のエージェントは `infra-engineer` 1 体で「**Terraform 実装・レビューエージェント**」と兼任定義。backend/frontend は実装役とレビュー役が分かれている | [templates/infra-repo/CLAUDE.md.tmpl](../../../templates/infra-repo/CLAUDE.md.tmpl) の運用ルール表 |

---

## Q-1. issue の粒度 (1 issue = 何単位か)

C-8 は「GitHub issue 駆動」を定めるが、切り方は未定義 (F-2)。
設計リポ側の受入基準は **AC-ID** 単位で存在し、実装リポの `go-developer` は
**テスト名に AC-ID を埋める**規約を既に持っている
([go-developer.md](../../../templates/backend-repo/.claude/agents/go-developer.md) の TDD 節)。

- **A. 1 issue = 1 PR = 「同じ層・同じ検証手段で閉じる AC 群」** — issue 本文に対象 AC-ID を列挙する。
  1 AC で 1 issue になることも、関連 3 AC で 1 issue になることもある
- **B. 1 issue = 1 AC-ID** (厳密 1:1) — 対応が機械照合できるが、issue と PR が細かく大量になる
- **C. 1 issue = 設計リポ `plan.md` の 1 タスク (Task-x)** — 設計側の分解をそのまま持ち込む
- **D. 1 issue = 1 機能** (複数 PR を束ねる。PR は issue の中で任意に切る)
- E. Other (please describe after [Answer]: tag below)

> 推奨: **A**。理由: AI 駆動では「レビュー 1 回で読み切れる差分」が実質的な上限になるため、
> **1 issue = 1 PR = 1 レビューセッション**を不変条件に置くのが運用しやすい。
> B は 1 AC が Controller/UseCase/Service/Repository とテストに跨る場合に PR が細分化されすぎ、
> マージ順序の管理コストが増える。C は設計リポのタスク (= 設計成果物単位) が実装単位と一致しない。
> D は「1 issue が閉じない」状態が長期化し、進捗が観測できなくなる。

**この回答が左右するもの**: AC-2.1 / AC-2.3 (issue テンプレートの受入基準欄の形) /
issue ↔ AC-ID ↔ テスト名の照合を CI で機械化できるか (AC-2.4)。

[Answer]: A (2026-07-29) — 1 issue = 1 PR = 「同じ層・同じ検証手段で閉じる AC 群」

---

## Q-2. 3 リポ跨ぎの機能の issue / PR 構成とマージ順序の担保

[templates/README.md](../../../templates/README.md) は
「1 機能の変更が 3 リポに跨るとき、PR が 3 本になり**順序の担保が人手になる**」と課題を明記している。
API 破壊的変更の順序 (backend で新旧併存 → frontend 切替 → 旧削除) も同ファイルに定義済み。

- **A. 親 issue (backend リポに置く) + 各リポの子 issue** — 親に順序と依存を書き、
  子 issue には「親 #N のステップ 2」と明記する。3 リポの横断は backend リポの親 issue が SSOT
- **B. リポごとに独立した issue** — 横断の順序は PR 説明に書く。親子関係は持たない
- **C. 設計リポ (hassan_v3) に横断 issue を置く** — 実装リポの issue はその子とする
- E. Other (please describe after [Answer]: tag below)

> 推奨: **A**。理由: 順序の担保には「順序を書く場所が 1 箇所であること」が必要で、B は
> 3 本の PR 説明に分散するため漏れが検出できない。C は「設計リポは製品コードを持たない」方針
> (ルート `CLAUDE.md`) と噛み合うが、**実装の進行管理が設計リポに逆流する**ため、
> Design Freeze 後の設計リポが実装の進捗ボードになってしまう。
> A の代償は「親 issue の置き場所が backend に偏る」ことだが、
> 依存順序 (infra → backend → frontend) の中間にあるのは backend なので実害が小さい。

**この回答が左右するもの**: AC-2.2 / issue テンプレートに「親 issue」欄を持たせるか /
リポ横断の完了判定を誰が行うか (AC-4.1 の人間チェックポイントと連動)。

[Answer]: B (2026-07-29) — リポごとに独立した issue。親子関係は持たない。
**推奨 A と異なる選択のため設計で補う点**: 順序の SSOT を issue の親子構造で持てないので、
① 3 リポ共通ルールに「リポ跨ぎのマージ順序規約」(infra → backend → frontend / API 互換順序) を固定で書く
② issue テンプレートに「依存 issue (他リポ)」欄を設け、依存先がマージ済みかを着手前チェックに含める
③ リポ横断の完了判定は人間が行う (Q-3 の着手前承認条件「3 リポ跨ぎ」と連動) — を AC-2.2 の設計に含めること

---

## Q-3. 人間が必ず判断するポイントの範囲

F-4 のとおり承認は断片的に存在するのみ。**AI 駆動でも人間が必ず見る点**を確定する必要がある。

- **A. PR マージのみ** — それ以外 (実装・レビュー・dev デプロイ・マイグレーション適用) はエージェントと CI に委ねる
- **B. 4 点: PR マージ / DB マイグレーション適用 / Managed Agent 再発行 / 本番デプロイ**
- **C. B + 着手前の計画承認 (issue の受け入れ)** = 5 点。エージェントが立てた実装計画を人間が見てから着手する
- **D. C + レビュー結果の確認** = 6 点。`code-reviewer` の指摘を人間が読んでから修正に入る
- E. Other (please describe after [Answer]: tag below)

> 推奨: **B**、ただし**着手前承認 (C の追加分) は条件付きで要求する** —
> 「新規ドメインの追加」「設計書に無いパターンの実装」「3 リポ跨ぎ」の 3 条件のいずれかに該当する
> issue のみ、着手前に計画を人間が確認する。理由: 全 issue で着手前承認を要求すると
> AI 駆動の利点 (待ち時間ゼロで着手) が失われる一方、**設計に無い判断が実装で発生する issue** は
> 手戻りが最大になるため、そこだけ人間を挟むのが費用対効果が高い。
> D は、レビュー指摘の反映は機械的で人間の判断余地が小さいため過剰
> (ただし**差し戻しが上限に達した場合は人間へ上げる** — Q-6)。

**この回答が左右するもの**: AC-4.1 / AC-4.2 (承認を機構で担保する範囲) /
issue テンプレートの「人間チェックポイント」欄 / deploy ワークフローの environment 承認設定。

[Answer]: B + 条件付き着手前承認 (2026-07-29) — 4 点 (PR マージ / DB マイグレーション適用 /
Managed Agent 再発行 / 本番デプロイ) + 「新規ドメイン追加・設計書に無いパターン・3 リポ跨ぎ」の
いずれかに該当する issue のみ着手前に計画を人間が確認する

---

## Q-4. エージェントの自律範囲 (commit / push / PR 作成)

グローバル方針は「**コミット・push はユーザーが明示的に依頼したときのみ**」であり、実装エージェント側も
「ユーザー指示なしのコミット/プッシュ」を禁止事項に挙げている
([go-developer.md](../../../templates/backend-repo/.claude/agents/go-developer.md) の「やってはいけないこと」)。
一方 issue 駆動 + PR ベースを AI 駆動で回すなら、この線引きを実装リポ向けに決め直す必要がある。

- **A. commit / push / PR 作成まで自律。マージのみ人間** — feature ブランチへの push を許可し、
  `main` はブランチ保護で直接 push 禁止
- **B. commit は自律、push と PR 作成は人間の明示指示** — 現行のグローバル方針をそのまま実装リポに適用
- **C. すべて人間の明示指示** — エージェントは作業ツリーの変更のみ
- E. Other (please describe after [Answer]: tag below)

> 推奨: **A**。理由: 1 issue = 1 PR (Q-1=A) を回す上で、push と PR 作成を毎回人間が起動すると
> **人間が待ち行列の律速**になる。安全性は「`main` への直接 push をブランチ保護で禁止」+
> 「PR マージは人間」+「CI ゲートで build/vet/test/lint を機械強制」の 3 点で担保でき、
> commit/push の許可はリスクを増やさない (feature ブランチは壊れてもよい場所)。
> ただし **force push / ブランチ削除 / タグ操作は deny のまま**にする。

**この回答が左右するもの**: AC-4.3 / 実装リポの `.claude/settings.json` の deny リスト
([templates/README.md](../../../templates/README.md) の立ち上げ手順 2 が指す設定) /
作業ループのどのステップまでを 1 セッションで完結させられるか (AC-1.1)。

[Answer]: A (2026-07-29) — commit / push / PR 作成まで自律、マージのみ人間。
main はブランチ保護で直接 push 禁止。force push / ブランチ削除 / タグ操作は deny のまま

---

## Q-5. モデルのエスカレーション / デエスカレーションの判断主体と基準

F-3 のとおり「呼び出し側が指定する」以上の規約が無い。設計リポ側は
[.claude/rules/02-agents.md](../../../.claude/rules/02-agents.md) に既定モデル表 +
エスカレーション / デエスカレーション基準を持っており、その実装リポ版が必要。

- **A. オーケストレーター (メインセッション) が着手前に判定する** — 判定基準を表で固定し
  (触るファイル数 / 新規ドメインか / 並行処理・状態機械を含むか / 設計書に前例があるか)、
  issue のラベルまたは issue 本文に想定モデルを記録する
- **B. サブエージェントの自己申告** — 既定 sonnet で着手させ、
  「非自明」と判断したら実装せずに差し戻し、呼び出し側が opus で再委譲する
- **C. 実装は常に opus** — 判断を廃し、コストで払う
- E. Other (please describe after [Answer]: tag below)

> 推奨: **A + 実行中の昇格トリガー併用**。理由: B は「非自明さの判断」自体を sonnet に委ねることになり、
> 難しい実装ほど「難しさに気付かないまま進む」失敗に寄る (自己申告のバイアス)。
> A の弱点は「着手前に難易度を読み違える」ことなので、**実行中のトリガー**で補う:
> ① Red の確認が 2 回連続で意図した失敗にならない ② レビューの重大指摘が 2 巡目も残る
> ③ 実装が設計書に無いパターンに到達した — のいずれかで opus へ昇格 (③ は設計リポへの差し戻しも検討)。
> C はレビュー (既定 opus) との tier 関係は満たすが、定型作業のコストが恒常的に上がる。

**この回答が左右するもの**: AC-3.1 / AC-3.2 / 実装リポ `.claude/rules/` のモデル表の粒度 /
`go-developer.md`・`react-developer.md`・`infra-engineer.md` 冒頭の引用ブロックの書き換え範囲。

[Answer]: A + 実行中の昇格トリガー併用 (2026-07-29) — オーケストレーターが着手前に基準表で判定し、
実行中は ①Red が 2 回連続で意図した失敗にならない ②重大指摘が 2 巡目も残る
③設計書に無いパターンに到達 のいずれかで昇格 (③ は設計リポへの差し戻しも検討)

---

## Q-6. レビュー差し戻しの反復上限と、収束しないときの扱い

設計リポは「**重大ゼロでない場合、修正してから再レビュー**」
([.claude/rules/04-review.md](../../../.claude/rules/04-review.md)) と定めるだけで、
反復の上限が無い。AI 駆動では「修正 → 再レビュー」が自動で回るため、上限が無いと無限ループになり得る。

- **A. 差し戻し 2 回まで。3 巡目に入る前に人間へエスカレーション** (issue にコメントして停止)
- **B. 重大ゼロになるまで無制限に反復** — 収束しない場合はエージェントが判断して停止
- **C. 差し戻しは 1 回。残った指摘は別 issue に切って先へ進む**
- E. Other (please describe after [Answer]: tag below)

> 推奨: **A**。理由: 2 巡しても重大が残るのは「実装の未熟」ではなく
> **設計の曖昧さかレビュー観点の解釈違い**である場合が多い
> (設計リポの実例: 1 巡目レビューで重大 12 件 → 起草側での修正が必要と判定された)。
> そのまま反復させても収束しない。
> C は重大指摘を先送りする形になり、`main` に重大な問題を入れる経路を作ってしまう
> (中・軽微の指摘を別 issue に切るのは可)。

**この回答が左右するもの**: AC-1.3 / 作業ループの停止条件 (AC-1.1) /
Q-5 の昇格トリガー ② との関係 (2 巡目で opus へ上げるか、人間へ上げるか、両方か)。

[Answer]: A (2026-07-29) — 差し戻し 2 回まで。3 巡目に入る前に issue にコメントして停止し、人間へエスカレーション

---

## Q-7. infra-repo のレビュー体制 (自己レビュー禁止の適用)

F-6 のとおり infra-repo は `infra-engineer` 1 体が実装とレビューを兼任する定義。
設計リポの原則は「**起草したエージェント・セッションとは別セッションでレビューする (自己レビュー禁止)**」
([.claude/rules/04-review.md](../../../.claude/rules/04-review.md))。
Terraform は `plan` の出力が差分の説明になるため、レビューの形が backend/frontend と異なり得る。

- **A. `infra-reviewer` を新設する** — 3 リポすべてで「実装役 / レビュー役の分離」を成立させる
- **B. 別セッションの `infra-engineer` にレビューを依頼する** — エージェント定義は増やさず、
  「レビュー時は別セッションで呼ぶ」運用ルールだけを追加する
- **C. `terraform plan` の出力を人間が確認することでレビューに代える** — エージェントレビューは行わない
- E. Other (please describe after [Answer]: tag below)

> 推奨: **A**。理由: レビュー観点 (state 破壊・destroy を伴う差分・IAM 権限の過剰付与・
> シークレットの平文化) は実装観点と別物で、専用の定義に書き出した方が抜けにくい。
> B は同じ定義ファイルを読む以上「実装時に考えたことをもう一度考える」形になり、
> セッションを分ける効果が薄い。C は人間が Terraform の差分を毎回精読する前提になり、
> インフラ変更の頻度が上がると破綻する (ただし **`apply` の人間承認は A でも維持する**)。

**この回答が左右するもの**: AC-5.2 / `templates/infra-repo/.claude/agents/` に追加するファイル /
[templates/infra-repo/CLAUDE.md.tmpl](../../../templates/infra-repo/CLAUDE.md.tmpl) の運用ルール表。

[Answer]: A (2026-07-29) — `infra-reviewer` を新設し、3 リポすべてで実装役 / レビュー役を分離する。
`terraform apply` の人間承認は維持する

---

## 回答が無い場合の暫定既定 (推奨案の採用)

| Q | 暫定既定 | 影響を受ける AC |
|---|---|---|
| Q-1 | A (1 issue = 1 PR = 同じ検証で閉じる AC 群) | AC-2.1 / AC-2.3 / AC-2.4 |
| Q-2 | A (backend に親 issue + 各リポに子 issue) | AC-2.2 |
| Q-3 | B + 条件付き着手前承認 | AC-4.1 / AC-4.2 |
| Q-4 | A (commit/push/PR は自律・マージは人間) | AC-4.3 |
| Q-5 | A + 実行中の昇格トリガー | AC-3.1 / AC-3.2 |
| Q-6 | A (差し戻し 2 回で人間へ) | AC-1.3 |
| Q-7 | A (`infra-reviewer` を新設) | AC-5.2 |

暫定既定で進める場合、[requirements.md](requirements.md) §6 に「既定採用」と明記し、
**回答が出た時点で requirements と templates 側のルールを更新する**。
