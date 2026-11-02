import Foundation
import BusNowCore
import WatchKit
import WidgetKit

@MainActor
enum WatchRefresh {
    static let taskID = "app.busnow.board-refresh"

    static func perform() async {
        let services = BusServices.make(store: SharedBoard.cache())
        guard services.scenario == nil else { return }
        let now = services.clock.now()
        let facing = FacingChoice.resolve(mode: SharedBoard.facingMode(), now: now)
        let client = HTTP.backgroundClient()
        if facing == .fujimidai {
            if let payload = try? await ApproachBoardLoader(client: client, clock: services.clock).load(),
               payload.sources.contains(where: \.ok) {
                services.store.saveApproach(payload)
            }
        } else if let payload = try? await DepartureBoardLoader(
            client: client,
            clock: services.clock,
            cache: services.fetchCache,
            store: services.store
        ).load(useCache: true) {
            services.store.saveDepartures(payload)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: ComplicationBoard.kind)
        schedule()
    }

    static func schedule() {
        let when = Date().addingTimeInterval(ComplicationBoard.reloadInterval)
        WKApplication.shared().scheduleBackgroundRefresh(withPreferredDate: when, userInfo: nil) { _ in }
    }
}
