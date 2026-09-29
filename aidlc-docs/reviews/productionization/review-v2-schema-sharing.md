# レビュー: v2 既存 `public` スキーマ共有への方針転換 (2026-09-24)

レビュー対象: docs/design/data-model.md, docs/design/infrastructure.md, aidlc-docs/inception/productionization/questions.md, docs/design/operations.md, docs/design/auth.md, docs/design/architecture.md, aidlc-docs/inception/productionization/plan.md, aidlc-docs/schedule-2026q3.md

- 範囲: 未コミットの作業ツリー差分 (`git diff HEAD` のうち上記 8 ファイル。`docs/design/frontend.md` / `docs/design/testing.md` はスコープ外)
- レビュアー: design-reviewer (別セッション・第三者視点・本番基準)
- 重大 4 件 / 中 9 件 / 軽微 4 件

---

## 対応状況 (2026-09-24。同一セッションが修正を適用)

**重大 4 件はすべて修正済み**:

| # | 対応 |
|---|---|
| 重大 1 (superset 規範が列止まり) | **fixed** — §6.4② の規範を「列」から「制約・インデックス名・`EXTENSION`・enum 全値」へ拡張。事実誤認 (別経路になる) も訂正 |
| 重大 2 (A-3 の断定崩壊) | **fixed** — §3.3 に検査①' (NOT NULL 例外は `activity_logs`/`event_logs` の 2 件に限定) を新設。§4.10 の対応表で `contract_id` を「列として確定 (NULL 許容)」に固定 (実装判断の余地を除去)。A-3 (§5) の文言を修正 |
| 重大 3 (§6.6 が撤回済み P-3 前提) | **fixed** — §6.6 を全面改訂。共有テーブルへの列追加・enum 値追加 (不可逆) を明示し、v3 専用テーブルのみ旧原則が残る形に整理 |
| 重大 4 (回答済み/未回答の並存 3 組) | **fixed** — §4.2 冒頭の `[Answer]:` 行・§6.4②末尾の①注記・R-DM-10 (register_admin_password_requests) の 3 箇所を訂正 |

**中 9 件のうち 8 件を修正、1 件は是正要求として起票**:

| # | 対応 |
|---|---|
| 中 5 (DM-A4 `[Answer]`・`:XXX` プレースホルダ) | **fixed** |
| 中 6 (P-2 / DM-A2 / DM-A3 / §6.4 見出しが未確定のまま) | **fixed** (`plan.md` の `Task-2f` 記述のみ R-DM-13 に追加して起票) |
| 中 7 (architecture.md:1054 / operations.md:589 に P-1 残存) | **fixed** — operations.md は直接修正 (純粋な事実反映)。architecture.md は R-DM-13 に追加して起票 (内容判断を伴うため他書は編集しない原則を優先) |
| 中 8 (§4.1.2 前文が撤回済み 5 点を根拠) | **fixed** |
| 中 9 (INF-X⑥ / §5.3 が INF-X 確定前) | **fixed** |
| 中 10 (enum 値追加が PG バージョン依存) | **fixed** — infrastructure.md §11.3 の未調査事実に確認条件を追加 |
| 中 11 (`v3_` 物理名/論理名で検査が壊れる) | **fixed** — §7.2 に正規化の手順を明記 |
| 中 12 (R-DM-12/14 が条件付き・37 件が DR-9 違反) | **fixed** — file:line を明記し、件数は再現コマンドに置き換え |
| 中 13 (§4.2 新規約の前提・NOT NULL DEFAULT の曖昧さ) | **fixed** — 前提を明記し「NULL 許容の列追加のみ可 (DEFAULT の有無を問わず NOT NULL にしない)」に確定 |

**軽微 4 件のうち 2 件を修正、2 件は情報共有のみ**:

| # | 対応 |
|---|---|
| 軽微 14 (§7.2 検査 6 の対象列が食い違う) | **fixed** |
| 軽微 15 (§8.4 仮定 5 が撤廃済み規約を参照) | **fixed** — クローズ済みとして整理 |
| 軽微 16 (auth-accounts.md の token_hash 前提が広範) | **no_change_needed (この場では)** — R-DM-10 の射程確認情報として記録に留める。auth-accounts.md 自体は編集対象外 |
| 軽微 17 (INF-Y の出典が issue URL のみ) | **no_change_needed (この場では)** — 実害が小さいとレビュー自身が評価しており、追加対応はしない |

**検証**: `make doc-lint` (エラー 0 / 警告 61)・`make check-table-counts` (照合 37 件 / エラー 0)・
`make check-endpoint-mapping` (照合 44 件 / エラー 0)・`make check-traceability` (150/150 カバー)
をすべて修正後に再実行し、0 エラーを確認済み。**`make check-template-sync` は本差分と無関係な
既存の不整合 (`templates/shared/.claude/rules/feedback_review_patterns.md`) で失敗したままであり、
未解消**。

---

## ① 総評

**重大事項あり。この差分のままでは push すべきでない。**

方針転換そのもの (v2 の `public` を共有する / identity は v2 の実テーブルをそのまま使う /
衝突 7 本を `v3_` に改名する / log 2 本は共用する) は、オーナー決定の内容として questions.md
`[Answer 5]` と INF-X に正確に反映されており、意図の取り違え・解釈の拡大は**見当たらなかった**。
一次ソースの抜き取り照合 12 件はすべて一致した (§⑥ に一覧)。

