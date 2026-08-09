# レビュー (2 巡目): 増分 conversation (Task-3p) — 1 巡目指摘の反映差分

> レビュー日: 2026-08-02 / レビュアー: `design-reviewer` (第三者セッション。1 巡目とは別セッション)
> 対象: 1 巡目 ([review-conversation.md](review-conversation.md)) の重大 3 / 中 6 / 軽微 8 に対する**起草側の反映差分**と、
> 反映によって生じた新たな不整合。**判定基準は本番基準** (`.claude/rules/08-production-gates.md`)
> 前提: 1 巡目の重大 3 件はすべて「**実施済みと自己申告したが実物が未反映**」型だった。
> したがって本巡は**申告文を読まず、宛先ファイルを開いて実物を確認**した

## レビュー結果サマリ

- **重大: 2 件 / 中: 6 件 / 軽微: 5 件**
- **Design Freeze: 不可 (Blocked)**。ただし 1 巡目とは性質が変わった —
  **重大 2 のうち 1 件は 1 行の修正で解消**し、もう 1 件は「本増分が反転させた決定 (D-API-8') の波及が
  API 表・FE 設計・書き込み経路に届いていない」型である
- 実行した検証:
  - **反映の実物照合 33 主張** (一致 29 / **不一致 4**)
  - `make check` (5 ゲート・エラー 0)
  - **故障注入 8 種** (検査⑤ 3 / 検査⑥ 4 / 既存検査④ 1) — うち **2 種が素通り = 検査⑥ の穴**
  - 一次ソースの抜き取り照合 **9 件** (v2 7 / PoC 2。1 巡目の 24 件とは別の箇所)

### レビューした設計成果物 (リポジトリ相対パス)

**反映差分を実物で確認したもの**

- `docs/design/data-model.md`
- `docs/design/API/README.md`
- `docs/design/API/ideas.md`
- `docs/design/API/plans.md`
- `docs/design/API/conversation.md`
- `docs/design/API/themes.md`
- `docs/design/API/assets.md`
- `docs/design/API/settings.md`
- `docs/design/API/idea-boards.md`
- `docs/design/API/auth-accounts.md`
- `docs/design/auth.md`
- `docs/design/frontend.md`
- `docs/design/llm-migration.md`
- `docs/design/observability.md`
- `docs/design/architecture.md`
- `docs/analysis/v2-feature-inventory.md`
- `scripts/check-endpoint-mapping.sh`
- `scripts/check-traceability.sh`
- `aidlc-docs/reviews/productionization/review-conversation.md` (末尾の「反映記録」= 検証対象の自己申告)

**参照のみ**

- `aidlc-docs/inception/productionization/requirements-conversation.md`
- `aidlc-docs/inception/productionization/questions-conversation.md`
- `aidlc-docs/inception/productionization/plan.md`
- `docs/design/testing.md` / `docs/design/operations.md`
- `.claude/rules/feedback_review_patterns.md` / `.claude/rules/05-harness.md`

**未確認 (本巡では見ていない)**

- `aidlc-docs/aidlc-state.md` / `todo.html`
- `docs/prototype/` の HTML と、そこへの行番号引用
- 1 巡目が「未確認」とした残り引用 (概算 60 件以上) のうち、本巡で新たに照合したのは 9 件のみ
- `templates/` 配下

---

## 1. 反映の実物照合 (最優先。33 主張)

**表の読み方**: 「主張」= `review-conversation.md` 末尾の反映記録に書かれた内容。
「実物」= レビュアーが宛先ファイルを開いて確認した結果。

### 1.1 重大 1 (`route_kind=image_generation` をスキーマ SSOT へ) — **4 主張中 3 一致 / 1 不一致**

| # | 主張 | 実物 | 判定 |
|---|---|---|---|
| 1-1 | §4.10 の `route_kind` 値域に `image_generation` を追加 | `docs/design/data-model.md:726` の値域列挙に `image_generation` あり | **一致** |
| 1-2 | NULL 許容の CHECK を 2 値へ | `docs/design/data-model.md:755`〜`:761` = `route_kind IN ('external_search','image_generation')`。追加理由も併記 | **一致** |
| 1-3 | §5 の O-2 行を更新 | `docs/design/data-model.md:926` = 2 値 | **一致** |
| 1-4 | (1 巡目の修正案②)「`:726` の**列注記**を 2 値に」 | **`docs/design/data-model.md:726` の列注記は `(**4 つとも `route_kind='external_search'` のときのみ NULL 可**)` / `stop_reason` `(同条件で NULL 可)` のまま** | **不一致 → 重大 R2-2** |

### 1.2 重大 2 (`idea_evaluations` のジョブ列) — **6 主張すべて一致**

| # | 主張 | 実物 (`docs/design/data-model.md:596`) | 判定 |
|---|---|---|---|
| 2-1 | `heartbeat_at` の追加 | あり | **一致** |
| 2-2 | `idempotency_key` の追加 | あり | **一致** |
| 2-3 | `failure_message` の追加 | あり | **一致** |
| 2-4 | 列名を DM-16 の共通規約に揃えた (`job_status`→`status`) | `status` (`queued`\|`running`\|`succeeded`\|`failed`)。旧 `job_status` / `job_started_at` / `job_finished_at` は**全文検索で残存 0 件** | **一致** |
| 2-5 | 索引 `(status, heartbeat_at) WHERE status IN ('queued','running')` | あり (J-3 の取り残し回収と明記) | **一致** |
| 2-6 | 部分 UNIQUE `(idea_id, idempotency_key) WHERE …` + キーを `idea_id` にした理由 | あり (「再評価はそのアイデアに対して 1 本で排他する」) | **一致** |

`asset_extractions` (`:516`) / `knowledge_files` (`:634`) と列名・索引の型が揃っていることも確認した。

### 1.3 重大 3 (`scope=contract` を増分 1 へ統一) — **申告した 7 箇所はすべて一致。ただし波及が未完 (R2-1)**

| # | 主張 | 実物 | 判定 |
|---|---|---|---|
| 3-1 | `README.md` §5 の A-7 行 | `docs/design/API/README.md:558` = 「**増分 1** (D-API-8'。2026-08-02 改訂)」 | **一致** |
| 3-2 | `README.md` API-Q3 | 同 `:576` = 「A-7 の判断部分はクローズ済み。…も**増分 1**。残る未確認は TH-Q5 のみ」 | **一致** |
| 3-3 | `README.md` §6.1 の「増分 2 の作業単位」 | 同 `:612` = 「**テーマメンバー機能のみ**」 | **一致** |
| 3-4 | `README.md` §3.8 の 1 行 | 同 `:513` `GET /ideas/{idea_id}` = 「個人 / 契約 (増分 1)」 | **一致** |
| 3-5 | `ideas.md` の 6 箇所 | `docs/design/API/ideas.md:68` / `:69` / `:71` / `:86` / `:108` / `:140` すべて「増分 1」。同書に「増分 2」の残存 0 件 | **一致** |
| 3-6 | `plans.md` §10.4 の暫定挙動を撤回 | `docs/design/API/plans.md:773`〜`:777` = 「増分 1 から受け付ける」「旧記述の『解消までは 400 で拒否する』は**撤回する**」 | **一致** |
| 3-7 | `auth.md` §10.4 の R-9 状態列 | `docs/design/auth.md:1546` = 「**実施済み** (2026-08-02)」 | **一致** |

### 1.4 中 1〜中 4 — **7 主張すべて一致**

| # | 主張 | 実物 | 判定 |
|---|---|---|---|
| 4-1 | 版 URL の差を `ideas.md` §4.2.1 で明文化 | `docs/design/API/ideas.md:483`〜`:499` に新設。理由 (PK が `plan_tab_versions` / `idea_evaluations` から参照される) / 共通させるもの / 「意味論は同一」まである | **一致** |
| 4-2 | `plans.md` D-PL-18 に適用範囲の注記 | `docs/design/API/plans.md:822` = 「**却下 (b) の適用範囲は企画書タブの版に限る**」 | **一致** |
| 4-3 | `llm-migration.md` §2 の「別途起草・対象外」を改訂 | `docs/design/llm-migration.md:92` = 「**API 設計は完了 (2026-08-02)** — conversation / ideas / plans の 3 ファイル」 | **一致** |
| 4-4 | 同 §4 の「LLM 経路は 3 本」を本数なしのリンクへ | 同 `:95`〜`:99` = 「本数はそこ (README §3 の総覧) が正。**本書に本数を転記しない** = DR-9」 | **一致** |
| 4-5 | LM-R10 を `plans.md` §12.2 の受信欄へ | `docs/design/API/plans.md:865` = 起票元・内容・回答先・**「受信済み・未回答 (2026-08-02)」**の状態列あり | **一致** |
| 4-6 | 同 §13 に PL-R10 として残課題化 | 同 `:883` = 判断材料 (v2 本番 DB の実測 / operations.md の RL 段) まで書かれている | **一致** |
| 4-7 | `check-endpoint-mapping.sh` に検査⑥ (403) を追加 | `scripts/check-endpoint-mapping.sh` の⑥ (総覧の 403 列合計 ↔ 小計行 ↔ §3 本文 ↔ §5 A-5 行)。**故障注入 3/3 で検出を確認** (§3 参照) | **一致 (ただし穴あり = 中 R2-M1)** |

### 1.5 軽微 8 (行番号の是正) — **7 主張中 6 一致 / 1 不一致**

一次ソースを実際に開いて照合した (v2 / PoC は読み取りのみ)。

| # | 主張 | 一次ソースの実測 | 判定 |
|---|---|---|---|
| 5-1 | `ideas.md:234` の `theme_id` を `idea.go:164`→**`:165`** | `hassan-v2-backend/controller/idea.go:165` = `ThemeIDStr: c.Query("theme_id")` | **一致** |
| 5-2 | `ideas.md:244` の `idea.go:164` は**正しいので変更しない** | 同 `:164` = `RequestAccountID: c.Query("account_id")` | **一致 (申告どおり)** |
| 5-3 | `ideas.md:314` の CSV 必須チェックを `:452`→**`:450`** | 同 `:450` = `ideaHassanIDStr := c.Query(...)`、`:451`〜`:454` が必須チェック本体 | **一致** |
| 5-4 | `conversation.md:412` の `deepdive.go:195`→**`:197`** | `claude_managed_agents/cmd/devui/conversation_tools_deepdive.go:197` = `AssetContext string \`json:"asset_context"\`` | **一致** |
| 5-5 | `conversation.md:534` の同上 | 同上 | **一致** |
| 5-6 | `plans.md:691` の `business_plan.go:817`→**`router.go:165`** | `hassan-v2-backend/router/router.go:165` = `businessPlansRoute.GET("/generate-image", …)` | **一致** |
| 5-7 | `idea-boards.md` の `schema.sql:159`→**`:160`** | `hassan-v2-backend/db/schema.sql:160` = `market_size text`。**ただし同表の次行 `:394` の `cagr` が「同:160」のまま** (実測 `:161`) | **不一致 (部分反映) → 軽微 R2-L1** |

### 1.6 レビュー後の自主変更 (本巡が初レビュー) — **5 主張中 5 一致**

| # | 主張 | 実物 | 判定 |
|---|---|---|---|
| 6-1 | `plans.md` D-PL-7 の「12 ファイル・54 箇所」を再現コマンドへ | `docs/design/API/plans.md:811` = 「**件数は書かない**…`grep -rl '8 タブ' docs/ aidlc-docs/ templates/` の出力が正」 | **一致** |
| 6-2 | `architecture.md` の「9 tools」をリンク化 | 「tool 名 → ハンドラの対応表」+「SSOT は `API/conversation.md` §4.1」+ PoC 側 9 分岐の出典は保持 | **一致** |
| 6-3 | 検査⑤ (custom tool の本数) を追加 | `scripts/check-endpoint-mapping.sh` の⑤。**故障注入 3/3 で検出を確認** | **一致** |
| 6-4 | `feedback_review_patterns.md` の DR-6 / DR-9 追記 | 差分にあり (内容の妥当性は本巡の対象外) | **一致** |
| 6-5 | `05-harness.md` の検査一覧・故障注入の記述を更新 | 差分にあり | **一致** |

### 1.7 照合結果の内訳

**33 主張中 29 一致 / 4 不一致**。

| 不一致 | 内容 | 分類 |
|---|---|---|
| 1-4 | `data-model.md:726` の列注記が `external_search` 限定のまま | **重大 R2-2** |
| 5-7 | `idea-boards.md:394` の `cagr` が `同:160` のまま (実測 `:161`) | 軽微 R2-L1 |
| — | 1 巡目 **軽 8** (`plans.md:21`〜`:23` の「`ideas.md` にリンクを張っていない理由」) が反映記録に現れず、**実物も未修正** (同ファイル `:15` は既にリンク化済み) | 軽微 R2-L3 |
| — | 1 巡目の「そのほか」(`v2-feature-inventory.md` の `GET /ideas/csv` の移設先) が未反映 | 軽微 R2-L4 |

**申告の正確さについて**: 反映記録の冒頭は「**重大 3 件・中 4 件・軽微 8 件をすべて反映した**」だが、
1 巡目の中は **6 件**であり、**中 5 (API/ 外への波及) と 中 6 (一括生成中の `tabs[].status`) は反映されていない**。
表を見れば分かるものの、冒頭の「すべて反映した」は誤読を招く (1 巡目の重大 3 件と同じ「状態の自己申告」問題)。

---

## 2. 重大 (Must Fix — Design Freeze を止める)

### 重大 R2-1. `scope=contract` / `visibility` の増分 1 化が**エンドポイント表・FE 設計・書き込み経路**に届いておらず、C-16 の中核操作 (共有の切り替え) が実装不能

1 巡目の**中 5** の続きだが、**本巡で新たに 3 つの実装不能点が判明した**ため重大に格上げする。
D-API-8' が「増分 1」で確定した今、旧記述は「保留中の案」ではなく**現行規約との矛盾**である
(1 巡目レビュー自身が同じ整理をしている)。

**(a) 可視性変更エンドポイントが「増分 2」のまま — 同一ファイル内の直接矛盾**

| 根拠 | 記述 |
|---|---|
| `docs/design/API/themes.md:55` | `PUT /themes/{theme_id}/visibility` の**増分列が `2`** |
| `docs/design/API/README.md:401` | 同エンドポイントの総覧行が**増分 `2`** |
| 対して `docs/design/API/themes.md:98` (D-TH-5) | 「**可視性 (`PUT /visibility`) と `scope=contract` は増分 1**」 |
| 対して `docs/design/API/themes.md:139` (TM-2) | 「**書き込み API (`PUT /themes/{id}/visibility`) と `scope=contract` も増分 1 で開ける**」 |
| 対して `docs/design/data-model.md:125` (DM-9) | 「**列と書き込み API の両方を増分 1 に含める**」 |

**(b) アセット: 決定行と API 表が食い違い、AS-M2 が存在しないエンドポイントを引用している**

| 根拠 | 記述 |
|---|---|
| `docs/design/API/assets.md:50` / `:54` | `scope` の説明は「**`contract` は増分 1 から有効** — C-16」なのに、**同じ行の固有ステータス列が `400` (増分 1 で `scope=contract`)** |
| `docs/design/API/assets.md:55` | `POST /assets` の `visibility` が「**増分 2 で有効**」 |
| `docs/design/API/assets.md:144` (D-AS-12) | 「書き込み経路と `scope=contract` はどちらも**増分 2**」 |
| `docs/design/API/assets.md:180` (A-4) | 「`scope=contract` (**増分 2**)」 |
| 対して `docs/design/API/assets.md:168` (AS-M2) | 「**書き込み API (`PUT /assets/{id}/visibility`) と `scope=contract` も増分 1**」← **`PUT /assets/{asset_id}/visibility` は §2 のエンドポイント表に存在しない** |

**(c) アイデア: `visibility` を設定する経路がどの API にも無い (BE-10 の設計版)**

- `docs/design/API/ideas.md:108` / `:140` — 可視性の 3 条件の 1 つが `ideas.visibility = 'contract'` (**増分 1**)。
  §1.4 の 1 クエリ評価に**読む側として組み込まれている**
- `docs/design/API/ideas.md:200` — `Idea` の応答例に `"visibility": "private"` が入っている
- **しかし** `PUT /ideas/{idea_id}` の受付項目 (同 `:71`〜`:72`) に `visibility` は無く、
  `PUT /ideas/{idea_id}/visibility` も存在しない。同書に `visibility` の書き込みに関する決定 (D-IDA-x) も無い
- `docs/design/data-model.md:125` (DM-9) は `ideas` を**書き込み API を増分 1 に含める対象**として名指ししている
- 同じ問題が `asset_folders` にもある (DM-9 の対象だが `POST/PUT /asset-folders` の項目に `visibility` が無い)

**(d) FE 設計が「BE が 400 を返す」前提のまま**

| 根拠 | 記述 |
|---|---|
| `docs/design/frontend.md:424` | 「**増分 1 では `scope` の UI を出さない** (`contract` は **BE が 400 で拒否する** — D-API-8')」 |
| `docs/design/frontend.md:425` | 「共有・可視性の UI は**増分 2 で追加**する (A-7)」 |
| `docs/design/frontend.md:996` | §14 の A-7 行が同上 |
| `docs/design/frontend.md:762` | `/themes/[themeId]/members` 行 (これは**増分 2 のままで正しい**) |

**(e) その他の残存 (決定・回答表)**

`docs/design/API/themes.md:94` (D-TH-1「`contract` の有効化は増分 2」← 同書 `:98` と矛盾) /
`docs/design/auth.md:1325` (§9 の A-7 回答表 (c) が「増分 2」← 同書 `:1281` の §6.12 (c) と矛盾) /
`docs/design/API/auth-accounts.md:703` (A-7 が「増分 2」) /
`docs/design/API/settings.md:230`〜`:234` (「`default_asset_visibility` は**増分 2 の共有機能**が読む側として要求」
← 同書 `:42` / `:128` (D-ST-3) / `:204` (A-7) は「増分 1」で自己矛盾) /
`docs/design/API/settings.md:66` / `:106` (`GET/PUT /settings/workspace` が増分 2・「`scope=contract` は 400」)

**なぜ本番で問題になるか**: C-16 の趣旨は「v2 の `POST /sharing-settings` でできていた**共有の切り替え**を落とさない」
ことである。現状の設計を読んだ実装者は、①テーマの可視性変更 API を増分 2 として実装しない
②アセットの `visibility` を「増分 2 で有効」として無視する ③アイデアの `visibility` は**そもそも設定手段が無い**
④FE は `scope` セレクタを出さない — という組み合わせに至る。
結果は「**読み取りだけ契約に開いていて、誰も共有を ON/OFF できない**」であり、C-16 は達成されない。
`ideas.visibility` に至っては**読む側 (可視性 3 条件) だけがあり書く側が無い** = `feedback_review_patterns.md` の
**BE-10 そのもの**が設計段階で作られている。

**修正案 (最小)**:

1. `themes.md:55` / `README.md:401` の増分列を `1` にする (D-TH-5 / TM-2 / DM-9 に合わせる)
2. `assets.md` に **`PUT /assets/{asset_id}/visibility` を追加する** (AS-M2 が既に引用している) か、
   `POST/PUT /assets` のボディで受ける形に AS-M2 の記述を合わせる。`:50` / `:54` の
   「400 (増分 1 で `scope=contract`)」を削除。`:55` / `:144` / `:180` を増分 1 に
3. **`ideas.md` に `visibility` の書き込み経路を決める** (`PUT /ideas/{idea_id}` の項目に足すか専用 API か)。
   決めないなら「アイデアの `visibility` は移行時の初期値のみで、切り替えは増分 2」と**明示して C-16 の例外承認を要求する**
   (現状は無言の欠落 = DR-2 と同型)
4. `frontend.md:424`〜`:425` / `:996` の「BE が 400 で拒否する」を撤回し、`scope` セレクタと
   `PUT /visibility` の導線を増分 1 に入れる (`auth.md` R-10 の内容そのもの。同時に R-10 の状態列を更新する)
5. `themes.md:94` / `auth.md:1325` / `auth-accounts.md:703` / `settings.md:230`〜`:234` / `:66` / `:106` を整合させる
6. `auth.md:1542` の前文「**反映済みは … `API/themes.md` TM-2・D-TH-5 / `API/assets.md` AS-M2 … の 4 書**」は、
   **エンドポイント表・決定行が未反映**であることを反映した記述に直す (現状は 1 巡目の重大 3 と同型の状態の虚偽記載)

### 重大 R2-2. `data-model.md:726` の列注記だけが `route_kind='external_search'` 限定のまま — 同一行内で CHECK の条件が 2 通りになっている

**根拠**:

- `docs/design/data-model.md:726` — `cache_creation_input_tokens` (**4 つとも `route_kind='external_search'` のときのみ NULL 可**) /
  `stop_reason` (**同条件で NULL 可**) ← **旧記述**
- 同 `:755`〜`:761` — 「NULL を許すのは **`route_kind IN ('external_search','image_generation')`**」+
  「**CHECK を `external_search` 限定のままにすると、設計どおり実装した明細が INSERT できず画像生成のコストが総額から丸ごと落ちる**」
- 同 `:926` — O-2 の回答表も 2 値

**なぜ本番で問題になるか**: `data-model.md` は**スキーマの SSOT** であり、実装者が DDL を書くときに
最初に読むのはテーブル定義表 (`:726`) である。列注記が `external_search` 限定のままだと、
`feature=plan.thumbnail` の行 (`docs/design/API/plans.md:458` / `docs/design/observability.md:206`) が
**CHECK 違反で INSERT できない**。これは 1 巡目の重大 1 が防ごうとした事象そのもので、
**同一ファイル内の 3 箇所のうち 1 箇所だけが取り残された** = DR-8 の 7 巡目の再発である。

**修正案**: `:726` の 2 つの括弧注記を `route_kind IN ('external_search','image_generation')` に揃える (1 行)。
**これは 1 巡目の修正案②が明示的に指定していた箇所**であり、指摘の読み落としとして扱うこと。

---

## 3. 機構の検証 (故障注入。起草側の自己申告を信じず独立に実施)

リポジトリを汚さないため `docs/` `scripts/` `aidlc-docs/` をスクラッチへ複製して実施した
(**設計成果物・スクリプトを変更していない**)。

### 3.1 検査⑤ (custom tool の本数) — **3/3 検出**

| # | 注入 | 結果 |
|---|---|---|
| FI-5a | `conversation.md` §4.1 の tool 表から `deep_dive` 行を削除 (8→7) | **exit 1**。「実測 7 に対し文書は 8」を 2 箇所 (見出し / 本文) で検出 |
| FI-5b | 見出しの自称値を「v3 8 本」→「v3 9 本」 | **exit 1** |
| FI-5c | 本文「1 本減って 8 本になる」を 7 に | **exit 1** |

### 3.2 検査⑥ (403 の本数) — **3/3 検出。ただし 2 種の穴を確認**

| # | 注入 | 結果 |
|---|---|---|
| FI-6a | 総覧表の ideas 行の 403 を 5→4 | **exit 1** (小計 / §3 本文 / §5 A-5 の 3 箇所で検出) |
| FI-6b | §5 の A-5 行「403 は合計 16 本」→ 15 | **exit 1** |
| FI-6c | 小計行の 403 を 16→15 | **exit 1** |
| **FI-6d** | **総覧「合計」行の 403 を 26→25** | **exit 0 = 素通り** |
| **FI-6e** | **ideas の 403 を 5→6 にし、小計・§3 本文・§5 を 17 へ整合させる** (内訳「R-1 (3 本) + R-2 (… = 13 本)」は 13 のまま放置) | **exit 0 = 素通り**。「**17 = 3 + 13**」という算術破綻が通る |

### 3.3 既存検査を壊していないこと

| # | 注入 | 結果 |
|---|---|---|
| FI-4 | `README.md` §3.9 (企画書) の明細から `POST /plans/{plan_id}/thumbnail` を削除 | **exit 1** (「plans.md のエンドポイント実数 == README §3.9 の明細行数: 実測 17 に対し文書は 16」) |

ベースライン (無改変) では `照合 34 件 / エラー 0 件`。**検査①〜④ は健在**で、
`DOMAINS` 配列化 (6→9 ドメイン) による退行は確認されなかった。

---

## 4. `make check` の実行結果

```
[doc-lint] 対象 101 ファイル / エラー 0 件 / 警告 38 件
  → 警告 38 件はすべて既存 (過去 review・design_memo.md の TODO 語 / 既存の未回答 [Answer] 5 件 =
    data-model.md:1059 / frontend.md:1229 / infrastructure.md:519・:535 / llm-migration.md:790 / operations.md:696)。
    本増分の新規 3 ファイルに未回答 [Answer] は 0 件
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 86/86 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
[workflow-shell] 検査 52 ブロック / エラー 0 件
[table-counts] 実測: 機能テーブル 42 (個人 34 / 契約 8) / 分類 ①31 ②2 ③1
[table-counts] 実測: 機能テーブル以外 12 (所有者列なし 7 / 所有者列あり 5) / 検査①の除外リスト 9
[table-counts] 照合 37 件 / エラー 0 件
[endpoint-mapping] 実測: auth-accounts.md 37 本 / 9 ドメイン 112 本 / settings.md §5 18 行 / custom tool 8 本 / 403 16 本
[endpoint-mapping] 照合 34 件 / エラー 0 件
```

**5 ゲートすべてエラー 0**。ただし `05-harness.md` が自ら書いているとおり
「**doc-lint が通った = 設計が正しい**」ではない — 重大 R2-1 / R2-2 はいずれも機械検査の対象外である。

---

## 5. 中 (Should Fix)

### 中 R2-M1. 検査⑥ に 2 つの穴がある (総覧「合計」行と、内訳の算術)

- **FI-6d**: 総覧表の「合計」行の 403 (`26`) は**どの検査も見ていない**。
  `sum403` (9 ドメイン = 16) + `auth-accounts` の 403 (10) = 26 の検算が無い
- **FI-6e**: `README.md:384` の「403 の 16 本 = §2.2 の R-1 (**3 本**) + R-2 (idea-boards **8 本** + ideas **5 本** = **13 本**)」
  の**内訳**と、`:553` (A-2 行の「R-2 … 13 本」) / `:298` / `:299` が無検査。合計だけ揃えれば算術破綻が通る
- **多重ヒットの盲点**: ⑤⑥ とも `grep … | head -1` で 1 件目しか見ない。
  `check-table-counts.sh` が 2026-07-31 に `pick()` の多重ヒット検査で塞いだ穴と**同型**
  (`feedback_review_patterns.md` DR-9 の「同一文言の 2 個目に旧値が残る」)

**修正案**: ①合計行 = 小計 + auth-accounts の検算を足す ②内訳の加算 (`R-1 + R-2 = 合計`、`idea-boards + ideas = R-2`) を
検算に入れるか、内訳を書かず §2.2 の表へのリンクにする ③`head -1` を多重ヒット検査に変える

### 中 R2-M2. `plans.md` §10.4 に「読み取りが契約に開くまでは」という旧前提が残っている

- `docs/design/API/plans.md:779`〜`:780` — 「`visibility` の書き込みは `PUT /plans/{plan_id}` で受ける。
  **読み取りが契約に開くまでは値を設定しても表示範囲は変わらない**」
- 同 `:773`〜`:777` は「**`scope=contract` は増分 1 から受け付ける**」と確定させている

同じ節の中で「増分 1 から開く」と「開くまでは変わらない」が併存している。撤回した暫定挙動の残骸。

### 中 R2-M3. 1 巡目の中 6 (一括生成中の `tabs[].status`) が未反映のまま

- `docs/design/API/plans.md:170` — `status` の値域に `generating` (生成中。§4.9)
- `docs/design/API/plans.md:498` — 「`plans.generating_started_at` と `generating_tab_id` の **2 列**で表す。
  **一括生成では `generating_tab_id` は `null`**」
- **一括生成中に `tabs[].status` が何を返すか (全タブ `generating` か / 完了済みは `ready` か) は未記述**

`GET /plans/{plan_id}` は切断時の回復経路 (§4.9 の 4) であり、FE はこの値で画面を描く。
実装者判断への丸投げ (DR-5)。**PL-R7 (`docs/design/API/plans.md:881`) は「タブ並行生成の要求が来たら」の話であって、
本件 (現行仕様での値) の回答ではない**。

### 中 R2-M4. `auth.md` §10.4 の前文と R-11 の状態列が実態と食い違う

- `docs/design/auth.md:1542` — 「**反映済みは data-model.md DM-9 / API/themes.md TM-2・D-TH-5 /
  API/assets.md AS-M2 / API/settings.md D-ST-3 の 4 書**」← 重大 R2-1 のとおり、
  **同じ 2 書のエンドポイント表・決定行 (D-TH-1 / D-AS-12) は未反映**
- `docs/design/auth.md:1548` — **R-11 の状態列に R-12 の対応内容が書かれている**
  (「①README §3 の総覧は `idea-boards.md` の実測 **22 本**に `GET /ideas/csv` を含んでおり…
  ②frontend.md §11.1 の `/ideas` 行に CSV エクスポートボタンを記載済み」)。
  R-11 の要求は **`auth-accounts.md` AA-D-15 の根拠差し替え**であり、状態列が別要求の回答で埋まっているため
  **R-11 が実施されたかどうかが読めない**。加えて「idea-boards **22 本**」は本増分の R-IDA-1 (4 本の移設) で
  **18 本**に変わっており、記述自体が旧値 (`make check-endpoint-mapping` の実測は 18)

### 中 R2-M5. 反映記録の「すべて反映した」が中 5 / 中 6 の未対応を覆い隠している

`aidlc-docs/reviews/productionization/review-conversation.md:558` — 「**重大 3 件・中 4 件・軽微 8 件をすべて反映した**」。
1 巡目の中は 6 件であり、**中 5 (API/ 外への波及 = 本巡の重大 R2-1) と 中 6 は未対応**。
本リポジトリの是正要求の運用 (`06-delegation-prompts.md` の「状態列を持たせる」) に照らすと、
**未対応の指摘には「未対応 + 理由 + 対応時期」を書く**べきで、無言で表から落とさない。

### 中 R2-M6. `llm-migration.md:213` に「会話型 API 設計は本ディレクトリ対象外の未着手タスク」の旧記述が残る

- `docs/design/llm-migration.md:213`〜`:215` — 「**『会話型アイデア創出の API 設計』** (`API/README.md` §0 で
  **本ディレクトリ対象外として宣言済みのタスク**。**着手は認証系 Task-3i の後** — 2026-07-31 のユーザー決定) が担う」
- 同書 `:92` は中 2 の反映で「**API 設計は完了 (2026-08-02)**」に更新済み

同一ファイル内で「完了」と「未着手」が併存している (中 2 の反映の波及漏れ = DR-8)。
`docs/design/llm-migration.md:592`〜 の LM-R10 の注 (M-8 が RL-4 のまま) は**意図的な未決として双方向に記録済み**なので問題ない。

---

## 6. 軽微 (Nice to Have)

| # | 箇所 | 内容 |
|---|---|---|
| R2-L1 | `docs/design/API/idea-boards.md:394` | `cagr` の出典が「`同:160`」。実測は `hassan-v2-backend/db/schema.sql:161` (`:160` は `market_size`)。**軽微 5 の部分反映** — `ideas.md:213` は `:160`〜`:161` で正しい |
| R2-L2 | `docs/design/API/plans.md:814` (D-PL-10 の却下案 a) | v2 の GET 出典が `controller/business_plan.go:817` のまま。実測 `:817` は `@success` 行で、GET の根拠は `:820` (`@Router … [get]`) / `router/router.go:165`。**同じ事実を直した `:691` の連動先が残った** |
| R2-L3 | `docs/design/API/plans.md:21`〜`:23` | 「**`ideas.md` にリンクを張っていない理由**…統合時にリンク化する」が旧文のまま。同ファイル `:15` は既に `ideas.md` へのリンク形式に変換済み。1 巡目の軽 8 が未反映 |
| R2-L4 | `docs/analysis/v2-feature-inventory.md:129` | `GET /ideas/csv` の v3 対応が「同名 (**idea-boards.md §2.4**)」のまま。移設先は `ideas.md` §2.6 (R-IDA-1 の連動先) |
| R2-L5 | `docs/design/API/conversation.md:16`〜`:24` | 「(2026-08-02 起草済み)」表記と直下の注が重複 (害はない。統合時の整理対象) |

---

## 7. 一次ソースの抜き取り照合 (本巡で新たに 9 件)

1 巡目が照合していない引用のうち、**本巡の差分で新規追加された load-bearing なもの**を選んだ。

| # | 主張 (箇所) | 照合 | 結果 |
|---|---|---|---|
| 1 | `docs/design/llm-migration.md` V-10 — `technology_analysis` に生成経路が無い根拠 = `converter.go:64` の「TechnologyAnalysisは未実装のため除外」 | `sed -n '60,68p' usecase/business_plan/detailed/converter.go` | **完全一致** (`:64` がそのコメント行) |
| 2 | `docs/design/API/ideas.md:234` `theme_id` = `controller/idea.go:165` | 実読 | **一致** |
| 3 | `docs/design/API/ideas.md:244` `account_id` = `controller/idea.go:164` | 実読 | **一致** |
| 4 | `docs/design/API/ideas.md:314` CSV 必須 = `controller/idea.go:450`〜`:453` | 実読 | **一致** (`:450`〜`:454` が必須チェック) |
| 5 | `docs/design/API/ideas.md:213` `market_size` / `cagr` = `db/schema.sql:160`〜`:161` | 実読 | **一致** |
| 6 | `docs/design/API/idea-boards.md:393` `market_size` = `db/schema.sql:160` | 実読 | **一致** |
| 7 | `docs/design/API/idea-boards.md:394` `cagr` = 「同`:160`」 | 実読 | **不一致** (`:161`) → R2-L1 |
| 8 | `docs/design/API/plans.md:691` GET = `router/router.go:165` | 実読 | **一致** (`GET /generate-image`) |
| 9 | `docs/design/API/conversation.md:412` / `:534` `asset_context` = `conversation_tools_deepdive.go:197` | 実読 | **一致** (schema は `pattern`/`target` のみ・handler だけが `asset_context` を読む点も再確認) |

**内容の誤りは 0 件**。行番号のずれ 1 件 (R2-L1) のみ。
1 巡目と同じく、`feedback_review_patterns.md` の全数照合トリガー (内容の誤りが 1 件でも出たら) には該当しない。

---

## 8. 頻出パターンの再確認 (差分に関係する範囲)

| ID | 判定 |
|---|---|
| DR-1 出典なしの断定 | **該当なし** (抜き取り 9 件で内容の誤り 0) |
| DR-2 本番観点の無言の省略 | **1 件** — `ideas.visibility` の書き込み経路が無いことに理由も先送り先も無い (重大 R2-1 (c)) |
| DR-3 既存データの不在 | **該当なし** (PL-R10 / R-PL-4 で v2 企画書データの移行が追跡されている) |
| DR-4 PoC 実装のコピー設計 | **該当なし** |
| DR-5 曖昧語による丸投げ | **1 件** (中 R2-M3 = 一括生成中の `tabs[].status`。1 巡目の中 6 と同じ) |
| DR-6 AC の宙吊り | **該当なし** (86/86) |
| DR-7 プロトタイプを仕様として扱う | **該当なし** |
| **DR-8 修正の波及漏れ** | **6 件** (重大 R2-1 / 重大 R2-2 / 中 R2-M2 / 中 R2-M4 / 中 R2-M6 / 軽微 R2-L1・L2)。**7 巡連続** |
| DR-9 件数の転記 | **1 件** (中 R2-M1 = 検査⑥ の穴。故障注入 2 種が素通り) |
| BE-10 書き手のいない読み手 | **1 件** — `ideas.visibility` は読む側 (可視性 3 条件) だけがあり書く側が無い (重大 R2-1 (c)) |

**DR-8 の再検査 grep (状態語 + 数値語)**:

```
$ grep -rn "増分 2" docs/design/            → 重大 R2-1 の根拠 (themes / assets / settings / frontend / auth / auth-accounts)
$ grep -rn "400 で拒否\|400 を返す" docs/design/   → frontend.md:424 / :996 が残存 (plans.md §10.4 は撤回済み ✅)
$ grep -rn "job_status\|job_started_at" docs/  → 残存 0 件 (R-IDA-2 の要求文のみ) ✅
$ grep -rn "external_search" docs/           → data-model.md:726 の列注記だけが旧記述 (重大 R2-2)
$ grep -rn "未反映\|未対応" docs/design/       → auth.md R-10 が「未対応 (並行編集)」のまま (重大 R2-1 (d) と同じ対象)
$ grep -rn "別途起草\|対象外として宣言" docs/design/llm-migration.md → :213 が旧記述 (中 R2-M6)
```

---

## 9. 良かった点

1. **重大 2 (`idea_evaluations`) の反映が期待以上**。5 列 + 索引 2 本を入れただけでなく、
   **列名を DM-16 の共通規約に揃え**、`asset_extractions` / `knowledge_files` と型が揃っている。
   冪等キーを `account_id` ではなく `idea_id` にした理由 (「再評価はそのアイデアに対して 1 本で排他」) まで書かれており、
   1 巡目が指摘した「前例と実物の食い違い」が構造的に解消された
2. **中 1 の解き方が良い**。版 URL の識別子を「揃える」ではなく「**意図的な差 + 理由 + 共通させるもの**」として
   `ideas.md` §4.2.1 に明文化し、`plans.md` D-PL-18 の却下案に**適用範囲の限定**を書き足した。
   「PK が他テーブルから参照されているか」という**判定基準**を残したので、次に版を持つドメインが増えても判断できる
3. **中 3 (LM-R10) の受信欄が機能している**。`plans.md` §12.2 に起票元・内容・回答先・状態列があり、
   §13 の PL-R10 に「本書では決めきれない理由」(v2 本番 DB の実測が要る) が書かれている。
   DR-8 の受信側の仕組みが**設計どおり動いた初の例**
4. **機構を先に直してから文書を書いている**。検査⑤ (custom tool) は 1 巡目が指摘していない自主追加で、
   独立の故障注入 3/3 で検出力を確認できた。D-6 (Agent 再発行) と結びつけた起票理由もスクリプト内コメントに残っている
5. **DR-9 の「書かずにリンクにする」が実践されている**。`plans.md` D-PL-7 の「12 ファイル・54 箇所」を
   再現コマンドに置き換え、`architecture.md` の「9 tools」を本数なしのリンクにした。
   どちらも**検算対象外の数値を減らす**方向の修正で、DR-9 の運用意図に合っている

---

## 10. Design Freeze の可否

**不可 (Blocked)。ただし 1 巡目より軽い。**

| 重大 | 性質 | 修正規模 |
|---|---|---|
| **R2-2** (`data-model.md:726` の列注記) | **設計どおり実装すると壊れる** (CHECK 違反で画像生成の明細が INSERT できない)。かつ**申告と実物の不一致** | **1 行** |
| **R2-1** (`scope=contract` / `visibility` の波及未完) | **実装スコープが一意に決まらない**。かつ**C-16 の中核操作 (共有の切り替え) が実装不能**。`ideas.visibility` は BE-10 の設計版 | 6 ファイル + 判断 1 件 (アイデアの `visibility` 書き込み経路) |

### Freeze 可にするための最小の修正

| # | 修正 | 対象 |
|---|---|---|
| 1 | `route_kind` の列注記を 2 値へ | `docs/design/data-model.md:726` |
| 2 | 可視性変更エンドポイントの増分列を 1 に | `docs/design/API/themes.md:55` / `docs/design/API/README.md:401` |
| 3 | アセットの `visibility` 書き込み経路を確定 (`PUT /assets/{id}/visibility` を追加するか AS-M2 の記述を合わせる) + `:50` / `:54` の 400・`:55` / `:144` / `:180` の増分 2 を是正 | `docs/design/API/assets.md` |
| 4 | **アイデアの `visibility` 書き込み経路を決める** (増分 1 で開けるなら API を足す / 開けないなら C-16 の例外承認要求として明記する) | `docs/design/API/ideas.md` |
| 5 | FE の「BE が 400 で拒否する」前提を撤回し、`auth.md` R-10 の状態列を更新 | `docs/design/frontend.md:424`〜`:425` / `:996` / `docs/design/auth.md:1549` |
| 6 | 決定・回答表の残存を是正 | `docs/design/API/themes.md:94` / `docs/design/auth.md:1325` / `docs/design/API/auth-accounts.md:703` / `docs/design/API/settings.md:66`・`:106`・`:230`〜`:234` |
| 7 | `auth.md` §10.4 の前文 (「4 書は反映済み」) と R-11 の状態列を実態に合わせる | `docs/design/auth.md:1542` / `:1548` |

**中 6 件は Freeze の条件にしない**。ただし **中 R2-M1 (検査⑥ の穴) は次の増分が始まる前に塞ぐ方が安い** —
穴のある検査は「検算済み」という誤った安心を生み、DR-9 が静かに復活する
(FI-6e で「17 = 3 + 13」が通ることを実証した)。

### 再レビュー時の確認方法 (3 巡目の効率のため)

1. `grep -rn "増分 2" docs/design/` の残存が **`theme_members` / `/themes/[themeId]/members` / `/settings/workspace` (ST-Q8) だけ**になること
2. `grep -n "external_search" docs/design/data-model.md` の**全ヒットに `image_generation` が併記**されていること
3. `grep -rn "visibility" docs/design/API/ideas.md` に**書き込み経路の決定**が現れること
4. `grep -rn "400 で拒否\|BE が 400" docs/design/frontend.md` が **0 件**になること
5. `make check` の再実行 (件数系の連動が発生する)

---

## 11. 本レビューのカバレッジの正直な申告

- **全数照合していない**: 出典の照合は**本巡 9 件**(1 巡目 24 件と合わせて 33 件)。
  内容の誤りが 0 件だったため全数照合トリガーには該当しないが、**残る引用は未確認**である
- **未確認の範囲**: `aidlc-docs/aidlc-state.md` / `todo.html`、`docs/prototype/` の行番号引用、
  `.claude/rules/feedback_review_patterns.md` / `05-harness.md` の追記内容の妥当性 (差分の存在のみ確認)、
  `templates/` 配下
- **薄い観点**: `conversation.md` §4.5 の台帳フィールドの書き手・読み手の対応 (1 巡目が確認済みとして再検証していない)、
  `plans.md` §4.1 の 8 タブ本文の構造 (1 巡目と同じく PL-R5 の範囲として扱った)
- **実施した機械検証**: `make check` 5 ゲート / 故障注入 8 種 (うち 2 種が素通り = 中 R2-M1 の根拠)

---

## 反映記録 (起草側。2026-08-02)

**重大 2 件・中 6 件・軽微 5 件のうち、Freeze 条件の重大 2 件と指摘された軽微を反映した**。
`make check` は全 5 ゲート エラー 0 (endpoint-mapping は **36 件**へ増加)。

| 指摘 | 反映内容 |
|---|---|
| **R2-2** (`data-model.md:726` の列注記が 1 値のまま) | 列注記を **`route_kind IN ('external_search','image_generation')`** に是正。`stop_reason` の「同条件」も 2 値を指すことを明記。**同一行内で CHECK の条件が 2 通りになっていた**という指摘のとおり |
| **R2-1** (`scope`/`visibility` の増分 1 化が API 表・FE・書き込み経路に未達) | ①[../../../docs/design/API/themes.md](../../../docs/design/API/themes.md) §2 の `PUT /themes/{theme_id}/visibility` を増分 **2 → 1**、**D-TH-1 の「`contract` の有効化は増分 2」も是正** ②[../../../docs/design/API/README.md](../../../docs/design/API/README.md) §3.1 の同行も 1 へ ③themes / assets の**固有ステータス「400 (増分 1 で `scope=contract`)」4 箇所**を「`scope` の値域外」に是正 ④[../../../docs/design/API/assets.md](../../../docs/design/API/assets.md) の `POST /assets` の `visibility` を「増分 1 から有効」へ、**AS-M2 が参照していた存在しない `PUT /assets/{id}/visibility` を実在の経路 (`POST`/`PUT /assets` の body) に差し替え** ⑤[../../../docs/design/frontend.md](../../../docs/design/frontend.md) の「増分 1 では `scope` の UI を出さない (BE が 400 で拒否)」を撤回 ⑥[../../../docs/design/data-model.md](../../../docs/design/data-model.md) の「増分 1 では常に `private` が入る」を撤回 |
| **R2-1 の核心** (`ideas.visibility` に書き込み経路が無い = BE-10 の設計版) | **`PUT /ideas/{idea_id}` の body に `visibility` を追加**し、§1.3 の直後に**書き込み経路と「この経路が無いと C-16 に違反する」理由**を明記。あわせて **§4.1 に「`visibility` だけの変更では版を切らない」**を追加 (共有範囲の切り替えで版が増えると企画書の stale 判定が内容の変化なしに outdated になる = BE-4 の誤検知) |
| **中 R2-M1** (検査⑥ の穴 2 種) | **`scripts/check-endpoint-mapping.sh` に検査⑦ を追加** — ①総覧「合計」行の 403 == 小計 + 認証 ②本文の内訳の算術 (R-1 + R-2 == 合計)。**指摘された 2 種で故障注入し、いずれも `exit 1` を確認**。照合は 34 → **36 件** |
| **中 R2-M4** (`auth.md` §10.4 の前文が実態と違う) | 前文を「反映済み (2026-08-02 時点)」の実態リストに書き換え、**2 巡目レビューで「判断文だけ直してエンドポイント表・FE・書き込み経路が未反映だった」ことが判明した経緯**を残した |
| **軽微** | [../../../docs/design/API/idea-boards.md](../../../docs/design/API/idea-boards.md) の `cagr` を `schema.sql:161` へ / [../../../docs/design/API/plans.md](../../../docs/design/API/plans.md) 冒頭のリンク注記を実態へ / [../../../docs/analysis/v2-feature-inventory.md](../../../docs/analysis/v2-feature-inventory.md) の `GET /ideas/csv` の移設先を `ideas.md` §2.6 へ |

**反映していないもの (Freeze 条件外)**: 中 6 件のうち R2-M1 / R2-M4 以外の 4 件。
`check-table-counts` の `head -1` 多重ヒットの盲点は**同型の問題として認識している**が、
本増分の差分ではないため次の増分で扱う。

**この反映記録も自己申告である** — 1 巡目・2 巡目とも「実施済みの申告」から重大指摘が出ているため、
**3 巡目のレビューでは本記録の実物照合を最優先観点にすること**。
