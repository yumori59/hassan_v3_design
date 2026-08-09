# design-reviewer レビュー — リポジトリ構成の 2 分割 (設計文書側)

- **対象の変更**: 3 リポ分割 → **app モノレポ (`backend/` + `frontend/` + `api/`) + infra リポの 2 分割**
  (ユーザー決定 2026-08-03。`questions.md` Q-2 の `[Answer 2]` = D)
- **レビュー日**: 2026-08-04 / **レビュアー**: `design-reviewer` (別セッション。起草は別セッションが実施)
- **基準**: 本番基準 (`.claude/rules/08-production-gates.md`)。「3 リポ構成ではこうだった」「PoC では対象外だった」を
  省略の理由として認めない
- **スコープ外 (指摘しない)**: `templates/app-monorepo/` 配下のワークフロー・スクリプト・テンプレートの**実装**
  (別レビュアー担当 = `review-monorepo-harness.md`) / `docs/design/API/{conversation,ideas,plans}.md` /
  `review-conversation*.md` / `scripts/check-endpoint-mapping.sh` / `scripts/check-traceability.sh` / `機能一覧.md`
  — ただし**設計文書の記述が実物と一致するかの照合**のためには読んでいる

## レビューした成果物 (リポジトリ相対パス)

| 区分 | ファイル |
|---|---|
| 決定の SSOT | `aidlc-docs/inception/productionization/questions.md` (Q-2 `[Answer 2]`) / `aidlc-docs/inception/productionization/requirements.md` (C-10 / §6 の Q-2 行) / `docs/design/architecture.md` (§2 の D-I / §3.11 / §3.11.1 / §3.11.2 / §3.11.3 / §5) |
| 設計文書 | `docs/design/operations.md` / `docs/design/testing.md` / `docs/design/infrastructure.md` / `docs/design/frontend.md` / `docs/design/README.md` / `docs/design/data-model.md` / `docs/design/design_memo.md` / `docs/analysis/gap-analysis.md` |
| Inception | `aidlc-docs/inception/construction-workflow/questions.md` / `aidlc-docs/inception/construction-workflow/requirements.md` / `aidlc-docs/inception/construction-workflow/plan.md` / `aidlc-docs/inception/productionization/plan.md` |
| 運用ルール | `templates/shared/.claude/rules/01-construction-loop.md` / `templates/shared/.claude/rules/02-issue-granularity.md` / `templates/shared/.claude/rules/03-model-escalation.md` / `templates/shared/.claude/rules/04-human-checkpoints.md` / `templates/README.md` / `CLAUDE.md` / `.claude/rules/00-index.md` / `.claude/rules/05-harness.md` / `.claude/rules/feedback_review_patterns.md` (DR-10) / `Makefile` |
| 状態 | `aidlc-docs/aidlc-state.md` (2026-08-03 / 2026-08-04 の行) / `todo.html` |
| 照合のために読んだ (スコープ外) | `templates/app-monorepo/.github/workflows/ci.yml` / `templates/app-monorepo/.github/workflows/deploy-backend.yml` / `templates/app-monorepo/.github/workflows/e2e.yml` / `templates/app-monorepo/.github/CODEOWNERS` / `templates/app-monorepo/backend/STRUCTURE.md` / `scripts/check-monorepo-ci.sh` |

---

## ① 結論

**Design Freeze 不可**。重大 5 件を解消してから再レビューが必要。

| 区分 | 件数 |
|---|---|
| **重大 (Must Fix)** | **5** |
| 中 (Should Fix) | 10 |
| 軽微 (Nice to Have) | 5 |

**決定そのもの (D の採用) は妥当**と判断する。却下案 3 つが揃い、モノレポ化の代償を MR-1〜MR-6 として
明示設計で受けている点は、DR-10 を新設した経緯どおりの扱いになっている。
**問題は根拠と担保の 2 点に集中している**:

1. **却下案 (b) の根拠が、引用先の SSOT と食い違っている** — 「app と infra の間にコード上の契約が無い」は
   `infrastructure.md` §4.2 の tfstate 連携と矛盾する (重大 1)。「無い」と書かれた契約には誰も検査を設計しない
2. **モノレポ化で新設した担保が、担保として成立していない 3 件** — ①MR-1 の整合検査が**設計リポにしか無く
   引き渡し項目にもない** (重大 2) ②`scripts/**` の変更が `contract` ジョブを起動しないため
   **MR-3 の実体を無力化する PR が `gate` 緑で通る** (重大 3) ③**OIDC の信頼条件が設計に 1 行も無く**、
   3 リポ構成が `repo:` クレームで担保していた権限分離が消えている (重大 4)
3. **DR-8 (波及漏れ) が再発している** — 前巡で「重大 1」とされた「裸の `git diff --exit-code`」が
   `frontend.md` に生き残っている (重大 5)。前巡は**雛形と `testing.md` だけを直し、`frontend.md` を見ていない**

`make check` は全 7 ゲート緑 (エラー 0) だが、**上記 5 件はいずれも `make check` が見ていない**。

---

## ② 重大 (Must Fix)

### 重大 1. 却下案 (b) の根拠「app と infra の間にコード上の契約が無い」が、引用先の SSOT と矛盾する

**該当箇所**:

- `docs/design/architecture.md:60` (D-I の却下案 (b))
- `aidlc-docs/inception/productionization/questions.md:82`〜`:85` (採用理由 3)
- `aidlc-docs/aidlc-state.md:65` (同じ主張の転記)

> 3. **infra だけは分離を維持する** — app と infra の間にはコード上の契約が無く (受け渡しは SSM / Secrets Manager 経由。
>    [infrastructure.md] §6.3)、**同居しても検査が増えない**。

**引用先の実記述** (`docs/design/infrastructure.md:227`〜`:231`、§4.2「tfstate 連携の方向」):

> - ecspresso は **tfstate を読む側**であり、書かない。`ecspresso.yml` の tfstate プラグインで
>   S3 上の state を参照し、定義ファイル内で**クラスタ名・subnet ID・SG ID・ターゲットグループ ARN・
>   シークレット ARN を解決する**
> - **却下案: 出力値を app モノレポの設定ファイルへ手で書き写す** — infra 側の変更 … が backend 側に
>   反映されず、`ecspresso deploy` が古い ID を使う

**なぜ本番で問題になるか**:

1. **契約は実在する**。app (`backend/stacks/<env>/`) は infra の **tfstate 上のリソースアドレス / 出力名**を
   名前で参照している。SSM / Secrets Manager はシークレットの**値**の経路であって、
   デプロイ時の infra→app 契約ではない (§6.3 の図でも「シークレット経由」なのは RDS エンドポイントのみ)
2. **この契約が壊れると `ecspresso deploy` が実行時に落ちるか、古い ID で動く** (§4.2 が却下案の代償として
   自ら書いている失敗モード)。しかも **2 リポに跨るため、どちらの CI からも検査できない** —
   infra 側でリソースをリネームする PR は、app 側を壊したことを CI で知らされない。
   モノレポの主目的として掲げた「契約ドリフトの機械検出」が**まさに残った 1 本の契約に対して効かない**
3. 却下理由が「検査が増えない」と述べているため、**この契約に検査を設計する動機が文書から消えている**。
   「無い」と書かれた契約は誰も守らない (DR-1 の実害: 誤認が実装リポまで運ばれる)

**修正案** (決定を覆す必要はない。根拠を実態に合わせる):

- D-I の却下案 (b) の文言を「**app と infra の契約は tfstate の出力名・リソースアドレスに限られ、
  同居させても Terraform の `apply` 前後で意味が変わるため CI で照合できない**」に差し替える
  (= 同居しても検査できない、が正しい却下理由)
- **失われた担保を代償として明記する** (DR-10 の「代償欄に失う担保を明記する」):
  「infra のリソース名変更が app のデプロイを壊すことは、どちらの CI も検出しない」
- 代替機構を 1 つ置く。最小案: **`ecspresso.yml` が参照する tfstate の出力名の一覧を app 側に定義ファイルとして持ち、
  infra リポの CI (`plan` ジョブ) がその一覧を `terraform output` の名前集合と照合する**
  (infra 側の PR で落ちる形にする)。採らないなら「採らない理由 + 検出は `deploy` の失敗に委ねる」を書く