問題は次の 3 種類に集中している:

1. **v2 の稼働中 DB に対する技術的な安全性の論証が不足している** — psqldef の drop 対象を
   「テーブル」と「列」だけで評価しており、**インデックス・FK/CHECK 制約・EXTENSION・enum 値**を
   見落としている (重大 1)。sqldef v1.0.7 のソースで確認した。
2. **本番観点 A-3 (テナント境界) とロールバック (DR-3 / D-3) の不変条件が、方針転換で崩れたまま
   断定が残っている** (重大 2・3)。
3. **DR-8 (波及漏れ) が文書内・文書間で多発している** — 同一ファイル内に「回答済み」と
   「未回答のまま残る」が並存する箇所が 3 組 (重大 4)、撤回済みの前提を根拠に使っている節が
   4 箇所 (中 5・6・8)。**本差分で編集した段落の直上に矛盾文が残っている例** (architecture.md:1054)
   まである (中 7)。

---

## ② 重大な指摘 (Must Fix)

### 重大 1. `docs/design/data-model.md:1474-1482` — psqldef の superset 規範が「列」しか見ておらず、v2 のインデックス・FK/CHECK・EXTENSION が本番で DROP される

§6.4② の帰結規範 1 は次のように書かれている:

> **v3 の `schema.sql` における共有テーブルの定義は、v2 の `schema.sql` の全**列**を含む superset
> でなければならない** (列を減らすと v3 の psqldef が v2 の列を DROP する)

**sqldef v1.0.7 の実測では、DROP されるのは列だけではない。**

| DROP 対象 | 生成箇所 (sqldef v1.0.7) | `--enable-drop-table` で抑止されるか |
|---|---|---|
| インデックス (共有テーブル上、desired に無いもの) | `schema/generator.go:252-270` → `:1106` | **されない** |
| FK 制約 | `schema/generator.go:236-239` / `:1090-1096` | **されない** |
| CHECK 制約 | `schema/generator.go:293-300` | **されない** |
| 排他制約 / POLICY | `schema/generator.go:242-249` / `:284-290` | **されない** |
| VIEW / MATERIALIZED VIEW | `schema/generator.go:304-315` | **されない** |
| **EXTENSION** | `schema/generator.go:316-323` | **されない** |
| 列 | `schema/generator.go:272-282` | されない (§6.4② が唯一認識している) |
| テーブル | — | される (`database/database.go:69-72` — 本書の記述は正しい) |

具体的な帰結 (すべて v2 の稼働中 prod DB):

- v2 は `CREATE EXTENSION IF NOT EXISTS "uuid-ossp"` (`hassan-v2-backend/db/schema.sql:1`) を持ち、
  `accounts.id` / `event_logs.id` 等の `DEFAULT uuid_generate_v4()` が依存している。
  **v3 の `schema.sql` がこの extension を宣言していなければ、v3 の psqldef は `DROP EXTENSION "uuid-ossp"` を発行する**。
  依存オブジェクトがあるので実際にはエラーで apply 全体が落ちる (= prod のマイグレーションが止まる) か、
  条件次第で v2 の既定値が壊れる。どちらにせよ**共有 DB への初回 apply が成功する保証が無い**。
- `accounts` の `unique_accounts_email` / `idx_accounts_contract_id` (`同:49-50`) と
  `fk_contracts_accounts_contract_id` / `fk_auth_roles_accounts_auth_role_id` (`同:45-46`) は、
  **v3 の `schema.sql` が同名で宣言していなければ DROP される**。照合は**制約名・インデックス名の一致**で
  行われる (`containsString(convertIndexesToIndexNames(...))`) ため、v3 が別の命名規則で同等の制約を
  書いていても DROP + CREATE になる。**メールのグローバル一意が一瞬でも消えると、§4.2 DM-A5 補足 5
  (メールアドレスの永久占有) の前提もテナント境界も同時に崩れる**。
- enum についても同型の穴がある。`generateDDLsForCreateType` (`schema/generator.go:1017-1022`) は
  **`len(current) < len(desired)` のときだけ** `ALTER TYPE ADD VALUE` を出す。したがって
  §6.4①(a) の「`event_type_enum` に 6 種を値追加する」を成立させるには、**v3 の `schema.sql` が
  v2 の `event_type_enum` の全値 (`hassan-v2-backend/db/schema.sql:372-465`) を含む superset を
  宣言している**必要がある。これも「列の superset」検査では検出できない。

**修正案**: 規範 1 を「**列・列の型/NOT NULL/DEFAULT・インデックス (名前を含む)・FK/CHECK/排他制約
(名前を含む)・enum 型の全値・EXTENSION**」に拡張し、「機械検査の対象にする方針」の検査要件も同じ
集合に広げる。加えて、**共有 DB への初回 apply は必ず `--dry-run` の出力を人間が確認する**ことを
`operations.md` §7.4 の規則 5 と `templates/shared/.claude/rules/04-human-checkpoints.md` の
承認対象に含める (現状は「DDL は v3 の psqldef からのみ流す」としか書いていない)。

### 重大 2. `docs/design/data-model.md:1267` (§5 A-3) / `:381-405` (§4.1.1) / `:231` (§3.3 検査①) — A-3 の不変条件「機能テーブル 42 件すべてが `contract_id NOT NULL` + FK」が、共用する log 2 本で成立しなくなっている

本差分で §5 の A-3 行は件数だけ 44→42 に更新されたが、断定は残っている:

