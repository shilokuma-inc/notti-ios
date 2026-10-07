//
//  NotificationKind.swift
//  notti
//

import Foundation

/// 通知の種類。保存値は `NotificationSetting.kindRawValue`
nonisolated enum NotificationKind: String, CaseIterable, Codable, Identifiable, Sendable {
    /// 起点から一定間隔（`NotificationInterval`）ごとに鳴らす
    case interval
    /// 決めた時刻に鳴らす（`NotificationRepeat` で繰り返し方を選ぶ）
    case timeOfDay

    var id: String {
        rawValue
    }

    /// 画面に出す表記
    var label: String {
        switch self {
        case .interval: "一定間隔"
        case .timeOfDay: "時刻を指定"
        }
    }
}
