# API: 設定 (+ 認証・アカウント基盤の移植範囲)

> 共通規約 (認証・レスポンス形・エラー・ページネーション・ステータスコード) の SSOT: [README.md](README.md)
> 本ファイルが回答する本番観点: **A-2, A-4, A-5, O-3 (部分), O-6** / 受入基準: **AC-1.1, AC-1.4**

## 1. 対応する画面と参照する既存実装

| 区分 | 所在 |
|---|---|
| プロトタイプ | `admin` ビュー — `../../prototype/hassan_agent_prototype_v2.html` の HTML `:7629-7672` / JS `:13677-13697` + `ADMIN_SECTIONS` (`:14931-14986`) (2026-07-30 更新版の実測) |
| セクション | **更新版は `profile` / `members` / `audit` / `help` (+ `logout`) の 5 種のみ** (`:7641-7661` / `ADMIN_SECTIONS` のキー `:14931-14986`)。**旧版にあった `workspace` / `plan` セクションは消滅した** (「ワークスペース」「タイムゾーン」「データポリシー」「プラン変更」の文言 0 件) — 設計への影響は §7.1 (ST-Q8 / ST-Q9) |
| v2 の既存実装 | `hassan-v2-backend/controller/account.go` / `company.go` / `contract.go` / `company_mission.go` / `sharing_settings.go` / `event_logs.go` / `mfa.go` |
| v2 の既存ルート | `hassan-v2-backend/router/router.go:61-103` (contracts / accounts / companies / company-mission)、`:188-189` (sharing-settings)、`:229-233` (mfa)、`:235-237` (event_logs) |
| v2 の既存テーブル | `accounts` / `companies` / `contracts` / `auth_roles` / `activity_logs` (`hassan-v2-backend/db/schema.sql:482-489`) / `event_logs` (`同:586-597`) / `sharing_settings` (`同:491-499`) |

**重要な事実**: プロトタイプの `admin` ビューは
**各セクションのボタン (保存・招待・CSV 出力等) が配線なしの静的 HTML** である
(`ADMIN_SECTIONS` は文字列テンプレートを返すだけで、ボタンにイベントハンドラを登録していない — `:14931` 以降。
唯一の例外は audit の**月セレクタ**で、月次集計表の切替だけは動作する — `:13687-13697` / `renderActivityAnalysis` `:14828-14845`)。
したがって**このビューから確定できる仕様は「どの情報を表示するか」までであり、
更新系の挙動はプロトタイプから読み取れない** (DR-7)。

> **v4 プロトタイプ (2026-08-23) の設定画面について**: `../../prototype/hassan_agent_prototype_v4.html` は
> 設定にセクションを追加している (セキュリティ / 組織管理 / 多要素認証 / **評価基準** / メンバー管理 / 利用状況分析)。
> このうち増分 proto-v4 が扱うのは**評価基準の先送り (§2 の行) だけ**であり、
> 他セクションの採否は本増分の対象外 ([requirements-proto-v4.md](../../../aidlc-docs/inception/productionization/requirements-proto-v4.md) §1.2 の PV-DF6)。
> 対象外 = 採用しないではなく、設定ドメインの増分で改めて判断する。

---

## 2. セクション別の判断 (v3 で移植 / v3 新設 / 対象外)

> **D-ST-1' (2026-07-30) で「v2 再利用」は無くなった**。認証・アカウント系は **v3 で移植**する。
> 下表の「移植元」列は **v2 のどの実装を移植元にするか**を示すもので、
> 「v2 の API を FE が叩き続ける」という意味ではない。移植対象の一覧は §5、
> 認証・認可の規約は [../auth.md](../auth.md)、**入出力仕様は [auth-accounts.md](auth-accounts.md) が確定** (2026-07-31。同 §10.2 R-3 は実施済み)。

