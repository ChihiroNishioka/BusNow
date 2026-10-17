import Foundation

public enum BusOperator: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case tokyu = "東急バス"
    case kawasaki = "川崎市バス"
}

public struct SourceStatus: Codable, Equatable, Sendable {
    public var operatorName: BusOperator
    public var ok: Bool
    public var message: String?
    public var updatedAt: String?
    public var observedAt: Date?

    public init(
        operatorName: BusOperator,
        ok: Bool,
        message: String?,
        updatedAt: String?,
        observedAt: Date? = nil
    ) {
        self.operatorName = operatorName
        self.ok = ok
        self.message = message
        self.updatedAt = updatedAt
        self.observedAt = observedAt
    }

    enum CodingKeys: String, CodingKey {
        case operatorName = "operator"
        case ok
        case message
        case updatedAt
        case observedAt
    }
}

public struct ApproachSighting: Equatable, Sendable {
    public var id: String
    public var operatorName: BusOperator
    public var route: String
    public var destination: String
    public var minutes: Int?
    public var status: String

    public init(
        id: String,
        operatorName: BusOperator,
        route: String,
        destination: String,
        minutes: Int?,
        status: String
    ) {
        self.id = id
        self.operatorName = operatorName
        self.route = route
        self.destination = destination
        self.minutes = minutes
        self.status = status
    }
}

public struct ApproachBus: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var operatorName: BusOperator
    public var route: String
    public var destination: String
    public var minutes: Int?
    public var status: String
    public var observedAt: Date
    public var arrivesAt: Date?

    public init(
        id: String,
        operatorName: BusOperator,
        route: String,
        destination: String,
        minutes: Int?,
        status: String,
        observedAt: Date,
        arrivesAt: Date?
    ) {
        self.id = id
        self.operatorName = operatorName
        self.route = route
        self.destination = destination
        self.minutes = minutes
        self.status = status
        self.observedAt = observedAt
        self.arrivesAt = arrivesAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case operatorName = "operator"
        case route
        case destination
        case minutes
        case status
        case observedAt
        case arrivesAt
    }
}

public struct ApproachPayload: Codable, Equatable, Sendable {
    public var stop: String
    public var toward: String
    public var fetchedAt: Date
    public var buses: [ApproachBus]
    public var sources: [SourceStatus]

    public init(
        fetchedAt: Date,
        buses: [ApproachBus],
        sources: [SourceStatus],
        stop: String = "富士見台",
        toward: String = "溝の口"
    ) {
        self.stop = stop
        self.toward = toward
        self.fetchedAt = fetchedAt
        self.buses = buses
        self.sources = sources
    }
}

public enum DayKind: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case weekday
    case saturday
    case holiday
}

public enum DayLabel {
    public static func text(_ kind: DayKind) -> String {
        switch kind {
        case .weekday: return "平日"
        case .saturday: return "土曜"
        case .holiday: return "休日"
        }
    }
}

public struct Departure: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var operatorName: BusOperator
    public var route: String
    public var destination: String
    public var time: String
    public var date: String
    public var dayLabel: String
    public var whenLabel: String

    public init(
        id: String,
        operatorName: BusOperator,
        route: String,
        destination: String,
        time: String,
        date: String,
        dayLabel: String,
        whenLabel: String
    ) {
        self.id = id
        self.operatorName = operatorName
        self.route = route
        self.destination = destination
        self.time = time
        self.date = date
        self.dayLabel = dayLabel
        self.whenLabel = whenLabel
    }

    enum CodingKeys: String, CodingKey {
        case id
        case operatorName = "operator"
        case route
        case destination
        case time
        case date
        case dayLabel
        case whenLabel
    }
}

public struct DeparturePayload: Codable, Equatable, Sendable {
    public var stop: String
    public var toward: String
    public var fetchedAt: Date
    public var today: String
    public var serviceFinishedToday: Bool
    public var departures: [Departure]
    public var sources: [SourceStatus]

    public init(
        fetchedAt: Date,
        today: String,
        serviceFinishedToday: Bool,
        departures: [Departure],
        sources: [SourceStatus],
        stop: String = "溝の口駅南口",
        toward: String = "富士見台"
    ) {
        self.stop = stop
        self.toward = toward
        self.fetchedAt = fetchedAt
        self.today = today
        self.serviceFinishedToday = serviceFinishedToday
        self.departures = departures
        self.sources = sources
    }
}

public struct TimetableColumns: Codable, Equatable, Sendable {
    public var weekday: [String]
    public var saturday: [String]
    public var holiday: [String]

    public init(weekday: [String], saturday: [String], holiday: [String]) {
        self.weekday = weekday
        self.saturday = saturday
        self.holiday = holiday
    }

    public static let empty = TimetableColumns(weekday: [], saturday: [], holiday: [])

    public func times(_ kind: DayKind) -> [String] {
        switch kind {
        case .weekday: return weekday
        case .saturday: return saturday
        case .holiday: return holiday
        }
    }
}

public struct ScheduledTrip: Codable, Equatable, Sendable {
    public var operatorName: BusOperator
    public var route: String
    public var destination: String
    public var dayKind: DayKind
    public var time: String

    public init(
        operatorName: BusOperator,
        route: String,
        destination: String,
        dayKind: DayKind,
        time: String
    ) {
        self.operatorName = operatorName
        self.route = route
        self.destination = destination
        self.dayKind = dayKind
        self.time = time
    }

    enum CodingKeys: String, CodingKey {
        case operatorName = "operator"
        case route
        case destination
        case dayKind
        case time
    }
}

public struct TimedTrip: Equatable, Sendable {
    public var operatorName: BusOperator
    public var route: String
    public var destination: String
    public var dayKind: DayKind
    public var time: String

    public init(
        operatorName: BusOperator,
        route: String,
        destination: String,
        dayKind: DayKind,
        time: String
    ) {
        self.operatorName = operatorName
        self.route = route
        self.destination = destination
        self.dayKind = dayKind
        self.time = time
    }
}

public enum Countdown: Equatable, Sendable {
    case minutes(Int)
    case soon
    case past
    case unknown
}

public enum BoardCopy {
    public static let loading = "看板を出しています"
    public static let approachEmpty = "接近しているバスはありません"
    public static let refreshKept = "更新できませんでした。前の表示のままです"
    public static let departuresFailed = "うまく取れませんでした"
    public static let noMoreDepartures = "次の便がありません"
    public static let serviceFinished = "きょうの運行は終わりました"
    public static let retry = "もう一度"
    public static let back = "もどる"
    public static let staleHidden = "古い情報のため非表示です。もう一度更新してください"
    public static let towardMizonokuchi = "溝の口方面"
    public static let towardFujimidai = "富士見台方面"
    public static let fujimidaiTitle = "富士見台発"
    public static let mizonokuchiTitle = "溝の口駅南口発"
    public static let pollCaption = "30秒ごとに更新"
    public static let offline = "いまはネットにつながっていません"

    public static func minutesAgo(_ minutes: Int) -> String {
        "\(minutes)分前の情報"
    }

    public static func savedTimetable(on date: Date) -> String {
        let parts = TokyoCalendar.parts(date)
        return "\(parts.month)月\(parts.day)日に取得した時刻表を表示しています"
    }
}
