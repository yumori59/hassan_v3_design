# レビュー: 認証・アカウント基盤 API (`docs/design/API/auth-accounts.md`) — 1 巡目

- **レビュー日**: 2026-07-31
- **レビュアー**: `design-reviewer` (別セッション。起草者ではない)
- **基準**: 本番基準 (`.claude/rules/08-production-gates.md` 全 ID / `.claude/rules/feedback_review_patterns.md` DR-1〜DR-9 + BE/FE)。
  **「PoC では対象外だった」を省略の理由として認めない**
- **位置づけ**: [review-round3.md](review-round3.md) §3 重大 3 が「本レビュー開始後に新規追加され未レビュー」と判定した文書の
  独立した 1 巡目レビュー。本書は 675 行 / 37 エンドポイント / 是正要求 14 行を持つ

## 0. レビュー対象 (リポジトリ相対パス)

### 主対象 (全文レビュー)

- `docs/design/API/auth-accounts.md` (675 行。**本レビューの唯一の判定対象**)

### 整合を確認した相手 (該当節のみ)

- `docs/design/auth.md` (§5 / §6.2 / §6.3 / §6.4 / §6.6 / §6.7 / §6.9 / §6.10 / §6.11 / §10.2)
- `docs/design/API/README.md` (§0 / §1.3 / §2.2 / §2.5 / §3 / §4)
- `docs/design/API/settings.md` (§2 / §4 / §5 / §6 / §7)
- `docs/design/data-model.md` (§3.3 / §3.4.2 / §3.4.3 / §4.1.2 / §4.2 / §4.10 / §6.5 / §7.2 / §8.3)
- `docs/design/observability.md` (§4.5)
- `docs/design/frontend.md` (§5.2.2 / §5.2.3 / §9 / §11.1 / §11.2 / §11.3.1 / §16)
- `docs/design/testing.md` (§7.3)
- `aidlc-docs/inception/productionization/requirements.md` (AC-1.1〜AC-1.6)
- `aidlc-docs/inception/productionization/plan.md` (Task-3i / AC-1.5 / AC-1.6 の状態列)

### 一次ソース (読み取り専用。編集していない)

- `hassan-v2-backend/router/router.go` / `db/schema.sql` / `db/queries/account.sql` /
  `usecase/account/*` / `usecase/mfa/*` / `controller/mfa.go` / `controller/controller.go` /
  `controller/dto/account.go` / `aws/s3.go`

### 参考にした既存レビュー

- `aidlc-docs/reviews/productionization/review-auth-hardening.md` (auth.md 4 巡分)
- `aidlc-docs/reviews/productionization/review-round3.md` (3 巡目)
- `aidlc-docs/reviews/productionization/verification-auth-accounts.md` (正式レビューではない照合記録)

### スコープ外 (別レビュアー / 別タスクの担当)

- `docs/design/auth.md` §6.2 (MFA 新規実装) / §6.4 (許可リスト 7 種そのもの) / §6.7 (4 系統) の**妥当性**。
  本レビューは「auth-accounts.md が auth.md と矛盾していないか」のみを見た
- 既知の未反映事項 (`docs/design/` の「未着手」stale 12 箇所 / `plan.md:35`〜`:39` の状態列 /
  review-round3 の中 1〜4・軽微 1〜4)。**新規発見として重大に挙げていない**

---

## 1. 実行した検証

### 1.1 `make check` (2026-07-31。生出力の末尾)

```
[WARN ] ./docs/design/data-model.md:954 未回答の [Answer]:
[WARN ] ./docs/design/frontend.md:1199 未回答の [Answer]:
[WARN ] ./docs/design/infrastructure.md:519 未回答の [Answer]:
[WARN ] ./docs/design/infrastructure.md:535 未回答の [Answer]:
[WARN ] ./docs/design/llm-migration.md:764 未回答の [Answer]:
[WARN ] ./docs/design/operations.md:695 未回答の [Answer]:
[doc-lint] 対象 89 ファイル / エラー 0 件 / 警告 31 件
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 47/47 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
[workflow-shell] 検査 52 ブロック / エラー 0 件
[table-counts] 実測: 機能テーブル 40 (個人 32 / 契約 8) / 分類 ①29 ②2 ③1
[table-counts] 照合 22 件 / エラー 0 件
```

**判定**: **エラー 0 件で通過**。警告 31 件のうち **`auth-accounts.md` 由来は 0 件**
(残りはルール文書・過去 review・`design_memo.md` の「TODO」語と、他 6 文書の未回答 `[Answer]`)。
**AC 未カバー 0 / リンク切れ 0 / 件数転記の不整合 0**。

**再実行時の差分についての注記**: 本レビュー執筆中に**別セッションが並行して
`aidlc-docs/reviews/productionization/review-auth-round5.md` を追加し `docs/design/frontend.md` を編集した**ため、
レビュー末の再実行では `対象 91 ファイル / エラー 0 件 / 警告 36 件` になった
(**エラー 0・AC 47/47・件数照合 22 件 0 エラーは変わらない**)。
警告の増分は追加された review 文書と本レビュー文書自身の「TODO」語への反応であり、
`auth-accounts.md` 由来は引き続き 0 件である。

**ただし `make check` は本レビューの重大 1〜6 を 1 件も検出していない** — 参照先の**内容**が主張と
合っているか、`data-model.md` に無いテーブルを API が読み書きしていないかは検査対象外
(`.claude/rules/05-harness.md` の「見ない」列)。

### 1.2 エンドポイント実数の機械集計 (独立に数え直した)

```
awk 'BEGIN{FS="|"} /^\| *(GET|POST|PUT|DELETE|PATCH) *\|/ {print}' docs/design/API/auth-accounts.md | wc -l
→ 37
```

| 節 | 宣言 | 実測 | 判定 |
|---|---|---|---|
| §2.1 公開 | 6 | 6 | ✓ |
| §2.2 ユーザー (MFA 未検証で到達可) | 2 | 2 | ✓ |
| §2.3.1 自分のアカウント | 7 | 7 | ✓ |
| §2.3.2 メンバー管理 | 10 | 10 | ✓ |
| §2.3.3 契約・会社情報 | 4 | 4 | ✓ |
| §2.3 小計 | 21 | 21 | ✓ |
| §2.4.1 管理者 (MFA 未検証で到達可) | 2 | 2 | ✓ |
| §2.4.2 管理者 (MFA 検証済み必須) | 6 | 6 | ✓ |
| §2.4 小計 | 8 | 8 | ✓ |
| **§2 合計** | **37** | **37** | **✓** |

`API/README.md:319-320` の「**合計 110** = 6 ドメイン **73** + auth-accounts **37**」と、
`同:336-337` の総覧表 (37 / LLM 0 / SSE 0 / 403 10) は**実測と一致**。
403 の 10 本 = 契約内管理者限定 9 (§2.3.2 の 8 + §2.3.3 の 1) + SuperAdmin 限定 1 (§2.4.2) も**実測一致**
(§2.3 冒頭の「403 の 9 本」/ §2.3.2 の「8 本」/ §2.3.3 の「1 本」/ §4 の A-2 行が相互に整合)。

### 1.3 `settings.md` §5 (移植チェックリスト) との対応の検証

`settings.md:170-187` の表は **18 行**であり、`auth-accounts.md` §2.6 の 18 行と**行の順序も内容も 1:1 対応**。
**行の取り残しは 0**。ただし row 11 の出典が settings.md 側で誤っており本書が是正要求に含めていない (中 10)、
`settings.md:30` / `:158` の「入出力仕様の起草は未着手」が是正要求に入っていない (中 9)。

### 1.4 参照テーブル・列の実在確認 (data-model.md 全数)

| 本書が読み書きすると書いているもの | `data-model.md` の定義 | 判定 |
|---|---|---|
| `accounts` (`crypted_password` / `is_completed` / `auth_role_id` / `last_locked_at` / `failed_sign_in_attempts` / `icon_url` 等) | §4.2「v2 の構造をそのまま」 | ✓ |
| `contracts` (`num_of_members` 等) | §4.2 | ✓ |
| `companies` (`mfa_type`) | §4.2 (+ enum → text + CHECK) | ✓ |
| `auth_roles` | §4.2 | ✓ |
| `account_mfa_configs` | §4.2 / §4.1.2 (b) | ✓ |
| `reset_password_requests` | §4.2 / §4.1.2 (b) | ✓ (**ただし列名は `hash`。`token` は無い** → 重大 5) |
| `signup_links` (+ `contract_id`) | §4.2 / §4.1.2 (b) | ✓ (**`token` 列は無い** → 重大 5) |
| `admin_accounts` / `admin_auth_roles` | §4.2 / §4.1.2 (a) | ✓ |
| `register_admin_password_requests` | §4.2 / §4.1.2 (a) | ✓ (**読み手・書き手が無い** → 本書が R-AA-5 で起票済み) |
| `auth_rate_limit_counters` | §4.2 | ✓ |
| `audit_logs` | §4.10 | ✓ (**`signin_failed` を書けない** → 重大 2) |
| **`account_deletions`** | **存在しない** | **✗** — 本書が R-AA-4 で起票済み (既知) |
| **`admin_mfa_configs`** | **存在しない** (`grep -rn "admin_mfa_configs" docs/design/data-model.md` → **0 件**) | **✗ 是正要求も無い** → **重大 1 (新規発見)** |

**同型の全数確認の結果**: `data-model.md` に定義先が無いテーブルは **2 件** (`account_deletions` /
`admin_mfa_configs`)。うち前者は起票済み、**後者は起票漏れ**。他に定義先の無いテーブルは無い。

### 1.5 出典の抜き取り照合 (12 件。うち結論を左右するもの 6 件)

| # | 本書の主張と出典 | 照合コマンド / 実測 | 判定 |
|---|---|---|---|
| 1 ★ | **V2-D1**: `sign_up.go:40-79` に `signupLink.Email` の参照が無く、クライアントの `email` で `accounts` を引く | `sed -n '39,95p' usecase/account/sign_up.go` → `GetSignupLinkByID` → 期限確認 → `GetAccountByEmail(ctx, input.Email)`。**`signupLink.Email` は 1 度も参照されない**。`account.IsCompleted` で `AccountAlreadySignup` のみ拒否 | **一致** (欠陥は実在) |
| 2 ★ | **V2-D3**: `RequestResetPasswordRes.Hash` が `dto/account.go:139-141` に残る | `sed -n '139,141p' controller/dto/account.go` → `type RequestResetPasswordRes struct { Hash string ... }` | **完全一致** |
| 3 ★ | **AA-D-10 の根拠**: `failed_sign_in_attempts` はパスワード失敗でしか増えない (`account.sql:56-64`) | 実測: `-- name: UpdateFailedSignInAttempts` (56) 〜 `WHERE email = $2;` (64)。MFA 経路からの加算は存在しない | **一致** |
| 4 ★ | **V2-D4 の根拠**: email 指定の `:66-71` は使わず ID 指定の `:73-78` を使う | 実測: `DeleteLastLockedAt` = `WHERE email = $1` (66-71) / `UnlockAccountByID` = `WHERE id = $1` (73-78) | **一致** |
| 5 ★ | **AA-D-12 の根拠**: `CountAdminsByContractID` はロック状態を見ない (`account.sql:80-81`) | 実測: `SELECT count(*) FROM accounts WHERE contract_id = $1 AND auth_role_id = 1;` | **完全一致** |
| 6 ★ | **R-AA-3③**: `UpdateEmailUseCase` はメール送信を行わない (`update_email.go:35-66`) | 実測: 依存は `ar` / `auth` のみ。`EmailService` を持たず、`GetAccountByID` → `CheckBcrypt` → `GetAccountByEmail` → `UpdateEmail` で完結 | **一致** (settings.md の記述が誤りである点も正しい) |
| 7 | **V2-F3**: `signup_links` は 5 列 (`schema.sql:342-348`) | 実測: 342 `CREATE TABLE signup_links (` 〜 348 `);`。`id` / `email` / `expired_at` / `created_at` / `updated_at` | **一致** |
| 8 | **V2-F17**: 認証系 6 種が `activity_log_type` に既存 (`schema.sql:467-489`) | 実測: enum 467-480 に `signin_success` / `signin_failed` / `mfa_verify_success` / `mfa_verify_failed` / `mfa_reset_by_admin` / `mfa_reset_by_aillio_admin` の 6 種。`activity_logs` は 482-489 (`account_id uuid` = NULL 可 / `account_email varchar(255)`) | **一致** |
| 9 | **V2-F9 / R-AA-3②**: `POST /admin/companies/accounts/mfa/reset` = `router.go:217`、検索は `:216` | 実測: 216 `adminCompanyRoute.GET("/accounts", ...)` / 217 `adminCompanyRoute.POST("/accounts/mfa/reset", ...)` | **完全一致** |
| 10 | **§2.1**: `POST /admin/signin` = `router.go:195` | 実測: 195 `adminRoute.POST("/signin", ...)` (`:194` は `r.Group("/admin")`) | **完全一致** (settings.md §5 の `:194` は誤り → 中 10) |
| 11 | **AA-D-16 却下 (a)**: `ACL: ObjectCannedACLPublicRead` = `aws/s3.go:46`、恒久 URL = `:58` | 実測: 46 `ACL: types.ObjectCannedACLPublicRead,` / 58 `return fmt.Sprintf("https://%s.s3.amazonaws.com/%s", ...)` | **完全一致** |
| 12 | **AA-Q7**: v2 のパスワード要件は `min=8,max=255` のみ (`dto/account.go:106`, `:130-132`) | 実測: 106 = `SignUpReq.Password` / 130-132 = `UpdatePasswordReq` の 3 フィールド、いずれも `min=8,max=255` | **完全一致** |

