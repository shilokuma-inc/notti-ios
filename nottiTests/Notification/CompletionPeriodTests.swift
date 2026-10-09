//
//  CompletionPeriodTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing

struct CompletionPeriodTests {
    private static let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    // MARK: - 日ごと

    @Test
    func dailyPeriodRunsFromMidnightByDefault() {
        let period = Self.period(.daily, at: Self.date(2026, 10, 5, 21, 0))

        #expect(period == CompletionPeriod(start: Self.date(2026, 10, 5, 0, 0), end: Self.date(2026, 10, 6, 0, 0)))
    }

    @Test
    func dailyPeriodStartsAtDayBoundary() {
        let rule = UntilDoneRule(dayBoundary: Self.time(4, 0))
        let period = Self.period(.daily, at: Self.date(2026, 10, 5, 21, 0), rule: rule)

        #expect(period == CompletionPeriod(start: Self.date(2026, 10, 5, 4, 0), end: Self.date(2026, 10, 6, 4, 0)))
    }

    @Test
    func timeBeforeDayBoundaryBelongsToPreviousDay() {
        let rule = UntilDoneRule(dayBoundary: Self.time(4, 0))
        let period = Self.period(.daily, at: Self.date(2026, 10, 6, 1, 0), rule: rule)

        #expect(period == CompletionPeriod(start: Self.date(2026, 10, 5, 4, 0), end: Self.date(2026, 10, 6, 4, 0)))
    }

    @Test
    func dayBoundaryItselfBelongsToNewDay() {
        let rule = UntilDoneRule(dayBoundary: Self.time(4, 0))
        let period = Self.period(.daily, at: Self.date(2026, 10, 6, 4, 0), rule: rule)

        #expect(period.start == Self.date(2026, 10, 6, 4, 0))
        #expect(period.contains(Self.date(2026, 10, 6, 4, 0)))
        #expect(!period.contains(Self.date(2026, 10, 7, 4, 0)))
    }

    @Test
    func dailyPeriodAcrossMonthEnd() {
        let rule = UntilDoneRule(dayBoundary: Self.time(4, 0))
        let period = Self.period(.daily, at: Self.date(2026, 11, 1, 3, 59), rule: rule)

        #expect(period == CompletionPeriod(start: Self.date(2026, 10, 31, 4, 0), end: Self.date(2026, 11, 1, 4, 0)))
    }

    @Test
    func dailyPeriodOnDaylightSavingDayIsShorter() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let rule = UntilDoneRule(dayBoundary: Self.time(1, 0))

        let period = CompletionPeriod.containing(date, cycle: .daily, rule: rule, calendar: calendar)

