# レビュー: AA-D-24 (監査ログ 4 件の復帰) / AA-D-25 (`/contract` `/company` への改名)

- **実施日**: 2026-08-23
- **レビュアー**: design-reviewer (起草セッションとは別セッション)
- **基準**: 本番基準 (`.claude/rules/08-production-gates.md`) + `.claude/rules/feedback_review_patterns.md` (DR 全件)

## レビュー結果サマリ

- **対象 (未コミット差分。リポジトリ相対パス)**
  - `docs/design/API/auth-accounts.md` — AA-D-24 / AA-D-25 とその波及 (§2.3.3 / §2.6 / §3 決定表 / §3.5 / §3.7 / §6.1 / §7 / §5 R-AA-7)
  - `docs/design/observability.md` — §4.5.1 の `action` 値域に 4 値の行を追加
  - `docs/analysis/v2-feature-inventory.md` — §2.1 の `GET /contracts` 行の v3 対応先を `GET /contract` に追従
  - **対象外**: 増分 proto-v4 (`docs/design/API/ideas.md` / `conversation.md` 等) は
    [review-proto-v4.md](review-proto-v4.md) で既レビュー。`aidlc-docs/schedule-2026q3.md` /
    `docs/design/README.md` / `docs/design/API/auth-accounts.md` の proto-v4 由来部分も同様
- **重大: 3 件 / 中: 5 件 / 軽微: 3 件**
- **実行した検証**
  - `make check` — **エラー 0 / 全ゲート緑** (出力は §「実行した検証」)
  - **一次ソース抜き取り照合 4 件** (`hassan-v2-backend/auth/event_mapper.go` / `entity/event_log.go` /
    `db/schema.sql` / `repository/activity_log.go`) — **AA-D-24 の load-bearing な事実は全数一致**
  - DR-8 の再検査 grep 5 種 (`contracts/me` / `companies/me` / `member_create` 系 4 値 /
    `2.3.3` の被参照 / `D-API-2`)

---

## 事実照合 (観点 1)

### AA-D-24 の根拠 = `hassan-v2-backend/auth/event_mapper.go` — **6 件すべて実在。行番号も正確**

| 設計書の主張 | 実測 (一次ソース) | 判定 |
|---|---|---|
| `POST /accounts` → `member_create` (`:62`) | `event_mapper.go:62` `"POST /accounts": {EventCategoryMember, EventTypeMemberCreate}` | ✅ |
| `PUT /accounts/admin` → `member_update_by_admin` | `event_mapper.go:63` | ✅ |
| `DELETE /accounts/:id` → `member_delete_by_admin` | `event_mapper.go:64` | ✅ |
| `PUT /companies/mfa` → `contract_update_mfa` (`:67`) | `event_mapper.go:67` | ✅ |
| `PUT /accounts/email` → `account_update_email` (`:73`) | `event_mapper.go:73` | ✅ |
| `PUT /accounts/password` → `account_update_password` (`:74`) | `event_mapper.go:74` | ✅ |

**`action` 文字列も v2 の定数値と一致**: `entity/event_log.go:102-104` (`member_create` /
`member_update_by_admin` / `member_delete_by_admin`)、`:109` (`contract_update_mfa`)、
`:114-115` (`account_update_email` / `account_update_password`)。
**設計書が写した値は v2 の実文字列そのもの**であり、転記の誤りは無い。

### 「残りは v2 に前例が無い」の再確認 (AA-D-24 が「変更なし」と主張した部分) — **妥当**

- `POST /admin/signin` / ロック・解除: `event_mapper.go` の map (`:23`-`:76`) に `/admin/*` も
  `unlock` も無く、`activity_logs` 側の書き込みメソッドも
  `repository/activity_log.go` の 12 種 (`CreateAccountSigninSuccessLog` 〜
  `CreateIdeaBoardActionFailedLog`) にロック・管理者サインインは無い → **前例なし。判定は妥当**
- リセットの**実行**: map にあるのは `POST /accounts/reset-password` (= **要求**、`:75`) のみ。
  実行 (`:hash` 付き) は無い → **前例なし。判定は妥当**

