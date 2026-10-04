//
//  NotificationDelegateTests.swift
//  nottiTests
//

@testable import notti
import Testing
import UserNotifications

struct NotificationDelegateTests {
    /// アプリ表示中もバナーで出し、通知センターに残し、音も鳴らす
    @Test
    func foregroundPresentationShowsBanner() {
        let options = NotificationDelegate.foregroundPresentationOptions
        #expect(options.contains(.banner))
        #expect(options.contains(.list))
        #expect(options.contains(.sound))
    }
}
