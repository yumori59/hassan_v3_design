# 設計書の索引 (実装リポの開発者・AI 向け)

> **この索引の目的**: `docs/design/` は**ファイル数・行数ともに 1 セッションで読み切れない規模**にある
> (実測は `ls docs/design/*.md docs/design/API/*.md | wc -l` と
> `cat docs/design/*.md docs/design/API/*.md | wc -l`)。
> **件数をここに書かない** — 2026-08-05 まで「18 ファイル・約 12,000 行」と書かれており、
> 実測 (22 ファイル・15,170 行) から乖離していた (DR-9)。
> **1 つの実装タスクに必要なのはその一部**であり、全部を読むと context を使い切る。
> 本書は「**何を作るか → どのファイルのどの節を読むか**」の対応表である。
>
> **本書に設計内容を書かない** (SSOT を割らないため)。ここにあるのは索引だけ。

---

## 1. まず読むもの (どのタスクでも共通・約 250 行)

| # | 読むもの | 何が書いてあるか |
|---|---|---|
| 1 | [architecture.md](architecture.md) **§3.3 / §3.4 / §3.5** | **6 パッケージ層の責務**と**層配置の判断基準 (4 問の決定木)**・**依存規則 L-1〜L-6**。「この処理をどの層に置くか」で迷ったらここ |
| 2 | [API/README.md](API/README.md) **§2** | **API の共通規約** — 認証の適用範囲 / エラー形 / ページネーション / ソート・検索 / **ステータスコードの使い分け (§2.5)** |
| 3 | [auth.md](auth.md) **§6.3 / §6.4 / §6.6** | **所有者列の持たせ方**・**クエリ側の許可リスト**・**401/403/404 の判定規則**。テナント境界を壊さないための最低限 |
| 4 | [architecture.md](architecture.md) **§3.11** | **リポジトリ構成 (app モノレポ + infra リポ)** と、**モノレポ化で新規に必要になった 6 機構 MR-1〜MR-6**。特に **MR-3 (`api/openapi.yaml` の再生成漏れ検査)** と **MR-6 (破壊的 API 変更は PR を分ける)** は、知らずに作業すると PR がマージできない / 順序を壊す |

**この 4 つを読まずに書くと、層違反・所有者条件の欠落・ステータスコードの不統一・契約の非同期が確実に出る**。

---

## 2. 作るものから引く (タスク種別 → 読むファイル)

### バックエンド: ドメイン API を 1 本実装する

| 読む順 | ファイル | 範囲 |
|---|---|---|
| 1 | `API/<ドメイン>.md` | **§2 のエンドポイント表** (入出力・ステータス) と **§3 の設計判断**。担当ドメインのファイルだけでよい |
| 2 | [data-model.md](data-model.md) **§4 の該当テーブル** | 列・FK・インデックス・一意制約。**§4.1.1 の表で自分のテーブルを引く** |
| 3 | [testing.md](testing.md) **§4 (層ごとのモック境界) / §6** | どの段で何を担保するか。**§6 のテナント越境テストは全 route で必須** |
| 4 | [observability.md](observability.md) **§4.1** | 構造化ログの必須フィールド |

**ドメインと設計書の対応**: テーマ = [API/themes.md](API/themes.md) / アセット = [API/assets.md](API/assets.md) /
ナレッジ = [API/knowledge.md](API/knowledge.md) / アイデアボード = [API/idea-boards.md](API/idea-boards.md) /
お知らせ = [API/news.md](API/news.md) / 設定 = [API/settings.md](API/settings.md) /
**会話型アイデア創出** = [API/conversation.md](API/conversation.md) /
**アイデア (参照・人手編集・版・タグ・評価)** = [API/ideas.md](API/ideas.md) /
**企画書** = [API/plans.md](API/plans.md) /
**認証・アカウント基盤** = [API/auth-accounts.md](API/auth-accounts.md)
(**1 リクエストが層をどう通るか・サインインの分岐は [auth.md](auth.md) §6.13 のシーケンス図**)。
**総覧 (どのエンドポイントがどのファイルか) は [API/README.md](API/README.md) §3**。

### バックエンド: LLM を呼ぶ処理を実装する

| 読む順 | ファイル | 範囲 |
|---|---|---|
| 1 | [llm-migration.md](llm-migration.md) **§4** | **その機能が Managed Agent か直接 API か**。§3 は判定手順なので、既に §4 の表に載っていれば読まなくてよい |
| 2 | [architecture.md](architecture.md) **§3.8** | LLM 呼び出しの層 (`gateway/` 経由が必須) と所有者スコープの強制点 |
| 3 | [observability.md](observability.md) **§4.2 / §4.3** | **全 LLM 呼び出しで記録する項目**と失敗 5 分類 |
| 4 | [llm-migration.md](llm-migration.md) **§5.1** | 用途カテゴリごとのモデル選択 (`config` の 1 表が SSOT) |

### バックエンド: DB マイグレーションを書く

