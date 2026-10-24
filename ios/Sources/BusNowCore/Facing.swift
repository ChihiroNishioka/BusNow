import Foundation

public enum BoardFacing: String, Codable, Sendable, CaseIterable {
    case fujimidai
    case mizonokuchi
}

/// How the Watch chooses which board is in front.
/// Automatic is morning = Fujimidai departures, afternoon = Mizonokuchi timetable.
public enum FacingMode: String, Codable, Sendable, CaseIterable {
    case automatic
    case fujimidai
    case mizonokuchi
}

public enum FacingChoice {
    /// 00:00–11:59 Asia/Tokyo is morning. Noon and later is afternoon.
    public static func resolve(mode: FacingMode, now: Date) -> BoardFacing {
        switch mode {
        case .fujimidai:
            return .fujimidai
        case .mizonokuchi:
            return .mizonokuchi
        case .automatic:
            return TokyoCalendar.parts(now).hour < 12 ? .fujimidai : .mizonokuchi
        }
    }
}

public enum SharedBoard {
    public static let appGroupID = "group.app.busnow.ios"
    public static let facingDefaultsKey = "busnow.facingMode"

    /// Watch app and complication share this when the app group is entitled.
    /// Unsigned builds fall back to the process's own application-support directory.
    public static func cache() -> BoardCache {
        #if os(Linux)
        return .appSupport()
        #else
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return BoardCache(directory: container.appendingPathComponent("BusNow", isDirectory: true))
        }
        return .appSupport()
        #endif
    }

    public static func facingMode() -> FacingMode {
        if let shared = UserDefaults(suiteName: appGroupID)?.string(forKey: facingDefaultsKey),
           let mode = FacingMode(rawValue: shared) {
            return mode
        }
        if let local = UserDefaults.standard.string(forKey: facingDefaultsKey),
           let mode = FacingMode(rawValue: local) {
            return mode
        }
        return .automatic
    }

    public static func setFacingMode(_ mode: FacingMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: facingDefaultsKey)
        UserDefaults(suiteName: appGroupID)?.set(mode.rawValue, forKey: facingDefaultsKey)
    }
}
