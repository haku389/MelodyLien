import Foundation

// MARK: - MelodyRepository
/// APIService のラッパー。ビジネスロジックとキャッシュを担う

final class MelodyRepository {

    static let shared = MelodyRepository()

    private let api = APIService.shared

    // MARK: - User / Collection

    func fetchMe()           async throws -> User              { try await api.fetchMe() }
    func fetchCollection()   async throws -> CollectionSummary { try await api.fetchCollection() }
    func fetchMission()      async throws -> Mission           { try await api.fetchMission() }

    // MARK: - Tracks

    func fetchTracks()       async throws -> [Track]           { try await api.fetchTracks() }

    // MARK: - Encounter

    func fetchTodayEncounter() async throws -> Encounter       { try await api.fetchTodayEncounter() }

    func selectPiece(encounter: Encounter, candidateIndex: Int) async throws -> SelectPieceResponse {
        try await api.selectPiece(encounterId: encounter.id, candidateIndex: candidateIndex)
    }

    // MARK: - Hint

    func applyHint(trackId: String, kind: HintKind) async throws -> HintResponse {
        try await api.applyHint(trackId: trackId, kind: kind)
    }

    func unlockTrack(trackId: String) async throws {
        _ = try await api.unlockTrack(id: trackId)
    }

    // MARK: - Playlist

    func fetchDailyPlaylist() async throws -> DailyPlaylist    { try await api.fetchDailyPlaylist() }

    func addListenLater(trackId: String) async throws {
        _ = try await api.addListenLater(trackId: trackId)
    }

    // MARK: - BLE: Encounterを生成（サーバー経由）

    func createEncounter(with peerUserId: String) async throws -> String {
        // TODO: POST /encounters  with peerUserId
        // 現在は今日のEncounterを返す（開発用）
        let enc = try await fetchTodayEncounter()
        return enc.id
    }
}