---

### 重大 2. MR-1 (gate の整合) の機械強制が設計リポにしか無く、実装リポへの引き渡し項目にもなっていない

**該当箇所**: `docs/design/architecture.md:920`〜`:928` / `docs/design/operations.md:306`〜`:307`

> **MR-1〜MR-6 の整合は機械強制する** — `make check-monorepo-ci` (**設計リポ** `scripts/check-monorepo-ci.sh`) が
> ①`ci.yml` の job 集合 == `gate` の `needs` == `gate` 内の判定名 … を照合する

**実物** (`templates/app-monorepo/.github/workflows/ci.yml:516`〜`:521`、`meta` ジョブ):

```
# **`gate` の needs / 判定名の整合は設計リポの `make check-monorepo-ci` が見る**
# (雛形の CI からは設計リポのスクリプトを呼べないため、ここでは検査しない)。
- name: gate の整合についての注意
  run: echo "::notice::… 実装リポへ切り出したら同等の検査を本ジョブへ移すこと …"
```

**なぜ本番で問題になるか**:

- `.claude/rules/05-harness.md:108`〜`:110` が「**雛形は初期値であって SSOT ではない — 切り出し後は
  実装リポ側が正になる (雛形を直しても向こうには反映されない)**」と定めている。
  したがって**切り出した瞬間に MR-1 の機械強制は消える**。設計リポの `check-monorepo-ci` は
  「雛形が正しいか」しか見ておらず、実装リポで**ジョブを 1 本追加して `gate` の `needs` に足し忘れる**
  = MR-1 が自ら「そのジョブの失敗が必須チェックを通る」と書いた事故を止められない
- `::notice::` は**ブロックしない**。しかも `meta` ジョブは `.github/**` が変わったときだけ走るので、
  ジョブ追加時 (= まさに `.github/` を触る PR) には出るが、**読み飛ばせる**
- **引き渡し項目になっていない**: `operations.md` §9 の「app モノレポ (`backend/`)」の 1〜9、
  `architecture.md` §7、`testing.md` §12 のいずれにも「gate 整合検査を実装リポへ移植する」が無い
  (`grep -rn "check-monorepo-ci" docs/ aidlc-docs/inception templates/` の全ヒットを確認済み)。
  **雛形のコメントだけが引き継ぎ手段**という状態は `06-delegation-prompts.md` の
  「機構を直したら、その機構を語る文書を同じ差分で直す」の裏返し (機構が語られていない)

**修正案**:

- `templates/app-monorepo/scripts/` に **`check-ci-gate.sh` (job 集合 == `gate.needs` == 判定名) を同梱**し、
  `meta` ジョブの `::notice::` を**実検査の呼び出しに置き換える** (雛形に入れれば切り出し後も生き残る)
- `architecture.md` §3.11.2 の「機械強制する」の主語を分ける —
  「**雛形の整合は設計リポの `make check-monorepo-ci`、実装リポの整合は `meta` ジョブの `check-ci-gate.sh`**」
- `operations.md` §9 の app モノレポ引き渡しに 1 項目として追加する

---

### 重大 3. `scripts/**` の変更が `contract` ジョブを起動しないため、MR-3 の実体を無力化する PR が `gate` 緑で通る

**該当箇所**: `docs/design/operations.md:299`〜`:355` (§5.1.1 の MR-1 の path filter と MR-3 の実装)

- `changes` の filter (実物 `ci.yml`): `backend: backend/**` / `frontend: frontend/**` / `api: api/**` /
  **`meta: .github/** , scripts/** , .claude/**`**
- `contract` ジョブの起動条件: `changes.backend || changes.frontend || changes.api`
- `meta` ジョブの内容: `scripts/` の `bash -n` と `actionlint` のみ

**なぜ本番で問題になるか**:

**MR-3 の実体は `scripts/check-regen.sh`** (前巡の重大 1 の是正としてこの形にした)。
`scripts/**` だけを変更する PR は `meta` しか起動せず、`contract` は skip される。
`bash -n` は構文しか見ないので、**`check-regen.sh` を「常に exit 0」に書き換える PR は
`gate` 緑でマージできる**。以後すべての PR で MR-3 (= モノレポ化の見返り本体) が空振りし、
**BE の IF 変更が FE の型に反映されないまま本番へ出る**。同じ理屈で
`check-required-tests.sh` / `check-owner-scope.sh` / `check-tool-contract.sh` (A-4 / D-6 の検査)
も無力化できる。設計リポの `check-monorepo-ci` ④ は「裸の `git diff` の不在」だけを見るので、
中身を空にする改変は検出しない (実測: ④ の grep 条件を確認済み)。

**これは MR-1 の設計そのものの穴**である。§5.1.1 は「**この検査が MR-1 の path filter で
skip される条件を作らない**」と `contract` について書いているが、**検査の実体ファイルが
変わったときに走らせる**ことを書いていない。

**修正案** (どれか 1 つ。①が最小):

1. `contract` / `backend` / `frontend` の起動条件に **`changes.meta` を OR で加える**
   (「機構ファイルが変わったら全部走らせる」— 頻度は低く、コストも小さい)
2. filter を「`backend: backend/** , scripts/**`」のように**検査スクリプトを利用側サブツリーに含める**
3. `meta` ジョブで**検査スクリプトの振る舞いテスト** (故障注入 1 件を仕込んで非 0 で落ちること) を回す

いずれにせよ `operations.md` §5.1.1 に「**検査の実体 (`scripts/`) を変える PR では、その検査を使うジョブを
必ず走らせる**」を規約として明記する。

---

### 重大 4. OIDC の信頼条件 (sub クレーム) が設計に存在せず、モノレポ化で「リポジトリ単位の権限分離」が黙って消えている

**該当箇所**: `docs/design/infrastructure.md:97` (INF-I) / `docs/design/operations.md:157`〜`:160` (§4.1 の CI 行)

> **GitHub OIDC + 用途別 IAM ロール 3 本** (`plan` 用 read-only / `deploy` 用 / `migration` 用) …
> 長期アクセスキーを作らない

**確認した事実**:

- 設計文書・雛形の全体を `grep -rn "信頼ポリシー\|trust\|sub クレーム\|token.actions.githubusercontent"` で見たが、
  **IAM ロールの信頼条件 (どの `sub` を許すか) を定めた記述は 1 件も無い**
- `templates/app-monorepo/.github/workflows/e2e.yml:69` は **`environment: dev`**、
  `:101` で `vars.E2E_AWS_ROLE_ARN` を引き受ける。
  `deploy-backend.yml:437` の `release` ジョブも dev では **`environment: dev`**
  → **E2E と dev のリリースが同一 environment を共有している**

**なぜ本番で問題になるか**:

1. 3 リポ構成では、IAM の信頼条件を `repo:<org>/hassan-v3-backend:*` に絞れば
   **frontend リポのワークフローからは backend の `deploy` / `migration` ロールを引き受けられなかった**。
   これは「文書化されていないがリポ境界が担保していた性質」の典型 (= DR-10 の対象) であり、
   モノレポ化で**信頼条件から `repo:` による分離軸が消える**
2. 残る分離軸は `environment:` / `ref:` だが、**`environment: dev` を e2e と release が共有している**ため、
   `sub` を `repo:<org>/hassan-v3:environment:dev` に絞っても両者を区別できない。
   結果、**Playwright + `npm ci` (第三者依存の塊) を走らせるジョブが、dev の deploy / migration ロールと
   同じ信頼境界に入る**。dev の RDS・ECS・Secrets Manager に到達し得る
3. 信頼条件が未設計だと、実装時に `sub: repo:<org>/hassan-v3:*` (= 全ブランチ・全ワークフロー) で
   作られる可能性が高い。その場合 **`feature/*` ブランチに置いた任意のワークフローから prod ロールまで
   引き受けられる** (prod の environment 承認は environment を宣言したジョブにしか効かない)

**修正案**:

