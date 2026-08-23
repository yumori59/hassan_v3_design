# v2 搭載機能の棚卸し (v3 への引き継ぎ台帳)

> **本書の位置づけ**: **v2 に実装がある機能の全件リスト**と、**v3 のどこが受けるか**の対応を記録する。
> ユーザー指示 (2026-08-01) — 「**v2 に実装があるもので同じ機能が v3 にある場合は、搭載していた機能は記載しておきたい**」。
>
> **本書は事実の記録** (`docs/analysis/` の規約に従い、v2 の実装は出典付き)。
> **設計判断は行わない** — 引き継ぐ / 引き継がないの判断は
> [../../aidlc-docs/inception/productionization/requirements.md](../../aidlc-docs/inception/productionization/requirements.md) の
> **C-16 とその承認済み例外表**が SSOT で、本書はその**照合の入力**になる。
>
> **使い方**: 設計で「対象外」「増分 2 へ後ろ倒し」「廃止」を書くときは、**本書で v2 の実装の有無を確認する**。
> 実装があるなら C-16 違反なので、例外表への追加とユーザー承認が要る。

## 0. 抽出の方法 (再現手順)

**件数は本書に転記しない** (DR-9)。次のコマンドの出力が正である。

```bash
V2=/Users/yuyamorishita/aillio/hassan/hassan-v2-backend
# 全ルート数
grep -cE '\.(GET|POST|PUT|DELETE|PATCH)\(' $V2/router/router.go
# グループ別
grep -nE '\.(GET|POST|PUT|DELETE|PATCH)\(' $V2/router/router.go \
  | sed -E 's/^([0-9]+):[[:space:]]*([a-zA-Z]+)\..*/\2/' | sort | uniq -c | sort -rn
```

**2026-08-01 の実測**: 全 **132** ルート (うち **3** は基盤 = swagger / ルート / ヘルスチェック)。
出典はすべて `hassan-v2-backend/router/router.go` の行番号。

## 1. 状態の凡例

| 状態 | 意味 |
|---|---|
| **引き継ぐ** | v3 に同等の機能がある (対応先を明記) |
| **統合** | 機能は残るが独立した API を持たず、別の経路に吸収される (UI が変わる。C-16 の「引き継いだ」に含まれる) |
| **例外 (承認済み)** | v3 に持ち込まない。**C-16 の例外表に記載があり、ユーザー承認済み** |
| **対象外 (要確認)** | v3 の設計に対応先が無い。**C-16 の下で承認を得ていない** — 本書の主な用途はここを可視化すること |
| **基盤** | アプリ機能ではない (ヘルスチェック等) |

---

## 2. 一般ユーザー向け機能

### 2.1 契約・アカウント・認証 (`/contracts` / `/accounts` / `/mfa`)

v3 の対応先は [../design/API/auth-accounts.md](../design/API/auth-accounts.md) (37 エンドポイント)。

