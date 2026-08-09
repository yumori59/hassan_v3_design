# レビュー (3 巡目): app モノレポ + infra リポの 2 分割 — 2 巡目 2 本の反映の実物照合

- **対象**: 2 巡目 2 本 ([review-monorepo-harness-r2.md](review-monorepo-harness-r2.md) の 重大 3 / 中 8 / 軽微 5 と
  [review-monorepo-design.md](review-monorepo-design.md) の 重大 5 / 中 10 / 軽微 5)、および
  `aidlc-docs/aidlc-state.md:67` / `:68` (2026-08-05 の 2 行) の**自己申告**
- **レビュー日**: 2026-08-05 / **レビュアー**: `design-reviewer` (別セッション。起草は別セッション)
- **最優先観点**: **反映の実物照合**。3 巡連続で「実施済みの自己申告」から重大が出ているため、
  自己申告を一切信用せず**実ファイルを開き、機構は故障注入で殴った**
- **基準**: 本番基準 (`.claude/rules/08-production-gates.md`)。「PoC / 3 リポ構成ではこうだった」を省略の理由にしない
- **本レビューはファイルを一切恒久変更していない** (故障注入は全て復元済み。§5.4 の照合結果を参照)

## レビューした成果物 (リポジトリ相対パス)

機構 (雛形・スクリプト):

- `templates/app-monorepo/scripts/check-regen.sh`
- `templates/app-monorepo/scripts/check-ci-gate.sh` (**新設**)
- `templates/app-monorepo/scripts/hooks/pre-commit`
- `templates/app-monorepo/.github/workflows/ci.yml`
- `templates/app-monorepo/.github/workflows/deploy-backend.yml`
- `templates/app-monorepo/.github/workflows/e2e.yml`
- `templates/app-monorepo/.github/workflows/rollback-backend.yml`
- `templates/app-monorepo/.github/CODEOWNERS`
- `templates/app-monorepo/.github/pull_request_template.md`
- `templates/app-monorepo/.github/ISSUE_TEMPLATE/task-backend.yml`
- `templates/app-monorepo/.github/ISSUE_TEMPLATE/task-frontend.yml`
- `templates/app-monorepo/CLAUDE.md.tmpl`
- `templates/app-monorepo/backend/STRUCTURE.md`
- `templates/app-monorepo/frontend/.eslintrc.json.tmpl`
- `templates/shared/.claude/rules/01-construction-loop.md`
- `templates/shared/.claude/rules/02-issue-granularity.md`
- `templates/shared/.claude/rules/04-human-checkpoints.md`
- `templates/README.md`
- `scripts/check-monorepo-ci.sh`
- `Makefile`
- `CLAUDE.md`
- `.claude/rules/05-harness.md`
- `.claude/rules/feedback_review_patterns.md`

設計文書:

- `docs/design/architecture.md` (D-I / §3.11.1〜§3.11.4 / §5 / §7)
- `docs/design/operations.md` (§4.1 / §5.1.1 / §5.4 / §7.1 / §9)
- `docs/design/infrastructure.md` (§4.2 / §4.5 / §5.3 / §6.1 / §6.2)
- `docs/design/testing.md` (§5.3 / §7.4 / §10 / §13.3)
- `docs/design/frontend.md` (§16.1 / §16.2-1)
- `docs/design/README.md` / `docs/design/API/README.md`
- `aidlc-docs/inception/productionization/questions.md` (Q-2 `[Answer 2]`)
- `aidlc-docs/inception/construction-workflow/questions.md` / `.../requirements.md`
- `aidlc-docs/aidlc-state.md` / `todo.html`

---

## 1. 結論

**Design Freeze 不可。重大 5 件 / 中 12 件 / 軽微 7 件。**

**2 巡目 36 件 + 自己申告 2 行の反映判定: 一致 17 / 部分反映 6 / 不一致 13 / 対象外 2。**

**重大の反映は良い** — 2 巡目の重大 8 件 (R2-1〜R2-3 / D-1〜D-5) のうち **6 件は実物として正しく反映されている**。
とくに `check-regen.sh` の `git status --porcelain --untracked-files=all` 方式への作り直し (6 ケース実測で確認)、
`check-ci-gate.sh` の新設と `meta` ジョブからの実呼び出し (故障注入 3/3 検出)、
D-I 却下案 (b) の根拠の書き直しと §3.11.4 の新設 + `ecspresso verify` の雛形組み込み、
CODEOWNERS の「双方の承認は機構化できない」への確定、`infrastructure.md` §4.5 の新設 (`dev-e2e`) は
いずれも**実物で確認できた**。

**問題は 3 つに集中している**:

1. **修正自身がまた新しい欠陥を作った (4 巡連続)** — `check-regen.sh` は削除を検出するようになった一方、
   **存在しない pathspec に対して `[check-regen] OK` / exit=0 を返すようになった** (前版は exit=128)。
   2 巡目 軽微 R2-L5 が「落ちる方向なので安全側」と評価した挙動が**安全でない方向に反転している**。
   `feedback_review_patterns.md` DR-6 の「**検査が『対象 0 件』を検査して緑になる**」そのもの (重大 1)
2. **「中」がまるごと未着手** — 2 巡目の 中 18 件のうち**実際に反映されたのは 3 件のみ**。
   とりわけ 2 巡目が「非検出」と**実証済み**の故障注入 4 種 (D / E / I / L) は、本レビューで**再実行して 4/4 とも
   依然 exit=0** だった (重大 2)。`aidlc-state.md:67` の「**故障注入は累計 12 種で全件検出**」は、
   2 巡目レビュー本文 (§6.4) が 4 種の非検出を明記していることと食い違う
3. **是正が新しい波及漏れを 3 件生んだ** — ①D-4 (`dev-e2e`) の追加が `infrastructure.md` の
   INF-I「IAM ロール **3 本**」を取り残し、同一文書内で **3 本 vs 8 本**の自己矛盾になった (重大 3)
   ②R2-3 の是正で「回避可」が 3 件になったのに、直後の 2 段落が「**回避可能な 2 件 (H-5 / MR-6)**」のまま (重大 5)
   ③`dev-e2e` 化が `testing.md` §13.3 #2 の「`environment: dev`」を取り残した (中 3)

`make check` は **7 ゲート**すべて緑 (エラー 0) だが、**上記のうち `make check` が見ているものは 1 件も無い**。

| 分類 | 件数 | 一言 |
|---|---|---|
| 重大 | 5 | check-regen の新盲点 / 中 4 件が全て未是正・故障注入 4/4 非検出 / IAM 3 本 vs 8 本 / R2-M1 の 3 箇所未是正 / 「回避可 2 件」ガードの自己破壊 |
| 中 | 12 | 改名漏れ + 検査⑨ が scripts/ を見ない / backtick / §13.3 #2 / 検証ゲート SSOT / AC 欠落 / production ブランチ / Dependabot / 出典の逆転 / DR-10 9 例目 |
| 軽微 | 7 | actionlint の curl / 二重助詞 / 「未了」の残存 / 「他 2 リポ」/ 3 リポ表記 / 旧実装を語るコメント / todo.html |

---

## 2. 2 巡目 36 件 + 自己申告の反映判定 (1 主張 = 1 行)

**判定基準**: 「一致」= 指摘原文が名指しした箇所**すべて**が修正され、修正内容が実物として機能する
(機構は故障注入で確認)。修正案が挙げた箇所の一部だけを直したものは「部分反映」。

### 2.1 review-monorepo-harness-r2.md (雛形の機構)

| 2 巡目 | 判定 | 確認したファイル:行 / 根拠 |
|---|---|---|
| **重大 R2-1** `check-regen.sh` の削除盲点 + インデックス汚染 | **部分反映** | `templates/app-monorepo/scripts/check-regen.sh:58` が `git status --porcelain --untracked-files=all -- "$@"` 方式。**使い捨てリポジトリで 8 ケース実測** (§5.1): 追加 / 変更 / 削除 / 差分なし / gitignore / 対象外パス / インデックス非汚染 の **7/7 が期待どおり**。`:14`〜`:32` のコメントも実装と一致 (虚偽の記述は解消)。**しかし「存在しない pathspec」で `OK` / exit=0 を返すようになった** (前版 exit=128) → **重大 1** |
| 同 (波及) `frontend.md:1193`〜`:1194` の裸の `git diff` | **一致** | `docs/design/frontend.md:1193`〜`:1194` が `scripts/check-regen.sh api/openapi.yaml` / `frontend/src/generated` に差し替え済み |
| 同 (波及) `testing.md:223` の裸の `git diff` | **一致** | `docs/design/testing.md:223` が `scripts/check-regen.sh backend/testdata/golden`。二重貼りも解消 |
| 同 (波及) 検査④ の対象に `docs/` を加える | **一致** | `scripts/check-monorepo-ci.sh:200`〜`:203` (`naked_md`)。除外語 `使わない\|無いこと\|復活\|禁止\|見落とす\|見ない`。**故障注入 FI-4 で検出を確認** (§5.2) |
| **重大 R2-2** 行番号引用 10 件の残存 | **一致** | 2 巡目が指定した再検査 grep 2 本を実行し、`ci.yml` / `e2e.yml` / `pre-commit` を指す `:NN` / `:NN〜NN` は **0 件**。残るヒットは `.eslintrc.json.tmpl` (無変更ファイル。`:30` `:31〜38` を実測照合し**一致**) と参照リポ (`claude_managed_agents/.github/workflows/ci.yml:27`〜`:30` を実測照合し**一致**) のみ |
| **重大 R2-3** CODEOWNERS の断定 | **一致** | `templates/app-monorepo/.github/CODEOWNERS:16`〜`:37` が**専用チーム 1 行** (`:30` `/api/ @<owner>/<api-reviewers>`) + 「双方の承認は CODEOWNERS では表現できない」と断定を反転。`architecture.md:912` (MR-4)・`04-human-checkpoints.md:213` (§2.6 の「回避可」に MR-4 登録)・`:415`〜`:418` (awk が「1 行 1 オーナー」を検査する形に変更)・`architecture.md` §3.11.2 要確認 #3 が「確定した制約」へ移動 — **4 箇所すべて整合**。ただし副作用で **重大 5** が発生 |
| 中 R2-M1 `on` 変更の波及漏れ 3 箇所 | **不一致** | `01-construction-loop.md:67` / `:316` / `testing.md:585` **3 箇所とも旧記述のまま**。実物 `ci.yml:27`〜`:30` は `push: branches: [main]` → **重大 4** |
| 中 R2-M2 検証ゲート SSOT に未登録 | **不一致** | `CLAUDE.md:39`〜`:46` は依然 **5 本を列挙 + 「上記 5 つをまとめて実行」**。`Makefile:6` の help も 5 本。`.claude/rules/05-harness.md` の「見る / 見ない」表に `check-monorepo-ci` / `check-template-sync` の行**なし** (grep ヒット 0) → **中 4** |
| 中 R2-M3 `MR-x` 誤爆 3 件 | **一致** | `docs/design/frontend.md:391` / `:672` / `:782` はいずれも「2026-07-31 のレビュー **重大 1 / 重大 3**」に戻っている (`M-1` / `MR-1` とも不在)。`data-model.md` / `llm-migration.md` / `03-model-escalation.md` への `MR-` 混入は **0 件** |
| 中 R2-M3 改名漏れ 2 件 | **不一致** | `scripts/check-monorepo-ci.sh:95` の `(M-1)` / `:221` の `(M-3 の実体)` が**そのまま**。加えて `:2` `:148` `:155` `:215` にも素の `M-x`。**検査⑨ の走査対象に `scripts/` が無い** (`:327`〜`:329`) ため構造的に検出不能 (実測 exit=0) → **中 1** |
| 中 R2-M4 `meta` フィルタ削除が非検出 | **不一致** | 故障注入 FI-L (フィルタ 4 行削除) **再実行して exit=0**。検査①は依然ジョブ名の集合しか見ない。`meta` ジョブの検査対象も `find scripts` + `actionlint` + `check-regen.sh` 自己テスト + `check-ci-gate.sh` の 4 つで、**`.github/CODEOWNERS` / `ISSUE_TEMPLATE/*` / `pull_request_template.md` / `.claude/**` は依然無検査** → **重大 2 / 中 12** |
| 中 R2-M5 CODEOWNERS 改変が非検出 | **不一致** | 故障注入 FI-E (`/api/` を 1 行 2 オーナーに戻す) **exit=0**。`check-monorepo-ci.sh` に CODEOWNERS の検査は 1 つも無い → **重大 2** |
| 中 R2-M6 deploy paths の逆方向が非検出 | **不一致** | 故障注入 FI-D (`'api/**'` を削除) **exit=0**。検査⑤ (`:240`〜`:250`) は deploy ⊆ CI の一方向のみ → **重大 2** |
| 中 R2-M7 「ジョブは 6 本」が非検査 | **不一致** | 故障注入 FI-I (`operations.md:321` を「5 本」に) **exit=0**。`operations.md:16` / `:253` / `:802` の「6 ジョブ」も無検査 → **重大 2** |
| 中 R2-M8 `testing.md:223` の二重貼り + 裸の `git diff` | **一致** | `:223` は `check-regen.sh` 経由 + 二重貼り解消。`:874` の二重助詞も解消。**ただし `frontend.md:965` に同型が残存** (軽微 2) |
| 軽微 R2-L1 未エスケープ backtick | **不一致** | `scripts/check-monorepo-ci.sh:90` `:92` `:102` `:307` `:309` に**未エスケープ backtick が残存**。**実測で実害を確認**: 故障注入 FI-1 のエラーが `[monorepo-ci] NG: ① の needs が job 集合と一致しません` となり、**識別子 `gate` が消える** → **中 2** |
| 軽微 R2-L3 `deploy-backend.yml:24` のコメント | **不一致** | `:25` は依然「path filter は ci.yml の backend ジョブと**同じ条件**にする」。`operations.md:341` は「**部分集合にする**」、実物は `.github/workflows/deploy-backend.yml` を含む**上位集合** — 三者不整合 → **中 10** |
| 軽微 R2-L4 `actionlint` の curl 分岐 | **不一致** | `ci.yml:509`〜`:513` が `bash <(curl -fsSL …) \|\| { … }` のまま (軽微 1) |
| 軽微 R2-L5 pathspec 不一致時のメッセージ | **不一致 (悪化)** | 「exit=128 で落ちる」が「**exit=0 で OK と表示**」に反転 → **重大 1** |

