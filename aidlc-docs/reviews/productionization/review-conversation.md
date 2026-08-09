# レビュー: 増分 conversation (Task-3p) — 会話型アイデア創出 API の設計

> レビュー日: 2026-08-02 / レビュアー: `design-reviewer` (第三者セッション) / 対象: 未コミット差分の全体 (新規 5 / 変更 18)
> 判定基準: **本番基準** (`.claude/rules/08-production-gates.md`)。「PoC では対象外だった」を省略理由として認めない
> 頻出パターン: `.claude/rules/feedback_review_patterns.md` (DR-1〜DR-9 全件 + 本増分が触れる BE-1〜BE-12 / FE-2・FE-6)

## レビュー結果サマリ

- **重大: 3 件 / 中: 6 件 / 軽微: 8 件**
- 実行した検証: `make doc-lint` (エラー 0 / 警告 38 = すべて既存) / `make check-traceability` (86/86 カバー) /
  `make check-table-counts` (照合 37 件・エラー 0) / `make check-endpoint-mapping` (照合 29 件・エラー 0) /
  **一次ソースの抜き取り照合 24 件** (v2 15 件 / PoC 9 件) / **故障注入 9 件** (endpoint-mapping 7 / traceability 2)
- **Design Freeze: 不可**。重大 3 件はいずれも「設計どおりに実装すると壊れる / 実装スコープが一意に決まらない」型で、
  かつ **3 件とも起草側が「実施済み」と自己申告した是正要求の未反映**である

### レビューした設計成果物 (リポジトリ相対パス)

**新規 (全文を読んだ)**

- `docs/design/API/conversation.md`
- `docs/design/API/ideas.md`
- `docs/design/API/plans.md`
- `aidlc-docs/inception/productionization/requirements-conversation.md`
- `aidlc-docs/inception/productionization/questions-conversation.md` (CV-Q1〜CV-Q13 の回答部分)

**変更 (差分を読んだ)**

- `docs/design/API/README.md`
- `docs/design/API/idea-boards.md`
- `docs/design/API/assets.md`
- `docs/design/API/themes.md`
- `docs/design/data-model.md`
- `docs/design/observability.md`
- `docs/design/llm-migration.md`
- `docs/design/frontend.md`
- `docs/design/auth.md`
- `docs/design/testing.md`
- `docs/design/operations.md`
- `docs/design/architecture.md`
- `docs/analysis/v2-feature-inventory.md`
- `aidlc-docs/inception/productionization/plan.md`
- `scripts/check-endpoint-mapping.sh`
- `scripts/check-traceability.sh`

**参照のみ (差分外だが整合確認のため読んだ)**

- `docs/design/API/settings.md`
- `docs/design/API/auth-accounts.md`

**未確認 (このレビューでは見ていない)**

- `aidlc-docs/aidlc-state.md` / `todo.html` の差分 (状態管理ファイル。設計判断を含まないため)
- `docs/prototype/` の HTML (プロトタイプは設計入力であり仕様ではない = DR-7。参照元の行番号引用は照合していない)
- `templates/` 配下 (本増分の差分に含まれない)

---

## 重大 (Must Fix — Design Freeze を止める)

### 重大 1. `route_kind=image_generation` がスキーマ SSOT に未反映 — サムネイルの明細が CHECK 違反で書けない

**根拠**:

- `docs/design/data-model.md:726` — `llm_call_records` の `route_kind` の値域が
  **(`managed_agent`\|`direct_api`\|`external_search`) のまま**。同行の注も
  「4 つとも `route_kind='external_search'` のときのみ NULL 可」「`stop_reason` (同条件で NULL 可)」
- `docs/design/data-model.md:755` — 「**NULL を許すのは `route_kind='external_search'` の 4 カウンタと
  `stop_reason` だけ**とし、**`CHECK` 制約でそれを表明する**」
- `docs/design/data-model.md:922` — O-2 の回答表が「**NULL 許容を `route_kind='external_search'` に限る CHECK**」
- 一方 `docs/design/observability.md:139` / `:155` / §4.2.2 (`:197`〜) は `image_generation` を追加済み
- `docs/design/API/plans.md:842` の **R-PL-6 は「実施済み」**と申告し、起票先を `observability.md §4.2` のみにしている

**なぜ本番で問題になるか**: `route_kind` の値域と NULL 許容の **`CHECK` を定義するのは data-model.md** であり、
observability.md は「値の追加はこの表を SSOT として行う」という運用規約を持つだけである。
設計どおりに実装すると、`feature=plan.thumbnail` の行は `input_tokens` 等が NULL のため
**CHECK 制約違反で INSERT に失敗する**か、実装者が独自判断で CHECK を緩める。
前者なら画像生成のコストが 1 行も残らず、**R-PL-6 が防ごうとした「`estimated_cost=0` で総額から丸ごと落ちる」が
そのまま起きる** (O-3 の集計が構造的に誤る)。

**DR-8 の典型例である証拠**: `docs/design/data-model.md:1245` の R-DM-8 には
「**2026-08-02 追記**: NULL を許す `route_kind` は … **`image_generation`** の 2 つになった」と**既に書かれている**。
つまり同一ファイル内で、是正要求欄は新事実を知っているのに本文 (スキーマ定義) が旧記述のまま残っている。

**修正案**: `docs/design/data-model.md` §4.10 の ①`route_kind` の値域列挙に `image_generation` を追加
②`:726` の列注記と `:755` の CHECK 記述を 2 値に ③`:922` の O-2 回答表も同じ差分で更新。
あわせて `plans.md` R-PL-6 の起票先に `data-model.md §4.10` を追加する (起票先の指定漏れが根本原因)。

---

### 重大 2. `idea_evaluations` の非同期ジョブ列が要求の一部しか入っておらず、J-3 / J-5 が実装不能

**根拠**:

- 要求 (`docs/design/API/ideas.md:757` の **R-IDA-2**): `status` / **`heartbeat_at`** / **`idempotency_key`** /
  `failure_code` / **`failure_message`** の 5 列 + `(status, heartbeat_at) WHERE status IN ('queued','running')` の
  インデックス + **部分 UNIQUE `(idea_id, idempotency_key) WHERE status IN ('queued','running')`**
- 実際 (`docs/design/data-model.md:596`): 入ったのは **`job_status` / `job_started_at` / `job_finished_at` /
  `failure_code`** の 4 列のみ。**`heartbeat_at` / `idempotency_key` / `failure_message` と 2 つのインデックスが無い**
- それにもかかわらず R-IDA-2 の状態欄は「**実施済み**」

**壊れる箇所 (すべて `ideas.md` 本文が依存している)**:

| 依存元 | 依存している列 | 現状 |
|---|---|---|
| `docs/design/API/ideas.md:665` (§6.4 の 4。**J-5 冪等キー** = `(idea_id, source_hash)`) | `idempotency_key` | **列が無い** |
| `docs/design/API/ideas.md:668` (§6.4 の 7。**J-3 取り残しの回収** = `heartbeat_at` の閾値超過) | `heartbeat_at` | **列が無い** |
| `docs/design/API/ideas.md:711` (§6.7 の「取り残し (デプロイでプロセスが消えた)」) | `heartbeat_at` | **列が無い** |
| `docs/design/API/ideas.md:79` / `:288` (`failure: {code, message}` を返す) | `failure_message` | **列が無い** |