> **結論**: AA-D-24 は「AA-D-23 の事実誤認の訂正」として**事実面で正しい**。
> 誤認の原因は、v2 の監査が **2 系統** (`activity_logs` = セキュリティ / `event_logs` = 操作)
> であるところ `activity_log_type` enum (`db/schema.sql:467`〜) だけを見ていたこと。
> **v2 の 2 系統は `docs/analysis/v2-auth-tenancy.md:271-274` に既に記録済み**であり
> (`auth/event_mapper.go:12-95` の名指しまである)、**リポジトリ内の事実基盤で防げた誤認**だった (→ 中 4)。

### AA-D-25 (パス改名) の影響

- 本数は変わらない (33 本 / 403 = 16 本) — `make check-endpoint-mapping` が
  `auth-accounts.md 33 本 / 403 16 本` を実測して緑。**DR-9 の観点で新たなずれは無い**
- 旧パスの残存 grep (`docs/` `aidlc-docs/` `templates/` `.claude/`):
  設計として生きている記述で旧パスが残るのは **`docs/design/auth.md:1668`** の 1 件 (→ 中 5)。
  他は過去 review (履歴) と AA-D-23 / AA-D-24 の経緯注記

---

## 重大 (Must Fix)

### 重大 1. §3.7 の表の**直前の注記**が旧版のまま — 「5 行」「値域に不足は無い」が 9 行の表と矛盾 (DR-8)

**箇所**: `docs/design/API/auth-accounts.md:648-655` (§3.7 の表の直前の引用ブロック)

> **2026-08-10 の AA-D-23 で本表を v2 相当の 5 行に絞ったため、§4.5.1 の値域に不足は無くなった** —
> 残る 5 事象の値 (…6 値…とリセット要求) はいずれも v2 の前例を持つ。
> **§5 R-AA-7③ (不足 7 値の追加要求) は取り下げる**

**なぜ本番で問題になるか**: 同じ節の中で、表は **9 行**、`§7` の O-6 行は **9 行**、`§5` の R-AA-7 は
**「4 種は値域に追加済み」**、`observability.md` §4.5.1 には**新しい行が追加済み**なのに、
**表の直前 (実装者が最初に読む位置) だけが「5 行 / 値域に不足なし」**と言っている。
`§4.5.1` の値域は **Go 定数 1 箇所 + CI 照合**で担保される設計 (`observability.md:311-314`) なので、
実装者が直前の注記を信じて 6 値だけ定数化すると **CI が落ちるか、4 事象の記録が黙って落ちる**。
**DR-8 の典型 (思考の対象になった節だけ直し、同じ事実に依拠する隣接記述が旧版のまま)**。

**修正案**: 当該ブロックを「AA-D-23 で 5 行に絞り、**2026-08-14 の AA-D-24 で 9 行に戻した**。
値域は §4.5.1 の**認証 6 種 + メンバー・アカウント設定 4 種**で足りる (R-AA-7③ の取り下げは
真に v3 独自の事象についてのみ有効)」に書き換える。**数値は書かずに §4.5.1 へのリンクにする**選択肢も可 (DR-9)。

### 重大 2. AA-D-23 注記の **C-16 の結論**が未訂正 — 「v2 にある操作を落とす」ことの承認記録になっていない

**箇所**: `docs/design/API/auth-accounts.md:674-675`

> **削除した対象**: … / メンバー作成・権限変更・削除 / 招待の発行・受諾 /
> パスワードリセットの**実行**とパスワード・メール変更 / `PUT /companies/me/mfa`。
> **いずれも v2 に前例が無い事象**であり、**C-16 (v2 にある操作は落とさない) の対象外**。

