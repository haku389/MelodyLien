import SwiftUI

struct MelodyView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                screenTitle
                if vm.encounters.isEmpty {
                    emptyState
                } else {
                    encounterProgress
                    if let enc = vm.activeEncounter {
                        candidateCarousel(encounter: enc)
                        carouselNav(encounter: enc)
                        actionButtons(encounter: enc)
                    }
                    encounterList
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 112)
        }
        .scrollIndicators(.hidden)
        .background(Color(hex: "F5F0FF").ignoresSafeArea())
    }

    // MARK: - Screen title

    private var screenTitle: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("メロディ")
                    .font(.system(size: 20, weight: .black)).foregroundStyle(.primary)
                Text("ピースを選んでパズルを完成させよう")
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            }
            Spacer()
        }
        .padding(.bottom, 18)
    }

    // MARK: - Encounter progress bar

    private var encounterProgress: some View {
        let total = vm.encounters.count
        let idx   = vm.activeEncounterIndex
        let enc   = vm.encounters[safe: idx]

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(idx + 1) / \(total) 件目の出会い")
                    .font(.system(size: 10, weight: .black)).foregroundStyle(Color(hex: "7248E0"))
                Spacer()
                HStack(spacing: 4) {
                    ForEach(0..<total, id: \.self) { i in
                        let done = vm.encounterCooldowns[vm.encounters[i].id] != nil
                        RoundedRectangle(cornerRadius: 3)
                            .fill(done ? Color(hex: "1A9E6E") : (i == idx ? Color(hex: "7248E0") : Color(hex: "7248E0").opacity(0.2)))
                            .frame(width: i == idx ? 18 : 8, height: 6)
                            .animation(.spring(duration: 0.3), value: idx)
                    }
                }
            }

            if let enc = enc {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(hex: "7248E0"))
                        .frame(width: 36, height: 36)
                        .overlay(Text("\(idx + 1)").font(.system(size: 13, weight: .black)).foregroundStyle(.white))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(enc.fromUserName) さん")
                            .font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
                        Text("📍 \(enc.locationLabel) · \(enc.candidates.count)曲")
                            .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                    }
                    Spacer()

                    if vm.friends.contains(where: { $0.userId == enc.fromUserId }) {
                        Text("🎵 フレンド")
                            .font(.system(size: 10, weight: .black)).foregroundStyle(Color(hex: "7248E0"))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color(hex: "7248E0").opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                }

                let cooldown = vm.cooldownRemaining(for: enc.id)
                if cooldown > 0 {
                    HStack(spacing: 8) {
                        Text("⏳").font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(enc.fromUserName) さんとのクールタイム中")
                                .font(.system(size: 11, weight: .black)).foregroundStyle(.primary)
                            Text("あと \(vm.formatCooldown(cooldown)) で再度受信できます")
                                .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                        }
                    }
                    .padding(10)
                    .background(Color(hex: "7248E0").opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "7248E0").opacity(0.25)))
                } else {
                    Text("パズルを選んで「このパズルにする」を押してください")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color(hex: "7B6F8A"))
                        .multilineTextAlignment(.center)
                }

                if total > 1 {
                    HStack(spacing: 8) {
                        Button {
                            if vm.activeEncounterIndex > 0 {
                                vm.activeEncounterIndex -= 1
                                vm.selectedCandidateIndex = nil
                                vm.carouselIndex = 0
                            }
                        } label: {
                            Label("前の出会い", systemImage: "chevron.left")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(vm.activeEncounterIndex > 0 ? Color(hex: "7248E0") : Color(hex: "B8ACD6"))
                        }
                        .disabled(vm.activeEncounterIndex <= 0)
                        Spacer()
                        Button {
                            if vm.activeEncounterIndex < vm.encounters.count - 1 {
                                vm.activeEncounterIndex += 1
                                vm.selectedCandidateIndex = nil
                                vm.carouselIndex = 0
                            }
                        } label: {
                            Label("次の出会い", systemImage: "chevron.right")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(vm.activeEncounterIndex < vm.encounters.count - 1 ? Color(hex: "7248E0") : Color(hex: "B8ACD6"))
                                .environment(\.layoutDirection, .rightToLeft)
                        }
                        .disabled(vm.activeEncounterIndex >= vm.encounters.count - 1)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(14)
        .background(Color(hex: "7248E0").opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "7248E0").opacity(0.15)))
        .padding(.bottom, 14)
    }

    // MARK: - Carousel

    private func candidateCarousel(encounter: Encounter) -> some View {
        let candidates = encounter.candidates
        let idx = max(0, min(vm.carouselIndex, candidates.count - 1))

        return VStack(spacing: 0) {
            if candidates.indices.contains(idx) {
                let candidate = candidates[idx]
                mainCarouselCard(candidate: candidate, track: vm.track(for: candidate.trackId))
            }
        }
        .padding(.bottom, 4)
    }

    private func mainCarouselCard(candidate: Candidate, track: Track?) -> some View {
        // フル表示＝全ピース表示（未解放はモザイク）／ピース確認＝所持ピースのみ表示
        let isFull = vm.carouselViewMode == "mosaic"
        let unlocked = track?.isUnlocked ?? false

        return VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                PuzzlePiecesView(thumbnailURL: track?.thumbnailURL,
                                 ownedPieces: track?.ownedPieces ?? [],
                                 color: track?.color ?? "violet",
                                 cornerRadius: 18,
                                 revealAll: isFull,
                                 blur: isFull && !unlocked)
                    .overlay(alignment: .bottomTrailing) {
                        Text("\(track?.ownedPieces.count ?? 0) / \(track?.pieceCount ?? 24)")
                            .font(.system(size: 10, weight: .black)).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(.black.opacity(0.45), in: Capsule())
                            .padding(8)
                    }
                    .shadow(color: Color(hex: "7248E0").opacity(0.15), radius: 16, y: 8)

                Button {
                    vm.carouselViewMode = vm.carouselViewMode == "pieces" ? "mosaic" : "pieces"
                } label: {
                    Text(vm.carouselViewMode == "pieces" ? "🎵 フル表示" : "🧩 ピース確認")
                        .font(.system(size: 9, weight: .black)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(.black.opacity(0.45), in: Capsule())
                }
                .padding(8)
            }

            VStack(spacing: 4) {
                Text("\(candidate.sourceSlot) · \(String(repeating: "★", count: min(candidate.rarity, 5)))")
                    .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                Text(track?.displayArtist ?? "—")
                    .font(.system(size: 15, weight: .black)).foregroundStyle(.primary)
                Text(track?.displayTitle ?? "—")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Color(hex: "7248E0"))
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Carousel nav

    private func carouselNav(encounter: Encounter) -> some View {
        let candidates = encounter.candidates
        let idx = max(0, min(vm.carouselIndex, candidates.count - 1))
        return HStack(spacing: 16) {
            Button {
                if vm.carouselIndex > 0 {
                    vm.carouselIndex -= 1
                    vm.selectedCandidateIndex = nil
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(vm.carouselIndex > 0 ? Color(hex: "7248E0") : Color(hex: "B8ACD6"))
                    .frame(width: 40, height: 40)
                    .background(Color(hex: "EDE8FF"), in: Circle())
                    .overlay(Circle().stroke(Color(hex: "E0D8F7")))
            }
            .disabled(vm.carouselIndex <= 0)

            Text("\(idx + 1) / \(candidates.count)")
                .font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))

            Button {
                if vm.carouselIndex < candidates.count - 1 {
                    vm.carouselIndex += 1
                    vm.selectedCandidateIndex = nil
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(vm.carouselIndex < candidates.count - 1 ? Color(hex: "7248E0") : Color(hex: "B8ACD6"))
                    .frame(width: 40, height: 40)
                    .background(Color(hex: "EDE8FF"), in: Circle())
                    .overlay(Circle().stroke(Color(hex: "E0D8F7")))
            }
            .disabled(vm.carouselIndex >= candidates.count - 1)
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    // MARK: - Action buttons

    private func actionButtons(encounter: Encounter) -> some View {
        let candidates = encounter.candidates
        let idx = max(0, min(vm.carouselIndex, candidates.count - 1))
        let onCooldown = vm.cooldownRemaining(for: encounter.id) > 0

        let candTrackId = candidates[safe: idx]?.trackId
        let previewLeft = candTrackId.map { vm.previewPlaysLeft(trackId: $0) } ?? 0
        let canPreview = candTrackId.map { vm.canPreview(trackId: $0) } ?? false

        return VStack(spacing: 10) {
            if let tid = candTrackId, vm.track(for: tid)?.hasYouTubeVideo == true {
                Button { vm.startPreview(trackId: tid) } label: {
                    Text(previewLeft > 0 ? "▶ 少し聴く（あと\(previewLeft)回）" : "本日の試聴回数を使い切りました")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(canPreview ? .white : Color(hex: "B8ACD6"))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(
                            canPreview
                                ? LinearGradient(colors: [Color(hex: "79C7FF"), Color(hex: "5BA8F5")], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [Color(hex: "EDE8FF"), Color(hex: "EDE8FF")], startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canPreview)
            }

            Button {
                if !onCooldown {
                    vm.selectedCandidateIndex = idx
                    vm.navigate(to: .pieceSelect(encounterId: encounter.id, candidateIndex: idx))
                }
            } label: {
                Text(onCooldown ? "クールタイム中" : "このパズルにする")
                    .font(.system(size: 16, weight: .black)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(
                        onCooldown
                            ? LinearGradient(colors: [Color(hex: "B8ACD6"), Color(hex: "B8ACD6")], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [Color(hex: "9670F0"), Color(hex: "7248E0")], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 20)
                    )
            }
            .disabled(onCooldown)
            .buttonStyle(.plain)

            Button { vm.activeTab = .home } label: {
                Text("あとで選ぶ")
                    .font(.system(size: 14, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color(hex: "EDE8FF"), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "E0D8F7")))
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 24)
    }

    // MARK: - Encounter list

    private var encounterList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今日の出会い")
                    .font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
                Text("\(vm.encounters.count)件")
                    .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                Spacer()
            }
            .padding(.bottom, 4)

            ForEach(Array(vm.encounters.enumerated()), id: \.element.id) { i, enc in
                let isActive = i == vm.activeEncounterIndex
                let onCooldown = vm.cooldownRemaining(for: enc.id) > 0
                let isLocked = !onCooldown && !isActive && i > vm.activeEncounterIndex
                let isFriend = vm.friends.contains { $0.userId == enc.fromUserId }

                Button {
                    if !isLocked {
                        vm.activeEncounterIndex = i
                        vm.carouselIndex = 0
                        vm.selectedCandidateIndex = nil
                    }
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(onCooldown ? Color(hex: "1A9E6E").opacity(0.15)
                                  : isActive ? Color(hex: "7248E0")
                                  : Color(hex: "7248E0").opacity(0.12))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Group {
                                    if onCooldown {
                                        Text("✓").font(.system(size: 14, weight: .black))
                                            .foregroundStyle(Color(hex: "1A9E6E"))
                                    } else if isLocked {
                                        Text("🔒").font(.system(size: 14))
                                    } else {
                                        Text("\(i + 1)").font(.system(size: 14, weight: .black))
                                            .foregroundStyle(isActive ? .white : Color(hex: "7248E0"))
                                    }
                                }
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(enc.fromUserName)\(isFriend ? " 🎵" : "")")
                                .font(.system(size: 12, weight: .black)).foregroundStyle(.primary)
                                .lineLimit(1)
                            Text("📍 \(enc.locationLabel) · \(enc.candidates.count)曲")
                                .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                        }

                        Spacer()

                        if onCooldown {
                            let remaining = vm.cooldownRemaining(for: enc.id)
                            Text("済 · あと\(vm.formatCooldown(remaining))")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(Color(hex: "1A9E6E"))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color(hex: "1A9E6E").opacity(0.1), in: Capsule())
                        } else if isActive {
                            Text("→ 今ここ")
                                .font(.system(size: 9, weight: .heavy)).foregroundStyle(Color(hex: "7248E0"))
                        } else if isLocked {
                            Text("順番待ち")
                                .font(.system(size: 9, weight: .heavy)).foregroundStyle(Color(hex: "B8ACD6"))
                        } else {
                            Text("受信可")
                                .font(.system(size: 9, weight: .heavy)).foregroundStyle(Color(hex: "1A9E6E"))
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(isActive ? Color(hex: "7248E0").opacity(0.06) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(isActive ? Color(hex: "7248E0") : Color(hex: "E0D8F7"),
                                lineWidth: isActive ? 2 : 1))
                    .opacity(isLocked ? 0.45 : 1)
                }
                .buttonStyle(.plain)
                .disabled(isLocked)
            }
        }
        .padding(16).mlCard()
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("🎵").font(.system(size: 48))
            Text("まだ出会いがありません")
                .font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
            Text("外出してすれちがいを待ちましょう")
                .font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Safe subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
