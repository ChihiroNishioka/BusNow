import XCTest
@testable import BusNowCore

final class TokyoCalendarTests: XCTestCase {
    func testHolidaysFor2026() {
        XCTAssertEqual(TokyoCalendar.dayKind("2026-10-12"), .holiday)
        XCTAssertTrue(TokyoCalendar.isHoliday("2026-10-12"))
        XCTAssertEqual(TokyoCalendar.dayKind("2026-10-13"), .weekday)
        XCTAssertEqual(TokyoCalendar.dayKind("2026-10-17"), .saturday)
        XCTAssertTrue(TokyoCalendar.isHoliday("2026-03-20"))
        XCTAssertTrue(TokyoCalendar.isHoliday("2026-09-23"))
        XCTAssertTrue(TokyoCalendar.isHoliday("2026-09-22"))
        XCTAssertEqual(TokyoCalendar.dayKind("2026-05-06"), .holiday)
        XCTAssertTrue(TokyoCalendar.isHoliday("2026-05-06"))
    }

    func testRelativeLabels() {
        XCTAssertEqual(TokyoCalendar.relativeDayLabel(today: "2026-10-13", ymd: "2026-10-13"), "今日")
        XCTAssertEqual(TokyoCalendar.relativeDayLabel(today: "2026-10-13", ymd: "2026-10-14"), "明日")
        XCTAssertEqual(TokyoCalendar.relativeDayLabel(today: "2026-10-13", ymd: "2026-10-18"), "10/18（日）")
    }
}

final class TextTests: XCTestCase {
    func testCompactRouteCollapsesLineBreak() {
        XCTAssertEqual(compactRoute("溝15<br>溝18"), "溝15・溝18")
    }

    func testNormalizeFullwidthDigits() {
        XCTAssertEqual(normalizeDigits("溝２２　０９"), "溝22 09")
    }
}

final class ShiftJISTests: XCTestCase {
    func testMetaCharsetDecodesShiftJIS() throws {
        let prefix = Data("<meta charset=\"shift_jis\">".utf8)
        var bytes = prefix
        bytes.append(0x8A)
        bytes.append(0x4F)
        XCTAssertTrue(try decodePage(bytes).contains("外"))
    }

    func testKawasakiWord() throws {
        let bytes = Data([0x90, 0xEC, 0x8D, 0xE8, 0x8E, 0x73, 0x83, 0x6F, 0x83, 0x58])
        XCTAssertEqual(try ShiftJIS.decode(bytes), "川崎市バス")
    }

    func testUTF8StaysUTF8() throws {
        let html = "<html><head><meta charset=\"utf-8\"></head><body>富士見台</body></html>"
        XCTAssertEqual(try decodePage(Data(html.utf8)), html)
    }
}

final class CountdownTests: XCTestCase {
    func testObservedInstantUsesTodayTokyo() throws {
        let now = try date("2026-10-13T01:52:20.000Z")
        let observed = CountdownMath.observedInstant(now: now, clock: "10:52")
        XCTAssertEqual(observed.timeIntervalSince1970, try date("2026-10-13T01:52:00.000Z").timeIntervalSince1970, accuracy: 0.001)
    }

    func testClockBeforeMidnightStaysYesterday() throws {
        let now = try date("2026-10-13T15:05:00.000Z")
        let observed = CountdownMath.observedInstant(now: now, clock: "23:58")
        XCTAssertEqual(observed.timeIntervalSince1970, try date("2026-10-13T14:58:00.000Z").timeIntervalSince1970, accuracy: 0.001)
    }

