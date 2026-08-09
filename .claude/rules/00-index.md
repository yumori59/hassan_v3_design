# hassan_v3 — Claude Code ルール集

このディレクトリは Claude Code 用の運用ルール。リポジトリルートの `../../CLAUDE.md` から索引される。

**このリポジトリは設計ドキュメント専用**。製品コードは置かず、本番実装は別リポジトリで行う
(引き渡し物 = `docs/design/` の設計 + `aidlc-docs/inception/` の要件・計画 + `templates/` (**app モノレポ / infra リポの 2 セット** + shared) のハーネス雛形)。

## ファイル一覧

ルート `CLAUDE.md` の「Claude Code 運用ルール」表が SSOT (同じ一覧をここに再掲しない)。

## 既存ルールとの関係

- ルート `CLAUDE.md` — アーキテクチャ方針・参照リポジトリ・検証ゲート・ドキュメント規約。常時ロード
- `.claude/rules/*` — **Claude Code 固有の運用ルール** (本ディレクトリ)
- `.aidlc-rule-details/` — AIDLC 各フェーズの詳細手順 (`aidlc-planner` が参照)
- 参照リポジトリの規約 (`hassan-v2-backend/CLAUDE.md`・`.cursor/rules/`・`rules-bank/`) は
  **本番実装規約の正**。本リポジトリはそれを設計に取り込む側であり、書き換えない
