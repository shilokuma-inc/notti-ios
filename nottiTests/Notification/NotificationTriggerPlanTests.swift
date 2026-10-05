//
//  NotificationTriggerPlanTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import Testing

struct NotificationTriggerPlanTests {
    private static let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    private static let overnight = QuietHours(isEnabled: true, start: time(23, 0), end: time(7, 0))

    @Test(arguments: NotificationInterval.allCases)
    func disabledQuietHoursUsesRepeatingInterval(interval: NotificationInterval) {
        let plan = Self.plan(start: Self.date(14, 23), interval: interval, quietHours: .default)
        #expect(plan == .repeatingInterval(interval.timeInterval))
    }

    @Test
    func quietHoursWithSameStartAndEndExcludesNothing() {
        let quietHours = QuietHours(isEnabled: true, start: Self.time(9, 0), end: Self.time(9, 0))
        #expect(!quietHours.isActive)
        #expect(!quietHours.contains(Self.time(9, 0)))
        #expect(Self.plan(start: Self.date(14, 23), interval: .oneHour, quietHours: quietHours) == .repeatingInterval(3600))
    }

    @Test
    func hourlyKeepsStartMinuteAndSkipsOvernightQuietHours() {
        let plan = Self.plan(start: Self.date(14, 23), interval: .oneHour, quietHours: Self.overnight)

        guard case let .dailyTimes(times) = plan else {
            Issue.record("時刻ごとのトリガーになるはず: \(plan)")
            return
        }
        #expect(times == (7...22).map { Self.time($0, 23) })
    }

    @Test
    func hourlySkipsDaytimeQuietHours() {
        let quietHours = QuietHours(isEnabled: true, start: Self.time(12, 0), end: Self.time(13, 0))

        let plan = Self.plan(start: Self.date(9, 30), interval: .oneHour, quietHours: quietHours)

        let expected = (0...23).filter { $0 != 12 }.map { Self.time($0, 30) }
        #expect(plan == .dailyTimes(expected))
    }

    @Test
    func boundaryIncludesStartAndExcludesEnd() {
        let plan = Self.plan(start: Self.date(7, 0), interval: .oneHour, quietHours: Self.overnight)

        guard case let .dailyTimes(times) = plan else {
            Issue.record("時刻ごとのトリガーになるはず: \(plan)")
            return
        }
        #expect(times.first == Self.time(7, 0))
        #expect(times.last == Self.time(22, 0))
        #expect(!times.contains(Self.time(23, 0)))
    }

    @Test
    func dailyOutsideQuietHoursRingsOnce() {
        let plan = Self.plan(start: Self.date(14, 23), interval: .twentyFourHours, quietHours: Self.overnight)
        #expect(plan == .dailyTimes([Self.time(14, 23)]))
        #expect(!plan.isSilent)
    }

    @Test
    func dailyInsideQuietHoursNeverRings() {
        let plan = Self.plan(start: Self.date(2, 0), interval: .twentyFourHours, quietHours: Self.overnight)
        #expect(plan == .dailyTimes([]))
        #expect(plan.isSilent)
    }

    @Test
    func startTimeIsReadInGivenTimeZone() {
        // 東京の 14:23 は UTC の 5:23
        let start = Self.date(14, 23)

        let plan = Self.plan(
            start: start,
            interval: .twentyFourHours,
            quietHours: Self.overnight,
            timeZone: TimeZone(identifier: "UTC")!
        )

        #expect(plan == .dailyTimes([]))
    }

    @Test(arguments: [
        (23, 0, true), (23, 59, true), (0, 0, true), (6, 59, true), (7, 0, false), (22, 59, false), (12, 0, false)
    ])
    func overnightContains(hour: Int, minute: Int, expected: Bool) {
        #expect(Self.overnight.contains(Self.time(hour, minute)) == expected)
    }

    @Test
    func disabledQuietHoursContainsNothing() {
        var quietHours = Self.overnight
        quietHours.isEnabled = false
        #expect(!quietHours.contains(Self.time(0, 0)))
    }

    private static func plan(
        start: Date,
        interval: NotificationInterval,
        quietHours: QuietHours,
        timeZone: TimeZone = tokyo
    ) -> NotificationTriggerPlan {
        NotificationTriggerPlan.make(
            startDate: start,
            interval: interval,
            quietHours: quietHours,
            calendar: Calendar(identifier: .gregorian),
            timeZone: timeZone
        )
    }

    /// 東京の 2026-10-05 hour:minute
    private static func date(_ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tokyo
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: hour, minute: minute))!
    }

    private static func time(_ hour: Int, _ minute: Int) -> TimeOfDay {
        TimeOfDay(hour: hour, minute: minute)
    }
}