**★ = 結論を左右する事実** (6 件)。

**照合の総括**: **12 件中 12 件が一致**し、**誤った事実は 1 件も見つからなかった** (全数照合への切替は不要)。
`±1 行`のずれが 2 件のみ (軽微 2)。**DR-1 (出典なしの断定) はほぼ無い** — v2 の主張はすべて
`パス:行` を伴う。これは本リポジトリのこれまでの成果物の中でも citation 精度が高い。

**ただし出典の正確さは重大 1〜6 を防いでいない** — 重大の全件は「**v2 の事実は正しいが、
v3 側の受け皿 (テーブル・コード値域・クエリ名) が定義されていない**」型 (BE-10) である。

---

## 2. 重大 (Must Fix) — 6 件

すべて **BE-10 (読む側と書く側を対で設計する)** か **DR-2 (本番観点の無言の省略)** の型である。
**設計の誤りではなく「受け皿の欠落」**なので、実装リポでは「仕様どおり書いたのに動かない / CI が落ちる /
穴が開いたまま通る」として現れる。

### 重大 1. `admin_mfa_configs` に定義先が無く、是正要求も出ていない (BE-10 / DR-2 / A-3)

- **箇所**: `docs/design/API/auth-accounts.md:183` (§2.4.1 の移植元列「**`admin_mfa_configs` は新設**」)、
  `同:444` (§3.5 の許可リスト行「`admin_accounts` / `admin_mfa_configs` / `admin_auth_roles` の全クエリ」)、
  `同:79` (P-5)
- **事実**: `grep -rn "admin_mfa_configs" docs/design/data-model.md` → **0 件**。
  `data-model.md:413-415` の §4.2 対象 10 テーブルにも、`同:373-379` の §4.1.2 (a) 6 件にも無い。
  一方 `docs/design/auth.md:530` は「**`admin_mfa_configs` 相当を新設する**」と決定済みで、
  `同:1256` (§10.2 R-3) は Task-3i の必須事項③に「**`admin_mfa_configs` のスキーマ**」を明示している
- **なぜ本番で問題になるか**:
  1. **社内管理者の MFA 必須 (P-5 / auth.md §6.2) が実装先を持たない**。`admin_mfa_configs` が無いと
     §2.4.1 の 2 本は「シークレットの保存先が無い」ため実装不能。`account_mfa_configs.account_id` は
     `accounts` への FK なので流用できない (auth.md が出典付きで指摘 — `hassan-v2-backend/db/schema.sql:68-77`)
  2. 本書は **`account_deletions` を R-AA-4、`register_admin_password_requests` を R-AA-5 として
     同じ型で起票している**。**同型の 3 件目だけが落ちている** — 是正要求の網が不完全であることを示す
  3. **件数の連動が手作業になる**: `admin_mfa_configs` は §4.1.2 (a) 側 (所有者列を持たない・契約に属さない) に
     入るため、`data-model.md` の「**機能テーブル以外の 11 テーブル**」(§4.1.2 見出し) が 12 へ、
     (a) 表が 6 → 7 件へ、**§3.3 の検査①の除外リスト「8 件」が 9 件**へ動く。この「8 件」は
     `data-model.md:193` / `:391-396` (注記) / `:1061` (§7.2 検査 1) / `:1136` (R-DM-4) の **4 箇所**にあり、
     **`make check-table-counts` の照合対象に入っていない** (検算は機能テーブル 40 / 個人 32 / 契約 8 / 分類①②③のみ。
     実行結果で確認済み)。**ずれると「設計どおり実装した CI 検査が必ず落ちる」形で実装リポに出る** (rule 05 §「件数の転記を機械で見る理由」)
- **修正案**: §5 に **R-AA-14** を新設する (ID は中 3 の改番と揃える):
  > **R-AA-14** | `docs/design/data-model.md` §4.2 / §4.1.2 (a) / §3.3 / §7.2 |
  > **`admin_mfa_configs` を追加する**。`auth.md` §6.2 が新設を決定し `同` §10.2 R-3 の必須事項③が
  > 本書に「スキーマ」を要求しているが、`data-model.md` に定義が無く §2.4.1 の 2 本の実装先が無い (BE-10)。
  > 列は v2 の `account_mfa_configs` (`hassan-v2-backend/db/schema.sql:68-77`) を雛形に
  > `admin_account_id` (PK 一部・`admin_accounts` への FK・CASCADE) / `mfa_type` (`totp` 固定) /
  > `otp_secret` / `is_verified` / タイムスタンプ。**併せて連動する件数を全件更新する**:
  > §4.1.2 見出しの「11 テーブル」→ 12、(a) 表 6 件 → 7 件、**§3.3 検査①の除外リスト「8 件」→ 9 件
  > (`data-model.md:193` / `:391`〜`:396` / `:1061` / `:1136` の 4 箇所)**。
  > **この 4 箇所は `make check-table-counts` の検算対象外**なので、同時に検算対象へ加えるか
  > (`scripts/check-table-counts.sh` に除外リスト件数の照合を追加) 定義元へのリンクに置き換える (DR-9)
- **併せて**: §2.4.1 / §3.5 の該当セルから R-AA-14 へリンクを張る (「新設」の一言では読者が定義先を探せない)

### 重大 2. `signin_failed` を `audit_logs` に書けない — O-6 が v2 より後退する (BE-10 / O-6 / O-4)

- **箇所**: `docs/design/API/auth-accounts.md:483` (§3.7 の 1 行目
  「`POST /accounts/signin` | 成功 / 失敗 (**失敗はメールアドレスを平文で保存しない**。ハッシュのみ)」)、
  `同:543` (R-AA-7)、`同:519` (§4 の O-6 行)
- **事実**:
  - `docs/design/data-model.md:661` (§4.10) の `audit_logs` の列は
    `actor_type` (`account`|`admin_account`) / `actor_id uuid` / `action text` / `target_type` /
    `target_id` / `request_id` / `detail jsonb` / `occurred_at`。**`actor_id` / `contract_id` の NULL 可の記述が無い**
  - `同:681` は「**`audit_logs.contract_id` は「対象リソースの契約」を入れる**。社内管理者による全契約横断の操作
    (ロック解除) でも対象アカウントの契約が入るため **NOT NULL を維持できる**」と**明示的に NOT NULL を宣言**
  - **未登録メールアドレスへのサインイン失敗では actor も contract も存在しない**。`accounts` に行が無いため
    `actor_id` も `contract_id` も埋められず、**ハッシュ化した email を入れる列も無い** (`detail jsonb` に
    入れる規約は書かれていない)
  - v2 はこれを **`activity_logs.account_id` を NULL 可 + `account_email varchar(255)`** で解いていた
    (本書 V2-F17 が自ら出典を挙げている — 実測 `hassan-v2-backend/db/schema.sql:482-489`)
- **なぜ本番で問題になるか**: `auth.md` §6.11-3 が**名指しで防ぐと宣言した攻撃**が
  「多数アカウントに 1 回ずつ試行するパスワードスプレー」であり、**その検知は「存在しない / 存在する
  メールアドレスへの失敗サインインの分布」しか手がかりが無い**。書けないと
  ①O-6 が v2 でできていたこと (`signin_failed`) を失う ②O-7 のアラート
  (`auth.md` §10.2 R-6 の「社内管理者のサインイン失敗」も同型) の入力が消える。
  **`docs/design/observability.md` §4.5 の記録対象にも認証失敗が無い**ため、
  どの文書にも受け皿が無い状態
- **R-AA-7 では埋まらない**: 現在の R-AA-7 は「6 事象を追加する」「平文で保存しない」の 2 点のみで、
  **「actor / contract が確定しない事象を書ける形にする」要求が無い**。
  6 事象を `action` に追加しても `NOT NULL` に当たって書けないため、**要求どおり実装しても機能が死ぬ**
- **修正案**: R-AA-7 に④を追加し、**`data-model.md` §4.10 宛ての別 ID (R-AA-15)** を起票する。
  選択肢を明示して起草側に判断させる (どちらも代償があるため「適切に」で渡さない):
  - **(a)** `audit_logs.actor_id` / `contract_id` を **NULL 可**にし、
    `detail jsonb` に `email_hash` を入れる規約を §4.5 に書く。
    **代償**: `data-model.md:681` の「NOT NULL を維持できる」決定の反転 +
    `(contract_id, occurred_at DESC)` インデックスの選択性低下
  - **(b)** **認証失敗は `audit_logs` に書かず**、構造化ログ + メトリクス (`observability.md` §4.1 / §4.3) で
    観測する。**代償**: v2 の `signin_failed` / `mfa_verify_failed` が監査記録から落ちることを
    §4 の O-6 行に明記する必要がある (「v2 でできていたことを満たす」= `auth.md` §9.3 Q-A2 に対する
    明示の逸脱として却下理由を書く)
  - **(c)** 認証イベント専用の append-only テーブルを新設する。**代償**: 監査記録が 2 本になる
    (`data-model.md` DM-15 が却下した v2 の 2 本構成に戻る)
  - **本レビューの推奨は (a)** — `actor_type = 'unknown'` を追加せず、
    「**actor が特定できない認証イベントは `actor_id IS NULL` かつ `contract_id IS NULL`**」を
    `CHECK` で表明する形にすれば、`llm_call_records` の `CHECK` 制約 (`data-model.md:678` 付近) と
    同じ「NULL を許す条件をスキーマで表明する」方針に揃う

### 重大 3. 401 の `CodedError` コード値域がどこにも定義されていない (BE-10 / DR-5 / A-5)

- **箇所**: `docs/design/API/auth-accounts.md:306` (AA-D-9)、`同:497` (§3.7 の O-4)、
  `同:512` (§4 の A-5 行)、`同:538` (R-AA-2①)
- **事実**: `docs/design/frontend.md:664` (§9 の「401 (②提示した資格情報の不一致)」行) は
  > 「**①②の判別は BE が返す `CodedError.code` で行う** — **値域と判定規則の SSOT は
  > `docs/design/API/auth-accounts.md` §3.1**」

  と書き、`同:387` (§5.2.3) も「判別は BE の `CodedError.code` で行う
  (`docs/design/API/auth-accounts.md` §3.1 が値域の SSOT)」と**2 箇所で本書を値域の SSOT に指名**している。
  一方 **本書 §3.1 の AA-D-9 はコードを 1 つも列挙していない** — 「401 + `CodedError` 本文」
  「**ロックは専用コードで区別する**」と書くだけ。§3.7 も「資格情報不正・ロック・MFA 不一致を
  **別のコードで区別**する」で止まり、**コード名が出てこない**
- **なぜ本番で問題になるか**: frontend.md が **2026-07-31 のレビュー M-1 で入れた対策**
  (「**この分岐が無いと TOTP の打ち間違い 1 回で強制サインアウトになる**。レート制限と重なると
  正規ユーザーが自分をロックアウトする」) が、**値域が無いために実装できない**。
  FE の実装者は「401 を全部 ①失効扱い」に倒すしかなく、**対策が無効化される**。
  かつ **`AA-D-10` のレート制限 (MFA 検証も対象) と重なると、正規ユーザーが自分を締め出す** —
  この複合が起きたときの回復は「契約内管理者に解除を依頼」しかない (AA-Q3=b で本人回復を落としたため)
- **修正案**: §3.1 の AA-D-9 の直後に**コード表を置く** (本書が SSOT に指名されているため、
  他文書へ委譲しない)。最低限次の列を持つ:

  | `CodedError.code` | HTTP | 対象エンドポイント | FE の分類 (`frontend.md` §9) | 本文の文言方針 |
  |---|---|---|---|---|
  | `invalid_credentials` | 401 | `POST /accounts/signin` / `/admin/signin` / `PUT /accounts/me/email` / `PUT /accounts/me/password` | **②資格情報の不一致** (セッション破棄しない) | email / password のどちらが不正かを示さない (`auth.md` §6.11-1) |
  | `account_locked` | 401 | `POST /accounts/signin` | **②** (サインイン画面に留まり、管理者への依頼を案内) | ロックされている事実を伝える (`auth.md` §6.11-1 が踏襲を決定) |
  | `mfa_code_mismatch` | 401 | `POST /mfa/totp/verify` / `/admin/mfa/totp/verify` / `POST /mfa/totp/reset` | **②** | コードが違うことのみ |
  | `token_invalid` | 401 | 全認証必須ルート | **①トークンの失効** (`/api/logout` へ) | 本文なし (`auth.md` §6.6) |
  | `mfa_required` | 401 | 保護ルートへの MFA 未検証アクセス | **①** (`/mfa` へ) | 本文なし |
  | `mfa_not_registered` | 404 | `POST /mfa/totp/verify` / `reset` | — | — |

  **併せて**: ①R-AA-2① に「frontend.md §9 / §5.2.3 が本書 §3.1 を値域の SSOT に指名しているため、
  §3.1 にコード表を置くまで FE は実装着手不可」を明記する ②`README.md` §2.5 の 401 行からこの表を参照させる
  ③`§7.3` の UT 必須ケースに「**①と②の 401 が別コードで返ること**」を 9 件目として追加する
  (コードが同じだと FE の分岐が成立しないため、テストで固定しないと退行する)

