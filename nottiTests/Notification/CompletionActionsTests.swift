//
//  CompletionActionsTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing

@MainActor
struct CompletionActionsTests {
    /// 東京の 2026-10-05（月曜）21:30
    private static let now = date(2026, 10, 5, 21, 30)

    private let center: FakeNotificationCenter
    private let container: ModelContainer
    private var context: ModelContext {
        container.mainContext
    }

    private var actions: NotificationSettingActions {
        NotificationSettingActions(scheduler: NotificationScheduler.fake(center))
    }

    init() throws {
        container = try NottiModelContainer.make(inMemory: true)
        center = FakeNotificationCenter()
    }

    // MARK: - 完了

    @Test
    func completeSavesRecordAndRegistersFromNextDay() async throws {
        let setting = insertDaily()
        await actions.sync(setting, now: Self.now)
        #expect(center.pending["\(setting.id.uuidString)-nag202610052200"] != nil)

        await actions.complete(setting, in: context, now: Self.now).value

        let records = try ModelContext(container).fetch(FetchDescriptor<CompletionRecord>())
        #expect(records.count == 1)
        #expect(records.first?.periodStart == Self.date(2026, 10, 5, 0, 0))
        #expect(records.first?.completedAt == Self.now)
        let keys = Set(center.pending.keys)
        #expect(!keys.contains { $0.hasPrefix("\(setting.id.uuidString)-nag20261005") })
        #expect(keys.contains("\(setting.id.uuidString)-nag202610062100"))
        #expect(keys.count == 6)
    }

    @Test
    func completeRemovesSnoozeAndDeliveredNotifications() async throws {
        let setting = insertDaily()
        let delivered = "\(setting.id.uuidString)-nag202610052100"
        let center = FakeNotificationCenter(delivered: [delivered, "other"])
        let actions = NotificationSettingActions(scheduler: NotificationScheduler.fake(center))
        await actions.sync(setting, now: Self.now)
        try await NotificationScheduler.fake(center).snooze(id: setting.id, message: setting.message)

        await actions.complete(setting, in: context, now: Self.now).value

        #expect(center.pending["\(setting.id.uuidString)-snooze"] == nil)
        #expect(center.delivered == ["other"])
    }

    @Test
    func completingTwiceKeepsOneRecord() async throws {
        let setting = insertDaily()

        await actions.complete(setting, in: context, now: Self.now).value
        await actions.complete(setting, in: context, now: Self.now.addingTimeInterval(600)).value

        #expect(setting.completions.count == 1)
    }

    @Test
    func completeBeforeDayBoundaryCompletesPreviousDay() async throws {
        let setting = insertDaily(rule: UntilDoneRule(interval: .oneHour, dayBoundary: Self.time(4, 0)))

        await actions.complete(setting, in: context, now: Self.date(2026, 10, 6, 1, 0)).value

        #expect(setting.completions.map(\.periodStart) == [Self.date(2026, 10, 5, 4, 0)])
    }

    @Test
    func completeWeeklyCompletesWeek() async throws {
        let setting = NotificationSetting(
            message: "ウィークリーミッション",
            kind: .timeOfDay,
            hour: 21,
            repeatRule: .weekdays,
            weekdays: [.monday],
            repeatsUntilDone: true,
            untilDoneRule: UntilDoneRule(interval: .oneHour)
        )
        context.insert(setting)

        await actions.complete(setting, in: context, now: Self.now).value

        #expect(setting.completions.map(\.periodStart) == [Self.date(2026, 10, 5, 0, 0)])
        #expect(center.pending.isEmpty)
    }

    @Test
    func completeDoesNothingForSettingNotRepeatingUntilDone() async throws {
        let setting = NotificationSetting(message: "デイリー", kind: .timeOfDay, hour: 21, repeatRule: .daily)
        context.insert(setting)
        await actions.sync(setting, now: Self.now)

        await actions.complete(setting, in: context, now: Self.now).value

        #expect(setting.completions.isEmpty)
        #expect(Set(center.pending.keys) == ["\(setting.id.uuidString)-daily"])
    }

    // MARK: - 取り消し

    @Test
    func undoCompletionRemovesRecordAndRegistersRestOfDay() async throws {
        let setting = insertDaily()
        await actions.complete(setting, in: context, now: Self.now).value

        await actions.undoCompletion(setting, in: context, now: Self.now).value

        #expect(setting.completions.isEmpty)
        #expect(try ModelContext(container).fetch(FetchDescriptor<CompletionRecord>()).isEmpty)
        #expect(center.pending["\(setting.id.uuidString)-nag202610052200"] != nil)
        #expect(center.pending.count == 2 + 3 + 3)
    }

    @Test
    func undoCompletionKeepsRecordsOfOtherPeriods() async throws {
        let setting = insertDaily()
        await actions.complete(setting, in: context, now: Self.now.addingTimeInterval(-86_400)).value

        await actions.undoCompletion(setting, in: context, now: Self.now).value

        #expect(setting.completions.map(\.periodStart) == [Self.date(2026, 10, 4, 0, 0)])
    }

    // MARK: - 補助

    private func insertDaily(rule: UntilDoneRule = UntilDoneRule(interval: .oneHour)) -> NotificationSetting {
        let setting = NotificationSetting(
            message: "デイリーミッション",
            kind: .timeOfDay,
            hour: 21,
            repeatRule: .daily,
            repeatsUntilDone: true,
            untilDoneRule: rule
        )
        context.insert(setting)
        return setting
    }

    /// 東京の year-month-day hour:minute
    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        NotificationScheduler.testCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private static func time(_ hour: Int, _ minute: Int) -> TimeOfDay {
        TimeOfDay(hour: hour, minute: minute)
    }
}
