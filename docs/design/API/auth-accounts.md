# API: 認証・アカウント基盤 (v3 で実装する移植 + 新設)

> 共通規約 (レスポンス形・エラー本文・ページネーション・パス命名) の SSOT: [README.md](README.md) §1.2
> **認証・認可・セキュリティ要件の SSOT は [../auth.md](../auth.md)** — 本書はその規約に載せた
> **エンドポイントごとの入出力仕様**であり、トークン形式・鍵・レート制限値・判定規則を再定義しない
> 本書が回答する本番観点: **A-1, A-2, A-3 (参照), A-4, A-5, A-6 (対象外), A-7, O-1, O-2 (対象外),
> O-3 (対象外), O-4, O-5, O-6, O-7 (先送り), D-2, D-4 (参照), D-5 (参照), D-6 (対象外), D-7 (参照)**。
> **D-1 / D-3 / D-8 は対象外** (理由は §4 の同 ID 行)。回答は全件 §4 の表にある
> 対応する受入基準: **AC-1.1 / AC-1.4 / AC-1.5 / AC-1.6**
> 位置づけ: [plan.md](../../../aidlc-docs/inception/productionization/plan.md) の **Task-3i** =
> [../auth.md](../auth.md) §10.2 **R-3** への回答
> 必須観点 ID の一覧: [../../../.claude/rules/08-production-gates.md](../../../.claude/rules/08-production-gates.md)

## 1. 位置づけ・対応画面・移植元

### 1.1 本書が仕様を定める範囲

**D-ST-1' (ユーザー決定 2026-07-30。[settings.md](settings.md) §4)** により、認証・アカウント基盤は
**v2 の API を再利用せず v3 で実装する**。[settings.md](settings.md) §5 は「v2 に何があったか」の
移植チェックリスト (18 行) を持つが、**入出力仕様は存在しなかった** ([../auth.md](../auth.md) §10.2 R-3)。
本書がそれを埋める。

| 区分 | 所在 |
|---|---|
| 移植チェックリスト (v2 の何を移植するか) | [settings.md](settings.md) §5 — 本書 §2.6 で**全 18 行の対応**を示す |
| 認証・認可の規約 (トークン・鍵・系統・レート制限・401/403/404) | [../auth.md](../auth.md) §6.1〜§6.11 |
| スキーマ (`accounts` / `companies` / `contracts` / `signup_links` 等) | [../data-model.md](../data-model.md) §4.2 |
| 画面とルート | [../frontend.md](../frontend.md) §11.1 (`/login` `/mfa` `/mfa/setup` `/signup` `/reset-password` `/settings/members` `/admin/*`) |
| E2E での認証の扱い | [../testing.md](../testing.md) §7.3 |
| v2 の既存実装 (移植元) | `hassan-v2-backend/controller/account.go` / `mfa.go` / `admin_account.go` / `company.go` / `contract.go`、`hassan-v2-backend/usecase/account/`・`usecase/mfa/`・`usecase/admin_account/`、`hassan-v2-backend/db/queries/account.sql` / `signup_link.sql` |
| v2 の既存ルート | `hassan-v2-backend/router/router.go:61-103` (contracts / accounts / companies / company-mission)、`:194-211` (admin)、`:229-233` (mfa) |

**対応する画面** ([../frontend.md](../frontend.md) §11.1 の `[未確定] (Task-3i)` 行がすべて本書に対応する):
`/login` / `/mfa` / `/mfa/setup` / `/signup` / `/reset-password` / `/settings/members` /
`/admin/signin` / `/admin/mfa` / `/admin/mfa/setup` / `/admin/accounts` / `/admin/admins` /
**`/admin/contracts` / `/admin/contracts/[contractId]`** (2026-08-25 追加 = AA-D-26)。
**`/admin/mfa` / `/admin/mfa/setup` は AA-D-22 で消滅済み**なので、実在するのは残りである
(**実数は [../frontend.md](../frontend.md) §11.1 の表が正** — ここに件数を転記しない = DR-9)。
**FE の画面仕様は書かない** (同節が SSOT)。本書は API 契約のみを定める。

**API → 画面の逆引き (2026-07-31 に実施。上の 11 ルートは「画面 → API」の方向しか見ていなかった)**:

| 本書のエンドポイント | 行き先の画面 | 状態 |
|---|---|---|
| §2.1 の 8 本 | `/login` / `/signup` / `/reset-password` / `/admin/signin` / **`/admin/password-registration`** (**2026-08-29 の AA-D-30。§5 R-AA-32③ で新設を要求**) | 既存 4 + **新設 1** |
| §2.2 の 2 本 | `/mfa` / `/mfa/setup` | 既存 |
| §2.3.1 の **`GET /accounts/me`** | 全画面のヘッダ・セッション初期化 ([../frontend.md](../frontend.md) §5.2.2) | 既存 |
| §2.3.1 の **残り 6 本** (`PUT /accounts/me` / `PUT /accounts/me/email` / `PUT /accounts/me/password` / `POST /accounts/me/icon` / `DELETE /accounts/me/icon` / `POST /mfa/totp/reset`) | **`/settings/profile`** | **新設済み** ([../frontend.md](../frontend.md) §11.1。2026-07-31。§5 **R-AA-16** = 実施済み)。**6 本すべてに消費者となる画面がある**ので、本増分から外す条件分岐は消滅した |
| §2.3.2 の 9 本 + §2.3.3 の 4 本 | `/settings/members` | 既存 (会社情報も同画面) |
| §2.4 の①アカウント回復・閲覧 (5 本) | `/admin/accounts` / `/admin/admins` | 既存。**`/admin/mfa*` は AA-D-22 で消滅** |
| §2.4 の②契約管理 (5 本) | **`/admin/contracts` / `/admin/contracts/[contractId]`** | **新設** ([../frontend.md](../frontend.md) §11.1。2026-08-25 = AA-D-26)。**5 本すべてに消費者となる画面がある** (招待の再発行は詳細画面のボタン = AA-D-27) |
| §2.4 の③他の管理者アカウントの管理 (3 本) | **`/admin/admins`** (一覧に新規作成・編集・登録リンク再発行の導線を足す) | **未整備** (**§5 R-AA-32①②で新設を要求**。2026-08-29 = AA-D-29 / AA-D-30) |
| §2.4 の④自己管理 (3 本) | **社内管理者向けの設定画面** (v2 の `/admin/settings/account` 相当) | **未整備** (**§5 R-AA-32④ で新設を要求**。2026-08-29 = AA-D-33。**`admin` ロールから到達できる導線が必須**) |

### 1.2 v2 の事実 (移植の入力。出典付き)

**フロー**:

| # | 事実 | 出典 |
|---|---|---|
| V2-F1 | **サインアップは「管理者がメンバー行を作る → 招待リンクを送る → 本人がパスワードを設定する」の 3 段**。`POST /accounts` は `crypted_password` を入れずに行を作り (`is_completed = false`)、`POST /accounts/signup-links` がリンクをメールし、`POST /accounts/signup` がパスワードを設定して `is_completed = true` にする | `hassan-v2-backend/db/queries/account.sql:26-27`、`hassan-v2-backend/usecase/account/create_signup_link.go:43-93`、`hassan-v2-backend/usecase/account/sign_up.go:40-91` |
| V2-F2 | **招待リンクの秘密はリンク ID (UUID v4) 自体**。`uuid.New()` で生成し 7 日有効。使用後に削除する | `hassan-v2-backend/usecase/account/create_signup_link.go:68`, `:83-88`, `hassan-v2-backend/usecase/account/sign_up.go:87` |
| V2-F3 | **`signup_links` は所有者列を持たない** (`id` / `email` / `expired_at` / `created_at` / `updated_at` の 5 列) | `hassan-v2-backend/db/schema.sql:342-348` |
| V2-F4 | **メンバー作成時に契約の人数上限を検査する** (`len(accounts) >= contract.num_of_members` → `AccountLimitExceeded`)。**email はテナントを跨いでグローバル一意** | `hassan-v2-backend/usecase/account/create_account.go:51`, `:64-65`、`hassan-v2-backend/db/schema.sql:49` (`CREATE UNIQUE INDEX unique_accounts_email`) |
| V2-F5 | **サインインは JWT を返す。MFA は会社単位** (`companies.mfa_type`) で、発行時は `mfa_verified: false`。有効期限 7 日 | `hassan-v2-backend/usecase/account/sign_in.go:106-114`、`hassan-v2-backend/db/schema.sql:86` |
| V2-F6 | **MFA 検証成功で `mfa_verified: true` のトークンを再発行**し、初回検証時に `account_mfa_configs.is_verified` を true にする。期限は再発行時点から 7 日 | `hassan-v2-backend/usecase/mfa/verify_totp.go:62-77` |
| V2-F7 | **ミドルウェアの MFA ゲートは `RequiredMfaType != 'none' && !MfaVerified` のときパス前方一致 `/mfa` 以外を 401** | `hassan-v2-backend/auth/middleware.go:40-47` |
| V2-F8 | **`POST /mfa/totp/reset` は「有効な TOTP コードを添えて設定を削除する」自己再登録の経路**であり、デバイス紛失時の回復には使えない。紛失時の回復は契約内管理者の `POST /accounts/mfa/reset` (同一契約のみ) | `hassan-v2-backend/usecase/mfa/reset_totp.go:25-46`、`hassan-v2-backend/usecase/account/reset_member_mfa.go:44-66` |
| V2-F9 | **社内管理者は一般アカウントの MFA を全契約横断でリセットできる** (`POST /admin/companies/accounts/mfa/reset`)。`AdminAuthRequiredMiddleware` 配下で、Admin / SuperAdmin のどちらでも実行可 | `hassan-v2-backend/router/router.go:217`、`hassan-v2-backend/controller/account.go:1033-1082` |
| V2-F10 | **パスワードリセットは 1 時間有効・期限確認あり・使用後削除あり。ロックは解除されない** (成功しても `last_locked_at` に触れない) | `hassan-v2-backend/usecase/account/request_reset_password.go:57-62`、`hassan-v2-backend/usecase/account/reset_password.go:38-89` |
| V2-F11 | **メール送信は Resend (外部 SaaS)**。日本語/英語テンプレートを持ち、言語は**リクエストの Host** で決まる (`sparkfield-ai.com` を含めば英語) | `hassan-v2-backend/usecase/account/email_service.go:1-60`、`hassan-v2-backend/controller/middleware.go:52-70` |
| V2-F12 | **契約内管理者を要求する操作 (本書の範囲)**: メンバー作成 / 権限変更 / 削除 / 招待リンク発行 / ロック解除 / メンバーの MFA リセット / 会社の MFA 方式変更 | `hassan-v2-backend/controller/account.go:104`, `:423`, `:598`, `:850`, `:897`, `:990`、`hassan-v2-backend/controller/company.go:530-533` |
| V2-F13 | **最後の管理者を守るガードが 2 つある** (削除・降格)。**どちらのカウントもロック状態を見ない** (`WHERE contract_id = $1 AND auth_role_id = 1`) | `hassan-v2-backend/usecase/account/delete_account.go:46-55`、`hassan-v2-backend/usecase/account/update_account_by_admin.go:63-72`、`hassan-v2-backend/db/queries/account.sql:80-81` |
| V2-F14 | **メンバー一覧は契約スコープ・ページネーション無し・裸配列**。`mfa_enabled` は UseCase で後付けする | `hassan-v2-backend/controller/account.go:230-246`、`hassan-v2-backend/usecase/account/list_accounts.go:36-65`、`hassan-v2-backend/db/queries/account.sql:20-24` |
| V2-F15 | **社内管理者向けのアカウント一覧は `last_locked_at` と `company_name` を返し、`limit`/`offset` と `total_count` を持つ** (`limit = 0` は全件)。検索対象は会社名・氏名・メール。**契約の言語で絞り込む** | `hassan-v2-backend/db/queries/account.sql:86-120`、`hassan-v2-backend/controller/account.go:933-972`、`hassan-v2-backend/controller/dto/account.go:165-215` |
| V2-F16 | **企業ミッションは会社単位ではなくアカウント単位** (`company_missions.account_id`) で、発散セッション作成時の既定ミッションとして書かれる | `hassan-v2-backend/db/queries/company_mission.sql:1-13`、`hassan-v2-backend/usecase/idea_hassan/create_idea_hassan.go:111-126` |
| V2-F17 | **監査記録の種別に認証系が既に存在する**: `signin_success` / `signin_failed` / `mfa_verify_success` / `mfa_verify_failed` / `mfa_reset_by_admin` / `mfa_reset_by_aillio_admin`。`activity_logs` は `account_id` を NULL 可とし、失敗時は `account_email` を平文で持つ | `hassan-v2-backend/db/schema.sql:467-489` |

**v2 の欠陥 (本書で構造的に潰す対象。[../auth.md](../auth.md) §5 に無い 3 件を含む)**:

| # | 欠陥 | 出典 | 本書の対応 |
|---|---|---|---|
| V2-D1 | **招待リンクとアカウントが突き合わされない** — `POST /accounts/signup` はリンクの期限だけを確認し、**クライアントが送った `email` で `accounts` を引いてパスワードを設定する**。`signupLink.Email` との一致検証が無いため、**有効なリンクを 1 つ持つ者は「まだサインアップしていない任意のアカウント (他契約を含む)」のパスワードを設定できる** | `hassan-v2-backend/usecase/account/sign_up.go:40-79` (`signupLink.Email` の参照が無い)、`hassan-v2-backend/controller/dto/account.go:103-108` (`email` を受け取る) | **AA-D-5**: `email` を受け取らない。アカウントはリンクから解決する |
| V2-D2 | **MFA 検証の失敗が 500 になる** — `VerifyTotp` は `TotpCodeNotMatch` を返すが、Controller が `internalServerError` に流す。`CreateTotp` / `ResetTotp` も同じ | `hassan-v2-backend/controller/mfa.go:80-83`, `:45-48`, `:113-116`、`hassan-v2-backend/controller/controller.go:63-68` (`internalServerError` は型を見ずに 500) | **AA-D-9**: 401 + `CodedError` (`AU-C-00003` = **分類 C**。§3.1.1)。O-4 として警告に出す |
| V2-D3 | **リセット要求の応答にリセットトークンを入れる DTO がある** (`RequestResetPasswordRes.Hash`)。現在のハンドラは `success(c)` を返すだけで未使用だが、**型が残っている限り「応答に入れる」実装が前例として復活しうる** | `hassan-v2-backend/controller/dto/account.go:139-141`、`hassan-v2-backend/controller/account.go:672` | **AA-D-6**: 要求の応答は 204 固定。秘密を応答に含める型を作らない |
| V2-D4 | ロック解除が email 指定でテナント検証なし | [../auth.md](../auth.md) §5-11 | **AA-D-11** |
| V2-D5 | リセットトークンが `math/rand` 由来 | [../auth.md](../auth.md) §5-8 | **AA-D-6** ([../auth.md](../auth.md) §6.10) |
| V2-D6 | リセット要求でメールアドレスの登録有無が判る (未登録は 400) | [../auth.md](../auth.md) §5-9、`hassan-v2-backend/controller/account.go:663-665` | **AA-D-6** |
| V2-D7 | **社内管理者の「自分の氏名変更」に所有権検証が無い** — `PUT /admin/accounts/name` は**対象をボディの `id` で受け取り**、呼び出し元 (JWT の主体) と一致するかを検証しない。UseCase も `UPDATE ... WHERE id = $1` を撃つだけ。したがって**認証済みの社内管理者 (`admin` ロールを含む) は、他の社内管理者 (SuperAdmin を含む) の氏名を書き換えられる**。**メール・パスワード変更は対象の現行パスワード提示を要求する**ため同じ形の越境は成立しない (`update_admin_account_email.go:34-37` / `update_admin_account_password.go:34-37`) | `hassan-v2-backend/controller/admin_account.go:272-295` (ボディの `id` をそのまま UseCase へ)、`hassan-v2-backend/usecase/admin_account/update_admin_account_name.go:24-28`、DTO は `hassan-v2-backend/controller/dto/admin_account.go:57-60` | **AA-D-33**: 対象を **JWT から解決**し、パス・ボディで受け取らない (AA-D-3 の社内管理者版)。**V2-D4 (ロック解除の email 指定) と同型の欠陥** |

### 1.3 確定済みの前提 (本書はこれを再議論しない)

| # | 前提 | 出典 |
|---|---|---|
| P-1 | **併用期間のアカウント基盤は v3 を正とする**。RL-3 の最初に v2 → v3 へ 1 回コピー (bcrypt ハッシュ・MFA シークレットをそのまま移送)、以後 v3 が唯一の書き込み先。**`POST /accounts/signin` は v3 の DB のみを参照する** (v2 の資格情報をフォールバック参照しない) | [../data-model.md](../data-model.md) §6.5 (DM-A3。2026-07-31 確定) |
| P-2 | **`signup_links` は `contract_id NOT NULL` + FK を持つ**。既存 v2 の未使用リンクは引き継がず失効・再発行 | [../data-model.md](../data-model.md) §4.2 / §6.5 (DM-A4=B) |
| P-3 | **社内管理者トークンの有効期間は一般ユーザーと同じ 7 日** | [../frontend.md](../frontend.md) §11.3.1 ([Answer] FE-Q8。2026-07-31) |
| P-4 | **E2E 専用アカウントは MFA 無効**。例外の表現は本書が定義する (§3.6) | [../testing.md](../testing.md) §7.3 (T-Q3=B) |
| P-5 | **社内管理者は MFA (TOTP) 必須**・初回サインイン後に登録を強制。ロック機構は持たない | [../auth.md](../auth.md) §6.2 |
| P-6 | **認証系統は 3 系統のホワイトリスト** (2026-08-10 の AA-D-22 で 4 → 3)で管理し、CI が系統単位の一致を検査する (**系統の定義と検査機構の SSOT**。ホワイトリストに載る**エンドポイントの列挙**は本書 §2 が元表 — AA-D-20) | [../auth.md](../auth.md) §6.7 |
| P-7 | **レート制限・応答マスク・429・ロック機構**は [../auth.md](../auth.md) §6.11 が SSOT。本書は適用対象の列挙のみを行う (§2.1 / §3.7) | [../auth.md](../auth.md) §6.11 |
| P-8 | **手動ロック API は v3 新設**。契約内管理者 = ロック + 解除 (自分自身・最後の契約内管理者のガード付き)、社内管理者 = 解除のみ・全契約横断 | [../auth.md](../auth.md) §6.9 |

---

## 2. エンドポイント一覧 (合計 **46 本**)

### 2.0 表記と共通規約

- **Q** = クエリ / **B** = リクエストボディ / **R** = レスポンス本文
- **系統** = [../auth.md](../auth.md) §6.7 の 3 系統 (2026-08-10 の AA-D-22 で 4 → 3)。**節ごとに 1 系統**にしてあり、この節構成が
  **「どのエンドポイントがどの系統か」の元表**になる (§7.2 で実装リポへ引き渡す)。
  **系統の定義そのものと CI 検査の仕組みは同 §6.7 が SSOT** — 役割分担は **AA-D-20** (P-6 との関係もそこで整理)
- **共通のステータス**は [README.md](README.md) §2.5 に従い、本表は**固有のもののみ**挙げる。
  ただし本書には**同節が「本ディレクトリの対象外」とした 3 点がある** — ①公開エンドポイント
  ②401 に本文を持つ応答 (§3.1 AA-D-9。**分類とコードの値域は §3.1.1**) ③429 (§3.7)。差分は §3.1 と §4 に明示する
- **401 を返す表の行は必ず分類 (T / C) を書く** (§3.1.1)。**分類 C の 401 は FE がセッションを破棄しない**
- 一覧は **`{items, total_count}`** ([README.md](README.md) D-API-5)、`limit` 既定 50 / 上限 200、
  `limit=0` は 400 (同 D-API-7)。作成 201 / 更新 200 / 削除 204 (同 D-API-11)。
  **例外 2 件**: `POST /accounts/signup` と **`POST /admin/password-registrations`** は **200**
  (どちらも既存行のパスワード設定であり作成ではない。§2.1 / §3.3。後者は 2026-08-29 の **AA-D-30**)
- **JSON キーは snake_case**、ID は `accounts` / `contracts` / `companies` が uuid
  ([../data-model.md](../data-model.md) §4.2 が v2 の型をそのまま持つ)。

### 2.1 系統: 公開 (認証なし。8 本)

**全 8 本がレート制限の対象** ([../auth.md](../auth.md) §6.11-3。キーは IP + エンドポイント、
リセット要求とサインインはメールアドレス単位も併用)。**超過は 429 + `Retry-After`**。
**下 2 本は 2026-08-29 に追加** (AA-Q15 = (c) のオーナー回答 → **AA-D-30**。社内管理者の初回パスワード設定)。

| メソッド | パス | 概要 | 主な入出力 | 固有ステータス | 移植元 |
|---|---|---|---|---|---|
| POST | `/accounts/signin` | サインイン (JWT 発行) | B: `{email, password}` — R: `SignInResult` (§2.5) | 200 / **401** (資格情報不正 = マスク `AU-C-00001` / ロック `AU-C-00002` / **無効化済み `AU-C-00006`** = [../data-model.md](../data-model.md) の DM-A5 補足 1。**分類 C** = §3.1.1) / 429 | `hassan-v2-backend/router/router.go:76`、`hassan-v2-backend/usecase/account/sign_in.go:57-133` |
| POST | `/accounts/signup-links/lookup` | 招待リンクの検証と招待先の表示 (**読み取りだが POST**。理由は AA-D-4) | B: `{token}` — R: `{email, expires_at}` | 200 / **404** (不正・期限切れ・使用済みを区別しない) / 429 | `同:78` (`GET /accounts/signup-links/:id`)、`hassan-v2-backend/usecase/account/get_signup_link.go:31-42` |
| POST | `/accounts/signup` | 招待受諾 (パスワード設定) | B: `{token, password, confirmed_password}` — **`email` を受け取らない** (V2-D1) — R: `SignInResult` (そのままサインイン状態にする) | **200** (**201 ではない** — 作成ではなく既存行 (`is_completed=false`) のパスワード設定であり `Location` を返さない。[README.md](README.md) D-API-11「作成 201」に対する明示の例外。§3.3) / **404** (トークン不正・**トークンから解決したアカウントが無効化済み** = **AA-D-32**。両者を区別しない) / **409** (既にサインアップ済み) / **400** (パスワード不一致・強度違反) / 429 | `同:75`、`hassan-v2-backend/usecase/account/sign_up.go:40-91` |
| POST | `/accounts/reset-password` | パスワードリセット要求 (メール送信) | B: `{email}` — R: なし | **204 固定** (アカウント不存在でも 204。[../auth.md](../auth.md) §6.11-1) / 429 | `同:79`、`hassan-v2-backend/usecase/account/request_reset_password.go:45-90` |
| POST | `/accounts/reset-password/confirm` | パスワードリセット実行 (**トークンはボディ**。AA-D-4) | B: `{token, password, confirmed_password}` — R: なし | 204 / **404** (トークン不正・期限切れ・使用済み) / **400** (不一致・強度違反・**旧パスワードと同一**) / 429 | `同:80`、`hassan-v2-backend/usecase/account/reset_password.go:38-89` |
| POST | `/admin/signin` | 社内管理者サインイン | B: `{email, password}` — R: `AdminSignInResult` (§2.5) | 200 / **401** (資格情報不正 = マスク `AU-C-00001`。**分類 C**) / 429 | `同:195`、`hassan-v2-backend/controller/admin_account.go:420-442` |
| POST | `/admin/password-registrations/lookup` | **社内管理者のパスワード登録リンクの検証**と登録先の表示 (**読み取りだが POST**。AA-D-4) | B: `{token}` — R: `{email, expires_at}` | 200 / **404** (不正・期限切れ・使用済みを区別しない。AA-D-6④) / 429 | `hassan-v2-backend/router/router.go:199` (`GET /admin/accounts/register/password/check`)、`hassan-v2-backend/usecase/admin_account/check_register_password_token.go:29-47`。**`email` の返却は v3 の追加** (v2 は `AdminAccountID` のみを返す) — `POST /accounts/signup-links/lookup` と揃えた |
| POST | `/admin/password-registrations` | **社内管理者の初回パスワード設定** (登録リンクの受諾) | B: `{token, password, confirmed_password}` — R: `AdminSignInResult` (§2.5。そのままサインイン状態にする) | **200** (**201 ではない** — 既存 `admin_accounts` 行のパスワード設定。§2.0 の例外 2 件目) / **404** (トークン不正・期限切れ・使用済み) / **400** (確認不一致・強度違反) / 429 | `同:200`、`hassan-v2-backend/usecase/admin_account/register_password.go:33-58`、`hassan-v2-backend/controller/admin_account.go:242-259` |

### 2.2 系統: ユーザー認証 (MFA 未検証で到達可。2 本)

**この 2 本だけをホワイトリストに載せる** ([../auth.md](../auth.md) §6.7。v2 のパス前方一致 `/mfa` を採らない
= V2-F7 を継承しない)。**`POST /mfa/totp/verify` はレート制限の対象** (キー = `account_id` + エンドポイント。
理由は AA-D-10)。

| メソッド | パス | 概要 | 主な入出力 | 固有ステータス | 移植元 |
|---|---|---|---|---|---|
| POST | `/mfa/totp/generate` | TOTP の登録開始 (シークレット発行) | R: `{totp_url, issued_at}` (`otpauth://` URL。QR は FE が描く) | 200 / **409** (検証済みの TOTP が既にある) | `hassan-v2-backend/router/router.go:231`、`hassan-v2-backend/usecase/mfa/create_totp.go:29-61` |
| POST | `/mfa/totp/verify` | TOTP の検証 (トークン再発行) | B: `{totp_code}` (6 桁) — R: `{token, expires_at, mfa: {required_type, registered, verified}}` | 200 / **401** (コード不一致 `AU-C-00003`。**分類 C** = セッションを破棄しない。**v2 は 500** = V2-D2) / **404** (登録が無い) / **429** | `同:232`、`hassan-v2-backend/usecase/mfa/verify_totp.go:46-88` |

### 2.3 系統: ユーザー認証 (MFA 検証済みが必須。20 本)

**スコープ列の意味**: **自分** = `WHERE account_id = <認証ユーザー>` / **契約** =
`WHERE contract_id = <認証ユーザーの契約>` ([README.md](README.md) §2.3)。
**403 の 16 本は契約内管理者限定 (R-1) 8 本と SuperAdmin 限定 (R-4) 8 本**
(**実測は `make check-endpoint-mapping` が正**。2026-08-10 の AA-D-22 / AA-D-13 で 9 → 8、
**2026-08-25 の AA-D-26 で §2.4 の契約管理 4 本が加わり 8 → 12、2026-08-26 の AA-D-27 で招待の再発行が加わり 12 → 13、
2026-08-29 の AA-D-29 で §2.4 の③管理者アカウント管理 2 本が加わり 13 → 15、
同日の AA-D-30 で登録リンクの再発行 1 本が加わり 15 → 16**)。
R-1 の 8 本のうち 3 本は**契約の不変条件ガード (R-3。§3.4)** でも 403 を返す。
**R-4 = 社内管理者の SuperAdmin 限定** — §2.4 の②契約管理 (招待の再発行を含む) と
**③他の管理者アカウントの管理 (AA-D-29 / AA-D-30)** が該当し、`admin` ロールでは 403 になる。
**§2.4 の④自己管理 3 本 (AA-D-33) は R-4 の対象外** — `admin` ロールでも 200 / 204 を返すため、**403 の本数は 16 本のまま**である。

#### 2.3.1 自分のアカウント (7 本)

**うち 3 本 (`PUT /accounts/me/email` / `PUT /accounts/me/password` / `POST /mfa/totp/reset`) は
レート制限の対象** (キー = `account_id` + エンドポイント。AA-D-10 / §3.7)。**行き先の画面は `/settings/profile`**
([../frontend.md](../frontend.md) §11.1 に 2026-07-31 に新設済み。§1.1 / R-AA-16)。

| メソッド | パス | 概要 | スコープ | 主な入出力 | 固有ステータス | 移植元 |
|---|---|---|---|---|---|---|
| GET | `/accounts/me` | 自分のアカウント取得 | 自分 | R: `Account` (§2.5。`mfa_registered` を含む — **v2 は常に false を返す** V2-F14 の裏返し) | 200 | `hassan-v2-backend/router/router.go:66`、`hassan-v2-backend/controller/account.go:174-177` |
| PUT | `/accounts/me` | 氏名・所属・役割の更新 | 自分 | B: `{name, division, role}` — R: `Account` | 200 / 400 | `同:69`、`hassan-v2-backend/usecase/account/update_account_by_member.go` |
| PUT | `/accounts/me/email` | メールアドレス変更 | 自分 | B: `{new_email, password}` — R: `Account` | 200 / **400** (パスワード不一致 `AU-C-00004`。**分類 C** = §3.1.1。AA-D-17) / **409** (既に使われている) / **429** (AA-D-10) | `同:71`、`hassan-v2-backend/usecase/account/update_email.go:35-66` |
| PUT | `/accounts/me/password` | パスワード変更 | 自分 | B: `{old_password, new_password, confirmed_new_password}` — R: なし | 204 / **400** (旧パスワード不一致 `AU-C-00004` [**分類 C**。AA-D-17] / 確認不一致・強度違反 [バリデーション。別コード]) / **429** (AA-D-10) | `同:72`、`hassan-v2-backend/usecase/account/update_password.go:36-68` |
| POST | `/accounts/me/icon` | アイコン登録 (`multipart/form-data`) | 自分 | B: `file` — R: `{icon_url, icon_url_expires_at}` | 200 / **400** (拡張子・サイズ違反) | `同:73`、`hassan-v2-backend/controller/account.go:745-775` |
| DELETE | `/accounts/me/icon` | アイコン削除 | 自分 | — | 204 | `同:74` |
| POST | `/mfa/totp/reset` | 自分の TOTP を解除して再登録できる状態にする (**有効な TOTP コードが必要**) | 自分 | B: `{totp_code}` — R: なし | 204 / **400** (コード不一致 `AU-C-00005`。**分類 C** = §3.1.1。AA-D-17) / **404** (登録が無い) / **429** (AA-D-10) | `同:233`、`hassan-v2-backend/usecase/mfa/reset_totp.go:25-46` |

#### 2.3.2 メンバー管理 (9 本。**403** = 契約内管理者限定 7 本。一覧・取得の 2 本は全メンバー可)

| メソッド | パス | 概要 | スコープ | 主な入出力 | 固有ステータス | 移植元 |
|---|---|---|---|---|---|---|
| GET | `/accounts` | 契約内メンバー一覧 (**ロック状態を含む**) | 契約 | Q: `keyword` (氏名・メール・役割・所属) / **`include_deactivated`** (既定 `false`。無効化済みを含めるか — DM-A5 補足 3) / `limit` / `offset` / `sort` (`updated_at`\|`created_at`\|`name`) — R: `{items: Account[], total_count}` | 200 / 400 | `同:65`、`hassan-v2-backend/db/queries/account.sql:20-24`、ロック列は `hassan-v2-backend/db/queries/account.sql:98` |
| GET | `/accounts/{account_id}` | メンバー取得 | 契約 | R: `Account` | 200 / **404** (他契約・不存在) | `同:67`、`hassan-v2-backend/usecase/account/get_account_by_id.go:33-46` |
| POST | `/accounts` | メンバー作成 (パスワード無し・`is_completed=false`) | 契約 | B: `{name, email, auth_role, division, role}` — R: `Account` | **201** / **403** / **409** (メール重複・**契約の人数上限**) / 400 | `同:68`、`hassan-v2-backend/usecase/account/create_account.go:40-73` |
| PUT | `/accounts/{account_id}` | メンバーの氏名・メール・権限変更 | 契約 | B: `{name, email, auth_role, division, role}` — R: `Account` | 200 / **403** (管理者以外 / **最後の契約内管理者の降格**) / **404** / **409** (メール重複) | `同:70`、`hassan-v2-backend/usecase/account/update_account_by_admin.go:37-80` |
| DELETE | `/accounts/{account_id}` | メンバー削除 (**無効化のみ。所有物は移管しない**。AA-D-13)。**副作用: 同一トランザクションで当該アカウントの未使用の招待リンクを削除する** (AA-D-32③。§3.3) | 契約 | R: なし | **204** / **403** (管理者以外 / **最後の契約内管理者** / **自分自身**) / **404** | `同:81`、`hassan-v2-backend/usecase/account/delete_account.go:31-64`、無効化の帰結 7 点は [../data-model.md](../data-model.md) §4.2 の **DM-A5 補足**が SSOT。**既存トークンは次のリクエストで 401 になる** (同補足 2。2026-08-29 に「失効しない」から改訂 = AA-D-32)・**メールアドレスは永久に占有される** |
| POST | `/accounts/{account_id}/signup-links` | 招待リンクの発行・再送 (**未使用リンクを失効させてから発行**) | 契約 | R: `{expires_at}` (**トークンは応答に含めない**) | **201** / **403** / **404** / **409** (既にサインアップ済み) | `同:77`、`hassan-v2-backend/usecase/account/create_signup_link.go:43-93` |
| POST | `/accounts/{account_id}/mfa/reset` | メンバーの TOTP をリセット (デバイス紛失時) | 契約 | R: なし | 204 / **403** / **404** | `同:83`、`hassan-v2-backend/usecase/account/reset_member_mfa.go:44-70` |
| POST | `/accounts/{account_id}/lock` | **手動ロック (v3 新設)**。⚠️ **2026-08-10 の実装スコープ外** — 設計は確定させたまま、9 月末までの増分では実装しない (§6.1 の AA-Q13) | 契約 | R: `Account` (`is_locked=true`) | 200 / **403** (管理者以外 / **自分自身** / **最後の未ロック契約内管理者**) / **404** | **v2 に無い** ([../auth.md](../auth.md) §6.9) |
| DELETE | `/accounts/{account_id}/lock` | ロック解除 (失敗回数も 0 に戻す) | 契約 | R: `Account` (`is_locked=false`) | 200 / **403** (管理者以外) / **404** | `同:82`、`hassan-v2-backend/db/queries/account.sql:73-78` (**email 指定の `:66-71` は使わない** = V2-D4) |

#### 2.3.3 契約・会社情報 (4 本。**403** = 1 本)

**パスに `/me` を付けない** (2026-08-15 の AA-D-25。AA-D-2 の適用範囲の訂正) — `/me` は
**認証ユーザー自身のレコード**を指す接尾辞であり、契約・会社は**同一契約内の全ユーザーで共有される
1 レコード**なので対象が違う。単数形の単一リソースパス (`/contract` / `/company`) を使う。

| メソッド | パス | 概要 | スコープ | 主な入出力 | 固有ステータス | 移植元 |
|---|---|---|---|---|---|---|
| GET | `/contract` | 自分の契約情報 (認証コンテキストの `contract_id` から解決。ID 不要) | 契約 | R: `{id, num_of_members, member_count, start_date, end_date, representative_name, representative_email, division, created_at, updated_at}` — **`sharing_settings` を返さない** (AA-D-15) | 200 | `hassan-v2-backend/router/router.go:62`、`hassan-v2-backend/controller/dto/contract.go:18-42` |
| GET | `/company` | 会社情報 (契約に 1 件。同上) | 契約 | R: `{id, contract_id, name, url, business_summary, strengths, mfa_type, created_at, updated_at}` | 200 / **404** (行が無い) | `同:93`、`hassan-v2-backend/controller/dto/company.go:18-41` |
| PUT | `/company` | 会社情報の更新 (**行が無ければ 404**。作らない = AA-D-14) | 契約 | B: `{name, url, business_summary, strengths}` — R: 上と同じ | 200 / 400 / **404** (行が無い = 移行の失敗。GET と同じ扱い) | `同:95-96` |
| PUT | `/company/mfa` | MFA 方式の変更 (契約全体に効く) | 契約 | B: `{mfa_type: "none"\|"totp"}` — R: `{mfa_type}` | 200 / **403** (契約内管理者以外) / **400** (列挙外) | `同:97`、`hassan-v2-backend/controller/company.go:527-552` |

> **`mfa_type` の値域から `email` を落とす**: v2 の enum は `none` / `totp` / `email`
> (`hassan-v2-backend/db/schema.sql:66`) だが、**email OTP の実装は v2 に無い** (TOTP のみ:
> `hassan-v2-backend/usecase/mfa/` に TOTP の 3 UseCase しかない)。値を受け付けると
> 「設定できるが認証が成立しない」状態になる (BE-10)。**列そのものは v2 と同じ 3 値で持つ**
> ([../data-model.md](../data-model.md) §4.2 の「列を変えない」) が、**API は 2 値のみ受け付ける**。

### 2.4 系統: 社内管理者認証 (16 本)

**`X-Admin-Token`**。**社内管理者に MFA を課さない** (2026-08-10 のユーザー決定 = AA-D-22)。
したがって**この系統に「MFA 未検証で到達可」の区分は無く**、系統は **3 系統**になる ([../auth.md](../auth.md) §6.7)。
全 16 本が**契約スコープを持たない** (全契約横断が目的)。

