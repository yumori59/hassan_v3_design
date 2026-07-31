#!/usr/bin/env bash
# templates/ の GitHub Actions ワークフローに埋め込まれた **複数行の run スクリプト**を
# bash -n で構文検査する。
#
# なぜ必要か: 雛形は `<...>` をプレースホルダとして使う慣例がある。
# 単一行の `run: <コマンド>` は「まるごと置換する」意図なので許容だが、
# **複数行スクリプトの中に `<...>` が入ると、置換前の状態で構文エラーになる**。
# 実装リポがコピーした時点で「実行すると必ず落ちるワークフロー」になり、
# 構文エラーは実行時まで分からない (設計リポで実際に 3 回作り込んだ)。
#
# 対象: 改行を含む run ブロックのみ (単一行の全置換プレースホルダは対象外)。
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v ruby >/dev/null 2>&1; then
  echo "[workflow-shell] ruby が無いためスキップ" >&2
  exit 0
fi

fail=0
count=0

for f in templates/*/.github/workflows/*.yml; do
  [ -f "$f" ] || continue

  blocks_dir="$(mktemp -d)"
  ruby -ryaml -e '
    path, dir = ARGV
    begin
      d = YAML.safe_load(File.read(path), aliases: true)
    rescue => e
      warn "YAML_ERROR #{e.message.lines.first.to_s.strip}"
      exit 2
    end
    i = 0
    ((d || {})["jobs"] || {}).each_value do |j|
      (((j || {})["steps"]) || []).each do |st|
        run = st["run"]
        next unless run.is_a?(String)
        next unless run.strip.include?("\n")
        i += 1
        File.write(File.join(dir, format("block_%03d.sh", i)), run)
        File.write(File.join(dir, format("block_%03d.name", i)), st["name"].to_s.empty? ? "(no name)" : st["name"])
      end
    end
  ' "$f" "$blocks_dir"
  rc=$?

  if [ "$rc" = "2" ]; then
    echo "[ERROR] $f: YAML として読めない" >&2
    fail=1
    rm -rf "$blocks_dir"
    continue
  fi

  for b in "$blocks_dir"/block_*.sh; do
    [ -f "$b" ] || continue
    count=$((count + 1))
    name_file="${b%.sh}.name"
    step_name="(no name)"
    if [ -f "$name_file" ]; then
      step_name="$(cat "$name_file")"
    fi
    if ! err="$(bash -n "$b" 2>&1)"; then
      echo "[ERROR] ${f} / ステップ「${step_name}」の run が bash として構文エラー" >&2
      echo "        $(printf '%s' "$err" | head -2 | tr '\n' ' ')" >&2
      echo '        → 複数行スクリプト内の <...> は変数化する (例: VAR="" にして未設定なら exit 1)' >&2
      fail=1
    fi
  done
  rm -rf "$blocks_dir"
done

if [ "$fail" != "0" ]; then
  echo "[workflow-shell] 構文エラーあり (検査 $count ブロック)" >&2
  exit 1
fi
echo "[workflow-shell] 検査 $count ブロック / エラー 0 件"
