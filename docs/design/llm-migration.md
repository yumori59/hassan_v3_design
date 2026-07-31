# LLM 機能の移行設計 (Dify 廃止 / 実装形態・モデル・切替順序)

> 本書が回答する本番観点: **D-6** (Agent ライフサイクルの**対象特定**。手順の SSOT は
> [operations.md](operations.md) §5.2) / **D-7** (機能単位の移送 = RL-4 の中身) /
> **O-2** (計測対象となる LLM 経路の索引) / **O-3** (モデル選定がコストに直結する側) /
> **A-6** (経路を減らすことで越境面を縮める判断) / **D-1・D-5** (モデル設定・API キーの持ち方 → 参照のみ)
> 対応 AC: **AC-3.8** (主) / **AC-2.1**・**AC-3.3**・**AC-3.5** (参照)
>
> 前提とする事実 (出典はそちらに集約。本書は表とリンクで参照する):
> [dify-inventory.md](../analysis/dify-inventory.md) /
> [v2-llm-inventory.md](../analysis/v2-llm-inventory.md) /
> [poc-prompt-inventory.md](../analysis/poc-prompt-inventory.md)
>
> 本書が **SSOT として持つもの**: ①機能ごとの v3 実装形態 (Managed Agent / 直接 API / 廃止)
> ②用途カテゴリ別の使用モデルと決め方 ③プロンプト資産の置き場と 1 本化 ④移行順序と品質確認方法。
> 本書が **持たないもの** (再定義しない): LLM 呼び出しレコードのフィールド
> ([observability.md](observability.md) §4.2) / 計測点の層 ([architecture.md](architecture.md) §3.8.3) /
> Agent 発行のデプロイ手順 ([operations.md](operations.md) §5.2) / 安全弁のしきい値
> ([observability.md](observability.md) §4.4) / 層の責務と依存規則 ([architecture.md](architecture.md) §3)。

## AC-3.8 の 4 要素と本書の対応

| AC-3.8 の要素 | 本書の節 |
|---|---|
| 機能ごとの v3 での実装形態 (Managed Agent / 直接 LLM API / 廃止) | **§4** (判定基準は §3) |
| 使用モデルの見直し結果 | **§5** |
| 機能単位の切替順序 | **§7** |
| 切替時の品質確認方法 | **§8** |

---

## 1. 現状 (v2 / PoC)

> 本節が回答する ID: なし (事実の整理)。出典は各分析文書に集約し、本節では**転記せず参照する**。

### 1.1 「Dify 廃止」の実体

| # | 事実 | 出典 |
|---|---|---|
| 1 | `hassan-v2-backend/dify` は **dead code** (非 dify コードからの import ゼロ・grep 参照はコメント 2 件のみ)。import 解決レベルでも裏取り済み | [dify-inventory.md](../analysis/dify-inventory.md) §1 / [v2-llm-inventory.md](../analysis/v2-llm-inventory.md) §8 |
| 2 | Dify の 8 機能はすべて**現行経路が判明している** (6 機能は v2 の `hassan-v2-backend/llm` へ移行済み、`extract_json` は決定論的 Go コードへ、`client.go` は配管) | [v2-llm-inventory.md](../analysis/v2-llm-inventory.md) §1 |
| 3 | 残存しているのは**設定と資産のみ**: `DIFY_*` env 9 個、ワークフロー YAML (prod 7 本 / dev 8 本)、`Dify` を名に含むプロンプト関数 8 個 + テンプレート 4 本 (**4 本は現役で参照されている**) | [dify-inventory.md](../analysis/dify-inventory.md) §2 / [v2-llm-inventory.md](../analysis/v2-llm-inventory.md) §5-3 |

**したがって本書の作業対象は「Dify からの移行」ではなく、①v2 の現行 LLM 機能の v3 への移植
②PoC の LLM 機能の v3 への移植 ③どちらにも移さないものの廃止確定**である
([dify-inventory.md](../analysis/dify-inventory.md) §0 の結論と一致)。
Dify YAML 内のモデル (GPT-4o 系) は**見直しの対象ではない** — 見直す対象は現行 v2 が実際に選んでいるモデル
(同 §4 の含意)。

### 1.2 v2 の現行 LLM 機能 (移植元)

**22 経路 / 4 プロバイダ / 実効モデル 10 種以上**。機能単位に束ねると 17 件で、内訳と実効モデルの
完全な表は [v2-llm-inventory.md](../analysis/v2-llm-inventory.md) §2 が SSOT。
本書は §4.2 の移行表でこの 17 件に 1 行ずつ回答する。

移植方針を左右する v2 側の構造的事実 (すべて出典は同文書):

| # | 事実 | v3 への含意 | 出典 |
|---|---|---|---|
| a | **usage を詰めるのは OpenAI 実装のみ**。主系の Gemini / Claude / Exa は詰めていない。ストリーム経路は原理的に取得不能 | LLM 抽象は再設計が必須 (D-B''。§5.2) | 同 §7 |
| b | **`stop_reason` が公開型に存在しない** | BE-6 (切り詰め検出) が現行抽象では実装不可能 | 同 §7 |
| c | **未知モデルは `default` で暗黙に OpenAI へルーティング** | 未知モデルはエラーにする (§5.2) | 同 §4 |
| d | **用途別許可リストと既定値が不整合** (think 既定の `gemini-3.1-pro-preview` が `ResearchModels` に無い)。エラーメッセージ内に手書きモデル一覧が別に存在 | 許可リスト・既定値・fallback を同一定義から導く (§5.2) | 同 §3-2 / §3-3 |
| e | **`buildFallbacks` 相当が 4 パッケージ + 別方式 1 系統に重複** | fallback をプロファイル定義 1 箇所に集約 (§5.2) | 同 §3-4 |
| f | **「env で上書き可能」と書かれた設定 3 つが DI で届いていない**。`DEFAULT_IDEA_THINK_FALLBACK_MODEL` も未配線 | 設定は `config` を単一の入口にする ([architecture.md](architecture.md) §3.9②) | 同 §2-1 |
| g | **部分指定の config が空モデル名を通す** (カスタムリサーチ)。空文字列が fallback 列に渡り 1 本目が必ず失敗する | プロファイルのオーバーレイは**全フィールド必須**にする (§5.2) | 同 §2-2 |
| h | **ストリーム中のフォールバックが先頭から再送**し、送信済みチャンクがクライアントに残る | ストリーム開始後のフォールバックを禁止 (§5.2) | 同 §6-3 |
| i | **プロンプトの system / user の分け方が統一されていない** (`idea` だけフラット + 接尾辞方式)。英語版は 130 本中 16 本のみで**暗黙フォールバック**する | 置き場と言語の規約を先に固定する (§6.1) | 同 §5-1 / §5-2 |

### 1.3 PoC の LLM 経路 (移植元)

**プロンプト 26 ファイル + Go 埋め込み 7 箇所**。実行形態・MaxTokens・呼び出し経路の完全な表は
[poc-prompt-inventory.md](../analysis/poc-prompt-inventory.md) §1 が SSOT。

| # | 事実 | v3 への含意 | 出典 |
|---|---|---|---|
| a | **Anthropic 側の Agent リソースに載っており再発行が必要なのは 4 ファイルのみ** (diverge / post-diverge chat / plan / conversational orchestrator) | **v3 の D-6 の対象は 3 本** — post-diverge chat を orchestrator に統合するユーザー決定 (2026-07-31 の LM-Q1) により PoC の 4 本から 1 本減る (§6.3) | 同 §2 |
| b | 上記以外はすべて**直接 API messages 呼び出し**でコードデプロイのみで反映される | 移行の大半は Agent 運用を伴わない | 同 §2 |
| c | **重複・散在が 5 件** (発散 4 軸の 2 系統分裂 / research_market 2 箇所 / 情報源ルール二重実装 / 評価 3 実装 / 企画書 3 方式) | §6.2 で 1 本化する | 同 §3 |
| d | **未配線資産**: `internal/agent/diverge/` の Service 一式 + `prompts/diverge/` 配下 9 ファイル、`prompts/research_system.md` | §4.3 で廃止確定 | 同 §4 |
| e | **FE 呼び出しの無いレガシー経路**: `/api/evaluate` / `/api/deepdive` (ルーティング登録はある) | 同上 | 同 §4 |
| f | プロンプト本文が **Go のインライン文字列**として 7 箇所にある (match_functions / research_market ×2 / themes_tags / evaluate (1 行に 2 プロンプト) / deepdive / **`internal/exaresearch/search_guidance.go`**) | ファイル化を規約で強制 (§6.1)。**`search_guidance` は P-12 として移植対象** (廃止ではない) | 同 §1.2 |

### 1.4 v3 側で既に確定している LLM 経路 (整合を取る相手)

| v3 の経路 | 実装形態の既定状況 | 出典 |
|---|---|---|
| `POST /asset-extractions` (アセット AI 抽出) | LLM 呼び出しは `gateway/` 経由、ドメインロジックは `service/asset.Extractor` (D-AS-10) | [API/assets.md](API/assets.md) §3 |
| `POST /knowledge-threads/{thread_id}/messages` (RAG 回答) | Agent か直接 API かは **KN-Q2 で未決** → **本書 §4.1 で決める** (**直接 API**)。**第 1 リリースに含める** (2026-07-31 の LM-Q6) | [API/knowledge.md](API/knowledge.md) §6 |
| `POST /knowledge-files` (埋め込み生成) | 直接 API。計測対象として明示済み。**第 1 リリースに含める**。ただし**埋め込みプロバイダの選定は別トピックの設計**が担う (§9.1 の LM-Q6) | [API/knowledge.md](API/knowledge.md) §5 |
| テーマ管理 | **LLM 経路を持たない**と確定済み | [API/themes.md](API/themes.md) §5 |
| 会話型アイデア創出 (発散・9 tools・企画書) | API 設計は**別途起草** (本ディレクトリ対象外)。**2026-07-31 の LM-Q1 / LM-Q2 により、P-3 の統合と v2 機能 (V-1〜V-3 / V-6) の統合設計もこのタスクが担う** (着手は認証系 Task-3i の後) | [API/README.md](API/README.md) §0 |
| `GET /companies/genai` (URL から企業情報) | LLM 経路として認識済み。移行先の判定は**本書**が担う | [API/settings.md](API/settings.md) §5 |

**計測対象の索引との関係**: [API/README.md](API/README.md) §4 は「本ディレクトリ内の LLM 経路は 3 本」と
特定している。本書 §4 の表は**それ以外の経路 (会話型 + v2 移植分) を含む全体の索引**であり、
数を上書きするものではない。

---

## 2. 設計判断

> 本節が回答する ID: **D-6, D-7, O-2, O-3, A-6** / 対応 AC: **AC-3.8**

