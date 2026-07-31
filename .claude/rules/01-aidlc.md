# Rule 01: AIDLC ベース設計 (設計リポ版)

## 原則

このリポジトリでの作業は **AIDLC の Inception フェーズを基本フロー**とする。
実装 (Construction) は別リポジトリで行うため、ここでの完了条件は
「コードが動くこと」ではなく **「実装リポへ渡せる粒度で設計が確定していること」**。

```
Inception:     Requirements Analysis → Workflow Planning → Design Freeze
                (questions.md → requirements.md → plan.md → docs/design/*.md)
(別リポジトリ)  Construction: Test First (Red) → Code Generation (Green) → Build & Test
```

## 必須

- 新機能・大きな設計判断・複数ドキュメントにまたがる変更は、**必ず `aidlc-planner` を最初に呼ぶ**
- 仕様確認は **`[Answer]:` タグ付きの専用ファイル**に証跡を残す。軽い確認は `AskUserQuestion` で
  即時取得してよいが、**確定回答はファイルへ書き戻す**
- **Requirements Analysis 完了前に `docs/design/` の設計を確定させない** (下書きは可)
- 受入基準には **AC-ID** を振り、plan.md / 設計書から参照する (`make check-traceability` が照合)
- **設計は「事実 → 判断 → 決定」の順で書く**。事実 (PoC / v2 の現状) には出典を、
  判断には却下案と理由を、決定には影響範囲を添える

## Design Freeze (設計リポ固有の完了条件)

設計を「確定」と宣言する前に、次を満たすこと:

1. `make check` が通る (リンク切れ・参照先不在ゼロ、AC 未カバーゼロ)
2. **`08-production-gates.md` の 3 領域**に対する設計上の回答が書かれている
   (認証・テナント分離・権限 / 可観測性・LLM コスト / CI/CD・デプロイ・IaC)。
   「本増分では対象外」とする場合も、**理由と先送り先を明記**する (無言の省略は不可)
3. 別セッションの `design-reviewer` レビューで重大事項ゼロ (`04-review.md`)
4. 実装リポへの引き渡し情報が揃っている: 影響レイヤー・依存順序・並列可能タスク・
   参照すべき v2 既存実装 (リポジトリ相対パス:行)

## 省略可

- 誤字修正・表記ゆれの統一
- 既存ドキュメントの節の並べ替え・リンク追加のみ
- 事実の追記 (出典付きで、既存の設計判断を変えないもの)

これらは planner を通さず直接編集してよい。ただし `make doc-lint` は必ず通す。

## 産物の命名規約 (固定)

| 産物 | パス | 増分がある場合 |
|---|---|---|
| 構想 | `aidlc-docs/inception/<feature>/concept.md` | — |
| 質問 | `aidlc-docs/inception/<feature>/questions.md` | `questions-<increment>.md` |
| 要件 | `aidlc-docs/inception/<feature>/requirements.md` | `requirements-<increment>.md` |
| 計画 | `aidlc-docs/inception/<feature>/plan.md` | `plan-<increment>.md` |
| レビュー | `aidlc-docs/reviews/<feature>/review.md` | `review-<increment>.md` |
| 確定設計 | `docs/design/<topic>.md` | 章を追記 (別ファイルに分裂させない) |
| 現状分析 | `docs/analysis/<topic>.md` | 同上 |

`make new-feature F=<name>` でディレクトリと questions.md の雛形を作れる。

詳細な各フェーズ手順は `.aidlc-rule-details/` を参照。
