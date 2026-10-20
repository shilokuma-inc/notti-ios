//
//  LinkURLDraftTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import Testing

struct LinkURLDraftTests {
    /// 東京の 2026-10-05 12:00:30
    private let now = NotificationScheduler.testCalendar.date(
        from: DateComponents(year: 2026, month: 10, day: 5, hour: 12, minute: 0, second: 30)
    )!

    private func problem(of draft: NotificationDraft) -> NotificationDraft.Problem? {
        draft.problem(now: now, calendar: NotificationScheduler.testCalendar)
    }

    @Test
    func linkCanBeSavedWithEveryKind() {
        var draft = NotificationDraft(message: "残高", linkURL: "https://example.com")
        #expect(problem(of: draft) == nil)

        draft.kind = .timeOfDay
        draft.linkURL = "examplebank://"
        #expect(problem(of: draft) == nil)

        draft.repeatsUntilDone = true
        #expect(problem(of: draft) == nil)
    }

    @Test
    func emptyLinkMeansNoLink() {
        let draft = NotificationDraft(message: "残高", linkURL: " ")

        #expect(problem(of: draft) == nil)
    }

    @Test
    func unreadableLinkCannotBeSaved() {
        var draft = NotificationDraft(message: "残高", linkURL: "example.com")
        #expect(problem(of: draft) == .unreadableLinkURL)

        draft.kind = .timeOfDay
        #expect(problem(of: draft) == .unreadableLinkURL)
    }

    @Test
    func unsupportedSchemeCannotBeSaved() {
        let draft = NotificationDraft(message: "残高", linkURL: "javascript:alert(1)")

        #expect(problem(of: draft) == .unsupportedLinkScheme)
    }

    @Test
    func messageAndScheduleProblemsComeFirst() {
        var draft = NotificationDraft(message: " ", kind: .timeOfDay, linkURL: "example.com")
        #expect(problem(of: draft) == .emptyMessage)

        draft.message = "歩数"
        draft.schedule.repeatRule = .weekdays
        #expect(problem(of: draft) == .noWeekday)
    }

    @Test
    func changingOnlyLinkURLDoesNotRequireRescheduling() {
        let old = NotificationDraft(message: "残高", linkURL: "https://example.com")
        var draft = old
        draft.linkURL = "examplebank://"

        #expect(!draft.requiresRescheduling(from: old))
        #expect(!old.requiresRescheduling(from: old))
    }

    @Test
    func addingOrRemovingLinkRequiresRescheduling() {
        let withoutLink = NotificationDraft(message: "残高")
        var withLink = withoutLink
        withLink.linkURL = "https://example.com"

        #expect(withLink.requiresRescheduling(from: withoutLink))
        #expect(withoutLink.requiresRescheduling(from: withLink))
    }

    @Test
    func changingOtherFieldsRequiresRescheduling() {
        let old = NotificationDraft(message: "残高", linkURL: "https://example.com")
        var draft = old
        draft.linkURL = "examplebank://"
        draft.interval = .twentyFourHours

        #expect(draft.requiresRescheduling(from: old))
    }
}