| v2 エンドポイント | 行 | v2 が搭載していた機能 | v3 の対応 | 状態 |
|---|---|---|---|---|
| `GET /contracts` | `:62` | 自分の契約情報の取得 (v2 は `sharing_settings` も含めて返す) | `GET /contract` (`sharing_settings` は返さず `member_count` を返す — AA-D-15。パスは `/me` を付けない単数形 = AA-D-25) | **引き継ぐ** |
| `GET /accounts` | `:65` | 契約内メンバー一覧 | 同名 | **引き継ぐ** |
| `GET /accounts/me` | `:66` | 自分のアカウント取得 | 同名 | **引き継ぐ** |
| `GET /accounts/:id` | `:67` | メンバー個別取得 | 同名 | **引き継ぐ** |
| `POST /accounts` | `:68` | メンバー作成 (契約内管理者) | 同名 | **引き継ぐ** |
| `PUT /accounts` | `:69` | 自分のアカウント更新 | 同名 | **引き継ぐ** |
| `PUT /accounts/admin` | `:70` | メンバーの権限変更 (契約内管理者) | 同名 | **引き継ぐ** |
| `PUT /accounts/email` | `:71` | メールアドレス変更 | `PUT /accounts/me/email` | **引き継ぐ** |
| `PUT /accounts/password` | `:72` | パスワード変更 | `PUT /accounts/me/password` | **引き継ぐ** |
| `POST /accounts/icon` | `:73` | アイコン画像のアップロード | auth-accounts.md §2.3 | **引き継ぐ** |
| `DELETE /accounts/icon` | `:74` | アイコン削除 | 同 | **引き継ぐ** |
| `POST /accounts/signup` | `:75` | 招待リンクからのサインアップ (**v2 は招待の email と入力 email を突き合わせない = V2-D1**) | 同名 (**AA-D-5 で突合を必須化**) | **引き継ぐ (欠陥は継承しない)** |
| `POST /accounts/signin` | `:76` | サインイン (JWT 発行) | 同名 | **引き継ぐ** |
| `POST /accounts/signup-links` | `:77` | 招待リンク発行 | 同名 | **引き継ぐ** |
| `GET /accounts/signup-links/:id` | `:78` | 招待リンクの検証 (未認証) | 同名 (**秘密は `token_hash` へ** — data-model §4.2) | **引き継ぐ** |
| `POST /accounts/reset-password` | `:79` | パスワードリセット要求 | 同名 | **引き継ぐ** |
| `POST /accounts/reset-password/:hash` | `:80` | リセット実行 | `POST /accounts/reset-password/confirm` (**秘密を URL に置かない** — AA-D-4) | **引き継ぐ** |
| `DELETE /accounts/:id` | `:81` | メンバー削除 | 同名 (**202 + 状態 GET**。AA-D-13) | **引き継ぐ** |
| `POST /accounts/unlock` | `:82` | ロック解除 (契約内管理者。**v2 は email 指定でテナント越境 = §5-11**) | `DELETE /accounts/{id}/lock` (**`WHERE id AND contract_id`**) | **引き継ぐ (欠陥は継承しない)** |
| `POST /accounts/mfa/reset` | `:83` | メンバーの MFA リセット (契約内管理者) | auth-accounts.md §2.3 | **引き継ぐ** |
| `POST /mfa/totp/generate` | `:231` | TOTP 登録開始 | 同名 | **引き継ぐ** |
| `POST /mfa/totp/verify` | `:232` | TOTP 検証 (**v2 は不一致が 500 = §5-12 / 失敗が加算されない = §5-13**) | 同名 (**401 + 試行上限**。auth.md §6.2 の成立条件) | **引き継ぐ (欠陥は継承しない)** |
| `POST /mfa/totp/reset` | `:233` | 自己 MFA リセット (**現在のコードが必要。紛失時は使えない**) | 同名 (AA-D-8 で MFA 検証済みを必須化) | **引き継ぐ** |

### 2.2 会社情報 (`/companies` / `/company-mission`)

| v2 エンドポイント | 行 | v2 が搭載していた機能 | v3 の対応 | 状態 |
|---|---|---|---|---|
| `GET /companies` | `:93` | 会社情報の取得 | auth-accounts.md §2.3 / [../design/API/settings.md](../design/API/settings.md) §5 | **引き継ぐ** |
| `POST /companies` | `:95` | 会社情報の作成 | 同 | **引き継ぐ** |
| `PUT /companies` | `:96` | 会社情報の更新 | 同 | **引き継ぐ** |
| `PUT /companies/mfa` | `:97` | 会社単位の MFA 必須設定 (`companies.mfa_type`) | 同 | **引き継ぐ** |
| **`GET /companies/genai`** | `:94` | **会社情報を LLM で生成する** (社名等から自動生成) | **対応先が設計に無い** | **対象外 (要確認)** |
| `GET /company-mission` | `:100` | 企業ミッションの取得 | — | **例外 (承認済み。AA-Q1)** |
| `POST /company-mission` | `:101` | 企業ミッションの作成 | — (ミッションは**テーマが持つ** = `themes.mission`) | **例外 (承認済み。AA-Q1)** |
| `PUT /company-mission` | `:102` | 企業ミッションの更新 | — | **例外 (承認済み。AA-Q1)** |
| `DELETE /company-mission` | `:103` | 企業ミッションの削除 | — | **例外 (承認済み。AA-Q1)** |

### 2.3 テーマ (`/themes`)

v3 の対応先は [../design/API/themes.md](../design/API/themes.md)。

