import SwiftUI
import BusNowCore

struct WatchRootView: View {
    let services: BusServices
    @AppStorage(SharedBoard.facingDefaultsKey) private var modeRaw = FacingMode.automatic.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false
    @State private var now = Date()

    var body: some View {
        Group {
            if services.scenario == .recordedComplications {
                ComplicationGallery()
            } else {
                board
            }
        }
        .sheet(isPresented: $showSettings) {
            WatchSettingsView()
        }
        .onAppear {
            now = services.fixedNow ?? Date()
        }
        .onChange(of: scenePhase) { _, phase in
            guard services.scenario == nil else { return }
            if phase == .active {
                now = Date()
            } else {
                WatchRefresh.schedule()
            }
        }
    }

    @ViewBuilder
    private var board: some View {
        let facing = currentFacing
        VStack(spacing: 0) {
            HStack {
                Text(title(facing))
                    .font(WatchTheme.text(16, relativeTo: .headline))
                    .foregroundStyle(accent(facing))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Button("向き") { showSettings = true }
                    .font(WatchTheme.text(13, relativeTo: .caption))
                    .accessibilityIdentifier("settings.open")
            }
            .padding(.horizontal, 6)
            if facing == .fujimidai {
                WatchApproachView(services: services)
            } else {
                WatchDepartureView(services: services)
            }
        }
    }

    private var currentFacing: BoardFacing {
        if let forced = services.launchFacing {
            return forced
        }
        let instant = services.fixedNow ?? now
        let mode = FacingMode(rawValue: modeRaw) ?? .automatic
        return FacingChoice.resolve(mode: mode, now: instant)
    }

    private func title(_ facing: BoardFacing) -> String {
        facing == .fujimidai ? BoardCopy.fujimidaiTitle : BoardCopy.mizonokuchiTitle
    }

    private func accent(_ facing: BoardFacing) -> Color {
        facing == .fujimidai ? WatchTheme.persimmon : WatchTheme.indigo
    }
}