    func testCountdownSequence() throws {
        let observed = try date("2026-10-13T01:52:00.000Z")
        let bus = CountdownMath.stamp([sighting(3)], observedAt: observed)[0]
        XCTAssertEqual(try XCTUnwrap(bus.arrivesAt).timeIntervalSince1970, try date("2026-10-13T01:55:00.000Z").timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(CountdownMath.countdown(arrivesAt: bus.arrivesAt, now: observed), .minutes(3))
        XCTAssertEqual(CountdownMath.countdown(arrivesAt: bus.arrivesAt, now: observed.addingTimeInterval(60)), .minutes(2))
        XCTAssertEqual(CountdownMath.countdown(arrivesAt: bus.arrivesAt, now: observed.addingTimeInterval(120)), .minutes(1))
        XCTAssertEqual(CountdownMath.countdown(arrivesAt: bus.arrivesAt, now: observed.addingTimeInterval(180)), .soon)
        XCTAssertEqual(CountdownMath.countdown(arrivesAt: bus.arrivesAt, now: observed.addingTimeInterval(200)), .soon)
        XCTAssertEqual(CountdownMath.countdown(arrivesAt: bus.arrivesAt, now: observed.addingTimeInterval(240)), .past)
    }

    func testMissingMinutesHaveNoArrival() throws {
        let bus = CountdownMath.stamp([sighting(nil)], observedAt: try date("2026-10-13T01:52:00.000Z"))[0]
        XCTAssertNil(bus.arrivesAt)
        XCTAssertEqual(CountdownMath.countdown(arrivesAt: bus.arrivesAt, now: Date()), .unknown)
    }

    func testBasisCaptionOneClock() throws {
        let sources = [
            SourceStatus(operatorName: .tokyu, ok: true, message: nil, updatedAt: "10:52", observedAt: try date("2026-10-13T01:52:00.000Z")),
            SourceStatus(operatorName: .kawasaki, ok: true, message: nil, updatedAt: "10:52", observedAt: try date("2026-10-13T01:52:00.000Z")),
        ]
        XCTAssertEqual(CountdownMath.basisCaption(sources), "10:52時点の情報")
    }

    func testBasisCaptionSeparateClocks() throws {
        let sources = [
            SourceStatus(operatorName: .tokyu, ok: true, message: nil, updatedAt: "10:52", observedAt: try date("2026-10-13T01:52:00.000Z")),
            SourceStatus(operatorName: .kawasaki, ok: true, message: nil, updatedAt: "10:51", observedAt: try date("2026-10-13T01:51:00.000Z")),
        ]
        XCTAssertEqual(CountdownMath.basisCaption(sources), "東急バス 10:52時点 · 川崎市バス 10:51時点")
    }

    func testSpeech() {
        XCTAssertEqual(countdownAccessibilityLabel(.minutes(3), status: "3分待ち"), "あと3分")
        XCTAssertEqual(countdownAccessibilityLabel(.soon, status: "まもなく"), "まもなく到着")
    }
}

final class ParserTests: XCTestCase {
    func testNavitimeCells() {
        let html = """
        <table>
          <tr><th>時</th><th>平日</th><th>土曜</th><th>休日</th></tr>
          <tr>
            <td>6</td>
            <td>02<br>2分はつ 溝22</td>
            <td>10 10分はつ</td>
            <td>09 9分はつ 25 25分はつ</td>
          </tr>
        </table>
        """
        let columns = NavitimeDiagramParser.parse(html)
        XCTAssertEqual(columns.weekday, ["06:02"])
        XCTAssertEqual(columns.saturday, ["06:10"])
        XCTAssertEqual(columns.holiday, ["06:09", "06:25"])
    }