| v2 エンドポイント | 行 | v2 が搭載していた機能 | v3 の対応 | 状態 |
|---|---|---|---|---|
| `GET /themes` | `:86` | テーマ一覧 (**共有 ON なら契約内の他人のテーマも見える**) | 同名 (`scope=contract` は**増分 1 から有効** — C-16) | **引き継ぐ** |
| `GET /themes/:id` | `:87` | テーマ取得 (**v2 は所有者チェック無し = §5-1 IDOR**) | 同名 (所有者条件を `WHERE` に持つ) | **引き継ぐ (欠陥は継承しない)** |
| `POST /themes` | `:88` | テーマ作成 | 同名 | **引き継ぐ** |
| `PUT /themes/:id` | `:89` | テーマ更新 | 同名 | **引き継ぐ** |
| `DELETE /themes/:id` | `:90` | テーマ削除 (**v2 は物理削除**) | 同名 (**論理削除 `deleted_at`** = DM-5。見え方は 404) | **引き継ぐ** |

### 2.4 アセット (`/assets`)

v3 の対応先は [../design/API/assets.md](../design/API/assets.md)。

| v2 エンドポイント | 行 | v2 が搭載していた機能 | v3 の対応 | 状態 |
|---|---|---|---|---|
| `GET /assets` | `:106` | アセット一覧 | 同名 (`scope=contract` は増分 1 から有効) | **引き継ぐ** |
| `GET /assets/:id` | `:107` | アセット取得 | 同名 | **引き継ぐ** |
| `POST /assets` | `:108` | アセット作成 | 同名 | **引き継ぐ** |
| `POST /assets/bulk` | `:109` | **アセットの一括作成** | assets.md §2 (作成の一括系) | **要確認** — 一括作成の受け口が設計に明示されていない |
| `PUT /assets/:id` | `:110` | アセット更新 | 同名 | **引き継ぐ** |
| `DELETE /assets/:id` | `:111` | アセット削除 | 同名 | **引き継ぐ** |
| `DELETE /assets/bulk` | `:112` | **アセットの一括削除** | assets.md §2 | **要確認** — 上と同じ |
| `GET /assets/recent` | `:113` | **最近使ったアセットの一覧** | **対応先が設計に無い** | **対象外 (要確認)** |
| `POST /assets/upload` | `:114` | **CSV からのアセット一括投入** | assets.md の CSV アップロード | **引き継ぐ** |
| `POST /assets/generate` | `:116` | アセットの AI 生成 (抽出) | assets.md の抽出フロー | **引き継ぐ** |
| `POST /assets/generate-description` | `:118` | **アセット説明文の AI 生成** | 抽出フローに吸収 (llm-migration) | **統合** |

### 2.5 アイデア (`/ideas` / `/idea-hassans`)

v3 の対応先は [../design/API/ideas.md](../design/API/ideas.md) (参照・作成・更新・版・評価) と
[../design/API/conversation.md](../design/API/conversation.md) (会話セッションと生成の入口)。**2026-08-02 に起草済み**。
**参照系 4 本は `idea-boards.md` §7 から `ideas.md` へ移設した**。

| v2 エンドポイント | 行 | v2 が搭載していた機能 | v3 の対応 | 状態 |
|---|---|---|---|---|
| `GET /ideas` | `:122` | アイデア一覧 | 同名 (参照専用) | **引き継ぐ** |
| `GET /ideas/:id` | `:121` | アイデア取得 | 同名 | **引き継ぐ** |
| `PUT /ideas/:id/star` | `:128` | スター評価 | 同名 | **引き継ぐ** |
| **`GET /ideas/csv`** | `:127` | **アイデア一覧の CSV エクスポート** (16 列・UTF-8 BOM + CRLF) | 同名 (**[../design/API/ideas.md](../design/API/ideas.md) §2.6**。2026-07-31 に C-16 で復活し、2026-08-02 に `idea-boards.md` §2.4 から移設) | **引き継ぐ** |
| `POST /ideas/generate` | `:123` | アイデアの発散生成 | 会話型フローへ統合 (llm-migration V-1) | **統合** |
| `POST /ideas/generate/my-idea` | `:124` | 自分のアイデアの登録・生成 | 同 (**V-3**) | **統合** |
| `POST /ideas/generate/my-idea/draft` | `:125` | 自分のアイデアの下書き生成 | 同 (**V-3**。`ExecuteDraft` は同じ UseCase — `hassan-v2-backend/usecase/idea/create_my_idea.go:207`) | **統合** |
| `POST /ideas/evaluate` | `:126` | アイデアの再評価 | **P-5 へ統合** (**V-2**) | **統合** |
| `POST /idea-hassans` | `:144` | 発散セッションの作成 | [../design/API/conversation.md](../design/API/conversation.md) §1 (`POST /conversations`) | **統合** |
| `GET /idea-hassans` | `:146` | 発散セッション一覧 | 同 | **統合** |
| `GET /idea-hassans/:id` | `:145` | 発散セッション取得 | 同 | **統合** |
| `PUT /idea-hassans/:hassan_id` | `:147` | 発散セッションの更新 | 同 | **統合** |
| `DELETE /idea-hassans/:hassan_id` | `:148` | 発散セッションの削除 | 同 | **統合** |