> **機能テーブル 42 件すべてが `contract_id NOT NULL` + FK を持ち、個人スコープの 34 件は `account_id` も持つ**

一方、同じ差分で追加された §6.4①(a) は:

- `activity_logs`: 「`contract_id` / `target_type` / `target_id` / `request_id` は `log_detail` (jsonb) に
  **畳むか NULL 列で足すかは実装側の判断**」
- `event_logs`: 「**`contract_id uuid NULL` を追加**。v2 行の契約は `accounts` を JOIN して解決 (バックフィルしない)」

としている。つまり **A-3 の回答 (AC-1.2 の担保) と §6.4① の決定が正面から矛盾している**。しかも:

- §3.3 の検査① / §7.2 の検査 1 の**除外リストは 8 件のまま**で、`activity_logs` / `event_logs` を含まない。
  実装すると**設計どおりに実装した検査が必ず落ちる** (DR-9 が警告している形そのもの)。
  実装リポは落ちた検査を弱める方向に倒れやすく、その場合 **A-4 の唯一の機械的防御が消える**。
- `contract_id` が「`log_detail` に畳まれ得る」状態では、**監査ログのテナント絞り込みを
  Repository のクエリ条件で強制できない** (P-6 / auth.md §6.4)。他テナントの監査ログが
  `GET /activity-logs` に混ざるかどうかが実装判断に委ねられている。これは A-3/A-4 の本番観点として
  受け入れられない。
- 「NULL 列で足すか `log_detail` に畳むかは実装側の判断」は **DR-5 (曖昧語による実装者への丸投げ)**。
  テナント境界を左右する選択を実装判断に置いてはいけない。

**修正案**: (a) `activity_logs` / `event_logs` の `contract_id` を **NULL 許容の実列 + インデックス**と
設計で確定させ (jsonb への畳み込みは却下案として理由を書く)、(b) §3.3 / §7.2 の検査①の除外リストに
「**v2 と共用するため `NOT NULL` にできない 2 件 (v2 の既存行が契約を持たないため)**」という第 3 の
例外区分を新設して有限列挙し、(c) §5 の A-3 行の断定を「機能テーブル 42 件のうち 40 件は
`contract_id NOT NULL` + FK、共用 2 件は NULL 許容 + アプリ側不変条件」に改める。
(d) `make check-table-counts` の検算対象にこの新区分を加える (加えないと DR-9 が再発する)。

### 重大 3. `docs/design/data-model.md:1680-1686` (§6.6) — ロールバックの成立条件が、撤回済みの P-3 を根拠にしたまま残っている

§6.6 は未改訂で、次のように書かれている:

> | **移送したデータ** | **v3 側を捨てるだけで成立する** (v2 のデータを書き換えないため。**P-3** / ...) |

しかし **P-3 (「移行は v2 → v3 の一方向コピーで、v2 のデータを書き換えない」) は本差分の
`:54` で撤回されている**。新方針では v3 は v2 の実テーブルに対して:

1. **列を追加する** (`accounts.deactivated_at` / `signup_links.contract_id` / `signup_links.token_hash` /
   `activity_logs.actor_type` / `event_logs.contract_id` / `event_logs.detail` /
   `contracts.default_*_visibility` / `accounts.notify_*`)
2. **enum に値を追加する** (`activity_log_type` / `event_category_enum` / `event_type_enum`)。
   **PostgreSQL の enum は値を削除できない** — これは原理的に不可逆な変更である
3. **v2 の行を書き換える** (`DELETE /accounts/{id}` が `deactivated_at` と **`last_locked_at` を
   同一 UPDATE で立てる** = §4.2 論点 4。`last_locked_at` は v2 のサインインが見る列であり、
   **v3 の操作が v2 の挙動を直接変える**)
4. **共有テーブルに v3 の行を書く** (`activity_logs` / `event_logs` / `reset_password_requests.hash` に
   ダイジェストを書く)

したがって「v3 側を捨てるだけで成立する」は**もはや偽**である。§6.5 の新回答は切り戻しについて
「v3 が発行した招待・リセットリンクが v2 では受諾できない」という 1 点しか挙げていないが、
実際には上記 3 の `last_locked_at` の書き込みが**切り戻し後の v2 に残り、無効化したユーザーが
v2 からもロックされたまま**になる (これは意図どおりだが、切り戻し時には「v2 に戻せば元通り」では
なくなることの明示が要る)。

**修正案**: §6.6 のロールバック表を新方針で書き直す。少なくとも
①列追加は残置してよい (v2 は無視する) ②**enum 値追加は不可逆であることを明記** ③v3 が書いた
共有 log 行の扱い (残す / `actor_type` で除外して読む) ④`last_locked_at` の書き込みが v2 に残ること
⑤`reset_password_requests.hash` に v3 のダイジェストが混在したまま残ること、を表に入れる。
`operations.md` §6.4 (切り戻し告知) への是正要求 (R-DM-13) にもこの 4 点を追加する。

### 重大 4. 同一ファイル内に「回答済み」と「未回答」が並存している (DR-8) — 3 組

実装リポの開発者はどちらを正として読めばよいか判断できない。3 組とも**本差分で作り込まれたもの**。

