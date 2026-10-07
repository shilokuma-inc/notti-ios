//
//  NotificationSettingLabelTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import Testing

struct NotificationSettingLabelTests {
    /// 東京の 2026-10-05 12:00
    private let now = Self.date(2026, 10, 5, 12, 0)

    @Test
    func intervalShowsInterval() {
        let setting = NotificationSetting(message: "水を飲む", intervalHours: 24)

        #expect(label(of: setting) == "24 時間ごと")
    }

    @Test
    func dailyShowsTime() {
        let setting = NotificationSetting(message: "デイリー", kind: .timeOfDay, hour: 7, minute: 5)

        #expect(label(of: setting) == "毎日 7:05")
    }

    @Test
    func weekdaysShowSelectedDaysInOrder() {
        let setting = NotificationSetting(
            message: "歩数",
            kind: .timeOfDay,
            hour: 21,
            minute: 30,
            repeatRule: .weekdays,
            weekdays: [.friday, .sunday, .monday]
        )

        #expect(label(of: setting) == "毎週 日・月・金 21:30")
    }

    @Test
    func allWeekdaysShowEveryDay() {
        let setting = NotificationSetting(message: "歩数", kind: .timeOfDay, repeatRule: .weekdays, weekdays: Set(Weekday.allCases))

        #expect(label(of: setting) == "毎日 9:00")
    }

    @Test
    func onceShowsDateAndYearOnlyWhenNotThisYear() {
        let thisYear = NotificationSetting(message: "残高", kind: .timeOfDay, repeatRule: .once, onceDate: Self.date(2026, 10, 25, 9, 30))
        let nextYear = NotificationSetting(message: "残高", kind: .timeOfDay, repeatRule: .once, onceDate: Self.date(2027, 1, 3, 18, 0))

        #expect(label(of: thisYear) == "10月25日 9:30 に 1 回")
        #expect(label(of: nextYear) == "2027年1月3日 18:00 に 1 回")
    }

    @Test
    func onceExpiresAfterItsMinute() {
        let past = NotificationSetting(message: "残高", kind: .timeOfDay, repeatRule: .once, onceDate: Self.date(2026, 10, 5, 12, 0))
        let future = NotificationSetting(message: "残高", kind: .timeOfDay, repeatRule: .once, onceDate: Self.date(2026, 10, 5, 12, 1))
        let disabled = NotificationSetting(message: "残高", isEnabled: false, kind: .timeOfDay, repeatRule: .once, onceDate: past.onceDate)
        let daily = NotificationSetting(message: "デイリー", kind: .timeOfDay)

        #expect(past.isOnceExpired(now: now, calendar: NotificationScheduler.testCalendar))
        #expect(!future.isOnceExpired(now: now, calendar: NotificationScheduler.testCalendar))
        #expect(!disabled.isOnceExpired(now: now, calendar: NotificationScheduler.testCalendar))
        #expect(!daily.isOnceExpired(now: now, calendar: NotificationScheduler.testCalendar))
    }

    private func label(of setting: NotificationSetting) -> String {
        setting.scheduleLabel(now: now, calendar: NotificationScheduler.testCalendar)
    }

    /// 東京の year-month-day hour:minute
    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        NotificationScheduler.testCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
