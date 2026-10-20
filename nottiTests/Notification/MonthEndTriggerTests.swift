//
//  MonthEndTriggerTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing
import UserNotifications

@MainActor
struct MonthEndTriggerTests {
    private static let nine = TimeOfDay(hour: 9, minute: 0)
    private static let evening = TimeOfDay(hour: 21, minute: 0)

    private let container: ModelContainer

    init() throws {
        container = try NottiModelContainer.make(inMemory: true)
    }

    // MARK: - 日時

    @Test
    func monthEndRingsOnLastDayOfNextThreeMonths() {
        let dates = Self.fireDates(offset: 0, now: Self.date(2026, 10, 5, 12, 0))

        #expect(dates == [Self.date(2026, 10, 31, 21, 0), Self.date(2026, 11, 30, 21, 0), Self.date(2026, 12, 31, 21, 0)])
    }

    @Test
    func daysBeforeMonthEndCountFromLastDay() {
        let dates = Self.fireDates(offset: 3, now: Self.date(2026, 10, 5, 12, 0))

        #expect(dates == [Self.date(2026, 10, 28, 21, 0), Self.date(2026, 11, 27, 21, 0), Self.date(2026, 12, 28, 21, 0)])
    }

    @Test
    func thisMonthIsIncludedUntilItsTimePasses() {
        let before = Self.fireDates(offset: 0, now: Self.date(2026, 10, 31, 20, 59))
        let atTime = Self.fireDates(offset: 0, now: Self.date(2026, 10, 31, 21, 0))

        #expect(before.first == Self.date(2026, 10, 31, 21, 0))
        // 今月の分を過ぎたら来月から 3 か月ぶん（年をまたぐ）
        #expect(atTime == [Self.date(2026, 11, 30, 21, 0), Self.date(2026, 12, 31, 21, 0), Self.date(2027, 1, 31, 21, 0)])
    }

    @Test
    func februaryHasTwentyEightOrTwentyNineDays() {
        let leap = Self.fireDates(offset: 0, now: Self.date(2028, 1, 15, 12, 0))
        let common = Self.fireDates(offset: 0, now: Self.date(2027, 1, 15, 12, 0))
        let commonBefore = Self.fireDates(offset: 3, now: Self.date(2027, 1, 15, 12, 0))

        #expect(leap == [Self.date(2028, 1, 31, 21, 0), Self.date(2028, 2, 29, 21, 0), Self.date(2028, 3, 31, 21, 0)])
        #expect(common[1] == Self.date(2027, 2, 28, 21, 0))
        #expect(commonBefore[1] == Self.date(2027, 2, 25, 21, 0))
    }

    @Test
    func offsetIsClampedToRange() {
        let now = Self.date(2026, 10, 5, 12, 0)

        #expect(Self.fireDates(offset: 99, now: now) == Self.fireDates(offset: MonthDay.monthEndOffsetRange.upperBound, now: now))
        #expect(Self.fireDates(offset: -1, now: now) == Self.fireDates(offset: 0, now: now))
    }

    @Test
    func daylightSavingTimeChangesKeepTheDay() throws {
        var berlin = Calendar(identifier: .gregorian)
        berlin.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        let now = try #require(berlin.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 12)))

        // 2026-03-29（月末の 2 日前）は 2:00 から 3:00 に進むので、2:30 は無い。その日のうちの直後の時刻にする
        let halfPastTwo = TimeOfDay(hour: 2, minute: 30)
        let spring = NotificationTriggerPlan.monthEndFireDates(time: halfPastTwo, offset: 2, now: now, calendar: berlin)
        let first = try #require(spring.first)
        #expect(berlin.component(.month, from: first) == 3)
        #expect(berlin.component(.day, from: first) == 29)
        #expect(berlin.component(.hour, from: first) == 3)
        #expect(spring.count == 3)
        #expect(Self.monthDayTime(of: spring[1], in: berlin) == DateComponents(month: 4, day: 28, hour: 2, minute: 30))

        // 2026-10-25（月末の 6 日前）は 3:00 から 2:00 に戻る。2:30 は 2 回あるが、その日の 2:30 に 1 回だけ鳴らす
        let autumnNow = try #require(berlin.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 12)))
        let autumn = NotificationTriggerPlan.monthEndFireDates(time: halfPastTwo, offset: 6, now: autumnNow, calendar: berlin)
        #expect(Self.monthDayTime(of: autumn[0], in: berlin) == DateComponents(month: 10, day: 25, hour: 2, minute: 30))
        #expect(Self.monthDayTime(of: autumn[1], in: berlin) == DateComponents(month: 11, day: 24, hour: 2, minute: 30))
    }

