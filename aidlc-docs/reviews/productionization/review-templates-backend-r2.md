# レビュー (2 巡目): backend 雛形の骨格追加 + rules 切り出し

レビュー対象: **`git diff 6bdf7ef..HEAD`** (コミット **`0448a12`** + **`4afd59b`** = `origin/main..HEAD`)。
1 巡目 [review-templates-backend.md](review-templates-backend.md) は `0448a12` 単独を対象にしており、
本ファイルはその**指摘 16 件の解消判定** + **`4afd59b` の新規レビュー**を行う。
判定は本番基準 (`.claude/rules/08-production-gates.md`。「PoC では対象外」を省略理由と認めない)。

## レビュー結果サマリ

- **重大 5 件 (継続 4 / 新規 1) / 中 9 件 (継続 5 / 新規 4) / 軽微 10 件 (継続 6 / 部分解消 1 / 新規 3)**
- 1 巡目の指摘 16 件のうち **解消 0 件 / 部分解消 1 件 (軽微 7) / 未解消 15 件** (うち 4 件は**該当箇所が移動しただけ**)
- 実行した検証: `make check` (エラー 0 / 警告 43) / 一次ソースの抜き取り照合 **9 件** (うち 4 件は 1 巡目の
  load-bearing な事実の再照合。**「0 件」の事実誤りを再現し、未解消であることを確認**)
