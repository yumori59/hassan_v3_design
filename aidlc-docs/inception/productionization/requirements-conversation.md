# Requirements (増分: conversation): 会話型アイデア創出 API (会話 / アイデア / 企画書)

> 親要件: [requirements.md](requirements.md) (AC-1.1〜AC-5.2 は有効。本書は **AC-CV-1.1〜AC-CV-6.4 を追加**する — §9)。
> 先行増分: [requirements-layering.md](requirements-layering.md) (AC-6.1〜AC-6.23。層構成・ツール注入・計測点は同書が SSOT)
> 質問: [questions-conversation.md](questions-conversation.md) — **CV-Q1〜CV-Q13 は 2026-08-01 に全件ユーザー回答済み。暫定既定は 1 件も残っていない**
> 計画: [plan.md](plan.md) の **Task-3p**
> 新設対象 (本書の受入基準が向く先): `docs/design/API/conversation.md` / `docs/design/API/ideas.md` / `docs/design/API/plans.md` (いずれも未作成)
> 改訂対象: [API/README.md](../../../docs/design/API/README.md) / [API/idea-boards.md](../../../docs/design/API/idea-boards.md) / [data-model.md](../../../docs/design/data-model.md) / [llm-migration.md](../../../docs/design/llm-migration.md) / [frontend.md](../../../docs/design/frontend.md) / [API/assets.md](../../../docs/design/API/assets.md) / [v2-feature-inventory.md](../../../docs/analysis/v2-feature-inventory.md) (詳細は §5)
> 本番観点の ID 一覧: [08-production-gates.md](../../../.claude/rules/08-production-gates.md)
>
> ステータス: **確定**。設計起草 (`architecture-designer`) の入力として使える状態。

## 1. 目的とスコープ

[API/README.md](../../../docs/design/API/README.md) §0 が「本ディレクトリの対象外」と宣言した
**会話型アイデア創出**の API を確定させ、あわせて **v2 のアイデア系 13 本と企画書系 18 本の受け先**を
確定させる。本増分の完了により、[frontend.md](../../../docs/design/frontend.md) §16.1 の **FE-Q1** が解け、
会話画面が実装着手可能になる。

### 1.1 スコープ内

| # | 領域 | 内容 | 主な出力先 |
|---|---|---|---|
| 1 | **会話** | 会話セッションの作成・一覧・取得・削除、会話ターン (同期 SSE)、SSE イベント型、発話履歴、custom tool の集合と契約、台帳の読み書き、stage の導出 | `docs/design/API/conversation.md` |
| 2 | **アイデア** | 生成 (会話ターン経由) / 人手の作成・更新・削除 (REST)、`tags` の書き込み、版 (`idea_versions`) の参照と復元、評価 | `docs/design/API/ideas.md` |
| 3 | **企画書** | 8 タブの生成・取得・タブ単位の再生成・版・お気に入り・チャット・詳細版セクション・サムネイル、**v2 の企画書 18 エンドポイントすべての受け先** | `docs/design/API/plans.md` |

### 1.2 スコープ外 (本増分では扱わない)

- **層構成・ツール注入の内部構造・LLM 計測点** — [requirements-layering.md](requirements-layering.md) の
  C-L9 / AC-6.7 / AC-6.8 / AC-6.16 が SSOT。本書は「その構造の上で何を作るか」だけを定める
- **会話まわりのテーブル定義そのもの** — [data-model.md](../../../docs/design/data-model.md) §4.5 / §4.6 / §4.11 が SSOT。
  本書は**同書への是正要求** (§5) の形でのみ関与する
- **RAG (ナレッジ検索)** — 別トピック (LM-Q6)
- **v2 の社内管理者機能** — [requirements.md](requirements.md) §2 の C-16 例外表と
  [auth.md](../../../docs/design/auth.md) §6.2 の 2026-07-30 決定に従う
- **製品コードの実装** (本リポジトリに製品コードは置かない)

### 1.3 CV-Q1=B の帰結 — 第 1 リリース範囲の拡大

**CV-Q1 の回答は推奨 A ではなく B**であり、**v2 の企画書 18 エンドポイントすべてを第 1 リリースで
設計・実装する**。これは C-16 (v2 にある操作は落とさない) を最も厳格に満たす選択で、
併用期間中の機能差をゼロにする。**次の 3 つの帰結が本書の要件になる**:

1. **[llm-migration.md](../../../docs/design/llm-migration.md) §4.2 の優先度判定と衝突する** —
   同書は V-8 (企画書チャット) / V-9 (サムネイル) / V-10 (詳細セクション分析 7 種) / V-11 (詳細版 Web リサーチ) を
   **優先度 2〜3 = v2 併用期間 (§7.1 の M-8 / RL-4)** と判定している。**是正要求として起票する** (§5 の R-CV-1)。
   無言の逸脱にしない
2. **[v2-feature-inventory.md](../../../docs/analysis/v2-feature-inventory.md) §5 の未解決 2 件をクローズする** —
   **#9 企画書のお気に入り** / **#10 版履歴のプロンプト編集**。どちらも「一般ユーザー向け機能で、
   対象外とした明示的な判断が見つからない」として残っていたもの (§5 の R-CV-4 / R-CV-5 / R-CV-10)
3. **データモデルに受け皿が無い機能が 4 つある** (§2 の F-CV2〜F-CV6)。テーブル追加を伴うため、
   [data-model.md](../../../docs/design/data-model.md) への是正要求と `make check-table-counts` の
   期待値更新がセットになる (DR-9)

## 2. 前提事実 (実測。出典付き)

> **すべて本増分の起草時 (2026-08-01) にメインセッションが一次ソースで実測した**。推測は含まない。
> DR-1 (出典なしの断定) を避けるため、以降の要件は本表の ID を参照する。
> PoC の会話フローの事実は [poc-conversation-flow.md](../../../docs/analysis/poc-conversation-flow.md)
> (2026-07-29 実測・抜き取り検証済み) が SSOT であり、本表では再掲しない。

