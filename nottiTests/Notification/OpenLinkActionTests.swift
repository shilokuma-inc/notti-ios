//
//  OpenLinkActionTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing
import UserNotifications

/// 紐づけたアプリを開く URL を記録する。開けたかどうかは `result` で決める
@MainActor
final class RecordingLinkOpener {
    var openedURLs: [URL] = []
    var result = true

    lazy var opener = LinkOpener { [weak self] url in
        guard let self else {
            return false
        }
        openedURLs.append(url)
        return result
    }
}

@MainActor
struct OpenLinkActionTests {
    private let center = FakeNotificationCenter()
    private let container: ModelContainer
    private let recorder = RecordingLinkOpener()

    private var scheduler: NotificationScheduler {
        NotificationScheduler.fake(center)
    }

    private var actions: NotificationSettingActions {
        NotificationSettingActions(scheduler: scheduler)
    }

    private var delegate: NotificationDelegate {
        NotificationDelegate(scheduler: scheduler, modelContainer: container, linkOpener: recorder.opener)
    }

    init() throws {
        container = try NottiModelContainer.make(inMemory: true)
    }

    // MARK: - カテゴリ

    @Test
    func linkCategoryHasOpenLinkAndSnoozeActions() throws {
        scheduler.registerCategories()

        let category = try #require(center.categories.first { $0.identifier == NotificationScheduler.linkCategoryIdentifier })
        #expect(category.actions.map(\.identifier) == [
            NotificationScheduler.openLinkActionIdentifier,
            NotificationScheduler.snoozeActionIdentifier
        ])
        #expect(category.actions.map(\.title) == ["アプリを開く", "10 分後にもう一度"])
        // 通知から直接ほかのアプリは開けないので、いったんのっちを前面に出す
        #expect(category.actions[0].options.contains(.foreground))
    }

    @Test
    func untilDoneLinkCategoryHasCompleteOpenLinkAndSnoozeActions() throws {
        scheduler.registerCategories()

        let category = try #require(center.categories.first { $0.identifier == NotificationScheduler.untilDoneLinkCategoryIdentifier })
        #expect(category.actions.map(\.identifier) == [
            NotificationScheduler.completeActionIdentifier,
            NotificationScheduler.openLinkActionIdentifier,
            NotificationScheduler.snoozeActionIdentifier
        ])
        #expect(category.actions.map(\.title) == ["完了", "アプリを開く", "10 分後にもう一度"])
        // 「完了」はアプリを開かずに保存する。「アプリを開く」はのっちを前面に出す
        #expect(!category.actions[0].options.contains(.foreground))
        #expect(category.actions[1].options.contains(.foreground))
    }

    @Test
    func existingCategoriesAreUnchanged() throws {
        scheduler.registerCategories()

        #expect(Set(center.categories.map(\.identifier)) == [
            "notti.reminder",
            "notti.untilDone",
            "notti.reminder.link",
            "notti.untilDone.link"
        ])
        let reminder = try #require(center.categories.first { $0.identifier == "notti.reminder" })
        #expect(reminder.actions.map(\.identifier) == ["notti.snooze"])
        let untilDone = try #require(center.categories.first { $0.identifier == "notti.untilDone" })
        #expect(untilDone.actions.map(\.identifier) == ["notti.complete", "notti.snooze"])
        #expect(NotificationScheduler.openLinkActionIdentifier == "notti.openLink")
    }

    @Test
    func categoryDependsOnPlanAndLink() {
        let interval = NotificationTriggerPlan.repeatingInterval(3_600)
        let nag = NotificationTriggerPlan.untilDone([DateComponents(year: 2026, month: 10, day: 5, hour: 21, minute: 0)])

        #expect(NotificationScheduler.categoryIdentifier(for: interval) == NotificationScheduler.categoryIdentifier)
        #expect(NotificationScheduler.categoryIdentifier(for: interval, hasLink: true) == NotificationScheduler.linkCategoryIdentifier)
        #expect(NotificationScheduler.categoryIdentifier(for: nag) == NotificationScheduler.untilDoneCategoryIdentifier)
        #expect(NotificationScheduler.categoryIdentifier(for: nag, hasLink: true) == NotificationScheduler.untilDoneLinkCategoryIdentifier)
    }

    // MARK: - 登録

    @Test
    func linkedNotificationsCarryLinkCategories() async throws {
        let interval = insert(NotificationSetting(message: "間隔", startDate: Self.now, linkURL: "https://example.com"))
        let daily = insert(NotificationSetting(message: "毎日", kind: .timeOfDay, hour: 21, linkURL: "examplebank://"))
        let nag = insertDailyUntilDone(linkURL: "examplebank://")
        let plain = insert(NotificationSetting(message: "紐づけなし", kind: .timeOfDay, hour: 8))

        for setting in [interval, daily, nag, plain] {
            await actions.sync(setting, now: Self.now)
        }

        #expect(center.pending[interval.id.uuidString]?.content.categoryIdentifier == NotificationScheduler.linkCategoryIdentifier)
        #expect(center.pending["\(daily.id.uuidString)-daily"]?.content.categoryIdentifier == NotificationScheduler.linkCategoryIdentifier)
        let nagRequest = try #require(center.pending["\(nag.id.uuidString)-nag202610052100"])
        #expect(nagRequest.content.categoryIdentifier == NotificationScheduler.untilDoneLinkCategoryIdentifier)
        #expect(center.pending["\(plain.id.uuidString)-daily"]?.content.categoryIdentifier == NotificationScheduler.categoryIdentifier)
    }

    @Test
    func urlIsNotPutInUserInfo() async throws {
        let setting = insert(NotificationSetting(message: "残高", startDate: Self.now, linkURL: "https://example.com/secret"))

        await actions.sync(setting, now: Self.now)

        let request = try #require(center.pending[setting.id.uuidString])
        #expect(request.content.userInfo.keys.map { "\($0)" } == [NotificationScheduler.settingIDKey])
        #expect(!request.content.body.contains("example.com"))
    }

    @Test
    func addingLinkInEditReregistersWithLinkCategory() async throws {
        let setting = insert(NotificationSetting(message: "残高", kind: .timeOfDay, hour: 9))
        await actions.sync(setting, now: Self.now)
        var draft = setting.draft
        draft.linkURL = "https://example.com"

        await actions.save(draft, to: setting, in: container.mainContext, now: Self.now).task.value

        #expect(dailyCategory(of: setting) == NotificationScheduler.linkCategoryIdentifier)

        draft.linkURL = nil
        await actions.save(draft, to: setting, in: container.mainContext, now: Self.now).task.value

        #expect(dailyCategory(of: setting) == NotificationScheduler.categoryIdentifier)
    }

    @Test
    func reconcileReregistersWhenLinkCategoryDiffers() async throws {
        let setting = insert(NotificationSetting(message: "残高", kind: .timeOfDay, hour: 9))
        await actions.sync(setting, now: Self.now)
        // 紐づけを足したが、通知は前のカテゴリのまま
        setting.linkURL = "https://example.com"

        await NotificationReconciler(scheduler: scheduler).reconcile(in: container.mainContext, now: Self.now)

        #expect(dailyCategory(of: setting) == NotificationScheduler.linkCategoryIdentifier)

        setting.linkURL = nil
        await NotificationReconciler(scheduler: scheduler).reconcile(in: container.mainContext, now: Self.now)

        #expect(dailyCategory(of: setting) == NotificationScheduler.categoryIdentifier)
    }

    @Test
    func reconcileKeepsMatchingLinkedNotifications() async throws {
        let setting = insert(NotificationSetting(message: "残高", startDate: Self.now, linkURL: "https://example.com"))
        await actions.sync(setting, now: Self.now)
        let removedBefore = center.removedIdentifiers.count

        await NotificationReconciler(scheduler: scheduler).reconcile(in: container.mainContext, now: Self.now.addingTimeInterval(600))

        #expect(center.removedIdentifiers.count == removedBefore)
        #expect(setting.startDate == Self.now)
    }

    @Test
    func snoozeOfLinkedNotificationKeepsLinkCategory() async throws {
        let id = UUID()

        await delegate.handle(
            actionIdentifier: NotificationScheduler.snoozeActionIdentifier,
            settingID: id.uuidString,
            message: "残高",
            categoryIdentifier: NotificationScheduler.untilDoneLinkCategoryIdentifier
        )

        let request = try #require(center.pending["\(id.uuidString)-snooze"])
        #expect(request.content.categoryIdentifier == NotificationScheduler.untilDoneLinkCategoryIdentifier)
    }

    // MARK: - アプリを開くのアクション

    @Test
    func openLinkActionOpensLinkedURLBeforeCallingCompletionHandler() async throws {
        let setting = insert(NotificationSetting(message: "残高", linkURL: "examplebank://"))
        let delegate = delegate

        let openedAtCompletion = await withCheckedContinuation { continuation in
            delegate.respond(
                actionIdentifier: NotificationScheduler.openLinkActionIdentifier,
                settingID: setting.id.uuidString,
                message: setting.message,
                categoryIdentifier: NotificationScheduler.linkCategoryIdentifier
            ) { [recorder] in
                Task { @MainActor in
                    continuation.resume(returning: recorder.openedURLs)
                }
            }
        }

        #expect(openedAtCompletion == [URL(string: "examplebank://")!])
        #expect(!recorder.opener.isShowingFailure)
    }

    @Test
    func openLinkActionOpensURLChangedAfterDelivery() async throws {
        let setting = insert(NotificationSetting(message: "残高", linkURL: "https://example.com/old"))
        // 通知が届いた後に URL を変えた
        setting.linkURL = "https://example.com/new"

        await delegate.handle(
            actionIdentifier: NotificationScheduler.openLinkActionIdentifier,
            settingID: setting.id.uuidString,
            message: setting.message
        )

        #expect(recorder.openedURLs == [URL(string: "https://example.com/new")!])
    }

    @Test
    func openLinkActionForUnknownSettingOpensNothing() async {
        await delegate.handle(
            actionIdentifier: NotificationScheduler.openLinkActionIdentifier,
            settingID: UUID().uuidString,
            message: "削除済み"
        )

        #expect(recorder.openedURLs.isEmpty)
        #expect(!recorder.opener.isShowingFailure)
    }

    @Test
    func openLinkActionWithoutLinkOpensNothing() async {
        let setting = insert(NotificationSetting(message: "紐づけを外した"))

        await delegate.handle(
            actionIdentifier: NotificationScheduler.openLinkActionIdentifier,
            settingID: setting.id.uuidString,
            message: setting.message
        )

        #expect(recorder.openedURLs.isEmpty)
        #expect(!recorder.opener.isShowingFailure)
    }

    @Test
    func failureToOpenIsShown() async {
        let setting = insert(NotificationSetting(message: "残高", linkURL: "examplebank://"))
        recorder.result = false

        await delegate.handle(
            actionIdentifier: NotificationScheduler.openLinkActionIdentifier,
            settingID: setting.id.uuidString,
            message: setting.message
        )

        #expect(recorder.openedURLs == [URL(string: "examplebank://")!])
        #expect(recorder.opener.isShowingFailure)
    }

    @Test
    func tapDoesNotOpenLink() async {
        let setting = insert(NotificationSetting(message: "残高", linkURL: "examplebank://"))

        await delegate.handle(
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            settingID: setting.id.uuidString,
            message: setting.message,
            categoryIdentifier: NotificationScheduler.linkCategoryIdentifier
        )

        #expect(recorder.openedURLs.isEmpty)
    }

    // MARK: - 補助

    /// 東京の 2026-10-05（月曜）12:00
    private static let now = NotificationScheduler.testCalendar.date(
        from: DateComponents(year: 2026, month: 10, day: 5, hour: 12, minute: 0)
    )!

    /// 毎日の通知に付いたカテゴリ
    private func dailyCategory(of setting: NotificationSetting) -> String? {
        center.pending["\(setting.id.uuidString)-daily"]?.content.categoryIdentifier
    }

    private func insert(_ setting: NotificationSetting) -> NotificationSetting {
        container.mainContext.insert(setting)
        return setting
    }

    private func insertDailyUntilDone(linkURL: String) -> NotificationSetting {
        insert(
            NotificationSetting(
                message: "デイリーミッション",
                kind: .timeOfDay,
                hour: 21,
                repeatRule: .daily,
                repeatsUntilDone: true,
                untilDoneRule: UntilDoneRule(interval: .oneHour),
                linkURL: linkURL
            )
        )
    }
}