| # | 箇所 | 矛盾 |
|---|---|---|
| a | `docs/design/data-model.md:485` vs `:509` | `:485` の `[Answer]: **論点 1 (enum → text) のみ回答済み (2026-09-22)。論点 2〜4 は未回答のまま残る**` に対し、`:509` は `**論点 2〜4: 回答済み (2026-09-22)。§4.2 の [Answer] はこれで 4 論点すべて埋まる**` |
| b | `docs/design/data-model.md:1484` vs `:1394` | `:1394` が `① **テーブル名の衝突 — [Answer]: 回答済み (2026-09-23)**` なのに、`:1484` に**空の `[Answer]:`** + `**①テーブル名の衝突は未回答のまま残る**`。**`make doc-lint` の警告 2 件 (`data-model.md:1484` / `:1505`) のうち `:1484` は本差分が新規に増やしたもの** |
| c | `docs/design/data-model.md` R-DM-10 (§8.3) vs `:534` | R-DM-10 は「**`register_admin_password_requests.token` → `token_hash` の改名 (auth.md:785 等) は今回の回答の対象外 — 未確定のまま**」と書くが、§4.2 の対応表 `:534` は「**2026-09-23 回答済み: 論点 3 と同じ扱いに揃える。改名せず v2 の `token` 列をそのまま使う。`auth.md:785` 等への是正要求は R-DM-10 に含める (改名しない旨に更新)**」。**R-DM-10 の本文が更新されないまま「R-DM-10 に含める」と書かれている** |

**修正案**: a・c は新しい方 (回答済み) に統一。b は「①も 2026-09-23 に回答済み」であれば空の
`[Answer]:` ブロックごと削除する (`doc-lint` の警告も同時に消える)。**残す場合は
「未回答」ではなく「②の決定は①を解消しない」という注記に書き換える**。

---

## ③ 中程度の指摘 (Should Fix)

### 中 5. `docs/design/data-model.md:1631` (DM-A4 の `[Answer]`) が `contract_id NOT NULL` のまま / `:533` に `:XXX` のプレースホルダが残存

- `:1631` の `[Answer]: **B — `contract_id NOT NULL` + FK を持たせる**` は未改訂。§4.2 論点 2
  (`:520-529`) が「`contract_id uuid NULL` + FK。`NOT NULL` は v3 アプリ側の不変条件」に改訂したので矛盾する。
- §3.3 検査① (`:231`) と §7.2 検査 1 の `(accounts / companies / signup_links は除外しない — DM-A4=B)`
  も、`NOT NULL` 前提の DM-A4=B を参照している。検査①の定義 (「`contract_id` を**持つ**こと」) 自体は
  NULL 許容でも通るが、**根拠として指している DM-A4=B が旧記述**なので読み手が追えない。
- `:533` に `**DM-A4=B (:XXX 相当) は本回答に伴い改訂**` — **`:XXX` はプレースホルダのまま**。
  `doc-lint` は `TODO`/`TBD`/`FIXME` しか見ないため検出されない。実際の行番号は `:1631`。

### 中 6. P-2 / §8.1 DM-A2・DM-A3 / §6.4 の見出しが「未確定」のまま (§6.5 が閉じたはず)

§6.5 の新回答 (`:1576-1578`) は「**P-2 (データ引き継ぎの要否・範囲) を閉じる**。…`Task-2f` は**不要**」
と明記した。しかし:

| 箇所 | 現状 |
|---|---|
| `docs/design/data-model.md:53` (P-2) | 「**データ引き継ぎの要否・範囲…は事業判断待ち**」のまま |
| `docs/design/data-model.md:1392` (§6.4 見出し) | 「**未確定 — 対象と写像が決まっていない**」のまま |
| `docs/design/data-model.md:1505` | 空の `[Answer]:` (doc-lint 警告)。直前の本文も「Q-1 の残りと `Task-2f` 待ち」 |
| `docs/design/data-model.md` §8.1 DM-A2 | 「既存データの引き継ぎ範囲 / **`[Answer]`。「引き継がない」前提では設計していない**」のまま |
| `docs/design/data-model.md` §8.1 DM-A3 | 「アカウント基盤の二重化 (5 点) / **推奨を提示済み**」のまま (§6.5 で全面撤回済み) |
| `aidlc-docs/inception/productionization/plan.md` | Task-2f の記述が未更新 (本差分の変更はテーブル件数 1 行のみ) |

`06-delegation-prompts.md` の「**状態語 (`未了`/`未確定`/`未対応`) も grep する**」手順が
実行されていない典型。

### 中 7. `docs/design/architecture.md:1054` / `docs/design/operations.md:589` — P-1 (相乗りしない) が残存。しかも architecture.md は**同じ段落を本差分で編集している**

- `architecture.md:1054`: 「**Q-1 の方向確定 (v3 は全て新規・v2 の DB に相乗りしない) を受けて**…」
  → 直後の `:1055` を本差分で 44→42 に編集している。**同じ段落を触りながら矛盾文を残した** (DR-8 の教科書例)。
- `operations.md:589`: 「**v3 の資源 (インフラ / DB / スキーマ) は全て新規で、v2 の DB には相乗りしない**」
  + 「したがって移行は v2 → v3 の一方向コピーであり、v2 のデータを書き換えない」(= 撤回済みの P-3)。

`questions.md` `[Answer 5]` (`:69`) 自身が「**この 2 箇所は…別途起票が必要**」と書いているが、
**起票された R-DM-11〜14 のどれもこの 2 箇所を対象にしていない** — R-DM-13 が挙げるのは
`architecture.md` の **D-7 段階リリース**と `operations.md` の **§6.2 の「移送の 4 規則」**であって、
`architecture.md` §4 冒頭・`operations.md` §6.2 **冒頭**ではない。**是正要求の受信側が存在しない
まま放置されている** (DR-8 の受信欄の問題)。