[data-model.md](data-model.md) **§6.1 (ツール = psqldef) / §6.3** → [operations.md](operations.md) **§7.4 (自動適用の範囲・破壊的変更の 3 段階リリース)**。

### フロントエンド

| 読む順 | ファイル | 範囲 |
|---|---|---|
| 1 | [frontend.md](frontend.md) **§2 (設計判断 FE-A〜FE-N) / §3 (依存方向)** | トークンの持ち方・BE 呼び出し経路・ディレクトリ規約 |
| 2 | [frontend.md](frontend.md) **§11.1** | **画面 → ルート → API の対応表**。実装する画面の行を引く |
| 3 | [frontend.md](frontend.md) **§9** | **エラー表示の分岐** (401 の分類 T / C は間違えると強制ログアウトになる) |
| 4 | 対応する `API/<ドメイン>.md` §2 | 呼ぶ API の入出力 |

### インフラ / デプロイ

[infrastructure.md](infrastructure.md) **§3 (構成要素) / §4 (Terraform と ecspresso の分担)** →
[operations.md](operations.md) **§5 (デプロイ手順) / §4 (シークレット)**。

### テストを書く

[testing.md](testing.md) **§3 (4 段の担保範囲) / §4 (層ごとの方針)**。
**§6 (テナント越境) と §10 (必須テストの存在検査) は CI が機械強制する**ので必ず読む。

---

## 3. 読まなくてよいもの (実装時)

**設計書には実装に不要な情報も入っている**。以下は**設計プロセスの記録**なので、実装タスクでは飛ばしてよい:

| 飛ばしてよい | 理由 |
|---|---|
| **各書の「§1 現状 (v2 / PoC)」** | 移植元の事実。**移植タスクを担当するときだけ**読む |
| **設計判断の「却下案と理由」列** | なぜその形かの記録。**採用案の列だけ読めば実装できる** |
| **「是正要求」の節** (`R-*` の表。auth-accounts.md §5 など) | 他の設計書への申し送りであり、実装者宛てではない。**「未対応」と書いてあっても実装をブロックしない** |
| **`[Answer]:` が空の項目** | **未確定。ここに当たったら実装せず設計リポへ差し戻す** ([01-construction-loop.md](../../templates/shared/.claude/rules/01-construction-loop.md) の **S-3** — 「設計書に無いパターンに到達したら昇格ではなく差し戻しを先に判定する」) |

---

## 4. 迷ったときの原則

- **設計書どうしが食い違っていたら実装で辻褄を合わせない** — 設計リポ (hassan_v3) に差し戻す。
  食い違いは**設計の欠陥**であり、実装側で片方に寄せると SSOT が壊れる
- **SSOT がどこかは各書の冒頭 (「§0 本書の位置づけと SSOT 境界」) に書いてある** — 同じ話題が 2 箇所にあるように見えたら、そこを読む
- **v2 に存在した機能を落とさない** ([../../aidlc-docs/inception/productionization/requirements.md](../../aidlc-docs/inception/productionization/requirements.md) の **C-16**)。
  設計書に無くても v2 にあるなら、**実装を省く前に差し戻す**

---

## 5. ファイル一覧 (行数は目安。2026-08-01 時点)

| ファイル | 主題 | 実装時に読む頻度 |
|---|---|---|
| [architecture.md](architecture.md) | 層構造・依存規則・トランザクション境界・**リポジトリ構成 (§3.11)** | **高** (§3 は毎回) |
| [API/README.md](API/README.md) | API 共通規約・エンドポイント総覧 | **高** (§2 は毎回) |
| [auth.md](auth.md) | 認証・テナント境界・権限・秘密の扱い | **高** (§6 の該当節) |
| [data-model.md](data-model.md) | 全テーブル定義・採番・移行 | **高** (該当テーブル) |
| [API/*.md](API/README.md) (**ドメインごとに 1 ファイル**。一覧と本数は [API/README.md](API/README.md) §3 の総覧が正) | ドメインごとの入出力仕様 | 担当ドメインのみ |
| [testing.md](testing.md) | テストの段・モック境界・CI 検査 | 中 |
| [observability.md](observability.md) | ログ・LLM 計測・監査・アラート | 中 |
| [frontend.md](frontend.md) | FE の構造・ルート・エラー表示 | FE 担当のみ |
| [llm-migration.md](llm-migration.md) | 機能ごとの LLM 実装形態・モデル | LLM を触るときのみ |
| [operations.md](operations.md) | 環境・シークレット・デプロイ・切替 | インフラ / リリース時 |
| [infrastructure.md](infrastructure.md) | AWS 構成・IaC の範囲 | インフラ時 |
| [design_memo.md](design_memo.md) | **ユーザーの生メモ (設計の一次要求)** | 参照のみ。**仕様ではない** |
| [../prototype/](../prototype/README.md) | UI プロトタイプ | **設計入力であって仕様ではない** (DR-7)。**UI が無いことも仕様ではない** |
