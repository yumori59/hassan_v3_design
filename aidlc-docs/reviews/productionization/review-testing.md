# レビュー結果: テスト戦略 (docs/design/testing.md)

- レビュー日: 2026-07-30 / レビュアー: design-reviewer (opus) / 別セッション (起草者ではない)
- **レビュー対象 (これのみ)**: [docs/design/testing.md](../../../docs/design/testing.md)
- **付随して確認した雛形 (編集していない)**:
  - [templates/app-monorepo/.github/workflows/ci.yml](../../../templates/app-monorepo/.github/workflows/ci.yml) (スキーマ適用ステップ)
  - [templates/app-monorepo/.github/workflows/e2e.yml](../../../templates/app-monorepo/.github/workflows/e2e.yml) (新規)
  - [templates/app-monorepo/.github/workflows/deploy-backend.yml](../../../templates/app-monorepo/.github/workflows/deploy-backend.yml):466〜496 (`repository_dispatch` 送信)
- **整合確認のため参照**: [templates/shared/.claude/rules/01-construction-loop.md](../../../templates/shared/.claude/rules/01-construction-loop.md) §7 /
  [templates/shared/.claude/rules/02-issue-granularity.md](../../../templates/shared/.claude/rules/02-issue-granularity.md) §3.1 /
  [docs/design/llm-migration.md](../../../docs/design/llm-migration.md) §8 / [docs/design/observability.md](../../../docs/design/observability.md) §4.3 /
  [docs/design/operations.md](../../../docs/design/operations.md) §4.1 / [docs/design/auth.md](../../../docs/design/auth.md) §6.4〜§6.6
- **対象外 (別レビュー)**: `docs/design/data-model.md` / `docs/design/frontend.md`

## サマリ

- **重大 4 件 / 中 7 件 / 軽微 4 件**
- **Freeze 可否: 不可**。重大 4 件のうち 3 件は雛形 (`e2e.yml`) の是正、1 件は testing.md 自身の
  事実記述の更新で閉じる。設計判断そのもの (§2 の T-A〜T-O) の骨格は妥当で、書き換えは要らない。
- 実行した検証: `make check` (doc-lint エラー 0 / 警告 48 (うち testing.md は未回答 `[Answer]` 5 件 = §13.1 の T-Q1〜T-Q5) /
  traceability 2 feature 未カバー 0 / workflow-shell 45 ブロック エラー 0)、
  抜き取り照合 **8 件** (7 件一致 / 1 件不一致)、`e2e.yml` のスキップ検出ステップの実挙動再現 1 件

## 実行した検証の出力

```
[doc-lint] 対象 83 ファイル / エラー 0 件 / 警告 48 件
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 46/46 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
[workflow-shell] 検査 45 ブロック / エラー 0 件
```

testing.md 由来の警告は §13.1 の未回答 `[Answer]` 5 件のみ (:606 / :616 / :625 / :634 / :649)。
いずれも「暫定既定を明記した上でユーザー判断待ち」であり、DR-5 (曖昧語による丸投げ) には当たらない。

### 抜き取り照合 (8 件で打ち切り。オーケストレーター既済の 6 件は再照合せず)

| # | 主張 | 照合結果 |
|---|---|---|
| 1 | T-F6: v2 CI は PR (base=main) のみ / **lint ジョブが無い** / `fail_ci_if_error: false` | **一致** (`hassan-v2-backend/.github/workflows/test.yml`: `jobs:` は `test` の 1 本のみ、lint 系ジョブ・golangci の記述なし。`fail_ci_if_error: false` を確認) |
| 2 | T-F1 / T-F3 / T-F5: テスト 114 件 / `repository/` 0 件 / `controller/` は 3 件 | **一致** (114 / 0 / `custom_validator_test.go`・`dto/idea_test.go`・`dto/idea_board_test.go`) |
| 3 | §6.2・§13.4: PoC の tool は 9 本 (`claude_managed_agents/cmd/devui/conversation.go:774`〜`:790`) | **一致** (`toolLabel` の case が 9 件: list_assets / load_asset / research_market / deep_dive / generate_ideas / generate_plan / record_rejection / set_theme_name / match_functions) |
| 4 | T-F17: BE-12 はテストの手書き合成 JSON で隠れた (`conversation_plan_grounding_test.go:32`・`:98`・`:121`) | **一致** (:32 に `{"finding":"...","notes":"要確認"}` を直書き。:98・:121 も同型) |
| 5 | T-F14: PoC の Go テスト 126 / frontend 157 | **一致** (`node_modules` 除外で 157) |
| 6 | T-F15: PoC の CI は PostgreSQL を起動しない | **一致** (`claude_managed_agents/.github/workflows/ci.yml` に `go test ./...` + 「PostgreSQL サービスは起動しない」の明記) |
| 7 | T-O: 雛形の pre-commit が既に `npx vitest related --run` を呼ぶ (`templates/app-monorepo/scripts/hooks/pre-commit`:34) | **一致** |
| 8 | §8.2 / §13.3-1: 雛形 `ci.yml` に**マイグレーション適用ステップが無い** (:51〜54) | **不一致** — ci.yml:55〜69 に「スキーマ適用 (統合段の前提)」ステップが実在する (未設定なら `exit 1`)。**重大 4 参照** |

**照合していない範囲 (正直に列挙)**: T-F11 / T-F12 / T-F13 (v2 の Playwright 構成・固定 MFA・`test.skip`) と
「v2 に DB を伴うテスト 0 件」「v2 frontend に CI と単体テスト基盤が無い」「PoC の CI が PostgreSQL を起動しない」の
一部は**オーケストレーターが既に 6 件照合し全件一致を確認済み**との指示により再照合していない。
T-F4 / T-F7 / T-F8 と llm-migration §8 の内容妥当性は未照合 (存在は確認)。

---

## 重大 (Must Fix)

### 重大 1. `e2e.yml` が E2E の資格情報を GitHub environment secret に直置きし、§7.3 の決定と operations.md §4.1 の限定列挙に違反している

- 該当: [templates/app-monorepo/.github/workflows/e2e.yml](../../../templates/app-monorepo/.github/workflows/e2e.yml):39〜41・:71〜78 /
  [docs/design/testing.md](../../../docs/design/testing.md):358 (§7.3 の「資格情報の所在」行)
- **事実**: testing.md §7.3 は「**dev の Secrets Manager**。E2E ジョブが `dev` environment の OIDC ロールで取得する
  (operations.md §4.1 の経路に合わせる。**GitHub secret に置かない**)」と決定している。
  一方 e2e.yml は `E2E_ACCOUNT_EMAIL` / `E2E_ACCOUNT_PASSWORD` / `E2E_TOTP_SECRET` を
  `${{ secrets.* }}` (GitHub environment secret) から渡す。**同じファイルの :17 が
  「所在は operations.md §4.1 が SSOT」と書いており、自身のコメントとも矛盾している**。
  operations.md §4.1:152〜157 の限定列挙は **IAM ロール ARN と非秘密の識別子のみ**で、パスワード・TOTP は入らない。
- **なぜ本番で問題になるか**: (a) TOTP シークレットは MFA の第 2 要素そのもので、
  GitHub 側に置くとローテーション経路が二重化する (operations.md §4.1:166〜170 が BE-2 の再演として却下した形)。
  (b) 実装リポは**雛形をコピーして起動する**ため、設計が却下した経路が既定になる。
  (c) e2e.yml の `permissions` は `contents: read` のみで **`id-token: write` が無く、
  §7.3 が決めた OIDC 経路が原理的に実行できない**。
- **修正案**: e2e.yml に `permissions: { contents: read, id-token: write }` を追加し、
  `aws-actions/configure-aws-credentials` + `secretsmanager:GetSecretValue` で取得するステップに置き換える
  (environment secret に残すのは dev の**ロール ARN とシークレット名**のみ)。
  併せて testing.md §13.3 に「e2e.yml の資格情報取得経路の是正」を 1 行追加する
  (現在の §13.3-5 は operations.md 側への追記要求のみで、雛形側の違反に触れていない)。

### 重大 2. `e2e.yml` のスキップ検出ステップが機構として成立していない (常に失敗する / 形式不一致 / レポート欠損で緑)

- 該当: [templates/app-monorepo/.github/workflows/e2e.yml](../../../templates/app-monorepo/.github/workflows/e2e.yml):83〜100 /
  [docs/design/testing.md](../../../docs/design/testing.md):449〜452 (§8.4 の self-skip 禁止)
