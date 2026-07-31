# Workflow Plan: productionization (PoC → 本番化)

> 対応する要件: [requirements.md](requirements.md) / 質問: [questions.md](questions.md)
> 設計骨格: [architecture.md](../../../docs/design/architecture.md)
> ステータス: **Phase 0 完了**。Phase 1 (分岐の解消) は Q-2/Q-4/Q-5/Q-6 反映済み、Q-1・Q-3・Q-7〜Q-9 が残り。

## 影響範囲

- 設計成果物: `docs/analysis/poc-inventory.md` (済) / `docs/analysis/gap-analysis.md` (済) /
  `docs/design/architecture.md` (骨格) / `docs/design/auth.md` (記述あり) /
  `docs/design/API/` (全 7 ファイル記述あり。レビュー待ち) /
  `docs/design/data-model.md` (**記述あり**) /
  `docs/design/observability.md` (**記述あり**) / `docs/design/operations.md` (**記述あり**) / `docs/design/infrastructure.md` (**記述あり**) /
  `docs/design/llm-migration.md` (**記述あり**) / `docs/design/testing.md` (**記述あり**) / `docs/design/frontend.md` (**記述あり**) /
  `docs/design/API/auth-accounts.md` (**記述あり**)
- 実装リポ引き渡し物: `templates/` (backend / frontend / infra の 3 セット) (雛形は済。CI ゲートの確定待ち)
- 本番観点: A 全項目 / O 全項目 / D 全項目

## 受入基準 → 検証方法

| AC | 検証方法 | 状態 |
|---|---|---|
| AC-1.1 | `docs/design/auth.md` §6.7 (**4 系統ホワイトリスト + 系統単位の CI 検査**。公開 / ユーザー認証 / 社内管理者認証 / 社内管理者認証 (MFA 未検証で可)) + `docs/design/API/README.md` §2.1 (適用範囲) / 同 §1.4 (CI 検査の一覧) | **記述あり** (2026-07-30。社内管理者の MFA 必須化に伴い 4 系統へ更新)。レビュー未実施 |
| AC-1.2 | `docs/design/data-model.md` の各テーブル定義に所有者列 (`account_id` / `contract_id`) + `docs/design/auth.md` §6.3 の例外列挙 / §6.4 の許可リストと CI 検査。レビューで A-3 / A-4 確認 | 未着手 (Q-1 / **R-1** 待ち)。**規約側 (auth.md §6.3 / §6.4) は記述あり** |
| AC-1.3 | `docs/design/architecture.md` **§3.8.2** の所有者スコープ強制点 (束縛 = `usecase/conversation/tool_registry.go` のクロージャ / 検証 = Repository のクエリ条件) + レビューで A-6 確認。**旧記述の `ToolDispatcher` は増分 layering で関数注入方式に置き換わった** ([requirements-layering.md](requirements-layering.md) C-L9) | **骨格で回答済み** |
| AC-1.4 | `docs/design/API/README.md` §2.5 のステータスコード適用一覧 + `docs/design/auth.md` §6.6 (判定規則の SSOT。**429 を含む**) | **記述あり** (429 の §2.5 反映は 2026-07-29) |
| AC-1.5 | `docs/design/auth.md` §6.8 (鍵の新規発行・複数鍵ローテーション) / §6.9 (有効期間と手動ロックによる失効) | **記述あり**。実装先は **v3** で確定 (同 §9.3 Q-A8。2026-07-30) |
| AC-1.6 | `docs/design/auth.md` §6.10 (`crypto/rand` + CI 検査) / §6.11 (応答マスク・レート制限・429・観測) + `docs/design/observability.md` §4.3 F-6 / §4.6 AL-7 | **記述あり**。**実装先の明示 = v3** (同 §9.3 Q-A8)。エンドポイント仕様の起草は残作業 (同 §10.2 R-3) |
| AC-2.1 | `docs/design/observability.md` §4.2 (LLM 呼び出しレコードのフィールド要件) + §2 O-C (計測位置) | **記述あり** (レビュー未実施) |
| AC-2.2 | `docs/design/observability.md` §4.2 / §4.4 (安全弁) / §4.6 (AL-4 コスト急増) | **記述あり** (レビュー未実施) |
| AC-2.3 | `docs/design/observability.md` §4.3 の失敗 5 分類 (F-1〜F-5。BE-6 / BE-8 由来を含む) | **記述あり** (レビュー未実施) |
| AC-2.4 | `docs/design/observability.md` §4.1 の必須フィールド表 | **記述あり** (レビュー未実施) |
| AC-2.5 | `docs/design/observability.md` §4.5 (v2 の `activity_logs` / `event_logs` 方式を踏襲) | **記述あり** (レビュー未実施) |
| AC-3.1 | `docs/design/operations.md` に環境・シークレット管理 | **記述あり** (§3 の 3 環境 + §4 の Secrets Manager / SSM 分離。v2 は Secrets Manager 未使用のため新規設計) |
| AC-3.2 | `templates/backend-repo/.github/workflows/ci.yml` ほか 3 リポ分 + `docs/design/operations.md` の CI ゲート表 | **雛形済み** (確定はレビュー後) |
| AC-3.3 | `docs/design/operations.md` に Agent 発行を含むデプロイ手順 | **記述あり** (§5 の 6 ジョブ + §5.2 の Agent / Environment ライフサイクル + §5.3 のロールバック) |
| AC-3.4 | `docs/design/data-model.md` にマイグレーション方式・ロールバック | **記述あり** (§6 / §7.4。ツールは **psqldef で確定** = D-4。2026-07-31) |
| AC-3.5 | `docs/design/operations.md` に移行・段階リリース | **記述あり** (§6 の RL-0〜RL-5 = 全面切替)。**残るのは DM-A2 (データ引き継ぎ範囲。Task-2f 待ち)** |
| AC-3.6 | `docs/design/infrastructure.md` にインフラ構成要素と IaC 管理範囲 (Terraform) | **記述あり** (INF-A〜O + 提案 40 要素 + Terraform / ecspresso 分担)。**残るのは Q-INF-1 (要素一覧の確認) と Q-INF-3 (ドメイン)** |
| AC-3.7 | `docs/design/operations.md` に環境戦略と DB 自動適用範囲 | **記述あり** (§3 の環境戦略 + §7.4 の自動適用範囲 = dev の非破壊のみ自動 / 破壊的は分解)。**フラグ方式は §7.2 の OP-I で確定** (環境変数のみ) |
| AC-3.8 | `docs/design/llm-migration.md` に機能別の v3 実装形態・モデル見直し結果 | **記述あり** (Managed Agent 3 / 直接 API 19 / 統合 6 / 廃止 7 + 整理 5。切替順序 M-0〜M-9)。**RAG は第 1 リリースに含め設計は別トピック** (LM-Q6) |
| AC-4.1 | `make doc-lint` が 0 エラー | **達成 (継続)** |
| AC-4.2 | `aidlc-docs/reviews/<feature>/review.md` の存在 (push ゲートが強制) | **達成** — `reviews/productionization/` に 13 本 (最新は 2026-07-31 の `review-auth-accounts.md` / `review-auth-round5.md` / `review-round4.md`) |
| AC-4.3 | 引き渡し物チェックリスト (`docs/design/architecture.md` §7) | 部分 |
| AC-5.1 | `docs/design/architecture.md` §3.3 の責務表 (**6 パッケージ層**) + §3.4 の**層配置の判断基準** + §3.5 の**依存規則 L-1〜L-6** + §3.10 の**会話 1 ターンの配置例 (19 ステップ)** | **記述あり**。増分 layering で定義を更新 ([requirements-layering.md](requirements-layering.md) §7)。レビュー: `aidlc-docs/reviews/productionization/review-layering.md` |
| AC-5.2 | `templates/` (backend / frontend / infra の 3 セット) の CI・pre-commit・エージェント定義が TDD/lint を強制 | **雛形済み** (確定はレビュー後) |