### 2.6 アイデアボード (`/idea-boards`)

v3 の対応先は [../design/API/idea-boards.md](../design/API/idea-boards.md)。**v2 の契約内共有と 3 段ロールを増分 1 で引き継ぐ** (auth.md §6.12 (b))。

| v2 エンドポイント | 行 | v2 が搭載していた機能 | v3 の対応 | 状態 |
|---|---|---|---|---|
| `POST /idea-boards` | `:131` | ボード作成 | 同名 | **引き継ぐ** |
| `GET /idea-boards` | `:132` | ボード一覧 (**`sharing_settings` + メンバーシップで絞る**) | 同名 | **引き継ぐ** |
| `PUT /idea-boards/:id` | `:133` | ボード名の更新 | 同名 | **引き継ぐ** |
| `DELETE /idea-boards/:id` | `:134` | ボード削除 | 同名 | **引き継ぐ** |
| `GET /idea-boards/:id/ideas` | `:135` | ボード上のアイデア一覧 | `GET /idea-boards/{id}/items` | **引き継ぐ** |
| `PUT /idea-boards/:id/ideas/:idea_id` | `:136` | ボードアイテムの更新 (フェーズ移動等) | 同 | **引き継ぐ** |
| `PUT /idea-boards/:id/filter` | `:137` | **ボードのフィルタ定義の更新** | **採らない (置き換え)** — filter はボード定義そのものなので切替時に評価して実体化する (idea-boards.md §2 / §4) | **統合** |
| `GET /idea-boards/:id/members` | `:138` | 共有メンバー取得 | 同名 | **引き継ぐ** |
| `PUT /idea-boards/:id/members` | `:141` | 共有メンバー設定 (`role` = viewer / editor) | `PUT …/members` (置換) | **引き継ぐ** |
| `POST /idea-boards/phases` | `:139` | フェーズ作成 | `POST /idea-board-phases` | **引き継ぐ** |
| `PUT /idea-boards/phases/:phase_id` | `:140` | フェーズ更新 | `PUT /idea-board-phases/{id}` | **引き継ぐ** |

### 2.7 企画書 (`/business-plans` / `/business-plans/detailed`)

v3 の対応先は [../design/API/plans.md](../design/API/plans.md) (**2026-08-02 起草済み**。同書 §3 が本節の 18 行と 1:1 で対応する)。
**本節が「企画書に何があったか」の唯一の一覧**であり、`plans.md` §3 の対応表がその受け先の SSOT。
**ユーザー決定 CV-Q1=B により 18 本すべてが第 1 リリース対象**である (「増分 2」「後ろ倒し」は 0 行)。