| # | 論点 | 採用案 | 却下案と理由 |
|---|---|---|---|
| **LM-A** | 実装形態の判定方法 | **[architecture.md](architecture.md) の D-B' の 3 問を、機械的に適用できる 5 段の手順に具体化する** (§3)。**「多段でも段の順序と回数が Go コードで固定されているものは Agent にしない」**「**会話履歴を持つだけの chat は Agent にしない**」の 2 つの適用ルールを明記する | (a) 「多段処理 = Agent」とする: v2 のカスタムリサーチ・Web リサーチ 5 系統・リサーチシートがすべて Agent 化され、Agent が 10 本以上になる。Agent は `Tools` 全置換 (BE-9)・schema 乖離 (BE-8)・ID 変更で進行中セッションが切れるという固有の事故面を持ち、これを固定パイプラインに持ち込む理由がない。(b) 「対話 UI を持つ = Agent」とする: v2 の企画書チャット・v3 のナレッジ RAG が Agent になるが、どちらも 1 リクエスト = 1 LLM 呼び出しで、次の呼び出し内容を決めるのは**ユーザーの次の発話**であり LLM ではない。(c) 判定を実装者に任せる: 同じ性質の処理が機能ごとに別形態になり、計測・モデル設定・プロンプト置き場がすべて分岐する (DR-5) |
| **LM-B** | 廃止の判定方法 | **3 条件のいずれかを満たすものを廃止とし、§4.3 に根拠付きで列挙する**: ①非テストコードからの呼び出しが無い (未配線) ②後継実装が存在し FE からの呼び出しが無い ③LLM を使わずに決定論的コードで実現できている | (a) 「PoC / v2 にあるものは全部移植する」: 未配線資産 (`internal/agent/diverge/` 一式) と旧実装 (評価 3 実装・企画書 3 方式) がそのまま v3 に持ち込まれ、BE-2 の散在を移植コストごと引き継ぐ。(b) 廃止を暗黙にする (表に載せない): 移植漏れと廃止の区別が付かず、後から「移植したつもりの機能が無い」形で発覚する (DR-2 と同型の無言の省略) |
| **LM-C** | モデル名の SSOT | **`config` に「LLM プロファイル表」を 1 つ置き、`feature` 識別子をキーにする**。1 行 = {provider, model, fallback[], max_tokens, timeout, languages}。**許可リスト・既定値・fallback 列をこの 1 表から導出する** ([architecture.md](architecture.md) §3.9② の「設定値の SSOT は `config`」の具体化)。**`feature` 識別子は [observability.md](observability.md) §4.2 の `feature` と同一文字列**にする | (a) v2 方式 (モデル列挙 + 用途別許可リスト map + パッケージ別 fallback + エラーメッセージ内の手書き一覧): 実測で 4 系統に分裂し許可リストと既定値が不整合になった (§1.2 の d / e)。(b) env var だけで持つ: v2 は「env で上書き可能」と書かれた 3 設定が DI に届かず、コード内定数が実効値だった (同 f)。どの値が効いているかがコードから読めない。(c) プロファイルを機能実装側に持たせる: 計測キーと設定キーが別物になり、「どの機能がどのモデルでいくら使ったか」の突き合わせに変換表が必要になる |
| **LM-D** | プロバイダ方針 | **Anthropic を主系とする**。例外は **第 1 リリース時点で 3 つ** (2026-07-31 確定): **Web 検索 = Exa** (`gateway/exa`)、**画像生成 = Gemini** (Anthropic に該当機能が無いため。**機能の維持はユーザー決定済み** — §9.1 の LM-Q3)、**RAG の埋め込み = 未選定のプロバイダ** (**Anthropic は埋め込みモデルを提供していない**ため 3 番目が必然。**RAG は第 1 リリースに含める**が、**プロバイダの確定は別トピックの設計に委ねる** — 2026-07-31 のユーザー確認。§9.1 の LM-Q6 が申し送り事項の SSOT) | (a) v2 と同じ 4 プロバイダ・22 モデルを維持: プロバイダ数がそのまま整合性コストになる (§1.2 の a〜e はすべてマルチプロバイダ由来)。Managed Agents が Anthropic 固定 (C-2) なので、直接 API を別プロバイダに置くと単価表・切り詰め挙動・プロンプト規約が 2 系統になる。(b) OpenAI を主系にする: Agent 経路が Anthropic である以上、主系を分ける利点が無い。(c) 検索も Anthropic の web_search に寄せる: PoC は Exa を実使用しており (`claude_managed_agents/internal/exaresearch/exa.go`)、v2 も `exa-search` を fallback に持つ。検索品質の比較データが無いまま実績のある経路を捨てる根拠がない |
| **LM-E** | fallback の方針 | **プロファイルの `fallback` 配列 1 箇所に集約する。ストリーミング開始後のフォールバックは行わない** (開始後の失敗は SSE の `error` イベントとして表現する。[API/README.md](API/README.md) D-API-12 と同じ扱い) | (a) v2 方式 (パッケージごとに `buildFallbacks`): 5 系統に重複し、空モデル名が渡ると 1 本目が必ず失敗する経路が残った (§1.2 の e / g)。(b) ストリーム中も次モデルで再送する (v2 現状): 送信済みチャンクがクライアントに残り、同一回答が二重に見える (同 h)。(c) fallback を持たない: 単一モデルの一時障害で機能が全停止する |
| **LM-F** | プロンプト資産の置き場 | **`prompts/<domain>/` にファイルとして置き、構築ロジックは `service/<domain>/` に置く** ([architecture.md](architecture.md) の D-E をそのまま適用)。**`prompts/` 外に長いプロンプト文字列リテラルを置くことを CI で禁止する** (§6.1) | (a) PoC 方式 (Go インライン文字列 7 箇所と `.md` ファイルの併存): D-6 の 3 者一致検査が走査すべき対象が散り、検査が漏れる。差分レビューでプロンプト変更が Go の diff に埋まる。(b) v2 方式 (`prompt/` 配下だが system/user の分け方が機能ごとに違う): 取得関数がパスを直書きしており (`hassan-v2-backend/prompt/template.go`)、規約が読み取れない (§1.2 の i) |
| **LM-G** | 移行の単位と順序 | **「共通基盤 → PoC 由来 (第 1 リリース) → v2 由来 (併用期間・ドメイン単位)」の 3 段**とし、[operations.md](operations.md) §6.1 の RL-1 / RL-3 / RL-4 に対応付ける (§7) | (a) 機能単位で v2 / PoC を混ぜて進める: [operations.md](operations.md) §6.0 の「切替単位はドメイン」に反し、同一ドメインが両系で同時更新される。(b) 共通基盤を後回しにして機能から作る: 各機能が独自に SDK を呼ぶ形が先に定着し、O-2 の単一関門 (gateway) が後付けになる — v2 で実際にそうなった (計測が 1 経路のみ) |
| **LM-H** | 品質確認の方法 | **切替前に現行系の出力を凍結し、ブラインド A/B + 機械検査 + 切替後 7 日の運用監視の 3 段で判定する** (§8)。合否は数値で定義する | (a) 目視確認のみ: 判定者・件数・合格条件が無いため「劣化していない」が検証不能な主張になる (DR-5)。(b) 機械検査のみ (スキーマ適合率): 「JSON は正しいが内容が薄い」劣化を検出できない。LLM 出力の主要な劣化形はこちら。(c) 本番トラフィックのシャドー実行で比較: 2 系統に同一入力を流すため LLM コストが二重になり、v2 側にも改修が必要になる (C-13 により v2 に手を入れない方針と矛盾する) |
| **LM-I** | 言語対応 | **暗黙フォールバックを実装しない**。プロファイルの `languages` に対応言語を列挙し、テンプレート取得は (用途, 言語) の組が無ければ**エラー**にする。**v3 新規機能は日本語のみで開始**し、v2 から移植する機能は既存の英語版がある用途のみ `[ja, en]` と宣言する | (a) v2 方式 (`.en` が無ければ日本語版に暗黙フォールバック): 130 本中 16 本しか英語版が無く、英語リクエストで日本語が返る経路が 114 本ある (§1.2 の i)。「英語対応済み」という誤った前提が API 仕様に流れる。(b) 全用途の英語版を最初から用意する: 移植対象が 2 倍になり、要件化されていない対応に工数が乗る |
| **LM-J** | Dify ワークフロー YAML の扱い | **v3 の移植では参照しない**。移植元は v2 の現行実装 (`hassan-v2-backend/prompt` + `usecase/*/*_llm.go`) とする | (a) YAML からプロンプト本文を抽出して移植する: v2 の現行実装が既に置き換わっており (§1.1 の 2)、YAML は**動いていないプロンプト**である。死んでいるコードを手本にしない。(b) YAML と現行実装の差分を取って「移植で落ちた指示」を復元する: 差分調査 (`dify/workflow/prod/research-chat.yml` は 3467 行) の工数に対し、現行 v2 が本番稼働している事実が品質の裏付けになっている。**ただし v3 移植後の品質が現行 v2 を下回った場合の調査先としては残す** (§9 の LM-R2) |

---

## 3. 実装形態の判定手順 (機械的に適用する)

> 本節が回答する ID: **A-6** (Agent 数を減らすことが越境面を減らす) / 対応 AC: **AC-3.8** (1 要素目の前提)

**[templates/backend-repo/CLAUDE.md.tmpl](../../templates/backend-repo/CLAUDE.md.tmpl) の「LLM の使い分け」表と
[architecture.md](architecture.md) の D-B' が判定線の SSOT**。本節はそれを**適用手順に具体化するだけ**で、
判定線を変えない。

```
Q0. 廃止判定 (LM-B の 3 条件のいずれかを満たすか)
     ① 非テストコードからの呼び出しが無い (未配線)
     ② 後継実装が存在し、FE からの呼び出しが無い
     ③ LLM なしで決定論的コードにより実現できている
    → いずれか Yes なら【廃止】。§4.3 に根拠 (パス) 付きで記載する
     ↓ No
Q1. LLM が「ツールを呼ぶ」必要があるか
     = LLM 自身が、どの外部データ (DB / 検索 / 他ドメイン) をいつ読むかを決める必要があるか
    → Yes なら【Managed Agent】
     ↓ No
Q2. LLM が「任意の順序・回数」で処理を組み合わせる必要があるか
     ※ Go コードが段の順序と回数を固定できるなら No (= 複数の単発呼び出しであり、複数ターンではない)
     ※ Go コードが有限個の実装済み分岐から 1 つを選ぶだけなら No (分類 → 分岐は単発の分類)
    → Yes なら【Managed Agent】
     ↓ No
Q3. LLM の出力が、次に何をするかを決めるか
     ※ 次の呼び出し内容を決めるのがユーザーの次の発話なら No (会話履歴を持つだけの chat は Agent ではない)
    → Yes なら【Managed Agent】
     ↓ No
Q4.【直接 LLM API】(`gateway/<プロバイダ>` 経由。SDK を各所で直叩きしない)
```

**Q1〜Q3 が「1 つでも Yes なら Agent」である点は D-B' と同一**。本節が付け足したのは
**Yes / No の読み方 3 つ** (※ の行) だけである。この 3 つを書く理由:

| ※ | 誤判定すると起きること | 実例 (出典) |
|---|---|---|
| 固定パイプラインは「複数ターン」ではない | v2 の多段処理 5 系統 (カスタムリサーチ / 企画書詳細 Web リサーチ / リサーチシート Web リサーチ / アイデア市場規模 Web リサーチ / 企画書ブラッシュアップ) がすべて Agent 化され、D-6 の再発行対象が 3 本から 8 本以上に増える | 段構成は Go に固定されている: `hassan-v2-backend/usecase/research/custom_research_stream.go` (planning → 反復 → 最終レポート。[v2-llm-inventory.md](../analysis/v2-llm-inventory.md) §1-1) |
| 分類 → 分岐は「自律的な判断」ではない | リサーチシートのアクション分類が Agent になり、分岐先 (テーブル作成 / 列追加 / …) の実装が Agent の tool として Anthropic 側リソースに紐付く | `hassan-v2-backend/usecase/research_sheet/action_classifier.go` (分類は単発の LLM 呼び出し、分岐は Go の switch) |
| 会話履歴を持つ chat は Agent ではない | v2 の企画書チャットと v3 のナレッジ RAG (KN-Q2) が Agent になり、**ツールを 1 つも持たない Agent** が 2 本増える | `hassan-v2-backend/usecase/business_plan/business_plan_chat.go` / [API/knowledge.md](API/knowledge.md) §6 KN-Q2 |

**A-6 との関係**: Agent は「LLM がツール引数を決める」経路であり、越境の検証点
([architecture.md](architecture.md) §3.8.2) を必要とする。直接 API は入力を Go が確定させるため、
**Agent を必要以上に増やさないこと自体がテナント越境面の縮小になる**。

---

## 4. 機能別の移行表 (本書の中核)

> 本節が回答する ID: **O-2** (計測対象経路の索引)・**D-6** (Agent 再発行対象の特定)・**A-6** /
> 対応 AC: **AC-3.8** (1 要素目)
>
> 「見直し後のモデル」列は §5.1 の用途カテゴリ ID を指す (モデル名を各行に書くと BE-2 の散在になるため、
> **本表はカテゴリを指し、モデル名は §5.1 の 1 表のみが持つ**)。
> 「優先度」列: **1 = 第 1 リリース (RL-3 まで) / 2 = 併用期間の前半 / 3 = 併用期間の後半**
> (段階の定義は [operations.md](operations.md) §6.1)。**2026-07-31 のユーザー回答で値が 1 つ加わった**:
> **「統合先に従う」= 独立機能として移植せず、統合先の機能と同時に作る** (LM-Q2。移送の段を持たない)。
> **RAG (N-1 / N-2) の優先度は 1** (第 1 リリースに含める。**埋め込みプロバイダの選定だけが別トピックの設計** — LM-Q6)。
>
> **本表の集計 (回答反映後)**: **Managed Agent 3** (P-1 / P-2 / P-4) / **直接 API 19**
> (PoC 7 + v3 新規 2 + v2 移送 10) / **統合により独立移植しない 6** (P-3 + V-1 / V-2 / V-3 / V-6 / V-12) /
> **廃止 12** (§4.3 = 機能の廃止 7 + 資産・命名の整理 5) / **Exa のみの経路 1** (P-12)。
> **数え方**: 「直接 API」は実装形態欄が直接 API の行 (吸収先が別機能でも移送作業があるものを含む)。
> 統合・廃止の行は含めない。

### 4.1 PoC 由来 (第 1 リリースの中核)

| # | 機能 | 現状の経路 (出典) | v3 の実装形態 | 採用理由 (§3 の判定) | モデル | 優先度 |
|---|---|---|---|---|---|---|
| P-1 | 会話型オーケストレーター (5 ステップ・9 custom tool) | Managed Agent (`ORCHESTRATOR_AGENT_ID`)。`claude_managed_agents/prompts/conversational_orchestrator_system.md` | **Managed Agent** (**D-6 の再発行対象**)。**P-3 (発散後チャット) を統合する** (2026-07-31 の LM-Q1) | Q1=Yes (LLM が 9 tool の呼び出しを決める) | **C-1** | 1 |
| P-2 | アイデア発散 (domain / trend / usage / spec の 4 軸) | Managed Agent (`DIVERGE_AGENT_ID`) + raw 経路。`claude_managed_agents/prompts/idea_diverge_system.md` | **Managed Agent** (**再発行対象**) | Q1=Yes (発散中に検索・アセット参照を行う)。**未配線の自前ツールループ版は廃止** (§4.3 の X-5) | **C-1** | 1 |
| P-3 | 発散後チャット (発散済みアイデアの参照アシスタント) | Managed Agent (`CHAT_AGENT_ID`)。`claude_managed_agents/prompts/post_diverge_chat_system.md` | **P-1 へ統合** (**独立 Agent としては作らない**。2026-07-31 のユーザー決定 = §9.1 の LM-Q1)。**プロンプト本文は `prompts/conversation/orchestrator.md` に取り込み、`CHAT_AGENT_ID` 相当の Agent は発行しない** → **D-6 の再発行対象から外れる** (§6.3) | Q1=Yes (アイデア参照ツールを使う) だが、**同じツール群を P-1 が既に持つため別 Agent にする必要がない**。統合により Agent ID が 1 本減り、越境の検証点 (A-6) と `Tools` 全置換の事故面 (BE-9) も 1 本分減る | **C-1** (P-1 と同一) | 1 |
| P-4 | 企画書生成 (タブ単位) | Managed Agent (`PLAN_AGENT_ID`) で 6 タブ / service・bmc の 2 タブは直接 API。`claude_managed_agents/cmd/devui/idea_plan_managed.go` | **Managed Agent** (**再発行対象**)。**8 タブすべてを Agent 経路に統一する** | Q1=Yes (タブ生成中に市場調査・深掘りの結果を参照する)。**2 タブだけ別経路にする理由が実装上の経緯しかなく、計測とプロンプト管理が 2 系統になる** | **C-2** | 1 |
| P-5 | アイデア評価 (1 件のリッチ評価) | 直接 API。`claude_managed_agents/prompts/idea_evaluate_system.md` (MaxTokens 8192・切り詰め検出あり) | **直接 API** | Q1〜Q3=No (入力 1 件 → JSON 1 オブジェクト) | **C-2** | 1 |
| P-6 | 深掘り 6 パターン (信頼性 / 競合 / モメンタム / 需要 / 反証 / 問題構造) | 直接 API。`claude_managed_agents/prompts/conversational/deepdive_credibility.md` ほか 5 本 | **直接 API** (会話の `deep_dive` tool のハンドラ内から呼ぶ) | Q1〜Q3=No (パターンは Go が選び、1 回の JSON 出力で完結) | **C-2** | 1 |
| P-7 | 機能 × 市場ペアのスコアリング (`match_functions`) | 直接 API。プロンプトは **Go インライン** (`claude_managed_agents/cmd/devui/conversation_tools_matching.go`) | **直接 API** + **プロンプトをファイル化** (§6.1) | Q1〜Q3=No | **C-3** | 1 |
| P-8 | 市場調査の候補領域抽出 (`research_market`。domain / trend) | 直接 API + Exa。プロンプトは Go インライン 2 箇所 (`claude_managed_agents/cmd/devui/conversation_tools_research.go`) | **直接 API + `gateway/exa`**。**2 箇所を 1 本化** (§6.2 の 2) | Q1〜Q3=No (検索は Go が実行し、LLM は抽出のみ) | **C-3** + **C-5** | 1 |
| P-9 | アセット抽出 (PDF / URL) | 直接 API。`claude_managed_agents/prompts/asset_extract_system.md` (MaxTokens 16384) | **直接 API** (v3 の `POST /asset-extractions`。[API/assets.md](API/assets.md) D-AS-10 と一致) | Q1〜Q3=No (入力が確定した文書 → 構造化 JSON) | **C-2** | 1 |
| P-10 | 特許情報の Web 検索フォールバック抽出 | 直接 API + Web 検索。`claude_managed_agents/prompts/asset_extract_patent_fallback_system.md` | **直接 API + `gateway/exa`** | Q1〜Q3=No (PDF 失敗時に Go が 2 段目を起動する固定手順) | **C-3** + **C-5** | 1 |
| P-11 | 重複アセット候補のグルーピング判定 | 直接 API。`claude_managed_agents/prompts/asset_merge_system.md` (MaxTokens 2048) | **直接 API** | Q1〜Q3=No (小さな JSON 判定) | **C-3** | 1 |
| P-12 | Exa 検索の情報源優先度方針 | Exa API の `systemPrompt` フィールド (**Anthropic 呼び出しではない**)。`claude_managed_agents/internal/exaresearch/search_guidance.go` | **`gateway/exa` の検索パラメータとして移植**。**情報源ルールの文言はこちらを正として 1 本化** (§6.2 の 3) | LLM 呼び出しではないため §3 の対象外。**ただし O-2 の計測対象には含める** (課金を伴う外部 API 呼び出しであり、`route_kind` を分けて記録する) | — | 1 |
| P-13 | テーマのタグ推定 | 直接 API。Go インライン (`claude_managed_agents/cmd/devui/themes_tags.go`。MaxTokens 256) | **廃止** (§4.3 の X-1) | Q0-② (v3 のテーマ API に LLM 経路が無いと確定済み) | — | — |

