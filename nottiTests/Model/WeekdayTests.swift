//
//  WeekdayTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import Testing

struct WeekdayTests {
    @Test
    func rawValuesMatchGregorianWeekdayComponent() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        // 2026-10-04 は日曜日
        let sunday = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 4)))

        for offset in 0..<7 {
            let date = try #require(calendar.date(byAdding: .day, value: offset, to: sunday))
            #expect(calendar.component(.weekday, from: date) == Weekday.allCases[offset].rawValue)
        }
    }

    @Test
    func maskRoundTrips() {
        let weekdays: Set<Weekday> = [.monday, .wednesday, .friday]

        let mask = Weekday.mask(of: weekdays)

        #expect(mask == 0b010_1010)
        #expect(Weekday.set(fromMask: mask) == weekdays)
        #expect(Weekday.set(fromMask: Weekday.mask(of: Weekday.allCases)) == Set(Weekday.allCases))
        #expect(Weekday.mask(of: []) == 0)
    }
}
