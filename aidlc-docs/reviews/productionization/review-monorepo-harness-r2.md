# レビュー (2 巡目): app モノレポ雛形 — 1 巡目 26 件の反映の実物照合

- **対象**: 1 巡目 ([review-monorepo-harness.md](review-monorepo-harness.md)) の **重大 4 / 中 14 / 軽微 8 = 26 件**に対する
  起草側の「全件反映した」の主張を、**実物を開いて 1 件ずつ照合**した結果
- **レビュー日**: 2026-08-04
- **観点**: ①反映の実物照合 (最優先) ②反映が生んだ新しい欠陥 ③1 巡目の「要確認 5 件」の扱い ④検証ゲート
- **基準**: 本番基準。「3 リポ構成ではこうだった」を省略の理由として認めない
- **起草**: 別セッション (本レビューは第三者)。**本レビューはファイルを一切変更していない** (故障注入は全て復元済み — ⑥参照)

## レビューした成果物 (リポジトリ相対パス)

機構 (雛形・スクリプト):

- `templates/app-monorepo/scripts/check-regen.sh` (**新設**)
- `templates/app-monorepo/scripts/hooks/pre-commit`
- `templates/app-monorepo/.github/workflows/ci.yml`
- `templates/app-monorepo/.github/workflows/e2e.yml`
- `templates/app-monorepo/.github/workflows/deploy-backend.yml`
- `templates/app-monorepo/.github/workflows/rollback-backend.yml`
- `templates/app-monorepo/.github/CODEOWNERS`
- `templates/app-monorepo/.github/pull_request_template.md`
- `templates/app-monorepo/.github/ISSUE_TEMPLATE/task-backend.yml`
- `templates/app-monorepo/.github/ISSUE_TEMPLATE/task-frontend.yml`
- `templates/app-monorepo/CLAUDE.md.tmpl`
- `templates/app-monorepo/backend/STRUCTURE.md`
- `templates/app-monorepo/backend/.golangci.yml`
- `templates/shared/.claude/rules/01-construction-loop.md`
- `templates/shared/.claude/rules/02-issue-granularity.md`
- `templates/shared/.claude/rules/04-human-checkpoints.md`
- `templates/shared/.claude/rules/feedback_review_patterns.md`
- `scripts/check-monorepo-ci.sh` (**新設**)
- `Makefile`
- `CLAUDE.md`
- `.claude/rules/feedback_review_patterns.md`

設計文書 (反映先として照合):

- `docs/design/architecture.md` (§3.11 / §3.11.2 / §3.11.3 / §5)
- `docs/design/operations.md` (§4.1 / §5.1.1 / §5.2 / §5.3)
- `docs/design/testing.md` (§5.3 / §7.4 / §9.1.1 / §10 / §13.3)
- `docs/design/frontend.md` (§16.2-1 の表 / FE-E / §11.2 / §12)
- `docs/design/README.md` / `docs/design/infrastructure.md`
- `aidlc-docs/aidlc-state.md`

---

## ① 結論

**Design Freeze 不可。重大 3 件 / 中 8 件 / 軽微 5 件。**

**26 件の反映判定: 一致 18 / 部分反映 7 / 不一致 1。**

1 巡目の重大 2・重大 3 と、中 14 件のうち 11 件は**実物として正しく反映されている**。
`scripts/check-monorepo-ci.sh` の新設は方向として正しく、**起草側の自称「故障注入 6 種 6/6 検出」は
本レビューで全件再現できた** (①〜⑧ の骨格は機能している)。

一方で**重大 4 件のうち 2 件が「部分反映」**であり、直近 3 巡と同じ型が再発している:

1. **重大 1 の対処 (`check-regen.sh`) が新しい欠陥を持ち込んだ** — **削除を検出しない** (裸の `git diff` より
   後退している) うえ、**ローカル実行でインデックスを書き換え、意図しない削除を次の commit に混入させる**。
   いずれも使い捨てリポジトリで実測した。スクリプト自身のコメント「変更・削除は元から diff に出るため
   両方カバーできる」は**事実に反する** (DR-1)
2. **重大 4 (行番号引用) が 10 件残っている** — 起草側は `templates/app-monorepo/…:NN` の形だけを置換し、
   **`同 :NN〜NN` / `ci.yml:NN-NN` (パスを伴わない形) を構造的に取り残した**。DR-8 が指摘する
   「自己申告の範囲だけ直す」そのもの
3. **中 11 (CODEOWNERS) の対処が不一致** — 「同じパスを 2 行書くと行ごとに別のオーナー要求になる」を
   機構ファイル内で**事実として断定**しているが、GitHub の Code Owners は最後に一致した行が優先されるため
   **`frontend-reviewers` のみ要求に化ける可能性が高い**。同じ差分の `architecture.md` §3.11.2 の
   要確認 #3 では「未検証」としており、**同一差分内で断定と未検証が併存**している

加えて、**中 2 (`on` の変更) が 2 文書に旧記述を残した**新しい波及漏れと、
**`MR-x` への改名で別名前空間の `M-1` / `M-3` を 3 箇所誤改名**した誤爆がある。
`make check` は 7 ゲート緑だが、**新設した `check-monorepo-ci` がルート `CLAUDE.md` の検証ゲート節
(`05-harness.md` が SSOT と宣言している一覧) に登録されていない** — そこは「上記 5 つ」のままで、
実体は 7 ゲートである。

| 分類 | 件数 | 一言 |
|---|---|---|
| 重大 | 3 | check-regen.sh の削除盲点 + commit 汚染 / 行番号引用 10 件の残存 / CODEOWNERS の断定 |
| 中 | 8 | 中 2 の波及漏れ / 検証ゲート SSOT 未登録 / MR-x 誤改名 / 故障注入 4 種が非検出 |
| 軽微 | 5 | 新設スクリプトの未エスケープ backtick・改名漏れ・コメントの不一致 |

---

## ② 1 巡目 26 件の反映判定

**判定基準**: 「一致」= 1 巡目の指摘原文が名指しした箇所**すべて**が修正され、修正内容が実物として機能する。
**修正案が挙げた箇所の一部だけを直したものは「部分反映」**とし、一致に数えない。

### 重大 4 件

| 1 巡目 | 判定 | 根拠 (パス:行) |
|---|---|---|
| **重大 1** `git diff --exit-code` が未追跡を見ない | **部分反映** | ①`templates/app-monorepo/scripts/check-regen.sh` は**未追跡を検出する** (実測: 新規生成後 exit=1。⑥ T1) ②しかし**削除を検出しない** (実測: 裸の `git diff` は exit=1 / `check-regen.sh` は exit=0。⑥ T3b) — スクリプト冒頭 `check-regen.sh:15` の「変更・削除は元から diff に出るため両方カバーできる」が**虚偽** ③**インデックスを書き換え、意図しない削除を次の commit に混入させる** (実測。⑥ S2) ④`docs/design/frontend.md:1193`〜`:1194` と `docs/design/testing.md:223` に**裸の `git diff --exit-code` を実行する要求が残存** — 検査④の対象は `$APP templates/shared templates/infra-repo` の `*.yml` / `*.sh` / `pre-commit` のみで **`docs/` を見ない** (`scripts/check-monorepo-ci.sh:185`〜`:186`) → **重大 R2-1** |
| **重大 2** e2e サマリが `repository_dispatch` 前提 | **一致** | `e2e.yml` の「結果の要約 (H-4 の承認材料になる)」ステップ: `TARGET_SHA` を `workflow_run.head_sha` から導出する env を置き、`github.event_name == 'workflow_run'` の分岐で「検証対象 commit (BE / FE 共通)」+「**H-4 の承認材料として使える**」を出力。nightly / 手動は「承認材料に使わない」。`upload-artifact` の `path:` も `frontend/<playwright-report/>` に修正済み (= 軽微 2 も同時解消) |
| **重大 3** `testing.md` §7.4 に廃止済み機構の要求 | **一致** | `docs/design/testing.md:410`〜`:414`: 警告条件 2 つを ~~取り消し線~~ + 「**要求から削除**」と明記。§13.3 の是正要求 13 は `:883` で ~~**13**~~ / 「本項目は消滅 (2026-08-04)」。`docs/design/operations.md:166` の §4.1 も ~~`E2E_DISPATCH_TOKEN`~~ / 「例外は現在ゼロ件」。**`deploy-backend.yml` に `curl` は 0 件**のままで整合 |
| **重大 4** 行番号引用 27 件が旧ファイル基準 | **部分反映** | **ステップ名参照 17 件はすべて実在を確認** (`ci.yml` / `e2e.yml` / `pre-commit` の実物のステップ名・セクション名と全数照合。⑥参照)。しかし **`ci.yml` を指す行番号引用が 10 件残存**し、**全件が別の内容を指す**: `docs/design/frontend.md:1266` (`ci.yml:58-72`) / `:1267` (`:73-98`) / `:1268` (`:99-118`) / `:1269` (`:119-129`) / `docs/design/testing.md:275` (`同 :107〜116`) / `:576` (`同 :73〜97` と `:95〜96`) / `:577` (`同 :99〜117`) / `:578` (`同 :119〜129`) / `:874` (`同 :97〜105`) → **重大 R2-2** |

