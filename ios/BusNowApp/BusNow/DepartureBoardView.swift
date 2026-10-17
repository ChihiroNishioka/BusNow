import SwiftUI
import BusNowCore

struct DepartureBoardView: View {
    @State private var model: DepartureModel
    @ScaledMetric(relativeTo: .largeTitle) private var timeSize = 52

    init(services: BusServices) {
        _model = State(initialValue: DepartureModel(services: services))
    }

    var body: some View {
        SheetChrome(stripe: Theme.indigo, title: BoardCopy.mizonokuchiTitle, screenID: "departure.screen", onRefresh: {
            await model.load(useCache: false)
        }) {
            Text(BoardCopy.towardFujimidai)
                .font(Theme.maru(18, relativeTo: .title3))
                .foregroundStyle(Theme.quiet)
                .padding(.top, 6)
                .padding(.bottom, 12)
            if model.loading && model.payload == nil {
                Text(BoardCopy.loading)
                    .font(Theme.maru(32, relativeTo: .title))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 36)
                    .accessibilityIdentifier("board.loading")
            } else if let payload = model.payload {
                let presented = BoardPresentation.departures(payload)
                if presented.finishedBanner {
                    Text(BoardCopy.serviceFinished)
                        .font(Theme.maru(28, relativeTo: .title2))
                        .foregroundStyle(Theme.indigo)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 8)
                        .accessibilityIdentifier("board.finished")
                }
                if let hero = presented.hero {
                    Text(hero)
                        .font(Theme.maru(32, relativeTo: .title))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 20)
                        .accessibilityIdentifier("board.hero")
                    if hero == BoardCopy.departuresFailed {
                        Button(BoardCopy.retry) {
                            model.refresh()
                        }
                        .font(Theme.maru(17, relativeTo: .body))
                        .foregroundStyle(Theme.cream)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(Theme.ink, in: Capsule())
                        .padding(.top, 16)
                        .accessibilityIdentifier("board.retry")
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(presented.departures) { departure in
                            departureRow(departure: departure, timeSize: timeSize)
                        }
                    }
                }
                if let refreshError = model.refreshError {
                    Text(refreshError)
                        .font(Theme.maru(16, relativeTo: .body))
                        .foregroundStyle(Theme.warn)
                        .padding(.top, 12)
                        .accessibilityIdentifier("board.refresh-error")
                }
                SourceNotes(sources: payload.sources)
                OfficialLinks(links: [
                    ("東急バス 時刻表", TokyuTimetable.pageURL),
                    ("川崎市バス 時刻表", KawasakiTimetable.pageURL),
                ])
            }
        }
        .task { await model.load(useCache: true) }
        .onDisappear { model.stop() }
    }
}

private struct departureRow: View {
    var departure: Departure
    var timeSize: CGFloat

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                time
                details
            }
            VStack(alignment: .leading, spacing: 6) {
                time
                details
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(Theme.ink.opacity(0.12)).frame(height: 2) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(departureAccessibilityLabel(departure))
        .accessibilityIdentifier("departure.row")
    }

    private var time: some View {
        Text(departure.time)
            .font(Theme.digits(timeSize))
            .monospacedDigit()
            .foregroundStyle(Theme.indigo)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            OperatorChip(name: departure.operatorName)
            Text("\(departure.route) \(departure.destination)")
                .font(Theme.maru(20, relativeTo: .title3))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(departure.whenLabel) · \(departure.dayLabel)")
                .font(Theme.maru(15, relativeTo: .footnote))
                .foregroundStyle(Theme.quiet)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
