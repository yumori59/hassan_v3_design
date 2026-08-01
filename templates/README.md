# 実装リポジトリ用ハーネス雛形 (3 リポジトリ構成)

hassan_v3 で確定した設計を**実装するリポジトリ**を立ち上げるときの Claude Code ハーネス初期値。
リポジトリは **backend / frontend / infra の 3 分割** (productionization の Q-2=A の回答) を前提にしている。

```
templates/
  shared/.claude/skills/     3 リポで共通の skill (実装の思考ステップ・TDD)
  shared/.claude/rules/      3 リポで共通の運用ルール (作業ループ / issue 粒度 / モデル運用 / 人間承認点)
  backend-repo/              Go / gin / 4 層 + entity / gateway の計 6 パッケージ層 / sqlc / wire / Managed Agents
  frontend-repo/             Next.js on Vercel / OpenAPI 生成型
  infra-repo/                Terraform (AWS: ECS / RDS / VPC / IAM / Secrets)
```

`aidlc-planner` / `design-reviewer` / `poc-analyst` / `architecture-designer` と rules 01〜08 は
**設計リポ (hassan_v3) 側に残す**。実装リポには実装・レビューに必要なものだけを持っていく。
ただし `.claude/rules/feedback_review_patterns.md` は**各実装リポにもコピーする**
(BE/FE パターンは実装時のチェックリストとして機能する)。

## 立ち上げ手順 (各リポジトリ共通)

```bash
R=backend-repo   # または frontend-repo / infra-repo
cp -R templates/$R/.claude            <impl-repo>/
cp -R templates/$R/scripts            <impl-repo>/
cp -R templates/$R/.github            <impl-repo>/       # ci.yml / deploy.yml / ISSUE_TEMPLATE / pull_request_template.md
cp    templates/$R/CLAUDE.md.tmpl     <impl-repo>/CLAUDE.md
cp -R templates/shared/.claude/skills <impl-repo>/.claude/
cp -R templates/shared/.claude/rules  <impl-repo>/.claude/   # 作業ループ (01) / issue 粒度 (02) / モデル運用 (03) / 人間承認点 (04)
cp    .claude/rules/feedback_review_patterns.md <impl-repo>/.claude/rules/
```

1. `CLAUDE.md` の `<...>` プレースホルダを実際の構成 (モジュール名・コマンド・ディレクトリ) で埋める。
   **frontend リポは加えて `.eslintrc.json.tmpl` を `.eslintrc.json` にリネームし**、
   `import/no-restricted-paths` の zone と `NEXT_PUBLIC_` 許可リストを実ディレクトリ構成に合わせる
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
   **これが済むまで H-1 (マージ) 〜 H-4 (本番デプロイ) の承認は機構で担保されない**
5. hassan_v3 の `docs/design/` と `aidlc-docs/inception/<feature>/plan.md` を実装の入力にする。
   **設計書は `docs/design/README.md` (索引) から入る** — 18 ファイル・約 12,000 行あり、
   タスク種別ごとに読む範囲が決まっている (索引が「読まなくてよい節」も示す)

## リポジトリ間の依存 (立ち上げ順序)

```
infra-repo (Terraform で基盤を作る)
   ↓ 出力: RDS エンドポイント / ECS クラスタ名 / Secrets の ARN
backend-repo (ECS にデプロイ / OpenAPI 定義を公開)
   ↓ 出力: OpenAPI スキーマ
frontend-repo (型生成 / Vercel にデプロイ)
```

- **OpenAPI スキーマが backend → frontend の契約**。backend の IF 変更時はスキーマを再生成し、
  frontend 側で型を再生成する (CI で型ズレを検出する構成にする)
- **API 変更のリリース順序**: 後方互換な変更は backend 先行。破壊的変更は
  「backend で新旧併存 → frontend 切替 → 旧削除」の 3 段階 (D-3)
- **3 分割の代償**: 1 機能の変更が 3 リポに跨るとき、PR が 3 本になる。順序の担保は
  [shared/.claude/rules/02-issue-granularity.md](shared/.claude/rules/02-issue-granularity.md) §2
  (固定のマージ順序規約 + issue の「依存 issue (他リポ)」欄 + 人間による横断完了判定) で行う。
  設計側でも「どの変更がどのリポに閉じるか」を意識して増分を切る (`plan.md` のタスク分割)

## 注意

**この雛形は初期値であって SSOT ではない**。切り出した後は各実装リポ側が正になり、
雛形を直しても向こうには反映されない (pre-commit がこの旨を警告する)。
逆に、実装リポで得られた知見 (新しいバグパターン等) は
`.claude/rules/feedback_review_patterns.md` (設計リポ側) にも還流させる。
