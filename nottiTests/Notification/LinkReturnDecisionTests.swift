//
//  LinkReturnDecisionTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import SwiftData
import Testing

/// 紐づけたアプリから戻ったときに、済んだかを聞くかどうか（東京の固定の日時で確かめる）
@MainActor
struct LinkReturnDecisionTests {
    private let calendar = NotificationScheduler.testCalendar
    private let container: ModelContainer

    init() throws {
        container = try NottiModelContainer.make(inMemory: true)
    }

    // MARK: - 戻ったかどうか

    @Test
    func notOpenedIsNotAsked() {
        let setting = daily()

        #expect(decision(setting, backgroundedAt: date(10, 5, 12, 0), now: date(10, 5, 12, 5)) == .notReturned)
    }

    @Test
    func notAskedBeforeGoingToBackground() {
        let setting = daily(openedAt: date(10, 5, 12, 0))

        // 通知のアクションでのっちが前面に出たとき（開く前にバックグラウンドに回ったのが最後）
        #expect(decision(setting, backgroundedAt: date(10, 5, 11, 0), now: date(10, 5, 12, 0)) == .notReturned)
    }

    @Test
    func openedAtSameTimeAsBackgroundIsAsked() {
        let setting = daily(openedAt: date(10, 5, 12, 0))

        let result = decision(setting, backgroundedAt: date(10, 5, 12, 0), now: date(10, 5, 12, 10))

        #expect(result == .ask(period: CompletionPeriod(start: date(10, 5, 0, 0), end: date(10, 6, 0, 0))))
    }

    @Test
    func askedAfterReturningFromBackground() {
        let setting = daily(openedAt: date(10, 5, 12, 0))

        let result = decision(setting, backgroundedAt: date(10, 5, 12, 0, 1), now: date(10, 5, 12, 10))

        #expect(result == .ask(period: CompletionPeriod(start: date(10, 5, 0, 0), end: date(10, 6, 0, 0))))
    }

    // MARK: - 日・週・月の期間

    @Test
    func dailyIsDiscardedAfterDayBoundary() {
        let setting = daily(openedAt: date(10, 5, 23, 50))

        let period = CompletionPeriod(start: date(10, 5, 0, 0), end: date(10, 6, 0, 0))
        #expect(decision(setting, backgroundedAt: date(10, 5, 23, 51), now: date(10, 5, 23, 59)) == .ask(period: period))
        #expect(decision(setting, backgroundedAt: date(10, 5, 23, 51), now: date(10, 6, 0, 0)) == .discard)
    }

    @Test
    func dailyUsesDayBoundary() {
        // 日の区切りが 4 時なら、深夜 1 時に開いて 3 時に戻っても前の日の期間のまま
        let setting = daily(openedAt: date(10, 6, 1, 0), rule: UntilDoneRule(dayBoundary: TimeOfDay(hour: 4, minute: 0)))

        let result = decision(setting, backgroundedAt: date(10, 6, 1, 1), now: date(10, 6, 3, 0))

        #expect(result == .ask(period: CompletionPeriod(start: date(10, 5, 4, 0), end: date(10, 6, 4, 0))))
        #expect(decision(setting, backgroundedAt: date(10, 6, 1, 1), now: date(10, 6, 4, 0)) == .discard)
    }

    @Test
    func weeklyIsAskedWithinWeekAndDiscardedAfterWeekStart() {
        // 2026-10-05 は月曜。週の始まりは既定で月曜 0 時
        let setting = insert(
            NotificationSetting(
                message: "週のミッション",
                kind: .timeOfDay,
                hour: 9,
                repeatRule: .weekdays,
                weekdays: [.monday],
                repeatsUntilDone: true
            )
        )
        setting.linkOpenedAt = date(10, 7, 9, 0)

        let result = decision(setting, backgroundedAt: date(10, 7, 9, 1), now: date(10, 11, 23, 0))

        #expect(result == .ask(period: CompletionPeriod(start: date(10, 5, 0, 0), end: date(10, 12, 0, 0))))
        #expect(decision(setting, backgroundedAt: date(10, 7, 9, 1), now: date(10, 12, 0, 0)) == .discard)
    }

