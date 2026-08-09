# Questions (増分: conversation): 会話型アイデア創出 API の未確定論点

> 本書は増分 **conversation** (= [plan.md](plan.md) の **Task-3p**) の質問ファイル。
> 親: [questions.md](questions.md) / 先行増分: [questions-layering.md](questions-layering.md)
> 回答後の成果物: `requirements-conversation.md` → 設計起草 (`architecture-designer`)
>
> **回答は `[Answer]:` 行に書く**。未回答のまま進める場合は `> 推奨:` を暫定既定として
> requirements-conversation.md に「既定採用」と明記して設計を進める。
> 各問いには **この回答が何を左右するか** を添えた。

**本増分が受け持つ範囲** (他文書が明示的に本タスクへ委譲したもの):

| 委譲元 | 内容 |
|---|---|
| [API/README.md](../../../docs/design/API/README.md) §0 | 会話型アイデア創出 (会話セッション・SSE・9 custom tools・企画書生成) の API 一式 |
| [llm-migration.md](../../../docs/design/llm-migration.md) §4.1 / §4.2 | **LM-Q1** (P-3 を P-1 へ統合した後のプロンプト・ツール構成・会話状態) / **LM-Q2** (v2 の V-1 / V-3 → P-2、V-2 → P-5、V-6 → P-4、V-12 → N-1 の統合設計) |
| [frontend.md](../../../docs/design/frontend.md) §16.1 **FE-Q1** | SSE イベント型の確定 (FE の会話画面が実装着手不可) |
| [API/idea-boards.md](../../../docs/design/API/idea-boards.md) §7 / §8.1 | アイデアの本文更新経路と **`tags` の書き込み側** (BE-10) / **IB-Q7** (ステージ) |
| [API/assets.md](../../../docs/design/API/assets.md) §5 **AS-Q11** | 持ち込み PDF のアップロード経路 (**4 系統目を作らない**) |
| [API/themes.md](../../../docs/design/API/themes.md) **TH-Q3** / D-TH-4 | ステージ定義の SSOT |
| [data-model.md](../../../docs/design/data-model.md) §8.4 の 4 / 6 | `conversation_messages.status` の値域 / **テーマ確定のタイミング** |

**再議論しない確定事項** (本書では問わない):

1. **Managed Agent は 3 本** (P-1 orchestrator (P-3 統合済み) / P-2 diverge / P-4 plan tab)。`CHAT_AGENT_ID` 相当は発行しない — LM-Q1 (2026-07-31 ユーザー決定。[llm-migration.md](../../../docs/design/llm-migration.md) §4.1 / §6.3)
2. **v2 の V-1 / V-2 / V-3 / V-6 / V-12 は独立機能として移植しない** — LM-Q2 (同 §4.2)
3. **層構成と Agent 実行の内部構造** — `usecase/conversation` がツールハンドラをクロージャで組み立て `service/conversation.Runner` に注入する。所有者スコープを引数にしない ([architecture.md](../../../docs/design/architecture.md) §3.8.1 / §3.8.2 / D-C)
4. **会話まわりのテーブル** — `conversation_sessions` / `conversation_messages` / `conversation_tool_calls` / `conversation_ledger_archives` と台帳のスキーマ契約 ([data-model.md](../../../docs/design/data-model.md) §4.5 / §4.11)。**台帳は PoC の 13 フィールドのうち `entrypoint` / `interests` / `rejected_candidates[].confidence` を持たない** (同 §4.11.2。**件数は書かない** — 定義元の表が正。2026-08-01 に v3 独自の `seed_idea` を 1 つ追加したため、当初の「10」は実態とずれた = DR-9)
5. **ターンの排他** — ターン開始時に `SELECT ... FOR UPDATE NOWAIT`、取得できなければ 409 (DM-13)
6. **安全弁** — ツール呼び出し 20 回 / ターン、実行時間 5 分 ([observability.md](../../../docs/design/observability.md) §4.4)。**課金上限による拒否は設けない** (C-12)
7. **PoC の会話フローの事実** — [poc-conversation-flow.md](../../../docs/analysis/poc-conversation-flow.md) (2026-07-29 実測・抜き取り検証済み)。**再調査せず本書の事実の正として使う**

---

# 第 1 節: ユーザーの関心 4 点 (API 一覧 / オーケストレーター / Agent / custom tool)

## CV-Q1. 本増分が第 1 リリースで受け持つ機能範囲 (企画書ドメインの扱い)

**背景 (事実)**:

- **v3 の設計に「企画書 (business plans)」ドメインの対応先が存在しない**。v2 には
  [v2-feature-inventory.md](../../../docs/analysis/v2-feature-inventory.md) §2.7 に **18 エンドポイント**があり、
  全行の状態が「**統合**」または「**要確認**」で、**同節が「企画書に何があったか」の唯一の一覧**である
