#!/usr/bin/env bash
# check-monorepo-ci.sh — app モノレポの CI 機構 (MR-1〜MR-6) の整合を機械照合
#
# 背景 (2026-08-04。design-reviewer のレビューで判明):
#   3 リポ → app モノレポ + infra リポの 2 分割 (Q-2 の [Answer 2]) に伴い、
#   `templates/app-monorepo/` に **MR-1〜MR-6 という新しい機構**を導入した。
#   ところがレビュアーの故障注入 3 種 (①`gate` の `needs` から 1 ジョブ削除
#   ②issue テンプレートの `required: true` を false ③「6 機構」→「5 機構」に改ざん) が
#   **3/3 とも `make check` で非検出**だった。
#   つまり **`make check` の緑は「モノレポ機構が壊れていないこと」を何も意味していなかった**。
#
#   これは `feedback_review_patterns.md` の
#     - DR-9 (件数の転記が複数文書に散る → 機械強制に移す)
#     - DR-10 (構造変更が無償で成立していた担保を黙って外す)
#   の両方に該当する。したがってレビュー観点に置かず**機械強制する**。
#
# 検査するもの:
#   ① `ci.yml` の job 集合 == `gate` の `needs` == `gate` 内で判定している名前
#      (ジョブを増やしたのに `gate` の更新を忘れると、そのジョブの失敗が必須チェックを通る)
#   ② issue テンプレート 3 本 × `required: true` 5 件 (AC-2.3 の実体)
#   ③ MR-1〜MR-6 の実測本数 ↔ 各文書の自称値 (「6 機構」等) の照合 (DR-9)。
#      **`M-x` は既に 4 つの名前空間 (モデル判定 / LLM 移送段 / data-model / 過去レビューの Must-fix 連番)
#      に使われていたため
#      2026-08-04 に `MR-x` へ改名した** — 本検査が `MR-` のみを対象にすることで誤検知を避ける
#   ④ 雛形に**裸の `git diff --exit-code`** が復活していないこと
#      (未追跡ファイルを見ないため契約検査が素通りする = 2026-08-04 の重大 1)
#   ⑤ `deploy-backend.yml` の `on.push.paths` ⊆ `ci.yml` の path filter パターン
#      (デプロイのトリガ条件が CI より広いと「CI が見ていない変更でデプロイされる」)
#   ⑥ `ci.yml` の `D-2⑨` の `targets` == `backend/.golangci.yml` の
#      `L3-no-sqlc-outside-repository` の `files` に現れるドメイン集合 (中 6)
#   ⑦ PR テンプレートに V-1〜V-10 の ID が全部あること (1 本化でブロック削除運用にしたため)
#   ⑧ `e2e.yml` の `workflows: [<name>]` == `deploy-backend.yml` の `name:`
#      (リネームで E2E が無言に起動しなくなる経路を塞ぐ)
#   ⑨ モノレポ機構を素の `M-x` で書いていないこと (`MR-x` への改名漏れ。`M-x` は 4 名前空間で使用中)
#   ⑩ `changes` の `outputs:` == `filters:` のキー == 各ジョブの `if:` が参照するキー
#      (**フィルタを消すとそのジョブの `if` が恒久的に偽になり、常に skip・gate 緑になる**)
#   ⑪ ⑤の逆方向 — `ci.yml` の `backend` ジョブを起動するパターン ⊆ `deploy-backend.yml` の `paths`
#      (CI は走るのにデプロイされない = dev に反映されず E2E も発火しない)
#   ⑫ `ci.yml` / `deploy-backend.yml` の実測ジョブ数 ↔ `operations.md` の自称値 (DR-9)
#   ⑬ `CODEOWNERS` の `/api/` が **1 行かつオーナー 1 件**であること
#      (1 行 2 オーナー / 同一パス 2 行はどちらも「双方の承認」にならない = 2 巡目 R2-3)
#   ⑭ `04-human-checkpoints.md` §2.6 の「回避可」行数 ↔ 直後のガード段落の自称値・ID 列挙
#      (「回避可を増やさない」というガード自身が、増えたことを隠していた = 3 巡目 重大 5)
#
# 2026-08-05 に ⑩〜⑬ を追加した (design-reviewer 3 巡目の重大 2)。
# **⑩〜⑬ は 2 巡目のレビューが「非検出」と実証した 4 種**であり、3 巡目で再実行しても
# 4/4 とも非検出のまま放置されていた。追加後は必ず同じ 4 種を故障注入して検出を確かめること
# (`.claude/rules/05-harness.md`「足した検査自体を故障注入で殴る」)。
#
# 使い方: bash scripts/check-monorepo-ci.sh
# 終了コード: 不一致があれば 1
set -uo pipefail