    func testTokyuApproachText() {
        let html = """
        <title>バス接近情報｜富士見台（高津区）→溝の口駅南口</title>
        <div>23:03 <span>時点の情報</span></div>
        <table class="sekkinListTbl">
          <tr><td class="businfo">溝２２ 蟹ヶ谷行【09分待ち】</td></tr>
          <tr><td class="businfo">&nbsp;</td></tr>
          <tr><td class="colmsg">溝22 まもなく</td></tr>
        </table>
        """
        let parsed = TokyuApproach.parse(html)
        XCTAssertNil(parsed.pageError)
        XCTAssertEqual(parsed.updatedAt, "23:03")
        XCTAssertEqual(parsed.buses.count, 2)
        XCTAssertEqual(parsed.buses[0].route, "溝22")
        XCTAssertEqual(parsed.buses[0].minutes, 9)
        XCTAssertEqual(parsed.buses[0].destination, "蟹ヶ谷行")
        XCTAssertEqual(parsed.buses[1].minutes, 0)
        XCTAssertEqual(parsed.buses[1].status, "まもなく")
    }

    func testTokyuRouteDiagramKeepsBusesStillComing() {
        let html = """
        <title>東急バスナビ｜ＰＣ版・路線別運行情報(位置情報)｜溝22</title>
        <div>09:51 <span>時点の情報</span></div>
        <table class="routeListTbl">
          <tr>
            <td class="balloonL"><dd>(折)蟹ヶ谷行 <em></em></dd></td>
            <td class="balloonR">&nbsp;</td>
          </tr>
          <tr>
            <td class="balloonL">&nbsp;</td>
            <td class="balloonR"><dd>蟹ヶ谷行 <em>02分待ち</em></dd></td>
          </tr>
          <tr>
            <td class="balloonL"><dd>溝口南行 <em>04分待ち</em></dd></td>
            <td class="stopName">洗足学園前</td>
          </tr>
          <tr><td class="stopName">富士見台</td><td class="balloonL">&nbsp;</td></tr>
          <tr>
            <td class="balloonL"><dd>溝口南行 <em>06分待ち</em></dd></td>
            <td class="balloonR">&nbsp;</td>
          </tr>
          <tr>
            <td class="balloonL">&nbsp;</td>
            <td class="balloonR"><dd>蟹ヶ谷行 <em>03分待ち</em></dd></td>
          </tr>
          <tr>
            <td class="balloonL"><dd>(折)溝口南行 <em>15分待ち</em></dd></td>
          </tr>
          <tr>
            <td class="balloonL"><dd>溝口南行 <em>まもなく</em></dd></td>
          </tr>
        </table>
        """
        let parsed = TokyuApproach.parse(html)
        XCTAssertNil(parsed.pageError)
        XCTAssertEqual(parsed.updatedAt, "09:51")
        XCTAssertEqual(
            parsed.buses.map { "\($0.route) \($0.destination) \($0.minutes ?? -1)" },
            ["溝22 溝口南行 6", "溝22 (折)溝口南行 15", "溝22 溝口南行 0"]
        )
        XCTAssertEqual(parsed.buses[2].status, "まもなく")
    }

    func testTokyuPhoneDiagram() {
        let html = """
        <title>東急バスナビ｜路線別運行情報(位置情報)｜溝22</title>
        <div>09:51時点の情報</div>
        <table>
          <tr><td><div class="label-u">溝口南行<br /><span class="waittm">01分待ち</span></div></td></tr>
          <tr class="stopline selectedstopline"><td class="stopnm" id="selectStop"><span>富士見台</span></td></tr>
          <tr><td><div class="label-u">溝口南行<br /><span class="waittm">06分待ち</span></div></td></tr>
          <tr><td><div class="label-d">蟹ヶ谷行<br /><span class="waittm">02分待ち</span></div></td></tr>
          <tr><td><div class="label-u">(折)溝口南行<br /><span class="waittm">15分待ち</span></div></td></tr>
        </table>
        """
        let parsed = TokyuApproach.parse(html)
        XCTAssertEqual(
            parsed.buses.map { "\($0.destination) \($0.minutes ?? -1)" },
            ["溝口南行 6", "(折)溝口南行 15"]
        )
    }