### 重大 4. 許可リストの種別⑦が契約内管理者経路と同名で、V2-D4 (テナント越境) が CI を通る (A-4 / A-6 相当)

- **箇所**: `docs/design/API/auth-accounts.md:442`
  (`UnlockAccountByID` | ⑦ 全契約横断の運用操作 | 社内管理者による解除 (v2 の実例と同一))、
  `同:443` (`DeleteAccountMfaConfigByAccountID` **(社内管理者経路)** | ⑦)、
  `同:451` (「載せないもの」表の 2 行目「契約内管理者のロック / 解除 / MFA リセット / メンバー取得・更新・削除 |
  `WHERE id = $1 AND contract_id = $2` を持つ」)
- **事実 (a) — 同名クエリの両用**: §2.3.2 の `DELETE /accounts/{account_id}/lock` (契約内管理者) と
  §2.4.2 の `DELETE /admin/accounts/{account_id}/lock` (社内管理者) は**同じ行を更新する 2 本**である。
  §3.5 は前者に**クエリ名を与えていない**まま、後者用の `UnlockAccountByID` (= v2 の `WHERE id = $1`。
  実測 `hassan-v2-backend/db/queries/account.sql:73-78`) を**許可リストに載せた**。
  `docs/design/auth.md` §6.4 は自ら
  > 「**許可リストは「そのクエリを許可する」だけで呼び出し元を制約しない**」

  と明記し、呼び出し元パッケージを書かせる案を**却下している**。したがって
  **契約内管理者経路が誤って `UnlockAccountByID` を呼んでも、SQL 検査 (所有者条件の有無) も
  許可リスト検査も通る** → **V2-D4 / auth.md §5-11 (ロック解除がテナント境界を越える) がそのまま復活する**。
  本書は §2.3.2 のセルで「email 指定の `:66-71` は使わない」と v2 の**別の**穴だけを塞いでいる
- **事実 (b) — `account_mfa_configs` では「載せないもの」の主張が成立しない**:
  `docs/design/data-model.md:387` / `同:391`〜`:396` のとおり **`account_mfa_configs` は
  `account_id` のみを持ち `contract_id` を持たない**。したがって契約内管理者の
  `POST /accounts/{account_id}/mfa/reset` のクエリを
  `WHERE ... AND contract_id = $2` にすることは**構造的に不可能**であり、
  §3.5 の「載せないもの」2 行目の主張 (MFA リセットも `contract_id` 条件を持つ) は**このテーブルについて偽**。
  さらに `DeleteAccountMfaConfigByAccountID` は**名前が 1 つしかないのに「(社内管理者経路)」という
  括弧書きだけで区別されている** — 括弧書きはクエリ名に入らないため、実装リポでは 1 本のクエリになる
- **なぜ本番で問題になるか**: 契約内管理者の MFA リセットが
  `DELETE FROM account_mfa_configs WHERE account_id = $1` として実装され、`$1` は **path param 由来**。
  これは A-4 が名指しする「**存在確認は所有権の検証にならない**」の変形であり、
  `auth.md` §6.4 ②の `NewAccountIDInContract` を通す規約が**唯一の防御**になる。
  SQL 検査は「所有者条件 (`account_id`) あり」として**通す**ため、
  **コンストラクタを通し忘れた 1 箇所が他契約のメンバーの MFA を解除できる穴になり、検出手段が無い**
  (`auth.md` §5-1 / F-15 と同じ機構)
- **修正案**: §3.5 を次の 3 点で書き換える。
  1. **クエリ名を経路ごとに分ける** (名前で系統が読めるようにする — `auth.md` §6.4 が
     `GetAccountByEmailForSignIn` に対して採ったのと同じ手):
     - `UnlockAccountByIDForAdmin` (⑦。許可リストに載せる) /
       **`UnlockAccountByIDInContract`** (`WHERE id = $1 AND contract_id = $2`。載せない)
     - `DeleteAccountMfaConfigForAdmin` (⑦。載せる) /
       **`DeleteAccountMfaConfigByAccountID`** (載せない。**契約検証は下記 2 で担保**)
  2. **`account_mfa_configs` を触る契約内管理者経路の契約検証の所在を明記する** —
     「`accounts` を `WHERE id = $1 AND contract_id = $2` で先に引き、0 件なら 404 を返す。
     **その戻り値から作った `AccountID` (= `auth.md` §6.4 ②のコンストラクタを通した型) でのみ
     MFA 設定を削除する**」を UseCase の必須手順として §3.5 の脚注に書く。
     併せて「載せないもの」2 行目から MFA リセットを分離し、
     **「`contract_id` を持たないテーブルは 2 段 (親で検証 → 子を操作) になる」ことを例外として明記**する
  3. **許可リストの記載形式に「呼び出しを許す系統」列を足す**ことを `auth.md` §6.4 への是正要求として起票する
     (現在の必須項目は「ファイルパス + クエリ名 + 種別 + 理由」)。
     `auth.md` §6.4 が却下したのは**③ (レコードを返す一意性検査) に呼び出し元を書かせる案**であり、
     **⑦ (全契約横断の書き込み) は却下理由が当てはまらない** — ③は「レコードを返す経路が残る」ことが
     却下理由だったが、⑦は書き込みで、かつ**系統 (`X-Admin-Token`) が `auth.md` §6.7 の CI 検査で
     既に機械判定できる**ため、系統列と系統検査の突き合わせが可能
- **併せて**: §7.3 の UT 必須ケース 3 は「他契約の `account_id` を指定した ... MFA リセット ... が 404」を
  既に持っており**振る舞いとしては担保されている**。本指摘は「**UT 1 本に依存し、構造 (CI 検査) で
  潰せていない**」点である (`feedback_review_patterns.md` の運用 = 「実装時に気をつける」で済ませない)

### 重大 5. 招待トークン / リセットトークンの**保存先の列と保存形**が定義されていない (BE-10 / DR-5 / D-5)

- **箇所**: `docs/design/API/auth-accounts.md:302` (AA-D-5 ①「**`signup_links.token`** → `(contract_id, email)` →
  `accounts` の 1 経路でアカウントを解決する」)、`同:433` (§3.5 `GetSignupLinkByToken`)、
  `同:434` (`GetResetPasswordRequestByToken`)、`同:367` / `:384` (§3.3 のフロー)
- **事実**:
  - `docs/design/data-model.md:405-415` (§4.2) は「**v2 の構造をそのまま v3 に作る (列の追加・削除をしない)**。
    **変える点は 2 つだけ**」= ①`enum` → `text` + `CHECK` ②`signup_links` に `contract_id` を追加。
    したがって **`signup_links` に `token` 列は無い**。v2 の秘密は **リンク ID (UUID v4) 自体**であり、
    本書自身が V2-F2 として出典付きで書いている (`create_signup_link.go:68`)
  - `reset_password_requests` の v2 の列は実測 **`hash text NOT NULL`** (`hassan-v2-backend/db/schema.sql:312-320`)。
    `token` という列は存在しない
- **なぜ本番で問題になるか**: 2 通りの実装が生まれ、どちらも別の決定と衝突する。
  - **(a) `id` をそのまま秘密として使う**: `docs/design/auth.md` §6.10-1 は
    「**パスワードリセット・招待・その他「秘密として送られる文字列」の生成はすべて `crypto/rand` を使う**」と
    決定している。`id uuid DEFAULT uuid_generate_v4()` は **DB 側 (uuid-ossp) の生成**であり、
    §6.10-3 の CI 検査 (`math/rand` の import 検出) は**アプリ外の生成経路を見られない**。
    「§6.10 を満たしているか」が**判定不能**になる
  - **(b) `token` 列を足す**: `data-model.md` §4.2 の「変える点は 2 つだけ / v2 に無い列を足さない」に
    **3 点目の変更**が必要。しかも **AA-D-5 の却下 (b) は `signup_links` への `account_id` 追加を
    「移行の写像が増える」を理由に却下している** — 同じ論法で `token` 追加も却下される筋になり、
    本書内で自己矛盾する
  - さらに **保存形 (平文 / ハッシュ) が未決定**。AA-D-4 は「秘密が ALB アクセスログに残ると
    **ログ閲覧権限がアカウント乗っ取り能力になる**」ことを理由に URL への配置を禁じた。
    **同じ論法が DB 読み取り権限に適用されていない** (v2 は `hash` 列に平文のトークンを入れている)。
    RL-3 の 1 回コピー (P-1) やバックアップ経路を含めると、**DB スナップショット閲覧権限が
    同じ能力を持つ**ことになる
- **修正案**: AA-D-5 に**④「秘密の格納」**を追加し、次の 4 点を確定させる (実装者に選ばせない):
  1. **列名**: `signup_links.token text NOT NULL UNIQUE` / `reset_password_requests` は v2 の `hash` を流用するか
     `token` へ改名するか (改名するなら `data-model.md` §4.2 の「変える点」に加える)
  2. **生成**: `crypto/rand` で **32 バイト → base64url** (`auth.md` §6.10-1 の適用先を具体化する)。
     **`id` を秘密に使わない** — §6.10 の CI 検査が届く場所に生成を置くため
  3. **保存形**: **SHA-256 のハッシュを保存し、平文は保存しない** (照合はハッシュの一致で行う)。
     AA-D-4 の論法 (秘密を保存する場所を増やさない) と一貫させる。
     平文保存を選ぶ場合は**却下案として理由を書く**
  4. **§3.5 のクエリ名を列名に合わせる** (`GetSignupLinkByTokenHash` 等)。
     `GetResetPasswordRequestByToken` も同様
  **併せて**: `data-model.md` §4.2 宛ての是正要求 (R-AA-16) を起票する。
  `signup_links` の変更が 2 点目 (`contract_id`) に加えて 3 点目になる旨と、
  「**v2 の既存未使用リンクは引き継がず失効・再発行**」(P-2) により**移行の写像が増えないこと**を明記する
  (これが `contract_id` 追加のときと同じ論法で承認される根拠になる)

### 重大 6. §4 の本番観点表に **D-1 / D-3 / D-8 の行が無い** (DR-2 = 無言の省略)

- **箇所**: `docs/design/API/auth-accounts.md:506-527` (§4 の表)
- **事実**: §4 は A-1〜A-7 / O-1〜O-7 / **D-2 / D-4 / D-5 / D-6 / D-7** に回答または対象外の理由を書いているが、
  **D-1 (環境)・D-3 (デプロイ手順とロールバック)・D-8 (IaC の管理範囲) の 3 行が存在しない**。
  ヘッダ (`同:6`) も「本書が回答する本番観点」に D 系は **D-5 (参照)** のみを挙げている。
  `.claude/rules/08-production-gates.md` の運用は
  「**回答も「対象外の理由」も無い ID を重大指摘**」「**対象外とする場合も、理由と先送り先を書く**」と定めている
- **なぜ本番で問題になるか (特に D-3)**:
  - 本書は **FE (Vercel) と BE (ECS) が対で切り替わらないと成立しない**領域である。
    `/login` `/mfa` `/mfa/setup` `/signup` `/reset-password` `/settings/members` `/admin/*` の
    **11 ルート** (`frontend.md` §11.1) が §2 の 37 本に 1:1 で依存し、
    **FE 先行デプロイ = 存在しない API を叩く / BE 先行 = `SignInResult` の新フィールドを使えない**。
    08 の D-3 が名指しする「**FE (Vercel) と BE (ECS) のリリース順序と互換性 (API 変更時)**」の
    最も効く箇所が、**検討済みかどうか読者に分からない**
  - **D-1**: 本書の移植で新たに必要になる環境固有値は Resend API キー・S3 バケット・
    `ADMIN_JWT_KEY` (D-5 行が挙げている) に加え、**`companies.mfa_type` が dev で `none` になる
    E2E 専用契約** (§3.6) がある。§3.6 の歯止め①②③は事実上 D-1 への回答だが、
    **D-1 の行が無いため「どの環境にどの値・どのシードが入るか」の一覧に到達できない**
  - **D-8**: レート制限カウンタの受け皿 (DB) と、`auth.md` §6.2 の③
    「社内管理者系エンドポイントを WAF の IP 許可リストで社内からのみ到達可能にする」は
    **本書の §2.4 の 8 本に直接掛かる IaC 要素**である。かつ `frontend.md:891` (§11.3.2) が
    「**WAF の IP 許可リストと FE-D' が両立しない (未解決)**」と起票している —
    **本書の §2.4 が成立するかどうかを左右する未解決事項**であり、対象外にするなら理由と先送り先が必要
