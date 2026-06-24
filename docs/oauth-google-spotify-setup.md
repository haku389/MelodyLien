# Google / Spotify サインイン セットアップ手順

コード（SDK・OAuth フロー・ボタン・リダイレクト URL スキーム）は実装済み・ビルド済み。
**実行時に動かすには各プロバイダの登録＋Supabase 設定が必要**（あなたの作業）。

## 共通：Supabase のリダイレクト URL 許可

Supabase ダッシュボード → Authentication → **URL Configuration → Redirect URLs** に
**`com.streetmelody.app://login-callback`** を追加（アプリの URL スキームと一致。コードで登録済み）。

各プロバイダの Supabase 側コールバックは共通で：
`https://wngtvdgzzlkajtbwsurc.supabase.co/auth/v1/callback`

---

## ① Google（既存の GCP プロジェクト `streetmelody` を流用可・無料）

1. GCP Console → **APIs & Services → OAuth 同意画面** を設定（外部・アプリ名・サポートメール等）。
2. **APIs & Services → 認証情報 → 認証情報を作成 → OAuth クライアント ID**
   - 種類: **ウェブ アプリケーション**
   - **承認済みのリダイレクト URI**: `https://wngtvdgzzlkajtbwsurc.supabase.co/auth/v1/callback`
   - 作成後の **クライアント ID / クライアント シークレット** を控える。
3. Supabase → Authentication → Providers → **Google を有効化**し、クライアント ID / シークレットを入力して保存。

## ② Spotify（無料）

1. **Spotify Developer Dashboard**（developer.spotify.com）→ Create app
   - **Redirect URI**: `https://wngtvdgzzlkajtbwsurc.supabase.co/auth/v1/callback`
   - **Client ID / Client Secret** を控える。
2. Supabase → Authentication → Providers → **Spotify を有効化**し、Client ID / Secret を入力して保存。

---

## 実装済みのコード

- Supabase Swift SDK（SPM 2.48.0）。
- `Services/SupabaseAuthKit.swift`: `signInWithGoogle()` / `signInWithSpotify()`
  = `auth.signInWithOAuth(.google/.spotify, redirectTo: com.streetmelody.app://login-callback)`
  → `ASWebAuthenticationSession`（表示アンカーあり）→ セッションを REST データ層へ橋渡し。
- `AccountLinkView`: 「Google で続ける」「Spotify で続ける」ボタン。
- `project.yml`: `CFBundleURLTypes` に `com.streetmelody.app` スキーム登録。

## 補足：データ引き継ぎ（匿名→Google/Spotify）

- 現状は「サインイン（＝そのプロバイダのユーザーに切替）」。**今プレイ中の匿名ユーザーの進行をそのまま引き継ぐ**には
  `linkIdentity`（同じ Web フロー）を使う。①②が整い実機検証できる段階で、
  「新規サインイン」か「匿名から昇格(link)」かを確定して仕上げる（Apple と同方針）。

## 動作確認（設定後）

1. アプリ → マイページ → アカウント → 「アカウントを連携 / ログイン」→ Google/Spotify ボタン。
2. Web 認証 → アプリに戻り、`auth.users` に該当プロバイダのユーザーが作成される。
3. （リダイレクトが弾かれる場合は Supabase の Redirect URLs と URL スキームの一致を確認。）
