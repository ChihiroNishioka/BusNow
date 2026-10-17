import Foundation

public struct ApproachBoardLoader: Sendable {
    public var client: HTTPClient
    public var clock: any BusClock

    public init(client: HTTPClient, clock: any BusClock = SystemClock()) {
        self.client = client
        self.clock = clock
    }

    public func load(now: Date? = nil) async throws -> ApproachPayload {
        let now = now ?? clock.now()
        async let tokyu = TokyuApproach.load(client)
        async let kawasaki = KawasakiApproach.load(client)
        let tokyuOutcome = await tokyu
        let kawasakiOutcome = await kawasaki
        if tokyuOutcome.transportFailed && kawasakiOutcome.transportFailed {
            throw BusTransportError(tokyuOutcome.source.message ?? BoardCopy.departuresFailed)
        }
        let tokyuAt = CountdownMath.observedInstant(now: now, clock: tokyuOutcome.source.updatedAt)
        let kawasakiAt = CountdownMath.observedInstant(now: now, clock: kawasakiOutcome.source.updatedAt)
        let buses = (
            CountdownMath.stamp(tokyuOutcome.buses, observedAt: tokyuAt)
                + CountdownMath.stamp(kawasakiOutcome.buses, observedAt: kawasakiAt)
        ).sorted(by: byArrival)
        var tokyuSource = tokyuOutcome.source
        var kawasakiSource = kawasakiOutcome.source
        tokyuSource.observedAt = tokyuAt
        kawasakiSource.observedAt = kawasakiAt
        return ApproachPayload(fetchedAt: now, buses: buses, sources: [tokyuSource, kawasakiSource])
    }

    private func byArrival(_ lhs: ApproachBus, _ rhs: ApproachBus) -> Bool {
        let left = lhs.arrivesAt?.timeIntervalSince1970 ?? .infinity
        let right = rhs.arrivesAt?.timeIntervalSince1970 ?? .infinity
        if left != right { return left < right }
        let order = compareJapanese(lhs.route, rhs.route)
        if order != .orderedSame { return order == .orderedAscending }
        return lhs.id < rhs.id
    }
}

public struct DepartureBoardLoader: Sendable {
    public var client: HTTPClient
    public var clock: any BusClock
    public var cache: TimetableFetchCache
    public var store: BoardCache

    public init(
        client: HTTPClient,
        clock: any BusClock = SystemClock(),
        cache: TimetableFetchCache = TimetableFetchCache(),
        store: BoardCache = .memory()
    ) {
        self.client = client
        self.clock = clock
        self.cache = cache
        self.store = store
    }

    public func load(now: Date? = nil, useCache: Bool = true) async -> DeparturePayload {
        let now = now ?? clock.now()
        let today = TokyoCalendar.parts(now)
        let todayKind = TokyoCalendar.dayKind(today.ymd)
        let tomorrowKind = TokyoCalendar.dayKind(TokyoCalendar.addDays(today.ymd, 1))
        let kinds = todayKind == tomorrowKind ? [todayKind] : [todayKind, tomorrowKind]

        async let tokyuTask = TokyuTimetable.load(client, now: now, cache: cache, store: store, useCache: useCache)
        async let kawasakiTask = loadKawasaki(kinds: kinds, now: now, useCache: useCache)
        let tokyu = await tokyuTask
        let kawasaki = await kawasakiTask

        var trips: [TimedTrip] = []
        var sources: [SourceStatus] = []
        trips.append(contentsOf: TokyuTimetable.trips(tokyu.columns, kinds: kinds))
        sources.append(SourceStatus(operatorName: .tokyu, ok: true, message: tokyu.note, updatedAt: nil))
        switch kawasaki {
        case .success(let value):
            trips.append(contentsOf: value.trips.map {
                TimedTrip(
                    operatorName: $0.operatorName,
                    route: $0.route,
                    destination: $0.destination,
                    dayKind: $0.dayKind,
                    time: $0.time
                )
            })
            sources.append(SourceStatus(operatorName: .kawasaki, ok: true, message: value.note, updatedAt: nil))
        case .failure(let error):
            sources.append(SourceStatus(operatorName: .kawasaki, ok: false, message: ReadableError.message(for: error), updatedAt: nil))
        }
        let selected = UpcomingSelector.select(now: now, trips: trips, limit: 3)
        return DeparturePayload(
            fetchedAt: now,
            today: selected.today,
            serviceFinishedToday: selected.serviceFinishedToday,
            departures: selected.departures,
            sources: sources
        )
    }

    private func loadKawasaki(
        kinds: [DayKind],
        now: Date,
        useCache: Bool
    ) async -> Result<KawasakiDepartures, Error> {
        do {
            let value = try await KawasakiTimetable.load(
                client,
                kinds: kinds,
                now: now,
                cache: cache,
                store: store,
                useCache: useCache
            )
            return .success(value)
        } catch {
            return .failure(error)
        }
    }
}
