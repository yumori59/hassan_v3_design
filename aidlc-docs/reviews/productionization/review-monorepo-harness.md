# レビュー: app モノレポ + infra リポの 2 分割に伴う雛形 (`templates/`) の機構

- **対象**: 未コミット差分のうち、リポジトリ構成の 3 分割 → 2 分割 (D-I) に伴って新規作成・移動・改訂された雛形
- **レビュー日**: 2026-08-04
- **レビュー観点**: 本番基準 (`.claude/rules/08-production-gates.md` / `feedback_review_patterns.md`)。
  「3 リポ構成ではこうだった」を省略の理由として認めない
- **起草**: 別セッション (本レビューは第三者)

## レビューした成果物 (リポジトリ相対パス)

- `templates/app-monorepo/.github/workflows/ci.yml`
- `templates/app-monorepo/.github/workflows/deploy-backend.yml`
- `templates/app-monorepo/.github/workflows/rollback-backend.yml`
- `templates/app-monorepo/.github/workflows/e2e.yml`
- `templates/app-monorepo/.github/pull_request_template.md`
- `templates/app-monorepo/.github/ISSUE_TEMPLATE/task-backend.yml`
- `templates/app-monorepo/.github/ISSUE_TEMPLATE/task-frontend.yml`
- `templates/app-monorepo/.github/CODEOWNERS`
- `templates/app-monorepo/scripts/hooks/pre-commit`
- `templates/app-monorepo/CLAUDE.md.tmpl`
- `templates/app-monorepo/backend/CLAUDE.md.tmpl`
- `templates/app-monorepo/frontend/CLAUDE.md.tmpl`
- `templates/app-monorepo/backend/.golangci.yml`
- `templates/app-monorepo/backend/STRUCTURE.md`
- `templates/infra-repo/.github/ISSUE_TEMPLATE/task.yml`
- `templates/infra-repo/.github/pull_request_template.md`

照合のために読んだ設計文書 (レビュー対象そのものではないが、指摘が及ぶ):

- `docs/design/architecture.md` (§2 の D-I 行 / §3.11 / §3.11.1 / §3.11.2 / §3.11.3 / §5 の D-2 行)
- `docs/design/operations.md` (§5.1 / §5.1.1 / §5.3 / §5.4)
- `docs/design/testing.md` (§7.4 / §9.1.1)
- `templates/shared/.claude/rules/04-human-checkpoints.md` (§2.1 / §2.6 / §4.1 / §4.4)
- `templates/shared/.claude/rules/02-issue-granularity.md` (§3.1 / §4.1 / §4.2)
- `templates/shared/.claude/rules/01-construction-loop.md` (§1.3 / §7)

---

## ① 結論

**重大 4 件 / 中 14 件 / 軽微 8 件。この状態で実装リポの立ち上げに進めない。**

M-1 (gate) の判定ロジックと「アクション入力はルート相対」の徹底は**実物として正しく動く**。
一方で **M-3 (契約ドリフトの機械検出) が「新規ファイル追加」で機能しない** ため、
モノレポ化の主目的が最も頻度の高い変更で空振りする。加えて **3 リポ → 2 リポの移動で
雛形の行番号引用 27 件が旧ファイル基準のまま残り**、`e2e.yml` は
**`repository_dispatch` 前提のコードが残って H-4 の承認材料を常に無効化する**。
`make check` は 6 ゲートすべて緑だが、**今回新設された担保 3 種を故障注入したところ 3/3 非検出**で、
「緑」がモノレポ機構を何も見ていないことを確認した。

| 分類 | 件数 | 一言 |
|---|---|---|
| 重大 | 4 | M-3 の穴 (未追跡) / e2e サマリの旧実装 / testing.md §7.4 の自己矛盾 / 行番号引用 27 件の全滅 |
| 中 | 14 | 検査の「対象 0 件で緑」・機械照合の欠落・CODEOWNERS の担保過大宣言・M-5 の宣言のみ |
| 軽微 | 8 | 注意コメントの欠落・記述のずれ |

## ② 重大 (Must Fix)

| # | 箇所 | 問題 | 詳細 |
|---|---|---|---|
| **重大 1** | `templates/app-monorepo/.github/workflows/ci.yml:492` / `:511` (+ `:127` / `:140`) | **`git diff --exit-code` は未追跡ファイルを検出しない**。`api/openapi.yaml` の初回生成・orval が新規に吐く `frontend/src/generated/<new>.ts`・sqlc が新規に吐く `.sql.go` が**すべて素通り**する。M-3 (モノレポ化の見返り本体) が「エンドポイント追加」という最頻の変更で効かない | §B-1 |
| **重大 2** | `templates/app-monorepo/.github/workflows/e2e.yml:198`〜`:206` | `on:` から削除済みの **`repository_dispatch` を条件にしたまま**。`workflow_run` 起動 (= 唯一 H-4 の承認材料になり得る実行) でも「**BE の対象 commit: 不明 / この結果は H-4 の承認材料に使わない**」と出力され、**H-4 の承認材料が構造的に存在しなくなる** | §D-2 |
| **重大 3** | `docs/design/testing.md:414`〜`:418` および `:882` | 同一節の中で `E2E_DISPATCH_TOKEN` を**廃止したと宣言しながら、その機構の実装 (トークン未設定警告 / dispatch の 204 判定) を「実装済み」として要求している**。実物に `curl` は存在しない。読者は**廃止された機構を再実装する方向に動き、`operations.md` §4.1 の限定列挙に例外を再導入する** (セキュリティ方針の後退を設計文書が指示する形) | §D-4 |
| **重大 4** | `docs/design/testing.md` / `docs/design/frontend.md` の計 **27 箇所** | 雛形の**パスだけ一括置換され、行番号が旧ファイル基準のまま**。`ci.yml` 20 件・`e2e.yml` 3 件・`deploy-backend.yml` 2 件・`pre-commit` 2 件。抜き取り 11 件すべて不一致。**大半が「実装済み」の根拠として書かれている**ため、実装リポの開発者が別の検査を見て「これのことか」と誤読する。`make doc-lint` はリンクの実在だけを見るので**機械検査は緑** | §D-8 |

## ③ 中 (Should Fix)

| # | 箇所 | 問題 | 詳細 |
|---|---|---|---|
| 中 1 | `ci.yml:521`〜`:549` | **全ジョブ skip でも `gate` は緑**。ルート直下の `.github/workflows/*`・`scripts/hooks/pre-commit`・`.claude/` は**どの CI ジョブの対象でもない** (機構ファイル自身が無検査) | §A-3 |
| 中 2 | `ci.yml:22`〜`:26` | `push` と `pull_request` が両方 `branches: ["**"]`。path filter 導入後は**同一 SHA に基準の違う `gate` が 2 つ**生まれる (要確認 2) | §A-7 |
| 中 3 | `templates/app-monorepo/backend/STRUCTURE.md:208` | 「**OpenAPI 定義の出力先は設計で確定していない**」の旧記述が残り、M-3 の前提と矛盾 | §B-2 |
| 中 4 | `ci.yml:229` / `:284` / `:304` | `grep -r <targets> 2>/dev/null` の形は**対象ディレクトリが無くてもヒット 0 = 合格**。ドメイン追加・改名で検査が沈黙する (DR-6 後半) | §C-2 |
| 中 5 | `task-backend.yml:61` / `task-frontend.yml:59` / `STRUCTURE.md:157` | **`git diff --exit-code` に pathspec が無い** 3 箇所。規約 (`02-issue-granularity.md:248`) 自身が「必ず付ける」と定めた箇所の違反で、しかも AI 実装者が最も頻繁にコピペする既定値 | §C-3 |
| 中 6 | `ci.yml:304` ↔ `backend/.golangci.yml:313`〜`:326` | 集合は一致しているが、**一致を検査する機構が無い** (`D-2⑦` の入力に `ci.yml` が含まれない)。今後 6 ドメイン追加が予定されており必ず動く (DR-9) | §C-4 |
| 中 7 | `ci.yml:90` + `backend/.golangci.yml:83` | `golangci-lint-action@v6` × `version: "2"` の組み合わせ (要確認 1) と、**ツールバージョン非固定** | §C-6 |
| 中 8 | `e2e.yml:197` | `workflow_run` 起動時の `github.sha` はデフォルトブランチの最新。**checkout した `head_sha` と別物**をサマリに出している | §D-3 |
| 中 9 | `docs/design/testing.md` §7.4 / `04-human-checkpoints.md` §1.1 | **FE のみの変更では E2E が最大 24 時間走らない**。記述はあるが、E 段の担保対象がすべて FE 側の実装で壊れるものであり、緩和策 1 (PR の I 段) は FE に効かない。受容するなら H-4 の確認観点を足すべき | §D-5 |
| 中 10 | `docs/design/architecture.md:912` (M-4 行) | **CODEOWNERS はレビュー要求であって書き込み権限の分離ではない**。3 リポ構成が権限で担保していた「特定サブツリーを触れる人を絞る」の喪失が代償として書かれていない (新設した **DR-10 の 3 番目の実例**) | §E-4 |
| 中 11 | `.github/CODEOWNERS` + `04-human-checkpoints.md:314` | 「`api/` は BE / FE **双方の承認**」は GitHub の Code Owners の挙動として成立しない可能性が高い (1 行複数オーナーは 1 名で充足。要確認 3) | §E-5 |
| 中 12 | `scripts/hooks/pre-commit:80` | `npx vitest related --run` は**関連テスト 0 件で exit 1** になる見込み。`--no-verify` が禁止されているため**回避不能な詰まり**になる (要確認 4) | §E-6 |
| 中 13 | `docs/design/architecture.md:913` (M-5 行) | **M-5 (タグ名前空間) は宣言だけ**。機構・立ち上げチェックリスト・§2.6 のいずれにも無いのに「6 件すべてを立ち上げ時に用意する」に数えられている | §F-1 |
| 中 14 | `Makefile` の `make check` | **モノレポ機構を見る検査が 1 つも無い** — 故障注入 3/3 非検出 (`gate` の `needs` 欠落 / issue テンプレの必須欄 / 「6 機構」の件数) | §G-2 |

