//
//  MonthDayTriggerTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing
import UserNotifications

@MainActor
struct MonthDayTriggerTests {
    /// 東京の 2026-10-05 12:00
    private static let now = NotificationScheduler.testCalendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 12))!
    private static let nine = TimeOfDay(hour: 9, minute: 0)

    private let id = UUID()
    private let container: ModelContainer

    init() throws {
        container = try NottiModelContainer.make(inMemory: true)
    }

    // MARK: - トリガー

    @Test
    func monthlyRepeatsOncePerSelectedDayInOrder() {
        let plan = Self.plan(days: [31, 1, 15])

        #expect(plan == .timeOfDay([.monthDay(1, Self.nine), .monthDay(15, Self.nine), .monthDay(31, Self.nine)]))
        #expect(plan.requestCount == 3)
    }

    @Test
    func monthDayComponentsHaveDayHourAndMinuteOnly() {
        let trigger = TimeOfDayTrigger.monthDay(29, TimeOfDay(hour: 21, minute: 30))

        // 年・月を持たないので、29 日が無い月（うるう年でない 2 月）は OS が鳴らさない
        #expect(trigger.dateComponents == DateComponents(day: 29, hour: 21, minute: 30))
        #expect(trigger.repeats)
    }

    @Test
    func allDaysMakeThirtyOneTriggers() {
        #expect(Self.plan(days: Set(MonthDay.range)).requestCount == 31)
    }

    @Test
    func noDaysAndMonthEndOnlyRegisterNoMonthDayTriggers() {
        #expect(Self.plan(days: []) == .timeOfDay([]))
        // 月末（N 日前）の登録はまだ無い
        #expect(Self.plan(days: [], monthEndOffset: 0) == .timeOfDay([]))
        #expect(Self.plan(days: [10], monthEndOffset: 3) == .timeOfDay([.monthDay(10, Self.nine)]))
    }

    // MARK: - identifier と登録

    @Test
    func monthDayIdentifiersDoNotCollideWithOtherIdentifiers() {
        let monthDayIdentifiers = MonthDay.range.map { NotificationScheduler.identifier(for: id, trigger: .monthDay($0, Self.nine)) }
        let others: [TimeOfDayTrigger] = [.daily(Self.nine), .once(DateComponents(year: 2026, month: 10, day: 25))]
            + Weekday.allCases.map { .weekly($0, Self.nine) }
        let otherIdentifiers = Set(others.map { NotificationScheduler.identifier(for: id, trigger: $0) })
            .union((0...23).map { NotificationScheduler.identifier(for: id, hour: $0) })
            .union([NotificationScheduler.identifier(for: id), NotificationScheduler.snoozeIdentifier(for: id)])

        #expect(monthDayIdentifiers.first == "\(id.uuidString)-monthday1")
        #expect(monthDayIdentifiers.last == "\(id.uuidString)-monthday31")
        #expect(Set(monthDayIdentifiers).count == 31)
        #expect(otherIdentifiers.isDisjoint(with: monthDayIdentifiers))
    }

    @Test
    func monthlyRegistersOneRepeatingCalendarTriggerPerDay() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)
        let schedule = TimeOfDaySchedule(time: TimeOfDay(hour: 21, minute: 0), repeatRule: .monthly, monthDays: [10, 27])

        let plan = try await scheduler.schedule(id: id, message: "家賃", schedule: schedule, now: Self.now)

        #expect(plan.requestCount == 2)
        #expect(Set(center.pending.keys) == ["\(id.uuidString)-monthday10", "\(id.uuidString)-monthday27"])
        let request = try #require(center.pending["\(id.uuidString)-monthday27"])
        #expect(request.content.body == "家賃")
        #expect(request.content.categoryIdentifier == NotificationScheduler.categoryIdentifier)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats)
        #expect(trigger.dateComponents == DateComponents(day: 27, hour: 21, minute: 0))

        let expected = NotificationScheduler.expectedNotifications(id: id, message: "家賃", plan: plan)
        #expect(await scheduler.pendingNotifications() == expected)
    }

    // MARK: - 整合

    @Test
    func reconcileReplacesUnselectedDaysAndAddsMissingDays() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)
        let setting = NotificationSetting(message: "家賃", kind: .timeOfDay, repeatRule: .monthly, monthDays: [10, 20])
        container.mainContext.insert(setting)
        // 前に 5・10 日で登録した通知が残っている
        let registered = TimeOfDaySchedule(time: Self.nine, repeatRule: .monthly, monthDays: [5, 10])
        try await scheduler.schedule(id: setting.id, message: "家賃", schedule: registered, now: Self.now)

        await NotificationReconciler(scheduler: scheduler).reconcile(in: container.mainContext, now: Self.now)

        #expect(Set(center.pending.keys) == ["\(setting.id.uuidString)-monthday10", "\(setting.id.uuidString)-monthday20"])
        let trigger = try #require(center.pending["\(setting.id.uuidString)-monthday20"]?.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents == DateComponents(day: 20, hour: 9, minute: 0))
    }

    @Test
    func reconcileKeepsMatchingMonthDayNotifications() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)
        let setting = NotificationSetting(message: "家賃", kind: .timeOfDay, repeatRule: .monthly, monthDays: [1, 31])
        container.mainContext.insert(setting)
        try await scheduler.schedule(id: setting.id, message: setting.message, schedule: setting.timeOfDaySchedule, now: Self.now)
        let removedBefore = center.removedIdentifiers.count

        await NotificationReconciler(scheduler: scheduler).reconcile(in: container.mainContext, now: Self.now)

        #expect(center.removedIdentifiers.count == removedBefore)
        #expect(Set(center.pending.keys) == ["\(setting.id.uuidString)-monthday1", "\(setting.id.uuidString)-monthday31"])
    }

    @Test
    func requestCountCountsMonthDays() {
        let monthly = NotificationSetting(message: "家賃", kind: .timeOfDay, repeatRule: .monthly, monthDays: [1, 15, 31])
        let daily = NotificationSetting(message: "毎日", kind: .timeOfDay)

        #expect([monthly, daily].requestCount(quietHours: .default, calendar: NotificationScheduler.testCalendar, now: Self.now) == 4)
    }

    // MARK: - ヘルパー

    private static func plan(days: Set<Int>, monthEndOffset: Int? = nil) -> NotificationTriggerPlan {
        let schedule = TimeOfDaySchedule(time: nine, repeatRule: .monthly, monthDays: days, monthEndOffset: monthEndOffset)
        return NotificationTriggerPlan.make(schedule: schedule, now: now, calendar: NotificationScheduler.testCalendar)
    }
}
