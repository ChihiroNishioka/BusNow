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
    private var reloadGeneration = 0
    private let services: BusServices

    init(services: BusServices) {
        self.services = services
        self.now = services.fixedNow ?? services.clock.now()
    }

    func activate() async {
        if services.scenario == nil, payload == nil, let saved = services.store.loadApproach() {
            payload = saved
            loading = false
            now = services.clock.now()
        }
        await reload(useNetwork: true)
        guard services.scenario == nil else { return }
        var ticks = 0
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }
            now = services.clock.now()
            ticks += 1
            if ticks >= 30 {
                ticks = 0
                await reload(useNetwork: true)
            }
        }
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
        reloadGeneration += 1
        let generation = reloadGeneration
        do {
            let next = try await services.approachLoader.load()
            guard generation == reloadGeneration else { return }
            payload = next
            now = next.fetchedAt
            refreshError = nil
            failed = false
            loading = false
            if next.sources.contains(where: \.ok) {
                services.store.saveApproach(next)
            }
        } catch {
            guard generation == reloadGeneration else { return }
            loading = false
            now = services.clock.now()
            if payload == nil {
                failed = true
                failureDetail = ReadableError.message(for: error)
            } else {
                refreshError = BoardCopy.refreshKept
            }
        }
    }
}

@MainActor
@Observable
final class DepartureModel {
    var payload: DeparturePayload?
    var loading = true
    var refreshError: String?
    private var reloadGeneration = 0
    private let services: BusServices

    init(services: BusServices) {
        self.services = services
    }

    func load(useCache: Bool) async {
        if let scenario = services.scenario {
            let instant = services.fixedNow ?? services.clock.now()
            payload = PreviewBoard.departures(now: instant, scenario: scenario)
            loading = false
            refreshError = nil
            return
        }
        reloadGeneration += 1
        let generation = reloadGeneration
        let next = await services.departureLoader.load(useCache: useCache)
        guard generation == reloadGeneration else { return }
        if payload != nil && next.departures.isEmpty && next.sources.allSatisfy({ !$0.ok }) {
            refreshError = BoardCopy.refreshKept
            loading = false
            return
        }
        payload = next
        refreshError = nil
        loading = false
    }
}
