//
//  UntilDoneReconcilerTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing
import UserNotifications

@MainActor
struct UntilDoneReconcilerTests {
    /// 東京の 2026-10-05（月曜）12:00
    private static let now = date(2026, 10, 5, 12, 0)

    private let container: ModelContainer

    init() throws {
        container = try NottiModelContainer.make(inMemory: true)
    }

    @Test
    func refillsNagsForComingDays() async throws {
        let setting = insertDaily()
        // 2 日前に登録した催促のうち、まだ鳴っていない今日の分だけが残っている
        let center = FakeNotificationCenter(pending: [
            Self.request(id: setting.id, at: Self.date(2026, 10, 5, 21, 0)),
            Self.request(id: setting.id, at: Self.date(2026, 10, 5, 22, 0)),
            Self.request(id: setting.id, at: Self.date(2026, 10, 5, 23, 0))
        ])

        await reconcile(center)

        #expect(center.pending.count == 9)
        #expect(center.pending["\(setting.id.uuidString)-nag202610072300"] != nil)
    }

    @Test
    func keepsMatchingNagsAsIs() async throws {
        let setting = insertDaily()
        let center = FakeNotificationCenter()
        await NotificationSettingActions(scheduler: NotificationScheduler.fake(center)).sync(setting, now: Self.now)

        await reconcile(center)

        #expect(center.removedIdentifiers.count == 1)
        #expect(center.pending.count == 9)
    }

    @Test
    func removesNagsOfCompletedPeriod() async throws {
        let setting = insertDaily()
        let center = FakeNotificationCenter()
        await NotificationSettingActions(scheduler: NotificationScheduler.fake(center)).sync(setting, now: Self.now)
        // 別の経路（通知のアクションなど）で完了の記録だけが保存された
        container.mainContext.insert(CompletionRecord(periodStart: Self.date(2026, 10, 5, 0, 0), completedAt: Self.now, setting: setting))

        await reconcile(center)

        let keys = Set(center.pending.keys)
        #expect(!keys.contains { $0.hasPrefix("\(setting.id.uuidString)-nag20261005") })
        #expect(keys.count == 6)
    }

    @Test
    func replacesDailyTriggerRegisteredBeforeTurningOn() async throws {
        let setting = insertDaily()
        let center = FakeNotificationCenter()
        setting.repeatsUntilDone = false
        await NotificationSettingActions(scheduler: NotificationScheduler.fake(center)).sync(setting, now: Self.now)
        setting.repeatsUntilDone = true

        await reconcile(center)

        let keys = Set(center.pending.keys)
        #expect(!keys.contains("\(setting.id.uuidString)-daily"))
        #expect(keys.count == 9)
    }

    @Test
    func removesNagsOfDisabledSetting() async throws {
        let setting = insertDaily()
        let center = FakeNotificationCenter()
        await NotificationSettingActions(scheduler: NotificationScheduler.fake(center)).sync(setting, now: Self.now)
        setting.isEnabled = false

        await reconcile(center)

        #expect(center.pending.isEmpty)
    }

    // MARK: - 補助

    private func reconcile(_ center: FakeNotificationCenter) async {
        await NotificationReconciler(scheduler: NotificationScheduler.fake(center))
            .reconcile(in: container.mainContext, now: Self.now)
    }

    private func insertDaily() -> NotificationSetting {
        let setting = NotificationSetting(
            message: "デイリーミッション",
            kind: .timeOfDay,
            hour: 21,
            repeatRule: .daily,
            repeatsUntilDone: true,
            untilDoneRule: UntilDoneRule(interval: .oneHour)
        )
        container.mainContext.insert(setting)
        return setting
    }

    /// `date` に鳴らす催促の通知
    private static func request(id: UUID, at date: Date) -> UNNotificationRequest {
        let components = NotificationScheduler.testCalendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let content = UNMutableNotificationContent()
        content.body = "デイリーミッション"
        content.categoryIdentifier = NotificationScheduler.categoryIdentifier
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = NotificationScheduler.identifier(for: id, nagAt: components)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    /// 東京の year-month-day hour:minute
    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        NotificationScheduler.testCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
