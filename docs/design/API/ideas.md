# API: アイデア (参照・人手編集・版・タグ・評価)

> 共通規約 (認証・レスポンス形・エラー・ページネーション・ステータスコード) の SSOT: [README.md](README.md)
> 本ファイルが回答する本番観点: **A-1, A-2, A-3 (参照), A-4, A-5, A-6, A-7, O-2, O-3, O-4, O-5, O-6, D-6 (対象外の理由)**
> 対応する受入基準: **AC-CV-1.2 / AC-CV-3.1〜3.5 / AC-CV-6.1・6.3** (+ AC-1.1 / AC-1.2 / AC-1.4 / AC-2.1 / AC-2.3 の維持)
> 要件の SSOT: [requirements-conversation.md](../../../aidlc-docs/inception/productionization/requirements-conversation.md)
> 必須観点 ID 一覧: [../../../.claude/rules/08-production-gates.md](../../../.claude/rules/08-production-gates.md)

## 0. 本書の範囲

### 0.1 範囲内 / 範囲外

| 区分 | 内容 | 所在 |
|---|---|---|
| **範囲内** | `ideas` テーブルを主対象とする **REST API の全部** — 一覧・取得・CSV・手動登録・本文更新・削除・スター・タグ・版 (`idea_versions`) の参照と復元・評価 (`idea_evaluations`) の生成と参照 / v2 アイデア系 13 本の受け先 / v2 (V-2) と PoC (P-5) の評価軸の統合 (LM-R6) | 本書 |
| **範囲内 (移設を受ける)** | [idea-boards.md](idea-boards.md) §7 の参照系 3 本 (`GET /ideas` / `GET /ideas/{idea_id}` / `PUT /ideas/{idea_id}/star`) **と §2.4 の `GET /ideas/csv`** | 本書 §1.1 / §2 (移設の起票は §8 の R-IDA-1) |
| **範囲外** | アイデアの**生成** (LLM 発散) — 会話ターンの `generate_ideas` tool | [conversation.md](conversation.md) §4.1 |
| **範囲外** | 会話セッション・SSE イベント型・台帳・`stage` の**定義** | [conversation.md](conversation.md) §1〜§5 |
| **範囲外** | 企画書 (8 タブ・再生成・版・お気に入り・チャット・サムネイル・詳細版) と v2 企画書 18 本の対応表 | **[plans.md](plans.md)** (2026-08-02 起草済み) |
| **範囲外** | ボード上でのアイデアの扱い (`BoardItem` / フェーズ / メモ / コメント) | [idea-boards.md](idea-boards.md) |
| **範囲外** | テーブル定義そのもの (列・FK・インデックス) | [../data-model.md](../data-model.md) §4.6 / §4.11 |
| **範囲外** | 安全弁の**数値**・失敗分類・監査ログの項目・`feature` の const 群 | [../observability.md](../observability.md) §4.2 / §4.3 / §4.4 / §4.5 |

> **`plans.md` にリンクを張っていない理由**: 本書と同じ増分で並列起草中であり、本書の確定時点で
> **ファイルが存在しない**。存在しないパスへの相対リンクは `make doc-lint` がリンク切れとして落とすため、
> 起草時は本文で `[未作成]` と明示していた。**2026-08-02 に `plans.md` が揃ったためリンク化済み**。
> [conversation.md](conversation.md) が同じ理由で同じ書き方をしている (同書 §0.1)。

### 0.2 本書が回答する本番観点 ID

| ID | 回答節 |
|---|---|
| A-1 認証方式 | §1.1 (全エンドポイントが認証必須。方式の SSOT は [../auth.md](../auth.md) §6.1) |
| A-2 ロール | §1.3 (認証ロールは `AuthRoleUser` のみ。その上で**アイデアの所有者かどうか**が書き込み権限を決める = [README.md](README.md) §2.2 の R-2) |
| A-3 テナント境界 | **参照** — [../data-model.md](../data-model.md) §4.6 の `ideas` / `idea_tags` / `idea_versions` / `idea_evaluations` はすべて所有者列を持つ。本書は**新規テーブルを定義しない** (§8 の是正要求はすべて**列の追加**) |
| A-4 絞り込みの層 | §1.4 (UseCase が確定し Repository のクエリ条件で強制。可視性の 3 条件も同節) |
| A-5 ステータスコード | §1.1 / §1.3 (**403 が発生する** — 「ボード経由で見えるが所有者ではない」状態が本書で初めて書き込み対象になるため) |
| A-6 LLM への越境 | §6.5 (評価 REST が LLM に渡す入力のスコープ。**LLM に ID を解決させない**) |
| A-7 共有・公開 | §1.4 (可視性の 3 条件 = 所有 / ボードのメンバーシップ / `visibility=contract`)。**共有された相手に書き込みを許さない**ことが §1.3 |
| O-2 LLM 呼び出しの記録 | §6.6 (`feature=idea.evaluate` / `route_kind=direct_api`。[conversation.md](conversation.md) §3.3 の表と同じ値) |
| O-3 コスト集計と上限 | §6.4 (1 リクエストで作れる評価ジョブの件数上限を `config` に置く)。**上限超過による拒否は設けない** (C-12) |
| O-4 失敗の可観測性 | §6.7 (`max_tokens` 切り詰め = F-1 / JSON パース失敗 = F-2 を**成功に落とさない**) |
| O-5 SSE / 長時間処理 | §6.3 (評価は**非同期ジョブ**。SSE を持たない理由は §7 の D-IDA-9) |
| O-6 監査ログ | §1.5 (記録対象の特定のみ。項目の SSOT は [../observability.md](../observability.md) §4.5) |
| O-1 / O-7 | **対象外** — [../observability.md](../observability.md) §4.1 / §4.6 が SSOT。アイデア経路に固有のアラートは本増分では追加しない (先送り先: 同書 §4.6) |
| D-6 Agent ライフサイクル | **対象外の理由つき** — 本書の LLM 経路 (P-5 評価) は **Managed Agent ではなく直接 API** ([conversation.md](conversation.md) §3.2) であり、Agent の再発行対象に含まれない。プロンプト (`prompts/idea/evaluate.md`) の変更はコードのデプロイと同じ経路に載る ([../operations.md](../operations.md) §5.2 の対象外) |
| D-4 DB マイグレーション | **参照** — 本書の是正要求はすべて**列の追加** (非破壊 DDL)。適用区分は [../operations.md](../operations.md) §7.4 に従う |
| D-7 段階リリース | **参照** — [../operations.md](../operations.md) §6 が SSOT。本書固有の移行は §3.3 (v2 の評価スコアの値域写像) |
| D-1 / D-2 / D-3 / D-5 / D-8 | **対象外** (インフラ・CI/CD は API 設計の範囲外。SSOT は [../operations.md](../operations.md) / [../infrastructure.md](../infrastructure.md)) |

---

## 1. エンドポイント一覧

**本節が回答する ID: A-1, A-2, A-4, A-5, A-7, O-6** / 対応 AC: **AC-CV-3.1, AC-CV-3.3, AC-CV-6.1, AC-CV-6.3**

### 1.1 一覧 (**本表がエンドポイント集合の定義元**)

すべて認証必須 (`X-Token`)・すべて増分 1。共通の 400 / 401 / 500 は [README.md](README.md) §2.5 に従い、
本表では**固有のコードのみ**挙げる。ID の型は [../data-model.md](../data-model.md) §3.2 の規約
(機能テーブルの PK は `bigint`) に従う。

> **本数を本文に書かない** (DR-9)。[README.md](README.md) §3 への転記と
> `scripts/check-endpoint-mapping.sh` の期待値は**本表の行数を実測して**入れる (§8 の R-IDA-6)。

| メソッド | パス | 概要 | スコープ | 主なリクエスト / レスポンス項目 | 固有ステータス | LLM |
|---|---|---|---|---|---|---|
| GET | `/ideas` | アイデア一覧 | 個人 / 契約 (`scope=contract`。**増分 1**) | Q: §2.2 の絞り込み — R: `{items:[Idea], total_count}` | 200 | — |
| GET | `/ideas/csv` | **CSV エクスポート** (v2 踏襲) | 個人 / 契約 (`scope=contract`。**増分 1**) | Q: `GET /ideas` と同一 (`limit` / `offset` は受け付けない) — R: `text/csv` (§2.6) | 200 / **400** (絞り込みが不正) | — |
| POST | `/ideas` | **アイデアの手動登録** (v2 のマイアイデア = V-3 の受け先) | 個人 | B: `theme_id` (**必須**) / `title` (**必須**) / `summary` / `target_market` / `customer` / `issue` / `solution` / `tags[]` / `conversation_session_id` (任意) — R: `Idea` | **201** / **400** (必須欠落・タグ規約違反) / **404** (テーマが他人 or 不存在) | — |
| GET | `/ideas/{idea_id}` | アイデア取得 | 個人 / 契約 (**増分 1**) / ボード経由 (§1.4) | R: `Idea` (+ `evaluation` / `stage`) | 200 / 404 | — |
| PUT | `/ideas/{idea_id}` | **本文・タグ・可視性の更新** (人手編集。**版を切る**) | 個人 (**所有者のみ**) | B: `title` / `summary` / `target_market` / `customer` / `issue` / `solution` / `tags[]` / **`visibility` (`private`\|`contract`)** / `version_label` (任意) — R: `Idea` | 200 / 404 / **403** (§1.3) / **400** | — |
| DELETE | `/ideas/{idea_id}` | 削除 (**論理削除** = `deleted_at`) | 個人 (**所有者のみ**) | — | **204** / 404 / **403** | — |
| PUT | `/ideas/{idea_id}/star` | スター評価更新 | 個人 (**所有者のみ**) | B: `{stars: 0..5}` — R: `Idea` | 200 / 404 / **403** / **400** (範囲外) | — |
| GET | `/ideas/{idea_id}/versions` | 版一覧 (**本文を含まない**) | 取得と同じ | Q: `limit` / `offset` — R: `{items:[IdeaVersionSummary], total_count}` (`ver_no` 降順) | 200 / 404 | — |
| GET | `/ideas/{idea_id}/versions/{version_id}` | 版 1 件の取得 (**本文を含む**) | 取得と同じ | R: `IdeaVersion` | 200 / 404 | — |
| POST | `/ideas/{idea_id}/versions/{version_id}/restore` | **復元** (対象版を新しい版として作り直す) | 個人 (**所有者のみ**) | B: `version_label` (任意) — R: `Idea` | **201** / 404 / **403** | — |
| GET | `/ideas/{idea_id}/evaluation` | **リッチ評価の取得** (stale 判定つき) | 取得と同じ | R: `{evaluation, stale, status, source_idea_version_id, evaluated_at, failure?}` (§2.5) | 200 / 404 | — |
| POST | `/idea-evaluations` | **リッチ評価の生成 (非同期ジョブ)** — v2 の `POST /ideas/evaluate` の受け先 | 個人 (**所有者のみ**) | B: `{idea_ids:[…]}` (**必須**・1 件以上) — R: `{items:[{idea_id, status}]}` | **202** / 404 / **403** / **400** (空配列・件数上限超過) | **✓** |
| GET | `/idea-evaluations` | 評価ジョブの状態一括取得 (J-7 の状態 GET) | 個人 | Q: `idea_ids` (カンマ区切り。**必須**) — R: `{items:[{idea_id, status, stale, evaluated_at, failure?}]}` | 200 / **400** (未指定) | — |

Q = クエリパラメータ / B = リクエストボディ / R = レスポンス。

