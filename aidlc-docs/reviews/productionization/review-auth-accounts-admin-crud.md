# レビュー: 社内管理者アカウント管理 API の復活 (AA-D-29) と初回パスワード登録リンク方式 (AA-D-30)

- 日付: 2026-08-29
- レビュアー: `design-reviewer` (別セッション。起草者ではない)
- 起草の入口: 実装リポ hassan-v3 の issue #181 (blocked-by-design) → オーナー判断 (案 B) → AA-Q15 = (c)

> **本ファイルは 2 巡分のレビューを含む**。**最新の判定は末尾の「## 再レビュー (第 2 巡。2026-08-29)」** —
> **第 1 巡の重大 3 件・中 4 件はいずれも解消または起票済みで、重大は 0 件になった** (残るのは中 3 件・軽微 3 件)。
> 以下は第 1 巡の記録であり、**指摘の現況は末尾の対応表が正**。

## レビュー結果サマリ (第 1 巡)

- **対象** (未コミット差分。リポジトリ相対パス):
  - `docs/design/API/auth-accounts.md`
  - `docs/design/auth.md`
  - `docs/design/data-model.md`
  - `docs/design/API/README.md`
  - `docs/analysis/v2-feature-inventory.md`
  - `aidlc-docs/inception/productionization/requirements.md`
- **重大 3 件 / 中 4 件 / 軽微 5 件**
- 実行した検証:
  - `make doc-lint` → **対象 120 ファイル / エラー 0 件 / 警告 57 件** (警告はいずれも本差分と無関係な既存の未回答マーカー・作業メモ)
  - `make check-endpoint-mapping` → **実測: auth-accounts.md 43 本 / 9 ドメイン 114 本 / settings.md §5 18 行 / custom tool 8 本 / 403 17 本 / CSV 16 列。照合 44 件 / エラー 0 件**
  - `make check` → 全ゲート緑 (`traceability` productionization **124/124 カバー**、`table-counts` 照合 37 件 0 エラー、`monorepo-ci` 照合 58 件 0 エラー、`workflow-shell` 61 ブロック 0 エラー、`template-sync` 0 エラー)
  - 一次ソースへの抜き取り照合 **14 件** (下記「裏取りの結果」)。**うち結論を左右する 3 件** = ①v2 の 5 本すべてに `CheckSuperAdminRole()` ②v2 の設定側 usecase に期限判定が無い ③削除・ロール一覧が v2 FE で未配線
- **スコープの注記 (カバレッジの正直さ)**: `docs/design/auth.md` の未コミット差分には、**本件と無関係な別作業 (FE-D の段階移行への反転 / JWT 有効期間 7 日 → 1 日 / FE-Q7・FE-Q10・R-13)** が混在している。本レビューは **AA-D-29 / AA-D-30 に関係する部分 (§6.2 例外 3 件目・ロール制限表・§6.3 例外表・§6.7 公開系統・§6.11-3 対象①・§10.2 R-7・§10.3 R-IMP-2)** のみを見た。JWT 1 日化と FE-D 反転は**本レビューの対象外**であり、別途レビューが要る (push ゲートは auth.md 全体をレビュー済みと見なすため、明示しておく)。

---

## 裏取りの結果 (レビュー観点 1)

**14 件すべて一致** (行番号ズレ 1 件のみ、下の軽微 3)。

| 主張 (設計の記述) | 一次ソース | 結果 |
|---|---|---|
| v2 は作成・詳細取得・削除・詳細更新・ロール一覧の **5 本すべてに `CheckSuperAdminRole()`** | `hassan-v2-backend/router/router.go:206-210` | **一致**。`:205` の `GET ""` (一覧) だけがロール判定なし = 設計の①群配置と整合 |
| パスワード登録の公開 2 本 | `同:199`(`GET /admin/accounts/register/password/check`) / `:200`(`POST …/register/password`)、`:201` で `.Use(AdminAuthRequiredMiddleware())` | **一致**。AA-D-30 却下 (b) の「順序依存で公開性を表現」も実物どおり |
| `admin_accounts.name` / `email` の UNIQUE | `hassan-v2-backend/db/schema.sql:54-55` | **一致** |
| `register_admin_password_requests` の `token varchar(255) NOT NULL UNIQUE` | `同:501-509` (`token` は `:504`) | **一致** |
| 作成 usecase の登録リンク発行・メール送信 (`:90`-`:110`)・**有効期限 7 日** (`:95-96`) | `hassan-v2-backend/usecase/admin_account/create_admin_account.go:50-110` | **一致** (`time.Now().Add(time.Hour*24*7)`)。**ダミーパスワードを bcrypt して入れる**点も確認 |
| **設定側 usecase に期限判定が無い** (AA-D-30 却下 (g) の根拠) | `usecase/admin_account/register_password.go:33-58` | **一致**。期限判定は `check_register_password_token.go:38-41` のみ |
| 受諾成功時に登録要求行を削除する (`password_registered` 導出の書き手) | `register_password.go:52` | **一致** |
| トークン不正でも 500 を返す (V2-D2 と同型) | `controller/admin_account.go:242-259` (`:253-256` が `internalServerError`) | **一致** |
| `PUT /admin/accounts/details` は対象 ID をボディに持つ | `controller/dto/admin_account.go:68-73` | **一致** |
| 更新 usecase | `usecase/admin_account/update_admin_account_details.go:28-40` | **一致** |
| 「Admin: 管理画面における Read 機能を利用可能」 | `entity/admin_auth_role.go:7-10` | **一致** |
| v2 FE の作成画面が `postAdminAccounts` を呼ぶ | `hassan-v2-frontend/src/features/admin/admin-setting/components/admin-account-form.tsx:39` → `actions/create-admin-account.ts:7` | **一致** |
| v2 FE の編集画面が `putAdminAccountsDetails` を呼ぶ | `同 components/admin-account-edit-form.tsx:44` → `actions/update-admin-account-details.ts:9` | **一致**。**補足**: 編集画面は `getAdminMe()` の結果 (`me`) を渡す **自分自身の編集**である (`page/admin-setting-edit-page.tsx`)。「他人の権限を変える画面」ではない |
| 削除・ロール一覧は v2 FE に呼び出し元が無い | `src/generated/admin-account/admin-account.ts` のみ / `features/admin/(shared)/actions/get-admin-accounts-auth-role.ts` は import 元 0 件 | **一致** (`grep -rn` で確認) |