## タスクと依存関係

### Phase 0: 棚卸しと骨格 — 完了

1. ~~PoC 棚卸し~~ → `docs/analysis/poc-inventory.md`
2. ~~ギャップ分析~~ → `docs/analysis/gap-analysis.md`
3. ~~アーキテクチャ骨格~~ → `docs/design/architecture.md` (v0.1)
4. ~~ハーネス構築~~ → `.claude/` + `scripts/` + `templates/` (backend / frontend / infra の 3 セット)

### Phase 1: 分岐の解消 (直列・ここがボトルネック) — **一部完了**

5. **Q-1〜Q-9 の回答取得** ← ユーザー判断。未回答なら推奨案を既定採用として明記して進む
   - ~~Q-2 (3 リポ分割) / Q-4 (Dify 廃止) / Q-5 (全面切替) / Q-6 (上限なし)~~ → **回答済み・反映済み** (C-9〜C-12)
   - Q-1 (データモデル) / Q-3 (スコープ): **検討中** — 判断材料を questions.md に追記済み。
     Q-1 は **Task-2f (既存データ量) が判断材料**
   - Q-7 (IaC) / Q-8 (フラグ): **解説を追記して再質問中**
   - Q-9 (Dify 廃止の移行方針): **新規起票** — Task-2e が判断材料
6. 回答を requirements.md へ反映 (`[Answer]:` の書き戻しと §5 機能要件の確定)

> **Q-1 と Q-3 は Phase 2 の一部より後でよい**: Task-2e / 2f の結果が判断材料になるため、
> 「全部答えてから調査」ではなく「調査しながら答える」順序が合理的。
> ただし **Phase 3 (設計確定) には Q-1 の回答が必須**。

### Phase 2: 深掘り調査 — **2a / 2b / 2c / 2e / 2g 完了 (抜き取り検証済み)。残: 2d (プロンプト棚卸し) / 2f (データ量確認・ユーザー側)**

Q-3=A (会話型フローのみ) を前提とした場合:

