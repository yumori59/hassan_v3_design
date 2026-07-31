# API: ナレッジ (RAG チャット + ファイル管理)

> 共通規約 (認証・レスポンス形・エラー・ページネーション・ステータスコード) の SSOT: [README.md](README.md)
> 本ファイルが回答する本番観点: **A-3 (部分), A-4, A-5, A-6, O-2, O-4, O-5** / 受入基準: **AC-1.1, AC-1.3, AC-1.4**

## 1. 対応する画面と参照する既存実装

| 区分 | 所在 |
|---|---|
| プロトタイプ | `knowledge` ビュー — `../../prototype/hassan_agent_prototype_v2.html` の HTML `:7526-7587` / JS `:13851-14769` (2026-07-30 更新版の実測) |
| プロトタイプのモックデータ | `KB_DOCS` (`:13851`、8 件) / `KB_THREADS` (`:13892`、4 件) / `kbState` (`:13926`) |
| 新規チャットのフロー | モード選択 (アイデア引継ぎ / 通常) → アイデア選択 → 作成。**1 アイデア = 1 スレッド**の強制は `finalizeNewChat` (`:14658-14670`) |
| v2 の既存実装 | **ナレッジに相当する機能・テーブルは v2 に存在しない** (grep 3 軸 + `hassan-v2-backend/db/schema.sql` の全 `CREATE TABLE` 走査で不在を確認) |
| v2 の**類似**実装 (参照する手本) | リサーチチャット: `hassan-v2-backend/controller/research.go`、`hassan-v2-backend/db/queries/research.sql`、テーブル `research_titles` / `research_conversation_histories` (`hassan-v2-backend/db/schema.sql:520-539`) |

### 1.1 v2 の「リサーチチャット」との関係 (誤解を避けるための明示)

v2 には**スレッド型のチャット機能が既にある**が、**アップロードした資料に対する RAG ではない**。

| 観点 | v2 のリサーチチャット | v3 のナレッジ |
|---|---|---|
| スレッドの表現 | `research_titles` (`conversation_id` / `account_id` / `title` / `conversation_type`) | 同型を踏襲する (§3 D-KN-1) |
| メッセージの表現 | `research_conversation_histories` (`conversation_id` + `message_id` の複合主キー、`query` / `answer` / `ogp_info`) — **1 行に質問と回答の両方**を持つ | **質問と回答を別行**にする (§3 D-KN-2) |
| 検索対象 | 外部 Web (`ogp_info` を保持していることから) | **ユーザーがアップロードした資料** |
| ストリーミング | SSE (`hassan-v2-backend/controller/research.go:207` が `SetupSSEHeaders` を呼ぶ) | SSE (同方式を踏襲) |
| ファイル管理 | 無い | **新規** |

**したがってナレッジは新規ドメインだが、スレッド + SSE の骨格は v2 に手本がある**。

### 1.2 プロトタイプの概念と v3 の対応

| プロトタイプの概念 | v3 の対応 | 備考 |
|---|---|---|
| スレッド (`KB_THREADS[].id` / `title` / `groupLabel`) | `knowledge_threads` | `groupLabel` (今日 / 昨日 / 3日前) は `updated_at` からの**表示上の派生値** — サーバは返さない (§3 D-KN-5) |
| アイデア参照 (`ideaRef`) | `idea_id` (null = 通常モード) | **1 アイデア = 1 スレッド** (§3 D-KN-3) |
| スレッドの参照ファイル (`files: [KB_DOC id]`) | `knowledge_thread_files` (中間テーブル) | 引継ぎ時にアイデア関連資料を自動紐付け (`:14674`) |
| メッセージ (`msgs[].role` = `ai`\|`user`, `text`, `subText`, `cites`) | `knowledge_messages` (`role` / `body` / `citations`) | `text` / `subText` は**プロトタイプの HTML 断片**であり、そのままの形は採らない (§3 D-KN-6) |
| 引用 (`cites: [KB_DOC]`) | `citations: [{file_id, title, excerpt}]` | 所有者スコープ内のファイルのみ (§4)。**更新版プロトタイプの引用表示は id/title/date のみで excerpt を出していない** (`renderKbMsg` `:14462-14471`) — API は excerpt を返す設計を維持 (表示は FE の裁量) |
| ファイル (`KB_DOCS[].type` / `title` / `ideaNum` / `date` / `size` / `author` / `excerpt` / `tags`) | `knowledge_files` | `type` の値域: `interview` / `report` / `internal` / `external` (`KB_TYPE_LABEL` `:13886`) |
| ファイルのアップロード | `POST /knowledge-files` | プロトタイプは動的追加 (`:14375-14385` の `allowedRe` によるフィルタ)。許可拡張子は §3.1。**更新版ではアップロードはアクティブスレッドの文脈でのみ発生し** (`processKbFilesForActiveThread` `:14369`)、ファイル一覧パネルも常にスレッド範囲 (`th.files`) に限定される (`renderKbFilePanel` `:14007-14012`) — 全ファイル横断の一覧 UI は無い (KN-Q10) |
| 候補質問チップ | サーバから返さない | プロトタイプは固定文字列。生成する要件が未確認 (§6 KN-Q4) |