| セクション | 項目 | 判断 | 根拠 |
|---|---|---|---|
| **profile** | 氏名・所属・役割 | **v3 で移植** (§5) | 移植元: `GET /accounts/me` — `hassan-v2-backend/router/router.go:66`、`PUT /accounts` — `同:69` |
| | メールアドレス (プロトタイプでは readonly) | **v3 で移植** (§5) | 移植元: `PUT /accounts/email` — `同:71`。変更フローは検証メール等を含む |
| | パスワード | **v3 で移植** (§5) | 移植元: `PUT /accounts/password` — `同:72` |
| | アイコン | **v3 で移植** (§5) | 移植元: `POST` / `DELETE /accounts/icon` — `同:73-74`。S3 アップロード実装は `hassan-v2-backend/aws/s3.go:62` |
| | **通知設定** (アイデア発散の完了通知・週次サマリ) | **v3 新設** (`GET` / `PUT /settings/notifications`) | **v2 に相当機能が無い** (`accounts` に通知列なし、通知系ルートなし)。通知の対象イベント (発散完了) が v3 の機能であるため v3 が持つ |
| **workspace** (**2026-07-30 更新版プロトタイプでセクション消滅 — ST-Q8**) | ワークスペース名・組織 ID | **v3 で移植** (§5。**プロトタイプから消えても v2 既存機能の移植としての根拠は残る**) | 移植元: `GET /companies` — `同:93`、`PUT /companies` — `同:96` |
| | **タイムゾーン** | **保留** — `/settings/workspace` 自体は増分 1 ([../auth.md](../auth.md) §6.12 (c))。`timezone` 項目は **ST-Q1 の結論が「サーバ側で使う」の場合のみ**増分 2 で追加 | v2 に相当列が無い。**要確認 ST-Q1** (サーバ側で使う必要があるのか。更新版プロトタイプに選択 UI 自体が無い) |
| | **データポリシー** (入力データの学習利用) | **対象外 (先送り)** — **更新版プロトタイプから UI も消滅し、対象外の判断が補強された** (ST-Q2) | 旧プロトタイプの選択肢 (「組織内モデルのみ」/「共通モデルにも活用」) が**実装可能な挙動として定義されていない**。LLM 提供者との契約・実装の両面で未確定 (ST-Q2) |
| | **アセット可視性の既定** | **v3 新設 (増分 1)** (**2026-07-31 に C-16 で前倒し** — v2 の `POST /sharing-settings` は 1 スイッチで契約全体を切り替えられたため、既定値が無いと操作の後退になる。[../auth.md](../auth.md) §6.12 の 3。**3 カテゴリ (テーマ / アセット / アイデア) へ拡張する**) | v2 に `sharing_settings` (カテゴリ単位の ON/OFF。`POST /sharing-settings` — `同:189`) があるが、**GET が無く現在値を読めない**。v3 のアセット/テーマは v3 の DB にあるため v3 側で持つ (§4 D-ST-3)。**適用先 ([assets.md](assets.md) の `visibility`) と同じ増分 2 に揃える** — BE-10 (読む側と書く側を対で設計する) への対応 |
| **members** | メンバー一覧・権限バッジ・**ロック状態** | **v3 で移植** (§5) | 移植元: `GET /accounts` = 契約内一覧 — `同:65`。**ロック状態 (`last_locked_at`) を返すこと** — v2 の `ListAccountsForAdmin` も返している (`hassan-v2-backend/db/queries/account.sql:98`)。解除操作に到達するための読み側 ([../auth.md](../auth.md) §6.9) |
| | 招待 | **v3 で移植** (§5) | 移植元: `POST /accounts/signup-links` — `同:77`。**招待リンクの生成は `crypto/rand`** ([../auth.md](../auth.md) §6.10) |
| | メンバー編集 (権限変更) | **v3 で移植** (§5。契約内管理者のみ) | 移植元: `PUT /accounts/admin` — `同:70`。`hassan-v2-backend/controller/account.go:421-426` が `AuthRoleID.IsAdmin()` で判定。**最後の管理者の降格拒否**も移植する (`usecase/account/update_account_by_admin.go:64`) |
| | メンバー削除・**ロック / 解除**・MFA リセット | **v3 で移植 + 新設** (§5) | 移植元: `DELETE /accounts/:id` — `同:81`、`POST /accounts/unlock` — `同:82`、`POST /accounts/mfa/reset` — `同:83`。**v2 の解除 API は email 指定でテナント検証が無い** ([../auth.md](../auth.md) §5-11) ため、v3 は **`account_id` 指定 + `contract_id` 検証**にする。**手動ロック API は v3 で新設** (v2 に無い)、**社内管理者による解除**も持つ (同 §6.9 / §6.2) |
| | **CSV 出力** | **対象外 (要確認 ST-Q3)** | 配線なしのダミー。v2 の CSV 出力は社内管理者向け (`GET /admin/companies/clients/csv`) で、契約内ユーザー向けではない |
| **audit** | メトリクス — **更新版プロトタイプで表示形が変わった**: 旧版の 4 指標 (生成アイデア・アクティブテーマ・アセット登録・アクティブ率) は消え、**月選択 + メンバー × 活動種別 6 種 (テーマ作成 / アイデア発散 / 企画書ドラフト / ナレッジチャット / アセット登録 / コメント) の月次クロス集計表 + CSV 出力 (配線なし)** になった (`ACTIVITY_TYPES`/`ACTIVITY_MONTHS` `:14771`〜、表描画 `:14852-14925`、CSV ボタン `:14840`) | **v3 新設** (`GET /usage-summary`) — **返す指標の形は ST-Q9 で再確定** | **集計対象データ (themes / assets / ideas) が v3 の DB にある**ため v2 では算出できない (§4 D-ST-4) |
| | アクティビティログ | **v3 新設** (`GET /activity-logs`) | v2 に `activity_logs` テーブルはある (`hassan-v2-backend/db/schema.sql:482-489`) が、**参照する API が無い** (`hassan-v2-backend/router/router.go` に該当ルートなし)。O-6 の回答として v3 が持つ |
| **plan** (**2026-07-30 更新版プロトタイプでセクション消滅 — 対象外の判断が補強された**) | プラン・使用量 (AI 生成回数等) | **対象外 (先送り)** | **C-12 によりコスト上限を設けない**方針のため、ユーザー向けの使用量制限表示は要件になっていない。課金は v2 でも API 化されていない (社内管理者向け `GET /admin/companies/usage_status/csv` のみ)。O-3 の可視化は**運用者向け**として [../observability.md](../observability.md) §4.2 / §6.1 で扱う (§4 D-ST-5) |
| **評価基準** (**v4 プロトタイプ (2026-08-23) で新設されたセクション** — `../../prototype/hassan_agent_prototype_v4.html` の `_evalCriteriaState` `:17061`〜) | 評価軸の重み・サブ基準・数値アンカー・判定ランク条件の閲覧/編集 + 変更履歴 | **最小形 (DB 保存 + `GET/PUT /settings/eval-criteria`) を増分 1 へ前倒し** (**2026-08-24 ユーザー決定 PV-D5**。旧判断「増分 2 へ先送り」のうち①契約ごとの編集 ③CRUD の 2 項目)。**②変更履歴のみ増分 2 のまま** (履歴テーブルと「過去の基準で採点された評価」の関係が未設計 — [ideas.md](ideas.md) §6.8 の②)。`entity/idea` の Go 定数は**契約行が無い場合の既定値の SSOT** へ縮小 ([ideas.md](ideas.md) §6.3 / AC-PV-8.1〜8.4)。仕様は §3 / §3.1 / §3.2 / §4 D-ST-8 | ユーザー決定 2026-08-24 ([requirements-proto-v4.md](../../../aidlc-docs/inception/productionization/requirements-proto-v4.md) PV-D5。旧判断は同 PV-D1 / PV-D4)。旧先送り理由のうち「管理者のみ編集可のロール粒度が無い」は実装リポ #52 の `IsAdmin()` 導入で解消。起票: 実装リポ #110 |
| **help** | 外部リンク | **API 不要** | 静的リンク |
| **logout** | ログアウト | **API 不要** | **FE のトークン破棄のみ**。JWT は 7 日で失効する ([../auth.md](../auth.md) §6.9 で据え置き確定)。**サーバ側の即時失効は手動ロック API が担う** (同 §6.9) ため、logout 用の revoke エンドポイントは設けない。**ST-Q4 は決着済み** |

