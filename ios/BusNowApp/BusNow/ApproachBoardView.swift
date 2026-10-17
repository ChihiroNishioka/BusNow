import SwiftUI
import BusNowCore

struct ApproachBoardView: View {
    @State private var model: ApproachModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize = 76

    init(services: BusServices) {
        _model = State(initialValue: ApproachModel(services: services))
    }

    var body: some View {
        SheetChrome(stripe: Theme.persimmon, title: BoardCopy.fujimidaiTitle, screenID: "approach.screen", onRefresh: {
            await model.reload(useNetwork: true)
        }) {
            Text(BoardCopy.towardMizonokuchi)
                .font(Theme.maru(18, relativeTo: .title3))
                .foregroundStyle(Theme.quiet)
                .padding(.top, 6)
                .padding(.bottom, 12)
            bodyContent
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await model.activate()
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        if model.loading && model.payload == nil {
            Text(BoardCopy.loading)
                .font(Theme.maru(32, relativeTo: .title))
                .foregroundStyle(Theme.ink)
                .padding(.top, 36)
                .accessibilityIdentifier("board.loading")
        } else if model.failed && model.payload == nil {
            VStack(alignment: .leading, spacing: 16) {
                Text(BoardCopy.departuresFailed)
                    .font(Theme.maru(32, relativeTo: .title))
                    .foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("board.hero")
                if let detail = model.failureDetail, detail != BoardCopy.departuresFailed {
                    Text(detail)
                        .font(Theme.maru(16, relativeTo: .body))
                        .foregroundStyle(Theme.warn)
                }
                Button(BoardCopy.retry) {
                    Task { await model.reload(useNetwork: true) }
                }
                .font(Theme.maru(17, relativeTo: .body))
                .foregroundStyle(Theme.cream)
                .padding(.horizontal, 18)
                .frame(minHeight: 44)
                .background(Theme.ink, in: Capsule())
                .accessibilityIdentifier("board.retry")
            }
            .padding(.top, 28)
        } else if let payload = model.payload {
            let presented = BoardPresentation.approach(payload, now: model.now)
            if let hero = presented.hero {
                Text(hero)
                    .font(Theme.maru(32, relativeTo: .title))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 24)
                    .accessibilityIdentifier("board.hero")
            } else if presented.rows.isEmpty, let freshness = presented.freshnessNote {
                Text(freshness)
                    .font(Theme.maru(28, relativeTo: .title2))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 24)
                    .accessibilityIdentifier("board.hero")
            } else {
                VStack(spacing: 0) {
                    ForEach(presented.rows, id: \.bus.id) { row in
                        busRow(row: row, reduceMotion: reduceMotion, numberSize: numberSize)
                    }
                }
            }
            if let freshness = presented.freshnessNote, !presented.rows.isEmpty {
                Text(freshness)
                    .font(Theme.maru(15, relativeTo: .footnote))
                    .foregroundStyle(Theme.quiet)
                    .padding(.top, 14)
            }
            if let refreshError = model.refreshError {
                Text(refreshError)
                    .font(Theme.maru(16, relativeTo: .body))
                    .foregroundStyle(Theme.warn)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                    .accessibilityIdentifier("board.refresh-error")
            }
            Text(basisLine(presented.basis))
                .font(Theme.maru(14, relativeTo: .footnote))
                .foregroundStyle(Theme.quiet)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
            SourceNotes(sources: payload.sources, showClock: false)
            OfficialLinks(links: [
                ("東急バスナビ", TokyuApproach.pageURL),
                ("川崎市バスナビ", KawasakiApproach.pageURL()),
            ])
        }
    }

    private func basisLine(_ basis: String?) -> String {
        if let basis { return "\(basis) · \(BoardCopy.pollCaption)" }
        return BoardCopy.pollCaption
    }
}

private struct busRow: View {
    var row: ApproachRow
    var reduceMotion: Bool
    var numberSize: CGFloat

    var body: some View {
        ViewThatFits(in: .horizontal) {
            rowBody
            VStack(alignment: .leading, spacing: 8) {
                identity
                minute
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Rectangle().fill(Theme.ink.opacity(0.12)).frame(height: 2) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(approachRowAccessibilityLabel(row.bus, countdown: row.countdown))
        .accessibilityIdentifier("approach.row")
    }

    private var rowBody: some View {
        HStack(alignment: .center, spacing: 12) {
            identity
            Spacer(minLength: 8)
            minute
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 4) {
            OperatorChip(name: row.bus.operatorName)
            Text(row.bus.route)
                .font(Theme.maru(24, relativeTo: .title2))
                .foregroundStyle(Theme.ink)
            Text(row.bus.destination)
                .font(Theme.maru(16, relativeTo: .body))
                .foregroundStyle(Theme.quiet)
        }
    }

    @ViewBuilder
    private var minute: some View {
        switch row.countdown {
        case .soon:
            Text("まもなく")
                .font(Theme.maru(28, relativeTo: .title))
                .foregroundStyle(Theme.persimmon)
                .fixedSize()
        case .unknown:
            Text(row.bus.status)
                .font(Theme.maru(22, relativeTo: .title3))
                .foregroundStyle(Theme.persimmon)
                .fixedSize()
        case .minutes(let minutes):
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(minutes)")
                    .font(Theme.digits(numberSize))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Text("分")
                    .font(Theme.maru(20, relativeTo: .title3))
                    .foregroundStyle(Theme.ink)
            }
        case .past:
            EmptyView()
        }
    }
}
