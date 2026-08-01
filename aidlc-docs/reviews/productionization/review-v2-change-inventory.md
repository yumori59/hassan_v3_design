# レビュー: v2→v3 変更リストの網羅性 + 整合是正 (P1〜P6)

- **日付**: 2026-08-01
- **レビュアー**: 別セッションの `design-reviewer` (opus)。起草 (メインセッション) とは分離
- **対象**: ①v2→v3 変更リスト (アーティファクト。設計書群からの抽出ビュー) の網羅性・正確性
  ②その照合過程で検出された**設計書側の欠陥 6 件 (P1〜P6)** とその是正 (コミット `c1f5b7b`)
- **観点**: 全設計書の判断 ID 群 (D-x / DM-x / D-API-x / D-TH/AS/IB/NW/ST-x / AA-D-x / LM-x /
  O-x / OP-x / INF-x / T-x / FE-x) との突き合わせ + 数値の抜き取り照合 13 件 + `make check`

## 1. レビュー対象・言及する設計成果物 (リポジトリ相対パス)

今回 push するレンジで変更された設計成果物:

| パス | 変更内容 | レビュー状態 |
|---|---|---|
| docs/design/API/README.md | §3 総覧の三重不整合の是正 (idea-boards 22 / 小計 79 / 合計 116)、§3.2 にアセット 5 本・§3.4 に `GET /ideas/csv` を追加 (R-12)、§0 の件数転記を DR-9 に従い削除 | 是正 = 本レビューの P1 指摘への対応。`make check-endpoint-mapping` 23 件で機械照合済み |
| docs/design/API/assets.md | §3.3 一括系の C-16 仕様化 (前セッション作業。D-AS-14〜18・AS-Q3 クローズ撤回) | 本レビューの正確性照合で内容を確認 (R3 の根拠として全文参照) |
| docs/design/API/auth-accounts.md | AA-D-13 の「28 テーブル」→ 29 (DR-8 波及是正) | 実測 (check-table-counts 分類① 29) と一致 |
| docs/design/auth.md | §10.4 R-12 を対応済みに更新 (受信欄の状態更新) | 対応内容とパスを本レビューで確認 |
| docs/design/data-model.md | P2: 移管対象 29 テーブルへ訂正 (2 箇所) / P3: `email_hash` を HMAC-SHA256 + `AUDIT_EMAIL_HMAC_KEY` に統一 / P5: `workspace_settings` を `default_*_visibility` 3 列へ / §7 D-4 を psqldef 確定に (DR-8) | 是正 = P2/P3/P5 指摘への対応。SSOT (observability.md §4.5.2 / settings.md D-ST-3 / §6.1 [Answer]) と一致することを確認 |
| docs/design/frontend.md | §11.1 `/ideas` 行に CSV エクスポートボタンの配置と `GET /ideas/csv` を追記 (R-12 ②) | R-12 の指示どおり |
| docs/design/infrastructure.md | P4: D-4 の「psqldef / golang-migrate 未確定」→ psqldef 確定 (2026-07-31。SSOT: data-model.md §6.1) | DR-8 是正 |
| docs/design/operations.md | OP-I の「73 本」転記を削除し §3 参照へ (DR-9) | DR-8/DR-9 是正 |
| docs/analysis/v2-feature-inventory.md | 新規 (前セッション作業) + §5 の #7/#8 を解消済みに更新 (P6) | 本レビューが §5 全文を照合に使用 (重大 R1 の根拠) |
| docs/analysis/gap-analysis.md | ヘッダ追記 (前セッション作業・軽微) | 参照のみ |
| docs/design/README.md | 新規 (設計書の索引。前セッション作業) | 索引のみ (設計判断を含まない) |
| aidlc-docs/inception/productionization/requirements.md | C-16 追記 (前セッション作業) | 本レビューが C-16 承認済み例外表を照合に使用 |
| templates/README.md / templates/backend-repo/CLAUDE.md.tmpl / templates/frontend-repo/CLAUDE.md.tmpl / templates/backend-repo/.github/ISSUE_TEMPLATE/task.yml / templates/frontend-repo/.github/ISSUE_TEMPLATE/task.yml / templates/shared/.claude/rules/03-model-escalation.md | 前セッションの軽微修正 (文言・リンク) | **本レビューの対象外** (設計判断を含まない軽微差分。`make check-workflow-shell` 52 ブロック通過で機械検証のみ) |

## 2. 指摘と対応状況

### 変更リスト (アーティファクト) への指摘 — 反映済み

