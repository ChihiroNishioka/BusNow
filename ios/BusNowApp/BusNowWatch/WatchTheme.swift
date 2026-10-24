import SwiftUI

enum WatchTheme {
    static let persimmon = Color(red: 226.0 / 255, green: 91.0 / 255, blue: 42.0 / 255)
    /// Lightened so the Mizonokuchi heading stays above 4.5:1 on the black watch face.
    static let indigo = Color(red: 126.0 / 255, green: 184.0 / 255, blue: 220.0 / 255)
    static let tokyu = Color(red: 193.0 / 255, green: 18.0 / 255, blue: 31.0 / 255)
    static let kawasaki = Color(red: 14.0 / 255, green: 122.0 / 255, blue: 61.0 / 255)
    static let warn = Color(red: 226.0 / 255, green: 160.0 / 255, blue: 120.0 / 255)
    static let quiet = Color(white: 0.75)

    static func text(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("HiraMaruProN-W4", size: size, relativeTo: style)
    }

    static func digits(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}
