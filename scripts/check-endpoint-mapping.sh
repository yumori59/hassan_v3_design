#!/usr/bin/env bash
# check-endpoint-mapping.sh — API 設計のエンドポイント件数・対応表の整合を機械照合
#
# 背景 (2026-07-31 のレビュー 中 2 = R-AA-22): エンドポイントの「N 件」は
# `check-table-counts` の検算対象外だった。エンドポイントを 1 本増減すると
# **README.md §0 / §3 と auth-accounts.md §2 の複数箇所が同時に動く**ため、
# DR-9 (件数・集合サイズの転記が複数文書に散る) が API 設計側でも成立していた。
#
# 本スクリプトは**表を数えた実測値**を正とし、他所への転記がそれと一致するかを検査する。
# 照合するもの:
#   ① settings.md §5 の移植チェックリストの行数 == auth-accounts.md §2.6 の対応表の行数
#   ② auth-accounts.md §2 のエンドポイント実数 == 同書と README.md §3 に書かれた値
#   ③ README.md §3 の総覧の合計値 == 6 ドメインの内訳 + 認証・アカウント基盤
#   ④ 各ドメインファイルのエンドポイント実数 == README §3 総覧表の行・§3.1〜§3.6 の明細行数・
#     小計行・「共通規約が対象にするのは N 本」(2026-08-01 追加 — 総覧表の三重不整合
#     (個別値の合計 78 ↔ 小計 73 ↔ 明細 17 行) が①〜③をすり抜けたため)
#
# 使い方: bash scripts/check-endpoint-mapping.sh
# 終了コード: 不一致があれば 1
set -uo pipefail

cd "$(dirname "$0")/.."
AA="docs/design/API/auth-accounts.md"
RM="docs/design/API/README.md"
ST="docs/design/API/settings.md"

