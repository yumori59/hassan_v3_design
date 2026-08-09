# Design Review: construction-workflow (実装リポの AI 駆動開発ワークフロー)

- レビュー日: 2026-07-29
- レビュアー: `design-reviewer` (別セッション。起草は `architecture-designer` × 4 + メインセッション)
- 基準: 本番基準 (`.claude/rules/08-production-gates.md` / `.claude/rules/feedback_review_patterns.md` /
  ルート `CLAUDE.md` のハイブリッド方針)。「PoC では対象外だった」は省略理由として認めない
- 対象: 本リポジトリは git 管理外のため差分ではなく**対象ファイル全文**をレビューした

## レビュー結果サマリ

- **重大 2 件 / 中 4 件 / 軽微 6 件**
- 実行した検証: `make doc-lint` (エラー 0 / 警告 17 — いずれも本 feature 外) /
  `make check-traceability` (construction-workflow 23/23 OK) / YAML パース 7 本 (全 OK) /
  ID 名前空間の機械照合 (S/V/M/T/H/I 全参照が定義域内) / 抜き取り照合 6 件
- **Design Freeze は不可**。重大 2 件 (H-5 の機構欠落 / frontend 本番デプロイの回避経路) を
  修正してから再レビューが必要。中 4 件は Freeze 前に処理することを推奨

### レビューした設計成果物 (リポジトリ相対パス。全件)

新規:

- `templates/shared/.claude/rules/01-construction-loop.md`
- `templates/shared/.claude/rules/02-issue-granularity.md`
- `templates/shared/.claude/rules/03-model-escalation.md`
- `templates/shared/.claude/rules/04-human-checkpoints.md`
- `templates/app-monorepo/.github/ISSUE_TEMPLATE/task-backend.yml`
- `templates/app-monorepo/.github/ISSUE_TEMPLATE/task-frontend.yml`
- `templates/infra-repo/.github/ISSUE_TEMPLATE/task.yml`
- `templates/app-monorepo/.github/pull_request_template.md`
- `templates/app-monorepo/.github/pull_request_template.md`
- `templates/infra-repo/.github/pull_request_template.md`
- `templates/infra-repo/.claude/agents/infra-reviewer.md`

更新:

- `templates/app-monorepo/.github/workflows/deploy-backend.yml`
- `templates/app-monorepo/backend/CLAUDE.md.tmpl`
- `templates/app-monorepo/frontend/CLAUDE.md.tmpl`
- `templates/infra-repo/CLAUDE.md.tmpl`
- `templates/README.md`
- `templates/app-monorepo/backend/.claude/agents/go-developer.md`
- `templates/app-monorepo/backend/.claude/agents/code-reviewer.md`
- `templates/app-monorepo/frontend/.claude/agents/react-developer.md`
- `templates/app-monorepo/frontend/.claude/agents/frontend-reviewer.md`
- `templates/infra-repo/.claude/agents/infra-engineer.md`

整合確認のために読んだ要件・計画 (指摘対象を含む):

- `aidlc-docs/inception/construction-workflow/questions.md`
- `aidlc-docs/inception/construction-workflow/requirements.md`
- `aidlc-docs/inception/construction-workflow/plan.md`

参照のみ (指摘なし): `templates/app-monorepo/.github/workflows/ci.yml` /
`templates/app-monorepo/.github/workflows/ci.yml` / `templates/infra-repo/.github/workflows/ci.yml` /
`templates/app-monorepo/scripts/hooks/pre-commit` /
`aidlc-docs/inception/productionization/requirements-layering.md` / `docs/design/architecture.md`

---

## 実行した検証 (出力)

```
$ make doc-lint
[doc-lint] 対象 71 ファイル / エラー 0 件 / 警告 29 件      # レビュー開始時 (23:40)
[doc-lint] 対象 72 ファイル / エラー 0 件 / 警告 17 件      # 本 review.md 追加後 (23:57)

$ make doc-lint 2>&1 | grep -E "construction-workflow|templates/"
(出力なし — 本 feature の追加分はエラーも警告もゼロ。AC-7.1 充足)

$ make doc-lint 2>&1 | grep WARN | cut -d: -f1 | sort | uniq -c | sort -rn
   7 ./docs/design/design_memo.md          2 ./docs/design/auth.md
   2 ./docs/analysis/gap-analysis.md       2 ./.claude/rules/05-harness.md
   1 ./docs/design/architecture.md         1 ./CLAUDE.md
   1 ./aidlc-docs/inception/productionization/questions.md
   1 ./aidlc-docs/inception/productionization/plan.md

$ make check-traceability
[traceability] construction-workflow: 23/23 カバー — OK
[traceability] productionization: 41/41 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
```

> **注**: 警告数が 29 → 17 に減っているのは、レビュー中 (23:53〜23:54) に**別セッションが
> `docs/design/auth.md` と `aidlc-docs/inception/productionization/questions-layering.md` の
> 未回答 `[Answer]:` を埋めた**ため (mtime で確認)。本 feature の対象ファイルの mtime は
> いずれも 23:15〜23:43 でレビュー中に変化しておらず、**レビュー対象は安定していた**。
> 警告はすべて本 feature 外のファイル由来 (未確定マーカー = `docs/design/design_memo.md` の
> 未確定項目など) で、エラーは一貫して 0 件。

YAML パース (ruby -ryaml):

```
OK   templates/app-monorepo/.github/ISSUE_TEMPLATE/task-backend.yml required=5 types=markdown,input,dropdown,textarea,dropdown,textarea,textarea,input,textarea,dropdown
OK   templates/app-monorepo/.github/ISSUE_TEMPLATE/task-frontend.yml required=5 ...
OK   templates/infra-repo/.github/ISSUE_TEMPLATE/task.yml required=5 ...
OK   templates/app-monorepo/.github/workflows/deploy-backend.yml jobs=build,plan_migration,apply_migration,plan_agent,apply_agent,release
OK   templates/app-monorepo/.github/workflows/ci.yml jobs=go
OK   templates/app-monorepo/.github/workflows/ci.yml jobs=frontend
OK   templates/infra-repo/.github/workflows/ci.yml jobs=validate,plan
```

