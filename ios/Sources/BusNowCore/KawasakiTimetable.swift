import Foundation

public struct KawasakiFetchFailure: Equatable, Sendable {
    public var route: String
    public var day: String
    public var url: String
    public var status: String

    public init(route: String, day: String, url: String, status: String) {
        self.route = route
        self.day = day
        self.url = url
        self.status = status
    }
}

public struct KawasakiDepartures: Equatable, Sendable {
    public var trips: [ScheduledTrip]
    public var note: String?
    public var failures: [KawasakiFetchFailure]

    public init(trips: [ScheduledTrip], note: String?, failures: [KawasakiFetchFailure] = []) {
        self.trips = trips
        self.note = note
        self.failures = failures
    }
}

public enum KawasakiTimetableParser {
    public static func parse(_ html: String) -> [String] {
        let root = HTMLParser.parse(html)
        var times: [String] = []
        for row in root.find("tr") {
            let cells = row.childElements(["td"])
            if cells.count < 2 { continue }
            let hourText = cells[0].textContent()
            if !hourText.contains("時") { continue }
            guard let hourMatch = firstMatch(hourText, pattern: "(\\d{1,2})"),
                  let hourValue = hourMatch.groups.dropFirst().first ?? nil,
                  let hour = Int(hourValue),
                  hour <= 27
            else { continue }
            let minuteText = cells[1].textContent().replacingOccurrences(of: "\u{3000}", with: " ")
            for match in allMatches(minuteText, pattern: "(\\d{1,2})\\s*分") {
                guard let minuteValue = match.groups.dropFirst().first ?? nil,
                      let minute = Int(minuteValue),
                      minute <= 59
                else { continue }
                times.append(String(format: "%02d:%02d", hour, minute))
            }
        }
        return times
    }
}

public enum KawasakiTimetable {
    public static let indexURL = URL(string: "https://kcbn.bus-navigation.jp/wgsys/wgp/timeTableRouteTab.htm")!
    public static let fileURL = URL(string: "https://kcbn.bus-navigation.jp/wgsys/wgp/timeTableRouteTabFile.htm")!
    public static let signpoleKey = "145384"
    public static let pageURL = URL(string: "https://kcbn.bus-navigation.jp/wgsys/wgp/bus.htm?from=%E6%BA%9D%E5%8F%A3%E9%A7%85%E5%8D%97%E5%8F%A3&fromType=1&fromSignpoleKey=145384&locale=ja&tabName=timetableRouteTab")!
    public static let cacheTTL: TimeInterval = 10 * 60

    public static func load(
        _ client: HTTPClient,
        kinds: [DayKind],
        now: Date,
        cache: TimetableFetchCache,
        store: BoardCache,
        useCache: Bool = true
    ) async throws -> KawasakiDepartures {
        let key = kinds.map(\.rawValue).sorted().joined(separator: ",")
        if useCache, let hit = cache.kawasaki(key: key, now: now) {
            return hit
        }
        do {
            let fetched = try await fetch(client, kinds: kinds)
            if Task.isCancelled { throw CancellationError() }
            let merged = store.mergeKawasaki(fetched.trips, at: now)
            let value = KawasakiDepartures(trips: merged, note: fetched.note, failures: fetched.failures)
            cache.setKawasaki(key: key, value: value, at: now)
            return value
        } catch {
            if BoardClock.isCancellation(error) { throw error }
            if let saved = store.loadKawasaki() {
                let value = KawasakiDepartures(trips: saved.trips, note: BoardCopy.savedTimetable(on: saved.savedAt))
                cache.setKawasaki(key: key, value: value, at: now)
                return value
            }
            throw error
        }
    }

