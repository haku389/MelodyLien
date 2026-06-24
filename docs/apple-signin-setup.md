# Sign in with Apple セットアップ手順（実機で動かすために必要）

コード側（SDK・UI・ロジック）は実装済み・ビルド済み。**実行時に動かすには下記の設定が必要**で、
①②はあなたの Apple Developer / Supabase 操作、③は私（コード/設定反映）が担当。

## 大前提

- **有料の Apple Developer Program**（年 99 USD）が必要。Sign in with Apple は無料アカウントでは使えない。
- アプリの Bundle ID は **`com.streetmelody.app`**。

## ① Apple Developer 側（あなた）

1. **App ID**: Certificates, Identifiers & Profiles → Identifiers → `com.streetmelody.app` を作成/選択し、
   **Sign In with Apple** capability を ON。
2. **Services ID**（Supabase 連携用）: Identifiers → 新規 **Services ID**（例 `com.streetmelody.signin`）を作成し、
   Sign In with Apple を有効化。Web Authentication で **Return URL** に
   `https://wngtvdgzzlkajtbwsurc.supabase.co/auth/v1/callback` を登録。
3. **Sign in with Apple Key**: Keys → 新規キー（Sign In with Apple 用）→ `.p8` をダウンロード。
   **Key ID** と **Team ID** を控える。

## ② Supabase ダッシュボード（あなた）

- Authentication → Sign In / Providers → **Apple を有効化**。
  - **Service ID**（①-2 の Services ID）
  - **Team ID / Key ID / Secret Key（.p8 の中身）**（①-3）
  を入力して保存。

## ③ コード/プロジェクト側（私）

- `apps/ios/project.yml` に **Sign in with Apple entitlement** を追加：
  ```yaml
  entitlements:
    path: StreetMelody/StreetMelody.entitlements
    properties:
      com.apple.developer.applesignin: [Default]
  ```
  と **`DEVELOPMENT_TEAM: <あなたの Team ID>`** を設定（Team ID をもらってから。空のままだと署名できない）。
- → これで実機/シミュレータの Sign in with Apple が機能。

## 実装済みのコード

- Supabase Swift SDK（SPM, 2.48.0）導入。
- `Services/SupabaseAuthKit.swift`: SDK で `signInWithIdToken(.apple)` → セッションを REST データ層へ橋渡し。
- `AccountLinkView`: `SignInWithAppleButton`（nonce 生成・SHA256）。
- `AppViewModel.signInWithApple`: サインイン → 進行を `mergeRemoteProgress` で復元。

## 補足：データ引き継ぎ（匿名→Apple）

- 現状の実装は「Apple でサインイン（＝Apple ユーザーのセッションに切替）」。**今プレイ中の匿名ユーザーの進行を
  そのまま引き継ぐ**には Supabase の `linkIdentity`（OAuth リダイレクト）を使う方式が適切。
  ①②が整い実機検証できる段階で、「新規サインイン」か「匿名から昇格（link）」かを確定して仕上げる。
