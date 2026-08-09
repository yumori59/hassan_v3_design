# Rule 02: issue の粒度・完了条件 (DoD)・リポ跨ぎのマージ順序

**GitHub issue を何単位で切るか / いつ「完了」と言えるか / リポジトリ・サブツリーに跨る変更をどの順序でマージするか**
を定める。**2 リポジトリ共通** (app モノレポ / infra リポ。`templates/shared/` から各実装リポの `.claude/rules/` にコピーされる)。
リポ固有の値 (層の名前・検証コマンド・人間承認点の選択肢) は各リポの
`.github/ISSUE_TEMPLATE/task-<subtree>.yml` (infra リポは `task.yml`) と `.github/pull_request_template.md` が持つ。

作業の**順序と担当** (ステップ ID `S-1`〜`S-10`・ラベル `needs-human` / `blocked-by-design`・
ブランチ名の形) は [`01-construction-loop.md`](01-construction-loop.md) が定める。
本ルールはそれを前提に参照するだけで、**再定義しない**。次も他の SSOT が持つ:

| 事項 | SSOT |
|---|---|
| ループの順序・担当・Red/Green の裏取り・差し戻し上限 | [`01-construction-loop.md`](01-construction-loop.md) |
| リポごとの検証コマンド集合 | [`01-construction-loop.md`](01-construction-loop.md) §1.3 + 各リポの `CLAUDE.md` |
| 既定モデルと昇格 / 降格の基準 | rule `03-model-escalation.md` |
| 人間承認点の一覧と承認機構 (environment 承認・deny) | rule `04-human-checkpoints.md` |
| 何を作るか (AC の内容) | 設計リポ hassan_v3 の `aidlc-docs/inception/<feature>/requirements.md` |

> 本ルールが満たす設計リポ hassan_v3 の受入基準 (feature `construction-workflow`):
> **AC-2.1** §1 / **AC-2.2** §2 / **AC-2.4** §3 / **AC-2.3** §4 (欄の定義は §4、実体は各リポの
> `.github/ISSUE_TEMPLATE/task-<subtree>.yml`)。
> (ここでの AC-ID は設計プロセス側の受入基準であり、実装 issue が扱う AC-ID とは別物)

**本ルール内の `AC-4.2` / `AC-4.3` / `#123` 等はすべて記述例**。実際の値は issue ごとに異なる。

---

## 1. 1 issue の単位 (AC-2.1)

### 1.1 定義 (確定値)

> **1 issue = 1 PR = 「同じ層の縦串・同じ検証手段で閉じる AC 群」**

不変条件 (この 3 つを崩す切り方をしない):

| # | 不変条件 | 崩れたときに起きること |
|---|---|---|
| I-1 | **1 issue に対して PR は 1 本**。PR 内のコミット数は制約しない | issue が閉じない状態が長期化し、進捗が観測できない |
| I-2 | **1 issue = 1 レビューセッション** (`S-7` を 1 回で差分全体に対して行える大きさ) | 層間の不整合が見えないまま分割レビューになる |
| I-3 | **同じ AC-ID を同一リポ内の 2 つの issue に載せない** (リポが異なる場合のみ重複可。§2.1) | テスト名の AC-ID 照合 (`01` §2.3) で「どちらの issue がその AC を満たしたか」を機械判定できなくなる |

I-3 の帰結: **1 つの AC を同一リポ内で分割したくなったら、それは AC 自体が大きすぎる**。
実装側で勝手に割らず、`01` §4 の手順で設計リポへ「AC の分割」を差し戻す
(判定基準 `01` §4.1 の 4「AC がテストに翻訳できない」に該当させる)。

コミット / ブランチとの関係: ブランチ名の形は `01` の `S-3` が定める `<type>/<issue番号>-<slug>`。
`<type>` の値域は Conventional Commits の type を使う (`feat` / `fix` / `refactor` / `chore` / `docs`) —
`01` の形を補完する定義であり、矛盾しない。

### 1.2 分割手順 (この順に機械的に適用する)

1. **リポで割る (必須)** — AC の実現に backend / frontend / infra の複数リポが必要なら、
   **リポごとに別 issue**にする (§2)。1 issue が 2 リポに跨ることを許さない。
2. **縦串と検証手段でまとめる** — 同一リポ内で、
   ①触る層の集合が同じ (backend なら Controller → UseCase → Service → Repository の同じ縦串) かつ
   ②`01` §1.3 の検証コマンド集合が同じ AC を **1 issue にまとめる**。