### 中 14 件

| 1 巡目 | 判定 | 根拠 (パス:行) |
|---|---|---|
| 中 1 機構ファイル自身が無検査 | **部分反映** | `ci.yml:57`〜`:60` に `meta` フィルタ / `:485`〜`:521` に `meta` ジョブ / `:593` の `needs` に登録済み。しかし ①**検査対象はフィルタより狭い** — `find scripts -type f` (`ci.yml:501`) と `actionlint` (`:514`) のみで、フィルタに含めた **`.claude/**` と `.github/CODEOWNERS` / `ISSUE_TEMPLATE/*` / `pull_request_template.md` は無検査** ②**`meta` フィルタを消すと `meta` ジョブが恒久 skip になり `gate` が緑**になるが、故障注入で**非検出** (⑥ 注入 L) → **中 R2-M4** |
| 中 2 二重トリガー | **部分反映 (新たな矛盾)** | `ci.yml:26`〜`:30` は `push: branches: [main]` + `pull_request` に是正済み。しかし **`templates/shared/.claude/rules/01-construction-loop.md:67`「退避 push でも CI は起動するため…」/ `:314`「CI (push) \| S-9 の push (退避 push でも起動)」** と **`docs/design/testing.md:585`「`ci.yml` は `push` / `pull_request` の**両方で全ブランチに走る**」** が旧記述のまま → **中 R2-M1** |
| 中 3 STRUCTURE.md の「未確定」 | **一致** | `templates/app-monorepo/backend/STRUCTURE.md:208`「### OpenAPI 定義の出力先 (2026-08-03 に確定)」/ `:210`「`make docs` の生成先は `../api/openapi.yaml`」/ `:217` で `check-regen.sh` 経由を明記 |
| 中 4 grep の対象 0 件で緑 | **一致** | `ci.yml:322`〜`:330` に `for d in $targets; do [ ! -d "$d" ] && … fail=1`。エラーメッセージが連動 4 箇所を列挙している |
| 中 5 pathspec 欠落 3 箇所 | **一致** | `task-backend.yml:61`〜`:63` / `task-frontend.yml:59`〜`:60` / `STRUCTURE.md:157` の 3 箇所すべてが `scripts/check-regen.sh <pathspec>` 経由 |
| 中 6 targets ↔ files の機械照合 | **一致** | `scripts/check-monorepo-ci.sh:232`〜`:256` (検査⑥)。故障注入で検出を確認 (⑥ 注入 G) |
| 中 7 golangci-lint 未固定 | **部分反映** | `ci.yml:109` に `version: <v2.x.y>` を追加。ただし **action は `@v6` のまま** (`ci.yml:102`) で、1 巡目 要確認 1 の本体 (v6 が `version: "2"` スキーマを扱えるか) は未解決。**`architecture.md` §3.11.2 の要確認表 #1 に登録済み**なので DR-1 ではないが、**「反映」ではなく「先送りの明示」**である |
| 中 8 `github.sha` が checkout と別物 | **一致** | `e2e.yml` の「結果の要約」の `env: TARGET_SHA: ${{ github.event_name == 'workflow_run' && github.event.workflow_run.head_sha \|\| github.sha }}` |
| 中 9 FE のみで E2E が走らない | **一致** | `04-human-checkpoints.md:41` の H-4 行に確認観点⑥「最新の E2E 結果と、それが対象 commit を検証したものか」+「FE の変更を prod へ出すときは E2E を `workflow_dispatch` で 1 回手動実行し、その結果を承認材料にする」 |
| 中 10 write 権限の分離が代償に未記載 | **一致** | `architecture.md:911` (MR-4 行) に「**モノレポでは書き込み権限をサブツリー単位で分けられない**…受容する代償として明示する」。`CODEOWNERS` にも「**注意 (MR-4 の限界)**」節。`feedback_review_patterns.md:28` の DR-10 に 3 例目として追記 (`templates/shared/` 側も同期済み) |
| 中 11 CODEOWNERS の双方承認 | **不一致** | `/api/` を 2 行に分割したが、`CODEOWNERS:22`〜`:23` のコメントが「**同じパスを 2 行書く**と、行ごとに別のオーナー要求として扱われる」と**断定**。`architecture.md:911` (MR-4 行) も同様に断定。一方 `architecture.md` §3.11.2 の要確認表 #3 は同じ論点を「未検証」としている → **重大 R2-3** |
| 中 12 `vitest related` が 0 件で exit 1 | **一致** | `pre-commit:91` `npx vitest related --run --passWithNoTests $rel` + `:85`〜`:89` に理由コメント |
| 中 13 MR-5 が宣言だけ | **一致** | `architecture.md:913` (MR-5 行) に「立ち上げチェックリスト (04 §4.1) に**タグ保護ルール**の設定を含める」。実体は `04-human-checkpoints.md:330` (チェック項目) と `:409`〜`:410` (`gh api repos/:owner/:repo/tags/protection` による確認) |
| 中 14 `make check` がモノレポ機構を見ない | **部分反映** | `scripts/check-monorepo-ci.sh` (300 行) を新設し `Makefile:19` の `check` に追加。**自称 6 種の故障注入は 6/6 再現** (⑥)。しかし ①**ルート `CLAUDE.md:37`〜`:45` の検証ゲート節に登録されていない** (「上記 5 つをまとめて実行」のまま。実体は 7 ゲート) → **中 R2-M2** ②本レビューの自作 4 種が非検出 (注入 D / E / I / L) → **中 R2-M4 / M5 / M6 / M7** ③スクリプト内に改名漏れと未エスケープ backtick → **軽微 R2-L1 / L2** |

### 軽微 8 件

| 1 巡目 | 判定 | 根拠 (パス:行) |
|---|---|---|
| 軽微 1 `deploy` の paths が上位集合 | **部分反映** | `docs/design/operations.md:340`「**`deploy-backend.yml` の `on.push.paths` は `ci.yml` の path filter の部分集合にする** (ワークフロー定義自身の変更を除く)」+ 検査⑤で機械照合。ただし **`deploy-backend.yml:24` のコメントは「path filter は ci.yml の backend ジョブと**同じ条件**にする」のまま** → **軽微 R2-L3** |
| 軽微 2 `upload-artifact` の path 注意 | **一致** | `e2e.yml` の「レポートの保存」ステップ: `frontend/<playwright-report/>` + 「**アクションの `path:` は `defaults.run.working-directory` に従わない**」コメント |
| 軽微 3 `go.mod` 不在で無言スキップ | **一致** | `pre-commit:30`〜`:34` に `WARN: backend/go.mod がありません — backend のチェックをスキップ` |
| 軽微 4 issue テンプレの契約行が半分 | **一致** | `task-backend.yml:61`〜`:63` に `make sqlc wire` / `make docs` / `npm --prefix frontend run generate` の 3 行、`task-frontend.yml:59`〜`:60` に FE→BE 両方向 |
| 軽微 5 「H-5 以外は回避不可」 | **一致** | `04-human-checkpoints.md:214`「**H-5 と MR-6 以外は** GitHub 側の機構で回避不可能な形にする」 |
| 軽微 6 ecspresso config の `backend/` 接頭辞 | **一致** | `deploy-backend.yml:458` / `:472` が `<backend/stacks/${ENV_NAME}/ecspresso.yml>`、`rollback-backend.yml:120` が `<backend/stacks>/${{ inputs.environment }}/ecspresso.yml` |
| 軽微 7 §5.1.1 のジョブ名 | **一致** | `docs/design/operations.md:308`〜`:314` の表が `changes` / `backend` / `frontend` / `contract` / `meta` / `gate` の実物どおり |
| 軽微 8 §4.5 に Vercel の目視項目 | **一致** | `04-human-checkpoints.md:412`「**Vercel (MR-2) は gh api で見えないため目視で確認して結果をここに書き残す**」 |

### 起草側が自己申告した追加 1 件 + 1 巡目の「要確認 5 件」

