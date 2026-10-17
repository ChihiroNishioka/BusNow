import Foundation

public enum NavitimeDiagramParser {
    public static func parse(_ html: String) -> TimetableColumns {
        let root = HTMLParser.parse(html)
        var columns = TimetableColumns.empty
        var indexes: [DayKind: Int] = [:]
        var sawHeader = false
        for row in root.find("tr") {
            let cells = row.childElements(["th", "td"])
            if cells.count < 2 { continue }
            let labels = cells.map { htmlToText($0.innerHTML.isEmpty ? $0.textContent() : $0.innerHTML) }
            if labels.contains(where: { $0.contains("平日") }) {
                indexes = [:]
                for (index, label) in labels.enumerated() {
                    if label.contains("平日") { indexes[.weekday] = index }
                    if label.contains("土曜") { indexes[.saturday] = index }
                    if label.contains("休日") { indexes[.holiday] = index }
                }
                sawHeader = true
                continue
            }
            if !sawHeader { continue }
            guard let hourMatch = firstMatch(labels.first ?? "", pattern: "(\\d{1,2})"),
                  let hourText = hourMatch.groups.dropFirst().first ?? nil,
                  let hour = Int(hourText),
                  hour <= 27
            else { continue }
            for kind in [DayKind.weekday, .saturday, .holiday] {
                guard let index = indexes[kind], cells.indices.contains(index) else { continue }
                let cellHTML = cells[index].innerHTML
                let text = replacing(cellHTML, pattern: "<[^>]+>", with: " ")
                let spaced = replacing(text, pattern: "&nbsp;", with: " ", caseInsensitive: true)
                for match in allMatches(spaced, pattern: "(\\d{1,2})\\s*分はつ") {
                    guard let minuteText = match.groups.dropFirst().first ?? nil,
                          let minute = Int(minuteText),
                          minute <= 59
                    else { continue }
                    let stamp = String(format: "%02d:%02d", hour, minute)
                    switch kind {
                    case .weekday: columns.weekday.append(stamp)
                    case .saturday: columns.saturday.append(stamp)
                    case .holiday: columns.holiday.append(stamp)
                    }
                }
            }
        }
        if columns.weekday.isEmpty && columns.saturday.isEmpty {
            return .empty
        }
        return columns
    }
}
