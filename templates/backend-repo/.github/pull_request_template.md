Closes #<issue番号>

## 1. 対象 AC-ID と変更の要約

- 対象 AC-ID: `<feature> / AC-x.y, AC-x.z` (issue の「対象 AC-ID」欄と一致させる)
- 影響する層: `<Controller / UseCase / Service / Repository / DB スキーマ / Managed Agent / 生成物>`
- 変更の要約 (3 行以内):
  -

## 2. DoD チェックリスト (機械検証項目)

ID は `.claude/rules/02-issue-granularity.md` §3.1 の V-x に対応する。**ID を消さない**。
V-7 (Terraform plan の突合) は infra リポ専用のため本テンプレートには無い。
未充足の項目が 1 つでもあれば **PR を ready にしない** (draft のまま S-6 に戻る)。

- [ ] **V-1** CI の全ジョブが green
- [ ] **V-2** 対象 AC-ID すべてがテスト名に存在する (`grep -rE "func Test.*ACx_y" --include='*_test.go' .` が全 AC で OK)
- [ ] **V-3** 対象 AC のテストを名指しで実行して PASS (`go test ./... -run 'ACx_y' -v`。`no tests to run` は未充足)
- [ ] **V-4** 検証ゲート全通過 (`go build ./...` / `go vet ./...` / `go test ./...` / `golangci-lint run`)
- [ ] **V-5** 生成物の再生成漏れゼロ (`make sqlc wire docs` 後に `git diff --exit-code`)
- [ ] **V-6** OpenAPI 定義が同期している (frontend の型再生成が必要なら §5 に明記した)
- [ ] **V-8** `Closes #<issue番号>` を記載し、GitHub 上で issue とリンクしている
- [ ] **V-9** ブランチ名が `<type>/<issue番号>-<slug>` である
- [ ] **V-10** リポ内ドキュメントを更新した / **該当なし** (どちらかを残す。新コマンド → `CLAUDE.md` のコマンド表、新バグパターン → `.claude/rules/feedback_review_patterns.md`)

## 3. 検証出力 (貼り付け必須)

`.claude/rules/01-construction-loop.md` §2.1 の受理条件 3 点。**assertion の失敗**を含む Red を貼る
(コンパイルエラーのみの状態は Red として受理しない)。

<details><summary>S-4 Red (失敗したテスト名と失敗理由)</summary>

```
```

</details>

<details><summary>S-5 / S-6 Green (対象テストの PASS + 全体テスト + lint + 生成物差分 + AC-ID⇔テスト名の照合出力 — `01` §2.3)</summary>

```
```

</details>

## 4. レビュー結果 (S-7)

- [ ] **別セッションの `code-reviewer`** で実施した (自己レビューではない)
- [ ] **重大 (Must Fix) ゼロ**
- レビュー巡目: `<n> / 2` (2 巡で収束しなかった場合は `needs-human` を付けて停止し、この PR を ready にしない)
- 中・軽微の指摘の扱い: この PR で修正した / 別 issue に切った (`#<番号>`) — **重大は別 issue に切らない**
- A 領域 (認証・テナント) の確認結果:
- O 領域 (可観測性・LLM コスト) の確認結果:

## 5. 依存とマージ順序

- 依存 issue (他リポ) とその状態: `<owner>/<repo>#N (merged / apply 済 / 未マージ)` または **なし**
- API 破壊的変更の段: ①新旧併存 / ②frontend 切替 / ③旧削除 / **該当なし**
- frontend 側の対応: 型再生成が必要 (対応 issue `#N`) / 不要

## 6. 適用が必要な変更 (マージ後の人間承認点)

承認点の ID は `.claude/rules/04-human-checkpoints.md` §1.1 の H-x。
該当なしの場合も「**該当なし**」と明記する (無記載でマージすると Agent 再発行漏れ等が起きる)。

- [ ] **DB マイグレーションの適用** (`04` の H-2) — 適用対象のファイル:
- [ ] **Managed Agent の再発行** (`04` の H-3) — system prompt / custom tool schema を変更した場合は必須。
      変更した tool 名と、schema / handler / prompt 説明の 3 者一致を確認した箇所:
- [ ] **本番デプロイ** (`04` の H-4) — 出す判断は別途
- [ ] **該当なし**

## 7. H-5 (着手前の計画承認)

どちらか一方を必ず残す (`.claude/rules/04-human-checkpoints.md` §2.5 — URL の無い該当 PR は approve されない):

- [ ] **該当なし** (issue で「着手前の計画承認」を選択していない)
- [ ] **該当あり** — 承認コメントの URL: `<issue コメントの URL>`

## 8. 人間レビュアーへ

- 特に見てほしい箇所 (ファイルと理由):
- 設計と異なる判断をした箇所: **なし** / あり (ある場合は設計リポへ差し戻すべきかを書く。実装で辻褄を合わせない)
