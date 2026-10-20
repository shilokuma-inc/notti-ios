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

/// 毎月の項目を足す前の `NotificationSetting` と `CompletionRecord`（epic/required-reminders でリリースした形）
enum UntilDoneNotificationSchema {
    @Model
    final class NotificationSetting {
        @Attribute(.unique) var id: UUID
        var message: String
        var intervalHours: Int
        var isEnabled: Bool
        var startDate: Date
        var createdAt: Date
        var kindRawValue: String = "interval"
        var hour: Int = 9
        var minute: Int = 0
        var repeatRawValue: String = "daily"
        var weekdayMask: Int = 0
        var onceDate: Date?
        var repeatsUntilDone: Bool = false
        var nagIntervalMinutes: Int = 30
        var dayBoundaryHour: Int = 0
        var dayBoundaryMinute: Int = 0
        var weekStartWeekdayRawValue: Int = 2
        var weekStartHour: Int = 0
        var weekStartMinute: Int = 0
        @Relationship(deleteRule: .cascade, inverse: \CompletionRecord.setting)
        var completions: [CompletionRecord] = []

        init(
            message: String,
            hour: Int,
            minute: Int,
            repeatRawValue: String,
            weekdayMask: Int = 0,
            onceDate: Date? = nil,
            repeatsUntilDone: Bool = false
        ) {
            self.id = UUID()
            self.message = message
            self.intervalHours = 1
            self.isEnabled = true
            self.startDate = .now
            self.createdAt = .now
            self.kindRawValue = "timeOfDay"
            self.hour = hour
            self.minute = minute
            self.repeatRawValue = repeatRawValue
            self.weekdayMask = weekdayMask
            self.onceDate = onceDate
            self.repeatsUntilDone = repeatsUntilDone
        }
    }

    @Model
    final class CompletionRecord {
        var periodStart: Date
        var completedAt: Date
        var setting: NotificationSetting?

        init(periodStart: Date, completedAt: Date, setting: NotificationSetting?) {
            self.periodStart = periodStart
            self.completedAt = completedAt
            self.setting = setting
        }
    }
}

@MainActor
struct MonthlyMigrationTests {
    private static let onceDate = Date(timeIntervalSince1970: 1_800_000_000)
    private static let periodStart = Date(timeIntervalSince1970: 1_790_000_000)

