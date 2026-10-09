//
//  UntilDoneLabelTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing

@MainActor
struct UntilDoneLabelTests {
    /// 東京の 2026-10-05（月曜）12:00
    private static let now = date(2026, 10, 5, 12, 0)
    private static let calendar = NotificationScheduler.testCalendar

    private let container: ModelContainer

    init() throws {
        container = try NottiModelContainer.make(inMemory: true)
    }

    @Test
    func scheduleLabelShowsNagInterval() {
        let daily = NotificationSetting(message: "デイリー", kind: .timeOfDay, hour: 21, repeatsUntilDone: true)
        let weekly = NotificationSetting(
            message: "ウィークリー",
            kind: .timeOfDay,
            hour: 21,
            repeatRule: .weekdays,
            weekdays: [.saturday],
            repeatsUntilDone: true,
            untilDoneRule: UntilDoneRule(interval: .tenMinutes)
        )

        #expect(daily.scheduleLabel(now: Self.now, calendar: Self.calendar) == "毎日 21:00・完了まで 30 分ごと")
        #expect(weekly.scheduleLabel(now: Self.now, calendar: Self.calendar) == "毎週 土 21:00・完了まで 10 分ごと")
    }

    @Test
    func settingNotRepeatingUntilDoneHasNoCompletionStatus() {
        let off = NotificationSetting(message: "デイリー", kind: .timeOfDay, hour: 21)
        let once = NotificationSetting(message: "1 回", kind: .timeOfDay, repeatRule: .once, onceDate: Self.now, repeatsUntilDone: true)

        #expect(off.scheduleLabel(now: Self.now, calendar: Self.calendar) == "毎日 21:00")
        #expect(off.completionStatusLabel(now: Self.now, calendar: Self.calendar) == nil)
        #expect(off.isCurrentPeriodCompleted(now: Self.now, calendar: Self.calendar) == nil)
        #expect(once.completionStatusLabel(now: Self.now, calendar: Self.calendar) == nil)
        #expect(!once.scheduleLabel(now: Self.now, calendar: Self.calendar).contains("完了まで"))
    }

    @Test
    func dailyStatusFollowsTodaysCompletion() {
        let setting = NotificationSetting(message: "デイリー", kind: .timeOfDay, hour: 21, repeatsUntilDone: true)
        container.mainContext.insert(setting)
        #expect(setting.completionStatusLabel(now: Self.now, calendar: Self.calendar) == "今日はまだ完了していません")

        container.mainContext.insert(CompletionRecord(periodStart: Self.date(2026, 10, 5, 0, 0), completedAt: Self.now, setting: setting))

        #expect(setting.isCurrentPeriodCompleted(now: Self.now, calendar: Self.calendar) == true)
        #expect(setting.completionStatusLabel(now: Self.now, calendar: Self.calendar) == "今日は完了済み")
        // 翌日は未完了に戻る
        #expect(setting.completionStatusLabel(now: Self.date(2026, 10, 6, 0, 0), calendar: Self.calendar) == "今日はまだ完了していません")
    }

    @Test
    func weeklyStatusFollowsThisWeeksCompletion() {
        let setting = NotificationSetting(
            message: "ウィークリー",
            kind: .timeOfDay,
            hour: 21,
            repeatRule: .weekdays,
            weekdays: [.saturday],
            repeatsUntilDone: true
        )
        container.mainContext.insert(setting)
        container.mainContext.insert(CompletionRecord(periodStart: Self.date(2026, 10, 5, 0, 0), completedAt: Self.now, setting: setting))

        #expect(setting.completionStatusLabel(now: Self.date(2026, 10, 11, 23, 0), calendar: Self.calendar) == "今週は完了済み")
        #expect(setting.completionStatusLabel(now: Self.date(2026, 10, 12, 0, 0), calendar: Self.calendar) == "今週はまだ完了していません")
    }

    /// 東京の year-month-day hour:minute
    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        NotificationScheduler.testCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
