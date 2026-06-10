import Foundation

// MARK: - User

struct User: Codable, Identifiable {
    let id: String
    var name: String
    var level: Int
    var exp: Int
    var coins: Int
}

// MARK: - Artist

struct Artist: Codable, Identifiable {
    let id: String
    let name: String
}

// MARK: - Track

struct Track: Codable, Identifiable {
    let id: String
    let artistId: String
    let pieceCount: Int
    let rewardCoins: Int
    let rewardExp: Int
    let color: String
    let tone: String?

    // ユーザー状態（APIから返る）
    var title: String?          // 未解放は nil
    var artistName: String?     // 未解放は nil
    var isUnlocked: Bool
    var hintLevel: Int          // 0 / 1 / 2
    var answerReady: Bool
    var maskedLabel: String?    // hintLevel に応じた伏せ字
    var choices: [String]       // hintLevel >= 2 で公開
    var ownedPieces: [Int]

    var displayTitle: String {
        title ?? maskedLabel ?? "未解放メロディ"
    }

    var displayArtist: String {
        artistName ?? "???"
    }

    var isComplete: Bool {
        ownedPieces.count >= pieceCount
    }
}

// MARK: - Encounter

struct Encounter: Codable, Identifiable {
    let id: String
    let locationLabel: String
    let rewardCoins: Int
    let expiresAt: Date
    let candidates: [Candidate]
}

struct Candidate: Codable, Identifiable {
    let id: String
    let trackId: String
    let pieceNumber: Int
    let sourceSlot: String
    let rarity: Int
    let sortOrder: Int
}

// MARK: - Playlist

struct DailyPlaylist: Codable, Identifiable {
    let id: String
    let date: String
    let title: String
    let tracks: [PlaylistItem]
}

struct PlaylistItem: Codable {
    let trackId: String
    let artistId: String
    let color: String
}

// MARK: - Mission

struct Mission: Codable {
    let userId: String
    let date: String
    let label: String
    var current: Int
    let target: Int

    var progress: Double {
        guard target > 0 else { return 0 }
        return Double(current) / Double(target)
    }
}

// MARK: - Collection Summary

struct CollectionSummary: Codable {
    let completedPuzzles: Int
    let totalPuzzles: Int
    let completedArtists: Int
    let totalArtists: Int
    let playlists: Int
}

// MARK: - BLE

/// 近くで検出したユーザーの識別情報
struct NearbyUser: Identifiable {
    let id: String          // UUID (BLE Peripheral ID)
    let userId: String      // サーバー側ユーザーID
    let rssi: Int           // 信号強度
    let detectedAt: Date
}
