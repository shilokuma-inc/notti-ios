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

    /// 毎月の日付に、無い月がある日（29〜31 日）を選んでいる。その月は鳴らない
    var hasDaysMissingInSomeMonths: Bool {
        monthDays.contains { MonthDay.daysMissingInSomeMonths.contains($0) }
    }

    /// 毎月の鳴らす日の数（1〜31 日の日付と、月末（N 日前））
    var monthlyDayCount: Int {
        monthDays.filter(MonthDay.range.contains).count + (monthEndOffset == nil ? 0 : 1)
    }

    /// 毎月の鳴らす日を 1 つだけにする（完了するまで繰り返すときは、催促を始める日が 1 つのため）。
    /// 日付を選んでいれば最も早い日付を残して月末を外し、日付が無ければ月末を残す
    mutating func keepFirstMonthlyDay() {
        if let first = monthDays.filter(MonthDay.range.contains).min() {
            monthDays = [first]
            monthEndOffset = nil
        }
    }
}
