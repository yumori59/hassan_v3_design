# レビュー (3 巡目): 増分 conversation (Task-3p) — C-16 前倒しの波及、2 巡目指摘の反映差分

> レビュー日: 2026-08-03 / レビュアー: `design-reviewer` (第三者セッション。1・2 巡目とは別セッション)
> 対象: 2 巡目 ([review-conversation-r2.md](review-conversation-r2.md)) §10「Freeze 可にするための最小の修正」項目 1〜7 の**実物**と、
> 2026-08-03 に別セッションが行った 3 箇所の是正の整合性。**判定基準は本番基準** (`.claude/rules/08-production-gates.md`)
> 前提: **1 巡目・2 巡目とも「実施済み」の自己申告から重大指摘が出ている**。本巡も申告文を読まず、宛先ファイルを開いて実物のみで判定した

## レビュー結果サマリ

- **重大: 7 件 / 中: 8 件 / 軽微: 5 件**
- **Design Freeze: 不可 (Blocked)**。2 巡目より**悪化はしていないが、質が変わった** —
  本巡の重大 7 件のうち **6 件は 2 巡目が Freeze 条件として名指しした箇所そのもの**であり、
  **残り 1 件 (R3-1) は上流の `requirements.md` の確定決定が設計に 1 箇所も届いていない**という、
  2 巡目より上流の断絶である
- 実行した検証:
  - **2 巡目 §10 の 7 項目の実物照合** (完全実施 3 / **部分実施 3** / **未実施 1**)
  - 2026-08-03 の 3 箇所の是正の独立検証 (**3 件とも実物を確認。ただし 2 件に副作用**)
  - `make check` (**5 ゲート・エラー 0**)
  - 一次ソースの抜き取り照合 **7 件** (v2 backend。うち 4 件は本巡の結論を左右する load-bearing)
  - **2 巡目が提示した再検査手順 (`grep -rn "増分 2"`) の検出力の検証** → **構造的な穴を発見** (§2 の R3-2)

### レビューした設計成果物 (リポジトリ相対パス)

**実物を開いて照合したもの**

- `docs/design/auth.md` (§6.12 / §9 の回答表 / §10.4)
- `docs/design/API/auth-accounts.md` (§4 A-7 / AA-D-15)
- `docs/design/API/themes.md` (§2 / §2.1 前文 / §3 / §3.2 / §4)
- `docs/design/API/assets.md` (§2 / §3.2 / §3.3 / §4)
- `docs/design/API/ideas.md` (§1.3 / §1.4 / §2 / §4.1)
- `docs/design/API/settings.md` (§2 / §3 / §3.1 / §3.2 / §4 / §6 / §7 / §7.1)
- `docs/design/API/README.md` (§2.2 / §2.3 / §2.5 / §3.1 / §3.6 / §4 / §5 / §6.1)
- `docs/design/API/plans.md` (§0.1 / §10.4 / §12 / §13)
- `docs/design/API/idea-boards.md` (§7 の対応表)
- `docs/design/frontend.md` (§5.4 / §11.1 / §14)
- `docs/design/data-model.md` (DM-9 / §4.4 / §4.10 / §5 / §7.4 / §8)
- `docs/design/llm-migration.md` (§2 / §5)
- `docs/analysis/v2-feature-inventory.md` (§4 / §5)
- `aidlc-docs/inception/productionization/requirements.md` (C-16 と承認済み例外表)
- `aidlc-docs/reviews/productionization/review-conversation-r2.md` (§10 = 検証対象)

**参照のみ**

- `aidlc-docs/reviews/productionization/review-conversation.md`
- `aidlc-docs/inception/productionization/plan.md`
- `.claude/rules/08-production-gates.md` / `.claude/rules/feedback_review_patterns.md`

**未確認 (本巡では見ていない)**

- `templates/app-monorepo/backend/` 配下の新規スキャフォールド一式・`機能一覧.md` (依頼により対象外)
- `docs/prototype/` の HTML と、そこへの行番号引用
- `docs/design/knowledge.md` / `news.md` / `conversation.md` / `observability.md` / `operations.md` /
  `infrastructure.md` / `testing.md` / `architecture.md` (本巡の論点に接続する箇所のみ grep で走査、通読はしていない)
- `aidlc-docs/aidlc-state.md` / `todo.html`
- 1・2 巡目が未確認とした引用の大半 (本巡で新たに照合したのは 7 件)

---

## 1. 反映の実物照合

### 1.1 2026-08-03 に本セッション外で行われた 3 箇所の是正 — **3 件とも実物を確認。ただし 2 件に副作用**

