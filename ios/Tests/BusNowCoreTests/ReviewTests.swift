import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import BusNowCore

final class HTMLRegressionTests: XCTestCase {
    func testBareLessThanIsText() {
        let root = HTMLParser.parse("1 < 2")
        XCTAssertTrue(root.textContent().contains("1"))
        XCTAssertTrue(root.textContent().contains("2"))
        XCTAssertTrue(root.textContent().contains("<"))
    }

    func testProcessingInstructionDoesNotStall() {
        let root = HTMLParser.parse("<?xml version=\"1.0\"?><p>ok</p>")
        XCTAssertTrue(root.textContent().contains("ok"))
    }

    func testStraySlashInsideTagDoesNotStall() {
        let root = HTMLParser.parse("<div / class=\"a\">text</div>")
        XCTAssertEqual(root.find("div").first?.attr("class"), "a")
        XCTAssertTrue(root.textContent().contains("text"))
    }

    func testManyBareLessThanFinish() {
        let root = HTMLParser.parse(String(repeating: "<", count: 8_000))
        XCTAssertEqual(root.textContent().count, 8_000)
    }
}

final class ClockRegressionTests: XCTestCase {
    func testDisplayClockDoesNotRewindToFetch() throws {
        let ticking = try date("2026-10-17T15:00:30Z")
        let fetchedAt = try date("2026-10-17T14:59:30Z")
        XCTAssertEqual(BoardClock.displayNow(ticking: ticking, fetchedAt: fetchedAt), ticking)
    }

    func testPollWaitShrinksByFetchTime() throws {
        let started = try date("2026-10-17T01:00:00Z")
        XCTAssertEqual(BoardClock.waitAfterPoll(started: started, finished: started.addingTimeInterval(12)), 18, accuracy: 0.001)
        XCTAssertEqual(BoardClock.waitAfterPoll(started: started, finished: started.addingTimeInterval(40)), 0, accuracy: 0.001)
    }

    func testCancellationDetection() {
        XCTAssertTrue(BoardClock.isCancellation(CancellationError()))
        XCTAssertTrue(BoardClock.isCancellation(URLError(.cancelled)))
        XCTAssertFalse(BoardClock.isCancellation(BusTransportError("timeout")))
    }

    func testDayKindsCoverTheUpcomingWindow() {
        XCTAssertEqual(BoardClock.dayKinds(on: "2026-10-17", through: 3), [.saturday, .holiday, .weekday])
        XCTAssertEqual(BoardClock.dayKinds(on: "2026-10-14", through: 3), [.weekday, .saturday])
        XCTAssertEqual(BoardClock.dayKinds(on: "2026-10-16", through: 3), [.weekday, .saturday, .holiday])
    }

    func testReceivedTimePlacesMidnightClockOnTheNewDay() async throws {
        let start = try date("2026-10-17T14:59:30Z")
        let clock = MutableClock(start)
        let stub = StubHTTP()
        stub.route(host: "tokyu.bus-location.jp") { _ in
            clock.advance(by: 60)
            return htmlResponse("""
            <title>バス接近情報｜富士見台</title>
            <div>00:05時点</div>
            <table class="routeListTbl">
              <tr><td class="stopName">富士見台</td></tr>
              <tr><td class="balloonL">溝口南行 6分待ち</td></tr>
            </table>
            """)
        }
        stub.route(host: "kcbn.bus-navigation.jp") { _ in
            htmlResponse("""
            <title>川崎市 市バスナビ</title>
            <i class="fa fa-clock-o"></i>00:05
            <div id="errInfo">60分以内に接近しているバスはありません。</div>
            <div id="buslist"></div>
            """)
        }
        let payload = try await ApproachBoardLoader(client: stub.client(), clock: clock).load()
        let observed = try XCTUnwrap(payload.buses.first?.observedAt)
        XCTAssertEqual(TokyoCalendar.parts(observed).ymd, "2026-10-18")
        XCTAssertEqual(TokyoCalendar.parts(payload.fetchedAt).ymd, "2026-10-18")
        XCTAssertGreaterThan(payload.fetchedAt, start)
        XCTAssertEqual(BoardClock.displayNow(ticking: clock.now(), fetchedAt: start), clock.now())
    }
}

