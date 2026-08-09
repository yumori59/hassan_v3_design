# Rule 04: 人間の承認点と、それを止める機構 (app モノレポ / infra リポ 共通)

**AI 駆動でも人間が必ず判断する点**を一覧で確定し、**各点をどの機構が止めるか**を定める。
このファイルは 2 リポジトリ共通 (app モノレポ / infra リポ。`templates/shared/` から各実装リポの `.claude/rules/` にコピーされる)。

**原則: 機構の無い承認点を作らない**。「注意する」「人間が確認する」とだけ書かれた承認点は、
承認を忘れた瞬間に無言で通過する。本ルールの承認点はすべて §2 の機構と 1:1 で対応し、
機構が未設定なら**その承認点は存在しないものとして扱う** (= §4 の立ち上げ設定が完了するまでリリースしない)。

このファイルが定めるのは**承認点と機構**のみ。次は他の SSOT が持つ (ここに複製しない):

| 事項 | SSOT |
|---|---|
| 作業ループの順序・担当・ステップ ID (S-1〜S-10) | [`01-construction-loop.md`](01-construction-loop.md) |
| レビュー差し戻しの上限 (2 巡) と `needs-human` の付与条件 | 同 §3 |
| 設計リポへの差し戻し (`blocked-by-design`) の基準と手順 | 同 §4 |
| issue の粒度・DoD・リポ跨ぎ / サブツリー跨ぎのマージ順序 | rule `02-issue-granularity.md` |
| 既定モデルと昇格 / 降格 | rule `03-model-escalation.md` |
| マイグレーション方式・Agent 発行コマンドの実体 | 設計リポ hassan_v3 の `docs/design/` と各リポの `CLAUDE.md` |

> 本ルールが満たす設計リポ hassan_v3 の受入基準 (feature `construction-workflow`):
> **AC-4.1** §1 / **AC-4.2** §2 / **AC-4.3** §3 / **AC-6.2** §2.2 + §2.3。
> 本番ゲート `08-production-gates.md` への回答: **D-4** §2.2 / **D-6** §2.3 / **D-7** §2.4。
> **D-2 (CI ゲート)** は `01-construction-loop.md` §7 が回答する (本ルールでは重複定義しない)。
> **A / O 領域**は本ルールの対象外 — 先送り先は親 feature `productionization`
> (`docs/design/auth.md` / `docs/design/observability.md`)。承認点ではなく S-7 のレビュー観点として担保する
> (`01-construction-loop.md` §8)。

## 1. 承認点一覧 (AC-4.1)

**必須 4 点 (H-1〜H-4) + 条件付き 1 点 (H-5)**。これ以外の工程 (実装・レビュー・指摘反映・
dev への継続デプロイ) は人間の承認を要求しない (AI 駆動の待ち時間を作らないため)。

### 1.1 一覧

| ID | 承認点 | ループ上の位置 | 対象リポ | 承認前に見るもの (確認観点) | 承認の記録先 | 止める機構 (§2) |
|---|---|---|---|---|---|---|
| **H-1** | **PR のマージ** | S-10 | 両リポ | ① CI の **`gate` ジョブ** green (app モノレポ。個別ジョブは skip され得る — モノレポ機構の MR-1) ② PR 本文のレビュー結果要約に**重大ゼロ** ③ DoD チェックリストの充足 ④ 対象 AC-ID とテスト名の照合出力 ⑤ 依存 issue のマージ済み (infra は `apply` 済みまで) ⑥ H-2 / H-3 の該当宣言の有無 ⑦ H-5 該当 issue なら承認コメントの URL ⑧ **API 破壊的変更の段の宣言があり、①②③ が同梱されていないこと** (MR-6) | **PR の approve レビュー + マージコミット** | ブランチ保護 (必須レビュー + 必須ステータスチェック + `main` への直接 push 禁止) §2.1 |
| **H-2** | **DB マイグレーションの適用** | S-10 後 (`deploy-backend.yml` の `apply_migration` ジョブ) | app (`backend/`) | ① 適用される DDL 差分の全文 ② **破壊的変更の検出結果** (§2.2 の定義) ③ 適用先環境 ④ 後方互換か (旧イメージが動き続けるか) ⑤ ロールバック手順の有無 | **GitHub environment の承認履歴** (`prod-db` / `dev-db-destructive`) | GitHub Actions environment の required reviewers §2.2 |
| **H-3** | **Managed Agent の再発行** | S-10 後 (`apply_agent` ジョブ。**アプリのリリースより前**) | app (`backend/`) | ① prompt / tool schema の差分 ② **schema ↔ handler ↔ prompt の 3 者一致検査が green** ③ `Tools` の全置換で既存ツール (web_search 等) が落ちていないこと ④ Agent ID が変わることによる**進行中セッションの切断**の影響 | **GitHub environment の承認履歴** (`prod-agent`) | 同上 §2.3 |
| **H-4** | **本番環境への適用 (デプロイ)** | S-10 とは独立した判断 (手動起動) | app: `backend/` (ECS) / `frontend/` (Vercel) / infra リポ (`terraform apply`) | ① 対象イメージタグ / コミット SHA ② その変更が dev で検証済みであること ③ H-2 / H-3 が先に完了していること ④ infra は `plan` 差分 (`destroy` / `replace` の有無) ⑤ ロールバック手段 ⑥ **`frontend/` を prod へ出す PR の head が `main` であること** (`guard-production-pr.yml` が機械で見るが、必須チェックの指定漏れで無効化され得るため人間も見る。§4.1) ⑦ **最新の E2E 結果と、それが対象 commit を検証したものか** — **`frontend/` のみの変更では `deploy-backend.yml` が起動せず E2E も走らない** (MR-1 の path filter の帰結) ため、**FE の変更を prod へ出すときは E2E を `workflow_dispatch` で 1 回手動実行し、その結果を承認材料にする** (nightly を待つと最大 24 時間空く。2026-08-04 の design-reviewer 指摘 中 9) | **GitHub environment の承認履歴** (`prod`) / Vercel の Promote 操作ログ / infra は `apply` 実行者本人 | `workflow_dispatch` + environment 承認 + `main` 限定 §2.4 |
| **H-5** | **着手前の計画承認** (**条件付き**) | S-2 (§1.2 の条件に該当する issue のみ) | 両リポ | ① 変更計画 (触るファイル・層・追加するテーブル / エンドポイント) ② 設計書の該当節との対応 ③ **infra 跨ぎの場合はマージ順序と `apply` の位置** ④ 却下する場合は設計リポへ差し戻すかの判断 | **issue コメント** (承認者と日付を明記) | issue テンプレートの必須欄 + `needs-human` ラベルでの停止 + PR の DoD 欄 → **H-1 で検証** §2.5 |

