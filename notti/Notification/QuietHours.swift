//
//  QuietHours.swift
//  notti
//

import Foundation

/// 1 日のうちの時刻（時・分）
nonisolated struct TimeOfDay: Comparable, Codable, Hashable, Sendable {
    /// 0...23
    var hour: Int
    /// 0...59
    var minute: Int

    /// 0 時 0 分からの分数
    var minutesSinceMidnight: Int {
        hour * 60 + minute
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}

/// おやすみ時間（通知しない時間帯）。アプリ全体で 1 つ持つ
nonisolated struct QuietHours: Codable, Equatable, Sendable {
    /// 既定値。無効（24 時間通知する）で、有効にしたときの初期値は 23:00〜7:00
    static let `default` = Self(isEnabled: false, start: TimeOfDay(hour: 23, minute: 0), end: TimeOfDay(hour: 7, minute: 0))

    var isEnabled: Bool
    /// 開始時刻（この時刻を含む）
    var start: TimeOfDay
    /// 終了時刻（この時刻を含まない）。開始より前なら日をまたぐ（例: 23:00〜7:00）
    var end: TimeOfDay

    /// 通知を止める時間帯が実際にあるか。開始 = 終了は長さ 0 として扱う
    var isActive: Bool {
        isEnabled && start != end
    }

    /// `time` がおやすみ時間に入るか
    func contains(_ time: TimeOfDay) -> Bool {
        guard isActive else {
            return false
        }
        if start < end {
            return start <= time && time < end
        }
        // 日をまたぐ
        return start <= time || time < end
    }
}