必須 5 欄 (AC-2.3): 3 リポとも `required: true` が 5 件、id は
`ac-ids` / `layers` / `verification` / `human-checkpoints` / `dependencies` で一致。

ID 名前空間の機械照合 (`grep -rhoE "\bS-[0-9]+|\bV-[0-9]+|..." templates/ | sort | uniq -c`):

```
H-1..H-5 / I-1..I-3 / M-1..M-4 / S-1..S-10 / T-1..T-3 / V-1..V-10
→ 定義域外の ID (S-11・H-6 等) の参照はゼロ。重複定義もなし
   (V-x は 02 §3.1 のみ / H-x は 04 §1.1 のみ / S-x は 01 §1.1 のみが定義元)
```

### 抜き取り照合 (load-bearing な事実 6 件)

| # | 主張 | 照合先 | 結果 |
|---|---|---|---|
| 1 | ブランチ保護の必須チェック名 (04 §4.1: backend `build / vet / test / lint` / frontend `tsc / test / build / lint` / infra `fmt / validate / lint` と `plan (dev)`) | `templates/*/.github/workflows/ci.yml` の `name:` | **一致** (backend:15 / frontend:15 / infra:20,47)。設定可能な形になっている |
| 2 | 01 §7 の pre-commit の内容 (build + vet + 変更パッケージ test はブロック、生成物・OpenAPI・Agent は警告) | `templates/app-monorepo/scripts/hooks/pre-commit:15-62` | **一致** (`exit 1` は build/vet/test のみ、生成物・OpenAPI・Agent は `echo` のみ) |
| 3 | 01 §7.1 の「A-1 / A-4 / D-6 の検査は未実装なら CI が落ちる」 | `templates/app-monorepo/.github/workflows/ci.yml:70-99` | **一致** (3 ステップとも `exit 1`) |
| 4 | 02 §2.2 の依存方向の出典「`templates/README.md` の『リポジトリ間の依存 (立ち上げ順序)』節」 | `templates/README.md:47-55` | **実在・節名一致** |
| 5 | 03 §1 の既定モデル表 (`infra-engineer` = opus 例外 / `infra-reviewer` = opus) | 各 frontmatter `model:` | **一致** (`infra-engineer.md:5` opus / `infra-reviewer.md:5` opus / `go-developer.md:5` sonnet / `code-reviewer.md:5` opus) |
| 6 | 01 §2.3 の AC-ID → Go テスト名変換 (`AC-4.2` → `AC4_2`) と `-run` 照合 | `tr -d '-' \| tr '.' '_'` を実行、`go-developer.md:29` のテスト名規約 | **整合** (`TestXxx_AC1_2_<Scenario>` と一致。`-run` は非アンカー正規表現なので部分一致で動く) |
| 7 | CLAUDE.md.tmpl × 3 が索引する `.claude/**` パスの存在 (コピー後に解決するか) | 27 パスを機械照合 | **全 OK** (下記軽微 9 も参照) |

---

## 重大 (Must Fix)

### 重大 1. H-5 (着手前の計画承認) の唯一の検出経路が PR テンプレートに実装されていない

- 該当: `templates/shared/.claude/rules/04-human-checkpoints.md` §2.5 の 3 /
  同 §1.1 の H-1 確認観点 ⑦ / `templates/shared/.claude/rules/02-issue-granularity.md` §4.2 /
  `templates/{backend,frontend,infra}-repo/.github/pull_request_template.md`
- 事実: 04 §2.5 は「**PR 本文の DoD 欄**に『H-5 該当 issue の場合、承認コメントの URL』を
  **必須項目として置く**。URL が無い / 該当有無が未記載の PR は **H-1 で approve しない**」と定め、
  §1.1 の H-1 確認観点 ⑦ も「H-5 該当 issue なら承認コメントの URL」を要求する。
  しかし **3 リポの `pull_request_template.md` に H-5 の欄が存在しない**
  (`grep -rn "H-5" templates/*/.github/` は issue テンプレートの説明文のみにヒット)。
  02 §4.2 が列挙する PR テンプレートの構成要素 5 点にも H-5 が含まれていないため、
  テンプレートは 02 に忠実で、**04 と 02 が食い違っている**。
- なぜ本番で問題になるか: 04 は冒頭で「機構が未設定なら**その承認点は存在しないものとして扱う**」と
  自ら定めており、§2.6 は H-5 を唯一「回避可」と分類して**事後検出を H-1 に一本化**している。
  その検出材料が PR に無いため、H-5 は現状**どの機構にも接続されていない**。
  結果として「新規ドメインの追加 / 設計書に無いパターン / 3 リポ跨ぎ」— 手戻りが最大になると
  自ら定義した 3 条件の issue が、人間の計画承認を経ずに実装完了・マージされる経路が残る。
  これは AC-4.2「規約文書だけの『注意する』で終わらせないこと」に直接反する。
- 修正案:
  1. 02 §4.2 の PR テンプレート構成要素に「**6. H-5 の該当有無 + 承認コメント URL**」を追加する
     (項目の SSOT は 02 §3.1/§4.2 側なので、まずここを直す)
  2. 3 リポの `pull_request_template.md` に必須行を追加する
     (例: `## 8. H-5 (着手前の計画承認)` — `該当なし` / `該当あり → 承認コメント: <URL>`)
  3. 04 §2.5 の 1 は「issue テンプレートの必須欄に ①②③ の**チェックボックス**を置く」と書くが、
     実体は単一 dropdown option (`着手前の計画承認 (新規ドメイン / 設計書に無いパターン / 3 リポ跨ぎ)`)
     で ①②③ の区別が残らない。記述を実体に合わせる (または dropdown の選択肢を ①②③ に分割する)

### 重大 2. frontend の H-4 (本番デプロイ) が `production` ブランチへの push で回避できる

- 該当: `templates/shared/.claude/rules/04-human-checkpoints.md` §2.4 (frontend 行) / §2.6 /
  §3.2 (`.claude/settings.json` の例) / §4.1 / §4.4