**P-3 統合の設計責任 (LM-Q1 の委譲先)**: 統合後の**プロンプト本文・ツール構成・会話状態の扱い**は本書では決めない —
**「会話型アイデア創出の API 設計」** ([API/README.md](API/README.md) §0 で本ディレクトリ対象外として宣言済みのタスク。
着手は認証系 Task-3i の後 — 2026-07-31 のユーザー決定) が担う。
**本書が確定させるのは「独立 Agent を作らない」ことと、それに伴う D-6 の対象が 3 本になること**である。
統合によるプロンプトの品質劣化 (発散後チャットの応答が発散モードに引っ張られる等) は
**§8 の品質確認の対象**とし、§8.2 の②ブラインド A/B を P-1 の feature で実施する。

**v3 新規 (PoC / v2 のどちらにも移植元が無い機能)** — 判定だけ本書が行う:

| # | 機能 | v3 の実装形態 | 採用理由 | モデル | 優先度 |
|---|---|---|---|---|---|
| N-1 | ナレッジ RAG の回答生成 (`POST /knowledge-threads/{thread_id}/messages`) | **直接 API** (**KN-Q2 への回答**。[API/knowledge.md](API/knowledge.md) §6 が本書に委譲) | Q1=No (検索は `usecase/knowledge` が所有者スコープで実行し、結果のみを LLM に渡す — [API/knowledge.md](API/knowledge.md) §4)・Q3=No (次の呼び出しはユーザーの発話が決める。§3 の ※3) | **C-4** | 1 |
| N-2 | ナレッジのファイル埋め込み生成 (`POST /knowledge-files`) | **直接 API** | Q1〜Q3=No (テキスト → ベクトル) | **C-7** (**プロバイダ未選定 — 選定は別トピックの設計**。§5.1) | 1 |

**N-1 / N-2 が優先度 1 である根拠** (2026-07-31 のユーザー確認 = LM-Q6):
**RAG は第 1 リリースに含める**。**別トピックに切り出すのは「RAG の設計」** —
埋め込みプロバイダの選定・`gateway` 実装・ベクトル格納先のスキーマなど (申し送り 7 項目は §9.1 の LM-Q6) —
であり、**リリース時期を後ろへずらす決定ではない**。
**実装形態の判定 (N-1 / N-2 ともに直接 API) は本書の確定事項**であり、別トピックで再判定しない。

### 4.2 v2 由来 (併用期間に移送。C-13 により v2 側には残さない)

出典列の「§2-N」は [v2-llm-inventory.md](../analysis/v2-llm-inventory.md) §2 の表の行番号。

| # | 機能 | 現状の経路 (出典) | v3 の実装形態 | 採用理由 (§3 の判定) | モデル | 優先度 |
|---|---|---|---|---|---|---|
| V-1 | アイデア生成 | `hassan-v2-backend/usecase/idea/generate_idea.go` (§2-1。実効 `gemini-3.1-pro-preview` → `gpt-5.2`) | **v3 の会話型フロー (P-2) へ統合** — **独立機能として移植しない** (2026-07-31 のユーザー決定 = §9.1 の LM-Q2)。統合の詳細設計は**会話型アイデア創出の API 設計**へ委譲 | Q1〜Q3=No (テーマ入力 → アイデア配列の単発生成) だが、**v3 では同じ目的の入口が P-2 に存在するため 2 系統を維持しない** | P-2 と同一 (**C-1**) | 統合先に従う |
| V-2 | アイデア評価 | `hassan-v2-backend/usecase/idea/evaluate_ideas.go` (§2-2) | **P-5 へ統合** — 独立機能として移植しない (同 LM-Q2)。**プロンプトの 1 本化は §6.2 の 4** | 同上 | P-5 と同一 (**C-2**) | 統合先に従う |
| V-3 | マイアイデア補完 | `hassan-v2-backend/usecase/idea/create_my_idea.go` (§2-3。env を見ない) | **v3 の会話型フロー (P-2) へ統合** — 独立機能として移植しない (同 LM-Q2) | 同上 | P-2 と同一 (**C-1**) | 統合先に従う |
| V-4 | アイデアの Web 検索 (市場規模 / CAGR / OGP 選択・ページ本文からの抽出) | `hassan-v2-backend/usecase/idea/web_search.go` (§2-4 / §2-5。`gpt-5-nano` 3 箇所ハードコード) | **直接 API + `gateway/exa`** | Q2=No (検索 → 抽出の 2 段が Go に固定) | **C-3** + **C-5** | 2 |
| V-5 | アイデア市場規模・CAGR Web リサーチ (多段) | `hassan-v2-backend/usecase/idea/idea_market_cagr_web_research.go` (§2-6。**唯一 usage を読んでいる経路**) | **直接 API の固定パイプライン + `gateway/exa`** | Q2=No (§3 の ※1)。**単価ハードコードは廃止し `estimated_cost` は単価テーブル O-H から算出する** ([observability.md](observability.md) §4.2) | **C-3** + **C-5** | 2 |
| V-6 | 企画書 簡易モード生成 | `hassan-v2-backend/usecase/business_plan/generate_business_plan.go` (§2-7。SSE) | **P-4 (Agent 版タブ生成) へ統合** — 独立機能として移植しない (2026-07-31 のユーザー決定 = §9.1 の LM-Q2)。**§6.2 の 5 (企画書 3 方式の 1 本化) に v2 の簡易モードも含める** | Q1〜Q3=No (単発生成をストリームで返すだけ) だが、**v3 では企画書の生成経路を P-4 に一本化する**ため独立経路を作らない | P-4 と同一 (**C-2**) | 統合先に従う |
| V-7 | 企画書 ブラッシュアップ stage-1 (クエリ補強) | 同上 (§2-8) | **直接 API** | Q2=No (段が Go に固定) | **C-3** | 2 |
| V-8 | 企画書チャット | `hassan-v2-backend/usecase/business_plan/business_plan_chat.go` (§2-9。SSE) | **直接 API** | Q3=No (§3 の ※3。ツールを持たない chat) | **C-4** | 2 |
| V-9 | 企画書サムネイル生成 (画像) | `hassan-v2-backend/usecase/business_plan/generate_business_plan_thumbnail.go` (§2-10。プロバイダ直指定) | **直接 API (Gemini)**。**機能は維持する** (2026-07-31 のユーザー決定 = §9.1 の LM-Q3。Gemini が LM-D の例外として残る) | Q1〜Q3=No。LM-D の例外 (Anthropic に画像生成が無い) | **C-6** | 3 |
| V-10 | 企画書詳細 セクション分析 7 種 (競合 / PESTEL / 市場 / 仮説検証 / 法規制 / 評価サマリ / ブラッシュアップ) | `hassan-v2-backend/usecase/business_plan/detailed/web_research.go` ほか (§2-11) | **直接 API** (セクションごとに 1 呼び出し) | Q2=No (セクションの集合と順序は Go が固定) | **C-2** | 3 |
| V-11 | 企画書詳細 Web リサーチ | 同 (§2-12。plan / draft / search / revision / critic の 5 フェーズ) | **直接 API の固定パイプライン + `gateway/exa`** | Q2=No (§3 の ※1) | **C-3** + **C-5** | 3 |
| V-12 | カスタムリサーチ (旧 `research_chat`。SSE) | `hassan-v2-backend/usecase/research/custom_research_stream.go` (§2-13。リクエストで 7 フェーズのモデルを指定可) | **v3 のナレッジ (N-1) へ統合** — 独立機能として移植しない (2026-07-31 のユーザー決定 = §9.1 の LM-Q2)。**統合先の N-1 は第 1 リリースに入る**ため、V-12 の移送は **RL-4 のリサーチ系ドメインの切替時**に行う (§7.1 の M-9)。**リクエストからのモデル直指定は移植しない** (プロファイル指定に置き換える。§5.2) | Q2=No (§3 の ※1)。ナレッジの「検索して答える」経路と目的が重複するため 2 系統を維持しない | N-1 と同一 (**C-4** + **C-5**) | 統合先に従う (移送は 3) |
| V-13 | リサーチシート 6 系統 (テーブル作成・修正 / アクション分類 / 質問応答 / 質問応答 + 検索 / Web リサーチ / その他) | `hassan-v2-backend/usecase/research_sheet/handle_create_sheet.go` ほか (§2-14〜§2-18) | **廃止** (§4.3 の X-12。2026-07-31 のユーザー決定 = §9.1 の LM-Q4)。**v3 に対応機能を作らない = ユーザーに見える機能減**であり、**ユーザー告知の対象**とする | Q0 の 3 条件には当たらない (v2 で稼働中) — **スコープ判断による廃止**。v3 の API 設計に対応ドメインが無く ([API/README.md](API/README.md) §0)、移植すると API 設計タスクが 1 本増える | — | — |
| V-14 | アセットタイトル抽出 | `hassan-v2-backend/usecase/asset/extract_asset_titles_llm.go` (§2-19。`dify_` 命名が現役) | **直接 API**。**P-9 (v3 のアセット抽出) に吸収し、単独機能としては残さない** | Q1〜Q3=No。**吸収の理由**: v3 は 1 回の抽出ジョブで棚卸し情報を構造化する設計 ([API/assets.md](API/assets.md) D-AS-3) であり、タイトルだけを別経路で抽出する段が存在しない | **C-2** | 2 |
| V-15 | アセット説明生成 (ドキュメント経路 / タイトルのみ経路 / WriteReport) | `hassan-v2-backend/usecase/asset/generate_asset_descriptions_llm.go` ほか (§2-20 / §2-21) | **直接 API**。**P-9 に吸収** (同上) | 同上 | **C-2** | 2 |
| V-16 | URL から企業情報 (`GET /companies/genai`) | `hassan-v2-backend/usecase/company/company_from_url_llm.go` (§2-22。`o4-mini` **フォールバック無し**) | **直接 API** ([API/settings.md](API/settings.md) §5 の注に対する回答) | Q1〜Q3=No (URL 本文 → 固定フィールドの JSON)。**fallback をプロファイルに追加する** (現状は単一モデル) | **C-3** | 2 |
| V-17 | JSON 抽出 (`extract_json`) | **v2 で既に LLM を使わない実装** (`hassan-v2-backend/util/json.go`) | **廃止** (§4.3 の X-8)。**決定論的な JSON 抽出ロジックは移植する** (LLM 呼び出しとしては作らない) | Q0-③ | — | — |

**LM-Q2 の決定が本表に与えた変化 (2026-07-31)**:

| 区分 | 該当 | v3 での扱い |
|---|---|---|
| **統合 (独立移植しない)** | **V-1 / V-2 / V-3 / V-6 / V-12** の 5 件 | 会話型フロー (P-2 / P-4) と P-5 / ナレッジ (N-1) に吸収。**API・プロンプト・profile を独立に持たない** |
| **廃止 (機能減)** | **V-13** (LM-Q4) / V-17 (Q0-③) | §4.3 の X-12 / X-8 |
| **独立して移送する** | V-4 / V-5 / V-7 / V-8 / V-9 / V-10 / V-11 / V-14 / V-15 / V-16 の **10 件** | 直接 API。うち V-14 / V-15 は P-9 に吸収される移送 |

**統合の詳細設計の委譲先**: **「会話型アイデア創出の API 設計」** (着手は認証系 Task-3i の後 —
2026-07-31 のユーザー決定)。**本書が確定させるのは「独立機能として移植しない」ことだけ**で、
①統合後の入口 (会話ターンか専用エンドポイントか) ②v2 の評価軸・出力スキーマのどちらを採るか (§9.2 の LM-R6)
③v2 の既存 FE 画面をどう畳むかは、その設計と [operations.md](operations.md) §6 の切替計画が決める。

**V-4 / V-5 を統合対象に入れなかった理由**: 2026-07-31 のユーザー回答が名指ししたのは V-1〜V-3 / V-6 / V-12 のみ。
V-4 / V-5 (アイデアの Web 検索・市場規模 CAGR リサーチ) は**独立移送のまま据え置く**。
ただし統合先 (P-2) の設計で市場規模調査が会話型フローの tool (P-8) に吸収される可能性があり、
その場合 §7.1 の M-7 は消滅する — **§9.2 の LM-R8 として残課題に立てる** (推測で先に畳まない)。

