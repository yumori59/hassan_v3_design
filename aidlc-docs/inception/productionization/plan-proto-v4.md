# Workflow Plan (増分: proto-v4): 評価軸の 3 軸化 と 発散フローの v4 化

> 要件: [requirements-proto-v4.md](requirements-proto-v4.md) (**AC-PV-1.1〜AC-PV-7.3**) /
> 質問: [questions-proto-v4.md](questions-proto-v4.md) (PV-Q1〜PV-Q3 ユーザー確定 / PV-Q4〜PV-Q10 は判断ルール付きで設計へ委譲)
> 親計画: [plan.md](plan.md) / [plan-layering.md](plan-layering.md)
>
> **本計画は設計リポジトリ内の作業のみを対象とする**。実装は別リポジトリで行い、
> [schedule-2026q3.md](../../schedule-2026q3.md) の C-0.4 / C-3 / C-6 が受ける。

## 1. 影響範囲

### 1.1 設計成果物 (このリポジトリ)

| 文書 | 触る節 | 是正要求 ID |
|---|---|---|
| [docs/design/API/ideas.md](../../../docs/design/API/ideas.md) | §2.1 (`Idea.evaluation`) / §2.5 / §2.6 (CSV) / §3.3 (移行写像) / §6.1〜§6.3 (評価軸) / §7 (D-IDA-4 / D-IDA-6 / D-IDA-7) / §8 (是正要求) / §9 (IDA-R7) | R-PV-1 |
| [docs/design/API/conversation.md](../../../docs/design/API/conversation.md) | §2.2 (状態注入) / §4.1 (tool の引数・enum・本数) / §4.4 (A-6 の適用点) / §4.5 (台帳の書き手読み手) / §4.6 (3 者一致検査) / §5.1〜§5.3.1 (SSE) / §7 (設計判断) | R-PV-2 |
| [docs/design/data-model.md](../../../docs/design/data-model.md) | §4.6 (`ideas` の軸カラム) / §4.11.2 (台帳フィールド) | R-PV-3 |
| [docs/design/llm-migration.md](../../../docs/design/llm-migration.md) | §9.2 (LM-R6) / §6.2 の 4 | R-PV-4 |
| [docs/design/API/idea-boards.md](../../../docs/design/API/idea-boards.md) | §2.1 / §3 の D-IB-3 | R-PV-5 |
| [docs/design/frontend.md](../../../docs/design/frontend.md) | `Idea` 型の `evaluation.grade` / §6.2 の S-8 (新イベントを足す場合のみ) | R-PV-6 |
| [docs/design/API/README.md](../../../docs/design/API/README.md) | §3 の総覧 (**本数が変わる場合のみ**) | R-PV-7 |
| [docs/design/API/settings.md](../../../docs/design/API/settings.md) | 評価基準 CRUD = 増分 2 の記載 | R-PV-8 |
| [aidlc-docs/schedule-2026q3.md](../../schedule-2026q3.md) | §2 の P-4 / §3.3 の C-0.4 / §5 の C-3・C-6 | R-PV-9 |
| [docs/prototype/README.md](../../../docs/prototype/README.md) | v4 の位置づけ | R-PV-10 |

### 1.2 本番実装層 (実装リポで動くもの。設計側は「どこが動くか」を書く)

| 層 | 変更 |
|---|---|
| `entity/idea` | **3 軸の重み定数 / アンカーの閾値表 / composite の重み式 / grade のバンド (A/B+/B/C)** — いずれも**副作用のない関数 1 箇所** (BE-2) |
| `entity/conversation` | 台帳フィールドの型 (レンズ / 隣接の起点を持つ場合。BE-12) |
| `entity/` の const 群 | `feature` 値 (増やさない見込み。PV-DF3) |
| `usecase/idea` | 評価ジョブの入力 (ミッションを渡すかの再判定 = AC-PV-1.6) |
| `usecase/conversation` | tool ハンドラのクロージャ (追加探索の引数・隣接の起点の台帳書き込み) |
| `repository/idea` | `ideas` の軸カラムの読み書き (列が変わる場合) |
| DB スキーマ | `ideas` の軸スコア列 (3 軸化)。**テーブル件数は変わらない見込み** |
| LLM / Agent 層 | `prompts/idea/evaluate.md` (3 軸 + サブ基準 9 個) / `prompts/conversation/orchestrator.md` (レンズ 2 階層・追加探索・自由記述質問) / tool schema の enum → **D-6 の Agent 再発行** |
| FE (別担当) | `evaluation.grade` の値域 / 自由記述質問の描画 / 3 軸のレーダー表示 |