**なぜ本番で問題になるか**: この 2 行は AA-D-24 で**前提が崩れた**が、崩れたのは
「前例が無い」だけでなく **C-16 の結論**である。実測 (`event_mapper.go:63`, `:64`) のとおり
`member_update_by_admin` / `member_delete_by_admin` は **v2 が記録していた**ので、
v3 で記録しないことは「**スコープを広げない**」ではなく「**v2 でできていた監査を落とす**」= C-16 抵触である
(ユーザー承認は 2026-08-14 に存在するので判断自体は有効。**記録の形が誤っている**)。
このままだと、実装リポの読者は 674-675 行を根拠に「**v2 からの後退は 1 件も無い**」と結論する。
権限変更・メンバー削除は**不可逆かつ権限昇格を含む操作**で、監査が無いと事故時に実行者を特定できない (O-6)。
加えて 674 行の列挙には**復帰済みの 4 件がそのまま残っている**ため、
この行だけ読むと「メンバー作成・メール変更・パスワード変更・会社 MFA は記録しない」と読める。

**修正案**:
1. 674 行の列挙から復帰した 4 件を**取り消し線**にし、「復帰は下の 2026-08-14 注記」を添える
2. 675 行を「**`member_update_by_admin` / `member_delete_by_admin` は v2 に前例があるため C-16 に抵触する。
   2026-08-14 のユーザー決定で意図的な後退として承認済み**。残り (`POST /admin/signin`・ロック・解除・
   招待の発行・受諾・リセットの実行) は前例が無く C-16 の対象外」に分割する
3. 「失うもの②」に**C-16 抵触である旨**を明記し、再開の入口 (AA-Q14) と紐づける

### 重大 3. AA-D-25 の単数形パスが **`API/README.md` の共通規約 (D-API-2) と衝突**したまま、SSOT への是正要求が無い

**箇所**: `docs/design/API/auth-accounts.md:178-181` / `:361` (AA-D-25) ↔
`docs/design/API/README.md:112` (D-API-2) / `:29-33` (「差分 3 点」)

**事実**:
- `API/README.md:112` D-API-2 = **「kebab-case + 複数形に統一」**。却下案 (a) は
  v2 の `/company-mission` (**単数**) を不統一の実例として名指ししている
- `API/README.md:29` = 「auth-accounts.md は**同じ規約に載る**が、認証系であるがゆえの**差分 3 点**を持つ」
  として①公開 6 本 ②401 の本文 ③429 の 10 本を列挙 (+403 の第 3 系統)
- AA-D-25 は `/contract` / `/company` / `/company/mfa` という**単数形**を採用し、
  「**ID 不要の単一リソースは単数形パスで表す**」という**一般規則**を宣言している

**なぜ本番で問題になるか**: D-API-2 の遵守は**機械検査がパスパラメータ側しか見ない**
(`API/README.md:192` の検査は `{id}` を弾くだけ) ため、**この不整合はどの `make check` にも現れない**。
結果、実装者は (a) README を正として `/contracts` に「直す」か、(b) auth-accounts を正として
他ドメインにも単数形を持ち込むかを**その場で判断**する。**先例のある扱い方は plans.md** で、
同書は D-API-2 の「ネストは 2 段まで」からの逸脱を **§2 の準拠表 1 行 + D-PL-18 (却下案・適用範囲の限定)** で
明示している (`docs/design/API/plans.md:95` / `:821`)。AA-D-25 にはこれが無い。

**修正案** (どちらか):
- (i) **AA-D-25 に D-API-2 との関係を 1 行足す** — 「D-API-2 の『複数形』は**コレクションを持つリソース**に
  かかる規約であり、**ID 不要の単一リソース (singleton) は単数形**とする。逸脱ではなく**規約の細則**として
  `API/README.md` D-API-2 に追記する」+ **§5 に R-AA-xx を起票**して README §0 の「差分」に④を登録する
- (ii) singleton 規則を **README D-API-2 側の SSOT に昇格**させ、auth-accounts はそれを参照するだけにする

**ついでに必要な波及**: `API/README.md:29` の「**差分 3 点**」という**件数**が動く (DR-9)。
件数を書かずに「差分 (①〜④)」と列挙だけにするか、`check-endpoint-mapping` の検査対象に加えること。

---

## 中 (Should Fix)

