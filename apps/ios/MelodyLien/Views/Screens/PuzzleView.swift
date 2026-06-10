import SwiftUI

struct PuzzleView: View {
    let trackId: String
    @EnvironmentObject var vm: AppViewModel

    private var track: Track? { vm.track(for: trackId) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                screenHeader
                if let t = track { content(track: t) }
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 112)
        }
        .scrollIndicators(.hidden)
    }

    private var screenHeader: some View {
        HStack(spacing: 12) {
            Button { vm.goBack() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .heavy))
                    .frame(width: 42, height: 42)
                    .background(.regularMaterial, in: Circle())
            }
            VStack(spacing: 2) {
                Text(track?.displayTitle ?? "—").font(.system(size: 15, weight: .black)).lineLimit(1)
                Text(track?.displayArtist ?? "—").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "817992"))
            }
            .frame(maxWidth: .infinity)
            Button { Task { await vm.addListenLater(trackId: trackId) } } label: {
                Image(systemName: "heart")
                    .font(.system(size: 18, weight: .heavy))
                    .frame(width: 42, height: 42)
                    .background(.regularMaterial, in: Circle())
            }
        }
        .padding(.bottom, 18)
    }

    private func content(track: Track) -> some View {
        let owned = track.ownedPieces.count
        let total = track.pieceCount
        let progress = Double(owned) / Double(max(total, 1))

        return VStack(spacing: 14) {
            // Hero
            HStack(spacing: 16) {
                ArtBlockView(color: track.color).frame(width: 128, height: 128)
                VStack(alignment: .leading, spacing: 8) {
                    Text("曲パズル").font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "817992"))
                    PieceMeterView(owned: owned, total: total, compact: true)
                    ProgressBarView(value: progress)
                    let rem = max(total - owned, 0)
                    Text(rem > 0 ? "あと\(rem)ピースで完成！" : "完成！")
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "817992"))
                }
                Spacer()
            }
            .padding(16)
            .mlCard()

            // Piece grid
            VStack(alignment: .leading, spacing: 12) {
                Text("所持ピース").font(.system(size: 14, weight: .black))
                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 10) {
                    ForEach(1...total, id: \.self) { n in
                        let has = track.ownedPieces.contains(n)
                        RoundedRectangle(cornerRadius: 16)
                            .fill(has
                                  ? LinearGradient(colors: [Color(hex: "ff7fa6"), Color(hex: "8f6df4")], startPoint: .topLeading, endPoint: .bottomTrailing)
                                  : LinearGradient(colors: [Color(hex: "eee7f7"), Color(hex: "eee7f7")], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                Text(has ? "🧩" : "\(n)")
                                    .font(.system(size: has ? 22 : 13, weight: .black))
                                    .foregroundStyle(has ? Color.white : Color(hex: "817992"))
                            )
                    }
                }
            }
            .padding(16)
            .mlCard()

            // Reward
            VStack(alignment: .leading, spacing: 12) {
                Text("完成で手に入る報酬").font(.system(size: 14, weight: .black))
                HStack(spacing: 10) {
                    rewardTile(label: "メロディコイン", value: "×\(track.rewardCoins)")
                    rewardTile(label: "経験値", value: "×\(track.rewardExp)")
                }
                Button { vm.activeTab = .exchange } label: {
                    Text("ピース一覧を見る").buttonLabel(.primary)
                }
            }
            .padding(16)
            .mlCard()
        }
    }

    private func rewardTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "817992"))
            Text(value).font(.system(size: 20, weight: .black))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(hex: "f8f1ff"), in: RoundedRectangle(cornerRadius: 18))
    }
}