- **事実 (再現済み)**: 当該ステップは `set -euo pipefail` の下で
  `SKIPPED=$(grep -o '"status":"skipped"' "$REPORT" | wc -l | tr -d ' ')` を実行する。
  **`grep` は無マッチで exit 1 を返し、`pipefail` によりコマンド置換が失敗、`set -e` でステップが落ちる**。
  実際に同じスクリプトを実行して確認した (パターン一致がある場合のみ `echo` に到達し、
  無マッチでは `exit=1` で無言終了)。つまり**スキップ 0 件の正常系で E2E ジョブが赤になる**。
  さらに Playwright の JSON reporter は 2 スペース整形で出力するため実際のキーは
  `"status": "skipped"` (空白あり) であり、空白なしのリテラルは**スキップが在っても一致しない**。
  加えて :89〜92 はレポートが無いとき `::warning` + `exit 0` で**緑**にする。
- **なぜ本番で問題になるか**: T-F13 (v2 の E2E が `test.skip` で緑になる) を潰すための唯一の機構が、
  ①常に赤 → 「E2E は赤が普通」という運用に退行し §7.4 の緩和策 2 (H-4 の承認材料) が無意味になる、
  ②レポート未設定なら緑 → **testing.md が最も強く禁じた「緑の見せかけ」をこの検査自身が作る**。
- **修正案**: `--reporter=json` の出力先を `PLAYWRIGHT_JSON_OUTPUT_NAME` で固定し、
  `jq '[.. | objects | select(.status? == "skipped")] | length'` のように**構造で数える**。
  `grep | wc -l` を使うなら `|| true` で無マッチを 0 に落とす。
  **レポート欠損は `exit 1`** にする (レポートが無い = 検査できていない = 担保なし)。

### 重大 3. 統合段 (I) が「DB 未接続なら skip ではなく fail する」ことを設計として決めていない (BE-5 の再演余地)

- 該当: [docs/design/testing.md](../../../docs/design/testing.md):421〜434 (§8.2) / :466〜476 (§9.1) / :75〜76 (§1.4-4)
- **事実**: §1.4-4 は「PoC の CI は DB を持たない前提 (T-F15 / T-F16)。**v3 はこの前提を持ち込まない**」と書くが、
  I 段のテストが `DATABASE_URL` 未設定のときどう振る舞うべきかの規約が本書にない。
  §9.1 は「`go test ./...` が U と I の両方を含む (`services: postgres` があるため)」とだけ述べる。
  雛形 ci.yml は**スキーマ適用ステップ側**は未設定で落ちるようにしてあるが (:61〜66)、
  テスト側には同等のガードが無い。
- **なぜ本番で問題になるか**: Go の慣習は「`DATABASE_URL` が空なら `t.Skip`」であり、
  実装者は高確率でそれを書く。すると `DATABASE_URL` の env 落ち・ジョブ分割・ローカル実行で
  **I 段が 0 件実行のまま緑**になり、§6.1 / §6.3 の越境テスト (A-4 / A-6 の実効性の全て) が消える。
  これは BE-5 (DB 未接続フォールバック) が形を変えて戻ってきた状態で、本書の中心的主張が無効化される。
- **修正案**: §8.2 に 1 行追加する — 「**I 段のテストは `DATABASE_URL` 未設定を `t.Skip` にせず
  `t.Fatal` にする**。スキップ可能にしてよいのはローカルの明示フラグ (`-short`) のみとし、
  CI は `-short` を付けない」。併せて §10 の存在検査に
  「I 段のヘルパが skip 経路を持たないこと」または「CI で I 段のテスト実行件数が 0 でないこと」を追加する
  (0 件実行の検出は grep より件数で見るのが確実)。

### 重大 4. 雛形の現状に関する断定が誤っており、同一文書内でも矛盾している (DR-1)

- 該当: [docs/design/testing.md](../../../docs/design/testing.md):432〜434 (§8.2) / :665 (§13.3-1) / :666 (§13.3-2) /
  :273 (§6.1 の 3) / :668 (§13.3-4)
- **事実**:
  1. §8.2:432〜434 と §13.3-1 は「ci.yml:51〜54 は postgres を起動して `DATABASE_URL` を渡すだけで、
     **マイグレーションを適用するステップが無い**」と断定するが、**ci.yml:55〜69 に「スキーマ適用 (統合段の前提)」
     ステップが実在する** (しかも未設定なら `exit 1` する形で、本書 §8.2 の要求を満たしている)。
     `:51〜54` は現在その適用ステップのコメント行を指す。
  2. §13.3-2 は「`templates/app-monorepo/.github/workflows/` に **`e2e.yml` が無い**」と断定するが実在する。
     **同じ文書の §7.4:380〜390 は e2e.yml の存在を前提に `repository_dispatch` の送信側の話を書いている** —
     文書内で矛盾している。
  3. 行番号の出典ずれ: §6.1 の 3 は `check-route-auth.sh` を「ci.yml:77〜85」と引くが実際は **:97〜105**、
     §13.3-4 は `check-owner-scope.sh` を「:87〜96」と引くが実際は **:107〜116** (スキーマ適用ステップ挿入分のずれ)。
     T-B の「ci.yml:17〜26」(`services: postgres`) は一致。
- **なぜ本番で問題になるか**: §13.3 は**実装リポへ渡す是正バックログそのもの**であり、
  既に完了した項目が「未対応」として残ると、(a) 二重作業、(b) 「§13.3 は当てにならない」という扱いになって
  **本当に未対応の 3〜7 (特に 4: 越境テストの網羅検査) が落ちる**。
  行番号ずれは `make doc-lint` が検出しない種類の誤り (rule 05 の「見ないもの」) で、
  実装者は照合せず転記する。
- **修正案**: §8.2 の「現状の雛形はこれを満たしていない」段落を「雛形は適用ステップを持つ (ci.yml:55〜69)。
  方式 (D-4) 未確定のため `SCHEMA_APPLY_TARGET` が空で、その間は CI が落ちる形になっている」に書き換え、
  §13.3-1・2 を **「是正済み (2026-07-30)」**へ移す (operations.md §9 が採っている「是正済み」表と同じ形)。
  行番号 3 件を実測値に更新する。

---

## 中 (Should Fix)

### 中 1. 「必須テストの存在検査 5 種」のうち #4 / #5 に実装先が無く、§11 の AC-5.2 の主張が 5 分の 3 しか機構化されていない

- 該当: [docs/design/testing.md](../../../docs/design/testing.md):513〜519 (§10) / :531 (§11 の AC-5.2 行)
- #1 は既存 V-2 ([02-issue-granularity.md](../../../templates/shared/.claude/rules/02-issue-granularity.md) §3.1 で実在確認)、
  #2 / #3 は §13.3-4 で `check-owner-scope.sh` への追加が要求されている (機構あり)。
  一方 **#4 は「llm-migration §8.3 の Q-3 (機械検査項目として既に定義済み)」を根拠にするが、
  llm-migration.md:552 の Q-3 は「レンジ表記を含む入力を必ずテストケースに含める」という**規約**であり、
  ケースの**欠落を検出する検査ではない**。#5 (各 LLM 経路に F-1〜F-5 のケースが 1 件以上) は
  「`feature` 識別子とテスト名を突き合わせる」とだけ書かれ、スクリプト名も 是正要求 も無い。
- §11 は「『テストが通ること』だけでなく『必要なテストが在ること』を機械で見る形にした」と書いているため、
  この 2 件は主張の裏付けを欠く (DR-5 に近い: 実装者が「気をつける」に落とす)。
- **修正案**: #4 / #5 の実体を `check-owner-scope.sh` と同じ「未実装なら CI が落ちる」形のスクリプト
  (例: `scripts/check-required-tests.sh`) に集約し、§13.3 に是正要求として 1 行追加する。

### 中 2. golden の差分チェック (§5.3 規約 4) に機構が割り当てられていない

- 該当: [docs/design/testing.md](../../../docs/design/testing.md):222 (§5.3 の規約 4) /
  [ci.yml](../../../templates/app-monorepo/.github/workflows/ci.yml):76〜91
- 規約 4 の担保欄は「生成物の差分チェック (既存の `git diff --exit-code` 方式と同じ形)」だが、
  ci.yml の該当ステップは `make sqlc wire` と `make docs` のみで、**golden の再生成を含まない**。
  §13.3 にも要求が無いため、「型を変えたのに golden が古い PR」が緑で通る。
  T-E の判断 (型 + 生成 golden の二本立て) の後半が機構を失う。