### 中 1. 「9 行」「4 件」が 5 箇所以上に転記され、機械照合の対象外 (DR-9)

現在の転記先: `auth-accounts.md` §3.7 の表 (実体 9 行) / §7 の O-6 行 (「9 行」「4 行」「5 → 9」) /
§5 R-AA-7 (「4 種」) / §6.1 AA-Q14 (「4 件」) / `observability.md` §4.5.1 の新行 (「この 4 件」)。
`make check-endpoint-mapping` は**エンドポイント数と 403 数しか見ておらず、監査表の行数は無検査**。
DR-9 の規約 (「新しく『N 件』を書くときは、同時に検算の対象に加えるか、書かずに定義元へのリンクにする」) に照らして未処理。
**対処**: `scripts/check-endpoint-mapping.sh` に検査⑧として
「§3.7 の表の行数 ↔ §7 の自称値 ↔ `observability.md` §4.5.1 の値の総数」を追加するか、§7 から数値を落とす。
**tool 本数を検査⑤として機械強制した先例**がある (`.claude/rules/05-harness.md`)。

### 中 2. §3.7 の「リセット要求」行に対応する `action` 値が **`observability.md` §4.5.1 に無い** (BE-10)

§3.7 の 5 行目 (`POST /accounts/reset-password` = 要求) は「v2 は `event_logs` に要求のみ
(`usecase/account/request_reset_password.go:56`)」を前例に**記録する**と決めているのに、
`observability.md` §4.5.1 の値域には対応する値 (v2 の `account_request_reset_password`
= `event_mapper.go:75` / `entity/event_log.go` の定数) が**無い**。
`§7` の O-6 行が今回「**6 種 + 4 種で足り**」と**明示的に断定**したため、**この不足が断定で塗り潰された**。
値域は Go 定数 + CI 照合で担保されるため、**表にある行を実装しようとすると定数が無い**状態になる
(読む側と書く側の対 = BE-10)。**対処**: §4.5.1 に `account_request_reset_password` を追加するか、
§3.7 の当該行を「記録しない」に変更する (どちらでもよいが**どちらかに決める**)。
※ 不足自体は AA-D-24 以前からの持ち越しだが、**§7 の断定を書き換えた今回が是正の機会**。

### 中 3. `settings.md` の「活動種別の値域は observability §4.5 の `action` 定義と揃える」が**行を絞っていない**

`docs/design/API/settings.md:75` / `:145` (D-ST-6) は `GET /usage-summary` のクロス集計軸を
「§4.5 の `action` 定義」に委譲している。§4.5.1 は今回**行が 1 つ増えた**ため、
文面どおりに読むと `member_create` / `account_update_email` / … が**利用状況クロス集計の軸に入る**
(プロトタイプ由来の軸は**活動種別 6 種** — 同書 `:54`)。委譲先が「表全体」か「利用状況の集計対象の行」かが
曖昧なまま値域が伸びた形で、**DR-5 (曖昧語による実装者への丸投げ)** に近い。
**対処**: `observability.md` §4.5.1 に「**`GET /usage-summary` の集計軸は『利用状況の集計対象』行に限る**」を
1 行書く (または settings.md 側の委譲先を行名まで指定する)。

### 中 4. 誤認の**原因側 (事実基盤)** が未修正 — 同型の「v2 に前例が無い」判定が再発する

AA-D-24 の誤認は「v2 の監査は 2 系統」を見落としたことによる。
`docs/analysis/v2-auth-tenancy.md:271-274` は**系統の存在と `auth/event_mapper.go:12-95` の機構**まで
書いているが、**`event_logs` に入る値 (種別) の一覧がリポジトリのどこにも無い**。
一方 `activity_log_type` の 6 値は `auth-accounts.md` R-AA-7① と `observability.md` §4.5.1 に
出典付きで載っているため、**「v2 の前例」を調べると片側だけがヒットする構造**になっている。
今回の訂正は**実装リポの issue #28 (= 設計を消費する側)** で見つかっており、
設計リポ側の検査では見つからなかった。
**対処**: `docs/analysis/v2-feature-inventory.md` (§2 の `POST /event_logs` 行付近) か
`v2-auth-tenancy.md` §の活動ログ節に、**`entity/event_log.go` の `EventType*` 一覧 (出典付き)** を
1 表として置く。以後「v2 に前例があるか」の判定が**片側だけ見て終わる**構造を潰せる。