**H-4 の環境別の扱い** (dev を人間承認で止めない — C-15「dev へ継続デプロイして検証」を律速させないため):

| 適用先 | backend の DB マイグレーション (H-2) | backend の Agent 再発行 (H-3) | サービスのリリース (H-4) |
|---|---|---|---|
| **dev** | **非破壊なら自動適用** / **破壊的変更は承認必須** (`dev-db-destructive`) | 自動 (dev の Agent ID は dev 専用。切断の影響は開発者のみ) | 自動 (`main` への push で継続デプロイ。**backend は `backend/` `api/` に差分がある場合のみ / frontend は Vercel の Ignored Build Step が判定する** — MR-1 / MR-2) |
| **prod** | **承認必須** (`prod-db`) | **承認必須** (`prod-agent`) | **承認必須** (`prod`。手動起動のみ) |

- **infra リポは dev の `terraform apply` も人間が実行する** (既存規約を維持。CI は `plan` まで)。
  理由: Terraform の差分は「非破壊」を機械判定しにくく、`replace` が RDS / ECS の作り直しになる経路がある。
- dev の破壊的マイグレーションだけ承認を要求する理由: dev の検証データ (会話ログ・生成物) は
  再現コストが高く、消えると受入確認自体ができなくなる。**環境の重要度ではなくデータ喪失の不可逆性**で線を引く。

### 1.2 H-5 (着手前承認) の該当条件 — S-2 で機械的に判定する

次の**いずれか 1 つでも該当**すれば H-5 が必要。判定は OR が issue 本文だけを見て行える形に固定する:

| 条件 | 該当の判定方法 (S-2 で確認するもの) |
|---|---|
| **① 新規ドメインの追加** | issue が**新規テーブル**または**新規 URL プレフィックス** (`/themes` `/conversations` のような第 1 階層) を追加する。issue の「影響する層」欄に Repository + 新規テーブル名がある、または API 定義に新しい第 1 階層パスを足す |
| **② 設計書に無いパターンの実装** | S-2 の時点で `01-construction-loop.md` §4.1 の 1〜4 に該当する**疑い**がある (該当が確定したら承認ではなく §4 の差し戻し)。判定材料: 設計書に該当節が見つからない / 節はあるが対象の層・カラム・ステータスコードの記述が無い |
| **③ infra 跨ぎ** | issue テンプレートの「**依存 issue**」欄に **infra リポの参照**がある、または同一機能の issue が infra リポに存在する。**app モノレポ内の FE/BE 跨ぎは該当しない** (1 PR に収まり、契約の整合は CI の `contract` ジョブが機械検証する — モノレポ機構の MR-3)。ただし**破壊的 API 変更の 3 段 (MR-6)** に該当する issue は ① または ② で拾う (新 IF の追加は通常「新規エンドポイント」= ①) |

**該当しない issue は S-2 で承認を待たずに S-3 へ進む**。該当有無の判定結果は、該当しない場合も
issue コメントに 1 行残す (`H-5: 非該当 (①②③ いずれも該当せず)`) — 後から「判定を省いた」と区別できるようにする。

### 1.3 承認待ちの扱い

- 承認待ちに入るときは**ループ位置コメントを更新**し (`01-construction-loop.md` §6.2 の 2)、
  停止理由に「人間承認待ち (H-x)」と書く。`needs-human` ラベルを付ける
- **承認待ちの間、OR は同じ issue を進めない**。他の独立した issue に移る (並列可否は同 §5)
- 承認期限は設けない。代わりに**待ちが観測できる状態**にする (`needs-human` ラベル + ループ位置コメント)。
  期限を設けて自動で進める仕組みは作らない (承認の意味が消えるため)
- **却下された場合**: H-5 は計画を作り直して再度 S-2。H-1 は S-8 (指摘反映) へ戻る。
  H-2 / H-3 / H-4 は**ワークフローの再実行**で承認をやり直す (適用済みの部分の巻き戻しは §2.2 / §2.3)

## 2. 機構での担保 (AC-4.2 / AC-6.2)

**規約文書は機構ではない**。各承認点は次の機構で止まる。

### 2.1 H-1 (PR マージ) = ブランチ保護

GitHub のブランチ保護ルール (`main`) で担保する。設定内容は §4.1。

- 必須レビュー**1 件以上** (approve が無いとマージボタンが押せない)
- 必須ステータスチェック (CI のジョブ名。§4.1 に列挙) が green でないとマージできない。
  **app モノレポでは `gate` ジョブ 1 本のみを指定する** — path filter で skip されたジョブは
  status を返さないため、個別ジョブを必須にすると PR が永久に pending になる (MR-1)