- [x] **Task-2a** (完了・**抜き取り検証済み** 2026-07-29): PoC の会話フロー詳細調査 → `docs/analysis/poc-conversation-flow.md` — SSE イベント仕様・台帳のフィールド・
      9 tools の入出力スキーマ・エラー時の挙動 ← `poc-analyst`
- [x] **Task-2b** (完了・**抜き取り検証済み** 2026-07-29): v2 の認証・アカウント基盤の詳細調査 → `docs/analysis/v2-auth-tenancy.md` — トークン発行/検証・ロール判定・
      `accounts` / `companies` / `contracts` の関係 ← `poc-analyst`
- [x] **Task-2c** (完了・**抜き取り検証済み** 2026-07-29): v2 のデプロイ・シークレット・ログ基盤 → `docs/analysis/v2-deploy-observability.md` — ecspresso のタスク定義・
      環境変数の受け渡し・logger の実装 ← `poc-analyst`
- [x] **Task-2d** (完了・**抜き取り検証済み** 2026-07-30): PoC プロンプト資産の棚卸し → `docs/analysis/poc-prompt-inventory.md` — **Agent 再発行対象は 4 プロンプトのみ** (diverge / chat / plan / orchestrator)、他は全て直接 API でコードデプロイのみで反映。重複・散在 5 件 (発散 4 軸の 2 系統分裂・評価 3 実装・企画書 3 方式ほか) と未配線資産 (`research_system.md` / `internal/agent/diverge/` 一式) を確認 ← `poc-analyst`
- [x] **Task-2e**: **v2 の Dify 依存の棚卸し** → `docs/analysis/dify-inventory.md` (完了。2026-07-28)
      **重要な発見**: Dify は v2 で既に dead code 化しており、主要機能は v2 の llm 層へ移行済み。
      Q-9 の「v3 で全部作り直す」の実体は「v2 の現行 LLM 機能を v3 へ移植する」こと。
      **残る未調査**: research_chat / idea / company_info_from_url / extract_json の現行経路、
      各機能が実際に使っているモデル (C-9 のモデル見直しの入力) ← 追加調査が必要
- [ ] **Task-2f**: **v2 本番の既存データ量の確認** (Q-1 の判断材料) — themes / ideas /
      business_plans 等の件数と、切替時に引き継ぐ必要のある範囲。**DB への接続が要るためユーザー側で確認** ← 手動
- [x] **Task-2g** (完了・**抜き取り検証済み** 2026-07-29): **v2 の現行 LLM 経路とモデルの棚卸し** → `docs/analysis/v2-llm-inventory.md` (dify-inventory.md §5 の未調査分) —
      research_chat / idea / company_info_from_url / extract_json が今どの経路で動いているか、
      各機能が `llm/types.go` のどのモデルを選んでいるか ← `poc-analyst`

> **各報告は取り込む前に抜き取り検証する** (`orchestrating-delegation` skill ③)。
> 検証していない事実を設計に書かない (DR-1)。
>
> **抜き取り検証の対象** (報告が返ってきたら最低これを一次ソースで照合する):
> - Task-2a: 9 tools の schema ↔ handler ↔ prompt の不一致指摘 / SSE イベント名の実在 / 台帳フィールドの write 経路
> - Task-2b: トークンヘッダ名とロール値 / 所有者絞り込みの層 (パス:行) / 401-403-404 の分岐箇所
> - Task-2c: ロールバック手段の有無 / secrets の参照方式 / IaC 定義の不在
> - Task-2g: **モデル名と機能の対応** (推測混入が最も設計を誤らせる) / 4 機能の現行経路の判定根拠

### Phase 3: 設計確定 (Task-2 の検証済み報告に依存)

- [x] **Task-3a** (起草完了 2026-07-30・**レビュー未実施**): `docs/design/data-model.md` (AC-1.2 / AC-3.4 / A-3 / A-4 / DR-3) —
      設計判断 DM-1〜DM-20・**テーブル 40 (全件に `contract_id`) + 例外 11**・採番と冪等性 (BE-11)・
      台帳のスキーマ契約 (BE-10 / BE-12)・派生物の無効化 (BE-4)・マイグレーション方式と投入順序。
      **Q-1 の未確定は「データ引き継ぎ範囲」だけ**と切り分け、移行部分のみ `[Answer]` ゲート (DM-A1〜A3)。
      **他文書への是正要求 8 件**を起票 (うち 3 件はメインセッションが即日反映)。旧記述: ← `architecture-designer`。
      **追加要件 (2026-07-30)**: 認証系 API を v3 で実装する決定 (`docs/design/auth.md` §9.3 Q-A8) により、
      **併用期間中のアカウント基盤の二重化** (パスワード・MFA 設定・ロック状態をどちらを正とするか、
      移行のタイミング) を扱う (同 §10.2 R-1 / AC-3.5)