- **修正案**: §13.3 に「ci.yml の生成物差分チェックに golden 再生成 (`go test ./... -update` 相当) を追加する」を
  1 行足す。もしくは §5.3 規約 4 の担保欄に対象コマンドを明記する。

### 中 3. 段の境界に穴: 外部 API (Exa) の実挙動がどの段でも担保されない

- 該当: [docs/design/testing.md](../../../docs/design/testing.md):117 (§3.1 の I 段「何を担保しないか」) / :319〜325 (§7.1)
- I 段は「外部 API の実挙動 (LLM / **Exa**) → **U でダブル、E で実物**」と委譲するが、
  (a) U のダブルは定義上実挙動を担保しない (§3.1 の U 行にも「外部 API の実挙動」は無い)、
  (b) E-1〜E-5 に**検索 (Exa) を通る経路が無い** (E-3 は会話 1 ターンの SSE、E-4 はアイデア生成)。
  結果として Exa の応答形式変更・認証失効は**どの段でも検出されない**。
  同種の軽い穴として、U が I へ委譲した「**マイグレーション後のスキーマとの整合**」が
  I 段の「何を担保するか」欄に明記されていない (§8.2 の CI 前提としてしか登場しない)。
- **修正案**: §3.1 の I 段の委譲先を「LLM → E で実物 / **Exa → 非担保 (nightly の疎通確認で見る、または E-3 に
  research 経路を含める)**」と書き分ける。委譲先が無い担保は「非担保」と明示するのが本書の書式に合う。

### 中 4. 未確定 ID (T-Q) が重複し、本文からの参照が別項目を指している

- 該当: [docs/design/testing.md](../../../docs/design/testing.md):637 (§13.1 の T-Q5) / :652 (§13.2 の T-Q5) / :158 / :400
- §13.1 の **T-Q5 = dispatch トークン**、§13.2 の **T-Q5 = Anthropic Go SDK のベース URL 差し替え**で**番号が重複**。
  さらに §4.1:158 は SDK の件を「§13 の **T-Q6**」と参照するが、13.2 の T-Q6 は orval の MSW 生成。
  §7.5:400 は dev のクォータを「§13 の **T-Q2**」と参照するが、実体は 13.2 の T-Q7。
- 未確定事項は実装リポへの引き渡し単位 (§12) で追跡されるため、ID の衝突は「回答したつもりの取り違え」を生む。
- **修正案**: §13.2 を T-Q6〜T-Q9 に振り直し (または 13.1 = T-Qn / 13.2 = T-Rn に分離)、§4.1・§7.5 の参照を直す。

### 中 5. dispatch 送信がトークンの権限不足を検知できない (`curl -sS` は HTTP 4xx でも exit 0)

- 該当: [templates/app-monorepo/.github/workflows/deploy-backend.yml](../../../templates/app-monorepo/.github/workflows/deploy-backend.yml):491〜496 /
  [docs/design/testing.md](../../../docs/design/testing.md):388〜390
- 送信ステップは実在する (§7.4 の記述どおり。**確認済み**)。ただし `curl -sS ... || echo "::warning::"` は
  **401 / 403 / 404 でも exit 0** なので警告が出ない。testing.md §7.4 は
  「無言のスキップにするとトリガーが死んでいることに気付けない」と書いているが、
  実務で最も起きやすい「トークンの権限不足・repo 名の誤り」がまさに無言になる。
- **修正案**: `curl -fsS` にする、または `-o /dev/null -w '%{http_code}'` を取って 204 以外で警告する。
  testing.md §7.4 の「警告を出す」の条件に「**dispatch の HTTP ステータスが 204 でない場合**」を含める。

### 中 6. E2E の結果と「どの commit を検証したか」の対応が取れない (H-4 の承認材料としての追跡性)

- 該当: [e2e.yml](../../../templates/app-monorepo/.github/workflows/e2e.yml):112〜127 /
  [deploy.yml](../../../templates/app-monorepo/.github/workflows/deploy-backend.yml):495 /
  [docs/design/testing.md](../../../docs/design/testing.md):373〜374 (§7.4 の緩和策 2)
- deploy.yml は `client_payload.sha` を送っているが e2e.yml はこれを使わず、
  サマリの「対象 commit」は `github.sha` = **frontend の default branch の SHA**。
  §7.4 の緩和策 2 は「最新の E2E 結果を H-4 の承認材料に含める」と定めるが、
  BE の対象 commit が分からないと「この commit を検証済み」という承認判断ができない
  ([04-human-checkpoints.md](../../../templates/shared/.claude/rules/04-human-checkpoints.md) §1.1 の H-4 確認観点② と噛み合わない)。
- **修正案**: e2e.yml のサマリに `${{ github.event.client_payload.sha }}` (BE 側 commit) と
  FE 側 commit の**両方**を出す。§13.3-6 の要求 (H-4 の確認観点に E2E 結果を追加) に「対象 commit の対応が取れること」を含める。

### 中 7. §7.3 が決めた「E2E 専用契約 2 つ (A / B)」に対し、雛形の資格情報は 1 アカウント分しかない

- 該当: [docs/design/testing.md](../../../docs/design/testing.md):357 / [e2e.yml](../../../templates/app-monorepo/.github/workflows/e2e.yml):76〜78 / :669 (§13.3-5)
- §7.3 は「E2E 専用契約を 2 つ (A / B) と各 1 アカウント」と決めているが、e2e.yml は `E2E_ACCOUNT_*` の 1 組のみ。
  §13.3-5 の operations.md への追記要求も「E2E 専用アカウントの資格情報」と単数で書かれており、B 契約分の所在が未定義。
- 現時点で B を使うのは将来の共有機能だけなので**是正の方向は「B は当面作らない」でもよい**が、
  どちらかを書かないと実装者が判断を迫られる (DR-5)。
- **修正案**: §7.3 の表に「B 契約は共有機能の実装時に追加する (第 1 リリースでは作らない)」を明記するか、
  §13.3-5 を「A / B の 2 組」と具体化する。

---

## 軽微 (Nice to Have)

1. **§11 の D-2 行の語の矛盾** ([testing.md](../../../docs/design/testing.md):532): 「新規の必須チェックは E 段のワークフロー 1 本だけ」と書くが、
   §9.1 は E を **PR の必須チェックにしない**と決めている。「新規ワークフロー 1 本 (PR の必須チェックではない)」に直す。
2. **出典粒度の不統一** (:322): E-2 の根拠が「design_memo.md の決定ログ」で節・行が無い。
   他の出典は パス:行 まで書かれているため、ここだけ照合できない (DR-1 の軽度)。
3. **`baseURL` の受け渡し名が未確定**: e2e.yml は `E2E_BASE_URL`、v2 は `PLAYWRIGHT_BASE_URL` (T-F11)、
   §7.3 は「`baseURL` を環境変数で渡す」とだけ書く。playwright.config が読む env 名を 1 つ決めて §7.3 に書く。
4. **E 段の時間予算に余裕がない** (:119・:397): 5 本 × 3 分 = 15 分でちょうど上限、`workers: 1`。
   §9.2 の予算超過時の対処順序は PR CI (U/I/C) 向けで、**E 段が 15 分を超えた場合の順序が無い**
   (T-Q1 で本数を増やす判断をしたときに効く)。

---

## 本番観点カバレッジ (08-production-gates.md)

testing.md §11 に **A-1〜A-7 / O-1〜O-7 / D-1〜D-8 の全 ID** が回答・部分回答・参照・対象外 (理由 + 先送り先付き) で
現れており、**無言の省略 (DR-2) はゼロ**。ID 別の実在確認をした主なものだけ挙げる。

