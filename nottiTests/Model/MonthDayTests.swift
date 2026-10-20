//
//  MonthDayTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import Testing

struct MonthDayTests {
    @Test
    func maskRoundTrips() {
        let days: Set<Int> = [1, 10, 31]

        let mask = MonthDay.mask(of: days)

        #expect(mask == 1 | 1 << 9 | 1 << 30)
        #expect(MonthDay.set(fromMask: mask) == days)
        #expect(MonthDay.set(fromMask: MonthDay.mask(of: MonthDay.range)) == Set(MonthDay.range))
        #expect(MonthDay.mask(of: []) == 0)
    }

    @Test
    func outOfRangeDaysAreIgnored() {
        #expect(MonthDay.mask(of: [0, 32, -1]) == 0)
        #expect(MonthDay.set(fromMask: 1 << 31 | 1 << 40).isEmpty)
    }
}