- **重大 4 件**: R1 C-16 判断待ち 6 件の欠落 / R2 告知対象の不一致 (企業ミッション・切り戻し制約) /
  R3 アセット行の v2 事実誤認 (一括系は v2 で稼働中) / R4 層規約の適用範囲 (2 規約併存) の欠落
- **中 7 件・軽微 8 件**: 22 経路 (≠22 モデル)、LM-Q2 統合対象 5 件、エンドポイント 116 本、
  D-API-8' の出典ズレ (R-9 未反映)、O-F 欠落、テーマ行のプロトタイプ混入 (DR-7)、未確定 7 件の取りこぼし ほか
- すべて 2026-08-01 にアーティファクトへ反映済み (リポジトリ外の成果物のため本コミットに差分なし)

### 設計書側の欠陥 (P1〜P6) — コミット `c1f5b7b` で是正済み

| # | 欠陥 | 是正 |
|---|---|---|
| P1 | API/README.md §3 総覧の三重不整合 (合計 78 ↔ 小計 73 ↔ §3.2 明細 17 行)。既存の検査①〜③をすり抜けていた | 総覧・明細・小計を実測に一致させ、**`scripts/check-endpoint-mapping.sh` に検査④ (ドメイン別実測 ↔ 総覧行・§3.1〜3.6 明細・小計・共通規約注) を追加**。故障注入 2 種 (総覧行の改ざん / 明細行の削除) で `exit 1` を確認。`.claude/rules/05-harness.md` を同差分で更新 (rule 06 の手順) |
| P2 | data-model.md の「移管対象 28 テーブル」(正: 分類① = 29) | 2 箇所 + auth-accounts.md の波及 1 箇所を 29 に訂正 |
| P3 | data-model.md §4.10 の `email_hash` 例が鍵なし SHA-256 (SSOT は HMAC+pepper) | HMAC-SHA256 + `AUDIT_EMAIL_HMAC_KEY` に統一 (BE-12 型の食い違い解消) |
| P4 | infrastructure.md に「psqldef / golang-migrate 未確定」の旧記述 (DR-8) | psqldef 確定 (2026-07-31) に更新。data-model.md §7 の同型の旧記述も是正 |
| P5 | data-model.md の `workspace_settings` が 1 列 (settings.md D-ST-3 は 3 カテゴリ) | `default_theme_visibility` / `default_asset_visibility` / `default_idea_visibility` の 3 列に |
| P6 | v2-feature-inventory.md §5 の #7/#8 が解消済みなのに未更新 (§6 の運用ルール違反) | 解消済み (assets.md §3.3) と明記、末尾の対象列挙を「6・9・10」に |

## 3. 検証結果 (是正後)

```
make check:
[doc-lint] 対象 94 ファイル / エラー 0 件 / 警告 38 件 (既知の未回答 [Answer] 等)
[traceability] productionization 47/47・construction-workflow 24/24 カバー
[workflow-shell] 検査 52 ブロック / エラー 0 件
[table-counts] 照合 37 件 / エラー 0 件 (分類① 29 = 本レビューの訂正値と一致)
[endpoint-mapping] 実測: auth-accounts.md 37 本 / 6 ドメイン 79 本 / 照合 23 件 / エラー 0 件
```

故障注入 (検査④の検出力): 総覧表 idea-boards 22→21 の改ざん → exit 1 / §3.2 明細 1 行削除 → exit 1 / 復元後 exit 0。

## 4. 残課題 (本レビューで確認済み・未対応のまま push する項目)

| # | 内容 | 所在 |
|---|---|---|
| 1 | **R-9 (未対応)**: `scope=contract` 増分 1 前倒しの波及 — API/README.md D-API-8'・§3 の「(増分 2)」表記・§5 A-7 行・assets.md D-AS-12・settings.md §2/§3.2・frontend.md の workspace 行が旧記述のまま。増分 1/2 の作業単位を 1 差分で書き換える必要がある | [../../../docs/design/auth.md](../../../docs/design/auth.md) §10.4 R-9 |
| 2 | **C-16 判断待ち 6 件** (契約 CRUD / 契約一覧 / 管理者 CRUD / 横断検索 / CSV / `GET /companies/genai`)。契約作成は全面切替 (C-15) のブロッカー | [../../../docs/analysis/v2-feature-inventory.md](../../../docs/analysis/v2-feature-inventory.md) §5 |
| 3 | `GET /companies/genai` の扱いが設計書間で不一致 (auth-accounts §2.7 対象外 / llm-migration V-16 移送) — #2 の判断と同時に一本化する | 同上 §5-6 |
