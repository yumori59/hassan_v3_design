#!/usr/bin/env bash
# check-ci-gate.sh — `ci.yml` の job 集合 == `gate` の `needs` == `gate` 内の判定名 を照合する
#
# ■ なぜ雛形 (実装リポ) 側に置くか (2026-08-05。design-reviewer 指摘 D-2)
#
#   モノレポ機構 **MR-1** は「**ブランチ保護の必須ステータスチェックは `gate` 1 本のみ**」という設計である
#   (path filter で skip されたジョブは status を返さないため、個別ジョブを必須にすると
#    PR が永久に pending になる)。
#
#   この設計の弱点は **`gate` が「何を集約するか」が PR で変更可能なコードになったこと** —
#   3 リポ構成では「必須チェックの厳格さ」はリポジトリ設定 (サーバ側) にあった。
#   `gate` の `needs` から 1 ジョブを消せば、**そのジョブが失敗しても必須チェックは緑になる**。
#
#   当初この照合は**設計リポ hassan_v3 の `scripts/check-monorepo-ci.sh` にしか無かった**。
#   しかし `05-harness.md` は「**雛形は初期値であって SSOT ではない。切り出し後は実装リポ側が正**」と
#   定めているため、**実装リポへ切り出した瞬間に MR-1 の担保が消える**状態だった。
#   そこで**同じ照合を雛形側に持たせ、`ci.yml` の `meta` ジョブから呼ぶ**。
#
# ■ 検査するもの
#   ① `jobs:` 直下の job 名の集合 (`gate` を除く) == `gate` の `needs` に列挙された名前
#   ② `gate` の `needs` == `gate` のステップ内で `check <name>` している名前
#      (`needs` に足しただけで判定を書かなければ、その結果は無視される)
#   ③ `gate` に `if: always()` があること (無いと前段の失敗で `gate` 自身が skip され、
#      「必須チェックが来ない」= PR が pending のまま止まる)
#
# ■ 使い方
#     scripts/check-ci-gate.sh [<ci.yml のパス>]
#   既定は `.github/workflows/ci.yml`。終了コードは不一致があれば 1。
set -euo pipefail

CI="${1:-.github/workflows/ci.yml}"

if [[ ! -f "$CI" ]]; then
  echo "::error::$CI がありません (MR-1 の照合対象。パスを変えたら本スクリプトの引数も直す)" >&2
  exit 1
fi

errors=0
fail() { echo "::error::$*" >&2; errors=$((errors + 1)); }

# `jobs:` 直下 = 2 スペースインデントの `<name>:` 行
jobs=$(awk '
  /^jobs:/        { in_jobs = 1; next }
  /^[^[:space:]]/ { in_jobs = 0 }
  in_jobs && /^  [a-z_][a-z0-9_-]*:[[:space:]]*$/ { gsub(/^  |:[[:space:]]*$/, ""); print }
' "$CI" | sort -u)

needs=$(grep -E '^[[:space:]]+needs:[[:space:]]*\[' "$CI" | tail -1 \
          | sed 's/.*\[//; s/\].*//' | tr ',' '\n' | tr -d ' ' | grep -v '^$' | sort -u)

checks=$(grep -oE '^[[:space:]]+check[[:space:]]+[a-z_][a-z0-9_-]*' "$CI" \
           | awk '{print $2}' | sort -u)

if [[ -z "$jobs" ]]; then
  fail "$CI から job 名を抽出できませんでした (jobs: の書式が変わった可能性)"
fi

jobs_no_gate=$(echo "$jobs" | grep -v '^gate$' || true)

if [[ -n "$jobs" && "$jobs_no_gate" != "$needs" ]]; then
  fail "① gate の needs が job 集合と一致しません
  job 集合 (gate を除く): $(echo "$jobs_no_gate" | tr '\n' ' ')
  gate の needs        : $(echo "$needs" | tr '\n' ' ')
  → ジョブを増減したら gate の needs も同じ差分で更新してください (MR-1)。
    needs から漏れたジョブは **失敗しても必須チェック (gate) を通ります**"
fi

if [[ -n "$needs" && "$checks" != "$needs" ]]; then
  fail "② gate の needs と、gate 内で判定している名前が一致しません
  needs : $(echo "$needs" | tr '\n' ' ')
  check : $(echo "$checks" | tr '\n' ' ')
  → needs に足しただけで判定を書かないと、そのジョブの結果は無視されます"
fi

# `gate` ジョブの中に `if: always()` があるか (ジョブ定義行の直後 5 行以内を見る)
if ! awk '/^  gate:/{f=1} f && /if:[[:space:]]*always\(\)/{found=1; exit} f && ++n>6{exit} END{exit !found}' "$CI"; then
  fail "③ gate に \`if: always()\` がありません
  → 前段のジョブが失敗すると gate 自身が skip され、**必須チェックの status が来ないまま
    PR が pending で止まります** (MR-1 の前提が壊れます)"
fi

if [[ "$errors" -ne 0 ]]; then
  echo "[check-ci-gate] エラー $errors 件" >&2
  exit 1
fi
echo "[check-ci-gate] OK: job $(echo "$jobs" | grep -c .) 本 / gate の needs $(echo "$needs" | grep -c .) 本 / 判定 $(echo "$checks" | grep -c .) 本"
