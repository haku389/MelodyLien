import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            LinearGradient(
                colors: [Color(hex: "fffdfb"), Color(hex: "f9f1ff")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Main content
            Group {
                switch vm.activeTab {
                case .home:
                    NavigationStack(path: $vm.navigationStack) {
                        HomeView()
                            .navigationDestination(for: Screen.self) { screen in
                                screenView(for: screen)
                            }
                    }
                case .exchange:
                    ExchangeView()
                case .puzzle:
                    if let hero = vm.heroTrack {
                        PuzzleView(trackId: hero.id)
                    } else {
                        ProgressView()
                    }
                case .artist:
                    Text("アーティスト画面 (実装予定)")
                case .playlist:
                    Text("プレイリスト画面 (実装予定)")
                }
            }
            .ignoresSafeArea(edges: .bottom)

            // Bottom navigation
            BottomNavBar()

            // Toast
            if let toast = vm.toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 12, weight: .heavy))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.regularMaterial, in: Capsule())
                        .shadow(radius: 8, y: 4)
                        .padding(.bottom, 90)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(), value: toast)
            }
        }
    }

    @ViewBuilder
    private func screenView(for screen: Screen) -> some View {
        switch screen {
        case .home:              HomeView()
        case .exchange:          ExchangeView()
        case .mystery(let id):   MysteryView(trackId: id)
        case .puzzle(let id):    PuzzleView(trackId: id)
        case .artist(let id):    Text("アーティスト: \(id)")
        case .playlist:          Text("プレイリスト")
        }
    }
}

// MARK: - Bottom Nav Bar

struct BottomNavBar: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    vm.activeTab = tab
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 9, weight: .heavy))
                    }
                    .foregroundStyle(vm.activeTab == tab ? Color(hex: "8f6df4") : Color(hex: "817992"))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(vm.activeTab == tab ? Color(hex: "f0e9ff") : Color.clear,
                                in: RoundedRectangle(cornerRadius: 17))
                }
            }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(hex: "eadff3")))
        .shadow(color: .black.opacity(0.1), radius: 16, y: 8)
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }
}