- `infrastructure.md` INF-I に**信頼条件を明記する**: 各ロールの `sub` 条件を
  `repo:<org>/<repo>:environment:<env>` の形に固定し (ブランチ条件ではなく environment 条件にする根拠も書く)、
  `aud` の検証と `token.actions.githubusercontent.com` の 1 プロバイダ運用を書く
- **E2E 用に別 environment (`dev-e2e`) を切る** — `e2e.yml` は deploy と別の信頼境界に置く。
  併せて **E2E 用ロールを INF-I の「3 本」に加える (実際は 4 本)** = 中 10 と同一の是正
- 「3 リポ構成では `repo:` クレームが分離を担保していた」ことを **MR-4 の代償欄 (または新 MR) に明記**する
  (DR-10 の 4 例目として本レビューで登録)

---

### 重大 5. `frontend.md` が MR-3 を「裸の `git diff --exit-code`」として記述している (前巡の重大 1 の波及漏れ)

**該当箇所**: `docs/design/frontend.md:1191`〜`:1194` (§16.1 の FE-Q3 の解消記述)

> CI の `contract` ジョブ (モノレポ機構の MR-3) が
> `make -C backend docs` → **`git diff --exit-code -- api/`** → `npm run generate` →
> **`git diff --exit-code -- frontend/src/generated`** を実行して同期を機械検証する。

**確認した事実**:

- `architecture.md:911` (MR-3) と `operations.md:347`〜`:352` は
  「⚠️ **裸の `git diff --exit-code` を使わない** — 未追跡ファイルを見ないため
  **『エンドポイント追加』という最頻の変更で検査が空振りする**」と定め、`scripts/check-regen.sh` を通す
- 実物 `ci.yml:560` / `:580` も `check-regen.sh` を呼んでいる
- `templates/shared/.claude/rules/01-construction-loop.md:95` / `02-issue-granularity.md:248` も
  「裸の `git diff --exit-code` を書かない」と規約化済み
- **`frontend.md` だけが旧記述のまま**。設計リポの `check-monorepo-ci` ④ は
  「対象は `.yml` / `.sh` / `pre-commit`。`.md` は注意書き自体を含むため対象外」と明示的に `.md` を外している
  ため、**この文書は機械検査からも外れている**

**なぜ本番で問題になるか**: FE の型生成は `frontend.md` が SSOT として読まれる文書である
(`docs/design/README.md` §2 の「FE 担当のみ」の入口)。**FE 担当者がこの節を根拠に `contract` ジョブを
実装/再実装すると、前巡で重大 1 とされた空振りがそのまま復活する** (初回生成と新規出力が素通り)。
DR-8 の「思考の対象になった節だけを直す」の 6 巡目の再発で、
**前巡は雛形と `testing.md` を直して `frontend.md` を grep していない**。

**修正案**: `frontend.md:1193`〜`:1194` を `scripts/check-regen.sh` 経由の記述に差し替える。
併せて **`check-monorepo-ci` ④ の `.md` 除外を「`裸の git diff を使わない` 等の否定文脈を含む行だけ除外」に狭める**
(設計文書が壊れた機構を要求する経路を機械で塞ぐ。現状の除外は広すぎる)。
`docs/design/testing.md:223` も同型 (→ 中 2)。

---

## ③ 中 (Should Fix)

### 中 1. `testing.md` §13.3 の是正要求 2 が、廃止済みの `repository_dispatch` 機構を「作成済み」として記述している

