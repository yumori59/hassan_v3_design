#!/usr/bin/env bash
# check-table-counts.sh — data-model.md のテーブル件数の整合を機械照合
#
# 背景: 2026-07-31 に `idea_tags` を 1 テーブル追加したとき、**連動する件数の記述が 15 箇所**あり、
# 初版の見積り (6 箇所) と 3 巡目レビューの見積り (9 箇所) がどちらも外れた。
# 増えた原因は「`account_id` を持つテーブルを足すと §3.4.2 の 3 分類にも必ず入れる必要があり、
# 分類①の件数が 4 箇所に現れる」ことで、人手の grep では取り残しが避けられなかった。
#
# 本スクリプトは data-model.md の**表を数えた実測値**を正とし、
# 同書と他文書に散在する件数の記述がそれと一致するかを検査する。
# 件数はいくつかが **CI 検査の期待値** (§3.3 / §7.2) であり、ずれると
# 「設計どおりに実装した検査が必ず落ちる」形で実装リポに出る。
#
# 使い方: bash scripts/check-table-counts.sh
# 終了コード: 不一致があれば 1
set -uo pipefail

cd "$(dirname "$0")/.."
DM="docs/design/data-model.md"
errors=0
checked=0

if [[ ! -f "$DM" ]]; then
  # **スキップして緑にしない** (2026-07-31 変更)。ファイル名変更・移動で静かに通ると
  # BE-5 (DB 未接続フォールバック) と同型の「検査が消えたことに気付けない」設計になる。
  echo "[ERROR] $DM が見つからない。ファイルを移動・改名したなら本スクリプトの DM を更新すること"
  exit 1
fi

# 1 件の期待値照合。$1=説明 / $2=実測値 / $3=文書に書かれた値 / $4=出典
expect() {
  checked=$((checked + 1))
  if [[ "$2" != "$3" ]]; then
    echo "[ERROR] $1: 実測 $2 に対し文書は $3  ($4)"
    errors=$((errors + 1))
  fi
}

# 文書から最初にマッチした箇所の**末尾の数値**を取り出す。取れなければ空文字。
# 末尾を採るのは、パターンに節番号 (`§3.4.2` / `#### 4.1.1`) が含まれるため —
# 先頭から採ると節番号を拾ってしまう。呼び出し側は「照合したい数値がパターン内で最後に来る」ことを守る。
pick() {
  local hits distinct
  hits=$(grep -oE "$1" "$2")
  if [[ -z "$hits" ]]; then echo ""; return; fi
  # 多重ヒット検査 (2026-07-31 追加): 同じパターンが複数箇所にあり、**値が食い違っている**場合は
  # 先頭だけを見ると静かに取り残す (4 巡目レビューが故障注入で実証した唯一の未検出ケース)。
  distinct=$(echo "$hits" | while IFS= read -r line; do
    echo "$line" | grep -oE '[0-9]+' | tail -1
  done | sort -u | wc -l | tr -d ' ')
  if [[ "$distinct" -gt 1 ]]; then
    # pick() はコマンド置換 (サブシェル) で呼ばれるため、`errors` への加算は親に伝わらない。
    # 一時ファイルに記録して最後に集計する。
    echo "[ERROR] 同一パターンが複数箇所にあり値が一致しない: /$1/ ($2)" >> "$MULTIHIT_LOG"
  fi
  echo "$hits" | head -1 | grep -oE '[0-9]+' | tail -1
}

MULTIHIT_LOG=$(mktemp)
trap 'rm -f "$MULTIHIT_LOG"' EXIT

# ── 実測値 (§4.1.1 の表を数える) ─────────────────────────────
# 表本体の行は「| <番号> | `<テーブル名>` | <境界> | ...」
rows=$(grep -cE '^\| [0-9]+ \| `[a-z_]+` \| (個人|契約) \|' "$DM")
personal=$(grep -cE '^\| [0-9]+ \| `[a-z_]+` \| 個人 \|' "$DM")
contract=$(grep -cE '^\| [0-9]+ \| `[a-z_]+` \| 契約 \|' "$DM")

