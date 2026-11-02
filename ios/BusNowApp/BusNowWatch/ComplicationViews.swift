import SwiftUI
import WidgetKit
import BusNowCore

struct CircularComplicationView: View {
    var content: ComplicationContent
    var now: Date
    var liveTimer: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text(content.headline)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .widgetAccentable()
            value
            Text(shortFreshness)
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
        .accessibilityIdentifier("complication.circular")
    }

    @ViewBuilder
    private var value: some View {
        if content.showsTimer, let arrivesAt = content.arrivesAt {
            if liveTimer {
                Text(arrivesAt, style: .timer)
                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                    .widgetAccentable()
            } else {
                Text(ComplicationBoard.timerText(arrivesAt: arrivesAt, now: now))
                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
            }
        } else {
            Text(content.detail)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }

    private var shortFreshness: String {
        if content.timetableUnverified {
            return "未確認"
        }
        if content.stale {
            return "古い"
        }
        let head = content.freshness.split(separator: "·").first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? content.freshness
        if head.hasPrefix("取得 ") {
            return String(head.dropFirst("取得 ".count))
        }
        return head
    }
}

struct InlineComplicationView: View {
    var content: ComplicationContent
    var now: Date
    var liveTimer: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            line
            Text(content.headline)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
        .accessibilityIdentifier("complication.inline")
    }

    private var line: some View {
        HStack(spacing: 3) {
            Text(content.headline)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .widgetAccentable()
            if content.showsTimer, let arrivesAt = content.arrivesAt {
                if liveTimer {
                    Text(arrivesAt, style: .timer)
                        .monospacedDigit()
                        .widgetAccentable()
                } else {
                    Text(ComplicationBoard.timerText(arrivesAt: arrivesAt, now: now))
                        .monospacedDigit()
                }
            } else {
                Text(content.detail)
            }
            Text(content.freshness)
                .foregroundStyle(.secondary)
        }
    }
}
