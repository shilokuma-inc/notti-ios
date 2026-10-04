//
//  NotificationReconcilerTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing
import UserNotifications

@MainActor
struct NotificationReconcilerTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let start = Date(timeIntervalSince1970: 1_799_990_000)
    private let container: ModelContainer

    init() throws {
        container = try NottiModelContainer.make(inMemory: true)
    }

    @Test
    func schedulesEnabledSettingThatIsNotPending() async throws {
        let center = FakeNotificationCenter()
        let setting = insert(NotificationSetting(message: "水を飲む", intervalHours: 24, startDate: start))

        await reconcile(center)

        let request = try #require(center.pending[setting.id.uuidString])
        #expect(request.content.body == "水を飲む")
        let trigger = try #require(request.trigger as? UNTimeIntervalNotificationTrigger)
        #expect(trigger.timeInterval == 86_400)
        #expect(setting.startDate == now)
    }

    @Test
    func keepsMatchingPendingNotificationAsIs() async {
        let setting = insert(NotificationSetting(message: "水を飲む", startDate: start))
        let center = FakeNotificationCenter(pending: [
            Self.request(identifier: setting.id.uuidString, body: "水を飲む", interval: 3600)
        ])

        await reconcile(center)

        #expect(center.removedIdentifiers.isEmpty)
        #expect(center.pending.count == 1)
        #expect(setting.startDate == start)
    }

    @Test(arguments: [("古い文言", TimeInterval(3600)), ("水を飲む", TimeInterval(86_400))])
    func reschedulesMismatchedPendingNotification(body: String, interval: TimeInterval) async throws {
        let setting = insert(NotificationSetting(message: "水を飲む", startDate: start))
        let center = FakeNotificationCenter(pending: [
            Self.request(identifier: setting.id.uuidString, body: body, interval: interval)
        ])

        await reconcile(center)

        let request = try #require(center.pending[setting.id.uuidString])
        #expect(request.content.body == "水を飲む")
        let trigger = try #require(request.trigger as? UNTimeIntervalNotificationTrigger)
        #expect(trigger.timeInterval == 3600)
        #expect(setting.startDate == now)
    }

    @Test
    func removesNotificationsOfDisabledAndDeletedSettings() async {
        let enabled = insert(NotificationSetting(message: "残す", startDate: start))
        let disabled = insert(NotificationSetting(message: "止めた", isEnabled: false, startDate: start))
        let deletedID = UUID()
        let center = FakeNotificationCenter(pending: [
            Self.request(identifier: enabled.id.uuidString, body: "残す", interval: 3600),
            Self.request(identifier: disabled.id.uuidString, body: "止めた", interval: 3600),
            Self.request(identifier: deletedID.uuidString, body: "削除済み", interval: 3600),
            Self.request(identifier: "\(deletedID.uuidString)-9", body: "削除済み", interval: 3600)
        ])

        await reconcile(center)

        #expect(Set(center.pending.keys) == [enabled.id.uuidString])
        #expect(!disabled.isEnabled)
        #expect(disabled.startDate == start)
    }

    @Test
    func rescheduledStartDateIsSaved() async throws {
        let center = FakeNotificationCenter()
        let setting = insert(NotificationSetting(message: "水を飲む", startDate: start))
        try container.mainContext.save()

        await reconcile(center)

        #expect(!container.mainContext.hasChanges)
        #expect(setting.startDate == now)
    }

    private func reconcile(_ center: FakeNotificationCenter) async {
        await NotificationReconciler(scheduler: NotificationScheduler(center: center))
            .reconcile(in: container.mainContext, now: now)
    }

    private func insert(_ setting: NotificationSetting) -> NotificationSetting {
        container.mainContext.insert(setting)
        return setting
    }

    private static func request(identifier: String, body: String, interval: TimeInterval) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.body = body
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: true)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}
