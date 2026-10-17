import XCTest

final class BusNowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHomeShowsTwoBoardsAndNotTheAppName() {
        let app = launch(scenario: "home")
        let fuji = app.buttons["top.fujimidai"]
        let mizo = app.buttons["top.mizonokuchi"]
        XCTAssertTrue(fuji.waitForExistence(timeout: 8))
        XCTAssertTrue(mizo.waitForExistence(timeout: 8))
        XCTAssertEqual(fuji.label, "富士見台発")
        XCTAssertEqual(mizo.label, "溝の口駅南口発")
        XCTAssertFalse(app.staticTexts["BusNow!!"].exists)
        XCTAssertFalse(app.staticTexts["BusNow"].exists)
        attach(app, name: "home")
    }

    func testApproachCountdownVoiceOverAndBack() {
        let app = launch(scenario: "approach")
        app.buttons["top.fujimidai"].tap()
        XCTAssertTrue(marked(app, "approach.screen").waitForExistence(timeout: 8))
        let rows = app.descendants(matching: .any).matching(identifier: "approach.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 8))
        XCTAssertEqual(rows.count, 3)
        let labels = (0..<rows.count).map { rows.element(boundBy: $0).label }
        XCTAssertTrue(labels.contains("東急バス、溝22、(折)溝口南行、まもなく到着"), labels.joined(separator: " | "))
        XCTAssertTrue(labels.contains("東急バス、溝22、蟹ヶ谷行き、あと3分"), labels.joined(separator: " | "))
        XCTAssertTrue(labels.contains("川崎市バス、溝21、有馬第二団地前行き、あと9分"), labels.joined(separator: " | "))
        XCTAssertTrue(app.staticTexts["まもなく"].exists)
        attach(app, name: "approach")
        app.buttons["board.back"].tap()
        XCTAssertTrue(app.buttons["top.mizonokuchi"].waitForExistence(timeout: 8))
    }

    func testDeparturesShowsNextThreeAndOfflineNote() {
        let app = launch(scenario: "departures", start: "departures")
        XCTAssertTrue(marked(app, "departure.screen").waitForExistence(timeout: 8))
        let rows = app.descendants(matching: .any).matching(identifier: "departure.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 8))
        XCTAssertEqual(rows.count, 3)
        let labels = (0..<rows.count).map { rows.element(boundBy: $0).label }
        XCTAssertTrue(labels.contains { $0.hasPrefix("10:41、東急バス、溝22、蟹ヶ谷行き、今日、土曜") })
        XCTAssertTrue(labels.contains { $0.hasPrefix("10:53、川崎市バス、溝21、有馬第二団地前行き、今日、土曜") })
        XCTAssertTrue(labels.contains { $0.hasPrefix("11:07、東急バス、溝22、蟹ヶ谷行き、今日、土曜") })
        XCTAssertTrue(app.staticTexts["10:41"].exists)
        let note = marked(app, "board.note")
        XCTAssertTrue(note.waitForExistence(timeout: 4))
        XCTAssertTrue(note.label.contains("2025年7月1日改定"))
        attach(app, name: "departures")
    }

    func testDeparturesFinishedShowsTomorrowMorning() {
        let app = launch(scenario: "departures-finished", start: "departures")
        let banner = marked(app, "board.finished")
        XCTAssertTrue(banner.waitForExistence(timeout: 8))
        XCTAssertEqual(banner.label, "きょうの運行は終わりました")
        let rows = app.descendants(matching: .any).matching(identifier: "departure.row")
        XCTAssertEqual(rows.count, 3)
        let labels = (0..<rows.count).map { rows.element(boundBy: $0).label }
        XCTAssertTrue(labels.contains { $0.hasPrefix("06:02、") && $0.contains("明日、平日") })
        XCTAssertTrue(labels.contains { $0.hasPrefix("06:08、") && $0.contains("明日、平日") })
        XCTAssertTrue(labels.contains { $0.hasPrefix("06:11、") && $0.contains("明日、平日") })
        attach(app, name: "departures-finished")
    }

    func testApproachPartialShowsBusAndWarning() {
        let app = launch(scenario: "approach-partial", start: "approach")
        let rows = app.descendants(matching: .any).matching(identifier: "approach.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 8))
        XCTAssertEqual(rows.count, 1)
        XCTAssertTrue(rows.firstMatch.label.contains("あと3分"))
        let warn = marked(app, "board.warn")
        XCTAssertTrue(warn.waitForExistence(timeout: 4))
        XCTAssertTrue(warn.label.contains("公式ページから取れませんでした"))
        XCTAssertFalse(app.staticTexts["接近しているバスはありません"].exists)
        attach(app, name: "approach-partial")
    }

    func testApproachBothFailHidesEmptyHero() {
        let app = launch(scenario: "approach-down", start: "approach")
        XCTAssertTrue(marked(app, "approach.screen").waitForExistence(timeout: 8))
        let warns = app.descendants(matching: .any).matching(identifier: "board.warn")
        XCTAssertTrue(warns.firstMatch.waitForExistence(timeout: 4))
        XCTAssertEqual(warns.count, 2)
        XCTAssertFalse(app.staticTexts["接近しているバスはありません"].exists)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "approach.row").count, 0)
        attach(app, name: "approach-down")
    }

    func testApproachEmptyHero() {
        let app = launch(scenario: "approach-empty", start: "approach")
        let hero = marked(app, "board.hero")
        XCTAssertTrue(hero.waitForExistence(timeout: 8))
        XCTAssertEqual(hero.label, "接近しているバスはありません")
        attach(app, name: "approach-empty")
    }

    func testApproachInitialFailureShowsRetry() {
        let app = launch(scenario: "approach-failed", start: "approach")
        let hero = marked(app, "board.hero")
        XCTAssertTrue(hero.waitForExistence(timeout: 8))
        XCTAssertEqual(hero.label, "うまく取れませんでした")
        XCTAssertTrue(app.staticTexts["公式ページから取れませんでした"].exists)
        XCTAssertTrue(app.buttons["board.retry"].exists)
        attach(app, name: "approach-failed")
    }

    func testDeparturesBothFail() {
        let app = launch(scenario: "departures-down", start: "departures")
        let hero = marked(app, "board.hero")
        XCTAssertTrue(hero.waitForExistence(timeout: 8))
        XCTAssertEqual(hero.label, "うまく取れませんでした")
        XCTAssertTrue(app.buttons["board.retry"].exists)
        attach(app, name: "departures-down")
    }

    func testDynamicTypeAccessibilityExtraExtraExtraExtraExtraLargeStillShowsBothBoards() {
        let app = launch(
            scenario: "home",
            extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraExtraExtraLarge"]
        )
        let fuji = app.buttons["top.fujimidai"]
        let mizo = app.buttons["top.mizonokuchi"]
        XCTAssertTrue(fuji.waitForExistence(timeout: 8))
        XCTAssertTrue(mizo.waitForExistence(timeout: 8))
        var swipes = 0
        while !mizo.isHittable && swipes < 4 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(mizo.isHittable)
        fuji.tap()
        XCTAssertTrue(app.staticTexts["富士見台発"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["まもなく"].waitForExistence(timeout: 8))
        app.buttons["board.back"].tap()
        XCTAssertTrue(mizo.waitForExistence(timeout: 8))
        var backSwipes = 0
        while !mizo.isHittable && backSwipes < 4 {
            app.swipeUp()
            backSwipes += 1
        }
        mizo.tap()
        XCTAssertTrue(app.staticTexts["10:41"].waitForExistence(timeout: 8))
        attach(app, name: "home-ax5")
    }

    private func launch(scenario: String, start: String? = nil, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-busnow-scenario", scenario]
        if let start {
            app.launchArguments += ["-busnow-start", start]
        }
        app.launchArguments += extra
        app.launch()
        return app
    }

    private func marked(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
