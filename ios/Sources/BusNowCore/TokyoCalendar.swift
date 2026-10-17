import Foundation

public struct TokyoParts: Equatable, Sendable {
    public var ymd: String
    public var year: Int
    public var month: Int
    public var day: Int
    public var hour: Int
    public var minute: Int
    public var minutesOfDay: Int
}

public enum TokyoCalendar {
    public static let zone = TimeZone(identifier: "Asia/Tokyo")!

    public static func parts(_ date: Date) -> TokyoParts {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return TokyoParts(
            ymd: String(format: "%04d-%02d-%02d", year, month, day),
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            minutesOfDay: hour * 60 + minute
        )
    }

    public static func addDays(_ ymd: String, _ days: Int) -> String {
        let numbers = ymd.split(separator: "-").compactMap { Int($0) }
        guard numbers.count == 3 else { return ymd }
        let calendar = utcCalendar
        var components = DateComponents()
        components.year = numbers[0]
        components.month = numbers[1]
        components.day = numbers[2] + days
        components.hour = 0
        guard let date = calendar.date(from: components) else { return ymd }
        let next = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", next.year ?? numbers[0], next.month ?? numbers[1], next.day ?? numbers[2])
    }

    /// Sunday is 0, matching JavaScript `Date.getUTCDay()`.
    public static func weekdayIndex(_ ymd: String) -> Int {
        let numbers = ymd.split(separator: "-").compactMap { Int($0) }
        guard numbers.count == 3 else { return 0 }
        var components = DateComponents()
        components.year = numbers[0]
        components.month = numbers[1]
        components.day = numbers[2]
        components.hour = 0
        guard let date = utcCalendar.date(from: components) else { return 0 }
        return utcCalendar.component(.weekday, from: date) - 1
    }

    public static func relativeDayLabel(today: String, ymd: String) -> String {
        if ymd == today { return "今日" }
        if ymd == addDays(today, 1) { return "明日" }
        let parts = ymd.split(separator: "-")
        let month = Int(parts.count > 1 ? parts[1] : "0") ?? 0
        let day = Int(parts.count > 2 ? parts[2] : "0") ?? 0
        let names = ["日", "月", "火", "水", "木", "金", "土"]
        return "\(month)/\(day)（\(names[weekdayIndex(ymd)])）"
    }

    public static func formatClock(_ date: Date) -> String {
        let parts = parts(date)
        return "\(parts.hour):" + String(format: "%02d", parts.minute)
    }

    /// A Tokyo wall-clock time. Japan has no daylight saving.
    public static func date(ymd: String, hour: Int, minute: Int) -> Date {
        let numbers = ymd.split(separator: "-").compactMap { Int($0) }
        let year = numbers.count > 0 ? numbers[0] : 1970
        let month = numbers.count > 1 ? numbers[1] : 1
        let day = numbers.count > 2 ? numbers[2] : 1
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        let wall = utcCalendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
        return wall.addingTimeInterval(TimeInterval(-9 * 60 * 60))
    }

    public static func holidays(in year: Int) -> Set<String> {
        var ordered = OrderedDays(baseHolidays(year))
        var substituted = Set<String>()
        var changed = true
        var guardCount = 0
        while changed && guardCount < 16 {
            guardCount += 1
            changed = false
            let snapshot = ordered.items
            for day in snapshot {
                if weekdayIndex(day) != 0 || substituted.contains(day) { continue }
                var cursor = addDays(day, 1)
                var steps = 0
                while ordered.contains(cursor) && steps < 14 {
                    cursor = addDays(cursor, 1)
                    steps += 1
                }
                if !ordered.contains(cursor) {
                    ordered.insert(cursor)
                }
                substituted.insert(day)
                changed = true
            }
            let sorted = ordered.items.sorted()
            if sorted.count >= 2 {
                for index in 0..<(sorted.count - 1) {
                    let between = addDays(sorted[index], 1)
                    if between == sorted[index + 1] { continue }
                    if addDays(between, 1) != sorted[index + 1] { continue }
                    if ordered.contains(between) { continue }
                    ordered.insert(between)
                    changed = true
                }
            }
        }
        return ordered.set
    }

    public static func isHoliday(_ ymd: String) -> Bool {
        let year = Int(ymd.prefix(4)) ?? 0
        return holidays(in: year).contains(ymd)
    }

    public static func dayKind(_ ymd: String) -> DayKind {
        if isHoliday(ymd) || weekdayIndex(ymd) == 0 { return .holiday }
        if weekdayIndex(ymd) == 6 { return .saturday }
        return .weekday
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    private static func nthMonday(year: Int, month: Int, n: Int) -> Int {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        let date = utcCalendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
        let first = utcCalendar.component(.weekday, from: date) - 1
        let untilMonday = (1 - first + 7) % 7
        return 1 + untilMonday + (n - 1) * 7
    }

    private static func ymd(_ year: Int, _ month: Int, _ day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func vernalEquinoxDay(_ year: Int) -> Int {
        let years = Double(year - 1980)
        return Int(floor(20.8431 + 0.242194 * years - Double((year - 1980) / 4)))
    }

    private static func autumnalEquinoxDay(_ year: Int) -> Int {
        let years = Double(year - 1980)
        return Int(floor(23.2488 + 0.242194 * years - Double((year - 1980) / 4)))
    }

    private static func baseHolidays(_ year: Int) -> [String] {
        var days = [
            ymd(year, 1, 1),
            ymd(year, 1, nthMonday(year: year, month: 1, n: 2)),
            ymd(year, 2, 11),
            ymd(year, 2, 23),
            ymd(year, 3, vernalEquinoxDay(year)),
            ymd(year, 4, 29),
            ymd(year, 5, 3),
            ymd(year, 5, 4),
            ymd(year, 5, 5),
            ymd(year, 7, nthMonday(year: year, month: 7, n: 3)),
            ymd(year, 8, 11),
            ymd(year, 9, nthMonday(year: year, month: 9, n: 3)),
            ymd(year, 9, autumnalEquinoxDay(year)),
            ymd(year, 10, nthMonday(year: year, month: 10, n: 2)),
            ymd(year, 11, 3),
            ymd(year, 11, 23),
        ]
        if year == 2019 {
            days.append("2019-05-01")
            days.append("2019-10-22")
        }
        if year == 2020 {
            days.append("2020-07-23")
            days.append("2020-07-24")
        }
        if year == 2021 {
            days.append("2021-07-22")
            days.append("2021-07-23")
        }
        return days
    }
}

private struct OrderedDays {
    var items: [String]
    var set: Set<String>

    init(_ items: [String]) {
        self.items = []
        self.set = []
        for item in items { insert(item) }
    }

    func contains(_ value: String) -> Bool { set.contains(value) }

    mutating func insert(_ value: String) {
        if set.contains(value) { return }
        set.insert(value)
        items.append(value)
    }
}
