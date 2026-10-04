//
//  NotificationInterval.swift
//  notti
//

import Foundation

/// 通知を繰り返す間隔。起点（ON にした時刻）から N 時間ごとに鳴らす
nonisolated enum NotificationInterval: Int, CaseIterable, Codable, Sendable {
    case oneHour = 1
    case twentyFourHours = 24

    /// 間隔の時間数
    var hours: Int {
        rawValue
    }

    /// 間隔の秒数。`UNTimeIntervalNotificationTrigger` に渡す
    var timeInterval: TimeInterval {
        TimeInterval(hours * 60 * 60)
    }
}
