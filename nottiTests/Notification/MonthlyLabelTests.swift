//
//  MonthlyLabelTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import Testing

struct MonthlyLabelTests {
    /// 東京の 2026-10-05 12:00
    private let now = NotificationScheduler.testCalendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 12))!

    @Test
    func monthDaysShowInOrder() {
        #expect(label(days: [27, 10]) == "毎月 10・27 日 9:00")
        #expect(label(days: [1]) == "毎月 1 日 9:00")
    }

    @Test
    func monthEndShowsMonthEndOrDaysBefore() {
        #expect(label(days: [], monthEndOffset: 0, hour: 21) == "毎月 月末 21:00")
        #expect(label(days: [], monthEndOffset: 3, hour: 21) == "毎月 月末の 3 日前 21:00")
    }

    @Test
    func monthDaysAndMonthEndShowTogether() {
        #expect(label(days: [15, 1], monthEndOffset: 0) == "毎月 1・15 日・月末 9:00")
        #expect(label(days: [10], monthEndOffset: 7, minute: 30) == "毎月 10 日・月末の 7 日前 9:30")
    }

    @Test
    func monthlyWithoutDaysShowsNoDays() {
        #expect(label(days: []) == "毎月（日付なし）")
    }

    @Test
    func monthlyNeverExpires() {
        let setting = NotificationSetting(message: "家賃", kind: .timeOfDay, repeatRule: .monthly, monthDays: [1])

        #expect(!setting.isOnceExpired(now: now, calendar: NotificationScheduler.testCalendar))
    }

    private func label(days: Set<Int>, monthEndOffset: Int? = nil, hour: Int = 9, minute: Int = 0) -> String {
        let setting = NotificationSetting(
            message: "家賃",
            kind: .timeOfDay,
            hour: hour,
            minute: minute,
            repeatRule: .monthly,
            monthDays: days,
            monthEndOffset: monthEndOffset
        )
        return setting.scheduleLabel(now: now, calendar: NotificationScheduler.testCalendar)
    }
}
