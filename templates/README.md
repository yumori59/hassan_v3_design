# 実装リポジトリ用ハーネス雛形 (2 リポジトリ構成)

hassan_v3 で確定した設計を**実装するリポジトリ**を立ち上げるときの Claude Code ハーネス初期値。
リポジトリは **app モノレポ (`backend/` + `frontend/` + `api/`) + infra リポの 2 分割**
(productionization の Q-2 = **[Answer 2] の D**。**2026-08-03 に 3 分割から方針転換**。
決定と却下案は [../docs/design/architecture.md](../docs/design/architecture.md) §2 の D-I、
構成と 6 機構は同 §3.11) を前提にしている。

```
templates/
  shared/.claude/skills/     2 リポで共通の skill (実装の思考ステップ・TDD)
  shared/.claude/rules/      2 リポで共通の運用ルール (作業ループ / issue 粒度 / モデル運用 / 人間承認点 / 頻出バグパターン)
  app-monorepo/              **app モノレポ**
    CLAUDE.md.tmpl             ルート = 共通規約 + サブツリーへの索引 + モノレポ機構 MR-1〜MR-6
    .github/                   ci.yml (path filter + gate) / deploy-backend.yml / rollback-backend.yml /
                               e2e.yml / ISSUE_TEMPLATE (backend / frontend の 2 種) /
                               pull_request_template.md (1 本) / CODEOWNERS
    api/                       OpenAPI 定義の出力先 (BE→FE 契約の SSOT。生成物)
    backend/                   Go / gin / 4 層 + entity / gateway の計 6 パッケージ層 / sqlc / wire / Managed Agents
    frontend/                  Next.js on Vercel / OpenAPI 生成型
    scripts/hooks/pre-commit   staged パスでサブツリーに振り分ける
  infra-repo/                Terraform (AWS: ECS / RDS / VPC / IAM / Secrets)。**構成変更なし**
```

**サブツリー自己完結** ([../docs/design/architecture.md](../docs/design/architecture.md) §3.11.1):
`backend/.golangci.yml` · `backend/layering-scopes.yml` · `backend/scripts/` · `frontend/.eslintrc.json` を
**各サブツリーのルートに置き**、CI は `working-directory:` を切って実行する。
これにより depguard の L-1〜L-6・CI 検査 `D-2①`〜`D-2⑨` の対象パス・`frontend.md` §3.3 の lint zone が
**3 リポ構成のときと同じパス表記で有効**になる。**Go module はルートに置かず `backend/go.mod`** とする。

`aidlc-planner` / `design-reviewer` / `poc-analyst` / `architecture-designer` と rules 01〜08 は
**設計リポ (hassan_v3) 側に残す**。実装リポには実装・レビューに必要なものだけを持っていく。
ただし `.claude/rules/feedback_review_patterns.md` は**各実装リポにもコピーする**
(BE/FE パターンは実装時のチェックリストとして機能する)。**SSOT は設計リポ直下の
`.claude/rules/feedback_review_patterns.md`** — `templates/shared/.claude/rules/feedback_review_patterns.md`
はその同期コピー (冒頭に同期コピーである旨の注記を持つ)。**設計リポ側で本ファイルを更新したら、同じ差分で
`templates/shared/` 側にも `cp .claude/rules/feedback_review_patterns.md templates/shared/.claude/rules/`
を実行し追随させる**こと。**`make check-template-sync` (`make check` に含まれる) が乖離を機械検出する**
(忘れると shared 経由で立ち上げた実装リポが古いパターンのままになる)。

**`shared/.claude/rules/` の番号は 01〜04 のみ**。各実装リポ固有の rules (例: backend の
`05-architecture-coding-rules.md`) は **05 以降の番号を使い、`shared/` には置かない** —
`cp -R templates/shared/.claude/rules <impl-repo>/.claude/` は既存の `.claude/rules/` に**マージ**されるため
(同名ファイルは上書きされる)、`shared/` 側に `05` を追加すると各リポ固有ファイルを静かに壊す。

## 立ち上げ手順

### app モノレポ

```bash
cp -R templates/app-monorepo/.              <app-repo>/     # backend/ frontend/ api/ .github/ scripts/ CLAUDE.md.tmpl
mv    <app-repo>/CLAUDE.md.tmpl             <app-repo>/CLAUDE.md
mv    <app-repo>/backend/CLAUDE.md.tmpl     <app-repo>/backend/CLAUDE.md
mv    <app-repo>/frontend/CLAUDE.md.tmpl    <app-repo>/frontend/CLAUDE.md
mv    <app-repo>/frontend/.eslintrc.json.tmpl <app-repo>/frontend/.eslintrc.json
cp -R templates/shared/.claude/skills       <app-repo>/.claude/
cp -R templates/shared/.claude/rules        <app-repo>/.claude/
  # 作業ループ (01) / issue 粒度 (02) / モデル運用 (03) / 人間承認点 (04) / 頻出バグパターン (feedback_review_patterns.md)
```

**共通 rules / skills はリポジトリのルート `.claude/` に 1 部だけ置く** —
`backend/.claude/` と `frontend/.claude/` はサブツリー固有のもの (agents と backend の rule 05) だけを持つ。

### infra リポ