3. **上限チェック (超えたら割る)** — 見積もりが次を超える場合は issue を割る:
   **生成物を除く変更ファイル数 15**、または **生成物・スナップショットを除く差分行数 (追加 + 削除) 800**。
   割らずに進める場合は、**割れない理由を issue 本文の「非スコープ / 備考」に書く**
   (例:「Repository を分けると `main` でコンパイルが通らない」)。理由の記載がない超過は `S-2` で差し戻す。
   > この 2 つの数値は**初期値**。実装リポで最初の 5 issue を回した実測でレビュー品質が落ちる境界が
   > 分かったら、実装リポ側のこのファイルを更新する (雛形は SSOT ではない)。
4. **下限チェック (小さすぎたら束ねる)** — **単独でマージしても `main` が壊れない**
   (検証ゲート全通過・既存の振る舞いを壊さない) ことを満たさない issue は、隣接する AC と束ねる。
   「次の issue をマージするまで `main` のテストが赤」になる切り方を禁止する。

### 1.3 分割の判断例 (記述例)

| 例 | 対象 | 判断 | 根拠 |
|---|---|---|---|
| **例 A: 3 AC で 1 issue** | 「テーマ一覧取得」「テーマ単体取得」「テーマ削除」の 3 AC。いずれも Controller → UseCase → Service → Repository の同じ縦串、検証は `go test ./...` + `golangci-lint run` | **1 issue** | 手順 2 (層の集合と検証手段が同一)。手順 3 の上限内 (1 テーブル・4 ファイル + テスト) |
| **例 B: 1 AC で 1 issue** | 「新規エンドポイント 1 本を追加する」1 AC。Controller・UseCase・Service・Repository・DB スキーマ・生成物・テストに及ぶ | **1 issue** | 縦串 1 本ぶんの差分で上限内。手順 4 も満たす (単独マージで `main` は壊れない) |
| **例 C: 1 AC で 3 issue (リポ / サブツリー跨ぎ)** | 「画面から企画書を生成できる」1 AC が、infra の Secrets 追加・backend の API・frontend の画面を要求する | **3 issue** (infra リポに 1 本 + app モノレポに backend / frontend で 1 本ずつ) | 手順 1。同じ AC-ID が複数 issue に載る (I-3 の例外)。順序は §2.2、依存は §2.3。**backend と frontend が後方互換なら 1 issue = 1 PR に統合してよい** (§2.1) |
| **例 D: 2 AC を 2 issue に割る** | 「LLM 呼び出しの usage 記録」と「コスト上限超過時の拒否」の 2 AC。前者は Service 層の全 LLM 経路 (差分行数 800 超)、後者は UseCase 層の分岐 | **2 issue** | 手順 3 (上限超過) + 手順 2 (触る層が違う)。前者を先にマージする (後者が前者の記録値に依存するため、依存 issue 欄に前者を書く) |

### 1.4 却下案

| 却下案 | 却下理由 |
|---|---|
| **1 issue = 1 AC-ID (厳密 1:1)** | 1 AC が 4 層 (Controller → UseCase → Service → Repository) + `entity/` / `gateway/` の計 6 パッケージ層 + テストに跨る場合に PR が細分化され、マージ順序の管理コストが差分レビューのコストを超える。単独マージで `main` が壊れる切り方 (手順 4 違反) を誘発する |
| **1 issue = 設計リポ `plan.md` の 1 タスク** | 設計リポのタスクは**設計成果物**の単位であり、実装の縦串と一致しない (1 設計タスクが複数リポ・複数サブツリーに散る) |
| **1 issue = 1 機能 (PR 複数)** | I-1 が崩れ、「閉じない issue」が生まれる。レビュー単位が PR ごとにばらつき、DoD (§3) の充足を issue 単位で判定できない |
| **1 issue = 1 コミット (squash 前提の細切れ)** | コミット粒度は実装者の作業単位であって、レビューと検証の単位ではない。I-2 と無関係な制約を実装に課す |

---

## 2. リポジトリ・サブツリーに跨る変更 (AC-2.2)

### 2.1 issue の構成 (確定値)

> **infra リポと app モノレポでは独立した issue を立てる。issue の親子関係を持たない。**
> **app モノレポ内 (backend / frontend) は、後方互換な変更なら 1 issue = 1 PR に統合してよい。**

**2 リポ構成 (app モノレポ + infra リポ) での読み替え** — 旧 3 リポ構成では FE/BE 跨ぎも
「別リポ = 別 issue」だったが、**モノレポでは 1 PR に収まるため統合できる**
(設計リポ hassan_v3 `docs/design/architecture.md` §3.11。D-I の方針転換 2026-08-03):