## ④ 軽微 (Nice to Have)

| # | 箇所 | 内容 |
|---|---|---|
| 軽微 1 | `deploy-backend.yml:26`〜`:31` | 「ci.yml と**同じ条件**にする」と書きつつ実物は上位集合 (`.github/workflows/deploy-backend.yml` を含む)。規約を「⊆ + 追加分は理由をコメント」に直す (§A-5) |
| 軽微 2 | `e2e.yml:186`〜`:188` | `upload-artifact` の `path:` にも「アクション入力は `working-directory` に従わない」注意が必要 (置換時に `frontend/` を落とすとレポートが空になる) (§C-1) |
| 軽微 3 | `scripts/hooks/pre-commit:30` | `backend/go.mod` が無いとき**無言でスキップ** (frontend 側は WARN を出す) (§E-6) |
| 軽微 4 | `task-backend.yml:61` / `task-frontend.yml:59` | `02-issue-granularity.md` §4.3 が要求する「契約行」が**半分しか入っていない** (BE 側に `npm run generate` が無く、FE 側に `make -C backend docs` が無い) (§E-6) |
| 軽微 5 | `04-human-checkpoints.md` §2.6 の直後 | 「**H-5 以外は GitHub 側の機構で回避不可能な形にする**」が、M-6 (回避可) の追加で事実と食い違う (§F-2) |
| 軽微 6 | `deploy-backend.yml:458` / `:472`・`rollback-backend.yml:120` | ecspresso の config プレースホルダが `<stacks/...>` で **`backend/` 接頭辞が無い**。`operations.md` §5.3 は `backend/stacks/<env>/ecspresso.yml` と書いており不一致 (両ジョブは repo ルートで動く) |
| 軽微 7 | `docs/design/operations.md:309`〜`:310` | §5.1.1 の表がジョブ名を `backend-*` / `frontend-*` と書いているが、実物は `backend` / `frontend` の各 1 本 |
| 軽微 8 | `04-human-checkpoints.md` §4.5 | 「設定できたことの確認」に **Vercel (M-2) の確認手段が 1 つも無い** (gh api で見えないため目視項目にする) (§F) |

---

## 検証項目ごとの詳細

---

## A. M-1 (path filter + gate ジョブ) の検証

### A-1. `gate` の `needs` と `check` の一致 — **問題なし**

`templates/app-monorepo/.github/workflows/ci.yml:524` の
`needs: [changes, backend, frontend, contract]` と、同 `:537`〜`:540` の `check` 4 行が
**過不足なく 1 対 1**。ジョブ定義側も `changes` (`:30`) / `backend` (`:51`) / `frontend` (`:344`) /
`contract` (`:463`) の 4 本で、`needs` に載っていないジョブは存在しない。

### A-2. `success` / `skipped` 許容と `failure` / `cancelled` の確実な失敗 — **問題なし (実測)**

`check()` は**関数呼び出し**であり、サブシェル (`|` / `$( )` / `( )`) を経由しないため
`fail=1` は現在のシェルに残る。`set -euo pipefail` 下でも `fail=1` の代入は終了コード 0 なので
早期終了しない。`ci.yml:528`〜`:549` をそのまま切り出して 7 通りの `needs.*.result` を注入した実測:

| changes / backend / frontend / contract | exit |
|---|---|
| success success success success | 0 |
| success failure skipped success | 1 |
| success skipped skipped skipped | **0** (→ A-3) |
| success success cancelled success | 1 |
| failure skipped skipped skipped | 1 |
| skipped skipped skipped skipped | 1 |
| success success success failure | 1 |

空文字 (`result` が空) も `case` の `*` に落ちて FAIL になることを確認 (`"$2"` はクォートされており
`set -u` にも抵触しない)。**判定ロジックは仕様どおり**。

### A-3. 「全ジョブ skip なのに `gate` が緑」— **経路は存在する (中 1)**

A-2 の 3 行目のとおり、`backend` / `frontend` / `contract` がすべて skip でも `gate` は緑になる。
これは「変更されたサブツリーが無いなら検証対象も無い」という**意図された挙動として妥当**だが、
**app モノレポのルート直下には CI の検査対象になっていないファイル群が残る**:

- `.github/workflows/*.yml` (**`ci.yml` 自身・`deploy-backend.yml`・`rollback-backend.yml`・`e2e.yml`**)
- `.github/CODEOWNERS` / `.github/ISSUE_TEMPLATE/*` / `.github/pull_request_template.md`
- **`scripts/hooks/pre-commit`** (= H-1 の前段を担う機構)
- `.claude/rules/` / `.claude/settings.json` / ルート `CLAUDE.md` / `.gitattributes`

このうち `scripts/hooks/pre-commit` と各ワークフローは**機構そのもの**であり、
設計リポ側は同種のリスクに対して `make check-workflow-shell` (ワークフローに埋めた複数行 `run` の
`bash -n`) と `bash -n` の pre-commit を持っている (ルート `CLAUDE.md` の検証ゲート節)。
app モノレポ側にはこれに相当するジョブが無く、**`gate` は「ルート機構ファイルだけを壊した PR」を
緑で通す**。詳細は「中」の指摘 1。

### A-4. `changes` が skipped の異常検出は到達可能か — **到達可能 (ただし現状は到達しない状態)**

コード順では `fail` 判定 (`:541`) が先に `exit 1` するため、後段 (`:546`) が遮られるかを確認した。
`check changes "skipped"` は **`skipped` を OK 扱いにする**ので `fail` は 0 のまま後段へ進み、
`:546` が `exit 1` にする (実測: 表の 6 行目 = exit 1)。**論理的に遮られていない**。

一方、`changes` ジョブは `if:` も `needs:` も持たない (`:30`〜`:48`) ため、
**GitHub 上で `skipped` になる状態は現実には発生しない** (発生するのは `failure` / `cancelled`)。
つまりこの分岐は「将来 `changes` に `if:` が足されたときの保険」であり、
現時点では死んでいる。コメント (`:545`) が「無条件ジョブのため異常」と明記しているので誤解は生まない。

### A-5. `deploy-backend.yml` の `on.push.paths` と `ci.yml` の path filter — **不一致 (軽微 1)**

| 条件 | `ci.yml` の `backend` ジョブ | `deploy-backend.yml` の push paths |
|---|---|---|
| `backend/**` | ○ (`:44`) | ○ (`:29`) |
| `api/**` | ○ (`:48` + `:54` の OR) | ○ (`:30`) |
| `.github/workflows/deploy-backend.yml` | — | ○ (`:31`) |

`deploy-backend.yml:26` は「**path filter は ci.yml の backend ジョブと同じ条件にする**」と書いているが、
実物は **deploy 側が真の上位集合**。方向としては安全側 (CI で見ていない条件でデプロイが起動する側であり、
「CI は走ったがデプロイされない」は起きない) だが、**規約の文言と実物が食い違っている**ため、
次に誰かが「同じにする」を根拠に `.github/workflows/deploy-backend.yml` 行を削るか、
逆に `ci.yml` 側へ足す (= ワークフロー変更のたびに backend の全 CI が走る) 判断がぶれる。
**規約を「`ci.yml` の条件 ⊆ deploy の条件。追加分は理由をコメントで書く」に直すべき**。

### A-6. `04-human-checkpoints.md` の必須チェック名 — **問題なし**

- `templates/shared/.claude/rules/04-human-checkpoints.md:311` 「**app モノレポ: `gate` の 1 本のみ**」
- 同 `:384` の確認コマンド節 「checks が `["gate"]` の 1 本だけであることを確認する (M-1)」
- 同 §2.1 `:89` 「**app モノレポでは `gate` ジョブ 1 本のみを指定する**」

`ci.yml:522` の `name: gate` と一致する (ステータスチェック名はジョブの `name:`)。
個別ジョブ名の例示 (`backend …` / `frontend …` / `contract …`) も実物の `name:` の接頭辞と一致。

### A-7. `on:` が `push` と `pull_request` の両方で `branches: ["**"]` — **中 2 (要確認を含む)**

`ci.yml:22`〜`:26` は 3 リポ時代の雛形 (`git show HEAD:templates/backend-repo/.github/workflows/ci.yml:7`〜`:11`)
をそのまま引き継いでいるが、**path filter を入れた時点で意味が変わる**。

- `push` イベントの `dorny/paths-filter` は**その push に含まれる差分**を基準にする一方、
  `pull_request` イベントは **base...head の差分**を基準にする。
  したがって「backend を触った既存 PR ブランチに、docs だけの追加コミットを push する」と、
  同一 SHA に対して **`backend` が skip された push 実行**と **`backend` が走る PR 実行**の
  2 つの `gate` チェックが生まれる
- **要確認**: 同名 (`gate`) のチェックランが同一 SHA に 2 つある場合、ブランチ保護が
  どちらの結論を採用するか (最後に完了したものか / 全部の AND か) を実挙動として確認できていない。
  最後に完了したものを採る挙動であれば、**PR 実行の赤を push 実行の緑が上書きし得る** —
  つまり M-1 の担保が状況依存になる。3 リポ時代は path filter が無く全ジョブ無条件だったため
  この差は生じなかった
- 副作用として **PR ブランチへの push ごとに CI が二重に走る** (コスト)

**修正案**: `pull_request` は `branches: [main]`、`push` は `branches: [main]` に絞る
(feature ブランチの検証は PR 実行が担う)。少なくとも
`04-human-checkpoints.md` §4.1 の「3 通りの PR で確認する」チェック項目に
**「同一 SHA に `gate` が 2 つ出ないこと」**を足す。

---

## B. M-3 (contract ジョブ = OpenAPI 契約の再生成漏れ検査) の検証

### B-1. `git diff --exit-code` が未追跡ファイルを見ない — **重大 1 (M-3 の主目的が「新規追加」で効かない)**

