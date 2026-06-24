import Foundation
import Supabase
import AuthenticationServices
import UIKit

// MARK: - Web 認証の表示アンカー（ASWebAuthenticationSession 用）

final class WebAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthPresenter()
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.keyWindow ?? ASPresentationAnchor()
    }
}

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
        await bridge(session)
    }

    /// リダイレクト URL（Supabase ダッシュボードの Redirect URLs と一致させる）。
    static let redirectURL = URL(string: "com.streetmelody.app://login-callback")!

    static func signInWithGoogle() async throws { try await signInWithOAuth(.google) }
    static func signInWithSpotify() async throws { try await signInWithOAuth(.spotify) }

    /// OAuth（Web リダイレクト）でサインインし、セッションを REST 層へ橋渡し。
    private static func signInWithOAuth(_ provider: Provider) async throws {
        let session = try await client.auth.signInWithOAuth(
            provider: provider,
            redirectTo: redirectURL
        ) { webAuth in
            webAuth.presentationContextProvider = WebAuthPresenter.shared
            webAuth.prefersEphemeralWebBrowserSession = false
        }
        await bridge(session)
    }

    private static func bridge(_ session: Session) async {
        await SupabaseClient.shared.adoptSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            userId: session.user.id.uuidString.lowercased(),
            email: session.user.email,
            isAnonymous: session.user.isAnonymous
        )
    }
}
