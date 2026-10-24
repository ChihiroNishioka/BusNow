import XCTest
@testable import BusNowCore

final class FacingTests: XCTestCase {
    func testMorningIsFujimidaiAndNoonIsMizonokuchi() throws {
        let morning = try XCTUnwrap(ISO8601Clock.parse("2026-10-24T02:59:00Z"))
        let noon = try XCTUnwrap(ISO8601Clock.parse("2026-10-24T03:00:00Z"))
        XCTAssertEqual(TokyoCalendar.parts(morning).hour, 11)
        XCTAssertEqual(TokyoCalendar.parts(noon).hour, 12)
        XCTAssertEqual(FacingChoice.resolve(mode: .automatic, now: morning), .fujimidai)
        XCTAssertEqual(FacingChoice.resolve(mode: .automatic, now: noon), .mizonokuchi)
    }

    func testFacingModeOverridesTheClock() throws {
        let morning = try XCTUnwrap(ISO8601Clock.parse("2026-10-24T01:00:00Z"))
        XCTAssertEqual(FacingChoice.resolve(mode: .mizonokuchi, now: morning), .mizonokuchi)
        XCTAssertEqual(FacingChoice.resolve(mode: .fujimidai, now: morning), .fujimidai)
    }
}

final class ComplicationBoardTests: XCTestCase {
    func testApproachComplicationCountsDownFromTheFetchAndShowsTheClock() throws {
        let fetched = try date("2026-10-24T02:07:00Z")
        let bus = ApproachBus(
            id: "live",
            operatorName: .tokyu,
            route: "溝22",
            destination: "蟹ヶ谷行き",
            minutes: 4,
            status: "4分待ち",
            observedAt: fetched,
            arrivesAt: fetched.addingTimeInterval(4 * 60)
        )
        let payload = ApproachPayload(fetchedAt: fetched, buses: [bus], sources: [
            SourceStatus(operatorName: .tokyu, ok: true, message: nil, updatedAt: "11:07", observedAt: fetched),
        ])
        let content = ComplicationBoard.content(facing: .fujimidai, approach: payload, departures: nil, now: fetched)
        XCTAssertEqual(content.headline, "溝22")
        XCTAssertTrue(content.showsTimer)
        XCTAssertEqual(content.arrivesAt, bus.arrivesAt)
        XCTAssertEqual(content.freshness, "取得 11:07")
        XCTAssertFalse(content.stale)
        XCTAssertEqual(ComplicationBoard.timerText(arrivesAt: bus.arrivesAt!, now: fetched), "4:00")
        let aged = fetched.addingTimeInterval(120)
        let later = ComplicationBoard.content(facing: .fujimidai, approach: payload, departures: nil, now: aged)
        XCTAssertEqual(later.freshness, "取得 11:07 · 2分前の情報")
        XCTAssertEqual(ComplicationBoard.timerText(arrivesAt: bus.arrivesAt!, now: aged), "2:00")
    }

    func testStaleApproachHidesTheCountdown() throws {
        let fetched = try date("2026-10-24T02:00:00Z")
        let now = fetched.addingTimeInterval(6 * 60)
        let bus = ApproachBus(
            id: "old",
            operatorName: .kawasaki,
            route: "溝21",
            destination: "有馬第二団地前行き",
            minutes: 9,
            status: "約9分で発車",
            observedAt: fetched,
            arrivesAt: fetched.addingTimeInterval(9 * 60)
        )
        let payload = ApproachPayload(fetchedAt: fetched, buses: [bus], sources: [
            SourceStatus(operatorName: .kawasaki, ok: true, message: nil, updatedAt: "11:00", observedAt: fetched),
        ])
        let content = ComplicationBoard.content(facing: .fujimidai, approach: payload, departures: nil, now: now)
        XCTAssertTrue(content.stale)
        XCTAssertFalse(content.showsTimer)
        XCTAssertNil(content.arrivesAt)
        XCTAssertEqual(content.headline, "古い")
        XCTAssertTrue(content.freshness.contains("取得 11:00"))
    }

    func testMissingApproachIsAnErrorNotAFakeBus() {
        let content = ComplicationBoard.content(facing: .fujimidai, approach: nil, departures: nil, now: Date())
        XCTAssertEqual(content.headline, "失敗")
        XCTAssertEqual(content.detail, BoardCopy.departuresFailed)
        XCTAssertFalse(content.showsTimer)
        XCTAssertNil(content.arrivesAt)
    }

