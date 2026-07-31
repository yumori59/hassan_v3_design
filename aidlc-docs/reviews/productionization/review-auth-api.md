# レビュー: 認証・テナント境界 + API 設計 (`docs/design/auth.md` + `docs/design/API/` 全 7 ファイル)

> 実施日: 2026-07-29 / レビュアー: `design-reviewer` (別セッション・第三者視点・本番基準)
> 判定: **重大 7 件 — Design Freeze 不可。うち 3 件はテナント内の情報露出または機能退行に直結する**

## 0. 対象 / 実行した検証 / 一次ソース照合

### 0.1 レビューした設計成果物 (リポジトリ相対パス)

- `docs/design/auth.md`
- `docs/design/API/README.md`
- `docs/design/API/themes.md`
- `docs/design/API/assets.md`
- `docs/design/API/knowledge.md`
- `docs/design/API/idea-boards.md`
- `docs/design/API/news.md`
- `docs/design/API/settings.md`

整合性確認のために読んだが**レビュー対象外** (別レビュアー担当): `docs/design/architecture.md`、`docs/design/observability.md`。
事実の出典として参照: `docs/analysis/v2-auth-tenancy.md`、`aidlc-docs/inception/productionization/requirements.md`。

**呼び出し時の前提の訂正**: `knowledge.md` / `idea-boards.md` / `news.md` / `settings.md` は
「未作成スタブ」ではなく**いずれも完成した設計文書**である (118〜343 行 / 13〜46 KB)。
したがって「未作成文書に依存したまま回答済みになっている」という DR-2 変種は**該当なし**。
ただし**先送り先の実在性については別の問題が見つかった** (中 3)。

### 0.2 実行した検証コマンドの出力

```
$ cd /Users/yuyamorishita/aillio/hassan/hassan_v3 && make doc-lint
（抜粋。全 18 警告のうち本レビュー対象に関わるもの）
[WARN ] ./docs/design/auth.md:537 未回答の [Answer]:
[WARN ] ./docs/design/auth.md:542 未回答の [Answer]:
[WARN ] ./docs/design/auth.md:548 未回答の [Answer]:
[doc-lint] 対象 54 ファイル / エラー 0 件 / 警告 18 件
(exit 0)
```

```
$ cd /Users/yuyamorishita/aillio/hassan/hassan_v3 && make check-traceability
[traceability] productionization: 22/22 カバー — OK
[traceability] 照合 1 feature / 未カバーあり 0 feature
(exit 0)
```

**doc-lint はエラー 0** で通る。ただし警告のうち **auth.md の 3 件の未回答 `[Answer]`** は、
そのうち Q-A2 が API 側で既に確定扱いになっている (中 6) ため単なる警告として片付けられない。
`make check-traceability` は **AC → 設計書の方向のみ**を照合するため、
逆方向 (設計判断に対応する AC が無い) は検出できない — 実際に 1 件見つかった (中 9)。

### 0.3 一次ソースで照合した事実

**照合件数: 34 件** (`hassan-v2-backend` の Go / SQL、`claude_managed_agents`)。
**設計文書側の誤りは 0 件** — 行番号レベルまで一致した。以下は主要なもの。

