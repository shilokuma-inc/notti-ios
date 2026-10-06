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
        #expect(setting.kind == .interval)
        #expect(setting.timeOfDay == TimeOfDay(hour: 9, minute: 0))
        #expect(setting.repeatRule == .daily)
        #expect(setting.weekdays.isEmpty)
        #expect(setting.onceDate == nil)
    }

    @Test
    func timeOfDaySettingIsPersisted() throws {
        let container = try NottiModelContainer.make(inMemory: true)
        let context = container.mainContext
        let onceDate = Date(timeIntervalSince1970: 1_800_000_000)
        let weekly = NotificationSetting(
            message: "デイリーミッション",
            kind: .timeOfDay,
            hour: 21,
            minute: 30,
            repeatRule: .weekdays,
            weekdays: [.monday, .friday]
        )
        let once = NotificationSetting(message: "残高を確認", kind: .timeOfDay, repeatRule: .once, onceDate: onceDate)
        context.insert(weekly)
        context.insert(once)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<NotificationSetting>())
        let fetchedWeekly = try #require(fetched.first { $0.id == weekly.id })
        let fetchedOnce = try #require(fetched.first { $0.id == once.id })

        #expect(fetchedWeekly.kind == .timeOfDay)
        #expect(fetchedWeekly.timeOfDay == TimeOfDay(hour: 21, minute: 30))
        #expect(fetchedWeekly.repeatRule == .weekdays)
        #expect(fetchedWeekly.weekdays == [.monday, .friday])
        #expect(fetchedOnce.repeatRule == .once)
        #expect(fetchedOnce.onceDate == onceDate)
    }

    @Test
    func accessorsUpdateStoredValues() {
        let setting = NotificationSetting(message: "水を飲む")

        setting.kind = .timeOfDay
        setting.repeatRule = .weekdays
        setting.weekdays = [.sunday, .saturday]
        setting.timeOfDay = TimeOfDay(hour: 7, minute: 15)

        #expect(setting.kindRawValue == "timeOfDay")
        #expect(setting.repeatRawValue == "weekdays")
        #expect(setting.weekdayMask == 0b100_0001)
        #expect(setting.hour == 7)
        #expect(setting.minute == 15)
    }

    @Test
    func unknownStoredValuesFallBackToDefaults() {
        let setting = NotificationSetting(message: "水を飲む")
        setting.kindRawValue = "unknown"
        setting.repeatRawValue = "monthly"
        setting.weekdayMask = 0b1000_0000

        #expect(setting.kind == .interval)
        #expect(setting.repeatRule == .daily)
        #expect(setting.weekdays.isEmpty)
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
