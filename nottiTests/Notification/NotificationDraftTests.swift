//
//  NotificationDraftTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import Testing

struct NotificationDraftTests {
    /// 東京の 2026-10-05 12:00:30
    private let now = NotificationScheduler.testCalendar.date(
        from: DateComponents(year: 2026, month: 10, day: 5, hour: 12, minute: 0, second: 30)
    )!

    @Test
    func emptyMessageCannotBeSaved() {
        let draft = NotificationDraft(message: " \n")

        #expect(draft.problem(now: now, calendar: NotificationScheduler.testCalendar) == .emptyMessage)
    }

    @Test
    func intervalAndDailyCanBeSaved() {
        var draft = NotificationDraft(message: "水を飲む")
        #expect(draft.problem(now: now, calendar: NotificationScheduler.testCalendar) == nil)

        draft.kind = .timeOfDay
        #expect(draft.problem(now: now, calendar: NotificationScheduler.testCalendar) == nil)
    }

    @Test
    func weekdaysNeedAtLeastOneWeekday() {
        var draft = NotificationDraft(message: "歩数", kind: .timeOfDay)
        draft.schedule.repeatRule = .weekdays
        #expect(draft.problem(now: now, calendar: NotificationScheduler.testCalendar) == .noWeekday)

        draft.schedule.weekdays = [.monday]
        #expect(draft.problem(now: now, calendar: NotificationScheduler.testCalendar) == nil)
    }

    @Test
    func onceNeedsFutureDate() {
        var draft = NotificationDraft(message: "残高", kind: .timeOfDay)
        draft.schedule.repeatRule = .once
        #expect(draft.problem(now: now, calendar: NotificationScheduler.testCalendar) == .pastOnceDate)

        // 分未満を切り捨てると今の分（12:00）になり、過ぎている
        draft.schedule.onceDate = now.addingTimeInterval(20)
        #expect(draft.problem(now: now, calendar: NotificationScheduler.testCalendar) == .pastOnceDate)

        draft.schedule.onceDate = now.addingTimeInterval(60)
        #expect(draft.problem(now: now, calendar: NotificationScheduler.testCalendar) == nil)
    }

    @Test
    func intervalIgnoresTimeOfDayFields() {
        var draft = NotificationDraft(message: "水を飲む")
        draft.schedule.repeatRule = .weekdays

        #expect(draft.problem(now: now, calendar: NotificationScheduler.testCalendar) == nil)
    }
}