- **修正案**: §4 の表に 3 行を追加する。
  - **D-1** = **回答**: 「環境固有値は `JWT_KEY` / `ADMIN_JWT_KEY` (`auth.md` §6.8) / Resend API キー /
    S3 バケット名。**dev には §3.6 の E2E 専用契約 (`companies.mfa_type='none'`) を投入し prod には投入しない**
    (歯止め①②③)。**FE (Vercel) 側の対応値は `frontend.md` §12 の環境変数 7 行**」+
    棚卸し先 `infrastructure.md` へのリンク
  - **D-3** = **回答 (要確認を含む)**: 「**BE 先行 → FE 後追い**を既定とする
    (§2 の 37 本はすべて新設であり、v2 の API を壊さないため BE を先に出しても既存 FE に影響が無い)。
    `SignInResult` の新フィールド (`auth_role` / `mfa.*` / `company_name`) は
    **FE が読めなくても動く追加のみ**で破壊的変更が無いことを明記。**ロールバック**は
    `data-model.md` §6.5 (v3 で変更したパスワードは v2 に戻らない) が SSOT」+ `operations.md` へのリンク。
    **リリース順序の SSOT が operations.md 側なら、その節番号を指す**
  - **D-8** = **参照 + 未解決の明示**: 「レート制限カウンタは DB (`data-model.md` §4.2 の
    `auth_rate_limit_counters`)。**§2.4 の 8 本に掛かる WAF の IP 許可リスト (`auth.md` §6.2 の③) は
    `frontend.md` §11.3.2 で FE-D' と両立しないことが未解決** (FE-Q7)。
    **本書の §2.4 はこの未解決に依存する**ため、決着先を明記する」

---

## 3. 中 (Should Fix) — 11 件

### 中 1. `auth.md` §6.6 の「`/mfa` 配下のみ許可」が残り、R-AA-2 が拾っていない (DR-8)

- **箇所**: `docs/design/auth.md:763` (§6.6 の表「MFA 必須かつ未検証 | **401** | なし | v2 と同じ。
  **`/mfa` 配下のみ許可**」)、`docs/design/API/auth-accounts.md:348` (§3.2 の S2 行が**この §6.6 を出典として引用**)、
  `docs/design/frontend.md:743` (`/mfa` 行の根拠列「**必要性の根拠は auth.md §6.6 の
  「MFA 必須かつ未検証は 401。`/mfa` 配下のみ許可」**」)
- **問題**: `auth.md` §6.7 は「v3 は許可ルートを**ホワイトリストとして 1 箇所に列挙**し、
  **前方一致判定を使わない**」と決定済みで、本書 §2.2 / AA-D-8 もこれに従っている
  (「v2 のパス前方一致 `/mfa` を採らない = V2-F7 を継承しない」)。
  しかし **§6.6 は「判定規則の SSOT」を自称する節**であり (`同:759`)、
  そこに v2 の前方一致がそのまま残っている。**`frontend.md` がこの文言を「根拠」として転記済み**であり、
  波及が始まっている
- **R-AA-2 の宛先は §6.6 なのに、この 1 点が入っていない** (①401 の本文 ②429 ③403 の第 3 系統 の 3 点のみ)
- **修正案**: R-AA-2 に④を追加 —
  「**§6.6 の「MFA 必須かつ未検証」行の備考「`/mfa` 配下のみ許可」を
  「§6.7 のホワイトリストに載せた 2 本のみ許可 (前方一致を使わない)」に書き換える**。
  併せて `frontend.md:743` の `/mfa` 行の根拠列も同時に直す (R-AA-11① の対象に含める)」。
  **本書 §3.2 の S2 行の出典も §6.6 → §6.7 に変える** (本書側の修正)

### 中 2. §2.6 が「機械照合の結果は §6 の検証欄」と書くが、§6 に検証欄が無い (DR-9 / DR-5)

- **箇所**: `docs/design/API/auth-accounts.md:255`
- **問題**: §6 は §6.1 (ユーザー判断が必要) / §6.2 (要確認) / §6.3 (本書の仮定) のみで、
  **検証欄も機械照合の結果も存在しない**。18 行の対応は人手の表 1 つだけ。
  `make doc-lint` は節アンカーを検査しないため通ってしまう。
  本レビューが独立に照合して 18/18 一致を確認したが (§1.3)、**文書の主張としては裏付けが無い**
- **修正案**: (a) 参照を削除して「§2.6 の表が対応の全件である」と書き切る、または
  (b) **`scripts/check-endpoint-mapping.sh` を新設**して
  「`settings.md` §5 の表の行数 == `auth-accounts.md` §2.6 の表の行数」と
  「§2 のエンドポイント実数 == `README.md` §3 の総覧の値」を照合し `make check` に載せる。
  **後者を推奨** — `README.md` §3 の「37」「110」「403 の 10 本」は
  **`check-table-counts.sh` の検算対象外**であり (実行結果で確認)、
  エンドポイントを 1 本足すと `README.md` §0 / §3 / §4 と本書 §2 の 7 箇所が連動する。
  rule 05 の「新しく増えた「N 件」が検算の対象に入っているか」に該当する

### 中 3. R-AA-12 が 2 行に重複 — 前回の改番が新しい衝突を作っている

- **箇所**: `docs/design/API/auth-accounts.md:546` (auth.md §6.2 宛て) と `同:549` (testing.md §7.3 宛て)
- **問題**: `:546` の備考は
  > 「**採番の経緯**: 当初 R-AA-10 として追記したが起草時の R-AA-10 と ID が衝突していたため
  > 2026-07-31 のレビュー指摘で **R-AA-12 へ改番した**」

  と書いているが、**改番先の R-AA-12 が既に `:549` に存在する**ため、
  **衝突が解消せず場所を移しただけ**になっている。表の並び順も
  R-AA-9 → **R-AA-12** → R-AA-10 → R-AA-11 → **R-AA-12** → R-AA-13 と崩れている。
  `grep -o "R-AA-[0-9]*" | sort -u` は 13 個の ID を返すが**表の行数は 14** で、機械的にも検出できる
- **なぜ問題か**: 是正要求は**他文書の担当者が ID で引き当てる**ための識別子である。
  重複すると「R-AA-12 に対応した」という報告がどちらを指すか判定不能になり、
  **片方が永久に未対応のまま「対応済み」と記録される** (状態列を持たせた目的が失われる)
- **修正案**: `:546` (auth.md §6.2 宛て) を **R-AA-17** など**現在の最大値より大きい ID** に振り直し、
  表を ID 昇順に並べ直す。**改番のたびに末尾に追加する運用**を §5 の冒頭に 1 行書く
  (ID の再利用・詰め直しをしない)。本レビューが要求する新規 ID (R-AA-14〜16) との衝突も避ける

### 中 4. R-AA-11① の「8 行」が実測と合わない (DR-9)

- **箇所**: `docs/design/API/auth-accounts.md:548`
- **問題**: 「根拠列が `[未確定] (Task-3i)` のままの **8 行**
  (`/login` / `/mfa` / `/mfa/setup` / `/signup` / `/reset-password` / `/settings/members` /
  `/admin/*` の 5 行)」と書いているが、**列挙自体が 6 + 5 = 11 行**であり **8 と矛盾**する。
  実測 (`frontend.md` §11.1) も **11 行**: `:742` `/login` / `:743` `/mfa` / `:744` `/mfa/setup` /
  `:745` `/signup` / `:746` `/reset-password` / `:770` `/settings/members` / `:771` `/admin/signin` /
  `:772` `/admin/mfa/setup` / `:773` `/admin/mfa` / `:774` `/admin/accounts` / `:775` `/admin/admins`
- **なぜ問題か**: 受け手 (frontend.md の担当) が「8 行直した」で完了と判断すると **3 行が残る**。
  残った行は `[未確定]` = 「仕様が無い」と読まれ、FE 実装者が着手不可と判断する
  (R-AA-11 自身が挙げている理由がそのまま残る)
- **修正案**: 「**11 行**」に訂正し、**ルート名を 11 件すべて列挙する** (「`/admin/*` の 5 行」のような
  ワイルドカードを使わない)。`/settings/profile` (`:769`) は **2026-07-31 に既に `[API]` へ更新済み**なので
  対象外である旨も添える

### 中 5. R-AA-11② は既に反映済みなのに状態列が「未対応」(DR-8 / 状態表の信頼性)

- **箇所**: `docs/design/API/auth-accounts.md:548` の状態列「**未対応**」
- **事実**: `docs/design/frontend.md:880` (§11.3.1) の「セッションの寿命」行は既に
  > 「7 日 (`docs/design/auth.md` §6.9-3) | **7 日で確定** (2026-07-31 の FE-Q8 回答 = 一般ユーザーと同じ。
  > `docs/design/API/auth-accounts.md` §2.4 の管理者トークンも 7 日)。FE の `maxAge` は BE の値に一致させる」

  に更新されており、**FE-Q8 (`同:1208`〜`:1216`) も回答済み**。R-AA-11② は**既に完了している**
- **なぜ問題か**: `.claude/rules/06-delegation-prompts.md` が状態列を持たせる目的として挙げたのは
  「**実施しても未対応に見えたまま残る**」ことの防止である。逆に**実施済みが未対応と書かれていると
  受け手が二重作業し、状態表そのものが信用されなくなる** (状態表を読まずに全件を見に行く運用に戻る)
- **修正案**: R-AA-11 を①と②に分割し、②を「**実施済み (2026-07-31。`frontend.md:880`)**」にする。
  併せて **R-AA-10 の状態列「未対応 (本書側は完了)」も同様に検証する** —
  `frontend.md:374` (§5.2.2) の暫定挙動 (「応答に入るまでは導線を全員に出す」) は**未解除のまま**であり、
  こちらは「未対応」が正しい

### 中 6. R-AA-4 が `data-model.md` 側の**件数連動**と**既存決定との衝突**に触れていない

- **箇所**: `docs/design/API/auth-accounts.md:540` (R-AA-4)
- **問題 (a) 件数の連動**: `account_deletions` を §4.9 に置く (= 機能テーブル) なら
  **機能テーブル 40 → 41 / 契約境界 8 → 9** になり、`make check-table-counts` が照合する **22 箇所**の
  一部が動く。検算があるため事故にはならないが (rule 05)、**要求に書かないと起草側が 1 巡余計に回る**
  (rule 05 が実測として記録した「`idea_tags` 1 テーブルの連動が 15 箇所・見積りが 2 回外れた」と同型)
- **問題 (b) 既存決定との衝突**: `docs/design/data-model.md:265` (§3.4.3-3) は
  > 「進捗は ... **残件数で表す** ... **別途の進捗テーブルを持たない**」

  と決定している。R-AA-4 が求める `account_deletions` は `status` / `remaining_aggregates` を持つため、
  **文面上は §3.4.3-3 と衝突する** (実質は「集約単位の進捗表」を否定したものであり、
  「ジョブ 1 行」は `DM-16` = `docs/design/data-model.md:132` の
  「非同期ジョブは**ドメインごとに持つ**」に従う形なので両立する)。
  **この読み替えを書かないと、data-model 側で「既に決めた方針と矛盾する」として却下されうる**
- **修正案**: R-AA-4 に 2 文を追加 —
  「**§3.4.3-3 の「別途の進捗テーブルを持たない」は集約単位の進捗表を否定したものであり、
  DM-16 (非同期ジョブはドメインごとに持つ) に従うジョブ 1 行とは両立する**。
  §3.4.3-3 にその旨の脚注を足すこと」+
  「**機能テーブルとして追加する場合、`§4.1.1` の 40 → 41 / 契約境界 8 → 9 と、
  それを転記した箇所 (`make check-table-counts` の照合対象 22 件) を同じ差分で更新すること**」。
  併せて `deletion_id` の型 (uuid か bigserial か) を明記する (軽微 5)

### 中 7. §3.4 の「ロック中のリセット完了画面で案内する」が**実装不能** (BE-10 / AA-Q3=b の波及)

- **箇所**: `docs/design/API/auth-accounts.md:406` (§3.4 の「回復側 (追加)」行)
  「**パスワード忘れ + 連続失敗ロックの複合ケースは「リセット後に契約内管理者へ解除を依頼」が正規手順** —
  FE はロック中のリセット完了画面でその旨を案内する (`frontend.md` §11.1 の `/reset-password`)」
- **問題**: `POST /accounts/reset-password/confirm` は **204 固定・本文なし** (§2.1 / AA-D-6)。
  したがって **FE は「対象アカウントがロック中かどうか」を知る手段が無い**。
  応答に載せれば `AA-D-6` の目的 (アカウントの状態を漏らさない) と直接衝突する。
  さらに `frontend.md` §11.1 の `/reset-password` 行は `[未確定] (Task-3i)` のままで、
  **この文言要件が FE 側のどこにも無い** (R-AA-11 も要求していない)