| 跨ぎの種類 | issue の切り方 | 順序の担保 |
|---|---|---|
| **infra ↔ app** | **必ず別 issue** (リポが違う) | §2.2 + 依存 issue 欄 + §2.4 の横断完了判定 |
| **backend ↔ frontend (後方互換)** | **1 issue = 1 PR に統合してよい** | **CI の `contract` ジョブ (MR-3) が契約の同期を機械検証する** — 人手の順序担保が不要になる |
| **backend ↔ frontend (破壊的 API 変更)** | **必ず 3 issue = 3 PR に分ける** (MR-6) | §2.2.1 + PR テンプレート §5 の段の宣言 |

**infra ↔ app は順序の SSOT を issue の構造では持たない**ため、次の 3 点で担保する。
3 点セットで初めて成立するので、どれも省略しない:

| # | 担保手段 | 場所 |
|---|---|---|
| ① | **マージ順序規約を固定で書く** | 本ルール §2.2 (リポの外に置かず、2 リポ共通ルールとして 1 部だけ持つ) |
| ② | **各 issue に「依存 issue」欄** を持たせ、`S-2` で依存先のマージ済みを確認する | 各リポの issue テンプレート (必須欄) + 本ルール §2.3 |
| ③ | **リポ横断の完了判定は人間が行う** (infra 跨ぎは `S-2` の着手前承認の対象) | 本ルール §2.4 |

**却下案: app モノレポに親 issue を置き、infra リポに子 issue を作る** — 順序の SSOT を 1 箇所に置ける利点は
あるが、GitHub は**リポジトリを跨ぐ親子関係を構造として持てない** (手書きの `#N` 参照になり、
どちらかの更新漏れを機械検出できない) ため、「SSOT がある」という見かけだけが残る。
ユーザー確定 (2026-07-29 / questions.md Q-2 = B)。
代償は「順序の担保が人手になる」ことで、上記 ①②③ がその補償である。

**却下案: モノレポ内も FE/BE で必ず issue を分ける** — 旧 3 リポ構成の運用をそのまま維持できるが、
**モノレポ化で得た利得 (契約の同期が 1 PR / 1 CI で検証できる) を自ら捨てることになる**。
分割を要求するのは破壊的 API 変更 (MR-6) に限る。

**却下案: 設計リポ (hassan_v3) に横断 issue を置く** — Design Freeze 後の設計リポが
実装の進捗ボードになる。設計リポは製品コードを持たない方針と噛み合わない。

### 2.2 マージ順序規約 (固定)

依存方向は **`infra → app`** (app 内は `backend → frontend`)
(出典: hassan_v3 `templates/README.md` の「リポジトリ間の依存 (立ち上げ順序)」節。
infra の出力 = RDS エンドポイント / ECS クラスタ名 / Secrets の ARN が app の入力、
backend の出力 = `api/openapi.yaml` が frontend の入力 — **後者はリポ内に閉じる**)。

| 変更の種類 | 順序 (左から順にマージ) | 次段の着手条件 (`S-2` で確認する) |
|---|---|---|
| **infra の出力値を backend が使う** | infra → app | infra の PR がマージ済み **かつ** 対象環境へ `apply` 済み (適用は人間。rule `04-human-checkpoints.md`)。出力値 (ARN / エンドポイント) が実際に取得できることを確認する |
| **後方互換な API 追加 / 変更** | **1 PR で同時マージ可** (backend → frontend の順序はデプロイ経路が別なので保たれる) | **CI の `contract` ジョブが `api/openapi.yaml` ↔ `frontend/src/generated` の同期を落とす** (MR-3)。別 issue に分けた場合は backend の PR がマージ済み **かつ** `api/openapi.yaml` が `main` に入っていること |
| **API の破壊的変更** | ①backend 新旧併存 → ②frontend 切替 → ③backend 旧削除。**①②③ を 1 PR に同梱しない** (MR-6) | §2.2.1 |
| **frontend のみ / infra のみに閉じる変更** | 制約なし | — |
| **DB スキーマ変更を伴う backend 変更** | スキーマ (後方互換) → コード | 同一 issue 内で完結させる。マイグレーション適用は人間承認点 (rule `04-human-checkpoints.md`) で、PR 本文に「適用が必要な変更」として明記する (§3.2。承認点は rule `04-human-checkpoints.md` の H-2) |

#### 2.2.1 API 破壊的変更の 3 段 (D-3)