### 1.3 本番観点 (08-production-gates) の該当 ID

| ID | 本増分での扱い | 受入基準 |
|---|---|---|
| **D-6** | enum / プロンプト / tool schema の変更 = **Agent 再発行が発生する** | AC-PV-6.1 |
| **O-2** | `feature` 値を増やさない (増える場合は §3.3 の表と const 群を同じ差分で) | AC-PV-6.2 |
| **A-6** | 新しい文字列引数 (隣接の起点 / 追加探索) が所有者スコープの解決に使われないこと | AC-PV-6.3 |
| **O-4** | 評価 JSON の出力規模の変化 → `max_tokens` 切り詰め (BE-6) の再評価 | AC-PV-6.4 |
| **A-1 / A-2 / A-3 / A-4 / A-5 / A-7** | **本増分では変更なし** — 新エンドポイントを作らず (PV-DF2)、所有者境界・ロール・403/404 の判定に触らない。[ideas.md](../../../docs/design/API/ideas.md) §1.3 / §1.4 が有効なまま | — (対象外の理由を設計書に 1 行書く) |
| **O-1 / O-3 / O-5 / O-6 / O-7** | **本増分では変更なし** — ログ項目・コスト集計単位・SSE 切断・監査対象・アラートのしきい値は変わらない | — (同上) |
| **D-1 / D-2 / D-3 / D-4 / D-5 / D-7 / D-8** | **本増分では変更なし**。ただし **D-4 (マイグレーション)** は `ideas` の軸カラムを変える場合に該当 → AC-PV-3.5 で扱う | AC-PV-3.5 (D-4 のみ) |

## 2. 設計判断として残っているもの (起草者が決める。判断ルールは questions が持つ)

| # | 論点 | 判断ルールの所在 |
|---|---|---|
| 1 | 判定ランクの閾値の具体値 | [questions-proto-v4.md](questions-proto-v4.md) PV-Q4 (5 ルール) |
| 2 | レンズ → enum の対応 | 同 PV-Q5 (6 ルール) |
| 3 | 自由記述質問の SSE 表現 | 同 PV-Q6 (4 ルール。既定は新イベントを足さない) |
| 4 | CSV 列・説明文列の扱い | 同 PV-Q7 (4 ルール。既定は列の維持) |
| 5 | 増分 2 の範囲の書き方 | 同 PV-Q8 |
| 6 | 「自分のアイデアから発散」とレンズの関係 | 同 PV-Q9 |
| 7 | レンズ・隣接の起点を台帳に持つか | 同 PV-Q10 (既定は台帳に持つ) |

## 3. 受入基準 → 検証方法

> **設計リポジトリの AC は「設計書の記述」に対する条件**である。したがって検証は
> ①`make check` の機械検査 ②`design-reviewer` の読み合わせ ③使い捨ての grep の 3 つで行う。
> **「実装リポでどう検証するか」の列は、この AC が実装リポの TDD で何のテストになるかを示す** (S-1 の入力)。

### 3.1 評価軸の 3 軸構造

| AC | 設計側の検証 | 実装リポでの検証 |
|---|---|---|
| **AC-PV-1.1** | `ideas.md` §6.3 の主軸の表を数え、行数 == 3 / サブ基準の行数 == 9 を目視 + `grep -c`。9 サブ基準が F-PV2 の名称と 1:1 対応 | `entity/idea` の UT (3 軸の定数と重みの和 == 100) |
| **AC-PV-1.2** | `grep -n '40\|35\|25' ideas.md` で重みの記載箇所が **`entity/idea` の定数を SSOT** と書いているか。DB / settings に持つ記述が 0 件 | `entity/idea` の UT。DB マイグレーションに重みの列が無いことを確認 |
| **AC-PV-1.3** | アンカーの表が軸ごとに存在し、「閾値表で計算する軸」と「LLM が採点する軸」の切り分けが表になっているか | `entity/idea` の閾値表の UT (境界値。v2 の `< 400` の穴を再発させない) |
| **AC-PV-1.4** | 旧 9 軸 (主軸 5 + 補助軸 4) の**全件が表に現れ、行き先が空欄の行が 0 件**。`grep -c` で 9 行を確認 | — (設計上の網羅性。テスト対象外) |
| **AC-PV-1.5** | §6.2 の対照表に「軸として廃止 (2026-08-23 ユーザー承認)」の**承認日つき記述**があるか | — |
| **AC-PV-1.6** | ミッションを渡す / 渡さないの**採用案 + 却下案 + 理由**が揃っているか。「必要に応じて」が 0 件 | `usecase/idea` の評価入力構築のテスト (ミッションが入る / 入らない) |

