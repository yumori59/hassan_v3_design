# レビュー: ユーザー決定 4 件 (AA-D-22 / AA-D-23 / AA-Q10 / DM-Q2) のスコープ縮小反映

- 実施日: 2026-08-10
- レビュアー: `design-reviewer` (別セッション。本番基準)
- 対象差分: `git diff origin/docs/20260809-implementation-schedule..HEAD` (コミット `5f3bb88` / `abf3a22`)

## レビュー結果サマリ

- **対象 (レビューした設計成果物。リポジトリ相対パス)**:
  - `docs/design/auth.md`
  - `docs/design/API/auth-accounts.md`
  - `docs/design/data-model.md`
  - `docs/design/API/README.md`
  - `docs/design/API/settings.md`
  - `docs/design/observability.md`
  - `docs/design/frontend.md`
  - `docs/design/architecture.md`
  - `aidlc-docs/schedule-2026q3.md`
- **重大: 10 件 / 中: 9 件 / 軽微: 4 件**
- 実行した検証: `make check` (**エラー 0 / 警告 50**。出力は §A) / DR-8 の識別子・状態語 grep 全件 (§B) /
  参照リポジトリの抜き取り照合 **7 件** (§C。うち C-16 の可否を左右する 3 件を含む)

**総評**: **決定 4 件そのものの反映方向は正しい**が、**波及が「思考の対象になった節」だけで止まっており、
DR-8 (修正の波及漏れ) が過去最大規模で発生している**。とくに **`docs/design/API/auth-accounts.md` §4
(本番観点への回答表) と `docs/design/auth.md` §7 の A-1 行が一切更新されていない** — これは
`08-production-gates.md` の回答そのものが旧決定を主張している状態で、**設計を読んだ実装者が
「社内管理者に MFA を実装する」と判断できる**。加えて **AA-Q10 (手動ロックの実装スコープ外) が
`docs/design/auth.md` §6.9 に明記された成立条件を破っている**が、その帰結がどこにも書かれていない。

---

## 重大 (Must Fix)

### 重大 1. 本番観点の回答表 (A-1 / A-2) が旧決定のまま — ゲートの回答が誤り (DR-2 / DR-8)

- **箇所**: `docs/design/auth.md:1251` (§7 の A-1 行) / `docs/design/API/auth-accounts.md:696`〜`:699` (§4 の A-1 / A-2 行)
- **事実**:
  - `auth.md:1251` は今も「**社内管理者の MFA 必須化** (§6.2。`admin_mfa_configs` の新設・管理者トークンへの
    `mfa_verified` 追加・ミドルウェア判定・登録/検証/リセットのフロー)」を **A-1 の回答**として掲げている。
    同じ表の 1 行下 `:1252` (A-2) は「**社内管理者に MFA を課さない**」と書いており、**同一の表の隣接行が矛盾**する。
  - `auth-accounts.md:697` (A-1) は「§2 の**全 37 本**」(実測 33)、`:699` (A-2) は
    「②§2.3 の **9 本**が 403 ③§2.4 の **8 本** ④**SuperAdmin** = `POST /admin/admins/{id}/mfa/reset` の **1 本**」
    と書いている。**④のエンドポイントは本差分で削除済み**であり、③は実測 5 本、②は実測 8 本
    (§2.3.2 の 7 本 + §2.3.3 の 1 本。`make check-endpoint-mapping` の実測 8 と一致)。
- **本番で何が問題か**: `08-production-gates.md` は「設計書は各項目に **ID で回答**する」と定めており、
  実装リポとレビュアーはこの表を**回答の正**として読む。**A-2 (ロールと適用範囲) が存在しないロール
  (SuperAdmin 限定操作) を宣言している**ため、実装リポは `CheckSuperAdminRole` 相当を作り、
  対応する経路が無いまま CI の系統宣言に到達不能な行を残す (AA-D-22 の却下 (b) が名指しで避けたはずの状態)。
- **修正案**: `auth.md` §7 の A-1 行から MFA 必須化の記述を落とし、AA-D-22 への参照に置き換える。
  `auth-accounts.md` §4 の A-1 / A-2 / A-3 / A-5 / D-4 / D-1・D-3・D-8 の各行を実測値へ更新する
  (下記 重大 6 と同じ差分で行うこと)。

### 重大 2. §6.7 の系統表 (CI 検査の入力) が旧記述のまま — 3 系統化が本文だけで表に届いていない

- **箇所**: `docs/design/auth.md:901`
- **事実**: 本文 `:889`〜`:892` は「**v3 は 3 系統を持つ**」「4 番目の系統が消滅した」と改訂されたが、
  **直下の系統表の「社内管理者認証」行は未修正**:
  - ミドルウェア列 = 「`AdminAuthRequiredMiddleware` 相当 (**MFA 検証済みを要求**)」
  - 該当ルート列 = 「… / **社内管理者自身の MFA リセット (SuperAdmin 限定)** / …」
- **本番で何が問題か**: 同節は「**ホワイトリストは『パス → 要求する認証系統』の宣言**とし、
  CI はルート定義と宣言の**系統単位の一致**を検査する」と定めている。**この表が検査の入力**なので、
  ①存在しないルート (`POST /admin/admins/{id}/mfa/reset`) が宣言に残り
  ②`AdminAuthRequiredMiddleware` に「MFA 検証済み要求」が実装されることになる。
  実装ブランチ `feat/6` の `16da244` は既に 3 系統なので、**設計と実装がこの表の粒度で再び食い違う**
  (P-5 を「解決」としたが、表が直っていないため解決していない)。
- **修正案**: 該当行のミドルウェア列を「`AdminAuthRequiredMiddleware` 相当 (MFA 判定なし)」に、
  ルート列から「社内管理者自身の MFA リセット」を削除する。

### 重大 3. AA-Q10 (手動ロックの実装スコープ外) が auth.md の明示された成立条件を破っている — 是正要求も無い

- **箇所**: `docs/design/auth.md:1053`〜`:1057` / `docs/design/API/auth-accounts.md:842` (AA-Q10) /
  `docs/design/frontend.md:786`
- **事実**: `auth.md:1053`〜`:1057` は JWT 有効期間 7 日据え置きの根拠として次を書いている (原文):

  > **却下 (a): トークンのブラックリスト (`jti` + 失効テーブル) を持つ案** — … **手動ロック API があれば
  > アカウント単位の即時遮断で漏洩時の要件を満たせる**。… **この却下は 2 (手動ロック API の新設) が
  > 実装されることを前提とする** — **2 を落とすとこの却下理由は成立せず、漏洩時に最大 7 日間対処できない状態になる**

  AA-Q10 は **まさに 2 を本増分から落とした**。にもかかわらず `auth.md` は 1 文字も変わっていない
  (`:1290` の失効手段表・`:1414` のリフレッシュトークン却下・`:1146` の「手動ロック API を新設する」も同様)。
  `frontend.md:786` も「**ロックの実行 UI はここだけにある** — **この画面が無いと製品内に即時遮断手段が存在しない**」
  という旧文の前に警告を挿入しただけで、**「存在しない」という帰結が現に成立したこと**を書いていない。
- **本番で何が問題か**: **9 月末リリース時点で、トークン漏洩・退職者・不正アクセスに対する即時遮断手段が
  製品内に存在しない**。しかも `frontend.md:142` (FE-D) と `:121` は「XSS で漏れても手動ロックで遮断できる」を
  ブラウザに JWT を渡さない判断の裏付けに使っており、**FE 側の安全性の根拠も同時に失効している**。
  DM-Q2 (無効化のみ) と組み合わせると、**「無効化したメンバーが最大 7 日間アクセスし続ける」**が設計どおりになる。
