import Foundation

public struct ApproachBoardLoader: Sendable {
    public var client: HTTPClient
    public var clock: any BusClock

    public init(client: HTTPClient, clock: any BusClock = SystemClock()) {
        self.client = client
        self.clock = clock
    }

    public func load(now: Date? = nil) async throws -> ApproachPayload {
        async let tokyu = TokyuApproach.load(client)
        async let kawasaki = KawasakiApproach.load(client)
        let tokyuOutcome = await tokyu
        let kawasakiOutcome = await kawasaki
        if tokyuOutcome.cancelled || kawasakiOutcome.cancelled || Task.isCancelled {
            throw CancellationError()
        }
        if tokyuOutcome.transportFailed && kawasakiOutcome.transportFailed {
            throw BusTransportError(tokyuOutcome.source.message ?? BoardCopy.departuresFailed)
        }
        let received = now ?? clock.now()
        let tokyuAt = CountdownMath.observedInstant(now: received, clock: tokyuOutcome.source.updatedAt)
        let kawasakiAt = CountdownMath.observedInstant(now: received, clock: kawasakiOutcome.source.updatedAt)
        let buses = (
            CountdownMath.stamp(tokyuOutcome.buses, observedAt: tokyuAt)
                + CountdownMath.stamp(kawasakiOutcome.buses, observedAt: kawasakiAt)
        ).sorted(by: byArrival)
        var tokyuSource = tokyuOutcome.source
        var kawasakiSource = kawasakiOutcome.source
        tokyuSource.observedAt = tokyuAt
        kawasakiSource.observedAt = kawasakiAt
        return ApproachPayload(fetchedAt: received, buses: buses, sources: [tokyuSource, kawasakiSource])
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

    public func load(now: Date? = nil, useCache: Bool = true) async throws -> DeparturePayload {
        let started = now ?? clock.now()
        let startedKinds = BoardClock.dayKinds(on: TokyoCalendar.parts(started).ymd, through: 3)
        async let tokyuTask = loadTokyu(now: started, useCache: useCache)
        async let kawasakiTask = loadKawasaki(kinds: startedKinds, now: started, useCache: useCache)
        let tokyu = try await tokyuTask
        var kawasaki = try await kawasakiTask
        let received = now ?? clock.now()
        let kinds = BoardClock.dayKinds(on: TokyoCalendar.parts(received).ymd, through: 3)
        if kinds != startedKinds {
            kawasaki = try await loadKawasaki(kinds: kinds, now: received, useCache: useCache)
        }

        var trips: [TimedTrip] = []
        var sources: [SourceStatus] = []
        if tokyu.ok {
            trips.append(contentsOf: TokyuTimetable.trips(tokyu.columns, kinds: kinds))
        }
        sources.append(SourceStatus(operatorName: .tokyu, ok: tokyu.ok, message: tokyu.note, updatedAt: nil))
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
        let selected = UpcomingSelector.select(now: received, trips: trips, limit: 3)
        return DeparturePayload(
            fetchedAt: received,
            today: selected.today,
            serviceFinishedToday: selected.serviceFinishedToday,
            departures: selected.departures,
            sources: sources
        )
    }

    private func loadTokyu(now: Date, useCache: Bool) async throws -> TokyuTimetableResult {
        do {
            return try await TokyuTimetable.load(client, now: now, cache: cache, store: store, useCache: useCache)
        } catch {
            if BoardClock.isCancellation(error) { throw error }
            return TokyuTimetable.unavailable()
        }
    }

    private func loadKawasaki(
        kinds: [DayKind],
        now: Date,
        useCache: Bool
    ) async throws -> Result<KawasakiDepartures, Error> {
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
            if BoardClock.isCancellation(error) { throw error }
            return .failure(error)
        }
    }
}
