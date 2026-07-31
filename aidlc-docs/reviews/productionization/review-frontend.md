# レビュー結果: docs/design/frontend.md (フロントエンド設計)

- **レビュー対象 (リポジトリ相対パス)**
  - `docs/design/frontend.md` (806 行・新規。**本レビューの唯一の対象**)
  - 付随確認 (編集していない): `templates/frontend-repo/.github/workflows/ci.yml` /
    `templates/frontend-repo/CLAUDE.md.tmpl` / `templates/frontend-repo/` 配下の全ファイル一覧
  - 整合確認のため参照: `docs/design/API/README.md` / `docs/design/auth.md` §6.1 §6.2 §6.6 §6.9 /
    `docs/design/testing.md` §4.2 §9 §10 / `docs/design/operations.md` §3.3 §7.2 /
    `docs/design/observability.md` §4.3 §4.4 / `docs/design/data-model.md` DM-1 /
    `docs/design/design_memo.md`:149/:150/:169 / `.claude/rules/feedback_review_patterns.md`
  - **対象外** (別レビュー): `docs/design/data-model.md` 全体 / `docs/design/testing.md` 全体
- **判定: Freeze 不可** (重大 5 件)
- 件数: **重大 5 / 中 7 / 軽微 4**
- レビュー基準: 本番基準 (`.claude/rules/08-production-gates.md`)。「PoC では対象外だった」を省略理由と認めない

---

## 実行した検証

```
$ make check
[WARN ] ./docs/design/frontend.md:730 未回答の [Answer]:   ← FE-Q1
[WARN ] ./docs/design/frontend.md:739 未回答の [Answer]:   ← FE-Q2
[WARN ] ./docs/design/frontend.md:748 未回答の [Answer]:   ← FE-Q3
[WARN ] ./docs/design/frontend.md:757 未回答の [Answer]:   ← FE-Q4
[WARN ] ./docs/design/frontend.md:762 未回答の [Answer]:   ← FE-Q5
[WARN ] ./docs/design/frontend.md:768 未回答の [Answer]:   ← FE-Q6
[doc-lint] 対象 83 ファイル / エラー 0 件 / 警告 48 件
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 46/46 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
[workflow-shell] 検査 45 ブロック / エラー 0 件
```

- **doc-lint: エラー 0** (リンク切れ・参照リポのパス不在なし)。警告は既存文書分を含む 48 件で、
  そのうち frontend.md 由来は FE-Q1〜Q6 の `[Answer]` 未回答 6 件のみ
- **traceability: 未カバー AC ゼロ** (DR-6 の宙吊りなし)。frontend.md が宣言する AC-1.1 / AC-1.4 /
  AC-2.3 / AC-2.4 / AC-5.2 はいずれも既にカバー済み集合に含まれる

### 抜き取り照合 (12 グループ。指示の 8 件上限を超えたが、いずれも単発 grep で完了)

| # | 主張 | 照合コマンド / 参照 | 結果 |
|---|---|---|---|
| 1 | **V-9「SSE の読み取りループが 7 ファイル」** | `grep -rl "text/event-stream\|getReader()" src` (hassan-v2-frontend) | **一致 (7 件)**。内訳も本文どおり (ai-sheet 2 / business-plan 4 / research 1)。**数え方の grep 条件が本文に明記されている**ため再現できた。オーケストレーター側の 5 件は条件 (`EventSource`) 違いで、本文の主張が正しい |
| 2 | V-9「未対応コメントが残る」 | `create-stream-research-chat.ts:17` | **一致** (「ストリーム処理は共通化する」の未対応コメントが同行に実在) |
| 3 | §16.2-1「ci.yml に 5 検査のうち 4 つが無い」 | `templates/frontend-repo/.github/workflows/ci.yml` 全文 + `find templates/frontend-repo -type f` | **一致だが過小評価**。再生成差分検査 (`:41-49`) は実在。**雛形に eslint 設定ファイルが 1 件も無い**ため lint zone も実体ゼロ → 重大 4 |
| 4 | §16.2-2②「雛形が `GET /api/features` を例示」 | `grep -rn "api/features" templates/` → **0 件** | **不一致 (陳腐化)** → 中 1 |
| 5 | design_memo:149 / :150 / :169 | `sed -n '149p;150p;169p'` | **3 件すべて一致** (SSE 型の単一ソース化 / 共通クライアント 1 本 / 履歴 GET + 再接続) |
| 6 | §9「BE は 401 に本文を返さない」/ 404 は本文あり / 429 に `Retry-After` | `auth.md` §6.6 の表 | **一致** (`D-API-6` の「404/403 も本文を返す」とも矛盾しない) |
| 7 | keep-alive 15 秒 / 1 ターン 5 分 / F-4・F-5 | `observability.md` §4.4 §4.3 | **一致** |
| 8 | §16.2-3「イベント名の一覧がどこにも無い」 | `grep -n "event:\|イベント名" observability.md` → **0 件** | **一致** (是正要求は妥当) |
| 9 | §0「ID の型は data-model に従う (`bigint` = number)」 | `data-model.md` DM-1 | **不完全**。DM-1 は「機能テーブル `bigint` + **アイデンティティ基盤は `uuid`**」+ 外部 ID `text` → 中 2 |
| 10 | 403 は 11 本 / D-API-8' / D-API-13 / D-API-4 | `API/README.md`:106-113, :331, :446 | **一致** |
| 11 | プロトタイプ `:4896-4902` (ナビ 7 項目) / `:4909` (ホーム = テーマ管理) | `docs/prototype/hassan_agent_prototype_v2.html` | **一致** |
| 12 | フィーチャーフラグの配布方法 | `operations.md` §7.2 OP-I | **確定済み** (環境変数のみ・API で配らない)。frontend.md の記述と食い違う → 中 1 |

**未照合 (対象外と判断した範囲)**: §5.2 の「LLM を伴う 3 本」の本数と API/README の LLM 列の一致、
§11.1 の 25 ルート個々のエンドポイント実在、`eslint-plugin-tailwindcss` / `react/forbid-dom-props` の
ルール名の実在、v2 `src/lib/post-logs.ts` の用途 (本文も「未調査」と明記)。

---

## 重大 (Must Fix)

### 重大 1. 社内管理者経路 (auth.md §6.2 の 2026-07-30 決定) の FE 側が丸ごと存在しない — A-2 / DR-2

- 該当: `docs/design/frontend.md:551-577` (§11.1 ルート一覧) / `:292` (§5.2「`X-Admin-Token` は送らない」) /
  `:636` (§13 の A-2 回答)
- 根拠: `docs/design/auth.md` §6.2 は **本増分の対象に「社内管理者のサインイン (`POST /admin/signin`)・
  MFA の登録/検証/リセット・アカウントのロック解除」を含める**と 2026-07-30 に決定している
  (「これが無いと契約内管理者が全員ロックされた場合に製品内の回復手段が存在しない」)。
- 問題: frontend.md は §5.2 で `X-Admin-Token` を送らないと決め、§11.1 に管理者向けルートを 1 本も置かず、
  §13 の A-2 回答は契約内管理者限定の 3 画面だけを扱う。結果、**この 4 機能の UI をどこに置くかが
  どの設計書にも無い** (同一 Next.js アプリの別ルートグループなのか、別アプリなのか、UI を作らず
  運用で API を直叩きするのか)。
- 本番で何が起きるか: `auth.md` §6.9 の「トークン漏洩時に即座に遮断する」設計は
  **ロック解除に到達できる UI があること**を前提にしている。UI が誰の担当でもないまま増分 1 を出すと、
  管理者全員ロック時の回復手段が製品内に存在しない状態で本番稼働する。
- 修正案: §11.1 に管理者ルート群を追加する (例: `(admin)/admin/signin` / `/admin/mfa` /
  `/admin/accounts`)。**または** 「社内管理者 UI は本 FE の対象外」とし、
  対象外の理由と先送り先 (どのリポ・どの増分で作るか) を §13 A-2 に明記する。
  いずれの場合も §5.2 の「`X-Admin-Token` は送らない」に**例外の有無**を書く
  (管理者経路を同一 FE に置くなら例外が必要になる)。

### 重大 2. §11.1 に `/mfa` が無く、§11.2 の MFA ゲートと CI 照合が最初から成立しない — A-1 / A-5

- 該当: `docs/design/frontend.md:595`「MFA 未検証の扱いは v2 を踏襲する
  (`requiredMfaType` が残っている間は `/mfa` 以外へ行かせない)」/ `:596-598`
  「`middleware.ts` の許可リストと `(auth)` グループのルート一覧が一致することを CI で検査する」/
  `:551-577` (ルート一覧に `/mfa` が無い)
- 根拠: v2 の実測 V-14 (`hassan-v2-frontend/src/middleware.ts:29-34`) が
  `token.requiredMfaType !== 'totp'` を認可条件にしていることは本文が自ら出典付きで書いている。
  `auth.md` §6.2 も MFA の登録・検証を本増分に含める。
- 問題: 遷移先の `/mfa` (および登録用の画面) がルート一覧に無いため、
  ①`(auth)` / `(app)` のどちらに属するかが決まらない ②§11.2 が新設する CI 照合
  (許可リスト ↔ `(auth)` 配下の一覧) が**初日から不一致で落ちる or 抜け穴になる**。
