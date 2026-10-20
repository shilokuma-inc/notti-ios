//
//  MonthlyUntilDoneTriggerPlanTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import Testing

struct MonthlyUntilDoneTriggerPlanTests {
    private static let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    /// 東京の 2026-10-05（月曜）12:00
    private static let now = date(2026, 10, 5, 12, 0)

    // MARK: - 完了の期間

    @Test
    func periodIsCalendarMonthFromFirstDayMidnight() {
        let period = Self.period(containing: Self.date(2026, 10, 31, 23, 59))

        #expect(period.start == Self.date(2026, 10, 1, 0, 0))
        #expect(period.end == Self.date(2026, 11, 1, 0, 0))
        #expect(Self.period(containing: Self.date(2026, 11, 1, 0, 0)).start == Self.date(2026, 11, 1, 0, 0))
    }

    @Test
    func periodIgnoresDayBoundaryAndWeekStart() {
        let rule = UntilDoneRule(dayBoundary: Self.time(4, 0), weekStart: WeekStart(weekday: .wednesday, time: Self.time(5, 0)))

        let period = CompletionPeriod.containing(Self.date(2026, 11, 1, 1, 0), cycle: .monthly, rule: rule, calendar: Self.calendar())

        #expect(period.start == Self.date(2026, 11, 1, 0, 0))
    }

    @Test
    func periodCrossesYearAndCountsLeapDay() {
        #expect(Self.period(containing: Self.date(2026, 12, 31, 23, 0)).end == Self.date(2027, 1, 1, 0, 0))
        let leap = Self.period(containing: Self.date(2028, 2, 29, 12, 0))
        #expect(leap.start == Self.date(2028, 2, 1, 0, 0))
        #expect(leap.end == Self.date(2028, 3, 1, 0, 0))
    }

    // MARK: - 催促を始める日