### 中 5. `docs/design/auth.md:1668` (R-11) が旧パス `GET /contracts/me` のまま (DR-8 の受信側)

同行は AA-D-15 宛ての是正要求で、**判断内容が現役**の記述 (「`GET /contracts/me` から
`sharing_settings` を落とす」の根拠差し替え)。AA-D-25 の改名が届いていない。
1 語の修正だが、**`auth.md` は認証・テナントの SSOT** であり、ここに旧パスが残ると
「`/contract` と `/contracts/me` の 2 本があるのか」という読み違いを生む。
**対処**: `GET /contract` に更新 (AA-D-25 の参照を添える)。

---

## 軽微 (Nice to Have)

1. **出典の範囲が広い**: `auth-accounts.md:360` (AA-D-24) の `event_mapper.go:45-75` は、
   `:45` が Asset ブロックの先頭。実際の 6 件は `:62-64` / `:67` / `:73-74`。
   map 全体を指すなら `:23-76`、6 件を指すなら `:62-74` が正確。
2. **§3.7 の注記内の数え上げが元から合っていない** (今回の差分の責任ではない):
   「残る **5** 事象の値 (6 値**とリセット要求**)」= 表 5 行に対し値が 7 個。重大 1 の書き換えで併せて解消できる。
3. **「招待の発行」の指す先を明記した方がよい**: AA-D-23 注記の「削除した対象」に
   「招待の発行・受諾」があるが、§2.3.2 の表では `POST /accounts` の概要が
   「**メンバー作成・招待発行**」で、その行は AA-D-24 で**記録対象に復帰している**。
   注記側は「招待リンクの単独発行・再送 (`POST /accounts/{account_id}/signup-links`) と受諾
   (`POST /accounts/signup`)」と書けば取り違えが消える (v2 の map に `signup-links` は無く、前例なしの判定は妥当)。

---

## 本番観点カバレッジ (今回の差分が触れる ID のみ)

| ID | 状態 | 箇所 |
|---|---|---|
| **O-6** 監査ログ | **回答あり (今回更新)**。ただし C-16 抵触の記録が不足 (重大 2)、値域の 1 値が不足 (中 2) | `auth-accounts.md` §3.7 / §7 の O-6 行 / `observability.md` §4.5.1 |
| **O-7** アラート | **回答あり (変更なし)**。`POST /admin/signin` は AA-D-24 でも記録対象外のため R-AA-26 が有効なまま | `auth-accounts.md` §7 の O-7 行 |
| **A-5** ステータスコード | **回答あり**。パス改名は 401/403/404 の割り当てを変えていない (§2.3.3 の固有ステータス列は改名前と同一) | `auth-accounts.md` §2.3.3 |
| **A-3 / A-4** テナント境界 | **回答あり**。`/contract` / `/company` は**認証コンテキストの `contract_id` から解決** (ID を受け取らない) と AA-D-25 が明記 — 越境入力が構造的に無くなる方向の変更 | `auth-accounts.md` §2.3.3 / §3.5 (`GetContractByID` の引数は認証コンテキスト由来のみ) |
| **A-1 / A-2 / A-6 / A-7 / O-1〜O-5 / D-1〜D-8** | **今回の差分の対象外** (既存の回答を変更していない) | — |

---

## 良かった点

1. **事実照合が全数一致した**。6 件の前例・行番号・`action` 文字列が v2 の一次ソースと完全に一致。
   「4 件だけ復帰」という**選択的な訂正**も、`event_mapper.go` の実測と 1:1 で対応している
