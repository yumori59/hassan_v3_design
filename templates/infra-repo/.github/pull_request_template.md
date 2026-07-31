Closes #<issue番号>

## 1. 対象 AC-ID と変更の要約

- 対象 AC-ID: `<feature> / AC-x.y` (issue の「対象 AC-ID」欄と一致させる)
- 影響する対象: `<modules/network / modules/ecs / modules/rds / modules/iam / modules/observability / envs/dev / envs/prod / Secrets / state>`
- 変更の要約 (3 行以内):
  -

## 2. DoD チェックリスト (機械検証項目)

ID は `.claude/rules/02-issue-granularity.md` §3.1 の V-x に対応する。**ID を消さない**。
未充足の項目が 1 つでもあれば **PR を ready にしない** (draft のまま S-6 に戻る)。
V-2 / V-3 は `modules/` の `terraform test` に適用する。`envs/` のみの変更では V-7 が代替になる
(`.claude/rules/01-construction-loop.md` §2.4)。

- [ ] **V-1** CI の全ジョブが green (fmt / validate / tflint / plan)
- [ ] **V-2** `modules/` を変更した場合、対象 AC-ID が `terraform test` のテスト名に存在する / **`envs/` のみのため該当なし**
- [ ] **V-3** 対象 AC のテストを実行して PASS (`terraform test`) / **該当なし**
- [ ] **V-4** 検証ゲート全通過 (`terraform fmt -check -recursive` / `validate` / `tflint --recursive` / `plan`)
- [ ] **V-5** `terraform fmt` 済み (差分なし)
- [ ] **V-7** `plan` の差分が issue の「期待する plan 差分」の宣言と一致する (差異があれば §3 に理由を書いた)
- [ ] **V-8** `Closes #<issue番号>` を記載し、GitHub 上で issue とリンクしている
- [ ] **V-9** ブランチ名が `<type>/<issue番号>-<slug>` である
- [ ] **V-10** リポ内ドキュメントを更新した / **該当なし** (新コマンド → `CLAUDE.md` のコマンド表、新バグパターン → `.claude/rules/feedback_review_patterns.md`、IaC 管理範囲外にしたリソースの理由コメント)

## 3. plan の結果 (貼り付け必須)

**`plan` が通ることは「正しい」ことを意味しない**。add / change / destroy の件数と内容、
想定外の差分の有無を明示する。

- 事前宣言 (issue の「期待する plan 差分」) との一致: 一致 / 差異あり (差異の内容と理由:)
- add / change / destroy の件数: `add <n> / change <n> / destroy <n>`
- **`must be replaced` / `will be destroyed` の有無**: なし / あり
  - ある場合、対象リソースと**データ消失の有無**、なぜ許容できるか:

<details><summary>terraform plan (dev) の要約</summary>

```
```

</details>

<details><summary>terraform test の出力 (modules/ を変更した場合。Red と Green の両方)</summary>

```
```

</details>

## 4. レビュー結果 (S-7)

- [ ] **別セッションの `infra-reviewer`** で実施した (実装した `infra-engineer` と同一セッションではない)
- [ ] **重大 (Must Fix) ゼロ**
- レビュー巡目: `<n> / 2` (2 巡で収束しなかった場合は `needs-human` を付けて停止し、この PR を ready にしない)
- 中・軽微の指摘の扱い: この PR で修正した / 別 issue に切った (`#<番号>`) — **重大は別 issue に切らない**
- 確認結果 (該当したものと対処): state 破壊 / `destroy`・`replace` を伴う差分 /
  IAM 権限の過剰付与 / シークレットの平文化 (`.tf`・`.tfvars`・state) / 環境間の定義コピー / 該当なし

## 5. 依存と後続

- 依存 issue (他リポ): **なし (このリポが依存の先頭)** / `<owner>/<repo>#N`
- **このリポの出力を待っている後続 issue**: `<owner>/<backend-repo>#N` (この PR の `apply` 完了後に着手可) / なし
- 出力値 (RDS エンドポイント / ECS クラスタ名 / Secrets ARN) の変更: なし / あり
  - ある場合、受け取り側 (backend / frontend) の対応 issue と、先に確認した内容:

## 6. 適用が必要な変更 (マージ後の人間承認点)

**`apply` はエージェントが実行しない**。承認点の ID は `.claude/rules/04-human-checkpoints.md` §1.1 の H-x。
該当なしの場合も「**該当なし**」と明記する。

- [ ] **`terraform apply` (dev)** — 人間のみが実行する (`04` §1.1 の注記 + §3.1)。適用対象のディレクトリ:
- [ ] **`terraform apply` (prod)** (`04` の H-4) — dev で検証済みであること:
- [ ] **state 操作** (`import` / `state rm`) — 実行内容と理由:
- [ ] **該当なし** (コード整理のみで適用不要)

## 7. H-5 (着手前の計画承認)

どちらか一方を必ず残す (`.claude/rules/04-human-checkpoints.md` §2.5 — URL の無い該当 PR は approve されない):

- [ ] **該当なし** (issue で「着手前の計画承認」を選択していない)
- [ ] **該当あり** — 承認コメントの URL: `<issue コメントの URL>`

## 8. 人間レビュアーへ

- 適用前に特に確認してほしい差分 (リソース名と理由):
- 手作業 (AWS コンソール) が残る項目と、IaC 管理範囲外にした理由:
- 設計と異なる判断をした箇所: **なし** / あり (ある場合は設計リポへ差し戻すべきかを書く)