final class TimetableRegressionTests: XCTestCase {
    func testWeekdayOnlyLiveDoesNotReplaceSnapshot() async throws {
        var rows = ["<table><tr><th>時</th><th>平日</th><th>土曜</th><th>休日</th></tr>"]
        for hour in 6...25 {
            rows.append("<tr><td>\(hour)</td><td>10分はつ</td><td></td><td></td></tr>")
        }
        rows.append("</table>")
        let stub = StubHTTP()
        stub.route(host: "transfer.navitime.biz") { _ in htmlResponse(rows.joined()) }
        stub.route { _ in throw BusTransportError("offline") }
        let store = BoardCache.memory()
        let now = try date("2026-10-13T00:00:00Z")
        let payload = try await DepartureBoardLoader(client: stub.client(), cache: TimetableFetchCache(), store: store).load(now: now, useCache: false)
        XCTAssertNil(store.loadTokyu())
        XCTAssertEqual(payload.sources[0].ok, true)
        XCTAssertTrue(payload.sources[0].message?.contains("現在のダイヤと異なる可能性があります") == true)
        XCTAssertEqual(payload.departures.first?.time, "09:06")
    }

    func testIncompleteSavedTokyuDoesNotHideSnapshot() async throws {
        let store = BoardCache.memory()
        store.saveTokyu(TimetableColumns(weekday: Array(repeating: "07:15", count: 20), saturday: [], holiday: []), at: try date("2026-09-01T00:00:00Z"))
        let stub = StubHTTP()
        stub.route { _ in throw BusTransportError("HTTP 403 https://blocked") }
        let result = try await TokyuTimetable.load(stub.client(), now: try date("2026-10-17T01:00:00Z"), cache: TimetableFetchCache(), store: store, useCache: false)
        XCTAssertEqual(result.mode, .snapshot)
        XCTAssertEqual(result.ok, true)
        XCTAssertNotEqual(result.columns.weekday.first, "07:15")
        XCTAssertTrue(result.note?.contains("確認できていません") == true)
    }

    func testMissingSnapshotIsAFailure() {
        let missing = TokyuTimetable.resultFromSnapshot(nil)
        XCTAssertFalse(missing.ok)
        XCTAssertEqual(missing.note, TokyuTimetable.unavailableNote)
        let payload = DeparturePayload(
            fetchedAt: Date(),
            today: "2026-10-17",
            serviceFinishedToday: false,
            departures: [],
            sources: [
                SourceStatus(operatorName: .tokyu, ok: false, message: missing.note, updatedAt: nil),
                SourceStatus(operatorName: .kawasaki, ok: false, message: "公式ページから取れませんでした", updatedAt: nil),
            ]
        )
        XCTAssertEqual(BoardPresentation.departures(payload).hero, BoardCopy.departuresFailed)
    }

    func testKawasakiMergeKeepsOtherDays() async throws {
        let store = BoardCache.memory()
        let savedAt = try date("2026-10-01T00:00:00Z")
        store.saveKawasaki([
            ScheduledTrip(operatorName: .kawasaki, route: "溝25", destination: "鷲ヶ峰営業所行き", dayKind: .saturday, time: "07:00"),
        ], at: savedAt)
        let html = try fixture("kawasaki-mizo21-weekday", "html").replacingOccurrences(of: "Shift_JIS", with: "utf-8")
        let stub = StubHTTP()
        stub.route(contains: "timeTableRouteTabFile.htm") { _ in
            jsonResponse(["filePath": "/wgp/timeTable/mizo21.html", "errorFlg": "0"])
        }
        stub.route(contains: "timeTableRouteTab.htm") { _ in
            jsonResponse([
                "timeTableRouteDestinationSubData": [[
                    "timeTableRollsignNameJP": "溝21",
                    "timeTableDestinationNameJP": "有馬第二団地前",
                    "noteJP": NSNull(),
                    "timeTableHtmlList": ["平日"],
                    "timeTableHtmlListLink": ["20261001,mizo21.html"],
                ]],
            ])
        }
        stub.route(contains: "mizo21.html") { _ in htmlResponse(html) }
        let loaded = try await KawasakiTimetable.load(
            stub.client(),
            kinds: [.weekday],
            now: try date("2026-10-13T00:00:00Z"),
            cache: TimetableFetchCache(),
            store: store,
            useCache: false
        )
        let stored = try XCTUnwrap(store.loadKawasaki()?.trips)
        XCTAssertTrue(stored.contains { $0.dayKind == .saturday && $0.route == "溝25" && $0.time == "07:00" })
        XCTAssertTrue(stored.contains { $0.dayKind == .weekday && $0.route == "溝21" && $0.time == "06:08" })
        XCTAssertTrue(loaded.trips.contains { $0.route == "溝25" })
        XCTAssertNil(loaded.note)
    }

