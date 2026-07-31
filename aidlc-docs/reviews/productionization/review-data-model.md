# レビュー結果: データモデル設計 (data-model.md)

- **レビュー対象 (リポジトリ相対パス)**: `docs/design/data-model.md` (932 行・新規・未レビュー)
- **レビュー日**: 2026-07-29 / **レビュアー**: design-reviewer (別セッション。本番基準)
- **整合確認のために読んだ (レビュー対象外・未編集)**: `docs/design/auth.md` §6.3 / §6.4、
  `docs/design/operations.md` §6.1〜§6.5 / §7.4 / §7.5、`docs/design/observability.md` §4.2、
  `docs/design/architecture.md` §4 / §8、`docs/design/API/themes.md`、`docs/design/API/assets.md`、
  `docs/design/API/README.md`、`docs/design/API/knowledge.md`、`docs/design/API/idea-boards.md`、
  `aidlc-docs/inception/productionization/requirements.md` (AC-1.2 / AC-3.4 / AC-3.5)、
  `.claude/rules/feedback_review_patterns.md`
- **対象外**: `docs/design/testing.md` (別レビュー)

## レビュー結果サマリ

- **重大: 3 件 / 中: 5 件 / 軽微: 4 件**
- **Freeze 可否: 不可** (重大 3 件。いずれもスキーマ・手順・是正要求の局所修正で閉じるため、
  修正後の再レビューは該当差分のみで足りる)
- 実行した検証: `make check` (エラー 0 / 警告 42 / traceability 46/46 カバー)、
  所有者列の機械照合 (39/39)、抜き取り照合 **8 件** (オーケストレーター実施の 4 件とは別。重複なし)

### 実行した検証の出力

```
$ make check
（doc-lint 警告は 42 件すべて WARN。本書に関するものは以下 3 件のみ = 意図的な [Answer] 行）
[WARN ] ./docs/design/data-model.md:716 未回答の [Answer]:
[WARN ] ./docs/design/data-model.md:795 未回答の [Answer]:
[WARN ] ./docs/design/data-model.md:824 未回答の [Answer]:
[doc-lint] 対象 81 ファイル / エラー 0 件 / 警告 42 件
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 46/46 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
[workflow-shell] 検査 45 ブロック / エラー 0 件
```

**所有者列の機械照合 (AC-1.2 / §4.1.1 の 39 行)**:

```
$ awk 'NR>=250 && NR<=288' docs/design/data-model.md | grep -c '^| [0-9]'      # 39
$ awk 'NR>=250 && NR<=288' docs/design/data-model.md | grep -v 'contract_id'    # (出力なし)
$ ... | grep -c 'contract_id` + `account_id'                                    # 31
$ ... | grep -c '| `contract_id` | '                                            #  8
$ # 境界列と所有者列の整合 (個人=両方 / 契約=contract_id のみ) の不一致検出
$ ... | awk -F'|' '($2=="個人" && $3!="両方") ...'                              # MISMATCH: 0 件
```

→ **39 テーブル全件に `contract_id`。31 = 個人 (両方) / 8 = 契約。§5 の A-3 行の主張 (39 / 31 / 8) と一致**。
欠番なし。表の「境界」列と「所有者列」列の不整合も 0 件。

### 抜き取り照合 8 件 (すべて一致。行番号は起草者の自己修正後の値)

| # | 主張 | 出典 | 結果 |
|---|---|---|---|
| 1 | F-9: v2 は psqldef で `db/schema.sql` を適用 | `hassan-v2-backend/Makefile:24`〜`:26` | **一致** (`psqldef … hassan < ./db/schema.sql`) |
| 2 | F-9: **sqlc の入力も同じ `db/schema.sql`** (§6.1 の選定基準 1 = 結論を左右する事実) | `hassan-v2-backend/sqlc.yml:3` | **一致** (`schema: "db/schema.sql"`) |
| 3 | F-10: sqlc 出力は 1 パッケージ `db/rdb` | `hassan-v2-backend/sqlc.yml:6`〜`:11` | **一致** (`package: "rdb"` / `out: "db/rdb"`) |
| 4 | F-2: `accounts.contract_id` を更新するクエリが無い (UPDATE 7 本 / `SET contract_id` は 0 ファイル) | `hassan-v2-backend/db/queries/account.sql:32`〜`:50` | **一致** (7 本の列名を実物と突合。grep 結果 0) |
| 5 | F-5: `asset_documents` は 4 カラムで FK 無し | `hassan-v2-backend/db/schema.sql:510` | **一致** (`id uuid` / `file_text` / `created_at` / `updated_at`。FK なし) |
| 6 | F-12: `idea_board_phases` は `contract_id` + `UNIQUE(contract_id,name)` + `color_code` 既定値、並び順なし | `hassan-v2-backend/db/schema.sql:615`〜`:625` | **一致** |
| 7 | G-7: `ver` 採番は Go 側で全行パースし、コメント自身が「UNIQUE が最終防衛線」と認めている | `claude_managed_agents/internal/db/plan_tab_versions_store.go:170`〜`:205` | **一致** (:168〜:169 のコメントが race を明記) |
| 8 | G-9 / G-11 / G-13 / G-14: `tab_id` に CHECK を付けない判断 / 台帳は全置換 / `stage` は導出 / `Entrypoint` は書き手も読み手も無く `Interests` は読み手 2 箇所で書き手なし | `claude_managed_agents/internal/db/migrations/000023_plan_tab_versions.up.sql:13`〜`:15` / `internal/db/conversation_store.go:148`, `:250`, `:406` / grep | **一致** (`Entrypoint` は型宣言のみ。`Interests` の読み手は `conversation_tools_generate.go:400`, `:471` の 2 箇所で、書き手は台帳コピー `conversation_ledger.go:433` だけ) |

**追加で 1 件** (DM-4 の逸脱根拠): `rdb.MfaTypeEnumTotp` が `usecase/` から参照されている主張 →
`hassan-v2-backend/usecase/mfa/verify_totp.go:47` / `usecase/repository_interfaces.go:190`〜`:193` で **一致**。

**照合していない範囲 (正直な申告)**: F-1 / F-4 / F-6 / F-11 / F-13 / F-14 / F-15、G-1〜G-6 / G-8 / G-10 / G-12 / G-15、
`docs/analysis/` 経由の間接引用。出典 9 件 (8 + 1) がすべて一致したため全数照合には切り替えていない
(`feedback_review_patterns.md` DR-1 の運用基準)。

---

## 重大 (Must Fix)

### 重大 1. CI 検査②と⑤が同時には成立しない — 所有者移管の対象集合が定義不能

**箇所**: `docs/design/data-model.md:190` (§3.3 検査②) / `:863` `:866` (§7.2 の検査 2 / 検査 5) /
`:287` (§4.1.1 の `llm_call_records` = 個人・`account_id` あり) / `:527`〜`:529` (§4.9)

**事実**:

- §3.3 検査② / §7.2 検査 2 = 「**`account_id` を持つテーブルの集合 == 所有者移管 UseCase が `UPDATE` するテーブルの集合**」(厳密な集合一致)
- §7.2 検査 5 = 「**append-only テーブル (`llm_call_records` / `audit_logs`) に対する `UPDATE` / `DELETE` クエリが存在しないこと**」
- `llm_call_records` は §4.1.1 で **個人境界 (`account_id` あり)**。§4.10 も「UPDATE / DELETE を行わない」と明記

→ **`llm_call_records` は検査②が `UPDATE` を要求し、検査⑤が `UPDATE` を禁止する**。両方を CI に入れると
どちらかが必ず落ちる。実装リポは「片方の検査を弱める」で解決してしまう (弱められるのは通常②であり、
**§3.4 が塞ぐと言っている「非正規化 `account_id` の更新漏れ = 孤立」の唯一の機械的防御が消える**)。

**同種の矛盾がもう 1 つある**: §3.3-2 / DM-6 は「`account_id` → `ON DELETE NO ACTION`」を全機能テーブルの
規約としているが、§4.9 の `read_news_accounts` / `account_notification_settings` の FK は
**`account_id`→`accounts` (CASCADE)** と書かれている (`:527`, `:528`)。この 2 テーブルは意味的にも移管対象では
ない (他人の既読状態・通知設定を管理者へ移管するのは誤り)。**つまり「`account_id` を持つ ⇔ 移管する」は
成り立たない**。

**なぜ本番で問題になるか**: メンバー削除は本番で必ず起きる運用操作である (§3.4-3 が「移管してから物理削除」を
既定にしている)。集合一致の検査が壊れた状態で実装が進むと、**移管漏れテーブルの行が削除済みアカウントを
指したまま残り**、`account_id` が `NO ACTION` の FK であるため**メンバー削除そのものが本番で失敗する**
(または CASCADE のテーブルだけ黙って消える)。

**修正案**: `account_id` を持つテーブルを **3 分類**して表に列挙し、検査②を分類ごとに定義する。

| 分類 | 例 | メンバー削除時 | FK |
|---|---|---|---|
| ① 移管する (契約の資産) | `themes` / `assets` / `ideas` / `plans` / 会話・ナレッジ系 | `UPDATE account_id` | NO ACTION |
| ② 個人設定として削除する | `read_news_accounts` / `account_notification_settings` | `DELETE` (または CASCADE) | CASCADE (**例外として明記**) |
| ③ 記録として保全する (append-only) | `llm_call_records` | **何もしない** (`account_id` は「発生時の実行者」であり所有者移管の対象ではない) | NO ACTION + 削除不可の運用 |