| 段 | サブツリー | issue の内容 | 依存 issue 欄に書くもの | この段の完了判定 |
|---|---|---|---|---|
| ① | backend | 新 IF を追加し、**旧 IF を残す** (旧はドキュメント上 deprecated と明記)。`api/openapi.yaml` に両方が載る | なし (②の issue 番号を参考として書く) | 新旧両方の IF にテストがある。CI green |
| ② | frontend | 生成型を再生成し、**呼び出しを新 IF へ切り替える**。旧 IF への参照ゼロ | ①の issue 番号 | `npm run generate` の差分ゼロ・旧 IF の呼び出しが grep で 0 件 |
| ③ | backend | **旧 IF を削除**。`api/openapi.yaml` から旧定義が消える | ②の issue 番号 | ②のマージ後**かつ Vercel の production へ反映後**に着手。旧 IF のテストも削除 |

**3 段の issue は着手前に 3 本まとめて起票する**。②③ を後から起票する運用にすると、
③ の起票漏れで旧 IF が残り続け、「削除されない deprecated」が蓄積する。

**モノレポでは 3 段が同一リポジトリ内の 3 PR になる** — リポ境界が順序を担保しないため、
**PR テンプレート §5 の「API 破壊的変更の段」の宣言欄が唯一の検出経路**である (MR-6)。
宣言が無い / ①②③ を同梱した PR は H-1 で approve しない。
③ の着手条件は「②の PR がマージ済み **かつ** frontend の本番相当環境 (Vercel の production)
にデプロイ済み」— マージだけで着手すると、旧 IF を使っている稼働中の frontend が壊れる。

### 2.3 依存 issue 欄と `S-2` での確認手順

issue テンプレートの「依存 issue」欄には、**他リポへの依存はリポ名付きの参照**
(例: `<owner>/<infra-repo>#12`)、**同一リポ内 (サブツリー跨ぎ) の依存は `#N`** を書く。
依存が無い場合は **`なし` と明記する** (空欄を許さない)。

`S-2` (着手前判定) で OR が実行する確認:

```bash
# ① 依存 issue がクローズ済みか (他リポ)
gh issue view 12 --repo <owner>/<infra-repo> --json state,title,closedAt

# ①' 同一リポ内の依存 issue
gh issue view 123 --json state,title,closedAt

# ② 依存 issue の PR がマージされているか
gh pr list --search "123 in:body" --state merged --json number,mergedAt

# ③ 契約が main に入っているか (破壊的変更の ② / ③ の着手条件)
git fetch origin main && git show origin/main:api/openapi.yaml | grep -c '<新 IF のパス>'
```

判定と扱い:

| 確認結果 | `S-2` の扱い |
|---|---|
| 依存 issue がすべてクローズ済み、かつ §2.2 の「次段の着手条件」を満たす | 着手する |
| 依存 issue が未クローズ | **着手しない**。issue に「ループ位置: `S-2` で待機。依存 `<repo>#N` (または `#N`) が未マージ」をコメントして停止する (`01` §6.1 の形式)。**新しいラベルは定義せず**、`needs-human` / `blocked-by-design` のどちらも付けない (人間の判断ではなく前段の完了を待っている状態)。ただし同じ issue が H-5 (着手前の計画承認) の承認待ちでもある場合は、`04` §1.3 に従い `needs-human` を付ける |
| 依存 issue はクローズ済みだが着手条件が未達 (例: infra が `apply` されていない / Vercel 未デプロイ) | 同上。待機理由に「着手条件 <どれ> が未達」と書く |
| 依存関係が欄に書かれていない状態で `S-3` の調査中に発覚した | issue 本文の欄を更新してから `S-2` をやり直す (順序の記録を PR 説明だけに残さない) |

### 2.4 リポ横断の完了判定 (人間)

**infra 跨ぎの変更**、および**破壊的 API 変更の 3 段 (MR-6)** は、
**最終段の PR がマージされても「横断として完了」とは判定しない**。
**後方互換な FE/BE 跨ぎを 1 PR に統合した場合は本節の対象外** (`contract` ジョブが契約の整合を機械検証し、
1 PR のマージで横断が閉じるため)。
`S-10` (マージ) の後に、**人間**が次を確認して**最初の段の issue にコメントする**
(親 issue を持たないため、集約点を「先頭の issue」に固定する):

```markdown
## リポ横断の完了判定 (2026-07-29)

- 対象 AC-ID: AC-4.2
- 段と PR: infra <repo>#12 (merged, apply 済) / backend #123 (merged) / frontend #45 (merged, production 反映済)
- 確認したこと:
  - [ ] 全段の PR がマージ済み
  - [ ] 破壊的変更の場合、旧 IF の削除 (③) まで完了している
  - [ ] dev 環境で AC の経路が端から端まで動作する (確認手順と結果)
  - [ ] 本番へ出す判断: 出す / 保留 (理由)
- 判定: 完了 / 未完了 (残っているもの)
```