- **`4afd59b` の本体 (規約本文の切り出し) は逐語移動であることを機械照合済み** —
  削除 329 行と新ファイル本文 331 行の差分は「節見出し 2 行」のみ (下記照合 #9)。
  **したがって 1 巡目が本文に対して出した指摘 (中 3 / 軽微 4) は移動先でそのまま有効**

### レビュー対象ファイル (リポジトリ相対パス。全 53 件)

```
docs/design/llm-migration.md
templates/README.md
templates/app-monorepo/backend/.claude/agents/go-developer.md
templates/app-monorepo/backend/.claude/rules/05-architecture-coding-rules.md
templates/app-monorepo/backend/CLAUDE.md.tmpl
templates/app-monorepo/backend/STRUCTURE.md
templates/app-monorepo/backend/layering-scopes.yml
templates/app-monorepo/backend/prompts/agents.yaml
templates/app-monorepo/frontend/CLAUDE.md.tmpl
templates/infra-repo/.claude/agents/infra-reviewer.md
templates/shared/.claude/rules/feedback_review_patterns.md
templates/app-monorepo/backend/common/auth/.gitkeep
templates/app-monorepo/backend/common/config/.gitkeep
templates/app-monorepo/backend/common/constants/.gitkeep
templates/app-monorepo/backend/common/di/.gitkeep
templates/app-monorepo/backend/common/logger/.gitkeep
templates/app-monorepo/backend/common/router/.gitkeep
templates/app-monorepo/backend/controller/.gitkeep
templates/app-monorepo/backend/controller/dto/.gitkeep
templates/app-monorepo/backend/db/queries/asset/.gitkeep
templates/app-monorepo/backend/db/queries/conversation/.gitkeep
templates/app-monorepo/backend/db/queries/idea/.gitkeep
templates/app-monorepo/backend/db/queries/plan/.gitkeep
templates/app-monorepo/backend/db/queries/theme/.gitkeep
templates/app-monorepo/backend/db/rdb/.gitkeep
templates/app-monorepo/backend/entity/.gitkeep
templates/app-monorepo/backend/entity/toolresult/.gitkeep
templates/app-monorepo/backend/env/.gitkeep
templates/app-monorepo/backend/gateway/anthropic/.gitkeep
templates/app-monorepo/backend/gateway/exa/.gitkeep
templates/app-monorepo/backend/gateway/gemini/.gitkeep
templates/app-monorepo/backend/gateway/mail/.gitkeep
templates/app-monorepo/backend/gateway/s3/.gitkeep
templates/app-monorepo/backend/prompts/asset/.gitkeep
templates/app-monorepo/backend/prompts/conversation/.gitkeep
templates/app-monorepo/backend/prompts/idea/.gitkeep
templates/app-monorepo/backend/prompts/plan/.gitkeep
templates/app-monorepo/backend/repository/asset/.gitkeep
templates/app-monorepo/backend/repository/conversation/.gitkeep
templates/app-monorepo/backend/repository/idea/.gitkeep
templates/app-monorepo/backend/repository/plan/.gitkeep
templates/app-monorepo/backend/repository/theme/.gitkeep
templates/app-monorepo/backend/service/asset/.gitkeep
templates/app-monorepo/backend/service/conversation/.gitkeep
templates/app-monorepo/backend/service/idea/.gitkeep
templates/app-monorepo/backend/service/plan/.gitkeep
templates/app-monorepo/backend/service/theme/.gitkeep
templates/app-monorepo/backend/testdata/golden/toolresult/.gitkeep
templates/app-monorepo/backend/usecase/asset/.gitkeep
templates/app-monorepo/backend/usecase/conversation/.gitkeep
templates/app-monorepo/backend/usecase/idea/.gitkeep
templates/app-monorepo/backend/usecase/plan/.gitkeep
templates/app-monorepo/backend/usecase/theme/.gitkeep
```

### 重要な前提: 是正の一部は**未コミットのワーキングツリーにしか存在しない**

1 巡目の是正状況表は 重大 2 を「実施済み」・重大 1 を「一部実施」と記録しているが、**その是正は
`docs/design/architecture.md` の未コミット差分** (`git diff --stat HEAD -- docs/design/architecture.md`
= 103 insertions / 11 deletions) であり、**`origin/main..HEAD` (= push される内容) には入っていない**。

```
$ git show HEAD:docs/design/architecture.md | grep -c "common/"        → 0
$ git show HEAD:docs/design/architecture.md | grep -c "controller/dto" → 0
```

したがって**このまま push すると**、remote は次の状態になる:

- `templates/app-monorepo/backend/layering-scopes.yml:52` が「`architecture.md` §3.5.1 の `common/` の決定」を参照するが、
  **その決定は push される `architecture.md` に存在しない** (重大 2 の状態のまま)
- `templates/app-monorepo/backend/STRUCTURE.md:111` の「v2 実測 0 件」(事実誤り) と
  `.claude/rules/05-architecture-coding-rules.md:90`〜`:96` の DTO 規約が push されるが、
  **その規約の設計 SSOT (`architecture.md` §3.3 の DTO 節) は push されない** (重大 1 の状態のまま)

**push するなら `docs/design/architecture.md` の是正差分を同じ push に含めること**。
含めるなら `STRUCTURE.md:111` の「0 件」削除も同じコミットに入れる (重大 1)。

### 実行した検証 (出力)

```
$ make check
[doc-lint] 対象 108 ファイル / エラー 0 件 / 警告 43 件
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 86/86 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
[workflow-shell] 検査 52 ブロック / エラー 0 件
[table-counts] 実測: 機能テーブル 42 (個人 34 / 契約 8) / 分類 ①31 ②2 ③1
[table-counts] 実測: 機能テーブル以外 12 (所有者列なし 7 / 所有者列あり 5) / 検査①の除外リスト 9
[table-counts] 照合 37 件 / エラー 0 件
[endpoint-mapping] 実測: auth-accounts.md 37 本 / 9 ドメイン 112 本 / settings.md §5 18 行 / custom tool 8 本 / 403 16 本
[endpoint-mapping] 照合 36 件 / エラー 0 件
```

- 対象ファイルは 1 巡目の 106 → **108** (`+2` = `templates/app-monorepo/backend/.claude/rules/05-architecture-coding-rules.md`
  と `templates/shared/.claude/rules/feedback_review_patterns.md`。**どちらも `.md` なので doc-lint の対象に入った** —
  1 巡目 軽微 7 の部分解消)
- 警告 43 件はすべて既存 + 1 巡目 review.md 自身の「TODO」語 3 件。**エラー 0 件**
- **`make check` は本レビューの指摘を 1 件も検出していない** — 件数の整合 (`check-table-counts` /
  `check-endpoint-mapping`) は `templates/` を走査対象に含まないため (中 4 / 重大 5 の根拠)
- **本ファイル保存後の再実行**: `[doc-lint] 対象 109 ファイル / エラー 0 件 / 警告 45 件`。
  増分 2 件は本ファイル自身が「TODO」の語を引用していることへの反応のみで、対象成果物由来のものは無い

### 抜き取り照合 (9 件)

| # | 主張 (出典) | 照合コマンド | 結果 |
|---|---|---|---|
| 1 | **v2 実測: `usecase/` → `controller/dto` の import は 0 件** (`templates/app-monorepo/backend/STRUCTURE.md:111`) | `grep -rl "controller/dto" usecase/ \| wc -l` → **29** / 非テスト **27** / `usecase/asset/list_assets.go:7` に実在 | **誤り (重大 1 継続)** |
| 2 | v2 は `service/` 追加レイヤーを明示禁止 (`05-architecture-coding-rules.md:35` = `hassan-v2-backend/CLAUDE.md:39`) | `sed -n '36,42p' CLAUDE.md` | **一致** (`:39` = 「**禁止**: … (`internal/`/`service/` 追加レイヤー)」) |
| 3 | `usecase/idea/web_search.go` が 1381 行 (同 `:36`) | `wc -l usecase/idea/web_search.go` → **1381** | **一致** |
| 4 | v2 の非テストコードに `fmt.Errorf` が 113 件 (同 `:227`) | `grep -rn "fmt.Errorf" --include='*.go' . \| grep -v _test.go \| wc -l` → **113** | **一致** |
| 5 | `L1-usecase-no-controller` の deny が `<module-path>/controller` (前方一致で `controller/dto` を含む) | `templates/app-monorepo/backend/.golangci.yml:150-156` | **一致** (重大 1 の帰結 2 が成立) |
| 6 | 設計 SSOT に `common/` の決定がある (`layering-scopes.yml:52` / `STRUCTURE.md:57-58`) | `git show HEAD:docs/design/architecture.md \| grep "common/"` → **0 件** (worktree は `:282`〜`:293` に決定あり・未コミット) | **HEAD では不在 (重大 2 継続)** |
| 7 | `env/<env>.env` のキー集合を CI で照合する (`05-architecture-coding-rules.md:247`) | `grep -n "env/\|\.env\|check-env\|secret" templates/app-monorepo/.github/workflows/ci.yml` → **0 件** | **機構なし (重大 3 継続)** |
| 8 | `templates/shared/.claude/rules/feedback_review_patterns.md` は SSOT の同期コピー (`templates/README.md:18-22`) | `diff <(git show HEAD:.claude/rules/feedback_review_patterns.md) templates/shared/.claude/rules/feedback_review_patterns.md` → **DR-6 / DR-9 の 2 行が相違** | **HEAD でドリフト (重大 5 新規)** |
| 9 | `4afd59b` の規約移動は内容改変なし | 削除行 (329) と `05-architecture-coding-rules.md:22-353` (331) を `diff` → 差分は節見出し 2 行のみ | **逐語移動 (中 3 / 軽微 4 は移動先で有効)** |

---

## 1 巡目の指摘 16 件の解消判定

| 1 巡目の指摘 | 判定 | 根拠 (現在の file:line) |
|---|---|---|
| **重大 1** 「v2 実測 0 件」が事実誤り | **未解消** | `templates/app-monorepo/backend/STRUCTURE.md:111` に「0 件」が残存 (照合 #1 で再現)。`architecture.md` 側の訂正は**未コミット** (`:180`〜`:198`)。移植分の depguard 扱いも `templates/app-monorepo/backend/.golangci.yml:150-156` は未変更 |
| **重大 2** `common/` が設計 SSOT に無い | **未解消 (HEAD)** | `git show HEAD:docs/design/architecture.md` に `common/` が **0 件** (照合 #6)。worktree の是正 (`:282`〜`:293`) が push レンジ外。`layering-scopes.yml:52` / `STRUCTURE.md:57-58` が存在しない決定を参照する状態で push される |
| **重大 3** env キー集合照合 CI が無い (D-5) | **未解消** | `templates/app-monorepo/.github/workflows/ci.yml` に env 関連ステップ 0 件 (照合 #7)。要求元は `4afd59b` で `CLAUDE.md.tmpl:257` → **`05-architecture-coding-rules.md:247` に移動しただけ** |
| **重大 4** 立ち上げ手順に骨格が無い | **未解消 + 悪化** | `templates/README.md:26-35` のコピー対象は依然 4 + shared 2 のみ (骨格 / `STRUCTURE.md` / `.golangci.yml` / `layering-scopes.yml` / `prompts/agents.yaml` は無い)。**加えて `CLAUDE.md.tmpl` から `STRUCTURE.md` への参照が移動で消滅** — HEAD で `STRUCTURE.md` を参照するのは `05-architecture-coding-rules.md:96` と `layering-scopes.yml:50` の 2 件だけになり、**実装リポの入口 (`CLAUDE.md`) からは到達できない**。`docs/design/architecture.md:919` の引き渡し行も未更新 (新設の `rules/05` も未記載) |
| **中 1** `agents.yaml` の `tools: []` が無言で緑 (BE-9) | **未解消** | `templates/app-monorepo/backend/prompts/agents.yaml` は `4afd59b` で未変更 |
| **中 2** `D-2⑦` の適用範囲を過大に記述 | **未解消 (行番号が移動)** | `STRUCTURE.md:9` / **`:127-128`** (旧 `:120-121`。`db/queries/` を含め、右辺が `v3_domains` のみ) / **`:197`** (旧 `:191`) |
| **中 3** env の①インフラ由来/②アプリ由来の二分が潰れている (D-1) | **未解消 (逐語移動)** | 旧 `CLAUDE.md.tmpl:257` → **`05-architecture-coding-rules.md:244`**。設計 (`docs/design/operations.md:118`) の 2 分類と `APP_ENV` の例外が落ちたまま。`STRUCTURE.md:48` の `env/` 行も「アプリ由来のみ」の明記なし |
| **中 4** §5 のエンドポイント本数が検算対象外 (DR-9) | **未解消** | `STRUCTURE.md:202-205` に 15 / 18 / 5 / 6 / 37 が残存。`grep -c templates scripts/check-endpoint-mapping.sh` → **0** (走査対象外) |
| **中 5** DTO / バリデーションが 3 重管理 | **未解消 (宣言先だけ差し替え)** | `STRUCTURE.md:5` の「本文は…に持たせてある。同じ表を二重に持たない」の参照先が `CLAUDE.md` → `.claude/rules/05-architecture-coding-rules.md` に変わっただけ。実体は依然 3 箇所 (`STRUCTURE.md:96-124` / `05-architecture-coding-rules.md:90-104` / `architecture.md:167-215` (未コミット)) |
| **軽微 1** ツリーに `sqlc.yaml` / `.dockerignore` / `.env.example` が無い | **未解消** | `STRUCTURE.md:18-19` に `.golangci.yml` / `layering-scopes.yml` はあるが 3 ファイルは無い (`grep -n "sqlc.yaml\|dockerignore\|env.example"` は §4 の本文ヒットのみ) |
| **軽微 2** `env/<env>.env` の実ファイル名形が未確定 | **未解消** | `STRUCTURE.md:48` |
| **軽微 3** `common/logger/` の「v2 踏襲」が条件を落とす | **未解消** | `STRUCTURE.md:29` (「構造化ログ (v2 踏襲。O-1)」。`observability.md:444` の「登録条件は踏襲しない」が落ちている) |
| **軽微 4** `IdeaBoard.CanEdit` に パス:行 が無い (DR-1) | **未解消 (逐語移動)** | 旧 `CLAUDE.md.tmpl:136` → **`05-architecture-coding-rules.md:123`** |
| **軽微 5** `common_layers` が実質 no-op | **未解消** | `layering-scopes.yml:49-56` (注記は整理されたが、リストの発火条件は書かれていない) |
| **軽微 6** ツリーの `CLAUDE.md.tmpl` 行 | **未解消** | `STRUCTURE.md:20` |
| **軽微 7** `CLAUDE.md.tmpl` が doc-lint 対象外 | **部分解消** | 規約本文が `.md` (`05-architecture-coding-rules.md`) へ移り、**doc-lint の対象になった** (対象 106 → 108)。`CLAUDE.md.tmpl` 自体は依然対象外 |

---

## 重大 (Must Fix)

### 重大 5 (新規). `templates/shared/.claude/rules/feedback_review_patterns.md` は「同期コピー」として作られたが、**HEAD 時点で既に SSOT より新しく**、同期を担保する機械検査が無い

**事実**: `4afd59b` は `templates/shared/.claude/rules/feedback_review_patterns.md` (69 行) を新設し、
`templates/README.md:18-22` で

> **SSOT は設計リポ直下の `.claude/rules/feedback_review_patterns.md`** — …はその同期コピー。
> **設計リポ側で本ファイルを更新したら、同じ差分で `templates/shared/` 側にも … 追随させる**
> (忘れると shared 経由で立ち上げた実装リポが古いパターンのままになる)

と規定した。しかし **push される HEAD では、その関係が逆向きに破れている**:

```
$ diff <(git show HEAD:.claude/rules/feedback_review_patterns.md) \
       templates/shared/.claude/rules/feedback_review_patterns.md
24c24  (DR-6)  ← コピー側だけが「検査が『対象 0 件』を検査して緑になる形に注意 (2026-08-02 追加)」を持つ
27c27  (DR-9)  ← コピー側だけが「『影響範囲は N ファイル・N 箇所』型の数値も同じ (2026-08-02 追加)」を持つ
$ diff .claude/rules/feedback_review_patterns.md templates/shared/.claude/rules/feedback_review_patterns.md
(差分なし — コピーは **未コミットのワーキングツリー**から作られている)
```

つまり **SSOT 側の更新が未コミットのまま、コピーだけがコミットされた**。

**なぜ本番で問題になるか**:

1. **この push で remote は「SSOT (69 行) が古く、コピーが新しい」状態になる**。次に誰かが README の手順どおり
   「SSOT を編集 → `cp` でコピーに反映」すると、**コピー側にしか無い 2026-08-02 の追記 (DR-6 の
   「検査が対象 0 件を検査して緑になる」・DR-9 の「数えた値ではなく再現コマンドを書く」) が消える**。
   この 2 件は**このリポジトリで実際に発生した検査すり抜けの再発防止策**であり、失うと同型の穴が戻る
2. **同期義務が文章だけで、`make check` に入っていない**。`grep -rn "shared" scripts/*.sh` は **0 件**で、
   doc-lint も 2 ファイルの同一性を見ない。本ファイルは直近 1 週間で複数回更新されており、
   **ドリフトは「起こり得る」ではなく「導入コミットで既に起きている」**
3. **DR-9 の自己適用違反**: 同ファイル自身が「レビュー観点に置かず**機械強制する**」「新しく『N 件』を書くときは
   検算の対象に加えるか、書かずに定義元へのリンクにする」と定めている。**内容の丸ごとコピーは
   件数の転記より強い二重管理**であり、同じ基準なら機械強制が要る

**是正案** (どれも 1 行〜数行):

- **(a) SSOT の未コミット差分を同じ push に含める** (最優先。これをしないとドリフトを remote に出す)
- **(b) `make check` に同一性検査を追加する** — 例:
  ```bash
  diff -q .claude/rules/feedback_review_patterns.md \
          templates/shared/.claude/rules/feedback_review_patterns.md \
    || { echo "[sync] feedback_review_patterns.md が templates/shared/ と一致しません"; exit 1; }
  ```
  `scripts/doc-lint.sh` 末尾か新規 `scripts/check-template-sync.sh` に置き、**故障注入 (コピー側の 1 行を改変して
  `exit 1` になること) で検出力を確認する** (`05-harness.md` の「足した検査自体を故障注入で殴る」)
- **(c) コピー側の冒頭に「本ファイルは同期コピー。SSOT は設計リポ `.claude/rules/feedback_review_patterns.md`」の
  1 行を入れる** — 現状はコピーの冒頭が「**このファイルが頻出パターンの単一の正 (SSOT)**」と自称しており
  (中 8 参照)、コピーを直接編集する動機を作っている

### 重大 1〜4 (継続)

内容と是正案は 1 巡目 [review-templates-backend.md](review-templates-backend.md) の該当節が正 (再掲しない)。
**2 巡目で追加された事実**のみ記す:

- **重大 1**: `templates/app-monorepo/backend/.golangci.yml:150-156` を実測し、`deny.pkg: "<module-path>/controller"` が
  `files: "**/usecase/**"` 全体に掛かることを確認した (照合 #5)。**移植分 27 ファイルが lint で落ちる**という
  1 巡目の帰結は、雛形の実物で成立している。加えて **HEAD には `architecture.md` の DTO 節自体が無い** ため、
  雛形が「(v2 踏襲)」として配る規約に**設計 SSOT が存在しない**状態で push されようとしている
- **重大 2**: `layering-scopes.yml:52` が新たに「(`architecture.md` §3.5.1 の `common/` の決定)」を参照するように
  なった (`0448a12`)。**HEAD の `architecture.md` にその決定が無い**ため、**雛形 → 設計への参照が宛先不明**になる。
  `make doc-lint` はこれを検出しない (`.yml` のコメント内参照であり、節番号の実在は検査対象外)
- **重大 4**: 上表のとおり**悪化**した。`4afd59b` が `CLAUDE.md.tmpl` から `STRUCTURE.md` への唯一の参照を
  移動で失わせたため、**実装リポの入口から骨格の索引に辿る経路が無い**。
  是正時は `templates/README.md` の手順に加えて **`CLAUDE.md.tmpl` の「アーキテクチャ」節に
  `STRUCTURE.md` へのポインタを 1 行残す**こと

---

## 中 (Should Fix)

### 中 6 (新規). 圧縮後の `CLAUDE.md.tmpl:40` が、`rules/05` が明示的に禁じた直列表記を「要点」として再導入している

**事実**:

| 場所 | 記述 |
|---|---|
| `templates/app-monorepo/backend/CLAUDE.md.tmpl:40`〜`:41` (本コミットで新規) | 「要点だけ: Clean Architecture 4 層 (**Controller → UseCase → Service → Repository**) + `entity/` + `gateway/` の計 6 パッケージ層」 |
| `templates/app-monorepo/backend/.claude/rules/05-architecture-coding-rules.md:70`〜`:71` | 「**`usecase` は `repository` / `gateway` の具体パッケージに依存しない**。「Controller → UseCase → Service → Repository」の直列図は**この意味で誤読になるので使わない**」 |

**なぜ本番で問題になるか**: `CLAUDE.md` は実装リポで**常時ロードされる唯一のファイル**で、
`rules/05` は「実装前に読む」参照先である。**常時見える側に、参照先が禁止した表記だけが残る**ため、
`usecase` → `repository` 具体パッケージの import (L-4 / L-5 違反) を「図どおり」と考える実装が生まれる。
depguard が止めるので事故にはならないが、**設計意図が伝わらず「lint が邪魔をしている」という誤解**になる
(1 巡目の重大 1 と同型 — 雛形の要約が設計の意味を反転させる)。

**是正案**: `:40-44` を「依存方向と責務は `rules/05` の図が正 (**直列ではない** — `repository` / `gateway` は
IF を満たす側)」の 1 文に置き換える。あわせて **`:6`〜`:9` と `:40`〜`:44` の重複を解消する**
(「6 パッケージ層」「Managed Agents」「Dify は使わない」が同一ファイル内で 2 回書かれている — 軽微 10)。

### 中 7 (新規). `go-developer.md` には `rules/05` への必読ポインタを足したが、`code-reviewer.md` には足していない (非対称。DR-8)

**事実**: `4afd59b` は `templates/app-monorepo/backend/.claude/agents/go-developer.md:99-102` に

> **`.claude/rules/05-architecture-coding-rules.md`** — 層の責務・依存規則 L-1〜L-6・… (本エージェントの
> §「層の責務」「Managed Agent 変更時の必須手順」は**要点の再掲。詳細と理由はこのファイルが正**)

を追加した。しかし `templates/app-monorepo/backend/.claude/agents/code-reviewer.md` には **`rules/05` への言及が 1 件も無い**
(`grep -n "rules/05" code-reviewer.md` → 0 件)。同ファイルは `:23`〜`:60` で L-1〜L-6 を**独自に要約**しており、
`:139` では `feedback_review_patterns.md` を「SSOT」と呼んで参照経路を明示しているのに、
**層規約だけ参照先が無い**。

**なぜ本番で問題になるか**: **レビュアーが「要約」を基準に判定する**構造になる。
`rules/05:135` の L-3 (sqlc 生成パッケージの import 制限) のように**設計側で更新される可能性が高い規則**が
変わったとき、レビュアーは古い要約で通してしまう。`go-developer` は正を読み、`code-reviewer` は要約で見る
という**非対称は、実装が規約に追随してもレビューが追随しない形**になる。

**是正案**: `code-reviewer.md` の冒頭 (レビュー観点の前) に go-developer と同文の必読行を置き、
「本ファイルの §1 / §6 は要点の再掲。詳細と理由は `rules/05` が正」を明記する。

### 中 8 (新規). 「`feedback_review_patterns.md` は SSOT」と書いた箇所が 5 つ残り、新設の README 規定 (SSOT は設計リポ) と矛盾する

**事実**: `4afd59b` は `templates/README.md:18` で「**SSOT は設計リポ直下**」と確定させた。一方で:

| 場所 | 記述 |
|---|---|
| `templates/app-monorepo/backend/CLAUDE.md.tmpl:57` | 「`.claude/rules/feedback_review_patterns.md` \| 頻出バグパターン (**SSOT**。設計リポと還流)」 |
| `templates/app-monorepo/frontend/CLAUDE.md.tmpl:92` | 同文 |
| `templates/infra-repo/CLAUDE.md.tmpl:67` | 同文 |
| `templates/app-monorepo/backend/.claude/agents/code-reviewer.md:139` | 「**`.claude/rules/feedback_review_patterns.md` (SSOT)** をチェックリストとして必ず使う」 |
| `templates/app-monorepo/frontend/.claude/agents/frontend-reviewer.md:62` | 同旨 |
| `templates/shared/.claude/rules/feedback_review_patterns.md:3`-`4` (本コミットで新設) | 「**このファイルが**頻出パターンの単一の正 (Single Source of Truth)」「**重複コピーを各所に置かない** (更新時のドリフト防止)」 |

**なぜ本番で問題になるか**: 実装リポの開発者・エージェントは「自分の手元のファイルが SSOT」と読む。
新パターンを**手元だけに追記**し、設計リポへ還流しない (`templates/README.md:79-80` が要求している還流が起きない)。
次の同期 `cp` で**その追記が黙って消える**。**コピー自身が「重複コピーを各所に置かない」と書いている**のは
自己矛盾で、読み手はどちらの規定に従うべきか判断できない (DR-5)。

**是正案**: 5 箇所の「(SSOT)」を「(設計リポの同期コピー。**新パターンは設計リポへ還流する**)」に変え、
`templates/shared/` 側のコピー冒頭に「本ファイルは同期コピー」の 1 行を入れる (重大 5 の (c) と同じ差分)。
**DR-x 節は設計リポ専用**であり、参照先 (`aidlc-docs/reviews/...` / `docs/design/...` / `scripts/check-table-counts.sh`) は
実装リポに存在しないことも 1 行で断る (軽微 11)。

### 中 9 (新規). `plan-layering.md:60` が、移動で無効になった行番号と「雛形は旧定義のまま」という旧状態を保持している (DR-8 の受信側)

**事実**: `aidlc-docs/inception/productionization/plan-layering.md:60` は影響範囲表で

> `templates/app-monorepo/backend/CLAUDE.md.tmpl` \| `:31-45` (アーキテクチャ節) + `:47` (エラー規約) \|
> **雛形は旧定義のまま** — ①`:41` が Service を「複数 UseCase から再利用される処理」と定義 …

と書いている。**本コミットで当該本文は `.claude/rules/05-architecture-coding-rules.md` へ移動し、
`CLAUDE.md.tmpl:31-47` は別の内容になった**。同じ表の次行 (`:61`) は
「**実施後の実測値: `:46-49`**。着手時点では `:41-42`」と実測更新の形を持っているのに、この行は未更新。

**なぜ本番で問題になるか**: `plan.md` 系は実装リポへの引き渡し情報 (`01-aidlc.md` の Design Freeze 条件 4)。
**「雛形は旧定義のまま」を読んだ実装者が、既に更新済みの規約を再度書き換える**か、
存在しない `:41` を探して時間を失う。`.claude/rules/06-delegation-prompts.md` の
「**行番号を引用している箇所は実測値へ更新する**」「状態を語っている記述を同じ差分で更新する」に反する。

**是正案**: 当該行の対象を `templates/app-monorepo/backend/.claude/rules/05-architecture-coding-rules.md` に付け替え、
**状態を「実施済み (2026-08-03。`CLAUDE.md.tmpl` から切り出し)」に更新する**。
`grep -rn "CLAUDE.md.tmpl" docs/ aidlc-docs/inception/` を再実行し、他に状態語を含む行が無いことを確認する
(本レビューでの再確認結果: 残るヒットは `aidlc-docs/inception/construction-workflow/plan.md:23` のみで、
これは「更新」という作業種別の記載なので影響なし)。

### 中 1〜中 5 (継続)

上表の判定どおり全件未解消。是正先が移動したものは次のとおり読み替える:

- **中 3** → `templates/app-monorepo/backend/.claude/rules/05-architecture-coding-rules.md:244`〜`:247`
- **中 2 / 中 4** → `templates/app-monorepo/backend/STRUCTURE.md:9` / `:127-128` / `:197` / `:202-205`
- **中 5** → `STRUCTURE.md:96-124` と `05-architecture-coding-rules.md:90-104` の二重管理を**片方に寄せる**
  (`4afd59b` は宣言先を差し替えただけで、実体の重複は減っていない)

---

## 軽微 (Nice to Have)

1. **(新規) `rules/05:9` の「内容は同期させる」の相手が曖昧** — 「本ファイルは実装リポの `CLAUDE.md` から
   独立させた**運用コピー**であり、内容は同期させる」。`:8` は「決定の正は `architecture.md` §3」と書いており、
   **同期相手が `CLAUDE.md` なのか `architecture.md` §3 なのか読めない** (DR-5)。
   実体は後者なので「`architecture.md` §3 の写し。設計側が変わったら本ファイルを更新する」と書く。
2. **(新規) `rules/05:136` / `:351` の `di/` 表記** — 同ファイル `:147` は `common/di/**`。
   `architecture.md:291-293` (worktree) は「`di` はパッケージ名で、物理パスは `common/di/`。
   **CI 検査の対象パス・除外パスに現れる箇所は `common/` 付きで書く**」と定めており、
   `:351` の `<di/wire_gen.go>` は**ファイルパス**なので `common/di/wire_gen.go` が正。
3. **(新規) `templates/shared/` に置いたコピーが設計リポ専用の参照を含む** — DR-1〜DR-9 の各行が
   `aidlc-docs/reviews/productionization/review-round4.md` / `docs/design/observability.md §4.2` /
   `docs/design/auth.md §10.3` / `scripts/check-table-counts.sh` / `docs/design/API/idea-boards.md §8.2` を
   参照する。**実装リポにこれらは存在しない**ため、実装リポの `.md` リンク検査 (導入した場合) が落ちるか、
   読み手が辿れないまま放置される。「DR-x は設計リポ用。実装リポで使うのは BE-x / FE-x」の 1 行を添える。
4. **(新規) rules の番号衝突リスク** — backend 固有の `05` は現在 `templates/shared/.claude/rules/` に
   `05-*` が無いから成立している。**shared に `05` が追加されると `cp -R` で上書きされる**
   (実測: `cp -R templates/shared/.claude/rules <impl>/.claude/` は既存 `rules/` へ**マージ**されるため、
   同名ファイルは静かに置き換わる)。backend 固有は `05` ではなく `b1-` 等の別名前空間にするか、
   `templates/README.md` に「shared 側は 01〜04 のみ。05 以降は各リポ固有」を明記する。
5. **(継続) 1 巡目 軽微 1〜6** — 上表の判定どおり未解消 (`STRUCTURE.md:18-19` / `:20` / `:29` / `:48`、
   `05-architecture-coding-rules.md:123`、`layering-scopes.yml:49-56`)。
6. **(部分解消) 1 巡目 軽微 7** — 規約本文が `.md` に移り doc-lint 対象になった (対象 108 ファイル)。
   残りは `CLAUDE.md.tmpl` 自身 (`.tmpl`) が対象外である旨を `.claude/rules/05-harness.md` の
   「見る / 見ない」表に 1 行書くだけで閉じる。

---

## 本番観点カバレッジ (`4afd59b` による差分のみ。それ以外は 1 巡目の表が有効)

| ID | 状態 | 箇所 |
|---|---|---|
| A-1 / A-4 / A-6 | 回答あり (変化なし) | 記述が `05-architecture-coding-rules.md:161`〜`:212` へ移動。**A-6 の束縛点 (`tool_registry.go` の クロージャ束縛) は逐語で保持** (照合 #9) |
| O-2 | 回答あり (変化なし) | `05-architecture-coding-rules.md:193`〜`:198` / `:283`〜`:297` |
| O-3 | 回答あり (変化なし) | `05-architecture-coding-rules.md:186` / `:341`〜`:343` |
| O-4 | 回答あり (変化なし) | `05-architecture-coding-rules.md:232`〜`:235` |
| **D-1** | **回答に欠陥 (継続)** | `05-architecture-coding-rules.md:244` (中 3。移動しただけ) |
| **D-5** | **未回答 (継続)** | 要求は `05-architecture-coding-rules.md:247`、機構は `ci.yml` に無い (重大 3・照合 #7) |
| **D-6** | **回答あり (欠陥継続)** | `prompts/agents.yaml` 未変更 (中 1)。`05-architecture-coding-rules.md:299`〜`:317` に運用が移動 |
| D-2 | 回答あり | `4afd59b` は CI を変更していない。**doc-lint の対象が 2 ファイル増えた**のは実質的な改善 |

## 頻出パターン (`.claude/rules/feedback_review_patterns.md`) の確認結果

| # | 判定 |
|---|---|
| DR-1 | **該当あり (重大 1 継続 / 軽微 4 継続)** — 「0 件」が残存、`CanEdit` の出典なしも移動先で残存 |
| DR-2 | **該当あり (重大 3 継続)** — D-5 の機構が無いまま要求文だけが移動 |
| DR-3 | 該当なし (本差分は既存データに触れない) |
| DR-4 | 該当なし — PoC 構造の持ち込みは無い |
| DR-5 | **該当あり (中 8 / 軽微 1・2)** — 「SSOT」の指す先の矛盾、「同期させる」の相手が不明 |
| DR-6 | 該当なし — `make check-traceability` は 24/24 + 86/86。本差分は AC を増やしていない |
| DR-7 | 該当なし |
| **DR-8** | **該当あり (重大 4 悪化 / 中 7 / 中 9)** — 参照経路の消滅、`go-developer` だけ更新、`plan-layering.md:60` の旧状態残存 |
| **DR-9** | **該当あり (重大 5 / 中 4 継続)** — 丸ごとコピーの同期が機械強制されておらず、導入コミットで既にドリフト |
| BE-2 | 対応済み (`05-architecture-coding-rules.md:237`〜`:248`) |
| BE-6 / BE-8 / BE-10 / BE-11 / BE-12 | 対応済み (逐語移動。`:232` / `:302` / `:188` / `:82` / `:304`〜`:312`) |
| **BE-9** | **不十分 (中 1 継続)** — `agents.yaml` の `tools: []` |

---

## 良かった点

- **規約本文の切り出しが逐語移動であることを機械照合で確認できた** (照合 #9)。
  330 行規模の移動で 1 行も内容が変質していないのは、レビュー側が「移動先で指摘が有効か」を
  行単位で追える形になっており、**再レビューのコストを最小にしている**。
- **`CLAUDE.md.tmpl` (313 行削除) の圧縮により、規約本文が `.md` に移って `doc-lint` の対象に入った** —
  1 巡目 軽微 7 (「最も内容が増えたファイルがリンク切れ・TODO 検査を受けない」) が
  意図せずとも構造的に解消方向へ動いた。**規約を `.tmpl` ではなく `.md` に置く**という形自体が正しい。
- **`rules/05:11`〜`:20` の「ここに複製しない」表** — 8 事項について SSOT を名指しし、
  作業ループ / issue 粒度 / モデル運用 / 人間承認点 / 頻出パターン / TDD / コマンドの重複を先に禁じている。
  DR-9 の思想 (二重管理を作る前に参照へ倒す) を新規ファイルの冒頭で実践している。
- **`go-developer.md:99`〜`:102` の書き方** — 「本エージェントの §… は**要点の再掲。詳細と理由はこのファイルが正**」と
  上下関係を明示した。要約と正本が共存するときの正しい書式であり、**これを `code-reviewer.md` にも
  適用すれば中 7 は閉じる** (書式の発明は済んでいる)。
- **`templates/README.md:18`〜`:22` が同期義務を明文化した** — 従来は「設計リポから直接コピー」という
  暗黙運用だった経路を、SSOT とコピーの関係として書き下した。**残る課題は機械強制だけ** (重大 5)。

## 判定

**是正が必要 (push 前に重大 5 件の解消を求める)**。最小の是正リスト:

1. **重大 5-(a) + 重大 1・2 の前提**: `docs/design/architecture.md` と
   `.claude/rules/feedback_review_patterns.md` の**未コミット差分を同じ push に含める**。
   含めない場合は、`layering-scopes.yml:52` / `STRUCTURE.md:57-58` の `common/` 参照と
   `templates/shared/` のコピーが**宛先不明・逆ドリフトの状態で remote に出る**
2. **重大 1**: `STRUCTURE.md:111` の「0 件」を削除 (実測 29 / 非テスト 27。再現コマンドを併記)。
   移植分の `L1-usecase-no-controller` の扱いを決める
3. **重大 3**: `templates/app-monorepo/.github/workflows/ci.yml` に env キー集合検査の
   「未実装なら落ちる」ステップを追加 (他 6 種と同形)
4. **重大 4**: `templates/README.md` の手順に骨格・`STRUCTURE.md`・`.golangci.yml`・`layering-scopes.yml`・
   `prompts/agents.yaml` を追記し、**`CLAUDE.md.tmpl` に `STRUCTURE.md` へのポインタを 1 行戻す**。
   `docs/design/architecture.md:919` の引き渡し行に骨格・`STRUCTURE.md`・`rules/05` を加える
5. **重大 5-(b)**: `make check` に `feedback_review_patterns.md` の同一性検査を追加し、故障注入で確認する

中 6〜9 と中 1〜5 は同じ差分で直すのが安い (いずれも 1〜数行)。是正後の再レビューは本ファイルに追記する。

## 3 巡目: 是正の反映状況 (コミット `e33f03f`。範囲は「自コミット (`4afd59b`) 由来分のみ」とユーザーが確定)

ユーザー判断により、**是正は `4afd59b` (rules 切り出しコミット) に起因する指摘のみ**を対象とし、
`0448a12` (骨格追加コミット) に起因する指摘は**別途対応**として据え置く。

| 指摘 | 対応 | 備考 |
|---|---|---|
| 重大 5 (新規): shared コピーの導入時ドリフト + 同期検査なし | **解消** | SSOT (`.claude/rules/feedback_review_patterns.md`) の未コミット差分 (DR-6/DR-9 追記) を同じコミットに含め、`scripts/check-template-sync.sh` を新設し `make check` に組み込んだ (故障注入で検出力確認済み)。コピー冒頭に同期コピーの注記を追加 |
| 中 6: 圧縮後 `CLAUDE.md.tmpl` が禁止済み直列図を再導入 + 重複 | **解消** | 該当段落を削除し、`rules/05` の図が正である旨の 1 文 + `STRUCTURE.md` へのポインタに置換 |
| 中 7: `code-reviewer.md` に `rules/05` 必読ポインタが無い (非対称) | **解消** | `go-developer.md` と同形式の必読ポインタを追加 |
| 中 8: 「(SSOT)」表記が実装リポ側 5 箇所に残存し矛盾 | **解消** | 5 箇所すべてを「(設計リポの同期コピー。新パターンは設計リポへ還流する)」に変更 |
| 中 9: `plan-layering.md:60` が移動前の古い行番号・状態を保持 | **解消** | 対象行を `rules/05` に付け替え、状態を「実施済み (2026-08-03)」に更新 |
| 重大 4 の悪化分 (`STRUCTURE.md` への参照消失) | **解消** | `CLAUDE.md.tmpl` の該当節に `STRUCTURE.md` へのポインタを復元 |
| 軽微 (新規) #1: `rules/05:9` の同期相手が曖昧 | **解消** | 「`architecture.md` §3 の写し」と明記 |
| 軽微 (新規) #4: `05` の番号衝突リスク | **解消** | `templates/README.md` に「`shared/` は 01〜04 のみ。各リポ固有は 05 以降」を明記 |
| **重大 1 / 2 / 3 / 4 (本体)** | **未対応 (据え置き)** | いずれも `0448a12` (本レビュー対象の別コミット) 由来。`docs/design/architecture.md` の未コミット差分の内容検証を要するなど、今回のセッションのスコープ外と判断。**push は本レビューの重大 1/2/3/4 が残っている限りブロックされたままでよい** (ユーザー確認済み) |
| 軽微 (新規) #2 / #3、中 1〜5 (継続) | **未対応 (据え置き)** | 同上の理由、または `common/` パッケージ決定 (`architecture.md` 未コミット差分) に依存するため |

**再検証**: `make check-template-sync` エラー 0 件 / `make doc-lint` エラー 0 件 (警告は既存分のみ)。

## 未調査 / 要確認

- **`docs/` `aidlc-docs/` の未コミット差分の内容そのものはレビュー対象外** (依頼範囲は `6bdf7ef..HEAD`)。
  ただし重大 1・2 は**その差分が同じ push に入るかどうか**で結論が変わるため、上記 1 に条件として書いた。
  **未コミット差分を push に含める場合、その差分自体は別途レビューが必要** (push ゲートの鮮度チェックの対象)
- **`cp -R` のマージ挙動は macOS (BSD cp) で実測した** (`templates/shared/.claude/rules` を既存の
  `.claude/rules/` へコピーしてもネストせずマージされる)。**GNU cp での再確認は未実施** —
  立ち上げ手順が Linux で実行される可能性がある (軽微 4 の同名上書きの前提)
- **`depguard` の `deny.pkg` が前方一致であること** (重大 1 の帰結 2) は 1 巡目と同じく仕様理解に基づく。
  実装リポで故障注入 1 回で確認すること
