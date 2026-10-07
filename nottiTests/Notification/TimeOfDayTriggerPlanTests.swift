//
//  TimeOfDayTriggerPlanTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import Testing

struct TimeOfDayTriggerPlanTests {
    private static let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    private static let overnight = QuietHours(isEnabled: true, start: time(23, 0), end: time(7, 0))
    /// 東京の 2026-10-05 12:00
    private static let now = date(2026, 10, 5, 12, 0)

    // MARK: - 毎日

    @Test
    func dailyRepeatsAtTimeEveryDay() {
        let plan = Self.plan(.daily, time: Self.time(21, 30))

        #expect(plan == .timeOfDay([.daily(Self.time(21, 30))]))
        #expect(plan.requestCount == 1)
        let trigger = TimeOfDayTrigger.daily(Self.time(21, 30))
        #expect(trigger.dateComponents == DateComponents(hour: 21, minute: 30))
        #expect(trigger.repeats)
    }

    // MARK: - 曜日

    @Test
    func weekdaysRepeatOncePerSelectedWeekdayInOrder() {
        let plan = Self.plan(.weekdays, time: Self.time(7, 15), weekdays: [.friday, .monday, .sunday])

        #expect(plan == .timeOfDay([
            .weekly(.sunday, Self.time(7, 15)),
            .weekly(.monday, Self.time(7, 15)),
            .weekly(.friday, Self.time(7, 15))
        ]))
        #expect(plan.requestCount == 3)
    }

    @Test
    func allWeekdaysMakeSevenTriggers() {
        let plan = Self.plan(.weekdays, weekdays: Set(Weekday.allCases))
        #expect(plan.requestCount == 7)
    }

    @Test
    func noWeekdaysNeverRings() {
        let plan = Self.plan(.weekdays, weekdays: [])
        #expect(plan == .timeOfDay([]))
        #expect(plan.requestCount == 0)
    }

    @Test(arguments: Weekday.allCases)
    func weeklyComponentsUseGregorianWeekdayNumber(weekday: Weekday) {
        let trigger = TimeOfDayTrigger.weekly(weekday, Self.time(8, 0))

        #expect(trigger.dateComponents == DateComponents(hour: 8, minute: 0, weekday: weekday.rawValue))
        #expect(trigger.repeats)
    }

    @Test
    func weekdayNumbersDoNotDependOnCalendarSettings() {
        // 週の始まりが月曜の暦や、和暦・仏暦の端末でも、DateComponents.weekday は 1 = 日曜のまま
        let sunday = Self.date(2026, 10, 4, 9, 0)
        for identifier in [Calendar.Identifier.gregorian, .japanese, .buddhist, .iso8601] {
            var calendar = Calendar(identifier: identifier)
            calendar.timeZone = Self.tokyo
            calendar.firstWeekday = 2
            #expect(calendar.component(.weekday, from: sunday) == Weekday.sunday.rawValue)

            let plan = Self.plan(.weekdays, weekdays: [.sunday], calendar: calendar)
            #expect(plan == .timeOfDay([.weekly(.sunday, Self.time(9, 0))]))
        }
    }

    // MARK: - 1 回だけ

    @Test
    func onceRingsAtDateWithoutRepeating() {
        let onceDate = Self.date(2026, 10, 25, 9, 30)

        let plan = Self.plan(.once, onceDate: onceDate)

        guard case let .timeOfDay(triggers) = plan, let trigger = triggers.first, triggers.count == 1 else {
            Issue.record("1 本だけのトリガーになるはず: \(plan)")
            return
        }
        let components = trigger.dateComponents
        #expect(components.year == 2026)
        #expect(components.month == 10)
        #expect(components.day == 25)
        #expect(components.hour == 9)
        #expect(components.minute == 30)
        #expect(components.second == nil)
        #expect(!trigger.repeats)
        #expect(Self.calendar().date(from: components) == onceDate)
    }

    @Test
    func onceIgnoresSecondsBelowMinute() {
        let onceDate = Self.date(2026, 10, 25, 9, 30).addingTimeInterval(45)

        let plan = Self.plan(.once, onceDate: onceDate)

        guard case let .timeOfDay(triggers) = plan, let trigger = triggers.first else {
            Issue.record("1 本だけのトリガーになるはず: \(plan)")
            return
        }
        #expect(trigger.dateComponents.minute == 30)
        #expect(trigger.dateComponents.second == nil)
    }

    @Test(arguments: [-86_400.0, -60, 0, 30])
    func onceAtOrBeforeNowNeverRings(offset: TimeInterval) {
        // 12:00:30 は分に切り捨てると 12:00 で、もう過ぎている
        let plan = Self.plan(.once, onceDate: Self.now.addingTimeInterval(offset))
        #expect(plan == .timeOfDay([]))
        #expect(plan.requestCount == 0)
    }

    @Test
    func onceOneMinuteLaterRings() {
        let plan = Self.plan(.once, onceDate: Self.now.addingTimeInterval(60))
        #expect(plan.requestCount == 1)
    }

    @Test
    func onceWithoutDateNeverRings() {
        #expect(Self.plan(.once, onceDate: nil) == .timeOfDay([]))
    }

    @Test
    func onceDateIsReadInCalendarTimeZone() throws {
        // 東京の 2026-10-25 9:30 は UTC の 0:30
        let onceDate = Self.date(2026, 10, 25, 9, 30)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(identifier: "UTC"))

        let plan = Self.plan(.once, onceDate: onceDate, calendar: utc)

        guard case let .timeOfDay(triggers) = plan, let trigger = triggers.first else {
            Issue.record("1 本だけのトリガーになるはず: \(plan)")
            return
        }
        #expect(trigger.dateComponents.day == 25)
        #expect(trigger.dateComponents.hour == 0)
        #expect(trigger.dateComponents.minute == 30)
    }

    // MARK: - 設定からの変換と件数

    @Test
    func timeOfDaySettingIgnoresQuietHours() {
        let setting = NotificationSetting(message: "夜のデイリー", kind: .timeOfDay, hour: 23, minute: 30)

        let plan = setting.plan(quietHours: Self.overnight, calendar: Self.calendar(), now: Self.now)

        #expect(plan == .timeOfDay([.daily(Self.time(23, 30))]))
        #expect(!plan.isSilent)
        #expect(!setting.isSilent(quietHours: Self.overnight, calendar: Self.calendar()))
    }

    @Test
    func intervalSettingStillUsesIntervalPlan() {
        let setting = NotificationSetting(message: "水を飲む", startDate: Self.now)
        #expect(setting.plan(quietHours: .default, calendar: Self.calendar(), now: Self.now) == .repeatingInterval(3600))
    }

    @Test
    func requestCountIncludesTimeOfDaySettings() {
        let settings = [
            NotificationSetting(message: "間隔", startDate: Self.date(2026, 10, 5, 14, 23)),
            NotificationSetting(message: "毎日", kind: .timeOfDay),
            NotificationSetting(message: "曜日", kind: .timeOfDay, repeatRule: .weekdays, weekdays: [.monday, .wednesday, .friday]),
            NotificationSetting(message: "1 回", kind: .timeOfDay, repeatRule: .once, onceDate: Self.date(2026, 10, 25, 9, 0)),
            NotificationSetting(message: "過ぎた 1 回", kind: .timeOfDay, repeatRule: .once, onceDate: Self.date(2026, 10, 1, 9, 0)),
            NotificationSetting(message: "OFF", isEnabled: false, kind: .timeOfDay, repeatRule: .weekdays, weekdays: Set(Weekday.allCases))
        ]

        let count = settings.requestCount(quietHours: Self.overnight, calendar: Self.calendar(), now: Self.now)

        // 間隔（1 時間・おやすみ時間あり）16 + 毎日 1 + 曜日 3 + 1 回 1 + 過ぎた 1 回 0
        #expect(count == 16 + 1 + 3 + 1)
    }

    // MARK: - ヘルパー

    private static func plan(
        _ repeatRule: NotificationRepeat,
        time: TimeOfDay = Self.time(9, 0),
        weekdays: Set<Weekday> = [],
        onceDate: Date? = nil,
        calendar: Calendar = Self.calendar()
    ) -> NotificationTriggerPlan {
        NotificationTriggerPlan.make(
            schedule: TimeOfDaySchedule(time: time, repeatRule: repeatRule, weekdays: weekdays, onceDate: onceDate),
            now: now,
            calendar: calendar
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