### 4.3 廃止する機能・資産 (移植対象から外す判断)

**2 群に分けて数える** — 「廃止 N 件」を機能減として説明できるようにするため
(ユーザーへの説明に直結するので粒度を混ぜない):

| 群 | 件数 | 意味 |
|---|---|---|
| **(1) 機能の廃止** (ユーザーに見える変化がある) | **7 件** = X-1〜X-5 (PoC 由来 5 件) + X-8 / **X-12** (v2 由来 2 件) | v3 に対応機能を作らない。**代替が無い場合は要件確認が必要** |
| **(2) 資産・命名の整理** (機能は不変) | **5 件** = X-6 / X-7 (未配線・revert 専用のプロンプト) / X-9 (v2 の dead code) / X-10 (命名整理 = リネーム) / X-11 (残骸型の非移植) | 移植作業から外すだけで、**ユーザーから見た機能は変わらない** |

**X-10 は廃止ではなくリネーム** (対象の 4 本は現役)。LM-B の 3 条件を満たさないため (2) に置く。

**ユーザー告知が必要なのは X-12 (リサーチシート) のみ** (2026-07-31 の LM-Q4 で追加):
X-1〜X-5 / X-8 は「未配線 / FE から到達しない / 決定論的コードに置換済み」であり
**現在のユーザーが使っている機能ではない** (各行の根拠を参照)。X-12 は**v2 で稼働中の機能を v3 で作らない**
唯一のケースなので、**リリースノート / ユーザー告知の対象**とする
([API/idea-boards.md](API/idea-boards.md) §6 の IB-Q10 と同じ扱い)。
**[operations.md](operations.md) §6 の切替手順には現時点でユーザー告知の節が無い** (2026-07-31 実測: 同書に「告知」の記述 0 件) —
**告知項目を同書へ追加する是正要求を §9.2 の LM-R9 に立てる** (本書からは同書を書き換えない)。
**統合 (V-1〜V-3 / V-6 / V-12) は機能減ではない** — 入口が会話型フロー / ナレッジに変わるだけであり、
告知は「操作方法の変更」として扱う (廃止一覧に入れない)。

**無言で落とさないために、根拠 (パス) と Q0 の条件を明記する** (LM-B)。

| # | 対象 | Q0 の条件 | 根拠 (出典) |
|---|---|---|---|
| X-1 | テーマのタグ推定 (`claude_managed_agents/cmd/devui/themes_tags.go`) | ② | v3 のテーマ API は「LLM 経路を持たない」と確定済み ([API/themes.md](API/themes.md) §5 の A-6 / O-2)。**タグ推定 UI が要件化された場合は、themes.md の LLM 列と本表を同時に更新する** (§9 の LM-R3) |
| X-2 | 旧アイデア評価 `/api/evaluate` (`claude_managed_agents/cmd/devui/evaluate.go` の 2 プロンプト) | ② | ルーティング登録はあるが `frontend/src` に呼び出しなし。`idea_evaluate` に置き換わったと判断 ([poc-prompt-inventory.md](../analysis/poc-prompt-inventory.md) §4。**置換の断定は確信度中**) |
| X-3 | 旧 BMC 深掘り `/api/deepdive` (`claude_managed_agents/cmd/devui/deepdive.go`) | ② | 同上。`deep_dive` tool (P-6) に置き換わったと判断 (同 §4) |
| X-4 | 企画書 8 タブ一括生成 (`claude_managed_agents/prompts/idea_plan_system.md`。MaxTokens 48000) | ② | 同期 (非 SSE) 分岐のみで到達し、FE は常時 SSE を使うため**到達しない** (同 §1.1)。P-4 (タブ単位) に集約する |
| X-5 | 発散の**自前ツールループの実行部分のみ**: `claude_managed_agents/internal/agent/diverge/` の `Service` 一式 (`NewService` / `RunOnce` / `RunOnceWithEvents` / `RunWithHistory` / `ValidateInput` / `orchestratorForPattern` と、それらが使う `Orchestrator` / `toolset` / `pattern_prompt`) + `claude_managed_agents/prompts/diverge/` 配下 9 ファイル (orchestrator / input_validator / tools 3 / patterns 4) | ① | `Service` 一式の非テストコードからの呼び出しがコメント内の言及のみ。`claude_managed_agents/cmd/devui/conversation_tools_generate.go` のコメントに「Managed Agent 経由に置き換え」と明記 (同 §4。オーケストレーターが再照合済み)。**⚠ パッケージ全体を廃止対象にしない** — 下記の注記を参照 |
| X-6 | `claude_managed_agents/prompts/research_system.md` (リサーチャー用 system prompt) | ① | `prompts.ResearchSystem` は `claude_managed_agents/prompts/embed.go` の宣言のみ。発行コマンド例も無い (同 §1.1 / §4)。**情報源優先度ルールの文言は P-12 側を正として引き継ぐ** (§6.2 の 3) |
| X-7 | `claude_managed_agents/prompts/idea_diverge_system.original.md` (revert 用の切り分け版) | ① | `update-agent-prompt --revert` 時のみ使用 (同 §1.1)。**プロンプトの版管理は git で行う** ([operations.md](operations.md) §5.2 が発行をハッシュ差分で管理するため、リポジトリ内に旧版ファイルを並置する必要がない) |
| X-8 | LLM による JSON 抽出 (v2 の `hassan-v2-backend/prompt/json_extraction/system/system.tmpl` + 取得関数 2 本) | ③ | v2 で決定論的 Go コードに置換済み。非テストコードからの呼び出しはゼロ ([v2-llm-inventory.md](../analysis/v2-llm-inventory.md) §1-4) |
| X-9 | `hassan-v2-backend/dify` パッケージ・ワークフロー YAML (prod 7 / dev 8)・`DIFY_*` env 9 個 | ① | dead code (§1.1)。**v3 に持ち込まない**。v2 リポジトリからの削除は v2 側の課題であり本書の範囲外 ([dify-inventory.md](../analysis/dify-inventory.md) §5) |
| X-10 | `Dify` を名に含む識別子 (プロンプト関数 8 個・テンプレート 4 本・引数型 2 種) | — (命名整理) | **4 本は現役だが、v3 では機能名で命名する** ([v2-llm-inventory.md](../analysis/v2-llm-inventory.md) §5-3)。廃止済み基盤の名前を新システムに持ち込まない ([dify-inventory.md](../analysis/dify-inventory.md) §6-2) |
| X-11 | `dto.ResearchUsage` / `ResearchChoice.FinishReason` (Dify / Perplexity 時代の残骸) | ① | 現在は履歴パースの入れ物として空のまま使われている (同 §7 の最終行)。**v3 では `CallMeta` が usage と `stop_reason` を持つ** ([observability.md](observability.md) §4.2) ため、この型を移植しない |
| **X-12** | **リサーチシート 6 系統 18 経路** (V-13。`hassan-v2-backend/usecase/research_sheet/handle_create_sheet.go` ほか。内訳は [v2-llm-inventory.md](../analysis/v2-llm-inventory.md) §2-14〜§2-18) | **— (スコープ判断)** | **2026-07-31 のユーザー決定 (§9.1 の LM-Q4) により v3 へ移植しない**。Q0 の 3 条件には当たらない (**v2 で稼働中の機能**) ため、**廃止の根拠は「v3 のスコープに入れない」というユーザー判断そのもの**である。**(1) 機能の廃止に数える唯一の稼働中機能**であり、**告知対象** (上記の注 + §9.2 の LM-R9)。**プロンプト資産・Web リサーチ実装ともに移植しない** — 多段 Web リサーチのパイプライン実装は V-11 (企画書詳細) 側を正として作る |

> **X-5 の範囲に関する重要な注意 (2026-07-30 のレビュー指摘により明確化)**:
> `internal/agent/diverge/` は**パッケージ全体が未配線ではない**。同パッケージには**生きているドメイン型**が
> 同居しており、稼働中のコードから多数参照されている (実測: `PlanTabID` / `IdeaPlan` (`plan.go`)、
> `Idea` / `IdeaEvaluation` (`schema.go`) が `cmd/devui/idea_plan.go` · `plan_tab_versions.go` ·
> `idea_evaluations.go` · `theme_ideas.go` · `plan_brushup.go` · `conversation_tools_plan.go` ほかから利用)。
> **廃止するのは実行部分 (Service / Orchestrator / toolset / pattern_prompt) とプロンプト 9 本だけ**であり、
> **型定義は移植対象**である。v3 での行き先は次のとおり:
>
> | PoC の資産 | v3 での行き先 |
> |---|---|
> | `PlanTabID` / `IdeaPlan` (企画書 8 タブの ID とタブ構造) | **`entity/plan`** (副作用のない型定義。P-4 / P-5 が使う) |
> | `Idea` / `IdeaEvaluation` (アイデアと評価スコアの構造) | **`entity/idea`** (P-8 が使う) |
> | `Service` / `Orchestrator` / `toolset` / `pattern_prompt` + `prompts/diverge/` 9 本 | **廃止** (X-5。Managed Agent 経由に置換済み) |
>
> **パッケージ名の一致で廃止判断をしない** — PoC は実行部分と型定義を同一パッケージに置いているため、
> 「パッケージ単位で移植 / 廃止を決める」と生きた型が落ちる。

> **埋め込み (C-7) は LM-D の「例外は 2 つ」を崩す — 決着済み** (起票 2026-07-30 / 決定 2026-07-31。
> 経緯と申し送りの全文は §9.1 の LM-Q6):
> **Anthropic は埋め込みモデルを提供していない**ことが一次ソースで確定し、**RAG は第 1 リリースに含める**という
> ユーザー確認が出たため、**3 番目のプロバイダが第 1 リリースに必ず入る** — LM-D の「例外は Exa と Gemini の
> 2 つのみ」は**「第 1 リリース時点で 3 つ」に改まる**。ただし**プロバイダの確定と、それに伴う
> gateway 実装 (§10.1)・単価テーブルの行追加・API キーの Secrets 登録
> ([operations.md](operations.md) §4.5 の棚卸し)・ベクトル格納先は、本書ではなく別トピックの設計で決める**
> (ユーザー確認「RAG はリリースするが、RAG の設計は別で行う」)。
> **本書に残る確定事項**: ①**RAG を廃止対象に入れない** ②**N-1 / N-2 は優先度 1・実装形態は直接 API**
> (KN-Q2 への回答は有効) ③**M-4 は RL-1** (§7.1)。

**廃止によって減る PoC 資産**: プロンプトファイル **12 本** (X-4 の 1 + X-5 の 9 + X-6 + X-7) と
Go インライン **3 箇所** (X-1 / X-2 / X-3)。
[poc-prompt-inventory.md](../analysis/poc-prompt-inventory.md) §1 の内訳 (**26 ファイル + 埋め込み 7 箇所**) に対し、
**移植元となるのは 14 ファイル + 4 箇所**である (X-12 は v2 側の資産であり、この内訳には含まれない)。
**移植先のファイル数はこれより少ない** — LM-Q1 の統合で `post_diverge_chat_system.md` が
`prompts/conversation/orchestrator.md` に取り込まれ、§6.2 の 1 本化 (research_market の 2 箇所・評価の複数実装) も
統合されるため、**v3 の `prompts/` のファイル数は §6.1 のレイアウトが示す構成が正**である
(「26 → 14」は移植元の数え方であって、v3 のファイル数ではない)。

---

## 5. 使用モデルの見直し (C-9 の「使用モデルは見直す」)

> 本節が回答する ID: **O-3** (モデル選定はコストの主要因)・**D-1 / D-5** (環境差とキーの持ち方は
> [operations.md](operations.md) §3.3 / §4.1 が SSOT。本節は参照のみ) / 対応 AC: **AC-3.8** (2 要素目)

### 5.1 用途カテゴリと初期モデル

**モデル名を持つのは本表と `config` のプロファイル表のみ**。§4 の移行表・プロンプト・FE・
ドキュメント本文に個別のモデル名を書かない (BE-2)。

| ID | 用途カテゴリ | 該当機能 (§4) | 初期モデル (プロバイダ) | 選定理由 | 確定方法 |
|---|---|---|---|---|---|
| **C-1** | 会話・ツールループ (Agent) | P-1 (**P-3 を統合**) / P-2 (**V-1 / V-3 を統合**) | **Anthropic Claude sonnet 級** (v2 に定義済みの `claude-sonnet-4-5` が候補) | Managed Agents は Anthropic 提供 (C-2) のため**プロバイダの選択余地が無い**。ツールの選択と多段推論を行うため下位モデルに落とすと停止条件の判断が劣化する | **実測** (§5.3。sonnet 級 vs haiku 級) |
| **C-2** | 大きい構造化出力 (JSON 数千トークン) | P-4 (**V-6 を統合**) / P-5 (**V-2 を統合**) / P-6 / P-9 / V-10 / V-14 / V-15 | **同 sonnet 級** | 現行の MaxTokens が 8192〜16384 (PoC 実測) で、**切り詰め (BE-6) が実際に発生した用途**。スキーマ適合率が要件で、下位モデルの節約額より 1 件の壊れた JSON の再実行コストが大きい | **実測** (§5.3 の指標①②が判定軸) |
| **C-3** | 小さい構造化判定 (分類・スコアリング・抽出。MaxTokens ≤ 4096) | P-7 / P-8 / P-10 / P-11 / V-4 / V-5 / V-7 / V-16 | **Anthropic Claude haiku 級** (`claude-haiku-4-5-20251001` が候補) | 出力が小さく判定基準が明示されている用途。**呼び出し回数が最も多い**カテゴリなので単価とレイテンシの効果が大きい | **実測必須** (下げる方向の変更のため、§5.3 の合否をすべて満たすまで既定にしない) |
| **C-4** | 長文生成 (レポート・回答本文) | N-1 (**V-12 を統合**) / V-8 | **同 sonnet 級** | 文章品質が成果物そのもの。**人間評価 (§5.3 の指標⑤) の比重が最も高い**カテゴリ | **実測** |
| **C-5** | Web 検索 | P-8 / P-10 / P-12 / V-4 / V-5 / V-11 / N-1 経由の V-12 | **Exa** (`gateway/exa`) | v2 は検索実行モデルに OpenAI の `*-search-preview` を既定にし、4 パッケージで別々に fallback を持っていた ([v2-llm-inventory.md](../analysis/v2-llm-inventory.md) §3-4)。**プロバイダ固定モデルを既定にすると gateway の差し替え余地が消える**。PoC は Exa を実使用 | **確定** (LM-D。検索品質の比較は §9 の LM-R1) |
| **C-6** | 画像生成 | V-9 | **Gemini `gemini-2.5-flash-image`** (v2 と同一) | LM-D の例外。Anthropic に画像生成機能が無い。v2 で稼働している組み合わせをそのまま使う | **確定** (**機能の維持は 2026-07-31 のユーザー決定済み** = §9.1 の LM-Q3。カテゴリの変更なし) |
| **C-7** | 埋め込み (RAG) | N-2 (**第 1 リリースに含む**) | **プロバイダ未選定** (**選定は別トピックの RAG 設計で行う** — §9.1 の LM-Q6。**Anthropic は埋め込みモデルを提供していない**ため 3 番目のプロバイダになる。候補は Voyage AI) | **v2 に RAG 機能が無く** ([API/knowledge.md](API/knowledge.md) §1)、PoC にも埋め込み経路が無いため、**既存分析文書に選定の根拠となる事実がない** | **実測** (§5.3 を RAG 用に読み替える。指標①②の代わりに**検索の再現率**を測る。**プロバイダ選定後・RL-3 の前**に実施する) |

