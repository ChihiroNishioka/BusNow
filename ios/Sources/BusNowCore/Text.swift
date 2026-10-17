import Foundation

public func normalizeDigits(_ value: String) -> String {
    var collapsed = ""
    collapsed.reserveCapacity(value.count)
    var pendingSpace = false
    var started = false
    for character in value {
        let mapped: Character
        if let scalar = character.unicodeScalars.first,
           character.unicodeScalars.count == 1,
           (0xFF10...0xFF19).contains(scalar.value) {
            mapped = Character(UnicodeScalar(scalar.value - 0xFF10 + 0x30)!)
        } else {
            mapped = character
        }
        if mapped == "\u{3000}" || mapped == "\u{00A0}" || mapped.isWhitespace {
            if started { pendingSpace = true }
            continue
        }
        if pendingSpace {
            collapsed.append(" ")
            pendingSpace = false
        }
        collapsed.append(mapped)
        started = true
    }
    return collapsed
}

func replacing(_ text: String, pattern: String, with template: String, caseInsensitive: Bool = false) -> String {
    var options: NSRegularExpression.Options = []
    if caseInsensitive { options.insert(.caseInsensitive) }
    guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else {
        return text
    }
    let range = NSRange(text.startIndex..., in: text)
    return expression.stringByReplacingMatches(in: text, range: range, withTemplate: template)
}

struct TextMatch {
    var groups: [String?]
}

func allMatches(_ text: String, pattern: String, caseInsensitive: Bool = false) -> [TextMatch] {
    var options: NSRegularExpression.Options = []
    if caseInsensitive { options.insert(.caseInsensitive) }
    guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else {
        return []
    }
    let range = NSRange(text.startIndex..., in: text)
    return expression.matches(in: text, range: range).map { match in
        let groups = (0..<match.numberOfRanges).map { index -> String? in
            let group = match.range(at: index)
            guard group.location != NSNotFound, let swiftRange = Range(group, in: text) else {
                return nil
            }
            return String(text[swiftRange])
        }
        return TextMatch(groups: groups)
    }
}

func firstMatch(_ text: String, pattern: String, caseInsensitive: Bool = false) -> TextMatch? {
    allMatches(text, pattern: pattern, caseInsensitive: caseInsensitive).first
}

func containsMatch(_ text: String, pattern: String, caseInsensitive: Bool = false) -> Bool {
    firstMatch(text, pattern: pattern, caseInsensitive: caseInsensitive) != nil
}

public func compactRoute(_ value: String) -> String {
    var text = replacing(normalizeDigits(value), pattern: "<br\\s*/?>", with: "・", caseInsensitive: true)
    text = replacing(text, pattern: "<[^>]+>", with: "")
    text = String(text.filter { character in
        !(character.isWhitespace || character == "\u{00A0}" || character == "\u{3000}")
    })
    text = replacing(text, pattern: "・+", with: "・")
    while text.hasPrefix("・") { text.removeFirst() }
    while text.hasSuffix("・") { text.removeLast() }
    return text
}

func group(_ match: TextMatch, _ index: Int) -> String? {
    guard match.groups.indices.contains(index) else { return nil }
    return match.groups[index]
}

public func htmlToText(_ html: String) -> String {
    var text = replacing(html, pattern: "<br\\s*/?>", with: " ", caseInsensitive: true)
    text = replacing(text, pattern: "<[^>]+>", with: " ")
    text = replacing(text, pattern: "&nbsp;", with: " ", caseInsensitive: true)
    text = replacing(text, pattern: "&amp;", with: "&", caseInsensitive: true)
    return normalizeDigits(text)
}

func containsJapanese(_ text: String) -> Bool {
    text.unicodeScalars.contains { scalar in
        (0x3040...0x30FF).contains(scalar.value) || (0x4E00...0x9FFF).contains(scalar.value)
    }
}

func compareJapanese(_ lhs: String, _ rhs: String) -> ComparisonResult {
    lhs.compare(rhs, locale: Locale(identifier: "ja"))
}