**なぜ本番で問題になるか**: J-3 が無いと **ECS のローリング更新で消えたジョブが永久に `running`** のまま残り、
ユーザーは再評価できなくなる。J-5 が無いと **二重クリックで LLM コストが倍**になる
(`ideas.md:665` が明示的に防ぐと宣言している事象)。

**あわせて**: 追加された列名 `job_status` は **DM-16 (`docs/design/data-model.md:132`) が定めた共通列名
`status` / `progress` / `failure_code` / `failure_message` / `heartbeat_at` / `idempotency_key` から逸脱**しており、
理由が書かれていない。前例の `knowledge_files` (同 `:601` 付近) は 6 列すべてと部分 UNIQUE を持っており、
R-IDA-10 が「`knowledge_files` と同型」と書いた根拠と実物が食い違う。

**修正案**: `data-model.md` §4.6 の `idea_evaluations` に `heartbeat_at` / `idempotency_key` / `failure_message` を追加し、
列名を DM-16 の規約 (`status`) に揃える (揃えない場合は理由を書く)。インデックス 2 本も同じ差分で追加する。

---

### 重大 3. `scope=contract` の増分境界が文書間・文書内で矛盾し、R-PL-11「実施済み」が事実と違う

**根拠 (①自己申告と実物の食い違い)**:

- `docs/design/API/plans.md:847` の **R-PL-11 の状態欄**: 「実施済み (2026-08-02。D-API-8' を…改訂し、
  **§1.4 の `scope` 値域・§2.2・§5 の A-7 行・API-Q3 を追随させた**)」