検査②は「①の集合 == 移管 UseCase が UPDATE する集合」に改め、**②③を別表で有限列挙**する。
併せて §4.10 に「`llm_call_records.account_id` は所有者ではなく実行者の記録である」を明記する
(そうでないと A-4 の読み取り絞り込みの意味も曖昧になる)。

### 重大 2. prod の初期スキーマを「いつ・どのジョブが」適用するかが文書間で矛盾しており、データ移送がテーブル不在時に走る

**箇所**: `docs/design/data-model.md:728` (§6.2 の 1) / `:776` (§6.3 ロールバック表の最終行) /
`docs/design/operations.md:443`〜`:452` (§6.3 の手順①〜⑦) / 同 `:415` (RL-2 の完了条件)

**事実**:

- data-model §6.2-1: 「**マイグレーションはアプリのリリースより前に適用される** (`apply_migration` → `release`)」
  = 適用は **deploy.yml の中** (operations.md §5.1)。prod の deploy.yml が動くのは **RL-3 の手順③**
- data-model §6.3: 「初期投入 (①〜⑦) の失敗 … **prod は RL-2 (基盤構築) の段で行うため**、公開前であり
  ユーザー影響なしに作り直せる」= 適用は **RL-2**
- operations.md §6.3 の手順: 「**② データ移送** … v2 → v3 の一方向コピー」→「**③ BE** … deploy.yml を prod で手動起動」。
  data-model §6.4 の確定事項 1 も「移送は **RL-3 の最初 (BE デプロイより前)**」
- operations.md §6.1 の **RL-2 の完了条件に初期スキーマ適用は含まれていない** (Terraform / Secrets / Agent 発行 /
  通知試験のみ)

→ 「初期スキーマは RL-2」を採るなら **RL-2 の完了条件に無い作業**が暗黙に必要で、実行主体もジョブも未定義。
「deploy.yml で適用」を採るなら **手順② のデータ移送が空の DB に対して走る**。

**なぜ本番で問題になるか**: AC-3.4 の「適用タイミング」は本書が確定済みと主張している項目 (§5 の D-4 行) だが、
**最も重要な 1 回目 (prod の初期投入) について確定していない**。切替当日に「テーブルが無いので移送が落ちる」→
その場で手作業で `schema.sql` を適用する、という**IaC / 承認ゲートを迂回する運用**に落ちる。

**修正案**: §6.3 に「**prod の初期投入は RL-2 の段で `apply_migration` ジョブを 1 回単独実行する**
(deploy.yml の `release` を伴わない起動、または専用の `init_schema` 起動口)」と実行主体・承認 (`prod-db`) を明記し、
**operations.md §6.1 の RL-2 完了条件への追記を §8.3 の是正要求 (R-DM-9) として立てる**。
§6.2-1 の「リリースより前」は差分適用の規則、初期投入はその特例であることを書き分ける。

### 重大 3. 所有者列の規約を auth.md より強めているのに、規約側 (SSOT) への是正要求が出ていない — AC-1.2 の充足判定が文書間で一致しない (オーケストレーターの発見 B を含む)

**箇所**: `docs/design/data-model.md:18` (§0 = 規約の SSOT は auth.md §6.3) / `:114` (DM-2) / `:181`〜`:183` (§3.3) /
`:292`〜`:308` (§4.1.2) / `:670` (§5 の A-3 行「差分 1 件」) / `:915` (R-DM-4) ↔
`docs/design/auth.md:578`〜`:612` (§6.3) / `aidlc-docs/inception/productionization/requirements.md:57`〜`:62` (AC-1.2)

**事実 3 点**:

1. **規約の強化が SSOT に反映されていない**。auth.md §6.3-1 は「個人スコープ = `account_id`」「契約スコープ =
   `contract_id`」「両方」の **3 パターンを許し**、要件は「どちらかが 1 段で存在すること」である
   (`auth.md:581`〜`:589`)。本書 DM-2 は「**全機能テーブルが `contract_id` NOT NULL** + 個人スコープは
   加えて `account_id`」に**強化**した (妥当な判断であり理由も却下案も揃っている)。しかし
   **auth.md §6.3 の表と機械検査 (同 `:592`〜`:593`: 「`account_id` / `contract_id` の**どちらも**持たない状態を検出」) は旧規約のまま**で、
   R-DM-4 は例外列挙への 1 行追加しか要求していない。
   → **AC-1.2 は「例外は auth.md §6.3 の有限の列挙に限る」と auth.md を名指しで SSOT にしている** (requirements.md:59)。
   実装リポが SSOT (auth.md) 側の弱い検査を実装すると、`contract_id` の無い機能テーブルが CI を通り、
   **DM-2 の目的 (契約単位の集計・移管・テナント全削除を 1 段で行う) が黙って崩れる**。
   `architecture.md:723` も「例外は … `contracts` / `accounts` / `companies` / `auth_roles` 相当のみ」と
   **3 文書で異なる粒度**の記述になっている。

2. **§4.1.2 の「例外 11 件」が 2 種類の例外を混在させている** (オーケストレーターの発見 B。判定: **指摘として立てる。
   単なる表記ではなく、CI 検査①の定義が壊れる**)。同表の 10 行のうち、
   `accounts` / `companies` / `signup_links` は **`contract_id` を実際に持ち**、
   `account_mfa_configs` / `reset_password_requests` は **`account_id` を実際に持つ** (本書自身が「列は持つ」と書いている)。
   これらは §6.3 (所有者列を持てない) の例外ではなく **§6.4 のクエリ側許可リスト**の対象である。
   **所有者列を真に持たないのは 6 件** (`contracts` / `auth_roles` / `admin_accounts` / `admin_auth_roles` /
   `register_admin_password_requests` / `auth_rate_limit_counters`)。
   → §3.3 検査①は「**全テーブルが `contract_id` を持つこと。例外は §4.1.2 の列挙に載っているテーブルのみ**」である。
   混在した列挙を入力にすると、**`accounts` / `companies` / `signup_links` が検査①の対象外**になり、
   将来これらの `contract_id` が落ちても検出されない (v2 の `asset_documents` = F-5 が生まれた経路と同型)。

3. **「差分 1 件」の記述が不正確**。§5 の A-3 行と §4.1.2 は「auth.md §6.3 の列挙との差分は
   `auth_rate_limit_counters` の 1 件」とするが、`account_mfa_configs` も同 §6.3 の列挙に**無い**
   (同表の該当行は「認証フローの**一時レコード** (`reset_password_requests` / `signup_links` 相当)」であり、
   MFA の恒久設定テーブルは含まれない。§6.3 は「ここに無いテーブルに例外を認めない」と宣言している)。

**修正案** (3 点まとめて):

- §4.1.2 を **2 表に分割**する: (a) **所有者列を持たない 6 件** = 検査①の例外、
  (b) **所有者列は持つがクエリ側で所有者条件を掛けられない 5 件** = auth.md §6.4 許可リストの対象で、
  **検査①の例外ではない** (`contract_id` を持つ `accounts` / `companies` / `signup_links` は検査①を通る)。
  検査①の入力は (a) のみとする。
- §5 の A-3 行の「差分 1 件」を「**差分 2 件** (`auth_rate_limit_counters` / `account_mfa_configs`)」に修正。
- **R-DM-4 を拡張**し、auth.md §6.3 に対して ①例外列挙への 2 件追加 ②**§6.3-1 の表と機械検査の記述を
  「機能テーブルは `contract_id` 必須、個人境界は `account_id` を追加」へ更新** (= DM-2 の強化を SSOT に反映)
  を要求する。あわせて `architecture.md:723` の例外記述を本書 §4.1.2 への参照に置き換える要求を R-DM-5 に足す。

---

## 中 (Should Fix)

### 中 1. 台帳の append エントリに安定 ID が無く、BE-1 の「どの版を渡したか」の記録が再結合できない

**箇所**: `:656` (§4.11.3 の grounding 行「**どの deep dive を使ったかを `content` 内に記録する**」) /
`:412` (`conversation_ledger_archives` は `field_name` + `entry jsonb` + `archived_at` のみ) / `:631` (退避の決定)

`deep_dive_results` は台帳内の append 配列であり、**エントリ単位の識別子が設計に無い**。したがって
(a) 企画書タブの `content` に「どの deep dive を使ったか」を書いても**照合先を一意に指せない**、
(b) サイズ上限超過で最古エントリが `conversation_ledger_archives` へ退避されると、
**退避先にも ID が無いため還流元を辿れない**。BE-1 (旧版参照で数値が食い違う) の再発検知が
「人が本文を読み比べる」に落ちる。

**修正案**: 台帳の append 系フィールドのエントリに **`entry_id` (uuid / ULID) を必須にする**
(型は `entity/conversation` に宣言)。`conversation_ledger_archives` に `entry_id` 列を持たせ、
`plan_tab_versions.content` には `source_deep_dive_entry_ids` を配列で記録する、と §4.11.2 / §4.11.3 に書く。

### 中 2. 新規の UNIQUE 制約が v2 の既存データを弾き得ることが移行の検討項目に入っていない (DR-3)

**箇所**: `:342` (`themes` の **部分 UNIQUE `(account_id, name)`**) / `:435` (`plans` の `UNIQUE (idea_id)`) /
`:467` (`knowledge_threads` の部分 UNIQUE) / `:799`〜`:807` (§6.4 の「回答後に書く 7 項目」)

