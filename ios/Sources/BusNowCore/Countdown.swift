import Foundation

public enum CountdownMath {
    public static let arrivalGrace: TimeInterval = 60
    public static let twoHours: TimeInterval = 2 * 60 * 60

    /// The operator clock is only HH:MM. Place it on today's Tokyo date, and on
    /// yesterday when that would put the clock more than two hours ahead of now.
    public static func observedInstant(now: Date, clock: String?) -> Date {
        guard let clock, let match = firstMatch(clock, pattern: "^(\\d{1,2}):(\\d{2})$"),
              let hourText = match.groups.dropFirst().first ?? nil,
              let minuteText = match.groups.dropFirst(2).first ?? nil,
              let hour = Int(hourText),
              let minute = Int(minuteText),
              hour <= 23, minute <= 59
        else {
            return now
        }
        let today = TokyoCalendar.parts(now)
        var basis = TokyoCalendar.date(ymd: today.ymd, hour: hour, minute: minute)
        if basis.timeIntervalSince(now) > twoHours {
            basis = TokyoCalendar.date(ymd: TokyoCalendar.addDays(today.ymd, -1), hour: hour, minute: minute)
        }
        return basis
    }

    public static func stamp(_ sightings: [ApproachSighting], observedAt: Date) -> [ApproachBus] {
        sightings.map { bus in
            let arrives = bus.minutes.map { minutes in
                observedAt.addingTimeInterval(TimeInterval(minutes * 60))
            }
            return ApproachBus(
                id: bus.id,
                operatorName: bus.operatorName,
                route: bus.route,
                destination: bus.destination,
                minutes: bus.minutes,
                status: bus.status,
                observedAt: observedAt,
                arrivesAt: arrives
            )
        }
    }

    public static func countdown(arrivesAt: Date?, now: Date, grace: TimeInterval = arrivalGrace) -> Countdown {
        guard let arrivesAt else { return .unknown }
        let remaining = arrivesAt.timeIntervalSince(now)
        if remaining.isNaN { return .unknown }
        if remaining <= -grace { return .past }
        if remaining <= 0 { return .soon }
        return .minutes(Int(ceil(remaining / 60.0)))
    }

    public static func basisCaption(_ sources: [SourceStatus]) -> String? {
        var clocks: [(BusOperator, String)] = []
        var seen = Set<BusOperator>()
        for source in sources {
            guard source.ok, let observedAt = source.observedAt, !seen.contains(source.operatorName) else { continue }
            seen.insert(source.operatorName)
            clocks.append((source.operatorName, TokyoCalendar.formatClock(observedAt)))
        }
        if clocks.isEmpty { return nil }
        var unique: [String] = []
        for (_, clock) in clocks where !unique.contains(clock) {
            unique.append(clock)
        }
        if unique.count == 1 { return "\(unique[0])時点の情報" }
        return clocks.map { "\($0.0.rawValue) \($0.1)時点" }.joined(separator: " · ")
    }
}

public func countdownAccessibilityLabel(_ countdown: Countdown, status: String) -> String {
    switch countdown {
    case .minutes(let minutes):
        return "あと\(minutes)分"
    case .soon:
        return "まもなく到着"
    case .past:
        return "到着済み"
    case .unknown:
        return status
    }
}

public func approachRowAccessibilityLabel(_ bus: ApproachBus, countdown: Countdown) -> String {
    let when = countdownAccessibilityLabel(countdown, status: bus.status)
    return "\(bus.operatorName.rawValue)、\(bus.route)、\(bus.destination)、\(when)"
}

public func departureAccessibilityLabel(_ departure: Departure) -> String {
    "\(departure.time)、\(departure.operatorName.rawValue)、\(departure.route)、\(departure.destination)、\(departure.whenLabel)、\(departure.dayLabel)"
}
