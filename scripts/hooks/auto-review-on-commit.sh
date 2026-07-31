#!/bin/bash
# PostToolUse(Bash) hook — git commit 後に「状態を見て」レビューを促す (rules/04-review.md)
#
# 直前コミット (HEAD) が設計成果物 (docs/design・docs/analysis・aidlc-docs/inception・templates)
# を含む場合のみ、別セッションでの design-reviewer を必須として促す。
# README・スクリプト・.claude のみの変更ではレビュー任意である旨を案内する。
set -euo pipefail

input=$(cat)
echo "$input" | grep -q 'git commit' || exit 0

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$root"

files=$(git show --name-only --format= HEAD 2>/dev/null || true)
[[ -z "$files" ]] && exit 0

artifact=$(echo "$files" | grep -E '^(docs/design/|docs/analysis/|aidlc-docs/inception/|templates/)' || true)

echo ""
if [[ -n "$artifact" ]]; then
  echo "[harness] コミット完了。設計成果物を含みます — **別セッションで design-reviewer 必須** (rules/04-review.md)。"
  echo "[harness] push/PR 前に aidlc-docs/reviews/<feature>/review.md が無いとゲートでブロックされます。"
else
  echo "[harness] コミット完了 (設計成果物なし) — レビューは任意です。"
fi

# 記帳遅延の警告: AIDLC 産物・レビューの未コミット残
pending=$(git status --porcelain -- aidlc-docs/ docs/ 2>/dev/null | head -5 || true)
if [[ -n "$pending" ]]; then
  echo "[harness] 注意: aidlc-docs/ · docs/ に未コミットの変更があります。設計判断は確定した時点で記帳してください:"
  echo "$pending" | sed 's/^/[harness]   /'
fi