- [x] **Task-3i** (**起草完了 2026-07-31・レビュー未実施**): → `docs/design/API/auth-accounts.md` (37 エンドポイント =
      公開 6 / ユーザー認証 21 + MFA 未検証可 2 / 社内管理者 6 + MFA 未検証可 2。設計判断 AA-D-1〜16)。
      **v2 の新発見欠陥 3 件** (V2-D1: signup が招待リンクの email と入力 email を突き合わせない —
      `hassan-v2-backend/usecase/account/sign_up.go:40`〜 で**オーケストレーターが一次ソース照合済み・実在** /
      V2-D2: MFA 不一致が 500 / V2-D3: リセットトークンを応答に含める DTO) を構造で潰した。
      auth.md への是正要求 R-AA-1〜9 を §5 に起票 (auth.md は別セッション担当のため未編集)。
      **AA-Q1〜Q3 は同日ユーザー回答済み・反映済み**: AA-Q1=移植しない (PoC にも会社単位ミッションは無いと照合済み。
      提供終了は operations §6.3.1 の告知対象へ) / AA-Q2=含める (auth.md §6.2 への列挙追加は R-AA-12) /
      AA-Q3=**解除しない** (当初案を反転 — リセットはロックを外さず、解除は管理者経由のみ)。
      旧記述: 認証・アカウント基盤 API の入出力仕様
- [x] **Task-3i-R2** (**指摘反映完了 2026-07-31 → 再レビュー待ち**): **2 系統のレビュー指摘を全件反映した**。
      ①**旧レビュー 17 件** (重大 3 / 中 10 / 軽微 4) ②**別セッションの 1 巡目レビュー**
      ([review-auth-accounts.md](../../reviews/productionization/review-auth-accounts.md)。重大 6 / 中 11 / 軽微 7)。
      **主な確定**: **`CodedError` の分類付き値域** (`AU-T-` = トークン失効 → セッション破棄 /
      `AU-C-` = 提示資格情報の不一致 → フォーム内エラー / 未知は fail-safe で破棄。auth-accounts.md §3.1.1) —
      **TOTP の打ち間違いで強制ログアウトする問題を構造的に解消** /
      **AA-D-17** (認証済みの状態変更に添える本人確認は 400) / **AA-D-21** (認証失敗の監査記録は
      `audit_logs` の `actor_id`/`contract_id` を NULL 可 + CHECK。メールは HMAC-SHA256 + pepper) /
      **AA-D-5④** (招待・リセットの秘密は `crypto/rand` 32B → base64url、**DB にはハッシュのみ**)。
      **是正要求は R-AA-1〜22** (data-model 4 件 / auth.md 4 件 / frontend.md 2 件 / observability 1 件ほか)。
      **メインセッション担当分は完了**: README.md §2.5 の範囲限定 + 429 を 8→11 本 / frontend.md の
      401 分岐をコード接頭辞ベースへ・`/settings/profile` 新設・`[未確定]` 11 行を `[API]` へ /
      **`scripts/check-endpoint-mapping.sh` を新設し `make check` に組み込み** (R-AA-22。故障注入 2 種で検出力確認済み)
- [x] **Task-3i-R3** (**2 巡目レビューと反映が完了 2026-07-31**): 再レビュー
      ([review-auth-accounts-round2.md](../../reviews/productionization/review-auth-accounts-round2.md)) は
      **1 巡目の 34 件すべて解消**を確認。新規 **重大 3 / 中 7 / 軽微 4 も全件反映済み**。
      **新規重大は設計の誤りではなく並行編集による文書間の割れ**だった: ①`audit_logs` の形が 3 文書で不一致
      (data-model が `actor_type='unauthenticated'` + CHECK を先に採用 → **スキーマの SSOT に合わせた**。
      ただし **`detail.email_hash` は HMAC-SHA256 + pepper を維持** = 2026-07-31 ユーザー決定。
      **素の SHA-256 はメールアドレスの低エントロピーゆえ総当たりで復元でき、「平文を保存しない」目的を達成しない**) /
      ②`reset_password_requests` の列名 (data-model の `token_hash` に合わせた) と §5 状態列 13 行の陳腐化 /
      ③AA-D-17 (400) が README・frontend で 401 のまま → **メインセッションが両方修正**。
      **メインセッション担当の機構 2 件も完了**: R-AA-24 (README の旧 ID 参照) / **R-AA-25 (`check-endpoint-mapping.sh` に
      照合 3 件を追加 = 429 の本数 ×2・CodedError コード表の行数。照合 5 → 8 件。故障注入 4 種で検出力確認済み)**