    func testKawasakiApproachCardsAndEmptyNight() {
        let live = """
        <title>川崎市 市バスナビ</title>
        <li><i class="fa fa-clock-o"></i>18:12</li>
        <div id="errInfo"></div>
        <div id="buslist">
          <div class="route_box">
            <font style="color: blue;">溝２１</font>
            有馬第二団地前 行き
            約&nbsp;<font size="4">6</font>分で発車します
          </div>
          <div class="route_box">
            <font color="blue">溝23</font>
            梶ヶ谷駅 行き
            まもなく
          </div>
        </div>
        """
        let parsed = KawasakiApproach.parse(live)
        XCTAssertNil(parsed.pageError)
        XCTAssertEqual(parsed.updatedAt, "18:12")
        XCTAssertEqual(parsed.buses.count, 2)
        XCTAssertEqual(parsed.buses[0].route, "溝21")
        XCTAssertEqual(parsed.buses[0].minutes, 6)
        XCTAssertEqual(parsed.buses[0].destination, "有馬第二団地前行き")
        XCTAssertEqual(parsed.buses[1].minutes, 0)
        XCTAssertEqual(parsed.buses[1].status, "まもなく")

        let empty = """
        <title>川崎市 市バスナビ</title>
        <li><i class="fa fa-clock-o"></i>23:05</li>
        <div id="errInfo"><b>60分以内に接近しているバスはありません。</b></div>
        <div id="buslist"></div>
        """
        let night = KawasakiApproach.parse(empty)
        XCTAssertEqual(night.buses.count, 0)
        XCTAssertTrue(night.message?.contains("接近しているバスはありません") == true)
        XCTAssertEqual(night.updatedAt, "23:05")
    }

    func testKawasakiTimetableFixture() throws {
        let html = try fixture("kawasaki-mizo21-weekday", "html")
        let times = KawasakiTimetableParser.parse(html)
        XCTAssertEqual(Array(times.prefix(3)), ["06:08", "06:52", "07:28"])
        XCTAssertFalse(times.contains { $0.hasPrefix("05:") })
    }
}

final class UpcomingTests: XCTestCase {
    func testAfterLastBusNextThreeAreTomorrowMorning() throws {
        let now = try date("2026-10-12T14:30:00Z")
        let snapshot = try TokyuTimetable.bundledSnapshot()
        var trips = snapshot.weekday.prefix(3).map {
            TimedTrip(operatorName: .tokyu, route: "溝22", destination: "蟹ヶ谷行き", dayKind: .weekday, time: $0)
        }
        trips.append(TimedTrip(operatorName: .kawasaki, route: "溝21", destination: "有馬第二団地前行き", dayKind: .weekday, time: "06:08"))
        trips.append(contentsOf: snapshot.holiday.prefix(2).map {
            TimedTrip(operatorName: .tokyu, route: "溝22", destination: "蟹ヶ谷行き", dayKind: .holiday, time: $0)
        })
        let result = UpcomingSelector.select(now: now, trips: trips, limit: 3)
        XCTAssertEqual(result.today, "2026-10-12")
        XCTAssertTrue(result.serviceFinishedToday)
        XCTAssertEqual(result.departures.map { "\($0.time) \($0.operatorName.rawValue)" }, ["06:02 東急バス", "06:08 川崎市バス", "06:11 東急バス"])
        XCTAssertEqual(result.departures[0].whenLabel, "明日")
        XCTAssertEqual(result.departures[0].dayLabel, "平日")
    }