| v2 エンドポイント | 行 | v2 が搭載していた機能 | 状態 |
|---|---|---|---|
| `POST /business-plans/generate` | `:151` | 企画書の生成 (**SSE ストリーム**。`hassan-v2-backend/controller/business_plan.go:242` の `streamChannelAsSSE`。**2026-08-02 訂正** — 旧記述「同期」は誤り) | **統合** (会話フロー / 企画書タブ) |
| `POST /business-plans/jobs/start` | `:152` | 企画書生成ジョブの開始 (非同期) | **統合** |
| `GET /business-plans/jobs/:job_id` | `:153` | ジョブ状態の取得 | **統合** |
| `GET /business-plans/jobs/:job_id/stream` | `:154` | **ジョブ進捗の SSE ストリーム** | **統合** (SSE は v3 の共通機構へ) |
| `POST /business-plans` | `:155` | 企画書の作成 | **統合** |
| `PUT /business-plans/:id` | `:156` | 企画書の更新 | **統合** |
| `GET /business-plans/:id` | `:158` | 企画書の取得 | **統合** |
| `GET /business-plans` | `:160` | 企画書一覧 | **統合** |
| `DELETE /business-plans/:id` | `:159` | 企画書の削除 | **統合** |
| `PUT /business-plans/:id/histories/:history_id/prompt` | `:157` | **版履歴のプロンプト編集** | **要確認** — 版履歴の編集操作が v3 の設計に無い |
| `GET /business-plans/:id/chat/history` | `:161` | 企画書チャットの履歴取得 | **統合** |
| `POST /business-plans/:id/chat` | `:162` | 企画書チャット (ブラッシュアップ) | **統合** |
| `POST /business-plans/:id/favorite` | `:163` | **企画書のお気に入り登録** | **要確認** — `business_plan_favorites` に相当する v3 テーブル・API が無い |
| `DELETE /business-plans/:id/favorite` | `:164` | お気に入り解除 | **要確認** (同上) |
| `GET /business-plans/generate-image` | `:165` | 企画書サムネイルの生成 | **引き継ぐ** (LM-Q3 = サムネイル維持) |
| `GET /business-plans/detailed` | `:168` | 詳細版企画書の取得 | **統合** |
| `POST /business-plans/detailed` | `:169` | 詳細版のセクション生成 | **統合** |
| `POST /business-plans/detailed/brush-up/prepare` | `:170` | 詳細版のブラッシュアップ準備 | **統合** |

### 2.8 リサーチ (`/research-chats` / `/research-sheets`)

| v2 エンドポイント | 行 | v2 が搭載していた機能 | v3 の対応 | 状態 |
|---|---|---|---|---|
| `POST /research-chats` | `:178` | カスタムリサーチのストリーム実行 | ナレッジ / 会話フローへ統合 (LM-Q2) | **統合** |
| `GET /research-chats` | `:173` | リサーチ会話の一覧 | 同 | **統合** |
| `GET /research-chats/:conversation_id` | `:174` | リサーチ会話の履歴 | 同 | **統合** |
| `DELETE /research-chats/:conversation_id` | `:175` | リサーチ会話の削除 | 同 | **統合** |
| `POST /research-sheets` | `:181` | リサーチシートのチャット | — | **例外 (承認済み。LM-Q4 = 廃止)** |
| `GET /research-sheets` | `:182` | リサーチシート一覧 | — | **例外 (承認済み)** |
| `GET /research-sheets/:conversation_id` | `:184` | リサーチシート取得 | — | **例外 (承認済み)** |
| `PUT /research-sheets/:conversation_id` | `:185` | リサーチシート更新 | — | **例外 (承認済み)** |
| `PUT /research-sheets/:conversation_id/html-content` | `:183` | HTML 本文の更新 | — | **例外 (承認済み)** |
| `DELETE /research-sheets/:conversation_id` | `:186` | リサーチシート削除 | — | **例外 (承認済み)** |

### 2.9 共有設定・お知らせ・活動ログ

| v2 エンドポイント | 行 | v2 が搭載していた機能 | v3 の対応 | 状態 |
|---|---|---|---|---|
| `POST /sharing-settings` | `:189` | **契約 × カテゴリ (idea / asset / business_plan) の共有 ON/OFF** | **per-resource `visibility` + 契約単位の既定値 3 カテゴリ** (auth.md §6.12。**増分 1**) | **引き継ぐ** |
| `GET /news` | `:226` | 既読状態つきのお知らせ情報 | [../design/API/news.md](../design/API/news.md) | **引き継ぐ** (`has_unread` → **未読件数**へ拡張) |
| `POST /news` | `:227` | 既読化 (**記事 ID を持たない**) | `POST /news/{id}/read` (**記事単位**) | **引き継ぐ** |
| `POST /webhook/microcms/news` | `:192` | microCMS からのお知らせ受信 (HMAC 検証) | **v3 に持ち込まない** — 受信は v2 backend が担い続ける (auth.md §6.7) | **例外 (承認済み)** |
| `GET /event_logs/analytics` | `:236` | **利用状況の集計** | `GET /usage-summary` (settings.md。月 × メンバー × 活動種別) | **引き継ぐ** |
| `POST /event_logs` | `:237` | **画面アクセス等のイベント記録** | `audit_logs` へ集約 (DM-15。**`event_logs` 相当の新設は却下**) | **統合** |

