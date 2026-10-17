import Foundation

public struct TokyuSnapshotFile: Codable, Equatable, Sendable {
    public var sourceUrl: String
    public var revision: String
    public var stop: String
    public var route: String
    public var destination: String
    public var via: String?
    public var weekday: [String]
    public var saturday: [String]
    public var holiday: [String]
    public var checkedOn: String?
    public var timetableVerified: Bool?

    public var columns: TimetableColumns {
        TimetableColumns(weekday: weekday, saturday: saturday, holiday: holiday)
    }
}

public struct TokyuTimetableResult: Equatable, Sendable {
    public var columns: TimetableColumns
    public var mode: Mode
    public var note: String?
    public var ok: Bool

    public init(columns: TimetableColumns, mode: Mode, note: String?, ok: Bool = true) {
        self.columns = columns
        self.mode = mode
        self.note = note
        self.ok = ok
    }

    public enum Mode: String, Equatable, Sendable {
        case live
        case saved
        case snapshot
    }
}

public enum TokyuTimetable {
    public static let pageURL = URL(string: "https://transfer.navitime.biz/tokyubus/pc/diagram/BusDiagram?course=0004600046&orvCode=00240668&stopNo=1")!
    public static let alternateURL = URL(string: "https://transfer.navitime.biz/tokyubus/pc/extif/DiagramIF?busstopCode=1750403&poleCode=05&routeCode=703101")!
    public static let liveURLs = [pageURL, alternateURL]
    public static let cacheTTL: TimeInterval = 10 * 60

    public static func bundledSnapshot() throws -> TokyuSnapshotFile {
        guard let url = BundledResources.url("tokyu-mizonokuchi", "json") else {
            throw BusTransportError("同梱の東急バス時刻表がありません")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(TokyuSnapshotFile.self, from: data)
    }

    public static let unavailableNote = "東急バスの時刻表を表示できません"

    public static func snapshotNote(revision: String, checkedOn: String? = nil, verified: Bool = false) -> String {
        var note = "東急バスの時刻表サイトに接続できなかったため、公式ページ（\(datePhrase(revision))改定）から取り込んだ時刻を表示しています。現在のダイヤと異なる可能性があります。"
        if let checkedOn, !verified {
            note += "\(datePhrase(checkedOn))時点では最新かどうか確認できていません。"
        }
        return note
    }

    public static func isComplete(_ columns: TimetableColumns) -> Bool {
        columns.weekday.count >= 20 && columns.saturday.count >= 20 && columns.holiday.count >= 20
    }

    public static func unavailable() -> TokyuTimetableResult {
        TokyuTimetableResult(columns: .empty, mode: .snapshot, note: unavailableNote, ok: false)
    }

    public static func resultFromSnapshot(_ snapshot: TokyuSnapshotFile?) -> TokyuTimetableResult {
        guard let snapshot, isComplete(snapshot.columns) else {
            return unavailable()
        }
        return TokyuTimetableResult(
            columns: snapshot.columns,
            mode: .snapshot,
            note: snapshotNote(
                revision: snapshot.revision,
                checkedOn: snapshot.checkedOn,
                verified: snapshot.timetableVerified == true
            ),
            ok: true
        )
    }

    private static func datePhrase(_ revision: String) -> String {
        let parts = revision.split(separator: "-")
        if parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) {
            return "\(year)年\(month)月\(day)日"
        }
        return revision
    }

    public static func trips(_ columns: TimetableColumns, kinds: [DayKind]) -> [TimedTrip] {
        kinds.flatMap { kind in
            columns.times(kind).map { time in
                TimedTrip(
                    operatorName: .tokyu,
                    route: "溝22",
                    destination: "蟹ヶ谷行き",
                    dayKind: kind,
                    time: time
                )
            }
        }
    }

    public static func load(
        _ client: HTTPClient,
        now: Date,
        cache: TimetableFetchCache,
        store: BoardCache,
        useCache: Bool = true
    ) async throws -> TokyuTimetableResult {
        if useCache, let hit = cache.tokyu(now: now) {
            return hit
        }
        for url in liveURLs {
            if Task.isCancelled { throw CancellationError() }
            do {
                let html = try await HTTP.fetchText(client, url)
                if isBlocked(html) { continue }
                let columns = NavitimeDiagramParser.parse(html)
                if !isComplete(columns) { continue }
                let value = TokyuTimetableResult(columns: columns, mode: .live, note: nil, ok: true)
                cache.setTokyu(value, at: now)
                if Task.isCancelled { throw CancellationError() }
                store.saveTokyu(columns, at: now)
                return value
            } catch {
                if BoardClock.isCancellation(error) { throw error }
                continue
            }
        }
        if let saved = store.loadTokyu(), isComplete(saved.columns) {
            let value = TokyuTimetableResult(
                columns: saved.columns,
                mode: .saved,
                note: BoardCopy.savedTimetable(on: saved.savedAt),
                ok: true
            )
            cache.setTokyu(value, at: now)
            return value
        }
        let value = resultFromSnapshot(try? bundledSnapshot())
        if value.ok {
            cache.setTokyu(value, at: now)
        }
        return value
    }

    static func isBlocked(_ html: String) -> Bool {
        containsMatch(html, pattern: "403 ERROR|Request blocked|cloudfront", caseInsensitive: true)
    }
}
