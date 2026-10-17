import Foundation

public struct ApproachRow: Equatable, Sendable {
    public var bus: ApproachBus
    public var countdown: Countdown

    public init(bus: ApproachBus, countdown: Countdown) {
        self.bus = bus
        self.countdown = countdown
    }
}

public struct ApproachPresentation: Equatable, Sendable {
    public var rows: [ApproachRow]
    public var hero: String?
    public var freshnessNote: String?
    public var basis: String?

    public init(rows: [ApproachRow], hero: String?, freshnessNote: String?, basis: String?) {
        self.rows = rows
        self.hero = hero
        self.freshnessNote = freshnessNote
        self.basis = basis
    }
}

public struct DeparturePresentation: Equatable, Sendable {
    public var departures: [Departure]
    public var finishedBanner: Bool
    public var hero: String?

    public init(departures: [Departure], finishedBanner: Bool, hero: String?) {
        self.departures = departures
        self.finishedBanner = finishedBanner
        self.hero = hero
    }
}

public enum BoardPresentation {
    public static let approachStaleAfter: TimeInterval = 5 * 60

    public static func approach(_ payload: ApproachPayload, now: Date) -> ApproachPresentation {
        let age = now.timeIntervalSince(payload.fetchedAt)
        let basis = CountdownMath.basisCaption(payload.sources)
        if age > approachStaleAfter {
            return ApproachPresentation(rows: [], hero: nil, freshnessNote: BoardCopy.staleHidden, basis: basis)
        }
        let freshness = age >= 60 ? BoardCopy.minutesAgo(Int(age / 60)) : nil
        let rows = visibleApproachRows(payload.buses, now: now)
        let bothFailed = !payload.sources.isEmpty && payload.sources.allSatisfy { !$0.ok }
        let hero: String?
        if bothFailed || !rows.isEmpty {
            hero = nil
        } else {
            hero = BoardCopy.approachEmpty
        }
        return ApproachPresentation(rows: rows, hero: hero, freshnessNote: freshness, basis: basis)
    }

    public static func departures(_ payload: DeparturePayload) -> DeparturePresentation {
        if payload.departures.isEmpty {
            let bothFailed = !payload.sources.isEmpty && payload.sources.allSatisfy { !$0.ok }
            return DeparturePresentation(
                departures: [],
                finishedBanner: false,
                hero: bothFailed ? BoardCopy.departuresFailed : BoardCopy.noMoreDepartures
            )
        }
        return DeparturePresentation(
            departures: payload.departures,
            finishedBanner: payload.serviceFinishedToday,
            hero: nil
        )
    }

    public static func visibleApproachRows(_ buses: [ApproachBus], now: Date) -> [ApproachRow] {
        buses.compactMap { bus in
            let countdown = displayCountdown(bus, now: now)
            if countdown == .past { return nil }
            return ApproachRow(bus: bus, countdown: countdown)
        }
        .sorted { lhs, rhs in
            let left = rank(lhs.countdown)
            let right = rank(rhs.countdown)
            if left != right { return left < right }
            let order = compareJapanese(lhs.bus.route, rhs.bus.route)
            if order != .orderedSame { return order == .orderedAscending }
            return lhs.bus.id < rhs.bus.id
        }
    }

    public static func displayCountdown(_ bus: ApproachBus, now: Date) -> Countdown {
        if let arrivesAt = bus.arrivesAt {
            return CountdownMath.countdown(arrivesAt: arrivesAt, now: now)
        }
        if bus.minutes == 0 { return .soon }
        if let minutes = bus.minutes { return .minutes(minutes) }
        return .unknown
    }

    private static func rank(_ countdown: Countdown) -> Int {
        switch countdown {
        case .soon: return 0
        case .minutes(let minutes): return minutes
        case .unknown: return 10_000
        case .past: return 10_001
        }
    }
}

public enum ReadableError {
    public static func message(for error: Error) -> String {
        let raw: String
        if let transport = error as? BusTransportError {
            raw = transport.message
        } else {
            raw = String(describing: error)
        }
        if containsMatch(raw, pattern: "timeout|timed out|abort", caseInsensitive: true) {
            return "公式ページが時間内に応答しませんでした"
        }
        if raw.hasPrefix("HTTP ") {
            return "公式ページから取れませんでした"
        }
        if !raw.isEmpty && raw.count <= 80 {
            return raw
        }
        return BoardCopy.departuresFailed
    }
}

public struct BusTransportError: Error, Equatable, CustomStringConvertible {
    public var message: String
    public init(_ message: String) { self.message = message }
    public var description: String { message }
}