- 本番で何が起きるか: MFA 未検証ユーザーが `(app)` 配下に到達する、あるいは `/mfa` を許可リストに
  入れた結果「未認証でも `/mfa` に入れる」状態が生まれる。どちらも認証境界の穴。
- 修正案: §11.1 に `/mfa` (+ 必要なら `/mfa/setup`) を追加し、§11.2 に
  **3 状態 (未認証 / 認証済み・MFA 未検証 / 認証済み) × 到達可能ルートの遷移表**を書く。
  許可リストは「未認証で入れるパス」と「MFA 未検証で入れるパス」の**2 本立て**になることを明示する。

### 重大 3. 中継 Route Handler が catch-all で、中継先の許可リストと GET 経路が無い — A-1 に新しい穴を作る

- 該当: `docs/design/frontend.md:376`「パス: `src/app/api/stream/[...path]/route.ts` (POST)。
  **BE の SSE エンドポイントへ 1 対 1 で中継**する」/ `:202-203` (L-F5 の例外で
  `src/app/api/**` を fetch 禁止 zone から除外) / `:624-627` (§12 の CORS 回答)
- 問題 (2 点):
  1. **許可リストが無い catch-all プロキシ**。`[...path]` を「1 対 1 で中継」とだけ書くと、
     実装は任意の BE パスを **HttpOnly Cookie のセッションから取り出した `X-Token` 付きで**
     中継する汎用プロキシになる。FE-D が獲得した性質 (「ブラウザは BE を直接叩けない」) が崩れ、
     ブラウザ JS から `POST /api/stream/themes/1` のような**任意の BE 操作**が実行可能になる。
     §12 が「BE の CORS 許可リストを縮小できる」と回答していることと合わせると、
     **BE 側の防御を緩めた上で FE に開いたプロキシを置く**形になる。
  2. **GET の SSE が中継できない**。§6.3 は Route Handler を「(POST)」と書くが、
     `docs/design/API/assets.md` の SSE は `GET /asset-extractions/{extraction_id}/stream` であり、
     §11.1 の `/assets/extractions/[extractionId]` はこれを使う画面として挙がっている。
- 修正案: §6.3 に (a) **中継可能なエンドポイントの列挙** (現状 SSE は 2 本。それ以外は 404 を返す)、
  (b) **メソッドごとのハンドラ** (`GET` と `POST` の両方)、
  (c) **Origin / SameSite の扱い** (Cookie 認証の中継なので、クロスサイトからの呼び出しを
  どう弾くかを設計時点で決める。「SameSite=Lax に依存する」ならその旨を明記する) を追加する。
  §12 の CORS 縮小の回答には「中継対象の 2 本を許可リスト化した上で」という前提を付す。

### 重大 4. FE-3 / FE-5 / FE-4 / FE-6 の担保手段が実体を持たず、CI ゲートの SSOT にも登録されていない — DR-5 / D-2

- 該当: `docs/design/frontend.md:658-668` (§14 の担保手段列) / `:772-775` (§16.2-1) /
  `:650` (§13 D-2「段とマージ条件の SSOT は testing.md §9」)
