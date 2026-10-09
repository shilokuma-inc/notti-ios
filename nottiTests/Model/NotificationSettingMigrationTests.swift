//
//  NotificationSettingMigrationTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing

/// 時刻指定の項目を足す前の `NotificationSetting`（epic/notification でリリースした形）
enum LegacyNotificationSchema {
    @Model
    final class NotificationSetting {
        @Attribute(.unique) var id: UUID
        var message: String
        var intervalHours: Int
        var isEnabled: Bool
        var startDate: Date
        var createdAt: Date

        init(id: UUID, message: String, intervalHours: Int, isEnabled: Bool, startDate: Date, createdAt: Date) {
            self.id = id
            self.message = message
            self.intervalHours = intervalHours
            self.isEnabled = isEnabled
            self.startDate = startDate
            self.createdAt = createdAt
        }
    }
}

@MainActor
struct NotificationSettingMigrationTests {
    @Test
    func legacyStoreIsReadAsIntervalNotifications() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "default.store")
        let id = UUID()
        let startDate = Date(timeIntervalSince1970: 1_800_000_000)

        do {
            let schema = Schema([LegacyNotificationSchema.NotificationSetting.self])
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            container.mainContext.insert(
                LegacyNotificationSchema.NotificationSetting(
                    id: id,
                    message: "水を飲む",
                    intervalHours: 24,
                    isEnabled: true,
                    startDate: startDate,
                    createdAt: startDate
                )
            )
            try container.mainContext.save()
        }

        let schema = NottiModelContainer.schema
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        let fetched = try container.mainContext.fetch(FetchDescriptor<NotificationSetting>())

        let setting = try #require(fetched.first)
        #expect(fetched.count == 1)
        #expect(setting.id == id)
        #expect(setting.message == "水を飲む")
        #expect(setting.interval == .twentyFourHours)
        #expect(setting.isEnabled)
        #expect(setting.startDate == startDate)
        #expect(setting.kind == .interval)
        #expect(setting.repeatRule == .daily)
        #expect(setting.timeOfDay == TimeOfDay(hour: 9, minute: 0))
        #expect(setting.weekdays.isEmpty)
        #expect(setting.onceDate == nil)
        #expect(!setting.repeatsUntilDone)
        #expect(setting.untilDoneRule == UntilDoneRule())
        #expect(setting.completions.isEmpty)
    }
}
