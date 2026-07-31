# v2 認証・テナント境界 事実収集 (poc-analyst)

> 実測日: 2026-07-29 / 対象: hassan-v2-backend (作業ツリー)

調査範囲: `hassan-v2-backend` の `auth/` `db/schema.sql` `db/queries/` `controller/` `usecase/` `router/` 配下。
`.worktrees/` `vendor/` は対象外。`docs/design/auth.md` (既存の v2 事実整理) を突き合わせ資料として使ったが、
本書の記述は**すべて一次ソース (Go コード / SQL) を自分で読み直して確認した事実**であり、転記ではない。
既存資料と食い違う箇所・既存資料に無い追加の発見は明記した。

## 調査対象と問い

hassan_v3 の本番設計 (`docs/design/auth.md`, `docs/design/API/`) が前提とする「v2 準拠の認証・テナント境界」
について、(1) トークン検証の全体像、(2) ロールとミドルウェア適用範囲、(3) 契約/会社/アカウントの FK 構造、
(4) 所有者カラムの分布、(5) 所有者絞り込みの実装層、(6) 401/403/404 の判定実例、(7) v3 が流用しうる既存機構の
稼働状況、を出典付きで裏取りする。

---

## 事実

### 1. トークンの受け渡しと検証

**ヘッダは 3 種類宣言され、実際に読まれるのは 2 種類**(`hassan-v2-backend/auth/middleware.go:15-17`)。

| ヘッダ名 | 変数 | 用途 | 検証関数 | 稼働状況 |
|---|---|---|---|---|
| `X-Token` | `HeaderKey` (`middleware.go:15`) | 一般ユーザー | `ParseToken` (`auth/client.go:70-87`) | 稼働 (`middleware.go:25`) |
| `X-Admin-Token` | `AdminHeaderKey` (`middleware.go:16`) | 管理者 | `ParseAdminToken` (`auth/client.go:99-120`) | 稼働 (`middleware.go:90`) |
| `Auth-Token` | `AuthTokenHeaderKey` (`middleware.go:17`) | 不明 | — | **デッドコード** |

`Auth-Token` に対応する `PrivateAPIAuthToken` フィールド (`auth/client.go:17`) は `NewAuthClient` の第2引数として
配線され (`auth/client.go:40-50`, `di/provider.go:117`)、環境変数 `PRIVATE_API_AUTH_TOKEN` から供給される
(`di/provider.go:32`。**`JWT_KEY`/`ADMIN_JWT_KEY` と違い `required` タグが無い**)。
リポジトリ全体を `AuthTokenHeaderKey` / `PrivateAPIAuthToken` の 2 軸で `grep` した結果、
テスト以外のコードで `c.Request.Header.Get` 等から読み出す箇所は無い。**宣言されているが未使用**。

**JWT クレーム構成** (`auth/client.go:32-38`):

```go
type JwtClaims struct {
    UserUid         string   `json:"user_uid"`          // accounts.id (UUID文字列)
    Role            AuthRole `json:"role"`               // "User" / "Consultant"
    RequiredMfaType string   `json:"required_mfa_type"` // companies.mfa_type のスナップショット
    MfaVerified     bool     `json:"mfa_verified"`
    jwt.StandardClaims                                   // ExpiresAt のみ設定
}
```

| 項目 | 値 | 出典 |
|---|---|---|
| 署名アルゴリズム | HS256 | `auth/client.go:66` (`jwt.SigningMethodHS256`) |
| alg 混同攻撃対策 | 検証時に `token.Method.(*jwt.SigningMethodHMAC)` を確認 | `auth/client.go:72-74` |
| 鍵の取得元 (ユーザー) | 環境変数 `JWT_KEY` (`required`) | `di/provider.go:30` |
| 鍵の取得元 (管理者) | 環境変数 `ADMIN_JWT_KEY` (`required`、ユーザーと**別鍵**) | `di/provider.go:31` |
| 有効期限 (sign-in 発行) | 7日 (`time.Now().Add(time.Hour*24*7)`) | `usecase/account/sign_in.go:112` |
| 有効期限 (MFA検証後の再発行) | 7日 (同上の式) | `usecase/mfa/verify_totp.go:76` |
| 有効期限 (管理者) | 7日 | `auth/client.go:94` (`CreateAdminJwtString`) |
| 管理者トークンのクレーム | `uid` / `exp` のみ (ロール情報なし。`jwt.MapClaims`) | `auth/client.go:91-96` |

