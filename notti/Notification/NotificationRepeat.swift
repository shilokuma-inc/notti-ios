//
//  NotificationRepeat.swift
//  notti
//

import Foundation

/// 時刻指定の通知の繰り返し方。保存値は `NotificationSetting.repeatRawValue`
nonisolated enum NotificationRepeat: String, CaseIterable, Codable, Identifiable, Sendable {
    /// 毎日同じ時刻に鳴らす
    case daily
    /// 選んだ曜日の同じ時刻に鳴らす
    case weekdays
    /// 指定した日時に 1 回だけ鳴らす
    case once
    /// 毎月、選んだ日付・月末（N 日前）の同じ時刻に鳴らす
    case monthly

    var id: String {
        rawValue
    }

    /// 画面に出す表記
    var label: String {
        switch self {
        case .daily: "毎日"
        case .weekdays: "曜日を選ぶ"
        case .once: "1 回だけ"
        case .monthly: "毎月"
        }
    }

    /// 追加・編集画面の「繰り返し」に出す選択肢
    static let selectableCases: [Self] = [.daily, .weekdays, .once, .monthly]
}