    private static func fetch(_ client: HTTPClient, kinds: [DayKind]) async throws -> FetchedTimetable {
        let index = try await HTTP.fetchFormJSON(
            client,
            indexURL,
            fields: [
                ("from", "溝口駅南口"),
                ("fromType", "1"),
                ("fromSignpoleKey", signpoleKey),
                ("locale", "ja"),
                ("tabName", "timetableRouteTab"),
                ("nextDiagramFlag", "0"),
                ("language", "ja"),
            ],
            as: IndexResponse.self
        )
        let rows = index.timeTableRouteDestinationSubData ?? []
        if rows.isEmpty {
            throw BusTransportError("川崎市バスの時刻表一覧が空でした")
        }
        var jobs: [(String, DayKind, String, String)] = []
        for row in rows {
            let route = compactRoute(row.timeTableRollsignNameJP ?? "")
            let place = compactRoute(row.timeTableDestinationNameJP ?? "")
            let destination: String
            if place.isEmpty {
                destination = ""
            } else if place.hasSuffix("行き") {
                destination = place
            } else {
                destination = "\(place)行き"
            }
            let note = compactRoute(row.noteJP ?? "")
            let labeled = note.isEmpty || destination.isEmpty ? destination : "\(destination)（\(note)）"
            let labels = row.timeTableHtmlList ?? []
            let links = row.timeTableHtmlListLink ?? []
            for kind in kinds {
                let label = DayLabel.text(kind)
                guard let indexOfKind = labels.firstIndex(where: { $0.contains(label) }),
                      links.indices.contains(indexOfKind)
                else { continue }
                jobs.append((links[indexOfKind], kind, route, labeled))
            }
        }
        if jobs.isEmpty {
            return FetchedTimetable(trips: [], note: nil, failures: [])
        }
        return try await withThrowingTaskGroup(of: OneFetch.self) { group in
            for job in jobs {
                group.addTask {
                    let day = DayLabel.text(job.1)
                    do {
                        let trips = try await loadOne(client, link: job.0, dayKind: job.1, route: job.2, destination: job.3)
                        return OneFetch(trips: trips, failure: nil)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch let error as KawasakiFetchError {
                        return OneFetch(
                            trips: [],
                            failure: KawasakiFetchFailure(route: job.2, day: day, url: error.url, status: error.status)
                        )
                    } catch {
                        if BoardClock.isCancellation(error) { throw error }
                        return OneFetch(
                            trips: [],
                            failure: KawasakiFetchFailure(
                                route: job.2,
                                day: day,
                                url: fileURL.absoluteString,
                                status: (error as? BusTransportError)?.message ?? String(describing: error)
                            )
                        )
                    }
                }
            }
            var trips: [ScheduledTrip] = []
            var failures: [KawasakiFetchFailure] = []
            for try await result in group {
                if Task.isCancelled { throw CancellationError() }
                trips.append(contentsOf: result.trips)
                if let failure = result.failure {
                    failures.append(failure)
                }
            }
            if trips.isEmpty {
                let summary = failures.map { "\($0.route) \($0.day) \($0.status)" }.joined(separator: " / ")
                throw BusTransportError(summary.isEmpty ? "川崎市バスの時刻表の形が分かりません" : summary)
            }
            failures.sort { lhs, rhs in
                if lhs.route != rhs.route { return lhs.route < rhs.route }
                if lhs.day != rhs.day { return lhs.day < rhs.day }
                return lhs.url < rhs.url
            }
            return FetchedTimetable(trips: trips, note: failureNote(failures), failures: failures)
        }
    }

    private static func failureNote(_ failures: [KawasakiFetchFailure]) -> String? {
        guard !failures.isEmpty else { return nil }
        let lines = failures.map { "\($0.route) \($0.day) \($0.url) \($0.status)" }
        return (["一部の路線の時刻表を取れませんでした"] + lines).joined(separator: "\n")
    }

    private static func loadOne(
        _ client: HTTPClient,
        link: String,
        dayKind: DayKind,
        route: String,
        destination: String
    ) async throws -> [ScheduledTrip] {
        let pieces = link.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        let date = pieces.first.map(String.init) ?? ""
        let name = pieces.count > 1 ? String(pieces[1]) : ""
        let requestURL = "\(fileURL.absoluteString)?date=\(date)&name=\(name)"
        let meta: FileResponse
        do {
            meta = try await HTTP.fetchFormJSON(
                client,
                fileURL,
                fields: [("type", "0"), ("date", date), ("name", name)],
                as: FileResponse.self
            )
        } catch {
            throw KawasakiFetchError(url: requestURL, status: httpStatus(error))
        }
        if meta.filePath == nil || meta.filePath?.isEmpty == true || meta.errorFlg == "1" {
            throw KawasakiFetchError(url: requestURL, status: "ファイルなし")
        }
        let path = meta.filePath ?? ""
        guard let url = URL(string: "https://kcbn.bus-navigation.jp/wgsys\(path)") else {
            throw KawasakiFetchError(url: requestURL, status: "ファイルなし")
        }
        let html: String
        do {
            html = try await HTTP.fetchText(client, url)
        } catch {
            throw KawasakiFetchError(url: url.absoluteString, status: httpStatus(error))
        }
        let times = KawasakiTimetableParser.parse(html)
        if times.isEmpty {
            throw KawasakiFetchError(url: url.absoluteString, status: "空の時刻表")
        }
        return times.map { time in
            ScheduledTrip(
                operatorName: .kawasaki,
                route: route,
                destination: destination.isEmpty ? "富士見台方面" : destination,
                dayKind: dayKind,
                time: time
            )
        }
    }
}

private struct KawasakiFetchError: Error {
    var url: String
    var status: String
}

private struct OneFetch: Sendable {
    var trips: [ScheduledTrip]
    var failure: KawasakiFetchFailure?
}

private struct FetchedTimetable: Sendable {
    var trips: [ScheduledTrip]
    var note: String?
    var failures: [KawasakiFetchFailure]
}

private func httpStatus(_ error: Error) -> String {
    let message = (error as? BusTransportError)?.message ?? String(describing: error)
    if let match = firstMatch(message, pattern: "HTTP (\\d+)"),
       let code = match.groups.dropFirst().first ?? nil,
       !code.isEmpty {
        return "HTTP \(code)"
    }
    return message
}

private struct IndexResponse: Decodable {
    var timeTableRouteDestinationSubData: [IndexRow]?
}

private struct IndexRow: Decodable {
    var timeTableRollsignNameJP: String?
    var timeTableDestinationNameJP: String?
    var noteJP: String?
    var timeTableHtmlList: [String]?
    var timeTableHtmlListLink: [String]?
}

private struct FileResponse: Decodable {
    var filePath: String?
    var errorFlg: String?
}
