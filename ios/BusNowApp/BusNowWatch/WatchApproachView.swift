import SwiftUI
import BusNowCore

struct WatchApproachView: View {
    @State private var model: ApproachModel

    init(services: BusServices) {
        _model = State(initialValue: ApproachModel(services: services))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(BoardCopy.towardMizonokuchi)
                    .font(WatchTheme.text(12, relativeTo: .caption))
                    .foregroundStyle(WatchTheme.quiet)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .accessibilityIdentifier("approach.screen")
        .task { await model.activate() }
        .onDisappear { model.stop() }
    }

    @ViewBuilder
    private var content: some View {
        if model.loading && model.payload == nil {
            Text(BoardCopy.loading)
                .font(WatchTheme.text(16, relativeTo: .body))
                .accessibilityIdentifier("board.loading")
        } else if model.failed && model.payload == nil {
            failure(model.failureDetail)
        } else if let payload = model.payload {
            let presented = BoardPresentation.approach(payload, now: model.now)
            if presented.rows.isEmpty, let hero = presented.hero {
                Text(hero)
                    .font(WatchTheme.text(16, relativeTo: .body))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("board.hero")
            }
            ForEach(presented.rows, id: \.bus.id) { row in
                approachRow(row)
            }
            warnings(payload.sources)
            if let refreshError = model.refreshError {
                Text(refreshError)
                    .font(WatchTheme.text(12, relativeTo: .caption))
                    .foregroundStyle(WatchTheme.warn)
                    .fixedSize(horizontal: false, vertical: true)
            }
            freshness(ComplicationBoard.freshness(fetchedAt: payload.fetchedAt, now: model.now))
            if presented.freshnessNote == BoardCopy.staleHidden || (model.failed && model.payload == nil) {
                retry
            }
        }
    }

    private func approachRow(_ row: ApproachRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                operatorChip(row.bus.operatorName)
                Text(row.bus.route)
                    .font(WatchTheme.digits(15, relativeTo: .headline))
                Spacer(minLength: 4)
                Text(countdownText(row.countdown, status: row.bus.status))
                    .font(WatchTheme.digits(18, relativeTo: .title3))
                    .monospacedDigit()
                    .foregroundStyle(WatchTheme.persimmon)
            }
            Text(row.bus.destination)
                .font(WatchTheme.text(13, relativeTo: .footnote))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(approachRowAccessibilityLabel(row.bus, countdown: row.countdown))
        .accessibilityIdentifier("approach.row")
    }

    private func countdownText(_ countdown: Countdown, status: String) -> String {
        switch countdown {
        case .minutes(let minutes):
            return "あと\(minutes)分"
        case .soon:
            return "まもなく"
        case .past:
            return "到着済み"
        case .unknown:
            return status
        }
    }

    private func failure(_ detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(BoardCopy.departuresFailed)
                .font(WatchTheme.text(16, relativeTo: .body))
                .accessibilityIdentifier("board.hero")
            if let detail, detail != BoardCopy.departuresFailed {
                Text(detail)
                    .font(WatchTheme.text(12, relativeTo: .caption))
                    .foregroundStyle(WatchTheme.warn)
                    .fixedSize(horizontal: false, vertical: true)
            }
            retry
        }
    }

    private var retry: some View {
        Button(BoardCopy.retry) { model.refresh() }
            .font(WatchTheme.text(14, relativeTo: .body))
            .accessibilityIdentifier("board.retry")
    }

    private func warnings(_ sources: [SourceStatus]) -> some View {
        ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
            if source.ok == false, let message = source.message, !message.isEmpty {
                Text("\(source.operatorName.rawValue) \(message)")
                    .font(WatchTheme.text(11, relativeTo: .caption2))
                    .foregroundStyle(WatchTheme.warn)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("board.warn")
            }
        }
    }

    private func freshness(_ text: String) -> some View {
        Text(text)
            .font(WatchTheme.text(11, relativeTo: .caption2))
            .foregroundStyle(WatchTheme.quiet)
            .fixedSize(horizontal: false, vertical: true)
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
