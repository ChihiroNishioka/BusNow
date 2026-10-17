import Foundation
import BusNowCore

enum BoardRoute: Hashable {
    case fujimidai
    case mizonokuchi
}

enum PreviewScenario: String {
    case home
    case approach
    case approachPartial
    case approachEmpty
    case approachDown
    case approachFailed
    case departures
    case departuresFinished
    case departuresDown

    init?(argument: String) {
        switch argument {
        case "home": self = .home
        case "approach": self = .approach
        case "approach-partial": self = .approachPartial
        case "approach-empty": self = .approachEmpty
        case "approach-down": self = .approachDown
        case "approach-failed": self = .approachFailed
        case "departures": self = .departures
        case "departures-finished": self = .departuresFinished
        case "departures-down": self = .departuresDown
        default: return nil
        }
    }
}

struct LaunchConfig {
    var scenario: PreviewScenario?
    var start: BoardRoute?

    static func current(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> LaunchConfig {
        LaunchConfig(scenario: value("busnow-scenario", arguments).flatMap(PreviewScenario.init(argument:)),
                     start: startRoute(value("busnow-start", arguments)))
    }

    private static func value(_ name: String, _ arguments: [String]) -> String? {
        let flag = "-\(name)"
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func startRoute(_ raw: String?) -> BoardRoute? {
        switch raw {
        case "approach": return .fujimidai
        case "departures": return .mizonokuchi
        default: return nil
        }
    }
}

final class BusServices {
    let client: HTTPClient
    let clock: any BusClock
    let fetchCache: TimetableFetchCache
    let store: BoardCache
    let scenario: PreviewScenario?
    let fixedNow: Date?
    let start: BoardRoute?

    init(
        client: HTTPClient,
        clock: any BusClock,
        fetchCache: TimetableFetchCache,
        store: BoardCache,
        scenario: PreviewScenario?,
        fixedNow: Date?,
        start: BoardRoute?
    ) {
        self.client = client
        self.clock = clock
        self.fetchCache = fetchCache
        self.store = store
        self.scenario = scenario
        self.fixedNow = fixedNow
        self.start = start
    }

    static func make() -> BusServices {
        let launch = LaunchConfig.current()
        if launch.scenario != nil {
            let now = ISO8601Clock.parse("2026-10-17T01:30:00Z") ?? Date()
            return BusServices(
                client: HTTPClient { _ in throw BusTransportError("preview") },
                clock: FixedClock(now),
                fetchCache: TimetableFetchCache(),
                store: .memory(),
                scenario: launch.scenario,
                fixedNow: now,
                start: launch.start
            )
        }
        return BusServices(
            client: HTTP.sessionClient(),
            clock: SystemClock(),
            fetchCache: TimetableFetchCache(),
            store: .appSupport(),
            scenario: nil,
            fixedNow: nil,
            start: launch.start
        )
    }

    var approachLoader: ApproachBoardLoader {
        ApproachBoardLoader(client: client, clock: clock)
    }

    var departureLoader: DepartureBoardLoader {
        DepartureBoardLoader(client: client, clock: clock, cache: fetchCache, store: store)
    }
}