### 2.2 review-monorepo-design.md (設計文書側)

| 2 巡目 | 判定 | 確認したファイル:行 / 根拠 |
|---|---|---|
| **重大 D-1** 却下案 (b) の誤った根拠 | **一致** | `docs/design/architecture.md:60` (D-I) が①ライフサイクルの非対称性 ②AWS 権限の分離 に書き換わり、「⚠️ 却下理由に『契約が無い』を使わない」+ §3.11.4 への差し戻しを明記。`aidlc-docs/inception/productionization/questions.md:85`〜`:94` に訂正ブロック、`aidlc-docs/aidlc-state.md:65` に訂正注記 — **3 箇所すべて整合**。引用先 `docs/design/infrastructure.md:227`〜`:231` を実測照合し**一致** |
| **重大 D-1** §3.11.4 の新設 + `ecspresso verify` | **一致** | `architecture.md:957`〜`:989`。「**実施済み (2026-08-05)**」と書かれ、実物 `templates/app-monorepo/.github/workflows/deploy-backend.yml:464`〜`:492` に「契約の実行時検証 (ecspresso verify)」ステップ + 「verify 失敗時の切り分け手順」(疑う順序 4 点) が `deploy` (`:494`) の直前に存在。要確認 (4 種のどれを検出するか) も残されている |
| **重大 D-2** `check-ci-gate.sh` の新設 | **一致** | `templates/app-monorepo/scripts/check-ci-gate.sh` (実行権限あり) が実在し、`ci.yml:566`〜`:567` の `meta` ジョブから `bash scripts/check-ci-gate.sh .github/workflows/ci.yml` で**実呼び出し**。**故障注入 3/3 検出** (§5.3)。`architecture.md:1063`〜`:1069` (§7 引き渡し) にも明記 |
| 同 (修正案 3) `operations.md` §9 への引き渡し追記 | **部分反映** | `architecture.md` §7 には入ったが、`operations.md:835`〜`:860` (§9 の app モノレポ 1〜9) には**自己検査スクリプト 2 本の項目が無い** (軽微 7) |
| **重大 D-3** `contract` の起動条件に `meta` | **一致** | `ci.yml:580`〜`:584` が `backend \|\| frontend \|\| api \|\| meta` の 4 条件。`:577`〜`:579` に理由コメント |
| **重大 D-3** `meta` に `check-regen.sh` の自己テスト | **一致** | `ci.yml:521`〜`:558`。**5 ケース** (差分なし / 未追跡の追加 / 変更 / 削除 / インデックス非汚染)。ただし**「存在しない pathspec」のケースが無い** (重大 1 が機械で止まらない理由) |
| **重大 D-4** OIDC の `sub` クレーム設計 | **一致** | `docs/design/infrastructure.md:266`〜`:301` に §4.5 を新設。`sub` を `environment` で分ける表 (8 行) + 要点 3 つ + 要確認 |
| **重大 D-4** `dev-e2e` の分離 | **一致** | `templates/app-monorepo/.github/workflows/e2e.yml:76` `environment: dev-e2e`、`04-human-checkpoints.md:355` / `:371` (6 つの environment) / `:435` (`for e in dev dev-e2e …`)、`operations.md:157`、`testing.md:360` — **波及 5 箇所すべて整合** |
| **重大 D-4** (関連) INF-I を 4 本にする = 中 10 | **不一致** | `infrastructure.md:97` は依然「**IAM ロール 3 本**」。`:183` の IaC 管理範囲表も 3 種、`:370` の構築順序 段 2 も「3 本」、`:386` は「信頼条件を **`main` ブランチに限定**」で §4.5 要点 2 と矛盾 → **重大 3** |
| **重大 D-5** `frontend.md` の MR-3 記述 | **一致** | `frontend.md:1193`〜`:1194` が `check-regen.sh` 経由 |
| **重大 D-5** 検査④ に `docs/` | **一致** | 上記 (故障注入 FI-4 で検出確認) |
| 中 1 `testing.md` §13.3 #2 | **部分反映** | `docs/design/testing.md:872` はトリガーを `workflow_run` に訂正済み。**しかし ①`environment: dev` のまま** (実物は `dev-e2e` = D-4 の波及漏れ) **②「送信側は `deploy-backend.yml` の `release` 末尾」のまま** — 実物 `deploy-backend.yml:533`〜`:540` は「E2E の起動方法 (記録用)」の `echo` だけで**送信ステップは存在しない** → **中 3** |
| 中 2 `testing.md` §5.3 の規約 4 | **一致** | `:223` を確認 |
| 中 3 Q-2 `[Answer 2]` の出典が正反対 | **不一致** | `aidlc-docs/inception/productionization/questions.md:72` は現行の `templates/app-monorepo/backend/STRUCTURE.md` へリンクしたまま「設計で確定していないため、ディレクトリを作っていない」と引用。**現行ファイルに当該文字列は 0 件** (`:208` は「**OpenAPI 定義の出力先 (2026-08-03 に確定)**」) → **中 9** |
| 中 4 MR-1/2/4/5 に対応する AC が無い | **不一致** | `grep -rn "AC-5.5" aidlc-docs/ docs/` = **0 件**。`grep -rn "MR-" aidlc-docs/inception/` は 4 件 (MR-3 / MR-6 のみ) → **中 5** |
| 中 5 job 本数が検算対象外 | **不一致** | 故障注入 FI-I で確認 (重大 2 に統合) |
| 中 6 `production` ブランチが backend を含む | **不一致** | `operations.md:675` 「**`production`** (frontend のみ)」/ `:677` 「backend / infra に `production` ブランチを作らない」が旧記述のまま → **中 6** |
| 中 7 「`main` からの PR のみ」は強制できない | **不一致** | `04-human-checkpoints.md:341` が設定項目のまま。`grep -n "head_ref" templates/ docs/` = **0 件** (H-4 の確認観点にも検査ワークフローにも無い) → **中 7** |
| 中 8 MR-4 の代償欄に Dependabot / `git blame` | **不一致** | `architecture.md:912` の MR-4 代償欄は write 権限のみ。`grep -rn "Dependabot" docs/ templates/ aidlc-docs/inception/` のヒットは **DR-10 の本文とその同期コピーだけ**。`templates/app-monorepo/.github/dependabot.yml` **不在** → **中 8** |
| 中 9 `CLAUDE.md` の検証ゲート一覧 | **不一致** | 中 R2-M2 と同一 → **中 4** |
| 中 10 INF-I の IAM ロール 4 本 | **不一致** | 上記 → **重大 3** |
| 軽微 1 `operations.md` 「他 2 リポの前提」 | **不一致** | `operations.md:815` が「**他 2 リポの前提**」のまま (軽微 4) |
| 軽微 2 AC-5.1 の「3 箇所」 | **一致** | `construction-workflow/requirements.md:112` が「app モノレポ (backend / frontend の 2 サブツリー) と infra リポ」 |
| 軽微 3 `construction-workflow/questions.md:3` | **不一致** | 「実装リポジトリ (**backend / frontend / infra**)」のまま (軽微 5) |
| 軽微 4 「6 ゲート」の実体は 7 | **不一致** | `aidlc-docs/aidlc-state.md:67` / `:68` が「全 6 ゲート緑」、`todo.html:410` が「make check を 6 ゲートに」。実測は **7 ゲート** → **中 4** |
| 軽微 5 `testing.md:223` の二重文言 | **一致** | 解消 |

### 2.3 aidlc-state.md の自己申告 (2026-08-05 の 2 行)