| # | 設計側の記述 | 一次ソース | 判定 |
|---|---|---|---|
| 1 | ヘッダ名 `X-Token` / `X-Admin-Token` / `Auth-Token` (auth.md §1.1) | `hassan-v2-backend/auth/middleware.go:15`, `:16`, `:17` | **一致** |
| 2 | ロール値は `"User"` / `"Consultant"` (auth.md §1.2) | `hassan-v2-backend/auth/client.go:28`, `:29` | **一致** |
| 3 | `AuthRoleConsultant` の参照 0 件・`switch role` に `case AuthRoleUser` のみ・`default` 無し・フォールスルー時に `c.Abort()` を呼ばない (auth.md §5-2) | `hassan-v2-backend/auth/client.go:29` (定義以外の参照 0)、`hassan-v2-backend/auth/middleware.go:49-84` | **一致 (時限爆弾の記述は正確)** |
| 4 | **v2 のテーマ一覧は所有者パラメータの契約一致を検証しない** (auth.md §5-1 / README F-15) | `hassan-v2-backend/usecase/theme/list_themes.go:56-62` が `GetAccountByID` の nil 判定のみ、直後に `ListThemesByAccountID` を呼ぶ。当該クエリは `hassan-v2-backend/db/queries/account.sql:1-2` の `SELECT * FROM accounts WHERE id = $1` | **一致 (結論を左右する事実)** |
| 5 | `GET /themes/:id` に所有者チェック無し・3 層すべてで欠落 (auth.md §5-1) | `hassan-v2-backend/db/queries/theme.sql:1-2` (`SELECT * FROM themes WHERE id = $1`)、`hassan-v2-backend/usecase/theme/get_theme_by_id.go:30-50` (`input.AccountID` を `CountIdeaAndBusinessPlanByThemeID` にしか使わない) | **一致** |
| 6 | **36 テーブル中 `account_id` 17 / `contract_id` のみ 5 / `company_id` 0 / どちらも無し 14** (auth.md §2.2) | `hassan-v2-backend/db/schema.sql` を機械集計。**テーブル名リストまで完全一致** | **一致 (結論を左右する事実)** |
| 7 | `themes` は 6 カラム (themes.md §1) / `asset_documents` は 4 カラム・所有者への FK 無し (auth.md §2.3) | `hassan-v2-backend/db/schema.sql:94-102` / `:510-516` | **一致** |
| 8 | `sharing_settings` の PK は `(contract_id, category)` (README F-16) | `hassan-v2-backend/db/schema.sql:491-499` | **一致** |
| 9 | v2 の S3 は `ACL: types.ObjectCannedACLPublicRead` + 恒久無署名 URL。用途はアイコンと企画書サムネイル。`Presign` の参照 0 件 (README D-API-14' / D-KN-10) | `hassan-v2-backend/aws/s3.go:46`, `:58`, `:62-65`, `:68-71`。`Presign` grep = 0 | **一致 (結論を左右する事実)** |
| 10 | 契約内ロールは 1 = 管理者 / 2 = メンバー、`IsAdmin()` で判定し 403 を返す (settings.md §3.1) | `hassan-v2-backend/entity/auth_role.go:7-10`、`hassan-v2-backend/controller/event_logs.go:47-50` | **一致** |
| 11 | ボード内ロール 3 段と `Role()` / `HasAccess` / `CanEdit` / `IsAdmin` (idea-boards.md V-3 / §3.1) | `hassan-v2-backend/entity/idea_board.go:14-16`, `:95-110`, `:113-115`, `:118-121`, `:124-126` | **一致** |
| 12 | **`ListIdeasForBoard` に `board_id` が一切現れない**・中身は `filter` の評価結果 (idea-boards.md V-1) | `hassan-v2-backend/db/queries/idea_board.sql:80-140` (`board_id` の出現 0 件)、`hassan-v2-backend/usecase/idea_board/list_idea_boards.go:47` が `b.Filter` を渡す | **一致 (結論を左右する事実)** |
| 13 | `ideas.memo` / `ideas.phase` はアイデア単位・`ideas` に `is_deleted` が無い・所有者列が無く 2 段チェーン (idea-boards.md V-2 / A-3') | `hassan-v2-backend/db/schema.sql:151-178` (`memo` は `:173`、`phase` は `:174`、`is_deleted` 無し、`account_id` / `contract_id` 無し) | **一致** |
| 14 | `idea_board_phases.color_code text NOT NULL DEFAULT '#0455C5'` と `UNIQUE(contract_id, name)` (idea-boards.md D-IB-4') | `hassan-v2-backend/db/schema.sql:619`, `:624` | **一致** (前回レビューで指摘された `:618` 誤記は修正済み) |
| 15 | `Group.Use()` の順序依存で `:199-200` に管理者認証がかからない (auth.md §1.7) | `hassan-v2-backend/router/router.go:198` (Group)、`:199-200` (2 ルート)、`:201` (`.Use()`) | **一致 (gin の挙動の説明も正確)** |
| 16 | prod でリクエストログが二重に無効化 (auth.md §5-6) | `hassan-v2-backend/router/router.go:50-54` | **一致** |
| 17 | v2 の `notFound` / `forbidden` はボディ無し・`badRequest` は `{code,msg}` (README F-7 / F-9) | `hassan-v2-backend/controller/controller.go:42`, `:50`, `:58`, `:105-125` | **一致** |
| 18 | v2 の `GET /news` は `has_unread` の真偽値のみ・`POST /news` に記事 ID が無い (news.md D-NW-3 / D-NW-4) | `hassan-v2-backend/controller/news.go:35-46`, `:59` | **一致** |
| 19 | v2 に `PATCH` の登録が 0 件 (themes.md D-TH-8) | `hassan-v2-backend/router/router.go` の `.PATCH(` = 0 件 | **一致** |
| 20 | `ThemeNameDuplicationError` の実在 (themes.md D-TH-6) | `hassan-v2-backend/controller/apperror/error.go:188` | **一致** |
| 21 | CORS 許可リストがハードコード (README F-14 / API-Q2) | `hassan-v2-backend/internal/corsutil/origin.go:10` の `productionWebOrigins` | **一致** |
| 22 | PoC の custom tool にテナント概念が無い (`08-production-gates.md` A-6 の前提) | `claude_managed_agents/cmd/devui/conversation_tools.go` に `account_id` / `accountID` / `ownerID` の出現 0 件 | **一致** |
| 23 | エンドポイント総数 73・LLM 3 本・SSE 2 本・403 11 本 (README §3) | 各ドメインファイルの一覧表を数え上げ: 9+17+15+21+5+6 = **73**、LLM = assets 1 + knowledge 2 = **3**、SSE = **2**、403 = settings 3 + idea-boards 8 = **11** | **一致** |
| 24 | `restrictToSelf` は「非共有かつ自分が作成者」のときだけ true (README F-16 3 行目) | `hassan-v2-backend/usecase/idea_board/list_idea_boards.go:46` | **一致 — ただしこの事実の帰結が移行設計に反映されていない (重大 1)** |

**軽微なズレ 2 件** (誤りではないが精度が落ちている): 軽微 1 / 軽微 2 に記載。

---

## 1. サマリ

- **重大 7 件 / 中 10 件 / 軽微 5 件**
- 出典の正確性・曖昧語の排除・却下案の記録は**極めて高い水準**にある (照合 34 件で誤り 0、曖昧語 0 件)。
  指摘はすべて「**書かれていない帰結**」と「**文書間で判断が割れている箇所**」に集中している。
- 重大の内訳:
  - **既存データの露出 / 退行** 2 件 (重大 1・重大 2) — いずれもアイデアボードの移行。
    一次ソースで確認した v2 の**閲覧者依存のボード評価**が設計に落ちていない。
  - **A-4 / A-5 の機械強制の穴** 3 件 (重大 4・重大 5・重大 6) — 宣言はあるが、
    v2 で実測された穴 (F-15) をその検査が捕まえられない。
  - **SSOT 間の矛盾** 2 件 (重大 3・重大 7) — `auth.md` が SSOT を宣言している論点で、
    API 側と正反対または両立しない記述になっている。

---

## 2. 重大 (Must Fix)

### 重大 1. `docs/design/API/idea-boards.md:232-241` (§4 M-1) — v2 のボード評価は**閲覧者依存**であり、静的アイテムに凍結すると非共有契約でボードが一斉公開になる

**該当**: `docs/design/API/idea-boards.md:237` (「v2 の `ListIdeasForBoard` と**同じ条件**で `ideas` を評価」)、`:241` (検証手順)

**一次ソースで確認した v2 の実態**:

| 事実 | 出典 |
|---|---|
| `ListIdeasForBoard` の絞り込みは `WHERE a.contract_id = @contract_id` を基点にし、`restrict_to_self` は**引数で渡される可変条件** | `hassan-v2-backend/db/queries/idea_board.sql:114`, `:116` (`AND (NOT @restrict_to_self::bool OR ih.account_id = @auth_account_id::uuid)`) |
| その引数は**閲覧者ごとに計算される**: `restrictToSelf := !isShared && b.CreateAccountID == input.AccountID` | `hassan-v2-backend/usecase/idea_board/list_idea_boards.go:46` |

つまり**同一のボードが、見る人によって異なるアイテム集合を返す**。
`sharing_settings(category=idea)` が OFF の契約では、**作成者が見ると自分のアイデアのみ**、
**viewer / editor が見ると契約内の全アイデア**が返る (`restrictToSelf` が false になるため)。

**なぜ本番で問題になるか**: M-1 は静的な `idea_board_items` 行を 1 セットだけ作る。
閲覧者依存の集合を 1 つに潰す以上、どちらかの側が必ず変わる。

- `restrictToSelf = false` で materialize した場合 → **共有 OFF の契約で、作成者が自分のボードを開くと
  これまで見えていなかった同僚のアイデアが全件現れる**。
  これは `themes.md` §3.2 TM-1 / `assets.md` §3.2 AS-M1 が「切替が一斉公開になる」として
  厳密に避けた DR-3 の事故を、**ボードで再現する**ことになる。
- `restrictToSelf = true` で materialize した場合 → viewer / editor が v2 で見えていたアイテムが消える。

さらに §4 M-1 の検証手順「移行前後で各ボードの `ListIdeasForBoard` 件数と `idea_board_items` の件数が
一致することを全ボードで照合する」は、件数が閲覧者ごとに違うため**原理的に成立しない**。
M-1 の「注意」欄は旧単数キーの `UnmarshalJSON` 後方互換にしか触れておらず、
`restrict_to_self` / `auth_account_id` という 2 つの引数の存在自体が記述されていない。

**修正案**:

1. M-1 の処理欄に `restrictToSelf` の決定規則を書く。推奨は
   **`themes.md` TM-1 / `assets.md` AS-M1 と同じ規則に揃える** —
   「`sharing_settings(category=idea)` が `true` の契約は `restrictToSelf=false`、
   `false` またはレコード無しの契約は `restrictToSelf=true` で materialize する」。
   これで「切替前後で見える範囲を変えない」がボードでも成立する (作成者視点を正とする)。
2. 上記により **共有 OFF の契約のボードで viewer / editor が見えていたアイテムは失われる**ため、
   その件数を移行ログに出し、IB-Q10 (memo のスコープ変更の告知) と同じ扱いで
   リリースノートに含めることを §4 に明記する。
3. 検証欄を「**作成者視点の `ListIdeasForBoard` 件数**と `idea_board_items` の件数が一致すること」に
   限定し、閲覧者依存であることを注記する。

### 重大 2. `docs/design/API/idea-boards.md:85` と `:292` — ボードへ追加できるアイデアの範囲が同一ファイル内で矛盾し、増分 1 で機能退行になる

**該当**: `docs/design/API/idea-boards.md:85` (`POST /idea-boards` の「**400** (契約外のアカウント ID / **他人のアイデア ID**)」)、
`:90` (`POST /idea-boards/{board_id}/items` の固有ステータスに他人のアイデアの規定なし)、
`:292` (A-4 行「`idea_id` は**すべて契約と組で検証**する (他契約の ID は 404)」)、
`:102` (`GET /ideas` は増分 1 で `scope=mine` のみ)

**矛盾の内容**:

| 経路 | 他契約のアイデア | **自契約・他人**のアイデア |
|---|---|---|
| `POST /idea-boards` (`:85`) | 400 | **400 (拒否)** |
| `POST /idea-boards/{board_id}/items` (`:90`) | 404 と読める | **規定なし** |
| A-4 行 (`:292`) | 404 | **許可 (契約と組で検証)** |

**なぜ本番で問題になるか**: v2 のボードは既定で**契約横断**のアイデアを載せる
(`hassan-v2-backend/db/queries/idea_board.sql:114` の `WHERE a.contract_id = @contract_id`。照合済み)。
重大 1 の M-1 を実施すれば、切替直後のボードには**同僚のアイデアが載っている**。
一方で増分 1 の追加系 API は `POST /idea-boards` が他人のアイデアを 400 で拒否し、
`GET /ideas` は `scope=mine` のみなので**選択元の一覧にも他人のアイデアが出てこない**。
結果として「**載っているものは見えるのに、新しく追加できず、一覧からも選べない**」という
共同レビュー用途 (プロトタイプの `BOARDS[].shared`) の中核が壊れた状態で出ることになる。
しかも 2 つの追加経路で判断が食い違っているため、実装者がどちらに寄せても片方の仕様と矛盾する。

**修正案**:

1. **判断を 1 つに決めて 3 箇所を揃える**。推奨は A-4 行 (`:292`) に寄せる —
   「ボード配下ではボードメンバーが操作対象にできるアイデア = **同一契約のアイデア**とし、
   他契約は 404 / 自契約・他人は許可」。`:85` の「他人のアイデア ID → 400」を削除する。
2. `GET /ideas` に**ボード追加用の選択元を返す経路**を用意する。
   増分 1 で `scope=contract` を全面解禁しない方針 (D-API-8') と両立させるには、
   `GET /idea-boards/{board_id}/addable-ideas` のようなボード配下の限定エンドポイントか、
   `GET /ideas?scope=contract` を「`board_id` 指定時のみ増分 1 で許可」とするかを選ぶ。
   **どちらも増やさない (退行を受容する) と決める場合は、その旨を IB-Q2 / IB-Q6 に明記し、
   「v2 でできていたことができなくなる」ことをリリースノート項目として §4 に加える**。
3. `POST /idea-boards/{board_id}/items` の固有ステータス列に、他契約 (404) と
   自契約・他人 (許可) の扱いを明示する。

### 重大 3. `docs/design/auth.md:419-436` (§6.4) / `:479-481` (§6.6 の帰結) — 「403/404 の取り違えが構造的に起きない」がリソース単位ロールと両立せず、実装者を誤導する

**該当**: `docs/design/auth.md:428` (「Repository: 単一取得系も含め、**すべてのクエリが所有者条件を `WHERE` に持つ**」)、
`:431` (「却下 (a) UseCase の read-then-compare を正とする (v2 パターン B)」)、
`:479-481` (「他テナントのリソースは 0 件として返る … **403 と 404 の取り違えが構造的に起きない**」)、
対応する API 側: `docs/design/API/README.md:231-236`、`docs/design/API/idea-boards.md:167` (D-IB-11)、`:175-197` (§3.1)

**両立しない理由**: `README.md` §2.2 の **R-2 (リソース単位ロール)** は、
viewer に **403**、非メンバーに **404** を返すことを要求する。
この 2 つを区別するには「ボード行を取得したうえで `viewer_account_ids` / `editor_account_ids` を評価する」
必要があり、**Repository のクエリ条件でメンバーシップを絞り込んではいけない**
(絞り込むと viewer も 0 件になり 404 に落ちる)。
v2 も実際にこの形で実装されている — `ListIdeaBoardsByContractID` (`WHERE contract_id = $1`) で
取得したのち Go 側で `if b.HasAccess(input.AccountID)` を評価している
(`hassan-v2-backend/usecase/idea_board/list_idea_boards.go:28`, `:44`。照合済み)。
これは `auth.md` §6.4 が「主たる防御にしない」として却下した**パターン B そのもの**である。

**なぜ本番で問題になるか**: `auth.md` は「v3 の認証・認可・テナント設計の判断の SSOT」を
自ら宣言している (`:8`)。その SSOT が「read-then-compare は却下」「WHERE で絞れば取り違えは起きない」と
書いているため、**ボード・アイテム・コメントを実装する開発者は §6.4 の指示に従って
メンバーシップを `WHERE` に入れる**方向へ誘導される。そうすると viewer が 404 を受け取り、
`README.md` §2.5 / `idea-boards.md` §3.1 の 403 設計 (8 本) が静かに壊れる。
逆に §3.1 に従えばロール判定が Go 側の分岐に戻り、**§5-1 (`GET /themes/:id` の IDOR) を生んだのと
同じ「実装者が書き忘れると素通り」構造**が、`auth.md` の中では対策済みと書かれたまま残る。

**修正案**: `auth.md` §6.4 の層表に**第 3 のパターン**を追加し、§6.6 の断定を限定する。

1. §6.4 に行を追加 — 「**リソース単位ロールを持つドメイン** (アイデアボード):
   (a) Repository は `contract_id` で絞る (メンバーシップは `WHERE` に入れない)、
   (b) ロール判定は entity の単一メソッド (`HasAccess` / `CanEdit` / `IsAdmin` 相当) に集約し
   UseCase から必ずそれを呼ぶ、(c) **操作 × ロールの全組み合わせを表駆動の UT で網羅する**
   (`docs/design/API/idea-boards.md` §3.1 の権限表をそのままテストの入力にする)」。
2. §6.6 の「**403 と 404 の取り違えが構造的に起きない**」を
   「**個人スコープでは構造的に起きない。リソース単位ロールを持つドメインでは
   entity の単一メソッド + 網羅 UT で担保する**」に書き換える。
3. §6.4 の機械強制の箇条書きに「(c) の網羅 UT を D-2 のマージ条件に含める」を追加する
   (現状の CI 検査は SQL とコンパイル時型のみで、ロール判定の漏れを検出できない)。

### 重大 4. `docs/design/API/themes.md:146` / `docs/design/API/assets.md:159` — 増分 2 で 403/404 の判定境界が破れ、「403 は 11 本」が誤りになる

**該当**: `docs/design/API/themes.md:146` (A-4 行「**更新・削除は増分 2 でも作成者のみ** (他人のテーマ指定は 404)」)、
`docs/design/API/assets.md:159` (同文)、
`docs/design/API/README.md:225-232` (判定境界表と「403 は … **2 系統のみ** … **合計 11 本**」)

**矛盾の内容**: 増分 2 では `visibility = contract` のテーマ / アセットは他メンバーから
**`GET` で 200 で読める** (`themes.md` §3.2 の増分 2 行、`:48` のスコープ列)。
その同じリソースへの `PUT` / `DELETE` を **404** で返すと:

- `README.md` §2.5 の判定境界表 (「**見える (取得できる) + 操作権限 無し → 403**」) に反する
- `idea-boards.md` §3.1 が明記した理由 (「取得できたものが更新では存在しない、という
  **矛盾したクライアント挙動**を生むだけで秘匿効果が無い」) に反する
- 「403 は R-1 (3 本) + R-2 (8 本) の**合計 11 本**」という総数が増分 2 で成立しなくなる
  (`AC-1.4` が要求する一覧が増分 2 で不正確になる)

**なぜ本番で問題になるか**: FE は 404 を「消えた / 存在しない」として一覧から除去する実装を書く。
増分 2 で「一覧には出るが更新すると 404 が返り、リロードすると再び出てくる」という
再現性のある不具合になる。かつ AC-1.4 の一覧表が実挙動と食い違ったまま Freeze される。

**修正案**:

1. `README.md` §2.2 に **R-3 (リソース所有者限定)** を追加する —
   「契約内で**読める**リソースに対する更新・削除は、**所有者 (作成者) のみ**。
   所有者以外は **403**」。対象: 増分 2 の `PUT`/`DELETE /themes/{theme_id}`、
   `PUT /themes/{theme_id}/visibility`、`PUT`/`DELETE /assets/{asset_id}`、
   `PUT /assets/{asset_id}/function-tree`、`POST`/`DELETE /assets/{asset_id}/documents`。
2. `README.md` §2.5 の適用一覧に R-3 の行を足し、§3 の 403 列を
   **「増分 1: 11 本 / 増分 2: 11 + N 本」**の形で増分別に書く。
3. `themes.md:146` / `assets.md:159` の「他人のテーマ指定は 404」を
   「**増分 1 は 404 (そもそも読めない) / 増分 2 で `visibility=contract` により読めるものは 403**」に訂正する。

### 重大 5. `docs/design/API/assets.md:54` — `created_by` が実質 owner-ID パラメータなのに、増分ゲート・検証・機械検査のいずれも掛かっていない

**該当**: `docs/design/API/assets.md:54` (`GET /assets` の `Q: … / created_by / …`)、
`docs/design/API/assets.md:106` (D-AS-8 に `created_by` の検証記述なし)、
`docs/design/API/README.md:106` (D-API-8: 「`created_by` は**契約スコープでの作成者絞り込みが必要な場合のみ**許し、
**サーバが必ず自契約メンバーであることを検証**する」)、
`docs/design/API/README.md:150` (§1.4 の CI 検査は文字列 `account_id` のみを対象)

**問題**: D-API-8 は `created_by` に 2 つの条件 (契約スコープ限定 + 自契約メンバー検証) を付けているが、
適用先の `assets.md` は**どちらも書いていない**。表は `created_by` を増分 1 のクエリに無条件で並べ、
固有ステータス列にも `400` (契約外のメンバー ID) が無い。
さらに §1.4 の CI 検査「`swagger.json` の全 query パラメータに `account_id` が現れないこと」は
**名前ベース**なので `created_by` を検出できない。

**なぜ本番で問題になるか**: `08-production-gates.md` A-4 が名指しする形
(「所有者 ID をパラメータで受け取る API で、その所有者が呼び出し元と同じ契約に属することを検証しない」)
が、**別名で復活する**。v2 の F-15 は `account_id` という名前だったから設計で潰せたが、
`created_by` は「制作者フィルタ」という UI 用語のまま素通りしている。
本設計が「最も事故が大きい規約なので機械検査を必須にする」(`README.md:150`) と宣言した
まさにその規約が、名前が違うだけで無効化される。

**修正案**:

1. `assets.md:54` の `created_by` に「**増分 2 (`scope=contract` と同時)**。
   サーバが**自契約メンバーであることを検証**し、範囲外は **400**
   (コード・メッセージで「契約外」と「不存在」を区別しない)」を明記し、
   固有ステータス列に `400` を追加する。D-AS-8 にも同文を書く。
2. `README.md` §1.4 の CI 検査を**名前ベースから形ベースに拡張**する —
   「query パラメータ名が `account_id` / `created_by` / `owner_id` / `*_account_id` /
   `*_by` のいずれかに一致するものを禁止。許可リストは 1 箇所に列挙し、
   列挙されたものは自契約検証の UT を必須とする」。
3. 同じ検査漏れが `GET /assets` 以外にないかを確認する
   (`GET /activity-logs` の `account_id` は既に許可リストに入っている ―
   `settings.md:62`。他に owner-ID 相当の入力が無いことを表で示すとよい)。

### 重大 6. `docs/design/auth.md:439-442` / `docs/design/API/README.md:149` — A-4 の機械強制が、**v2 で実測されたテナント越境 (F-15) をそもそも検出できない**

**該当**: `docs/design/auth.md:439-442` (「CI で `db/queries/*.sql` の `-- name: Get*` に
所有者条件があるかを検査する (v2 の `GetThemeByID` 相当を弾く)」)、
`docs/design/API/README.md:149` (同じ検査を「所有者引数の強制」として再掲)

**問題**: F-15 の穴は**一覧経路**であり、**SQL 自体は正しかった**。一次ソースで確認した内訳:

| 層 | 状態 | 出典 |
|---|---|---|
| SQL | `WHERE account_id = $1` を**持っている** (正常) | `hassan-v2-backend/db/queries/theme.sql:16` (`ListThemesByAccountID`) |
| 呼び出し側 | **クライアント由来の `account_id` を存在確認だけで渡している** | `hassan-v2-backend/usecase/theme/list_themes.go:56-62` |

したがって:

- 検査対象が `-- name: Get*` だけなので **`List*` / `Count*` が対象外** — F-15 のクエリは検査されない
- 仮に `List*` を含めても、そのクエリは `WHERE account_id = $1` を持つので**検査は合格する**
- `auth.md:443-449` の専用型 (`type AccountID uuid.UUID`) は引数順の取り違えを防ぐが、
  **「その値がクライアント入力由来で未検証か」は型で表現されない**

つまり A-4 の 2 つの機械強制 (SQL の grep + 専用型) を両方通しても、
**08-production-gates.md A-4 が名指しした形 (v2 の theme 一覧) は再発し得る**。
これは重大 5 (`created_by`) と同じ根の問題であり、設計が最も重く扱うと宣言した観点の穴である。

**修正案**:

1. 検査対象を `-- name: Get*` から **`Get*` / `List*` / `Count*` / `Search*`** に拡げ、
   所有者条件を持たないクエリは**ホワイトリスト (マスタ系: `auth_roles` / `idea_board_phases` 等) のみ**
   許すことを `auth.md` §6.4 と `README.md` §1.4 の両方に書く。
2. **専用型の生成経路を 1 箇所に絞る**設計を `auth.md` §6.4 に追加する —
   「`AccountID` / `ContractID` は、認証コンテキスト由来か、
   **契約検証を通したコンストラクタ (例: `NewAccountIDInContract(raw string, caller ContractID) (AccountID, error)`)**
   からのみ生成できる。リクエストパラメータの文字列から直接キャストする経路を作らない」。
   これで「存在確認は所有権の検証にならない」が**型で担保**され、
   重大 5 の `created_by` も構造的に閉じる。
3. `README.md` §1.4 の表に上記 2 件を追加し、D-2 のマージ条件に含める。

### 重大 7. `docs/design/auth.md:509` (§7 A-7) — SSOT 宣言側の A-7 判断が**自書の事実 (§2.2) と矛盾**したまま「対象外 (暫定)」で残っている

**該当**: `docs/design/auth.md:509` (A-7 = 「**対象外 (暫定)**。本増分では共有機能を持たない」)、
`docs/design/auth.md:8` (「v3 の認証・認可・テナント設計の判断 (§6 / §7) は**このファイルが SSOT**」)、
対する API 側: `docs/design/API/README.md:435` (A-7 = 「部分回答」、ボードは v2 の共有を**そのまま引き継ぐ**)、
`docs/design/API/idea-boards.md:295` (A-7 = 「**回答**」、3 段ロールを引き継ぐ)、
`docs/design/API/README.md:453` (API-Q3 として要ユーザー確認)

**問題**: `auth.md` §2.2 は `idea_boards` / `idea_board_phases` が `contract_id` を持つ既存テーブルであることを
**自ら実測して記載している** (照合済み: `hassan-v2-backend/db/schema.sql:599-613`, `:615-625`)。
`idea_boards` は `viewer_account_ids` / `editor_account_ids` を持ち、v2 の本番 DB に既存データがある。
にもかかわらず §7 の A-7 は「本増分では共有機能を持たない」という判断を維持している。
**既に稼働している共有機能に対して「持たない」は選択肢として存在しない**。

**なぜ本番で問題になるか**: 両文書が互いを指して「食い違っている」と注記しているのは誠実だが、
**どちらに従えばよいかが決まっていない**。宣言された SSOT (`auth.md`) に従う実装者は
共有を実装せず、`idea-boards.md` §4 M-4 のロール移行 (viewer/editor の 1:1 写し) が落ちる。
その結果 v2 の viewer/editor 区分が消え、`idea-boards.md` D-IB-8 が
「サイレントな権限昇格」として明確に却下した状態が発生する。
これは「ユーザー確認待ちの未確定」ではなく、**一方の判断が事実として成立しない**種類の矛盾である。

**修正案**:

1. `auth.md` §6 に **§6.8 (A-7)** を新設し、単一の判断を書く —
   「(a) **既存データを持つアイデアボードは v2 の契約内共有と 3 段ロールを引き継ぐ (増分 1)**
   (`docs/design/API/idea-boards.md` D-IB-8 / §4 M-4 が詳細を持つ)。
   (b) テーマ・アセットの per-resource `visibility` と `scope=contract` は増分 2 (D-API-8')。
   (c) それ以外の新規共有機能 (契約外公開・`open`) は本増分では持たない」。
   却下案として「A-7 全体を対象外にする案 — §2.2 の既存データと両立しない」を残す。
2. §7 の A-7 行を「**回答** (§6.8)」に更新する。
3. `README.md` API-Q3 の残課題を「**テーマメンバーの権限差 (TH-Q5) の要件確認のみ**」に縮小し、
   A-7 の判断そのものは残課題から外す。

---

## 3. 中 (Should Fix)

### 中 1. `docs/design/API/README.md:103` (D-API-5) — 「常に `items` + `total_count`」が実際の設計と 9 本以上で食い違い、§1.4 の CI 検査が落ちる

D-API-5 は「**`{"items": [...], "total_count": N}` に統一**。キー名は**常に** `items`」と決め、
§1.4 に「`swagger.json` の 200 レスポンスのうち配列を返すものが `{items, total_count}` の形であること
(裸配列・リソース名キーを弾く)」という CI 検査を置いている。しかし各ドメインファイルの実際の設計は:

| エンドポイント | 設計されたレスポンス | 違反 |
|---|---|---|
| `GET`/`PUT /themes/{theme_id}/members` (`themes.md:51-52`) | `{items:[...]}` | `total_count` なし |
| `GET /asset-folders` (`assets.md:50`) | `{items:[...]}` | 同 |
| `GET /assets/{asset_id}/documents` (`assets.md:64`) | `{items:[...]}` | 同 |
| `GET`/`PUT /knowledge-threads/{thread_id}/files` (`knowledge.md:59-60`) | `{items:[File]}` | 同 |
| `GET`/`PUT /idea-boards/{board_id}/members` (`idea-boards.md:96-97`) | `{items:[...]}` | 同 |
| `GET /idea-board-phases` (`idea-boards.md:98`) | `{items:[...]}` | 同 |
| `GET`/`PUT /assets/{asset_id}/function-tree` (`assets.md:59-60`) | `{version, nodes:[...]}` | **`items` キーですらない** |

ページネーションを持たない固定長の子リソースに `total_count` を強制するのは無意味であり、
機能ツリーはドメイン固有構造なので `items` に押し込むべきでもない。
つまり**規約が実態に合っておらず、宣言した CI 検査が最初から通らない**。
規約を「気をつける」に落とさない仕組みとして CI を置いた意図が無効化される。

**修正案**: D-API-5 を 3 分類に分ける —
「(a) `limit`/`offset` を持つ一覧 = `{items, total_count}` **必須**、
(b) ページネーションを持たない固定長の子リソース = `{items}` (`total_count` 省略可)、
(c) ドメイン固有構造 (機能分解ツリー) = **例外として本表に列挙**」。
§1.4 の CI 検査の対象を「**`limit` パラメータを持つエンドポイント**」に限定し、
(c) の例外リストをコード側の 1 箇所に置く。

### 中 2. `docs/design/API/assets.md:63` — SSE の GET エンドポイントで `X-Token` をどう運ぶかが未決。放置すると JWT が URL とアクセスログに残る

`GET /asset-extractions/{extraction_id}/stream` は全エンドポイント認証必須 (D-API-3 / §2.1) だが、
**ブラウザの `EventSource` はカスタムヘッダを送れない**。決めておかないと実装者は
`?token=<JWT>` に落とし、**JWT が URL・ALB アクセスログ・Referer・ブラウザ履歴に残る**
(D-5 のシークレット管理と O-1 の構造化ログの両方に事故として現れる)。

v2 にも同型の GET SSE がある (`hassan-v2-backend/router/router.go:154` の
`GET /business-plans/jobs/:job_id/stream` に `AuthRequiredMiddleware` が付く。照合済み) ので、
**v2 の FE 実装方式を引き継ぐ**と書けば済む。

**修正案**: D-API-12 に 1 行追加 —
「SSE の購読は **fetch + ReadableStream** で行い、`X-Token` は**ヘッダで送る**。
`EventSource` の使用と、クエリパラメータでのトークン送出を禁止する」。
§1.4 の CI 検査に「query パラメータ名に `token` / `jwt` を含まないこと」を追加する。

### 中 3. `docs/design/API/README.md:135` ほか — 先送り先の `docs/design/observability.md` は**既に存在し該当 ID を回答している**のに「未着手」と書かれ、相対リンクも張られていない

実在確認: `docs/design/observability.md` は §4.1 (O-1 / AC-2.4)、§4.2 (O-2 / AC-2.1)、
§4.3 (O-4 / AC-2.3)、§4.4 (O-3 / AC-2.2)、§4.5 (O-6 / AC-2.5)、§4.6 (O-7) を**回答済み**である。
一方で本レビュー対象は:

- `README.md:135` — 「`docs/design/operations.md` (未着手) と **`docs/design/observability.md` (未着手)** が担う」 → **事実誤認**
- `README.md:436` (O-1) / `:439` (O-4) / `:441` (O-6) — 「observability 設計 (未着手)」
- `README.md:442` (O-7) — 「**対象外**。運用設計 (`docs/design/operations.md`、未着手)」 → 実際の回答は observability.md §4.6
- `themes.md:151` / `assets.md:163,165,166` / `knowledge.md:194,195,196` / `settings.md:176` — 「observability 設計」(リンクなし)

さらに **`failure.code` の値域が 2 文書に分裂**している:
`README.md` §1.3 J-3 が `stale_aborted` を定義しているが、observability.md §4.3 の失敗分類
(F-1 切り詰め / F-2 JSON パース失敗 / F-3 ツール引数不整合 / F-4 タイムアウト / F-5 SSE 異常終了) に
`stale_aborted` は**含まれていない**。どちらも「値域の SSOT」を主張していないため、
実装時にどちらか一方だけを見て不完全な値域を実装する余地がある。

**修正案**: (a) 「未着手」の記述を削り、`docs/design/API/` から見た相対パス `../observability.md` への
Markdown リンク + 節番号に置き換える (doc-lint がリンク切れを検出できる形にする)。
(b) O-7 の先送り先を observability.md §4.6 に訂正する。
(c) `failure.code` の値域 SSOT を observability.md §4.3 に一本化し、
`stale_aborted` を **F-6 (取り残しジョブの回収)** として追記、
`README.md` §1.3 J-3 からそこを参照する形にする。

### 中 4. `docs/design/API/README.md:245-247` (§2.5) — 「他契約のリソース = 404」がボディ / クエリで渡す ID に適用されておらず、4 本が 400 を返す設計になっている

§2.5 は「**他テナント (他契約) のリソースを指定 → 404**。適用範囲: **ID を受け取る全エンドポイント**」と
書いているが、実際には次の 4 本が **400** を返す設計である:

| エンドポイント | 設計 | 出典 |
|---|---|---|
| `PUT /themes/{theme_id}/members` | 400 (契約外のアカウント ID) | `themes.md:52` |
| `GET /activity-logs` | 400 (契約外の `account_id`) | `settings.md:62` |
| `POST /idea-boards` | 400 (契約外のアカウント ID) | `idea-boards.md:85` |
| `PUT /idea-boards/{board_id}/members` | 400 (契約外のアカウント ID) | `idea-boards.md:97` |

パス = リソース同定 (404) / ボディ = 入力検証 (400) という切り分けは十分に妥当だが、
**その基準がどこにも書かれていない**ため §2.5 との矛盾として残る。
加えて「契約外」と「不存在」でコード・メッセージを分けると**契約所属が漏れる**
(A-5 が防ごうとしている情報開示そのもの)。

**修正案**: §2.5 の適用一覧に 1 行追加 —
「**リクエストボディ / クエリ内の他契約アカウント ID・他人のリソース ID → 400 (`CodedError`)。
ただしコードとメッセージで『契約外』と『不存在』を区別しない**」。
判定境界の節に「パスパラメータ = リソース同定 → 404 / ボディ・クエリ = 入力検証 → 400」を明文化する。

### 中 5. `docs/design/API/README.md:100` (D-API-2) — 動作系・集計系サブパスの命名規約が無く、ドメイン間で揺れている。`news_id` は外部採番なので予約語衝突もある

D-API-2 は kebab-case + 複数形 + `{単数_id}` + ネスト 2 段までを決めているが、
**動詞的サブパスと集計エンドポイントの規約が無い**。実際の揺れ:

| 用途 | 実際の設計 | 揺れ |
|---|---|---|
| 一括操作 | `POST /news/read-all` (`news.md:55`) と `POST /knowledge-files/bulk-delete` (`knowledge.md:66`) | 同じ「一括」で別命名 |
| 集計 | `GET /themes/stats` (`themes.md:46`) と `GET /news/unread-count` (`news.md:56`) | 同じ「集計」で別命名 |
| 単一フィールド更新 | `PUT /themes/{theme_id}/visibility`、`PUT /ideas/{idea_id}/star` | 規約なし (D-TH-8 は PUT 全項目置換を採っているので例外) |

§1.4 の CI 検査 (「パスパラメータの命名」) はパラメータ名しか見ないため、これらは検査対象外。

加えて **`news_id` は MicroCMS が採番する文字列** である (`news.md:86`「`news_id` の型は `TEXT` のまま
(CMS の ID 体系に依存するため、v3 で採番しない)」)。
したがって `/news/read-all` `/news/unread-count` は、CMS 側に `read-all` という ID の記事が
作られた瞬間にその記事の詳細が引けなくなる。
v2 の `/accounts/me` vs `/accounts/:id` (`hassan-v2-backend/router/router.go:66-67`。照合済み) は
`:id` が UUID なので衝突しないが、こちらは**外部採番の任意文字列**なので性質が違う。

**修正案**: D-API-2 に「一括操作は `bulk-<動作>`、集計は `<コレクション>/stats` に統一する」を追記し、
`POST /news/read-all` → `POST /news/bulk-read`、`GET /news/unread-count` → `GET /news/stats` のように揃える。
外部採番 ID を持つコレクションについては、**静的セグメントの予約語をサーバ側定数 1 箇所に列挙**し、
起動時または CI で CMS の ID 体系と衝突しないことを検査する (または集計系を別コレクションに逃がす)。

### 中 6. `docs/design/auth.md:539-548` (§9) — 未回答の `[Answer]` が API 側で既に「回答」の土台になっている

doc-lint が警告している 3 件の未回答 `[Answer]` のうち 2 件が、他文書の確定判断の前提になっている。

- **Q-A2 (契約内管理者/メンバー区別を v3 で使うか)** — `auth.md:539-542` で未回答。
  一方 `README.md:182-183` と `settings.md:78-79` は「**使う。ただし用途は R-1 の 3 本に限る**」と
  確定させ、**403 の総数 11 本の根拠**にしている (`README.md:232`)。
  ルート `CLAUDE.md` は「未確定は `[Answer]:` 行で明示する。**回答されないまま確定させない**」を
  規約にしているため、この状態は規約違反にあたる。
- **Q-A1 (v2 と同じ `JWT_KEY` を共有するか)** — `auth.md:533-537` で未回答。
  `settings.md:133` はこれを「**本ファイルの最大の依存**」と正しく書き、
  NO なら D-ST-1 (v2 API 再利用) の前提が崩れると明記している。
  しかし `auth.md` §7 の **A-1 = 「回答」** 行にはこの重みが現れていない。
  Q-A1 が NO なら v3 側にサインイン・パスワードリセット・MFA の API 群が新設され、
  `settings.md` §5 の**再利用 15 本の一覧が全面的に変わる**。

**修正案**: (a) `auth.md` §6.2 に R-1 の 3 本を**採用案として取り込み**、
Q-A2 を「ユーザー承認待ちの提案 (提案内容は `docs/design/API/settings.md` §3.1)」と明記する
(実質確定しているものを未回答欄に残さない)。
(b) §7 の A-1 行に「**Q-A1 が NO の場合の影響**: v3 専用ログイン API 群の新設 +
`docs/design/API/settings.md` §5 の再利用一覧の全面見直し」を追記する。

### 中 7. `docs/design/auth.md:400-409` (§6.3) — 「新規テーブルはすべて `account_id` を直接持つ」に実在する例外が認められていない

§6.3-1 は「v3 が新規に作るテーブルは**すべて `account_id` を直接持つ** (`NOT NULL` + FK)」と書くが、
API 側の設計には**契約が境界のテーブル**が複数ある:

| テーブル | 境界 | 出典 |
|---|---|---|
| `idea_board_phases` | `contract_id` のみ (v2 既存。照合済み `hassan-v2-backend/db/schema.sql:615-625`) | `idea-boards.md:290` |
| `workspace_settings` (v3 新設) | `contract_id` のみ | `settings.md:170` |
| `idea_board_items` / `idea_board_comments` (v3 新設) | `contract_id` + メンバーシップ (`account_id` は作成者) | `idea-boards.md:290` |

§6.3-2 が「契約内共有が必要なテーブルは `contract_id` も併せて持つ。`account_id` は作成者を表す」と
補足しているため意図は読めるが、**§6.3-1 の「すべて」という絶対表現が優先して読まれると**
契約マスタに意味のない `account_id` が付き、逆に「所有者は `account_id`」という前提で
契約スコープのクエリが書かれる。A-3 の CI 検査 (重大 6 の修正で拡張する検査) も、
どちらを所有者列と見るかの宣言が無いと機械化できない。

**修正案**: §6.3-1 を
「**所有者列 (`account_id` または `contract_id`) を 1 段で必ず持つ。
どちらを境界にするかをテーブル単位で宣言し、data-model 設計の表に列として持つ**」に書き換える。
A-4 の CI 検査はその宣言を参照して所有者条件の有無を判定する形にする。

### 中 8. `docs/design/API/README.md:437` (O-2) / `docs/design/API/knowledge.md:193` — 埋め込み生成を `AgentRunner` で計測できる前提が未検証

O-2 の計測対象 3 本のうち 1 本は `POST /knowledge-files` の**埋め込み生成**であり、
`knowledge.md` は「計測は `AgentRunner` (直接 API 経路も同じラッパを通す) 1 箇所」と書いている。
しかし `08-production-gates.md` O-2 は
「**LLM 抽象が全プロバイダで usage と `stop_reason` を返せるかを先に確認する**」を明示要求しており、
**埋め込み API は `stop_reason` を返さない**。加えて KN-Q2 が
「Managed Agent か直接 LLM API か」を未決にしているため、
埋め込みが `AgentRunner` の型に収まるかは確認されていない。
`observability.md` §4.3 の失敗分類 F-1 も `stop_reason == max_tokens` を前提にしている。
結果として「3 本すべて計測」が実装時に「2 本だけ」になる余地がある — これは O-2 が
「1 経路だけの計測は計測なしと同じ」と定義している失敗形そのものである。

**修正案**: `README.md` O-2 行に
「**埋め込み生成は `stop_reason` を持たない**ため、LLM 呼び出しレコードでは `stop_reason` を nullable とし、
`call_kind` (`agent` / `completion` / `embedding`) を必須フィールドとする
(`docs/design/observability.md` §4.2 に反映)」を追記する。

### 中 9. `aidlc-docs/inception/productionization/requirements.md` §3.1 — ストレージ層のテナント境界に対応する **AC が無い** (DR-6 の逆方向)

本設計で最も事故が大きい判断のひとつは D-API-14' である —
「非公開バケット + ACL を付けない + GET は署名付き URL のみ」。
その却下対象は v2 の実装であり、一次ソースで確認済みである
(`hassan-v2-backend/aws/s3.go:46` の `ACL: types.ObjectCannedACLPublicRead` と
`:58` の恒久無署名 URL)。**同じ実装を流用すると、ヒアリング議事録・技術資料が URL を知る誰でも
認証なしで読める**。

しかし requirements.md §3.1 の AC-1.1〜AC-1.4 は
「認証を通ること」「**テーブル**に所有者カラムがあること」「LLM ツールのスコープ」
「401/403/404 の一覧化」しか要求しておらず、**ストレージの公開設定に対応する AC が存在しない**。
`make check-traceability` は AC → 設計書の方向のみを照合するため、この欠落は検出されない
(実行結果は 22/22 カバーで OK)。

**修正案**: requirements.md §3.1 に **AC-1.5** を追加する —
「ユーザーがアップロードしたファイルは**公開 ACL を持たないバケット**に保存され、
配布は**有効期限付き署名 URL のみ**であること」。
`README.md` D-API-14' / `assets.md` D-AS-5 / `knowledge.md` D-KN-10 からこの ID を参照する。
あわせて `idea-boards.md` §4 の移行手順 M-1〜M-4 は **AC-3.5** (全面切替手順) を引用していないので紐付ける。

### 中 10. `docs/design/API/themes.md:51-52` — `PUT /themes/{theme_id}/members` の実行権限が未定義で、仕様どおり実装すると契約内の誰でもメンバーを差し替えられる

表のスコープ列が「契約」、固有ステータス列に **403 が無い**ため、
文字どおり実装すると「同一契約のメンバーであれば、任意のテーマのメンバー一覧を置換できる」になる。
D-TH-5 の却下案 (a) は「認可設計 (誰がメンバーを変更できるか) が未確定のまま入る」ことを
増分 2 に送る理由として挙げているが、**表側は既に「契約スコープ・403 なし」という危険な既定を
確定させている**。前回レビュー (`aidlc-docs/reviews/productionization/review-api.md` の中 C) が
指摘した読み書きの非対称 (GET が `role` を返すのに PUT が書けない) とも同じ根を持つ。

**修正案**: スコープ列を「**読み: 契約 / 書き: 作成者**」に分け、
固有ステータス列に **403** (作成者以外) を追加する。
TH-Q5 が解決されるまでは書き込みを作成者限定にすると本文に明記する
(重大 4 の R-3 に含める形が最も整合する)。

---

## 4. 軽微 (Nice to Have)

1. **`docs/design/auth.md:151` / `docs/design/API/README.md:57`** — 「約 90 のルート」。
   実測は `AuthRequiredMiddleware(auth.AuthRoleUser)` の出現が **98 箇所**
   (うち 1 つは `hassan-v2-backend/router/router.go:230` の `mfaRoute.Use()`)。
   「約 100」または実数に。
2. **`docs/design/API/README.md:73` / `docs/design/API/assets.md:106`** —
   `hassan-v2-backend/usecase/asset/list_assets.go:60-66` を出典としているが、
   契約一致の比較 (`input.ContractID != account.ContractID`) は **`:66-67`** にまたがる。
   `:61-68` にすると範囲が正確になる。
3. **`docs/design/API/README.md:306-314` (§3 総覧)** — エンドポイント数・LLM・SSE・403 の
   4 列はすべて各ファイルと一致していた (照合済み) が、**増分 1 / 増分 2 の内訳列が無い**。
   増分 1 のスコープを確認するには 6 ファイルを開く必要がある。
   「増分 1 / 増分 2」の列を足すと引き渡し時の作業単位が総覧だけで読める
   (`README.md:489-491` の増分 2 の作業単位と対応させられる)。
4. **`docs/design/API/knowledge.md:144` と `docs/design/API/assets.md:118`** —
   許可拡張子の値域が 2 系統で違う (ナレッジは `.doc/.ppt/.xls/.txt/.md` を含む、
   アセットは含まない)。D-AS-4 でアップロード基盤を分けた帰結であれば**その理由を 1 行書く**。
   書かないと BE-2 (設定値の SSOT) の観点で「どちらが正か」の疑問が実装時に出る。
5. **`docs/design/API/news.md:52`** — `GET /news` に `unread_only=true` を付けたときの
   `total_count` の意味 (未読件数か公開記事の全件数か) が未定義。
   §3.1 のとおり未読は「CMS の公開済み記事集合 − 既読レコード」で算出するため、
   `total_count` がどちらを指すかで FE のページネーション表示が変わる。

---

## 5. 本番観点カバレッジ (`.claude/rules/08-production-gates.md`)

### A. 認証・テナント分離・権限

| ID | 状態 | 箇所 | 本レビューの判定 |
|---|---|---|---|
| A-1 認証方式 | **回答あり** | `docs/design/auth.md` §6.1 / `docs/design/API/README.md` §2.1 (D-API-3) | 内容は妥当。ただし Q-A1 未回答の影響が §7 に現れていない (**中 6**) |
| A-2 ロールと適用範囲 | **回答あり** | `docs/design/auth.md` §6.2 / `docs/design/API/README.md` §2.2 (R-1 / R-2) | `AuthRoleConsultant` を前提にしていないことを確認 (照合済み・良好)。Q-A2 が SSOT 側で未回答のまま API 側が確定 (**中 6**) |
| A-3 テナント境界 | **回答あり** | `docs/design/auth.md` §6.3 / 各ドメインファイルの A-3 行 | 「全テーブル `account_id` 必須」に実在する例外が未記載 (**中 7**)。`company_id` を新設しない判断と 36 テーブル集計は照合一致 |
| A-4 絞り込みの層 | **回答あり (機械強制に穴)** | `docs/design/auth.md` §6.4 / `docs/design/API/README.md` §2.3, §1.4 | **重大 5** (`created_by`) と **重大 6** (`Get*` 限定の検査が F-15 を検出できない) が未解決。層の分担自体は妥当 |
| A-5 ステータスコード | **回答あり (増分 2 で破れる)** | `docs/design/auth.md` §6.6 (判定規則 SSOT) / `docs/design/API/README.md` §2.5 (エンドポイント適用 = AC-1.4) | **重大 4** (増分 2 の 403/404) と **中 4** (ボディ内 ID の 400) が未解決。増分 1 の一覧としては網羅的 |
| A-6 LLM への越境 | **回答あり** | `docs/design/architecture.md` §3 (SSOT) / `docs/design/auth.md` §6.5 / `docs/design/API/knowledge.md` §4 / `docs/design/API/assets.md` A-6 行 | 参照先の実在と内容を確認済み (`architecture.md:93,100,142` に `ToolDispatcher` の所有者スコープ強制が実在)。`knowledge.md` §4 の不変条件 3 点 (LLM 出力 ID を引用に採用しない・スコープ外は該当なし・他人の `file_id` 紐付けは 404) は **PoC の穴 (照合済み: `conversation_tools.go` に所有者概念 0 件) に対する直接的な回答**として十分 |
| A-7 共有・公開 | **矛盾 (要修正)** | `docs/design/auth.md` §7 (対象外) vs `docs/design/API/README.md` §4 / `docs/design/API/idea-boards.md` §5 (引き継ぐ) | **重大 7**。SSOT 側の判断が自書 §2.2 の事実と両立しない |

### O. 可観測性・LLM コスト (この 2 文書が回答すると宣言している ID のみ)

| ID | 状態 | 箇所 | 判定 |
|---|---|---|---|
| O-1 | **参照** (先送り先の記述が誤り) | `docs/design/API/README.md` §4 | 先送り先の `observability.md` は実在し §4.1 で回答済み (**中 3**) |
| O-2 | **回答 (経路特定)** | `docs/design/API/README.md` §4 / §3 の LLM 列 / `docs/design/API/knowledge.md` §5 | 3 本の特定は妥当かつ総覧と一致 (照合済み)。埋め込み経路の計測可否が未検証 (**中 8**) |
| O-3 | **先送り (理由あり)** | `docs/design/API/README.md` §4 / `docs/design/API/settings.md` §4 D-ST-5 | C-12 (上限なし) と整合。`GET /usage-summary` にコストを含めない判断も明示されている。問題なし |
| O-4 | **部分回答** | `docs/design/API/README.md` §2.5 (502) / §1.3 J-3 (`stale_aborted`) / 各ファイルの `failure.code` | 502 で外部起因を識別する判断は良好。`failure.code` の値域が 2 文書に分裂 (**中 3**) |
| O-5 | **回答 (一部先送り)** | `docs/design/API/README.md` §1.3 (J-1〜J-7) / D-API-12 / `docs/design/API/assets.md` §2.1 | J-3 (取り残しの回収) と J-6 (DB ポーリング配信) は `design_memo.md:136` の要求に具体的に答えており、**本レビューで最も評価できる部分**。SSE の認証トランスポートが未決 (**中 2**) |
| O-6 | **部分回答** | `docs/design/API/settings.md` §3 (`GET /activity-logs`) / 各ファイルの O-6 行 | v2 に `activity_logs` テーブルはあるが参照 API が無いという事実は照合一致。記録項目の先送り先が誤り (**中 3**) |
| O-7 | **対象外 (先送り先が誤り)** | `docs/design/API/README.md` §4 | 実際の回答は `observability.md` §4.6 にある (**中 3**) |

### D. CI/CD・デプロイ・IaC

| ID | 状態 | 箇所 | 判定 |
|---|---|---|---|
| D-1〜D-8 | **対象外 (理由あり)** | `docs/design/API/README.md` §4 の D 行 | 「API 設計の範囲外」+ **D-2 のマージ条件に §1.4 の 8 検査を要求** + **D-3 が §1.3 J-3 の前提** という形で、対象外にしつつ依存を明示できている。無言の省略なし |
| D-4 | **参照** | `docs/design/API/idea-boards.md` §4 / `docs/design/API/themes.md` §3.2 / `docs/design/API/assets.md` §3.2 | 移行手順は API 設計側に具体的に落ちている (M-1〜M-4 / TM-1 / AS-M1)。M-1 に欠落あり (**重大 1**) |
| D-5 | **部分回答** | `docs/design/API/news.md` §4 (CMS の API キーを backend 側に寄せる) / `docs/design/API/settings.md` §6 | `NEXT_PUBLIC_` 接頭辞のキーをサーバへ寄せる判断は D-5 の観点として的確。SSE のトークン送出が未決 (**中 2**) |
| D-7 | **回答** | `docs/design/API/idea-boards.md` §4 (移行 + ロールバック) | 「v2 は読み取るだけ・ロールバックは v3 を捨てるだけ」の不変条件は DR-3 への回答として過不足なし |

### DR / BE / FE パターン (`.claude/rules/feedback_review_patterns.md`)

| ID | 判定 |
|---|---|
| DR-1 出典なしの断定 | **問題なし**。34 件を一次ソースで照合し誤り 0。外部事実 (`dgrijalva/jwt-go` のアーカイブ状況) を「本リポジトリでは検証不能・要確認」と切り分けている書き方は模範的 (`auth.md:71-76`) |
| DR-2 本番観点の無言の省略 | **問題なし**。A-1〜A-7 / O-1〜O-7 / D-1〜D-8 のすべてに回答か理由付きの対象外がある。A-7 のみ矛盾 (重大 7) だが省略ではない |
| DR-3 既存データの不在 | **一部問題**。テーマ・アセット (TM-1 / AS-M1) とお知らせ (§3.1) は十分。**ボードの M-1 に閲覧者依存の欠落** (重大 1) と**追加範囲の退行** (重大 2) |
| DR-4 PoC 実装のコピー設計 | **問題なし**。v2 規約 (`CodedError` 単一系統・3+1 層・swag) を採り、PoC からは振る舞い (4 ターン SSE・台帳) のみを参照している。D-API-6 で v2 の 2 系統 (F-7 / F-8) を単一系統に寄せる判断は明確 |
| DR-5 曖昧語 | **問題なし**。「適切に」「必要に応じて」「後で検討」「適宜」「柔軟に」の出現が**対象 8 ファイルで 0 件** (grep 済み)。「実装時に気をつける」で済ませた箇所も見当たらず、§1.4 の CI 検査 8 件で機械化する方針は一貫している (ただし検査自体に穴 — 重大 5 / 重大 6 / 中 1) |
| DR-6 AC の宙吊り | **一部問題**。`make check-traceability` は 22/22 で OK だが、**逆方向にストレージ層の AC 欠落** (中 9) |
| DR-7 プロトタイプを仕様として扱う | **問題なし**。`README.md` §0 で「配線のないダミー UI は総覧に載せず要確認節に分ける」という構造的な扱いを決め、各ファイルが実際に守っている (TH-Q1〜Q5 / AS-Q1〜Q10 / KN-Q1〜Q7 / IB-Q1〜Q10 / ST-Q1〜Q7 / NW-Q1〜Q5)。`assets.md:37-39` の「22 アセット中 4 件のみ実データ」のような**モックの実態の明示**まで行っている |
| BE-1 / BE-4 (派生物の stale) | **対応済み**。`idea-boards.md` D-IB-1 (参照を正・スナップショットを却下)、`themes.md` D-TH-4 (stage/progress は派生値・読み取り専用) |
| BE-2 (hard cap の散在) | **対応済み**。`assets.md` §3.1 / `knowledge.md` §3.1 / D-API-7 / D-API-14 で「サーバ側定数 1 箇所 + OpenAPI 経由で FE へ伝播」。値域が 2 系統で違う点のみ軽微 4 |
| BE-6 (`max_tokens` 切り詰め) | **対応済み**。`assets.md` D-AS-11 の `failure.code` と D-KN-6 の却下案 (b) で構造的に扱っている |
| BE-8 / BE-9 (schema と handler の乖離) | **対象外の扱いが妥当** (Managed Agent 定義は本ディレクトリ外)。ただし A-6 の実効性はそこに依存する |
| BE-10 (読む側と書く側の対) | **模範的**。`settings.md` §3.2 と `assets.md` D-AS-12 が `default_asset_visibility` (書く側) と `visibility` (読む側) を**同じ増分に入れる**ことで構造的に潰している。`themes.md:51` のメンバー API のみ非対称が残る (中 10) |
| BE-11 (採番と冪等性) | **対応済み**。§1.3 J-5 の `idempotency_key` と J-4 の「同じジョブ行を再利用しない」 |
| FE-2 (snake_case 漏れ) | **対応済み**。D-API-4 で snake_case 統一 + D-ST-7 で変換層を API 境界 1 箇所に閉じる + orval 生成先を 2 つに分ける |
| FE-6 (数値パーサの誤抽出) | **対応済み**。`idea-boards.md` D-IB-3 が `"B+・4.1"` をサーバ側で `{rank, score}` に分解し、FE にパーサを書かせない |

---

## 6. 良かった点

1. **出典の精度が突出している**。34 件を一次ソースで照合して**誤りが 0**。
   特に `auth.md` §2.2 の 36 テーブル集計 (`account_id` 17 / `contract_id` のみ 5 / `company_id` 0 /
   どちらも無し 14) は**テーブル名リストまで機械集計と完全一致**した。
   前回レビューで指摘された `color_code` の行番号誤記 (`:618` → `:619`) も修正されている。

2. **v2 の最も危険な既存実装を「踏襲しない」と明示的に逸脱した判断**。
   `hassan-v2-backend/aws/s3.go:46` の `ACL: ObjectCannedACLPublicRead` と `:58` の恒久無署名 URL は、
   用途 (アイコン・サムネイル) の確認まで含めて調べたうえで
   「ヒアリング議事録・技術資料には流用禁止」と却下されている (D-API-14' / D-AS-5 / D-KN-10)。
   `Presign` の参照が v2 に 0 件であることまで確認して「新規実装が必要」と書いている点も含め、
   「v2 もそうだから」で通さない姿勢が徹底されている。
   `D-KN-10` が「当初は『v2 に前例あり』と書いていたが事実誤認だった」と**撤回の記録を残している**のも良い。

3. **曖昧語が 0 件で、代わりに機械検査 8 件に落としている**。
   §1.4 の CI 検査表は「規約を『気をつける』に落とさない」という意図が明確で、
   `account_id` クエリ禁止を「最も事故が大きい規約なので機械検査を必須にする」と
   優先度付きで書いている。検査自体に穴はあるが (重大 5 / 重大 6)、**穴を指摘できる形で
   検査が書かれていること自体が設計の質**である。

4. **非同期ジョブ (§1.3 J-1〜J-7) が設計入力の要求に具体的に答えている**。
   `design_memo.md:136` の「デプロイで処理が死んでも復旧可能」に対して、
   J-3 で heartbeat + 2 経路の回収 + `stale_aborted` を、J-6 で「ジョブ実行 goroutine と SSE 接続が
   同一プロセスにいることを前提にしない」を決めている。
   後者は ALB の振り分けを考慮した判断で、`desiredCount 1` を前提にしない点が本番的である。

5. **`idea-boards.md` §1.0 (V-1〜V-3) の構成**。
   「ここを読まずに実装すると既存データを壊す」という位置づけで v2 のデータモデルの差分を
   3 点に絞って先頭に置く構成は、実装リポへの引き渡し物として最も効く形である。
   `ideas` に `is_deleted` が無いこと・所有者列が無く 2 段チェーンであることを
   A-3' として data-model へ申し送りしている点も、`auth.md` §6.3 との差分を
   自分では確定できないと正しく判断している。

6. **増分設計を認可の安全側に使っている**。
   D-API-8' の「増分 1 は `scope=mine` のみ・`contract` は 400」は、
   v2 の `sharing_settings` の既定が非共有であるという実測 (照合済み) から
   「切替が一斉公開になる」を導いた判断であり、
   TM-1 / AS-M1 の初期値決定と合わせて「切替前後で見える範囲を変えない」を成立させている。
   **重大 1 はこの規則をボードにも適用すれば解決する** — つまり正しい型は既に文書内にある。

---

## 7. 再レビューの条件

- **重大 1 / 重大 2** (ボードの移行と追加範囲) は既存本番データの露出・退行に直結するため、
  修正後に**再レビューを行う** (移行手順の変更は検証方法の変更を伴う)。
- **重大 3 / 重大 7** (`auth.md` の SSOT 記述) は `auth.md` §6 への節追加を伴うため、
  修正後に**該当節のみ再レビュー**する。
- **重大 4 / 重大 5 / 重大 6** および中 1〜中 10 は、いずれも表への行追加・文言の訂正・
  CI 検査定義の拡張で閉じられる。修正後は `make check` の再実行で足りる。
- 修正時に**併せて閉じられるもの**: 重大 4 の R-3 追加は中 10 (テーマメンバーの権限) を包含する。
  重大 6 の専用型コンストラクタは重大 5 (`created_by`) を構造的に閉じる。