- 事実:
  - §2.4 は「Vercel の Production Branch を **`production`** に設定し、`main` は Preview にする」と
    確定し、§2.6 は H-4 を「**回避不可**」と分類している
  - しかし §4.1 のブランチ保護チェックリストは見出しどおり「ブランチ保護ルール (**`main`**) —
    3 リポすべて」で、**`production` ブランチの保護は 3 リポどこにも定義されていない**
    (§4.4 の Vercel チェックリストも Production Branch の設定と Promote メンバー限定のみ)
  - §3.2 の deny は `Bash(git push origin main:*)` / `Bash(git push origin HEAD:main:*)` のみで、
    allow に **`Bash(git push origin HEAD:*)`** がある。deny は §3.2 自身が明記するとおり
    **前方一致**なので、`git push origin HEAD:production` は deny に一致せず allow に一致する
- なぜ本番で問題になるか: エージェントが 1 コマンドで **Vercel production への本番デプロイを起動できる**。
  レビュー (S-7)・H-1 (マージ)・H-4 (承認) をすべて迂回する経路であり、
  §2.6 の「H-5 以外は GitHub 側の機構で回避不可能な形にする」が frontend で成立していない。
  さらに `production` は保護されていないため、人間の誤操作でも同じことが起きる。
- 修正案:
  1. §4.1 に frontend 固有項目を追加: 「**`production` ブランチにも保護を設定**
     (必須レビュー 1 名以上・`main` からの PR のみ許可・force push / deletion 禁止・
     直接 push 禁止)」。§4.4 のチェックリストからも相互参照する
  2. §3.2 の deny に `Bash(git push origin production:*)` /
     `Bash(git push origin HEAD:production:*)` / `Bash(git push:*production*)` 相当を追加し、
     allow の `Bash(git push origin HEAD:*)` を `Bash(git push origin HEAD:refs/heads/<feature 系>)`
     相当に狭めるか、少なくとも production 系を明示 deny する
  3. §2.6 の H-4 (frontend) 行の「回避不可」根拠を「Vercel の Promote 権限限定 +
     `production` ブランチ保護」に書き換える (現状の根拠 `gh workflow run` の deny は
     Vercel の git 連携デプロイに効かない)
  4. あわせて `templates/app-monorepo/frontend/CLAUDE.md.tmpl` の「Vercel デプロイ」節 (63〜68 行) に
     「Production Branch は `production` / `main` は Preview」を明記する。
     **Vercel の既定は `main` = Production** であり、節だけ読むと既定運用に流れる

---

## 中 (Should Fix)

### 中 1. 実装・レビューエージェントの description が「3 層」のままで、確定した 4 層と矛盾する (AC-5.4)

- `templates/app-monorepo/backend/.claude/agents/go-developer.md:3` — 「本番バックエンド (Go / gin / **3 層** /
  sqlc / wire / Managed Agents) …**Controller・UseCase・Repository**・Agent 層・DB スキーマをまたがる…」
  → **Service 層が列挙から落ちている**
- `templates/app-monorepo/backend/.claude/agents/code-reviewer.md:3` — 「本番実装リポジトリ (Go **3 層** +
  Managed Agents + **Next.js**) …」→ 3 層に加え、3 リポ分割後の backend リポに Next.js が残っている
- 本文は正しく 4 層 (`go-developer.md:40-45` / `code-reviewer.md:23`)。ルート `CLAUDE.md` と
  `templates/README.md:10`・`CLAUDE.md.tmpl` はいずれも 4 層。description はエージェント選択時に
  読まれるメタデータであり、実装 SA が自分の description を根拠に Service 層を飛ばす余地を残す。
  AC-5.4「追加ルールが親 feature の確定制約 (4 層構成…) と矛盾しないこと」に対する取りこぼし
- 修正案: 両 description を 4 層 (Controller / UseCase / Service / Repository) に直し、
  code-reviewer から `Next.js` を削る

### 中 2. infra の「期待する plan 差分」が任意欄のため、V-7 の突合基準が空でも受領されてしまう

- `templates/infra-repo/.github/ISSUE_TEMPLATE/task.yml:104-113` (`id: expected-plan`,
  `required: false`) vs `templates/shared/.claude/rules/01-construction-loop.md` §2.4
  (「`envs/` 配下: **期待する `plan` 差分を issue に事前宣言**」= S-4 (Red) の代替) /
  同 `02-issue-granularity.md` §3.1 の V-7 (「`plan` の差分が**事前宣言と一致**する」)
- 02 §4.1 の受領判定は「**必須 5 欄**がすべて埋まっていること」だけなので、`envs/` のみを変更する
  issue が宣言なしで S-1 を通過できる。宣言が無ければ V-7 は比較対象を持たず、
  infra の Red 代替 (01 §2.4) が無言で消える。infra は V-2 / V-3 が「`envs/` のみなら V-7 が代替」と
  逃げ道を持つ設計なので、V-7 が空振りすると**infra リポだけ TDD 相当の担保がゼロ**になる
- 修正案: 必須欄を 6 に増やす代わりに、02 §4.1 の受領判定に条件を 1 行足す —
  「『影響する対象』で `envs/` を選択した issue は『期待する plan 差分』欄が埋まっていること
  (空なら S-1 で差し戻す)」。01 §2.4 の表にも同じ受領条件を書く

### 中 3. infra-repo の運用ルール表が `feedback_review_patterns.md` と skills を索引していない (AC-5.1 / AC-5.3)

- `templates/infra-repo/CLAUDE.md.tmpl:59-66` の表は rules 01〜04 と agents 2 本のみ。
  backend (`CLAUDE.md.tmpl:82-92`) / frontend (`:72-82`) は
  `.claude/rules/feedback_review_patterns.md` と `.claude/skills/implementing-robustly/` ·
  `test-driven-development/` を索引している
- `templates/README.md:28-30` の立ち上げ手順は 3 リポすべてに skills と
  `feedback_review_patterns.md` をコピーするため、**ファイルは置かれるが索引されない**状態になる。
  02 §3.1 の V-10 は「新バグパターン発見時の `.claude/rules/feedback_review_patterns.md`」を
  DoD に含めるが、infra の PR テンプレート (`:25`) はその記載を落としており、
  infra リポでは新パターンの還流先が実質的に存在しない
- 修正案: infra の運用ルール表に 3 行 (`feedback_review_patterns.md` / 2 skills) を追加し、
  infra PR テンプレートの V-10 に還流先を明記する (infra 固有の読み替えを残してよい)

