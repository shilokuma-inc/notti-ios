//
//  MonthlyUntilDoneSettingTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing
import UserNotifications

/// 毎月の「完了するまで繰り返す」通知の、登録・完了・整合・表記
@MainActor
struct MonthlyUntilDoneSettingTests {
    /// 東京の 2026-10-05（月曜）12:00
    private static let now = date(2026, 10, 5, 12, 0)
    private static let calendar = NotificationScheduler.testCalendar

    private let center = FakeNotificationCenter()
    private let container: ModelContainer
    private var context: ModelContext {
        container.mainContext
    }

    private var scheduler: NotificationScheduler {
        NotificationScheduler.fake(center)
    }

    private var actions: NotificationSettingActions {
        NotificationSettingActions(scheduler: scheduler)
    }

    init() throws {
        container = try NottiModelContainer.make(inMemory: true)
    }

    // MARK: - 登録

    @Test
    func planUsesNagsInsteadOfMonthlyTriggers() async throws {
        let setting = insertMonthly(monthEndOffset: 0)

        let plan = scheduler.plan(for: setting, now: Self.now)
        await actions.sync(setting, now: Self.now)

        guard case .untilDone = plan else {
            Issue.record("催促の経路で登録していない: \(plan)")
            return
        }
        let keys = Set(center.pending.keys)
        #expect(keys.count == 9 + 2)
        #expect(keys.allSatisfy { $0.hasPrefix("\(setting.id.uuidString)-nag") })
        #expect(keys.contains("\(setting.id.uuidString)-nag202612052100"))
        #expect(center.pending.values.allSatisfy { $0.content.categoryIdentifier == NotificationScheduler.untilDoneCategoryIdentifier })
    }

    @Test
    func estimateMatchesSchedulerAndExpectedNotifications() {
        let setting = insertMonthly()

        let plan = scheduler.plan(for: setting, now: Self.now)
        let expected = NotificationScheduler.expectedNotifications(id: setting.id, message: setting.message, plan: plan)

        #expect(setting.plan(quietHours: .default, calendar: Self.calendar, now: Self.now) == plan)
        #expect([setting].requestCount(quietHours: .default, calendar: Self.calendar, now: Self.now) == 11)
        #expect(expected.count == plan.requestCount)
    }

    // MARK: - 完了

    @Test
    func completeActionCompletesDeliveredMonth() async throws {
        let setting = insertMonthly()
        try context.save()
        await actions.sync(setting, now: Self.now)
        let delegate = NotificationDelegate(scheduler: scheduler, modelContainer: container)

        // 10 月 31 日 23 時に届いた通知の「完了」を、月が変わってから押した
        await delegate.handle(
            actionIdentifier: NotificationScheduler.completeActionIdentifier,
            settingID: setting.id.uuidString,
            message: setting.message,
            deliveredAt: Self.date(2026, 10, 31, 23, 0)
        )

        #expect(setting.completions.map(\.periodStart) == [Self.date(2026, 10, 1, 0, 0)])
        #expect(!center.pending.keys.contains { $0.hasPrefix("\(setting.id.uuidString)-nag202610") })
    }