    @Test
    func untilDoneStoreIsReadWithoutMonthlyFields() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "default.store")
        try writeUntilDoneStore(at: url)

        let schema = NottiModelContainer.schema
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        let fetched = try container.mainContext.fetch(FetchDescriptor<NotificationSetting>())

        #expect(fetched.count == 3)
        let daily = try #require(fetched.first { $0.message == "毎日" })
        let weekly = try #require(fetched.first { $0.message == "曜日" })
        let once = try #require(fetched.first { $0.message == "1 回" })

        #expect(daily.repeatRule == .daily)
        #expect(daily.timeOfDay == TimeOfDay(hour: 21, minute: 30))
        #expect(daily.repeatsUntilDone)
        #expect(daily.completions.map(\.periodStart) == [Self.periodStart])
        #expect(weekly.repeatRule == .weekdays)
        #expect(weekly.weekdays == [.monday, .friday])
        #expect(once.repeatRule == .once)
        #expect(once.onceDate == Self.onceDate)
        for setting in fetched {
            #expect(setting.kind == .timeOfDay)
            #expect(setting.monthDays.isEmpty)
            #expect(setting.monthEndOffset == nil)
        }
    }

    /// 毎月の項目を足す前の形で、毎日（完了の記録つき）・曜日・1 回だけの通知を保存する
    private func writeUntilDoneStore(at url: URL) throws {
        let schema = Schema([UntilDoneNotificationSchema.NotificationSetting.self, UntilDoneNotificationSchema.CompletionRecord.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        let context = container.mainContext
        let daily = UntilDoneNotificationSchema.NotificationSetting(
            message: "毎日",
            hour: 21,
            minute: 30,
            repeatRawValue: "daily",
            repeatsUntilDone: true
        )
        context.insert(daily)
        let record = UntilDoneNotificationSchema.CompletionRecord(
            periodStart: Self.periodStart,
            completedAt: Self.periodStart,
            setting: daily
        )
        context.insert(record)
        let weekly = UntilDoneNotificationSchema.NotificationSetting(
            message: "曜日",
            hour: 8,
            minute: 0,
            repeatRawValue: "weekdays",
            weekdayMask: 0b010_0010
        )
        context.insert(weekly)
        let once = UntilDoneNotificationSchema.NotificationSetting(
            message: "1 回",
            hour: 9,
            minute: 0,
            repeatRawValue: "once",
            onceDate: Self.onceDate
        )
        context.insert(once)
        try context.save()
    }
}

/// 開くアプリの URL を足す前の `NotificationSetting` と `CompletionRecord`（epic/monthly-repeat でリリースした形）
enum MonthlyNotificationSchema {
    @Model
    final class NotificationSetting {
        @Attribute(.unique) var id: UUID
        var message: String
        var intervalHours: Int
        var isEnabled: Bool
        var startDate: Date
        var createdAt: Date
        var kindRawValue: String = "interval"
        var hour: Int = 9
        var minute: Int = 0
        var repeatRawValue: String = "daily"
        var weekdayMask: Int = 0
        var onceDate: Date?
        var repeatsUntilDone: Bool = false
        var nagIntervalMinutes: Int = 30
        var dayBoundaryHour: Int = 0
        var dayBoundaryMinute: Int = 0
        var weekStartWeekdayRawValue: Int = 2
        var weekStartHour: Int = 0
        var weekStartMinute: Int = 0
        var monthDayMask: Int = 0
        var repeatsOnMonthEnd: Bool = false
        var monthEndOffsetDays: Int = 0
        @Relationship(deleteRule: .cascade, inverse: \CompletionRecord.setting)
        var completions: [CompletionRecord] = []

        init(message: String, kindRawValue: String, startDate: Date) {
            self.id = UUID()
            self.message = message
            self.intervalHours = 24
            self.isEnabled = true
            self.startDate = startDate
            self.createdAt = startDate
            self.kindRawValue = kindRawValue
        }
    }

    @Model
    final class CompletionRecord {
        var periodStart: Date
        var completedAt: Date
        var setting: NotificationSetting?

        init(periodStart: Date, completedAt: Date, setting: NotificationSetting?) {
            self.periodStart = periodStart
            self.completedAt = completedAt
            self.setting = setting
        }
    }
}

@MainActor
struct LinkURLMigrationTests {
    private static let startDate = Date(timeIntervalSince1970: 1_800_000_000)
    private static let periodStart = Date(timeIntervalSince1970: 1_790_000_000)

    @Test
    func monthlyStoreIsReadWithoutLink() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "default.store")
        try writeMonthlyStore(at: url)

        let schema = NottiModelContainer.schema
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        let fetched = try container.mainContext.fetch(FetchDescriptor<NotificationSetting>())

        #expect(fetched.count == 2)
        let interval = try #require(fetched.first { $0.message == "間隔" })
        let monthly = try #require(fetched.first { $0.message == "毎月" })

        #expect(interval.kind == .interval)
        #expect(interval.interval == .twentyFourHours)
        #expect(interval.startDate == Self.startDate)
        #expect(monthly.kind == .timeOfDay)
        #expect(monthly.repeatRule == .monthly)
        #expect(monthly.monthDays == [25])
        #expect(monthly.monthEndOffset == 2)
        #expect(monthly.repeatsUntilDone)
        #expect(monthly.completions.map(\.periodStart) == [Self.periodStart])
        for setting in fetched {
            #expect(setting.linkURL == nil)
            #expect(setting.draft.linkURL == nil)
        }
    }

    /// 開くアプリの URL を足す前の形で、間隔の通知と、毎月の完了するまで繰り返す通知（完了の記録つき）を保存する
    private func writeMonthlyStore(at url: URL) throws {
        let schema = Schema([MonthlyNotificationSchema.NotificationSetting.self, MonthlyNotificationSchema.CompletionRecord.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        let context = container.mainContext
        context.insert(MonthlyNotificationSchema.NotificationSetting(message: "間隔", kindRawValue: "interval", startDate: Self.startDate))
        let monthly = MonthlyNotificationSchema.NotificationSetting(message: "毎月", kindRawValue: "timeOfDay", startDate: Self.startDate)
        monthly.repeatRawValue = "monthly"
        monthly.monthDayMask = MonthDay.mask(of: [25])
        monthly.repeatsOnMonthEnd = true
        monthly.monthEndOffsetDays = 2
        monthly.repeatsUntilDone = true
        context.insert(monthly)
        context.insert(
            MonthlyNotificationSchema.CompletionRecord(periodStart: Self.periodStart, completedAt: Self.periodStart, setting: monthly)
        )
        try context.save()
    }
}

/// 開いた日時を足す前の `NotificationSetting` と `CompletionRecord`（epic/open-linked-app のタスク 1 で足した `linkURL` まで入った形）
enum LinkURLNotificationSchema {
    @Model
    final class NotificationSetting {
        @Attribute(.unique) var id: UUID
        var message: String
        var intervalHours: Int
        var isEnabled: Bool
        var startDate: Date
        var createdAt: Date
        var kindRawValue: String = "interval"
        var hour: Int = 9
        var minute: Int = 0
        var repeatRawValue: String = "daily"
        var weekdayMask: Int = 0
        var onceDate: Date?
        var repeatsUntilDone: Bool = false
        var nagIntervalMinutes: Int = 30
        var dayBoundaryHour: Int = 0
        var dayBoundaryMinute: Int = 0
        var weekStartWeekdayRawValue: Int = 2
        var weekStartHour: Int = 0
        var weekStartMinute: Int = 0
        var monthDayMask: Int = 0
        var repeatsOnMonthEnd: Bool = false
        var monthEndOffsetDays: Int = 0
        var linkURL: String?
        @Relationship(deleteRule: .cascade, inverse: \CompletionRecord.setting)
        var completions: [CompletionRecord] = []

        init(message: String, linkURL: String?) {
            self.id = UUID()
            self.message = message
            self.intervalHours = 1
            self.isEnabled = true
            self.startDate = Date(timeIntervalSince1970: 1_800_000_000)
            self.createdAt = Date(timeIntervalSince1970: 1_800_000_000)
            self.kindRawValue = "timeOfDay"
            self.hour = 21
            self.repeatsUntilDone = true
            self.linkURL = linkURL
        }
    }

    @Model
    final class CompletionRecord {
        var periodStart: Date
        var completedAt: Date
        var setting: NotificationSetting?

        init(periodStart: Date, completedAt: Date, setting: NotificationSetting?) {
            self.periodStart = periodStart
            self.completedAt = completedAt
            self.setting = setting
        }
    }
}

@MainActor
struct LinkOpenedAtMigrationTests {
    @Test
    func linkURLStoreIsReadWithoutOpenedAt() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "default.store")
        do {
            let schema = Schema([LinkURLNotificationSchema.NotificationSetting.self, LinkURLNotificationSchema.CompletionRecord.self])
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            container.mainContext.insert(LinkURLNotificationSchema.NotificationSetting(message: "紐づけあり", linkURL: "examplebank://"))
            container.mainContext.insert(LinkURLNotificationSchema.NotificationSetting(message: "紐づけなし", linkURL: nil))
            try container.mainContext.save()
        }

        let schema = NottiModelContainer.schema
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        let fetched = try container.mainContext.fetch(FetchDescriptor<NotificationSetting>())

        #expect(fetched.count == 2)
        let linked = try #require(fetched.first { $0.message == "紐づけあり" })
        let plain = try #require(fetched.first { $0.message == "紐づけなし" })
        #expect(linked.linkURL == "examplebank://")
        #expect(linked.repeatsUntilDone)
        #expect(plain.linkURL == nil)
        for setting in fetched {
            #expect(setting.linkOpenedAt == nil)
        }
    }
}