- **`main` への直接 push 禁止** (管理者含む) — エージェントが `main` を直接触る経路を塞ぐ
- 新しい commit が push されたら**既存の approve を無効化**する
  (レビュー後に差分を足して通す経路を塞ぐ)

**却下案**: ローカルの pre-push フックでレビュー未実施を止める (設計リポの
`require-review-before-push.sh` 方式)。却下理由: ローカルフックは `--no-verify` と
別クローンで回避でき、CI ランナーには存在しない。**マージを止めるのは GitHub 側でなければならない**
(設計リポ側の判断 DF-5 と同じ)。

### 2.2 H-2 (DB マイグレーション) = environment 承認 + 破壊的変更の機械検出 (D-4)

`deploy-backend.yml` を **`plan_migration` (検査・承認ルーティング) → `apply_migration` (適用)** の 2 ジョブに分ける。
`apply_migration` の `environment` は `plan_migration` の出力で決まり、**承認者が設定された environment に
入った時点でジョブが待機する** (人間が承認するまで DB に触らない)。

| 適用先 × 変更クラス | 通す environment | 承認者 |
|---|---|---|
| dev × 非破壊 | `dev` | 不要 (自動) |
| dev × **破壊的** | `dev-db-destructive` | 必要 |
| prod × 任意 | `prod-db` | 必要 |

**破壊的変更の定義 (機械判定。`plan_migration` の検査対象)** — 次のいずれかを含めば `destructive=true`:

1. `DROP TABLE` / `DROP COLUMN` / `DROP INDEX` / `DROP CONSTRAINT`
2. 列の型変更 (`ALTER COLUMN ... TYPE`)
3. デフォルト値の無い `NOT NULL` の追加
4. 既存データがある列・列組への `UNIQUE` 制約 / 一意インデックスの追加
5. テーブル・列の `RENAME`
6. `TRUNCATE` / `DELETE` / `UPDATE` を含むデータ移行 SQL

**適用前に人間へ提示するもの** (`plan_migration` がジョブサマリへ書き出す): 適用される DDL の全文、
上記 1〜6 の検出結果、適用先環境、ロールバック用の逆方向 SQL または復元手順の有無。

**ロールバック**: 破壊的変更は「適用したら戻せない」ものとして扱う。承認前に
**RDS のスナップショット取得を承認条件に含める** (承認コメントにスナップショット ID を書く)。
非破壊変更のロールバックは旧イメージへの `ecspresso rollback` のみで足りる (スキーマは前方互換なので戻さない)。

**マイグレーション方式 (psqldef / golang-migrate) は設計リポで未確定** (同 `docs/design/architecture.md` の
D-4)。方式が決まるまで `plan_migration` の差分生成コマンドはプレースホルダのままにする。
**承認が挟まる位置 (どのジョブが environment で待つか) は方式に依存しないため、本ルールで確定させる**。

**却下案**: マイグレーションをアプリ起動時に自動適用する (PoC 方式)。却下理由: 適用の可否を人間が
見る機会が無くなり、ECS のタスク複数起動時に同時適用が競合する。dev の非破壊のみ自動適用する現案は、
「見る価値のある差分だけを人間に見せる」ための線引きである。

**却下案**: 単一の `prod` environment で 1 回だけ承認する。却下理由: GitHub の承認は
**環境単位・実行単位**であり、同一 environment を使う複数ジョブは 1 回の承認でまとめて解放される。
マイグレーション差分と Agent 差分とイメージタグは**見るべき材料が別物**なので、承認も分ける
(承認履歴からも「何を承認したか」が読める)。

### 2.3 H-3 (Managed Agent の再発行) = environment 承認 + 差分検出 (D-6)

同じく **`plan_agent` → `apply_agent`** の 2 ジョブ。`apply_agent` は `apply_migration` の後・
**アプリのリリース (`release`) より前**に置く (schema を増やしたのに Agent が古いままだと、
新しい引数が黙って捨てられる / 台帳の前提チェックが常に失敗する — `feedback_review_patterns.md` の BE-8 / BE-10)。

| 適用先 | 通す environment | 承認者 |
|---|---|---|
| dev | `dev` | 不要 (自動) |
| prod | `prod-agent` | 必要 |

- `plan_agent` は **`prompts/agents.yaml` が列挙した「Agent に登録されるプロンプトと tool schema」の集合のハッシュ**を前回発行時の記録 (`/hassan-v3/<env>/agent/<name>/source-hash`) と比較し、差分が無ければ
  (**`prompts/` 全体ではない** — 直接 API 用のプロンプトの誤字修正で Agent が再発行され、進行中セッションが切れるのを避けるため。列挙と実発行対象の一致は `check-tool-contract.sh` が検査する)
  `apply_agent` をスキップする (毎回発行しない — Agent ID が変わると進行中セッションが切れる)
- 承認前に人間へ提示するもの: prompt の差分、tool schema の差分、**3 者一致検査 (CI の
  `check-tool-contract`) の結果**、置き換わる `Tools` の一覧 (全置換のため既存ツールの欠落を目視確認できる形)
- **ロールバック**: 旧 Agent ID を Secrets / SSM の前バージョンとして保持し、切り戻しは ID を戻す操作で行う。
  再発行の失敗時は `release` ジョブに進ませない (ジョブ依存で止まる)

**却下案**: Agent 再発行を手動コマンド (PoC の `update-agent-prompt` 方式) のまま運用し、
デプロイと切り離す。却下理由: 「コードだけデプロイして Agent 再発行を忘れる」が本番障害として現れる
経路をそのまま残すことになる (D-6 の主旨に反する)。

### 2.4 H-4 (本番デプロイ) = 手動起動 + environment 承認 + ref 制限 (D-7)