# 番号の欠番検査 (1..rows が 1 回ずつ現れること)
nums=$(grep -oE '^\| [0-9]+ \| `[a-z_]+` \| (個人|契約) \|' "$DM" | grep -oE '[0-9]+' | sort -n | uniq)
expected_seq=$(seq 1 "$rows")
if [[ "$nums" != "$expected_seq" ]]; then
  echo "[ERROR] §4.1.1 の表の行番号に欠番または重複がある (1〜$rows が 1 回ずつ現れていない)"
  errors=$((errors + 1))
fi
checked=$((checked + 1))

# 所有者列の欠落 (全行に contract_id があること = AC-1.2)
missing=$(grep -E '^\| [0-9]+ \| `[a-z_]+` \| (個人|契約) \|' "$DM" | grep -vc 'contract_id')
expect "§4.1.1 の全行が contract_id を持つこと" 0 "$missing" "AC-1.2 / §3.3 の検査①"

# ── 実測値 (§3.4.2 の 3 分類を数える) ────────────────────────
# 分類①: グループ行のセル内に列挙されたテーブル名 (バッククォート) の総数
c1=$(awk '/^\*\*分類① 移管する/,/^\*\*分類② /' "$DM" \
      | grep -E '^\| [^|]+ \| `' \
      | grep -oE '`[a-z_]+`' | wc -l | tr -d ' ')
# 分類② / 分類③: 1 行 = 1 テーブル (第 1 列がテーブル名)
c2=$(awk '/^\*\*分類② /,/^\*\*分類③ /' "$DM" | grep -cE '^\| `[a-z_]+` \|')
c3=$(awk '/^\*\*分類③ /,/^#### /' "$DM" | grep -cE '^\| `[a-z_]+` \|')

# ── 実測値 (§4.1.2 の例外 2 表を数える) ──────────────────────
# (a) 所有者列を持たない表 / (b) 所有者列を実際に持つ表。第 1 セルのバッククォート名を数える
# (1 行に 2 名を書く行があるため行数では数えない)。
excl_a=$(awk '/^\*\*\(a\) 所有者列を持たない/,/^\*\*\(b\) 所有者列を実際に持つ/' "$DM" \
          | awk -F'|' '/^\| /{print $2}' | grep -oE '`[a-z_]+`' | wc -l | tr -d ' ')
excl_b=$(awk '/^\*\*\(b\) 所有者列を実際に持つ/,/^### 4\.2/' "$DM" \
          | awk -F'|' '/^\| /{print $2}' | grep -oE '`[a-z_]+`' | wc -l | tr -d ' ')
# (b) のうち contract_id を持たない件数 = 検査①の除外に入る分 (第 2 セル = 実際に持つ列)
excl_b_noc=$(awk '/^\*\*\(b\) 所有者列を実際に持つ/,/^### 4\.2/' "$DM" \
          | awk -F'|' '/^\| `|^\| \*\*`/{ if ($3 ~ /account_id/ && $3 !~ /contract_id/) c++ } END{print c+0}')
exclusion=$((excl_a + excl_b_noc))
non_functional=$((excl_a + excl_b))

# ── 照合 (§4.1.2 の例外件数。**CI 検査の期待値を含む**) ───────
expect "§4.1.2 見出しの「機能テーブル以外の N テーブル」" "$non_functional" \
  "$(pick '#### 4\.1\.2 機能テーブル以外の [0-9]+ テーブル' "$DM")" "$DM §4.1.2 見出し"
expect "§4.1.2 (a) 表の件数" "$excl_a" \
  "$(pick '\*\*\(a\) 所有者列を持たない [0-9]+ 件' "$DM")" "$DM §4.1.2 (a)"
expect "§4.1.2 (b) 表の件数" "$excl_b" \
  "$(pick '\*\*\(b\) 所有者列を実際に持つ [0-9]+ 件' "$DM")" "$DM §4.1.2 (b)"
expect "§4.1.2 注記の (a) 件数" "$excl_a" \
  "$(pick '検査①の実装は \(a\) [0-9]+ 件' "$DM")" "$DM §4.1.2 の注記"
expect "§4.1.2 注記の除外リスト総数" "$exclusion" \
  "$(pick '検査①の実装は \(a\) [0-9]+ 件 \+ 本注記の [0-9]+ 件 = [0-9]+ 件' "$DM")" "$DM §4.1.2 の注記"