| 自己申告 (`aidlc-docs/aidlc-state.md`) | 判定 | 根拠 |
|---|---|---|
| `:67` 「重大 8 → 解消」 | **部分反映 (6/8)** | R2-1 は新盲点あり (重大 1)。他 7 件は反映済み。「解消」と断定できるのは 7 件 |
| `:67` 「`check-regen.sh` を `git status --porcelain --untracked-files=all` 方式へ作り直した (6 ケースで検証)」 | **一致** | 8 ケース再実測で確認 (§5.1) |
| `:67` 「行番号引用を全件ステップ名参照へ」 | **一致** | 再検査 grep 2 本で 0 件 |
| `:67` 「CODEOWNERS を専用チーム 1 行に変え、§2.6 の回避可に MR-4 を登録」 | **一致** | ただし「回避可能な 2 件」の文言が取り残された (重大 5) |
| `:67` 「`check-ci-gate.sh` を新設し `meta` から呼ぶ (故障注入 3/3 検出)」 | **一致** | 本レビューで 3/3 再現 |
| `:67` 「`contract` の条件に `meta` を追加 + 自己テスト (5 ケース)」 | **一致** | 実物で確認 |
| `:67` 「`infrastructure.md` §4.5 を新設。environment は 5 → 6 に」 | **一致** | 6 environment を 5 箇所で確認 |
| `:67` 「検査④ の対象に `docs/` を追加」 | **一致** | 故障注入で確認 |
| `:67` 「誤爆 12 件を全件巻き戻し」 | **一致** | `frontend.md:391` / `:672` / `:782` を実測。他名前空間への `MR-` 混入 0 件 |
| `:67` 「**検査⑨ (改名漏れの検出) を追加**」 | **部分反映** | 検査⑨ は実在し故障注入 FI-7 で検出したが、**`scripts/` を走査しないため現存の改名漏れ 6 件を 1 件も検出しない** (中 1) |
| `:67` 「`make check` 全 **6 ゲート**緑」 | **不一致** | 実体は **7 ゲート** |
| `:67` 「`monorepo-ci` は照合 **31 件**」 | **一致** | 実測 31 件 |
| `:67` 「**故障注入は累計 12 種で全件検出**」 | **不一致** | 2 巡目 §6.4 は自作 14 種のうち **4 種を非検出**と記録している。本レビューで 4 種とも再現し**依然 exit=0**。「全件検出」は成立しない (重大 2) |
| `:68` 「`ecspresso verify` を `release` ジョブの `deploy` 直前に必須実行」 | **一致** | `deploy-backend.yml:472`〜`:492` |
| `:68` 「§3.11.4 の『未実施』を解消」 | **一致** | `architecture.md:981` が「**実施済み (2026-08-05)**」 |
| `:68` 「`README.md` の件数を落とし再現コマンドにした」 | **一致** | `docs/design/README.md:3`〜`:7` が「1 セッションで読み切れない規模」+ `ls … \| wc -l`。`:110` は「一覧と本数は `API/README.md` §3 の総覧が正」 |
| `:68` 「`API/README.md` の『対象』行を 9 ドメインに是正」 | **一致** | `docs/design/API/README.md:12` / `:18` |
| `:68` 「DR-9 に判断の目安 (a)(b)(c) を追記」 | **一致** | `.claude/rules/feedback_review_patterns.md` の DR-9 行末 |
| `:68` 「`make check` 全 **6 ゲート**緑」 | **不一致** | 実体は 7 |

---

## 2.9 反映状況 (起草側セッションが 2026-08-05 に追記)

**重大 5 / 中 12 / 軽微 7 のすべてを反映した**。反映の裏取りは 4 巡目レビューの対象。

| 指摘 | 対応 | 実物 |
|---|---|---|
| 重大 1 | `git ls-files` で追跡・未追跡の両方に 1 件も一致しなければ `exit 1`。**使い捨てリポジトリ 9 ケースで実測 (9/9 期待どおり)** | `templates/app-monorepo/scripts/check-regen.sh` の「■ pathspec 不一致」節と `tracked` / `untracked` 判定 / `ci.yml` の自己テストに pathspec 不一致 2 ケース |
| 重大 2 | **検査⑩〜⑬ を新設**。FI-L / FI-E / FI-D / FI-I を含む**故障注入 7 種で 7/7 検出**を確認し、作業ツリーを SHA-256 で復元確認 | `scripts/check-monorepo-ci.sh` の ⑩〜⑬ (照合 31 → 59 件) |
| 重大 3 | INF-I / IaC 管理範囲表 / §6.1 段 2 / prod 追記 / `modules/iam-oidc` の**本数を落として §4.5 へのリンクに寄せた** (DR-9 (c))。`ref:` 条件の指示を environment 固定 + Deployment branches の二重化へ。段 2 の完了条件に「§4.5 の各ロールで `aws iam get-role` が成功する」を追加 | `docs/design/infrastructure.md` |
| 重大 4 | 3 箇所とも是正。**「S-4〜S-8 は機械の検証が pre-commit だけになる」**を明記 | `templates/shared/.claude/rules/01-construction-loop.md` の補足と §7 の表 / `docs/design/testing.md` |
| 重大 5 | 「回避可能な 3 件 (H-5 / MR-6 / MR-4)」へ更新し、**ガード自身を検査⑭ で機械強制**した | `templates/shared/.claude/rules/04-human-checkpoints.md` §2.6 / `scripts/check-monorepo-ci.sh` ⑭ |
| 中 1 | 改名漏れ 6 件を `MR-x` へ。**検査⑨ の走査対象に `scripts/` を追加 (自己適用)**。「3 つの名前空間」を 4 に | `scripts/check-monorepo-ci.sh` |
| 中 2 | `fail "…"` 内の未エスケープ backtick 5 箇所をエスケープ。故障注入で `` `gate` `` が出力に残ることを確認 | 同上 |
| 中 3 | `environment: dev-e2e` へ訂正 + **「送信側は存在しない」**を明記 | `docs/design/testing.md` §13.3 |
| 中 4 | `CLAUDE.md` の検証ゲート節に 2 本を追記し**「上記 5 つ」の本数を落とした**。`Makefile` の help も。`05-harness.md` の「見る / 見ない」表に 2 行追加 | `CLAUDE.md` / `Makefile` / `.claude/rules/05-harness.md` |
| 中 5 | **AC-5.5 を新設**し `plan.md` の AC 表にも登録 (traceability 24 → 25) | `aidlc-docs/inception/construction-workflow/{requirements,plan}.md` |
| 中 6 | `production` の `backend/` はどこにもデプロイされない旨と、BE の本番状態の確認手段を明記 | `docs/design/operations.md` §7.1 |
| 中 7 | **`guard-production-pr.yml` を新設** (`head_ref != 'main'` を落とす) し、04 の記述を「設定」から「検査 + H-4 の確認観点」へ移した | `templates/app-monorepo/.github/workflows/guard-production-pr.yml` / `04-human-checkpoints.md` §4.1・H-4 の観点⑥ |
| 中 8 | MR-4 の代償欄に **Dependabot の単位 / `git blame` の分離**を追記し、**`dependabot.yml` を新設** | `docs/design/architecture.md` §3.11.2 / `templates/app-monorepo/.github/dependabot.yml` / `CLAUDE.md.tmpl` |
| 中 9 | **旧版 + コミット `0448a12` 時点**と明記し、現行ファイルが正反対に書き換わっていることも書いた | `aidlc-docs/inception/productionization/questions.md` |
| 中 10 | コメントを「`ci.yml` の条件 ⊆ 本 paths」へ。両方向を検査⑤ / ⑪ が見ることも明記 | `deploy-backend.yml` |
| 中 11 | **DR-10 の 9 例目**として SSOT と同期コピーに追記。MR-1 の代償欄と 04 のチェックリストにも注記 | `.claude/rules/feedback_review_patterns.md` (+ `templates/shared/` の同期コピー) / `architecture.md` / `04-human-checkpoints.md` §4.1 |
| 中 12 | `meta` ジョブに **`.claude/settings.json` の JSON 妥当性**と `.github` の YAML パース (+ `CODEOWNERS` の存在) を追加 | `ci.yml` の `meta` |
| 軽微 1〜7 | 全件反映 (`actionlint` の取得を `-o` + `&&` へ / 二重助詞 / `testing.md` §10 登録済みへ訂正 / 「他 2 リポ」→「app モノレポ」/ 冒頭の 3 リポ前提 / 検査④ コメントの旧実装 / §9 の引き渡し項目)。**`todo.html` の 2 件は未修正** — title は localStorage の合流キーなので変更禁止 (ルート `CLAUDE.md`) | 各ファイル |

**反映の過程で新たに 1 件自力検出した (本レビューの指摘外)**:
**`make check` の `check-template-sync` は `.PHONY` と `check` の依存に名前だけがあり、レシピが無かった** —
`scripts/check-template-sync.sh` は**一度も実行されていなかった** (`make` が "Nothing to be done" で成功扱い)。
本レビュー §5.5 が「7 ゲートすべて緑」と記録したうちの 1 本が**何も検査していなかった**ことになる
(DR-6 の Makefile 版)。レシピを追加し、コピー側を 1 行変える故障注入で検出を確認した。

---

## 3. 重大 (Must Fix)

### 重大 1. `check-regen.sh` の作り直しが「**存在しない pathspec を緑で返す**」新しい盲点を作った (4 巡連続で「修正自身が新たな欠陥」)

**箇所**: `templates/app-monorepo/scripts/check-regen.sh:58`〜`:63`

```bash
status=$(git status --porcelain --untracked-files=all -- "$@")

if [ -z "$status" ]; then
  echo "[check-regen] OK: $*"
  exit 0
fi
```

**実測** (使い捨て git リポジトリ。詳細は §5.1):

| pathspec | 前版 (`git add -N` + `git diff`) | 現版 |
|---|---|---|
| `api2/openapi.yaml` (存在しない) | exit=**128** / `fatal: pathspec … did not match any files` | **exit=0** / `[check-regen] OK: api2/openapi.yaml` |
| `nonexistent/dir` | exit=128 | **exit=0 / OK** |

2 巡目 軽微 R2-L5 は前版のこの挙動を「**落ちる方向なので安全側**」と評価し、
「メッセージが読めるようにする」ことだけを求めた。**現版は安全側でなくなっている**。

**なぜ本番で問題になるか**:

1. **これは `feedback_review_patterns.md` DR-6 が名指しする「検査が『対象 0 件』を検査して緑になる」形そのもの**。
   `git status -- <存在しないパス>` は空を返すため、**検査は「差分ゼロ = 最新」と解釈する**
2. **pathspec は 12 箇所で手書きされている** — `ci.yml:146` (`backend`) / `:157` (`backend/testdata/golden`) /
   `:610` (`api/openapi.yaml`) / `:630` (`frontend/src/generated`)、`task-backend.yml:61`〜`:63`、
   `task-frontend.yml:59`〜`:60`、`pull_request_template.md:36` `:37` `:44`。
   **1 文字のタイポ、あるいはディレクトリ改名 (`frontend/src/generated` → `frontend/src/api`) で
   MR-3 が恒久的に空振りする**。しかも出力は `OK` なので、**壊れたことがログにも残らない**