**この判定を機械化しない理由**: 横断の集約点を GitHub 上の構造 (親子 issue) として持たない選択
(§2.1) の裏返しであり、「3 本の issue がすべて閉じた」ことは
「AC が端から端まで満たされた」ことを意味しない (段の間で契約がずれても各 PR の CI は green になる)。
判定を人間に置くことがこの選択の前提条件である。
**モノレポ化で機械化できたのは「後方互換な FE/BE 跨ぎ」だけ** — infra の `apply` 状態と
破壊的変更の production 反映は CI から観測できないため、人間の判定が残る。

---

## 3. 完了条件 (Definition of Done) (AC-2.4)

DoD は 2 種類に分けて持つ。**機械検証項目 (V-x)** は誰が実行しても同じ結果になるもの、
**人間判断項目**は人間の承認記録が残ることが条件のもの。
**PR テンプレートのチェックリストは §3.1 の V-x ID をそのまま引用する** (§4.2)。

ID の名前空間 (2 リポ共通ルールをまたいで衝突させない):

| 接頭辞 | 意味 | 定義元 |
|---|---|---|
| `S-1`〜`S-10` | 作業ループのステップ | rule `01-construction-loop.md` §1.1 |
| `V-1`〜`V-10` | **DoD の機械検証項目** | **本ルール §3.1** |
| `M-1`〜`M-4` / `T-1`〜`T-3` | モデル判定の観点 / 実行中の昇格トリガー | rule `03-model-escalation.md` |
| `H-1`〜`H-5` | **人間の承認点** | rule `04-human-checkpoints.md` §1.1 (**本ルールは H-x を定義せず参照する**) |
| `MR-1`〜`MR-6` (**モノレポ機構**) | app モノレポ化で新規に必要になった機構 (**M**ono**R**epo) | 設計リポ hassan_v3 `docs/design/architecture.md` §3.11.2。**当初 `M-1`〜`M-6` としたが、`M-x` は既に 3 つの名前空間 (`03-model-escalation.md` のモデル判定 M-1〜M-4 / `llm-migration.md` の移送段 M-0〜M-9 / `data-model.md` の M-1〜M-20) に使われていたため 2026-08-04 に `MR-x` へ改名した** (design-reviewer 指摘。`make check-monorepo-ci` が件数と連番を機械照合する) |

### 3.1 機械検証項目 (V-x)

「検証手段」の列のコマンドは、**サブツリー / リポごとの実体を `01` §1.3 と各 `CLAUDE.md` が持つ**
(ここに複製しない)。

