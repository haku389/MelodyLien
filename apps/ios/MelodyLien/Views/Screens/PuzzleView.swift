import SwiftUI

struct PuzzleView: View {
    let trackId: String
    @EnvironmentObject var vm: AppViewModel

    private var track: Track? { vm.track(for: trackId) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let t = track { content(track: t) }
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 112)
        }
        .scrollIndicators(.hidden)
        .background(Color(hex: "F5F0FF").ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Color(hex: "F5F0FF"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { vm.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(hex: "7248E0"))
                }
            }
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(track?.displayTitle ?? "—")
                        .font(.system(size: 14, weight: .black)).foregroundStyle(.primary).lineLimit(1)
                    Text(track?.displayArtist ?? "—")
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await vm.addListenLater(trackId: trackId) } } label: {
                    Image(systemName: "heart").font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(hex: "7248E0"))
                }
            }
        }
    }

    private func content(track: Track) -> some View {
        let owned    = track.ownedPieces.count
        let total    = track.pieceCount
        let progress = Double(owned) / Double(max(total, 1))
        let rem      = max(total - owned, 0)

        return VStack(spacing: 14) {
            // 6×4 パズル本体：所持ピースだけサムネイルが見える（設計書準拠）
            VStack(spacing: 14) {
                PuzzlePiecesView(thumbnailURL: track.thumbnailURL,
                                 ownedPieces: track.ownedPieces,
                                 color: track.color,
                                 cornerRadius: 18)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(owned) / \(total)").font(.system(size: 20, weight: .black)).foregroundStyle(.primary)
                        Text("ピース").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                        Spacer()
                        Text(rem > 0 ? "あと\(rem)ピースで完成！" : "🎉 完成！")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(rem == 0 ? Color(hex: "1A9E6E") : Color(hex: "7B6F8A"))
                    }
                    ProgressBarView(value: progress)
                }
            }
            .padding(16).mlCard()

            VStack(alignment: .leading, spacing: 12) {
                Text("完成で手に入る報酬").font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
                HStack(spacing: 10) {
                    rewardTile(label: "メロディコイン", value: "×\(track.rewardCoins)")
                    rewardTile(label: "経験値", value: "×\(track.rewardExp)")
                }
                Button { vm.activeTab = .melody } label: {
                    Text("ピースを集める").buttonLabel(.primary)
                }
            }
            .padding(16).mlCard()

            PostCollectSection()
        }
    }

    private func rewardTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            Text(value).font(.system(size: 20, weight: .black)).foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(hex: "EDE8FF"), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "E0D8F7")))
    }
}
