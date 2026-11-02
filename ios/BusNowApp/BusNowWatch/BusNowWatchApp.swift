import SwiftUI
import BusNowCore

@main
struct BusNowWatchApp: App {
    private let services = BusServices.make(store: SharedBoard.cache())

    var body: some Scene {
        WindowGroup {
            WatchRootView(services: services)
        }
        .backgroundTask(.appRefresh(WatchRefresh.taskID)) {
            await WatchRefresh.perform()
        }
    }
}