    func testHolidayMorningStaysOnHolidayColumn() throws {
        let now = try date("2026-10-12T00:00:00Z")
        let snapshot = try TokyuTimetable.bundledSnapshot()
        let trips = snapshot.holiday.map {
            TimedTrip(operatorName: .tokyu, route: "溝22", destination: "蟹ヶ谷行き", dayKind: .holiday, time: $0)
        }
        let result = UpcomingSelector.select(now: now, trips: trips, limit: 3)
        XCTAssertFalse(result.serviceFinishedToday)
        XCTAssertEqual(result.departures.count, 3)
        for departure in result.departures {
            XCTAssertEqual(departure.dayLabel, "休日")
            XCTAssertEqual(departure.whenLabel, "今日")
            XCTAssertGreaterThanOrEqual(departure.time, "09:00")
        }
    }
}

final class SnapshotTests: XCTestCase {
    func testBundledRevision() throws {
        let snapshot = try TokyuTimetable.bundledSnapshot()
        XCTAssertEqual(snapshot.revision, "2025-07-01")
        XCTAssertEqual(snapshot.weekday.first, "06:02")
        XCTAssertEqual(snapshot.weekday.last, "22:45")
        XCTAssertEqual(snapshot.saturday.first, "06:09")
        XCTAssertEqual(snapshot.holiday.first, "06:09")
        XCTAssertGreaterThan(snapshot.weekday.count, 20)
        XCTAssertEqual(snapshot.checkedOn, "2026-10-17")
        XCTAssertEqual(snapshot.timetableVerified, false)
        XCTAssertEqual(
            TokyuTimetable.snapshotNote(
                revision: snapshot.revision,
                checkedOn: snapshot.checkedOn,
                verified: snapshot.timetableVerified == true
            ),
            "東急バスの時刻表サイトに接続できなかったため、公式ページ（2025年7月1日改定）から取り込んだ時刻を表示しています。現在のダイヤと異なる可能性があります。2026年10月17日時点では最新かどうか確認できていません。"
        )
    }
}

final class FreshnessTests: XCTestCase {
    func testPastBusesLeaveAndSoonSortsFirst() throws {
        let now = try date("2026-10-17T01:30:00Z")
        let soon = bus("a", minutes: 0, arrives: now)
        let three = bus("b", minutes: 3, arrives: now.addingTimeInterval(180))
        let past = bus("c", minutes: 1, arrives: now.addingTimeInterval(-61))
        let payload = ApproachPayload(fetchedAt: now, buses: [three, past, soon], sources: [
            SourceStatus(operatorName: .tokyu, ok: true, message: nil, updatedAt: "10:30", observedAt: now),
        ])
        let presented = BoardPresentation.approach(payload, now: now)
        XCTAssertEqual(presented.rows.map(\.bus.id), ["a", "b"])
        XCTAssertEqual(presented.rows[0].countdown, .soon)
        XCTAssertNil(presented.hero)
    }

    func testStaleApproachHidesBuses() throws {
        let fetched = try date("2026-10-17T01:00:00Z")
        let now = fetched.addingTimeInterval(6 * 60)
        let payload = ApproachPayload(
            fetchedAt: fetched,
            buses: [bus("a", minutes: 3, arrives: fetched.addingTimeInterval(180))],
            sources: [SourceStatus(operatorName: .tokyu, ok: true, message: nil, updatedAt: "10:00", observedAt: fetched)]
        )
        let presented = BoardPresentation.approach(payload, now: now)
        XCTAssertTrue(presented.rows.isEmpty)
        XCTAssertEqual(presented.freshnessNote, BoardCopy.staleHidden)
        XCTAssertNil(presented.hero)
    }

    func testAgedApproachKeepsBuses() throws {
        let fetched = try date("2026-10-17T01:00:00Z")
        let now = fetched.addingTimeInterval(2 * 60)
        let payload = ApproachPayload(
            fetchedAt: fetched,
            buses: [bus("a", minutes: 8, arrives: fetched.addingTimeInterval(8 * 60))],
            sources: [SourceStatus(operatorName: .tokyu, ok: true, message: nil, updatedAt: "10:00", observedAt: fetched)]
        )
        let presented = BoardPresentation.approach(payload, now: now)
        XCTAssertEqual(presented.rows.count, 1)
        XCTAssertEqual(presented.freshnessNote, "2分前の情報")
    }

