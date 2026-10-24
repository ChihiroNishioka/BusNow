import Foundation
import WidgetKit
import BusNowCore

struct ComplicationEntry: TimelineEntry {
    var date: Date
    var content: ComplicationContent
}

struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        let now = Date()
        return ComplicationEntry(date: now, content: ComplicationBoard.placeholder(now: now))
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        let now = Date()
        if context.isPreview {
            completion(ComplicationEntry(date: now, content: ComplicationBoard.placeholder(now: now)))
            return
        }
        let store = SharedBoard.cache()
        let facing = FacingChoice.resolve(mode: SharedBoard.facingMode(), now: now)
        let content = ComplicationBoard.content(
            facing: facing,
            approach: store.loadApproach(),
            departures: store.loadDepartures(),
            now: now
        )
        completion(ComplicationEntry(date: now, content: content))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        Task {
            let timeline = await ComplicationLoader.timeline()
            completion(timeline)
        }
    }
}

enum ComplicationLoader {
    static func timeline() async -> Timeline<ComplicationEntry> {
        let now = Date()
        let store = SharedBoard.cache()
        let facing = FacingChoice.resolve(mode: SharedBoard.facingMode(), now: now)
        let client = HTTP.backgroundClient()
        let clock = SystemClock()
        var approach = store.loadApproach()
        var departures = store.loadDepartures()
        if facing == .fujimidai {
            if let fetched = try? await ApproachBoardLoader(client: client, clock: clock).load(),
               fetched.sources.contains(where: \.ok) {
                store.saveApproach(fetched)
                approach = fetched
            }
        } else if let fetched = try? await DepartureBoardLoader(
            client: client,
            clock: clock,
            cache: TimetableFetchCache(),
            store: store
        ).load(useCache: true) {
            store.saveDepartures(fetched)
            departures = fetched
        }
        let moments = ComplicationBoard.timeline(
            facing: facing,
            approach: approach,
            departures: departures,
            now: now
        )
        let entries = moments.map { ComplicationEntry(date: $0.date, content: $0.content) }
        let next = now.addingTimeInterval(ComplicationBoard.reloadInterval)
        return Timeline(entries: entries.isEmpty ? [ComplicationEntry(date: now, content: ComplicationBoard.placeholder(now: now))] : entries, policy: .after(next))
    }
}
