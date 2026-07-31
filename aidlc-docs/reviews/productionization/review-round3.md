# 設計レビュー (3 巡目 / Design Freeze 可否判定) — productionization

- **実施日**: 2026-07-31
- **レビュアー**: design-reviewer (別セッション。起草者ではない)
- **基準**: `.claude/rules/08-production-gates.md` (本番観点 SSOT) / `.claude/rules/feedback_review_patterns.md` (DR-1〜DR-8 + BE/FE) /
  ルート `CLAUDE.md` (ハイブリッド方針)。**PoC 基準の合格判定は行わない**
- **結論**: **Freeze 条件付き不可** (重大 3 件)。スコープ別の可否は §6

---

## 0. レビュー対象 (リポジトリ相対パス — 全件列挙)

### 0.1 設計成果物 (docs/design/)

- `docs/design/testing.md`
- `docs/design/frontend.md`
- `docs/design/data-model.md`
- `docs/design/observability.md`
- `docs/design/architecture.md`
- `docs/design/operations.md`
- `docs/design/infrastructure.md`
- `docs/design/llm-migration.md`
- `docs/design/auth.md` (参照照合のみ: `:554`〜`:557` / `:588`〜`:596`)
- `docs/design/API/assets.md`
- `docs/design/API/idea-boards.md`
- `docs/design/API/themes.md`
- `docs/design/API/settings.md`
- `docs/design/API/README.md`
- `docs/design/API/knowledge.md`
- `docs/design/API/news.md`

### 0.2 Inception 成果物 (aidlc-docs/inception/)

- `aidlc-docs/inception/productionization/plan.md`
- `aidlc-docs/inception/productionization/plan-layering.md`
- `aidlc-docs/inception/productionization/requirements-layering.md`

### 0.3 雛形 (templates/)

- `templates/backend-repo/.github/workflows/ci.yml`
- `templates/backend-repo/.golangci.yml`
- `templates/frontend-repo/.github/workflows/ci.yml`

### 0.4 レビュー範囲外として扱ったもの (理由付き)

| パス | 扱い | 理由 |
|---|---|---|
| `docs/design/API/auth-accounts.md` | **未レビュー** | **本レビュー開始後 (2026-07-31 08:38:25) に新規作成された** (91 KB / 37 エンドポイント / Task-3i 成果物)。レビュー開始時点のファイル一覧に存在せず、依頼された範囲にも含まれていない。**独立した 1 巡目レビューが必要** (§3 重大 3) |
| `templates/shared/.claude/rules/` の construction-workflow 系 | 対象外 | 別 feature で Freeze 済み (依頼で明示) |
| `docs/prototype/hassan_agent_prototype_v2.html` | 設計入力として参照のみ | DR-7。仕様の根拠にしていないかの検査に使用 |

---

## 1. 実行した検証 (出力そのまま)

### 1.1 `make check`

```
[doc-lint] 対象 85 ファイル / エラー 0 件 / 警告 28 件
[traceability] construction-workflow: 24/24 カバー — OK
[traceability] productionization: 47/47 カバー — OK
[traceability] 照合 2 feature / 未カバーあり 0 feature
[workflow-shell] 検査 52 ブロック / エラー 0 件
```

- **doc-lint エラー 0 件** — リンク切れ・参照リポの不在はゼロ
- **traceability: productionization 47/47 カバー** — **DR-6 (AC の宙吊り) は無し**
- **workflow-shell: 52 ブロック / エラー 0 件**

### 1.2 警告 28 件の内訳 (doc-lint)

**22 件は「TODO」語そのものへの反応** (ルール文書・過去 review・`design_memo.md` の取り消し線付き TODO) で、本増分の成果物には無い。
**残る 6 件は実際の未回答 `[Answer]`** であり、Freeze 判定に効く (§4 中 5):

| ファイル:行 | 未回答の問い | 影響 |
|---|---|---|
| `docs/design/data-model.md:952` | §6.4 どのデータを引き継ぐか (Q-1 / Task-2f 待ち) | 移行設計が未完成 (既知・DR-3 として追跡済み) |
| `docs/design/frontend.md:1198` | **FE-Q7 管理者経路の WAF IP 制限** | **`docs/design/auth.md:554`〜`:557` が「IP 制限は多層防御として併用する」と書いたまま**で、FE-D と両立しない状態が 2 文書に残る |
| `docs/design/infrastructure.md:519` | Q-INF-1 構成要素一覧の確定 (要確認 12 行) | IaC の適用範囲が未確定 |
| `docs/design/infrastructure.md:535` | Q-INF-3 ドメイン名 / ホストゾーン | 同上 |
| `docs/design/llm-migration.md:764` | LM-Q5 A/B 評価者の役割 | 暫定既定あり・影響小 |
| `docs/design/operations.md:694` | アラート宛先 (Slack / メール) | 暫定既定あり・影響小 |

### 1.3 抜き取り照合 (19 件。一致 13 / 不一致 5 / 未照合 1)

