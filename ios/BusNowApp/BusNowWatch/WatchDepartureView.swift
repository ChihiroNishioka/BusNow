import SwiftUI
import BusNowCore

struct WatchDepartureView: View {
    let services: BusServices
    @State private var model: DepartureModel
    @Environment(\.scenePhase) private var scenePhase

    init(services: BusServices) {
        self.services = services
        _model = State(initialValue: DepartureModel(services: services))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(BoardCopy.towardFujimidai)
                    .font(WatchTheme.text(12, relativeTo: .caption))
                    .foregroundStyle(WatchTheme.quiet)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .accessibilityIdentifier("departure.screen")
        .task(id: scenePhase) { await followScene() }
        .onDisappear { model.stop() }
    }

    @ViewBuilder
    private var content: some View {
        if model.loading && model.payload == nil {
            Text(BoardCopy.loading)
                .font(WatchTheme.text(16, relativeTo: .body))
                .accessibilityIdentifier("board.loading")
        } else if let payload = model.payload {
            let presented = BoardPresentation.departures(payload, now: model.now)
            if presented.finishedBanner {
                Text(BoardCopy.serviceFinished)
                    .font(WatchTheme.text(15, relativeTo: .headline))
                    .foregroundStyle(WatchTheme.indigo)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("board.finished")
            }
            if let hero = presented.hero {
                Text(hero)
                    .font(WatchTheme.text(16, relativeTo: .body))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("board.hero")
                if hero == BoardCopy.departuresFailed {
                    Button(BoardCopy.retry) { model.refresh() }
                        .font(WatchTheme.text(14, relativeTo: .body))
                        .accessibilityIdentifier("board.retry")
                }
            }
            ForEach(presented.departures) { departure in
                departureRow(departure)
            }
            notes(payload.sources)
            if let refreshError = model.refreshError {
                Text(refreshError)
                    .font(WatchTheme.text(12, relativeTo: .caption))
                    .foregroundStyle(WatchTheme.warn)
                    .fixedSize(horizontal: false, vertical: true)
            }
            freshness(ComplicationBoard.freshness(fetchedAt: payload.fetchedAt, now: model.now))
        }
    }

    private func followScene() async {
        if scenePhase != .active, services.scenario == nil {
            model.stop()
            WatchRefresh.schedule()
            return
        }
        await model.load(useCache: true)
    }

    private func departureRow(_ departure: Departure) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(departure.time)
                    .font(WatchTheme.digits(20, relativeTo: .title3))
                    .monospacedDigit()
                    .foregroundStyle(WatchTheme.indigo)
                operatorChip(departure.operatorName)
                Text(departure.route)
                    .font(WatchTheme.digits(14, relativeTo: .body))
            }
            Text("\(departure.destination)（\(departure.whenLabel)）")
                .font(WatchTheme.text(13, relativeTo: .footnote))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(departureAccessibilityLabel(departure))
        .accessibilityIdentifier("departure.row")
    }

    private func notes(_ sources: [SourceStatus]) -> some View {
        ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
            if let message = source.message, !message.isEmpty {
                Text(message)
                    .font(WatchTheme.text(11, relativeTo: .caption2))
                    .foregroundStyle(source.ok ? WatchTheme.quiet : WatchTheme.warn)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(source.ok ? "board.note" : "board.warn")
            }
        }
    }

    private func freshness(_ text: String) -> some View {
        Text(text)
            .font(WatchTheme.text(11, relativeTo: .caption2))
            .foregroundStyle(WatchTheme.quiet)
            .accessibilityIdentifier("board.freshness")
    }

    private func operatorChip(_ name: BusOperator) -> some View {
        Text(name == .tokyu ? "東急" : "市バス")
            .font(WatchTheme.text(10, relativeTo: .caption2))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .foregroundStyle(.white)
            .background(name == .tokyu ? WatchTheme.tokyu : WatchTheme.kawasaki, in: Capsule())
    }
}