---

## 3. 社内管理者向け機能 (`/admin`)

**ここが C-16 の下で最も差が大きい**。`auth.md` §6.2 は社内管理者機能を
「**ロック解除 + 到達に必要な最小の付随機構**」に限り、
「それ以外の管理者機能 (社内向け一覧・会社管理・利用状況閲覧) は**引き続き対象外**」としている
(2026-07-30 のユーザー決定)。**その決定は C-16 より前**であり、下表の「対象外 (要確認)」は
**C-16 の例外表に未登録**である。

| v2 エンドポイント | 行 | v2 が搭載していた機能 | v3 の対応 | 状態 |
|---|---|---|---|---|
| `POST /admin/signin` | `:195` | 社内管理者のサインイン | auth-accounts.md §2.4 | **引き継ぐ** |
| `GET /admin/me` | `:196` | 自分の管理者アカウント取得 | 同 | **引き継ぐ** |
| `POST /admin/accounts/unlock` | `:211` | **全契約横断のロック解除** (**v2 は `CheckSuperAdminRole` を持たず Admin でも実行できる**) | 同 (**v3 は SuperAdmin 限定** — auth.md §6.2) | **引き継ぐ** |
| `POST /admin/companies/accounts/mfa/reset` | `:217` | 一般アカウントの MFA リセット | auth-accounts.md §2.4 (AA-Q2=a) | **引き継ぐ** |
| `GET /admin/accounts/register/password/check` | `:199` | パスワード登録トークンの検証 (公開) | **v3 は API を作らず移行スクリプト投入 + 一時パスワード** (auth.md §6.2「初回登録の窓を閉じる」) | **例外 (承認済み)** |
| `POST /admin/accounts/register/password` | `:200` | パスワード登録 (公開。**`math/rand` トークン経由 = §5-8**) | 同上 | **例外 (承認済み)** |
| `POST /admin/accounts` | `:206` | 管理者アカウントの作成 | 移行スクリプト投入 (API を持たない) | **例外 (承認済み)** |
| `GET /admin/accounts` | `:205` | 管理者アカウント一覧 | **対応先が設計に無い** | **対象外 (要確認)** |
| `GET /admin/accounts/:id` | `:207` | 管理者アカウント取得 | 同 | **対象外 (要確認)** |
| `DELETE /admin/accounts/:id` | `:208` | 管理者アカウント削除 | 同 | **対象外 (要確認)** |
| `PUT /admin/accounts/name` | `:202` | 管理者の氏名変更 | 同 | **対象外 (要確認)** |
| `PUT /admin/accounts/email` | `:203` | 管理者のメール変更 | 同 | **対象外 (要確認)** |
| `PUT /admin/accounts/password` | `:204` | 管理者のパスワード変更 | 同 | **対象外 (要確認)** |
| `PUT /admin/accounts/details` | `:209` | 管理者の詳細更新 (ロール等) | 同 | **対象外 (要確認)** |
| `GET /admin/accounts/auth_roles` | `:210` | 管理者ロールのマスタ一覧 | 同 | **対象外 (要確認)** |
| `GET /admin/companies` | `:215` | **契約 (会社) の一覧** | 同 | **対象外 (要確認)** |
| `GET /admin/companies/:contract_id` | `:218` | 契約の個別取得 | 同 | **対象外 (要確認)** |
| `POST /admin/companies` | `:220` | **契約の新規作成 (顧客のオンボーディング)** | 同 | **対象外 (要確認)** |
| `PUT /admin/companies` | `:221` | 契約の更新 | 同 | **対象外 (要確認)** |
| `DELETE /admin/companies/:contract_id` | `:219` | **契約の削除** | 同 | **対象外 (要確認)** |
| `GET /admin/companies/accounts` | `:216` | 全契約横断のアカウント検索 | 同 (auth-accounts.md R-AA-3 ①が起票済み) | **対象外 (要確認)** |
| `GET /admin/companies/clients/csv` | `:222` | **顧客一覧の CSV エクスポート** | 同 | **対象外 (要確認)** |
| `GET /admin/companies/usage_status/csv` | `:223` | **利用状況の CSV エクスポート** | 同 | **対象外 (要確認)** |

