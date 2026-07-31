# hassan_v3 — 本番化のための設計リポジトリ

PoC (`claude_managed_agents`) で検証済みの「テーマ管理 × アセット管理 × 会話型アイデア創出」を、
**本番システムとして再構築するための設計・仕様・移行計画**を確定させるリポジトリ。
**製品コードは置かない** — 実装は別リポジトリで行い、ここの設計成果物と
[実装リポ用ハーネス雛形](templates/README.md) を引き渡す。

## クイックスタート

```bash
make help          # コマンド一覧
make check         # 検証ゲート一式 (doc-lint / AC トレーサビリティ / workflow 構文 / テーブル件数)
make install-hooks # pre-commit フックの導入 (git init 済みであること)
```

Claude Code の運用ルールは [CLAUDE.md](CLAUDE.md) と [.claude/rules/](.claude/rules/00-index.md) を参照。

## いま何が決まっていて、次に何をするか

| 区分 | 状態 |
|---|---|
| 本番アーキ方針 | **ハイブリッド確定** — アプリ構造/認証/デプロイは hassan-v2-backend 準拠、LLM 層は Managed Agents ([CLAUDE.md](CLAUDE.md)) |
| PoC の棚卸し | [docs/analysis/poc-inventory.md](docs/analysis/poc-inventory.md) |
| ギャップ分析 | [docs/analysis/gap-analysis.md](docs/analysis/gap-analysis.md) — G-1〜G-8 |
| アーキテクチャ | [docs/design/architecture.md](docs/design/architecture.md) — **v0.1 骨格** (データモデルと移行は未確定) |
| 次のアクション | [questions.md](aidlc-docs/inception/productionization/questions.md) の **Q-1〜Q-6 に回答** → [plan.md](aidlc-docs/inception/productionization/plan.md) の Phase 2 (深掘り調査) へ |

## ディレクトリ構成

```
docs/analysis/    PoC 棚卸し・ギャップ分析 (事実。出典付き)
docs/design/      本番アーキテクチャ・データモデル・API・非機能設計 (確定した設計判断)
docs/prototype/   UI プロトタイプ (設計入力であって仕様ではない)
aidlc-docs/       AIDLC 産物 (inception/<feature>/ と reviews/<feature>/)
templates/            実装リポジトリ立ち上げ用のハーネス雛形 (backend / frontend / infra)
scripts/          doc-lint・トレーサビリティ照合・git hooks
.claude/          Claude Code のルール・エージェント・skill・設定
```

## 参照リポジトリ (読み取り専用)

| パス | 役割 |
|---|---|
| `../claude_managed_agents` | PoC。移植元の**振る舞いの正** |
| `../hassan-v2-backend` | 本番バックエンド。**規約の正** (3 層 / sqlc / wire / 認証 / ECS) |
| `../hassan-v2-frontend` | 本番フロントエンド (Next.js / orval) |

これらは**編集しない**。設計上の参照は「リポジトリ名 + 相対パス:行」で書く
(`make doc-lint` が実在を照合する)。

## ワークフロー

```
aidlc-planner (要件・計画)
   ↓
poc-analyst ×N (事実収集・並列)  →  報告の抜き取り検証 (オーケストレーター)
   ↓
architecture-designer (設計起草)
   ↓
design-reviewer (別セッション・本番基準)  →  aidlc-docs/reviews/<feature>/review.md
   ↓
make check → コミット → push (レビュー成果物が無いとフックがブロック)
```
