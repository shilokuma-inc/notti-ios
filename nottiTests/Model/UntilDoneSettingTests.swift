//
//  UntilDoneSettingTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing

@MainActor
struct UntilDoneSettingTests {
    @Test
    func initUsesDefaults() {
        let setting = NotificationSetting(message: "デイリーミッション")

        #expect(!setting.repeatsUntilDone)
        #expect(setting.nagInterval == .thirtyMinutes)
        #expect(setting.dayBoundary == TimeOfDay(hour: 0, minute: 0))
        #expect(setting.weekStart == WeekStart(weekday: .monday, time: TimeOfDay(hour: 0, minute: 0)))
        #expect(setting.untilDoneRule == UntilDoneRule())
        #expect(setting.completions.isEmpty)
    }

    @Test
    func untilDoneSettingIsPersisted() throws {
        let container = try NottiModelContainer.make(inMemory: true)
        let rule = UntilDoneRule(
            interval: .tenMinutes,
            dayBoundary: TimeOfDay(hour: 4, minute: 0),
            weekStart: WeekStart(weekday: .monday, time: TimeOfDay(hour: 5, minute: 0))
        )
        let setting = NotificationSetting(
            message: "デイリーミッション",
            kind: .timeOfDay,
            hour: 21,
            repeatsUntilDone: true,
            untilDoneRule: rule
        )
        container.mainContext.insert(setting)
        try container.mainContext.save()

        let fetched = try ModelContext(container).fetch(FetchDescriptor<NotificationSetting>())
        let fetchedSetting = try #require(fetched.first)

        #expect(fetchedSetting.repeatsUntilDone)
        #expect(fetchedSetting.untilDoneRule == rule)
    }

    @Test
    func accessorsUpdateStoredValues() {
        let setting = NotificationSetting(message: "ウィークリーミッション")

        setting.untilDoneRule = UntilDoneRule(
            interval: .oneHour,
            dayBoundary: TimeOfDay(hour: 4, minute: 30),
            weekStart: WeekStart(weekday: .saturday, time: TimeOfDay(hour: 5, minute: 15))
        )

        #expect(setting.nagIntervalMinutes == 60)
        #expect(setting.dayBoundaryHour == 4)
        #expect(setting.dayBoundaryMinute == 30)
        #expect(setting.weekStartWeekdayRawValue == 7)
        #expect(setting.weekStartHour == 5)
        #expect(setting.weekStartMinute == 15)
    }

    @Test
    func unknownStoredValuesFallBackToDefaults() {
        let setting = NotificationSetting(message: "デイリーミッション")

        setting.nagIntervalMinutes = 7
        setting.weekStartWeekdayRawValue = 0

        #expect(setting.nagInterval == .thirtyMinutes)
        #expect(setting.weekStart.weekday == .monday)
    }

    @Test
    func completionsAreSavedWithSetting() throws {
        let container = try NottiModelContainer.make(inMemory: true)
        let context = container.mainContext
        let setting = NotificationSetting(message: "デイリーミッション", kind: .timeOfDay, repeatsUntilDone: true)
        let periodStart = Date(timeIntervalSince1970: 1_800_000_000)
        context.insert(setting)
        let record = CompletionRecord(periodStart: periodStart, completedAt: periodStart.addingTimeInterval(3600), setting: setting)
        context.insert(record)
        try context.save()

        let fetched = try ModelContext(container).fetch(FetchDescriptor<NotificationSetting>())
        let fetchedSetting = try #require(fetched.first)

        #expect(fetchedSetting.completions.count == 1)
        #expect(fetchedSetting.completions.first?.periodStart == periodStart)
        #expect(fetchedSetting.completions.first?.completedAt == periodStart.addingTimeInterval(3600))
    }

    @Test
    func deletingSettingDeletesCompletions() throws {
        let container = try NottiModelContainer.make(inMemory: true)
        let context = container.mainContext
        let deleted = NotificationSetting(message: "デイリーミッション", kind: .timeOfDay, repeatsUntilDone: true)
        let kept = NotificationSetting(message: "ウィークリーミッション", kind: .timeOfDay, repeatsUntilDone: true)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        context.insert(deleted)
        context.insert(kept)
        context.insert(CompletionRecord(periodStart: date, completedAt: date, setting: deleted))
        context.insert(CompletionRecord(periodStart: date, completedAt: date, setting: kept))
        try context.save()

        context.delete(deleted)
        try context.save()

        let records = try ModelContext(container).fetch(FetchDescriptor<CompletionRecord>())
        #expect(records.count == 1)
        #expect(records.first?.setting?.id == kept.id)
    }
}