### 中 8. `docs/design/data-model.md:418-421` (§4.1.2 前文) が、撤回された §6.5 の 5 点を根拠にしている

> **列挙はこの 2 表で確定である** — 前提だった `docs/design/auth.md` §10.2 R-1 … は
> **2026-07-31 に回答済み** (§6.5 の DM-A3 = 推奨 5 点すべてで確定。①v3 を正とする ②RL-3 の最初に移行
> ③移行中は v2 のアカウント更新系を数分停止 ④資格情報は 1 回コピーのみで同期しない ⑤切り戻しは v2 を使う)。

この 5 点は §6.5 の再回答 (`:1562-1575`) で**全面的に置き換えられている** (①「正」の概念が消える
②移行なし ③不要 ④同期の概念も消える ⑤改善する)。**例外列挙の確定根拠が消えた**ことになるので、
新前提で「なぜこの 2 表で確定と言えるか」を書き直す必要がある。

併せて `:432` (§4.1.2 (a)) の `register_admin_password_requests` — 「未認証経路から **`token_hash`** で
引く」も、改名撤回 (§4.2 論点 3 / `:534`) と矛盾する (列名は `token` のまま)。

### 中 9. `docs/design/infrastructure.md:114` (INF-X ⑥) と `:385-386` (§5.3) が INF-X 確定前の記述のまま

- INF-X ⑥: 「**`--enable-drop` 等の抑止設定は未確認**。…**この論点は本書では決めない** —
  data-model.md §6 の Q として置く」。**data-model.md §6.4② は 2026-09-22 に回答済み**
  (sqldef v1.0.7 の既定挙動を実測し、「共有テーブルの DDL の SSOT は v3 の schema.sql / v2 の
  psqldef は停止」を決定)。機構側が決まったのに文書が「未確認」のまま = `06-delegation-prompts.md`
  の「機構を直したら、その機構を語る文書を同じ差分で直す」違反。
- §5.3 環境対応表 `:385` / `:386`: DB 列が「**v2 の既存 RDS インスタンス (スキーマ追加。INF-V)**」。
  INF-X では**スキーマを追加しない** (v2 の `public` をそのまま使う)。「スキーマ追加」という語と
  `INF-V` への参照の両方が誤り。**この 2 行は本差分でアセットストレージ列を足すために編集されている**
  ので、やはり「触った行の隣を直していない」形。

### 中 10. enum 値追加の成立が v2 RDS の PostgreSQL バージョンに依存する — 未検証のまま断定している (DR-1)

§6.4①(a) と DM-4 は「**sqldef は schema.sql の enum 定義差分から `ALTER TYPE ... ADD VALUE` 自体を
生成する** (`schema/generator.go:1019-1022`)」を根拠に、log 系の値追加を安全としている。
生成される点は実測で確認した (一致)。しかし:

- sqldef は生成した DDL を**トランザクション内で実行する**。非トランザクション実行に回すのは
  DDL 文字列に `concurrently` を含む場合だけである (`database/database.go:90-92`)。
- **PostgreSQL 11 以前は `ALTER TYPE ... ADD VALUE` をトランザクションブロック内で実行できない**
  (エラーになる)。PG12 以降は可能だが「同一トランザクション内で新しい値を使えない」制約が付く
  (DM-4 の却下理由①が言及しているとおり)。
- **v2 RDS のエンジンバージョンは未調査**である — `questions.md` `[Answer 4]` の「残作業」に
  「v2 の実 RDS インスタンス種別・**エンジンバージョン**…の調査 (§11.3)」と明記されている。

つまり「値追加は psqldef が自動で流せる」は**前提未検証の断定**。PG11 以前なら log 系の enum 値追加は
psqldef 経由では一切流せず、§6.4①(a) の設計 (v2 の enum に値追加して共用する) が成立しない。

**修正案**: §6.4①(a) に「**この設計は v2 RDS が PostgreSQL 12 以降であることを前提とする。
未検証 (infrastructure.md §11.3 の残作業)。11 以前なら log 系の共用は再検討**」を明記する。

### 中 11. `v3_` の物理名/論理名の二重運用が、設計が実装リポへ渡す機械検査を壊す (DR-10)

§6.4①(b) は「**§4 の各節は論理名のままで記述を続ける**」「**実装リポでは sqlc/repository 層が
物理名を吸収する**」と決めた。転記爆発を避ける判断自体は妥当だが、**同じ構造変更が無償で成立
させていた担保が 1 つ外れている**:

§7.2 が実装リポへ渡す検査 1 / 2-2 / 5 / 6 は、いずれも「**スキーマ定義中のテーブル名**」を
`§4.1.1` / `§4.1.2` / `§3.4.2` の**論理名リスト**と突き合わせる形で定義されている。
改名後は schema.sql 側が `v3_themes` / `v3_ideas` / `v3_assets` / `v3_asset_documents` /
`v3_idea_boards` / `v3_idea_board_phases` / `v3_read_news_accounts` になるため、
**そのまま実装すると 7 件が「一覧に無いテーブル」として検出されるか、逆に一覧側の 7 件が
「存在しないテーブル」として無視される**。どちらに倒れても検査が骨抜きになる
(§3.3 の検査① = AC-1.2 の唯一の機械的担保)。

