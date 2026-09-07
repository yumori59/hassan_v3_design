# レビュー: 実装リポ `blocked-by-design` 5 件への設計対応 (2026-08-30)

対象ブランチ: `docs/20260809-implementation-schedule` の**未コミット差分**
(`git status --short` の全ファイル。重点は issue #127 / #37 / #108 / #107 / #144 への対応)

## レビュー結果サマリ

- **重大 1 件 / 中 4 件 / 軽微 4 件**
- **5 件の設計判断そのものは、いずれも参照元 issue の内容と整合しており、却下案・理由・代償が揃っている**
  (`gh issue view` で 5 件の本文を実読して照合)。**指摘はすべて「波及・受信の取りこぼし」型**であり、
  判断の誤りは 0 件

### レビューした設計成果物 (リポジトリ相対パス)

- `docs/design/data-model.md`
- `docs/design/observability.md`
- `docs/design/auth.md`
- `docs/design/API/auth-accounts.md`
- `docs/design/API/settings.md`
- `docs/design/API/README.md`
- `docs/design/infrastructure.md`
- `docs/design/architecture.md`
- `docs/design/operations.md`
- `docs/design/testing.md`
- `docs/design/frontend.md`
- `docs/analysis/v2-feature-inventory.md`
- `aidlc-docs/inception/productionization/requirements.md`
- `aidlc-docs/inception/productionization/plan.md`
- `aidlc-docs/inception/productionization/questions.md`
- `aidlc-docs/aidlc-state.md`
- `aidlc-docs/schedule-2026q3.md`
- `scripts/check-table-counts.sh`
- `templates/app-monorepo/.github/workflows/ci.yml`
- `templates/app-monorepo/backend/STRUCTURE.md`

### 実行した検証

`make check` (全ゲート。1 回のみ実行):

```
[doc-lint] 対象 122 ファイル / エラー 0 件 / 警告 60 件
[traceability] construction-workflow: 25/25 カバー — OK
[traceability] productionization: 125/125 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
[workflow-shell] 検査 61 ブロック / エラー 0 件
[table-counts] 実測: 機能テーブル 44 (個人 35 / 契約 9) / 分類 ①31 ②3 ③1
[table-counts] 実測: 機能テーブル以外 11 (所有者列なし 6 / 所有者列あり 5) / 検査①の除外リスト 8
[table-counts] 照合 37 件 / エラー 0 件
[endpoint-mapping] 実測: auth-accounts.md 46 本 / 9 ドメイン 114 本 / settings.md §5 18 行 / custom tool 8 本 / 403 17 本 / CSV 16 列
[endpoint-mapping] 照合 44 件 / エラー 0 件
[template-sync] 照合 1 組 / エラー 0 件
[monorepo-ci] 実測: ci.yml の job 6 本 / モノレポ機構 MR-x 6 件 / issue テンプレート 3 本
[monorepo-ci] 照合 59 件 / エラー 0 件
```

**警告 60 件は既存**(過去 review・`design_memo.md` の「TODO」語 / 未回答 `[Answer]` 7 件)。
**AC-2.6 の新設は traceability に取り込まれている** (productionization 125/125)。

**DR-9 (件数の転記)**: `event_logs` 追加に伴う 43→44 / 34→35 / 分類② 2→3 は
`check-table-counts` の実測と一致 (`scripts/check-table-counts.sh` の分類② 見出し正規表現も同じ差分で更新済み)。
`check-endpoint-mapping` も緑 (403 = auth-accounts 16 / 総覧 17)。

### 出典の抜き取り照合 (5 件。うち 3 件は結論を左右する事実)

| # | 主張 (出典) | 実測 | 判定 |
|---|---|---|---|
| 1 | **v2 の `CountAdminsByContractID` は `WHERE contract_id = $1 AND auth_role_id = 1` のみ** (`hassan-v2-backend/db/queries/account.sql:80-81`) = AA-D-31 の欠陥根拠 | `-- name:` が :80、`SELECT count(*) FROM accounts WHERE contract_id = $1 AND auth_role_id = 1;` が :81 | **一致** (load-bearing) |
| 2 | **v2 `event_logs.account_id` は `ON DELETE CASCADE`** (`hassan-v2-backend/db/schema.sql:592`〜`:595`) = §3.4.2 分類② の根拠 | `CONSTRAINT fk_accounts_event_logs_account_id … ON DELETE CASCADE` を確認 | **一致** (load-bearing) |
| 3 | **v2 の `PUT /admin/accounts/{name,email,password}` は `AdminAuthRequiredMiddleware` のみでロール判定なし** (`router/router.go:202-204`) = AA-D-33② の根拠 | :202-204 に `CheckSuperAdminRole()` 無し / :206-210 の 5 本には有り | **一致** (load-bearing) |
| 4 | `delete_account.go:47-54` / `update_account_by_admin.go:64` の最後の管理者ガード | :47 `IsAdmin()` / :52-54 `adminCount <= 1` / :64 降格ガード | **一致** |
| 5 | `internal/corsutil/origin.go:10-15` の許可オリジン 4 件 (`:14` = `dev.hassan.jp`) | 一致 | **一致** |

**誤りは 0 件**のため、全数照合への切り替えは行っていない。

### issue 本文との照合 (5 件)

| issue | 設計側の反映 | 判定 |
|---|---|---|
| **#127** (主体を確定できないサインイン失敗) | `observability.md` §4.5.2 に「記録しない (WARN + AL-1)」を**採用案として明記**、却下 (b) を 4 理由で記述。`API/auth-accounts.md` §3.7 の広い文言 (「アカウントが解決できない失敗」) を限定側へ書き換え、SSOT を §4.5.2 に一本化 | **整合。issue が指摘した「2 文書の食い違い」が解消されている** |
| **#37** (信頼プロキシ) | `auth.md` §6.11-3 に対象① の IP 解決行を新設 (ALB 信頼境界 / 却下 (b)(c) / local 空値の意味 / dev・prod で未設定なら起動失敗)。`infrastructure.md` INF-P + §3 の TF `output` 行 + `operations.md` §3.3 分類② | **整合。issue の「gin 既定は全プロキシ信頼」も「採用バージョンで確認してから配線」と前提の確認付きで扱っている** |
| **#108** (ガードの TOCTOU) | AA-D-31 + `API/auth-accounts.md` §3.4 の `LockContractAdminsForGuardInContract` (3 経路共通・`FOR UPDATE`・`ORDER BY id`・除外は数えるときだけ)。却下 (a)〜(e) と代償あり。注記 2 で交差経路 5 通りを列挙、§7.3 の必須ケース 17・18 で固定 | **整合。issue が挙げた 2 経路 (PUT / DELETE) に加えロックも同じ差分に入れており、issue より広く塞いでいる** |
| **#107** (無効化済みへの受諾) | AA-D-32 の 3 点 (ミドルウェア判定 / 受諾を 404 マスク / 招待リンクの同一 tx 削除)。`auth.md` §6.1 変更点 5・§6.13.2 判定 g、`data-model.md` DM-A5 補足 2 の改訂、`AU-T-00006` 新設、§7.3 の必須ケース 19・20 | **整合。issue が挙げた「middleware が `deactivated_at` を見ない」も同時に塞いでいる** |
| **#144** (`event_logs` 新設 + 改名) | DM-15 の改訂 (経緯表 + 改名理由 + 却下)、§4.10 の列・索引、§3.4.2 分類②、`observability.md` §4.5.3、`API/settings.md` D-ST-4 / ST-Q10、AC-2.6 | **決定 1・2 は整合 (決定 2 = (a) を採用)。決定 3 と「やること 2」が受信されていない → 重大 1** |

---

## 重大 (Must Fix)

### 重大 1. issue #144 の**決定 3 (v2 既存データの引き継ぎ) が受信されておらず**、`event_logs.contract_id NOT NULL` と v2 データの既知の衝突がどこにも記録されていない (DR-3 / DR-2 / DR-8 の受信側)

- **箇所**: `docs/design/data-model.md:1326` (§5 の受信欄 R-IMP-1) / 同 `§6.4` (:1140〜。移行の未確定節)
- **事実**: 受信欄は issue #144 の要求を **①改名 ②新設 ③集計元の移行の 3 点**として記録し「実施済み」としているが、
  issue 本文は**決定を 3 つ**求めている。**決定 3** は次の内容である:

  > `data-model.md` §6.4 (既存データ移行) が未確定のまま。引き継ぐ場合、v2 の `event_logs` は
  > `contract_id` を持たないため `accounts` への join が必要で、**退会済みアカウントの行は
  > `contract_id` を埋められない** (`activity_logs` 側と同型の問題)。

  設計側は v2 からの**逸脱 1 として `contract_id NOT NULL` + FK を新設**し (`data-model.md:874`)、
  その理由 (契約単位集計で `accounts` を JOIN しない) は妥当だが、
  **「v2 の既存行にはその値が存在せず、退会済みアカウント分は原理的に埋まらない」という衝突を 1 行も書いていない**。
- **なぜ本番で問題になるか**: §6.4 の**項目 8 は「v3 で新設した一意制約に違反する v2 データを、
  移行の設計時 (切替当日ではない) に検出して規則を決める」**と自ら定めている。
  `NOT NULL` + FK も同じクラスの制約であり、**本件はその表に載るべき既知の衝突**である。
  記録が無いと「Q-1 が『引き継ぐ』で回答された瞬間に、切替当日に初めて破綻が出る」形になる
  (§6.2 の確定事項 3「写像できなかった件数を 0 件になるまで確認する」が最初から満たせない)。
- **修正案** (どちらでも可。**無言のままにしない**ことが要件):
  1. §6.4 の**項目 8 の表に `event_logs` の行を足す** — 「v3 の `contract_id NOT NULL` に対し
     v2 は列を持たない。`accounts` 経由で解決し、**退会済み (v2 で物理削除済み) の `account_id` は解決不能**。
     規則 = 該当行は移送対象外にする / または期間で切る」を書く。検出 SQL も他 3 件と同じ形で置ける。
  2. または **`event_logs` は引き継がない**と本増分で決め切り、§6.4 の**項目 7 (引き継がない場合に何を捨てるかの列挙)** に載せる
     (`GET /usage-summary` の過去分が空になることの告知対象)。
- **併せて**: 同じ受信欄が issue #144 の**「やること 2 = 書き込み API (`POST /event_logs` 相当) + レート制限」**にも触れていない。
  設計側の回答は `API/settings.md` の **ST-Q10 (受け口は本増分で作らない。先送り先あり)** として存在するので**判断は済んでいる**が、
  **受信欄がそれを指していない**ため「取りこぼし」と読める。ST-Q10 へのリンクを受信欄に足し、
  **ST-Q10 側には「受け口を作る増分ではレート制限を同時に入れる」** (issue が「v2 は無制限で野放しだった」と指摘) を
  1 行残すこと。現状 ST-Q10 はレート制限に言及していない。

---

## 中 (Should Fix)

### 中 1. `event_logs` と `activity_logs` を**両方に書く**という決定 (二重書き込み) の根拠が、本増分では成立しない事実に依拠している

- **箇所**: `docs/design/observability.md` §4.5.3 の「重複の規則」3 (:395 付近) と線引き表の「消えるか」行
- **事実**: 根拠は「**2 本は寿命と消え方が違う** — `activity_logs` は消えない、`event_logs` は
  アカウントの物理削除で CASCADE で消える。片方から他方を導出できない」である。
  しかし `data-model.md` §3.4.2 の `event_logs` 行は同じ差分で
  **「本増分では `accounts` を物理削除しない (§3.4.1-3 の DM-Q2 回答) ため、実際には発生しない」**と明記している。
- **なぜ問題か**: 二重書き込みは**実装コストと BE-10 (書き漏れ) のリスクを常時背負う決定**である。
  その唯一の根拠が本増分で空振りする条件だと、**実装リポで「片方に寄せてよいのでは」と再議論が起きる**
  (実際 issue #144 は統合しない理由として**信頼境界・量・保持期間・値域の運用**を挙げており、こちらは本増分でも成立する)。
- **修正案**: 根拠を **DM-20 の保持期間差** (§4.10 が「`event_logs` は `activity_logs` より速く伸びる。
  行数の観測対象に含める」と既に書いている) と**値域の運用が混ざらないこと**に差し替えるか、
  現行根拠に「**本増分では CASCADE は発生しないが、物理削除を再開する増分で効く**」を明記する。

### 中 2. `data-model.md:796` の `GET /usage-summary` の説明が旧設計のまま (DR-8)

- **記述**: 「A-4 の読み取り絞り込みでは『実行者による絞り込み』として使う: **`GET /usage-summary` の
  アカウント別内訳は「そのアカウントが発生させたコスト」**であり…」 — これは `llm_call_records` の節にある。
- **問題**: ①`API/settings.md` §4 の O-3 行は「`GET /usage-summary` は**件数のみ**でコストを含まない」と定めている
  ②本差分で**集計元が `event_logs` に確定した**ため、`GET /usage-summary` は `llm_call_records` を一切読まない。
  実装者がこの行を読むと**利用量サマリを `llm_call_records` に配線しかねない** (テーブルを跨いだ誤配線は A-4 の検査では落ちない)。
- **修正案**: 例示を運用者向けのコスト可視化 (`observability.md` §4.2 / §6.1) に差し替える。
  `GET /usage-summary` を例に使わない。

### 中 3. `AA-D-32②` / `③` の参照番号の取り違え

- **箇所**: `docs/design/API/auth-accounts.md:191` (§2.3 の `DELETE /accounts/{account_id}` 行)
  — 「副作用: 同一トランザクションで当該アカウントの未使用の招待リンクを削除する (**AA-D-32②**。§3.3)」
- **事実**: AA-D-32 の定義 (:482) では **② = `POST /accounts/signup` の 404 マスク**、**③ = 招待リンクの同一 tx 削除**。
  同書 `:659` (§3.3 の図) と `:799` (§3.5) は正しく **③** を指しており、**:191 だけが②**になっている。
- **なぜ問題か**: この行は**エンドポイント表**であり、実装リポが仕様として最初に読む場所である。
  多層防御の 2 段は §7.3 の必須ケース 20 で**独立に固定する**と決めているため、
  番号の取り違えは「どちらの段の実装か」の取り違えに直結する。
- **修正案**: `:191` を **AA-D-32③** に直す。

### 中 4. 無効化 (`DELETE /accounts/{account_id}`) が「実質不可逆な即時遮断」に昇格したのに、監査記録の対象外という判断が据え置かれたままで、両者が結び付いていない (O-6)

- **事実**: AA-D-32 の代償欄は「**無効化が実質的に不可逆な即時遮断になる**」と明記した。
  一方 `§3.7` の記録対象表に `DELETE /accounts/{account_id}` は無く、
  「現在も記録しない対象」の注記は **AA-D-24 (2026-08-14) のスコープ限定**に基づく
  (`member_delete_by_admin` は v2 に前例があるが、オーナー承認のうえ記録しないと決めた)。
- **なぜ問題か**: 判断自体はオーナー承認済みで**変更を求めるものではない**が、
  **承認時点と現在で「失うものの重み」が変わった** — 承認時は「無効化しても最大 7 日/1 日はアクセスできる可逆な状態」だったが、
  いまは「**即座に締め出され、製品内に戻す手段が無い操作**の実行者が追えない」になった。
  §3.7 の「失うもの ②ロック・削除・権限変更という不可逆操作の実行者が追跡できない」は**旧前提の文言のまま**である。
- **修正案**: (a) §3.7 の「失うもの ②」に **AA-D-32 で不可逆性が増したことを 1 行**追記し、
  (b) AA-D-32 の代償欄から §3.7 / AA-Q14 (再開の入口) へ相互リンクを張る。
  **記録対象に戻すかどうかは AA-Q14 のオーナー判断**として明示的に残す (無言で据え置かない)。

---

## 軽微 (Nice to Have)

1. **`templates/app-monorepo/backend/STRUCTURE.md:206`** — `ops` の説明が
   `llm_call_records / activity_logs / レート制限` に改名されたが、**`event_logs` が入っていない**。
   `data-model.md:318` の `ops/*.sql → db/rdb/ops` は 3 テーブルに更新済みなので、雛形だけ 1 件遅れている (DR-8)。
2. **`docs/design/auth.md:1573`** — 実装リポとの対応表の行が「**認証ミドルウェアの判定 a〜f**」のまま。
   同書 §6.13.2 (:1534) が**判定 g** を追加したので `a〜g` に揃える (DR-8)。
3. **#37 の補強**: `SetTrustedProxies` だけでなく **gin の `RemoteIPHeaders` の既定が
   `X-Forwarded-For` + `X-Real-IP` の 2 本**である点に触れておくとよい。ALB は `X-Real-IP` を
   除去しないため、**信頼ヘッダを `X-Forwarded-For` 1 本に絞る**ことを同じ行に書いておくと、
   実装リポで「XFF は塞いだが X-Real-IP は素通り」の実装差が出ない
   (§6.11-3 が既に「採用バージョンの実装で確認してから配線する」と書いているので、その確認項目に足す形で足りる)。
4. **`docs/design/frontend.md:945`** — 「**この画面が無いと製品内に即時遮断手段が存在しない**」は
   AA-D-32 後は不正確 (無効化が即時遮断になった。ただし不可逆)。`auth.md` §6.9 の AA-Q13 受信欄 1 には
   同日の追記が入っているので、**FE 側だけが旧記述**である (DR-8 の受信側)。

---

## 本番観点カバレッジ (本差分が触れる ID)

| ID | 状態 | 箇所 |
|---|---|---|
| **A-1** 認証方式 | **回答あり** | `auth.md` §6.1 の変更点 5 (判定 g) / §6.13.2 / `API/auth-accounts.md` §3.5 (`GetAccountByIDForAuth` の選択列) |
| **A-3** テナント境界 | **回答あり** | `data-model.md` §4.1.1 の 44 件目 (`event_logs` = `contract_id` + `account_id`) / A-3 行を 44・35 へ更新 |
| **A-4** 絞り込みの層 | **回答あり** | `API/auth-accounts.md` §3.5 (`…InContract` 命名で許可リスト非該当) / `API/settings.md` A-4。**ただし `data-model.md:796` の例示が stale = 中 2** |
| **A-5** 401/403/404 | **回答あり** | `AU-T-00006` (401 / 分類 T) の新設と `AU-C-00006` を流用しない理由 (:531) / 受諾拒否は 404 マスク (AA-D-32② の却下 (b)) / ガードは 403 (AA-D-12) |
| **A-6** LLM 越境 | **本差分の対象外** (触れていない。既存の回答が有効) | — |
| **O-2** LLM 計測 | **本差分の対象外** | — |
| **O-3** コスト上限 | **本差分の対象外** (`GET /usage-summary` は件数のみ = C-12 と整合) | `API/settings.md` O-3 |
| **O-4** 失敗の可観測性 | **回答あり** | `observability.md` §4.5.2 の「記録しない代わりに WARN + AL-1」/ 代償欄 (DB 障害中の件数はリクエストログから復元) |
| **O-6** 監査ログ | **回答あり (要補強)** | `observability.md` §4.5 / §4.5.3 / `data-model.md` §4.10 / AC-2.6。**無効化の監査対象外の据え置きが新前提と結び付いていない = 中 4** |
| **O-7** アラート | **回答あり** | AL-1 を #127 の観測経路として指名 |
| **D-4** DB マイグレーション | **回答あり** | `event_logs` の `CHECK` 追加は「新しい値を許す方向 = 非破壊」(§6.2 の後方互換表) と明記 |
| **D-8 / D-1** IaC・環境 | **回答あり** | INF-P (TF `output` → ecspresso → ECS `environment`)。`operations.md` §3.3 分類② に接続 |
| **D-6** Agent 再発行 | **本差分の対象外** | — |
| **DR-3** 既存データ | **未回答 (重大 1)** | `event_logs` の移行が §6.4 に無い |

---

## 良かった点

- **AA-D-31 の設計密度が高い**。却下案 5 つ (DB 宣言的制約 / 楽観的制御 / 運用 SQL / `SERIALIZABLE` / 対象行の除外)
  がすべて**「なぜ直列化されないか」まで踏み込んで**書かれており、特に却下 (e) の
  「互いに素な行集合をロックするため衝突せず、デッドロックとして現れる」は**実装者が必ず踏む罠**を先回りしている。
  注記 2 で交差経路 5 通りを列挙し、§7.3 の必須ケース 17 で `PUT`×`PUT` / `PUT`×`DELETE` / `lock`×… まで
  テストに落としているため、**設計で構造的に潰す**という要求を満たしている。
- **AA-D-32 が「二重に塞ぐと片方の実装漏れが検査に現れない」ことを自覚し、
  §7.3 の必須ケース 19・20 で 2 段を独立に固定している** (BE-10 の裏返しへの対処)。
  「(a) 無効化時のリンク削除を無効にしたビルドでも 404 になる」という書き方は故障注入の指定そのもの。
- **#127 の却下理由③** (「部分的な DB 障害中の失敗が `unauthenticated` の部分インデックスに並び、
  **パスワードスプレーの署名そのものになって検知を狂わせる**」) は、
  可観測性の設計としてレベルが高い。監査台帳を「攻撃検知の入力」として見た帰結を書けている。
- **DM-15 の改訂で「経緯表 (起草時 / 2026-08-26 / 2026-08-29)」を残した**のは良い。
  判断が反転したときに**旧却下理由の前提が失効した**ことを明示しており、
  再度「なぜ 1 本にしないのか」が蒸し返されない形になっている。
- **`check-table-counts.sh` の分類② 見出し正規表現を同じ差分で更新している** (DR-9 の運用どおり)。
  件数が動く変更で**機械照合を先に直す**手順が守られている。
- **`API/settings.md` ST-Q10 が「v2 のパス名 `POST /event_logs` をそのまま使わない (テーブル名を露出させない)」**
  まで書いているのは、先送り項目としては十分な粒度。

---

## 再レビューの要否

- **重大 1 の修正 (§6.4 への `event_logs` の行追加、または「引き継がない」の明示) は必須**。
- 中 1〜4・軽微 1〜4 は同じ差分で直せる範囲。**修正後は差分箇所のみの軽量再レビューで足りる**
  (設計判断そのものの変更を伴わないため)。

## 追記 (2026-08-30。指摘の反映)

同一セッションで全件を修正した。判断そのものは変更していない (波及・受信の記述の補完のみ)。

| 指摘 | 対応 | 反映箇所 |
|---|---|---|
| 重大: 決定 3 (v2 既存データ) が §6.4 の受信欄に無い | `event_logs.contract_id NOT NULL` の行を §6.4 項目 8 の表に追加。v2 `accounts` は物理削除 + `event_logs` への `ON DELETE CASCADE` のため移行時点で孤立行は発生せず、`accounts.contract_id` への join で衝突なく埋まることを明記。R-IMP-1 の受信欄も決定 1/2/3 の粒度に書き直した | `data-model.md` §6.4・§7.9 R-IMP-1 |
| 中: issue の「やること 2 (書き込み受け口 + レート制限)」が受信欄に無い | `API/settings.md` ST-Q10 に、受け口を作る増分では `auth.md` §6.11-3 対象②に含める旨を追記 | `API/settings.md` |
| 中: 二重書き込みの根拠 (§4.5.3 規則 3) が「CASCADE で消える」を理由にしていたが、本増分では発生しない | 理由を issue #144 が挙げた 4 観点 (信頼境界・量・保持期間・値域運用) に差し替え。誤った旧理由は削除 | `observability.md` §4.5 表・§4.5.3 規則 3 |
| 中: `data-model.md:796` が旧設計 (`GET /usage-summary` が `llm_call_records` を読む前提) のまま | 「本テーブルを読まない (集計元は `event_logs` に変更済み)」を明記 | `data-model.md` §4.10 |
| 中: `API/auth-accounts.md:191` の `AA-D-32②` は `③` の誤り | ③に訂正 (他の参照箇所は確認済みで誤りなし) | `API/auth-accounts.md` §2.3.2 |
| 軽微: `STRUCTURE.md` に `event_logs` 未追加 | `ops` ドメイン行に追加 | `templates/app-monorepo/backend/STRUCTURE.md` |
| 軽微: `auth.md:1573` が「判定 a〜f」のまま (g 未反映) | 「判定 a〜g」に更新 | `auth.md` |
| 軽微: `frontend.md:945` の「即時遮断手段が存在しない」が AA-D-32 後は不正確 | 無効化 (不可逆・ロックの代替にならない) を明記する形に修正 | `frontend.md` |
| 軽微: gin の `RemoteIPHeaders` 既定への言及が無い | `X-Forwarded-For` 以外を追加しない前提を明記 | `auth.md` §6.11-3 |

### 検証結果 (`make check`)

```
[doc-lint] 対象 123 ファイル / エラー 0 件 / 警告 61 件 (既存の TODO 語・未回答 [Answer] のみ)
[traceability] construction-workflow 25/25・productionization 125/125 — OK
[workflow-shell] 検査 61 ブロック / エラー 0 件
[table-counts] 照合 37 件 / エラー 0 件
[endpoint-mapping] 照合 44 件 / エラー 0 件
[template-sync] 照合 1 組 / エラー 0 件
[monorepo-ci] 照合 59 件 / エラー 0 件
```

**再レビュー完了**。重大 0 件。
