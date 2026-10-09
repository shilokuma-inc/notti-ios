//
//  UntilDoneSchedulerTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing
import UserNotifications

@MainActor
struct UntilDoneSchedulerTests {
    /// 東京の 2026-10-05（月曜）12:00
    private static let now = date(2026, 10, 5, 12, 0)
    private static let rule = UntilDoneRule(interval: .oneHour)

    private let id = UUID()

    // MARK: - 登録

    @Test
    func registersOneNonRepeatingTriggerPerNagDate() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)

        let plan = try await scheduler.schedule(
            id: id,
            message: "デイリーミッション",
            schedule: Self.daily(21, 0),
            rule: Self.rule,
            completedPeriodStarts: [],
            now: Self.now
        )

        #expect(plan.requestCount == 9)
        let pending = center.pending
        #expect(pending.count == 9)
        let request = try #require(pending["\(id.uuidString)-nag202610052100"])
        #expect(request.content.body == "デイリーミッション")
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(!trigger.repeats)
        #expect(trigger.dateComponents == DateComponents(year: 2026, month: 10, day: 5, hour: 21, minute: 0))
        #expect(pending["\(id.uuidString)-nag202610072300"] != nil)
    }

    @Test
    func replacesDailyTriggerAndKeepsSnooze() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)
        try await scheduler.schedule(id: id, message: "デイリーミッション", schedule: Self.daily(21, 0), now: Self.now)
        try await scheduler.snooze(id: id, message: "デイリーミッション")

        try await scheduler.schedule(
            id: id,
            message: "デイリーミッション",
            schedule: Self.daily(21, 0),
            rule: Self.rule,
            completedPeriodStarts: [Self.date(2026, 10, 5, 0, 0)],
            now: Self.now
        )

        let keys = Set(center.pending.keys)
        #expect(!keys.contains("\(id.uuidString)-daily"))
        #expect(keys.contains("\(id.uuidString)-snooze"))
        #expect(!keys.contains("\(id.uuidString)-nag202610052100"))
        #expect(keys.contains("\(id.uuidString)-nag202610062100"))
        #expect(keys.count == 1 + 6)
    }

    @Test
    func removeDeletesNagNotifications() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)
        try await scheduler.schedule(
            id: id,
            message: "デイリーミッション",
            schedule: Self.daily(21, 0),
            rule: Self.rule,
            completedPeriodStarts: [],
            now: Self.now
        )

        await scheduler.remove(id: id)

        #expect(center.pending.isEmpty)
    }

    @Test
    func expectedNotificationsMatchRegisteredOnes() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)

        let plan = try await scheduler.schedule(
            id: id,
            message: "デイリーミッション",
            schedule: Self.daily(21, 30),
            rule: UntilDoneRule(interval: .thirtyMinutes),
            completedPeriodStarts: [],
            now: Self.now
        )

        let expected = NotificationScheduler.expectedNotifications(id: id, message: "デイリーミッション", plan: plan)
        #expect(expected.count == 15)
        #expect(await scheduler.pendingNotifications() == expected)
    }

    @Test
    func nagIdentifierHasDateAndTime() {
        let components = DateComponents(year: 2026, month: 1, day: 2, hour: 3, minute: 4)

        #expect(NotificationScheduler.identifier(for: id, nagAt: components) == "\(id.uuidString)-nag202601020304")
    }

    // MARK: - 設定から

    @Test
    func settingRepeatingUntilDoneIsPlannedAsNags() throws {
        let container = try NottiModelContainer.make(inMemory: true)
        let scheduler = NotificationScheduler.fake(FakeNotificationCenter())
        let setting = NotificationSetting(
            message: "デイリーミッション",
            kind: .timeOfDay,
            hour: 21,
            repeatRule: .daily,
            repeatsUntilDone: true,
            untilDoneRule: Self.rule
        )
        container.mainContext.insert(setting)

        #expect(scheduler.plan(for: setting, now: Self.now).requestCount == 9)

        container.mainContext.insert(CompletionRecord(periodStart: Self.date(2026, 10, 5, 0, 0), completedAt: Self.now, setting: setting))
        #expect(scheduler.plan(for: setting, now: Self.now).requestCount == 6)

        setting.repeatsUntilDone = false
        #expect(scheduler.plan(for: setting, now: Self.now) == .timeOfDay([.daily(Self.time(21, 0))]))
    }

    @Test
    func scheduleSettingRegistersNags() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)
        let setting = NotificationSetting(
            message: "ウィークリーミッション",
            kind: .timeOfDay,
            hour: 21,
            repeatRule: .weekdays,
            weekdays: [.wednesday],
            repeatsUntilDone: true,
            untilDoneRule: Self.rule
        )

        try await scheduler.schedule(setting, now: Self.now)

        #expect(Set(center.pending.keys) == [
            "\(setting.id.uuidString)-nag202610072100",
            "\(setting.id.uuidString)-nag202610072200",
            "\(setting.id.uuidString)-nag202610072300"
        ])
    }

    // MARK: - 補助

    private static func daily(_ hour: Int, _ minute: Int) -> TimeOfDaySchedule {
        TimeOfDaySchedule(time: time(hour, minute), repeatRule: .daily)
    }

    /// 東京の year-month-day hour:minute
    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        NotificationScheduler.testCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private static func time(_ hour: Int, _ minute: Int) -> TimeOfDay {
        TimeOfDay(hour: hour, minute: minute)
    }
}