| ID | 状態 | 箇所 / 所見 |
|---|---|---|
| A-4 | 回答 (機構あり) | §6.1 (全 route の X-1 / X-2 + route 一覧との突き合わせ検査) / §6.3。**「注意する」に退行していない** — ただし機構は §13.3-4 の是正が前提 |
| A-6 | 回答 (機構あり) | §6.2 (全 tool の A-1'〜A-3'、LLM を介さず I 段でハンドラ直呼び)。tool 名一覧の突き合わせも §13.3-4 に含む |
| A-5 / A-1 | 部分回答 | §4.1 の `controller/` 行が auth.md §6.6 の**全行** (401/403/404/429 を実在確認) を必須ケース化 |
| O-4 | 回答 | §5.4 が observability.md §4.3 の F-1〜F-6 (実在確認: 5 分類 + F-6 = セキュリティイベント) と 1 対 1 |
| O-2 | 参照 | §4.1 の `gateway/` 行で usage 4 カウンタと `stop_reason` の欠落禁止をテスト必須化。SSOT は architecture.md §3.8.3 / observability.md §4.2 |
| D-2 | 部分回答 | §9.1。01-construction-loop.md §7.2 のマージ条件を再定義していない (**SSOT 違反なし**を確認) |
| **D-5** | 対象外としているが実質は違反 | §7.3 が資格情報の所在を決めており、雛形がそれに反する (**重大 1**) |
| D-4 | 対象外 (依存) | §8.2 が「本番と同じツールでテスト DB を作る」条件のみ決定。方式未確定は architecture.md §5 に依存 |

**SSOT 境界 (観点 4) の確認結果**: llm-migration.md §8 (ゴールデンセット・ブラインド A/B) /
observability.md §4.3〜§4.4 (しきい値・分類定義) / 01-construction-loop.md §7 (マージ条件) /
02-issue-granularity.md §3.1 (V-x) のいずれとも**重複定義していない**。§0 の境界表と §11 の参照先が実物と一致する。

## 良かった点 (3 行以内)

- 段の境界を「**何を担保しないか + どの段が担保するか**」で切り、越境を全 route / 全 tool 必須 + 一覧突き合わせ検査に落としており、A-4 / A-6 が「実装時に注意する」に退行していない。
- カバレッジ率目標を v2 の実測 (T-F6: しきい値なし Codecov) を根拠に却下し、「必須テストの存在検査」へ置換した判断が、誘因の議論込みで書かれている。
- BE-12 を「型 + 型から生成した golden + 読み手が golden を入力に使う」の 3 点で構造的に潰しており、T-F17 (手書き合成 JSON) の再発経路を閉じている。

## Freeze 判定

**Freeze 不可**。重大 4 件の是正 (うち 2・3 は雛形 `e2e.yml` の修正 + §8.2 への 1 行追加、4 は本書の事実更新) 後に再レビューが必要。
設計判断 (§2 の T-A〜T-O)・段の定義 (§3)・越境テストの範囲 (§6) は書き換え不要。


---

## 雛形側の是正 (2026-07-30・メインセッション)

重大 1〜4 に加えて、**中 5 (`curl -sS` が HTTP 4xx を無言通過する)** も雛形側で是正した:

| 指摘 | 反映先 | 内容 |
|---|---|---|
| **重大 1** | `templates/app-monorepo/.github/workflows/e2e.yml` | E2E 資格情報を **OIDC + Secrets Manager** 経由に変更 (`/hassan-v3/dev/e2e/account` から取得し `::add-mask::` を付ける)。`permissions` に `id-token: write` を追加。**GitHub environment secret にパスワード・TOTP シークレットを置かない** (operations.md §4.1 の限定列挙に一致) |
| **重大 2** | 同 | スキップ検出を **node による JSON 構文解析**に変更。旧実装は ①`grep -o` が無マッチで終了コード 1 を返し `set -euo pipefail` 下で**スキップ 0 件の正常系が必ず赤**になる (再現確認済み) ②パターン `"status":"skipped"` が実出力 `"status": "skipped"` に一致しない ③レポート欠損時に `exit 0` で緑 — の 3 点が同時に壊れていた。新実装は **0 件実行とレポート欠損も失敗扱い** |
| **重大 3** | `docs/design/testing.md` §8.2 | 「**統合段は `DATABASE_URL` 未設定を `t.Skip` にせず失敗させる**」規約を追加 (`TestMain` で `log.Fatal`。却下案 = `t.Skip` / ビルドタグ)。BE-5 の再演を防ぐ |
| **重大 4** | 同 §8.2 / §13.3-1 / §13.3-2 / §6.1-3 / §13.3-4 | stale の是正 (`ci.yml` のスキーマ適用ステップは実在・`e2e.yml` も実在) と行番号出典の実測値への修正 |
| **中 5** | `templates/app-monorepo/.github/workflows/deploy-backend.yml` | dispatch の `curl` を **HTTP ステータス判定付き**に変更 (`-w '%{http_code}'` で 204 を確認)。`curl -sS` は 4xx / 5xx でも終了コード 0 を返すため、旧実装では**トークンが無効で通知できていないことに永久に気付けない**状態だった。デプロイは失敗させないが警告と応答本文を出す |

`ci.yml` (backend) のスキーマ適用ステップも 2026-07-30 に追加済み (§8.2 の前提)。
中 1〜4 / 6〜7 と軽微 4 件は別セッションが `testing.md` 側に反映中。

---

## 中・軽微の反映 (2026-07-30)

**対象**: [docs/design/testing.md](../../../docs/design/testing.md) のみ (中 7 件 / 軽微 4 件 = 11 件全件)。
**重大 4 件はメインセッションが反映済み**のため触っていない (上節参照)。
雛形 (`templates/`) と他設計書 (`docs/design/frontend.md` 等) は**編集せず**、
testing.md §13.3 の是正要求として起票した。

