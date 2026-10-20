//
//  TimeOfDaySchedule.swift
//  notti
//

import Foundation

/// 時刻指定の通知をいつ鳴らすか。`NotificationSetting` の時刻指定の項目を、隔離境界を越えて渡せる形にまとめたもの
nonisolated struct TimeOfDaySchedule: Equatable, Sendable {
    /// 毎日・曜日・毎月の通知を鳴らす時刻
    var time: TimeOfDay
    /// 繰り返し方
    var repeatRule: NotificationRepeat
    /// 繰り返しが曜日のときに鳴らす曜日
    var weekdays: Set<Weekday> = []
    /// 繰り返しが 1 回だけのときに鳴らす日時
    var onceDate: Date?
    /// 繰り返しが毎月のときに鳴らす日付（1〜31 日）
    var monthDays: Set<Int> = []
    /// 繰り返しが毎月のときに、月末の何日前に鳴らすか（0 = 月末の当日）。月末に鳴らさないなら nil
    var monthEndOffset: Int?
}