- **修正案**: `auth.md` §6.9 に AA-Q10 の受信欄を作り、①却下 (a) の前提が本増分では不成立であること
  ②本増分での代替 (社内管理者の `DELETE /admin/accounts/{id}/lock` は解除専用なので代替にならない)
  ③受け入れるリスクと再開の入口 (AA-Q10) を明記する。**「設計は残す」だけでは、成立条件を失った他の決定は直らない**。

### 重大 4. DM-A5 (`accounts.deactivated_at`) の帰結が 1 つも設計されていない (BE-10 / DR-5)

- **箇所**: `docs/design/data-model.md:424` (DM-A5) / `docs/design/API/auth-accounts.md:172` /
  `同:769` (R-AA-27) / `同:869`
- **事実**: 列を足す決定はあるが、**読む側がどこにも無い**:

  | # | 欠落 | 現状 |
  |---|---|---|
  | 1 | **サインイン拒否** | `auth-accounts.md:125` (`POST /accounts/signin`) の固有ステータスに無効化済みの扱いが無い。`auth.md` §1.3 の判定 (実在確認・ロック確認) にも `deactivated_at` が入っていない → **無効化したメンバーがサインインできる** |
  | 2 | **既存トークンの失効** | 無効化しても JWT は最大 7 日有効。唯一の即時遮断手段 (手動ロック) は AA-Q10 で実装スコープ外 (重大 3) |
  | 3 | **一覧の既定除外** | `data-model.md:424` は「**R-AA-27 で決める**」、`auth-accounts.md:769` (R-AA-27) は「**同節 (data-model §4.2) で決めること**」— **循環委譲でどちらも決めていない**。にもかかわらず `auth-accounts.md:869` は R-AA-27 を「**実施済み (2026-08-10。DM-A5)**」と書いている |
  | 4 | **所有物の参照** | 個人スコープ 34 テーブルは `WHERE account_id = <認証ユーザー>` で引く。無効化するとその行は**契約内の誰からも読めない**。`data-model.md:212` の「**契約の資産が失われないという v3 の目的は満たす**」は、この経路が無い限り成立しない |
  | 5 | **email の再利用** | `hassan-v2-backend/db/schema.sql:49` = `CREATE UNIQUE INDEX unique_accounts_email ON accounts (email)` (**グローバル一意**。抜き取り照合済み)。v2 は物理削除でアドレスが解放されていたが、v3 は**永久に占有される** → 同一人物の再招待・別契約での利用が 409 になる。記述なし |
  | 6 | **契約の人数上限** | `POST /accounts` の 409 「契約の人数上限」(`auth-accounts.md:169`) が無効化済みを数えるか未定 |

- **本番で何が問題か**: 1 と 2 は**退職者のアクセスが切れない**という直接の事故。5 は運用開始後に
  「再入社した人を登録できない」形で必ず出る。3 は DR-5 (曖昧語による丸投げ) そのもので、
  かつ**未決定を「実施済み」と記録している**ため次のレビューで検出されない。
- **修正案**: `auth-accounts.md` §2.3.2 の `DELETE /accounts/{account_id}` と §2.1 の `POST /accounts/signin` に
  無効化の判定を書き込み、§7.3 の UT 必須ケースに「無効化済みアカウントのサインインが 401」を追加する。
  3 の循環委譲は片方 (auth-accounts §5 R-AA-27) を廃し、`data-model.md` §4.2 で確定させる。
  5・6 は AA-D-13 の「代償」欄に明記する。

### 重大 5. 所有者移管 UseCase を前提にした CI 検査が残り、実装リポで必ず落ちる (DR-9 の名指しした故障形)

- **箇所**: `docs/design/data-model.md:211` (§3.4.1 の 2) / `同:194` (§3.3 の検査②-1) / `同:1158` (§7.2 の検査 2-1)
- **事実**: §3.4.1 の 3 は「削除せず無効化のみ」に改訂されたが、**同じ表の 2 は未改訂**で
  「**所有者移管 (メンバー削除時) は専用の UseCase 1 本だけが行う**。対象は §3.4.2 の**分類①に限る**。
  **§3.3 の検査②-1 で機械照合する**」と残っている。検査②-1 は
  「**§3.4.2 の分類① (移管対象。31 件) の集合 == 所有者移管 UseCase が `UPDATE` するテーブルの集合** (厳密な集合一致)」。
  移管 UseCase を作らない以上、**右辺は空集合**であり **31 ≠ 0 で必ず失敗する**。
  `auth-accounts.md:769` (R-AA-27) 自身が「§3.4.3 の移管方式は本増分では使われない」と書いている。
- **本番で何が問題か**: `05-harness.md` が DR-9 の理由として挙げた
  「**設計どおりに実装した検査が必ず落ちる**」がそのまま起きる。実装リポは検査を消すか空実装を作るかの
  判断を迫られ、どちらでも**将来 (移管を再開したとき) の担保が失われる** (DR-10)。
- **修正案**: §3.4.1 の 2 と §3.3 の検査②-1 / §7.2 の検査 2-1 に「本増分では対象なし。移管を再開する増分で復活させる」を
  明記し、**検査の期待値を「分類①の集合 == 空集合」ではなく「移管 UseCase が存在しないこと」に置き換える**か、
  検査そのものを条件付きにする。同時に `scripts/check-table-counts.sh` の分類①の 31 件が
  何のための数え上げなのかを再定義する (現状は移管対象の定義そのもの)。

### 重大 6. 表セルの外に注記を書いたため、レンダリング上は旧記述しか見えない (3 箇所)

- **箇所**: `docs/design/auth.md:1037` / `docs/design/API/settings.md:182` / `同:183`
- **事実** (パイプ数を実測):

  ```
  docs/design/auth.md:1037        : pipes=4 : after-last-pipe='[ **(2026-08-10 補足: AA-D-22 で MFA も課さないため、社内管理者は締め出しの経路自体を持たない)**]'
  docs/design/API/settings.md:182 : pipes=4 : after-last-pipe='[  ⚠️ **2026-08-10: v3 では作らない** (`auth-accounts.md` AA-D-22)]'
  docs/design/API/settings.md:183 : pipes=4 : after-last-pipe='[  ⚠️ **2026-08-10: v3 では作らない** (同 AA-D-22)]'
  ```

  GFM の表行は**最後の `|` で終端**するため、その後ろのテキストは**表示されない**。
  結果として読者が見るのは:
  - `auth.md:1037` = 「**ただし MFA 必須化により「MFA デバイスの紛失」が新しい到達不能経路になる** →
    他の SuperAdmin による MFA リセットで回復する (§6.2)」という**完全に旧前提の本文だけ**
  - `settings.md:182-183` = 「社内管理者の MFA 登録・検証 / リセット」が**移植対象として何の注記もなく残る**
- **本番で何が問題か**: `settings.md` §5 は **C-16 (v2 にある操作は落とさない) の移植チェックリスト**であり、
  `make check-endpoint-mapping` が行数を数える対象でもある。**取り消されたことが見えない**ため、
  実装リポは 2 本を移植対象として起票する。`auth.md:1037` は §6.9 のロックアウト経路表であり、
  存在しない回復手段 (SuperAdmin による MFA リセット) を対策として提示し続ける。
