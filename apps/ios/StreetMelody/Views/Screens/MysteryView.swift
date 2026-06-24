import SwiftUI

struct MysteryView: View {
    let trackId: String
    @EnvironmentObject var vm: AppViewModel
    @State private var showAdModal = false
    @State private var pendingHint: HintKind = .hint1
    @State private var showGuessAlert = false
    @State private var guessText = ""

    private var track: Track? { vm.track(for: trackId) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let t = track {
                    mysteryHero(track: t)
                    actionBlock(track: t)
                    if t.hintLevel >= 2, !t.choices.isEmpty {
                        choiceGrid(choices: t.choices)
                    }
                    youtubePanel(track: t)
                    PostCollectSection()
                }
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
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(hex: "7248E0"))
                }
            }
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("未解放メロディ").font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
                    Text("ヒントを使ってこの曲の名前を当てよう！")
                        .font(.system(size: 9, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { vm.goBack() } label: {
                    Text("あとで").font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                }
            }
        }
        .sheet(isPresented: $showAdModal) {
            AdConfirmModal(kind: pendingHint) {
                Task { await vm.applyHint(trackId: trackId, kind: pendingHint) }
            }
        }
        .alert("曲名を当てる", isPresented: $showGuessAlert) {
            TextField("曲名を入力してください", text: $guessText)
            Button("確認") {
                let _ = vm.guessTrack(trackId: trackId, answer: guessText)
                guessText = ""
            }
            Button("キャンセル", role: .cancel) { guessText = "" }
        } message: {
            Text("曲名を入力して正解すると解放されます")
        }
    }

    // MARK: - Mystery hero

    private func mysteryHero(track: Track) -> some View {
        VStack(spacing: 10) {
            ZStack {
                // 未解放はパズルサムネイルをモザイク（フル表示）で見せる
                PuzzlePiecesView(thumbnailURL: track.thumbnailURL,
                                 ownedPieces: track.ownedPieces,
                                 color: track.color,
                                 cornerRadius: 22,
                                 revealAll: true,
                                 blur: true)
                    .frame(maxWidth: min(300, UIScreen.main.bounds.width * 0.82))
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "7248E0").opacity(0.18))
                    .frame(width: 62, height: 62)
                    .overlay(Text("🔒").font(.system(size: 28)))
            }
            Text(maskedDisplay(track: track))
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            Text("未解放メロディ").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
        }
        .padding(.bottom, 16)
    }

    // MARK: - 少し聴く（30秒試聴）

    @ViewBuilder
    private func previewButton(track: Track) -> some View {
        let hasVideo = track.hasYouTubeVideo
        let left = vm.previewPlaysLeft(trackId: track.id)
        let enabled = hasVideo && left > 0
        Button { vm.startPreview(trackId: track.id) } label: {
            Text(!hasVideo ? "試聴できません"
                 : left > 0 ? "▶ 少し聴く（あと\(left)回）"
                 : "本日の試聴回数を使い切りました")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(enabled ? .white : Color(hex: "B8ACD6"))
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(
                    enabled
                        ? LinearGradient(colors: [Color(hex: "79C7FF"), Color(hex: "5BA8F5")], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color(hex: "EDE8FF"), Color(hex: "EDE8FF")], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 16)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Action block

    private func actionBlock(track: Track) -> some View {
        VStack(spacing: 10) {
            previewButton(track: track)
            Button { showGuessAlert = true } label: {
                Text("曲名を当てる").buttonLabel(.pink)
            }
            Button { pendingHint = .hint1; showAdModal = true } label: {
                Text("1つ目のヒントを見る  🎫×1").buttonLabel(.secondary)
            }
            Button { pendingHint = .hint2; showAdModal = true } label: {
                Text("2つ目のヒントを見る  🎫×1").buttonLabel(.secondary)
            }
            Button { pendingHint = .answer; showAdModal = true } label: {
                Text("答えを見る  CM×1").buttonLabel(.coin)
            }
            if vm.hintTickets > 0 {
                Text("🎟️ ヒントチケット \(vm.hintTickets)枚所持 — 広告なしで解放されます")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Color(hex: "7248E0"))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(16).mlCard()
        .padding(.bottom, 14)
    }

    // MARK: - 4択

    private func choiceGrid(choices: [String]) -> some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
            ForEach(choices, id: \.self) { choice in
                Button(choice) {}
                    .font(.system(size: 13, weight: .heavy)).foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(Color(hex: "EDE8FF"), in: RoundedRectangle(cornerRadius: 15))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color(hex: "E0D8F7")))
            }
        }
        .padding(16).mlCard()
        .padding(.bottom, 14)
    }

    // MARK: - YouTube panel

    private func youtubePanel(track: Track) -> some View {
        let hasVideo = track.hasYouTubeVideo
        let isLocked = !track.answerReady

        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let thumbURL = track.thumbnailURL, !isLocked {
                    CachedThumbnail(url: thumbURL)
                        .background(Color(hex: "EDE8FF"))
                        .frame(width: 72, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(hasVideo ? Color.red.opacity(0.8) : Color(hex: "EDE8FF"))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: hasVideo ? "play.fill" : "lock.fill")
                                .foregroundStyle(hasVideo ? .white : Color(hex: "B8ACD6"))
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("YouTubeで見て確認")
                        .font(.system(size: 13, weight: .black)).foregroundStyle(.primary).lineLimit(1)
                    Text(
                        isLocked ? "広告視聴後に確認できます" :
                        !hasVideo ? "この曲のYouTube動画はありません" :
                        "確認すると曲名とアーティスト名を解放します"
                    )
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Color(hex: "7B6F8A")).lineLimit(1)
                }
                Spacer()
                if isLocked {
                    Button { pendingHint = .answer; showAdModal = true } label: {
                        Text("CM").buttonLabel(.coin, small: true)
                    }
                } else {
                    Button {
                        Task { await vm.unlockTrack(trackId: trackId) }
                    } label: {
                        Text("確認して解放").buttonLabel(.primary, small: true)
                    }
                }
            }
        }
        .padding(14).mlCard()
        .opacity(isLocked ? 0.55 : 1)
    }

    // MARK: - Helpers

    private func maskedDisplay(track: Track) -> String {
        if track.isUnlocked { return "\(track.artistName ?? "") / \(track.title ?? "")" }
        guard let masked = track.maskedLabel else { return "★★★★★★★★" }
        return masked
    }
}

