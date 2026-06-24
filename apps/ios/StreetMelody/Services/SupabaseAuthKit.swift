import Foundation
import AuthenticationServices
import UIKit

// MARK: - Web 認証の表示アンカー

final class WebAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthPresenter()
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.keyWindow ?? ASPresentationAnchor()
    }
}

// MARK: - SupabaseAuthKit
//
// OAuth（Google/Spotify）と Apple のサインイン/昇格を担う。
// 認証は REST 直叩き（`SupabaseClient`）＋ `ASWebAuthenticationSession`（PKCE）で行い、
// Supabase Swift SDK のネットワークは使わない。
// 理由: SDK の URLSession 経路はシミュレータ/一部環境で HTTP/3(QUIC) の -1005 を出すため、
// 実証済みの REST 経路に統一する（本番でも確実）。
// link=true は今の（匿名）セッションにプロバイダを紐付け＝進行データを保持したまま昇格。

enum SupabaseAuthKit {

    static func signInWithApple(idToken: String, nonce: String, link: Bool) async throws {
        try await SupabaseClient.shared.signInWithAppleIDToken(idToken, nonce: nonce, link: link)
    }

    static func signInWithGoogle(link: Bool) async throws { try await oauth("google", link: link) }
    static func signInWithSpotify(link: Bool) async throws { try await oauth("spotify", link: link) }

    @MainActor
    private static func oauth(_ provider: String, link: Bool) async throws {
        let url = try await SupabaseClient.shared.oauthAuthorizeURL(provider: provider, link: link)
        let callback = try await presentWebAuth(url)
        try await SupabaseClient.shared.oauthExchange(callback: callback)
    }

    @MainActor
    private static func presentWebAuth(_ url: URL) async throws -> URL {
        let presenter = WebAuthPresenter.shared
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
            var authSession: ASWebAuthenticationSession?
            authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: "com.streetmelody.app") { callback, error in
                if let callback { cont.resume(returning: callback) }
                else { cont.resume(throwing: error ?? CancellationError()) }
                _ = authSession
            }
            authSession?.presentationContextProvider = presenter
            // true: iOS の「"..." を使用しようとしています」同意ダイアログを省略し、
            // タップ後すぐにプロバイダのログイン画面へ遷移する（Cookie 非共有のエフェメラル）。
            authSession?.prefersEphemeralWebBrowserSession = true
            authSession?.start()
        }
    }
}