**該当箇所**: `docs/design/testing.md:869` (§13.3 の #2)

> | 2 | [e2e.yml] | **2026-07-30 に作成済み** — dev デプロイ後 (**`repository_dispatch`**) + nightly + 手動のトリガー …
>   **送信側は [deploy-backend.yml] の `release` 末尾** |

**実物**: `e2e.yml:32` は `workflow_run:` / `:33` は `workflows: [Deploy]`。`repository_dispatch` は
コメント内の禁止注記としてのみ存在する。`deploy-backend.yml` の `release` に送信ステップは無い
(`:477`〜`:493` はコメントのみ)。同じ表の **#13 は「本項目は消滅 (2026-08-04)」「この行の要求を復活させないこと」**と
書いており、**同一表の中で #2 と #13 が矛盾している**。

**問題**: DR-8 の「受信側」型。#13 が明示的に警告している「`repository_dispatch` の再導入 =
`operations.md` §4.1 の限定列挙への例外の再導入」へ、#2 が読者を誘導する。
前巡のレビューで #13 を消滅扱いにしたときに **#2 を同じ差分で直していない**。

**修正案**: #2 の記述を `workflow_run` 起動 + 「送信側は存在しない」に差し替える。
§13.3 の表に**状態列**があるので、#2 に「2026-08-04 に `workflow_run` へ改訂」を追記する。

### 中 2. `testing.md` §5.3 の規約 4 が golden 検査を裸の `git diff --exit-code` と記述している

**該当箇所**: `docs/design/testing.md:223`

> `make golden` → **`git diff --exit-code`**。`Makefile` に `golden` ターゲットが無ければ `exit 1`

**実物** (`ci.yml:150`〜`:158`): `make golden` → **`scripts/check-regen.sh backend/testdata/golden`**。
雛形のコメントは「golden は **新規ファイルが増える形**で漏れるため、未追跡も見る必要がある」と明記している。
同書 §13.3 の #8 も `check-regen.sh` 経由に更新済みで、**§5.3 の表だけが旧記述**。

**問題**: golden は「新規ファイルが増える」形で漏れる代表例であり、裸の `git diff` が最も危険な対象。
実装リポが §5.3 を根拠に書き直すと BE-12 の再発防止が空振りする。

**修正案**: `:223` を `scripts/check-regen.sh backend/testdata/golden` に差し替える (重大 5 と同時に行う)。

### 中 3. Q-2 `[Answer 2]` の出典が、現在のファイル内容と正反対になっている

**該当箇所**: `aidlc-docs/inception/productionization/questions.md:70`〜`:73`

> (**[templates/app-monorepo/backend/STRUCTURE.md] §5** の
> 「OpenAPI 定義の出力先は設計で確定していないため、ディレクトリを作っていない」)

**確認**: 現在の `templates/app-monorepo/backend/STRUCTURE.md:208` は
**「### OpenAPI 定義の出力先 (2026-08-03 に確定)」「`make docs` の生成先は `../api/openapi.yaml`」**。
引用文は `git show HEAD:templates/backend-repo/STRUCTURE.md:208` に存在する (旧版)。

**問題**: DR-1。**方針転換の根拠 (「旧状態では未設計だった」) を検証しようとした読者が、正反対の記述に当たる**。
`make doc-lint` はリンク先の実在しか見ないため検出されない。
`aidlc-state.md:65` の「旧 `templates/backend-repo/STRUCTURE.md` §5」は「旧」と付いていて正しい。

**修正案**: 「**旧版**: `templates/backend-repo/STRUCTURE.md:208` (コミット `0448a12` 時点)」と書く。
現行ファイルへのリンクは「確定後の姿」として別に張る。

### 中 4. モノレポ機構のうち MR-1 / MR-2 / MR-4 / MR-5 に対応する AC が無い

**確認**: `grep -rn "MR-" aidlc-docs/inception/` のヒットは 4 件のみ —
`productionization/questions.md:94` (決定文) / `construction-workflow/questions.md:60` /
`requirements.md:55` (C-7 = MR-3) / `requirements.md:85` (AC-2.2 = MR-6)。
**MR-1 (gate 必須チェック) / MR-2 (Vercel の出し分け) / MR-4 (CODEOWNERS) / MR-5 (タグ名前空間) は
どの AC からも参照されていない**。

**問題**: DR-6 の逆方向 (「設計判断に対応する AC が無い場合も要件漏れ」)。
`make check-traceability` は **AC → 設計書**の方向しか見ないので、この穴は緑のまま。
実害は RL-0 の完了条件 (`operations.md` §6.1 の④) にこれらが列挙されているだけで、
**受入基準として承認されていない = 落としても誰も落としたと言えない**こと。

**修正案**: `construction-workflow/requirements.md` §3.5 に
**AC-5.5「モノレポ機構 MR-1〜MR-6 が雛形と立ち上げチェックリストに存在し、機械検査可能なものは検査に載っている」**を
1 本起こす (ID を増やす。AC-2.2 に相乗りさせない)。

### 中 5. 「`ci.yml` の job 6 本」「`deploy-backend.yml` の 6 ジョブ」が検算対象に入っていない (DR-9 の再発余地)

**該当箇所**: `docs/design/operations.md:306` (「**ジョブは 6 本**」) / `:16` `:252` `:784` (「**6 ジョブ**」×3)

**確認**: `make check-monorepo-ci` の①は「job 集合 == `gate.needs` == 判定名」を照合するだけで、
**文書の自称値「6 本」とは照合していない** (スクリプト全文を確認)。`deploy-backend.yml` の
ジョブ数はどの検査も数えていない (実測 6 = `build` / `plan_migration` / `apply_migration` /
`plan_agent` / `apply_agent` / `release`。現時点では一致)。

**問題**: DR-9 が「**新しく『N 件』を書くときは、同時に検算の対象に加えるか、書かずに定義元へのリンクにする**」と
定めている。`operations.md:306` は「ジョブ名はここで数えず実物を見る」と書きながら**本数だけを書いている**ため、
規約の趣旨を半分だけ満たしている。デプロイの 6 ジョブは 3 箇所に転記済み。

**修正案**: `check-monorepo-ci` に②'として「①の実測 job 数 ↔ `operations.md` の自称値」
「`deploy-backend.yml` の実測 job 数 ↔ 自称値 (3 箇所)」を追加する。
足したら**故障注入で殴る** (05-harness の「足した検査自体を故障注入で殴る」)。

### 中 6. モノレポでは `production` ブランチが backend コードを含むが、その帰結が書かれていない

**該当箇所**: `docs/design/operations.md:657`〜`:659` (§7.1) / `:97` (§3.2) / `docs/design/infrastructure.md:308` (§5.3)

> | **`production`** (**frontend のみ**) | Vercel の Production Branch | `main` からの PR のみ … |
> - **backend / infra に `production` ブランチを作らない**。BE の本番は「`main` の特定コミットを
>   手動起動でデプロイする」形であり、ブランチで表現しない

**問題**: 2 リポ構成では `production` は **app モノレポのブランチ**であり、**必然的に `backend/` を含む**。
「frontend のみ」「backend に作らない」は 3 リポ時代の言い方で、モノレポでは成立しない。
結果として次が未定義のまま残る:

1. **`production` ブランチの `backend/` はどこにもデプロイされない** — にもかかわらず
   `production` の head は「本番のコード」に見える。運用者が hotfix を `production` から切る / 「本番は
   `production` を見ればよい」と判断する余地がある
2. **§5.4 の③ (旧 IF の削除) の条件判定が非対称**になる。「②の FE が `production` に Promote 済み」は
   ブランチで確認できるが、**BE 側の「prod に何が載っているか」を知る手段が設計に無い**
   (`testing.md` §13.2 の **T-Q10** が「dev で稼働中の BE の commit を外部から知る手段が無い」と
   未調査のまま残しており、prod でも同じ)。3 リポ構成ではリポが別で「別々に確認する」ことが自明だったが、
   モノレポでは「同じ commit だから揃っている」という誤解が生じやすい (DR-10 の型)

**修正案**: §7.1 に
「**`production` ブランチの `backend/` サブツリーはどこにもデプロイされない。BE の本番は `main` の
手動 dispatch が唯一の経路であり、`production` の head は BE の本番状態を表さない**」を明記し、
`production` から作業ブランチを切らないことを規約化する。
併せて T-Q10 を「prod でも必要」に拡張し、§5.4 ③ の確認手段 (`/alive` に revision を載せるか) を先送り先付きで書く。

### 中 7. 「`production` は `main` からの PR のみ」はブランチ保護で強制できない (要確認付き)

**該当箇所**: `templates/shared/.claude/rules/04-human-checkpoints.md:337`〜`:341` /
`docs/design/operations.md:657`

> - [ ] **frontend のみ: `production` ブランチにも同等の保護を設定する** — 直接 push 禁止
>   (**`main` からの PR のみ**)・必須レビュー 1 名以上・force push / deletion 禁止

**問題**: GitHub のブランチ保護 / ruleset には **PR の head ブランチを制限する設定が無い** (要確認: 当方の
理解では 2026-08 時点で存在しない)。したがって「`main` からの PR のみ」は**チェックリストの項目としては
設定できない**。任意の `feature/*` から `production` へ PR を出せば、承認 1 名で**`main` を経ずに FE 本番へ出る** —
§7.3 の「dev の未リリース変更を prod に出さない 4 段」のうち機械の 3 段 (`workflow_dispatch` / environment 承認 /
フラグ) は **BE のみに効く**ため、FE 側にこの経路が残る。

**修正案**: ①**H-4 (FE) の確認観点に「この PR の head が `main` であること」を入れる** (人間の確認に落とす)
②または `production` への PR で `github.head_ref == 'main'` を検査する軽量ワークフローを 1 本置き、
必須チェックにする (機械化)。どちらを採るかを決め、04 の文言を「設定」から「確認観点 / 検査」へ移す。

### 中 8. MR-4 の代償欄が、DR-10 自身の指示 (置き換えられていないものを同じ行に列挙する) を満たしていない

**該当箇所**: `docs/design/architecture.md:912` (MR-4) / `.claude/rules/feedback_review_patterns.md:28` (DR-10 の 3 例目)

DR-10 は「**『CODEOWNERS で置き換えた』と書くときは、置き換えられていないもの
(write 権限・Dependabot の単位・`git blame` の分離) を同じ行に列挙する**」と定めている。
MR-4 の代償欄は **write 権限だけ**を挙げており、**Dependabot の単位・`git blame` / `git log` の分離が無い**。

**確認**: `grep -rn "Dependabot" docs/ templates/ aidlc-docs/inception` のヒットは
**DR-10 の本文 (と `templates/shared/` のコピー) のみ** — 設計文書のどこにも依存更新の話が無い。
モノレポでは **Dependabot の version updates が `directory:` ごとの宣言を要する**ため、
`/backend` (gomod) と `/frontend` (npm) を明示しないと**依存更新が静かに止まる**
(alerts は manifest 自動検出で残るが、更新 PR は出ない)。要確認: 3 リポ時代に dependabot 設定が
存在したかは確認できていない (雛形に `dependabot.yml` は無い) ため、「担保が消えた」ではなく
「**モノレポでは明示設定が必須になった**」が正確な言い方。

**修正案**: MR-4 の代償欄に 2 項目を追記し、**`.github/dependabot.yml` を雛形に置く**
(`/backend` と `/frontend` の 2 ecosystem)。`git blame` については「サブツリーを跨ぐコミットが混ざるため
`git log -- backend/` を使う」を `templates/app-monorepo/CLAUDE.md.tmpl` に 1 行。

### 中 9. `CLAUDE.md` の検証ゲート一覧が `make check` の実体と一致していない (新ゲート 2 本が未登録)

**該当箇所**: `CLAUDE.md:39`〜`:46` / `Makefile:17` / `Makefile:6`

- `CLAUDE.md` は **5 本を列挙し「上記 5 つをまとめて実行」**と書いている
- `Makefile:17` の `check` の依存は **7 本** (`doc-lint` `check-traceability` `check-workflow-shell`
  `check-table-counts` `check-endpoint-mapping` **`check-template-sync`** **`check-monorepo-ci`**)
- `make help` の要約行 (`Makefile:6`) も 5 本のまま

**問題**: `.claude/rules/05-harness.md:5` が「**検証コマンドの実体はルート `CLAUDE.md` の「検証ゲート」節が SSOT**」と
定め、05 自身は本数を書かない方針にしている。**その SSOT が新ゲートを 2 本落としている**ため、
「`make check` を通した」と報告する側も、レビュー側も、**`check-monorepo-ci` が存在することを
CLAUDE.md からは知り得ない**。`check-template-sync` は本変更以前からの未登録 (HEAD の CLAUDE.md も 5 本)。

**修正案**: `CLAUDE.md` の検証ゲート節に 2 本を追記し、「上記 5 つ」を**本数を書かない表現**に変える
(DR-9 の趣旨。`make check` が全部を実行する、と書けばよい)。`Makefile:6` の要約も同様。

### 中 10. INF-I の「IAM ロール 3 本」に E2E 用ロールが入っていない (実際は 4 本)

**該当箇所**: `docs/design/infrastructure.md:97` (INF-I) / `:331` (構築順序の段 2) / `:479` (`modules/iam-oidc`)

`e2e.yml:101` は `vars.E2E_AWS_ROLE_ARN` を引き受け、E2E 専用アカウントの資格情報を
Secrets Manager から取得する設計になっている (これ自体は `operations.md` §4.1 の限定列挙と整合し、
**「例外ゼロ件」の主張は妥当**)。しかし **infra 側の設計には E2E 用ロールが存在しない**ため、
RL-0 (`operations.md` §6.1) を実施しても E2E が動かない。
`testing.md` §13.3 の #5 (「E2E 専用アカウントの資格情報の所在を `operations.md` §4.1 に追加する」) は
**状態列が空 = 未実施**のままで、この不足と対になっている。

**問題**: モノレポ化で `e2e.yml` が app モノレポへ移り、**同一リポの `environment: dev` を共有した**ことで
重大 4 と結合する。件数「3 本」は 3 箇所に転記されている (DR-9)。

**修正案**: INF-I を **4 本** (`plan` / `deploy` / `migration` / **`e2e`**) にし、`e2e` ロールの権限を
「`/hassan-v3/dev/e2e/*` の `secretsmanager:GetSecretValue` のみ」に絞る。
`testing.md` §13.3 #5 の状態列を更新し、`operations.md` §4.1 の限定列挙に E2E ロール ARN を 1 行加える。

---

## ④ 軽微 (Nice to Have)

1. **`docs/design/operations.md:797`**: 「**infra リポ** (最初に着手。**他 2 リポの前提**。」 — 2 リポ構成では
   「app モノレポの前提」。3 リポ時代の数え方が残っている
2. **`aidlc-docs/inception/construction-workflow/requirements.md:113`**: AC-5.1 の
   「同じ規約を **3 箇所**に複製しない」 — コピー先は 2 リポ (DF-3 は「3 → 2 に減った」と正しく更新済みなので
   AC 本文だけが取り残されている)
3. **`aidlc-docs/inception/construction-workflow/questions.md:3`**: 「実装リポジトリ
   (**backend / frontend / infra**) で 1 issue をどう回すか」 — 同書 `:58` の Q-2 には読み替え注記があるが、
   冒頭の位置づけ文は 3 リポ前提のまま
4. **`aidlc-docs/aidlc-state.md:66` / `todo.html:410`**: 「`make check` を **6 ゲート**に」「全 **6 ゲート**緑」 —
   実体は 7 (中 9 と同根)。DR-9 の「数えた値を書かない」に従い、本数を書かず `make check` の出力を貼る形にする
5. **`docs/design/testing.md:223`**: 「…**ステップ の「golden ファイルの差分チェック」**」— 前巡の
   「行番号 → ステップ名参照」置換で文言が二重になっている (中 2 の修正と同時に整理)

---

## ⑤ 裏取りの記録

### 実行した検証コマンドと結果

```
$ make check
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

$ make check-traceability
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 86/86 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature

$ make doc-lint
[doc-lint] 対象 111 ファイル / エラー 0 件 / 警告 48 件
（本レビュー文書 2 本を含むため対象ファイル数が 109 → 111 に増えている）
```

**未カバー AC: 0 件 / リンク切れ: 0 件**。警告 48 件はすべて既知
(`design_memo.md` の取り消し線つき未確定マーカー・未回答 `[Answer]` 5 件 = `data-model.md:1061` `frontend.md:1239`
`infrastructure.md:519` `:535` `llm-migration.md:790` `operations.md:777`)。
**本変更が新しい未回答を増やしていない**ことを確認した。

> ⚠️ **`make check` の緑は本レビューの重大 5 件を 1 件も見ていない**。
> `check-monorepo-ci` は**雛形**の整合を見る検査であり、①実装リポ側の整合 (重大 2)
> ②検査スクリプトの中身 (重大 3) ③IAM の信頼条件 (重大 4) ④`.md` の記述 (重大 5。`.md` を明示的に除外)
> ⑤引用元の内容 (重大 1) はいずれも対象外である。

### 出典の抜き取り照合 (18 件 / 一致 13・不一致 5)

| # | 主張 (設計文書) | 照合先 | 結果 |
|---|---|---|---|
| 1 | D-I 却下案 (b): 「app と infra の間にコード上の契約が無く、受け渡しは SSM / Secrets Manager 経由」 (`architecture.md:60`) | `infrastructure.md:227`〜`:231` (§4.2)。**ecspresso が tfstate を読み、クラスタ名 / subnet / TG ARN / シークレット ARN を解決する** | **不一致 (重大 1)** |
| 2 | D-I 却下案 (b): 「infra は PR マージ ≠ 反映 (`apply` が人手ゲート、`apply` 済みが backend の着手条件)」 | `infrastructure.md:363`〜`:364` (§6.3) と `:255` (§4.4 = `apply` は dev も prod も人間) | 一致 |
| 3 | Q-2 `[Answer 2]` 採用理由 1 の出典「OpenAPI の出力先は未確定でディレクトリを作っていない」 | 現行 `templates/app-monorepo/backend/STRUCTURE.md:208` は「**2026-08-03 に確定。生成先は `../api/openapi.yaml`**」。旧版 `git show HEAD:templates/backend-repo/STRUCTURE.md:208` に該当文あり | **不一致 (中 3)** |
| 4 | `operations.md:306`「ジョブは 6 本」 | `ci.yml` の実測 job = `changes` / `backend` / `frontend` / `meta` / `contract` / `gate` = **6** | 一致 (ただし無検査 = 中 5) |
| 5 | `operations.md:252` `:16` `:784`「`deploy-backend.yml` の 6 ジョブ」 | 実測 = `build` / `plan_migration` / `apply_migration` / `plan_agent` / `apply_agent` / `release` = **6** | 一致 (ただし無検査 = 中 5) |
| 6 | `testing.md:398`「`e2e.yml` は `on.workflow_run` で `deploy-backend.yml` の完了を直接受ける」 | `e2e.yml:32`〜`:33` (`workflow_run:` / `workflows: [Deploy]`)・`deploy-backend.yml:1` (`name: Deploy`) | 一致 |
| 7 | `testing.md:869` (§13.3 #2)「dev デプロイ後 (`repository_dispatch`) …送信側は `deploy-backend.yml` の `release` 末尾」 | `e2e.yml` に `repository_dispatch` トリガ無し / `deploy-backend.yml` の `release` に送信ステップ無し (`:477`〜`:493` はコメントのみ) | **不一致 (中 1)** |
| 8 | `operations.md:166`「`E2E_DISPATCH_TOKEN` 廃止で GitHub 側の値は IAM ロール ARN と非秘密の識別子のみ = 例外ゼロ件」 | `e2e.yml:101` は `vars.E2E_AWS_ROLE_ARN` (ロール ARN) + OIDC + Secrets Manager。トークンの参照は無い | 一致 |
| 9 | MR-3「裸の `git diff --exit-code` を使わない。`check-regen.sh` を通す」(`architecture.md:911` / `operations.md:347`) | `ci.yml:560` `:580` は `check-regen.sh`。`:145` `:156` も同様 | 一致 |
| 10 | `frontend.md:1193`「`contract` ジョブが `git diff --exit-code -- api/` … を実行して機械検証する」 | 上記 9 と矛盾。実物にこの形は無い | **不一致 (重大 5)** |
| 11 | `testing.md:223`「golden は `make golden` → `git diff --exit-code`」 | `ci.yml:150`〜`:156` は `check-regen.sh backend/testdata/golden` | **不一致 (中 2)** |
| 12 | MR-4「`api/` は BE / FE を 2 行に分けて書く」(`architecture.md:912`) | `templates/app-monorepo/.github/CODEOWNERS` に `/api/` が 2 行 (backend-reviewers / frontend-reviewers) | 一致 |
| 13 | MR-1「必須チェックに指定するのは `gate` 1 本のみ」(`architecture.md:910`) | `04-human-checkpoints.md:316`〜`:320` (立ち上げチェックリスト) に同旨・`ci.yml` の `gate` は `if: always()` | 一致 |
| 14 | INF-I「CI の AWS 認証は OIDC + 用途別 IAM ロール **3 本**」(`infrastructure.md:97`) | `e2e.yml:101` が 4 本目 (`E2E_AWS_ROLE_ARN`) を要求。信頼条件の記述は全文書で 0 件 | **不一致 (重大 4 / 中 10)** |
| 15 | `infrastructure.md:48` (F-7)「v2 の CI は長期 IAM アクセスキー」 | `hassan-v2-backend/.github/workflows/prod-deploy.yml:20` `dev-deploy.yml:17` に `secrets.AWS_ACCESS_KEY_ID` | 一致 (参照リポ実測) |
| 16 | `operations.md:868`「v2 の `di/provider.go:83-94` = 環境名で env ファイルを選択する形 (部分踏襲)」 | `hassan-v2-backend/di/provider.go:83`〜`:94` = `GO_ENV` の switch で `env/.<env>.env` を `godotenv.Load` | 一致 (参照リポ実測) |
| 17 | `infrastructure.md` の前提「v2 に IaC が存在しない」 | `hassan-v2-backend` 配下に `*.tf` が 0 件 / `stacks/prod/ecspresso.yml` は実在 | 一致 (参照リポ実測) |
| 18 | `testing.md:857` (T-Q9)「v2 の PostgreSQL 拡張は `uuid-ossp` のみ」 | `hassan-v2-backend/db/schema.sql:1` = `CREATE EXTENSION IF NOT EXISTS "uuid-ossp";` | 一致 (参照リポ実測) |

**結論を左右した照合は #1** (D-I の却下理由の根拠) と **#14** (OIDC の信頼条件)。
**#1 が不一致だったため、D-I / questions.md / aidlc-state の 3 箇所に同じ主張が転記されていることを
全数確認した** (DR-1 の運用どおり load-bearing な事実を全数照合へ切り替えた)。

---

## ⑥ 頻出パターン DR-1〜DR-10 の全件判定

| # | 判定 | 根拠 |
|---|---|---|
| **DR-1** 出典なしの断定 | **該当 (中 3・重大 1)** | 出典は概ね付いている (D-I / MR-1〜MR-6 / §3.11.1 の各行に パス:行 または節番号がある)。しかし **①出典先の内容が主張と矛盾 (重大 1)** **②出典先が旧版で、現物は正反対 (中 3)** の 2 件。`make doc-lint` は実在しか見ないため両方すり抜ける |
| **DR-2** 本番観点の無言の省略 | **該当なし (回答は網羅されている)** | 影響のある ID (D-1 / D-2 / D-3 / D-5 / D-6 / D-7 / D-8) すべてに追随記述がある (⑦ の表)。**ただし D-2 / D-5 の回答内容に穴がある** (重大 2〜4) ので、「無言の省略」ではなく「回答の不備」として扱った |
| **DR-3** 既存データの不在 | **該当なし** | 本変更はスキーマ・データに触らない。**そう言えることを確認した**: `data-model.md` の差分は移行スクリプトの置き場を `app モノレポの backend/cmd/migrate-from-v2` に更新した 1 箇所のみ (`:1070`)。v2 → v3 の移行方針 (§6.2 / DM-A2) は無変更で、`make check-table-counts` の実測値 (42 + 12) も動いていない |
| **DR-4** PoC 実装のコピー設計 | **該当なし** | 本変更に PoC 由来の構造は無い。`§3.11.1` は逆に「既存の層設計 (L-1〜L-6 / D-2①〜⑨ / lint zone) をパス表記を変えずに保つ」ことを原則にしており、v2 規約からの逸脱が発生していない |
| **DR-5** 曖昧語による丸投げ | **該当なし** | §3.11 / §3.11.1 / §3.11.2 / §3.11.3 と `operations.md` §5.1.1 を `適切に` / `必要に応じて` / `後で検討` で grep して 0 件。MR-1〜MR-6 はいずれも「欠けると起きること」を具体的な失敗モードで書いている。未検証の前提は §3.11.2 末尾の「要確認」表 5 件に**明示的に隔離**されている (良い形) |
| **DR-6** AC の宙吊り | **該当 (中 4)** | `make check-traceability` は 24/24・86/86 で緑。**逆方向が抜けている** — MR-1 / MR-2 / MR-4 / MR-5 に対応する AC が無い。DR-6 が明記する「設計判断に対応する AC が無い場合も要件漏れ」の型。**また AC-2.2 / AC-2.3 / AC-5.1 / DF-3 は ID 据え置きで本文を改訂している** (下記の判定を参照) |
| **DR-7** プロトタイプを仕様として扱う | **該当なし** | 本変更はプロトタイプに一切依拠していない |
| **DR-8** 修正の波及漏れ | **該当 (重大 5・中 1・中 2・軽微 1〜3)** | **6 巡連続の再発**。状態語 (`未了` `未実装` `含まれていない` `是正要求` 等) と構成語 (`3 リポ` `3 分割` `別リポ` `backend リポ` `deploy.yml` 等) で `docs/` `aidlc-docs/` `templates/` `CLAUDE.md` `.claude/` を全文 grep し、ヒット全件を歴史的記述か取り残しかで判別した。**取り残し 6 件**: `frontend.md:1193`(重大 5) / `testing.md:869`(中 1) / `testing.md:223`(中 2) / `operations.md:797`(軽微 1) / `requirements.md:113`(軽微 2) / `construction-workflow/questions.md:3`(軽微 3)。**受信側**も確認した — `testing.md` §13.3 は #13 を消滅扱いにしたが **#2 を直しておらず、同一表内で矛盾**している (中 1)。`operations.md` §10.2 / §10.3 と `frontend.md` §16.2 の是正要求表は本変更に伴う状態変化が無い項目のみで、取り残しは無かった |
| **DR-9** 件数・集合サイズの転記 | **該当 (中 5・中 10・軽微 4)** | 機械照合に載った: 「**6 機構 MR-1〜MR-6**」(`check-monorepo-ci` ③。連番検査つき) / 「**issue テンプレート 3 本 × 必須 5 欄**」(②) / 「`gate` の needs 集合」(①)。**載っていない**: 「`ci.yml` の job **6 本**」「`deploy-backend.yml` の **6 ジョブ**」(3 箇所に転記。中 5) / 「IAM ロール **3 本**」(3 箇所。実際 4 = 中 10) / 「`make check` は **6 ゲート**」(実体 7 = 軽微 4) / 「**2 リポジトリ**」(構造語なので実害小)。**「検査 8 項目 (①〜⑧)」「故障注入 6 種」も無検査**だが、スクリプト自身のコメントと本文が同じ差分で動く距離にあるため実害は小さいと判断した |
| **DR-10** 構造変更が無償の担保を外す | **該当 (重大 2・重大 3・重大 4・中 6・中 8)** | **本変更から抽出された新パターンであり、起草側自身の変更に最も強く当たる**。起草側の 3 例 (MR-6 の順序 / path filter × 必須チェック / write 権限) はいずれも設計に反映済み。**本レビューで 4 例目〜8 例目を検出**した (下表) |

### AC-ID 据え置きでの本文改訂の妥当性 (指示された判定)

| AC / ID | 改訂内容 | 判定 |
|---|---|---|
| **AC-2.2** | 「リポ跨ぎ / サブツリー跨ぎの issue 分割とマージ順序が**定義されていること**」に「後方互換な FE/BE 跨ぎは 1 issue = 1 PR に統合可 / 破壊的 3 段は別 PR 必須 = MR-6」を追記 | **ID 据え置きは妥当**。AC の受入形 (「〜が定義されていること」) は不変で、**定義すべき内容が増えた**だけ。改訂日を本文に併記しており追跡可能。ただし **MR-6 という新しい規範を既存 AC に相乗りさせた**結果、MR-1 / MR-2 / MR-4 / MR-5 が AC を持たない偏りが生じている (中 4 で AC 新設を提案) |
| **AC-2.3** | issue テンプレートの必須 5 欄は不変。実体が 2 本 (`task-backend` / `task-frontend`) + infra 1 本に再編 | **妥当**。受入基準の意味が変わっていない (欄の集合が正)。`check-monorepo-ci` ② が 3 本 × 5 欄を機械照合しており、据え置きが安全側 |
| **AC-5.1** | 「3 リポで一貫」→「app モノレポ (2 サブツリー) と infra リポで一貫」 | **妥当** (対象集合の読み替えで、要求内容は同じ)。ただし本文末尾の「同じ規約を **3 箇所**に複製しない」が未修正 (軽微 2) |
| **DF-3** | 「2 リポ共通のループ規約は `templates/shared/` に置く。**コピー先は 3 → 2 に減ったが仕組みは残る**」 | **妥当**。変更前後の関係を明記した良い形 (DR-8 の受信側の書き方の実例) |

### DR-10 の 4 例目以降 (本レビューで検出)

| # | 3 リポ構成が無償で担保していた性質 | モノレポで消える理由 | 代替機構の有無 | 本レビューの指摘 |
|---|---|---|---|---|
| **④** | **IAM 信頼条件の `repo:` クレームによる権限分離** — FE リポのワークフローは BE の deploy / migration ロールを引き受けられなかった | `sub` の `repo:` が 1 つになる。残る分離軸 `environment:` は **e2e と release が `dev` を共有**しているため機能しない | **無し** (信頼条件の記述が設計に 0 件) | **重大 4** |
| **⑤** | **必須ステータスチェックの厳格さがリポジトリ設定側にあった** — 個別ジョブ名をブランチ保護に登録していれば、PR では緩められなかった | `gate` 1 本に集約した結果、**何を集約するかが `ci.yml` (= PR で変更できるコード) に移った**。`needs` から 1 本抜けば緑のまま検査が消える | 設計リポの `check-monorepo-ci` ① のみ。**実装リポには無く、引き渡し項目にもない** | **重大 2** |
| **⑥** | **検査スクリプトが利用側リポに同居していた** — 各リポの CI が自分の `scripts/` を必ず実行していた | 検査を root `scripts/` に集約し、path filter で **`scripts/**` は `meta` (構文検査のみ) しか起動しない**。検査を空にする PR が `gate` 緑で通る | **無し** | **重大 3** |
| **⑦** | **`production` ブランチが FE リポにしか存在しなかった** — 「production = 本番のコード」が成立していた | app モノレポの `production` は **`backend/` を含むが、そのコードはどこにもデプロイされない**。「本番の BE は `main` の手動 dispatch」との非対称が見えなくなる | 部分的 (§7.1 の「backend に production を作らない」は 3 リポ時代の言い方で、モノレポでは意味が変わる) | **中 6** |
| **⑧** | **依存更新の単位がリポ = エコシステムと 1 対 1 だった** | モノレポでは Dependabot の version updates が `directory:` の明示宣言を要する。宣言が無いと**更新 PR が静かに止まる** (alerts は残る) | **無し** (`dependabot.yml` は雛形に無く、設計文書に依存更新の記述が 0 件) | **中 8** |

**検討したが「担保の喪失ではない」と判断したもの** (カバレッジの正直さのため列挙):

- **Actions の同時実行数 / 課金**: 上限はアカウント単位であり、リポジトリ分割で変わらない。
  CI の wall clock も同一ワークフロー内のジョブは並列に走るため加算にならない (`gate` の待ちのみ +1 段)
- **secret scanning / push protection の範囲**: リポジトリ設定で同等のものを 1 セット張るだけ。分割で得ていた性質は無い
- **リリースノート / タグの単位**: **MR-5 (タグ名前空間 + タグ保護ルール) で代替済み**
- **クローンサイズ / チェックアウト時間**: 実害が小さく、`fetch-depth` の調整で足りる
- **`git blame` / `git log` の分離**: 実害は「サブツリーを跨ぐコミットが混ざる」ことのみ。
  ただし **DR-10 自身が「MR-4 の行に列挙せよ」と定めている**ため、記述漏れとして中 8 に含めた

---

## ⑦ 本番ゲート A-1〜A-7 / O-1〜O-7 / D-1〜D-8 の影響判定

**判定の意味**: 「**変わる**」= 本変更で回答内容が変わる ID / 「**変わらない**」= 回答は不変
(パス表記の更新のみを含む) / 追随欄は設計文書が実際に追随しているか。

| ID | 本変更で回答が変わるか | 追随 | 箇所・確認内容 |
|---|---|---|---|
| **A-1** 認証方式 | 変わらない | — | `auth.md` §6.1 はリポ構成に非依存。本変更の差分に認証の記述変更は無い (確認済み) |
| **A-2** ロール | 変わらない | — | 同上 (`auth.md` §6.2) |
| **A-3** テナント境界 | 変わらない | ✓ | **変わらないことを確認した**: `data-model.md` の差分は移行スクリプトの置き場 1 箇所のみ。`make check-table-counts` の実測 (機能テーブル 42 / 例外 12 / 分類 ①31②2③1) は本変更前と同値 |
| **A-4** 絞り込みの層 | 変わらない (実行場所のみ変わる) | ✓ | CI 検査 `D-2①`〜`⑨` は `working-directory: backend` で従来のパス表記のまま有効 (§3.11.1)。`check-monorepo-ci` ⑥ が `targets` ↔ `.golangci.yml` の L3 `files` を機械照合しており、モノレポ化で対象集合がずれる経路を塞いでいる |
| **A-5** ステータスコード | 変わらない | — | `API/README.md` §2.5 / `auth.md` §6.6 に差分なし |
| **A-6** LLM の越境 | 変わらない | — | §3.8.2 の担保 (Runner が他ドメインを import しない = パッケージ依存で越境経路が無い) は**サブツリー自己完結でモジュールパスが不変**のため成立が保たれる (§3.11.1) |
| **A-7** 共有・公開 | 変わらない | — | `auth.md` / `API/idea-boards.md` に差分なし |
| **O-1** 構造化ログ | 変わらない | — | `observability.md` §4.1 に差分なし |
| **O-2** LLM 計測 | 変わらない | — | 同 §4.2。gateway 単一関門の設計はサブツリー内に閉じる |
| **O-3** コスト上限 | 変わらない | — | 同 §4.4 / C-12 |
| **O-4** 失敗の可観測性 | 変わらない | — | 同 §4.3 |
| **O-5** SSE | 変わらない | — | ALB / keep-alive はインフラ側の設計で、リポ構成に非依存 |
| **O-6** 監査ログ | 変わらない | — | 同 §4.5 |
| **O-7** アラート | 変わらない | — | 同 §4.6 / `operations.md` §7.5。**CI 由来の通知 (gate 失敗・E2E 赤) は変更前後とも O-7 の対象外** — 本変更で悪化していないため指摘には含めない |
| **D-1** 環境 | **変わる** | **部分** | FE (Vercel) / BE (AWS) の 2 系統という構造は不変 (`operations.md` §3.2 / `infrastructure.md` §5.3 = SSOT)。**モノレポで変わったのは 3 点**: ①FE と BE が**同一 commit** になった (E2E の検証対象が 1 SHA で一意 = `testing.md` §7.4 の緩和策 2 が構造的に成立) ②Vercel が Root Directory + Ignored Build Step を要する (MR-2) ③**`production` ブランチが backend コードを含むようになった** → **③が未追随 (中 6)** |
| **D-2** CI ゲート | **変わる** | **部分** | マージ条件は「`gate` 1 本が緑」に集約 (`architecture.md` §3.11.2 MR-1 / `04` §4.1 / `01-construction-loop.md` §7)。**「マージ条件を設計時点で決める」は満たしている** (必須チェック名・skip 許容条件・確認手順 3 通りまで書かれている)。**ただし厳格さの担保が壊れている**: gate の中身が PR で緩められ (**重大 2**)、検査スクリプトを無力化する PR が緑で通る (**重大 3**) |
| **D-3** デプロイ手順 | **変わる** | **部分** | FE/BE のリリース順序は `operations.md` §5.4 に追随済み (後方互換は同梱可 / 破壊的 3 段は別 PR = MR-6)。ロールバックは `rollback-backend.yml` に改名して整合。**infra→app の受け渡し (tfstate) の記述が D-I と §4.2 で矛盾 (重大 1)**。**③の順序判定に必要な「prod に載っている BE commit」を知る手段が無い** (中 6 / T-Q10) |
| **D-4** マイグレーション | 変わらない | ✓ | `operations.md` §7.4 / `data-model.md` §6。`apply_migration` の RunTask 経路はリポ構成に非依存。パスが `backend/` 配下になった追随は済み |
| **D-5** シークレット | **変わる** | **部分** | **`E2E_DISPATCH_TOKEN` の廃止で §4.1 の限定列挙が「例外ゼロ件」に戻ったという主張は妥当** (照合 #8。`e2e.yml` は OIDC + Secrets Manager で、GitHub 側に置くのはロール ARN のみ)。**ただし OIDC の信頼条件が未設計で、リポ境界による権限分離が消えている (重大 4)**。E2E 用ロールが INF-I に無い (中 10) |
| **D-6** Agent ライフサイクル | **変わる (軽微)** | ✓ | `deploy-backend.yml` の `on.push.paths` が `backend/**` + `api/**` を含むため、`backend/prompts/agents.yaml` の変更で再発行フローが起動する (実物で確認)。`check-monorepo-ci` ⑤ が `deploy` の `paths` ⊆ `ci.yml` の filter を機械照合しており、「CI が見ていない変更でデプロイが走る」経路を塞いでいる |
| **D-7** 段階リリース | 変わらない | ✓ | §7.3 の 4 段 (workflow_dispatch / environment 承認 / フラグ既定 false / H-4 の確認観点) は BE 側で不変。**「開発環境の未リリース変更を本番に出さない仕組み」はモノレポで変わらない**が、**FE 側は `production` への PR 経路が残る** (中 7) — これは変更前 (3 リポ) も同じ穴だったため「本変更で悪化した」ではなく「モノレポの立ち上げチェックリストで設定できないと明記された項目」として中に置いた |
| **D-8** IaC の管理範囲 | **変わる** | **部分** | X-3 (ECS サービス定義) / X-4 (Agent) の管理主体を「app モノレポ」に更新済み。Terraform / ecspresso の線 (§4.1) は不変。**tfstate 連携を「契約が無い」と述べた D-I の記述が §4.2 と矛盾 (重大 1)** |

**DR-2 (無言の省略) の判定**: **無し**。影響のある 7 ID すべてに追随記述が存在する。
ただし D-2 / D-3 / D-5 / D-8 は**回答の内容に上記の欠陥**があるため「部分」とした。

---

## ⑧ 良かった点

1. **DR-10 という新パターンを、自分の変更から抽出して SSOT に登録している** — 「構造変更が無償で成立していた
   担保を外す」は本リポジトリで最も再現性の高い欠陥類型で、`feedback_review_patterns.md:28` に
   **検出法 (「この性質は機構が守っているのか、構造の副産物だったのか」を性質ごとに問う) と
   代償欄への明記**まで書かれている。本レビューが 4 例目〜8 例目を機械的に探せたのは、この記述があったため
2. **§3.11.1「サブツリー自己完結」が既存資産の無変更性を証明する形で書かれている** — depguard L-1〜L-6 /
   `D-2①`〜`⑨` の `targets` / `layering-scopes.yml` / `frontend.md` §3.3 の lint zone / `STRUCTURE.md` の
   パス表を 1 つずつ「なぜパス表記を変えずに済むか」で示しており、**大規模な構造変更で
   「既に確定した設計を作り直さない」ことを担保している**。`turborepo / nx を導入しない` の却下理由も明快
3. **MR-1 の失敗モードが「なぜ危険か」まで書かれている** — 「skip されたジョブは status を返さないため
   必須チェックが永久 pending になる」は実際に踏むまで気付けない罠で、
   **立ち上げチェックリストに「3 通りの PR で挙動を確認する」まで落ちている** (04 §4.1)
4. **未検証の前提を「要確認」表 5 件に隔離している** (`architecture.md` §3.11.2 末尾) —
   GitHub / Vercel / vitest の実挙動を推測で断定せず、**外れた場合の影響**まで書いている。
   `07-quality-protocols.md` の「『同等』『存在しない』は検証済み主張としてのみ書く」に忠実
5. **前巡レビューの是正が、設計文書側にも高い精度で反映されている** —
   MR-3 (`check-regen.sh`) / MR-4 (write 権限の代償) / MR-5 (タグ保護ルール) / `meta` ジョブ / `on` の絞り込みは
   いずれも**実物と設計文書の両方**で確認できた (照合 #9 #12 #13)。取り残しは `frontend.md` 1 ファイルに集中している
6. **`check-monorepo-ci.sh` が「ファイルが無いときにスキップして緑にしない」を明示的に実装している**
   (`:56`〜`:63`) — DR-6 の「検査が対象 0 件を検査して緑になる」形を構造的に避けており、
   `check-table-counts.sh` と方針が揃っている

---

## ⑨ 要確認 (本レビューで確信が持てなかった項目)

1. **GitHub のブランチ保護 / ruleset に「PR の head ブランチを制限する」設定は存在しないと理解している**が、
   2026-08 時点の最新仕様を実機で確認していない (中 7 の前提)。存在するなら中 7 は「設定項目名を書く」だけで解決する
2. **Dependabot alerts が monorepo のサブディレクトリ manifest を自動検出する**という理解は一般論であり、
   本プロジェクトの GitHub プラン (GHAS の有無) で挙動が変わり得る (中 8)。
   **3 リポ時代に dependabot 設定が存在したかは確認できていない** (雛形に `dependabot.yml` が無いため、
   「担保が消えた」ではなく「モノレポでは明示設定が必須になった」と書いた)
3. **IAM の信頼条件の実装形 (`environment:` 条件が推奨か `ref:` 条件が推奨か)** は、
   E2E を dev の Preview に対して走らせる運用と合わせて実機検証が必要 (重大 4 の修正案の選択)
4. **調べていない範囲**: ①`templates/app-monorepo/` 配下のワークフロー・スクリプトの**実装の正しさ**
   (別レビュアー担当。本レビューは「設計文書の記述が実物と一致するか」の照合にのみ使った)
   ②`docs/design/API/{conversation,ideas,plans}.md` と `機能一覧.md` (別セッションの並行作業。
   ただし `docs/design/README.md` §5 の「API/*.md (**7 ファイル**)」「約 12,000 行」「18 ファイル」は
   同増分で 10 ファイルに増えているため、**DR-9 の観点で別途照合が必要**と思われる — 本変更由来ではないため
   指摘には含めていない) ③`aidlc-docs/reviews/` 配下の既存レビュー文書の内容
5. **`operations.md` §6.1 の RL-0 完了条件④** に立ち上げチェックリストが列挙されているが、
   ここに列挙された項目 (gate 必須チェック / Vercel の 2 設定 / CODEOWNERS) と
   `04` §4.1〜§4.4 のチェックリスト本体との**件数の対応は機械照合されていない**。
   中 5 の是正に含めるか、RL-0 側を「04 §4 の全項目」への参照にするかを起草側で選ぶ必要がある

---

**再レビューの依頼時の観点**: 重大 1〜5 の是正は**いずれも「文書を直す」だけでは閉じない** —
重大 2 / 3 は雛形への機構追加、重大 4 は `infrastructure.md` への信頼条件の新設が必要。
**是正後は「機構を足した」で終わらせず、足した検査を故障注入で殴った記録**
(`05-harness.md` の方針) をレビュー依頼に添えること。
