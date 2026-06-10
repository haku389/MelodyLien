import SwiftUI

struct MysteryView: View {
    let trackId: String
    @EnvironmentObject var vm: AppViewModel
    @State private var showAdModal = false
    @State private var pendingHint: HintKind = .hint1
    @State private var guessText = ""
    @State private var showGuessField = false

    private var track: Track? { vm.track(for: trackId) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                screenHeader
                if let t = track {
                    mysteryHero(track: t)
                    actionBlock(track: t)
                    if t.hintLevel >= 2, !t.choices.isEmpty {
                        choiceGrid(choices: t.choices)
                    }
                    youtubePanel(track: t)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 112)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showAdModal) {
            AdConfirmModal(kind: pendingHint) {
                Task { await vm.applyHint(trackId: trackId, kind: pendingHint) }
            }
        }
    }

    // MARK: - Header

    private var screenHeader: some View {
        HStack(spacing: 12) {
            Button { vm.goBack() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .heavy))
                    .frame(width: 42, height: 42)
                    .background(.regularMaterial, in: Circle())
            }
            VStack(spacing: 2) {
                Text("未解放メロディ").font(.system(size: 15, weight: .black))
                Text("ヒントを使ってこの曲の名前を当てよう！")
                    .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "817992"))
            }
            .frame(maxWidth: .infinity)
            Button { vm.goBack() } label: {
                Text("あとで確認")
                    .font(.system(size: 11, weight: .heavy))
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(.regularMaterial, in: Capsule())
            }
        }
        .padding(.bottom, 18)
    }

    // MARK: - Mystery hero

    private func mysteryHero(track: Track) -> some View {
        VStack(spacing: 10) {
            ZStack {
                ArtBlockView(color: track.color, cornerRadius: 26)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: min(240, UIScreen.main.bounds.width * 0.74))
                // Lock
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white.opacity(0.93))
                    .frame(width: 62, height: 62)
                    .shadow(radius: 8, y: 4)
                    .overlay(Text("🔒").font(.system(size: 28)))
                // Play button
                VStack {
                    Spacer()
                    Button {
                        // TODO: 試聴
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(Color(hex: "8f6df4"))
                            .frame(width: 50, height: 50)
                            .background(Color.white, in: Circle())
                            .shadow(radius: 8, y: 4)
                    }
                    .padding(.bottom, 12)
                }
                .frame(width: min(240, UIScreen.main.bounds.width * 0.74))
            }
            Text(maskedDisplay(track: track))
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .multilineTextAlignment(.center)
            Text("未解放メロディ")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Color(hex: "817992"))
        }
        .padding(.bottom, 16)
    }

    // MARK: - Action block

    private func actionBlock(track: Track) -> some View {
        VStack(spacing: 10) {
            Button { showGuessField = true } label: {
                Text("曲名を当てる")
                    .buttonLabel(.pink)
            }
            Button { pendingHint = .hint1; showAdModal = true } label: {
                Text("1つ目のヒントを見る  🎫×1")
                    .buttonLabel(.secondary)
            }
            Button { pendingHint = .hint2; showAdModal = true } label: {
                Text("2つ目のヒントを見る  🎫×1")
                    .buttonLabel(.secondary)
            }
            Button { pendingHint = .answer; showAdModal = true } label: {
                Text("答えを見る  CM×1")
                    .buttonLabel(.coin)
            }
        }
        .padding(16)
        .mlCard()
        .padding(.bottom, 14)
    }

    // MARK: - 4択ヒント

    private func choiceGrid(choices: [String]) -> some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
            ForEach(choices, id: \.self) { choice in
                Button(choice) {}
                    .font(.system(size: 13, weight: .heavy))
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 15))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color(hex: "eadff3")))
            }
        }
        .padding(16)
        .mlCard()
        .padding(.bottom, 14)
    }

    // MARK: - YouTube panel

    private func youtubePanel(track: Track) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.red)
                .frame(width: 48, height: 48)
                .overlay(Image(systemName: "play.fill").foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 4) {
                Text("YouTubeで見て確認")
                    .font(.system(size: 13, weight: .black)).lineLimit(1)
                Text(track.answerReady ? "曲名とアーティスト名を解放します" : "公式MVまたは公式リリックビデオを確認")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Color(hex: "817992")).lineLimit(1)
            }
            Spacer()
            if track.answerReady {
                Button { Task { await vm.unlockTrack(trackId: trackId) } } label: {
                    Text("確認する").buttonLabel(.primary, small: true)
                }
            } else {
                Button { pendingHint = .answer; showAdModal = true } label: {
                    Text("CM").buttonLabel(.coin, small: true)
                }
            }
        }
        .padding(14)
        .mlCard()
    }

    // MARK: - Helpers

    private func maskedDisplay(track: Track) -> String {
        if track.isUnlocked { return "\(track.artistName ?? "") / \(track.title ?? "")" }
        guard let masked = track.maskedLabel else { return "★★★★★★★★" }
        return masked.split(separator: "/").map { part in
            String(part).trimmingCharacters(in: .whitespaces)
                        .map { c in c == "○" ? "○" : (c.isLetter || c.isNumber ? "★" : String(c)) }
                        .joined()
        }.joined(separator: " / ")
    }
}

// MARK: - Button label style

enum ButtonStyle { case primary, secondary, pink, coin }

extension View {
    func buttonLabel(_ style: ButtonStyle, small: Bool = false) -> some View {
        self
            .font(.system(size: small ? 11 : 12, weight: .black))
            .foregroundStyle(style == .primary || style == .pink ? Color.white : Color(hex: "302944"))
            .frame(maxWidth: small ? nil : .infinity, minHeight: small ? 32 : 40)
            .padding(.horizontal, small ? 10 : 14)
            .background(buttonBG(style), in: RoundedRectangle(cornerRadius: small ? 13 : 16))
    }

    private func buttonBG(_ style: ButtonStyle) -> LinearGradient {
        switch style {
        case .primary:   return LinearGradient(colors: [Color(hex: "b79cff"), Color(hex: "8f6df4")], startPoint: .top, endPoint: .bottom)
        case .secondary: return LinearGradient(colors: [.white, Color(hex: "fff4ef")], startPoint: .top, endPoint: .bottom)
        case .pink:      return LinearGradient(colors: [Color(hex: "ff9fbd"), Color(hex: "ff7fa6")], startPoint: .top, endPoint: .bottom)
        case .coin:      return LinearGradient(colors: [Color(hex: "ffe28a"), Color(hex: "ffc85b")], startPoint: .top, endPoint: .bottom)
        }
    }
}