    func testDepartureComplicationKeepsTheUnverifiedTimetableNote() throws {
        let now = try date("2026-10-24T02:07:00Z")
        let departure = Departure(
            id: "next",
            operatorName: .tokyu,
            route: "溝22",
            destination: "蟹ヶ谷行き",
            time: "11:17",
            date: "2026-10-24",
            dayLabel: "土曜",
            whenLabel: "今日"
        )
        let payload = DeparturePayload(
            fetchedAt: now,
            today: "2026-10-24",
            serviceFinishedToday: false,
            departures: [departure],
            sources: [
                SourceStatus(
                    operatorName: .tokyu,
                    ok: true,
                    message: TokyuTimetable.snapshotNote(revision: "2025-07-01", checkedOn: "2026-10-24", verified: false),
                    updatedAt: nil
                ),
            ]
        )
        let content = ComplicationBoard.content(facing: .mizonokuchi, approach: nil, departures: payload, now: now)
        XCTAssertEqual(content.headline, "11:17")
        XCTAssertTrue(content.timetableUnverified)
        XCTAssertTrue(content.freshness.contains("取得 11:07"))
        XCTAssertTrue(content.freshness.contains("ダイヤ未確認"))
    }

    func testTimelineEntriesStayAtLeastFiveMinutesApart() throws {
        let now = try date("2026-10-24T02:07:00Z")
        let soon = Departure(
            id: "a",
            operatorName: .tokyu,
            route: "溝22",
            destination: "蟹ヶ谷行き",
            time: "11:08",
            date: "2026-10-24",
            dayLabel: "土曜",
            whenLabel: "今日"
        )
        let later = Departure(
            id: "b",
            operatorName: .kawasaki,
            route: "溝21",
            destination: "有馬第二団地前行き",
            time: "11:20",
            date: "2026-10-24",
            dayLabel: "土曜",
            whenLabel: "今日"
        )
        let payload = DeparturePayload(
            fetchedAt: now,
            today: "2026-10-24",
            serviceFinishedToday: false,
            departures: [soon, later],
            sources: [SourceStatus(operatorName: .tokyu, ok: true, message: nil, updatedAt: nil)]
        )
        let moments = ComplicationBoard.timeline(facing: .mizonokuchi, approach: nil, departures: payload, now: now)
        XCTAssertGreaterThanOrEqual(moments.count, 2)
        for pair in zip(moments, moments.dropFirst()) {
            XCTAssertGreaterThanOrEqual(pair.1.date.timeIntervalSince(pair.0.date), ComplicationBoard.minimumEntrySpacing)
        }
        XCTAssertEqual(moments.first?.content.headline, "11:08")
        let handoff = try XCTUnwrap(moments.dropFirst().first)
        XCTAssertEqual(handoff.content.headline, "11:20")
        XCTAssertGreaterThanOrEqual(handoff.date.timeIntervalSince(now), ComplicationBoard.minimumEntrySpacing)
        XCTAssertEqual(ComplicationBoard.reloadInterval, 30 * 60)
        XCTAssertLessThanOrEqual(86_400 / ComplicationBoard.reloadInterval, 70)
        XCTAssertGreaterThanOrEqual(86_400 / ComplicationBoard.reloadInterval, 40)
    }

    func testApproachIsStaleAtExactlyFiveMinutes() throws {
        let fetched = try date("2026-10-24T02:00:00Z")
        let staleAt = fetched.addingTimeInterval(BoardPresentation.approachStaleAfter)
        let bus = ApproachBus(
            id: "edge",
            operatorName: .tokyu,
            route: "溝22",
            destination: "溝口南行",
            minutes: 3,
            status: "3分待ち",
            observedAt: fetched,
            arrivesAt: fetched.addingTimeInterval(3 * 60)
        )
        let payload = ApproachPayload(fetchedAt: fetched, buses: [bus], sources: [
            SourceStatus(operatorName: .tokyu, ok: true, message: nil, updatedAt: "11:00", observedAt: fetched),
        ])
        let presented = BoardPresentation.approach(payload, now: staleAt)
        XCTAssertTrue(presented.rows.isEmpty)
        XCTAssertEqual(presented.freshnessNote, BoardCopy.staleHidden)
        let content = ComplicationBoard.content(facing: .fujimidai, approach: payload, departures: nil, now: staleAt)
        XCTAssertTrue(content.stale)
        XCTAssertEqual(content.headline, "古い")
        XCTAssertFalse(content.showsTimer)
        let moments = ComplicationBoard.timeline(facing: .fujimidai, approach: payload, departures: nil, now: fetched)
        XCTAssertEqual(moments.last?.date, staleAt)
        XCTAssertEqual(moments.last?.content.stale, true)
    }