**リフレッシュ機構**: 無い。`GetSignedString` (ユーザー用トークン発行) の呼び出し元はリポジトリ全体で
`usecase/account/sign_in.go:116` と `usecase/mfa/verify_totp.go:79` の 2 箇所のみ (grep で確認)。
どちらも「新規発行」であって、既存トークンを検証して延長する経路ではない。

**失効 (revoke) 機構**: 無い。ブラックリストやトークンバージョン管理は見つからなかった。
唯一のサーバー側状態は `accounts.last_locked_at` で、`AuthRequiredMiddleware` が毎リクエスト
`ac.ar.GetAccountByID` で DB を引いて判定する (`auth/middleware.go:59-74`)。ステートレス JWT ではなく
「JWT + アカウント実在確認」の混成。

**ライブラリ**: `github.com/dgrijalva/jwt-go` (`auth/client.go:11`)。パッケージの保守状況 (アーカイブ済みか等) は
本調査では確認していない (外部情報のため対象外、§「未調査」参照)。

### 2. ロール

**`auth.AuthRole`** (JWT レベルのロール。文字列型、`auth/client.go:25-30`):

| 値 | 定義 | router.go からの参照数 | 実際の挙動 |
|---|---|---|---|
| `AuthRoleUser` (`"User"`) | `auth/client.go:28` | 98 (`grep -c "AuthRequiredMiddleware(auth.AuthRoleUser)" router/router.go`) | `AuthRequiredMiddleware` の `switch role` に `case AuthRoleUser:` あり (`middleware.go:50`) |
| `AuthRoleConsultant` (`"Consultant"`) | `auth/client.go:29` | **0** (定義のみ、非テストコードからの参照なし) | `switch role` に対応する `case` が無い。渡された場合、JWT 検証・MFA 検証は実行されるが (`middleware.go:32-47`)、その後の分岐 (`middleware.go:49-84`) は何も一致せず、**アカウント実在確認・ロック確認・context への格納・`c.Abort()` のいずれも実行されずに関数を抜ける**。後続ハンドラで `auth.GetAuthenticatedAccount` (`middleware.go:138-141`) を呼ぶと、`c.Get` が返す `nil` に対する型アサーション `res.(*entity.Account)` が `panic` する (Go の言語仕様上、`,ok` を伴わない失敗する型アサーションは panic するため確定的な帰結) |

**`entity.AuthRole`** (契約内の管理者/メンバー区別。`accounts.auth_role_id` / `admin_accounts.auth_role_id` が
参照する DB レベルのロール。int 型、`entity/auth_role.go:5-10`): `authRoleAdmin = 1`、`authRoleMember = 2`。
`IsAdmin()` (`entity/auth_role.go:20-22`) が `controller/sharing_settings.go:37`、`controller/company.go:531`、
`controller/event_logs.go:47` で使われる。

> **注意 (命名衝突)**: `auth.AuthRole` (JWT の "User"/"Consultant") と `entity.AuthRole` (DB の管理者/メンバー、
> int) は**別パッケージの別概念**でありながら同名の型名を持つ。v3 の設計・実装で参照する際に混同しやすい。

**`entity.AdminAuthRole`** (社内管理者の権限段階。`entity/admin_auth_role.go:5-14`): `AdminAuthRoleSuperAdmin = 1`、
`AdminAuthRoleAdmin = 2`。`CheckSuperAdminRole` (`auth/middleware.go:153-163`) が使用。

**`router.go` のミドルウェア適用範囲**:

| ミドルウェア/ロール | 適用方式 | 対象 | 出典 |
|---|---|---|---|
| `AuthRequiredMiddleware(auth.AuthRoleUser)` | ルート個別指定 (98箇所) + Group.Use 1箇所 | `/contracts`, `/accounts` (signup/signin/signup-links(GET)/reset-password系を除く), `/themes`, `/companies`, `/company-mission`, `/assets`, `/ideas`, `/idea-boards`, `/idea-hassans`, `/business-plans`(+`/detailed`), `/research-chats`, `/research-sheets`, `/sharing-settings`, `/news`, `/event_logs`(2件) | `router.go` 各行、`/mfa` は Group.Use (`router.go:230`) |
| `AdminAuthRequiredMiddleware()` | 個別1箇所 + Group.Use 2箇所 (計3) | `GET /admin/me` (`:196`, 個別)。`adminAccountRoute` (`:201`) — ただし `:199-200` の2ルートは `.Use()` より**前**に登録されており適用外。`adminCompanyRoute` (`:214`) — Group生成直後の1行目なので全ルートに適用 | `router.go:196,201,214` |
| `CheckSuperAdminRole()` | `AdminAuthRequiredMiddleware` 適用後に追加で5箇所 | `POST /admin/accounts`(`:206`), `GET /admin/accounts/:id`(`:207`), `DELETE /admin/accounts/:id`(`:208`), `PUT /admin/accounts/details`(`:209`), `GET /admin/accounts/auth_roles`(`:210`) | `router.go:206-210` |
| なし (公開) | — | `POST /accounts/signup`(`:75`), `POST /accounts/signin`(`:76`), `GET /accounts/signup-links/:id`(`:78`), `POST /accounts/reset-password`(`:79`), `POST /accounts/reset-password/:hash`(`:80`), `POST /webhook/microcms/news`(`:192`, HMAC署名検証で保護 — `controller/webhook.go:39,49-53`), `POST /admin/signin`(`:195`), `GET /admin/accounts/register/password/check`(`:199`), `POST /admin/accounts/register/password`(`:200`) | `router.go` 各行 |

### 3. アカウント基盤のデータ構造 (FK ベース)

```
contracts (id)                          ← テナント境界の頂点
├── companies.contract_id  (FK, ON DELETE CASCADE, UNIQUE INDEX)  … 0..1件 (schema.sql:79-92)
├── accounts.contract_id   (FK, ON DELETE CASCADE, 通常INDEX)     … 0..N件 (schema.sql:30-50)
│    └── accounts.auth_role_id → auth_roles.id (FK)  (schema.sql:35,46)
└── (companies / accounts 経由で全機能テーブルが account_id / contract_id により束ねられる)

admin_accounts   … contracts/accounts への FK なし。auth_role_id / admin_auth_role_id のみ参照 (schema.sql:52-64)
consultant_accounts … FK 一切なし。完全に独立したテーブル (schema.sql:322-330)
```

- `companies.contract_id` に `UNIQUE INDEX unique_companies_contract_id` (`schema.sql:92`) があるため、
  1契約につき会社情報は**最大1件** (0件も許容されるため厳密には 0..1:1)。
- `accounts.contract_id` は `UNIQUE` ではなく通常の `INDEX idx_accounts_contract_id` (`schema.sql:50`) のため
  1契約に複数アカウント (1:N)。
- `admin_accounts` / `consultant_accounts` はどちらも `contracts` / `accounts` に FK で接続されていない。
  社内スタッフ (admin) やコンサルタントは契約に属さない別系統のエンティティ。
- **契約 (`contracts`) が束ねる単位**: 1契約 = 会社情報 (`companies`, 最大1件) + 複数ユーザー (`accounts`, 1:N)。
  各機能テーブルは `accounts` 経由 (`account_id`) または `contracts` 経由 (`contract_id`) でこの契約に属する。
  「契約 = テナント」がスキーマ上の境界の頂点。

**所有者到達チェーンの実例** (直接 `account_id` を持たないテーブルは親を辿る):

| テーブル | 到達経路 | 出典 |
|---|---|---|
| `ideas` | `idea_hassan_id` → `idea_hassans.account_id` | `schema.sql:153,177` (FK), `:122,145` (FK) |
| `business_plans` | `idea_id` → `ideas` → `idea_hassans.account_id` | `schema.sql:184,201` |
| `asset_documents` | **到達経路なし** (`id`/`file_text`/`created_at`/`updated_at` の4カラムのみ、FK皆無) | `schema.sql:510-516` |

`asset_documents` は所有者へ辿る手段がスキーマ上に存在しない。`assets` との対応は命名からの**推測**であり、
外部キーによる保証はない (確信度: 中、§推測 参照)。

### 4. 所有者カラムの分布

`schema.sql` の `CREATE TABLE` は **36件** (`grep -c "^CREATE TABLE" schema.sql` で確認)。

| 所有者カラム | 件数 | 検証 |
|---|---|---|
| `account_id` | 17 | 下表 |
| `contract_id` | 5 | 下表 |
| `company_id` | **0** | `grep -n "company_id" schema.sql` は無ヒット。**v2 スキーマに `company_id` というカラムは存在しない** |
| どちらも無し | 14 | `contracts`,`auth_roles`,`admin_auth_roles`,`admin_accounts`,`ideas`,`business_plans`,`business_plan_chats`,`business_plan_chat_messages`,`business_plan_histories`,`consultant_accounts`,`signup_links`,`register_admin_password_requests`,`asset_documents`,`research_sheet_contents` |

