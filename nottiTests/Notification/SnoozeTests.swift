//
//  SnoozeTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing
import UserNotifications

@MainActor
struct SnoozeTests {
    private let center = FakeNotificationCenter()
    /// 東京の 2026-10-05 12:00
    private let now = NotificationScheduler.testCalendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 12))!
    private let container: ModelContainer

    private var scheduler: NotificationScheduler {
        .fake(center)
    }

    private var context: ModelContext {
        container.mainContext
    }

    init() throws {
        container = try NottiModelContainer.make(inMemory: true)
    }

    @Test
    func registersSnoozeCategory() throws {
        scheduler.registerCategories()

        let category = try #require(center.categories.first { $0.identifier == NotificationScheduler.categoryIdentifier })
        #expect(center.categories.count == 2)
        #expect(category.actions.map(\.identifier) == [NotificationScheduler.snoozeActionIdentifier])
        #expect(category.actions.map(\.title) == ["10 分後にもう一度"])
    }

    @Test
    func scheduledNotificationsCarryCategoryAndSettingID() async throws {
        let setting = NotificationSetting(message: "デイリー", kind: .timeOfDay)
        try await scheduler.schedule(setting, now: now)

        let request = try #require(center.pending["\(setting.id.uuidString)-daily"])
        #expect(request.content.categoryIdentifier == NotificationScheduler.categoryIdentifier)
        #expect(request.content.userInfo[NotificationScheduler.settingIDKey] as? String == setting.id.uuidString)
    }

    @Test
    func snoozeActionSchedulesNotificationAfterTenMinutes() async throws {
        let id = UUID()
        let delegate = NotificationDelegate(scheduler: scheduler)

        await delegate.handle(actionIdentifier: NotificationScheduler.snoozeActionIdentifier, settingID: id.uuidString, message: "歩数")

        let request = try #require(center.pending["\(id.uuidString)-snooze"])
        #expect(request.content.body == "歩数")
        #expect(request.content.categoryIdentifier == NotificationScheduler.categoryIdentifier)
        let trigger = try #require(request.trigger as? UNTimeIntervalNotificationTrigger)
        #expect(trigger.timeInterval == 600)
        #expect(!trigger.repeats)
    }

    @Test
    func otherActionsDoNotSnooze() async {
        let delegate = NotificationDelegate(scheduler: scheduler)

        await delegate.handle(actionIdentifier: UNNotificationDefaultActionIdentifier, settingID: UUID().uuidString, message: "歩数")
        await delegate.handle(actionIdentifier: NotificationScheduler.snoozeActionIdentifier, settingID: nil, message: "歩数")

        #expect(center.pending.isEmpty)
    }

    @Test
    func reschedulingKeepsSnoozeButTurningOffRemovesIt() async throws {
        let setting = NotificationSetting(message: "デイリー", kind: .timeOfDay)
        context.insert(setting)
        let actions = NotificationSettingActions(scheduler: scheduler)
        await actions.sync(setting, now: now)
        try await scheduler.snooze(id: setting.id, message: setting.message)

        var draft = setting.draft
        draft.schedule.time = TimeOfDay(hour: 20, minute: 0)
        await actions.save(draft, to: setting, in: context, now: now).task.value
        #expect(Set(center.pending.keys) == ["\(setting.id.uuidString)-daily", "\(setting.id.uuidString)-snooze"])

        await actions.setEnabled(false, for: setting, now: now).value
        #expect(center.pending.isEmpty)
    }

    @Test
    func turningOffOrDeletingRemovesDeliveredNotificationsSoTheyCannotBeSnoozed() async {
        let setting = NotificationSetting(message: "デイリー", kind: .timeOfDay)
        let deleted = NotificationSetting(message: "削除", kind: .timeOfDay)
        let other = NotificationSetting(message: "そのまま", kind: .timeOfDay)
        context.insert(setting)
        context.insert(deleted)
        context.insert(other)
        let center = FakeNotificationCenter(delivered: [
            "\(setting.id.uuidString)-daily",
            "\(setting.id.uuidString)-snooze",
            "\(deleted.id.uuidString)-daily",
            "\(other.id.uuidString)-daily"
        ])
        let actions = NotificationSettingActions(scheduler: .fake(center))

        await actions.setEnabled(false, for: setting, now: now).value
        await actions.delete([deleted], from: context).value

        #expect(center.delivered == ["\(other.id.uuidString)-daily"])
    }

    @Test
    func reschedulingKeepsDeliveredNotifications() async throws {
        let setting = NotificationSetting(message: "デイリー", kind: .timeOfDay)
        let center = FakeNotificationCenter(delivered: ["\(setting.id.uuidString)-daily"])

        try await NotificationScheduler.fake(center).schedule(setting, now: now)

        #expect(center.delivered == ["\(setting.id.uuidString)-daily"])
    }

    @Test
    func reconcileKeepsSnoozeOfExistingSettingsOnly() async throws {
        let setting = NotificationSetting(message: "デイリー", kind: .timeOfDay)
        let off = NotificationSetting(message: "OFF", isEnabled: false, kind: .timeOfDay, repeatRule: .once)
        context.insert(setting)
        context.insert(off)
        await NotificationSettingActions(scheduler: scheduler).sync(setting, now: now)
        let deletedID = UUID()
        try await scheduler.snooze(id: setting.id, message: setting.message)
        try await scheduler.snooze(id: off.id, message: off.message)
        try await scheduler.snooze(id: deletedID, message: "削除済み")
        let removedBefore = center.removedIdentifiers.count

        await NotificationReconciler(scheduler: scheduler).reconcile(in: context, now: now)

        // 整合の取れた設定はスヌーズがあっても登録し直さない
        #expect(center.removedIdentifiers.count == removedBefore + 1)
        #expect(Set(center.pending.keys) == [
            "\(setting.id.uuidString)-daily",
            "\(setting.id.uuidString)-snooze",
            "\(off.id.uuidString)-snooze"
        ])
    }

    @Test
    func reconcileReregistersNotificationsWithoutCategory() async throws {
        let setting = NotificationSetting(message: "デイリー", kind: .timeOfDay)
        context.insert(setting)
        // スヌーズを付ける前のバージョンで登録した通知（カテゴリなし）
        let content = UNMutableNotificationContent()
        content.body = "デイリー"
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 9, minute: 0), repeats: true)
        try await center.add(UNNotificationRequest(identifier: "\(setting.id.uuidString)-daily", content: content, trigger: trigger))

        await NotificationReconciler(scheduler: scheduler).reconcile(in: context, now: now)

        let request = try #require(center.pending["\(setting.id.uuidString)-daily"])
        #expect(request.content.categoryIdentifier == NotificationScheduler.categoryIdentifier)
    }
}