| リポ | 機構 |
|---|---|
| **backend** | `deploy-backend.yml` の `workflow_dispatch` (`environment: prod` を明示選択) + `release` ジョブの `environment: prod` (承認者必須) + **`main` 以外の ref からの prod 起動を最初のジョブで失敗させる** |
| **frontend** | Vercel の Production Branch を **`production`** に設定し、`main` は Preview にする。本番昇格は人間の Promote 操作 (または `production` への人間によるマージ)。`main` を Production Branch にしない。**Root Directory = `frontend`** (モノレポのため。§4.4) |
| **infra** | `apply` を CI に持たせない。人間が `plan` 差分を読んで手元で実行する。エージェント側は deny (§3) |

**dev への継続デプロイは承認を挟まない** (`main` への push で `release` ジョブが `environment: dev` を通る。
**`backend/` `api/` に差分が無い push では backend のデプロイが走らない** — path filter の判定は
`ci.yml` と `deploy-backend.yml` で同じ条件にする (片方だけ更新するとデプロイ漏れになる)。
`dev` には承認者を設定しない)。これは親 feature の確定制約 C-15 (dev 先行構築 + 継続デプロイ、
本番は開発完了後に一括切替) に対応する。

**未検証の変更を本番に出さない担保**: prod 起動時に ① ref が `main` であること (機械チェック)
② その commit が dev にデプロイ済みであること (承認前に人間が確認する項目。H-4 の確認観点②) の 2 段。
①は機械、②は人間の確認事項として承認材料に含める。

### 2.5 H-5 (着手前計画承認) = ラベル停止 + PR チェックリスト + H-1 での検証

H-5 は**完全な機械ブロックを持たない**唯一の承認点である (issue に着手すること自体を GitHub は止められない)。
そのため次の 3 段で担保し、**最終的に H-1 (ブランチ保護の必須レビュー) で検出可能にする**:

1. **issue テンプレートの必須欄**「人間チェックポイントの該当有無」に選択肢
   「着手前の計画承認 (新規ドメイン / 設計書に無いパターン / infra 跨ぎ)」を置く
   (起票時に埋まる。空欄の issue は S-1 で差し戻す。§1.2 の ①②③ のどれに該当したかは
   S-2 の判定コメントに書く)
2. **OR が S-2 で停止する**: 該当時は計画をコメントし `needs-human` ラベルを付けて待つ。
   ラベルが付いた issue のまま S-3 以降に進んだ場合、それは規約違反として PR で検出する
3. **PR 本文の DoD 欄**に「H-5 該当 issue の場合、承認コメントの URL」を必須項目として置く。
   URL が無い / 該当有無が未記載の PR は **H-1 で approve しない**

**MR-6 (破壊的 API 変更の 3 段) は H-5 の条件に含めない** — 該当する issue は ① (新規エンドポイント) で
拾われるうえ、段の順序は **PR テンプレート §5 の宣言欄 + H-1 の確認観点 ⑧** で検出する方が
「どの段の PR か」を PR 単位で判定できる (issue 単位の着手前承認では 3 段のうちどれをマージ中か分からない)。

**却下案**: 全 issue で着手前承認を必須にする。却下理由: 人間が全 issue の待ち行列の律速になり、
AI 駆動の利点が消える。**手戻りが最大になる 3 条件だけに絞る**方が費用対効果が高い (Q-3 の回答)。

### 2.6 承認点 × 機構の対応 (機構なしゼロの確認表)

| 承認点 | 機構 | 回避可能性 | 二重化 |
|---|---|---|---|
| H-1 マージ | ブランチ保護 (GitHub) | **回避不可** (サーバ側) | **app モノレポは `gate` ジョブを必須チェックに指定していることが前提** (MR-1)。指定漏れ = CI 無しでマージ可能 |
| H-2 マイグレーション | environment `prod-db` / `dev-db-destructive` の required reviewers | **回避不可** (GitHub Actions がジョブを待機させる) | エージェントには prod の DB 接続情報を渡さない (§3.3) |
| H-3 Agent 再発行 | environment `prod-agent` の required reviewers | **回避不可** | **prod の Anthropic API キーは Secrets Manager が唯一の所在**。`apply_agent` は environment `prod-agent` の OIDC ロールで `secretsmanager:GetSecretValue` して取得する (§4.2 — GitHub secret には置かない)。エージェントのローカルには prod のキーを配らない (§3.3) |
| H-4 本番デプロイ | backend / infra: `workflow_dispatch` + environment `prod` + ref 制限。frontend: **`production` ブランチ保護 (§4.1) + Vercel の Promote 権限限定 (§4.4)** | **回避不可** | `.claude/settings.json` で `gh workflow run` と `production` への push を deny (§3.2) |
| H-5 着手前承認 | issue 必須欄 + `needs-human` ラベル + PR の DoD 欄 → H-1 で検証 | **回避可** (ラベルを無視して進める余地がある) | H-1 の必須レビューで事後検出する |
| **MR-6 破壊的 API 変更の段** | PR テンプレート §5 の宣言欄 → **H-1 の確認観点 ⑧** で検証 | **回避可** (宣言を「該当なし」と書けば通る) | pre-commit が `api/` と `frontend/` の同梱を警告する (非ブロック)。**3 リポ構成のリポ境界による自動担保は失われている**ため、レビュアーが宣言欄を必ず読む |
| **MR-4 `api/` の双方レビュー** | `CODEOWNERS` の専用チーム (`@<owner>/<api-reviewers>`) + "Require review from Code Owners" → **「どちらかが見る」までは機構で担保できる** | **回避可** (**「BE と FE の双方からそれぞれ 1 名」は CODEOWNERS で表現できない** — 1 行複数オーナーは「誰か 1 人」で充足し、同じパスを 2 行書くと**最後に一致した行だけが適用される**。2026-08-05 に確定 = design-reviewer 2 巡目の重大 R2-3) | H-1 の確認観点 ⑧ + PR テンプレート §5 の宣言。**却下案**: PR の reviews API を叩いて両チームの承認を検査する CI ジョブ — team membership の取得に org 読み取り権限が必要で、`GITHUB_TOKEN` では足りない (**第 1 リリースでは採らない**。契約変更が実際に事故ったら導入する) |

