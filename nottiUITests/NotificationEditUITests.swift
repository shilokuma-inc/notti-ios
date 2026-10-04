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

        let row = app.buttons["水を飲む, 1 時間ごと"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        // 編集
        row.tap()
        XCTAssertTrue(app.navigationBars["通知を編集"].waitForExistence(timeout: 5))
        app.buttons["24 時間ごと"].tap()
        app.navigationBars["通知を編集"].buttons["保存"].tap()

        XCTAssertTrue(app.buttons["水を飲む, 24 時間ごと"].waitForExistence(timeout: 5))
    }
}
