# CLAUDE.md

**hassan_v3 — 本番化のための設計リポジトリ**。PoC (`claude_managed_agents`) で検証済みの
「テーマ管理 × アセット管理 × 会話型アイデア創出」を、**本番システムとして再構築するための設計・仕様・
移行計画**をここで確定させる。**このリポジトリに製品コードは置かない** (実装は別リポジトリで行い、
本リポジトリの設計成果物と `templates/` (backend / frontend / infra の 3 セット) のハーネス雛形を引き渡す)。

## 本番アーキテクチャの方針 (ハイブリッド)

ユーザー指定の技術スタック ([design_memo.md](docs/design/design_memo.md)) を最優先とし、
指定の無い部分を v2 規約 / PoC 方式で埋める。

| 層 | 方針 | 内容 |
|---|---|---|
| アプリ構造 | **ユーザー指定 + v3 で追加** | クリーンアーキテクチャ **4 層: Controller → UseCase → Service → Repository** (ユーザー指定) に、**`entity/` (副作用のない計算) と `gateway/` (外部システムのアダプタ) を層として加えた計 6 パッケージ層**。責務境界・依存規則 L-1〜L-6 は `docs/design/architecture.md` §3 で定義 |
| コーディング規約 | **hassan-v2-backend** | Go、gin、sqlc + wire、`constants.NewCodedError`、命名・エラー返却スタイル |
| 認証・テナント | **hassan-v2-backend** | JWT (`X-Token`) + `AuthRequiredMiddleware`、`account_id` (個人) / `contract_id` (契約) による所有権境界。**事実と採用方針の SSOT は [docs/design/auth.md](docs/design/auth.md)** |
| LLM / エージェント層 | **claude_managed_agents (PoC)** | Anthropic Managed Agents + custom tools + SSE ストリーミング + 台帳 (ledger) パターン |
| フロントエンド | **ユーザー指定** | **Next.js on Vercel**。UI は `docs/prototype/` のプロトタイプを設計入力とする |
| インフラ | **ユーザー指定** | AWS (ECS + PostgreSQL) を **全て IaC で管理** (Terraform 想定)。v2 の ecspresso 方式との関係は要確認 |
| 開発手法 | **ユーザー指定** | TDD (UT を書く)、CI/CD で UT + lint を機械強制、GitHub issue 駆動 |

**指定の無い判断は v2 の既存規約に寄せる** (実装者・レビュアーの学習コストと既存資産の再利用が勝るため)。
逸脱する場合は `docs/design/architecture.md` に理由と却下案を書く。

## 参照リポジトリ (一次ソース。すべて読み取り専用)

| パス | 役割 | 使い方 |
|---|---|---|
| `/Users/yuyamorishita/aillio/hassan/claude_managed_agents` | PoC (Go net/http + React/Vite + Managed Agents) | 移植元の**振る舞いの正**。仕様は spec.md ではなくコードを正とする |
| `/Users/yuyamorishita/aillio/hassan/hassan-v2-backend` | 本番バックエンド | **規約の正** (`CLAUDE.md` / `.cursor/rules/*.mdc` / `rules-bank/*.md`) |
| `/Users/yuyamorishita/aillio/hassan/hassan-v2-frontend` | 本番フロントエンド | 規約の正 (Next.js / orval / Storybook / Playwright) |

**これらのリポジトリを編集しない**。設計上の参照は「リポジトリ名 + リポジトリ相対パス:行番号」で書く
(例: `hassan-v2-backend/auth/middleware.go:23`)。

## 検証ゲート (完了条件)

```bash
make doc-lint              # 相対リンク切れ / 未回答 [Answer] / TODO 残 / 参照リポの実在チェック
make check-traceability    # requirements.md の AC-ID が plan.md と設計書に現れるかの機械照合
make check-workflow-shell  # templates のワークフローに埋めた複数行 run の bash 構文検査
make check-table-counts    # data-model.md のテーブル件数と、他文書・CI 期待値への転記の整合
make check-endpoint-mapping # API のエンドポイント件数・移植チェックリストの対応の整合
make check                 # 上記 5 つをまとめて実行
```

このリポジトリの「テスト」は上記のコマンド群。**設計成果物を確定 (コミット・push) する前に必ず実行し、
出力を完了報告に含める** (`.claude/skills/verification-before-completion/SKILL.md`)。
`make doc-lint` が落ちる状態でコミットは通らない (pre-commit hook)。

## ディレクトリ構成