### 中 4. `templates/infra-repo/.claude/agents/infra-reviewer.md:94` に生成物の残骸 `</content>` がある

- ファイル末尾に `</content>` の 1 行が残っている (`od -c` で確認)。
  doc-lint はこの種のゴミを検出しない (`scripts/doc-lint.sh` の検査項目に無い)
- 新規ファイルがそのまま実装リポにコピーされ、エージェント定義の本文末尾にゴミが混じる。
  実害は小さいが、**新規成果物が検証されずに確定した証跡**であり、
  他の生成箇所にも同種の残骸が無いか確認すべき (本レビューで `templates/` 全体を grep した結果、
  他には 1 件も無い)
- 修正案: 当該行を削除する

---

## 軽微 (Nice to Have)

1. **`tflint` のコマンド揺れ**: `01-construction-loop.md:92,316` は `tflint`、
   `02-issue-granularity.md:215` と `templates/infra-repo/.github/pull_request_template.md:20`・
   `templates/infra-repo/.github/ISSUE_TEMPLATE/task.yml` の既定値・
   `templates/infra-repo/.github/workflows/ci.yml:44` は `tflint --recursive`。
   S-6 (ローカル) と CI が同じコマンドであることが 01 §7.1 の前提なので、`--recursive` に揃える
2. **backend PR テンプレートに V-7 の欠番理由が無い**: frontend は
   `pull_request_template.md:14` で「V-7 は infra リポ専用のため本テンプレートには無い」と書くが、
   backend には注記が無く、ID が飛んでいる理由が読めない (02 §4.2 の「リポに存在しない項目は載せない」に
   従った結果なので、同じ注記を 1 行入れれば足りる)
3. **AC-5.3 の「doc-lint で担保」は不正確**: `scripts/doc-lint.sh:30` は `find . -name '*.md'` で
   走査するため **`CLAUDE.md.tmpl` は対象外**。本レビューで 3 つの tmpl が索引する `.claude/**` の
   27 パスを機械照合し全件解決を確認したが (上記検証表 7)、requirements の
   「相対リンクが切れていないこと (`make doc-lint`)」という書き方は機械検証の範囲を過大に見せる。
   AC の文言を「索引パスがコピー後に解決すること (手動または専用スクリプトで照合)」に直すか、
   doc-lint に `*.md.tmpl` を含める
4. **DF-6 (中断・再開の記録) に対応する AC が無い**: `01-construction-loop.md` §6 は
   ループ位置コメントという運用の要を定めるが、AC-1.1〜1.5 のどれも §6 を要求していないため
   `make check-traceability` の対象外になる (DR-6 の逆方向 = 設計判断に対応する AC の不足)。
   AC-1.6 として昇格させるのが望ましい
5. **H-1 の確認観点 ④ に対する PR 側の受け皿が弱い**: 04 §1.1 は H-1 で
   「対象 AC-ID とテスト名の照合出力」を見ると定めるが、PR テンプレート §3 の貼り付け欄は
   Red / Green のテスト出力のみを求めており、01 §2.3 の照合出力 (`OK` / `MISS` の一覧) を
   明示的に要求していない。§3 の Green 欄の説明に 1 語足せば足りる
6. **requirements §5 の D 領域の記述が D-2 / D-4 / D-6 に限定されている**: 実際には
   `04-human-checkpoints.md` が D-7 (§2.4)、`deploy.yml` が D-3 (ロールバック手順の明示) と
   D-5 (environment secret 経由の受け渡し) に踏み込んで回答している。
   一方 D-1 / D-8 は親 feature (`docs/design/architecture.md:214,221`) で回答済みであることが
   本 feature の文書に書かれていない。§5 の表に「D-1 / D-3 / D-5 / D-8 は親 feature で回答済み。
   本増分は機構化のみ」の 1 行を足すと、無言の省略との区別が付く

---

## 本番観点カバレッジ (`08-production-gates.md`)

本 feature は AC-6.3 で「A / O は**レビュー観点としての担保のみ**、設計は親 feature」と
先送り先を明示しているため、その方針に沿って評価した。

| ID | 状態 | 箇所 |
|---|---|---|
| A-1 | 回答あり (担保のみ) | `01-construction-loop.md` §8 (S-7 受理条件に「新規エンドポイントが認証ミドルウェアを通っているか」) + `ci.yml:70` の検査ステップ。設計は親 `docs/design/auth.md` |
| A-2 | 対象外 (理由あり) | AC-6.3 / requirements §5 で先送り先 = 親 feature `docs/design/auth.md` |
| A-3 | 対象外 (理由あり) | 同上 (本 feature は新規テーブルを定義しない) |
| A-4 | 回答あり (担保のみ) | `01` §8 (所有者絞り込みの確認) + `ci.yml:80` の `check-owner-scope.sh` |
| A-5 | 回答あり (担保のみ) | `01` §8 (401/403/404 の使い分けを S-7 の受理条件に含む)。**使い分けの決定は親 `auth.md`** |
| A-6 | 回答あり (担保のみ) | `01` §8 (custom tool の引数 ID に所有者チェックがあるか) + `01` §4.1 の 1 (所有者スコープの取り方が設計に無ければ差し戻し) |
| A-7 | 対象外 (理由あり) | AC-6.3 の先送り (共有・公開は親 feature) |
| O-1 | 対象外 (理由あり) | 先送り先 = 親 `docs/design/observability.md` (`01` §8) |
| O-2 | 回答あり (担保のみ) | `01` §8 (新しい LLM 呼び出し経路にトークン・コスト・`stop_reason` の記録があるか。無ければ S-7 未完了として再実行) |
| O-3 | 対象外 (理由あり) | `01` §8 (「コスト上限時の挙動を実装で決めない」= §4 の差し戻し対象)。設計は親 feature |
| O-4 | 回答あり | `01` §8 (`max_tokens` 切り詰め・JSON パース失敗・タイムアウトの観測可能性) + `deploy.yml:201` の 3 者一致検査 (BE-8) |
| O-5〜O-7 | 対象外 (理由あり) | AC-6.3 の先送り (親 feature `observability.md`) |
| **D-1** | 回答あり (部分) | `04-human-checkpoints.md` §1.1 の環境別表 (dev / prod の承認差) + §4.2 の environment 一覧。環境設計そのものは親 `architecture.md:214`。**本 feature の文書に「親で回答済み」の明示が無い** (軽微 6) |
| **D-2** | 回答あり | `01` §7 (pre-commit / CI (push) / CI (PR) / 人間の 4 段) + §7.1 (既存ジョブのループ上の位置) + §7.2 (マージ条件 5 点) + `02` §3.1 の V-1 |
| **D-3** | 回答あり | `04` §2.4 (本番デプロイの機構) + `deploy.yml:169,254,301` (各段の失敗時ロールバック手順) + `02` §2.2 / §2.2.1 (FE/BE のリリース順序と API 互換 3 段) |
| **D-4** | 回答あり | `04` §2.2 (破壊的変更の機械判定 6 条件 + environment ルーティング + スナップショットを承認条件に) + `deploy.yml:89-175` (`plan_migration` → `apply_migration`)。方式未確定はプレースホルダと明記 |
| **D-5** | 回答あり (部分) | `deploy.yml:162-164,246-247` (environment secret 経由) + `04` §3.3 (「エージェントのセッションに prod の接続情報を置かない」)。保管方式の SSOT は親 `architecture.md:218` |
| **D-6** | 回答あり | `04` §2.3 (`plan_agent` → `apply_agent`、ハッシュ比較でスキップ、`release` より前、旧 Agent ID の保持) + `deploy.yml:176-258` |
| **D-7** | 回答あり | `04` §2.4 (手動起動 + environment 承認 + `main` 限定の機械チェック + dev 検証済みの人間確認) + `deploy.yml:55-63`。**ただし frontend は重大 2 のとおり穴がある** |
| **D-8** | 対象外 (理由の明示が弱い) | 親 `architecture.md:221` (Q-7=B: Terraform = 基盤 / ecspresso = サービス) で回答済み。本 feature の文書に先送り先の記載が無い (軽微 6) |

