import SwiftUI

@main
struct BusNowApp: App {
    private let services = BusServices.make()

    var body: some Scene {
        WindowGroup {
            RootView(services: services)
                .preferredColorScheme(.dark)
        }
    }
}