expect "§3.3 検査①の (a) 件数 (CI の期待値)" "$excl_a" \
  "$(pick '除外リストは §4\.1\.2 の \(a\) 表 [0-9]+ 件' "$DM")" "$DM §3.3 の検査①"
expect "§3.3 検査①の除外リスト総数 (CI の期待値)" "$exclusion" \
  "$(pick '\(b\) 表のうち `contract_id` を持たない [0-9]+ 件 \(`account_mfa_configs` / `reset_password_requests`\) = [0-9]+ 件' "$DM")" \
  "$DM §3.3 の検査①"
expect "§7.2 検査 1 の (a) 件数 (CI の期待値)" "$excl_a" \
  "$(pick '除外リストは §4\.1\.2 \(a\) の [0-9]+ 件' "$DM")" "$DM §7.2 の検査 1"
expect "§7.2 検査 1 の除外リスト総数 (CI の期待値)" "$exclusion" \
  "$(pick '§4\.1\.2 \(a\) の [0-9]+ 件 \+ `account_mfa_configs` / `reset_password_requests` = [0-9]+ 件' "$DM")" \
  "$DM §7.2 の検査 1"

# ── 照合 (§3.4.2 分類①のグループ行ラベル) ────────────────────
# 「1 行に複数テーブルを書く行」には `(N 件)` ラベルがある。ラベルとバッククォート名の数を突き合わせる。
# ラベルの無い行 (単一テーブル) はスキップする。
while IFS= read -r line; do
  label=$(echo "$line" | grep -oE '\([0-9]+ 件\)' | head -1 | grep -oE '[0-9]+')
  [[ -z "$label" ]] && continue
  names=$(echo "$line" | awk -F'|' '{print $3}' | grep -oE '`[a-z_]+`' | wc -l | tr -d ' ')
  agg=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$2); print $2}')
  expect "§3.4.2 分類①のグループ行ラベル (${agg})" "$names" "$label" "$DM §3.4.2 分類① (グループ行の内訳)"
done < <(awk '/^\*\*分類① 移管する/,/^\*\*分類② /' "$DM" | grep -E '^\| [^|]+ \| `|^\| [^|]+ \| \*\*`')

# ── 照合 (data-model.md 内) ───────────────────────────────────
expect "§4.1.1 見出しの件数" "$rows" \
  "$(pick '#### 4\.1\.1 機能テーブル \([0-9]+ 件' "$DM")" "$DM §4.1.1 見出し"
expect "§4.1.1 注記の行数 (1〜N)" "$rows" \
  "$(pick '行番号 1〜[0-9]+ のうち欠番は無い' "$DM")" "$DM §4.1.1 の注記"
expect "§4.1.1 注記の行数 (**N 行**)" "$rows" \
  "$(grep -oE '行番号 1〜[0-9]+ のうち欠番は無い \(\*\*[0-9]+ 行\*\*\)' "$DM" | grep -oE '[0-9]+ 行' | grep -oE '[0-9]+')" \
  "$DM §4.1.1 の注記"
expect "§3.4.2 見出しの個人テーブル数" "$personal" \
  "$(pick '#### 3\.4\.2 `account_id` を持つ [0-9]+ テーブル' "$DM")" "$DM §3.4.2 見出し"
expect "§3.4.2 分類①の件数" "$c1" \
  "$(pick '\*\*分類① 移管する \(契約の資産。[0-9]+ 件\)' "$DM")" "$DM §3.4.2 分類①"
expect "§3.4.2 分類②の件数" "$c2" \
  "$(pick '\*\*分類② 個人設定として削除する \([0-9]+ 件\)' "$DM")" "$DM §3.4.2 分類②"
expect "§3.4.2 分類③の件数" "$c3" \
  "$(pick '\*\*分類③ 記録として保全する \(append-only。[0-9]+ 件\)' "$DM")" "$DM §3.4.2 分類③"
expect "分類①+②+③ == 個人スコープのテーブル数" "$personal" "$((c1 + c2 + c3))" \
  "$DM §3.4.2 (未分類のテーブルがあると一致しない = 検査②-2 が落とす対象)"