### 3.2 尺度・判定ランク

| AC | 設計側の検証 | 実装リポでの検証 |
|---|---|---|
| **AC-PV-2.1** | D-IDA-4 が「0.0〜10.0 を維持」のまま。v4 の 3 尺度を採らない理由が行番号付きで書かれている | `entity/idea` の composite の UT (0.0〜10.0 の範囲) |
| **AC-PV-2.2** | 判定ランクの表に**数値の下限値**が入っている。`grep -n '実装時に調整\|適切に\|要検討'` が §6 で 0 件 | `entity/idea` の grade の UT (境界値 4 段) |
| **AC-PV-2.3** | **DR-8 の再検査 grep**: `grep -rn 'A/B/C/D\|grade.*D\b' docs/` の全件を確認し、旧値 `D` が 0 件。波及先 4 文書 + 1 実装層が列挙されている | `entity/idea` の grade 関数が 1 箇所であることの検査 (発散側と評価側が同じ関数) |
| **AC-PV-2.4** | `+` を含む値の 3 論点 (OpenAPI enum / CSV / URL クエリ) それぞれに決定が書かれている | Controller のテスト (`?grade=B%2B` のデコード) |

### 3.3 C-16 と既存データ

| AC | 設計側の検証 | 実装リポでの検証 |
|---|---|---|
| **AC-PV-3.1** | `grep -n '合計 ÷ 4\|4 軸の平均' docs/design/API/ideas.md` が **0 件**。新しい移行規則が §3.3 にある | 移行スクリプトのテスト (v2 の 4 スコア → 3 軸) |
| **AC-PV-3.2** | 説明文列の扱いに採用案 + 却下案 + 理由。落とす案なら「§3.2 の承認欄への追記が必要」の記述がある | `repository/idea` のテスト (列に何が入るか) |
| **AC-PV-3.3** | §2.6 の列の表の行数と「16 列」の自称値が一致。変える場合は対応表 + リリースノート告知の記載 | CSV 生成のテスト (列数と列名) |
| **AC-PV-3.4** | 「v3 の既存評価データは 0 件」の根拠が **schedule の C-6 への出典付き**で書かれている | — |
| **AC-PV-3.5** | `make check-table-counts` が通る。`data-model.md` §4.6 の `ideas` の軸カラムが 3 軸 | マイグレーションの適用・ロールバックのテスト (D-4) |

### 3.4 発散フロー

| AC | 設計側の検証 | 実装リポでの検証 |
|---|---|---|
| **AC-PV-4.1** | 2 階層の表があり、第 1 階層 3 種・第 2 階層 3 種 × 2 経路。**「4 種」という記述が 0 件** (`grep -n 'レンズ 4' docs/design/`) | orchestrator プロンプトの検査 (レンズ値の集合) |
| **AC-PV-4.2** | enum の対応表がある。`industry_mode` の 2 値の「残す / 廃止」が明示。D-6 への言及がある | `scripts/check-tool-contract.sh` の検査 3 (schema ↔ ハンドラ ↔ プロンプトの 3 者一致) |
| **AC-PV-4.3** | `make check-endpoint-mapping` が通る (検査⑤ の tool 本数)。本数を変えない場合はその判定理由がある | 起動時チェック 1・2 (tool 名集合) |
| **AC-PV-4.4** | 新イベントを足す場合、§5.1 / §5.3 / §5.3.1 / `frontend.md` §6.2 の **4 箇所すべてに記述がある** (`grep -c` で確認)。足さない場合は却下理由がある | SSE デコーダのテスト (discriminated union) |
| **AC-PV-4.5** | 追加探索の引数 / 新 tool の判定 + append の重複除外キー + 冪等性の記述 | `research_market` ハンドラのテスト (2 回呼んで重複しない) |
| **AC-PV-4.6** | 台帳フィールドの**書き手と読み手が対で**書かれている。`data-model.md` §4.11.2 の表に行がある | 台帳フィールドの書き手存在検査 (`data-model.md` §4.11.2 の CI 検査 4) |
| **AC-PV-4.7** | `seed_idea` 経路のレンズ既定値が書かれている | `generate_ideas` ハンドラのテスト |