3. **雛形の初期状態がまさにこの条件に当たる** — `templates/app-monorepo/api/` は `.gitkeep` のみ、
   `backend/testdata/golden/toolresult/` も `.gitkeep` のみ。`make -C backend docs` が
   **何も出力せずに exit 0 した場合**、`check-regen.sh api/openapi.yaml` は緑を返す
   (`check-regen.sh:6`〜`:12` が「初回生成が素通りする」ことこそを問題として書いているのに、
   **生成物が 1 つも作られなかったケースは今も素通りする**)
4. **`meta` ジョブの自己テストが 5 ケースしか見ていない** (`ci.yml:544`〜`:548`: 差分なし / 追加 / 変更 /
   削除 / 副作用)。**存在しない pathspec のケースが無い**ため、この退行は CI でも止まらない

**修正案**:

```bash
# pathspec が HEAD にも worktree にも 1 件も一致しないなら、検査対象が消えている = 落とす
tracked=$(git ls-files -- "$@")
present=$(git ls-files --others --exclude-standard -- "$@")
if [ -z "$tracked" ] && [ -z "$present" ]; then
  echo "::error::pathspec に一致するファイルがありません: $*" >&2
  echo "  (生成コマンドが何も出力していないか、パスの綴り / 移動が原因です)" >&2
  exit 1
fi
```

あわせて **`ci.yml` の自己テストに 6 ケース目 (`expect 1 "存在しない pathspec"`) を足す** —
2 巡目が「足した検査自体を故障注入で殴る」と定めた運用 (`05-harness.md`) の適用対象そのものである。

---

### 重大 2. 2 巡目が「非検出」と実証した故障注入 4 種が **1 件も是正されておらず、再実行して 4/4 とも依然 exit=0**

**実測** (§5.2。いずれも `bash scripts/check-monorepo-ci.sh` を実行):

| 注入 | 内容 | 2 巡目 | 本レビュー |
|---|---|---|---|
| FI-L | `ci.yml:57`〜`:60` の `meta` フィルタ 4 行を削除 | 非検出 | **exit=0 ❌ 非検出** |
| FI-E | `CODEOWNERS:30` の `/api/` を 1 行 2 オーナーに戻す | 非検出 | **exit=0 ❌ 非検出** |
| FI-D | `deploy-backend.yml:30` の `'api/**'` を削除 | 非検出 | **exit=0 ❌ 非検出** |
| FI-I | `operations.md:321` の「ジョブは 6 本」→「5 本」 | 非検出 | **exit=0 ❌ 非検出** |

**なぜ本番で問題になるか** — 4 件はいずれも「**今回の増分で入れた担保そのものを 1 PR で巻き戻せる**」形である:

1. **FI-L が最も重い**。`meta` フィルタの 4 行を消すと `meta` ジョブの `if: needs.changes.outputs.meta == 'true'`
   (`ci.yml:489`) が恒久的に偽になり、`meta` は常に skip・`gate` は緑になる。
   `meta` ジョブは今や **①`scripts/` の `bash -n` ②`actionlint` ③`check-regen.sh` の自己テスト
   ④`check-ci-gate.sh` (= MR-1 の唯一の実装リポ側担保)** の 4 つを抱えている。
   **1 巡目 中 1・2 巡目 D-2・D-3 の対処が、4 行の削除でまとめて無効化され、しかも `make check` は緑**
2. **FI-D**: `api/**` が deploy の `paths` から落ちると、契約だけが変わった commit が dev に反映されず、
   `e2e.yml` の `workflow_run` も発火しない (E2E が最大 24 時間空く)
3. **FI-I**: DR-9 が「新しく『N 件』を書くときは同時に検算の対象に加えるか、書かずに定義元へのリンクにする」と
   定めているのに、`operations.md:321` は「ジョブ名はここで数えず実物を見る — `make check-monorepo-ci` の①が…
   機械照合する」と書きながら**本数だけを書いている**。①はジョブ名の集合しか見ない
4. `aidlc-docs/aidlc-state.md:67` の「**故障注入は累計 12 種で全件検出**」は、
   2 巡目レビュー §6.4 の記録 (自作 14 種のうち 4 種非検出) と食い違う。**自己申告が実態より良く書かれている**

**修正案** (2 巡目の修正案をそのまま。**足したら必ず故障注入で殴ること**):

- 検査①に「`changes` の `outputs:` キー集合 == `filters:` のキー集合 == 各ジョブの `if:` が参照する
  `needs.changes.outputs.<key>` の集合」を追加
- 検査⑤に逆方向 (`ci.yml` の `backend` ジョブを起動するパターンが `deploy-backend.yml` の `paths` に含まれる)
- 検査③に「`ci.yml` の実測 job 数 ↔ `operations.md` の自称値」「`deploy-backend.yml` の実測 job 数 ↔ 自称値 3 箇所」
- 検査⑩として「`CODEOWNERS` の `/api/` が 1 行かつオーナー 1 件」(`04-human-checkpoints.md:415`〜`:418` の
  awk と同じ判定を `make check` 側にも置く)

---

### 重大 3. `infrastructure.md` 内で **IAM ロールの本数と信頼条件が自己矛盾**している (D-4 の波及漏れ + 中 10 の未是正)

**箇所**:

| 行 | 記述 | §4.5 (新設) との関係 |
|---|---|---|
| `docs/design/infrastructure.md:97` (INF-I) | 「GitHub OIDC + 用途別 **IAM ロール 3 本** (`plan` / `deploy` / `migration`)」 | §4.5 の表は **app 側 7 本 + infra 1 本 = 8 行** |
| `:183` (IaC 管理範囲表) | 「IAM ロール (`plan` / `deploy` / `migration`)」「**リポジトリとブランチで信頼条件を絞る**」 | §4.5 は「モノレポでは `repo:` で分離できない」「`ref:` 条件だけに頼らない」 |
| `:370` (§6.1 構築順序 段 2) | 「**OIDC プロバイダ + IAM ロール 3 本** (INF-I) を apply」 | 同上 |
| `:386` (§6.2 prod 構築) | 「段 2 の IAM ロールは prod 用を追加で作成し、**信頼条件を `main` ブランチに限定**する」 | §4.5 要点 2 が**明示的に禁じている形** |

**なぜ本番で問題になるか**:

1. **構築手順が壊れる**。`:370` は「段 2 = IAM ロール 3 本を apply」で完了と判定させる。
   その状態で `dev-e2e` / `prod-agent` / `prod-db` のロールは存在しないので、
   `e2e.yml:101` (`vars.E2E_AWS_ROLE_ARN`) / `deploy-backend.yml` の `apply_agent` / `apply_migration` は
   **OIDC の AssumeRole で落ちる**。しかも段 2 の完了条件は「`plan` ジョブが PR にコメントできる」だけなので、
   **不足に気付くのは各機能を初めて動かすとき**になる
2. **`:386` に従うと §4.5 が防ごうとした穴が開く**。§4.5 要点 2 は
   「`ref:refs/heads/main` は…**`main` に入った任意のワークフローは通る**。ジョブ単位の分離には `environment` を使う」と
   書いている。`:386` はまさに ref ベースの信頼条件を prod ロールに指示している
3. 設計レビュー 中 10 は「3 本 → **4 本**」を要求していたが、**未是正のまま §4.5 が 8 行の表を新設した**ため
   **乖離が拡大した** (3 vs 4 → 3 vs 8)。DR-9 の「件数の転記が複数文書・複数節に散る」の典型

**修正案**:

- **INF-I から本数を落とし、§4.5 の表へのリンクにする** (DR-9 の判断の目安 (c)「定義元が別文書にあるならリンクだけ」)。
  §4.5 が信頼条件と用途の SSOT であることを INF-I に 1 行書く
- `:183` の「リポジトリとブランチで信頼条件を絞る」を「**environment で絞る (§4.5)**」に、
  ロール列挙を §4.5 へのリンクに差し替える
- `:370` の「3 本」を「§4.5 の表のロール一式」に、`:386` の「`main` ブランチに限定」を
  「**prod 系 environment (`prod` / `prod-db` / `prod-agent`) の `sub` に固定し、
  GitHub 側の Deployment branches で `main` に限定する二重化** (§4.5 要点 3)」に差し替える

---

### 重大 4. 2 巡目 中 R2-M1 (`ci.yml` の `on` 変更の波及漏れ) が **3 箇所とも未是正**

| 箇所 | 現在の記述 | 実物 (`templates/app-monorepo/.github/workflows/ci.yml:27`〜`:30`) |
|---|---|---|
| `templates/shared/.claude/rules/01-construction-loop.md:67` | 「退避 push でも **CI は起動する**ため、失敗した CI を放置しない」 | `push: branches: [main]` — **退避 push では起動しない** |
| 同 `:316` | 「**CI (push)** \| S-9 の push (**退避 push でも起動**) \| 下表の全ジョブ \| PR のマージをブロック」 | 同上 |
| `docs/design/testing.md:585` | 「**`ci.yml` は `push` / `pull_request` の両方で全ブランチに走る**」 | `push` は `main` のみ |

**なぜ本番で問題になるか**: `01-construction-loop.md` は**実装リポの AI 実装者が S-1〜S-10 を回すための手順書**であり、
`:66`〜`:67` は「中断時の退避 push は S-4 以降いつでも可 (feature ブランチは壊れてよい場所)」+
「退避 push でも CI は起動するため、失敗した CI を放置しない」という**行動規範**を書いている。
実際には起動しないので、**S-4〜S-8 の間 (= 中断・再開の §6 が想定する期間) は検証がゼロの空白**になる。
逆に S-9 で PR を作った後は `pull_request` の `synchronize` で走るため、
**「PR 作成前は走らない / 作成後は走る」を明示しないと、この空白が誰にも見えない**。
`ci.yml:23`〜`:26` は是正の理由をコメントで丁寧に書いているのに、**規約側が旧前提のまま**である (DR-8)。

**修正案** (2 巡目の修正案どおり):

- `01-construction-loop.md:67` → 「退避 push では CI は起動しない (`ci.yml` の `push` は `main` のみ。MR-1 の
  2026-08-04 の是正)。**PR を作った時点から `pull_request` で走り、以降の push ごとに再走する**」
- 同 `:316` → 「**CI (pull_request)** \| S-9 の PR 作成後 (以降の push ごとに再走)」の 1 行に統合
- `testing.md:585` → 「`ci.yml` は `pull_request` で全ブランチの PR に走る (`push` は `main` のみ)」

---

### 重大 5. R2-3 の是正が **「回避可能な承認点は 2 件」という自己ガードを黙って壊した**

**箇所**: `templates/shared/.claude/rules/04-human-checkpoints.md:213` (追加) と `:216` / `:218` (旧記述)