**`account_id` を持つ17テーブルの FK・インデックス有無**:

| テーブル | FK制約 | 単独/先頭列インデックス | 出典 |
|---|---|---|---|
| `account_mfa_configs` | あり (`:76`) | PK `(account_id, mfa_type)` で先頭列 (`:75`) | `schema.sql:68-77` |
| `themes` | あり (`:101`) | **なし** | `schema.sql:94-102` |
| `assets` | あり (`:116`) | **なし** | `schema.sql:104-117` |
| `idea_hassans` | あり (`:145`) | `idx_idea_hassans_account_id` (`:149`) | `schema.sql:119-149` |
| `business_plan_favorites` | あり (`:212`) | PK `(account_id, business_plan_id)` で先頭列 (`:211`) | `schema.sql:206-214` |
| `business_plans_detailed` | あり (`:291`) | `idx_business_plans_detailed_account_id` (`:296`) | `schema.sql:260-297` |
| `business_plan_detailed_histories` | **なし** (FKは `(idea_id, version)` 複合のみ、`:307`) | **なし** | `schema.sql:299-310` |
| `reset_password_requests` | あり (`:319`) | **なし** | `schema.sql:312-320` |
| `research_chats` | あり (`:339`) | PK `(account_id, conversation_id)` で先頭列 (`:338`) | `schema.sql:332-340` |
| `asset_usage_histories` | あり (`:355`) | PK `(account_id, asset_id)` で先頭列 (`:354`) | `schema.sql:350-357` |
| `activity_logs` | **なし**、`account_id` は NULL 許容 (`:484`) | **なし** | `schema.sql:482-489` |
| `research_titles` | **なし** (`:522`) | **なし** (PKは`conversation_id`のみ) | `schema.sql:520-527` |
| `research_conversation_histories` | **なし** (`:531`) | **なし** | `schema.sql:529-539` |
| `read_news_accounts` | **なし** (`:557`) | PK `(news_id, account_id)` だが `account_id` は非先頭列 (`:560`) | `schema.sql:555-561` |
| `news_email_logs` | あり (`:574`) | `UNIQUE(news_id, account_id)` だが `account_id` は非先頭列 (`:573`) | `schema.sql:563-575` |
| `company_missions` | あり (`:583`) | **なし** | `schema.sql:577-584` |
| `event_logs` | あり (`:592-595`) | `idx_event_logs_account_created(account_id, created_at)` (`:597`) | `schema.sql:586-597` |

**`contract_id` を持つ5テーブル**:

| テーブル | FK制約 | インデックス | 出典 |
|---|---|---|---|
| `accounts` | あり (`:45`) | `idx_accounts_contract_id` (`:50`) | `schema.sql:30-50` |
| `companies` | あり (`:89`) | `unique_companies_contract_id` (`:92`、1:1保証) | `schema.sql:79-92` |
| `sharing_settings` | あり (`:497`) | PK `(contract_id, category)` 先頭列 (`:498`) | `schema.sql:491-499` |
| `idea_boards` | あり (`:609-610`) | **なし** | `schema.sql:599-613` |
| `idea_board_phases` | あり (`:622-623`) | `UNIQUE(contract_id, name)` 先頭列 (`:624`) | `schema.sql:615-625` |

`account_id`/`contract_id` を持つテーブルのうち、FK 制約が**存在しない**もの (`research_titles`,
`research_conversation_histories`, `read_news_accounts`, `activity_logs`, `business_plan_detailed_histories`) は
スキーマレベルでは所有者の整合性が保証されておらず、アプリケーションコードの正しさに依存する。

### 5. 絞り込みの実装層 (一覧系エンドポイント3例)

3例とも「Controller は絞り込み判断をせず認証情報を UseCase の Input に詰めるだけ」「UseCase がスコープを決定」
「Repository の SQL WHERE が最終的な絞り込みを行う」という基本構造は共通。しかし **UseCase 層でのクロステナント
ガードの有無が一貫していない**ことを検証で確認した。

**例A: `GET /themes` (ListThemes)**

