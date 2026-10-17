import Foundation

final class HTMLNode {
    enum Kind { case element, text }
    let kind: Kind
    let tag: String
    var attributes: [String: String] = [:]
    var children: [HTMLNode] = []
    weak var parent: HTMLNode?
    var textData = ""
    var innerHTML = ""
    var contentStart: String.Index?
    var didClose = false

    init(tag: String, kind: Kind) {
        self.tag = tag
        self.kind = kind
    }

    func finish(_ source: String, _ end: String.Index) {
        if didClose { return }
        didClose = true
        if let contentStart, contentStart <= end {
            innerHTML = String(source[contentStart..<end])
        }
    }

    func textContent() -> String {
        if kind == .text { return textData }
        if tag == "script" || tag == "style" { return "" }
        return children.map { $0.textContent() }.joined()
    }

    func childElements(_ tags: Set<String>) -> [HTMLNode] {
        children.filter { tags.contains($0.tag) }
    }

    func attr(_ name: String) -> String? {
        attributes[name.lowercased()]
    }

    func find(_ selector: String) -> [HTMLNode] {
        let chains = Selector.parse(selector)
        var found: [HTMLNode] = []
        for child in children {
            child.collect(chains, into: &found)
        }
        return found
    }

    private func collect(_ chains: [[SimpleSelector]], into found: inout [HTMLNode]) {
        if chains.contains(where: { Selector.matches(self, chain: $0) }) {
            found.append(self)
        }
        for child in children {
            child.collect(chains, into: &found)
        }
    }
}

struct SimpleSelector {
    var tag: String?
    var id: String?
    var classes: [String]

    func matches(_ node: HTMLNode) -> Bool {
        guard node.kind == .element else { return false }
        if let tag, node.tag != tag { return false }
        if let id, node.attr("id") != id { return false }
        if !classes.isEmpty {
            let tokens = node.attr("class")?
                .split(whereSeparator: { $0.isWhitespace })
                .map(String.init) ?? []
            for name in classes where !tokens.contains(name) {
                return false
            }
        }
        return tag != nil || id != nil || !classes.isEmpty
    }
}

enum Selector {
    static func parse(_ selector: String) -> [[SimpleSelector]] {
        selector.split(separator: ",").map { alternative in
            alternative.split(whereSeparator: { $0.isWhitespace }).map { parseSimple(String($0)) }
        }.filter { !$0.isEmpty }
    }

    static func matches(_ node: HTMLNode, chain: [SimpleSelector]) -> Bool {
        guard let last = chain.last, last.matches(node) else { return false }
        if chain.count == 1 { return true }
        let prefix = Array(chain.dropLast())
        var ancestor = node.parent
        while let current = ancestor {
            if matches(current, chain: prefix) { return true }
            ancestor = current.parent
        }
        return false
    }

    private static func parseSimple(_ token: String) -> SimpleSelector {
        var tag = ""
        var id = ""
        var classes: [String] = []
        var buffer = ""
        var mode = "tag"
        func flush() {
            switch mode {
            case "id": id = buffer
            case "class": if !buffer.isEmpty { classes.append(buffer) }
            default: tag = buffer.lowercased()
            }
            buffer = ""
        }
        for character in token {
            if character == "#" || character == "." {
                flush()
                mode = character == "#" ? "id" : "class"
            } else {
                buffer.append(character)
            }
        }
        flush()
        return SimpleSelector(tag: tag.isEmpty ? nil : tag, id: id.isEmpty ? nil : id, classes: classes)
    }
}