| # | 項目 | 検証手段 | 実行者 | 未充足時 |
|---|---|---|---|---|
| **V-1** | **CI の全ジョブが green** | `.github/workflows/ci.yml`。**app モノレポでは `gate` ジョブ 1 本を必須チェックに設定する** (個別ジョブは path filter で skip され得る。モノレポ機構の MR-1) | CI | マージ不可 (`01` §7.2) |
| **V-2** | **対象 AC-ID すべてがテスト名に存在する** | `01` §2.3 の照合コマンド (backend: `grep -rE "func Test.*AC4_2"` / frontend: `grep -rn "AC-4.2" --include='*.test.ts*'`)。**infra は `modules/` を変更した場合に `terraform test` のテスト名で照合し、`envs/` のみの変更では V-7 が代替**する (`01` §2.4) | OR (`S-6`) | `MISS` が 1 件でもあれば `S-4` 未完了として差し戻し |
| **V-3** | **対象 AC のテストが実行され PASS する** | `go test ./... -run 'AC4_2' -v` / `npx vitest run -t 'AC-4.2'` / infra は `terraform test` (`no tests to run` ・0 件マッチは未充足) | OR (`S-6`) | `S-4`/`S-5` に戻る |
| **V-4** | **触ったサブツリー / リポの検証ゲート全コマンドが通る** | `01` §1.3 の該当行 (backend: build / vet / test / lint、frontend: tsc / test / build / lint、infra: fmt / validate / tflint / plan)。**両サブツリーを触った PR は両方の行を実行する** | OR (`S-6`) | `S-9` に進まない |
| **V-5** | **生成物の再生成漏れがゼロ** | backend: `make -C backend sqlc wire` + **`scripts/check-regen.sh backend`** / frontend: `npm run generate` + **`scripts/check-regen.sh frontend/src/generated`** / infra: `terraform fmt -check -recursive`。⚠️ **裸の `git diff --exit-code` を使わない** — pathspec が無いと他サブツリーを拾い、かつ**未追跡ファイル (新規生成物) を見ないため追加漏れが素通りする** | OR (`S-6`) + CI | 同上 |
| **V-6** | **契約ドキュメントが同期している** | **CI の `contract` ジョブ** (`make -C backend docs` → **`scripts/check-regen.sh api/openapi.yaml`** → `npm run generate` → **`scripts/check-regen.sh frontend/src/generated`**。モノレポ機構の MR-3)。**backend だけ / frontend だけの PR でも走る** | CI | マージ不可。破壊的変更なら PR テンプレート §5 で段を宣言する (§2.2.1 / MR-6) |
| **V-7** | **infra: `plan` の差分が事前宣言と一致する** | `terraform plan` の出力を issue の事前宣言 (`01` §2.4) と突き合わせ、`destroy` / `replace` の有無を PR に貼る | OR (`S-6`) | 差異の理由を説明できるまで PR を ready にしない |
| **V-8** | **PR が対象 issue を閉じる** | PR 本文に `Closes #<issue番号>` があり、GitHub が issue とリンクしていること | OR (`S-9`) | issue が開いたまま残る (`S-10` で検出) |
| **V-9** | **ブランチ名が規約に沿う** | `<type>/<issue番号>-<slug>` (`01` の `S-3`。`<type>` の値域は §1.1) | OR (`S-3`) | ブランチを切り直す (退避コミットは cherry-pick) |
| **V-10** | **リポ内ドキュメントの更新** — 新コマンド追加時の該当サブツリーの `CLAUDE.md` コマンド表、新バグパターン発見時の `.claude/rules/feedback_review_patterns.md`、infra の範囲外リソースのコメント | `git diff --stat` に該当ファイルが含まれるかを OR が確認 (該当なしの場合は PR に「該当なし」と書く) | OR (`S-9`) | レビュー (`S-7`) の指摘対象 |

V-10 は「差分の有無」だけが機械で見え、**内容の妥当性は `S-7` のレビューが見る**
(この境界を曖昧にしない: doc の更新漏れを CI で検出する仕組みは持たない)。

### 3.2 人間判断項目 (承認点の ID は rule `04-human-checkpoints.md` の H-x)

**承認点の一覧・確認観点・承認機構 (GitHub environment 承認・deny 設定) の SSOT は
rule `04-human-checkpoints.md`**。本ルールは **H-x を定義せず参照**し、
**DoD としての位置** (issue をクローズする前に必要か / マージ後か) のみを定める。

| 承認点 | 内容 | ループ位置 | **issue クローズの条件か** |
|---|---|---|---|
| **H-5** (04) | **着手前の計画承認** (条件付き。該当条件は `04` §1.2 が定める: ①新規ドメイン ②設計書に無いパターン ③**infra 跨ぎ**) | `S-2` | **該当 issue では必須** |
| **H-1** (04) | **PR のマージ** (レビュー重大ゼロと DoD 充足を人間が確認して approve + マージ) | `S-10` | **必須** |
| — (本ルール §2.4) | **リポ横断の完了判定** — **infra 跨ぎ**と**破壊的 API 変更の 3 段**のみ (後方互換な FE/BE 跨ぎは対象外)。`04` の承認点には含まれない (承認ではなく完了判定であり、止める機構を持たない) | `S-10` の後 | **該当時は必須** (先頭 issue のクローズ条件) |
| **H-2** (04) | **DB マイグレーションの適用** | `S-10` 後 | **条件にしない** (下記) |
| **H-3** (04) | **Managed Agent の再発行** (system prompt / custom tool schema を変更した場合) | `S-10` 後 | **条件にしない** |
| **H-4** (04) | **本番環境への適用 (デプロイ)** — backend (ECS) / frontend (Vercel) / infra (`terraform apply`) | `S-10` と独立 | **条件にしない** |

infra の dev への `terraform apply` は `04` で番号付き承認点になっていないが、
**人間のみが実行する操作**である (`04` §1.1 の注記 + §3.1)。DoD 上の扱いは H-2〜H-4 と同じ
(issue クローズの条件にせず、PR 本文の「適用が必要な変更」欄に明記する)。

**H-2 / H-3 / H-4 を issue クローズの条件にしない理由 (決定)**: 適用・再発行・本番デプロイは
複数 issue の変更をまとめて 1 回行うことがあり、issue 単位の 1:1 対応にならない。
issue を開いたまま待たせると、実装が終わった issue が本番リリースまで滞留し、
「未完了の issue」と「リリース待ちの issue」を区別できなくなる。