expect "§3.3 検査②-1 の分類①件数 (CI の期待値)" "$c1" \
  "$(pick '§3\.4\.2 の分類① \(移管対象。[0-9]+ 件\)' "$DM")" "$DM §3.3 の検査②-1"
expect "§3.3 検査②-2 の個人件数 (CI の期待値)" "$personal" \
  "$(pick '分類① ∪ 分類② ∪ 分類③ \([0-9]+ 件\)' "$DM")" "$DM §3.3 の検査②-2"
expect "§7.2 検査 2-1 の分類①件数 (CI の期待値)" "$c1" \
  "$(pick '§3\.4\.2 の分類① \([0-9]+ 件\) の集合' "$DM")" "$DM §7.2 の検査 2-1"
expect "§7.2 検査 2-2 の個人件数 (CI の期待値)" "$personal" \
  "$(pick '`account_id` を持つテーブル \([0-9]+ 件\) が' "$DM")" "$DM §7.2 の検査 2-2"

expect "§5 A-3 の機能テーブル数" "$rows" \
  "$(pick '\*\*機能テーブル [0-9]+ 件すべてが' "$DM")" "$DM §5 の A-3 行"
expect "§5 A-3 の個人スコープ数" "$personal" \
  "$(pick '個人スコープの [0-9]+ 件は `account_id`' "$DM")" "$DM §5 の A-3 行"
expect "§5 A-3 の契約スコープ数" "$contract" \
  "$(pick '契約スコープは [0-9]+ 件' "$DM")" "$DM §5 の A-3 行"

# ── 照合 (他文書からの引用) ───────────────────────────────────
# data-model.md の値を引用している箇所。ファイルが無ければスキップする。
if [[ -f docs/design/auth.md ]]; then
  expect "auth.md のテーブル数" "$rows" \
    "$(pick '\([0-9]+ テーブルの内訳 = 個人境界' docs/design/auth.md)" "docs/design/auth.md"
  expect "auth.md の個人境界数" "$personal" \
    "$(pick '個人境界 [0-9]+ / 契約境界' docs/design/auth.md)" "docs/design/auth.md"
  expect "auth.md の契約境界数" "$contract" \
    "$(pick '契約境界 [0-9]+\)' docs/design/auth.md)" "docs/design/auth.md"
fi
if [[ -f docs/design/architecture.md ]]; then
  expect "architecture.md のテーブル数" "$rows" \
    "$(pick '\(テーブル [0-9]+ \+ 例外' docs/design/architecture.md)" "docs/design/architecture.md"
  expect "architecture.md の例外 (機能テーブル以外) 件数" "$non_functional" \
    "$(pick '\(テーブル [0-9]+ \+ 例外 [0-9]+' docs/design/architecture.md)" "docs/design/architecture.md §4 の索引"
fi
if [[ -f aidlc-docs/inception/productionization/plan.md ]]; then
  expect "plan.md (Task-3a) のテーブル数" "$rows" \
    "$(pick '\*\*テーブル [0-9]+ \(全件に' aidlc-docs/inception/productionization/plan.md)" \
    "aidlc-docs/inception/productionization/plan.md"
fi

# ── 結果 ─────────────────────────────────────────────────────
# pick() の多重ヒット検出をここで集計する (サブシェルで加算できないため)
if [[ -s "$MULTIHIT_LOG" ]]; then
  cat "$MULTIHIT_LOG"
  errors=$((errors + $(wc -l < "$MULTIHIT_LOG" | tr -d ' ')))
fi

echo "[table-counts] 実測: 機能テーブル $rows (個人 $personal / 契約 $contract) / 分類 ①$c1 ②$c2 ③$c3"
echo "[table-counts] 実測: 機能テーブル以外 $non_functional (所有者列なし $excl_a / 所有者列あり $excl_b) / 検査①の除外リスト $exclusion"
echo "[table-counts] 照合 $checked 件 / エラー $errors 件"
if [[ "$errors" -gt 0 ]]; then
  echo "[table-counts] **テーブルを追加・削除したら、上の全件数を同じ差分で直すこと** (docs/design/API/idea-boards.md §8.2 に実例)"
  exit 1
fi
exit 0