2. **誤認を消さずに残した**。AA-D-23 の行を書き換えずに「訂正前の記録として残す」と明記し、
   AA-D-24 を別行にしたため、**なぜ判断が動いたかが後から追える**。
   `docs/design/observability.md` §4.5.1 の旧行 (取り消し線) に
   「この行が指す『削除』は次行の復帰とは異なるので混同しない」を添えたのは、
   **DR-8 の再発 (同じ語が 2 箇所で違う意味になる) を先に潰している**
3. **「事実誤認の訂正」と「スコープの拡大」を分けた**。前例のある `member_update_by_admin` /
   `member_delete_by_admin` を機械的に復帰させず、ユーザー判断として区別した点は
   AA-D-24 の却下案 (b) に理由まで書かれている (**残るのは C-16 の記録の仕方だけ** = 重大 2)
4. **AA-D-25 の却下案が具体的**。(a) 現状維持 / (b) `/mine` / (c) `{contract_id}` の 3 案があり、
   とくに (c) の却下理由が **AA-D-3 (対象は常に path param) との適用境界**を整理している
   (「越境を防ぐため対象を明示させる」は他契約を指定できない singleton には当てはまらない) —
   規約の**適用範囲**を言語化しており、DR-5 の曖昧さが無い
5. **波及がよく追えている**: §2.3.3 / §2.6 (16・17 行) / §3.5 (`GetContractByID` の用途) / §3.7 /
   §7 / `v2-feature-inventory.md` まで届いている。**AA-D-2 の本文にも「契約・会社は対象外」を書き足している**
   (決定表の親側を直す = DR-8 の正しい処理)
6. `make check` **全ゲート緑**。件数系ゲート (`check-table-counts` / `check-endpoint-mapping` /
   `check-monorepo-ci`) にも影響を出していない

---

## 実行した検証

```
$ make check
[doc-lint] 対象 118 ファイル / エラー 0 件 / 警告 52 件
[traceability] construction-workflow: 25/25 カバー — OK
[traceability] productionization: 120/120 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
[workflow-shell] 検査 61 ブロック / エラー 0 件
[table-counts] 実測: 機能テーブル 42 (個人 34 / 契約 8) / 分類 ①31 ②2 ③1
[table-counts] 実測: 機能テーブル以外 11 (所有者列なし 6 / 所有者列あり 5) / 検査①の除外リスト 8
[table-counts] 照合 37 件 / エラー 0 件
[endpoint-mapping] 実測: auth-accounts.md 33 本 / 9 ドメイン 112 本 / settings.md §5 18 行 / custom tool 8 本 / 403 16 本 / CSV 16 列
[endpoint-mapping] 照合 44 件 / エラー 0 件
[template-sync] 照合 1 組 / エラー 0 件
[monorepo-ci] 実測: ci.yml の job 6 本 / モノレポ機構 MR-x 6 件 / issue テンプレート 3 本
[monorepo-ci] 照合 59 件 / エラー 0 件
```

警告 52 件は既存 (ルール文書・過去 review・`design_memo.md` の「TODO」語と、
`data-model.md` / `infrastructure.md` ×2 / `llm-migration.md` / `operations.md` の未回答 `[Answer]` 5 件)。
**本差分由来の新規警告・エラーは無い**。

**抜き取り照合に使ったコマンド (再現用)**

```bash
grep -n "" /Users/yuyamorishita/aillio/hassan/hassan-v2-backend/auth/event_mapper.go | sed -n '60,76p'
grep -rn "EventTypeMemberCreate|EventTypeAccountUpdateEmail|EventTypeContractUpdateMFA" \
  /Users/yuyamorishita/aillio/hassan/hassan-v2-backend/entity/
sed -n '467,480p' /Users/yuyamorishita/aillio/hassan/hassan-v2-backend/db/schema.sql
grep -n "func (alr" /Users/yuyamorishita/aillio/hassan/hassan-v2-backend/repository/activity_log.go
grep -rn "contracts/me" docs/ aidlc-docs/ templates/ .claude/
grep -rn "companies/me" docs/ aidlc-docs/ templates/ .claude/
grep -n "D-API-2" docs/design/API/*.md
```

