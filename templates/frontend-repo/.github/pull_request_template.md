Closes #<issue番号>

## 1. 対象 AC-ID と変更の要約

- 対象 AC-ID: `<feature> / AC-x.y, AC-x.z` (issue の「対象 AC-ID」欄と一致させる)
- 影響する層: `<画面 / コンポーネント / 純粋ロジック (lib) / API クライアント / デザイントークン / E2E>`
- 変更の要約 (3 行以内):
  -

## 2. DoD チェックリスト (機械検証項目)

ID は `.claude/rules/02-issue-granularity.md` §3.1 の V-x に対応する。**ID を消さない**。
未充足の項目が 1 つでもあれば **PR を ready にしない** (draft のまま S-6 に戻る)。
V-7 (Terraform plan の突合) は infra リポ専用のため本テンプレートには無い。

- [ ] **V-1** CI の全ジョブが green
- [ ] **V-2** 対象 AC-ID すべてがテスト名に存在する (`grep -rn "AC-x.y" --include='*.test.ts' --include='*.test.tsx' src/`)
- [ ] **V-3** 対象 AC のテストを名指しで実行して PASS (`npx vitest run -t 'AC-x.y'`。0 件マッチは未充足)
- [ ] **V-4** 検証ゲート全通過 (`npx tsc --noEmit` / `npm run test` / `npm run build` / `npm run lint`)
- [ ] **V-5** 生成物の再生成漏れゼロ (`npm run generate` 後に `git diff --exit-code`)
- [ ] **V-6** API 型が backend の OpenAPI と同期している (手書きの API 型を追加していない)
- [ ] **V-8** `Closes #<issue番号>` を記載し、GitHub 上で issue とリンクしている
- [ ] **V-9** ブランチ名が `<type>/<issue番号>-<slug>` である
- [ ] **V-10** リポ内ドキュメントを更新した / **該当なし** (新コマンド → `CLAUDE.md` のコマンド表、新バグパターン → `.claude/rules/feedback_review_patterns.md`)

## 3. 検証出力 (貼り付け必須)

`.claude/rules/01-construction-loop.md` §2.1 の受理条件 3 点。**assertion の失敗**を含む Red を貼る
(型エラーのみの状態は Red として受理しない)。

<details><summary>S-4 Red (失敗したテスト名と失敗理由)</summary>

```
```

</details>

<details><summary>S-5 / S-6 Green (対象テストの PASS + tsc + test + build + lint + 生成型の差分 + AC-ID⇔テスト名の照合出力 — `01` §2.3)</summary>

```
```

</details>

## 4. レビュー結果 (S-7)

- [ ] **別セッションの `frontend-reviewer`** で実施した (自己レビューではない)
- [ ] **重大 (Must Fix) ゼロ**
- レビュー巡目: `<n> / 2` (2 巡で収束しなかった場合は `needs-human` を付けて停止し、この PR を ready にしない)
- 中・軽微の指摘の扱い: この PR で修正した / 別 issue に切った (`#<番号>`) — **重大は別 issue に切らない**
- 頻出パターンの確認結果 (該当したものと対処): FE-1 (AbortError) / FE-2 (snake_case 漏れ) /
  FE-3 (デザイントークン) / FE-4 (パーサーの非 export) / FE-5 (lib への JSX 混入) /
  FE-6 (数値パースのレンジ誤抽出) / FE-7 (分割 waitFor) / 該当なし

## 5. 依存とマージ順序

- 依存 issue (他リポ) とその状態: `<owner>/<backend-repo>#N (merged / OpenAPI 更新済 / 未マージ)` または **なし**
- API 破壊的変更の段: **②frontend 切替** (①backend 新旧併存 の issue: `#N`) / **該当なし**
- ③ backend 旧削除の issue: `#N` (この PR のマージ + production 反映後に着手可) / 該当なし

## 6. 適用が必要な変更 (マージ後の人間承認点)

承認点の ID は `.claude/rules/04-human-checkpoints.md` §1.1 の H-x。該当なしの場合も「**該当なし**」と明記する。

- [ ] **本番デプロイ** (`04` の H-4) — Vercel production への反映。出す判断は別途
- [ ] 環境変数の追加・変更 — Vercel の Project Settings (dev / preview / production) で人手設定が必要な項目:
- [ ] **該当なし**

## 7. H-5 (着手前の計画承認)

どちらか一方を必ず残す (`.claude/rules/04-human-checkpoints.md` §2.5 — URL の無い該当 PR は approve されない):

- [ ] **該当なし** (issue で「着手前の計画承認」を選択していない)
- [ ] **該当あり** — 承認コメントの URL: `<issue コメントの URL>`

## 8. 人間レビュアーへ

- 特に見てほしい箇所 (ファイルと理由):
- プロトタイプ (hassan_v3 の `docs/prototype/`) と挙動が異なる箇所とその根拠 (**仕様は設計書が正**):
- 設計と異なる判断をした箇所: **なし** / あり (ある場合は設計リポへ差し戻すべきかを書く)