> **重要**: `POST /admin/companies` (**契約の新規作成**) が対象外のままだと、
> **v3 単独では新規顧客を受け入れられない** (契約を作る経路が製品内に無い)。
> 全面切替 (C-15) で v2 が退役する前提と両立しないため、**優先して判断が必要**。

---

## 4. 基盤 (アプリ機能ではない)

| v2 エンドポイント | 行 | 内容 | v3 |
|---|---|---|---|
| `GET /swagger/*any` | `:34` | Swagger UI | 実装リポで決める (v3 は orval 生成のため OpenAPI は必要) |
| `GET /` | `:35` | ルート | — |
| `GET /alive` | `:56` | ヘルスチェック | ALB のヘルスチェック先として必要 ([../design/infrastructure.md](../design/infrastructure.md)) |

---

## 5. 「対象外 (要確認)」の一覧 (C-16 の判断待ち)

**本書の主な成果物**。設計に対応先が無く、C-16 の例外表にも無いもの。

| # | 機能 | v2 の実装 | 影響 |
|---|---|---|---|
| 1 | **契約 (会社) の新規作成・更新・削除** | `:220` / `:221` / `:219` | **v3 単独で新規顧客を受け入れられない**。C-15 (全面切替) と両立しない |
| 2 | 契約 (会社) の一覧・個別取得 | `:215` / `:218` | 社内の顧客管理業務が v3 でできない |
| 3 | 管理者アカウントの CRUD・ロール管理 | `:202`〜`:210` | 管理者の追加・削除・ロール変更が製品内でできない (移行スクリプト運用のみ) |
| 4 | 全契約横断のアカウント検索 | `:216` | 問い合わせ対応の調査手段が無い |
| 5 | 顧客一覧・利用状況の CSV エクスポート | `:222` / `:223` | 社内のレポート業務が v3 でできない |
| 6 | **会社情報の LLM 生成** | `:94` | 会社情報の入力補助が無くなる |
| 7 | ~~**最近使ったアセットの一覧**~~ | `:113` | **解消済み (2026-08-01)**: [../design/API/assets.md](../design/API/assets.md) §3.3 の `GET /assets/recent` (D-AS-18) |
| 8 | ~~アセットの一括作成・一括削除~~ | `:109` / `:112` | **解消済み (2026-08-01)**: 同 §3.3 の `POST/DELETE /assets/bulk` + `POST /asset-imports` (D-AS-14〜17。AS-Q3 のクローズ撤回) |
| 9 | ~~**企画書のお気に入り**~~ | `:163` / `:164` | **解消済み (2026-08-02)**: [../design/API/plans.md](../design/API/plans.md) §9 の `POST/DELETE /plans/{plan_id}/favorite`。受け皿は [../design/data-model.md](../design/data-model.md) §4.6 の **`plan_favorites`** (新設) |
| 10 | ~~企画書の版履歴のプロンプト編集~~ | `:157` | **解消済み (2026-08-02)**: [../design/API/plans.md](../design/API/plans.md) §5.1 の `PUT /plans/{plan_id}/tabs/{tab_id}/versions/{ver_no}/instruction`。受け皿は [../design/data-model.md](../design/data-model.md) §4.6 の **`plan_tab_versions.instruction`** 列 |

**1〜5 は社内管理者機能**であり、`auth.md` §6.2 の「対象外」という 2026-07-30 の決定に含まれる。
**残る未解決は 6 (会社情報の LLM 生成) の 1 件のみ** — 一般ユーザー向け機能でありながら、対象外とした明示的な判断が見つからない (= 設計の抜け落ちの可能性)。
**7・8 は 2026-08-01 に解消済み** ([../design/API/assets.md](../design/API/assets.md) §3.3 で仕様化)、**9・10 は 2026-08-02 に解消済み** ([../design/API/plans.md](../design/API/plans.md) §5.1 / §9 で仕様化)。

> **C-16 の完了条件 (本節の「対象外 (要確認)」が空になること) までの残**: **#1〜#5 (社内管理者機能。承認済みの対象外だが例外表に未登録)** と **#6** の計 6 件。

---

## 6. 更新の運用

- **v2 に機能が追加されたら本書に行を足す** (v2 は稼働中のため)
- **設計側で「対象外」「廃止」「増分 2」を書いたら、本書の該当行の状態を更新する**
- **§5 の表が空になることが C-16 の完了条件**である (すべてが「引き継ぐ / 統合 / 例外 (承認済み)」に分類される状態)
