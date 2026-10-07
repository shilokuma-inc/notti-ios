//
//  TimeOfDaySettingActionsTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing
import UserNotifications

@MainActor
struct TimeOfDaySettingActionsTests {
    private static let overnight = QuietHours(isEnabled: true, start: TimeOfDay(hour: 23, minute: 0), end: TimeOfDay(hour: 7, minute: 0))

    private let center = FakeNotificationCenter()
    /// 東京の 2026-10-05 12:00
    private let now = Self.date(2026, 10, 5, 12, 0)
    private let container: ModelContainer

    private var actions: NotificationSettingActions {
        NotificationSettingActions(scheduler: .fake(center, quietHours: Self.overnight))
    }

    private var context: ModelContext {
        container.mainContext
    }

    init() throws {
        container = try NottiModelContainer.make(inMemory: true)
    }

    // MARK: - 保存

    @Test
    func addingTimeOfDayDraftSavesFieldsAndSchedules() async throws {
        let onceDate = Self.date(2026, 10, 25, 9, 30)
        var draft = NotificationDraft(message: " デイリー\n", kind: .timeOfDay)
        draft.schedule = TimeOfDaySchedule(time: Self.time(21, 30), repeatRule: .weekdays, weekdays: [.monday, .friday], onceDate: onceDate)

        let result = actions.save(draft, to: nil, in: context, now: now)
        await result.task.value

        let setting = try #require(try context.fetch(FetchDescriptor<NotificationSetting>()).first)
        #expect(setting.id == result.setting.id)
        #expect(setting.message == "デイリー")
        #expect(setting.kind == .timeOfDay)
        #expect(setting.timeOfDay == Self.time(21, 30))
        #expect(setting.repeatRule == .weekdays)
        #expect(setting.weekdays == [.monday, .friday])
        #expect(setting.onceDate == onceDate)
        #expect(setting.isEnabled)
        #expect(setting.createdAt == now)
        #expect(Set(center.pending.keys) == ["\(setting.id.uuidString)-weekday2", "\(setting.id.uuidString)-weekday6"])
        #expect(center.pending.values.allSatisfy { $0.content.body == "デイリー" })
    }

    @Test
    func editingIntervalSettingToTimeOfDayReplacesNotifications() async {
        let setting = insert(NotificationSetting(message: "水を飲む", startDate: now.addingTimeInterval(-600)))
        await actions.sync(setting, now: now)
        #expect(center.pending.count == 16)

        var draft = setting.draft
        draft.kind = .timeOfDay
        draft.schedule = TimeOfDaySchedule(time: Self.time(8, 0), repeatRule: .daily)
        await actions.save(draft, to: setting, in: context, now: now).task.value

        #expect(setting.kind == .timeOfDay)
        #expect(Set(center.pending.keys) == ["\(setting.id.uuidString)-daily"])
    }

    @Test
    func editingTimeOfDaySettingWithoutChangesDoesNotReschedule() async {
        let setting = insert(Self.weekly(message: "歩数", weekdays: [.monday]))
        await actions.sync(setting, now: now)
        let removedBefore = center.removedIdentifiers.count

        await actions.save(setting.draft, to: setting, in: context, now: now).task.value

        #expect(center.removedIdentifiers.count == removedBefore)
        #expect(center.pending.count == 1)
    }

    @Test
    func editingWeekdaysReschedulesOnlySelectedWeekdays() async {
        let setting = insert(Self.weekly(message: "歩数", weekdays: [.monday, .tuesday]))
        await actions.sync(setting, now: now)

        var draft = setting.draft
        draft.schedule.weekdays = [.sunday]
        await actions.save(draft, to: setting, in: context, now: now).task.value

        #expect(setting.weekdays == [.sunday])
        #expect(Set(center.pending.keys) == ["\(setting.id.uuidString)-weekday1"])
    }

    @Test
    func savingIntervalOnlyKeepsTimeOfDayFields() async {
        let setting = insert(Self.weekly(message: "歩数", weekdays: [.monday]))

        await actions.save(message: "水を飲む", interval: .twentyFourHours, to: setting, in: context, now: now).task.value

        #expect(setting.kind == .interval)
        #expect(setting.interval == .twentyFourHours)
        #expect(setting.repeatRule == .weekdays)
        #expect(setting.weekdays == [.monday])
        #expect(Set(center.pending.keys) == [NotificationScheduler.identifier(for: setting.id, hour: 12)])
    }

    // MARK: - ON/OFF・削除・登録し直し・件数

    @Test
    func togglingTimeOfDaySettingRemovesAndRegistersAgain() async {
        let setting = insert(Self.daily(message: "デイリー"))
        await actions.sync(setting, now: now)

        await actions.setEnabled(false, for: setting, now: now).value
        #expect(center.pending.isEmpty)

        await actions.setEnabled(true, for: setting, now: now).value
        #expect(Set(center.pending.keys) == ["\(setting.id.uuidString)-daily"])
    }