| 項目 | 判定 | 根拠 |
|---|---|---|
| **`M-1`〜`M-6` → `MR-1`〜`MR-6` の改名 (147 箇所)** | **部分反映 (誤爆あり)** | 現在 `MR-[0-9]` は 159 箇所。既存 3 名前空間は無傷 (`03-model-escalation.md` = M-1〜M-4 / `llm-migration.md` = M-0〜M-9 / `data-model.md` = M-1〜M-4 のみで `MR-` は 0 件)。しかし ①**`docs/design/frontend.md:391` / `:672` / `:782` の「2026-07-31 のレビュー M-1 / M-3」を `MR-1` / `MR-3` に誤改名** (`git show HEAD:docs/design/frontend.md` の `:387` / `:664` / `:774` と照合。起草側は「5 箇所を誤改名して巻き戻した」と報告しており、**同型が 3 件取り残されている**) ②**改名漏れ 2 件** — `scripts/check-monorepo-ci.sh:94` の `(M-1)` と `:199` の `(M-3 の実体)` → **中 R2-M3** |
| **1 巡目の要確認 5 件を `architecture.md` §3.11.2 に記録** | **一致 (5/5)** | 「> **要確認 (GitHub / ツールの実挙動を未検証。実装リポの立ち上げ時に 1 回確かめる)**」の表に #1 golangci-lint v6 × `version: "2"` / #2 同名チェックランのブランチ保護判定 / #3 CODEOWNERS の 2 行 / #4 `vitest --passWithNoTests` / #5 `workflow_run.event` の将来耐性。**「外れた場合の影響」列があり推測を事実として書いていない形式**。ただし #3 は機構ファイルと MR-4 行で断定されており矛盾 (重大 R2-3) |

---

## ③ 重大 (Must Fix)

### 重大 R2-1. `check-regen.sh` が **削除を検出せず**、かつ**ローカル実行で意図しない削除を commit に混入させる**

**箇所**: `templates/app-monorepo/scripts/check-regen.sh:41`〜`:43`
(+ 波及: `ci.yml:145` / `:156` / `:560` / `:580`、`task-backend.yml:61`〜`:63`、`task-frontend.yml:59`〜`:60`、
`02-issue-granularity.md:248` の V-5、`architecture.md:911` の MR-3 行)

```bash
# 未追跡ファイルを diff の対象に載せる (内容はまだステージしない = intent-to-add)。
git add --intent-to-add -- "$@"

if git diff --exit-code -- "$@"; then
```

**実測 (使い捨て git リポジトリ。詳細は ⑥)**:

| 変更の種類 | 裸の `git diff --exit-code` | `check-regen.sh` |
|---|---|---|
| 生成物の**新規追加** | exit=0 (**素通り** = 1 巡目 重大 1) | **exit=1 (検出)** ✅ |
| 生成物の**変更** | exit=1 | exit=1 ✅ |
| 生成物の**削除** | **exit=1 (検出)** | **exit=0 (素通り)** ❌ **後退** |

**なぜ後退するか**: `git add -- <dir>` は**削除もステージする**ため、続く `git diff`
(worktree ↔ index) が clean になる。`--intent-to-add` は新規追加にしか作用しない。

**さらに重い問題 — 開発者のコミット内容を黙って変える**。`02-issue-granularity.md:248` の V-5 と
issue テンプレートは、**S-6 (DoD 検証) でオーケストレーターがローカルで `scripts/check-regen.sh backend` を
実行する**ことを既定値にしている。実測 (⑥ S2):

```
[実行前]  D backend/usecase/u.go | A  backend/v.go     ← 削除は未ステージ
$ ./check-regen.sh backend
[check-regen] OK: backend                              ← 削除を見逃す
[実行後] D  backend/usecase/u.go | A  backend/v.go     ← 削除が **ステージされた**
$ git commit -m "add v.go only"
 backend/usecase/u.go | 1 -     ← 意図せず削除が commit に入った
 backend/v.go         | 1 +
```

**本番で何が問題か**:

1. **生成物の削除ドリフトが検出されない**。sqlc のクエリファイル削除・orval のタグ削除・golden の
   ケース削除で「リポジトリに残った古い生成物」が緑で通る。MR-3 は「BE の IF 変更が FE の型に
   反映されているか」の担保なのに、**削除方向の反映漏れだけ穴が空く**
2. **AI 実装者の commit 内容が黙って変わる**。`01-construction-loop.md` の S-4〜S-9 は
   「検証 → commit」を機械的に繰り返す設計であり、検証コマンドがインデックスを書き換えることを
   誰も想定していない。`--no-verify` 禁止と組み合わさると、**開発者が気付かないまま
   「本来別 PR にすべき削除」が混入した PR が出る**
3. **スクリプト自身の説明が虚偽** (`check-regen.sh:15`「変更・削除は元から diff に出るため
   両方カバーできる」)。実装リポの開発者はこの記述を根拠に検証を省略する (DR-1 の
   「出典があるが指す先が違う」と同型で、**機構の自己申告**が誤っている)

**修正案** (どれか 1 つ。**インデックスを触らない形が望ましい**):

```bash
# 案 A (推奨): インデックスを一切触らない。git status で判定する
dirty=$(git status --porcelain --untracked-files=all -- "$@")
if [ -n "$dirty" ]; then
  echo "$dirty"; git diff -- "$@"; echo "::error::生成物が最新ではありません: $*"; exit 1
fi
```

```bash
# 案 B: 一時インデックスを使い、呼び出し元のインデックスを汚さない
export GIT_INDEX_FILE="$(mktemp)"; git read-tree HEAD
git add --intent-to-add -- "$@"; git diff --exit-code -- "$@"   # 削除は git diff HEAD で見る
```

**あわせて直すこと**: `check-regen.sh:15` の「両方カバーできる」を実測に合わせる。
`docs/design/frontend.md:1193`〜`:1194` と `docs/design/testing.md:223` に残る
**裸の `git diff --exit-code` を実行する要求**を `check-regen.sh` 経由へ書き換える
(現状 `docs/design/testing.md` は `:223` が `git diff --exit-code`、`:878` が
`scripts/check-regen.sh backend/testdata/golden` と**同一文書内で食い違っている**)。
検査④ (`scripts/check-monorepo-ci.sh:185`) の対象に **`docs/`** を加える
(現状は `templates/` 配下のみを見るため、この 2 件を構造的に見逃す)。

### 重大 R2-2. **`ci.yml` を指す行番号引用が 10 件残存**し、全件が別の内容を指す (重大 4 の部分反映)

起草側は「`ci.yml` / `e2e.yml` / `pre-commit` への行番号引用 22 件をステップ名参照へ置換」と報告し、
**その 17 件は実在するステップ名を指している** (全数確認済み)。しかし置換は
`templates/app-monorepo/…:NN` の形にしか掛かっておらず、**パスを伴わない引用形が残った**。

| 箇所 | 引用 | 主張 | `ci.yml` の実際の内容 | 実際の所在 |
|---|---|---|---|---|
| `docs/design/frontend.md:1266` | `ci.yml:58-72` | 併置テストの存在検査の「雛形の実体」 | `meta` フィルタの 3 行 + `backend` ジョブのヘッダ | `ci.yml:410`〜`:423` |
| `docs/design/frontend.md:1267` | `ci.yml:73-98` | 公開パス許可リストの照合 | postgres の `image:` 〜 `go vet` | `ci.yml:425`〜`:449` |
| `docs/design/frontend.md:1268` | `ci.yml:99-118` | `NEXT_PUBLIC_` 許可リスト | golangci-lint のコメントと `with:` | `ci.yml:451`〜`:469` |
| `docs/design/frontend.md:1269` | `ci.yml:119-129` | `globals.css` 行数の可視化 | スキーマ適用の `run:` 本体 | `ci.yml:471`〜`:481` |
| `docs/design/testing.md:275` | `同 :107〜116` | `check-owner-scope.sh` の呼び出し元 | `version: <v2.x.y>` 〜 スキーマ適用のコメント | 「A-4 所有者スコープの検査」ステップ |
| `docs/design/testing.md:576` | `同 :73〜97` / `:95〜96` | F-C4 の担保と「未実装なら落ちる」位置 | postgres の設定 / 層規約のコメント | `ci.yml:425`〜`:449` |
| `docs/design/testing.md:577` | `同 :99〜117` | F-C5 の担保 | golangci-lint | `ci.yml:451`〜`:469` |
| `docs/design/testing.md:578` | `同 :119〜129` | F-C6 の担保 | スキーマ適用の `run:` | `ci.yml:471`〜`:481` |
| `docs/design/testing.md:874` | `同 :97〜105` | `check-route-auth.sh` の走査位置 | 層規約のコメント + golangci-lint の開始 | 「A-1 認証の適用漏れ検査」ステップ |

