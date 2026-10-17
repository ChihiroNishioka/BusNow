import Foundation

public struct StoredColumns: Codable, Equatable, Sendable {
    public var columns: TimetableColumns
    public var savedAt: Date
}

public struct StoredKawasaki: Codable, Equatable, Sendable {
    public var trips: [ScheduledTrip]
    public var savedAt: Date
}

public final class TimetableFetchCache: @unchecked Sendable {
    private let lock = NSLock()
    private var tokyuEntry: (at: Date, value: TokyuTimetableResult)?
    private var kawasakiEntries: [String: (at: Date, value: KawasakiDepartures)] = [:]
    public var ttl: TimeInterval

    public init(ttl: TimeInterval = 10 * 60) {
        self.ttl = ttl
    }

    public func tokyu(now: Date) -> TokyuTimetableResult? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = tokyuEntry, now.timeIntervalSince(entry.at) < ttl else { return nil }
        return entry.value
    }

    public func setTokyu(_ value: TokyuTimetableResult, at: Date) {
        lock.lock()
        tokyuEntry = (at, value)
        lock.unlock()
    }

    public func kawasaki(key: String, now: Date) -> KawasakiDepartures? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = kawasakiEntries[key], now.timeIntervalSince(entry.at) < ttl else { return nil }
        return entry.value
    }

    public func setKawasaki(key: String, value: KawasakiDepartures, at: Date) {
        lock.lock()
        kawasakiEntries[key] = (at, value)
        lock.unlock()
    }
}

public final class BoardCache: @unchecked Sendable {
    private let lock = NSLock()
    private let directory: URL?
    private var tokyu: StoredColumns?
    private var kawasaki: StoredKawasaki?
    private var approach: ApproachPayload?
    private let encoder = BusJSON.encoder()
    private let decoder = BusJSON.decoder()

    public init(directory: URL?) {
        self.directory = directory
        if let directory {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    public static func memory() -> BoardCache {
        BoardCache(directory: nil)
    }

    public static func appSupport() -> BoardCache {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return BoardCache(directory: base.appendingPathComponent("BusNow", isDirectory: true))
    }

    public func loadTokyu() -> StoredColumns? {
        lock.lock()
        defer { lock.unlock() }
        if let tokyu { return tokyu }
        tokyu = read("tokyu-live.json", as: StoredColumns.self)
        return tokyu
    }

    public func saveTokyu(_ columns: TimetableColumns, at: Date) {
        let stored = StoredColumns(columns: columns, savedAt: at)
        lock.lock()
        tokyu = stored
        lock.unlock()
        write("tokyu-live.json", stored)
    }

    public func loadKawasaki() -> StoredKawasaki? {
        lock.lock()
        defer { lock.unlock() }
        if let kawasaki { return kawasaki }
        kawasaki = read("kawasaki-live.json", as: StoredKawasaki.self)
        return kawasaki
    }

    public func saveKawasaki(_ trips: [ScheduledTrip], at: Date) {
        let stored = StoredKawasaki(trips: trips, savedAt: at)
        lock.lock()
        kawasaki = stored
        lock.unlock()
        write("kawasaki-live.json", stored)
    }

    /// Replaces trips for the day and route pairs in `trips` and keeps every other saved pair.
    public func mergeKawasaki(_ trips: [ScheduledTrip], at: Date) -> [ScheduledTrip] {
        lock.lock()
        if kawasaki == nil {
            kawasaki = read("kawasaki-live.json", as: StoredKawasaki.self)
        }
        var existing = kawasaki?.trips ?? []
        if !trips.isEmpty {
            let keys = Set(trips.map { "\($0.dayKind.rawValue)\t\($0.route)" })
            existing.removeAll { keys.contains("\($0.dayKind.rawValue)\t\($0.route)") }
            existing.append(contentsOf: trips)
        }
        let stored = StoredKawasaki(trips: existing, savedAt: at)
        kawasaki = stored
        lock.unlock()
        write("kawasaki-live.json", stored)
        return existing
    }

    public func loadApproach() -> ApproachPayload? {
        lock.lock()
        defer { lock.unlock() }
        if let approach { return approach }
        approach = read("approach.json", as: ApproachPayload.self)
        return approach
    }

    public func saveApproach(_ payload: ApproachPayload) {
        lock.lock()
        approach = payload
        lock.unlock()
        write("approach.json", payload)
    }

    private func read<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        guard let directory else { return nil }
        let url = directory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ name: String, _ value: T) {
        guard let directory, let data = try? encoder.encode(value) else { return }
        let url = directory.appendingPathComponent(name)
        Task.detached(priority: .utility) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

public enum BusJSON {
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ISO8601Clock.format(date))
        }
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = ISO8601Clock.parse(text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: text)
            }
            return date
        }
        return decoder
    }
}
