//
//  UntilDoneRule.swift
//  notti
//

import Foundation

/// 「完了するまで繰り返す」通知の催促の決まり。`NotificationSetting` の項目を、隔離境界を越えて渡せる形にまとめたもの
nonisolated struct UntilDoneRule: Equatable, Sendable {
    /// 完了するまで催促する間隔
    var interval: NagInterval = .default
    /// 日の区切りの時刻。これより前の完了は前の日の完了として扱う
    var dayBoundary = TimeOfDay(hour: 0, minute: 0)
    /// 週の始まり。繰り返しが曜日のとき、完了の期間（週）をここで区切る
    var weekStart = WeekStart()
}

/// 週の始まりの曜日と時刻（例: 月曜 5 時に週が変わる）
nonisolated struct WeekStart: Equatable, Sendable {
    /// 週が始まる曜日。既定は月曜
    var weekday: Weekday = .monday
    /// 週が始まる時刻。既定は 0 時
    var time = TimeOfDay(hour: 0, minute: 0)
}
