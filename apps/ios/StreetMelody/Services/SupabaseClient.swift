import Foundation

// MARK: - SupabaseClient
//
// 方式A（クライアント直結）の基盤。
// Supabase Auth（GoTrue）で匿名サインインして JWT を得て、以後 per-user データを
// Supabase（PostgREST）に直接読み書きするための最小クライアント（REST・URLSession ベース）。
//
// 前提: Supabase ダッシュボードで「Anonymous sign-ins」を有効にしておくこと。
//       無効のままだと signInAnonymously は失敗し、セッションは nil（アプリは seed のまま動作）。

actor SupabaseClient {
    static let shared = SupabaseClient()

    // 公開（publishable / anon）キー。秘密ではない。
    nonisolated let baseURL = "https://wngtvdgzzlkajtbwsurc.supabase.co"
    nonisolated let anonKey = "sb_publishable_oR41TcNHu-G9La0JHrnmWg_P8SfRts5"

    private let session: URLSession
    private let sessionKey = "streetmelody.supabase.session.v1"

    private(set) var userId: String?
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
    private struct AuthUser: Codable { let id: String }
    private struct SavedSession: Codable { let refreshToken: String; let userId: String }

    var isSignedIn: Bool { userId != nil && accessToken != nil }

    // MARK: Bootstrap

    /// 起動時に呼ぶ。保存済みセッションがあれば更新トークンで復帰、無ければ匿名サインイン。
    /// 失敗（匿名無効・通信不可など）しても投げない（seed 運用を妨げない）。
    func bootstrap() async {
        if let saved = loadSaved() {
            if (try? await refresh(saved.refreshToken)) != nil { return }
        }
        try? await signInAnonymously()
    }

    @discardableResult
    func signInAnonymously() async throws -> String {
        let data = try await authRequest(path: "/auth/v1/signup", body: Data("{}".utf8))
        return try apply(data)
    }

    private func refresh(_ token: String) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: ["refresh_token": token])
        let data = try await authRequest(path: "/auth/v1/token?grant_type=refresh_token", body: body)
        return try apply(data)
    }

    private func apply(_ data: Data) throws -> String {
        let s = try JSONDecoder().decode(AuthSession.self, from: data)
        accessToken = s.access_token
        refreshToken = s.refresh_token
        userId = s.user.id
        save(SavedSession(refreshToken: s.refresh_token, userId: s.user.id))
        return s.user.id
    }

    private func authRequest(path: String, body: Data) async throws -> Data {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = body
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.httpError(http.statusCode)
        }
        return data
    }

    // MARK: PostgREST helper（Phase 2 の per-user 読み書き用）

    /// 認証済みトークンで PostgREST にリクエストする。`query` 例: "collected_pieces?select=*"。
    /// 未サインイン時は nil を返す（RLS で弾かれるため呼ばない）。
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

    // MARK: per-user 進行（方式A Phase 2）

    struct UserProgress: Sendable {
        var pieces: [String: [Int]] = [:]   // trackId -> 所持ピース番号
        var unlocked: Set<String> = []      // 解放済み trackId
    }
    private struct PieceRow: Decodable { let track_id: String; let piece_number: Int }
    private struct TrackIdRow: Decodable { let track_id: String }

    /// 自分の進行（所持ピース・解放曲）を Supabase から取得。未サインイン時は空。
    func fetchProgress() async -> UserProgress {
        var p = UserProgress()
        if let data = (try? await rest(method: "GET", query: "collected_pieces?select=track_id,piece_number")) ?? nil,
           let rows = try? JSONDecoder().decode([PieceRow].self, from: data) {
            for r in rows { p.pieces[r.track_id, default: []].append(r.piece_number) }
        }
        if let data = (try? await rest(method: "GET", query: "unlocked_tracks?select=track_id")) ?? nil,
           let rows = try? JSONDecoder().decode([TrackIdRow].self, from: data) {
            for r in rows { p.unlocked.insert(r.track_id) }
        }
        return p
    }

    /// 所持ピースを1件保存（冪等。RLS で本人分のみ許可）。
    func upsertPiece(trackId: String, piece: Int) async {
        guard let uid = userId else { return }
        let body = try? JSONSerialization.data(withJSONObject: [["user_id": uid, "track_id": trackId, "piece_number": piece]])
        _ = try? await rest(method: "POST",
                            query: "collected_pieces?on_conflict=user_id,track_id,piece_number",
                            body: body, prefer: "resolution=ignore-duplicates,return=minimal")
    }

    /// 曲の解放を保存（冪等）。
    func upsertUnlock(trackId: String) async {
        guard let uid = userId else { return }
        let body = try? JSONSerialization.data(withJSONObject: [["user_id": uid, "track_id": trackId]])
        _ = try? await rest(method: "POST",
                            query: "unlocked_tracks?on_conflict=user_id,track_id",
                            body: body, prefer: "resolution=ignore-duplicates,return=minimal")
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