`ci.yml:492` / `:511` は次のとおりで、**未追跡ファイルの検出手当てが一切ない**
(`git status --porcelain` / `git add -N` / `--no-ext-diff` のいずれも無い。
`grep -rn "porcelain\|add -N\|untracked\|未追跡" templates/app-monorepo/` → **ヒット 0**)。

```
- name: api/openapi.yaml の差分チェック (BE の IF 変更が契約に反映されているか)
  run: |
    git diff --exit-code -- api/openapi.yaml || { ... }
...
- name: frontend/src/generated の差分チェック (FE の型ズレ検出)
  run: |
    git diff --exit-code -- frontend/src/generated || { ... }
```

実測 (使い捨てリポジトリで再現):

```
$ git diff --exit-code -- api/openapi.yaml      # openapi.yaml を新規生成した直後
exit=0                                          ← 検出されない
$ git diff --exit-code -- frontend/src/generated # 生成物を新規追加した直後
exit=0                                          ← 検出されない
$ git status --porcelain
?? api/openapi.yaml
?? frontend/
$ git add -A -N -- api frontend/src/generated && git diff --exit-code -- api/openapi.yaml
exit=1                                          ← intent-to-add を挟めば検出される
```

**本番で何が起きるか**:

1. **立ち上げ直後の 1 回目が必ず素通りする**。`templates/app-monorepo/api/` は `.gitkeep` のみで
   `openapi.yaml` は存在しない。最初に `make -C backend docs` を実装した PR では
   生成物が未追跡になるため、**「契約をコミットし忘れた PR」が緑で通る**
2. **エンドポイント追加のたびに素通りし得る**。orval はタグ / パスごとにファイルを分割生成するため、
   **新しいドメインの API を足した PR は `frontend/src/generated/<new>.ts` が未追跡**になり検出されない。
   既存ファイルの書き換えを伴う変更だけが検出される
3. これは `architecture.md:911` (M-3 行) が「欠けると起きること = **モノレポ化の見返り本体が失われる**」と
   書いた事象そのもの。**モノレポ化の主目的が、最も頻度の高い変更種別 (追加) で効かない**

**修正案** (両ステップ共通。`ci.yml` の backend ジョブ `:127` / `:140` も同じ穴なので同時に直す):

```bash
git add -A -N -- api/openapi.yaml            # intent-to-add で未追跡を差分に載せる
git diff --exit-code -- api/openapi.yaml || { ... }
```

または `[ -z "$(git status --porcelain -- api/openapi.yaml)" ]` で判定する。
**同じ穴が `ci.yml` 内の全 `git diff --exit-code` (4 箇所: `:127` sqlc/wire・`:140` golden・
`:492` openapi・`:511` generated) にある**ため、修正は 4 箇所すべてに適用すること
(sqlc は新しいクエリファイルを足すと生成 `.go` が新規ファイルになる = 同じく最頻の変更で素通りする)。

### B-2. `make -C backend docs` の出力先の記述の一貫性 — **中 1 (旧記述が残っている)**

| 文書 | 記述 | 判定 |
|---|---|---|
| `templates/app-monorepo/backend/CLAUDE.md.tmpl:25` | 「`<make docs>` — **出力先は `../api/openapi.yaml`**」 | ○ |
| `templates/app-monorepo/CLAUDE.md.tmpl:25` / `:44` | `api/openapi.yaml` = 生成物・手編集禁止 / M-3 | ○ |
| `docs/design/architecture.md:871` / `:911` | 同じ | ○ |
| **`templates/app-monorepo/backend/STRUCTURE.md:208`** | 「その他、**OpenAPI 定義の出力先** (`make docs` の生成先) は**設計で確定していない**ため、ディレクトリを作っていない。frontend の型生成の入力になるため、**実装リポで決めたら本ファイルに追記する**」 | **× 旧記述** |

`STRUCTURE.md` は backend サブツリーの構造の正として実装者が最初に読む文書であり、
そこに「未確定・実装リポで決める」と書かれていると、**M-3 の前提 (出力先は `api/openapi.yaml` で確定) が
無効化される**。`api/` ディレクトリは既に雛形に存在する (`templates/app-monorepo/api/.gitkeep`) ため、
「ディレクトリを作っていない」も事実と食い違う。**`feedback_review_patterns.md` の DR-8**
(修正の波及漏れ) の典型で、`06-delegation-prompts.md` の「機構を直したら、その機構を語る文書を
同じ差分で直す」手順 1〜2 (状態語 `未確定` の grep) を実施すれば検出できた。

**修正案**: §5 の当該 2 行を削除し、「`make docs` の出力先は `../api/openapi.yaml` (M-3 の入力。
モノレポルートの `api/` に置く)」へ置換する。

### B-3. orval の入力が `../api/openapi.yaml` である旨 — **問題なし**

`templates/app-monorepo/frontend/CLAUDE.md.tmpl:15` / `:27` / `:41` に
「**`../api/openapi.yaml`** から `src/generated/` へ生成 (orval の入力にこのパスを指定する)」と明記。
設計側も `docs/design/frontend.md:315` (`入力は ../api/openapi.yaml`) / FE-E で一致。

### B-4. `contract` ジョブの起動条件 — **問題なし**

`ci.yml:466`〜`:469` は `backend || frontend || api` の OR で、
**backend だけの PR / frontend だけの PR の両方で走る**。`operations.md:339`
「この検査が M-1 の path filter で skip される条件を作らない」と整合。
(docs だけの PR では skip されるが、契約に関わるファイルが 1 つも変わっていないため妥当。)

### B-5. `.gitattributes` (`linguist-generated`) が雛形に無い — **軽微 1**

`operations.md:337`〜`:338` は M-3 の一部として
「**`api/` は `.gitattributes` で `linguist-generated` を付け、レビュー差分から畳む**」と定めているが、
`find templates -name ".gitattributes"` → **0 件**。設計に書かれた機構が雛形に落ちていない
(効果はレビュー体験のみなので軽微だが、`04-human-checkpoints.md` §4 の
立ち上げチェックリストにも無いため、そのまま忘れられる)。

### B-6. `docs/design/frontend.md:144` の `ci.yml` 行番号引用が実物とずれている — **中 2**

FE-E 行が「生成物は**コミットし、CI で再生成差分を検査**する (雛形
`templates/app-monorepo/.github/workflows/ci.yml`:41-49 が既にこの形)」と書いているが、
`ci.yml:41`〜`:49` は **`dorny/paths-filter` の `filters:` ブロック**であり、再生成差分の検査ではない
(実物は `contract` ジョブの `:486`〜`:515`)。3 リポ時代の `frontend-repo/.github/workflows/ci.yml` の
行番号がそのまま残ったもの。**DR-8 の手順 3 (行番号を引用している箇所は実測値へ更新する)** に該当。
読者は「既にこの形」の根拠として当該行を開くため、機構の実在確認が空振りする。

---

## C. サブツリー自己完結 (§3.11.1) の反証

### C-1. アクションの `with:` 入力がルートからのパスになっているか — **問題なし (全数確認)**

`defaults.run.working-directory` はアクションの `with:` 入力に効かないため、全ワークフローの
アクション入力を洗い出して確認した。

| ファイル:行 | 入力 | 値 | 判定 |
|---|---|---|---|
| `ci.yml:76` | `setup-go.go-version-file` | `backend/go.mod` | ○ |
| `ci.yml:93` | `golangci-lint-action.working-directory` | `backend` | ○ (アクション側入力を明示) |
| `ci.yml:359` / `:361` | `setup-node.node-version-file` / `cache-dependency-path` | `frontend/.node-version` / `frontend/package-lock.json` | ○ |
| `ci.yml:477` / `:482` / `:484` | contract ジョブの同 3 入力 | 同上 (ルート相対) | ○ |
| `e2e.yml:85` / `:87` | `setup-node` の 2 入力 | `frontend/...` | ○ |
| `e2e.yml:186`〜`:188` | `upload-artifact.path` | `<playwright-report/>` / `<test-results/>` | **要注意** — プレースホルダだが、`upload-artifact` の `path` も `working-directory` に**従わない**。実構成では `frontend/playwright-report` と書く必要がある。この 1 箇所だけ「ルートからのパスで書く」注意コメントが付いていない |
| `rollback-backend.yml` | `kayac/ecspresso@v2` / `configure-aws-credentials@v4` | パス入力なし | ○ |
| `deploy-backend.yml:91` | `docker build ... backend` (コンテキスト) | `backend` | ○ (C-5) |

**軽微 2**: `e2e.yml:186` の `path:` にも他の 3 箇所 (`ci.yml:75` / `:358` / `e2e.yml:84`) と同じ
「アクションの入力は working-directory の影響を受けない」注意を付けるべき。
プレースホルダのまま `playwright-report/` と置換すると**アーティファクトが空で保存される**
(赤の切り分けができない = `testing.md` §7.4 の再実行判断ができない)。

### C-2. `D-2①`〜`D-2⑨` の `grep` 対象パスが `working-directory: backend` 下で解決するか — **問題なし。ただし「対象 0 件で緑」の穴あり (中 3)**

すべて相対パス (`usecase` / `service` / `controller` / `entity` / `gateway` / `repository` / `.`) で書かれており、
`working-directory: backend` 下で解決する (`ci.yml:229` / `:243` / `:254` / `:284` / `:304`)。
`--exclude-dir=vendor` と `_test.go` 除外も付いている。

ただし **`grep -rn ... <targets> 2>/dev/null | ... || true` の形は、対象ディレクトリが存在しない場合も
「ヒット 0 = 合格」になる**。`feedback_review_patterns.md` の **DR-6 後半**
(「**検査が『対象 0 件』を検査して緑になる形に注意**」) がまさにこの型で、
本リポジトリは同じ穴を `check-traceability.sh` で 1 度踏んでいる。

具体的な発火条件:

