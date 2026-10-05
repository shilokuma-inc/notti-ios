//
//  QuietHoursSchedulingTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing
import UserNotifications

@MainActor
struct QuietHoursSchedulingTests {
    private static let overnight = QuietHours(
        isEnabled: true,
        start: TimeOfDay(hour: 23, minute: 0),
        end: TimeOfDay(hour: 7, minute: 0)
    )

    private let id = UUID()
    private let container: ModelContainer

    init() throws {
        container = try NottiModelContainer.make(inMemory: true)
    }

    // MARK: - 保存

    @Test
    func quietHoursRoundTripsThroughUserDefaults() throws {
        let suiteName = "QuietHoursSchedulingTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(QuietHours.load(from: defaults) == .default)
        #expect(!QuietHours.load(from: defaults).isEnabled)

        let quietHours = QuietHours(isEnabled: true, start: TimeOfDay(hour: 22, minute: 30), end: TimeOfDay(hour: 6, minute: 15))
        quietHours.save(to: defaults)

        #expect(QuietHours.load(from: defaults) == quietHours)
    }

    @Test(arguments: [(0, 0, 0), (90, 1, 30), (1439, 23, 59), (1440, 0, 0), (-60, 23, 0)])
    func timeOfDayFromMinutes(minutes: Int, hour: Int, minute: Int) {
        #expect(TimeOfDay(minutesSinceMidnight: minutes) == TimeOfDay(hour: hour, minute: minute))
    }

    // MARK: - 登録

