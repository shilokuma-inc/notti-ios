//
//  NagInterval.swift
//  notti
//

import Foundation

/// 「完了するまで繰り返す」通知で、完了するまで催促する間隔。保存値は `NotificationSetting.nagIntervalMinutes`
nonisolated enum NagInterval: Int, CaseIterable, Codable, Identifiable, Sendable {
    case tenMinutes = 10
    case thirtyMinutes = 30
    case oneHour = 60

    /// 既定の間隔。64 件の上限に収まりやすいよう 30 分にしている
    static let `default`: Self = .thirtyMinutes

    var id: Int {
        rawValue
    }

    /// 間隔の分数
    var minutes: Int {
        rawValue
    }

    /// 画面に出す表記
    var label: String {
        switch self {
        case .tenMinutes: "10 分ごと"
        case .thirtyMinutes: "30 分ごと"
        case .oneHour: "1 時間ごと"
        }
    }
}
