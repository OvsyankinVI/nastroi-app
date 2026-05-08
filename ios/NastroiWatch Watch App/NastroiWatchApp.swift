import SwiftUI
import WatchConnectivity

@main
struct NastroiWatch_Watch_AppApp: App {
    @StateObject private var watchStore = WatchPeopleStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(watchStore)
        }
    }
}
