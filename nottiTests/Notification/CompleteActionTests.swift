//
//  CompleteActionTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing
import UserNotifications

@MainActor
struct CompleteActionTests {
    private let center = FakeNotificationCenter()
    private let container: ModelContainer

    private var scheduler: NotificationScheduler {
        NotificationScheduler.fake(center)
    }

    private var actions: NotificationSettingActions {
        NotificationSettingActions(scheduler: scheduler)
    }

    init() throws {
        container = try NottiModelContainer.make(inMemory: true)
    }

    // MARK: - カテゴリ

    @Test
    func untilDoneCategoryHasCompleteAndSnoozeActions() throws {
        scheduler.registerCategories()

        let category = try #require(center.categories.first { $0.identifier == NotificationScheduler.untilDoneCategoryIdentifier })
        #expect(category.actions.map(\.identifier) == [
            NotificationScheduler.completeActionIdentifier,
            NotificationScheduler.snoozeActionIdentifier
        ])
        #expect(category.actions.map(\.title) == ["完了", "10 分後にもう一度"])
        // アプリを開かずに保存する
        #expect(!category.actions[0].options.contains(.foreground))
    }

    @Test
    func nagsCarryUntilDoneCategoryAndOtherNotificationsKeepReminderCategory() async throws {
        let nag = insertDaily()
        let plain = NotificationSetting(message: "毎日", kind: .timeOfDay, hour: 21, repeatRule: .daily)
        container.mainContext.insert(plain)

        await actions.sync(nag, now: Self.now)
        await actions.sync(plain, now: Self.now)

        let nagRequest = try #require(center.pending["\(nag.id.uuidString)-nag202610052100"])
        #expect(nagRequest.content.categoryIdentifier == NotificationScheduler.untilDoneCategoryIdentifier)
        #expect(center.pending["\(plain.id.uuidString)-daily"]?.content.categoryIdentifier == NotificationScheduler.categoryIdentifier)
    }

    @Test
    func reconcileReregistersNagsWithOldCategory() async throws {
        let setting = insertDaily()
        await actions.sync(setting, now: Self.now)
        // 「完了」のアクションを足す前に、ふだんのカテゴリで登録した催促
        let old = try #require(center.pending["\(setting.id.uuidString)-nag202610052100"])
        let content = try #require(old.content.mutableCopy() as? UNMutableNotificationContent)
        content.categoryIdentifier = NotificationScheduler.categoryIdentifier
        try await center.add(UNNotificationRequest(identifier: old.identifier, content: content, trigger: old.trigger))

        await NotificationReconciler(scheduler: scheduler).reconcile(in: container.mainContext, now: Self.now)

        #expect(center.pending.values.allSatisfy { $0.content.categoryIdentifier == NotificationScheduler.untilDoneCategoryIdentifier })
    }

    // MARK: - 完了のアクション

    @Test
    func completeActionSavesCompletionBeforeCallingCompletionHandler() async throws {
        let setting = insertDaily()
        try container.mainContext.save()
        await actions.sync(setting, now: Self.now)
        let delegate = NotificationDelegate(scheduler: scheduler, modelContainer: container)
        let deliveredAt = Self.date(2026, 10, 5, 21, 0)

        let pendingAtCompletion = await withCheckedContinuation { continuation in
            delegate.respond(
                actionIdentifier: NotificationScheduler.completeActionIdentifier,
                settingID: setting.id.uuidString,
                message: setting.message,
                categoryIdentifier: NotificationScheduler.untilDoneCategoryIdentifier,
                deliveredAt: deliveredAt
            ) { [center] in
                continuation.resume(returning: Set(center.pending.keys))
            }
        }

        #expect(setting.completions.map(\.periodStart) == [Self.date(2026, 10, 5, 0, 0)])
        #expect(!container.mainContext.hasChanges)
        #expect(!pendingAtCompletion.contains { $0.hasPrefix("\(setting.id.uuidString)-nag20261005") })
    }

    @Test
    func completeActionAfterMidnightCompletesDeliveredDay() async throws {
        let setting = insertDaily()
        let delegate = NotificationDelegate(scheduler: scheduler, modelContainer: container)

        // 23 時に届いた通知の「完了」を、日付が変わってから押した
        await delegate.handle(
            actionIdentifier: NotificationScheduler.completeActionIdentifier,
            settingID: setting.id.uuidString,
            message: setting.message,
            deliveredAt: Self.date(2026, 10, 5, 23, 0)
        )

        #expect(setting.completions.map(\.periodStart) == [Self.date(2026, 10, 5, 0, 0)])
    }

    @Test
    func completeActionForUnknownSettingDoesNothing() async throws {
        let delegate = NotificationDelegate(scheduler: scheduler, modelContainer: container)

        await delegate.handle(
            actionIdentifier: NotificationScheduler.completeActionIdentifier,
            settingID: UUID().uuidString,
            message: "削除済み"
        )

        #expect(try container.mainContext.fetch(FetchDescriptor<CompletionRecord>()).isEmpty)
    }

    @Test
    func snoozeOfNagKeepsUntilDoneCategory() async throws {
        let id = UUID()
        let delegate = NotificationDelegate(scheduler: scheduler, modelContainer: container)

        await delegate.handle(
            actionIdentifier: NotificationScheduler.snoozeActionIdentifier,
            settingID: id.uuidString,
            message: "デイリーミッション",
            categoryIdentifier: NotificationScheduler.untilDoneCategoryIdentifier
        )

        let request = try #require(center.pending["\(id.uuidString)-snooze"])
        #expect(request.content.categoryIdentifier == NotificationScheduler.untilDoneCategoryIdentifier)
    }

    // MARK: - 補助

    /// 東京の 2026-10-05（月曜）12:00
    private static let now = date(2026, 10, 5, 12, 0)

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

    /// 東京の year-month-day hour:minute
    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        NotificationScheduler.testCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