- **なぜ問題か**: AA-Q3 で**本人による回復を落とした** (2026-07-31 ユーザー回答 = (b)) ため、
  `auth.md` §6.9 が「**最も起きやすい**」とした経路 2 (管理者がパスワードを忘れて失敗ロック) の
  **唯一の案内経路がこの画面**である。実装不能なまま残すと、
  ユーザーはリセット成功 → サインイン失敗 → 原因不明のループに入る
- **修正案**: §3.4 の当該セルを
  「**FE は `/reset-password` の完了画面で無条件に『サインインできない場合はロックされている可能性があります。
  契約内管理者に解除を依頼してください』を案内する**」に書き換える (ロック状態を応答に載せない)。
  併せて **R-AA-11 に③として `frontend.md` §11.1 の `/reset-password` 行への文言要件の追加**を足す。
  **サインイン時の `account_locked` コード** (重大 3 のコード表) が実際の判別経路になる旨も明記する

### 中 8. `action` の値域がどこにも存在しないのに、3 文書が同じ節へ委譲している (BE-10)

- **箇所**: `docs/design/API/auth-accounts.md:478` (「記録項目・**`action` の値域の SSOT** は
  `observability.md` §4.5」)、`docs/design/API/settings.md:68` / `同:131` (D-ST-6 が同じ節へ委譲)
- **事実**: `docs/design/observability.md` §4.5 の全文には**記録対象の散文と記録項目のリストしかなく、
  `action` の値域 (列挙) が無い**。`docs/design/data-model.md:661` の `audit_logs` も `action text` (自由文字列)。
  **3 文書が存在しない値域を SSOT として参照している**
- **なぜ問題か**: `GET /usage-summary` は「メンバー × **活動種別 6 種**の月次クロス集計」であり
  (`settings.md:48` / `:68`)、**値域が確定しないと集計の列が決まらない**。
  本書 §3.7 の 9 行が追加する事象も同じ表に入る。値域が無いと実装リポで
  「文字列を各 UseCase が自由に書く」形になり、集計側が拾えない (BE-8 と同型の「黙って落ちる」)
- **修正案**: R-AA-7 に「**`observability.md` §4.5 に `action` の値域表 (ドメイン別) を新設する**。
  初期値は本書 §3.7 の 9 行 + `settings.md` の 6 種 + `auth.md` §6.9 のロック / 解除。
  **`data-model.md` の `action text` に `CHECK` を張るか、値域を Go の定数 1 箇所に置くかも決める**」を追加する

### 中 9. `settings.md` の「入出力仕様の起草は未着手」が残り、R-AA-3 が拾っていない (DR-8)

- **箇所**: `docs/design/API/settings.md:30` (§2 の前置き「認証・認可の規約は `auth.md`、
  **入出力仕様の起草は未着手** (同 §10.2 R-3)」)、`同:158` (§5 の前置き「**入出力仕様の起草は未着手**」)
- **問題**: R-AA-3 の宛先は **`settings.md` §5** なのに、要求は表の 3 点のみで、
  **§5 冒頭と §2 冒頭の状態記述を本書への参照に差し替える要求が無い**。
  `settings.md` から入る読者 (設定画面の実装者) は「仕様が無い」と読む。
  `.claude/rules/06-delegation-prompts.md` の
  「**機構を直したら、その機構を語る文書を同じ差分で直す**」と同じ型
- **既知事項との関係**: 「`docs/design/` の「未着手」stale 12 箇所」の一部と重複する可能性があるが、
  **R-AA-3 が名指しで宛先にしている文書の中の記述**なので、本書の是正要求の欠落として挙げる
- **修正案**: R-AA-3 に④として
  「**§2 (`:30`) と §5 (`:158`) の「入出力仕様の起草は未着手」を
  「入出力仕様は `auth-accounts.md` が確定 (2026-07-31)」へ書き換える**」を追加する。
  `settings.md:220` (ST-Q6) の「`docs/design/data-model.md` (**未着手**)」も同じ差分で直せる

### 中 10. `settings.md` §5 の `POST /admin/signin` の出典が誤りで、R-AA-3 が拾っていない (DR-1)

- **箇所**: `docs/design/API/settings.md:180` (「**社内管理者のサインイン** | `POST /admin/signin` |
  **`同:194`**」)。本書 §2.6 row 11 (`:269`) はこの行を対応表に載せているが、誤りを指摘していない
- **事実**: 実測 `hassan-v2-backend/router/router.go:195` = `adminRoute.POST("/signin", ...)`。
  **`:194` は `adminRoute := r.Group("/admin")`**。
  **`docs/design/auth.md:498` は既に「`同:195` (**公開エンドポイント**。`:194` は `r.Group("/admin")`)」と
  正しく注記しており、本書 §2.1 (`:113`) も `同:195` と正しい**。
  つまり **`settings.md` だけが誤ったまま残っている**
- **なぜ問題か**: 実装者は移植チェックリスト (`settings.md` §5) を作業リストとして使う。
  行番号が 1 つずれると `r.Group` の行を見て「middleware が付いていない理由」を誤解する。
  本書は §2.6 で全 18 行を照合したと主張しているため、**照合の網に行番号が入っていない**ことが分かる
- **修正案**: R-AA-3 に⑤として
  「**`POST /admin/signin` の出典を `同:194` → `同:195` に訂正する** (`:194` は `r.Group("/admin")`。
  `auth.md` §6.2 が既に正しく注記済み)」を追加する。
  併せて §2.6 の照合に「**出典の行番号も照合対象に含めた**」旨を明記する (していないなら主張を弱める)

### 中 11. `POST /accounts/signup` が 201 と 200 の 2 系統で書かれている (整合)

- **箇所**: `docs/design/API/auth-accounts.md:110` (§2.1 の固有ステータス列「**201** / 404 / 409 / 400 / 429」) と
  `同:386` (§3.3 のフロー「**200 SignInResult** (そのままサインイン状態にする。再入力を求めない)」)
- **問題**: 同じエンドポイントの成功コードが **201 (§2.1) と 200 (§3.3)** で食い違う。
  §2.0 は「作成 201 / 更新 200 / 削除 204 (`README.md` D-API-11)」を宣言しているが、
  `POST /accounts/signup` は**リソースの作成ではなくパスワードの設定 (既存行の更新)** であり、
  `SignInResult` を返すため意味的には 200 が近い。§3.3 の直後の散文
  (「**却下**: 204 を返してサインイン画面に送る」) も 201 を前提にしていない
- **なぜ問題か**: FE の `orval` 生成型は成功コードごとにレスポンス型を持つため、
  **どちらで実装されるかで FE のハンドリングが変わる**。§7.3 の UT 必須ケースにも入っていない
- **修正案**: **200 に統一する** (既存行の更新であり、`Location` を返さないため)。
  §2.1 の該当セルを 200 に直し、**§2.0 の「作成 201」の例外である理由を 1 行添える**
  (`README.md` D-API-11 に対する明示の例外)。201 を採るなら §3.3 を直し、
  「新規リソースの作成として扱う理由」を書く

---

## 4. 軽微 (Nice to Have) — 7 件

| # | 箇所 | 内容 | 修正案 |
|---|---|---|---|
| 軽微 1 | `docs/design/API/auth-accounts.md:276` (§2.6 row 18) / `同:298` (AA-D-1) | **「要確認 AA-Q1」が残っている**。AA-Q1 は §6.1 (`:565`) で **(a) 移植しない** と回答済み (2026-07-31。PoC 調査結果まで添えられている)。DR-8 の型 | 両箇所を **「AA-Q1=a (2026-07-31 回答済み)」** に置き換える。既存データの扱いは R-AA-6 が引き継ぐ旨を添える |
| 軽微 2 | `同:45` (V2-F4) / `同:543` (R-AA-7) | **出典の行番号が ±1** — V2-F4 の `schema.sql:48` は実測 **`:49`** (`CREATE UNIQUE INDEX unique_accounts_email ON accounts (email);`。`:48` は空行)。R-AA-7 の `同:481-489` は実測 **`:482-489`** (`CREATE TABLE activity_logs`。`:481` は空行) | 実測値に直す。**他 11 件の出典は完全一致**だったため、この 2 件のみ |
| 軽微 3 | `同:148` (§2.3.2 の `GET /accounts` 行) | **1 セル内で `同` の指す先が切り替わる** — 「`同:65`、`hassan-v2-backend/db/queries/account.sql:20-24`、ロック列は `同:98`」で、最初の `同` は `router.go`、最後の `同` は `account.sql` | 最後を `account.sql:98` と明記する (同じセル内で `同` を再定義しない) |
| 軽微 4 | `同:7` (ヘッダ) | **ヘッダが「対応する受入基準: AC-1.1 / AC-1.4 / AC-1.5 / AC-1.6」と宣言しているが、§4 の表は AC-1.1 / AC-1.2 / AC-1.4 しか参照していない**。AC-1.5 (鍵管理と失効手段) / AC-1.6 (認証エンドポイントの濫用対策) の対応箇所が本書内に無い (`plan.md:132` の割り当てとは整合するので `make check-traceability` は通る = DR-6 の逆形) | §4 の **D-5 行に AC-1.5**、**O-4 行または §3.7 のレート制限段落に AC-1.6** を明記する。本書の貢献は「適用対象の列挙」(P-7) である旨を添える |
| 軽微 5 | `同:153` (`GET /account-deletions/{deletion_id}`) / `同:540` (R-AA-4) | **`deletion_id` の型が書かれていない**。§2.0 は「ID は `accounts` / `contracts` / `companies` が uuid」と 3 テーブルのみ列挙し、`data-model.md` の他のジョブ (`asset_extractions`) との整合も不明 | R-AA-4 の列定義で **`id uuid`** か **`bigserial`** を確定し、§2.0 の ID 型の列挙に加える (FE の生成型が変わる) |
| 軽微 6 | `同:664-676` (§7.3 の UT 必須ケース 8 件) | **AA-Q3=b の帰結 (リセット成功がロックを解除しないこと) のテストが無い**。当初案 (a) を反転した判断であり、テストで固定しないと「親切な実装」として解除が入りうる (v2 と同じ挙動に戻すのが正) | ケース 9 として「**`POST /accounts/reset-password/confirm` の成功後も `last_locked_at` / `failed_sign_in_attempts` が変化しない**」を追加 (根拠: AA-Q3=b / V2-F10) |
| 軽微 7 | `同:210` (§2.5 の `Account`) | **`is_locked` / `locked_at` と DB 列 `last_locked_at` の対応が書かれていない**。`is_locked` は `last_locked_at IS NOT NULL` の導出値、`locked_at` は同列の値と読めるが明示が無い | §2.5 に 1 行注記する (`is_locked` = `last_locked_at IS NOT NULL` / `locked_at` = `last_locked_at`)。API 名と列名が違う唯一の箇所である |

---

## 5. 是正要求 R-AA-1〜13 の妥当性判定

**判定の凡例**: **妥当** = そのまま反映すべき / **妥当 (要補強)** = 方向は正しいが要求内容が不足 /
**要修正** = 要求の内容自体に誤りがある / **不要** = 既に解消済み。

