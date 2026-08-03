#!/usr/bin/env bash
# check-template-sync.sh — templates/ 配下に置いた「設計リポの同期コピー」が SSOT と一致するか照合
#
# 対象: templates/shared/.claude/rules/feedback_review_patterns.md
#   SSOT: .claude/rules/feedback_review_patterns.md (このリポジトリの正)
# 新しい同期コピーを追加したら、下の PAIRS に1行足すだけでよい。
#
# 使い方: bash scripts/check-template-sync.sh
# 終了コード: 1 件でも不一致があれば 1
set -uo pipefail

cd "$(dirname "$0")/.."

# "SSOT:コピー" の形で列挙する
PAIRS=(
  ".claude/rules/feedback_review_patterns.md:templates/shared/.claude/rules/feedback_review_patterns.md"
)

errors=0

for pair in "${PAIRS[@]}"; do
  ssot="${pair%%:*}"
  copy="${pair##*:}"

  if [[ ! -f "$ssot" ]]; then
    echo "[template-sync] SSOT が無い -> $ssot"
    errors=$((errors + 1))
    continue
  fi
  if [[ ! -f "$copy" ]]; then
    echo "[template-sync] コピーが無い -> $copy"
    errors=$((errors + 1))
    continue
  fi

  # コピー側は先頭に「同期コピーである」旨の注記 (HTML コメント) を持ってよい。
  # 比較は両ファイルとも最初の Markdown 見出し (`# `) 以降の本文で行う (注記だけの差は許容する)。
  if ! diff -q \
      <(awk '/^# /{f=1} f' "$ssot") \
      <(awk '/^# /{f=1} f' "$copy") \
      >/dev/null 2>&1; then
    echo "[template-sync] 不一致: $copy の本文が $ssot と同期していません (先頭の同期注記を除く)"
    echo "  再同期: 冒頭の同期注記を残したまま、本文を $ssot の内容に置き換える"
    errors=$((errors + 1))
  fi
done

echo "[template-sync] 照合 ${#PAIRS[@]} 組 / エラー ${errors} 件"
[[ $errors -gt 0 ]] && exit 1
exit 0
