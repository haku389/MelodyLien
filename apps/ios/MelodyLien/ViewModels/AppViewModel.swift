import SwiftUI
import Combine

// MARK: - Navigation

enum Screen {
    case home
    case exchange
    case mystery(trackId: String)
    case puzzle(trackId: String)
    case artist(artistId: String)
    case playlist
}

// MARK: - AppViewModel

@MainActor
final class AppViewModel: ObservableObject {

    // MARK: Published

    @Published var user: User?
    @Published var tracks: [String: Track] = [:]       // trackId → Track
    @Published var collection: CollectionSummary?
    @Published var mission: Mission?
    @Published var todayEncounter: Encounter?
    @Published var dailyPlaylist: DailyPlaylist?

    @Published var activeTab: Tab = .home
    @Published var navigationStack: [Screen] = []

    @Published var selectedCandidateIndex: Int? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var toast: String? = nil

    // MARK: Dependencies

    let bleManager: BLEManager
    private let repository: MelodyRepository

    // MARK: Init

    init(repository: MelodyRepository = .shared) {
        self.repository = repository
        self.bleManager = BLEManager(repository: repository)
    }

    // MARK: - Load

    func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadUser() }
            group.addTask { await self.loadTracks() }
            group.addTask { await self.loadCollection() }
            group.addTask { await self.loadMission() }
            group.addTask { await self.loadEncounter() }
            group.addTask { await self.loadPlaylist() }
        }
    }

    private func loadUser() async {
        do { user = try await repository.fetchMe() }
        catch { handle(error) }
    }

    private func loadTracks() async {
        do {
            let list = try await repository.fetchTracks()
            tracks = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
        } catch { handle(error) }
    }

    private func loadCollection() async {
        do { collection = try await repository.fetchCollection() }
        catch { handle(error) }
    }

    private func loadMission() async {
        do { mission = try await repository.fetchMission() }
        catch { handle(error) }
    }

    private func loadEncounter() async {
        do { todayEncounter = try await repository.fetchTodayEncounter() }
        catch { handle(error) }
    }

    private func loadPlaylist() async {
        do { dailyPlaylist = try await repository.fetchDailyPlaylist() }
        catch { handle(error) }
    }

    // MARK: - Actions

    func selectCandidate(_ index: Int) {
        selectedCandidateIndex = index
    }

    func confirmPiece() async {
        guard let encounter = todayEncounter,
              let index = selectedCandidateIndex else { return }

        do {
            let result = try await repository.selectPiece(encounter: encounter, candidateIndex: index)
            // ローカルのtrack状態を更新
            if var track = tracks[result.trackId] {
                if result.added && !track.ownedPieces.contains(result.pieceNumber) {
                    track.ownedPieces.append(result.pieceNumber)
                    track.ownedPieces.sort()
                    tracks[result.trackId] = track
                }
            }
            selectedCandidateIndex = nil
            showToast(result.added ? "ピースを獲得しました！" : "所持済みのピースです")
            // 画面遷移
            if result.nextScreen == "puzzle" {
                navigationStack.append(.puzzle(trackId: result.trackId))
            } else {
                navigationStack.append(.mystery(trackId: result.trackId))
            }
        } catch { handle(error) }
    }

    func applyHint(trackId: String, kind: HintKind) async {
        do {
            let result = try await repository.applyHint(trackId: trackId, kind: kind)
            if var track = tracks[trackId] {
                track.hintLevel    = result.hintLevel
                track.answerReady  = result.answerReady
                tracks[trackId]    = track
            }
            showToast(kind == .answer ? "YouTubeリンクを表示しました" : "ヒントを解放しました")
        } catch { handle(error) }
    }

    func unlockTrack(trackId: String) async {
        do {
            try await repository.unlockTrack(trackId: trackId)
            if var track = tracks[trackId] {
                track.isUnlocked = true
                tracks[trackId]  = track
            }
            showToast("曲が解放されました！")
            navigationStack.removeLast()
            navigationStack.append(.puzzle(trackId: trackId))
        } catch { handle(error) }
    }

    func addListenLater(trackId: String) async {
        do {
            try await repository.addListenLater(trackId: trackId)
            showToast("あとで聴くに追加しました")
        } catch { handle(error) }
    }

    func navigate(to screen: Screen) {
        navigationStack.append(screen)
    }

    func goBack() {
        navigationStack.removeLast()
    }

    // MARK: - Computed

    var heroTrack: Track? {
        guard let playlist = dailyPlaylist,
              let item = playlist.tracks.first else { return nil }
        return tracks[item.trackId]
    }

    func track(for id: String) -> Track? { tracks[id] }

    // MARK: - Helpers

    private func showToast(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            toast = nil
        }
    }

    private func handle(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}

// MARK: - Tab

enum Tab: String, CaseIterable {
    case home      = "ホーム"
    case exchange  = "届いた"
    case puzzle    = "パズル"
    case artist    = "アーティスト"
    case playlist  = "プレイリスト"

    var icon: String {
        switch self {
        case .home:     return "house.fill"
        case .exchange: return "arrow.left.arrow.right.circle.fill"
        case .puzzle:   return "puzzlepiece.fill"
        case .artist:   return "star.fill"
        case .playlist: return "music.note.list"
        }
    }
}