# ドメインファイルの集合 (2026-08-02 に 6 → 9)。**ドメインを増やすときはこの配列だけを直す** —
# 「N ドメイン」を含む正規表現とエラーメッセージは NDOM から生成されるため、
# 配列と文書の食い違いは検査④が自動的に検出する (DR-9 の機械強制)。
DOMAINS=(themes assets knowledge idea-boards news settings conversation ideas plans)
NDOM=${#DOMAINS[@]}
errors=0
checked=0

for f in "$AA" "$RM" "$ST"; do
  if [[ ! -f "$f" ]]; then
    echo "[endpoint-mapping] $f が無いためスキップ"
    exit 0
  fi
done

# 1 件の期待値照合。$1=説明 / $2=実測値 / $3=文書に書かれた値 / $4=出典
expect() {
  checked=$((checked + 1))
  if [[ -z "$3" ]]; then
    echo "[ERROR] $1: 文書側の値を取り出せなかった (パターンが変わった可能性。実測 $2) ($4)"
    errors=$((errors + 1))
  elif [[ "$2" != "$3" ]]; then
    echo "[ERROR] $1: 実測 $2 に対し文書は $3  ($4)"
    errors=$((errors + 1))
  fi
}

# 文書から最初にマッチした箇所の**末尾の数値**を取り出す (check-table-counts.sh と同じ規約)
pick() { grep -oE "$1" "$2" | head -1 | grep -oE '[0-9]+' | tail -1; }

# ── ① 移植チェックリストの対応 ────────────────────────────
# settings.md §5 の表本体: 「| <用途> | <v2 のエンドポイント> | <出典> |」の 3 列。
# 見出し行・区切り行・注記を除くため「`」でメソッドかパスを含む行に限定する。
st_rows=$(awk '/^## 5\./,/^## 6\./' "$ST" | grep -cE '^\|.*\| *`?(GET|POST|PUT|DELETE|ユーザー側|同)' || true)
# auth-accounts.md §2.6 の対応表: 「| <番号> | ... |」
aa_map_rows=$(awk '/^### 2\.6/,/^## 3\./' "$AA" | grep -cE '^\| [0-9]+ \|' || true)
expect "settings.md §5 の行数 == auth-accounts.md §2.6 の対応行数" \
  "$st_rows" "$aa_map_rows" "R-AA-22 ①"

# ── ② エンドポイント実数 ──────────────────────────────
# §2 の表本体の行: 「| GET | `/path` | ... |」
aa_eps=$(grep -cE '^\| (GET|POST|PUT|DELETE|PATCH) \| ' "$AA")
# 同書が自称する本数 (§1 冒頭または §2 冒頭の「37 エンドポイント」「計 37 本」形式)
aa_claim=$(pick '(エンドポイント|合計|計) ?\*{0,2}[0-9]+ ?\*{0,2}(本|エンドポイント)' "$AA")
expect "auth-accounts.md のエンドポイント実数 == 同書の自称値" \
  "$aa_eps" "$aa_claim" "R-AA-22 ②"

# README.md §3 の総覧表の「認証・アカウント基盤」行の本数列 (行の先頭が `| 認証・アカウント基盤 |`)。
# 表の行を直接見る — 本文中の説明文から拾うと別の数値 (403 の本数など) を掴む
rm_auth=$(grep -E '^\| 認証・アカウント基盤 \|' "$RM" | head -1 | awk -F'|' '{print $4}' | grep -oE '[0-9]+')
expect "auth-accounts.md のエンドポイント実数 == README.md §3 の総覧表の本数" \
  "$aa_eps" "$rm_auth" "R-AA-22 ②"

# 総覧表の 403 の本数 == auth-accounts.md §2 の 403 を返す行数
aa_403=$(grep -E '^\| (GET|POST|PUT|DELETE|PATCH) \| ' "$AA" | grep -c '403')
rm_403=$(grep -E '^\| 認証・アカウント基盤 \|' "$RM" | head -1 | awk -F'|' '{print $7}' | grep -oE '[0-9]+')
expect "auth-accounts.md の 403 を返すエンドポイント数 == README.md §3 の総覧表の 403 列" \
  "$aa_403" "$rm_403" "R-AA-22 ②"

# ── ②' 429 を返す本数と CodedError の値域 (2026-07-31 追加 = R-AA-25) ──
# 429 を返すエンドポイント行の実数 ↔ 同書 §3.1 / AA-D-10 / README §0 が書く「11 本」
aa_429=$(grep -E '^\| (GET|POST|PUT|DELETE|PATCH) \| ' "$AA" | grep -c '429')
aa_429_claim=$(grep -oE '(レート制限|429)[^0-9]{0,20}[0-9]+ ?本' "$AA" | head -1 | grep -oE '[0-9]+' | tail -1)
expect "429 を返すエンドポイント実数 == auth-accounts.md の自称値" \
  "$aa_429" "$aa_429_claim" "R-AA-25"

# 「429 を返す 11 本」から末尾の数値を採る (先頭から採ると "429" を拾う — pick() と同じ規約)
rm_429=$(grep -oE '429 を返す ?\*{0,2}[0-9]+ ?\*{0,2}本' "$RM" | head -1 | grep -oE '[0-9]+' | tail -1)
expect "429 を返すエンドポイント実数 == README.md §0 の値" \
  "$aa_429" "$rm_429" "R-AA-25"

# §3.1.1 の CodedError コード表の行数 ↔ 本文が書く「N コード」
aa_codes=$(grep -cE '^\| `AU-[TC]-[0-9]+`' "$AA")
aa_codes_claim=$(grep -oE '[0-9]+ ?(個の)?コード' "$AA" | head -1 | grep -oE '[0-9]+')
expect "§3.1.1 のコード表の行数 == 本文の自称値" \
  "$aa_codes" "$aa_codes_claim" "R-AA-25"

# ── ③ README §3 の合計 ───────────────────────────────
# 「**合計 149 エンドポイント** = 下表の 9 ドメイン **112 本** + 認証・アカウント基盤 …」
# ドメイン数は 2026-08-02 に 6 → 9 (conversation / ideas / plans を追加)。**数値をハードコードしない** —
# 下の DOMAINS 配列の要素数から生成し、配列を増やせば正規表現も追随する (DR-9)
rm_total=$(grep -oE '合計 ?\*{0,2}[0-9]+ ?\*{0,2}エンドポイント' "$RM" | head -1 | grep -oE '[0-9]+')
rm_domains=$(grep -oE "$NDOM ドメイン ?\\*{0,2}[0-9]+ ?\\*{0,2}本" "$RM" | head -1 | grep -oE '[0-9]+' | tail -1)
if [[ -n "$rm_total" && -n "$rm_domains" ]]; then
  expect "README.md §3 の合計 == $NDOM ドメイン + 認証・アカウント基盤" \
    "$rm_total" "$((rm_domains + aa_eps))" "R-AA-22 ③"
else
  checked=$((checked + 1))
  echo "[ERROR] README.md §3 の合計値または $NDOM ドメインの本数を取り出せなかった (パターンが変わった可能性)"
  errors=$((errors + 1))
fi

# ── ④ 全ドメイン: ファイル実測 == 総覧表の行 == §3.x の明細行数 (2026-08-01 追加 / 2026-08-02 に 9 ドメイン化) ──
dom_subtotal=0
i=0
for f in "${DOMAINS[@]}"; do
  i=$((i + 1))
  file="docs/design/API/$f.md"
  # ドメインファイルのエンドポイント表の実測 (行頭が「| GET | 」等)
  actual=$(grep -cE '^\| (GET|POST|PUT|DELETE|PATCH) \| ' "$file")
  dom_subtotal=$((dom_subtotal + actual))
  # README 総覧表の該当行 (2 列目のファイルリンクで特定) の本数列
  row=$(grep -E "^\|[^|]*\| \[$f\.md\]" "$RM" | head -1 | awk -F'|' '{print $4}' | grep -oE '[0-9]+')
  expect "$f.md のエンドポイント実数 == README §3 総覧表の本数" "$actual" "$row" "④"
  # README §3.$i の明細の行数
  next=$((i + 1))
  sec_rows=$(awk "/^### 3\\.$i /,/^### 3\\.$next |^## 4/" "$RM" | grep -cE '^\| (GET|POST|PUT|DELETE|PATCH) \| ')
  expect "$f.md のエンドポイント実数 == README §3.$i の明細行数" "$actual" "$sec_rows" "④"
done
# 小計行 (「| **小計 (6 ドメイン)** | — | **79** | …」)
rm_subtotal=$(grep -E '^\| \*\*小計' "$RM" | head -1 | awk -F'|' '{print $4}' | grep -oE '[0-9]+')
expect "$NDOM ドメイン実測の合計 == README §3 の小計行" "$dom_subtotal" "$rm_subtotal" "④"
# 冒頭の「$NDOM ドメイン N 本」と注の「共通規約が対象にするのは $NDOM ドメインの N 本」
expect "$NDOM ドメイン実測の合計 == README §3 冒頭の「$NDOM ドメイン N 本」" "$dom_subtotal" "$rm_domains" "④"
rm_kyotsu=$(grep -oE "共通規約が対象にするのは $NDOM ドメインの ?\\*{0,2}[0-9]+ ?\\*{0,2}本" "$RM" | head -1 | grep -oE '[0-9]+' | tail -1)
expect "$NDOM ドメイン実測の合計 == README §3 注の共通規約対象本数" "$dom_subtotal" "$rm_kyotsu" "④"

# ── ⑤ custom tool の本数: 定義元の表 == 転記先 (2026-08-02 追加) ──
# 起票理由: 「PoC 9 本 → v3 8 本」という数え上げた値が conversation.md の複数箇所にあり、
# tool の増減は D-6 (Agent 再発行) を伴うため必ず起きる。検算されない件数は必ずずれる (DR-9)。
CV="docs/design/API/conversation.md"
if [[ -f "$CV" ]]; then
  # §4.1 の tool 表の実測 (行頭が「| `tool_name` | 」。§4.2 の手前まで)
  tool_rows=$(awk '/^### 4\.1 /,/^### 4\.2 /' "$CV" | grep -cE '^\| `[a-z_]+` \| ')
  # 見出しの自称値 「### 4.1 採用する tool (PoC 9 本 → v3 8 本)」の後者
  tool_claim=$(grep -oE '採用する tool \(PoC [0-9]+ 本 → v3 [0-9]+ 本\)' "$CV" | head -1 | grep -oE '[0-9]+' | tail -1)
  expect "conversation.md §4.1 の tool 表の実測 == 見出しの自称値" "$tool_rows" "$tool_claim" "⑤"
  # 本文の「1 本減って N 本になる」
  tool_body=$(grep -oE '1 本減って ?\*{0,2}[0-9]+ ?\*{0,2}本' "$CV" | head -1 | grep -oE '[0-9]+' | tail -1)
  expect "conversation.md §4.1 の tool 表の実測 == 本文の「N 本になる」" "$tool_rows" "$tool_body" "⑤"
else
  checked=$((checked + 1))
  echo "[ERROR] $CV が見つからない (ファイルを移動・改名したなら本スクリプトの CV を更新すること)"
  errors=$((errors + 1))
fi

# ── ⑥ 403 の本数: 総覧表の列の合計 == 小計・本文・§5 の転記 (2026-08-02 追加) ──
# 起票理由: 403 の本数が README 内の 4 箇所に転記されているのに無検査だった (レビュー 中 4)。
# ドメインが増えるたびに 403 が増減するため、検算しないと必ずずれる (DR-9)。
# 総覧表のドメイン行 (小計・認証・合計を除く) の 403 列を合計する
sum403=$(awk -F'|' '
  /^\| \*\*小計/ {exit}
  /^\| [^|]+ \| \[[a-z-]+\.md\]/ { gsub(/[* ]/,"",$7); if ($7 ~ /^[0-9]+$/) s+=$7 }
  END{print s+0}' "$RM")
sub403=$(grep -E '^\| \*\*小計' "$RM" | head -1 | awk -F'|' '{gsub(/[* ]/,"",$7); print $7}')
expect "README §3 総覧の 403 列の合計 == 小計行の 403" "$sum403" "$sub403" "⑥"
body403=$(grep -oE '403 の ?\*{0,2}[0-9]+ ?\*{0,2}本 ?=' "$RM" | head -1 | grep -oE '[0-9]+' | tail -1)
expect "README §3 総覧の 403 列の合計 == §3 本文の「403 の N 本 =」" "$sum403" "$body403" "⑥"
a5_403=$(grep -oE '403 は合計 ?\*{0,2}[0-9]+ ?\*{0,2}本' "$RM" | head -1 | grep -oE '[0-9]+' | tail -1)
expect "README §3 総覧の 403 列の合計 == §5 の A-5 行の「403 は合計 N 本」" "$sum403" "$a5_403" "⑥"

# ── ⑦ 403 の内訳と合計行 (2026-08-02 追加。2 巡目レビュー R2-M1 = 検査⑥ の穴) ──
# 検査⑥ は「総覧のドメイン行の合計 == 小計・本文・§5」までしか見ておらず、
#   (a) 総覧「合計」行の 403 が無検査   (b) 本文の「N 本 = R-1 x 本 + R-2 y 本」の算術が無検査
# だった (故障注入で 2 種が素通りすることを確認)。両方を塞ぐ。
if [[ -n "${sum403:-}" ]]; then
  # (a) 合計行の 403 == 小計 + 認証・アカウント基盤
  aa403=$(grep -E '^\|[^|]*\| \[auth-accounts\.md\]' "$RM" | head -1 | awk -F'|' '{gsub(/[* ]/,"",$7); print $7}')
  tot403=$(grep -E '^\| \*\*合計\*\*' "$RM" | head -1 | awk -F'|' '{gsub(/[* ]/,"",$7); print $7}')
  expect "README §3 の合計行の 403 == 小計 + 認証・アカウント基盤" "$((sum403 + ${aa403:-0}))" "$tot403" "⑦"
  # (b) 本文「403 の N 本 = §2.2 の R-1 (x 本) + R-2 (… = y 本)」の x + y == N
  r1=$(grep -oE 'R-1 ?\(?\*{0,2}[0-9]+ ?\*{0,2}本' "$RM" | head -1 | grep -oE '[0-9]+' | tail -1)
  r2=$(grep -oE '= ?\*{0,2}[0-9]+ ?\*{0,2}本\)' "$RM" | head -1 | grep -oE '[0-9]+' | tail -1)
  if [[ -n "$r1" && -n "$r2" ]]; then
    expect "README §3 本文の 403 の内訳 (R-1 + R-2) == 403 の合計" "$((r1 + r2))" "$sum403" "⑦"
  else
    checked=$((checked + 1))
    echo "[ERROR] README §3 本文の 403 の内訳 (R-1 / R-2 の本数) を取り出せなかった (パターンが変わった可能性)"
    errors=$((errors + 1))
  fi
fi

# ── 結果 ────────────────────────────────────────
echo "[endpoint-mapping] 実測: auth-accounts.md $aa_eps 本 / $NDOM ドメイン $dom_subtotal 本 / settings.md §5 $st_rows 行 / custom tool ${tool_rows:-?} 本 / 403 ${sum403:-?} 本"
echo "[endpoint-mapping] 照合 $checked 件 / エラー $errors 件"
[[ "$errors" -eq 0 ]] || exit 1