### 3.5 廃止された UI 部品・本番観点・増分 2

| AC | 設計側の検証 | 実装リポでの検証 |
|---|---|---|
| **AC-PV-5.1** | 発散設計ウィジェットを採らない旨 + 代替の指定方法。F-PV15 の引用がある | — |
| **AC-PV-5.2** | `data-model.md` §4.11.2 の `seed_idea` の理由が**ボタンに依存しない書き方**になっている (`grep -n '再発散' docs/design/data-model.md` の全件確認) | — |
| **AC-PV-5.3** | 残骸 5 種のうち `strategyFitScore` と `overallScore: 32` の 2 つに**行番号付きの非採用理由**がある | — |
| **AC-PV-6.1** | D-6 の記述が `operations.md` §5.2 と schedule の H-3 の 2 つに対応づいている | デプロイ手順 (Agent 再発行の停止点) |
| **AC-PV-6.2** | `feature` 値の増減が明記。増える場合は §3.3 の表と const 群の両方に記述 | `observability.md` §4.2 の `feature` const 存在検査 |
| **AC-PV-6.3** | §4.4 の「ツール別の適用点」表に新しい引数の行がある | 全 tool のテナント越境テスト (C-3 の④) |
| **AC-PV-6.4** | `max_tokens` の再評価の記述があり、**数値が設計書に書かれていない** (`config` が SSOT) | `stop_reason == max_tokens` の検出テスト |
| **AC-PV-6.5** | `make check` が全ゲート緑。**新しく増えた「N 件」が検算対象に入っているか**を Task-PV-7 で確認 | — |
| **AC-PV-6.6** | `llm-migration.md` §9.2 の LM-R6 が再オープン → 再クローズの形。5 軸の旧結論が 0 件 | — |
| **AC-PV-7.1** | 増分 2 の 3 項目が名指しで列挙され、各項目に理由と先送り先 | — |
| **AC-PV-7.2** | 増分 2 への移行時の 3 論点 (SSOT の移動先 / 採点時の重みの記録 / キャッシュ) に記述がある。「後で検討」が 0 件 | — |
| **AC-PV-7.3** | 対象外の 3 領域が列挙されている | — |

## 4. タスクと依存関係

### 4.1 直列必須

```
Task-PV-0 (事実確定。完了)
   └→ Task-PV-1 (ideas.md: 3 軸の SSOT を作る)
         ├→ Task-PV-5 (data-model.md の軸カラム)   ← どの列を持つかが PV-1 で決まる
         └→ Task-PV-6 (llm-migration.md の LM-R6)  ← 結論を転記する
   └→ Task-PV-2 (conversation.md: 発散フロー)
         └→ Task-PV-7 (機械検算の期待値確認)      ← tool 本数・enum が PV-2 で決まる
   全タスク完了 → Task-PV-R (design-reviewer。別セッション)
```

**直列にする理由**: ①**同一ファイルの同時編集を避ける** (rule 03) ②**PV-1 が 3 軸の SSOT**であり、
data-model / llm-migration はその転記先である (上流が変わると下流が無効になる)。

**Task-PV-1 と Task-PV-2 は並列にできる** — `grade` の値域と総合スコアの尺度という**両者が共有する決定を
requirements の AC-PV-2.1 / AC-PV-2.2 / AC-PV-2.3 で先に固定した**ため、起草者どちらも同じ入力を持つ。

### 4.2 並列実行可能なタスク