| 層 | 内容 | 出典 |
|---|---|---|
| Controller | `authAccount.ContractID`/`.ID` とクエリの`account_id`(任意)を UseCase Input に渡すのみ | `controller/theme.go:51-86` |
| UseCase | 共有設定 (`idea`カテゴリ) を確認 (`:44-53`) した上で、本人のみ/指定`account_id`/契約全体、のいずれかに分岐 (`:49-72`)。**指定`account_id`が呼び出し元と同じ契約に属するかのチェックが無い** — `account == nil` のみ確認し (`:60-62`)、`account.ContractID` と `input.ContractID` の比較が無い | `usecase/theme/list_themes.go:39-91` (特に `:55-66`) |
| Repository | `ListThemesByAccountID`: `WHERE account_id = $1` | `db/queries/theme.sql:16-24` |
| Repository (契約全体) | `ListThemesByContractID`: `WHERE ac.contract_id = $1` | `db/queries/theme.sql:4-14` |

**例B: `GET /assets` (ListAssetsByAccountID ハンドラ)**

| 層 | 内容 | 出典 |
|---|---|---|
| Controller | `AccountID`/`ContractID`/`RequestAccountID`(`c.Query("account_id")`) を Input に渡すのみ | `controller/asset.go:99-107` |
| UseCase | 共有設定 (`asset`カテゴリ) を確認 (`:72-79`)。指定`account_id`がある場合、**`account.ContractID != input.ContractID` を明示チェック** (`:61-68`) | `usecase/asset/list_assets.go:45-103` |
| Repository | `ListAssetsByAccountID`: `WHERE account_id = $1` / `ListAssetsByContractID`: `WHERE ac.contract_id = $1` | `db/queries/asset.sql:16-39`, `:41-60` |

**例C: `GET /business-plans` (ListBusinessPlans)**

| 層 | 内容 | 出典 |
|---|---|---|
| Controller | Input を組み立てて UseCase へ委譲 | `controller/business_plan.go:542-546` |
| UseCase | 指定`account_id`がある場合 `account.ContractID != input.ContractID` を明示チェック (`:56`)。共有設定 (`business_plan`カテゴリ) も確認 (`:63-69`) | `usecase/business_plan/list_business_plans.go:42-84` |
| Repository | `ListBusinessPlansByAccountID`: 3段JOIN (`business_plans`→`ideas`→`idea_hassans`) の上で `WHERE ih.account_id = $1` | `db/queries/business_plan.sql:118-132` |

**層がばらついている事実**: theme (例A) には asset (例B)・business_plan (例C) と同型の
「指定`account_id`が自分の契約に属するか」のチェックが**無い**。共有設定 (`idea`カテゴリ) が有効な契約で、
存在する他契約のアカウントIDをクエリパラメータに指定すると、`GetAccountByID` は non-nil を返し
(存在確認のみで契約一致を見ない)、続く `ListThemesByAccountID` はそのアカウントIDだけで絞り込むため、
**他契約のテーマ一覧を取得できる経路がコード上は存在する** (確信度は §推測 参照。実行時の再現は未実施)。
`usecase/theme/list_themes_test.go` にもこのケース (指定`account_id`が別契約) のテストは無いことを確認した。

**更新/削除の防御多重度も一様ではない**: `theme` の `UpdateTheme` SQL 自体に `AND account_id = $3` があり
(`db/queries/theme.sql:30`)、UseCase の read-then-compare (`usecase/theme/update_theme.go:44`) と二重防御。
一方 `DeleteThemeByID` SQL には所有者条件が無く (`db/queries/theme.sql:32-33`、`DELETE FROM themes WHERE id = $1`)、
UseCase の read-then-compare (`usecase/theme/delete_theme.go:32`) のみに依存する。
`asset` の `UpdateAsset`/`DeleteAsset` SQL にも所有者条件は無いが (`db/queries/asset.sql:4-8`)、
UseCase 側は `GetAssetByID(ctx, ContractID, AssetID)` で**契約スコープの JOIN 済み取得** (`db/queries/asset.sql:14`)
をまず行い、その上で `asset.AccountID != input.AccountID` を比較する二段構え
(`usecase/asset/update_asset.go:34-41`, `usecase/asset/delete_asset.go:32-39`)。
`GetThemeByID` (`db/queries/theme.sql:1-2`, `SELECT * FROM themes WHERE id = $1`) には契約スコープの JOIN が無く、
`usecase/theme/get_theme_by_id.go:30-44` も `theme.AccountID` と `input.AccountID` を比較しない
(所有者チェックが3層すべてで欠落。既存資料 `docs/design/auth.md` §5-1 と一致する事実として再確認できた)。

### 6. 401 / 403 / 404 の分岐実例

