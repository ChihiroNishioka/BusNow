import SwiftUI
import BusNowCore

struct ComplicationGallery: View {
    private let approach = RecordedBoard.approach()
    private let departures = RecordedBoard.departures()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("コンプリケーションの見た目です。文字盤そのものではなく、録画した取得結果です。")
                    .font(WatchTheme.text(11, relativeTo: .caption2))
                    .foregroundStyle(WatchTheme.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("complication.recorded")
                if approach == nil && departures == nil {
                    Text("録画したデータがありません")
                        .font(WatchTheme.text(14, relativeTo: .body))
                        .accessibilityIdentifier("board.hero")
                }
                if let approach {
                    pair(title: "富士見台", content: ComplicationBoard.content(
                        facing: .fujimidai,
                        approach: approach,
                        departures: departures,
                        now: approach.fetchedAt
                    ), now: approach.fetchedAt)
                }
                if let departures {
                    pair(title: "溝の口", content: ComplicationBoard.content(
                        facing: .mizonokuchi,
                        approach: approach,
                        departures: departures,
                        now: departures.fetchedAt
                    ), now: departures.fetchedAt)
                }
            }
            .padding(.horizontal, 4)
        }
        .accessibilityIdentifier("complication.screen")
    }

    private func pair(title: String, content: ComplicationContent, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(WatchTheme.text(12, relativeTo: .caption))
            HStack(alignment: .center, spacing: 8) {
                CircularComplicationView(content: content, now: now, liveTimer: false)
                    .frame(width: 52, height: 52)
                    .background(Color.black, in: Circle())
                InlineComplicationView(content: content, now: now, liveTimer: false)
            }
        }
    }
}
