//
//  MonthDay.swift
//  notti
//

import Foundation

/// 繰り返しが毎月のときに選ぶ日付（1〜31 日）と月末の扱い
nonisolated enum MonthDay {
    /// 選べる日付。その日が無い月（31 日を選んで 30 日の月など）は鳴らさない
    static let range = 1...31

    /// 無い月がある日付（2 月は 28 日まで、30 日の月もある）
    static let daysMissingInSomeMonths = 29...31

    /// 月末の何日前まで選べるか（0 = 月末の当日）
    static let monthEndOffsetRange = 0...7

    /// 日付の集合を保存するときのビット（1 日 = 1, 2 日 = 2, 3 日 = 4, … 31 日 = 1 << 30）
    static func bit(of day: Int) -> Int {
        1 << (day - 1)
    }

    /// ビットマスクから日付の集合を読む。範囲外のビットは無視する
    static func set(fromMask mask: Int) -> Set<Int> {
        Set(range.filter { mask & bit(of: $0) != 0 })
    }

    /// 日付の集合をビットマスクにする。範囲外の日付は無視する
    static func mask(of days: some Sequence<Int>) -> Int {
        days.filter(range.contains).reduce(0) { $0 | bit(of: $1) }
    }
}