**実測**: v2 の `themes` に `(account_id, name)` の一意制約は**存在しない**
(`hassan-v2-backend/db/schema.sql:94`〜`:102` に UNIQUE 無し・grep でも 0 件)。
したがって v2 に同一アカウント・同名テーマが存在し得る。§6.4 の 7 項目 (対応表 / 写像規則 / 実行経路 /
冪等性 / 検証方法 / ダウンタイム / 引き継がない場合) に「**既存データが v3 の新制約に違反する場合の扱い**」が無い。

**なぜ本番で問題になるか**: 移送は RL-3 の当日に走る。制約違反は「一部の行だけ入らない」= §6.2-3 の
「写像できなかった件数 0」が達成できず、**切替当日に判断を求められる** (リネームするのか・スキップするのか)。

**修正案**: §6.4 の項目に「**8. 新規制約との衝突**: v3 で新設した一意制約 (`themes(account_id,name)` /
`plans(idea_id)` / `knowledge_threads(account_id,idea_id)`) に違反する v2 データの検出 SQL と、
衝突時の規則 (改名サフィックス付与 / 新しい方を残す等) を移行前に決める」を追加する。
併せて v2 に対応列が無い `NOT NULL` 列 (`themes.subtitle` / `purpose` / `icon` / `status`) の既定値も
写像規則に含める。

### 中 3. `llm_call_records` の相関キーが弱い — テーマ単位のコスト集計ができず、`session_id` の削除時挙動が未定義

**箇所**: `:548` (§4.10 の `llm_call_records`) / `.claude/rules/08-production-gates.md` の **O-3**
(「**アカウント / テーマ単位**のコスト集計」)

- **`theme_id` が無い**。`session_id` 経由で辿る形になるが、`conversation_sessions.theme_id` は
  `SET NULL` (`:409`) かつ `session_id` は NULL 可であり、**テーマ単位の集計が構造的に保証されない**。
  本テーブルは **append-only で「取り損なった分は後から復元できない」** (observability.md §4.2 の明記) ため、
  後から列を足しても**過去分は永久に集計不能**になる。
- **`session_id` の FK と削除時挙動が書かれていない**。CASCADE を張ると会話削除でコスト明細が消え、
  append-only (§4.10) と矛盾する。

**修正案**: `theme_id bigint NULL` (FK は張らず、または `ON DELETE SET NULL`) を列に追加し、
`session_id` は「**FK を張らない (論理参照)**」または `ON DELETE SET NULL` を明記する。
observability.md §4.2 のフィールド要件表への追記要求 (R-DM-8 の内容差し替え) として立てる。

### 中 4. 「ID を維持できる形にしてある」が全テーブルで成立しない

**箇所**: `:802` (§6.4 の写像規則「①ID を維持するか再割り当てするか (**DM-1 は維持できる形にしてある**)」) /
`:375` (v3 `asset_documents.id` = `bigint` identity)

**実測**: v2 の `asset_documents.id` は **`uuid`** (`hassan-v2-backend/db/schema.sql:510`。照合 5 で確認)。
v3 は機能テーブル一律 `bigint` (DM-1) なので、**このテーブルだけは ID を維持できず対応表が必要**になる。
DM-1 の却下 (a) が「UUIDv7 統一は全テーブル分の対応表が必要になる」を理由に採用案を選んでいるため、
**同じ論法が 1 テーブルに残っていることを明示しないと、移行設計時に見落とす**。

**修正案**: §6.4 の写像規則①に「**例外: `asset_documents` は v2 が `uuid` PK のため対応表が必要**」を明記する
(F-5 の隣に書くのが自然)。ほか F-1 の `uuid` 系 4 テーブルは §4.2 で `uuid` を維持しているため影響なし。

### 中 5. 所有者移管 UseCase の実行可能性 (対象 31 テーブル・大量行) が未評価

**箇所**: `:198`〜`:199` (§3.4 の 2 / 3) / `:264`〜`:277` (`conversation_messages` / `knowledge_file_chunks` 等)

`account_id` を非正規化した結果、移管対象は最大 31 テーブルになり、その中に**行数が伸びる子テーブル**
(`conversation_messages` / `conversation_tool_calls` / `knowledge_file_chunks` / `asset_extraction_events`) が含まれる。
「専用 UseCase 1 本が UPDATE する」(§3.4-2) 以外に、**トランザクション境界・バッチ分割・実行時間の想定が無い**。
1 トランザクションで数百万行を更新すると本番でロック待ちを起こす。

**修正案**: §3.4 に「移管は**集約ルート単位のバッチ**で行い、1 バッチ = 1 トランザクション。
進捗を再開可能にする (冪等)」の方針と、対象テーブルの**行数オーダーの想定**を書く。
重大 1 の 3 分類表と同じ表で管理すると二重管理にならない。

---

## 軽微 (Nice to Have)

### 軽微 1. 是正要求 3 件が既に解消済み (陳腐化) — R-DM-5 / R-DM-6 / R-DM-8

| 要求 | 判定 | 根拠 |
|---|---|---|
| **R-DM-6** (`:917`) 「operations.md §7.5 に同じ `[Answer]` がある」 | **無効 (解消済み)** | `docs/design/operations.md:619`〜`:622` が既に「**この問いの `[Answer]` は data-model.md §6.1 に集約した** (2026-07-30) … 本節は参照のまま維持する」と書いており、§7.5 に当該 `[Answer]` 行は無い |
| **R-DM-8** (`:919`) 「observability.md §4.2 の『テーブル名は…確定する』を本書への参照に更新」 | **無効 (解消済み)** | `docs/design/observability.md` §4.2 は既に「**テーブル名は `llm_call_records`・スキーマは data-model.md §4.10 が SSOT** (2026-07-30 に確定)」と記載。中 3 の内容 (`theme_id` / `session_id`) に**差し替える**のが妥当 |
| **R-DM-5** (`:916`) 「architecture.md §4 は『データモデル (未確定 — Q-1 待ち)』のままである」 | **前提が誤り。残る有効部分あり** | `docs/design/architecture.md:714` は既に「**## 4. データモデル (確定 — SSOT は data-model.md)**」。**有効なのは** ①§4 末尾の箇条書き「`db/queries` と sqlc 出力先を**本節で決める**」 ②`architecture.md:834` の残課題「sqlc の出力先構成 (1 パッケージか複数か)」の 2 点のみ (DM-18 で確定済み) |

**なぜ指摘するか**: 是正要求の一覧は次の作業者のタスクリストになる。解消済みの要求が混ざると
「他の要求も古いのでは」と全件の再確認コストが発生する。**§8.3 は反映日を持つ形 (auth.md §8 / §10.1 の形式) にする**のが構造的な対処。

### 軽微 2. 本番観点 ID のうち D-6 に回答も対象外理由も無い

`:3`〜`:8` の観点宣言は A / O / D の主要 ID を網羅しているが、**D-6 (Managed Agent のライフサイクル)** が
参照リストにも「対象外」リストにも無い (D-1 / D-3 / D-5 / D-7 / D-8 は所在が明示されている)。
実質は operations.md §5.2 の担当で本書に Agent 関連テーブルは不要だが、
`08-production-gates.md` は**無言の省略を重大指摘**と定めている。**`:7` の参照行に「D-2 / D-6 → operations.md」を足す**
(D-2 は §7.2 で追加要求を出しているので所在の明示だけでよい)。

### 軽微 3. §4.9 の詳細表に所有者列の FK が現れない

`:527`〜`:529` の FK 列は `account_id`→`accounts` / `contract_id`→`contracts` のうち片方しか書かれていない
(§4.3 は「本節の全テーブルは §4.1.1 の所有者列を持つ」という前置きがあるが、§4.9 には同じ前置きが無い)。
§4.1.1 とは整合しているので実害は小さいが、**表単体を読む実装者が `contract_id` を落とす**。
§4.4〜§4.10 の各節冒頭に §4.3 と同じ 1 行を置く。

### 軽微 4. `visibility` の値域が 2 文書で微妙に別管理

`:121` (DM-9) は `private` / `contract` を本書で定義し、`:674` (§5 の A-7 行) は
「判断の SSOT は API/themes.md §3.2 / API/assets.md §3.2」とする。値域そのものは
§3.2 の規約どおり `entity/` が SSOT なので実害は無いが、**「列と値域は本書、開放時期は API」**と
1 行で書き分けた方が安全。

---

## 判定 (依頼された観点)

### 1. AC-1.2 (所有者列)

**充足。ただし重大 3 の 3 点を直すまで「auth.md との整合が取れた状態」ではない**。
39/39 に `contract_id`、境界の読み方 (`account_id` の有無) が一意、機械検査 3 本が定義済み、
例外は有限列挙 — AC-1.2 の要求文はすべて満たしている。**例外 11 件の内訳が auth.md §6.3 と
不一致 (差分 2 件)、かつ列挙が 2 種類の例外を混在**しているため、AC-1.2 が名指しする SSOT (auth.md) 側の
更新とセットでないと充足判定が文書間で一致しない。

### 2. AC-3.4 (マイグレーション)

**方式未確定の扱いは妥当。ただし初期投入の段が矛盾 (重大 2) のため「適用タイミング確定」の主張は成立しない**。

- 未確定の扱い方は**良い形**: 比較表 (7 観点) + 選定基準 4 点 (優先順位付き) + 推奨案 (psqldef) +
  **回答が入ったら書き換える箇所の列挙** (§6.1 の注記)。「後で決める」で終わっていない (DR-5 を回避)。