```
| **MR-4 `api/` の双方レビュー** | … | **回避可** (…2026-08-05 に確定 = design-reviewer 2 巡目の重大 R2-3) | … |   ← :213 に追加された

**H-5 と MR-6 以外は GitHub 側の機構で回避不可能な形にする**。…                                          ← :216 (旧)

**回避可能な 2 件 (H-5 / MR-6) をこれ以上増やさない**。…                                                  ← :218 (旧)
```

**なぜ本番で問題になるか**:

1. **この 2 文は「回避可を増やさない」ための唯一のガード**であり、
   **それ自身が「今まさに 1 件増えたこと」を隠している**。次に承認点を足す人 (人間でも AI でも) は
   「回避可は H-5 と MR-6 の 2 件」を基準に判断するため、**3 件目が既に存在することを知らずに 4 件目を足す**
2. `:216` の「**H-5 と MR-6 以外は**回避不可能な形にする」は、表の `:213` と**直接矛盾する断定**である。
   `04-human-checkpoints.md` は実装リポへ配る規約ファイルなので、この矛盾はそのまま実装リポへ運ばれる
3. **DR-8 (自己申告の範囲だけ直す) + DR-9 (数え上げの転記) の合わせ技**。
   2 巡目 R2-3 の修正は「§2.6 の表に MR-4 を登録する」ところまでは正確に行われたが、
   **同じ節の直下 2 段落を読み直していない**。DR-8 の検出法 (変更した主張のキーワードを grep) を
   「回避可」「2 件」で回していれば 1 回の grep で出る

**修正案**:

- `:216` → 「**H-5 / MR-6 / MR-4 以外は** GitHub 側の機構で回避不可能な形にする」
- `:218` → 「**回避可能な 3 件 (H-5 / MR-6 / MR-4) をこれ以上増やさない**」。
  MR-4 の追加理由 (CODEOWNERS では双方の承認を表現できない) を 1 行添える
- **本数を書く形を続けるなら `check-monorepo-ci` の検査対象に入れる** —
  「§2.6 の表の『回避可』行数 ↔ 直後の段落の自称値」は 1 行の `grep -c` で照合できる (DR-9 の判断の目安 (a))

---

## 4. 中 (Should Fix)

### 中 1. `check-monorepo-ci.sh` の改名漏れが未是正で、**検査⑨ が `scripts/` を走査しないため構造的に検出できない**

- **2 巡目が名指しした 2 件がそのまま**: `scripts/check-monorepo-ci.sh:95` `→ ジョブを増減したら gate の needs も同じ差分で更新する (M-1)。` /
  `:221` `fail "④…が無い / 実行権限がありません (M-3 の実体)"`
- **さらに 4 件**: `:2` (`app モノレポの CI 機構 (M-1〜M-6)`) / `:148` (`連番であること (M-1..M-N …)`) /
  `:155` (`「N 機構」「M-1〜M-N」の転記を全文照合`) / `:215` (`M-3 が「エンドポイント追加」で空振りします`)
- **検査⑨ (`:327`〜`:329`) の走査対象は `docs/ templates/ .claude/ CLAUDE.md aidlc-docs/inception/` で
  `scripts/` を含まない** → 実測 `bash scripts/check-monorepo-ci.sh` = **exit=0** (§5.2 FI-8)。
  検査⑨ は「モノレポ機構の改名漏れを検出する」ために新設されたのに、**自分自身の改名漏れを見られない**
- 加えて `:22` のコメントが「`M-x` は既に **3 つ**の名前空間に使われていた」、`:319` が「**4 つ**の別の名前空間」で
  **同一ファイル内で自己矛盾**している (2026-08-05 に 4 と確定したのに 1 箇所が旧値)

**修正案**: 改名漏れ 6 件を `MR-x` に直す。検査⑨ の走査対象に `scripts/` を加える (自己適用)。
`:22` を「4 つ」に直す (件数を書くなら `:319` と 1 箇所に寄せる)。

### 中 2. 未エスケープ backtick 5 箇所 (R2-L1 未是正)。**実測で診断メッセージから識別子が消えることを確認**

`scripts/check-monorepo-ci.sh:90` `:92` `:102` `:307` `:309` の `fail "…\`gate\`…"` が二重引用符内で
未エスケープのため、**bash がコマンド置換として評価する**。

本レビューの故障注入 FI-1 (`ci.yml` に `newjob` を追加) の実出力:

```
[monorepo-ci] NG: ① の needs が job 集合と一致しません
```

**本来 `①\`gate\` の needs が…` であるべきところ、`gate` が消えている**
(`gate: command not found` が stderr に出て空文字に置換された)。
`gate` / `ci.yml` / `e2e.yml` / `deploy-backend.yml` という**どれを直せばよいかを示す唯一の語**が落ちる。
新設した機構の診断が読めなくなるため、優先度は低くない。

**修正案**: `\`` にエスケープする (`:145` `:213` `:221` 等は既に正しくエスケープされているので形は揃っている)。

### 中 3. `testing.md` §13.3 #2 が **D-4 の変更を取り込んでおらず、存在しない送信側を指している**

**箇所**: `docs/design/testing.md:872`

> | 2 | [e2e.yml] | **2026-07-30 に作成済み / 2026-08-03 にトリガーを `workflow_run` へ変更** — …
>   **`environment: dev`**、… 送信側は [deploy-backend.yml] の **`release` 末尾** |

**実物**:

- `templates/app-monorepo/.github/workflows/e2e.yml:76` は **`environment: dev-e2e`** (2026-08-05 の D-4 で変更)。
  `:70`〜`:75` に「`environment: dev` を共有すると OIDC の `sub` が同一になる」という理由コメントまである
- `deploy-backend.yml:533`〜`:540` は「E2E の起動方法 (**記録用**。dev のみ)」の `echo` のみ。
  **送信ステップは存在しない** (設計レビュー 中 1 が指摘した点で、トリガーだけ直して送信側の記述が残った)

**なぜ問題か**: §13.3 は**是正要求の台帳**であり、実装リポが「何が済んでいて何が残っているか」を読む表である。
`environment: dev` を根拠に e2e ロールを `dev` に紐付ければ、**D-4 で塞いだ穴 (E2E が dev の deploy ロールを
引き受けられる) がそのまま復活する**。DR-8 の「受信側」型 (`auth.md` §10.3 が実例) — §13.3 は状態列を持つので、
**D-4 の是正時にこの表へ 1 行起票すべきだった**。

**修正案**: `:872` を「`environment: dev-e2e` (2026-08-05 に `dev` から変更 = D-4)」「**送信側は存在しない** —
`e2e.yml` の `on.workflow_run` が `deploy-backend.yml` の完了を直接受ける」に差し替える。

### 中 4. 検証ゲートの SSOT が **2 レビューから同時に指摘されながら未是正** (R2-M2 / 設計 中 9 / 設計 軽微 4)

- `CLAUDE.md:39`〜`:46`: **5 本を列挙 + `make check # 上記 5 つをまとめて実行`**。実体は **7 本**
  (`Makefile:17` の `check` の依存)
- `Makefile:6` の help 要約も 5 本 (`doc-lint + traceability + workflow-shell + table-counts + endpoint-mapping`)
- `.claude/rules/05-harness.md`: `check-monorepo-ci` / `check-template-sync` の grep ヒット **0 件** —
  「見る / 見ない」表に行が無い (`check-table-counts` / `check-endpoint-mapping` は持っている)
- `aidlc-docs/aidlc-state.md:67` / `:68` が「全 **6 ゲート**緑」、`todo.html:410` が「`make check` を **6 ゲート**に」

`05-harness.md:5` が「**検証コマンドの実体はルート `CLAUDE.md` の『検証ゲート』節が SSOT**」と宣言しているため、
**SSOT が 2 本落としたまま 2 巡分放置されている**。個別に走らせる運用 (pre-commit の差分限定・CI の分割) で落ちる。

**修正案**: `CLAUDE.md` の検証ゲート節に 2 本を追記し、「上記 5 つ」を**本数を書かない表現**に変える (DR-9)。
`Makefile:6` も同様。`05-harness.md` の表に `check-monorepo-ci` の行を足す
(見る = `gate` の needs / 必須欄 / MR-x 件数 / 裸の `git diff` の不在 / 改名漏れ、
見ない = **CI が実際に落とすかどうか・`meta` フィルタの生存**)。
`aidlc-state.md` / `todo.html` の「6 ゲート」は本数を落として `make check` の出力を貼る形にする。

### 中 5. MR-1 / MR-2 / MR-4 / MR-5 に対応する **AC が 1 本も無い** (設計 中 4 未是正)

- `grep -rn "AC-5.5" aidlc-docs/ docs/` = **0 件**
- `grep -rn "MR-" aidlc-docs/inception/` = 4 件 (`productionization/questions.md:106` の決定文 /
  `construction-workflow/questions.md:60` / `requirements.md:55` = MR-3 / `:85` = MR-6)

`make check-traceability` は **AC → 設計書**の方向しか見ないので緑のまま。DR-6 の逆方向
(「設計判断に対応する AC が無い場合も要件漏れ」)。実害は、**MR-1 (必須チェックが `gate` 1 本)・
MR-4 (CODEOWNERS)・MR-5 (タグ名前空間) が受入基準として承認されていない = 落としても誰も落としたと言えない**こと。
とくに MR-1 は「指定を誤ると PR が永久に pending」という運用事故の唯一の予防線である。

**修正案**: `construction-workflow/requirements.md` §3.5 に
**AC-5.5「モノレポ機構 MR-1〜MR-6 が雛形と立ち上げチェックリストに存在し、機械検査可能なものは検査に載っている」**を
1 本起こす (AC-2.2 に相乗りさせない)。

### 中 6. モノレポの `production` ブランチが **`backend/` を含む**帰結が未記述 (設計 中 6 未是正)

`docs/design/operations.md:675` 「| **`production`** (**frontend のみ**) | Vercel の Production Branch | …」 /
`:677` 「**backend / infra に `production` ブランチを作らない**」は 3 リポ時代の言い方で、
2 リポ構成では `production` は **app モノレポのブランチ**であり必然的に `backend/` を含む。

未定義のまま残るもの: ①`production` の `backend/` はどこにもデプロイされないのに、head が「本番のコード」に見える
②`operations.md` §5.4 ③ (旧 IF の削除) の条件判定が非対称になる (FE 側はブランチで確認できるが、
BE 側の「prod に何が載っているか」を知る手段が設計に無い = `testing.md` §13.2 の T-Q10 が未調査のまま)。

**修正案**: §7.1 に「**`production` ブランチの `backend/` サブツリーはどこにもデプロイされない。
BE の本番は `main` の手動 dispatch が唯一の経路であり、`production` の head は BE の本番状態を表さない**」を明記し、
`production` から作業ブランチを切らないことを規約化する。T-Q10 を prod にも拡張する。

### 中 7. 「`production` は `main` からの PR のみ」が **機構化されていない** (設計 中 7 未是正)

