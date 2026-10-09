//
//  NotificationEditUITests.swift
//  nottiUITests
//

import XCTest

final class NotificationEditUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAddAndEditNotification() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        // 追加
        app.navigationBars["通知"].buttons["追加"].tap()
        let field = app.descendants(matching: .any)["messageField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("水を飲む")
        app.navigationBars["通知を追加"].buttons["保存"].tap()
        allowNotificationsIfAsked()

        let row = app.buttons["水を飲む, 1 時間ごと"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        // 編集
        row.tap()
        XCTAssertTrue(app.navigationBars["通知を編集"].waitForExistence(timeout: 5))
        app.buttons["24 時間ごと"].tap()
        app.navigationBars["通知を編集"].buttons["保存"].tap()

        XCTAssertTrue(app.buttons["水を飲む, 24 時間ごと"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAddTimeOfDayNotificationOnSelectedWeekdays() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        app.navigationBars["通知"].buttons["追加"].tap()
        let field = app.descendants(matching: .any)["messageField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("歩数")
        app.buttons["時刻を指定"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["timePicker"].waitForExistence(timeout: 5))

        // 曜日を 1 つも選んでいないうちは保存できない
        app.buttons["曜日を選ぶ"].tap()
        let save = app.navigationBars["通知を追加"].buttons["保存"]
        XCTAssertFalse(save.isEnabled)
        XCTAssertTrue(app.staticTexts["曜日を 1 つ以上選んでください"].exists)

        app.buttons["月曜"].tap()
        XCTAssertTrue(save.isEnabled)
        save.tap()
        allowNotificationsIfAsked()

        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "歩数")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }

    @MainActor
    func testOnceShowsDatePicker() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        app.navigationBars["通知"].buttons["追加"].tap()
        XCTAssertTrue(app.buttons["時刻を指定"].waitForExistence(timeout: 5))
        app.buttons["時刻を指定"].tap()
        app.buttons["1 回だけ"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["onceDatePicker"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["timePicker"].exists)
    }

    @MainActor
    func testUntilDoneToggleShowsNagSettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        app.navigationBars["通知"].buttons["追加"].tap()
        let field = app.descendants(matching: .any)["messageField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("デイリーミッション")
        app.buttons["時刻を指定"].tap()

        let toggle = app.switches["repeatsUntilDoneToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["dayBoundaryPicker"].exists)
        toggle.switches.firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["dayBoundaryPicker"].waitForExistence(timeout: 5))

        // 曜日を選ぶと、日の区切りの代わりに週の始まりを設定する
        app.buttons["曜日を選ぶ"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["weekStartTimePicker"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["dayBoundaryPicker"].exists)

        // 1 回だけにはトグルを出さない
        app.buttons["1 回だけ"].tap()
        XCTAssertFalse(app.switches["repeatsUntilDoneToggle"].exists)

        app.buttons["毎日"].tap()
        let save = app.navigationBars["通知を追加"].buttons["保存"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        allowNotificationsIfAsked()

        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "デイリーミッション")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        // 一覧から完了にして、取り消す
        let complete = app.buttons["完了にする"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()
        XCTAssertTrue(element(containing: "今日は完了済み", in: app).waitForExistence(timeout: 5))
        app.buttons["完了を取り消す"].tap()
        XCTAssertTrue(element(containing: "今日はまだ完了していません", in: app).waitForExistence(timeout: 5))
    }

    /// ラベルに `text` を含む要素。行の文言は、編集ボタンのラベルにまとめられることも、個別の文字として出ることもある
    @MainActor
    private func element(containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// 通知を ON にすると初回だけ出る許可ダイアログ（SpringBoard）を閉じる。2 番目のボタンが「許可」
    @MainActor
    private func allowNotificationsIfAsked() {
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if alert.waitForExistence(timeout: 3) {
            alert.buttons.element(boundBy: 1).tap()
        }
    }
}