// MARK: - Button label style (MLButtonStyle avoids conflict with SwiftUI ButtonStyle)

enum MLButtonStyle { case primary, secondary, pink, coin }

extension View {
    func buttonLabel(_ style: MLButtonStyle, small: Bool = false) -> some View {
        self
            .font(.system(size: small ? 11 : 12, weight: .black))
            .foregroundStyle(buttonFG(style))
            .frame(maxWidth: small ? nil : .infinity, minHeight: small ? 32 : 40)
            .padding(.horizontal, small ? 10 : 14)
            .background(buttonBG(style), in: RoundedRectangle(cornerRadius: small ? 13 : 16))
    }

    private func buttonFG(_ style: MLButtonStyle) -> Color {
        switch style {
        case .primary, .pink: return .white
        case .secondary:      return Color(hex: "7248E0")
        case .coin:           return Color(hex: "3a2400")
        }
    }

    private func buttonBG(_ style: MLButtonStyle) -> LinearGradient {
        switch style {
        case .primary:   return LinearGradient(colors: [Color(hex: "9670F0"), Color(hex: "7248E0")], startPoint: .top, endPoint: .bottom)
        case .secondary: return LinearGradient(colors: [Color(hex: "EDE8FF"), Color(hex: "E0D8F7")], startPoint: .top, endPoint: .bottom)
        case .pink:      return LinearGradient(colors: [Color(hex: "ff9fbd"), Color(hex: "ff7fa6")], startPoint: .top, endPoint: .bottom)
        case .coin:      return LinearGradient(colors: [Color(hex: "ffe28a"), Color(hex: "ffc85b")], startPoint: .top, endPoint: .bottom)
        }
    }
}