    func testDepartureTimelineHandsOffAfterTheGrace() throws {
        let now = try date("2026-10-24T02:19:00Z")
        func trip(_ time: String, _ route: String) -> Departure {
            Departure(
                id: time,
                operatorName: route == "溝22" ? .tokyu : .kawasaki,
                route: route,
                destination: "溝の口方面",
                time: time,
                date: "2026-10-24",
                dayLabel: "土曜",
                whenLabel: "今日"
            )
        }
        let payload = DeparturePayload(
            fetchedAt: now,
            today: "2026-10-24",
            serviceFinishedToday: false,
            departures: [trip("11:25", "溝25"), trip("11:28", "溝22"), trip("11:35", "溝23")],
            sources: [SourceStatus(operatorName: .kawasaki, ok: true, message: nil, updatedAt: nil)]
        )
        let moments = ComplicationBoard.timeline(facing: .mizonokuchi, approach: nil, departures: payload, now: now)
        XCTAssertEqual(moments.first?.content.headline, "11:25")
        let handoff = try XCTUnwrap(moments.dropFirst().first)
        let printed = try XCTUnwrap(BoardPresentation.departureDate(payload.departures[0]))
        XCTAssertGreaterThanOrEqual(handoff.date.timeIntervalSince(printed), BoardPresentation.departureGrace)
        XCTAssertEqual(handoff.content.headline, "11:28")
        XCTAssertFalse(handoff.content.detail.contains("溝25"))
        for pair in zip(moments, moments.dropFirst()) {
            XCTAssertGreaterThanOrEqual(pair.1.date.timeIntervalSince(pair.0.date), ComplicationBoard.minimumEntrySpacing)
        }
    }

    func testPlaceholderDoesNotInventADeparture() {
        let content = ComplicationBoard.placeholder(now: Date())
        XCTAssertEqual(content.detail, "取得中")
        XCTAssertNil(content.arrivesAt)
        XCTAssertFalse(content.showsTimer)
    }
}

final class RecordedFixtureTests: XCTestCase {
    func testRecordedBoardsAreTheOctober24Fetch() throws {
        let directory = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("BusNowApp/RecordedFixtures")
        let approachData = try Data(contentsOf: directory.appendingPathComponent("recorded-approach.json"))
        let departureData = try Data(contentsOf: directory.appendingPathComponent("recorded-departures.json"))
        let approach = try BusJSON.decoder().decode(ApproachPayload.self, from: approachData)
        let departures = try BusJSON.decoder().decode(DeparturePayload.self, from: departureData)

        XCTAssertEqual(TokyoCalendar.formatClock(approach.fetchedAt), "11:19")
        XCTAssertEqual(TokyoCalendar.formatClock(departures.fetchedAt), "11:19")
        XCTAssertEqual(approach.stop, "富士見台")
        XCTAssertEqual(approach.buses.count, 8)
        let first = try XCTUnwrap(approach.buses.first)
        XCTAssertEqual(first.operatorName, .tokyu)
        XCTAssertEqual(first.route, "溝22")
        XCTAssertEqual(first.destination, "溝口南行")
        XCTAssertEqual(first.minutes, 3)
        XCTAssertEqual(first.status, "3分待ち")
        let arrives = try XCTUnwrap(first.arrivesAt)
        XCTAssertEqual(CountdownMath.countdown(arrivesAt: arrives, now: approach.fetchedAt), .minutes(3))
        XCTAssertEqual(ComplicationBoard.timerText(arrivesAt: arrives, now: approach.fetchedAt), "2:02")
        XCTAssertTrue(approach.sources.allSatisfy(\.ok))

        XCTAssertEqual(departures.departures.map(\.time), ["11:25", "11:28", "11:35"])
        XCTAssertEqual(departures.departures.map(\.route), ["溝25", "溝22", "溝23"])
        let tokyu = try XCTUnwrap(departures.sources.first { $0.operatorName == .tokyu }?.message)
        XCTAssertTrue(tokyu.contains("2026年10月24日"))
        XCTAssertTrue(tokyu.contains("確認できていません"))
        let kawasaki = try XCTUnwrap(departures.sources.first { $0.operatorName == .kawasaki }?.message)
        XCTAssertTrue(kawasaki.contains("一部の路線の時刻表を取れませんでした"))

        let blob = try XCTUnwrap(String(data: approachData + departureData, encoding: .utf8))
        XCTAssertFalse(blob.contains("10:41"))
        let source = try String(contentsOf: directory.appendingPathComponent("SOURCE.txt"), encoding: .utf8)
        XCTAssertTrue(source.hasPrefix("statusBar=11:19\n"))
        XCTAssertTrue(source.contains("時刻は作っていません"))
        XCTAssertTrue(source.contains("文字盤の写真ではない"))
        XCTAssertTrue(source.contains("simctl status_bar override に対応していない"))
        XCTAssertTrue(source.contains("departures-finished"))
        XCTAssertTrue(source.contains("approach-partial"))
    }
}

final class ShiftJISBundleTests: XCTestCase {
    func testBundledCp932ExistsAndDecodes() throws {
        let url = try XCTUnwrap(BundledResources.url("cp932", "bin"))
        let data = try Data(contentsOf: url)
        XCTAssertEqual(Array(data.prefix(4)), [0x43, 0x50, 0x39, 0x32])
        XCTAssertEqual(data.count, 57_632)
        let table = try ShiftJIS.parseTable(data)
        XCTAssertEqual(table.count, 9604)
        XCTAssertEqual(try ShiftJIS.decode(Data([0x8E, 0x9E, 0x95, 0xAA])), "時分")
        XCTAssertThrowsError(try ShiftJIS.parseTable(Data())) { error in
            XCTAssertEqual(error as? ShiftJISTableError, .invalid)
        }
    }
}
