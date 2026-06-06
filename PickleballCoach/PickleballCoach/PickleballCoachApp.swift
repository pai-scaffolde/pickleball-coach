import SwiftUI

@main
struct PickleballCoachApp: App {
    @StateObject private var store = SessionStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
        }
    }
}