    @Test
    func nagStartIsEarliestDayInMonth() {
        let calendar = Self.calendar()
        let both = TimeOfDaySchedule(time: Self.time(21, 0), repeatRule: .monthly, monthDays: [25], monthEndOffset: 7)
        let days = TimeOfDaySchedule(time: Self.time(21, 0), repeatRule: .monthly, monthDays: [10, 3])

        // 10 月は月末の 7 日前（24 日）が 25 日より早い。2027 年 2 月（28 日）は 21 日
        #expect(Self.nagStart(2026, 10, both) == Self.date(2026, 10, 24, 21, 0))
        #expect(Self.nagStart(2027, 2, both) == Self.date(2027, 2, 21, 21, 0))
        #expect(NotificationTriggerPlan.monthlyNagStart(inMonthOf: Self.date(2026, 10, 15, 9, 0), schedule: days, calendar: calendar)
            == Self.date(2026, 10, 3, 21, 0))
    }

    @Test
    func nagStartIsMissingWhenDayIsNotInMonth() {
        let day31 = TimeOfDaySchedule(time: Self.time(21, 0), repeatRule: .monthly, monthDays: [31])

        #expect(Self.nagStart(2026, 11, day31) == nil)
        #expect(Self.nagStart(2026, 12, day31) == Self.date(2026, 12, 31, 21, 0))
    }

    @Test
    func nagStartOnMonthEndCountsLeapYear() {
        let monthEnd = TimeOfDaySchedule(time: Self.time(21, 0), repeatRule: .monthly, monthEndOffset: 0)
        let threeDaysBefore = TimeOfDaySchedule(time: Self.time(21, 0), repeatRule: .monthly, monthEndOffset: 3)

        #expect(Self.nagStart(2028, 2, monthEnd) == Self.date(2028, 2, 29, 21, 0))
        #expect(Self.nagStart(2027, 2, monthEnd) == Self.date(2027, 2, 28, 21, 0))
        #expect(Self.nagStart(2028, 2, threeDaysBefore) == Self.date(2028, 2, 26, 21, 0))
        #expect(Self.nagStart(2027, 2, threeDaysBefore) == Self.date(2027, 2, 25, 21, 0))
    }

    // MARK: - 催促の日時

    @Test
    func nagsFromStartDayAndFirstNagsOfComingMonths() {
        let dates = Self.fireDates(monthDays: [5])

        // 3 日ぶん（5〜7 日の 21〜23 時）と、11・12 月の最初の催促。10 月 5 日 21 時は重ねない
        #expect(dates.count == 9 + 2)
        #expect(dates.first == Self.date(2026, 10, 5, 21, 0))
        #expect(dates.suffix(2) == [Self.date(2026, 11, 5, 21, 0), Self.date(2026, 12, 5, 21, 0)])
        #expect(Set(dates).count == dates.count)
        #expect(dates == dates.sorted())
    }

    @Test
    func doesNotNagBeforeStartDay() {
        let dates = Self.fireDates(monthDays: [20])

        #expect(dates == [Self.date(2026, 10, 20, 21, 0), Self.date(2026, 11, 20, 21, 0), Self.date(2026, 12, 20, 21, 0)])
    }

    @Test
    func nagsEveryDayUntilMonthEndAndStartsOverNextMonth() {
        let dates = Self.fireDates(monthDays: [20], now: Self.date(2026, 10, 30, 12, 0))

        // 10 月 30・31 日の 21〜23 時。11 月 1 日は 11 月の催促を始める日（20 日）より前なので鳴らない
        #expect(dates.prefix(6) == [
            Self.date(2026, 10, 30, 21, 0), Self.date(2026, 10, 30, 22, 0), Self.date(2026, 10, 30, 23, 0),
            Self.date(2026, 10, 31, 21, 0), Self.date(2026, 10, 31, 22, 0), Self.date(2026, 10, 31, 23, 0)
        ])
        // 今月の最初の催促は過ぎたので、来月から 3 か月（年をまたぐ）
        #expect(dates.dropFirst(6) == [Self.date(2026, 11, 20, 21, 0), Self.date(2026, 12, 20, 21, 0), Self.date(2027, 1, 20, 21, 0)])
    }

    @Test
    func completedMonthIsSkipped() {
        let completed = [Self.date(2026, 10, 1, 0, 0)]

        let late = Self.fireDates(monthDays: [20], now: Self.date(2026, 10, 30, 12, 0), completed: completed)
        // 今月の催促を始める日の前に完了しても、今月の分は月の数に数える
        let early = Self.fireDates(monthDays: [20], completed: completed)

        #expect(late == [Self.date(2026, 11, 20, 21, 0), Self.date(2026, 12, 20, 21, 0), Self.date(2027, 1, 20, 21, 0)])
        #expect(early == [Self.date(2026, 11, 20, 21, 0), Self.date(2026, 12, 20, 21, 0)])
    }

    @Test
    func monthWithoutChosenDayIsSkipped() {
        // 11 月は 31 日が無いので来月から。2 月も 31 日が無いので入れない
        let dates = Self.fireDates(monthDays: [31], now: Self.date(2026, 11, 5, 12, 0))
        let endOfNovember = Self.fireDates(monthDays: [31], now: Self.date(2026, 11, 29, 12, 0))

        #expect(dates == [Self.date(2026, 12, 31, 21, 0), Self.date(2027, 1, 31, 21, 0)])
        #expect(endOfNovember == dates)
    }

    @Test
    func firstNagsOverlappingThreeDaysAreNotDuplicated() {
        let dates = Self.fireDates(monthDays: [1], now: Self.date(2026, 10, 30, 12, 0))

        // 10 月 30・31 日と 11 月 1 日の 21〜23 時に、12 月・1 月の最初の催促。11 月 1 日 21 時は 1 回だけ
        #expect(dates.count == 9 + 2)
        #expect(dates.filter { $0 == Self.date(2026, 11, 1, 21, 0) }.count == 1)
        #expect(dates.suffix(2) == [Self.date(2026, 12, 1, 21, 0), Self.date(2027, 1, 1, 21, 0)])
    }

    @Test
    func monthEndNagsMatchMonthEndFireDates() {
        let dates = Self.fireDates(monthEndOffset: 0)
        let calendar = Self.calendar()
        let monthEnds = NotificationTriggerPlan.monthEndFireDates(time: Self.time(21, 0), offset: 0, now: Self.now, calendar: calendar)

        #expect(dates == monthEnds)
        #expect(dates == [Self.date(2026, 10, 31, 21, 0), Self.date(2026, 11, 30, 21, 0), Self.date(2026, 12, 31, 21, 0)])
    }

    @Test
    func nonexistentTimeOnDaylightSavingDayMovesToNextTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 12)))
        // 2026-03-29（月末の 2 日前）は 2:00 に 3:00 へ進むので、2:30 は無い
        let schedule = TimeOfDaySchedule(time: Self.time(2, 30), repeatRule: .monthly, monthEndOffset: 2)

        let dates = NotificationTriggerPlan.untilDoneFireDates(
            schedule: schedule,
            rule: UntilDoneRule(interval: .oneHour),
            completedPeriodStarts: [],
            now: now,
            calendar: calendar
        )
        let monthEnds = NotificationTriggerPlan.monthEndFireDates(time: Self.time(2, 30), offset: 2, now: now, calendar: calendar)

        #expect(dates == monthEnds)
        let first = try #require(dates.first)
        #expect(calendar.component(.day, from: first) == 29)
        #expect(calendar.component(.hour, from: first) == 3)
    }

    @Test
    func monthlyWithoutDayNeverNags() {
        #expect(Self.fireDates().isEmpty)
        #expect(Self.fireDates(monthDays: [32]).isEmpty)
    }

    @Test
    func singleSettingIsCappedAtPendingLimit() {
        let plan = NotificationTriggerPlan.make(
            schedule: TimeOfDaySchedule(time: Self.time(6, 0), repeatRule: .monthly, monthDays: [5]),
            rule: UntilDoneRule(interval: .tenMinutes),
            completedPeriodStarts: [],
            now: Self.date(2026, 10, 5, 5, 0),
            calendar: Self.calendar()
        )

        #expect(plan.requestCount == NotificationScheduler.pendingLimit)
    }

    // MARK: - 補助

    private static func fireDates(
        monthDays: Set<Int> = [],
        monthEndOffset: Int? = nil,
        now: Date = now,
        completed: [Date] = []
    ) -> [Date] {
        NotificationTriggerPlan.untilDoneFireDates(
            schedule: TimeOfDaySchedule(time: time(21, 0), repeatRule: .monthly, monthDays: monthDays, monthEndOffset: monthEndOffset),
            rule: UntilDoneRule(interval: .oneHour),
            completedPeriodStarts: completed,
            now: now,
            calendar: calendar()
        )
    }

    private static func nagStart(_ year: Int, _ month: Int, _ schedule: TimeOfDaySchedule) -> Date? {
        NotificationTriggerPlan.monthlyNagStart(inMonthOf: date(year, month, 1, 0, 0), schedule: schedule, calendar: calendar())
    }

    private static func period(containing date: Date) -> CompletionPeriod {
        CompletionPeriod.containing(date, cycle: .monthly, rule: UntilDoneRule(), calendar: calendar())
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
