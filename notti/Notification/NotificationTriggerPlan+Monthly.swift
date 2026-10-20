//
//  NotificationTriggerPlan+Monthly.swift
//  notti
//

import Foundation

nonisolated extension NotificationTriggerPlan {
    /// 月末（N 日前）の通知を、先に登録しておく回数（月の数）。
    /// 起動・前面復帰の整合（`NotificationReconciler`）のたびに補充するので、アプリをこれより長く開かないと通知が止まる
    static let monthEndMonths = 3

    /// 毎月の通知のトリガー。選んだ日付ごとに繰り返す 1 本ずつと、月末（N 日前）の 1 回きりを `monthEndMonths` 回ぶん
    ///
    /// 月末（N 日前）が選んだ日付と同じ日になる月（31 日と月末を選んで 31 日まである月など）は、日付の繰り返しの通知だけにする
    /// （同じ時刻に 2 本鳴らないように）。その月の分は数に入れず、先の月を足さない
    ///
    /// - Parameter calendar: 月の日数を数え、日時を年・月・日・時・分に分ける暦。タイムゾーンもここから取る
    static func monthlyTriggers(schedule: TimeOfDaySchedule, now: Date, calendar: Calendar) -> [TimeOfDayTrigger] {
        let monthDays = schedule.monthDays.filter(MonthDay.range.contains).sorted()
        let repeating = monthDays.map { TimeOfDayTrigger.monthDay($0, schedule.time) }
        guard let offset = schedule.monthEndOffset else {
            return repeating
        }
        let monthEnds = monthEndFireDates(time: schedule.time, offset: offset, now: now, calendar: calendar)
            .filter { !monthDays.contains(calendar.component(.day, from: $0)) }
            .map { TimeOfDayTrigger.monthEnd(calendar.dateComponents([.year, .month, .day, .hour, .minute], from: $0)) }
        return repeating + monthEnds
    }

    /// 月末の `offset` 日前（0 = 月末の当日）の `time` の日時のうち、`now` より後のものを早い順に `count` 個。
    /// 今月の分がまだ先なら今月を含む
    ///
    /// 月の日数（28〜31 日・うるう年）は `calendar` で数える。夏時間の切り替えでその時刻が無い日は、その直後の時刻にする。
    /// `offset` は `MonthDay.monthEndOffsetRange` に収める
    ///
    /// - Parameter calendar: 月の日数を数える暦。タイムゾーンもここから取る
    static func monthEndFireDates(
        time: TimeOfDay,
        offset: Int,
        now: Date,
        calendar: Calendar,
        count: Int = monthEndMonths
    ) -> [Date] {
        guard let thisMonth = calendar.dateInterval(of: .month, for: now)?.start else {
            return []
        }
        let range = MonthDay.monthEndOffsetRange
        let offset = min(max(offset, range.lowerBound), range.upperBound)
        var dates: [Date] = []
        // 今月の分を過ぎていれば、来月から `count` か月ぶん
        for month in 0...count where dates.count < count {
            guard
                let monthStart = calendar.date(byAdding: .month, value: month, to: thisMonth),
                let days = calendar.range(of: .day, in: .month, for: monthStart),
                let day = calendar.date(byAdding: .day, value: days.count - 1 - offset, to: monthStart),
                let date = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day),
                date > now
            else {
                continue
            }
            dates.append(date)
        }
        return dates
    }
}
