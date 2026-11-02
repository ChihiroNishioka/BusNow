import XCTest
@testable import BusNowCore

final class BusNowWatchTests: XCTestCase {
    func testWatchOSUsesTheSameFacingAndShiftJISTable() throws {
        let morning = try XCTUnwrap(ISO8601Clock.parse("2026-10-24T01:07:00Z"))
        let afternoon = try XCTUnwrap(ISO8601Clock.parse("2026-10-24T06:00:00Z"))
        XCTAssertEqual(FacingChoice.resolve(mode: .automatic, now: morning), .fujimidai)
        XCTAssertEqual(FacingChoice.resolve(mode: .automatic, now: afternoon), .mizonokuchi)
        let url = try XCTUnwrap(BundledResources.url("cp932", "bin"))
        let data = try Data(contentsOf: url)
        XCTAssertEqual(try ShiftJIS.parseTable(data).count, 9604)
        XCTAssertEqual(try ShiftJIS.decode(Data([0x8E, 0x9E, 0x95, 0xAA])), "時分")
    }
}
