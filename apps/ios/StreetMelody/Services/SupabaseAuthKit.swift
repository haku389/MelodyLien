import Foundation
import Supabase

// MARK: - SupabaseAuthKit
//
// OAuth/OIDC プロバイダ（Apple など）用の Supabase Swift SDK ラッパー。
// SDK で認証し、確立したセッションを REST 版 `SupabaseClient`（per-user データ層）へ橋渡しする。
// これにより「認証は SDK / データ読み書きは実証済みの REST 経路」を両立する。
//
// 将来 Google / Spotify / LINE を足すときは、ここに linkIdentity / signInWithOAuth を追加する。

enum SupabaseAuthKit {

    /// SDK クライアント（型名衝突を避けるため `Supabase.SupabaseClient` を明示）。
    static let client = Supabase.SupabaseClient(
        supabaseURL: URL(string: "https://wngtvdgzzlkajtbwsurc.supabase.co")!,
        supabaseKey: "sb_publishable_oR41TcNHu-G9La0JHrnmWg_P8SfRts5"
    )

    /// Sign in with Apple の id_token + nonce で Supabase にサインインし、
    /// 取得したセッションを REST クライアントへ橋渡しする。
    static func signInWithApple(idToken: String, nonce: String) async throws {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        await SupabaseClient.shared.adoptSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            userId: session.user.id.uuidString.lowercased(),
            email: session.user.email,
            isAnonymous: session.user.isAnonymous
        )
    }
}
