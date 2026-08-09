.PHONY: check doc-lint check-traceability check-workflow-shell check-table-counts check-endpoint-mapping check-template-sync check-monorepo-ci install-hooks new-feature help

help:
	@echo "hassan_v3 — 本番化のための設計リポジトリ"
	@echo ""
	@echo "  make check              検証ゲート一式 (下に列挙した check-* をすべて実行。本数は書かない = DR-9)"
	@echo "  make doc-lint           リンク切れ・参照先不在・未回答 [Answer]・TODO 残の検出"
	@echo "  make check-traceability requirements の AC-ID が plan/設計書でカバーされているか照合"
	@echo "  make check-workflow-shell  templates のワークフローに埋めた複数行 run の bash 構文検査"
	@echo "  make check-table-counts data-model.md のテーブル件数と、他文書・CI 期待値への転記の整合"
	@echo "  make check-endpoint-mapping API 設計のエンドポイント件数・移植チェックリストの対応の整合"
	@echo "  make check-template-sync templates/ 配下の同期コピー (feedback_review_patterns.md 等) が SSOT と一致するか照合"
	@echo "  make check-monorepo-ci  app モノレポの CI 機構 (MR-1〜MR-6) の整合 — gate の needs / 必須欄 / 件数 / 裸の git diff"
	@echo "  make install-hooks      scripts/hooks/pre-commit を .git/hooks へリンク"
	@echo "  make new-feature F=<名前>  AIDLC の feature ディレクトリと雛形を作成"

check: doc-lint check-traceability check-workflow-shell check-table-counts check-endpoint-mapping check-template-sync check-monorepo-ci

# templates/ 配下の同期コピーが SSOT (.claude/rules/) と一致するかの照合。
# ⚠️ **このターゲットは 2026-08-05 まで .PHONY と check の依存に名前だけがあり、レシピが無かった** —
# `make check-template-sync` が "Nothing to be done" で成功扱いになり、scripts/check-template-sync.sh は
# 一度も実行されていなかった。**「ゲートが 7 本ある」という表示が 1 本ぶん嘘だった**
# (feedback_review_patterns.md の DR-6「検査が対象 0 件を検査して緑になる」の Makefile 版)。
check-template-sync:
	@bash scripts/check-template-sync.sh

doc-lint:
	@bash scripts/doc-lint.sh

check-traceability:
	@bash scripts/check-traceability.sh

# templates のワークフローに埋め込まれた複数行 run スクリプトの構文検査。
# 単一行の `run: <コマンド>` プレースホルダは対象外 (まるごと置換する慣例)。
check-workflow-shell:
	@bash scripts/check-workflow-shell.sh

# data-model.md §4.1.1 / §3.4.2 の表を数えた実測値を正とし、同書と他文書に散在する
# 件数の記述と一致するかを照合する。件数の一部は CI 検査の期待値 (§3.3 / §7.2) であり、
# ずれると「設計どおり実装した検査が必ず落ちる」形で実装リポに出る。
# 2026-07-31 に `idea_tags` を 1 件追加したとき連動が 15 箇所あり、
# 人手の見積り (6 → 9 件) が 2 回外れたため新設した。
check-table-counts:
	@bash scripts/check-table-counts.sh

check-endpoint-mapping:
	@bash scripts/check-endpoint-mapping.sh

# Git hooks のインストール (scripts/hooks/pre-commit → .git/hooks/pre-commit)
# rules/05-harness.md に基づき pre-commit で doc-lint を強制する。
install-hooks:
	@test -d .git || (echo 'git リポジトリではありません (git init を先に実行)' && exit 1)
	ln -sf ../../scripts/hooks/pre-commit .git/hooks/pre-commit
	@echo "[install-hooks] .git/hooks/pre-commit -> scripts/hooks/pre-commit"

# AIDLC feature の雛形作成 (aidlc-planner が使う。手動でも可)
new-feature:
	@test -n "$(F)" || (echo 'usage: make new-feature F=<feature-name>' && exit 1)
	@mkdir -p aidlc-docs/inception/$(F) aidlc-docs/reviews/$(F)
	@test -f aidlc-docs/inception/$(F)/questions.md || printf '# Questions: %s\n\n> 設計を分岐させる不明点のみ (目安 7 問以内)。推奨案を必ず併記し、回答は `[Answer]:` 行に書く。\n\n## Q1. <質問>\n\n- A. <選択肢>\n- B. <選択肢>\n- E. Other\n\n> 推奨: A (<理由>)\n\n[Answer]:\n' "$(F)" > aidlc-docs/inception/$(F)/questions.md
	@echo "[new-feature] aidlc-docs/inception/$(F)/questions.md を作成しました"
	@echo "[new-feature] 次: aidlc-planner で requirements.md → plan.md を確定"

# app モノレポの CI 機構 (MR-1〜MR-6) の整合を機械照合する。
# 2026-08-04 の design-reviewer レビューで、モノレポ機構に対する故障注入 3 種が
# **3/3 とも make check で非検出**だったため新設した (詳細はスクリプト冒頭のコメント)。
check-monorepo-ci:
	@bash scripts/check-monorepo-ci.sh