| Task | 内容 | 対象ファイル・節 | 参照 AC | 担当 |
|---|---|---|---|---|
| **Task-PV-1** | **評価の 3 軸化**の起草 | `docs/design/API/ideas.md` §2.1 / §2.5 / §2.6 / §3.3 / §6.1〜§6.3 / §7 / §8 / §9 | AC-PV-1.1 / AC-PV-1.2 / AC-PV-1.3 / AC-PV-1.4 / AC-PV-1.5 / AC-PV-1.6 / AC-PV-2.1 / AC-PV-2.2 / AC-PV-2.4 / AC-PV-3.1 / AC-PV-3.2 / AC-PV-3.3 / AC-PV-3.4 / AC-PV-6.4 / AC-PV-7.1 / AC-PV-7.2 | `architecture-designer` |
| **Task-PV-2** | **発散フローの v4 化**の起草 | `docs/design/API/conversation.md` §2.2 / §4.1 / §4.4 / §4.5 / §4.6 / §5.1〜§5.3.1 / §7 / §8 | AC-PV-4.1 / AC-PV-4.2 / AC-PV-4.3 / AC-PV-4.4 / AC-PV-4.5 / AC-PV-4.6 / AC-PV-4.7 / AC-PV-5.1 / AC-PV-5.3 / AC-PV-6.1 / AC-PV-6.2 / AC-PV-6.3 | `architecture-designer` |
| **Task-PV-3** | **表示側の型の追従** — `grade` の値域変更 | `docs/design/API/idea-boards.md` §2.1 / §3 の D-IB-3、`docs/design/frontend.md` | AC-PV-2.3 | `architecture-designer` (軽量) |
| **Task-PV-4** | **増分 2 の受け皿とプロトタイプの位置づけ** | `docs/design/API/settings.md`、`docs/prototype/README.md` | AC-PV-7.1 / AC-PV-7.3 | 手動 |
| **Task-PV-8** | **スケジュールへの反映** | `aidlc-docs/schedule-2026q3.md` §2 の P-4 / §3.3 の C-0.4 / §5 の C-3・C-6 | AC-PV-6.1 / AC-PV-6.5 | 手動 |

**Task-PV-3 / Task-PV-4 / Task-PV-8 は Task-PV-1 / Task-PV-2 と同時に走らせてよい** —
触るファイルが重ならず、依拠する決定 (`grade` の値域 / 増分 2 の 3 項目 / D-6 の発生) は
すでに requirements で固定されている。

### 4.3 上流完了後のタスク

| Task | 内容 | 対象 | 参照 AC | 担当 |
|---|---|---|---|---|
| **Task-PV-5** | `ideas` の軸カラムと台帳フィールドの反映 | `docs/design/data-model.md` §4.6 / §4.11.2 | AC-PV-3.5 / AC-PV-4.6 / AC-PV-5.2 | `architecture-designer` |
| **Task-PV-6** | **LM-R6 の再オープン → 3 軸で再クローズ** | `docs/design/llm-migration.md` §9.2 / §6.2 の 4 | AC-PV-6.6 | `architecture-designer` (軽量) |
| **Task-PV-7** | **機械検算の期待値確認** — tool 8 本 / エンドポイント 145 本 / 403 の 16 本 / CSV 16 列 / テーブル件数。**新しく増えた「N 件」が検算対象に入っているか**も見る。**実施結果 (2026-08-23)**: ①〜③⑤は不変を確認。**④ CSV 16 列は検算対象外と判明** (レビュー重大 2) → `scripts/check-endpoint-mapping.sh` に**検査⑨を新設**し故障注入 4 種で検出確認。回答は `docs/design/API/ideas.md` §2.6.1 に記載 | `docs/design/API/README.md` §3 (変わる場合のみ)、`scripts/check-*.sh` の期待値 | AC-PV-6.5 | 手動 |
| **Task-PV-R** | **レビュー** (別セッション。自己レビュー禁止) | `main...HEAD` の全差分 → `aidlc-docs/reviews/productionization/review-proto-v4.md` | 全 AC | `design-reviewer` |

### 4.4 調査タスク (現時点では不要)

**本増分に `poc-analyst` の調査タスクは置かない**。理由:

- v4 プロトタイプの事実は planner が 2026-08-23 に実測済み (requirements §2.1 の F-PV1〜F-PV15)
- PoC の会話フローの事実は [poc-conversation-flow.md](../../../docs/analysis/poc-conversation-flow.md) が
  2026-07-29 に実測・抜き取り検証済み。**再調査しない**
- v2 の評価軸の事実は [ideas.md](../../../docs/design/API/ideas.md) §6.1 / §6.2 に出典付きで揃っている

**調査が必要になる契機**: 起草中に「v2 の閾値表を 3 軸のサブ基準 (収益性 / 参入障壁 / 競合密度 / TRL /
認証リードタイム / 組織リソース) に流用できるか」を判断する場面で、**v2 に該当する計算が存在するかが分からない**
場合。そのときは `poc-analyst` に **`hassan-v2-backend/util/` と `hassan-v2-backend/prompt/idea/` の限定調査**を
1 本だけ出す (推測で埋めない)。

## 5. 名前空間の衝突確認 (DR-6 の 2026-08-04 教訓)

**AC 接頭辞 `PV` の採用前に実行したコマンドと結果** (2026-08-23):

```bash
# ① 既存の AC 名前空間
grep -rohE '\bAC-([A-Z]{2,})-[0-9]+' docs/ aidlc-docs/ templates/ .claude/ scripts/ \
  | sed -E 's/AC-([A-Z]+)-.*/\1/' | sort | uniq -c
#   → 292 CV   (CV のみ。他の接頭辞は存在しない)

# ② 数字直結の AC
grep -rohE '\bAC-[0-9]+(\.[0-9]+)?' docs/ aidlc-docs/ | sed -E 's/AC-([0-9]+).*/\1/' | sort -n -u
#   → 1 2 3 4 5 6 7

# ③ PV 接頭辞そのものの衝突 (AC 以外の ID 体系との衝突も見る)
grep -rn 'PV-[0-9]' docs/ aidlc-docs/ templates/ .claude/ scripts/ Makefile
#   → 0 件
```

**判定**: `AC-PV-*` は衝突しない。`PV-Q*` / `PV-D*` / `PV-DF*` / `F-PV*` / `R-PV*` も 0 件だった。

**検査スクリプトが拾うことの確認 (故障注入)**: `scripts/check-traceability.sh` の AC 抽出正規表現は
`\bAC-([A-Z]{2,}-)?[0-9]+(\.[0-9]+)?` で、**`PV` は `[A-Z]{2,}` に一致する**。
実際に拾うことは §7 の手順で故障注入して確認した。

**実装リポ側の同型の穴 (F-PV33)**: [schedule-2026q3.md](../../schedule-2026q3.md) の **P-4** は
「AC カタログが `AC-CV-*` を 1 件も拾っていない」を未解決として記録している
(`sync-ac-catalog.sh` が読むのが `aidlc-docs/inception/*/requirements.md` 固定)。
**`AC-PV-*` も同じ穴に落ちる**。**Task-PV-8 で P-4 の記述に `AC-PV-*` を追記する**。

## 6. 完了の定義 (Design Freeze)

1. **`make check` が通る** (`doc-lint` / `check-traceability` / `check-table-counts` /
   `check-endpoint-mapping` / `check-template-sync` / `check-workflow-shell` / `check-monorepo-ci`)
2. **本番観点への回答が揃っている** — D-6 / O-2 / A-6 / O-4 に設計上の回答があり、
   **変更なしとした ID (A-1〜A-5 / A-7 / O-1 / O-3 / O-5〜O-7 / D-1〜D-3 / D-5 / D-7 / D-8) には
   「本増分では変更なし」の 1 行がある** (§1.3。無言の省略にしない = DR-2)
3. **`design-reviewer` (別セッション) のレビューで重大ゼロ** — 結果は
   `aidlc-docs/reviews/productionization/review-proto-v4.md`
4. **DR-8 の再検査 grep を実行し、出力を証拠として報告に含める** — キーワード:
   `5 軸` / `主軸` / `novelty` / `mission_fit` / `A/B/C/D` / `合計 ÷ 4` / `レンズ 4` / `再発散` /
   状態語 (`未了` / `未実装` / `未設定` / `含まれていない` / `是正要求`)