**例1 (401): 認証ミドルウェアの全失敗経路**。`auth/middleware.go:23-85` (`AuthRequiredMiddleware`) は、
ヘッダ欠如 (`:26-30`)・JWTパース失敗 (`:32-38`)・MFA未検証 (`:40-47`)・ロール不一致 (`:79-83`)・
UUIDパース失敗 (`:52-58`)・アカウント不在 (`:59-69`)・ロック中 (`:70-74`) の**すべてで** `c.Status(http.StatusUnauthorized); c.Abort()` を直接呼ぶ (専用ヘルパー関数は無い)。
`CheckSuperAdminRole` (`:153-163`) も、認証済み管理者の権限不足を **401** で返す (`:156-159`)。
これは「認証済みだが権限不足」であり本来403が妥当なケースに401を使っている実例。

**例2 (403): ロール不足の明示チェック**。`controller/sharing_settings.go:37-39`、
`controller/company.go:531-532`、`controller/event_logs.go:47-48` はいずれも同じパターンで、
`if !authAccount.AuthRoleID.IsAdmin() { forbidden(c, ...); return }` を持つ。`forbidden` ヘルパー
(`controller/controller.go:58-62`) が `http.StatusForbidden` を設定する。

**例3 (404): `CodedError` の型判定によるマッピング**。`controller/business_plan_detailed.go:359-366` は
`err.(*constants.CodedError)` の型アサーションでコードを見て、`FailedToGetBusinessPlanDetailed` /
`IdeaNotFound` / `BusinessPlanNotFound` は `notFound(c)` (`:362`) へ、`SharingSettingDisabled` は
`forbidden(c, err)` (`:366`) へ分岐する。同様の集約ヘルパー `handleIdeaBoardError`
(`controller/idea_board.go:554-572`) は `IdeaBoardNotFound`/`IdeaBoardPhaseNotFound`/`IdeaNotFound` を
`notFound(c)` (`:559,562,571`) へ、`IdeaBoardForbidden` を `forbidden(c, err)` (`:565`) へ変換する。

**追加の事実 (層のばらつき、404/403判定が機能しない実例)**: `controller/theme.go` の
`GetThemeByID`/`UpdateTheme`/`DeleteTheme` (`:113`,`:189`,`:221`) は UseCase が返すエラーの型を一切判定せず、
常に `internalServerError` (500) にする。ところが UseCase 側 (`usecase/theme/`) は
`apperror.ResourceNotFound("theme")` (404相当) や `apperror.NotPermitted()` (403相当) という**意味のある型**を
返している (`usecase/theme/get_theme_by_id.go:36`、`delete_theme.go:30,33`、`update_theme.go:42,45`)。
これらは `controller/apperror` パッケージの `*apperror.Error` 型 (`controller/apperror/error.go:5-16`) であり、
`asset.go`/`idea_board.go`/`business_plan_detailed.go` が判定している `*constants.CodedError` 型
(`constants/errors.go:29-33`) とは**別の独立したエラー型システム**である。
つまり v2 には「エラーコード付きエラー」の実装が2系統並存し、theme 系統は Controller 側で判定されないため、
**本来 404/403 になるべきケースが一律 500 として現れる**。

### 7. v3 が使う可能性のある既存機構の有無

