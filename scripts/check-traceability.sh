#!/usr/bin/env bash
# check-traceability.sh — 受入基準 (AC-ID) のトレーサビリティ照合
#
# requirements.md で定義した AC-ID が、同じ feature の plan.md / 設計書 (docs/design/) で
# 参照されているかを機械照合する。実装リポの `check-ac-coverage.sh` (AC ↔ テスト照合) の
# 設計リポ版で、AC ↔ 計画 ↔ 設計 の対応漏れを検出する。
#
# 使い方: bash scripts/check-traceability.sh [feature名]   (省略時は全 feature)
# 終了コード: 未カバー AC があれば 1
set -uo pipefail

cd "$(dirname "$0")/.."
INCEPTION="aidlc-docs/inception"
DESIGN_GLOB="docs/design"

target="${1:-}"
errors=0
checked=0

if [[ ! -d "$INCEPTION" ]]; then
  echo "[traceability] $INCEPTION が無いためスキップ"
  exit 0
fi

features=$(find "$INCEPTION" -mindepth 1 -maxdepth 1 -type d | sort)
[[ -n "$target" ]] && features=$(printf '%s\n' "$features" | grep -E "/${target}$" || true)

if [[ -z "$features" ]]; then
  echo "[traceability] 対象 feature なし${target:+ (指定: $target)}"
  exit 0
fi

while IFS= read -r fdir; do
  [[ -z "$fdir" ]] && continue
  feature=$(basename "$fdir")
  reqs=$(find "$fdir" -maxdepth 1 -name 'requirements*.md' | sort)
  if [[ -z "$reqs" ]]; then
    echo "[traceability] $feature: requirements*.md なし — スキップ"
    continue
  fi

  # requirements から AC-ID を抽出 (AC-1 / AC-1.2 / AC-12.3 形式)
  acs=$(grep -ohE '\bAC-[0-9]+(\.[0-9]+)?' $reqs | sort -u -V 2>/dev/null || grep -ohE '\bAC-[0-9]+(\.[0-9]+)?' $reqs | sort -u)
  if [[ -z "$acs" ]]; then
    echo "[traceability] $feature: AC-ID の定義なし — スキップ (受入基準に AC-ID を振ること)"
    continue
  fi

  plans=$(find "$fdir" -maxdepth 1 -name 'plan*.md' | sort)
  if [[ -z "$plans" ]]; then
    echo "[traceability] $feature: plan*.md 未作成 (AC $(echo "$acs" | wc -l | tr -d ' ') 件) — 計画未着手"
    continue
  fi

  design_files=$(find "$DESIGN_GLOB" -name '*.md' 2>/dev/null | sort || true)
  uncovered=""
  covered=0
  total=0
  while IFS= read -r ac; do
    [[ -z "$ac" ]] && continue
    total=$((total + 1))
    # 単語境界付きで照合 (AC-1 が AC-1.2 に部分一致しないように)
    if grep -qE "\b${ac}\b([^.0-9]|$)" $plans 2>/dev/null; then
      covered=$((covered + 1))
    elif [[ -n "$design_files" ]] && grep -qE "\b${ac}\b([^.0-9]|$)" $design_files 2>/dev/null; then
      covered=$((covered + 1))
    else
      uncovered="${uncovered}${ac} "
    fi
  done <<< "$acs"

  checked=$((checked + 1))
  if [[ -n "$uncovered" ]]; then
    echo "[traceability] $feature: $covered/$total カバー — 未カバー: $uncovered"
    errors=$((errors + 1))
  else
    echo "[traceability] $feature: $covered/$total カバー — OK"
  fi
done <<< "$features"

echo "[traceability] 照合 $checked feature / 未カバーあり $errors feature"
[[ $errors -gt 0 ]] && exit 1
exit 0
