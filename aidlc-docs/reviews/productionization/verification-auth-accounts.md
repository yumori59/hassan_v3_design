# オーケストレーターによる検証記録: auth-accounts.md

> **これは正式なレビューではない**。`.claude/rules/04-review.md` が要求する `design-reviewer` による
> 第三者レビューは**未実施**であり、本ファイルは push ゲート (`review*.md`) を満たさない命名にしてある。
> 本ファイルの位置づけは `06-delegation-prompts.md` の**責務 1 (報告の抜き取り検証)** の実施記録である。
>
> **経緯**: 2026-07-31 に `design-reviewer` を起動したが、**API のストール / 接続断で 4 回連続して失敗**した
> (照合は完了したと報告しつつ成果物を書き出せなかった)。起草者の報告に含まれる**重大主張を未検証のまま
> 設計に残さない**ため、オーケストレーターが一次ソースで独立に照合した。

**検証対象**: [../../../docs/design/API/auth-accounts.md](../../../docs/design/API/auth-accounts.md) (Task-3i の成果物)

---

## 1. 結論

**起草者が報告した「v2 の新発見欠陥 3 件」はいずれも実在する**。うち V2-D1 は**認可の欠陥**であり、
v2 の本番環境に現存する。v3 側の対策 (AA-D-5) はこの穴を構造的に塞いでいる。

**この検証は正式レビューの代わりにならない** — 設計判断の妥当性・網羅性・他文書との整合は未判定 (§4)。

---

## 2. 一次ソース照合の結果 (7 件照合 / 7 件一致 / 不一致 0)

| # | 主張 (auth-accounts.md) | 照合先 | 結果 |
|---|---|---|---|
| 1 | **V2-D1: `POST /accounts/signup` が招待リンクの email と入力 email を突き合わせない** | `hassan-v2-backend/controller/account.go:258`〜`:282` / `hassan-v2-backend/usecase/account/sign_up.go:40`〜`:79` | **一致 (成立)**。詳細は §3 |
| 2 | **V2-D2: MFA コード不一致が 500 になる** | `hassan-v2-backend/controller/mfa.go:79`〜`:82` (`err` を無条件に `internalServerError` へ) / `hassan-v2-backend/usecase/mfa/verify_totp.go:59` (UseCase は `apperror.TotpCodeNotMatch()` を返している) | **一致**。UseCase は正しいコードを返すが Controller が `CodedError` の分岐を持たないため 500 になる |
| 3 | **V2-D3: リセットトークンを応答 DTO に含める型が残存** | `hassan-v2-backend/controller/dto/account.go:140` (`Hash string \`json:"hash"\``) | **一致** (型の実在を確認。実際に応答へ載る経路の有無は**未検証**) |
| 4 | **R-AA-1 の前提: MFA 検証失敗はロックカウンタを増やさない** | 加算 SQL `UpdateFailedSignInAttempts` = `hassan-v2-backend/db/queries/account.sql:57`〜`:64` (`WHERE email = $2`)。**呼び出し元は `hassan-v2-backend/usecase/account/sign_in.go:91` の 1 箇所のみ** (`grep -rn` で確認)。`usecase/mfa/` 配下の加算は **0 件** | **一致**。R-AA-1 (MFA 検証をレート制限対象に加える) は**妥当**と判定 |
| 5 | **T-Q3 (E2E の MFA 例外) の表現を本書が定義している** | 本書 §3.6 (`companies.mfa_type = 'none'` で足り、**コードに `if isE2E` の分岐を作らない**) | **一致・良い設計**。testing.md §7.3 が委譲した約束は履行されている (BE-10 型の宙吊りなし) |
| 6 | **エンドポイントは 37 本** | 本書のエンドポイント表を機械集計 (`grep -cE "^\\| (GET\|POST\|PUT\|DELETE\|PATCH) "` = **37**) | **一致** |
| 7 | **`account_deletions` テーブルが data-model.md に無い** (R-AA-4 の前提) | `docs/design/data-model.md` に `account_deletions` は **0 件** | **一致**。AA-D-13 (メンバー削除を 202 + 状態 GET) は**状態を持つ先が未定義のまま** — §4 の残課題 |

## 3. V2-D1 の詳細 (最重要)

**成立する**。経路を 2 段辿って確認した:

1. `controller/account.go:258`〜`:282` — `SignUp` は `req.SignupLinkID` と `req.Email` を**独立したパラメータ**として受け取り、
   トリムと UUID パースのみ行って UseCase へ渡す。契約・招待相手の突合は無い
2. `usecase/account/sign_up.go:40`〜`:79` — 処理順は
   ①リンク取得 → ②**存在と有効期限のみ検証** → ③パスワード確認一致 →
   ④**`GetAccountByEmail(input.Email)` で「入力された email」からアカウントを引く** →
   ⑤`IsCompleted` が false ならパスワードを設定

**`signupLink.Email` と `input.Email` を突き合わせる処理がどこにも無い**。招待リンクは招待相手にメールで届くため、
**攻撃者は自分宛の有効な招待 1 通で足りる**。契約の境界も見ていないため、**他契約の未サインアップアカウントも対象になる**。

**v3 の対策**: AA-D-5 (単一有効リンク + email 突合 + メール変更時の失効)。**この対策の有効性は正式レビューで再判定すること**。

## 4. 未検証 (正式レビューで判定すべき範囲)

| # | 未判定の項目 | なぜ重要か |
|---|---|---|
| 1 | **設計判断 AA-D-1〜16 の妥当性** (却下案の網羅性・採用理由の強度) | 本検証は「事実が正しいか」しか見ていない。**設計として正しいかは未判定** |
| 2 | **R-AA-2〜10 の是正要求の妥当性** (R-AA-1 のみ妥当と判定済み) | SSOT 側の欠陥か本書の読み違えかで、auth.md / README.md の改訂要否が変わる |
| 3 | **README.md §2.5 からの 3 つの逸脱** (401 + 本文 / 429 の 8 本 / 403 の第 3 系統) が正当化されているか | 規約の SSOT を割る変更であり、承認なしに実装リポへ渡せない |
| 4 | **frontend.md §11.1 の auth 系ルート 8 行が本書の API で満たされるか** (FE 側からの逆引き) | 画面があるのに API が無い / その逆を検出できていない |
| 5 | **`account_deletions` (R-AA-4) の未対応** | AA-D-13 の 202 + 状態 GET が**状態の置き場を持たない**。data-model.md への追加が必要 |
| 6 | **系統別内訳 (6 / 2 / 21 / 2 / 6) と 403 の 10 本** | 総数 37 は一致を確認したが、内訳は未集計 |
| 7 | **08-production-gates.md の全 ID への回答網羅** / **DR-1〜DR-8 の全件チェック** | `04-review.md` の観点 2・4。本検証では実施していない |
| 8 | V2-D3 が**実際に応答へ載る経路**の有無 | 型の実在のみ確認 (使われていない残骸の可能性がある) |

## 5. 検証コマンド

```
grep -n "SignUp" hassan-v2-backend/controller/account.go            # :258〜 の経路特定
sed -n '258,290p' hassan-v2-backend/controller/account.go            # 突合の不在を確認
sed -n '40,79p'  hassan-v2-backend/usecase/account/sign_up.go        # 同上 (UseCase 側)
grep -rn "UpdateFailedSignInAttempts" --include="*.go" .             # 加算の呼び出し元 = sign_in.go:91 のみ
grep -c "UpdateFailedSignInAttempts" hassan-v2-backend/usecase/mfa/verify_totp.go   # → 0
sed -n '55,90p' hassan-v2-backend/controller/mfa.go                  # 500 への流し込みを確認
grep -n "Hash" hassan-v2-backend/controller/dto/account.go           # :140 の型を確認
grep -cE "^\| (GET|POST|PUT|DELETE|PATCH) " docs/design/API/auth-accounts.md   # → 37
grep -n "account_deletions" docs/design/data-model.md                # → 0 件
```

## 6. 次のアクション

1. **正式レビュー (`design-reviewer`) を実施する** — §4 の 8 項目が対象。**v2 リポジトリの再照合は不要**
   (本ファイルの §2 を入力として渡せば、レビューアは文書の内容判定に集中できる)。
   4 回の失敗は**参照ファイルの多さによる文脈肥大**が原因と見られるため、**対象を文書内の判定に絞る**こと
2. **R-AA-4** (`account_deletions`) を data-model.md へ反映するか、AA-D-13 を同期 API に変えるかを決める
3. R-AA-1 は**妥当と判定済み**なので、auth.md §6.11-3 への反映を担当セッションへ依頼する