    @Test
    func monthlyIsAskedWithinMonthAndDiscardedNextMonth() {
        let setting = insert(
            NotificationSetting(
                message: "家賃",
                kind: .timeOfDay,
                hour: 9,
                repeatRule: .monthly,
                monthDays: [25],
                repeatsUntilDone: true
            )
        )
        setting.linkOpenedAt = date(10, 25, 9, 0)

        let result = decision(setting, backgroundedAt: date(10, 25, 9, 1), now: date(10, 31, 23, 0))

        #expect(result == .ask(period: CompletionPeriod(start: date(10, 1, 0, 0), end: date(11, 1, 0, 0))))
        #expect(decision(setting, backgroundedAt: date(10, 25, 9, 1), now: date(11, 1, 0, 0)) == .discard)
    }

    // MARK: - 聞かずに消す

    @Test
    func completedPeriodIsDiscarded() {
        let setting = daily(openedAt: date(10, 5, 12, 0))
        // 通知の「完了」で済ませた
        container.mainContext.insert(CompletionRecord(periodStart: date(10, 5, 0, 0), completedAt: date(10, 5, 12, 3), setting: setting))

        #expect(decision(setting, backgroundedAt: date(10, 5, 12, 1), now: date(10, 5, 12, 10)) == .discard)
    }

    @Test
    func disabledSettingIsDiscarded() {
        let setting = daily(openedAt: date(10, 5, 12, 0))
        setting.isEnabled = false

        #expect(decision(setting, backgroundedAt: date(10, 5, 12, 1), now: date(10, 5, 12, 10)) == .discard)
    }

    @Test
    func settingNoLongerUntilDoneIsDiscarded() {
        let setting = daily(openedAt: date(10, 5, 12, 0))
        setting.repeatsUntilDone = false

        #expect(decision(setting, backgroundedAt: date(10, 5, 12, 1), now: date(10, 5, 12, 10)) == .discard)
    }

    // MARK: - 補助

    private func decision(_ setting: NotificationSetting, backgroundedAt: Date, now: Date) -> LinkReturnDecision {
        setting.linkReturnDecision(backgroundedAt: backgroundedAt, now: now, calendar: calendar)
    }

    private func daily(openedAt: Date? = nil, rule: UntilDoneRule = UntilDoneRule()) -> NotificationSetting {
        let setting = insert(
            NotificationSetting(
                message: "デイリーミッション",
                kind: .timeOfDay,
                hour: 21,
                repeatRule: .daily,
                repeatsUntilDone: true,
                untilDoneRule: rule,
                linkURL: "examplebank://"
            )
        )
        setting.linkOpenedAt = openedAt
        return setting
    }

    private func insert(_ setting: NotificationSetting) -> NotificationSetting {
        container.mainContext.insert(setting)
        return setting
    }

    /// 東京の 2026 年 month-day hour:minute:second
    private func date(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute, second: second))!
    }
}

/// 開いた日時の保存と、戻ったときの確認の結果
@MainActor
struct LinkReturnActionsTests {
    private let center = FakeNotificationCenter()
    private let container: ModelContainer
    private let recorder = RecordingLinkOpener()

    private var actions: NotificationSettingActions {
        NotificationSettingActions(scheduler: NotificationScheduler.fake(center))
    }

    init() throws {
        container = try NottiModelContainer.make(inMemory: true)
    }

    @Test
    func openingUntilDoneLinkRecordsOpenedAt() async {
        let setting = insert(untilDone: true)

        let isOpened = await actions.openLink(of: setting, with: recorder.opener, in: container.mainContext, now: Self.now)

        #expect(isOpened)
        #expect(recorder.openedURLs == [URL(string: "examplebank://")!])
        #expect(setting.linkOpenedAt == Self.now)
        #expect(!container.mainContext.hasChanges)
    }

