//
//  MonthlyRequestCountTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing

/// 毎月の通知（日付・月末（N 日前）・「完了するまで繰り返す」の催促）の、登録する通知の数の見積もりと上限の警告
@MainActor
struct MonthlyRequestCountTests {
    /// 東京の 2026-10-05（月曜）12:00
    private static let now = date(2026, 10, 5, 12, 0)
    private static let calendar = NotificationScheduler.testCalendar

    private let container: ModelContainer

    private var actions: NotificationSettingActions {
        NotificationSettingActions(scheduler: NotificationScheduler.fake(FakeNotificationCenter()))
    }

    init() throws {
        container = try NottiModelContainer.make(inMemory: true)
    }

    // MARK: - 日付と月末

    @Test
    func monthDaysCountOnePerDay() {
        let two = insertMonthly(days: [1, 15])
        let all = insertMonthly(days: Set(MonthDay.range))

        #expect(count([two]) == 2)
        #expect(count([all]) == MonthDay.range.count)
        #expect(actions.requestCount(for: [two, all], now: Self.now) == 2 + 31)
    }

    @Test
    func monthEndCountsMonthsRegisteredAhead() {
        let monthEnd = insertMonthly(days: [], monthEndOffset: 3)
        let withDay = insertMonthly(days: [10], monthEndOffset: 0)

        #expect(count([monthEnd]) == NotificationTriggerPlan.monthEndMonths)
        #expect(count([withDay]) == 1 + 3)
        #expect(actions.requestCount(for: [monthEnd, withDay], now: Self.now) == 3 + 4)
    }

    @Test
    func monthEndOnSelectedDayIsCountedOnce() {
        // 31 日と月末。10・12 月の月末は 31 日の繰り返しの 1 本だけで鳴るので、月末の分は 11/30 の 1 件だけ（先の月を足さない）
        let setting = insertMonthly(days: [31], monthEndOffset: 0)

        #expect(count([setting]) == 1 + 1)
        #expect(actions.requestCount(for: [setting], now: Self.now) == 2)
    }

    // MARK: - 完了するまで繰り返す

    @Test
    func monthlyUntilDoneCountsNagsAndFirstNagsOfComingMonths() {
        let setting = insertMonthlyUntilDone()

        // 5〜7 日の 21〜23 時の 9 件と、11・12 月の最初の催促 2 件
        #expect(count([setting]) == 9 + 2)
        #expect(actions.requestCount(for: [setting], now: Self.now) == 11)
    }

    @Test
    func completedMonthIsNotCountedInMonthlyUntilDone() {
        let setting = insertMonthlyUntilDone()
        container.mainContext.insert(CompletionRecord(periodStart: Self.date(2026, 10, 1, 0, 0), completedAt: Self.now, setting: setting))

        // 今月の催促を始める日時（5 日 21 時）がまだ先なので 10〜12 月の 3 か月ぶんを見るが、完了済みの 10 月は数えず 11・12 月の 2 件
        #expect(count([setting]) == NotificationTriggerPlan.monthEndMonths - 1)
        #expect(actions.requestCount(for: [setting], now: Self.now) == 2)
    }

    // MARK: - 上限の警告

    @Test
    func monthlyNotificationsExceedPendingLimit() {
        let first = insertMonthly(days: Set(MonthDay.range), monthEndOffset: 0)
        let second = insertMonthly(days: Set(MonthDay.range), monthEndOffset: 0)
        let monthEnd = insertMonthly(days: [10], monthEndOffset: 0)
        let settings = [first, second, monthEnd]

        // 31 日すべてと月末は 31 件ずつ（月末はどの月も選んだ日付と重なる）、10 日と月末は 1 + 3 件
        #expect(count(settings) == 31 + 31 + 4)
        #expect(actions.requestCount(for: settings, now: Self.now) == 66)
        // `ContentView` は `requestCount > NotificationScheduler.pendingLimit` のときに `PendingLimitNotice` を出す
        #expect(count(settings) > NotificationScheduler.pendingLimit)

        second.isEnabled = false

        #expect(count(settings) == 35)
        #expect(count(settings) <= NotificationScheduler.pendingLimit)
    }

    @Test
    func monthlyUntilDoneWithOtherMonthlyExceedsPendingLimit() {
        let nag = insertMonthlyUntilDone()
        let all = insertMonthly(days: Set(MonthDay.range), monthEndOffset: 3)
        let twoDays = insertMonthly(days: [1, 2], monthEndOffset: nil)

        // 催促 11 件 + 31 日すべて 31 件 + 2 件 = 44 件では出ず、31 日すべてをもう 1 件足すと 75 件で出る
        #expect(count([nag, all, twoDays]) == 44)
        #expect(count([nag, all, twoDays]) <= NotificationScheduler.pendingLimit)

        let another = insertMonthly(days: Set(MonthDay.range))
        let settings = [nag, all, twoDays, another]

        #expect(count(settings) == 75)
        #expect(actions.requestCount(for: settings, now: Self.now) == 75)
        #expect(count(settings) > NotificationScheduler.pendingLimit)
    }

    // MARK: - 補助

    /// 一覧と同じ見積もり（`Sequence<NotificationSetting>.requestCount`）。毎月の通知はおやすみ時間を適用しない
    private func count(_ settings: [NotificationSetting]) -> Int {
        settings.requestCount(quietHours: .default, calendar: Self.calendar, now: Self.now)
    }

    /// 毎月 `days`（と月末の `monthEndOffset` 日前）21 時の通知
    private func insertMonthly(days: Set<Int>, monthEndOffset: Int? = nil) -> NotificationSetting {
        let setting = NotificationSetting(
            message: "家賃",
            kind: .timeOfDay,
            hour: 21,
            repeatRule: .monthly,
            monthDays: days,
            monthEndOffset: monthEndOffset
        )
        container.mainContext.insert(setting)
        return setting
    }

    /// 毎月 5 日 21 時から、1 時間ごとに催促する設定
    private func insertMonthlyUntilDone() -> NotificationSetting {
        let setting = NotificationSetting(
            message: "家賃を振り込む",
            kind: .timeOfDay,
            hour: 21,
            repeatRule: .monthly,
            monthDays: [5],
            repeatsUntilDone: true,
            untilDoneRule: UntilDoneRule(interval: .oneHour)
        )
        container.mainContext.insert(setting)
        return setting
    }

    /// 東京の year-month-day hour:minute
    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