```
docs/
  analysis/     PoC 棚卸し・ギャップ分析 (現状の事実。推測と事実を分けて書く)
  design/       本番アーキテクチャ・データモデル・API・非機能設計 (確定した設計判断の正)
    README.md       **索引** — 「何を作るか → どのファイルのどの節を読むか」。
                    実装リポの開発者・AI はここから入る (18 ファイル・約 12,000 行あるため)
    design_memo.md  ユーザーによる技術スタック・方針の生メモ (入力。設計の一次要求)
  prototype/    UI プロトタイプ (HTML)。設計入力であって仕様ではない
aidlc-docs/
  inception/<feature>/   questions.md / requirements.md / plan.md (+ concept.md)
  reviews/<feature>/     review.md — design-reviewer の成果物 (push ゲートが要求)
templates/               実装リポジトリ雛形 3 セット (backend-repo / frontend-repo / infra-repo + shared)
scripts/                 doc-lint.sh・traceability チェック・git hooks
.claude/rules/           Claude Code 運用ルール (下表)
.aidlc-rule-details/     AIDLC フェーズ詳細 (aidlc-planner が参照)
```

## ドキュメント規約

- **1 トピック 1 ファイル・SSOT を明示**。同じ事実を 2 箇所に書かない。参照は相対リンクで張る
  (`make doc-lint` がリンク切れを検出する)
- **事実と推測と決定を書き分ける**: 事実には出典 (リポジトリ + パス:行)、推測には「推測」と確信度、
  決定には「採用案 + 却下案 + 理由」
- **未確定は `[Answer]:` 行**で明示する。回答されないまま確定させない (`make doc-lint` が未回答を検出)
- 受入基準には **AC-ID** (`AC-1.2` 形式) を振る。plan.md / 設計書がこの ID で参照する
  (`make check-traceability` が照合)
- 日本語で書く。図は ASCII か mermaid (外部サービス依存の画像を貼らない)

## Claude Code 運用ルール

| ファイル | 内容 |
|---|---|
| `.claude/rules/01-aidlc.md` | AIDLC 必須フロー (Inception 中心。設計リポ版) |
| `.claude/rules/02-agents.md` | エージェント使い分け (planner → analyst/designer ×N → design-reviewer) |
| `.claude/rules/03-parallel-development.md` | 並列作業の判断基準 |
| `.claude/rules/04-review.md` | レビュー必須 (別セッションで `design-reviewer`) |
| `.claude/rules/05-harness.md` | 検証ゲート・pre-commit・push ゲート |
| `.claude/rules/06-delegation-prompts.md` | サブエージェント委譲プロンプト (7 要素) |
| `.claude/rules/07-quality-protocols.md` | 調査・計画・実装の思考プロトコル (skills) |
| `.claude/rules/08-production-gates.md` | **本番品質の必須観点 SSOT** (認証/テナント・可観測性/LLM コスト・CI/CD/IaC) |
| `.claude/rules/feedback_review_patterns.md` | PoC から継承した頻出バグパターン + 設計レビュー観点 |

- 新機能・大きな設計判断は **`aidlc-planner` を最初に呼ぶ**
- **タスク・検討が完了したら `todo.html` を更新する** (`aidlc-docs/aidlc-state.md` の更新とセット) —
  SEED 配列の該当タスクの status を完了 (`2`) にし、新しく生まれたタスクは `t(cat, phase, title, status)` で追記する。
  **既存タスクの title は変えない** (ブラウザの localStorage 保存データとの合流キーのため。
  status の変更は次回リセット/新規閲覧時の初期値になる)
- PoC / v2 の事実収集は `poc-analyst`、アーキテクチャ起草は `architecture-designer`、
  レビューは**別セッションで** `design-reviewer`
- **本番設計は `08-production-gates.md` の観点を必ず通す** (PoC では対象外だった認証・テナント分離・
  権限粒度・可観測性・LLM コスト・CI/CD・IaC。「PoC では不要だった」を設計の省略理由にしない)

## ハーネス

- pre-commit で `make doc-lint` を強制。`--no-verify` 回避はユーザー明示指示がない限り禁止
- push / PR 前に `aidlc-docs/reviews/<feature>/review.md` を要求 (PreToolUse フック)
- `.env` / 秘密ファイルの読み取りは deny。参照リポジトリへの書き込みは行わない

## 応答スタイル (簡潔に)

- 作業を始める前に、これから何をするかを**一文だけ**述べる
- 作業中の報告は、重要な発見があったときと方針を変えるときだけ
- 終わったら**結論から**書く。最初の一文で「何をしたか」「何が分かったか」に答え、詳細はその後
- 返答は短く要点だけ。前置き・但し書きは最小限にし、文字数は答えそのものに使う
- 説明を求められたときは、ユーザーが「詳しく」と言わない限り要点のまとめだけ返す