- **operations.md §7.4 の 8 分類との矛盾なし** (照合済み): §6.2 の「本書のスキーマ設計が与える具体」表は
  §7.4 の 2 (既定値付き列追加) / 5・6 (3 段階) / 7 (UNIQUE) / 8 (データ移行 SQL) に正しく対応しており、
  `CHECK` の差し替え方向 (追加 = 非破壊 / 削除 = 破壊的) の評価も §7.4 の枠内。
- ロールバック (§6.3) も §7.4 の「戻さない / スナップショット復元 / 段ごとに戻せる」と一致。
- **不足は初期投入 1 点のみ** (重大 2)。

### 3. BE パターンの構造的解消

| パターン | 判定 | 根拠 |
|---|---|---|
| **BE-1** (旧版参照で数値が食い違う) | **部分解消** | `plan_tab_versions.source_idea_version_id` で「どの版から生成したか」を FK で持つ = 構造的解消。**grounding (deep dive) 側は `content` 内の記録止まりで安定 ID が無い** → 中 1 |
| **BE-4** (派生物の stale ガード) | **解消** | DM-14 の 3 点 (版 FK + `source_hash` + 消さずに `stale`) + §4.11.3 の依存グラフ + **`source_hash` の計算対象を `entity/idea` の 1 関数に閉じてテストで固定** (`:659`〜`:662`)。「実装時に気をつける」になっていない |
| **BE-10** (台帳の write-through 欠落) | **解消** | 13 フィールドすべてに書き手・読み手を明記し、**書き手の無い 3 フィールドを「持たない」と決定** (`:606`〜`:608`)。CI 検査 (書き手の存在) + **限界の明示** (意味の取り違えは検出できない) まで書かれている |
| **BE-11** (採番の固定 Insert) | **解消** | DM-8 (採番 + Insert を 1 SQL) / §4.11.1 の 5 規約。特に「**バージョン番号を引数で受け取るメソッドを作らない**」は再発余地を型で消す設計。PoC の warn 継続 (G-8) を明示的に却下 |
| **BE-12** (読み手・書き手の契約食い違い) | **解消** | 型の SSOT を `entity/conversation` に 1 箇所化 + **読み手が独自構造体を定義することを禁止** + テストで合成 JSON を禁止。PoC の実バグ (G-15) の発生機構に対応している |
| **BE-2** (設定値の散在) | 解消 | 台帳サイズ上限を `config` の SSOT に置く (`:630`) |
| **BE-3 / BE-5** | 対象外 (本書の範囲外。operations.md / architecture.md) | — |

### 4. DR-3 / DR-1

- **DR-3**: **「引き継がない」前提になっていない**。`:791`〜`:793` が明示的に
  「**『引き継がない』前提で設計していない** — テーブル定義は引き継ぎがある場合に写せる形にしてある」と書き、
  §6.4 に回答後に埋める 7 項目 (対応表・写像規則・実行経路・冪等性・検証・ダウンタイム・
  **引き継がない場合も「何を捨てるか」を告知対象として列挙**) を置いている。**扱いは正しい**。
  不足は中 2 (新制約との衝突) と中 4 (uuid PK の例外) の 2 点。
- **DR-1**: 出典密度は高く、抜き取り 8 件 + 1 件すべて一致 (行番号のズレも無し)。
  **出典なしの断定が 1 箇所**: `:600` の「PoC は引数マージ側が Name だけ書いて `rationale` を消していた」に
  パス:行が無い (照合すると `claude_managed_agents/cmd/devui/conversation_tools_generate.go:194`〜`:204` が
  `SelectedDomainLedger{Name: ...}` のみを詰めており **主張自体は正しい**)。**出典を付けるだけで解消** (軽微扱い)。

### 5. SSOT 違反

- observability.md (項目要件) / operations.md (適用手順) / auth.md (境界の規約) / API (エンドポイント) との
  **役割分担は §0 の表で明示され、参照は節番号で行われている**。移行手順・アラート・許可リストなどを
  再定義していない (`:333` の「しきい値 / fail-closed は auth.md が SSOT」など、抑制が効いている)。
- **唯一の実質的な違反が重大 3** (auth.md §6.3 の規約を本書側で強化し、SSOT を更新していない)。
- 陳腐化した是正要求 3 件 (軽微 1) は SSOT 違反ではないが、二重管理の解消済み事実を追随していない。

### 6. 残る是正要求の妥当性 (auth.md / API 宛て 5 件)

| # | 判定 | 根拠 (実測) |
|---|---|---|
| **R-DM-1** (API/themes.md D-TH-7 を論理削除へ) | **妥当。越権ではない** | `docs/design/API/themes.md:95` の D-TH-7 が**自ら**「この不統一の解消は **data-model 設計で扱う (§5)**」と委譲しており、同 `:162` の TH-Q4 (削除時の配下データ) も data-model 送り。**判断権は本書にある**。理由も強い (テーマ配下のアイデアがボードに載りコメントを持つため、物理削除は `API/idea-boards.md` D-IB-7「アイデアは論理削除・ボードアイテムは参照を保つ」と両立しない)。**ただし要求範囲を絞るべき**: D-TH-7 の「アーカイブを UI 上の既定の消し方にする」判断は維持できるので、要求は「**削除の実装を物理→論理に変更**」+ TH-Q4 の回答であり、D-TH-7 全体の書き換えではない |
| **R-DM-2** (API/README.md J-3 の heartbeat) | **妥当** | `docs/design/API/README.md:128` が「**`running` / `processing` の `updated_at` を heartbeat として更新**」と実際に書いている。DM-17 の理由 (結果以外の更新で `updated_at` が動く) も正しい。同 `:470` の API-Q7 (閾値・仕組み) と一緒に処理すべき |
| **R-DM-3** (文字列 ID の例を整数へ) | **妥当** | 実在を確認: `docs/design/API/knowledge.md:77` (`"kt-01J9Z8QP…"`) / `:87` (`"kf-01J9Z8QP…"`) / `docs/design/API/idea-boards.md:112` (`"bi-01J9Z8QP…"`) |
| **R-DM-4** (auth.md §6.3 に `auth_rate_limit_counters` を追加) | **妥当だが不十分** | 例外列挙に実在しないことは確認済み。**重大 3 のとおり `account_mfa_configs` と §6.3-1 の規約本体・機械検査の更新まで広げる必要がある** |
| **R-DM-7** (function-tree の `is_core`) | **妥当** | `docs/design/API/assets.md:59` のレスポンスは `{id, parent_id, level, name, description}` で `is_core` が無い。**「保持するが返さない」ならその旨を API 側に書く**という要求の形も適切 (PoC の `is_core` = G-4 は照合済み) |

---

## 良かった点 (3 行)

- **却下案の質が高い**: DM-6 (`RESTRICT` は即時チェック / `NO ACTION` は文末遅延という PostgreSQL の
  挙動差で「アカウント単体削除は失敗させ、契約削除の CASCADE は通す」を成立させる) は、
  規約を書くだけでなく**なぜその 1 語でなければ成り立たないか**まで到達している。
- **PoC の既知バグを「構造で潰したか」で自己点検している** (BE-10 の 13 フィールド表 /
  BE-11 の「版番号を引数で受け取るメソッドを作らない」/ BE-12 の「読み手が独自構造体を定義することを禁止」)。
- **未確定の残し方が模範的**: §6.1 / §6.4 / §6.5 は「推奨 + 選ばなかった場合に変わること + 回答後に
  書き換える箇所」まで書いてあり、`[Answer]` が入った時点の作業が機械的に決まる。

## Freeze 可否

**不可 (重大 3 件)**。修正の性質は次のとおりで、いずれも設計の骨格を変えない:

1. **重大 1** = §3.3 / §7.2 の検査定義を 3 分類に書き換え + §4.9 の FK を例外として明記
2. **重大 2** = §6.3 に prod 初期投入の段・ジョブ・承認を明記 + operations.md §6.1 への是正要求 (R-DM-9) 追加
3. **重大 3** = §4.1.2 を 2 表に分割 + §5 の「差分 1 件」修正 + R-DM-4 の拡張 (auth.md §6.3 の規約本体まで)

中 5 件は Freeze の障害ではないが、**中 1 (台帳エントリ ID) と中 3 (`theme_id`) は append-only /
JSONB の性質上「後から足しても過去分が復元できない」**ため、実装着手前に決めておく方が安い。
再レビューは上記 3 点 + 中 1 / 中 3 の差分のみで足りる (全文の再レビューは不要)。

---

## 指摘の反映 (2026-07-30)

**反映先**: `docs/design/data-model.md` (本節以外は未編集)。**上記の指摘記述そのものは改変していない**。