**本番で何が問題か**: 1 巡目の重大 4 と同じ — **これらはすべて「雛形の実体」「担保」「実装済み」の
根拠として書かれている**。`docs/design/frontend.md:1260`〜`:1269` は
**「現状と残りを表で確定させる」という見出しの下の表**であり、実装リポの開発者が「残作業」を
判断する入口になる。行を開くと別の検査があるため、**未実装の見落としか重複実装が起きる**。

**修正案**: 上表の 10 件を**ステップ名参照へ置換する** (残り 17 件と同じ形)。
そのうえで**再検査の grep を「パスを伴わない形」も含める**:

```bash
grep -rnE '(同|ci\.yml|e2e\.yml|pre-commit)[^。]{0,15}:[0-9]+ *[〜~-] *[0-9]+' docs/
grep -rnE '(ci|e2e)\.yml:[0-9]+' docs/
```

**`06-delegation-prompts.md` の「機構を直したら文書を直す」手順 3 に、この 2 本を追記すべき** —
今回の取り残しは「置換対象の形を 1 種類しか想定しなかった」ことが原因で、
DR-8 の再検査 grep が**数値語・状態語に加えて「引用の記法」も対象にする**必要があることを示している。

### 重大 R2-3. CODEOWNERS の 2 行分割は「双方の承認」を実現しない可能性が高く、**機構ファイルが未検証の挙動を事実として断定**している

**箇所**: `templates/app-monorepo/.github/CODEOWNERS:17`〜`:24` / `docs/design/architecture.md:911` (MR-4 行)

```
# ⚠️ **1 行に複数オーナーを並べてはいけない** — GitHub の Code Owners は
# 「その行のオーナーのうち **誰か 1 人**」で充足するため、`@be @fe` と並べると
# BE だけの承認で通ってしまう (2026-08-04 の design-reviewer 指摘 中 11)。
# **同じパスを 2 行書く**と、行ごとに別のオーナー要求として扱われる。
/api/                   @<owner>/<backend-reviewers>
/api/                   @<owner>/<frontend-reviewers>
```

**問題**:

1. **最後の一文は GitHub の文書化された挙動と逆である可能性が高い**。CODEOWNERS は gitignore 形式で
   **「最後に一致したパターンが優先される (the last matching pattern takes the most precedence)」**
   という規則を持ち、**1 ファイルに適用されるルールは 1 行だけ**である。同じパスを 2 行書くと
   **2 行目が 1 行目を上書きし、`frontend-reviewers` のみが要求される**と考えられる。
   その場合、**BE レビュアーは `api/` の変更で自動リクエストすらされなくなり、1 行版より後退する**
   — **要確認**: GitHub 上での実挙動は確認していない (本レビューは GitHub API を叩いていない)。
   ただし**「後退している可能性がある」以上、断定して雛形に書いてよい状態ではない**
2. **同一差分内で断定と未検証が併存している**。`architecture.md` §3.11.2 の要確認表 #3 は
   同じ論点を「CODEOWNERS で**同じパスを 2 行**書いたとき、両方のオーナーの承認が必要になるか」=
   **未検証**として登録している。**機構ファイルと MR-4 行は断定、要確認表は未検証** —
   実装リポの開発者は機構ファイルのコメントを読んで「担保されている」と判断する
3. **1 巡目 中 11 の修正案 (a)(b)(c) のいずれも採られていない**。1 巡目は
   「(a) 必須承認者数を 2 に上げる (b) 記述を弱める (c) 双方を含むチームを 1 つ作る」の
   3 案を出し、**「どれを採るにしても立ち上げ時に 1 回試して確認する項目を §4.1 に足す」**と書いた。
   `04-human-checkpoints.md` §4.1 / §4.5 に**「BE のみの approve で `api/` の変更がマージできるか」を
   試す項目は無い** (`grep -n "api/" templates/shared/.claude/rules/04-human-checkpoints.md` で確認)

**本番で何が問題か**: `api/openapi.yaml` は BE→FE 契約の SSOT であり、MR-6 (破壊的変更の 3 段分割) の
唯一の人的関門が「`api/` の変更に双方のレビューが入る」ことである。**この担保が実在しないまま
「担保した」と書かれると、破壊的変更が FE レビューを経ずにマージされる**。
`04-human-checkpoints.md` 自身の原則「**機構の無い承認点を作らない**」に反する。

**修正案**:

