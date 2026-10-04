//
//  NotificationSettingSaveTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing
import UserNotifications

@MainActor
struct NotificationSettingSaveTests {
    private let center = FakeNotificationCenter()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let container: ModelContainer

    private var actions: NotificationSettingActions {
        NotificationSettingActions(scheduler: NotificationScheduler(center: center))
    }

    init() throws {
        container = try NottiModelContainer.make(inMemory: true)
    }

    @Test
    func addingInsertsEnabledSettingAndSchedules() async throws {
        let context = container.mainContext

        let result = actions.save(message: "  水を飲む\n", interval: .twentyFourHours, to: nil, in: context, now: now)
        await result.task.value

        let fetched = try context.fetch(FetchDescriptor<NotificationSetting>())
        let setting = try #require(fetched.first)
        #expect(fetched.count == 1)
        #expect(setting.id == result.setting.id)
        #expect(setting.message == "水を飲む")
        #expect(setting.interval == .twentyFourHours)
        #expect(setting.isEnabled)
        #expect(setting.startDate == now)
        #expect(setting.createdAt == now)
        let request = try #require(center.pending[setting.id.uuidString])
        #expect(request.content.body == "水を飲む")
        let trigger = try #require(request.trigger as? UNTimeIntervalNotificationTrigger)
        #expect(trigger.timeInterval == 86_400)
    }

    @Test
    func editingEnabledSettingReschedulesAndResetsStartDate() async throws {
        let context = container.mainContext
        let setting = NotificationSetting(message: "古い文言", startDate: now.addingTimeInterval(-600))
        context.insert(setting)
        await actions.sync(setting)

        await actions.save(message: "新しい文言", interval: .twentyFourHours, to: setting, in: context, now: now).task.value

        #expect(setting.message == "新しい文言")
        #expect(setting.intervalHours == 24)
        #expect(setting.startDate == now)
        #expect(try context.fetchCount(FetchDescriptor<NotificationSetting>()) == 1)
        let pending = center.pending
        #expect(pending.count == 1)
        let request = try #require(pending[setting.id.uuidString])
        #expect(request.content.body == "新しい文言")
    }

    @Test
    func editingWithoutChangesKeepsStartDate() async {
        let context = container.mainContext
        let start = now.addingTimeInterval(-600)
        let setting = NotificationSetting(message: "水を飲む", startDate: start)
        context.insert(setting)

        await actions.save(message: "水を飲む", interval: .oneHour, to: setting, in: context, now: now).task.value

        #expect(setting.startDate == start)
    }

    @Test
    func editingDisabledSettingDoesNotSchedule() async {
        let context = container.mainContext
        let start = now.addingTimeInterval(-600)
        let setting = NotificationSetting(message: "古い文言", isEnabled: false, startDate: start)
        context.insert(setting)

        await actions.save(message: "新しい文言", interval: .oneHour, to: setting, in: context, now: now).task.value

        #expect(setting.message == "新しい文言")
        #expect(!setting.isEnabled)
        #expect(setting.startDate == start)
        #expect(center.pending.isEmpty)
    }
}