    @Test
    func scheduleRegistersCalendarTriggerPerHourOutsideQuietHours() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center, quietHours: Self.overnight)

        let plan = try await scheduler.schedule(id: id, message: "水を飲む", interval: .oneHour, startDate: Self.date(14, 23))

        #expect(plan.requestCount == 16)
        let pending = center.pending
        #expect(Set(pending.keys) == Set((7...22).map { "\(id.uuidString)-\($0)" }))
        let request = try #require(pending["\(id.uuidString)-7"])
        #expect(request.content.body == "水を飲む")
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats)
        #expect(trigger.dateComponents.hour == 7)
        #expect(trigger.dateComponents.minute == 23)
    }

    @Test
    func schedulingWithoutQuietHoursReplacesDerivedRequests() async throws {
        let center = FakeNotificationCenter()
        try await NotificationScheduler.fake(center, quietHours: Self.overnight)
            .schedule(id: id, message: "水を飲む", interval: .oneHour, startDate: Self.date(14, 23))

        try await NotificationScheduler.fake(center)
            .schedule(id: id, message: "水を飲む", interval: .oneHour, startDate: Self.date(14, 23))

        #expect(Set(center.pending.keys) == [id.uuidString])
    }

    @Test
    func pendingNotificationsReadCalendarTrigger() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center, quietHours: Self.overnight)
        let plan = try await scheduler.schedule(id: id, message: "水を飲む", interval: .twentyFourHours, startDate: Self.date(14, 23))

        let pending = await scheduler.pendingNotifications()

        #expect(pending == NotificationScheduler.expectedNotifications(id: id, message: "水を飲む", plan: plan))
        #expect(pending["\(id.uuidString)-14"] == PendingNotification(body: "水を飲む", hour: 14, minute: 23, repeats: true))
    }

    // MARK: - 起動時の整合

    @Test
    func reconcileKeepsMatchingDailyTriggers() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center, quietHours: Self.overnight)
        let start = Self.date(14, 23)
        let setting = insert(NotificationSetting(message: "水を飲む", startDate: start))
        try await scheduler.schedule(id: setting.id, message: "水を飲む", interval: .oneHour, startDate: start)
        let removedBefore = center.removedIdentifiers.count

        await NotificationReconciler(scheduler: scheduler).reconcile(in: container.mainContext, now: Self.date(20, 0))

        #expect(center.removedIdentifiers.count == removedBefore)
        #expect(center.pending.count == 16)
        #expect(setting.startDate == start)
    }

    @Test
    func reconcileFixesDailyTriggersWithoutMovingStartDate() async throws {
        let start = Self.date(14, 23)
        let setting = insert(NotificationSetting(message: "水を飲む", startDate: start))
        let center = FakeNotificationCenter(pending: [
            Self.calendarRequest(identifier: "\(setting.id.uuidString)-3", hour: 3, minute: 23),
            Self.calendarRequest(identifier: "\(setting.id.uuidString)-14", hour: 14, minute: 23)
        ])
        let scheduler = NotificationScheduler.fake(center, quietHours: Self.overnight)

        await NotificationReconciler(scheduler: scheduler).reconcile(in: container.mainContext, now: Self.date(20, 0))

        #expect(Set(center.pending.keys) == Set((7...22).map { "\(setting.id.uuidString)-\($0)" }))
        #expect(setting.startDate == start)
    }

    // MARK: - おやすみ時間の変更

    @Test
    func rescheduleAllWithQuietHoursKeepsStartDate() async {
        let center = FakeNotificationCenter()
        let start = Self.date(14, 23)
        let enabled = insert(NotificationSetting(message: "水を飲む", startDate: start))
        let disabled = insert(NotificationSetting(message: "止めた", isEnabled: false, startDate: start))
        let actions = NotificationSettingActions(scheduler: .fake(center, quietHours: Self.overnight))

        await actions.rescheduleAll([enabled, disabled], in: container.mainContext, now: Self.date(20, 0)).value

        #expect(enabled.startDate == start)
        #expect(disabled.startDate == start)
        #expect(center.pending.count == 16)
        #expect(center.pending.keys.allSatisfy { $0.hasPrefix(enabled.id.uuidString) })
    }

    @Test
    func rescheduleAllWithoutQuietHoursRestartsFromNow() async throws {
        let center = FakeNotificationCenter(pending: [])
        let start = Self.date(14, 23)
        let now = Self.date(20, 0)
        let setting = insert(NotificationSetting(message: "水を飲む", startDate: start))
        try await NotificationScheduler.fake(center, quietHours: Self.overnight)
            .schedule(id: setting.id, message: "水を飲む", interval: .oneHour, startDate: start)
        let actions = NotificationSettingActions(scheduler: .fake(center))

        await actions.rescheduleAll([setting], in: container.mainContext, now: now).value

        #expect(setting.startDate == now)
        #expect(Set(center.pending.keys) == [setting.id.uuidString])
        #expect(!container.mainContext.hasChanges)
    }

    // MARK: - 上限と鳴らない通知

    @Test
    func requestCountCountsEnabledSettingsOnly() {
        let settings = [
            NotificationSetting(message: "1", startDate: Self.date(14, 23)),
            NotificationSetting(message: "2", startDate: Self.date(9, 0)),
            NotificationSetting(message: "3", intervalHours: 24, startDate: Self.date(9, 0)),
            NotificationSetting(message: "4", isEnabled: false, startDate: Self.date(9, 0))
        ]
        let actions = NotificationSettingActions(scheduler: .fake(FakeNotificationCenter(), quietHours: Self.overnight))

        #expect(actions.requestCount(for: settings) == 16 + 16 + 1)
        #expect(settings.requestCount(quietHours: Self.overnight, calendar: NotificationScheduler.testCalendar) == 33)
        #expect(settings.requestCount(quietHours: .default, calendar: NotificationScheduler.testCalendar) == 3)
    }

    @Test
    func fiveHourlySettingsExceedPendingLimit() {
        let settings = (0..<5).map { NotificationSetting(message: "\($0)", startDate: Self.date(9, 0)) }
        let count = settings.requestCount(quietHours: Self.overnight, calendar: NotificationScheduler.testCalendar)
        #expect(count == 80)
        #expect(count > NotificationScheduler.pendingLimit)
    }

    @Test
    func dailySettingStartingInQuietHoursIsSilent() {
        let calendar = NotificationScheduler.testCalendar
        let silent = NotificationSetting(message: "夜中", intervalHours: 24, startDate: Self.date(2, 0))
        let ringing = NotificationSetting(message: "昼", intervalHours: 24, startDate: Self.date(14, 0))
        let disabled = NotificationSetting(message: "止めた", intervalHours: 24, isEnabled: false, startDate: Self.date(2, 0))

        #expect(silent.isSilent(quietHours: Self.overnight, calendar: calendar))
        #expect(!ringing.isSilent(quietHours: Self.overnight, calendar: calendar))
        #expect(!disabled.isSilent(quietHours: Self.overnight, calendar: calendar))
        #expect(!silent.isSilent(quietHours: .default, calendar: calendar))
    }

    // MARK: - ヘルパー

    private func insert(_ setting: NotificationSetting) -> NotificationSetting {
        container.mainContext.insert(setting)
        return setting
    }

    /// 東京の 2026-10-05 hour:minute
    private static func date(_ hour: Int, _ minute: Int) -> Date {
        NotificationScheduler.testCalendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: hour, minute: minute))!
    }

    private static func calendarRequest(identifier: String, hour: Int, minute: Int) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.body = "水を飲む"
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: minute), repeats: true)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}
