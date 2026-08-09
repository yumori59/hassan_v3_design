# 設計レビュー (4 巡目 / 3 巡目指摘の反映確認) — productionization

- **実施日**: 2026-07-31
- **レビュアー**: `design-reviewer` (別セッション。起草者ではない)
- **対象範囲**: 3 巡目レビュー (`review-round3.md`、mtime **2026-07-31 08:49:06**) 以降に変更された成果物
  (本リポジトリに `.git` が無いため `git diff` は使えず、**mtime による差分特定 + 内容照合**で範囲を確定した)
- **判定サマリ**: **重大 2 件 / 中 6 件 / 軽微 5 件**。**Freeze 条件付き不可**
  (3 巡目 重大 2 は**解消**、重大 1 は **5 箇所のうち 2 箇所が未解消**、重大 3 は別レビュアーが実施済み)

---

## 0. レビュー対象 (リポジトリ相対パス — 全件列挙)

### 0.1 3 巡目以降に変更された成果物 (mtime が 08:49:06 より後)

| パス | mtime | 本レビューでの扱い |
|---|---|---|
| `Makefile` | 20:18:03 | `check-table-counts` の配線を検査 |
| `CLAUDE.md` | 20:18:33 | 検証ゲート節の記述を検査 |
| `scripts/check-table-counts.sh` | 20:17 台 | **新設。機構としての妥当性を故障注入で検査** |
| `scripts/hooks/pre-commit` | 20:17:13 | 3 経路目の配線を検査 |
| `.github/workflows/docs-ci.yml` | 20:17 台 | 2 経路目の配線を検査 |
| `.claude/rules/05-harness.md` | 20:17 台 | 新機構を語る記述の正確性 |
| `.claude/rules/feedback_review_patterns.md` | 20:17 台 | DR-9 行の記述の正確性 |
| `docs/design/data-model.md` | 20:17:43 | `idea_tags` 新設と件数 15 箇所の反映 |
| `docs/design/architecture.md` | 20:17:43 | 件数の転記 (`:759`) |
| `docs/design/auth.md` | 09:10:09 | **件数の転記 (`:592`) のみ**。内容は別レビュアー担当 |
| `docs/design/API/idea-boards.md` | 09:10:59 | §8.2 の連動リスト (**連動箇所の SSOT**) |
| `aidlc-docs/inception/productionization/plan.md` | 20:17 台 | Task-3a のテーブル件数 |
| `aidlc-docs/aidlc-state.md` | 20:30:43 | 本増分の記録の有無 |
| `aidlc-docs/reviews/productionization/review-round3.md` | 08:49:06 | 反映の自己申告表 (§2 の入力) |
| `todo.html` | 20:30:50 | タスク status の同期 |

### 0.2 3 巡目指摘の反映 第 1 陣 (08:47〜08:48 = round3 確定の直前に編集済み。反映内容として検査)