`templates/shared/.claude/rules/04-human-checkpoints.md:341` は「`production` ブランチにも同等の保護を設定する —
直接 push 禁止 (**`main` からの PR のみ**)」を**立ち上げチェックリストの設定項目**として書いている。
GitHub のブランチ保護 / ruleset には **PR の head ブランチを制限する設定が無い** (要確認: 2026-08 時点の当方の理解)。
`grep -n "head_ref" templates/ docs/` = **0 件**で、H-4 の確認観点にも検査ワークフローにも代替が無い。

結果、任意の `feature/*` から `production` へ PR を出せば承認 1 名で **`main` を経ずに FE 本番へ出る**。
`operations.md` §7.3 の「dev の未リリース変更を prod に出さない 4 段」のうち機械の 3 段は **BE のみに効く**。

**修正案**: ①H-4 (FE) の確認観点に「この PR の head が `main` であること」を入れる (人間の確認に落とす)
②または `production` への PR で `github.head_ref == 'main'` を検査する軽量ワークフローを 1 本置き必須チェックにする。
どちらを採るか決め、04 の文言を「設定」から「確認観点 / 検査」へ移す。

### 中 8. MR-4 の代償欄が DR-10 自身の指示を満たしておらず、**`dependabot.yml` も無い** (設計 中 8 未是正)

DR-10 は「**『CODEOWNERS で置き換えた』と書くときは、置き換えられていないもの
(write 権限・**Dependabot の単位**・**`git blame` の分離**) を同じ行に列挙する**」と定めている
(`.claude/rules/feedback_review_patterns.md:28`)。

`docs/design/architecture.md:912` の MR-4 代償欄は **write 権限だけ**。
`grep -rn "Dependabot\|dependabot" docs/ templates/ aidlc-docs/inception/ .claude/` のヒットは
**DR-10 の本文と `templates/shared/` の同期コピーのみ** — 設計文書のどこにも依存更新の話が無く、
`templates/app-monorepo/.github/dependabot.yml` は**存在しない**。
モノレポでは version updates が `directory:` ごとの宣言を要するため、`/backend` (gomod) と `/frontend` (npm) を
明示しないと**更新 PR が出なくなる** (alerts は残るが更新は止まる)。

**修正案**: MR-4 の代償欄に 2 項目 (Dependabot の単位 / `git blame` の分離) を追記し、
`templates/app-monorepo/.github/dependabot.yml` を 2 ecosystem で置く。
`git log -- backend/` を使う旨を `templates/app-monorepo/CLAUDE.md.tmpl` に 1 行。

### 中 9. Q-2 `[Answer 2]` の出典が **現行ファイルと正反対のまま** (設計 中 3 未是正)

`aidlc-docs/inception/productionization/questions.md:72`:

> (`templates/app-monorepo/backend/STRUCTURE.md` へのリンク付き参照 §5 の
>  「OpenAPI 定義の出力先は設計で確定していないため、ディレクトリを作っていない」)

**現行 `templates/app-monorepo/backend/STRUCTURE.md` に当該文字列は 0 件**
(`grep -c "設計で確定していないため" …` = 0)。`:208` は「### OpenAPI 定義の出力先 (**2026-08-03 に確定**)」。

**方針転換の根拠 (「旧状態では未設計だった」) を検証しようとした読者が、正反対の記述に当たる** (DR-1)。
`make doc-lint` はリンク先の実在しか見ないため検出されない。
なお `aidlc-docs/aidlc-state.md:65` は「**旧** `templates/backend-repo/STRUCTURE.md` §5」と書いていて正しい。

**修正案**: 「**旧版**: `templates/backend-repo/STRUCTURE.md:208` (コミット `0448a12` 時点)」と書く。

### 中 10. `deploy` の paths について **3 者が食い違う** (R2-L3 未是正)

| 箇所 | 記述 |
|---|---|
| `templates/app-monorepo/.github/workflows/deploy-backend.yml:25` | 「path filter は ci.yml の backend ジョブと**同じ条件**にする」 |
| `docs/design/operations.md:341` | 「**部分集合にする** (ワークフロー定義自身の変更を除く)」 |
| 実物 `deploy-backend.yml:28`〜`:31` | `backend/**` / `api/**` / `.github/workflows/deploy-backend.yml` = **上位集合** |

**修正案** (2 巡目の原文): コメントを「`ci.yml` の条件 ⊆ 本 paths。追加分は理由をコメントで書く」に直す。

### 中 11. **DR-10 の 9 例目** — `gate` 1 本必須 × 「Require branches to be up to date」で、**サブツリー間のマージ独立性が消える**

`templates/shared/.claude/rules/04-human-checkpoints.md:338` は
「**Require branches to be up to date before merging** を有効化」を立ち上げチェックリストに置いている。
MR-1 により**必須チェックは `gate` 1 本**であり、`gate` は `always()` で全ジョブを集約する。

**3 リポ構成では BE のマージが FE の PR を無効化しなかった** (別リポ = 別ブランチ保護 = 別の up-to-date 判定)。
**モノレポでは `main` が 1 本なので、BE のマージが `frontend/` しか触っていない PR まで
「out of date」にし、`gate` の再実行を要求する**。path filter は「どのジョブを走らせるか」を絞るだけで、
**`gate` 自体は必ず再実行される**ため、`changes` + `gate` の 2 ジョブ分のキューが全 PR に発生する。

これは `feedback_review_patterns.md` DR-10 が言う「**構造の副産物として成立していた性質が、
どの検査にも現れないまま消える**」の 9 例目である (既知の①〜⑧ とは別軸: **マージのスループット独立性**)。
規約も CI も何も壊れず、**PR が増えたときに初めて「マージが直列化する」形で現れる**。

**修正案**: `architecture.md` §3.11.2 の MR-1 の「代償」欄に 1 行足す —
「**`main` が 1 本になるため、up-to-date 要求下では他サブツリーのマージが全 PR の再実行を誘発する**。
PR 同時数が増えたら ①up-to-date 要求を外す ②merge queue を導入する のどちらかを検討する」。
`04-human-checkpoints.md:338` にも同じ注記を添える (「3 リポでは無償だった」ことを書く)。

### 中 12. `.claude/settings.json` の妥当性が **どの CI でも検査されない** (R2-M4 ① の一部)

`04-human-checkpoints.md:210` は H-4 の「二重化」として
「`.claude/settings.json` で `gh workflow run` と `production` への push を deny (§3.2)」を挙げ、
`:243` は「**JSONC 形式のコメントを残すと deny が全滅する。しかも失敗は目に見えない**」と自ら警告している。
検証は `:402`〜`:403` (`python3 -m json.tool`) にあるが、これは**立ち上げ時の目視チェックリスト 1 回きり**である。

モノレポでは `.claude/` はリポジトリ内のファイルなので **任意の PR が編集できる**。
`meta` フィルタは `.claude/**` を含む (`ci.yml:60`) のに、`meta` ジョブの検査は
`find scripts` の `bash -n` / `actionlint` / `check-regen.sh` 自己テスト / `check-ci-gate.sh` の 4 つで、
**`.claude/` を 1 バイトも見ない**。したがって `settings.json` を壊す PR は `gate` 緑でマージできる。

**修正案**: `meta` ジョブに 2 ステップ足す — ①`python3 -m json.tool .claude/settings.json`
②`.github/**/*.yml` の YAML パース (`actionlint` は `.github/workflows/` しか見ないため issue テンプレートを守らない)。
`.claude/` を検査対象にしないなら **`meta` フィルタから外して理由を書く** (フィルタに入れて無検査は
「検査しているように見える」ぶん悪い)。

---

## 5. 裏取りの記録

### 5.1 `check-regen.sh` の実挙動検証 (使い捨て git リポジトリ・8 ケース)

`templates/app-monorepo/scripts/check-regen.sh` をスクラッチのリポジトリへコピーし、
`api/openapi.yaml` / `frontend/src/generated/theme.ts` / `backend/usecase/u.go` を commit 済みの初期状態
(`.gitignore` = `node_modules/` `*.log`) から実行した。

| # | ケース | 期待 | 結果 |
|---|---|---|---|
| T1 | `frontend/src/generated/idea.ts` を**新規追加** | 検出 | **exit=1 ✅** (`?? frontend/src/generated/idea.ts`) |
| T2 | 変更なし | 通過 | exit=0 ✅ (`[check-regen] OK`) |
| T3 | `api/openapi.yaml` を**変更** | 検出 | exit=1 ✅ (` M` + 内容 diff) |
| T4 | `frontend/src/generated/theme.ts` を**削除** | 検出 | **exit=1 ✅** (` D` + `deleted file mode`) — **2 巡目の重大 R2-1 は解消** |
| T5 | `.gitignore` 対象 (`debug.log`) を置く | 巻き込まない | exit=0 ✅ |
| T6 | **対象外パス**の変更 (`backend/` を変えて `api/openapi.yaml` を検査) | 巻き込まない | exit=0 ✅ |
| T7 | **インデックス汚染** (未ステージの削除を持った状態で実行 → commit) | 混入しない | **✅** 実行前後で `git status` が ` D backend/usecase/u.go \| A  backend/v.go` のまま。`git commit` は `backend/v.go` 1 件のみ (**2 巡目の S2 は解消**) |
| T8 | **存在しない pathspec** (`api2/openapi.yaml` / `nonexistent/dir`) | 検出 or 明示エラー | **exit=0 / `[check-regen] OK` ❌** (前版は exit=128) → **重大 1** |

T7 の実測ログ:

```
[実行前]  D backend/usecase/u.go|A  backend/v.go|
$ ./scripts/check-regen.sh backend
::error::生成物が最新ではありません: backend
 D backend/usecase/u.go
A  backend/v.go
  exit=1
[実行後]  D backend/usecase/u.go|A  backend/v.go|      ← 変化なし (インデックス非汚染)
$ git commit -qm "add v.go only"
 backend/v.go | 1 +
 1 file changed, 1 insertion(+)                        ← 削除は混入していない
```

### 5.2 `scripts/check-monorepo-ci.sh` の故障注入 (11 種)

実行は `bash scripts/check-monorepo-ci.sh`。基準線は `[monorepo-ci] 照合 31 件 / エラー 0 件` (exit=0)。