| ID | 事実 | 出典 |
|---|---|---|
| **F-CV1** | v2 の `business_plans.idea_id` は **NOT NULL だがユニークではない** (張られているのは通常インデックス)。**スキーマ上は 1 アイデアに複数の企画書行を許す**。一方 v3 の `plans` は **`UNIQUE (idea_id) WHERE deleted_at IS NULL`** で 1 アイデア 1 件に限定している。**実運用で複数行が作られているかは未調査** | `hassan-v2-backend/db/schema.sql:184` / `:204` / [data-model.md](../../../docs/design/data-model.md) §4.6 |
| **F-CV2** | v2 の **`business_plan_favorites`** は `(account_id, business_plan_id)` の複合主キーを持つ独立テーブル。**v3 に対応するテーブルが無い** | `hassan-v2-backend/db/schema.sql:206` / [data-model.md](../../../docs/design/data-model.md) §4.6 (`plans` / `plan_tab_versions` のみ) |
| **F-CV3** | v2 の **`business_plan_histories.prompt text NOT NULL DEFAULT ''`** が「版履歴のプロンプト編集」(`PUT /business-plans/:id/histories/:history_id/prompt`) の編集対象。**v3 の `plan_tab_versions` に prompt 相当の列が無い** | `hassan-v2-backend/db/schema.sql:238` / [data-model.md](../../../docs/design/data-model.md) §4.6 |
| **F-CV4** | v2 の企画書チャット (V-8) は **`business_plan_chats` + `business_plan_chat_messages` の 2 テーブル**に履歴を持つ (`conversation_id text` で束ねる)。**v3 に対応するテーブルが無い** | `hassan-v2-backend/db/schema.sql:216` / `:225` |
| **F-CV5** | v2 の企画書サムネイル (V-9) の保存先は **`business_plans.thumbnail_url`** と `business_plan_histories.thumbnail_url` / `business_plans_detailed.thumbnail_url`。**v3 の `plans` に列が無い** | `hassan-v2-backend/db/schema.sql:198` / `:253` / `:270` |
| **F-CV6** | v2 の詳細版セクション (V-10) は **`business_plans_detailed` の 7 つの jsonb 列** (`evaluation_summary` / `pestel_analysis` / `market_analysis` / `competitor_analysis` / `hypothesis_poc` / `technology_analysis` / `legal_regulations`)。**v3 の企画書は 8 タブ**であり、**7 セクション → 8 タブの写像は未定義** | `hassan-v2-backend/db/schema.sql:273`〜`:279` / [llm-migration.md](../../../docs/design/llm-migration.md) §6.2 の 5 |
| **F-CV7** | [llm-migration.md](../../../docs/design/llm-migration.md) §4.2 は **V-8 / V-10 / V-11 を優先度 2〜3、V-9 を 3** と判定し、§7.1 は **M-8 (v2 企画書系) を RL-4 = 併用期間**に置いている。**CV-Q1=B (18 本すべて第 1 リリース) と衝突する** | 同 §4.2 の優先度列 / §7.1 の M-8 行 |
| **F-CV8** | 同 §6.2 の 5 は「**簡易モード (V-6) の出力粒度が 8 タブに写像できるかが未確認**」と明記し、判定を本増分に委譲している。同じ節で「**V-10 は統合対象ではなく独立移送**」とも書いている | [llm-migration.md](../../../docs/design/llm-migration.md) §6.2 の 5 |
| **F-CV9** | [data-model.md](../../../docs/design/data-model.md) §4.5 の `conversation_sessions.theme_id` は現在 **NULL 可**で、FK は **`SET NULL`**、インデックスは **`(theme_id) WHERE theme_id IS NOT NULL`** の部分インデックス。CV-Q8=A (テーマ必須) はこの 3 点すべてを変える | 同 §4.5 |
| **F-CV10** | [API/idea-boards.md](../../../docs/design/API/idea-boards.md) §7 は参照系 3 本を暫定配置し、「**生成系が確定した時点で統合され直す可能性が高い**」を却下理由に書いている。同 §8.1 は `tags` の**書き込み側を本増分に委譲**している (BE-10) | 同 §7 / §8.1 |
| **F-CV11** | `scripts/check-endpoint-mapping.sh` の検査④は「**6 ドメイン**」を前提にファイル実測と [API/README.md](../../../docs/design/API/README.md) §3 の総覧表・小計・注記を機械照合する。**API/ にファイルを足すと同スクリプトの対象集合を広げないと検査が成立しない** | `scripts/check-endpoint-mapping.sh` の検査④ (`DOMAIN` 集合) |

## 3. 確定事項 (CV-D1〜CV-D13 + 既定採用 6 件)

### 3.1 ユーザー回答による確定 (2026-08-01)

| ID | 論点 | 決定 | 設計書に必ず書く「却下案と理由」 |
|---|---|---|---|
| **CV-D1** | 第 1 リリースの機能範囲 | **CV-Q1=B** — v2 の企画書 **18 エンドポイントすべて**を第 1 リリースで設計・実装する | 却下 A (PoC 相当 + CRUD/参照系。付加機能は増分 2): 併用期間中に機能差が残り、C-16 の後ろ倒しに個別承認が要る / 却下 C (v2 企画書は丸ごと増分 2): 会話で生成した 8 タブを後から開く経路が無い |
| **CV-D2** | 成果物の分割 | **CV-Q2=A** — `docs/design/API/` 配下に **`conversation.md` / `ideas.md` / `plans.md`** の 3 本を追加。README §0 の「対象外」宣言を解除。idea-boards.md §7 の参照系 3 本を `ideas.md` へ移設 | 却下 B (1 ファイル): 会話 + アイデア + 企画書で巨大化しコンフリクト範囲が全域に広がる / 却下 C (API/ の外に置く): 共通規約 (README §1・§2) と別ディレクトリになり「会話だけ規約が別」に見える |
| **CV-D3** | 会話ターンの入口 | **CV-Q3=A** — **`POST /conversations/{session_id}/messages` が同期 SSE を返す**。切断時の回復は台帳 GET + 履歴 GET。同一セッションへの並行ターンは **409** (DM-13) | 却下 B (ターンのジョブ化): 進捗の DB ポーリング機構・`turns` テーブル・購読権検証が増え、応答レイテンシにポーリング間隔が乗る。5 分の安全弁がある以上 B の利点が活きない / 却下 C (企画書生成だけジョブ化): 入口が 2 系統になり計測と安全弁の適用が分かれる |
| **CV-D4** | Agent の責務境界 | **CV-Q4=A** — **system prompt 1 本**。サーバが毎ターン「現在の stage と前提の充足状況」を注入する。**ツール集合は常に全数**で、前提を満たさない呼び出しは**ハンドラが構造化エラー (`missing` 付き) で拒否**する | 却下 B (stage ごとにツールを出し分け): `Tools` は Agent リソース側で全置換 (BE-9) のため stage ごとに別 Agent が要り、Agent を 3 本に減らした目的 (D-6 / A-6 の検証点削減) に逆行 / 却下 C (P-3 統合の撤回): LM-Q1 の再議論 |
| **CV-D5** | custom tool の取捨 | **CV-Q5=A** — 「**LLM が呼び出しを決める必要があるか**」で足切りする。**ユーザー操作で起動が決まるもの (タグ編集 / 版の復元 / PDF 添付 / タブ再生成) は REST とし tool にしない**。統合分 (V-1 / V-3 / V-6) は既存ツールの引数で吸収し新ツールを作らない。**`set_theme_name` は廃止** | 却下 B (9 本据え置き・追加禁止): 統合で本当に必要になった場合の判断基準が無い / 却下 C (プロトタイプ UI に合わせて増やす): D-6 の再発行対象・3 者一致検査・A-6 の越境検証点が増える |
| **CV-D6** | SSE イベント型 | **CV-Q6=A** — PoC の 9 種 ([poc-conversation-flow.md](../../../docs/analysis/poc-conversation-flow.md) §1.2) を土台に **4 点を正す**: ①`artifact` を単一形 `{kind, payload}` に統一 ②進捗を **`progress` 1 種**に統合 (`{scope, step, total, label, detail?}`) ③`error` を **`CodedError` 形 `{code, message}`** にする ④**`turn_summary`** を追加 | 却下 B (PoC 踏襲): 3 つの不揃いが FE の分岐として残り、discriminated union 方針 (S-8) と最も相性が悪い / 却下 C (全面再設計): PoC の名前は素直で、改名は移植時の対応表コストだけを生む |
| **CV-D7** | 履歴の保存粒度 | **CV-Q7=A** — **ターン終了時に 1 メッセージ = 1 行**。ユーザー発話は受信時、assistant 発話はターン終了時。**中断時も「その時点までの本文」を `aborted` で保存**し、**保存はロールバックされない別トランザクション**で行う | 却下 B (デルタ追記): 1 ターンで数十〜数百回の UPDATE が走り、`conversation_messages` は最も行数が伸びるテーブル / 却下 C (完了ターンのみ保存): 打ち切られた本文がどこにも残らず O-4 とユーザー体験を損なう |
| **CV-D8** | テーマ確定の時期 | **CV-Q8=A** — **会話の作成にテーマを必須にする**。`conversation_sessions.theme_id` は **NOT NULL**。PoC の暗黙テーマ作成 (「対話生成: <本体>」) は**移植しない** | 却下 B (PoC 踏襲・暗黙作成): 紐づく前の `llm_call_records.theme_id` が NULL で残り O-3 のテーマ単位集計に穴が空く / 却下 C (B + 遡及更新): 明細の append-only ([data-model.md](../../../docs/design/data-model.md) §7.2 の検査 5) と矛盾する |
| **CV-D9** | 版の扱い | **CV-Q9=A** — 既存の版テーブル (`idea_versions` / `plan_tab_versions`) の操作として API 化する。「スナップショット」という別概念を作らない。**復元は新版を作る操作**であり版番号は増える。**削除操作は持たない** | 却下 B (会話アーティファクトのスナップショット新設): 「版」が 2 系統になり、`entry_id` による還流元の追跡 (§4.11.2) と二重管理になる / 却下 C (API を作らない): プロトタイプの UI が実装できない |
| **CV-D10** | 企画書タブの粒度 | **CV-Q10=A** — **タブ単位の REST** (`POST /plans/{plan_id}/tabs/{tab_id}/regenerate` は SSE で進捗、`GET /plans/{plan_id}` は 8 タブの最新版を同梱)。**会話ターン中の `generate_plan` と同じ UseCase を共有**し、入口だけ 2 つにする | 却下 B (会話ターン経由のみ): 1 タブの作り直しに会話 1 往復が要り LLM コストと待ち時間が増える / 却下 C (全体一括生成のみ): v2 が既にセクション単位の生成を持つため C-16 で粒度を落とせない |
| **CV-D11** | アイデアの更新経路 | **CV-Q11=A** — **`PUT /ideas/{idea_id}` (本文・タグ) / `DELETE /ideas/{idea_id}` / `POST /ideas` (マイアイデアの手動登録)**。**LLM 生成は会話ターン、人手の編集は REST** と役割を分ける。人手編集時は `idea_versions` に版を切る | 却下 B (タグ専用エンドポイント): 1 リソースの更新が 2 エンドポイントに割れ、部分更新の競合 (後勝ち規則) を別途決めることになる / 却下 C (会話ターン経由のみ・tool 追加): CV-D5 の判定基準に反する |
| **CV-D12** | 持ち込み PDF | **CV-Q12=A** — 既存②「**抽出用の未紐付けアップロード**」に寄せる。**会話専用のアップロードを作らない** ([API/assets.md](../../../docs/design/API/assets.md) §5 の AS-Q11 をクローズし D-AS-4 の「3 系統に留める」根拠を維持) | 却下 B (ナレッジファイルに寄せる): RAG のチャンク化・埋め込みコストが不要な文書にまで発生する / 却下 C (共通アップロード基盤の新設): 本増分の範囲が assets / knowledge の再設計にまで広がる |
| **CV-D13** | ツール引数の注入 | **CV-Q13=A** — **サーバ注入を廃す**。ツール引数は **schema に宣言したものだけ**とし、`asset_context` のような文脈は**ハンドラのクロージャが台帳から直接読む**。3 者一致検査 (`scripts/check-tool-contract.sh`) が常に成立する | 却下 B (PoC 踏襲 + schema 宣言 + サーバ値で上書き): Agent の値が黙って捨てられる = BE-8 の温床 / 却下 C (Agent に渡させる): 改ざんされた値がハンドラに入る余地を作る (A-6) |