| # | 宛先 | 判定 | 根拠 (一次ソース / 対象文書で照合した結果) |
|---|---|---|---|
| **R-AA-1** | `auth.md` §6.11-3 | **妥当** | `auth.md:1046` の「対象」行は実測で「サインイン / パスワードリセット要求 / 招待受諾など**未認証で叩けるエンドポイント**」と書かれており、**MFA 検証は対象外**。かつ `account.sql:56-64` は `WHERE email = $2` でパスワード失敗のみを加算する (実測一致) ため、**TOTP 6 桁 = 10^6 への総当たりを止める機構が本当に無い**。優先度は高い |
| **R-AA-2** | `auth.md` §6.6 / `README.md` §2.5 | **妥当 (要補強)** | ①②③はいずれも実在の差分。①`auth.md:762` の表は「401 / なし」を 3 行で宣言済み ②`README.md` は **§0 (`:25`〜`:31`) で既に差分 3 点を注記済み**であり、**残っているのは §2.5 本体の 429 行と 403 の行** ③`README.md:246` / `:460` が「合計 11 本」を「6 ドメインについての数」と既に注記済み。**補強すべきは中 1 の④ (「`/mfa` 配下のみ許可」の削除)** と、**重大 3 のコード表への参照** |
| **R-AA-3** | `settings.md` §5 | **妥当 (要補強)** | ①`router.go:216` = `adminCompanyRoute.GET("/accounts", ...)` が `settings.md` §5 の 18 行に無いことを実測確認 ②`同:217` も無い ③`update_email.go:35-66` に `EmailService` 依存が無いことを実測確認 (「検証メール等を含む」は誤り) — **3 点すべて正しい**。**補強**: 中 9 (「未着手」の状態記述) と中 10 (`:194` → `:195`) を④⑤として追加 |
| **R-AA-4** | `data-model.md` §4.9 / §4.2 | **妥当 (要補強)** | `grep -rn "account_deletions" docs/design/data-model.md` → **0 件**。`data-model.md:132` (DM-16) が「非同期ジョブはドメインごとに持つ」と決めており、**単一 `jobs` テーブルは却下済み**なので専用テーブルが必要 = 要求は正しい。**補強**: 中 6 (件数連動 + §3.4.3-3 との読み替え + `deletion_id` の型) |
| **R-AA-5** | `data-model.md` §4.2 | **妥当** | `register_admin_password_requests` は `data-model.md:377` (§4.1.2 (a)) と `同:415` (§4.2 対象) に実在。`auth.md:503` が社内管理者の投入を移行スクリプトに限定し (「**v3 では API を作らず、移行スクリプトによる投入とする**」)、本書 §2.7 が作成 API を対象外としているため、**読み手も書き手も無い** = BE-10。要求どおり「外すか経路を定義する」が正しい。**外す場合は §4.1.2 (a) が 6 → 5 件、§3.3 検査①の除外リストが 8 → 7 件**になる (重大 1 の `admin_mfa_configs` 追加と差し引きゼロになる可能性があるので、**2 件を同じ差分で扱うよう R-AA-5 に注記すると事故が減る**) |
| **R-AA-6** | `data-model.md` §6.4 (DM-A2) | **妥当** | AA-Q1=a により `/company-mission` を移植しない決定が確定した (2026-07-31)。v2 の `company_missions` は**アカウント単位**で発散セッションの既定ミッションに使われる (V2-F16 の出典は本書が提示)。**v3 に写す先を決めないと既存データが消える** = DR-3 (既存データの不在)。`operations.md` §6.3.1 の切替告知にも追加済みと本書が書いており、整合している |
| **R-AA-7** | `observability.md` §4.5 | **妥当 (要補強。優先度最高)** | `observability.md` §4.5 の記録対象を全文確認した結果、**認証系の事象は「アカウントの手動ロック / 解除」1 種のみ**で、**v2 に既存の 6 種 (`schema.sql:467-479` 実測一致) はすべて無い**。3 巡目レビューの判定 (「未反映のまま Freeze すると O-6 に v2 で既にできていた 6 事象が落ちる」) は**正しい**。**補強が 2 点**: **重大 2** (actor / contract が確定しない `signin_failed` を `audit_logs` に書けない) と **中 8** (`action` の値域そのものが §4.5 に無い) |
| **R-AA-8** | `auth.md` §6.3 の例外表 | **妥当** | `data-model.md:387` が `account_mfa_configs` を「(b) 所有者列を実際に持つ 5 件 = **検査①の例外ではない**」に置き、`同:391`〜`:396` の注記が「**検査①の除外リストに持つ**」と整理済み。**したがって必要なのはスキーマ検査の除外だけで、`auth.md` §6.4 の許可リスト登録は不要** = 本書の指摘は正しい。ただし**本書 §3.5 自身が `account_mfa_configs` の扱いを 2 行で矛盾させている** (重大 4 の (b)) ため、R-AA-8 を出す前に本書側を直す必要がある |
| **R-AA-9** | `auth.md` §6.7 の 4 系統表 | **妥当** | `auth.md:790`〜`:795` の表を実測: 「ユーザー認証 | `AuthRequiredMiddleware(AuthRoleUser)` | **上記と管理者系を除く全ルート**」で、**ユーザー側の MFA 未検証系統は表に無い**。管理者側は 4 行目として載っている。**非対称は実在**。本書 §2.2 / §2.4.1 の 5 分類の方が「節ごとに 1 系統」で CI 検査の元表になり実装しやすい。**5 系統へ揃える案を推奨** |
| **R-AA-10** | `frontend.md` §5.2.2 / §16.2-6 | **妥当** | `frontend.md:374` を実測: 「**`role` は v2 のサインイン応答に無い** ... 応答に入るまでは**契約内管理者限定 3 画面の導線を全員に出し、403 をインラインで表示する**」— **暫定挙動は未解除**。本書 §2.5 の `SignInResult` が `auth_role` / `mfa.required_type` / `mfa.verified` / `account.id` / `account.name` / `company_name` を**全件含む**ことを確認したので、要求は成立する。状態列「未対応 (本書側は完了)」も正しい |
| **R-AA-11** | `frontend.md` §11.1 / §11.3.1 | **①妥当 (要修正: 8 行 → 11 行) / ②不要 (既に反映済み)** | ①は中 4 のとおり件数が誤り。②は中 5 のとおり `frontend.md:880` で**既に「7 日で確定」に更新済み**。**③を追加すべき** (中 7 の `/reset-password` の文言要件) |
| **R-AA-12** (`:546`。auth.md §6.2 宛て) | `auth.md` §6.2 | **妥当 (ただし ID を要修正)** | `auth.md:497`〜`:505` の「含めるもの」表を実測: ロック解除 / 管理者サインイン / MFA 登録・検証 / **MFA のリセット (実行者は SuperAdmin のみ = 管理者自身の MFA)** / 管理者の初期投入 の 5 行で、**「一般アカウントの MFA リセット」(`router.go:217`) は無い**。AA-Q2=a (2026-07-31) で本増分に含めると確定したので追加要求は妥当。**ID が R-AA-12 と重複している** (中 3) |
| **R-AA-12** (`:549`。testing.md 宛て) | `testing.md` §7.3 / §13.1 | **妥当** | `testing.md` §7.3 の MFA 行を実測: 「**例外の表現方法は Task-3i が定義する**」が残っている。本書 §3.6 が定義を与えた (`companies.mfa_type='none'` + 歯止め 3 点 + コード分岐を作らない) ので参照先の更新は妥当。**§3.6 の歯止め③ (CI 検査) を `testing.md` の検査一覧に載せる**要求も妥当 (載せないと検査が誰の担当か決まらない) |
| **R-AA-13** | `plan.md` / `aidlc-state.md` / `todo.html` | **妥当 (ただし前提が未成立)** | 状態更新の要求自体は正しいが、**本レビューが重大 6 件を出したため「Task-3i 完了」は今の時点では成立しない**。§7 の Freeze 判定に従い、**重大の解消後に更新する**のが正しい順序。要求の文面に「**重大指摘の解消後に**」を足すこと |

**是正要求の網の評価**: 13 ID / 14 行のうち **要修正は 2 件のみ** (R-AA-11① の件数 / R-AA-11② の状態)、
**残りは妥当または妥当 (要補強)**。**要求の方向はほぼ正しい** — 問題は
**網から漏れた 5 件** (重大 1 の `admin_mfa_configs` / 重大 2 の `audit_logs` の書けない事象 /
重大 3 のコード値域 / 重大 5 のトークン列 / 中 8 の `action` 値域) であり、
いずれも「**本書が他文書へ委譲した先に、受け皿が存在しない**」型である。
**委譲先を書いたときに、その節を開いて受け皿の実在を確認する**手順が抜けている。

### 5.1 R-AA-2 の判定の訂正 (`README.md` §2.5 本体を実測した結果)

上表の R-AA-2 の根拠を `docs/design/API/README.md:250` / `:257`〜`:275` (§2.5 の適用一覧) で
**実測し直した結果、`README.md` 側は既に 3 点すべて反映済み**である。判定を分割して訂正する。

| 宛先 | 訂正後の判定 | 実測 |
|---|---|---|
| `README.md` §2.5 | **不要 (既に反映済み)** | ①401 行に「**`docs/design/API/auth-accounts.md` は例外** — 資格情報の不一致 ... を 401 + `CodedError` 本文で返す」(`:259`) ②429 行に「**`docs/design/API/auth-accounts.md` は 429 を返す** — 同書 §3.7 が対象エンドポイントを列挙する」(`:274`) ③`:250` に「**同書の 403 は 10 本ある**」 |
| `auth.md` §6.6 | **妥当 (要補強)** | `auth.md:762`〜`:769` の表は依然「401 / なし」の 3 行のまま。403 の第 3 系統 (R-3) も無い。**加えて中 1 の「`/mfa` 配下のみ許可」も残っている** |

**これは是正要求の状態管理の欠陥でもある** (中 5 と同型) — **R-AA-2 の状態列は 2 つの宛先を
1 行で「未対応」と書いており、片方が完了しても表現できない**。
**修正案**: R-AA-2 を **R-AA-2a (`auth.md` §6.6 宛て。未対応)** と
**R-AA-2b (`README.md` §2.5 宛て。実施済み 2026-07-31)** に分割する。
**宛先が複数の是正要求は宛先ごとに行を分ける**ことを §5 の運用に 1 行書く。

**さらに重要**: `README.md:259` は
> 「**FE の「401 → 強制サインアウト」の分岐は本文のコードで切り分ける**必要があるため、
> **規則は同書 §3.1 が持つ**」

と書いており、**`frontend.md` §9 / §5.2.3 と合わせて 3 文書・4 箇所が
「`auth-accounts.md` §3.1 が 401 のコード規則の SSOT」と宣言している**。
**§3.1 にコードの列挙が無い**ため、**重大 3 は「1 文書の抜け」ではなく
「3 文書が同じ空箱を指している」状態**である。優先度は重大の中でも最上位。

---

## 6. 本番観点カバレッジ (`.claude/rules/08-production-gates.md` 全 ID)

| ID | 状態 | 箇所 | 内容の妥当性 (回答の有無だけでなく中身を判定) |
|---|---|---|---|
| **A-1** 認証方式 | **回答あり** | §4 の A-1 行 / §2.1〜§2.4 の節構成 | **妥当**。37 本すべてに要求系統が宣言され、節構成がホワイトリストの元表になる形は `auth.md` §6.7 の CI 検査と噛み合う。公開 6 本の内訳 (v2 同一 4 + `/admin/signin` は §6.2 の例外 + `lookup` は v2 の `GET …/:id` の置換) も追跡可能 |
| **A-2** ロールと適用範囲 | **回答あり** | §4 の A-2 行 / §2.3 / §2.4.2 | **妥当**。4 段 (一般 / 契約内管理者 / 社内管理者 / SuperAdmin) の割り当てが 403 の実数 (9 + 1 = 10) と一致。**V2-F12 の 7 操作をすべて維持し新しいロール差を作っていない**点が `auth.md` §9.3 Q-A2 と整合。AA-Q6 (会社情報更新を全メンバーに開く) を**仮定として明示**しているのも正しい |
| **A-3** テナント境界 | **参照 (一部欠落)** | §4 の A-3 行 / §5 R-AA-4 | **重大 1** — `admin_mfa_configs` の定義先が無く是正要求も無い。`account_deletions` は起票済み。前提 2 点 (`signup_links.contract_id` / `accounts.email` グローバル一意) は実測一致 |
| **A-4** 絞り込みの層 | **回答あり (穴あり)** | §4 の A-4 行 / §3.5 | **重大 4** — 許可リストの⑦が契約内管理者経路と同名で、V2-D4 が CI を通る。`NewAccountIDInContract` を通す方針自体は正しく `auth.md` §6.4 ②と整合。§3.5 が「載せないもの」を明記した設計は良いが、`account_mfa_configs` について主張が偽 |
| **A-5** ステータスコード | **回答あり (値域欠落)** | §4 の A-5 行 / §2 の各表 / §3.1 | **重大 3** — `CodedError` のコード値域が無く、3 文書が本節を SSOT に指名している。差分 3 点 (401 に本文 / 429 / 403 の第 3 系統) の自己申告と是正要求は正しい。**中 11** — signup の 201/200 が不一致 |
| **A-6** LLM への越境 | **対象外 (理由あり)** | §4 の A-6 行 | **妥当**。本書に LLM 経路が無いことは §2 の 37 本を実測して確認。唯一の候補 `GET /companies/genai` を §2.7 で `llm-migration.md` へ先送りし、**移植時も `gateway/` 経由必須**を条件付けている |
| **A-7** 共有・公開 | **回答あり** | §4 の A-7 行 / AA-D-15 | **妥当**。`sharing_settings` を応答から落とす判断が `auth.md` §7 (本増分では共有機能を持たない) と `README.md` D-API-8' の増分 2 方針の両方に整合。**代わりに `member_count` を返す理由 (人数上限 409 の残枠可視化) が BE-10 の「読む側」として筋が通っている** |
| **O-1** 構造化ログ | **参照 + 回答** | §4 の O-1 行 | **妥当**。「秘密文字列を URL に置かない」(AA-D-4) を O-1 の構造的回答として位置づけたのは適切 (ログを直す運用に依存しない) |
| **O-2** LLM 計測 | **対象外 (理由あり)** | §4 の O-2 行 | **妥当**。「計測対象 3 本は増えない」と `README.md` §4 の O-2 行との整合を明示している |
| **O-3** コスト集計 | **対象外 (理由あり)** | §4 の O-3 行 | **妥当** (LLM 経路が無い) |
| **O-4** 失敗の可観測性 | **回答あり** | §3.7 末尾 / §4 の O-4 行 | **妥当だが重大 3 に依存** — 「401 の内訳をコードで区別する」が O-4 の中身だが、コードが定義されていないため観測も成立しない。**メール送信失敗を握り潰さない**点は v2 の実害 (`create_signup_link.go:80-82`) を出典付きで挙げており良い |
| **O-5** SSE / 長時間処理 | **回答あり** | §4 の O-5 行 | **妥当**。SSE なし / 長時間処理は削除ジョブ 1 本のみで、`README.md` §1.3 の J-2 / J-3 / J-5 / J-7 に個別に対応づけている。進捗を SSE にせずポーリングとした根拠も `data-model.md` §3.4.3-3 を引いている |
| **O-6** 監査ログ | **回答あり (書けない事象がある)** | §3.7 / §4 の O-6 行 / R-AA-7 | **重大 2** — `signin_failed` が `audit_logs` の `NOT NULL` 制約に当たって書けない。**中 8** — `action` の値域が委譲先に存在しない。エンドポイント別に記録事象を確定した表そのものは良い |
| **O-7** アラート | **対象外 (先送り。入力を明示)** | §4 の O-7 行 | **妥当**。「429 の急増 / レート制限ストア障害による 503 / 社内管理者のサインイン失敗」の 3 つを入力として明示し、`auth.md` §10.2 R-6 と同じ経路に載せている |
| **D-1** 環境 | **未回答** | — | **重大 6**。§3.6 の歯止め①②③が事実上の回答だが、§4 に行が無く到達できない |
| **D-2** CI ゲート | **回答あり** | §4 の D-2 行 | **妥当**。追加する検査 2 件 (prod デプロイが E2E シードを参照しない / 公開エンドポイントが §2.1 の 6 本と完全一致) はいずれも機械化可能で、`auth.md` §6.7 の系統検査の入力として §2 の表を使う設計も筋が通る |
| **D-3** デプロイ手順 | **未回答** | — | **重大 6**。**本書は FE 11 ルートと BE 37 本が対で切り替わる領域**であり、08 が名指しする「FE (Vercel) と BE (ECS) のリリース順序と互換性」が最も効く |
| **D-4** マイグレーション | **参照** | §4 の D-4 行 | **妥当** (本書はスキーマを新設せず、追加要求のみ)。ただし**重大 1 / 重大 5 で追加要求が 1 → 3 件に増える** |
| **D-5** シークレット管理 | **参照 (回答あり)** | §4 の D-5 行 | **妥当**。`JWT_KEY` / `ADMIN_JWT_KEY` を `auth.md` §6.8 に委譲し、**本書の移植で新たに必要になる資格情報として Resend API キーと S3 を特定**している (V2-F11 の出典付き)。棚卸し先も明示。**重大 5 (トークンの保存形) が D-5 の隣接論点として残る** |
| **D-6** Managed Agent | **対象外 (理由あり)** | §4 の D-6 行 | **妥当** (本書に Agent / custom tool は無い) |
| **D-7** 段階リリース | **参照** | §4 の D-7 行 | **妥当**。P-1 (v3 を正とする 1 回コピー) とロールバックの代償 (v3 で変更したパスワードは v2 に戻らない) を `data-model.md` §6.5 に委譲。**委譲先に実在することを `data-model.md` §6.5 で確認済み** |
| **D-8** IaC の管理範囲 | **未回答** | — | **重大 6**。§2.4 の 8 本に掛かる WAF の IP 許可リストが `frontend.md` §11.3.2 で**未解決**として起票されており、対象外にするなら理由と先送り先が必要 |

