//
//  UntilDoneRequestCountTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing

@MainActor
struct UntilDoneRequestCountTests {
    /// 東京の 2026-10-05（月曜）12:00
    private static let now = date(2026, 10, 5, 12, 0)
    private static let calendar = NotificationScheduler.testCalendar

    private let container: ModelContainer

    init() throws {
        container = try NottiModelContainer.make(inMemory: true)
    }

    @Test
    func estimateCountsNagsLikeScheduler() {
        let setting = insertDaily(hour: 21, interval: .tenMinutes)
        let scheduler = NotificationScheduler.fake(FakeNotificationCenter())

        let estimate = [setting].requestCount(quietHours: .default, calendar: Self.calendar, now: Self.now)

        #expect(estimate == 54)
        #expect(setting.plan(quietHours: .default, calendar: Self.calendar, now: Self.now) == scheduler.plan(for: setting, now: Self.now))
    }

    @Test
    func estimateExcludesCompletedPeriod() {
        let setting = insertDaily(hour: 21, interval: .tenMinutes)
        container.mainContext.insert(CompletionRecord(periodStart: Self.date(2026, 10, 5, 0, 0), completedAt: Self.now, setting: setting))

        #expect([setting].requestCount(quietHours: .default, calendar: Self.calendar, now: Self.now) == 36)
    }

    @Test
    func nagsWithOtherNotificationsExceedPendingLimit() {
        let nag = insertDaily(hour: 21, interval: .tenMinutes)
        let hourly = NotificationSetting(message: "水を飲む", startDate: Self.date(2026, 10, 5, 9, 0))
        container.mainContext.insert(hourly)
        let overnight = QuietHours(isEnabled: true, start: TimeOfDay(hour: 23, minute: 0), end: TimeOfDay(hour: 7, minute: 0))

        let count = [nag, hourly].requestCount(quietHours: overnight, calendar: Self.calendar, now: Self.now)

        // 催促 54 件 + おやすみ時間外の 1 時間ごと 16 件
        #expect(count == 70)
        #expect(count > NotificationScheduler.pendingLimit)
    }

    @Test
    func estimateOfSingleSettingIsCappedAtPendingLimit() {
        let setting = insertDaily(hour: 6, interval: .thirtyMinutes)

        #expect([setting].requestCount(quietHours: .default, calendar: Self.calendar, now: Self.date(2026, 10, 5, 5, 0)) == 64)
    }

    @Test
    func disabledNagsAreNotCounted() {
        let setting = insertDaily(hour: 21, interval: .tenMinutes)
        setting.isEnabled = false

        #expect([setting].requestCount(quietHours: .default, calendar: Self.calendar, now: Self.now) == 0)
    }

    // MARK: - 補助

    private func insertDaily(hour: Int, interval: NagInterval) -> NotificationSetting {
        let setting = NotificationSetting(
            message: "デイリーミッション",
            kind: .timeOfDay,
            hour: hour,
            repeatRule: .daily,
            repeatsUntilDone: true,
            untilDoneRule: UntilDoneRule(interval: interval)
        )
        container.mainContext.insert(setting)
        return setting
    }

    /// 東京の year-month-day hour:minute
    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        NotificationScheduler.testCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
