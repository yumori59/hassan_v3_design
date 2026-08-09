Closes #<issue番号>

## 1. 対象 AC-ID と変更の要約

**対象サブツリー** (該当するものを残し、他は削除する。§2 のチェックリストも同じ側だけを残す):

- [ ] **backend** (`backend/`)
- [ ] **frontend** (`frontend/`)
- [ ] **api** (`api/openapi.yaml` — 契約のみの変更。backend / frontend の少なくとも一方と同時になる)

- 対象 AC-ID: `<feature> / AC-x.y, AC-x.z` (issue の「対象 AC-ID」欄と一致させる)
- 影響する層:
  - backend: `<Controller / UseCase / Service / Repository / DB スキーマ / Managed Agent / 生成物>`
  - frontend: `<画面 / コンポーネント / 純粋ロジック (lib) / API クライアント / デザイントークン / E2E>`
- 変更の要約 (3 行以内):
  -

## 2. DoD チェックリスト (機械検証項目)

ID は `.claude/rules/02-issue-granularity.md` §3.1 の V-x に対応する。**ID を消さない**。
V-7 (Terraform plan の突合) は infra リポ専用のため本テンプレートには無い。
未充足の項目が 1 つでもあれば **PR を ready にしない** (draft のまま S-6 に戻る)。

**共通**:

- [ ] **V-1** CI の全ジョブが green (**`gate` ジョブが green であること** — 個別ジョブは skip され得る)
- [ ] **V-8** `Closes #<issue番号>` を記載し、GitHub 上で issue とリンクしている
- [ ] **V-9** ブランチ名が `<type>/<issue番号>-<slug>` である
- [ ] **V-10** リポ内ドキュメントを更新した / **該当なし** (どちらかを残す。新コマンド → 該当サブツリーの `CLAUDE.md` のコマンド表、新バグパターン → `.claude/rules/feedback_review_patterns.md`)

**backend を触った場合** (触っていなければこのブロックを削除する):

- [ ] **V-2** 対象 AC-ID すべてがテスト名に存在する (`grep -rE "func Test.*ACx_y" --include='*_test.go' backend/` が全 AC で OK)
- [ ] **V-3** 対象 AC のテストを名指しで実行して PASS (`make -C backend test-ac AC=ACx_y` 相当。`no tests to run` は未充足)
- [ ] **V-4** 検証ゲート全通過 (`backend/` で `go build ./...` / `go vet ./...` / `go test ./...` / `golangci-lint run`)
- [ ] **V-5** 生成物の再生成漏れゼロ (`make -C backend sqlc wire` 後に `scripts/check-regen.sh backend`。**裸の `git diff` を使わない** — 新規生成物を見落とす)
- [ ] **V-6** **`api/openapi.yaml` が同期している** (`make -C backend docs` 後に `scripts/check-regen.sh api/openapi.yaml`。frontend の型再生成が必要なら §5 に明記した)

**frontend を触った場合** (触っていなければこのブロックを削除する):

- [ ] **V-2** 対象 AC-ID すべてがテスト名に存在する (`grep -rn "AC-x.y" --include='*.test.ts' --include='*.test.tsx' frontend/src/`)
- [ ] **V-3** 対象 AC のテストを名指しで実行して PASS (`frontend/` で `npx vitest run -t 'AC-x.y'`。0 件マッチは未充足)
- [ ] **V-4** 検証ゲート全通過 (`frontend/` で `npx tsc --noEmit` / `npm run test` / `npm run build` / `npm run lint`)
- [ ] **V-5** 生成型の再生成漏れゼロ (`npm --prefix frontend run generate` 後に `scripts/check-regen.sh frontend/src/generated`)
- [ ] **V-6** **`frontend/src/generated` が `api/openapi.yaml` と同期している** (手書きの API 型を追加していない)

## 3. 検証出力 (貼り付け必須)

`.claude/rules/01-construction-loop.md` §2.1 の受理条件 3 点。**assertion の失敗**を含む Red を貼る
(コンパイルエラー / 型エラーのみの状態は Red として受理しない)。

<details><summary>S-4 Red (失敗したテスト名と失敗理由)</summary>

```
```

</details>

