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

    @MainActor
    func testAddMonthlyNotificationOnSelectedDays() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        app.navigationBars["通知"].buttons["追加"].tap()
        let field = app.descendants(matching: .any)["messageField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("家賃")
        app.buttons["時刻を指定"].tap()
        XCTAssertTrue(app.buttons["毎月"].waitForExistence(timeout: 5))
        app.buttons["毎月"].tap()

        // 日付も月末も選んでいないうちは保存できない
        let save = app.navigationBars["通知を追加"].buttons["保存"]
        XCTAssertFalse(save.isEnabled)
        // 日付の格子の下の注意書きを画面に出す（キーボードと格子で隠れるため）
        app.swipeUp()
        XCTAssertTrue(element(containing: "日付か月末を 1 つ以上選んでください", in: app).waitForExistence(timeout: 5))

        let tenth = app.buttons["10 日"]
        XCTAssertTrue(tenth.waitForExistence(timeout: 5))
        tenth.tap()
        XCTAssertTrue(tenth.isSelected)
        app.buttons["31 日"].tap()
        XCTAssertTrue(element(containing: "その日が無い月には鳴りません", in: app).waitForExistence(timeout: 5))
        app.buttons["31 日"].tap()
        XCTAssertTrue(element(containing: "その日が無い月には鳴りません", in: app).waitForNonExistence(timeout: 5))
        app.buttons["27 日"].tap()

        // 月末を ON にすると、何日前かの欄と、3 か月で止まる旨の注意書きが出る
        let monthEnd = app.switches["monthEndToggle"]
        XCTAssertTrue(monthEnd.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["monthEndOffsetPicker"].exists)
        monthEnd.switches.firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["monthEndOffsetPicker"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "3 か月アプリを開かないと", in: app).exists)
        monthEnd.switches.firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["monthEndOffsetPicker"].waitForNonExistence(timeout: 5))

        XCTAssertTrue(save.isEnabled)
        save.tap()
        allowNotificationsIfAsked()

        XCTAssertTrue(element(containing: "毎月 10・27 日 9:00", in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    func testMonthlyUntilDoneSelectsOneDay() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        app.navigationBars["通知"].buttons["追加"].tap()
        XCTAssertTrue(app.buttons["時刻を指定"].waitForExistence(timeout: 5))
        app.buttons["時刻を指定"].tap()
        app.buttons["毎月"].tap()
        let tenth = app.buttons["10 日"]
        XCTAssertTrue(tenth.waitForExistence(timeout: 5))
        tenth.tap()
        app.buttons["27 日"].tap()

        // ON にすると、最も早い日付だけ残す。日の区切り・週の始まりの欄は出さない（トグルは日付の格子の下にある）
        app.swipeUp()
        let toggle = app.switches["repeatsUntilDoneToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.switches.firstMatch.tap()
        XCTAssertTrue(tenth.isSelected)
        XCTAssertFalse(app.buttons["27 日"].isSelected)
        XCTAssertFalse(app.descendants(matching: .any)["dayBoundaryPicker"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["weekStartTimePicker"].exists)

        // ON のうちは 1 つだけ選べる。月末を ON にすると日付を外す
        app.buttons["15 日"].tap()
        XCTAssertTrue(app.buttons["15 日"].isSelected)
        XCTAssertFalse(tenth.isSelected)
        app.switches["monthEndToggle"].switches.firstMatch.tap()
        XCTAssertFalse(app.buttons["15 日"].isSelected)

        // 文言の欄は Form の一番上にある。下の「アプリを開く」の節まで送ると画面から外れるため、上に戻す
        // Form は画面外の欄を要素として持たないので、押せるようになるまで上に戻す
        let field = app.descendants(matching: .any)["messageField"]
        for _ in 0..<3 where !(field.exists && field.isHittable) {
            app.swipeDown()
        }
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("締め日")
        let save = app.navigationBars["通知を追加"].buttons["保存"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        allowNotificationsIfAsked()

        XCTAssertTrue(element(containing: "毎月 月末 9:00・完了まで", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "今月はまだ完了していません", in: app).waitForExistence(timeout: 5))
        app.buttons["完了にする"].tap()
        XCTAssertTrue(element(containing: "今月は完了済み", in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    func testLinkURLIsSavedAndShownWhenEditing() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        app.navigationBars["通知"].buttons["追加"].tap()
        let field = app.descendants(matching: .any)["messageField"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("水を飲む")

        // 「アプリを開く」の節は Form の一番下にある
        app.swipeUp()
        let linkField = app.textFields["linkURLField"]
        XCTAssertTrue(linkField.waitForExistence(timeout: 15))
        linkField.tap()
        linkField.typeText("https://example.com")
        app.navigationBars["通知を追加"].buttons["保存"].tap()
        allowNotificationsIfAsked()

        // もう一度開くと、入れた URL が残っている
        let row = app.buttons["水を飲む, 1 時間ごと"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()
        XCTAssertTrue(app.navigationBars["通知を編集"].waitForExistence(timeout: 15))
        app.swipeUp()
        let savedLinkField = app.textFields["linkURLField"]
        XCTAssertTrue(savedLinkField.waitForExistence(timeout: 15))
        XCTAssertEqual(savedLinkField.value as? String, "https://example.com")
    }

    @MainActor
    func testUnreadableLinkURLCannotBeSaved() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        app.navigationBars["通知"].buttons["追加"].tap()
        let field = app.descendants(matching: .any)["messageField"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("残高")
        let save = app.navigationBars["通知を追加"].buttons["保存"]
        XCTAssertTrue(save.isEnabled)

        // スキームの無い URL は読めないので保存できず、理由を出す
        app.swipeUp()
        let linkField = app.textFields["linkURLField"]
        XCTAssertTrue(linkField.waitForExistence(timeout: 15))
        linkField.tap()
        linkField.typeText("example.com")
        XCTAssertTrue(element(containing: "URL を読めません", in: app).waitForExistence(timeout: 15))
        XCTAssertFalse(save.isEnabled)
    }

    @MainActor
    func testRowShowsOpenLinkButtonOnlyForLinkedNotification() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        addNotification(message: "水を飲む", linkURL: nil, in: app)
        addNotification(message: "残高", linkURL: "https://example.com", in: app)

        // 紐づけのある行にだけ「開く」ボタンが出る
        XCTAssertTrue(app.buttons["残高, 1 時間ごと"].waitForExistence(timeout: 15))
        let openButtons = app.buttons.matching(identifier: "openLinkButton")
        XCTAssertTrue(openButtons.firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(openButtons.count, 1)
        XCTAssertEqual(openButtons.firstMatch.label, "アプリを開く")

        // OFF にしても出る
        let toggles = app.switches.matching(identifier: "enabledToggle")
        XCTAssertEqual(toggles.count, 2)
        toggles.element(boundBy: 1).switches.firstMatch.tap()
        XCTAssertEqual(toggles.element(boundBy: 1).value as? String, "0")
        XCTAssertTrue(openButtons.firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(openButtons.count, 1)
    }

    /// 追加画面で通知を 1 件保存する。`linkURL` が nil なら紐づけない
    @MainActor
    private func addNotification(message: String, linkURL: String?, in app: XCUIApplication) {
        app.navigationBars["通知"].buttons["追加"].tap()
        let field = app.descendants(matching: .any)["messageField"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText(message)
        if let linkURL {
            // 「アプリを開く」の節は Form の一番下にある。Form は画面外の欄を要素として持たないので、押せるまで送る
            let linkField = app.textFields["linkURLField"]
            for _ in 0..<3 where !(linkField.exists && linkField.isHittable) {
                app.swipeUp()
            }
            XCTAssertTrue(linkField.waitForExistence(timeout: 15))
            linkField.tap()
            linkField.typeText(linkURL)
        }
        app.navigationBars["通知を追加"].buttons["保存"].tap()
        allowNotificationsIfAsked()
        XCTAssertTrue(app.buttons["\(message), 1 時間ごと"].waitForExistence(timeout: 15))
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
