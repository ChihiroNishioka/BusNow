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
            guard services.scenario == nil, phase == .active else { return }
            now = Date()
        }
    }

    @ViewBuilder
    private var board: some View {
        let facing = currentFacing
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    heading(facing)
                    Spacer(minLength: 8)
                    settingsButton
                }
                VStack(alignment: .leading, spacing: 2) {
                    heading(facing)
                    settingsButton
                }
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

    private func heading(_ facing: BoardFacing) -> some View {
        Text(title(facing))
            .font(WatchTheme.text(16, relativeTo: .headline))
            .foregroundStyle(accent(facing))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .layoutPriority(1)
            .accessibilityIdentifier("board.title")
    }

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Text("向き")
                .font(WatchTheme.text(13, relativeTo: .caption))
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityIdentifier("settings.open")
    }

    private func title(_ facing: BoardFacing) -> String {
        facing == .fujimidai ? BoardCopy.fujimidaiTitle : BoardCopy.mizonokuchiTitle
    }

    private func accent(_ facing: BoardFacing) -> Color {
        facing == .fujimidai ? WatchTheme.persimmon : WatchTheme.indigo
    }
}