**本表から外れた機能** (2026-07-31 の LM-Q1 / LM-Q2 / LM-Q4 の反映):
**V-1 / V-2 / V-3 / V-6 / V-12** は統合先の feature に吸収されるため**独自のプロファイル行を持たない**
(統合先の `feature` で計測・モデル解決される)。**V-13 は廃止** (X-12) のため行が無い。
**P-3 は P-1 と同一 feature** になるため C-1 の該当機能から独立した記載を外した。
**§5.2 のプロファイル表は「v3 で実在する `feature`」だけを持つ** — 統合された v2 機能名でキーを作らない
(計測の `feature` と 1 対 1 対応を崩さないため。[observability.md](observability.md) §4.2)。

**v2 の実効モデルからの変更点** (見直し結果の要約):

| 変更 | 現状 (v2) | v3 | 理由 |
|---|---|---|---|
| プロバイダの集約 | Gemini 主系 + OpenAI + Claude + Exa の 4 系統・22 モデル定義 | **Anthropic 主系 + 例外 3 つ** (Exa = 外部検索 / Gemini = 画像のみ / **埋め込み = RAG 用の第 3 プロバイダ**。Anthropic は埋め込みモデルを提供しないため必然。選定は RAG の別トピック設計へ申し送り — §9.1 の LM-Q6) | LM-D。§1.2 の a〜e はすべてマルチプロバイダ由来の不整合 |
| 検索実行 | `gpt-4o-mini-search-preview` → `exa-search` (パッケージごとに別定義) | **Exa 単独** | LM-D の (c) / C-5 |
| モデル指定の受け口 | `?model=fast\|think` (アイデア系) / body の `config` に 7 フェーズ分のモデル名 (カスタムリサーチ) | **プロファイル名のみを受け付ける** (モデル名を API から受け取らない) | 部分指定が空モデル名を通す欠陥 (§1.2 の g) と、FE にモデル名が漏れる BE-2 の同時解消 |
| 未知モデル | `default` で OpenAI へ | **エラー** | D-B''③ |

**PoC 側の現行モデルは未調査**: PoC の Managed Agent 定義と直接 API 呼び出しが指定しているモデル名は、
既存の分析文書 ([poc-prompt-inventory.md](../analysis/poc-prompt-inventory.md)) に記載がない
(同文書は実行形態と MaxTokens を記録し、モデル名は対象外)。
**したがって「PoC からの変更点」は本書では確定できない** (§9 の LM-R4)。

### 5.2 モデル名の SSOT (LM-C の具体化)

**`config` の LLM プロファイル表 1 箇所**が、モデルに関するすべての値の出所になる。

| プロファイルの列 | 内容 | 誰が読むか |
|---|---|---|
| `feature` (キー) | 機能識別子。**[observability.md](observability.md) §4.2 の `feature` と同一文字列** (例: `conversation.turn` / `plan.generate` / `asset.extract`) | 計測 (明細の `feature`) / モデル解決 / プロンプト解決 |
| `category` | §5.1 の C-1〜C-7 | モデル既定値の導出元 |
| `provider` / `model` | 実際に使うプロバイダとモデル | `gateway/<プロバイダ>` |
| `fallback[]` | 失敗時に試す順序 (LM-E) | gateway の呼び出しラッパ |
| `max_tokens` | 出力規模 + 余裕 (BE-6) | gateway |
| `timeout` | 1 呼び出しの上限 (ターン全体の上限は [observability.md](observability.md) §4.4) | gateway |
| `languages[]` | 対応言語 (LM-I) | プロンプト解決 |

**この表から導出するもの (別定義を作らない)**:

1. **用途別許可リスト** — 「この機能で使えるモデル」は `model` + `fallback[]` の集合。v2 のような
   独立した map (`IdeaGenerationModels` / `ResearchModels`) を作らない (§1.2 の d)
2. **エラーメッセージ内のモデル一覧** — 文字列リテラルで書かない。プロファイルから生成する
   (v2 は手書き一覧が map と同期していない)
3. **単価テーブルの参照キー** — `provider` + `model` ([observability.md](observability.md) の O-H)

**環境差の扱い** ([operations.md](operations.md) §3.3 が設定分類の SSOT):

- dev で安価なモデルを使う場合、**オーバーレイは `feature` 単位で全フィールドを与える** —
  部分指定を許さない。理由: v2 は部分指定で空モデル名が fallback 列に渡り、1 本目が必ず失敗する経路を
  作った (§1.2 の g)
- **prod と dev でモデルが異なる状態を既定にしない**。§8 の品質確認は dev で行うため、
  dev で安いモデルを使うと**確認した品質と本番の品質が別物になる**。安価モデルの使用は
  「開発中の疎通確認」に限り、RL-1 の受入確認 ([operations.md](operations.md) §6.1) は prod と同じ
  プロファイルで行う
- **API キーは Secrets Manager** ([operations.md](operations.md) §4.1)。プロファイル表にキーを書かない

**モデル / プロバイダ追加時に触る箇所**: **プロファイル表 1 箇所 + gateway 実装 (新プロバイダのみ)**。
v2 は 9 箇所 ([v2-llm-inventory.md](../analysis/v2-llm-inventory.md) §4-1) で、漏れると暗黙に
OpenAI へ流れていた。

### 5.3 「実測で決める」の条件 (DR-5 対策)

§5.1 で「実測」とした C-1 / C-2 / C-3 / C-4 (および C-7) は、**次の手順で決める**。
「性能を見て適切に選ぶ」では実装者が判断できないため、入力・指標・合否・時期・記録先を固定する。
**C-7 (埋め込み) も第 1 リリースのゲートに含める** — ただし**プロバイダ選定が先行条件**であり
(別トピックの RAG 設計が決める。§9.1 の LM-Q6)、選定後に本節の手順を検索の再現率へ読み替えて適用する。

**入力セット (ゴールデンセット)**:

| 項目 | 値 |
|---|---|
| 単位 | **`feature` 単位** (プロファイルのキーごと) |
| 件数 | **20 件 / feature** |
| 選定基準 | ①現行 (PoC / v2) で実行実績のある入力を優先する ②**入力長が上位のもの 3 件以上** (MaxTokens 余裕の検証) ③**現行で失敗した入力 2 件以上** (切り詰め・JSON パース失敗の再現。無い場合は「該当なし」と記録する) |
| 保管場所 | 実装リポの `testdata/golden/<feature>/` (§10 の引き渡し事項) |

**測る指標**:

| # | 指標 | 取得元 |
|---|---|---|
| ① | **スキーマ適合率** (JSON パース成功 かつ 必須フィールド充足) | 実行結果の検証コード |
| ② | **`stop_reason == max_tokens` の発生率** | `CallMeta` ([observability.md](observability.md) §4.2) |
| ③ | **p50 / p95 の `duration_ms`** | 同上 |
| ④ | **1 件あたりの `estimated_cost`** | 同上 + 単価テーブル (O-H) |
| ⑤ | **人間評価** (3 軸 = 事実の正確さ / 網羅性 / 指示遵守。各 5 段階、**評価者 2 名が独立に採点**) | 評価シート |

**実行条件**: 候補モデル 2〜3 本 × 各入力 3 回 (出力の揺れを見るため)。dev 環境で実行する。

**合否 (すべて満たすものだけを既定にする)**:

| # | 条件 |
|---|---|
| 1 | **①が 100%** (構造化出力を要求する feature)。1 件でも失敗するモデルは既定にしない |
| 2 | **②が 0%**。0% でない場合は `max_tokens` を上げて再測する (モデルの不採用ではなく設定の不足として扱う) |
| 3 | **⑤の平均が、比較基準 (§8.1 の凍結出力) より 0.5 点以上下がらない**。**例外 1: v3 新規機能 (N-1 / N-2) は比較基準を持たないため、§8.3 の絶対基準のみで判定する** (§8.1 の例外と同じ扱い。C-4 は N-1 を含み、C-7 は N-2 のみのカテゴリ)。**例外 2: 統合された v2 機能 (V-1〜V-3 / V-6 / V-12) の比較基準は統合先の feature に対して取る** — v2 の出力を before として凍結し (§8.1)、after は統合後の P-2 / P-4 / P-5 / N-1 の出力で比較する |
| 4 | 1〜3 を満たすモデルが複数ある場合は **④が最小のものを既定にする** |
| 5 | ③の p95 が SSE 経路で **60 秒**を超えないこと (超える場合はストリーミング前提の feature に限り許容し、その旨をプロファイルのコメントに残す) |

**実施時期と記録**:

- **実施**: dev への継続デプロイ期間 (RL-1。[operations.md](operations.md) §6.1) 内
- **プロファイル既定値の確定**: **RL-3 (本番リリース) の前**。未実測の feature を prod に出さない
  (**C-7 / N-2 も第 1 リリースに含まれる**ため対象。埋め込みプロバイダの選定が RL-3 前に決まっていることが前提 — §9.1 の LM-Q6)
- **記録先**: `docs/analysis/llm-model-benchmark.md` (未作成。§9 の LM-R5)。
  モデル名・日付・5 指標の値・採否を残す。**単価と性能は変動するため、日付の無い測定結果を根拠にしない**

---

## 6. プロンプト資産の移行方針

> 本節が回答する ID: **D-6** (対象の特定。手順は [operations.md](operations.md) §5.2) /
> 対応 AC: **AC-3.8, AC-3.3** (参照)

### 6.1 置き場と命名の規約

[architecture.md](architecture.md) の D-E (「テンプレートファイルは `prompts/<domain>/` に集約し、
構築ロジックは `service/<domain>/` に置く」) を、移植に使える粒度に具体化する。

```
prompts/
  conversation/   orchestrator.md              ← Agent (再発行対象)。P-3 (発散後チャット) を統合 (LM-Q1)
                  deepdive_credibility.md ほか 5 本
                  match_functions.md            ← PoC の Go インラインをファイル化
                  research_market.md            ← 2 箇所を 1 本化 (§6.2 の 2)
  idea/           diverge.md                    ← 4 軸を 1 ファイルで持つ (§6.2 の 1)。V-1 / V-3 を統合 (LM-Q2)
                  evaluate.md                   ← PoC + v2 の評価を 1 本化 (§6.2 の 4)
  plan/           tab.md                        ← Agent (再発行対象)。8 タブ共通 + V-6 を統合 (§6.2 の 5)
  asset/          extract.md / patent_fallback.md / merge.md
  knowledge/      answer.md                     ← N-1 (第 1 リリースに含む)
  shared/         source_priority.md            ← 情報源優先度ルール (§6.2 の 3)
```

**`post_diverge_chat_system.md` に対応するファイルを作らない** (LM-Q1 の統合結果)。
`prompts/conversation/` に `post_diverge_chat.md` を置くと、**ファイルはあるが Agent に載らない**状態
(= X-6 と同じ未配線資産) を新規に作ることになる。統合先の `orchestrator.md` に節として持つ。

| 規約 | 内容 | 根拠 |
|---|---|---|
| R-1 | ファイル名は**用途**で付ける。`system` / `user` はファイル内の見出しまたは同名の `.user.md` で表す。**機能ごとに分け方を変えない** | v2 は `idea` だけフラット + 接尾辞方式で、取得関数がパスを直書きしている (§1.2 の i) |
| R-2 | **`prompts/` 外に長いプロンプト文字列リテラルを置くことを CI で禁止する** (検査案: `service/` `usecase/` `gateway/` 配下の Go ファイルに **80 文字以上の文字列リテラル**があれば失敗。既存例外はリスト管理) | PoC はプロンプト本文が Go インライン 7 箇所にあり、D-6 の 3 者一致検査の走査対象から外れる ([poc-prompt-inventory.md](../analysis/poc-prompt-inventory.md) §1.2) |
| R-3 | **プロンプト内に数値 (生成件数・上限・スコア基準) を書かない**。テンプレート引数として注入する | [architecture.md](architecture.md) §3.9② (BE-2) |
| R-4 | **どのバージョンのデータをプロンプトに渡すか**を構築ロジック側で明示する (`service/<domain>/`) | BE-1 (旧バージョン参照で数値が食い違う) / BE-4 (派生物の stale) |
| R-5 | 言語別は `<name>.<lang>.md`。**暗黙フォールバックを実装しない** (LM-I) | §1.2 の i |
| R-6 | `MaxTokens` はプロンプト側に書かず**プロファイル表**に持つ (§5.2) | PoC は MaxTokens が 8 箇所以上に個別指定 (同 §1.1) |

### 6.2 散在 5 件の 1 本化 (BE-2 を構造で潰す)

出典は [poc-prompt-inventory.md](../analysis/poc-prompt-inventory.md) §3 の 1〜5 に対応する。

