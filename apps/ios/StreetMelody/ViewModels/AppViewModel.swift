import SwiftUI
import Combine

// MARK: - Tab (Web と同一順)

enum Tab: String, CaseIterable {
    case home       = "ホーム"
    case melody     = "メロディ"
    case collection = "コレクション"
    case ranking    = "ランキング"
    case mypage     = "マイページ"

    var icon: String {
        switch self {
        case .home:       return "house.fill"
        case .melody:     return "music.note.circle.fill"
        case .collection: return "square.stack.3d.up.fill"
        case .ranking:    return "chart.bar.fill"
        case .mypage:     return "person.fill"
        }
    }
}

// MARK: - Navigation Screen

enum Screen: Hashable {
    case mystery(trackId: String)
    case puzzle(trackId: String)
    case pieceSelect(encounterId: String, candidateIndex: Int)
    case artistDetail(artistId: String)
    case friendDetail(userId: String)
    case playlist
    case friends
    case premium
    case shop
    case notifySettings
    case bgSettings
}

// MARK: - Sub-tab enums

enum CollectionTab: String, CaseIterable {
    case puzzles = "曲パズル"
    case artists = "アーティスト"
    case oshi    = "推し曲"
    case titles  = "称号"
}

enum RankingTab: String, CaseIterable {
    case today  = "今日"
    case near   = "近く"
    case friend = "友達"
    case all    = "全国"
}

// MARK: - AppViewModel

@MainActor
final class AppViewModel: ObservableObject {

    // MARK: Published - server data

    @Published var user: User?
    @Published var tracks: [String: Track] = [:]
    @Published var collection: CollectionSummary?
    @Published var mission: Mission?
    @Published var todayEncounter: Encounter?
    @Published var encounters: [Encounter] = []
    @Published var activeEncounterIndex: Int = 0
    @Published var dailyPlaylist: DailyPlaylist?

    // MARK: Published - navigation

    @Published var activeTab: Tab = .home
    @Published var navigationStack: [Screen] = []

    // MARK: Published - sub-tabs

    @Published var collectionTab: CollectionTab = .puzzles
    @Published var rankingTab: RankingTab = .today

    // MARK: Published - user state

    @Published var coins: Int = 240
    @Published var exp: Int = 0
    @Published var oshiTrackIds: [String] = []
    @Published var unlockedTrackIds: [String] = []
    @Published var friends: [Friend] = []
    @Published var premium: Bool = false
    @Published var linkedServices: [String: Bool] = [:]
    @Published var hintTickets: Int = 0
    @Published var ownedDecorations: [String] = []
    @Published var equippedDecoration: String? = nil

    // MARK: Published - notification settings

    @Published var notifyImmediate: Bool = true
    @Published var notifyDigest: Bool = false
    @Published var notifyDigestTime: String = "20:00"
    @Published var notifyEncounter: Bool = true
    @Published var notifyMission: Bool = true

    // MARK: Published - background scan settings

    @Published var bgScanEnabled: Bool = true
    @Published var bgScanMode: String = "balanced"
    @Published var bgNightPause: Bool = false

    // MARK: Published - melody / carousel

    @Published var carouselIndex: Int = 0
    @Published var carouselViewMode: String = "pieces"  // "pieces" | "mosaic"
    @Published var encounterCooldowns: [String: Date] = [:]

    // MARK: Published - puzzle complete / title celebration

    @Published var puzzleCompleteTrackId: String? = nil
    @Published var pendingTitleCelebrations: [String] = []

    // MARK: Published - UI state

    @Published var selectedCandidateIndex: Int? = nil
    @Published var isLoading = false
    @Published var toast: String? = nil

    // ピース取得直後の導線（フレンド申請カード／次の出会いへ）
    @Published var pendingFriendAdd: PendingFriend? = nil
    @Published var showNextEncounterPrompt: Bool = false

    // 試聴（少し聴く）: 30秒・1曲1日3回まで
    @Published var previewPlays: [String: PreviewRecord] = [:]
    @Published var previewTrackId: String? = nil

    // MARK: Published - account（方式A: アカウント連携）
    @Published var accountEmail: String? = nil
    @Published var isGuestAccount: Bool = true

    // MARK: Dependencies

    let bleManager: BLEManager
    private let repository: MelodyRepository

    // MARK: Init