- 実測 (照合 #3):
  - `templates/frontend-repo/` の全ファイルは **8 件** (`.claude/agents/` 2 / `.github/ISSUE_TEMPLATE/task.yml` /
    `pull_request_template.md` / `workflows/ci.yml` / `workflows/e2e.yml` / `CLAUDE.md.tmpl` /
    `scripts/hooks/pre-commit`)。**eslint 設定・`package.json`・`tsconfig`・vitest 設定が無い**。
  - `ci.yml` は `npm run lint` を実行するが、**何を検査するかを決める設定が雛形に無い**ため
    §16.2-1 の「lint zone は `npm run lint` に含まれる」は成立しない。
    したがって §14 の FE-3 (`no-arbitrary-value` / `no-custom-classname` / hex 禁止 / `style` 禁止) と
    FE-5 (`import/no-restricted-paths`) の担保は**現時点で 0 件**。
  - frontend.md が新設する検査 (lint zone・テスト存在検査・公開パス照合・`NEXT_PUBLIC_` 許可リスト・
    `globals.css` 行数の可視化) は `docs/design/testing.md` §9 (マージ条件) にも §10 (必須テストの
    存在検査 5 種) にも登録されていない。§10 の 5 種は AC-ID・X-1/X-2・tool の A-1'・
    `entity/` のレンジ入力・F-1〜F-5 で、**FE の同名 `*.test.ts` 存在検査は含まれない**。
- 本番で何が起きるか: FE-3 (トークン未使用) と FE-5 (lib への hook 混入) は
  **PoC と v2 の両方で実際に起きたパターン**であり、本書自身が「v2 は雛形と同じ禁止事項を文書に
  持ちながら FE-5 が起きた (V-17)」と書いている。設定が引き渡されないまま実装が始まれば、
  §14 の担保は「気をつける」に退行し、同じ再発を招く。
- 修正案:
  1. §16.2-1 の記述を「**lint zone を含む 5 検査すべてが雛形に無く、eslint 設定ファイル自体が存在しない**」
     に是正する (現在の「lint zone は含まれる」は誤り)。
  2. §16.2 に **`docs/design/testing.md` §9 / §10 宛の是正要求**を追加する
     (FE の 5 検査をマージ条件と存在検査の一覧に登録する)。§13 の D-2 が「SSOT は testing.md §9」と
     宣言している以上、登録しなければ決定が宙に浮く。
  3. §15.1 の 1 (雛形展開 + 基盤設定) の成果物に「eslint 設定 (zone / tailwind / hex / `style`)・
     vitest 設定・存在検査スクリプト」を**引き渡し物として名前で列挙**する。

### 重大 5. FE-Q2 が不成立だった場合の代替が、FE-D 自身の却下理由 (CORS) を解消していない — A-1 / DR-5

- 該当: `docs/design/frontend.md:112` (FE-D の却下 (a) と (d)) / `:381-383` (§6.3 の「Vercel の関数実行時間の
  上限に収まるかは要確認」) / `:732-739` (FE-Q2) / `:788-790` (§16.2-4) / `:795-797` (§16.3-1)
- 問題:
  1. FE-D は却下 (a) (v2 方式) の理由に **「Vercel の Preview URL が変動するため BE の CORS 許可リストを
     維持できない」** を挙げる。ところが FE-Q2 不成立時の代替である却下案 (d)
     (BE が SSE 用の短命トークンを発行し、**ブラウザが直接 SSE を張る**) は
     **同じ CORS 問題をそのまま再現する**。代替の成立条件 (CORS をどう解くか・短命トークンの
     有効期間・スコープ・失効・発行エンドポイント) が書かれておらず、**「不成立なら (d)」は
     成立が確認されていない代替**である。
  2. §12 と §16.2-4 は **「BE の CORS 許可リストを縮小できる可能性」を operations.md へ反映せよ**と
     求めている。FE-Q2 が未解決のまま縮小すると、**(d) への退避路を自ら塞ぐ**。
  3. FE-Q2 は「未調査」だが、**Vercel のドキュメントと 1 回の実測で決着する調査**であり、
     暫定既定で流したまま §15.1 の依存順序 (5 番目に `lib/sse/`) に入れると、
     不成立が判明した時点で BE の新規 API・`auth.md` の是正・plan.md の Task 追加が
     まとめて発生する (最も手戻りが大きい順序になっている)。
- 修正案:
  1. **FE-Q2 を §15.1 の依存順序の第 0 ステップ** (雛形展開より前) に置き、
     「Node.js ランタイムの Function で 5 分のストリームを中継できるか」を実測で確定させる。
  2. (d) を採る場合の骨子 (短命トークンの有効期間・スコープ・単回使用の有無・発行 API のパス・
     CORS 許可リストの運用) を §16.1 FE-Q2 に**代替の設計骨子として**書く。
     書けないなら「(d) は成立未確認であり、不成立時の判断はユーザー決定を要する」と明記する。
  3. §16.2-4 に **「FE-Q2 が肯定された後に限る」** を前提条件として付す。

---

## 中 (Should Fix)

### 中 1. §16.2-2② が陳腐化しており、かつ operations.md の確定済み決定と矛盾する

- 該当: `docs/design/frontend.md:779-781`
- 実測: `grep -rn "api/features" templates/` → **0 件** (雛形は 2026-07-30 に是正済みで、現在は
  `templates/frontend-repo/CLAUDE.md.tmpl:46-51` が「配布方法は未確定」と明記している)。
  さらに `docs/design/operations.md` §7.2 (OP-I) は **「フラグの実装形態 = 環境変数のみ
  (BE = ECS タスク定義、**FE = Vercel の環境変数**)・フラグを API で配らない」を確定済み**で、
  `GET /features` のような API は却下案 (a) として明示的に却下されている。
- 帰結: ②の「配布方法の確定が必要」は既に決着している。**代わりに埋めるべき穴が §12 側にある** —
  §12 の環境変数表 (`:608-614`) は FE 固有の環境変数を 5 分類で確定すると宣言しているが、
  **OP-I が FE 側に要求するフラグ環境変数の行が無い**。加えて §12 の CI 検査
  (`NEXT_PUBLIC_` の許可リストは「上表の 1 件」) は、フラグを追加した瞬間に判断が必要になる。
- 修正案: ②を削除し、§12 の表に「フィーチャーフラグ (`operations.md` §7.2 OP-I)」の行を追加する。
  導線の出し分けを Server Component で行うなら `NEXT_PUBLIC_` を**付けない**ことを明記し、
  許可リスト検査との整合を書く。

### 中 2. §0 の「`bigint` = TS では `number`」が data-model.md の決定を取りこぼしている — DR-1

- 該当: `docs/design/frontend.md:28`
- 根拠: `docs/design/data-model.md` DM-1 は「**機能テーブルは `bigint`、アイデンティティ基盤テーブルは
  `uuid`**」+ 外部 ID の例外 (`read_news_accounts.news_id` は `text`) と決めている。
- 帰結: `/settings/members` `/themes/[themeId]/members` (アカウント = uuid) と `/news/[newsId]`
  (CMS の text ID) を扱う画面で、ルートパラメータと ViewModel の ID 型が誤って `number` になる。
  §5.3 の「生成型をそのまま使う」方針では tsc が救ってくれるが、
  ルートパラメータ (`params.newsId` は常に string) の変換箇所で事故になる。
- 修正案: §0 の当該行を「機能リソースの ID は `number` / アカウント・契約は `string` (uuid) /
  外部 ID (`news_id`) は `string`」に直す。

### 中 3. A-2 の導線出し分けに必要なロール情報の取得元が未定 — DR-5

- 該当: `docs/design/frontend.md:574-576` (契約内管理者限定の 3 画面) / `:482` (「FE 側で権限判定をしない」) /
  `:636` (§13 A-2)
- 問題: 「導線を出さない」ためには FE がロールを知る必要がある。その出所
  (next-auth セッションに `role` を載せる / 403 を受けてから隠す / 専用の me API) が書かれていない。
  `auth.md` §6.1 の JWT クレームに `role` はあるが、FE-D では JWT をアプリコードで復号する方針が無い。
- 修正案: §5.2 または §11 に「セッションに載せる**表示用の最小属性**」(role / 契約内管理者かどうか) を
  明記する。判定の正が BE であることは維持したまま、表示用属性の出所を 1 箇所に決める。

### 中 4. 401 時の「セッションを破棄」の実現手段と、セッション有効期間の対応が未定

- 該当: `docs/design/frontend.md:481` (§9 の 401 行)
- 問題: FE-D では 401 を最初に受けるのは Server Component / Server Action / Route Handler。
  next-auth の `signOut` はクライアント API であり、**サーバ側から Cookie を破棄する手段**
  (Route Handler での cookie delete 等) が決まっていない。決まらないと
  「401 を受けたが Cookie が残り、`/login` へ飛んだ後もセッションが生きている」実装差が生まれる。
- 併せて: v2 は next-auth の `session.maxAge` = 7 日で **BE の JWT 期限 7 日と一致**させている
  (`auth.md` の v2 実測。frontend.md の V-13 も同じ事実を書いている)。
  `auth.md` §6.9-3 は v3 も **7 日据え置き** (リフレッシュなし) と決定済みなので、
  **Cookie が唯一の保持先になる v3 では両者の一致を明記すべき**
  (ずれると「Cookie は生きているが BE の JWT が期限切れ」で全リクエストが 401 になる)。
- 修正案: §5.2 か §9 に「401 を受けた場合の Cookie 破棄経路」と
  「next-auth セッション maxAge = BE の JWT 有効期間 (7 日) に一致させる」を追加する。

### 中 5. FE-Q1 の暫定既定に「手書き型を書かせない歯止め」が無い / 是正要求が plan.md に立っていない

- 該当: `docs/design/frontend.md:724-730` (FE-Q1) / `:367` (S-8「手書きの `StreamResponse` 型を作らない」)
- 問題 1: FE-Q1 の暫定既定は「イベント名 + payload の汎用形で先に作り、型の確定後に decode 層だけ
  差し替える」。汎用形の payload の型が明示されていないため、実装者が「暫定の payload 型」を
  手書きすると **V-10 (生成型と手書き型の並存) をそのまま再生産する**。
- 問題 2: FE-Q1 の「確認したいこと: 会話 API の設計着手時期 (plan.md への Task 追加が必要か)」は
  §16.2 の是正要求リストに**立っていない** (plan.md 宛は Task-3l の完了マークのみ)。
  §11.1 は会話画面を**増分 1** に置きながら「実装着手不可」としており、
  このままでは増分 1 のスコープが閉じない。
- 修正案: (a) 汎用形の payload は **`unknown` 固定**、参照は `lib/sse/decode-event.ts` のみ、という
  縛りを §6.2 に書く。(b) §16.2 に「会話 API の設計 Task を plan.md に追加する」是正要求を追加する
  (§16.2-3 のイベント名一覧の要求とセットで 1 項目にしてよい)。

### 中 6. SSE 中継の GET 経路 (重大 3-2 の別側面) と §11.1 の SSE 画面の対応が表になっていない

- 該当: `docs/design/frontend.md:376` / `:561` `:570` (SSE を使う画面 2 本)
- 修正案: §6.3 に「中継対象の SSE エンドポイント × メソッド × 対応画面」の小表を置く
  (現状 2 本 + 会話は FE-Q1 待ち)。重大 3 の許可リストと同じ表で兼ねられる。

### 中 7. SSE 中継の Vercel 側コストと同時実行上限が O-3 / D-1 で評価されていない

- 該当: `docs/design/frontend.md:644` (§13 O-3 = 「BE の責務」) / `:795-797` (§16.3-1)
- 問題: Route Handler で 5 分間ストリームを中継すると、**Vercel の Function 実行時間が接続時間ぶん
  課金され、同時実行上限が同時 SSE 接続数の上限になる**。§16.3-1 は「耐えない場合」と仮定に触れるだけで、
  上限到達時の挙動 (ユーザーに何を見せるか) と概算コストが無い。
  §13 の O-3 を「BE の責務」で閉じると、**FE-D が新規に作った課金・容量の面が誰も見ていない**状態になる。
- 修正案: FE-Q2 の確認項目に「同時実行上限と実行時間課金の概算」「上限到達時の応答をユーザーに
  どう見せるか (§9 のどの行に落ちるか)」を追加する。

---

## 軽微 (Nice to Have)

1. `:547-549` §11.1 の凡例に **[P]** (プロトタイプにしか根拠が無い) を定義しているが、
   表中で [P] を使っている行が 1 つも無い。「プロトタイプ由来のみの画面は 0 件」なのか
   凡例が余っているのかが読者に分からない。使わないなら凡例から外し、
   プロトタイプ由来の論点は `:579-587` の散文にまとめる旨を書く。
2. `:667` §14 の FE-6 行が担保の SSOT を「testing.md §4.1 `entity/` 行と §4.2」としているが、
   §4.1 は backend の表で、FE の必須ケースは §4.2 の `lib/` 行。参照を §4.2 に絞る。
3. `:461-463` §8.2 が参照する「testing.md §10 の必須テストの存在検査」5 種に FE 版は含まれない
   (重大 4-2 と同根)。§8.2 に「testing.md §10 への追加が必要」の 1 行を添えると読者が誤解しない。
4. `:433` の hex 禁止は `no-restricted-syntax` としているが、ESLint の同ルールは AST セレクタで
   指定する (正規表現単体ではない)。実装リポで詰まらないよう
   「`Literal[value=/#[0-9a-fA-F]{3,8}/]` 相当のセレクタ」と具体化しておくとよい。

---

## 本番観点カバレッジ (frontend.md §13 の自己申告に対する検証結果)

| ID | 状態 | 箇所 / 所見 |
|---|---|---|
| A-1 | **回答あり (条件付き)** | §2 FE-D / §5.2 / §6.3。**ブラウザ直叩きの廃止は v2 の欠陥を実際に解消している**が、①catch-all プロキシの許可リストが無い (重大 3) ②FE-Q2 不成立時の代替が成立未確認 (重大 5) ③401 時の Cookie 破棄と期限の対応が未定 (中 4) |
| A-2 | **不足** | §9 / §11.1 は契約内管理者の 3 画面のみ。**社内管理者経路 (auth.md §6.2 の例外) が欠落** (重大 1)。ロール情報の出所も未定 (中 3) |
| A-3 | 対象外 (理由あり) | §13。FE に所有者列の概念が無い。SSOT は data-model / auth |
| A-4 | 回答あり | §5.4。`scope` は生成型 enum のみ・`account_id` を送る経路を作らない。D-API-8 と整合 |
| A-5 | **回答あり (穴 1 件)** | §9 の 8 ステータス表。auth.md §6.6 と照合一致。**ただし MFA 未検証の遷移先が §11.1 に無い** (重大 2) |
| A-6 | 対象外 (理由あり) | §13。FE はツール実行経路を持たない。architecture.md §3.8.2 へ委譲 |
| A-7 | 回答あり | §5.4 / §11.1。共有 UI は増分 2、増分 1 は導線を出さない (D-API-8' と整合) |
| O-1 | 回答あり | §2 FE-L / §5.2 / §6.3。`X-Request-Id` (ULID) をサーバ側 1 箇所で生成 |
| O-2 | 対象外 (理由あり) | §13。FE は LLM を直接呼ばない |
| O-3 | **部分回答** | §6.3 の切断伝播は妥当。**Vercel 中継の実行時間課金・同時実行上限が未評価** (中 7) |
| O-4 | 回答あり | §6.4 / §9 / §10.1。4 分類が observability §4.3 の F-4 / F-5 と対応。不完全終了を成功に見せない |
| O-5 | 回答あり | §6.4。切断・無通信 45 秒・ローリング更新の 3 経路 + 履歴 GET 復元。自動再接続の却下理由も明示 |
| O-6 | 対象外 (理由あり) | §13 |
| O-7 | 対象外 + 先送り先あり | §13。FE-Q4 の決着後に再検討 |
| D-1 | **回答あり (1 行欠落)** | §12。`API_BASE_URL` のサーバ専用化は妥当。**フラグ環境変数の行が無い** (中 1) |
| D-2 | **不足** | §3.3 / §7.2 / §8.2 / §11.2 / §12 で 5 検査を定義しているが、**雛形に実体が無く testing.md §9 / §10 に登録されていない** (重大 4) |
| D-3 | 参照 (再定義しない) | operations.md §5.1 / §5.4 へ委譲。妥当 |
| D-4〜D-8 | 対象外 + 先送り先あり | §13。FE の責務外として operations / infrastructure を名指し |

**DR パターン**: DR-1 = 出典は全件あり、抜き取り 12 件中 10 件一致 / 2 件不正確 (中 1・中 2)。
DR-2 = §13 に全 ID の表があり無言の省略は無いが、A-2 に**設計対象の抜け**がある (重大 1)。
DR-3 = FE は既存データを持たないため該当なし (v2 → v3 の画面切替順序は operations.md §5.4 へ委譲、妥当)。
DR-4 = PoC 実装のコピーは無い (`lib/` 平置きと `parseSSEBlock` の `.trim()` を明示的に却下)。
DR-5 = 中 3 / 中 4 / 中 5 / 重大 4 に該当箇所あり。DR-6 = 未カバー AC ゼロ。
DR-7 = 根拠列で区分しており**良好** (軽微 1 のみ)。

---

## 良かった点 (3 行)

- V-1〜V-18 / P-1〜P-7 の全事実に出典が付き、**件数の主張には grep 条件まで書かれている** ため
  「SSE 7 ファイル」を含む 12 件の抜き取りが再現できた (DR-1 の懸念はほぼ無い)。
- FE-1〜FE-7 と BE-2/7/10/12 を「構造 / lint / テスト存在検査」に全件割り当て、
  **担保が雛形に無いことを自己申告している** (§16.2-1) — 是正要求として正しい形。
- §0 の SSOT 境界表と §13 の全 ID 表により、他 7 文書との重複定義がほぼ無く、
  対象外には理由と先送り先が付いている (SSOT 違反は中 1 の 1 件のみ)。

---

## 再レビューの条件

**重大 1〜5 の修正後に再レビューが必要**。特に重大 5 (FE-Q2) は、
不成立の場合に §2 FE-D・§6.3・§12・`auth.md`・`plan.md` が連鎖して変わるため、
**FE-Q2 の実測結果を得てから Freeze する**ことを推奨する。

---

## 指摘の反映 (2026-07-30)

**反映対象**: `docs/design/frontend.md` (レビュー時点 806 行 → 反映後 **1251 行**)。
**他文書は編集していない** (`docs/design/` の他ファイル・`templates/`・`aidlc-docs/inception/` への
是正は frontend.md §16.2 の要求として起票した)。
**検証**: `make check` → doc-lint エラー 0 / 警告 50 (frontend.md 由来は FE-Q1〜**Q8** の
`[Answer]` 未回答 8 件のみ) / traceability 46/46 カバー。

### 重大

| # | 反映先 | 内容 |
|---|---|---|
| 重大 1 | **§2 の FE-D' (新規)** / **§11.1** / **§11.3 (新規)** / §3.1 / §5.2.1 / §13 A-2 / §15.3 / §16.3-6・7 | 社内管理者の**5 画面を §11.1 に追加** (`/admin/signin` / `/admin/mfa/setup` / `/admin/mfa` / `/admin/accounts` / `/admin/admins`。すべて増分 1・根拠は `auth.md` §6.2 / §6.9)。**採用案 = 同一アプリの `(admin)` ルートグループ + next-auth とセッション Cookie の分離**、却下案 4 件 (v2 の単一 next-auth / 別 Vercel プロジェクト / UI を作らず curl 運用 / `(app)` にロールで同居)。`X-Admin-Token` は §5.2.1 で **`admin-mutator.ts` 1 ファイルに限定 + grep 検査 (検査 7)** として書き分けた。**新たに発見した衝突を §11.3.2 に起票**: FE-D では ALB が見る送信元 IP が Vercel になるため **`auth.md` §6.2 ③ の WAF IP 許可リストが成立しない** → FE-Q7 + §16.2-7 |
| 重大 2 | **§11.1** / **§11.2.1〜11.2.3** / §1.1 の **V-21 (新規)** / §13 A-5 | `/mfa` と `/mfa/setup` をルート一覧に追加 (`(auth)` グループ)。**許可リストを 4 本に分割** (`PUBLIC_PATHS` / `MFA_PENDING_PATHS` + 管理者用 2 本)、**3 状態 × 到達可能ルートの遷移表**を新設。CI 照合は **`(auth)` ↔ 2 本の和集合** + **`/mfa` 系が `PUBLIC_PATHS` に現れたら落とす** 1 行を追加。v2 の穴は一次ソースで確認して V-21 として出典付きで記録 (`hassan-v2-frontend/src/middleware.ts:39-42` の matcher に `mfa` が含まれる = 未認証でも到達可) |
| 重大 3 | **§6.3.1〜6.3.3 (全面改稿)** / §6.1 の図 / §3.1 / §13 A-1 | catch-all を**廃止**し、**中継対象ごとに Route Handler ファイルを 1 つ置く**方式に変更 (許可リスト = ファイルの存在。定数の更新漏れという失敗形が無い)。**`GET /asset-extractions/{id}/stream` の GET 中継を表に明記** (一次ソース確認: `docs/design/API/assets.md`:63)。却下案 2 件。**§6.3.3 を新設**して `Sec-Fetch-Site` / `Origin` / `Sec-Fetch-Mode` の 3 検査と `SameSite=Lax` 依存案の却下を書いた |
| 重大 4 | **§16.2-1 (全面改稿。7 検査の状況表)** / §3.3 / §7.2 / §8.2 / §14 / §15.1 / §13 D-2 | 「lint zone は `npm run lint` に含まれる」という**誤りを是正**し、経緯 (当時 eslint 設定が 0 件だった / 2026-07-30 にメインセッションが `.eslintrc.json.tmpl` と CI 検査 4 本を追加) を記録。**7 検査それぞれに実体の パス:行 と残作業**を表で確定 (未充足 = tailwind プラグイン 2 ルール・`X-Admin-Token` 局所化検査・L-F4 のドメイン名展開・`check-public-paths.sh` 本体)。**`testing.md` §9 / §10 への登録要求**を 3 項目 (§10 の一覧追加 / §9.1 の段の明記 / §7 E-1 の CORS 記述の陳腐化) として起票。§15.1 の 1 に**引き渡し物 6 件を名前で列挙** |
| 重大 5 | **§16.1 FE-Q2 (全面改稿)** / §2 FE-D 却下 (d) / **§15.1 の第 0 ステップ (新規)** / §12 / §16.2-5 | FE-D の却下 (d) に**「(a) で却下した CORS 問題をそのまま再現する」ことを明記**し矛盾を解消。FE-Q2 に **測ること 4 項目の表** (①5 分の中継可否 ②同時実行上限 ③実行時間課金の概算 ④上限到達時の応答) と、**(d) を採る場合の骨子 5 点** (発行 API・有効期間 60 秒・1 リソース 1 メソッドのスコープ・単回使用・クエリ渡しの帰結) + **未解決の成立条件 (許可オリジンの決め方 2 案。いずれもユーザー決定)** を追記。**「不成立なら (d)」は成立未確認**と明示。**FE-Q2 を §15.1 の第 0 ステップ**(雛形展開より前) に移動。§16.2-5 に **「FE-Q2 が肯定された後に出す」**を前提として付し、§12 の CORS 回答にも条件 2 つを付けた |

### 中

| # | 反映先 | 内容 |
|---|---|---|
| 中 1 | **§12 の環境変数表** / **§16.2-2②** / §16.2-4 / §13 D-1 | ②を「配布方法の確定が必要」から**「雛形の記述が `operations.md` §7.2 OP-I の確定 (FE = Vercel の環境変数・API で配らない) と食い違う」**に差し替え (`CLAUDE.md.tmpl:46-51` を一次ソースで確認。`GET /api/features` の例示は既に削除済み = 指摘②前半は解消済みと記録)。§12 の表に **`FEATURE_<機能名>` の行**を追加し、**`NEXT_PUBLIC_` を付けない / 判定は Server Component** と許可リスト検査との整合を明記。§16.2-4 に OP-I 側への 1 行追記要求を起票 |
| 中 2 | **§0 の ID 型の表 (新規)** | 「`bigint` = number」を**3 種類の表**に差し替え (機能リソース = `number` / アカウント・契約 = `string` (uuid) / 外部 CMS の `news_id` = `string` (text))。**ルートパラメータは常に string** であることと、変換を 1 つの純粋関数に閉じ `Number.isSafeInteger` で検証する規約、`uuid`/`text` を `Number()` に通さない禁止、却下案を追記 (出典: `data-model.md` DM-1 / §4.1.1 / F-15) |
| 中 3 | **§5.2.2 (新規)** / §13 A-2 / §16.2-6① | 表示用の最小属性 (`role` / `requiredMfaType` / `mfaVerified` / `accountId`) の**出所を「サインイン応答 → next-auth の User → jwt/session コールバック → セッション」の 1 経路に固定**。v2 が `requiredMfaType` に対して既に採っている形を出典付きで示し (`hassan-v2-frontend/src/lib/auth.ts:49-57` / `:134-153`)、**v2 の応答に `role` が無い**ことを確認して **Task-3i への是正要求 (§16.2-6①)** を起票。JWT 復号 / 403 後に隠す / me API の 3 案を却下 |
| 中 4 | **§5.2.3 (新規)** / §5.2 の責務 7 / §9 の 401 行 | 破棄経路を **`app/api/logout/route.ts` の 1 本**に固定 (Server Component / Server Action / Route Handler それぞれの動きを明記。`signOut()` は明示サインアウト専用)。**`/api/logout` を 2 本の許可リスト両方に載せる**ことを明記。**`session.maxAge` = BE の JWT 期限 7 日に一致**させる規約と、ずれた場合の帰結 (全リクエスト 401) を追記 (`auth.md` §6.9-3 が SSOT) |
| 中 5 | **§6.2 の S-9 (新規)** / §16.1 FE-Q1 / §16.2-3② | 汎用形の payload を **`unknown` 固定**、narrow は `decode-event.ts` のみ、`as` を書かない (雛形 eslint が既に `as` を禁止) の 3 点を規約化。**「会話 API の設計 Task を plan.md に追加する」是正要求**を §16.2-3② としてイベント名一覧の要求と同じ項目に起票 |
| 中 6 | **§6.3.1 の表** | 「BE のエンドポイント × メソッド × Route Handler のパス × 対応画面 × 増分」の表で重大 3 の許可リストと兼ねた (会話は FE-Q1 待ちとして行に残した) |
| 中 7 | **§16.1 FE-Q2 の測る項目 ②③④** / **§9 に 1 行追加** / §13 O-3 | Vercel の同時実行上限・実行時間課金の概算を FE-Q2 の実測項目に追加。**上限到達時の画面**を §9 の表に 1 行として追加 (開始前 = 通信失敗の行と同じ / 開始後 = `failed` + `disconnected` で再接続導線)。§13 の O-3 を「BE の責務」で閉じず、**Vercel 側の課金・容量は本書の担当**と明記 |

### 軽微

| # | 反映先 | 内容 |
|---|---|---|
| 軽微 1 | §11.1 の凡例 | **[P] を凡例から削除**し、「プロトタイプにしか根拠が無い画面は 1 件も無い」「プロトタイプ由来の論点は表ではなく下の散文にまとめる」を明記 |
| 軽微 2 | §14 の FE-6 行 | 参照を **`testing.md` §4.2 の `lib/` 行**に絞り、「§4.1 は backend の表なので参照しない」と明記 |
| 軽微 3 | §8.2 | 「`testing.md` §10 の 5 種は 5 件すべて backend であり FE の検査が無い」ことと、**§16.2-1 の登録要求**への参照を追記 |
| 軽微 4 | §7.2 の表 | hex 禁止を **AST セレクタ `Literal[value=/^#[0-9a-fA-F]{3,8}$/]`** に具体化 (雛形の実装 `:31-34` を参照)。`style` 属性禁止も `react/forbid-dom-props` から **`JSXAttribute[name.name='style']`** に変更し、プラグインを増やさない理由と**検出できない限界** (テンプレートリテラル内 / CSS ファイル内) を明記 |

### 反映に伴って新規に起票したもの (レビュー指摘に無いが、反映の結果として必要になった)

| 種別 | 内容 |
|---|---|
| `[Answer]` **FE-Q7** | 社内管理者経路の **WAF IP 制限**をどうするか (§11.3.2。暫定既定 = MFA + レート制限 + 監査で担保し IP 制限は諦める。選択肢 = Vercel 固定 egress IP / ALB 配下配信) |
| `[Answer]` **FE-Q8** | **管理者セッションの寿命** (BE の管理者トークン有効期間が `auth.md` に無い。Task-3i で決める) |
| 是正要求 **§16.2-6** | `plan.md` Task-3i へ 3 件 (`POST /signin` の応答に `role` / 管理者 4 機能の入出力仕様 / 管理者トークンの有効期間) |
| 是正要求 **§16.2-7** | `auth.md` §6.2 / `infrastructure.md` INF-L へ — WAF IP 制限が FE-D と両立しない点の是正 |
| 是正要求 **§16.2-5 の後半** | `infrastructure.md` §3.3 の **S3 CORS** は「FE がブラウザから presigned URL を直接開く」前提で必要である旨の確定 (§12 末尾に FE 側の回答を記載) |
| 事実の追加 | **V-19 / V-20 / V-21** (v2 の管理者 UI 同居と単一セッション / 両ヘッダ同値の構造的原因 / `/mfa` が未認証に開いている) を一次ソースで確認して §1.1 に追記。§1.3 に継承可否 2 行を追加 |
| 仮定の追加 | §16.3 に **6 (管理者 UI は本 FE の対象)** / **7 (同一アプリに next-auth を 2 系統マウントできる — 未検証。不可なら自前 Cookie 実装か別アプリ)** |

### 未反映 (0 件)

**16 件すべてに対応した**。ただし次の 2 件は**設計上「未解決」として明示した**ものであり、
反映は「決着」ではない:

- **重大 5 / FE-Q2**: 実測前。**§15.1 の第 0 ステップで確定させる**。不成立時の代替 (d) は
  CORS の成立条件が未解決であり、**ユーザー決定を要する**と明記した
- **重大 1 の派生 / FE-Q7**: WAF IP 制限は `auth.md` の決定を弱めるため、**FE 側だけで確定させない**

### 再レビュー時に見てほしい点 (起草者からの申し送り)

1. **§11.3 の管理者 UI を本 FE に含める判断**が妥当か (却下 (b) 別アプリの方が良いという判断もあり得る)
2. **§6.3.3 の 3 検査**が過剰・不足でないか (`Sec-Fetch-*` 前提で curl も弾く方針を採った)
3. **§11.2.2 の 3 状態遷移表**の 302 先が、Task-3i の認証 API 仕様と矛盾しないか


---

## 雛形側の機構追加 (2026-07-30・メインセッション)

重大 4 (FE-3 / FE-4 / FE-5 / FE-6 の担保が実体ゼロ) の**根本**は「雛形に eslint 設定が 1 つも無い」ことだった。
`frontend.md` 側の記述是正は別セッションが行ったので、**機構はメインセッションが追加した**:

| 追加物 | 内容 |
|---|---|
| **`templates/frontend-repo/.eslintrc.json.tmpl` (新規)** | L-F1〜L-F6 の依存 zone (`import/no-restricted-paths` + `no-restricted-imports`) / **生 hex と `style` 属性の禁止** (FE-3) / `fetch` の直呼び禁止 (L-F5) / **`tailwindcss/no-arbitrary-value` + `no-custom-classname`** / **`X-Admin-Token` を `lib/api/admin-mutator.ts` 以外で禁止** (FE-D')。v2 の 5 ルール (no-console / consistent-type-imports / unused-imports / `as` 禁止) は踏襲 |
| **`templates/frontend-repo/.github/workflows/ci.yml`** | 検査 4 本を追加 — ①併置テストの存在 (FE-4 / FE-6) ②公開パス許可リストと `(auth)` の照合 (FE-K。`PUBLIC_PATHS` の不在と `check-public-paths.sh` 未実装で `exit 1`) ③`NEXT_PUBLIC_` 許可リスト (A-1) ④`globals.css` の行数可視化 (ブロックしない) |
| **`templates/README.md`** | 立ち上げ手順に「`.eslintrc.json.tmpl` を `.eslintrc.json` にリネームし zone と許可リストを実構成に合わせる」を追記 |

**この作業中にメインセッションが自分の欠陥を 1 件検出して修正した**:
eslint の `overrides` における `no-restricted-syntax` は**マージではなく上書き**であるため、
`src/**` に `X-Admin-Token` 禁止を足した時点で**基底の 3 セレクタ (as / hex / `style`) が src 配下全体で無効化される**
状態だった。基底セレクタを各 override に再掲する形へ修正し、`src/styles/**` は
**hex だけを許可 (他の禁止は維持)** に改めた (ルール全体を `off` にすると他の禁止まで消える)。

これにより **§16.2-1 の 7 検査すべてに機構が入った**。残るのは実装リポで用意するスクリプト
(`check-public-paths.sh`) と `testing.md` §9 / §10 への登録である。

---

## 2 巡目 (確認・2026-07-30)

**モード**: 1 巡目の指摘 16 件の解消判定 + 回帰検査に限定 (新規の網羅レビューは行っていない)。

**レビューした成果物 (リポジトリ相対パス)**:

- `docs/design/frontend.md` (主対象。1251 行)
- `templates/frontend-repo/.eslintrc.json.tmpl` (新規・付随確認)
- `templates/frontend-repo/.github/workflows/ci.yml` (付随確認)
- `docs/design/testing.md` §9.1.1 / §10 / §13.3-11 (付随確認)

**実行した検証**:

```
$ make check
[doc-lint] 対象 85 ファイル / エラー 0 件 / 警告 51 件
  (frontend.md 由来は :1063 / :1098 / :1107 / :1116 / :1121 / :1127 / :1140 / :1149 の
   未回答 [Answer] 8 件のみ = FE-Q1〜FE-Q8 が消えていないことを機械確認)
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 47/47 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
[workflow-shell] 検査 52 ブロック / エラー 0 件
```

```
$ python3 (json.loads + セレクタ数の実測) templates/frontend-repo/.eslintrc.json.tmpl
JSON parse OK
base rules.no-restricted-syntax: 3 (as / hex / style)
override[0] files=[src/lib/**, src/features/*/lib/**]            rules=[no-restricted-imports]
override[1] files=[src/features/*/components/**, src/app/**]     rules=[no-restricted-globals]
override[2] files=[src/features/**]                              rules=[no-restricted-imports]
override[3] files=[src/**] excluded=[src/lib/api/admin-mutator.ts]
                                                                 no-restricted-syntax: 5 (as / hex / style / X-Admin-Token ×2)
override[4] files=[src/styles/**, tailwind.config.ts|js]          no-restricted-syntax: 4 (as / style / X-Admin-Token ×2)
override[5] files=[src/generated/**]                             rules={}
```

**抜き取り照合 6 件 (指示どおり 6 件で打ち切り)**:

| # | 照合対象 | 結果 |
|---|---|---|
| 1 | `.eslintrc.json.tmpl` の override 構造とセレクタ数 (上記 python 実測) | **一致** — `src/**` に基底 3 セレクタが再掲され (計 5)、`src/styles/**` は hex のみ落とし他 4 つを維持。override 順も styles が後で hex 許可が効く |
| 2 | `ci.yml` の検査 4 本の行範囲 (`:58-72` / `:73-98` / `:99-118` / `:119-129`) | **一致** |
| 3 | `.eslintrc.json.tmpl` の hex `:46` / `style` `:50` / zone `:55` / tailwind `:30`〜`:38` | **一致**。ただし frontend.md §14 の `:31-38` は **hex/style ではなく `no-custom-classname` の行** (下記 中 1) |
| 4 | `testing.md` §9.1.1 の F-C1〜F-C7 と §10 の 6 番 | **一致** (7 検査の集合・順序・実体パスが frontend.md §16.2-1 と同一)。ただし §9.1.1 の箇条書き `:570-575` と §13.3-11 が frontend.md の**旧記述**を指したまま (下記 中 4) |
| 5 | `hassan-v2-frontend/src/middleware.ts:39-42` (V-21 = matcher に `mfa` が含まれ未認証で到達可) | **一致** (`:41` の否定正規表現に `mfa` が含まれる。middleware 本体 `:29` は `token.requiredMfaType !== 'totp'` 判定) |
| 6 | `hassan-v2-frontend/src/lib/auth.ts:49-57` (サインイン応答に `role` が無い) / `:17-27` (`sameSite: 'lax'`) | **一致** (`User` は `token`/`email`/`uuid`/`companyName`/`requiredMfaType`/`mfaEnabled` の 6 項目で `role` 無し) |

**追加 1 件 (6 件の枠外。重大 1 の判定を左右するため実施)**: `docs/design/auth.md` §6.9 の
手動ロック / 解除 API の「実行者の 2 経路」表 — 契約内管理者の用途は **「漏洩時の遮断・失敗ロックの解除」**
であり、**ロック操作を持つ**。frontend.md 側にロック実行の導線が無い (下記 新規重大 1)。

**対象外とした範囲**: §4 (状態管理) / §6.2 (S-1〜S-9) / §7.1 (トークン体系) / §9 / §10 / §12 の
本文は 1 巡目で指摘が無かったため、参照整合のみ見て内容の再レビューはしていない。

---

### 解消判定表

| 1 巡目 | 判定 | 根拠 |
|---|---|---|
| **重大 1** (社内管理者 5 画面 / `X-Admin-Token` / 即時失効) | **部分解消** | 5 画面が §11.1 に入り `(admin)` グループ・別 Cookie・別 next-auth・却下案 4 件が §11.3 / FE-D' に揃った。`X-Admin-Token` は §5.2 責務 1 で「送らない」+ §5.2.1 で `admin-mutator.ts` 1 ファイルに限定と書き分けられ、eslint でも機械化済み。**未解消: auth.md §6.9-2 の「トークン漏洩時に即座に遮断する」を成立させる「ロックする」UI が無い** (新規重大 1) |
| **重大 2** (`/mfa` 系のルート定義と許可リスト) | **解消 (設計)** / **CI は部分** | `/mfa` `/mfa/setup` が §11.1 に定義され、許可リストは 4 本 (`PUBLIC_PATHS` / `MFA_PENDING_PATHS` / `ADMIN_*` 2 本)、§11.2.2 に 3 状態 × 到達可能ルートの遷移表、§11.2.3 に「`/mfa` が `PUBLIC_PATHS` に現れたら落とす」1 行。**CI の初日成立は部分** — 雛形が存在を確認するのは `PUBLIC_PATHS` 1 本のみ (新規中 3) |
| **重大 3** (中継 Route Handler の catch-all) | **解消** | §6.3.1 で catch-all を廃止し「中継対象ごとに 1 ファイル = 許可リストはファイルの存在」に変更。**GET 中継 (`GET /asset-extractions/{id}/stream`) が表の 1 行目に明記**。却下 2 件 + §6.3.3 の `Sec-Fetch-Site` / `Origin` / `Sec-Fetch-Mode` 3 検査と `SameSite=Lax` 依存案の却下も追加 |
| **重大 4** (7 検査の実装状況の記述) | **部分解消** | §16.2-1 の 7 検査表の**行番号は実測と一致** (照合 2・3)。**未解消 4 点**: ①§14 FE-3 の `:31-38` が誤り ②§15.1 の 1-b / 1-e / 1-f が §16.2-1・§11.2.1 と矛盾 ③検査 7 の「逆向きの検査」が雛形に無いのに「残作業なし」 ④testing.md への登録が完了済みなのに「未登録・要求中」の記述が 4 箇所 (中 1・中 2・中 4) |
| **重大 5** (FE-Q2 の実測条件と不成立時の分岐) | **解消** | 測ること 4 項目の表 (測り方・判定つき)、(d) の骨子 5 点、**CORS の成立条件が未解決でユーザー決定を要する**旨、`§15.1` の第 0 ステップ化、FE-D 却下 (d) への「(a) の CORS 問題を再現する」明記。**「不成立なら (d)」を成立済みの代替として書いていない**点が正しい |
| 中 1 (フラグ環境変数) | 解消 | §12 に `FEATURE_<機能名>` の行 + `NEXT_PUBLIC_` を付けない + 判定は Server Component。§16.2-4 に OP-I 側への追記要求 |
| 中 2 (ID 型) | 解消 | §0 に 3 種類の表 (`number` / uuid=string / text=string)、ルートパラメータは常に string、`Number.isSafeInteger` 検証、却下案 |
| 中 3 (ロールの出所) | 解消 | §5.2.2 で 1 経路に固定 + v2 に `role` が無いことを一次ソースで確認 (照合 6) + 是正要求 §16.2-6① + 却下 3 案 |
| 中 4 (401 後のセッション破棄) | 解消 | §5.2.3 で `/api/logout` 1 本に固定、3 箇所からの呼び方、`signOut()` の用途限定、2 本の許可リスト両方に載せる、`maxAge` = 7 日 |
| 中 5 (SSE 汎用形の型) | 解消 | §6.2 S-9 (`unknown` 固定 / narrow は `decode-event.ts` のみ / `as` 禁止) + §16.2-3② |
| 中 6 (中継の対応表) | 解消 | §6.3.1 の表が許可リストと兼用 |
| 中 7 (Vercel の上限・課金) | 解消 | FE-Q2 の②③④ + §9 に上限到達時の行 + §13 O-3 に「Vercel 側は本書の担当」 |
| 軽微 1 (DR-7 の [P]) | 解消 | §11.1 の凡例から [P] を削除し「プロトタイプにしか根拠が無い画面は 1 件も無い」+ 散文への切り分け。全行が [API] か [未確定] (Task-3i) |
| 軽微 2 (testing.md の参照節) | 解消 | §14 FE-6 が「§4.2 の `lib/` 行」に限定 |
| 軽微 3 (§10 の 5 種が backend のみ) | **解消済みだが記述が陳腐化** | 追記自体はあるが、testing.md 側が既に登録済み (中 4) |
| 軽微 4 (hex/`style` の AST セレクタ) | 解消 | §7.2 が `Literal[value=/^#[0-9a-fA-F]{3,8}$/]` / `JSXAttribute[name.name='style']` に具体化 + 検出できない限界の明示。`:30〜33` の行参照だけ微ズレ (実際は `:31〜38` が `no-custom-classname`) |

**DR-5 (曖昧語)**: 曖昧語 4 種 (「適切に」「必要に応じて」「後で検討」+ 未確定マーカー) の grep → **0 件**。
**[Answer]**: FE-Q1〜FE-Q8 の 8 件すべて未回答のまま維持 (doc-lint で機械確認)。
**DR-7**: 維持されている (§11.1 の根拠列 + 「上表に無い操作は実装対象ではない」+ §16.3-5)。

---

### 新規重大 (Must Fix)

#### 新規重大 1. `docs/design/frontend.md:753` / `:757` / `:841-843` — アカウントを**ロックする** UI が無く、auth.md §6.9 の「即時遮断」が製品内で成立しない

`auth.md` §6.9 は「実行者の 2 経路」表で **契約内管理者の用途を「通常運用 (漏洩時の遮断・失敗ロックの解除)」**
と定め、社内管理者経路を **「解除専用」** と明記している (「回復手段がロックアウト手段を兼ねない」)。
同節の採用 2 は「手動ロック API を新設し、**『トークン漏洩時に即座に遮断する』手段を成立させる**」である。

frontend.md 側の記述は:

- `:753` `/settings/members` = 「**ロック状態の表示と解除**を含む」
- `:757` `/admin/accounts` = 「ロック状態表示 + **ロック解除** (解除専用)」
- `:841-843` §11.3 の「なぜ FE に必要か」も **ロック解除に到達できる UI** のみを論じている

`grep -n "ロック" docs/design/frontend.md` の全 20 行を見ても、**ロックを実行する導線は 1 箇所も無い**。

**本番で何が起きるか**: JWT は 7 日有効・リフレッシュなしで、失効手段は `last_locked_at` を立てる
手動ロックだけである (`auth.md` §6.9 / §1.3 判定 7)。ロック操作の UI が無ければ、漏洩を検知しても
**製品内に遮断手段が存在せず、DB 直操作か API 直叩きに戻る** — これは FE-D' の却下 (c) が
「常設の回復手段にしない」として却下した形そのものである。加えて `auth.md` §6.9 は
「自分自身のロック禁止 (403)」「最後の契約内管理者のロック拒否 (403)」「ロック時の監査記録」を
決めており、**これらは UI 側の確認ダイアログ・エラー表示・403 のインライン表示を伴う**。

**修正案**: `§11.1` の `/settings/members` 行を「ロック状態の表示・**ロック**・解除」に改め、
`§9` の 403 表に「自分自身のロック / 最後の契約内管理者のロックは 403 をインライン表示」を 1 行加える。
`§11.3` の「なぜ FE に必要か」は解除 (回復) 側の論拠なので変更不要。
併せて `§16.2-6`②(Task-3i への要求) に **ロック API の入出力**を含める
(`auth.md` §10.2 R-3 が対象に含んでいるかを確認のうえ)。

#### 新規重大 2. `templates/frontend-repo/.eslintrc.json.tmpl:88-121` / `:141-161` — `no-restricted-imports` に**同じ「override は上書き」欠陥が残っており**、`src/features/*/lib/**` で FE-5 の担保 (react / next 禁止) が消える

メインセッションが `no-restricted-syntax` について自己検出・修正した欠陥
(「overrides の同ルールはマージではなく上書き」) が、**`no-restricted-imports` では未修正**である。

- `override[0]` (`:88-121`) = L-F1: `files: ["src/lib/**", "src/features/*/lib/**"]` に
  `no-restricted-imports` で `react` / `react-dom` / `next` / `next/*` を禁止
- `override[2]` (`:141-161`) = L-F4: `files: ["src/features/**/*.{ts,tsx}"]` に
  **同じ `no-restricted-imports`** で `@/features/*/!(types)` を禁止

`src/features/theme/lib/foo.ts` は**両方の `files` にマッチ**し、ESLint は後勝ちで
**`override[2]` の設定が `override[0]` を置き換える** — 結果 `src/features/*/lib/**` では
**`react` / `next` の import が許可される**。

**本番で何が起きるか**: FE-5 は PoC で**実際に起きた**パターンで、`feedback_review_patterns.md` は
「設計でその余地を無くす」ことを要求している。`frontend.md` §3.3 の L-F1 は
「`src/lib/**` **と** `src/features/*/lib/**` から react / next を import しない」と定義しており、
**設計と雛形が不一致**。しかも §14 FE-5 行と `testing.md` §9.1.1 の F-C1 は
「実装済み・PR の必須チェック ✓」と宣言しているため、**担保されていない検査が担保済みとして記録される**
(1 巡目の重大 4 と同じ失敗形の再発)。

**修正案** (順序変更では解けない — L-F4 の対象が `features/**` 全体であるため、
`override[0]` を後ろに移すと今度は `features/*/lib` で L-F4 が消える):
①`override[2]` の `no-restricted-imports` に react / react-dom / next の `paths` / `patterns` を**再掲**する
(`no-restricted-syntax` で採った再掲方式と同じ)、または
②L-F1 を `no-restricted-imports` ではなく `import/no-restricted-paths` の zone
(`target: ./src/lib` / `./src/features/*/lib`, `from` = 外部モジュール不可のため不適) ではなく
**`no-restricted-syntax` の `ImportDeclaration[source.value=/^(react|react-dom|next)/]` セレクタ**に移し、
基底 + 各 override 再掲の一元管理にそろえる。
**併せて `frontend.md` §14 FE-5 と `testing.md` §9.1.1 F-C1 の「実装済み」判定を修正するまで
7 検査を「機構が入った」と書かない**。

---

### 新規中 (Should Fix)

#### 中 1. `docs/design/frontend.md:973` — §14 FE-3 の行参照 `.eslintrc.json.tmpl:31-38` が誤り (hex/`style` は `:45-52`)

`:31-38` は `tailwindcss/no-custom-classname` のブロックである (実測)。hex は `:45-48`、
`style` 属性は `:49-52`。§7.2 (`:46`〜 / `:50`〜) と §16.2-1 (`:46`〜 / `:50`〜) は正しいので、
**同一事実に 2 つの異なる出典が併存している** (DR-1)。§7.2 の `:30〜33`
(トークン外クラス禁止) も実際は `:31〜38` で 1 行ずれている。
`testing.md` §9.1.1 の F-C2 が実測値を持っているので、そこに合わせるのが最短。

#### 中 2. `docs/design/frontend.md:1005` / `:1008` / `:1009` — §15.1 の引き渡し物リストが §16.2-1・§11.2.1 と矛盾 (3 箇所 stale)

| 箇所 | 記述 | 現状 |
|---|---|---|
| `:1005` (1-b) | 「`eslint-plugin-tailwindcss` の `no-arbitrary-value` / `no-custom-classname` を**追加する**」 | ルールは雛形 `:30-38` に**既にある**。残作業は **npm 依存の追加** (§16.2-1 検査 2 はこちらを書いている) |
| `:1008` (1-e) | 「`X-Admin-Token` の局所化検査 (**雛形に無い**)」 | §5.2.1 と §16.2-1 検査 7 は「**実装済み・残作業なし**」 |
| `:1009` (1-f) | 「`middleware.ts` の **2 本**の許可リスト定数 (`PUBLIC_PATHS` / `MFA_PENDING_PATHS`)」 | §11.2.1 は **4 本** (`ADMIN_PUBLIC_PATHS` / `ADMIN_MFA_PENDING_PATHS` を含む) |

`§15.1` は**実装リポへの引き渡し指示そのもの**であり、ここが古いと
「管理者用の許可リスト 2 本が作られない」「すでにある検査を二重に作る」形で実装リポに伝播する。

#### 中 3. `templates/frontend-repo/.github/workflows/ci.yml:84` / `docs/design/frontend.md:1007` — 公開パス照合 (F-C4) の受入条件が雛形にもスクリプト要求にも落ちていない

雛形の検査 2 が存在を確認するのは `ALLOWLIST_NAME="PUBLIC_PATHS"` の **1 本のみ**。
§11.2.3 が要求する ①`(auth)` ↔ 2 本の和集合 ②`(admin)` ↔ 管理者 2 本の和集合
③**`/mfa` で始まるパスが `PUBLIC_PATHS` に現れたら落とす** は、いずれも
未実装の `scripts/check-public-paths.sh` 側に委ねられている。ところが
`§15.1` の 1-d は「§11.2.3 の照合」とだけ書き、`§16.2-1` 検査 4 の残作業も
「2 本の許可リストを区別したまま照合する」までで、**管理者 2 本と `/mfa` 検査が受入条件に現れない**。

**本番で何が起きるか**: v2 の V-21 (未認証で `/mfa` に到達) を塞ぐ**唯一の機械検査**が ③ である。
スクリプトの受入条件に書かれていなければ、実装リポは「CI を緑にする最小の実装」を書く。
**修正案**: §15.1 の 1-d に上記 ①②③ を検査項目として列挙し、雛形 `ci.yml:84` の存在確認を
4 本 (少なくとも `MFA_PENDING_PATHS` を含む) に広げる。

#### 中 4. `docs/design/frontend.md:625-629` / `:959` / `:974` / `:1172-1179` — `testing.md` への登録は**既に完了している**のに「未登録・要求中」の記述が 4 箇所残る (相互 stale)

`testing.md` は §9.1.1 に F-C1〜F-C7 を登録し (`:546-580`)、§10 の必須テスト存在検査を
**6 種**に増やして 6 番を FE の併置テスト検査にしている (`:643` / `:101` の T-N も「6 種」に更新済み)。
一方 frontend.md は:

- `:625-629` §8.2「§10 の**必須テストの存在検査 5 種**に本検査は含まれていない」→ 6 種に登録済み
- `:959` §13 D-2「同書に登録する是正要求を §16.2-1 に出した」→ 対応済み
- `:974` §14 FE-4「**testing.md §10 への登録は未了**」→ 完了
- `:1172-1179` §16.2-1 の要求①②③ → ①② は反映済み

逆方向も stale: `testing.md:570-575` と `:844` (§13.3-11) は
**「frontend.md §16.2-1 は `no-custom-classname` を未設定・F-C7 を未実装と書いている」**
と述べているが、frontend.md は既に両方「実装済み」に更新済みである。
**どちらの文書を読んでも相手の状態を誤って知る**状態で、DR-1 の逆流形。
frontend.md 側 4 箇所と testing.md 側 2 箇所を同じ増分で消すこと (SSOT は testing.md §9.1.1)。

#### 中 5. `docs/design/frontend.md:348-349` / `:1170` — 「`admin-mutator.ts` を import できるのは `features/admin/**` だけ」の逆向き検査が雛形に無いのに検査 7 が「残作業なし」

§5.2.1 は 3 つ目の箇条書きで **逆向きの検査 (import 元の限定)** を要求しているが、
雛形の eslint には `X-Admin-Token` 文字列の禁止 (`:186-192` / `:215-221`) しかなく、
`src/lib/api/admin-mutator.ts` は `lib/` にあるため **どの feature からでも import できる**
(L-F4 の `@/features/*/!(types)` は features 間の import しか見ない)。
`§16.2-1` 検査 7 の「残作業なし」は**前半 (文字列の局所化) のみ**についての判定である。

**修正案**: 検査 7 の残作業に「import 元の限定 (`import/no-restricted-paths` の zone:
`target: ./src` / `from: ./src/lib/api/admin-mutator.ts` の except に `features/admin` を置く形は
`except` が `from` 配下でないため成立しない → `no-restricted-imports` の override で
`src/features/!(admin)/**` から禁止する) を実装リポで入れる」を明記する。

#### 中 6. `templates/frontend-repo/.eslintrc.json.tmpl:72-83` — L-F6 zone の `except` が `from` の外を指しており、ルール自体が config エラーになる可能性 (**確信度: 中。要確認**)

zone は `target: "./src"` / `from: "./src/generated"` / `except: ["../features/*/api", …]` である。
`eslint-plugin-import` の `no-restricted-paths` は **`except` を `from` からの相対パスとして解決し、
`from` の子孫であることを要求する** (満たさない場合
`Restricted path exceptions must be descendants of the configured from path` を報告する)。
`../features/*/api` は `./src/generated` の外なので、この条件を満たさない。
**そうなると L-F6 だけでなく `import/no-restricted-paths` 全体が毎ファイルでエラーを出す** —
L-F2 / L-F3 も同じルールの中にあるため、雛形の zone 検査が「常に赤」になって
最初に無効化される候補になる。

雛形にコメント「zones の from/target はコピー後の実ディレクトリ構成に合わせて確認する」があるので
一部は申し送られているが、**方向 (import する側を except に書けない) は構成の違いではなく仕様**である。
**修正案**: `except` を使わず、`no-restricted-imports` の override
(`files: ["src/**"]` から `@/generated/*` を禁止し、`features/*/api` 等の override で解除) に寄せるか、
`from` 側を分割した複数 zone にする。**プラグインのバージョンで挙動を確認してから確定すること**。

---

### 回帰検査の結果

| 観点 | 結果 |
|---|---|
| `make check` | **エラー 0**。frontend.md 由来の警告は [Answer] 8 件のみ (意図どおり) |
| `[Answer]` FE-Q1〜FE-Q8 | **8 件すべて維持** (新規の FE-Q7 / FE-Q8 を含む) |
| 7 検査の同定 (frontend.md §16.2-1 ↔ testing.md §9.1.1) | **件数・順序・実体パスが一致** (F-C1〜F-C7)。段の割り当て (F-C3 = U / 他 = C) も矛盾なし |
| SSOT 重複 | 新規の重複定義は無い。§0 の SSOT 境界表と §13 の全 ID 表は維持 |
| stale の新規発生 | **6 箇所** (中 1 / 中 2 の 3 箇所 / 中 4 の frontend.md 側 4 箇所 = 実質 8 行) — **3 回の更新 (別セッション → メイン → 別セッション) の間で `§14` と `§15.1` が取り残された**のが原因 |
| DR-5 (曖昧語) | 0 件 |
| DR-7 (プロトタイプ) | 維持 (§11.1 の凡例・散文・§16.3-5) |
| DR-4 (PoC のコピー設計) | 新規発生なし (PoC 参照は「踏襲する部分と採らない部分」の形を維持) |

---

### Freeze 可否

**不可**。**新規重大 2 件**の修正後に 3 巡目 (差分のみの軽量確認) が必要。

- **新規重大 1** (ロック UI の欠落) は `frontend.md` §11.1 の 1 行 + §9 の 1 行 + §16.2-6② への追記で閉じる。
  ただし **auth.md §6.9 の決定を UI 側で成立させる話**なので、`§16.2-6` の Task-3i 要求に
  「ロック API の入出力」が含まれることを確認すること
- **新規重大 2** (`no-restricted-imports` の上書き) は雛形 1 ファイルの修正 + `frontend.md` §14 FE-5 /
  `testing.md` §9.1.1 F-C1 の判定文の修正。**「7 検査すべてに機構が入った」という §13 D-2 の記述は
  現時点では正しくない**
- 中 1〜中 6 は Freeze の阻害要因ではないが、**中 2 (§15.1) と中 4 (相互 stale) は
  実装リポへ誤った状態が伝播する**ため、重大 2 件と同じ増分で消すことを推奨する
- 1 巡目の再レビュー条件だった **FE-Q2 の実測前に Freeze しない**方針は維持されており、
  §15.1 の第 0 ステップ化で手順に落ちている (この点は 1 巡目の懸念が解消している)


---

## 2 巡目指摘の反映 (2026-07-30・メインセッション)

| 指摘 | 反映先 | 内容 |
|---|---|---|
| **重大 1 (ロック実行 UI が無い)** | `docs/design/frontend.md` §11.1 の `/settings/members` 行 + 直後の「ロック操作の UI 要件」節 (新設) | `auth.md` §6.9 は実行者 2 経路のうち**契約内管理者がロックを実行する**と定めているのに、FE の画面一覧に**ロックの実行がなく解除だけ**だった (社内管理者の `/admin/accounts` は解除専用なので、**製品内に即時遮断手段が存在しない**状態)。行を「手動ロック / 解除 / ロック状態の表示」に改め、**UI 要件 3 点**を追記 — ①「最後の契約内管理者」「自分自身」の 403 は**正常系**なので操作前の無効化 + 理由表示で表現する ②確認ダイアログを必須にする ③ロック状態を一覧に常時表示する (BE-10 の読む側) |
| **重大 2 (`no-restricted-imports` の override 上書き)** | `templates/frontend-repo/.eslintrc.json.tmpl` | 指摘どおり再現。`src/features/*/lib/**` は L-F4 の override が後勝ちで L-F1 を置き換え、**react / next の import 禁止 (FE-5 の担保) が消えていた**。**`src/features/*/lib/**` 専用の override を新設し L-F1 と L-F4 の両方を再掲**した (`src/lib/**` の override は `src/lib` のみに限定)。JSON パースと 3 override のセレクタ数を機械確認 |
| **重大 4 の残り (§14 / §15.1 の stale)** | `docs/design/frontend.md` §14 FE-5 / `docs/design/testing.md` の F-C1 行 | 「実装済み ✓」と宣言していたが上記の欠陥で**未担保だった**ため、両文書の判定文を実測値 (override の行番号と再掲の事実) へ更新 |

**プロセス側の是正**: `.claude/rules/06-delegation-prompts.md` に
「**機構を直したら、その機構を語る文書を同じ差分で直す**」節を追加 (詳細は review-testing.md の同節)。