    func testBothFailedApproachHasNoEmptyHero() {
        let payload = ApproachPayload(fetchedAt: Date(), buses: [], sources: [
            SourceStatus(operatorName: .tokyu, ok: false, message: "公式ページから取れませんでした", updatedAt: nil),
            SourceStatus(operatorName: .kawasaki, ok: false, message: "公式ページから取れませんでした", updatedAt: nil),
        ])
        let presented = BoardPresentation.approach(payload, now: payload.fetchedAt)
        XCTAssertNil(presented.hero)
        XCTAssertTrue(presented.rows.isEmpty)
    }

    func testDepartureCopy() {
        let failed = DeparturePayload(fetchedAt: Date(), today: "2026-10-17", serviceFinishedToday: false, departures: [], sources: [
            SourceStatus(operatorName: .tokyu, ok: false, message: "x", updatedAt: nil),
            SourceStatus(operatorName: .kawasaki, ok: false, message: "y", updatedAt: nil),
        ])
        XCTAssertEqual(BoardPresentation.departures(failed).hero, BoardCopy.departuresFailed)
        let empty = DeparturePayload(fetchedAt: Date(), today: "2026-10-17", serviceFinishedToday: false, departures: [], sources: [
            SourceStatus(operatorName: .tokyu, ok: true, message: nil, updatedAt: nil),
        ])
        XCTAssertEqual(BoardPresentation.departures(empty).hero, BoardCopy.noMoreDepartures)
    }

    func testReadableError() {
        XCTAssertEqual(ReadableError.message(for: BusTransportError("timeout")), "公式ページが時間内に応答しませんでした")
        XCTAssertEqual(ReadableError.message(for: BusTransportError("HTTP 403 https://example.test")), "公式ページから取れませんでした")
        XCTAssertEqual(ReadableError.message(for: BusTransportError(BoardCopy.offline)), BoardCopy.offline)
    }
}

final class LoaderTests: XCTestCase {
    func testApproachMergesAndSorts() async throws {
        let now = try date("2026-10-13T01:52:20.000Z")
        let stub = StubHTTP()
        stub.route(host: "tokyu.bus-location.jp") { _ in
            htmlResponse("""
            <title>バス接近情報｜富士見台</title>
            <div>10:52時点</div>
            <table class="routeListTbl">
              <tr><td class="stopName">富士見台</td></tr>
              <tr><td class="balloonL">溝口南行 6分待ち</td></tr>
            </table>
            """)
        }
        stub.route(host: "kcbn.bus-navigation.jp") { _ in
            htmlResponse("""
            <title>川崎市 市バスナビ</title>
            <i class="fa fa-clock-o"></i>10:51
            <div id="buslist"><div class="route_box"><font color="blue">溝21</font>有馬第二団地前 行き 約2分で発車します</div></div>
            """)
        }
        let payload = try await ApproachBoardLoader(client: stub.client(), clock: FixedClock(now)).load(now: now)
        XCTAssertEqual(payload.buses.map(\.route), ["溝21", "溝22"])
        XCTAssertEqual(payload.buses.map(\.minutes), [2, 6])
        XCTAssertEqual(payload.sources.map(\.ok), [true, true])
    }

    func testApproachPartialFailure() async throws {
        let stub = StubHTTP()
        stub.route(host: "tokyu.bus-location.jp") { _ in throw BusTransportError("HTTP 500 https://tokyu.example") }
        stub.route(host: "kcbn.bus-navigation.jp") { _ in
            htmlResponse("""
            <title>川崎市 市バスナビ</title>
            <i class="fa fa-clock-o"></i>10:51
            <div id="buslist"><div class="route_box"><font color="blue">溝21</font>有馬第二団地前 行き 約2分で発車します</div></div>
            """)
        }
        let payload = try await ApproachBoardLoader(client: stub.client()).load(now: Date())
        XCTAssertEqual(payload.buses.count, 1)
        XCTAssertEqual(payload.sources[0].ok, false)
        XCTAssertEqual(payload.sources[0].message, "公式ページから取れませんでした")
        XCTAssertEqual(payload.sources[1].ok, true)
    }