- ディレクトリ名の変更・タイポ (`service` → `services`) で **L-2 系の検査が全部沈黙する**
- `ci.yml:304` の `targets` は**ドメイン名を列挙**している (`usecase/theme usecase/asset
  usecase/conversation usecase/idea usecase/plan`)。**新ドメインを足して `targets` に書き忘れると、
  その `usecase/<新ドメイン>` は D-2⑨ (a)(b)(c) すべて無検査**になる。
  `STRUCTURE.md:200`〜`:206` のとおり `knowledge` / `board` / `news` / `settings` / `account` / `ops` の
  6 ドメインが今後追加される予定であり、**発生は確実**

**修正案**: 各検査の先頭で対象の実在を検証する。例:

```bash
for d in $targets; do [ -d "$d" ] || { echo "::error::検査対象 $d が存在しません"; exit 1; }; done
```

`entity/` `gateway/` のようにまだ空のディレクトリは `.gitkeep` があるので `-d` は真になる。

### C-3. `git diff --exit-code` の pathspec — **3 箇所で欠落 (中 4)**

`02-issue-granularity.md:248` は **「`git diff` は必ず pathspec を付ける (モノレポでは cwd に限定されない)」**
を規約として宣言している。全出現の実測:

| 箇所 | pathspec | 判定 |
|---|---|---|
| `ci.yml:127` / `:140` | `-- .` | ○ |
| `ci.yml:492` / `:511` | `-- api/openapi.yaml` / `-- frontend/src/generated` | ○ |
| `01-construction-loop.md:90` / `:92` / `:317` | `-- .` / `-- api/` / `-- frontend/src/generated` / `-- backend` | ○ |
| `02-issue-granularity.md:248` (V-5) / `:249` (V-6) | `-- backend` / `-- frontend/src/generated` / `-- api/` | ○ |
| `pull_request_template.md:36` (V-5) / `:37` (V-6) / `:44` (V-5) | `-- backend` / `-- api/` / `-- frontend/src/generated` | ○ |
| `CLAUDE.md.tmpl:60` / `:61` | `-- api/` / `-- frontend/src/generated` | ○ |
| **`ISSUE_TEMPLATE/task-backend.yml:61`** | **`make sqlc wire docs && git diff --exit-code`** | **× 無し** |
| **`ISSUE_TEMPLATE/task-frontend.yml:59`** | **`npm run generate && git diff --exit-code`** | **× 無し** |
| **`backend/STRUCTURE.md:157`** | 「`make golden` + `git diff --exit-code` が再生成漏れを落とす」 | **× 無し** (散文) |

issue テンプレートの当該行は「**S-6 でオーケストレーターが自分の手で実行するコマンド**」の既定値であり、
**AI 実装者が最も高い頻度でコピペする箇所**。ここが規約違反だと、
`frontend/` に未コミットの変更を持つ状態で backend の DoD 検証をすると**無関係の差分で赤になり**、
逆に「差分があるのが普通」という学習が起きて V-5 が形骸化する。
**規約 (`02-issue-granularity.md:248`) と、その規約を実行する雛形の食い違い**なので、
「実装時に気をつける」ではなく雛形を直すべき (DR-5 の裏返し)。

**修正案**: `task-backend.yml:61` → `make sqlc wire docs && git diff --exit-code -- . ../api`
(backend/ で実行する前提。`make docs` の出力先が `../api/openapi.yaml` であるため `../api` も要る)。
`task-frontend.yml:59` → `npm run generate && git diff --exit-code -- src/generated`。

### C-4. `.golangci.yml` の `files:` と `ci.yml` の `D-2⑨` の `targets` — **一致している。ただし機械照合が無い (中 5)**

`architecture.md:981` (§5 の D-2 行) は
「**対象は `.golangci.yml` の `L3-no-sqlc-outside-repository` の `files` と一致させる** —
`ci.yml` の `targets` が SSOT の実体」と要求している。実測:

| `.golangci.yml:313`〜`:326` の `files` | `ci.yml:304` の `targets` |
|---|---|
| `**/usecase/theme/**` `**/usecase/asset/**` `**/usecase/conversation/**` `**/usecase/idea/**` `**/usecase/plan/**` `**/service/**` `**/controller/**` `**/entity/**` `**/gateway/**` (9) | `service usecase/theme usecase/asset usecase/conversation usecase/idea usecase/plan controller entity gateway` (9) |

**集合として一致** (順序のみ異なる)。

一方、**この一致を検査する機構は存在しない**。`ci.yml:262`〜`:280` の `D-2⑦`
(`scripts/check-layer-scopes.sh`) の仕様は「①実ディレクトリ ②`layering-scopes.yml`
③`.golangci.yml`」の 3 集合のみを比較し、**`ci.yml` の `targets` を入力に含めていない**。
`STRUCTURE.md` §5 の 6 ドメインが今後追加されるため、**この 2 つのリストは必ず同時に動く**。
`feedback_review_patterns.md` の **DR-9** (「件数・集合サイズの転記が複数文書に散る」→
**レビュー観点に置かず機械強制する**) の対象そのもの。

**修正案**: `check-layer-scopes.sh` の入力に第 4 集合として
「`ci.yml` の `D-2⑨` ステップの `targets=` 行」を加え、③との一致を条件 4 として検査する
(設計側は `architecture.md:981` の「一致させる」に「検査は D-2⑦ の条件 4」を追記する)。

### C-5. `deploy-backend.yml` の Docker ビルドコンテキスト — **問題なし**

`deploy-backend.yml:91` `docker build -f <backend/Dockerfile のパス> -t "$IMAGE" backend`。
コンテキストが `backend` で、`:89`〜`:90` に「ルートを渡さない (frontend/ と node_modules が
コンテキストに含まれる)」理由コメントがある。

### C-6. `golangci-lint-action@v6` + `version: "2"` スキーマの組み合わせ — **要確認 1 (中 6 の可能性)**

`backend/.golangci.yml:83` は `version: "2"` (golangci-lint **v2 系**のスキーマ) で、
`ci.yml:90` は `golangci/golangci-lint-action@v6` を `version:` 入力なしで使っている。

- **要確認**: golangci-lint v2 の設定スキーマに対応したのは **action v7 以降**という認識であり、
  action v6 が既定でインストールする golangci-lint は v1 系である (v1 は `version: "2"` を
  「unsupported configuration version」として起動時に落とす)。**この組み合わせは
  雛形を投入した最初の CI 実行で失敗する可能性が高い**。実挙動を確認していないため
  断定はしないが、**立ち上げ前に必ず 1 回実行して確認すべき項目**
- 併せて、**`version:` 入力でツールのバージョンを固定していない**点も指摘する。
  lint の新リリースで規則が増えると**コードを変えていない PR が赤になる** (再現性がない)。
  `.golangci.yml:72`〜`:74` が「規則数は 18。全 18 規則それぞれについて違反サンプルで CI が
  落ちることを確認する」という検証手順を持っているため、**その確認を行ったツールバージョンを
  固定しないと確認の意味が薄れる**

**修正案**: `uses: golangci/golangci-lint-action@v7` (または v8) + `version: v2.x.y` を明示する。
どちらを採るにせよ **action のメジャーと `.golangci.yml` の `version:` の対応を
`.golangci.yml:80` のコメントに書く**。

### C-7. 参考: depguard の規則数の自称値 — **問題なし**

`.golangci.yml:72` 「**規則数は 18**」に対し、実物の `depguard.rules` 直下のキーを数えると
18 件 (L1 系 7 / L2 系 6 / L3 1 / L4 系 2 / L5 1 / L6 1)。自称値と実測が一致。

---

## D. `e2e.yml` の `workflow_run` 化

### D-1. GitHub Actions の実挙動に依存する 3 つの主張

| # | 主張 | 判定 |
|---|---|---|
| 1 | `GITHUB_TOKEN` 起因のイベントは新しいワークフロー実行を起動しない → `repository_dispatch` は使えない | **妥当**。GitHub のドキュメント化された仕様 (`GITHUB_TOKEN` を使った push / dispatch はワークフローを起動しない。無限ループ防止) と一致する。同一リポジトリでの「先行ワークフローの完了受信」は `workflow_run` が正攻法 |
| 2 | `workflow_run.event` で dev (`push`) / prod (`workflow_dispatch`) を判別できる | **妥当**。`workflow_run` の payload には起動元ワークフローの実行情報 (`event` / `conclusion` / `head_sha` / `head_branch`) が入る。ただし **`deploy-backend.yml` の起動経路が将来 3 通り以上になると (例: tag push・`schedule`) この 2 分岐が崩れる**。`env_name` を判別の根拠にできない (ジョブ出力は `workflow_run` payload に載らない) ため、**判別軸が `event` しかないという制約はコメントに残すべき** |
| 3 | `workflow_run` 起動時の既定 ref はデフォルトブランチの最新 → `head_sha` の明示 checkout が必要 | **妥当** (GitHub のイベント別 `GITHUB_SHA` / `GITHUB_REF` 表で `workflow_run` はデフォルトブランチの最新)。`e2e.yml:79` の `ref: ${{ ... workflow_run.head_sha || github.ref }}` は正しい対処。**ただし D-3 の指摘参照 — 同じ理由で `github.sha` を使っている箇所が残っている** |

いずれも **`--- 要確認 ---` に落とすほどの疑義は無い**が、3 点とも「実挙動を 1 回の実行で確認する」項目として
`04-human-checkpoints.md` §4 の立ち上げチェックリストに無い。**M-1 の `gate` は 3 通りの PR で確認する
項目があるのに、E2E のトリガーには確認項目が無い** (D-3 / D-4 の指摘と合わせて追加すべき)。

### D-2. `e2e.yml` のサマリが `repository_dispatch` 前提のまま — **重大 2**

`e2e.yml:198`〜`:206`:

```bash
# BE 側の commit は repository_dispatch の client_payload.sha で渡ってくる。
# **nightly / 手動実行では BE の commit が不明** なので、その旨を明示する
if [ "${{ github.event_name }}" = "repository_dispatch" ]; then
  echo "- BE の対象 commit: \`${{ github.event.client_payload.sha }}\`"
else
  echo "- BE の対象 commit: **不明** (${{ github.event_name }} 起動のため)。"
  echo "  **この結果は H-4 の承認材料に使わない** (testing.md §7.4)"
fi
```

**`on:` から `repository_dispatch` は削除された** (`e2e.yml:19`〜`:46` は `workflow_run` / `schedule` /
`workflow_dispatch` の 3 つ) ため、**この条件は永久に偽**。結果として
**`workflow_run` 起動 (= 唯一 H-4 の承認材料になり得る実行) でも
「BE の対象 commit: 不明。この結果は H-4 の承認材料に使わない」と出力される**。

**本番で何が問題か**: `04-human-checkpoints.md:41` (H-1〜H-5 表の H-4 行) の確認観点②
「その変更が dev で検証済みであること」の証拠が **E2E のサマリ**であり、
`testing.md` §7.4 の緩和策 2 は「**E2E が赤の状態で prod デプロイを進めない**」を H-4 の承認材料で担保する。
サマリが常に「承認材料に使わない」と書くため、**H-4 の承認材料が構造的に存在しない**状態になる。
実運用では「毎回出る注意書き」として無視されるようになり、**警告の摩耗**を招く
(= 機構としては存在するが機能しない。`04-human-checkpoints.md` の原則
「機構の無い承認点を作らない」の実質的な違反)。

しかも `testing.md` §7.4 は**モノレポ化でこの分岐が不要になったことを明記している**:
「**モノレポ化 (2026-08-03。D-I の方針転換) でこの条件は構造的に満たされた** — BE と FE が
同一リポジトリの同一 commit に属するため、`workflow_run.head_sha` 1 つが BE / FE 双方の
検証対象を一意に指す (…**その分岐は不要になった**)」。
**設計文書は正しく更新され、機構 (雛形) が旧実装のまま残っている** — `06-delegation-prompts.md` の
「機構を直したら文書を直す」の**逆向きの取り残し**。

**修正案**:

```bash
if [ "${{ github.event_name }}" = "workflow_run" ]; then
  echo "- 検証対象 commit (BE / FE 共通): \`${{ github.event.workflow_run.head_sha }}\`"
  echo "- 起動元: ${{ github.event.workflow_run.name }} #${{ github.event.workflow_run.run_number }}"
else
  echo "- 対象 commit: **不明** (${{ github.event_name }} 起動)。H-4 の承認材料に使わない"
fi
```

### D-3. `github.sha` を「FE の対象 commit」として出力している — **中 7**

`e2e.yml:197` `echo "- FE の対象 commit: \`${{ github.sha }}\`"`。
**`workflow_run` 起動時の `github.sha` はデフォルトブランチの最新**であり (D-1 の主張 3 が自ら述べている)、
`:79` で実際に checkout した `workflow_run.head_sha` とは**別物になり得る**
(デプロイ完了までに main が進んだ場合に必ずずれる)。
サマリに載る commit と実際にテストしたコードが食い違い、**回帰の切り分けで誤った commit を疑う**。
D-2 の修正と同時に `head_sha` へ統一すること。

### D-4. `testing.md` §7.4 に廃止済みの `E2E_DISPATCH_TOKEN` 機構の要求が残っている — **重大 3**

同じ §7.4 の中で**相反する 2 つの記述が併存**している。

- 廃止を宣言している側 (`docs/design/testing.md:414` 付近):
  「**`E2E_DISPATCH_TOKEN` は廃止**」「⚠️ **`repository_dispatch` を `GITHUB_TOKEN` で打つ形に
  置き換えてはいけない**」
- 旧機構を要求している側 (同 `:416`〜`:418`):
  「**トークン未設定でもデプロイは失敗させない** (…) が、**警告を出す**」
  「**警告を出す条件は 2 つ**(…) ①**トークンが未設定**のとき ②**dispatch の HTTP ステータスが
  204 でないとき**」「**雛形は 2026-07-30 にこの形で実装済み**
  (`templates/app-monorepo/.github/workflows/deploy-backend.yml`:491〜507)」

**実物には `curl` も dispatch も存在しない** (`deploy-backend.yml` に `curl` の出現は 0 件。
`:491`〜`:502` は E2E 起動方法を `echo` で記録するだけのステップ)。
`docs/design/testing.md:882` (§13 の是正要求 13) も「2026-07-30 に是正済み — `curl` の HTTP ステータスを
`-w '%{http_code}'` で取り…**残る要求は無い**」と、存在しない実装を「是正済み」として閉じている。

**本番で何が問題か**: 実装リポの開発者 (人間・AI とも) は設計文書を正として読むため、
**「警告条件 2 つを実装する」= `repository_dispatch` を復活させる**方向に動く。その実装は
①同じ節が禁止している (`GITHUB_TOKEN` では起動しない) ②**GitHub 側に repo 権限を持つトークンを
置くことになり、`operations.md` §4.1 の限定列挙 (IAM ロール ARN と非秘密識別子のみ) に例外を
再導入する** — セキュリティ方針の後退を、設計文書自身が指示する形になっている。

**修正案**: `testing.md` §7.4 の「トークン未設定でもデプロイは失敗させない」以降の
警告条件 2 つのブロックを削除し、代わりに `workflow_run` の失敗モード
(**起動元ワークフローの `name:` 変更 / `e2e.yml` がデフォルトブランチに無い場合は発火しない**) を
「無言のスキップ」対策として書く。§13 の是正要求 13 は「**機構ごと廃止 (2026-08-03)**」に書き換える。

### D-5. `frontend/` のみの変更で E2E が起動しないことの帰結 — **記述あり。許容の根拠は薄い (中 8)**

`testing.md` §7.4 に明記されている:
「**FE のみの変更では `deploy-backend.yml` が起動しない** (path filter。M-1) ため
`workflow_run` も発火しない。その場合は nightly が拾う」。`e2e.yml:29`〜`:31` にも同じ記述がある。
**DR-2 (無言の省略) には当たらない**。

ただし**許容と言えるかは別**:

- **FE のみの変更が最も E2E で守りたい対象**である。`testing.md:120` の E 段の担保対象は
  「認証 / 画面遷移 / **SSE が実ブラウザに届くこと** / 非同期ジョブの完了表示 / 生成物が別画面で
  参照できること / 再接続での復元」で、**すべて FE 側の実装で壊れる**
- 3 リポ構成では `frontend` リポの `main` push が E2E の起動契機になり得た (旧 `e2e.yml` の
  `repository_dispatch` 待ちだったため実際には同じ穴だったが、**モノレポ化で「FE の変更は
  BE のデプロイに相乗りしない」ことが構造として固定された**)
- §7.4 の緩和策 1 は「PR では I 段が同じ縦串を `httptest` で通す」だが、
  **I 段には実ブラウザが無い** (同 §9.1.1「FE には実 DB を伴う段が無いため I 段は空」)。
  つまり FE のみの変更に対する緩和策 1 は**実質的に効かない**

**修正案** (どれか 1 つを設計判断として採り、却下案とともに §7.4 に書く):

- (a) `e2e.yml` に `on.push: { branches: [main], paths: ['frontend/**','api/**'] }` を足す
  (Vercel の Preview デプロイ完了を待たないので、冒頭で `E2E_BASE_URL` の `/alive` 相当を
  ポーリングして新 revision を待つ必要がある)
- (b) Vercel の Deploy Hook / Deployment 完了 Webhook を `repository_dispatch` で受ける
  (トークンが再登場するため §4.1 の例外扱いになる)
- (c) 現状維持 (nightly まで最大 24 時間) を**明示的に受容と書く** —
  その場合は「FE のみの変更を含む prod デプロイ (H-4) では、
  **nightly の結果が当該 commit を含んでいることを承認者が確認する**」を
  `04-human-checkpoints.md` §1.1 の H-4 確認観点に足す (現状は「最新の E2E 結果」しか書かれておらず、
  その E2E が FE の変更を含むかを問うていない)

### D-6. `defaults.run.working-directory: frontend` と `if:` の整合 — **問題なし。ただし artifact path に穴 (C-1 で既出)**

`e2e.yml:64`〜`:73` の `if:` は `workflow_run` 以外 (schedule / workflow_dispatch) を素通しし、
`workflow_run` のときだけ `conclusion == 'success' && event == 'push'` を要求する。
`defaults` は `run:` のみに効くので `if:` との干渉は無い。
`:126` の `<npx playwright test>` / `:142` の `REPORT="playwright-report/results.json"` は
`frontend/` 相対で一貫している。**唯一の例外が `:186`〜`:188` の `upload-artifact` の `path:`**
(C-1 の軽微 2)。

### D-7. `workflows: [Deploy]` のリネーム脆弱性 — **注意書きあり (問題なし)**

`e2e.yml:33` `workflows: [Deploy]        # deploy-backend.yml の `name:`。**リネームしたらここも直す**`。
`deploy-backend.yml:1` の `name: Deploy` と一致。**機械照合は無い**が、注意書きが実物に付いており、
かつ `rollback-backend.yml` の `name:` と衝突しないことも確認した
(リネーム時に E2E が無言で起動しなくなる形なので、
`04-human-checkpoints.md` §4 の確認項目に「デプロイ後に E2E が起動したか」を入れると機械化に近づく)。

### D-8. **雛形の行番号を引用した設計文書 36 箇所が、パスだけ置換され行番号が旧ファイル基準のまま — 重大 4**

`templates/backend-repo/` · `templates/frontend-repo/` → `templates/app-monorepo/` の移動に伴い、
設計文書の**リンク先パスは一括置換されたが、行番号が更新されていない**。
`make doc-lint` はリンクの実在しか見ない (`05-harness.md` の「見る / 見ない」表: 行番号のズレは
design-reviewer の仕事) ため、**機械検査は緑のまま通る**。

実測 (`grep -rnoE "templates/app-monorepo/[A-Za-z0-9_./-]+\)+:[0-9]+" docs/design/`):