---

## 2. エンドポイント一覧

すべて認証必須 (`X-Token`)・**すべて個人スコープ**・すべて増分 1。
共通の 400 / 401 / 500 は [README.md](README.md) §2.5 に従い、本表では**固有のコードのみ**挙げる。

| メソッド | パス | 概要 | 主なリクエスト / レスポンス項目 (暫定) | 固有ステータス | LLM | SSE |
|---|---|---|---|---|---|---|
| GET | `/knowledge-threads` | スレッド一覧 | Q: `keyword` / `limit` / `offset` / `sort` (`updated_at` 既定) — R: `{items:[Thread], total_count}` | 200 | — | — |
| POST | `/knowledge-threads` | スレッド作成 | B: `mode` (`inherit`\|`blank`, 必須) / `idea_id` (`inherit` 時必須) / `title` (任意) — R: `Thread` | **201** / **409** (`idea_id` に既存スレッドあり。本文に `existing_thread_id`) / **404** (`idea_id` が他人 or 不存在) / **400** (`mode=inherit` で `idea_id` 欠落) | — | — |
| GET | `/knowledge-threads/{thread_id}` | スレッド取得 | R: `Thread` (+ `file_count` / `message_count`) | 200 / 404 | — | — |
| PUT | `/knowledge-threads/{thread_id}` | タイトル更新 | B: `title` (必須) — R: `Thread` | 200 / 404 | — | — |
| DELETE | `/knowledge-threads/{thread_id}` | スレッド削除 | — (**ファイルは削除しない** — §3 D-KN-4) | **204** / 404 | — | — |
| GET | `/knowledge-threads/{thread_id}/messages` | メッセージ履歴 | Q: `limit` / `offset` (**古い順**) — R: `{items:[Message], total_count}` | 200 / 404 | — | — |
| POST | `/knowledge-threads/{thread_id}/messages` | 質問送信 | B: `body` (必須) — R: `text/event-stream` (確定した回答は SSE 最終イベントと `GET .../messages` の双方から取得できる) | **ストリーム開始前**: 200 (開始) / 404 (スレッドが他人 or 不存在) / 400 (`body` 空) / **502** (Agent への接続自体が失敗)。**ストリーム開始後の LLM 失敗は SSE の `error` イベント**で表現し接続を正常終了させる ([README.md](README.md) D-API-12 / [../architecture.md](../architecture.md) §3) | **✓** | **✓** |
| GET | `/knowledge-threads/{thread_id}/files` | 参照ファイル一覧 | R: `{items:[File]}` | 200 / 404 | — | — |
| PUT | `/knowledge-threads/{thread_id}/files` | 参照ファイルの紐付け置換 | B: `{file_ids:[...]}` — R: `{items:[File]}` | 200 / 404 (スレッドまたは `file_ids` のいずれかが他人 or 不存在) | — | — |
| GET | `/knowledge-files` | ファイル一覧 | Q: `type` / `idea_id` / `keyword` / `limit` / `offset` / `sort` (`created_at`\|`title`\|`byte_size`。**更新版プロトタイプの並び替えは `added`\|`name`\|`type` — `:14059-14063`。`type` 順の採否は KN-Q8**) — R: `{items:[File], total_count}` | 200 | — | — |
| POST | `/knowledge-files` | アップロード (**受理後に非同期でテキスト抽出 + 埋め込み生成**) | `multipart/form-data`: `file` (必須) / `type` / `idea_id` / `tags` — R: `File` (`status:"processing"`) | **201** / **400** (拡張子・サイズ違反) | **✓** (埋め込み生成。O-2 の計測対象) | — |
| GET | `/knowledge-files/{file_id}` | メタ取得 (処理状態のポーリング先) | R: `File` (+ `status` / `updated_at` / `failure`)。**状態機械と `failure.code` は [README.md](README.md) §1.3 が SSOT** | 200 / 404 | — | — |
| GET | `/knowledge-files/{file_id}/download` | 原本ダウンロード | R: `{download_url, expires_at}` (**非公開バケットの署名付き URL。バイト列を返さない** — [README.md](README.md) D-API-14') | 200 / 404 | — | — |
| DELETE | `/knowledge-files/{file_id}` | 削除 | — | **204** / 404 | — | — |
| POST | `/knowledge-files/bulk-delete` | 一括削除 | B: `{file_ids:[...]}` — R: `{deleted_count}` | 200 / **404** (1 件でも他人 or 不存在なら**全件実行しない**) | — | — |

Q = クエリパラメータ / B = リクエストボディ / R = レスポンス。

### 2.1 `POST /knowledge-threads` の 409 レスポンス例

```json
{
  "code": "KB-E-00003",
  "message": "このアイデアには既にナレッジスレッドがあります",
  "request_id": "01J9Z8Q0R7T3V5X7Y9A1B3C5D7",
  "existing_thread_id": "kt-01J9Z8QP0000000000000000"
}
```

FE はこれを受けて既存スレッドへ遷移する (プロトタイプの「既存スレッドを開きました」に相当 — `:14668`)。

### 2.2 `File` オブジェクト (暫定)

```json
{
  "id": "kf-01J9Z8QP0000000000000000",
  "type": "interview",
  "title": "山田剛 (ENEOS) ヒアリング議事録",
  "file_name": "interview_eneos_20260719.pdf",
  "byte_size": 250880,
  "content_type": "application/pdf",
  "idea_id": 1,
  "tags": ["ヒアリング", "水素インフラ", "ペイン"],
  "excerpt": "水素配管の腐食は「事後対応」ではなく「予兆」で把握したい。",
  "status": "ready",
  "created_by": { "account_id": "0f9c...", "name": "内保 徹平" },
  "created_at": "2026-07-19T02:00:00Z"
}
```

`status` の値域: `processing` (テキスト抽出・埋め込み生成中) / `ready` / `failed`。
`failed` のとき `failure.code` で原因を区別する (O-4)。**取り残された `processing` は
`updated_at` の閾値超過で `failed` (`failure.code = stale_aborted`) に落ちる**
([README.md](README.md) §1.3 J-3) — デプロイで処理が死んだファイルが永久に「処理中」で残らない。

**再実行の経路** ([README.md](README.md) §1.3 J-4): **`failed` のファイルは同じファイルを
`POST /knowledge-files` に再アップロードする**。冪等キー (J-5) により
`processing` 中の重複は既存を返し、`failed` からの再送は新しい処理として走る。
**専用の再実行エンドポイントは設けない**:

- **却下 (a) `POST /knowledge-files/{file_id}/reprocess` を作る**: LLM を呼ぶ経路が
  1 本増えて O-2 の計測対象の索引 ([README.md](README.md) §3 の LLM 列) が広がる。
  失敗の原因の多くはファイル自体の問題 (破損・パスワード保護) であり、
  **同じバイト列で再試行しても成功しない**ため、再アップロードを促す方が期待どおりに動く
- **却下 (b) サーバが自動で再試行する**: J-4 のとおり LLM 呼び出しは課金を伴う

---

## 3. 設計判断

| # | 論点 | 採用案 | 却下案と理由 |
|---|---|---|---|
| D-KN-1 | スレッドの表現 | **v2 の `research_titles` と同型** (`id` / `account_id` / `title` / `created_at` / `updated_at`) に `idea_id` を加える | (a) 会話型アイデア創出の `conversation_sessions` ([../../analysis/poc-inventory.md](../../analysis/poc-inventory.md) §4) を共用する: 台帳 (ledger) やツール実行状態を持つ構造で、RAG チャットには不要なフィールドが大半を占める。SSOT が曖昧になる |
| D-KN-2 | メッセージの表現 | **1 行 = 1 メッセージ** (`role` = `user`\|`assistant`)。引用は `citations` として回答行に持たせる | (a) v2 の `research_conversation_histories` 方式 (1 行に `query` + `answer` — `hassan-v2-backend/db/schema.sql:529-539`): SSE で回答を逐次書き出す設計と噛み合わず (回答が未確定の間 `answer` を空で持つ)、失敗した回答や中断を表現できない。**これは v2 規約からの意図的な逸脱**として記録する |
| D-KN-3 | 1 アイデア = 1 スレッドの強制 | **DB の一意制約 `UNIQUE(account_id, idea_id)`** を正とし、API は **409 + `existing_thread_id`** を返す | (a) 冪等に既存を返す (200): 「作成した」と「既に在った」を FE が区別できず、プロトタイプの遷移 + トースト挙動 (`:14668`) を実装できない。(b) FE が事前に一覧を GET して判定 (プロトタイプ方式 — `existingThreadByIdea` `:14602`): 同時操作で二重作成が起きる。**制約が DB に無い限り「1 アイデア = 1 スレッド」は保証されない** |
| D-KN-4 | スレッド削除とファイル | **スレッドを削除してもファイルは残す** | (a) 紐付いたファイルも削除: ファイルは複数スレッドから参照され得る (プロトタイプでも `kd5` が `kt1` と `kt3` の両方に現れる — `:13894`, `:13915`)。削除すると他スレッドの引用が壊れる |
| D-KN-5 | 日付グルーピング | **サーバは `updated_at` を返すだけ**。「今日 / 昨日 / 3日前」の見出しは FE が算出する | (a) サーバが `group_label` を返す (プロトタイプの `groupLabel` — `:13893`): タイムゾーンをサーバ側で固定することになり、`Asia/Tokyo` 以外の利用者で表示がずれる。表示ロジックを API 契約に埋めない |
| D-KN-6 | 回答本文の形式 | **Markdown 文字列**で返す。HTML はサーバから返さない | (a) プロトタイプ準拠の HTML 断片 (`text` / `subText` に `<strong>` `<ul>` を含む — `:13896-13901`): LLM 出力をそのまま HTML として描画すると XSS 経路になり、サニタイズの責務が FE の各表示箇所に散る。(b) 構造化 JSON (見出し・箇条書きを配列で持つ): LLM に厳密な JSON を出力させると `max_tokens` 切り詰めで壊れる (BE-6) |
| D-KN-7 | 質問送信のレスポンス | **SSE** (`POST` に対する `text/event-stream`) | (a) 202 + 別 GET のポーリング: 回答のトークン逐次表示 (プロトタイプの体験) ができない。(b) 202 + 別 SSE エンドポイント (アセット抽出の方式 — [assets.md](assets.md) §2.1): 抽出は分単位のジョブで再接続に価値があるが、チャットは失敗時に**再質問すればよい**ため、ジョブ ID を持つ複雑さに見合わない |
| D-KN-8 | RAG の検索スコープ | **`account_id` を必須フィルタ**として検索層に渡す。スレッドに `file_ids` が紐付いている場合は**その集合にさらに限定**し、空の場合は「自分の全ファイル」を対象にする | (a) スレッドの紐付けを無視して常に全ファイル: プロトタイプのアイデア引継ぎモード (関連資料 3 件を初期コンテキストに読み込む — `:13897`) の挙動が再現できない。(b) 検索層にスコープを渡さずプロンプトで「自分の資料だけ見よ」と指示: **LLM の遵守に依存する設計は本番で成立しない** ([../architecture.md](../architecture.md) §2 の D-C) |
| D-KN-9 | ファイル処理の非同期化 | アップロードは **201 + `status:"processing"`**。テキスト抽出・埋め込み生成は非同期。FE は `GET /knowledge-files/{file_id}` でポーリング。**実行主体 (プロセス内 goroutine)・状態機械・取り残しの回収・再実行 (同じファイルの再アップロード) は [README.md](README.md) §1.3 (D-API-15) が SSOT** | (a) 同期処理: 3.4 MB の PDF (プロトタイプの `kd2` — `:13857`) の抽出 + 埋め込みでリクエストタイムアウトに当たる。(b) SSE で進捗: 進捗の粒度が「抽出中 → 完了」の 2 段しかなく、接続維持のコストに見合わない |
| D-KN-10 | 原本ダウンロード | **非公開バケット + 署名付き URL (presigned URL) + `expires_at`** を返す (バイト列を返さない)。**これは v2 に前例が無い新規実装** ([README.md](README.md) D-API-14') | (a) API がバイト列をプロキシする: ECS タスクの帯域とメモリを消費し、大きい PDF で他リクエストに影響する。(b) **v2 と同じ方式で S3 の URL を返す (却下。当初は「v2 に前例あり」と書いていたが事実誤認だった)**: v2 の `uploadFile` は **`ACL: types.ObjectCannedACLPublicRead` を付けて公開し** (`hassan-v2-backend/aws/s3.go:46`)、`https://<bucket>.s3.amazonaws.com/<key>` という**恒久・無署名 URL を返す** (`同:58`)。v2 の用途はアイコン (`同:62-65`) と企画書サムネイル (`同:68-71`) という公開前提の画像。**ナレッジのファイルはヒアリング議事録・技術資料であり、同じ方式では URL を知る誰でも認証なしで読める** — [../auth.md](../auth.md) §2.2 の `asset_documents` (本文がテナント境界の外) と同じ事故をストレージ層に作ることになる。**`Presign` の参照は v2 の本体コードに 0 件**なので、実装は新規に書く |
| D-KN-11 | 一括削除の部分失敗 | **1 件でも他人 or 不存在なら全件実行しない** (404) | (a) 実行できたものだけ削除して結果を返す: 「何が消えて何が残ったか」を FE が集計する必要があり、失敗の可観測性が下がる。(b) 他人の ID を無視して自分の分だけ削除: 他テナントの ID を含む要求が**成功として記録される**ため、越境の試行がログから読み取れない |
| D-KN-12 | 通常モード時の検索対象 | **自分の全ファイル** (プロトタイプの「全ヒアリング資料・市場データを対象に横断回答」— `:13922` / `:14692` と同じ) | (a) 契約内の全ファイルを横断: A-7 (共有) が未確定であり、他人がアップロードしたヒアリング議事録が本人の許可なく引用される。**共有が必要になった時点で `scope` を追加する** |

### 3.1 上限値・許可値の SSOT (BE-2 の構造的回避)

サーバ側定数 1 箇所に置き、OpenAPI 経由で FE へ伝播させる ([README.md](README.md) D-API-14)。
**FE のバリデーションとプロンプトに数値・拡張子を書かない**。

| 項目 | プロトタイプの値 (暫定) | 出典 |
|---|---|---|
| 許可拡張子 | `.pdf` / `.doc` / `.docx` / `.ppt` / `.pptx` / **`.xls`** / `.xlsx` / `.csv` / `.txt` / `.md` (**プロトタイプの正規表現 `/\.(pdf|docx?|pptx?|xlsx?|csv|txt|md)$/i` は `xlsx?` = `.xls` も通す — allow-list 化のときに落とさない**。更新版でも同一の正規表現) | `../../prototype/hassan_agent_prototype_v2.html:14375` |
| ファイルサイズ上限 | プロトタイプに明示なし。**アセット側と同じ 20 MB を暫定採用** | [assets.md](assets.md) §3.1 と揃える (別値にする理由が無い) |
| 1 スレッドに紐付けられるファイル数 | プロトタイプに上限なし | **要確認 KN-Q3** (RAG のコンテキスト長に直結するため上限が必要) |

---

## 4. LLM ツール・RAG のテナント境界 (A-6 / AC-1.3)

**本節が回答する ID: A-6**

**層の前提**: ナレッジは **v2 移植ドメイン**であり、`service/` を持たない 3 層構成のまま移植する
([../architecture.md](../architecture.md) §3.5.2 の対象パス一覧)。
**ただし LLM 呼び出しだけは `gateway/` 経由を必須とする**
(ユーザー決定 2026-07-30。[../../../aidlc-docs/inception/productionization/questions-layering.md](../../../aidlc-docs/inception/productionization/questions-layering.md) Q-L11=A-1)。
また RAG は**ツールを使わない直接 API 経路**なので、会話型アイデア創出の `service/conversation.Runner`
(ツールループ) は通らない。

```
POST /knowledge-threads/{thread_id}/messages
   │  controller: X-Token を検証し account_id を取り出す
   ▼
usecase/knowledge: スレッドの所有者を account_id で照合 (不一致は 404)
   │  スレッドの file_ids を取得 (これも account_id 条件付きクエリ)
   │  ★ 検索フィルタに account_id を必須引数として渡す
   │  ★ file_ids が非空ならその集合にも限定する
   ▼
repository (ベクトル検索 + メタデータフィルタ)
   │  account_id 条件は WHERE 句に必ず入る (省略可能な引数にしない)
   ▼
usecase/knowledge: 検索結果 (所有者で絞り込み済み) のみを LLM への入力にする
   ▼
gateway/<プロバイダ>  ★ LLM 計測点 (1 箇所。埋め込み生成・回答生成の両方)
   │  所有者スコープの判断を持たない — 入力は呼び出し元が絞り込み済み
   │  CallMeta (usage 4 カウンタ / stop_reason) を戻り値で返す
   ▼
usecase/knowledge: 引用の生成 — 検索がヒットした file_id のみを citations に載せる
   │              明細の記録 (v3 第 1 リリース前。[../observability.md](../observability.md) §6.1)
```

**守るべき不変条件**:

1. **LLM が出力した `file_id` を引用として採用しない**。引用は「検索層が返した結果」からのみ作る。
   LLM が存在しない ID や他人の ID を出力しても、それは `citations` に現れない
2. スコープ外でヒットしなかった場合は「該当なし」として扱い、
   **エラー本文・回答本文に他テナントのリソースの存在を示す情報を含めない** ([../auth.md](../auth.md) §6.5)
3. `PUT /knowledge-threads/{thread_id}/files` で他人の `file_id` を紐付けようとした要求は **404**
   (成功して後段の RAG で黙って無視される、という形にしない)

---

## 5. 本番観点への回答

| ID | 回答 | 備考 |
|---|---|---|
| A-1 | [README.md](README.md) §2.1。全 15 本が認証必須 | AC-1.1 |
| A-2 | `AuthRoleUser` のみ。契約内管理者限定の操作は無い | — |
| A-3 | `knowledge_threads` / `knowledge_messages` / `knowledge_files` / `knowledge_thread_files` の**全テーブルに `account_id`**。抽出テキスト・埋め込みを保持するテーブルにも置く ([../auth.md](../auth.md) §6.3 の 3 番) | data-model で確定 |
| A-4 | 全エンドポイントで Repository のクエリ条件に `account_id`。`file_ids` / `idea_id` も所有者と組で検証 | §4 |
| A-5 | 本表の「固有ステータス」列 + [README.md](README.md) §2.5 | **AC-1.4** |
| A-6 | **§4 が本ファイルの中心的な回答** (AC-1.3) | [../architecture.md](../architecture.md) §3.8.2 が SSOT |
| A-7 | 共有しない (D-KN-12)。契約内共有は先送り | [README.md](README.md) §5 API-Q3 |
| O-2 | LLM 経路は **3 本のうち 2 本が本ファイル**: `POST /knowledge-threads/{thread_id}/messages` (質問応答) と **`POST /knowledge-files` (埋め込み生成)**。§2 の表の LLM 列がこの索引。**計測値の生成は `gateway/<プロバイダ>` の単一関門 1 箇所** (直接 API 経路も同じ gateway を通る)、明細の記録は `usecase/knowledge` ([../observability.md](../observability.md) の O-C) | **経路の見落としが O-2 の失敗形**なので、埋め込み生成を表の LLM 列に明示した ([README.md](README.md) §3 の合計 3 本と一致)。**ナレッジは移植ドメインだが Q-L11=A-1 により LLM 呼び出しは `gateway/` 経由が必須**なので、計測対象から漏れない (§4 の層の前提) |
| O-4 | ファイル処理の `failure.code`、質問応答の 502、`max_tokens` 切り詰めの警告 (BE-6) | 値域は [../observability.md](../observability.md) §4.3 |
| O-5 | SSE の切断時は**再質問**で回復する (D-KN-7)。切断された回答は `role:"assistant"` の未完了レコードとして残し、履歴 API で `status:"aborted"` を返す。**ストリーム開始後のエラーは SSE の `error` イベント** ([README.md](README.md) D-API-12)。**ファイル処理の非同期基盤は [README.md](README.md) §1.3** | イベント名・閾値の最終値は [../observability.md](../observability.md) §4.3 (F-5) / §4.4 / §4.4.1 |
| O-6 | スレッド・ファイルの作成/削除は監査対象 | 記録項目は [../observability.md](../observability.md) §4.5 |

---

## 6. 要確認 (プロトタイプに UI のみ / 判断待ち)

| # | 項目 | プロトタイプの状態 | 確定先 |
|---|---|---|---|
| KN-Q1 | **RAG の検索方式** | 回答は正規表現による固定文言 (`generateKbResponse` — `:14704-14755`)。検索は未実装 | 実装設計。ベクトル検索基盤 (pgvector / 外部サービス) の選定が前提。**PoC にも RAG の実装は無い** ([../../analysis/poc-inventory.md](../../analysis/poc-inventory.md) §3) |
| KN-Q2 | **Managed Agent か直接 LLM API か** | **回答済み (2026-07-30)** | **直接 LLM API** で確定 — [../llm-migration.md](../llm-migration.md) §4 (判定手順は同 §3) が SSOT。判定根拠: 検索 → 要約はツールを使わず・複数ターン回らず・出力が次の入力を決めないため (同 §3 の「分類 → 分岐」「履歴だけの chat」の読み方も参照)。**RAG は第 1 リリースに含める。ただし RAG の設計 (埋め込みプロバイダ選定・gateway・ベクトル格納先等) は別トピックとして切り出す** (2026-07-31 の LM-Q6 確定 — 同 §9.1。Anthropic に埋め込み API が無いため 3 番目のプロバイダの選定が別トピックの設計対象)。本ファイルのエンドポイント定義・増分 1 の位置づけは変わらない |
| KN-Q3 | **1 スレッドの紐付けファイル数上限** | 上限なし | 実装設計 (コンテキスト長との関係。§3.1) |
| KN-Q4 | **候補質問チップ** | 固定文字列のモック | 要件確認 (LLM 生成にするなら LLM 経路が 1 本増え、O-2 の対象が増える) |
| KN-Q5 | **`ideaNum` の参照整合** | `KB_DOCS[].ideaNum` は `"01"` 形式の文字列で `KB_THREADS[].ideaRef` と突き合わせている。**プロトタイプのコメント自身が「このスレッドの `ideaRef` は本来 #03 だが簡略化した」と不整合を認めている** (`:13904`) | data-model 設計。`idea_id` を外部キーにするか (推奨) 表示番号を持つか |
| KN-Q6 | **スレッドのタイトル自動生成** | 引継ぎ時は「<アイデア名>のナレッジ」、通常時は「新規チャット」の固定文言 (`:14676` / `:14687`) | 要件確認 (LLM で要約タイトルを付けるなら LLM 経路が 1 本増える) |
| KN-Q7 | **アイデア引継ぎ時の自動紐付け条件** | `KB_DOCS.ideaNum` が一致するファイルを自動紐付け (`:14674`) | data-model 設計。ファイルとアイデアの関連付けを誰が (アップロード時のユーザー / LLM) 決めるかが未確定 |
| KN-Q8 | **ファイル一覧の `sort` 値域** (2026-07-30 プロトタイプ更新) | 更新版の並び替えは `added`\|`name`\|`type` (`:14059-14063`, `:14298-14302`) — 設計の `created_at`\|`title`\|`byte_size` と食い違う (`type` 順が無く、`byte_size` 順は UI に無い) | 実装設計 (`type` をホワイトリストに足すか。`byte_size` を残すか) |
| KN-Q9 | **ファイル削除と既存引用の整合** (2026-07-30 プロトタイプ更新) | 削除確認モーダルが「ファイルを参照している回答も影響を受けます」と警告する (`openKbDeleteConfirmModal` `:14186-14234`)。削除後に既存メッセージの `citations` (file_id 参照) をどう表示するか (残す / 「削除済み」表示 / リンク無効化) が未規定 | data-model / FE 設計 ([idea-boards.md](idea-boards.md) D-IB-7 の `idea.deleted` と同型の解決が候補) |
| KN-Q10 | **ファイル管理 UI のスコープとアップロードの API 組合せ** (2026-07-30 プロトタイプ更新) | 更新版のファイル管理はチャット / ファイル管理の 2 タブ (`renderKbMainTabs` `:13953-13974`) で、**常にアクティブスレッドの範囲に限定** (§1.2)。`GET /knowledge-files` (全ファイル) に対応する画面が無い。スレッド内アップロードは `POST /knowledge-files` + `PUT /knowledge-threads/{id}/files` (置換) の 2 呼び出しになるが、置換セマンティクスとの組み合わせ手順が未記述。**なお旧ファイル管理モーダル (`openKbFileManagerModal` `:14247-14366`) は呼び出し元の無い死んだコード** (`:14006` のコメントで置換済みと明記) — 設計の手本にしない | FE 設計 (frontend.md の `/knowledge/files` ルートとの対応を含む)。API 自体は現行定義で表現可能 |