| 指摘 | 反映先 (testing.md) | 内容 |
|---|---|---|
| **中 1** (存在検査 #4 / #5 に実装先が無い) | §10 の表 / §13.3-12 | 検査を **6 種**に整理し、**#4 / #5 の実体を `scripts/check-required-tests.sh` (新規) に確定**。判定規則 (対象集合の決め方・照合するリテラル・テスト名の命名規則) を表に明記し、`check-*.sh` と同じ「未実装なら `exit 1`」形にする要求を §13.3-12 に起票。**Q-3 は規約であって欠落検出の検査ではない**ことを明記 |
| **中 2** (golden 差分に機構が無い) | §5.3 規約 4 / §13.3-8 | 担保欄を「`make golden` (= `go test -run TestGolden -update` 相当) を `ci.yml`:76〜83 の生成物差分チェックに追加し、後続の `git diff --exit-code` で落とす」に具体化 |
| **中 3** (Exa の実挙動がどの段でも非担保) | §3.1 の I / E 行 / **§7.6 (新規)** / §13.3-10 | I 段の委譲先を「LLM → U でダブル・E で実物」/「**Exa → E 段の nightly 疎通確認 1 本 (E-S1) のみ**」に書き分け。**E-S1 を採用** (nightly 限定 Playwright プロジェクト・`request` fixture・30 秒・E-1〜E-5 の本数に数えない) し、却下案 4 件 (E-3 に research を含める / 非担保 / ダブルを厚くする / 合成監視へ寄せる) を明記。**U → I へ委譲された「マイグレーション適用後のスキーマとの整合」を I 段の担保欄に追記** |
| **中 4** (T-Q ID の重複と参照ずれ) | §13.2 / §7.5 | §13.2 を **T-Q6〜T-Q9 に振り直し**、通し番号で一意にする旨を明記。§7.5 の「dev のクォータ = T-Q2」→ **T-Q8** に修正。§4.1 の SDK 参照 (T-Q6) は振り直し後に正しい参照になった。**T-Q10 を新設** (dev で稼働中の BE revision を外部から知る手段が無い — 中 6 の帰結) |
| **中 5** (`curl -sS` が 4xx を無言通過) | §7.4 / §13.3-13 | §7.4 の「警告を出す」条件を **2 つに明文化** (①トークン未設定 ②**dispatch の HTTP ステータスが 204 でない**)。雛形側は**既に是正済み**であることを実測して確認し ([deploy.yml](../../../templates/app-monorepo/.github/workflows/deploy-backend.yml):478〜507)、§13.3-13 に「是正済み・残る要求なし」として記録した (未対応として二重起票しない) |
| **中 6** (E2E 結果と対象 commit の対応) | §7.4 緩和策 2 / §13.3-9 / §13.2 T-Q10 | 「H-4 の承認材料として成立する条件」として **BE 側 commit (`client_payload.sha`) と FE 側 commit の両方をサマリに出す**ことを要求。**nightly / 手動は BE commit を特定できないため承認材料に使わない**と決定 (`/version` 相当が設計に無いため — T-Q10) |
| **中 7** (E2E 専用契約 A / B と雛形の 1 組の齟齬) | §7.3 / §13.3-5 | **第 1 リリースは契約 A の 1 組のみ**と決定 (B は共有機能を E2E に載せる時点で追加。理由: 使われない資格情報がローテーション対象になる)。§13.3-5 を「1 組 = メール + パスワード + TOTP シークレット」に具体化 |
| **軽微 1** (§11 の D-2 行の語の矛盾) | §11 の D-2 行 / §9.1 | 「新規に増えるワークフローは `e2e.yml` 1 本のみで、**これは PR の必須チェックではない**」に修正し、**PR 必須チェックに増えるのは既存ジョブ内のステップだけ**であることを明記。併せて §9.1 の**stale な記述「`e2e.yml` は雛形に存在しない」を実測に合わせて是正**した (重大 4 の同型が §9.1 に残っていた) |
| **軽微 2** (出典粒度の不統一) | §7.1 の E-2 行 | 「design_memo.md の決定ログ」→ **`design_memo.md:187` の決定ログ 3** (引用文付き) |
| **軽微 3** (`baseURL` の env 名が未確定) | §7.3 の `baseURL` 行 | **`E2E_BASE_URL` に確定** (雛形 `e2e.yml`:104 と一致)。**`playwright.config.ts` は既定値を持たず未設定なら throw** と規定。v2 の `PLAYWRIGHT_BASE_URL` 踏襲を却下 (既定 `localhost:3000` があると env 落ち時に原因が切り分けられない) |
| **軽微 4** (E 段の時間予算に余裕が無い) | §9.2 | **E 段が 15 分を超えた場合の順序を新設** (①`workers` 増 = T-Q8 の実測前提 ②dev デプロイ後は E-1 / E-3 の 2 本に絞り残りを nightly ③`timeout-minutes` 引き上げは最後の手段)。**E-1 は本数を削っても常に含める** |

### 追加で反映した項目 (レビュー指摘外)

| # | 内容 |
|---|---|
| 1 | **FE の機械検査 7 種を D-2 の SSOT に登録** ([frontend.md](../../../docs/design/frontend.md) §16.2-1 の要求) — §9.1.1 を新設し、**F-C1〜F-C7** として段 (U / C) と PR 必須チェックの可否・実体パスと行番号 (実測) を表にした。§10 に **6 番 (FE の併置テスト存在検査)** を登録。**§10.1 (FE のカバレッジ担保)** を新設し、数値目標を置かない判断と却下案 3 件を明記 |
| 2 | **§6.1 の 3 の出典ずれを是正** — `check-route-auth.sh` を `ci.yml`:109〜112 と引いていたが、その範囲は `check-owner-scope.sh` のもの。**実測値 :97〜105 (route-auth) / :107〜116 (owner-scope)** に修正 (§13.3-4 も同様) |
| 3 | **§13.3-11 を新設** — frontend.md §16.2-1 の表が「`no-custom-classname` 未設定」「`X-Admin-Token` 未実装」と書いているが**どちらも実装済み**であること、§3.3 / §7.2 の行番号が現ファイルとずれていること、§8.2 の「testing.md §10 に含まれていない」が解消済みであることを起票 (frontend.md は編集していない) |
| 4 | **§0 の SSOT 境界表に frontend.md の行を追加** — FE の依存規則・トークン体系・検査の中身は frontend.md が SSOT であり、本書は**段への割り当てと必須チェック宣言のみ**を行うことを明示 (再定義の防止) |
| 5 | **§12.1 に依存順序 0 番を追加** — frontend の CI を緑にする 3 作業 (npm 依存追加 / L-F4 のドメイン展開 / `check-public-paths.sh` 実装)。雛形が「未実装なら落ちる」形のため、これが済むまで frontend の PR は全て赤になる |
| 6 | **§7.1 の E-1 の CORS 記述に条件を付けた** (frontend.md §16.2-1 の要求③) — FE-D 成立時は **CORS が E-1 の担保対象から外れる**。確定は **FE-Q2 の実測後**とし、不成立なら戻る旨を明記 (断定にしない) |

### 実行した検証

```
[doc-lint] 対象 85 ファイル / エラー 0 件 / 警告 51 件
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 46/46 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
[workflow-shell] 検査 50 ブロック / エラー 0 件
```

testing.md 由来の警告は **§13.1 の未回答 `[Answer]` 5 件 (T-Q1〜T-Q5) のみ**で、反映前と同数
(:764 / :774 / :783 / :792 / :807)。新規に引用した行番号 (frontend-repo の `.eslintrc.json.tmpl` /
`ci.yml` / `e2e.yml`、backend-repo の `ci.yml` / `deploy.yml`) は **`sed` で該当行を表示して実在を確認**した。

### この反映で残る未解決 (再レビュー時の確認対象)

- **T-Q10 (dev の稼働 BE revision を知る手段)** が未解決のため、**nightly / 手動の E2E 結果は
  H-4 の承認材料に使えない**という制約が残る。`repository_dispatch` 起動 (T-Q5 が A) が前提になっている
- **§13.3 の 8〜12 は未対応の是正要求** (雛形・他設計書・実装リポ側)。とくに **12 (`check-required-tests.sh`)**
  が実装されないと §10 の #4 / #5 が「規約のみ」に戻る
- **§7.6 の E-S1** は雛形に実体が無い (§13.3-10)。nightly 限定プロジェクトの実装形態は実装リポで確定する


---

## §13.3 の是正要求への対応 (2026-07-30・メインセッション)

別セッションが `testing.md` に反映した中・軽微 11 件に加え、**§13.3 に起票された雛形側の要求 4 件を実施した**:

| 要求 | 反映先 | 内容 |
|---|---|---|
| **8** golden 再生成の CI | `templates/app-monorepo/.github/workflows/ci.yml` | **「golden ファイルの差分チェック」ステップを追加** (`make golden` → `git diff --exit-code`)。`Makefile` に `golden` ターゲットが無ければ `exit 1` — golden を生成物として扱い手編集させない (§5.3 の規約 4 = BE-12 の再発防止) |
| **9** BE / FE 両 commit の出力 | `templates/app-monorepo/.github/workflows/e2e.yml` | サマリに **FE の commit** と **BE の commit** (`client_payload.sha`) を出す。**nightly / 手動起動では BE の commit が不明**なので「この結果は H-4 の承認材料に使わない」と明示 (§7.4 の決定どおり) |
| **11** `frontend.md` の stale | `docs/design/frontend.md` | **実装状況の記述 4 箇所を実測値に是正** — `no-custom-classname` と `X-Admin-Token` の局所化は**どちらも `.eslintrc.json.tmpl` に実装済み**だったのに「未設定」「未実装」と書かれていた。行番号レンジ 5 箇所も grep の実測値へ更新。**「未設定 / 未実装」の語は 0 件になった** |
| **12** 必須テストの存在検査 | `templates/app-monorepo/.github/workflows/ci.yml` | **`scripts/check-required-tests.sh` を呼ぶステップを追加**。未実装なら `exit 1` — §10 の #4 / #5 (LLM 出力の数値化箇所と越境テストの存在検査) が「規約のみ」に戻るのを防ぐ |

**未対応で残したもの**: 要求 **10** (`e2e.yml` の nightly 限定 E-S1 プロジェクト) —
起草者自身が「**第 1 リリースのスコープに検索経路 (Exa) が入らない場合は不要**」と条件付きで書いているため、
**Q-3 のスコープ確定を待つ**。要求 **13** は是正済みの記録のみ (対応不要)。

検証: `make check` = doc-lint エラー 0 / traceability 46/46・24/24 / **workflow-shell 52 ブロック エラー 0** /
新規 2 ワークフローの YAML パース OK。

---

## 2 巡目 (確認・2026-07-30)

- レビュアー: design-reviewer (opus) / 別セッション。**1 巡目の 15 件 (重大 4 / 中 7 / 軽微 4) の解消判定と回帰検査に限定**し、新規の網羅レビューは行っていない
- **レビュー対象**: [docs/design/testing.md](../../../docs/design/testing.md)
- **付随して確認した雛形 (編集していない)**:
  - [templates/app-monorepo/.github/workflows/e2e.yml](../../../templates/app-monorepo/.github/workflows/e2e.yml)
  - [templates/app-monorepo/.github/workflows/ci.yml](../../../templates/app-monorepo/.github/workflows/ci.yml)
  - [templates/app-monorepo/.github/workflows/deploy-backend.yml](../../../templates/app-monorepo/.github/workflows/deploy-backend.yml):478〜507
  - [templates/app-monorepo/.github/workflows/ci.yml](../../../templates/app-monorepo/.github/workflows/ci.yml) / [templates/app-monorepo/frontend/.eslintrc.json.tmpl](../../../templates/app-monorepo/frontend/.eslintrc.json.tmpl) (§9.1.1 の F-C1〜F-C7 の行番号照合)
- **結果: 重大 1 件 (新規) / 中 3 件 / 軽微 5 件。Freeze 不可** (重大 1 件は §13.3 の記述更新のみで閉じる。設計判断の書き換えは不要)

### 実行した検証

```
[doc-lint] 対象 85 ファイル / エラー 0 件 / 警告 51 件
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 47/47 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
[workflow-shell] 検査 52 ブロック / エラー 0 件
```

`bash scripts/check-workflow-shell.sh` 単独実行も `検査 52 ブロック / エラー 0 件`。
testing.md 由来の doc-lint 警告は **§13.1 の未回答 `[Answer]` 5 件のみ** (:764 / :774 / :783 / :792 / :807 = T-Q1〜T-Q5)
で 1 巡目と同数。**曖昧語 (「適切に」「必要に応じて」「後で検討」および未確定マーカー) は grep で 0 件** (DR-5 なし)。

**抜き取り照合 6 件で打ち切り** (指示どおり)。照合した対象:

| # | 対象 | 結果 |
|---|---|---|
| 1 | **e2e.yml:128〜154 のスキップ検出 node スクリプトを合成 JSON 4 種で実行** (重大 2 の実挙動) | **一致** (下記) |
| 2 | ci.yml の golden 差分ステップ・必須テスト存在検査ステップ ↔ testing.md §5.3 / §10 / §13.3-8 / §13.3-12 | **不一致** (→ **重大 R-1**) |
| 3 | frontend `ci.yml`:7〜11 / :58〜71 / :73〜97 / :99〜117 / :119〜129 とジョブ名 `frontend`・`npm run lint`:38〜39 (§9.1.1 の F-C3〜F-C6) | **全一致** |
| 4 | `.eslintrc.json.tmpl` の 13 レンジ (:30 / :31〜38 / :45〜48 / :49〜52 / :55〜86 / :59〜64 / :65〜70 / :71〜83 / :89〜121 / :122〜140 / :141〜161 / :162〜195 / :196〜224) | **全一致** |
| 5 | deploy.yml:478〜507 (dispatch ステップ) / :491〜507 (HTTP ステータス判定) / :498 (`client_payload.sha`) | **全一致** |
| 6 | 軽微 2 の出典 `design_memo.md:187` / §10 #5 の対象集合 `observability.md` §4.2 の `feature` / e2e.yml:54・:104・:166〜181 | **:187・:54・:104・:166〜181 は一致 / `feature` の定数一覧は不在** (→ **中 R-3**) |

**照合していない範囲 (正直に列挙)**: 1 巡目で一致を確認した T-F1〜T-F17 の再照合は行っていない。
`auth.md` §6.6 / `observability.md` §4.3 の F-1〜F-6 / `llm-migration.md` §8 の内容妥当性も 1 巡目の確認を流用した。
`architecture.md` §3.8.x・`operations.md` §4.1 の本文は今回読んでいない (1 巡目で確認済みの範囲)。

#### 重大 2 の実挙動再現 (最重要の照合)

`e2e.yml`:129〜153 の node スクリプトを scratchpad に抜き出し、合成 Playwright JSON で実行した
(**雛形は変更していない**)。

| ケース | 入力 | 終了コード | 出力 |
|---|---|---|---|
| 正常系 | 2 spec / 全 passed | **0** | `total=2 skipped=0` |
| skip 混入 | 1 passed + 1 skipped | **1** | `total=2 skipped=1` + `::error::スキップされた E2E が 1 件あります: E-5 restore` |
| 0 件実行 | `{"suites":[]}` | **1** | `::error::E2E が 1 件も実行されていません` |
| ネスト suite (describe) 内の skip | `suites[].suites[].specs[]` | **1** | `total=1 skipped=1` (再帰 `walk` が届く) |

レポート欠損は :119〜124 で `exit 1`。**1 巡目に指摘した 3 つの壊れ (①無マッチの `grep -o` で正常系が必ず赤
②`"status":"skipped"` の空白なしリテラルが実出力に一致しない ③レポート欠損で緑) はすべて解消**しており、
かつ「0 件実行も赤」まで強化されている。

### 1 巡目 15 件の解消判定

| 指摘 | 判定 | 根拠 (実測) |
|---|---|---|
| **重大 1** E2E 資格情報の GitHub secret 直置き | **解消** | e2e.yml:39〜41 に `id-token: write`、:72〜98 が OIDC (`configure-aws-credentials`) → `secretsmanager get-secret-value` (`/hassan-v3/dev/e2e/account`) → `::add-mask::` → `GITHUB_ENV`。**`secrets.*` からのパスワード / TOTP 受け渡しは 0 件**。§7.3:360 の決定と一致 (ただし軽微 1 のコメント残り) |
| **重大 2** スキップ検出が機構として不成立 | **解消** | 上表の実挙動再現。設計側の記述 (§8.4 / §13.3-2) も実物と一致 |
| **重大 3** I 段の DB 未接続を fail させる規約が無い | **部分解消** | §8.2:486〜498 に「`DATABASE_URL` 未設定を `t.Skip` にせず失敗させる」規約 + 採用 (`TestMain` で `log.Fatal`) / 却下 2 件 (`t.Skip` / ビルドタグ) が入った。**ただし 1 巡目の修正案の後半 (§10 の存在検査への追加) は未反映** → **中 R-2** |
| **重大 4** 雛形の現状に関する stale な断定 | **解消 (指摘分)** | §8.2:482〜484 が「雛形は 2026-07-30 に是正済み (スキーマ適用ステップ)」、§9.1:540 が「e2e.yml は作成済み」、§13.3-1 / 2 が「解消済み」形式、§6.1 の 3 (:274〜276) が `check-route-auth.sh` = ci.yml:97〜105 / `check-owner-scope.sh` = :107〜116 と実測値。**同じ型の欠陥が別箇所に新規発生している** → **重大 R-1** |
| **中 1** 存在検査 #4 / #5 に実装先が無い | **解消** | §10 を 6 種に整理し #4 / #5 の実体を `scripts/check-required-tests.sh` に確定 (:641〜642)。**判定規則 (対象集合・照合リテラル・命名規則) を表に明記**。ci.yml:104〜114 が未実装で `exit 1`。残る弱点は対象集合の決め方 → **中 R-3 / 中 R-4** |
| **中 2** golden 差分に機構が無い | **機構は解消 / 記述は stale** | ci.yml:88〜100 に専用ステップ (`make golden` → `git diff --exit-code`、`Makefile` に `golden` ターゲットが無ければ `exit 1`)。**§5.3 規約 4 と §13.3-8 が「未対応」のまま** → **重大 R-1** |
| **中 3** Exa の実挙動が非担保 | **解消 (設計)** | §7.6 を新設し **E-S1 (nightly 限定の疎通確認 1 本・30 秒・5 本に数えない)** を採用、却下案 4 件を明記。§3.1 の I 行 / E 行の委譲先を書き分け、U → I へ委譲された「マイグレーション適用後のスキーマとの整合」も I 段の担保欄に追記済み。**実体は §13.3-10 として未対応** (妥当性は軽微 4 参照) |
| **中 4** T-Q ID の重複と参照ずれ | **解消** | §13.2 を T-Q6〜T-Q10 に振り直し、:811〜813 に通し番号の宣言。`grep -on 'T-Q[0-9]*'` で重複なし。本文参照 (:158 → T-Q6 SDK / :418・:604 → T-Q8 クォータ / :385 → T-Q10 / :399 → T-Q5) がすべて正しい項目を指す |
| **中 5** `curl -sS` が HTTP 4xx を無言通過 | **解消** | deploy.yml:494〜507 が `-o /dev/null` 相当 (`-o /tmp/dispatch-res.txt`) + `-w '%{http_code}'` で 204 判定、204 以外は `::warning::` + 応答本文 500 バイト。§7.4:402〜408 が警告条件 2 つを明文化。§13.3-13 が「是正済み・残る要求なし」で二重起票を避けている |
| **中 6** E2E 結果と対象 commit の対応 | **機構は解消 / 記述は stale** | e2e.yml:172〜181 が FE commit と BE commit (`client_payload.sha`) の両方を出し、nightly / 手動では「**不明**」+「**H-4 の承認材料に使わない**」を出力。設計側 (§7.4:377〜385) も決定として書かれている。**ただし §7.4:381 と §13.3-9 が「未充足」のまま** → **重大 R-1** |
| **中 7** E2E 専用契約 A / B と雛形の 1 組の齟齬 | **解消** | §7.3:359 が「第 1 リリースは契約 A の 1 組のみ / B は共有機能を E2E に載せる時点で追加」と決定 (理由付き)。§13.3-5 が「1 組 = メール + パスワード + TOTP シークレット」に具体化 |
| **軽微 1** §11 の D-2 行の語の矛盾 | **解消** | :684 が「新規に増えるワークフローは `e2e.yml` 1 本のみで、これは PR の必須チェックではない」。§9.1:541 も同旨。ただし列挙に golden ステップが無い → 軽微 2 |
| **軽微 2** 出典粒度の不統一 | **解消** | :324 が `design_memo.md:187` の決定ログ 3 を引用付きで参照。**実測一致** (:187 = 「非同期ジョブの SSE 進捗はプロセス内 channel でなく DB 状態のポーリング配信」) |
| **軽微 3** `baseURL` の env 名が未確定 | **解消** | §7.3:362 が `E2E_BASE_URL` に確定 + 「`playwright.config.ts` は既定値を持たず未設定なら throw」。e2e.yml:104 と一致 (実測)。v2 の `PLAYWRIGHT_BASE_URL` 踏襲を却下理由付きで明記 |
| **軽微 4** E 段の時間予算に余裕が無い | **解消** | §9.2:600〜614 に E 段専用の対処順序 3 段 (`workers` 増 → dev デプロイ後は E-1 / E-3 に絞る → `timeout-minutes` 引き上げ) と「E-1 は常に含める」。:610 の e2e.yml:54 (`timeout-minutes: 30`) は実測一致 |

**集計: 解消 12 / 部分解消 1 (重大 3) / 機構は解消だが記述が stale 2 (中 2・中 6 → 重大 R-1 に統合)**。

### 回帰検査

| 検査 | 結果 |
|---|---|
| **§9.1.1 の F-C1〜F-C7 の実体パス・行番号** (メインセッションが後から `.eslintrc.json.tmpl` と `ci.yml` を更新した箇所) | **13 レンジすべて一致**。F-C1 zone (:55〜86 / L-F2 :59〜64 / L-F3 :65〜70 / L-F6 :71〜83) と overrides (L-F1 :89〜121 / L-F5 :122〜140 / L-F4 :141〜161) / F-C2 (:30 / :31〜38 / :45〜48 / :49〜52 / :196〜224) / F-C7 (:162〜195) / F-C3 (frontend `ci.yml`:58〜71) / F-C4 (:73〜97) / F-C5 (:99〜117) / F-C6 (:119〜129) / `push`・`pull_request` の両トリガー (:7〜11) がすべて実測どおり。ジョブ名 `frontend` と `npm run lint` (:38〜39) も一致 |
| **`[Answer]` の消失** | **なし**。T-Q1〜T-Q5 の 5 件が健在 (doc-lint が検出)。§13.2 の T-Q6〜T-Q10 は「調査が必要」節で `[Answer]` を持たない構成 (1 巡目と同じ) |
| **SSOT 重複の新規発生** | **§0 に frontend.md の行が追加**され、§9.1.1 が「段への割り当てと必須チェックの宣言のみ」と自己限定している。検査の**内容**の再定義は無い。ただし §9.1.1 の表に設定値そのもの (whitelist `^(app\|admin)-.*` / `ALLOWED="NEXT_PUBLIC_APP_ENV"`) が転記されている → 軽微 5 |
| **stale の新規発生** | **あり** (重大 R-1)。§5.3 規約 4 / §7.4 緩和策 2 / §13.3-8 / §13.3-9 / §13.3-12 |
| **曖昧語 (DR-5)** | 0 件 |
| **検証ゲート** | `make check` エラー 0 / traceability 未カバー 0 / workflow-shell エラー 0 |

### 新規指摘

#### 重大 R-1. §13.3 の是正要求 8 / 9 が実施済みなのに「未対応」として残り、本文の断定も雛形の現状に反する (1 巡目 重大 4 と同型の再発)

- 該当: [testing.md](../../../docs/design/testing.md):223 (§5.3 規約 4) / :381 (§7.4 緩和策 2) / :841 (§13.3-8) / :842 (§13.3-9) / :845 (§13.3-12)
- **事実 (実測)**:
  1. §5.3 規約 4 は「現状の [ci.yml](../../../templates/app-monorepo/.github/workflows/ci.yml):76〜83 は `make sqlc wire` + `git diff --exit-code` のみで golden を再生成しない。**`make golden` を同ステップに追加し**、その後の `git diff --exit-code` で落とす (§13.3 の是正要求 8)」と書く。
     → **ci.yml:88〜100 に専用ステップ「golden ファイルの差分チェック (BE-12 の再発防止)」が実在**し、`make golden` + `git diff --exit-code` を行い、`Makefile` に `golden` ターゲットが無ければ `::error::` + `exit 1` する。**担保は既に存在する**。
     さらに設計は「**同ステップに追加**」、雛形は「**別ステップ**」で**形も一致していない**。
  2. §13.3-8 は「現状は `make sqlc wire` のみで、**型を変えて golden が古いままの PR が緑で通る**」と断定 → **誤り**。
  3. §7.4 緩和策 2 は「雛形の [e2e.yml](../../../templates/app-monorepo/.github/workflows/e2e.yml):172 は `github.sha` の 1 つだけ = **未充足**。§13 の是正要求 9」と書く → **誤り**。e2e.yml:172〜181 は FE commit と BE commit (`client_payload.sha`) の両方を出し、nightly / 手動では「不明」+「承認材料に使わない」まで出力する。
  4. §13.3-9 も同じ断定 (「:172 は `github.sha` のみで `client_payload.sha` を使っていない」) → **誤り**。
  5. §13.3-12 の対象欄は「実装リポの `scripts/check-required-tests.sh` (新規) **+ ci.yml の検査ステップ**」だが、**ci.yml:104〜114 に呼び出しステップは実装済み** (未実装なら `exit 1`)。残作業はスクリプト本体だけ → **部分 stale**。
- **なぜ本番で問題になるか**: §13.3 は**実装リポへ渡す是正バックログそのもの**であり、1 巡目 重大 4 で挙げた
  (a) 二重作業 (b)「§13.3 は当てにならない」という扱いになり**本当に未対応の 3 / 4 / 6 / 7 / 10 / 11 / 12 が落ちる**
  が再発する。特に golden は「**同ステップに追加**」と読めるため、実装者が既存の sqlc/wire ステップに
  `make golden` を重複追加し、生成物差分が落ちたときの原因切り分け (sqlc か wire か golden か) が 1 段悪くなる。
  行番号・実装状況のずれは `make doc-lint` が検出しない種類の誤りで (rule 05 の「見ないもの」)、実装者は照合せず転記する。
- **修正案**: §13.3-8 / 9 を §13.3-1 / 2 / 13 と同じ「**2026-07-30 に是正済み**」形式へ移す
  (8 は「**別ステップ**として実装済み。設計側の『同ステップに追加』を実測に合わせる」と書く)。
  §5.3 規約 4 の担保欄を「[ci.yml](../../../templates/app-monorepo/.github/workflows/ci.yml):88〜100 の専用ステップ
  (`make golden` → `git diff --exit-code`。`Makefile` に `golden` ターゲットが無ければ `exit 1`)」に置換。
  §7.4 緩和策 2 の「:172 は `github.sha` の 1 つだけ = 未充足」を「雛形 :172〜181 が両方を出力済み」に。
  §13.3-12 の対象欄から ci.yml を外し、残作業をスクリプト本体に限定する。

#### 中 R-2. 重大 3 の是正が「規約」だけで終わり、§10 の存在検査に入らなかった

- 該当: [testing.md](../../../docs/design/testing.md):486〜498 (§8.2) / :630〜643 (§10 の 6 種) / :834 (§13.3-1)
- **事実**: §8.2 に `TestMain` 必須化の規約は入ったが、1 巡目の修正案の後半
  「§10 の存在検査に『I 段のヘルパが skip 経路を持たないこと』または『I 段のテスト実行件数が 0 でないこと』を追加する」
  は**反映されていない** (§10 の 6 種に該当項目なし)。§13.3-1 は「規約を実装リポの `TestMain` に落とすこと」と
  送っているだけで、機械検査は無い。
- **なぜ問題になるか**: CI は常に `DATABASE_URL` を設定する (ci.yml:73〜74) ため **`TestMain` の `log.Fatal` は CI では発火しない**。
  実際の抜け道は「個別テストに `if os.Getenv("DATABASE_URL") == "" { t.Skip() }` を書く」形であり、これを止めるものが無い。
  testing.md 自身の基準 (:645〜648「実装先の無い項目を残すと実装者が『気をつける』に落とす = DR-5」) に照らして不足しており、
  **BE-5 の再演余地が規約の遵守に依存したまま残る**。
- **修正案**: `check-required-tests.sh` の判定に 1 行足すだけで閉じる —
  「`repository/` · `controller/` 配下の `_test.go` に `t.Skip` / `t.Skipf` が現れたら `exit 1` (許可は `-short` 判定の 1 箇所のみ)」。
  §10 の表に **#7** として登録し、§13.3-12 の判定規則に含める。

#### 中 R-3. §10 #5 の対象集合 (`feature` 識別子の Go const 群) が、どの設計書にも存在しない

- 該当: [testing.md](../../../docs/design/testing.md):642 / [observability.md](../../../docs/design/observability.md):137
- **事実**: §10 #5 の判定規則は「[observability.md](../../../docs/design/observability.md) §4.2 の `feature` 識別子の
  **定数一覧** (Go の const 群) を対象集合とし」と書くが、observability.md:137 の `feature` は
  **ログ項目の説明で例が 3 つ挙がっているだけ** (`conversation.turn` / `plan.generate` / `asset.extract`) で、
  「const 群として 1 箇所に定義する」という要求はどこにも無い (`grep -n "feature" docs/design/architecture.md` は **0 件**)。
- **なぜ問題になるか**: 実装リポが const 群を作らなければ **#5 の対象集合が空**になり、
  `check-required-tests.sh` は「0 件を検査して緑」= 検査したふりになる。§10 が最も避けたい形 (存在検査が空回り) が
  対象集合の未定義によって起きる。**DR-1 (出典なしの断定)** にも当たる。
- **修正案**: §13.3 に「observability.md §4.2 に『`feature` 識別子は Go の const 群として 1 箇所で定義し、
  追加は同 PR で行う』を追記する」を 1 行起票する (observability.md 側の SSOT に置く)。
  もしくは §10 #5 の対象集合を「observability.md §4.2 の `feature` の**表**」と定め、表を enumerated にする要求を出す。

#### 中 R-4. §10 #4 の対象集合が自己申告マーカー (`// llmparse:`) で、付け忘れが検査の無効化になる

- 該当: [testing.md](../../../docs/design/testing.md):641
- **事実**: `// llmparse:` マーカーは **testing.md:641 が唯一の出典** (`grep -rn "llmparse" docs/ templates/` は同行のみ)。
  マーカーを付け忘れた関数は対象集合から外れ、**検査は緑のまま FE-6 (数値パーサのレンジ誤抽出) の再発点が無防備**になる。
  #4 は FE-6 の再発防止そのものなので、対象集合の決め方が抜け道になるのは効き目を大きく削る。
- **修正案** (どちらか): (a) 対象集合を「`entity/` 配下で `strconv.Atoi` / `ParseFloat` / 数値抽出の正規表現を含む関数」と
  機械的に定め、**除外を `// llmparse:ignore` の明示に反転**させる (漏れが「付け忘れ」ではなく「除外の明示」になる)。
  (b) マーカー付与を `templates/app-monorepo/backend/.claude/agents/code-reviewer` の観点に載せることを §13.3 に起票する。
  **1 巡目より確実に良化しているため、これ単独では Freeze をブロックしない**。

#### 軽微

1. **e2e.yml:52〜53 のコメントが是正後の実装と食い違う** — 「dev の資格情報を environment secret から取る
   (リポジトリ全体の変数に置かない)」と書かれているが、重大 1 の是正後は**資格情報は Secrets Manager が唯一の所在**で、
   environment に残るのは `vars.E2E_AWS_ROLE_ARN` のみ。本体は正しく、コメントだけ旧方式のまま残っている
   (雛形はコピーして使われるため、コメントが誤誘導になる)。
2. **§11 の D-2 行 (:684) の列挙に golden 差分ステップが無い** — 「PR の必須チェックに増えるのは既存ジョブ内のステップだけ
   (backend = `check-owner-scope.sh` への追加 + `check-required-tests.sh`)」に **ci.yml:88〜100 の golden 差分ステップ**が
   入っておらず、列挙が実物と 1 件ずれる。
3. **JSON reporter の設定が引き渡し事項になっていない** — e2e.yml のスキップ検出は
   `playwright-report/results.json` の実在が前提 (欠損は `exit 1`)。§12.1 の 6 は「setup project + E-1」のみで、
   「`playwright.config` の reporter に json を追加し、出力先を e2e.yml:117 と一致させる」が書かれていない。
   雛形が赤で気付ける形なので実害は小さいが、1 行あれば初回の赤の切り分けが不要になる。
4. **要求 10 (E-S1) を未対応として残した理由が testing.md に書かれていない** — 上の「§13.3 の是正要求への対応」節は
   「起草者自身が『第 1 リリースのスコープに検索経路 (Exa) が入らない場合は不要』と条件付きで書いている」ことを根拠にするが、
   **§7.6 と §13.3-10 にこの条件は無い** (grep で確認)。むしろ §7.6 却下案 (b) は
   「Exa は [llm-migration.md](../../../docs/design/llm-migration.md) V-11 の企画書リサーチが依存する外部依存であり無担保にできない」、
   §13.4:854 は「第 1 リリースのドメインは テーマ / アセット / **会話 (idea / plan を含む)**」と書いており、
   **第 1 リリースに Exa 経路が入る前提**に読める。先送りそのものは雛形作業の順序として妥当だが、
   **条件を §13.3-10 に明記する** (「Q-3 のスコープ確定後に実装。検索経路が入るなら必須」) こと。
5. **§9.1.1 の表に設定値そのものが転記されている** — whitelist `^(app|admin)-.*` / `ALLOWED="NEXT_PUBLIC_APP_ENV"` /
   例外パス (`src/styles/**` と `tailwind.config.*`) は雛形と frontend.md 側の値であり、
   §0 の SSOT 境界 (「本書は段への割り当てと必須チェックの宣言のみ」) からはみ出す。
   **行番号と併せて 2 箇所目の stale 源になる**ので、値は落として「実体パス:行」だけに留めるのが安全。

### Freeze 判定

**Freeze 不可**。ただし残るのは **testing.md §13.3 と本文 3 箇所の記述更新 (重大 R-1)** と
**中 R-2 / R-3 の 2 行追記**のみで、**設計判断 (§2 の T-A〜T-O)・段の定義 (§3)・越境テストの範囲 (§6)・
E2E の設計 (§7)・カバレッジの扱い (§10) は書き換え不要**。
1 巡目の重大 4 件はすべて機構として閉じており (重大 3 のみ機構が規約止まり = 中 R-2)、
**雛形側 (e2e.yml / ci.yml / deploy.yml) に新規の重大は無い**。


---

## 2 巡目指摘の反映 (2026-07-30・メインセッション)

| 指摘 | 反映先 | 内容 |
|---|---|---|
| **重大 R-1 (stale)** | `docs/design/testing.md` §5.3 規約 4 / §7.4 緩和策 2 / §13.3 の 8・9・12 | **実施済みの機構を「未対応」と書いていた 5 箇所を是正**。§5.3 は「golden 再生成の**専用ステップ**がある」+ 生成物差分と別にした理由 (落ちた原因の切り分け)、§7.4 は「BE / FE 両 commit を出力済み・`repository_dispatch` 以外は BE 不明として承認材料にしない」、§13.3 の 3 行は**実測行番号つきで「2026-07-30 実施済み」**へ |
| 中 R-2 / R-3 (規約止まり・対象集合の不在) | 未反映 | Freeze の阻害要因ではないが、**§10 の #5 の対象集合 (`feature` の Go const 群) がどの設計書にも存在しない**点は observability.md 側の決定が必要。次に同書を触る機会にまとめる |

**プロセス側の是正**: 同じ型 (機構は直したが文書が stale) が **3 巡連続で最上位指摘**だったため、
`.claude/rules/06-delegation-prompts.md` に「**機構を直したら、その機構を語る文書を同じ差分で直す**」節を追加した
(編集したファイル名で `docs/` と `aidlc-docs/` を全文検索し、状態を語る記述と引用行番号を同じ差分で更新する手順)。
