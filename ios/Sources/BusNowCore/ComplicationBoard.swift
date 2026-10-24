import Foundation

public struct ComplicationContent: Equatable, Sendable {
    public var facing: BoardFacing
    public var headline: String
    public var detail: String
    public var showsTimer: Bool
    public var arrivesAt: Date?
    public var freshness: String
    public var stale: Bool
    public var timetableUnverified: Bool
    public var accessibilityLabel: String

    public init(
        facing: BoardFacing,
        headline: String,
        detail: String,
        showsTimer: Bool,
        arrivesAt: Date?,
        freshness: String,
        stale: Bool,
        timetableUnverified: Bool,
        accessibilityLabel: String
    ) {
        self.facing = facing
        self.headline = headline
        self.detail = detail
        self.showsTimer = showsTimer
        self.arrivesAt = arrivesAt
        self.freshness = freshness
        self.stale = stale
        self.timetableUnverified = timetableUnverified
        self.accessibilityLabel = accessibilityLabel
    }
}

public enum ComplicationBoard {
    public static let kind = "app.busnow.board"
    /// About 48 requests a day, inside WidgetKit's roughly 40–70 budget.
    public static let reloadInterval: TimeInterval = 30 * 60
    public static let minimumEntrySpacing: TimeInterval = 5 * 60

    public struct Moment: Equatable, Sendable {
        public var date: Date
        public var content: ComplicationContent

        public init(date: Date, content: ComplicationContent) {
            self.date = date
            self.content = content
        }
    }

    public static func placeholder(now: Date) -> ComplicationContent {
        let facing = FacingChoice.resolve(mode: .automatic, now: now)
        return ComplicationContent(
            facing: facing,
            headline: "次のバス",
            detail: "取得中",
            showsTimer: false,
            arrivesAt: nil,
            freshness: "取得中",
            stale: false,
            timetableUnverified: false,
            accessibilityLabel: "次のバス。取得中"
        )
    }

    public static func content(
        facing: BoardFacing,
        approach: ApproachPayload?,
        departures: DeparturePayload?,
        now: Date
    ) -> ComplicationContent {
        switch facing {
        case .fujimidai:
            return approachContent(approach, now: now)
        case .mizonokuchi:
            return departureContent(departures, now: now)
        }
    }

    public static func timeline(
        facing: BoardFacing,
        approach: ApproachPayload?,
        departures: DeparturePayload?,
        now: Date
    ) -> [Moment] {
        var moments = [Moment(date: now, content: content(facing: facing, approach: approach, departures: departures, now: now))]
        switch facing {
        case .fujimidai:
            guard let fetchedAt = approach?.fetchedAt else { return moments }
            let staleAt = fetchedAt.addingTimeInterval(BoardPresentation.approachStaleAfter)
            let earliest = now.addingTimeInterval(minimumEntrySpacing)
            let when = staleAt >= earliest ? staleAt : earliest
            if when > now {
                moments.append(Moment(date: when, content: content(facing: facing, approach: approach, departures: departures, now: when)))
            }
        case .mizonokuchi:
            guard let departures else { return moments }
            var last = now
            for departure in departures.departures {
                guard let when = instant(of: departure), when.timeIntervalSince(last) >= minimumEntrySpacing else { continue }
                moments.append(Moment(date: when, content: content(facing: facing, approach: approach, departures: departures, now: when)))
                last = when
                if moments.count >= 8 { break }
            }
        }
        return moments
    }