- **修正案**: 3 箇所とも**セル内**に取り消し線 + 注記を入れる (`observability.md:307` が採った形が正しい実例)。

### 重大 7. frontend.md の `(admin)` 画面数が 3 / 4 / 5 の三重不整合 + 存在しないルートを middleware 定数が宣言している

- **箇所**: `docs/design/frontend.md:143` (FE-D') / `同:787`〜`:789` (§11.1) / `同:837` / `同:868`〜`:869` / `同:993` (§13 の A-2 行)
- **事実**:
  - §11.1 の `(admin)` 行は **3 行** (`/admin/signin` / `/admin/accounts` / `/admin/admins`)
  - FE-D' (`:143`) は「**`(admin)` は 4 画面になった**」
  - §13 の A-2 回答 (`:993`) は「③**社内管理者の 5 画面**を `(admin)` グループとして本増分に含める」(未修正)
  - `:837` の `ADMIN_MFA_PENDING_PATHS` は **`/admin/mfa` / `/admin/mfa/setup`** を宣言したまま。
    `:839` の「**4 本に分ける理由**」、`:868`〜`:869` の
    「`(admin)` ↔ `ADMIN_PUBLIC_PATHS ∪ ADMIN_MFA_PENDING_PATHS` (`(admin)` の残り = `/admin/accounts` /
    `/admin/admins` は「管理者認証 + **MFA 検証済み**」必須)」も未修正
- **本番で何が問題か**: `:868` の等式は**ルートグループと middleware 定数の網羅性不変条件**であり、
  FE 側の到達性検査の入力になる。**存在しないルートを含む定数**は、①実装が空の `/admin/mfa` ページを作るか
  ②検査が「宣言にあるがファイルが無い」で落ちるかのどちらかを確定で引き起こす (DR-10:
  構造変更で無償の担保が消える型)。加えて `/admin/accounts` / `/admin/admins` に「MFA 検証済み必須」が
  残っているため、**管理者が永久に到達できない画面**になる。
- **修正案**: `ADMIN_MFA_PENDING_PATHS` を削除し (定数は 4 本 → 3 本)、`:868`〜`:869` の等式と
  `:845` の遷移表の `(admin)` 列、`:993` の A-2 回答、FE-D' の画面数を **§11.1 の実測 3 と一致させる**。
  **数を書かず「§11.1 の表が正」とする**方が DR-9 の再発を防ぐ。

### 重大 8. FE-D' の書き換えで、MFA と無関係な決定と却下案が巻き添え削除された (DR-10)

- **箇所**: `docs/design/frontend.md:143`
- **事実**: 旧 FE-D' は ①`(admin)` ルートグループ ②**next-auth のインスタンスとセッション Cookie を
  一般ユーザー系と分ける** (`app/api/admin-auth/[...nextauth]`・Cookie 名を別にする)
  ③**`X-Admin-Token` を付けるのは `lib/api/admin-mutator.ts` の 1 ファイルのみ** の 3 点を決め、
  却下案 (a) v2 の 1 next-auth に provider 併置 (V-19/V-20) / (b) 別 Vercel プロジェクト /
  (c) UI を作らず API 直叩き / (d) `(app)` に置きロールで出し分け の 4 件を持っていた。
  **新 FE-D' は「`(admin)` ルートグループに分け、`X-Admin-Token` を別ストアで保持する」の 1 行と
  却下案 1 件のみ**になり、②③と却下 (b)(c)(d) が消えた。**いずれも AA-D-22 と無関係**である。
- **本番で何が問題か**: 消えた②③を**根拠として参照している記述が全て残っている**:
  `:172` / `:174` (ディレクトリ構成の `api/admin-auth/[...]`)、`:337` / `:349`〜`:357` (§5.2.1 admin-mutator と
  eslint 検査)、`:897` / `:899` (§11.3.1 の対比表)、`:949` (`ADMIN_AUTH_SECRET` = 「§11.3.1 で next-auth を
  2 系統に分ける帰結」)、`:992` (A-1 回答)、`:1077` / `:1089`。**決定を持つ節が空になり、
  機構 (eslint ルール・Cookie 分離) だけが根拠なしで残る** — `feedback_review_patterns.md` DR-10 の
  「構造変更が無償で成立していた担保を黙って外す」に該当する。
- **修正案**: FE-D' に②③と却下 (b)(c)(d) を復元し、削除するのは「MFA 登録・検証・リセットの 3 画面」への
  言及だけに限定する。**「(a) 一般ユーザーと同じレイアウトに混ぜる」は旧 (a) (v2 の 1 next-auth 併置) と
  別物**なので、V-19/V-20 を却下した記録が失われている点も戻すこと。

### 重大 9. §6.11-3 のレート制限対象に削除済みエンドポイントが残り、429 の本数が 3 文書で不一致 (DR-9)

- **箇所**: `docs/design/auth.md:1164` / `docs/design/API/README.md:34` / `同:306` / `docs/design/API/auth-accounts.md:702` / `同:743` / `同:744` / `同:767`
- **事実**:

  | 箇所 | 記述 | 実測 (`auth-accounts.md` §3.7 の表) |
  |---|---|---|
  | `auth.md:1164` | 対象② = `POST /mfa/totp/verify` / **`POST /admin/mfa/totp/verify`** / `PUT /accounts/me/password` / `PUT /accounts/me/email` | 削除済みエンドポイントが残る。かつ `POST /mfa/totp/reset` が入っていない (R-AA-1 の既知の残作業) |
  | `README.md:34` | 「429 を返す **10 本**」だが内訳は「未認証 6 本 + **MFA 検証 2 本** + 認証済み 3 本」 | **6+2+3 = 11 ≠ 10。算術が破綻** |
  | `README.md:306` | 「429 を返す (**11 本**)」 | **旧値のまま** |
  | `auth-accounts.md:702` (A-5 回答) | 「429 を返す **11 本**」 | 旧値 |
  | `auth-accounts.md:492` (§3.7) | 「レート制限の対象 (**計 10 本**)」+ 「**転記先 2 箇所 (README §0 の差分注記と §2.5 の 429 行) を同じ差分で更新した**」 | **この自己申告が事実に反する** (§2.5 = `README.md:306` は未更新) |

  さらに `auth.md:1164` は「**この対象が §6.2 の「ロックを設けない」判断の成立条件である**」と書くが、
  §6.2 の「成立条件」節は本差分で**削除済み**。同型の壊れた参照が `auth.md:858` (§6.2 の成立条件 2) /
  `:859` (§6.2 の成立条件 1) / `:1163` (§6.2 の「初回登録の窓を閉じる」3) にもある。
- **なぜ機械検査をすり抜けたか**: `scripts/check-endpoint-mapping.sh:94` の `rm_429` は
  `grep -oE '429 を返す ?\*{0,2}[0-9]+ ?\*{0,2}本' "$RM" | head -1` で **README の最初のヒットしか見ない**。
  `README.md:306` は括弧付き (`429 を返す (11 本)`) で正規表現に一致せず、そもそも 2 個目は無視される。
  `check-table-counts.sh` が 2026-07-31 に塞いだ「**同一文言の 2 個目に旧値が残る**」の穴が、
  `check-endpoint-mapping.sh` 側に残っている。
- **修正案**: ①`auth.md:1164` から `POST /admin/mfa/totp/verify` を削除し `POST /mfa/totp/reset` を追加する
  ②壊れた §6.2 参照 4 箇所を実在する節へ張り替える ③README の内訳を「未認証 6 + MFA 検証 1 + 認証済み 3」に直す
  ④`check-endpoint-mapping.sh` の `rm_429` を `check-table-counts.sh` の `pick()` と同じ**多重ヒット検査**に変え、
  括弧付きの表記も拾う。**「検査を足した」で終わらせず故障注入で殴る** (rule 05)。

### 重大 10. 403 の本数が 4 箇所で不一致 (実測 8 / 記述 9・10・10)

- **箇所**: `docs/design/API/auth-accounts.md:146` / `同:699` / `docs/design/API/README.md:281` / `同:385`
- **事実**: `make check-endpoint-mapping` の実測は **403 を返す行 = 8** (README §3 総覧の 8 と一致・機械照合済み)。
  - `auth-accounts.md:146` = 「**403 の 9 本は契約内管理者限定 (R-1)**」→ 実測 8 (§2.3.2 の 7 + §2.3.3 の 1)
  - `auth-accounts.md:699` = 「§2.3 の **9 本**が 403」+ 「**SuperAdmin** … の **1 本**」
  - `README.md:281` = 「**同書の 403 は 10 本ある** — 系統と本数の SSOT は同書 §3.1」
  - `README.md:385` = 「**認証・アカウント基盤の 10 本は別勘定** = 契約内管理者限定 **9 本** + **SuperAdmin 限定 1 本**」
- **本番で何が問題か**: `README.md:281` は「**本数の SSOT は同書 §3.1**」と宣言しており、
  その §3.1 系 (`:146`) も誤っている = **SSOT を自称する場所が誤値**。AC-1.4 (401/403/404 の一覧化) の
  受入判定がこの数に依存する。`check-endpoint-mapping.sh` の検査⑥⑦は **9 ドメイン側の 403 (16 本)** と
  総覧表しか見ておらず、この 4 箇所は無検査。
- **修正案**: 4 箇所を 8 に揃えるか、**数を書かず「実測は `make check-endpoint-mapping` が正」**にする (DR-9 の規約)。
  併せて `check-endpoint-mapping.sh` に「auth-accounts の 403 の散文値 ↔ 実測」の照合を追加する。

---

## 中 (Should Fix)

### 中 1. `auth.md` §6.2 の「追加の層」が MFA 前提のまま

`docs/design/auth.md:576`〜`:581`: 「**追加の層 (MFA と併用する)**: ①… ②サインイン試行と **MFA 検証**の成否を
監査記録に残す (O-6) / ③… **MFA を主たる防御とし**、IP 制限は多層防御として併用する」。
MFA は無くなっており、しかも `:552`〜`:555` は「**`POST /admin/signin` の未認証レート制限が唯一の総当たり対策**」と
書いている — **WAF の IP 許可リスト (③) を「唯一」から除外している点も内部矛盾**。
②の「MFA 検証の成否」は AA-D-23 で記録対象から外れた。3 点とも書き直しが要る。

### 中 2. `auth.md` §6.2 の「管理者アカウントの初期投入」行が削除済み節を SSOT として参照

`docs/design/auth.md:533`: 「**投入直後は MFA 未登録**なので、**初回サインイン後に TOTP 登録を強制する**
(登録するまで解除 API に到達できない)。**初期パスワードの出所・窓の閉じ方は下記「初回登録の窓を閉じる」が SSOT**」。
「初回登録の窓を閉じる」節は本差分で削除された。**SSOT が存在しない参照**であり、`make doc-lint` は
節見出しへの参照を検査しないため素通りする。`:1448` (§10.2 R-7 = `operations.md` への申し送り) も
「初回 MFA 登録の手順」「SuperAdmin を 2 名以上」「1 名で MFA デバイスを失った場合の回復手順」を要求したままで、
`operations.md` 側には**是正要求が届いていない**。

### 中 3. §5-12 / §5-13 の帰結が「社内管理者の主防御」を前提にしたまま

`docs/design/auth.md:462`〜`:463`: 「さらに **§6.2 が MFA を社内管理者の主たる防御に据えたため**、
**MFA の総当たりが「5xx の山」として現れ O-4 / O-7 のアラートが意味を失う**」。
§6.2 はもう据えていない。§6.2 の改訂本文 (`:567`〜`:568`) が「§5-12 / §5-13 は取り下げない」と正しく書いているので、
**§5 側の帰結の根拠だけを一般ユーザー側に書き換える**のが正しい。

### 中 4. 監査ログ AA-D-23 の受信漏れ — `auth.md` が消えた `action` の記録を要求し続けている

`docs/design/auth.md:1178`: 「4. **制限の発動とロック操作を観測可能にする** — 429 の発生件数・スパイクと、
**手動ロック / 解除の実行を記録する**。**SSOT は `observability.md`**」。
`observability.md:307` / §4.5.1 は AA-D-23 で `account_locked` / `account_unlocked` を**値域から削除**した。
**読む側 (auth.md の要求) は残り、書く側 (値域) が消えた** = BE-10 の型。
`auth-accounts.md` §5 の R-AA-26 は **observability.md の O-7 アラート**しか宛先にしておらず、
**auth.md §6.11-4 宛ての是正要求が起票されていない**。

### 中 5. 新設の是正要求 R-AA-26 / R-AA-27 / R-AA-28 が受信側に記録されていない

```
$ grep -rn "R-AA-26\|R-AA-27\|R-AA-28" docs/design/ | grep -v auth-accounts.md
(0 件)
```
`feedback_review_patterns.md` DR-8 の運用は「**是正要求を受ける文書は「受信欄」(起票元・ID・状態) を持つこと**」
(実例 = `auth.md` §10.3)。`data-model.md` (R-AA-27 / R-AA-28 の宛先) と `observability.md` (R-AA-26 の宛先) に
受信欄の行が無いため、**実施済みかどうかが起票側の自己申告でしか分からない**。
実際に R-AA-27 は起票側が「実施済み」と書いているが未決定 (重大 4-③)。

### 中 6. `auth-accounts.md` §7.1 (実装リポへの引き渡し) が取り下げ済みの要求を「未対応」として残している

`docs/design/API/auth-accounts.md:865` = 「`+ R-AA-4 account_deletions (新テーブル。DM-Q2 の回答が前提) … 未対応 (条件付き)`」、
`同:890` = 「①**RL-2 (初期スキーマ投入) より前**: **R-AA-17** … と **R-AA-4** (`account_deletions`)」。
同じファイルの `:746` は R-AA-4 を「**取り下げ (2026-08-10)**」としている = **文書内の自己矛盾**。
さらに `:884` の図中「§2.3.2 `DELETE /accounts/{id}` は §3.4.3 の**移管ジョブに依存** (最後)」、
`:891` の「**`§2.3.2 の 10 本` と `§2.4 の 8 本` は同じ増分に入れる**」、
`:905` (§7.2) の「社内管理者ミドルウェア (**v3 は MFA 判定を追加**)」も旧記述。
**§7 は実装リポが最初に読む章**なので、ここが旧版だと差分の意味が全部無効になる。

### 中 7. `settings.md` §4 の A-2 回答が 4 系統 / MFA 必須のまま

`docs/design/API/settings.md:199`: 「**ただし §5 の移植対象には社内管理者認証 (`X-Admin-Token`) を要するものが含まれる** —
ロック解除 / **MFA 登録・検証・リセット** (`auth.md` §6.2 の例外。**社内管理者は MFA 必須**)。
… 認証系統の分離は同 §6.7 の **4 系統**ホワイトリストが担う」。
本差分は同ファイルの `:182`〜`:183` しか触っていない (しかもセル外注記 = 重大 6)。

### 中 8. `auth-accounts.md` の `AdminSignInResult` が存在しない MFA 状態を返す契約のまま

`docs/design/API/auth-accounts.md:255`〜`:262` の `AdminSignInResult` は `"mfa": { "registered": false, "verified": false }` を含み、
`:104` (§2.0) は「**系統** = §6.7 の **4 系統**」、`:216`〜`:220` (§3.2 の末尾) は
「**社内管理者も同じ形**。ただし `required_mfa_type` は持たず**常に TOTP 必須** (P-5) なので、
`mfa.registered` / `mfa.verified` の 2 値で S2 / S3 を判定する」、`:2.6` の row 11 は
「応答に **MFA 状態を追加** (P-5)」と書いている。
**FE の読み手 (`/admin/mfa*` 画面) は削除済み**なので、書き手だけが残った状態 (BE-10 の逆)。
`AA-D-9` の「対象は … の **4 本**」も 3 本になる。

### 中 9. AA-Q9 / AA-Q10 の ID が同一表内で二重定義されている (DR-6 型の名前空間衝突)

```
$ grep -n "| \*\*AA-Q" docs/design/API/auth-accounts.md
841:| **AA-Q9**  | **社内管理者の MFA を将来やるか** …
842:| **AA-Q10** | **手動ロックの実装時期** …
843:| **AA-Q11** | **監査ログを将来拡張するか** …
844:| **AA-Q9**  | **招待リンクとリセットトークンの有効期間** …
845:| **AA-Q10** | **`GET /admin/accounts` の言語絞り込み** …
```
`AA-Q9` / `AA-Q10` が**別の論点に 2 回**振られている。`AA-D-22` の再開入口 (`:213`) と
`auth.md:557` はどちらも「AA-Q9」を参照しており、**どちらの AA-Q9 かが判別できない**。
`feedback_review_patterns.md` DR-6 の「**ID を新設する前に `grep -oE '<接頭辞>-[0-9]+'` で全リポを見る**」に該当。
新設分を `AA-Q12` / `AA-Q13` / `AA-Q14` へ振り直すこと。

---

## 軽微 (Nice to Have)

1. `docs/design/frontend.md:789` の `/admin/admins` 行が **1 列不足** (パイプ 6 本。他の行は 7 本 = 末尾の「増分」列が無い)。表がずれる。
2. `docs/design/auth.md:1300` (§10.1 相当) 「§6.3 の例外テーブル列挙 | **確定** — … (`admin_mfa_configs` を含む)」が旧記述。
3. `docs/design/auth.md:1444` (§10.2 R-3) が「**37 エンドポイントで確定**」「③**社内管理者の MFA フロー**
   (`admin_mfa_configs` のスキーマ・登録/検証/リセット・初回登録強制)」を**実施済み**として記録したまま。
4. `docs/design/data-model.md:193` の括弧書き「(… 同日 `admin_mfa_configs` が (a) に加わった)」が
   削除の経緯を含まない (件数 8 自体は正しく `make check-table-counts` が検算済み)。
   `auth.md:627` は削除まで書けているので、同じ形に揃えると読み手が迷わない。

---

## 本番観点カバレッジ (`08-production-gates.md`)

| ID | 状態 | 箇所 |
|---|---|---|
| A-1 認証方式 | **回答あり (ただし旧決定)** — 重大 1 | `docs/design/auth.md:1251` / `docs/design/API/auth-accounts.md:697` |
| A-2 ロールと適用範囲 | **回答あり (数値・ロールが誤り)** — 重大 1 / 重大 10 | `docs/design/auth.md:1252` / `docs/design/API/auth-accounts.md:699` |
| A-3 テナント境界 | **回答あり (是正要求の状態が旧版)** — 中 6 | `docs/design/API/auth-accounts.md:700` / `docs/design/data-model.md:911` |
| A-4 絞り込みの層 | 回答あり | `docs/design/API/auth-accounts.md:701` |
| A-5 ステータスコード | **回答あり (429 / 403 の本数が不整合)** — 重大 9 / 重大 10 | `docs/design/auth.md:1255` / `docs/design/API/auth-accounts.md:702` |
| A-6 LLM への越境 | 対象外 (理由あり) | `docs/design/API/auth-accounts.md:703` |
| A-7 共有・公開 | 回答あり | `docs/design/API/auth-accounts.md:705` |
| O-1 構造化ログ | 回答あり | `docs/design/API/auth-accounts.md:706` |
| O-2 LLM 計測 | 対象外 (理由あり) | `docs/design/API/auth-accounts.md`(O-2 行) |
| O-3 コスト | 対象外 (理由あり) | 同上 |
| O-4 失敗の可観測性 | 回答あり | `docs/design/API/auth-accounts.md:707` |
| O-5 SSE / 長時間処理 | **回答あり (AA-D-13 の帰結を正しく反映)** | `docs/design/API/auth-accounts.md:708` |
| O-6 監査ログ | **回答あり (縮小の理由と先送り先を明示。ただし受信側が未更新)** — 中 4 / 中 5 | `docs/design/API/auth-accounts.md:709` / `docs/design/observability.md:307` |
| O-7 アラート | 対象外 (先送り。理由あり) | `docs/design/API/auth-accounts.md:711` |
| D-1 / D-3 / D-8 | 対象外 (理由あり。ただし「§2.4 の社内管理者 8 本」が旧値) | `docs/design/API/auth-accounts.md`(D-1/D-3/D-8 行) |
| D-2 CI ゲート | 回答あり | 同 (D-2 行) |
| D-4 マイグレーション | **回答あり (追加要求 4 件の内訳が旧版)** — 中 6 | 同 (D-4 行) |
| D-5 シークレット管理 | 回答あり | 同 (D-5 行) |
| D-6 Managed Agent | 対象外 (理由あり) | 同 (D-6 行) |
| D-7 段階リリース | 参照 | 同 (D-7 行) |

**新たに未回答になった観点**: **A-1 の「失効手段」** — AA-Q10 により手動ロックが本増分から外れた結果、
`auth.md` §6.9 が回答としていた「有効期間 7 日据え置き + 手動ロックによる即時失効」の後半が
**本増分に存在しない**。これは「対象外の理由 + 先送り先」も書かれていないため **DR-2 (無言の省略)** に該当する (重大 3)。

---

## 頻出パターン (`feedback_review_patterns.md`) の確認結果

| # | 該当 | 内容 |
|---|---|---|
| DR-1 出典なしの断定 | **非該当** | 削除の根拠 (「v2 に実体が無い」) は `hassan-v2-backend/router/router.go:231-233` / `:83` / `:205` を挙げており、**抜き取り照合で全て正しい** (§C) |
| DR-2 本番観点の無言の省略 | **該当 (重大 3)** | 即時失効手段の消滅が無記載 |
| DR-3 既存データの不在 | **該当 (重大 4-⑤)** | `accounts.email` のグローバル一意 (`hassan-v2-backend/db/schema.sql:49`) と無効化の共存が未記述 |
| DR-4 PoC 実装のコピー | 非該当 | |
| DR-5 曖昧語による丸投げ | **該当 (重大 4-③)** | 一覧の既定除外が data-model ↔ auth-accounts で循環委譲 |
| DR-6 AC の宙吊り / ID 衝突 | **該当 (中 9)** | `AA-Q9` / `AA-Q10` の二重定義。`make check-traceability` は 86/86 カバーで AC 側は問題なし |
| DR-7 プロトタイプを仕様に | 非該当 | |
| DR-8 修正の波及漏れ | **最重要の該当 (重大 1・2・6・7・9・10 / 中 1〜8)** | §B の grep 出力が証拠 |
| DR-9 件数の転記 | **該当 (重大 9・10 / 重大 7)** | 429 (10/11)・403 (8/9/10)・エンドポイント (33/37)・画面数 (3/4/5)。**機械照合の穴 = `check-endpoint-mapping.sh:94` の `head -1`** |
| DR-10 構造変更が担保を外す | **該当 (重大 7・8)** | FE-D' の巻き添え削除と `ADMIN_MFA_PENDING_PATHS` の宙吊り |
| BE-10 読む側と書く側の対 | **該当 (重大 4-①②・中 4・中 8)** | 無効化列 / ロック監査 / `AdminSignInResult.mfa` |
| BE-2 設定値の SSOT | 非該当 (しきい値の SSOT は `auth.md` §10.2 R-4 に集約されたまま) | |
| FE-2 / FE-3 / FE-4 / FE-5 | 非該当 | |

---

## 良かった点

1. **C-16 (v2 にある操作は落とさない) の検証が正確**。`auth-accounts.md:208`〜`:213` の「削除した 3 本と、その根拠」は
   移植元がユーザー側であることを出典付きで示しており、**参照リポジトリの実測と完全に一致する** (§C)。
   `GET /admin/admins` を「v2 に実体があるため残す」と正しく切り分けた点も含めて、**C-16 への抵触は無い**。
2. **決定の「失うもの」を先送りではなく受け入れるリスクとして明記した**。`auth.md:547`〜`:551` の表
   (パスワード 1 要素・ロックも試行上限も無い) と `auth-accounts.md` §3.7 の「失うもの (先送り先を明示する)」は
   `08-production-gates.md` が求める形になっている。
3. **緩和策の不可侵性を明示した**。「**§6.11-3 の対象から `POST /admin/signin` を外す変更は、本決定を無効化する**」
   (`auth.md:553`〜`:555`) は、DR-10 が求める「代償欄に、いつ何を観測したら見直すかまで書く」に近い良い書き方。
4. **DM-A5 の却下案が具体的**。`data-model.md:424` の (a) `last_locked_at` 流用の却下理由
   (「解除 API が無効化まで解いてしまう」) は実装事故を的確に予見している。
5. **件数の機械照合が正しく連動した**。除外リスト 9 → 8 件が `make check-table-counts` (照合 37 件) を通っており、
   `architecture.md:1055` の「例外 12 → 11」まで連動している。**機械強制の対象に入っていた数値は 1 件も漏れていない**
   — 漏れたのは全て**検算対象外の数値**であり、DR-9 の「機械強制へ移す」方針の有効性を裏付けている。
6. **`observability.md:307` の取り消し線 + 理由 + 再開入口の書式**は、本差分で最も良い書き換え方。
   `settings.md` / `auth.md` の 3 箇所 (重大 6) もこの形にすべき。
7. **`aidlc-docs/schedule-2026q3.md` の R-2 / R-3 / P-5 / R-12 の更新が丁寧**。
   「代わりに生じたリスク」を R-3 に書き換えた形は、決定の反転を計画側へ正しく伝えている。

---

## §A. `make check` の出力 (2026-08-10 実行)

```
[doc-lint] 対象 113 ファイル / エラー 0 件 / 警告 50 件
[traceability] construction-workflow: 25/25 カバー — OK
[traceability] productionization: 86/86 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
[workflow-shell] 検査 61 ブロック / エラー 0 件
[table-counts] 実測: 機能テーブル 42 (個人 34 / 契約 8) / 分類 ①31 ②2 ③1
[table-counts] 実測: 機能テーブル以外 11 (所有者列なし 6 / 所有者列あり 5) / 検査①の除外リスト 8
[table-counts] 照合 37 件 / エラー 0 件
[endpoint-mapping] 実測: auth-accounts.md 33 本 / 9 ドメイン 112 本 / settings.md §5 18 行 / custom tool 8 本 / 403 16 本
[endpoint-mapping] 照合 36 件 / エラー 0 件
[template-sync] 照合 1 組 / エラー 0 件
[monorepo-ci] 実測: ci.yml の job 6 本 / モノレポ機構 MR-x 6 件 / issue テンプレート 3 本
[monorepo-ci] 照合 59 件 / エラー 0 件
```

**エラー 0**。警告 50 件は既存 (ルール文書・過去 review・`design_memo.md` の「TODO」語と、
`data-model.md:1049` / `frontend.md:1239` / `infrastructure.md:562`,`:578` / `llm-migration.md:790` /
`operations.md:802` の未回答 `[Answer]` 6 件) で、本差分由来の新規警告は無い。

**重要**: 本レビューの重大指摘 10 件のうち **`make check` が検出したものは 0 件**である
(件数の不整合はいずれも検算対象外の箇所)。`05-harness.md` の
「**doc-lint が通った ≠ 設計が正しい**」がそのまま当てはまる。

## §B. DR-8 の再検査 grep (証拠)

削除した識別子:

```
$ grep -rn "admin_mfa_configs\|admin/mfa/totp\|admin/admins/{admin_account_id}\|account_deletions\|account-deletions\|mfa_registered\|4 系統" docs/ aidlc-docs/ templates/ scripts/ .claude/
```

`aidlc-docs/reviews/` (過去の review = 履歴) と `aidlc-docs/aidlc-state.md:57` (履歴ログ) を除いた
**現行設計文書の残存ヒット** (更新済みの言及 = 「削除した」「取り下げ」を明示するものを除く):

| ファイル:行 | 残存記述 | 対応する指摘 |
|---|---|---|
| `docs/design/auth.md:533` | 「投入直後は MFA 未登録」「初回登録の窓を閉じるが SSOT」 | 中 2 |
| `docs/design/auth.md:576`〜`:581` | 「MFA と併用する」「MFA 検証の成否」「MFA を主たる防御とし」 | 中 1 |
| `docs/design/auth.md:462`〜`:463` | 「§6.2 が MFA を社内管理者の主たる防御に据えたため」 | 中 3 |
| `docs/design/auth.md:856` | 「**社内管理者側の 4 系統目 (MFA 未検証で可) も同じ規則**で扱う」 | 重大 2 |
| `docs/design/auth.md:858` / `:859` | 「§6.2 の成立条件 2」/「§6.2 の成立条件 1」(節が存在しない) | 重大 9 |
| `docs/design/auth.md:901` | 系統表「(**MFA 検証済みを要求**)」「社内管理者自身の MFA リセット」 | 重大 2 |
| `docs/design/auth.md:1037` | 「MFA 必須化により…SuperAdmin による MFA リセットで回復する」 | 重大 6 |
| `docs/design/auth.md:1163` / `:1164` | 「§6.2 の「初回登録の窓を閉じる」3」/ `POST /admin/mfa/totp/verify` | 重大 9 |
| `docs/design/auth.md:1251` | A-1 回答「社内管理者の MFA 必須化」「`admin_mfa_configs` の新設」 | 重大 1 |
| `docs/design/auth.md:1300` / `:1444` / `:1448` | `admin_mfa_configs` を含む / 37 エンドポイント / 初回 MFA 登録手順 | 軽微 2・3 / 中 2 |
| `docs/design/API/auth-accounts.md:104` | 「系統 = §6.7 の **4 系統**」 | 中 8 |
| `docs/design/API/auth-accounts.md:146` | 「403 の **9 本**」 | 重大 10 |
| `docs/design/API/auth-accounts.md:227` / `:255`〜`:262` | `AdminSignInResult` の `mfa` / `mfa_registered` | 中 8 |
| `docs/design/API/auth-accounts.md:220` (§3.2 末尾) | 「社内管理者も同じ形…常に TOTP 必須 (P-5)」 | 中 8 |
| `docs/design/API/auth-accounts.md:341` (AA-D-9) | 対象「… `POST /admin/mfa/totp/verify` の **4 本**」 | 中 8 |
| `docs/design/API/auth-accounts.md:697`〜`:702` (§4) | 37 本 / 9 本 / 8 本 / SuperAdmin 1 本 / R-AA-4 未対応 / R-AA-18 実施済み / 除外 9 件 / 429 11 本 | 重大 1・9・10 / 中 6 |
| `docs/design/API/auth-accounts.md:865` / `:884` / `:890` / `:891` / `:905` | R-AA-4 未対応 / 移管ジョブに依存 / 10 本・8 本 / MFA 判定を追加 | 中 6 |
| `docs/design/API/README.md:34` / `:281` / `:306` / `:385` | MFA 検証 2 本 / 403 は 10 本 / 429 (11 本) / SuperAdmin 限定 1 本 | 重大 9・10 |
| `docs/design/API/settings.md:199` | 「社内管理者は MFA 必須」「**4 系統**ホワイトリスト」 | 中 7 |
| `docs/design/frontend.md:837` / `:839` / `:868`〜`:869` | `ADMIN_MFA_PENDING_PATHS` = `/admin/mfa*` / 4 本に分ける理由 / MFA 検証済み必須 | 重大 7 |
| `docs/design/frontend.md:930` / `:993` / `:1233` | 「MFA + レート制限 + 監査 + SuperAdmin の複数運用」/「社内管理者の 5 画面」 | 重大 7 |

状態語の grep (`未実装` / `未対応` / `無い` / `必要` / `是正要求` / `新設`) で追加検出したもの:

- `docs/design/API/auth-accounts.md:865` = 「`account_deletions` … **未対応 (条件付き)**」(同ファイル `:746` は「取り下げ」) — 中 6
- `docs/design/API/auth-accounts.md:869` = 「`R-AA-27` … **実施済み**」(実際は未決定) — 重大 4-③
- `docs/design/data-model.md:211` = 「所有者移管は専用の UseCase 1 本だけが行う」(移管しないと決めた) — 重大 5

## §C. 参照リポジトリの抜き取り照合 (7 件。読み取りのみ)

| # | 主張 (設計書) | 照合コマンド | 結果 |
|---|---|---|---|
| 1 | `POST /admin/signin` = `router.go:195`、`:194` は `r.Group("/admin")` | `grep -n 'adminRoute := r.Group\|adminRoute.POST("/signin"' hassan-v2-backend/router/router.go` | **一致** (`194:adminRoute := r.Group("/admin")` / `195:adminRoute.POST("/signin", …)`) |
| 2 | **v2 の `/admin` 配下に MFA エンドポイントが存在しない** (AA-D-22 が C-16 に抵触しない根拠) | `sed -n '194,222p' hassan-v2-backend/router/router.go` | **一致**。`/admin` 配下は signin / me / accounts (管理者 CRUD・unlock) / companies のみ。**`mfa` を含むルートは 1 本も無い** |
| 3 | ユーザー側 TOTP = `router.go:231-233` | `grep -n 'mfaRoute.POST'` | **一致** (`231` generate / `232` verify / `233` reset) |
| 4 | 契約内管理者の MFA リセット = `router.go:83` | 同上 | **一致** (`83:accountsRoute.POST("/mfa/reset", …ResetMemberMfa)`) |
| 5 | `GET /admin/admins` の移植元 = `同:205` / `GET /admin/accounts` = `同:216` / MFA リセット = `同:217` / ロック解除 = `同:211` | `sed -n '204,218p'` | **全て一致** (`205:adminAccountRoute.GET("")` = 管理者一覧 / `211:POST /unlock` / `216:adminCompanyRoute.GET("/accounts")` / `217:POST("/accounts/mfa/reset")`) |
| 6 | `account_mfa_configs.account_id` は `accounts` への FK (AA-D-22 の却下理由) = `db/schema.sql:68-77` | `sed -n '66,78p' hassan-v2-backend/db/schema.sql` | **一致** (`FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE`) |
| 7 | **`accounts` に無効化列が無い / `email` はグローバル一意** (DM-A5 の前提) | `sed -n '30,50p' hassan-v2-backend/db/schema.sql` | **一致 + 追加発見**: `deleted_at` 無しは正しい。**`:49` に `CREATE UNIQUE INDEX unique_accounts_email ON accounts (email)` があり、無効化のみでは email が永久占有される** (重大 4-⑤ の根拠) |

**結論**: 削除の根拠となった事実 (DR-1 の対象) は **7/7 一致**。**C-16 への抵触は無い**。
本レビューの重大指摘は、**事実の誤りではなく波及の欠落**に集中している。

---

## 再レビューの条件

**重大 10 件のうち、少なくとも次の 5 件は再レビュー前に修正が必要**:

- 重大 1 (本番観点の回答表) / 重大 2 (系統表) / 重大 3 (即時失効手段の消滅) /
  重大 4 (`deactivated_at` の帰結) / 重大 5 (CI 検査が必ず落ちる)

修正時は `06-delegation-prompts.md` の「機構を直したら、その機構を語る文書を同じ差分で直す」の手順どおり、
**§B の残存ヒット表を上から順に潰し、grep の出力を証拠として報告に含めること**。
数値 (403 / 429 / エンドポイント本数 / 画面数) は**書き直すのではなく、可能な限り定義元へのリンクか
`make check-*` の出力への参照に置き換える** (DR-9 の規約)。

---

## 是正の反映 (2026-08-10。メインセッションによる修正)

**重大 10 件・中 9 件すべてに対応した**。対象ファイルは §2 と同じ:
`docs/design/auth.md` / `docs/design/API/auth-accounts.md` / `docs/design/data-model.md` /
`docs/design/API/README.md` / `docs/design/API/settings.md` / `docs/design/observability.md` /
`docs/design/frontend.md` / `docs/design/architecture.md` / `aidlc-docs/schedule-2026q3.md`。
加えて `scripts/check-endpoint-mapping.sh` を修正した。

| # | 指摘 | 是正内容 |
|---|---|---|
| 重大 1 | 本番観点の回答表が旧決定 | `auth.md` §7 の A-1 を「社内管理者の認証強度 (AA-D-22 で反転)」へ。`auth-accounts.md` §4 の A-1 / A-2 / A-5 を実測へ (37 → 本数を書かず §2 の見出しを正に / 9 → 8 / 8 → 5 / SuperAdmin の 1 本は消滅と明記) |
| 重大 2 | §6.7 の系統表 (CI 検査の入力) | 社内管理者行を「**MFA 判定なし**」へ。ルート列から「社内管理者自身の MFA リセット」を削除し、実際の 5 本を列挙 |
| 重大 3 | AA-Q13 が auth.md の成立条件を破る | `auth.md` §6.9 に **AA-Q13 の受信欄**を新設。帰結 4 点 (即時遮断手段が無い / 解除専用は代替にならない / DM-A5 と組むと最大 7 日アクセスが続く / FE-D の根拠も失効) と、運用の代替 (署名鍵ローテーション) を明記。§10.2 に **R-8** を起票 |
| 重大 4 | DM-A5 の帰結が未設計 | `data-model.md` §4.2 に **「DM-A5 補足」7 点**を新設 (サインイン拒否 / トークン失効しない / 一覧の既定除外は本書が SSOT / 所有物の参照 / **メールアドレスの永久占有** / 人数上限 / 再有効化 API を作らない)。`auth-accounts.md` に `AU-C-00006`・`include_deactivated` を追加。循環委譲を解消 |
| 重大 5 | 移管前提の CI 検査が残る | §3.4.1 の 2 / §3.3 の検査②-1 / §7.2 の検査 2-1 を「**本増分では移管 UseCase が存在しないことを見る**」へ。§3.4.2 に「31 件を本増分の移管対象と読まない」注記 |
| 重大 6 | 表セル外の注記 | 3 箇所ともセル内へ移動 (パイプ数で確認済み) |
| 重大 7 | `(admin)` 画面数の三重不整合 | `ADMIN_MFA_PENDING_PATHS` を削除 (4 本 → 3 本)、§11.2.3 の照合を `ADMIN_PUBLIC_PATHS` のみへ、§13 の A-2 から画面数を削除し「§11.1 の表が正」へ |
| 重大 8 | FE-D' の巻き添え削除 | 旧 FE-D' を復元し、MFA の 3 画面への言及のみを差し替え。next-auth 2 系統分離・`admin-mutator.ts` 集約・却下案 4 件を維持 |
| 重大 9 | 429 の本数が 3 文書で不一致 | `auth.md` の対象②から削除済みエンドポイントを外し `POST /mfa/totp/reset` を追加。壊れた §6.2 参照 4 箇所を張り替え。README の内訳を 6+1+3 = 10 に。**`check-endpoint-mapping.sh` の `pick()` を多重ヒット検査つきに変更**し、括弧付き表記も拾うようにした |
| 重大 10 | 403 の本数が 4 箇所で不一致 | 4 箇所を実測 8 に統一。**検査⑧ (auth-accounts の 403 散文値 ↔ 実測 / README の 2 箇所) を新設** |
| 中 1〜4 | auth.md §6.2 / §5 の旧前提 | 追加の層・初期投入・§5-12/13 の帰結・§6.11-4 のロック記録要求を是正 |
| 中 5 | 受信欄が無い | `data-model.md` に §7.9、`observability.md` に受信欄を新設 (R-AA-26 / 27 / 28) |
| 中 6 | §7 の引き渡しが旧版 | R-AA-4 を取り下げ表記へ、移管ジョブ依存を削除、ミドルウェアの MFA 判定を「持たない」へ |
| 中 7 | `settings.md` §4 の A-2 | 3 系統 / MFA を課さない へ |
| 中 8 | `AdminSignInResult` の MFA 状態 | `mfa` を削除。AA-D-9 の対象を 4 本 → 3 本へ |
| 中 9 | AA-Q9 / AA-Q10 の二重定義 | 新設分を **AA-Q12 / AA-Q13 / AA-Q14** へ改番し、参照 6 箇所を張り替え |

### 検証

- `make check` — **全ゲート エラー 0 件** (doc-lint 114 ファイル / traceability 111 AC 全カバー / table-counts 37 件 / endpoint-mapping 39 件 / template-sync / monorepo-ci 58 件)
- **`check-endpoint-mapping.sh` の新規検査を故障注入 5 種で確認 — 5/5 検出**:
  ①§3.1 の 403 散文値を 8→9 ②README の「同書の 403 は N 本」 ③README の「別勘定 N 本」
  ④**README §2.5 の括弧付き 429 を旧値へ (`head -1` 素通りの再現)** ⑤§3.7 の 429 自称値
- **多重ヒット検査の副作用を 1 件是正**: `aa_claim` のパターンが広すぎて「レート制限 計 10 本」「403 合計 16 本」まで拾い誤検知したため、**§2 の見出し形に限定**した (パターンは主張ごとに一意にする)

### 残課題

- **FE-Q7 の回答が必要になった** — AA-D-22 / AA-D-23 で「MFA 必須 + 監査記録 + SuperAdmin の複数運用」が消え、
  社内管理者経路の担保が**レート制限 1 本だけ**になった。IP 制限を諦める暫定既定のまま進めるかはユーザー判断
- **`operations.md` が R-8 (即時遮断手段が無いことの運用手順) を未受信** — 次の増分で受信欄を作る

### 残課題の解消 (2026-08-10。ユーザー決定)

- **FE-Q7 = ③ で確定** — 「一旦管理者 EP の保護はスキップ」。`docs/design/frontend.md` §16.2 の `[Answer]` に
  受け入れるリスクと再検討の契機を記録し、`docs/design/auth.md` §6.2 に決定ブロックを、
  `docs/design/infrastructure.md` の INF-L に「管理者経路の IP 許可リストは本増分では入れない」を追記した。
  **`POST /admin/signin` のレート制限と `observability.md` §4.6 の AL-7 は外してはいけない** (外すと防御がゼロになる)
  ことを両書に明記している。**残るのは `operations.md` の R-8 未受信のみ**

### 追加是正 (2026-08-12。設定機能の増分の食い違い)

**発見**: `default_asset_visibility` / `/settings/workspace` の増分が 4 箇所で食い違っていた。
**SSOT は [../../../docs/design/auth.md](../../../docs/design/auth.md) §6.12 (c)** で、
**C-16 の適用により読む側・書く側とも増分 1** と 2026-07-31 に確定済みだった。
`settings.md` と `frontend.md` がその改訂を受け取っておらず、増分 2 の旧記述を保持していた (DR-8 の受信漏れ)。

| ファイル | 旧記述 | 是正 |
|---|---|---|
| `docs/design/API/settings.md` §3 の増分列 | `GET`/`PUT /settings/workspace` = **増分 2** | **増分 1** |
| 同 §3.2 の増分表 | 「増分 1 では `/settings/workspace` 自体を提供しない」 | 増分 1 で提供。auth.md §6.12 (c) が SSOT と明記 |
| 同 §3.2 の却下 | 「増分 1 で作るのは却下 (適用先が無い)」 | 「**増分 2 に残すのを却下**」へ反転。読む側が増分 1 に引き上げられたため |
| 同 §7.1 の ST-Q8 `[Answer]` | 「(a) 増分 2 へ後ろ倒し」 | **撤回**を追記。後ろ倒しのままだと v2 の `POST /sharing-settings` が増分 1 で失われる (C-16 違反) |
| `docs/design/frontend.md` §0 | 「`/settings/workspace` は増分 2 へ」 | 増分 1 |

**帰結**: スケジュールの **P-7 が解決**し、**B-9 設定の範囲が 5 本に確定**した
(通知 2 / 活動ログ・利用状況 2 / ワークスペース設定 1〜2)。

**検証**: `make check` 全ゲート エラー 0 件。