**内訳は 4 群**: **①アカウントの回復・閲覧** (上 5 行。[../auth.md](../auth.md) §6.2 の例外 1 件とその付随機構) と
**②契約管理** (次の 5 行。**2026-08-25 の Q-10 = A で追加** = **AA-D-26**。**招待の再発行は 2026-08-26 に AA-D-27 で追加**) と
**③他の社内管理者アカウントの管理** (次の 3 行。**2026-08-29 のオーナー判断で追加** = **AA-D-29**。
**登録リンクの再発行 1 本は同日の AA-D-30 で追加**) と
**④自分自身の社内管理者アカウントの管理** (下 3 行。**2026-08-29 に追加** = **AA-D-33**)。
**②③は SuperAdmin 限定 (R-4)** — `admin` ロールでは **403**。判定は Controller が行う
(AA-D-19 の①ロール判定と同じ位置)。**③は v2 も 5 本すべてに `CheckSuperAdminRole()` を掛けている**
(`hassan-v2-backend/router/router.go:206-210`) ため、**②と違って C-16 の後退が無い** (AA-D-29)。
**①④はロール判定を課さない** — **`admin` ロールでも実行できる** (①は**2026-08-26 のオーナー判断**、
④は**v2 の実挙動どおり** — `hassan-v2-backend/router/router.go:202-204` は `AdminAuthRequiredMiddleware` のみで
`CheckSuperAdminRole()` を持たない = **AA-D-33**。
理由と代償は [../auth.md](../auth.md) §6.2 の「社内管理者のロールによる制限の範囲」が正)。
**したがって①④群の Controller に `IsSuperAdmin()` 相当の判定を置かない** —
①④群の固有ステータス列に **403 が無い**のはこの決定の帰結であり、書き漏れではない。
**④の対象は常に呼び出し元本人**であり、**path param もボディの ID も受け取らない** (JWT の
`admin_account_id` から解決する。**v2 はボディの `id` で対象を指定しており氏名変更に所有権検証が無い** = **V2-D7**)。