- [ ] **Task-3i-R4** (**残作業 = 他文書側の是正要求のみ**): 本書側の反映は完了しており、残るは**他文書担当への引き継ぎ**。
      優先順: ①**data-model.md §4.10 の `detail` の例を HMAC-SHA256 + pepper に改める** (R-AA-19 の残 1 点。
      現状は「記録項目の SSOT は observability.md §4.5」と書きながら例が素の SHA-256 で**参照先と矛盾** = BE-12) /
      ②**data-model.md の R-AA-17** (`signup_links` の `UNIQUE (contract_id, email)`。**RL-2 前に必要な唯一の DB 制約**。
      無いと再送の同時押しで有効リンクが 2 本残る = BE-11) / ③**auth.md の R-AA-15** (公開ホワイトリストが旧パスのまま。
      **CI 検査の入力なので確定で事故る**) / R-AA-2a / R-AA-1 / R-AA-20 / ④operations.md の R-AA-23 (pepper の棚卸し) /
      ⑤observability.md の R-AA-7③ (`action` 値域に不足 7 値)。**これらは並行セッションが該当ファイルを編集中のため未着手**
      (ユーザー判断 2026-07-31: 別セッションに任せる)。**旧記述**: ①再レビュー ②他文書側の是正要求の反映 —
      data-model.md (R-AA-4 / 18 / 19 / 21。**R-AA-18 と R-AA-5 は同じ差分で扱う** — 除外リストの件数が中間状態でずれるため) /
      auth.md (R-AA-2a / 8 / 9 / 15 / 20) / observability.md (R-AA-7) / frontend.md の残り (R-AA-10 / 16 は反映済み)。
      **旧レビューの記録は下行**
- [x] **Task-3i-R** (**第 1 波のレビュー・反映済み 2026-07-31**): [review-auth-accounts.md](../../reviews/productionization/review-auth-accounts.md)
      = **Design Freeze 不可 (重大 3 / 中 10 / 軽微 4)**。**重大 3 件はオーケストレーターが一次ソースで成立を確認済み**:
      **M-1** = AA-D-9 (401 + 本文) が [frontend.md](../../../docs/design/frontend.md):657 の「401 → `/api/logout`」と衝突し、
      **TOTP 打ち間違い 1 回でログアウトする** (同行は「BE は 401 に本文を返さない」とも書いており二重の矛盾) /
      **M-2** = [auth.md](../../../docs/design/auth.md):149・:151 の公開ホワイトリストが具体パスで
      `GET /accounts/signup-links/:id` / `POST /accounts/reset-password/:hash` を宣言しているのに AA-D-4 が両方変更 —
      **CI の系統一致検査が原理的に落ちる**のに是正要求が無い /
      **M-3** = §2.3.1 の 6 本 (プロフィール・パスワード・アイコン・メール変更) に対応する FE 画面が
      frontend.md に **0 件** (BE-10 の消費者不在)。
      併せて **R-AA-10 の ID 重複はメインセッションが即日解消** (追加分を R-AA-12 へ改番)。
      **v2 の事実照合は完了済み** ([verification-auth-accounts.md](../../reviews/productionization/verification-auth-accounts.md) — 7 件一致・不一致 0)
      (`signin` / `signup` / パスワードリセット / MFA / メンバー管理 / 会社情報 +
      **アカウント手動ロック / 解除**) を起草 (AC-1.1 / AC-1.4 / AC-1.5 / AC-1.6)。
      移植対象の一覧は `docs/design/API/settings.md` §5、認証・認可の規約は `docs/design/auth.md`。
      **v2 の欠陥を引き継がないこと** (同 §5-8 / §5-9 / §5-11) ← `architecture-designer`。
      **起草可能になった (2026-07-31)**: 前提の R-1 = DM-A3 (アカウント基盤二重化は推奨 5 点で確定) と
      DM-A4 (`signup_links` に `contract_id` = B) をユーザーが回答 (`docs/design/data-model.md` §6.5 / §8.1)。
      追加入力: E2E 用の「MFA 無効アカウント」の例外表現 (testing.md T-Q3=B) / 管理者トークン有効期間 7 日 (frontend.md FE-Q8)
- [ ] **Task-3p** (新規 2026-07-31): **会話型アイデア創出 API の設計** (SSE イベント型 = frontend.md FE-Q1 のブロック解消)。
      **着手は Task-3i の後** (ユーザー決定 2026-07-31)。スコープ: ①会話・アーティファクトのエンドポイントと
      SSE イベント型 ②**LM-Q1 の統合設計** (発散後チャット P-3 を P-1 へ統合 — Agent 3 本構成) ③**LM-Q2 の統合設計**
      (v2 のアイデア生成・企画書生成・カスタムリサーチを会話フロー / ナレッジへ統合) ④更新版プロトタイプの新 UI
      (アーティファクトのバージョン管理 = BE-1 対応・発散設計ウィジェット・持ち込み PDF・企画書 8 サブタブ) の API 対応
      ⑤idea-boards.md IB-Q11 (企画書サマリの結合フィールド) の形の確定
      ⑥**持ち込み PDF のアップロード経路** — `docs/design/API/assets.md` §5 の **AS-Q11** が制約の SSOT。
      **4 系統目を作らず既存 3 系統のどれかに寄せる (または共通基盤へ統合する)** こと。D-AS-4 は
      「3 系統になる」ことを理由に専用 API を却下しているため、4 系統目を黙って足すとその判断の根拠が崩れる
      ← `architecture-designer`