    func testEmptyKawasakiPageDoesNotReplaceSave() async throws {
        let store = BoardCache.memory()
        store.saveKawasaki([
            ScheduledTrip(operatorName: .kawasaki, route: "溝21", destination: "有馬第二団地前行き", dayKind: .weekday, time: "06:08"),
        ], at: try date("2026-10-01T00:00:00Z"))
        let stub = StubHTTP()
        stub.route(contains: "timeTableRouteTabFile.htm") { _ in
            jsonResponse(["filePath": "/wgp/timeTable/empty.html", "errorFlg": "0"])
        }
        stub.route(contains: "timeTableRouteTab.htm") { _ in
            jsonResponse([
                "timeTableRouteDestinationSubData": [[
                    "timeTableRollsignNameJP": "溝21",
                    "timeTableDestinationNameJP": "有馬第二団地前",
                    "noteJP": NSNull(),
                    "timeTableHtmlList": ["平日"],
                    "timeTableHtmlListLink": ["20261001,empty.html"],
                ]],
            ])
        }
        stub.route(contains: "empty.html") { _ in htmlResponse("<html><meta charset=\"utf-8\"><body>空</body></html>") }
        let loaded = try await KawasakiTimetable.load(
            stub.client(),
            kinds: [.weekday],
            now: try date("2026-10-13T00:00:00Z"),
            cache: TimetableFetchCache(),
            store: store,
            useCache: false
        )
        XCTAssertEqual(store.loadKawasaki()?.trips.map(\.time), ["06:08"])
        XCTAssertEqual(loaded.trips.map(\.time), ["06:08"])
        XCTAssertEqual(loaded.note, "10月1日に取得した時刻表を表示しています")
    }

    func testOneKawasakiDetailFailureKeepsTheOtherRoute() async throws {
        let html = try fixture("kawasaki-mizo21-weekday", "html").replacingOccurrences(of: "Shift_JIS", with: "utf-8")
        let stub = StubHTTP()
        stub.route(contains: "timeTableRouteTabFile.htm") { request in
            let body = String(data: request.body ?? Data(), encoding: .utf8) ?? ""
            if body.contains("mizo23") {
                return jsonResponse(["filePath": "", "errorFlg": "1"])
            }
            return jsonResponse(["filePath": "/wgp/timeTable/mizo21.html", "errorFlg": "0"])
        }
        stub.route(contains: "timeTableRouteTab.htm") { _ in
            jsonResponse([
                "timeTableRouteDestinationSubData": [
                    [
                        "timeTableRollsignNameJP": "溝21",
                        "timeTableDestinationNameJP": "有馬第二団地前",
                        "noteJP": NSNull(),
                        "timeTableHtmlList": ["平日"],
                        "timeTableHtmlListLink": ["20261001,mizo21.html"],
                    ],
                    [
                        "timeTableRollsignNameJP": "溝23",
                        "timeTableDestinationNameJP": "蔵敷",
                        "noteJP": NSNull(),
                        "timeTableHtmlList": ["平日"],
                        "timeTableHtmlListLink": ["20261001,mizo23.html"],
                    ],
                ],
            ])
        }
        stub.route(contains: "mizo21.html") { _ in htmlResponse(html) }
        let store = BoardCache.memory()
        let loaded = try await KawasakiTimetable.load(
            stub.client(),
            kinds: [.weekday],
            now: try date("2026-10-13T00:00:00Z"),
            cache: TimetableFetchCache(),
            store: store,
            useCache: false
        )
        XCTAssertTrue(loaded.trips.contains { $0.route == "溝21" && $0.time == "06:08" })
        XCTAssertFalse(loaded.trips.contains { $0.route == "溝23" })
        XCTAssertEqual(loaded.note, "一部の路線の時刻表を取れませんでした")
    }

