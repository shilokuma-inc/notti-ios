//
//  Weekday.swift
//  notti
//

import Foundation

/// 曜日。raw 値は `DateComponents.weekday`（グレゴリオ暦の 1 = 日曜 〜 7 = 土曜）と同じ
nonisolated enum Weekday: Int, CaseIterable, Codable, Comparable, Identifiable, Sendable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var id: Int {
        rawValue
    }

    /// 曜日の集合を保存するときのビット（日曜 = 1, 月曜 = 2, … 土曜 = 64）
    var bit: Int {
        1 << (rawValue - 1)
    }

    /// 画面に出す 1 文字の表記
    var shortLabel: String {
        switch self {
        case .sunday: "日"
        case .monday: "月"
        case .tuesday: "火"
        case .wednesday: "水"
        case .thursday: "木"
        case .friday: "金"
        case .saturday: "土"
        }
    }

    /// ビットマスクから曜日の集合を読む。範囲外のビットは無視する
    static func set(fromMask mask: Int) -> Set<Self> {
        Set(allCases.filter { mask & $0.bit != 0 })
    }

    /// 曜日の集合をビットマスクにする
    static func mask(of weekdays: some Sequence<Self>) -> Int {
        weekdays.reduce(0) { $0 | $1.bit }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