| # | 散在の現状 | v3 での 1 本化 | 残る作業 |
|---|---|---|---|
| 1 | **発散 4 軸が 2 系統に分裂** (生きている `idea_diverge_system.md` の `output_mode` 節 + 未配線の `prompts/diverge/patterns/*`)。文言が異なり同一挙動ではない | **生きている系統を正とし、未配線側は廃止** (§4.3 の X-5)。`prompts/idea/diverge.md` 1 本に軸別セクションを持つ形を維持する | **文言の差分を移植前に確認する** — 未配線側にしか無い有用な指示が含まれる可能性がある (§9 の LM-R2) |
| 2 | **`research_market` の候補領域抽出が 2 箇所** (Managed Agent 経由の REST と 会話 custom tool の Go インライン)。入出力スキーマも別実装 | **`prompts/conversation/research_market.md` 1 本 + 入出力スキーマ 1 つ**にし、REST 経路と tool 経路の**両方が同じテンプレートとスキーマを使う**。経路自体の存廃は会話型 API 設計が決める | — |
| 3 | **情報源優先度ルールの二重実装** (未配線の `research_system.md` と 実使用の `search_guidance.go`。同期の仕組みが無い) | **`prompts/shared/source_priority.md` 1 ファイルを唯一の定義**とし、**Anthropic の system prompt と Exa の `systemPrompt` の両方がこのファイルを読む** (Go の embed 変数 1 つを共有)。未配線側は廃止 (X-6) | — |
| 4 | **アイデア評価が 3 実装並存** (PoC の現行 + 旧 `evaluate.go` の 2 プロンプト) + **v2 側にも評価がある** (V-2) | 旧 2 実装を廃止 (X-2) し、**PoC 現行 (P-5) と v2 (V-2) を `prompts/idea/evaluate.md` 1 本に統合する** (**LM-Q2 = 統合するで確定**。V-2 は独立機能として移植しない)。**統合の実施時期は P-5 の実装時** — v2 の評価軸を取り込んだ 1 本を最初から作り、後から V-2 を足す形にしない | 評価軸・出力スキーマが PoC と v2 で異なる可能性 (**未調査**。§9 の LM-R6)。**どちらの軸を採るかは会話型 API 設計が決める** (本書は 1 本化の決定のみ) |
| 5 | **企画書生成の system prompt が 3 方式並存** (8 タブ一括 / per-tab の Go 組み立て / Agent 版 1 タブ)。MaxTokens も個別 | **Agent 版 (P-4) に統一**し、8 タブすべてを同じ経路に載せる。8 タブ一括は廃止 (X-4)。per-tab の Go 組み立ては `prompts/plan/tab.md` + タブ別引数に置き換える。**v2 の簡易モード (V-6) もここに統合する** (LM-Q2 = 統合するで確定。独立した streaming 経路を作らない) | **簡易モードの出力粒度 (8 タブに写像できるか) が未確認** — 統合の設計は会話型 API 設計が担う。**V-10 (詳細セクション分析 7 種) は統合対象ではなく独立移送**である (LM-Q2 の対象に含まれない) |

**v2 から移植するプロンプト資産の扱い**:

- 移植元は `hassan-v2-backend/prompt` の `*.tmpl` (130 本のうち、§4.2 で移送対象とした機能に対応する分)。
  **Dify ワークフロー YAML は参照しない** (LM-J)
- **`dify_` / `Dify` の命名を機能名に置き換える** (X-10)。テンプレートファイル名・取得関数名・引数型の 3 つ
- v2 の 2 系統のテンプレート取得関数 (`GetTemplateWithLanguage` / `getTemplateNoLanguage`。
  **TrimSpace の有無とテンプレート関数の集合が異なる** — [v2-llm-inventory.md](../analysis/v2-llm-inventory.md) §5-2)
  は **1 系統に統合する**。移植時に末尾空白の扱いが変わるため、**§8 の品質確認の対象に含める**

### 6.3 Agent 再発行対象 (D-6)

**v3 で再発行が必要なプロンプトは 3 本** (2026-07-31 の LM-Q1 で確定):
**P-1 (orchestrator。P-3 を統合) / P-2 (diverge) / P-4 (plan tab)**。

**PoC の対象は 4 本**である ([poc-prompt-inventory.md](../analysis/poc-prompt-inventory.md) §2:
`idea_diverge_system` / `post_diverge_chat_system` / `idea_plan_agent_system` /
`conversational_orchestrator_system`)。**v3 で 3 本になる差分は P-3 (post-diverge chat) の統合 1 本**であり、
**`CHAT_AGENT_ID` 相当の Agent・Environment 変数を v3 では発行しない**
(これにより §9.2 の LM-R7 = `CHAT_AGENT_ID` の発行コマンドが未発見という残課題は**v3 では解消**する —
発行そのものを行わないため)。

**発行・更新の手順、ハッシュ差分による発行判定、`Tools` 全置換 (BE-9) の承認材料、
ロールバック方法は [operations.md](operations.md) §5.2 / §5.3 が SSOT** — 本書では再定義しない。
本書が確定させるのは**対象がこの 3 本であること**と、**§4 の表の「Managed Agent」行が増えたら
D-6 の対象も増える**という対応関係である。

§4 の判定 (V-1〜V-17 に Managed Agent 判定は無い — 移送分は直接 API、統合分は既存 Agent に吸収、
V-13 / V-17 は廃止) により、**v2 由来の機能を移送しても再発行対象は 3 本のまま**である。

---

**`prompts/agents.yaml` が実体の SSOT** (2026-07-30 のレビュー指摘により明確化):
[operations.md](operations.md) §5.2 は「**Agent 再発行のトリガは `prompts/agents.yaml` の列挙のハッシュ**」と決め、
「発行コマンドが実際に送る集合と列挙の一致」を `check-tool-contract.sh` の検査項目にしている。

- **本節の 3 本は `agents.yaml` の初期値**である (実体の正は `agents.yaml`)。
  **`agents.yaml` に `post_diverge_chat` を列挙しない** — LM-Q1 の統合決定 (2026-07-31) の反映であり、
  列挙すると存在しない Agent の再発行が走る
- **§4 の表で Managed Agent 行が増減したら、`agents.yaml` と本節を同じ PR で更新する**。
  片方だけを直すと「統合したのに旧 Agent が再発行され続ける」「増やしたのに再発行が走らない」になる
- 一致の担保は人手のレビューに頼らず、`check-tool-contract.sh` の検査で落とす (同 §5.2)

## 7. 切替順序 (機能単位の移行順)

> 本節が回答する ID: **D-7** ([operations.md](operations.md) §6.1 の RL-4 の中身) /
> 対応 AC: **AC-3.8** (3 要素目), **AC-3.5** (参照)

### 7.1 順序と依存関係

| # | 段 | 内容 | 依存 (これが先に完了していること) | 対応する RL 段階 |
|---|---|---|---|---|
| **M-0** | 共通基盤 | ①`gateway/<プロバイダ>` と `CallMeta` (usage 4 種 / `stop_reason` / duration) ②`config` の LLM プロファイル表 (§5.2) ③`prompts/` レイアウトと R-2 の CI 検査 ④tool 契約検査 (`scripts/check-tool-contract.sh`) ⑤安全弁 (Runner) | — | RL-1 の開始条件 |
| **M-1** | PoC 直接 API・アセット系 | P-9 / P-10 / P-11 | M-0 | RL-1 |
| **M-2** | PoC Agent・会話中核 | P-1 (**P-3 統合済みの 1 本**) / P-2 + tool ハンドラ (P-6 / P-7 / P-8)。**V-1 / V-3 の統合分もここで作る** (LM-Q2) | M-0 / M-1 (会話の `list_assets` 系 tool がアセットを読む) / **会話型 API 設計の確定** (着手は認証系 Task-3i の後) | RL-1 |
| **M-3** | 企画書生成 | P-4 (**V-6 統合分を含む**) / P-5 (**V-2 統合分を含む**) | M-2 (企画書は会話の生成物を入力にする) | RL-1 |
| **M-4** | ナレッジ (**RAG**) | N-1 / N-2 | M-0 + **C-7 のプロバイダ選定** (別トピックの RAG 設計。§9.1 の LM-Q6) **とその実測** (§5.1) | RL-1 |
| **M-5** | v2 アセット系の吸収 | V-14 / V-15 → P-9 に吸収 | M-1 (吸収先が動いていること) | RL-4 |
| **M-6** | v2 企業情報 | V-16 | M-0 | RL-4 |
| **M-7** | v2 アイデア系 (**残る移送分**) | **V-4 / V-5 のみ** (V-1 / V-2 / V-3 は M-2 / M-3 に統合済み。LM-Q2) | M-3 (統合先が動いていること) | RL-4 |
| **M-8** | v2 企画書系 | V-7 / V-8 / **V-9** (LM-Q3 = 維持で確定) / V-10 / V-11 (V-6 は M-3 に統合) | M-3 / M-7 (企画書はアイデアを入力にする) | RL-4 |
| **M-9** | v2 リサーチ系 | **V-12 のみ** (V-13 は廃止 = X-12。LM-Q4)。**統合先は N-1 (M-4)** | M-4 (統合先が動いていること) / M-8 (Web リサーチのパイプライン実装を共有する) | RL-4 |

**並列可能**: M-1 と M-4 (アセットとナレッジは依存しない) / M-5 と M-6 / (M-7 完了後の) M-8 と M-9 の一部。
**直列必須**: M-0 → 他すべて / M-2 → M-3 → M-7 → M-8 / M-4 → M-9。

**第 1 リリース (RL-1〜RL-3) に入る段は M-0〜M-4 の 5 つ** (RAG を含む。§9.1 の LM-Q6)。
M-5〜M-9 は併用期間 (RL-4)。

**この順序の理由**:

1. **M-0 を最初に置く** — 各機能が独自に SDK を呼ぶ形が先に定着すると、gateway が後付けになり
   O-2 の単一関門が崩れる (v2 で実際に起きた形)
2. **アセット (M-1) を会話 (M-2) より先** — 会話の custom tool がアセットを読むため
   ([architecture.md](architecture.md) §3.10)。逆順にすると tool のハンドラがモックのまま残る
3. **v2 由来 (M-5 以降) は「吸収先が動いてから」** — V-14 / V-15 は P-9 に吸収する判断なので、
   P-9 が本番で動いていない状態で v2 側を止められない
4. **各段の完了条件は [operations.md](operations.md) §6.1 の RL-4 の 5 条件に従う** (本書で別途定義しない)。
   特に⑤「**gateway を通らない LLM 呼び出しが残っていない**」が本書の移行の受入条件になる
5. **統合対象 (V-1〜V-3 / V-6 / V-12) は「移送の段」を持たない** — 統合先を作る段 (M-2 / M-3 / M-4) で
   最初から v2 の要求を織り込む。**後から足す形にしない**理由: 「まず PoC 相当を作り、後で v2 の機能を足す」
   と、v2 側の切替 (RL-4 のドメイン単位) が「v3 に機能が足りないので止められない」状態で待たされ、
   [operations.md](operations.md) §6.0 の「同一ドメインを両系で同時に更新させない」が破れる
6. **M-4 (ナレッジ) は第 1 リリースに含む** (2026-07-31 のユーザー確認 = LM-Q6)。
   ただし **M-4 の開始には埋め込みプロバイダの選定が先行条件**であり、これは**別トピックの RAG 設計**が決める。
   **選定が RL-3 の前に確定しない場合、M-4 が第 1 リリースのクリティカルパスになる** —
   M-0 の gateway 実装 (プロバイダ 1 本追加) と §5.3 の実測が後続するため、
   **別トピックの起票を M-0 の着手と同時に行う** (§9.1 の LM-Q6 の申し送り)

### 7.2 v2 側で並走中に起きること

- **v2 には手を入れない** (C-13)。移送は v3 側に同等機能を作り、
  [operations.md](operations.md) §6.0 の「ドメイン単位で v3 へ寄せる」に従う
- **同一ドメインを両系で同時に更新させない**(同 §6.0)。したがって M-5〜M-9 の各段は
  **ドメイン単位で完結させる** — 「アイデア生成だけ v3、評価は v2」の状態を作らない。
  **アイデアドメインの切替判定は M-2 / M-3 (統合分) と M-7 (V-4 / V-5) の完了をもって行う** —
  統合により機能が 2 段に分かれたため、**段単位ではなくドメイン単位で切替を承認する**
- **X-12 (リサーチシート) は v3 に作らないため、当該画面の停止は「移送」ではなく「機能終了」**として
  切替計画に載せる (§4.3 の注記 + §9.2 の LM-R9)

---

## 8. 品質確認方法 (移行前後で劣化していないことの確認)

> 本節が回答する ID: **O-4** (失敗の観測は移行判定の入力) / 対応 AC: **AC-3.8** (4 要素目)

### 8.1 比較基準の凍結 (切替の前に行う)

**移行対象の feature ごとに、切替前に現行系 (PoC または v2) で §5.3 のゴールデンセット 20 件を実行し、
出力を凍結保存する**。

| 項目 | 内容 |
|---|---|
| 保存先 | 実装リポの `testdata/golden/<feature>/before/` (§10) |
| 保存内容 | 入力 / 出力本文 / 実行日 / 実行系 (PoC or v2) / **使用モデル (判明する場合)** |
| 凍結の理由 | **切替後に現行系を動かして比べることができない** (**該当ドメインは RL-4 で新規アクセスを止める** — v2 サービス自体の停止は RL-5 だが、ドメイン単位で「新規アクセス 0 件」を確認して移送するため、そのドメインについては RL-4 以降は比較に使えない。[operations.md](operations.md) §6.1。PoC はローカル環境で認証が無く、本番データで再実行できない)。比較基準は**切替前にしか取れない** |
| 例外 | N-1 / N-2 (v3 新規で比較基準が存在しない) は §8.3 の絶対基準のみで判定する |
| **統合された機能の扱い** (2026-07-31 の LM-Q1 / LM-Q2) | **統合元ごとに before を取り、統合先 1 つの after と比較する**。①**P-3 → P-1**: PoC の発散後チャットで 20 件を凍結し、統合後の P-1 の同じ質問と比較する (**統合で「発散モードに引っ張られて参照質問に答えない」劣化が出るのはこの比較でしか見えない**) ②**V-1 / V-3 → P-2** / **V-2 → P-5** / **V-6 → P-4**: v2 の出力を凍結し、統合先の出力と比較する ③**V-12 → N-1**: v2 のカスタムリサーチの出力を凍結し、N-1 の回答と比較する (M-9 の完了時)。**「統合したので比較基準が無い」という扱いにしない** — 統合は移行の一形態であり、§8.4 の合否をそのまま適用する |

### 8.2 判定の 3 段