### 3.2 既定採用 (質問にせず確定したもの)

[questions-conversation.md](questions-conversation.md) の「質問にしない既定採用」表の 6 件を**そのまま採用**する。
異論は設計レビューで受ける。

| ID | 項目 | 既定 |
|---|---|---|
| **CV-DF1** | **stage の値域と SSOT** | PoC の 5 値 (`asset` / `market` / `match` / `ideation` / `plan_draft`) を `entity/conversation` の純粋関数で台帳から導出する。テーマ・ボードが表示用に畳む場合の写像も本増分が定義する ([API/themes.md](../../../docs/design/API/themes.md) TH-Q3 / [API/idea-boards.md](../../../docs/design/API/idea-boards.md) IB-Q7 の委譲先) |
| **CV-DF2** | **D-6 とデプロイ順序** | ツールの追加は後方互換 (新ツールは新 Agent version だけが呼ぶ)、**削除は 2 段階** (先に Agent 定義から外し、次のリリースでハンドラを消す)。手順の SSOT は [operations.md](../../../docs/design/operations.md) §5.2 |
| **CV-DF3** | **O-2 の計測** | 会話経路の LLM 呼び出しはすべて `gateway/anthropic` を通し、ターン集計は `service/conversation.Runner` が持つ。**個別ツールに計測コードを書かない**。本増分は `feature` 値を列挙するだけ |
| **CV-DF4** | **O-4 の失敗表現** | `max_tokens` 切り詰め・JSON パース失敗・ツール引数の不整合は**構造化エラーとして Agent に返し、同時に warn + メトリクスに出す**。**PoC の `research_market` のような「パース失敗を成功として返すフォールバック」は作らない** |
| **CV-DF5** | **評価軸の統合** | v2 (V-2) と PoC (P-5) の評価軸を**調査してから**決める (LM-R6)。要件としては「両者を突き合わせ v3 の 1 本に統合すること」と「**どちらかを黙って落とさないこと**」を課す |
| **CV-DF6** | **V-4 / V-5 の扱い** | 本増分で `research_market` (P-8) に吸収できるかを判定する。吸収する場合は [llm-migration.md](../../../docs/design/llm-migration.md) §7.1 の M-7 が消滅するため是正要求を起票する (LM-R8。推測で先に畳まない) |

## 4. 受入基準 (AC-CV-1.1〜AC-CV-6.4)

> すべて **3 つの新設設計書の記述に対する受入基準**であり、実装コードに対するものではない。
> 「適切に」「必要に応じて」等の曖昧語を使わず、**記述の有無・一致・不在・件数**で判定できる形にしてある (DR-5)。
> 各 AC の検証方法は [plan.md](plan.md) の Task-3p 系のタスクが定める。

### 4.1 スコープと v2 の引き継ぎ (C-16)

- **AC-CV-1.1** `docs/design/API/plans.md` に **v2 企画書の v2 → v3 対応表**があり、
  **[v2-feature-inventory.md](../../../docs/analysis/v2-feature-inventory.md) §2.7 の表と同じ行数**で、
  **1 行も欠けていない**こと。各行に ①v2 のパスとメソッド ②v3 の受け先 (API のパス / 会話ツール名 /
  「REST に置き換え」等) ③第 1 リリースに入ること が書かれ、**「増分 2」「後ろ倒し」「対象外」と書かれた行が
  0 行**であること (CV-D1 / C-16)
- **AC-CV-1.2** `docs/design/API/ideas.md` に **v2 アイデア系の v2 → v3 対応表**があり、
  同 §2.5 の表と同じ行数で、**`POST /ideas/generate/my-idea` と `POST /ideas/generate/my-idea/draft` (V-3) の
  受け先**、および `POST /idea-hassans` 系 5 本 (発散セッション CRUD) の受け先が明示されていること (C-16)
- **AC-CV-1.3** [v2-feature-inventory.md](../../../docs/analysis/v2-feature-inventory.md) §5 の
  **#9 (企画書のお気に入り)** と **#10 (版履歴のプロンプト編集)** が**解消済みに更新**され、
  解消先 (本増分のどの設計書のどの節) が書かれていること。**「対象外」のまま残さない**
- **AC-CV-1.4** **F-CV1 の衝突に対する判断**が `docs/design/API/plans.md` に書かれていること —
  v2 は 1 アイデアに複数の企画書行を許すが v3 の `plans` は `UNIQUE (idea_id)` である。
  **①v3 も 1 アイデア 1 企画書に限定する (v2 の既存データに複数行がある場合の移行規則を書く)**
  **②制約を外す** のどちらかを採用案 + 却下案 + 理由の形で確定させること。
  **「移行時に確認する」という先送りは不可** (v2 の `POST /business-plans` を第 1 リリースで受ける以上、
  API の 409 / 200 の分岐がここで決まる)