**修正案**: §7.2 に「**検査は物理名を `v3_` を剥がして論理名へ正規化してから照合する**」という
1 行を足す (または §6.4①(b) の一覧を検査の入力として渡す形にする)。**代償欄 (DR-10) に
「改名によって論理名ベースの検査の名前解決が 1 段増える」ことを明記する**。

### 中 12. R-DM-12 / R-DM-14 が「〜があれば」の条件付きで、実際のヒットを特定していない (DR-5) + R-DM-12 の「37 件」は DR-9 違反

- R-DM-14 は「(`workspace_settings` / `account_notification_settings` の保存先の記述**があれば**)」
  「(observability.md) (テーブル数を数えている箇所**があれば**)」「(API/knowledge.md) (**該当なければ対象外**)」
  と書いている。**実測すれば確実にヒットする**:
  - `docs/design/API/settings.md:227` — **A-3 の回答行**が「v3 が新設する `account_notification_settings` /
    `workspace_settings` / `activity_logs` / `event_logs` は、それぞれ `account_id` / `contract_id` を…」と
    廃止済みのテーブル名を挙げている。**本番観点 A-3 の回答が 2 文書で食い違う状態**になる。
  - `docs/design/API/settings.md:159` (D-ST-8) — 「`eval_criteria_settings` (所有者列 = `contract_id` = **PK**)」。
    §4.9 が PK を `(contract_id, ver_no)` の版積みに改訂したので誤り。
  - `docs/design/API/ideas.md:752` / `:898` / `:1034` / `:1049` も `eval_criteria_settings` を単一行前提で
    参照している (「契約行があれば」の読み方が版積みで変わる)。
  条件付きの起票は受け取り側に再調査を強いる。**ヒット箇所を file:line で列挙して起票する**こと。
- R-DM-12 の「**37 件の言及を機械的に洗い出したのみ**」は、DR-9 が明示的に禁じた
  「数えた値を書く」形。**再現コマンド (`grep -rn '`themes`\|`ideas`\|…' docs/design/API/`) を書く**
  のが本リポジトリの規約。

### 中 13. §4.2 の新規約 (「NULL 許容または `DEFAULT` 付きの列追加のみ可」) の安全性の論証が 2 点不足

新規約 (`:583-598`) の根拠は「v2 の sqlc 生成コードは `SELECT *` を列名に展開済みで `INSERT` も列明示
(`hassan-v2-backend/db/rdb/theme.sql.go:74` 等)」。**この事実は実測で確認した** (一致。
`db/queries/*.sql` 側には `SELECT *` が多数あるが、生成済み Go は列展開されている)。ただし:

1. **この安全性は「v2 が `sqlc generate` を再実行しない」または「v2 の `schema.sql` が凍結されている」
   ことに依存する**。凍結の決定は §6.4② にあるが、**§4.2 の規約本文には条件として現れていない**。
   規約だけを読んだ実装者は依存関係に気づけない。§4.2 の規約に「(前提: v2 の `schema.sql` は
   §6.4② により参照用に凍結されている)」を添えるべき。
2. 「**NULL 許容または `DEFAULT` 付きの列追加のみ可**」と「**`NOT NULL` の追加は不可**」が同居しており、
   **`NOT NULL DEFAULT x` の列追加が可なのか不可なのか読めない** (DR-5)。技術的には
   `NOT NULL DEFAULT` の列追加は v2 の列明示 INSERT を壊さないので可にできるが、**どちらかに決めて
   書く**こと。

---

## ④ 軽微な指摘

### 軽微 14. §7.2 検査 6 の対象列表が §6.4①(a) と食い違う

`docs/design/data-model.md` §7.2 の検査 6 の表は `activity_logs` の検査対象列を **`actor_id`**、
対象外を「`account_id` / `session_id` / `theme_id`」としている。§6.4①(a) は
「**`actor_id` は v2 の `account_id` をそのまま使う**」と決めたので、表の対象/対象外が入れ替わる。
§4.10 冒頭の注記は「下表 (§4.10 の列定義) は §6.4①(a) が正」と書いているが、**§7.2 の表は
その注記の射程外**にある。

### 軽微 15. §8.4 仮定 5 が撤廃済みの規約を参照

「その場合は `accounts` に無効化フラグを持つ必要があり、**§4.2 の「v2 の列を変えない」方針が変わる**」
— この方針は本差分の `:583` で撤廃された。仮定 5 自体はクローズしてよい (DM-Q2 が回答済み)。

### 軽微 16. `docs/design/API/auth-accounts.md` 側の `token_hash` 前提が広範囲に残る (R-DM-10 の射程確認)

R-DM-10 は起票済みだが、実際のヒットは以下のとおり広い。起票時に列挙しておくと受け取り側が楽になる:
`:626` / `:643` / `:670` (シーケンス図)・`:774` `GetSignupLinkByTokenHash`・`:775`
`GetResetPasswordRequestByTokenHash` (「v2 の `hash` 列を **`token_hash` へ改名**」と明記)・`:777`
`GetRegisterAdminPasswordRequestByTokenHash`・`:1153` (「R-AA-5 … **実施済み**」)・`:1210`。
`docs/design/auth.md:785` / `docs/analysis/v2-feature-inventory.md:64` も同様。

### 軽微 17. INF-Y の出典が GitHub issue の URL のみ

