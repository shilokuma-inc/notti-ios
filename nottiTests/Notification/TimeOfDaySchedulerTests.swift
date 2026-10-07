//
//  TimeOfDaySchedulerTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import Testing
import UserNotifications

struct TimeOfDaySchedulerTests {
    private static let overnight = QuietHours(isEnabled: true, start: time(23, 0), end: time(7, 0))
    /// 東京の 2026-10-05 12:00
    private static let now = date(2026, 10, 5, 12, 0)

    private let id = UUID()

    // MARK: - 登録

    @Test
    func dailyRegistersOneRepeatingCalendarTrigger() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)

        let plan = try await scheduler.schedule(id: id, message: "デイリーミッション", schedule: Self.daily(21, 30), now: Self.now)

        #expect(plan.requestCount == 1)
        let pending = center.pending
        #expect(Set(pending.keys) == ["\(id.uuidString)-daily"])
        let request = try #require(pending["\(id.uuidString)-daily"])
        #expect(request.content.body == "デイリーミッション")
        #expect(request.content.sound == .default)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats)
        #expect(trigger.dateComponents == DateComponents(hour: 21, minute: 30))
    }

    @Test
    func weekdaysRegisterOneTriggerPerWeekday() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)
        let schedule = TimeOfDaySchedule(time: Self.time(7, 15), repeatRule: .weekdays, weekdays: [.monday, .friday])

        let plan = try await scheduler.schedule(id: id, message: "歩数", schedule: schedule, now: Self.now)

        #expect(plan.requestCount == 2)
        let pending = center.pending
        #expect(Set(pending.keys) == ["\(id.uuidString)-weekday2", "\(id.uuidString)-weekday6"])
        let friday = try #require(pending["\(id.uuidString)-weekday6"]?.trigger as? UNCalendarNotificationTrigger)
        #expect(friday.repeats)
        #expect(friday.dateComponents == DateComponents(hour: 7, minute: 15, weekday: 6))
    }

    @Test
    func onceRegistersNonRepeatingTriggerWithDate() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)
        let schedule = TimeOfDaySchedule(time: Self.time(9, 0), repeatRule: .once, onceDate: Self.date(2026, 10, 25, 9, 30))

        try await scheduler.schedule(id: id, message: "残高を確認", schedule: schedule, now: Self.now)

        let request = try #require(center.pending["\(id.uuidString)-once"])
        #expect(center.pending.count == 1)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(!trigger.repeats)
        let components = trigger.dateComponents
        #expect([components.year, components.month, components.day, components.hour, components.minute] == [2026, 10, 25, 9, 30])
    }

    @Test
    func pastOnceRemovesExistingAndRegistersNothing() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)
        try await scheduler.schedule(id: id, message: "毎日", schedule: Self.daily(9, 0), now: Self.now)
        let past = TimeOfDaySchedule(time: Self.time(9, 0), repeatRule: .once, onceDate: Self.date(2026, 10, 1, 9, 0))

        let plan = try await scheduler.schedule(id: id, message: "過ぎた", schedule: past, now: Self.now)

        #expect(plan == .timeOfDay([]))
        #expect(center.pending.isEmpty)
    }

    @Test
    func timeOfDayIgnoresQuietHours() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center, quietHours: Self.overnight)

        try await scheduler.schedule(id: id, message: "夜", schedule: Self.daily(23, 30), now: Self.now)

        #expect(Set(center.pending.keys) == ["\(id.uuidString)-daily"])
    }

    // MARK: - 置き換え・削除

    @Test
    func timeOfDayReplacesIntervalNotificationsOfSameSetting() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center, quietHours: Self.overnight)
        try await scheduler.schedule(id: id, message: "水を飲む", interval: .oneHour, startDate: Self.date(2026, 10, 5, 14, 23))
        #expect(center.pending.count == 16)

        try await scheduler.schedule(id: id, message: "水を飲む", schedule: Self.daily(9, 0), now: Self.now)

        #expect(Set(center.pending.keys) == ["\(id.uuidString)-daily"])
    }

    @Test
    func intervalReplacesTimeOfDayNotificationsOfSameSetting() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)
        let schedule = TimeOfDaySchedule(time: Self.time(9, 0), repeatRule: .weekdays, weekdays: Set(Weekday.allCases))
        try await scheduler.schedule(id: id, message: "毎朝", schedule: schedule, now: Self.now)
        #expect(center.pending.count == 7)

        try await scheduler.schedule(id: id, message: "水を飲む", interval: .oneHour, startDate: Self.now)

        #expect(Set(center.pending.keys) == [id.uuidString])
    }

    @Test
    func changingWeekdaysRemovesUnselectedWeekdays() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)
        let before = TimeOfDaySchedule(time: Self.time(9, 0), repeatRule: .weekdays, weekdays: [.monday, .tuesday])
        let after = TimeOfDaySchedule(time: Self.time(9, 0), repeatRule: .weekdays, weekdays: [.saturday])
        try await scheduler.schedule(id: id, message: "曜日", schedule: before, now: Self.now)

        try await scheduler.schedule(id: id, message: "曜日", schedule: after, now: Self.now)

        #expect(Set(center.pending.keys) == ["\(id.uuidString)-weekday7"])
    }

    @Test
    func removeDeletesAllTimeOfDayNotificationsAndKeepsOthers() async throws {
        let otherID = UUID()
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)
        let schedule = TimeOfDaySchedule(time: Self.time(9, 0), repeatRule: .weekdays, weekdays: [.sunday, .wednesday])
        try await scheduler.schedule(id: id, message: "曜日", schedule: schedule, now: Self.now)
        try await scheduler.schedule(id: otherID, message: "別の通知", schedule: Self.daily(9, 0), now: Self.now)

        await scheduler.remove(id: id)

        #expect(Set(center.pending.keys) == ["\(otherID.uuidString)-daily"])
    }

    // MARK: - identifier と突き合わせ

    @Test
    func timeOfDayIdentifiersDoNotCollideWithIntervalIdentifiers() {
        let hourlyIdentifiers = (0...23).map { NotificationScheduler.identifier(for: id, hour: $0) }
        let intervalIdentifiers = Set([NotificationScheduler.identifier(for: id)] + hourlyIdentifiers)
        let triggers: [TimeOfDayTrigger] = [.daily(Self.time(9, 0)), .once(DateComponents(year: 2026, month: 10, day: 25))]
            + Weekday.allCases.map { .weekly($0, Self.time(9, 0)) }
        let timeOfDayIdentifiers = triggers.map { NotificationScheduler.identifier(for: id, trigger: $0) }

        #expect(Set(timeOfDayIdentifiers).count == triggers.count)
        #expect(intervalIdentifiers.isDisjoint(with: timeOfDayIdentifiers))
        #expect(timeOfDayIdentifiers.allSatisfy { $0.hasPrefix(id.uuidString + "-") })
    }

    @Test
    func pendingNotificationsMatchExpectedNotifications() async throws {
        let schedules = [
            TimeOfDaySchedule(time: Self.time(21, 30), repeatRule: .daily),
            TimeOfDaySchedule(time: Self.time(7, 15), repeatRule: .weekdays, weekdays: [.sunday, .wednesday, .saturday]),
            TimeOfDaySchedule(time: Self.time(9, 0), repeatRule: .once, onceDate: Self.date(2026, 10, 25, 9, 30))
        ]
        for schedule in schedules {
            let center = FakeNotificationCenter()
            let scheduler = NotificationScheduler.fake(center)

            let plan = try await scheduler.schedule(id: id, message: "文言", schedule: schedule, now: Self.now)

            let expected = NotificationScheduler.expectedNotifications(id: id, message: "文言", plan: plan)
            #expect(!expected.isEmpty)
            let pending = await scheduler.pendingNotifications()
            #expect(pending == expected, "\(schedule.repeatRule)")
        }
    }

    @Test
    func expectedNotificationsDetectChangedWeekdayAndDate() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)
        let registered = TimeOfDaySchedule(time: Self.time(9, 0), repeatRule: .once, onceDate: Self.date(2026, 10, 25, 9, 0))
        try await scheduler.schedule(id: id, message: "文言", schedule: registered, now: Self.now)

        let moved = TimeOfDaySchedule(time: Self.time(9, 0), repeatRule: .once, onceDate: Self.date(2026, 10, 26, 9, 0))
        let expected = NotificationScheduler.expectedNotifications(
            id: id,
            message: "文言",
            plan: scheduler.plan(schedule: moved, now: Self.now)
        )

        let pending = await scheduler.pendingNotifications()
        #expect(Set(expected.keys) == Set(pending.keys))
        #expect(pending != expected)
    }

    @Test
    func settingProvidesItsSchedule() {
        let onceDate = Self.date(2026, 10, 25, 9, 30)
        let setting = NotificationSetting(
            message: "残高",
            kind: .timeOfDay,
            hour: 8,
            minute: 45,
            repeatRule: .once,
            weekdays: [.monday],
            onceDate: onceDate
        )

        #expect(setting.timeOfDaySchedule == TimeOfDaySchedule(
            time: Self.time(8, 45),
            repeatRule: .once,
            weekdays: [.monday],
            onceDate: onceDate
        ))
    }

    // MARK: - ヘルパー

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
