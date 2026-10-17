import Foundation

public struct UpcomingSelection: Equatable, Sendable {
    public var today: String
    public var serviceFinishedToday: Bool
    public var departures: [Departure]
}

public enum UpcomingSelector {
    public static func select(now: Date, trips: [TimedTrip], limit: Int = 3) -> UpcomingSelection {
        let today = TokyoCalendar.parts(now)
        var chosen: [Departure] = []
        var sawLaterToday = false

        var offset = 0
        while offset < 4 && chosen.count < limit {
            let date = TokyoCalendar.addDays(today.ymd, offset)
            let kind = TokyoCalendar.dayKind(date)
            let sameDay = trips
                .enumerated()
                .filter { $0.element.dayKind == kind }
                .sorted { lhs, rhs in
                    let left = minutes(lhs.element.time)
                    let right = minutes(rhs.element.time)
                    if left != right { return left < right }
                    let order = compareJapanese(lhs.element.route, rhs.element.route)
                    if order != .orderedSame { return order == .orderedAscending }
                    return lhs.offset < rhs.offset
                }
                .map(\.element)
            for trip in sameDay {
                if offset == 0 && minutes(trip.time) < today.minutesOfDay { continue }
                if offset == 0 { sawLaterToday = true }
                chosen.append(
                    Departure(
                        id: "\(date)-\(trip.operatorName.rawValue)-\(trip.route)-\(trip.time)-\(trip.destination)",
                        operatorName: trip.operatorName,
                        route: trip.route,
                        destination: trip.destination,
                        time: trip.time,
                        date: date,
                        dayLabel: DayLabel.text(kind),
                        whenLabel: TokyoCalendar.relativeDayLabel(today: today.ymd, ymd: date)
                    )
                )
                if chosen.count >= limit { break }
            }
            offset += 1
        }

        return UpcomingSelection(
            today: today.ymd,
            serviceFinishedToday: !sawLaterToday,
            departures: chosen
        )
    }

    private static func minutes(_ time: String) -> Int {
        let parts = time.split(separator: ":")
        let hour = Int(parts.first ?? "0") ?? 0
        let minute = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        return hour * 60 + minute
    }
}
