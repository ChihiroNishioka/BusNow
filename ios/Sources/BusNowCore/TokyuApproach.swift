import Foundation

public struct TokyuApproachParse: Equatable, Sendable {
    public var buses: [ApproachSighting]
    public var updatedAt: String?
    public var pageError: String?
}

public enum TokyuApproach {
    public static let pageURL = URL(string: "https://tokyu.bus-location.jp/blsys/navi?VID=rsc&EID=nt&RAMK=61&SCT=2&DSMK=2994&DSN=%E5%AF%8C%E5%A3%AB%E8%A6%8B%E5%8F%B0%EF%BC%88%E9%AB%98%E6%B4%A5%E5%8C%BA%EF%BC%89&ASMK=2991&ASN=%E6%BA%9D%E3%81%AE%E5%8F%A3%E9%A7%85%E5%8D%97%E5%8F%A3&FDSN=0&FASN=0&CTYP=0")!

    public static func parse(_ html: String) -> TokyuApproachParse {
        if containsMatch(html, pattern: "セッションタイムアウト|ページが見つかりません") {
            return TokyuApproachParse(buses: [], updatedAt: nil, pageError: "東急バスナビのセッションを開始できませんでした")
        }
        if !html.contains("バス接近情報") && !html.contains("富士見台") {
            return TokyuApproachParse(buses: [], updatedAt: nil, pageError: "東急バスナビの接近ページではありません")
        }
        let root = HTMLParser.parse(html)
        let plain = htmlToText(html)
        let updated = firstMatch(plain, pattern: "(\\d{1,2}:\\d{2})\\s*時点")?.groups.dropFirst().first ?? nil
        var buses: [ApproachSighting] = []
        if !root.find("table.routeListTbl").isEmpty {
            for item in busesOnRouteDiagram(root) {
                var copy = item
                copy.id = "\(item.id)-\(buses.count)"
                buses.append(copy)
            }
        } else if !root.find("#selectStop").isEmpty {
            for item in busesOnPhoneDiagram(root) {
                var copy = item
                copy.id = "\(item.id)-\(buses.count)"
                buses.append(copy)
            }
        } else {
            for (index, element) in root.find("td.businfo, td.colmsg").enumerated() {
                let fragment = element.innerHTML
                let text = normalizeDigits(htmlToText(fragment))
                if text.isEmpty || text == " " { continue }
                for item in busesFromTokyuText(text) {
                    var copy = item
                    copy.id = "\(item.id)-\(index)-\(buses.count)"
                    buses.append(copy)
                }
            }
        }
        return TokyuApproachParse(buses: dedupe(buses), updatedAt: updated, pageError: nil)
    }

    static func load(_ client: HTTPClient) async -> OperatorOutcome {
        do {
            let html = try await HTTP.fetchText(client, pageURL)
            let parsed = parse(html)
            if let pageError = parsed.pageError {
                return OperatorOutcome(buses: [], source: failed(.tokyu, pageError), transportFailed: false)
            }
            let empty = parsed.buses.isEmpty ? BoardCopy.approachEmpty : nil
            return OperatorOutcome(
                buses: parsed.buses,
                source: SourceStatus(operatorName: .tokyu, ok: true, message: empty, updatedAt: parsed.updatedAt),
                transportFailed: false
            )
        } catch {
            return OperatorOutcome(
                buses: [],
                source: failed(.tokyu, ReadableError.message(for: error)),
                transportFailed: true
            )
        }
    }

    private static func busesOnRouteDiagram(_ root: HTMLNode) -> [ApproachSighting] {
        let rows = root.find("table.routeListTbl tr")
        return busesAfterFujimidai(rows) { row in
            normalizeDigits(row.find("td.balloonL").map { $0.textContent() }.joined())
        }
    }

    private static func busesOnPhoneDiagram(_ root: HTMLNode) -> [ApproachSighting] {
        busesAfterFujimidai(root.find("tr")) { row in
            normalizeDigits(row.find(".label-u").map { $0.textContent() }.joined())
        }
    }