## 頻出パターン (`feedback_review_patterns.md`) の確認

| # | 判定 |
|---|---|
| DR-1 出典なしの断定 | **問題なし**。questions.md の F-1〜F-6 に出典があり、ルール本文の事実 (CI ジョブ名・pre-commit の挙動・README の節名・既定モデル) は抜き取り 6 件すべて一次ソースと一致 |
| DR-2 本番観点の無言の省略 | **軽微 6 のみ** (D-1 / D-3 / D-5 / D-8 の「親で回答済み」の明示欠落)。A / O は AC-6.3 で先送り先を明記済み |
| DR-3 既存データの不在 | **該当なし (妥当)**。本 feature はプロセス規約で新スキーマを定義しない。むしろ `04` §2.2 が「既存データがある列への UNIQUE 追加」「デフォルト値の無い NOT NULL 追加」等を破壊的変更として機械判定し、スナップショットを承認条件にしている点は既存データへの配慮として良い |
| DR-4 PoC 実装のコピー設計 | **問題なし**。`04` §2.2 / §2.3 は PoC 方式 (起動時自動マイグレーション / 手動 `update-agent-prompt`) を却下案として明示的に排除している |
| DR-5 曖昧語による丸投げ | **問題なし**。`適切に` / `必要に応じて` / `後で検討` / `適宜` を対象ファイル全体で grep して 0 件。上限値 (2 巡 / 15 ファイル / 800 行 / 5 以下・6 以上) がすべて数値で確定している |
| DR-6 AC の宙吊り | traceability 23/23 OK。逆方向で軽微 4 (DF-6 に対応する AC が無い) |
| DR-7 プロトタイプを仕様として扱う | **問題なし**。`templates/app-monorepo/.github/pull_request_template.md:72` が「プロトタイプと挙動が異なる箇所とその根拠 (**仕様は設計書が正**)」を PR で要求しており、構造的に潰している |
| BE-3 / BE-5 (`.env` 方式・DB フォールバック) | 該当箇所は `04` §3.2 の deny (`Read(**/.env)`) と `deploy.yml` の environment secret。持ち込まれていない |
| BE-8 / BE-9 / BE-10 (Agent と schema の乖離) | `04` §2.3 + `deploy.yml:201-210` (3 者一致検査を Agent 発行の前提条件にし、未実装なら落とす) + `:228` (Tools 全置換の目視確認材料)。**設計で構造的に潰せている** |
| BE-11 (冪等性) | `deploy.yml` の `concurrency` (`:39-41`, `cancel-in-progress: false`) で同一環境への並行適用を禁止 |
| FE-1〜FE-7 | `templates/app-monorepo/.github/pull_request_template.md:51-53` が FE-1〜FE-7 の該当確認を PR の必須記載にしている |

## 良かった点

1. **承認点と機構の 1:1 対応表 (`04` §2.6) を自ら作り、「機構: なし」の行を禁止している**。
   R-1 (ルールを書いても実行されない) への構造的な回答になっており、
   今回の重大 2 件はいずれも「この表の基準に照らして自分が破っている箇所」として検出できた
   — 表の存在自体がレビュー可能性を作っている
2. **`deploy.yml` の 6 ジョブ分割が承認単位の設計になっている**。「同一 environment の複数ジョブは
   1 回の承認でまとめて解放される」という GitHub の挙動を根拠に、
   `prod-db` / `prod-agent` / `prod` を分けた判断と却下案 (単一 `prod` で 1 回承認) が書かれている。
   `apply_agent` を `release` より前に置く順序の根拠 (BE-8 / BE-10) も明示
3. **ブランチ保護の必須チェック名が実際の CI ジョブ名と一致している** (抜き取り照合 1)。
   「設定手順を書いたが名前が合わず設定できない」という典型的な引き渡し事故を回避できている
4. **dev の破壊的マイグレーションにのみ承認を要求する線引き** (`04` §1.1 の注記:
   「環境の重要度ではなく**データ喪失の不可逆性**で線を引く」)。C-15 (dev 継続デプロイ) を
   律速させずに、再現コストの高い検証データを守る判断が理由付きで書かれている
5. **Q-2 = B (推奨 A と異なる選択) の補完 3 点が漏れなく実装されている**。
   ① マージ順序規約 (`02` §2.2 / §2.2.1) ② 依存 issue 欄 (3 リポとも必須欄・`なし` を強制) ③
   人間による横断完了判定 (`02` §2.4) が揃い、さらに「機械化しない理由」まで書かれている
