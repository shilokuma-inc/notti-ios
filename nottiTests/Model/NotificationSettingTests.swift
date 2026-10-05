//
//  NotificationSettingTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing

@MainActor
struct NotificationSettingTests {
    @Test
    func initUsesDefaults() {
        let before = Date.now
        let setting = NotificationSetting(message: "水を飲む")
        let after = Date.now

        #expect(setting.message == "水を飲む")
        #expect(setting.intervalHours == 1)
        #expect(setting.isEnabled)
        #expect((before...after).contains(setting.startDate))
        #expect((before...after).contains(setting.createdAt))
    }

    @Test
    func insertedSettingsAreFetchedInCreatedOrder() throws {
        let container = try NottiModelContainer.make(inMemory: true)
        let context = container.mainContext
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let first = NotificationSetting(message: "1 件目", createdAt: base)
        let second = NotificationSetting(
            message: "2 件目",
            intervalHours: 24,
            isEnabled: false,
            startDate: base.addingTimeInterval(60),
            createdAt: base.addingTimeInterval(1)
        )
        context.insert(second)
        context.insert(first)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<NotificationSetting>(sortBy: [SortDescriptor(\.createdAt)]))

        #expect(fetched.map(\.id) == [first.id, second.id])
        #expect(fetched[1].message == "2 件目")
        #expect(fetched[1].intervalHours == 24)
        #expect(!fetched[1].isEnabled)
        #expect(fetched[1].startDate == base.addingTimeInterval(60))
    }

    @Test
    func updateAndDeleteArePersisted() throws {
        let container = try NottiModelContainer.make(inMemory: true)
        let context = container.mainContext
        let keep = NotificationSetting(message: "残す")
        let remove = NotificationSetting(message: "消す")
        context.insert(keep)
        context.insert(remove)
        try context.save()

        keep.message = "変更後"
        keep.isEnabled = false
        context.delete(remove)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<NotificationSetting>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.id == keep.id)
        #expect(fetched.first?.message == "変更後")
        #expect(fetched.first?.isEnabled == false)
    }
}
