//
//  LinkOpenerTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing
import UserNotifications

@MainActor
struct LinkOpenerTests {
    private let container: ModelContainer

    init() throws {
        container = try NottiModelContainer.make(inMemory: true)
    }

    // MARK: - 開く処理

    @Test
    func openedLinkDoesNotShowFailure() async {
        let recorder = RecordingLinkOpener()

        let isOpened = await recorder.opener.open(URL(string: "https://example.com")!)

        #expect(isOpened)
        #expect(recorder.openedURLs == [URL(string: "https://example.com")!])
        #expect(!recorder.opener.isShowingFailure)
    }

    @Test
    func failureToOpenShowsFailure() async {
        let recorder = RecordingLinkOpener()
        recorder.result = false

        let isOpened = await recorder.opener.open(URL(string: "examplebank://")!)

        #expect(!isOpened)
        #expect(recorder.opener.isShowingFailure)
    }

    // MARK: - 一覧の行の「開く」ボタンを出すかどうか

    @Test
    func rowShowsOpenButtonOnlyForOpenableLink() {
        let linked = NotificationSetting(message: "残高", linkURL: "https://example.com")
        let custom = NotificationSetting(message: "ポイント", linkURL: "examplebank://")
        let plain = NotificationSetting(message: "水を飲む")
        // 画面からは保存できない形が残っていても、開けないのでボタンを出さない
        let unreadable = NotificationSetting(message: "壊れた URL", linkURL: "example.com")
        let unsafe = NotificationSetting(message: "危ない URL", linkURL: "javascript:alert(1)")

        #expect(linked.hasLink)
        #expect(linked.linkDestination == URL(string: "https://example.com"))
        #expect(custom.hasLink)
        #expect(!plain.hasLink)
        #expect(!unreadable.hasLink)
        #expect(!unsafe.hasLink)
    }

    @Test
    func disabledSettingStillHasLink() {
        let setting = NotificationSetting(message: "残高", isEnabled: false, linkURL: "https://example.com")

        #expect(setting.hasLink)
    }
}

/// #195 のレビューで抜けていた経路のカテゴリ
@MainActor
struct LinkCategoryCoverageTests {
    private let center = FakeNotificationCenter()
    private let container: ModelContainer

    init() throws {
        container = try NottiModelContainer.make(inMemory: true)
    }

    @Test
    func intervalWithQuietHoursCarriesLinkCategory() async throws {
        let quietHours = QuietHours(isEnabled: true, start: TimeOfDay(hour: 23, minute: 0), end: TimeOfDay(hour: 7, minute: 0))
        let scheduler = NotificationScheduler.fake(center, quietHours: quietHours)
        let setting = NotificationSetting(message: "水を飲む", intervalHours: 1, startDate: Self.now, linkURL: "https://example.com")
        container.mainContext.insert(setting)

        await NotificationSettingActions(scheduler: scheduler).sync(setting, now: Self.now)
        let plan = scheduler.plan(for: setting, now: Self.now)

        guard case .dailyTimes = plan else {
            Issue.record("おやすみ時間がある間隔の通知は時刻ごとに登録する")
            return
        }
        #expect(!center.pending.isEmpty)
        #expect(center.pending.values.allSatisfy { $0.content.categoryIdentifier == NotificationScheduler.linkCategoryIdentifier })
        let expected = NotificationScheduler.expectedNotifications(id: setting.id, message: setting.message, plan: plan, hasLink: true)
        #expect(await scheduler.pendingNotifications() == expected)
    }

    @Test
    func snoozeOfLinkedReminderKeepsLinkCategory() async throws {
        let id = UUID()
        let delegate = NotificationDelegate(scheduler: .fake(center), modelContainer: container)

        await delegate.handle(
            actionIdentifier: NotificationScheduler.snoozeActionIdentifier,
            settingID: id.uuidString,
            message: "残高",
            categoryIdentifier: NotificationScheduler.linkCategoryIdentifier
        )

        let request = try #require(center.pending["\(id.uuidString)-snooze"])
        #expect(request.content.categoryIdentifier == NotificationScheduler.linkCategoryIdentifier)
    }

    @Test
    func reconcileRetagsUntilDoneNagsWhenLinkChanges() async throws {
        let scheduler = NotificationScheduler.fake(center)
        let setting = NotificationSetting(
            message: "デイリーミッション",
            kind: .timeOfDay,
            hour: 21,
            repeatRule: .daily,
            repeatsUntilDone: true,
            untilDoneRule: UntilDoneRule(interval: .oneHour)
        )
        container.mainContext.insert(setting)
        await NotificationSettingActions(scheduler: scheduler).sync(setting, now: Self.now)
        let reconciler = NotificationReconciler(scheduler: scheduler)

        setting.linkURL = "examplebank://"
        await reconciler.reconcile(in: container.mainContext, now: Self.now)

        #expect(!center.pending.isEmpty)
        #expect(center.pending.values.allSatisfy { $0.content.categoryIdentifier == NotificationScheduler.untilDoneLinkCategoryIdentifier })

        setting.linkURL = nil
        await reconciler.reconcile(in: container.mainContext, now: Self.now)

        #expect(center.pending.values.allSatisfy { $0.content.categoryIdentifier == NotificationScheduler.untilDoneCategoryIdentifier })
    }

    /// 東京の 2026-10-05（月曜）12:00
    private static let now = NotificationScheduler.testCalendar.date(
        from: DateComponents(year: 2026, month: 10, day: 5, hour: 12, minute: 0)
    )!
}