- 実物: `docs/design/API/README.md:558` (**§5 の A-7 行**) = 「テーマ・アセットの `visibility` と `scope=contract` は
  **増分 2** (D-API-8')。**増分 1 は個人スコープのみ**」← **未更新**
- 実物: `docs/design/API/README.md:576` (**API-Q3**) = 「テーマ・アセットの `visibility` と `scope=contract` は
  **増分 2** (D-API-8')」← **未更新**

**根拠 (②新規ファイルが自分の引用先と矛盾)**:

- `docs/design/API/README.md` D-API-8' (改訂後) = 「テーマ / アセット / **アイデア**の `scope=contract` は
  **増分 1 から**有効化する」
- しかし `docs/design/API/ideas.md:68` / `:69` / `:71` = スコープ列が「個人 / 契約 (**増分 2**)」、
  `docs/design/API/ideas.md:86` = 「`scope=contract` の受け付けは**増分 2 から** (`README.md` **D-API-8'**)。
  増分 1 は `mine` のみ」、同 `:108` / `:140` / `:233` も増分 2 前提
- `docs/design/API/README.md` §3.8 の総覧明細も**同じ表の中で不一致** —
  `GET /ideas` / `GET /ideas/csv` は「増分 1」だが `GET /ideas/{idea_id}` だけ「増分 2」

**根拠 (③解消済みなのに未解消前提の暫定挙動が残っている)**:

- `docs/design/API/plans.md:773`〜`:777` (§10.4) = 「D-API-8' (**増分 2**) と auth.md §6.12 (c) (増分 1) が
  **食い違っている**ため、本書で片方を選ばず、**解消を §12 の R-PL-11 で起票する**。
  **解消までは `scope=contract` を 400 で拒否する**」← R-PL-11 が「実施済み」になった今も未更新

**根拠 (④起票元の状態列が未更新)**:

- `docs/design/auth.md:1546` の **R-9** (内容 = D-API-8' の増分 1 化) が「**未対応 (並行編集)**」のまま。
  本増分がまさに R-9 を実施したにもかかわらず、起票元の状態列が更新されていない (DR-8 の受信側)

**なぜ本番で問題になるか**: 増分境界は**第 1 リリースに何を実装するかを決める値**である。
現状の設計を読んだ実装者は、`ideas.md` を読めば「増分 1 では `scope=contract` を 400 で拒否する」を実装し、
`README.md` §3.8 / D-API-8' を読めば「増分 1 から受け付ける」を実装する。
どちらを実装しても他方の記述に対する違反になる。`plans.md` §10.4 に至っては
「解消していないので 400」という**既に解消された前提**に基づく挙動を明示的に規定している。

**修正案**: `ideas.md` の 6 箇所 / `README.md:558` / `:576` / `README.md` §3.8 の `GET /ideas/{idea_id}` 行 /
`plans.md` §10.4 / `auth.md:1546` の R-9 状態列を、同じ差分で「増分 1」に統一する。
**キーワード grep は「増分 2」だけでなく「個人スコープのみ」「400 で拒否」「未対応 (並行編集)」でも行うこと**
(数値語だけでは `plans.md` §10.4 と `auth.md` R-9 を構造的に取り残す = DR-8 の既知の失敗形)。

---

## 中 (Should Fix)

### 中 1. 版の URL 識別子が `ideas.md` と `plans.md` で食い違い、R-IDA-8「差分なし」が不正確

- `docs/design/API/ideas.md:76` / `:77` — `GET /ideas/{idea_id}/versions/{version_id}` /
  `POST /ideas/{idea_id}/versions/{version_id}/restore` (**PK を URL に出す**)
- `docs/design/API/plans.md:76` / `:77` — `GET .../versions/{ver_no}` / `POST .../versions/{ver_no}/restore` (**連番**)
- `docs/design/API/plans.md:822` の **D-PL-18 の却下 (b)** は「**`ver_no` ではなく版の PK を使って 2 段にする**:
  `ver_no` はユーザーに見える番号であり、**PK を URL に出すと FE が 2 種類の識別子を持つ**」と
  明示的に PK を却下している。`ideas.md` はその却下案をそのまま採用している
- `docs/design/API/ideas.md:763` の **R-IDA-8** は「plans.md §5 の版・復元が本書 §4 と同じ規則であることを確認。
  **差分なし**」と報告しているが、**識別子の差分を見落としている**

**影響**: `requirements-conversation.md` §6.1 の 4 が「版と復元の共通規則を先に決める」とした目的
(= `entity` の共通関数を作れるようにする) が、URL 層で崩れる。FE も版の識別子を 2 種類持つ。
**どちらかに揃えるか、揃えない理由を書く**こと。

### 中 2. `llm-migration.md` の索引が「会話型 API は別途起草・対象外」「LLM 経路は 3 本」のまま

- `docs/design/llm-migration.md:92` — 「会話型アイデア創出 (発散・9 tools・企画書) | API 設計は**別途起草**
  (本ディレクトリ対象外)」。参照先の `API/README.md` §0 は本増分で対象に含める側へ改訂済み
- `docs/design/llm-migration.md:95` — 「`API/README.md` §4 は「本ディレクトリ内の
  **LLM 経路は 3 本**」と特定している」。実物 (`docs/design/API/README.md:560`) は **9 本**

**影響**: `llm-migration.md` は LLM 移行の索引であり、実装リポの入口の 1 つ。
「別途起草・未着手」と書いてあると、確定済みの `conversation.md` / `plans.md` を読まずに再設計される
(`06-delegation-prompts.md` が名指しする「直した機構が使われず同じものを再実装する」型)。

### 中 3. LM-R10 の判定主体に `plans.md` が指定されているのに、`plans.md` に受信欄も残課題もない

- `docs/design/llm-migration.md:857` (**LM-R10**) — 「**判定の主体は `docs/design/API/plans.md`
  (企画書ドメインの設計) と operations.md の移行計画**」
- `docs/design/API/plans.md` §12.2 (受信欄) にも §13 (残課題 PL-R1〜PL-R9) にも **LM-R10 の行が無い**

**内容そのものも未決**: CV-Q1=B により v3 に企画書機能は第 1 リリースで載るが、
**v2 の既存企画書データの移送は M-8 = RL-4 (併用期間) のまま**である。
`llm-migration.md:838`〜 の注が自ら書いているとおり「第 1 リリース時点で v3 の企画書に既存データが無いなら、
利用者は『企画書が空の v3』を見る」= C-16 の実質的な後退になり得る。
**本増分で決めるべきだったかの判断**: 決めきれないこと自体は妥当 (v2 の実データ量が未計測 = PL-R1)。
ただし **DR-8 の受信側として `plans.md` §12.2 / §13 に登録し、判定期限と判定条件を書く**必要がある。
現状は「誰かが判定する」と書かれているだけで、受け手がそれを知らない。

### 中 4. 新しく増えた「403 の N 本」が機械検算の対象外 (DR-9 の再発余地)

- `docs/design/API/README.md:296` (§2.2 R-2 行) = 「idea-boards 8 本 + ideas 5 本 = **合計 13 本**」
- 同 `:299` (§2.5) = 「**合計 16 本** = settings 3 + idea-boards 8 + ideas 5」
- 同 §3 の総覧表 403 列 (idea-boards 8 / ideas 5 / 小計 16 / 合計 26)
- 同 §3 の注 = 「403 の **16 本** = R-1 (3 本) + R-2 (13 本)」
- `docs/design/API/ideas.md:131` = 「**403 の本数は本表から数える** (DR-9)」

`scripts/check-endpoint-mapping.sh` の検査②は **auth-accounts.md の 403 列しか照合していない**
(9 ドメイン側は本数列のみ照合)。したがって上記 5 箇所以上の転記は**すべて人手管理**であり、
`feedback_review_patterns.md` の DR-9 運用欄が要求する「新しく増えた『N 件』が検算の対象に入っているか」を
満たしていない。**403 列も検査④に加えるか、ideas.md §1.3 の表へのリンクに置き換える**こと。

### 中 5. `scope=contract` 増分 1 化の波及が API/ 外にも残っている (重大 3 の続き。別文書分)

現時点で「増分 2」のまま残っている箇所 (grep 実測):

| ファイル:行 | 記述 |
|---|---|
| `docs/design/API/assets.md:55` | `POST /assets` の `visibility` が「**増分 2 で有効**」 |
| `docs/design/API/assets.md:144` | D-AS-12「書き込み経路と `scope=contract` はどちらも**増分 2**」 |
| `docs/design/API/assets.md:180` | A-4「`scope=contract` (**増分 2**)」 |
| `docs/design/API/themes.md:94` | D-TH-1「`contract` の有効化は**増分 2**」← 同ファイル `:98` D-TH-5 / `:152` A-4 は「増分 1」で**自己矛盾** |
| `docs/design/API/auth-accounts.md:703` | A-7「テーマ・アセットの `visibility` は**増分 2** (`README.md` D-API-8')」 |
| `docs/design/API/settings.md:230` | 「`default_asset_visibility` は**増分 2 の共有機能**が読む側として要求する」 |
| `docs/design/frontend.md:425` / `:996` | 「共有・可視性の UI は**増分 2 で追加**する (A-7)」← `auth.md:1549` の R-10 が「未対応」 |
| `docs/design/auth.md:1325` | §9 の回答表「(c) テーマ・アセットの `visibility` 書き込み API は**増分 2** (列は増分 1)」← 同ファイル `:1281` §6.12 (c) は「増分 1」で**自己矛盾** |

これらの大半は本増分より前から存在する (auth.md §10.4 の R-9 / R-10 が「未対応 (並行編集)」として追跡している)。
ただし **本増分が D-API-8' を反転させたことで、旧記述が「保留中の案」ではなく「現行規約との矛盾」に変わった**。
重大 3 の修正と同じ差分で片付けるか、少なくとも auth.md §10.4 の状態列を実態に合わせること。

### 中 6. `plans.md` §4.9 の生成中状態が `plans` の 2 列で、タブ並行生成を構造的に禁止している点の明示が弱い

- `docs/design/API/plans.md:498` — 「`plans.generating_started_at` と `plans.generating_tab_id` の **2 列**で表す」
- `docs/design/API/plans.md:880` の **PL-R7** で「同時に走る生成は企画書あたり 1 本と仮定した。
  『タブ 1 と タブ 5 を同時に再生成したい』という要求が出た場合、2 列では表せず…**その要求は現時点で確認できていない**」

仮定と代償が書かれている点は良い。ただし **`GET /plans/{plan_id}` の `tabs[].status` は
タブごとに `generating` を返す設計** (`docs/design/API/plans.md:170`) であり、
2 列表現だと `generating_tab_id` に入った 1 タブしか `generating` にできない
(一括生成時は `null` なので**全タブが `generating` に見える**のか、どのタブも `generating` にならないのかが未記述)。
**一括生成中の `tabs[].status` の値**を明記すること (DR-5 = 実装者判断への丸投げになっている)。

---

## 軽微 (Nice to Have)

出典の**内容は正しいが行番号がずれている**もの (DR-1 の軽度形。転記されると実装リポで探せなくなる)。

| # | 記述箇所 | 引用 | 実測 |
|---|---|---|---|
| 軽 1 | `docs/design/API/ideas.md:234` | `theme_id` の由来 = `hassan-v2-backend/controller/idea.go:164` | `:164` は `RequestAccountID: c.Query("account_id")`。`theme_id` は **`:165`**。同じ `:164` を同節 (`:243`) で `account_id` の出典にも使っており、**1 行を 2 つの別事実の出典にしている** |
| 軽 2 | `docs/design/API/conversation.md:412` / `:534` | `claude_managed_agents/cmd/devui/conversation_tools_deepdive.go:195` が `asset_context` をパースする | `:195` は `Pattern`。`AssetContext` は **`:197`** (主張自体は正しい — schema は `pattern`/`target` のみで handler だけが `asset_context` を読む) |
| 軽 3 | `docs/design/API/plans.md:691` | 「エンドポイントは **GET**」の出典が `hassan-v2-backend/controller/business_plan.go:817` | `:817` は `@success`。GET である根拠は **`:820`** (`@Router … [get]`) / `:821` (関数定義)。同行の `:824` / `:856` は完全一致 |
| 軽 4 | `docs/design/API/ideas.md:314` | v2 の CSV は `idea_hassan_id` 必須 = `controller/idea.go:452`〜`:455` | 必須チェックは **`:450`〜`:454`** |
| 軽 5 | `docs/design/API/idea-boards.md` (IB-Q14 表) | `market_size` = `hassan-v2-backend/db/schema.sql:159` / `cagr` = `:160` | 実測は **`:160` / `:161`**。**`ideas.md:213` の `:160`〜`:161` が正しい** — 同じ事実の行番号が 2 文書で 1 ずれている |
| 軽 6 | `docs/design/API/conversation.md:186` / `:827` | system prompt が Agent リソース側に登録される根拠 = `cmd/update-agent-prompt/main.go:215` | `:215` は `buildUpdateTools` (**Tools** の全置換)。system prompt の登録は **`:182`〜`:184`** (更新) / **`:524`〜`:527`** (新規) / 差分判定は **`:177`**。主張は正しいが出典が別の事実を指している |
| 軽 7 | `docs/design/API/conversation.md:118` / `:719` | PoC が `managed_session_id` を返す根拠 = `cmd/devui/conversation_list.go:39` | `:39` はハンドラ関数の定義行。返している実体は **`:84`** (`json:"managed_session_id"`) / **`:124`**。事実は正しい |
| 軽 8 | `docs/design/API/plans.md:21`〜`:23` | 「**`ideas.md` にリンクを張っていない理由** … 本文ではプレーンテキストで書く。統合時にリンク化する」 | 同ファイル `:15` は**既にリンク化済み**。`conversation.md:24` / `ideas.md:26` は同じ注を「2026-08-02 にリンク化済み」へ更新しており、**plans.md だけ旧文のまま** |

そのほか:

- `docs/analysis/v2-feature-inventory.md` §2.5 の `GET /ideas/csv` 行の v3 対応が
  「同名 (**idea-boards.md §2.4**)」のまま。移設先は `ideas.md` §2.6 (リンク切れではないが 1 段迂回する)
- `docs/design/API/conversation.md:16`〜`:17` の「**(2026-08-02 起草済み)**」表記と `:22`〜`:24` の注が重複している
  (統合時の整理対象。害はない)

---

## 裏取りの記録

### A. 検証ゲートの実行結果

```
$ make doc-lint
[doc-lint] 対象 100 ファイル / エラー 0 件 / 警告 38 件
  → 警告 38 件はすべて既存: 過去 review・design_memo.md の未確定マーカー語への反応 /
    既存の未回答 [Answer] 5 件 (data-model.md:1055 / frontend.md:1229 / infrastructure.md:519・:535 /
    llm-migration.md:788 / operations.md:696)。**本増分の新規 3 ファイルに未回答 [Answer] は 0 件**

$ make check-traceability
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 86/86 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature

$ make check-table-counts
[table-counts] 実測: 機能テーブル 42 (個人 34 / 契約 8) / 分類 ①31 ②2 ③1
[table-counts] 実測: 機能テーブル以外 12 (所有者列なし 7 / 所有者列あり 5) / 検査①の除外リスト 9
[table-counts] 照合 37 件 / エラー 0 件

$ make check-endpoint-mapping
[endpoint-mapping] 実測: auth-accounts.md 37 本 / 9 ドメイン 112 本 / settings.md §5 18 行
[endpoint-mapping] 照合 29 件 / エラー 0 件
```

### B. 一次ソースの抜き取り照合 (24 件。うち結論を左右するもの 6 件)

**結果: 内容の誤り 0 件 / 行番号完全一致 18 件 / ±1〜3 行のずれ 6 件 (軽微 1〜7)。**

**v2 (`hassan-v2-backend`) — 15 件**

| # | 主張 (出典) | 照合コマンド | 結果 |
|---|---|---|---|
| 1 | `plans.md` §3 の企画書 18 本の router 行番号 (`:151`〜`:170`) | `sed -n '119,172p' router/router.go` | **18/18 完全一致** (`POST /generate`=151 … `POST /detailed/brush-up/prepare`=170) |
| 2 | `ideas.md` §3.1 のアイデア系 13 本の行番号 | 同上 | **13/13 完全一致** (`GET /ideas/:id`=121 / `GET /ideas`=122 / `/generate`=123 / my-idea=124 / draft=125 / evaluate=126 / csv=127 / star=128 / idea-hassans=144〜148) |
| 3 | `conversation.md:82` — `/idea-hassans` グループは `router.go:143` | 同上 | **一致** |
| 4 | **`ideas.md` §2.6 の CSV 列ずれバグ** (ヘッダ 16 列 `:43`〜`:58` / データ 15 値 / `TargetMarket` 欠落 / `:68` の次が `:69`) | `sed -n '33,80p' usecase/idea/get_ideas_csv.go` | **完全一致・バグの実在を確認**。ヘッダ 16 個は `:43`〜`:58`、データ行は `Title,Concept,Customer,Issue,Solution,MarketSize,…` の 15 個で `TargetMarket` が無い。`CreatedAt` は `:78` |
| 5 | `ideas.md:310`〜`:311` — CSV の BOM / CRLF (`controller/idea.go:481`〜`:486`) | `sed -n '479,488p' controller/idea.go` | **完全一致** (481=Content-Type / 482=Disposition / 483=BOM / 486=UseCRLF) |
| 6 | **`ideas.md` §6.3 の閾値表の穴** (`<=300`→1、`>=400 && <500`→2 で 300〜400 が default に落ちる。`score_calculator.go:65`〜`:85`) | `sed -n '60,90p' util/score_calculator.go` | **完全一致・穴の実在を確認** |
| 7 | `ideas.md` §3.3 — `CalculateTotalScore` = 4 軸の単純合計 (`:135`) | `sed -n '133,140p' util/score_calculator.go` | **一致** |
| 8 | `ideas.md` §3.2 — `ExecuteDraft` は同じ UseCase の別メソッド (`create_my_idea.go:207`) | `sed -n '203,210p'` | **完全一致** |
| 9 | `ideas.md` §3.2 — `PDFFiles` (`create_my_idea.go:60`) | `sed -n '55,62p'` | **完全一致** |
| 10 | `plans.md` §5.1 — 手動編集は本文先頭 30 文字 (`update_business_plan.go:79`) / brush_up は原文 (`:82`) / 手動でも履歴行を作る (`:99`) | `sed -n '77,101p'` | **3/3 完全一致** |
| 11 | `plans.md` §6.1 — `technology_analysis` に生成経路が無い (`business_plan_detailed.go:105`〜`:118` の 6 分岐) | `sed -n '103,120p'` | **完全一致**。6 case (`pestel/competitor/market/hypothesis_verification_poc/legal/evaluation_summary`) で `technology_analysis` 不在。引き継ぎ側は `finalize_…:174` も一致 |
| 12 | `plans.md` §6.2 — 簡易モード 12 種 (`entity/business_plan.go:71`〜`:82`) + `thumbnail-url` (`:83`) / ジョブの並列対象 (`generation_job_manager.go:21`〜`:34`) | `sed -n '69,85p'` / `sed -n '19,36p'` | **完全一致** (12 定数が 71〜82、thumbnail-url が 83、配列が 21〜34) |
| 13 | `plans.md` D-PL-4 — v2 のジョブは状態も購読者もメモリ (`generation_job_manager.go:57`〜`:80` の `jobsByID` / `subscribers`) | `sed -n '55,82p'` | **一致** (57=`type businessPlanJob`、68=`subscribers`、78=`jobsByID`) |
| 14 | `plans.md` §9.1 — `business_plan_favorites` = `(account_id, business_plan_id)` 複合 PK (`schema.sql:206`〜`:214`) / §7.1 — `business_plan_chat_messages` に所有者列も FK も無い (`:225`〜`:232`) / `business_plan_histories.prompt` (`:238`) / 詳細版 7 列 (`:273`〜`:279`) | `sed -n '204,240p;270,282p' db/schema.sql` | **4/4 完全一致**。特に「本文テーブルは `id`/`conversation_id`/`role`/`content`/`created_at` のみ」を確認 |
| 15 | `plans.md` §8.1 — S3 が public-read (`aws/s3.go:46`) / `ideas.md` — `ideas.concept`=`:155`・`star_rating`=`:172` | `sed -n '44,48p' aws/s3.go` / `sed -n '150,175p' db/schema.sql` | **一致** (`market_size`=160 / `cagr`=161 — `idea-boards.md` の :159/:160 は 1 ずれ = 軽微 5) |

**PoC (`claude_managed_agents`) — 9 件**

| # | 主張 (出典) | 結果 |
|---|---|---|
| 16 | `conversation.md` §2.3.1 — `stage` 5 値の判定順序が PoC と同じ (`internal/db/conversation_store.go:250`) | **完全一致**。`deriveStage` が 250 行目、順序も `plan_draft → ideation → match(Matching.Pairs) → market(Selected\|\|Researched) → asset`。`deep_dive_results` を使わない点も一致 |
| 17 | `conversation.md` §1.4 — `display_title` の導出順 (`conversation_store.go:213`) | **一致**。コメントが `Theme > AssetDefinition.AssetName > SelectedDomains[0].Name > 「無題の対話 (作成日時)」` = 本文の 2〜5 と同順 |
| 18 | `conversation.md` §4.1 — PoC の tool は 9 本 (`cmd/update-agent-prompt/main.go:280` の `conversationToolDefs`) | **一致**。`grep -n 'Name:'` で `list_assets/load_asset/set_theme_name/research_market/deep_dive/generate_ideas/generate_plan/record_rejection/match_functions` の 9 本を確認。v3 の 8 本 = これ − `set_theme_name` |
| 19 | `conversation.md` §4.1 の変更点 2 — `deep_dive` の schema は `pattern`/`target` のみ、handler だけが `asset_context` を読む | **主張は完全に正しい**。schema の `Properties`/`Required` は 2 つ、handler の args struct に `AssetContext` あり (行番号のみ軽微 2) |
| 20 | `conversation.md` D-CV-9 — PoC は `artifact` → 台帳の順 (`cmd/devui/conversation.go:606` → `:607`) | **完全一致** (606 が `sw.Event("artifact"…)`、607 が `ledger.appendGeneratedIdeasFromArtifact`) |
| 21 | `conversation.md` §6.2 — `error` は `runErr.Error()` の素通し (`conversation.go:482`) / §5.2 — `asset` artifact がラッパ無し (`:705`) | **2/2 完全一致** |
| 22 | `ideas.md` §6.1 — 評価の `MaxTokens=8192` (`idea_evaluate.go:44`) / timeout 60s (`:47`) / retry 2 (`:50`) / `stop_reason==max_tokens` 検出 (`:192`) / `computeIdeaSourceHash` の思想 (`:139`〜`:147`) | **5/5 完全一致**。4096→8192 の経緯コメントも `:39`〜`:44` に実在 |
| 23 | `ideas.md` §6.2 — `grade` バンド 8.0/6.0/4.0 (`conversation_tools_generate.go:615`〜`:626`) / `Grade` フィールド (`:245`) / `decideEvaluationLookup` (`idea_evaluations.go:140`) / `Categories` (`diverge/schema.go:31`) | **4/4 完全一致** |
| 24 | `plans.md` §4.1 — 8 タブの定義 (`diverge/plan.go:13`〜`:20`) と表示順 (`:27`〜`:35`) | **完全一致** (service/bmc/summary/pestel/market/competitor/tech/legal) |

**判定**: DR-1 (出典なしの断定) は本増分に**見つからなかった**。
行番号のずれ 6 件はいずれも ±1〜3 行で、**主張の内容が誤っていたものは 1 件も無い**。
`feedback_review_patterns.md` の「1 つでも誤りが見つかったら全数照合に切り替える」条件には該当しないため、
抜き取り 24 件で打ち切った (= **全数照合は未実施**。残りの引用は未確認)。

### C. 是正要求「実施済み」の実物照合 (12 件)

宛先ファイルを開いて実際に入っているかを確認した。

| 是正要求 | 宛先 | 判定 |
|---|---|---|
| R-CVA-1 (`conversation_sessions.title`) | `docs/design/data-model.md:546` | **一致** (`title text NULL` あり) |
| R-CVA-2 (台帳 `seed_idea`) | `docs/design/data-model.md:852` | **一致** (書き手・読み手が対で記載) |
| R-CVA-3 (`turn_seq` の定義) | `docs/design/data-model.md:577` 付近 | **一致** |
| R-CVA-4 (①主 tx 外 ②仮定 4 クローズ ③対応 API 欄) | `docs/design/data-model.md:544` / `:582`〜`:584` | **一致** (§4.5 は `API/conversation.md`、§4.6 は 3 ファイルへのリンク) |
| R-CVA-13 (`theme_id` NOT NULL) | `docs/design/data-model.md:546` / `:557`〜`:565` | **一致** (NOT NULL + FK CASCADE + 通常インデックス。`llm_call_records` 側の旧根拠の失効も明記 = 良い) |
| R-CVA-5 (`feature` 7 値の登録) | `docs/design/observability.md` §4.2.1 | **一致** (9 値に拡張済み) |
| R-CVA-6 / R-PL-9④ (J-6 適用外の明記) | `docs/design/API/README.md` §1.3.1 | **一致** (会話 1 本 + 企画書 3 本) |
| R-CVA-8 / R-PL-10 (FE の中継 Route Handler) | `docs/design/frontend.md` §6.3.1 | **一致** (6 行。会話 1 + 企画書 3 を含む) |
| R-IDA-1 (`/ideas` 系 4 本の移設) | `docs/design/API/idea-boards.md` §2 / §2.2 / §2.4 / §7 / D-IB-3 / IB-Q14 | **一致** (4 行削除・§7 書き換え・`rank`→`grade`・22→18 本) |
| R-IDA-6 (README の総覧更新) | `docs/design/API/README.md` §3 | **一致** (9 ドメイン 112 + 37 = 149。移設元 idea-boards も 22→18 に減算済み = 二重計上を回避) |
| R-IDA-7 (CSV 列ずれの告知) | `docs/design/operations.md:518` | **一致** (§6.3.1 に #5 として追加) |
| R-PL-12 (テストの 3 入口) | `docs/design/testing.md:649` | **一致** (存在検査 #5 に限界と 3 入口の要求を追記) |
| **R-PL-6 (route_kind 追加)** | `docs/design/observability.md` ✅ / **`docs/design/data-model.md` ❌** | **不一致 → 重大 1** |
| **R-IDA-2 (評価ジョブ列)** | `docs/design/data-model.md:596` | **不一致 (5 列中 2 列 + 索引 2 本が欠落) → 重大 2** |
| **R-PL-11 (増分境界の解消)** | `docs/design/API/README.md` D-API-8'・§1.4・§2.3 ✅ / **§5 A-7 (`:558`)・API-Q3 (`:576`) ❌** | **不一致 → 重大 3** |

**照合 15 件中 12 件一致 / 3 件不一致**。不一致 3 件はいずれも重大に計上した。

### D. DR-8 の波及 grep (状態語 + 数値語の両方)

```
$ grep -rn "増分 2" docs/design/ | grep -v README.md        → 重大 3 / 中 5 の根拠 (8 ファイル)
$ grep -rn "route_kind" docs/ | grep -v review              → 重大 1 の根拠 (data-model 3 箇所が旧値)
$ grep -rn "未着手|未実装|未設定|未登録|未作成|別途起草|Task-3p" docs/design/ docs/analysis/
                                                            → 中 2 の根拠 (llm-migration.md:92 / :95)
$ grep -rn "theme_id.*NULL 可|テーマ確定前" docs/ aidlc-docs/inception/
                                                            → 残存 0 件 (observability.md:138 は撤回を明記済み ✅)
$ grep -rn "13 フィールド|10 のうち" docs/ aidlc-docs/inception/
                                                            → 件数表現の残存 0 件。questions-conversation.md:28 は
                                                              「件数は書かない — 定義元の表が正」に置き換え済み ✅
```

### E. 故障注入 (観点 7 — 起草側の自己申告を信じず、レビュアーが独立に実施)

リポジトリを汚さないため `scripts/` `docs/` `aidlc-docs/` をスクラッチへ複製して実施した (**設計成果物は変更していない**)。

**`scripts/check-endpoint-mapping.sh` — 7 種すべて検出 (7/7)**

| # | 注入 | 結果 |
|---|---|---|
| FI-1 | `plans.md` のエンドポイント表から 1 行削除 (17→16) | **exit 1**。総覧表・§3.9 明細・小計の 3 箇所で検出 |
| FI-2 | README 総覧の conversation 行を 7→8 に改ざん | **exit 1** |
| FI-3 | README §3.8 の明細から 1 行削除 | **exit 1** |
| FI-4 | README 注の「共通規約が対象にするのは 9 ドメインの 112 本」を 111 に | **exit 1** |
| FI-5 | 「9 ドメイン」を「10 ドメイン」に (DOMAINS 配列とずらす) | **exit 1** (パターン不一致として 2 件) |
| FI-6 | 小計行 112→111 | **exit 1** |
| FI-7 | 合計 149→148 | **exit 1** |
| FI-8 | `ideas.md` の表に 1 行追加 (13→14) | **exit 1** (5 箇所) |

→ `DOMAINS` 配列 + `NDOM` 方式は**検出力を持つ**と確認した。
ドメイン追加時に配列だけ直せばよい設計になっており、DR-9 の機械強制として妥当。
**ただし 403 / LLM / SSE の各列は検査対象外** (中 4)。

**`scripts/check-traceability.sh` — 2 種すべて検出 (2/2)**

| # | 注入 | 結果 |
|---|---|---|
| FI-T1 | `AC-CV-4.8` の参照を plan.md / plans.md から全消し | **`productionization: 85/86 カバー — 未カバー: AC-CV-4.8`** で検出 |
| FI-T2 | 旧形式 `AC-1.2` の参照を全消し (既存 AC を壊していないかの確認) | **両 feature で検出** (`construction-workflow: 23/24` / `productionization: 85/86`) |

**正規表現拡張の効果を実測**:

```
$ grep -ohE '\bAC-CV-[0-9]+(\.[0-9]+)?' requirements-conversation.md | sort -u | wc -l   → 39
$ grep -ohE '\bAC-[0-9]+(\.[0-9]+)?'    requirements-conversation.md | sort -u | wc -l   → 16
```

拡張前の正規表現では **AC-CV-* 39 個のうち 23 個が照合対象から漏れていた** (DR-6 の穴)。
拡張後は 86/86 で全数が照合される。**既存 AC-ID を壊していない**ことも FI-T2 で確認した。

---

## 本番観点カバレッジ (`.claude/rules/08-production-gates.md`)

| ID | 状態 | 箇所 |
|---|---|---|
| A-1 認証方式 | **回答あり** | `conversation.md` §0.2 / §1.1 (全 7 本認証必須) / `ideas.md` §0.2 / `plans.md` §0.3 (全 17 本) |
| A-2 ロール | **回答あり** | `conversation.md` §1.1・`plans.md` §1.1 (`AuthRoleUser` のみ・403 なし) / `ideas.md` §1.3 (所有者による 403 = README §2.2 の R-2) |
| A-3 テナント境界 | **回答あり (参照 + 新規テーブル)** | `plans.md` §7.2 / §9.2 (新規 2 テーブルに `contract_id` + `account_id`) / `data-model.md` §4.1.1 の 42 件表 |
| A-4 絞り込みの層 | **回答あり** | `conversation.md` §2.1 のステップ 3・§4.4 / `ideas.md` §1.4 (可視性 3 条件を 1 クエリ + `is_owner`) / `plans.md` §1.3 |
| A-5 ステータスコード | **回答あり** | `conversation.md` §6.1 (409 = 並行ターン) / `ideas.md` §1.3 (403/404 の表) / `plans.md` §2.9 |
| A-6 LLM への越境 | **回答あり (具体的)** | `conversation.md` §4.4 (クロージャ束縛・存在確認を所有権に使わない・`generate_plan` のテーマ配下チェック・warn) / `ideas.md` §6.5 (LLM に ID を解決させない) / `plans.md` §4.5 |
| A-7 共有・公開 | **回答あり (ただし増分境界が矛盾 = 重大 3)** | `conversation.md` §0.2 (個人スコープのみ・D-CV-3 に理由) / `ideas.md` §1.4 / `plans.md` §10.4 |
| O-1 構造化ログ | **対象外 (理由 + 先送り先あり)** | 3 ファイルとも §0.2 相当で `observability.md` §4.1 を SSOT と明示 |
| O-2 LLM 計測 | **回答あり (ただし CHECK が未追随 = 重大 1)** | `conversation.md` §3.3 (7 値) / `ideas.md` §6.6 / `plans.md` §4.6 (`plan.chat` / `plan.thumbnail`) / `observability.md` §4.2.1 |
| O-3 コスト集計と上限 | **回答あり** | `conversation.md` §2.5 (安全弁 4 種の測定点と発火時の挙動) / `plans.md` §4.7 / いずれも「上限による拒否は設けない (C-12)」を明記 |
| O-4 失敗の可観測性 | **回答あり** | `conversation.md` §6.3 (F-1〜F-5 との対応) / `ideas.md` §6.7 / `plans.md` §4.8 (部分保存を作らない) |
| O-5 SSE / 長時間処理 | **回答あり** | `conversation.md` §2.4 / §5.3 / §6.2 (回復経路 2 本) / `plans.md` §4.9 (回復は `GET /plans/{plan_id}`) / `ideas.md` §6.3 (SSE を持たない理由 = D-IDA-9) |
| O-6 監査ログ | **回答あり** | `conversation.md` §6.3 / `ideas.md` §1.5 / `plans.md` §10.5 (いずれも対象操作のみ確定し、項目は `observability.md` §4.5 を SSOT) |
| O-7 アラート | **対象外 (理由 + 先送り先あり)** | 3 ファイルとも `observability.md` §4.6 へ委譲 |
| D-1 環境 | **対象外 (理由あり)** | 「インフラ・CI/CD は API 設計の範囲外」+ SSOT を名指し |
| D-2 CI ゲート | **対象外 (理由あり)** | 同上。ただし `testing.md` §10 の #5 に企画書 3 入口を追加済み (R-PL-12) |
| D-3 デプロイ手順 | **対象外 (理由あり)** | 同上 |
| D-4 DB マイグレーション | **回答あり (参照)** | `ideas.md` §0.2 (是正要求はすべて列追加 = 非破壊 DDL・区分は `operations.md` §7.4) |
| D-5 シークレット | **対象外 (理由あり)** | 同上 |
| D-6 Agent ライフサイクル | **回答あり** | `conversation.md` §3.4 (再発行対象 3 本・追加は後方互換・削除は 2 段階) / `plans.md` §4.2 (P-4) / `ideas.md` §0.2 (**直接 API なので対象外**の理由あり) |
| D-7 段階リリース | **回答あり (ただし LM-R10 が宙吊り = 中 3)** | `plans.md` §0.3 / §12 の R-PL-7 / `ideas.md` §3.3 (既存データの写像) |
| D-8 IaC | **対象外 (理由あり)** | 同上 |

**無言の省略 (DR-2) は 0 件**。すべての ID に回答または「対象外 + 理由 + 先送り先」がある。

---

## 頻出パターン (`feedback_review_patterns.md`) の確認結果

| ID | 判定 |
|---|---|
| DR-1 出典なしの断定 | **該当なし** (抜き取り 24 件で内容の誤り 0。行番号ずれ 6 件は軽微へ) |
| DR-2 本番観点の無言の省略 | **該当なし** (上表のとおり全 ID に回答または理由) |
| DR-3 既存データの不在 | **該当なし** — `ideas.md` §3.3 (スコア値域の写像・5 軸目 NULL・`idea_versions` の ver 1 生成・ロールバック) / `plans.md` R-PL-4 (1 アイデア複数行の移行規則 + 移行レポート) が書かれている |
| DR-4 PoC 実装のコピー設計 | **該当なし** — むしろ PoC の 6 箇所を明示的に却下 (`artifact`→台帳の順序 / `runErr` 素通し / 固定 ver Insert / `asset_context` 注入 / タブ本文の SSE 全載せ / `managed_session_id` の露出) |
| DR-5 曖昧語による丸投げ | **1 件** (中 6 = 一括生成中の `tabs[].status` の値が未記述)。「適切に」「必要に応じて」「後で検討」の判断ポイントでの使用は grep でも 0 件 |
| DR-6 AC の宙吊り | **該当なし** (86/86)。むしろ `check-traceability.sh` の拡張で **23 個の宙吊りを新たに可視化して解消**した |
| DR-7 プロトタイプを仕様として扱う | **該当なし** (プロトタイプ由来の記述は IB-Q14 系で「回答済み」に落とし、根拠を v2 実装に置いている) |
| **DR-8 修正の波及漏れ** | **3 件 (重大 1・2・3) + 中 2・中 3・中 5**。本レビューの最上位指摘。**6 巡連続で同じ型** |
| DR-9 件数の転記 | **1 件 (中 4 = 403 の本数が未検算)**。テーブル件数・エンドポイント件数は機械強制が効いている |
| BE-1 (旧バージョン参照) | 構造で対処 — 台帳に `entry_id` を渡す / `seed_idea` を保存 / `source_idea_version_id` を NOT NULL |
| BE-2 (hard cap の散在) | 構造で対処 — `rejected_candidates` 上限・タグ長・評価件数上限・`instruction` の N をすべて `config` 1 箇所に |
| BE-4 (stale ガード) | 構造で対処 — `is_stale` / `stale_reason` の値域と「本文を返さない」判断 |
| BE-6 (MaxTokens 切り詰め) | 構造で対処 — F-1 として観測 + 「再試行が同じ deadline を共有しない」を明記 |
| BE-7 (SSE マルチライン) | 構造で対処 — 「除外リスト方式・空行も本文として通す」を仕様に明記 |
| BE-8 / BE-10 (schema と handler の乖離 / 書き手のいない読み手) | **構造で潰した** — CV-D13 (サーバ注入の廃止) により 3 者一致検査が原理的に成立。台帳 13 フィールドすべてに書き手・読み手を対で記載 (`conversation.md` §4.5) |
| BE-11 (採番の固定 Insert) | 構造で対処 — 「採番と Insert を 1 SQL」「版番号を引数で受け取るメソッドを作らない」を両ファイルで反復 |
| BE-12 (フィールド契約の食い違い) | 構造で対処 — `entity/toolresult` の 1 宣言から読み手・書き手・テストを導く |
| FE-2 / FE-6 | 構造で対処 — orval 生成型の強制 (`frontend.md` の `Idea` 型注記) / 「数値はサーバが計算済みの整数で返し FE にパースさせない」(`ideas.md` §2.1) |

---

## 良かった点

1. **出典の精度が高い**。特に `plans.md` §3 の v2 企画書 18 本は router の行番号が **18/18 完全一致**。
   `ideas.md` §2.6 の CSV 列ずれ (ヘッダ 16 / データ 15) と §6.3 の閾値表の穴 (300〜400 が default に落ちる) は、
   **一次ソースで再現確認できた実在のバグ**であり、v2 を読み込んだ上での指摘になっている。
   さらに「バグを再現するか」を却下案付きで判断している (D-IDA-11)。
2. **機構を直してから文書を書いている**。`check-endpoint-mapping.sh` の `DOMAINS` 配列化 (故障注入 7/7 検出) と
   `check-traceability.sh` の正規表現拡張 (拡張前は AC-CV-* 39 個中 23 個が照合対象外だった) は、
   どちらも**実効性のある機械強制**である。特に後者は DR-6 の穴を新たに塞いだもので、本増分の副次的な成果として大きい。
3. **C-16 (v2 の操作を落とさない) の追跡が徹底している**。企画書 18 本・アイデア 13 本とも
   「増分 2 / 後ろ倒し / 対象外」が 0 行で、`v2-feature-inventory.md` §5 の未解決 #9 / #10 もクローズされた。
   落とす 4 件 (0〜40 尺度 / OGP の `image` / モデル選択 / 言語切替) には**すべて理由と例外承認要求 (IDA-R1 / IDA-R2)** がある。
   `POST /business-plans/detailed/brush-up/prepare` を「操作が構造的に消滅する」として扱った説明 (D-PL-5) も妥当。
4. **逸脱を無言で行っていない**。`plans.md` D-PL-16 (8 タブ 1 tx → タブ 1 件 1 tx) と D-PL-18 (3 段ネスト) は
   どちらも既存規約からの逸脱を自ら宣言し、規約側の改訂を起票している。
   `data-model.md` §4.11.1 の規約 5 も「旧記述は…だった」を残したまま改訂されており、変更履歴が追える。
5. **A-6 の回答が実装可能な粒度**。「存在確認を所有権の検証に使わない」「該当なしは見つからないで統一」
   「所有者不一致を warn + メトリクス」の 3 点が 3 ファイルで一貫し、
   `generate_plan` にはテーマ配下チェックという**追加の越境経路**まで潰している。
6. **受信欄 (DR-8 の受信側) を 3 ファイルとも持っている**。`conversation.md` §8.2 / `ideas.md` §8.2 /
   `plans.md` §12.2 に起票元・ID・状態がある。今回の重大 3 件は「起票先の指定漏れ」と
   「状態列の虚偽記載」であって、機構そのものは正しく設計されている。

---

## Design Freeze の可否

**不可 (Blocked)。**

重大 3 件はいずれも次の性質を持つ:

- **設計どおりに実装すると壊れる** (重大 1 = CHECK 違反で計測が落ちる / 重大 2 = J-3・J-5 が実装できない)、
  または **実装スコープが一意に決まらない** (重大 3 = `scope=contract` の増分)
- **3 件とも起草側が「実施済み」と自己申告した是正要求の未反映**である。
  自己申告を信じて Freeze すると、実装リポで「設計書どおりに作ったのに動かない」形で顕在化する

### Freeze 可にするための最小の修正

| # | 修正 | 対象 |
|---|---|---|
| 1 | `route_kind` の値域に `image_generation` を追加し、NULL 許容の CHECK 記述を 2 値にする (3 箇所) | `docs/design/data-model.md:726` / `:755` / `:922` |
| 2 | `idea_evaluations` に `heartbeat_at` / `idempotency_key` / `failure_message` と索引 2 本を追加し、列名を DM-16 の規約に揃える (揃えないなら理由を書く) | `docs/design/data-model.md:596` |
| 3 | `scope=contract` の増分を「増分 1」に統一する。**最低限**: `ideas.md` の 6 箇所 / `README.md:558` / `:576` / `README.md` §3.8 の `GET /ideas/{idea_id}` 行 / `plans.md` §10.4 (「解消までは 400」の撤回) / `auth.md:1546` の R-9 状態列 | 5 ファイル |
| 4 | 上記 3 件の是正要求 (R-PL-6 / R-IDA-2 / R-PL-11) の**状態欄を実態に合わせて書き直す**。R-PL-6 は起票先に `data-model.md §4.10` を追加する | `docs/design/API/plans.md` §12.1 / `docs/design/API/ideas.md` §8.1 |

**中 6 件は Freeze の条件にしない**が、中 1 (版 URL の識別子) と中 3 (LM-R10 の受信欄) は
実装着手前に決めた方が安い (前者は `entity` の共通関数と FE の型に、後者は移行計画に波及する)。

### 再レビュー時の確認方法 (次回の効率のため)

1. 修正後に `grep -rn "増分 2" docs/design/` を実行し、**残存箇所が「テーマメンバー機能」だけになる**ことを確認する
2. `grep -rn "external_search" docs/design/data-model.md` で **`image_generation` が併記されている**ことを確認する
3. `grep -n "heartbeat_at\|idempotency_key" docs/design/data-model.md` で
   **`idea_evaluations` の行にも現れる**ことを確認する
4. `make check` を再実行する (件数系の連動が発生するため)

---

## 本レビューのカバレッジの正直な申告

- **全数照合していない**: 出典の照合は**抜き取り 24 件**である。DR-1 の誤りが 0 件だったため
  `feedback_review_patterns.md` の全数照合トリガー (1 件でも誤りが見つかったら) には該当しなかったが、
  **残る引用 (概算で 60 件以上) は未確認**である
- **未確認の範囲**: `aidlc-docs/aidlc-state.md` / `todo.html` の差分、`docs/prototype/` の行番号引用、
  `questions-conversation.md` の回答本文の妥当性 (ユーザー決定なので再議論しない前提)
- **薄い観点**: `plans.md` §4.1 の 8 タブの `content` 構造 (PoC の型の移植) は
  PoC 側の型定義 (`diverge/plan.go` の 8 定数と表示順) までしか照合しておらず、
  **各タブ本文の構造そのものの妥当性は見ていない** (PL-R5 が実装リポへ送っている範囲)
- **実施していない**: `templates/` 配下の雛形との整合確認 (本増分の差分に含まれないため)

---

## 反映記録 (起草側。2026-08-02)

**重大 3 件・中 4 件・軽微 8 件をすべて反映した**。`make check` は全 5 ゲート エラー 0。

| 指摘 | 反映内容 |
|---|---|
| **重大 1** (`image_generation` がスキーマ SSOT に未反映) | [../../../docs/design/data-model.md](../../../docs/design/data-model.md) §4.10 の `route_kind` 値域に追加し、**NULL 許容の CHECK を `route_kind IN ('external_search','image_generation')` の 2 値へ拡張**。§5 の O-2 行も更新。**指摘のとおり observability にだけ反映してスキーマ側を取り残していた** |
| **重大 2** (`idea_evaluations` の列不足) | `heartbeat_at` / `idempotency_key` / `failure_message` を追加し、**列名を DM-16 の共通規約に揃えた** (`job_status` → `status` 等)。索引 2 本 (`(status, heartbeat_at) WHERE …` と部分 UNIQUE `(idea_id, idempotency_key) WHERE …`) も追加。**冪等キーを `account_id` ではなく `idea_id` にした理由**を併記 |
| **重大 3** (`scope=contract` の増分境界の矛盾) | **全件を「増分 1」に統一**: `README.md` §5 の A-7 行 / API-Q3 / §6.1 の増分 2 の作業単位 / §3.8 の 1 行、`ideas.md` の 6 箇所、`plans.md` §10.4 の暫定挙動 (「解消までは 400 で拒否」を撤回)、`auth.md` §10.4 の R-9 の状態列 |
| **中 1** (版 URL の識別子の食い違い) | **揃えず、意図的な差として理由を明文化**した ([../../../docs/design/API/ideas.md](../../../docs/design/API/ideas.md) §4.2.1 を新設 / [../../../docs/design/API/plans.md](../../../docs/design/API/plans.md) D-PL-18 に適用範囲の注記)。**`idea_versions` の PK は `plan_tab_versions` / `idea_evaluations` から参照され FE に既に渡っている**ため、`ver_no` にすると識別子が 2 種類になる。**版の意味論は同一** |
| **中 2** (llm-migration の旧記述) | §2 の対応表を「API 設計は完了 (3 ファイル)」へ、§4 冒頭の「LLM 経路は 3 本」を**本数を書かず総覧へのリンク**に変更 (DR-9) |
| **中 3** (LM-R10 の受信欄不在) | `plans.md` §12.2 の受信欄に 1 行追加し、§13 に **PL-R10** として残課題化。**本書では決めきれない理由** (v2 本番 DB の実測と operations.md の RL 段の見直しが要る) を明記 |
| **中 4** (403 の本数が無検査) | **`scripts/check-endpoint-mapping.sh` に検査⑥を追加** — 総覧表の 403 列の合計 ↔ 小計行 ↔ §3 本文 ↔ §5 の A-5 行。**故障注入 2 種で検出を確認** (§5 の値を 16→15 / 総覧の ideas を 5→4)。照合は 31 → **34 件** |
| **軽微 8** (行番号ずれ) | 実測値へ是正: `idea.go:164`→`:165` (theme_id) / `idea.go:452`→`:450` / `deepdive.go:195`→`:197` (2 箇所) / `business_plan.go:817`→`router.go:165` / `schema.sql:159`→`:160`。**`ideas.md:244` の `idea.go:164` は `RequestAccountID` を指しており正しい**ため変更していない |

**レビュー後に起草側が自主的に直したもの** (レビュー対象外の時点で入れた変更):

- `plans.md` D-PL-7 の「12 ファイル・54 箇所」を削除 — **書いた時点で実測 (docs/ = 11 ファイル・53 箇所) とずれていた**。検算対象外の数値は書かず再現コマンドを示す形に変更 (DR-9)
- `architecture.md` の「9 tools」を実態 (v3 は 8 本) に合わせ、**本数を書かず [../../../docs/design/API/conversation.md](../../../docs/design/API/conversation.md) §4.1 へのリンク**に変更
- **`check-endpoint-mapping.sh` に検査⑤ (custom tool の本数) を追加** — tool の増減は D-6 の再発行を伴うため必ず起きる。故障注入 2 種で確認
- `.claude/rules/feedback_review_patterns.md` の DR-6 / DR-9 に、本増分で観測した 2 パターンを追記

**Design Freeze の可否**: 重大 3 件が解消したため、**起草側としては Freeze 可の状態と考える**。ただし
**再レビューは本反映後の差分に対して行う必要がある** (本記録は起草側の自己申告であり、
レビュー観点 1 の「自己申告の裏取り」の対象そのものである)。