`docs/design/infrastructure.md:115` の根拠が実装リポの issue #377 のコメント URL で、
`doc-lint` の参照実在チェックが届かない。決定内容は本文に要約されているので実害は小さいが、
**オーナー決定の一次証跡が外部サービス依存**である点は記録しておく (`questions.md` に
`[Answer]` として書き写す形が本リポジトリの規約)。

---

## ⑤ 良かった点

1. **一次ソースの精度が高い**。抜き取り照合 12 件はすべて一致した (下表)。特に
   `request_reset_password.go:59-62` の「`hash` は名前に反して平文」という発見は、
   **秘密の保存形の設計 (論点 3) の結論を左右する事実**であり、正しく効いている。
2. **DM-4 の理由付けを自ら訂正した点** (「値追加が別経路になるので噛み合わない」→ 誤り。
   sqldef が `ALTER TYPE ADD VALUE` を生成する)。**誤った根拠を消して結論だけ残す**のではなく、
   訂正の経緯と正しい理由 (却下 (a) の①②) に絞り直しているのは良い。
3. **`deactivated_at` + `last_locked_at` の同時セット** (§4.2 論点 4) — 「v2 のサインインは
   `deactivated_at` を見ない」という穴を実コード (`sign_in.go:71-74`) から特定し、機構で塞ぎ、
   **塞げない残りの穴 (v2 管理画面からのロック解除) を運用注記として明記**している。
   A-6/A-1 の考え方として正しい。
4. **§6.4①(b) で物理名の SSOT を 1 箇所に限定**し、§4 全体の書き換え (= DR-9 の転記爆発) を
   意図的に回避した判断。理由も明記されている。
5. **§4.9 の 17 テーブル最終判定**が、却下理由を 4 つの型 (①概念が v2 に無い ②カーディナリティ
   ③親が `v3_` 別テーブル ④参照先が v2 に無い) に整理して全件示している。
6. **却下案を推測で埋めていない** (INF-Y の却下 (a) に「却下の理由自体はオーナー回答に記載が無い」
   と DR-1 を明示して書いている)。

---

## ⑥ 実行した検証

### make check 系の結果

| コマンド | 結果 |
|---|---|
| `make doc-lint` | **対象 123 ファイル / エラー 0 件 / 警告 60 件**。うち `data-model.md:1484` の「未回答の `[Answer]:`」は**本差分が新規に増やしたもの** (重大 4-b)。`data-model.md:1505` は既存 (中 6)。 |
| `make check-table-counts` | **実測: 機能テーブル 42 (個人 34 / 契約 8) / 分類 ①31 ②2 ③1 / 機能テーブル以外 11 (所有者列なし 6 / 所有者列あり 5) / 検査①の除外リスト 8。照合 37 件 / エラー 0 件** |
| `make check-endpoint-mapping` | **実測: auth-accounts.md 46 本 / 9 ドメイン 114 本 / settings.md §5 18 行 / custom tool 8 本 / 403 17 本 / CSV 16 列。照合 44 件 / エラー 0 件** |
| `make check-traceability` | **construction-workflow 25/25 / productionization 125/125 — 未カバー 0** |
| `make check-workflow-shell` | 検査 0 ブロック / エラー 0 件 |
| **`make check` (全体)** | **失敗 (exit 1)**。`check-template-sync` が `templates/shared/.claude/rules/feedback_review_patterns.md` の本文が SSOT (`.claude/rules/feedback_review_patterns.md`) と非同期であることを検出。**本差分起因ではない** (`git status --porcelain .claude templates` は空 = HEAD 時点から存在する既存の不整合) が、**「全ゲート緑」とは報告できない**。push 前に別途解消すること。 |

> 件数系 (DR-9) の転記は**機械検査が 42 / 34 / 8 / 31 / 2 を正として緑**であり、
> 44→42・35→34・9→8・3→2 の転記は `auth.md:750` / `architecture.md:1055` / `plan.md:124` を含めて
> 整合している。**件数の転記漏れは検出されなかった**。ただし重大 2 のとおり、
> **検算が通っていることと A-3 の不変条件が成立していることは別問題**である
> (検算は「表の行数と転記」を見ており、「`NOT NULL` かどうか」は見ていない)。

### 一次ソースの抜き取り照合 (12 件 — すべて一致)

| # | 設計側の主張 | 照合先 | 結果 |
|---|---|---|---|
| 1 | `activity_logs` は v2 に `id bigserial` / `account_id uuid` NULL 可・FK 無し / `log_type` enum / `log_detail` jsonb / `created_at` | `hassan-v2-backend/db/schema.sql:482-489` | **一致** |
| 2 | `event_logs` は `uuid DEFAULT uuid_generate_v4()` PK / `account_id NOT NULL` FK CASCADE / enum 2 列 / `created_at` | `同:586-597` | **一致** |
| 3 | `reset_password_requests.hash` は名前に反して平文 (`RandStringRunes(32)`) | `hassan-v2-backend/usecase/account/request_reset_password.go:59-62` | **一致 (結論を左右する事実)** |
| 4 | v2 のロックは 5 回失敗 / `last_locked_at` 非 NULL で即拒否 / 自動解除なし | `同 usecase/account/sign_in.go:15-16` / `:71-74` | **一致** |
| 5 | `signup_links` に `contract_id` は無い | `db/schema.sql:342-348` | **一致** |
| 6 | `accounts` に `deactivated_at` / 無効化列は無い | `db/schema.sql:30-47` | **一致** |
| 7 | `register_admin_password_requests.token varchar(255) NOT NULL UNIQUE` | `db/schema.sql:504` | **一致** |
| 8 | `asset_documents` は v2 が `uuid` PK | `db/schema.sql:510-515` | **一致** |
| 9 | `accounts.email` はグローバル一意 | `db/schema.sql:49` | **一致** |
| 10 | v2 の psqldef は人が手で流す (`Makefile`) | `hassan-v2-backend/Makefile:24-26` | **一致** |
| 11 | sqldef は `--enable-drop-table` 無しで `DROP TABLE` を `-- Skipped` にする | `sqldef@v1.0.7 database/database.go:69-72` | **一致** |
| 12 | sqldef は enum 差分から `ALTER TYPE ... ADD VALUE` を生成する | `sqldef@v1.0.7 schema/generator.go:1017-1022` | **一致**。ただし `len(current) < len(desired)` の条件付き (重大 1) であり、**実行はトランザクション内** (`database/database.go:90-92` — 中 10) |