| メソッド | パス | 概要 | 主な入出力 | 固有ステータス | 移植元 |
|---|---|---|---|---|---|
| GET | `/admin/me` | 自分 (社内管理者) の情報 | R: `{id, name, email, admin_auth_role: "super_admin"\|"admin"}` | 200 | `hassan-v2-backend/router/router.go:196` |
| GET | `/admin/accounts` | **全契約横断**のアカウント検索 (ロック状態・会社名つき) | Q: `keyword` (会社名・氏名・メール) / `is_locked` (任意) / `limit` / `offset` — R: `{items: AdminAccountView[], total_count}` | 200 / 400 | `同:216`、`hassan-v2-backend/db/queries/account.sql:86-120` |
| DELETE | `/admin/accounts/{account_id}/lock` | ロック解除 (**解除専用。ロックは持たない**) | R: `AdminAccountView` | 200 / **404** (不存在) | `同:211`、`hassan-v2-backend/usecase/admin_account/unlock_account_by_admin.go:25-33` |
| POST | `/admin/accounts/{account_id}/mfa/reset` | **一般アカウント**の TOTP リセット (全契約横断。AA-Q2) | R: なし | 204 / **404** | `同:217`、`hassan-v2-backend/controller/account.go:1046-1082` |
| GET | `/admin/admins` | 社内管理者の一覧 | Q: `limit` / `offset` — R: **`{items: InternalAdminView[], total_count}`** (§2.5。**`password_registered` を含む** — 一覧が発行状態の表示と再発行ボタンの判断材料になる = R-AA-32② / §7.3 の UT #15。2026-08-29 に `{id, name, email, admin_auth_role}` から是正した) | 200 | `同:205`、`hassan-v2-backend/controller/admin_account.go:90`。**`mfa_registered` を返さない** (AA-D-22)。**`password_registered` は v2 に無い v3 の追加** (AA-D-30⑥) |
| POST | `/admin/contracts` | **契約の新規作成** — `contracts` + 代表者 `accounts` (パスワード無し・`is_completed=false`) + `companies` + 招待リンクを**1 トランザクションで作り**、代表者へ招待メールを送る (AA-D-26) | B: `{company_name, num_of_members, start_date, end_date, representative_name, representative_email, division}` — R: `AdminContractView` | **201** / **403** (SuperAdmin 以外) / 400 (日付形式・メール形式・`num_of_members` の範囲) / **409** (代表者メールが既存アカウントと重複) | `同:220`、`hassan-v2-backend/usecase/company/create_company_for_admin.go:56-155` |
| GET | `/admin/contracts` | **契約の一覧** (会社名・代表者・期間・人数つき) | Q: `keyword` (会社名・代表者名・メール) / `limit` / `offset` — R: `{items: AdminContractView[], total_count}` | 200 / **403** (SuperAdmin 以外) / 400 | `同:215`、`hassan-v2-backend/controller/company.go:215` |
| GET | `/admin/contracts/{contract_id}` | 契約の詳細 | R: `AdminContractView` | 200 / **403** (SuperAdmin 以外) / **404** (不存在) | `同:218`、`hassan-v2-backend/controller/company.go:244` |
| PUT | `/admin/contracts/{contract_id}` | 契約の更新 (会社名・人数・期間・代表者・部署)。**代表者メールを変更したとき、代表者が未サインアップ (`accounts.is_completed = false`) なら `accounts.email` も同一トランザクションで追随させる** (**2026-08-26 追加 = AA-D-28**) | B: 作成と同じ項目 — R: `AdminContractView` | 200 / **403** (SuperAdmin 以外) / 400 / **404** / **409** (新しい代表者メールが既存アカウントと重複。AA-D-28) | `同:221`、`hassan-v2-backend/controller/company.go:318` |
| POST | `/admin/contracts/{contract_id}/signup-links` | **代表者への招待リンクの再発行・再送** (**2026-08-26 追加 = AA-D-27**)。**未使用リンクを失効させてから発行する** (§2.3.2 の再送と同じ手続き) | **B: なし** — 宛先は `contracts.representative_email` から引く。R: `{expires_at}` (**トークンは応答に含めない**) | **201** / **403** (SuperAdmin 以外) / **404** (契約が不存在) / **409** (代表者が既にサインアップ済み) | v2 に相当機能なし (v2 は平文トークンを DB から復元できたため必要が無かった — AA-D-27) |
| POST | `/admin/admins` | **社内管理者アカウントの作成** (**2026-08-29 追加 = AA-D-29**)。**パスワードは設定せず、登録リンクを 1 トランザクションで発行して本人へメールする** (**2026-08-29 の AA-Q15 = (c) で方式が確定 = AA-D-30**。応答に秘密を含めない) | B: `{name, email, admin_auth_role}` (**`language_type` を受け取らない** = AA-Q4) — R: `InternalAdminView` (§2.5) | **201** / **403** (SuperAdmin 以外) / **400** (メール形式・`admin_auth_role` が列挙外) / **409** (`name` または `email` が既存の社内管理者と重複 — v2 も `admin_accounts.name` / `email` の両方が UNIQUE。`hassan-v2-backend/db/schema.sql:54-55`) | `hassan-v2-backend/router/router.go:206`、`hassan-v2-backend/usecase/admin_account/create_admin_account.go:50-110` (**`:90`-`:110` の登録リンク発行とメール送信も移植する** = AA-D-30) |
| POST | `/admin/admins/{admin_account_id}/password-registrations` | **パスワード登録リンクの再発行・再送** (**2026-08-29 追加 = AA-D-30**)。**未使用リンクを失効させてから発行する** (§2.3.2 / AA-D-27 の再送と同じ手続き)。**メール送信失敗時の唯一の回復手段**であり、**本人がパスワードを忘れたときの回復手段でもある** | **B: なし** — 宛先は `admin_accounts.email` から引く。R: `{expires_at}` (**トークンは応答に含めない**) | **201** / **403** (SuperAdmin 以外) / **404** (不存在) | v2 に相当機能なし (v2 は平文トークンを DB から復元できたため必要が無かった — AA-D-27 と同じ構図) |
| PUT | `/admin/admins/{admin_account_id}` | **他の社内管理者アカウントの更新** (氏名・メール・ロール。**2026-08-29 追加 = AA-D-29**)。**パスワードは扱わない** (本人のパスワード変更は下の④ = AA-D-33) | B: `{name, email, admin_auth_role}` — R: `InternalAdminView` (§2.5) | 200 / **403** (SuperAdmin 以外) / **400** / **404** (不存在) / **409** (`name` / `email` の重複) | `同:209`、`hassan-v2-backend/usecase/admin_account/update_admin_account_details.go:28-40` (**対象 ID をボディからパスへ** = AA-D-3) |
| PUT | `/admin/admins/me` | **自分の氏名の変更** (**2026-08-29 追加 = AA-D-33**)。**対象は JWT の `admin_account_id`** (ボディ・パスで対象を受け取らない = V2-D7 の解消)。**`admin` ロールでも実行可** (R-4 の対象外) | B: `{name}` — R: `InternalAdminView` (§2.5) | 200 / **400** (空・長さ) / **409** (`name` が他の社内管理者と重複。`hassan-v2-backend/db/schema.sql:54`) | `hassan-v2-backend/router/router.go:202`、`hassan-v2-backend/usecase/admin_account/update_admin_account_name.go:24-28` (**ボディの `id` で対象を指定する形は移植しない** = V2-D7)。**応答本文は v3 の追加** (v2 は `success(c)` の空応答 — `hassan-v2-backend/controller/admin_account.go:295`) |
| PUT | `/admin/admins/me/email` | **自分のメールアドレスの変更** (**2026-08-29 追加 = AA-D-33**)。**現在のパスワードの提示が必要** (v2 と同じ) | B: `{new_email, password}` — R: `InternalAdminView` (§2.5) | 200 / **400** (パスワード不一致 `AU-C-00004`。**分類 C** = §3.1.1。AA-D-17 / メール形式) / **409** (既に使われている) / **429** (AA-D-10) | `同:203`、`hassan-v2-backend/usecase/admin_account/update_admin_account_email.go:27-42` |
| PUT | `/admin/admins/me/password` | **自分のパスワードの変更** (**2026-08-29 追加 = AA-D-33**)。**漏洩を疑ったときに本人が即座に変えられる唯一の経路** | B: `{old_password, new_password, confirmed_new_password}` — R: なし | 204 / **400** (旧パスワード不一致 `AU-C-00004` [**分類 C**。AA-D-17] / 確認不一致・強度違反 [バリデーション。別コード]) / **429** (AA-D-10) | `同:204`、`hassan-v2-backend/usecase/admin_account/update_admin_account_password.go:27-45` (**`confirmed_new_password` の検証は v3 の追加** — v2 の DTO は 2 項目のみ `hassan-v2-backend/controller/dto/admin_account.go:75-79`。§2.3.1 の `PUT /accounts/me/password` に揃える) |

> **②契約管理を `/admin/companies` (v2 のパス) にしない理由** (AA-D-26):
> v3 で作る主体は **`contracts`** であり、`companies` は契約に従属して同一トランザクションで作られる。
> v2 のパス名は「会社」と「契約」を同一視しており (`DELETE /admin/companies/{contract_id}` のように
> **パスの語と path param が食い違っている**)、**契約内ユーザー向けの `GET /company` (§2.3.3) とも紛らわしい**。
> **`companies` 行を契約作成と同時に作るのは AA-D-14 の前提を保つため** — 同判断は
> 「行が無い = 移行の失敗なので `PUT /company` は upsert せず 404 で観測する」ことを根拠にしており、
> **行を作る経路を契約作成 1 本に閉じることでこの前提が新規契約でも成り立つ**。
>
> **契約の削除 (`同:219`) は引き続き対象外** — v2 は `ON DELETE CASCADE` の物理削除だが、
> **メンバーですら AA-D-13 で「削除せず無効化」に変えた**ため、契約単位の不可逆な物理削除だけが残るのは
> 一貫しない。契約の終了は `end_date` の更新で表す。必要になったら AA-D-13 と同じ形 (無効化列) で別途決める。
>
> **削除した 3 本と、その根拠** (2026-08-10 = AA-D-22):
> `POST /admin/mfa/totp/generate` / `POST /admin/mfa/totp/verify` / `POST /admin/admins/{admin_account_id}/mfa/reset`。
> **いずれも v2 に実体が無い** — [settings.md](settings.md) §5 の移植チェックリストで移植元に挙がっていたのは
> **ユーザー側の `POST /mfa/totp/generate` / `verify` / `POST /accounts/mfa/reset`** (`hassan-v2-backend/router/router.go:231-233`, `:83`) であり、
> **社内管理者用のエンドポイントは v2 に存在しない**。したがって削除は **C-16 (v2 にある操作は落とさない) に抵触しない**。
> **`GET /admin/admins` は残す** — v2 に実体があり (`同:205`)、C-16 の対象。ただし応答から `mfa_registered` を落とす。
> **再開する場合の入口**: `admin_mfa_configs` の定義と系統の 4 分割を戻すこと。§6.1 の AA-Q12 に残す。

### 2.5 レスポンスオブジェクト (暫定 — [../data-model.md](../data-model.md) §4.2 に従う)

```json
// Account (GET /accounts/me, GET /accounts, GET /accounts/{account_id})
{
  "id": "3f1c…", "contract_id": "9ab2…",
  "name": "森下 太郎", "email": "taro@example.com",
  "auth_role": "admin",                       // "admin" | "member" (v2 の auth_role_id 1/2 の表現)
  "division": "技術開発本部", "role": "リードエンジニア",
  "icon_url": "https://…?X-Amz-Signature=…",  // 署名付き URL (AA-D-16)
  "icon_url_expires_at": "2026-07-31T12:00:00Z",
  "is_completed": true,                       // サインアップ (パスワード設定) 済みか
  "mfa_registered": true,                     // TOTP を登録・検証済みか
  "is_locked": false, "locked_at": null,
  "created_at": "2026-04-01T00:00:00Z", "updated_at": "2026-07-30T09:00:00Z"
}
```

> **API 名と DB 列名が食い違う唯一の箇所 (明示する)**: **`is_locked` = `accounts.last_locked_at IS NOT NULL`
> の導出値** / **`locked_at` = `accounts.last_locked_at` の値そのもの** (`hassan-v2-backend/db/schema.sql:42`。
> 列名は v3 でも変えない — [../data-model.md](../data-model.md) §4.2)。**`is_locked` を列として持たない**
> (二重管理になり、解除時に一方だけ更新される余地を作らない)。

```json
// SignInResult (POST /accounts/signin, POST /accounts/signup)
{
  "token": "<JWT>", "expires_at": "2026-08-07T09:00:00Z",
  "account": { "id": "3f1c…", "contract_id": "9ab2…", "name": "森下 太郎",
               "email": "taro@example.com", "auth_role": "admin",
               "icon_url": "https://…", "icon_url_expires_at": "2026-07-31T12:00:00Z" },
  "company_name": "アイリオ株式会社",
  "mfa": { "required_type": "totp", "registered": false, "verified": false }
}
```

```json
// AdminSignInResult (POST /admin/signin)
{
  "token": "<JWT>", "expires_at": "2026-08-07T09:00:00Z",
  "admin_account": { "id": "b71e…", "name": "運用担当", "email": "ops@aillio.io",
                     "admin_auth_role": "super_admin" }
}
// ⚠️ 2026-08-10 (AA-D-22): `mfa` を返さない。社内管理者に MFA が無いため
```

```json
// AdminAccountView (GET /admin/accounts) — 社内管理者向け。会社名を含む
{
  "id": "3f1c…", "contract_id": "9ab2…", "company_name": "アイリオ株式会社",
  "name": "森下 太郎", "email": "taro@example.com", "auth_role": "member",
  "is_completed": true, "mfa_registered": true,
  "is_locked": true, "locked_at": "2026-07-30T08:12:00Z",
  "created_at": "2026-04-01T00:00:00Z", "updated_at": "2026-07-30T09:00:00Z"
}
```

```json
// InternalAdminView (§2.4 の③④、および `GET /admin/admins` の items。1 形に統一する)
{
  "id": "b71e…", "name": "運用担当", "email": "ops@aillio.io",
  "admin_auth_role": "super_admin",           // "super_admin" | "admin"
  "password_registered": false,               // 本人がパスワードを設定済みか (AA-D-30⑥)
  "created_at": "2026-04-01T00:00:00Z", "updated_at": "2026-07-30T09:00:00Z"
}
// `password_registered` は列ではなく導出値 — **`register_admin_password_requests` に当該
// `admin_account_id` の行が 1 件も無いこと**。行は受諾成功時に削除される
// (v2 も同じ: `hassan-v2-backend/usecase/admin_account/register_password.go:51-54`) ため
// 「行の存在 = 未設定」が厳密に成り立つ。**期限切れ行を掃除しない**ことが前提 (AA-D-30 の代償 iii)
// ⚠️ `mfa_registered` を返さない (AA-D-22)。`language_type` を返さない (AA-Q4)
// ⚠️ v2 の `auth_role_id` (一般ユーザー側の role 区分。作成時に固定値 1 を入れている —
//    `hassan-v2-backend/usecase/admin_account/create_admin_account.go:52-53`) は応答に出さない。
//    社内管理者の権限は `admin_auth_role` だけが決めるため、2 つ返すと読み手がどちらを見るか分かれる
```

> **`POST /admin/admins` の 201 応答も `InternalAdminView` である** (**2026-08-29 の AA-D-30 で
> `InternalAdminCreated` を廃止した**)。旧版は `initial_password` (サーバ生成の平文) を 201 に 1 度だけ載せる形
> だったが、**AA-Q15 = (c) の回答で「v2 と同じパスワード登録リンク方式」に切り替わった**ため、
> **本書の応答オブジェクトに秘密文字列を含む型は 1 つも無い** (AA-D-6②)。
> 登録リンクの発行系 2 本 (`POST /admin/admins`・`POST /admin/admins/{admin_account_id}/password-registrations`)
> は §2.3.2 の招待発行と同じく **`{expires_at}` だけを返す** (前者は `InternalAdminView` に含めず別項目として
> `password_registration_expires_at` を持たせない — **有効期限は再発行 API の応答と登録リンクのメール本文で足りる**)。

```json
// AdminContractView (§2.4 の契約管理 4 本。AA-D-26)
{
  "contract_id": "9ab2…", "company_name": "アイリオ株式会社",
  "num_of_members": 20, "start_date": "2026-09-01", "end_date": "2027-08-31",
  "representative_name": "森下 太郎", "representative_email": "taro@example.com",
  "division": "経営企画部",
  "active_account_count": 7,
  "created_at": "2026-04-01T00:00:00Z", "updated_at": "2026-07-30T09:00:00Z"
}
// ⚠️ `language_type` を返さない (AA-Q4 = 日本語のみ。列は `DEFAULT 'ja'` のまま触らない)
// `active_account_count` は `num_of_members` (上限) に対する現在の在籍数 (`deactivated_at IS NULL`)。
// **§2.4 の②契約管理 4 本すべてが返す** — 作成直後は代表者 1 名なので必ず 1 になる。
// (**2026-08-25 訂正**: 旧記述は「一覧・詳細でのみ返す」だったが、§2.4 が POST の応答も
//  AdminContractView と定めているため自己矛盾していた。実装リポ #116 の S-7 レビューで検出)
// 上限判定そのものは `POST /accounts` 側が持つ (§2.3.2 の 409)
```

**`SignInResult` が [../frontend.md](../frontend.md) §5.2.2 の是正要求 (§16.2-6) への回答である** —
同節が「セッションに載せる属性の出所はサインイン応答の 1 経路」とし、**`role` が v2 の応答に無い**ことを
Task-3i への是正要求として出している。本書は `account.auth_role` / `mfa.required_type` /
`mfa.verified` / `account.id` / `account.name` / `company_name` の**すべてを応答に含める**。

### 2.6 [settings.md](settings.md) §5 (移植チェックリスト 18 行) との対応

**18 行すべてに対応がある。下の表が対応の全件である** (§6 に検証欄は無い。以前の
「機械照合の結果は §6 の検証欄」という記述は参照先が存在しなかったため削除した)。

> **本表がカバーしていない v2 のエンドポイントが 2 組ある (2026-08-29)**: ①社内管理者の
> パスワード登録 (`hassan-v2-backend/router/router.go:199-200`) ②**社内管理者の自己管理 3 本**
> (`同:202-204`。**2026-08-29 に AA-D-33 で移植対象に入った**)。**どちらも §2.1 / §2.4 に移植先を作ったが**
> ([settings.md](settings.md) §5 の元表に行が無いため) 本表にも行が無い。
> **両方へ同時に 2 行足すことを §5 の R-AA-34 で起票した** — `scripts/check-endpoint-mapping.sh` の
> 検査①が**両者の行数一致**を見るため、片方だけ足すと `make check` が落ちる。

**照合の範囲 (主張を実施した範囲に限定する)**: 突き合わせたのは
[settings.md](settings.md) §5 の**各行 (v2 のエンドポイント) と本書の対応先**であり、
**同書が併記している出典の行番号は照合していない** — 実際に row 11 (`POST /admin/signin` の `同:194`) が
誤っていた (正 = `:195`)。訂正は §5 **R-AA-3⑤** で要求する。
**行数・件数は機械照合されている** (2026-07-31。§5 **R-AA-22** = 実施済み): `scripts/check-endpoint-mapping.sh`
(`make check-endpoint-mapping` / `make check` に組み込み済み) が **[settings.md](settings.md) §5 の行数 == 本表の行数**、
および **§2 のエンドポイント実数 == [README.md](README.md) §3 の総覧値** を**照合 5 件**で見る
(**総覧値をここに転記しない** — 2026-08-10 の AA-D-22 / AA-D-13 改訂で本数が動いたため。実測は `make check-endpoint-mapping` の出力が正 = DR-9)。
**照合していないのは出典の行番号のみ** (上段のとおり)。**未照合の件数が 2 つ残る**: §3.7 の**レート制限 14 本**と
§3.1.1 の **11 コード**は同スクリプトの対象外で人手一致のまま — 追加要求は §5 **R-AA-25**。

| # | §5 の行 (v2 のエンドポイント) | 本書の対応 | 備考 |
|---|---|---|---|
| 1 | サインイン `POST /accounts/signin` | §2.1 `POST /accounts/signin` | 応答項目を拡張 (§2.5) |
| 2 | サインアップ `POST /accounts/signup` / `GET /accounts/signup-links/:id` | §2.1 `POST /accounts/signup` / `POST /accounts/signup-links/lookup` | **入力から `email` を除去** (V2-D1)・**トークンをボディへ** (AA-D-4) |
| 3 | パスワードリセット `POST /accounts/reset-password` / `POST /accounts/reset-password/:hash` | §2.1 `POST /accounts/reset-password` / `.../confirm` | 応答を 204 固定 (V2-D6)・トークンをボディへ |
| 4 | 自分のアカウント `GET /accounts/me` / `PUT /accounts` | §2.3.1 `GET /accounts/me` / `PUT /accounts/me` | パスを `/me` に統一 (AA-D-2) |
| 5 | メール・パスワード変更 `PUT /accounts/email` / `PUT /accounts/password` | §2.3.1 `PUT /accounts/me/email` / `PUT /accounts/me/password` | 同上 |
| 6 | アイコン `POST` / `DELETE /accounts/icon` | §2.3.1 `POST` / `DELETE /accounts/me/icon` | **署名付き URL 方式へ** (AA-D-16) |
| 7 | 契約内メンバー一覧・取得 `GET /accounts` / `GET /accounts/:id` | §2.3.2 の同 2 本 | **ロック状態を追加** + ページネーション追加 (V2-F14) |
| 8 | メンバー作成・権限変更・削除 `POST /accounts` / `PUT /accounts/admin` / `DELETE /accounts/:id` | §2.3.2 `POST /accounts` / `PUT /accounts/{account_id}` / `DELETE /accounts/{account_id}` | 対象を path param へ (AA-D-3)・削除は 202 の非同期 (AA-D-13) |
| 9 | 招待リンク発行 `POST /accounts/signup-links` | §2.3.2 `POST /accounts/{account_id}/signup-links` | email 指定 → account_id 指定 (AA-D-3)・**単一有効リンク** (AA-D-5) |
| 10 | ロック解除・MFA リセット `POST /accounts/unlock` / `POST /accounts/mfa/reset` | §2.3.2 `DELETE /accounts/{account_id}/lock` / `POST /accounts/{account_id}/mfa/reset` (+ **新設** `POST …/lock`) | V2-D4 の解消 (AA-D-11) |
| 11 | 社内管理者サインイン `POST /admin/signin` | §2.1 `POST /admin/signin` | 応答に MFA 状態を追加 (P-5) |
| 12 | 社内管理者によるロック解除 `POST /admin/accounts/unlock` | §2.4 `DELETE /admin/accounts/{account_id}/lock` | **解除専用**。到達に必要な `GET /admin/accounts` を追加 (§5 の是正要求 R-AA-3) |
| 13 | 社内管理者の MFA 登録・検証 | **作らない** (AA-D-22) | **v2 に実体が無い** — §5 の移植元欄はユーザー側 `同:231-232` を指しており、社内管理者用のエンドポイントは v2 に存在しない。したがって C-16 に抵触しない。`admin_mfa_configs` も作らない |
| 14 | 社内管理者の MFA リセット (SuperAdmin のみ) | **作らない** (AA-D-22) | 同上 (移植元はユーザー側 `同:83`)。**社内管理者が MFA を持たないためリセット対象が無い** |
| 15 | MFA (TOTP) `POST /mfa/totp/generate` / `verify` / `reset` | §2.2 の 2 本 + §2.3.1 の `POST /mfa/totp/reset` | **`reset` は MFA 検証済み必須**に変更 (AA-D-8) |
| 16 | 契約情報 `GET /contracts` | §2.3.3 `GET /contract` | `sharing_settings` を落とす (AA-D-15)。パスは `/me` を付けない単数形 (AA-D-25) |
| 17 | 会社情報 `GET` / `POST` / `PUT /companies` / `PUT /companies/mfa` | §2.3.3 `GET` / `PUT /company` / `PUT /company/mfa` | **POST を作らない。更新は `PUT` 1 本で、行が無ければ 404** (AA-D-14)。パスは `/me` を付けない単数形 (AA-D-25) |
| 18 | 企業ミッション `GET` / `POST` / `PUT` / `DELETE /company-mission` | **作らない** (AA-D-1)。ミッションはテーマが持つ ([themes.md](themes.md) §2.1 の `mission`) | **AA-Q1=a (2026-07-31 回答済み。移植しない)**。既存データの扱いは R-AA-6 が引き継ぐ |

### 2.7 本書で作らないもの (理由と先送り先)

| 対象 | 判断 | 理由 |
|---|---|---|
| `GET /companies/genai` (`hassan-v2-backend/router/router.go:94`) | **本書の対象外** | 生成 AI で会社情報を作る経路であり、**Dify 廃止 (C-9) の影響を受ける**。移行先の判定は [../llm-migration.md](../llm-migration.md) が担う ([settings.md](settings.md) §5 の注と同じ扱い)。**移植する場合も LLM 呼び出しは `gateway/` 経由が必須** (O-2) |
| ~~社内管理者アカウントの作成・権限変更 (`同:206`, `:209`)~~ | **§2.4 の③として対象に入った** (2026-08-29) | **旧記述は「対象外。[../auth.md](../auth.md) §6.2 が『API を作らず移行スクリプトで投入』と確定済み」だった** — その根拠は「**v2 でも実質使われていない**」ではなく「**社内管理者機能が実質全部入りになる**」という範囲の判断だったが、**v2 フロントエンドに現に配線された画面がある**ことが実装リポ hassan-v3 の issue #181 の調査で判明した (作成 = `hassan-v2-frontend/src/features/admin/admin-setting/components/admin-account-form.tsx:39` → `actions/create-admin-account.ts:7` の `postAdminAccounts` / 更新 = 同 `admin-account-edit-form.tsx:44` → `actions/update-admin-account-details.ts:9` の `putAdminAccountsDetails`。画面はヘッダーナビ「アドミン設定」から到達可能 — `hassan-v2-frontend/src/components/layouts/header/admin-header-link.tsx:58`-`:63` (**`SUPER_ADMIN_HEADER_ITEMS` のみ**。`:62` は同項目の `pathKey` 行であり、エントリの先頭ではない — 2026-08-29 に 1 行のズレを訂正))。**C-16 (v2 にある操作は落とさない) の対象**である = **AA-D-29** |
| **社内管理者アカウントの削除 (`同:208`) と権限ロール一覧 (`同:210`)** | **対象外** | **v2 フロントエンドに呼び出し元が無い** (2026-08-29 実測): 削除は生成クライアント (`hassan-v2-frontend/src/generated/admin-account/admin-account.ts`) にしか現れず、ロール一覧はラッパー (`hassan-v2-frontend/src/features/admin/(shared)/actions/get-admin-accounts-auth-role.ts`) が**どこからも import されていない死にコード**である。**「配線されていない実装を手本にしない」** (`.claude/skills/designing-development-plans/SKILL.md` ①) ため C-16 の対象に数えない。**削除は AA-D-13 (メンバーは削除せず無効化) / 本表の契約削除と同じ理由でも採らない** — v2 の `DELETE /admin/accounts/:id` は物理削除であり、不可逆な削除だけが社内管理者に残るのは一貫しない。**ロール一覧は値域が 2 値 (`super_admin` / `admin`) の固定列挙**であり、FE が定数で持てば足りる。**先送り先**: 必要になったら AA-D-29 と同じ形 (v2 の配線を確認してから) で §2.4 に足す |
| ~~社内管理者の**パスワード変更・氏名変更・メール変更** (自分自身。`同:202-204`)~~ | **§2.4 の④として対象に入った** (2026-08-29 = **AA-D-33**) | **旧記述は「対象外。①パスワードは登録リンクの再発行で、②氏名・メールは SuperAdmin の `PUT /admin/admins/{admin_account_id}` で代行できるので代替経路がある」だった** — **この判定は 2 点で誤っていた**: **(1) v2 フロントエンドに現に配線された 3 画面がある** (`hassan-v2-frontend/src/app/admin/settings/account/{name,email,password}/edit/page.tsx` → `src/features/admin/settings/(routes)/account/components/admin-account-name-edit-form.tsx:44` / `admin-account-email-edit-form.tsx:60` / `admin-account-password-edit.tsx:65` → `actions/update-admin-account-{name,email,password}.ts:9` が `putAdminAccountsName` / `putAdminAccountsEmail` / `putAdminAccountsPassword` を呼ぶ。**対象は `getAdminMe()` の結果の `me.id`** = 自分自身。入口はヘッダーナビの「設定」— `hassan-v2-frontend/src/components/layouts/header/admin-header-link.tsx:31`-`:36` (`admin` ロール向け `ADMIN_HEADER_ITEMS`) と `:64`-`:69` (`SUPER_ADMIN_HEADER_ITEMS`)、`PATH.ADMIN_SETTING_ACCOUNT` = `hassan-v2-frontend/src/lib/path.ts:47`)。**削除・ロール一覧 (死にコード) とは状態が違う**ので C-16 の対象である **(2) 主張した代替経路が `admin` ロールでは成立しない** — `PUT /admin/admins/{admin_account_id}` は AA-D-29③ で **SuperAdmin 限定 (R-4)** にしたため、**`admin` ロールの社内管理者は自分の氏名・メールを変える手段が一切無くなる** (v2 は `hassan-v2-backend/router/router.go:202-204` にロール判定が無く本人が変更できた)。パスワードも「漏洩を疑ったときに本人が即座に変えられない」状態が残る。**判断は AA-D-33** |
| 社内管理者向けの利用状況・CSV 出力 (`同:222-223`) | **対象外** | [../auth.md](../auth.md) §6.2 が本増分の対象外と確定。利用量の可視化は**運用者向け**として [../observability.md](../observability.md) §4.2 / §6.1 が扱う ([settings.md](settings.md) §4 の D-ST-5 と同じ扱い) |
| **契約の削除 (`同:219`)** | **対象外** | v2 は `ON DELETE CASCADE` の物理削除だが、**メンバーですら AA-D-13 で「削除せず無効化」に変えた**ため、契約単位の不可逆な物理削除だけが残るのは一貫しない (AA-D-26)。契約の終了は `PUT /admin/contracts/{contract_id}` の `end_date` で表す |
| ~~契約の作成・一覧・詳細・更新 (`同:215`, `:218`, `:220-221`)~~ | **§2.4 の②として対象に入った** (2026-08-25) | **旧記述は「対象外。契約は移行スクリプトで投入する」だった** — 根拠は §6.3 の仮定 2 (作成経路は移行スクリプトのみ) であり、同仮定が明記していた後続条件「**v3 で新規契約を獲得する運用が必要になると本増分の対象に戻る**」が発火した (Q-10 = A。**AA-D-26**)。**既存契約の移送 ([../data-model.md](../data-model.md) §6.4 / §6.5) は引き続き必要**で、新規作成 API とは並存する |
| `POST /accounts/{account_id}` 相当の「管理者がパスワードを直接設定する」経路 | **作らない** | v2 に無い (`CreateFullAccount` は社内管理者経路の DTO のみ — `hassan-v2-backend/controller/dto/account.go:18-27`)。管理者が他人のパスワードを知る経路を作らない |
| ログアウト (revoke) API | **作らない** | [settings.md](settings.md) §2 で決着済み (ST-Q4)。FE のトークン破棄 + 手動ロックが担う |
| 言語切替 (`language_type` の API 露出) | **作らない** | v2 は Host で日英を切り替える (V2-F11) が、**v3 のホスト名は環境ごとに 1 つ** ([../infrastructure.md](../infrastructure.md) INF-J)。メールは日本語のみ。**仮定として §6 に記載** |

---

## 3. 設計判断

### 3.1 判断表

| # | 論点 | 採用案 | 却下案と理由 |
|---|---|---|---|
| **AA-D-1** | **企業ミッション API の扱い** | **移植しない**。ミッションは**テーマが持つ** (`themes.mission` — [themes.md](themes.md) §2.1) | (a) v2 どおり `/company-mission` を移植: **[../data-model.md](../data-model.md) に `company_missions` 相当のテーブルが無い** (§4.2 の対象 10 テーブルにも §4.1.1 の機能テーブル 40 件にも無い)。加えて v2 の用途は「発散セッション作成時の既定ミッション」(V2-F16) であり、v3 はテーマごとに `mission` を持つため**同じ知識が 2 箇所になる** (BE-1 / BE-2 の型)。(b) 移行して読み取り専用で残す: 読み手が無い (BE-10)。**既存データの写像 (v2 の既定ミッション文をテーマ作成の初期値にするか) は [../data-model.md](../data-model.md) DM-A2 の対象に追加要求する** (§5 R-AA-6)。**AA-Q1=a で確定** (2026-07-31 ユーザー回答。§6.1) |
| **AA-D-2** | **パス体系** | **v2 の `/accounts` `/mfa` `/contracts` `/companies` `/admin` を踏襲**し、**認証ユーザー自身のレコードを指す操作**だけ `/me` 配下に集める (`PUT /accounts/me/email` 等)。**契約・会社は対象外** — 適用範囲の訂正は AA-D-25 | (a) `/auth/*` に集約: 系統とパス接頭辞が 1:1 になり CI 検査が読みやすくなるが、**[../auth.md](../auth.md) §6.7 のホワイトリストが既に v2 のパスで系統を宣言している** (SSOT 側の書き換えを伴う。**書き換えは AA-D-4 の 2 本について不可避なので §5 R-AA-15 で起票し、SSOT の向きを AA-D-20 で確定した**) うえ、`/accounts/signin` は v2 の運用者・実装者に既知の形。**判断が割れたら v2 に寄せる** (ルート `CLAUDE.md`)。(b) v2 の `PUT /accounts` (自分の更新) をそのまま使う: **コレクションへの PUT が「自分 1 件の更新」を意味する**形で、`PUT /accounts/{account_id}` (管理者操作) と並ぶと読み手が取り違える。v2 自身も回避のため `PUT /accounts/admin` という**動詞的パス**を足している (`hassan-v2-backend/router/router.go:70`) |
| **AA-D-3** | **操作対象の指定方法** | **対象アカウントは常に path param `{account_id}`**。ボディやクエリで `account_id` / `email` を受け取らない | (a) v2 の「ボディに `email`」(`hassan-v2-backend/controller/dto/account.go:155-157`): **越境の実例そのもの** ([../auth.md](../auth.md) §5-11)。(b) v2 の「ボディに `account_id`」(同 `:35-46`): 越境はしないが、**[README.md](README.md) §1.4 の機械検査 (`account_id` クエリ・パスパラメータ命名) がボディの中を見られない**ため、規約違反が検出できない。path param なら `{<単数リソース名>_id}` 検査と [../auth.md](../auth.md) §6.4 の②コンストラクタ (`NewAccountIDInContract`) の適用箇所が一目で分かる |
| **AA-D-4** | **秘密文字列 (招待トークン・リセットトークン) の受け渡し** | **URL (パス・クエリ) に置かず、必ずリクエストボディで受ける**。招待リンクの検証は読み取りだが **POST** (`/accounts/signup-links/lookup`) | (a) v2 の `GET /accounts/signup-links/:id` / `POST /accounts/reset-password/:hash`: **秘密が ALB のアクセスログ (S3) に平文で残る** — [../infrastructure.md](../infrastructure.md) §3.2 が prod で ALB アクセスログを有効にする決定を持つ。**アプリ側のログを直しても消えない** (v2 のリクエストログも `c.Request.RequestURI` を出す — `hassan-v2-backend/controller/middleware.go:44`)。結果として**ログ閲覧権限がアカウント乗っ取り能力になる**。(b) パスに置いたままログ側でマスクする: マスクの実装が漏れた瞬間に (a) に戻り、**漏れを検出する手段が無い**。(c) `GET` + `Authorization` ヘッダに載せる: 標準外の使い方で orval の生成にも乗らない。**メールに載る URL は FE の URL** (`/signup?token=…`) であり、FE がボディに詰め替えて BE を呼ぶ ([../frontend.md](../frontend.md) §11.1 の `(auth)` ルート) |
| **AA-D-5** | **招待の突合とリンクの有効数**、および**秘密文字列の格納形式** (④) | **①`POST /accounts/signup` は `email` を受け取らず、`signup_links.token_hash` → `(contract_id, email)` → `accounts` の 1 経路でアカウントを解決する** ②**1 アカウントにつき有効な招待リンクは 1 本**とし、発行時に未使用リンクを削除する ③**メールアドレス変更時も未使用リンクを削除する** **④秘密の格納 (2026-07-31 のレビュー重大 5 で追加。実装者に選ばせない 4 点)**: **(i) 生成** = `crypto/rand` で **32 バイト → base64url (パディング無し)**。**`id` (uuid) を秘密として使わない** — v2 は招待リンク ID 自体を秘密にしていた (V2-F2) が、`id uuid DEFAULT uuid_generate_v4()` は **DB 側 (uuid-ossp) の生成**であり、[../auth.md](../auth.md) §6.10-3 の CI 検査 (`math/rand` の import 検出) は**アプリ外の生成経路を見られない**ため「§6.10-1 を満たしているか」が判定不能になる。**(ii) 保存形** = **SHA-256 のダイジェストのみを保存し、平文を保存しない**。照合は**両テーブルとも `WHERE token_hash = $1`** のハッシュ一致。**pepper を使わない**のは入力が 32 バイトの乱数で辞書攻撃が成立しないため (**AA-D-21③ のメールアドレスとは入力空間が違う** — あちらは HMAC + pepper が要る)。**(iii) 列名** = **`signup_links` / `reset_password_requests` の両方を `token_hash text NOT NULL UNIQUE` に揃える** (`signup_links` は列自体の新設、`reset_password_requests` は **v2 の `hash text NOT NULL` からの改名** — `hassan-v2-backend/db/schema.sql:315`)。**起草時は「`hash` を据え置く。改名は §4.2 の変える点を増やすだけで得が無い」としたが、2026-07-31 に撤回した** — スキーマの SSOT である [../data-model.md](../data-model.md) §4.2 が**改名を採用済み**であり (採用理由「**列名で保存形が読める**」)、**同じ意味の列が 2 テーブルで別名 (`hash` / `token_hash`) になると sqlc の生成名と §3.5 のクエリ名が経路ごとに揺れる**。据え置きの利得 (「変える点」を 1 つ減らす) は、**改名が `ALTER TABLE ... RENAME COLUMN` 1 行で、かつ RL-2 (初期スキーマ投入) より前に確定するため移行コストが 0** であることで消える。**(iv) クエリ名を列名に合わせる** (§3.5 の `GetSignupLinkByTokenHash` / `GetResetPasswordRequestByTokenHash` / `DeleteSignupLinkByTokenHash`)。**スキーマ側の要求は §5 R-AA-21** | (a) v2 のまま: **V2-D1 (任意の未サインアップアカウントを乗っ取れる)** をそのまま持ち込む。(b) `signup_links` に `account_id` 列を足して直接引く: 突合はより単純になるが、[../data-model.md](../data-model.md) §4.2 の「v2 に無い列を足さない」方針への追加変更になり移行の写像が増える (`contract_id` の追加だけで DM-A4 の判断を要した)。**②を採る理由**: 複数の有効リンクを許すと、リンクの秘匿性が破れたときに「どれを失効させるか」の管理対象が増える。**②の担保は手続きだけに頼らない** — 発行は**1 トランザクション内で `DELETE` → `INSERT`** とし、さらに **`signup_links` に `UNIQUE (contract_id, email)` を要求する** (§5 R-AA-17)。手続きだけだと「再送」を同時に 2 回押したときに **delete → insert のレースで有効リンクが 2 本残る** (BE-11 と同型)。**③を採る理由**: リンクは `email` でアカウントを解決するため、変更後にリンクが宙に浮く (読む側と書く側の対 = BE-10)。**④の却下案**: (c) **平文で保存する (v2 の実態)**: v2 は `util.RandStringRunes(32)` の生成値を `reset_password_requests.hash` にそのまま入れている (`hassan-v2-backend/usecase/account/request_reset_password.go:59`, `:62`)。AA-D-4 は「秘密が ALB アクセスログに残ると**ログ閲覧権限がアカウント乗っ取り能力になる**」を理由に URL 配置を禁じたが、**同じ論法は DB 読み取り権限にも当てはまる** — 平文だと **DB スナップショット / バックアップの閲覧権限が、有効期限内の任意アカウントのパスワード設定能力**になる。(d) **`id` (uuid v4) を秘密として使い続ける (v2 方式)**: 列を足さずに済むが (i) のとおり生成経路が CI 検査の外に出るうえ、**uuid は URL・ログ・エラーメッセージに識別子として出やすい**ため「秘密である」という前提が運用で破れやすい。(e) **`signup_links` を改名して `token` 列にする**: 平文を連想させる名前になり、(ii) の決定が実装で崩れやすい |
| **AA-D-6** | **リセット・招待の応答と乱数** | **①要求は 204 固定** (アカウント不存在でも成功応答) ②**秘密文字列を応答に含める型を作らない** ③トークン生成は `crypto/rand` ([../auth.md](../auth.md) §6.10) ④**トークン不正・期限切れ・使用済みをすべて 404 に統一** | (a) v2 のまま (未登録は 400 `AccountNotFoundByEmail`): **メールアドレスの列挙が成立する** (V2-D6 / [../auth.md](../auth.md) §5-9)。(b) 期限切れだけ専用コードで返す (v2 の `ResetPasswordRequestExpired` — `hassan-v2-backend/usecase/account/reset_password.go:49-50`): **トークンが存在したことが判る**ため、総当たりの当たり判定に使える。ユーザーが取れる行動は「再発行」の 1 つだけなので、文言を分ける利得が無い。(c) `410 Gone` を使う: [README.md](README.md) §2.5 に無いコードを 1 本のためだけに増やす |
| **AA-D-7** | **`is_locked` を誰に見せるか** | **契約内の全メンバーに返す** (`GET /accounts` / `GET /accounts/{account_id}`) | (a) 契約内管理者にだけ返す: 同じ DTO が 2 形式になり orval の型が分岐する。v2 でも契約内メンバー一覧は全員に開いている (V2-F14) ため、**契約内のメンバー構成は既に相互可視**である。(b) v2 のまま返さない: **ロックされたことを管理者が知る経路が無く、解除操作に到達できない** ([../auth.md](../auth.md) §6.9 の「ロック状態の可視化」= BE-10 の読む側) |
| **AA-D-8** | **`POST /mfa/totp/reset` の到達条件** | **MFA 検証済みを必須**にする (MFA 未検証で到達できるルートは §2.2 の 2 本だけ) | (a) v2 のまま `/mfa` 配下すべてを未検証で開放 (V2-F7): [../auth.md](../auth.md) §6.7 が**パス前方一致の判定を却下済み**。加えて reset は**有効な TOTP コードを要求する**ため未検証状態で使う意味がない (コードを出せるなら verify できる)。(b) reset を廃止して「管理者にリセットしてもらう」のみにする: 端末を移す度に管理者を巻き込むことになり、v2 でできていた自己解決の経路を失う |
| **AA-D-9** | **資格情報エラーのステータス** | **「トークンを発行・昇格させるエンドポイント」の資格情報エラーだけを 401 + `CodedError` 本文**にする。対象は `POST /accounts/signin` / `POST /admin/signin` / `POST /mfa/totp/verify` の **3 本** (2026-08-10 の AA-D-22 で `POST /admin/mfa/totp/verify` が消滅し 4 → 3)。**認証済みセッションで本人確認のために添えた資格情報の不一致は 400** (AA-D-17)。**401 は「トークン自体の失効 (分類 T)」と「提示した資格情報の不一致 (分類 C)」の 2 分類**とし、FE が本文の `code` だけで機械判定できるようにする (**§3.1.1** が値域と判定規則の SSOT)。ロック・MFA 不一致は分類 C の専用コードで区別する ([../auth.md](../auth.md) §6.11-1) | (a) v2 の 400 (`hassan-v2-backend/controller/account.go:352-355`): [../frontend.md](../frontend.md) §9 が **400 を「フォームのフィールドエラー」**として扱うため、**サインインの「メールまたはパスワードが違います」はどちらのフィールドにも紐づかない** (AA-D-6 のマスクが目的なので紐づけてはいけない) のにフィールドエラーとして出る。加えて**バリデーション違反 (形式不正) と資格情報の誤りが同じステータスになり、O-4 の観測で区別するには結局コードが要る**。(b) 403: 認証されていないのだから 403 ではない。(c) **v2 の 500 (MFA 検証失敗 = V2-D2)**: 失敗が全部サーバエラーとして計上され、**総当たりが 500 の山として現れる** (O-4 の逆行)。(d) **401 のまま FE 側が「どのエンドポイントを叩いたか」で分岐する** (起草時の案): エンドポイントが増えるたびに FE が分岐表を更新することになり、**更新漏れが強制サインアウトとして現れる**。判定の入力を**応答本文の `code` 1 つ**に閉じる (§3.1.1)。**この判断は [README.md](README.md) §2.5 の「401 は本文なし」に対する明示の例外**であり、§5 の **R-AA-2a** ([../auth.md](../auth.md) §6.6 宛て) / **R-AA-2b** ([README.md](README.md) §2.5 宛て。実施済み) で SSOT へ是正要求を出す |
| **AA-D-17** | **認証済み経路で「本人確認のために添えた資格情報」が一致しないときのステータス** | **400 + `CodedError`**。対象は `PUT /accounts/me/password` の `old_password` / `PUT /accounts/me/email` の `password` / `POST /mfa/totp/reset` の `totp_code` の **3 本**。切り分け規則は「**そのエンドポイントの目的がトークンの発行・昇格なら 401 (AA-D-9)、それ以外 (認証済みの状態変更に本人確認を添えるもの) なら 400**」 | (a) **401 に統一する (起草時の採用案)**: 3 本とも**セッションを持つ経路**であり、[../frontend.md](../frontend.md) §9 の「401 → `/api/logout`」に流れると **TOTP を 1 文字打ち間違えただけで強制サインアウト**になる。§3.1.1 の分類 C で救えるが、**FE の共通層に「401 だが破棄しない」という例外経路を 3 本のためだけに常設する**ことになる。分類 C が必要なのは MFA 検証 2 本 (S2 セッションを持ちながら 401 を返さざるを得ない = トークン昇格そのもの) だけに絞れる。(b) **422 を使う**: [README.md](README.md) §2.5 に無いコードを増やす (AA-D-6 で `410 Gone` を却下したのと同じ理由)。(c) **403**: 権限の問題ではない。**AA-D-9 の却下 (a) との整合**: 却下 (a) が問題にしたのは「**どのフィールドにも紐づかない**マスク文言がフィールドエラーとして出る」ことであり、`old_password` / `password` / `totp_code` は**入力フィールドそのものに紐づく**ため同じ問題は起きない。O-4 の区別は §3.1.1 のコードで担保する |
| **AA-D-20** | **公開系統ホワイトリストの SSOT をどちらに置くか** ([../auth.md](../auth.md) §6.7 と本書 §2 が現状**双方向参照**) | **2 段に分ける**: **①系統の定義と判定機構・CI 検査の仕組み = [../auth.md](../auth.md) §6.7 が SSOT** / **②どのエンドポイントがどの系統に属するか (公開ホワイトリストの中身) = 本書 §2 の節構成が元表**。auth.md §6.7 は**個別パスを再掲せず本書を参照する** (差し替えは §5 R-AA-15 で要求) | (a) **auth.md §6.7 側にパスを列挙し続ける** (現状): エンドポイントの増減のたびに 2 箇所を直すことになり、**実際に AA-D-4 のパス変更 (`GET /accounts/signup-links/:id` → `POST /accounts/signup-links/lookup`、`POST /accounts/reset-password/:hash` → `.../confirm`) で乖離した**。CI 検査の入力が旧パスのままなので、①実装が旧パスを作るか②新パスが未宣言として落ちるかのどちらかになる。(b) **系統の定義ごと本書へ移す**: 認証系以外のドメイン ([themes.md](themes.md) / [assets.md](assets.md) 等) も系統に属するため、**認証設計の SSOT が 1 ドメインの API 仕様書に移る**。(c) **両方に書いて CI で一致を検査する**: 検査は書けるが、**2 箇所を同時に直す運用**が残る (DR-8 の温床)。**帰結**: 本書 §2.0 の「この節構成がホワイトリストの元表になる」は②の意味に限定され、P-6 (系統の SSOT = auth.md §6.7) と矛盾しない |
| **AA-D-19** | **403 と 404 の評価順序** | **①ロール判定 (R-1) → ②所有者条件による取得 (0 件なら 404) → ③不変条件ガード (R-3) の順に評価する**。したがって**一般メンバーが `{account_id}` を指定する管理者操作は、対象が自契約・他契約・不存在のいずれでも 403** になる (§3.1.2) | (a) **存在確認を先にする (404 優先)**: 「見えないリソースは常に 404」を徹底できるが、**ロール判定のためだけに Repository へ 1 往復増える**うえ、v2 は Controller でロールを見てから UseCase を呼ぶ (`hassan-v2-backend/controller/account.go:598` の削除経路 = V2-F12) ため実装順序を反転させることになる。**403 は対象の存在を示さない** (ロール不足を示すだけ) ので、404 を先に返す情報漏洩上の利得も無い。(b) **順序を決めず実装に委ねる**: [../auth.md](../auth.md) §6.6 の表は「他テナント = 404 / 権限不足 = 403」を並記するだけで**両方に当てはまる要求の答えにならず**、FE の分岐と §7.3 の UT が実装ごとに食い違う (DR-5) |
| **AA-D-18** | **`CodedError.code` の値域を本書に書くか** | **401 / 400 のうち「FE の分岐を決める」コードに限り、本書 §3.1.1 で値域と接頭辞規則を確定する** (それ以外のコードは実装リポの `constants` パッケージが SSOT のまま) | (a) [README.md](README.md) §1.2 (`:315`-`:317`) の「**本ディレクトリでは個別コードを列挙しない (二重管理の防止)**」をそのまま守る: **セッションを破棄するかどうかの判定が FE と BE の共有契約**であるにもかかわらず契約がどこにも書かれず、**両側が別々に推測する** (BE-8「schema と handler の乖離」と同型)。二重管理のコストより、破棄判定を取り違える害 (強制サインアウト / 無効セッションのループ) が大きい。(b) 接頭辞規則だけ書き、コードは列挙しない: 実装リポが接頭辞を付け間違えても検出できない。**§3.1.1 の表を CI 検査の入力にする** (D-2) ことで機械照合できる形にする。**代償**: 実装リポでコードを追加・改名したら本書 §3.1.1 も同じ差分で直す必要がある (§7.2 に明記) |
| **AA-D-10** | **認証済み経路のレート制限** | **①`POST /mfa/totp/verify`** (**`POST /admin/mfa/totp/verify` は AA-D-22 で消滅**) に加え、**②資格情報を再提示させる 3 本 (`PUT /accounts/me/password` / `PUT /accounts/me/email` / `POST /mfa/totp/reset`)** もレート制限の対象に含める (キー = `account_id` / `admin_account_id` + エンドポイント)。**③社内管理者の自己管理のうち資格情報を再提示する 2 本 (`PUT /admin/admins/me/email` / `PUT /admin/admins/me/password`) も同じ理由で対象**に含める (2026-08-29 = AA-D-33④。**氏名変更は資格情報を受け取らないため対象外**)。**計 14 本** (**対象の全件と本数の定義元は §3.7 の表**。2026-08-10 の AA-D-22 で 11 → 10、2026-08-29 の AA-D-30 で 10 → 12、同日の AA-D-33 で 12 → 14。**本行の数値は 2026-08-29 のレビュー 中 1 で §3.7 と食い違っているのが検出された** — 本行の言い回しも機械照合の対象に加えることを §5 **R-AA-25** で要求する) | (a2) **②の 3 本を対象外にする** (起草時): 同じ論拠がそのまま当てはまる — `old_password` / `password` はパスワードの、`totp_code` は 10^6 空間の総当たりであり、**`failed_sign_in_attempts` はどれでも増えない**。とくに `PUT /accounts/me/email` は「**セッションを盗んだ攻撃者がパスワードを総当たりしてメールアドレスを乗っ取り、リセット経路ごと奪う**」に直結する。「認証済みだから試行者を特定でき監査で追える」は事後の話であり、**①の MFA 検証も認証済み (S2) である**以上、認証済みを除外理由にすると①の判断と矛盾する。(a) ①を対象外にする ([../auth.md](../auth.md) §6.11-3 の現記述は「未認証で叩けるエンドポイント」のみ): **TOTP は 6 桁 = 10^6 の探索空間**で、パスワードを知る (= トークンを 1 本持つ) 攻撃者が総当たりできる。**`failed_sign_in_attempts` はパスワード失敗でしか増えない** (`hassan-v2-backend/db/queries/account.sql:56-64`) ため、ロック機構では止まらない。(b) MFA 失敗をロックカウンタに加算する: しきい値 1 つが 2 つの意味を持ち、[../auth.md](../auth.md) §10.2 R-4 の「ロックしきい値 < レート制限しきい値」の関係が壊れる。**§5 の R-AA-1 で SSOT へ追加要求** |
| **AA-D-11** | **ロック / 解除の表現** | **`POST /accounts/{account_id}/lock` / `DELETE /accounts/{account_id}/lock`** (契約内管理者)、**`DELETE /admin/accounts/{account_id}/lock`** (社内管理者・解除のみ)。テナント検証は Repository のクエリ条件 (`WHERE id = $1 AND contract_id = $2`) | (a) v2 の `POST /accounts/unlock` + ボディ (`hassan-v2-backend/controller/account.go:895-916`): AA-D-3 の理由。(b) `PATCH /accounts/{account_id}` の `is_locked` フィールドで表す: 一般更新と権限・ガードが違う操作が同じエンドポイントに同居し、**監査記録の粒度も落ちる** (O-6)。加えて v2 に `PATCH` の前例が無い ([themes.md](themes.md) D-TH-8 と同じ理由)。(c) 社内管理者側にもロックを持たせる: **回復手段がロックアウト手段を兼ねる** ([../auth.md](../auth.md) §6.9 の禁止事項) |
| **AA-D-12** | **不変条件ガードのステータス (R-3)** | **403 に統一する** — 対象は ①最後の未ロック契約内管理者のロック ②自分自身のロック ③最後の契約内管理者の降格 ④最後の契約内管理者の削除 ⑤自分自身の削除 ⑥SuperAdmin が自分の MFA をリセット。**ロックのカウントは `AND last_locked_at IS NULL` を含める** (**カウントの取り方 — 行ロック・トランザクション境界・`AND deactivated_at IS NULL` — は AA-D-31 / §3.4 が定義元**。本行はステータスのみを決める) | (a) v2 の 400 (`CannotDeleteLastAdmin` / `CannotDemoteLastAdmin` — `hassan-v2-backend/controller/account.go:621-624`, `:473-476`): [../frontend.md](../frontend.md) §11.1 が**この 2 ケースを「403 = 正常系」として操作前無効化 + 理由表示**で扱うと既に決めており、コードが分かれると FE が 2 系統の分岐を持つ。(b) 409: 意味は近いが [../auth.md](../auth.md) §6.9 が**ロックのガードを 403 と確定済み**で、同種のガードが 2 コードに分かれる。**代償**: [README.md](README.md) §2.5 の「403 は R-1 / R-2 の 2 系統のみ」に**第 3 系統 (R-3) が増える** → §5 の R-AA-2a (auth.md §6.6) / R-AA-2b (README.md §2.5。実施済み) |
| **AA-D-13** | **メンバー削除の既定挙動** | **削除せず無効化のみ** (2026-08-10 のユーザー回答 = DM-Q2)。`DELETE /accounts/{account_id}` は **204 の同期 API**とし、`accounts` の行を物理削除しない。**所有物の移管を行わない**ため、非同期ジョブ・`account_deletions` テーブル・`GET /account-deletions/{deletion_id}` はいずれも**作らない** | (a) **202 + 非同期ジョブで所有物を移管してから物理削除** (2026-07-31 までの本書の設計): [../data-model.md](../data-model.md) §3.4.3 の移管方式を要し、対象は最大 29 テーブル・ジョブの状態テーブル・冪等キー・heartbeat 回収が付随する。**無効化のみなら所有物の帰属が変わらない**ため、これらがすべて不要になる。(b) v2 のまま CASCADE で消す: 同 DM-6 が却下済み (契約の資産が消える)。**帰結**: §5 の **R-AA-27** (`accounts` に無効化列) を出し、**R-AA-4** (`account_deletions`) を取り下げる |
| **AA-D-14** | **会社情報の作成と更新** | **`PUT /company` の 1 本にし、行が無ければ 404 を返す** (upsert しない) | (a) v2 の `POST` / `PUT` 2 本 (`hassan-v2-backend/router/router.go:95-96`): クライアントが「行があるか」を知って呼び分ける必要がある (v2 の `GET /companies` は行が無いとき 404 — `hassan-v2-backend/controller/company.go:80-83`)。(b) **upsert にする (起草時の採用案。2026-07-31 のレビュー S-6 で撤回)**: 採用理由が「クライアントが呼び分けなくてよい」だったが、**同じ理由づけの中で「契約と会社は移行スクリプトで同時に投入するため行が無い状態は通常発生しない」と書いており** ([../data-model.md](../data-model.md) §6.5。新規契約の作成経路も移行スクリプトのみ = §6.3-2 の仮定)、**upsert が救うケースが存在しない**。加えて `GET /company` は 404 を返すため、**GET は「無い」と言うのに PUT は黙って作る**非対称が残る。**行が無い = 移行の失敗**なので、静かに作らず **404 として観測できる方がよい** (静かなデータ生成で移行漏れを隠さない = BE-5 の型)。**帰結**: §2.3.3 の `PUT /company` に 404 を追加し、§2.6 の 17 行目を「POST を作らない」に読み替える。**2026-08-25 の補足 (AA-D-26)**: §6.3 の仮定 2 が撤回され `POST /admin/contracts` が新設されたが、**本判断は変わらない** — 同エンドポイントが `companies` 行を**契約と同一トランザクションで作る**ため、「行が無い = 作成経路の失敗」という前提は新規契約でも成り立つ (**`companies` 行を作る経路は契約作成 1 本に閉じたまま**であり、`PUT /company` を upsert にする理由は依然として無い) |
| **AA-D-15** | **契約情報から `sharing_settings` を落とす** | `GET /contract` は `sharing_settings` を返さない。代わりに `member_count` (在籍数) を返す | (a) v2 の応答をそのまま維持 (`hassan-v2-backend/controller/dto/contract.go:31-42`): **v3 は契約 × カテゴリの共有スイッチを持たない** ([settings.md](settings.md) D-ST-3 / [README.md](README.md) D-API-8')。返しても読み手がおらず、**「設定できるように見えて効かない」** 形になる (BE-10)。**`member_count` を足す理由**: `POST /accounts` が契約の人数上限で 409 を返す (V2-F4) ため、**残枠を画面に出せないと管理者は上限に当たるまで分からない** |
| **AA-D-16** | **アイコンの保存と配布** | **非公開バケット + 署名付き URL**。応答は `icon_url` + `icon_url_expires_at` ([README.md](README.md) D-API-14') | (a) v2 方式 (`ACL: ObjectCannedACLPublicRead` + 恒久 URL — `hassan-v2-backend/aws/s3.go:46`, `:58`): D-API-14' が明示的に禁止している。**アイコンだけ例外にすると「公開バケットが 1 つ存在する」状態**になり、次の実装者が置き場所を判断する余地が生まれる。(b) `GET /accounts/{account_id}/icon` で 302 リダイレクトを返す: エンドポイントが 1 本増え、一覧の N 行に対して N 回の往復が発生する。**代償**: 一覧 1 回で N 件の署名を生成する (HMAC のみでネットワーク往復は無い) |
| **AA-D-21** | **actor / contract が確定しない認証イベント (未登録メールへのサインイン失敗など) をどこに記録するか**。**経緯**: 起草時点の [../data-model.md](../data-model.md) §4.10 は `activity_logs.actor_id uuid` / `contract_id NOT NULL` を維持すると書いており、**そのスキーマでは `signin_failed` が書けない** (BE-10) ことを本書が指摘した。**同節は 2026-07-31 に改訂され、本判断と同じ方向で NULL 可 + `CHECK` を採用済み** (同 §4.10 の「主体も対象契約も確定しない認証イベントだけは NULL を許す」)。**本行は改訂後のスキーマに合わせた確定版である** | **`activity_logs` に書けるようにする** (**[../data-model.md](../data-model.md) §4.10 の採用形に合わせる**。スキーマの SSOT は同節): ①**`actor_type` に 3 番目の値 `unauthenticated` を追加**し、**`actor_id` / `contract_id` を NULL 可**にする。**NULL を許す条件は `action` ではなく `actor_type` を基準に `CHECK` で表明する** — `CHECK ((actor_type = 'unauthenticated' AND actor_id IS NULL AND contract_id IS NULL) OR (actor_type <> 'unauthenticated' AND actor_id IS NOT NULL AND contract_id IS NOT NULL))` (同 §4.10 が採用した形。**`action` 基準にすると `action` の値域の追加ごとに `CHECK` の書き換えが必要**になり、値域を Go 定数 + CI 照合で持つ決定 ([../observability.md](../observability.md) §4.5.1) と噛み合わない) ②**アカウントが解決できた失敗は `actor_type = 'account'` / `'admin_account'` として両列を埋める**。`actor_type = 'unauthenticated'` になるのは未登録メール・存在しない管理者アカウントへの試行のみ ③**メールアドレスは平文で保存せず `detail.email_hash` に入れる** — **HMAC-SHA256 (サーバ側 pepper `AUDIT_EMAIL_HMAC_KEY`)**。同一アドレスへの試行を突き合わせられ、かつ辞書攻撃で復元されない (**pepper 無しの SHA-256 は既知アドレスの総当たりで復元できるため採らない** — メールアドレスは低エントロピーで候補が有限であり、ハッシュだけでは「監査ログを見られてもアドレスが分からない」が成立しない。**2026-07-31 ユーザー決定**)。pepper は §4 の D-5 で棚卸し対象に加える。**[../observability.md](../observability.md) §4.5.2 は既に HMAC + pepper で確定済み**だが、**[../data-model.md](../data-model.md) §4.10 の `detail` の例が pepper 無しの SHA-256 のまま**であり、**是正は §5 R-AA-19** (同節自身が「値域と記録項目の SSOT は observability.md §4.5」と書いているため、参照先と例が矛盾している) | (a) **認証失敗を `activity_logs` に書かず、構造化ログ + レート制限カウンタだけで観測する**: **v2 でできていた `signin_failed` / `mfa_verify_failed` (V2-F17) が監査記録から落ちる** — [../auth.md](../auth.md) §9.3 Q-A2 の「v2 でできていたことは満たす」に対する明示の後退になる。加えて §6.11-3 が名指しで防ぐと宣言した**パスワードスプレー (多数アカウントに 1 回ずつ) の検知は「失敗の分布」でしか行えず**、保持期間の短いログでは月次の突き合わせができない。(b) **認証イベント専用の append-only テーブルを新設する**: **監査記録そのものが 2 本に割れる**ため、`GET /activity-logs` の参照が 2 本の UNION になる。(**2026-08-29 に理由を書き直した** — 旧理由は「[../data-model.md](../data-model.md) DM-15 が却下した v2 の 2 本構成 (`activity_logs` + `event_logs`) に戻る」だったが、**同 DM-15 は 2 本構成を採用する方向へ改訂された**。ただし増えたのは `event_logs` = 利用状況の計測であって認証イベントの置き場ではなく、**認証イベントは `activity_logs` に属する**ため却下の結論は変わらない。`GET /usage-summary` の集計元も `event_logs` に移ったので、旧理由の「集計が 2 本の UNION になる」は本却下案とは無関係になった)。(c) **`actor_type` に値を足さず NULL だけで表現する** (**起草時の採用案。2026-07-31 に撤回し、値を足す形へ転じた**): 起草時の却下理由は「値を増やすと『`actor_type` ごとに `actor_id` が何を指すか』が 3 通りになる」だったが、**[../data-model.md](../data-model.md) §4.10 が `unauthenticated` を追加する形を採用済み**であり、**そちらの方が `CHECK` の条件を `action` の値域から切り離せる** (①の理由)。3 通りになる懸念は「`unauthenticated` のとき `actor_id` は常に NULL」という 1 行の規則で閉じ、`CHECK` がそれを機械的に強制する。**スキーマの SSOT は data-model 側**なので本書が独自案を維持しない (ルート `CLAUDE.md`「判断が割れたら既存の規約・SSOT に寄せる」)。(d) **`detail` にメールアドレスを平文で入れる**: v2 が `activity_logs.account_email` で採った方式 (V2-F17) だが、**監査ログ閲覧権限が「どのアドレスが本製品を使っているか」の名簿になる**。AA-D-4 (秘密を ALB ログに残さない) と同じ論法を DB にも適用する。**代償 (採用案の)**: ①[../data-model.md](../data-model.md) §4.10 の「`contract_id` は NOT NULL を維持できる」という決定の**明示の反転**になる (**同節が 2026-07-31 に反転済み。反転理由も同節に記録された**) ②`(contract_id, occurred_at DESC)` インデックスに NULL 行が集まる。**補償の形は data-model §4.10 の採用形に従う** = `(contract_id, …)` は部分化せず、認証イベント用に **`(action, occurred_at DESC) WHERE actor_type = 'unauthenticated'`** を持つ。**本書が起草時に要求した「`(contract_id, …)` を `WHERE contract_id IS NOT NULL` で部分化する」は採らない** — 認証イベントを引く経路が専用の部分インデックスに閉じるため、`(contract_id, …)` 側の NULL 行は読まれず、部分化の利得が「インデックスサイズの節約」だけになる (SSOT 側の形を変える理由に足りない) |
| **AA-D-22** | **社内管理者の MFA** | **課さない** (2026-08-10 のユーザー決定)。`POST /admin/mfa/totp/generate` / `verify` / `POST /admin/admins/{admin_account_id}/mfa/reset` を**作らず**、`admin_mfa_configs` も**作らない**。`GET /admin/admins` は残すが `mfa_registered` を返さない。**帰結として認証系統は 4 → 3 になる** ([../auth.md](../auth.md) §6.7) | (a) 4 系統のまま社内管理者にも TOTP を課す (2026-08-05 までの本書の設計): **v2 に実体が無い機能**であり (移植元はいずれもユーザー側 — `hassan-v2-backend/router/router.go:231-233`, `:83`)、C-16 の「v2 にある操作は落とさない」の対象外。**実装ブランチ `feat/6` の `16da244` が既に 3 系統化しており** (スケジュールの P-5)、設計を実装に合わせることで差し戻しが不要になる。(b) 設計に残して実装スコープ外にする: 手動ロック (AA-Q13) と同じ扱いだが、**系統数が 4 のままだと `check-route-auth.sh` の系統宣言に到達不能な 4 番目が残り**、CI が「宣言はあるが実装が無い」を検出できない |
| **AA-D-23** | **監査ログの拡張** | **行わない** (2026-08-10 のユーザー決定)。§3.7 の記録対象を **v2 に前例のある事象のみ**に限定する。v3 独自の対象 (`POST /admin/signin` の成否 / ロック・解除 / メンバー作成・権限変更・削除 / 招待の発行・受諾 / リセットの実行・パスワード / メール変更 / `PUT /companies/me/mfa`) は**記録しない**。**2026-08-14 の AA-D-24 により、本行の「v2 に前例が無い」という前提の一部が誤りだったと判明し訂正された — 本行はその訂正前の記録として残す** | (a) 10 行すべてを記録する (2026-07-31 までの本書の設計): [../observability.md](../observability.md) §4.5.1 の値域に 7 値を追加する必要があり、各 UseCase への `activity_logs` 書き込みが実装量として全 issue に薄く広がる。**失うもの**: ①O-7 のアラート入力「社内管理者のサインイン失敗」が成立しない (§5 R-AA-26) ②不可逆操作の実行者が追跡できない。**再開の入口は §6.1 の AA-Q14** |
| **AA-D-24** | **AA-D-23 の前提の訂正 (v2 前例の再確認)** | **メンバー作成・メール変更・パスワード変更・会社 MFA 設定変更の 4 件を記録対象に復帰させる** (2026-08-14 のユーザー決定。実装リポ issue #28 の調査で発覚)。**AA-D-23 は「メンバー作成・権限変更・削除 / パスワード・メール変更 / `PUT /companies/me/mfa` はいずれも v2 に前例が無い」と述べたが、`hassan-v2-backend/auth/event_mapper.go:45-75` を直接確認すると次の 6 件に明確な前例がある**: `POST /accounts` → `member_create` / `PUT /accounts/admin` → `member_update_by_admin` / `DELETE /accounts/:id` → `member_delete_by_admin` / `PUT /accounts/email` → `account_update_email` / `PUT /accounts/password` → `account_update_password` / `PUT /companies/mfa` → `contract_update_mfa`。**このうち復帰させるのは 4 件のみ** (`member_create` / `account_update_email` / `account_update_password` / `contract_update_mfa`)。**`member_update_by_admin` / `member_delete_by_admin` は前例があることを認めつつ、ユーザーが引き続きスコープを広げない判断をした** (事実誤認ではなく意図的な除外として維持)。**`POST /admin/signin` の成否・ロック・解除・招待の発行・受諾・リセットの実行は v2 に前例が無いという AA-D-23 の判定は変更なし** (本書 §3.7 直後の 2026-08-10 注記のうち、この 3 系統に対応する記述は妥当だった) | (a) AA-D-23 を全面的に撤回し 10 行構成へ戻す: 誤認は 6 件中 4 件の復帰で足り、`POST /admin/signin` 等の残り 6 対象は AA-D-23 の判断 (前例なし・スコープを広げない) が妥当なままなので過剰な巻き戻し。(b) 6 件全てを復帰させる: `member_update_by_admin` / `member_delete_by_admin` は前例があるが、ユーザーが「事実誤認の訂正」と「スコープ拡大」を区別して後者は採らないと判断した — 前例の有無だけで機械的に復帰させると判断の余地を奪う |
| **AA-D-25** | **AA-D-2 の適用範囲の訂正 (`/me` を付けるのは誰の視点か)** | **契約・会社は `/me` を付けない**。`/contracts/me` → **`/contract`**、`/companies/me` → **`/company`**、`/companies/me/mfa` → **`/company/mfa`** (2026-08-15。実装リポ issue #17 の着手前レビューでユーザーが指摘し確定)。**`/accounts/me` 系はそのまま** (対象が変わらない) | AA-D-2 は「自分自身を指す操作は `/me` に集める」を**認証ユーザー個人**の意味で意図していたが、§2.3.3 の文面がそれを「認証ユーザーが所属する契約・会社」にまで拡張して適用していた。**契約・会社はアカウント個人のレコードではなく、同一契約に属する全ユーザーで共有される 1 レコード**であり (`PUT /company/mfa` は契約内の全ユーザーに一律で効く — §2.3.3 の概要列)、`/me` が示唆する「自分専用」という意味と食い違う。(a) 現状維持 (`/contracts/me` 等): **意味の食い違いを残したまま**。実装者・利用者が「`/me` = 個人設定」と誤読し、`PUT /companies/me/mfa` を「自分のMFA設定」と取り違える実害がある (実装リポでの質疑で実際に発生)。(b) `/contracts/mine` 等 `me` を保ちつつ語を変える: 「誰の視点か」という本質的な曖昧さ (個人か所属先か) を解消しない。(c) `{contract_id}` を path param にして明示する: **契約・会社は認証コンテキストから一意に解決でき、クライアントが ID を知る必要も渡す必要も無い** (AA-D-3 が `account_id` に要求する path param の理由 — 「越境を防ぐため対象を明示させる」— は、そもそも他契約を指定できない本エンドポイントには当てはまらない)。**ID 不要の単一リソースは単数形パスで表す**方が、`/accounts/{account_id}` (他者操作) との対比でも一貫する |
| **AA-D-26** | **社内管理者向けの契約管理を本増分に含める** | **`POST` / `GET /admin/contracts` と `GET` / `PUT /admin/contracts/{contract_id}` の 4 本を §2.4 に追加する** (2026-08-25 の Q-10 = A)。**削除は作らない** (§2.7)。作成は `contracts` + 代表者 `accounts` + `companies` + 招待リンクを**1 トランザクション**で作り、代表者へ招待メールを送る。**権限は SuperAdmin 限定 (R-4)** — `admin` ロールは 403 (2026-08-25 のオーナー判断で反転。下の却下 (d))。**`language_type` は API に出さない** (AA-Q4)。**監査ログの記録対象に含める** (§3.7。AA-D-23 / AA-D-24 のスコープ限定に対する明示の例外) | **本判断は §6.3 の仮定 2 が明記していた後続条件の発火である** — 同仮定は「作成経路は移行スクリプトのみ」と置きつつ「**v3 で新規契約を獲得する運用が必要になると本増分の対象に戻る**」と書いており、2026-08-25 にオーナーが「新規契約を作る手段は必要」と判断した。(a) **移行スクリプト / 手動 SQL のまま運用する (旧採用案)**: 契約獲得のたびに人間が本番 DB へ直接 INSERT することになり、**承認機構 (H-2) の外側に書き込み経路が常設される** — 実装リポの `.claude/rules/04-human-checkpoints.md` §3.3 が「エージェントに prod の DB 接続情報を配らない」を担保の中心に置いているのと噛み合わない。(b) **作成 1 本だけ追加する**: 作った契約を製品内で確認できず、投入の成否を本番 DB を見に行って確かめることになる (**BE-10 = 読む側と書く側を対で設計する**と同型の穴)。v2 も `GET /admin/companies` を持っていた (`hassan-v2-backend/router/router.go:215`)。(c) **v2 のパス `/admin/companies` を踏襲する**: パスの語と path param が食い違い (`DELETE /admin/companies/{contract_id}`)、契約内ユーザー向けの `GET /company` とも紛らわしい。(d) **`admin` ロールにも許す (2026-08-25 の起草時の採用案。同日中に反転)**: v2 のルーティングは `POST /admin/companies` に `CheckSuperAdminRole` を掛けておらず (`hassan-v2-backend/router/router.go:220`)、**実装上は Admin でも契約を作れた**。しかし **v2 自身のコード内ドキュメントは「Admin: 管理画面における Read 機能を利用可能」と宣言しており** (`hassan-v2-backend/entity/admin_auth_role.go:7-10`)、**v2 の実装がその宣言に反していた**。v3 はこの文言を `entity/admin_account/admin_account.go` へ転記済みで、**Admin に書き込みを許すと実装とコメントが食い違ったまま v3 に持ち込まれる**。**契約の作成は課金に直結し不可逆**であり、宣言どおり Admin を Read に留める価値がここに集中している。**⚠️ 2026-08-26 に本却下理由から 1 文を削除した (オーナー判断)** — 旧版は「**加えて v3 は既に MFA リセット・ロック解除を SuperAdmin 限定にしており ([../auth.md](../auth.md) §6.2)、契約の作成という不可逆かつ課金に直結する操作だけが緩いのは一貫しない**」と書いていたが、**その前提が成立していなかった** (同 §6.2 はロール制限を課しておらず、`auth.md` §10.2 の R-3 ④ は AA-D-22 で取り下げ済み)。オーナーが「MFA リセットなどは Admin ができて良い」と判断し、**ロール制限の範囲は契約管理 4 本だけ**で確定した (同 §6.2 の「社内管理者のロールによる制限の範囲」)。**本却下 (d) の結論は変わらない** — v2 のコード内ドキュメントの宣言が独立した理由として成立するため。検出元は実装リポ hassan-v3 の issue #18 / PR #126。**代償**: v2 の実挙動より権限が狭くなる = **C-16 (v2 でできたことを落とさない) に対する後退**であり、意図的な選択としてここに記録する (運用で Admin ロールの管理者が契約を作れなくなる)。**認証系統の数は 3 のまま変わらない** — 増えるのは既存の `X-Admin-Token` 系統の route だけで、[../auth.md](../auth.md) §6.7 の系統宣言は触らない |

| **AA-D-27** | **代表者への招待リンクの再発行・再送を作る** | **`POST /admin/contracts/{contract_id}/signup-links` を §2.4 の②に追加する** (2026-08-26 のオーナー判断)。**リクエストボディを持たず**、宛先は `contracts.representative_email` から引く。**未使用リンクを失効させてから発行する** (§2.3.2 のメンバー招待の再送と同じ手続き)。**権限は SuperAdmin 限定 (R-4)** — 契約管理の一部として AA-D-26 と揃える。**監査ログの記録対象に含める** (§3.7) | **起票の経緯**: AA-D-26 で作った `POST /admin/contracts` は**コミットしてから招待メールを送る**ため、メール送信に失敗すると 4 行は残ったまま**平文トークンだけが失われる**。**v2 には回復手段があった** — `signup_links.id` (UUID の主キー) をそのまま平文トークンとして使い `GET /accounts/signup-links/:id` が公開だった (`hassan-v2-backend/router/router.go:78`) ため、運用が DB から取り出して手で再送できた。**v3 は `token_hash` しか保存しない** (AA-D-5④) ため復元できず、**回復手段が無い状態が v3 で新しく生まれていた** = **C-16 に対する後退**。実装リポ hassan-v3 の issue #116 の S-7 レビュー (重大1) が検出した。(a) **既存の `POST /accounts/{account_id}/signup-links` を社内管理者にも開く**: 同 route は `TierUser` 系統で**契約内管理者限定**であり、[../auth.md](../auth.md) §6.7 のホワイトリストは**1 route = 1 系統**で宣言する。2 系統を通すと「route を足したがミドルウェアを書き忘れた」を構造的に防ぐ仕組みが崩れる。加えて社内管理者は契約スコープを持たないため、契約内管理者向けの所有者絞り込みがそのままでは効かない。(b) **`POST /admin/contracts` を「既存メールなら再発行する」形にする**: **作成エンドポイントに隠れた分岐**が生まれ、409 が返るはずの操作が黙って成功する。(c) **回復手段を作らず運用で本番 DB を直接触る**: `signup_links.token_hash` を手で書き換える回避策は実際に成立する (`HashSignupToken` は pepper 無しの SHA-256) が、**実装の内部仕様を運用手順書に固定する**ことになり、pepper を足す変更で手順書が黙って壊れる。加えて承認機構 (H-2) の外側に本番 DB への書き込み経路が常設される — AA-D-26 の却下 (a) と同じ理由で採らない。(d) **リクエストボディで宛先メールを受け取る**: **全契約横断の権限を持つ社内管理者が任意のアドレスへ招待リンクを送れる経路**になる。宛先を `contracts.representative_email` に固定すると、この経路が構造的に存在しない |
| **AA-D-28** | **`PUT /admin/contracts/{contract_id}` が代表者メールを変えたときの `accounts.email` の追随** | **代表者が未サインアップ (`accounts.is_completed = false`) のときだけ、`contracts.representative_email` と `accounts.email` を同一トランザクションで更新する** (2026-08-26 のオーナー判断)。**サインアップ済みなら `accounts.email` を変更しない** — `contracts.representative_email` だけが変わる。**新しいメールが既存アカウントと重複する場合は 409** (`accounts.email` は `unique_accounts_email` で全契約横断の一意) | **起票の経緯**: AA-D-27 で作った招待の再発行は `(contract_id, contracts.representative_email)` で `accounts` を引く。一方 `PUT` は `contracts` だけを更新していたため、**招待が届かない最大の原因 (メールアドレスの打ち間違い) を直した直後に 再発行が 404 になり、AA-D-27 の目的が半分達成されない**状態だった (実装リポ hassan-v3 の issue #130 の S-7 レビュー 中1 が検出)。加えて `contracts.representative_email` (管理画面の表示) と `accounts.email` (認証に使う値) が**食い違ったまま残る**という不整合も生じていた。(a) **サインアップ済みの代表者でも `accounts.email` を変更する**: **`PUT /accounts/me/email` (本人がパスワード確認を添えて変更する。AA-D-17) の意味が消える** — 社内管理者が本人確認なしに他人のログイン ID を書き換えられることになり、**アカウント乗っ取りに近い**。メール変更はリセット経路 (`POST /accounts/reset-password`) の宛先でもあるため、**書き換えられた時点でその人のアカウントを奪える**。(b) **再発行の側で代表者を「契約内の管理者ロールかつ未サインアップの 1 行」として解決する** (#130 だけで閉じる案): `POST /accounts` で契約内管理者を増やせるため、**代表者が複数いる契約で対象が曖昧になる**。契約の代表者は `contracts.representative_email` が定義であり、そこから引けない状態を放置したまま別の解決手段を足すと、**定義が 2 つになる**。(c) **追随させない (現状維持)**: 打ち間違えた契約は DB を直接触るしかなくなり、AA-D-27 が解こうとした問題 (承認機構の外側の書き込み経路) がそのまま残る |
| **AA-D-29** | **社内管理者アカウントの作成・権限変更を本増分に含める** (**§2.7 で「対象外」としていた判断の反転**) | **3 点**。**①`POST /admin/admins` と `PUT /admin/admins/{admin_account_id}` の 2 本を §2.4 の③として追加する** (2026-08-29 のオーナー判断 = 実装リポ issue #181 の案 B)。**削除 (`hassan-v2-backend/router/router.go:208`) と権限ロール一覧 (`同:210`) は対象外のまま** (§2.7 — v2 FE に呼び出し元が無い)。**パスは `/admin/accounts` ではなく `/admin/admins`** — v3 は `GET /admin/accounts` を**一般アカウントの全契約横断検索**に割り当てており (§2.4 の①。v2 の `GET /admin/companies/accounts` = `同:216` の移植先)、v2 のパスをそのまま使うと同じ接頭辞が 2 種類の主体を指す。**対象 ID はボディではなく path param** (AA-D-3。v2 は `PUT /admin/accounts/details` のボディに `id` を持つ — `hassan-v2-backend/controller/dto/admin_account.go:68-73`)。**②初期パスワードの渡し方は v2 と同じ「パスワード登録リンクをメールで送る」方式にする** (**2026-08-29 のオーナー回答 AA-Q15 = (c)。起草時の「サーバ生成 + 201 応答で 1 度だけ返す」から反転した**)。**採用の詳細 (公開 2 本・再発行 1 本・列の改名・却下案) は AA-D-30 が持つ** — 本行は「本増分に含める」判断のみを保持する。**③権限は SuperAdmin 限定 (R-4)** で、**監査ログの記録対象に含める** (§3.7。AA-D-23 / AA-D-24 のスコープ限定に対する明示の例外 = AA-D-26 と同じ扱い) | **起票の経緯**: §2.7 の旧記述は [../auth.md](../auth.md) §6.2 の「API を作らず移行スクリプトで投入する」に依拠していたが、**その根拠は「社内管理者機能が実質全部入りになる」という範囲の判断**であり、**v2 での使用実態を確認したものではなかった**。実装リポ hassan-v3 の issue #181 の調査で、**作成・更新の 2 本は v2 フロントエンドの `/admin/admin-setting/new` · `/edit` 画面から現に呼ばれており、画面はヘッダーナビから到達可能**であることが判明した (出典は §2.7)。**C-16 (v2 にある操作は落とさない) の対象**である。**AA-D-26 (契約管理) と同型の反転**だが、**権限の扱いだけが違う** — **v2 は該当 5 本すべてに `CheckSuperAdminRole()` を掛けており** (`hassan-v2-backend/router/router.go:206-210`)、コードと v2 自身の宣言 (`hassan-v2-backend/entity/admin_auth_role.go:7-10`「Admin: 管理画面における Read 機能を利用可能」) に**食い違いが無い**。したがって③は**v2 の実挙動どおりに揃えるだけ**であり、**AA-D-26 の代償だった「C-16 に対する後退」がここには無い**。(a) **①の却下 — 現状維持 (移行スクリプトのみ)**: 社内管理者を 1 人増やすたびに本番 DB へ直接 INSERT することになり、**承認機構 (H-2) の外側に書き込み経路が常設される** (AA-D-26 の却下 (a) と同じ)。**加えて v2 の画面が消えるため C-16 の後退になり、増分後ろ倒しにもオーナー承認が要る**。(b) **①の却下 — 削除・ロール一覧も含めて v2 の 5 本すべてを移植する**: **削除とロール一覧は v2 FE に呼び出し元が無い** (§2.7 の実測) ため、**配線されていない実装を仕様の根拠にすることになる**。作った API に消費者がいない状態は BE-10 の裏返しで、**保守対象と 403 の本数だけが増える**。(c) **②の旧採用案 — サーバが `crypto/rand` で初期パスワードを生成し、平文を 201 応答に 1 度だけ返す** (**起草時の採用案。2026-08-29 に AA-Q15 = (c) のオーナー回答で却下へ転じた**): 公開エンドポイントを増やさずに済むが、**代償 2 点がどちらも本番運用で残り続ける** — **(i) 作成者 (SuperAdmin) が他人の初期パスワードを知る** (§2.7 が一般アカウントについて禁じた経路の例外を `admin_accounts` に作ることになる) **(ii) v3 には社内管理者が自分のパスワードを変更する API が無い** (v2 の `PUT /admin/accounts/password` = `同:204` は当時 §2.7 のとおり未移植だった。**2026-08-29 中に AA-D-33 で `PUT /admin/admins/me/password` として移植対象に入ったが、本却下の判断は変わらない** — 変更経路があっても「作成者が初期パスワードを知る」状態そのものは消えないため) ため、**初期パスワードが変更されないまま使われ続ける**。**オーナーはこの 2 点を理由に登録リンク方式を選んだ** (AA-Q15 の回答)。**採用側の詳細は AA-D-30**。(d) **②の却下 — 呼び出し側が初期パスワードをボディで指定する**: 人間が選んだ値になり [../auth.md](../auth.md) §6.10 の生成規約が効かない。**弱いパスワードが最も強い権限に付く**。**登録リンク方式でも本人が選ぶパスワードは強度要件 (AA-Q7) の検証を通る**ため、この却下理由は (c) の反転後も維持される。(e) **③の却下 — `admin` ロールにも許す**: v2 が 5 本すべてに `CheckSuperAdminRole()` を掛けている実挙動からの後退になる (AA-D-26 の (d) と違い、ここでは v2 のコードと宣言が一致しているため擁護できる理由が無い) |
| **AA-D-30** | **社内管理者の初回パスワード設定の経路** (**AA-Q15 = (c) のオーナー回答 = 2026-08-29。AA-D-29② の実装形**) | **6 点**。**①公開 2 本を新設する** — `POST /admin/password-registrations/lookup` (登録先の表示) と `POST /admin/password-registrations` (パスワード設定)。**どちらもトークンをボディで受ける** (AA-D-4)。**`/admin/admins` 配下に置かない** (却下 (b))。**②秘密の扱いは AA-D-5④ に完全準拠する** — 生成 = `crypto/rand` 32 バイト → base64url ([../auth.md](../auth.md) §6.10)、保存 = **SHA-256 ダイジェストのみ**、列は **`register_admin_password_requests.token_hash text NOT NULL UNIQUE`** (**v2 の `token varchar(255) NOT NULL UNIQUE` = `hassan-v2-backend/db/schema.sql:504` からの改名**。`signup_links` / `reset_password_requests` と同名にする)、クエリ名も列に揃える (§3.5)。**③受諾の応答は 200 + `AdminSignInResult`** (`POST /accounts/signup` と同じ理由 = §3.3)。**④再発行 1 本を §2.4 の③に足す** (`POST /admin/admins/{admin_account_id}/password-registrations`。SuperAdmin 限定 = R-4。未使用リンクを失効させてから発行する)。**⑤期限判定を lookup と設定の両方で行う** (却下 (g))。**⑥有効期限は v2 と同じ 7 日** (`hassan-v2-backend/usecase/admin_account/create_admin_account.go:95-96`。値の SSOT は [../auth.md](../auth.md) §10.2 R-4 = AA-Q9 と同じ扱い)。**併せて `InternalAdminView` に `password_registered` を足す** (§2.5。**読む側を対で設計する = BE-10**) | **経緯**: AA-D-29② は起草時「サーバ生成 + 201 で 1 度だけ返す」を採り、(c) として本方式を却下していた。**オーナーが AA-Q15 に (c) と回答した**ため採用側が入れ替わった (却下理由の全文は AA-D-29 の (c) に残す)。(a) **v2 のパスをそのまま移植する** (`GET /admin/accounts/register/password/check` + `POST /admin/accounts/register/password` = `hassan-v2-backend/router/router.go:199-200`): **トークンがクエリに乗り ALB アクセスログに平文で残る** (AA-D-4 の却下 (a) と同一)。加えて **v3 の `/admin/accounts` は一般アカウントの全契約横断検索**を指す (AA-D-29①) ため、同じ接頭辞が 2 種類の主体を指す。(b) **公開 2 本を `/admin/admins/...` 配下に置く**: **v2 はまさにこの形で事故っている** — `adminAccountRoute` は**公開 2 本を宣言した後に `.Use(AdminAuthRequiredMiddleware())` を呼ぶ**順序依存で公開性を表現しており (`同:199-201`)、[../auth.md](../auth.md) §1.7 / §6.7 がこれを欠陥として名指ししている。§6.7 は「グループの既定を認証必須にし、**公開だけを別グループに切り出す**」を採っているので、**公開ルートを SuperAdmin 限定グループと同じ接頭辞に置くとその表現が崩れる**。**`/admin/password-registrations` なら route グループがそのまま系統の境界になる**。(c) **受諾の応答を 204 にしてサインイン画面へ送る**: §3.3 が `POST /accounts/signup` で却下したのと同じ — **設定したばかりのパスワードをもう一度入力させる**。(d) **④の却下 — 再発行 API を作らない**: **メール送信に失敗すると `admin_accounts` の行だけが残り、パスワードを設定する手段が永久に無くなる** — **削除 API は対象外** (§2.7) で、**`name` / `email` が UNIQUE** (`hassan-v2-backend/db/schema.sql:54-55`) なので**作り直しもできない**。**製品内の回復手段がゼロになる**のは AA-D-27 が契約の招待について解いた問題より重い (あちらは契約を作り直せた)。**本人がパスワードを忘れたときの回復手段も兼ねる** — v3 は社内管理者向けのパスワードリセット経路を持たない (v2 も持たない)。**運用が DB を直接触る回避策は採らない** (AA-D-27 の却下 (c) と同じ = 承認機構 H-2 の外側に書き込み経路が常設される)。(e) **④の却下 — 再発行のボディで宛先メールを受け取る**: AA-D-27 の却下 (d) と同じ (**任意のアドレスへ登録リンクを送れる経路になる**)。宛先は `admin_accounts.email` に固定する。(f) **④の却下 — 再発行を公開エンドポイントにする** (「登録メールを再送」ボタン): **未認証で社内管理者アドレスの存在確認とメール送信を無制限に起動できる**。公開面を増やさない。(g) **⑤の却下 — v2 どおり期限判定を lookup 側だけに置く**: **v2 の `RegisterPasswordUseCase` には期限判定が無く** (`hassan-v2-backend/usecase/admin_account/register_password.go:33-58`。期限を見るのは `hassan-v2-backend/usecase/admin_account/check_register_password_token.go:38-41` だけ)、**lookup を通さず `POST` を直接叩けば期限切れトークンでパスワードを設定できる**。**同 usecase の呼び出し元 (`hassan-v2-backend/controller/admin_account.go:253-256`) はトークン不正でも 500 を返す**ため、失敗が総当たりとして観測できない (V2-D2 と同型)。v3 は **404 に統一** (AA-D-6④) し §7.3 の UT で固定する。**採用側の代償 (3 点)**: **(i) 公開系統が 6 → 8 本に増える** — 公開面は認証を持たない攻撃者が到達できる面であり、増やすこと自体が代償。緩和は**レート制限の対象に含める** (§3.7 で 10 → 12 本) と**404 の統一** (当たり判定を与えない)。**(ii) メール到達性への依存** — 到達しない間は社内管理者を 1 人も増やせない (作成は 201 で成功するがサインインできない)。緩和は④の再発行と、**メール送信失敗を握り潰さない** (§3.7 の O-4)。**(iii) 「作成済みだが未設定」の状態が最長 7 日 (再発行すればさらに延びる) 存在する** — 運用がそれを見分けられないと再発行の判断ができないため、`InternalAdminView` に `password_registered` を足す (⑥)。**その導出は「`register_admin_password_requests` に当該 `admin_account_id` の行が 1 件も無いこと」**であり、**期限切れ行を掃除しないことが前提**になる (掃除すると未設定のアカウントが「設定済み」に見える。`auth_rate_limit_counters` の定期削除 = [../data-model.md](../data-model.md) §4.2 と扱いが違う点を明示する) |
| **AA-D-31** | **不変条件ガード (R-3) を並行実行下でも守る手段** (2026-08-29 のオーナー判断。実装リポ hassan-v3 の issue #108 = `blocked-by-design`) | **3 点**。**①`SELECT … FOR UPDATE` による直列化を採る** — ガードのカウントと実際の UPDATE を **1 トランザクション**に入れ、**契約内の有効な管理者の行をロックしてから数える** (クエリと数え方は §3.4 の `LockContractAdminsForGuardInContract` が定義元)。**②ロック対象の集合から「操作対象の行」を除外しない** (除外は数えるときだけ)。**③`PUT /accounts/{account_id}` (降格) と `DELETE /accounts/{account_id}` (無効化) と `POST /accounts/{account_id}/lock` の 3 本を同じ差分で直す** — 1 本だけ直すと交差経路 (`PUT`×`DELETE` 等) が残る。**併せて数える条件に `AND deactivated_at IS NULL` を足す** (v2 は物理削除前提でこの条件を持たない = §3.4 の 3 つ目の箇条) | **欠陥の内容**: §3.4 の判定は `COUNT(*) … <= 1` としか書いておらず**直列化の要求が無かった**。管理者が A・B の 2 名しかいない契約で A への `DELETE` と B への `DELETE` が並行すると、**双方の COUNT が相手を 1 と数えてガードを通過し、有効な管理者が 0 名になる**。**無効化は回復が困難** — [../data-model.md](../data-model.md) §4.2 の **DM-A5 補足 7** が「再有効化 API を作らない」と決めているため、戻す手段が運用 SQL しかない。(a) **DB 側の宣言的な不変条件 (部分ユニークインデックス等)**: 「契約ごとに有効な管理者が **1 人以上**」は**下限の制約**であり、ユニーク制約 (上限 1) で表現できない。実現にはトリガか制約テーブル (契約ごとに管理者数を持つ行を更新する) が要り、**すべての `accounts` 更新経路に副作用が乗る**。制約テーブル方式は結局その行への行ロックで直列化するので、**(採用案) と同じ直列化を、更新経路すべてに広げて実装する**ことになる。(b) **楽観的制御 (カウント条件を含めた条件付き UPDATE を撃ち、0 件更新なら 403)**: 1 文で済むが、**降格・削除・ロックで条件式が 3 通りに散り** (BE-2 の型)、かつ**「0 件更新」が「ガード違反」なのか「対象が消えた (404)」なのかを区別できない**。競合の再判定にリトライ設計 (回数・バックオフ・冪等性) が別途要る。(c) **不変条件を守らず、破れたら運用 SQL で回復する**: DM-A5 補足 7 の帰結として**製品内の回復手段がゼロ**であり、承認機構 (H-2) の外側の本番 DB 書き込みを常態化させる (AA-D-27 却下 (c) / AA-D-30 却下 (d) と同じ理由)。**オーナーが不採用と明示した** (2026-08-29)。(d) **トランザクション分離レベルを `SERIALIZABLE` に上げる**: 正しく直列化されるが、**分離レベルは接続・トランザクション単位の設定**であり「この 3 本だけ」を機械的に強制する手段が無く、**直列化失敗 (40001) のリトライを全経路で扱う**ことになる。明示ロックなら**どの行が守られているかがクエリに書かれる**。(e) **ロック集合から操作対象の行を除外する** (②の却下): 「他に管理者がいるか」を数えるなら対象を除くのが自然だが、**管理者 2 名で A の削除と B の削除が並行すると、互いに素な行集合 (`{B}` と `{A}`) をロックするため衝突せず直列化されない**。その後の UPDATE が相手のロック行に当たって**デッドロック (40P01) として現れる**ため、結果的に不変条件は守られるが、**「守られる理由がデッドロック検出」になり、リトライ設計と 500 の抑止が要る**。**代償 (採用案の)**: ①**契約内の管理者数ぶんの行ロック**を取るため、同一契約のメンバー更新が直列化する (契約あたりの管理者は数名で、対象操作は管理画面からの低頻度操作なのでスループット上の問題にならない) ②**Repository のクエリを 1 本増やす** (`COUNT` クエリの置き換え)。**スキーマ変更は伴わない** — [../data-model.md](../data-model.md) への追加要求 (§5) は発生しない |
| **AA-D-32** | **無効化済みアカウントへのトークン発行と、発行済みトークンの扱い** (2026-08-29 のオーナー判断。実装リポ hassan-v3 の issue #107 = `blocked-by-design`) | **3 点**。**①使用側で止める (主対策)**: **認証ミドルウェアが `deactivated_at IS NOT NULL` を判定し 401 + `AU-T-00006` を返す** ([../auth.md](../auth.md) §6.1 の変更点 5 / §6.13.2 の判定 g。[../data-model.md](../data-model.md) §4.2 の **DM-A5 補足 2 を同じ差分で改訂**した)。**②発行側で止める (受諾の拒否)**: **`POST /accounts/signup` は、トークンから解決した `accounts` 行が `deactivated_at IS NOT NULL` なら 404 を返す** — **招待リンク不正・期限切れ・使用済みと同一の 404・同一コード**にマスクする (AA-D-6 / §7.3 の必須ケース 6 と同じ扱い)。**パスワードは設定せず、`SignInResult` も返さない**。**③多層防御**: **`DELETE /accounts/{account_id}` は無効化と同一トランザクションで当該アカウントの未使用招待リンクを削除する** — AA-D-5③ (メールアドレス変更時の削除) と同じ手続き・同じ Repository クエリ (`signup_links` の認証済み経路。§3.5 の「載せないもの」) を使う | **欠陥の内容**: 「メンバー作成 → 招待リンク発行 → **受諾前に無効化** → 本人が受諾」の順序が AA-D-13 (削除 = 無効化) の導入で実在するようになった。**受諾は 200 で成功し `SignInResult` (トークン) が発行される** — 旧 DM-A5 補足 2 (既存トークンは失効しない) と組むと、**無効化済みの人物が JWT の有効期間 (1 日。[../auth.md](../auth.md) §6.9-3) API を使える**。**補足 1 (サインイン拒否) は迂回される** — サインインとは別のトークン発行経路だからである。(a) **受諾を拒否せず、①だけで守る**: ミドルウェアが止めるので実害は消えるが、**無効化済みアカウントのパスワードが設定され `is_completed=true` になる** (DM-A5 補足 7 で再有効化 API が無いため、この行は「パスワードが設定された無効アカウント」として残る)。**補足 1 がサインインを拒否している以上、同じ資格情報を作らせること自体が不整合**である。(b) **専用のエラーコード / ステータスを起こす** (例: 403 + 「このアカウントは無効化されています」): **招待リンクの状態を外部から区別可能にする** — 攻撃者は「404 = リンクが無効」「専用コード = リンクは有効で宛先アカウントが無効化された」を読み分けられ、**アカウントの存在と状態の間接的な確認手段**になる。**AA-D-6 (存在を漏らさない) / §7.3 の必須ケース 6 (不正・期限切れ・使用済みを同一応答にする) と正面から衝突**する。**FE の表示上も差を付ける必要が無い** — どちらも「管理者に連絡してリンクを再発行してもらう」が唯一の回復手順である。(c) **③だけを採る (招待リンクの削除のみ)**: 「無効化 → 受諾」の**順序**は塞げるが、**受諾がすでに完了して発行済みのトークン**には何も効かない (①の代替にならない)。また削除の実装が漏れても**検査に現れない**。(d) **無効化時に既存トークンをブラックリスト化する**: ①と同じ効果を、**新しいストア (失効リストとその TTL 管理) を増やして**得ることになる。ミドルウェアは既に毎リクエスト `accounts` を引いている ([../auth.md](../auth.md) §1.3 の判定 6) ため、**列を 1 つ足すだけで同じ効果が得られる**。**代償**: ①**`AU-T-00006` が増える** (§3.1.1 の値域に 1 行。**FE の判定規則 3 行は変わらない** — 接頭辞で分類するため) ②**無効化が実質的に不可逆な即時遮断になる** ([../auth.md](../auth.md) §6.9 の AA-Q13 受信欄 1 の追記) ③**②と③は同じ穴を二重に塞ぐ** — 片方だけを実装しても検査が緑になるため、§7.3 の必須ケース 19・20 で**両方を独立に固定する** |
| **AA-D-33** | **社内管理者が自分の氏名・メール・パスワードを変える経路** (2026-08-29 のオーナー判断。同日のレビュー 重大 3 = 「C-16 の判定に v2 FE の配線が反映されていない」への対応) | **4 点**。**①3 本を §2.4 の④群として作る**: `PUT /admin/admins/me` (氏名) / `PUT /admin/admins/me/email` / `PUT /admin/admins/me/password`。**②ロール制限を課さない** — **`admin` ロールでも実行できる** (R-4 の対象外)。**自分自身の記録の変更**であり、AA-D-29③ が SuperAdmin 限定にした「**他者の権限を変える操作**」とは性質が違う。**v2 も `hassan-v2-backend/router/router.go:202-204` は `AdminAuthRequiredMiddleware` のみで `CheckSuperAdminRole()` を持たない** (同 `:206-210` の 5 本とは扱いが違う) ため、**この 3 本には C-16 の後退が無い**。**③対象は常に呼び出し元本人**とし、**パスにもボディにも対象 ID を置かない** (JWT の `admin_account_id` から解決する = V2-D7 の解消。AA-D-3 の社内管理者版)。**④資格情報の再提示と 400 の扱いは §2.3.1 の同名 3 本に完全に揃える** — メール変更は現在のパスワード、パスワード変更は `old_password` を要求し、**不一致は 400 + `AU-C-00004` (分類 C)** (AA-D-17)。**メール変更とパスワード変更はレート制限の対象** (§3.7 の 13・14 = AA-D-10②) | **経緯**: 起草時は §2.7 で「代替経路がある」ことを理由に対象外としていた。**2026-08-29 のレビューで 2 つの事実誤認が判明した** — (1) **v2 FE に配線済みの 3 画面がある** (§2.7 に出典を記載。`admin` ロール向けヘッダーナビからも到達可能 = `hassan-v2-frontend/src/components/layouts/header/admin-header-link.tsx:31`-`:36`) (2) **代替経路は `admin` ロールでは成立しない** (`PUT /admin/admins/{admin_account_id}` は SuperAdmin 限定)。(a) **作らない (旧判断の維持)**: **`admin` ロールの社内管理者は自分の氏名・メールを変更する手段が製品内に一切無くなる**。パスワードも SuperAdmin に登録リンクの再発行を依頼するまで変えられず、**漏洩を疑ったときに本人が即座に遮断できない** ([../auth.md](../auth.md) §6.9 の AA-Q13 受信欄 = 即時遮断手段が無い、と重なる)。**C-16 の後ろ倒しはオーナー承認が要る** (`v2-spec-carryover-policy.md`) が、AA-Q15 の回答 (= 初期パスワードの渡し方) はこの問いへの承認ではない。(b) **`PUT /admin/admins/{admin_account_id}` に自分自身を指定して代用する**: 同エンドポイントは **SuperAdmin 限定**なので `admin` は 403。**限定を外すと「他人のロールを変える操作」が `admin` に開き**、AA-D-29③ が塞いだ**権限の自己増殖経路**が復活する。**同 API は `admin_auth_role` を本文に持つ**ため、自分自身に対して呼べるようにするだけでも**自己昇格 (`admin` → `super_admin`) が可能**になる。(c) **v2 のパスをそのまま移植する** (`PUT /admin/accounts/{name,email,password}`): **v3 の `/admin/accounts` は一般アカウントの全契約横断検索**を指す (AA-D-29① / AA-D-30 却下 (a) と同じ理由) うえ、**対象をボディの `id` で受ける形 (V2-D7) を持ち込む**。(d) **3 本を 1 本 (`PUT /admin/admins/me`) に統合し、メール・パスワードも同じ本文で受ける**: **資格情報の再提示が要る項目と要らない項目が同じ本文に混ざり**、400 (`AU-C-00004`) がどのフィールドに紐づくかを FE が判定できない (AA-D-17 の却下 (a) と同型)。§2.3.1 が同じ理由で 3 本に分かれているのと非対称にもなる。(e) **パスワード変更を「登録リンクの再発行」(AA-D-30④) で代用する**: **SuperAdmin への依頼が必要**で本人が即座に変えられず、**メール到達に依存する** (AA-D-30 の代償 ii)。加えて再発行は SuperAdmin 限定なので、`admin` は自分のパスワードを変える起点を持てない。**代償**: ①**社内管理者系統が 13 → 16 本**に増える (公開面は増えない — 全 3 本が `X-Admin-Token` 必須)。②**レート制限の対象が 12 → 14 本**に増える (§3.7)。③**`PUT /admin/admins/{admin_account_id}` (③群) と `PUT /admin/admins/me` (④群) が同じ `admin_accounts` 行を更新する経路になる** — 更新の実体 (UNIQUE 違反 → 409 の写像) は 1 箇所に集約し、**入口ごとに書き分けない** (BE-2 の型を避ける。§7.1)。④**監査記録は行わない** (§3.7 の注記 = v2 に前例が無く AA-D-23 / AA-D-24 のスコープ限定に従う)。**再開の入口は §6.1 の AA-Q14** |

### 3.1.1 401 / 400 の分類と `CodedError` の値域 (AA-D-9 / AA-D-17 / AA-D-18)

**本節は FE と BE の共有契約**であり、**FE が「セッションを破棄するか」を決める唯一の入力**である。
[../frontend.md](../frontend.md) §9 は「401 を受けたら `/api/logout?next=…` へリダイレクトしセッションを破棄する」を
規定し、同 §5.2.3 が「破棄経路は 1 本だけ」を確定している。**この既定のままだと TOTP コードの
打ち間違い 1 回で強制サインアウト**になるため、**401 を 2 分類に割り、判定を応答本文の `code` に閉じる**。

| 分類 | 意味 | HTTP | FE の扱い |
|---|---|---|---|
| **T (Token)** | **`X-Token` / `X-Admin-Token` 自体が無効** — 署名不正・期限切れ・トークンのアカウントが存在しない・**アカウントがロックされている** (ミドルウェアが `last_locked_at` 非ゼロで無条件に 401。[../auth.md](../auth.md) §6.9 が「この挙動を踏襲する」と確定)・**アカウントが無効化されている** (ミドルウェアが `deactivated_at IS NOT NULL` で 401。AA-D-32①)・**MFA ゲート未通過** (§3.2 の S2 で §2.2 以外に到達) | **401** | `/api/logout?next=…` へ。**セッションを破棄する** |
| **C (Credential)** | **リクエストボディで提示した資格情報が一致しない** (パスワード・TOTP コード)。**トークンは有効なまま**であり、破棄する理由が無い | **401** (トークンの発行・昇格 4 本。AA-D-9) / **400** (認証済みの 3 本。AA-D-17) | **フォーム内のエラー表示のみ。セッションを破棄しない** (401 でも `/api/logout` に流さない) |

**FE の判定規則 (実装するのはこの 3 行だけ。エンドポイントで分岐しない)**:

1. 応答本文の `code` が **`AU-T-` で始まる** → 分類 T。セッションを破棄する
2. 応答本文の `code` が **`AU-C-` で始まる** → 分類 C。フォーム内エラーとして描く
3. **上記以外** (本文なし / 未知の接頭辞 / JSON パース失敗 — ALB や逆プロキシが返す 401 を含む) →
   **分類 T として扱う (fail-safe の既定)**。理由: 未知の 401 を分類 C として無視すると、
   実際にトークンが切れている場合に**同じ 401 を返し続けるループ**になり画面から回復できない。
   破棄側に倒せばユーザーは再サインインで回復できる

**コードの値域 (本節が SSOT。これ以外のコードは実装リポの `constants` パッケージが SSOT — AA-D-18)**:

**採番規則**: v2 の `<カテゴリ 2 文字>-E-<5 桁>` (`hassan-v2-backend/constants/errors_account.go:6` = `AC-E-00001`) の
**`E` の位置に分類記号 (`T` / `C`) を置く**。カテゴリは既存の `AC` (Account) と衝突しない
**新カテゴリ `AU` (Auth)** を起こす (v2 の `ErrorCategory` は列挙の追加で拡張できる —
`hassan-v2-backend/constants/errors.go:8-19`)。

| code | 分類 | HTTP | 返す箇所 | FE の表示 |
|---|---|---|---|---|
| `AU-T-00001` | T | 401 | 認証ミドルウェア 2 系統 (署名不正・形式不正) | 「セッションが無効です。再度サインインしてください」 |
| `AU-T-00002` | T | 401 | 同上 (有効期限切れ) | 同上 |
| `AU-T-00003` | T | 401 | 同上 (`user_uid` のアカウントが存在しない) | 同上 |
| `AU-T-00004` | T | 401 | 同上 (**アカウントがロックされている**) | 「アカウントがロックされています。契約内管理者に解除を依頼してください」 |
| `AU-T-00005` | T | 401 | MFA ゲート (S2 で §2.2 以外へ到達) | **他の分類 T と同じ扱い** — `/api/logout?next=<元の URL>` へ流し、`/login?next=…` へ送る ([../frontend.md](../frontend.md) §9 の分類 T 行。**`code` ごとの例外を作らない**) |
| **`AU-T-00006`** | T | 401 | 認証ミドルウェア 2 系統のうち**ユーザー側** (**アカウントが無効化されている** = `deactivated_at IS NOT NULL`。2026-08-29 の **AA-D-32**①。[../auth.md](../auth.md) §6.1 の変更点 5) | 「このアカウントは利用できません。契約内管理者にお問い合わせください」(**`AU-C-00006` = サインイン時と同一の文言**)。**セッションを破棄する** (分類 T) |
| `AU-C-00001` | C | 401 | `POST /accounts/signin` / `POST /admin/signin` (資格情報不一致) | 「メールアドレスまたはパスワードが違います」(**どちらが違うかを出さない** = AA-D-6 のマスク。フィールドに紐づけずフォーム全体のエラーとして描く) |
| `AU-C-00002` | C | 401 | `POST /accounts/signin` (**アカウントがロックされている**) | 「アカウントがロックされています。契約内管理者に解除を依頼してください」([../auth.md](../auth.md) §6.11-1 の「ロックは伝える」) |
| `AU-C-00003` | C | 401 | `POST /mfa/totp/verify` (コード不一致。**`POST /admin/mfa/totp/verify` は AA-D-22 で消滅**) | `totp_code` フィールドのエラー。**サインイン画面に戻さない** |
| `AU-C-00004` | C | **400** | `PUT /accounts/me/password` (`old_password`) / `PUT /accounts/me/email` (`password`) / `PUT /admin/admins/me/password` (`old_password`) / `PUT /admin/admins/me/email` (`password`。**2026-08-29 の AA-D-33 で追加**) | 当該フィールドのエラー (「現在のパスワードが違います」) |
| `AU-C-00005` | C | **400** | `POST /mfa/totp/reset` (`totp_code`) | `totp_code` フィールドのエラー |
| `AU-C-00006` | C | 401 | `POST /accounts/signin` (**アカウントが無効化されている**。2026-08-10 の DM-A5 補足 1) | 「このアカウントは利用できません。契約内管理者にお問い合わせください」。**`AU-C-00002` (ロック) と分ける理由**: ロックは解除 API で回復するが、**無効化は本増分に回復手段が無い** (再有効化 API を作らない = DM-A5 補足 7) ため、FE の案内文と O-4 の集計が別になる |

- **`AU-T-00004` と `AU-C-00002` を分ける理由**: 前者は「トークンを持って操作中にロックされた」
  (セッション破棄が必要)、後者は「未認証でサインインを試みた」(破棄するセッションが無い) であり、
  **FE の遷移先が違う**。O-4 の集計でも「稼働中のロック」と「ロック後のサインイン試行」を分けて数えたい
- **`AU-T-00006` を新設し、`AU-C-00006` (サインイン時の無効化) を流用しない理由** (2026-08-29 = AA-D-32):
  **`AU-C-00006` は分類 C** であり、上の FE 判定規則 2 に従って**セッションを破棄しない**。
  ミドルウェアが返す 401 でセッションを破棄しないと、**同じ 401 を返し続けるループ**になり画面から回復できない
  (判定規則 3 が明記した失敗形と同じ)。**接頭辞が分類を決める**以上、
  **同じ事象 (無効化) でも「トークンを使った操作中」と「未認証のサインイン試行」でコードを分ける**必要がある —
  これは `AU-T-00004` / `AU-C-00002` (ロック) が既に採っている形と同一である。**表示文言は同一でよい**
  (FE は分類で遷移を決め、文言はコードで引くため)
- **`AU-T-00005` (MFA ゲート) に FE の例外を作らない理由** (2026-07-31 のレビュー中 3 で確定):
  起草時は「破棄はするが `/mfa` へ誘導する」と書いていたが、**`code` の値まで見て遷移先を分ける形になり、
  FE の判定が上の 3 行で閉じなくなる** (本節が却下した「エンドポイントで分岐する」形に近づく)。
  **MFA 未検証セッションは FE の middleware が `/mfa` に留めるため** ([../frontend.md](../frontend.md) §11.2.1 の
  `MFA_PENDING_PATHS`)、**BE の `AU-T-00005` が FE に届くのは middleware を経ない想定外経路のみ**であり、
  破棄 + 再サインインで回復させるのが正しい。**`next` に元の URL を残す挙動は分類 T 共通**なので、
  MFA 検証後に元の画面へ戻る体験は失われない
- **分類 T は必ず本文を持つ** ([README.md](README.md) §2.5 の「401 は本文なし」への例外 = AA-D-9)。
  本文なしの 401 が届くのは BE の外側 (ALB・逆プロキシ) だけであり、そのときは判定規則 3 が効く
- **上表の code は実装リポの `constants` と一致していなければならない** — CI で機械照合する (§4 の D-2)

### 3.1.2 403 と 404 の評価順序 (AA-D-19)

**順序は 1 つに固定する**: **①ロール判定 (R-1) → ②所有者条件による取得 (0 件なら 404) →
③不変条件ガード (R-3。§3.4)**。判定の実体は、①が Controller / UseCase 冒頭 (認証コンテキストのロールのみを見る)、
②が Repository のクエリ条件 (`WHERE id = $1 AND contract_id = $2`。[../auth.md](../auth.md) §6.4)、
③が取得後の UseCase。

| 呼び出し元 | 指定した `{account_id}` | 結果 | 理由 |
|---|---|---|---|
| 一般メンバー | 自契約に実在 | **403** | ①で止まる |
| 一般メンバー | **他契約**のアカウント | **403** | ①で止まる (**存在の有無を判定する前**) |
| 一般メンバー | 実在しない ID | **403** | 同上 |
| 契約内管理者 | **他契約**のアカウント | **404** | ①を通過 → ②が 0 件 |
| 契約内管理者 | 実在しない ID | **404** | 同上。**上行と区別できないのが正しい状態** ([README.md](README.md) §2.5) |
| 契約内管理者 | 自契約に実在するが不変条件に反する (最後の管理者・自分自身) | **403** | ③ (§3.4 のガード表) |

- **一覧・取得系 (`GET /accounts` / `GET /accounts/{account_id}`) は①が無い** (全メンバー可) ため、
  常に②だけが効く = 他契約・不存在はどちらも 404
- **社内管理者系 (§2.4)** は契約スコープを持たない (`⑦ 全契約横断`) ため②が無く、不存在は 404。
  **①のロール判定があるのは②契約管理 4 本だけ**で、そこでのロール不足が 403 になる
  ([../auth.md](../auth.md) §5-3 の是正)。**①群 (アカウントの回復・閲覧) は①も無い** —
  `admin` ロールでも実行できるため (§2.4 冒頭 / [../auth.md](../auth.md) §6.2)、**403 を返す経路が無い**

### 3.2 サインイン〜MFA のセッション状態遷移

**状態は「トークンのクレーム 2 つ (`required_mfa_type` / `mfa_verified`)」だけで決まる**
([../auth.md](../auth.md) §6.1 のクレームを踏襲。V2-F5 / V2-F7)。

```
                         ┌──────────────────────────────────────────────┐
  (未認証)               │ POST /accounts/signin  {email, password}      │
     │                   └───────────────┬──────────────────────────────┘
     │  401 (資格情報不正 = マスク AU-C-00001 / ロック AU-C-00002。分類 C) / 429
     ▼                                   │ 200 SignInResult
  [/login]                               ▼
                          required_mfa_type == "none" ?
                            ├─ yes ──▶ 【S3: 利用可】 全ルート到達可
                            └─ no  ──▶ 【S2: MFA 未検証】
                                          到達できるのは §2.2 の 2 本のみ
                                          (他は 401 AU-T-00005 = 分類 T)
                                          │
                        mfa.registered ?  ├─ false ─▶ POST /mfa/totp/generate → {totp_url}
                                          │             (FE: /mfa/setup で QR 表示)
                                          └─ true  ─▶ (FE: /mfa でコード入力)
                                          │
                                          ▼
                              POST /mfa/totp/verify {totp_code}
                                ├─ 401 (不一致 AU-C-00003 = 分類 C。**S2 のまま**。
                                │        セッションは破棄しない) / 429 (AA-D-10)
                                └─ 200 {token(mfa_verified=true), expires_at}
                                          │
                                          ▼
                                     【S3: 利用可】
```

| 状態 | トークンのクレーム | 到達できる API | FE のルート |
|---|---|---|---|
| **S1 未認証** | トークン無し | §2.1 の公開 8 本のみ | `(auth)` グループ ([../frontend.md](../frontend.md) §11.2.2 の 1 行目) |
| **S2 MFA 未検証** | `required_mfa_type != "none"` かつ `mfa_verified = false` | §2.2 の 2 本のみ。**到達可否の判定は [../auth.md](../auth.md) §6.7 のホワイトリスト** (**§6.6 の「`/mfa` 配下のみ許可」= v2 の前方一致は採らない** — §6.6 側の書き換えは R-AA-2a④)。**他は 401 `AU-T-00005` (分類 T)** — §3.1.1 により**本文を持つ** (同 §6.6 の「401 は本文なし」への例外) | `/mfa` / `/mfa/setup` (同 2 行目) |
| **S3 利用可** | `required_mfa_type == "none"` または `mfa_verified = true` | ユーザー認証系すべて | `(app)` 配下 (同 3 行目) |

- **`POST /mfa/totp/verify` は新しいトークンを返し、有効期限はその時点から 7 日**になる
  (v2 と同じ — V2-F6)。**FE の Cookie の `maxAge` はサインイン時点から 7 日**である
  ([../frontend.md](../frontend.md) §5.2.3) ため、**MFA 検証に時間がかかった分だけ Cookie の方が先に切れる**。
  これは「Cookie が切れて再サインイン」になるだけで齟齬にはならない (逆向きだと 401 が続く)
- **`mfa.registered` を応答に含める理由**: FE が `/mfa` (検証) と `/mfa/setup` (登録) を出し分ける
  唯一の入力である ([../frontend.md](../frontend.md) §11.2.1 の `MFA_PENDING_PATHS` の 2 本)。
  **含めないと FE は 404 を受けてから登録画面へ遷移する**ことになる
- **社内管理者も同じ形**。ただし `required_mfa_type` は持たず**常に TOTP 必須** (P-5) なので、
  `mfa.registered` / `mfa.verified` の 2 値で S2 / S3 を判定する

### 3.3 パスワードリセットと招待のフロー

```
[リセット]
  POST /accounts/reset-password {email}
     │  ── アカウントが無くても 204 (存在を漏らさない。AA-D-6)
     │  ── ある場合: crypto/rand の 32 バイトトークンを生成 → **reset_password_requests.token_hash に
     │     SHA-256 ハッシュのみを保存** (1 時間有効。平文は保存しない = AA-D-5④)
     │     → 平文は Resend のメール本文にだけ載せる
     ▼
  (メール) https://<FE>/reset-password?token=…        ← 秘密は FE の URL にのみ現れる
     ▼
  POST /accounts/reset-password/confirm {token, password, confirmed_password}
     ├─ 404: 不正 / 期限切れ / 使用済み (区別しない)
     ├─ 400: 確認不一致 / 強度違反 / 旧パスワードと同一 (v2 踏襲)
     └─ 204: パスワード更新 + トークン削除 + 監査記録 (**ロックは解除しない** — AA-Q3=b。解除は管理者経由のみ)

[招待]
  POST /accounts            {name, email, auth_role, …}   → 201 Account(is_completed=false)
  POST /accounts/{id}/signup-links                        → 201 {expires_at}
     │  ── 未使用リンクを削除してから発行 (単一有効リンク。AA-D-5)
     │     1 トランザクション内で DELETE → INSERT + UNIQUE(contract_id, email) (R-AA-17)
     │  ── contract_id は発行者の契約を入れる (P-2)
     │  ── token は crypto/rand 32 バイト → base64url。DB には token_hash (SHA-256) のみ (AA-D-5④)
     ▼
  (メール) https://<FE>/signup?token=…
     ▼
  POST /accounts/signup-links/lookup {token} → 200 {email, expires_at}   ← 招待先の表示用
  POST /accounts/signup {token, password, confirmed_password}
     ├─ 404: トークン不正 / 期限切れ / 使用済み
     │       / **解決したアカウントが無効化済み (deactivated_at IS NOT NULL)** ← AA-D-32②
     │         (4 つを区別しない。同一ステータス・同一コード。パスワードは設定しない)
     ├─ 409: 既にサインアップ済み
     └─ 200 SignInResult (そのままサインイン状態にする。再入力を求めない)

[無効化 (招待の受諾より前に実行され得る。AA-D-32)]
  DELETE /accounts/{account_id}
     │  ── 1 トランザクションで:
     │     ① accounts.deactivated_at = now()
     │     ② 当該アカウント宛ての未使用 signup_links を削除 (AA-D-32③ = 多層防御。
     │        AA-D-5③ のメールアドレス変更時の削除と同じ手続き)
     ▼
  以降のリクエスト: 認証ミドルウェアが deactivated_at を見て 401 AU-T-00006 (AA-D-32①)
  以降の受諾:       ②で消えているので 404。②が漏れても AA-D-32② が 404 にする

[社内管理者のパスワード登録 (AA-D-30。2026-08-29 追加)]
  POST /admin/admins  {name, email, admin_auth_role}   → 201 InternalAdminView
                                                         (password_registered=false)
     │  ── admin_accounts の INSERT と register_admin_password_requests の INSERT を
     │     1 トランザクションで行い、コミット後にメールを送る (AA-D-26 の契約作成と同じ順序)
     │  ── token は crypto/rand 32 バイト → base64url。DB には token_hash (SHA-256) のみ
     │  ── 有効期限 7 日。パスワード列には設定しない
     ▼  (メール送信に失敗 / 届かない場合 → POST /admin/admins/{admin_account_id}/password-registrations
     │   で未使用リンクを失効させて再発行する。SuperAdmin 限定。回復手段はこれだけ = AA-D-30 却下 (d)。
     │   ── 再発行は 1 トランザクション内で DELETE → INSERT を行う (単一有効リンク。§2.3.2 の招待の
     │      再送と同じ手続き)。DB 制約 UNIQUE(admin_account_id) の要求は R-AA-33 — **制約が入るまでは
     │      この 1 トランザクションだけが担保**であり、トランザクション分離だけに頼らない (BE-11))
  (メール) https://<FE>/admin/password-registration?token=…
     ▼
  POST /admin/password-registrations/lookup {token} → 200 {email, expires_at}   ← 登録先の表示用
  POST /admin/password-registrations {token, password, confirmed_password}
     ├─ 404: 不正 / 期限切れ / 使用済み (区別しない。**設定側でも期限を見る** = AA-D-30⑤)
     ├─ 400: 確認不一致 / 強度違反
     └─ 200 AdminSignInResult + 登録要求行の削除 (削除により password_registered が true になる)
```

**`POST /accounts/signup` が `SignInResult` を返す理由**: v2 は 200 空応答のため、FE は
直後にサインインを呼ぶ必要がある (`hassan-v2-backend/controller/account.go:311`)。
**パスワードを設定した本人が同じリクエスト内で認証済みである**ことは明らかであり、
1 往復減らせる。**却下**: 204 を返してサインイン画面に送る — v2 と同じ挙動だが、
**設定したパスワードをもう一度入力させる**ことになる。

### 3.4 ロック機構の全体像 (書く側・読む側・回復側)

[../auth.md](../auth.md) §6.11-2 の「4 つを揃えて初めて成立する」に対する本書の割り当て。

| 役割 | 実体 | 本書の対応 |
|---|---|---|
| **書く側 (自動)** | サインイン失敗回数の加算としきい値超過でのロック | `POST /accounts/signin` の副作用 (v2 踏襲: `hassan-v2-backend/db/queries/account.sql:56-64`。しきい値は設定 SSOT — [../auth.md](../auth.md) §10.2 R-4) |
| **書く側 (手動)** | 手動ロック | §2.3.2 `POST /accounts/{account_id}/lock` (v3 新設) |
| **読む側** | ロック状態の可視化 | §2.3.2 `GET /accounts` の `is_locked` / `locked_at` (AA-D-7)、§2.4 `GET /admin/accounts` の `is_locked` フィルタ |
| **解除側** | 契約内管理者による解除 | §2.3.2 `DELETE /accounts/{account_id}/lock` |
| **回復側** | 契約内管理者が全員ロックされたときの回復 | §2.4 `DELETE /admin/accounts/{account_id}/lock` (社内管理者・全契約横断) |
| **回復側 (追加)** | ~~本人による回復~~ → **採用しない** (AA-Q3=b。2026-07-31 ユーザー回答) | パスワードリセットはロックを解除しない (v2 = V2-F10 と同じ)。**パスワード忘れ + 連続失敗ロックの複合ケースは「リセット後に契約内管理者へ解除を依頼」が正規手順** — 案内を出す場所は**リセット完了画面ではなく、リセット後のサインインで `AU-C-00002` (ロック) を受けた `/login` 画面**である (§3.1.1)。`POST /accounts/reset-password/confirm` は **204 固定・本文なし**で、**未認証の FE がロック状態を知る手段は無い** (知らせると AA-D-6 のマスクが破れる) |

**ガード (403 が正常系。AA-D-12)**:

| ガード | 判定 | 対象エンドポイント |
|---|---|---|
| 自分自身をロックできない | `target == caller` (**直列化不要** — 下の注記 3) | `POST /accounts/{account_id}/lock` |
| 最後の未ロック契約内管理者をロックできない | **下の `LockContractAdminsForGuardInContract` の結果のうち `last_locked_at IS NULL` かつ `id <> target` が 0 件なら 403** | 同上 |
| 最後の契約内管理者を降格できない | **同クエリの結果のうち `id <> target` が 0 件なら 403** (ロック状態は見ない = 注記 1) | `PUT /accounts/{account_id}` |
| 最後の契約内管理者を削除できない / 自分自身を削除できない | 同上 + `target == caller` | `DELETE /accounts/{account_id}` |
| ~~自分の MFA をリセットできない~~ (**AA-D-22 で消滅**) | ~~`target == caller`~~ | ~~`POST /admin/admins/{admin_account_id}/mfa/reset`~~ |

**3 ガード共通の判定クエリ (AA-D-31)** — **ロック・降格・削除の 3 経路が同一の 1 クエリで行ロックを取り、
その結果から各自の条件で数える**。**`COUNT(*)` を単独で発行しない**:

```sql
-- name: LockContractAdminsForGuardInContract :many
SELECT id, last_locked_at
FROM accounts
WHERE contract_id = $1 AND auth_role_id = 1 AND deactivated_at IS NULL
ORDER BY id
FOR UPDATE;
```

- **呼び出しは UseCase が張ったトランザクションの内側**で行い、**同一トランザクションで対象行を UPDATE する**
  ([../architecture.md](../architecture.md) §3.7 の L-6 = UseCase が `tx` を張り引数で渡す)。
  **対象エンドポイントは `PUT /accounts/{account_id}` / `DELETE /accounts/{account_id}` /
  `POST /accounts/{account_id}/lock` の 3 本**で、いずれも**トランザクション境界がガードの外側**になる
- **対象アカウント自身をロック集合から除外しない** (数えるときだけ `id <> target` で除く)。
  除外すると、管理者 2 名の契約で「A を削除」と「B を削除」が**互いに素な行集合をロックする**ため
  直列化されない (AA-D-31 の却下 (e))
- **`AND deactivated_at IS NULL` は v3 で足す**。v2 の `CountAdminsByContractID`
  (`hassan-v2-backend/db/queries/account.sql:80-81`) は物理削除前提 (`同:83-84` の `DeleteAccount`) で
  この条件を持たないが、**v3 の削除は無効化** (AA-D-13 / [../data-model.md](../data-model.md) §4.2 の DM-A5) なので、
  条件が無いと**無効化済みの管理者を「いる」と数え、並行実行でなくてもガードが素通りする**
- **クエリ名は `…InContract`** (§3.5 の脚注 1) で `WHERE contract_id = $1` を持つため、
  §3.5 の許可リストには載せない (A-4 の絞り込みは Repository のクエリ条件で行う)

> **注記 1 — `last_locked_at` の扱い**: v2 の `CountAdminsByContractID` はロック状態を見ないため、
> **管理者 3 名の契約で 2 名を順にロックするとカウントは 3 のまま全員ロックに到達する**
> ([../auth.md](../auth.md) §6.9 が指摘済み)。**ロックのガードだけが `last_locked_at IS NULL` で絞る**
> (AA-D-12 の「ロックのカウントは `AND last_locked_at IS NULL` を含める」の実現形)。
> **降格・削除のガードは v2 どおりロック状態を見ない** — 降格・削除は行そのものを変えるため、
> ロック中の管理者も「解除すれば使える管理者」として数えるのが正しい。
> **絞るのは数えるときだけで、行ロックは 3 経路とも同じ集合に掛ける** — 掛ける集合を分けると
> 「ロック」と「削除」が別々の行を掴み、**交差経路 (最後の 2 名を片方はロック・片方は削除) が直列化されない**。
>
> **注記 2 — 交差経路**: 上表の 3 ガードは**同一の不変条件**「契約内に有効な (`deactivated_at IS NULL`)
> 管理者が 1 人以上おり、そのうち少なくとも 1 人が未ロックである」を守る。
> したがって **`PUT`×`PUT` / `DELETE`×`DELETE` / `PUT`×`DELETE` / `lock`×`PUT` / `lock`×`DELETE` の
> 全組み合わせ**が上記 1 クエリで直列化される。**降格・削除は「有効な管理者 ≧ 1」まで、
> ロックは「未ロックの有効な管理者 ≧ 1」まで**を保証する。
>
> **注記 3 — TOCTOU を持たないガード (対象外の明示)**: 「自分自身をロックできない」「自分自身を削除できない」は
> **認証コンテキストの `account_id` と path param の比較**であり、判定の入力に他トランザクションが
> 書き込める共有状態が無いため、直列化の対象外とする。**`POST /accounts` の人数上限 409**
> ([../data-model.md](../data-model.md) §4.2 の DM-A5 補足 6) は本節のガードではないが同型の
> TOCTOU を持つ — **本増分では扱わず、§6.2 の要確認に残す** (超過の帰結が「有効な管理者 0 人」と違い可逆であるため)。

### 3.5 [../auth.md](../auth.md) §6.4 の許可リストへ登録する認証系クエリ (R-3 の必須事項②)

**形式は `ファイルパス + クエリ名 + 種別 + 理由`** (同節)。**下表が本書のエンドポイントが直接使うクエリの全件**
であり、**これ以外の認証系クエリは所有者条件 (`account_id` / `contract_id`) を持つため許可リストに載せない**。
**許可リストは CODEOWNERS 承認を要する CI ゲート** ([../auth.md](../auth.md) §6.4) なので、
**漏れは「実装時に PR が止まる」形で現れる** — 実装時に本表に無いクエリが必要になったら、
本書 §3.5 と許可リストを**同じ PR で**更新する。

| クエリ名 (v3) | 種別 | 理由 | 契約検証の箇所 |
|---|---|---|---|
| `GetAccountByEmailForSignIn` | ① 未認証経路 | サインインは email でしか引けない | — |
| `GetAccountByEmailForPasswordReset` | ① 未認証経路 | リセット要求。**サインインとクエリを分ける** (呼び出し元が未認証専用であることを名前で示す — [../auth.md](../auth.md) §6.4 ③の但し書き) | — |
| `GetSignupLinkByTokenHash` | ① 未認証経路 | 招待リンクは**トークンの SHA-256 ハッシュ**で引く (`WHERE token_hash = $1`。AA-D-5④)。**`contract_id` を持つが引く条件にはできない** (P-2) | 解決後に `accounts` を `(contract_id, email)` で引く (AA-D-5) |
| `GetResetPasswordRequestByTokenHash` | ① 未認証経路 | リセットトークンの**ハッシュ**で引く (`WHERE token_hash = $1`。v2 の `hash` 列を **`token_hash` へ改名** = AA-D-5④(iii) / [../data-model.md](../data-model.md) §4.2) | — |
| `GetAdminAccountByEmailForSignIn` | ① 未認証経路 | 社内管理者のサインイン | — |
| **`GetRegisterAdminPasswordRequestByTokenHash`** | ① 未認証経路 | 社内管理者のパスワード登録リンクを**トークンの SHA-256 ハッシュ**で引く (`WHERE token_hash = $1`。AA-D-30②)。**`lookup` と設定の両方が使い、どちらも `expired_at` を判定する** (AA-D-30⑤) | — (`register_admin_password_requests` は契約に属さない — [../data-model.md](../data-model.md) §4.1.2 (a)) |
| **`DeleteRegisterAdminPasswordRequestByTokenHash`** | ① 未認証経路 | `POST /admin/password-registrations` が設定後に登録要求を削除する (v2 も同じ — `hassan-v2-backend/usecase/admin_account/register_password.go:52`)。**この削除が `password_registered` の導出の書き手**である (§2.5 = BE-10) | 同上 |
| `DeleteSignupLinkByTokenHash` (**招待受諾時**) | ① 未認証経路 | `POST /accounts/signup` が受諾後にリンクを削除する (V2-F2)。**未認証経路からの DELETE** であり、下の「載せないもの」の `signup_links` (**認証済みの発行・失効**) とは別物 | トークンから解決済みの `(contract_id, email)` に一致する行のみを削除する |
| `UpsertAuthRateLimitCounter` / `GetAuthRateLimitCounter` | ① 未認証経路 | レート制限のカウンタ (§3.7 の 11 本)。**キーは `bucket_key` (IP / メールアドレス / `account_id` + エンドポイント) であり所有者条件を持ち得ない**。テーブルは [../data-model.md](../data-model.md) §4.2 の `auth_rate_limit_counters` | — (テナントに属さない) |
| `GetAccountByIDForAuth` | ② 所有者を決定 | 認証ミドルウェアが `user_uid` からアカウントを引く。**選択列に `last_locked_at` と `deactivated_at` を含める** — ミドルウェアの判定 f・g がこの 1 行だけを見て済むようにするため ([../auth.md](../auth.md) §6.13.2。**クエリを増やさない** = AA-D-32 の代償評価の前提) | — |
| `GetAdminAccountByIDForAuth` | ② 所有者を決定 | 社内管理者側のミドルウェア | — |
| `ExistsAccountByEmail` | ③ グローバル一意性 | メール重複確認。**bool のみを返す** (メンバー作成・メール変更・権限変更の 3 経路が使う) | — |
| `GetAuthRoleByID` | ④ マスタ参照 | `auth_roles` はテナントに属さない | — |
| `GetContractByID` | ⑤ 頂点テーブル | `GET /contract` とメンバー作成時の人数上限確認 | 引数は認証コンテキスト由来の `ContractID` のみ |
| `ListAccountsForAdmin` / `SearchAccountsForAdmin` | ⑦ 全契約横断の運用操作 | 社内管理者のアカウント検索 (§2.4) | 認可は §6.7 の系統で担保 |
| **`UnlockAccountByIDForAdmin`** (`WHERE id = $1`) | ⑦ 全契約横断の運用操作 | 社内管理者による解除 (§2.4。v2 の実例と同一 — `hassan-v2-backend/db/queries/account.sql:73-78`)。**契約内管理者の解除は別クエリ `UnlockAccountByIDInContract` を使う** (下の「載せないもの」) | 同上 |
| **`DeleteAccountMfaConfigForAdmin`** (`WHERE account_id = $1`) | ⑦ 全契約横断の運用操作 | 社内管理者による一般アカウントの MFA リセット (§2.4。AA-Q2)。**契約内管理者の MFA リセットは別クエリ `DeleteAccountMfaConfigByAccountID`** (下の「載せないもの」+ 脚注の 2 段検証) | 同上 |
| `admin_accounts` / `admin_auth_roles` / **`register_admin_password_requests` の認証済み経路のクエリ** (作成時の発行・再発行時の失効と発行・`password_registered` の導出) の全クエリ | ⑦ 全契約横断の運用操作 | **社内管理者系テーブルは契約に属さない** ([../auth.md](../auth.md) §6.3 の例外)。`admin_account_id` は所有者列として認識されない。**`admin_mfa_configs` の定義は [../data-model.md](../data-model.md) §4.2 に反映済み** (2026-07-31。§5 R-AA-18 = 実施済み) | 同上 |

**許可リストに載せないもの (誤登録を防ぐため明記する)**:

| クエリ | 検査を通る理由 |
|---|---|
| `account_mfa_configs` / `reset_password_requests` の**認証済み経路のクエリ** | `WHERE account_id = $1` を持つ。**`contract_id` 列が無いことはスキーマ側の例外** ([../data-model.md](../data-model.md) §4.1.2 (b)) であり、**クエリ側の例外ではない**。所有者条件としては `account_id` の方が狭い |
| 契約内管理者のロック / **解除 (`UnlockAccountByIDInContract`)** / メンバー取得・更新・削除 | `WHERE id = $1 AND contract_id = $2` を持つ ([../auth.md](../auth.md) §6.9 の決定どおり)。**社内管理者経路とはクエリ名を分ける** (上表の `…ForAdmin`) |
| **不変条件ガードの行ロック (`LockContractAdminsForGuardInContract`。AA-D-31)** | `WHERE contract_id = $1` を持つ (§3.4)。**`FOR UPDATE` を伴うが所有者条件の有無という判定基準は変わらない**。**v2 の `CountAdminsByContractID` を置き換える** — 同名を残すと「`COUNT` だけ撃つ実装」が復活し得るため、v3 は `COUNT` クエリ自体を作らない |
| 契約内管理者の **MFA リセット (`DeleteAccountMfaConfigByAccountID`)** | `WHERE account_id = $1` を持つ。**ただし `account_mfa_configs` は `contract_id` を持たない**ため ([../data-model.md](../data-model.md) §4.1.2 (b))、**このクエリ単体では契約検証にならない** — **契約検証は下の脚注の 2 段手順で担保する** (SQL 検査は「所有者条件あり」として通してしまうため、**検査だけに頼らない唯一の行**である) |
| `signup_links` の発行・失効 (**認証済み経路**。`POST /accounts/{account_id}/signup-links` / **メールアドレス変更時 (AA-D-5③)** / **無効化時 (`DELETE /accounts/{account_id}`。AA-D-32③)**) | `WHERE account_id`/`contract_id` 条件を持つ (実行者の契約が確定している)。**招待受諾時の削除は未認証経路なので上表に載せる** |
| `GetCompanyByContractID` / `UpdateCompanyByContractID` (**upsert ではない** = AA-D-14) | `contract_id` を持つ |

> **脚注 1 — クエリ名を経路ごとに分ける理由 (2026-07-31 のレビュー重大 4)**:
> [../auth.md](../auth.md) §6.4 は「**許可リストは「そのクエリを許可する」だけで呼び出し元を制約しない**」と
> 明記している (同節の種別⑦の「理由」欄。**同一リポ内の参照は節番号で引く** — 行番号は別セッションの改訂でずれる)。
> したがって **1 つのクエリ名を契約内管理者経路と社内管理者経路で
> 共有すると、契約内管理者の UseCase が `WHERE id = $1` のクエリ (許可済み) を呼んでも
> ①SQL 検査 (所有者条件の有無) ②許可リスト検査の**どちらも通る** —
> **V2-D4 / [../auth.md](../auth.md) §5-11 (ロック解除がテナント境界を越える) が CI を通ったまま復活する**。
> `…ForAdmin` / `…InContract` と**名前で系統が読める形にする**ことで、
> 「許可リストに載っているクエリ名を契約内管理者の UseCase が参照していないこと」を
> **grep 可能な機械検査にできる** (検査の追加要求は §5 **R-AA-20**、CI ゲートは §4 の D-2 ④)。
>
> **脚注 2 — `contract_id` を持たないテーブルを契約内管理者が触るときの必須手順 (2 段)**:
> `account_mfa_configs` は `account_id` のみを持つため、`WHERE … AND contract_id = $2` を書くことが
> **構造的に不可能**である。契約内管理者の `POST /accounts/{account_id}/mfa/reset` は次の順序を必須とする。
> **1 段目を省いた実装は「存在確認は所有権の検証にならない」(A-4) の変形になり、
> 他契約のメンバーの MFA を解除できる穴になる**。
>
> 1. `accounts` を **`WHERE id = $1 AND contract_id = $2`** で引く。**0 件なら 404** (§3.1.2 の②)
> 2. **その戻り値から作った `AccountID`** ([../auth.md](../auth.md) §6.4 ②の `NewAccountIDInContract` を
>    通した型。path param の生値を渡さない) を引数に `DeleteAccountMfaConfigByAccountID` を呼ぶ
>
> **この 2 段は `account_mfa_configs` に限らず、[../data-model.md](../data-model.md) §4.1.2 (b) の
> 「所有者列を持つが `contract_id` を持たない」テーブル全般に適用する例外規則**である。
> 振る舞いは §7.3 の UT ケース 3 で固定するが、**UT 1 本に依存させず上記の機械検査 (R-AA-20) と対で担保する**。

### 3.6 E2E 専用アカウントの MFA 例外の表現 (P-4 = [../testing.md](../testing.md) T-Q3 への回答)

**専用のフラグ・コード分岐を一切作らない**。MFA の要否は**会社単位の既存設定** (`companies.mfa_type`。
V2-F5) で決まるため、**E2E 専用契約の `companies.mfa_type = 'none'` にするだけで足りる**。

| 項目 | 決定 |
|---|---|
| 例外の表現 | **`companies.mfa_type = 'none'`** (v2 の既定値と同じ。実顧客契約でも取り得る正当な設定) |
| コードへの影響 | **なし**。`if isE2E` のような分岐を作らない (**無言の裏口を作らないための最重要点**) |
| 歯止め① | E2E 用のシードは **dev 専用のシードスクリプト 1 本**に閉じ、**`APP_ENV != dev` なら実行前に異常終了する** |
| 歯止め② | **prod の初期スキーマ投入 (RL-2) にシードを含めない** ([../data-model.md](../data-model.md) §6.3 / [../operations.md](../operations.md) §6.1 の RL-2 完了条件はスキーマのみ) |
| 歯止め③ | CI で **prod 向けデプロイジョブが E2E シードスクリプトを参照していないこと**を検査する (D-2 のマージ条件に追加) |
| 資格情報 | dev の Secrets Manager ([../testing.md](../testing.md) §7.3) |
| 代償 | E2E は MFA 画面遷移を担保しない (同節が受容済み)。**§3.2 の S2 → S3 遷移は UT / I 段で検証する** |

**却下 (a) `accounts` に `mfa_exempt` フラグを足す**: **prod のコードに「MFA を免除する分岐」が常設される**。
フラグが 1 行入った瞬間に、それを true にできる経路 (移行スクリプト・DB 直更新) が MFA の迂回路になる。
[../data-model.md](../data-model.md) §4.2 の「v2 に無い列を足さない」にも反する。
**却下 (b) 環境変数で MFA を全体無効化する**: dev 全体で MFA が検証されなくなり、
**dev で一度も通らない経路が prod で初めて動く**。

> **メール到達を前提とするフロー (招待受諾 / パスワードリセット) は本節の対象外**。
> MFA と違い「送らない」で代替できない (トークンの到達がフローの本体) ため、
> **E2E では扱わず I 段で担保する**というのが本書の仮定である (§6.2 **AA-Q5**)。
> dev の送信ポリシーとテストのトークン取得経路は同項の未確定事項。

### 3.7 監査記録とレート制限の対象 (O-6 / O-4)

**記録項目・`action` の値域の SSOT は [../observability.md](../observability.md) §4.5**。
本書は**どのエンドポイントが何を記録するか**を列挙する (値域への追加要求は §5 R-AA-7)。

> **委譲先の受け皿の状態 (2026-07-31 再確認 → 2026-08-14 の AA-D-24 で更新)**:
> ①**`action` の値域表は [../observability.md](../observability.md) §4.5.1 として新設済み**
> (Go の定数 1 箇所を SSOT + CI 照合。`activity_logs.action` は [../data-model.md](../data-model.md) §4.10 のとおり
> `text` のままで `CHECK` は張らない = DM-15 と整合)。**本表は 2026-08-10 の AA-D-23 で絞られた後、
> 2026-08-14 の AA-D-24 で 4 行が復帰した** (**行数は下表が定義元** — 転記しない = DR-9)。**値域の不足は無い** —
> v2 由来の 6 種に加え、**復帰した 4 種 (`member_create` / `account_update_email` / `account_update_password` /
> `contract_update_mfa`) とリセット要求 (`account_request_reset_password`) も §4.5.1 に登録済み** (2026-08-23 に後者の欠落 = BE-10 を是正)。
> **§5 R-AA-7③ (v3 独自事象の値域追加要求) の取り下げは、真に v3 独自の事象についてのみ有効** (R-AA-7 の状態列を参照)
> ②**actor / contract が確定しない事象 (未登録メールへのサインイン失敗) を書けるスキーマは
> [../data-model.md](../data-model.md) §4.10 に反映済み** (`actor_type = 'unauthenticated'` + `CHECK`)。
> 判断は **AA-D-21**、**残る差分は `detail.email_hash` の方式のみ** (同節の例が pepper 無しの SHA-256。
> 本書と [../observability.md](../observability.md) §4.5.2 は HMAC-SHA256 + pepper) — 要求は §5 **R-AA-19**。

| エンドポイント | 記録する事象 | v2 の前例 |
|---|---|---|
| `POST /accounts/signin` | 成功 / 失敗。**失敗はメールアドレスを平文で保存せず `detail.email_hash` (HMAC-SHA256 + pepper) に入れる**。**メールアドレスに該当するアカウントが存在しなかった失敗 (未登録メール) は `actor_type = 'unauthenticated'` として `actor_id` / `contract_id` を両方 NULL にする** (AA-D-21②。スキーマは [../data-model.md](../data-model.md) §4.10 に反映済み。残る要求 = R-AA-19 の `email_hash` 方式)。**DB エラー等、システム側の理由で引き当て自体が失敗し主体を確定できない場合は `activity_logs` に書かない** — WARN ログ + 5xx メトリクス (AL-1) で観測する。**この線引きの SSOT は [../observability.md](../observability.md) §4.5.2** (2026-08-29 に実装リポ hassan-v3 の `blocked-by-design` issue #127 からの照会を受けて確定。却下案と理由は同節) | `signin_success` / `signin_failed` (V2-F17) |
| `POST /mfa/totp/verify` | 成功 / 失敗 | `mfa_verify_success` / `mfa_verify_failed` |
| `POST /accounts/{id}/mfa/reset` | 実行 (actor = 契約内管理者) | `mfa_reset_by_admin` |
| `POST /admin/accounts/{id}/mfa/reset` | 実行 (actor = `admin_accounts.id`) | `mfa_reset_by_aillio_admin` |
| `POST /accounts/reset-password` | 要求 | v2 は `event_logs` に要求のみ (`hassan-v2-backend/usecase/account/request_reset_password.go:56`) |
| `POST /accounts` (メンバー作成・招待発行) | 実行 (actor = 契約内管理者) | `member_create` (`hassan-v2-backend/auth/event_mapper.go:62`)。**2026-08-14 の AA-D-24 で復帰** |
| `PUT /accounts/me/email` | 実行 | `account_update_email` (`hassan-v2-backend/auth/event_mapper.go:73`)。**2026-08-14 の AA-D-24 で復帰** |
| `PUT /accounts/me/password` | 実行 | `account_update_password` (`hassan-v2-backend/auth/event_mapper.go:74`)。**2026-08-14 の AA-D-24 で復帰** |
| `PUT /company/mfa` | 実行 | `contract_update_mfa` (`hassan-v2-backend/auth/event_mapper.go:67`)。**2026-08-14 の AA-D-24 で復帰**。**パスは 2026-08-15 の AA-D-25 で `/companies/me/mfa` から改名** |
| `POST /admin/contracts` (契約の新規作成) | 実行 (actor = `admin_accounts.id`。`actor_type = 'admin_account'` / `contract_id` = 作成した契約) | **v2 に前例が無い** (`event_mapper.go` は社内管理者経路を通らない) — **AA-D-23 / AA-D-24 のスコープ限定に対する明示の例外として 2026-08-25 に追加した** (AA-D-26)。**契約作成は不可逆かつ課金に直結する操作**であり、実行者が追えないことの代償が「v2 相当に留める」原則より大きい。値域 `contract_create` は [../observability.md](../observability.md) §4.5.1 に登録する |
| `POST /admin/contracts/{contract_id}/signup-links` (招待の再発行) | 実行 (actor = `admin_accounts.id`。`actor_type = 'admin_account'` / `contract_id` = 対象の契約) | **v2 に前例が無い** — **AA-D-27 で追加した** (2026-08-26)。**招待リンクの再発行は不可逆ではない**が、**誰がいつ契約の入口を作り直したかは追えるべき**である (代表者のメールアドレスに届く URL を新しく発行する操作であり、`POST /admin/contracts` と同じ性質の入口を開く)。値域 `contract_invitation_resend` は [../observability.md](../observability.md) §4.5.1 に登録する |
| `POST /admin/admins` (社内管理者の作成) | 実行 (actor = 実行した SuperAdmin の `admin_accounts.id`。`actor_type = 'admin_account'` / **`contract_id` は NULL** = 契約に属さない操作。AA-D-21① の `CHECK` は `actor_type` を条件にしているため、**`admin_account` では `contract_id` が NOT NULL 側に入る** → **本行は同 `CHECK` に抵触する**。是正要求は §5 **R-AA-30**) | **v2 に前例が無い** — **AA-D-29 で追加した** (2026-08-29)。**全契約横断の権限を持つ主体が増える操作**であり、AA-D-26 が契約作成について述べた「実行者が追えないことの代償」がより強く当てはまる。値域 `admin_account_create` は [../observability.md](../observability.md) §4.5.1 に登録する |
| `POST /admin/admins/{admin_account_id}/password-registrations` (登録リンクの再発行) | 実行 (同上。`contract_id` は NULL = R-AA-30 の対象) | **v2 に前例が無い** — **AA-D-30 で追加** (2026-08-29)。**AA-D-27 (契約の招待の再発行) と同じ理由** — 不可逆ではないが、**社内管理者アカウントの入口を作り直す操作**であり、誰がいつ再発行したかは追えるべきである。値域 `admin_account_password_reissue` は [../observability.md](../observability.md) §4.5.1 に登録する (§5 R-AA-31)。**`POST /admin/password-registrations` (本人による設定) は記録しない** — 招待の受諾を記録しないのと同じ扱い (下の 2026-08-10 の注記) |
| `PUT /admin/admins/{admin_account_id}` (社内管理者の権限変更) | 実行 (同上。`admin_auth_role` の変更前後を `detail` に入れる) | **v2 に前例が無い** — **AA-D-29 で追加**。**`admin` → `super_admin` の昇格は権限の自己増殖経路**になり得るため、変更前後を記録する。値域 `admin_account_update` は同 §4.5.1 に登録する |

> **2026-08-10 (AA-D-23): 監査ログを v2 相当に留め、v3 での拡張を行わない** (ユーザー決定)。
> **⚠ 2026-08-14 の AA-D-24 で当時の削除対象のうち 4 件が復帰した** (上表参照) —
> 「いずれも v2 に前例が無い」という当時の判定は**一部誤認**だった (§7 の AA-D-24 が経緯の正)。
> **現在も記録しない対象**: `POST /admin/signin` の成否 / ロック・解除 (`POST`・`DELETE /accounts/{id}/lock`、`DELETE /admin/accounts/{id}/lock`) /
> 招待の受諾 / パスワードリセットの**実行** — **ここまでは v2 に前例が無く C-16 の対象外**。
> **権限変更 (`member_update_by_admin`) と削除 (`member_delete_by_admin`) は v2 に前例がある** (`hassan-v2-backend/auth/event_mapper.go:63-64`) —
> **記録しないことは C-16 に対する後退であり、2026-08-14 にユーザーが「スコープを広げない」として承認済み** (AA-D-24 の却下 (b))。
> **帰結として §5 の R-AA-7③ (不足 7 値の追加要求) は取り下げる** — 追加する `action` 値が無くなったため。
> **失うもの (先送り先を明示する)**: ①**`POST /admin/signin` の失敗が記録されないため、O-7 のアラート入力
> 「社内管理者のサインイン失敗」が成立しない** — 是正要求は §5 **R-AA-26** ([../observability.md](../observability.md) §4.6 の AL-7 は有効なまま)。
> ②**ロック・削除・権限変更という不可逆操作の実行者が追跡できない**。再開する場合は本表に行を戻すだけでよい (§6.1 の AA-Q14)。
>
> **2026-08-14 (AA-D-24): 上記「いずれも v2 に前例が無い事象」は誤りだった**。
> `hassan-v2-backend/auth/event_mapper.go` を直接確認すると、**メンバー作成・メール変更・パスワード変更・
> `PUT /companies/me/mfa` (現 `/company/mfa` — AA-D-25) の 4 件には明確な前例があった** (上表に行を追加して復帰)。
> **`member_update_by_admin` (権限変更等) / `member_delete_by_admin` (メンバー削除) にも前例はあるが、
> ユーザーが引き続き記録対象に含めない判断をした** (事実誤認ではなく意図的なスコープ限定として維持)。
> `POST /admin/signin` の成否・ロック・解除・招待の発行・受諾・パスワードリセットの**実行**については
> 「v2 に前例が無い」の判定は変更なし (再確認済み)。

> **記録するのは成功した実行だけである** (2026-08-29 に明示 = 同日のレビュー 軽微 4)。
> **409 (重複) / 403 (`admin` ロールが SuperAdmin 限定操作を叩いた) / 400 は `activity_logs` に書かない** —
> `activity_logs` は「**実行された事実**」の台帳であり (v2 相当に限定 = AA-D-23)、**拒否された試行は
> O-4 の観測側 (WARN 構造化ログ + ステータス別メトリクス) で数える** (本節末尾の「O-4 として観測する失敗」)。
> **権限昇格の試行痕跡は「403 の件数を `admin_account_id` 付きの WARN ログで観測する」形で残す** —
> 監査台帳に混ぜると「実行された操作の一覧」を読むクエリが試行で汚れる。**再開する場合の入口**: §6.1 の AA-Q14。
>
> **§2.4 の④群 (自己管理 3 本 = AA-D-33) は記録しない** — **v2 の `event_mapper.go` は社内管理者経路を
> 通らない**ため前例が無く (`hassan-v2-backend/auth/event_mapper.go` に `PUT /admin/accounts/*` の
> エントリは無い)、AA-D-23 / AA-D-24 のスコープ限定に従う。**ユーザー側の同等操作
> (`PUT /accounts/me/email` / `/password`) は前例があるので記録する**という非対称は、
> 「v2 に前例があるか」だけで決めた結果であり意図的である。

**レート制限の対象 (計 14 本。AA-D-10)**:

| # | 対象 | キー |
|---|---|---|
| 1-8 | §2.1 の**公開 8 本** (**2026-08-29 に AA-D-30 の 2 本を追加して 6 → 8**) | IP + エンドポイント (リセット要求・サインインはメールアドレス単位も併用。[../auth.md](../auth.md) §6.11-3) |
| 9 | §2.2 `POST /mfa/totp/verify` | `account_id` + エンドポイント |
| 10 | §2.3.1 `PUT /accounts/me/password` (`old_password` の総当たり) | `account_id` + エンドポイント |
| 11 | §2.3.1 `PUT /accounts/me/email` (`password` の総当たり。**成功するとリセット経路ごと奪われる**) | 同上 |
| 12 | §2.3.1 `POST /mfa/totp/reset` (`totp_code` の総当たり) | 同上 |
| 13 | §2.4 の④ `PUT /admin/admins/me/password` (`old_password` の総当たり。**2026-08-29 に AA-D-33 で追加**) | `admin_account_id` + エンドポイント |
| 14 | §2.4 の④ `PUT /admin/admins/me/email` (`password` の総当たり。**成功すると全契約横断の権限を持つアカウントのメールアドレスが奪われる**) | 同上 |

> **`POST /admin/admins/{admin_account_id}/password-registrations` (再発行) を対象に含めない理由**:
> **SuperAdmin 認証が必要**で、総当たりの入力 (パスワード・コード・トークン) を受け取らない。
> **AA-D-27 の `POST /admin/contracts/{contract_id}/signup-links` (招待の再発行) と同じ扱い**である。
> **メール連投の抑止は §6.11-3 の対象①が公開 2 本を見ることでは担保されない**点は認識しておく
> (再発行はメールを送るが認証済み経路)。**濫用は O-6 の監査記録 (§3.7 の同エンドポイントの行) で追う**。

**しきい値・保管先・fail-closed 時の挙動は [../auth.md](../auth.md) §6.11-3 が SSOT** (本書では決めない)。
**10-12 は 2026-07-31 のレビュー指摘 (S-3) で追加**した。**2026-08-10 に `POST /admin/mfa/totp/verify` が
AA-D-22 で消滅したため 11 本 → 10 本。2026-08-29 に AA-D-30 の公開 2 本が加わり 10 本 → 12 本、
同日の AA-D-33 で 13・14 が加わり 12 本 → 14 本** (**SSOT 側 = [../auth.md](../auth.md) §6.11-3 の
対象② の列挙にも同じ差分で 2 本を追加した**)。**転記先 2 箇所 ([README.md](README.md) §0 の差分注記と §2.5 の 429 行)
を同じ差分で更新した** (§5 R-AA-2b ②)。**この数は現時点では機械照合の対象外**なので、照合の追加を §5 **R-AA-25** で要求する。

**O-4 として観測する失敗**: 429 の発生件数 / **401 と 400 の内訳を §3.1.1 の `code` 単位で数える**
(`AU-T-*` = トークン失効の内訳 / `AU-C-*` = 資格情報不一致の内訳。**分類 T と C を混ぜて数えない** —
`AU-C-00003` の急増は総当たり、`AU-T-00002` の急増はトークン寿命の設定ミスと、原因が別物になる。
AA-D-9 / AA-D-17) / メール送信の失敗 (Resend の応答。**握り潰さない** —
v2 は招待メール送信失敗時にリンクを保存しないまま 500 を返す
`hassan-v2-backend/usecase/account/create_signup_link.go:80-82`)。

---

## 4. 本番観点への回答

| ID | 状態 | 回答 |
|---|---|---|
| **A-1** 認証方式 | **回答** | §2 の全エンドポイント (**本数は同書 §2 の見出しが正** — 2026-08-10 に 37 → 33。DR-9) に**要求する認証系統を宣言**した (§2.1〜§2.4 の節構成 = ホワイトリストの元表)。方式の SSOT は [../auth.md](../auth.md) §6.1、系統の機械検査は同 §6.7。**公開は 8 本のみ**で、うち 4 本は v2 と同一の公開範囲、`POST /admin/signin` は同 §6.2 の例外、`POST /accounts/signup-links/lookup` は v2 の `GET …/:id` の置き換え (AA-D-4)、**`POST /admin/password-registrations/lookup` / `POST /admin/password-registrations` は v2 の `GET /admin/accounts/register/password/check` / `POST /admin/accounts/register/password` の置き換え** (2026-08-29 の **AA-D-30**。公開面が 6 → 8 に増えることが同判断の代償 (i))。**無効化済みアカウント (`accounts.deactivated_at`) の拒否は、トークンを使う経路 (認証ミドルウェア = `AU-T-00006`) を主対策とし、未認証のトークン発行経路 2 本 (`POST /accounts/signin` = `AU-C-00006` / `POST /accounts/signup` = 404) でも拒否する** (2026-08-29 の **AA-D-32**。[../auth.md](../auth.md) §6.1 の変更点 5)。**`POST /mfa/totp/verify` は §2.2 = 認証必須なのでミドルウェアが先に止める**。**社内管理者側 (`admin_accounts`) に無効化の概念は無い** ([../data-model.md](../data-model.md) §4.2 は `deactivated_at` を `accounts` にのみ足す)。**AC-1.1** |
| **A-2** ロールと適用範囲 | **回答** | ①**一般ユーザー** (`AuthRoleUser`) = §2.2 / §2.3 ②**契約内管理者** (R-1) = §2.3 の 8 本が 403 ③**社内管理者** (`X-Admin-Token`) = §2.4 の 16 本 ④**SuperAdmin** (R-4) = §2.4 の②契約管理 5 本 (**2026-08-25 の AA-D-26** / **2026-08-26 の AA-D-27**) と**③他の管理者アカウントの管理 3 本** (**2026-08-29 の AA-D-29** と、同日の **AA-D-30** による登録リンクの再発行 1 本)。**§2.4 の④自己管理 3 本 (2026-08-29 の AA-D-33) は R-4 の対象外** — **`admin` ロールでも実行できる** (**v2 の実挙動どおり**。`hassan-v2-backend/router/router.go:202-204` にロール判定が無い)。**自分自身の記録の変更**であり他者の権限を変えないため、③と分けた (**したがって 403 の本数は 16 本のまま増えない**)。**対象は JWT の `admin_account_id` から解決し、パス・ボディで受け取らない** (V2-D7 の解消 = A-4 の社内管理者版)。`POST /admin/admins/{id}/mfa/reset` は AA-D-22 で消滅したため、SuperAdmin 限定の対象はこの 2 群に入れ替わった。**v2 で管理者限定だった操作 (V2-F12) はすべて維持している**が、**契約管理だけは v2 の実挙動 (Admin でも実行可) より狭めた** — v2 自身の宣言 (`hassan-v2-backend/entity/admin_auth_role.go:7-10` の「Admin: Read 機能を利用可能」) に合わせた結果であり、**C-16 に対する意図的な後退**として AA-D-26 の却下 (d) に記録した ([../auth.md](../auth.md) §9.3 Q-A2) |
| **A-3** テナント境界 | **参照** | スキーマは [../data-model.md](../data-model.md) §4.2 が SSOT。本書が前提にするのは **`signup_links.contract_id NOT NULL`** (P-2) と **`accounts.email` のグローバル一意** (V2-F4) の 2 点。**スキーマへの追加要求と状態は §5 の表が定義元** (件数を転記しない = DR-9。以下は内訳): 新テーブル = `account_deletions` (§5 R-AA-4。**未対応 = DM-Q2 待ちの条件付き**) / **`admin_mfa_configs`** (**R-AA-18 = 実施済み**。§4.1.2 (a) 側 = 所有者列を持たない例外。除外リストも 9 件へ連動済み)、列の追加・変更 = **`signup_links.token_hash` / `reset_password_requests.hash` → `token_hash`** (R-AA-21 = 実施済み) / **`register_admin_password_requests.token` → `token_hash`** (**R-AA-5 = 2026-08-29 実施済み。AA-D-30②**) / **`activity_logs` の `actor_type` に `unauthenticated` を追加 + `actor_id` / `contract_id` の NULL 可 + CHECK** (R-AA-19 = **スキーマは実施済み。残るは `detail.email_hash` の方式**) |
| **A-4** 絞り込みの層 | **回答** | ①対象は常に path param (AA-D-3) で、**[../auth.md](../auth.md) §6.4 の②コンストラクタ `NewAccountIDInContract` を通してからでないと型が作れない** ②テナント検証は Repository のクエリ条件 (`WHERE id = $1 AND contract_id = $2`) ③**許可リストに載せる認証系クエリを §3.5 で全件確定** (R-3 の必須事項②) ④**全契約横断クエリと契約内クエリはクエリ名を分ける** (`…ForAdmin` / `…InContract`。§3.5 の脚注 1) ⑤**`contract_id` を持たないテーブル (`account_mfa_configs` 等) は「親を契約条件で引いて 404 判定 → その戻り値から作った ID で子を操作」の 2 段**を必須手順とする (§3.5 の脚注 2。**存在確認は所有権の検証にならない**) ⑥**不変条件ガード (R-3) の判定は UseCase が張ったトランザクションの内側で、`FOR UPDATE` 付きの `…InContract` クエリを使って行う** (§3.4 / **AA-D-31**) — **絞り込み (`contract_id`) は Repository のクエリ条件のまま**で②から変わらないが、**判定と更新の間に他トランザクションを割り込ませない責務が UseCase 側にある**ことを明示する ([../architecture.md](../architecture.md) §3.7 の L-6)。**AC-1.2 の補完** |
| **A-5** ステータスコード | **回答** | §2 の各表の「固有ステータス」列 + §3.1 + **§3.1.1 (401/400 の分類とコード値域)**。判定規則の SSOT は [../auth.md](../auth.md) §6.6。**403 と 404 の評価順序は §3.1.2 で固定**。**同節・[README.md](README.md) §2.5 に対する差分 3 点**: ①**401 に本文を持ち、分類 T / C を `code` の接頭辞で表す** (AA-D-9 / AA-D-18。**認証済み経路の資格情報不一致は 400** = AA-D-17) ②**429 を返す 14 本** (§3.7。AA-D-10。**2026-08-29 に AA-D-30 の公開 2 本で 10 → 12、同日の AA-D-33 の自己管理 2 本で 12 → 14**) ③**不変条件ガードの 403 (R-3。6 ケース)** (AA-D-12)。差分は §5 **R-AA-2a** (auth.md §6.6。未対応) / **R-AA-2b** (README.md §2.5。実施済み) で SSOT へ是正要求。**AC-1.4** |
| **A-6** LLM への越境 | **対象外 (理由あり)** | **本書のエンドポイントに LLM 経路は無い**。唯一の候補 `GET /companies/genai` は §2.7 のとおり [../llm-migration.md](../llm-migration.md) へ先送り。**移植する場合も `gateway/` 経由必須** ([../architecture.md](../architecture.md) §3.8) |
| **A-7** 共有・公開 | **回答** | 本書は共有機能を持たない。**v2 の `sharing_settings` を応答から落とす** (AA-D-15) ことで、[../auth.md](../auth.md) §6.12 の「契約単位の共有既定は `/settings/workspace` が持ち、per-resource の可視性は各リソースが持つため、契約情報の応答に共有設定を載せる必要が無い」と整合させた (旧根拠「§7 の共有機能なし」は §6.12 の新設で撤回済み — [../auth.md](../auth.md) §10.4 R-11)。テーマ・アセットの `visibility` (列・書き込み API とも) は**増分 1** ([README.md](README.md) D-API-8'。2026-08-02 に C-16 で「増分 2」から改訂) |
| **O-1** 構造化ログ | **参照 + 回答** | フィールド定義は [../observability.md](../observability.md) §4.1。本書の要件は**エラー本文に `request_id` を含める** ([README.md](README.md) D-API-6) と、**秘密文字列を URL に置かない** (AA-D-4。ログに残さないための構造) |
| **O-2** LLM 計測 | **対象外 (理由あり)** | LLM 経路が無い (A-6 と同じ)。計測対象 3 本は [README.md](README.md) §4 の O-2 行のまま**増えない** |
| **O-4** 失敗の可観測性 | **回答** | §3.7 の末尾。**401 / 400 の内訳を §3.1.1 の `code` 単位で数える** (v2 は MFA 失敗が 500 = V2-D2)、**メール送信の失敗を握り潰さない**。**AC-1.6** (認証エンドポイントの濫用対策) に対する本書の貢献は**適用対象の列挙** (P-7): §3.7 の**レート制限 14 本**と、その超過を **429 の発生件数として観測する**こと。しきい値・保管先・fail-closed の挙動は [../auth.md](../auth.md) §6.11-3 が SSOT |
| **O-5** SSE / 長時間処理 | **対象外 (理由あり)** | **SSE も長時間処理も無い**。2026-08-10 の DM-Q2 回答 (削除せず無効化のみ) で **AA-D-13 の非同期削除ジョブが消滅**したため、[README.md](README.md) §1.3 の J-2 / J-3 / J-5 / J-7 を適用する対象が本書に無くなった |
| **O-6** 監査ログ | **回答 (v2 相当に限定。2026-08-14 に一部復帰)** | §3.7 の表で**エンドポイント別に記録事象を確定**した (**行数は同表が定義元** — 転記しない = DR-9。2026-08-10 の **AA-D-23** で絞った後、**2026-08-14 の AA-D-24** で「v2 に前例が無い」という判定の誤りが見つかり、メンバー作成・メール変更・パスワード変更・会社 MFA 設定変更の 4 行を復帰させた)。値域は [../observability.md](../observability.md) §4.5.1 に v2 由来の 6 種 + AA-D-24 で復帰した 4 種 + リセット要求 (`account_request_reset_password`) が登録済みで不足なし。**v3 独自事象の追加要求 (R-AA-7③) は取り下げたまま**。**先送りしたもの**: ロック・削除・権限変更・招待の実行者追跡と `POST /admin/signin` の成否 (**権限変更・削除は前例があるが AA-D-24 でも意図的に対象外**) — 再開の入口は §6.1 の **AA-Q14** |
| **O-3** コスト集計 | **対象外** | LLM 経路が無いため該当なし |
| **O-7** アラート | **対象外 (先送り)** | しきい値と通知先は [../observability.md](../observability.md) §4.6 / [../operations.md](../operations.md)。**本書からの入力は「429 の急増」「レート制限ストア障害による 503」の 2 つ** — **「社内管理者のサインイン失敗」は AA-D-23 で記録自体を行わないことにしたため入力から外れた** (是正要求は §5 **R-AA-26**。[../observability.md](../observability.md) §4.6 の **AL-7** は `POST /admin/signin` のレート制限発動を見るので引き続き有効) |
| **D-5** シークレット管理 | **参照** | `JWT_KEY` / `ADMIN_JWT_KEY` は [../auth.md](../auth.md) §6.8。**本書の移植で新たに必要になる資格情報 3 件**: **Resend の API キー** (V2-F11) / **S3** (アイコン) / **`AUDIT_EMAIL_HMAC_KEY`** (監査記録の `detail.email_hash` の pepper。AA-D-21③。**失われると過去の失敗サインインと新しい記録が突き合わせ不能になる**ため、ローテーションはしない前提で棚卸しに載せる)。**棚卸し先は [../operations.md](../operations.md) §4.5 の棚卸し表** (2026-07-31 訂正。**[../infrastructure.md](../infrastructure.md) §3.4 は「器」= Secrets Manager / SSM の構成を定義するが棚卸し表を持たない** — 同書に「棚卸し」の語は 0 件)。**3 件はまだ同表に載っていないため §5 R-AA-23 で起票した** — 載らないまま RL-2 (prod 基盤構築) を通すと、同書 §6.1 の完了条件② (「§4.5 の棚卸し表の全行に prod の値が投入済み」) が**空振りして pepper 未投入のまま prod が立つ**。**招待・リセットのトークンは DB に平文で保存しない** (AA-D-5④ = 秘密の保管場所を増やさない)。**AC-1.5** (鍵の管理と失効手段は [../auth.md](../auth.md) §6.8 が SSOT。**本書の貢献は「本書の移植で増える秘密の列挙」に限る**) |
| **D-4** マイグレーション | **参照** | 本書はスキーマを直接定義せず、[../data-model.md](../data-model.md) への**追加要求** (R-AA-4 / R-AA-18 / R-AA-19 / R-AA-21 = A-3 行の内訳、+ R-AA-17 / **R-AA-30** = 2026-08-29 追加。**件数は §5 の表が定義元** — DR-9) に委ねる。方式は同 §6.1。**RL-2 (初期スキーマ投入) より前に確定が要るのは R-AA-19 (既存列の NULL 可化 + `actor_type` の値追加) / R-AA-21 (`signup_links` の列追加と `reset_password_requests.hash` の改名) / R-AA-17 (`signup_links` の `UNIQUE`) の 3 件** — 投入後の変更は移行手順 (§6.5) の対象になる。**R-AA-19 / R-AA-21 は 2026-07-31 に反映済み** (R-AA-19 は `email_hash` の方式のみ残る = 列定義には影響しない)。**RL-2 前に未対応で残っている DB 制約は R-AA-17 / R-AA-30 / R-AA-33 の 3 件**である (**2026-08-29 に R-AA-30 = `activity_logs` の `CHECK` の緩和と、R-AA-33 = `register_admin_password_requests` の `UNIQUE (admin_account_id)` を追加**。前者は AA-D-29 の監査行が現在の `CHECK` に抵触するため、後者は AA-D-30④ の再発行が R-AA-17 と同型のレースを持つため)。**`register_admin_password_requests.token` → `token_hash` の改名は [../data-model.md](../data-model.md) §4.2 に反映済み** (2026-08-29 = R-AA-5 の解決側) |
| **D-6** Managed Agent | **対象外** | 本書に Agent / custom tool は無い |
| **D-7** 段階リリース | **参照** | P-1 (v3 を正とする 1 回コピー) / ロールバック時の代償 (v3 で変更したパスワードは v2 に戻らない) は [../data-model.md](../data-model.md) §6.5 が SSOT |
| **D-2** CI ゲート | **回答** | 本書が追加する検査 **4 件**: ①**§3.6 の歯止め③** (prod デプロイが E2E シードを参照しない) ②**認証ミドルウェアを通らないルートが「§2.1 の 8 本 + `GET /alive`」と完全一致すること** ([../auth.md](../auth.md) §6.7 の系統検査の入力として §2 の表を使う。**`GET /alive` は ALB のヘルスチェックが叩く公開ルート** — [../infrastructure.md](../infrastructure.md) INF-D / [../auth.md](../auth.md) §1.6 の表。**8 本だけで照合すると `GET /alive` が違反として落ちる**) ③**§3.1.1 の `code` 表が実装リポの `constants` と一致すること** (コード名・分類記号・HTTP ステータスの 3 列。AA-D-18 の代償への歯止め) ④**種別⑦のクエリ (`…ForAdmin`) を社内管理者系統以外のパッケージが参照していないこと** (§3.5 の脚注 1。**契約内管理者経路が全契約横断クエリを呼ぶと V2-D4 が復活するが、SQL 検査も許可リスト検査も通ってしまう**ため、系統との突き合わせを機械化する。検査の置き場と記載形式の変更は §5 **R-AA-20**) |
| **D-1 / D-3 / D-8** | **対象外** | **CI/CD・IaC は API 設計の範囲外** ([README.md](README.md) §4 の同 ID 行と同じ扱い)。本書に固有の入力は **D-5 の秘密 3 件 (Resend / S3 / `AUDIT_EMAIL_HMAC_KEY`)** と **D-2 の検査 4 件**のみで、環境分離・デプロイ手順・IaC 管理範囲は [../infrastructure.md](../infrastructure.md) / [../operations.md](../operations.md) が担う。**D-8 について 1 点だけ本書からの依存がある**: **§2.4 の社内管理者 16 本は [../auth.md](../auth.md) §6.2 の「WAF の IP 許可リストで社内からのみ到達可能にする」の適用範囲に入る** (**本数は §2.4 の見出しが正** — DR-9。2026-08-29 に「8 本」が §2.4 の実数とずれていたのを是正し、同日の AA-D-33 で 13 → 16 になった)。**Vercel 由来のリクエスト (FE の Route Handler が BE を呼ぶ) と両立するかは [../frontend.md](../frontend.md) §11.3.2 (FE-Q7) が未解決**であり、**§2.4 の到達性はその決着に依存する** — 実装リポが §2.4 を作った後に到達不能を知る事態を避けるため、FE-Q7 の回答を §2.4 の実装着手より前に得る |

**2026-08-29 に追加した 8 本 (AA-D-29 の 2 本 / AA-D-30 の 3 本 / AA-D-33 の 3 本) に新しい AC を立てていない**
(同日のレビュー 軽微 5)。**既存の AC で足りると判断した** — 8 本はいずれも
**AC-1.1 (系統の宣言と素通りの禁止) / AC-1.4 (401/403/404 の使い分け) / AC-1.6 (認証エンドポイントの濫用対策)**
が課す性質の適用先が増えたものであり、**新しい受入性質は生じていない**。
**振る舞いの固定は §7.3 の UT 必須ケース (14〜16・21〜23) で行う**。
**この判断が変わる条件**: 社内管理者機能に**新しい性質**(例: 承認フロー・多要素)を足すとき。
そのときは requirements.md 側に AC を新設する (**AC が無い設計判断は DR-6 の対象**)。

---

## 5. 他の設計書への是正要求 (本書の判断から派生)

**auth.md は別セッションが改訂中のため本書からは編集しない** (要求のみを起票する)。
**状態列を持たせる** (`.claude/rules/06-delegation-prompts.md` の運用)。

**採番と行分割の運用 (2026-07-31 のレビュー M-3 / §5.1 で確定)**:

1. **新規 ID は常に現在の最大値 + 1 を末尾に追加する**。**ID の再利用・詰め直し・欠番の再割り当てをしない**
   (他文書の担当者が ID で引き当てるため、同じ ID が別の要求を指すと「対応済み」の記録が無効になる)
2. **改番が必要になった場合も末尾へ移す** (空いた番号を再利用しない)
3. **宛先が複数の要求は宛先ごとに行を分ける** — 1 行に 2 宛先を書くと、片方だけ完了したときに
   状態列で表現できない (R-AA-2 が実際にこの形になったため、**R-AA-2a / R-AA-2b に分割**した)
4. **状態列は宛先の現物を確認してから更新する。`未対応` のまま放置された行は、次のレビューで
   必ず現物照合の対象になる** (2026-07-31 のレビュー重大 2 で追加)。**「対応済み」と
   「別案で対応済み (相違点あり)」を区別する** — 後者を「対応済み」に丸めると**割れが消えて見える**。
   別案の場合は**相違点を状態列に列挙し、本書側の記述をどちらへ寄せたかを書く**
   (2026-07-31 の実例: R-AA-19 = `actor_type` の値追加 / R-AA-21 = 列の改名。どちらも SSOT 側に寄せた)。
   **状態列の根拠は「宛先の節番号 + 確認日」で示す** (行番号は別セッションの改訂でずれるため書かない)

| # | 対象 | 内容 | 状態 (2026-07-31) |
|---|---|---|---|
| **R-AA-1** | [../auth.md](../auth.md) §6.11-3 | **レート制限の対象に MFA 検証 (`POST /mfa/totp/verify`。**`/admin/mfa/totp/verify` は AA-D-22 で消滅**) を追加する**。現記述は「未認証で叩けるエンドポイント」に限定しており、**TOTP 6 桁への総当たりが対象外になる** — `failed_sign_in_attempts` はパスワード失敗でしか増えない (`hassan-v2-backend/db/queries/account.sql:56-64`) ため、ロック機構では止まらない (AA-D-10)。キーは `account_id` + エンドポイント | **実施済み・ただし 1 本不足 (2026-07-31 実測)** — [../auth.md](../auth.md) §6.11-3 に**対象② (認証済み)** が新設され、`POST /mfa/totp/verify` / `POST /admin/mfa/totp/verify` / `PUT /accounts/me/password` / `PUT /accounts/me/email` が入った (同 §10.3 の受信欄も「実施済み」)。**`POST /mfa/totp/reset` (`totp_code` の総当たり) が対象②の列挙から漏れている** — **2026-08-10 時点の記録**: 本書 §3.7 のレート制限は当時 **10 本**で、対象②の 4 本 + 公開 6 本 = 10 本と一致していた (**現在は 14 本** — AA-D-30 の公開 2 本と AA-D-33 の自己管理 2 本が加わった。実測は §3.7 の表が定義元) (**2026-08-10 に是正済み** — `POST /mfa/totp/reset` を §6.11-3 の対象②へ追加し、AA-D-22 で消滅した `POST /admin/mfa/totp/verify` を外した) |
| **R-AA-2a** | [../auth.md](../auth.md) §6.6 | **4 点**: ①**401 は `CodedError` 本文を持ち、`code` の接頭辞で分類 T (トークン自体の失効) / 分類 C (提示した資格情報の不一致) を表す**という例外を明記する (現記述は「401 は本文なし」。AA-D-9 / AA-D-18。値域の SSOT は本書 §3.1.1)。**FE の書き分けの軸は「セッションを持つ経路か」ではなく「本文の `code` が `AU-T-` か `AU-C-` か」**である — 経路で分けると MFA 検証 (セッションを持つが分類 C) を取り違えて**強制サインアウトを再生産する**。併せて**認証済み経路の資格情報不一致は 400** (AA-D-17) を §6.6 の表に反映する ②**429 を返す 11 本**を一覧に載せる (README §2.5 の 429 行は「本ディレクトリの対象外」と書いており、本書が同ディレクトリに入ったことで不正確になった。**[README.md](README.md) 側の「8 本」→「11 本」は R-AA-2b ② で実施済み** — S-3 で認証済み 3 本を追加したため) ③**403 の第 3 系統 (R-3 = 契約の不変条件ガード。6 ケース)** を追加する (現記述は「403 は R-1 / R-2 の 2 系統のみ・合計 16 本」— **本数は `make check-endpoint-mapping` の実測が正**)。**403 と 404 の評価順序 (AA-D-19)** も併記する ④**§6.6 の表の「MFA 必須かつ未検証」行の備考「`/mfa` 配下のみ許可」を削除し、「§6.7 のホワイトリストに載せた 2 本 (`POST /mfa/totp/generate` / `POST /mfa/totp/verify`) のみ許可。前方一致判定を使わない」に書き換える** — 同 §6.7 が前方一致を却下済みであるにもかかわらず、**判定規則の SSOT を自称する §6.6 に v2 の前方一致 (V2-F7) が残っており**、[../frontend.md](../frontend.md) の `/mfa` 行が既にこの文言を「根拠」として転記している (波及済み。R-AA-11 と同じ差分で直す) | **①④ 実施済み / ③ 未対応 / ② は R-AA-2b へ移設 (2026-07-31 実測)** — ①[../auth.md](../auth.md) §6.6 に「公開エンドポイントの資格情報エラーは 401 + `CodedError` 本文。値域の SSOT は本書 §3.1.1」の例外行が入った ④同 §6.6 の「MFA 必須かつ未検証」行が「§6.7 のホワイトリストに載せたルートのみ許可」へ書き換わり、`/mfa` 前方一致の記述は消えた (同 §10.3 の受信欄も両方「実施済み」)。**③ (403 の第 3 系統 = R-3 の不変条件ガード 6 ケース) は未対応** — §6.6 の 403 の行は R-1 (契約内管理者限定) と R-2 (リソース単位ロール) の 2 系統しか挙げていない。**403 と 404 の評価順序 (AA-D-19) も未記載**のままである |
| **R-AA-2b** | [README.md](README.md) §2.5 / §0 | **3 点**: ①401 に本文を持つ例外 ②**429 を返す本数** (§0 の差分注記と §2.5 の 429 行に残っていた「8 本」を実測値へ。**本数を本行に転記しない** — 8 → 11 → 10 → **12** と 4 回動いたため。実測は `make check-endpoint-mapping` が正 = DR-9) ③**403 の第 3 系統 (R-3)** を §2.5 の適用一覧に反映する。**内容は R-AA-2a と同じ差分で、宛先だけが違う** (§5 冒頭の運用 3 に従って行を分けた) | **実施済み (2026-07-31。メインセッションが同差分で対応 — [README.md](README.md) §0 の差分 3 点注記 / §2.5 の 401 行・429 行 / §2.5 の「403 は 10 本」)** |
| **R-AA-3** | [settings.md](settings.md) §5 (①②) / 同 §2 の `:35` (③) | **3 点**: ①**社内管理者向けのアカウント検索 (`GET /admin/companies/accounts` = `hassan-v2-backend/router/router.go:216`) が移植リストに無い** — これが無いと `/admin/accounts` 画面 ([../frontend.md](../frontend.md) §11.1) がロック対象を探せず、**解除操作に到達できない** (BE-10) ②**社内管理者による一般アカウントの MFA リセット (`同:217`) も無い** (AA-Q2 の対象) ③**[settings.md](settings.md)`:35` (§2 のプロトタイプ棚卸し表。§5 ではない) の「変更フローは検証メール等を含む」は誤り** — v2 の `UpdateEmailUseCase` はメール送信を行わず、パスワード確認のみで即時更新する (`hassan-v2-backend/usecase/account/update_email.go:35-66`。EmailService への依存を持たない) ④**§2 冒頭 (`:30`) と §5 冒頭 (`:158`) の「入出力仕様の起草は未着手」を「入出力仕様は [auth-accounts.md](auth-accounts.md) が確定 (2026-07-31)」へ書き換える** — [settings.md](settings.md) から入る読者 (設定画面の実装者) が「仕様が無い」と読み、着手不可と判断する (`.claude/rules/06-delegation-prompts.md` の「機構を直したら、その機構を語る文書を同じ差分で直す」)。同書 `:220` (ST-Q6) の「[../data-model.md](../data-model.md) (**未着手**)」も同じ差分で直せる ⑤**§5 の `POST /admin/signin` の出典を `同:194` → `同:195` に訂正する** — 実測 `hassan-v2-backend/router/router.go:195` = `adminRoute.POST("/signin", ...)` で、**`:194` は `adminRoute := r.Group("/admin")`**。[../auth.md](../auth.md) §6.2 と本書 §2.1 は既に `:195` と正しく書いており、**[settings.md](settings.md) だけが誤ったまま残っている** (DR-1)。行番号がずれると実装者が `r.Group` の行を見て「middleware が付いていない理由」を誤解する | **④⑤ 実施済み / ①②③ 未対応 (2026-07-31 実測)** — ④[settings.md](settings.md) §2 冒頭・§5 冒頭とも「**入出力仕様は [auth-accounts.md](auth-accounts.md) が確定 (2026-07-31)**」に更新され、同書に「未着手」の語は 0 件 ⑤§5 の `POST /admin/signin` の出典が `同:195` に訂正され、訂正理由も併記された。**①② (社内管理者向けのアカウント検索 `GET /admin/companies/accounts` と一般アカウントの MFA リセット) は §5 の移植リストに依然無い** (実測: 同書に該当パスの行が無い) / **③ (§2 の「変更フローは検証メール等を含む」) も未訂正** |
| **R-AA-4** | — | **取り下げ (2026-08-10)**。DM-Q2 が「削除せず無効化のみ」に確定したため、`account_deletions` テーブルも `GET /account-deletions/{deletion_id}` も不要になった (AA-D-13 の改訂)。**代わりに R-AA-27 (`accounts` の無効化列) を出す** |
| **R-AA-5** | [../data-model.md](../data-model.md) §4.2 | **`register_admin_password_requests` を v3 のテーブル一覧から外すか、使う経路を定義する**。[../auth.md](../auth.md) §6.2 が社内管理者の投入を移行スクリプトに限定した (API を作らない) ため、**v3 に読み手も書き手も無い** (BE-10 の形。§2.7)。パスワードハッシュも移行スクリプトが投入するため登録フローは不要 | **対応済み (2026-08-29)。「使う経路を定義する」側で解決した** — **AA-Q15 = (c) のオーナー回答 (AA-D-30) により、`register_admin_password_requests` に読み手と書き手が対で付いた** (BE-10 への回答): **書き手** = `POST /admin/admins` (作成時の発行) と `POST /admin/admins/{admin_account_id}/password-registrations` (再発行時の失効 + 発行) / **読み手** = `POST /admin/password-registrations/lookup` と `POST /admin/password-registrations` (どちらも `token_hash` で引き `expired_at` を判定する) と **`InternalAdminView.password_registered` の導出** (行の存在 = 未設定) / **削除の書き手** = 設定成功時の `DeleteRegisterAdminPasswordRequestByTokenHash`。**列の改名 (`token varchar(255)` → `token_hash text NOT NULL UNIQUE`。AA-D-5④(iii) 準拠) は [../data-model.md](../data-model.md) §4.2 に反映済み** (2026-08-29)。**残る DB 要求は R-AA-33 (`UNIQUE (admin_account_id)`) のみ** |
| **R-AA-6** | [../data-model.md](../data-model.md) §6.4 (DM-A2) | **`company_missions` の既存データの扱いを移行対象の判断に含める** (AA-D-1 で API を作らない判断をしたため、`v2 の既定ミッション文` を v3 のどこにも写さないと消える)。**候補**: 移行しない / テーマ作成時の初期値として 1 回だけ写す | **未対応** |
| **R-AA-7** | [../observability.md](../observability.md) §4.5 | **①②のみ有効 (③は取り下げ)**。①**v2 に既に存在する 6 種** (`signin_success` / `signin_failed` / `mfa_verify_success` / `mfa_verify_failed` / `mfa_reset_by_admin` / `mfa_reset_by_aillio_admin` — `hassan-v2-backend/db/schema.sql:467-479`) を落とさないこと ②**失敗サインインのメールアドレスは平文で保存せず HMAC-SHA256 + pepper のハッシュにする** (AA-D-21)。**③ v3 独自事象の値域追加は AA-D-23 で取り下げ** (**2026-08-14 の AA-D-24 で、取り下げ対象に v2 前例のある事象が誤って含まれていたことが判明し、member_create / account_update_email / account_update_password / contract_update_mfa の 4 種は値域に追加済み — これらは「v3 独自事象」ではなかったため③の対象外だったことになる。③の取り下げ自体 (真に v3 独自の事象) は変更なし**) |
| **R-AA-8** | [../auth.md](../auth.md) §6.3 の例外表 (`account_mfa_configs` の行) | **「引くときの条件がトークン検証済みの `account_id` であるため §6.4 の許可リスト側で扱う」の記述を見直す** — §6.4 の SQL 検査は**所有者条件 (`account_id` を含む) の有無**を見るため、`WHERE account_id = $1` を持つクエリは検査を通り、**許可リストへの登録は不要**である (§3.5 の「載せないもの」)。必要なのは**スキーマ検査 (`contract_id` 必須) の除外**だけで、それは [../data-model.md](../data-model.md) §4.1.2 (b) に登録済み。現記述のままだと実装リポが不要な例外を許可リストに積む | **実施済み (2026-07-31)** — [../auth.md](../auth.md) §6.3 の該当行が「スキーマ検査の例外であり許可リストには載せない」に訂正された (同 §10.3 の受信欄) |
| **R-AA-9** | [../auth.md](../auth.md) §6.7 の系統表 | **ユーザー側の「MFA 未検証で到達可」が系統表に現れていない** — 表の「ユーザー認証」行は「上記と管理者系を除く全ルート」であり、`POST /mfa/totp/generate` / `verify` の 2 本が**同節後半の別機構 (許可ルートのホワイトリスト)** で表現されている。**管理者側は 4 番目の系統として表に載っているのに、ユーザー側は載っていない**という非対称。本書 §2.2 / §2.3 は系統を 5 分類 (公開 / ユーザー MFA 未検証可 / ユーザー / 管理者 MFA 未検証可 / 管理者) として表を分けた。**表側を 5 系統に揃えるか、脚注で 2 本を明示するかを SSOT 側で決める** | **実施済み (2026-07-31)** — [../auth.md](../auth.md) §6.7 の系統表が非対称を解消した (同 §10.3 の受信欄) |
| **R-AA-10** | [../frontend.md](../frontend.md) §5.2.2 / §16.2-6 | **是正要求への回答が本書 §2.5 で揃った** (`SignInResult` に `auth_role` / `mfa.required_type` / `mfa.verified` / `account.id` / `name` / `company_name` を含む)。同節の「応答に入るまでは導線を全員に出す」暫定挙動を**解除できる**。併せて **§9 の「401 → `/api/logout`」を §3.1.1 の分類で書き換える** — **`code` が `AU-T-` で始まるときだけ破棄し、`AU-C-` はフォーム内エラーとして扱う。本文なし・未知の接頭辞は分類 T (fail-safe)**。**エンドポイントやセッションの有無で分岐しない** (MFA 検証はセッションを持つが分類 C。AA-D-9 / AA-D-17) | **実施済み (2026-07-31)** — [../frontend.md](../frontend.md) §5.2.2 の暫定挙動 (「応答に入るまでは導線を全員に出す」) が解除され、**§9 に分類 T / C の 2 行 + 判定 3 行 (`AU-T-` → 破棄 / `AU-C-` → フォーム内 / それ以外 → 破棄)** が反映済み。本書 §3.1.1 と同一の契約になっている |
| **R-AA-11** | [../frontend.md](../frontend.md) §11.1 / §11.3.1 | **2 点**: ①**根拠列が `[未確定] (Task-3i)` のままの 11 行** (`/login` / `/mfa` / `/mfa/setup` / `/signup` / `/reset-password` / `/settings/members` / `/admin/signin` / `/admin/mfa/setup` / `/admin/mfa` / `/admin/accounts` / `/admin/admins`。**実測 11 行** — うち文字列 `Task-3i` を含む行は 9 なので、**grep だけで拾うと 2 行落ちる**) を **`[API]` + 本書への参照**に更新する — **読者 (FE 実装者) は「仕様が無い」と読み、着手不可と判断する** ②**§11.3.1 の「セッションの寿命」行**は「値は Task-3i が管理者トークンの有効期間を決めた後に一致させる」としているが、**P-3 (FE-Q8 = 7 日) で確定済み**であり、本書 §2.4 の管理者トークンも 7 日である。**「7 日」に確定させる** ③**`/login` に「ロック時の案内」を持たせる** — サインイン応答が `AU-C-00002` (ロック) のとき「契約内管理者に解除を依頼してください」を表示する。**`/reset-password` の完了画面には置けない** (204 固定・未認証ではロック状態を知れない = §3.4 / S-7) | **①②③ すべて実施済み (2026-07-31)** — ①[../frontend.md](../frontend.md) §11.1 に `[未確定] (Task-3i)` の行は残っていない (実測 0 件) ②§11.3.1 のセッション寿命が 7 日に確定 ③§9 の分類 C 行と §11.1 の `/login` 行に「`AU-C-00002` を受けたら管理者へ解除を依頼と案内」が入った |
| **R-AA-12** | [../auth.md](../auth.md) §6.2 | **本増分に含める社内管理者機能の列挙に「一般アカウントの MFA リセット」(`POST /admin/accounts/{account_id}/mfa/reset` — §2.4) を追加する** (2026-07-31 の AA-Q2=a で確定。MFA 必須契約で契約内管理者が全員デバイスを失った場合の製品内で唯一の回復経路)。**採番の経緯**: 当初 R-AA-10 として追記したが起草時の R-AA-10 と ID が衝突したため 2026-07-31 のレビュー指摘 (S-10) で R-AA-12 へ改番。その結果**既存の R-AA-12 ([../testing.md](../testing.md) §7.3) と再衝突した**ため、後者を **R-AA-14** へ改番して解消した (同日) | **実施済み (2026-07-31)** — [../auth.md](../auth.md) §6.2 の「本増分に含める範囲」表に `POST /admin/accounts/{account_id}/mfa/reset` の行が入り、回復経路が無い場合の帰結も併記された (同 §10.3 の受信欄) |
| **R-AA-13** | [plan.md](../../../aidlc-docs/inception/productionization/plan.md) / `aidlc-docs/aidlc-state.md` / `todo.html` | **Task-3i の状態を「完了」に更新する** (成果物 = 本書 + [README.md](README.md) §0 / §3 の更新)。併せて **aidlc-state.md の「④Task-3i は DM-A3 / DM-A4 の回答が前提」の行**と、**todo.html の be / fe「認証機能設計」(現在 進行中 = 1。理由が「入出力仕様は Task-3i 未着手」)** を実態へ同期する。**本書からは編集しない** (状態管理はメインセッションの担当)。**更新は 2026-07-31 のレビューが挙げた重大指摘 (本書側の反映 = R-AA-18〜R-AA-22 の起票を含む) が解消し、再レビューで重大ゼロを確認した後に行う** — 現時点で「Task-3i 完了」にすると、受け皿の無い委譲先 (`activity_logs` / `action` 値域 / トークン列。**`admin_mfa_configs` は AA-D-22 で不要になった**) が未整備のまま実装リポへ渡る | **未対応 (重大指摘の解消が前提)** |
| **R-AA-14** | [../testing.md](../testing.md) §7.3 / §13.1 (T-Q3) | **「例外の表現方法は Task-3i が定義する」の参照先を本書 §3.6 に更新する** — 定義は「**`companies.mfa_type = 'none'` を使い、コードに分岐を作らない**」であり、歯止め 3 点 (dev 専用シード / prod の投入手順に含めない / CI 検査) を含む。**§3.6 の歯止め③ (CI 検査) は [../testing.md](../testing.md) 側の検査一覧にも載せる必要がある** | **未対応** |
| **R-AA-15** | [../auth.md](../auth.md) §6.7 の**公開系統のホワイトリスト** | **公開系統の宣言を「本書 §2.1 の 8 本 + `GET /alive`」に差し替える** (**2026-08-29 に AA-D-30 の公開 2 本が加わり 6 → 8**)。同節の「公開」行は現在 **`GET /accounts/signup-links/:id`** と **`POST /accounts/reset-password/:hash`** を具体パスで宣言しているが、本書は AA-D-4 (秘密を URL に置かない) により **`POST /accounts/signup-links/lookup`** / **`POST /accounts/reset-password/confirm`** へ変更した。**この表が §6.7 の CI 検査の入力である**ため、放置すると ①実装が §6.7 に合わせて旧パスを作る ②または新パスが未宣言として CI で落ちる、のどちらかになる (§7.1 の「共通層を先に完成させる」が成立しない)。**`GET /alive` を明示的に含める** ([../infrastructure.md](../infrastructure.md) INF-D / [../auth.md](../auth.md) §1.6)。**併せて SSOT の向きを確定する** (下の「SSOT の向き」を参照) | **未対応 (M-2)** |
| **R-AA-16** | [../frontend.md](../frontend.md) §11.1 | **`/settings/profile` 相当の画面を 1 本追加する** (R-AA-11 とは別の要求。**既存行の根拠列更新ではなく行の新設**)。§11.1 の現ルート一覧に**自分自身のプロフィール系画面が 1 つも無い**ため、本書 §2.3.1 の **6 本に消費者 (画面) が存在しない** (BE-10 の読む側の不在): `PUT /accounts/me` (氏名・所属・役割) / `PUT /accounts/me/email` / `PUT /accounts/me/password` / `POST /accounts/me/icon` / `DELETE /accounts/me/icon` / `POST /mfa/totp/reset` (自分の TOTP 再登録)。とくに **`POST /mfa/totp/reset`** は AA-D-8 が「v2 でできていた自己解決の経路を失わない」を理由に残したエンドポイントであり、**画面が無いとその判断の根拠が成立しない**。画面に載せる項目 = 氏名 / 所属 / 役割 / アイコン / メールアドレス / パスワード / MFA 再登録。**入力は [settings.md](settings.md) §2 (`:33`-`:37`) のプロトタイプ棚卸しにある profile 項目**だが、**プロトタイプは設計入力であって仕様ではない** (DR-7) ため、ルートと画面仕様の確定は §11.1 側で行う。**画面を作らない判断をする場合は、本書 §2.3.1 の該当 6 本を本増分から外す** (作ったが誰も呼ばない API を残さない) | **実施済み (2026-07-31)** — [../frontend.md](../frontend.md) §11.1 に **`/settings/profile`** (`(app)` グループ) が新設され、氏名・所属・役割 / アイコン / メール変更 / パスワード変更 / MFA 再登録の 6 本すべてに消費者ができた。**同行は AA-D-17 の 400 (フィールドエラー) も正しく反映している** (本書 §3.1.1 と一致)。本書 §1.1 / §2.3.1 の「画面未存在」記述も同日に更新済み |
| **R-AA-17** | [../data-model.md](../data-model.md) §4.2 (`signup_links`) | **`UNIQUE (contract_id, email)` を追加する**。AA-D-5 ② の「1 アカウントにつき有効な招待リンクは 1 本」を**発行時の delete → insert という手続きだけ**で担保しているため、**「再送」を同時に 2 回押すと 2 本の有効リンクが残る** (delete → insert のレース。BE-11 と同型)。DB 制約があれば 2 本目の insert が失敗し、UseCase は 409 か再試行として扱える。**制約を入れない場合でも、発行は 1 トランザクション内で `DELETE` → `INSERT` を行い、トランザクション分離だけに頼らない**ことを §4.2 の注記に残す (本書 §3.3 にも明記済み) | **未対応 (S-8)** |
| **R-AA-18** | — | **取り下げ (2026-08-10。AA-D-22)**。社内管理者に MFA を課さないため `admin_mfa_configs` は作らない。**[../data-model.md](../data-model.md) §4.2 に追加済みの定義を削除する要求 = R-AA-28** |
| **R-AA-19** | [../data-model.md](../data-model.md) §4.10 (`activity_logs`) | **actor / contract が確定しない認証イベントを書けるようにする** (AA-D-21)。**起票時の問題**: 同節の列定義は `actor_id uuid` / `contract_id NOT NULL` で、「社内管理者による全契約横断の操作でも対象アカウントの契約が入るため NOT NULL を維持できる」と明示していたが、**未登録メールアドレスへのサインイン失敗では actor も契約も存在せず `signin_failed` が書けない** — **v2 でできていた `signin_failed` / `mfa_verify_failed` (V2-F17) が v3 で落ち、O-6 が v2 より後退する**。**要求 4 点のうち①②④は充足済み** (下の状態列)。**残る要求は 1 点**: **`detail.email_hash` の方式を「pepper 無しの SHA-256」から「HMAC-SHA256 + サーバ側 pepper (`AUDIT_EMAIL_HMAC_KEY`)」へ改める** — **メールアドレスは低エントロピーで候補が有限**なので、素のダイジェストは既知アドレスの総当たりで復元でき、**「監査ログを見られてもアドレスが分からない」が成立しない** (**2026-07-31 ユーザー決定**)。同節自身が「**値域と記録項目の SSOT は [../observability.md](../observability.md) §4.5**」と書いており、その **§4.5.2 は HMAC + pepper で確定済み**であるため、**現状は参照先と本文の例が矛盾している** — どちらで実装されるかが読んだ順で決まる (BE-12)。**併せて③の扱いを確認する**: 本書が起票した「`(contract_id, …)` を `WHERE contract_id IS NOT NULL` で部分化する」は**採用されず**、代わりに `(action, occurred_at DESC) WHERE actor_type = 'unauthenticated'` が入った。**本書はこの形を受け入れた** (AA-D-21 の代償②) ので、③の再要求はしない | **①②④ 実施済み・③ は別案で対応・`email_hash` の方式のみ未対応 (2026-07-31)**。実施済みの内容: ①`actor_id` / `contract_id` を NULL 可 ②**`actor_type` に `unauthenticated` を追加し、`CHECK` は `action` ではなく `actor_type` を条件にする形**を採用 (本書の起票は「`action` が認証失敗系のときだけ」だったが、**SSOT 側の形に本書を合わせた** — AA-D-21①) ④反転を明記し反転理由 (未認証の失敗イベント) を同節に記録済み。**未対応の 1 点 (`detail` の例が pepper 無しの SHA-256) は本書 §4 の D-5 (pepper の棚卸し) と §3.7 に依存する**ため、放置すると pepper を持つ実装と持たない実装が並立する |
| **R-AA-20** | [../auth.md](../auth.md) §6.4 (許可リストの記載形式と CI 検査) | **許可リストの必須項目に「呼び出しを許す系統」列を足し、種別⑦を系統で機械検査できるようにする**。**問題**: 同節は「**許可リストは「そのクエリを許可する」だけで呼び出し元を制約しない**」と明記している (同節の種別⑦の「理由」欄)。種別⑦のクエリ (`WHERE id = $1`) を契約内管理者の UseCase が呼んでも、①SQL 検査 (所有者条件の有無) ②許可リスト検査の**どちらも通る**ため、**V2-D4 / 同 §5-11 (ロック解除のテナント越境) が CI を通ったまま復活する**。**3 点**: ①必須項目を「ファイルパス + クエリ名 + 種別 + 理由 + **呼び出しを許す系統**」にする ②**種別⑦の定義に「社内管理者系統 (`X-Admin-Token`) の UseCase からのみ呼べる」を含める** ③**CI 検査に「⑦のクエリ名をユーザー系統のパッケージが参照していないこと」を加える** (系統の機械判定は同 §6.7 で既に成立しているため、系統列との突き合わせが可能)。**§6.4 が却下したのは「③ (レコードを返す一意性検査) に呼び出し元パッケージを書かせる案」であり、その却下理由 (レコードを返す経路が残る) は⑦には当てはまらない** — ⑦は書き込みで、系統が既に機械判定できる。**併せて本書 §3.5 のクエリ名変更を許可リストに反映する** (`UnlockAccountByID` → **`UnlockAccountByIDForAdmin`** / `DeleteAccountMfaConfigByAccountID` (社内管理者経路) → **`DeleteAccountMfaConfigForAdmin`**) | **①②③ 実施済み (2026-07-31 実測)** — [../auth.md](../auth.md) §6.4 の記載形式に「**種別⑦は『呼び出しを許す系統』も必須項目**」が入り、種別⑦の定義にも「登録には『呼び出しを許す系統』列が必須」が追記され、追加制約の項に「**§6.7 の系統検査と突き合わせて機械判定する**」「③に呼び出し元を書かせる案の却下理由は⑦には当てはまらない」が明記された。**同 §10.3 の受信欄には本 ID の行が無い**ため、受信欄への追記は宛先側の残作業 (本書からは書けない)。**クエリ名変更 (`…ForAdmin`) の許可リストへの反映は実装リポの担当** (§3.5 が元表) |
| **R-AA-21** | [../data-model.md](../data-model.md) §4.2 (`signup_links` / `reset_password_requests`) | **秘密文字列の格納先を定義する** (AA-D-5④)。**現状 `signup_links` に `token` 相当の列が無く** (v2 は 5 列 = V2-F3。秘密はリンク ID 自体 = V2-F2)、**`reset_password_requests` の列は `hash` で `token` は無い** (`hassan-v2-backend/db/schema.sql:312-320`) ため、本書 §3.3 / §3.5 のフローに保存先が存在しない (BE-10)。**2 点**: ①**`signup_links` に `token_hash text NOT NULL UNIQUE` を追加する** — §4.2 の「変える点は 2 つだけ」に対する **3 点目**になる。**承認の根拠**: AA-D-5 の却下 (b) が `account_id` 追加を却下した理由は「**移行の写像が増える**」だが、**P-2 (v2 の既存未使用リンクは引き継がず失効・再発行 = DM-A4=B) により `token_hash` には写す元が無く、移行の写像は増えない** ②**`reset_password_requests.hash` に格納する値を「平文トークン」から「SHA-256 ダイジェスト」へ変える**ことを §4.2 に明記する (v2 は `util.RandStringRunes(32)` の生成値をそのまま入れている — `hassan-v2-backend/usecase/account/request_reset_password.go:59`, `:62`)。**併せて §6.5 の移行設計で「v2 の未処理リセット要求 (1 時間有効) を v3 に写さない」ことを確認する** — 写すと平文トークンが v3 の DB に入る | **①② とも実施済み (2026-07-31)** — [../data-model.md](../data-model.md) §4.2 が `signup_links.token_hash text NOT NULL UNIQUE` を新設し、**`reset_password_requests.hash` を `token_hash` へ改名**した (本書の②は「列名は据え置き」だったが、**採用されたのは改名**。理由「列名で保存形が読める」)。**本書は SSOT 側に合わせて AA-D-5④(iii) / §3.3 / §3.5 のクエリ名を `token_hash` へ更新済み** (2026-07-31)。**残る確認 1 点**: 同書 §6.5 (移行設計) が「v2 の未処理リセット要求を写さない」を明記しているかは**本巡では未照合**であり、要求として残す |
| **R-AA-22** | `scripts/` + `Makefile` (**設計文書ではないためメインセッションの担当**) | **`scripts/check-endpoint-mapping.sh` を新設し `make check` に載せる**。照合 2 点: ①**[settings.md](settings.md) §5 の移植チェックリストの行数 == 本書 §2.6 の対応表の行数** (現在どちらも 18) ②**本書 §2 のエンドポイント実数 == [README.md](README.md) §3 の総覧値** (37 / 合計 110 / 403 の 10 本)。**理由**: これらの「N 件」は `make check-table-counts` の検算対象外であり (2026-07-31 実測)、**エンドポイントを 1 本増減すると [README.md](README.md) §0 / §3 / §4 と本書 §2 の複数箇所が同時に動く** (DR-9 = rule 05 の「新しく増えた N 件が検算の対象に入っているか」)。本書 §2.6 は以前「機械照合の結果は §6 の検証欄」と書いていたが**検証欄は存在しなかった**ため、記述を実施範囲に合わせて修正済み (§2.6) | **実施済み (2026-07-31)** — メインセッションが `scripts/check-endpoint-mapping.sh` を新設し `make check` に組み込んだ (照合 5 件)。**故障注入 2 種で検出力を確認済み** (総覧表の本数改ざん / §2.6 の対応行の欠落)。手順は [../../.claude/rules/05-harness.md](../../../.claude/rules/05-harness.md) の「件数の転記を機械で見る理由」 |
| **R-AA-23** | [../operations.md](../operations.md) §4.5 (シークレットの棚卸し表) | **本書の移植で増える秘密 3 件を棚卸し表に行として載せる** (§4 の D-5)。**現状の同表に無い**: ①**メール送信 (Resend) の API キー** — カテゴリ「外部 API」の例に「メール送信」の語はあるが**行として分類 (§3.3) が振られていない** ②**S3 (アイコンの非公開バケット + 署名付き URL 生成)** の資格情報・バケット名 (AA-D-16) ③**`AUDIT_EMAIL_HMAC_KEY`** (監査記録の `detail.email_hash` の pepper。AA-D-21③)。**分類とローテーション方針も同時に決める**: ③は **ローテーションしない** (回すと過去の失敗サインインと新しい記録が突き合わせ不能になり、パスワードスプレーの月次検知が切れる) ため、**同 §4.3 のローテーション対象から明示的に除外する**。**なぜ口頭委譲では足りないか**: 同 §4.5 の運用ルールは「**新しい設定値を追加する PR は分類を書く**」という**追加時点**の規約であり、**設計段階で表に載っていない秘密は §6.1 の RL-2 完了条件② (「§4.5 の棚卸し表の全行に prod の値が投入済み」) を空振りで通過する** = **pepper 未投入のまま prod が立つ**。pepper は後から入れ直すと監査の連続性が切れる。**併せて本書 §4 の D-5 行の「棚卸し先」表記も訂正済み** (2026-07-31。`infrastructure.md` → `operations.md` §4.5。[../infrastructure.md](../infrastructure.md) §3.4 は器の定義のみで棚卸し表を持たない) | **未対応 (2026-07-31 のレビュー中 6。新規起票)** |
| **R-AA-24** | [README.md](README.md) §0 (差分 3 点の注記) | **是正要求 ID の参照を `R-AA-2` → `R-AA-2a / R-AA-2b` に直す**。同節は「SSOT 側への是正要求は同 §5 **R-AA-2**」と書いているが、**`R-AA-2` という ID は本書に存在しない** — §5 冒頭の運用 3 に従って**宛先ごとに R-AA-2a (auth.md §6.6) / R-AA-2b (README.md §2.5) へ分割済み**であり、分割前の ID で引くと**どちらの状態を指すのか判定できない** (R-AA-2a は未対応・R-AA-2b は実施済み)。**R-AA-2b とは別行にした理由**: R-AA-2b は既に実施済みで、同じ行に 4 点目を足すと状態列が「実施済み」から後退して見える (§5 冒頭の運用 1・4) | **実施済み (2026-07-31)** — メインセッションが [README.md](README.md) §0 の参照を `R-AA-2a` / `R-AA-2b` へ更新 (AA-D-17 / §3.1.1 への参照も併せて追加) |
| **R-AA-25** | `scripts/check-endpoint-mapping.sh` (**設計文書ではないためメインセッションの担当**) | **照合を 2 件足し、抽出の前提を 1 つ狭める** (R-AA-22 の残り。DR-9)。**追加する照合 2 件**: ①**レート制限の本数 (11)** — 本書 §2.0 / §3.7 と [README.md](README.md) §2.5 の 429 行の 3 箇所に同じ数が転記されている (S-3 で 8 → 11 に動いた実績があり、**次に動いたとき人手一致に戻る**) ②**§3.1.1 のコード表の行数 (10)** — 本書 §7.1 が「10 コードを `constants` に定義」と転記しており、コードを 1 つ足すと 2 箇所が同時に動く。**2026-08-29 に追加する照合 4 件 (同日のレビュー 中 1 / 中 4)**: ③**公開系統の本数** (§2.1 の見出しの実数 ↔ §1.1 / §3.1.2 の S1 / §4 の A-1・D-2② / §5 R-AA-15 / SSOT の向き表 / §7.1 の依存図、[README.md](README.md) §0 ①③・§2.5、[../auth.md](../auth.md) §6.2 への転記。**D-2 の CI 検査②が「公開 N 本 + `GET /alive` と完全一致」を実装リポで見る**ため、ずれると実装リポの CI が確定で落ちる) ④**§2.4 の見出しの実数 ↔ 群の内訳 (①5 / ②5 / ③3 / ④3) ↔ §4 の A-2・D-8 と [README.md](README.md) §3 本文** ⑤**R-4 (SuperAdmin 限定) の本数** ⑥**AA-D-10 の決定欄の言い回し (`計 N 本`)** — 現在の検査は §3.7 の `レート制限の対象 \(計 N 本` にしか一致せず、**AA-D-10 が「計 10 本」のまま §3.7 の 12 本と食い違っていた** (2026-08-29 のレビュー 中 1。`make check` は緑のまま素通りした)。**足したら故障注入で殴る** (検査⑥→⑦の経緯と同じ)。**狭める前提 1 件**: 同スクリプトの `aa_claim` は「**文書内で最初に現れた『計 N 本 / N エンドポイント』**」を掴む実装であり、**§2 見出しより前に同形の文が入ると別の数を拾う**。抽出を **`## 2.` 見出し行に限定**するか、限定しない場合は**その前提をスクリプト内のコメントに明記する** (誤検知側に倒れるため害は小さいが、原因の特定に時間がかかる) | **実施済み (2026-07-31)** — メインセッションが `scripts/check-endpoint-mapping.sh` に照合 3 件を追加 (429 の本数 ×2・§3.1.1 のコード表の行数) し、`rm_429` の抽出を末尾数値へ限定。**照合 5 → 8 件**。故障注入 2 種 (429 の 1 本削除 / コード表 1 行削除) で検出力を確認済み |
| **R-AA-26** | [../observability.md](../observability.md) §4.6 (アラート定義) | **O-7 のアラート入力から「社内管理者のサインイン失敗」を外す**。AA-D-23 で `POST /admin/signin` の監査記録を行わないと決めたため、**入力となるイベントが発生しない**。**同節の AL-7 (認証エンドポイントのレート制限の発動スパイク) は `POST /admin/signin` を含むため引き続き有効**だが、「社内管理者のサインイン失敗そのもの」を条件にしたアラートは追加しないこと (一度も発火しない監視になる) |
| **R-AA-27** | [../data-model.md](../data-model.md) §4.2 (`accounts`) | **実施済み (2026-08-10)**。`accounts.deactivated_at` の追加 (DM-A5) と、**無効化の帰結 7 点 (サインイン拒否 / トークン失効 / 一覧の既定除外 / 所有物の参照 / メールアドレスの占有 / 人数上限 / 再有効化)** が同節の「DM-A5 補足」で確定した。**本書はその受信側**であり、§2.1 の `POST /accounts/signin` と §2.3.2 の `GET /accounts` / `DELETE /accounts/{account_id}` に反映済み |
| **R-AA-28** | [../data-model.md](../data-model.md) §4.2 / §4.1.2 (a) / §3.3 の検査①の除外リスト / §7.2 | **`admin_mfa_configs` を削除する** (AA-D-22)。**件数の連動先が複数ある** — 機能テーブル以外の件数・除外リスト・`make check-table-counts` の期待値。**削除と同じ差分で検算を通すこと** (DR-9) |
| **R-AA-29** | [README.md](README.md) §0 の差分列挙 / §1.2 の D-API-2 | **AA-D-25 の単数形パス (`/contract` / `/company` / `/company/mfa`) を D-API-2 (複数形に統一) の明示の例外として登録する** — 例外が SSOT 側に無いと、実装者が D-API-2 を根拠に `/contracts` へ「是正」する余地が残る (機械検査はパスパラメータしか見ないため検出されない)。**実施済み** (2026-08-23。README §0 の差分④ + D-API-2 行に例外を追記) |
| **R-AA-30** | [../data-model.md](../data-model.md) §4.10 (`activity_logs` の `CHECK`) | **`actor_type = 'admin_account'` かつ契約に紐づかない操作でも書けるようにする**。同節の `CHECK` は「`unauthenticated` 以外は `actor_id` も `contract_id` も NOT NULL」であり (同 §4.10 の「主体も対象契約も確定しない認証イベントだけは NULL を許す」の採用形)、**AA-D-29 で追加した `POST /admin/admins` / `PUT /admin/admins/{admin_account_id}` は契約に属さない**ため**書き込みが `CHECK` 違反で失敗する** (BE-10 の「書く側が存在しない」ではなく「書けない」形)。**候補 2 つ**: (i) `CHECK` を `(actor_type = 'account' AND … contract_id IS NOT NULL) OR (actor_type = 'admin_account' AND actor_id IS NOT NULL) OR (actor_type = 'unauthenticated' AND 両方 NULL)` の 3 分岐にする (ii) 社内管理者アカウントを対象とする監査行だけ `contract_id` を NULL 可にする。**スキーマの SSOT は data-model 側**なので本書は形を指定しない (AA-D-21 で同じ判断をした)。**`(contract_id, occurred_at DESC)` インデックスに NULL 行が増える**点は AA-D-21 の代償②と同じ扱いでよい | **未対応 (2026-08-29 起票)** |
| **R-AA-31** | [../observability.md](../observability.md) §4.5.1 (`action` の値域) | **`admin_account_create` / `admin_account_update` / `admin_account_password_reissue` の 3 値を追加する** (AA-D-29③ + AA-D-30④ = §3.7 の 3 行。**2026-08-29 に 2 → 3 値へ更新**)。**値域は Go 定数 1 箇所を SSOT + CI 照合**という同節の形に載せる。**登録しないと、実装が定数を持たないまま `activity_logs.action` に文字列を直書きするか、記録自体が落ちる** (AA-D-26 で `contract_create` を登録したのと同じ理由) | **未対応 (2026-08-29 起票)** |
| **R-AA-32** | [../frontend.md](../frontend.md) §11.1 (`/admin/admins` の行) | **社内管理者の新規作成・編集の導線を持たせる** (AA-D-29)。同行は現在「社内管理者の一覧」だけで、**`POST /admin/admins` / `PUT /admin/admins/{admin_account_id}` に消費者 (画面) が無い** (BE-10 の読む側の不在。R-AA-16 と同型)。**v2 は `/admin/admin-setting/new` と `/edit` の 2 画面**だが、**v3 のルート構成をそのまま真似ない** — 一覧内のダイアログでもよい (判断は §11.1 側)。**画面に必ず要るもの**: ①`admin_auth_role` の選択 (2 値の固定列挙。**`GET …/auth_roles` は作らない** = §2.7) **②登録リンクの発行状態 (`password_registered` = §2.5) の表示と、未設定アカウントに対する再発行ボタン** (`POST /admin/admins/{admin_account_id}/password-registrations`)。**③公開ルート `/admin/password-registration` を `(auth)` グループに 1 本足す** — メールのリンク先であり、`POST /admin/password-registrations/lookup` でメールアドレスを表示してからパスワードを設定させる (`/signup` と同じ形。§3.3)。**④自己管理の 3 本 (AA-D-33) に対応する画面を 1 本足す** — `PUT /admin/admins/me` / `/me/email` / `/me/password` の消費者であり、**v2 は `/admin/settings/account` とその配下 3 画面** (`hassan-v2-frontend/src/app/admin/settings/account/{name,email,password}/edit/page.tsx`。入口はヘッダーナビの「設定」)。**`admin` ロールでも到達できる導線にする** (v2 の `ADMIN_HEADER_ITEMS` と同じ。§2.4 の④は R-4 の対象外)。**ルート構成は v2 を真似ず §11.1 側で決めてよい**が、**画面が無いと `admin` ロールの社内管理者は自分の氏名・メール・パスワードを変えられないまま**になる (AA-D-33 が塞いだ穴が FE 側で復活する = BE-10 の読む側の不在)。**旧②「作成直後に 1 度だけ返る `initial_password` の表示」は削除した** — **2026-08-29 の AA-Q15 = (c) (AA-D-30) で応答から平文パスワードが消えたため** | **未対応 (2026-08-29 起票。同日に②③を AA-D-30 に合わせて差し替え、④を AA-D-33 で追加)** |
| **R-AA-33** | [../data-model.md](../data-model.md) §4.2 (`register_admin_password_requests`) | **`UNIQUE (admin_account_id)` を追加する** (**R-AA-17 (`signup_links`) と同型・同理由**)。AA-D-30④ の再発行は「未使用リンクを失効させてから発行する」という手続きで単一有効リンクを担保するが、**再発行を同時に 2 回押すと `DELETE` → `INSERT` のレースで有効リンクが 2 本残る** (BE-11)。DB 制約があれば 2 本目の `INSERT` が失敗し、UseCase は再試行として扱える。**制約を入れない場合でも、発行は 1 トランザクション内で `DELETE` → `INSERT` を行う** (§3.3 に明記済み)。**v2 に制約は無い** (`hassan-v2-backend/db/schema.sql:501-509` は `token` の UNIQUE のみ)。**RL-2 (初期スキーマ投入) より前に確定が要る** | **未対応 (2026-08-29 起票)** |
| **R-AA-34** | [settings.md](settings.md) §5 (移植チェックリスト) | **社内管理者のパスワード登録の公開 2 本 (`hassan-v2-backend/router/router.go:199-200`) と、自己管理 3 本 (`同:202-204`) を移植リストに 2 行足す** (AA-D-30① / **AA-D-33**。**2026-08-29 に 1 行 → 2 行へ更新**)。**同リストは v2 の移植対象を数え上げる元表**だが、この 2 本は起草時に社内管理者機能が対象外だったため載っていない。**追加は本書 §2.6 の対応表と同じ差分で行うこと** — `scripts/check-endpoint-mapping.sh` の検査① が**両者の行数一致**を見るため、片方だけ足すと `make check` が落ちる (**この連動は意図した設計であり、回避せず両方を同時に更新する**) | **未対応 (2026-08-29 起票)** |
| **R-AA-35** | [../auth.md](../auth.md) §6.9 (ロックのガード行) | **「最後の契約内管理者」ガードに直列化の要求を足す** (AA-D-31)。同行は「ロックされていない契約内管理者が 1 名になる操作を拒否する」+「移植時に `AND last_locked_at IS NULL` を加える」までを決めているが、**カウントと更新を同一トランザクションに入れる要求が無い**ため、**ロック 2 本の並行実行で最後の 2 名を同時にロックできる** (本書 §3.4 の注記 2 の交差経路)。**足す文言**: 「**カウントは `SELECT … FOR UPDATE` で契約内の有効な管理者行をロックしてから行い、同一トランザクション内で更新する**」。**判定クエリと数え方の定義元は本書 §3.4** (auth.md 側は SQL を再掲せず参照する = AA-D-20 と同じ向き)。**併せて同行の「ロック状態を見ないカウント」の記述に `AND deactivated_at IS NULL` も要ることを 1 句足す** (v2 は物理削除前提。AA-D-13 / DM-A5 で v3 の削除が無効化になったため) | **実施済み (2026-08-29)** — [../auth.md](../auth.md) §6.9 のガード行に `AND deactivated_at IS NULL` と、`LockContractAdminsForGuardInContract` (本書 §3.4 / AA-D-31) を PUT・DELETE と共通の判定手段とする旨を追記した |
| **R-AA-36** | [../data-model.md](../data-model.md) §4.2 の **DM-A5 補足 2** / [../auth.md](../auth.md) §6.1・§6.9・§6.13.2 | **無効化済みアカウントの既存トークンを失効させる** (AA-D-32①)。①**DM-A5 補足 2 を「失効しない (最大 7 日 / 1 日)」から「認証ミドルウェアが `deactivated_at` を判定して 401 + `AU-T-00006`」へ改訂** ②[../auth.md](../auth.md) §6.1 の「v2 から変える点」に**変更点 5** (`deactivated_at` の判定) を足す ③同 §6.13.2 のシーケンスに**判定 g** を足し、要点 4 (「失効させない」) を反転する ④同 §6.9 の AA-Q13 受信欄の帰結 3 (「無効化後も最大 1 日アクセスできる」) を解消済みにし、帰結 1 に「無効化は即時遮断になったが不可逆なので手動ロックの代替にならない」を追記する | **実施済み (2026-08-29)** — ①〜④を本差分で反映した |
| **R-AA-37** | [../operations.md](../operations.md) §6.1 (RL-2 の完了条件) / §5.1 | **社内管理者のブートストラップ (最初の 1 人) の手順を運用手順として書く** (2026-08-29 起票 = 同日のレビュー 中 3)。**受け皿がどこにも無い** — [../auth.md](../auth.md) §6.2 が具体化した「移行スクリプトが `admin_accounts` 行と `register_admin_password_requests` 行 (`token_hash`) を作り、**平文トークンを標準出力に 1 度だけ出す**」は、[../operations.md](../operations.md) にも [../data-model.md](../data-model.md) §6 の移行手順にも記述が無い (**同書の移行節は「未使用の登録要求は引き継がず失効させ再発行する」**であり、**ブートストラップで新規に 1 行作る**手順とは別物)。**書くこと 4 点**: ①スクリプトの実行者と実行環境 (prod の DB へ到達できる主体。承認機構 H-2 との関係) ②**標準出力に出た平文トークンの取り扱い** (ログに残さない・実行ログを保存しないこと。CI のジョブログに出さない) ③**運用者が `POST /admin/password-registrations` でパスワードを設定するまでの期限は 7 日** (AA-D-30⑥。切れたら再実行する) ④**SuperAdmin を 2 名以上にする手順** (1 人目が `POST /admin/admins` で 2 人目を作る = R-7② と同じ要求)。**RL-2 との前後関係 (D-3 / D-7)**: **`POST /admin/admins` は SuperAdmin の `X-Admin-Token` を要求する**ため、**最初の SuperAdmin が存在しないと誰も叩けない**。したがって**ブートストラップは RL-2 (prod 基盤構築) の完了条件⑦ (初期スキーマ投入) の後、RL-3 (本番リリース) より前**に位置し、**RL-2 の完了条件に 1 項目として足すのが妥当** (現在の完了条件①〜⑦に社内管理者の存在が無いため、**RL-3 の当日に「誰も管理画面に入れない」形で発覚する**)。**本要求は [../auth.md](../auth.md) §10.2 の R-7① を置き換えるものではなく補完する** — R-7① は同日に新方式へ書き換え済み (旧記述は一時パスワードの帯域外配布) | **未対応 (2026-08-29 起票)** |

**SSOT の向き (R-AA-15 の一部。決定は AA-D-20)**:

| 対象 | 元表 (SSOT) | 参照する側 |
|---|---|---|
| **系統の定義**・判定機構・CI 検査の仕組み | [../auth.md](../auth.md) §6.7 | 本書 §2.0 / P-6 |
| **どのエンドポイントがどの系統か** (公開ホワイトリストの中身) | **本書 §2 の節構成** (§2.1 の 8 本 + `GET /alive`) | [../auth.md](../auth.md) §6.7 — **個別パスを再掲しない** |

これは AA-D-2 の却下理由 (a)「§6.7 のホワイトリストが既に v2 のパスで系統を宣言している
(SSOT 側の書き換えを伴う)」が認識していた書き換えそのものであり、**R-AA-15 がその起票**である。

---

## 6. 残課題 / 要確認

### 6.1 ユーザー判断が必要 (回答で本書の記述が変わる)

- **AA-Q1: 企業ミッション API (`/company-mission` 4 本) を移植しないでよいか**。
  事実: v2 の用途はアカウント単位の「発散セッションの既定ミッション」(V2-F16) であり、
  v3 はミッションを**テーマが持つ** ([themes.md](themes.md) §2.1)。
  [../data-model.md](../data-model.md) に `company_missions` 相当のテーブルは無い。
  選択肢: (a) 移植しない (AA-D-1 の採用案。テーマの `mission` に統合) /
  (b) 移植する (data-model へのテーブル追加 + v3 のミッション概念の二重化を受け入れる)。
  **(a) を前提に設計した**。既存データの扱いは R-AA-6。
  [Answer]: **(a) 移植しない** (2026-07-31 ユーザー回答)。回答前の確認質問「PoC にはないのか」への調査結果:
  **PoC に会社単位の企業ミッションは存在しない** — PoC の mission は**テーマ単位の列**
  (`claude_managed_agents/internal/db/migrations/000016_themes.up.sql:15` の `themes.mission`) で、
  v3 設計 (themes.md TH-Q7) と同じ形。未配線 diverge パッケージの `company_mission` フィールド
  (`claude_managed_agents/internal/agent/diverge/schema.go:262`) も**実体はテーマを代入している**
  (`同 result_helpers.go:135`)。**会社単位ミッションの提供終了は切替告知の対象に追加**
  ([../operations.md](../operations.md) §6.3.1)

- **AA-Q2: 社内管理者による「一般アカウントの MFA リセット」(§2.4) を本増分に含めてよいか**。
  事実: v2 に実装がある (`hassan-v2-backend/router/router.go:217`。全契約横断・Admin / SuperAdmin の
  どちらでも実行可)。**[../auth.md](../auth.md) §6.2 が本増分に含めた社内管理者機能の列挙にはこれが無い**。
  含めない場合の帰結: **MFA 必須の契約で契約内管理者が全員 MFA デバイスを失うと、
  製品内の回復手段が存在しない** — 契約内管理者の `POST /accounts/{id}/mfa/reset` に到達するには
  自身が MFA 検証済みである必要があるため (§3.2 の S2 では §2.2 の 2 本しか叩けない)。
  これは同 §6.9 がロックについて解いた「回復経路が無い」と同型の穴である。
  選択肢: (a) 含める (本書の採用案) / (b) 含めず運用手順 (DB 直更新) に委ねる
  (同 §6.9 の却下 (c) と同じ代償)。
  **(a) を前提に設計した** (エンドポイント 1 本と許可リスト 1 行の追加で済む)。
  [Answer]: **(a) 本増分に含める** (2026-07-31 ユーザー回答)。§2.4 の
  `POST /admin/accounts/{account_id}/mfa/reset` を確定。[../auth.md](../auth.md) §6.2 の
  社内管理者機能の列挙への追加は §5 の R-AA-12 として是正要求

- **AA-Q3: パスワードリセットの成功でアカウントのロックも解除してよいか**。
  事実: v2 は解除しない (V2-F10) ため、**パスワードを忘れて 5 回失敗しロックされた管理者は、
  リセットしても入れない** (`hassan-v2-backend/usecase/account/sign_in.go:71-74` のロック判定が
  パスワード検証より前にある)。これは [../auth.md](../auth.md) §6.9 が「最も起きやすい」とした
  回復経路 2 そのもの。解除しても総当たり耐性は下がらない (解除にはメール受信が必要)。
  選択肢: (a) 解除する (**当初案。2026-07-31 に (b) へ確定したため現在は不採用**) / (b) v2 どおり解除しない
  (社内管理者による解除だけが回復手段になる)。
  **(a) を前提に設計した** (**当初案。2026-07-31 に (b) へ確定**)。(a) が採用された場合は
  [../auth.md](../auth.md) §6.9 の回復経路の表に 4 番目の経路として追記が必要だったが、
  **(b) 確定によりこの追記要求は発生しない**。
  [Answer]: **(b) 解除しない (v2 同様)** (2026-07-31 ユーザー回答。**本書の当初案 (a) は不採用**)。
  リセット成功はパスワードのみを更新し、ロック状態は変更しない — ロック解除は常に管理者経由
  (契約内管理者 / 社内管理者)。手動ロック (意図的な遮断) がリセットで破られない利点を優先した。
  §3.3 のフロー・§3.4 の回復経路表は本回答に合わせて修正済み。auth.md §6.9 への追記要求は不要になった

### 6.2 要確認 (仮定を添えて記載。回答待ちで設計は止めない)

| # | 項目 | 本書の仮定 | 確定先 |
|---|---|---|---|
| **AA-Q4** | **多言語 (日英) の扱い** | v2 は Host で日英を切り替え、契約に `language_type` を持つ (V2-F11)。**v3 は日本語のみ**と仮定し、メールテンプレートを 1 系統、API に言語パラメータを持たせない設計にした ([../infrastructure.md](../infrastructure.md) INF-J のホスト名は環境ごとに 1 つ)。**英語運用が必要なら §2.1 / §2.3.2 のメール送信系に言語の入力が増える** | 要件確認 |
| **AA-Q5** | **メール送信基盤**と**メール到達を前提とするフローの検証方法** | ①**送信基盤**: v2 と同じ **Resend** を使うと仮定した (V2-F11)。`gateway/mail` に置く ([../architecture.md](../architecture.md) §3.3)。**SES へ替える場合、テンプレートの管理方法とバウンス処理が別途必要になる** ②**dev の送信ポリシー** (実メールを送るか / 送信先ドメインを許可リストで制限するか) と③**テストがトークンを取得する経路**が未定。**AA-D-5④ (DB にはハッシュしか保存しない) により選択肢が 1 つに減った** — **DB を読んでも平文トークンは復元できない**ため、**dev / test では `gateway/mail` をキャプチャ実装に差し替えて送信本文からトークンを取り出す**しかない (API から取得する経路は AA-D-6 で作らないと決めた)。**本書の仮定**: **招待受諾 (`/signup?token=…`) とパスワードリセット (`/reset-password?token=…`) の E2E は行わず、I 段 (BE の統合テスト。トークンは `gateway/mail` のキャプチャ実装から取得する) で担保する** — §3.6 が E2E の MFA 例外を `companies.mfa_type='none'` で解いたのと違い、**メールは「送らない」で代替できない** (トークンの到達がフローの本体) ため。**この仮定が変わる場合、②③ の決定が [../testing.md](../testing.md) §7.3 に必要**になる | [../infrastructure.md](../infrastructure.md) (D-5 の資格情報棚卸しと同時) / [../testing.md](../testing.md) §7.3 |
| **AA-Q6** | **会社情報の更新を一般メンバーに開くか** | **v2 どおり全メンバーに開く**と仮定した (v2 の `UpdateCompany` に `IsAdmin()` 判定が無い — V2-F12 に含まれない)。[../auth.md](../auth.md) §9.3 Q-A2 の「v2 で管理者限定だった範囲のみ維持し、新しいロール差を作らない」に従った結果である。**管理者限定にすると R-1 の 403 が 1 本増える** | 要件確認 |
| **AA-Q7** | **パスワードの強度要件** | v2 は `min=8,max=255` のみ (`hassan-v2-backend/controller/dto/account.go:106`, `:130-132`)。**同じ要件で設計した** (400 の条件に「強度違反」と書いた実体はこれ)。**強化する場合、値の SSOT は [../auth.md](../auth.md) §10.2 R-4 の設定 1 箇所に置く** | 要件確認 |
| **AA-Q8** | **メンバー削除の既定挙動** | **回答済み (2026-08-10)**: **(a) 削除せず無効化のみ**。`DELETE /accounts/{account_id}` は **204 の同期 API** になり、`GET /account-deletions/{deletion_id}` と `account_deletions` テーブルは不要。`accounts` に無効化列が要る (§5 **R-AA-27**)。判断は **AA-D-13** に反映済み | [../data-model.md](../data-model.md) DM-Q2 |
| **AA-Q12** | **社内管理者の MFA を将来やるか** | **本増分ではやらない** (AA-D-22)。再開する場合の入口: ①`admin_mfa_configs` を [../data-model.md](../data-model.md) §4.2 に戻す ②[../auth.md](../auth.md) §6.7 の系統を 3 → 4 に戻す ③本書 §2.4 に 3 本を戻す。**②が最も波及が大きい** (全 API ドキュメントの系統宣言) | ユーザー |
| **AA-Q13** | **手動ロックの実装時期** | **設計は確定・実装は 9 月末までの増分の対象外** (2026-08-10 のユーザー決定)。`POST /accounts/{account_id}/lock` は §2.3.2 に残すが実装しない。**`DELETE /accounts/{account_id}/lock` (解除) は v2 にあるため実装する** — 解除だけが先に入るのは v2 と同じ状態であり、[../auth.md](../auth.md) §5-10 の欠陥が本増分では残ることを意味する | ユーザー |
| **AA-Q14** | **監査ログを将来拡張するか** | **本増分では v2 相当に留める** (AA-D-23。**2026-08-14 の AA-D-24 でメンバー作成・メール変更・パスワード変更・会社 MFA 設定変更の 4 件は「v2 に前例が無い」との誤認が判明し復帰済み**)。**残るスコープ外 (ロック・解除・権限変更・削除・招待・`POST /admin/signin`) を将来拡張するか**が本問いの対象。再開する場合の入口: §3.7 の表に行を戻し、[../observability.md](../observability.md) §4.5.1 に値域を足す。**§3.7 の表に行を足すだけで済む**ようにするため、削除ではなく「記録しない対象」として本書に列挙を残してある | ユーザー |
| **AA-Q15** | **社内管理者の初期パスワードの渡し方と、本人による変更経路** (**2026-08-29 起票・同日回答**) | **[Answer]: (c) v2 と同じ「パスワード登録リンクをメールで送る」方式に切り替える** (2026-08-29 オーナー回答)。**確定した設計は AA-D-30** — ①公開 2 本 (`POST /admin/password-registrations/lookup` / `POST /admin/password-registrations` = §2.1) ②再発行 1 本 (`POST /admin/admins/{admin_account_id}/password-registrations` = §2.4 の③) ③`register_admin_password_requests.token` → **`token_hash`** の改名 (AA-D-5④ 準拠。[../data-model.md](../data-model.md) §4.2 に反映済み) ④`InternalAdminView.password_registered` (§2.5)。**同じ差分で変えた箇所**: §2.0 (200 の例外 2 件) / §2.1 (6 → 8 本) / §2.3 (403 15 → 16 本) / §2.4 (12 → 13 本) / §2.5 (`InternalAdminCreated` の廃止) / §2.7 / §3.3 / §3.5 / §3.7 (監査 1 行追加・レート制限 10 → 12 本) / §4 (A-1・A-5・D-2・D-4・D-8) / §5 (R-AA-5 = 対応済み・R-AA-31 = 3 値・R-AA-32・**R-AA-33 / R-AA-34 を新規起票**) / §7、および [../auth.md](../auth.md) §6.2 / §6.3 / §6.7 / §6.11-3、[../data-model.md](../data-model.md) §4.1.2 / §4.2、[README.md](README.md) §0 / §2.5 / §3。**却下された (a) (`PUT /admin/admins/me/password` を 1 本足す) と (b) (作らず運用で受け入れる) の理由は AA-D-29 の却下 (c) に残す** — (b) は「作成者が他人の初期パスワードを知り続ける」ことを受け入れる案であり、オーナーはこれを避ける判断をした。**(a) は本増分では不要になった** (パスワードは最初から本人しか知らず、忘れた場合は再発行で本人が再設定できる。§2.7) — **⚠️ この判断は同日中に AA-D-33 で覆った**: 自己管理 3 本 (`PUT /admin/admins/me` / `/me/email` / `/me/password`) を §2.4 の④として本増分に含める。**理由は「初期パスワードの渡し方」ではなく C-16** (v2 FE に配線済みの 3 画面があり、`admin` ロールには代替経路が無い)。**AA-Q15 の回答は自己管理 3 本を落とすことへの承認ではない** | **回答済み (2026-08-29)** |
| **AA-Q16** | **`POST /accounts` の人数上限 409 も直列化するか** (**2026-08-29 起票。AA-D-31 の影響範囲の確認で検出**) | **本増分では直列化しない**と仮定した。判定 (`deactivated_at IS NULL` の在籍数 < `contracts.num_of_members` — [../data-model.md](../data-model.md) §4.2 の DM-A5 補足 6) は AA-D-31 と同型の TOCTOU を持ち、**同時作成で上限を 1〜数名超過し得る**。**AA-D-31 の対象に含めなかった理由**: 破れたときの結果が**可逆** (超過分を無効化すれば戻せる。DM-A5 補足 7 の「再有効化 API が無い」問題に当たらない) で、かつ**課金・権限のいずれも即時には壊れない**。**直列化するなら手段は AA-D-31 と同じ** — `SELECT … FROM contracts WHERE id = $1 FOR UPDATE` を `POST /accounts` のトランザクション先頭に置く (`accounts` 側の行ロックでは新規 INSERT のファントムを止められないため、ここは親行ロックになる) | ユーザー (超過の許容可否) |
| **AA-Q9** | **招待リンクとリセットトークンの有効期間** | v2 と同じ (**招待 7 日** / **リセット 1 時間**) で設計した (V2-F2 / V2-F10)。値の SSOT は [../auth.md](../auth.md) §10.2 R-4 の設定 1 箇所 (BE-2) | 実装リポの設定設計 |
| **AA-Q13** | **`GET /admin/accounts` の言語絞り込み** | v2 は契約の `language_type` で絞る (V2-F15)。**AA-Q4 の仮定 (日本語のみ) により絞り込みを持たない**設計にした | AA-Q4 と同時 |

### 6.3 本書の仮定 (違えば §3.1 の判断が変わる)

1. **v3 の FE は [../frontend.md](../frontend.md) §11.1 のルート構成を採る**と仮定した。
   `/mfa` と `/mfa/setup` が分かれていることが `mfa.registered` を応答に含める根拠 (§3.2)
2. ~~**契約 (`contracts`) と会社 (`companies`) の作成経路は移行スクリプトのみ**と仮定した~~
   **→ 2026-08-25 に撤回した (Q-10 = A / AA-D-26)**。同仮定が明記していた後続条件
   「**v3 で新規契約を獲得する運用が必要になると、社内管理者向けの契約作成 API が本増分の対象に戻る**」が
   発火し、**§2.4 の②契約管理 4 本が対象に入った**。
   **移行スクリプトが不要になったわけではない** — 既存契約の移送
   ([../data-model.md](../data-model.md) §6.4 / §6.5) は引き続き必要で、**新規作成 API と並存する**。
   両経路が `contracts` を作るため、**代表者メールの重複チェックを同じ規則にする**
   (揃えないと同じメールのアカウントが二重に作られる = BE-11 と同型。要求は同 §6.4 の項目 4)
3. **メンバーの契約間移動は無い**と仮定した (同 §3.4.1-1)。あると `PUT /accounts/{account_id}` に
   `contract_id` の変更が入り、非正規化した `contract_id` の再計算が必要になる

---

## 7. 実装リポへの引き渡し

### 7.1 依存順序

```
[../data-model.md] §4.2 / §4.10 のスキーマ投入 (RL-2 より前に確定が要るもの)
  + R-AA-4  account_deletions (新テーブル)                            … 取り下げ (2026-08-10。DM-Q2 = 無効化のみ)
  + R-AA-17 signup_links の UNIQUE (contract_id, email)              … 未対応 ★RL-2 前
  + R-AA-33 register_admin_password_requests の UNIQUE (admin_account_id) … 未対応 ★RL-2 前 (2026-08-29。AA-D-30)
  + R-AA-5  register_admin_password_requests.token → token_hash      … 実施済み (2026-08-29。AA-D-30②)
  + R-AA-30 activity_logs の CHECK 緩和 (admin_account かつ契約なし)      … 未対応 ★RL-2 前 (2026-08-29。AA-D-29)
  + R-AA-18 admin_mfa_configs (新テーブル)                            … 取り下げ (2026-08-10。AA-D-22)
  + R-AA-28 admin_mfa_configs の削除                                 … 実施済み (2026-08-10)
  + R-AA-27 accounts の無効化列 (DM-Q2 = 無効化のみ)                  … 実施済み (2026-08-10。DM-A5)
  + R-AA-21 signup_links.token_hash / reset_password_requests.token_hash … 実施済み (2026-07-31。列は改名)
  + R-AA-19 activity_logs の actor_type='unauthenticated' + NULL 可 + CHECK … 実施済み
            (残るは detail.email_hash を HMAC + pepper にすること。列定義には影響しない)
   ↓
共通層: 認証ミドルウェア 2 系統 + MFA ゲート + 系統ホワイトリスト
        + CodedError マッピング (**§3.1.1 の `AU-T-*` / `AU-C-*` 10 コードを `constants` に定義**)
        + レート制限ミドルウェア + gateway/mail + gateway/s3 (署名付き URL)
        + 秘密文字列の生成・ハッシュ化ヘルパー (crypto/rand 32B → base64url / SHA-256。AA-D-5④)
   ↓
┌──────────────┬────────────────┬──────────────┬────────────────┐
§2.1 公開 8 本   §2.2/§2.3.1 自分  §2.3.2 メンバー  §2.4 社内管理者     ← 並列可
  ↑ うち AA-D-30 の公開 2 本は §2.4 の③ (発行側) と対で作る — 片方だけ入れると
    「リンクは届くが設定できない」/「設定 API はあるが誰も発行しない」になる (BE-10)
  ↑ §2.4 の③ (PUT /admin/admins/{id}) と④ (PUT /admin/admins/me) は同じ admin_accounts 行を
    更新するため、**UNIQUE 違反 → 409 の写像と bcrypt 生成を 1 箇所に集約して両方から使う**
    (入口ごとに書き分けない = BE-2。AA-D-33 の代償③)
                                      ↓
                          §2.3.2 DELETE /accounts/{id} は
                          (2026-08-10: 移管ジョブは作らない = DM-Q2。依存なし)
```

- **共通層を先に完成させる** — 系統ホワイトリストと CI 検査 ([../auth.md](../auth.md) §6.7) が
  後回しになると、公開エンドポイントの追加が素通りとして現れる (AC-1.1)
- **未対応の是正要求のうち、着手を止めるものは 2 種しかない** (2026-07-31 の状態列に基づく):
  ①**RL-2 (初期スキーマ投入) より前**: **R-AA-17** (`signup_links` の `UNIQUE (contract_id, email)`) と
  **R-AA-27** (`accounts.deactivated_at` = DM-A5。**R-AA-4 の `account_deletions` は取り下げ済み**) ②**共通層の実装より前**: **R-AA-15**
  (公開ホワイトリストが `GET /accounts/signup-links/:id` / `POST /accounts/reset-password/:hash` の
  **旧パスのまま**。この表が CI 検査の入力なので、①実装が旧パスを作るか②新パスが未宣言で落ちるかが確定で起きる) と
  **R-AA-2a③** (403 の第 3 系統 = R-3)。**2026-08-29 に①へ 2 件追加した**: **R-AA-33** (`register_admin_password_requests` の `UNIQUE (admin_account_id)` — AA-D-30④ の再発行が R-AA-17 と同型のレースを持つ) と **R-AA-30**
  (`activity_logs` の `CHECK` — AA-D-29 の監査行は `actor_type='admin_account'` かつ契約に紐づかないため
  **現在の `CHECK` では INSERT が失敗する**。`CHECK` はスキーマなので RL-2 より前に確定が要る)。
  **それ以外の未対応 (R-AA-3 / 6 / 7③ / 13 / 14 / 23 / 24 / 25 / 31 / 32 / 34 / 35。**R-AA-5 は 2026-08-29 に対応済みへ変わった**) は
  並列で進められる** (**R-AA-35** = auth.md §6.9 のガード行への直列化要求 (AA-D-31) は**スキーマを伴わない**が、
  **§2.3.2 の 3 本 (`PUT` / `DELETE` / `POST …/lock`) の実装より前に反映する** — 反映前は SSOT 側が
  「`COUNT` だけで足りる」と読める状態が残り、実装者が §3.4 と auth.md のどちらを見たかで結果が変わる) — ただし **R-AA-6 (`company_missions` の既存データ) は移行設計 (DM-A2) の締切に間に合わせる**
  (移行後に気づくとデータが消えている) と **R-AA-23 (pepper の棚卸し) は RL-2 の完了条件②に間に合わせる**の 2 点は例外
- **`§2.3.2` と `§2.4` は同じ増分に入れる** (**本数は §2 の見出しが正**。DR-9) — 読む側 (ロック状態の表示) と
  書く側 (ロック / 解除) と回復側 (社内管理者) が揃って初めてロック機構が成立する (§3.4 = BE-10)
- **§2.2 の 2 本と MFA ゲートは同時** — ゲートだけ入れると MFA 必須の契約が誰も入れなくなる

### 7.2 参照すべき既存実装

| 目的 | 参照先 |
|---|---|
| 認証ミドルウェアの判定順序 (v3 は空 role を拒否・全 enum 網羅・**`deactivated_at` を判定** = AA-D-32①。**社内管理者側に MFA 判定は追加しない** = AA-D-22) | `hassan-v2-backend/auth/middleware.go:23-86` (**ロック判定 `:70-74` の直後に無効化判定を足す形**。[../auth.md](../auth.md) §6.1 の変更点 3 / 4 / 5) |
| 社内管理者ミドルウェア (**v3 も MFA 判定を持たない** = AA-D-22。v2 と同じ) | `hassan-v2-backend/auth/middleware.go:88-131`、`:153-163` (SuperAdmin) |
| JWT クレームと署名 | `hassan-v2-backend/auth/client.go:32-38`, `:66-95` |
| サインイン (失敗回数・ロック・マスク) | `hassan-v2-backend/usecase/account/sign_in.go:57-133` |
| TOTP の生成・検証・リセット | `hassan-v2-backend/usecase/mfa/create_totp.go:29-61`、`verify_totp.go:46-88`、`reset_totp.go:25-46` |
| 招待リンク (契約検証の正しい例 = [../auth.md](../auth.md) §6.4 の種別⑥) | `hassan-v2-backend/usecase/account/create_signup_link.go:43-93` |
| 最後の管理者ガード (**判定の構造は移植しない** — v2 は `COUNT` を単独で撃ちトランザクションを張らない。**v3 は §3.4 の `LockContractAdminsForGuardInContract` + 同一トランザクション内の UPDATE** = **AA-D-31**) | `hassan-v2-backend/usecase/account/delete_account.go:46-55`、`update_account_by_admin.go:63-72` (**どちらもトランザクションを張らず、カウントと更新を別々の文として発行している** — `delete_account.go:48` の `CountAdminsByContractID` と `:58` の `DeleteAccount`、`update_account_by_admin.go:65` の `CountAdminsByContractID` と `:75` の `UpdateAccountByAdmin`)。**実装リポ hassan-v3 の適用先は `usecase/account/update_member.go` (降格) / `usecase/account/deactivate_member.go` (無効化) / 手動ロックの UseCase の 3 本** — **トランザクション境界の変更を伴うため 3 本を同じ PR で直す** (issue #108。1 本だけ直すと交差経路が残る = AA-D-31③) |
| 社内管理者向け一覧 (`total_count` の窓関数・ロック列) | `hassan-v2-backend/db/queries/account.sql:86-120` |
| 社内管理者アカウントの作成・更新 (**AA-D-29**。**パスワード登録リンクの発行・送信 `:90`-`:110` も移植する** — 2026-08-29 の AA-Q15 = (c) / **AA-D-30**。**ただし `token` を平文で保存する点だけは移植しない** = `token_hash` へ) | `hassan-v2-backend/usecase/admin_account/create_admin_account.go:50-110`、`update_admin_account_details.go:28-40`、ロール判定は `hassan-v2-backend/router/router.go:206-210` (v2 も全 5 本が `CheckSuperAdminRole()`)、`name` / `email` の UNIQUE は `hassan-v2-backend/db/schema.sql:54-55` |
| **社内管理者の自己管理 3 本** (**AA-D-33**。氏名・メール・パスワード) | `hassan-v2-backend/usecase/admin_account/update_admin_account_name.go:24-28`、`update_admin_account_email.go:27-42`、`update_admin_account_password.go:27-45`、ルートとロール判定の不在は `hassan-v2-backend/router/router.go:202-204` (`AdminAuthRequiredMiddleware` のみ)。**移植しないもの**: **対象 ID をボディで受ける形** (`hassan-v2-backend/controller/dto/admin_account.go:57-60`, `:62-66`, `:75-79` の `ID` フィールドと `hassan-v2-backend/controller/admin_account.go:272-295`) — **氏名変更に所有権検証が無く他の社内管理者の氏名を書き換えられる** (V2-D7)。v3 は JWT の `admin_account_id` から解決する |
| メール送信 (Resend。**テンプレートは v3 で作り直す**) | `hassan-v2-backend/usecase/account/email_service.go:1-60` |
| Controller のレスポンス / エラーヘルパー (**v3 は 401 に本文を持つ点が違う** — §3.1.1) | `hassan-v2-backend/controller/controller.go:30-125` |
| エラーコードの定義形式 (`<カテゴリ 2 文字>-E-<5 桁>`。v3 は `AU-T-` / `AU-C-` を追加 — §3.1.1) | `hassan-v2-backend/constants/errors.go:8-19` (カテゴリ列挙)、`hassan-v2-backend/constants/errors_account.go:6` (`AC-E-00001`)。**`AU-*` を追加・改名したら本書 §3.1.1 の表を同じ PR で更新する** (CI が照合する = §4 の D-2 ③) |
| **移植しないもの** | `hassan-v2-backend/util/util.go:20-36` (`RandStringRunes` / `GenerateSecureToken` — [../auth.md](../auth.md) §6.10-2)、`hassan-v2-backend/controller/dto/account.go:139-141` (`RequestResetPasswordRes.Hash` — V2-D3) |

### 7.3 テストで必ず固定する振る舞い (UT の必須ケース)

| # | ケース | 根拠 |
|---|---|---|
| 1 | **`POST /accounts/signup` が他契約の未サインアップアカウントを乗っ取れない** (トークンから解決した `(contract_id, email)` 以外のアカウントに到達しない) | V2-D1 |
| 2 | **MFA 未検証トークンで §2.2 以外のルートが 401 + `AU-T-00005` になる** (パス前方一致でないこと。`/mfa` 接頭辞の別ルートを追加しても漏れない) | [../auth.md](../auth.md) §6.7 / V2-F7 |
| 3 | **他契約の `account_id` を指定したロック / 解除 / MFA リセット / 更新 / 削除がすべて 404** (**契約内管理者が実行した場合**。一般メンバーが実行した場合は①で止まり 403 = AA-D-19) | V2-D4 / [../auth.md](../auth.md) §6.6 / §3.1.2 |
| 4 | **最後の未ロック契約内管理者のロックが 403** (管理者 3 名を順にロックしても全員ロックに到達しない) | §3.4 |
| 5 | **リセット要求が未登録メールでも 204**、応答本文が空 | AA-D-6 |
| 6 | **トークン不正・期限切れ・使用済みが同一の 404 + 同一コード** | AA-D-6 |
| 7 | **MFA コード不一致が 401 + `AU-C-00003`** (500 にならない。**分類 C** = 本文の code 接頭辞が `AU-C-`) | V2-D2 / §3.1.1 |
| 8 | **`GET /accounts` が `limit` 既定 50・上限超過で 400・`total_count` を返す** | [README.md](README.md) D-API-5 / D-API-7 |
| 9 | **`PUT /accounts/me/password` の `old_password` 不一致が 400 + `AU-C-00004`** で、**同一トークンで直後に `GET /accounts/me` が 200 を返す** (セッションが無効化されていない) | AA-D-17 / §3.1.1 |
| 10 | **一般メンバーが `{account_id}` を指定する管理者操作は、対象が自契約・他契約・不存在のいずれでも 403** (404 が漏れない) | AA-D-19 / §3.1.2 |
| 11 | **ミドルウェアが返す 401 の `code` が `AU-T-` 接頭辞、資格情報不一致の 401 が `AU-C-` 接頭辞**であること (両者を取り違えると強制サインアウトか無限 401 になる) | §3.1.1 |
| 12 | **`POST /accounts/reset-password/confirm` の成功後も `last_locked_at` / `failed_sign_in_attempts` が変化しない** (リセットはロックを解除しない。**「親切な実装」として解除が入る退行を止める**) | AA-Q3=b / V2-F10 |
| 13 | **契約内管理者の `POST /accounts/{account_id}/mfa/reset` が、他契約のアカウントを指定したとき `account_mfa_configs` を 1 行も削除せずに 404** を返すこと (§3.5 脚注 2 の 1 段目を省いた実装を落とす。**`account_mfa_configs` は `contract_id` を持たないため SQL 検査では防げない**) | §3.5 脚注 2 / A-4 |
| 14 | **`POST /admin/password-registrations` が期限切れトークンで 404 を返し、`admin_accounts.crypted_password` を書き換えないこと** (**lookup を通さず直接叩いた場合**。v2 は設定側に期限判定が無く、期限切れでも設定できた — `hassan-v2-backend/usecase/admin_account/register_password.go:33-58`) | AA-D-30⑤ |
| 15 | **`POST /admin/password-registrations` の成功後、同じトークンでの再実行が 404 になり、`GET /admin/admins` の `password_registered` が false → true に変わること** (登録要求行の削除が読み手と書き手の対になっている) | AA-D-30⑥ / BE-10 |
| 16 | **`POST /admin/admins/{admin_account_id}/password-registrations` を 2 回続けて呼ぶと、`register_admin_password_requests` の該当 `admin_account_id` の行が常に 1 行で、古いトークンが 404 になること** | AA-D-30④ / R-AA-33 / BE-11 |
| 17 | **管理者 2 名 (A・B) の契約で、A の削除と B の削除を 2 本のトランザクションから同時に実行すると、片方が 403 になり、`deactivated_at IS NULL AND auth_role_id = 1` の行が必ず 1 行以上残ること**。**同じ検査を `PUT`(降格)×`PUT` / `PUT`×`DELETE` / `POST …/lock`×`DELETE` の組でも行う** (交差経路)。**実 PostgreSQL を使う** ([../testing.md](../testing.md) T-B。`sqlmock` では行ロックの効果が見えない) | AA-D-31 / §3.4 |
| 18 | **既に無効化された管理者しか残っていない契約で、最後の有効な管理者の削除・降格が 403 になること** (`AND deactivated_at IS NULL` を落とすと通ってしまう。**並行実行を伴わない退行検査**) | AA-D-31 / [../data-model.md](../data-model.md) §4.2 の DM-A5 |
| 19 | **無効化済みアカウントの有効なトークンで任意の認証必須エンドポイントを叩くと 401 + `AU-T-00006`** になること (**トークン自体は署名・期限とも有効なまま**であることをテスト内で確認する = 判定 g が効いていることの証拠)。**`AU-C-00006` (分類 C) が返ると FE がセッションを破棄せず 401 ループになる**ため、`code` の値まで固定する | AA-D-32① / §3.1.1 / [../auth.md](../auth.md) §6.1 の変更点 5 |
| 20 | **未使用の招待リンクを発行済みのメンバーを無効化した後、そのトークンで `POST /accounts/signup` を呼ぶと 404 + 招待リンク不正と同一のコードになり、`accounts.crypted_password` と `is_completed` が変化しないこと**。**多層防御の 2 段を独立に固定する** — (a) 無効化時のリンク削除 (AA-D-32③) を無効にしたビルドでも 404 になること (b) 無効化後に `signup_links` に当該アカウント宛ての行が 0 行であること。**専用コード・403 を返す実装は落とす** (AA-D-32 却下 (b) = 存在の間接的な確認手段になる) | AA-D-32②③ / AA-D-6 / §7.3 の 6 |
| 21 | **`PUT /admin/admins/me` がボディやクエリで対象 ID を受け取らず、更新されるのが JWT の `admin_account_id` の行だけであること** (v2 の DTO をそのまま移植すると、**`admin` ロールが他の社内管理者 (SuperAdmin を含む) の氏名を書き換えられる** = V2-D7。**「`id` を送っても無視される」ではなく「受け取る口が無い」ことを固定する** — リクエストに未知フィールドを足しても他人の行が変わらないこと) | V2-D7 / AA-D-33③ |
| 22 | **`admin` ロールのトークンで §2.4 の④ 3 本が 200 / 200 / 204 を返し、同じトークンで③の `PUT /admin/admins/{admin_account_id}` が 403 になること** (**ロール判定を④に付け足す退行を落とす**。v2 も `hassan-v2-backend/router/router.go:202-204` にロール判定は無い) | AA-D-33② / A-2 |
| 23 | **`PUT /admin/admins/me/password` の `old_password` 不一致が 400 + `AU-C-00004`** で、**同一トークンで直後に `GET /admin/me` が 200 を返す** (セッションが無効化されていない。**ユーザー側の必須ケース 9 の社内管理者版**) | AA-D-33④ / AA-D-17 / §3.1.1 |