| # | 是正内容 | 実物 | 判定 |
|---|---|---|---|
| A | `docs/design/auth.md:1325` (§9 の A-7 回答表 (c)) を増分 1 へ | 「(c) テーマ・アセットの `visibility` 列と書き込み API はともに増分 1」。同書 `:1281` の §6.12 (c) と一致 | **一致。ただし副作用あり → 中 R3-M6** (**アイデアが列挙から落ちている**。`README.md:119` の D-API-8' は「テーマ / アセット / **アイデア**」の 3 つ) |
| B | `docs/design/API/auth-accounts.md:703` の A-7 を増分 1 へ + 根拠差し替え | 「`visibility` (列・書き込み API とも) は**増分 1**」+ 新根拠「契約単位の共有既定は `/settings/workspace` が持ち…」 | **一致。ただし副作用あり → 中 R3-M2** (**新根拠が依拠する `/settings/workspace` は設計上まだ増分 2**。根拠が増分 1 時点で成立しない) |
| C | `docs/design/auth.md:1548` の R-11 状態列を実態へ | 「**未対応のまま「実施済み」と誤記されていた**…2026-08-03 の独立検証で発覚し、同日修正」と経緯まで記載 | **一致。良い書き方** (§5 の 1 に再掲) |

### 1.2 2 巡目 §10「Freeze 可にするための最小の修正」7 項目 — **完全実施 3 / 部分実施 3 / 未実施 1**

| # | 2 巡目の要求 | 実物 | 判定 |
|---|---|---|---|
| **1** | `route_kind` の列注記を 2 値へ (`data-model.md:726`) | `docs/design/data-model.md:728` = ``(**4 つとも **`route_kind IN ('external_search','image_generation')` のときのみ NULL 可**。2026-08-02 に 2 値化)`` / `stop_reason` `(同じ 2 値の条件で NULL 可)`。同書 `:757` / `:928` / `:1251` と 4 箇所すべて 2 値 | **完全実施** |
| **2** | 可視性変更エンドポイントの増分列を 1 に | `docs/design/API/themes.md:55` = **1** / `docs/design/API/README.md:401` = **1** | **完全実施** |
| **3** | アセットの `visibility` 書き込み経路の確定 + `:50` / `:54` の 400・`:55` / `:144` / `:180` の増分 2 を是正 | `:50` / `:54` = 「400 (`scope` の値域外)」✅ / `:55` = 増分 1 ✅ / `:168` AS-M2 = 実在の経路へ差し替え済み ✅ / **`:144` (D-AS-12) = 「どちらも増分 2」のまま** ❌ / **`:180` (A-4) = 「`scope=contract` (増分 2)」のまま** ❌ | **部分実施 → 重大 R3-5** |
| **4** | アイデアの `visibility` 書き込み経路を決める | `docs/design/API/ideas.md:72` (`PUT /ideas/{idea_id}` の body に `visibility`) / `:118`〜`:119` (書き込み経路の決定 + C-16 違反になる理由 + 所有者のみ) / `:461` (版を切らない理由 = BE-4 の誤検知回避) | **完全実施 (質が高い)** |
| **5** | FE の「BE が 400 で拒否する」前提を撤回 + `auth.md` R-10 の状態列更新 | `docs/design/frontend.md:424` = 撤回済み ✅ / **同 `:425` = 「共有・可視性の UI は増分 2 で追加する」のまま** ❌ / **同 `:996` (§14 の A-7) = 「増分 2。…導線を出さない (BE が 400 を返すため)」のまま** ❌ / `docs/design/auth.md:1549` R-10 = 「**未対応** (並行編集)」 | **部分実施 → 重大 R3-6** |
| **6** | 決定・回答表の残存を是正 (`themes.md:94` / `auth.md:1325` / `auth-accounts.md:703` / `settings.md:66`・`:106`・`:230`〜`:234`) | `themes.md:94` = 増分 1 ✅ / `auth.md:1325` = 増分 1 ✅ (1.1 A) / `auth-accounts.md:703` = 増分 1 ✅ (1.1 B) / **`settings.md:66`・`:67` = 増分 2 のまま** ❌ / **`:106` = 「常に `private`・`scope=contract` は 400」のまま** ❌ / **`:230`〜`:234` = ST-Q8=a のまま** ❌ | **部分実施 → 重大 R3-1 / R3-3** |
| **7** | `auth.md` §10.4 の前文と R-11 の状態列を実態に合わせる | `:1542` 前文 = 書き換え済みだが**内容が実態と違う** (下記) / `:1548` R-11 = 実態化済み ✅ (1.1 C) | **未実施 (前文) → 中 R3-M1** |

**項目 7 の前文が実態と違う点** (`docs/design/auth.md:1542`):

- 「**反映済み**」に ``frontend.md` の scope UI` を列挙しているが、`frontend.md:425` / `:996` は未反映 (R3-6)
- 「反映済み」に ``API/settings.md` D-ST-3` を列挙しているが、同書のエンドポイント表・§3.2 は真逆 (R3-1 / R3-3)
- 「**下記 2 書は別セッションが編集中のため未反映**」と書いているが、表の未対応行は **R-10 の 1 件のみ** (R-11 は 2026-08-03 に実施済み)。
  **かつ `settings.md` は要求として起票すらされていない** — 未反映の実物があるのに受信欄が無い (DR-8 の受信側の欠落)

---

## 2. 重大 (Must Fix — Design Freeze を止める)

### 重大 R3-1. `/settings/workspace` の増分が `requirements.md` の確定決定と全面的に食い違い、C-16 が要求する「契約単位の既定値」が増分 1 に存在しない

**上流の確定** (これが正):

- `aidlc-docs/inception/productionization/requirements.md:50` — 「`/settings/workspace` (アセット可視性の既定) | **増分 1 へ前倒し (例外ではなくなった)** | **C-16 の適用で ST-Q8=a を撤回** (2026-07-31)。…`docs/design/auth.md` §6.12 の 3 が SSOT」
- `docs/design/auth.md:1298` (§6.12 の 3) — 「**契約単位の既定値** — v2 は**1 スイッチで契約全体を切り替えられた**ため、per-resource だけにすると…**操作の後退**になる。`API/settings.md` の `default_asset_visibility` 相当を**テーマ / アセット / アイデアの 3 カテゴリ**に持たせ…」

**設計側の実物** (増分 2 のまま = 7 箇所 + 2 書):

| 箇所 | 記述 |
|---|---|
| `docs/design/API/settings.md:66` / `:67` | `GET` / `PUT /settings/workspace` の増分列 = **2** |
| 同 `:58`〜`:59` | 「2026-07-30 の ST-Q8 回答で `/settings/workspace` は増分 2 へ後ろ倒し」 |
| 同 `:40` | 「ST-Q8=a により `/settings/workspace` は増分 2 へ後ろ倒し」 |
| 同 `:73` | 「`PUT /settings/workspace` (増分 2 — ST-Q8)」 |
| 同 `:226`〜`:234` | ST-Q8 の `[Answer]` が「**(a) 増分 2 へ後ろ倒し**…§3 の増分列・§3.2 に反映済み」のまま |
| `docs/design/API/README.md:489` / `:490` | 総覧表の増分列 = **2** |
| `docs/design/frontend.md:779` | ルート表 = 「**ST-Q8 により増分 2 へ後ろ倒し**」/ 増分列 **2** |
| `docs/design/auth.md:1552` | 「併せてユーザー確認が必要な既存決定…**ST-Q8** (`/settings/workspace` の後ろ倒し)」← 既に決着済み |

**同一ファイル内の直接矛盾**: `settings.md:42` (「**v3 新設 (増分 1)**」) / `:128` D-ST-3 (「**増分 1** で有効化」) /
`:204` A-7 (「**書く側と読む側をどちらも増分 1 に置く**」) — **判断行だけが増分 1 で、エンドポイント表・移行表・`[Answer]` が増分 2**。
2 巡目の重大 R2-1 とまったく同じ型 (判断文だけ直してエンドポイント表が残る) が、指摘後も別ファイルで生き残っている。

**なぜ本番で問題になるか**: `default_*_visibility` を書ける唯一のエンドポイントが増分 2 だと、
**増分 1 のユーザーは新規リソースの共有既定を持てず、テーマ・アセット・アイデアを 1 件ずつ手で `contract` にする**運用になる。
v2 は `POST /sharing-settings` の 1 スイッチで契約全体を切り替えられた
(`hassan-v2-backend/router/router.go:189` = `sharingSettingsRoute.POST("", AuthRequiredMiddleware(auth.AuthRoleUser), CreateOrUpdateSharingSettings)` — **本巡で実読・一致**) ので、
これは C-16 が名指しで禁じている「**利用者ができていた操作の後退**」に当たる。
しかも**上流の要件文書は既に「前倒し」で確定している**ため、これは判断待ちではなく**単なる未反映**である。

**修正案 (最小)**:

1. `settings.md:66` / `:67` の増分列を **1** に、`README.md:489` / `:490` も **1** に、`frontend.md:779` も **1** に
2. `settings.md:40` / `:58`〜`:59` / `:73` の「ST-Q8=a により増分 2 へ後ろ倒し」を、`requirements.md:50` を引いて「**2026-07-31 に C-16 で撤回。増分 1**」へ
3. `settings.md:226`〜`:234` の `[Answer]` は**回答を消さず**「(a) と回答されたが **2026-07-31 に C-16 で撤回された** (`requirements.md:50`)」と追記する (決定の履歴を残す)
4. `auth.md:1552` から ST-Q8 を落とし (決着済み)、`auth.md` §10.4 に **`API/settings.md` 宛ての是正要求 (R-13 等) を新規起票**する — 現状は宛先の受信欄が無い

### 重大 R3-2. `themes.md` §3.2 の増分ゲート表が撤回済みの旧設計のまま — **`data-model.md` DM-9 が「開放時期の SSOT」と名指ししている表**

**根拠**:

- `docs/design/data-model.md:125` (DM-9) — 「**SSOT の書き分け**: 列を持つテーブルと値域は本書 / **開放時期と画面での意味は `API/themes.md` §3.2・`API/assets.md` §3.2**」
- `docs/design/API/themes.md:131` — 「| **1** | `mine` のみ (**`contract` は 400**) | `WHERE account_id = <認証ユーザー>` | 可視性を表す属性がまだ無い…」
- 同 `:132` — 「| **2** | `mine` / `contract` | `contract`: `WHERE contract_id = … AND (visibility = 'contract' OR account_id = …)` | …」
- 対して同 `:84` (「`visibility` は**増分 1 から読み書きする**」) / `:98` (D-TH-5) / `:139` (TM-2) / `:152` (A-4「`contract` (**増分 1 から有効**)」) / `:155` (A-7) / `docs/design/API/README.md:119` (D-API-8')

**なぜ本番で問題になるか**: この表は **`scope=contract` の WHERE 句そのものを定義している唯一の場所**であり、
実装者が Repository のクエリを書くときに読む。**増分 1 = 400・増分 2 = visibility 条件**のまま実装されると、
増分 1 で `scope=contract` が 400 を返し、**移行で `visibility='contract'` を入れた既存テーマが誰にも見えない** —
`auth.md:1293` が「機能退行」として名指しした事象そのものになる。

**この件が 2 巡連続で生き残った理由 (手順の欠陥。R3-8 として §4 に再掲)**:
2 巡目 §10 の再検査手順 #1 は `grep -rn "増分 2" docs/design/` だった。
**この表の増分列は裸の `**1**` / `**2**` であり、「増分 2」という文字列を含まない**ため、
grep では構造的に検出できない。`settings.md:106` (R3-3) が同じ理由で生き残っている。

**修正案**: `themes.md:129`〜`:132` の 2 行表を**1 行に畳む** (増分で分ける理由が無くなったため) —
「| `mine` | `WHERE account_id = …` | | `contract` | `WHERE contract_id = <契約> AND (visibility = 'contract' OR account_id = …)` |」。
`assets.md` §3.2 には同型の表が無い (D-AS-12 が代替 → R3-5 で是正) ので、**DM-9 の「開放時期の SSOT」の指し先を確認して揃える**。

### 重大 R3-3. `settings.md` §3.2 の増分対応表が「`visibility` は常に `private`・`scope=contract` は 400」のまま — 他書が**明示的に撤回した**記述の生き残り

**根拠**:

- `docs/design/API/settings.md:106` — 「| **1** | **`/settings/workspace` 自体を提供しない** | **`visibility` はスキーマに存在するが常に `private`。`scope=contract` は 400** |」
- 対して `docs/design/data-model.md:500`〜`:501` — 「**2026-08-02 に「増分 1 では常に `private` が入る」を撤回** — 書き込み API が増分 1 にある以上、常に `private` という記述は成立しない」
- 対して `docs/design/API/themes.md:84` — 「`visibility` は**増分 1 から読み書きする** (**2026-07-31 改訂**。旧記述は「増分 1 では常に `private`」)」
- 同表の却下欄 `:114`〜`:115` — 「**却下**: `default_asset_visibility` を増分 1 で作る — 適用先が無く、設定した値がどこにも効かない期間ができる」
  ← **`:128` の D-ST-3 は同じ案を採用案として書いている**。**同一ファイル内で採用案が却下欄に載っている**

**なぜ本番で問題になるか**: §3.2 は「BE-10 (読む側と書く側を対で設計する)」の節として作られており、
**実装者が「この増分で何が動くか」を確認する表**である。ここが旧記述だと、
R3-1 と合わせて「増分 1 では共有は一切動かない」と読める。C-16 の中核が丸ごと落ちる。

**修正案**: `:104`〜`:107` の表を「増分 1 で書く側 (`/settings/workspace`) と読む側 (`visibility` / `scope=contract`) を**同時に**開く」1 行に置き換え、
`:114`〜`:115` の却下を「**この却下は 2026-07-31 に C-16 で撤回した** — 適用先 (per-resource `visibility`) も同じ増分 1 に入ったため、
『効かない期間』は発生しない」に書き換える (却下を消さず、撤回として残す)。

### 重大 R3-4. `README.md` §2.5 (ステータスコードの SSOT) の 400 行に「`scope=contract` を増分 1 で指定」が残る — **R-9 は「§2.5 の 400 行を追随させた」と実施済み申告している**

**根拠**:

- `docs/design/API/README.md:292` — 「| リクエストボディ・クエリのバリデーション違反 (必須欠落・型不一致・`limit` 範囲外・`sort` 許可外・**`scope=contract` を増分 1 で指定**) | **400** | `CodedError` | 全エンドポイント (D-API-6 / D-API-7 / **D-API-8'** / D-API-9) |」
- 対して同 `:119` (D-API-8') — 「テーマ / アセット / アイデアの `scope=contract` は**増分 1 から有効化**する (**2026-08-02 改訂。旧「増分 2」を撤回**)」
- `docs/design/auth.md:1546` (R-9 の状態列) — 「**実施済み** (2026-08-02)。…§1.4 の `scope` 値域・§2.2・**§2.5 の 400 行**・§5 の A-7 行…を追随させた」← **実物は未反映**
- 対比: `docs/design/API/assets.md:50` / `:54` は同じ 400 を「**`scope` の値域外**」に直している (正しい形)

**なぜ本番で問題になるか**: §2.5 は **A-5 (401/403/404 の使い分け) の SSOT** であり、
`docs/design/API/README.md:193` の UT 規約 (「`scope` の値域が `mine`/`contract` のみであることを UT で担保する」) と対になる。
ここが旧記述だと **`scope=contract` を 400 で弾く UT が書かれ、CI が「設計どおり」に緑で通る** —
機械強制が誤った仕様を固定する最悪の形になる。
かつ**これで 3 巡連続で「R-9 実施済み」の申告に穴がある** (1 巡目: API 表未反映 / 2 巡目: `ideas.md` 6 箇所・§10.4 / 3 巡目: §2.5)。

**修正案**: `:292` の括弧内を「`sort` 許可外・**`scope` の値域外**」に変える (1 行)。あわせて `auth.md:1546` の R-9 状態列から「§2.5 の 400 行」の記載を落とすか、本巡での是正日を追記する。

### 重大 R3-5. `assets.md` D-AS-12 (`:144`) と A-4 (`:180`) が「増分 2」のまま — 2 巡目 Freeze 条件 #3 の半分が未実施

**根拠**:

- `docs/design/API/assets.md:144` (D-AS-12) — 「**書き込み経路 (`POST` / `PUT` の `visibility`) と `scope=contract` はどちらも増分 2**」。
  さらに却下欄 (b) が「**両者を同じ増分 2 に入れることで構造的に潰す**」= **却下の論拠自体が旧前提**
- 同 `:180` (A-4) — 「`scope=contract` (**増分 2**) は `contract_id` + `visibility` 条件 (§3.2)」
- 対して同 `:55` (増分 1) / `:168` (AS-M2 = 増分 1) / `:185` (A-7 = 増分 1) / `docs/design/API/README.md:119`

**なぜ本番で問題になるか**: D-AS-12 は `assets.md` §3 の**設計判断表の筆頭行**であり、
「なぜこの設計か」を確認する実装者が最初に読む。A-4 は**本番観点の回答表**であり、`design-reviewer` と実装レビュアーが照合する行である。
**判断表と回答表の両方が増分 2 と書いているのに移行表 (AS-M2) だけが増分 1** という状態は、
2 巡目が指摘した「読み手が増分 2 として実装しない」帰結をそのまま残している。

**修正案**: `:144` の採用案を「どちらも**増分 1**」に、却下欄 (b) の締めを「**両者を同じ増分 1 に入れることで構造的に潰す** (2026-07-31 に C-16 で増分 2 → 1)」に。`:180` の「(増分 2)」を「(**増分 1 から有効**)」に。

### 重大 R3-6. `frontend.md` の §5.4 2 行目 (`:425`) と §14 の A-7 (`:996`) が旧記述のまま — **同一箇条書きの中で自己矛盾**

**根拠**:

- `docs/design/frontend.md:424` — 「**`scope` の UI は増分 1 から出す** (2026-08-02 改訂。旧記述は「増分 1 では出さない — BE が 400 で拒否する」だったが…**共有の切り替え UI も同じ増分に出す = BE-10**)」← 是正済み
- **同 `:425` (同じ箇条書きの続き)** — 「共有・可視性の UI は**増分 2 で追加**する (A-7)」← **直前の行が「共有の切り替え UI も同じ増分に出す」と書いた直後に、真逆を書いている**
- **同 `:996` (§14 の A-7 行)** — 「**§5.4 / §11.1**: 共有・可視性の UI は**増分 2**。増分 1 では `scope` セレクタとメンバー共有画面の導線を出さない (**BE が 400 を返すため**)」← 2 巡目の再検査手順 #4 (`grep "BE が 400"` が 0 件になること) が**満たされていない**
- `docs/design/auth.md:1549` (R-10) = 「**未対応** (並行編集)」

**なぜ本番で問題になるか**: `:996` は **FE 設計の本番観点回答表**であり、`:425` は実装者が §5.4 を読んだときの最終行である。
BE が `PUT /themes/{theme_id}/visibility` (増分 1) を実装しても **FE に導線が無ければ利用者は共有を切り替えられない** —
C-16 は「利用者ができていた操作」を守る要件なので、**BE だけ直しても C-16 は達成されない**。
`auth.md:1542` の前文が frontend.md を「反映済み」に列挙している点も含め、**状態の虚偽記載**である。

**R-10 が「未対応 (並行編集)」であることの Freeze 可否への影響 (依頼された判断)**:
**Freeze を止める**。理由は 3 つ:
①「並行編集」は 2026-08-02 時点の記述で、**2026-08-03 の本巡でも同じ状態**である (並行編集が進んでいる証拠が無い)。
②未対応なのは受信側 (frontend.md) だけでなく、**起票側の前文 (`auth.md:1542`) が「反映済み」と書いている**ため、
`docs/design/README.md:82` の運用ルール (「『未対応』と書いてあっても実装をブロックしない」) の保護が効かない —
**前文を読んだ実装者は反映済みだと信じる**。
③ `:424` と `:425` が同一箇条書き内で矛盾しており、**「未対応」ではなく「誤った仕様が書かれている」状態**である。
未着手なら実装者は保留するが、矛盾は片方を選ばせる。

**修正案**: `:425` を削除するか「**共有・可視性の切り替え UI (`PUT /visibility` の導線) も増分 1。テーマメンバー共有画面のみ増分 2**」に。
`:996` を同内容に書き換え、`auth.md:1549` の R-10 状態列を実施日付付きで更新する。**`:762` (`/themes/[themeId]/members` = 増分 2) は正しいので触らない**。

### 重大 R3-7. `asset_folders` の `visibility` に書き込み経路が無い — 2 巡目 R2-1 (c) が指摘した BE-10 のうち**アイデアだけが塞がれ、フォルダが残った**

**根拠**:

- `docs/design/data-model.md:125` (DM-9) — 「`visibility` 列を `themes` / `assets` / **`asset_folders`** / `ideas` に持つ。**列と書き込み API の両方を増分 1 に含める**」
- `docs/design/data-model.md:510` — `asset_folders` の列に `visibility` あり
- `docs/design/API/assets.md:145` (D-AS-13) — 「**フォルダの可視性はフォルダ自身の `visibility` で判定**し、配下アセットの可視性とは独立に評価する」← **読む側**
- `docs/design/API/assets.md:46` (`POST /asset-folders`) — B: `name` / `parent_id` のみ。**`visibility` が無い**
- 同 `:47` (`PUT /asset-folders/{folder_id}`) — B: `name` / `parent_id` のみ。**`visibility` が無い**
- 同 `:44` (`GET /asset-folders`) — `scope=contract` は増分 1 から有効
- `assets.md` に `asset_folders` の `visibility` に関する決定 (D-AS-x) も、移行時の初期値の記述 (AS-M1 は `assets` のみ) も無い

**なぜ本番で問題になるか**: 2 巡目が「`ideas.visibility` は読む側だけがあり書く側が無い = **BE-10 そのもの**」と指摘した構造が、
**同じ差分で `asset_folders` に残っている**。増分 1 で `GET /asset-folders?scope=contract` が有効になるのに
フォルダの `visibility` は永久に既定 (`private`) のままなので、**契約内の他人のフォルダは 1 件も返らない**。
D-AS-13 が「フォルダの可視性はフォルダ自身で判定する」と決めた結果、**共有アセットが入っているフォルダごと見えなくなる**
(アセット単体は `GET /assets?scope=contract` で見えるので、**ツリー表示とフラット表示で見える集合が食い違う**)。
さらに `AS-M1` は `assets` の初期値しか決めていないため、**移行後も全フォルダが `private`** である。

**修正案**: いずれかを選び、理由とともに書く。
(a) `POST` / `PUT /asset-folders` の body に `visibility` を足す (`assets.md` AS-M2 と同じ形) + AS-M1 にフォルダの初期値規則を追加する。
(b) `asset_folders` から `visibility` 列を落とし、D-AS-13 を「フォルダは常に契約内で可視。中身の可視性はアセット側で判定」に変える
(現在の却下欄が「フォルダ名から他人の技術領域が推測できる」を理由にこれを却下しているので、採るなら却下理由への反論が要る)。
**無言で残さない** (DR-2)。

---

## 3. `make check` の実行結果

```
[doc-lint] 対象 104 ファイル / エラー 0 件 / 警告 39 件
  → 警告 39 件はすべて既存 (過去 review・ルール文書・design_memo.md の「TODO」語 /
    既存の未回答 [Answer] 5 件 = data-model.md:1061 / frontend.md:1229 /
    infrastructure.md:519・:535 / llm-migration.md:790 / operations.md:704)。
    本巡の論点に関わる新規の未回答 [Answer] は 0 件
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 86/86 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
[workflow-shell] 検査 52 ブロック / エラー 0 件
[table-counts] 実測: 機能テーブル 42 (個人 34 / 契約 8) / 分類 ①31 ②2 ③1
[table-counts] 実測: 機能テーブル以外 12 (所有者列なし 7 / 所有者列あり 5) / 検査①の除外リスト 9
[table-counts] 照合 37 件 / エラー 0 件
[endpoint-mapping] 実測: auth-accounts.md 37 本 / 9 ドメイン 112 本 / settings.md §5 18 行 /
                   custom tool 8 本 / 403 16 本
[endpoint-mapping] 照合 36 件 / エラー 0 件
```

**5 ゲートすべてエラー 0 (完了条件を満たす)**。ただし **重大 7 件はいずれも機械検査の対象外**である。
特に注意すべきは、**`check-endpoint-mapping.sh` が「増分」列を一切見ていない**こと —
`settings.md:66` (増分 2) と `README.md:489` (増分 2) は**両方とも旧値なので照合が一致してしまう**。
件数の照合は「2 箇所が同じ値か」しか見ないため、**両方が同時に古い場合は検出できない** (中 R3-M8)。

---

## 4. 中 (Should Fix)

### 中 R3-M1. `auth.md:1542` の §10.4 前文が実態と 3 点食い違い、`settings.md` 宛ての受信欄が存在しない

§1.2 の項目 7 に詳述。要点は ①`frontend.md` を「反映済み」に列挙しているが `:425` / `:996` は未反映
②`settings.md D-ST-3` を「反映済み」に列挙しているが同書のエンドポイント表・§3.2 は真逆
③「下記 2 書は…未反映」の**「2 書」が実態と合わない** (未対応行は R-10 の 1 件。`settings.md` は起票すらされていない)。
③は DR-9 (件数の転記) の型でもある — **「2 書」と数えずに「状態列が『未対応』の行を参照」と書けば連動しない**。

### 中 R3-M2. `auth-accounts.md:703` の新しい根拠が、まだ増分 2 の `/settings/workspace` に依拠している (2026-08-03 の是正 B の副作用)

`docs/design/API/auth-accounts.md:703` の新根拠 = 「契約単位の共有既定は `/settings/workspace` が持ち、
per-resource の可視性は各リソースが持つため、契約情報の応答に共有設定を載せる必要が無い」。
**R3-1 のとおり `/settings/workspace` は設計上まだ増分 2** なので、増分 1 の時点では
「契約単位の共有既定を持つ場所が存在しない」ことになり、**`GET /contracts/me` から `sharing_settings` を落とす根拠が増分 1 で成立しない**。
R3-1 を直せば自動的に解消する (順序依存)。**R3-1 を先に直すこと**。

### 中 R3-M3. `auth.md:1549` (R-10) と `:1552` の要求文が、上流で既に決着した論点を「再確認が必要」と書いている

- `:1549` — 「**`/settings/workspace` は増分 1 へ前倒し** — …**ST-Q8=a (増分 2 へ後ろ倒し) は C-16 の下で再確認が必要**」
- `:1552` — 「**併せてユーザー確認が必要な既存決定**…**ST-Q8** (`/settings/workspace` の後ろ倒し)」
- 対して `aidlc-docs/inception/productionization/requirements.md:50` — **2026-07-31 に撤回済み・前倒し確定**

「再確認が必要」と書かれている限り、読者は**まだ判断待ち**と解釈して R3-1 を直さない。
`requirements.md:50` を引いて「**決着済み (2026-07-31)。反映が未了**」に書き換えること。

### 中 R3-M4. `plans.md:777`〜`:778` に「読み取りが契約に開くまでは」の旧前提が残る (2 巡目 中 R2-M2 が未対応)

- `docs/design/API/plans.md:772` — 「**`scope=contract` は増分 1 から受け付ける**」
- 同 `:777`〜`:778` — 「**`visibility` の書き込みは `PUT /plans/{plan_id}`** で受ける。**読み取りが契約に開くまでは値を設定しても表示範囲は変わらない**」

同じ節の 5 行下で撤回済みの前提が繰り返されている。2 巡目で指摘され、Freeze 条件外として見送られたまま。

### 中 R3-M5. `llm-migration.md:213`〜`:214` の「本ディレクトリ対象外の未着手タスク」が残る (2 巡目 中 R2-M6 が未対応)

- `docs/design/llm-migration.md:213`〜`:214` — 「**『会話型アイデア創出の API 設計』** (`API/README.md` §0 で**本ディレクトリ対象外として宣言済みのタスク**。**着手は認証系 Task-3i の後** — 2026-07-31 のユーザー決定) が担う」
- 同書 `:92` は「**API 設計は完了 (2026-08-02)**」

同一ファイル内で「完了」と「未着手」が併存。

### 中 R3-M6. `auth.md:1325` と `auth-accounts.md:703` の A-7 回答が「テーマ・アセット」の 2 つで、**アイデアが落ちている** (2026-08-03 の是正 A の副作用)

- `docs/design/auth.md:1325` — 「(c) **テーマ・アセット**の `visibility` 列と書き込み API はともに増分 1」
- `docs/design/API/auth-accounts.md:703` — 「**テーマ・アセット**の `visibility` (列・書き込み API とも) は**増分 1**」
- 対して `docs/design/API/README.md:119` (D-API-8') / `:558` / `:576` / `docs/design/data-model.md:125` (DM-9) — いずれも「**テーマ / アセット / アイデア**」の 3 つ

`ideas.md` は今回まさに `visibility` の書き込み経路を新設した (§1.2 の項目 4) 側なので、
**A-7 の回答表からアイデアが落ちているのは A-7 のカバレッジ申告として不正確**。

### 中 R3-M7. `README.md:244` の凡例「個人 / 契約 (増分 2)」が、実質 0 件の集合を指す表記になっている

- `docs/design/API/README.md:244` — 「| **個人 / 契約 (増分 2)** | `scope` パラメータで切り替わる…**この表記のまま残る増分 2 の対象はテーマメンバー機能のみ**」
- しかし `README.md:401`〜`:402` のテーマメンバー 2 本のスコープ列は「**契約**」であり、「個人 / 契約 (増分 2)」ではない。
  かつメンバー 2 本は `scope` パラメータを持たない (`docs/design/API/themes.md:53`〜`:54`)

**この凡例に該当する行が総覧表に 1 件も無い**。凡例そのものを削除するか、
「(増分 2)」を落として `scope` を持つドメイン共通の表記にすること。

### 中 R3-M8. 「増分」列が機械検査の対象外で、**両側が同時に古い場合を検出できない**

`scripts/check-endpoint-mapping.sh` は本数・403 の件数を照合するが、**増分列は見ていない**。
実際 `settings.md:66` (2) と `README.md:489` (2) は**両方が旧値なので一致してしまう** (R3-1 が 3 巡生き残った一因)。
本数系の DR-9 対策 (定義元 ↔ 転記先の照合) は「片方だけずれる」型には効くが、
**「上流の決定 (requirements.md の C-16 例外表) ↔ 設計の増分列」の照合が無い**ため、この型は素通りする。

**提案**: `requirements.md` の C-16 例外表に「**増分**」列を持たせ、
`scripts/` に「例外表で『増分 1 へ前倒し』と書かれた機能のエンドポイント増分列が 1 であること」を照合する検査を足す。
**足したら故障注入で殴る** (`05-harness.md` の運用どおり)。

---

## 5. 軽微 (Nice to Have)

| # | 箇所 | 内容 |
|---|---|---|
| R3-L1 | `docs/design/API/README.md:558` | A-7 が「**部分回答**」のまま。同書 `:576` の API-Q3 は「A-7 の判断部分はクローズ済み (2026-08-02)」と書いており、ラベルだけ旧状態。「**回答** (残る未確認は TH-Q5 のみ)」へ |
| R3-L2 | `docs/design/API/settings.md:42` の根拠列末尾 | 「**適用先 (`assets.md` の `visibility`) と同じ増分 2 に揃える**」— 同じセルの判断列が「**v3 新設 (増分 1)**」。**1 つのセル内で自己矛盾**。R3-1 の修正と同時に落とす |
| R3-L3 | `docs/design/API/themes.md:94` (D-TH-1 の却下案 a) | 引用 `hassan-v2-backend/usecase/asset/list_assets.go:60-66` の実測は `:61`〜`:68` (`:60` は空行、契約一致の判定本体は `:66`〜`:68`)。**load-bearing な `:66` は範囲内なので実害は無い**が、範囲の始端が 1 行ずれている |
| R3-L4 | `docs/design/API/assets.md:180` / `docs/design/API/themes.md:152` | 「**更新・削除は増分 2 でも作成者のみ**」— 「増分 2 でも」は正しい (増分 2 になっても変わらない意) が、R3-5 の修正時に「増分 2」を機械置換すると壊れる。**置換対象から除外すること** |
| R3-L5 | `docs/design/API/settings.md:226` | 「**ST-Q8 / ST-Q9 は 2026-07-30 に回答済みで、本文 (§3 / §3.2) へ反映済み**」— ST-Q8 は 2026-07-31 に撤回されたので、この行も R3-1 の修正対象 |

---

## 6. 一次ソースの抜き取り照合 (本巡で 7 件。うち 4 件が load-bearing)

参照リポジトリは**読み取りのみ**。1・2 巡目が照合していない箇所を、本巡の結論を左右するものから選んだ。

| # | 主張 (箇所) | 照合 | 結果 |
|---|---|---|---|
| 1 | **`auth.md:1292`** — v2 は `POST /sharing-settings` で契約単位の共有を切り替えられた (`router.go:188`〜`:189`。`AuthRoleUser` で到達可) | `sed -n '186,192p' router/router.go` | **一致** (`:188` = `r.Group("/sharing-settings")` / `:189` = `POST("", AuthRequiredMiddleware(auth.AuthRoleUser), CreateOrUpdateSharingSettings)`)。**R3-1 の根拠** |
| 2 | **`themes.md` §3.2** — テーマ一覧は `is_shared == false` のとき絞り込みを認証ユーザーへ強制 (`usecase/theme/list_themes.go:42-52`。レコード未作成時は false 扱い) | 実読 | **一致** (`:42`〜`:43` がまさにそのコメント、`:44` が `GetSharingSettingsByCategory`、`:50`〜`:52` が強制)。**R3-2 の根拠** |
| 3 | **`assets.md` §3.2** — 共有 OFF で契約スコープ or 他人指定は `SharingSettingDisabled` → 403 (`usecase/asset/list_assets.go:71-79` / `controller/asset.go:119-120`) | 実読 | **一致** (`:71` = 「// 共有設定の確認」、`:78` = `if (useContract \|\| accountID != input.AccountID) && !isShared`、`:79` = `SharingSettingDisabled`。controller `:119`〜`:120` = `codedErr.Code == SharingSettingDisabled` → `forbidden(c, err)`)。**R3-5 の根拠** |
| 4 | **`settings.md` ST-Q5** — v2 の `sharing_settings` は契約 × カテゴリの ON/OFF (`db/schema.sql:491-499`) | 実読 | **一致** (`:491` = `CREATE TABLE sharing_settings`、`contract_id` / `category` / `is_shared`、`:499` = `PRIMARY KEY (contract_id, category)`)。**R3-1 / R3-3 の根拠** |
| 5 | `themes.md:94` (D-TH-1) — アセット側には契約一致検証がある (`usecase/asset/list_assets.go:60-66`) | 実読 | **部分一致** — 検証本体は `:61`〜`:68` (`:66` = `if account == nil \|\| input.ContractID != account.ContractID`)。始端が 1 行ずれ → 軽微 R3-L3 |
| 6 | `idea-boards.md:394` — `cagr` = `db/schema.sql:161` (2 巡目 R2-L1 の是正) | 実読 | **一致** (`:160` = `market_size text` / `:161` = `cagr text`)。**是正が正しく入っている** |
| 7 | `themes.md:94` — v2 のテーマ一覧は `GetAccountByID` の存在確認のみ (契約一致を検証しない) | `sed -n '55,62p' usecase/theme/list_themes.go` | **一致** (`:56`〜`:62` は `GetAccountByID` → `account == nil` の存在確認のみで、`ContractID` の比較が無い。**アセット側 (#5) との非対称が現に存在する**) |

**内容の誤りは 0 件**、行番号のずれ 1 件 (R3-L3、実害なし)。
`feedback_review_patterns.md` の全数照合トリガー (内容の誤りが 1 件でも出たら) には該当しない。

---

## 7. 頻出パターンの再確認

| ID | 判定 |
|---|---|
| DR-1 出典なしの断定 | **該当なし** (抜き取り 7 件で内容の誤り 0) |
| DR-2 本番観点の無言の省略 | **1 件** — `asset_folders.visibility` の書き込み経路が無いことに理由も先送り先も無い (重大 R3-7) |
| DR-3 既存データの不在 | **1 件** — `asset_folders` の移行時初期値が AS-M1 に無い (重大 R3-7 に含む) |
| DR-4 PoC 実装のコピー設計 | **該当なし** |
| DR-5 曖昧語による丸投げ | **1 件** — 一括生成中の `tabs[].status` (2 巡目 中 R2-M3 が未対応。`docs/design/API/plans.md:500` は「`tabs[].status` で分かる」と書くのみで値が未定義。`:880` の PL-R7 は別論点) |
| DR-6 AC の宙吊り | **該当なし** (86/86。ただし `auth.md:1325` が自認するとおり **A-7 に対応する AC が要件側に無い** — R-8 として起票済み) |
| DR-7 プロトタイプを仕様として扱う | **該当なし** (むしろ `assets.md:147` の「プロトタイプに UI が無いことは機能を落とす理由にならない」は DR-7 の裏面を正しく扱っている) |
| **DR-8 修正の波及漏れ** | **9 件** (R3-1 / R3-2 / R3-3 / R3-4 / R3-5 / R3-6 / R3-M1 / R3-M4 / R3-M5)。**8 巡連続**。**うち R3-4 / R3-6 は「実施済み」と申告された箇所** |
| DR-9 件数の転記 | **2 件** — `auth.md:1542` の「2 書」(中 R3-M1) / 増分列が無検査 (中 R3-M8) |
| BE-10 書き手のいない読み手 | **1 件** — `asset_folders.visibility` (重大 R3-7)。**`ideas.visibility` は 2 巡目指摘を受けて塞がれた** |

### 7.1 DR-8 への追記提案 (依頼された判断: **追記すべき**)

`.claude/rules/feedback_review_patterns.md` の DR-8 に、**2 つの新しい型**を追記することを提案する
(本レビューは提案のみ。**ファイルは編集していない**)。

**型①: 状態列の自己申告が別項目の内容とすり替わる** (2026-08-03 に R-11 で観測)

> `docs/design/auth.md:1548` の R-11 の状態列に **R-12 の対応内容** (README の CSV 集計・frontend.md のボタン配置) が
> 貼られており、「実施済み」に見えたまま R-11 本来の要求 (AA-D-15 の根拠差し替え) が未反映だった。
> **表の行が増えると状態列の貼り付け先を 1 行間違える**。かつ**間違えた側は「実施済み」に見える**ため、
> レビューでも読み飛ばされる。
> **検出法**: 状態列を読むときに**要求列のキーワードが状態列に現れるか**を確認する
> (R-11 の要求が「AA-D-15」なら状態列に `AA-D-15` が無ければ疑う)。
> **予防**: 状態列の書き出しを「**要求 ID を再掲してから**」にする (「**R-11**: 実施済み (2026-08-03) …」)。

**型②: 再検査の grep が「文字列としての判断語」に依存し、表の増分列 (裸の数字) を構造的に取りこぼす** (2026-08-03 に R3-2 / R3-3 で観測)

> 2 巡目レビューが提示した再検査手順 `grep -rn "増分 2" docs/design/` は、
> **`docs/design/API/themes.md:131`〜`:132` の増分ゲート表**と **`docs/design/API/settings.md:106` の増分対応表**を
> 検出できなかった — どちらも増分を `**1**` / `**2**` という**裸の数字のセル**で表しているため。
> しかも前者は `docs/design/data-model.md:125` (DM-9) が「開放時期の SSOT」と名指ししている表である。
> **DR-8 の再検査 grep は「数値語 + 状態語」だけでは足りず、『その事実を表現している表の列』も対象にする**。
> **検出法**: 判断を変えたら、**その判断を列で表している表を先に列挙する** —
> `grep -rn "^| \*\*[12]\*\* |" docs/design/` のような**表構造の検索**を 1 本足す。
> **予防**: 増分・可否のような**二値の判断を「行を分けた表」で表現しない** (1 行に畳み、変更点が 1 箇所になる形にする)。

---

## 8. 本番観点カバレッジ (本巡の論点に関わる ID)

| ID | 状態 | 箇所 |
|---|---|---|
| **A-3** テナント境界 | **回答あり (整合)** | `docs/design/data-model.md:125` (DM-9。`visibility` を 4 テーブルに) / `:510`〜`:511` / `docs/design/auth.md` §2.2。**本巡の変更で崩れていない** |
| **A-4** 絞り込みの層 | **回答あり。ただし SSOT が旧記述** | 回答は `docs/design/API/themes.md:152` / `docs/design/API/assets.md:180` / `docs/design/API/ideas.md:143` (1 クエリ評価)。**しかし WHERE 句を定義している `themes.md:131`〜`:132` が撤回済みの旧設計** (重大 R3-2)。**`assets.md:180` の回答自体も「増分 2」で旧記述** (重大 R3-5) |
| **A-5** ステータスコード | **回答あり。ただし SSOT に旧記述** | `docs/design/API/README.md` §2.5 が SSOT。**`:292` の 400 行に撤回済みの条件が残る** (重大 R3-4)。403/404 の使い分け (`:295`〜`:299`) と 403 の 16 本は機械検査済みで健全 |
| **A-7** 共有・公開 | **回答あり。ただし 6 書で不整合** | SSOT は `docs/design/auth.md` §6.12 (`:1281`〜`:1298`)。**下流の `settings.md` / `themes.md` §3.2 / `assets.md` D-AS-12・A-4 / `frontend.md` / `README.md` §2.5 が未追随** (重大 R3-1〜R3-6)。**`asset_folders` は書き込み経路そのものが無い** (重大 R3-7)。回答表からアイデアが落ちている (中 R3-M6) |
| A-6 LLM への越境 | **回答あり (本巡の変更と無関係)** | `docs/design/architecture.md` §3.8.2 / `docs/design/API/README.md` §2.4 |
| O-2 / O-3 / O-4 | **回答あり (本巡の変更と無関係)** | `docs/design/data-model.md:728` / `:757` / `:928` (項目 1 の是正で 2 値化が全箇所に届いている) |
| D-6 Agent 再発行 | **回答あり (本巡の変更と無関係)** | `docs/design/API/conversation.md` §4.1 + `scripts/check-endpoint-mapping.sh` の検査⑤ |

---

## 9. 良かった点

1. **項目 4 (アイデアの `visibility` 書き込み経路) の解き方が本巡で最良**。
   `docs/design/API/ideas.md:118`〜`:119` は ①経路 (`PUT /ideas/{idea_id}` の body) ②専用エンドポイントを作らない理由
   ③テーマだけ専用エンドポイントを持つ非対称の説明 ④変更できるのは所有者のみ ⑤**この経路が無いと C-16 に違反する理由**
   の 5 点を書いており、さらに `:461` で「`visibility` だけの変更では版を切らない」を **BE-4 (stale 判定の誤検知) と結びつけて**決めている。
   2 巡目が「BE-10 の設計版」と指摘した構造が、**副作用まで含めて潰されている**
2. **項目 1 (`route_kind` の 2 値化) が同一ファイル 4 箇所すべてに届いた**。
   `data-model.md:728` の列注記には「2026-08-02 に 2 値化」の日付まで入り、`:1251` (R-DM-8 の状態列) では
   **行番号引用を節番号参照に改めている** (「行番号の引用は機構の追記でずれるため」)。DR-9 の運用意図に沿った是正
3. **2026-08-03 の是正 C (R-11 の状態列) の書き方が模範的**。
   `docs/design/auth.md:1548` は「実施済み」に書き換えるのではなく、
   **「未対応のまま『実施済み』と誤記されていた」+ 誤記の中身 (R-12 の内容が貼られていた) + 発覚の経緯 (実行した grep) + 同日修正の内容**
   を残した。**同じ誤りの再発をレビュアーが検出できる形**になっており、DR-8 の還流として正しい
4. **`assets.md:147` が DR-7 の裏面を明文化している**。
   「**プロトタイプに UI が無いことは『機能を落とす理由』にならない** (DR-7 の裏面 — プロトタイプは仕様ではないのだから、**無いことも仕様ではない**)」。
   AS-Q3 のクローズを誤りとして撤回した経緯とセットで書かれており、C-16 の判断基準として再利用できる
5. **`v2-feature-inventory.md` §5 が C-16 の完了条件を機械的に追える形になっている**。
   「対象外 (要確認) が空になることが C-16 の完了条件」+ 残 6 件の明示 + 解消済み 4 件を取り消し線で残す形式。
   **本巡で発見した R3-1 は、この台帳が扱う「v2 ルート単位」より細かい粒度 (増分の後ろ倒し) だったため素通りした** —
   台帳の設計自体は健全で、**必要なのは増分列の追加** (中 R3-M8)

---

## 10. Design Freeze の可否

**不可 (Blocked)**。

| 重大 | 性質 | 修正規模 |
|---|---|---|
| **R3-4** (`README.md:292` の 400 行) | **A-5 の SSOT が撤回済みの仕様を書いている**。UT 規約と対になっているため**誤った仕様が CI で固定される** | **1 行** |
| **R3-5** (`assets.md:144` / `:180`) | 設計判断表と本番観点回答表が「増分 2」。2 巡目 Freeze 条件 #3 の未実施分 | **2 行 + 却下欄 1 文** |
| **R3-6** (`frontend.md:425` / `:996`) | **同一箇条書き内の自己矛盾**。BE を直しても FE に導線が無ければ C-16 は達成されない | **2 行 + `auth.md` R-10 の状態列** |
| **R3-2** (`themes.md:131`〜`:132`) | **DM-9 が「開放時期の SSOT」と名指しした表が旧設計**。WHERE 句の定義元 | **表 1 つ (2 行 → 1 行)** |
| **R3-3** (`settings.md:106` ほか) | 撤回済みの「常に `private`・400」。**却下欄と採用案が同一ファイル内で逆** | **表 1 つ + 却下欄 1 文** |
| **R3-1** (`/settings/workspace` の増分) | **上流 `requirements.md:50` の確定が設計に 1 箇所も届いていない**。C-16 の 3 要件のうち「契約単位の既定値」が増分 1 に無い | **3 ファイル 8 箇所 + 是正要求の新規起票** |
| **R3-7** (`asset_folders.visibility`) | **書く側が無い読む側** (BE-10)。ツリー表示とフラット表示で見える集合が食い違う | **判断 1 件** (経路を足す / 列を落とす) |

### Freeze 可にするための最小の修正 (依存順)

| # | 修正 | 対象 |
|---|---|---|
| 1 | **`/settings/workspace` を増分 1 にする** (`requirements.md:50` の確定を反映)。`[Answer]` は消さず「2026-07-31 に撤回」を追記 | `docs/design/API/settings.md:40`・`:58`〜`:59`・`:66`・`:67`・`:73`・`:226`〜`:234` / `docs/design/API/README.md:489`・`:490` / `docs/design/frontend.md:779` |
| 2 | **`settings.md` §3.2 の増分対応表を 1 行に畳む** + 却下欄 (`:114`〜`:115`) を「撤回」に書き換え + `:42` の根拠列末尾を修正 | `docs/design/API/settings.md:104`〜`:115`・`:42` |
| 3 | **`themes.md` §3.2 の増分ゲート表を 1 行に畳む** | `docs/design/API/themes.md:129`〜`:132` |
| 4 | `README.md` §2.5 の 400 行を「`scope` の値域外」へ | `docs/design/API/README.md:292` |
| 5 | `assets.md` D-AS-12 / A-4 を増分 1 へ (却下欄 (b) の締めも) | `docs/design/API/assets.md:144`・`:180` |
| 6 | `frontend.md` §5.4 の 2 行目と §14 の A-7 を増分 1 へ + `auth.md` R-10 の状態列を更新 | `docs/design/frontend.md:425`・`:996` / `docs/design/auth.md:1549` |
| 7 | **`asset_folders.visibility` の書き込み経路を決める** (足す / 列を落とす。**無言で残さない**) + 決めたら AS-M1 に初期値規則 | `docs/design/API/assets.md:46`・`:47`・`:145`・`:167` |
| 8 | `auth.md` §10.4 の前文を実態化 (「2 書」を数えない) + **`API/settings.md` 宛ての是正要求を新規起票** + `:1552` から決着済みの ST-Q8 を落とす | `docs/design/auth.md:1542`・`:1552` |
| 9 | A-7 回答表に**アイデア**を追加 | `docs/design/auth.md:1325` / `docs/design/API/auth-accounts.md:703` |

**中 8 件のうち R3-M2 / R3-M3 / R3-M6 は上記 1・8・9 で自動的に解消する**。
残る R3-M4 / R3-M5 / R3-M7 / R3-M1 / R3-M8 は Freeze の条件にしない。
ただし **R3-M8 (増分列の無検査) は次の増分が始まる前に塞ぐ方が安い** —
R3-1 が 3 巡生き残った直接の原因が「両側が同時に古いと本数照合で一致してしまう」ことだった。

### 4 巡目の確認方法 (**2 巡目の手順を修正したもの**)

2 巡目の再検査手順 #1 (`grep -rn "増分 2"`) は R3-2 / R3-3 を取りこぼした。以下に差し替える:

1. `grep -rn "増分 2" docs/design/` の残存が **`theme_members` / `/themes/[themeId]/members` / `themes.md:152`・`assets.md:180` の「増分 2 でも作成者のみ」だけ**になること
2. **`grep -rn '^| \*\*[12]\*\* |' docs/design/`** — **表の増分列 (裸の数字)** を全件目視する (**新規。R3-2 / R3-3 の再発防止**)
3. **`grep -rn 'ST-Q8' docs/ aidlc-docs/`** — `requirements.md:50` (前倒し確定) と矛盾する記述が 0 件になること (**新規**)
4. `grep -rn "BE が 400\|400 で拒否" docs/design/frontend.md` が **0 件**になること
5. `grep -rn "visibility" docs/design/API/assets.md | grep -i "folder"` に**書き込み経路が現れる**こと (**新規。R3-7**)
6. `grep -rn "scope=contract. を増分 1 で指定" docs/design/` が **0 件**になること (**新規。R3-4**)
7. `make check` の再実行

---

## 11. 本レビューのカバレッジの正直な申告

- **全数照合していない**: 出典の照合は**本巡 7 件** (1 巡目 24 / 2 巡目 9 と合わせて 40 件)。
  内容の誤りが 0 件だったため全数照合トリガーには該当しないが、**残る引用は未確認**である
- **未調査の範囲**: `templates/app-monorepo/backend/` 配下の新規スキャフォールド・`機能一覧.md` (**依頼により対象外**)、
  `docs/prototype/` の HTML と行番号引用、`docs/design/knowledge.md` / `news.md` / `conversation.md` /
  `observability.md` / `operations.md` / `infrastructure.md` / `testing.md` / `architecture.md` の通読
  (本巡の論点 = `visibility` / `scope` / 増分 に接続する箇所のみ grep で走査した)、
  `aidlc-docs/aidlc-state.md` / `todo.html`
- **本巡で実施しなかった検証**: **故障注入を行っていない** (2 巡目が検査⑤⑥⑦ に対して実施済みで、
  本巡の差分にスクリプト変更が含まれないため)。中 R3-M8 の提案検査は**未実装・未検証**である
- **「見つからなかった」と「存在しない」の区別**: R3-7 の「`asset_folders` の `visibility` に関する決定が無い」は、
  `docs/design/API/assets.md` 全文の `visibility` / `Folder` / `asset_folders` の 3 軸で検索した結果の**未発見**である。
  `docs/design/` の他ファイルにフォルダの可視性の決定が置かれている可能性は排除していない
- **実施した機械検証**: `make check` 5 ゲート (エラー 0)。ただし **重大 7 件はすべて機械検査の対象外**であり、
  `05-harness.md` が書くとおり「**doc-lint が通った = 設計が正しい**」ではない