    private static func busesAfterFujimidai(
        _ rows: [HTMLNode],
        textOf: (HTMLNode) -> String
    ) -> [ApproachSighting] {
        var sawFujimidai = false
        var found: [ApproachSighting] = []
        for row in rows {
            let stop = normalizeDigits(row.find(".stopName, .stopnm").map { $0.textContent() }.joined())
                .replacingOccurrences(of: " ", with: "")
            if containsMatch(stop, pattern: "^富士見台(?:[（(]|$)") || !row.find("#selectStop").isEmpty {
                sawFujimidai = true
                continue
            }
            let text = textOf(row)
            if text.isEmpty { continue }
            if sawFujimidai, let item = busTowardMizonokuchi(text) {
                found.append(item)
            }
        }
        if sawFujimidai { return found }
        return rows.compactMap { busTowardMizonokuchi(textOf($0)) }
    }

    private static func busTowardMizonokuchi(_ text: String) -> ApproachSighting? {
        guard let match = firstMatch(text, pattern: "((?:\\(折\\)|（折）)\\s*)?(溝口\\S{0,8}行)\\s*(?:(\\d{1,2})\\s*分待ち|まもなく)"),
              let destinationCore = match.groups.dropFirst(2).first ?? nil
        else { return nil }
        let turn = match.groups.dropFirst().first ?? nil
        let minutesText = match.groups.dropFirst(3).first ?? nil
        let soon = minutesText == nil
        let minutes = soon ? 0 : Int(minutesText ?? "") ?? 0
        let destination = "\(turn == nil ? "" : "(折)")\(destinationCore)"
        return bus(route: "溝22", destination: destination, minutes: minutes, status: soon ? "まもなく" : "\(minutes)分待ち")
    }

    private static func busesFromTokyuText(_ text: String) -> [ApproachSighting] {
        var found: [ApproachSighting] = []
        for match in allMatches(text, pattern: "溝\\s*([0-9]{2})([\\s\\S]{0,40}?)([0-9]{1,2})\\s*分待ち") {
            guard let route = match.groups.dropFirst().first ?? nil,
                  let chunk = match.groups.dropFirst(2).first ?? nil,
                  let minutesText = match.groups.dropFirst(3).first ?? nil,
                  let minutes = Int(minutesText)
            else { continue }
            found.append(bus(route: "溝\(route)", destination: destinationFrom(chunk), minutes: minutes, status: "\(minutes)分待ち"))
        }
        for match in allMatches(text, pattern: "溝\\s*([0-9]{2})([\\s\\S]{0,40}?)まもなく") {
            guard let route = match.groups.dropFirst().first ?? nil,
                  let chunk = match.groups.dropFirst(2).first ?? nil
            else { continue }
            found.append(bus(route: "溝\(route)", destination: destinationFrom(chunk), minutes: 0, status: "まもなく"))
        }
        return found
    }

    private static func destinationFrom(_ chunk: String) -> String {
        let cleaned = chunk.replacingOccurrences(of: "【", with: " ")
            .replacingOccurrences(of: "】", with: " ")
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
        if let match = firstMatch(cleaned, pattern: "([^\\d]{1,16})行"),
           let bound = match.groups.dropFirst().first ?? nil {
            let stem = bound.replacingOccurrences(of: "行き?$", with: "", options: .regularExpression)
            return stem + "行"
        }
        return "溝の口方面"
    }

    private static func bus(route: String, destination: String, minutes: Int, status: String) -> ApproachSighting {
        let compact = compactRoute(route)
        return ApproachSighting(
            id: "tokyu-\(compact)-\(minutes)-\(status)",
            operatorName: .tokyu,
            route: compact,
            destination: destination,
            minutes: minutes,
            status: status
        )
    }

    private static func dedupe(_ buses: [ApproachSighting]) -> [ApproachSighting] {
        var seen = Set<String>()
        return buses.filter { bus in
            if seen.contains(bus.id) { return false }
            seen.insert(bus.id)
            return true
        }
    }
}

struct OperatorOutcome: Sendable {
    var buses: [ApproachSighting]
    var source: SourceStatus
    var transportFailed: Bool
}

func failed(_ name: BusOperator, _ message: String) -> SourceStatus {
    SourceStatus(operatorName: name, ok: false, message: message, updatedAt: nil)
}
