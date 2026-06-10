import SwiftUI

@main
struct MelodyLienApp: App {

    @StateObject private var vm = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .task { await vm.loadAll() }
        }
    }
}