| 指摘 | 反映内容 (どこに何を書いたか) |
|---|---|
| **重大 1** (検査②と⑤の非両立) | **§3.4.2 を新設**し `account_id` を持つ 31 テーブルを **3 分類で有限列挙** (①移管 28 / ②個人設定として削除 2 / ③記録として保全 1)。**§3.3 の検査②を②-1 (分類①の集合一致) と②-2 (分類の網羅性 + ②③の有限列挙) に分割**し、両立する理由を注記。**§7.2 の検査 2 を 2-1 / 2-2 に分割し、検査 5 との両立を明記** + **検査 6 (append-only の 2 テーブルに FK を張らないこと) を追加**。**§4.9 の表に `read_news_accounts` / `account_notification_settings` の `account_id` = CASCADE を所有者列 FK として明示**し、§3.3-2 / DM-6 の `NO ACTION` 規約の**例外である旨と `NO ACTION` を選ばない理由**を書いた (DM-6 の採用案にも例外への参照を追加)。**§4.10 に「`llm_call_records.account_id` は所有者ではなく実行者の記録」を明記**し、移管対象外であること・A-4 では実行者絞り込みとして使うことを書いた。**分類③の FK は「張らない (論理参照)」と決定**し却下案 3 つ (`NO ACTION` / `CASCADE` / `SET NULL`) を書いた |
| **重大 2** (prod 初期スキーマの段の矛盾) | **§6.3 に「prod への初期投入は誰がいつどのジョブで」の表を新設** — 段 = **RL-2**、ジョブ = **`apply_migration` を `release` を伴わず 1 回単独起動** (または `init_schema` 起動口)、実行主体 = 人間の手動起動、承認 = **`prod-db` (H-2)**、経路は通常と同じ ECS RunTask。**§6.2-1 の見出しを「差分適用の規則」に改め、初期投入がその特例であることを書き分けた**。ロールバック表の「初期投入の失敗」行も RL-2 前提に書き換え。**§8.3 に R-DM-9 を起票** (operations.md §6.1 の RL-2 完了条件への追記。**メインセッションが 2026-07-30 に反映済み**であることを実測して注記: 同 §6.1 の RL-2 行に⑦が追加され承認欄に H-2 が入っている) |
| **重大 3** (所有者列の規約が auth.md より強い / 例外の分類混在) | **§4.1.2 を 2 表に分割**: **(a) 所有者列を持たない 6 件** (`contracts` / `auth_roles` / `admin_accounts` / `admin_auth_roles` / `register_admin_password_requests` / `auth_rate_limit_counters`) と **(b) 所有者列を実際に持つ 5 件** (`accounts` / `companies` / `signup_links` / `account_mfa_configs` / `reset_password_requests` — **検査①の例外ではない**。クエリ側の例外は auth.md §6.4 の許可リスト種別を行ごとに明記)。**§3.3 の検査① / §7.2 の検査 1 の除外リストを「(a) 6 件 + `contract_id` を持たない 2 件 = 8 件」に確定**し、**`accounts` / `companies` / `signup_links` は除外しない**と明記 (レビュー指摘の「(a) のみ」に対する**追加の発見**: `account_mfa_configs` / `reset_password_requests` は `contract_id` を持たないため検査①を通れない。**理由を 2 種類に分けて除外リストに載せる**形にした)。**§5 の A-3 行を「差分 2 件」に修正**。**R-DM-4 を 3 点に拡張** (①例外列挙への 2 件追加 ②§6.3-1 の表と機械検査の更新 ③append-only の FK 例外)。**R-DM-5 に `architecture.md:724` の例外記述を本書 §4.1.2 参照へ置き換える要求 (③) を追加** |
| **中 1** (台帳エントリの安定 ID) | **§4.11.2 に「append 系エントリの安定 ID (`entry_id`) — 必須」を新設**。型は **`uuid`** (生成は `entity/conversation` の 1 関数に閉じ、値を引数で受け取らない)、対象は append 系 5 フィールド、**`plan_tab_versions.content.source_deep_dive_entry_ids` (文字列配列・空配列で「未使用」を表す) を必須化**、却下案 3 つ (配列添字 / ULID / 時刻複合キー) を明記。**§4.5 の `conversation_ledger_archives` に `entry_id uuid NOT NULL` と UNIQUE `(session_id, field_name, entry_id)` を追加**。**§4.11.3 の grounding 行を `entry_id` 列挙に書き換え** (退避済みエントリも辿れることを明記)。退避の決定 2 にも「退避行に `entry_id` を必ず入れる」を追加 |
| **中 2** (新規 UNIQUE と v2 既存データの衝突) | **§6.4 に項目 8「新規制約との衝突 (DR-3)」を追加**し、**v3 の新規一意制約 3 件 × v2 の実測状態 × 検出 SQL × 衝突時の規則候補の表**を新設。実測を一次ソースで確認: v2 `themes` に UNIQUE 無し (`hassan-v2-backend/db/schema.sql:94`〜`:102`) / v2 `business_plans` は `idea_id` に索引のみ (`同:204`) / ナレッジは v2 に機能が無く対象なし。**検出は「移行の設計時 (切替当日ではない)」・v2 への読み取り専用接続で行う**と明記。**写像規則⑥として v2 に対応列が無い `NOT NULL` 列 (`themes.subtitle` / `purpose` / `icon` / `status`) の既定値を移行前に決めることを追加** |
| **中 3** (`llm_call_records` の相関キー) | **§4.10 の列に `theme_id bigint NULL` を追加** + 部分インデックス `(theme_id, created_at DESC)`。**`session_id` 経由にしない理由** (テーマ単位の集計が構造的に保証されない / append-only で過去分が復元できない) と **NULL を入れる経路** (アセット抽出・ナレッジ検索) を明記。**`session_id` / `theme_id` は FK を張らない (論理参照)** と決定し却下案 (`CASCADE` / `NO ACTION` / `SET NULL`) を明記。**計測漏れ検出の CHECK の対象は計測フィールドに限り、相関キーは対象外**と書き分け。**R-DM-8 の内容を差し替え** (テーブル名参照は解消済み → observability.md §4.2 のフィールド要件表への `theme_id` 追記要求へ) |
| **中 4** (ID 維持が全テーブルで成立しない) | **§6.4 の写像規則①に `asset_documents` の例外を明記** — v2 は `uuid` PK (`hassan-v2-backend/db/schema.sql:510`〜`:515` を一次ソースで確認)・v3 は `bigint` なので**このテーブルだけ対応表が必要**。DM-1 の却下 (a) と同じ論法が 1 テーブルに残ることを書いた。`contracts` / `accounts` / `companies` は §4.2 で `uuid` 維持のため影響なしと明記 |
| **中 5** (移管の実行可能性) | **§3.4.3「移管の実行方式」を新設** (5 項目): **1 バッチ = 1 集約ルート = 1 トランザクション** / **バッチ上限を `config` の設定値に置く (既定 50 集約。BE-2)** / **進捗は残件数で表し `UPDATE ... WHERE account_id = <旧>` の冪等性で再開する (進捗テーブルを持たない)** / **非同期ジョブとして実行し残件 0 の後にのみ `accounts` を物理削除する** / **行数の実測は推測で埋めず DM-Q2 の③に起票**。行数オーダー (伸びる子テーブル) は §3.4.2 の分類表に列として同居させ、二重管理を避けた |
| **軽微 1** (是正要求の陳腐化) | **§8.3 を「状態 (2026-07-30 時点)」列を持つ形に作り替えた** (auth.md §8 / §10.1 と同じ形式)。**R-DM-6 を「解消済み (要求は無効)」として根拠付きで残す** (`operations.md:619`〜`:622` を確認) / **R-DM-8 は当初要求が解消済みであることを明記して内容を差し替え** (`observability.md:160` を確認) / **R-DM-5 は「§4 の見出しは既に更新済み」を反映し、残る有効な 3 点に絞った** (`architecture.md:714` / `:724` / `:834` を確認) / **R-DM-1 の要求範囲を 2 点に絞った** (D-TH-7 の「アーカイブを既定の消し方にする」判断は維持できる。`API/themes.md:95` の委譲記述を確認)。R-DM-2 / R-DM-3 / R-DM-7 は出典行を追記して「未対応」のまま維持 |
| **軽微 2** (D-6 の無言の省略) | **本書冒頭の観点宣言に D-2 / D-6 を追加**。D-2 は §7.2 が検査を追加要求する形で関与、**D-6 は operations.md §5.2 が SSOT で本書に Agent 関連テーブルは無い** (Agent ID / Environment ID は **SSM Parameter Store** — 同 §3.3 の分類⑤ / §4.5 を確認して記載) と所在を明記 |
| **軽微 3** (§4.9 の詳細表に所有者列の FK が無い) | **§4.3 に「§4.3〜§4.10 の共通前置き」を置き、§4.4〜§4.10 の各節冒頭から参照させた** (所有者列は全件持つ / FK 列には所有者列以外だけを書く / 例外は §3.4.2 の 3 テーブル)。**§4.9 と §4.10 は例外に該当するため、表内に所有者列の FK を明示**した |
| **軽微 4** (`visibility` の値域の別管理) | **DM-9 の採用案と §5 の A-7 行の両方に書き分けを 1 行で入れた** — 「**列を持つテーブルと値域は本書** (値の一覧は `entity/` の Go 型) / **開放時期と画面での意味は API/themes.md §3.2・API/assets.md §3.2**」 |

**追加で反映した 1 件** (レビュー §4 の DR-1 で「出典なしの断定が 1 箇所」とされた項目):
§4.11.2 の `selected_domains` 行の「PoC は引数マージ側が Name だけ書いて `rationale` を消していた」に
**出典 `claude_managed_agents/cmd/devui/conversation_tools_generate.go:194`〜`:204` (消える行は `:198`) を付けた**
(一次ソースで `dbpkg.SelectedDomainLedger{Name: strings.TrimSpace(d)}` のみを詰めていることを確認)。

**新規に起票した項目**: 是正要求 **R-DM-9** (operations.md §6.1 の RL-2 完了条件。**反映済み**) /
§8.2 の **DM-Q2 に③ (移管対象 28 テーブルの行数実測)** を追加 /
§8.4 の仮定に **5 (メンバー削除が発生する運用操作であること) と 6 (`theme_id` が呼び出し時点で決まっていること)** を追加。
**`[Answer]` は追加も削除もしていない** (DM-A1 / DM-A2 / DM-A3 の 3 本のまま)。