    func testShiftJISTableRejectsGarbage() {
        XCTAssertThrowsError(try ShiftJIS.parseTable(Data())) { error in
            XCTAssertEqual(error as? ShiftJISTableError, .invalid)
        }
        var short = Data([0x43, 0x50, 0x39, 0x32, 1, 0, 0, 0])
        short.append(contentsOf: [0, 0, 0, 0, 0, 0])
        XCTAssertThrowsError(try ShiftJIS.parseTable(short))
    }

    func testKawasakiParserReadsRealShiftJISBytes() throws {
        var bytes = Data("<html><head><meta charset=\"Shift_JIS\"></head><body><table><tr><td>6".utf8)
        bytes.append(contentsOf: [0x8E, 0x9E])
        bytes.append(contentsOf: Data("</td><td>08".utf8))
        bytes.append(contentsOf: [0x95, 0xAA])
        bytes.append(contentsOf: Data("</td></tr></table></body></html>".utf8))
        let html = try decodePage(bytes)
        XCTAssertTrue(html.contains("時"))
        XCTAssertEqual(KawasakiTimetableParser.parse(html).first, "06:08")
    }
}

final class ApproachStructureTests: XCTestCase {
    func testTokyuPageWithoutKnownStructureIsAnError() {
        let html = "<title>バス接近情報｜富士見台</title><p>準備中</p>"
        let parsed = TokyuApproach.parse(html)
        XCTAssertEqual(parsed.pageError, "東急バスナビの接近情報の形が分かりません")
        XCTAssertTrue(parsed.buses.isEmpty)
    }

    func testTokyuOfficialEmptyStaysEmpty() {
        let html = "<title>バス接近情報｜富士見台</title><p>接近しているバスはありません</p>"
        let parsed = TokyuApproach.parse(html)
        XCTAssertNil(parsed.pageError)
        XCTAssertTrue(parsed.buses.isEmpty)
    }

    func testKawasakiPageWithoutKnownStructureIsAnError() {
        let html = "<title>川崎市 市バスナビ</title><p>メンテナンス</p>"
        let parsed = KawasakiApproach.parse(html)
        XCTAssertEqual(parsed.pageError, "川崎市バスナビの接近情報の形が分かりません")
    }

    func testCancelledApproachDoesNotReturnABoard() async {
        let stub = StubHTTP()
        stub.route(host: "tokyu.bus-location.jp") { _ in throw CancellationError() }
        stub.route(host: "kcbn.bus-navigation.jp") { _ in
            htmlResponse("""
            <title>川崎市 市バスナビ</title>
            <div id="buslist"><div class="route_box"><font color="blue">溝21</font>有馬 行き 約2分で発車します</div></div>
            """)
        }
        do {
            _ = try await ApproachBoardLoader(client: stub.client()).load()
            XCTFail("expected cancellation")
        } catch is CancellationError {
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testAgedEmptyApproachKeepsTheFreshnessNote() throws {
        let fetched = try date("2026-10-17T01:28:00Z")
        let now = try date("2026-10-17T01:30:00Z")
        let past = ApproachBus(
            id: "past",
            operatorName: .tokyu,
            route: "溝22",
            destination: "蟹ヶ谷行き",
            minutes: 1,
            status: "1分",
            observedAt: fetched,
            arrivesAt: now.addingTimeInterval(-120)
        )
        let payload = ApproachPayload(fetchedAt: fetched, buses: [past], sources: [
            SourceStatus(operatorName: .tokyu, ok: true, message: nil, updatedAt: "10:28", observedAt: fetched),
        ])
        let presented = BoardPresentation.approach(payload, now: now)
        XCTAssertTrue(presented.rows.isEmpty)
        XCTAssertEqual(presented.hero, BoardCopy.approachEmpty)
        XCTAssertEqual(presented.freshnessNote, "2分前の情報")
    }
}
