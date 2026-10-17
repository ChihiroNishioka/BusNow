import Foundation

public struct KawasakiApproachParse: Equatable, Sendable {
    public var buses: [ApproachSighting]
    public var updatedAt: String?
    public var message: String?
    public var pageError: String?
}

public enum KawasakiApproach {
    public static func pageURL() -> URL {
        var components = URLComponents(string: "https://kcbn.bus-navigation.jp/wgsys/wgp/bus.htm")!
        components.queryItems = [
            URLQueryItem(name: "from", value: "富士見台"),
            URLQueryItem(name: "fromType", value: "1"),
            URLQueryItem(name: "to", value: "溝口駅南口"),
            URLQueryItem(name: "toType", value: "1"),
            URLQueryItem(name: "locale", value: "ja"),
            URLQueryItem(name: "tabName", value: "searchTab"),
            URLQueryItem(name: "bsid", value: "1"),
            URLQueryItem(name: "mapFlag", value: "false"),
            URLQueryItem(name: "existYn", value: "N"),
            URLQueryItem(name: "nextDiagramFlag", value: "0"),
        ]
        return components.url!
    }

    public static func parse(_ html: String) -> KawasakiApproachParse {
        if !html.contains("市バスナビ") && !html.contains("buslist") {
            return KawasakiApproachParse(buses: [], updatedAt: nil, message: nil, pageError: "川崎市バスナビの接近ページではありません")
        }
        let root = HTMLParser.parse(html)
        let updated = firstMatch(html, pattern: "fa-clock-o\"\\s*>\\s*</i>\\s*(\\d{1,2}:\\d{2})")?.groups.dropFirst().first ?? nil
        let hasBuslist = !root.find("#buslist").isEmpty
        let hasNotice = !root.find("#errInfo").isEmpty
        if !hasBuslist && !hasNotice {
            return KawasakiApproachParse(
                buses: [],
                updatedAt: updated,
                message: nil,
                pageError: "川崎市バスナビの接近情報の形が分かりません"
            )
        }
        let notice = normalizeDigits(root.find("#errInfo").map { $0.textContent() }.joined())
        var buses: [ApproachSighting] = []
        for (index, box) in root.find("#buslist .route_box").enumerated() {
            let text = normalizeDigits(htmlToText(box.innerHTML))
            let route = routeFromBox(box, text: text)
            if route.isEmpty { continue }
            let destinationMatch = firstMatch(text, pattern: "(\\S{1,24}?)\\s*行き")
            let minutesMatch = firstMatch(text, pattern: "約\\s*([0-9]{1,2})\\s*分で発車")
            let soon = containsMatch(text, pattern: "まもなく")
            let minutes: Int? = soon ? 0 : minutesMatch.flatMap { match in
                (match.groups.dropFirst().first ?? nil).flatMap(Int.init)
            }
            let status = soon ? "まもなく" : (minutesMatch != nil ? "約\(minutes ?? 0)分で発車" : "接近")
            let place = destinationMatch.flatMap { $0.groups.dropFirst().first ?? nil }
            buses.append(
                ApproachSighting(
                    id: "kawasaki-\(route)-\(minutes.map(String.init) ?? "x")-\(index)",
                    operatorName: .kawasaki,
                    route: route,
                    destination: place.map { "\($0)行き" } ?? "溝口駅南口方面",
                    minutes: minutes,
                    status: status
                )
            )
        }
        let noBus = containsMatch(notice.isEmpty ? html : notice, pattern: "接近しているバスはありません")
        if buses.isEmpty && !hasNotice && !noBus {
            return KawasakiApproachParse(
                buses: [],
                updatedAt: updated,
                message: nil,
                pageError: "川崎市バスナビの接近情報の形が分かりません"
            )
        }
        let message: String?
        if noBus {
            message = notice
        } else if buses.isEmpty {
            message = notice.isEmpty ? BoardCopy.approachEmpty : notice
        } else {
            message = nil
        }
        return KawasakiApproachParse(buses: buses, updatedAt: updated, message: message, pageError: nil)
    }

    static func load(_ client: HTTPClient) async -> OperatorOutcome {
        do {
            let html = try await HTTP.fetchText(client, pageURL())
            let parsed = parse(html)
            if let pageError = parsed.pageError {
                return OperatorOutcome(buses: [], source: failed(.kawasaki, pageError), transportFailed: false)
            }
            return OperatorOutcome(
                buses: parsed.buses,
                source: SourceStatus(operatorName: .kawasaki, ok: true, message: parsed.message, updatedAt: parsed.updatedAt),
                transportFailed: false
            )
        } catch {
            if BoardClock.isCancellation(error) || Task.isCancelled {
                return OperatorOutcome(buses: [], source: failed(.kawasaki, ""), transportFailed: false, cancelled: true)
            }
            return OperatorOutcome(
                buses: [],
                source: failed(.kawasaki, ReadableError.message(for: error)),
                transportFailed: true
            )
        }
    }

    private static func routeFromBox(_ box: HTMLNode, text: String) -> String {
        for node in box.find("font") {
            let color = "\(node.attr("color") ?? "") \(node.attr("style") ?? "")".lowercased()
            let blue = color.contains("blue") || color.contains("#00f") || color.contains("0000ff") || color.contains("0000ee")
            if !blue { continue }
            let label = compactRoute(node.textContent())
            if !label.isEmpty { return label }
        }
        if let match = firstMatch(text, pattern: "溝\\s*[0-9]{2}"), let raw = match.groups.first ?? nil {
            return compactRoute(raw)
        }
        return ""
    }
}