| # | 主張 (出典) | 照合方法 | 結果 |
|---|---|---|---|
| 1 | depguard **18 規則** (`docs/design/architecture.md:237` / `:832` / `aidlc-docs/inception/productionization/plan-layering.md:61`) | `templates/backend-repo/.golangci.yml` の 8 スペース字下げキーを列挙 → `L1-entity-no-other-layers` (`:113`) 〜 `L6-service-no-connection-pool` (`:400`) の **18 件** | **一致** |
| 2 | golangci-lint ステップ = **`ci.yml:46-49`** (`plan-layering.md:61` / `:116`) | `templates/backend-repo/.github/workflows/ci.yml:46`〜`:49` = `- name: D-2①⑤ golangci-lint …` 〜 `args: --config=.golangci.yml` | **一致** |
| 3 | D-2⑨ の `targets` に **`gateway`** (`architecture.md:800` / `§3.7 の 3`) | `ci.yml:264` = `targets="service usecase/theme … controller entity gateway"` | **一致** |
| 4 | sqlc 規則 1 の deny 対象に `gateway/**` (`architecture.md:262`) | `.golangci.yml:322` = `- "**/gateway/**"` (`L3-no-sqlc-outside-repository` の `files`) | **一致** |
| 5 | `L4-gateway-no-upper-layers` の deny に `database/sql` / `pgx` (同 `:262`) | `.golangci.yml:344` / `:346` に両 desc が実在 | **一致** |
| 6 | v2 `ideas` に `concept` / `customer` / `issue` / `solution` = **`schema.sql:155`〜`:158`** (`docs/design/API/idea-boards.md:342` / `:408`) | `hassan-v2-backend/db/schema.sql` 実測: `155 concept` / **`156 target_market`** / `157 customer` / `158 issue` / `159 solution` | **不一致 (行が 1 ずれ。列名 4 件は実在)** → §4 中 3 |
| 7 | `market_size` = `:159` / `cagr` = `:160` (`idea-boards.md:405` / `:406`) | 実測 `160 market_size` / `161 cagr` | **不一致 (1 ずれ)** → §4 中 3 |
| 8 | 連動 1: `data-model.md:313` = 機能テーブル 39 件の見出し | 実測一致 (`#### 4.1.1 機能テーブル (39 件…`) | **一致** |
| 9 | 連動 2〜4: `data-model.md:360` / `:814` / `docs/design/auth.md:592` | 3 行すべて主張どおりの記述が実在 (39 行 / 39 件・31 件 / 39 テーブル 31・8) | **一致** |
| 10 | 連動 5 の注記「`architecture.md:759` の**「例外 11」は「除外 9 件」へ訂正済みの旧記述**」 | `data-model.md:362` は現に「機能テーブル以外の **11** テーブル」(a 6 件 + b 5 件)。「9 件」は**検査①の除外リスト**の旧値で、**現在は 8 件** (`data-model.md:393`) | **不一致 (誤った是正要求)** → §3 重大 2 |
| 11 | プロトタイプ `tags:["脱炭素","内部検査"]` = `:10488` (`idea-boards.md:404`) | 実測 `:10487`。`:10488` は `concept:"超音波センシングと…"` | **不一致 (1 ずれ)** |
| 12 | 「**ボード一覧のモック**も配列 (`:12675`)」(同 `:404`) | `:12675` は `PAST_THEMES`(**新規ボード作成ウィザードの過去テーマ**。`:12630`〜`:12677`) 内。ボード一覧のモックではない | **不一致 (帰属の誤り。配列であること自体は事実)** |
| 13 | AS-Q11 の `setFile` `:9720`〜`:9728` / `summarizeIdeaInput` `:9742` / ウィジェット `:9606`〜`:9861` (`docs/design/API/assets.md:179`) | 4 箇所すべて実測一致 (`9606 function addIdeaInputWidget()` / `9720 function setFile(f)` / `9742 function summarizeIdeaInput(file, text)`) | **一致** |
| 14 | `projectRef` = `:10485` / `:11283` (`idea-boards.md:409`) | 両行に `projectRef:true,` が実在。**参照箇所 0 件**の主張も grep で確認 | **一致** |
| 15 | `PHASE_OPTIONS` `:12003` / `BOARDS[].members` `:11934` (同 `:323` / `:324`) | 両行実在 (`const PHASE_OPTIONS = [` / `members: ["uchiho",…]`) | **一致** |
| 16 | FE 併置テスト検査 = `templates/frontend-repo/.github/workflows/ci.yml:58`〜`71` (`docs/design/testing.md:650` / `:667`) | 実測 `:58` = `- name: 検査 1 併置テストの存在` / `:71` = `exit $missing` | **一致** (`frontend.md:633` / `:1225` の `:58-72` は 1 行過大 → §5 軽微 1) |
| 17 | `asset_tags` = 個人境界 / `contract_id`+`account_id` / `sort_order` / GIN trgm (`idea-boards.md:428` / `:442`〜`:443` が `idea_tags` の同型根拠にしている) | `data-model.md:324` (境界・所有者列) と `:468` (`tag` / `sort_order` / `(asset_id)` / GIN trgm) が一致 | **一致** |
| 18 | `auth-accounts.md` は **36 本** (`docs/design/API/README.md:320`。合計 109 = 73 + 36) | `docs/design/API/auth-accounts.md:86` = 「合計 **37 本**」/ 同 `:508` = 「§2 の全 **37 本**」 | **不一致** → §3 重大 3 |
| 19 | Vercel の数値 (Node.js `maxDuration` Hobby 300s / Pro 800s / Edge ストリーム 300s / 同時実行 30,000 / active CPU は I/O 待ちを含まない。`docs/design/frontend.md:1105`〜`:1109`) | **未照合** — 本セッションはネットワークに出られないため公式ドキュメント原文を確認できない。**記載内容はモデルの知識と矛盾しない**が、これは照合ではない | **未照合** |

