//
//  NotificationSettingActionsTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing
import UserNotifications

@MainActor
struct NotificationSettingActionsTests {
    private let center = FakeNotificationCenter()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private var actions: NotificationSettingActions {
        NotificationSettingActions(scheduler: NotificationScheduler(center: center))
    }

    @Test
    func enablingSchedulesNotificationAndResetsStartDate() async throws {
        let setting = NotificationSetting(
            message: "水を飲む",
            intervalHours: 24,
            isEnabled: false,
            startDate: now.addingTimeInterval(-86_400)
        )

        await actions.setEnabled(true, for: setting, now: now).value

        #expect(setting.isEnabled)
        #expect(setting.startDate == now)
        let request = try #require(center.pending[setting.id.uuidString])
        #expect(request.content.body == "水を飲む")
        let trigger = try #require(request.trigger as? UNTimeIntervalNotificationTrigger)
        #expect(trigger.timeInterval == 86_400)
    }

    @Test
    func disablingRemovesNotificationAndKeepsStartDate() async {
        let setting = NotificationSetting(message: "水を飲む", startDate: now)
        await actions.sync(setting)
        #expect(center.pending.count == 1)

        await actions.setEnabled(false, for: setting, now: now.addingTimeInterval(60)).value

        #expect(!setting.isEnabled)
        #expect(setting.startDate == now)
        #expect(center.pending.isEmpty)
    }

    @Test
    func deleteRemovesSettingsAndNotifications() async throws {
        let container = try NottiModelContainer.make(inMemory: true)
        let context = container.mainContext
        let keep = NotificationSetting(message: "残す")
        let remove = NotificationSetting(message: "消す")
        context.insert(keep)
        context.insert(remove)
        try context.save()
        await actions.sync(keep)
        await actions.sync(remove)

        await actions.delete([remove], from: context).value

        let fetched = try context.fetch(FetchDescriptor<NotificationSetting>())
        #expect(fetched.map(\.id) == [keep.id])
        #expect(Set(center.pending.keys) == [keep.id.uuidString])
    }

    @Test(arguments: [(1, NotificationInterval.oneHour), (24, .twentyFourHours), (5, .oneHour)])
    func intervalFromStoredHours(hours: Int, expected: NotificationInterval) {
        let setting = NotificationSetting(message: "水を飲む", intervalHours: hours)
        #expect(setting.interval == expected)
    }

    @Test
    func settingIntervalUpdatesStoredHours() {
        let setting = NotificationSetting(message: "水を飲む")
        setting.interval = .twentyFourHours
        #expect(setting.intervalHours == 24)
    }

    @Test
    func intervalLabel() {
        #expect(NotificationInterval.oneHour.label == "1 時間ごと")
        #expect(NotificationInterval.twentyFourHours.label == "24 時間ごと")
    }
}
