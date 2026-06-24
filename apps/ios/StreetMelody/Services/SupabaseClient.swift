import Foundation

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
        cfg.timeoutIntervalForRequest = 15
        session = URLSession(configuration: cfg)
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
        let (data, resp) = try await session.data(for: req)
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
        let (data, resp) = try await session.data(for: req)
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