    init(repository: MelodyRepository = .shared) {
        self.repository = repository
        self.bleManager = BLEManager(repository: repository)
        loadSeedData()
        // 進行に変化があれば自動保存（読込完了後のみ・1秒デバウンス）
        saveCancellable = objectWillChange
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] in
                guard let self else { return }
                MainActor.assumeIsolated { self.persistIfLoaded() }
            }
    }

    // MARK: - Persistence

    private static let saveKey = "streetmelody.save.v1"
    private var isLoaded = false
    private var saveCancellable: AnyCancellable?
    private var lastSyncedCoins: Int? = nil   // 方式A: コインの Supabase 同期の重複防止

    private func persistIfLoaded() {
        guard isLoaded else { return }
        var s = SaveState()
        s.trackProgress = tracks.mapValues {
            TrackProgress(ownedPieces: $0.ownedPieces, isUnlocked: $0.isUnlocked,
                          hintLevel: $0.hintLevel, answerReady: $0.answerReady,
                          title: $0.title, artistName: $0.artistName)
        }
        s.coins = coins; s.exp = exp
        s.oshiTrackIds = oshiTrackIds; s.unlockedTrackIds = unlockedTrackIds
        s.friends = friends; s.premium = premium
        s.linkedServices = linkedServices; s.hintTickets = hintTickets
        s.ownedDecorations = ownedDecorations; s.equippedDecoration = equippedDecoration
        s.notifyImmediate = notifyImmediate; s.notifyDigest = notifyDigest
        s.notifyDigestTime = notifyDigestTime; s.notifyEncounter = notifyEncounter
        s.notifyMission = notifyMission
        s.bgScanEnabled = bgScanEnabled; s.bgScanMode = bgScanMode; s.bgNightPause = bgNightPause
        s.encounterCooldowns = encounterCooldowns
        s.missionCurrent = mission?.current
        s.previewPlays = previewPlays
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        }
        // 方式A: コインが変わっていれば Supabase の profiles に反映（デバウンス済み）
        if coins != lastSyncedCoins {
            lastSyncedCoins = coins
            Task { await SupabaseClient.shared.updateCoins(coins) }
        }
    }

    /// seed/API ロード後に呼び、保存済みの進行を上書き反映する
    private func restoreState() {
        defer { isLoaded = true }
        guard let data = UserDefaults.standard.data(forKey: Self.saveKey),
              let s = try? JSONDecoder().decode(SaveState.self, from: data) else { return }

        for (id, p) in s.trackProgress {
            guard var t = tracks[id] else { continue }
            t.ownedPieces = p.ownedPieces
            t.isUnlocked = p.isUnlocked
            t.hintLevel = p.hintLevel
            t.answerReady = p.answerReady
            if p.isUnlocked { t.title = p.title; t.artistName = p.artistName }
            tracks[id] = t
        }
        coins = s.coins; exp = s.exp
        oshiTrackIds = s.oshiTrackIds; unlockedTrackIds = s.unlockedTrackIds
        friends = s.friends; premium = s.premium
        linkedServices = s.linkedServices; hintTickets = s.hintTickets
        ownedDecorations = s.ownedDecorations; equippedDecoration = s.equippedDecoration
        notifyImmediate = s.notifyImmediate; notifyDigest = s.notifyDigest
        notifyDigestTime = s.notifyDigestTime; notifyEncounter = s.notifyEncounter
        notifyMission = s.notifyMission
        bgScanEnabled = s.bgScanEnabled; bgScanMode = s.bgScanMode; bgNightPause = s.bgNightPause
        encounterCooldowns = s.encounterCooldowns
        previewPlays = s.previewPlays
        if let mc = s.missionCurrent, let m = mission {
            mission = Mission(userId: m.userId, date: m.date, label: m.label,
                              current: mc, target: m.target, rewardCoins: m.rewardCoins)
        }
    }

    // MARK: - Load (API fallback)

    func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        await withTaskGroup(of: Void.self) { group in
            // 方式A: 匿名サインインでセッション確立（per-user 読み書きの起点）。
            // 匿名無効・通信不可なら静かに失敗し seed 運用を続ける（非破壊）。
            group.addTask { await SupabaseClient.shared.bootstrap() }
            // カタログ（曲・サムネイルURL）のみライブAPIから取得し、seed に重ねる。
            // user / collection / mission / encounter / playlist はバックエンドの
            // per-user データ＋認証が未整備のため、当面 seed を使う（API稼働時の
            // ゲストデータでプロトタイプ体験が劣化するのを避ける）。整備後に有効化する。
            group.addTask { await self.loadTracks() }
            // group.addTask { await self.loadUser() }
            // group.addTask { await self.loadCollection() }
            // group.addTask { await self.loadMission() }
            // group.addTask { await self.loadEncounter() }
            // group.addTask { await self.loadPlaylist() }
        }
        // すべての seed/API ロード後に保存済み進行を反映
        restoreState()
        // 方式A: Supabase の自分の進行（所持ピース・解放）を seed/ローカルにマージ
        await mergeRemoteProgress()
        await refreshAccountState()
    }

    private func loadUser() async {
        if let u = try? await repository.fetchMe() { user = u }
    }

    private func loadTracks() async {
        // カタログ（DB/CDN）を取得し、seed トラックに「サムネイルURL」だけ重ねる。
        // 進行状態（所持ピース・解放・ヒント）や youtubeVideoId/chorusStart は seed/保存を優先し、
        // 画像の出所だけを DB/CDN に切り替える（API 不通時は seed/同梱画像のまま）。
        guard let list = try? await repository.fetchTracks() else { return }
        for apiTrack in list {
            guard let remote = apiTrack.thumbnailUrl, !remote.isEmpty else { continue }
            if var seedTrack = tracks[apiTrack.id] {
                seedTrack.thumbnailUrl = remote
                tracks[apiTrack.id] = seedTrack
            }
        }
    }

    private func loadCollection() async {
        if let c = try? await repository.fetchCollection() { collection = c }
    }

    private func loadMission() async {
        if let m = try? await repository.fetchMission() { mission = m }
    }

    private func loadEncounter() async {
        if let enc = try? await repository.fetchTodayEncounter() {
            todayEncounter = enc
            if !encounters.contains(where: { $0.id == enc.id }) {
                encounters.insert(enc, at: 0)
            }
        }
    }

    private func loadPlaylist() async {
        if let p = try? await repository.fetchDailyPlaylist() { dailyPlaylist = p }
    }

    /// 方式A: Supabase に保存された自分の状態を seed/ローカルにマージする。
    /// ピースは和集合、解放/ヒントはONを反映、コインは remote 採用（初回は seed を push）、フレンドは未所持を追加。
    /// 未サインイン時は空で no-op。
    private func mergeRemoteProgress() async {
        let state = await SupabaseClient.shared.fetchUserState()

        for (trackId, pieces) in state.pieces {
            guard var t = tracks[trackId] else { continue }
            t.ownedPieces = Array(Set(t.ownedPieces).union(pieces)).sorted()
            tracks[trackId] = t
        }
        for trackId in state.unlocked {
            guard var t = tracks[trackId] else { continue }
            t.isUnlocked = true
            if !unlockedTrackIds.contains(trackId) { unlockedTrackIds.append(trackId) }
            tracks[trackId] = t
        }
        for (trackId, h) in state.hints {
            guard var t = tracks[trackId] else { continue }
            t.hintLevel = max(t.hintLevel, h.level)
            if h.answerReady { t.answerReady = true }
            tracks[trackId] = t
        }
        // コイン: remote に実値(>0)があれば採用、無ければ（新規=既定0）seed を remote へ push
        if let rc = state.coins {
            if rc > 0 { coins = rc }
            else if coins > 0 { await SupabaseClient.shared.updateCoins(coins) }
        }
        lastSyncedCoins = coins
        // フレンド: remote にあって手元に無い名前を追加（場所・回数も反映）
        for rf in state.friends where !friends.contains(where: { $0.userName == rf.name }) {
            friends.append(Friend(userId: "remote_\(rf.name)", userName: rf.name,
                                  locationLabel: rf.location, exchangeCount: rf.exchangeCount, addedAt: Date()))
        }
    }

    // MARK: - Piece collection (local / offline)

    func collectPiece(encounterId: String, candidateIndex: Int, pieceNumber: Int) {
        guard let enc = encounters.first(where: { $0.id == encounterId }),
              enc.candidates.indices.contains(candidateIndex) else { return }
        let candidate = enc.candidates[candidateIndex]
        let trackId = candidate.trackId

        var wasNewPiece = false
        var puzzleJustCompleted = false
        if var track = tracks[trackId] {
            if !track.ownedPieces.contains(pieceNumber) {
                track.ownedPieces.append(pieceNumber)
                track.ownedPieces.sort()
                tracks[trackId] = track
                wasNewPiece = true

                // 方式A: 所持ピースを Supabase に保存（サインイン時のみ・非同期）
                Task { await SupabaseClient.shared.upsertPiece(trackId: trackId, piece: pieceNumber) }

                // Mission progress
                if let m = mission {
                    mission = Mission(userId: m.userId, date: m.date, label: m.label,
                                      current: m.current + 1, target: m.target, rewardCoins: m.rewardCoins)
                }

                // EXP per piece
                exp += 5

                // Check puzzle complete
                if track.isComplete {
                    puzzleJustCompleted = true
                    coins += track.rewardCoins
                    exp += track.rewardExp
                    puzzleCompleteTrackId = trackId
                    checkTitleUnlocks()
                }
            }
        }

        // Set cooldown
        encounterCooldowns[encounterId] = Date()

        // Navigate: pop piece select, then push mystery/puzzle
        goBack()
        if let track = tracks[trackId] {
            if track.isUnlocked {
                navigate(to: .puzzle(trackId: trackId))
            } else {
                navigate(to: .mystery(trackId: trackId))
            }
        }

        // ピース取得直後の導線をセット（navigate 後に設定し、goBack で消えないようにする）
        if wasNewPiece {
            if let i = friends.firstIndex(where: { $0.userId == enc.fromUserId }) {
                // 既存フレンドは交換回数を加算
                friends[i].exchangeCount += 1
                let f = friends[i]
                Task { await SupabaseClient.shared.upsertFriend(name: f.userName, location: f.locationLabel, exchangeCount: f.exchangeCount) }
                pendingFriendAdd = nil
            } else {
                pendingFriendAdd = PendingFriend(userId: enc.fromUserId,
                                                 userName: enc.fromUserName,
                                                 locationLabel: enc.locationLabel)
            }
            showNextEncounterPrompt = true
        }

        if wasNewPiece && !puzzleJustCompleted {
            showToast("ピースを獲得しました！")
        }
    }

    // MARK: - ピース取得後の導線

    func confirmFriendAdd() {
        guard let pf = pendingFriendAdd else { return }
        addFriend(userId: pf.userId, userName: pf.userName, locationLabel: pf.locationLabel)
        pendingFriendAdd = nil
        showToast("\(pf.userName)さんとフレンドになりました🎵")
    }

    func dismissFriendPrompt() { pendingFriendAdd = nil }

    /// クールタイム中でない次の出会いへ進む（無ければ完了状態）
    func goToNextEncounter() {
        clearCollectPrompts()
        if let idx = encounters.firstIndex(where: { cooldownRemaining(for: $0.id) == 0 }) {
            activeEncounterIndex = idx
            carouselIndex = 0
            selectedCandidateIndex = nil
        }
        activeTab = .melody
        navigationStack = []
    }

    /// 次に受信可能な出会い（クールタイム外）。全てクールタイム中なら nil
    var nextAvailableEncounter: Encounter? {
        encounters.first { cooldownRemaining(for: $0.id) == 0 }
    }

    func clearCollectPrompts() {
        pendingFriendAdd = nil
        showNextEncounterPrompt = false
    }

    // MARK: - 試聴（少し聴く）

    static let previewDailyLimit = 3

    private func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// 本日の残り試聴回数（日付が変われば 3 に戻る）
    func previewPlaysLeft(trackId: String) -> Int {
        guard let rec = previewPlays[trackId], rec.date == todayKey() else {
            return Self.previewDailyLimit
        }
        return max(0, Self.previewDailyLimit - rec.count)
    }

    /// 試聴できるか（実在の YouTube 動画があり、本日の回数が残っている）
    func canPreview(trackId: String) -> Bool {
        guard let t = tracks[trackId], t.hasYouTubeVideo else { return false }
        return previewPlaysLeft(trackId: trackId) > 0
    }

    /// 試聴を開始（回数を記録し、プレイヤーを表示）
    func startPreview(trackId: String) {
        guard let t = tracks[trackId], t.hasYouTubeVideo else {
            showToast("この曲はプロトタイプのため試聴できません")
            return
        }
        guard previewPlaysLeft(trackId: trackId) > 0 else {
            showToast("この曲の本日の試聴回数を使い切りました（1日3回まで）")
            return
        }
        let today = todayKey()
        if let rec = previewPlays[trackId], rec.date == today {
            previewPlays[trackId] = PreviewRecord(date: today, count: rec.count + 1)
        } else {
            previewPlays[trackId] = PreviewRecord(date: today, count: 1)
        }
        previewTrackId = trackId
    }

    func endPreview() { previewTrackId = nil }

    private func checkTitleUnlocks() {
        for title in self.titles {
            if isTitleUnlocked(title) {
                let id = title.id
                if !pendingTitleCelebrations.contains(id) {
                    pendingTitleCelebrations.append(id)
                    coins += title.rewardCoins
                    exp += title.rewardExp
                }
            }
        }
    }

    func dismissPuzzleComplete() {
        puzzleCompleteTrackId = nil
    }

    func dismissTitleCelebration() {
        if !pendingTitleCelebrations.isEmpty {
            pendingTitleCelebrations.removeFirst()
        }
    }

    // MARK: - Legacy action (still used by API path)

    func selectCandidate(_ index: Int) { selectedCandidateIndex = index }

    func confirmPiece() async {
        guard let encounter = activeEncounter,
              let index = selectedCandidateIndex else { return }
        do {
            let result = try await repository.selectPiece(encounter: encounter, candidateIndex: index)
            if var track = tracks[result.trackId] {
                if result.added && !track.ownedPieces.contains(result.pieceNumber) {
                    track.ownedPieces.append(result.pieceNumber)
                    track.ownedPieces.sort()
                    tracks[result.trackId] = track
                    if track.isComplete { puzzleCompleteTrackId = result.trackId }
                }
            }
            selectedCandidateIndex = nil
            showToast(result.added ? "ピースを獲得しました！" : "所持済みのピースです")
            navigate(to: result.nextScreen == "puzzle"
                     ? .puzzle(trackId: result.trackId)
                     : .mystery(trackId: result.trackId))
        } catch {
            showToast("通信エラーが発生しました")
        }
    }

    /// ヒント／答えの解放（CM視聴はモック）。
    /// 解放手段の優先度: プレミアム（広告なし）＞ ヒントチケット消費 ＞ 広告視聴（後日実装）。
    /// バックエンドに依存せず seed 上でローカル解放する。
    func applyHint(trackId: String, kind: HintKind) async {
        guard var track = tracks[trackId] else { return }

        var prefix = ""
        if premium {
            prefix = "⭐ プレミアム特典：広告なしで解放 — "
        } else if hintTickets > 0 {
            hintTickets -= 1
            prefix = "🎟️ ヒントチケットを使用（残り\(hintTickets)枚）— "
        }

        switch kind {
        case .hint1:
            track.hintLevel = max(track.hintLevel, 1)
            tracks[trackId] = track
            showToast(prefix + "1つ目のヒントを解放しました")
        case .hint2:
            track.hintLevel = max(track.hintLevel, 2)
            tracks[trackId] = track
            showToast(prefix + "2つ目のヒント（4択）を解放しました")
        case .answer:
            track.answerReady = true
            tracks[trackId] = track
            showToast(prefix + "YouTube確認で曲名を解放できます")
        }
        // 方式A: ヒント状態を Supabase に保存（バックグラウンド・UI を待たせない）
        let lvl = track.hintLevel, ready = track.answerReady
        Task { await SupabaseClient.shared.upsertHint(trackId: trackId, level: lvl, answerReady: ready) }
    }

    func unlockTrack(trackId: String) async {
        if var track = tracks[trackId] {
            track.isUnlocked = true
            if !unlockedTrackIds.contains(trackId) { unlockedTrackIds.append(trackId) }
            tracks[trackId] = track
        }
        // 同期はバックグラウンド（UI を待たせない）
        Task { await SupabaseClient.shared.upsertUnlock(trackId: trackId) }
        Task { try? await repository.unlockTrack(trackId: trackId) }
        showToast("曲が解放されました！")
        goBack()
        navigate(to: .puzzle(trackId: trackId))
    }

    func guessTrack(trackId: String, answer: String) -> Bool {
        guard let track = tracks[trackId], let title = track.title else { return false }
        let normalized = { (s: String) in s.lowercased().filter { $0.isLetter || $0.isNumber } }
        if normalized(answer) == normalized(title) {
            Task {
                await unlockTrack(trackId: trackId)
            }
            return true
        }
        showToast("まだ違うようです。ヒントや試聴を使ってもう一度試してください。")
        return false
    }

    func addListenLater(trackId: String) async {
        if let _ = try? await repository.addListenLater(trackId: trackId) {
            showToast("あとで聴くに追加しました")
        }
    }

    func toggleOshi(trackId: String) {
        if oshiTrackIds.contains(trackId) {
            oshiTrackIds.removeAll { $0 == trackId }
        } else {
            let limit = premium ? 5 : 3
            guard oshiTrackIds.count < limit else {
                showToast("上限に達しています")
                return
            }
            oshiTrackIds.append(trackId)
        }
    }

    func toggleService(_ serviceId: String) {
        linkedServices[serviceId] = !(linkedServices[serviceId] ?? false)
    }

    func buyPremium() {
        premium = true
        showToast("⭐ プレミアムに加入しました！")
    }

    func cancelPremium() {
        premium = false
        while oshiTrackIds.count > 3 { oshiTrackIds.removeLast() }
        showToast("プレミアムを解約しました")
    }

    func buyShopItem(id: String) {
        guard let item = shopItems.first(where: { $0.id == id }) else { return }
        guard coins >= item.price else { showToast("コインが不足しています"); return }
        coins -= item.price
        switch item.type {
        case "ticket":     hintTickets += 1
        case "decoration": if !ownedDecorations.contains(id) { ownedDecorations.append(id) }
        case "piece":
            let incomplete = tracks.values.filter { !$0.isComplete }
            if let t = incomplete.randomElement() {
                let missing = (1...t.pieceCount).filter { !t.ownedPieces.contains($0) }
                if let p = missing.randomElement() {
                    if var updated = tracks[t.id] {
                        updated.ownedPieces.append(p)
                        updated.ownedPieces.sort()
                        tracks[t.id] = updated
                        if updated.isComplete { puzzleCompleteTrackId = t.id }
                    }
                }
            }
        default: break
        }
        showToast("\(item.name) を購入しました！")
    }

    func equipDecoration(_ id: String?) {
        equippedDecoration = (equippedDecoration == id) ? nil : id
    }

    func navigate(to screen: Screen) { navigationStack.append(screen) }
    func goBack() {
        clearCollectPrompts()
        if !navigationStack.isEmpty { navigationStack.removeLast() }
    }

    // MARK: - Computed

    var heroTrack: Track? {
        guard let playlist = dailyPlaylist,
              let item = playlist.tracks.first else { return nil }
        return tracks[item.trackId]
    }

    func track(for id: String) -> Track? { tracks[id] }

    var activeEncounter: Encounter? {
        guard !encounters.isEmpty, encounters.indices.contains(activeEncounterIndex) else {
            return todayEncounter
        }
        return encounters[activeEncounterIndex]
    }

    var artistGroups: [ArtistGroup] {
        var groups: [String: (name: String, tracks: [Track])] = [:]
        for track in tracks.values {
            let artistName = track.artistName ?? "Unknown"
            if groups[track.artistId] == nil {
                groups[track.artistId] = (name: artistName, tracks: [])
            }
            groups[track.artistId]?.tracks.append(track)
        }
        return groups.map { id, val in
            ArtistGroup(id: id, name: val.name, tracks: val.tracks.sorted { $0.id < $1.id })
        }.sorted { $0.name < $1.name }
    }

    var pendingEncounterCount: Int {
        encounters.filter { encounterCooldowns[$0.id] == nil }.count
    }

    func isTitleUnlocked(_ title: TitleItem) -> Bool {
        titleProgress(title) >= title.conditionCount
    }

    func titleProgress(_ title: TitleItem) -> Int {
        switch title.conditionType {
        case "puzzles":  return tracks.values.filter { $0.isComplete }.count
        case "artists":  return artistGroups.filter { $0.completed == $0.tracks.count && !$0.tracks.isEmpty }.count
        case "friends":  return friends.count
        case "unlocks":  return unlockedTrackIds.count
        case "mission":  return (mission?.current ?? 0) >= (mission?.target ?? 5) ? 1 : 0
        default:         return 0
        }
    }

    // NPC piece counts matching web data
    private let npcPieces: [String: Int] = [
        "user_tanaka_yuki":   96,
        "user_sato_kenji":    81,
        "user_suzuki_aya":    64,
        "user_yamada_taro":   47,
        "user_nakamura_mika": 28,
    ]

    func rankRows(for tab: RankingTab) -> [RankRow] {
        let myPieces = tracks.values.reduce(0) { $0 + $1.ownedPieces.count }
        let npcRows: [RankRow] = encounters.map { enc in
            RankRow(name: enc.fromUserName, sub: enc.locationLabel,
                    count: npcPieces[enc.fromUserId] ?? 30, isMe: false)
        }
        var rows: [RankRow]
        switch tab {
        case .today:
            rows = npcRows
        case .near:
            rows = npcRows + [
                RankRow(name: "ともき", sub: "渋谷エリア", count: 142, isMe: false),
                RankRow(name: "りんか", sub: "渋谷エリア", count: 121, isMe: false),
            ]
        case .friend:
            rows = friends.map { f in
                RankRow(name: f.userName, sub: "交換\(f.exchangeCount)回",
                        count: npcPieces[f.userId] ?? 30, isMe: false)
            }
        case .all:
            rows = [
                RankRow(name: "ユウキ", sub: "東京",   count: 512, isMe: false),
                RankRow(name: "さくら", sub: "大阪",   count: 498, isMe: false),
                RankRow(name: "ハルト", sub: "福岡",   count: 451, isMe: false),
                RankRow(name: "メイ",   sub: "名古屋", count: 387, isMe: false),
                RankRow(name: "ソウタ", sub: "札幌",   count: 305, isMe: false),
            ] + npcRows
        }
        let myName = user?.name ?? "StreetMelodyユーザー"
        rows.append(RankRow(name: "\(myName)（あなた）", sub: "集めたピース", count: myPieces, isMe: true))
        return rows.sorted { $0.count > $1.count }
    }

    // MARK: - Level

    func levelInfo() -> (level: Int, current: Int, next: Int) {
        var level = 1
        var rest = max(exp, 0)
        while rest >= level * 100 {
            rest -= level * 100
            level += 1
        }
        return (level: level, current: rest, next: level * 100)
    }

    // MARK: - Helpers

    func cooldownRemaining(for encounterId: String) -> TimeInterval {
        guard let cooldownAt = encounterCooldowns[encounterId] else { return 0 }
        let elapsed = Date().timeIntervalSince(cooldownAt)
        let remaining = (6 * 3600) - elapsed
        return max(0, remaining)
    }

    func formatCooldown(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return "\(h)時間\(m)分"
    }

    func showToast(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            toast = nil
        }
    }

    // MARK: - Account（方式A: アカウント連携）

    /// 現在の認証状態（ゲスト/連携メール）を Published に反映。
    func refreshAccountState() async {
        accountEmail = await SupabaseClient.shared.email
        isGuestAccount = await SupabaseClient.shared.isAnonymous
    }

    /// 匿名アカウントにメール＋パスワードを設定して永続化（成功時 nil、失敗時エラー文）。
    /// 「Confirm email」ON の場合は確認メール送信となり、確認リンクのタップで連携完了。
    func linkAccount(email: String, password: String) async -> String? {
        do {
            let active = try await SupabaseClient.shared.upgradeToEmail(email, password)
            await refreshAccountState()
            showToast(active ? "アカウントを連携しました（メールで復元できます）"
                             : "確認メールを送信しました。メール内のリンクをタップすると連携完了です")
            return nil
        } catch {
            return "連携に失敗しました。メール形式・パスワード（6文字以上）をご確認ください。"
        }
    }

    /// 既存メールアカウントでログインし、進行を復元（成功時 nil、失敗時エラー文）。
    func signInAccount(email: String, password: String) async -> String? {
        do {
            _ = try await SupabaseClient.shared.signInWithEmail(email, password)
            await refreshAccountState()
            await mergeRemoteProgress()
            showToast("ログインしました。進行を復元しました")
            return nil
        } catch {
            return "ログインに失敗しました。メール・パスワードをご確認ください。"
        }
    }

    /// Apple（id_token）。link=true は今のゲスト進行を保ったまま昇格。
    func signInWithApple(idToken: String, nonce: String, link: Bool) async -> String? {
        await providerAuth("Apple", link: link) { try await SupabaseAuthKit.signInWithApple(idToken: idToken, nonce: nonce, link: link) }
    }

    /// OAuth（Google / Spotify）。link=true は昇格（進行保持）、false は新規/復元サインイン。
    func signInWithGoogle(link: Bool) async -> String? {
        await providerAuth("Google", link: link) { try await SupabaseAuthKit.signInWithGoogle(link: link) }
    }
    func signInWithSpotify(link: Bool) async -> String? {
        await providerAuth("Spotify", link: link) { try await SupabaseAuthKit.signInWithSpotify(link: link) }
    }

    private func providerAuth(_ name: String, link: Bool, _ action: () async throws -> Void) async -> String? {
        do {
            try await action()
            await refreshAccountState()
            await mergeRemoteProgress()
            showToast(link ? "\(name) と連携しました（進行はそのまま）" : "\(name) でログインしました")
            return nil
        } catch {
            if let m = (error as? SupabaseClient.OAuthError)?.errorDescription { return "\(name): \(m)" }
            return "\(name) \(link ? "連携" : "ログイン")に失敗しました（\(error.localizedDescription)）"
        }
    }

    /// ログアウト（以後は匿名相当。ローカル進行は保持）。
    func signOutAccount() async {
        await SupabaseClient.shared.signOut()
        await refreshAccountState()
        showToast("ログアウトしました")
    }

    func addFriend(userId: String, userName: String, locationLabel: String) {
        if !friends.contains(where: { $0.userId == userId }) {
            friends.append(Friend(userId: userId, userName: userName,
                                  locationLabel: locationLabel, exchangeCount: 1, addedAt: Date()))
            checkTitleUnlocks()
            // 方式A: フレンドを Supabase に保存
            Task { await SupabaseClient.shared.upsertFriend(name: userName, location: locationLabel, exchangeCount: 1) }
        }
    }

    // MARK: - Seed Data (matches web data.js exactly)

    private func loadSeedData() {
        user = User(id: "me", name: "StreetMelodyユーザー", level: 3, exp: 0, coins: 240)
        coins = 240
        exp = 0

        let seedTrackList: [Track] = [
            Track(id: "track_pretender",
                  artistId: "artist_higedan", pieceCount: 24, rewardCoins: 100, rewardExp: 50,
                  color: "magic", tone: nil,
                  title: "Pretender", artistName: "Official髭男dism",
                  isUnlocked: true, hintLevel: 2, answerReady: true, maskedLabel: nil,
                  choices: [], ownedPieces: Array(1...12),
                  youtubeVideoId: "TQ8WlA2GXbk", chorusStart: 57),

            Track(id: "track_lemon",
                  artistId: "artist_yonezu", pieceCount: 24, rewardCoins: 100, rewardExp: 50,
                  color: "violet", tone: nil,
                  title: "Lemon", artistName: "米津玄師",
                  isUnlocked: false, hintLevel: 0, answerReady: false,
                  maskedLabel: "?????",
                  choices: ["恋愛", "夏", "夜", "ドラマ"], ownedPieces: [],
                  youtubeVideoId: "SX_ViT4Ra7k", chorusStart: 68),

            Track(id: "track_yoru",
                  artistId: "artist_yoasobi", pieceCount: 24, rewardCoins: 100, rewardExp: 50,
                  color: "berry", tone: nil,
                  title: "夜に駆ける", artistName: "YOASOBI",
                  isUnlocked: false, hintLevel: 0, answerReady: false,
                  maskedLabel: "?????",
                  choices: ["夜", "疾走感", "小説", "出会い"], ownedPieces: Array(1...8),
                  youtubeVideoId: "x8VYWazR5mE", chorusStart: 52),

            Track(id: "track_show",
                  artistId: "artist_ado", pieceCount: 24, rewardCoins: 100, rewardExp: 50,
                  color: "magic", tone: nil,
                  title: "唱", artistName: "Ado",
                  isUnlocked: true, hintLevel: 2, answerReady: true, maskedLabel: nil,
                  choices: [], ownedPieces: Array(1...22),
                  youtubeVideoId: "pgXpM4l_MwI", chorusStart: 44),

            Track(id: "track_kaiju",
                  artistId: "artist_vaundy", pieceCount: 24, rewardCoins: 100, rewardExp: 50,
                  color: "sunset", tone: nil,
                  title: "怪獣の花唄", artistName: "Vaundy",
                  isUnlocked: true, hintLevel: 2, answerReady: true, maskedLabel: nil,
                  choices: [], ownedPieces: Array(1...18),
                  youtubeVideoId: "UM9XNpgrqVk", chorusStart: 38),

            Track(id: "track_anytime",
                  artistId: "artist_milet", pieceCount: 24, rewardCoins: 100, rewardExp: 50,
                  color: "violet", tone: nil,
                  title: "Anytime Anywhere", artistName: "milet",
                  isUnlocked: false, hintLevel: 0, answerReady: false,
                  maskedLabel: "????? ???????",
                  choices: ["透明感", "旅", "祈り", "エンディング"], ownedPieces: [],
                  youtubeVideoId: "r105CzDvoo0", chorusStart: 58),

            Track(id: "track_blueberry",
                  artistId: "artist_macaroni", pieceCount: 24, rewardCoins: 100, rewardExp: 50,
                  color: "berry", tone: nil,
                  title: "ブルーベリー・ナイツ", artistName: "マカロニえんぴつ",
                  isUnlocked: true, hintLevel: 2, answerReady: true, maskedLabel: nil,
                  choices: [], ownedPieces: Array(1...8),
                  youtubeVideoId: "Euf1-3WRino", chorusStart: 55),

            Track(id: "track_halzion",
                  artistId: "artist_yoasobi", pieceCount: 24, rewardCoins: 100, rewardExp: 50,
                  color: "violet", tone: nil,
                  title: "ハルジオン", artistName: "YOASOBI",
                  isUnlocked: true, hintLevel: 2, answerReady: true, maskedLabel: nil,
                  choices: [], ownedPieces: Array(1...18),
                  youtubeVideoId: "kzdJkT4kp-A", chorusStart: 62),
        ]
        tracks = Dictionary(uniqueKeysWithValues: seedTrackList.map { ($0.id, $0) })
        unlockedTrackIds = seedTrackList.filter { $0.isUnlocked }.map { $0.id }

        let base = Date().addingTimeInterval(6 * 3600)
        encounters = [
            Encounter(id: "encounter_today_001", locationLabel: "大学",
                      fromUserName: "田中ゆき", fromUserId: "user_tanaka_yuki",
                      rewardCoins: 10, expiresAt: base,
                      candidates: [
                        Candidate(id: "c1_1", trackId: "track_pretender", pieceNumber: 13, sourceSlot: "推し曲枠", rarity: 5, sortOrder: 0,
                                  availablePieces: [13,14,15,16,17,18,19,20,21,22,23,24]),
                        Candidate(id: "c1_2", trackId: "track_lemon",     pieceNumber: 1,  sourceSlot: "発見枠",   rarity: 5, sortOrder: 1,
                                  availablePieces: [1,2,3,4,5,6,7,8,9,10,11,12]),
                        Candidate(id: "c1_3", trackId: "track_yoru",      pieceNumber: 9,  sourceSlot: "発見枠",   rarity: 5, sortOrder: 2,
                                  availablePieces: [9,10,11,12,13,14,15,16]),
                        Candidate(id: "c1_4", trackId: "track_kaiju",     pieceNumber: 19, sourceSlot: "レア枠",   rarity: 5, sortOrder: 3,
                                  availablePieces: [19,20,21,22,23,24]),
                        Candidate(id: "c1_5", trackId: "track_anytime",   pieceNumber: 1,  sourceSlot: "イベント", rarity: 5, sortOrder: 4,
                                  availablePieces: [1,2,3,4,5,6,7,8,9,10,11,12]),
                      ]),

            Encounter(id: "encounter_today_002", locationLabel: "渋谷駅",
                      fromUserName: "佐藤けんじ", fromUserId: "user_sato_kenji",
                      rewardCoins: 10, expiresAt: base,
                      candidates: [
                        Candidate(id: "c2_1", trackId: "track_yoru",      pieceNumber: 1,  sourceSlot: "推し曲枠", rarity: 5, sortOrder: 0,
                                  availablePieces: [1,2,3,4,5,6,7,8,9,10,11,12]),
                        Candidate(id: "c2_2", trackId: "track_blueberry", pieceNumber: 9,  sourceSlot: "発見枠",   rarity: 4, sortOrder: 1,
                                  availablePieces: [5,6,7,8,9,10,11,12,13,14,15,16]),
                        Candidate(id: "c2_3", trackId: "track_pretender", pieceNumber: 1,  sourceSlot: "発見枠",   rarity: 5, sortOrder: 2,
                                  availablePieces: [1,2,3,4,5,6,7,8]),
                      ]),

            Encounter(id: "encounter_today_003", locationLabel: "カフェ",
                      fromUserName: "鈴木あや", fromUserId: "user_suzuki_aya",
                      rewardCoins: 10, expiresAt: base,
                      candidates: [
                        Candidate(id: "c3_1", trackId: "track_show",     pieceNumber: 23, sourceSlot: "推し曲枠", rarity: 5, sortOrder: 0,
                                  availablePieces: [1,2,3,4,5,6,7,8,9,10,11,12]),
                        Candidate(id: "c3_2", trackId: "track_lemon",    pieceNumber: 13, sourceSlot: "発見枠",   rarity: 5, sortOrder: 1,
                                  availablePieces: [13,14,15,16,17,18,19,20]),
                        Candidate(id: "c3_3", trackId: "track_anytime",  pieceNumber: 13, sourceSlot: "発見枠",   rarity: 3, sortOrder: 2,
                                  availablePieces: [13,14,15,16,17,18,19,20,21,22,23,24]),
                        Candidate(id: "c3_4", trackId: "track_halzion",  pieceNumber: 19, sourceSlot: "レア枠",   rarity: 5, sortOrder: 3,
                                  availablePieces: [19,20,21,22,23,24]),
                      ]),

            Encounter(id: "encounter_today_004", locationLabel: "図書館",
                      fromUserName: "山田たろう", fromUserId: "user_yamada_taro",
                      rewardCoins: 10, expiresAt: base,
                      candidates: [
                        Candidate(id: "c4_1", trackId: "track_halzion",   pieceNumber: 19, sourceSlot: "推し曲枠", rarity: 5, sortOrder: 0,
                                  availablePieces: [1,2,3,4,5,6,7,8,9,10,11,12]),
                        Candidate(id: "c4_2", trackId: "track_kaiju",     pieceNumber: 1,  sourceSlot: "発見枠",   rarity: 5, sortOrder: 1,
                                  availablePieces: [1,2,3,4,5,6,7,8,9,10,11,12]),
                        Candidate(id: "c4_3", trackId: "track_blueberry", pieceNumber: 17, sourceSlot: "発見枠",   rarity: 4, sortOrder: 2,
                                  availablePieces: [17,18,19,20,21,22,23,24]),
                      ]),

            Encounter(id: "encounter_today_005", locationLabel: "コンビニ",
                      fromUserName: "中村みか", fromUserId: "user_nakamura_mika",
                      rewardCoins: 10, expiresAt: base,
                      candidates: [
                        Candidate(id: "c5_1", trackId: "track_blueberry", pieceNumber: 9, sourceSlot: "推し曲枠", rarity: 4, sortOrder: 0,
                                  availablePieces: [1,2,3,4,5,6,7,8]),
                        Candidate(id: "c5_2", trackId: "track_yoru",      pieceNumber: 17, sourceSlot: "レア枠",  rarity: 5, sortOrder: 1,
                                  availablePieces: [17,18,19,20,21,22,23,24]),
                      ]),
        ]
        todayEncounter = encounters.first

        mission = Mission(userId: "me", date: "2026-06-17", label: "デイリー", current: 3, target: 5, rewardCoins: 10)

        dailyPlaylist = DailyPlaylist(
            id: "pl_001", date: "2026-06-17", title: "今日のメロディ",
            tracks: [
                PlaylistItem(trackId: "track_show",      artistId: "artist_ado",      color: "magic"),
                PlaylistItem(trackId: "track_blueberry", artistId: "artist_macaroni", color: "berry"),
                PlaylistItem(trackId: "track_kaiju",     artistId: "artist_vaundy",   color: "sunset"),
                PlaylistItem(trackId: "track_halzion",   artistId: "artist_yoasobi",  color: "violet"),
            ]
        )

        collection = CollectionSummary(completedPuzzles: 1, totalPuzzles: 8, completedArtists: 0, totalArtists: 6, playlists: 1)

        friends = [
            Friend(userId: "user_tanaka_yuki",   userName: "田中ゆき",   locationLabel: "大学",   exchangeCount: 4, addedAt: Date().addingTimeInterval(-86400)),
            Friend(userId: "user_sato_kenji",    userName: "佐藤けんじ", locationLabel: "渋谷駅", exchangeCount: 2, addedAt: Date().addingTimeInterval(-172800)),
            Friend(userId: "user_suzuki_aya",    userName: "鈴木あや",   locationLabel: "カフェ", exchangeCount: 1, addedAt: Date().addingTimeInterval(-259200)),
        ]
    }

    // MARK: - Title seed data (static, matches web)

    var titles: [TitleItem] {[
        TitleItem(id: "title_first_puzzle",  icon: "🧩", name: "はじめてのひとかけら", description: "曲パズルを1曲完成させる",             rewardCoins: 30,  rewardExp: 30,  conditionType: "puzzles",  conditionCount: 1),
        TitleItem(id: "title_three_puzzles", icon: "🎼", name: "メロディコレクター",   description: "曲パズルを3曲完成させる",             rewardCoins: 50,  rewardExp: 50,  conditionType: "puzzles",  conditionCount: 3),
        TitleItem(id: "title_all_puzzles",   icon: "👑", name: "パズルマエストロ",     description: "全曲のパズルを完成させる",            rewardCoins: 200, rewardExp: 200, conditionType: "puzzles",  conditionCount: 10),
        TitleItem(id: "title_first_artist",  icon: "🌟", name: "推しマスター",         description: "1組のアーティストの全曲を完成させる", rewardCoins: 100, rewardExp: 100, conditionType: "artists",  conditionCount: 1),
        TitleItem(id: "title_first_friend",  icon: "🤝", name: "はじめてのフレンド",   description: "フレンドを1人つくる",                 rewardCoins: 30,  rewardExp: 30,  conditionType: "friends",  conditionCount: 1),
        TitleItem(id: "title_three_friends", icon: "🎶", name: "音楽の輪",             description: "フレンドを3人つくる",                 rewardCoins: 50,  rewardExp: 50,  conditionType: "friends",  conditionCount: 3),
        TitleItem(id: "title_unlock_five",   icon: "🔓", name: "名曲ハンター",         description: "曲名を5曲解放する",                   rewardCoins: 50,  rewardExp: 50,  conditionType: "unlocks",  conditionCount: 5),
        TitleItem(id: "title_daily_mission", icon: "📅", name: "今日のがんばり屋",     description: "デイリーミッションを達成する",        rewardCoins: 20,  rewardExp: 20,  conditionType: "mission",  conditionCount: 1),
    ]}

    var shopItems: [ShopItem] {[
        ShopItem(id: "shop_hint_ticket",  icon: "🎟️", name: "ヒントチケット",   description: "広告なしでヒントを1回解放できます",             price: 15,  type: "ticket"),
        ShopItem(id: "shop_random_piece", icon: "🎲", name: "ランダムピース",   description: "未完成のパズルからランダムで1ピース獲得します", price: 20,  type: "piece"),
        ShopItem(id: "shop_deco_hat",     icon: "🎩", name: "シルクハット",     description: "アバターに装備できる装飾です",                   price: 50,  type: "decoration"),
        ShopItem(id: "shop_deco_ribbon",  icon: "🎀", name: "リボン",           description: "アバターに装備できる装飾です",                   price: 50,  type: "decoration"),
        ShopItem(id: "shop_deco_crown",   icon: "👑", name: "クラウン",         description: "アバターに装備できる装飾です",                   price: 100, type: "decoration"),
    ]}
}