**H-5 / MR-6 / MR-4 以外は GitHub 側の機構で回避不可能な形にする**。この表に「機構: なし」の行を作らないこと
(新しい承認点を足すときは、同時に機構を決める)。

**回避可能な 3 件 (H-5 / MR-6 / MR-4) をこれ以上増やさない**。いずれも
「宣言欄 + H-1 のレビューで事後検出」という同じ形であり、**検出はレビュアーが欄を読むことに依存する**。

- **MR-6** は 2026-08-04 に追加。**3 リポ構成ではリポジトリ境界が機構だった**
  (= 文書化されていない担保だった) ものが、モノレポ化で回避可能な宣言に落ちた例
  (`feedback_review_patterns.md` の DR-10)
- **MR-4** は 2026-08-05 に追加。**「BE と FE の双方から 1 名ずつ」を CODEOWNERS では表現できない**
  ため (1 行複数オーナー = 誰か 1 人で充足 / 同一パス 2 行 = 最後の 1 行だけ適用)、
  「どちらかが見る」までを機構、「双方が見る」を宣言 + レビューに落とした

> **本数の転記は機械照合している** (DR-9 の判断の目安 (a))。設計リポの
> `scripts/check-monorepo-ci.sh` の検査⑭ が「§2.6 の表の**回避可**行数 ↔ 本段落の自称値 ↔
> 列挙した ID の個数」を突き合わせる。**表に 1 行足して本段落を直し忘れると `make check` が落ちる**。
> (2026-08-05 の 3 巡目レビューで、**MR-4 を表に足した差分がこの 2 段落を旧記述のまま残し、
> 「回避可は 2 件」が 3 件目の存在を隠していた**ことが指摘された = DR-8 の「直下 2 行を読まない」型。
> **このガード自身がガードされていなかった**ので機械強制へ移した)

## 3. エージェントの自律範囲 (AC-4.3)

### 3.1 許可 / 人間のみ / deny

| 区分 | 操作 |
|---|---|
| **許可 (エージェントが自律で行う)** | ブランチ作成 (`<type>/<issue番号>-<slug>`) / `git commit` / **feature ブランチへの `git push`** / PR の作成・更新 (draft 含む) / issue へのコメント・ラベル付与 / `gh pr view` 等の読み取り |
| **人間のみ** | **PR のマージ** (H-1) / DB マイグレーションの適用 (H-2) / Managed Agent の再発行 (H-3) / 本番デプロイ (H-4) / `terraform apply` (dev 含む) / 計画承認 (H-5) |
| **deny (実行させない)** | `main` への直接 push / `git push --force` (`--force-with-lease` も) / ブランチ削除 / タグの作成・削除・push / `git commit --no-verify` / `git reset --hard` / `gh pr merge` / `gh workflow run` (デプロイの起動) / `terraform apply` `destroy` `state` 操作 / `.tfstate` の読み取り / DB の `DROP` `TRUNCATE` `DELETE`・マイグレーションファイルの削除 / `.env` 等の秘密ファイルの読み取り |

**commit / push / PR 作成を許可する根拠**: 安全性は「`main` への直接 push 禁止」+「マージは人間」+
「CI ゲートで build / vet / test / lint を機械強制」の 3 点で担保されており、feature ブランチは
壊れてよい場所である。push を毎回人間が起動する運用 (却下案 B) は、1 issue = 1 PR を回す上で
**人間が待ち行列の律速**になるため却下。

### 3.2 `.claude/settings.json` の設定例 (立ち上げ時にこの形で作る)

**下の例は説明用の jsonc (`//` コメント付き)。実ファイルはコメントを全て削除した純 JSON にする** —
コメントが残るとパースに失敗し、**permissions ブロックごと読み込まれず deny が 1 つも効かない**
(しかも失敗は目に見えない)。作成後に `python3 -m json.tool .claude/settings.json` で必ず検証する (§4.5)。

`permissions.deny` は**コマンド文字列の前方一致**で効く。文字列を変えれば回避できるため、
これは**事故防止の一次ガード**であり、境界そのものではない (境界は §2 の GitHub 側の機構)。
`autoMode` の自然言語 deny を併用して、パターンでは書けない意図 (「秘密ファイルの内容を送信しない」等) を補う。