5. **実装リポへの引き渡し情報が揃っている** — §1.2 の影響レイヤー / §4 の依存順序 /
   参照すべき v2 既存実装 (`hassan-v2-backend/util/score_calculator.go`) / D-6 の停止点

## 7. 故障注入による検査の確認 (P-4 の同型の穴を作らない)

**「検査が通った」は「検査が対象を見た」を意味しない** (DR-6)。本増分の AC 体系について次を実施した:

| # | 注入 | 期待 | 結果 |
|---|---|---|---|
| 1 | `requirements-proto-v4.md` の AC を 1 件だけ plan / 設計書から参照されない状態にする | `check-traceability` が**未カバー**として `exit 1` | §8 の実行ログで確認 |
| 2 | 接頭辞を `AC-P4-*` のような**数字を含む形**にした場合 | 正規表現 `[A-Z]{2,}` に一致せず**拾われない** — したがって `PV` (英字のみ) を採用した | 設計時に回避 |

## 8. ハンドオフ (委譲プロンプトの骨子。7 要素 = `06-delegation-prompts.md`)

### Task-PV-1 (`architecture-designer`)

1. **目的/背景**: v4 プロトタイプの 3 軸評価をユーザーが採用決定した (2026-08-23)。
   本タスクの出力は実装リポの C-6 (評価・CSV。9/22〜9/23) の入力になる
2. **対象**: `/Users/yuyamorishita/aillio/hassan/hassan_v3/docs/design/API/ideas.md` の
   §2.1 / §2.5 / §2.6 / §3.3 / §6.1〜§6.3 / §7 / §8 / §9。
   入力は `aidlc-docs/inception/productionization/requirements-proto-v4.md` §2 の F-PV1〜F-PV24
3. **やること**: AC-PV-1.1〜AC-PV-1.6 / AC-PV-2.1 / AC-PV-2.2 / AC-PV-2.4 / AC-PV-3.1〜AC-PV-3.4 /
   AC-PV-6.4 / AC-PV-7.1 / AC-PV-7.2 を満たす記述にする (各 AC を番号で参照して書く)
4. **従うべき既存例**: 同書 §6.2 の対照表の書式 (v2 / PoC / v3 / 採否の理由の 4 列) と §7 の設計判断の書式
   (採用案 / 却下案 / 理由)
5. **制約**: **PV-D1〜PV-D3 を覆さない** / **D-IDA-4 (0.0〜10.0) を変えない** /
   **プロトタイプの残骸 (F-PV6) を採らない (DR-7)** / **重みを DB や settings に持たせない** /
   参照リポジトリは読み取り専用 / **件数を新しく転記しない (DR-9)**
6. **完了条件**: `make doc-lint` と `make check-traceability` が通る。
   §3.1 / §3.2 / §3.3 の「設計側の検証」欄の grep を実行して 0 件を確認する
7. **報告**: 日本語で ①変更した節 ②実行した検証コマンドと出力 ③残課題・要確認

### Task-PV-2 (`architecture-designer`)

上と同型。対象は `docs/design/API/conversation.md`。**特に注意する制約**:

- **レンズは 2 階層 (3 種 × 2 経路)。単一の 4 値 enum にしない** (F-PV9 / AC-PV-4.1)
- **`LENS_META` の「主軸」4 種は死にコードに近い。採らない** (F-PV6)
- **tool を増やさない方向が既定** (CV-D5)。増やす場合は `check-endpoint-mapping` の検査⑤ の期待値も直す
- **CV-D13 (サーバ注入の廃止) を維持する** — 新しい引数も schema に宣言したものだけ
- **enum 変更は D-6 の Agent 再発行を伴う** (AC-PV-6.1)

### Task-PV-R (`design-reviewer`。別セッションで呼ぶ)

- 対象: `main...HEAD` の全差分
- 保存先: `aidlc-docs/reviews/productionization/review-proto-v4.md`
  (**push ゲートが要求する**。変更した設計成果物の**リポジトリ相対パスを本文に書く**)
- **本番基準で見る** (PoC 基準に引きずられない)。特に **DR-7 (プロトタイプを仕様として扱う)** と
  **DR-8 (修正の波及漏れ)** と **DR-9 (件数の転記)** を重点に見る
</content>
</invoke>
