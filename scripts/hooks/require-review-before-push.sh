#!/bin/bash
# PreToolUse(Bash) hook — push/PR 前に別セッションレビュー成果物を必須化する (rules/04-review.md)
#
# 設計リポ版。実装リポの「製品コード」に相当するのは **設計成果物**:
#   docs/design/ · docs/analysis/ · aidlc-docs/inception/ · templates/
# これらを ship するなら aidlc-docs/reviews/<feature>/review*.md が必要。
#
# 挙動:
#   - git push / gh pr create を含む Bash 呼び出しのみ対象。それ以外は素通り (exit 0)。
#   - レンジに設計成果物が無ければ素通り (README/スクリプト/.claude のみの push 等)。
#   - 設計成果物があり、レンジ内に review*.md が無ければ exit 2 でブロック。
#   - 対応照合: レンジ内で変更された review*.md の内容 (HEAD 時点) に、変更された設計成果物の
#     リポジトリ相対パスが 1 つも登場しなければブロック (無関係 feature の review 同梱を防ぐ)。
#     一部のみ未言及は警告に留める。
#   - 鮮度: review*.md に最後に触れたコミットより後に設計成果物だけを変えたコミットが残っていれば
#     ブロック (レビュー後の未レビュー変更を防ぐ)。
#   - レンジを判定できない場合は誤ブロックを避けて素通り (警告のみ)。
# exit 2 = Claude Code PreToolUse のブロック (stderr がモデルに渡る)。
set -uo pipefail

ARTIFACT_RE='^(docs/design/|docs/analysis/|aidlc-docs/inception/|templates/)'

input=$(cat)

if ! echo "$input" | grep -Eq 'git +push|gh +pr +create'; then
  exit 0
fi

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$root" || exit 0

# ship されるコミットレンジを決定
range=""
if up=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null); then
  range="${up}..HEAD"
else
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [[ -n "$branch" ]] && git rev-parse --verify "origin/${branch}" >/dev/null 2>&1; then
    range="origin/${branch}..HEAD"
  elif git rev-parse --verify "origin/main" >/dev/null 2>&1; then
    range="origin/main..HEAD"
  fi
fi

if [[ -z "$range" ]]; then
  echo "[harness] push 検出: レビュー状態を判定できませんでした (upstream/origin 不明)。rules/04-review.md に従い別セッション design-reviewer を実施済みか確認してください。" >&2
  exit 0
fi

changed=$(git diff --name-only "$range" 2>/dev/null || true)
[[ -z "$changed" ]] && exit 0

artifact=$(echo "$changed" | grep -E "$ARTIFACT_RE" || true)
[[ -z "$artifact" ]] && exit 0

review=$(echo "$changed" | grep -E '^aidlc-docs/reviews/.*/review.*\.md$' || true)
if [[ -z "$review" ]]; then
  echo "[harness] BLOCKED: 設計成果物を push/PR しようとしていますが、レビュー成果物がありません。" >&2
  echo "[harness] 別セッションで design-reviewer を実行し、aidlc-docs/reviews/<feature>/review.md を作成してください (rules/04-review.md)。" >&2
  echo "[harness] 対象レンジ: $range / 設計成果物の変更あり / review.md 無し。" >&2
  exit 2
fi

# 対応照合: review*.md が今回の設計成果物のパスに言及しているか
review_content=""
while IFS= read -r rf; do
  [[ -z "$rf" ]] && continue
  review_content="${review_content}
$(git show "HEAD:${rf}" 2>/dev/null || true)"
done <<< "$review"

mentioned=0
total=0
unmentioned=""
while IFS= read -r pf; do
  [[ -z "$pf" ]] && continue
  total=$((total + 1))
  if printf '%s' "$review_content" | grep -qF "$pf"; then
    mentioned=$((mentioned + 1))
  else
    unmentioned="${unmentioned}${pf}
"
  fi
done <<< "$artifact"

if [[ "$total" -gt 0 && "$mentioned" -eq 0 ]]; then
  echo "[harness] BLOCKED: レンジ内で変更された review*.md はどれも、今回変更された設計成果物のファイルパス (リポジトリ相対) に言及していません。" >&2
  echo "[harness] 別 feature の review では通過できません。今回の変更に対応する design-reviewer レビューを実施し、変更ファイルの相対パスを含む review.md を aidlc-docs/reviews/<feature>/ に保存してください (rules/04-review.md)。" >&2
  exit 2
fi
if [[ -n "$unmentioned" ]]; then
  echo "[harness] 注意: 以下の設計成果物の変更は、レンジ内のどの review*.md にも相対パスの言及がありません (レビュー漏れでないか確認してください):" >&2
  printf '%s' "$unmentioned" | sed 's/^/[harness]   /' >&2
fi

# 鮮度チェック
last_review_commit=$(git log -1 --format=%H "$range" -- 'aidlc-docs/reviews/*/review*.md' 2>/dev/null || true)
if [[ -n "$last_review_commit" ]]; then
  stale=$(git log --format=%h "${last_review_commit}..HEAD" -- 'docs/design/' 'docs/analysis/' 'aidlc-docs/inception/' 'templates/' 2>/dev/null || true)
  if [[ -n "$stale" ]]; then
    echo "[harness] BLOCKED: review.md の最終更新より後に設計成果物の変更コミットがあります (レビューが古い)。" >&2
    echo "[harness] 未レビューのコミット: $(echo "$stale" | tr '\n' ' ')" >&2
    echo "[harness] 再レビュー (または軽微なら review.md への追記) を行い、review.md を更新してから push してください (rules/04-review.md)。" >&2
    exit 2
  fi
fi

exit 0
