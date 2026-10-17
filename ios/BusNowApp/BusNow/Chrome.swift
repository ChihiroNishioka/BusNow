import SwiftUI
import BusNowCore

struct SheetChrome<Content: View>: View {
    var stripe: Color
    var title: String
    var screenID: String
    var onRefresh: () async -> Void
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Theme.asphalt.ignoresSafeArea()
            ScrollView {
                HStack(spacing: 0) {
                    stripe.frame(width: 14)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Button(BoardCopy.back) { dismiss() }
                                .font(Theme.maru(18, relativeTo: .body))
                                .foregroundStyle(Theme.ink)
                                .frame(minHeight: 44)
                                .accessibilityIdentifier("board.back")
                            Spacer()
                        }
                        Text(title)
                            .font(Theme.maru(52, relativeTo: .largeTitle))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        content()
                    }
                    .padding(.init(top: 12, leading: 16, bottom: 28, trailing: 18))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Theme.cream)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: Theme.shadow, radius: 0, x: 0, y: 12)
                .padding(12)
            }
            .refreshable { await onRefresh() }
            .accessibilityAction(named: "更新") { Task { await onRefresh() } }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(screenID)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .transaction { transaction in
            if reduceMotion { transaction.animation = nil }
        }
    }
}

struct OperatorChip: View {
    var name: BusOperator

    var body: some View {
        Text(name.rawValue)
            .font(Theme.maru(13, relativeTo: .caption))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(name == .tokyu ? Theme.tokyu : Theme.kawasaki, in: Capsule())
            .accessibilityLabel(name.rawValue)
    }
}

struct SourceNotes: View {
    var sources: [SourceStatus]
    var showClock: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
                note(source)
            }
        }
        .padding(.top, 16)
    }

    @ViewBuilder
    private func note(_ source: SourceStatus) -> some View {
        let clock = showClock ? source.updatedAt : nil
        if source.ok && (source.message == nil || source.message?.isEmpty == true) && clock == nil {
            EmptyView()
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                OperatorChip(name: source.operatorName)
                Text(line(source, clock: clock))
                    .font(Theme.maru(15, relativeTo: .footnote))
                    .foregroundStyle(source.ok ? Theme.quiet : Theme.warn)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(source.ok ? "board.note" : "board.warn")
        }
    }

    private func line(_ source: SourceStatus, clock: String?) -> String {
        let message = source.ok ? (source.message ?? "") : (source.message ?? BoardCopy.departuresFailed)
        if let clock, !clock.isEmpty {
            return message.isEmpty ? "\(clock)時点" : "\(message) · \(clock)時点"
        }
        return message
    }
}

struct OfficialLinks: View {
    var links: [(String, URL)]
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(links, id: \.0) { link in
                Button(link.0) { openURL(link.1) }
                    .font(Theme.maru(15, relativeTo: .footnote))
                    .foregroundStyle(Theme.indigo)
                    .frame(minHeight: 44, alignment: .leading)
            }
        }
        .padding(.top, 12)
    }
}
