import SwiftUI

@main
struct RydrApp: App {
    init() {
        WatchDriveSyncManager.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