```jsonc
{
  "permissions": {
    "deny": [
      "Read(**/.env)", "Read(**/.env.*)", "Read(**/*.pem)", "Read(**/*credentials*)",
      "Bash(git push --force:*)", "Bash(git push -f:*)", "Bash(git push --force-with-lease:*)",
      "Bash(git push origin main:*)", "Bash(git push origin HEAD:main:*)",
      "Bash(git push origin production:*)", "Bash(git push origin HEAD:production:*)",  // frontend: production = Vercel の Production Branch (§2.4)。push 1 回で本番デプロイが起動するため deny
      "Bash(git branch -D:*)", "Bash(git branch -d:*)",
      "Bash(git tag:*)", "Bash(git push --tags:*)",
      "Bash(git commit --no-verify:*)", "Bash(git commit -n:*)", "Bash(git reset --hard:*)",
      "Bash(gh pr merge:*)",            // H-1: マージは人間
      "Bash(gh workflow run:*)",        // H-2 / H-3 / H-4: デプロイの起動は人間
      "Bash(gh api:*)",                 // environment 承認 API を叩く経路を塞ぐ
      "Bash(terraform apply:*)", "Bash(terraform destroy:*)", "Bash(terraform state:*)",
      "Bash(terraform import:*)", "Read(**/*.tfstate)",
      "Bash(psql:*)", "Bash(mysql:*)",  // DB への直接接続 (適用は H-2 の機構を通す)
      "Bash(psqldef:*)", "Bash(migrate:*)"
    ],
    "allow": [
      "Bash(git status:*)", "Bash(git diff:*)", "Bash(git log:*)", "Bash(git add:*)",
      "Bash(git commit -m:*)", "Bash(git checkout -b:*)", "Bash(git push origin HEAD:*)",
      "Bash(gh pr create:*)", "Bash(gh pr view:*)", "Bash(gh issue comment:*)",
      "Bash(terraform plan:*)", "Bash(terraform validate:*)", "Bash(terraform fmt:*)"
    ]
  },
  "autoMode": {
    "soft_deny": [
      "$defaults",
      "any attempt to merge a pull request, or to trigger / approve a deployment workflow — merge (H-1) and all environment approvals (H-2 / H-3 / H-4) belong to the repository owner",
      "any command that applies schema or infrastructure changes to a shared environment (migration apply, terraform apply/destroy, ecspresso deploy), even when the tool name differs from the deny patterns",
      "bypassing the mandatory pre-commit hook (--no-verify / -n) or rewriting published history (force push, reset --hard on a pushed branch)",
      "editing the design repository hassan_v3 — design changes go back through a blocked-by-design issue comment, not through a direct edit"
    ],
    "hard_deny": [
      "$defaults",
      "reading, printing, or transmitting the contents of .env / credential / *.pem files or a production database connection string"
    ]
  },
  "hooks": {
    "PreToolUse": []                    // 実装リポでは pre-commit hook (scripts/hooks/pre-commit) が主。必要になったら追加する
  }
}
```

### 3.3 機構の重ね方 (ローカル deny だけに頼らない)

| リスク | ローカル (settings.json) | サーバ側 (回避不可) |
|---|---|---|
| `main` を直接壊す | `git push origin main` を deny | ブランチ保護で直接 push 禁止 |
| 勝手にマージする | `gh pr merge` を deny | ブランチ保護の必須レビュー |
| 本番 DB を触る | `psql` 等を deny | **エージェントのセッションに prod の接続情報を置かない** (Secrets Manager から ECS タスクにのみ注入する。ローカルの `.env` には dev / local の値だけを置く) |
| 勝手にデプロイする | `gh workflow run` / `gh api` を deny | environment の required reviewers |

**「エージェントが実行できない」ことの担保は、コマンドの deny ではなく認証情報の非配置で行う**。
deny パターンの網羅性に依存した設計にしない。

## 4. GitHub / Vercel 側で人手設定が必要な項目 (立ち上げチェックリスト)

**雛形のファイルコピーでは自動化できない項目**。実装リポを作った直後にこれを済ませる。
**このチェックリストが未完了のリポジトリは、承認点が機構で守られていない状態**である
(§2 の前提が崩れるため、`main` へのマージと本番リリースを行わない)。

### 4.1 ブランチ保護ルール (`main`) — 両リポ

- [ ] **Require a pull request before merging** を有効化 (= `main` への直接 push を禁止)
- [ ] **Require approvals: 1** 以上
- [ ] **Dismiss stale pull request approvals when new commits are pushed** を有効化
- [ ] **Require status checks to pass before merging** を有効化し、**必須チェック名**を登録:
  - **app モノレポ: `gate` の 1 本のみ** — 個別ジョブ (`backend …` / `frontend …` / `contract …`) は
    path filter で skip され得る。**skip されたジョブは status を返さない**ため、必須に指定すると
    PR が永久に pending になりマージ不能になる (モノレポ機構の MR-1)。
    `gate` は `if: always()` で全ジョブの結果を集約し、`success` / `skipped` 以外を失敗にする
  - infra リポ: `fmt / validate / lint` と `plan (dev)`
- [ ] **app モノレポ: `gate` の挙動を 3 通りの PR で確認する** — 「backend のみ変更」「frontend のみ変更」
  「両方変更」。`gate` の skipped 許容条件を書き損ねると**逆に常に落ちる**ため、
  設定直後に 1 回検証する (この確認をしていないブランチ保護は未完了とみなす)
- [ ] **app モノレポ: `.github/CODEOWNERS` を配置し、"Require review from Code Owners" を有効化** (MR-4)。
  リポジトリ境界が消えた分のレビュー担当の分離をこれで担保する。
  **`api/` は BE / FE 双方のレビュアーを含む専用チーム (`@<owner>/<api-reviewers>`) を 1 行**で割り当てる。
  ⚠️ **「双方からそれぞれ 1 名の承認」は CODEOWNERS では表現できない** — 1 行複数オーナーは
  「誰か 1 人」で充足し、**同じパスを 2 行書くと最後に一致した行だけが適用される**
  (2026-08-05 に確定)。「双方が見る」は §2.6 のとおり **H-1 の人間のレビュー**が受け皿。
  **書き込み権限そのものもサブツリー単位で分けられない**
  (3 リポ構成がリポ単位の権限で担保していた分は失われる = 受容済みの代償)
- [ ] **app モノレポ: タグ保護ルールを設定する** (MR-5)。`backend-v*` / `frontend-v*` 以外の
  タグ作成を禁止する (Settings → Tags → Protected tags)。**これが無いと MR-5 は宣言だけになる** —
  エージェント側は `.claude/settings.json` で `git tag` を deny しているが (§3.2)、
  人間の手作業や別クローンからの `v1.2.3` は防げない (2026-08-04 の design-reviewer 指摘 中 13)