    func testApproachBothTransportFailuresThrow() async {
        let stub = StubHTTP()
        stub.route(host: "tokyu.bus-location.jp") { _ in throw BusTransportError("timeout") }
        stub.route(host: "kcbn.bus-navigation.jp") { _ in throw BusTransportError(BoardCopy.offline) }
        do {
            _ = try await ApproachBoardLoader(client: stub.client()).load()
            XCTFail("expected throw")
        } catch {
            XCTAssertFalse(ReadableError.message(for: error).isEmpty)
        }
    }

    func testDeparturesFallBackToSnapshot() async throws {
        let now = try date("2026-10-13T00:00:00Z")
        let stub = StubHTTP()
        stub.route { _ in throw BusTransportError("HTTP 403 https://blocked") }
        let loader = DepartureBoardLoader(client: stub.client(), clock: FixedClock(now), cache: TimetableFetchCache(), store: .memory())
        let payload = try await loader.load(now: now)
        let snapshot = try TokyuTimetable.bundledSnapshot()
        XCTAssertEqual(payload.sources[0].ok, true)
        XCTAssertEqual(
            payload.sources[0].message,
            TokyuTimetable.snapshotNote(
                revision: snapshot.revision,
                checkedOn: snapshot.checkedOn,
                verified: snapshot.timetableVerified == true
            )
        )
        XCTAssertEqual(payload.sources[1].ok, false)
        XCTAssertEqual(payload.departures.prefix(3).map(\.time), ["09:06", "09:15", "09:24"])
        XCTAssertFalse(payload.serviceFinishedToday)
        XCTAssertEqual(payload.departures.first?.whenLabel, "今日")
    }

    func testTokyuLiveReplacesSnapshot() async throws {
        let html = liveDiagram(hours: 6...25)
        let stub = StubHTTP()
        stub.route(host: "transfer.navitime.biz") { _ in htmlResponse(html) }
        stub.route { _ in throw BusTransportError("offline") }
        let store = BoardCache.memory()
        let now = try date("2026-10-13T00:00:00Z")
        let loader = DepartureBoardLoader(client: stub.client(), cache: TimetableFetchCache(), store: store)
        let payload = try await loader.load(now: now, useCache: false)
        XCTAssertNil(payload.sources[0].message)
        XCTAssertEqual(payload.departures.first?.time, "09:10")
        XCTAssertEqual(store.loadTokyu()?.columns.weekday.first, "06:10")
        XCTAssertEqual(store.loadTokyu()?.columns.saturday.first, "06:10")
        XCTAssertEqual(store.loadTokyu()?.columns.holiday.first, "06:10")
    }

    func testSavedTokyuBeatsBundle() async throws {
        let store = BoardCache.memory()
        let savedAt = try date("2026-09-01T00:00:00Z")
        store.saveTokyu(TimetableColumns(weekday: Array(repeating: "07:15", count: 20), saturday: Array(repeating: "07:15", count: 20), holiday: Array(repeating: "07:15", count: 20)), at: savedAt)
        let stub = StubHTTP()
        stub.route { _ in throw BusTransportError("HTTP 403 https://blocked") }
        let result = try await TokyuTimetable.load(stub.client(), now: try date("2026-10-17T01:00:00Z"), cache: TimetableFetchCache(), store: store, useCache: false)
        XCTAssertEqual(result.mode, .saved)
        XCTAssertEqual(result.columns.weekday.first, "07:15")
        XCTAssertEqual(result.note, "9月1日に取得した時刻表を表示しています")
    }