```bash
cp -R templates/infra-repo/.claude          <infra-repo>/
cp -R templates/infra-repo/scripts          <infra-repo>/
cp -R templates/infra-repo/.github          <infra-repo>/
cp    templates/infra-repo/CLAUDE.md.tmpl   <infra-repo>/CLAUDE.md
cp -R templates/shared/.claude/skills       <infra-repo>/.claude/
cp -R templates/shared/.claude/rules        <infra-repo>/.claude/
```

### 共通の手順

1. `CLAUDE.md` の `<...>` プレースホルダを実際の構成 (モジュール名・コマンド・ディレクトリ) で埋める。
   **app モノレポは 3 つ** (ルート / `backend/` / `frontend/`)。
   `frontend/.eslintrc.json` の `import/no-restricted-paths` の zone と `NEXT_PUBLIC_` 許可リストを
   実ディレクトリ構成に合わせる
   (依存規則 L-F1〜L-F6 とトークン強制の実体。設計は hassan_v3 `docs/design/frontend.md` §3.3 / §7)
2. `.claude/settings.json` を作る。**エージェントの自律範囲 (allow / deny) は
   [shared/.claude/rules/04-human-checkpoints.md](shared/.claude/rules/04-human-checkpoints.md) §3.2 の
   設定例が正** (feature ブランチへの commit / push / PR 作成は許可、force push・ブランチ削除・
   タグ操作・main 直接 push・DB 破壊操作・`--no-verify` は deny。
   infra リポでは加えて `terraform apply` / `terraform destroy` / state 操作を deny)
3. `ln -sf ../../scripts/hooks/pre-commit .git/hooks/pre-commit` でフックを導入する
4. **GitHub / Vercel の人手設定** (雛形で自動化できない) を
   [shared/.claude/rules/04-human-checkpoints.md](shared/.claude/rules/04-human-checkpoints.md) §4 の
   チェックリストどおり実施する — ブランチ保護 (必須レビュー + 必須 CI チェック + force push 禁止)・
   environment (dev / prod 系) の承認者・ラベル (`needs-human` / `blocked-by-design`) の作成。
   **これが済むまで H-1 (マージ) 〜 H-4 (本番デプロイ) の承認は機構で担保されない**。
   **app モノレポで特に落としやすい 3 点** (モノレポ化で新規に必要になった機構):
   - **必須ステータスチェックは `gate` の 1 本のみ** (MR-1)。個別ジョブを指定すると
     path filter による skip で **PR が永久に pending** になる。設定後に
     「backend のみ / frontend のみ / 両方」の 3 通りの PR で挙動を確認する
   - **Vercel の Root Directory = `frontend`** + **Ignored Build Step** (MR-2)。
     後者を入れないと backend だけの PR でも毎回 Preview ビルドが走る
   - **`.github/CODEOWNERS` の配置 + "Require review from Code Owners" の有効化** (MR-4)。
     リポジトリ境界が消えた分のレビュー担当の分離をこれで担保する
5. hassan_v3 の `docs/design/` と `aidlc-docs/inception/<feature>/plan.md` を実装の入力にする。
   **設計書は `docs/design/README.md` (索引) から入る** — **1 セッションで読み切れない規模**であり、
   タスク種別ごとに読む範囲が決まっている (索引が「読まなくてよい節」も示す)

## リポジトリ間の依存 (立ち上げ順序)

```
infra-repo (Terraform で基盤を作る)
   ↓ 出力: RDS エンドポイント / ECS クラスタ名 / Secrets の ARN
app-monorepo
   backend/ (ECS にデプロイ) → api/openapi.yaml → frontend/ (型生成 / Vercel にデプロイ)
   ※ BE→FE の契約はリポ内に閉じ、CI の contract ジョブ (MR-3) が同期を機械検証する
```

- **`api/openapi.yaml` が backend → frontend の契約 (SSOT)**。backend の IF 変更時は
  `make -C backend docs` で再生成し、frontend 側で型を再生成する。
  **どちらかを忘れた PR は CI の `contract` ジョブが落とす** (MR-3) — 3 リポ構成では
  「スキーマをどう渡すか」自体が未設計だったため、これがモノレポ化の主目的である
- **API 変更のリリース順序**: 後方互換な変更は **1 PR に同梱してよい** (本番反映の順序は
  ECS / Vercel Promote という別経路なので保たれる)。破壊的変更は
  「backend で新旧併存 → frontend 切替 → 旧削除」の 3 段階 (D-3) で、**3 段を別 PR に分ける** (MR-6)
- **モノレポ化の代償 (新しい落とし穴)**: **リポジトリ境界が担保していた順序が消える** —
  破壊的変更の 3 段を 1 PR に同梱できてしまう。担保は
  [shared/.claude/rules/02-issue-granularity.md](shared/.claude/rules/02-issue-granularity.md) §2.2.1 の規約 +
  **PR テンプレート §5 の段の宣言欄** + H-1 の確認観点 ⑧ の 3 点 (MR-6)
- **2 分割の代償**: 1 機能の変更が infra と app に跨るとき、PR が 2 本になる。順序の担保は
  同 §2 (固定のマージ順序規約 + issue の「依存 issue」欄 + 人間による横断完了判定) で行う。
  **infra の PR はマージだけでは効かない — `apply` 済みが app の着手条件**

## 注意

**この雛形は初期値であって SSOT ではない**。切り出した後は各実装リポ側が正になり、
雛形を直しても向こうには反映されない (pre-commit がこの旨を警告する)。
逆に、実装リポで得られた知見 (新しいバグパターン等) は
`.claude/rules/feedback_review_patterns.md` (設計リポ側) にも還流させる。