    @Test
    func openingLinkWithoutCompletionDoesNotRecord() async {
        let setting = insert(untilDone: false)

        await actions.openLink(of: setting, with: recorder.opener, in: container.mainContext, now: Self.now)

        #expect(recorder.openedURLs == [URL(string: "examplebank://")!])
        #expect(setting.linkOpenedAt == nil)
    }

    @Test
    func failureToOpenClearsOpenedAt() async {
        let setting = insert(untilDone: true)
        recorder.result = false

        let isOpened = await actions.openLink(of: setting, with: recorder.opener, in: container.mainContext, now: Self.now)

        #expect(!isOpened)
        #expect(setting.linkOpenedAt == nil)
        #expect(recorder.opener.isShowingFailure)
    }

    @Test
    func settingWithoutLinkOpensNothing() async {
        let setting = insert(untilDone: true)
        setting.linkURL = nil

        let isOpened = await actions.openLink(of: setting, with: recorder.opener, in: container.mainContext, now: Self.now)

        #expect(!isOpened)
        #expect(recorder.openedURLs.isEmpty)
        #expect(setting.linkOpenedAt == nil)
    }

    @Test
    func completingReturnCompletesPeriodContainingOpenedAt() async {
        let setting = insert(untilDone: true)
        // 23:50 に開いて、日付が変わってから「完了にする」を選んだ
        setting.linkOpenedAt = Self.date(10, 5, 23, 50)

        await actions.completeLinkReturn(setting, in: container.mainContext, now: Self.date(10, 6, 0, 5)).value

        #expect(setting.completions.map(\.periodStart) == [Self.date(10, 5, 0, 0)])
        #expect(setting.linkOpenedAt == nil)
        #expect(!container.mainContext.hasChanges)
    }

    @Test
    func completingReturnWithoutOpenedAtDoesNothing() async {
        let setting = insert(untilDone: true)

        await actions.completeLinkReturn(setting, in: container.mainContext, now: Self.now).value

        #expect(setting.completions.isEmpty)
    }

    @Test
    func completingReturnOfCompletedPeriodClearsOpenedAtOnly() async {
        let setting = insert(untilDone: true)
        container.mainContext.insert(CompletionRecord(periodStart: Self.date(10, 5, 0, 0), completedAt: Self.now, setting: setting))
        setting.linkOpenedAt = Self.now

        await actions.completeLinkReturn(setting, in: container.mainContext, now: Self.now).value

        #expect(setting.completions.count == 1)
        #expect(setting.linkOpenedAt == nil)
        #expect(!container.mainContext.hasChanges)
    }

    @Test
    func notYetClearsOpenedAtWithoutCompleting() {
        let setting = insert(untilDone: true)
        setting.linkOpenedAt = Self.now

        actions.finishLinkReturn(setting, in: container.mainContext)

        #expect(setting.linkOpenedAt == nil)
        #expect(setting.completions.isEmpty)
        #expect(!container.mainContext.hasChanges)
    }

    @Test
    func openLinkActionOfNotificationRecordsOpenedAt() async {
        let setting = insert(untilDone: true)
        let delegate = NotificationDelegate(scheduler: .fake(center), modelContainer: container, linkOpener: recorder.opener)

        await delegate.handle(
            actionIdentifier: NotificationScheduler.openLinkActionIdentifier,
            settingID: setting.id.uuidString,
            message: setting.message,
            categoryIdentifier: NotificationScheduler.untilDoneLinkCategoryIdentifier
        )

        #expect(recorder.openedURLs == [URL(string: "examplebank://")!])
        #expect(setting.linkOpenedAt != nil)
    }

    // MARK: - 補助

    /// 東京の 2026-10-05（月曜）12:00
    private static let now = date(10, 5, 12, 0)

    private func insert(untilDone: Bool) -> NotificationSetting {
        let setting = NotificationSetting(
            message: "デイリーミッション",
            kind: .timeOfDay,
            hour: 21,
            repeatRule: .daily,
            repeatsUntilDone: untilDone,
            linkURL: "examplebank://"
        )
        container.mainContext.insert(setting)
        return setting
    }

    /// 東京の 2026 年 month-day hour:minute
    private static func date(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        NotificationScheduler.testCalendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }
}