    @Test
    func deletingTimeOfDaySettingRemovesAllWeekdays() async {
        let setting = insert(Self.weekly(message: "歩数", weekdays: Set(Weekday.allCases)))
        await actions.sync(setting, now: now)
        #expect(center.pending.count == 7)

        await actions.delete([setting], from: context).value

        #expect(center.pending.isEmpty)
    }

    @Test
    func rescheduleAllKeepsTimeOfDayAndReregisters() async {
        let start = now.addingTimeInterval(-600)
        let setting = insert(NotificationSetting(message: "デイリー", startDate: start, kind: .timeOfDay, hour: 23, minute: 30))

        await actions.rescheduleAll([setting], in: context, now: now).value

        #expect(setting.startDate == start)
        #expect(Set(center.pending.keys) == ["\(setting.id.uuidString)-daily"])
    }

    @Test
    func requestCountIncludesTimeOfDaySettings() {
        let settings = [
            NotificationSetting(message: "間隔", startDate: Self.date(2026, 10, 5, 14, 23)),
            Self.daily(message: "毎日"),
            Self.weekly(message: "曜日", weekdays: [.monday, .wednesday, .friday]),
            Self.once(message: "1 回", at: Self.date(2026, 10, 25, 9, 0)),
            Self.once(message: "過ぎた 1 回", at: Self.date(2026, 10, 1, 9, 0))
        ]

        #expect(actions.requestCount(for: settings, now: now) == 16 + 1 + 3 + 1)
    }

    // MARK: - 起動時の整合

    @Test
    func reconcileRegistersMissingTimeOfDayNotifications() async throws {
        let setting = insert(Self.weekly(message: "歩数", weekdays: [.monday, .friday]))

        await reconcile()

        #expect(Set(center.pending.keys) == ["\(setting.id.uuidString)-weekday2", "\(setting.id.uuidString)-weekday6"])
        let trigger = try #require(center.pending["\(setting.id.uuidString)-weekday2"]?.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents == DateComponents(hour: 9, minute: 0, weekday: 2))
    }

    @Test
    func reconcileKeepsMatchingTimeOfDayNotifications() async {
        let setting = insert(Self.once(message: "残高", at: Self.date(2026, 10, 25, 9, 0)))
        await actions.sync(setting, now: now)
        let removedBefore = center.removedIdentifiers.count

        await reconcile()

        #expect(center.removedIdentifiers.count == removedBefore)
        #expect(Set(center.pending.keys) == ["\(setting.id.uuidString)-once"])
    }

    @Test
    func reconcileReregistersChangedTimeAndRemovesUnselectedWeekdays() async throws {
        let setting = insert(Self.weekly(message: "歩数", weekdays: [.monday, .tuesday]))
        await actions.sync(setting, now: now)
        // 保存内容だけが変わり、登録が追従していない状態（別経路の変更やクラッシュ）
        setting.weekdays = [.monday]
        setting.timeOfDay = Self.time(7, 0)

        await reconcile()

        #expect(Set(center.pending.keys) == ["\(setting.id.uuidString)-weekday2"])
        let trigger = try #require(center.pending["\(setting.id.uuidString)-weekday2"]?.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.hour == 7)
    }

    @Test
    func reconcileDoesNotRegisterPastOnceNotification() async {
        insert(Self.once(message: "過ぎた", at: Self.date(2026, 10, 1, 9, 0)))

        await reconcile()

        #expect(center.pending.isEmpty)
    }

    @Test
    func reconcileRemovesDisabledTimeOfDayNotifications() async {
        let setting = insert(Self.daily(message: "デイリー"))
        await actions.sync(setting, now: now)
        setting.isEnabled = false

        await reconcile()

        #expect(center.pending.isEmpty)
    }

    // MARK: - ヘルパー

    private func reconcile() async {
        await NotificationReconciler(scheduler: .fake(center, quietHours: Self.overnight)).reconcile(in: context, now: now)
    }

    @discardableResult
    private func insert(_ setting: NotificationSetting) -> NotificationSetting {
        context.insert(setting)
        return setting
    }

    private static func daily(message: String) -> NotificationSetting {
        NotificationSetting(message: message, kind: .timeOfDay)
    }

    private static func weekly(message: String, weekdays: Set<Weekday>) -> NotificationSetting {
        NotificationSetting(message: message, kind: .timeOfDay, repeatRule: .weekdays, weekdays: weekdays)
    }

    private static func once(message: String, at date: Date) -> NotificationSetting {
        NotificationSetting(message: message, kind: .timeOfDay, repeatRule: .once, onceDate: date)
    }

    /// 東京の year-month-day hour:minute
    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        NotificationScheduler.testCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private static func time(_ hour: Int, _ minute: Int) -> TimeOfDay {
        TimeOfDay(hour: hour, minute: minute)
    }
}