    /// Frozen stand-in for `Text(date, style: .timer)` when the device clock is not the fetch clock.
    public static func timerText(arrivesAt: Date, now: Date) -> String {
        let remaining = arrivesAt.timeIntervalSince(now)
        if remaining <= 0 || remaining.isNaN { return "0:00" }
        let whole = Int(remaining.rounded(.down))
        let minutes = whole / 60
        let seconds = whole % 60
        if minutes >= 60 {
            return String(format: "%d:%02d:%02d", minutes / 60, minutes % 60, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    public static func freshness(fetchedAt: Date, now: Date) -> String {
        let clock = "取得 \(TokyoCalendar.formatClock(fetchedAt))"
        let age = now.timeIntervalSince(fetchedAt)
        if age > BoardPresentation.approachStaleAfter {
            return "古い情報 · \(clock)"
        }
        if age >= 60 {
            return "\(clock) · \(BoardCopy.minutesAgo(Int(age / 60)))"
        }
        return clock
    }

    private static func approachContent(_ payload: ApproachPayload?, now: Date) -> ComplicationContent {
        guard let payload else {
            return failed(.fujimidai, freshness: "取得できていません")
        }
        let freshness = freshness(fetchedAt: payload.fetchedAt, now: now)
        if now.timeIntervalSince(payload.fetchedAt) > BoardPresentation.approachStaleAfter {
            return ComplicationContent(
                facing: .fujimidai,
                headline: "古い",
                detail: BoardCopy.staleHidden,
                showsTimer: false,
                arrivesAt: nil,
                freshness: freshness,
                stale: true,
                timetableUnverified: false,
                accessibilityLabel: "\(BoardCopy.staleHidden)。\(freshness)"
            )
        }
        let bothFailed = !payload.sources.isEmpty && payload.sources.allSatisfy { !$0.ok }
        let rows = BoardPresentation.visibleApproachRows(payload.buses, now: now)
        if bothFailed && rows.isEmpty {
            return failed(.fujimidai, freshness: freshness)
        }
        guard let row = rows.first else {
            return ComplicationContent(
                facing: .fujimidai,
                headline: "なし",
                detail: BoardCopy.approachEmpty,
                showsTimer: false,
                arrivesAt: nil,
                freshness: freshness,
                stale: false,
                timetableUnverified: false,
                accessibilityLabel: "\(BoardCopy.approachEmpty)。\(freshness)"
            )
        }
        let bus = row.bus
        switch row.countdown {
        case .soon, .past:
            return ComplicationContent(
                facing: .fujimidai,
                headline: bus.route,
                detail: "まもなく",
                showsTimer: false,
                arrivesAt: bus.arrivesAt,
                freshness: freshness,
                stale: false,
                timetableUnverified: false,
                accessibilityLabel: "\(approachRowAccessibilityLabel(bus, countdown: row.countdown))。\(freshness)"
            )
        case .minutes, .unknown:
            let showsTimer = bus.arrivesAt != nil && row.countdown != .unknown
            return ComplicationContent(
                facing: .fujimidai,
                headline: bus.route,
                detail: showsTimer ? "あと" : bus.status,
                showsTimer: showsTimer,
                arrivesAt: showsTimer ? bus.arrivesAt : nil,
                freshness: freshness,
                stale: false,
                timetableUnverified: false,
                accessibilityLabel: "\(approachRowAccessibilityLabel(bus, countdown: row.countdown))。\(freshness)"
            )
        }
    }

    private static func departureContent(_ payload: DeparturePayload?, now: Date) -> ComplicationContent {
        guard let payload else {
            return failed(.mizonokuchi, freshness: "取得できていません")
        }
        var freshness = freshness(fetchedAt: payload.fetchedAt, now: now)
        let unverified = payload.sources.contains { source in
            guard let message = source.message else { return false }
            return message.contains("確認できていません") || message.contains("異なる可能性")
        }
        if unverified {
            freshness += " · ダイヤ未確認"
        }
        let upcoming = payload.departures.filter { departure in
            guard let when = instant(of: departure) else { return true }
            return when.timeIntervalSince(now) > -60
        }
        guard let next = upcoming.first else {
            let headline = payload.serviceFinishedToday ? "終了" : "なし"
            let detail = payload.serviceFinishedToday ? BoardCopy.serviceFinished : BoardCopy.noMoreDepartures
            return ComplicationContent(
                facing: .mizonokuchi,
                headline: headline,
                detail: detail,
                showsTimer: false,
                arrivesAt: nil,
                freshness: freshness,
                stale: false,
                timetableUnverified: unverified,
                accessibilityLabel: "\(detail)。\(freshness)"
            )
        }
        return ComplicationContent(
            facing: .mizonokuchi,
            headline: next.time,
            detail: "\(next.route) \(next.destination)",
            showsTimer: false,
            arrivesAt: nil,
            freshness: freshness,
            stale: false,
            timetableUnverified: unverified,
            accessibilityLabel: "\(departureAccessibilityLabel(next))。\(freshness)"
        )
    }

    private static func failed(_ facing: BoardFacing, freshness: String) -> ComplicationContent {
        ComplicationContent(
            facing: facing,
            headline: "失敗",
            detail: BoardCopy.departuresFailed,
            showsTimer: false,
            arrivesAt: nil,
            freshness: freshness,
            stale: false,
            timetableUnverified: false,
            accessibilityLabel: "\(BoardCopy.departuresFailed)。\(freshness)"
        )
    }

    private static func instant(of departure: Departure) -> Date? {
        let parts = departure.time.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        return TokyoCalendar.date(ymd: departure.date, hour: hour, minute: minute)
    }
}