enum HTMLParser {
    private static let voidTags: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr",
    ]

    static let maxCharacters = 1_500_000
    static let maxDepth = 48

    static func parse(_ source: String) -> HTMLNode {
        let limited = source.count > maxCharacters ? String(source.prefix(maxCharacters)) : source
        let root = HTMLNode(tag: "#document", kind: .element)
        var stack = [root]
        var index = limited.startIndex
        var steps = 0
        let stepLimit = limited.count + 8
        while index < limited.endIndex {
            steps += 1
            if steps > stepLimit { break }
            let before = index
            if limited[index] == "<" {
                let next = limited.index(after: index)
                if next >= limited.endIndex {
                    appendText(String(limited[index]), to: stack.last)
                    break
                }
                let marker = limited[next]
                if marker == "!" || marker == "?" {
                    index = skipBang(limited, index)
                } else if marker == "/" {
                    index = closeTag(limited, index, &stack)
                } else if marker.isASCII && marker.isLetter {
                    index = openTag(limited, index, &stack)
                } else {
                    appendText(String(limited[index]), to: stack.last)
                    index = next
                }
            } else {
                let start = index
                while index < limited.endIndex, limited[index] != "<" {
                    index = limited.index(after: index)
                }
                let raw = String(limited[start..<index])
                if !raw.isEmpty {
                    appendText(decodeEntities(raw), to: stack.last)
                }
            }
            if index <= before {
                appendText(String(limited[before]), to: stack.last)
                index = limited.index(after: before)
            }
        }
        while stack.count > 1 {
            let node = stack.removeLast()
            node.finish(limited, limited.endIndex)
        }
        return root
    }

    private static func appendText(_ text: String, to parent: HTMLNode?) {
        guard let parent, !text.isEmpty else { return }
        let node = HTMLNode(tag: "", kind: .text)
        node.textData = text
        node.parent = parent
        parent.children.append(node)
    }

    private static func skipBang(_ source: String, _ start: String.Index) -> String.Index {
        if source[start...].hasPrefix("<!--") {
            if let range = source.range(of: "-->", range: start..<source.endIndex) {
                return range.upperBound
            }
            return source.endIndex
        }
        var index = start
        while index < source.endIndex, source[index] != ">" {
            index = source.index(after: index)
        }
        if index < source.endIndex { index = source.index(after: index) }
        return index
    }

    private static func openTag(_ source: String, _ start: String.Index, _ stack: inout [HTMLNode]) -> String.Index {
        var index = source.index(after: start)
        let nameStart = index
        while index < source.endIndex, isName(source[index]) {
            index = source.index(after: index)
        }
        let tag = source[nameStart..<index].lowercased()
        var attributes: [String: String] = [:]
        var selfClosing = false
        while index < source.endIndex {
            while index < source.endIndex, source[index].isWhitespace {
                index = source.index(after: index)
            }
            if index >= source.endIndex { break }
            if source[index] == ">" {
                index = source.index(after: index)
                break
            }
            if source[index] == "/" {
                let after = source.index(after: index)
                if after < source.endIndex, source[after] == ">" {
                    selfClosing = true
                    index = source.index(after: after)
                    break
                }
                index = after
                continue
            }
            let attributeStart = index
            while index < source.endIndex {
                let character = source[index]
                if character == "=" || character == ">" || character == "/" || character.isWhitespace { break }
                index = source.index(after: index)
            }
            let attribute = source[attributeStart..<index].lowercased()
            while index < source.endIndex, source[index].isWhitespace {
                index = source.index(after: index)
            }
            var value = ""
            if index < source.endIndex, source[index] == "=" {
                index = source.index(after: index)
                while index < source.endIndex, source[index].isWhitespace {
                    index = source.index(after: index)
                }
                if index < source.endIndex, source[index] == "\"" || source[index] == "'" {
                    let quote = source[index]
                    index = source.index(after: index)
                    let valueStart = index
                    while index < source.endIndex, source[index] != quote {
                        index = source.index(after: index)
                    }
                    value = String(source[valueStart..<index])
                    if index < source.endIndex { index = source.index(after: index) }
                } else {
                    let valueStart = index
                    while index < source.endIndex {
                        let character = source[index]
                        if character.isWhitespace || character == ">" { break }
                        index = source.index(after: index)
                    }
                    value = String(source[valueStart..<index])
                }
            }
            if index == attributeStart, index < source.endIndex {
                index = source.index(after: index)
            }
            if !attribute.isEmpty {
                attributes[String(attribute)] = decodeEntities(value)
            }
        }
        impliedClose(tag, at: start, source: source, stack: &stack)
        let node = HTMLNode(tag: String(tag), kind: .element)
        node.attributes = attributes
        node.parent = stack.last
        stack.last?.children.append(node)
        if selfClosing || voidTags.contains(node.tag) {
            node.didClose = true
            return index
        }
        if node.tag == "script" || node.tag == "style" {
            let needle = "</\(node.tag)"
            if let range = source.range(of: needle, options: .caseInsensitive, range: index..<source.endIndex) {
                node.innerHTML = String(source[index..<range.lowerBound])
                node.didClose = true
                var after = range.upperBound
                if let gt = source[after...].firstIndex(of: ">") {
                    after = source.index(after: gt)
                }
                return after
            }
        }
        node.contentStart = index
        if stack.count >= maxDepth {
            node.didClose = true
            return index
        }
        stack.append(node)
        return index
    }

    private static func closeTag(_ source: String, _ start: String.Index, _ stack: inout [HTMLNode]) -> String.Index {
        var index = source.index(start, offsetBy: 2, limitedBy: source.endIndex) ?? source.endIndex
        let nameStart = index
        while index < source.endIndex, isName(source[index]) {
            index = source.index(after: index)
        }
        let tag = source[nameStart..<index].lowercased()
        while index < source.endIndex, source[index] != ">" {
            index = source.index(after: index)
        }
        if index < source.endIndex { index = source.index(after: index) }
        guard stack.contains(where: { $0.tag == tag }) else { return index }
        while let last = stack.last, last.tag != "#document" {
            last.finish(source, start)
            stack.removeLast()
            if last.tag == tag { break }
        }
        return index
    }

    private static func impliedClose(_ tag: String, at end: String.Index, source: String, stack: inout [HTMLNode]) {
        let closable: Set<String>
        switch tag {
        case "td", "th": closable = ["td", "th"]
        case "tr": closable = ["td", "th", "tr"]
        case "li": closable = ["li"]
        case "p": closable = ["p"]
        default: return
        }
        while let last = stack.last, closable.contains(last.tag) {
            last.finish(source, end)
            stack.removeLast()
        }
    }

    private static func isName(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "-" || character == ":"
    }
}