### 4.2 会話ターン・SSE・履歴・テーマ

- **AC-CV-2.1** 会話ターンの入口が **`POST /conversations/{session_id}/messages` の同期 SSE** として定義され、
  次の 3 点が書かれていること (CV-D3): ①切断時の回復経路が **`GET /conversations/{session_id}` (台帳) +
  `GET /conversations/{session_id}/messages?after_seq=` (履歴)** の 2 本であること ②**同一セッションへの
  並行ターンは 409** (DM-13 の `SELECT ... FOR UPDATE NOWAIT` に対応) ③**J-6 の対象外であり J-7 を満たす**理由
  (SSE を返すリクエスト自身がターンを実行するため、ALB の振り分け問題が起こり得ない)
- **AC-CV-2.2** **SSE イベント型の一覧**が定義され、**OpenAPI の `components/schemas` に
  discriminated union として置く**ことが明記されていること (D-API-12 / [frontend.md](../../../docs/design/frontend.md) §6.2 の S-8)。
  次の 4 点が満たされること (CV-D6): ①`artifact` が **全 kind で `{kind, payload}` の単一形**であり、
  PoC の `asset` の payload ラッパ欠落と `research.pattern` の sibling が payload 内に入っていること
  ②進捗イベントが **`progress` 1 種**に統合され `{scope, step, total, label, detail?}` の形であること
  ③`error` が **`{code, message}`** であり「**プロバイダのエラー文言を素通ししない**」と明記されていること
  ④**未知イベントを捨てずに上位へ渡す** (S-6) が維持されていること
- **AC-CV-2.3** **`turn_summary` イベント**が定義され、①`outcome` の値域が
  **`completed` / `tool_limit` / `token_limit` / `timeout` / `failed` の 5 値**
  ②ツール呼び出し回数を含む ③**`done` の直前に 1 回だけ流す**
  ④**安全弁による打ち切りは `error` ではなく `turn_summary` の `outcome` で表す**
  (打ち切りは正常終了 — [observability.md](../../../docs/design/observability.md) §4.4) が書かれていること
- **AC-CV-2.4** **会話履歴の保存契約**が書かれていること (CV-D7): ①ユーザー発話は受信時、
  assistant 発話はターン終了時に **1 行**で保存 ②**中断時もその時点までの本文を `aborted` で保存**し、
  **ターンのトランザクション ([architecture.md](../../../docs/design/architecture.md) §3.10) とは
  別のロールバックされないトランザクション**で行うこと ③`conversation_messages.status` の値域が
  **`complete` / `aborted` / `failed`** で確定であること ([data-model.md](../../../docs/design/data-model.md) §8.4 の仮定 4 のクローズ)
  ④`GET /conversations/{session_id}/messages` のページング契約 (`after_seq` の意味と上限)
- **AC-CV-2.5** **会話の作成にテーマが必須**であることが書かれ、次の 3 点が満たされること (CV-D8):
  ①会話作成エンドポイントのパスと必須パラメータ (`theme_id`) が確定していること
  ②**PoC の暗黙テーマ作成 (`set_theme_name` / `generate_ideas` 実行時の `themes` 行の作成) を
  移植しない**ことが明記されていること ③テーマ名の変更が既存のテーマ更新 API で行われること
- **AC-CV-2.6** **毎ターンの状態注入**の仕様が確定していること (CV-D4): ①注入する台帳フィールドの一覧と形式
  ②**system prompt のテンプレート引数として渡すか、ユーザーメッセージの前置きとして渡すか**の決定と理由
  ③**プロンプト本文に「今どの段か」を書かない**こと (状態の SSOT は台帳。BE-1 の余地を減らす)
  ④**ツール集合は stage によらず常に全数**であり、前提不足はハンドラが `missing` 付き構造化エラーで拒否すること
- **AC-CV-2.7** **stage の値域 5 値とその導出**が `entity/conversation` の副作用のない関数として定義され、
  **テーマ・ボードが表示用に畳む場合の写像**も同じ節で定義されていること (CV-DF1)。
  [API/themes.md](../../../docs/design/API/themes.md) の **TH-Q3** と
  [API/idea-boards.md](../../../docs/design/API/idea-boards.md) の **IB-Q7** から参照できる形になっていること
- **AC-CV-2.8** 会話セッションの**ライフサイクル API** (作成・一覧・取得・削除) が定義され、
  v2 の `POST/GET/PUT/DELETE /idea-hassans` 系 5 本の受け先になっていること (AC-CV-1.2 と対応)

### 4.3 アイデア

- **AC-CV-3.1** **`PUT /ideas/{idea_id}` / `DELETE /ideas/{idea_id}` / `POST /ideas`** が定義され、
  **`tags` の書き込みが `PUT /ideas/{idea_id}` に含まれる**ことが明記されていること。
  [API/idea-boards.md](../../../docs/design/API/idea-boards.md) §8.1 の
  「**`tags` の書き込み側は会話型 API 設計が定義する**」が**クローズ**され、
  **読む側だけあって書く側が無い状態 (BE-10) が解消**していること (CV-D11)
- **AC-CV-3.2** **LLM が生成したアイデアを人手で編集したときに `idea_versions` に版を切る**ことが明記され、
  それが**企画書の stale 判定 (`plan_tab_versions.source_idea_version_id` / `source_hash`) を成立させるため**
  であることが理由として書かれていること (BE-4 / CV-D11)
- **AC-CV-3.3** [API/idea-boards.md](../../../docs/design/API/idea-boards.md) §7 の**参照系 3 本
  (`GET /ideas` / `GET /ideas/{idea_id}` / `PUT /ideas/{idea_id}/star`) が `ideas.md` へ移設**され、
  ①移設後の §7 が**空節ではなく「参照系は `ideas.md` へ移設済み」と書かれている**こと
  ②同節の制約 (「作成・本文更新・削除のエンドポイントを追加しない」) が**解除された旨が明記**されていること
  ③`ideas` テーブルの API SSOT が `ideas.md` の 1 箇所になっていること (CV-D2)
- **AC-CV-3.4** **v2 のアイデア評価 (V-2) と PoC の評価 (P-5) の評価軸・出力スキーマの突き合わせ結果**が
  表で示され、**v3 の 1 本に統合した後の軸の一覧**が書かれていること。
  **どちらか一方にしか無い軸について「採る / 採らない + 理由」が全件書かれている**こと
  (採らない軸を無言で落とさない — CV-DF5 / LM-R6)
- **AC-CV-3.5** **アイデア再評価の入口**が「LLM がターン中に評価を挟む必要があるか」で判定され、
  **tool か REST かの結論と理由**が書かれていること (CV-D5)

### 4.4 企画書

- **AC-CV-4.1** **タブ単位の再生成 `POST /plans/{plan_id}/tabs/{tab_id}/regenerate` (SSE) と
  `GET /plans/{plan_id}` (8 タブの最新版を同梱)** が定義され、
  **会話ターン中の `generate_plan` tool と同じ UseCase を共有する**ことと、
  **`feature` が `plan.generate` で共通**であるため**計測 (O-2) と安全弁の適用が入口によって変わらない**ことが
  書かれていること (CV-D10)
- **AC-CV-4.2** **再生成がどの版のアイデアを入力にしたかを `source_idea_version_id` に必ず記録する**ことと、
  **8 タブの ID 値域を `entity/plan` の `PlanTabID` の 1 箇所に持つ (DB の CHECK を付けない = G-9)** ことが
  書かれていること (BE-1 / CV-D10)