**未反映 / 本書の担当外として残したもの**:

- **auth.md §6.3-1 の表と機械検査の更新** (R-DM-4 の②) と **append-only の FK 例外の記載** (同③) —
  auth.md はレビュー対象外・編集対象外のため**是正要求として起票のみ**。
  ①は**メインセッションが 2026-07-30 に反映済み**であることを実測して注記した
- **operations.md §6.1 の RL-2 完了条件** (R-DM-9) — 同様に**メインセッションが 2026-07-30 に反映済み**
- **observability.md §4.2 への `theme_id` 追記** (R-DM-8 差し替え後) / **API 系 3 件** (R-DM-1 / R-DM-2 / R-DM-3 /
  R-DM-7) / **architecture.md 3 点** (R-DM-5) — いずれも**編集対象外のため要求として起票のみ**

**実行した検証** (2026-07-30):

```
$ make check
[doc-lint] 対象 83 ファイル / エラー 0 件 / 警告 48 件
   （data-model.md の警告は 3 件 = 意図的な [Answer] 行のみ。増分 6 件は
     別セッションが起草中の docs/design/frontend.md による）
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 46/46 カバー — OK
[workflow-shell] 検査 45 ブロック / エラー 0 件

$ # 所有者列の機械照合 (§4.1.1 の 39 行。2 表分割後も成立することの確認)
行数(数字始まり): 39 / contract_id 無し行: 0 / 両方(個人): 31 / contract_id のみ(契約): 8
境界列と所有者列の不整合: 0 件

$ # §3.4.2 の 3 分類が §4.1.1 の「account_id を持つ 31 件」と一致するか
分類①=28 分類②=2 分類③=1 / 合計=31        ← 期待どおり
OK: 31/31 が §3.4.2 に列挙されている
OK: 契約境界 8 件は §3.4.2 に現れない

$ # §4.1.2 の 2 表分割 (6 + 5 = 11) と auth.md との突合
(a) 6 件: contracts auth_roles admin_accounts admin_auth_roles register_admin_password_requests auth_rate_limit_counters
(b) 5 件: accounts companies signup_links account_mfa_configs reset_password_requests
11 件すべてが docs/design/auth.md §6.3 の例外表に存在 (不在 0 件)
```


---

## SSOT 側の是正 (2026-07-30・メインセッションが並行実施)

`data-model.md` 本体の修正は別セッションが実施中。**他文書が SSOT を持つ 2 件はメインセッションが反映した**:

| 指摘 | 反映先 | 内容 |
|---|---|---|
| **重大 3** の R-DM-4 拡張分 | `docs/design/auth.md` §6.3 | ①**機械検査の条件を「どちらも持たない」→「`contract_id` を持たない」に強化** (DM-2 の規約強化を SSOT に反映) ②検査の入力となる例外は「所有者列を持たないテーブル」だけであり、**所有者列は持つがクエリ側で条件を掛けられないものは §6.4 許可リストの対象で本検査の例外ではない**ことを明記 ③例外列挙に **`auth_rate_limit_counters`** (所有者列なし = 真の例外) と **`account_mfa_configs`** (`account_id` を持つ = 例外ではない旨の注記) の 2 行を追加 |
| **重大 2** の R-DM-9 | `docs/design/operations.md` §6.1 | **RL-2 の完了条件に ⑦「prod の初期スキーマを投入済み」を追加**。`apply_migration` を `release` を伴わずに 1 回単独起動し `prod-db` の承認を通す。承認欄も `H-2` を追加。**RL-3 のデータ移送がテーブル不在の DB に走る経路を塞いだ**。「リリースより前に適用」は差分適用の規則で、初期投入はその特例であることを明記 |

これにより **重大 2 / 重大 3 の文書間不一致は解消**した。

**追記 (2026-07-30 夜)**: `data-model.md` 側の 12 件も別セッションが反映を完了した (下記「指摘の反映」節)。
その過程で**レビュー指摘を超える発見 1 件**が出たため、メインセッションが SSOT 側を追加是正した:

| 発見 / 要求 | 反映先 | 内容 |
|---|---|---|
| **除外リストは 6 件ではなく 8 件** — (b) の `account_mfa_configs` / `reset_password_requests` は **`contract_id` を持たない**ため、規約強化後の検査① (「`contract_id` を持たない」を検出) を物理的に通れない | `docs/design/auth.md` §6.3-3 | 除外リストを **8 件**とし、**除外の理由を 2 種類** ((a) 所有者列なし 6 件 / (b) `account_id` は持つが `contract_id` なし 2 件) に分けて明記。**`contract_id` を持つ `accounts` / `companies` / `signup_links` は除外しない**ことも明示 |
| **R-DM-4 ②** 表と機械検査を DM-2 の強化に合わせる | 同 §6.3-1 | 境界の表を「契約スコープ = `contract_id`」「個人スコープ = **`contract_id` + `account_id`**」に改め、**`account_id` だけを持つ形は採らない**理由を明記 |
| **R-DM-4 ③** append-only の FK 例外 | 同 §6.3-1 | `llm_call_records` は `account_id` を**実行者の記録**として持ち **FK を張らない**。**所有者列の例外ではない**ことを明示 |
| **R-DM-5 ③** `architecture.md:724` の例外記述 | `docs/design/architecture.md` §4 | 「例外はアイデンティティ基盤テーブル」→「**除外リストは 8 件・理由 2 種類。列挙の SSOT は data-model.md §4.1.2**」へ差し替え |
| **R-DM-8 (差し替え後)** `theme_id` のフィールド要件 | `docs/design/observability.md` §4.2 | LLM 明細のフィールド表に **`theme_id`** を追加 (NULL 可・FK なしの判断は data-model.md §4.10) |

**残る是正要求は API/ 宛ての R-DM-1 / 2 / 3 / 7 のみ** (別セッションが `docs/design/API/` を担当)。

---

## 2 巡目 (確認・2026-07-30)

**モード**: 1 巡目指摘 (重大 3 / 中 5 / 軽微 4 = 12 件) の**解消判定と回帰検査のみ**。新規の網羅レビューは行っていない。

**レビュー対象** (リポジトリ相対パス):

- `docs/design/data-model.md` (主対象・全文)
- 付随確認 (編集していない): `docs/design/auth.md` §6.3 / `docs/design/operations.md` §6.1 /
  `docs/design/architecture.md` §4 / `docs/design/observability.md` §4.2

### 結論

**Freeze 不可 (重大 1 件)**。12 件のうち **11 件は解消**、**重大 3 のみ部分解消**。
部分解消の原因は 1 巡目指摘の未対応ではなく、**修正の過程で入った事実誤認 1 件が
data-model / auth / architecture の 3 文書へ伝播した**ことである (下記 R-1)。
修正は 1 つの事実訂正と除外リストの件数更新で済み、設計の骨格は変わらない。

### 1. 解消判定表