        #expect(period.start == calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 1)))
        #expect(period.end == calendar.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 1)))
        #expect(period.end.timeIntervalSince(period.start) == 23 * 60 * 60)
    }

    // MARK: - 週ごと

    @Test
    func weeklyPeriodRunsFromMondayMidnightByDefault() {
        // 2026-10-10 は土曜
        let period = Self.period(.weekly, at: Self.date(2026, 10, 10, 21, 0))

        #expect(period == CompletionPeriod(start: Self.date(2026, 10, 5, 0, 0), end: Self.date(2026, 10, 12, 0, 0)))
    }

    @Test
    func weeklyPeriodStartsAtWeekStartTime() {
        let rule = UntilDoneRule(weekStart: WeekStart(weekday: .monday, time: Self.time(5, 0)))

        let beforeStart = Self.period(.weekly, at: Self.date(2026, 10, 12, 4, 59), rule: rule)
        let atStart = Self.period(.weekly, at: Self.date(2026, 10, 12, 5, 0), rule: rule)

        #expect(beforeStart == CompletionPeriod(start: Self.date(2026, 10, 5, 5, 0), end: Self.date(2026, 10, 12, 5, 0)))
        #expect(atStart == CompletionPeriod(start: Self.date(2026, 10, 12, 5, 0), end: Self.date(2026, 10, 19, 5, 0)))
    }

    @Test
    func weeklyPeriodWithWeekStartOnSaturday() {
        let rule = UntilDoneRule(weekStart: WeekStart(weekday: .saturday, time: Self.time(0, 0)))

        // 2026-10-09 は金曜。週の始まりはその前の土曜（10-03）
        let period = Self.period(.weekly, at: Self.date(2026, 10, 9, 12, 0), rule: rule)

        #expect(period == CompletionPeriod(start: Self.date(2026, 10, 3, 0, 0), end: Self.date(2026, 10, 10, 0, 0)))
    }

    @Test
    func weeklyPeriodIgnoresDayBoundary() {
        let rule = UntilDoneRule(dayBoundary: Self.time(4, 0))

        let period = Self.period(.weekly, at: Self.date(2026, 10, 12, 1, 0), rule: rule)

        #expect(period.start == Self.date(2026, 10, 12, 0, 0))
    }

    // MARK: - 完了済みの判定

    @Test
    func periodIsCompletedWhenRecordStartIsInside() {
        let period = CompletionPeriod(start: Self.date(2026, 10, 5, 4, 0), end: Self.date(2026, 10, 6, 4, 0))

        #expect(period.isCompleted(byPeriodStarts: [Self.date(2026, 10, 5, 4, 0)]))
        #expect(period.isCompleted(byPeriodStarts: [Self.date(2026, 10, 4, 4, 0), Self.date(2026, 10, 5, 5, 0)]))
        #expect(!period.isCompleted(byPeriodStarts: [Self.date(2026, 10, 4, 4, 0), Self.date(2026, 10, 6, 4, 0)]))
        #expect(!period.isCompleted(byPeriodStarts: []))
    }

    // MARK: - NotificationSetting

    @Test
    func cycleFollowsRepeatRule() {
        #expect(CompletionCycle(.daily) == .daily)
        #expect(CompletionCycle(.weekdays) == .weekly)
        #expect(CompletionCycle(.once) == nil)
    }

    @Test
    @MainActor
    func settingHasPeriodOnlyWhenRepeatingUntilDone() {
        let date = Self.date(2026, 10, 5, 21, 0)
        let calendar = Self.calendar()
        let daily = NotificationSetting(message: "デイリー", kind: .timeOfDay, repeatRule: .daily, repeatsUntilDone: true)
        let weekly = NotificationSetting(
            message: "ウィークリー",
            kind: .timeOfDay,
            repeatRule: .weekdays,
            weekdays: [.saturday],
            repeatsUntilDone: true
        )
        let off = NotificationSetting(message: "OFF", kind: .timeOfDay, repeatRule: .daily)
        let once = NotificationSetting(message: "1 回", kind: .timeOfDay, repeatRule: .once, onceDate: date, repeatsUntilDone: true)
        let interval = NotificationSetting(message: "間隔", repeatsUntilDone: true)

        #expect(daily.completionPeriod(containing: date, calendar: calendar)?.start == Self.date(2026, 10, 5, 0, 0))
        #expect(weekly.completionPeriod(containing: date, calendar: calendar)?.end == Self.date(2026, 10, 12, 0, 0))
        #expect(off.completionPeriod(containing: date, calendar: calendar) == nil)
        #expect(once.completionPeriod(containing: date, calendar: calendar) == nil)
        #expect(interval.completionPeriod(containing: date, calendar: calendar) == nil)
    }

    @Test
    @MainActor
    func settingIsCompletedByStoredRecord() throws {
        let container = try NottiModelContainer.make(inMemory: true)
        let context = container.mainContext
        let calendar = Self.calendar()
        let setting = NotificationSetting(
            message: "デイリー",
            kind: .timeOfDay,
            repeatRule: .daily,
            repeatsUntilDone: true,
            untilDoneRule: UntilDoneRule(dayBoundary: Self.time(4, 0))
        )
        context.insert(setting)
        let today = try #require(setting.completionPeriod(containing: Self.date(2026, 10, 6, 1, 0), calendar: calendar))
        let tomorrow = try #require(setting.completionPeriod(containing: Self.date(2026, 10, 6, 4, 0), calendar: calendar))
        context.insert(CompletionRecord(periodStart: today.start, completedAt: Self.date(2026, 10, 6, 1, 0), setting: setting))
        try context.save()

        #expect(setting.isCompleted(today))
        #expect(!setting.isCompleted(tomorrow))
    }

    // MARK: - 補助

    private static func period(_ cycle: CompletionCycle, at date: Date, rule: UntilDoneRule = UntilDoneRule()) -> CompletionPeriod {
        CompletionPeriod.containing(date, cycle: cycle, rule: rule, calendar: calendar())
    }

    private static func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tokyo
        return calendar
    }

    /// 東京の year-month-day hour:minute
    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar().date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private static func time(_ hour: Int, _ minute: Int) -> TimeOfDay {
        TimeOfDay(hour: hour, minute: minute)
    }
}
