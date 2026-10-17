import SwiftUI

struct RootView: View {
    let services: BusServices
    @State private var path: [BoardRoute]

    init(services: BusServices) {
        self.services = services
        _path = State(initialValue: services.start.map { [$0] } ?? [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            TopView(path: $path)
                .navigationDestination(for: BoardRoute.self) { route in
                    switch route {
                    case .fujimidai:
                        ApproachBoardView(services: services)
                    case .mizonokuchi:
                        DepartureBoardView(services: services)
                    }
                }
        }
        .background(Theme.asphalt.ignoresSafeArea())
    }
}
