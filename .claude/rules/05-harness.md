# Rule 05: ハーネス・自動チェック

検証コマンドの実体はルート `CLAUDE.md` の「検証ゲート」節が SSOT。本ファイルは運用ルールのみを定める。

## 検証ゲートは一級の完了条件

このリポジトリの `make check` (**本数はここに書かない** — 実体は `Makefile:14`、一覧はルート `CLAUDE.md` の
検証ゲート節が SSOT。DR-9 の「書かずに定義元へのリンクにする」に従う。2026-07-31 に
`check-endpoint-mapping` を追加した際、本行の「4 ゲート」が実態とずれたため数値を落とした) は
「後で見る軽い確認」ではなく **設計成果物の完了ゲート**。

- **必須 (大きい/中程度)**: 新しい設計トピック・複数ドキュメントにまたがる変更・
  既存の設計判断を覆す変更は、確定前に `make check` を通す
- **省略可 (小さい)**: 誤字・表記ゆれ・リンク追加のみの変更は、pre-commit の doc-lint に任せてよい
- **完了報告**は `verification-before-completion` skill に従い、①変更ファイルリスト
  ②実行した検証コマンドと結果 ③残課題 を含める。曖昧な「完了しました」だけの報告は不可

### doc-lint が見るもの / 見ないもの

| 見る (機械) | 見ない (人間 / design-reviewer の仕事) |
|---|---|
| 相対リンク切れ | 参照先の**内容**が主張と合っているか |
| 参照リポジトリのパス不在 (`claude_managed_agents/...` 等) | 行番号のズレ・引用の意味的な正しさ |
| 未回答の `[Answer]:` | 回答の妥当性 |
| TODO / TBD / FIXME の残存 | 設計上の抜け漏れ |
| **`data-model.md` の表を数えた件数 ↔ 同書・他文書・CI 期待値への転記** (`check-table-counts`) | **テーブル定義そのものの妥当性** (列・FK・インデックスの設計) |
| **API のエンドポイント件数・移植チェックリストの対応** (`check-endpoint-mapping`。2026-07-31 新設) | **エンドポイント設計そのものの妥当性** (パス・入出力・ステータスコード) |

**「doc-lint が通った」は「設計が正しい」を意味しない**。事実の裏取りはレビュー観点 1 (`04-review.md`)。

### 件数の転記を機械で見る理由 (2026-07-31 に `check-table-counts` を新設)

`docs/design/data-model.md` の**テーブル件数は 4 文書に転記されており、うち 4 箇所は CI 検査の期待値**
(**照合件数は書かない** — `make check-table-counts` の出力が正。DR-9 自身の規約「書かずに定義元へのリンクにする」に従う。
2026-07-31 に除外リスト・グループ行ラベルの検算を追加した時点で 22 → 36 件に増えた)
(§3.3 の検査②-1/②-2 / §7.2 の検査 2-1/2-2)。**期待値がずれると「設計どおりに実装した検査が必ず落ちる」**形で
実装リポに出る。

`idea_tags` を **1 テーブル追加した際の連動は 15 箇所**あり、**人手の見積りが 2 回外れた**
(起草側の初版 6 件 → 3 巡目レビュー 9 件 → 実測 15 件)。外れた原因は
「`account_id` を持つテーブルを足すと §3.4.2 の 3 分類にも必ず入る = 分類①の件数が 4 箇所に現れる」ことで、
**キーワード grep では構造的に取り残しが出る**。したがってこの種の整合は
レビュー観点ではなく**機械強制**に置く。連動箇所の実例は
[../../docs/design/API/idea-boards.md](../../docs/design/API/idea-boards.md) §8.2 に記録した。

**同じ理由で `check-endpoint-mapping` を追加した (2026-07-31)**: エンドポイントの「N 件」も
`check-table-counts` の対象外だった (`docs/design/API/auth-accounts.md` の R-AA-22 = 同日のレビュー 中 2)。
照合するのは ①`settings.md` §5 の移植チェックリストの行数 ↔ `auth-accounts.md` §2.6 の対応表の行数
②同書 §2 のエンドポイント実数 ↔ 同書の自称値・`README.md` §3 の総覧表 (本数と 403 の列)
③`README.md` §3 の合計 ↔ 6 ドメイン + 認証・アカウント基盤
④**6 ドメイン各ファイルの実測 ↔ `README.md` §3 総覧表の行・§3.1〜§3.6 の明細行数・小計行・
「共通規約が対象にするのは N 本」** (2026-08-01 追加 — 総覧表の三重不整合 (個別値の合計 78 ↔
小計 73 ↔ §3.2 明細 17 行) が①〜③をすり抜けてレビューで検出されたため。①〜③は auth-accounts と
合計値しか見ておらず、ドメイン別の転記は無検査だった)。
**故障注入 4 種で検出力を確認済み** (総覧表の本数を 37→36 に改ざん / §2.6 の対応行を 1 行削除 /
総覧表のドメイン行を 22→21 に改ざん / §3.2 の明細を 1 行削除 — いずれも `exit 1` で検出)。

## pre-commit hook

`.git/hooks/pre-commit` (= `scripts/hooks/pre-commit`、`make install-hooks` で導入):

- staged の `*.md` に `doc-lint` (差分のみ。全体は CI)
- `aidlc-docs/inception/` に変更があれば `check-traceability`
- staged のシェルスクリプトに `bash -n`

失敗するとコミット不可。**`--no-verify` での回避はユーザー明示指示がない限り禁止**。

## CI (GitHub Actions)

`.github/workflows/docs-ci.yml` が PR / push で実行:

- `doc-lint` (リポジトリ全体)。CI 環境に参照リポジトリは無いので、参照先の実在チェックは
  自動的に WARN へ降格する (リンク切れ・`[Answer]` 未回答・TODO の検出は有効)
- `check-traceability` (全 feature)
- `scripts/` · `templates/` のシェルスクリプト構文チェック

**参照先の実在チェックはローカル (`make doc-lint` / pre-commit) でしか効かない** — CI 通過を
参照の正しさの証拠に使わない。

## レビューゲート (自己申告の排除)

- PreToolUse フック (`scripts/hooks/require-review-before-push.sh`) が `git push` / `gh pr create` を
  捕捉し、**設計成果物 (`docs/design/` · `docs/analysis/` · `aidlc-docs/inception/` · `templates/`) を
  含む変更には `aidlc-docs/reviews/<feature>/review*.md` を要求**、無ければブロックする。
  加えて**対応照合** (review.md に変更ファイルの相対パスが登場するか) と
  **鮮度チェック** (review.md 更新後の未レビュー変更が残っていないか) を行う。
  README・スクリプト・`.claude/` のみの変更は素通り
- PostToolUse (`auto-review-on-commit.sh`) は HEAD に設計成果物が含まれるときのみレビュー必須を促す
- レビューは**別セッションの `design-reviewer`** で行う (自己レビュー禁止)

## 実装リポジトリのハーネス

`templates/` (backend / frontend / infra の 3 セット) が実装リポ用の雛形 (CLAUDE.md・agents・skills・pre-commit・CI)。
**実装リポを立ち上げるときにコピーして使う**。雛形は初期値であって SSOT ではない —
切り出し後は実装リポ側が正になる (雛形を直しても向こうには反映されない)。