cd "$(dirname "$0")/.."

APP="templates/app-monorepo"
CI="$APP/.github/workflows/ci.yml"
DEPLOY="$APP/.github/workflows/deploy-backend.yml"
E2E="$APP/.github/workflows/e2e.yml"
PRT="$APP/.github/pull_request_template.md"
GOLANGCI="$APP/backend/.golangci.yml"
ARCH="docs/design/architecture.md"

errors=0
checked=0

fail() { echo "[monorepo-ci] NG: $*" >&2; errors=$((errors + 1)); }
ok()   { checked=$((checked + 1)); }

# **ファイルが無いときにスキップして緑にしない** — 移動・改名で静かに通ると
# 「検査が消えたことに気付けない」形になる (check-table-counts.sh と同じ方針)。
for f in "$CI" "$DEPLOY" "$E2E" "$PRT" "$GOLANGCI" "$ARCH"; do
  if [[ ! -f "$f" ]]; then
    fail "必須ファイルがありません: $f (移動・改名したら本スクリプトを同じ差分で直す)"
  fi
done
if [[ "$errors" -ne 0 ]]; then
  echo "[monorepo-ci] 照合 0 件 / エラー $errors 件" >&2
  exit 1
fi

# =====================================================================
# ① ci.yml の job 集合 == gate の needs == gate 内の判定名
# =====================================================================
# トップレベルの job 名 = 2 スペースインデントの `<name>:` 行 (jobs: 直下)。
jobs=$(awk '
  /^jobs:/        { in_jobs = 1; next }
  /^[^[:space:]]/ { in_jobs = 0 }
  in_jobs && /^  [a-z_][a-z0-9_-]*:[[:space:]]*$/ {
    gsub(/^  |:[[:space:]]*$/, ""); print
  }
' "$CI" | sort -u)

# gate の needs: [a, b, c]
needs_line=$(grep -nE '^[[:space:]]+needs:[[:space:]]*\[' "$CI" | tail -1 | cut -d: -f3-)
needs=$(echo "$needs_line" | sed 's/.*\[//; s/\].*//' | tr ',' '\n' | tr -d ' ' | grep -v '^$' | sort -u)

# gate のステップで `check <name> ...` している名前
checks=$(grep -oE '^[[:space:]]+check[[:space:]]+[a-z_][a-z0-9_-]*' "$CI" \
           | awk '{print $2}' | sort -u)

jobs_no_gate=$(echo "$jobs" | grep -v '^gate$' || true)

if [[ -z "$jobs" ]]; then
  fail "①\`ci.yml\` から job 名を抽出できませんでした (jobs: の書式が変わった可能性)"
elif [[ "$jobs_no_gate" != "$needs" ]]; then
  fail "①\`gate\` の needs が job 集合と一致しません
  job 集合 (gate を除く): $(echo "$jobs_no_gate" | tr '\n' ' ')
  gate の needs        : $(echo "$needs" | tr '\n' ' ')
  → ジョブを増減したら gate の needs も同じ差分で更新する (MR-1)。
    needs から漏れたジョブは **失敗しても必須チェックを通る**"
else
  ok
fi

if [[ -n "$needs" && "$checks" != "$needs" ]]; then
  fail "①\`gate\` の needs と、gate 内で判定している名前が一致しません
  needs : $(echo "$needs" | tr '\n' ' ')
  check : $(echo "$checks" | tr '\n' ' ')
  → needs に足しただけで判定を書かないと、そのジョブの結果は無視される"
else
  ok
fi

# =====================================================================
# ② issue テンプレート 3 本 × required: true 5 件 (AC-2.3)
# =====================================================================
EXPECTED_TEMPLATES=3
EXPECTED_REQUIRED=5
tmpl_files=(
  "$APP/.github/ISSUE_TEMPLATE/task-backend.yml"
  "$APP/.github/ISSUE_TEMPLATE/task-frontend.yml"
  "templates/infra-repo/.github/ISSUE_TEMPLATE/task.yml"
)
if [[ "${#tmpl_files[@]}" -ne "$EXPECTED_TEMPLATES" ]]; then
  fail "②issue テンプレートの本数の期待値がスクリプト内で崩れています"
else
  ok
fi
for f in "${tmpl_files[@]}"; do
  if [[ ! -f "$f" ]]; then
    fail "②issue テンプレートがありません: $f (AC-2.3 は 3 本を要求している)"
    continue
  fi
  n=$(grep -c 'required: true' "$f" || true)
  if [[ "$n" -ne "$EXPECTED_REQUIRED" ]]; then
    fail "②$f の必須欄が $n 件 (期待 $EXPECTED_REQUIRED)。AC-2.3 の必須 5 欄が崩れています"
  else
    ok
  fi
done

# =====================================================================
# ③ MR-1〜MR-6 の実測本数 ↔ 自称値 (DR-9)
# =====================================================================
# 定義元 = architecture.md §3.11.2 の表の `| **MR-N** |` 行
m_ids=$(grep -oE '^\| \*\*MR-[0-9]+\*\* \|' "$ARCH" | grep -oE 'MR-[0-9]+' | sort -u -V)
m_count=$(echo "$m_ids" | grep -c . || true)
if [[ "$m_count" -eq 0 ]]; then
  fail "③\`$ARCH\` から MR-x の定義行を抽出できませんでした (§3.11.2 の表の書式が変わった)"
else
  ok
  # 連番であること (MR-1..MR-N に穴が無い)
  expected_seq=$(seq 1 "$m_count" | sed 's/^/MR-/')
  if [[ "$m_ids" != "$expected_seq" ]]; then
    fail "③MR-x が連番ではありません: $(echo "$m_ids" | tr '\n' ' ') (期待 $(echo "$expected_seq" | tr '\n' ' '))"
  else
    ok
  fi
  # 「N 機構」「MR-1〜MR-N」の転記を全文照合
  # **`MR-` のみを対象にする** — 素の `M-x` は既存 4 名前空間のものが大量にあるため。
  # 「N 機構」は文脈が限られるので拾うが、モノレポ以外の「N 機構」を書いたら
  # 本検査が誤検知する (その場合は語を変えるか本検査に除外を足す)。
  # 対象は ①`MR-1〜MR-N` の範囲表記 ②「モノレポ機構」を伴う「N 機構」「N 件」。
  # 素の「N 機構」を拾うと見出し (「3.3 機構の重ね方」等) を誤検知するため文脈語を要求する。
  bad=$( { grep -rnoE 'MR-1〜MR-[0-9]+' docs/ templates/ .claude/ CLAUDE.md 2>/dev/null;
           grep -rnE 'モノレポ(化で新規に(要る|必要になった))?[^。]*[0-9]+ 機構' docs/ templates/ .claude/ CLAUDE.md 2>/dev/null \
             | grep -oE '^[^:]+:[0-9]+:.*[0-9]+ 機構' ; } \
          | grep -v 'aidlc-docs/reviews/' | grep -v 'check-monorepo-ci' || true)
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    val=$(echo "$hit" | grep -oE '[0-9]+ 機構|MR-1〜MR-[0-9]+' | grep -oE '[0-9]+$|^[0-9]+' | tail -1)
    if [[ -n "$val" && "$val" != "$m_count" ]]; then
      fail "③件数の転記が定義元とずれています (定義元 $ARCH の実測 = $m_count)
  $hit"
    else
      ok
    fi
  done <<< "$bad"
fi

# =====================================================================
# ④ 雛形に裸の `git diff --exit-code` が無いこと (重大 1 の再発防止)
# =====================================================================
# `git diff` は未追跡ファイルを見ないため、生成物の**追加**漏れが素通りする。
# 差分検査は必ず `scripts/check-regen.sh` (`git status --porcelain --untracked-files=all` 方式) を通す。
# **対象は「実行されるファイル」+ 設計文書 (`docs/` `aidlc-docs/inception/`)**。
#
# 2026-08-05 に `.md` を対象へ加えた (design-reviewer の D-5)。当初は
# 「`.md` は『裸の git diff を使わない』という注意書き自体を含むから対象外」としたが、
# **`frontend.md` と `testing.md` に「裸の `git diff --exit-code` を実行する」という
# 要求が残っているのを検査が拾えなかった** — 除外が穴になっていた。
#
# 判別方法:
#   - 実行ファイル (`.yml` / `.sh` / `pre-commit`): コメント行 (先頭 `#`) を除いた全件が違反
#   - 設計文書 (`.md`): **禁止・不在を述べている行は除外**する。
#     除外語 = `使わない` / `無いこと` / `復活` / `禁止` / `見落とす` / `見ない`
#     (これらを含まない `git diff --exit-code` の言及は「実行せよ」という要求とみなす)
#   - `aidlc-docs/reviews/` は**過去のレビュー本文**なので対象外 (指摘の引用を大量に含む)
naked=$( { grep -rn --include='*.yml' --include='*.sh' --include='pre-commit' \
             'git diff --exit-code' "$APP" templates/shared templates/infra-repo 2>/dev/null || true; } \
          | grep -v 'check-regen' \
          | awk -F: '{ line=$0; sub(/^[^:]*:[0-9]*:/, "", line); sub(/^[[:space:]]*/, "", line);
                       if (line !~ /^#/) print }' || true)
naked_md=$( { grep -rn --include='*.md' 'git diff --exit-code' \
                docs/ aidlc-docs/inception/ .claude/ CLAUDE.md 2>/dev/null || true; } \
             | grep -v 'check-regen' \
             | grep -vE '使わない|無いこと|復活|禁止|見落とす|見ない' || true)
if [[ -n "$naked_md" ]]; then
  fail "④設計文書に裸の \`git diff --exit-code\` を**実行する要求**が残っています
  (未追跡ファイルを見ないため、生成物の**追加漏れ**が素通りします。
   \`scripts/check-regen.sh <pathspec>\` を使う形に書き換えてください)
$naked_md"
else
  ok
fi
if [[ -n "$naked" ]]; then
  fail "④雛形に裸の \`git diff --exit-code\` があります。\`scripts/check-regen.sh\` を通してください
  (git diff は**未追跡ファイルを見ない**ため、api/openapi.yaml の初回生成・orval / sqlc の
   新規出力の追加漏れが素通りし、MR-3 が「エンドポイント追加」で空振りします)
$naked"
else
  ok
fi
if [[ ! -x "$APP/scripts/check-regen.sh" ]]; then
  fail "④\`$APP/scripts/check-regen.sh\` が無い / 実行権限がありません (MR-3 の実体)"
else
  ok
fi

# =====================================================================
# ⑤ deploy-backend.yml の paths ⊆ ci.yml の path filter パターン
# =====================================================================
# **`awk` の `gsub` は後方参照 (`\1`) を解釈しない** — 当初この形で書いたため抽出が空になり、
# 故障注入⑤ (deploy の paths に CI 未対応パターンを足す) が非検出だった (2026-08-04 に是正)。
# `sed` でクォートを剥がす素直な形にする。
ci_filters=$(sed -n '/filters: |/,/^[[:space:]]*$/p' "$CI" \
               | sed -n "s/^[[:space:]]*-[[:space:]]*'\([^']*\)'.*/\1/p" | sort -u)
dep_paths=$(sed -n '/^[[:space:]]*paths:/,/^[[:space:]]*[a-z_]*:[[:space:]]*$/p' "$DEPLOY" \
               | sed -n "s/^[[:space:]]*-[[:space:]]*'\([^']*\)'.*/\1/p" | sort -u)
if [[ -z "$ci_filters" || -z "$dep_paths" ]]; then
  fail "⑤path filter を抽出できませんでした (ci.yml の filters / deploy-backend.yml の paths の書式を確認)"
else
  ok
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    # ワークフロー自身の変更は CI の対象外でよい (デプロイ定義の変更を反映するため)
    case "$p" in .github/workflows/*) continue ;; esac
    if ! echo "$ci_filters" | grep -qxF "$p"; then
      fail "⑤deploy-backend.yml の paths '$p' が ci.yml の path filter に無い
  → **CI が見ていない変更でデプロイが走る**。ci.yml の filters に足すか paths から外す"
    else
      ok
    fi
  done <<< "$dep_paths"
fi

# =====================================================================
# ⑥ D-2⑨ の targets == .golangci.yml の L3 の files のドメイン集合
# =====================================================================
targets_line=$(grep -E '^[[:space:]]+targets="' "$CI" | head -1 || true)
if [[ -z "$targets_line" ]]; then
  fail "⑥ci.yml の D-2⑨ の targets= を抽出できませんでした"
else
  ok
  ci_domains=$(echo "$targets_line" | sed 's/.*targets="//; s/".*//' | tr ' ' '\n' \
                 | grep '^usecase/' | sed 's|usecase/||' | sort -u)
  # `L3-no-sqlc-outside-repository:` の直後の `files:` ブロック (行頭 `- "..."`) だけを読む。
  # 次の規則名 (同じインデントの `<name>:`) に当たったら打ち切る。
  gl_domains=$(awk '
    /L3-no-sqlc-outside-repository:/ { f=1; next }
    f && /^[[:space:]]*[A-Za-z0-9_-]+:[[:space:]]*$/ && !/files:|deny:|allow:/ { f=0 }
    f && /usecase\// { print }
  ' "$GOLANGCI" | grep -oE 'usecase/[a-z]+' | sed 's|usecase/||' | sort -u)
  if [[ -n "$gl_domains" && "$ci_domains" != "$gl_domains" ]]; then
    fail "⑥ci.yml の D-2⑨ targets と .golangci.yml の L3 files のドメイン集合が不一致
  ci.yml    : $(echo "$ci_domains" | tr '\n' ' ')
  golangci  : $(echo "$gl_domains" | tr '\n' ' ')
  → architecture.md §5 の D-2 行が「一致させる」と要求している"
  else
    ok
  fi
fi

# =====================================================================
# ⑦ PR テンプレートに V-1〜V-10 が全部あること
# =====================================================================
missing_v=""
for i in $(seq 1 10); do
  [[ "$i" == "7" ]] && continue   # V-7 は infra リポ専用 (02-issue-granularity.md §4.2)
  grep -q "V-$i\*\*" "$PRT" || missing_v="$missing_v V-$i"
done
if [[ -n "$missing_v" ]]; then
  fail "⑦app の PR テンプレートに DoD の ID が欠けています:$missing_v
  (02-issue-granularity.md §4.2「ID を落とさない」。1 本化 + ブロック削除運用のため機械で見る)"
else
  ok
fi
if grep -q 'V-7\*\*' "$PRT"; then
  fail "⑦app の PR テンプレートに V-7 (infra 専用) があります (§4.2 の区分と不一致)"
else
  ok
fi

# =====================================================================
# ⑧ e2e.yml の workflows: [<name>] == deploy-backend.yml の name:
# =====================================================================
dep_name=$(grep -m1 '^name:' "$DEPLOY" | sed 's/^name:[[:space:]]*//' | tr -d '\r')
e2e_ref=$(grep -A1 'workflow_run:' "$E2E" | grep 'workflows:' \
            | sed 's/.*\[//; s/\].*//' | tr -d ' ' | tr -d '\r')
if [[ -z "$dep_name" || -z "$e2e_ref" ]]; then
  fail "⑧\`deploy-backend.yml\` の name: / \`e2e.yml\` の workflows: を抽出できませんでした"
elif [[ "$dep_name" != "$e2e_ref" ]]; then
  fail "⑧\`e2e.yml\` の workflow_run が参照する名前 (\`$e2e_ref\`) が
  \`deploy-backend.yml\` の name: (\`$dep_name\`) と一致しません
  → **E2E が無言で起動しなくなる**。どちらかをリネームしたら同じ差分で直す"
else
  ok
fi

# =====================================================================
# ⑨ モノレポ機構を素の `M-x` で書いていないこと (改名漏れの検出)
# =====================================================================
# `M-x` は**4 つの別の名前空間**に使われている (モデル判定 `M-1`〜`M-4` /
# LLM 移送段 `M-0`〜`M-9` / `data-model.md` の `M-1`〜`M-20` / 過去レビューの Must-fix 連番)。
# そのためモノレポ機構は `MR-x` を使う。**改名漏れ (素の `M-x` でモノレポ機構を指す) を検出する**。
#
# 2026-08-05 の一括改名では **12 件の誤爆**が出た (他名前空間の `M-x` を `MR-x` にしてしまった)。
# 逆方向 (漏れ) は本検査で継続的に見る。**誤爆の検出は自動化していない** —
# 文脈判定が必要なため、`grep -rn 'MR-[0-9]'` の全件目視が唯一の手段である
# (ID を新設するときは `feedback_review_patterns.md` の DR-6 に従う)。
# **走査対象に `scripts/` を含める (自己適用)** — 2026-08-05 の 3 巡目レビューで、
# **本スクリプト自身に改名漏れが 6 件残っているのに検査⑨ が exit 0 を返していた**ことが判明した。
# 「モノレポ機構の改名漏れを検出する」ために新設した検査が、**自分自身を見ていなかった** (中 1)。
leak=$(grep -rnE 'モノレポ機構の M-[1-6]|モノレポ化.{0,40}[^R]M-[1-6][^0-9]' \
         docs/ templates/ scripts/ .claude/ CLAUDE.md aidlc-docs/inception/ 2>/dev/null \
         | grep -v 'aidlc-docs/reviews/' || true)
if [[ -n "$leak" ]]; then
  fail "⑨モノレポ機構を素の \`M-x\` で書いている箇所があります (\`MR-x\` に統一してください)
  \`M-x\` は 4 つの別の名前空間に使われているため、素の \`M-x\` は参照先が判別できません
$leak"
else
  ok
fi

# =====================================================================
# ⑩ changes の outputs == filters のキー == 各ジョブの if が参照するキー
# =====================================================================
# **これが最も安く担保を消せる経路**だった (2 巡目 中 R2-M4 / 3 巡目 重大 2 の FI-L)。
# `filters:` から `meta:` の 4 行を消すと `needs.changes.outputs.meta` が空文字になり、
# `meta` ジョブの `if` は恒久的に偽 → 常に skip → `gate` は `skipped` を許容するので緑。
# `meta` ジョブは今や ①`scripts/` の `bash -n` ②actionlint ③`check-regen.sh` の自己テスト
# ④`check-ci-gate.sh` (MR-1 の実装リポ側の唯一の担保) の 4 つを抱えているため、
# **4 行の削除で 1 巡目 中 1・2 巡目 D-2・D-3 の対処がまとめて無効化される**。
out_keys=$(awk '
  /^  changes:/ { in_job = 1 }
  in_job && /^    outputs:/ { in_out = 1; next }
  in_out && /^    [a-z_]+:/ { in_out = 0 }
  in_out && /^      [a-z_]+:/ { gsub(/^      |:.*$/, ""); print }
' "$CI" | sort -u)
filter_keys=$(sed -n '/filters: |/,/^$/p' "$CI" \
                | sed -n 's/^            \([a-z_][a-z0-9_]*\):[[:space:]]*$/\1/p' | sort -u)
if_keys=$(grep -oE 'needs\.changes\.outputs\.[a-z_][a-z0-9_]*' "$CI" \
            | sed 's/.*outputs\.//' | sort -u)

if [[ -z "$out_keys" || -z "$filter_keys" || -z "$if_keys" ]]; then
  fail "⑩\`changes\` の outputs / filters / if の参照キーを抽出できませんでした (書式が変わった可能性)"
else
  ok
  if [[ "$out_keys" != "$filter_keys" ]]; then
    fail "⑩\`changes\` の outputs と paths-filter の filters のキーが一致しません
  outputs : $(echo "$out_keys" | tr '\n' ' ')
  filters : $(echo "$filter_keys" | tr '\n' ' ')
  → filters から消えたキーの outputs は**空文字**になり、それを見るジョブは常に skip されます
    (skip は \`gate\` が許容するため **CI は緑のまま担保だけが消える**)"
  else
    ok
  fi
  # `if` が参照するキーは outputs の部分集合でなければならない (綴り違いは常に偽 = 常に skip)
  while IFS= read -r k; do
    [[ -z "$k" ]] && continue
    if ! echo "$out_keys" | grep -qxF "$k"; then
      fail "⑩\`needs.changes.outputs.$k\` を参照しているジョブがありますが、\`changes\` の outputs にありません
  → この条件は常に偽になり、当該ジョブは**恒久的に skip** されます"
    else
      ok
    fi
  done <<< "$if_keys"
  # 逆に「outputs にあるが誰も見ていない」キーは、ジョブ側の if を消した痕跡である
  while IFS= read -r k; do
    [[ -z "$k" ]] && continue
    if ! echo "$if_keys" | grep -qxF "$k"; then
      fail "⑩\`changes\` の outputs に \`$k\` がありますが、どのジョブの if も参照していません
  → フィルタだけ残してジョブの起動条件が失われている可能性があります"
    else
      ok
    fi
  done <<< "$out_keys"
fi

# =====================================================================
# ⑪ ⑤の逆方向: ci.yml の backend ジョブを起動するパターン ⊆ deploy の paths
# =====================================================================
# ⑤ は「デプロイの方が広い」を見る。**逆 (CI の方が広い) も事故になる** — 例えば
# `api/**` を deploy の paths から落とすと、契約だけが変わった commit が dev に反映されず、
# `e2e.yml` の `workflow_run` も発火しない (E2E が次の backend 変更まで空く。2 巡目 中 R2-M6)。
backend_if=$(grep -A3 '^  backend:' "$CI" | grep -m1 'if:' || true)
if [[ -z "$backend_if" ]]; then
  fail "⑪ci.yml の backend ジョブの if: を抽出できませんでした"
else
  ok
  backend_keys=$(echo "$backend_if" | grep -oE 'needs\.changes\.outputs\.[a-z_]+' | sed 's/.*outputs\.//' | sort -u)
  while IFS= read -r k; do
    [[ -z "$k" ]] && continue
    # そのキーの filter パターンを取り出して deploy の paths に含まれるか見る
    pats=$(sed -n "/filters: |/,/^$/p" "$CI" \
             | sed -n "/^            $k:/,/^            [a-z_]*:/p" \
             | sed -n "s/^[[:space:]]*-[[:space:]]*'\([^']*\)'.*/\1/p")
    while IFS= read -r p; do
      [[ -z "$p" ]] && continue
      if ! echo "$dep_paths" | grep -qxF "$p"; then
        fail "⑪ci.yml の backend ジョブを起動する '$p' が deploy-backend.yml の paths にありません
  → **CI は走るのにデプロイされない**。dev に反映されず e2e.yml の workflow_run も発火しません"
      else
        ok
      fi
    done <<< "$pats"
  done <<< "$backend_keys"
fi

# =====================================================================
# ⑫ 実測ジョブ数 ↔ operations.md の自称値 (DR-9)
# =====================================================================
# `operations.md` は「ジョブ名はここで数えず実物を見る」と書きながら**本数だけを書いていた**。
# ①はジョブ名の集合しか見ないため、本数の転記は無検査だった (2 巡目 中 R2-M7)。
OPS="docs/design/operations.md"
if [[ ! -f "$OPS" ]]; then
  fail "⑫$OPS がありません"
else
  ok
  ci_jobs_n=$(echo "$jobs" | grep -c .)
  # **`jobs:` 直下だけを数える** — 素の `^  <name>:` で数えると `on:` 配下の `push:` を拾う
  dep_jobs_n=$(awk '
    /^jobs:/        { in_jobs = 1; next }
    /^[^[:space:]]/ { in_jobs = 0 }
    in_jobs && /^  [a-z_][a-z0-9_-]*:[[:space:]]*$/ { n++ }
    END { print n + 0 }
  ' "$DEPLOY")
  # ci.yml の本数を語る行 =「ジョブは N 本」
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    val=$(echo "$hit" | grep -oE 'ジョブは [0-9]+ 本' | grep -oE '[0-9]+')
    if [[ -n "$val" && "$val" != "$ci_jobs_n" ]]; then
      fail "⑫ci.yml の実測ジョブ数 ($ci_jobs_n) と転記がずれています
  $hit"
    else
      ok
    fi
  done <<< "$(grep -n 'ジョブは [0-9]\+ 本' "$OPS" || true)"
  # deploy-backend.yml の本数を語る行 =「N ジョブ」
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    val=$(echo "$hit" | grep -oE '[0-9]+ ジョブ' | grep -oE '[0-9]+' | head -1)
    if [[ -n "$val" && "$val" != "$dep_jobs_n" ]]; then
      fail "⑫deploy-backend.yml の実測ジョブ数 ($dep_jobs_n) と転記がずれています
  $hit"
    else
      ok
    fi
  done <<< "$(grep -n '[0-9]\+ ジョブ' "$OPS" | grep -v '複数ジョブ' || true)"
fi

# =====================================================================
# ⑬ CODEOWNERS の /api/ が 1 行かつオーナー 1 件
# =====================================================================
# 「双方の承認」は CODEOWNERS では表現できない (2026-08-05 に確定 = 2 巡目 R2-3)。
#   - 1 行に複数オーナー → **誰か 1 人**で充足する
#   - 同じパスを 2 行     → GitHub は**最後に一致したパターンだけ**を適用する
# どちらの書き方も「双方が見る」を実現しないのに、**実現していると誤解させる**形なので機械で禁じる。
# (実装リポ側の同等検査は `04-human-checkpoints.md` §4 の awk。切り出し後はそちらが正)
CODEOWNERS="$APP/.github/CODEOWNERS"
if [[ ! -f "$CODEOWNERS" ]]; then
  fail "⑬$CODEOWNERS がありません (MR-4 の実体)"
else
  ok
  api_lines=$(grep -cE '^/api/[[:space:]]' "$CODEOWNERS" || true)
  if [[ "$api_lines" -ne 1 ]]; then
    fail "⑬CODEOWNERS の \`/api/\` の行が $api_lines 行あります (期待 1 行)
  → 同一パスを複数行書いても GitHub は**最後の 1 行しか適用しない**ため、
    「双方の承認」にはならず、**先に書いた側が無視される**"
  else
    ok
    api_owners=$(grep -E '^/api/[[:space:]]' "$CODEOWNERS" | grep -oE '@[^[:space:]]+' | grep -c . || true)
    if [[ "$api_owners" -ne 1 ]]; then
      fail "⑬CODEOWNERS の \`/api/\` のオーナーが $api_owners 件あります (期待 1 件 = 双方を含む専用チーム)
  → 1 行に複数オーナーを並べると**そのうち誰か 1 人**の承認で充足します"
    else
      ok
    fi
  fi
fi

# =====================================================================
# ⑭ 04-human-checkpoints.md §2.6 の「回避可」行数 ↔ 直後の段落の自称値・ID 列挙
# =====================================================================
# 「回避可能な N 件 (…) をこれ以上増やさない」は**回避可を増やさないための唯一のガード**である。
# ところが 2026-08-05 に MR-4 を表へ足した差分がこの段落を旧記述のまま残し、
# **ガード自身が「今まさに 1 件増えたこと」を隠していた** (3 巡目 重大 5)。
# ガードは機械で守る (DR-9 の判断の目安 (a))。
HCP="templates/shared/.claude/rules/04-human-checkpoints.md"
if [[ ! -f "$HCP" ]]; then
  fail "⑭$HCP がありません"
else
  ok
  # §2.6 の表で「回避可」(「回避不可」を除く) と判定されている行数
  avoid_rows=$(grep -cE '^\|.*\*\*回避可\*\*' "$HCP" || true)
  guard_line=$(grep -nE '回避可能な [0-9]+ 件' "$HCP" | head -1 || true)
  if [[ -z "$guard_line" ]]; then
    fail "⑭$HCP に「回避可能な N 件 (…)」のガード段落がありません
  → §2.6 の表に「回避可」を足すときの歯止めが消えています"
  else
    ok
    guard_n=$(echo "$guard_line" | grep -oE '回避可能な [0-9]+ 件' | grep -oE '[0-9]+')
    guard_ids=$(echo "$guard_line" | sed 's/.*回避可能な [0-9]* 件 (//; s/).*//' | tr '/' '\n' | tr -d ' ' | grep -c . || true)
    if [[ "$guard_n" != "$avoid_rows" ]]; then
      fail "⑭§2.6 の表の「回避可」行数 ($avoid_rows) と、ガード段落の自称値 ($guard_n) が一致しません
  $guard_line
  → 表に承認点を足したら**同じ差分でこの段落の件数と ID 列挙を更新する**
    (旧値のまま残すと「N 件を超えないこと」というガードが、既に超えていることを隠します)"
    else
      ok
    fi
    if [[ "$guard_ids" != "$avoid_rows" ]]; then
      fail "⑭ガード段落が列挙している ID の個数 ($guard_ids) が「回避可」行数 ($avoid_rows) と一致しません
  $guard_line"
    else
      ok
    fi
  fi
  # 「X と Y 以外は…回避不可能な形にする」の列挙も同じ個数であること
  excl_line=$(grep -nE '以外は GitHub 側の機構で回避不可能' "$HCP" | head -1 || true)
  if [[ -z "$excl_line" ]]; then
    fail "⑭$HCP に「… 以外は GitHub 側の機構で回避不可能な形にする」の断定文がありません"
  else
    ok
    # **`.*\*\*` は貪欲マッチで行末の `**` まで食う** — 最初の `**` 〜「以外は」だけを取り出す
    excl_ids=$(echo "$excl_line" | grep -oE '\*\*[^*]+以外は' | sed 's/^\*\*//; s/以外は$//' \
                 | tr '/' '\n' | tr -d ' ' | grep -c . || true)
    if [[ "$excl_ids" != "$avoid_rows" ]]; then
      fail "⑭「… 以外は回避不可能」が列挙する ID の個数 ($excl_ids) が「回避可」行数 ($avoid_rows) と一致しません
  $excl_line
  → **表と直接矛盾する断定**になります (実装リポへ配る規約ファイルなのでそのまま運ばれます)"
    else
      ok
    fi
  fi
fi

# =====================================================================
echo "[monorepo-ci] 実測: ci.yml の job $(echo "$jobs" | grep -c .) 本 / モノレポ機構 MR-x $m_count 件 / issue テンプレート ${#tmpl_files[@]} 本"
if [[ "$errors" -ne 0 ]]; then
  echo "[monorepo-ci] 照合 $checked 件 / エラー $errors 件" >&2
  exit 1
fi
echo "[monorepo-ci] 照合 $checked 件 / エラー 0 件"
