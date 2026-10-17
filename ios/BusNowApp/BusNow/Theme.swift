import SwiftUI
import UIKit

enum Theme {
    static let asphalt = Color(red: 36.0 / 255, green: 28.0 / 255, blue: 22.0 / 255)
    static let cream = Color(red: 246.0 / 255, green: 239.0 / 255, blue: 226.0 / 255)
    static let persimmon = Color(red: 226.0 / 255, green: 91.0 / 255, blue: 42.0 / 255)
    static let indigo = Color(red: 31.0 / 255, green: 75.0 / 255, blue: 110.0 / 255)
    static let tokyu = Color(red: 193.0 / 255, green: 18.0 / 255, blue: 31.0 / 255)
    static let kawasaki = Color(red: 14.0 / 255, green: 122.0 / 255, blue: 61.0 / 255)
    static let ink = Color(red: 36.0 / 255, green: 28.0 / 255, blue: 22.0 / 255)
    static let quiet = Color(red: 92.0 / 255, green: 81.0 / 255, blue: 70.0 / 255)
    static let warn = Color(red: 138.0 / 255, green: 52.0 / 255, blue: 24.0 / 255)
    static let shadow = Color(red: 26.0 / 255, green: 20.0 / 255, blue: 15.0 / 255)

    static func maru(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        for name in ["HiraMaruProN-W4", "HiraginoMaruGothicProN-W4"] where UIFont(name: name, size: size) != nil {
            return .custom(name, size: size, relativeTo: textStyle)
        }
        let base = UIFont.systemFont(ofSize: size, weight: .black)
        let rounded = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? base
        let scaled = UIFontMetrics(forTextStyle: uiTextStyle(textStyle)).scaledFont(for: rounded)
        return Font(scaled)
    }

    private static func uiTextStyle(_ style: Font.TextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        default: return .body
        }
    }

    static func digits(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .largeTitle) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }
}