| 段 | 内容 | 実行者 | 実行時期 |
|---|---|---|---|
| **①機械検査** | §8.3 の全項目 | CI (`go test`) | 移行 PR ごと |
| **②ブラインド A/B** | 凍結出力 (before) と v3 出力 (after) を**どちらが v3 か隠して**並べ、20 件を比較。優劣 + §5.3 の 3 軸スコア。**統合された機能 (P-3 / V-1〜V-3 / V-6 / V-12) は統合元ごとに 1 セット実施する** (§8.1 の例外行) | 評価者 2 名 (独立) | 各段 (M-1〜M-9) の完了時 |
| **③運用監視** | 切替後 **7 日間**の F-1〜F-5 の発生率 ([observability.md](observability.md) §4.3) と 1 件あたりコストの推移 | 開発チーム (アラート AL-2 / AL-4) | 切替後 |

### 8.3 機械検査の項目 (①)

| # | 検査 | 合格条件 | 由来 |
|---|---|---|---|
| Q-1 | 構造化出力のスキーマ適合 (パース成功 + 必須フィールド充足) | **20 / 20** | BE-6 |
| Q-2 | `stop_reason == max_tokens` が発生しない | **0 件** | BE-6 |
| Q-3 | **数値化ロジックのユニットテスト** (市場規模・CAGR・スコアの抽出) | レンジ表記 (`120-420億円` 等) を含む入力を**必ずテストケースに含める** | FE-6 |
| Q-4 | **読み手・書き手・テストが同一のスキーマ定義から導かれている** (合成 JSON をテストに直書きしない) | 生成物の還流経路 (深掘り結果 → 企画書など) で型が一致 | BE-12 |
| Q-5 | **引用・参照 ID が所有者スコープ内のものだけ** (LLM 出力の ID を参照経路にしない) | 他テナント ID を混ぜた入力で 0 件になる | A-6 / [API/knowledge.md](API/knowledge.md) §4 |
| Q-6 | tool schema ↔ handler ↔ prompt の 3 者一致 | `scripts/check-tool-contract.sh` が成功 | BE-8 / [architecture.md](architecture.md) §3.8.4 |
| Q-7 | **プロンプトの末尾空白・テンプレート関数の差**による出力変化がない (v2 の 2 系統統合の影響。§6.2) | before / after のトークン数の差が **±10% 以内** | §1.2 の i |

### 8.4 合否と不合格時の扱い

**合格条件 (3 つすべて)**:

1. **機械検査 (§8.3) が全項目合格**
2. **ブラインド A/B で「v3 が劣る」と判定された件数が 20 件中 4 件以下** (= 80% 以上で同等以上)。
   かつ 3 軸スコアの平均が **before より 0.5 点以上下がらない**
3. **切替後 7 日間**の LLM 失敗率が AL-2 のしきい値 (15 分間で 10%) を超えず、
   1 件あたりコストが before の **1.5 倍**を超えない

**評価者**: 機械検査は CI。ブラインド A/B は **2 名が独立に採点し、判定が割れた件は 3 人目が裁定する**。
**評価者の役割の確定は §9 の LM-Q5** (暫定既定: 当該機能を要求したプロダクト側 1 名 + 開発者 1 名 +
裁定者 1 名)。

**不合格時の調査順序** (原因の切り分けを実装者の勘に任せない):

| 順 | 疑う対象 | 確認方法 |
|---|---|---|
| 1 | **入力データのバージョン差** | プロンプトに渡したデータの版を before / after で照合 (BE-1)。**モデルを疑う前にここを見る** |
| 2 | **プロンプトの移植差分** | v2 / PoC の原文と v3 テンプレートを diff。§6.2 の 1 本化で文言を選んだ箇所を優先 |
| 3 | **`max_tokens` と切り詰め** | Q-2 の結果。設定不足ならプロファイルを上げて再測 |
| 4 | **モデル** | §5.3 の次候補で再測。**プロファイル 1 箇所の変更で切り替わる** (§5.2) |
| 5 | **検索結果の質 (C-5 経路のみ)** | Exa の結果件数・ドメイン分布を before / after で比較 |

**不合格のまま切替を進めない**。M-5〜M-9 の各段は [operations.md](operations.md) §6.1 の RL-4 の
完了条件 (ドメインごとに H-4 承認) に従い、本節の合否判定を承認材料に含める。

---

## 9. 本番観点への回答 / 未確定

> 本節が回答する ID: **D-6, D-7, O-2, O-3, A-6, D-1, D-5**

| ID | 状態 | 回答 |
|---|---|---|
| **D-6** Managed Agent のライフサイクル | **回答 (対象の特定)** | §6.3。再発行対象は **3 本** (P-1 / P-2 / P-4。2026-07-31 の LM-Q1 で P-3 を P-1 に統合したため PoC の 4 本から 1 本減) で、v2 由来の移送・統合では増えない。**手順の SSOT は [operations.md](operations.md) §5.2** |
| **D-7** 段階リリース | **回答** | §7.1 の M-0〜M-9 と RL 段階の対応。並列可否と直列必須を明示。**第 1 リリースは M-0〜M-4 (RAG を含む — LM-Q6) / M-5〜M-9 は RL-4** |
| **O-2** 全 LLM 呼び出しの計測 | **回答 (索引)** | §4 の表が**全 LLM 経路の一覧**であり、O-2 の計測対象の索引になる。**計測点の層とフィールドは再定義しない** ([architecture.md](architecture.md) §3.8.3 / [observability.md](observability.md) §4.2)。**Exa の検索呼び出し (P-12 / C-5) も課金を伴うため `route_kind` を分けて記録する** |
| **O-3** コスト | **部分回答** | 上限は設けない (C-12)。本書が担うのは**モデル選定によるコスト決定**と、§5.3 の指標④による事前見積り。集計・アラートは [observability.md](observability.md) §4.6 |
| **O-4** 失敗の可観測性 | **参照** | §8.2 の ③ と §8.3 の Q-1 / Q-2 が [observability.md](observability.md) §4.3 の F-1〜F-5 を移行判定に使う |
| **A-6** LLM の越境 | **部分回答** | §3 の判定手順が Agent 数を最小化する (Agent = LLM がツール引数を決める経路)。**強制点の設計は [architecture.md](architecture.md) §3.8.2 が SSOT**。§8.3 の Q-5 が移行時の検査項目として対応する |
| **D-1** 環境 | **参照** | プロファイルの環境オーバーレイ規則のみ本書 (§5.2)。環境定義は [operations.md](operations.md) §3 |
| **D-5** シークレット | **参照** | API キーは Secrets Manager ([operations.md](operations.md) §4.1)。**プロファイル表にキーを書かない**ことのみ本書が定める |
| **D-2** CI ゲート | **部分回答** | §6.1 の R-2 (プロンプト文字列リテラルの禁止) と §8.3 の Q-1〜Q-7 を CI に載せる。ゲート一覧の SSOT は [operations.md](operations.md) |
| **D-3 / D-4 / D-8** | **対象外** | デプロイ手順・DB マイグレーション・IaC 管理範囲は本書の論点ではない。先送り先: [operations.md](operations.md) (D-3 / D-4) / [infrastructure.md](infrastructure.md) (D-8) |
| **A-1〜A-5 / A-7** | **対象外** | 認証・テナント境界・ステータスコードは [auth.md](auth.md) と [API/README.md](API/README.md) が SSOT。本書は LLM 経路の実装形態のみを扱う |
| **O-1 / O-5 / O-6 / O-7** | **対象外** | ログ・SSE・監査・アラートは [observability.md](observability.md) が SSOT |

### 9.1 未確定 (回答が入ると本書の判断が変わる)

**LM-Q1〜LM-Q4 / LM-Q6 は 2026-07-31 にユーザー回答済み** (各 `[Answer]` 行が確定内容)。
**未回答は LM-Q5 のみ**。以下の各項目は「仮定を置いて設計を進めた」状態の記録であり、
**回答が仮定と異なる場合は `[Answer]` 側が正**である。

**LM-Q1: 発散後チャット (P-3) を会話オーケストレーター (P-1) に統合するか、独立した Agent として残すか** —
統合すれば Agent が 3 本になり D-6 の再発行対象が 1 本減る。決定は会話型アイデア創出の API 設計で行う。
**仮定: 独立した Agent として移植する** (PoC が別 Agent で運用しており、統合は挙動変更を伴う)。
影響する節: §4.1 / §6.3。

[Answer]: **統合する** (2026-07-31 ユーザー回答。**仮定と逆**)。P-3 を P-1 へ統合し、
**Managed Agent は P-1 / P-2 / P-4 の 3 本**になる (**D-6 の再発行対象も 3 本**)。
**プロンプト統合の妥当性検証は「会話型アイデア創出の API 設計」と §8.4 の品質確認 (§8.1 の統合行) で行う**。
反映先: §1.3 の a (v3 の対象は 3 本) / §4.1 の P-3 行 + 統合の設計責任の注記 / §5.1 の C-1 /
§6.1 のレイアウト (`post_diverge_chat.md` を作らない) / §6.3 (3 本 + `agents.yaml` に列挙しない) /
§7.1 の M-2 / §8.1 の統合行 / §9 の D-6 行 / §3 の表 (3 本 → 8 本以上)。

**LM-Q2: v2 のアイデア生成 (V-1〜V-3) / 企画書生成 (V-6) / カスタムリサーチ (V-12) を、v3 の会話型フロー
(P-2 / P-4) およびナレッジ (N-1) に統合するか、独立した機能として移植するか** —
機能重複の指摘は [dify-inventory.md](../analysis/dify-inventory.md) §6-3。Q-3 のスコープ判断と同時に決まる。
**仮定: 独立機能として移植する** (v2 の画面と API が稼働しており、統合は FE の作り直しを伴う)。
影響する節: §4.2 / §6.2 の 4・5 / §7.1 の M-7〜M-9。

[Answer]: **統合する** (2026-07-31 ユーザー回答。**仮定と逆**)。V-1 / V-2 / V-3 / V-6 / V-12 の **5 件は
独立機能として移植しない** — v3 の会話型フロー (P-2 / P-4)・P-5 (評価)・ナレッジ (N-1) に統合する。
**統合の詳細設計は「会話型アイデア創出の API 設計」タスクが担う** (着手は認証系 **Task-3i** の後 —
同日のユーザー決定)。**本書が持つのは「独立移植しない」という決定と委譲先の明示だけ**であり、
統合後の入口・ツール構成・評価軸の選択は本書では決めない。
反映先: §4.2 の V-1 / V-2 / V-3 / V-6 / V-12 行 + LM-Q2 の変化表 / §5.1 の C-1〜C-5 と「本表から外れた機能」 /
§6.1 のレイアウト / §6.2 の 4・5 / §7.1 の M-2 / M-3 / M-7 / M-9 と理由 5 / §7.2 / §8.1 の統合行 / §10.3。

**LM-Q3: 企画書サムネイル生成 (V-9) を v3 で維持するか** —
維持する場合のみ Gemini が 3 番目のプロバイダとして残る (LM-D の例外)。
**仮定: 維持する** (v2 で稼働中の機能であり、廃止は §3 の Q0 の 3 条件のいずれにも当たらない)。
影響する節: §4.2 / §5.1 の C-6。

[Answer]: **維持する** (2026-07-31 ユーザー回答。**仮定どおり**)。**C-6 (Gemini `gemini-2.5-flash-image`) は
変更なしで確定**し、Gemini は LM-D の例外として残る (画像生成は Anthropic に該当機能が無い)。
V-9 は §7.1 の **M-8** に含める (「LM-Q3 の回答後」という条件は解消)。
反映先: §2 の LM-D / §4.2 の V-9 行 / §5.1 の C-6 (確定) / §7.1 の M-8。

**LM-Q4: リサーチシート (V-13。v2 の 6 系統・18 経路) を v3 に移植するか** —
v3 の API 設計 ([API/README.md](API/README.md) §0) に対応するドメインが無く、
プロトタイプにも該当画面が確認できていない (**未調査**)。
**仮定: 移植する** (C-13 + C-11 により v2 に残す選択肢が無いため)。
**移植すると決まった時点で、対応する API 設計のタスクが 1 本増える**。
影響する節: §4.2 / §7.1 の M-9。

[Answer]: **廃止する** (2026-07-31 ユーザー回答。**仮定と逆**)。V-13 は v3 へ移植しない = **廃止**。
**§4.3 の廃止一覧に X-12 を追加**し、**(1) 機能の廃止は 6 件 → 7 件**になった。
**Q0 の 3 条件には当たらない (v2 で稼働中の機能) ため、根拠は「v3 のスコープに入れない」というユーザー判断そのもの**
であり、**ユーザーに見える機能減としてリリースノート / 告知の対象に追加する** (§4.3 の注記)。
対応する API 設計タスクは**増えない** (移植しないため)。
反映先: §4.2 の V-13 行 / §4.3 の件数表・告知の注記・X-12 行 / §5.1 の C-3・C-5 (V-13 を除去) /
§7.1 の M-9 / §7.2 / §10.3 の 1。

**LM-Q5: §8.4 のブラインド A/B の評価者の役割** (誰が 2 名 + 裁定者になるか) —
**仮定 (暫定既定): 当該機能を要求したプロダクト側 1 名 + 開発者 1 名 + 裁定者 1 名**。
影響する節: §8.4 (合否判定の実行主体)。

[Answer]:

**LM-Q6: RAG の埋め込み (C-7) のプロバイダ** — 3 番目のプロバイダ
(OpenAI / Voyage / Gemini 等) が第 1 リリースに入ると、**LM-D の「例外は 2 つ」が崩れる**。
影響: gateway 実装 1 本の追加 (§10.1) / 単価テーブルの行追加 (§5.2) / API キーの Secrets 登録
([operations.md](operations.md) §4.5)。**RAG を第 1 リリースから外す**選択肢も含めて判断する (Q-3 のスコープと連動)。