| 引用先 | 件数 | 状態 |
|---|---|---|
| `.github/workflows/ci.yml` | **20** | **全滅** (2 ファイルを 1 本に統合したため。旧 `frontend-repo/ci.yml` は約 130 行、新ファイルは 550 行) |
| `.github/workflows/e2e.yml` | **3** | 全滅 |
| `.github/workflows/deploy-backend.yml` | **2** | 全滅 (引用先の実装そのものが削除されている = D-4) |
| `scripts/hooks/pre-commit` | **2** | 全滅 (2 ファイル統合のため) |
| `frontend/.eslintrc.json.tmpl` | 9 | **有効** (このファイルは無変更で移動したため行番号が保たれている) |

抜き取り照合 11 件 (すべて不一致):

| 引用元 | 主張 | 引用先の実際の内容 | 実際の所在 |
|---|---|---|---|
| `testing.md:89` (T-B) | `services: postgres` が `ci.yml:17〜26` にある | ヘッダコメントと `on:` | `ci.yml:59`〜`:68` |
| `testing.md:223` (規約 4) | golden 差分チェックが `ci.yml:88〜` | `golangci-lint` ステップ | `ci.yml:135`〜`:147` |
| `testing.md:274` | `check-route-auth.sh` が `ci.yml:97〜105` | スキーマ適用のコメント | `ci.yml:169`〜`:177` |
| `testing.md:511` / `:661` | `ci.yml:73〜74` | `setup-go` の `with:` | (FE の検査は `:385`〜) |
| `testing.md:574` / `:660` / `:677` (F-C3) | 併置テスト検査が `ci.yml:58〜71` | backend ジョブの `services:` | `ci.yml:385`〜`:398` |
| `testing.md:873` | `check-owner-scope.sh` が `ci.yml:107〜116` | スキーマ適用の `if` ブロック | `ci.yml:179`〜`:188` |
| `frontend.md:144` / `:327` / `:1022` (FE-E) | 再生成差分検査が `ci.yml:41-49` | `paths-filter` の `filters:` | `ci.yml:486`〜`:515` |
| `frontend.md:611` / `:1023` | `globals.css` 行数検知が `ci.yml:119-129` | sqlc/wire の差分チェック | `ci.yml:446`〜`:456` |
| `frontend.md:647` / `:1024` | `ci.yml:58-72` | backend ジョブの `services:` | (FE の検査) |
| `frontend.md:873` / `:965` | `ci.yml:73-98` / `:99-118` | setup-go / スキーマ適用 | `ci.yml:400`〜`:444` |
| `testing.md:102` (T-O) | `npx vitest related --run` が `pre-commit:34` | `go build ./...` | `pre-commit:80` |

**本番で何が問題か**: これらの引用は**ほぼ全て「実装済み」「既にある」の根拠として**書かれている
(例: `frontend.md:611`「実装済み: ci.yml:119-129」)。実装リポの開発者が根拠を開くと**別の検査が
そこにあるため、「これのことか」と誤読して重複実装 / 未実装の見落としが起きる**。
`feedback_review_patterns.md` の **DR-1 (出典なしの断定)** の変種で
「**出典があるが指している先が違う**」形 — 出典があるぶん検証されにくく、質が悪い。

**修正案**: `docs/design/` 内の `templates/app-monorepo/` への行番号付き引用を洗い出し、
`grep -n` の実測値で更新する。あわせて**行番号引用そのものを減らす** —
`ci.yml` のステップ名は `D-2①` のような ID を持っているので (`architecture.md:981` の規約)、
**行番号ではなくステップ名で引用する** (`ci.yml` の `D-2⑨` ステップ) 形にすれば、
以後の行番号ドリフトが構造的に起きない。この方針は DR-9 の
「**数えた値を書かずに再現コマンドを書く**」と同型。

---

## E. テンプレート (issue / PR / CODEOWNERS / pre-commit)

### E-1. AC-2.3 「3 本 × 必須 5 欄」 — **問題なし (実測を証拠として貼る)**

`aidlc-docs/inception/construction-workflow/plan.md:61` の AC-2.3:
「`.github/ISSUE_TEMPLATE/` の issue テンプレートが **3 本** (app の `task-backend.yml` /
`task-frontend.yml` + infra リポの `task.yml`) 存在し必須 5 欄を含む」。

```
$ grep -c 'required: true' <各テンプレート>
templates/app-monorepo/.github/ISSUE_TEMPLATE/task-backend.yml    5   (行 25 / 46 / 65 / 85 / 104)
templates/app-monorepo/.github/ISSUE_TEMPLATE/task-frontend.yml   5   (行 26 / 44 / 63 / 81 / 99)
templates/infra-repo/.github/ISSUE_TEMPLATE/task.yml              5   (行 25 / 47 / 65 / 83 / 100)
```

**3 本すべてで 5 件**。`02-issue-granularity.md` §4.1 の
「必須 5 欄はどのテンプレートでも同一にする」も満たしている
(欄の内容も対象 AC-ID / 影響する層 / 検証コマンド / 人間チェックポイント / 依存 issue の 5 つで一致)。

### E-2. PR テンプレート 1 本化と V-1〜V-10 の保持 — **問題なし**

`pull_request_template.md` の V-ID 出現: V-1 (`:26`) / V-2 (`:33`・`:41`) / V-3 (`:34`・`:42`) /
V-4 (`:35`・`:43`) / V-5 (`:36`・`:44`) / V-6 (`:37`・`:45`) / V-8 (`:27`) / V-9 (`:28`) / V-10 (`:29`)。
**V-7 は `:21` で「infra リポ専用のため本テンプレートには無い」と明記**。

「該当しない側のブロックを削除する」運用 (`:31` / `:39`) と
`02-issue-granularity.md` §4.2-1 の「**ID を落とさない**」規約の両立を検証した:

- 削除対象は **backend ブロック / frontend ブロック**で、**両ブロックが V-2〜V-6 を重複して持つ**ため、
  どちらを削っても **V-2〜V-6 の ID は残る**
- 共通ブロック (V-1 / V-8 / V-9 / V-10) は削除対象外
- `api/` のみの PR は成立しない (`:9`「backend / frontend の少なくとも一方と同時になる」) ため、
  **両ブロックが同時に消える経路は無い**

**結論: 両立している**。ただし機械検査は無いので、**「両方削除して V-2〜V-6 が消えた PR」を
人間 (H-1) が見落とす余地はある** (残余リスク。M-6 の宣言欄と同じ性質)。

### E-3. §4.2 の「V-7 は infra リポのみ / V-6 は app モノレポのみ」 — **一致 (実測)**

| | V-6 | V-7 |
|---|---|---|
| `templates/app-monorepo/.github/pull_request_template.md` | **有** (`:37`・`:45`) | **無** (`:21` に理由を明記) |
| `templates/infra-repo/.github/pull_request_template.md` | **無** (`grep -n "V-6"` → 0 件) | **有** (`:22`) |

### E-4. CODEOWNERS で置き換えられない担保 (書き込み権限の分離) が代償として書かれていない — **中 9**

`templates/app-monorepo/.github/CODEOWNERS` 自体は良く書けている (既定行あり / `/api/` は双方指定 /
`/.github/` `/.claude/` `/scripts/` を機構の所有者に寄せている / 「"Require review from Code Owners" を
有効にして初めて効く」注意もある)。

問題は**設計文書側**。`architecture.md:912` の M-4 行は
「機構: CODEOWNERS / 欠けると起きること: リポ境界で担保されていたレビュー担当の分離が消える」までしか
書いておらず、**CODEOWNERS では回復できない担保があることを書いていない**:

- **CODEOWNERS はレビュー要求であって書き込み制御ではない**。3 リポ構成では
  **リポジトリ単位のコラボレータ権限**で「FE 担当者は backend リポに push できない」を担保できた。
  モノレポでは **app リポの write 権限を持つ全員が `backend/` にも `.github/` にも push できる**
  (ブランチ保護は `main` への直接 push を止めるが、**PR ブランチには誰でも何でも書ける**)
- `sed -n '846,935p' docs/design/architecture.md | grep -n "権限\|アクセス"` → **ヒット 0 件**。
  §3.11 全体に権限の記述が無い。D-I の却下案 (b) では「AWS 変更権限も分けにくい」と
  **infra についてのみ**権限に触れており、app 内の BE/FE 間については触れていない

**本番で何が問題か**: `08-production-gates.md` の A 領域が扱う認証・テナント境界のコードは
`backend/common/auth/` に集まる。「その部分を触れる人を絞る」担保が 3 リポ構成では権限で成立していたのに、
**モノレポでは「CODEOWNERS があるから同じ」と誤解される**。実際には
CODEOWNERS を消す PR も `/.github/` の owner レビューだけで通る (自分が owner なら自己承認できる)。

**修正案**: `architecture.md` §3.11.2 の M-4 行に代償を明記する —
「**CODEOWNERS はレビュー要求であり、書き込み権限の分離ではない**。3 リポ構成で権限分離により
担保していた『特定サブツリーを触れる人を絞る』は**モノレポでは回復できない**。
必要なら GitHub Rulesets の `restrict updates` / 必須承認者数の引き上げで補う」。
併せて `04-human-checkpoints.md` §2.6 (機構なしゼロの表) の H-1 行に、
この残余を回避可能性として書く。

### E-5. `CODEOWNERS` の「双方の承認」は GitHub の挙動として成立しない可能性 — **中 10 (要確認 2)**

- `CODEOWNERS`: `/api/  @<owner>/<backend-reviewers> @<owner>/<frontend-reviewers>`
  にコメント「**契約は両サブツリーに影響するため双方の承認を要求する**」
- `04-human-checkpoints.md:314`: 「**`api/` は BE / FE 双方の承認**」

