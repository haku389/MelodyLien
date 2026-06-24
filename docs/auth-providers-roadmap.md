# ログイン手段の拡張ロードマップ（メール / Google / Apple / LINE / Spotify）

方式A（クライアント直結）の上に、複数のログイン手段を載せる計画。
**重要な前提**: どの手段で「連携」しても、今の匿名（ゲスト）ユーザーを**昇格**させる形にすれば
進行データ（ピース・解放・ヒント・コイン・フレンド）はそのまま引き継がれる。

## いま実装済み

- 匿名サインイン（端末＝1ユーザー）。
- メール＋パスワード連携（`upgradeToEmail`）／ログイン（`signInWithEmail`）／ログアウト。
  - **「Confirm email」は ON 推奨**（本番の正しい挙動）。連携時に確認メール送信→リンクで完了。
    アプリは「確認メール送信」状態を表示する。

## プロバイダ別の方針

| 手段 | Supabase 対応 | 必要なもの（あなた側） | iOS 実装 |
|---|---|---|---|
| メール | ネイティブ | なし | 実装済み（REST） |
| Google | ネイティブ OAuth | GCP OAuth クライアント ID | SDK or ASWebAuthenticationSession |
| Apple | ネイティブ（id_token 可） | Apple Developer の Sign in with Apple 設定 | Sign in with Apple → `grant_type=id_token` |
| Spotify | ネイティブ OAuth | Spotify Developer アプリ | SDK の OAuth フロー |
| LINE | **非ネイティブ**（カスタム OIDC） | LINE Developers チャネル＋OIDC 設定 | OIDC リダイレクト処理 |

## 推奨アーキテクチャ

1. **Supabase Swift SDK（SPM）を導入**。OAuth は PKCE＋リダイレクト処理が要るため、REST 手書きより SDK が堅い。
   現状の最小 REST クライアントは「匿名・メール」までは十分だが、OAuth は SDK に寄せるのが楽。
2. **匿名ユーザーへの紐付けは `linkIdentity`（OAuth）/ `updateUser`（メール）** を使う＝データ保持のまま昇格。
3. 各プロバイダは **ダッシュボードでの有効化＋各開発者コンソールでのアプリ登録（client id/secret・リダイレクトURL）** が前提（あなたの作業）。
4. リダイレクト URL（ディープリンク）を iOS の URL Scheme / Universal Links に登録。

## 進め方（着手時）

1. Supabase Swift SDK 導入（`project.yml` に SPM 依存追加 → 既存 `SupabaseClient` を SDK ベースに段階移行 or 併用）。
2. まず **Apple**（iOS と相性が良く審査上も推奨）→ Google → Spotify → LINE の順が無難。
3. プロバイダ毎に: 開発者コンソール登録 → Supabase ダッシュボードで有効化 → iOS にボタン追加 → `linkIdentity`/サインイン。
4. `AccountLinkView` にプロバイダボタンを追加（現在はメールのみ）。

> 各プロバイダの client id/secret・リダイレクト設定はあなたの開発者アカウントが必要なため、
> 着手のタイミングで一緒に進めるのが効率的。