> **前提の条件節は解消した (2026-07-30 に一次ソースで確認)**:
> **Anthropic は埋め込みモデルを提供していない**。公式ドキュメントが
> 「Anthropic does not offer its own embedding model」と明記し、**Voyage AI を推奨プロバイダとして案内**している
> (`https://platform.claude.com/docs/en/build-with-claude/embeddings`)。API は Anthropic ではなく
> Voyage の別エンドポイント (`https://api.voyageai.com/v1/embeddings`) で、**認証も別の API キー**
> (`VOYAGE_API_KEY`) になる。推奨モデルは `voyage-4-large` (品質) / `voyage-4` (均衡) /
> `voyage-4-lite` (低レイテンシ・低コスト) で、いずれも**コンテキスト長 32,000・次元 1024 (既定)**。
> **したがって「Anthropic に埋め込みがあればそれを使う」という選択肢は存在しない** — 残る判断は
> **①Voyage を 3 番目のプロバイダとして受け入れる** か **②RAG を第 1 リリースから外す** かの
> **スコープ判断のみ**であり、これはユーザー決定 (Q-3 と連動)。
> **暫定既定は後者 (RAG を第 1 リリースから外す)**。
> **①を選ぶ場合に増える作業**: gateway 実装 1 本 (§10.1) / 単価テーブルの行 (§5.2) /
> `VOYAGE_API_KEY` の Secrets 登録 ([operations.md](operations.md) §4.5) /
> **ベクトル格納先の設計** (次元 1024 を前提とした列定義。[data-model.md](data-model.md) のナレッジ系テーブル)

[Answer]: **①を採る = RAG は第 1 リリースに含める。ただし RAG の設計 (プロバイダ選定・gateway・
ベクトル格納先のスキーマ等) は別トピックとして切り出し、`aidlc-planner` で Inception を起票する**
(2026-07-31 ユーザー確認。**暫定既定 (②第 1 リリースから外す) を反転**)。
したがって **3 番目のプロバイダが第 1 リリースに入り、LM-D の例外は「第 1 リリース時点で 3 つ」に改まる**。

> **経緯 (同じ問いに 2 度反映した記録。DR-8 対策として残す)**: 2026-07-31 に一度
> 「**RAG を第 1 リリースから外す**」と解釈して本書へ反映したが、**ユーザーへの再確認で誤りと判明**した。
> 正しい回答は「**リリースはする / 設計を別トピックに切り出す**」であり、
> **「別で設計する」は「別のリリースにする」ではない**。同種の混同を避けるため、
> 本書では**「リリース時期 (= 優先度列・RL 段階)」と「設計の担当トピック」を必ず分けて書く**。

**本書に確定として書けること**:

| # | 確定内容 |
|---|---|
| 1 | **RAG (N-1 / N-2) は第 1 リリースに含める** — §4.1 の優先度は **1**、§7.1 の **M-4 は RL-1**。**第 1 リリースに入る移行段は M-0〜M-4 の 5 つ** |
| 2 | **RAG は「廃止」ではない** — §4.3 の廃止一覧 (X-x) に入れてはならない。ナレッジの API 設計 ([API/knowledge.md](API/knowledge.md)) は有効 |
| 3 | **埋め込みは Anthropic では実現できない** (上記の一次ソース) — **3 番目のプロバイダが第 1 リリースに必ず入る**。候補は Voyage AI (Anthropic 公式の推奨) だが、**選定は別トピックの RAG 設計が行う**。本書は候補として挙げるにとどめる |
| 4 | **N-1 / N-2 の実装形態 (どちらも直接 API) は本書の確定事項** — [API/knowledge.md](API/knowledge.md) の KN-Q2 への回答 (§4.1) は有効であり、別トピックで再判定しない。**別トピックが決めるのは「どう作るか」(プロバイダ・スキーマ・インデックス方式) だけ** |
| 5 | **V-12 (カスタムリサーチ) の統合先 N-1 が第 1 リリースに入る**ため、**V-12 の移送は通常どおり RL-4** (§7.1 の M-9)。切替順序への追加の影響は無い |
| 6 | **依存関係**: **M-4 の着手には埋め込みプロバイダの選定が先行条件**であり、**M-0 の gateway 実装にプロバイダ 1 本が追加**される。したがって**別トピックの起票を M-0 の着手と同時に行う** (遅れると M-4 が RL-3 のクリティカルパスになる。§7.1 の理由 6) |

**別トピック (RAG の設計) に持ち越す項目 (本書からの申し送り)**: ①埋め込みプロバイダの選定
②`gateway/<provider>` 実装 1 本の追加 (§10.1 の gateway 規約に従う) ③単価テーブルへの行追加 (§5.2)
と **[observability.md](observability.md) §4.2 の `route_kind` への値追加の要否**
(`external_search` と同様にトークン課金でない可能性があるため、同節の注記ブロックと同じ判断が必要)
④API キーの Secrets 登録 ([operations.md](operations.md) §4.5 の棚卸し表への追加)
⑤**ベクトル格納先** (次元 1024 前提の列定義・インデックス方式。[data-model.md](data-model.md) のナレッジ系テーブル)
⑥**prod の Anthropic Environment の `allowed_hosts`** に埋め込み API のホストを載せる必要があるか
([operations.md](operations.md) §5.2 の含意 4)
⑦**C-7 の実測の実施** (§5.3 の手順を検索の再現率に読み替えたもの。**プロバイダ選定の直後・RL-3 の前**)。
**⑤⑥は他文書のスキーマ・構成に触るため、別トピックを起票する時点で当該文書へ是正要求を出すこと**。
**本書側の受け皿は用意済み** — C-7 の行 (§5.1)・プロファイル表の列 (§5.2)・M-4 (§7.1)・
gateway の追加箇所 (§10.1) は**プロバイダ名だけを埋めれば成立する形**にしてある。

### 9.2 残課題 (調査が必要 — 推測で埋めない)

| # | 内容 | 影響 |
|---|---|---|
| **LM-R1** | **Exa と Anthropic の web_search / OpenAI の search-preview の検索品質比較データが無い**。C-5 の「Exa 単独」は v2 / PoC の実使用実績に基づく判断で、品質比較の実測ではない | 品質が問題化した場合に C-5 を見直す。§5.3 の枠組みで測れる |
| **LM-R2** | **未配線側 (`prompts/diverge/patterns/*`) と生きている側の文言差の内容が未調査**。「文言が異なり同一挙動ではない」までは判明している ([poc-prompt-inventory.md](../analysis/poc-prompt-inventory.md) §3 の 1) | §6.2 の 1。移植前に差分を読み、有用な指示を取り込む |
| **LM-R3** | **テーマのタグ推定 (X-1) の UI 要件が未確認**。プロトタイプに UI があるかは未調査 | 要件化されたら §4.3 の X-1 と [API/themes.md](API/themes.md) の LLM 列を同時に更新する |
| **LM-R4** | **PoC が使っているモデル名が未調査** ([poc-prompt-inventory.md](../analysis/poc-prompt-inventory.md) はモデル名を対象外にしている)。**したがって「PoC からのモデル変更点」は本書では確定できない** | §5.1。C-1 / C-2 の初期モデルは「v2 に定義済みの Claude 系」を候補にしており、PoC の実効モデルとの一致は未確認 |
| **LM-R5** | **`docs/analysis/llm-model-benchmark.md` が未作成** (§5.3 の記録先) | RL-1 期間に作成する。作成までモデル既定値は「候補」であって確定ではない |
| **LM-R6** | **PoC のアイデア評価 (P-5) と v2 のアイデア評価 (V-2) の評価軸・出力スキーマの差分が未調査** | §6.2 の 4。**LM-Q2 = 統合するで 1 本化は確定した**ので、残るのは「**どちらの軸を採るか**」の調査。**調査の実施主体は会話型アイデア創出の API 設計**であり、その設計の入力になる |
| **LM-R7** | **`CHAT_AGENT_ID` の正式な発行コマンドが未発見** (同 §5)。推測 (確信度高) で「他 3 Agent と同パターン」とされている | **v3 では解消** — LM-Q1 の統合により `CHAT_AGENT_ID` 相当の Agent を発行しないため、発行コマンドを移植する必要がない (§6.3) |
| **LM-R8** | **V-4 / V-5 (アイデアの Web 検索・市場規模 CAGR リサーチ) を統合対象に含めるかが未確定**。2026-07-31 の LM-Q2 の回答が名指ししたのは V-1〜V-3 / V-6 / V-12 のみで、V-4 / V-5 は独立移送のまま据え置いた | §4.2 / §7.1 の M-7。**会話型 API 設計で市場規模調査が P-8 (research_market) の tool に吸収される場合、M-7 は消滅する**。統合の是非はその設計で判定する (本書では畳まない) |
| **LM-R9** | **X-12 (リサーチシート) の機能終了をユーザー告知する項目が [operations.md](operations.md) §6 に無い** — **対応済み (2026-07-31)**: メインセッションが [operations.md](operations.md) **§6.3.1 (切替時のユーザー告知)** を新設し、X-12 を含む告知 4 件を RL-3 の完了条件に紐付けた | ~~是正要求~~ → 解消。**RL-4 のドメイン順序については是正不要** — LM-Q6 の確定 (RAG は第 1 リリースに含む) により、ナレッジと V-12 の切替時期は同書の既存記述どおりになる |

### 9.3 仮定 (違えば §2 の判断が変わる)

1. **PoC の会話型フローが v3 第 1 リリースの中核である**と仮定して §7 の順序を組んだ。
   **2026-07-31 の LM-Q2 (v2 機能を会話型フローへ統合) と LM-Q6 (RAG を別増分) はこの仮定を強める方向の決定**であり、
   第 1 リリースは M-0〜M-3 (会話 + 企画書 + アセット) に絞られた。Q-3 のスコープが変わると M-1〜M-3 の順序が変わる
2. **Managed Agents が Anthropic 提供である**ことを前提に LM-D (Anthropic 主系) を決めた。
   Agent 基盤が変わればプロバイダ方針から見直しになる
3. **v2 の現行実装が本番稼働している = 品質の裏付けがある**と仮定して LM-J (Dify YAML を参照しない) を決めた。
   v2 の現行機能に既知の品質問題がある場合は、YAML との差分調査 (LM-R2 と同種の作業) が必要になる
4. **§5.1 の C-1〜C-4 のモデル候補は「v2 に定義済みの Claude 系」**である。
   新しい世代のモデルが利用可能な場合は §5.3 の実測の候補に加える (プロファイル 1 箇所の変更で入れ替わる)

---

## 10. 実装リポへの引き渡し

> 対応 AC: **AC-4.3**

### 10.1 影響レイヤーと依存順序

| 順 | レイヤー | 作業 | 参照すべき既存実装 |
|---|---|---|---|
| 1 | `config` | LLM プロファイル表 (§5.2)。`feature` キーは [observability.md](observability.md) §4.2 と同一文字列 | v2 の反面教師: `hassan-v2-backend/llm/types.go` (モデル列挙 + 許可リスト) / `hassan-v2-backend/di/wire.go` (env が届かない provider) |
| 2 | `gateway/anthropic` / `gateway/exa` / `gateway/gemini` + **埋め込みプロバイダ 1 本** (**第 1 リリースで計 4 本**。プロバイダの選定は別トピックの RAG 設計 — §9.1 の LM-Q6。**選定待ちでも他 3 本の実装は着手できる**) | `CallMeta` を返す共通エンベロープ (D-B'')。未知モデルはエラー | 構造の手本: `hassan-v2-backend/llm/factory.go` (プロバイダ解決の switch)。**`default: OpenAI` は踏襲しない** / Exa: `hassan-v2-backend/llm/exa/service.go` |
| 3 | `prompts/` | §6.1 のレイアウト。移植元は `claude_managed_agents/prompts/` の **14 ファイル** (全 26 本のうち §4.3 の X-4〜X-7 で廃止する 12 本を除いた分。実測: 同ディレクトリの `*.md` は 26 本) + `hassan-v2-backend/prompt` の該当分。**うち `post_diverge_chat_system.md` は `conversation/orchestrator.md` に統合する** (LM-Q1) ため、**v3 側のファイルは 13 本相当**になる | — |
| 4 | `service/<domain>` | プロンプト構築ロジック (R-3 / R-4)、Runner の安全弁 | PoC: `claude_managed_agents/cmd/devui/conversation_tools.go` (tool ディスパッチ。**構造は移植しない**) |
| 5 | `usecase/<domain>` | 所有者スコープの束縛、`CallMeta` の永続化 | [architecture.md](architecture.md) §3.8.1 |
| 6 | CI | R-2 の文字列リテラル検査 + §8.3 の Q-1〜Q-7 | `scripts/check-tool-contract.sh` ([architecture.md](architecture.md) §3.8.4) |

### 10.2 並列可能なタスク

- §7.1 の **M-1 と M-4** (アセットとナレッジは依存しない。**M-4 は埋め込みプロバイダの選定を待つ**ので、
  選定が遅れる場合は M-1 を先に進める)
- §5.3 の実測 (feature ごとに独立。ゴールデンセットの作成も並列可)
- §6.2 の 1 本化 5 件のうち 2 (research_market) / 3 (情報源ルール) は他と独立

### 10.3 引き渡し物のチェックリスト

| # | 項目 | 状態 |
|---|---|---|
| 1 | 機能別の実装形態表 (§4。行数: PoC 由来 13 + v3 新規 2 + v2 由来 17 / うち**廃止判定は §4.3 の 12 件** = 機能の廃止 7 + 資産・命名の整理 5) | **本書で確定** (2026-07-31 の LM-Q1〜LM-Q4 / LM-Q6 を反映。**Managed Agent 3 / 直接 API 19 / 統合により独立移植しない 6 / 廃止 12**) |
| 2 | 用途カテゴリと初期モデル (§5.1) | **C-1〜C-6 は候補確定** (LM-R4 / LM-R5 の解消で確定に上がる) / **C-7 は第 1 リリースに入る — プロバイダ選定は別トピックの RAG 設計** (LM-Q6) |
| 3 | プロファイル表の列定義 (§5.2) | **本書で確定** |
| 4 | ゴールデンセットの仕様 (件数・選定基準・保管場所。§5.3 / §8.1) | **本書で確定**。実体の作成は実装リポ。**統合された機能は統合元ごとに before を取る** (§8.1) |
| 5 | 移行順序 M-0〜M-9 (§7.1) | **本書で確定**。**第 1 リリースは M-0〜M-4 の 5 つ** (M-4 = ナレッジ RAG を含む — LM-Q6) / **M-5〜M-9 は RL-4** (M-9 は M-4 完了が前提)。統合の詳細は会話型アイデア創出の API 設計に依存 (LM-Q2) |
| 6 | 品質確認の合否条件 (§8.4) | **本書で確定** (評価者の役割は **LM-Q5 待ち** — 本書で唯一残る未回答項目) |
