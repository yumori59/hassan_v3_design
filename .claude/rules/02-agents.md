# Rule 02: エージェント使用

## 原則

作業は**該当するエージェントを使用して実行する**。呼び出し時の**プロンプトの書き方 (7 要素テンプレート)**
は `06-delegation-prompts.md` に従う。

## 場面別使用エージェント

| 場面 | エージェント | 役割 |
|---|---|---|
| 要件整理・計画 | `aidlc-planner` | Inception 駆動、questions/requirements/plan の生成 |
| PoC / v2 の事実収集 | `poc-analyst` | 参照リポジトリを読み、出典付きの事実を返す (**設計判断はしない**) |
| アーキテクチャ・設計書の起草 | `architecture-designer` | `docs/design/` の設計判断 (採用案 + 却下案 + 影響範囲) |
| 設計確定前・push 前のレビュー | `design-reviewer` | 第三者視点。本番観点 (08) と頻出パターンの機械的チェック |
| 構想資料 (concept.md) | メインセッション + `writing-concept-docs` skill | ユーザーとの合意形成を伴うため委譲しない |

## モデル振り分け

| エージェント | 既定 model | 理由 |
|---|---|---|
| `aidlc-planner` | opus | 要件構造化・設計分岐の判断。成果物全体を左右する |
| `architecture-designer` | opus | 前例のない設計判断・トレードオフの評価 |
| `design-reviewer` | opus | 見落とし (False Negative) コストが最大。実装前に潰せる唯一の関門 |
| `poc-analyst` | sonnet | 探索と事実抽出が主 (判断を含まない)。`effort: medium` |

**デエスカレーション**: 軽微な差分 (誤字・リンク追加・節の並べ替え) のレビューは
`design-reviewer` に `model: sonnet` を明示指定してよい。原則は「**reviewer は起草者の tier 以上**」。

**エスカレーション**: `poc-analyst` でも「複数経路の挙動差を判定する」「移行可否を左右する事実の確定」を
含む調査は `model: opus` を明示指定する。

## 重要な分離

- **起草エージェントとレビューエージェントは別セッション** で呼ぶ (自己レビューは目的外)
- `poc-analyst` は**事実だけを返す**。「本番ではこうすべき」は `architecture-designer` /
  メインセッションの仕事。分離しないと、推測が事実として設計に混入する
- `design-reviewer` は **PoC 基準ではなく本番基準**で見る (`08-production-gates.md`)。
  「PoC では対象外だった」は設計の省略理由として認めない

## 使用しすぎないこと

- **1 トピックあたり planner → analyst/designer (×N 並列) → reviewer の 3 段で完結**
- 単純なファイル読み取り・grep はエージェント不要 (メインで直接やる方が速く正確)
- 参照リポジトリを 1 ファイル読むだけなら委譲しない。**3 ファイル以上の横断探索から委譲を検討**

## エージェント定義

`.claude/agents/` を参照。実装リポ用の `go-developer` / `react-developer` / `code-reviewer` は
`templates/app-monorepo/backend/.claude/agents/` · `templates/app-monorepo/frontend/.claude/agents/` にある (このリポジトリでは使わない)。
