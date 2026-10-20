//
//  MonthlySettingTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing

@MainActor
struct MonthlySettingTests {
    /// 東京の 2026-10-05 12:00
    private let now = NotificationScheduler.testCalendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 12))!

    @Test
    func monthlyRawValueAndLabel() {
        #expect(NotificationRepeat.monthly.rawValue == "monthly")
        #expect(NotificationRepeat.monthly.label == "毎月")
        #expect(NotificationRepeat(rawValue: "monthly") == .monthly)
    }

    @Test
    func monthlyIsSelectableLast() {
        #expect(NotificationRepeat.selectableCases == [.daily, .weekdays, .once, .monthly])
        #expect(Set(NotificationRepeat.selectableCases) == Set(NotificationRepeat.allCases))
    }

    @Test
    func initUsesMonthlyDefaults() {
        let setting = NotificationSetting(message: "家賃")

        #expect(setting.monthDays.isEmpty)
        #expect(setting.monthEndOffset == nil)
        #expect(setting.monthDayMask == 0)
        #expect(!setting.repeatsOnMonthEnd)
        #expect(setting.monthEndOffsetDays == 0)
    }

    @Test
    func monthlySettingIsPersisted() throws {
        let container = try NottiModelContainer.make(inMemory: true)
        let context = container.mainContext
        let setting = NotificationSetting(
            message: "家賃",
            kind: .timeOfDay,
            repeatRule: .monthly,
            monthDays: [10, 27],
            monthEndOffset: 3
        )
        context.insert(setting)
        try context.save()

        let fetched = try #require(try ModelContext(container).fetch(FetchDescriptor<NotificationSetting>()).first)

        #expect(fetched.repeatRule == .monthly)
        #expect(fetched.monthDays == [10, 27])
        #expect(fetched.monthEndOffset == 3)
    }

    @Test
    func monthEndOffsetIsClampedAndCleared() {
        let setting = NotificationSetting(message: "家賃", monthEndOffset: 0)
        #expect(setting.monthEndOffset == 0)
        #expect(setting.repeatsOnMonthEnd)

        setting.monthEndOffsetDays = 99
        #expect(setting.monthEndOffset == MonthDay.monthEndOffsetRange.upperBound)
        setting.monthEndOffsetDays = -1
        #expect(setting.monthEndOffset == 0)

        setting.monthEndOffset = 12
        #expect(setting.monthEndOffsetDays == MonthDay.monthEndOffsetRange.upperBound)
        setting.monthEndOffset = -3
        #expect(setting.monthEndOffsetDays == 0)

        setting.monthEndOffset = nil
        #expect(!setting.repeatsOnMonthEnd)
        #expect(setting.monthEndOffsetDays == 0)
    }

    @Test
    func draftRoundTripsMonthlySchedule() {
        let setting = NotificationSetting(
            message: "家賃",
            kind: .timeOfDay,
            hour: 21,
            repeatRule: .monthly,
            monthDays: [1, 15],
            monthEndOffset: 2
        )

        let draft = setting.draft
        #expect(draft.schedule.repeatRule == .monthly)
        #expect(draft.schedule.monthDays == [1, 15])
        #expect(draft.schedule.monthEndOffset == 2)
        #expect(draft.schedule.time == TimeOfDay(hour: 21, minute: 0))

        let other = NotificationSetting(message: "別")
        other.apply(draft)
        #expect(other.repeatRule == .monthly)
        #expect(other.monthDays == [1, 15])
        #expect(other.monthEndOffset == 2)
        #expect(other.draft == draft)
    }

    @Test
    func monthlyNeedsDayOrMonthEnd() {
        var draft = NotificationDraft(message: "家賃", kind: .timeOfDay)
        draft.schedule.repeatRule = .monthly
        #expect(draft.problem(now: now, calendar: NotificationScheduler.testCalendar) == .noMonthDay)

        draft.schedule.monthDays = [31]
        #expect(draft.problem(now: now, calendar: NotificationScheduler.testCalendar) == nil)

        draft.schedule.monthDays = []
        draft.schedule.monthEndOffset = 0
        #expect(draft.problem(now: now, calendar: NotificationScheduler.testCalendar) == nil)

        // 範囲外の日付だけでは、保存すると何も選んでいない設定になる
        draft.schedule.monthDays = [0, 32]
        draft.schedule.monthEndOffset = nil
        #expect(draft.problem(now: now, calendar: NotificationScheduler.testCalendar) == .noMonthDay)
    }

    @Test
    func daysMissingInSomeMonthsAreTwentyNineToThirtyOne() {
        var schedule = TimeOfDaySchedule(time: TimeOfDay(hour: 9, minute: 0), repeatRule: .monthly, monthDays: [1, 28])
        #expect(!schedule.hasDaysMissingInSomeMonths)

        for day in 29...31 {
            schedule.monthDays = [1, day]
            #expect(schedule.hasDaysMissingInSomeMonths)
        }

        // 月末（N 日前）はどの月にもあるので警告しない
        schedule.monthDays = []
        schedule.monthEndOffset = 0
        #expect(!schedule.hasDaysMissingInSomeMonths)
    }

    @Test
    func monthEndOffsetLabels() {
        #expect(MonthDayPicker.offsetLabel(0) == "月末の当日")
        #expect(MonthDayPicker.offsetLabel(3) == "3 日前")
    }

    @Test
    func intervalIgnoresMonthlyFields() {
        var draft = NotificationDraft(message: "水を飲む")
        draft.schedule.repeatRule = .monthly

        #expect(draft.problem(now: now, calendar: NotificationScheduler.testCalendar) == nil)
    }

    @Test
    func untilDoneIsNotAvailableForMonthlyYet() {
        var draft = NotificationDraft(message: "家賃", kind: .timeOfDay)
        draft.schedule.repeatRule = .monthly
        #expect(!draft.isUntilDoneAvailable)

        #expect(CompletionCycle(.monthly) == nil)
        let setting = NotificationSetting(message: "家賃", kind: .timeOfDay, repeatRule: .monthly, monthDays: [10], repeatsUntilDone: true)
        #expect(setting.completionCycle == nil)
    }
}