    func testKawasakiTimetableParsesIndex() async throws {
        let store = BoardCache.memory()
        let cache = TimetableFetchCache()
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
        let now = try date("2026-10-13T00:00:00Z")
        let loaded = try await KawasakiTimetable.load(stub.client(), kinds: [.weekday], now: now, cache: cache, store: store)
        XCTAssertNil(loaded.note)
        XCTAssertEqual(loaded.trips.first?.route, "溝21")
        XCTAssertEqual(loaded.trips.first?.destination, "有馬第二団地前行き")
        XCTAssertEqual(loaded.trips.first?.time, "06:08")
        let again = try await KawasakiTimetable.load(stub.client(), kinds: [.weekday], now: now, cache: cache, store: store)
        XCTAssertEqual(again.trips.count, loaded.trips.count)
        XCTAssertEqual(stub.calls.count, 3)
    }

    func testRequestCarriesDesktopUserAgent() throws {
        let request = HTTP.urlRequest(for: HTTPRequest(url: try XCTUnwrap(URL(string: "https://example.test"))))
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), HTTP.userAgent)
        XCTAssertEqual(request.timeoutInterval, 15)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept-Language"), "ja,en;q=0.8")
    }
}

func date(_ text: String) throws -> Date {
    try XCTUnwrap(ISO8601Clock.parse(text))
}

private func sighting(_ minutes: Int?) -> ApproachSighting {
    ApproachSighting(
        id: "bus",
        operatorName: .tokyu,
        route: "溝22",
        destination: "溝口南行",
        minutes: minutes,
        status: minutes == nil ? "接近" : "\(minutes!)分待ち"
    )
}

private func bus(_ id: String, minutes: Int, arrives: Date) -> ApproachBus {
    ApproachBus(
        id: id,
        operatorName: .tokyu,
        route: "溝22",
        destination: "蟹ヶ谷行き",
        minutes: minutes,
        status: "\(minutes)分",
        observedAt: arrives.addingTimeInterval(TimeInterval(-minutes * 60)),
        arrivesAt: arrives
    )
}

func fixture(_ name: String, _ ext: String) throws -> String {
    let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures")
        ?? Bundle.module.url(forResource: name, withExtension: ext)
    return try String(contentsOf: try XCTUnwrap(url), encoding: .utf8)
}

func htmlResponse(_ html: String) -> HTTPResponse {
    HTTPResponse(status: 200, body: Data(html.utf8), url: URL(string: "https://example.test")!)
}

func jsonResponse(_ object: Any) -> HTTPResponse {
    let data = try! JSONSerialization.data(withJSONObject: object)
    return HTTPResponse(status: 200, body: data, url: URL(string: "https://example.test")!)
}

private func liveDiagram(hours: ClosedRange<Int>) -> String {
    var rows = ["<table><tr><th>時</th><th>平日</th><th>土曜</th><th>休日</th></tr>"]
    for hour in hours {
        rows.append("<tr><td>\(hour)</td><td>10分はつ</td><td>10分はつ</td><td>10分はつ</td></tr>")
    }
    rows.append("</table>")
    return rows.joined()
}

final class StubHTTP: @unchecked Sendable {
    struct Route {
        var match: (URL) -> Bool
        var body: (HTTPRequest) throws -> HTTPResponse
    }

    private let lock = NSLock()
    private var routes: [Route] = []
    private(set) var calls: [URL] = []

    func route(host: String? = nil, contains: String? = nil, body: @escaping (HTTPRequest) throws -> HTTPResponse) {
        routes.append(Route(match: { url in
            if let host, url.host != host { return false }
            if let contains, !url.absoluteString.contains(contains) { return false }
            return true
        }, body: body))
    }

    func client() -> HTTPClient {
        HTTPClient { [self] request in
            let route = self.record(request)
            guard let route else { throw BusTransportError("no stub for \(request.url.absoluteString)") }
            return try route.body(request)
        }
    }

    private func record(_ request: HTTPRequest) -> Route? {
        lock.lock()
        defer { lock.unlock() }
        calls.append(request.url)
        return routes.first { $0.match(request.url) }
    }
}