| 機構 | テーブル | 稼働状況 | 根拠 |
|---|---|---|---|
| MFA | `account_mfa_configs` | **稼働中** | クエリ (`db/queries/account_mfa_config.sql`) に加え、`usecase/mfa/verify_totp.go`、`controller/mfa.go` (`CreateTotp`/`VerifyTotp`/`ResetTotp`、`router.go:229-233`)、`usecase/account/sign_in.go:101` (`GetAccountMfaConfigByPk`) から読み書きされる |
| 招待 (signup_links) | `signup_links` | **稼働中** | `db/queries/signup_link.sql` (Get/Create/Delete) に加え、`usecase/account/create_signup_link.go`、`get_signup_link.go`、`sign_up.go:42,50,87` (取得・期限チェック・削除)、`usecase/company/create_company_for_admin.go:134` (管理者による会社作成時の発行) から使われる。`signup_links` テーブルは `accounts`/`contracts` への FK を持たず、`email` 文字列のみで完結する設計 (`schema.sql:342-348`) |
| パスワードリセット | `reset_password_requests` | **稼働中と判断 (確信度: 中)** | `db/queries/reset_password_request.sql` (Get/Create/Delete) と、`usecase/account/request_reset_password.go`・`reset_password.go` の存在、`controller/account.go` からの呼び出しを grep で確認した。ただし UseCase 内部の全ロジックは読んでいない |
| 共有設定 | `sharing_settings` | **稼働中** | `db/queries/sharing_settings.sql` (`ON CONFLICT` upsert)、`usecase/sharing_settings/create_or_update_sharing_settings.go`、`controller/sharing_settings.go:35-59` に加え、**参照側**として `usecase/theme/list_themes.go:44`、`usecase/asset/list_assets.go:72`、`usecase/business_plan/list_business_plans.go:63`、`usecase/business_plan/get_business_plan.go:51` が `GetSharingSettingsByCategory` を呼び、一覧・詳細取得の可視性を左右している |
| 活動ログ | `activity_logs` | **稼働中 (event_logs とは別系統)** | `db/queries/activity_log.sql` (`CreateActivityLog`)、`repository/activity_log.go` に加え、`usecase/account/sign_in.go`、`usecase/mfa/verify_totp.go`、`usecase/idea_board/*`、`usecase/business_plan/detailed/*`、`usecase/admin_account/reset_account_mfa_by_admin.go` など多数から書き込まれる。サインイン成功/失敗、MFA検証成功/失敗などの**セキュリティイベント**中心。`account_id` は NULL 許容・FK無し (未知メールでの失敗ログイン等も記録するため) |
| イベントログ | `event_logs` | **稼働中** | `auth/middleware.go:78,166-179` (`createEventLogIfNeeded`) が認証成功時にパス/メソッドから種別を判定 (`auth/event_mapper.go:12-95`, `GetEventTypeFromRequest`) して記録。`controller/event_logs.go` の `GetAnalytics` (管理者専用、`:41-48`) が集計 UI 用途で参照する。`account_id` は NOT NULL・FKあり (`schema.sql:586-597`) |

`activity_logs` と `event_logs` は用途が異なる (前者はセキュリティ監査寄り、後者は UI 操作の利用状況分析寄り) 別系統
であり、v3 でどちらの設計思想を踏襲するかは設計判断 (本書では扱わない)。

---

## 経路・バリエーション

| 経路 | 実装 | 挙動の差 |
|---|---|---|
| `X-Token` (ユーザー) vs `X-Admin-Token` (管理者) | `auth/middleware.go:23-85` vs `:88-131` | 別署名鍵(`JWT_KEY`/`ADMIN_JWT_KEY`)。管理者トークンはロール情報を持たずクレームが `uid`/`exp` のみ (`client.go:91-96`)。**管理者側には `last_locked_at` 相当のロック判定が無い** |
| `AuthRoleUser` vs `AuthRoleConsultant` | `middleware.go:49-84` の `switch` | `AuthRoleUser` は稼働 (98箇所)。`AuthRoleConsultant` は `case` が無くアカウント確認・ロック確認がスキップされ、後続の `GetAuthenticatedAccount` 呼び出しで panic しうる。router からの参照は0件で現状は到達しない |
| 一覧の`account_id`指定時クロステナントガード: asset/business_plan (あり) vs theme (無し) | `list_assets.go:61-68`、`list_business_plans.go:56` vs `list_themes.go:55-66` | 同じ「`account_id`クエリパラメータで他人のデータを見る」機能なのに、theme だけ契約一致チェックが欠落 |
| エラー→HTTPステータス変換: `constants.CodedError` 型判定あり (asset/idea_board/business_plan_detailed) vs `apperror.Error` 型判定なし (theme) | `asset.go:110-124`、`idea_board.go:554-572`、`business_plan_detailed.go:356-366` vs `theme.go:113,189,221` | theme 系は UseCase が返す 404/403 相当のエラーが常に 500 に潰れる |
| 管理者ルートの適用順序: `adminAccountRoute` 内 `.Use()` 前後 | `router.go:198-201` | `:199-200` の2ルートは `.Use()` (`:201`) より前に登録されており認証が掛からない。同一 Group 内でも登録順序でミドルウェア適用有無が変わる |
| 単一取得の防御多層度: theme (皆無) vs asset (契約JOIN+account比較) | `theme.sql:1-2`+`get_theme_by_id.go:30-44` vs `asset.sql:14`+`update_asset.go:34-41` | asset は Repository が契約スコープJOINを行った上でUseCaseがaccount比較する二段防御。theme は3層とも所有者条件が無い |

---

## 推測 (確信度つき)

