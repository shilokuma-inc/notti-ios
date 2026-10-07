//
//  OnceCleanupTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing

@MainActor
struct OnceCleanupTests {
    private let center = FakeNotificationCenter()
    /// 東京の 2026-10-05 12:00
    private let now = Self.date(2026, 10, 5, 12, 0)
    private let container: ModelContainer

    private var actions: NotificationSettingActions {
        NotificationSettingActions(scheduler: .fake(center))
    }

    private var context: ModelContext {
        container.mainContext
    }

    init() throws {
        container = try NottiModelContainer.make(inMemory: true)
    }

    @Test
    func disablesOnlyExpiredEnabledOnceSettings() throws {
        let past = insert(Self.once(at: Self.date(2026, 10, 5, 12, 0)))
        let future = insert(Self.once(at: Self.date(2026, 10, 5, 12, 1)))
        let daily = insert(NotificationSetting(message: "毎日", kind: .timeOfDay, hour: 8))
        let interval = insert(NotificationSetting(message: "間隔", startDate: Self.date(2026, 10, 1, 9, 0)))

        let disabled = actions.disableExpiredOnce([past, future, daily, interval], in: context, now: now)

        #expect(disabled.map(\.id) == [past.id])
        #expect(!past.isEnabled)
        #expect(future.isEnabled)
        #expect(daily.isEnabled)
        #expect(interval.isEnabled)
        // 削除はしない（日時を変えて使い直せる）
        #expect(try context.fetchCount(FetchDescriptor<NotificationSetting>()) == 4)
    }

    @Test
    func nextOnceDateSkipsExpiredAndDisabled() {
        let soon = Self.date(2026, 10, 5, 18, 0)
        let disabled = Self.once(at: Self.date(2026, 10, 5, 13, 0))
        disabled.isEnabled = false
        let settings = [
            Self.once(at: Self.date(2026, 10, 5, 11, 0)),
            Self.once(at: Self.date(2026, 10, 25, 9, 0)),
            Self.once(at: soon),
            disabled
        ]

        #expect(actions.nextOnceDate(in: settings, now: now) == soon)
        #expect(actions.nextOnceDate(in: [], now: now) == nil)
    }

    @Test
    func cannotTurnOnExpiredOnceSetting() async {
        let past = insert(Self.once(at: Self.date(2026, 10, 5, 11, 0)))
        past.isEnabled = false
        let future = insert(Self.once(at: Self.date(2026, 10, 5, 13, 0)))
        future.isEnabled = false

        await actions.setEnabled(true, for: past, now: now).value
        await actions.setEnabled(true, for: future, now: now).value

        #expect(!past.isEnabled)
        #expect(future.isEnabled)
        #expect(Set(center.pending.keys) == ["\(future.id.uuidString)-once"])
    }

    @Test
    func reconcileDisablesExpiredOnceSetting() async {
        let setting = insert(Self.once(at: Self.date(2026, 10, 1, 9, 0)))

        await NotificationReconciler(scheduler: .fake(center)).reconcile(in: context, now: now)

        #expect(!setting.isEnabled)
        #expect(center.pending.isEmpty)
    }

    @discardableResult
    private func insert(_ setting: NotificationSetting) -> NotificationSetting {
        context.insert(setting)
        return setting
    }

    private static func once(at date: Date) -> NotificationSetting {
        NotificationSetting(message: "残高", kind: .timeOfDay, repeatRule: .once, onceDate: date)
    }

    /// 東京の year-month-day hour:minute
    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        NotificationScheduler.testCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
