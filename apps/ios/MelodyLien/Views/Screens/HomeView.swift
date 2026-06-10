import SwiftUI

struct HomeView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerRow
                heroPanel
                collectionPanel
                missionPanel
                recentTracksPanel
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 112)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: "e8dff7"))
                .frame(width: 54, height: 54)
                .overlay(Text("🎵").font(.title2))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(vm.user?.name ?? "—")
                    .font(.system(size: 15, weight: .black))
                Text("Lv.\(vm.user?.level ?? 0)")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Color(hex: "817992"))
                ProgressBarView(value: Double(vm.user?.level ?? 0) / 100.0)
                    .frame(height: 8)
            }
            Spacer()
            coinPill
        }
        .padding(.bottom, 18)
    }

    private var coinPill: some View {
        HStack(spacing: 6) {
            Text("🪙")
            Text(formatNumber(vm.user?.coins ?? 0))
                .font(.system(size: 12, weight: .black))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.8)))
    }

    // MARK: - Hero panel

    private var heroPanel: some View {
        HStack(spacing: 16) {
            if let hero = vm.heroTrack {
                ArtBlockView(color: hero.color)
                    .frame(width: 132, height: 132)
            } else {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(hex: "eee6fb"))
                    .frame(width: 132, height: 132)
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("今日のメロディ")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Color(hex: "817992"))

                Text(vm.heroTrack?.displayTitle ?? "—")
                    .font(.system(size: 14, weight: .black))
                    .lineLimit(1)

                if let hero = vm.heroTrack {
                    PieceMeterView(owned: hero.ownedPieces.count, total: hero.pieceCount)
                    ProgressBarView(value: Double(hero.ownedPieces.count) / Double(max(hero.pieceCount, 1)))
                    let rem = max(hero.pieceCount - hero.ownedPieces.count, 0)
                    if rem > 0 {
                        Text("あと\(rem)ピースで完成！")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Color(hex: "817992"))
                    } else {
                        Text("完成！").font(.system(size: 10, weight: .heavy)).foregroundStyle(.green)
                    }
                }

                Button {
                    vm.activeTab = .exchange
                } label: {
                    Label("近距離交換をはじめる", systemImage: "location.fill")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "8f6df4"), in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .padding(16)
        .mlCard()
        .padding(.bottom, 14)
    }

    // MARK: - Collection

    private var collectionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("コレクション").font(.system(size: 14, weight: .black))
            HStack(spacing: 10) {
                statTile(label: "曲パズル",
                         value: "\(vm.collection?.completedPuzzles ?? 0) / \(vm.collection?.totalPuzzles ?? 0)")
                statTile(label: "アーティスト",
                         value: "\(vm.collection?.completedArtists ?? 0) / \(vm.collection?.totalArtists ?? 0)")
                statTile(label: "プレイリスト",
                         value: "\(vm.collection?.playlists ?? 0)")
            }
        }
        .padding(16)
        .mlCard()
        .padding(.bottom, 14)
    }

    private func statTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "817992"))
            Text(value).font(.system(size: 13, weight: .black))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(Color(hex: "f8f1ff"), in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Mission

    private var missionPanel: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(vm.mission?.label ?? "デイリー")ミッション")
                    .font(.system(size: 13, weight: .black))
                ProgressBarView(value: vm.mission?.progress ?? 0)
            }
            Spacer()
            Text("\(vm.mission?.current ?? 0) / \(vm.mission?.target ?? 5)")
                .font(.system(size: 14, weight: .black))
        }
        .padding(16)
        .mlCard()
        .padding(.bottom, 14)
    }

    // MARK: - Recent tracks

    private var recentTracksPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近追加した曲").font(.system(size: 14, weight: .black))
                Spacer()
                Button("すべて見る") { vm.activeTab = .playlist }
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Color(hex: "8f6df4"))
            }
            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 12) {
                ForEach(Array(vm.tracks.values.prefix(3))) { track in
                    Button {
                        vm.navigate(to: track.isUnlocked ? .puzzle(trackId: track.id) : .mystery(trackId: track.id))
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            ArtBlockView(color: track.color).aspectRatio(1, contentMode: .fit)
                            Text(track.isUnlocked ? track.title ?? "—" : "未解放メロディ")
                                .font(.system(size: 11, weight: .black)).lineLimit(1)
                            Text(track.isUnlocked ? track.artistName ?? "—" : "???")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(Color(hex: "817992")).lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .mlCard()
    }

    // MARK: - Helpers
    private func formatNumber(_ n: Int) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        return fmt.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - Card modifier

extension View {
    func mlCard() -> some View {
        self
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(hex: "eadff3").opacity(0.86)))
            .shadow(color: .black.opacity(0.07), radius: 14, y: 8)
    }
}