- **AC-CV-4.3** **版の API** (`GET /ideas/{idea_id}/versions` / `GET /plans/{plan_id}/tabs/{tab_id}/versions` +
  復元操作) が定義され、①**復元は「特定版を最新として複製する」= 新版を作る操作**であり版番号が増えること
  ②**版の削除操作を持たない**ことと、その理由 (版の削除は BE-4 の派生物の stale 判定を壊す) が
  書かれていること ③採番が 1 SQL に閉じること (BE-11) (CV-D9)
- **AC-CV-4.4** **企画書のお気に入り** (v2 の `POST/DELETE /business-plans/:id/favorite`) の
  API とデータモデルが定義され、**[data-model.md](../../../docs/design/data-model.md) へのテーブル追加要求**が
  §5 に起票されていること (F-CV2 / v2-feature-inventory §5 の #9)
- **AC-CV-4.5** **版履歴のプロンプト編集** (v2 の `PUT /business-plans/:id/histories/:history_id/prompt`) について、
  **`plan_tab_versions` に生成プロンプトを保持する列が必要かの判定結果**が理由付きで書かれ、
  必要なら §5 に是正要求が起票されていること (F-CV3 / 同 #10)
- **AC-CV-4.6** **v2 の詳細版セクション 7 種 (V-10) → v3 の 8 タブの写像表**があり、
  **7 セクションすべてに写像先 (どのタブか / 新タブか / タブ外の別リソースか) が書かれている**こと。
  併せて **v2 の簡易モード (V-6) の出力粒度が 8 タブに写像できるかの判定** (F-CV8 が本増分に委譲したもの) が
  書かれていること (F-CV6)
- **AC-CV-4.7** **企画書チャット (V-8)** の API と履歴の保存先が定義されていること。
  v2 の `GET /business-plans/:id/chat/history` / `POST /business-plans/:id/chat` の受け先が明示され、
  **会話セッション (`conversation_sessions`) に相乗りするか専用テーブルを持つか**が採用案 + 却下案で
  決まっていること (F-CV4)
- **AC-CV-4.8** **企画書サムネイル (V-9)** の生成 API と保存先の列が定義されていること (F-CV5)。
  [llm-migration.md](../../../docs/design/llm-migration.md) の LM-Q3 (サムネイル維持・Gemini が LM-D の例外) と
  矛盾しないこと
- **AC-CV-4.9** **企画書の一覧・取得・作成・更新・削除**が定義され、
  **会話セッションを経由せずに企画書を開ける経路**が存在すること (PoC は会話セッション経由でしか辿れない)

### 4.5 ツール契約と本番観点 (A-6 / O-2 / O-4 / D-6)

- **AC-CV-5.1** **custom tool の一覧**が確定し、次の 3 点が書かれていること (CV-D5):
  ①PoC の 9 本それぞれについて「残す / 廃止する / 引数で吸収する」の判定と理由
  ②**`set_theme_name` の廃止**と、その理由 (CV-D8 のテーマ必須化)
  ③**ユーザー操作で起動する操作 (タグ編集 / 版の復元 / PDF 添付 / タブ再生成) が REST であり
  tool にしない**ことの対応表。**「LLM が呼び出しを決める必要があるか」という判定基準が明記**されていること
- **AC-CV-5.2** **ツール引数は schema に宣言したものだけ**であり、**サーバによる引数注入を行わない**ことが
  明記され、`asset_context` のような文脈が**ハンドラのクロージャ内で構築される**ことが書かれていること。
  これにより **`scripts/check-tool-contract.sh` の 3 者一致 (schema ↔ handler ↔ prompt) が常に成立する**ことが
  書かれていること (CV-D13 / BE-8)
- **AC-CV-5.3** **A-6 への回答**が書かれていること: ①LLM が渡す ID (`asset_id` / `idea_num` 等) を
  **すべて「所有者条件付きクエリの入力」として扱う**こと ②**存在確認を所有権の検証に使わない** (A-4)
  ③**該当なしの応答を「見つからない」で統一**し、他人のリソースの存在を推測させないこと
  ④所有者不一致を **warn ログ + メトリクス**に出すこと ([architecture.md](../../../docs/design/architecture.md) §3.8.2)
- **AC-CV-5.4** **台帳のフィールドごとに書き手と読み手が対で示されている**こと。特に
  **`record_rejection` が書く内容の読み手 (再提案の抑制) が実装対象として明記**されていること
  ([data-model.md](../../../docs/design/data-model.md) §4.11.2。BE-10)
- **AC-CV-5.5** **持ち込み PDF が既存②「抽出用の未紐付けアップロード」経路を使う**ことが書かれ、
  ①**会話専用のアップロードエンドポイントを作らない**こと ②会話から参照する際の**所有者スコープ検証を
  ハンドラのクロージャで行う**こと ③**抽出ジョブの完了を会話がどう待つか** (ターン内で待つか、
  完了後の次ターンで参照するか) が明示されていること (CV-D12 / AS-Q11)
- **AC-CV-5.6** **O-4 の失敗表現**が書かれていること: `max_tokens` 切り詰め・JSON パース失敗・
  ツール引数の不整合を**構造化エラーとして Agent に返しつつ warn + メトリクスに出す**こと、
  および **PoC の `research_market` のような「パース失敗を成功として返すフォールバック」を作らない**ことが
  明記されていること (CV-DF4)
- **AC-CV-5.7** **O-2 の `feature` 値の一覧**が本増分の経路について列挙されていること
  (少なくとも会話ターン / アイデア生成 / アイデア評価 / 企画書生成)。
  **個別ツールに計測コードを書かない**ことが明記されていること (CV-DF3)
- **AC-CV-5.8** **D-6 への回答**が書かれていること: ツールの**追加は後方互換**、**削除は 2 段階**
  (先に Agent 定義から外し、次のリリースでハンドラを消す)。手順の SSOT が
  [operations.md](../../../docs/design/operations.md) §5.2 であることが参照されていること (CV-DF2)
- **AC-CV-5.9** **安全弁**の値 (ツール呼び出し 20 回 / ターン、実行時間 5 分) が
  [observability.md](../../../docs/design/observability.md) §4.4 を SSOT として参照され、
  **本書側に数値を再掲しない**こと (DR-9)。打ち切り時の SSE 表現が AC-CV-2.3 と一致していること

### 4.6 成果物・整合・是正要求

- **AC-CV-6.1** `docs/design/API/` に **`conversation.md` / `ideas.md` / `plans.md` の 3 ファイル**が作られ、
  [API/README.md](../../../docs/design/API/README.md) §0 の**「会話型アイデア創出は対象外」宣言が解除**され、
  対象表に 3 ファイルが載っていること (CV-D2)
- **AC-CV-6.2** [API/README.md](../../../docs/design/API/README.md) §3 の総覧が **6 ドメイン → 9 ドメイン**に
  更新され、①総覧表への 3 行の追加 ②小計・合計 ③「共通規約が対象にするのは N 本」の注記
  ④§3.x の明細節 3 つの追加 が**同じ差分で**行われていること。
  **`scripts/check-endpoint-mapping.sh` の検査④の対象集合が 3 ファイルを含むよう拡張**され、
  **`make check-endpoint-mapping` が通る**こと (F-CV11 / DR-9)
- **AC-CV-6.3** 3 ファイルが [API/README.md](../../../docs/design/API/README.md) §1・§2 の共通規約
  (認証・所有者スコープ・ステータスコード・エラー形式) に**載っている**こと、
  および**規約からの差分がある場合は §0 の auth-accounts.md と同じ形式で差分が列挙**されていること
- **AC-CV-6.4** **§5 の是正要求表のすべての行が「実施済み」または「対応不要 (理由付き)」**になっていること。
  **Design Freeze の条件**であり、「未対応」が 1 行でも残る状態で Freeze しない

## 5. 他文書への是正要求 (R-CV-1〜R-CV-14)

> **状態列を必ず更新する** (`06-delegation-prompts.md`「是正要求の表は状態列を持つ」)。
> 状態が無い表は、実施しても未対応に見えたまま残る。
> **起票先の文書が「受信欄」を持つ場合はそちらにも登録する** (DR-8 の受信側。実例: [auth.md](../../../docs/design/auth.md) §10.3)。

| ID | 起票先 | 内容 | 理由 (これをやらないと何が壊れるか) | 状態 |
|---|---|---|---|---|
| **R-CV-1** | [llm-migration.md](../../../docs/design/llm-migration.md) §4.2 / §7.1 | **V-8 / V-9 / V-10 / V-11 の優先度を 2〜3 → 1 (第 1 リリース)** に引き上げ、**§7.1 の M-8 を RL-4 → RL-1 相当**へ移す。並列・直列の依存 (M-3 → M-7 → M-8) と「第 1 リリースに入る段は M-0〜M-4」の記述も同じ差分で見直す | CV-D1 (=CV-Q1=B) と正面から衝突する判定が残る。移行計画が「併用期間に送る」前提のままだと、実装リポが第 1 リリースから外す (F-CV7) | **一部実施済み** (2026-08-01。§4.2 の V-7〜V-11 の優先度を **1** へ改訂し理由を注記。**§7.1 の M-8 の段割りは変更していない** — 「優先度 = v3 に機能を作る段」と「M-x = v2 から移送する段」は別物で、両立可否が v2 の既存企画書データの扱いに依存するため。**未解決分は llm-migration.md §9.2 の LM-R10 として起票**し、判定主体を `plans.md` と operations.md に指定した) |
| **R-CV-2** | [API/README.md](../../../docs/design/API/README.md) §1.3 | 非同期ジョブ共通仕様に「**会話ターンは同期 SSE であり J-6 (実行 goroutine と SSE 接続の分離) の対象外。ただし J-7 (結果の取得口を SSE 以外にも持つ) は満たす**」を明記する | J-1〜J-7 は「非同期ジョブの規約」として書かれており、会話ターンをその適用外にすることが無言の逸脱になる (CV-D3) | **実施済み** (2026-08-01。README.md に **§1.3.1** を新設) |
| **R-CV-3** | [data-model.md](../../../docs/design/data-model.md) §4.5 / §8.4 | **`conversation_sessions.theme_id` を NOT NULL 化**する。連動して ①FK の `SET NULL` を見直す (親テーマ削除時の挙動を決め直す) ②部分インデックス `(theme_id) WHERE theme_id IS NOT NULL` の条件を外す ③**§8.4 の仮定 6 をクローズ**する | CV-D8 の帰結。NULL 可のままだと `llm_call_records.theme_id` に穴が空き O-3 のテーマ単位集計が成立しない (F-CV9) | **実施済み** (2026-08-01。data-model.md §4.5 で NOT NULL + FK CASCADE + 通常インデックスに変更、§8.4 の仮定 6 をクローズ) |
| **R-CV-4** | [data-model.md](../../../docs/design/data-model.md) §4.6 | **企画書お気に入りのテーブルを追加**する (v2 の `business_plan_favorites` 相当)。**DR-9 の連動あり** — [API/idea-boards.md](../../../docs/design/API/idea-boards.md) §8.2 の 15 箇所リストを手順として使い、**`make check-table-counts` の期待値まで同じ差分で更新**する | F-CV2 / v2-feature-inventory §5 の #9。テーブルが無いと AC-CV-4.4 が実装できない。件数の取り残しは「設計どおりに実装した検査が必ず落ちる」形で実装リポに出る | **実施済み** (2026-08-02。`plan_favorites` を data-model.md §4.1.1 / §4.6 / §3.4.2 分類① に追加。`make check-table-counts` の連動 13 箇所を全件更新し照合 37 件・エラー 0) |
| **R-CV-5** | [data-model.md](../../../docs/design/data-model.md) §4.6 | **`plan_tab_versions` に生成プロンプトを保持する列が必要かを判定**し、必要なら追加する (v2 の `business_plan_histories.prompt` 相当) | F-CV3 / #10。列が無いと「版履歴のプロンプト編集」を第 1 リリースで受けられない | **実施済み** (2026-08-02。**必要と判定** — `plan_tab_versions.instruction text NOT NULL DEFAULT ''` を追加。v2 は書き手 2 本・読み手 1 本が対で存在する ([API/plans.md](../../../docs/design/API/plans.md) §5.1)) |
| **R-CV-6** | [data-model.md](../../../docs/design/data-model.md) §4.6 | **企画書チャット (V-8) の履歴の保存先**と、**サムネイル URL の保存先**をデータモデルに反映する (AC-CV-4.7 / AC-CV-4.8 の結論に従う)。テーブルを増やす場合は R-CV-4 と同じ DR-9 の連動手順を踏む | F-CV4 / F-CV5。CV-D1 で第 1 リリースに入った 2 機能に受け皿が無い | **実施済み** (2026-08-02。企画書チャットは `plan_chat_messages` の 1 テーブル新設 (v2 の 2 テーブルは Dify の対応表のため畳む)、サムネイルは `plans.thumbnail_object_key` + `thumbnail_generated_at` の列追加) |
| **R-CV-7** | [data-model.md](../../../docs/design/data-model.md) §4.6 / §8.4 | **`plans` の `UNIQUE (idea_id)` を維持するか外すか**を AC-CV-1.4 の結論に合わせる。**§8.4 の仮定 4 (`conversation_messages.status` の値域) を「変更なしで確定」としてクローズ**する | F-CV1 / CV-D7。UNIQUE の可否は v2 の `POST /business-plans` の受け方 (409 か 200 か) を決める | **実施済み** (2026-08-02。`UNIQUE (idea_id)` は**維持**で確定 (AC-CV-1.4 = D-PL-1)。§6.4 の新規一意制約の表に移行規則を記載。§8.4 の仮定 4 は 2026-08-01 にクローズ済み) |
| **R-CV-8** | [API/idea-boards.md](../../../docs/design/API/idea-boards.md) §7 / §8.1 | **参照系 3 本を `ideas.md` へ移設**し、§7 を「移設済み」の記述に書き換える (空節を残さない)。**§7 の制約 (作成・本文更新・削除を追加しない) を解除**し、**§8.1 の「更新経路」行を `ideas.md` への参照に差し替える** (BE-10 のクローズ) | CV-D2 / CV-D11。移設しないと `ideas` テーブルの API SSOT が 2 ファイルに割れたまま残る (F-CV10) | **実施済み** (2026-08-02。参照系 4 本 (CSV を含む) を `ideas.md` へ移設し、idea-boards.md §7 を「移設済み」に書き換え・制約を解除・§8.1 の BE-10 をクローズ) |
| **R-CV-9** | [API/README.md](../../../docs/design/API/README.md) §0 / §3 + `scripts/check-endpoint-mapping.sh` | **§0 の「対象外」宣言の解除**、**§3 総覧の 6 → 9 ドメイン化** (総覧表・小計・合計・「共通規約が対象にするのは N 本」の注記・§3.x 明細の追加)、**検査④の対象集合の拡張** | AC-CV-6.2。機構 (スクリプト) を直さずに文書だけ増やすと検査が新ファイルを見ないまま「通った」ことになる (F-CV11) | **実施済み** (2026-08-02。§0 の対象外解除 / §3 を 9 ドメイン 112 本 + 37 = 149 に更新 / §3.7〜§3.9 を新設 / `check-endpoint-mapping.sh` を `DOMAINS` 配列方式で 9 ドメイン化 (照合 29 件・故障注入 3 種で確認)) |
| **R-CV-10** | [v2-feature-inventory.md](../../../docs/analysis/v2-feature-inventory.md) §5 | **#9 (企画書のお気に入り) / #10 (版履歴のプロンプト編集) を「解消済み」に更新**し、解消先を書く。§2.5 / §2.7 の「v3 の対応」列を新設 3 ファイルへのリンクに更新する | C-16 の完了条件は「§5 の『対象外 (要確認)』が空になること」。更新しないと C-16 が未達のまま残る | **一部実施済み** (2026-08-02。**§5 の #9 / #10 は「解消済み」に更新**し、§2.5 / §2.7 の見出しと対応列を新 3 ファイルへのリンクに変更。**残る「対象外 (要確認)」は #1〜#5 (社内管理者機能) と #6 (会社情報の LLM 生成) の 6 件**で、いずれも本増分の範囲外) |
| **R-CV-11** | [frontend.md](../../../docs/design/frontend.md) §16.1 / §6.2 / §6.3.1 / §11.1 | **FE-Q1 をクローズ**する。連動: ①§6.3.1 の中継 Route Handler 表の「**会話ターン (パス未定)**」行をメソッドとパスで確定 ②§6.2 の **S-9 (`unknown` 固定) の解除条件が満たされた**ことを記載 ③§11.1 の `/themes/[themeId]/conversations/[conversationId]` の **`[未確定]`** を `[API]` へ | CV-D6。FE は「イベント型が確定するまで実装に着手しない」と決めており、クローズしないと会話画面が着手できない | **実施済み** (2026-08-01。FE-Q1 をクローズ / 中継表に 2 行を確定 / S-8・S-9 を更新 / §11.1 を `[API]` へ) |
| **R-CV-12** | [API/assets.md](../../../docs/design/API/assets.md) §5 | **AS-Q11 をクローズ**し、「4 系統目を作らず既存②に寄せた」ことと **D-AS-4 の却下根拠 (3 系統に留める) が維持されている**ことを記載する | CV-D12。クローズしないと「4 系統目が増えたかもしれない」状態が残り、D-AS-4 の根拠が宙に浮く | **実施済み** (2026-08-01。assets.md §5 の AS-Q11 をクローズ) |
| **R-CV-13** | [API/themes.md](../../../docs/design/API/themes.md) / [API/idea-boards.md](../../../docs/design/API/idea-boards.md) | **TH-Q3 / D-TH-4 と IB-Q7 (ステージ定義の SSOT) をクローズ**し、参照先を `conversation.md` の stage 節にする | CV-DF1。両 Q は本増分を委譲先に指定している。放置すると 2 文書が独自にステージを定義する余地が残る | **実施済み** (2026-08-01。themes.md TH-Q3 / idea-boards.md IB-Q7 をクローズ) |
| **R-CV-14** | [llm-migration.md](../../../docs/design/llm-migration.md) §9.2 | **LM-R6 (評価軸の統合) の調査結果**と、**LM-R8 (V-4 / V-5 を `research_market` に吸収するか) の判定**を反映する。吸収する場合は §7.1 の **M-7 が消滅する**ため同節も更新する | CV-DF5 / CV-DF6。両者とも「調査の実施主体は本増分」と名指しされている | **後半のみ実施済み** (2026-08-01。**LM-R8 = 吸収しない**で確定し llm-migration.md §9.2 と §4.2 直前の注を更新、M-7 は消滅しない。**LM-R6 (評価軸の統合) は `ideas.md` の担当**で未反映) |

## 6. 設計起草の分割と並列可否

**3 ファイルを別セッションで並列起草できる**。ただし**共有する前提を先に固定してからでないと割れる**。

### 6.1 先に固定する共有前提 (直列必須)

| # | 共有前提 | 固定される場所 |
|---|---|---|
| 1 | **SSE イベント型の一覧と形** (AC-CV-2.2 / AC-CV-2.3) | `conversation.md` — `plans.md` のタブ再生成 (SSE) が同じ `progress` / `error` / `turn_summary` を使う |
| 2 | **custom tool の一覧と契約** (AC-CV-5.1 / AC-CV-5.2) | `conversation.md` — `generate_ideas` / `generate_plan` が `ideas.md` / `plans.md` の生成経路そのもの |
| 3 | **stage の値域と導出** (AC-CV-2.7) | `conversation.md` — `ideas.md` の `Idea.stage` と `plans.md` の前提チェックが参照する |
| 4 | **版と復元の共通規則** (AC-CV-4.3) | `conversation.md` に置かず**共通規則として先に決める** — `idea_versions` と `plan_tab_versions` の両方に同じ形で適用する |
| 5 | **所有者スコープの強制点** (AC-CV-5.3) | [requirements-layering.md](requirements-layering.md) の AC-6.8 が既に確定済み。3 ファイルはこれを参照するだけ |

### 6.2 並列起草の単位

| 起草単位 | 対象 | 依存 |
|---|---|---|
| **CV-A** | `docs/design/API/conversation.md` (会話セッション・ターン・SSE・tool・台帳・stage) | §6.1 の 1〜4 を**この単位が確定させる** — 最初に着手する |
| **CV-B** | `docs/design/API/ideas.md` (アイデアの生成・更新・参照・版・評価・v2 対応表) | CV-A の 1〜4 の確定後。**idea-boards.md §7 の移設を同じ差分で行う** |
| **CV-C** | `docs/design/API/plans.md` (企画書 8 タブ・再生成・版・お気に入り・チャット・詳細版・サムネイル・v2 18 本の対応表) | CV-A の 1〜4 の確定後。**最も大きい** (CV-D1 により v2 の 18 本すべてを受ける) |
| **CV-D** | §5 の是正要求 R-CV-1〜R-CV-14 の消化 + `check-endpoint-mapping.sh` の拡張 | CV-A / CV-B / CV-C の結論が出た後。**複数文書に同時に触るため 1 セッションに集約する** (並列にすると DR-8 の波及漏れが起きる) |

- **CV-B と CV-C は並列可能** (異なるファイル・異なるドメイン)
- **CV-D は直列必須**。是正要求は `data-model.md` に 4 件集中しており (R-CV-3 / 4 / 5 / 6 / 7)、
  **件数の連動 (DR-9) が中間状態でずれるため 1 差分にまとめる**
- レビューは**集約する** — 3 ファイル + 是正要求の反映を 1 セッションの `design-reviewer` で見る

## 7. 未確定として残るもの (本書では閉じない)

**いずれも「調査してから決める」ものであり、推測で埋めない**。設計起草時に調査を実施し、
結論を設計書に書く。**仮定を添えて先に進めてよいものは仮定を明記した**。

| # | 未確定 | 本増分での扱い | 仮定 (違えば指摘を要する) |
|---|---|---|---|
| 1 | **評価軸の統合** (LM-R6) — v2 (V-2) と PoC (P-5) の評価軸・出力スキーマの差分が未調査 | **CV-B が調査して決める**。AC-CV-3.4 が「どちらかを黙って落とさない」ことを条件にしている | 「軸の和集合を採り、重複は統合する」を出発点にする。片方を全面採用するなら理由が要る |
| 2 | **V-4 / V-5 の吸収可否** (LM-R8) — `research_market` (P-8) に吸収できるか | **CV-A が判定する**。吸収する場合は R-CV-14 で §7.1 の M-7 を消す | 吸収しない (独立移送のまま) を既定とし、吸収する場合のみ是正要求を出す |
| 3 | **v2 の企画書に複数行が実在するか** (F-CV1) | **AC-CV-1.4 が「どちらを採るか」を先に決める**。既存データの実測は移行計画 (Task-2f 系) の範囲 | v3 は `UNIQUE (idea_id)` 維持を出発点にする (data-model の既存判断)。外す場合は却下案の記録が要る |
| 4 | **簡易モード (V-6) の 8 タブへの写像可否** (F-CV8) | **CV-C が判定する** (AC-CV-4.6) | 8 タブの部分集合に写像できると仮定する。写像できない出力がある場合はタブの追加ではなく**プロンプト側で吸収**することを出発点にする |
| 5 | **抽出ジョブの完了を会話がどう待つか** (AC-CV-5.5 の③) | **CV-A が決める** | 「ターン内で待たない (完了後の次ターンで参照する)」を出発点にする — ターンの安全弁 5 分を抽出の待ちに使わない |
| 6 | **A/B 評価体制** (LM-Q5) | **本増分の対象外**。[llm-migration.md](../../../docs/design/llm-migration.md) §8.2 の統合による品質劣化の A/B は同書の未回答のまま | — |

## 8. 本番観点 (08-production-gates) との対応

| ID | 本増分での回答 | 対応する AC |
|---|---|---|
| **A-6** (LLM のテナント越境) | ツール引数のサーバ注入を廃し、台帳の読みをクロージャ内に閉じる。LLM が渡す ID は所有者条件付きクエリの入力としてのみ扱い、存在確認を所有権の検証にしない。該当なしは「見つからない」で統一 | AC-CV-5.2 / AC-CV-5.3 |
| **A-4** (絞り込みの層) | 上記に同じ。強制点は [requirements-layering.md](requirements-layering.md) の AC-6.8 (クロージャ束縛) が SSOT | AC-CV-5.3 |
| **A-1 / A-2 / A-3 / A-5 / A-7** | **本増分で新規の判断はしない** — [auth.md](../../../docs/design/auth.md) と [API/README.md](../../../docs/design/API/README.md) §2 が SSOT。新設 3 ファイルが**同じ規約に載っていること**のみ要求する | AC-CV-6.3 |
| **O-2** (全 LLM 呼び出しの計測) | `gateway/anthropic` 1 箇所を通し、ターン集計は Runner。本増分は `feature` 値を列挙する | AC-CV-5.7 |
| **O-3** (コスト集計と上限) | **テーマ必須化により `llm_call_records.theme_id` が最初から埋まり、テーマ単位集計に穴が空かない**。上限による拒否は設けない (C-12) | AC-CV-2.5 / R-CV-3 |
| **O-4** (失敗の可観測性) | パース失敗・切り詰め・引数不整合を構造化エラー + warn + メトリクスにする。**成功を装うフォールバックを作らない** | AC-CV-5.6 |
| **O-5** (SSE / 長時間処理) | 切断時の回復経路 2 本を定義し、打ち切りを `turn_summary` の `outcome` で表す (エラーと区別できる) | AC-CV-2.1 / AC-CV-2.3 |
| **O-6** (監査ログ) | **本増分で新規の判断はしない** — [observability.md](../../../docs/design/observability.md) §4.5 と AC-6.13 が SSOT。生成・削除操作 (アイデア削除・企画書削除) が同方針の対象になることのみ確認する | AC-CV-3.1 / AC-CV-4.9 |
| **O-1 / O-7** | **本増分の対象外** ([observability.md](../../../docs/design/observability.md) が SSOT)。会話経路に固有のアラートが必要になった場合は同書へ是正要求を出す | — |
| **D-6** (Agent ライフサイクル) | ツール追加は後方互換、削除は 2 段階。手順の SSOT は [operations.md](../../../docs/design/operations.md) §5.2。**3 者一致検査が常に成立する形にする** (CV-D13) | AC-CV-5.2 / AC-CV-5.8 |
| **D-7** (段階リリース) | **CV-D1 により v2 企画書 18 本が第 1 リリースに入る** — [operations.md](../../../docs/design/operations.md) §6 の切替段階 (RL-3 で v2 の企画書画面を止められるか) と [llm-migration.md](../../../docs/design/llm-migration.md) §7.1 の M-8 の位置づけが変わる | R-CV-1 |
| **D-1 / D-2 / D-3 / D-4 / D-5 / D-8** | **本増分の対象外** (層構成・インフラと独立)。SSOT は [operations.md](../../../docs/design/operations.md) / [infrastructure.md](../../../docs/design/infrastructure.md) | — |

## 9. 既存 AC との関係

| 既存 AC | 本増分での扱い |
|---|---|
| **AC-1.1** (全エンドポイントが認証を通る) | **維持**。新設 3 ファイルのエンドポイントも公開ホワイトリストに入れない → AC-CV-6.3 |
| **AC-1.2** (新規機能テーブルの所有者列) | **維持**。§5 で追加要求するテーブル (お気に入り / チャット履歴等) も所有者列を持つ → R-CV-4 / R-CV-6 |
| **AC-1.3** (custom tool の所有者スコープ) | **維持し、本増分で具体化する**。強制点は AC-6.8 のまま、**ツール引数の形 (サーバ注入の廃止) が加わる** → AC-CV-5.2 / AC-CV-5.3 |
| **AC-1.4** (401/403/404/429 の使い分け) | **維持**。新設 3 ファイルが [API/README.md](../../../docs/design/API/README.md) §2.5 の一覧に載る。**会話ターンの 409 (並行ターン) が新しい分岐として加わる** → AC-CV-2.1 / AC-CV-6.3 |
| **AC-2.1** (全 LLM 経路の計測) | **維持**。会話経路の `feature` 値が本増分で列挙される → AC-CV-5.7 |
| **AC-2.3** (LLM 起因の失敗が握り潰されない) | **維持し、会話経路で具体化する** → AC-CV-5.6 |
| **AC-3.3** (Agent 発行がデプロイ手順に組み込まれている) | **維持**。ツールの追加・削除の順序規則が本増分で確定する → AC-CV-5.8 |
| **AC-3.8** (Dify 廃止の移行手順) | **維持。ただし優先度の判定を書き換える** — CV-D1 により V-8〜V-11 が第 1 リリースへ移る → R-CV-1 |
| **AC-5.1** (層の責務境界) / **AC-6.7 / AC-6.8 / AC-6.16** (層構成・ツール注入・計測点) | **維持。本増分では変更しない**。3 ファイルはこの構造の上に載る |

## 10. 参照した一次ソース

| 文書 | 使った箇所 |
|---|---|
| [questions-conversation.md](questions-conversation.md) | CV-Q1〜CV-Q13 の回答と各回答の「設計で書くこと」「同じ差分で起票する是正要求」 / 既定採用 6 件 |
| `hassan-v2-backend/db/schema.sql` | F-CV1〜F-CV6 (企画書系 6 テーブルの実測) |
| [v2-feature-inventory.md](../../../docs/analysis/v2-feature-inventory.md) | §2.5 (アイデア 13 本) / §2.7 (企画書 18 本) / §5 の #9 / #10 |
| [llm-migration.md](../../../docs/design/llm-migration.md) | §4.2 (V-1〜V-17 の優先度) / §6.2 の 5 / §7.1 (M-0〜M-9) / §9.2 (LM-R6 / LM-R8) |
| [data-model.md](../../../docs/design/data-model.md) | §4.5 (会話 4 テーブル) / §4.6 (アイデア・企画書 7 テーブル) / §4.11 (台帳の契約) / §8.4 の仮定 4・6 |
| [API/README.md](../../../docs/design/API/README.md) | §0 (対象外宣言) / §1.3 (J-1〜J-7) / §3 (総覧) |
| [API/idea-boards.md](../../../docs/design/API/idea-boards.md) | §7 (参照系の配置理由と制約) / §8.1 (`tags` の書き込み側) / §8.2 (DR-9 の連動手順) |
| [frontend.md](../../../docs/design/frontend.md) | §6.2 (S-6 / S-8 / S-9) / §6.3.1 (中継の許可リスト) / §11.1 / §16.1 (FE-Q1) |
| [requirements-layering.md](requirements-layering.md) | AC-6.7 / AC-6.8 / AC-6.16 (層構成・ツール注入・計測点の SSOT) |
| `scripts/check-endpoint-mapping.sh` | 検査④の対象集合 (F-CV11) |
