import SwiftUI
import WidgetKit
import BusNowCore

@main
struct BusNowComplicationBundle: WidgetBundle {
    var body: some Widget {
        BusNowComplication()
    }
}

struct BusNowComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: ComplicationBoard.kind, provider: ComplicationProvider()) { entry in
            ComplicationWidgetView(entry: entry)
        }
        .configurationDisplayName("次のバス")
        .description("午前は富士見台の接近、午後は溝の口駅南口の次の便。設定で向きを変えられます。")
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}

struct ComplicationWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ComplicationEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                CircularComplicationView(content: entry.content, now: entry.date, liveTimer: true)
            case .accessoryInline:
                InlineComplicationView(content: entry.content, now: entry.date, liveTimer: true)
            default:
                InlineComplicationView(content: entry.content, now: entry.date, liveTimer: true)
            }
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }
}