**代わりに DoD として要求すること (機械で見える形にする)**:
H-2 / H-3 / H-4 (と infra の dev `apply`) に該当する変更を含む PR は、
**PR 本文の「適用が必要な変更」欄に該当項目を明記する** (該当なしの場合も「該当なし」と書く)。
`S-2` でも該当を宣言する (`01` §7.3)。これを書かずにマージすると
「コードだけデプロイして Agent 再発行を忘れる」障害 (D-6 / BE-8 / BE-10) が起きる。

**却下案: H-2〜H-4 の完了までを issue のクローズ条件にする** — 適用の完了が issue に紐づくため
追跡性は上がるが、上記のとおり issue が長期滞留し、進捗ボードとしての意味が失われる。
リリース状況の追跡は issue ではなく `04-human-checkpoints.md` の承認記録 (environment の承認履歴) で行う。

**却下案: 本ルール側で人間判断項目に独自の ID を振る** — DoD の表として自己完結するが、
`04` の H-x と番号が二重化し、issue コメント・PR 本文の「H-3」がどちらの定義か判別できなくなる。
承認点の ID は `04` を唯一の定義元とする。

### 3.3 DoD を満たさない PR の扱い

| 状況 | 扱い |
|---|---|
| V-x のいずれかが未充足 | **PR を ready にしない** (draft のまま)。`S-6` に戻る |
| `S-7` のレビューに重大が残っている | ready にしない (`01` §3。2 巡で収束しなければ `needs-human` を付けて停止) |
| H-5 (着手前の計画承認) が必要なのに承認が無い | `S-3` 以降に進まない (`04` §1.2 の該当条件で判定) |
| V-10 の「該当なし」判断が誤っていた (レビューで指摘) | `S-8` で反映してから `S-6` をやり直す |

---

## 4. issue / PR テンプレートとの対応 (AC-2.3)

### 4.1 issue テンプレートの必須欄 (5 つに限定する)

**app モノレポは `.github/ISSUE_TEMPLATE/task-backend.yml` と `task-frontend.yml` の 2 本**
(issue chooser に両方が並ぶ)、**infra リポは `task.yml` 1 本**を **GitHub issue フォーム** (YAML) として置く。
**必須 5 欄はどのテンプレートでも同一**にする (テンプレートを増やしても欄を増減させない)。
Markdown テンプレートではなく YAML フォームを選ぶ理由: **`validations: required: true` で
未記入の起票を GitHub がブロックできる**ため。Markdown テンプレートは見出しを消して起票できる。

| # | 欄 | 型 | 用途 (どのステップが読むか) |
|---|---|---|---|
| 1 | **対象 AC-ID** | 単一行 (必須) | `S-2` の対象確定 / `S-4` のテスト名 / V-2・V-3 の照合。feature 名 + AC-ID を書く (例: `productionization / AC-4.2, AC-4.3`) |
| 2 | **影響する層** | 複数選択 (必須) | `S-3` の計画・`S-7` のレビュー範囲。backend/frontend は層、**infra は `modules/` / `envs/` の実態に読み替える** (§4.3)。テンプレートがサブツリー別なので選択肢は混ざらない |
| 3 | **実行すべき検証コマンド** | 複数行 (必須) | `S-6` で OR が実行するコマンド。サブツリー既定値をテンプレートに埋め込み、issue 固有の追加分を足す。**契約に触る issue は `contract` ジョブ相当のコマンド (`01` §1.3 の「契約」行) を必ず含める** |
| 4 | **人間チェックポイントの該当有無** | 複数選択 (必須) | `S-2` の宣言・§3.2 (`04` の H-5 / H-2 / H-3 / H-4)。「該当なし」を選択肢に持つ (空欄を許さない) |
| 5 | **依存 issue** | 複数行 (必須) | `S-2` の依存確認 (§2.3)。他リポはリポ名付き、同一リポ内は `#N`。無い場合は `なし` と書く |

**任意欄** (未記入でも起票できる。issue を軽く保つため必須にしない):
背景 / 目的、設計書の該当箇所 (hassan_v3 の `docs/design/<file>.md` §節)、非スコープ・備考
(§1.2 手順 3 の超過理由をここに書く)、想定モデル (rule `03-model-escalation.md` の判定結果)。