- **SSE を返すエンドポイントは無い** (理由は §7 の D-IDA-9)
- ページングの既定・上限は [README.md](README.md) D-API-7 に従う (本書に値を再掲しない)
- `scope=contract` は**増分 1 から受け付ける** ([README.md](README.md) D-API-8'。2026-08-02 に「増分 2」から改訂 — C-16 により v2 の `POST /sharing-settings` でできていた共有の切り替えを落とせないため。SSOT は [../auth.md](../auth.md) §6.12 (c) / [../data-model.md](../data-model.md) DM-9)
- **`POST /ideas` は LLM を呼ばない**。v2 のマイアイデア補完 (LLM が空欄を埋める) の受け先は
  会話ターンであり、その理由と経路は §3.2

### 1.2 [idea-boards.md](idea-boards.md) からの移設 (AC-CV-3.3)

**移設対象は 4 本** — §7 が挙げる参照系 3 本 (`GET /ideas` / `GET /ideas/{idea_id}` /
`PUT /ideas/{idea_id}/star`) に加えて、**§2.4 の `GET /ideas/csv`** も移す。

| # | 決定 |
|---|---|
| 1 | **`GET /ideas/csv` も移す**。AC-CV-3.3 の本文が挙げるのは 3 本だが、**同 AC の③が「`ideas` テーブルの API SSOT が `ideas.md` の 1 箇所になっていること」を要求している**。CSV を残すと `/ideas` 配下の API が 2 ファイルに割れ、③を満たせない。`GET /ideas/csv` は AC の起草後 (2026-07-31) に C-16 で追加された 4 本目であり、3 本という数はその時点の実態を指している |
| 2 | **CSV の応答仕様 (Content-Type / BOM / 改行 / 列の写像) も本書 §2.6 へ移す**。[idea-boards.md](idea-boards.md) §2.4 は「移設済み」の 1 行に置き換える (§8 の R-IDA-1) |
| 3 | 移設後の [idea-boards.md](idea-boards.md) §7 は**空節にしない** — 「参照系は `ideas.md` へ移設済み」と書き換え、**同節の制約 (作成・本文更新・削除のエンドポイントを追加しない) が解除された旨**も書く (AC-CV-3.3 の①②)。編集はメインセッションが行う (§8 の R-IDA-1) |
| 4 | 移設は**パス・メソッド・ステータスコードを変えない**。変わるのは ①`Idea` オブジェクトの確定 (§2.1) ②書き込み系の 403 (§1.3) ③CSV の列ずれの修正 (§2.6) の 3 点で、いずれも本書で理由を書いた |

### 1.3 権限と 403 / 404 の使い分け (A-2 / A-5 / AC-1.4)

**判定境界は [README.md](README.md) §2.5 をそのまま適用する** — 「見えるリソースへの権限不足 = 403 /
見えないリソース = 404」。**本書で 403 が発生する**のは、[idea-boards.md](idea-boards.md) §2.2 が
**共有ボード経由で他人のアイデアが「見える」状態を作っている**ためである。

| 操作 | 所有者 | ボード経由で見えるだけの相手 | `visibility=contract` で見えるだけの相手 (**増分 1**) | 見えない相手 |
|---|---|---|---|---|
| 一覧・取得・版一覧・版取得・評価取得・CSV | ✓ | ✓ | ✓ | **404** |
| **本文・タグ更新** (`PUT /ideas/{idea_id}`) | ✓ | **403** | **403** | **404** |
| **削除** (`DELETE /ideas/{idea_id}`) | ✓ | **403** | **403** | **404** |
| **スター更新** (`PUT /ideas/{idea_id}/star`) | ✓ | **403** | **403** | **404** |
| **版の復元** (`POST …/versions/{version_id}/restore`) | ✓ | **403** | **403** | **404** |
| **評価の生成** (`POST /idea-evaluations`) | ✓ | **403** | **403** | **404** |
| 手動登録 (`POST /ideas`) | ✓ (テーマの所有者) | — (対象リソースが無い) | — | **404** (テーマが見えない) |

**`visibility` の書き込み経路 (A-7 / BE-10。2026-08-02 追加)**: **`PUT /ideas/{idea_id}` の body で更新する** (専用エンドポイントを作らない — [assets.md](assets.md) の `POST`/`PUT /assets` と同じ形。[themes.md](themes.md) だけは 既存の `PUT /themes/{theme_id}/visibility` を持つが、**そちらは既に定義済みのエンドポイント**であり増やさない)。**変更できるのは所有者のみ** (§1.3 の権限表と同じ — 共有された相手が共有範囲を広げられない)。
**この経路が無いと C-16 に違反する** — v2 の `POST /sharing-settings` は `idea` カテゴリの共有 ON/OFF を持っており ([../auth.md](../auth.md) §6.12)、読む側 (上の可視性 3 条件) だけを実装すると**利用者が共有を切り替えられなくなる** (BE-10 の設計版)。

- **403 の系統は [README.md](README.md) §2.2 の R-2 (リソース単位のロール / 投稿者)**。ボードのメンバーシップは
  リソース単位の関係であり、認証ロール (`AuthRoleUser`) では決まらない
- **却下 (a) 書き込みも 404 にする**: 直前の `GET /ideas/{idea_id}` で存在を知っている相手に 404 を返しても
  秘匿にならず、「取得できたものが更新では存在しない」というクライアント挙動を生む。
  [idea-boards.md](idea-boards.md) §3.1 が viewer の編集操作について**同じ理由で 403 を採っている**
- **却下 (b) ボードのメンバーに編集を許す**: v2 の `ideas` は `idea_hassans.account_id` に到達する個人データで、
  共有されているのは**ボードという閲覧・議論の面**である。編集を許すと、切替時に
  **v2 で他人が触れなかったアイデア本文が触れるようになる** = サイレントな権限昇格 (DR-3。
  [idea-boards.md](idea-boards.md) D-IB-8 が却下した平坦化と同型)
- **`POST /idea-evaluations` が 403 を返す理由**: 評価は `idea_evaluations` に **1 アイデア 1 行** で保存され
  ([../data-model.md](../data-model.md) §4.6 の `UNIQUE (idea_id)`)、他人が実行すると
  **所有者の評価が上書きされ、かつ所有者に無断で LLM コストが発生する**

**403 の本数は本表から数える** (DR-9)。[README.md](README.md) §2.5 / §3 は
「403 は R-1 / R-2 の 2 系統・合計 11 本」を**6 ドメインについての数**として書いているため、
**本書の追加分を同じ差分で反映する必要がある** (§8 の R-IDA-6)。

### 1.4 所有者スコープと可視性の強制点 (A-4 / A-7 / AC-1.2)

| # | 決定 |
|---|---|
| ① | **UseCase が所有者スコープ (`AccountID` / `ContractID`) を確定し、Repository のクエリ条件に必ず渡す** ([../auth.md](../auth.md) §6.4)。Controller はリクエストから所有者 ID を作らない ([README.md](README.md) §1.4 の「所有者 ID の生成経路」) |
| ② | **可視性の 3 条件は 1 本のクエリで評価する** — ①`ideas.account_id` = 認証ユーザー ②`idea_board_items` 経由で自分がメンバーのボードに載っている ③`ideas.contract_id` = 自契約 かつ `ideas.visibility = 'contract'` (**増分 1**)。**条件は [idea-boards.md](idea-boards.md) §2.2 と同一**であり、本書は書き込み権限 (§1.3) を追加しただけである |
| ③ | **存在確認を所有権の検証に使わない** (A-4)。「行が nil でない」で通すコードを書かない。403 と 404 の分岐は**「可視性クエリで 1 件」かつ「`account_id` が一致しない」**の 2 つの結果から決める (2 回のクエリではなく、可視性クエリが `is_owner` を返す形にする) |
| ④ | **`POST /ideas` の `theme_id` / `conversation_session_id` は所有者条件付きクエリで検証する**。テーマが見えなければ 404。会話セッションが見えなければ 404 (**存在確認だけで通さない**) |
| ⑤ | **`POST /idea-evaluations` の `idea_ids` は 1 件ずつ所有者条件で解決する**。1 件でも所有者でないものが含まれたら**ジョブを 1 つも作らずに** 403 / 404 を返す (部分成功にしない — どれが弾かれたかを応答で列挙すると他人のリソースの存在が漏れる) |

### 1.5 監査ログの対象 (O-6)

**記録項目の SSOT は [../observability.md](../observability.md) §4.5**。本書は**対象の特定**のみ行う。

| 操作 | 記録するか | 理由 |
|---|---|---|
| `POST /ideas` (手動登録) / `PUT /ideas/{idea_id}` / `DELETE /ideas/{idea_id}` | **する** | 同書の「生成」「削除」に該当 |
| `POST /ideas/{idea_id}/versions/{version_id}/restore` | **する** | 内容を過去版に戻す = 実質的な更新 |
| `POST /idea-evaluations` | **する** | 同書の「LLM を伴う操作の実行」に該当 |
| `PUT /ideas/{idea_id}/star` / 参照系 | **しない** | 内容を変えない主観評価・読み取り。記録すると量が多く、監査の信号対雑音比を下げる |

**新しい記録対象の種別は追加しない**。書き込み失敗時の扱い (別トランザクションの best-effort + warn) は
[../architecture.md](../architecture.md) §3.9③ が SSOT。

---

## 2. 各エンドポイントの入出力

**本節が回答する ID: A-5** / 対応 AC: **AC-CV-3.1, AC-CV-3.3, AC-CV-6.3**

### 2.1 `Idea` オブジェクト (**本書が SSOT**)

```json
{
  "id": 101,
  "num": 7,
  "theme": { "id": 12, "name": "超音波センシング 新規事業探索 v2" },
  "conversation_session_id": 41,
  "title": "半導体製造装置の配管詰まり 予兆検知IoT",
  "summary": "クランプオン超音波で配管内の付着・詰まりを非破壊で常時監視する",
  "target_market": "半導体前工程の装置メーカーおよびファブ",
  "customer": "装置保全部門",
  "issue": "詰まりの発見が定期点検頼りで、停止損失が大きい",
  "solution": "外付けセンサ + AI 推論で予兆を検知し保守通知を出す",
  "market_size": "12.4兆円",
  "cagr": "14.2%",
  "uniqueness": "既存は定期目視が主流で常時監視の商品化例が乏しい",
  "mission_alignment": "非破壊センシングによる安全性向上という方針に直結する",
  "tags": ["脱炭素", "予兆検知"],
  "stars": 4,
  "evaluation": {
    "grade": "B",
    "score": 6.4,
    "axis_scores": {
      "novelty": 7.0,
      "mission_fit": 6.0,
      "market_size": 8,
      "market_cagr": 5,
      "tech_feasibility": 6.5
    },
    "has_detail": true,
    "detail_stale": false
  },
  "stage": { "code": "plan", "label": "企画作成" },
  "has_knowledge": false,
  "visibility": "private",
  "latest_version": { "id": 55, "ver_no": 3 },
  "is_owner": true,
  "deleted": false,
  "created_at": "2026-07-16T00:22:00Z",
  "updated_at": "2026-08-01T09:12:00Z"
}
```

| フィールド | 決定と根拠 |
|---|---|
| `num` | `ideas.seq_no` (テーマ内の表示番号)。**採番は 1 SQL に閉じる** ([../data-model.md](../data-model.md) §4.11.1。BE-11) |
| `summary` | **v2 の `ideas.concept` に対応する** (`hassan-v2-backend/db/schema.sql:155`)。列名の写像が [../data-model.md](../data-model.md) に未記録なので §8 の R-IDA-4 で起票 (= [idea-boards.md](idea-boards.md) の **IB-Q14-4**) |
| `market_size` / `cagr` | **載せる** (= **IB-Q14-2 の回答**)。v2・v3 とも列があり (`hassan-v2-backend/db/schema.sql:160`〜`:161` / [../data-model.md](../data-model.md) §4.6)、プロトタイプのテーマ内アイデア一覧が列として表示している。**表示用の文字列をそのまま返し、数値に分解しない** — 数値は `evaluation.axis_scores.market_size` / `.market_cagr` としてサーバが計算済みの整数で返すため、**FE が文字列をパースする必要が無い** (FE-6 の「120-420億円 → -420億円」誤抽出の再発点を作らない) |
| `tags` | `string[]` (**空配列可・null を返さない**)。並び順は `idea_tags.sort_order` 昇順 ([idea-boards.md](idea-boards.md) §8.1)。**書き込みは §5** |
| `evaluation.grade` | **`rank` ではなく `grade`** に統一する。PoC の実装名が `grade` (`claude_managed_agents/cmd/devui/conversation_tools_generate.go:245`) で、[conversation.md](conversation.md) §5.2 の `artifact(ideas)` payload も `grade` を使う。[idea-boards.md](idea-boards.md) §2.1 の `evaluation.rank` は改名する (§8 の R-IDA-1) |
| `evaluation.score` | **0.0〜10.0 の小数 1 桁** (PoC の `composite` と同じ値域)。**v2 の 0〜40 の合計値ではない** — 写像は §3.3 |
| `evaluation.axis_scores` | composite に入る 5 軸のみ (§6.3 の主軸)。**補助軸と本文は `GET /ideas/{idea_id}/evaluation` が返す** — 一覧で数十 KiB の rationale を返さない |
| `evaluation.has_detail` / `detail_stale` | `idea_evaluations` に行があるか / その行が stale か ([../data-model.md](../data-model.md) §4.11.3)。**一覧で「再評価が必要」バッジを描くために必要**で、これが無いと FE が N 件分の評価 GET を撃つ |
| `stage` | `{code, label}`。値域は **`diverged` (発散) / `plan` (企画作成)** の 2 値で、**[conversation.md](conversation.md) §2.3.2 が SSOT** (`plans` 行が存在すれば `plan`)。会話セッションの `stage` (5 値) を配らない |
| `has_knowledge` | `knowledge_threads.idea_id` の存在。**`has_plan` は持たない** — `stage.code == "plan"` と同値になり、同じ事実を 2 つの名前で返すことになる (= **IB-Q14-3 の回答**)。**一覧では `EXISTS` の結合で導出し N+1 にしない** |
| `is_owner` | 認証ユーザーがアイデアの所有者か。**FE が編集 UI を出すかの判断に使う** — 無いと FE は「PUT を撃って 403 を見る」しか手段が無い (§1.3) |
| `deleted` | 論理削除済みのアイデアをボードが参照する場合に `true` ([idea-boards.md](idea-boards.md) D-IB-7)。**`GET /ideas` の一覧には出さない** |
| `latest_version` | 最新版の `id` / `ver_no`。**企画書の stale 判定 (`plan_tab_versions.source_idea_version_id`) と突き合わせる相手**であり、これが無いと FE が版一覧を撃たないと「企画書が古いか」を出せない |

**`IdeaSummary` は作らない** — 一覧と単体で同じ `Idea` を返す。本文フィールド (`summary` / `issue` /
`solution` 等) は [idea-boards.md](idea-boards.md) の IB-Q11=a が**ボード詳細で行内展開表示する**と決めており、
一覧から落とすと同じ画面で N 件の単体 GET が必要になる。

### 2.2 `GET /ideas` の絞り込み

| パラメータ | 値域 | 由来 |
|---|---|---|
| `scope` | `mine` (既定) / `contract` (**増分 1 から**) | [README.md](README.md) D-API-8 / D-API-8' |
| `theme_id` | 整数 | v2 の `theme_id` (`hassan-v2-backend/controller/idea.go:165`) |
| `conversation_session_id` | 整数 | **v2 の `idea_hassan_id`** (`同:163`) の受け先。v2 の発散セッション = v3 の会話セッション |
| `keyword` | 文字列。対象は **`title` / `summary` / `tags`** | [idea-boards.md](idea-boards.md) §8.1 が「`keyword` の対象にタグを含める」と確定済み |
| `min_stars` | 0〜5 | [idea-boards.md](idea-boards.md) §2 |
| **`stage`** | `diverged` / `plan` | **v2 の `is_only_business_plan_created`** (`hassan-v2-backend/controller/idea.go:141`) の受け先。`stage=plan` が「企画書が作られたものだけ」と同値 (§2.1 の `stage`) |
| **`plan_favorite`** | `true` / `false` | **v2 の `is_only_business_plan_favorite`** (`同:150`) の受け先。**判定元のテーブルは企画書ドメインが定義する** ([plans.md](plans.md) §9 の `plan_favorites` / F-CV2)。**本パラメータの実装は同テーブルの追加に依存する** (§8 の R-IDA-5) |
| `created_by` | 契約内メンバーの ID。**`scope=contract` のときのみ有効** | [README.md](README.md) D-API-8 (`account_id` パラメータは置かない) |
| `limit` / `offset` / `sort` | D-API-7 / D-API-9 | `sort` の許可値は `updated_at` / `created_at` / `stars` / `score` / `num` |

- **`account_id` パラメータを置かない** (D-API-8)。v2 は `c.Query("account_id")` を受けており
  (`hassan-v2-backend/controller/idea.go:164` の `RequestAccountID`)、テーマ側で契約一致検証が無い実装と
  同じ入力形になっている ([README.md](README.md) F-15)
- **`limit` 未指定 = 全件を継承しない** (v2 は `limit=0` で全件 — `hassan-v2-backend/controller/idea.go:121-122` のコメント)。
  既定と上限は D-API-7

### 2.3 `POST /ideas` / `PUT /ideas/{idea_id}` (人手の作成・編集)

| 項目 | 決定 |
|---|---|
| 更新の粒度 | **全置換ではなく、送られたフィールドのみ更新する** (部分更新)。`tags` は**送られた場合のみ全置換**する (§5) |
| 版 | **どちらも `idea_versions` に版を切る** (§4)。`version_label` を任意で受け、`idea_versions.label` に入れる |
| 空文字と未送信 | **区別する** — 未送信のキーは変更しない、空文字は「空にする」。`title` は空文字を許さない (400) |
| `conversation_session_id` | `POST` のみ受け付ける。**`PUT` では変更できない** (アイデアがどの会話から生まれたかは事実であり、後から書き換えると `GET /ideas?conversation_session_id=` の結果が変わる) |
| `seq_no` の採番 | `POST` 時に**テーマ単位で `COALESCE(MAX(seq_no),0)+1` を 1 SQL** で採る ([../data-model.md](../data-model.md) §4.11.1)。クライアントは指定できない |
| 評価の扱い | **本文を変えると `idea_evaluations` が stale になる** (§4.3)。**自動で再評価しない** (LLM コストが暗黙に発生する。同 §4.11.3 と同じ判断) |
| 削除 | `DELETE` は**論理削除** (`deleted_at`)。ボードアイテム・企画書・ナレッジスレッドは参照を保つ ([idea-boards.md](idea-boards.md) D-IB-7) |

### 2.4 `IdeaVersion` / `IdeaVersionSummary`

```json
{
  "id": 55,
  "ver_no": 3,
  "label": "顧客像を BtoB に寄せた",
  "created_by": { "account_id": "…", "name": "…" },
  "created_at": "2026-08-01T09:12:00Z",
  "is_latest": true,
  "snapshot": { "title": "…", "summary": "…", "target_market": "…", "customer": "…", "issue": "…", "solution": "…", "tags": ["…"] }
}
```

`IdeaVersionSummary` は上記から **`snapshot` を除いたもの** (一覧で全版の本文を返さない)。
`snapshot` の項目は **§4.2 の「版に入れるもの」と 1 対 1**で、本書の 2 箇所に別々の一覧を持たない。

### 2.5 `GET /ideas/{idea_id}/evaluation`

```json
{
  "status": "succeeded",
  "stale": false,
  "source_idea_version_id": 55,
  "evaluated_at": "2026-08-01T09:20:00Z",
  "evaluation": { "…": "§6.3 の統合スキーマ" },
  "failure": null
}
```

| 状態 | `status` | `stale` | `evaluation` | 由来 |
|---|---|---|---|---|
| 未評価 (行なし) | `none` | `false` | **`null`** | PoC の `decideEvaluationLookup` の「行なし」(`claude_managed_agents/cmd/devui/idea_evaluations.go:140`〜) |
| 実行中 | `queued` / `running` | 直前の値 | **直前の評価** (あれば) | [README.md](README.md) §1.3 の J-2。**実行中に前の結果を隠さない** |
| 完了・最新 | `succeeded` | `false` | 評価本体 | 同 |
| 完了・**古い** | `succeeded` | **`true`** | **`null`** | [../data-model.md](../data-model.md) §4.11.3 =「行を消さず `stale: true` を返し、評価本体は返さない」。PoC も同じ (`source_hash` 不一致で `eval=nil`) |
| 失敗 | `failed` | — | 直前の評価 (あれば) | `failure: {code, message}` ([README.md](README.md) §1.3 の J-2) |

**`stale=true` で本体を返さない理由**: 返すと FE が古い数値を表示し、ユーザーは「編集したのに評価が変わらない」
のか「評価が古い」のかを区別できない (BE-1 / BE-4)。

### 2.6 `GET /ideas/csv` の応答仕様 (**[idea-boards.md](idea-boards.md) §2.4 から移設**)

v2 の実装を実測して仕様化したもの (`hassan-v2-backend/usecase/idea/get_ideas_csv.go`)。

| 項目 | v3 の仕様 | v2 の実装 (出典) |
|---|---|---|
| Content-Type | `text/csv` | `hassan-v2-backend/controller/idea.go:481` |
| ファイル名 | `Content-Disposition: attachment; filename="ideaList.csv"` | `同:482` |
| 文字コード | **UTF-8 + BOM** (Excel で文字化けしないため。**踏襲する**) | `同:483` |
| 改行 | **CRLF** | `同:486` |
| 1 行目 | ヘッダ行 (日本語の列名) | `hassan-v2-backend/usecase/idea/get_ideas_csv.go:43`〜`:58` |
| テナント境界 | `contract_id` を `WHERE` に持つ (`List*` として実装する) | `同:35` |
| 絞り込み | `GET /ideas` と同一 (§2.2)。**`limit` / `offset` は受け付けず絞り込み結果の全件**を出す | v2 は `idea_hassan_id` 必須の 1 通りのみ (`hassan-v2-backend/controller/idea.go:450`〜`:453`) |

**列の写像 (本表の行数が列数の定義元)**:

| # | ヘッダ (v2 と同一) | v3 のフィールド |
|---|---|---|
| 1 | アイデアタイトル | `title` |
| 2 | コンセプト | `summary` |
| 3 | 顧客 | `customer` |
| 4 | 課題 | `issue` |
| 5 | 解決策 | `solution` |
| 6 | 価値提案 | `target_market` |
| 7 | 市場規模 | `market_size` |
| 8 | CAGR | `cagr` |
| 9 | 新規性 | `uniqueness` |
| 10 | ミッション整合性 | `mission_alignment` |
| 11 | 総合スコア | `evaluation.score` |
| 12 | 新規性スコア | `evaluation.axis_scores.novelty` |
| 13 | ミッション整合性スコア | `evaluation.axis_scores.mission_fit` |
| 14 | 市場規模スコア | `evaluation.axis_scores.market_size` |
| 15 | CAGRスコア | `evaluation.axis_scores.market_cagr` |
| 16 | 作成日 | `created_at` (`YYYY-MM-DD HH:MM:SS`) |

**v2 の実装には列ずれのバグがある (2026-08-01 に実測)**:
`hassan-v2-backend/usecase/idea/get_ideas_csv.go` の**ヘッダは 16 列** (`:43`〜`:58`) だが、
**データ行は 15 値しか書いていない** — `:68` (`idea.Solution`) の次が `:69` (`idea.MarketSize`) で、
**`idea.TargetMarket` (価値提案) が書かれていない**。結果として `価値提案` 列以降が 1 つずつ左にずれ、
**`作成日` 列は常に空**になる (`:78` の `CreatedAt` が `CAGRスコア` 列に入る)。
`encoding/csv` の `Writer` は列数の不一致を検査しないため**無言で出力される**。

| # | 決定 |
|---|---|
| 1 | **v3 は 16 列すべてに値を書く** (ヘッダどおり)。`価値提案` に `target_market` が入り、`作成日` が埋まる |
| 2 | **却下 (a) v2 のずれを再現する**: 「`価値提案` 列に市場規模が入る」状態を仕様として固定することになり、以後の実装者が「なぜずれているのか」を判断できない。バグの意図的な再現は [idea-boards.md](idea-boards.md) §2.4 が守ろうとした互換性 (下流の集計を壊さない) の目的にも合わない — **下流が読んでいるのは列名であり、列名と中身が食い違っている現状こそが壊れた状態**である |
| 3 | **却下 (b) 列を減らして 15 列にする**: `価値提案` と `作成日` のどちらかを落とすことになり、C-16 (v2 にある出力を落とさない) に反する |
| 4 | **リリースノートで告知する** — 切替でこの 2 列の中身が変わるのは**利用者から見える変更**である ([idea-boards.md](idea-boards.md) IB-Q10 と同じ扱い)。告知の要否は [../operations.md](../operations.md) の切替手順が受ける (§8 の R-IDA-7) |

**却下 (非同期ジョブ + ダウンロード URL にする)**: v2 は同期で返しており、件数も 1 発散分の規模である。
非同期化すると状態を持つ先が必要になり (BE-10)、v2 にできていた「押したら落ちてくる」操作が 2 段になる。
**件数が問題になった時点で再検討する** (契機: 1 契約のアイデアが数万件規模になったとき)。

---

## 3. v2 → v3 の対応表 (AC-CV-1.2 / C-16)

**本節が回答する ID: A-5, D-7** / 対応 AC: **AC-CV-1.2**

### 3.1 エンドポイント (v2 のアイデア系 13 本)

[../../analysis/v2-feature-inventory.md](../../analysis/v2-feature-inventory.md) §2.5 の表と**同じ行数・同じ順序**。
**「増分 2」「後ろ倒し」「対象外」と書かれた行は 0 行** (CV-D1 = CV-Q1=B)。

| # | v2 エンドポイント | 行 | v2 の機能 | v3 の受け先 | 第 1 リリース |
|---|---|---|---|---|---|
| 1 | `GET /ideas` | `hassan-v2-backend/router/router.go:122` | アイデア一覧 | **`GET /ideas`** (§1.1)。絞り込みの写像は §3.2 | ✓ |
| 2 | `GET /ideas/:id` | `同:121` | アイデア取得 | **`GET /ideas/{idea_id}`** | ✓ |
| 3 | `PUT /ideas/:id/star` | `同:128` | スター評価 | **`PUT /ideas/{idea_id}/star`** (**所有者のみ / 他人は 403** — §1.3) | ✓ |
| 4 | `GET /ideas/csv` | `同:127` | CSV エクスポート | **`GET /ideas/csv`** (§2.6。**列ずれを修正**) | ✓ |
| 5 | `POST /ideas/generate` (V-1) | `同:123` | アイデアの発散生成 | **会話ターンの `generate_ideas` tool** ([conversation.md](conversation.md) §4.1)。v2 の発散条件フォームは台帳の前提になる (同 §1.2) | ✓ |
| 6 | `POST /ideas/generate/my-idea` (V-3) | `同:124` | 自分のアイデアの登録 (LLM が空欄を補完してから保存) | **`POST /ideas`** (登録) + **会話ターン** (補完)。分割の理由は §3.2 | ✓ |
| 7 | `POST /ideas/generate/my-idea/draft` (V-3) | `同:125` | 自分のアイデアの下書き生成 (**保存しない**) | **会話ターン** (本文案を発話で返す)。`POST /ideas` でユーザーが確定する | ✓ |
| 8 | `POST /ideas/evaluate` (V-2) | `同:126` | アイデアの再評価 (**発散セッション単位で一括**) | **`POST /idea-evaluations`** (`idea_ids[]` に当該セッションの全件を渡す。§6.4) | ✓ |
| 9 | `POST /idea-hassans` | `同:144` | 発散セッションの作成 | **`POST /conversations`** ([conversation.md](conversation.md) §1.2) | ✓ |
| 10 | `GET /idea-hassans` | `同:146` | 発散セッション一覧 | **`GET /conversations`** (同) | ✓ |
| 11 | `GET /idea-hassans/:id` | `同:145` | 発散セッション取得 | **`GET /conversations/{session_id}`** (同) | ✓ |
| 12 | `PUT /idea-hassans/:hassan_id` | `同:147` | 発散セッションの更新 | **`PUT /conversations/{session_id}`** (タイトル) + **会話ターン** (発散条件)。同書 D-CV-4 | ✓ |
| 13 | `DELETE /idea-hassans/:hassan_id` | `同:148` | 発散セッションの削除 | **`DELETE /conversations/{session_id}`** (同) | ✓ |

**#9〜#13 (`idea-hassans` 系 5 本) は [conversation.md](conversation.md) §1.2 が受け先の SSOT** であり、
本表はその参照である (AC-CV-1.2 が「本書に明示されていること」を要求しているため再掲する)。
**本書とあちらで受け先が食い違っていないことが統合時のチェック対象**になる。

### 3.2 v2 のパラメータ・オプションの受け先 (**エンドポイント単位では見えない操作**)

**C-16 は「操作」を落とさないことを求める**。エンドポイントが引き継がれていても、
**クエリパラメータで表現されていた操作が消えると機能が落ちる**。

| v2 の入力 | 出典 | v3 の受け先 | 判断 |
|---|---|---|---|
| `GET /ideas?is_only_business_plan_created=` | `hassan-v2-backend/controller/idea.go:141` | **`GET /ideas?stage=plan`** (§2.2) | 引き継ぐ |
| `GET /ideas?is_only_business_plan_favorite=` | `同:150` | **`GET /ideas?plan_favorite=true`** (§2.2) | 引き継ぐ。**判定元テーブルは企画書ドメインの追加待ち** (§8 の R-IDA-5) |
| `GET /ideas?idea_hassan_id=` | `同:163` | **`GET /ideas?conversation_session_id=`** | 引き継ぐ |
| `GET /ideas?account_id=` | `同:164` | **`scope` + `created_by`** ([README.md](README.md) D-API-8) | **入力形を変える** (v2 の形は他契約のデータが読める入力形 — F-15) |
| `GET /ideas?limit=0` (= 全件) | `同:121`〜`:122` | **受け付けない (400)** (D-API-7) | **落とす。理由**: データ増加でレイテンシが静かに劣化する。全件が要る用途 (エクスポート) は `GET /ideas/csv` が受ける |
| `POST /ideas/evaluate?model=fast\|think` | `同:508` (swag の `@Param model`) / `hassan-v2-backend/usecase/idea/evaluate_ideas.go:184` | **受け付けない** | **落とす。理由**: モデルの解決は `config` の LLM プロファイル表 1 箇所が SSOT ([../llm-migration.md](../llm-migration.md) §5.2) であり、「この機能で使えるモデル」の別定義を作らない方針と正面から衝突する。**C-16 の例外承認が要る可能性がある** → §9 の IDA-R1 |
| `POST /ideas/evaluate` の言語切替 (`language_type`) | `hassan-v2-backend/usecase/idea/evaluate_ideas.go:49` / `prompt/idea/evaluation.en.tmpl` の存在 | **受け付けない (日本語のみ)** | **落とす。理由**: [auth-accounts.md](auth-accounts.md) の **AA-Q4** が「v3 は日本語のみ」を全体の仮定として置いており、本書だけ多言語を持つと整合しない。**同じ仮定に乗る** → §9 の IDA-R2 |
| `POST /ideas/generate/my-idea` の PDF 添付 (`PDFFiles`) | `hassan-v2-backend/usecase/idea/create_my_idea.go:60` | **会話ターン** (持ち込み PDF = 既存②の経路。[conversation.md](conversation.md) §4.3) | 引き継ぐ (受け口が変わる) |

**#6 / #7 (V-3) を `POST /ideas` と会話ターンに割る理由**:

- v2 の `POST /ideas/generate/my-idea` は **①LLM が空欄を補完し ②保存する** の 2 段である
  (`hassan-v2-backend/usecase/idea/create_my_idea.go` の `Execute`)。
  `.../draft` は**①だけを行い保存しない** (`同:207` の `ExecuteDraft` — 同じ UseCase の別メソッド)
- v3 は **CV-D11 で「LLM 生成は会話ターン、人手の編集は REST」と役割を分けた**。
  ①は LLM、②は人手の確定操作なので、**この分割線がそのまま①=会話ターン / ②=`POST /ideas` になる**
- **却下 (a) `POST /ideas/drafts` (LLM 補完だけの REST) を新設する**: [../llm-migration.md](../llm-migration.md) §4.2 が
  V-3 を「独立機能として移植しない (P-2 へ統合)」と決めており、独立した LLM エンドポイントを作ると
  その決定を無言で覆すことになる。加えて O-2 の計測点・`feature` 値・[../testing.md](../testing.md) の
  LLM 経路テストの対象が 1 本増える
- **却下 (b) `POST /ideas` に LLM 補完モード (`complete=true`) を持たせる**: CV-D11 の役割分担が
  1 エンドポイントの中で崩れ、「REST は LLM を呼ばない」という読者の期待が失われる。
  同期 REST で LLM を待つことになり、応答時間の性質が他の REST と変わる
- **この受け方が成立するための条件**: `prompts/conversation/orchestrator.md` に
  **「ユーザーが持ち込んだアイデアを、発散せずに本文だけ補完して提示する」節が要る**。
  現在の [conversation.md](conversation.md) §4.1 は `generate_ideas` の `seed_idea` 引数
  (= 持ち込みアイデアを**種にして発散する**) しか書いておらず、**補完だけを返す経路が明文化されていない** →
  §8 の **R-IDA-3** で起票する

### 3.3 既存データの写像 (DR-3)

**v2 の本番 DB には評価済みのアイデアが存在する**。移行対象と写像は移行計画 (plan.md の Task-2f 系) が
実施主体だが、**値域が変わるものは本書が決める**。

| 対象 | v2 | v3 | 写像 |
|---|---|---|---|
| 総合スコア | `ideas.score integer` = **4 軸の単純合計 (0〜40)** (`hassan-v2-backend/util/score_calculator.go:135` の `CalculateTotalScore` が `uniqueness + market_size + cagr + mission_alignment`) | **`score numeric(3,1)` = 0.0〜10.0 の重み付け平均** (§6.3) | **合計 ÷ 4 を小数 1 桁に丸める**。**5 軸目 (`tech_feasibility`) は v2 に無いため、移行値は 4 軸の平均になる** — 再評価するまで v3 の重み式とは厳密に一致しない。**この事実を移行ログに残す** |
| 各軸スコア | `uniqueness_score` / `mission_alignment_score` / `market_size_score` / `cagr_score` (整数 0〜10) | 同名の 4 軸 (§6.3) | **そのまま**。値域が同じ |
| `tech_feasibility` 他の新設軸 | **無い** | あり | **NULL (未評価)**。`evaluation.axis_scores` から欠落させ、**0 で埋めない** (0 は「実現性が無い」の意味になる) |
| リッチ評価 (`idea_evaluations`) | **無い** (v2 に相当テーブルなし) | あり | **移行しない** (初期は空)。`GET /ideas/{idea_id}/evaluation` は `status=none` を返す |
| `ideas.concept` | あり | **`summary`** | 列名の写像。**[../data-model.md](../data-model.md) に未記録** → §8 の R-IDA-4 |
| `idea_tags` | **無い** | あり | **移行しない** (初期は空。[../data-model.md](../data-model.md) §4.6 が既に「移行対象外 = 初期は空」と書いている) |
| `idea_versions` | **無い** | あり | **移行時に ver 1 を 1 件作る** (§4.2 の「初版」)。作らないと、移行済みアイデアを編集した瞬間に「編集前の内容」がどこにも残らない |

**ロールバック**: 上記はすべて **v2 のテーブルを読むだけで書き換えない**ため、
v3 側のデータを捨てればロールバックが成立する ([idea-boards.md](idea-boards.md) §4 と同じ形)。

---

## 4. アイデアの版管理 (AC-CV-3.2 / CV-D9 / CV-D11)

**本節が回答する ID: D-4 (参照)** / 対応 AC: **AC-CV-3.2**

> **本節は `idea_versions` と `plan_tab_versions` に共通の規則として書いている**
> ([requirements-conversation.md](../../../aidlc-docs/inception/productionization/requirements-conversation.md) §6.1 の 4 が
> 「版と復元の共通規則は共通規則として先に決める」としているため)。
> **企画書タブ側が同じ規則に乗ることの確認は統合時に行う** (§8 の R-IDA-8)。

### 4.1 いつ版を切るか

| 契機 | 版を切るか | `ver_no` | 理由 |
|---|---|---|---|
| **発散でアイデアが生成される** (`generate_ideas`) | **切る (初版 = 1)** | 1 | 初版が無いと、最初の人手編集で「LLM が生成した元の内容」が失われる。`plan_tab_versions.source_idea_version_id` の参照先が生成直後に存在しない状態も作らない |
| **`POST /ideas`** (手動登録) | **切る (初版 = 1)** | 1 | 同上 |
| **`PUT /ideas/{idea_id}`** (人手編集) | **切る** | MAX+1 | **AC-CV-3.2**。企画書の stale 判定 (`plan_tab_versions.source_idea_version_id` / `source_hash`) が成立するために、**内容が変わるたびに参照可能な版が要る** (BE-4) |
| **`PUT /ideas/{idea_id}` のうち `visibility` だけの変更** | **切らない** | 変わらない | **`visibility` は本文ではない** — 共有範囲の切り替えで版が増えると、企画書の stale 判定 (`plan_tab_versions.source_hash`) が内容の変化なしに outdated になる (BE-4 の誤検知)。**§4.2 の「版に入れないもの」に `visibility` が含まれている**のと整合する |
| **`POST …/versions/{version_id}/restore`** (復元) | **切る** | MAX+1 | CV-D9。復元は「過去版を最新として複製する」操作であり、**履歴を壊さない** |
| **`PUT /ideas/{idea_id}/star`** | **切らない** | — | スターは内容ではない。切ると版が実質的な操作ログになり、`source_hash` の対象外フィールド ([../data-model.md](../data-model.md) §4.11.3 が `star_rating` を除外) と矛盾する |
| **タグだけの変更** | **切る** | MAX+1 | `tags` は `snapshot` に入る (§4.2)。**却下**: タグを版の対象外にする — 復元したときにタグだけ復元されず、「戻したのに元と違う」状態になる |
| **評価の生成 / 再評価** | **切らない** | — | 評価は**派生物**であり、アイデアの内容ではない ([../data-model.md](../data-model.md) §4.11.3 の依存グラフ) |

**`ideas` 本体は常に最新版と同じ内容を持つ** (最新版だけを `ideas` から読み、他は `idea_versions` から読む
という分岐を作らない)。

### 4.2 版に入れるもの / 入れないもの

| 区分 | フィールド |
|---|---|
| **`snapshot` に入れる** | `title` / `summary` / `target_market` / `customer` / `issue` / `solution` / `tags` |
| **入れない** | `star_rating` / `seq_no` / `visibility` / `deleted_at` / `evaluation` 系の列 / `created_at` / `updated_at` |

- **入れない理由**: これらは「アイデアの内容」ではなく状態・メタであり、版に含めると
  **復元でスターや可視性まで巻き戻る**。加えて `source_hash` の計算対象
  ([../data-model.md](../data-model.md) §4.11.3 =「評価に影響するフィールドのみ」) と一致しなくなり、
  **内容と無関係な更新で評価が stale になる**
- **`snapshot` の項目と `source_hash` の対象は同じ集合にする**。実装は `entity/idea` の 1 関数が
  両方を作る (PoC も同じ思想 — `claude_managed_agents/cmd/devui/idea_evaluate.go:139`〜`:147` の
  `computeIdeaSourceHash` が「評価プロンプトが実際に詰めるフィールド」と一致させると明記している)
- **`market_size` / `cagr` / `uniqueness` / `mission_alignment` を `snapshot` に入れない** —
  これらは**評価が書き込む派生列**であり、人手編集の対象ではない (§2.3 の更新可能フィールドに含めていない)

### 4.2.1 版の URL 識別子に PK を使う理由 (2026-08-02 追加)

**本書は `{version_id}` (= `idea_versions.id` の PK) を使う**が、
[plans.md](plans.md) は `{ver_no}` (連番) を使う。**同じ「版」の概念で識別子が違う**ため、
**意図的な差であることと理由をここに明記する** (揃えないまま放置しない)。

| | 本書 (`idea_versions`) | [plans.md](plans.md) (`plan_tab_versions`) |
|---|---|---|
| URL の識別子 | **PK (`{version_id}`)** | **連番 (`{ver_no}`)** |
| 理由 | **PK が他テーブルから参照されている** — `plan_tab_versions.source_idea_version_id` と `idea_evaluations.source_idea_version_id` が `idea_versions.id` を指す ([../data-model.md](../data-model.md) §4.6)。**FE は企画書や評価の応答から PK を受け取る**ため、その PK でそのまま版を引ける形にする。`ver_no` にすると FE が PK → `ver_no` の変換表を持つことになる | **PK が他テーブルから参照されていない** (企画書の grounding は台帳の `entry_id` を使う)。URL が既に 3 段ネスト ([plans.md](plans.md) §11 の D-PL-18) で、そこに PK を足しても短くならない |

**[plans.md](plans.md) D-PL-18 の却下 (b)「PK を URL に出すと FE が 2 種類の識別子を持つ」は
企画書タブの版に限った判断**であり、本書には適用されない —
**アイデアの版は PK が既に FE へ渡っている**ため、`ver_no` を使う方が識別子を 2 種類にする。

**共通させるもの**: 復元は新版を作る (`ver_no` は MAX+1) / 削除を持たない / 採番は 1 SQL に閉じる。
**識別子だけが違い、意味論は同一**である。

### 4.3 採番と冪等性 (BE-11)

| # | 規約 |
|---|---|
| 1 | **採番と Insert は 1 つの SQL 文で行う** (`COALESCE(MAX(ver_no),0)+1`)。`SELECT MAX` を別クエリにしない ([../data-model.md](../data-model.md) §4.11.1 の規約 1) |
| 2 | **`ver_no` を引数で受け取るメソッドを作らない** (同 規約 4)。PoC の「固定 ver での Insert」(BE-11) を別の場所で再発させない |
| 3 | **`UNIQUE (idea_id, ver_no)` 違反は握り潰さず `CodedError` にする** (同 規約 2)。UseCase は同一トランザクション内で 1 回だけ再試行する (同 規約 3) |
| 4 | **本文更新と版の追記は同一トランザクション**で行う。`ideas` だけ更新されて版が残らない状態を作らない |

### 4.4 削除を持たない (CV-D9)

- **版の削除操作を持たない** (論理削除も含む)。理由: `plan_tab_versions.source_idea_version_id` と
  `idea_evaluations.source_idea_version_id` が版を参照しており、**版を消すと派生物の stale 判定が
  「参照先が無い」に落ちて、古いか新しいかを判定できなくなる** (BE-4)
- **却下 (a) 論理削除にして参照は残す**: 「削除済みの版を参照している企画書」を FE がどう表示するかが
  決まらず、UI 側の分岐だけが増える
- **却下 (b) PoC 方式 (対象より新しい版を物理削除して巻き戻す)**:
  `claude_managed_agents/internal/db/migrations/000022_idea_versions.up.sql:11`〜`:12` のコメントが
  この方針を明記しているが、**誤操作が不可逆**で監査でも「何を戻したか」が追えない
  ([../data-model.md](../data-model.md) §4.6 が同じ理由で却下済み)
- **版が増え続けることの扱い**: 上限・自動削除を設けない。1 アイデアの版数は人手編集の回数であり、
  行数が伸びるテーブルの分類 ([../data-model.md](../data-model.md) §3.4) に入っていない

---

## 5. タグ (AC-CV-3.1 / BE-10 のクローズ)

**本節が回答する ID: A-3 (参照)** / 対応 AC: **AC-CV-3.1**

### 5.1 BE-10 のクローズ

[idea-boards.md](idea-boards.md) §8.1 は **`Idea.tags` を返すと確定しながら、書き込み側を本増分に委譲**していた
(読む側だけあって書く側が無い = BE-10)。**本節が書き手を確定させ、この状態を解消する**。

| 台帳・列 | 書き手 | 読み手 |
|---|---|---|
| `idea_tags` | **①発散時** — `generate_ideas` の生成物に含まれる分類語 (PoC の `diverge.Idea.Categories` — `claude_managed_agents/internal/agent/diverge/schema.go:31` の `Categories []string`) を初期値として登録する / **②`PUT /ideas/{idea_id}` の `tags`** (全置換) / **③`POST /ideas` の `tags`** | `GET /ideas` の `keyword` 検索 ([idea-boards.md](idea-boards.md) §8.1) / `Idea.tags` / `BoardItem.idea.tags` / CSV には**含めない** (§2.6 の 16 列に無い = v2 に無い列を増やさない) |

**書き手①を入れる理由**: 人手のみにすると**発散直後のアイデアのタグが必ず空**になり、
「`keyword` の対象にタグを含める」という [idea-boards.md](idea-boards.md) §8.1 の決定が
初期状態では空振りする。**却下 (a) 人手のみ**: 上記。
**却下 (b) LLM 由来と人手由来を `origin` 列で区別する**: FE に 2 種を表示し分ける要件が無く、
`PUT` の全置換セマンティクスに「LLM 分は残す」という分岐が生まれる。`keyword` 検索も 2 系統になる。

### 5.2 値域と規約 (DR-5 対策 — 実装者が判断しないための具体)

| 項目 | 決定 |
|---|---|
| 型 | `string[]`。**空配列を許す。null は受け付けず、返さない** |
| 1 タグの値 | **前後の空白をトリムした後、空文字でないこと**。改行・タブを含むタグは **400** |
| 正規化 | **行わない** (大文字小文字・全角半角・表記ゆれを寄せない)。`asset_tags` と同じ扱い ([../data-model.md](../data-model.md) §4.4)。**却下**: 正規化する — 「脱炭素」と「脱炭素化」の同一視規則をどこかに書くことになり、辞書の SSOT が生まれる |
| 重複 | **サーバが先勝ちで除去し 200 を返す** (409 にしない)。全置換の入力に同じ値が 2 回入るのは入力ミスであり、操作の意図は明確 |
| 並び順 | **送られた配列の順序を `idea_tags.sort_order` に保存**し、読み出しは `sort_order` 昇順 ([idea-boards.md](idea-boards.md) §8.1 の「登録順」) |
| 1 タグの最大長 / 1 アイデアの最大件数 | **`config` の定数 1 箇所を SSOT とする** (BE-2)。**本書・プロンプト・FE に数値を書かない** ([README.md](README.md) D-API-7 と同じ方針)。超過は **400** |
| 更新方式 | **全置換**。`PUT` のボディに `tags` が**含まれない場合は変更しない** (§2.3) |
| 所有者列 | `idea_tags` は `contract_id` + `account_id` を持つ ([../data-model.md](../data-model.md) §4.6 / §4.1.1)。**タグの書き込みでも親アイデアの所有者条件を必ず通す** (§1.4) |

---

## 6. 評価 (AC-CV-3.4 / AC-CV-3.5 / LM-R6)

**本節が回答する ID: A-6, O-2, O-3, O-4, O-5** / 対応 AC: **AC-CV-3.4, AC-CV-3.5, AC-CV-5.7 (参照)**

### 6.1 v2 (V-2) と PoC (P-5) の実装事実 (2026-08-01 に一次ソースで実測)

| # | 事実 | v2 (V-2) | PoC (P-5) |
|---|---|---|---|
| 1 | 入口 | `POST /ideas/evaluate?idea_hassan_id=N` (`hassan-v2-backend/router/router.go:126`)。**発散セッション単位の一括**で、同期 JSON を返す (`hassan-v2-backend/controller/idea.go:513`〜`:553`) | `POST /api/ideas/evaluate`。**アイデア 1 件ずつ** (`claude_managed_agents/cmd/devui/idea_evaluate.go:31` の `ideaEvaluateRequest` が `Idea` 1 件 + `Asset`) |
| 2 | LLM 呼び出しの粒度 | **全アイデアを 1 プロンプトに詰めて 1 回** (`hassan-v2-backend/prompt/idea/evaluation.tmpl` が `{{ range $i, $v := .Ideas }}` で全件を展開) | **1 アイデア 1 回**。`MaxTokens = 8192` (`claude_managed_agents/cmd/devui/idea_evaluate.go:44`)、タイムアウト 60 秒 (`同:47`) |
| 3 | 出力の規模 | 1 アイデアあたり 6 フィールド (`hassan-v2-backend/prompt/idea/evaluation.tmpl` の出力 JSON) | 1 アイデアあたり **22 フィールド** (`claude_managed_agents/prompts/idea_evaluate_system.md:7`〜`:33` のスキーマ) |
| 4 | 市場規模・CAGR | **Web 検索と並列実行**し、検索結果が空なら LLM 推定値に「（推定値）」を付けてマージする (`hassan-v2-backend/usecase/idea/evaluate_ideas.go` の `mergeWebSearchWithEvaluationEstimates`)。出典は OGP 4 項目の配列 (`hassan-v2-backend/llm/types.go` の `OGPInfo`) | **LLM が値・出典・根拠を出す** (`market_size.value` / `.source` / `.note`)。Web 検索を伴わない |
| 5 | スコアの計算主体 | **市場規模と CAGR は Go が閾値表で計算** (`hassan-v2-backend/util/score_calculator.go:18` / `:93`)。新規性・ミッション整合は LLM が 0〜10 の整数で出す | **全軸を LLM が 0.0〜10.0 の小数で出す**。`composite` も LLM が重み式で計算 (`claude_managed_agents/prompts/idea_evaluate_system.md:92`〜`:93`) |
| 6 | 総合スコア | **4 軸の単純合計 (0〜40)** (`hassan-v2-backend/util/score_calculator.go:135`) | **5 軸の重み付け平均 (0.0〜10.0)**: `novelty*0.20 + mission_fit*0.20 + market_size*0.25 + market_cagr*0.15 + tech_feasibility*0.20` |
| 7 | 保存先 | `ideas` の列 (`score` / 各軸スコア / `market_size` / `cagr` / `uniqueness` / `mission_alignment` / OGP 2 列) | `idea_evaluations` (jsonb) + `source_hash` による stale 判定 (`claude_managed_agents/cmd/devui/idea_evaluate.go:108` / `:139`〜`:147`) |
| 8 | 評価の入力 | アイデア 6 項目 + **会社ミッション** (`hassan-v2-backend/prompt/idea/evaluation.tmpl` の `{{ .CompanyMission }}`) | アイデア全項目 + **アセット情報** (`ideaEvaluateRequest.Asset`) + テーマ |
| 9 | 切り詰めの扱い | **検知しない** (`stop_reason` が抽象に無い — [../../analysis/v2-llm-inventory.md](../../analysis/v2-llm-inventory.md)) | **`stop_reason == max_tokens` を検出して即エラー** (`claude_managed_agents/cmd/devui/idea_evaluate.go:192`)。パース失敗は 2 回まで再試行 (`同:50`) |

### 6.2 評価軸の対照表 (**LM-R6 の調査結果**。AC-CV-3.4)

**「採る / 採らない」を全件書く。無言で落とさない** (CV-DF5)。

| 軸 / 項目 | v2 (V-2) | PoC (P-5) | v3 の統合結果 | 採否の理由 |
|---|---|---|---|---|
| 新規性 | `uniqueness` (文) + `uniqueness_score` (整数 0〜10。4 段の基準表を prompt が持つ) | `novelty: {score, rationale}` (小数 0.0〜10.0) | **`novelty: {score, rationale}`** (主軸) | **採る (統合)**。同じ軸。**v2 の 4 段の基準表 (10 / 7-9 / 4-6 / 1-3 の各説明) を v3 のプロンプトに取り込む** — PoC は基準表を持たずスコアがブレやすい |
| ミッション整合性 | `mission_alignment` + `mission_alignment_score` (同上の 4 段基準) | `mission_fit: {score, rationale}` | **`mission_fit: {score, rationale}`** (主軸) | **採る (統合)**。同上。**v2 の 4 段基準表を取り込む** |
| 市場規模 | `market_size_estimate` (LLM) + Web 検索値 + **Go が計算する `market_size_score`** | `market_size: {score, value, source, note}` (score も LLM) | **`market_size: {score, value, source, note}`。ただし `score` は Go が計算する** | **両方採る**。値・出典・根拠は PoC の形 (構造化されている)、**スコアは v2 の閾値表**を採る。理由は §6.3 の「スコアの計算主体」 |
| CAGR | `cagr_estimate` + Web 検索値 + **Go が計算する `cagr_score`** | `market_cagr: {score, percent, source, note}` | **`market_cagr: {score, percent, source, note}`。`score` は Go が計算する** | 同上 |
| 技術実現性 | **無い** | `tech_feasibility: {score, rationale}` | **採る** (主軸) | **採る**。アセット (技術・IP) を起点にする v3 の中核概念で、composite の重みにも入っている。落とすと `composite` の重み式を作り直すことになる |
| アセット適合性 | **無い** | `asset_fit: {score, rationale}` | **採る** (補助軸・composite に入れない) | **採る**。アセット起点の発散を行う v3 に固有の観点。PoC でも composite には入っていない |
| 差別化 | **無い** | `differentiation: {score, rationale}` | **採る** (補助軸) | **採る**。競合・代替手段への優位性は企画書タブの入力にもなる |
| 業界課題フィット | **無い** | `industry_challenge_fit: {score, rationale}` | **採る** (補助軸) | **採る**。PoC のプロンプトが「composite には組み込まない・表示専用」と明記しており (`claude_managed_agents/prompts/idea_evaluate_system.md:132`)、その扱いを維持する |
| 業界優位性 | **無い** | `industry_advantage: {score, rationale}` | **採る** (補助軸) | **採る**。同上 (`同:145`) |
| 顧客課題 / 解決方法 / 収益モデル | **無い** (アイデア本体の `issue` / `solution` はあるが評価出力ではない) | `customer_problem` / `solution_method` / `revenue_model` | **採る** (スコアなし) | **採る**。詳細モーダルの 3 列表示に対応する。**アイデア本体の `issue` / `solution` を上書きしない** (評価は派生物) |
| 主要リスク | **無い** | `key_risks: [string]` | **採る** | **採る**。企画書タブ (リスク) の入力にもなる |
| 使用したコア技術 | **無い** | `used_core_technologies: [{name, reason}]` | **採る** | **採る**。`idea_assets` (どのアセットを使ったか) と対になる説明 |
| 採用障壁 | **無い** | `adoption_barriers: [{barrier, reason}]` | **採る** | **採る**。`record_rejection` の判断材料になる |
| コア改善点 | **無い** | `core_improvements: [{target, action}]` | **採る** | **採る**。アセットの機能ツリー改善への還流 |
| 思考根拠 / 強みサマリ / マッチング軸 | **無い** | `agent_rationale` / `strength_summary` / `matching` | **採る** | **採る**。`matching` は `match_functions` の出力と役割が重なるが、**評価は 1 アイデアの説明・`match_functions` は機能 × 領域の総当たり**で粒度が違う |
| 総合スコア | `score` = 4 軸の**単純合計 (0〜40)** | `composite` = 5 軸の**重み付け平均 (0.0〜10.0)** | **`composite` (0.0〜10.0 の重み付け平均)** | **PoC を採る。v2 を落とす。理由**: ①0〜40 の合計は「10 点満点の軸を 4 つ足した数」で、ユーザーに提示する尺度として意味を持たない ②v3 は主軸が 5 つになるため合計の上限が 50 に変わり、**v2 の 0〜40 に慣れたユーザーの解釈が壊れる** ③[idea-boards.md](idea-boards.md) のプロトタイプ表示 (`"B+・4.1"`) と発散結果の `score` ([conversation.md](conversation.md) §5.2) が既に 10 点満点系である。**既存データの写像は §3.3** |
| グレード | **無い** | `grade` (A/B/C/D)。**composite のバンドから Go が導出**する (`claude_managed_agents/cmd/devui/conversation_tools_generate.go:615`〜`:626`。8.0 以上 = A / 6.0 = B / 4.0 = C / それ未満 = D) | **採る (Go が導出)** | **採る**。LLM に出させない (バンドの SSOT がプロンプトに移り、composite と食い違う余地ができる) |
| 会社ミッションを入力に渡す | **渡す** (`{{ .CompanyMission }}`) | **渡さない** (テーマとアセットのみ) | **採る (渡す)** | **採る**。`mission_fit` / `mission_alignment` を評価する以上、**ミッションを渡さないと評価が成立しない**。v3 の渡し元は**テーマのミッション** ([themes.md](themes.md) の `mission`) — v2 は `idea_hassans.CompanyMission` (会社単位) だが、v3 はテーマ単位のミッションを持つため**より近い文脈になる** |
| アセット情報を入力に渡す | **渡さない** | **渡す** (`Asset`) | **採る (渡す)** | **採る**。`asset_fit` / `tech_feasibility` の評価に必要 |
| 市場規模・CAGR の Web 検索 | **する** (評価と並列) | **しない** | **統合の対象外** — **V-4 / V-5 として独立移送**され、`research_market` にも吸収しない ([conversation.md](conversation.md) §7 の **D-CV-13** が LM-R8 として判定済み) | **落とさない**。評価 (P-5) の中では行わず、**V-4 / V-5 の経路が別途 `market_size` / `cagr` を埋める**。§6.3 の「値の出所」で扱う |
| 「（推定値）」サフィックス | **付ける** (`mergeWebSearchWithEvaluationEstimates`) | `source: "推定"` と書く | **PoC の形 (`source` フィールド)** を採る | **統合**。同じ意味を表す 2 形式のうち、**構造化されている方**を採る。文字列に接尾辞を埋め込むと FE がパースする必要があり、v2 は実際に `stripApproximatePrefix` / `stripEstimatedSuffixIfHasOGP` という**文字列の付け外し関数を 3 つ**持っている |
| 出典の形式 | **OGP 4 項目** (`title` / `image` / `url` / `site_name`) の配列 | **文字列 1 本** (`"矢野経済研究所(2024)"`) | **`source: {label, url?}`** の形にする | **統合**。**`image` (OGP 画像) は落とす** — 外部画像の取得・保管・失効の扱いが必要になり、[README.md](README.md) D-API-14' (非公開バケット + 署名 URL) の方針とも噛み合わない。**`title` / `url` / `site_name` は `label` / `url` に畳む** |
| モデル選択 (`fast` / `think`) | **あり** | 無い | **落とす** | §3.2 の表を参照 (`config` の LLM プロファイルが SSOT)。**C-16 の例外承認が要る可能性** → §9 の IDA-R1 |
| 言語切替 (日 / 英) | **あり** (`evaluation.en.tmpl`) | 無い | **落とす (日本語のみ)** | §3.2 の表を参照 ([auth-accounts.md](auth-accounts.md) AA-Q4 と同じ仮定) → §9 の IDA-R2 |

**落とす項目の総数**: 上表で「落とす」と書いたのは **総合スコアの 0〜40 尺度 / OGP の `image` / モデル選択 /
言語切替** の 4 件で、**すべて理由を書いた**。評価の**軸**は 1 つも落としていない。

### 6.3 統合後の評価 (`prompts/idea/evaluate.md` の出力契約)

**主軸 (composite に入る 5 軸)**: `novelty` / `mission_fit` / `market_size` / `market_cagr` / `tech_feasibility`
**補助軸 (composite に入らない・表示専用)**: `asset_fit` / `differentiation` / `industry_challenge_fit` / `industry_advantage`

```json
{
  "customer_problem": "…", "solution_method": "…", "revenue_model": "…",
  "novelty":          { "score": 7.0, "rationale": "…" },
  "mission_fit":      { "score": 6.0, "rationale": "…" },
  "market_size":      { "score": 8, "value": "12.4兆円", "source": { "label": "矢野経済研究所(2024)", "url": "…" }, "note": "…" },
  "market_cagr":      { "score": 5, "percent": "14.2%", "source": { "label": "推定" }, "note": "…" },
  "tech_feasibility": { "score": 6.5, "rationale": "…" },
  "asset_fit":        { "score": 7.5, "rationale": "…" },
  "differentiation":  { "score": 7.0, "rationale": "…" },
  "industry_challenge_fit": { "score": 6.0, "rationale": "…" },
  "industry_advantage":     { "score": 5.5, "rationale": "…" },
  "composite": 6.4, "grade": "B",
  "agent_rationale": "…", "strength_summary": "…", "matching": "…",
  "key_risks": ["…"],
  "used_core_technologies": [{ "name": "…", "reason": "…" }],
  "adoption_barriers":      [{ "barrier": "…", "reason": "…" }],
  "core_improvements":      [{ "target": "…", "action": "…" }]
}
```

**スコアの計算主体 (実装者が判断しないための具体)**:

| 値 | 誰が決めるか | 根拠 |
|---|---|---|
| `novelty.score` / `mission_fit.score` / `tech_feasibility.score` / 補助軸の `score` | **LLM** (0.0〜10.0 の小数 1 桁) | 定性判断であり閾値表を書けない |
| **`market_size.score` / `market_cagr.score`** | **`entity/idea` の副作用のない関数** (整数 0〜10)。LLM が出した `value` / `percent` の文字列を入力にする | **v2 の閾値表を移植する** (`hassan-v2-backend/util/score_calculator.go:18`〜`:88` / `:93`〜`:129`)。理由: 同じ市場規模に毎回同じスコアが付き、**UT で固定できる**。LLM に出させると同一入力で値がぶれ、[../testing.md](../testing.md) の期待値が書けない |
| **`composite`** | **`entity/idea` の副作用のない関数**。重み式は PoC と同じ (`novelty*0.20 + mission_fit*0.20 + market_size*0.25 + market_cagr*0.15 + tech_feasibility*0.20`) | PoC は LLM に計算させている (`claude_managed_agents/prompts/idea_evaluate_system.md:92`) が、**算術を LLM にやらせると軸のスコアと合わない値が返る**。重み式の SSOT を `entity/idea` に置く |
| **`grade`** | **`entity/idea` の副作用のない関数**。バンドは PoC と同じ (8.0 / 6.0 / 4.0) | `claude_managed_agents/cmd/devui/conversation_tools_generate.go:615`。**発散直後の `grade` ([conversation.md](conversation.md) §5.2) と同じ関数を使う** — 2 箇所で別のバンドを持たない (BE-2) |

**v2 の閾値表を移植する際の 1 点の修正**: `CalculateMarketSizeScore` は
`<= 300` → 1、`>= 400 && < 500` → 2 と書かれており、**300 超〜400 未満が全 case を外れて `default` の 1 に落ちる**
(`hassan-v2-backend/util/score_calculator.go:65`〜`:85`)。結果は連続 (どちらも 1) なので**挙動は変わらない**が、
v3 では **`< 400` → 1** と書き直して境界の穴を無くす。

**値の出所 (`market_size.value` / `market_cagr.percent`)**:

| 出所 | 優先 | `source.label` |
|---|---|---|
| **V-4 / V-5 の Web リサーチ結果** (`ideas.market_size` / `cagr` が既に埋まっている) | **1** | 検索で得た出典 |
| **評価 LLM の推定値** | 2 | **`"推定"`** |
| どちらも無い | — | `value` は空文字。**`score` は 1** (v2 の閾値表の既定と同じ) |

**この優先順位は v2 の `mergeWebSearchWithEvaluationEstimates` と同じ**
(`hassan-v2-backend/usecase/idea/evaluate_ideas.go` — Web 検索結果が空または「－（推定値）」なら LLM 推定値を使う)。
**v2 が文字列の接尾辞で表していた区別を、`source.label` の構造で表す**ように変えた点だけが違う。

**保存先の書き分け (2 箇所に同じ値を持たない)**:

| 保存先 | 何を持つか |
|---|---|
| `ideas` の列 (`score` / 各軸スコア / `market_size` / `cagr` / `uniqueness` / `mission_alignment`) | **一覧・CSV・ボードが読む軽い値**。`Idea.evaluation` (§2.1) がここから作られる |
| `idea_evaluations.evaluation` (jsonb) | **本文つきのリッチ評価の全体**。詳細モーダルが読む |
| — | **`ideas.uniqueness` / `mission_alignment` には `novelty.rationale` / `mission_fit.rationale` を入れる** (v2 の同名列と同じ用途 = 説明文)。CSV の 9・10 列目がこれを読む (§2.6) |

**書き込みは同一トランザクションで行う** — `ideas` の列だけ更新されて `idea_evaluations` が古い状態を作らない。

### 6.4 再評価の入口 (AC-CV-3.5)

**判定基準は CV-D5 =「LLM が呼び出しを決める必要があるか」**。

| # | 決定 |
|---|---|
| 1 | **tool にしない。REST (`POST /idea-evaluations`) を入口にする** — [conversation.md](conversation.md) §4.2 / D-CV-15 の判定と一致する (同書が「REST のパス・入出力・v2 の V-2 との評価軸統合は `ideas.md` が確定させる」と委譲している) |
| 2 | **非同期ジョブ**として実行する ([README.md](README.md) §1.3 の J-1〜J-7)。`POST` は **202** を返し、状態は `GET /idea-evaluations` / `GET /ideas/{idea_id}/evaluation` が返す |
| 3 | **1 リクエストで `idea_ids` に渡せる件数の上限は `config` の定数 1 箇所** (BE-2)。超過は 400。**本書に数値を書かない** |
| 4 | **冪等キー** (J-5) は **`(idea_id, source_hash)`**。同じ内容のアイデアに対する `queued` / `running` のジョブが既にあれば**新規作成せず既存を返す**。二重クリックで LLM コストが倍にならない |
| 5 | **再実行は新しいジョブを作る** (J-4)。`failed` のジョブ行を `queued` に戻さない (何回失敗したかが追えなくなる) |
| 6 | **自動再評価をしない** — 本文を編集しても評価は stale になるだけで、再評価はユーザー操作 ([../data-model.md](../data-model.md) §4.11.3 の `plan_tab_versions` と同じ扱い。LLM コストを暗黙に発生させない) |
| 7 | **取り残しの回収** (J-3): `status` が `queued` / `running` のまま `heartbeat_at` が閾値を超えた行を `failed` (`failure.code = stale_aborted`) に落とす。判定はプロセス起動時と定期実行の 2 経路 |

**却下 (a) `evaluate_idea` tool を足す**: [conversation.md](conversation.md) §4.2 が既に却下済み
(発散結果に `score` / `grade` が入っており、ターンの途中で LLM が「今 1 件を評価すべきか」を判断する場面が無い)。
**却下 (b) v2 と同じ同期 REST**: v2 が同期で成立していたのは**全アイデアを 1 回の LLM 呼び出しで評価していた**
(`hassan-v2-backend/prompt/idea/evaluation.tmpl` が `range .Ideas`) からである。
v3 は PoC のリッチ評価 (1 件 22 フィールド・`MaxTokens` 8192) を採るため、**全件を 1 回に詰めると
`max_tokens` 切り詰め (BE-6) が構造的に起きる** → 1 件 1 呼び出し → N 件で同期 HTTP の時間内に収まらない。
**却下 (c) 会話ターンと同じ同期 SSE**: §7 の D-IDA-9。

### 6.5 A-6 (LLM への越境) への回答

| # | 決定 |
|---|---|
| ① | **LLM に ID を解決させない**。評価の入力は **UseCase が所有者条件付きクエリで取得済みのアイデア・テーマ・アセットの本文**であり、LLM が ID を返して何かを引く経路が無い ([conversation.md](conversation.md) §4.4 の①と同じ原則) |
| ② | **`POST /idea-evaluations` の `idea_ids` は所有者条件付きクエリの入力**として扱う。存在確認 (行が nil でない) を所有権の検証に使わない (A-4)。1 件でも所有者でなければジョブを 1 つも作らない (§1.4 の⑤) |
| ③ | **評価に渡すアセットは、そのアイデアの `idea_assets` に紐づく行だけ**を所有者条件付きで取得する。**アイデアの本文に書かれたアセット名で検索しない** (LLM の出力を検索キーにすると他人のアセットに当たり得る) |
| ④ | **テーマのミッション**も所有者条件付きで取得する (§6.2 の「会社ミッションを入力に渡す」)。**アイデアの `theme_id` は DB 上の FK であり LLM 由来ではない**ため、`ideas` の行を所有者条件で取れた時点でテーマも同一所有者である |
| ⑤ | **所有者不一致を warn ログ + メトリクスに出す** (件数・`request_id`)。無言にすると「スコープの渡し忘れ (実装バグ)」と「越境の試行」が両方とも検知できない ([conversation.md](conversation.md) §4.4 の④) |

### 6.6 O-2 (計測) への回答

| 項目 | 値 |
|---|---|
| `feature` | **`idea.evaluate`** — [conversation.md](conversation.md) §3.3 の表と同じ値。**`entity/` の const 群 1 ファイル**に列挙し、リテラルを直書きしない ([../observability.md](../observability.md) §4.2) |
| `route_kind` | **`direct_api`** (Managed Agent ではない。[conversation.md](conversation.md) §3.2 の P-5) |
| 計測点 | **`gateway/anthropic` の単一関門**。**評価の UseCase に計測コードを書かない** (CV-DF3) |
| 記録項目 | [../observability.md](../observability.md) §4.2 の全項目 (`input_tokens` / `output_tokens` / キャッシュ 2 カウンタ / `stop_reason` / `duration_ms` / `outcome` / `theme_id`) |
| `theme_id` | **必ず埋まる** — 評価対象のアイデアは `theme_id` を NOT NULL で持つ ([../data-model.md](../data-model.md) §4.6)。O-3 のテーマ単位集計に穴が空かない |

**`feature` 値を増やさない** — 本書の LLM 経路は 1 本だけで、[conversation.md](conversation.md) §3.3 が
既に `idea.evaluate` を列挙している。**本書は新しい `feature` を追加しない**
(同書 §8 の R-CVA-5 が登録を起票済み)。

### 6.7 O-4 (失敗の可観測性) への回答

**分類の SSOT は [../observability.md](../observability.md) §4.3**。本書は**評価経路での現れ方**を確定させる。

| 事象 | 判別 | 応答 | §4.3 |
|---|---|---|---|
| 出力の切り詰め | `stop_reason == max_tokens` | ジョブを **`failed`** にし `failure.code` を設定。**部分的な JSON を保存しない** | **F-1** |
| JSON パース失敗 | 構造化出力のパースエラー | **同一パラメータで最大 1 回だけ再試行**し、失敗ならジョブを `failed` に。**フォールバックで成功にしない** | **F-2** |
| タイムアウト | 1 呼び出しの `timeout` ([../llm-migration.md](../llm-migration.md) §5.2 のプロファイル) | ジョブを `failed` に | **F-4** |
| 取り残し (デプロイでプロセスが消えた) | `heartbeat_at` の閾値超過 | `failed` (`stale_aborted`) ([README.md](README.md) §1.3 の J-3) | **F-4** |
| 所有者不一致 | クエリ結果 0 件 | 403 / 404 (§1.3) + warn + メトリクス | §6.5 の⑤ |

- **`MaxTokens` は出力規模に対して余裕を持たせる** (BE-6)。PoC は項目増加で 4096 → 8192 に引き上げた
  経緯があり (`claude_managed_agents/cmd/devui/idea_evaluate.go:39`〜`:44` のコメント)、
  **v3 は v2 の 4 段基準表を取り込んで rationale が長くなるため、同じ値では足りない可能性がある** →
  値は `config` の LLM プロファイル (`max_tokens`) が SSOT で、本書に書かない
- **再試行が同じ deadline を共有しないこと** (BE-6 の後半)。1 回目と 2 回目でそれぞれ
  `context.WithTimeout` を張り直す。PoC は同一 deadline を共有して `context deadline exceeded` を誘発した
- **すべて warn ログ + メトリクスに出す。握り潰さない** (CV-DF4)

---

## 7. 設計判断

| # | 論点 | 採用案 | 却下案と理由 |
|---|---|---|---|
| **D-IDA-1** | アイデアの API の置き場所 | **`docs/design/API/ideas.md` に集約する。[idea-boards.md](idea-boards.md) §7 の参照系 3 本 + §2.4 の CSV を移設する** (CV-D2) | (a) 参照系を [idea-boards.md](idea-boards.md) に残す (現状): 同じ `ideas` テーブルの API SSOT が 2 ファイルに割れる。**同節自身が「生成系が確定した時点で統合され直す可能性が高い」と予告している**。(b) 参照系だけ移して CSV を残す: `/ideas` 配下が 2 ファイルに割れたままで AC-CV-3.3③ を満たさない |
| **D-IDA-2** | 人手編集の入口 | **`PUT /ideas/{idea_id}` が本文とタグをまとめて更新する** (CV-D11) | (a) `PUT /ideas/{idea_id}/tags` を分ける: 1 リソースの更新が 2 エンドポイントに割れ、**部分更新の競合 (どちらが後勝ちか) を別途決める**ことになる。`asset_tags` はアセットの更新 API でまとめて更新する形になっており揃わない。(b) 会話ターン経由のみ (tool 追加): CV-D5 の判定基準 (ユーザー操作で起動が決まるものは REST) に反する |
| **D-IDA-3** | **共有ボード経由で見える他人のアイデアへの書き込み** | **403 を返す (所有者のみ書き込み可)** | (a) 404 を返す: 直前の GET で存在を知っている相手に対して秘匿にならず、[README.md](README.md) §2.5 の判定境界と矛盾する。(b) ボードの `editor` に編集を許す: **v2 で他人が触れなかったアイデア本文が切替後に触れるようになる** = サイレントな権限昇格 (DR-3)。[idea-boards.md](idea-boards.md) D-IB-8 が同じ理由で平坦化を却下している |
| **D-IDA-4** | **v3 の総合スコアの尺度** | **0.0〜10.0 の重み付け平均 (PoC の `composite`)** | (a) v2 の 0〜40 の単純合計: 主軸が 5 つになると上限が 50 に変わり、**v2 に慣れたユーザーの解釈が壊れる**。「10 点満点の軸を 4 つ足した数」は提示尺度として意味を持たない。(b) 両方返す: 同じ事実を 2 尺度で返し、FE がどちらを表示するかの判断が UI ごとに散る (D-IB-1 が却下した「参照 + スナップショットの両持ち」と同型) |
| **D-IDA-5** | **市場規模 / CAGR のスコアの計算主体** | **Go (`entity/idea` の副作用のない関数) が v2 の閾値表で計算する** | (a) PoC 踏襲 (LLM が score を出す): 同一入力でスコアがぶれ、**UT で固定できない**。v2 は決定的な閾値表を持っており ([../llm-migration.md](../llm-migration.md) §3 の「Go に固定されている処理」と同じ性質)、これを捨てる理由が無い。(b) LLM の score と Go の score を両方持つ: どちらが正か決まらない |
| **D-IDA-6** | **`composite` と `grade` の計算主体** | **Go が計算する** | (a) PoC 踏襲 (LLM が重み式で計算する — `claude_managed_agents/prompts/idea_evaluate_system.md:92`): **算術を LLM にやらせると軸のスコアと合わない値が返る**。重み式の SSOT がプロンプトに移り、変更が Agent 再発行と結びつく。(b) grade を LLM に出させる: 発散直後の grade (Go が導出 — `conversation_tools_generate.go:615`) と**バンドが 2 箇所**になる (BE-2) |
| **D-IDA-7** | **v2 の Web 検索 (市場規模 / CAGR) を評価に取り込むか** | **取り込まない**。V-4 / V-5 の独立移送のまま置き、評価は**既に埋まっている値を優先して使う** (§6.3 の「値の出所」) | (a) v2 と同じく評価と並列に Web 検索を走らせる: 評価ジョブが検索の失敗・遅延に引きずられ、**O-4 の失敗分類が「評価の失敗」と「検索の失敗」で混ざる**。[conversation.md](conversation.md) D-CV-13 が V-4 / V-5 を独立移送のままとする判定を出しており、そちらと矛盾する。(b) 評価から市場規模・CAGR の軸を外す: composite の重み (0.25 + 0.15 = 40%) が消え、v2 の評価と比較できなくなる (§8.1 の凍結出力による A/B が成立しない) |
| **D-IDA-8** | **評価の入口の粒度** | **`POST /idea-evaluations` に `idea_ids[]` を渡す 1 本**。単体は要素 1 件 | (a) `POST /ideas/{idea_id}/evaluation` (単体) と一括の 2 本: **同じ UseCase に入口が 2 つ**になり、冪等キー・件数上限・計測の適用が入口ごとに分かれる ([conversation.md](conversation.md) D-CV-1 の却下 (b) と同型)。(b) 単体のみ: v2 の「発散セッション単位で一括評価」が N リクエストに割れ、件数上限・冪等性・失敗の集約をクライアントが持つことになる (C-16 の操作が実質的に劣化する) |
| **D-IDA-9** | **評価の進捗の配信方式** | **SSE を持たない。`GET /idea-evaluations` のポーリング**で状態を返す | (a) SSE を足す: 評価 1 件は「開始 → 完了」の 2 状態しかなく、**途中経過のイベントを生む場所が無い** (アセット抽出の 4 ターンとは違う)。`asset_extraction_events` 相当の進捗テーブルを新設することになる。(b) 会話ターンと同じ同期 SSE にする: `progress.scope` と `artifact.kind` の値域 ([conversation.md](conversation.md) §5.1) に会話と無関係な値を足すことになり、**会話の SSE 契約に評価が結合する**。さらに切断で結果が失われる (J-7 違反) |
| **D-IDA-10** | **評価ジョブの状態の置き場所** | **`idea_evaluations` に列を足す** (`status` / `heartbeat_at` / `idempotency_key` / `failure_code` / `failure_message`) | (a) `idea_evaluation_jobs` テーブルを新設: [../data-model.md](../data-model.md) **DM-16 が「非同期ジョブはドメインごとに持つ (独立テーブル or 既存テーブルの列)」**と定めており、**`knowledge_files` が既に「既存テーブルの列」の前例**である (同 §4.7)。評価は 1 アイデア 1 行 (`UNIQUE (idea_id)`) なので列で足りる。**新規テーブルは DR-9 の連動 15 箇所を発生させる**ため、足りるなら足さない。(b) 単一の `jobs` テーブル: DM-16 が却下済み (対象への FK が張れない) |
| **D-IDA-11** | **CSV の列ずれ (v2 のバグ) の扱い** | **ヘッダどおり 16 列すべてに値を書く (修正する)** | (a) v2 のずれを再現する: 「`価値提案` 列に市場規模が入る」状態を仕様として固定することになる。**下流が読んでいるのは列名**であり、列名と中身が食い違っている現状こそが壊れた状態。(b) 列を 15 に減らす: `価値提案` か `作成日` のどちらかを落とすことになり C-16 に反する |
| **D-IDA-12** | **`has_plan` フィールドを持つか** | **持たない。`stage.code == "plan"` で表す** (= IB-Q14-3 の回答) | (a) `has_plan` と `stage` を両方返す: [conversation.md](conversation.md) §2.3.2 が `stage` を **`plans` 行の存在**から導出すると確定させたため、**両者は同値**になった。同じ事実を 2 つの名前で返すと、片方だけ実装される・片方だけ更新される余地ができる。(b) `stage` を落として `has_plan` にする: [idea-boards.md](idea-boards.md) の `BoardItem.idea.stage` と [conversation.md](conversation.md) §2.3.2 の決定を覆すことになる |
| **D-IDA-13** | **タグを LLM に書かせるか** | **発散時の初期値は LLM 由来 (`diverge.Idea.Categories`)、以後は人手の全置換。由来を区別しない** | (a) 人手のみ: 発散直後のタグが必ず空になり、`keyword` がタグを対象にする決定 ([idea-boards.md](idea-boards.md) §8.1) が初期状態で空振りする。(b) `origin` 列で由来を区別: FE に 2 種を表示し分ける要件が無く、全置換に「LLM 分は残す」分岐が生まれ、`keyword` 検索が 2 系統になる |
| **D-IDA-14** | **版の対象に `tags` を含めるか** | **含める** | (a) 含めない: 復元してもタグだけ元に戻らず、「戻したのに元と違う」状態になる。(b) タグ変更では版を切らない: `snapshot` に `tags` がある以上、タグだけ変えた状態を指す版が存在しなくなり、`plan_tab_versions.source_idea_version_id` が指す内容と実体がずれる |
| **D-IDA-15** | **`PUT /ideas/{idea_id}` の更新粒度** | **部分更新 (送られたフィールドのみ)。`tags` は送られた場合のみ全置換** | (a) 全置換 (PUT の厳密な意味): FE が 1 フィールドを直すために全項目を送ることになり、**同時編集で送信していない項目が空に戻る**。(b) PATCH にする: v2・v3 の他ドメインに PATCH の前例が無く、[README.md](README.md) D-API-11 は PUT を更新の標準としている |

---

## 8. 他文書への是正要求 / 受信欄

### 8.1 本書が起票するもの (状態列つき)

**状態は「未対応 / 実施済み / 対応不要」+ 日付**。統合作業 (CV-D の単位) で消化する。
[requirements-conversation.md](../../../aidlc-docs/inception/productionization/requirements-conversation.md) §5 に
同じ内容の起票がある場合は「既存 ID」列で対応付ける (二重管理しない)。

| ID | 起票先 | 内容 | 理由 (やらないと何が壊れるか) | 既存 ID | 状態 |
|---|---|---|---|---|---|
| **R-IDA-1** | [idea-boards.md](idea-boards.md) §7 / §2 / §2.1 / §2.4 / §8.1 | ①**§7 を「参照系は `ideas.md` へ移設済み」に書き換える** (空節にしない) ②**§7 の制約 (作成・本文更新・削除を追加しない) を解除**した旨を書く ③**§2 のエンドポイント表から `/ideas` 系 4 行 (一覧・取得・スター・CSV) を削除**する ④**§2.4 (CSV の応答仕様) を本書 §2.6 への参照に置き換える** ⑤**§2.1 の `evaluation.rank` を `evaluation.grade` に改める** (§2.1) ⑥**§8.1 の「更新経路」行を本書 §5 への参照に差し替える** (BE-10 のクローズ) ⑦**IB-Q14-2 / IB-Q14-3 を回答済みに更新**し、参照先を本書 §2.1 にする | 移設しないと `ideas` テーブルの API SSOT が 2 ファイルに割れたまま残り、AC-CV-3.3 が未達になる。`rank` / `grade` の不一致は FE の型が 2 名前を持つ形で実装リポに出る | R-CV-8 | **実施済み** (2026-08-02。idea-boards.md から `/ideas` 系 4 行を削除し 22 → **18 本**へ。§7 を「[ideas.md](ideas.md) へ移設済み」に書き換え、§2.4 の CSV も移設、§8.1 の BE-10 をクローズ) |
| **R-IDA-2** | [../data-model.md](../data-model.md) §4.6 | **`idea_evaluations` に非同期ジョブの列を追加する** — `status` (`queued`\|`running`\|`succeeded`\|`failed`) / `heartbeat_at` / `idempotency_key` / `failure_code` / `failure_message`、および `(status, heartbeat_at) WHERE status IN ('queued','running')` のインデックスと**部分 UNIQUE `(idea_id, idempotency_key) WHERE status IN ('queued','running')`**。`knowledge_files` (同 §4.7) と同型 | 列が無いと `POST /idea-evaluations` の 202 応答と J-3 の取り残し回収が実装できない。**列の追加なのでテーブル件数 (DR-9) には影響しない** | — | **実施済み (2026-08-02 に完了)**。当初は `job_status` / `job_started_at` / `job_finished_at` / `failure_code` の 4 列のみで、**要求された `heartbeat_at` / `idempotency_key` / `failure_message` と索引 2 本が欠落**していた (レビュー重大 2 — J-3 の取り残し回収と J-5 の冪等キーが実装不能だった)。同日中に是正し、**列名を DM-16 の共通規約 (`status` / `failure_code` / `failure_message` / `heartbeat_at` / `idempotency_key`) に揃えた**。索引は `(status, heartbeat_at) WHERE status IN ('queued','running')` と部分 UNIQUE `(idea_id, idempotency_key) WHERE status IN ('queued','running')` |
| **R-IDA-3** | [conversation.md](conversation.md) §4.1 / §7 | **`prompts/conversation/orchestrator.md` に「ユーザーが持ち込んだアイデアを、発散せずに本文だけ補完して提示する」節が要る**ことを明記する。現状の同書は `generate_ideas` の `seed_idea` (= 持ち込みアイデアを種にして**発散する**) しか書いておらず、**v2 の `POST /ideas/generate/my-idea/draft` (補完だけ・保存しない) の受け先が明文化されていない** | 明文化しないと、v3 で「PDF を投げると自分のアイデアの下書きが埋まる」操作が**どこにも実装されない**まま C-16 の対応表だけが埋まる (本書 §3.1 の #7 が宙に浮く) | — | **実施済み** (2026-08-02。conversation.md §4.1 に「持ち込みアイデアには 2 つの経路がある」節を追加し、補完だけを行うモード (ツールを呼ばず `message_delta` で返す・保存しない) を明文化。補完専用 tool を足さない理由も記載) |
| **R-IDA-4** | [../data-model.md](../data-model.md) §4.6 / §6.4 | **v2 `ideas.concept` → v3 `ideas.summary` の写像を記録する** (`hassan-v2-backend/db/schema.sql:155`)。あわせて **`ideas.score` の型を `numeric(3,1)` (0.0〜10.0) と明記**し、v2 の 0〜40 からの写像規則 (本書 §3.3) を §6.4 に載せる | 列名の写像が無いと移行時にどちらへ入れるかが決まらない (= [idea-boards.md](idea-boards.md) の **IB-Q14-4**)。`score` の型が未定のままだと `integer` で実装され、0.0〜10.0 の小数が丸められる | — | **実施済み** (2026-08-02。data-model.md §6.4 に「確定済みの列写像」行を新設し、`concept`→`summary` / `score` の `numeric(3,1)` / `thumbnail_url`→`thumbnail_object_key` を記載) |
| **R-IDA-5** | [plans.md](plans.md) §9 | **企画書のお気に入りテーブルが `GET /ideas?plan_favorite=` の判定元になる**ことを同書に反映する (v2 の `is_only_business_plan_favorite` の受け先 — 本書 §3.2)。**あわせて `plans` の `UNIQUE (idea_id)` に対する本書の意見を受け取る**: **維持を推奨する** — `Idea.stage` (本書 §2.1 / [conversation.md](conversation.md) §2.3.2) が「`plans` 行が存在すれば `plan`」で導出されており、1 アイデアに複数の企画書があると `stage` が「どの企画書のことか」を表せない (AC-CV-1.4) | 判定元が無いと `plan_favorite` が実装できず、v2 の絞り込み操作が落ちる。UNIQUE を外す場合は `Idea.stage` の導出規則を作り直す必要がある | R-CV-4 / R-CV-7 | **実施済み** (2026-08-02。plans.md §9 が `plan_favorites` の読み手③として `GET /ideas` の絞り込みとフィールドを明記済みであることを確認。相互リンクも張った) |
| **R-IDA-6** | [README.md](README.md) §0 / §2.5 / §3 + `scripts/check-endpoint-mapping.sh` | ①§0 の「会話型アイデア創出は対象外」宣言の解除に**アイデアドメインを含める** ②§3 の総覧に**アイデアドメイン (本書 §1.1 の表の行数 / LLM 1 / SSE 0 / 403 は §1.3 の表から実測)** を追加する ③**§2.5 と §3 の「403 は 6 ドメインで合計 11 本」を本書の追加分を含む数に更新する** ④**§3.4 の [idea-boards.md](idea-boards.md) 明細から `/ideas` 系 4 行を削除**し、同ドメインの本数を減らす ⑤検査④の対象集合に `ideas` を加える | **件数を人手で数えると必ずずれる** (DR-9)。特に④は「アイデアドメインを足す」だけを見ていると取り残す — **移設元の本数も同時に減る**ため、合計が二重計上になる | R-CV-9 | **実施済み** (2026-08-02。README §3 の総覧にアイデアドメイン 13 本 (403 は 5 本) を追加し §3.8 を新設。**移設元の idea-boards も 22 → 18 に減らして二重計上を避けた**。403 合計は 11 → **16 本** (R-1 3 + R-2 13)。検査④の対象集合も拡張) |
| **R-IDA-7** | [../operations.md](../operations.md) §6 | **CSV の列ずれ修正 (本書 §2.6 / D-IDA-11) をリリースノートの告知対象に加える** — 切替後、`価値提案` 列と `作成日` 列の中身が変わる | 告知しないと、v2 の CSV を取り込んでいる利用者の集計が切替日に無言で変わる ([idea-boards.md](idea-boards.md) IB-Q10 と同じ性質) | — | **実施済み** (2026-08-02。operations.md §6.3.1 の告知表に #5 として追加) |
| **R-IDA-8** | [plans.md](plans.md) §5 | **版と復元の共通規則 (本書 §4) を `plan_tab_versions` にも同じ形で適用する**ことを確認し、差分がある場合は本書 §4 に是正要求を返す ([requirements-conversation.md](../../../aidlc-docs/inception/productionization/requirements-conversation.md) §6.1 の 4 = 「共通規則として先に決める」の受け先が本書 §4 である) | 並列起草のため、両書が別々の復元規則 (削除の可否・版番号の増え方・採番の閉じ込め先) を書く余地がある。ずれると `entity` の共通関数が作れない | — | **実施済み** (2026-08-02。plans.md §5 の版・復元が本書 §4 と同じ規則 (復元は新版を作る・削除を持たない・採番は 1 SQL) であることを確認。差分なし) |
| **R-IDA-9** | [../llm-migration.md](../llm-migration.md) §9.2 / §6.2 の 4 | **LM-R6 (評価軸の統合) の調査結果を反映する** — 本書 §6.2 の対照表が結論。**v2 の 4 段基準表を取り込む / 市場規模・CAGR のスコアは Go が閾値表で計算する / composite は 5 軸の重み付け平均 / OGP の `image` とモデル選択と言語切替は落とす**の 4 点を同書に記載し、LM-R6 を解決済みにする | 「調査の実施主体は会話型アイデア創出の API 設計」と名指しされており、未反映だと LM-R6 が残課題のまま残る | R-CV-14 (前半) | **実施済み** (2026-08-02。llm-migration.md §9.2 の LM-R6 をクローズし、統合方針 4 点と §6.2 の 4 への帰結を記載) |
| **R-IDA-10** | [../../analysis/v2-feature-inventory.md](../../analysis/v2-feature-inventory.md) §2.5 | **「v3 の対応」列を本書へのリンクに更新する** (現在は「idea-boards.md §7、生成系は Task-3p 未着手」)。**#5〜#8 の「統合」の受け先を本書 §3.1 の行番号で特定できる形にする** | C-16 の完了条件は §5 の「対象外 (要確認)」が空になることであり、対応先が「未着手」のままだと確認できない | R-CV-10 | **実施済み** (2026-08-02。v2-feature-inventory.md §2.5 の見出しを本書へのリンクに更新し、`idea-hassans` 5 本の対応先も conversation.md へ変更) |
| **R-IDA-11** | [../frontend.md](../frontend.md) | **アイデア画面が読む型が本書 §2.1 の `Idea` で確定した**ことを記載する (`tags` / `market_size` / `cagr` / `stage` / `has_knowledge` / `is_owner` / `latest_version` / `evaluation.grade`)。**`evaluation.rank` を使う記述があれば `grade` に直す** | FE が [idea-boards.md](idea-boards.md) §2.1 の旧 `Idea` (`tag` 単数 / `rank`) を正として実装すると、orval の生成型と手書きの期待が食い違う (FE-2) | — | **実施済み** (2026-08-02。frontend.md §11.1 の `/ideas` 行を本書 §1 の 13 本に更新し、`Idea` 型の SSOT と旧型からの差分 (`tag`→`tags` / `rank`→`grade`) を注記) |

**新規テーブルを 1 件も要求していない** — 是正要求 R-IDA-2 / R-IDA-4 はいずれも**列の追加**であり、
[../data-model.md](../data-model.md) のテーブル件数 (DR-9 / `make check-table-counts`) には影響しない。

### 8.2 本書が受け取った是正要求 / 委譲 (受信欄。DR-8 の受信側)

| 起票元 | ID | 内容 | 本書での回答 | 状態 |
|---|---|---|---|---|
| [idea-boards.md](idea-boards.md) §8.1 | `tags` の書き込み側 (BE-10) | 読む側だけあって書く側が無い | **§5** (発散時の初期値 + `PUT` / `POST` の全置換) | **回答済み** (2026-08-01) |
| [idea-boards.md](idea-boards.md) §7 | 参照系 3 本の移設 | 生成系の確定後に統合し直す | **§1.2** (+ CSV も移す) / 起票は §8.1 の R-IDA-1 | **回答済み** (2026-08-01) |
| [idea-boards.md](idea-boards.md) IB-Q14-2 | `market_size` / `cagr` を `Idea` に載せるか | | **§2.1** (載せる。文字列のまま返し、数値はサーバ計算のスコアで渡す) | **回答済み** (2026-08-01) |
| [idea-boards.md](idea-boards.md) IB-Q14-3 | `has_plan` / `has_knowledge` を返すか | | **§2.1 / §7 の D-IDA-12** (`has_plan` は持たず `stage` で表す / `has_knowledge` は持つ) | **回答済み** (2026-08-01) |
| [idea-boards.md](idea-boards.md) IB-Q14-4 | v2 `concept` → v3 `summary` の写像 | | **§3.3** + 起票 R-IDA-4 ([../data-model.md](../data-model.md) が確定先) | **委譲** (2026-08-01) |
| [conversation.md](conversation.md) §4.2 / D-CV-15 | アイデア再評価の REST のパス・入出力 | | **§1.1 / §6.4** (`POST /idea-evaluations` の非同期ジョブ) | **回答済み** (2026-08-01) |
| [conversation.md](conversation.md) §10 の **CV-R8** | **LM-R6** (評価軸の統合) の調査 | 「`ideas.md` (CV-B) が v2 と PoC を突き合わせて決める」 | **§6.1 / §6.2 / §6.3** | **回答済み** (2026-08-01) |
| [conversation.md](conversation.md) §2.3.2 / R-CVA-9 | **IB-Q7** の結論 (アイデアの `stage`) | 会話の `stage` を配らずアイデア自身の事実から導く | **§2.1** (`stage` は 2 値。SSOT は同書 §2.3.2) | **受領** (2026-08-01) |
| [conversation.md](conversation.md) §7 の **D-CV-13** | **LM-R8** の判定 (V-4 / V-5 を吸収しない) | | **§6.2 / §7 の D-IDA-7** (評価に Web 検索を取り込まない前提で設計した) | **受領** (2026-08-01) |
| [requirements-conversation.md](../../../aidlc-docs/inception/productionization/requirements-conversation.md) §6.1 の 4 | 版と復元の共通規則 | 「`conversation.md` に置かず共通規則として先に決める」 | **§4** (`plan_tab_versions` にも同じ形で適用する。確認は R-IDA-8) | **回答済み** (2026-08-01) |
| [requirements-conversation.md](../../../aidlc-docs/inception/productionization/requirements-conversation.md) AC-CV-1.4 | `plans` の `UNIQUE (idea_id)` への意見 | 決定主体は `plans.md` | **R-IDA-5** (維持を推奨。理由は `Idea.stage` の導出) | **回答済み (意見)** (2026-08-01) |

---

## 9. 残課題 / 要確認

**仮定を添えて書く。違えば §7 の判断が変わる。**

| ID | 内容 | 仮定 (この前提で設計した) | 確定先 |
|---|---|---|---|
| **IDA-R1** | **評価のモデル選択 (`fast` / `think`) を落とすことが C-16 の例外承認を要するか** (§3.2)。v2 は `POST /ideas/evaluate?model=` でユーザーがモデルを選べる (`hassan-v2-backend/controller/idea.go:508` の swag / `usecase/idea/evaluate_ideas.go:184` の `buildFallbackModelsForEvaluation`) | **落として設計した** — [../llm-migration.md](../llm-migration.md) §5.2 が「用途別許可リストを別定義で作らない」と決めており、API パラメータでモデルを切り替えるのは同決定と衝突する。**承認が得られない場合は、`config` のプロファイルに `fast` / `think` の 2 行を持たせ、API は `profile` 列挙値で受ける形にする** (モデル名は受けない) | **ユーザー承認** (C-16 の例外) |
| **IDA-R2** | **評価の日英切替を落とすこと** (§3.2)。v2 は `prompt/idea/evaluation.en.tmpl` を持つ | **落として設計した** — [auth-accounts.md](auth-accounts.md) の **AA-Q4** が「v3 は日本語のみ」を全体の仮定として置いている。**本書だけで判断していない**。AA-Q4 が覆ると、`prompts/idea/evaluate.md` が言語別になり [../llm-migration.md](../llm-migration.md) §5.2 の `languages[]` が効いてくる | **AA-Q4 と同時** |
| **IDA-R3** | **ボード上で他人のアイデアにスターを付けたいか** (§1.3 で 403 にした)。`ideas.star_rating` は**アイデア単位のグローバル値**であり (`hassan-v2-backend/db/schema.sql:172`)、アカウント別ではない。プロトタイプのボード詳細はアイテム行にスター UI を出す (`renderStarRater` — [idea-boards.md](idea-boards.md) §1.3) | **所有者のみに限定して設計した**。共有ボードで他人が星を上書きできると、所有者の評価が黙って変わる。**「メンバーそれぞれの星」が要件なら `ideas.star_rating` ではなく (アイデア, アカウント) の別テーブルが要る** = 新規テーブル (DR-9 の連動あり) | 要件確認 → [idea-boards.md](idea-boards.md) IB-Q 系と同時 |
| **IDA-R4** | **v2 の `ideas` に複数行の評価履歴があるか** — v2 は評価を `ideas` の列に上書きしており履歴を持たない。v3 の `idea_evaluations` も `UNIQUE (idea_id)` で 1 行 | **履歴を持たない前提で設計した** (再評価は上書き)。評価の推移を見たい要件が出た場合、`idea_evaluations` を版テーブル化するか `idea_versions` に評価を含めるかの判断が要る (**後者は §4.2 で明示的に却下している**) | 要件確認 |
| **IDA-R5** | **`GET /ideas` の `keyword` がタグを対象にするときのインデックス** | `idea_tags` の GIN trgm ([../data-model.md](../data-model.md) §4.6) で足りると仮定した。`ideas.title` / `summary` との OR 検索が実データ量でどう出るかは未計測 | [../data-model.md](../data-model.md) §3.5 / 実装リポ |
| **IDA-R6** | **評価の `MaxTokens` の初期値** — PoC は 4096 → 8192 に引き上げた経緯があり (`claude_managed_agents/cmd/devui/idea_evaluate.go:39`〜`:44`)、v3 は **v2 の 4 段基準表を取り込んで rationale が長くなる**ため同じ値で足りない可能性がある | **`config` の LLM プロファイル (`max_tokens`) が SSOT** とし、本書に数値を書かない前提で設計した。**F-1 (切り詰め) のメトリクスが立ち上げ直後に出ることを想定しておく** | 実装リポ ([../llm-migration.md](../llm-migration.md) §5.2 のプロファイル) |
| **IDA-R7** | **統合後の評価の品質が v2 / PoC より劣化しないか** — 主軸が 4 → 5 に増え、市場規模・CAGR のスコア計算が Go に移る | [../llm-migration.md](../llm-migration.md) §8.1 の凍結出力による A/B (統合元ごとに 1 セット) で検証する前提で設計した。**v2 (V-2) と PoC (P-5) の 2 セットが要る** | [../llm-migration.md](../llm-migration.md) §8 |
| **IDA-R8** | **`plan_favorite` 絞り込みの実装時期** — 判定元テーブルが企画書ドメインの追加待ち (§3.2 / R-IDA-5) | **同じ第 1 リリースに入る**前提で設計した (CV-D1 = v2 企画書 18 本すべてが第 1 リリース)。テーブルが遅れると本パラメータだけ 400 を返す状態になり、C-16 が部分的に未達になる | `docs/design/API/plans.md` |

---

## 10. 実装リポへの引き渡し

### 10.1 依存順序

```
data-model.md の ideas / idea_tags / idea_versions / idea_evaluations
   (+ R-IDA-2 の列追加・R-IDA-4 の型確定)
   ↓
entity/idea  (snapshot と source_hash を作る 1 関数 / 市場規模・CAGR の閾値表 /
              composite の重み式 / grade のバンド / stage の導出)   ← UT 必須
   ↓
repository/idea  (可視性クエリ (is_owner つき) / 版の 1 SQL 採番 / タグの全置換 /
                  評価ジョブの status 遷移と heartbeat)
   ↓
usecase/idea  (所有者スコープの確定 / 403 と 404 の分岐 / 版とタグのトランザクション /
               評価ジョブの冪等キーと件数上限)
   ↓
service/idea_evaluation  (LLM 呼び出しループ・再試行・stop_reason の検出)
   ↓
gateway/anthropic (CallMeta = usage 4 カウンタ + stop_reason)  ※会話ドメインと共通
   ↓
controller  (CSV のライタ / CodedError 変換 1 箇所)
```

### 10.2 並列可能

- **`entity/idea` の純粋関数群** (閾値表・重み式・grade バンド・source_hash) は他と並列に着手できる。
  **UT の期待値は §6.3 の表と v2 の閾値表がそのまま使える**
- **`prompts/idea/evaluate.md` の起こし**は Go の実装と並列。入力は
  PoC の `claude_managed_agents/prompts/idea_evaluate_system.md` + v2 の 4 段基準表
  (`hassan-v2-backend/prompt/idea/evaluation.tmpl`)
- **CSV のライタ**は独立 (§2.6 の 16 行の表が期待値)
- **OpenAPI の `Idea` / `IdeaVersion` / `IdeaEvaluation` スキーマ定義**は FE のブロック解除が最速になる

### 10.3 参照すべき既存実装

| 目的 | 参照先 | 扱い |
|---|---|---|
| 市場規模 / CAGR のスコア閾値表 | `hassan-v2-backend/util/score_calculator.go:18`〜`:129` | **移植する**。ただし `< 400` の境界を書き直す (§6.3) |
| 評価の 4 段基準表 (新規性・ミッション整合) | `hassan-v2-backend/prompt/idea/evaluation.tmpl` | **プロンプトに取り込む** |
| リッチ評価の出力スキーマと書き方の指示 | `claude_managed_agents/prompts/idea_evaluate_system.md` | **土台にする** (22 フィールド。§6.3 で `source` の形だけ変更) |
| `source_hash` の計算対象 | `claude_managed_agents/cmd/devui/idea_evaluate.go:139`〜`:161` | **思想を移す** (「プロンプトが実際に詰めるフィールドと一致させる」) |
| stale 判定の分岐 | `claude_managed_agents/cmd/devui/idea_evaluations.go:140`〜`:152` の `decideEvaluationLookup` | **純粋関数として移す** (§2.5 の表) |
| `grade` のバンド | `claude_managed_agents/cmd/devui/conversation_tools_generate.go:615`〜`:626` | **移植する** (発散側と同じ関数を使う) |
| CSV の出力 (BOM / CRLF / ヘッダ) | `hassan-v2-backend/controller/idea.go:481`〜`:486` / `hassan-v2-backend/usecase/idea/get_ideas_csv.go` | **ヘッダとエンコーディングは手本にする**。**データ行の 15 値は反面教師** (§2.6) |
| 一覧 + ページネーション + 可視性判定 | `hassan-v2-backend/usecase/idea/list_ideas.go` | 構造の参考。**`account_id` クエリの受け取りは持ち込まない** (D-API-8) |
| `CodedError` の集約ハンドラ | `hassan-v2-backend/controller/idea_board.go` | 変換 1 箇所の手本 |
| **反面教師** (Web 検索とのマージを文字列の接尾辞で表す) | `hassan-v2-backend/usecase/idea/evaluate_ideas.go` の `mergeWebSearchWithEvaluationEstimates` / `stripApproximatePrefix` / `stripEstimatedSuffixIfHasOGP` | **同じ構造にしない**。区別は `source` の構造で表す (§6.2) |
