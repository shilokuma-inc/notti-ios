//
//  NotificationTriggerPlan+MonthlyUntilDone.swift
//  notti
//

import Foundation

nonisolated extension NotificationTriggerPlan {
    /// 毎月の「完了するまで繰り返す」通知で、`monthStart` を含む月の催促を始める日時
    ///
    /// 催促を始める日は、選んだ日付（`schedule.monthDays`）か月末（N 日前）（`schedule.monthEndOffset`）。
    /// 両方・複数あるときは、その月の中で最も早い日から始める（毎週で、週の中で最初の曜日から始めるのと同じ）。
    /// その日の `schedule.time` の日時。夏時間の切り替えでその時刻が無い日は、その直後の時刻にする
    ///
    /// 月の日数（28〜31 日・うるう年）は `calendar` で数える。選んだ日付がその月に無い（31 日を選んで 30 日の月など）なら、
    /// その日付は使わない。月末（N 日前）は `monthEndFireDates` と同じく、月の最後の日から `offset` 日前
    /// （`offset` は `MonthDay.monthEndOffsetRange` に収める）
    ///
    /// - Parameter calendar: 月の日数を数える暦。タイムゾーンもここから取る
    /// - Returns: その月に催促を始める日が無ければ nil
    static func monthlyNagStart(inMonthOf monthStart: Date, schedule: TimeOfDaySchedule, calendar: Calendar) -> Date? {
        guard
            let month = calendar.dateInterval(of: .month, for: monthStart),
            let daysInMonth = calendar.range(of: .day, in: .month, for: month.start)?.count
        else {
            return nil
        }
        var candidates = schedule.monthDays.filter { MonthDay.range.contains($0) && $0 <= daysInMonth }
        if let offset = schedule.monthEndOffset {
            let range = MonthDay.monthEndOffsetRange
            candidates.insert(daysInMonth - min(max(offset, range.lowerBound), range.upperBound))
        }
        guard
            let day = candidates.min(),
            let date = calendar.date(byAdding: .day, value: day - 1, to: month.start)
        else {
            return nil
        }
        return calendar.date(bySettingHour: schedule.time.hour, minute: schedule.time.minute, second: 0, of: date)
    }

    /// 毎月の「完了するまで繰り返す」通知で、今後 `months` か月の各月の最初の催促（その月の催促を始める日時）。早い順
    ///
    /// 今月の催促を始める日時がまだ先なら今月から、過ぎている（または今月はその日が無い）なら来月から `months` か月。
    /// そのうち、完了済みの月とその日が無い月は入れない（月の数には数える）。
    /// 3 日ぶん（`untilDoneDays`）の催促が途切れても、各月の最初の 1 回は鳴るようにするため
    ///
    /// - Parameters:
    ///   - completedPeriodStarts: 完了の記録の期間の始まり（`CompletionRecord.periodStart`）
    ///   - calendar: 月の日数を数える暦。タイムゾーンもここから取る
    static func monthlyFirstNagDates(
        schedule: TimeOfDaySchedule,
        completedPeriodStarts: [Date],
        now: Date,
        calendar: Calendar,
        months: Int = monthEndMonths
    ) -> [Date] {
        guard months > 0, let thisMonth = calendar.dateInterval(of: .month, for: now)?.start else {
            return []
        }
        let starts = (0...months).map { month in
            calendar.date(byAdding: .month, value: month, to: thisMonth)
                .flatMap { monthlyNagStart(inMonthOf: $0, schedule: schedule, calendar: calendar) }
        }
        let firstMonth = starts[0].map { $0 > now } == true ? 0 : 1
        return starts[firstMonth..<(firstMonth + months)]
            .compactMap { $0 }
            .filter { start in
                start > now
                    && !CompletionPeriod.containing(start, cycle: .monthly, rule: UntilDoneRule(), calendar: calendar)
                        .isCompleted(byPeriodStarts: completedPeriodStarts)
            }
    }
}
