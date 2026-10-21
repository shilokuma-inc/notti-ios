//
//  NotificationEditUITests+Link.swift
//  nottiUITests
//

import XCTest

/// 紐づけたアプリ（一覧の「開く」ボタン・戻ったときの確認）の UI テスト。
/// `NotificationEditUITests` の本体が `type_body_length` の上限を超えないよう、extension に分けている（同じクラスとして流れる）
extension NotificationEditUITests {
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

    /// 紐づけたアプリ（Simulator では Safari で開く `https://example.com`）を開いて戻ると、済んだかを聞き、「完了にする」で今日を完了にする
    @MainActor
    func testReturningFromLinkedAppAsksWhetherDone() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        app.navigationBars["通知"].buttons["追加"].tap()
        let field = app.descendants(matching: .any)["messageField"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("デイリーミッション")
        app.buttons["時刻を指定"].tap()
        let toggle = app.switches["repeatsUntilDoneToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        toggle.switches.firstMatch.tap()
        let linkField = app.textFields["linkURLField"]
        for _ in 0..<3 where !(linkField.exists && linkField.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(linkField.waitForExistence(timeout: 15))
        linkField.tap()
        linkField.typeText("https://example.com")
        app.navigationBars["通知を追加"].buttons["保存"].tap()
        allowNotificationsIfAsked()
        XCTAssertTrue(element(containing: "今日はまだ完了していません", in: app).waitForExistence(timeout: 15))

        // 行の「開く」ボタンで Safari に移り、のっちに戻る
        app.buttons["openLinkButton"].tap()
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 30))
        app.activate()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 15))
        XCTAssertTrue(alert.label.contains("デイリーミッション"))
        alert.buttons["完了にする"].tap()
        XCTAssertTrue(element(containing: "今日は完了済み", in: app).waitForExistence(timeout: 15))

        // 聞き終えたら、もう一度戻っても聞かない
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(element(containing: "今日は完了済み", in: app).waitForExistence(timeout: 15))
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 3))
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
}
