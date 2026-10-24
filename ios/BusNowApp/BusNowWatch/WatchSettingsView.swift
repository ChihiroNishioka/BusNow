import SwiftUI
import BusNowCore

struct WatchSettingsView: View {
    @AppStorage(SharedBoard.facingDefaultsKey) private var modeRaw = FacingMode.automatic.rawValue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("向き")
                    .font(WatchTheme.text(16, relativeTo: .headline))
                Text("自動は、午前が富士見台発、午後が溝の口駅南口発です。")
                    .font(WatchTheme.text(12, relativeTo: .caption2))
                    .foregroundStyle(WatchTheme.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                choice(.automatic, title: "自動")
                choice(.fujimidai, title: BoardCopy.fujimidaiTitle)
                choice(.mizonokuchi, title: BoardCopy.mizonokuchiTitle)
            }
            .padding(.horizontal, 4)
        }
        .accessibilityIdentifier("settings.facing")
    }

    private func choice(_ mode: FacingMode, title: String) -> some View {
        Button {
            modeRaw = mode.rawValue
            SharedBoard.setFacingMode(mode)
            dismiss()
        } label: {
            HStack {
                Text(title)
                    .font(WatchTheme.text(15, relativeTo: .body))
                Spacer(minLength: 4)
                if modeRaw == mode.rawValue {
                    Image(systemName: "checkmark")
                }
            }
        }
        .accessibilityIdentifier("settings.\(mode.rawValue)")
    }
}