6. **SSOT の非重複が徹底されている**。4 ルールの冒頭にそれぞれ「他が持つ事項」の表があり、
   ID 名前空間 (`02` §3.1 の接頭辞表) を宣言した上で、機械照合しても重複定義・定義域外参照が 0 件
7. **Red の受理条件が「コンパイルエラーのみを Red としない」まで踏み込んでいる** (`01` §2.2)。
   自己申告を受理しない裏取りコマンド (`01` §2.3) が実行可能な形で書かれており、
   AC-1.2 を「気をつける」ではなく手順で潰している

---

## 判定

**Design Freeze 不可**。次の順で対応を求める。

1. **重大 2 件を修正** (H-5 の PR 欄追加 + 02 §4.2 の更新 / `production` ブランチ保護と deny の追加)
2. 中 1〜4 を修正 (description の 4 層化 / `expected-plan` の条件付き受領条件 /
   infra の索引追加 / `</content>` の削除)
3. 修正後に `make check` を再実行し、本 review.md に再レビュー結果を追記する
   (push ゲートは review.md の最終更新より後の設計成果物の変更をブロックする)

軽微 6 件は Freeze の阻害要因としない (ただし軽微 3 は AC-5.3 の文言修正を伴うため、
requirements を触るタイミングで一緒に直すのが安い)。

---

# 再レビュー (2 巡目) — 2026-07-30

- 対象: 1 巡目の指摘 12 件 (重大 2 / 中 4 / 軽微 6) の修正差分 + 波及した
  `aidlc-docs/inception/construction-workflow/requirements.md` ·
  `aidlc-docs/inception/construction-workflow/plan.md`
- 方法: 修正報告を受理せず、**すべて一次ソース (該当ファイルの当該行) で確認**した

## 判定サマリ

- **1 巡目の指摘 12 件はすべて解消** (重大 2 / 中 4 / 軽微 6)。修正による新たな矛盾・ID 破損なし
- **新規指摘: 中 1 件 / 軽微 1 件** (いずれも修正の副作用ではなく、2 巡目で新たに観測したもの)
- **Design Freeze: 条件付きで可**。設計内容としての阻害要因は無い。ただし下記
  「Freeze 前の実務ブロッカー」1 件 (`make check-traceability` が並行増分で落ちている) の解消が必要

## 1 巡目指摘の解消確認

| # | 指摘 | 判定 | 一次ソース確認 |
|---|---|---|---|
| **重大 1** | H-5 の検出経路が PR テンプレートに無い | **解消** | 3 リポの `pull_request_template.md` に `## 7. H-5 (着手前の計画承認)` (backend:71 / frontend:69 / infra:77) — 「該当なし」「該当あり + 承認コメント URL」の二択と「URL の無い該当 PR は approve されない」の根拠付き。`02-issue-granularity.md:315-316` に構成要素 6 が追加され SSOT 側も同期。`04` §2.5 の 1 は dropdown の実体に合わせ「①②③ のどれに該当したかは S-2 の判定コメントに書く」へ書き換え済み。旧 §7 は 3 リポとも `## 8. 人間レビュアーへ` に繰り下がり、他文書から PR テンプレートの節番号を参照している箇所は無い (grep 確認) |
| **重大 2** | frontend の H-4 が `production` push で回避できる | **解消** | ①`04` §4.1 に「**frontend のみ: `production` ブランチにも同等の保護**」(直接 push 禁止 / `main` からの PR のみ / 必須レビュー 1 名以上 / force push・deletion 禁止) を追加、根拠も明記 ②§3.2 の deny に `Bash(git push origin production:*)` / `Bash(git push origin HEAD:production:*)` を追加 (:235) — allow の `Bash(git push origin HEAD:*)` より具体的な前方一致で先に当たる ③§2.6 の H-4 行を backend/infra と frontend で機構を分けて書き直し、二重化列も `production` への push deny に更新 ④`frontend-repo/CLAUDE.md.tmpl` の Vercel 節に「Production Branch は `production`、`main` は Preview (**Vercel の既定は `main` = Production なので必ず変更する**)」を追加 |
| **中 1** | description が「3 層」のまま | **解消** | `go-developer.md:3` = 「Go / gin / **4 層**」+ 列挙に **Service** を追加 / `code-reviewer.md:3` = 「本番バックエンドリポジトリ (Go **4 層** + Managed Agents)」で Next.js を削除。`templates/` 全体の `3 層` 残存は `implementing-robustly/SKILL.md:31` の BE-2 の説明 (「コード/FE/prompts の 3 層」= 層構成とは無関係) のみ |
| **中 2** | infra の「期待する plan 差分」が任意欄で V-7 が空振りする | **解消** | `02` §4.1 の受領判定に「infra で『影響する対象』に `envs/` を含む issue は、任意欄『期待する plan 差分』が埋まっていること (空なら S-1 で差し戻す — V-7 の突合基準であり、無いと infra の Red 代替が消える)」を追加。`01` §2.4 の `envs/` 行にも「**宣言の無い issue は S-1 で受領しない**」を追加し、相互参照が閉じている。issue テンプレート側 (`infra-repo/.../task.yml:12,22`) にも起票者向けの案内が入った |
| **中 3** | infra-repo が `feedback_review_patterns.md` と skills を索引していない | **解消** | `infra-repo/CLAUDE.md.tmpl` の運用ルール表に 3 行 (`feedback_review_patterns.md` / `implementing-robustly` / `test-driven-development` — 後者に「infra の読み替えは rules 01 §2.4」の注記付き) を追加。infra PR テンプレート `:25` の V-10 に「新バグパターン → `.claude/rules/feedback_review_patterns.md`」を追記し、還流先が成立した |
| **中 4** | `infra-reviewer.md` 末尾の `</content>` | **解消** | `grep -rn "</content>" templates/` = 0 件。ファイル末尾は「差分の内容が意図どおりかは別の判断。」で正常終端 |
| **軽微 1** | `tflint` のコマンド揺れ | **解消** | `01` §1.3 (:92) と §7.1 (:316) を `tflint --recursive` に統一。CI (`infra-repo/.../ci.yml:44`)・issue テンプレート既定値・infra PR テンプレート V-4 と一致。`02` §3.1 の V-4 は `01` §1.3 を指す要約表記のため `tflint` のままで問題なし |
| **軽微 2** | backend PR テンプレートに V-7 欠番の注記が無い | **解消** | `backend-repo/.../pull_request_template.md:13` に注記追加 |
| **軽微 3** | AC-5.3 の「doc-lint で担保」が不正確 | **解消** | requirements `:112-114` が「索引されたパスが**実装リポへのコピー後に解決する**こと。`*.tmpl` は `make doc-lint` の走査対象外 (`scripts/doc-lint.sh` は `*.md` のみ) のため、この照合は手動または grep で行う」に修正。`scripts/doc-lint.sh:30` の実装と一致 |
| **軽微 4** | DF-6 に対応する AC が無い | **解消** | requirements `:75` に **AC-1.6** を追加、`01` §6 の見出しが `## 6. 中断・再開の記録 (AC-1.6)`、plan.md `:57` の検証表と `:97` の Task-1 行 (AC-1.1〜AC-1.6) に反映。`make check-traceability` が **24/24** に増えた |
| **軽微 5** | AC-ID ⇔ テスト名の照合出力の受け皿が無い | **解消** | backend / frontend の PR テンプレート `:38` の Green 欄サマリに「+ AC-ID⇔テスト名の照合出力 — `01` §2.3」を追加 |
| **軽微 6** | requirements §5 の D 行が D-2/D-4/D-6 のみ | **解消 (指摘より正確)** | §5 の D 行に D-3 / D-5 / D-7 の機構面回答と「D-1 / D-8 の設計回答は親 feature が持つ (`docs/design/architecture.md` §5 — **D-8 は回答済み、D-1 は部分回答**で環境間の切り分けは運用設計で確定予定)」を追記。`docs/design/architecture.md:214` (D-1 = 部分) / `:221` (D-8 = 回答) の実記載と一致しており、1 巡目レビューの「親で回答済み」という粗い表現を正した点は妥当 |