**`S-1` (issue 受領) の受領判定**: 必須 5 欄がすべて埋まっていること。
加えて **infra で「影響する対象」に `envs/` を含む issue は、任意欄「期待する plan 差分」が
埋まっていること** (空なら S-1 で差し戻す — V-7 の突合基準であり、無いと infra の Red 代替
(`01-construction-loop.md` §2.4) が消える)。
`gh issue create --body` や API 経由の起票では**フォームの `required` が効かない**ため、
OR は `S-1` で 5 欄の存在を自分で確認する。1 つでも欠けていれば起票者へ差し戻す (`01` の `S-1`)。

### 4.2 PR テンプレートと DoD の同期規約

各リポの `.github/pull_request_template.md` は次を持つ。
**app モノレポは PR テンプレートを 1 本だけ持つ** (GitHub の既定テンプレートは 1 ファイルのみ) —
サブツリー別の項目は**両方を載せ、該当しない側をブロックごと削除する**運用にする (§0 の「対象サブツリー」欄)。

1. **DoD チェックリスト** — §3.1 の **V-x ID をそのまま引用**する (チェック項目の文言は要約でよいが、
   **ID を落とさない**)。リポに存在しない項目はテンプレートに載せない —
   **V-7 は infra リポのみ**、**V-6 (契約ドキュメント) は app モノレポのみ**
2. **検証出力の貼り付け欄** — Red / Green のテスト出力 (`01` §2.1 の受理条件 3 点) と
   `S-6` の検証コマンド出力。infra は `plan` の要約と事前宣言との突合結果 (V-7)
3. **レビュー結果の宣言欄** — `S-7` を別セッションで実施したこと・**重大ゼロ**・巡目 (`n / 2`)・
   中軽微の扱い (この PR で修正 / 別 issue に切った番号)
4. **適用が必要な変更** — §3.2 の H-2 / H-3 / H-4 (infra は dev の `apply` も) の該当 (該当なしも明記)
5. **`Closes #<issue番号>`** (V-8)
6. **H-5 (着手前の計画承認) の記録欄** — 該当有無と、該当時は**承認コメントの URL**。
   URL の無い該当 PR は H-1 で approve されない (rule `04-human-checkpoints.md` §2.5 の検出材料)
7. **API 破壊的変更の段の宣言欄** (app モノレポのみ。**モノレポ機構の MR-6**) — 「該当なし」または
   ①新旧併存 / ②FE 切替 / ③旧削除 のどれかと、前段の PR 番号。
   **①②③ を同梱した PR / 宣言の無い PR は H-1 で approve しない** —
   3 リポ構成ではリポ境界が担保していた順序が、モノレポでは**この欄だけが検出経路**になる

**同期の責務**: §3.1 の表を変更したら、**2 リポの `pull_request_template.md` を同じコミットで更新する**。
逆に PR テンプレートだけに DoD 項目を足さない (項目の SSOT は §3.1)。

### 4.3 サブツリー / リポごとの読み替え (テンプレートに埋める既定値)

共通ルールは 1 部だけ持ち、**違うのは次の 3 点のみ**。この 3 点は各 issue テンプレートに既定値として書く:

| テンプレート | 「影響する層」の選択肢 | 「検証コマンド」の既定値 | 「人間チェックポイント」の選択肢 |
|---|---|---|---|
| `task-backend.yml` (app) | Controller / UseCase / Service / entity / Repository / gateway / DB スキーマ (マイグレーション) / Managed Agent (prompt・tool schema) / 生成物 (sqlc・wire) / **契約 (`api/openapi.yaml`)** | `01` §1.3 の backend 行 + 契約行 | 該当なし / 着手前の計画承認 / DB マイグレーション適用 / Managed Agent 再発行 / 本番デプロイ |
| `task-frontend.yml` (app) | 画面 (app / pages) / コンポーネント / 純粋ロジック (lib) / API クライアント (生成型) / デザイントークン / E2E | `01` §1.3 の frontend 行 + 契約行 | 該当なし / 着手前の計画承認 / 本番デプロイ (Vercel production) |
| `task.yml` (infra リポ) | `modules/` (network・ecs・rds・iam・observability) / `envs/dev` / `envs/prod` / IAM ポリシー / Secrets・SSM / リモート state・backend 設定 | `01` §1.3 の infra 行 | 該当なし / 着手前の計画承認 / `terraform apply` (dev) / `terraform apply` (prod) |

infra の「影響する層」は backend の 6 パッケージ層 (4 層 + `entity/` / `gateway/`) に対応する概念が無いため、
**`modules/` と `envs/` の区分 + 破壊的差分を生みやすい対象 (IAM / Secrets / state)** に読み替える。
`envs/prod` を選択した issue は `S-2` で必ず人間承認の対象になる (`04-human-checkpoints.md`)。