| # | 注入内容 | 期待 | 結果 |
|---|---|---|---|
| FI-1 | `ci.yml` に `newjob` を追加し `gate` の `needs` に足さない | 検出 | **exit=1 ✅** (①。ただしメッセージから `gate` が消える = 中 2) |
| FI-2 | `gate` の `needs` から `contract` を削除 | 検出 | **exit=1 ✅** (①) |
| FI-3 | `task-backend.yml` の `required: true` を全て false に | 検出 | **exit=1 ✅** (②「必須欄が 4 件 (期待 5)」) |
| FI-4 | `architecture.md` の「6 機構」→「5 機構」 | 検出 | **exit=1 ✅** (③) |
| FI-5 | `frontend.md` に裸の `git diff --exit-code -- frontend/src/generated` の実行要求を書く | 検出 | **exit=1 ✅** (④ の `docs/` 対象。**D-5 の是正が効いている**) |
| FI-6 | `deploy-backend.yml` の `paths` に `'docs/**'` を追加 | 検出 | **exit=1 ✅** (⑤) |
| FI-7 | `deploy-backend.yml` の `name: Deploy` → `Deploy Backend` | 検出 | **exit=1 ✅** (⑧) |
| FI-8 | `architecture.md` に「モノレポ機構の M-3」と書く | 検出 | **exit=1 ✅** (⑨) |
| FI-9 | **無改変**のまま (現存する `check-monorepo-ci.sh:95` の `(M-1)` / `:221` の `(M-3 の実体)`) | 検出 | **exit=0 ❌ 非検出** — ⑨ が `scripts/` を走査しない → **中 1** |
| FI-D | `deploy-backend.yml` の `paths` から `'api/**'` を削除 | 検出 | **exit=0 ❌ 非検出** (2 巡目 中 R2-M6 のまま) → **重大 2** |
| FI-E | `CODEOWNERS` の `/api/` を 1 行 2 オーナーに戻す | 検出 | **exit=0 ❌ 非検出** (2 巡目 中 R2-M5 のまま) → **重大 2** |
| FI-I | `operations.md:321` の「ジョブは 6 本」→「5 本」 | 検出 | **exit=0 ❌ 非検出** (2 巡目 中 R2-M7 のまま) → **重大 2** |
| FI-L | `changes` の `meta` フィルタ 4 行を削除 | 検出 | **exit=0 ❌ 非検出** (2 巡目 中 R2-M4 のまま) → **重大 2** |

**8 検出 / 5 非検出**。検出した 8 種はいずれも検査①〜⑨ の骨格が健全であることを示す。
非検出の 5 種は**すべて 2 巡目で既に非検出と報告されたもの (4 種) + 検査⑨ の自己適用漏れ (1 種)** であり、
**新たな検出力は 1 つも足されていない**。

### 5.3 `templates/app-monorepo/scripts/check-ci-gate.sh` の故障注入 (3 種)

使い捨てディレクトリへ `ci.yml` とスクリプトをコピーして実行 (D-2 の担保が実装リポ側で生きるかの確認)。

| # | 注入内容 | 結果 |
|---|---|---|
| CG-0 | 無改変 | `[check-ci-gate] OK: job 6 本 / gate の needs 5 本 / 判定 5 本` exit=0 ✅ |
| CG-1 | `gate` の `needs` から `meta` を削除 | **exit=1 ✅** (①) |
| CG-2 | `gate` から `if: always()` を削除 | **exit=1 ✅** (③「必須チェックの status が来ないまま PR が pending で止まります」) |
| CG-3 | `gate` の `check contract` 行だけ削除 (`needs` は残す) | **exit=1 ✅** (②) |

**3/3 検出**。D-2 の是正 (担保を実装リポ側へ移す) は**実物として機能している**。

### 5.4 注入の復元確認

```
$ shasum -a 256 -c sha-before.txt | grep -cv ": OK"
0                                        ← 11 ファイル全て一致

$ git status --porcelain | wc -l
     144                                 ← レビュー開始時と同一
```

対象ファイル: `templates/app-monorepo/.github/workflows/{ci,deploy-backend,e2e}.yml` /
`templates/app-monorepo/.github/{CODEOWNERS,pull_request_template.md}` /
`templates/app-monorepo/.github/ISSUE_TEMPLATE/task-backend.yml` /
`templates/app-monorepo/scripts/{check-ci-gate.sh,check-regen.sh}` /
`docs/design/{architecture,operations,frontend}.md`。

**本レビューは上記 11 ファイルへの一時的な注入と復元のみを行い、
成果物 `aidlc-docs/reviews/productionization/review-monorepo-r3.md` の作成以外の変更をしていない。**

### 5.5 `make check` の出力 (レビュー終了後 = 復元後)

```
[doc-lint] 対象 111 ファイル / エラー 0 件 / 警告 49 件
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 86/86 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
[workflow-shell] 検査 58 ブロック / エラー 0 件
[table-counts] 実測: 機能テーブル 42 (個人 34 / 契約 8) / 分類 ①31 ②2 ③1
[table-counts] 実測: 機能テーブル以外 12 (所有者列なし 7 / 所有者列あり 5) / 検査①の除外リスト 9
[table-counts] 照合 37 件 / エラー 0 件
[endpoint-mapping] 実測: auth-accounts.md 37 本 / 9 ドメイン 112 本 / settings.md §5 18 行 / custom tool 8 本 / 403 16 本
[endpoint-mapping] 照合 36 件 / エラー 0 件
[monorepo-ci] 実測: ci.yml の job 6 本 / モノレポ機構 MR-x 6 件 / issue テンプレート 3 本
[monorepo-ci] 照合 31 件 / エラー 0 件
make check exit=0
```

**実体は 7 ゲート**であり、`CLAUDE.md` の「上記 5 つ」・`aidlc-state.md` の「6 ゲート」と食い違う (中 4)。
警告 49 件は既存 (過去 review / `design_memo.md` の TODO 語 / 未回答 `[Answer]` 6 件) で、本増分由来の新規警告は無い。

### 5.6 出典の抜き取り照合 (5 件 / 一致 5)

| # | 出典 | 主張 | 結果 |
|---|---|---|---|
| 1 | `claude_managed_agents/.github/workflows/ci.yml:27`〜`:30` (`docs/design/testing.md:64` の T-F15 / `:764`) | 「CI は PostgreSQL を起動しない。`go test` は `DATABASE_URL` 未設定のインメモリ経路を前提」 | **一致**。当該行に `- name: go test` / `run: go test ./...` / `# AC-1.3: PostgreSQL サービスは起動しない。` / `# …DATABASE_URL 未設定でインメモリ動作する設計。` |
| 2 | `docs/design/infrastructure.md:227`〜`:231` (§4.2。**D-1 の結論を左右する事実**) | D-I 却下案 (b) の訂正が引用する「ecspresso が tfstate からクラスタ名・subnet ID・SG ID・TG ARN・シークレット ARN を解決する」 | **一致**。`:228`〜`:229` が逐語で該当。§3.11.4 の記述もこの範囲と整合 |
| 3 | `templates/app-monorepo/frontend/.eslintrc.json.tmpl:30` / `:31`〜`:38` (`docs/design/testing.md:574` / `:881`) | 「`:30` = `no-arbitrary-value` / `:31〜38` = `no-custom-classname` + whitelist `^(app\|admin)-.*`」 | **一致**。実測で行番号・内容とも一致 (R2-2 が「無変更ファイルなので有効」とした判断を再確認) |
| 4 | `templates/app-monorepo/backend/STRUCTURE.md:208` (`questions.md:72` が引用) | 「OpenAPI 定義の出力先は設計で確定していないため、ディレクトリを作っていない」 | **不一致** — 現行 `:208` は「### OpenAPI 定義の出力先 (2026-08-03 に確定)」。当該文字列は 0 件 → 中 9 |
| 5 | `templates/app-monorepo/.github/workflows/deploy-backend.yml:533`〜`:540` (`testing.md:872` が「送信側」と呼ぶ箇所) | 「送信側は `release` 末尾」 | **不一致** — 実物は `echo` のみの「E2E の起動方法 (記録用)」ステップ。送信は存在しない → 中 3 |

---

## 6. 頻出パターン DR-1〜DR-10 の判定

| # | 判定 | 根拠 |
|---|---|---|
| DR-1 | **違反 2 件** | `questions.md:72` の出典が現行ファイルと正反対 (中 9) / `testing.md:872` が存在しない送信側を指す (中 3)。`aidlc-state.md:67` の「故障注入は累計 12 種で全件検出」も実測と食い違う (重大 2) |
| DR-2 | 問題なし | 本増分は本番ゲート D-1〜D-8 に触れており、D-1 (環境) / D-2 (CI ゲート) / D-3 (デプロイ順序) / D-8 (IaC) への回答は `architecture.md` §5 と `operations.md` §10 に ID 付きで存在。**ただし D-8 の回答が参照する INF-I が壊れている** (重大 3) |
| DR-3 | 対象外 | 本増分はリポジトリ構成でありスキーマに触れない |
| DR-4 | 問題なし | PoC 実装の持ち込みは無い |
| DR-5 | 問題なし | 「後で検討」型の丸投げは検出せず。要確認は全て「未検証 + 確認方法 + 外れた場合の影響」の形式 |
| DR-6 | **違反 2 件** | ①`check-regen.sh` が「対象 0 件」を緑で返す (重大 1) ②検査⑨ が `scripts/` を走査せず、現存の改名漏れ 6 件を検出できない (中 1)。**加えて MR-1/2/4/5 に AC が無い** = 逆方向の DR-6 (中 5) |
| DR-7 | 対象外 | プロトタイプ由来の記述なし |
| DR-8 | **違反 5 件 (6 巡連続)** | R2-M1 の 3 箇所 (重大 4) / 「回避可能な 2 件」(重大 5) / INF-I の 3 本 (重大 3) / `testing.md:872` の `environment: dev` (中 3) / `frontend.md:1024` の「未了」(軽微 3)。**是正の 3 件が新しい波及漏れを生んでいる** |
| DR-9 | **違反 3 件** | INF-I 「3 本」 (重大 3) / 「回避可能な 2 件」 (重大 5) / 「6 ゲート」 (中 4)。**新しく書かれた「N 件」で検算対象に入ったものは 0 件**。良い例外: `README.md` は数値を落として再現コマンドにした / `operations.md:156` は「件数を転記しない = DR-9」と明記 |
| DR-10 | **9 例目を検出** | `gate` 1 本必須 × up-to-date 要求で**サブツリー間のマージ独立性が消える** (中 11)。既知の①〜⑧ は代償欄に記載済みで、その点は良い |

---

## 7. 本番ゲートのカバレッジ (本増分が触る範囲)

| ID | 状態 | 箇所 |
|---|---|---|
| D-1 環境 | **回答あり** | `operations.md:801` (§3。local / dev / prod)。FE(Vercel) ↔ BE(AWS) の対応は §3.2。**environment は 6 種** (`04-human-checkpoints.md:371`) |
| D-2 CI ゲート | **回答あり** | `architecture.md:1036` (D-2①〜⑨) / `operations.md` §5.1.1。**ただし機構の穴 = 重大 2 / 中 12** |
| D-3 デプロイ手順 | **回答あり** | `operations.md:802` (§5)。`ecspresso verify` が `release` の `deploy` 直前に入った (`deploy-backend.yml:472`) |
| D-4 DB マイグレーション | **回答あり** (本増分の変更なし) | `operations.md` §5.1 |
| D-5 シークレット | **回答あり** | `operations.md:803` (§4)。§4.1 の限定列挙は**例外ゼロ件**を維持 (`:167`) |
| D-6 Agent ライフサイクル | **回答あり** (本増分の変更なし) | `architecture.md:1040` / `deploy-backend.yml` の `plan_agent` / `apply_agent` |
| D-7 段階リリース | **回答あり** | `operations.md` §7。**ただし `production` ブランチの帰結が未定義 = 中 6 / 中 7** |
| D-8 IaC の管理範囲 | **回答あり (内容に矛盾)** | `infrastructure.md` §3 / §4.5。**INF-I の 3 本と §4.5 の 8 行が矛盾 = 重大 3** |
| A-1〜A-7 / O-1〜O-7 | 本増分の対象外 | リポジトリ構成の変更であり、認証・可観測性の設計判断に触れていない。**ただし D-4 の OIDC 信頼条件は A 領域に隣接**しており、§4.5 で環境ごとの分離が定義された |