**集計 (全 22 ID)**: **回答あり 10 / 参照 4 / 対象外 (理由あり) 5 / 未回答 3** (D-1 / D-3 / D-8)。
未回答 3 件は DR-2 (無言の省略) として**重大 6** に集約した。

---

## 7. 頻出パターン (`.claude/rules/feedback_review_patterns.md`) の確認結果

### 7.1 DR-1〜DR-9 (全件)

| # | 判定 | 根拠 |
|---|---|---|
| **DR-1** 出典なしの断定 | **良好** | v2 の主張 (V2-F1〜F17 / V2-D1〜D6) はすべて `パス:行` を伴う。**抜き取り 13 件中 13 件一致** (§1.5 + `GetMyAccount` の `mfa_enabled` 常に false の検証)。ずれは ±1 行が 2 件のみ (軽微 2) |
| **DR-2** 本番観点の無言の省略 | **該当 (重大 6)** | §4 に **D-1 / D-3 / D-8 の行が無い**。A-6 / O-2 / O-3 / D-6 は「対象外 + 理由」を書いており、落ちやすいとされる ID はむしろ守られている |
| **DR-3** 既存データの不在 | **良好** | P-1 (RL-3 の 1 回コピー・以後 v3 が唯一の書き込み先・v2 資格情報をフォールバック参照しない) / P-2 (v2 の未使用招待リンクは失効・再発行) を前提として明示し、`company_missions` の既存データ (R-AA-6) まで拾っている。**ロールバックの代償 (v3 で変更したパスワードは v2 に戻らない) も §4 の D-7 行で参照済み** |
| **DR-4** PoC 実装のコピー設計 | **非該当** | 本書は v2 の移植であり PoC 由来の構造は無い。`CodedError` / gin / sqlc の前提に沿っている (§7.2 が `controller/controller.go:30-125` を参照実装に挙げ、**v3 は 401 に本文を持つ点が違う**と差分を明示) |
| **DR-5** 曖昧語による丸投げ | **一部該当** | `grep -nE "適切に|必要に応じて|後で検討|別途検討|要検討"` → **0 件**。ただし**実質的な丸投げが 2 箇所**: **重大 3** (「専用コードで区別する」だがコード名が無い) と **重大 5** (「`signup_links.token`」だが列も生成方法も保存形も無い) |
| **DR-6** AC の宙吊り | **良好 (軽微 1 件)** | `make check-traceability` → productionization 47/47 カバー。逆形として**軽微 4** (ヘッダが AC-1.5 / AC-1.6 を宣言するが本文に対応箇所が無い) |
| **DR-7** プロトタイプを仕様として扱う | **良好** | 本書はプロトタイプを 1 度も根拠にしていない (`grep -c "prototype"` → 0)。仕様の入力は v2 の実装と `auth.md` / `frontend.md` の決定のみ |
| **DR-8** 修正の波及漏れ | **該当 (中 1 / 中 4 / 中 5 / 中 7 / 中 9 / 軽微 1)** | **本リポジトリで 4 巡連続の最上位指摘**が本書でも再発。①AA-Q1 が回答済みなのに「要確認 AA-Q1」が 2 箇所に残る ②AA-Q3=b の反転が `frontend.md` §11.1 の `/reset-password` に波及していない (中 7) ③R-AA-2 / R-AA-11 の状態列が実態と乖離 (中 5 / §5.1) ④`auth.md` §6.6 の「`/mfa` 配下のみ許可」が `frontend.md:743` に転記済み (中 1)。**一方 §3.3 / §3.4 は AA-Q3=b に合わせて改訂済み**で、思考の対象になった節は正しく直っている — DR-8 の定義どおりの症状 |
| **DR-9** 件数・集合サイズの転記 | **該当 (中 2 / 中 4 / 中 6)** | ①**R-AA-11① の「8 行」が実測 11 行** ②**§2 の「37 本」「合計 110」「403 の 10 本」が `check-table-counts` の検算対象外** (実行結果で確認) で、`README.md` §0 / §3 / §4 と本書 §2 の 7 箇所が連動する ③**重大 1 の `admin_mfa_configs` 追加で動く「除外リスト 8 件」も検算対象外**。**新しく増えた「N 件」が検算に入っていない** = rule 05 の観点にそのまま該当 |

### 7.2 BE / FE パターン (本書が触れる領域)

| # | 判定 | 根拠 |
|---|---|---|
| **BE-2** 設定値の SSOT | **良好** | しきい値・トークン有効期間・招待/リセットの期限をすべて `auth.md` §10.2 R-4 の設定 1 箇所に委譲 (P-7 / AA-Q9)。本書で値を再定義していない |
| **BE-8** schema と handler の乖離 | **非該当** (custom tool が無い) | — |
| **BE-10** 読む側と書く側の対 | **該当 (重大 1 / 2 / 3 / 5 / 中 7 / 中 8)** | **本レビューの重大 6 件のうち 5 件が BE-10**。本書は BE-10 を**自ら 6 回引用**して他文書の穴を指摘している (AA-D-7 / AA-D-15 / R-AA-3① / R-AA-5 / §3.4 / §7.1) — **観点は正しく持っているが、自分が委譲した先には適用していない** |
| **BE-11** 採番と冪等性 | **良好** | AA-D-13 が冪等キー = 対象 `account_id`、実行中の同一対象は 200 で既存を返すと明記。`README.md` J-5 に整合 |
| **FE-2** snake_case 漏れ | **良好** | §2.0 で JSON キーを snake_case に固定し、変換は orval / API 境界に委ねる方針と整合 |
| **FE-1** AbortError | **非該当** (SSE / 中断経路が無い) | — |

---

## 8. Freeze 可否 (auth-accounts.md スコープ)

**Freeze 不可**。`.claude/rules/01-aidlc.md` の Design Freeze 条件 3 (「別セッションの `design-reviewer` レビューで
重大事項ゼロ」) を満たさない。

| 条件 | 判定 |
|---|---|
| 1. `make check` が通る | **✓ 通過** (エラー 0 / AC 47/47 / 件数照合 22 件 0 エラー) |
| 2. `08-production-gates.md` の 3 領域に回答または「対象外の理由 + 先送り先」 | **✗** — **D-1 / D-3 / D-8 が未回答** (重大 6) |
| 3. `design-reviewer` レビューで重大ゼロ | **✗** — **重大 6 件** |
| 4. 実装リポへの引き渡し情報 (影響レイヤー・依存順序・並列可能タスク・参照すべき v2 実装) | **✓ 揃っている** (§7.1 の依存順序 / §7.2 の参照実装 11 行 / §7.3 の UT 8 件)。**ただし §7.1 の「共通層」に `admin_mfa_configs` のスキーマと 401 コード表が含まれていない** |

### 8.1 解消の推奨順序 (依存関係がある)

1. **重大 3 (401 のコード表)** — 3 文書 4 箇所が本書 §3.1 を SSOT に指名しており、
   **これが無い間 FE は §9 の 401 分岐を実装着手できない**。本書内で完結するため最短で潰せる
2. **重大 5 (トークンの列と保存形)** — 本書内の AA-D-5 の補強 +
   `data-model.md` §4.2 宛ての新規要求 1 件。**サインアップ / リセットの実装着手条件**
3. **重大 1 (`admin_mfa_configs`)** と **重大 2 (`audit_logs` の書けない事象)** —
   いずれも `data-model.md` / `observability.md` 宛ての新規要求。**重大 1 は件数の連動を含むため
   `R-AA-5` (`register_admin_password_requests` の除外) と同じ差分で扱う**
4. **重大 4 (許可リストの⑦)** — 本書 §3.5 の書き換え + `auth.md` §6.4 宛ての新規要求 1 件
5. **重大 6 (D-1 / D-3 / D-8)** — §4 に 3 行追加。**D-8 は `frontend.md` §11.3.2 の未解決 (FE-Q7) に依存**するため、
   「未解決に依存する」ことを明記する形で先に閉じられる
6. **中 3 (R-AA-12 の重複 ID)** — 新規要求 (R-AA-14〜17) を足す前に採番を整理する。**先にやると後がぶれない**
7. 中 1 / 中 2 / 中 4〜11 / 軽微 1〜7

### 8.2 他スコープへの影響

- **`productionization` feature 全体の Freeze**: 本書が唯一の未レビュー文書だったため、
  **本レビューで未レビュー状態は解消**したが、**重大 6 件により feature 全体の Freeze も引き続き不可**
- **`docs/design/data-model.md`**: 本書由来の追加要求が **1 件 (`account_deletions`) → 3 件**
  (+ `admin_mfa_configs` + `signup_links` / `reset_password_requests` のトークン列) に増える。
  `make check-table-counts` の検算対象と除外リスト件数の更新を伴う
- **`docs/design/observability.md`**: R-AA-7 の内容が「6 事象の追加」から
  「6 事象 + `action` 値域表の新設 + actor / contract が確定しない事象の扱い」に拡大する
- **`docs/design/frontend.md`**: 重大 3 のコード表が入るまで §9 の 401② と §5.2.3 は実装不能。
  R-AA-11 は①の件数訂正・②の削除・③の追加が必要

---

## 9. 良かった点 (維持すべきもの)

1. **出典精度が本リポジトリの成果物の中で最も高い** — 抜き取り **13 件中 13 件一致**、ずれは ±1 行が 2 件。
   特に `dto/account.go:139-141` (`RequestResetPasswordRes.Hash`)、`account.sql:80-81`
   (`CountAdminsByContractID`)、`aws/s3.go:46`/`:58`、`dto/account.go:155-157` は**完全一致**。
   「`GET /accounts/me` の `mfa_registered` は v2 では常に false」という主張も実測で裏付けられた
   (`controller/account.go:174-177` が `dto.ToAccountRes(authAccount)` を返すだけで、
   `MfaEnabled` は `dto/account.go:67-68` のコメントどおり「usecase で後付け」= GetMyAccount では埋まらない)