| # | 指摘 | 判定 | 根拠 (実測) |
|---|---|---|---|
| **重大 1** | 検査②と⑤の非両立 / 3 分類の網羅性 | **解消** | §3.4.2 の 3 分類を機械照合: **分類① 28 + ② 2 + ③ 1 = 31 (ユニーク 31)** が **§4.1.1 の `account_id` 保有 31 件と完全一致** (差分 0 / 契約境界 8 件の混入 0)。§3.3 の検査を②-1 (分類①の集合一致) と②-2 (網羅性 + ②③の有限列挙) に分割し、`:198`〜`:202` に両立理由を明記。§7.2 も検査 2-1 / 2-2 に分割し `:1044`〜`:1049` で検査 5 との両立を説明、**検査 6 (append-only への FK 禁止) を追加**。§4.9 (`:629`〜`:630`) は所有者列 FK を表内に明示し CASCADE が §3.3-2 / DM-6 の例外である旨と `NO ACTION` を選ばない理由 (`:240`〜`:243`) を記載。§4.10 (`:663`〜`:668`) は `llm_call_records.account_id` を「実行者の記録」と定義し、検査 2-1 の対象外・検査 5 側であることを書き分け。分類③の FK 不在も却下案 3 つ付きで決定 (`:251`〜`:259`) |
| **重大 2** | prod 初期スキーマの段の矛盾 | **解消 (文書間一致を確認)** | data-model `:908`〜`:918` の表 = 段 **RL-2** / ジョブ **`apply_migration` を `release` 抜きで単独起動** / 実行主体 **人間の手動** / 承認 **`prod-db` (H-2)** / 経路 ECS RunTask。`operations.md:415` の RL-2 完了条件に **⑦「prod の初期スキーマを投入済み」**が存在し、**承認欄に `H-2`** が入り、**手順の SSOT を data-model.md §6.3 と明示**、「§7.4 の『リリースより前に適用』は差分適用の規則で初期投入はその特例」まで同文。**両文書が同じことを言っている**。§6.2-1 の見出しも「差分適用の規則」に改まり (`:871`)、ロールバック表の初期投入行も RL-2 前提 (`:931`) |
| **重大 3** | 例外列挙の 2 分類 / auth.md との整合 | **部分解消** | 構造面は解消: §4.1.2 が (a) 6 件 / (b) 5 件の 2 表に分割され、**検査①の除外リストは「(a) 6 件 + `contract_id` を持たない 2 件 = 8 件」**に確定 (`:193` / `:1037` / `:390`〜`:399`)。`auth.md:601`〜`:612` も **8 件・理由 2 種**に更新済みで、`architecture.md:724` も「除外リストは 8 件・理由 2 種・列挙の SSOT は data-model.md §4.1.2」に差し替え済み。**残る欠陥**: (b) 表の `signup_links` 行の事実が誤り → **R-1 (新規重大)** |
| **中 1** | 台帳エントリの安定 ID | **解消** | §4.11.2 `:726`〜`:733` に `entry_id` を**必須**として新設 (型 `uuid` / 生成は `entity/conversation` の 1 関数 / 呼び出し側が値を決める引数を作らない / 却下案 3)。`conversation_ledger_archives` に `entry_id uuid NOT NULL` + `UNIQUE (session_id, field_name, entry_id)` (`:510`)、`plan_tab_versions.content.source_deep_dive_entry_ids` を**空配列 = 未使用**として必須化、§4.11.3 の grounding 行 (`:799`) が `entry_id` 列挙に書き換わり退避済みエントリの追跡も明記。**append-only で後から足せない性質に対し「第 1 リリースから必須」**と決めており、指摘の趣旨を満たす |
| **中 2** | 新規 UNIQUE と v2 既存データの衝突 | **解消 (v2 実測を照合)** | §6.4 項目 8 (`:963`〜`:982`)。実測を一次ソースで確認: v2 `themes` は 6 列で **UNIQUE 無し** (`hassan-v2-backend/db/schema.sql:94`〜`:102`) / v2 `business_plans` は **`CREATE INDEX idx_business_plans_idea_id`** のみ (`同:204`) / ナレッジは v2 に無し。**検出は「移行の設計時 (切替当日ではない)」・v2 へ読み取り専用接続**と明記。写像規則⑥ (v2 に列が無い `NOT NULL` 列の既定値) も追加 |
| **中 3** | `llm_call_records` の相関キー | **解消** | §4.10 に `theme_id bigint NULL` + 部分インデックス (`:658`)、`session_id` 経由にしない理由・NULL を入れる経路・FK を張らない決定と却下案 3 (`:670`〜`:681`)、CHECK の対象を計測フィールドに限る書き分け (`:684`〜`:689`)、§8.4-6 に仮定を追加 (`:1129`)。SSOT 側 `observability.md:138` にも `theme_id` 行が追加済み |
| **中 4** | ID 維持が全テーブルで成立しない | **解消 (v2 実測を照合)** | §6.4 写像規則① (`:957`) に `asset_documents` の例外。一次ソースで確認: v2 は `id uuid NOT NULL` / `PRIMARY KEY (id)` の 5 列テーブル (`hassan-v2-backend/db/schema.sql:510`〜`:516`)。`contracts` / `accounts` / `companies` は §4.2 で `uuid` 維持のため影響なしという記述も v2 実測 (`同:30` に `contract_id uuid` / `:79`) と整合 |
| **中 5** | 移管の実行可能性 | **解消** | §3.4.3 (`:261`〜`:269`) の 5 項目 (1 バッチ = 1 集約 = 1 トランザクション / バッチ上限を `config` の SSOT に置く (既定 50。BE-2) / 進捗は残件数 + `UPDATE ... WHERE account_id` の冪等性 / 非同期ジョブ・残件 0 後にのみ物理削除 / 行数実測は DM-Q2 ③へ起票し推測値を書かない) |
| **軽微 1** | 是正要求の陳腐化 | **解消 (ただし 1 件が再発 → R-3)** | §8.3 が「状態 (2026-07-30 時点)」列を持つ形になり (`:1101`)、R-DM-6 は根拠付きで「解消済み (要求は無効)」、R-DM-9 は「反映済み」、R-DM-5 は有効な 3 点に絞られた。**R-DM-8 の状態表記だけが半分 stale** (R-3) |
| **軽微 2** | D-6 の無言の省略 | **解消** | 冒頭 `:8`〜`:11` に **D-2 / D-6** を追記し、D-6 は operations.md §5.2 が SSOT・Agent ID は SSM Parameter Store で本書に該当テーブル無しと所在を明記 |
| **軽微 3** | §4.9 の詳細表に所有者列 FK が無い | **解消** | §4.3 に共通前置き (`:431`〜`:435`) を置き §4.4〜§4.10 の各節冒頭が参照。例外に該当する §4.9 / §4.10 は表内に所有者列 FK を明示 (`:624`〜`:630` / `:653`〜`:654`) |
| **軽微 4** | `visibility` の値域の別管理 | **解消** | DM-9 (`:125`) と §5 の A-7 行 (`:817`) の両方に「列と値域は本書 (値の一覧は `entity/`) / 開放時期と画面での意味は API」の書き分けを 1 行で記載 |

**解消 11 / 部分 1 / 未解消 0**。

### 2. 回帰検査 (修正で新たに入った矛盾)

#### R-1 (重大・新規). `signup_links` が `contract_id` を持つ、という誤った事実が 3 文書に伝播している

`docs/design/data-model.md:386` の (b) 表:

| テーブル | 実際に持つ列 | 検査① |
|---|---|---|
| `signup_links` | `contract_id` | **通る** |

**v2 の実測は逆である** — `hassan-v2-backend/db/schema.sql:342`〜`:348` の `signup_links` は
**`id` / `email` / `expired_at` / `created_at` / `updated_at` の 5 列のみ**で、
**`contract_id` も `account_id` も持たない** (`db/queries/signup_link.sql:2`〜`:8` の 3 本も
`id` だけで引いている)。`companies` (`同:79`) と `accounts` (`同:30`) は `contract_id` を持つため
(b) 表の他 2 行は正しく、**誤っているのは `signup_links` 1 行**である。出典が付いていない
(§4.2 は `:342` を挙げるが列の主張はしていない) — **DR-1**。

**本番で何が起きるか**: 本書 §4.2 は同テーブルを「**v2 の構造をそのまま v3 に作る (v2 に無い列を足さない)**」
対象に含めている (`:411`〜`:409`)。したがって v3 の `signup_links` にも `contract_id` は無い。
一方 §3.3 の検査① / §7.2 の検査 1 は「**除外リスト 8 件以外の全テーブルが `contract_id` を持つこと**」で
`signup_links` を除外リストに入れないと明記している (`:193` / `:395` / `:1037`)。
**AC-1.2 が要求する機械検査が、設計どおり実装すると初日から赤になる** —
実装リポでは「検査を通すために `signup_links` に `contract_id` を足す (§4.2 の 1:1 移行方針に違反)」か
「検査の除外リストを実装者判断で広げる (AC-1.2 の『列挙外は検出される』が骨抜き)」のどちらかが起き、
後者は 1 巡目重大 3 が塞いだはずの穴の再現である。

**伝播先** (どちらも同じ誤りを断定している):

- `docs/design/auth.md:605`〜`:606` —「**`contract_id` を持つ `accounts` / `companies` / `signup_links` は
  除外リストに入れない** (検査を通る)」
- `docs/design/architecture.md:724` —「除外リストの実体は 8 件」(件数のみだが本書を SSOT として引用)

**修正案** (どちらかを選び、選んだ理由を書く。**曖昧に残さない**):

- (a) **v3 の `signup_links` に `contract_id NOT NULL` を持たせる** — 招待リンクは契約に属するという
  意味論に合い、検査① をそのまま通せる。**§4.2 の「列の追加なし」に対する明示の例外**として書き、
  §6.4 の写像規則に「v2 の `signup_links` には対応列が無いため既定値の決め方が必要」(規則⑥と同型) を追加する
- (b) **除外リストを 9 件にする** — (b) 表から `signup_links` を (a) 表 (所有者列を持たない側) へ移し、
  理由を「未認証経路からリンク ID で引き、契約が確定する前に発行される」とする。
  §3.3① / §7.2-1 / §4.1.2 の件数と、`auth.md` §6.3-3 の「8 件」・列挙表の該当行、
  `architecture.md:724` の「8 件」を同時に更新する

いずれの場合も**件数 (8) が 3 文書に書かれている**ため、R-1 の修正は 3 文書同時でなければ
1 巡目重大 3 と同じ「文書間で充足判定が一致しない」状態に戻る。

#### R-2 (軽微). §7.2 検査 6 の対象フィールドが実在しない組み合わせを含む

`:1051`〜`:1052` は「`llm_call_records` / `audit_logs` の `account_id` / `actor_id` / `session_id` /
`theme_id` に FK が張られていないこと」と書くが、**`audit_logs` は `account_id` / `session_id` /
`theme_id` を持たず** (§4.10 の列は `actor_type` / `actor_id` / …)、**`llm_call_records` は `actor_id` を
持たない**。実装者は解釈できるが、検査を書く人が「存在しない列を探す検査」を書くことになる。
**テーブルごとに列を対応させて書く** (`llm_call_records`: `account_id` / `session_id` / `theme_id` /
`audit_logs`: `actor_id`)。

#### R-3 (軽微). R-DM-8 の状態表記が半分 stale — 軽微 1 で直した陳腐化が同じ形で再発している

`:1110` の R-DM-8 は状態「**未対応 (内容差し替え後)**」だが、要求の中心である
**`observability.md` §4.2 のフィールド表への `theme_id` 追加は既に反映済み**である
(`docs/design/observability.md:138` に `theme_id` 行が存在し、data-model.md §4.10 を参照している)。
未対応なのは同要求の後半 (**相関キーは計測漏れ CHECK の対象外**であることの明記) のみ。
§8.3 は「解消済みの要求を『未対応』のまま残さない」と自ら宣言している (`:1098`〜`:1099`) ので、
**状態を「①反映済み / ②未対応」に分けて書く**。