---

## 8. 軽微 (Nice to Have)

| # | 箇所 | 内容 |
|---|---|---|
| 1 | `templates/app-monorepo/.github/workflows/ci.yml:509`〜`:513` | R2-L4 未是正。`bash <(curl -fsSL …) \|\| { echo "::error::…"; exit 1; }` は **`bash` の終了コードしか見ない**ため、curl が失敗すると空スクリプトを実行して exit 0 になり、意図した `::error::actionlint の導入に失敗しました` が出ない (次行が 127 で落ちるので無言スキップにはならない)。`curl -fsSL … -o /tmp/dl.bash && bash /tmp/dl.bash` の形にする |
| 2 | `docs/design/frontend.md:965` | 「…「検査 3 NEXT_PUBLIC_ の許可リスト」ステップ **の** `ALLOWED`」 — 行番号→ステップ名置換の二重助詞が 1 件残存 (`testing.md:874` の同型は解消済み) |
| 3 | `docs/design/frontend.md:1024` | 「**`testing.md` §10 への登録は未了**」が**事実と逆** — `docs/design/testing.md` §10 の表に **6 番として登録済み** (`:661` 相当の行「FE: `src/lib/parse/**` と `features/*/lib/**` に併置テストがある」)。同書 `:881` 自身が「登録した」と書いている。DR-8 の状態語型 (本増分以前からの残存の可能性あり) |
| 4 | `docs/design/operations.md:815` | 「**infra リポ** (最初に着手。**他 2 リポの前提**」 — 2 リポ構成では「app モノレポの前提」 |
| 5 | `aidlc-docs/inception/construction-workflow/questions.md:3` | 「実装リポジトリ (**backend / frontend / infra**) で 1 issue をどう回すか」 — 同書 `:58` に読み替え注記はあるが冒頭の位置づけ文が 3 リポ前提のまま |
| 6 | `scripts/check-monorepo-ci.sh:181` | 検査④ のコメントが「差分検査は必ず `scripts/check-regen.sh` (**`git add --intent-to-add` を挟む**) を通す」— **旧実装の説明**。現行は `git status --porcelain --untracked-files=all` (`check-regen.sh:58`)。R2-1 の是正で本文は直したがコメントが取り残された |
| 7 | `docs/design/operations.md:835`〜`:860` (§9) | D-2 の修正案 3 「app モノレポ引き渡しに 1 項目として追加」が未反映 (`architecture.md` §7 には入った)。`todo.html:410` の「既存 **3** 名前空間」も実際は 4 |

---

## 9. 良かった点

1. **`check-regen.sh` の作り直しが正確**。`git status --porcelain --untracked-files=all` 方式は
   追加 / 変更 / 削除の 3 種を 1 回で見て、**インデックスを一切触らない**。
   本レビューの 8 ケース実測で 7/7 が期待どおりだった (残る 1 つが重大 1)。
   `:14`〜`:32` のコメントが**なぜ前版が誤りだったかを実測ベースで残している**のも良い —
   同じ誤りを「簡素化」として再導入する経路が閉じている
2. **D-2 の是正が「担保の置き場所」を正しく直した**。`check-ci-gate.sh` を雛形側に置いて `meta` から呼ぶ形は、
   `05-harness.md` の「切り出し後は実装リポ側が正」と整合する唯一の解であり、
   本レビューの故障注入 **3/3 で実際に機能することを確認**した。`ci.yml:560`〜`:565` のコメントが
   DR-10 (必須チェックの厳格さがサーバ側からコード側へ移った) を引用して理由を残している
3. **R2-3 の結論の出し方が誠実**。「同じパスを 2 行書けば双方の承認になる」という**都合の良い推測を撤回し、
   『双方が見ることは機構化できない』を確定した制約として書いた**。
   `04-human-checkpoints.md:415`〜`:418` の awk も「1 行 1 オーナーであること」を検査する形に反転しており、
   **誤った合格を渡す検査が誤りを検出する検査になった**。§2.6 の「回避可」への登録と、
   却下案 (reviews API で両チーム承認を検査する CI) の明記まで揃っている
4. **D-1 の訂正が 3 文書で同期している**。`architecture.md:60` / `questions.md:85`〜`:94` / `aidlc-state.md:65` の
   すべてに訂正が入り、**「⚠️ 却下理由に『契約が無い』を使わない」という再発防止の注記**が却下案の中に埋め込まれた。
   さらに §3.11.4 を新設して「静的検査できない契約」を残課題として起こし直し、
   `ecspresso verify` として**実際に雛形へ組み込むところまで完了している** (要確認も明示)
5. **D-4 の波及が広い**。`dev-e2e` の追加が `e2e.yml` / `04-human-checkpoints.md` (表・チェックリスト・確認コマンド) /
   `operations.md` §4.1 / `testing.md` §11 の **5 箇所に同期**している (§13.3 だけが漏れた = 中 3)。
   §4.5 の「要点 3 つ」が `ref:` 条件の落とし穴まで書いているのは、実装者が誤った信頼条件を作るのを防ぐ
6. **`docs/design/README.md` の DR-9 対応が規約どおり**。数値を落として「1 セッションで読み切れない規模」+
   再現コマンド (`ls … | wc -l`) にし、API/ の件数は「§3 の総覧が正」とリンクに寄せた。
   **DR-9 自身に判断の目安 (a) 機械強制 / (b) 再現コマンド / (c) リンク を追記して還流させた**のも良い
7. **`meta` ジョブに `check-regen.sh` の自己テストを置いた着想**。「検査スクリプト自身が壊れても静かに緑を返す」
   という性質を、**使い捨てリポジトリでの実挙動テストで毎 PR 潰す**形にしたのは、
   本リポジトリの「足した検査を故障注入で殴る」規約を CI へ持ち込んだ最初の例である
   (ケースが 1 つ足りないのが重大 1)

---

## 10. 要確認 (実挙動を確認していない項目)

| # | 項目 | なぜ確認が要るか | 確認方法 |
|---|---|---|---|
| 1 | GitHub のブランチ保護に **PR の head ブランチを制限する設定**が本当に無いか (中 7) | 有るなら 04 の記述は正しい | Rulesets の設定画面 / API を 1 回確認する |
| 2 | `dorny/paths-filter@v3` が `push: [main]` イベントで `github.event.before` をどう扱うか | force push・初回 push で全ジョブが走る / 走らないのどちらか未確認。`gate` の判定に影響し得る | 実装リポで 1 回試す |
| 3 | OIDC の信頼条件に `environment:` を使う形が推奨されるか (`infrastructure.md` §4.5 の要確認をそのまま引き継ぐ) | 誤ると全 CI が AWS に到達できない | AWS / GitHub の最新ドキュメント |
| 4 | `golangci-lint-action@v6` × `version: v2.x.y` (`architecture.md` §3.11.2 要確認 #1) | 未解決のまま。雛形投入直後の CI が必ず落ちる可能性 | action の README / 実装リポで 1 回 |
| 5 | `ecspresso verify` が §3.11.4 の 4 種のうちどれを検出するか | 検出しない種類は §6.3 の人手の担保に残る | 立ち上げ時に dev の TG を作り直して故障注入 |
| 6 | `actionlint` の `download-actionlint.bash` の配置先 (軽微 1) | 変わると `meta` が常に 127 で落ちる | 実装リポで 1 回 |
| 7 | up-to-date 要求下の `gate` 再実行が実際にどの程度直列化するか (中 11) | 影響の大きさが PR 同時数に依存する | 運用開始後に計測 |

## 11. 調べていない範囲 (カバレッジの正直さ)

- **1 巡目・2 巡目で「一致」と判定された項目のうち、本レビューで再検証していないもの**:
  `pre-commit` の全機能 (パス接頭辞除去 / `--passWithNoTests` / `go.mod` の WARN) /
  `rollback-backend.yml` の全文 / `task-frontend.yml` の全文 / `pull_request_template.md` の V-x 以外 /
  `templates/infra-repo/` の全文。**2 巡目が実測済みで、本増分で変更されていないため**
- **`templates/app-monorepo/backend/.claude/rules/05-architecture-coding-rules.md` / `layering-scopes.yml` /
  `prompts/agents.yaml` / `.golangci.yml` の内容**は本レビューの対象外 (本増分で変更なし)
- **GitHub / AWS / Vercel / Anthropic の実挙動は一切実行していない** (§10 の 7 件)
- **`docs/design/API/{conversation,ideas,plans}.md` / `review-conversation*.md` / `機能一覧.md` /
  `scripts/check-endpoint-mapping.sh` / `scripts/check-traceability.sh` / `scripts/check-table-counts.sh`** は
  本増分の対象外 (別レビュー系列)
- **`check-template-sync` の同期対象の妥当性**は確認していない (ゲートが緑であることのみ確認)
- **設計判断そのもの (D-I の採否)** は 2 巡目で「妥当」と判定済みであり、本レビューでは再評価していない —
  本レビューは**反映の照合と機構の検出力**に絞っている (指示による)

---

## 12. Design Freeze の可否

**不可**。次を満たしてから 4 巡目 (または軽量再レビュー) を行うこと:

1. **重大 1**: `check-regen.sh` に pathspec 不一致の検出を足し、`meta` の自己テストに 6 ケース目を追加する
2. **重大 2**: 非検出の 4 種を `check-monorepo-ci.sh` の検査に取り込み、**取り込んだ検査を故障注入で殴った証跡**を残す
3. **重大 3**: `infrastructure.md` の INF-I / `:183` / `:370` / `:386` を §4.5 に整合させる (本数はリンクに寄せる)
4. **重大 4**: `01-construction-loop.md:67` / `:316` / `testing.md:585` の 3 箇所
5. **重大 5**: `04-human-checkpoints.md:216` / `:218` を 3 件に更新する

**中 12 件のうち、少なくとも 中 1 / 中 3 / 中 4 / 中 5 は Freeze 前に処理すべき** —
中 1 は「新設した検査が自分を見ていない」、中 3 は「D-4 で塞いだ穴を復活させる記述」、
中 4 は「検証ゲートの SSOT が 2 巡放置」、中 5 は「MR-1/2/4/5 が受入基準として承認されていない」であり、
いずれも**実装リポへそのまま運ばれると取り返しがつく類ではない**。

**再レビュー時の追加観点**: 本レビューで 5 件の「是正が新しい欠陥/波及漏れを生んだ」を検出した
(重大 1 / 重大 3 / 重大 5 / 中 3 / 軽微 6)。**4 巡目は「今回の是正が触った節の前後 5 行」を必ず読むこと** —
5 件のうち 4 件は**是正した行の直下 2〜5 行**にある。