- [ ] **Require branches to be up to date before merging** を有効化。
  ⚠️ **モノレポでは代償がある** — `main` が 1 本なので、**他サブツリーのマージが
  `frontend/` しか触っていない PR まで out of date にし、`gate` の再実行を要求する**
  (3 リポ構成では別リポ = 別の up-to-date 判定だったので無償で独立していた = DR-10 の 9 例目)。
  path filter はジョブの出し分けであって `changes` / `gate` の再実行は避けられない。
  **PR 同時数が増えてマージが直列化したら、①この要求を外す ②merge queue を導入する のどちらかを検討する**
  (設計リポ `docs/design/architecture.md` §3.11.2 の MR-1 の代償)。
- [ ] **Do not allow bypassing the above settings** (管理者にも適用) を有効化
- [ ] **Allow force pushes / Allow deletions を無効**のまま維持する
- [ ] **frontend のみ: `production` ブランチにも同等の保護を設定する** — 直接 push 禁止・
  必須レビュー 1 名以上・force push / deletion 禁止。
  `production` は Vercel の Production Branch (§2.4) であり、**保護が無いと push 1 回で
  本番デプロイが起動する** (§4.4 と対)
- [ ] **`production` への PR は `main` 発のみ — これは検査で担保する (設定では担保できない)**。
  **GitHub のブランチ保護 / ruleset には「PR の head ブランチを制限する」設定が無い**
  (2026-08-05 時点の理解。§5 の要確認 — 有るなら設定へ移す)。
  設定だけに頼ると、任意の `feature/*` から `production` へ PR を出して承認 1 名で
  **`main` を経ずに FE 本番へ出せる** (`operations.md` §7.3 の「dev の未リリース変更を prod に出さない」
  4 段のうち機械の 3 段は BE にしか効かない)。したがって:
  - `.github/workflows/guard-production-pr.yml` (雛形にあり) を**必須ステータスチェックに指定する** —
    `github.head_ref != 'main'` の PR を落とす
  - 併せて **H-4 (FE) の確認観点に「この PR の head が `main` であること」を含める** (二重化)

### 4.2 GitHub Environments — app モノレポ

`deploy-backend.yml` が参照する environment を作り、**承認者 (required reviewers) を設定する**。
**environment が存在しない / 承認者が未設定の場合、ジョブは待機せず素通りする** — 作成漏れは承認の消滅を意味する。

| environment | 承認者 | 用途 | 保持する値 (**IAM ロール ARN と非秘密の識別子のみ。下記以外を置かない**) |
|---|---|---|---|
| `dev` | **設定しない** (自動) | dev への継続デプロイ・非破壊マイグレーション・dev の Agent 再発行 | dev の**デプロイ用 / マイグレーション用 IAM ロール ARN** / リージョン / **ECR リポジトリ名・ECS クラスタ名・ecspresso 設定パス** (いずれも秘密ではないので variable でよい) |
| `dev-db-destructive` | **1 名以上** | dev の破壊的マイグレーションのみ | (dev と同じ) |
| **`dev-e2e`** | **設定しない** (自動) | **E2E (Playwright) の実行**。**`dev` と分ける** — モノレポでは OIDC の `sub` クレームが environment で決まるため、共有すると **E2E が dev のデプロイ用ロール (ECR push / ecspresso) を引き受けられる** (2026-08-05 追加。設計は hassan_v3 `docs/design/infrastructure.md` §4.5) | **E2E 用 IAM ロール ARN** (権限は Secrets Manager の read のみ) / リージョン / dev の baseURL |
| `prod-db` | **1 名以上** | prod の DB マイグレーション | prod の**マイグレーション用 IAM ロール ARN** / リージョン / **ECS クラスタ名・マイグレーション用タスク定義名・ロググループ名・サブネット ID・セキュリティグループ ID** (RunTask の宛先。いずれも秘密ではないので variable でよい) |
| `prod-agent` | **1 名以上** | prod の Managed Agent 再発行 | prod の**デプロイ用 IAM ロール ARN** |
| `prod` | **1 名以上** | prod のサービスリリース (ecspresso) | prod の**デプロイ用 IAM ロール ARN** |

**DB 接続情報 / Anthropic API キー / Agent ID・Environment ID を GitHub 側に置かない**
(設計リポ hassan_v3 `docs/design/operations.md` §4.1 の限定列挙。2026-07-30 に本表を是正):

- **DB 接続情報**: `apply_migration` は **ECS RunTask** で VPC 内から実行し、接続情報は
  マイグレーション実行タスク定義の `secrets` (Secrets Manager) で注入される → **CI は持つ必要がない**
- **Anthropic API キー**: `apply_agent` が **OIDC ロールで Secrets Manager から取得**する
- **Agent ID / Environment ID**: **SSM Parameter Store が唯一の所在**。CI は SSM に書き、アプリは SSM から読む
- 同じ値を GitHub secret と Secrets Manager / SSM の両方に持つと、**ローテーションが片方に効かず**
  次の `apply_migration` / `apply_agent` が旧値で動く (原因の分かりにくい失敗になる)。
  Agent ID が複数箇所にあると切り戻し先も判断できなくなる

- [ ] 上記 **6 つ**の environment を作成 (`dev` / `dev-e2e` / `dev-db-destructive` / `prod-db` / `prod-agent` / `prod`)
- [ ] **IAM ロールの信頼条件 (`sub` クレーム) を environment ごとに固定する** —
  モノレポでは `repo:` で分離できないため、**`repo:<org>/<app-repo>:environment:<name>` で分ける**
  (設計は hassan_v3 `docs/design/infrastructure.md` §4.5)。
  **`dev` と `dev-e2e` を同じロールに紐付けない**