---

## 3. エンドポイント一覧 (v3 新設分)

すべて認証必須 (`X-Token`)。**増分は「増分」列のとおり** (2026-07-30 の ST-Q8 回答で
`/settings/workspace` は増分 1 — [../auth.md](../auth.md) §6.12 (c) が SSOT)。
共通の 400 / 401 / 500 は [README.md](README.md) §2.5 に従い、本表では**固有のコードのみ**挙げる。

| メソッド | パス | 概要 | スコープ | 主なリクエスト / レスポンス項目 (暫定) | 固有ステータス | 増分 |
|---|---|---|---|---|---|---|
| GET | `/settings/notifications` | 通知設定取得 | 個人 | R: `{diverge_completed: "email_and_slack"\|"email"\|"none", weekly_summary: "monday_09"\|"none"}` | 200 | 1 |
| PUT | `/settings/notifications` | 通知設定更新 | 個人 | B: 上と同じ項目 — R: 同じ | 200 / **400** (列挙外の値) | 1 |
| GET | `/settings/workspace` | v3 側ワークスペース設定取得 | 契約 | R: `{default_asset_visibility: "private"\|"contract"}` (**`timezone` は ST-Q1 の結論が「使う」の場合のみ追加**) | 200 | 1 |
| PUT | `/settings/workspace` | 同 更新 | 契約 | B: 上と同じ項目 — R: 同じ | 200 / **403** (契約内管理者以外) / **400** (列挙外の値) | 1 |
| GET | `/usage-summary` | 契約の利用量集計 (**月 × メンバー × 活動種別のクロス集計** — ST-Q9=a) | 契約 | Q: `from_month` / `to_month` (`YYYY-MM`) — R: `{months:[...], members:[{account_id, name}], counts:{<action>: {<month>: {<account_id>: n}}}}`。**活動種別の値域は [../observability.md](../observability.md) §4.5.1 の**「利用状況の集計対象」行の 6 種のみ** (同表の認証・メンバー設定系の action はクロス集計の軸に含めない。D-ST-6 と同じ委譲)。集計元は `audit_logs` ([../data-model.md](../data-model.md) §4.10) | 200 / **403** (契約内管理者以外) / **400** (月形式・期間) | 1 |
| GET | `/activity-logs` | 契約の活動ログ一覧 | 契約 | Q: `from` / `to` / `account_id` (**自契約のメンバーのみ**) / `limit` / `offset` — R: `{items:[{occurred_at, actor:{account_id, name}, action, target}], total_count}` | 200 / **403** (契約内管理者以外) / **400** (契約外の `account_id`) | 1 |
| GET | `/settings/eval-criteria` | 契約の評価基準取得 (**2026-08-24 前倒し — PV-D5**) | 契約 | R: `{axes:[{id, name, weight, subs:[{id, name, points, note}], anchors:[{score, label, sam_min?, cagr_min?, profit_min?, detail?}]}], verdicts:[{rank, label, min_composite?, min_axis?, weak_axis_below?, max_weak_axes?, feasibility_below?}], criteria_version}` (**2026-08-24 に実装 (#112) で確定** — 旧暫定の verdicts 自由文 `cond` は撤回: D-ST-8 ⑤の「閾値は 0.0〜10.0 尺度」の検証が自由文では成立しないため、**ランクごとに固定の閾値フィールドを持つ構造化形**にした。ランク別の必須/禁止フィールドは [ideas.md](ideas.md) §6.3.3 の条件表と 1:1。サブ基準にも固定 `id` を持つ — 評価出力のキーとして C-6 が参照するため契約ごとに変えられない)。**行なしは 200 + 既定基準** (`entity/idea` の Go 定数。[ideas.md](ideas.md) §6.3) | 200 | 1 |
| PUT | `/settings/eval-criteria` | 同 更新 | 契約 | B: 上と同じ項目 (`criteria_version` は送らない — サーバが更新) — R: 同じ。**upsert** (行なしは作成)。バリデーションは §4 D-ST-8 | 200 / **403** (契約内管理者以外) / **400** (軸 3 本固定・重み合計 100・値域違反) | 1 |

### 3.1 契約内管理者限定の 4 本 (A-2 / [README.md](README.md) §2.2 の **R-1**)

`PUT /settings/workspace` / `GET /usage-summary` / `GET /activity-logs` /
`PUT /settings/eval-criteria` (**2026-08-24 追加 — PV-D5**。v4 プロトタイプのコメント
「組織で共有・管理者のみ編集可」`:17060` を要件として採る) は
**契約内管理者のみ**が実行できる。判定は v2 の前例に倣う:

```
authAccount := auth.GetAuthenticatedAccount(c)   // Controller 層
if !authAccount.AuthRoleID.IsAdmin() { 403 }     // 契約内ロールの判定
```

出典: `hassan-v2-backend/controller/event_logs.go:47-50` が同じ判定で
`forbidden(ctx, apperror.RequestUserNotAdmin())` を返している。
ロール定義は `hassan-v2-backend/entity/auth_role.go:7-10` (1 = 管理者 / 2 = メンバー)。

これが [../auth.md](../auth.md) §9 の **Q-A2** に対する本ディレクトリからの回答である
(「契約内管理者/メンバー区別を v3 で使うか」→ **使う。ただし用途はこの 4 本に限る**。
2026-08-24 に `PUT /settings/eval-criteria` を追加して 3 本 → 4 本)。

**403 の全体像**: 本ディレクトリの 403 は合計 **12 本** — 本節の 4 本 (R-1 = 契約内ロール) と
[idea-boards.md](idea-boards.md) §3.1 の 8 本 (R-2 = リソース単位ロール)。
**`AuthRoleUser` のみという A-2 の方針と矛盾しない** (認証ロールは全員同じで、
その上に契約内ロールとリソース単位ロールが乗る — [README.md](README.md) §2.2)。

- **却下**: 全員に開放する案 — 活動ログは契約内の他メンバーの操作履歴を含み、
  利用量サマリは組織の活動状況を示す。一般メンバーに開く要件が確認されていない
- **却下**: 社内管理者 (`X-Admin-Token`) 限定にする案 — プロトタイプは**契約ユーザー自身の設定画面**に
  この情報を置いており ([../auth.md](../auth.md) §6.2 のとおり本増分は `AuthRoleUser` のみが対象)

### 3.2 増分の対応 (BE-10: 読む側と書く側を対で設計する)

`default_asset_visibility` は**設定を書く側**であり、**それを適用する読む側**は
[assets.md](assets.md) の `visibility` と `scope=contract` である。
**片方だけを実装すると「設定できるが何も起きない」状態になる**ため、増分を揃える。

| 増分 | 書く側 (本ファイル) | 読む側 ([assets.md](assets.md) / [themes.md](themes.md)) |
|---|---|---|
| **1** | **`GET/PUT /settings/workspace` を提供し `default_*_visibility` (3 カテゴリ) を受け付ける** | `PUT /assets/{asset_id}` / `PUT /themes/{theme_id}/visibility` で変更可、`scope=contract` が有効 |

**増分は 1 で確定している** ([../auth.md](../auth.md) §6.12 (c) が SSOT)。
同節は **C-16 (v2 に存在する仕様は原則すべて v3 に引き継ぐ)** の適用として
「契約内共有の読み取り (`scope=contract`) と `visibility` の書き込みは増分 1 に含める」を決めており、
**書く側だけを増分 2 に残すと v2 の `POST /sharing-settings` (契約単位で共有を ON/OFF する操作) が
増分 1 で失われる**。読む側・書く側とも増分 1 に揃えることで BE-10 は起きない。

**移行**: v2 の `sharing_settings` の既存値は、**設定値としてではなく既存リソースの `visibility` 初期値**
として使う ([themes.md](themes.md) §3.2 TM-1 / [assets.md](assets.md) §3.2 AS-M1)。
**`default_asset_visibility` の初期値も同じ値から決める** (契約が共有 ON だった → `contract`)。
これで「既存アセットは共有されているのに、新規作成すると非公開になる」という不整合を避ける。

- **却下**: `default_asset_visibility` を増分 2 に残す — 適用先 (読む側) が
  [../auth.md](../auth.md) §6.12 (c) で増分 1 に引き上げられており、**書く側だけが遅れると
  v2 の「契約単位で共有を切り替える」操作が増分 1 で失われる** (C-16 違反)
- **却下**: v2 の `sharing_settings` を v3 の設定としてそのまま引き継ぎ、契約 × カテゴリで判定し続ける —
  per-resource の可視性を表現できない ([themes.md](themes.md) D-TH-3 / [assets.md](assets.md) D-AS-12)。
  **v2 の操作は「契約単位の既定値 3 カテゴリ」として引き継がれる** ([../auth.md](../auth.md) §6.12 (a))

**評価基準 (`/settings/eval-criteria`) の読む側** (2026-08-24 追加 — PV-D5 / AC-PV-8.4):
書く側は本ファイル、**読む側は評価実装 (C-6。[ideas.md](ideas.md) §6.3 / §6.8)** — 評価ジョブが
①契約行があればそれを ②無ければ `entity/idea` の Go 定数の既定を、
**重み・配点・閾値を引数で受け取る純粋関数** (AC-PV-7.2 の①) に渡して採点する (キャッシュなし。同③)。
**書く側単独のマージでは採点に反映されない** (BE-10。実装リポ #110 の非スコープ節と同じ構図 —
読む側の接続は C-6 の issue が担う)。

---

## 4. 設計判断

| # | 論点 | 採用案 | 却下案と理由 |
|---|---|---|---|
| D-ST-1 | **アカウント・会社・契約系 API の提供元** | ~~v2 の既存 API を再利用し、v3 に複製しない~~ → **反転。v3 で実装する** (ユーザー決定 2026-07-30。反転の根拠は下の D-ST-1' ) | (b) v3 が v2 の DB を直接読み書きする: サービス境界を跨いだ DB 共有になり、**どちらのマイグレーションが正か決められない** (D-4)。**この却下は維持する**。(c) v3 に BFF 的プロキシを置いて v2 へ中継: FE の呼び先が 1 つになる利点はあるが、認証トークンの再送とエラー形式の二重変換が入り、障害時の切り分けが 1 段増える。**この却下も維持する** |
| **D-ST-1'** | **D-ST-1 を反転した理由** (2026-07-30) | **認証系 API を v3 で実装する** (`signin` / `signup` / パスワードリセット / MFA / メンバー管理 / 会社情報 + **手動ロック API**) | **元の採用案 (v2 再利用) を維持すると、[../auth.md](../auth.md) が確定させたセキュリティ対策のすべてに実装先が無くなる** — 署名鍵の新規発行 (同 §6.8。v2 の鍵は git 追跡下で露出)・**トークン漏洩時の失効手段である手動ロック API** (同 §6.9)・リセットトークンの `crypto/rand` 化 (同 §6.10)・応答マスクとレート制限 (同 §6.11)。**v2 側は改修しない方針** (同 §9.3 Q-A3) と組み合わせると、v2 再利用は「対策を実装しない」と同義になる。**残る代償**: 元の却下理由 (a) が指摘していた「同一の `accounts` を 2 つのサービスが書く」問題は消えておらず、**併用期間中のアカウント基盤の二重化**として `docs/design/data-model.md` / 移行設計 (AC-3.5) が扱う ([../auth.md](../auth.md) §10.2 R-1) |
| D-ST-2 | **通知設定の置き場** | **v3 が持つ** (`/settings/notifications`) | (a) v2 の `accounts` に列を足す: v2 のスキーマ変更が必要で、通知対象イベント (アイデア発散の完了) は v3 の機能。**v3 の機能の設定を v2 が持つと、v3 だけで完結する変更ができなくなる** |
| D-ST-3 | **アセット可視性の既定値** | **v3 が持つ** (`/settings/workspace` の `default_*_visibility`。**テーマ / アセット / アイデアの 3 カテゴリ** = v2 の `sharing_settings` の 3 カテゴリと 1:1)。**増分 1** で有効化 (**2026-07-31 に C-16 で前倒し**)し、適用先 ([assets.md](assets.md) の `visibility`) と同じ増分に揃える (§3.2) | (a) v2 の `sharing_settings` を使う (`POST /sharing-settings` — `hassan-v2-backend/router/router.go:189`): **v3 のアセットは v3 の DB にある**ため、v2 の設定を v3 が読むには DB 共有か API 呼び出しが必要になる (D-ST-1 の却下理由と同じ)。加えて**v2 には GET が無く現在値を読めない**ため、そのままでは設定画面に表示できない。**ただし v2 の既存設定値 (契約ごとの共有 ON/OFF) は移行対象**であり、切替時に v3 の既定値へ写す必要がある (ST-Q5) |
| D-ST-4 | **利用量サマリの提供元** | **v3 が新設** (`GET /usage-summary`) | (a) v2 の `GET /event_logs/analytics` (`hassan-v2-backend/router/router.go:236`) を再利用: **集計対象 (生成アイデア数・アクティブテーマ数・アセット登録数) が v3 の DB にある**ため、v2 では算出できない。(b) v2 の `event_logs` に v3 からイベントを書き込む: 書き込みのために DB 共有か API 追加が必要で D-ST-1 に反する |
| D-ST-5 | **プラン・課金の扱い** | **本増分の対象外** (先送り) | (a) 使用量表示だけ作る: C-12 (上限なし) により**ユーザーが見て行動を変える必要がない**情報になり、O-3 の可視化は運用者向けで足りる。(b) プロトタイプのプラン表示をそのまま実装: 「Business プラン月額」「AI 生成回数」は静的モックで、課金基盤 (請求・プラン変更) の設計が存在しない。**先送り先**: 課金要件が確定した増分 |
| D-ST-6 | **活動ログの記録項目** | **API の形 (`occurred_at` / `actor` / `action` / `target`) を本ファイルで決め、記録する `action` の値域は [../observability.md](../observability.md) §4.5 に委ねる** | (a) 値域まで本ファイルで決める: 監査対象イベントは全ドメイン横断で決まる (O-6) ため、API 設計ファイルに閉じると各ドメインの追加のたびに本ファイルを直すことになる。(b) v2 の `activity_log_type` enum をそのまま使う: v3 の機能 (会話型アイデア創出・ナレッジ) のイベントが値域に無い |
| D-ST-7 | **FE から見た 2 系統の API** | ~~FE は v2 API (認証・アカウント) と v3 API (機能) の 2 つのベース URL を持つ~~ → **D-ST-1' により反転。認証・アカウントも v3 が提供するため、v3 の API だけで完結する**。**ただし併用期間中は未移植の v2 機能があるため 2 系統が残る** — 変換層 (エラー形式・命名) を API 境界の 1 箇所に閉じる方針と `orval` の生成先分離は**そのまま有効** | (b) 変換層を作らず両形式をコンポーネントまで持ち込む: FE-2 (snake_case 漏れ) と同じ構造の問題になる。**併用期間中の追加論点**: v2 と v3 でトークンが別になるため (`../auth.md` §9.3 Q-A1)、**FE は両系統のトークンを保持する** ([../auth.md](../auth.md) §10.2 R-2) |
| **D-ST-8** | **契約単位の評価基準の保存形式** (2026-08-24 新設 — PV-D5 / AC-PV-8.2 / AC-PV-8.3) | **`eval_criteria_settings` (所有者列 = `contract_id` = PK) に jsonb 1 列 (`criteria`) + `criteria_version text NOT NULL` + `updated_by` / `updated_at` で持つ**。`criteria` の形は §3 の GET レスポンス (v4 の `_evalCriteriaState` の snake_case 化。`history` を除く)。**構造の検証は `entity` の純粋関数**で行う — ①軸 3 本固定 (id は `market_appeal` / `advantage` / `feasibility` — [ideas.md](ideas.md) §6.3.1 と同一) ②重みの合計 = 100 ③サブ基準は各軸 3 つ・配点合計 10 ④アンカーは 5 段 (score 10/8/6/4/2) ⑤判定ランクは 4 段 (A/B+/B/C)・閾値は 0.0〜10.0 尺度。**PUT 成功のたびに `criteria_version` を更新** (値は「契約 ID + 単調増加の版」を表す形式。`idea_evaluations.criteria_version` が過去の採点の基準を指せる — [ideas.md](ideas.md) §6.8 AC-PV-7.2 の②) | (a) 軸・サブ基準・アンカーを正規化テーブル群で持つ: テーブルが 4 つ以上増え、増分 1 では軸数・構造が固定 (部分更新・履歴・構造の可変性の要件は増分 2 の履歴と同時にしか生じない)。jsonb 1 列なら構造変更が増分 2 で正規化する余地も残る。(b) 重みだけを列で持つ: アンカー・判定条件が持てず、v4 の編集 UI (アンカー数値・判定条件) を受けられない。(c) `criteria_version` を持たない: [ideas.md](ideas.md) §6.8 の②の却下 (a) と同じ — 基準を変えた瞬間に過去のスコアと比較できなくなる。**代償 (履歴を増分 2 に送ったことによる)**: 変更の痕跡は `updated_by` / `updated_at` の**最終 1 件のみ**で「誰がいつ何を変えたか」の履歴は残らない。監査 `action` ([../observability.md](../observability.md) §4.5.1) への「評価基準の変更」の追加は #34/#71 と同枠の申し送り (v2 の共有設定変更の監査と同じ扱い) |

### 4.1 この構成の代償 (明示しておく事項)

> **D-ST-1' (2026-07-30) により下表の前提が変わった**。認証系が v3 に入るため、
> 「v2 の API を叩き続ける」ことに由来する代償の一部は**解消**する。現状を反映した内容に更新済み。

| 代償 | 内容 | 対処 |
|---|---|---|
| CORS | **解消**。認証系も v3 が提供するため、**v2 の許可オリジン (`hassan-v2-backend/internal/corsutil/origin.go` の `productionWebOrigins`) に Vercel ドメインを追加する v2 側の変更は不要**になった (v2 を改修しない方針と整合) | [README.md](README.md) §5 の API-Q2 を「不要」として閉じる |
| エラー形式 | **併用期間のみ残る**。v2 は `{"code","msg"}`、v3 は `{"code","message","request_id"}` ([README.md](README.md) D-API-6)。未移植の v2 機能を FE が叩く間だけ変換層が必要 | D-ST-7 の変換層 |
| 404/403 の本文 | 同上 (併用期間のみ)。v2 の `notFound` / `forbidden` は**ボディ無し** (`hassan-v2-backend/controller/controller.go:42-63`)、v3 は本文あり | 同上 |
| JWT 鍵 | **確定**: **共有しない**。v3 は新規発行する ([../auth.md](../auth.md) §9.3 Q-A1。v2 の鍵は git 追跡下で露出しており、v2 を改修しない方針ではローテーションもできないため)。**帰結として併用期間中は v2 と v3 でトークンが別になり、FE が両系統のトークンを保持する** | [../auth.md](../auth.md) §10.2 R-2 (FE 設計) |
| **アカウント基盤の二重化** | **新規の代償**。v3 が認証系を持つことで、併用期間中は `accounts` 相当が v2 と v3 の両方に存在する。**パスワード変更・MFA 設定・ロック状態の整合**をどう保つかが未設計 (D-ST-1 の元の却下理由 (a) が指す問題) | `docs/design/data-model.md` / 移行設計 (AC-3.5)。[../auth.md](../auth.md) §10.2 **R-1** |
| v2 の退役 | 全面切替 (C-11) で v2 が退役する際、**アカウント基盤も v3 へ移す** — D-ST-1' によりこれが**前提に組み込まれた** (移行のタイミングは **RL-3 の最初**。2026-07-31 の DM-A3 ② で確定) | ST-Q6 / 上記 R-1 |

---

## 5. v3 で作り直す認証・アカウント基盤 API (移植対象の一覧)

> **⚠️ 本節の位置づけが D-ST-1' (2026-07-30) で反転した。**
> 以前は「**v2 が提供し v3 で作らない** API の再利用一覧」だったが、
> **ユーザー決定により v3 で実装する**ことになった (「基本 v2 でできていたことは実装したい」)。
> **本節の表は「v3 で移植すべきエンドポイントの一覧」として読む**。
> 反転の根拠と残る代償は §4 の D-ST-1' / §4.1、
> セキュリティ要件は [../auth.md](../auth.md) §6.8〜§6.11 が SSOT。
> **入出力仕様は [auth-accounts.md](auth-accounts.md) が確定** (2026-07-31。[../auth.md](../auth.md) §10.2 **R-3** は実施済み) — 本節は
> 「v2 に何があったか」を出典付きで示す移植チェックリストであり、v3 の API 仕様ではない。
>
> **v3 で追加するもの** (v2 に無い): [../auth.md](../auth.md) §6.9 の
> **アカウント手動ロック API** (`last_locked_at` を設定する経路。v2 には解除しか無い)。
>
> **v3 で変える点** (v2 の欠陥を引き継がない): ロック解除は `account_id` 指定 +
> `contract_id` 検証必須 (v2 は email 指定でテナント越境。同 §5-11) /
> リセットトークンは `crypto/rand` (同 §5-8) / リセット要求はアカウント不存在でも成功応答 (同 §5-9)。

| 用途 | v2 のエンドポイント | 出典 |
|---|---|---|
| サインイン (JWT 発行) | `POST /accounts/signin` | `hassan-v2-backend/router/router.go:76` |
| サインアップ (招待受諾) | `POST /accounts/signup` / `GET /accounts/signup-links/:id` | `同:75`, `:78` |
| パスワードリセット | `POST /accounts/reset-password` / `POST /accounts/reset-password/:hash` | `同:79-80` |
| 自分のアカウント取得・更新 | `GET /accounts/me` / `PUT /accounts` | `同:66`, `:69` |
| メール・パスワード変更 | `PUT /accounts/email` / `PUT /accounts/password` | `同:71-72` |
| アイコン | `POST /accounts/icon` / `DELETE /accounts/icon` | `同:73-74` |
| 契約内メンバー一覧・取得 | `GET /accounts` / `GET /accounts/:id` | `同:65`, `:67` |
| メンバー作成・権限変更・削除 | `POST /accounts` / `PUT /accounts/admin` / `DELETE /accounts/:id` | `同:68`, `:70`, `:81` |
| 招待リンク発行 | `POST /accounts/signup-links` | `同:77` |
| ロック解除・MFA リセット | `POST /accounts/unlock` / `POST /accounts/mfa/reset` | `同:82-83` |
| **社内管理者のサインイン** | `POST /admin/signin` (**公開エンドポイント**) | `同:195` (**2026-07-31 訂正** — `:194` は `adminRoute := r.Group("/admin")`。[../auth.md](../auth.md) §6.2 と [auth-accounts.md](auth-accounts.md) §2.1 は当初から `:195` で正しい) |
| **社内管理者によるロック解除** (全契約横断) | `POST /admin/accounts/unlock` | `同:211` |
| **社内管理者の MFA 登録・検証** | ユーザー側の `POST /mfa/totp/generate` / `verify` が移植元 (**`admin_mfa_configs` は新設**) | `同:231-232` ⚠️ **2026-08-10: v3 では作らない** ([auth-accounts.md](auth-accounts.md) AA-D-22) |
| **社内管理者の MFA リセット** (SuperAdmin のみ) | ユーザー側の `POST /accounts/mfa/reset` が移植元 | `同:83` ⚠️ **2026-08-10: v3 では作らない** (同 AA-D-22) |
| MFA (TOTP) | `POST /mfa/totp/generate` / `verify` / `reset` | `同:231-233` |
| 契約情報 | `GET /contracts` | `同:62` |
| 会社情報 | `GET /companies` / `POST /companies` / `PUT /companies` / `PUT /companies/mfa` | `同:93`, `:95-97` |
| 企業ミッション | `GET` / `POST` / `PUT` / `DELETE /company-mission` | `同:100-103` |

**注**: `GET /companies/genai` (`同:94`) は生成 AI で会社情報を作る経路であり、
**Dify 廃止 (C-9) の影響を受け得る**。移行先の判定は [../llm-migration.md](../llm-migration.md) が担う。

---

## 6. 本番観点への回答

| ID | 回答 | 備考 |
|---|---|---|
| A-1 | [README.md](README.md) §2.1。v3 新設の 6 本すべて認証必須。**§5 の移植対象のうち signin / signup / reset-password / signup-links 取得は本質的に未認証**であり、[../auth.md](../auth.md) §6.7 の**公開エンドポイントのホワイトリスト + CI 検査**で管理する (D-ST-1' により v3 が持つことになったため、v2 での公開範囲 — 同 §1.6 — をそのまま引き継ぐ) | AC-1.1 |
| A-2 | **回答**: 本ディレクトリのエンドポイントは `AuthRoleUser` のみ。契約内管理者限定は §3.1 の 4 本 (2026-08-24 に 3 → 4 — PV-D5。[../auth.md](../auth.md) §9.3 Q-A2 への回答を含む)。**ただし §5 の移植対象には社内管理者認証 (`X-Admin-Token`) を要するものが含まれる** — ロック解除 / MFA 登録・検証・リセット ([../auth.md](../auth.md) §6.2 の例外。**社内管理者は MFA 必須**)。**本ディレクトリ外**であり、認証系統の分離は同 §6.7 の **3 系統**ホワイトリストが担う | — |
| A-3 | v3 が新設する `account_notification_settings` / `workspace_settings` / `activity_logs` (v3 側) は、それぞれ `account_id` / `contract_id` を持つ | data-model で確定 |
| A-4 | 通知設定は `account_id`、ワークスペース設定・サマリ・活動ログは `contract_id` を Repository のクエリ条件に入れる。`GET /activity-logs` の `account_id` パラメータは**自契約メンバーであることをサーバが検証**する ([README.md](README.md) D-API-8) | — |
| A-5 | 本表の「固有ステータス」列 + [README.md](README.md) §2.5。**本ファイルの 403 は §3.1 の 4 本** (R-1。2026-08-24 に 3 → 4 — PV-D5)。ディレクトリ全体では 12 本 ([idea-boards.md](idea-boards.md) の 8 本を含む) | **AC-1.4** |
| A-6 | v3 新設分に LLM 経路は無い。**`GET /companies/genai` (会社情報の AI 生成) は §5 の移植対象に含まれるため v3 の管轄になった** — 移植時は [../architecture.md](../architecture.md) §3 の `gateway` 経由を必須とし (O-2 の全経路計測)、Dify 依存の判定は [../llm-migration.md](../llm-migration.md) が担う | §5 の注 |
| A-7 | ワークスペース設定の `default_*_visibility` が共有の既定値を持つ (D-ST-3)。**書く側と読む側をどちらも増分 1 に置く** (**2026-07-31 に C-16 で改訂**。旧記述は「どちらも増分 2・増分 1 では共有が発生しない」だったが、**v2 で共有していた契約が切替後に共有を変更できなくなる**ため成立しない。[../auth.md](../auth.md) §6.12) | [README.md](README.md) §5 API-Q3 |
| O-3 | **部分回答**: ユーザー向けのコスト表示は作らない (D-ST-5)。`GET /usage-summary` は**件数のみ**でコストを含まない。運用者向けの可視化は [../observability.md](../observability.md) §4.2 / §6.1 へ | C-12 と整合 |
| O-6 | **回答**: `GET /activity-logs` を新設し、監査記録の**参照経路**を作る (v2 は `activity_logs` テーブルがあるのに参照 API が無い)。**記録項目の定義は [../observability.md](../observability.md) §4.5** (D-ST-6) | — |
| D-5 | **JWT 署名鍵は共有しない。v3 で新規発行し Secrets Manager に置く** (§4.1 と一致。[../auth.md](../auth.md) §9.3 Q-A1 / §6.8 が SSOT)。加えて **§5 の移植によりメール送信・S3 の資格情報が v3 側に必要になる** — 洗い出しは [../infrastructure.md](../infrastructure.md) | [../auth.md](../auth.md) §6.8 |

---

## 7. 要確認 (プロトタイプに UI のみ / 判断待ち)

| # | 項目 | 状態 | 確定先 |
|---|---|---|---|
| ST-Q1 | **タイムゾーン設定の用途** | **2026-07-30 更新版で UI 自体が消滅** (旧版は `Asia/Tokyo` / `UTC` の選択肢のみだった)。サーバ側で使う場面 (レポートの日付境界・通知時刻) も未定義のまま | 要件確認 (ST-Q8 と同時に判断)。使わないなら FE のローカル設定で足り、API は不要になる |
| ST-Q2 | **データポリシー (学習利用)** | **2026-07-30 更新版で UI 自体が消滅** (旧版は「組織内モデルのみ」/「共通モデルにも活用」の選択肢のみだった)。**実装可能な挙動として定義されていない** | 要件確認 + LLM 提供者との契約確認。**API 化は挙動が定義されてから** (UI 消滅により優先度は下がった) |
| ST-Q3 | **メンバー CSV 出力** | 配線なしのダミー | 要件確認 |
| ~~ST-Q4~~ | ~~ログアウト時のトークン失効~~ | **決着済み (2026-07-30)**: サーバ側の即時失効は**手動ロック API** が担う ([../auth.md](../auth.md) §6.9)。ログアウトは FE のトークン破棄のみで、revoke エンドポイントは設けない | — |
| ST-Q5 | ~~v2 の `sharing_settings` 既存値の移行~~ → **移行手順として本文に昇格済み** | v2 本番 DB の契約ごとの共有 ON/OFF (`hassan-v2-backend/db/schema.sql:491-499`) を、**既存リソースの `visibility` 初期値**と **`default_asset_visibility` の初期値**の両方に写す (§3.2 / [themes.md](themes.md) §3.2 TM-1 / [assets.md](assets.md) §3.2 AS-M1) | 残る未確定は**実行タイミングのみ** (`docs/design/operations.md` の切替手順) |
| ST-Q6 | **アカウント基盤の移行タイミング** | **前提が変わった (2026-07-30)**: D-ST-1' により v3 が認証基盤を持つため、「v2 退役時に移すかどうか」ではなく**併用期間中に二重化する `accounts` をどう扱うか**が論点になった (どちらを正とするか・移行タイミング・資格情報の同期可否・ロールバック) | [../data-model.md](../data-model.md) §6.5 / AC-3.5。**R-1 は 2026-07-31 に回答済み** (DM-A3 = 推奨 5 点)。詳細は [../auth.md](../auth.md) §10.2 **R-1** の状態列 |
| ST-Q7 | **通知の配信経路** | プロトタイプの選択肢に「メール + Slack」がある。Slack 連携の実装が v2・PoC のどちらにも無い | 要件確認。**設定値だけ作って配信基盤が無い状態にしない** (BE-10 の「読む側と書く側を対で設計する」) |

### 7.1 プロトタイプ更新 (2026-07-30) による再確認事項

更新版プロトタイプで `admin` ビューの構成が変わった (§1) ため起票した再確認事項。
**ST-Q8 / ST-Q9 は 2026-07-30 に回答済みで、本文 (§3 / §3.2) へ反映済み**。

- **ST-Q8: `workspace` セクション消滅後の `/settings/workspace` の扱い**。
  事実: 更新版に `workspace` セクションが無く、タイムゾーン・データポリシー・ワークスペース名の UI が消えた (§1)。
  ただし `default_asset_visibility` は共有機能 ([assets.md](assets.md) §3.2 の BE-10 対応) が読む側として要求する (**その読む側が増分 1 に引き上げられたのが撤回の理由**)。
  選択肢: (a) `/settings/workspace` を増分 2 へ丸ごと後ろ倒しし、増分 1 の設定画面は通知設定のみにする
  (`timezone` は ST-Q1 の結論次第で削除) / (b) 現行設計 (増分 1 に `GET/PUT /settings/workspace`) を維持する。
  [Answer]: **(a) 増分 2 へ後ろ倒し** (2026-07-30 ユーザー回答) → **2026-08-12 に撤回**。
  [../auth.md](../auth.md) §6.12 (c) が **C-16 の適用で読む側・書く側とも増分 1** に確定させたため、
  `/settings/workspace` は**増分 1** になった。後ろ倒しのままだと **v2 の `POST /sharing-settings`
  (契約単位で共有を ON/OFF する操作) が増分 1 で失われる**。§3 の増分列・§3.2 に反映済み。
  `timezone` は ST-Q1 の結論が「サーバ側で使う」となった場合のみ項目に追加する

- **ST-Q9: `GET /usage-summary` が返す集計の形**。
  事実: 更新版の audit は「月選択 + メンバー × 活動種別 6 種の月次クロス集計 + CSV」(§2 の audit 行)。
  現行設計の 4 指標 (`idea_count` / `active_theme_count` / `asset_count` / `active_rate`) とは形が異なる。
  クロス集計は `GET /activity-logs` の集約で表現する手もある (from/to + account_id は定義済み。集約パラメータは未定義)。
  選択肢: (a) `/usage-summary` をクロス集計形 (`{months[], members[], counts[type][month][member]}` 等) に変更 /
  (b) 4 指標を維持し、クロス集計は `/activity-logs` に集約クエリ (`group_by`) を足して担わせる / (c) 4 指標を維持し FE がログから集計。
  [Answer]: **(a) クロス集計形に変更** (2026-07-30 ユーザー回答)。§3 の `GET /usage-summary` に反映済み。
  旧 4 指標 (`active_rate` 含む) は廃止 — [../data-model.md](../data-model.md) §4.10 / DM-Q5 も同時に解消。
  活動種別の値域は [../observability.md](../observability.md) §4.5 の `action` 定義と揃える