func decodeEntities(_ value: String) -> String {
    guard value.contains("&") else { return value }
    var output = ""
    var index = value.startIndex
    while index < value.endIndex {
        if value[index] == "&" {
            let rest = value[index...]
            if let semicolon = rest.firstIndex(of: ";"), value.distance(from: index, to: semicolon) <= 12 {
                let token = String(value[value.index(after: index)..<semicolon])
                if let decoded = entity(token) {
                    output.append(decoded)
                    index = value.index(after: semicolon)
                    continue
                }
            }
        }
        output.append(value[index])
        index = value.index(after: index)
    }
    return output
}

private func entity(_ token: String) -> String? {
    switch token.lowercased() {
    case "nbsp": return "\u{00A0}"
    case "amp": return "&"
    case "lt": return "<"
    case "gt": return ">"
    case "quot": return "\""
    case "apos": return "'"
    default:
        if token.hasPrefix("#x") || token.hasPrefix("#X") {
            let hex = token.dropFirst(2)
            guard let scalar = UInt32(hex, radix: 16), let unicode = Unicode.Scalar(scalar) else { return nil }
            return String(unicode)
        }
        if token.hasPrefix("#") {
            let digits = token.dropFirst()
            guard let scalar = UInt32(digits), let unicode = Unicode.Scalar(scalar) else { return nil }
            return String(unicode)
        }
        return nil
    }
}
