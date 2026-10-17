import SwiftUI
import BusNowCore

struct TopView: View {
    @Binding var path: [BoardRoute]

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 14) {
                    sign(BoardCopy.fujimidaiTitle, stripe: Theme.persimmon, id: "top.fujimidai", hint: "接近しているバス") {
                        path.append(.fujimidai)
                    }
                    sign(BoardCopy.mizonokuchiTitle, stripe: Theme.indigo, id: "top.mizonokuchi", hint: "次の3本") {
                        path.append(.mizonokuchi)
                    }
                }
                .padding(14)
                .frame(minHeight: proxy.size.height)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.asphalt.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func sign(_ title: String, stripe: Color, id: String, hint: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 0) {
                stripe.frame(width: 18)
                Text(title)
                    .font(Theme.maru(56, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.45)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 28)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 240)
            .background(Theme.cream)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Theme.shadow, radius: 0, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .frame(maxHeight: .infinity)
        .accessibilityIdentifier(id)
        .accessibilityLabel(title)
        .accessibilityHint(hint)
    }
}