**照合していない範囲 (正直な列挙)**: ①Vercel 公式ドキュメント (#19) ②`docs/design/API/auth-accounts.md` の全文と 37 本の入出力仕様 ③`docs/design/API/themes.md` / `settings.md` / `knowledge.md` / `news.md` のプロトタイプ引用行の全数 (TH-Q6〜Q9・ST-Q8〜Q9 の**回答の妥当性と却下案の有無**は読んで確認したが、引用行番号は抜き取りしていない) ④1・2 巡目で照合済みの事実 (各 `review-*.md` の照合表に記録あり) は再照合していない。

---

## 2. 2 巡目指摘の解消判定

| 2 巡目の指摘 | 判定 | 根拠 |
|---|---|---|
| testing 中 R-2: `TestMain` 規約だけでは `t.Skip` の抜け道が塞げない | **解消** | `docs/design/testing.md:651` に存在検査 **#7** を新設 (`repository/`・`controller/` の `t.Skip` 禁止・許可は `testing.Short()` の 1 箇所)。判定規則と根拠 (`ci.yml:73`〜`74` が常に `DATABASE_URL` を設定するため `TestMain` の `log.Fatal` は CI で発火しない) まで書かれている。雛形 `templates/backend-repo/.github/workflows/ci.yml:111`〜`:113` も 3 検査列挙へ更新済み |
| 中 R-3: `feature` 識別子の対象集合が未定義で存在検査 #5 が「0 件を検査して緑」になる | **解消** | `docs/design/observability.md:137` に「Go の const 群として `entity/` の 1 ファイルに列挙・リテラル直書き禁止・追加は同一 PR」を追記。`testing.md:649` が同行を対象集合の SSOT として参照 |
| R-3 / R-4: `route_kind` の NULL 許容範囲が曖昧 / 相関キーとの書き分け | **解消** | `observability.md:141` / `:144` / `:155` で「NULL を許すのはこの `route_kind` のみ」が**トークン系 4 カウンタ + `stop_reason` の 5 フィールドに限る**ことを明記し、`:157` で**相関キーは計測漏れ CHECK の対象外**を明記 |
| data-model R-2: §7.2 検査 6 が存在しない列を探す | **解消** | テーブル別の実在列のみの表に変更 (`llm_call_records` = `account_id`/`session_id`/`theme_id` / `audit_logs` = `actor_id`)。R-DM-8 は「実施済み」へ |
| layering 中 A: `ci.yml` の D-2⑨ に `gateway` が無い | **解消** | 照合 #3〜#5 のとおり `ci.yml:264` / `.golangci.yml:322` / `:344` / `:346` / `architecture.md:262` / `:400` / `:800` が実態と一致 |
| layering 中 B: 「17 規則」「`ci.yml:41-42`」の旧値 | **解消** | 照合 #1・#2 のとおり 18 規則 / `:46-49` が実測値と一致。`plan-layering.md` / `requirements-layering.md` も更新済み |
| operations OP-R8: Environment を dev/prod で分けるか未確定 | **本体は解消 / 波及に漏れ** | `operations.md:346`〜`:359` に `[Answer]` + 一次ソースの含意 4 件が記入され、`infrastructure.md:383` (X-4) も反映済み。**ただし同書 §8 の D-6 行 (`:706`) が「`[Answer]` 待ち・暫定既定」のまま** → §4 中 1 |
| llm-migration LM-Q6 (埋め込みプロバイダ) | **本体は解消 / 波及に漏れ** | `llm-migration.md:110` (LM-D) が「第 1 リリース時点で 3 つ」へ改訂、`:320`〜`:329` の C-7 注記も決着済み、`:786`〜`:812` に `[Answer]` + 申し送り 7 項目。**`:373` が「Anthropic 主系 + Exa + Gemini (画像のみ)」= 例外 2 つのまま** → §4 中 2 |
| frontend FE-Q2 (Vercel の SSE 5 分中継) | **解消 (未照合)** | `frontend.md:1100`〜`:1152`。一次調査で測定 4 項目 → 実測 1 回 + プラン確認へ縮小、**Edge を選択肢から外す判断を固定** (`:518` / `:1107` の 2 箇所で一貫)。数値そのものは #19 のとおり未照合 |

---

## 3. 重大 (Must Fix — Freeze 前に必須)

### 重大 1. `docs/design/frontend.md` が「FE の存在検査は testing.md §10 に未登録・§10 は 5 種」と 4 箇所で主張しているが、既に登録済み (7 種)。加えて `docs/design/testing.md:101` 自身が「6 種」のまま

**なぜ実装リポで問題になるか**: 実装者は FE 側の正として `frontend.md` を読むため、「この存在検査は SSOT の外にある = 必須チェックにしなくてよい」と解釈して CI から外す、あるいは既に満たされている是正要求を再度起票して 1 巡分のコストを払う。**FE-6 (数値パーサのレンジ誤抽出) を構造で潰す唯一の機構が、文書の記述だけを理由に落ちる。**

- **事実 (登録済み側)**:
  - `docs/design/testing.md:637` = 「代わりに機械強制する『必須テストの存在検査』**7 種**」
  - 同 `:650` = 表の **6 番** が「**FE: `src/lib/parse/**` と `features/*/lib/**` に併置テストがある**」で、「**frontend.md §8.2 が本節への登録を要求していたもの**」と明記
  - 同 `:555` = 「**frontend.md §16.2-1 が要求する登録項目**」として §9.1.1 を新設
  - 同 `:691` (AC-5.2 の回答) = 「**存在検査 7 種**」
- **事実 (旧記述として残っている側)**:
  - `docs/design/frontend.md:634`〜`:638` = 「**ただし testing.md §10 の「必須テストの存在検査 5 種」に本検査は含まれていない**」「**同書への登録を §16.2-1 の是正要求として出す**」
  - 同 `:994` (FE-4 行) = 「**testing.md §10 への登録は未了** (§16.2-1)」
  - 同 `:979` (D-2 行) = 「**FE の検査を同書に登録する是正要求を §16.2-1 に出した**」
  - 同 `:1233`〜`:1236` = 「**同書 §10 の「必須テストの存在検査 5 種」は 5 件すべて backend であり、FE の検査が 1 つも無い**」「①§10 の一覧に FE の併置テスト存在検査 (検査 3) を加える」
  - `docs/design/testing.md:101` (T-N) = 「**6 種**の「必須テストの存在検査」を機械強制する (§10。うち 1 種は FE の併置テスト検査 = §9.1.1 の F-C3)」← §10 は 7 種
  - `templates/backend-repo/.github/workflows/ci.yml:102` のコメント = 「(testing.md §10 の **#4 / #5**)」← 同ファイル `:111`〜`:113` のエラーメッセージは #4/#5/**#7** を列挙している
- **DR-8 該当**: 「機構を直したのに、その機構を語る文書が『未対応』のまま」— `.claude/rules/06-delegation-prompts.md` が **3 巡連続の最上位指摘**として明記した型の **4 巡目の再発**。
- **修正案**:
  1. `frontend.md:634`〜`:638` を「**登録済み** (testing.md §10 の検査 **6** = F-C3。`testing.md:650`)」へ書き換える (是正要求ではなく状態の記述にする)
  2. `frontend.md:994` の「登録は未了」→「**登録済み** (同 §10 の 6 番)」
  3. `frontend.md:979` / `:1231`〜`:1236` の §16.2-1 の①②を **状態列付きで「実施済み (2026-07-30)」**にする (`06-delegation-prompts.md` の「是正要求の表は状態列を持たせる」に従う)。**③ (E-1 の CORS 記述の陳腐化) は FE-Q7/FE-Q2 待ちなので「未対応」で残す**
  4. `testing.md:101` の「6 種」→「**7 種**」
  5. `templates/backend-repo/.github/workflows/ci.yml:102` のコメントを「#4 / #5 / **#7**」へ
  6. **完了の証拠として** `grep -rn "5 種\|6 種" docs/` の出力を報告に含める (自己申告の排除)

### 重大 2. `docs/design/API/idea-boards.md` §8.2 の「連動 6 箇所」が不完全 (実測 **9 箇所**) で、うち 1 件は**実行すると設計を壊す誤った是正要求**

**なぜ実装リポで問題になるか**: §8.2 は「`idea_tags` を新設する」是正要求を**意図的に未反映**とし、その代わりに「反映時はこの全件を同じ差分で直すこと — DR-8」と連動リストを付けている。**先送りの正当性はこのリストの完全性に完全に依存する**。リストが不完全なら、反映時に DR-8 が確定的に発生する — しかも漏れている 2 件は**機械検査 (§3.3 検査②-2 / §7.2 検査 2-2) の入力値**であり、`31 件` のまま残ると **CI の検査が新テーブルを見落とす**か**常に赤になる**。

- **§8.2 が挙げた 6 箇所は全て実在し正しい** (照合 #8・#9)。**追加で漏れている 3 箇所**:

| # | 漏れている箇所 | 現在の記述 | 反映時に必要な変更 |
|---|---|---|---|
| 7 | `docs/design/data-model.md:195` (§3.3 の検査 ②-2) | 「`account_id` を持つテーブルの集合 == **分類① ∪ 分類② ∪ 分類③ (31 件)**」 | **32 件** — これは**機械検査の期待値**であり、直さないと検査が落ちる |
| 8 | `docs/design/data-model.md:1061` (§7.2 の検査 2-2) | 「`account_id` を持つテーブル (**31 件**) が分類①②③のいずれかに…」 | **32 件** — 同上 |
| 9 | `aidlc-docs/inception/productionization/plan.md:103` | 「**テーブル 39** (全件に `contract_id`) **+ 例外 11**」 | **40** |

- **誤った是正要求 (照合 #10)**: §8.2 の連動 5 の注記は
  > 「なお**「例外 11」は既に「除外 9 件」へ訂正済みの旧記述**であり、同じ差分で直すべき既存の陳腐化」

  と書いているが、これは**2 つの別の数を混同している**:
  - **11** = `data-model.md:362` の「機能テーブル**以外**の 11 テーブル」= (a) 所有者列を持たない **6 件** + (b) 所有者列を持つ **5 件**。**現行値であり陳腐化していない** (`architecture.md:759` の「テーブル 39 + 例外 11」は正しい)
  - **9 → 8** = `data-model.md:393` の「**検査①の除外リスト**」の件数 (DM-A4=B で 9 件 → 8 件)。テーブル総数の話ではない

  **この注記に従って `architecture.md:759` を「除外 9 件」に直すと、正しい記述を誤った記述に書き換えることになる。**
- **DR-1 該当**: 出典を示さずに「訂正済みの旧記述」と断定している。
- **修正案**: ①連動表を **9 箇所**に拡張する (上表の 7〜9 を追加。特に「機械検査の期待値」であることを明記) ②連動 5 の注記から「例外 11 は旧記述」の一文を削除する ③`grep -rn "39 テーブル\|39 件\|31 件\|テーブル 39" docs/ aidlc-docs/inception/` の**出力を §8.2 に貼る** (リストの完全性の証拠にする)。
- **先送り自体の判定 (依頼事項 4 への回答)**: **先送りの方針は妥当**。理由: (a) `idea_tags` は 3 文書 (`data-model` / `auth` / `architecture`) + plan にまたがる件数の書き換えを伴い、半端に直すと DR-8 になる (b) `Idea.tag` → `tags: string[]` という **API 側の確定は §8.1 で済んでおり**、読み手の契約は決まっている (c) 書き込み側を Task-3p に明示的に紐付け (`:430`) BE-10 を構造で避けている。**ただし「リストが完全であること」が先送りの前提条件**であり、現状は満たしていない。**上記の修正 (①②③) を行えば、未反映のまま Freeze してよい。**

### 重大 3. Freeze 範囲の逸走 — `docs/design/API/auth-accounts.md` (37 エンドポイント) が**本レビュー開始後に新規追加**され、未レビューのまま。加えて `docs/design/API/README.md` の総数と食い違っている

**なぜ実装リポで問題になるか**: `auth-accounts.md` は**認証・アカウント基盤の 37 本** = A-1 / A-2 / A-5 / D-5 の中核であり、**v2 の既知欠陥 (V2-D2 = MFA 失敗が 500 / V2-F17 = 失敗サインインで email 平文保存 / V2-F13 = 最後の管理者ガードがロック状態を見ない) を引き継がないことが要件**。ここを未レビューで Freeze すると、**認証の穴が実装リポの最初の PR に入る**。

- **事実**: `stat` 実測で `docs/design/API/auth-accounts.md` = **2026-07-31 08:38:25** 作成 (91,215 バイト)、`docs/design/API/README.md` = **08:38:49** 更新。**本レビュー開始時点 (08:33 の `ls`) には存在しなかった**。`aidlc-docs/inception/productionization/plan.md:110` の Task-3i は `[ ]` (未完了) のまま。
- **数の不一致 (照合 #18)**: `docs/design/API/README.md:319`〜`:320` = 「**合計 109 エンドポイント** = 6 ドメイン 73 本 + auth-accounts の **36 本** (§3.7)」 / `docs/design/API/auth-accounts.md:86` = 「エンドポイント一覧 (合計 **37 本**)」・同 `:508` = 「§2 の**全 37 本**に要求する認証系統を宣言した」。**どちらかが誤りで、109 か 110 かも決まらない**。加えて README が根拠として指す「§3.7」は `auth-accounts.md:476` = 「監査記録とレート制限の対象」であり、**エンドポイント数の節ではない**。
- **副次的な未反映**: `auth-accounts.md:543` の **R-AA-7** (`observability.md` §4.5 への「認証系 6 事象を監査対象に追加 / 失敗サインインで email を平文保存しない」要求) が **「未対応」** のまま。`docs/design/observability.md` 側に反映が無い状態で Freeze すると、**O-6 (監査ログ) に v2 で既にできていた 6 事象が落ちる**。
- **未回答 `[Answer]` が 3 件ある**: 本レビュー実施後に再実行した `make doc-lint` が
  `docs/design/API/auth-accounts.md:564` / `:576` / `:587` を未回答として検出した
  (§1.2 の 6 件とは別。**doc-lint 対象は 85 → 87 ファイル / 警告 28 → 32 件に増えた**)。
  `.claude/rules/01-aidlc.md` の Design Freeze 条件は「回答されないまま確定させない」であり、
  **この 3 件が未回答のまま同書を Freeze 範囲に入れることはできない**。
- **修正案**: ①`auth-accounts.md` を対象にした**独立した 1 巡目レビューを実施する** (本レビューは代替にならない) ②`README.md:319`〜`:320` の 36/109 を実数で確定し、根拠の節番号を正す (`auth-accounts.md:86` を指すべき) ③R-AA-7 を `observability.md` §4.5 に反映するか、未反映のまま Freeze する場合は**先送り先と増分**を書く ④`aidlc-docs/inception/productionization/plan.md` の Task-3i を `[x]` + レビュー未実施の注記へ。

---

## 4. 中 (Should Fix)

### 中 1. `docs/design/operations.md:706` (§8 本番観点の回答表 D-6 行) が「`[Answer]` 待ち」のまま — §5.2 で確定済み

- **事実**: `:706` = 「⑤**dev / prod で Environment を分けるかは `[Answer]` 待ち・暫定既定は「分ける」** (§5.2)」。一方 `:346` に `[Answer]` が記入され (「確認済み — 複数作成できる。…そのまま確定とする」)、`:797` の OP-R8 は「**解消 (2026-07-30)**」。
- **なぜ問題か**: **§8 は `08-production-gates.md` が要求する「ID への回答」の所在表**であり、design-reviewer と実装リポが D-6 の状態を判定する場所。ここが「待ち」だと、**確定した 2 つの新規要求 (Environment を不変として扱う運用 / prod の `limited` networking + `allowed_hosts`) が実装計画に載らない**。
- **DR-8 の再発 (同一サブパターン 4 度目)**: `feedback_review_patterns.md` DR-8 が挙げる「③§6.3/§6.4 を改訂して §7 の回答表が旧記述」と**同型**。
- **修正案**: `:706` の⑤を「**dev / prod で Environment を分けることを確定 (§5.2 の `[Answer]`)。併せて (a) Environment は不変として扱い変更時は新規作成 + ID 差し替え (b) prod は `networking.type = limited` + `allowed_hosts` 明示列挙**」へ。併せて `:323` の見出し「(D-6 の**未確定**)」と `:330` / `:333` の「**暫定既定**」表記を確定後の語に直す (`[Answer]` の直前に「暫定既定」が残っていると、表だけ読んだ読者が未確定と誤認する)。

### 中 2. `docs/design/llm-migration.md:373` がプロバイダ例外を「Exa + Gemini」= 2 つのまま — LM-D は「第 1 リリース時点で 3 つ」に改訂済み

- **事実**: `:110` (LM-D) = 「例外は **第 1 リリース時点で 3 つ** (2026-07-31 確定): Exa / Gemini / **RAG の埋め込み = 未選定のプロバイダ**」。一方 `:373` (v2 → v3 の対比表) = 「変更後: **Anthropic 主系 + Exa + Gemini (画像のみ)**」。
- **なぜ問題か**: この対比表は「v3 で何プロバイダを面倒見るか」を読む場所であり、**gateway 実装の本数見積り (§10.1) と単価テーブルの行数がここで 1 本少なく見える**。`:801`〜`:806` は「M-0 の gateway 実装にプロバイダ 1 本が追加される」と明記しているので、表だけが取り残されている。
- **修正案**: `:373` の「変更後」を「**Anthropic 主系 + Exa + Gemini (画像のみ) + 埋め込み 1 本 (未選定。別トピック)**」へ。

### 中 3. `docs/design/API/idea-boards.md` §8 の出典行番号が 1 ずれ (3 箇所) / プロトタイプ引用の帰属が誤り (1 箇所)

- **事実 (照合 #6・#7・#11・#12)**:
  - `:342` / `:408`: 「`schema.sql:155`〜`:158` = `concept` / `customer` / `issue` / `solution`」→ 実際は `155 concept` / `156 target_market` / `157 customer` / `158 issue` / `159 solution`。**`solution` は範囲外、`target_market` が範囲内**
  - `:405`: `market_size` = `:159` → 実際 `:160` / `:406`: `cagr` = `:160` → 実際 `:161`
  - `:404`: `tags:[...]` = `:10488` → 実際 `:10487` (`:10488` は `concept:`)
  - `:404`: 「**ボード一覧のモック**も配列 (`:12675`)」→ `:12675` は `PAST_THEMES` = **新規ボード作成ウィザードの過去テーマ選択**のデータ (`:12630`〜`:12677`)
- **なぜ問題か**: **結論 (6 列が v2 に実在し同名で写せる) は正しい**ので設計は壊れていない。ただし §8 は「IB-Q14-4 = `concept` → `summary` の 1 列のみが未対応」という**排他的な主張**の根拠表であり、行を辿った実装者が `target_market` に着地すると表そのものの信頼性が落ちる (DR-1 の軽度形)。
- **修正案**: 4 箇所を実測値へ。併せて **v2 `target_market` → v3 `target_market` (同名。`data-model.md:530` の `ideas` 行に実在)** を照合表に 1 行足すと「§8 が v2 の列を網羅している」ことが示せる。

### 中 4. `docs/design/API/idea-boards.md:404` の「プロトタイプは配列」という事実が不完全 — ボード詳細のモックは**単数 `tag`**

- **事実**: `docs/prototype/hassan_agent_prototype_v2.html:11950` = `{ id:"b1-i4", …, tag:"脱炭素インフラ", …}` (`BOARDS[].items[]`)。§8 の表は「現在の `Idea` (§2.1) は **`tag` (単数)** — JSON 例に 1 回だけ現れ、**出典・格納先の記述が無い**」と書いているが、**出典は存在する** (ボード詳細アイテムのモック)。テーマ内アイデア一覧 (`:10487`) は複数形 `tags:[…]`、ボードアイテムは単数 `tag` で、**プロトタイプ内で 2 形式が併存している**。
- **なぜ問題か**: `tags: string[]` に統一する決定 (§8.1) 自体は妥当 (BE-10 を潰す方向で、ユーザー決定もある)。**ただし「ボード詳細の行は 1 タグしか表示しない UI」である可能性が残る** — `BoardItem.idea.tags` が 2 件以上返ったときの表示は FE の未確定事項になる。§8 が「単数の出典は無い」と書いているためこの論点が起票されていない。DR-7 の裏返し (プロトタイプを仕様にしないのは正しいが、**事実の記述としては不正確**)。
- **修正案**: §8 の該当セルに `:11950` を出典として追記し、「**プロトタイプ内で 2 形式が併存 (テーマ一覧 = 配列 / ボードアイテム = 単数)。v3 は配列に統一するため、ボード詳細での表示件数上限は FE 要件として `docs/design/frontend.md` へ申し送る**」を 1 行加える。

### 中 5. 未回答 `[Answer]` 6 件のうち **FE-Q7 は 2 文書間の矛盾を放置している**

- **事実**: `docs/design/frontend.md:1198` の FE-Q7 (管理者経路の WAF IP 制限) が未回答。暫定既定は③ (IP 制限を諦め MFA + レート制限 + 監査 + SuperAdmin 複数運用で担保)。一方 `docs/design/auth.md:554`〜`:557` は「③社内管理者系エンドポイントを **WAF の IP 許可リストで社内からのみ到達可能にする**」「MFA を主たる防御とし、**IP 制限は多層防御として併用する (どちらかで代替しない)**」と書いたまま。
- **なぜ問題か**: `auth.md` は**認証の SSOT**。実装リポが `auth.md` を読んで WAF ルールを前提に設計すると、`frontend.md` FE-D (BE 呼び出しは全てサーバ側 = ALB が見る送信元は Vercel の Function) の下で**成立しない防御を「担保済み」と数えてしまう**。A-2 の多層防御の実効性が文書上だけの状態になる。
- **修正案**: FE-Q7 をユーザーに確定させる。**Freeze を先に通すなら**、`auth.md:557` に「**FE-D 採用により FE 経由の管理者経路では IP 制限が成立しない (frontend.md §11.3.2 / FE-Q7)。成立するのは BE を直接叩く経路のみ**」の 1 文を**同じ差分で**入れる (矛盾を「未確定」として可視化する)。

### 中 6. `templates/backend-repo/.github/workflows/ci.yml:102` のコメントが「#4 / #5」のまま

- 同ファイル `:111`〜`:113` のエラーメッセージは #4 / #5 / **#7** を列挙しているのに、直上のコメント (`:102`) は「(testing.md §10 の #4 / #5)」。**機構は直っているがコメントが旧版** — 実装リポでスクリプトを書く人はコメントを先に読む。重大 1 の修正 5 と同じ差分で直す。

---

## 5. 軽微 (Nice to Have)

1. `docs/design/frontend.md:633` / `:1225` の「`ci.yml:58-72`」→ 実測は **`:58`〜`:71`** (`:72` は空行)。`docs/design/testing.md:650` / `:667` は `:58〜71` で正しいので、frontend 側だけがずれている。
2. `docs/design/operations.md:323` の見出し「Anthropic の Environment を環境ごとに分けるか (**D-6 の未確定**)」— 確定済みなので「(D-6。2026-07-31 確定)」等へ。
3. `docs/design/data-model.md:1012` の「除外リスト = **9 件**」は **DM-A4 の却下案 A の説明文中**なので内容としては正しいが、「9 件」で grep した読者 (および重大 2 の是正要求を書いた起草者) が現行値と誤読する。「(A を採った場合。**採用した B では 8 件** — §4.1.2)」の 1 語を足すと誤読が消える。
4. `docs/design/API/README.md:24`〜`:31` の「6 ドメイン (73 本)」「2 系統・合計 11 本」の書き分けは丁寧だが、`:319` の合計との整合が重大 3 で崩れているため、**合計値を 1 箇所 (§3 冒頭) だけに置き、他は「§3 参照」にする**ほうが今後のドリフトを防げる。

---

## 6. Freeze 可否 (スコープ別)

| スコープ | 対象ファイル | 判定 | 条件 |
|---|---|---|---|
| **層構成・依存規則・CI ゲート** | `docs/design/architecture.md` / `templates/backend-repo/.golangci.yml` / `templates/backend-repo/.github/workflows/ci.yml` | **Freeze 可** | 中 6 (ci.yml のコメント) は軽微。18 規則・`:46-49`・D-2⑨ の `gateway` は 5 件すべて実測一致 |
| **可観測性** | `docs/design/observability.md` | **Freeze 可** | ただし重大 3 の副次項目 (R-AA-7 の認証系 6 事象) が未反映。**`auth-accounts.md` を Freeze 範囲に入れるなら不可** |
| **データモデル** | `docs/design/data-model.md` | **条件付き可** | 重大 2 の連動 7・8 (`:195` / `:1061` の「31 件」が機械検査の期待値であること) を §8.2 側に記録すること。§6.4 の `[Answer]` 未回答は既知の DR-3 追跡項目として許容 |
| **運用・インフラ** | `docs/design/operations.md` / `docs/design/infrastructure.md` | **条件付き可** | **中 1 (D-6 回答表の旧記述) を直すこと**。`[Answer]` 未回答 3 件 (Q-INF-1 / Q-INF-3 / アラート宛先) は「IaC の適用範囲と宛先の値」であり、設計判断ではなく値の確定なので Freeze 後の埋め込みで可 |
| **LLM 移行** | `docs/design/llm-migration.md` | **条件付き可** | 中 2 (`:373` の例外 2 つ) を直すこと |
| **テスト戦略・フロントエンド** | `docs/design/testing.md` / `docs/design/frontend.md` | **Freeze 不可** | **重大 1** (存在検査 5/6/7 種のドリフト 5 箇所)。DR-8 の 4 巡目再発であり、修正時は grep の出力を証拠として添えること。加えて中 5 (FE-Q7 と auth.md の矛盾) |
| **API (6 ドメイン)** | `docs/design/API/idea-boards.md` / `assets.md` / `themes.md` / `settings.md` / `README.md` / `knowledge.md` / `news.md` | **Freeze 不可** | **重大 2** (§8.2 の連動リスト不完全 + 誤った是正要求) / **重大 3** (README の総数不整合)。`idea_tags` の**未反映そのものは容認** (§3 重大 2 の判定を参照) |
| **API (認証・アカウント基盤)** | `docs/design/API/auth-accounts.md` | **Freeze 不可 (未レビュー)** | **重大 3**。独立した 1 巡目レビューが必要。本レビューは代替にならない |

**総合**: **Freeze 条件付き不可**。**重大 3 件 (重大 1 / 重大 2 / 重大 3) を解消し、中 1・中 2 を反映した時点で、`auth-accounts.md` を除く 16 文書は Freeze 可**。`auth-accounts.md` は別途 1 巡目レビューを通してから合流させること。

**再レビュー時に必ず確認する項目 (次の巡の入力)**:
1. `grep -rn "5 種\|6 種\|7 種" docs/design/` の出力 (重大 1 の完了証拠)
2. `grep -rn "39 テーブル\|39 件\|31 件\|テーブル 39\|例外 11" docs/ aidlc-docs/inception/` の出力 (重大 2 の完了証拠)
3. `docs/design/API/auth-accounts.md` のエンドポイント実数と README の合計値の一致
4. `docs/design/operations.md:706` の D-6 行

---

## 7. 良かった点

1. **DR-8 対策が文書自身に組み込まれ始めた**。`docs/design/llm-migration.md:791`〜`:795` は「同じ問いに 2 度反映した記録」を残し、**「別で設計する」は「別のリリースにする」ではない**という混同の型を明文化して「リリース時期と設計担当トピックを必ず分けて書く」を規約化している。これは**レビューで指摘される前に起草側が再発防止を書いた**唯一の例。
2. **`docs/design/API/idea-boards.md` §8 が BE-10 を自力で検出した**。「API が返すと宣言しているフィールド (`Idea.tag`) に**書き込む側が存在しない** (v2・v3 のどちらにもタグ列が無い)」を発見し、§8.1 で読み手の契約を確定させつつ `:430` で書き込み側を Task-3p に明示的に紐付けている。**§8.2 の連動リストという発想自体が正しい** (不完全さは重大 2 で指摘したが、方向は模範的)。
3. **`docs/design/operations.md:346`〜`:364` の一次ソース調査**が、問いへの回答 (複数作成できる) だけで終わらず**含意 4 件を設計変更として引き出している** — 特に「Environment は版管理されない → 設定を不変として扱い新規作成 + ID 差し替え」は、放置すれば「SSM の版履歴で戻せるはずが戻せない」という本番障害になっていた。含意 3 (サンドボックスはセッション単位で分離) で **A-6 の懸念範囲をツール引数の所有者チェックに正しく絞り込んだ**点も良い。
4. **`docs/design/frontend.md` §16.1 の FE-Q2 が測定項目を 4 → 1 に削減した**。「③実行時間課金の概算」の**式そのものが誤っていた** (active CPU は I/O 待ちを含まない) ことを自ら認めて差し替え、**Edge ランタイムの排除を設計判断として固定**した。`:518` と `:1107` の 2 箇所で一貫しており、この判断に関する DR-8 は無い。
5. **`docs/design/testing.md:651` の存在検査 #7 が「規約では塞げない残余」を正確に特定している**。「CI は常に `DATABASE_URL` を設定する (`ci.yml:73`〜`74`) ので `TestMain` の `log.Fatal` は CI では発火せず、実際の抜け道は個別テストへの `if os.Getenv("DATABASE_URL") == "" { t.Skip() }` である」— **機構の限界を実物の行番号で示してから検査を追加**しており、BE-5 / T-F13 の再演余地を規約遵守ではなく検査で閉じている。
6. **`gateway` の 3 箇所同時反映**が実測と完全に一致 (`ci.yml:264` / `.golangci.yml:322`・`:344`・`:346` / `architecture.md:262`・`:400`・`:800`)。「機構と文書を同じ差分で直す」が**この項目については達成できている** — 重大 1 との対比で、達成可能であることの証拠。
7. **`docs/design/API/assets.md:179` の AS-Q11 の起票品質**。「D-AS-4 は『3 系統になる』を理由に専用 API を却下しているため、**4 系統目が黙って増えると同じ判断の根拠が崩れる**」— 却下理由の前提が壊れることを検出して `plan.md:124`〜`:126` の Task-3p スコープに制約として引き継いでおり、プロトタイプの発見を仕様化せず制約化している (DR-7 を正しく回避)。

---

## 3 巡目指摘の反映 — 第 1 陣 (2026-07-31・メインセッション)

**起草側 (私) の誤りだったものを先に直した**。残りは下表の「未対応」。

| 指摘 | 反映先 | 内容 |
|---|---|---|
| **重大 1** の一部 (起草側の波及漏れ) | `docs/design/testing.md`:101 | **T-N の要約行が「6 種」のまま**だった (§10 は 7 種)。→ **7 種**へ。#7 の中身も 1 行で明記 |
| 同 | `templates/backend-repo/.github/workflows/ci.yml`:102 | コメントが「§10 の **#4 / #5**」のまま。→ **#4 / #5 / #7** へ |
| 同 | `docs/design/frontend.md`:634〜638 | 「§10 の存在検査 **5 種**に本検査は含まれていない / 登録を是正要求として出す」→ **「登録は完了済み (#6 として 6 種へ、7/31 に #7 が加わり 7 種)」**へ。要求が解消済みである旨を明記 |
| 同 | 同 `:1233`〜 | 「§10 への登録が**必要**」→ **①は反映済み**と状態を明示 (②③は未反映のまま残す) |
| **重大 2** | `docs/design/API/idea-boards.md` §8.2 | **連動箇所を 6 → 9 件へ修正**。漏れていた 3 件 (`data-model.md:195` / `:1061` = **どちらも機械検査の期待値 31 件** / `plan.md:103`) を表に追加。**7・8 を落とすと「設計どおり実装した検査が必ず落ちる」形で実装リポに出る**ことを明記 |
| 同 (誤りの訂正) | 同 §8.2 の末尾 | **「`architecture.md:759` の『例外 11』は旧記述」という初版の注記は誤り**だったため、訂正ブロックを追記。**11 = `data-model.md:362` の「機能テーブル以外の 11 テーブル」= 現行の正しい値** / **8 = §7.2 検査①の除外リスト件数**で、2 つの別の数を混同していた。**「例外 11」を直してはいけない** (直すと正しい記述が壊れる) ことを明示 |

**再検査 (DR-8 の手順)**: `存在検査 5 種` / `6 種の「必須テスト` / `#4 / #5` を `docs/` `templates/` 全体に grep。
残ヒットは `frontend.md:1234` の 1 件のみで、これは**「起票時点では 5 種だった」という経緯の記述**であり現状の主張ではない (意図的に残す)。

### 未対応 (この差分では直していない)

| 指摘 | 理由 |
|---|---|
| **重大 3** (`auth-accounts.md` 37 本が未レビュー) | **別セッションの成果物**であり、起草者がレビュー依頼を出す筋。**なお本数の食い違いは既に解消済み** — `README.md:319`〜`:320` は現在「**合計 110** = 73 + **37**」で `auth-accounts.md` の実数 (37) と一致する (レビュー時点の「36 本 / 合計 109」はレビュー実行中の 08:44 に更新された)。**未レビューである事実は残る** |
| **重大 2 の本体** (`idea_tags` の 9 箇所反映) | 是正要求として §8.2 に確定。**反映は独立タスク** (todo に起票済み)。レビュアーも「①②③を直せば未反映のまま Freeze 可」と判定している |
| 中 1〜中 6 / 軽微 1〜4 | 未着手。中 5 (FE-Q7 と `auth.md:554`〜`:557` の矛盾) は**ユーザー判断待ちの項目**を含む |
| Vercel 数値の一次ソース照合 (残課題 1) | レビュアーはネットワーク不可で未照合。**メインセッションでは 2026-07-31 に `vercel.com/docs/functions/limitations` (`last_updated: 2026-07-01`) を実際に取得して確認済み**であり、`frontend.md` §16.1 の数値はその引用。ただし**レビュアー独立の照合は未実施**という状態は正しい |