- **theme一覧のクロステナントIDOR疑い**: 確信度 中〜高。根拠: `usecase/theme/list_themes.go:55-66` を
  `usecase/asset/list_assets.go:61-68` および `usecase/business_plan/list_business_plans.go:56` と比較すると、
  後二者にある契約一致チェックが theme にだけ無い。ロジック上は到達可能に見えるが、実際に HTTP リクエストを
  送っての再現・DB を使った統合テストは実施していない (静的解析のみ)。
- **`reset_password_requests` が完全に稼働しているか**: 確信度 中。ファイル存在と呼び出し元の grep 一致は
  確認したが、`usecase/account/request_reset_password.go` / `reset_password.go` の内部ロジック全体は読んでいない。
- **`asset_documents` と `assets` の対応関係**: 確信度 中。`asset_documents.id` が `assets.id` と対応する設計と
  推測されるが、外部キーによる保証はスキーマ上に無い (§3参照)。
- **`dgrijalva/jwt-go` の保守状況 (アーカイブ済みかどうか)**: 未確認。`docs/design/auth.md` はこれを事実として
  記載しているが、本調査はリポジトリ内 (読み取り専用) の調査であり外部の GitHub 状態は確認していない。

---

## 未調査・対象外

- `hassan-v2-frontend` 側のトークン保管・更新方法 (対象リポジトリ外)
- MFA の TOTP 検証ロジック内部 (`util.VerifyTOTPCode` の実装詳細)
- `usecase/account/request_reset_password.go` / `reset_password.go` の完全な内部ロジック
- ecspresso/Terraform 等インフラ側の鍵配布・ローテーション
- `.worktrees/` `vendor/` 配下 (調査対象外として除外)
- 実行時の再現検証: 本書の全ての「経路」判断はソースコードの静的な読み込みによるものであり、
  実際に HTTP リクエストを送信して確認した挙動ではない (特に theme のクロステナント疑いは要注意)
- 管理者 (`admin_accounts`) / コンサルタント (`consultant_accounts`) 系のより深い業務ロジック
  (本調査は一般ユーザーのテナント境界が主眼のため、認証経路の把握に必要な最小限のみ確認)
- `dgrijalva/jwt-go` の外部の保守状況 (GitHub アーカイブ有無等)

---

## 抜き取り検証 (オーケストレーター実施。2026-07-29)

`orchestrating-delegation` skill ③ に従い、設計に影響する load-bearing な主張を一次ソースで照合した。

| 照合項目 | 照合方法 | 結果 |
|---|---|---|
| theme 一覧にクロステナントガードが無い | `hassan-v2-backend/usecase/theme/list_themes.go` の一覧取得経路を通読 | **一致 (条件付き)** — 下記参照 |

### 確認内容: theme 一覧の所有者パラメータに契約一致チェックが無い

`hassan-v2-backend/usecase/theme/list_themes.go` の一覧取得は次の流れ:

1. 共有設定 (`GetSharingSettingsByCategory(ContractID, カテゴリ=idea)`) を引く
2. **共有 OFF (`isShared == false`) なら `accountIDForList` を `RequestUserID` に強制上書き** (安全側)
3. **共有 ON なら入力の `AccountID` をそのまま採用**
4. `GetAccountByID(*accountIDForList)` で存在確認 → `ListThemesByAccountID(*accountIDForList, …)`

**4 の存在確認では、取得した account が `input.ContractID` に属するかを検証していない**。
したがって「共有 ON の契約」において、**他契約の account_id を指定された場合に、
その account のテーマ一覧が返り得る**構造になっている (共有 OFF の場合は 2 で塞がれる)。

- **確認したこと**: 読み取り経路に契約一致チェックのコードが存在しないこと
- **確認していないこと**: `AccountID` が外部入力から到達可能か (Controller 側のバインド経路)、
  実行時に再現するか。**実機での再現確認は行っていない** — 「疑いあり」として扱うべき段階

### v3 設計への含意 (A-3 / A-4)

**所有者パラメータを受け取る一覧 API では、「その所有者が呼び出し元と同じ契約に属すること」の検証を
必須にする**。存在確認 (`GetAccountByID` が nil でない) は所有権の検証にならない。
この確認内容を `.claude/rules/08-production-gates.md` の A-4 に追記した。

> なお本書のもう 1 つの発見「エラー型システムの二重化」(`constants.CodedError` 系統と
> `apperror.Error` を 500 に潰す theme 系統の並存) は**未照合**。v3 は `CodedError` 単一系統を
> 採る方針 (ルート `CLAUDE.md`) なので設計判断は変わらないが、移植時に theme 系統の
> エラー表現をそのまま持ち込まないこと。