    @Test
    func completeFromListRegistersFromNextMonth() async throws {
        let setting = insertMonthly()
        let now = Self.date(2026, 10, 5, 21, 30)
        await actions.sync(setting, now: now)

        await actions.complete(setting, in: context, now: now).value

        #expect(setting.completions.map(\.periodStart) == [Self.date(2026, 10, 1, 0, 0)])
        #expect(Set(center.pending.keys) == [
            "\(setting.id.uuidString)-nag202611052100",
            "\(setting.id.uuidString)-nag202612052100",
            "\(setting.id.uuidString)-nag202701052100"
        ])
    }

    @Test
    func undoCompletionRegistersRestOfMonth() async throws {
        let setting = insertMonthly()
        let now = Self.date(2026, 10, 5, 21, 30)
        await actions.complete(setting, in: context, now: now).value

        await actions.undoCompletion(setting, in: context, now: now).value

        #expect(setting.completions.isEmpty)
        #expect(center.pending["\(setting.id.uuidString)-nag202610052200"] != nil)
        // 今日の残り 2 件・6・7 日の 3 件ずつと、11・12・1 月の最初の催促
        #expect(center.pending.count == 11)
    }

    // MARK: - 整合

    @Test
    func reconcileReplacesMonthlyTriggersRegisteredBeforeTurningOn() async throws {
        let setting = insertMonthly(monthEndOffset: 0)
        setting.repeatsUntilDone = false
        await actions.sync(setting, now: Self.now)
        #expect(center.pending.keys.contains { $0.contains("-monthday") })
        #expect(center.pending.keys.contains { $0.contains("-monthend") })
        setting.repeatsUntilDone = true

        await reconcile()

        let keys = Set(center.pending.keys)
        #expect(!keys.contains { $0.contains("-monthday") })
        #expect(!keys.contains { $0.contains("-monthend") })
        #expect(keys.count == 9 + 2)
    }

    @Test
    func reconcileRefillsNagsAndFirstNagsOfComingMonths() async throws {
        let setting = insertMonthly()
        // 前に登録した催促のうち、来月の最初の催促だけが残っている
        try await center.add(Self.request(id: setting.id, at: Self.date(2026, 11, 5, 21, 0)))

        await reconcile()

        let keys = Set(center.pending.keys)
        #expect(keys.count == 9 + 2)
        #expect(keys.contains("\(setting.id.uuidString)-nag202610072300"))
        #expect(keys.contains("\(setting.id.uuidString)-nag202612052100"))
    }

    // MARK: - 表記

    @Test
    func labelsShowNagIntervalAndThisMonthsStatus() {
        let setting = insertMonthly()
        setting.nagIntervalMinutes = NagInterval.thirtyMinutes.minutes

        #expect(setting.scheduleLabel(now: Self.now, calendar: Self.calendar) == "毎月 5 日 21:00・完了まで 30 分ごと")
        #expect(setting.completionStatusLabel(now: Self.now, calendar: Self.calendar) == "今月はまだ完了していません")

        context.insert(CompletionRecord(periodStart: Self.date(2026, 10, 1, 0, 0), completedAt: Self.now, setting: setting))

        #expect(setting.completionStatusLabel(now: Self.date(2026, 10, 31, 23, 59), calendar: Self.calendar) == "今月は完了済み")
        #expect(setting.completionStatusLabel(now: Self.date(2026, 11, 1, 0, 0), calendar: Self.calendar) == "今月はまだ完了していません")
    }

    // MARK: - 補助

    private func reconcile() async {
        await NotificationReconciler(scheduler: scheduler).reconcile(in: context, now: Self.now)
    }

    /// 毎月 5 日（と月末の `monthEndOffset` 日前）21 時に、1 時間ごとに催促する設定
    private func insertMonthly(monthEndOffset: Int? = nil) -> NotificationSetting {
        let setting = NotificationSetting(
            message: "家賃を振り込む",
            kind: .timeOfDay,
            hour: 21,
            repeatRule: .monthly,
            monthDays: [5],
            monthEndOffset: monthEndOffset,
            repeatsUntilDone: true,
            untilDoneRule: UntilDoneRule(interval: .oneHour)
        )
        context.insert(setting)
        return setting
    }

    /// `date` に鳴らす催促の通知
    private static func request(id: UUID, at date: Date) -> UNNotificationRequest {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let content = UNMutableNotificationContent()
        content.body = "家賃を振り込む"
        content.categoryIdentifier = NotificationScheduler.untilDoneCategoryIdentifier
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = NotificationScheduler.identifier(for: id, nagAt: components)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    /// 東京の year-month-day hour:minute
    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