#### R-4 (軽微). SSOT 側に残る読み違えの余地 (R-DM-8 の後半に対応)

`docs/design/observability.md:154` は「**NULL を許すのはこの `route_kind` のみ**」と書く。
直前の箇条書きが「トークン系 4 カウンタと `stop_reason`」に限定しているため文脈上は正しいが、
同 §4.2 の表には `session_id` / `theme_id` (どの経路でも NULL 可) が同居しているため、
**単体で読むと相関キーにも掛かる**。data-model.md §4.10 (`:688`) 側は書き分け済みなので実害は小さいが、
R-DM-8 の後半はこれを直す要求である。

#### 回帰なしを確認した点

- **SSOT の重複なし**: 3 分類の定義は §3.4.2 の 1 箇所 (`:216`「分類はこの表が唯一の定義」)、
  除外リストの列挙は §4.1.2 の 1 箇所で、§3.3 / §7.2 は**件数と参照のみ**。移行手順・承認・
  しきい値の再定義も無い (§0 の SSOT 表どおり)
- **§3.3-2 の「例外は分類②③の 3 テーブルのみ」= 2 + 1 = 3** で §3.4.2 と一致
- **§6.3 の投入順序に `auth_rate_limit_counters` が含まれる** (`:896`) — §4.2 で新設したテーブルの
  投入漏れが無い
- **`[Answer]` は 3 本** (`:859` / `:950` / `:999` = DM-A1 / DM-A2 / DM-A3) で増減なし
- **曖昧語 (DR-5) の混入なし** — 「適切に」「必要に応じて」「後で検討」「適宜」および doc-lint の
  未確定マーカー語は data-model.md 本文に 0 件

### 3. AC の充足判定

| AC | 判定 |
|---|---|
| **AC-1.2** | **R-1 を直すまで不充足**。要求文は「例外列挙外のテーブルに所有者列が無い状態が**機械検査で検出される**こと」(`aidlc-docs/inception/productionization/requirements.md:57`〜`:62`) であり、現状の設計は **`signup_links` を検出してしまう** (= 検査が設計どおり実装できない)。**2 表分割そのものは機械照合可能**で、39 件の所有者列・31/8 の境界内訳・除外 8 件は機械的に突き合わせられることを本レビューで実証した (下記検証) |
| **AC-3.4** | **充足** (方式のみ `[Answer]`)。適用タイミング (差分適用の規則 + 初期投入の特例)・後方互換 (§6.2 の 8 分類への写像)・ロールバック (§6.3 の 4 行)・**初回投入の段と承認**が確定し、operations.md と一致 |
| **AC-3.5** (データ面) | **1 巡目どおり部分回答**。DM-A2 待ちであることと、回答後に埋める 8 項目が明示されている |

### 4. 実行した検証

```
$ make check
[doc-lint] 対象 85 ファイル / エラー 0 件 / 警告 50 件
   （data-model.md の警告は :859 / :950 / :999 の [Answer] 3 件のみ。
     他の警告は frontend.md / infrastructure.md / llm-migration.md / testing.md /
     operations.md / design_memo.md に属し本レビュー範囲外）
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 46/46 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
[workflow-shell] 検査 50 ブロック / エラー 0 件

$ # §4.1.1 の所有者列 (39 行を機械抽出)
rows: 39
個人(account_id+contract_id): 31
契約(contract_idのみ): 8 = theme_members / idea_boards / idea_board_members /
  idea_board_phases / idea_board_items / idea_board_comments / workspace_settings / audit_logs
（全 39 行に contract_id があることを assert で確認 — 例外 0）

$ # §3.4.2 の 3 分類 × §4.1.1 の個人 31 件
分類① 28 / 分類② 2 (read_news_accounts, account_notification_settings) / 分類③ 1 (llm_call_records)
合計 31 / ユニーク 31
§4.1.1 個人31 - §3.4.2 = []      ← 未分類なし
§3.4.2 - §4.1.1 個人31 = []      ← 幽霊テーブルなし
契約境界 8 件の §3.4.2 への混入 = []

$ # v2 実測 (hassan-v2-backend/db/schema.sql。読み取りのみ)
signup_links (schema.sql:342) cols=5 contract_id=False account_id=False
   id uuid | email text | expired_at | created_at | updated_at      ← R-1 の根拠
account_mfa_configs (schema.sql:68)      contract_id=False account_id=True   ← (b) の記述と一致
reset_password_requests (schema.sql:312) contract_id=False account_id=True   ← 一致
companies (schema.sql:79)                contract_id=True                    ← 一致
accounts (schema.sql:30)                 contract_id=True                    ← 一致
asset_documents (schema.sql:510) cols=5 = id uuid NOT NULL / file_text / created_at /
   updated_at / PRIMARY KEY (id)                                             ← 中 4 の根拠と一致
themes (schema.sql:94) cols=6 + FK, UNIQUE なし                              ← 中 2 の根拠と一致
business_plans: CREATE INDEX idx_business_plans_idea_id (schema.sql:204)     ← 中 2 の根拠と一致
```

**抜き取り照合 6 件** (依頼どおり 6 件で打ち切り): ①v2 のアイデンティティ系 5 テーブルの列
(`schema.sql:30` / `:68` / `:79` / `:312` / `:342`) ②v2 `asset_documents` の uuid PK (`:510`)
③v2 `themes` の列数と UNIQUE 不在 (`:94`) ④v2 `business_plans` の索引 (`:204`)
⑤`operations.md:415` の RL-2 完了条件⑦と承認欄 ⑥`architecture.md:724` と `observability.md:138`。

**照合していない範囲** (2 巡目のスコープ外): §4.4〜§4.8 の個々の列・インデックスの妥当性、
API 系 4 件の是正要求 (R-DM-1 / 2 / 3 / 7) の対象文書、PoC 出典 (1 巡目で 9 件照合済み・全一致のため再照合せず)。

### 5. Freeze 可否

**不可 (重大 1 件 = R-1)**。修正内容は次の 2 ステップで、設計判断の骨格は変わらない:

1. `signup_links` の扱いを (a) `contract_id` を持たせる / (b) 除外リストへ移す のいずれかで**決定**し、
   採用理由を書く (v2 の 5 列を一次ソースとして出典を付ける)
2. **件数 (8 → 8 または 9) を 3 文書同時に更新**する:
   `docs/design/data-model.md` §3.3① / §4.1.2 (a)(b) / §7.2-1 ・
   `docs/design/auth.md` §6.3-3 と例外表 ・ `docs/design/architecture.md` §4

軽微 3 件 (R-2 / R-3 / R-4) は Freeze の障害ではない。**再レビューは R-1 の差分のみで足りる**
(3 分類・初期投入・entry_id・theme_id・移管方式は本巡で機械照合まで済んでおり、再確認不要)。


---

## 2 巡目の新規重大 (R-1) の反映 (2026-07-30・メインセッション)

**指摘は正しかった** — オーケストレーターが一次ソースで確認:

```
$ sed -n '/CREATE TABLE signup_links/,/);/p' hassan-v2-backend/db/schema.sql
CREATE TABLE signup_links (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    email text NOT NULL,
    expired_at timestamptz NOT NULL,
    created_at ... , updated_at ...
);
```

`signup_links` は **所有者列を 1 つも持たない**。「`contract_id` を持つ → 検査①を通る」という記述は事実誤認だった。

| 反映先 | 内容 |
|---|---|
| `docs/design/data-model.md` §4.1.2 | `signup_links` を **(b) 表から (a) 表へ移動**。(a) = **7 件** / (b) = **4 件**、**除外リスト = 9 件**。移動理由と一次ソース (schema.sql:342) を行内に明記 |
| 同 §3.3① / §7.2 / §5 A-3 / §8.3 (R-DM-4) | 件数を **8 → 9** に統一。「`accounts` / `companies` / `signup_links` は除外しない」→ **「`accounts` / `companies` は除外しない」**に修正。auth.md との差分も **2 件 → 3 件**へ |
| 同 §8.1 **DM-A4 (新規起票)** | **`signup_links` に `contract_id` を持たせるか**の設計判断を `[Answer]` として起票。案 A (v2 踏襲・除外 9 件。暫定既定) / 案 B (`contract_id` を持たせる・除外 8 件に戻る) を影響つきで提示し、**判断材料 = 「契約の管理者が自契約へメンバーを招待する経路があるか」**と明記 (Task-3i と同時に決める) |
| `docs/design/auth.md` §6.3 | 除外リストを **9 件**に更新。例外表に `signup_links` 行を追加 (従来「`contract_id` を持つ」と書いていたのが誤りだった経緯も記載) |
| `docs/design/architecture.md` §4 | 「除外リストの実体は **9 件**・(a) 7 件 / (b) 2 件」に更新 |

**件数の機械照合** (2026-07-30 実施): (a) = 6 行 / **7 テーブル** (`admin_accounts` と `admin_auth_roles` が 1 行) +
(b) のうち `contract_id` を持たない 2 件 = **除外 9 件**。3 文書 (data-model / auth / architecture) の記述が一致。

R-2〜R-4 (軽微) は未反映 — Freeze の阻害要因ではないが、`observability.md` 側の陳腐化 (R-3 / R-4) は
同書を触る次の機会にまとめて直す。
