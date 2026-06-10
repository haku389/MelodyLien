import Foundation

// MARK: - API Error

enum APIError: Error {
    case invalidURL
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)
}

// MARK: - APIService

final class APIService {

    static let shared = APIService()

    #if DEBUG
    private let baseURL = "http://localhost:3001/api"
    #else
    private let baseURL = "https://api.melodylien.app/api"
    #endif

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy  = .convertFromSnakeCase
    }

    // MARK: - Generic request

    func get<T: Decodable>(_ path: String) async throws -> T {
        let data = try await request(method: "GET", path: path, body: nil)
        return try decode(data)
    }

    func post<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        let bodyData = try JSONEncoder().encode(body)
        let data = try await request(method: "POST", path: path, body: bodyData)
        return try decode(data)
    }

    private func request(method: String, path: String, body: Data?) async throws -> Data {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.httpError(http.statusCode)
        }
        return data
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}

// MARK: - Endpoints

extension APIService {

    // User
    func fetchMe()                        async throws -> User               { try await get("/me") }
    func fetchCollection()                async throws -> CollectionSummary  { try await get("/me/collection") }
    func fetchMission()                   async throws -> Mission            { try await get("/me/mission") }

    // Tracks
    func fetchTracks()                    async throws -> [Track]            { try await get("/tracks") }
    func fetchTrack(id: String)           async throws -> Track              { try await get("/tracks/\(id)") }
    func unlockTrack(id: String)          async throws -> EmptyResponse      { try await post("/tracks/\(id)/unlock", body: EmptyBody()) }
    func collectPiece(trackId: String, pieceNumber: Int) async throws -> PieceResponse {
        try await post("/tracks/\(trackId)/pieces", body: PieceBody(pieceNumber: pieceNumber))
    }
    func applyHint(trackId: String, kind: HintKind) async throws -> HintResponse {
        try await post("/tracks/\(trackId)/hint", body: HintBody(kind: kind.rawValue))
    }
    func addListenLater(trackId: String)  async throws -> EmptyResponse      { try await post("/tracks/\(trackId)/listen-later", body: EmptyBody()) }

    // Encounter
    func fetchTodayEncounter()            async throws -> Encounter          { try await get("/encounters/today") }
    func selectPiece(encounterId: String, candidateIndex: Int) async throws -> SelectPieceResponse {
        try await post("/encounters/\(encounterId)/select", body: SelectBody(candidateIndex: candidateIndex))
    }

    // Playlist
    func fetchDailyPlaylist()             async throws -> DailyPlaylist      { try await get("/playlist/daily") }
}

// MARK: - Request/Response types

struct EmptyBody: Encodable {}
struct EmptyResponse: Decodable {}

struct PieceBody: Encodable   { let pieceNumber: Int }
struct PieceResponse: Decodable { let added: Bool }

enum HintKind: String { case hint1, hint2, answer }
struct HintBody: Encodable    { let kind: String }
struct HintResponse: Decodable { let hintLevel: Int; let answerReady: Bool }

struct SelectBody: Encodable  { let candidateIndex: Int }
struct SelectPieceResponse: Decodable {
    let trackId: String
    let pieceNumber: Int
    let added: Bool
    let nextScreen: String
}
