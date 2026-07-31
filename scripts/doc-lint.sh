#!/usr/bin/env bash
# doc-lint.sh — 設計ドキュメントの機械検証 (hassan_v3 の「テスト」に相当)
#
# 検査項目:
#   [ERROR] 相対リンク切れ            — Markdown の ](path) がリポジトリ内に存在しない
#   [ERROR] 参照リポのパス不在        — claude_managed_agents/... 等の引用先が存在しない
#                                       (参照リポ自体が見つからない場合は WARN に降格)
#   [WARN ] 未回答の [Answer]:        — 空欄のまま残っている確認事項
#   [WARN ] TODO / TBD / FIXME        — 未確定の残骸
#
# 使い方: bash scripts/doc-lint.sh [対象ファイル...]   (省略時はリポジトリ全体)
# 環境変数: REF_ROOT — 参照リポジトリ群の親ディレクトリ (既定: リポジトリの 1 つ上)
set -uo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
REF_ROOT="${REF_ROOT:-$(dirname "$ROOT")}"
REF_REPOS="claude_managed_agents hassan-v2-backend hassan-v2-frontend"

errors=0
warns=0

err()  { echo "[ERROR] $1"; errors=$((errors + 1)); }
warn() { echo "[WARN ] $1"; warns=$((warns + 1)); }

# 対象ファイルの決定 (引数指定 or リポジトリ全体)
if [[ $# -gt 0 ]]; then
  files=$(printf '%s\n' "$@" | grep -E '\.md$' || true)
else
  files=$(find . -name '*.md' \
    -not -path './.git/*' \
    -not -path './.aidlc-rule-details/*' \
    -not -path './node_modules/*' | sort)
fi
[[ -z "$files" ]] && { echo "[doc-lint] 対象 Markdown なし"; exit 0; }

file_count=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  [[ -f "$f" ]] || continue
  file_count=$((file_count + 1))
  dir=$(dirname "$f")

  # --- 1. 相対リンク切れ ------------------------------------------------
  # ](path) 形式のみ検査。http(s)/mailto/アンカーのみ/テンプレート変数はスキップ。
  while IFS= read -r link; do
    [[ -z "$link" ]] && continue
    case "$link" in
      http://*|https://*|mailto:*|\#*|'<'*) continue ;;
      *'{'*|*'$'*|*'*'*|*'<'*) continue ;;   # テンプレート・glob はスキップ
    esac
    target="${link%%#*}"                      # アンカー除去
    [[ -z "$target" ]] && continue
    if [[ "$target" = /* ]]; then
      resolved="$target"                      # 絶対パス
    else
      resolved="$dir/$target"
    fi
    if [[ ! -e "$resolved" ]]; then
      err "$f: リンク切れ -> $link"
    fi
  done < <(grep -oE '\]\([^) ]+\)' "$f" | sed -E 's/^\]\(//; s/\)$//')

  # --- 2. 参照リポジトリのパス実在 --------------------------------------
  for repo in $REF_REPOS; do
    while IFS= read -r ref; do
      [[ -z "$ref" ]] && continue
      case "$ref" in *'*'*|*'{'*|*'<'*) continue ;; esac
      path="${ref%%:*}"                       # file:line の :line を除去
      path="${path%.}"                        # 文末ピリオド除去
      if [[ ! -d "$REF_ROOT/$repo" ]]; then
        warn "$f: 参照リポジトリ $repo が $REF_ROOT に見つからない (照合スキップ: $ref)"
        break
      fi
      if [[ ! -e "$REF_ROOT/$path" ]]; then
        err "$f: 参照先が存在しない -> $ref"
      fi
    done < <(grep -oE "(^|[^A-Za-z0-9_/-])($repo)/[A-Za-z0-9_./-]+(:[0-9]+)?" "$f" \
             | sed -E "s#^[^A-Za-z0-9_/-]*##" | sort -u)
  done

  # --- 3. 未回答の [Answer]: --------------------------------------------
  unanswered=$(grep -nE '^\s*\[Answer\]:\s*$' "$f" | head -20 || true)
  if [[ -n "$unanswered" ]]; then
    while IFS= read -r line; do
      warn "$f:${line%%:*} 未回答の [Answer]:"
    done <<< "$unanswered"
  fi

  # --- 4. TODO / TBD / FIXME --------------------------------------------
  todos=$(grep -nE '\b(TODO|TBD|FIXME)\b' "$f" | head -10 || true)
  if [[ -n "$todos" ]]; then
    while IFS= read -r line; do
      warn "$f:${line%%:*} 未確定マーカー: $(echo "$line" | cut -c1-100)"
    done <<< "$todos"
  fi
done <<< "$files"

echo "[doc-lint] 対象 $file_count ファイル / エラー $errors 件 / 警告 $warns 件"
[[ $errors -gt 0 ]] && exit 1
exit 0