### 修正による副作用の確認 (回帰なし)

```
$ grep -rhoE "\bS-[0-9]+|\bV-[0-9]+|\bM-[0-9]+|\bT-[0-9]+|\bH-[0-9]+|\bI-[0-9]+" templates/ | sort -u
H-1..H-5 / I-1..I-3 / M-1..M-4 / S-1..S-10 / T-1..T-3 / V-1..V-10   → 定義域外 ID・重複定義ゼロ (1 巡目と同じ)

$ ruby -ryaml (workflows 4 本 + ISSUE_TEMPLATE 3 本)
全 7 本 OK / issue テンプレートは 3 リポとも required=5 を維持 (AC-2.3 の必須 5 欄を増やさずに中 2 を解決している)

$ grep -rnE "適切に|必要に応じて|後で検討|適宜" templates/shared/.claude/rules/ templates/*/.github/ aidlc-docs/inception/construction-workflow/
(0 件 — DR-5 の再発なし)

$ make doc-lint
[doc-lint] 対象 72 ファイル / エラー 0 件 / 警告 18 件   ← 本 feature 由来の ERROR/WARN は 0 件 (grep で確認)

$ make check-traceability
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 43/44 カバー — 未カバー: AC-6.20
[traceability] 照合 2 feature / 未カバーあり 1 feature      ← exit 1 (下記ブロッカー)
```

## 新規指摘

### 新規 中 5. `.claude/settings.json` の設定例が jsonc (コメント付き) で、そのまま作ると deny が 1 つも効かない