2. **v2 の欠陥を 3 件**新規に発見し、**それぞれに対応する設計判断を紐づけている** —
   V2-D1 (招待リンクの突合欠落による他契約アカウント乗っ取り) は `auth.md` §5 にも無かった**新規の重大な欠陥**で、
   実測でも確認できた。V2-D3 (`RequestResetPasswordRes.Hash`) を「**現在は未使用だが型が残る限り
   実装の前例として復活しうる**」と捉えて「秘密を応答に含める型を作らない」を決定に昇格させたのは、
   このリポジトリの設計として正しい抽象度
3. **却下案の質が高い** — AA-D-4 (秘密を URL に置かない) が
   「`infrastructure.md` §3.2 が prod で ALB アクセスログを有効にする決定を持つ」→
   「**アプリ側のログを直しても消えない**」→「**ログ閲覧権限がアカウント乗っ取り能力になる**」と
   **他文書の決定から帰結を導いている**。AA-D-16 の「アイコンだけ例外にすると
   『公開バケットが 1 つ存在する』状態になり、次の実装者が置き場所を判断する余地が生まれる」も同型
4. **§3.6 (E2E の MFA 例外) が「裏口を作らない」形で解けている** —
   `companies.mfa_type='none'` という**実顧客契約でも取り得る正当な設定**を使い、
   `if isE2E` を作らない。歯止め 3 点 (dev 専用シード + `APP_ENV != dev` で異常終了 /
   prod の投入手順に含めない / CI で prod デプロイジョブがシードを参照しないことを検査) は
   **1 つが破れても他が残る多層**になっている。却下案 2 つ (`mfa_exempt` フラグ / 環境変数で全体無効化) の
   理由も具体的 (「フラグが 1 行入った瞬間に、それを true にできる経路が MFA の迂回路になる」)
5. **AA-D-10 (MFA 検証のレート制限) は本書が新規に発見した穴** — 「TOTP は 6 桁 = 10^6 の探索空間で、
   パスワードを知る攻撃者が総当たりできる。**`failed_sign_in_attempts` はパスワード失敗でしか増えない**ため
   ロック機構では止まらない」は実測で裏付けられた (`account.sql:56-64` は `WHERE email = $2`)。
   `auth.md` §6.11-3 の対象定義 (未認証経路のみ) の**実質的な穴**であり、R-AA-1 は優先して反映すべき
6. **AA-D-12 の「ロックのカウントには `AND last_locked_at IS NULL` を含めるが、
   降格・削除のカウントは v2 どおり見ない」の区別** — 「降格・削除は行そのものを変えるため、
   ロック中の管理者も『解除すれば使える管理者』として数えるのが正しい」という理由づけは、
   同じ「最後の管理者ガード」を**操作の性質で書き分けた**もので、機械的な踏襲より一段深い
7. **§7.3 の UT 必須ケース 8 件が「v2 の欠陥を退行させない」形で選ばれている** —
   ケース 1 (V2-D1)・2 (前方一致でないこと)・3 (他契約の 404)・7 (MFA 不一致が 500 にならない) は
   いずれも**実測で確認した v2 の実害に 1:1 対応**している。`feedback_review_patterns.md` の
   「実装時に気をつける」ではなく「テストで固定する」形に落ちている
8. **是正要求に状態列を持たせている** (`.claude/rules/06-delegation-prompts.md` の運用に従っている)。
   中 3 / 中 5 / §5.1 で指摘したのは**状態列の運用の粗さ**であって、状態列を持つ判断自体は正しい

---

## 総合判定

| 区分 | 件数 |
|---|---|
| **重大 (Must Fix)** | **6 件** |
| **中 (Should Fix)** | **11 件** |
| **軽微 (Nice to Have)** | **7 件** |

**Freeze 判定 (`docs/design/API/auth-accounts.md` スコープ)**: **不可**。
重大 6 件の解消後に再レビューを要する (`.claude/rules/04-review.md`: 「重大ゼロでない場合、修正してから再レビュー」)。

**重大の見出し**:

1. `admin_mfa_configs` に定義先が無く、是正要求も出ていない (BE-10 / A-3)
2. `signin_failed` を `audit_logs` に書けない — O-6 が v2 より後退する (BE-10 / O-6)
3. 401 の `CodedError` コード値域がどこにも定義されていない (3 文書 4 箇所が本書 §3.1 を SSOT に指名。BE-10 / A-5)
4. 許可リストの種別⑦が契約内管理者経路と同名で、V2-D4 (テナント越境) が CI を通る (A-4)
5. 招待トークン / リセットトークンの保存先の列と保存形が定義されていない (BE-10 / D-5)
6. §4 の本番観点表に D-1 / D-3 / D-8 の行が無い (DR-2 = 無言の省略)

**性質の総括**: 重大 6 件のうち **5 件が「他文書へ委譲した先に受け皿が無い」型 (BE-10)** である。
本書は BE-10 を**自ら 6 回引用して他文書の穴を指摘している**ため、観点そのものは持っている。
欠けているのは **「委譲先の節を開いて受け皿の実在を確認する」手順**であり、
これは §5 の是正要求を書くときに機械化できる (委譲先の節に対して
`grep` でテーブル名 / 値域 / コード名の実在を確認し、無ければ是正要求を起票する)。

**逆に、設計判断そのもの (AA-D-1〜16) に誤った判断は 1 件も見つからなかった** —
採用案・却下案・理由がすべて揃い、却下理由は他文書の決定や v2 の実測から導かれている。
重大の全件は「決定は正しいが受け皿が無い」であり、**設計のやり直しではなく追記で閉じられる**。

**未調査 / 対象外にした範囲 (正直な申告)**:

- `docs/design/auth.md` §6.2 (MFA の新規実装) / §6.4 (許可リスト 7 種の分類そのもの) / §6.7 (4 系統) の
  **妥当性は判定していない** (別レビュアーの担当)。本レビューは「auth-accounts.md がこれらと矛盾していないか」のみを見た
- **`docs/design/frontend.md` / `testing.md` / `operations.md` / `infrastructure.md` の全文は読んでいない** —
  auth-accounts.md が名指しした節 (frontend.md §5.2.2 / §5.2.3 / §9 / §11.1 / §11.2 / §11.3.1 / §16、
  testing.md §7.3) のみを照合した。**`operations.md` §6.1 (RL-2) / §6.3.1 (切替告知) は未照合**であり、
  §3.6 の歯止め② (prod の初期スキーマ投入にシードを含めない) が実際に反映されているかは確認していない
- **追加照合 (レビュー末に実施。いずれも一致)**: ①`docs/design/API/themes.md:21` / `:49` / `:51` / `:65` に
  `mission` が実在し、TH-Q7=a で `subtitle`/`purpose` を統合済み → **AA-D-1 の前提「ミッションはテーマが持つ」は成立**
  ②`docs/design/operations.md:514` (§6.3.1) に「**企業ミッション (会社単位) の提供終了** — v3 はテーマ単位の
  `mission` に一本化 (2026-07-31 の AA-Q1=a)」の行が実在 → **AA-Q1 の「切替告知の対象に追加」は反映済み**。
  これで抜き取り照合は **15 件中 15 件一致**
- v2 の一次ソースは**認証・アカウント系に限って**読んだ (`router.go` / `schema.sql` / `account.sql` /
  `usecase/account` / `usecase/mfa` / `controller/{account,mfa,controller}.go` / `dto/account.go` / `aws/s3.go`)。
  `usecase/admin_account/` は `unlock_account_by_admin.go` の存在確認のみで**中身は未読**
- 既知の未反映事項 (「未着手」stale 12 箇所 / `plan.md:35`〜`:39` / review-round3 の中 1〜4・軽微 1〜4) は
  **本レビューの件数に含めていない**

---

## 指摘の反映記録 (2026-07-31 夜・メインセッション)

> **重要**: 本書の主対象 `docs/design/API/auth-accounts.md` と `docs/design/API/README.md` は
> **別セッションが並行して編集中**である (21:16〜21:48 に更新を実測)。`.git` が無く復元手段が無いため、
> **メインセッションはこの 2 ファイルを編集していない**。下表の「未対応 (並行編集)」はその理由による。

| 指摘 | 反映先 | 状態 |
|---|---|---|
| **重大 1** `admin_mfa_configs` に定義先が無い | `docs/design/data-model.md` §4.2 (定義を新設) / §4.1.2 (a) (例外表に追加) / §3.3 検査① / §7.2 検査 1 / `auth.md` §6.3 | **実施済み** — 列は v2 の `account_mfa_configs` を雛形に `admin_account_id` (PK・`admin_accounts` への FK CASCADE) / `mfa_type` (`totp` 固定) / `otp_secret` / `is_verified` / タイムスタンプ。**連動する件数を全件更新** (機能テーブル以外 11→**12** / (a) 6→**7** / 除外リスト 8→**9**) し、**同時に `make check-table-counts` の検算対象へ加えた** (指摘が求めた「検算対象に加えるか定義元へのリンクにする」の両方を実施 — 転記側は削除、定義元は検算) |
| **重大 2** `signin_failed` を `audit_logs` に書けない | `docs/design/data-model.md` §4.10 | **実施済み (推奨 (a))** — `actor_type` に **`unauthenticated`** を追加し、`actor_id` / `contract_id` を**条件付き NULL 可**に。**`CHECK` で「NULL を許す条件」を表明**し (`llm_call_records` の計測 CHECK と方針を揃えた)、`detail jsonb` に **`email_hash` (SHA-256)** を入れる規約と部分インデックスを定義。**却下 (b)(c) の理由も記録**。旧記述「NOT NULL を維持できる」は改訂した |
| **重大 3** 401 の `CodedError` 値域が未定義 | — | **対応不要 (現況で解消)** — 照合したところ `auth-accounts.md` **§3.1.1 (AA-D-18)** に値域が存在し、`AU-C-00001`〜`00005` が本文で使われている。**レビュー実行中に並行セッションが追記したと推測**される。`auth.md` §6.6 側には**分類 T / C と「本文を返す唯一の例外」**を追記済み |
| **重大 4** 許可リスト種別⑦が契約内管理者経路と同名 | `auth.md` §6.4 (**⑦の追加制約**を新設) | **実施済み** — ①**クエリ名で系統を分ける** (`UnlockAccountByIDForAdmin` / `UnlockAccountByIDInContract`。括弧書きで区別しない) ②許可リストに**「呼び出しを許す系統」列を必須**にし §6.7 の系統検査と突き合わせる ③**`contract_id` を持たないテーブルは 2 段** (親で検証 → 子を操作) を UseCase の必須手順に |
| **重大 5** 招待 / リセットトークンの列と保存形が未定義 | `docs/design/data-model.md` §4.2 (「招待・リセットの秘密の格納」を新設 + 変える点を 2→**3 つ**へ) | **実施済み** — `signup_links.token_hash` / `reset_password_requests.token_hash` (v2 の `hash` を改名)、**`crypto/rand` 32 バイト → base64url をアプリ側で生成**、**SHA-256 ハッシュのみ保存**。**却下案 2 つ (平文保存 / `id` を秘密に使う) の理由を明記** — 後者は §6.10-3 の CI 検査が届かず「§6.10 を満たすか判定不能」になる。**移行では既存の未使用リンク・未使用リセット要求を失効・再発行** |
| **重大 6** §4 に D-1 / D-3 / D-8 の行が無い | `docs/design/API/auth-accounts.md` §4 | **未対応 (並行編集)** — 上記の理由。**指摘内容 (3 行の追記案) はそのまま使える** |
| **中 1** `auth.md` §6.6 の `/mfa` 前方一致 | `auth.md` §6.6 | **実施済み** (5 巡目レビュー 中 5 と同一。ホワイトリスト参照へ) |
| **中 8** `action` の値域がどこにも無い | `docs/design/observability.md` §4.5.1 | **実施済み (別セッション)** — 21:47 に同節が新設されたことを実測確認。`data-model.md` §4.10 側からも「値域と記録項目の SSOT は observability.md §4.5」を参照させた |
| **中 9** `settings.md` の「入出力仕様は未着手」 | `docs/design/API/settings.md` §2 / §5 / ST-Q6 | **実施済み** — 3 箇所を「**`auth-accounts.md` が確定 (2026-07-31)**」へ。ST-Q6 の `data-model.md` (未着手) も実リンクへ |
| **中 10** `POST /admin/signin` の出典が誤り | `docs/design/API/settings.md` §5 | **実施済み** — `同:194` → **`同:195`** (`:194` は `r.Group("/admin")`)。訂正の根拠も併記 |
| **中 2〜7 / 中 11 / 軽微 1〜7** | `docs/design/API/auth-accounts.md` | **未対応 (並行編集)** — すべて同書内の修正 (R-AA の改番・件数・状態列・201/200 の統一・出典 ±1 行ほか)。**別セッションが同書を編集中**のため引き渡す |
