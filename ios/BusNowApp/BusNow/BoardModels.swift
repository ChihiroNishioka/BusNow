import Foundation
import Observation
import BusNowCore

@MainActor
@Observable
final class ApproachModel {
    var payload: ApproachPayload?
    var loading = true
    var failed = false
    var failureDetail: String?
    var refreshError: String?
    var now: Date
    private var generation = 0
    private var lastFetchStarted = Date()
    private var fetchTask: Task<ApproachPayload, Error>?
    private var clockTask: Task<Void, Never>?
    private var waitTask: Task<Void, Never>?
    private var userTask: Task<Void, Never>?
    private let services: BusServices

    init(services: BusServices) {
        self.services = services
        self.now = services.fixedNow ?? services.clock.now()
        self.lastFetchStarted = self.now
    }

    func activate() async {
        defer { stop() }
        if services.scenario == nil, payload == nil {
            let store = services.store
            let saved = await Task.detached { store.loadApproach() }.value
            if payload == nil, let saved {
                payload = saved
                loading = false
            }
            now = services.clock.now()
        }
        if services.scenario != nil {
            await reload(useNetwork: true)
            return
        }
        clockTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                now = services.clock.now()
            }
        }
        while !Task.isCancelled {
            await reload(useNetwork: true)
            if Task.isCancelled { return }
            await pauseUntilNextPoll()
        }
    }

    func refresh() {
        userTask?.cancel()
        userTask = Task { await reload(useNetwork: true) }
    }

    func reload(useNetwork: Bool) async {
        if let scenario = services.scenario {
            let instant = services.fixedNow ?? now
            now = instant
            refreshError = nil
            if scenario == .approachFailed {
                payload = nil
                loading = false
                failed = true
                failureDetail = "公式ページから取れませんでした"
                return
            }
            payload = PreviewBoard.approach(now: instant, scenario: scenario)
            loading = false
            failed = false
            return
        }
        guard useNetwork else { return }
        waitTask?.cancel()
        fetchTask?.cancel()
        generation += 1
        let token = generation
        lastFetchStarted = services.clock.now()
        let loader = services.approachLoader
        let task = Task.detached { try await loader.load() }
        fetchTask = task
        let next: ApproachPayload
        do {
            next = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
        } catch is CancellationError {
            return
        } catch {
            guard token == generation, !Task.isCancelled else { return }
            loading = false
            now = services.clock.now()
            if payload == nil {
                failed = true
                failureDetail = ReadableError.message(for: error)
            } else {
                refreshError = BoardCopy.refreshKept
            }
            return
        }
        guard token == generation, !Task.isCancelled else { return }
        payload = next
        now = BoardClock.displayNow(ticking: services.clock.now(), fetchedAt: next.fetchedAt)
        refreshError = nil
        failed = false
        loading = false
        if next.sources.contains(where: \.ok) {
            let store = services.store
            let snapshot = next
            Task.detached { store.saveApproach(snapshot) }
        }
    }

    func stop() {
        clockTask?.cancel()
        fetchTask?.cancel()
        waitTask?.cancel()
        userTask?.cancel()
    }

    private func pauseUntilNextPoll() async {
        while !Task.isCancelled {
            let started = lastFetchStarted
            let epoch = generation
            let wait = BoardClock.waitAfterPoll(started: started, finished: services.clock.now())
            if wait <= 0 { return }
            let sleeper = Task<Void, Never> {
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
            waitTask = sleeper
            await sleeper.value
            waitTask = nil
            if Task.isCancelled { return }
            if generation != epoch {
                if let task = fetchTask {
                    _ = try? await withTaskCancellationHandler {
                        try await task.value
                    } onCancel: {
                        task.cancel()
                    }
                }
                continue
            }
            return
        }
    }
}

@MainActor
@Observable
final class DepartureModel {
    var payload: DeparturePayload?
    var loading = true
    var refreshError: String?
    private var generation = 0
    private var fetchTask: Task<DeparturePayload, Error>?
    private var userTask: Task<Void, Never>?
    private let services: BusServices

    init(services: BusServices) {
        self.services = services
    }

    func refresh() {
        userTask?.cancel()
        userTask = Task { await load(useCache: false) }
    }

    func load(useCache: Bool) async {
        if let scenario = services.scenario {
            let instant = services.fixedNow ?? services.clock.now()
            payload = PreviewBoard.departures(now: instant, scenario: scenario)
            loading = false
            refreshError = nil
            return
        }
        fetchTask?.cancel()
        generation += 1
        let token = generation
        let loader = services.departureLoader
        let task = Task.detached { try await loader.load(useCache: useCache) }
        fetchTask = task
        do {
            let next = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            guard token == generation, !Task.isCancelled else { return }
            if payload != nil && next.departures.isEmpty && next.sources.allSatisfy({ !$0.ok }) {
                refreshError = BoardCopy.refreshKept
                loading = false
                return
            }
            payload = next
            refreshError = nil
            loading = false
        } catch is CancellationError {
            return
        } catch {
            guard token == generation, !Task.isCancelled else { return }
            loading = false
            if payload != nil {
                refreshError = BoardCopy.refreshKept
            }
        }
    }

    func stop() {
        fetchTask?.cancel()
        userTask?.cancel()
    }
}