- 該当: `templates/shared/.claude/rules/04-human-checkpoints.md` §3.2
  (見出しは「**立ち上げ時にこの形で作る**」、コードフェンスは ```jsonc、`:235` `:239-241` `:246` 等に `//` コメント)
  / 参照元は `templates/README.md:34-38` (「§3.2 の設定例が**正**」)
- 問題: `.claude/settings.json` は **JSON として読まれ、コメント付き JSON を受け付ける保証がない**。
  例をそのままコピーしてファイル化すると**パース失敗で permissions ブロック全体が読み込まれず、
  deny が 1 つも効かない状態になる**。しかも「deny を書いたのに効いていない」は
  試行しないと分からない (エージェントは deny が無い状態で普通に動く) ため、
  §3.3 が言う「一次ガード」がゼロのまま立ち上がる。
  重大 2 の修正 (`production` への push deny) もこの経路に乗っているため、
  この 1 点で新しい deny も同時に無効化される
- 本指摘は 1 巡目の修正による回帰ではなく、2 巡目で新たに観測したもの
- 修正案 (どちらでもよい): (a) コードフェンス直下に
  「**`//` は説明のための注記。`settings.json` は厳格 JSON なので、実ファイルへコピーする際は
  コメントを削除する**」を 1 行追加する (b) コメントを JSON の外に出し、
  deny 項目 → 対応する承認点 (H-x) の表として併記する。
  加えて §4.5 の確認手順に `python3 -m json.tool .claude/settings.json` 相当の 1 行を足すと、
  パース失敗を立ち上げ時に検出できる

### 新規 軽微 7. §4.5 の設定確認スクリプトが `production` ブランチの保護を検証しない

- 該当: `templates/shared/.claude/rules/04-human-checkpoints.md` §4.5
  (`gh api "repos/:owner/:repo/branches/main/protection"` のみ)
- §4.5 は「**設定できたことの確認** (立ち上げ時に 1 回実行し、出力を残す)」であり、
  §4.1 の各項目が実際に効いているかの唯一の検証手段。重大 2 の修正で追加した
  frontend の `production` 保護は、この確認の対象外のまま残っている
  (= 設定漏れが検出されない。§4.2 の environment が「作成漏れ = 承認の消滅」と書かれているのと同じ構図)
- 修正案: frontend リポ用に 1 行足す —
  `gh api "repos/:owner/:repo/branches/production/protection" --jq '{reviews: .required_pull_request_reviews, force_push: .allow_force_pushes.enabled}'`

## Freeze 前の実務ブロッカー (本 feature の設計品質とは別)

**`make check-traceability` がリポジトリ全体では exit 1** になっている
(`productionization: 43/44 — 未カバー: AC-6.20`)。AC-6.20 は並行セッションが
`aidlc-docs/inception/productionization/requirements-layering.md` (mtime 2026-07-30 00:04) に
追加した layering 増分の作業中状態であり、**本 feature の対象外**。

ただし影響は本 feature に及ぶ: `scripts/hooks/pre-commit:27-33` は
**staged に `aidlc-docs/inception/` の変更があれば全 feature に対して `check-traceability.sh` を実行**する。
本 feature は `requirements.md` / `plan.md` を変更しているため、
**このままコミットすると pre-commit が落ちてコミットできない**。

対処 (いずれか):

1. 並行セッションが AC-6.20 を plan / 設計書から参照するのを待ち、まとめてコミットする
2. layering 増分と本 feature を同一コミットに含めず、AC-6.20 のカバーが済んだ後に本 feature をコミットする

**`--no-verify` での回避はしない** (`.claude/rules/05-harness.md`)。

## Design Freeze 判定 (更新)

**可 (条件付き)**。

- 1 巡目の重大 2 件・中 4 件・軽微 6 件はすべて一次ソースで解消を確認した。
  重大ゼロの状態に到達しており、`04-review.md` の Freeze 条件 3 (重大事項ゼロ) を満たす
- 新規 中 5 (jsonc の設定例) は**設計判断ではなく引き渡し物の可用性の問題**で、修正は 1 行。
  Freeze と同時に直すことを推奨する (直さない場合、実装リポ立ち上げ時に deny が無効化される
  リスクが残るため、**引き渡し時の申し送り事項として明記すること**を条件とする)
- 新規 軽微 7 は阻害要因としない
- **コミット前に上記「実務ブロッカー」を解消すること** (`make check` が通る状態が
  Freeze 条件 1 = `.claude/rules/01-aidlc.md`)

---

# 3 巡目 (2 巡目の新規指摘の確認) — 2026-07-30

2 巡目で挙げた新規 2 件と Freeze 条件 (b) の解消を一次ソースで確認した。

| # | 指摘 | 判定 | 一次ソース確認 |
|---|---|---|---|
| **中 5** | 設定例が jsonc のままで、コピーすると deny が全滅する | **解消** | `04-human-checkpoints.md` §3.2 冒頭に「**下の例は説明用の jsonc (`//` コメント付き)。実ファイルはコメントを全て削除した純 JSON にする**」+ 失敗が目に見えないことと「作成後に `python3 -m json.tool` で必ず検証する (§4.5)」を追記。§4.5 の確認スクリプト**先頭**に `python3 -m json.tool .claude/settings.json > /dev/null && echo "settings.json OK"` を追加 (最初に走るので、後続の `gh api` 確認より前にパース失敗を検出できる) |
| **軽微 7** | §4.5 が `production` の保護を検証しない | **解消** | §4.5 に `gh api "repos/:owner/:repo/branches/production/protection"` を追加。`--jq` は reviews / force_push / **deletions** を出し、コメントに「§4.1。**404 なら設定漏れ = push 1 回で本番デプロイが起動する**」と失敗時の意味まで書かれている (§4.2 の environment 作成漏れと同じ書式) |
| **条件 (b)** | `make check` がリポジトリ全体で落ちていた | **解消** | 下記のとおり `make check` が exit 0。並行増分の AC-6.20 がカバーされ `productionization: 44/44` |

## 追加で行った検証 (指示された範囲を超えた確認)

§3.2 の指示「コメントを全て削除した純 JSON にする」が**実際に成立するか**を確認した
(指示どおりにしても JSON として壊れているなら、修正は機能しない)。

```
$ python3 (```jsonc ブロックを抽出 → 行末 // コメントを除去 → json.loads)
コメント除去後は純 JSON として妥当: ['permissions', 'autoMode', 'hooks']
  deny 30 件 / allow 13 件
production deny 存在: ['Bash(git push origin production:*)', 'Bash(git push origin HEAD:production:*)']
```

→ 末尾カンマ等の潜在的な JSON 不正は無く、**§3.2 の手順どおりに作れば重大 2 の deny を含む
30 件がそのまま有効になる**ことを確認した。

```
$ make check
[doc-lint] 対象 72 ファイル / エラー 0 件 / 警告 18 件
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 44/44 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
exit=0

$ make doc-lint 2>&1 | grep -E "construction-workflow|templates/"
(なし — 警告 18 件はすべて本 feature 外のファイル由来)
```

---

# 最終判定: **Design Freeze 可 (無条件)**

- 指摘の総計: **重大 2 / 中 5 / 軽微 7 → 全 14 件すべて解消** (1 巡目 12 件 + 2 巡目 2 件)。
  すべて修正報告ではなく該当ファイルの当該行で確認した
- `.claude/rules/01-aidlc.md` の Design Freeze 条件との対応:

| # | 条件 | 判定 |
|---|---|---|
| 1 | `make check` が通る | **充足** (exit 0 / エラー 0 / 未カバー AC 0) |
| 2 | `08-production-gates.md` の 3 領域に回答、または理由と先送り先の明記 | **充足** (本 review の「本番観点カバレッジ」表。D は主対象として回答、A / O は AC-6.3 で先送り先を親 feature の `docs/design/auth.md` · `observability.md` と明記) |
| 3 | 別セッションの `design-reviewer` で重大ゼロ | **充足** (本 review。3 巡すべて別セッション・本番基準) |
| 4 | 実装リポへの引き渡し情報が揃っている | **充足** (共通ルール 4 本 + issue / PR テンプレート 6 本 + `infra-reviewer` + `deploy.yml` の承認機構 + `templates/README.md` の立ち上げ手順 + `04` §4 の GitHub / Vercel 人手設定チェックリストと §4.5 の設定確認コマンド) |

- **残す申し送り事項 (指摘ではない)**: `plan.md` の Task-8 (最初の 1 issue でループを実測してルールを
  実態に合わせる) は本リポジトリでは完了できない。`templates/` は初期値であって SSOT ではない (C-6) ため、
  実装リポ立ち上げ後の最初の 5 issue で `02` §1.2 手順 3 の上限値 (15 ファイル / 800 行) と
  `01` §3 の差し戻し上限 (2 巡) を実測で見直すこと。この先送りは plan.md に明記済みで、
  Freeze の阻害要因としない
