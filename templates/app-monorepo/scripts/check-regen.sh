#!/usr/bin/env bash
# 生成物の再生成漏れを検出する (**追加・変更・削除の 3 種すべて**を対象にする)。
#
# ■ なぜ専用スクリプトにしたか (2026-08-04。design-reviewer 1 巡目の重大 1)
#
#   `git diff --exit-code -- <path>` は **未追跡ファイルを一切見ない**。
#   したがって次のような「最も頻度が高い変更」で再生成漏れの検査が**素通りする**:
#     - `api/openapi.yaml` の初回生成 (雛形の `api/` は `.gitkeep` のみ = 初回 PR が必ず素通り)
#     - エンドポイント追加で orval が **新規に吐く** `frontend/src/generated/<new>.ts`
#     - クエリ追加で sqlc が **新規に吐く** `db/rdb/<domain>/<new>.sql.go`
#   つまり「BE の IF 変更が FE の型に反映されていない PR を落とす」という
#   モノレポ化の主目的 (設計 `architecture.md` §3.11.2 の MR-3) が空振りする。
#
# ■ 実装を 2026-08-05 に作り直した (design-reviewer 2 巡目の重大 R2-1)
#
#   **初版は `git add --intent-to-add` + `git diff --exit-code` だった。これには 2 つの欠陥があった**
#   (使い捨てリポジトリでの実測で確認):
#
#     1. **削除を検出しない** — `git add` は**削除をインデックスにステージする**ため、
#        その後の `git diff` (index ↔ worktree) は差分ゼロになり **exit 0 = 緑**を返す。
#        「生成物が消えた」(エンドポイント削除で orval の出力が減る等) を見落とす。
#        **裸の `git diff` より後退していた**。
#     2. **インデックスを書き換える副作用** — ステージされた削除がインデックスに残るため、
#        ローカルで実行した直後の `git commit` に**意図しない削除が混入する**。
#
#   **現在の実装は `git status --porcelain --untracked-files=all` を使う**:
#     - 追加 (`??`) / 変更 (` M`) / 削除 (` D`) の 3 種すべてが 1 回で見える
#     - **インデックスを一切触らない** (読み取りのみ)
#     - `.gitignore` されたファイル (node_modules 等) は既定で対象外
#
#   **`git diff --exit-code` を直接書かないこと**。設計リポの `scripts/check-monorepo-ci.sh` が
#   雛形と設計文書の両方を走査し、裸の `git diff --exit-code` を検出して落とす。
#
# ■ pathspec 不一致を落とす (2026-08-05。design-reviewer 3 巡目の重大 1)
#
#   `git status -- <どのファイルにも一致しない pathspec>` は**空を返す**。
#   したがって作り直した実装は、**存在しないパスを「差分ゼロ = 最新」と解釈して緑を返していた**
#   (初版は `git diff` が `fatal: pathspec … did not match any files` で exit 128 だったため、
#   偶然ながら落ちる方向 = 安全側だった。**作り直しで安全側でなくなった**)。
#
#   pathspec は呼び出し側 (`ci.yml` / issue・PR テンプレート) に **12 箇所手書きされている**ため、
#   1 文字のタイポやディレクトリ改名 (`frontend/src/generated` → `frontend/src/api`) で
#   **MR-3 が恒久的に空振りし、しかも出力が `OK` なので壊れたことがログに残らない**。
#   これは `feedback_review_patterns.md` の DR-6 (検査が「対象 0 件」を検査して緑になる) そのもの。
#
#   **したがって「pathspec に 1 件も一致しない」を明示的に落とす**。
#   `make -C backend docs` が何も出力せずに終わったケースもここで捕まる。
#
# ■ 使い方
#     scripts/check-regen.sh <pathspec> [<pathspec> ...]
#   例:
#     scripts/check-regen.sh api/openapi.yaml
#     scripts/check-regen.sh frontend/src/generated
#     scripts/check-regen.sh backend
#
#   **リポジトリルートからの pathspec で渡す**。CI が `working-directory` を切っていても
#   本スクリプトは自分でルートへ移動するため、呼び出し側の cwd に依存しない。
#
# ■ 判定の意味
#   「その pathspec が **HEAD (+ ステージ済みの内容) と一致していない**」ことを検出する。
#   CI (fresh checkout) では「コミットされている内容と生成結果が違う = 再生成漏れ」と同義。
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <pathspec> [<pathspec> ...]" >&2
  exit 2
fi

cd "$(git rev-parse --show-toplevel)"

# pathspec が **追跡ファイルにも未追跡ファイルにも 1 件も一致しない**なら、検査対象が消えている。
# 差分ゼロ (= 最新) と区別できないため、緑を返さずに落とす (上の「■ pathspec 不一致」を参照)。
tracked=$(git ls-files -- "$@")
untracked=$(git ls-files --others --exclude-standard -- "$@")
if [ -z "$tracked" ] && [ -z "$untracked" ]; then
  echo "::error::pathspec に一致するファイルがありません: $*"
  echo ""
  echo "  検査対象が 0 件です。「差分なし」ではなく **検査が空振りしている**状態です。"
  echo "  疑う順序:"
  echo "    1. 生成コマンドが何も出力していない (例: make -C backend docs が入力不足で無出力のまま exit 0)"
  echo "    2. パスの綴り違い (呼び出し側の pathspec は ci.yml / issue・PR テンプレートに手書きされている)"
  echo "    3. ディレクトリの改名・移動 (例: frontend/src/generated → frontend/src/api)"
  echo "    4. .gitignore が生成物ごと除外している"
  exit 1
fi

# `--untracked-files=all` はディレクトリではなく**ファイル単位**で未追跡を列挙する
# (既定の `normal` はディレクトリ単位に丸めるため、どのファイルが増えたか読めない)。
status=$(git status --porcelain --untracked-files=all -- "$@")

if [ -z "$status" ]; then
  echo "[check-regen] OK: $*"
  exit 0
fi

echo "::error::生成物が最新ではありません: $*"
echo ""
echo "--- 差分の一覧 (XY: X=index / Y=worktree。?? = 未追跡 = 追加漏れ / D = 削除) ---"
echo "$status"
echo ""
echo "--- 内容の差分 (未追跡ファイルは上の一覧のみ) ---"
# **`git diff HEAD` を使う** — ステージ済みの変更も含めて HEAD との差を出す。
# 未追跡ファイルは diff に出ないため、上の一覧が唯一の手掛かりになる。
git diff HEAD -- "$@" || true
echo ""
echo "対処: 再生成コマンドを実行し、生成物をコミットしてください。"
echo "  ?? の行 = **新規ファイルの追加漏れ** (git add していない)"
echo "  D  の行 = **生成物が消えている** (再生成の入力が減ったのに commit していない)"
exit 1