| パス | mtime |
|---|---|
| `docs/design/testing.md` | 08:47:35 (`:101` の 6 種 → 7 種) |
| `templates/app-monorepo/.github/workflows/ci.yml` | 08:47:39 (`:102` のコメント → #4/#5/#7) |
| `docs/design/frontend.md` | 08:48:04 (§8.2 / §16.2-1 の登録済み表記) |

### 0.3 参照した (変更はないが照合に使った) 成果物

- `templates/app-monorepo/.github/workflows/ci.yml` (存在検査の実体。行範囲の実測)
- `docs/design/operations.md` / `docs/design/llm-migration.md` (3 巡目 中 1 / 中 2 の反映状況)
- `README.md` / `.claude/rules/07-quality-protocols.md` (`make check` の構成を語る記述)
- `docs/design/API/README.md` (3 巡目 重大 3 のエンドポイント総数)
- `docs/prototype/hassan_agent_prototype_v2.html` (3 巡目 中 3 / 中 4 の出典照合)

### 0.4 レビュー範囲外 (理由付き)

| 対象 | 理由 |
|---|---|
| `docs/design/API/auth-accounts.md` | **別レビュアーが 1 巡目を実施済み** (`review-auth-accounts.md` 20:28:41 / `verification-auth-accounts.md` 20:16:56)。本レビューは重複しない |
| `docs/design/auth.md` の**内容** | 別レビュアー担当。本レビューは `:592` の件数転記のみを見た |
| `docs/design/` の「未着手」stale 12 箇所 / `plan.md:12`〜`:13`・`:35`〜`:39` の AC 状態列 | **既知・別タスクで起票済み**。実測で未解消を確認したが新規指摘に挙げない |
| `.git` 不在による pre-commit / push ゲートの不作動 | **既知・別タスク**。ただし**スクリプトの内容の妥当性**は §6 で評価した |

---

## 1. 実行した検証 (出力そのまま)

### 1.1 `make check` (エラー 0 / 警告 31)

```
[doc-lint] 対象 89 ファイル / エラー 0 件 / 警告 31 件
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 47/47 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
[workflow-shell] 検査 52 ブロック / エラー 0 件
[table-counts] 実測: 機能テーブル 40 (個人 32 / 契約 8) / 分類 ①29 ②2 ③1
[table-counts] 照合 22 件 / エラー 0 件
```

**エラー 0 / 未カバー AC 0 / 件数不整合 0**。3 巡目 (`doc-lint` 対象 85→89 ファイル) から
対象が増えたのは `auth-accounts.md` とレビュー成果物 3 本の追加による。

### 1.2 警告 31 件の内訳 (依頼事項 6 の分類)

| 分類 | 件数 | 箇所 |
|---|---|---|
| **未回答 `[Answer]`** (既知) | **6** | `data-model.md:954` (DM-A2 移行範囲) / `frontend.md:1199` (FE-Q7) / `infrastructure.md:519`・`:535` (Q-INF-1/3) / `llm-migration.md:764` (LM 申し送り) / `operations.md:695` (アラート宛先) |
| **「TODO」語そのものへの反応** (ルール文書・過去 review・`design_memo.md` の取り消し線) | **25** | `design_memo.md` ×7 (`:13`・`:15`・`:20`・`:24`・`:29`・`:51`・`:150`) / `review-layering.md` ×5 / `review-operations-infrastructure.md` ×3 / `.claude/rules/05-harness.md` ×2 / `review-auth-accounts.md` ×2 / `gap-analysis.md` ×2 / `CLAUDE.md:40` / `review-round3.md:72` / `plan.md:159` / `questions.md:174` |
| **本増分 (3 巡目以降の変更) に起因するもの** | **0** | 新設・改訂した `scripts/check-table-counts.sh` / `05-harness.md` の新節 / `data-model.md` の `idea_tags` / `idea-boards.md` §8.2 はいずれも警告を増やしていない |

**3 巡目からの増分 +3 件は `review-auth-accounts.md` の「TODO」語 ×2 と `05-harness.md` の新節に伴う 1 件**で、
**設計成果物側の未確定は増えていない** (`auth-accounts.md` の未回答 `[Answer]` 3 件は**解消済み** —
3 巡目が検出した `:564`・`:576`・`:587` は現在 doc-lint に出ない)。

### 1.3 3 巡目 重大 1 の完了証拠 — `grep -rn "5 種\|6 種\|7 種" docs/design/` (28 ヒット。存在検査に関係する行のみ抜粋)

```
docs/design/testing.md:101 : | **T-N** | カバレッジ | … 代わりに **7 種の「必須テストの存在検査」を機械強制する** (§10。… **#7 = I 段のテストが `t.Skip` で自分をスキップしないこと** — 2026-07-31 追加)
docs/design/testing.md:553 : #### 9.1.1 frontend リポの機械検査 7 種の割り当て (D-2 の SSOT への登録)
docs/design/testing.md:637 : **代わりに機械強制する「必須テストの存在検査」7 種**:
docs/design/testing.md:691 : | **AC-5.2** | **回答** | … + **存在検査 7 種** (§10。#4 / #5 / #7 の実装先を `scripts/check-required-tests.sh` に確定)
docs/design/frontend.md:634: - **`testing.md` §10 への登録は完了済み** (2026-07-30 に同節が **6 種**へ拡張され本検査が
docs/design/frontend.md:635:   **#6** として登録された。2026-07-31 に I 段の `t.Skip` 禁止が **#7** として加わり現在は **7 種**)。
docs/design/frontend.md:980: | **D-2** | … 検査 7 種を CI ゲートにする。… **FE の検査を同書に登録する是正要求を §16.2-1 に出した** |
docs/design/frontend.md:995: | **FE-4** | … **`testing.md` §10 への登録は未了** (§16.2-1) |
docs/design/frontend.md:1213: 1. **FE の機械検査 7 種の実装状況と、D-2 の SSOT への登録**
docs/design/frontend.md:1237:   (同節は **#6** として登録し 6 種へ、2026-07-31 に **#7** が加わり現在 **7 種**)
docs/design/architecture.md:525: **起動時チェックと CI 検査の 2 段で検出する**。検査対象は **5 種** (1〜3 は引数側 = BE-8、…
```

**判定**: **種類数 (5/6/7 種) のドリフトは解消**。`testing.md:101` は 7 種、`frontend.md:634`〜`:635` /
`:1237` は「登録完了済み」+ 7 種、`architecture.md:525` の「5 種」は**別物** (tool schema と handler/prompt の
一致検査 = BE-8。存在検査とは無関係で誤りではない) を実測で確認した。
**ただし `frontend.md:995` が「登録は未了」・`:980` が「是正要求を出した」のまま残っている** → **重大 1 (後述)**。

### 1.4 3 巡目 重大 2 の完了証拠 — `grep -rn "39 テーブル\|39 件\|31 件\|テーブル 39\|例外 11\|40 テーブル\|32 件" docs/ aidlc-docs/` (review 配下を除く)

```
docs/design/architecture.md:759 : (テーブル 40 + 例外 11 / 設計判断 DM-1〜DM-20 / …
docs/design/data-model.md:195   : | ②-2 | … **分類① ∪ 分類② ∪ 分類③ (32 件)** で、…
docs/design/data-model.md:816   : | **A-3** … **機能テーブル 40 件すべてが `contract_id NOT NULL` + FK を持ち、個人スコープの 32 件は …
docs/design/data-model.md:1063  : | 2-2 | `account_id` を持つテーブル (32 件) が …
docs/design/auth.md:592         :    実際の適用 (40 テーブルの内訳 = 個人境界 32 / 契約境界 8) は
aidlc-docs/inception/productionization/plan.md:103 : … **テーブル 40 (全件に `contract_id`) + 例外 11**・…
docs/design/API/idea-boards.md:449〜503 : §8.2 の是正要求表 (旧値 39/31 → 新値 40/32 を記録している箇所。意図的な残存)
aidlc-docs/aidlc-state.md:39,40 : 2026-07-30 の日付付き履歴行 (当時の値 39 を記録)
```

**判定**: **解消**。
①**機械検査の期待値 2 箇所** (`data-model.md:195` = §3.3 検査②-2 / `:1063` = §7.2 検査 2-2) は **32 件**で、
`check-table-counts.sh` の実測 (個人 32) と**一致**。
②**「例外 11」は `architecture.md:759` / `plan.md:103` の両方でそのまま残っており、3 巡目の訂正
(「直してはいけない」) が守られている**。§4.1.2 を独立に数え **(a) 6 件 + (b) 5 件 = 11** を確認した。
③`idea-boards.md` §8.2 の残ヒットは旧値→新値の記録であり陳腐化ではない。
`aidlc-state.md:39`・`:40` は日付付き履歴行 (軽微 5)。

### 1.5 抜き取り照合 (8 件。**一致 8 / 不一致 0**。うち結論を左右するもの 3 件)

| # | 主張 (箇所) | 一次ソース | 結果 |
|---|---|---|---|
| 1 ★ | 機能テーブル **40 件 / 個人 32 / 契約 8**、`idea_tags` は 20 番 (`data-model.md:313`・`:339`・`:361`) | 同書 §4.1.1 の表を**スクリプトとは別の awk で独立に計数** (行 314〜360) | **一致** (40 / 32 / 8。`idea_tags` は `| 20 |` で個人・両方の所有者列) |
| 2 ★ | 検査①の除外リスト = **(a) 6 件 + 2 件 = 8 件**、例外は計 **11** (`data-model.md:195`・`:363`・`:1061`) | 同書 §4.1.2 の (a)(b) 表を実数え ((a) は `admin_accounts` / `admin_auth_roles` が 1 行 2 テーブル) | **一致** ((a) 6 / (b) 5 / 計 11 / 除外 8) |
| 3 ★ | `templates/app-monorepo/.github/workflows/ci.yml:102` のコメントが **#4 / #5 / #7** (3 巡目 中 6 の反映) | 同ファイル `:102`〜`:113` | **一致** (コメントとエラーメッセージが 3 検査で揃った) |
| 4 | 存在検査 #6 の実体は frontend `ci.yml`**:58〜71** (`testing.md:650` / `:667`) | `templates/app-monorepo/.github/workflows/ci.yml` :58 が `- name: 検査 1 …`、:71 が `exit $missing`、**:72 は空行** | **一致** (`testing.md` 側が正。`frontend.md` 側の `58-72` はずれ = 軽微 1) |
| 5 | `TestMain` の穴の根拠 = CI が常に `DATABASE_URL` を設定 (`testing.md:651` の `ci.yml:73`〜`74`) | `templates/app-monorepo/.github/workflows/ci.yml:73` = `env:`、`:74` = `DATABASE_URL: postgres://…` | **一致** |
| 6 | v2 `ideas` の列位置 (`idea-boards.md:342`・`:405`・`:406` / `data-model.md:961`) | `hassan-v2-backend/db/schema.sql` :155 `concept` / :156 `target_market` / :157 `customer` / :158 `issue` / :159 `solution` / :160 `market_size` / :161 `cagr` | **`data-model.md:961` の `concept`=:155 は一致**。`idea-boards.md` の 3 箇所は**ずれたまま** (3 巡目 中 3 が未反映) |
| 7 | `signup_links` は v2 で所有者列を持たず 5 列 (`data-model.md` §4.1.2 (b) の `schema.sql:342`) | `hassan-v2-backend/db/schema.sql:342`〜`:348` = `id uuid` / `email` / `expired_at` / `created_at` / `updated_at` | **一致** (DM-A4=B の前提が成立) |
| 8 | PoC は `ENVIRONMENT_ID` 未設定でエラー (`operations.md:325` の `domain_discovery.go:453`) | `claude_managed_agents/cmd/devui/domain_discovery.go:453` = `ENVIRONMENT_ID が .env に未設定です` | **一致** |

★ = 結論を左右する事実 (#1・#2 は **CI 検査の期待値**、#3 は 3 巡目 中 6 の解消判定)。

### 1.6 `check-table-counts.sh` の故障注入 (実際に実行。**設計成果物は書き換えず** scratchpad のコピー上で実施)

コピー先: `/private/tmp/.../scratchpad/fi/` (`docs` / `scripts` / `aidlc-docs` を丸ごとコピー)。
ベースラインは `照合 22 件 / エラー 0 件` (本番と同一)。

| 注入 | 内容 | 結果 |
|---|---|---|
| 故障 1 | §4.1.1 見出しを `40 件` → `39 件` | **検出** (`[ERROR] §4.1.1 見出しの件数: 実測 40 に対し文書は 39`) |
| 故障 2 | §4.1.1 の表に 41 行目 (個人・`contract_id` あり) を追加し、件数は一切更新しない | **検出。エラー 13 件** — 見出し / 注記 ×2 / §3.4.2 見出し / **分類①+②+③ == 個人数** / §3.3 ②-2 / §7.2 2-2 / §5 A-3 ×2 / auth.md ×2 / architecture.md / plan.md。**「3 分類への未登録」も落ちる**ため、DR-9 の発生原因 (分類側の連動忘れ) が構造的に塞がっている |
| 故障 3 | **同じ文言の 2 個目**を文末に旧値で追記 (`機能テーブル 39 件すべてが …`) | **未検出 (エラー 0 / EXIT=0)** — `pick()` が `head -1` で先頭ヒットのみを見るため。**重大 2 (c)** |
| 故障 4 | §3.3 検査②-2 の言い回しを変更 (`分類①∪②∪③ の合計 32 テーブル`) | **検出** (`実測 32 に対し文書は （空）`)。**言い換え・削除は静かに緑にならず落ちる**という良い性質 |
| 故障 5 | `auth.md` 側だけ旧値 (39 / 31) に戻す | **検出** (エラー 2 件) |

**評価**: 5 種のうち **4 種を検出**。**未検出は故障 3 (同一文言の重複) のみ**で、これは
`feedback_review_patterns.md:27` の「故障注入 3 種で検出力を確認済み」に**記載されていない盲点**である (中 3)。

---

## 2. 3 巡目指摘の解消判定 (重大 1〜3 / 中 1〜6 / 軽微 1〜4 の全件。**実測**)

| 3 巡目の指摘 | 判定 | 実測の根拠 |
|---|---|---|
| **重大 1** 存在検査の種類数ドリフト (5 箇所) | **部分解消 (3/5)。→ 本レビュー 重大 1** | 反映済: `testing.md:101` (7 種) / `frontend.md:634`〜`:638` (登録完了済み) / `frontend.md:1231`〜`:1237` (状態明示) / `ci.yml:102` (#4/#5/#7)。**未反映: `frontend.md:995` (「登録は未了」) / `:980` (「是正要求を出した」)** — 3 巡目の修正案 2・3 が指定した箇所 |
| **重大 2** §8.2 の連動リスト不完全 + 誤った是正要求 | **解消** | §8.2 が **15 箇所**へ拡張 (3 巡目指摘の 7・8・9 を含む) + 訂正ブロックで「**`architecture.md:759` の『例外 11』を直してはいけない**」を明記。**実測でも `例外 11` は両文書に残存**。さらに `check-table-counts.sh` による機械強制まで進めた |
| **重大 3** `auth-accounts.md` 未レビュー / README の総数不整合 | **解消 (別レビュアー)** | `review-auth-accounts.md` (20:28) + `verification-auth-accounts.md` (20:16) が存在。`API/README.md:323`〜`:324` = 「**合計 110** = 73 + **37**」で `auth-accounts.md` の実数と一致し、**根拠の節番号も `同書 §2` に修正済み** (3 巡目が誤りとした `§3.7` ではない)。未回答 `[Answer]` 3 件も解消 |
| **中 1** `operations.md` D-6 回答表が「`[Answer]` 待ち」 | **未反映** (既知) | `:707` = 「⑤**dev / prod で Environment を分けるかは `[Answer]` 待ち・暫定既定は「分ける」**」のまま。`:798` の OP-R8 は「解消 (2026-07-30)」で矛盾が残る |
| **中 2** `llm-migration.md:373` のプロバイダが 2 つ | **未反映** (既知) | `:373` = 「**Anthropic 主系 + Exa + Gemini (画像のみ)**」のまま (LM-D は 3 つ) |
| **中 3** `idea-boards.md` §8 の出典行番号ずれ (3 箇所) + 帰属誤り (1 箇所) | **未反映** (既知) | `:342` = `155`〜`158` = concept/customer/issue/solution (実際は :157 customer / :159 solution)、`:405` market_size = `:159` (実際 :160)、`:406` cagr = `:160` (実際 :161)、`:404` tags = `:10488` (実際 **:10487**。:10488 は `concept:`) |
| **中 4** ボード詳細モックの単数 `tag` の出典欠落 | **未反映** (既知) | `idea-boards.md` に `11950` の言及 0 件。プロトタイプ `:11950` = `{ id:"b1-i4", …, tag:"脱炭素インフラ", …}` を実測で再確認 |
| **中 5** FE-Q7 と `auth.md:554`〜`:557` の矛盾 | **未反映** (既知・ユーザー判断待ち) | `auth.md:554`〜`:557` = 「WAF の IP 許可リストで社内からのみ到達可能に…IP 制限は多層防御として併用」のまま。`frontend.md:1199` の FE-Q7 も未回答 |
| **中 6** `ci.yml:102` のコメントが #4 / #5 | **解消** | 実測 `:102` = 「(testing.md §10 の #4 / #5 / #7)」 |
| **軽微 1** `frontend.md` の `ci.yml:58-72` | **未反映。→ 本レビュー 軽微 1** | `frontend.md:632` / §16.2-1 の表 (検査 3 の行) がともに `58-72`。実測は `:58`〜`:71` (:72 は空行) |
| **軽微 2** `operations.md:323` の見出し「D-6 の未確定」 | **未反映** (既知) | `:323` = 「(D-6 の未確定)」のまま |
| **軽微 3** `data-model.md` の「除外リスト = 9 件」の誤読対策 | **未反映** (既知) | 現在 `:1014` (行が繰り上がった)。DM-A4 の**却下案 A** の説明中なので内容は正しいが「採用した B では 8 件」の補足は入っていない |
| **軽微 4** `API/README.md` の合計値の一元化 | **部分反映** | 合計値の**不整合は解消** (110 = 73 + 37) が、`:24` / `:326` / `:329` に 73・37 が再掲される構造は変わらず |

---

## 3. 重大 (Must Fix — Freeze 前に必須)

### 重大 1. `docs/design/frontend.md:995` / `:980` が「testing.md §10 への登録は未了 / 是正要求を出した」のまま — 3 巡目 重大 1 の**修正案 2・3 が未実施**で、DR-8 の **5 巡連続**再発

> **行番号の注記**: 本節の引用は **20:35 実測**。`docs/design/frontend.md` は本レビュー執筆中の **20:40:12 に並行セッションが編集**し行が +8 ずれた。
> **20:41 に再照合し、指摘は現在も成立**する — `:995` → **`:1003`** / `:980` → **`:988`** / `:632` → **`:639`** / §16.2-1 の表の検査 3 行 → **`:1234`** (§付記 参照)。

**事実 (実測)**:

- `docs/design/frontend.md:995` (FE-4 行の担保手段セル) = 「**CI の存在検査** … **実装済み**: `ci.yml`:58-72 …
  **`testing.md` §10 への登録は未了** (§16.2-1)」
- `docs/design/frontend.md:980` (D-2 行) = 「…**段とマージ条件の SSOT は `testing.md` §9 / §10**
  であり、**FE の検査を同書に登録する是正要求を §16.2-1 に出した**」— **要求が解消済みである記述が無い**
- 一方 `docs/design/testing.md:637`・`:650` は **7 種**の一覧に **#6 = FE の併置テスト存在検査 (F-C3)** を
  登録済み。同じ `frontend.md` の `:634`〜`:635` と `:1237` は「**登録は完了済み**」と書いている
  → **同一ファイル内で 2 対 2 に割れている**

**なぜ本番で問題になるか**: FE-4 (パーサーの非 export) / FE-6 (数値パーサのレンジ誤抽出) を構造で潰す唯一の
機構が、この併置テスト存在検査である。**実装リポの FE 担当者は `frontend.md` の FE-1〜FE-7 対応表 (§14 相当)
を「何を担保しなければならないか」の一覧として読む**ため、その表の FE-4 行が「SSOT に未登録」と書いていれば
「必須チェックに入れなくてよい (SSOT の外の検査)」と解釈する余地が残る。3 巡目が「1 巡分のコストを毎回払う」と
指摘した型そのもの。

**なぜ第 1 陣で漏れたか (再発防止に直結する所見)**: 反映の自己申告 (`review-round3.md:296`) は再検査 grep として
`存在検査 5 種` / `6 種の「必須テスト` / `#4 / #5` の 3 パターンを使ったと記録している。
**この 3 パターンはいずれも `:995` の「登録は未了」・`:980` の「是正要求を…出した」に一致しない** —
つまり**キーワードの選び方が構造的に取り残しを生んだ**。`06-delegation-prompts.md` の DR-8 手順が求める
「変更した**主張**のキーワード」は数値表現ではなく**状態語**であり、`未了` / `未登録` / `含まれていない` /
`是正要求を…出した` / `必要` を grep する必要があった。

**修正案 (どの節をどう書き換えるか)**:

1. `frontend.md:995` の末尾を
   「**`testing.md` §10 の #6 として登録済み** (2026-07-30。同書 `:650`。#7 追加後は 7 種のうちの #6)」へ。
2. `frontend.md:980` の末尾を
   「**登録は完了済み** (§16.2-1 の要求①。`testing.md` §10 の #6 / §9.1.1)。**残る未対応は §16.2-1 の
   要求②③のみ**」へ。**状態列を持つ表現にする** (`06-delegation-prompts.md` の「是正要求の表は状態列を持たせる」)。
3. **完了の証拠**として
   `grep -rnE "登録は未了|未登録|含まれていない|是正要求を.*出した" docs/design/frontend.md docs/design/testing.md`
   の出力を反映報告に貼る (**数値ではなく状態語で grep する**ことを次回以降の手順に加える)。
4. `.claude/rules/06-delegation-prompts.md` の「機構を直したら…」手順の 1 に
   「**キーワードは数値だけでなく状態語 (未了 / 未実装 / 未設定 / 是正要求 / 必要) も grep する**」を追記する
   (5 巡連続の再発は手順そのものの不足を示している)。

### 重大 2. `scripts/check-table-counts.sh` が**検算していない件数の族が 3 つ**あり、うち 1 つは **CI 検査の期待値** — DR-9 は塞ぎ切れていない

新機構の方向は正しい (§6 で評価)。ただし**「検算されない件数が増えると DR-9 が復活する」** という
`feedback_review_patterns.md:65` の観点で見ると、**現在すでに 3 族が検算の外**にある。

**(a) 例外・除外リストの件数 (CI 検査の期待値を含む) — 最も危険**

| 件数 | 現在の値 | 出現箇所 (実測) | 検算 |
|---|---|---|---|
| 検査①の**除外リスト** | **8 件** | `data-model.md:193` (§3.3 検査① = **CI 期待値**) / `:1061` (§7.2 検査 1 = **CI 期待値**) / `:1136` (R-DM-4) / §4.1.2 の注記 | **無し** |
| 機能テーブル以外 | **11** | `data-model.md:363` (§4.1.2 見出し) / `architecture.md:759` / `plan.md:103` / `:181` / `data-model.md:1137` (R-DM-5) | **無し** |
| (a) 所有者列を持たない | **6 件** | `data-model.md:370` (表見出し) / `:816` (§5 A-3) / `:1061` | **無し** |
| (b) 所有者列を持つ | **5 件** | `data-model.md:380` (表見出し) / `:816` | **無し** |

- **これは 3 巡目が重大と判定したのと同じ故障モード**である: 除外リストの件数は §3.3 検査① / §7.2 検査 1 の
  **期待値**であり、ずれると「設計どおりに実装した検査が必ず落ちる」。
- **この族は 24 時間以内に実際にドリフトしている**: DM-A4=B で **9 件 → 8 件**へ変わり、
  さらに「例外 11」と「除外 9」の混同が **3 巡目の指摘対象になった誤った是正要求** (`idea-boards.md` §8.2 初版)
  を生んだ。**人手で 2 回間違えた族が、機械化から漏れている**。
- **live risk**: `docs/design/API/auth-accounts.md` (別セッションで進行中) は
  `signup_links` / `account_mfa_configs` / `admin_accounts` 等の**例外表に載るテーブル**を扱っており、
  ここで 1 件増減すれば 6 / 5 / 11 / 8 の 4 つの数と 5 文書が同時に連動する。

**(b) §3.4.2 分類①の**グループ行の内訳ラベル** (`(10 件)` / `(2 件)` / `(2 件)` / `(7 件)` / `(5 件)`)**

スクリプトは分類①の**総数 29** をバッククォート名の総数から数えるが、**グループ行のラベル (`(7 件)` 等) は
一切見ていない**。`idea_tags` 追加時に「アイデア・企画書」行が 6 → 7 になったのは正しく反映されているが
(実測: `ideas` / `idea_assets` / `idea_tags` / `idea_versions` / `idea_evaluations` / `plans` /
`plan_tab_versions` = 7 ✓)、**次に忘れても緑になる**。

**(c) `pick()` の `head -1` — 同一文言の 2 個目に旧値が残っても緑** (§1.6 の故障 3 で**実証**)

**修正案 (機構への追加。いずれも既存スクリプトの延長で書ける)**:

1. **除外リスト・例外の実測値を追加する**:
   `excl_a` = §4.1.2 (a) 表のテーブル名 (バッククォート) 総数、`excl_b` = (b) 表の行数、
   `excl = excl_a + (b のうち contract_id を持たない件数)` を数え、
   §4.1.2 見出しの `11` / (a)(b) の見出しの `6`・`5` / §3.3 検査①の `8` / §7.2 検査 1 の `8` /
   `architecture.md:759` の `例外 11` / `plan.md` の `例外 11` を `expect` で照合する。
2. **グループ行のラベル検査**: 分類①の各行について
   「その行のバッククォート名の数 == 同じ行の `(N 件)`」を照合する (ラベルが無い行はスキップ)。
3. **`pick()` の多重ヒット検査**: `grep -oE … | sort -u | wc -l` が 2 以上なら
   「同一パターンが複数箇所にあり値が一致していない」を **ERROR** にする
   (値が全て同じなら通す。**先頭だけ見る現在の実装は静かに取り残す**)。
4. `$DM` が無いときの `exit 0` (`scripts/check-table-counts.sh:23`〜`:26`) を **`exit 1`** にする。
   ファイル名変更・移動で**静かに緑**になるのは BE-5 (DB 未接続フォールバック) と同型の設計。

---

## 4. 中 (Should Fix)

### 中 1. `make check` の構成を語る記述が 4 箇所で旧版 (2 本のまま) — 新機構を足したのに機構を語る文書が追随していない (DR-8)

`make check` は現在 **4 ターゲット** (`doc-lint` + `check-traceability` + `check-workflow-shell` +
`check-table-counts`。`Makefile:14` が実体)。`CLAUDE.md:40`〜`:44` は正しく 4 本を列挙しているが、以下は旧記述:

| 箇所 | 現在の記述 | あるべき記述 |
|---|---|---|
| `.claude/rules/05-harness.md:6` | 「このリポジトリの `make check` (= `doc-lint` + `check-traceability`) は」 | 「(= `doc-lint` + `check-traceability` + `check-workflow-shell` + `check-table-counts`。実体は `Makefile:14`)」。**または本数を書かず `CLAUDE.md` の検証ゲート節への参照にする** (同ファイル冒頭が「実体は CLAUDE.md が SSOT」と宣言しているのだから、ここで再掲しない方が SSOT に忠実) |
| `.claude/rules/07-quality-protocols.md:38` | 「`make check` (doc-lint + traceability)」 | 同上 (「`make check` (4 ゲート。`CLAUDE.md` の検証ゲート節)」) |
| `README.md:12` | 「`make check` # 検証ゲート (doc-lint + AC トレーサビリティ)」 | 「# 検証ゲート一式 (doc-lint / AC トレーサビリティ / workflow 構文 / テーブル件数)」 |
| `aidlc-docs/inception/construction-workflow/plan.md:144` | 「`make check` (doc-lint + check-traceability) が通る」(AC-7.1 の完了条件) | 括弧内を削るか 4 本へ |

**なぜ問題か**: `05-harness.md` は「**検証ゲートは一級の完了条件**」を定義する節であり、レビュアーと
起草者が「何が通れば完了か」を判定する場所。ここが 2 本だと、**`check-table-counts` / `check-workflow-shell` の
失敗を「make check とは別の付随チェック」と扱う余地**が生まれる。`06-delegation-prompts.md` の
「機構を直したら、その機構を語る文書を同じ差分で直す」の対象そのもの。

### 中 2. `docs/design/API/idea-boards.md` §8.2 の連動表が引用する行番号が 4 箇所ずれている (連動箇所の **SSOT** なのに辿れない)

§8.2 は「テーブルを 1 件増やしたときに何を直すか」の**唯一の実測リスト**として `05-harness.md:33` と
`feedback_review_patterns.md:27` から参照されている。反映後の実測値と照合すると:

| §8.2 の引用 | 実測の現在位置 | 内容 |
|---|---|---|
| `:360` の注記 (連動 2) | **`:361`** | 「行番号 1〜40 のうち欠番は無い (40 行)」 |
| `:814` の A-3 行 (連動 3) | **`:816`** | §5 の A-3 行 |
| `:1061` (連動 8 / §7.2 検査 2-2) | **`:1063`** (`:1061` は**検査 1** = 除外リスト 8 件の行) | **辿ると別の検査に着地する** |
| 訂正ブロックの `:362` (「機能テーブル以外の 11 テーブル」) | **`:363`** | §4.1.2 見出し |

**なぜ問題か**: 連動 7・8 は「**機械検査の期待値なので直さないと検査が必ず落ちる**」と自ら強調している行で、
そこが**別の検査 (検査 1) を指している**。次にテーブルを追加する人 (または実装リポで検査を書く人) が
`:1061` を開くと「除外リスト 8 件」の行に着き、②-2 の期待値を見落とす。

**修正案**: 表を「**反映済みの記録**」として扱う以上、①各行の引用を実測値へ更新する (`:361` / `:816` /
`:1063` / `:363`)、**または** ②行番号を落として節番号のみにする (`§3.3 の検査②-2` / `§7.2 の検査 2-2`)。
**②を推奨** — 表は今後も参照され続けるが行番号は編集ごとにずれるため、節番号 + 見出し語の方が寿命が長い。

### 中 3. `.claude/rules/feedback_review_patterns.md:27` の「故障注入 3 種で検出力を確認済み」に**内訳と既知の盲点が無い** (DR-1)

- **事実**: 同行は「(`scripts/check-table-counts.sh` が実例。**故障注入 3 種で検出力を確認済み**)」と書くが、
  **どの 3 種か・何が検出できないかの記録が無い**。
- **本レビューの実測 (§1.6)**: 5 種のうち **4 種検出 / 1 種未検出**。未検出は
  「**同一文言の 2 個目に旧値が残る**」ケース (`pick()` の `head -1`)。
- **なぜ問題か**: この行は「DR-9 は機械強制済み」(同 `:65`) の根拠として読まれる。**盲点が書かれていないと、
  レビュアーが「機械が見ているから grep 不要」と判断してこの型を見逃す**。検出力の主張は
  `07-quality-protocols.md` の原則 2 (「『同等』『完了』は検証済み主張としてのみ書く」) の対象。
- **修正案**: 同行の括弧を
  「(実例: `scripts/check-table-counts.sh`。**故障注入の内訳と既知の盲点は
  `aidlc-docs/reviews/productionization/review-round4.md` §1.6** — 同一文言の重複は検出できないため、
  **同じ文言を 2 箇所に書かない**ことを併せて規約にする)」へ。重大 2 の (c) を直せば盲点は消えるので、
  **直した後にこの文を「盲点なし」へ更新する**。

### 中 4. `.claude/rules/05-harness.md:30` の「4 文書 22 箇所に転記」が実測とずれている (**DR-9 が禁じた「検算されない N 件」を、DR-9 の説明文自身が新設している**)

- **実測**: `check-table-counts.sh` の `expect()` 呼び出しは **21 件**、うち**転記の照合は 19 件**
  (残り 2 件は `contract_id` 欠落検査と「分類①+②+③ == 個人数」の**構造検査**)。
  これに行番号の欠番検査 1 件を足して**スクリプトが表示する「照合 22 件」**になる。
  文書数は 4 (`data-model` 14 / `auth` 3 / `architecture` 1 / `plan` 1) で正しい。
- したがって「**22 箇所に転記**」は**転記ではないもの 3 件を含む**。ずれは小さいが、
  **この数自身が「検算されない転記された件数」**であり、スクリプトに照合を 1 件足すたびに陳腐化する。
- **修正案**: 「`data-model.md` のテーブル件数は **4 文書に転記されており** (件数は
  `make check-table-counts` の出力が正)、**うち 4 箇所は CI 検査の期待値** (§3.3 の検査②-1/②-2 /
  §7.2 の検査 2-1/2-2)」へ。**数を書かず出力に委ねる**のが DR-9 の自分の規約
  (「**書かずに定義元へのリンクにする**」) に忠実。

### 中 5. `scripts/hooks/pre-commit:16` の照合対象フィルタが 4 ファイル固定 — スクリプトの対象を増やしたときに手元ゲートが黙って無効化される

```
tables_staged=$(echo "$staged" | grep -E '^docs/design/(data-model|auth|architecture)\.md$|^aidlc-docs/inception/productionization/plan\.md$' || true)
```

現在の照合対象と一致しており**今は正しい**。ただし重大 2 の修正で `architecture.md` 以外
(例: `docs/design/API/README.md`・`auth-accounts.md`) の件数を照合対象に加えると、**このフィルタの更新漏れが
「手元では緑・CI で赤」を生む**。CI (`.github/workflows/docs-ci.yml:53`) は無条件実行なので致命ではないが、
pre-commit の目的 (手元で落とす) が失われる。

**修正案**: **(a)** `.md` が 1 つでも staged なら常に `check-table-counts.sh` を実行する
(所要時間はミリ秒オーダーで、フィルタする価値が無い)、または **(b)** 対象文書リストを
スクリプト側に `TARGET_DOCS=(...)` として持たせ、pre-commit がそれを読む。**(a) を推奨**。

### 中 6. `docs/design/data-model.md:816` (§5 A-3) が「`signup_links` は DM-A4=B の反映が必要」と**未完の依存を回答表に抱えたまま**

- **事実**: `:816` = 「`auth.md` §6.3 の列挙との差分は **3 件** …
  **`signup_links` は DM-A4=B の反映が必要**」/ `:1136` の R-DM-4 = 「**②の §6.3-1 の表と③・④は未対応**」。
- **なぜ問題か**: §5 は **A-3 (テナント境界) の本番観点への回答表**であり、`08-production-gates.md` が
  「ID への回答の所在」として読む場所。**AC-1.2 は `auth.md` を名指しで SSOT にしている**
  (`aidlc-docs/inception/productionization/requirements.md:59`) ため、
  **SSOT 側 (auth.md §6.3-1) が弱い規約のままだと、実装リポは `contract_id` 無しの機能テーブルを通す CI を書く**。
  これは `data-model.md` 側の記述では防げない。
- **本レビューでは `auth.md` の内容は範囲外**だが、**A-3 の回答が他文書の未反映に依存している状態**は
  Freeze 判定に直接効くため中として挙げる。
- **修正案**: R-DM-4 の②③④に**期限と担当 (どのタスクで反映するか)** を書く。
  `auth.md` は別レビュアー担当なので、**`plan.md` に「R-DM-4 の残 3 点の反映」タスクを起票**して
  宙吊りを解く (現状は「継続要求」と書かれているだけで、実行主体がどこにも無い)。

---

## 5. 軽微 (Nice to Have)

1. **`docs/design/frontend.md` の `ci.yml:58-72` が 2 箇所残っている** (3 巡目 軽微 1 の未反映)。
   実測は `templates/app-monorepo/.github/workflows/ci.yml:58`〜**`:71`** (`:72` は空行)。
   該当は `frontend.md:632` (§8.2 の「実体」) と §16.2-1 の表の検査 3 行。
   `docs/design/testing.md:650` / `:667` は `:58〜71` で正しいので、**同じ機構を指す 4 箇所のうち 2 箇所だけがずれている**。
2. **`aidlc-docs/aidlc-state.md` に本増分の記録が無い**。`check-table-counts` の grep ヒットは 0 件で、
   `idea_tags` の 15 箇所反映・3 巡目指摘の第 1 陣反映・新ゲートの追加のいずれも履歴行になっていない
   (`CLAUDE.md` は「todo.html の更新と**セット**で `aidlc-state.md` を更新する」と定めている)。
   引き渡し情報としては `CLAUDE.md:43` が新ゲートを列挙しているので致命ではない。
3. **`todo.html:436` のタスク名が「計 6 箇所」のまま** (status は完了 `2` に更新済み)。
   `CLAUDE.md` が「**既存タスクの title は変えない**」(localStorage の合流キー) と定めているため
   **変更してはいけない**。代わりに **`t("design", …, "…実測は 15 箇所 (idea-boards.md §8.2)", 2)` の
   新規行を 1 本足す**か、`aidlc-state.md` 側 (軽微 2) に実測値を残すのが筋。
4. **`docs/design/data-model.md:534` の `idea_tags` 行に移行の扱いが書かれていない**。
   「v2 に対応するタグ列・タグテーブルが無い」事実は `docs/design/API/idea-boards.md:404` の表にあるが、
   同書 §6 の移行 (DM-A2) 側から見ると **`idea_tags` は「初期は空・移行対象外」**であることが読み取れない。
   §4.6 の同行末尾に「**v2 に対応データが無いため移行対象外 (初期は空)**」の 1 語を足すと DR-3 の観点が閉じる。
   なお **D-4 の扱いは既定で決まっている** (非破壊 `CREATE TABLE` = dev のみ自動適用 / prod は承認必須。
   `docs/design/data-model.md:877` / `docs/design/operations.md:61` の OP-J)。
5. **`aidlc-docs/aidlc-state.md:39`・`:40` の履歴行が「テーブル 39 + 例外 11」のまま**。
   日付付きの履歴なので誤りではないが、`39` で grep した読者が現行値と誤読しうる。
   「(当時の値。現行は 40 — `docs/design/data-model.md` §4.1.1)」の 1 語で消える。

---

## 6. `scripts/check-table-counts.sh` の機構評価 (依頼事項 3)

### 6.1 照合対象 22 箇所の列挙方法 — **ハードコード**。新しい転記先は自動で入らない

- 実測: `expect "<説明>" "<実測値>" "$(pick '<正規表現>' <文書>)" "<出典>"` の形で **21 件がスクリプト内に
  直書き**され、`pick()` が文書側の**言い回しに依存した正規表現**で値を抜く。
  加えて行番号の欠番検査 1 件で `照合 22 件` になる。
- したがって **新しい文書・新しい言い回しで件数を書いた場合、検算対象に自動では入らない**。
  これは `feedback_review_patterns.md:65` が明示した DR-9 の復活条件であり、
  **すでに 3 族が外にある** (重大 2)。
- **一方で「既存の照合先の言い回しを変えた・消した」場合は静かに緑にならない** —
  `pick()` が空を返し `expect` が「実測 N に対し文書は (空)」で **ERROR** になる (§1.6 の故障 4 で実証)。
  **これは良い設計**: 検査の無効化には気づける。**取りこぼすのは「新規追加」だけ**である。
- **恒久対策の方向 (推奨)**: 件数を書くたびに正規表現を足す方式は伸びない。
  **文書側にマーカーを埋める方式**へ移す余地がある —
  例: `<!-- count:tables -->40 件` のようなコメント付き記法を規約にし、
  スクリプトは**マーカーを全文検索して全ヒットを実測値と照合する** (ハードコード不要 / 新規追加も自動で入る /
  `head -1` の穴も同時に消える)。導入コストは中程度だが、**転記先が 19 → 30 を超えるなら回収できる**。

### 6.2 故障注入による検出力 — **5 種のうち 4 種検出 / 1 種未検出** (§1.6 に生出力)

`scratchpad/fi/` に `docs` / `scripts` / `aidlc-docs` をコピーして実施 (**設計成果物は一切変更していない**。
実施後に本体で `bash scripts/check-table-counts.sh` を再実行し `照合 22 件 / エラー 0 件` を確認済み)。

- **強い点**: 「表に 1 行足して件数を直さない」= **13 箇所が同時に赤**になる (故障 2)。
  とくに **`分類①+②+③ == 個人スコープ数`** の恒等式検査が、
  DR-9 の実際の発生原因 (§3.4.2 の 3 分類への登録忘れ) を**直接**捉えている。設計として的を射ている。
- **弱い点**: `head -1` により**同一文言の 2 個目**を見ない (故障 3)。重大 2 (c)。

### 6.3 3 経路への配線 — **すべて済み**

| 経路 | 実体 | 判定 |
|---|---|---|
| `make check` | `Makefile:14` = `check: doc-lint check-traceability check-workflow-shell check-table-counts` / `:32`〜`:33` にターゲット | **OK** |
| CI | `.github/workflows/docs-ci.yml:53` = `run: bash scripts/check-table-counts.sh` (直前に理由コメント) | **OK** |
| pre-commit | `scripts/hooks/pre-commit:38`〜`:43` (対象ファイルが staged のときのみ) | **OK** (ただしフィルタ固定 = 中 5)。`.git` 不在で現状不作動なのは既知・別タスク |

### 6.4 機構を語る文書の追随 (`06-delegation-prompts.md` の手順) — **3 件のうち 2 件が正確・1 件に不備 + 波及漏れ 4 箇所**

| 文書 | 記述 | 判定 |
|---|---|---|
| `CLAUDE.md:43`・`:44` | `make check-table-counts` を検証ゲート一覧に追加し「上記 **4 つ**をまとめて実行」 | **正確** |
| `.claude/rules/05-harness.md:24`・`:28`〜`:38` | 新節「件数の転記を機械で見る理由」を追加。**CI 期待値 4 箇所の特定 (§3.3 ②-1/②-2 / §7.2 2-1/2-2) は実測と一致** | **概ね正確**。ただし「22 箇所に**転記**」がずれ (中 4)。また新機構を「**doc-lint が見るもの**」の表に入れているが実体は別ターゲット (表の見出しが `doc-lint` なので誤読の余地) |
| `.claude/rules/feedback_review_patterns.md:27`・`:65` | DR-9 を「機械強制済み」へ改訂し、レビュー観点を「**新しく増えた N 件が検算の対象に入っているか**」へ絞った | **方向は正しい** (本レビューはこの観点で重大 2 を検出できた)。「故障注入 3 種で確認済み」の根拠不足は中 3 |
| `README.md:12` / `.claude/rules/07-quality-protocols.md:38` / `.claude/rules/05-harness.md:6` / `aidlc-docs/inception/construction-workflow/plan.md:144` | `make check` = 2 本のままの旧記述 | **波及漏れ** (中 1) |

---

## 7. DR-8 の全数チェック (grep の生出力を証拠として貼る)

### 7.1 存在検査の登録状態を語る記述 (状態語での grep)

```
$ grep -rnE "登録は未了|未登録|§10 の 5 種|含まれていない|是正要求を.*出した" docs/ templates/ .claude/
docs/design/frontend.md:980 : … **FE の検査を同書に登録する是正要求を §16.2-1 に出した** | 登録しないと「SSOT の外にある検査」になる (§8.2)
docs/design/frontend.md:995 : … **`testing.md` §10 への登録は未了** (§16.2-1)
```

→ **2 件が旧記述として残存** (重大 1)。`docs/design/testing.md:860` の「§8.2 の『testing.md §10 の 5 種に
本検査は含まれていない』という記述は**解消済み**」は**経緯の記述**であり現状の主張ではない (残して正しい)。

### 7.2 `make check` の構成

```
$ grep -rn "doc-lint + traceability|doc-lint\` \+ \`check-traceability|上記 4 つ" (実行は個別パターン)
CLAUDE.md:44                                          : make check  # 上記 4 つをまとめて実行          ← 正
.claude/rules/05-harness.md:6                         : `make check` (= `doc-lint` + `check-traceability`)   ← 旧
.claude/rules/07-quality-protocols.md:38              : `make check` (doc-lint + traceability)               ← 旧
README.md:12                                          : make check  # 検証ゲート (doc-lint + AC トレーサビリティ) ← 旧
aidlc-docs/inception/construction-workflow/plan.md:144 : `make check` (doc-lint + check-traceability) が通る   ← 旧
```

→ **4 件が旧記述** (中 1)。

### 7.3 テーブル件数 (39 / 31 / 例外 11 / 40 / 32)

§1.4 に生出力を掲載。**設計成果物側の旧値は 0 件**、残ヒットは
①`idea-boards.md` §8.2 の旧値→新値の記録 ②`aidlc-state.md` の日付付き履歴 (軽微 5) のみ。

### 7.4 `check-table-counts` を語る記述

```
$ grep -rn "check-table-counts" CLAUDE.md .claude/ docs/ aidlc-docs/ README.md Makefile .github/ scripts/ templates/
CLAUDE.md:43 / Makefile:1,10,14,32,33 / .github/workflows/docs-ci.yml:53 /
scripts/hooks/pre-commit:38,39 / .claude/rules/05-harness.md:24,28 / .claude/rules/feedback_review_patterns.md:27,65
```

→ **配線 3 経路 + 説明 3 文書がすべてヒット**。`README.md` に言及が無い点は中 1 に含めた。

### 7.5 `idea_tags` の連動 (§8.2 の 15 箇所を実測で追跡)

```
$ grep -n "idea_tags" docs/design/data-model.md
229 : | アイデア・企画書 | `ideas` / `idea_assets` / **`idea_tags`** / … (7 件) |   ← §3.4.2 分類① (連動 8)
339 : | 20 | `idea_tags` | 個人 | `contract_id` + `account_id` | 1 | §4.6 |    ← §4.1.1 の表 (連動 2)
534 : | `idea_tags` | アイデアのタグ (**2026-07-31 追加**) | `id` | `tag` / `sort_order` | … ← §4.6 定義 (連動 9)
```

→ **表・分類・定義の 3 点セットが揃っている** (BE-10 型「読む側だけあって書く側が無い」の回避)。
件数側は `check-table-counts.sh` が 22 件を照合して 0 エラー。**§8.2 の 15 箇所は全件反映済みと判定**。

### 7.6 DR-1〜DR-9 の全件確認 (本増分について)

| # | 判定 | 根拠 |
|---|---|---|
| DR-1 出典なしの断定 | **1 件** | `feedback_review_patterns.md:27` の「故障注入 3 種で検出力を確認済み」(中 3)。設計成果物側の新規記述には出典がある (`idea_tags` の型は `asset_tags` §4.4 を参照、v2 に無い事実は `idea-boards.md:404`) |
| DR-2 本番観点の無言の省略 | **無し** | §8 のカバレッジ表を参照。`idea_tags` は A-3 / A-4 に回答、書き込み経路は Task-3p へ**先送り先を明記** |
| DR-3 既存データの不在 | **軽微 1 件** | `idea_tags` の移行上の扱いが §4.6 に無い (軽微 4)。事実 (v2 に無い) 自体は `idea-boards.md:404` に記録済み |
| DR-4 PoC 実装のコピー設計 | **無し** | 本増分に実装構造の記述は無い |
| DR-5 曖昧語の丸投げ | **無し** | `grep -nE "適切に|必要に応じて|後で検討|別途検討|要検討"` を `data-model.md` / `idea-boards.md` / `05-harness.md` / `feedback_review_patterns.md` / `check-table-counts.sh` に実行 → ヒットは `idea-boards.md:175` の**フェーズ名の引用** (「要検討 → 深掘り中 → 投資判断」) のみで判断ポイントではない |
| DR-6 AC の宙吊り | **無し** | `check-traceability` = productionization 47/47・construction-workflow 24/24。`idea_tags` は **AC-1.2** に紐付け (`data-model.md:816`) |
| DR-7 プロトタイプを仕様化 | **無し** | `tags: string[]` は **IB-Q14-1 のユーザー確定**が根拠 (`idea-boards.md` §8.1)。ただし 3 巡目 中 4 (単数 `tag` の出典欠落) は未反映のまま |
| DR-8 修正の波及漏れ | **重大 1 + 中 1 + 中 2 (計 10 箇所)** | §7.1・§7.2・中 2。**5 巡連続の再発** |
| DR-9 件数の転記 | **重大 2 + 中 4** | 機械強制は入ったが 3 族が検算外。説明文自身が新たな未検算の「22 箇所」を書いた |

---

## 8. Freeze 可否 (スコープ別) と本番観点カバレッジ

### 8.1 本増分が触れる本番観点の ID (回答 / 対象外の理由 / 未回答)

| ID | 状態 | 箇所 |
|---|---|---|
| **A-3** テナント境界 | **回答** | `data-model.md:339` (`idea_tags` は `contract_id` + `account_id`) / `:816` (§5 A-3 の回答を 40 / 32 / 8 へ更新) / `auth.md:592`。**新テーブルが「全機能テーブルに所有者列必須」の原則から逸脱していない**ことを機械検査 (§3.3 検査①) と `check-table-counts.sh` の両方で担保 |
| **A-4** 絞り込みの層 | **回答** | `idea_tags` は §3.3 の検査①②の対象。タグを対象に含める `keyword` 検索 (`idea-boards.md` §8.1) は `API/README.md:158` の「`Get*` / `List*` / `Count*` / `Search*` に所有者条件」検査の対象 |
| **A-6** LLM への越境 | **先送り先明記** | `idea-boards.md` §8.1 の「更新経路」= **`tags` の書き込み側は会話型 API 設計 (Task-3p) が定義する**。読む側だけ実装する BE-10 を明示的に避けている |
| **D-2** CI ゲート | **回答** | 設計リポ側のゲートに `check-table-counts` を追加し **3 経路 (make / CI / pre-commit)** へ配線 (§6.3) |
| **D-4** DB マイグレーション | **参照** | 非破壊 `CREATE TABLE` = **dev のみ自動 / prod は承認必須** (`data-model.md:877` / `operations.md:61` OP-J)。`idea_tags` 個別の記述は無いが分類から一意に決まる |
| **O-1〜O-7** | **本増分では該当なし** | `idea_tags` は LLM 経路・SSE 経路を増やさない。ハーネスの追加は設計リポ内部の検証であり本番の可観測性に影響しない |
| **D-6 / A-5 / O-2 / O-3** | **本増分では変更なし** (既存の回答が有効) | 3 巡目 中 1 (`operations.md:707` の D-6 回答表) は**未反映のまま** — Freeze 条件として据え置き |

### 8.2 スコープ別 Freeze 可否

| スコープ | 対象ファイル | 判定 | 条件 |
|---|---|---|---|
| **データモデル** | `docs/design/data-model.md` | **Freeze 可** | 3 巡目の条件 (機械検査の期待値であることを §8.2 に記録) は**満たされ、機械強制まで到達**。現行値は独立計数と完全一致。中 6 (R-DM-4 の残 3 点) は `auth.md` 側の反映であり本書の欠陥ではない |
| **API (6 ドメイン)** | `docs/design/API/idea-boards.md` ほか 6 本 | **条件付き可** | 3 巡目 **重大 2 は解消**。残るのは 3 巡目 中 3 / 中 4 (出典行番号 4 箇所と単数 `tag` の出典) + 本レビュー 中 2 (§8.2 の引用行番号 4 箇所)。**いずれも結論を変えないが、§8.2 は連動リストの SSOT なので中 2 は反映してから Freeze するのが望ましい** |
| **テスト戦略・フロントエンド** | `docs/design/testing.md` / `docs/design/frontend.md` | **Freeze 不可** | **重大 1** (`frontend.md:995` / `:980`)。`testing.md` 側は単独では Freeze 可 (7 種で一貫) |
| **ハーネス** | `scripts/check-table-counts.sh` / `Makefile` / `.github/workflows/docs-ci.yml` / `scripts/hooks/pre-commit` / `.claude/rules/*` | **条件付き可** | **重大 2** の (a) (**CI 期待値である除外リスト 8 件が未検算**) を入れるまでは「DR-9 を機械強制した」と言い切れない。(b)(c) と中 3〜中 5 は同じ差分で入れられる |
| **層構成・可観測性** | `docs/design/architecture.md` / `docs/design/observability.md` | **Freeze 可** (本増分での変更は `architecture.md:759` の件数のみ) | — |
| **運用・インフラ / LLM 移行** | `docs/design/operations.md` / `infrastructure.md` / `llm-migration.md` | **条件付き可 (3 巡目の条件を据え置き)** | 3 巡目 **中 1 / 中 2 が未反映**。判定は 3 巡目から変わらない |
| **API (認証・アカウント基盤) / auth.md** | `docs/design/API/auth-accounts.md` / `docs/design/auth.md` | **本レビューの範囲外** | 別レビュアーの `review-auth-accounts.md` / `verification-auth-accounts.md` に従う |

---

## 9. 良かった点

1. **`idea_tags` の 15 箇所反映が機械検査と独立計数の両方で全件一致**。
   `check-table-counts.sh` が 22 件 0 エラーであることに加え、**レビュアーが別の awk で数え直した
   40 / 32 / 8 と `idea_tags` = 20 番の位置**が一致した。3 巡目が「機械検査の期待値」と特定した
   `data-model.md:195` / `:1063` も新値。**見積りが 2 回外れた作業を 3 度目で取りこぼしゼロで完了させている**。
2. **3 巡目の「誤った是正要求」を実行しなかった**。`architecture.md:759` の「例外 11」はそのまま残り、
   `idea-boards.md` §8.2 に**訂正ブロック (11 と 8 は別の数である / 直してはいけない)** が追記されている。
   **レビュー指摘を機械的に適用せず、正しさを検証してから止めた**判断は、設計リポで最も価値の高い振る舞い。
3. **DR-9 をレビュー観点から機械強制へ格上げした**のは、このリポジトリで初めての
   「**指摘 → ルール → 機械検査**」の完走。とくに **`分類①+②+③ == 個人スコープ数` の恒等式**は、
   人手の grep が構造的に取り残す原因 (分類への登録忘れ) を**直接**捉えており、
   故障注入で 13 箇所同時検出を確認できた。**検査対象の選び方が原因分析に基づいている**。
4. **見積りが外れた経緯 (6 → 9 → 15) と外れた理由を `idea-boards.md` §8.2 に残した**。
   「`account_id` を持つテーブルを足すと §3.4.2 の 3 分類にも必ず入れる必要があり、分類①の件数が
   4 箇所に現れる」— **次に同じ作業をする人が同じ見落としをしない形**で書かれており、
   `feedback_review_patterns.md` の DR-9 行にも同じ因果が還流している。
5. **`pick()` が空を返したら ERROR になる**という性質 (故障 4)。
   「文書の言い回しを変えたら検査が静かに無効化される」という**この種のスクリプトで最も多い欠陥**を
   避けられている (`expect` に空文字を渡す設計が結果的に fail-loud になっている)。
6. **3 巡目 重大 3 が別レビュアーによる独立レビューで正しく処理された**。
   `review-auth-accounts.md` + `verification-auth-accounts.md` の 2 本立て (レビュー + 一次ソース照合の分離) で、
   `API/README.md` の総数 (110 = 73 + 37) と根拠節の誤り (`§3.7` → `同書 §2`) も同時に解消している。

---

## 総合判定

**Freeze 条件付き不可** (重大 2 / 中 6 / 軽微 5)。

- **3 巡目の 3 件のうち 2 件 (重大 2・重大 3) は解消**。**重大 1 は 5 箇所中 3 箇所のみ反映**で、
  残る `docs/design/frontend.md:995` / `:980` が「未登録・是正要求中」と主張し続けている。
- **新規の重大は 1 件** (`scripts/check-table-counts.sh` の検算漏れ 3 族。うち**除外リスト 8 件は CI 検査の
  期待値**であり、3 巡目が重大と判定したのと**同じ故障モード**)。
- **次の巡で必ず確認する項目 (次巡の入力)**:
  1. `grep -rnE "登録は未了|未登録|是正要求を.*出した" docs/design/` の出力 (重大 1 の完了証拠。
     **数値ではなく状態語で grep すること**)
  2. `bash scripts/check-table-counts.sh` の `照合 N 件` が **22 → 30 前後に増えている**こと
     (除外リスト・例外・グループ行ラベルの追加。重大 2 の完了証拠)
  3. 故障注入「同一文言の 2 個目に旧値」が**赤になる**こと (重大 2 (c) の完了証拠)
  4. `make check` の構成を語る 4 箇所 (`05-harness.md:6` / `07-quality-protocols.md:38` / `README.md:12` /
     `construction-workflow/plan.md:144`) が 4 ゲートを指していること
  5. 3 巡目 中 1〜中 5 / 軽微 1〜4 の反映 (本巡でも全件未反映)
- **未調査の範囲 (正直な申告)**: `docs/design/auth.md` の内容 (件数転記のみ確認) /
  `docs/design/API/auth-accounts.md` 全文 / `templates/` の `ci.yml` 以外のファイル /
  `docs/design/` の「未着手」stale 12 箇所と `plan.md` の AC 状態列 (既知・別タスクのため実測のみで指摘化せず) /
  Vercel の外部数値 (ネットワーク不可のため 3 巡目と同じく未照合)。

---

## 付記 1. 並行編集による行番号のずれ (2026-07-31 20:41 実測)

本レビューの引用行番号は **20:30〜20:35 の実測値**。執筆中に別セッションが
`docs/design/frontend.md` を編集 (mtime **20:40:12**、サイズ 154,459 → 158,367) したため、
**同ファイルの行番号のみ +8 ずれた**。**指摘そのものは再照合して成立を確認済み**:

| 本文の引用 | 20:41 時点の実測位置 | 内容 (変わっていない) |
|---|---|---|
| `frontend.md:995` (重大 1) | **`:1003`** | 「**[testing.md] §10 への登録は未了** (§16.2-1)」 |
| `frontend.md:980` (重大 1) | **`:988`** | 「**FE の検査を同書に登録する是正要求を §16.2-1 に出した**」 |
| `frontend.md:632` (軽微 1) | **`:639`** | 「**実体**: `ci.yml`:58-72」 |
| §16.2-1 の表 検査 3 行 (軽微 1) | **`:1234`** | 「併置テストの存在 … `ci.yml:58-72`」 |
| `frontend.md:1199` (FE-Q7 未回答) | **`:1207`** | 3 巡目 中 5 の未反映は変わらず |

**この現象自体が中 2 (行番号の引用は寿命が短い) の実例**である — 節番号 + 見出し語での参照を推奨する。

## 付記 2. `make check` の現在の状態 (本レビュー成果物を含めた再実行)

```
[doc-lint] 対象 91 ファイル / エラー 7 件 / 警告 36 件
```

**エラー 7 件はすべて本レビューの対象外ファイル**であり、**本増分にも本レビュー成果物にも起因しない**:

```
./aidlc-docs/reviews/productionization/review-auth-accounts.md: リンク切れ -> API/auth-accounts.md  (×3)
./aidlc-docs/reviews/productionization/review-auth-accounts.md: リンク切れ -> auth.md
./aidlc-docs/reviews/productionization/review-auth-round5.md:   リンク切れ -> ../auth.md
./aidlc-docs/reviews/productionization/review-auth-round5.md:   リンク切れ -> architecture.md
./aidlc-docs/reviews/productionization/review-auth-round5.md:   リンク切れ -> data-model.md
```

**原因**: 別レビュアーの成果物が**設計文書の中の相対リンクをそのまま引用**したため
(`aidlc-docs/reviews/…/` から見ると `testing.md` や `API/auth-accounts.md` は存在しない)。
本レビューでも同じ罠を踏み、**引用中のリンク記法を `` `testing.md` `` のバッククォート表記に置換して解消した**
(`bash scripts/doc-lint.sh aidlc-docs/reviews/productionization/review-round4.md` = **エラー 0**)。

**申し送り**: **設計文書の一文を review に引用するときは、Markdown リンク記法を落とす**ことを
`.claude/agents/design-reviewer.md` の出力形式に 1 行加えると、この種の CI 赤が再発しない
(**現時点で `make doc-lint` が落ちており、pre-commit を導入した瞬間にコミットできなくなる**ため、
別レビュアーの 2 ファイルの修正が必要)。

---

## 指摘の反映記録 (2026-07-31 夜・メインセッション)

**状態列を持たせる** (`.claude/rules/06-delegation-prompts.md`)。**未対応の理由も書く**。

| 指摘 | 反映先 | 状態 |
|---|---|---|
| **重大 1** (frontend.md の状態語 stale 2 箇所) | `docs/design/frontend.md` | **未対応 — 別セッションが同ファイルを編集中**のため衝突回避で触っていない (20:57 に更新を実測)。`.git` が無く復元手段が無いため、同一ファイルの並行編集を避けた |
| 同 (再発防止の手順修正) | `.claude/rules/06-delegation-prompts.md` の DR-8 手順 1 / `.claude/rules/feedback_review_patterns.md` の運用節 | **実施済み** — 「**キーワードは数値だけでなく状態語 (`未了` / `未実装` / `未設定` / `未登録` / `未着手` / `含まれていない` / `是正要求` / `必要` / `無い`) も grep する**」を追記。**5 巡連続の再発が手順側の不足だった**ことを明記 |
| **重大 2 (a)** 除外リスト・例外の件数が検算外 | `scripts/check-table-counts.sh` | **実施済み** — §4.1.2 の (a)(b) 2 表を実測し (`excl_a` / `excl_b` / `excl_b_noc`)、**機能テーブル以外の総数・除外リスト総数・§3.3 検査①・§7.2 検査 1 の期待値**を照合。**併せて `auth.md` §6.3 と `architecture.md` §4 から件数の転記を廃止**した (DR-9 の「検算に入れる **か** 書かない」のうち、動きの速い集合は書かない方を採用) |
| **重大 2 (b)** グループ行ラベルが検算外 | 同 | **実施済み** — 分類①の各行で「バッククォート名の数 == `(N 件)` ラベル」を照合 (ラベルの無い単一行はスキップ) |
| **重大 2 (c)** `pick()` の `head -1` | 同 | **実施済み** — 多重ヒット時に**末尾数値が食い違えば ERROR**。`pick()` はサブシェルで呼ばれ `errors` に加算できないため一時ファイルに記録して最後に集計する |
| **重大 2 修正案 4** `$DM` 不在時の `exit 0` | 同 `:23`〜`:28` | **実施済み** — `exit 1` へ。BE-5 と同型の「静かに緑」を排除 |
| **中 1** `make check` の構成が 4 箇所で旧版 | `.claude/rules/05-harness.md` / `07-quality-protocols.md` / `README.md` / `aidlc-docs/inception/construction-workflow/plan.md` | **実施済み** — **本数を書かず**ルート `CLAUDE.md` の検証ゲート節への参照 (または「4 ゲート」) へ |
| **中 2** §8.2 の引用行番号が 4 箇所ずれ | `docs/design/API/idea-boards.md` §8.2 | **実施済み (推奨②を採用)** — **行番号を落として節番号 + 見出し語**に統一。方針転換の理由も同節に記録 |
| **中 3** 故障注入の内訳と盲点が無い | `.claude/rules/feedback_review_patterns.md` DR-9 行 | **実施済み** — 「**故障注入 7 種で 7/7 検出**」+ 内訳の参照先 (本書 §1.6 / §6.2) + 盲点を塞いだ旨 |
| **中 4** 「4 文書 22 箇所」が実測とずれ | `.claude/rules/05-harness.md` | **実施済み** — **件数を書かず** `make check-table-counts` の出力に委ねる形へ (照合は 22 → 37 件に増えた) |
| **中 5** pre-commit のフィルタが 4 ファイル固定 | `scripts/hooks/pre-commit` | **実施済み (推奨 (a))** — `.md` が 1 つでも staged なら常に実行 (`tables_staged="$md_staged"`) |
| **中 6** §5 A-3 が未完の依存を抱える | `docs/design/data-model.md` §5 の A-3 行 / §8 の R-DM-4 | **実施済み** — R-DM-4 ①〜④を**すべて実施済み**にし (auth.md 側の反映が完了したため)、状態列を更新。`auth.md` §10.3 に受信側の記録を新設 |
| **軽微 1** `ci.yml:58-72` が 2 箇所 | `docs/design/frontend.md` | **未対応** (重大 1 と同じ理由。並行編集中) |
| **軽微 2** aidlc-state.md に本増分の記録が無い | `aidlc-docs/aidlc-state.md` | **実施済み** (履歴行を追加) |
| **軽微 3** todo.html:436 の「計 6 箇所」 | `todo.html` | **実施済み** — **既存 title は変更せず** (localStorage の合流キー)、実測値を持つ新規行を追加 |
| **軽微 4** `idea_tags` に移行の扱いが無い | `docs/design/data-model.md` §4.6 | **実施済み** — 「v2 に対応データが無いため移行対象外 (初期は空)」+ D-4 の扱い (非破壊 DDL = dev 自動 / prod 承認) |
| **軽微 5** aidlc-state.md の履歴が旧値 | `aidlc-docs/aidlc-state.md` | **実施済み** (現行値への注記) |

### 故障注入の再実行 (本反映後。scratchpad のコピー上で実施)

**7 種すべて検出 (7/7)**。従来の唯一の未検出ケース (同一文言の 2 個目に旧値) も検出するようになった。

| # | 注入内容 | 結果 |
|---|---|---|
| F1 | §4.1.2 見出しを 12 → 13 | **検出** |
| F2 | (a) 表の見出しを 7 → 6 | **検出** |
| F3 | §3.3 検査①の除外を 9 → 8 (**CI の期待値**) | **検出** |
| F4 | 分類①のグループ行ラベルを 7 件 → 6 件 | **検出** |
| F5 | §7.2 検査 1 の除外を 9 → 10 (**CI の期待値**) | **検出** |
| F6 | **同一文言の 2 個目に旧値を残す** (従来の盲点) | **検出** (多重ヒット検査) |
| F7 | 定義元ファイルを改名 | **検出** (`exit 1`) |