1. `CODEOWNERS:20`〜`:24` のコメントから断定を外す —
   「**同じパスを 2 行書いたときに両方が要求されるかは未検証** (`architecture.md` §3.11.2 の要確認 #3)。
   **確認できるまでは必須承認者数 2 で担保する**」
2. **機構を承認者数に寄せる**: `04-human-checkpoints.md` §4.1 に
   「`api/` を含む PR は必須承認者数 2 (GitHub Rulesets)」を追加する。
   これは CODEOWNERS の解釈に依存しない
3. §4.1 の立ち上げチェックリストに**確認手順**を足す — 「`api/` のみを変更した PR を作り、
   BE 側 1 名の approve でマージ可能になるかを見る」(1 巡目の修正案から落ちている項目)

**補足 (R2-3 をさらに重くする事実)**: `04-human-checkpoints.md:406`〜`:407` の §4.5 に
**確認コマンドが追加されている**が、その内容は「`/api/` が 2 行あることを数えて
`api/ は N 行 = 双方の承認 OK` と表示する」だけである。

```awk
awk '$1=="/api/"{n++} END{ if (n>=2) print "api/ は " n " 行 = 双方の承認 OK"; else print "…" }' .github/CODEOWNERS
```

**行数を数えて「双方の承認 OK」と断定する検査**は、未検証の前提をそのまま自動化したものであり、
**チェックリストを実施した人に誤った合格を渡す**。加えて `04-human-checkpoints.md:212` (§2.6 の表) は
MR-6 の二重化欄で「`CODEOWNERS` により `api/` の変更は BE / FE 双方の承認が必要 (MR-4)」と断定しており、
**断定が 4 箇所 (CODEOWNERS / MR-4 行 / §2.6 の表 / §4.5 の検査) に増えている**一方で
要確認表 #3 は未検証のままである。**1 巡目 中 11 が要求した「1 回試して確認する項目」は依然として無い**。

---

## ④ 中 (Should Fix)

### 中 R2-M1. 中 2 (`on` の変更) の波及漏れ — 2 文書が旧記述のまま

| 箇所 | 記述 | 現実 |
|---|---|---|
| `templates/shared/.claude/rules/01-construction-loop.md:67` | 「退避 push でも **CI は起動する**ため、失敗した CI を放置しない」 | `ci.yml:27`〜`:28` は `push: branches: [main]`。**PR 作成前 (S-4〜S-8) の退避 push では CI が起動しない** |
| 同 `:314` | 「**CI (push)** \| S-9 の push (**退避 push でも起動**) \| 下表の全ジョブ \| PR のマージをブロック」 | 同上 |
| `docs/design/testing.md:585` | 「**`ci.yml` は `push` / `pull_request` の両方で全ブランチに走る**」 | `push` は `main` のみ |

**本番で何が問題か**: `01-construction-loop.md` は実装リポの AI 実装者が S-1〜S-10 を回すための手順書であり、
「退避 push で CI が起動する」を前提に「失敗した CI を放置しない」という**行動規範**を書いている。
実際には起動しないため、**中断・再開 (§6) の間に壊れたコードが検証されないまま残る**。
逆に S-9 で PR を作った後は `pull_request` の `synchronize` で走るため、
**「PR 作成前は走らない / 作成後は走る」を明示しないと、CI の空白期間が見えない**。

**修正案**: `01-construction-loop.md:67` を「退避 push では CI は起動しない (`ci.yml` の `push` は
`main` のみ。モノレポ機構 MR-1 の 2026-08-04 の是正)。**PR を作った時点から `pull_request` で走る**」に、
`:314` の行を「**CI (pull_request)**: S-9 の PR 作成後 (以降の push ごとに再走)」の 1 行へ統合する。
`docs/design/testing.md:585` は「`pull_request` で全ブランチの PR に走る」へ。

### 中 R2-M2. 新設した `check-monorepo-ci` が**検証ゲートの SSOT に登録されていない**

- `Makefile:19` の `check` は **7 ゲート** (`doc-lint` / `check-traceability` / `check-workflow-shell` /
  `check-table-counts` / `check-endpoint-mapping` / `check-template-sync` / `check-monorepo-ci`)
- ルート `CLAUDE.md:40`〜`:45` の検証ゲート節は **5 つしか列挙せず、`make check # 上記 5 つをまとめて実行`** のまま
- `.claude/rules/05-harness.md` は「**本数はここに書かない — 実体は `Makefile:14`、一覧はルート `CLAUDE.md` の
  検証ゲート節が SSOT**」と宣言している。つまり**SSOT が古い**
- `05-harness.md` の「doc-lint が見るもの / 見ないもの」表にも `check-monorepo-ci` の行が無い
  (`check-table-counts` / `check-endpoint-mapping` は行を持っている)

**`CLAUDE.md` は本差分で実際に編集されている** (`templates/` を 3 セット → 2 セットに直す変更が
`:6` と `:65` に入っている) — **同じファイルを開いていて検証ゲート節を見落とした**形で、DR-8 の典型。

**本番で問題になる理由**: 設計成果物を確定する前に走らせるゲートの一覧が SSOT なので、
**そこに無い検査は「走らせなくてよい検査」と読まれる**。`make check` 経由なら実行されるが、
個別に走らせる運用 (pre-commit の差分限定・CI の分割) で落ちる。

**修正案**: `CLAUDE.md` の検証ゲート節に `make check-template-sync` と `make check-monorepo-ci` を追記し、
「上記 5 つ」を**本数を書かない形** (「上記をまとめて実行」) に直す (DR-9 の規約どおり)。
`05-harness.md` の「見る / 見ない」表に `check-monorepo-ci` の行を足す
(見る = `gate` の needs / 必須欄 / MR-x 件数 / 裸の `git diff` の不在、見ない = **CI が実際に落とすかどうか**)。

### 中 R2-M3. `MR-x` 改名の誤爆 3 件 + 改名漏れ 2 件

**誤爆** (別名前空間を巻き込んだ。`git show HEAD:docs/design/frontend.md` と照合):

| 現在 | 改名前 | 内容 |
|---|---|---|
| `docs/design/frontend.md:391` | `:387` の `2026-07-31 のレビュー M-1` | 「すべての 401 が破棄経路に入るわけではない」の出典 |
| `docs/design/frontend.md:672` | `:664` の `2026-07-31 のレビュー M-1 で追加` | 401 / 分類 C の扱い |
| `docs/design/frontend.md:782` | `:774` の `2026-07-31 のレビュー M-3 で追加` | `/settings/profile` 画面の追加根拠 |

**改名漏れ** (モノレポ文脈なのに素の `M-x` が残った):

- `scripts/check-monorepo-ci.sh:94` `→ ジョブを増減したら gate の needs も同じ差分で更新する (M-1)。`
- `scripts/check-monorepo-ci.sh:199` `④…check-regen.sh が無い / 実行権限がありません (M-3 の実体)`

**本番で問題になる理由**: 誤爆は**設計判断の来歴を破壊する**。`frontend.md:672` は
「モノレポの path filter (MR-1) で追加された 401 の分類ルール」と読めてしまい、
無関係な機構を根拠に見せている。改名漏れの方は、**改名の目的 (名前空間衝突の解消) が
新設した機構の中で果たされていない** — `M-1` は `03-model-escalation.md` のモデル判定と衝突する。
**`operations.md:536` に `API/idea-boards.md` §4 の `M-1〜M-4` への正当な参照が現存する**ため、
衝突は実在するリスクである。

**修正案**: 誤爆 3 件を `M-1` / `M-3` に戻す。改名漏れ 2 件を `MR-1` / `MR-3` にする。
**再検査は「`MR-` の全出現がモノレポ文脈か」ではなく「`M-[1-9]` の全出現がどの名前空間か」を
分類する形で行う** (誤爆は `MR-` 側を見ても見つからない)。

### 中 R2-M4. `meta` ジョブの検査範囲が `meta` フィルタより狭く、**フィルタ削除が故障注入で非検出**

1. **フィルタとの不整合**: `meta` フィルタは `.github/**` / `scripts/**` / `.claude/**` (`ci.yml:57`〜`:60`)。
   `meta` ジョブの検査は `find scripts -type f \( -name '*.sh' -o -name 'pre-commit' \)` の `bash -n`
   (`ci.yml:501`) と `actionlint` (`:514`) の 2 つだけ。したがって
   **`.claude/**`・`.github/CODEOWNERS`・`.github/ISSUE_TEMPLATE/*`・`.github/pull_request_template.md` は
   1 つも検査されない**。1 巡目 中 1 が挙げたファイル群のうち、`.github/CODEOWNERS` /
   `ISSUE_TEMPLATE` / `pull_request_template.md` / `.claude/` が**依然として「どのジョブの対象でもない」**
2. **フィルタ削除が非検出** (⑥ 注入 L): `changes` の `meta` フィルタ 4 行を削除すると
   `meta` ジョブの `if: needs.changes.outputs.meta == 'true'` が恒久的に偽になり、
   **`meta` は常に skip → `gate` は緑**になる。`check-monorepo-ci.sh` の検査① は**ジョブ名の集合しか見ない**ため
   `exit=0`。**中 1 の対処は無検査のまま静かに巻き戻せる**

**修正案**:

- 検査①に「**`changes` の `outputs:` のキー集合 == `filters:` のキー集合 == 各ジョブの `if:` が参照する
  `needs.changes.outputs.<key>` の集合**」を足す (`grep` + `sed` で足りる)
- `meta` ジョブに **`.github/` の YAML 構文検査**を足す
  (`python3 -c 'import yaml,sys,glob; [yaml.safe_load(open(f)) for f in glob.glob(".github/**/*.yml", recursive=True)]'` 等)。
  `actionlint` は `.github/workflows/` しか見ないため issue テンプレートを守らない
- `.claude/` を `meta` フィルタに入れたまま検査対象にしないなら、**フィルタから外して理由を書く**
  (`.claude/settings.json` の hook deny は H-4 / MR-5 の機構でもあるため、
  少なくとも JSON 構文検査は入れるべき)

### 中 R2-M5. CODEOWNERS の `/api/` を 1 行に戻す改変が**故障注入で非検出**

⑥ 注入 E: `/api/` の 2 行を 1 行 (`@be @fe`) に戻しても `check-monorepo-ci.sh` は `exit=0`。
`04-human-checkpoints.md:406`〜`:407` の `awk` は**立ち上げ時の目視チェックリスト**であって
`make check` が走らせるものではない。MR-4 の担保が**設計リポ側の検査に載っていない**。

**修正案**: `check-monorepo-ci.sh` に検査⑨として
「`CODEOWNERS` に `/api/` の行が 2 行あり、それぞれ**単一オーナー**であること」を足す。
ただし R2-3 の結論 (承認者数で担保する) を採るなら、検査すべきは
`04-human-checkpoints.md` §4.1 に「`api/` を含む PR は必須承認者数 2」の項目があることになる。
**どちらにせよ MR-4 の担保が 1 つも機械照合されていない状態は解消すべき**。

### 中 R2-M6. `deploy-backend.yml` の `paths` を**狭める**方向が非検出 (検査⑤の片側性)

⑥ 注入 D: `deploy-backend.yml` の `paths` から `'api/**'` を削除しても `exit=0`。
検査⑤ (`check-monorepo-ci.sh:218`〜`:228`) は **deploy ⊆ CI の一方向しか見ない**。

`docs/design/operations.md:340` / `deploy-backend.yml:24` はどちらも
**「片方だけ更新すると『CI は走ったがデプロイされない』/ 逆が起きる」= 双方向**を問題として書いている。
`api/**` が deploy から落ちると、**契約だけが変わった commit が dev に反映されず、
`e2e.yml` の `workflow_run` も発火しない** (E2E が最大 24 時間空く = 中 9 の状況が拡大する)。

**修正案**: 検査⑤に逆方向を足す — 「`ci.yml` の `backend` ジョブを起動するパターン
(`backend/**` / `api/**`) が `deploy-backend.yml` の `paths` に含まれること」。
`.github/workflows/**` は現状どおり除外する。

### 中 R2-M7. `operations.md` の「**ジョブは 6 本**」が新たな未検査の件数 (DR-9 の再発)

⑥ 注入 I: `docs/design/operations.md:306` の「**ジョブは 6 本**」を「5 本」に改ざんしても
`check-monorepo-ci.sh` は `exit=0`。同じ行に「ジョブ名はここで数えず実物を見る —
`make check-monorepo-ci` の①が…機械照合する」と書いてあるが、**①はジョブ名の集合の一致だけを見ており、
「6 本」という数値は照合対象ではない**。スクリプトは実測本数を `[monorepo-ci] 実測: ci.yml の job 6 本` と
**出力しているのに、転記先と比べていない**。

`feedback_review_patterns.md` の DR-9 は「新しく『N 件』を書くときは、**同時に検算の対象に加えるか、
書かずに定義元へのリンクにする**」と定めている。**今回の反映で新しい「N 本」を 1 件増やしたのに
検算に入れていない** (`05-harness.md` の運用欄「レビューでは**新しく増えた『N 件』が検算の対象に
入っているか**を見る」に該当)。

**修正案**: 検査③と同じ形で「`operations.md` の『ジョブは N 本』↔ `ci.yml` の実測ジョブ数」を照合する
(1 行で足りる)。または DR-9 の規約どおり数値を落として「実物が正」だけを書く。

### 中 R2-M8. `docs/design/testing.md:223` の二重貼り + 裸の `git diff --exit-code` の残存

```
… (ci.yml へのリンク の「golden ファイルの差分チェック」ステップ **の「golden ファイルの差分チェック」**。
   `make golden` → `git diff --exit-code`。`Makefile` に `golden` ターゲットが無ければ `exit 1`)
```

1. **ステップ名が二重に貼られている** (置換作業の痕跡)
2. **`git diff --exit-code` のまま**。実物は `ci.yml:156` で
   `"$GITHUB_WORKSPACE/scripts/check-regen.sh" backend/testdata/golden`
3. **同一文書内で矛盾**: `docs/design/testing.md:878` (§13.3 の 8 番) は
   「`make golden` → `scripts/check-regen.sh backend/testdata/golden`」と正しく書いている

同型が `docs/design/frontend.md:1193`〜`:1194` にもある —
「`make -C backend docs` → `git diff --exit-code -- api/` → `npm run generate` →
`git diff --exit-code -- frontend/src/generated` を実行して同期を機械検証する」。
**これは実装リポへの要求文**であり、そのまま実装すると 1 巡目 重大 1 の穴が復活する。
検査④ は `docs/` を見ないため機械では止まらない (重大 R2-1 の修正案に含めた)。
`docs/design/testing.md:874` にも「A-4 所有者スコープの検査」ステップ **の** …」という同じ二重助詞がある。

---

## ⑤ 軽微 (Nice to Have)

| # | 箇所 | 内容 |
|---|---|---|
| R2-L1 | `scripts/check-monorepo-ci.sh:89` / `:91` / `:101` / `:285` / `:287` | **未エスケープの backtick が二重引用符内にあり、コマンド置換になる**。実測: 検査①が落ちたとき `scripts/check-monorepo-ci.sh: line 95: gate: command not found` が stderr に出て、**エラーメッセージから識別子 (`gate` / `ci.yml` / `e2e.yml` / `deploy-backend.yml`) が消える** (⑥ の注入 1 / 6 の出力を参照)。`\`` にエスケープする。**新設した機構自身の診断が読めなくなる**ため優先度は低くない |
| R2-L2 | `scripts/check-monorepo-ci.sh:94` / `:199` | `M-1` / `M-3` の改名漏れ (中 R2-M3 に含む。ここでは軽微として再掲しない — **M3 で対応**) |
| R2-L3 | `templates/app-monorepo/.github/workflows/deploy-backend.yml:24` | 「path filter は ci.yml の backend ジョブと**同じ条件**にする」のまま。実物は `.github/workflows/deploy-backend.yml` を含む**上位集合**で、`operations.md:340` は「**部分集合にする**」と書いており三者が食い違う。コメントを「`ci.yml` の条件 ⊆ 本 paths。追加分は理由をコメントで書く」に直す (1 巡目 軽微 1 の修正案原文) |
| R2-L4 | `ci.yml:509`〜`:513` | `actionlint` の導入失敗を `bash <(curl …) \|\| { echo "::error::…"; exit 1; }` で捕まえようとしているが、**`bash <(curl …)` の終了コードは `bash` のもの**であり、curl が失敗すると**空のスクリプトを実行して exit 0** になる。結果として意図した `::error::actionlint の導入に失敗しました` は出ず、次行の `actionlint` が `command not found` (127) で落ちる。**無言のスキップにはならない**ので実害は小さいが、切り分けの手掛かりが失われる。`curl -fsSL … -o /tmp/dl.bash && bash /tmp/dl.bash` の形にする |
| R2-L5 | `templates/app-monorepo/scripts/check-regen.sh:41` | **pathspec に一致するファイルが 1 つも無いとき `fatal: pathspec '…' did not match any files` (exit 128)** になり、スクリプトが用意した `::error::生成物が最新ではありません` は出ない (⑥ T5 / T5b)。`make docs` が `api/openapi.yaml` を吐かなかったケースがこれに当たる。**落ちる方向なので安全側**だが、`if ! git add --intent-to-add -- "$@" 2>/dev/null; then echo "::error::pathspec が存在しません: $*"; exit 1; fi` の形にすると原因が読める |

---

## ⑥ 裏取りの記録

### 6.1 `check-regen.sh` の実挙動検証 (使い捨て git リポジトリ)

`templates/app-monorepo/scripts/check-regen.sh` をスクラッチのリポジトリへコピーし、
`api/openapi.yaml` / `frontend/src/generated/theme.ts` / `backend/usecase/u.go` を commit 済みの
初期状態から各ケースを実行した (`.gitignore` に `node_modules/` と `*.log`)。

| # | ケース | 期待 | 結果 |
|---|---|---|---|
| T1 | `frontend/src/generated/idea.ts` を**新規追加** (orval の新規出力) | 検出 | **exit=1 ✅** (`new file mode` の diff を出力) |
| T2 | 変更なし (`frontend/src/generated api/openapi.yaml`) | 通過 | exit=0 ✅ (`[check-regen] OK`) |
| T3b | `frontend/src/generated/theme.ts` を**削除** | 検出 | **exit=0 ❌** (裸の `git diff --exit-code` は **exit=1** で検出する) |
| T4 | `api/openapi.yaml` を**変更** | 検出 | exit=1 ✅ |
| T5 | `api2/openapi.yaml` (存在しない pathspec) | 検出 (メッセージ付き) | exit=**128** / `fatal: pathspec … did not match any files` (意図したメッセージは出ない) |
| T5b | `nonexistent/dir` | 同上 | exit=128 / 同じ fatal |
| T6 | `frontend/src/generated/debug.log` (`.gitignore` 対象) を置く | 巻き込まない | exit=0 ✅ (ディレクトリ指定では ignore されたファイルは skip される) |
| T7 | `out.log` (ignore 済み) を**明示的に pathspec 指定** | — | exit=1 / `The following paths are ignored…` (意図したメッセージは出ない。実運用では起きない形) |
| S1 | 未追跡ファイルに `-N` した後 `git commit` | commit に**入らない** | ✅ `README.md` のみが commit された (i-t-a エントリは commit されない) |
| S2 | **未ステージの削除**を持った状態でローカル実行 → `git commit` | commit に**入らない** | **❌ 削除が `D ` (ステージ済み) に変わり、commit に混入した** |

S2 の実測ログ:

```
[実行前]  D backend/usecase/u.go|A  backend/v.go|
$ ./check-regen.sh backend
[check-regen] OK: backend
  exit=0
[実行後] D  backend/usecase/u.go|A  backend/v.go|
$ git commit -qm "add v.go only"
 backend/usecase/u.go | 1 -
 backend/v.go         | 1 +
 2 files changed, 1 insertion(+), 1 deletion(-)
```

**`pre-commit` からは `check-regen.sh` を呼んでいない** (`grep -n "check-regen\|git diff"
templates/app-monorepo/scripts/hooks/pre-commit` → `:16` の `git diff --cached --name-only` のみ) ため、
hook 経由でのインデックス汚染は無い。**ただし `02-issue-granularity.md:248` の V-5 と
issue テンプレート 2 本が「ローカルで実行するコマンド」として指定しているため、人と AI には到達する**。

### 6.2 「裸の `git diff --exit-code` を 17 箇所書き換えた」の残存確認

`grep -rn 'git diff --exit-code' templates/ docs/ aidlc-docs/ scripts/ .claude/` の全ヒットを
「実行されるコマンド」/「説明文・注意書き」に分類した (review 文書を除く):

| 分類 | 箇所 |
|---|---|
| **実行されるコマンド (問題)** | `docs/design/frontend.md:1193`〜`:1194` (実装リポへの要求文) / `docs/design/testing.md:223` (「実装済み」の説明として) |
| スクリプト内部 (正当) | `templates/app-monorepo/scripts/check-regen.sh:43` (本体) / `scripts/check-monorepo-ci.sh:186` (検出用の grep 文字列) |
| 注意書き (正当) | `02-issue-granularity.md:248` / `app-monorepo/CLAUDE.md.tmpl:44`・`:63` / `01-construction-loop.md:95` / `backend/STRUCTURE.md:218` / `check-regen.sh:6`・`:18` / `ci.yml:137`・`:555` / `architecture.md:911`・`:922` / `operations.md:347`・`:352` |

**雛形 (`templates/`) 側の実行コマンドは 0 件で、その点は主張どおり**。
`git diff --quiet` (同じく未追跡を見ない同義オプション) の混入も 0 件。
**残った 2 件はどちらも `docs/` にあり、検査④の対象外**である。

### 6.3 ステップ名参照の実在確認 (重大 4 の置換後)

`ci.yml` / `e2e.yml` / `deploy-backend.yml` の `- name:` を全数抽出し、
`docs/` 側の「〜の「◯◯」ステップ」形の参照 17 件と突き合わせた。**全 17 件が実在する**:

| 参照先 | 参照元 |
|---|---|
| `ci.yml` 「golden ファイルの差分チェック (BE-12 の再発防止)」 | `testing.md:223` / `:878` |
| `ci.yml` 「A-1 認証の適用漏れ検査 (…)」 | `testing.md:274` |
| `ci.yml` 「A-4 所有者スコープの検査 (…)」 | `testing.md:874` |
| `ci.yml` 「必須テストの存在検査 (testing.md §10)」 | `testing.md:882` |
| `ci.yml` `frontend` 「検査 1 併置テストの存在 (FE-4 / FE-6)」 | `testing.md:575` / `:661` / `:678` / `frontend.md:647` / `:1024` |
| `ci.yml` `frontend` 「検査 2 公開パスの許可リストとルートグループの一致 (FE-K)」 | `frontend.md:873` |
| `ci.yml` `frontend` 「検査 3 NEXT_PUBLIC_ の許可リスト (A-1)」 | `frontend.md:965` |
| `ci.yml` `frontend` 「検査 4 globals.css の行数 (FE-3。ブロックしない)」 | `frontend.md:611` / `:1023` |
| `e2e.yml` 「結果の要約 (H-4 の承認材料になる)」 | `testing.md:879` |
| `pre-commit` frontend ブロックの「関連テスト」 (`pre-commit:84` の echo) | `testing.md:102` |
| `pre-commit` 「生成型の手編集検出 (frontend)」 (`pre-commit:119` の節見出し) | `frontend.md:329` |

**「存在しないステップ名を指す」形の再発は無い**。残存する行番号引用 10 件は重大 R2-2 に列挙した。

### 6.4 故障注入 — **自称 6 種の再現 (6/6 検出) + 自作 8 種 (4 検出 / 4 非検出)**

実行は `bash scripts/check-monorepo-ci.sh`。注入前後で `shasum -a 256` を取得し完全復元を確認した (6.6)。

| # | 注入内容 | 起草側の自称 | 本レビューの結果 |
|---|---|---|---|
| 自称 1 | `gate` の `needs` から `contract` を削除 | 検出 | **exit=1 / エラー 2 件** ✅ (①-1 と ①-2 の両方) |
| 自称 2 | `task-backend.yml` の `required: true` を全て false に | 検出 | **exit=1** ✅ (「必須欄が 4 件 (期待 5)」) |
| 自称 3 | 「6 機構」→「5 機構」 | 検出 | **exit=1** ✅ (「件数の転記が定義元とずれています (実測 = 6)」) |
| 自称 4 | `ci.yml:145` を裸の `git diff --exit-code -- backend` に戻す | 検出 | **exit=1** ✅ (④) |
| 自称 5 | `deploy` の `paths` に `'docs/**'` を追加 | 検出 | **exit=1** ✅ (⑤「ci.yml の path filter に無い」) |
| 自称 6 | `deploy-backend.yml` の `name: Deploy` → `Deploy Backend` | 検出 | **exit=1** ✅ (⑧) |
| **自作 A** | `gate` の `check contract` 行だけを削除 (`needs` は残す) | — | **exit=1** ✅ (①-2 が拾う) |
| **自作 B** | `architecture.md` の `MR-3` の表行を削除 (連番を崩す) | — | **exit=1 / エラー 12 件** ✅ (連番違反 + 転記ずれ 11 件) |
| **自作 C** | `e2e.yml` の `workflows: [Deploy]` を**スカラー** `workflows: Deploy` に | — | **exit=1** ✅ (⑧。抽出値がコメントごと混入するが判定は正) |
| **自作 F** | `check-regen.sh` の実行権限を落とす (`chmod -x`) | — | **exit=1** ✅ (④の後半) |
| **自作 G** | `.golangci.yml` の L3 `files` から `**/usecase/idea/**` を削除 | — | **exit=1** ✅ (⑥) |
| **自作 H** | PR テンプレートの `V-9**` を `V-99**` に (= V-9 欠落) | — | **exit=1** ✅ (⑦) |
| **自作 J** | `ci.yml` に `newjob` を追加し `gate` の `needs` に足さない | — | **exit=1** ✅ (①-1) |
| **自作 D** | `deploy` の `paths` から `'api/**'` を削除 (deploy が CI より**狭く**なる) | — | **exit=0 ❌ 非検出** → 中 R2-M6 |
| **自作 E** | `CODEOWNERS` の `/api/` 2 行を 1 行 (`@be @fe`) に戻す | — | **exit=0 ❌ 非検出** → 中 R2-M5 |
| **自作 I** | `operations.md:306` の「ジョブは 6 本」→「5 本」 | — | **exit=0 ❌ 非検出** → 中 R2-M7 |
| **自作 L** | `changes` の `meta` フィルタ 4 行を削除 (中 1 の対処を巻き戻す) | — | **exit=0 ❌ 非検出** → 中 R2-M4 |

**評価**: 検査①〜⑧ の骨格は健全で、**起草側が試した 6 種は全て再現できた**。
非検出の 4 種はいずれも「**今回の反映で新設した担保そのものを巻き戻す改変**」であり
(D / E / L は 1 巡目の指摘への対処、I は反映で新しく書いた件数)、
**「対処を入れた」ことは検査されているが「対処が生きていること」は検査されていない**。
`feedback_review_patterns.md` DR-9 / DR-10 が言う「**足した検査自体を故障注入で殴る**」の
2 巡目適用として、上記 4 種を検査に取り込むべき。

### 6.5 `make check` の出力 (注入前・基準線)

```
[doc-lint] 対象 109 ファイル / エラー 0 件 / 警告 48 件
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 86/86 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
[workflow-shell] 検査 56 ブロック / エラー 0 件
[table-counts] 実測: 機能テーブル 42 (個人 34 / 契約 8) / 分類 ①31 ②2 ③1
[table-counts] 実測: 機能テーブル以外 12 (所有者列なし 7 / 所有者列あり 5) / 検査①の除外リスト 9
[table-counts] 照合 37 件 / エラー 0 件
[endpoint-mapping] 実測: auth-accounts.md 37 本 / 9 ドメイン 112 本 / settings.md §5 18 行 / custom tool 8 本 / 403 16 本
[endpoint-mapping] 照合 36 件 / エラー 0 件
[monorepo-ci] 実測: ci.yml の job 6 本 / モノレポ機構 MR-x 6 件 / issue テンプレート 3 本
[monorepo-ci] 照合 29 件 / エラー 0 件
make check exit=0
```

`make check-monorepo-ci` 単体:

```
$ bash scripts/check-monorepo-ci.sh
[monorepo-ci] 実測: ci.yml の job 6 本 / モノレポ機構 MR-x 6 件 / issue テンプレート 3 本
[monorepo-ci] 照合 29 件 / エラー 0 件
exit=0
```

警告 48 件は既存 (本ファイル追加後は 49 件 — 増分は本ファイル自身が「TODO」の語を引用した 1 件のみ。過去 review / `design_memo.md` の「TODO」語 / 未回答 `[Answer]` 6 件) で、
**本レビュー対象由来の新規警告は無い**。
**`make check` の実体は 7 ゲート**であり、`CLAUDE.md` の「上記 5 つ」と食い違う (中 R2-M2)。

### 6.6 注入の復元確認

```
$ shasum -a 256 -c sha-before.txt
templates/app-monorepo/.github/workflows/ci.yml: OK
templates/app-monorepo/.github/workflows/deploy-backend.yml: OK
templates/app-monorepo/.github/workflows/e2e.yml: OK
templates/app-monorepo/.github/pull_request_template.md: OK
templates/app-monorepo/.github/CODEOWNERS: OK
templates/app-monorepo/.github/ISSUE_TEMPLATE/task-backend.yml: OK
templates/app-monorepo/backend/.golangci.yml: OK
templates/app-monorepo/scripts/check-regen.sh: OK
docs/design/architecture.md: OK
docs/design/operations.md: OK

$ ls -l templates/app-monorepo/scripts/check-regen.sh
-rwxr-xr-x ... check-regen.sh          ← chmod -x を戻した (実行権限あり)

$ git status --porcelain | wc -l
     142                               ← レビュー開始時と同一
```

**本レビューは上記 10 ファイルへの一時的な注入と復元のみを行い、成果物
`aidlc-docs/reviews/productionization/review-monorepo-harness-r2.md` の作成以外の変更はしていない。**

### 6.7 抜き取り照合 (参照リポジトリ・出典の実在確認)

| # | 出典 | 主張 | 結果 |
|---|---|---|---|
| 1 | `claude_managed_agents/.github/workflows/ci.yml:27`〜`:30` (`docs/design/testing.md:64` の T-F15 / `:764`) | 「CI は **PostgreSQL を起動しない**。`go test` は `DATABASE_URL` 未設定のインメモリ経路を前提にしている」 | **一致**。当該行は `- name: go test` / `run: go test ./...` / `# AC-1.3: PostgreSQL サービスは起動しない。` / `# …DATABASE_URL 未設定でインメモリ動作する設計。` |
| 2 | `hassan-v2-backend/router/router.go:50` (`docs/design/architecture.md` §5 の O-1 行) | 「v2 は **prod でリクエストログを出さない**」 | **一致**。`:50` が `local` / `dev` 分岐で `controller.RequestLoggerMiddleware()` を含み、`:52` の else (prod) には含まれない |
| 3 | `templates/app-monorepo/…` への行番号引用 (重大 4 の置換結果) | 「22 件をステップ名参照へ置換。`.eslintrc.json.tmpl` の 9 件は有効」 | **部分一致**。ステップ名 17 件は実在 (6.3)。行番号引用の残存は `.eslintrc.json.tmpl` 9 件 (無変更ファイルのため有効) + **`ci.yml` を指す 10 件 (無効)** (重大 R2-2) |
| 4 | `git show HEAD:docs/design/frontend.md` の `:387` / `:664` / `:774` | 「`MR-x` へ 147 箇所改名。誤改名 5 箇所は巻き戻した」 | **部分一致**。3 箇所の誤改名が残存 (中 R2-M3) |
| 5 | `docs/design/operations.md:536` | (改名の必要性の裏付け) `API/idea-boards.md` §4 の `M-1〜M-4` への参照が現存 | **一致** — `M-x` の名前空間衝突が実在することの確認 |

---

## ⑦ 良かった点

1. **重大 2 / 重大 3 の反映が正確**。`e2e.yml` の「結果の要約」は `workflow_run` を主経路として扱い、
   `TARGET_SHA` を env で 1 箇所に集約し、**「H-4 の承認材料として使える」と明示的に書いた** —
   1 巡目が指摘した「常に承認材料に使わないと出る」状態は解消し、警告の摩耗も避けている。
   `testing.md` §7.4 の要求撤回も、**取り消し線 + 撤回理由 + 是正要求表の「消滅」化**まで揃っており、
   「廃止した機構の再実装へ誘導する」経路が閉じた
2. **`scripts/check-monorepo-ci.sh` の設計方針が正しい**。
   ①**ファイルが無いときにスキップして緑にしない** (`:54`〜`:64`) ②`awk` の `gsub` が後方参照を
   解釈しないという自分の実装バグを**コメントに残して是正している** (`:207`〜`:209`) —
   これは「検査を足しただけで満足しない」姿勢の実例であり、**故障注入⑤ が実際に効くようになっている**
   (本レビューで再現確認)。③**ドメイン数をハードコードしていない**
3. **自称「故障注入 6 種 6/6 検出」が本当だった**。1 巡目で問題になった「実施済みの自己申告」型では
   なく、**実行すれば再現できる主張になっている**
4. **1 巡目の「要確認 5 件」を `architecture.md` §3.11.2 の表に「外れた場合の影響」列付きで記録した** —
   推測を事実として設計に書かない形式が守られている (CODEOWNERS の #3 が機構ファイル側で
   断定されてしまった点だけが例外 = 重大 R2-3)
5. **`meta` ジョブの `actionlint` を「未導入なら落とす」形にした** (`ci.yml:508`〜`:511`)。
   1 巡目が指摘した「無言のスキップにしない」原則がこの新設ジョブでも守られている
   (curl 失敗時の分岐だけが不正確 = 軽微 R2-L4)
6. **`pre-commit` の 3 リポ版からの機能欠落がゼロのまま、`--passWithNoTests` と `go.mod` の WARN が
   加わった**。パス接頭辞の除去も 1 巡目の実測から変わっていない
7. **DR-10 に 3 例目 (write 権限の分離) を追記し、`templates/shared/` 側にも同期している**
   (`make check-template-sync` が同期を機械照合する)。パターンの還流が機能している

---

## ⑧ 要確認 (実挙動を確認していない項目。推測を事実として書いていない)

| # | 項目 | なぜ確認が要るか | 確認方法 |
|---|---|---|---|
| 1 | **CODEOWNERS で同じパスを 2 行書いたとき、両方のオーナーの承認が必要になるか** (重大 R2-3) | GitHub の CODEOWNERS は「最後に一致したパターンが優先」であり、**2 行目が 1 行目を上書きして `frontend-reviewers` のみ要求になる**可能性が高い。その場合 **1 行版より後退する** (BE レビュアーが自動リクエストされなくなる)。本レビューは GitHub 上で試していない | `api/` のみを変更した PR を作り、①レビュー要求に BE / FE の**両チームが載るか** ②BE 1 名の approve でマージ可能になるか を見る |
| 2 | **`golangci-lint-action@v6` が `version: v2.x.y` の指定で golangci-lint v2 系を導入できるか** (中 7) | できないなら雛形投入直後の CI が必ず落ちる。`architecture.md` §3.11.2 の要確認 #1 に登録済みだが**未解決** | action の README でメジャー対応表を確認 / 実装リポで 1 回 CI を回す |
| 3 | **`actionlint` の `download-actionlint.bash` が CWD にバイナリを置き、`PATH="$PWD:$PATH"` で解決するか** (軽微 R2-L4) | 置き場所が変わると `meta` ジョブが常に 127 で落ちる (= `meta` が常に赤で PR がマージ不能になる) | 実装リポで 1 回 `meta` ジョブを回す |
| 4 | **`push: [main]` + `pull_request: ["**"]` で、fork でない同一リポジトリの PR に `gate` が 1 つだけ出るか** (1 巡目 要確認 2 の後続) | 2 つ出るなら中 2 の対処が効いていない | backend を壊した PR を作り、チェックランの一覧を `gh pr checks` で見る |
| 5 | **`git add --intent-to-add -- <dir>` が削除をステージする挙動の git バージョン依存性** (重大 R2-1) | 本レビューはローカルの git 1 バージョンでのみ実測した。CI (ubuntu-latest) の git でも同じか | `ubuntu-latest` の git で 6.1 の T3b / S2 を再実行する。**ただし修正案 A (インデックスを触らない形) を採れば依存しなくなる** |

## 調べていない範囲 (カバレッジの正直さ)

- **1 巡目で「問題なし」と判定した項目の再検証はしていない** (`gate` の判定ロジック 7 通りの実測 /
  アクション入力のルート相対 / `contract` ジョブの起動条件 / PR テンプレートの V-x 両立 /
  `pre-commit` のパス接頭辞除去)。**`gate` の `needs` に `meta` が増えた影響のみ確認した**
  (`check meta` の行が実在し、①-2 の照合対象に入っている)
- **`templates/infra-repo/` の変更**は M-x → MR-x の言及整合のみ確認。CLAUDE.md.tmpl・issue/PR テンプレの
  全文はレビューしていない
- **`templates/app-monorepo/backend/.claude/rules/05-architecture-coding-rules.md` /
  `layering-scopes.yml` / `prompts/agents.yaml` / `.eslintrc.json.tmpl`** は本レビューの対象外
  (今回の反映で内容が変わっていない)
- **`docs/design/` の設計判断そのもの** (D-I の妥当性 / 本番ゲート A・O・D の網羅) は本レビューの
  範囲外 — 本レビューは**反映の照合**に絞っている (指示による)
- **対象外 (指示による)**: `docs/design/API/{conversation,ideas,plans}.md` / `review-conversation*.md` /
  `scripts/check-endpoint-mapping.sh` / `scripts/check-traceability.sh` / `機能一覧.md`
- **GitHub Actions / Vercel / GitHub の設定 API の実挙動**は一切実行していない (⑧ の 5 件)
