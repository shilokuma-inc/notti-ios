//
//  UntilDoneDraftTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing

@MainActor
struct UntilDoneDraftTests {
    /// 東京の 2026-10-05（月曜）12:00
    private static let now = NotificationScheduler.testCalendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 12))!
    private static let rule = UntilDoneRule(
        interval: .oneHour,
        dayBoundary: TimeOfDay(hour: 4, minute: 0),
        weekStart: WeekStart(weekday: .monday, time: TimeOfDay(hour: 5, minute: 0))
    )

    private let center = FakeNotificationCenter()
    private let container: ModelContainer

    private var actions: NotificationSettingActions {
        NotificationSettingActions(scheduler: NotificationScheduler.fake(center))
    }

    init() throws {
        container = try NottiModelContainer.make(inMemory: true)
    }

    // MARK: - 入力

    @Test
    func draftRoundTripsUntilDoneSettings() {
        let setting = NotificationSetting(message: "デイリー", kind: .timeOfDay, repeatsUntilDone: true, untilDoneRule: Self.rule)

        let draft = setting.draft
        #expect(draft.repeatsUntilDone)
        #expect(draft.untilDoneRule == Self.rule)

        let other = NotificationSetting(message: "別")
        other.apply(draft)
        #expect(other.repeatsUntilDone)
        #expect(other.untilDoneRule == Self.rule)
    }

    @Test
    func untilDoneIsAvailableOnlyForDailyAndWeekdays() {
        var draft = NotificationDraft(message: "デイリー")
        #expect(!draft.isUntilDoneAvailable)

        draft.kind = .timeOfDay
        #expect(draft.isUntilDoneAvailable)
        draft.schedule.repeatRule = .weekdays
        #expect(draft.isUntilDoneAvailable)
        draft.schedule.repeatRule = .once
        #expect(!draft.isUntilDoneAvailable)
    }

    @Test
    func weeklyUntilDoneNeedsExactlyOneWeekday() {
        var draft = NotificationDraft(message: "ウィークリー", kind: .timeOfDay, repeatsUntilDone: true)
        draft.schedule.repeatRule = .weekdays
        draft.schedule.weekdays = [.saturday, .sunday]
        #expect(draft.problem(now: Self.now, calendar: NotificationScheduler.testCalendar) == .multipleWeekdaysUntilDone)

        draft.schedule.weekdays = [.saturday]
        #expect(draft.problem(now: Self.now, calendar: NotificationScheduler.testCalendar) == nil)

        draft.repeatsUntilDone = false
        draft.schedule.weekdays = [.saturday, .sunday]
        #expect(draft.problem(now: Self.now, calendar: NotificationScheduler.testCalendar) == nil)
    }

    // MARK: - 保存

    @Test
    func savingNewUntilDoneSettingRegistersNags() async throws {
        let draft = NotificationDraft(
            message: "デイリーミッション",
            kind: .timeOfDay,
            schedule: TimeOfDaySchedule(time: TimeOfDay(hour: 21, minute: 0), repeatRule: .daily),
            repeatsUntilDone: true,
            untilDoneRule: Self.rule
        )

        let (setting, task) = actions.save(draft, to: nil, in: container.mainContext, now: Self.now)
        await task.value

        #expect(setting.repeatsUntilDone)
        #expect(setting.untilDoneRule == Self.rule)
        #expect(center.pending.count == 9)
        #expect(center.pending["\(setting.id.uuidString)-nag202610052100"] != nil)
    }

    @Test
    func turningOffReregistersDailyTriggerAndKeepsCompletions() async throws {
        var draft = NotificationDraft(
            message: "デイリーミッション",
            kind: .timeOfDay,
            schedule: TimeOfDaySchedule(time: TimeOfDay(hour: 21, minute: 0), repeatRule: .daily),
            repeatsUntilDone: true,
            untilDoneRule: Self.rule
        )
        let (setting, task) = actions.save(draft, to: nil, in: container.mainContext, now: Self.now)
        await task.value
        await actions.complete(setting, in: container.mainContext, now: Self.now).value

        draft.repeatsUntilDone = false
        await actions.save(draft, to: setting, in: container.mainContext, now: Self.now).task.value

        #expect(Set(center.pending.keys) == ["\(setting.id.uuidString)-daily"])
        #expect(setting.completions.count == 1)
    }

    @Test
    func changingIntervalReregistersNags() async throws {
        var draft = NotificationDraft(
            message: "デイリーミッション",
            kind: .timeOfDay,
            schedule: TimeOfDaySchedule(time: TimeOfDay(hour: 21, minute: 0), repeatRule: .daily),
            repeatsUntilDone: true,
            untilDoneRule: Self.rule
        )
        let (setting, task) = actions.save(draft, to: nil, in: container.mainContext, now: Self.now)
        await task.value

        draft.untilDoneRule.interval = .thirtyMinutes
        await actions.save(draft, to: setting, in: container.mainContext, now: Self.now).task.value

        #expect(setting.nagInterval == .thirtyMinutes)
        #expect(center.pending.count == 18)
    }
}