- [x] **Task-3b**: `docs/design/API/` (AC-1.1 / AC-1.4) — 全 7 ファイル記述済み (README = 共通規約 + 総覧の SSOT、
      themes / assets / knowledge / idea-boards / news / settings。計 73 エンドポイント。2026-07-29)。レビュー未実施。
      **注 (2026-07-30)**: **認証・アカウント基盤の約 30 エンドポイントは本タスクの範囲外** — Task-3i が担う
      (D-ST-1' による方針反転。`docs/design/API/README.md` §3 の注記)。**Phase 3 の完了条件には Task-3i を含む**
- [x] **Task-3c** (完了 2026-07-29): `docs/design/observability.md` (AC-2.1〜2.5 / O-1〜O-7 に回答)。分散トレースは先送り (理由と再検討契機を明記)
- [x] **Task-3d** (起草完了 2026-07-30・**レビュー未実施**): `docs/design/operations.md` (AC-3.1 / AC-3.3 / AC-3.5 / AC-3.7 / D-1・D-3・D-5・D-7) —
      設計判断 OP-A〜OP-J (全件却下案付き)・全面切替の段階 RL-0〜RL-5・DB 変更 8 種の分類。
      未確定 4 件を明示 (D-4 ツール選定・アラート宛先の [Answer] × 2 / Q-8 は暫定既定 / 公開方式ケース A・B は Q-1 と同時決定) ← `architecture-designer`
- [x] **Task-3e** (起草完了 2026-07-30・**レビュー未実施**): `docs/design/infrastructure.md` (AC-3.6 / D-8) —
      設計判断 INF-A〜INF-O (全件却下案付き)・提案 40 要素・Terraform/ecspresso 分担・環境差・構築順序・IaC 範囲外 10 件。
      **インフラ要素一覧は「提案」であり確定はユーザー確認待ち** ([Answer]: × 4 を §11.1 に配置。
      [design_memo.md](../../../docs/design/design_memo.md) の TODO に対応する確認リストを提供) ← `architecture-designer`
- [x] **Task-3h** (起草完了 2026-07-30・**レビュー未実施**): `docs/design/llm-migration.md` (AC-3.8) —
      設計判断 LM-A〜LM-J・判定手順 5 段・移行表・用途カテゴリ別モデルと SSOT (`config` の 1 表)・
      実測条件・散在 5 件の 1 本化・切替順序・品質確認 3 段 ← `architecture-designer`。
      **更新 (2026-07-31)**: LM-Q1〜Q4・Q6 のユーザー回答を反映し集計が変わった —
      **Managed Agent 3 (P-3 は P-1 へ統合) / 直接 API 19 / 統合により独立移植しない 6 (P-3 + V-1〜V-3・V-6・V-12) /
      機能の廃止 7 件 (X-1〜X-5・X-8 + リサーチシート X-12) + 資産・命名の整理 5 件**。
      RAG は第 1 リリースに含め、設計は別トピックへ切り出し (LM-Q6)。**未回答は LM-Q5 (A/B 評価体制) のみ**
- [x] **Task-3j** (完了 2026-07-30): `docs/design/API/knowledge.md` の KN-Q2 を **「直接 LLM API」で確定**し
      [llm-migration.md](../../../docs/design/llm-migration.md) §4 を SSOT として参照。併せて `settings.md` の
      「llm-migration.md (未着手)」2 箇所をリンクへ差し替え (レビュー軽微 4 の解消) ← メインセッション
- [x] **Task-3f**: `docs/design/architecture.md` §3 に**層配置の判断基準 (4 問の決定木) + 会話 1 ターンの配置例 + 迷いやすい 3 点**を追記 (AC-5.1 / D-A' 確定。2026-07-28)
> **オーケストレーターの抜き取り検証 (2026-07-30。正式レビューはセッション上限で中断中)**:
> `data-model.md` について 6 件照合し、**4 件は一致・2 件の発見**があった。**正式レビュー時に確認させる**:
>
> | # | 結果 |
> |---|---|
> | 1 | 所有者列の機械照合 = **39/39 一致** (`contract_id` 空欄 0 件) ✅ |
> | 2 | v2 の引用行 (`ideas.asset_ids` :171 / `idea_hassans.asset_ids` :125 / enum 6 個) = **一致** ✅ (起草者の自己修正後の値) |
> | 3 | BE-11 (採番) = **構造で解消済み** ✅ — 採番と Insert を 1 SQL に閉じ、「版番号を引数で受け取るメソッドを作らない」まで規約化 |
> | 4 | BE-10 / BE-12 (台帳) = **構造で解消済み** ✅ — 型の SSOT を `entity/conversation` に置き、13 フィールドすべてに書き手と読み手を対で明記 |
> | 5 | **発見 A**: 是正要求 R-DM-4 は**妥当** — `auth_rate_limit_counters` は [auth.md](../../../docs/design/auth.md) §6.3 の例外列挙 (有限列挙と宣言) に**実在しない**。同節は「ここに無いテーブルに例外を認めない」と書いているため、追加しないと機械検査で弾かれる |
> | 6 | **発見 B (起草者の報告に無い)**: §4.1.2 の「例外 11 件」は**2 種類の例外を混在**させている。`accounts` / `companies` / `signup_links` は `contract_id` を、`account_mfa_configs` / `reset_password_requests` は `account_id` を**実際に持っており**、§6.3 (所有者列を持てない) の例外ではなく **§6.4 のクエリ側許可リスト**の話である。**所有者列を真に持たないのは 6 件**。「例外 11 件」という数字が AC-1.2 の充足範囲を曖昧にする |

- [x] **Task-3k** (起草完了 2026-07-30・**レビュー未実施**): `docs/design/testing.md` (C-8 / AC-5.2 / D-2 / A-4 / A-6 / O-4) —
      設計判断 T-A〜T-O・段と担保範囲 (U / I / C / E)・層ごとのモック境界・**LLM 経路のテスト**・
      **テナント越境の必須範囲** (全 route + 全 tool)・E2E 5 本 (暫定)・テストデータ・CI 割り当て。
      未確定 T-Q1〜T-Q4 を `[Answer]:` で起票。**v2 の実態を実測**: DB を伴うテスト 0 件 /
      repository のテスト 0 件 / frontend に CI と単体テスト基盤が無い / E2E が `test.skip` で緑になる ← `architecture-designer`
- [ ] **Task-3k** (新規 2026-07-30): **`docs/design/testing.md`** — テスト戦略 (段と担保範囲 / 層ごとの方針 /
      **LLM を含む経路のテスト** / テナント越境 / **E2E (Playwright)** / テストデータ / CI 実行時間)。
      **design_memo.md の「結合テストやりたい — playwright」に対する設計上の回答が存在しなかった** ← `architecture-designer`
- [x] **Task-3l** (起草完了 2026-07-30・**レビュー未実施**): **`docs/design/frontend.md`** — 設計判断 FE-A〜FE-N (14 件)・
      依存規則 L-F1〜L-F6・SSE 共通クライアント S-1〜S-8・トークン 5 系統・**FE-1〜FE-7 の全件対応表**。
      **v2 の実測で判明した最大の論点**: `'use client'` から **BE の JWT をヘッダに入れてブラウザが直接 BE を叩いている**
      (`hassan-v2-frontend/src/features/research/components/research-list-form.tsx:73` →
      `.../actions/create-stream-research-chat.ts:23`。オーケストレーター照合済み) /
      `X-Token` と `X-Admin-Token` に常に同じ値を送る (`src/lib/api-client.ts:44`〜`:45`) /
      **eslint に依存方向・トークン強制のルールが 1 つも無い**。未確定 FE-Q1〜Q6 を起票 ← `architecture-designer`
- [x] **Task-3m** (完了 2026-07-30): frontend 雛形に**機構**を追加 —
      ①**`.eslintrc.json.tmpl` を新規作成** (L-F1〜L-F6 の zone / 生 hex と `style` 属性の禁止 / `fetch` の直呼び禁止。
      **雛形に eslint 設定が 1 つも無く、FE-3 / FE-5 の担保が文書だけだった**のを解消)
      ②`ci.yml` に**検査 4 本**を追加 (併置テストの存在 / 公開パス許可リストの照合 / `NEXT_PUBLIC_` 許可リスト /
      `globals.css` の行数可視化) ③`templates/README.md` の立ち上げ手順に eslint 設定のリネームを追記 ← メインセッション
- [ ] **旧記述 (Task-3l の当初定義)**: FE の構造設計
      (ディレクトリ規約 / 状態管理 / **SSE 共通クライアント** / デザイントークン / orval 生成型の扱い /
      プロトタイプの設計入力としての扱い / FE-1〜FE-7 を構造で潰す方針)。
      **3 リポのうち frontend だけ設計書が無い** (雛形 `templates/frontend-repo/CLAUDE.md.tmpl` に規約の断片のみ) ← `architecture-designer`
- [ ] **Task-3g**: `docs/design/architecture.md` の §4 §6 を確定に更新 ← メインセッション
- [x] **Task-3n** (完了 2026-07-30): **プロトタイプ更新の設計反映** — `docs/prototype/hassan_agent_prototype_v2.html` が
      更新版 (15,022 行) に差し替わったため、①正準名へのリネーム (リンク切れ 2 件の解消) ②全設計文書の
      引用行番号を実測値へ更新 (約 30 箇所) ③画面差分の事実を各設計文書へ追記 ④判断が要る差分を `[Answer]:` で起票 —
      **themes.md §6 (TH-Q6 stats 指標 / TH-Q7 mission 統合 / TH-Q8 アーカイブ存否 / TH-Q9 ナレッジ件数)**、
      **settings.md §7.1 (ST-Q8 workspace セクション消滅 / ST-Q9 usage-summary の形)**、
      **idea-boards.md §6.1 (IB-Q11 企画書列 / IB-Q12 一覧 KPI / IB-Q13 comment_count ソート)**、
      **knowledge.md KN-Q8〜Q10 (sort 値域 / 削除と引用整合 / ファイル管理スコープ)**。
      クローズしたもの: TH-Q1 (テーマエクスポート消滅)・AS-Q2 (AI で探す消滅)・AS-Q3 (一括インポート消滅)。
      会話ビューの新 UI (バージョン管理・発散設計ウィジェット・持ち込み PDF・企画書 8 サブタブ) は
      frontend.md FE-Q1 に会話 API 設計の入力として追記 ← メインセッション。
      **[Answer] × 9 は同日ユーザー回答済み・反映済み**: TH-Q6=a (stats 4 指標・status 廃止) /
      TH-Q7=a (mission 統合) / TH-Q8=a (アーカイブ廃止 — data-model R-DM-1 の①も同時解消) /
      TH-Q9=a (knowledge_count) / ST-Q8=a (workspace を増分 2 へ) / ST-Q9=a (usage-summary をクロス集計形へ —
      DM-Q5 解消) / IB-Q11=a (企画書サマリはサーバ結合) / IB-Q12=**b** (KPI は一覧に同梱) / IB-Q13=a (comment_count ソート + theme_id)

> 3a と 3b は**同一のデータ構造に依存する**ため、3a → 3b の順。3c / 3d / 3e は並列可能。
> 3f が兼ねていた Service 層の責務境界 (D-A') の確定は、**増分 layering で完了した**
> ([requirements-layering.md](requirements-layering.md) の C-L1〜C-L12 / 依存規則 L-1〜L-6)。
>
> **Task-3i は Task-3a の R-1 (アカウント基盤の二重化) の結論に依存する** (2026-07-30 追加)。
> 「移行前は v3 の signin が v2 の資格情報を参照する」のか「v3 に移行済みのアカウントだけが
> v3 で signin できる」のかで、`POST /signin` の入出力・エラー・FE の分岐がすべて変わるため、
> **R-1 が決まる前に 3i の入出力仕様は起草できない** (順序: 3a の R-1 → 3i)。
> 併せて **`docs/design/auth.md` §6.3 の例外テーブル列挙と §6.4 の許可リスト**も確定させる
> (**2026-07-31 に完了** — R-1 は `docs/design/data-model.md` §6.5 の DM-A3 で回答済み。auth.md §9.1 の表を参照)。

### Phase 4: レビューと引き渡し — **1 巡目完了 (2026-07-29)**

- [x] **Task-4a** (完了): 別セッションで `design-reviewer` を 2 本 (AC-4.2)
      - [review-architecture-observability.md](../../reviews/productionization/review-architecture-observability.md) — 重大 5 / 中 16 / 軽微 9
      - [review-auth-api.md](../../reviews/productionization/review-auth-api.md) — 重大 7 / 中 10 / 軽微 5
      - 両レビューとも **Design Freeze 不可** の判定。指摘の一次ソース照合は計 51 件で、**設計文書側の事実誤りは 0 件**
- [~] **Task-4b** (進行中): 指摘反映 → 再レビュー
      - **反映済み (レビュー A の重大 5 件すべて)**: ①トランザクション受け渡し機構を定義し
        「Service → UseCase 禁止」との矛盾を解消 (architecture.md の D-A'') ②CI ゲート 3 本を雛形に配置
        + deploy ワークフロー雛形を新規作成 (AC-3.3) + D-2 / D-6 の表現を実態に合わせた
        ③pre-commit 3 本の実行権限を付与 + **CI に実行権限チェックを追加** (再発防止)
        ④LLM 明細に cache トークン 2 種を追加 (単価も 4 種に分離) ⑤D-B'' を「インターフェース再設計」に格上げ
      - **未反映**: レビュー A の中 16 / 軽微 9、**レビュー B の重大 7 件すべて** (対象は `docs/design/auth.md` と
        `docs/design/API/` = 別セッションが起草。**起草側での修正が必要**)
- [ ] **Task-4c**: 実装リポジトリの立ち上げ (`templates/README.md` の手順) と引き渡し (AC-4.3)

## 並列実行可能なタスク

| フェーズ | 並列可能 | 直列必須の理由 |
|---|---|---|
| Phase 2 | Task-2a / 2b / 2c / 2d / 2e (5 並列) + 2f (手動) | 参照対象が別リポ・別ドメインで衝突しない |
| Phase 3 | (3a → 3b) と (**3a の R-1 → 3i**) と 3c と 3d と 3e と 3h の 6 系列 | 3b は 3a のデータ構造に依存。**3i は 3a の R-1 (アカウント基盤の二重化) の結論に依存**。3f/3g は他タスクの結果を統合するため最後 |
| Phase 4 | なし | レビューは差分全体を 1 セッションで集約する |

## 完了の定義 (Design Freeze)

- `make check` が通る (リンク切れ・参照先不在ゼロ / AC 未カバーゼロ)
- `.claude/rules/08-production-gates.md` の全 ID に回答または「対象外の理由 + 先送り先」
- 別セッションの `design-reviewer` で重大事項ゼロ
- 実装リポへの引き渡し情報 (影響レイヤー・依存順序・並列可能タスク・参照すべき既存実装) が揃っている
