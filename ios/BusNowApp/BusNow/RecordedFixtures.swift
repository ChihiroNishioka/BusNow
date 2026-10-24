import Foundation
import BusNowCore

enum RecordedBoard {
    static func approach() -> ApproachPayload? {
        decode("recorded-approach")
    }

    static func departures() -> DeparturePayload? {
        decode("recorded-departures")
    }

    private static func decode<T: Decodable>(_ name: String) -> T? {
        let url = Bundle.main.url(forResource: name, withExtension: "json")
            ?? Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "RecordedFixtures")
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? BusJSON.decoder().decode(T.self, from: data)
    }
}