- [ ] `prod*` と `dev-db-destructive` に required reviewers を設定 (**リポジトリのオーナー本人を含める**)
- [ ] `prod*` に **Deployment branches: `main` のみ** を設定 (ref 制限の二重化)
- [ ] 上表の値 (IAM ロール ARN と非秘密の識別子) を environment secret / variable として登録する (**リポジトリ全体の変数に置かない** —
  環境ごとに値が違うため)。**DB 接続情報・API キー・Agent ID / Environment ID を登録しないこと**を
  同時に確認する (上表の注記)

### 4.3 ラベル — 両リポ

- [ ] `needs-human` — 人間の判断待ち (H-5 の承認待ち / レビュー差し戻し上限到達 / 承認却下)
- [ ] `blocked-by-design` — 設計リポへの差し戻し中 (`01-construction-loop.md` §4)

### 4.4 Vercel (app モノレポの `frontend/`)

- [ ] **Root Directory を `frontend` に設定**する (モノレポのため。既定のリポジトリルートではビルドできない)
- [ ] **Ignored Build Step を設定**する — `frontend/` と `api/` に差分が無い push ではビルドしない
      (**モノレポ機構の MR-2**。設定しないと backend だけの PR でも毎回 Preview ビルドが走る)
- [ ] **Production Branch を `production` に変更**する (既定の `main` のままにしない)
- [ ] `main` への push は Preview デプロイに留める
- [ ] 本番昇格 (Promote) を行えるメンバーを限定する

**Root Directory と Ignored Build Step は雛形のファイルコピーで自動化できない** — Vercel の
Project Settings 側の値であり、`vercel.json` を置いても Root Directory は上書きできない。

### 4.5 設定できたことの確認 (立ち上げ時に 1 回実行し、出力を残す)

```bash
# settings.json が純 JSON であること (コメント残りは deny 全滅につながる — §3.2)
python3 -m json.tool .claude/settings.json > /dev/null && echo "settings.json OK"

# ブランチ保護 (必須レビュー数・必須チェック名・force push 禁止)
# app モノレポでは checks が ["gate"] の 1 本だけであることを確認する (MR-1)。
# 個別ジョブ名が混ざっていたら skip 時に pending で止まるので取り除く。
gh api "repos/:owner/:repo/branches/main/protection" \
  --jq '{reviews: .required_pull_request_reviews, checks: .required_status_checks.contexts, force_push: .allow_force_pushes.enabled}'

# app モノレポ: CODEOWNERS が配置され、Code Owners レビューが必須になっているか (MR-4)
test -f .github/CODEOWNERS && echo "CODEOWNERS あり" || echo "CODEOWNERS なし (MR-4 未設定)"
gh api "repos/:owner/:repo/branches/main/protection" \
  --jq '.required_pull_request_reviews.require_code_owner_reviews'
# `api/` が **専用チーム 1 行**になっているか (2 行に分けても「最後に一致した行」しか効かない)
awk '$1=="/api/"{n++; owners=NF-1} END{
  if (n==1 && owners==1) print "api/ は 専用チーム 1 行 = OK";
  else print "api/ が " n+0 " 行 / オーナー " owners+0 " 件 — 専用チーム 1 行にする (双方の承認は機構化できない)" }' .github/CODEOWNERS

# app モノレポ: タグ保護 (MR-5)。backend-v* / frontend-v* 以外の作成が禁止されているか
gh api "repos/:owner/:repo/tags/protection" --jq '.[].pattern' 2>/dev/null || echo "  (タグ保護が未設定 = MR-5 は宣言だけ)"

# --- Vercel (MR-2) は gh api で見えないため **目視で確認して結果をここに書き残す** ---
#   [ ] Project Settings → General → Root Directory = frontend
#   [ ] Project Settings → Git → Ignored Build Step にコマンドが入っている
#       (`frontend/` `api/` に差分が無ければビルドしない判定)
#   [ ] Project Settings → Git → Production Branch = production
#   確認日と確認者を issue / PR にコメントする (機械で追跡できない項目なので記録が唯一の証跡)

# frontend のみ: production ブランチの保護 (§4.1。404 なら設定漏れ = push 1 回で本番デプロイが起動する)
gh api "repos/:owner/:repo/branches/production/protection" \
  --jq '{reviews: .required_pull_request_reviews, force_push: .allow_force_pushes.enabled, deletions: .allow_deletions.enabled}'

# environment と承認者 (app モノレポ。reviewers が空の prod* があれば設定漏れ)
for e in dev dev-e2e dev-db-destructive prod-db prod-agent prod; do
  echo "== $e"
  gh api "repos/:owner/:repo/environments/$e" \
    --jq '.protection_rules[] | select(.type=="required_reviewers") | .reviewers[].reviewer.login' || echo "  (environment が無い)"
done

# ラベル
gh label list --json name --jq '.[].name' | grep -E 'needs-human|blocked-by-design'
```

## 5. 承認の記録と監査

| 承認点 | 後から追跡する方法 |
|---|---|
| H-1 | PR の Reviews タブ (approve 者・日時) とマージコミット |
| H-2 / H-3 / H-4 (`backend/`) | Actions の run 詳細に残る **environment の承認履歴** (承認者・日時・対象 environment)。承認前にジョブサマリへ出した差分もその run に残る |
| H-4 (`frontend/`) | Vercel の Deployments の Promote 履歴 |
| H-4 (infra リポ) | `apply` の実行者が **PR に `apply` 後の出力 (適用結果の要約) をコメントする** — CI に記録が残らないため、これを記録手段とする |
| H-5 | issue の承認コメント (承認者・日付) と、PR の DoD 欄に貼られたその URL |

**記録が残らない承認は行わない**。口頭・チャットのみの承認で H-2 / H-3 / H-4 を進めないこと
(GitHub の承認操作そのものが記録なので、承認は必ず GitHub 上で行う)。