    // MARK: - トリガー

    @Test
    func monthEndOnlyMakesThreeOneShotTriggers() {
        let plan = Self.plan(days: [], offset: 0, now: Self.date(2026, 10, 5, 12, 0))

        #expect(plan == .timeOfDay([
            .monthEnd(DateComponents(year: 2026, month: 10, day: 31, hour: 21, minute: 0)),
            .monthEnd(DateComponents(year: 2026, month: 11, day: 30, hour: 21, minute: 0)),
            .monthEnd(DateComponents(year: 2026, month: 12, day: 31, hour: 21, minute: 0))
        ]))
        #expect(plan.requestCount == 3)
        #expect(!TimeOfDayTrigger.monthEnd(DateComponents(year: 2026, month: 10, day: 31, hour: 21, minute: 0)).repeats)
    }

    @Test
    func monthDaysComeFirstAndSameDayAsMonthEndRingsOnce() {
        // 31 日と月末を選ぶと、31 日まである 10・12 月は日付の繰り返しの 1 本だけで鳴る
        let plan = Self.plan(days: [31, 15], offset: 0, now: Self.date(2026, 10, 5, 12, 0))

        #expect(plan == .timeOfDay([
            .monthDay(15, Self.evening),
            .monthDay(31, Self.evening),
            .monthEnd(DateComponents(year: 2026, month: 11, day: 30, hour: 21, minute: 0))
        ]))
    }

    @Test
    func noMonthEndMakesNoOneShotTriggers() {
        #expect(Self.plan(days: [10], offset: nil, now: Self.date(2026, 10, 5, 12, 0)) == .timeOfDay([.monthDay(10, Self.evening)]))
    }

    // MARK: - identifier と登録

    @Test
    func monthEndIdentifierHasFireDate() {
        let id = UUID()
        let trigger = TimeOfDayTrigger.monthEnd(DateComponents(year: 2026, month: 2, day: 28, hour: 9, minute: 5))

        let identifier = NotificationScheduler.identifier(for: id, trigger: trigger)

        #expect(identifier == "\(id.uuidString)-monthend202602280905")
        #expect(identifier != NotificationScheduler.identifier(for: id, nagAt: trigger.dateComponents))
        #expect(!NotificationScheduler.isSnooze(identifier))
    }

    @Test
    func monthEndRegistersOneShotCalendarTriggers() async throws {
        let id = UUID()
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)
        let schedule = TimeOfDaySchedule(time: Self.evening, repeatRule: .monthly, monthDays: [10], monthEndOffset: 3)

        let plan = try await scheduler.schedule(id: id, message: "カード", schedule: schedule, now: Self.date(2026, 10, 5, 12, 0))

        #expect(plan.requestCount == 4)
        #expect(Set(center.pending.keys) == [
            "\(id.uuidString)-monthday10",
            "\(id.uuidString)-monthend202610282100",
            "\(id.uuidString)-monthend202611272100",
            "\(id.uuidString)-monthend202612282100"
        ])
        let request = try #require(center.pending["\(id.uuidString)-monthend202611272100"])
        #expect(request.content.categoryIdentifier == NotificationScheduler.categoryIdentifier)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(!trigger.repeats)
        #expect(trigger.dateComponents == DateComponents(year: 2026, month: 11, day: 27, hour: 21, minute: 0))
        #expect(await scheduler.pendingNotifications() == NotificationScheduler.expectedNotifications(id: id, message: "カード", plan: plan))
    }

    // MARK: - 整合

    @Test
    func reconcileAddsNextMonthAfterOneHasFired() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)
        let setting = NotificationSetting(message: "締め日", kind: .timeOfDay, hour: 21, repeatRule: .monthly, monthEndOffset: 0)
        container.mainContext.insert(setting)
        let reconciler = NotificationReconciler(scheduler: scheduler)
        await reconciler.reconcile(in: container.mainContext, now: Self.date(2026, 10, 5, 12, 0))
        let id = setting.id.uuidString
        #expect(Set(center.pending.keys) == ["\(id)-monthend202610312100", "\(id)-monthend202611302100", "\(id)-monthend202612312100"])

        // 10/31 の分が届いて保留から外れた後に、アプリを開く
        await center.removePendingNotificationRequests(withIdentifiers: ["\(id)-monthend202610312100"])
        await reconciler.reconcile(in: container.mainContext, now: Self.date(2026, 11, 1, 8, 0))

        #expect(Set(center.pending.keys) == ["\(id)-monthend202611302100", "\(id)-monthend202612312100", "\(id)-monthend202701312100"])
    }

    @Test
    func reconcileReplacesPastMonthEndThatIsStillPending() async {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)
        let setting = NotificationSetting(message: "締め日", kind: .timeOfDay, hour: 21, repeatRule: .monthly, monthEndOffset: 0)
        container.mainContext.insert(setting)
        let reconciler = NotificationReconciler(scheduler: scheduler)
        await reconciler.reconcile(in: container.mainContext, now: Self.date(2026, 10, 5, 12, 0))

        // 端末の時計を進めたなどで、過ぎた日時の分が残っていても消して次の月の分にする
        await reconciler.reconcile(in: container.mainContext, now: Self.date(2026, 12, 1, 8, 0))

        let id = setting.id.uuidString
        #expect(Set(center.pending.keys) == ["\(id)-monthend202612312100", "\(id)-monthend202701312100", "\(id)-monthend202702282100"])
    }

    @Test
    func requestCountCountsMonthDaysAndMonthEnds() {
        let all = NotificationSetting(
            message: "家賃",
            kind: .timeOfDay,
            repeatRule: .monthly,
            monthDays: Set(MonthDay.range),
            monthEndOffset: 1
        )
        let monthEnd = NotificationSetting(message: "締め日", kind: .timeOfDay, repeatRule: .monthly, monthDays: [10], monthEndOffset: 0)
        let now = Self.date(2026, 10, 5, 12, 0)

        // 31 日すべてを選ぶと、月末の 1 日前はどの月も選んだ日付と重なる
        #expect([all].requestCount(quietHours: .default, calendar: NotificationScheduler.testCalendar, now: now) == 31)
        #expect([all, monthEnd].requestCount(quietHours: .default, calendar: NotificationScheduler.testCalendar, now: now) == 35)
    }

    // MARK: - ヘルパー

    private static func monthDayTime(of date: Date, in calendar: Calendar) -> DateComponents {
        calendar.dateComponents([.month, .day, .hour, .minute], from: date)
    }

    private static func fireDates(offset: Int, now: Date) -> [Date] {
        NotificationTriggerPlan.monthEndFireDates(time: evening, offset: offset, now: now, calendar: NotificationScheduler.testCalendar)
    }

    private static func plan(days: Set<Int>, offset: Int?, now: Date) -> NotificationTriggerPlan {
        let schedule = TimeOfDaySchedule(time: evening, repeatRule: .monthly, monthDays: days, monthEndOffset: offset)
        return NotificationTriggerPlan.make(schedule: schedule, now: now, calendar: NotificationScheduler.testCalendar)
    }

    /// 東京の year-month-day hour:minute
    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        NotificationScheduler.testCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