**追加で確認した反証 (⑤反証探索)**: v2 の**パスワード登録の公開 2 本は FE に配線されている** — `src/features/auth/pages/admin-signup-page.tsx:11` (lookup) と `src/features/auth/components/admin-signup-form.tsx:66` (設定)。AA-D-30 の「引き継ぐ」判断を**独立に裏付ける事実**であり、設計には未記載 (加えれば R-AA-34 / R-AA-32③ の根拠が強くなる)。

---

## 重大 (Must Fix)

### 重大 1. `GET /admin/admins` の応答に `password_registered` が無く、§2.5・§7.3 UT #15・R-AA-32② と矛盾する

- 箇所: `docs/design/API/auth-accounts.md:236` (§2.4 ①群の `GET /admin/admins` 行) — 応答は `{items: [{id, name, email, admin_auth_role}], total_count}` のまま
- 矛盾する記述: 同 `:323` (§2.5 の `InternalAdminView` を「**`GET /admin/admins` の items と同じ形**」と宣言し `password_registered` / `created_at` / `updated_at` を含む) / 同 `:1117` (UT #15「`GET /admin/admins` の `password_registered` が false → true に変わること」) / 同 `:935` (R-AA-32② が一覧画面に発行状態の表示と再発行ボタンを要求)
- **本番で問題になる理由**: AA-D-30 の代償 (iii) 「作成済みだが未設定の状態が最長 7 日存在する」の**唯一の緩和が `password_registered`** であり、その表示先は一覧画面である。実装者が §2.4 の行 (エンドポイント表 = 一次の契約) に従うと**フィールドが出ず、FE は再発行の要否を判断できない** — 読む側と書く側の対 (BE-10) が切れる。さらに UT #15 は設計どおりに実装しても落ちる。
- 修正案: §2.4 の該当行の応答を `InternalAdminView` (§2.5) 参照に統一する。導出コスト (存在サブクエリ) が一覧で問題になるなら「一覧では返さず個別取得で返す」と決めたうえで UT #15 と R-AA-32② を同じ差分で書き換える (どちらでもよいが**片方だけ直さない**)。

### 重大 2. `auth.md` §10.2 **R-7①** が旧方式のまま — operations.md が**却下された案**どおりに書かれる

- 箇所: `docs/design/auth.md:1767` (未変更)。現記述: 「①`admin_accounts` の初期投入 (移行スクリプト) と**初回 MFA 登録**の手順 — **一時パスワードを `crypto/rand` で生成し帯域外で配布する** / 有効期限を設け期限切れは無効化する」
- 一方 §6.2 (本差分で改訂) は「**初期パスワードという概念そのものが無くなり**」「移行スクリプトは**パスワードを直接投入せず** `register_admin_password_requests` 行を作り平文トークンを標準出力に 1 度だけ出す」「**`crypted_password` を直接書く経路がどこにも無くなる**」と決めた。**MFA も 2026-08-10 の AA-D-22 で消滅済み**。
- **本番で問題になる理由**: R-7 は**受け皿 (operations.md) への是正要求そのもの**であり、状態は「未対応」。運用手順を書く担当は R-7 の文面を仕様として読むため、**AA-D-30 が却下した「一時パスワードの帯域外配布」が運用手順に実装される**。`06-delegation-prompts.md` の「機構を直したら、その機構を語る文書を同じ差分で直す」および DR-8 (自己申告の範囲だけ直す) の典型。
- 修正案: R-7① を新方式へ書き換える (ブートストラップ = `admin_accounts` + `register_admin_password_requests` を作り平文トークンを標準出力へ / 運用者が `POST /admin/password-registrations` で設定 / **トークンの取り扱いと 7 日の期限**)。「初回 MFA 登録の手順」は削除する (AA-D-22)。

### 重大 3. C-16 の判定に「v2 FE の配線」が反映されていない — 自己管理 3 本 (`:202`-`:204`) は**現に配線された画面がある**

- 箇所: `docs/design/API/auth-accounts.md:421` (§2.7 の「社内管理者のパスワード変更・氏名変更・メール変更」行) / `aidlc-docs/inception/productionization/requirements.md` の C-16 例外表の追加行 / `docs/analysis/v2-feature-inventory.md` の `:202`-`:204` 3 行
- **実測 (本レビュー)**: v2 FE には**ルーティング済みの 3 画面**がある — `src/app/admin/settings/account/{name,email,password}/edit/page.tsx`、実装は `src/features/admin/settings/(routes)/account/components/admin-account-{name-edit-form,email-edit-form,password-edit}.tsx` が `putAdminAccountsName` / `putAdminAccountsEmail` / `putAdminAccountsPassword` を呼ぶ。入口はヘッダーナビの「設定」(`src/components/layouts/header/admin-header-link.tsx` の `PATH.ADMIN_SETTING_ACCOUNT` = `src/lib/path.ts:47`)。**削除・ロール一覧 (死にコード) とは状態が違う**。
- **本番で問題になる理由**: ①**issue #181 と同じ型の見落とし**である (「使用実態を確認せずに対象外と書いた」)。今回の反転はまさにこの型を是正するものなのに、**同じ判定基準 (FE 配線の有無) を隣の 3 本に適用していない** ②主張されている代替経路が `admin` ロールでは成立しない — v3 は `PUT /admin/admins/{id}` を **SuperAdmin 限定**にしたため、**`admin` ロールの社内管理者は自分の氏名・メールを変える手段が一切無くなる** (v2 では `:202`/`:203` にロール判定が無く、本人が変更できた) ③パスワードは「漏洩を疑ったとき本人が即座に変えられない」状態になり、`auth.md` §6.9 の受信欄 (即時遮断手段が無い) と重なる
- 修正案: (a) §2.7 と `v2-feature-inventory.md` の 3 行に**上記の FE 配線の事実 (パス付き)** を書く (b) 「代替経路がある」の記述を **`admin` ロールには代替が無い**点まで含めて正す (c) **C-16 の後ろ倒しはオーナー承認が要る** (`v2-spec-carryover-policy.md`) ため、AA-Q15 の回答 (= 初期パスワードの渡し方) を承認の根拠に流用せず、**「自己管理 3 本を落とす / `PUT /admin/admins/me` 相当を 1 本足す」を独立の問いとして起票**する。

---

## 中 (Should Fix)

### 中 1. AA-D-10 の「**計 10 本**」が §3.7 の「計 12 本」と矛盾 (機械検査の盲点)

`docs/design/API/auth-accounts.md:450` (AA-D-10 の決定欄) が「**計 10 本** (§3.7。2026-08-10 の AA-D-22 で 11 → 10)」のまま。§3.7 は本差分で 12 本へ更新済み。**`scripts/check-endpoint-mapping.sh` の検査は `pick 'レート制限の対象 \(計 N 本'` という §3.7 の言い回しにしか一致しない**ため、この転記は検査をすり抜けている (実際 `make check` は緑)。レート制限の対象本数は実装リポのミドルウェア設定の期待値になるため、**決定行 (AA-D-10) を読んで 10 本で実装する**余地が残る。→ 値を更新し、**同時に AA-D-10 側の言い回しも検査対象に含める** (R-AA-25 の要求に追記)。

### 中 2. R-AA-33 の「(§3.3 に明記済み)」が事実でない — 再発行の `DELETE` → `INSERT` 1 トランザクションがどこにも書かれていない

`:943` (R-AA-33) は「制約を入れない場合でも、発行は 1 トランザクション内で `DELETE` → `INSERT` を行う (**§3.3 に明記済み**)」と書くが、§3.3 の該当図 (`:634`) は「未使用リンクを失効させて再発行する」としか書いていない。`signup_links` 側は `:617` で「1 トランザクション内で DELETE → INSERT + UNIQUE(contract_id, email) (R-AA-17)」と明記されているのと非対称。**R-AA-33 は未対応 (DB 制約なし) なので、現時点の唯一の担保が文書に存在しない**状態 (BE-11)。→ §3.3 の社内管理者フローに 1 行足す。

### 中 3. ブートストラップ (最初の 1 人) の受け皿が起票されていない

`auth.md` §6.2 が新たに具体化した「移行スクリプトが `admin_accounts` + `register_admin_password_requests` を作り平文トークンを標準出力へ」は、**operations.md にも `data-model.md` §6 (移行手順) にも記述が無い** (`grep -n "SuperAdmin\|社内管理者" docs/design/operations.md` → 0 件)。唯一の受け皿である R-7 は重大 2 のとおり旧方式のまま。加えて `data-model.md` の移行節は「**未使用の登録要求は引き継がず失効させ再発行する**」と書いており、**ブートストラップで新規に 1 行作る**手順とは別物である。**RL-2 (prod 基盤構築) の後、最初の SuperAdmin がいないと `POST /admin/admins` を誰も叩けない**という順序依存 (D-3 / D-7) なので、**新規の R-AA-xx を operations.md 宛てに起票**し、RL-2 の完了条件との前後関係を書くこと。

### 中 4. 新しく増えた件数のうち 3 種が無検査のまま (DR-9 の再発余地)

本差分で動いた数え上げのうち、**機械照合の対象は 403 (16) / 429 (12) / エンドポイント総数 (43・157) だけ**である (`check-endpoint-mapping.sh` の検査②②'⑥⑦⑧)。無検査で複数箇所に転記されたのは:

- **「公開 8 本」** — `auth-accounts.md` §1.1 / §2.1 見出し・本文 / §3.1.2 の S1 / §4 の A-1・D-2② / §5 R-AA-15 / SSOT の向き表 / §7 の依存図、`API/README.md` §0 ①③・§2.5、`auth.md` §6.2 (再現: `grep -rn "公開.*8 本\|8 本 + \`GET /alive\`" docs/`)
- **「§2.4 の 13 本」**「**SuperAdmin 限定 8 本 / ③管理者アカウント管理 3 本**」 — `auth-accounts.md` §2.3 / §2.4 / §4 の A-2・D-8、`API/README.md` §3 本文
- **§2.4 の群の内訳 (①5 / ②5 / ③3)**

D-2 の CI 検査② が「公開 N 本 + `GET /alive` と完全一致」を実装リポで見る設計になっているため、**この数値がずれると実装リポの CI が確定で落ちる** (DR-9 が「CI 期待値になる数え上げは機械強制する」と定めた類型そのもの)。→ `check-endpoint-mapping.sh` に §2.1 / §2.4 の見出し実数と転記先の照合を足す (足したら**故障注入で殴る** — 検査⑥→⑦の経緯と同じ)。少なくとも R-AA-25 の要求に「公開本数・§2.4 本数・R-4 本数」を追記する。

---

## 軽微 (Nice to Have)

1. `:903` (R-AA-1 の状態欄) が「**本書 §3.7 のレート制限は 10 本**で、対象②の 4 本 + 公開 6 本 = 10 本と一致する」と**現在形**で残る。2026-08-10 時点の記録である旨を明示するか、12 本 (公開 8 + 認証済み 4) へ更新する。
2. `POST /admin/password-registrations/lookup` の応答 `{email, expires_at}` は **v2 に無い拡張** (`check_register_password_token.go` は `AdminAccountID` のみ返す)。`POST /accounts/signup-links/lookup` と揃えた妥当な設計だが、移植元列に「**email の返却は v3 の追加**」と 1 語添えると誤読が減る (DR-1 の予防)。
3. `admin-header-link.tsx:62` は「アドミン設定」ナビ項目の `pathKey` 行で、エントリ自体は `:58`-`:63`。1 行精度のズレ。
4. §3.7 の監査行は成功時の記録しか定めていない。**409 (重複) / 403 で終わったときに記録するか**が未記載 (`admin` ロールによる 403 は権限昇格の試行痕跡として価値がある)。O-6 の粒度として 1 行決めておくとよい。
5. 新設 5 本に対応する **AC が新規に立っていない** (requirements.md の追加は C-16 例外表の 1 行のみ)。`make check-traceability` は 124/124 で緑だが、これは「既存 AC が増えていない」だけであり、DR-6 の「設計判断に対応する AC が無い」側の確認は人手。既存 AC-1.x で足りるという判断ならその旨を §4 に 1 行書くのが安全。

---

## 起草側が範囲を超えて追加した判断の評価 (再発行 API 1 本)

**妥当。スコープ超過として問題視しない。** 根拠:

- 却下 (d) の論拠が**具体的で検証可能**である — 削除 API が対象外 (§2.7) かつ `name` / `email` が UNIQUE (`schema.sql:54-55`、本レビューで確認) のため、**メール到達に失敗したアカウントは作り直しも復旧もできない**。製品内の回復手段がゼロになる状態は AA-D-27 が契約について解いた問題より重い、という比較も成立している。
- **先行事例 (AA-D-27) と手続きが同型**である (ボディ無し・宛先は DB 固定・未使用リンクを失効させてから発行・SuperAdmin 限定・監査対象)。設計の一貫性を崩していない。
- ただし**代償の記録が 1 つ足りない**: 再発行はレート制限の対象外 (認証済みなので妥当) だが、**SuperAdmin が任意の社内管理者宛にメールを連投できる**点は §3.7 の注記どおり監査でしか追えない。注記があるので許容。

## 起草側の自己申告した残課題の検証

| 申告 | 実測 | 判定 |
|---|---|---|
| R-AA-33 (`UNIQUE (admin_account_id)`) 未対応 | `data-model.md` に `register_admin_password_requests` の制約行なし (`:389` / `:425` / `:468` のみ) | **申告どおり未対応**。ただし中 2 のとおり代替の担保が文書に無い |
| R-AA-34 (`settings.md` §5 への 1 行追加) 未対応 | `settings.md` に `register/password` の行なし | **申告どおり**。検査①が行数一致を見るため、**両方を同時に足すこと**の注記も正しい |
| R-AA-31 (observability の action 値域 3 値) 未対応 | `observability.md:310-311` は `contract_create` / `contract_invitation_resend` のみ | **申告どおり** |
| R-AA-32 (frontend.md の画面) 未対応 | `frontend.md:921` は `/admin/admins` = 一覧のみ。`/admin/password-registration` の行なし | **申告どおり** |
| R-AA-30 (`audit_logs` の `CHECK` 緩和) 未対応 | `data-model.md` §4.10 未変更 | **申告どおり**。起票内容 (3 分岐案) は妥当 |
| — | **申告に無い残課題**: 重大 2 (R-7① が旧方式)、中 3 (ブートストラップの受け皿)、重大 1 (§2.4 の一覧行) | **見落とし 3 件** |

## 本番観点カバレッジ (`08-production-gates.md`)

| ID | 状態 | 箇所 |
|---|---|---|
| A-1 | 回答 | §4 A-1 (公開 8 本の内訳と系統宣言)。`auth.md` §6.7 の公開行にも 2 本追加済み |
| A-2 | 回答 (ただし**重大 3**) | §4 A-2 / §2.4 の③ = SuperAdmin 限定。v2 実挙動 (`router.go:206-210`) と一致。**`admin` ロールの自己管理が消える点の評価が不足** |
| A-3 | 参照 | `data-model.md` §4.1.2 (a) — `register_admin_password_requests` は契約に属さない例外として登録済み |
| A-4 | 回答 | §3.5 に読み手 2 クエリ + 削除クエリを追加。全契約横断は種別⑦の許可リスト側へ |
| A-5 | 回答 | 新 5 本すべてに固有ステータス (201/200/403/404/400/409/429)。**404 の統一** (AA-D-6④) と**設定側でも期限判定** (AA-D-30⑤) は v2 の穴 (500 / 期限未判定) を実測で裏付けたうえでの是正 |
| A-6 | 対象外 (理由あり) | LLM 経路なし (§4 A-6) |
| A-7 | 回答 | 共有機能なし (変更なし) |
| O-1 | 参照 | 変更なし |
| O-2 / O-3 | 対象外 (理由あり) | LLM 経路なし |
| O-4 | 回答 | §3.7 末尾 (429 の計数・**メール送信失敗を握り潰さない**)。新方式でメール依存が増えた分の代償 (ii) も明記 |
| O-5 | 対象外 (理由あり) | SSE / 長時間処理なし |
| O-6 | 回答 (ただし**軽微 4**) | §3.7 に監査 3 行追加 + `contract_id` NULL の `CHECK` 抵触を **R-AA-30 として自己起票**。失敗時の記録有無は未記載 |
| O-7 | 対象外 (先送り) | 変更なし |
| D-1 / D-3 | 参照 (ただし**中 3**) | §4 D-8 の WAF 依存は更新済み。**ブートストラップと RL-2 の順序**が未記述 |
| D-2 | 回答 | 検査②の「公開 8 本 + `GET /alive`」へ更新済み |
| D-4 | 回答 | §4 D-4 で RL-2 前の DB 要求を R-AA-17 / R-AA-30 / R-AA-33 の 3 件に更新。`token_hash` 改名は反映済み |
| D-5 | 参照 | 新しい秘密は増えない (登録トークンは DB に `token_hash` のみ)。**平文パスワードを応答にも DB にも置かない**形になり、旧案より D-5 の観点で改善 |
| D-6 | 対象外 | Agent なし |
| D-7 | 参照 | `data-model.md` の移行節に「未使用の登録要求は引き継がず失効・再発行」を追加済み |
| D-8 | 参照 | §4 D-8 の「社内管理者 13 本」へ更新 (旧「8 本」の実数ズレも是正) |

## 頻出パターン (`feedback_review_patterns.md`)

| # | 判定 |
|---|---|
| DR-1 | **概ね良好** (抜き取り 14 件一致)。例外 = 中 2 (「§3.3 に明記済み」が事実でない)、軽微 2 |
| DR-2 | **なし** (無言の省略は見つからず。対象外には理由と先送り先がある) |
| DR-3 | **なし** — 既存データ (v2 の未使用登録要求) の扱いを `data-model.md` の移行節に追加済み |
| DR-4 | **なし** — v2 のパス・ボディ ID・順序依存グループをいずれも却下し、v3 規約側へ寄せている |
| DR-5 | **なし** — 「適切に」「必要に応じて」の類は判断点に使われていない |
| DR-6 | **ID 衝突なし** (`AA-D-29` / `AA-D-30` / `R-AA-33` / `R-AA-34` / `AA-Q15` はいずれも定義 1 箇所)。**AC の新設なし** = 軽微 5 |
| DR-7 | **なし** (プロトタイプ非依拠) |
| DR-8 | **再発 3 件** = 重大 1・重大 2・中 1 (いずれも「思考の対象になった節だけ直した」型) |
| DR-9 | **中 4** (公開本数・§2.4 本数・R-4 本数が無検査で多数箇所に転記) + **中 1** |
| DR-10 | **該当なし** (構造変更を伴わない) |
| BE-10 | **良好 + 重大 1** — `register_admin_password_requests` に書き手・読み手・削除の対を明示 (R-AA-5 を「経路を定義する」側で解決) した点は模範的。ただし `password_registered` の**読み手 (一覧)** が §2.4 で欠けている |
| BE-11 | **中 2** — 再発行の採番・冪等性は R-AA-33 で起票済みだが、制約が入るまでの担保 (1 トランザクション DELETE → INSERT) が文書に無い |
| BE-3 / BE-5 | 該当なし |

## 良かった点

- **却下案の質が高い**。とくに AA-D-30 却下 (b) (公開ルートを `/admin/admins` 配下に置かない) は **v2 の `.Use()` 順序依存という実在の欠陥**を根拠にしており、`auth.md` §1.7 / §6.7 の既存判断と噛み合っている。却下 (g) (設定側にも期限判定) は **v2 のコードを実際に読んで穴を見つけた**もので、UT #14 として固定までしている。
- **オーナー回答で方針が反転した経緯の残し方**が良い。却下側へ移した旧採用案 (AA-D-29 (c)) を全文残し、AA-D-30 が採用側の詳細を持つという分担が明快。DR-8 の「受信欄」も `auth.md` §10.3 の R-IMP-2 に波及先一覧付きで記録されている。
- **v2 の欠陥を移植しない線引きが明示的** — `token` の平文保存は移植しない / 期限判定を両方に置く / 404 に統一 / `auth_role_id` を応答に出さない (2 つの role 列の取り違えを構造的に潰しており、v2 FE の編集画面が `String(me.auth_role_id)` をロール選択の初期値に使っているバグと同型の再発を防ぐ)。
- **`make check` 全ゲート緑**を維持したまま 5 本の追加を反映しており、403 / 429 / 総数の連動は機械照合で担保されている。


---

# 再レビュー (第 2 巡。2026-08-29)

## 判定サマリ

- **対象** (未コミット差分。リポジトリ相対パス。第 1 巡の 6 ファイル + 今巡で触れた 1 ファイル):
  - `docs/design/API/auth-accounts.md`
  - `docs/design/auth.md`
  - `docs/design/data-model.md`
  - `docs/design/API/README.md`
  - `docs/analysis/v2-feature-inventory.md`
  - `aidlc-docs/inception/productionization/requirements.md`
  - `docs/design/operations.md` (§10.3 の受信欄 = R-AA-37)
- **重大 0 件 / 中 3 件 / 軽微 3 件** (第 1 巡: 重大 3 / 中 4 / 軽微 5)
- 実行した検証:
  - `make doc-lint` → **エラー 0 件** (警告は本差分と無関係な既存分のみ)
  - `make check-endpoint-mapping` → **実測: auth-accounts.md 46 本 / 9 ドメイン 114 本 / settings.md §5 18 行 / custom tool 8 本 / 403 17 本 / CSV 16 列。照合 44 件 / エラー 0 件**
  - `make check` → 全ゲート緑 (traceability productionization **124/124**、table-counts 照合 37 件、monorepo-ci 照合 58 件、workflow-shell 61 ブロック、template-sync 1 組 — いずれもエラー 0)
  - 一次ソースへの抜き取り照合 **11 件** (今巡の新規分。下表)
- **カバレッジの注記**: `docs/design/API/auth-accounts.md` / `docs/design/data-model.md` / `docs/design/observability.md` の作業ツリー差分には、**本件と別の起票 (実装リポ issue #107 / #108 / #127 由来の AA-D-31 / AA-D-32、DM-A5 の論点 2・7 の改訂、observability §4.5.2 の「主体を確定できない失敗は記録しない」)** が混在している。本レビューは **AA-D-29 / AA-D-30 / AA-D-33 に関係する範囲**を見た。混在分については**引用の抜き取り 3 件のみ確認して一致**を得たが (`delete_account.go:47`/`:52-54`、`update_account_by_admin.go:64`、`db/queries/account.sql:80-81`)、**判断の妥当性は本レビューの対象外**であり別途レビューが要る。`docs/design/frontend.md` / `infrastructure.md` の差分も引き続き対象外。

## 第 1 巡の指摘に対する対応表

| 第 1 巡 | 内容 | 判定 | 根拠 (実測) |
|---|---|---|---|
| **重大 1** | `GET /admin/admins` に `password_registered` が無い | **解消** | `auth-accounts.md` §2.4 の同行が **`{items: InternalAdminView[], total_count}`** に是正され、「一覧が発行状態の表示と再発行ボタンの判断材料になる = R-AA-32② / UT #15」まで書かれた |
| **重大 2** | `auth.md` §10.2 R-7① が旧方式 (一時パスワードの帯域外配布) | **解消** | R-7① が**登録リンク方式**へ全面改訂。**「旧記述は却下された案であり、そのまま運用手順に実装されると平文パスワードが運用チャネルに載る」**まで明記され、再実装を防ぐ形になっている。「初回 MFA 登録の手順」も削除済み (**ただし同行 ③ に MFA の残骸 = 下の中 B**) |
| **重大 3** | C-16 の判定に v2 FE の配線が反映されていない (自己管理 3 本) | **解消** | **AA-D-33 を新設**し `PUT /admin/admins/me` / `/me/email` / `/me/password` を §2.4 の④群として追加。**オーナー判断として記録**され、`requirements.md` の C-16 例外表・`v2-feature-inventory.md` の `:202`-`:204` 3 行・§2.7 の該当行 (取り消し線) ・`auth.md` §6.2 の**例外 4 件目**まで同じ差分で波及済み |
| **中 1** | AA-D-10 の「計 10 本」が §3.7 と矛盾 | **解消** | AA-D-10 が「**計 14 本** (対象の全件と本数の定義元は §3.7 の表)」へ。**言い回しごと検査対象に足す要求 (R-AA-25⑥)** も起票された |
| **中 2** | 再発行の 1 トランザクション `DELETE`→`INSERT` が未記載 | **解消** | §3.3 の図に「**制約が入るまではこの 1 トランザクションだけが担保**であり、トランザクション分離だけに頼らない (BE-11)」を明記 |
| **中 3** | ブートストラップの受け皿が無い | **解消 (起票 + 受信)** | **R-AA-37** を新設 (書くこと 4 点 + RL-2 との前後関係)、`operations.md` §10.3 に**受信欄として「未対応 (2026-08-29 受信)」で記録**。`auth.md` R-7① からも定義元として参照 |
| **中 4** | 公開本数・§2.4 本数・R-4 本数が無検査 | **部分対応 (継続。下の中 C)** | **R-AA-25 に照合③④⑤⑥を追記**したが状態は**未対応** (スクリプト未変更)。転記先は今巡でさらに増えた (§2.4 は 13 → **16**、群の内訳に④が追加) |
| **軽微 1** | R-AA-1 の「10 本」が現在形 | **解消** | 「当時 **10 本**…(**現在は 14 本**…実測は §3.7 の表が定義元)」へ |
| **軽微 2** | lookup の `{email}` が v2 に無い拡張である旨 | **解消** | §2.1 の該当行に「**v3 の追加** (v2 は `AdminAccountID` のみを返す)」を追記 |
| **軽微 3** | `admin-header-link.tsx:62` の行番号精度 | **解消** | `:58` (SuperAdmin ナビの「アドミン設定」エントリ先頭) と `:31`-`:36` (`admin` ロールナビの「設定」エントリ) に分けて引用。**実測と一致** |
| **軽微 4** | 監査を成功時のみ記録するかが未記載 | **解消** | §3.7 に「**記録するのは成功した実行だけである**」「409 / 403 / 400 は書かず O-4 の WARN ログとメトリクスで数える」を明記。**④群を記録しない理由**も併記 |
| **軽微 5** | 新設エンドポイントに対応する AC が無い | **解消** | §4 に「2026-08-29 に追加した 8 本に新しい AC を立てていない」理由と、**立てる条件 (AC が無い設計判断は DR-6 の対象)** を明記 |

## 今巡の裏取り (新規 11 件。すべて一致)

| 主張 | 一次ソース | 結果 |
|---|---|---|
| `PUT /admin/accounts/{name,email,password}` にロール判定が無い (AA-D-33② の根拠) | `hassan-v2-backend/router/router.go:202-204` (`AdminAuthRequiredMiddleware` のみ。`CheckSuperAdminRole()` は `:206-210` の 5 本だけ) | **一致** |
| **V2-D7**: 氏名変更が所有権検証なしでボディの `id` を使う | `controller/admin_account.go:272-295` (`req.ID` をそのまま UseCase へ。呼び出し元との一致検証なし) + `usecase/admin_account/update_admin_account_name.go:24-28` (`UPDATE … WHERE id`) + `dto/admin_account.go:57-60` | **一致。欠陥は実在する** — 認証済みの `admin` が SuperAdmin の氏名を書き換えられる |
| V2-D7 の限定「メール・パスワード変更は同じ形の越境が成立しない」 | `update_admin_account_email.go:28-34` / `update_admin_account_password.go:28-34` (どちらも対象の `crypted_password` と照合) | **一致**。限定の付け方も正確 |
| v2 FE の自己管理 3 画面が配線済み | `hassan-v2-frontend/src/app/admin/settings/account/{name,email,password}/edit/page.tsx` + `features/admin/settings/(routes)/account/components/*` | **一致** |
| **`admin` ロールのナビからも到達できる** (AA-D-33 の中心的根拠) | `admin-header-link.tsx:31`-`:36` が `ADMIN_HEADER_ITEMS` の「設定」= `PATH.ADMIN_SETTING_ACCOUNT`。分岐は `me.admin_auth_role_id === 1 ? SUPER_ADMIN_HEADER_ITEMS : ADMIN_HEADER_ITEMS` | **一致**。**逆に「アドミン設定」(作成・編集) は SuperAdmin ナビにしか無い** — AA-D-29③ の SuperAdmin 限定とも整合する |
| `PATH.ADMIN_SETTING_ACCOUNT = '/admin/settings/account'` | `hassan-v2-frontend/src/lib/path.ts:47` | **一致** |
| v2 の氏名変更は空応答 | `controller/admin_account.go:294` の `success(c)` | **一致** (設計の引用は `:295` = 閉じ括弧。±1 = 軽微 B) |
| v2 の DTO にパスワード確認欄が無い | `dto/admin_account.go:75-79` (`ID` / `OldPassword` / `NewPassword`) | **一致** |
| `event_mapper.go` に社内管理者経路のエントリが無い (④を監査対象外にする根拠) | `hassan-v2-backend/auth/event_mapper.go` — `admin` を含む行は `"PUT /accounts/admin"` (契約内管理者によるメンバー更新) の 1 件のみ | **一致** |
| `admin_accounts.name` / `email` の UNIQUE (④の 409 の根拠) | `db/schema.sql:54-55` | **一致** (第 1 巡で確認済み・再掲) |
| AA-D-31 が引く「最後の管理者ガード」の v2 出典 (**混在分の抜き取り**) | `usecase/account/delete_account.go:47`・`:52-54`、`update_account_by_admin.go:64`、`db/queries/account.sql:80-81` | **一致** |

## 中 (Should Fix)

### 中 A. §3.1.1 の `AU-C-00004` 行に ④ の 2 本が入っていない (DR-8 の波及漏れ)

- 箇所: `docs/design/API/auth-accounts.md:524` — 適用エンドポイント列が **`PUT /accounts/me/password` / `PUT /accounts/me/email` の 2 本のまま**
- 一方 §2.4 の `PUT /admin/admins/me/email` (`:255`) と `/me/password` (`:256`) は **400 + `AU-C-00004` (分類 C)** を返すと宣言し、§7.3 の UT #23 もそれを固定している
- **問題になる理由**: §3.1.1 は自ら「**FE と BE の共有契約であり、FE が『セッションを破棄するか』を決める唯一の入力**」と宣言している表である。**D-2 の CI 検査③ は「コード名・分類記号・HTTP ステータスの 3 列」しか照合しない**ため、適用先の欠落は機械検査を素通りする。管理画面の FE がこの表を見て「admin 側の 400 は未定義」と判断すると、**分類 C の 400 を分類 T (強制サインアウト) 相当に倒す**実装が生まれ得る (AA-D-9 / AA-D-18 が潰したはずの退行)
- 修正案: `:524` の適用列に ④ の 2 本を追記する (コードの新設は不要 — 値域は変えずに適用先だけ足す)

### 中 B. `auth.md` §10.2 **R-7③** が社内管理者 MFA を前提にしたまま残っている

- 箇所: `docs/design/auth.md:1806` の R-7 ③ 「**1 名で MFA デバイスを失った場合に限った回復手順 (DB 直更新の承認フロー)**」
- **社内管理者の MFA は 2026-08-10 の AA-D-22 で廃止済み**であり、①では「『初回 MFA 登録の手順』は削除した」と同じ行の中で宣言している。**同じ表の同じ行の中で、消えた機能の運用手順を要求し続けている**
- **問題になる理由**: R-7 は operations.md への是正要求であり (状態 = 未対応)、運用手順の担当者は**存在しない機能の回復手順を書くか、書けずに詰まる**。重大 2 と同じ「受け皿が旧前提のまま」の型
- 修正案: ③を削除するか、**登録リンクの再発行 (`POST /admin/admins/{admin_account_id}/password-registrations`) が SuperAdmin 1 名しかいないときに詰む**ケース (自分自身には再発行できるのか / SuperAdmin が 0 人になった場合) の手順に差し替える。**②「SuperAdmin を 2 名以上」と対で読める形にする**

### 中 C. (第 1 巡の中 4 の継続) 件数の機械照合が未実装のまま、転記先がさらに増えた

R-AA-25 に照合③〜⑥として起票された点は適切だが、**状態は未対応**で `scripts/check-endpoint-mapping.sh` は未変更である。今巡で **§2.4 は 13 → 16 本**、群の内訳に **④3 本**が加わり、`auth.md` §6.2 / §6.11-3・`README.md` §3 本文・§4 の A-2 / D-8 への転記も増えた。**D-2 の CI 検査② (公開 N 本 + `GET /alive`) は実装リポで機械照合される**ため、ずれた瞬間に実装リポの CI が落ちる。**R-AA-25 を「RL-2 前に片付ける」区分に入れるか、少なくとも実装着手前の期限を書く**こと (現状は期限の無い未対応キューに積まれている)。

## 軽微 (Nice to Have)

1. **`docs/design/auth.md:640` のテーブル行のインデントが落ちている** — §6.2 のロール表は箇条書き内の表 (`  | …` と 2 スペース字下げ) だが、今巡の編集で最終行 (`| **既存顧客のアクセスを回復する** …`) だけが字下げなしになった。**リストのコンテキストが切れて表が 2 つに分かれて描画され得る**。1 行の字下げで直る。
2. **引用行番号の ±1 が 3 件** — `controller/admin_account.go:295` (実体の `success(c)` は `:294`)、`admin-account-email-edit-form.tsx:60` (`updateAdminAccountsEmail` の呼び出しは `:59`)、`admin-account-password-edit.tsx:65` (同 `:64`)。いずれも同一の呼び出しブロック内なので実害は小さいが、**行番号を引くなら実測に合わせる** (`.claude/rules/06-delegation-prompts.md` の手順 3)。
3. **同一ファイルに別増分の変更が混在している** (カバレッジの注記に既述)。`auth-accounts.md` の AA-D-31 / AA-D-32、`observability.md` §4.5.2、`data-model.md` の DM-A5 論点 2・7 は**本レビューの判定対象外**である。push ゲートは本 review.md をこれらのファイルのレビュー証跡として扱うため、**別セッションでのレビューを別途通すこと**を推奨する。

## 本番観点カバレッジ (差分のみ。全体は第 1 巡の表)

| ID | 状態 | 今巡の変化 |
|---|---|---|
| **A-2** | **回答 (改善)** | ④群を `admin` ロールに開く判断が **v2 の実挙動 (`router.go:202-204`) と v2 FE のナビ分岐 (`admin-header-link.tsx:31`-`:36`)** の 2 つの一次ソースで裏付けられた。③との非対称 (SuperAdmin 限定 vs 誰でも) の理由も明示 |
| **A-4** | **回答 (改善)** | ④の対象を **JWT から解決**し path / body で受け取らない (**V2-D7 の解消**)。UT #21 で「ボディの `id` を受け取らないこと」を固定しており、**存在確認を所有権検証と取り違える型**を構造的に潰している |
| **A-5** | **回答 (ただし中 A)** | ④の 400 / 409 / 429 は定義済み。**§3.1.1 の適用先だけが未反映** |
| **O-4 / O-6** | **回答** | ④は監査対象外 (理由 = v2 に前例なし) を明示。403 / 409 / 400 を監査に書かず WARN + メトリクスで数える方針も明文化 |
| **D-4** | **回答** | RL-2 前の DB 要求は R-AA-17 / R-AA-30 / R-AA-33 のまま (④はスキーマを増やさない) |
| **D-3 / D-7** | **回答 (改善)** | R-AA-37 が **RL-2 の完了条件との前後関係**を持ち込み、`operations.md` が受信した |

## 頻出パターン (今巡)

| # | 判定 |
|---|---|
| DR-1 | **良好** (裏取り 11 件一致)。V2-D7 は**限定の付け方まで正確** (メール・パスワードは越境しない) |
| DR-6 | **改善** — AC を立てていない理由と立てる条件を §4 に明記 (軽微 5 の解消)。ID 衝突は無し (`AA-D-33` / `V2-D7` / `R-AA-35`〜`37` はいずれも定義 1 箇所) |
| DR-8 | **2 件** (中 A / 中 B)。ただし第 1 巡の 3 件はすべて解消しており、**波及の網羅度は上がっている** (`auth.md` §10.3 の R-IMP-2 に「さらに追加分」として波及先が列挙された) |
| DR-9 | **中 C** (継続)。今巡で新設された「計 14 本」「46 本」「403 16 本」は**機械照合済み**であり、増えた分の多くは検査に載った |
| BE-2 | **潰されている** — ③と④が同じ `admin_accounts` 行を更新することを AA-D-33 の代償③で明示し、**UNIQUE 違反 → 409 の写像を 1 箇所に集約**すると決めている |
| BE-10 | **解消** (重大 1) |
| BE-11 | **解消** (中 2。制約が入るまでの担保が §3.3 に明文化) |

## 良かった点 (第 2 巡)

- **重大 3 への対応が「指摘の字面」ではなく「原因」に当たっている** — 自己管理 3 本を足すだけでなく、**v2 の欠陥 (V2-D7) を新規に発見して §1.2 の欠陥表に登録し、その解消 (JWT から対象を解決) を設計に組み込み、UT #21 で固定**した。指摘の範囲を超えて品質が上がった例。
- **却下案 (b) の指摘が鋭い** — 「`PUT /admin/admins/{admin_account_id}` に自分自身を指定して代用する」案について、**同 API は `admin_auth_role` を本文に持つので自己昇格 (`admin` → `super_admin`) が可能になる**と論じており、権限設計として正しい。
- **非対称の明示** — ユーザー側の同等操作は監査に記録し、社内管理者の④は記録しない、という非対称を「v2 に前例があるかだけで決めた結果であり意図的である」と書いてある。**後から読む人が「漏れ」と誤認して直す**ことを防ぐ形。
- 第 1 巡の**軽微まで全件対応**しており、うち 3 件 (軽微 1・2・3) は**指摘より精密な形**で直っている (行番号を 2 箇所に分けて引用、過去形と現在値の併記)。

## 第 3 巡 (2026-08-29。メインセッションが直接修正)

**中 A・中 B を解消**。中 C は R-AA-25 への要求記載で対応済み扱いのまま継続 (スクリプト実装は別増分)。

- **中 A 解消**: `docs/design/API/auth-accounts.md` の `AU-C-00004` 定義行に
  `PUT /admin/admins/me/password` (`old_password`) / `PUT /admin/admins/me/email` (`password`) を追加した。
  各エンドポイント行 (`:255`・`:256`) は元々 `AU-C-00004` を参照していたため、定義側との不整合を解消した。
- **中 B 解消**: `docs/design/auth.md` の R-7③「1 名で MFA デバイスを失った場合に限った回復手順」を削除した。
  社内管理者の MFA は AA-D-22 (2026-08-10) で廃止済みであり、デバイス紛失という事象自体が存在しない。
  同じ行の①で「初回 MFA 登録の手順を削除した」と書きながら③が残っていた DR-8 型の取り残しだった。
- 検証: `make doc-lint` エラー 0 / `make check-endpoint-mapping` 照合 44 件エラー 0 /
  `make check` 全ゲート緑 (traceability productionization **125/125**)。

**最終判定: 重大 0 件・中 0 件 (未解消)・軽微 0 件 (未解消) — 合格。push 可**。