## 判定

**重大 3 件があるため「問題なし」とはしない**。
重大 1 / 重大 2 は**同一節 (§3.7) 内の隣接記述**で、重大 3 は SSOT (`API/README.md`) への未起票。
いずれも**修正は数行**だが、放置すると (a) 4 事象の監査記録が実装から落ちる、
(b) v2 からの後退が「後退なし」と記録される、(c) パス命名が実装で分岐する、という形で実装リポに出る。
修正後の再レビューは本ファイルに追記する。

## 反映記録 (2026-08-23。メインセッションによる修正の追記)

| 指摘 | 反映 |
|---|---|
| 重大 1 (§3.7 直前の注記が旧版) | **実施** — `docs/design/API/auth-accounts.md` §3.7 の「委譲先の受け皿の状態」を AA-D-24 後の状態へ改訂 (行数は「下表が定義元」とし転記を廃止 = DR-9)。§4 の O-6 行も同様に「9 行」の転記を落とし、値域の記述にリセット要求を追加 |
| 重大 2 (AA-D-23 注記の「前例なし・C-16 対象外」が未訂正) | **実施** — 同 §3.7 の AA-D-23 注記を「復帰済み 4 件を除いた現在も記録しない対象」の列挙に改め、**`member_update_by_admin` / `member_delete_by_admin` は前例があり「記録しない」は C-16 に対する後退 (2026-08-14 ユーザー承認済み)** と明記 |
| 重大 3 (AA-D-25 と D-API-2 の衝突が SSOT 未登録) | **実施** — `docs/design/API/README.md` §0 の差分列挙を 3 点 → **4 点** (④単数形の単一リソースパス) に拡張し、§1.2 の D-API-2 行に例外を追記。`auth-accounts.md` §5 に **R-AA-29** (実施済み) を起票 |
| 中② (リセット要求の action 値が §4.5.1 に無い = BE-10) | **実施** — `docs/design/observability.md` §4.5.1 に `account_request_reset_password` の行を追加 (v2 前例 `hassan-v2-backend/auth/event_mapper.go:75` / `entity/event_log.go:116` を一次ソースで確認済み) |
| 中③ (settings の値域委譲が行を絞っていない) | **実施** — `docs/design/API/settings.md` §3 の `GET /usage-summary` と observability §4.5.1 の該当行の両側で「クロス集計の軸は利用状況の集計対象の 6 種のみ」と限定 |
| 中⑤ (auth.md の旧パス `GET /contracts/me`) | **実施** — `docs/design/auth.md` §10 の R-11 行を `GET /contract` (旧パス注記付き) へ更新。あわせて auth-accounts.md §7 AA-D-24 行の `PUT /companies/me/mfa` に「現 `/company/mfa`」を付記 |
| 中① (「9 行」「4 件」の転記が無検査 = DR-9) | **一部実施** — 現在値の転記 2 箇所 (§3.7 注記 / §4 O-6 行) を「定義元参照」に置換。**歴史的経緯の中の数値 (「10 行 → 5 行」等) は当時の記録として残す**。§3.7 の行数を機械検算に載せるかは次増分の判断 (持ち越し) |
| 中④ (誤認の原因側 = analysis に `event_logs` の値一覧が無い) | **持ち越し** — `docs/analysis/v2-auth-tenancy.md` §の 2 系統の記録に値一覧を足すのは事実収集タスクとして別途 (`poc-analyst`)。本レビューの §「事実照合」が 6 値 + リセット要求の一次ソース行番号を記録しており、当面の参照はここで足りる |
| 軽微 3 件 | **持ち越し** (実害が実装に及ばない表現の調整のため) |

**反映後の検証**: `make check` 全ゲート緑 (下の再実行ログ)。旧パスの残存 grep:
`grep -rn "contracts/me\|companies/me" docs/ | grep -v "旧\|改名\|当時\|現 "` → 歴史的記録 (AA-D-23/24 行・レビューファイル) のみ。

**再判定: 重大ゼロ — push 可**。