- 同 §5 の「対象外 (要確認)」一覧に、**企画書のお気に入り (#9)** と **版履歴のプロンプト編集 (#10)** が
  「一般ユーザー向け機能で、対象外とした明示的な判断が見つからない」として残っている
- v2 のアイデア系 13 本のうち **9 本が「統合」**扱いで対応先が本増分 (同 §2.5)
- **C-16**: v2 にある操作は落とさない。**増分の後ろ倒しにもユーザー承認が要る**
- PoC 側の企画書は **8 タブ (`plan_tab_versions`)** で、v2 の詳細版 7 セクション・簡易モードとは構造が違う
  ([llm-migration.md](../../../docs/design/llm-migration.md) §6.2 の 5)

**選択肢**:

- **A. 第 1 リリース = PoC 相当 + v2 企画書の CRUD/参照系。v2 固有の付加機能は増分 2 (併用期間) へ** —
  第 1 リリースに入れるのは①会話ターン ②アイデア生成・評価 ③企画書 8 タブの生成・取得・版・再生成
  ④企画書の一覧・取得・削除。**増分 2 へ送る**のは企画書チャット (V-8) / 詳細版セクション分析 (V-10) /
  詳細版 Web リサーチ (V-11) / サムネイル (V-9) / お気に入り / 版履歴のプロンプト編集。
  **本増分の設計書には 18 本すべての対応表を書き、送り先の増分を明記する** (落とした証跡を残す)
- **B. v2 の企画書 18 本すべてを第 1 リリースで設計・実装する** — 併用期間中の機能差をゼロにする
- **C. 第 1 リリースは PoC 相当のみ (v2 企画書は丸ごと増分 2)** — 会話から生成した 8 タブだけを持ち、
  v2 由来の企画書操作は併用期間に v2 側で使い続ける
- D. Other (please describe after [Answer]: tag below)

> 推奨: **A**。理由: ①[llm-migration.md](../../../docs/design/llm-migration.md) §4.2 が既に
> **V-8 / V-9 / V-10 / V-11 を優先度 2〜3 (併用期間)** と判定済みで、第 1 リリースに入れるとその判定と矛盾する
> ②一方で「企画書の一覧・取得・削除」が無いと、会話で生成した 8 タブを**後から開く経路が無い**
> (PoC は会話セッション経由でしか辿れない) ため、これは第 1 リリースに必須
> ③B は Task-3p 単体で v2 の 18 本 + 会話 + アイデアを同時に設計することになり、レビュー単位として大きすぎる。
> **お気に入り (#9) と版履歴のプロンプト編集 (#10) は「増分 2 で扱う」と明記して C-16 の宙吊りを解消する**
> (対象外にするなら別途その旨の承認が要る)。

**この回答が左右するもの**: 設計書のファイル数と分割 (CV-Q2) / [v2-feature-inventory.md](../../../docs/analysis/v2-feature-inventory.md) §5 の
未解決 2 件のクローズ / [operations.md](../../../docs/design/operations.md) §6 の切替段階 (RL-3 で v2 の企画書画面を止められるか) /
`plans` テーブルの第 1 リリース投入範囲。

[Answer]: **B で確定** (2026-08-01 ユーザー回答)。**v2 の企画書 18 エンドポイントすべてを第 1 リリースで設計・実装する** — 併用期間中の機能差をゼロにする。C-16 (v2 にある操作は落とさない) を最も厳格に満たす選択。
> **B を採った帰結 (requirements-conversation.md と設計書に必ず書くこと)**:
> 1. **[llm-migration.md](../../../docs/design/llm-migration.md) §4.2 が V-8 (企画書チャット) / V-9 (サムネイル) / V-10 (詳細セクション分析 7 種) / V-11 (詳細版 Web リサーチ) を「優先度 2〜3 = v2 併用期間」と判定している**。B はこの判定と衝突するため、**同書への是正要求として起票する** (優先度を 1 = 第 1 リリースへ引き上げ、§7.1 の移送段階 M-x とリリース段階 RL-x の対応も見直す)。無言の逸脱にしない
> 2. **[v2-feature-inventory.md](../../../docs/analysis/v2-feature-inventory.md) §5 の未解決 2 件をクローズする** — **#9 企画書のお気に入り** (`business_plan_favorites` 相当のテーブルが v3 に無い → [data-model.md](../../../docs/design/data-model.md) へのテーブル追加要求として起票。**DR-9 の連動 = `make check-table-counts` の期待値更新を伴う**) / **#10 版履歴のプロンプト編集** (`plan_tab_versions` に生成プロンプトを保持する列が要るかを設計で判定する)
> 3. 本増分の設計書に **18 本すべての v2 → v3 対応表**を置く (どのエンドポイントがどの v3 API・どの会話ツールに写像されるか。1 本も宙吊りにしない)
> 4. **スコープが CV-Q2=A の 3 ファイルに収まらない可能性がある** — `plans.md` が単独で大きくなるため、起草は会話 / アイデア / 企画書の 3 セッションに分ける (CV-Q2 の A が並列起草を可能にしている)

---

## CV-Q2. 成果物の置き場所とファイル分割 (= 「API 一覧」の粒度)

**背景 (事実)**:

- [API/README.md](../../../docs/design/API/README.md) §0 は会話型アイデア創出を**対象外**と宣言し、
  「別途『会話型アイデア創出の API 設計』として起草する。本ディレクトリには置かない」と書いている
- 一方、同 §3 の総覧表・`scripts/check-endpoint-mapping.sh` の検査④は「**6 ドメイン**」を前提に
  ファイル実測と総覧表を機械照合している。**API/ 配下にファイルを足すと、README §3 の総覧・小計・
  注記と検査スクリプトを同じ差分で更新する必要がある** (DR-9)
- [API/idea-boards.md](../../../docs/design/API/idea-boards.md) §7 はアイデアの**参照系 3 本**を暫定的に置いており、
  「専用ファイル `ideas.md` の新設」を却下した理由に「**生成系が確定した時点で統合され直す可能性が高い**」と書いている

**選択肢**:

- **A. `docs/design/API/` 配下に 3 ファイルを追加し、README §0 の「対象外」を解除する** —
  `conversation.md` (会話セッション・ターン・SSE・ツール) / `ideas.md` (アイデアの生成・更新・参照。
  **idea-boards.md §7 の 3 本を移設**) / `plans.md` (企画書)。総覧は「6 ドメイン」→「9 ドメイン」に更新し、
  `check-endpoint-mapping.sh` の検査④の対象を広げる
- **B. `docs/design/API/conversation.md` の 1 ファイルにすべて書く** — 会話・アイデア生成・企画書を 1 本に。
  総覧への追加は 1 行で済む
- **C. `docs/design/API/` の外 (例: `docs/design/conversation-api.md`) に置く** — README §0 の宣言を変えない
- D. Other (please describe after [Answer]: tag below)

> 推奨: **A**。理由: ①**共通規約 (認証・スコープ・ステータスコード・非同期ジョブ) は
> [API/README.md](../../../docs/design/API/README.md) §1・§2 が SSOT** であり、同ディレクトリ外に置くと
> 「会話だけ規約が別」に見える (実際には同じ規約に載る) ②`ideas` テーブルの API SSOT が
> idea-boards.md と新ファイルの 2 箇所に割れる問題は、**参照系を `ideas.md` へ移す**ことで解消する
> (idea-boards.md §7 が予告している統合そのもの) ③B は 1 ファイルが会話 + アイデア + 企画書で
> 巨大化し、増分ごとの更新でコンフリクト範囲が全域に広がる (README §0 が分割を選んだ理由と同じ)。
> **A のコスト**: README §3 の総覧・小計・「共通規約が対象にするのは 6 ドメインの N 本」の注記と
> `check-endpoint-mapping.sh` を同じ差分で更新する (検査があるので取り残しは機械検出される)。

**この回答が左右するもの**: 設計起草の分割単位と並列可否 (3 ファイルなら会話 / アイデア / 企画書を
別セッションで起草できる) / `make check-endpoint-mapping` の改修範囲 / [API/README.md](../../../docs/design/API/README.md) §0 の書き換え /
[frontend.md](../../../docs/design/frontend.md) §11.1 の「[未確定]」行の解消先。

[Answer]: **A で確定** (2026-08-01 ユーザー回答)。`docs/design/API/` 配下に **`conversation.md` / `ideas.md` / `plans.md`** の 3 ファイルを追加し、[API/README.md](../../../docs/design/API/README.md) §0 の「対象外」宣言を解除する。[API/idea-boards.md](../../../docs/design/API/idea-boards.md) §7 の参照系 3 本は `ideas.md` へ移設する。
> **同じ差分で必ず更新するもの (DR-9。取り残しは `make check-endpoint-mapping` が検出する)**: README §3 の総覧表 (6 → 9 ドメイン・小計・合計)・§3.1〜§3.6 の明細・「共通規約が対象にするのは N 本」の注記・`scripts/check-endpoint-mapping.sh` の検査④の対象集合。**idea-boards.md §7 は移設後に「参照系は ideas.md へ移設済み」と書き換える** (空節を残さない)。

---

## CV-Q3. 会話ターンの入口の形 (オーケストレーターの外形)

**背景 (事実)**:

- PoC は **`POST /api/conversation` が直接 SSE を返す** (1 リクエスト = 1 ターン。`session` 先頭 → … → `done` 末尾。
  [poc-conversation-flow.md](../../../docs/analysis/poc-conversation-flow.md) §1.1 / §1.5)
- [architecture.md](../../../docs/design/architecture.md) §7 は配置例として **`POST /conversations/{id}/messages`**
  (ユーザー発話を受けて SSE で流す) を挙げている
- [API/README.md](../../../docs/design/API/README.md) §1.3 の非同期ジョブ共通仕様は
  **J-2 (状態の SSOT は DB の `status`)・J-6 (SSE は DB の状態をポーリングして配信し、
  実行 goroutine と SSE 接続が同一プロセスにいることを前提にしない)・J-7 (SSE は進捗表示専用で、
  結果の唯一の受け取り口にしない)** を定めている
- FE は **Vercel の Route Handler で中継**し、実行時間上限は Pro で 800 秒設定可 (既定 300 秒)
  ([frontend.md](../../../docs/design/frontend.md) §16.1 FE-Q2)。ターンの安全弁は 5 分

**選択肢**:

- **A. `POST /conversations/{session_id}/messages` が SSE を返す (PoC / architecture §7 と同形)** —
  ターンはリクエストのライフサイクルと一致。切断時の回復は
  **`GET /conversations/{session_id}` (台帳) + `GET /conversations/{session_id}/messages?after_seq=` (履歴)** で行う
  (J-7 の「結果は SSE 以外からも取れる」を満たす)。**同一セッションへの並行ターンは 409** (DM-13)
- **B. ターンをジョブ化する** — `POST /conversations/{session_id}/turns` が 202 + `turn_id` を返し、
  `GET /conversations/{session_id}/turns/{turn_id}/stream` で購読する。J-1〜J-7 に完全準拠し、
  **接続前に切れても実行が続く / 別タブから再購読できる**
- **C. A + 企画書生成だけジョブ化** — 長時間になる 8 タブ生成 (`generate_plan`) のみ別ジョブにする
- D. Other (please describe after [Answer]: tag below)

> 推奨: **A**。理由: ①**ターンは「ユーザーの発話に対する応答」であり、実行がユーザーの待機と一致する**
> (アセット抽出のような投げっぱなしのジョブとは性質が違う) ②J-6 の懸念は
> 「**ALB が SSE 接続をジョブが走っていないタスクに振ると進捗が流れない**」ことだが、
> **A では SSE を返すリクエスト自身がターンを実行するため、この振り分けが起こり得ない**
> (別タスクに繋がる可能性があるのは「実行中のジョブを後から購読する」形の B の方で、
> B は DB ポーリングの実装が必須になる) ③J-7 は「結果を SSE 以外からも取れること」の要求であり、
> `conversation_messages` + 台帳を GET できる A で満たせる。
>
> **A を採る場合に設計で明示すること**: **J-1〜J-7 は非同期ジョブ (アセット抽出等) の規約**として書かれている。
> 会話ターンをその適用外とするなら、[API/README.md](../../../docs/design/API/README.md) §1.3 に
> 「会話ターンは同期 SSE であり J-6 の対象外。ただし J-7 (結果の取得口を SSE 以外にも持つ) は満たす」ことを
> **明記する是正要求を起票する** (無言の逸脱にしない)。
> **B を採る場合の代償**: 進捗の DB ポーリング機構・`turns` テーブル・購読権の検証が増え、
> 会話の応答レイテンシに DB ポーリング間隔が乗る。**5 分を超える処理を作らない**方針 (安全弁) と合わせると、
> B の利点 (長時間処理の非同期化) は活きにくい。

**この回答が左右するもの**: SSE イベント型 (CV-Q6) の `session` / `turn` の表現 /
[frontend.md](../../../docs/design/frontend.md) §6.3.1 の中継 Route Handler の行 (メソッドとパス) /
`conversation_tool_calls.turn_seq` の採番主体 / O-5 (切断・再接続の観測) の設計 / データモデルへの追加要否 (B なら `turns` 相当が要る)。

[Answer]: **A で確定** (2026-08-01 ユーザー回答)。**`POST /conversations/{session_id}/messages` が同期 SSE を返す** (PoC / [architecture.md](../../../docs/design/architecture.md) §7 と同形)。切断時の回復は `GET /conversations/{session_id}` (台帳) + `GET /conversations/{session_id}/messages?after_seq=` (履歴)。同一セッションへの並行ターンは **409** (DM-13)。
> **同じ差分で起票する是正要求**: [API/README.md](../../../docs/design/API/README.md) §1.3 に「**会話ターンは同期 SSE であり J-6 (実行 goroutine と SSE 接続の分離) の対象外。ただし J-7 (結果の取得口を SSE 以外にも持つ) は満たす**」を明記する。無言の逸脱にしない。

---

## CV-Q4. Agent 3 本の責務境界 — P-1 に統合した「発散後チャット」のモード表現

**背景 (事実)**:

- LM-Q1 により **P-3 (発散後チャット) は P-1 (会話オーケストレーター) に統合**され、
  `prompts/conversation/orchestrator.md` に節として取り込まれる。**`post_diverge_chat.md` は作らない**
  ([llm-migration.md](../../../docs/design/llm-migration.md) §6.1 / §6.3)
- PoC の P-1 は**起点 3 種で手順が変わる** (アセットから発散 = 5 ステップ / ゼロベース = 4 ステップで
  `match_functions` を呼ばない / 自分のアイデアから発散 = `<idea_input>` タグで既存 9 ツールに合流。
  [poc-conversation-flow.md](../../../docs/analysis/poc-conversation-flow.md) の経路表)
- PoC は会話の進行段階を**台帳から導出する `stage`** で表している (`asset` → `market` → `match` →
  `ideation` → `plan_draft`。同 §5.3)
- **ツール schema は Agent リソース側に登録され `Tools` は全置換**される (BE-9)。
  PoC は `update-agent-prompt -conversation-tools` で 9 本を一括登録する (同 §3)
- **P-2 (diverge) と P-4 (plan tab) は、P-1 の custom tool ハンドラの中から呼ばれる**
  (`generate_ideas` → P-2、`generate_plan` → P-4。同 §6 の 15j)

**選択肢**:

- **A. system prompt 1 本 + サーバが「現在の stage と前提の充足状況」を毎ターン注入する** —
  Agent は注入された状態を見て、発散前モード / 発散後モードの節を自分で選ぶ。ツール集合は常に全 9 本で、
  **前提を満たさないツール呼び出しはハンドラが構造化エラー (`missing` 付き) で拒否する** (PoC と同じ)
- **B. stage ごとにツール集合を出し分ける** — 発散後は `generate_ideas` を外す等、Agent に見えるツールを絞る
- **C. Agent を 2 本に戻す (P-3 の統合を撤回)** — LM-Q1 の再議論
- D. Other (please describe after [Answer]: tag below)

> 推奨: **A**。理由: ①**Managed Agent の `Tools` は Agent リソース側の設定で全置換**であり
> (BE-9)、ターンごとに集合を変えるには「stage ごとに別 Agent を発行する」ことになる —
> **LM-Q1 が Agent を 3 本に減らした目的 (D-6 の再発行対象と A-6 の検証点を減らす) に逆行する**
> ②前提不足の拒否は**すでにハンドラ側にある** (PoC は `missing` 付きの構造化エラーを返す) ため、
> ツールを隠さなくても誤呼び出しは止まる ③状態の SSOT は台帳であり、
> **プロンプトに「今どの段か」を書くのではなく、サーバが毎ターン注入する**ことで
> BE-1 (旧バージョン参照) の余地を減らせる。
> **A を採る場合に設計で決めること**: 注入する状態のフォーマット (台帳のどのフィールドを何形式で渡すか) と、
> それを**プロンプト本文ではなくユーザーメッセージの前置きとして渡すか system prompt のテンプレート引数にするか**。

**この回答が左右するもの**: `prompts/conversation/orchestrator.md` の構成 / D-6 の再発行対象 (3 本のままか) /
`service/conversation.Runner` がターン開始時に受け取る入力の形 / 統合による品質劣化の A/B 評価対象
([llm-migration.md](../../../docs/design/llm-migration.md) §8.2)。

[Answer]: **A で確定** (2026-08-01 ユーザー回答)。**system prompt は 1 本**とし、サーバが毎ターン「現在の stage と前提の充足状況」を注入する。ツール集合は常に全数で、前提を満たさない呼び出しは**ハンドラが構造化エラー (`missing` 付き) で拒否**する (PoC と同じ)。Agent は 3 本のまま (D-6 の再発行対象は増やさない)。
> **設計で確定させること**: 注入する状態のフォーマット (台帳のどのフィールドを何形式で渡すか) と、**プロンプト本文ではなくユーザーメッセージの前置きとして渡すか、system prompt のテンプレート引数にするか**。状態の SSOT は台帳であり、プロンプトに「今どの段か」を書かない (BE-1 の余地を減らす)。

---

## CV-Q5. custom tool の構成方針 (PoC 9 本の取捨と、追加の判断基準)

**背景 (事実)**:

- PoC の 9 本: `list_assets` / `load_asset` / `set_theme_name` / `research_market` / `deep_dive` /
  `generate_ideas` / `generate_plan` / `record_rejection` / `match_functions`
  ([poc-conversation-flow.md](../../../docs/analysis/poc-conversation-flow.md) §3.1)
- 統合によって本増分が受け持つ機能が増える: **v2 のアイデア生成 (V-1) / マイアイデア補完 (V-3) → P-2**、
  **アイデア評価 (V-2) → P-5**、**企画書簡易モード (V-6) → P-4** ([llm-migration.md](../../../docs/design/llm-migration.md) §4.2)
- 更新版プロトタイプの会話 UI には**アーティファクトのバージョン管理・発散設計ウィジェット・
  持ち込み PDF・企画書 8 サブタブ**がある ([frontend.md](../../../docs/design/frontend.md) §16.1 FE-Q1 の設計入力)
- **`tags` の書き込み側**が未定義 ([API/idea-boards.md](../../../docs/design/API/idea-boards.md) §8.1)
- ツール schema・ハンドラ・プロンプトの 3 者一致は **`scripts/check-tool-contract.sh` で機械検査**する
  ([architecture.md](../../../docs/design/architecture.md) §3.8.4)。**ツールを 1 本増やすと D-6 の再発行と検査対象が増える**

**選択肢**:

- **A. 「LLM が呼び出しを決める必要があるか」で足切りし、9 本を基準に増減させる** —
  [llm-migration.md](../../../docs/design/llm-migration.md) §3 の判定 Q1 を tool にも適用する。
  **ユーザー操作で起動が決まるもの (タグ編集・版の復元・PDF 添付・サブタブの再生成) は通常の REST API にし、tool にしない**。
  統合分 (V-1 / V-3 / V-6) は**既存ツールの引数で吸収**し、新ツールを作らない
- **B. 9 本を据え置き、いかなる追加もしない** — 不足はプロンプトと引数で吸収する
- **C. 統合とプロトタイプ UI に合わせてツールを増やす** (例: `save_idea_tags` / `update_idea` /
  `regenerate_plan_tab` / `attach_pdf`)
- D. Other (please describe after [Answer]: tag below)

> 推奨: **A**。理由: ①**ツールは「LLM が呼ぶかどうかを判断する」ためのインターフェース**であり、
> ユーザーがボタンで起動する操作を tool にすると、LLM の判断を挟む必然性が無いまま
> D-6 の再発行対象・3 者一致検査・A-6 の越境検証点が増える ②PoC は「自分のアイデアから発散」を
> **新ツールを増やさず既存 9 ツールに合流させた**前例がある (同 §経路表) ③B は硬直的で、
> 統合で本当に必要になった場合に判断基準が無い。
> **A で予想される増減 (設計で確定させる)**: **`set_theme_name` は CV-Q8 の回答次第で不要になる** /
> **`record_rejection` は読み手を必ず実装する** ([data-model.md](../../../docs/design/data-model.md) §4.11.2 で
> 「再提案の抑制」に使うと決めている) / v2 のアイデア評価 (V-2) の再評価入口を tool にするか
> REST にするかは、**「LLM がターン中に評価を挟む必要があるか」で判定する**。

**この回答が左右するもの**: `prompts/agents.yaml` の初期値と D-6 の再発行対象 / `check-tool-contract.sh` の検査対象集合 /
CV-Q9〜CV-Q12 (プロトタイプ由来の操作を tool にするか REST にするか) の既定 /
[testing.md](../../../docs/design/testing.md) の「全 tool のテナント越境テスト」の本数。

[Answer]: **A で確定** (2026-08-01 ユーザー回答)。**「LLM が呼び出しを決める必要があるか」で足切り**する ([llm-migration.md](../../../docs/design/llm-migration.md) §3 の判定 Q1 を tool にも適用)。**ユーザー操作で起動が決まるもの (タグ編集・版の復元・PDF 添付・サブタブの再生成) は REST API とし、tool にしない**。統合分 (V-1 / V-3 / V-6) は既存ツールの引数で吸収し、新ツールを作らない。
> **本回答から確定する増減 (設計書に一覧を置く)**: **`set_theme_name` は廃止** (CV-Q8=A でテーマ必須になったため。9 → 8 本) / **`record_rejection` は読み手を必ず実装する** ([data-model.md](../../../docs/design/data-model.md) §4.11.2 の「再提案の抑制」。BE-10) / CV-Q9=A・Q10=A・Q11=A・Q12=A により**版の復元・タブ再生成・タグ編集・PDF 添付はすべて REST** となり tool を増やさない。**v2 のアイデア評価 (V-2) の再評価入口**は「LLM がターン中に評価を挟む必要があるか」で判定する。

---

# 第 2 節: 会話の契約 (SSE・履歴・テーマ)

## CV-Q6. SSE イベント型の方針 (FE-Q1 のブロック解消)

**背景 (事実)**:

- PoC のイベントは **9 種 + keep-alive コメント**: `session` / `message_delta` / `tool_start` / `tool_end` /
  `generate_progress` / `plan_progress` / `artifact` / `error` / `done`
  ([poc-conversation-flow.md](../../../docs/analysis/poc-conversation-flow.md) §1.2)
- **不揃いが 3 点ある**: ①`artifact` の 6 kind のうち `asset` だけ `payload` ラッパを持たない
  ②`research` だけ `pattern` が payload の sibling ③進捗イベントが `generate_progress` (total=5) と
  `plan_progress` (total=8) の 2 種に分かれ、status 中継時は `tab_id`/`label` が空文字 (同 §1.3 / §1.2)
- **`error` は `runErr.Error()` を素通し**し、Anthropic API のエラー文言が FE に出る (同 §1.2)
- v3 では **SSE イベント型を OpenAPI の `components/schemas` に discriminated union で定義**し、
  FE は生成型で受ける (D-API-12 / [frontend.md](../../../docs/design/frontend.md) §6.2 の S-8)。
  **未知イベントは捨てずに上位へ渡す** (S-6)
- 安全弁による打ち切りは「**エラーではなく正常終了**として扱い、理由を SSE イベントとターン集計に載せる」
  と決まっている ([architecture.md](../../../docs/design/architecture.md) §9 相当の失敗の扱い / [observability.md](../../../docs/design/observability.md) §4.4)

**選択肢**:

- **A. PoC の 9 種を土台に、次の 4 点を正して確定する** — ①`artifact` を**単一形 (`{kind, payload}`)** に統一
  (`asset` の例外と `research.pattern` の sibling を payload 内へ) ②進捗を **`progress` 1 種**に統合
  (`{scope: "ideas"|"plan", step, total, label, detail?}`) ③`error` を **`CodedError` の形
  (`{code, message}`)** にし、プロバイダのエラー文言を素通ししない ④**`turn_summary`** を追加
  (`outcome` = `completed`|`tool_limit`|`token_limit`|`timeout`|`failed`、ツール呼び出し回数、`done` の直前)
- **B. PoC の 9 種をそのまま踏襲する** (FE の移植コストが最小)
- **C. イベント名から全面的に設計し直す** (PoC との対応表を別途作る)
- D. Other (please describe after [Answer]: tag below)

> 推奨: **A**。理由: ①**PoC の 3 つの不揃いは FE 側の分岐として残り続ける** — discriminated union を
> OpenAPI に置く方針 (S-8) と最も相性が悪いのが「kind ごとに形が違う artifact」である
> ②`error` の素通しは**プロバイダのエラー文言をユーザーに見せる**ことになり、
> v3 の `CodedError` 規約 ([API/README.md](../../../docs/design/API/README.md) §1.2) から外れる
> ③安全弁の打ち切りを「正常終了」として表す受け皿が PoC に無い (`done` の `elapsed_sec` だけ) ため、
> **`turn_summary` が無いと打ち切りが `error` と区別できない**。
> **C を採らない理由**: PoC の名前 (`message_delta` / `tool_start` / `artifact`) は素直で、
> 改名は移植時の対応表コストだけを生む。

**この回答が左右するもの**: [frontend.md](../../../docs/design/frontend.md) FE-Q1 のクローズと会話画面の実装着手 /
`lib/sse/decode-event.ts` の分岐 (S-9 の `unknown` 固定を解除できる) / O-5 (SSE の切断・打ち切りの観測) /
[testing.md](../../../docs/design/testing.md) の SSE テストケース。

[Answer]: **A で確定** (2026-08-01 ユーザー回答)。PoC の 9 種を土台に 4 点を正す: ①**`artifact` を単一形 `{kind, payload}` に統一** (`asset` の payload ラッパ欠落と `research.pattern` の sibling を payload 内へ) ②**進捗を `progress` 1 種に統合** (`{scope: "ideas"|"plan", step, total, label, detail?}`) ③**`error` を `CodedError` 形 `{code, message}`** にし、プロバイダのエラー文言を素通ししない ④**`turn_summary` を追加** (`outcome` = `completed`|`tool_limit`|`token_limit`|`timeout`|`failed` + ツール呼び出し回数。`done` の直前)。
> **これにより [frontend.md](../../../docs/design/frontend.md) §16.1 の FE-Q1 がクローズできる** — 型は OpenAPI の `components/schemas` に discriminated union で定義し (D-API-12 / §6.2 の S-8)、`lib/sse/decode-event.ts` の `unknown` 固定 (S-9) を解除できる。**未知イベントは捨てずに上位へ渡す** (S-6) は維持する。

---

## CV-Q7. 会話履歴の保存粒度と、中断したターンの表現

**背景 (事実)**:

- **DM-12 で `conversation_messages` の新設は確定済み**。PoC は会話履歴を DB に持たず
  Anthropic の session 側にのみ存在していた ([data-model.md](../../../docs/design/data-model.md) §4.5 / G-12)
- 同テーブルの `status` は **`complete` | `aborted` | `failed`** で置かれているが、
  **§8.4 の仮定 4 が「会話 API 設計で再開・履歴取得の仕様が変わればこの値域が変わる」と明記**している
- PoC の agent 発話は**行単位で `message_delta`** として流れ、DB には残らない (同 §1.4)
- 安全弁 (5 分 / 20 ツール) の打ち切りは**ターンの途中**で起きる ([observability.md](../../../docs/design/observability.md) §4.4)

**選択肢**:

- **A. ターン終了時に 1 メッセージ = 1 行で保存する。中断時も「その時点までの本文」を `aborted` で保存する** —
  ユーザー発話は受信時、assistant 発話はターン終了時 (正常・中断・失敗のいずれでも 1 行)
- **B. デルタを受けるたびに追記保存する** — 切断してもサーバ側に本文が残り、再接続で途中から見せられる
- **C. 完了したターンのみ保存する (中断は保存しない)**
- D. Other (please describe after [Answer]: tag below)

> 推奨: **A**。理由: ①B は**1 ターンで数十〜数百回の UPDATE** が走り、`conversation_messages` は
> [data-model.md](../../../docs/design/data-model.md) §3.4 で「**最も行数が伸びるテーブル**」に分類されている
> ②C は打ち切られたターンの本文が**どこにも残らない**ため、O-4 (失敗の可観測性) と
> ユーザーの「さっき途中まで出ていた内容」が消える ③A なら `status` の値域を変えずに済み、
> **中断の理由は `turn_summary` (CV-Q6) と `conversation_tool_calls` から辿れる**。
> **A で設計に書くこと**: ターンが 1 トランザクション ([architecture.md](../../../docs/design/architecture.md) §3.10) である以上、
> **中断時の保存はロールバックされない経路で行う必要がある** (別トランザクション。Q-L2=B と同じ扱い)。

**この回答が左右するもの**: `conversation_messages.status` の値域確定 ([data-model.md](../../../docs/design/data-model.md) §8.4 の仮定 4 のクローズ) /
`GET /conversations/{id}/messages` のページング契約 / 再接続時に FE が復元する範囲 (CV-Q3 の A で必須) /
ターンのトランザクション境界。

[Answer]: **A で確定** (2026-08-01 ユーザー回答)。**ターン終了時に 1 メッセージ = 1 行**で保存する (ユーザー発話は受信時、assistant 発話はターン終了時)。**中断時も「その時点までの本文」を `aborted` で保存する**。`conversation_messages.status` の値域は `complete` | `aborted` | `failed` のまま確定 ([data-model.md](../../../docs/design/data-model.md) §8.4 の仮定 4 をクローズ)。
> **設計で明示すること**: ターンは 1 トランザクション ([architecture.md](../../../docs/design/architecture.md) §3.10) であるため、**中断時の保存はロールバックされない別トランザクションで行う**。中断の理由は `turn_summary` (CV-Q6) と `conversation_tool_calls` から辿る。

---

## CV-Q8. テーマ確定のタイミング (テーマ無しで会話を始められるか)

**背景 (事実)**:

- PoC は**テーマ無しで会話を開始でき**、`set_theme_name` ツールまたは `generate_ideas` の実行時に
  `themes` 行を暗黙作成する (「対話生成: <本体>」名。
  [poc-conversation-flow.md](../../../docs/analysis/poc-conversation-flow.md) の経路表 / §6 の 10)。
  `conversation_sessions.theme_id` は **NULL 可**
- **FE-Q5 は「会話はテーマ配下」で確定済み** — ルートは `/themes/[themeId]/conversations/[conversationId]`
  ([frontend.md](../../../docs/design/frontend.md) §16.1 FE-Q5。2026-07-31 ユーザー回答)
- [data-model.md](../../../docs/design/data-model.md) §8.4 の仮定 6 が
  「**テーマ未確定のまま会話を始める仕様なら、紐づく前の `llm_call_records` は `theme_id` が NULL のまま残り、
  遡ってテーマ単位に集計できない**」として本増分に確認を求めている (O-3 のテーマ単位コスト集計)

**選択肢**:

- **A. 会話の作成にテーマを必須にする** — `POST /themes/{theme_id}/conversations` (または
  `POST /conversations` に `theme_id` 必須)。テーマが無いユーザーは会話開始前にテーマを作る
  (FE は「テーマ作成 → 会話開始」の 1 ステップを挟む)。**`set_theme_name` ツールは不要になり、
  テーマ名の変更は既存のテーマ更新 API で行う**
- **B. PoC 踏襲 (テーマ無しで開始でき、途中で暗黙作成する)** — `theme_id` は NULL 可のまま。
  紐づく前の LLM 明細は `theme_id` NULL で残す (遡及更新しない)
- **C. B + テーマ確定時に当該セッションの `llm_call_records` を遡って更新する** —
  ただし [data-model.md](../../../docs/design/data-model.md) §7.2 の検査 5 (明細の append-only) と矛盾する
- D. Other (please describe after [Answer]: tag below)

> 推奨: **A**。理由: ①**FE-Q5 の確定 (テーマ配下) と URL 構造が既に A を前提にしている**
> ②`llm_call_records.theme_id` が最初から埋まり、O-3 のテーマ単位コスト集計に穴が空かない
> ③暗黙のテーマ作成が無くなることで、**ツールが 1 本減り** (`set_theme_name`)、
> テーマ作成の入口が 1 つになる (BE-2 型の散在を防ぐ)。
> **A の代償**: 「まず話し始めて、後からテーマ名を決める」という PoC の体験ができなくなる。
> **これを残したい場合は B** を選び、その場合は §8.4 の仮定 6 の帰結 (紐づく前の明細が
> テーマ集計に入らない) を許容することになる。

**この回答が左右するもの**: 会話作成エンドポイントの形 / `set_theme_name` ツールの存廃 (CV-Q5) /
`conversation_sessions.theme_id` の NULL 可否 / [data-model.md](../../../docs/design/data-model.md) §8.4 の仮定 6 のクローズ /
O-3 のテーマ単位集計の完全性。

[Answer]: **A で確定** (2026-08-01 ユーザー回答)。**会話の作成にテーマを必須にする**。`conversation_sessions.theme_id` は **NOT NULL** となり、`llm_call_records.theme_id` が最初から埋まるため O-3 のテーマ単位コスト集計に穴が空かない ([data-model.md](../../../docs/design/data-model.md) §8.4 の仮定 6 をクローズ)。
> **連動**: **`set_theme_name` ツールを廃止**する (CV-Q5 の増減に反映済み)。テーマ名の変更は既存のテーマ更新 API で行う。PoC の暗黙テーマ作成 (「対話生成: <本体>」) は**移植しない**。FE は「テーマ作成 → 会話開始」の導線を持つ ([frontend.md](../../../docs/design/frontend.md) FE-Q5 の確定と整合)。**`theme_id` の NOT NULL 化は [data-model.md](../../../docs/design/data-model.md) への是正要求として起票する**。

---

# 第 3 節: 生成物とプロトタイプ由来の新 UI

## CV-Q9. アーティファクトのバージョン管理 (プロトタイプの保存 / 復元 / 削除)

**背景 (事実)**:

- 更新版プロトタイプの会話ビューに**アーティファクトのスナップショット保存 / 復元 / 削除**の UI がある
  (`hassan_agent_prototype_v2.html:9116-9375`。[frontend.md](../../../docs/design/frontend.md) §16.1 FE-Q1 の設計入力)。
  **プロトタイプは設計入力であって仕様ではない** (DR-7)
- v3 は既に **版テーブルを 2 本**持つ: `idea_versions` と `plan_tab_versions`
  (`UNIQUE (plan_id, tab_id, ver_no)`。[data-model.md](../../../docs/design/data-model.md) §4.6)。
  **採番は 1 SQL に閉じる** (BE-11 対策。同 §7.1)
- 台帳の append 系エントリは **`entry_id` (uuid) を必須**で持ち、企画書タブは
  `content.source_deep_dive_entry_ids` で「どの deep dive を使ったか」を記録する (同 §4.11.2)。
  **BE-1 (旧バージョン参照で数値が食い違う) への構造的対策**

**選択肢**:

- **A. 既存の版テーブルの操作として API 化し、「スナップショット」という別概念を作らない** —
  `GET /ideas/{idea_id}/versions` / `GET /plans/{plan_id}/tabs/{tab_id}/versions` と
  「特定版を最新として複製する (復元)」操作を定義する。**削除は論理削除または不可**
- **B. 会話アーティファクトのスナップショットテーブルを新設する** — 会話画面に出ている状態
  (アイデア群 + 企画書 + 調査結果) をまとめて 1 スナップショットとして保存する
- **C. 採用しない (プロトタイプの UI として扱い、API を作らない)**
- D. Other (please describe after [Answer]: tag below)

> 推奨: **A**。理由: ①**同じ「版」が 2 系統になる** (版テーブル + スナップショット) と、
> BE-1 の「どのバージョンを渡すか」の記録が 2 箇所に割れる ②B は台帳・アイデア・企画書を
> 横断してコピーする必要があり、**`entry_id` による還流元の追跡 (§4.11.2) と二重管理になる**
> ③復元は「過去版を新しい版として作り直す」で表現でき、**履歴を壊さない** (削除より安全)。
> **A で設計に書くこと**: 「復元」が新版を作る操作であること (版番号は増える) と、
> **プロトタイプの「削除」に対応する操作を持つか** (推奨は持たない — 版の削除は BE-4 の派生物の整合を壊す)。

**この回答が左右するもの**: `plan_tab_versions` / `idea_versions` の API 露出範囲 / FE の会話画面の実装 /
BE-1 の対策が設計上どこで効くか。

[Answer]: **A で確定** (2026-08-01 ユーザー回答)。**既存の版テーブル (`idea_versions` / `plan_tab_versions`) の操作として API 化**し、「スナップショット」という別概念を作らない。版一覧の取得と「特定版を最新として複製する (復元)」を定義する。**復元は新版を作る操作**であり版番号は増える (履歴を壊さない)。
> **設計で書くこと**: プロトタイプの「削除」に対応する操作は**持たない** (版の削除は BE-4 の派生物の整合 = 企画書の `source_idea_version_id` / `source_hash` による stale 判定を壊す)。採番は 1 SQL に閉じる (BE-11。[data-model.md](../../../docs/design/data-model.md) §7.1)。

---

## CV-Q10. 企画書 8 サブタブの API 粒度と再生成の入口

**背景 (事実)**:

- 更新版プロトタイプの企画書ビューは **8 サブタブ単位のバージョン・履歴・再生成**を持つ
  (`hassan_agent_prototype_v2.html:6911-7349`)
- PoC は **タブ単位で Managed Agent (P-4) を呼び**、`plan_progress` (`total`=8) で進捗を流し、
  `plan_tab_versions` に**タブ別・独立採番**で保存する
  ([poc-conversation-flow.md](../../../docs/analysis/poc-conversation-flow.md) §1.2 / §5.2)
- **v3 は 8 タブすべてを Agent 経路 (P-4) に統一**する (PoC は service / bmc の 2 タブが直接 API。
  [llm-migration.md](../../../docs/design/llm-migration.md) §4.1 の P-4)
- `plan_tab_versions` は `source_idea_version_id` / `source_hash` を持ち、
  **元アイデアが更新されたら「最新版でないこと」を応答に含める。自動再生成はしない**
  ([data-model.md](../../../docs/design/data-model.md) §5 の派生物の無効化。BE-4)

**選択肢**:

- **A. タブ単位の REST を持つ** — `POST /plans/{plan_id}/tabs/{tab_id}/regenerate` (SSE で進捗) と
  `GET /plans/{plan_id}` (8 タブの最新版を同梱)。**会話ターン中の生成 (`generate_plan` tool) と
  同じ UseCase を共有し、入口だけ 2 つ**にする
- **B. 会話ターン経由のみ** — 再生成もユーザーが会話で依頼する (REST の再生成入口を作らない)
- **C. 企画書全体の一括生成のみ** (タブ単位の再生成を持たない)
- D. Other (please describe after [Answer]: tag below)

> 推奨: **A**。理由: ①**プロトタイプ以前に v2 が既にタブ (セクション) 単位の生成を持っている**
> (`POST /business-plans/detailed` のセクション生成。[v2-feature-inventory.md](../../../docs/analysis/v2-feature-inventory.md) §2.7)
> ため、C-16 の観点でも粒度を落とせない ②B は「1 タブだけ作り直したい」に会話ターンを 1 往復させることになり、
> LLM コストと待ち時間が増える ③**UseCase を共有すれば計測 (O-2) と安全弁の適用が入口によって変わらない**
> (`feature` は `plan.generate` で共通 — [observability.md](../../../docs/design/observability.md) §4.2)。
> **A で設計に書くこと**: 再生成が**どの版のアイデアを入力にするか**を必ず記録すること (BE-1 / `source_idea_version_id`) と、
> 8 タブの ID 値域を `entity/plan` の `PlanTabID` に 1 箇所で持つこと (DB の CHECK は付けない — G-9 / PoC 踏襲)。

**この回答が左右するもの**: 企画書 API のエンドポイント数 / SSE 中継の Route Handler の本数 ([frontend.md](../../../docs/design/frontend.md) §6.3.1) /
`generate_plan` tool の責務 (タブ全生成か、生成の依頼だけか)。

[Answer]: **A で確定** (2026-08-01 ユーザー回答)。**タブ単位の REST を持つ** — `POST /plans/{plan_id}/tabs/{tab_id}/regenerate` (SSE で進捗) と `GET /plans/{plan_id}` (8 タブの最新版を同梱)。**会話ターン中の生成 (`generate_plan` tool) と同じ UseCase を共有**し、入口だけ 2 つにする (計測 O-2 と安全弁の適用が入口によって変わらない。`feature` は `plan.generate` で共通)。
> **設計で書くこと**: 再生成が**どの版のアイデアを入力にしたか**を必ず記録する (BE-1 / `source_idea_version_id`)。8 タブの ID 値域は `entity/plan` の `PlanTabID` に 1 箇所で持つ (DB の CHECK は付けない = G-9 / PoC 踏襲)。**CV-Q1=B により、v2 の詳細版セクション生成 (7 種) もこの粒度に写像する**。

---

## CV-Q11. アイデアの更新経路と `tags` の書き込み側 (BE-10 の受け皿)

**背景 (事実)**:

- [API/idea-boards.md](../../../docs/design/API/idea-boards.md) §8.1 は `Idea.tags: string[]` を**返す**と確定し、
  **「`tags` の書き込み側は会話型 API 設計 (Task-3p) が定義する。読む側だけ実装して書く側が無い状態 (BE-10) を作らないこと」**
  と明記している。`idea_tags` テーブルは [data-model.md](../../../docs/design/data-model.md) に新設済み
- 同 §7 は「生成側の設計が確定するまで、参照系 3 本は**読み取りとスター更新のみ**とし、
  アイデアの作成・本文更新・削除のエンドポイントを追加しない」と制約を置いている
- **v2 には「マイアイデア」の登録・下書き生成 (V-3) がある** ([v2-feature-inventory.md](../../../docs/analysis/v2-feature-inventory.md) §2.5 の
  `POST /ideas/generate/my-idea` / `.../draft`)。C-16 により操作を落とせない

**選択肢**:

- **A. アイデアの更新系 REST を定義し、タグ・本文の書き込みはそこに置く** —
  `PUT /ideas/{idea_id}` (本文・タグ) / `DELETE /ideas/{idea_id}` / `POST /ideas` (マイアイデアの手動登録)。
  **LLM 生成は会話ターン経由、人手の編集は REST** と役割を分ける
- **B. タグの専用エンドポイントを別に持つ** (`PUT /ideas/{idea_id}/tags`) — 本文更新とは分ける
- **C. タグも本文も会話ターン経由でのみ更新する** (tool を追加する)
- D. Other (please describe after [Answer]: tag below)

> 推奨: **A**。理由: ①CV-Q5 の判定基準 (ユーザー操作で起動が決まるものは REST) と一致する
> ②`asset_tags` は既に**アセットの更新 API でまとめて更新する**形になっており、揃う
> ([API/assets.md](../../../docs/design/API/assets.md)) ③B は「1 リソースの更新が 2 エンドポイントに割れる」ため、
> 部分更新の競合 (どちらが後勝ちか) を別途決めることになる。
> **A で設計に書くこと**: **LLM が生成したアイデアを人手で編集したとき、`idea_versions` に版を切るか**
> (推奨: 切る。BE-4 の `source_hash` による企画書の stale 判定が効くようにする)。

**この回答が左右するもの**: [API/idea-boards.md](../../../docs/design/API/idea-boards.md) §7 の制約解除と §8.1 の BE-10 のクローズ /
v2 の `POST /ideas/generate/my-idea` 系の受け皿 (C-16) / `ideas.md` を新設するか (CV-Q2)。

[Answer]: **A で確定** (2026-08-01 ユーザー回答)。**アイデアの更新系 REST を定義する** — `PUT /ideas/{idea_id}` (本文・タグ) / `DELETE /ideas/{idea_id}` / `POST /ideas` (マイアイデアの手動登録)。**LLM 生成は会話ターン経由、人手の編集は REST** と役割を分ける。これで [API/idea-boards.md](../../../docs/design/API/idea-boards.md) §8.1 の **BE-10 (`tags` に書き込み側が無い) がクローズ**し、§7 の制約 (作成・本文更新・削除を追加しない) を解除する。
> **設計で書くこと**: **LLM が生成したアイデアを人手で編集したときは `idea_versions` に版を切る** (BE-4 の `source_hash` による企画書の stale 判定が効くようにする)。v2 の `POST /ideas/generate/my-idea` / `.../draft` (V-3) の受け皿がここになる (C-16)。

---

## CV-Q12. 持ち込み PDF のアップロード経路 (AS-Q11 の制約への回答)

**背景 (事実)**:

- 更新版プロトタイプの会話画面「持ち込みアイデア入力」が **PDF のドラッグ&ドロップ**を持つ
  (`hassan_agent_prototype_v2.html:9605-9861`)
- [API/assets.md](../../../docs/design/API/assets.md) §5 の **AS-Q11** が制約の SSOT:
  **D-AS-4 は「アップロード実装が 3 系統になり、拡張子・サイズ検証の SSOT が割れる (BE-2)」を理由に
  専用 API を却下している**ため、**4 系統目を黙って足すとその判断の根拠が崩れる**。
  既存 3 系統 = ①アセット添付 ②抽出用の未紐付けアップロード ③ナレッジファイル

**選択肢**:

- **A. ②「抽出用の未紐付けアップロード」に寄せる** — 会話画面の PDF は `POST /asset-extractions` 相当の
  既存経路でアップロードし、会話は返ってきた ID を参照する。**会話専用のアップロードを作らない**
- **B. ③ナレッジファイルに寄せる** — PDF をナレッジとして登録し、会話から参照する
- **C. 共通のアップロード基盤 (`POST /uploads`) を新設し、既存 3 系統もそこへ統合する** —
  検証の SSOT を 1 箇所にする (影響範囲は assets / knowledge にも及ぶ)
- D. Other (please describe after [Answer]: tag below)

> 推奨: **A**。理由: ①持ち込み PDF の用途は「アイデアの素材として中身を読ませる」ことであり、
> **②の抽出フロー (PDF → 構造化 JSON。P-9) と目的が同じ** ②B はナレッジ (RAG 用のチャンク化・埋め込み)
> と目的が違い、**埋め込みコストが不要な文書にまで発生する** ③C は正しい方向だが、
> **本増分の範囲を assets / knowledge の再設計にまで広げる** (第 1 リリースのスコープが膨らむ)。
> **A で設計に書くこと**: 会話から参照する際に**所有者スコープの検証をハンドラのクロージャで行う** (A-6) こと。

**この回答が左右するもの**: [API/assets.md](../../../docs/design/API/assets.md) §5 AS-Q11 のクローズと D-AS-4 の根拠の維持 /
会話ターンの入力に添付を持たせるか (`POST .../messages` のボディ形) / 抽出ジョブの完了を会話がどう待つか。

[Answer]: **A で確定** (2026-08-01 ユーザー回答)。**既存②「抽出用の未紐付けアップロード」に寄せる** — 会話画面の持ち込み PDF は `POST /asset-extractions` 相当の既存経路でアップロードし、会話は返ってきた ID を参照する。**会話専用のアップロードを作らない** ([API/assets.md](../../../docs/design/API/assets.md) §5 の AS-Q11 をクローズし、D-AS-4 の「3 系統に留める」根拠を維持する)。
> **設計で書くこと**: 会話から参照する際の**所有者スコープの検証をハンドラのクロージャで行う** (A-6 / CV-Q13=A と同じ構造)。抽出ジョブの完了を会話がどう待つか (ターン内で待つか、完了後に次ターンで参照するか) を明示する。

---

# 第 4 節: 本番観点 (A-6)

## CV-Q13. ツール引数のサーバ注入と、越境検証の表し方 (A-6)

**背景 (事実)**:

- PoC は **`deep_dive` の `asset_context` を schema にもプロンプトにも宣言せず、サーバが台帳から注入**している
  (「Agent が渡せない引数を handler が読む」3 者の非対称。
  [poc-conversation-flow.md](../../../docs/analysis/poc-conversation-flow.md) §3.3-(a)。オーケストレーター照合済み)
- PoC の `load_asset` は **`asset_id` を LLM の引数として受け取り、所有者チェックなしで参照**する
  (`08-production-gates.md` の A-6 が「本番化で最も危険な穴」として名指し)
- v3 は **所有者スコープをハンドラのクロージャに束縛**し、Runner が組み替えられない構造にする
  ([architecture.md](../../../docs/design/architecture.md) §3.8.2。束縛点は `usecase/conversation/tool_registry.go` の 1 箇所)。
  **所有者不一致は warn ログ + メトリクスに出す**
- ツール schema・ハンドラ・プロンプトの 3 者一致は `scripts/check-tool-contract.sh` が検査する (同 §3.8.4)

**選択肢**:

- **A. サーバ注入を廃し、「台帳から読む値」はハンドラのクロージャが直接読む** —
  ツール引数は schema に宣言したものだけ。`asset_context` のような文脈は**引数ではなくハンドラの内部で構築**する。
  **3 者一致検査が常に成立する**
- **B. PoC 踏襲 (サーバが引数を注入する)** — ただし schema にも宣言し、Agent からの値はサーバ値で上書きする
- **C. schema に宣言し、Agent に渡させる** (サーバは注入しない)
- D. Other (please describe after [Answer]: tag below)

> 推奨: **A**。理由: ①**注入は「引数の形をした内部状態」**であり、schema に載せる意味がない
> (Agent が値を決められない) ②B は「Agent の値が黙って捨てられる」形になり、**BE-8 (schema と handler の乖離で
> 機能が黙って死ぬ) の温床**になる ③C は LLM に台帳の中身を渡してから返させることになり、
> **改ざんされた値がハンドラに入る余地**を作る (A-6)。
> **A で設計に書くこと**: LLM が渡す ID (`asset_id` / `idea_num` など) は**すべて「所有者条件付きクエリの入力」
> として扱い、存在確認を所有権の検証に使わない** (A-4)。**該当なしの応答は「見つからない」で統一**し、
> 他人のリソースの存在を推測させない。

**この回答が左右するもの**: 9 tools の schema 定義 / `check-tool-contract.sh` の検査項目 (3 者一致の対象) /
[testing.md](../../../docs/design/testing.md) の「全 tool のテナント越境テスト」の書き方 / A-6 への設計上の回答。

[Answer]: **A で確定** (2026-08-01 ユーザー回答)。**サーバ注入を廃し、「台帳から読む値」はハンドラのクロージャが直接読む**。ツール引数は **schema に宣言したものだけ**とし、`asset_context` のような文脈は引数ではなくハンドラ内部で構築する (**3 者一致検査 `scripts/check-tool-contract.sh` が常に成立する**)。
> **設計で書くこと**: LLM が渡す ID (`asset_id` / `idea_num` など) は**すべて「所有者条件付きクエリの入力」として扱い、存在確認を所有権の検証に使わない** (A-4)。**該当なしの応答は「見つからない」で統一**し、他人のリソースの存在を推測させない。所有者不一致は warn ログ + メトリクスに出す ([architecture.md](../../../docs/design/architecture.md) §3.8.2)。

---

# 質問にしない既定採用 (回答不要。異論があれば指摘してください)

設計判断だが**推奨案が明確で分岐が実質 1 つ**のため、質問にせず requirements-conversation.md に
「既定採用」として書くもの:

| # | 項目 | 既定 | 根拠 |
|---|---|---|---|
| 1 | **ステージ (`stage`) の値域と SSOT** | **PoC の 5 値** (`asset` / `market` / `match` / `ideation` / `plan_draft`) を `entity/conversation` の純粋関数で台帳から導出する。**テーマ・ボードが表示用に畳む場合の写像も本増分が定義する** | [data-model.md](../../../docs/design/data-model.md) §4.4 が既に「PoC の `stage` 導出と同じ規則」と書いている。[API/themes.md](../../../docs/design/API/themes.md) TH-Q3 / [API/idea-boards.md](../../../docs/design/API/idea-boards.md) IB-Q7 の委譲先はここ |
| 2 | **D-6 (Agent 再発行) とデプロイの順序** | **ツールの追加は後方互換** (新ツールは新 Agent version だけが呼ぶ)、**削除は 2 段階** (先に Agent 定義から外し、次のリリースでハンドラを消す)。手順とハッシュ差分判定の SSOT は [operations.md](../../../docs/design/operations.md) §5.2 | 「コードだけデプロイして Agent 再発行を忘れる」が本番障害になる (D-6)。順序を決めておかないと BE-8 / BE-10 が本番で発火する |
| 3 | **O-2 の計測** | 会話経路の LLM 呼び出しはすべて `gateway/anthropic` を通し、ターン集計は `service/conversation.Runner` が持つ。**個別ツールに計測コードを書かない** | [observability.md](../../../docs/design/observability.md) O-C / [architecture.md](../../../docs/design/architecture.md) §3.8.3 で確定済み。本増分は `feature` 値 (`conversation.turn` / `plan.generate` など) を列挙するだけ |
| 4 | **O-4 の失敗表現** | `max_tokens` 切り詰め・JSON パース失敗・ツール引数の不整合は**構造化エラーとして Agent に返し、同時に warn + メトリクスに出す**。PoC の `research_market` のような「パース失敗を成功として返すフォールバック」は作らない | [poc-conversation-flow.md](../../../docs/analysis/poc-conversation-flow.md) §4.3 (PoC はパース失敗時に検索結果のタイトルを領域名にして `ok=true` を返す) / [observability.md](../../../docs/design/observability.md) §4.3 の 5 分類 |
| 5 | **v2 のアイデア評価 (V-2) と PoC (P-5) の評価軸の統合** | **調査してから決める** (LM-R6 が「調査の実施主体は本増分」と指定)。要件では「両者の評価軸を突き合わせ、v3 の 1 本に統合する」ことと、**どちらかを黙って落とさない**ことを条件にする | [llm-migration.md](../../../docs/design/llm-migration.md) §9.2 の LM-R6 |
| 6 | **V-4 / V-5 (アイデアの Web 検索・市場規模 CAGR リサーチ) の扱い** | **本増分で `research_market` (P-8) に吸収できるかを判定する**。吸収する場合は [llm-migration.md](../../../docs/design/llm-migration.md) §7.1 の M-7 が消滅するため、同書への是正要求として起票する | 同 §9.2 の LM-R8 (推測で先に畳まない) |

---

# 参照した一次ソース

| 文書 | 使った箇所 |
|---|---|
| [plan.md](plan.md) | Task-3p のスコープ (①〜⑥) |
| [llm-migration.md](../../../docs/design/llm-migration.md) | §4.1 (P-1〜P-13) / §4.2 (V-1〜V-17) / §6.1 (prompts レイアウト) / §6.2 (散在 5 件) / §6.3 (D-6 の 3 本) / §9.2 (LM-R6 / LM-R8) |
| [poc-conversation-flow.md](../../../docs/analysis/poc-conversation-flow.md) | §1 (SSE 9 種) / §2 (台帳 13 フィールド) / §3 (9 tools の 3 者整合) / §4 (エラー) / §5 (永続化・再開) / §6 (ターンの処理順序) |
| [v2-feature-inventory.md](../../../docs/analysis/v2-feature-inventory.md) | §2.5 (アイデア 13 本) / §2.7 (企画書 18 本) / §5 (対象外の #9 / #10) |
| [architecture.md](../../../docs/design/architecture.md) | D-C / D-D / §3.8.1〜§3.8.5 / §7 (会話 1 ターンの配置例) |
| [data-model.md](../../../docs/design/data-model.md) | §4.5 (会話 4 テーブル) / §4.11 (台帳の契約) / DM-11〜DM-13 / §8.4 の仮定 4・6 |
| [API/README.md](../../../docs/design/API/README.md) | §0 (対象外宣言) / §1.3 (非同期ジョブ J-1〜J-7) / §2 (共通規約) / §3 (総覧) |
| [API/idea-boards.md](../../../docs/design/API/idea-boards.md) | §6.1 (IB-Q7 / IB-Q11) / §7 (参照系の配置理由と制約) / §8.1 (`tags` の書き込み側) |
| [API/assets.md](../../../docs/design/API/assets.md) | §5 (AS-Q11) / D-AS-4 |
| [frontend.md](../../../docs/design/frontend.md) | §6.2 (S-1〜S-9) / §6.3.1 (中継の許可リスト) / §11.1 / §16.1 (FE-Q1 / FE-Q2 / FE-Q5) |
| [observability.md](../../../docs/design/observability.md) | O-C / O-E / §4.2 / §4.3 / §4.4 (安全弁) |
