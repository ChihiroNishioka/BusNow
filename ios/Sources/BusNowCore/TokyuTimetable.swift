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

    public var columns: TimetableColumns {
        TimetableColumns(weekday: weekday, saturday: saturday, holiday: holiday)
    }
}

public struct TokyuTimetableResult: Equatable, Sendable {
    public var columns: TimetableColumns
    public var mode: Mode
    public var note: String?

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

    public static func snapshotNote(revision: String) -> String {
        let parts = revision.split(separator: "-")
        let phrase: String
        if parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) {
            phrase = "\(year)年\(month)月\(day)日"
        } else {
            phrase = revision
        }
        return "東急バスの時刻表サイトに接続できなかったため、公式ページ（\(phrase)改定）から取り込んだ時刻を表示しています"
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
    ) async -> TokyuTimetableResult {
        if useCache, let hit = cache.tokyu(now: now) {
            return hit
        }
        for url in liveURLs {
            do {
                let html = try await HTTP.fetchText(client, url)
                if isBlocked(html) { continue }
                let columns = NavitimeDiagramParser.parse(html)
                if columns.weekday.count < 20 { continue }
                let value = TokyuTimetableResult(columns: columns, mode: .live, note: nil)
                cache.setTokyu(value, at: now)
                store.saveTokyu(columns, at: now)
                return value
            } catch {
                continue
            }
        }
        if let saved = store.loadTokyu(), saved.columns.weekday.count >= 20 {
            let value = TokyuTimetableResult(
                columns: saved.columns,
                mode: .saved,
                note: BoardCopy.savedTimetable(on: saved.savedAt)
            )
            cache.setTokyu(value, at: now)
            return value
        }
        let snapshot = (try? bundledSnapshot()) ?? TokyuSnapshotFile(
            sourceUrl: pageURL.absoluteString,
            revision: "2025-07-01",
            stop: "溝の口駅南口",
            route: "溝22",
            destination: "蟹ヶ谷",
            via: nil,
            weekday: [],
            saturday: [],
            holiday: []
        )
        let value = TokyuTimetableResult(
            columns: snapshot.columns,
            mode: .snapshot,
            note: snapshotNote(revision: snapshot.revision)
        )
        cache.setTokyu(value, at: now)
        return value
    }

    static func isBlocked(_ html: String) -> Bool {
        containsMatch(html, pattern: "403 ERROR|Request blocked|cloudfront", caseInsensitive: true)
    }
}