**要確認**: GitHub の "Require review from Code Owners" は、**1 つのルール行に複数のオーナーを
並べた場合、そのうち**1 名の承認で充足する**という認識である (「各オーナーから 1 件ずつ」ではない)。
この認識が正しければ、上記 2 箇所の記述は**実現しない担保を実現していると書いている**ことになり、
`04-human-checkpoints.md` の原則「機構の無い承認点を作らない」に反する。

**修正案** (いずれか): (a) `api/` の変更を含む PR は **必須承認者数を 2 に上げる**
ルールセットを立ち上げチェックリストに足す (b) 「双方の承認」を落とし
「**どちらかのチームのレビューが必須**」に記述を弱める (c) `api/` を
`/api/ @<owner>/<app-maintainers>` にして、BE/FE 双方を含むチームを 1 つ作る。
**どれを採るにしても、立ち上げ時に「BE のみの approve で `api/` の変更がマージできるか」を
1 回試して確認する項目を §4.1 に足す**。

### E-6. `pre-commit` (統合版) のシェル検証

`bash -n templates/app-monorepo/scripts/hooks/pre-commit` → **OK (構文エラーなし)**。

| 検証項目 | 結果 |
|---|---|
| `grep -E '^backend/'` が `git diff --cached --name-only` の出力形式と合うか | **○**。`git diff --cached --name-only` は**リポジトリルート相対**でパスを出す (`--relative` / `diff.relative` を設定していない限り)。`:14` で `cd "$(git rev-parse --show-toplevel)"` しているため cwd も一致 |
| `(cd backend && ...)` の終了コード伝播 | **○**。`if ! (cd backend && go build ./...); then` の形でサブシェルの終了コードを直接判定している (`set -e` に依存していない。`:12` は `set -uo pipefail` で `-e` 無し = 意図的) |
| `vitest related` に渡すパスの接頭辞除去 | **○ (実測)**。`echo "$ts_staged" \| sed 's#^frontend/##' \| tr '\n' ' '` に `frontend/src/features/theme/ThemeList.tsx` を通すと `src/features/theme/ThemeList.tsx` になり、`(cd frontend && npx vitest related ...)` の cwd と整合。backend 側も `sed 's#^backend/##' \| xargs -n1 dirname \| sed 's#^#./#'` で `backend/main.go` → `./.` (有効なパッケージ指定) / `backend/usecase/theme/create_theme.go` → `./usecase/theme` になることを実測 |
| 空 staged の扱い | **○**。`echo "" \| grep -E '^backend/' \|\| true` は空文字を返し、`:21` の全空判定で早期 `exit 0` |
| 3 リポ版から落ちた機能 | **無し**。旧 `backend-repo` / `frontend-repo` の hook と比較して、生成物追従・OpenAPI 追従・生成型手編集・Agent 再発行の注意喚起がすべて残り、**M-6 の同梱検出 (`:120`) が新規追加**されている |

**中 11**: `npx vitest related --run $rel` は、**変更した `.ts` に関連テストが 1 つも無い場合に
vitest が「No test files found」で終了コード 1 を返す**ため、
**テストを持たないファイル (設定 `.ts`・型定義・生成物以外の雑多なモジュール) を触った commit が
ブロックされる**可能性が高い (要確認 3 — vitest のバージョンによる)。
`05-harness.md` / 各 `CLAUDE.md` は **`--no-verify` を禁止**しているため、
**開発者が回避できない詰まり**になる。`--passWithNoTests` を付けるべき
(3 リポ時代の frontend hook にも同じ問題があったが、モノレポでは
`frontend/` を 1 行触っただけの PR でも発火するため頻度が上がる)。

**軽微 3**: `:30` の backend ブロックは `[[ -f backend/go.mod ]]` が偽のとき**無言でスキップ**する
(frontend 側は `:66` で `WARN:` を出す)。立ち上げ初期に `go.mod` が無い状態で
「hook が通った」と誤認するため、`else echo "[pre-commit] WARN: backend/go.mod が無い — スキップ"` を足す。

**軽微 4**: `02-issue-granularity.md` §4.3 は issue テンプレートの検証コマンド既定値を
「`01` §1.3 の <サブツリー> 行 **+ 契約行**」と定めているが、実物は**契約行の半分しか入っていない**
(`task-backend.yml:61` は `make sqlc wire docs && git diff --exit-code` で
**FE 側の `npm --prefix frontend run generate` が無い** / `task-frontend.yml:59` は
`npm run generate` のみで **`make -C backend docs` が無い**)。
契約に触る issue では両方向を回さないと `contract` ジョブと同じ検査にならない。

---

## F. 機構なしゼロの確認 (M-1〜M-6 × `04-human-checkpoints.md` §2.6)

| # | 機構 | 実体 (機構あり / 宣言だけ) | 立ち上げチェックリスト | §2.6 の表 | 判定 |
|---|---|---|---|---|---|
| **M-1** | path filter + gate | **機構あり** — `ci.yml:521`〜`:549` (`if: always()` + 4 ジョブ集約) | §4.1 に「`gate` 1 本のみ」+ 3 通りの PR での挙動確認 + §4.5 に `gh api ... required_status_checks.contexts` の確認 | H-1 行の「二重化」欄に「指定漏れ = CI 無しでマージ可能」として登録済み | **○**。ただし ①全 skip で緑 (A-3) ②`needs` とジョブ集合の一致が無検査 (G の注入 1) |
| **M-2** | Vercel の Root Directory + Ignored Build Step | **人手設定** (雛形では表現不能。`04` §4.4 が明記) | §4.4 にチェック項目あり | **未登録** | **△**。§4.5 の「設定できたことの確認」に **Vercel 側の確認コマンドが 1 つも無い** (gh api で見えないため)。**「Preview が backend だけの PR で起動しないこと」を 1 回目視確認する項目**を §4.4 に足すべき |
| **M-3** | OpenAPI 契約の再生成漏れ検査 | **機構あり** — `ci.yml:463`〜`:515` | (CI なので不要) | 不要 (承認点ではない) | **×**。**未追跡ファイルを検出しないため、最も頻度の高い「追加」で機能しない** (重大 1) |
| **M-4** | CODEOWNERS | **機構あり** — `.github/CODEOWNERS` + §4.1 の "Require review from Code Owners" + §4.5 の `test -f` と `gh api ... require_code_owner_reviews` | あり | 間接 (M-6 行が「`CODEOWNERS` により `api/` は双方の承認」と参照) | **△**。①「双方の承認」は GitHub の挙動として成立しない可能性 (中: E-5) ②**書き込み権限の分離は回復できない**旨が代償として未記載 (中: E-4) |
| **M-5** | タグ / リリースの名前空間 (`backend-v*` / `frontend-v*`) | **宣言だけ** — 全リポジトリ検索で `backend-v` / `frontend-v` の出現は **`architecture.md:913` と `CLAUDE.md.tmpl:46` の 2 箇所のみ**。タグを**作る仕組みがどのワークフローにも無い** (`deploy-backend.yml` はイメージタグのみで git tag を打たない) | **無し** | **未登録** | **×** (中: F-1) |
| **M-6** | 破壊的 API 変更は PR を分ける | **宣言だけ** — PR テンプレート §5 (`:83`〜`:92`) + `pre-commit:120`〜`:124` の非ブロック警告 | (規約なので不要) | **登録済み** (回避可 + 二重化欄あり) | **△**。形式は満たすが下記 |

### F-1. M-5 が「宣言だけ・機構ゼロ・チェックリスト外」 — **中 12**

`architecture.md:904` は **「6 件すべてを立ち上げ時に用意する」**と書いているが、
M-5 は**用意する場所が存在しない**。現状はタグを打つ手順自体が設計に無いため実害は出ていないが、

- `operations.md` §5.3 のロールバックは「直前のタスク定義に戻す」で git tag を使わないため、
  **タグが無くても運用は回る**。であれば **M-5 は「本増分では対象外 (先送り)」と書くべき**で、
  「立ち上げ時に用意する 6 件」に数えるのは誤り (DR-2 の逆 = **やらないことを「やる」と書いている**)
- 逆に必要と判断するなら、**`04-human-checkpoints.md` §4 に「リリースタグの命名規約を
  リポジトリ設定 (タグ保護ルール) で強制する」項目**を足す (GitHub の tag protection rules で
  `backend-v*` / `frontend-v*` 以外を作れないようにできる = 機構化可能)

### F-2. M-6 は §2.6 の形式は満たすが、§2.6 自身の宣言と矛盾する — **軽微 5 + 機械化の余地**

- **形式**: §2.6 の M-6 行は「機構 = PR テンプレート §5 の宣言欄 → H-1 の確認観点⑧」「回避可能性 = 回避可」
  「二重化 = pre-commit の非ブロック警告」を埋めており、**「機構: なし」の行にはなっていない**
- **矛盾**: 同表の直後に「**H-5 以外は GitHub 側の機構で回避不可能な形にする**」と書かれている。
  M-6 の追加で **「回避可」の行が H-5 と M-6 の 2 つ**になったのに、この一文が更新されていない (DR-8)。
  「H-5 と M-6 以外は…」に直すか、M-6 を回避不可にする
- **機械化の余地 (推奨)**: 破壊的 API 変更は **`api/openapi.yaml` の差分から機械判定できる**
  (エンドポイント / 必須パラメータ / レスポンス必須フィールドの削除。`oasdiff` 等の
  OpenAPI 差分ツールが breaking change 判定を持つ)。`contract` ジョブに
  「**base の `api/openapi.yaml` と比較して breaking なら、PR 本文の §5 で ①②③ のいずれかが
  宣言されていることを要求する**」検査を足せば、**「宣言忘れ」を機構で捕まえられる**。
  現状の「唯一の検出経路 = 人間が宣言欄を読む」は、`04-human-checkpoints.md` の原則
  (「注意する」とだけ書かれた承認点は忘れた瞬間に無言で通過する) が最も当てはまる場所である

---

## G. 検証ゲートと故障注入

### G-1. `make check` (**注入前・基準線**)

