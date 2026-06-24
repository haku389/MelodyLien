import Foundation
import CryptoKit

// MARK: - SupabaseClient
//
// 方式A（クライアント直結）の基盤。
// Supabase Auth（GoTrue）でサインインして JWT を得て、以後 per-user データを
// Supabase（PostgREST）に直接読み書きするための最小クライアント（REST・URLSession ベース）。
//
// - 匿名サインイン: 端末＝1ユーザー（要ダッシュボードで Anonymous sign-ins ON）。
// - アカウント連携: 匿名ユーザーにメール＋パスワードを設定して永続化（再インストール跨ぎの復元）。
// 失敗（匿名無効・通信不可など）してもアプリは seed のまま動作する。

actor SupabaseClient {
    static let shared = SupabaseClient()

    // 公開（publishable / anon）キー。秘密ではない。
    nonisolated let baseURL = "https://wngtvdgzzlkajtbwsurc.supabase.co"
    nonisolated let anonKey = "sb_publishable_oR41TcNHu-G9La0JHrnmWg_P8SfRts5"

    private let session: URLSession
    private let sessionKey = "streetmelody.supabase.session.v1"

    private(set) var userId: String?
    private(set) var email: String?
    private(set) var isAnonymous: Bool = true
    private var accessToken: String?
    private var refreshToken: String?

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 8     // 1リクエストの上限（体感速度優先）
        cfg.timeoutIntervalForResource = 15   // 全体上限（暴走待ち防止）
        cfg.waitsForConnectivity = false      // 不通時は即失敗（UIを待たせない）
        session = URLSession(configuration: cfg)
    }

    /// シミュレータ等で間欠的に出る HTTP/3(QUIC) の -1005「接続喪失」を吸収するため、
    /// 接続喪失時のみ短く2回だけリトライする（待ち時間を抑える）。
    private func dataWithRetry(_ req: URLRequest, attempts: Int = 3) async throws -> (Data, URLResponse) {
        var r = req
        r.assumesHTTP3Capable = false   // QUIC(HTTP/3)を前提にしない＝シミュレータの-1005を緩和
        var lastError: Error = URLError(.unknown)
        for _ in 0..<attempts {
            do { return try await session.data(for: r) }
            catch let e as URLError where e.code == .networkConnectionLost {
                lastError = e
                try? await Task.sleep(nanoseconds: 150_000_000)   // 0.15s 固定
            }
        }
        throw lastError
    }

    // MARK: Session model

    private struct AuthSession: Codable {
        let access_token: String
        let refresh_token: String
        let user: AuthUser
    }
    private struct AuthUser: Codable {
        let id: String
        let email: String?
        let is_anonymous: Bool?
    }
    private struct SavedSession: Codable { let refreshToken: String; let userId: String }

    var isSignedIn: Bool { userId != nil && accessToken != nil }

    enum AuthError: Error { case notSignedIn, http(Int) }

    // MARK: Bootstrap / sign-in

    /// 起動時に呼ぶ。保存済みセッションがあれば更新トークンで復帰、無ければ匿名サインイン。
    func bootstrap() async {
        if let saved = loadSaved() {
            if (try? await refresh(saved.refreshToken)) != nil { return }
        }
        try? await signInAnonymously()
    }

    @discardableResult
    func signInAnonymously() async throws -> String {
        let data = try await authRequest(method: "POST", path: "/auth/v1/signup", body: Data("{}".utf8))
        return try apply(data)
    }

    /// メール＋パスワードでサインイン（別端末・再インストール後の復元に使う）。
    @discardableResult
    func signInWithEmail(_ email: String, _ password: String) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        let data = try await authRequest(method: "POST", path: "/auth/v1/token?grant_type=password", body: body)
        return try apply(data)
    }

    /// 現在の（匿名）ユーザーにメール＋パスワードを設定して永続アカウント化。
    /// 戻り値: メールが即時有効になったか（true=「Confirm email」OFF等で即連携、false=確認メール送信・確認待ち）。
    @discardableResult
    func upgradeToEmail(_ email: String, _ password: String) async throws -> Bool {
        guard let token = accessToken else { throw AuthError.notSignedIn }
        let body = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        let data = try await authRequest(method: "PUT", path: "/auth/v1/user", body: body, bearer: token)
        if let u = try? JSONDecoder().decode(AuthUser.self, from: data) {
            let active = (u.email?.isEmpty == false)   // 確認待ちのときは email が空/未設定
            self.email = active ? u.email : nil
            self.isAnonymous = u.is_anonymous ?? self.isAnonymous
            return active
        }
        return false
    }

    func signOut() {
        accessToken = nil; refreshToken = nil; userId = nil; email = nil; isAnonymous = true
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }

    // MARK: OAuth（PKCE・REST 直叩き。SDK のネットワークを使わずシミュレータでも動く）

    private var pendingVerifier: String?
    private let oauthRedirect = "com.streetmelody.app://login-callback"

    /// プロバイダの認可URLを返す。link=true は今の（匿名）セッションに紐付け（昇格）、false は新規サインイン。
    func oauthAuthorizeURL(provider: String, link: Bool) async throws -> URL {
        let verifier = Self.pkceVerifier()
        pendingVerifier = verifier
        let challenge = Self.pkceChallenge(verifier)
        let items = [
            URLQueryItem(name: "provider", value: provider),
            URLQueryItem(name: "redirect_to", value: oauthRedirect),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "s256"),
        ]
        if !link {
            // 新規サインイン: /authorize を直接ブラウザで開く（302 連鎖でプロバイダ→コールバック）
            var comps = URLComponents(string: baseURL + "/auth/v1/authorize")!
            comps.queryItems = items
            guard let u = comps.url else { throw AuthError.notSignedIn }
            return u
        }
        // 昇格: 認可URL取得には Bearer が要る（ブラウザはヘッダ送れない）→ アプリ側で取得して URL を得る
        let linkItems = items + [URLQueryItem(name: "skip_http_redirect", value: "true")]
        // 有効なセッションが無ければ匿名サインイン
        if accessToken == nil { try? await signInAnonymously() }
        guard let token = accessToken else { throw OAuthError.message("サインインできませんでした（通信をご確認ください）") }

        var (status, data) = try await linkAuthorizeFetch(items: linkItems, token: token)
        // 古い/無効なセッション(401/403)なら匿名サインインし直して1回だけ再試行（自己回復）
        if status == 401 || status == 403 {
            try? await signInAnonymously()
            if let t2 = accessToken { (status, data) = try await linkAuthorizeFetch(items: linkItems, token: t2) }
        }
        guard (200..<300).contains(status) else {
            throw OAuthError.message("認可URL取得失敗(HTTP \(status)): \(String(data: data, encoding: .utf8)?.prefix(140) ?? "")")
        }
        struct LinkURL: Decodable { let url: String }
        guard let lu = try? JSONDecoder().decode(LinkURL.self, from: data), let u = URL(string: lu.url) else {
            throw OAuthError.message("認可URLの解析に失敗: \(String(data: data, encoding: .utf8)?.prefix(140) ?? "")")
        }
        return u
    }

    private func linkAuthorizeFetch(items: [URLQueryItem], token: String) async throws -> (Int, Data) {
        var comps = URLComponents(string: baseURL + "/auth/v1/user/identities/authorize")!
        comps.queryItems = items
        guard let url = comps.url else { throw OAuthError.message("URL不正") }
        var req = URLRequest(url: url)
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await dataWithRetry(req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        return (status, data)
    }

    enum OAuthError: LocalizedError {
        case message(String)
        var errorDescription: String? { if case let .message(m) = self { return m }; return nil }
    }

    /// コールバックURLの code を PKCE 交換してセッション確立。
    func oauthExchange(callback: URL) async throws {
        guard let verifier = pendingVerifier else { throw OAuthError.message("内部エラー: verifier 不在") }
        // code は query または fragment(#) のどちらにも来うる
        let comps = URLComponents(url: callback, resolvingAgainstBaseURL: false)
        var items = comps?.queryItems ?? []
        if let frag = comps?.fragment, let fc = URLComponents(string: "?" + frag)?.queryItems { items += fc }
        if let errDesc = items.first(where: { $0.name == "error_description" })?.value
            ?? items.first(where: { $0.name == "error" })?.value {
            throw OAuthError.message("プロバイダ側エラー: \(errDesc)")
        }
        // link はセッションを直接(#access_token=...)で返すことがある → その場合は直接確立
        if let at = items.first(where: { $0.name == "access_token" })?.value,
           let rt = items.first(where: { $0.name == "refresh_token" })?.value {
            try await applyTokens(access: at, refresh: rt)
            pendingVerifier = nil
            return
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw OAuthError.message("コールバックに code がありません: \(callback.absoluteString.prefix(80))")
        }
        // 直接 POST して、失敗時はサーバ本文を表示
        guard let url = URL(string: baseURL + "/auth/v1/token?grant_type=pkce") else { throw OAuthError.message("URL不正") }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["auth_code": code, "code_verifier": verifier])
        let (data, resp) = try await dataWithRetry(req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw OAuthError.message("交換失敗(HTTP \(http.statusCode)): \(body.prefix(160))")
        }
        _ = try apply(data)
        pendingVerifier = nil
    }

    /// Apple の id_token を REST で交換（link=true で昇格）。
    func signInWithAppleIDToken(_ idToken: String, nonce: String, link: Bool) async throws {
        var obj: [String: Any] = ["provider": "apple", "id_token": idToken, "nonce": nonce]
        if link { obj["link_identity"] = true }
        let body = try JSONSerialization.data(withJSONObject: obj)
        var bearer: String? = nil
        if link { bearer = accessToken }
        let data = try await authRequest(method: "POST", path: "/auth/v1/token?grant_type=id_token", body: body, bearer: bearer)
        _ = try apply(data)
    }

    /// access/refresh トークンから直接セッション確立（/auth/v1/user でユーザー取得）。
    private func applyTokens(access: String, refresh: String) async throws {
        accessToken = access
        refreshToken = refresh
        guard let url = URL(string: baseURL + "/auth/v1/user") else { throw OAuthError.message("URL不正") }
        var req = URLRequest(url: url)
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await dataWithRetry(req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw OAuthError.message("ユーザー取得失敗(HTTP \(http.statusCode)): \(String(data: data, encoding: .utf8)?.prefix(140) ?? "")")
        }
        guard let u = try? JSONDecoder().decode(AuthUser.self, from: data) else {
            throw OAuthError.message("ユーザー解析に失敗: \(String(data: data, encoding: .utf8)?.prefix(140) ?? "")")
        }
        userId = u.id
        email = (u.email?.isEmpty == false) ? u.email : nil
        isAnonymous = u.is_anonymous ?? false
        save(SavedSession(refreshToken: refresh, userId: u.id))
    }

    private static func pkceVerifier(_ n: Int = 64) -> String {
        let cs = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        var s = ""
        for _ in 0..<n { var b: UInt8 = 0; _ = SecRandomCopyBytes(kSecRandomDefault, 1, &b); s.append(cs[Int(b) % cs.count]) }
        return s
    }
    private static func pkceChallenge(_ verifier: String) -> String {
        let h = SHA256.hash(data: Data(verifier.utf8))
        return Data(h).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// 外部（Supabase SDK 等）で確立したセッションを取り込み、データ層を共有する。
    /// Apple など OAuth/OIDC サインイン後に呼ぶ。
    func adoptSession(accessToken: String, refreshToken: String, userId: String, email: String?, isAnonymous: Bool) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userId = userId
        self.email = (email?.isEmpty == false) ? email : nil
        self.isAnonymous = isAnonymous
        save(SavedSession(refreshToken: refreshToken, userId: userId))
    }

    private func refresh(_ token: String) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: ["refresh_token": token])
        let data = try await authRequest(method: "POST", path: "/auth/v1/token?grant_type=refresh_token", body: body)
        return try apply(data)
    }

    @discardableResult
    private func apply(_ data: Data) throws -> String {
        let s = try JSONDecoder().decode(AuthSession.self, from: data)
        accessToken = s.access_token
        refreshToken = s.refresh_token
        userId = s.user.id
        email = s.user.email?.isEmpty == true ? nil : s.user.email
        isAnonymous = s.user.is_anonymous ?? false
        save(SavedSession(refreshToken: s.refresh_token, userId: s.user.id))
        return s.user.id
    }

    private func authRequest(method: String, path: String, body: Data, bearer: String? = nil) async throws -> Data {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        if let bearer { req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        req.httpBody = body
        let (data, resp) = try await dataWithRetry(req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw AuthError.http(http.statusCode)
        }
        return data
    }

    // MARK: PostgREST helper（per-user 読み書き）

    /// 認証済みトークンで PostgREST にリクエスト。未サインイン時は nil。
    func rest(method: String, query: String, body: Data? = nil, prefer: String? = nil) async throws -> Data? {
        guard let token = accessToken else { return nil }
        guard let url = URL(string: baseURL + "/rest/v1/" + query) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
        req.httpBody = body
        let (data, resp) = try await dataWithRetry(req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.httpError(http.statusCode)
        }
        return data
    }

    // MARK: per-user 状態（方式A）

    struct RemoteFriend: Sendable { let name: String; let location: String; let exchangeCount: Int }
    struct UserState: Sendable {
        var pieces: [String: [Int]] = [:]
        var unlocked: Set<String> = []
        var hints: [String: (level: Int, answerReady: Bool)] = [:]
        var coins: Int? = nil
        var friends: [RemoteFriend] = []
    }
    private struct PieceRow: Decodable { let track_id: String; let piece_number: Int }
    private struct TrackIdRow: Decodable { let track_id: String }
    private struct HintRow: Decodable { let track_id: String; let level: Int; let answer_ready: Bool }
    private struct CoinRow: Decodable { let coins: Int }
    private struct FriendRow: Decodable { let friend_name: String; let location_label: String?; let exchange_count: Int }

    /// 自分の進行・状態をまとめて取得。未サインイン時は空。
    func fetchUserState() async -> UserState {
        var s = UserState()
        if let d = (try? await rest(method: "GET", query: "collected_pieces?select=track_id,piece_number")) ?? nil,
           let rows = try? JSONDecoder().decode([PieceRow].self, from: d) {
            for r in rows { s.pieces[r.track_id, default: []].append(r.piece_number) }
        }
        if let d = (try? await rest(method: "GET", query: "unlocked_tracks?select=track_id")) ?? nil,
           let rows = try? JSONDecoder().decode([TrackIdRow].self, from: d) {
            for r in rows { s.unlocked.insert(r.track_id) }
        }
        if let d = (try? await rest(method: "GET", query: "hint_levels?select=track_id,level,answer_ready")) ?? nil,
           let rows = try? JSONDecoder().decode([HintRow].self, from: d) {
            for r in rows { s.hints[r.track_id] = (r.level, r.answer_ready) }
        }
        if let d = (try? await rest(method: "GET", query: "profiles?select=coins")) ?? nil,
           let rows = try? JSONDecoder().decode([CoinRow].self, from: d), let c = rows.first?.coins {
            s.coins = c
        }
        if let d = (try? await rest(method: "GET", query: "friendships?select=friend_name,location_label,exchange_count")) ?? nil,
           let rows = try? JSONDecoder().decode([FriendRow].self, from: d) {
            s.friends = rows.map { RemoteFriend(name: $0.friend_name, location: $0.location_label ?? "", exchangeCount: $0.exchange_count) }
        }
        return s
    }

    func upsertPiece(trackId: String, piece: Int) async {
        guard let uid = userId else { return }
        let body = try? JSONSerialization.data(withJSONObject: [["user_id": uid, "track_id": trackId, "piece_number": piece]])
        _ = try? await rest(method: "POST", query: "collected_pieces?on_conflict=user_id,track_id,piece_number",
                            body: body, prefer: "resolution=ignore-duplicates,return=minimal")
    }

    func upsertUnlock(trackId: String) async {
        guard let uid = userId else { return }
        let body = try? JSONSerialization.data(withJSONObject: [["user_id": uid, "track_id": trackId]])
        _ = try? await rest(method: "POST", query: "unlocked_tracks?on_conflict=user_id,track_id",
                            body: body, prefer: "resolution=ignore-duplicates,return=minimal")
    }

    func upsertHint(trackId: String, level: Int, answerReady: Bool) async {
        guard let uid = userId else { return }
        let row: [String: Any] = ["user_id": uid, "track_id": trackId, "level": level, "answer_ready": answerReady]
        let body = try? JSONSerialization.data(withJSONObject: [row])
        _ = try? await rest(method: "POST", query: "hint_levels?on_conflict=user_id,track_id",
                            body: body, prefer: "resolution=merge-duplicates,return=minimal")
    }

    /// 自分の profiles.coins を更新（profiles 行は signup トリガーで自動生成済み）。
    func updateCoins(_ coins: Int) async {
        guard let uid = userId else { return }
        let body = try? JSONSerialization.data(withJSONObject: ["coins": coins])
        _ = try? await rest(method: "PATCH", query: "profiles?user_id=eq.\(uid)",
                            body: body, prefer: "return=minimal")
    }

    func upsertFriend(name: String, location: String, exchangeCount: Int) async {
        guard let uid = userId else { return }
        let row: [String: Any] = ["user_id": uid, "friend_name": name, "location_label": location, "exchange_count": exchangeCount]
        let body = try? JSONSerialization.data(withJSONObject: [row])
        _ = try? await rest(method: "POST", query: "friendships?on_conflict=user_id,friend_name",
                            body: body, prefer: "resolution=merge-duplicates,return=minimal")
    }

    // MARK: Persistence

    private func save(_ s: SavedSession) {
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: sessionKey) }
    }
    private func loadSaved() -> SavedSession? {
        guard let d = UserDefaults.standard.data(forKey: sessionKey) else { return nil }
        return try? JSONDecoder().decode(SavedSession.self, from: d)
    }
}
