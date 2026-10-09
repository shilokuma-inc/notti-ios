//
//  UntilDoneTriggerPlanTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import Testing

struct UntilDoneTriggerPlanTests {
    private static let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    /// 東京の 2026-10-05（月曜）12:00
    private static let monday = date(2026, 10, 5, 12, 0)

    // MARK: - 毎日

    @Test
    func dailyNagsFromStartTimeUntilMidnightForThreeDays() {
        let dates = Self.fireDates(.daily, time: Self.time(21, 0), interval: .thirtyMinutes)

        #expect(dates.count == 18)
        #expect(dates.first == Self.date(2026, 10, 5, 21, 0))
        #expect(dates.last == Self.date(2026, 10, 7, 23, 30))
        #expect(dates == dates.sorted())
    }

    @Test
    func tenMinutesFromNinePmFitInFiftyFourRequests() {
        let dates = Self.fireDates(.daily, time: Self.time(21, 0), interval: .tenMinutes)

        #expect(dates.count == 54)
        #expect(dates.last == Self.date(2026, 10, 7, 23, 50))
    }

    @Test
    func pastTimesAreSkipped() {
        let dates = Self.fireDates(.daily, time: Self.time(21, 0), interval: .thirtyMinutes, now: Self.date(2026, 10, 5, 22, 10))

        #expect(dates.first == Self.date(2026, 10, 5, 22, 30))
        #expect(dates.count == 3 + 6 + 6)
    }

    @Test
    func completedDayIsSkippedAndNextDayNagsAgain() {
        let dates = Self.fireDates(
            .daily,
            time: Self.time(21, 0),
            interval: .thirtyMinutes,
            completed: [Self.date(2026, 10, 5, 0, 0)]
        )

        #expect(dates.count == 12)
        #expect(dates.first == Self.date(2026, 10, 6, 21, 0))
    }

    @Test
    func timesBeforeDayBoundaryBelongToPreviousDay() {
        // 区切りが 4 時、開始が 2 時。翌日の 2〜3 時台は前の日の期間なので、前の日を完了していれば鳴らない
        let dates = Self.fireDates(
            .daily,
            time: Self.time(2, 0),
            interval: .oneHour,
            rule: UntilDoneRule(interval: .oneHour, dayBoundary: Self.time(4, 0)),
            completed: [Self.date(2026, 10, 5, 4, 0)]
        )

        #expect(!dates.contains(Self.date(2026, 10, 5, 23, 0)))
        #expect(!dates.contains(Self.date(2026, 10, 6, 3, 0)))
        #expect(dates.first == Self.date(2026, 10, 6, 4, 0))
        #expect(dates.contains(Self.date(2026, 10, 7, 2, 0)))
        #expect(dates.count == 20 + 22)
    }

    @Test
    func nagsStopAtMidnightEvenWhenDayBoundaryIsLater() {
        let dates = Self.fireDates(
            .daily,
            time: Self.time(22, 0),
            interval: .oneHour,
            rule: UntilDoneRule(interval: .oneHour, dayBoundary: Self.time(4, 0))
        )

        #expect(dates == [
            Self.date(2026, 10, 5, 22, 0), Self.date(2026, 10, 5, 23, 0),
            Self.date(2026, 10, 6, 22, 0), Self.date(2026, 10, 6, 23, 0),
            Self.date(2026, 10, 7, 22, 0), Self.date(2026, 10, 7, 23, 0)
        ])
    }

    // MARK: - 毎週

    @Test
    func weeklyNagsEveryDayFromStartWeekdayUntilWeekEnd() {
        // 金曜の昼。土曜 21 時から始め、日曜も催促する。月曜からは次の週なので、次の土曜まで鳴らない
        let dates = Self.fireDates(.weekdays, weekdays: [.saturday], now: Self.date(2026, 10, 9, 12, 0), days: 4)

        #expect(dates == [
            Self.date(2026, 10, 10, 21, 0), Self.date(2026, 10, 10, 22, 0), Self.date(2026, 10, 10, 23, 0),
            Self.date(2026, 10, 11, 21, 0), Self.date(2026, 10, 11, 22, 0), Self.date(2026, 10, 11, 23, 0)
        ])
    }

    @Test
    func weeklyDoesNotNagBeforeStartWeekday() {
        let dates = Self.fireDates(.weekdays, weekdays: [.wednesday])

        #expect(dates == [Self.date(2026, 10, 7, 21, 0), Self.date(2026, 10, 7, 22, 0), Self.date(2026, 10, 7, 23, 0)])
    }

    @Test
    func weeklyStartingOnLastDayOfWeekNagsOnlyThatDay() {
        // 週の始まりが月曜で始める曜日が日曜なら、日曜だけ鳴る
        let dates = Self.fireDates(.weekdays, weekdays: [.sunday], now: Self.date(2026, 10, 10, 12, 0))

        #expect(dates == [Self.date(2026, 10, 11, 21, 0), Self.date(2026, 10, 11, 22, 0), Self.date(2026, 10, 11, 23, 0)])
    }

    @Test
    func completedWeekIsSkipped() {
        let dates = Self.fireDates(
            .weekdays,
            weekdays: [.saturday],
            now: Self.date(2026, 10, 9, 12, 0),
            completed: [Self.date(2026, 10, 5, 0, 0)],
            days: 4
        )

        #expect(dates.isEmpty)
    }

    @Test
    func weekStartTimeSplitsWeeks() {
        // 週の始まりが月曜 5 時なら、月曜 0〜4 時台は前の週。日曜から始めた前の週の催促が続く
        let rule = UntilDoneRule(interval: .oneHour, weekStart: WeekStart(weekday: .monday, time: Self.time(5, 0)))
        let dates = Self.fireDates(.weekdays, time: Self.time(1, 0), weekdays: [.sunday], rule: rule, now: Self.date(2026, 10, 11, 12, 0))

        #expect(dates.contains(Self.date(2026, 10, 11, 23, 0)))
        #expect(dates.contains(Self.date(2026, 10, 12, 4, 0)))
        #expect(!dates.contains(Self.date(2026, 10, 12, 5, 0)))
        #expect(dates.last == Self.date(2026, 10, 12, 4, 0))
    }

    @Test
    func multipleWeekdaysStartFromFirstWeekdayOfWeek() {
        let dates = Self.fireDates(.weekdays, weekdays: [.saturday, .tuesday], now: Self.date(2026, 10, 6, 12, 0))

        #expect(dates.count == 9)
        #expect(dates.first == Self.date(2026, 10, 6, 21, 0))
    }

    // MARK: - 鳴らさない

    @Test
    func onceAndWeekdaysWithoutDaysNeverNag() {
        #expect(Self.fireDates(.once).isEmpty)
        #expect(Self.fireDates(.weekdays, weekdays: []).isEmpty)
    }

    // MARK: - 補助

    private static func fireDates(
        _ repeatRule: NotificationRepeat,
        time: TimeOfDay = Self.time(21, 0),
        weekdays: Set<Weekday> = [],
        interval: NagInterval = .oneHour,
        rule: UntilDoneRule? = nil,
        now: Date = monday,
        completed: [Date] = [],
        days: Int = NotificationTriggerPlan.untilDoneDays
    ) -> [Date] {
        NotificationTriggerPlan.untilDoneFireDates(
            schedule: TimeOfDaySchedule(time: time, repeatRule: repeatRule, weekdays: weekdays, onceDate: now),
            rule: rule ?? UntilDoneRule(interval: interval),
            completedPeriodStarts: completed,
            now: now,
            calendar: calendar(),
            days: days
        )
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
