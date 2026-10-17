import Foundation

public enum BoardClock {
    public static let pollInterval: TimeInterval = 30

    /// The board clock keeps ticking. A fetch must not rewind it to the request start.
    public static func displayNow(ticking: Date, fetchedAt: Date) -> Date {
        _ = fetchedAt
        return ticking
    }

    /// Start-to-start spacing. A fetch that already used the whole interval does not add another wait.
    public static func waitAfterPoll(started: Date, finished: Date, interval: TimeInterval = pollInterval) -> TimeInterval {
        max(0, interval - finished.timeIntervalSince(started))
    }

    /// Unique day kinds from `ymd` through `extraDays` later, in calendar order.
    public static func dayKinds(on ymd: String, through extraDays: Int) -> [DayKind] {
        var kinds: [DayKind] = []
        let span = max(0, extraDays)
        for offset in 0...span {
            let kind = TokyoCalendar.dayKind(TokyoCalendar.addDays(ymd, offset))
            if !kinds.contains(kind) {
                kinds.append(kind)
            }
        }
        return kinds
    }

    public static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }
}