### 追加で実施した検証

- **sqldef v1.0.7 の drop 生成経路の全数確認** (`grep -n "DROP INDEX\|DROP TYPE\|DROP VIEW\|DROP TRIGGER\|DROP EXTENSION\|DROP POLICY\|DROP CONSTRAINT" schema/generator.go` + 該当箇所の読解) → 重大 1 の根拠
- **v2 の `SELECT *` 利用の実態確認** (`grep -rn "SELECT \*" db/queries/` = 多数ヒット、生成済み Go は列展開済み) → 中 13 の根拠
- **廃止テーブルの他文書参照の全数 grep** (`grep -rn "workspace_settings\|account_notification_settings\|eval_criteria_settings" docs`) → 中 12 の根拠
- **P-1 系の状態語 grep** (`grep -rn "相乗りしない" docs aidlc-docs`) → 中 7 の根拠
- **`token_hash` の全数 grep** (`grep -rn "token_hash" docs`) → 軽微 16 の根拠

---

## ⑦ 本番観点カバレッジ (本差分が触れた ID のみ)

| ID | 状態 | 箇所 / 所見 |
|---|---|---|
| **A-3** テナント境界 | **回答あり — ただし不整合 (重大 2)** | `data-model.md` §5 A-3 (`:1267`)。断定「42 件すべてが `contract_id NOT NULL` + FK」が §6.4①(a) と矛盾。`API/settings.md:227` の A-3 回答も廃止テーブル名のまま (中 12) |
| **A-4** 絞り込みの層 | **回答あり — ただし共有 log 2 本で担保が弱まる** | `contract_id` が jsonb に畳まれ得る状態では Repository のクエリ条件で強制できない (重大 2) |
| **A-5** ステータスコード | 影響なし | 本差分は触れていない |
| **A-6** LLM への越境 | **影響なし (確認済み)** | 共有 `public` 化でも LLM ツールの所有者スコープ (`architecture.md` §3.8.2) は変わらない。`v3_` 改名は repository 層に閉じる。**新たな越境経路は見当たらなかった** |
| **A-7** 共有・公開 | 影響なし | `workspace_settings` の `contracts` への振り替えで既定 `visibility` の保存先が変わるが、API 契約は不変と明記 |
| **O-6** 監査ログ | **回答あり — ただし要確認** | `activity_logs` を v2 と共用する結果、**v2 の行と v3 の行が同じ表に混在し、`actor_type` NULL を `account` と読む**規則で区別する。監査の読み出し側 (`GET /activity-logs`) がテナント絞り込みできるかは重大 2 に依存 |
| **D-3** デプロイ / ロールバック | **未回答 (重大 3)** | §6.6 が撤回済みの P-3 を根拠にしたまま。enum 値追加の不可逆性が扱われていない |
| **D-4** DB マイグレーション | **回答あり — ただし論証不足 (重大 1・中 10)** | §6.4② で SSOT を v3 に一本化する決定は妥当。drop 対象の評価が列止まり / PG バージョン前提が未検証 |
| **D-5** シークレット管理 | 影響なし | — |
| **D-7** 段階リリース | **要是正 (R-DM-13 で起票済み・未対応)** | 「二重化 → RL-3 で移行」を前提にした記述が operations.md / auth.md / settings.md / architecture.md に残存 |
| **D-8** IaC の管理範囲 | **回答あり** | INF-X が v2 RDS を Terraform 管理外のまま維持する点を明記 (INF-V の④を継承) |

---

## ⑧ 再レビューの指針

- **重大 1〜4 の修正後、再度 `design-reviewer` を通すこと**。特に重大 1 は「規範の文言を直す」だけでなく
  **v3 の `schema.sql` が v2 の全 index/constraint/extension/enum 値を含むかを、共有 DB への初回 apply 前に
  `--dry-run` で確認する**手順まで落とす必要がある (設計時点で決められる)。
- 修正時は `06-delegation-prompts.md` の「**状態語 grep**」を必ず実行すること:
  `grep -rn "未確定\|未回答\|未対応\|未検証\|相乗りしない\|二重化\|一方向コピー\|NOT NULL" docs/ aidlc-docs/`
  — 本レビューの中 5〜9 はすべてこの grep で機械的に出る。
- **`make check` が現在失敗している** (`check-template-sync`)。push 前に解消すること。