<details><summary>S-5 / S-6 Green (対象テストの PASS + 全体テスト + lint + 生成物差分 + AC-ID⇔テスト名の照合出力 — `01` §2.3)</summary>

```
```

</details>

## 4. レビュー結果 (S-7)

- [ ] **別セッションのレビュアーで実施した** (自己レビューではない) — backend は **`code-reviewer`** / frontend は **`frontend-reviewer`**
- [ ] **重大 (Must Fix) ゼロ**
- レビュー巡目: `<n> / 2` (2 巡で収束しなかった場合は `needs-human` を付けて停止し、この PR を ready にしない)
- 中・軽微の指摘の扱い: この PR で修正した / 別 issue に切った (`#<番号>`) — **重大は別 issue に切らない**
- backend: A 領域 (認証・テナント) の確認結果:
- backend: O 領域 (可観測性・LLM コスト) の確認結果:
- frontend: 頻出パターンの確認結果 (該当したものと対処): FE-1 (AbortError) / FE-2 (snake_case 漏れ) /
  FE-3 (デザイントークン) / FE-4 (パーサーの非 export) / FE-5 (lib への JSX 混入) /
  FE-6 (数値パースのレンジ誤抽出) / FE-7 (分割 waitFor) / 該当なし

## 5. 依存とマージ順序

- 依存 issue (**infra リポ**) とその状態: `<owner>/<infra-repo>#N (merged / apply 済 / 未マージ)` または **なし**
  (依存順序は `infra → app`。**FE/BE 間の依存はリポ内に閉じるため本欄の対象ではない**)

**API 破壊的変更の段** (MR-6。`.claude/rules/02-issue-granularity.md` §2.2.1):

- [ ] **該当なし** (後方互換な変更のみ — **FE と BE を同一 PR に同梱してよい**)
- [ ] **① BE で新旧併存** (旧 IF を残したまま新 IF を追加。この PR に FE の切替を含めない)
- [ ] **② FE 切替** (① の PR: `#N` がマージ済み。この PR に BE の旧削除を含めない)
- [ ] **③ BE で旧削除** (② の PR: `#N` が **`production` に Promote 済み**。`main` へのマージだけでは不可)

> **①②③ を 1 PR に同梱してはいけない** (設計リポ hassan_v3 `docs/design/architecture.md` §3.11.2 の MR-6)。
> 3 リポ構成では「FE と BE が別リポ = 別 PR」であることが順序を無償で担保していたが、
> モノレポでは 1 PR で同時マージできてしまう。**この宣言欄が唯一の検出経路**である。

## 6. 適用が必要な変更 (マージ後の人間承認点)

承認点の ID は `.claude/rules/04-human-checkpoints.md` §1.1 の H-x。
該当なしの場合も「**該当なし**」と明記する (無記載でマージすると Agent 再発行漏れ等が起きる)。

- [ ] **DB マイグレーションの適用** (`04` の H-2) — 適用対象のファイル:
- [ ] **Managed Agent の再発行** (`04` の H-3) — system prompt / custom tool schema を変更した場合は必須。
      変更した tool 名と、schema / handler / prompt 説明の 3 者一致を確認した箇所:
- [ ] **本番デプロイ** (`04` の H-4) — backend は ECS (`deploy-backend.yml`) / frontend は Vercel の Promote。出す判断は別途
- [ ] **Vercel の環境変数の追加・変更** — Project Settings (dev / preview / production) で人手設定が必要な項目:
- [ ] **該当なし**

## 7. H-5 (着手前の計画承認)

どちらか一方を必ず残す (`.claude/rules/04-human-checkpoints.md` §2.5 — URL の無い該当 PR は approve されない):

- [ ] **該当なし** (issue で「着手前の計画承認」を選択していない)
- [ ] **該当あり** — 承認コメントの URL: `<issue コメントの URL>`

## 8. 人間レビュアーへ

- 特に見てほしい箇所 (ファイルと理由):
- frontend: プロトタイプ (hassan_v3 の `docs/prototype/`) と挙動が異なる箇所とその根拠 (**仕様は設計書が正**):
- 設計と異なる判断をした箇所: **なし** / あり (ある場合は設計リポへ差し戻すべきかを書く。実装で辻褄を合わせない)
