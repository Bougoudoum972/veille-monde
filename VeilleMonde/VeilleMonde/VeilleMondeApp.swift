import SwiftUI

@main
struct VeilleMondeApp: App {
    @StateObject private var store = NewsStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await store.refreshIfStale() } }
                }
        }
    }
}