```
[doc-lint] 対象 109 ファイル / エラー 0 件 / 警告 46 件
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 86/86 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
[workflow-shell] 検査 53 ブロック / エラー 0 件
[table-counts] 実測: 機能テーブル 42 (個人 34 / 契約 8) / 分類 ①31 ②2 ③1
[table-counts] 実測: 機能テーブル以外 12 (所有者列なし 7 / 所有者列あり 5) / 検査①の除外リスト 9
[table-counts] 照合 37 件 / エラー 0 件
[endpoint-mapping] 実測: auth-accounts.md 37 本 / 9 ドメイン 112 本 / settings.md §5 18 行 / custom tool 8 本 / 403 16 本
[endpoint-mapping] 照合 36 件 / エラー 0 件
make check exit=0
```

警告 46 件は既存 (過去 review・`design_memo.md` の「TODO」語 / 未回答 `[Answer]` 5 件)。
**本レビュー対象由来の新規警告は無い** (本 review ファイルを追加すると警告が増えるが、
増分は**本ファイル自身が「TODO」の語を引用していること**への反応のみ。
最終状態は `make doc-lint` = エラー 0 件)。

> 注: 初回実行時、本 review ファイルが引用のために貼った相対リンク 2 件が
> `[ERROR] リンク切れ` になった (review の置き場は `aidlc-docs/reviews/<feature>/` で、
> 設計文書 (`docs/design/`) からの相対パスをそのまま引用すると解決しない)。
> 引用をリンク記法から backtick 表記に変えて解消済み。**上記が最終結果**。

### G-2. 故障注入 3 種 — **3/3 非検出**

| # | 注入内容 | 期待 | 結果 |
|---|---|---|---|
| 1 | `ci.yml:524` の `needs: [changes, backend, frontend, contract]` から **`contract` を削除** (= `gate` が contract の失敗を見逃す状態) | 何かが落ちる | **非検出** (`make check` exit=0。全項目の件数が基準線と同一) |
| 2 | `task-backend.yml` の `required: true` を 1 つ `false` に (= 必須 5 欄が 4 欄に。AC-2.3 違反) | `check-traceability` が落ちる | **非検出** (exit=0) |
| 3 | `architecture.md` の「**6 機構**」→「**5 機構**」(2 箇所。§3.11.2 の見出しと本文) | `check-table-counts` が落ちる | **非検出** (exit=0) |

**評価**: 3 件はいずれも**モノレポ化で新設された担保の中核**であり、
`feedback_review_patterns.md` の **DR-9**「新しく『N 件』を書くときは、同時に検算の対象に加えるか、
書かずに定義元へのリンクにする」と **DR-6**「新しい ID 体系を導入したら、検査がその ID を拾うかを
故障注入で確かめる」に照らして、**検算の対象に入れるべきものが入っていない**。

- **注入 1 (最重要)**: `gate` の `needs` は **M-1 の全体が乗っている 1 行**で、
  `ci.yml` にジョブを足したときに更新を忘れる典型 (`CLAUDE.md.tmpl:42` が
  「`ci.yml` のジョブ構成を変えたら `gate` の `needs` も同じ差分で更新する」と**規約で**書いている =
  規約に書いた時点で「忘れる前提」だと認めている)。
  **設計リポ側で機械強制できる**: `scripts/check-monorepo-ci.sh` を作り、
  ①`ci.yml` の `jobs:` 直下のキー集合 (`gate` を除く) == `gate` の `needs` の集合
  ②同集合 == `gate` ステップ内の `check <name>` の引数集合
  を照合して `make check` に入れる (YAML パーサ不要。`grep` + `sed` で足りる)
- **注入 2**: AC-2.3 の「3 本 × 必須 5 欄」は `plan.md:61` に**数値として書かれている**のに検算が無い。
  `grep -c 'required: true'` の 1 行で検査できる (`check-table-counts.sh` と同じ形式)
- **注入 3**: 「6 機構」は `architecture.md` の 2 箇所 + `templates/README.md:14`
  (「モノレポ機構 M-1〜M-6」) + `CLAUDE.md.tmpl:35` (「M-1〜M-6」) に転記されている。
  **M-x の表の行数を数えて転記先と照合する**か、DR-9 の規約どおり**数値を書かずに
  「§3.11.2 の表」へのリンクにする**

### G-3. 注入したファイルの復元確認

```
$ shasum -a 256 <3 ファイル>   # 注入前
4bb8152608cc5be94032e2bb4c12bd64ea57a39408af0dc05f0c019b31e0d255  templates/app-monorepo/.github/workflows/ci.yml
add6a1f9477c99a12cf4a6c89a878c26fa859b1293fd82c5eaa95ba88e8a54fa  templates/app-monorepo/.github/ISSUE_TEMPLATE/task-backend.yml
d7743501382a71babc03d79014d8fefdc4ed946a751d1fa14170521c80799b2b  docs/design/architecture.md

$ diff sha-before.txt sha-after.txt && echo "sha 一致 (完全復元)"
sha 一致 (完全復元)
```

`git status` 上も注入前と同じ状態 (`ci.yml` は未追跡のままなので sha で確認した。
`architecture.md` / `task-backend.yml` は git 管理下で、注入前の worktree 差分と一致)。
**本レビューはこの 3 ファイル以外を一切変更していない** (レビュー成果物
`aidlc-docs/reviews/productionization/review-monorepo-harness.md` の作成のみ)。

---

## 良かった点

1. **`gate` の判定ロジックが正しい**。`skipped` を成功扱いにしつつ `failure` / `cancelled` を
   確実に落とす形になっており (7 通りの実測で確認)、`operations.md:317` が警告する
   「skipped 許容を書き忘れて逆に常に落ちる」を回避できている。`check()` を関数にして
   サブシェルを避けている点も正しい (パイプ内で `fail=1` を立てると失われる)
2. **アクションの `with:` 入力が `working-directory` の影響を受けないことを理解して書かれている**。
   `ci.yml:75` / `:358` / `e2e.yml:84` に理由コメント付きで、`golangci-lint-action` の
   `working-directory` 入力も明示されている (この 1 点だけでも CI の初回起動失敗が防げる)
3. **`workflow_run` 起動時の既定 ref がデフォルトブランチであることを把握し、`head_sha` を
   明示 checkout している** (`e2e.yml:76`〜`:79`)。ここを外すと「デプロイした commit と違う
   コードを E2E した」が静かに起きる
4. **`git diff` に pathspec を付ける必要性がモノレポ固有の落とし穴として言語化され、
   規約 (`02-issue-granularity.md:248`) と CI 実装の両方に落ちている** (issue テンプレート 2 箇所を除く)
5. **`D-2⑨` の `targets` と `.golangci.yml` の `L3-no-sqlc-outside-repository` の `files` が
   実際に一致している** (9 要素。人手で維持している割にずれていない)
6. **`pre-commit` の統合で機能が落ちていない**。旧 backend / frontend hook の全チェックが残り、
   M-6 の同梱検出が新規に加わっている。パス接頭辞の除去も実測で正しい
7. **`feedback_review_patterns.md` に DR-10 (構造変更が無償の担保を外す) を新規追加**している。
   本レビューの指摘 E-4 (書き込み権限の分離) は**まさに DR-10 の 3 番目の実例**であり、
   パターンの言語化自体は正しい方向 (適用の網羅が足りていないだけ)
8. **`e2e.yml` の「0 件実行で緑にしない」「skip を緑にしない」検査**が JSON を `node` で
   構文解析する形で書かれており (`:153`〜`:179`)、`grep` 依存の脆い実装を避けている

---

## 要確認 (実挙動を確認していない項目。推測を事実として書いていない)

| # | 項目 | なぜ確認が要るか | 確認方法 |
|---|---|---|---|
| 1 | **`golangci-lint-action@v6` が `version: "2"` の設定を読めるか** (C-6) | 読めないなら**雛形投入直後の CI が必ず落ちる**。action v7 以降が golangci-lint v2 対応という認識だが未確認 | 実装リポで 1 回 CI を回す / action の README でメジャー対応表を見る |
| 2 | **同一 SHA に同名 (`gate`) のチェックランが 2 つある場合のブランチ保護の判定** (A-7) | push 実行の緑が PR 実行の赤を上書きするなら M-1 の担保が状況依存になる | `push` と `pull_request` の両方を残したまま、backend を壊した PR を作って「マージ可能になるか」を見る |
| 3 | **CODEOWNERS の 1 行複数オーナーが「双方の承認」になるか** (E-5) | ならないなら `api/` の双方承認は実現していない | `api/` のみを変更した PR を作り、BE 側 1 名の approve でマージ可能になるかを見る |
| 4 | **`npx vitest related --run` が関連テスト 0 件のときに exit 1 になるか** (E-6) | なるなら pre-commit が正当な commit をブロックする (`--no-verify` は禁止されている) | `frontend/` でテストを持たない `.ts` を 1 行変えて commit してみる |
| 5 | **`workflow_run` の `event` 判別が将来の起動経路追加に耐えるか** (D-1) | `deploy-backend.yml` に `schedule` や tag push を足した瞬間に E2E の dev/prod 判別が壊れる | 起動経路を増やすときのレビュー観点として `e2e.yml:62` のコメントに残す |

## 調べていない範囲 (カバレッジの正直さ)

- **`templates/app-monorepo/backend/layering-scopes.yml` / `prompts/agents.yaml` / `.eslintrc.json.tmpl` /
  `backend/.claude/` 配下**は本レビューの対象外 (指示の対象ファイル一覧に無く、
  今回のモノレポ化で内容が変わっていないため)
- **`templates/infra-repo/CLAUDE.md.tmpl` / `templates/README.md` の全文**は、
  M-x への言及の整合のみ確認し、他の記述はレビューしていない
- **`rollback-backend.yml`** はアクション入力とパス表記のみ確認 (承認・入力設計は
  `operations.md` §5.3 のレビュー済み範囲と判断)
- **`docs/design/API/{conversation,ideas,plans}.md` / `review-conversation*.md` /
  `scripts/check-*.sh` / `機能一覧.md`** は指示により対象外
