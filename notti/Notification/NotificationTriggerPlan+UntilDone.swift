//
//  NotificationTriggerPlan+UntilDone.swift
//  notti
//

import Foundation

nonisolated extension NotificationTriggerPlan {
    /// 「完了するまで繰り返す」通知の催促を、先に登録しておく日数（今日を含む）。
    /// 完了・アプリの起動のたびに補充するので、完了せずアプリも開かない日がこれより続くと催促が止まる
    static let untilDoneDays = 3

    /// 「完了するまで繰り返す」通知の催促から、登録するトリガーを決める。日時は `untilDoneFireDates` のとおり
    ///
    /// 1 件の設定だけで通知センターの上限（`NotificationScheduler.pendingLimit`）を超えないよう、早い順に上限までにする
    /// （6 時から 30 分ごとなら 3 日で 108 件になる）。ほかの通知と合わせて超える分は `PendingLimitNotice` で知らせる
    ///
    /// - Parameter calendar: 日時を年・月・日・時・分に分ける暦。タイムゾーンは持たせず、端末のローカル時刻で解釈させる
    static func make(
        schedule: TimeOfDaySchedule,
        rule: UntilDoneRule,
        completedPeriodStarts: [Date],
        now: Date,
        calendar: Calendar
    ) -> Self {
        let dates = untilDoneFireDates(
            schedule: schedule,
            rule: rule,
            completedPeriodStarts: completedPeriodStarts,
            now: now,
            calendar: calendar
        )
        return .untilDone(dates.prefix(NotificationScheduler.pendingLimit).map {
            calendar.dateComponents([.year, .month, .day, .hour, .minute], from: $0)
        })
    }

    /// 「完了するまで繰り返す」通知の催促を鳴らす日時。日付を指定した 1 回きりの通知として 1 本ずつ登録する
    ///
    /// 今日から `days` 日ぶんの各日について、`schedule.time` から 0 時まで `rule.interval` ごとの日時のうち、次を満たすもの:
    /// - `now` より後
    /// - その日時を含む完了の期間（`CompletionPeriod`）が完了済みでない。期間を過ぎたら次の期間に持ち越さず、次の期間はまた最初から催促する
    /// - 毎週（繰り返しが曜日）なら、その週の催促を始める日時（週の始まり以降で最初の、選んだ曜日の `schedule.time`）以降。
    ///   曜日を複数選んでいれば、週の中で最初の曜日から始める
    /// - 毎月なら、その月の催促を始める日時（`monthlyNagStart(inMonthOf:schedule:calendar:)`）以降。
    ///   選んだ日が無い月（31 日を選んで 30 日の月など）は催促しない
    ///
    /// 毎月なら、これに今後 `months` か月の各月の最初の催促（`monthlyFirstNagDates`）を足す。3 日ぶんに入っている日時は重ねない。
    /// 合わせて上限を超えるときは、3 日ぶんの後ろを削って最初の催促を残す
    ///
    /// 0 時を過ぎたら催促しない（日の区切りが 0 時より後でも、深夜には鳴らさない）。
    /// 0 時〜日の区切りの間の日時は前の日の期間に入るので、前の日を完了していればその時間は鳴らない
    ///
    /// - Parameters:
    ///   - completedPeriodStarts: 完了の記録の期間の始まり（`CompletionRecord.periodStart`）
    ///   - calendar: 日付・曜日を数える暦。タイムゾーンもここから取る
    ///   - months: 毎月のとき、最初の催促を先に登録しておく月の数
    /// - Returns: 早い順の日時。1 回だけの通知（`CompletionCycle` が無い）なら空
    static func untilDoneFireDates(
        schedule: TimeOfDaySchedule,
        rule: UntilDoneRule,
        completedPeriodStarts: [Date],
        now: Date,
        calendar: Calendar,
        days: Int = untilDoneDays,
        months: Int = monthEndMonths
    ) -> [Date] {
        guard let cycle = CompletionCycle(schedule.repeatRule), hasNagStartDay(schedule, cycle: cycle) else {
            return []
        }
        let dates = dailyWindowFireDates(
            schedule: schedule,
            rule: rule,
            completedPeriodStarts: completedPeriodStarts,
            now: now,
            calendar: calendar,
            days: days
        )
        guard cycle == .monthly else {
            return dates
        }
        let known = Set(dates)
        let firsts = monthlyFirstNagDates(
            schedule: schedule,
            completedPeriodStarts: completedPeriodStarts,
            now: now,
            calendar: calendar,
            months: months
        )
        let extra = firsts.filter { !known.contains($0) }
        // `make` が上限（`NotificationScheduler.pendingLimit`）で切っても先の月の最初の催促が落ちないよう、その分の枠を先に取る
        // （5 日 9:00 から 30 分ごとなら 3 日ぶんだけで 90 件になる）
        let limit = max(NotificationScheduler.pendingLimit - extra.count, 0)
        return (dates.prefix(limit) + extra).sorted()
    }

    /// 催促を始める曜日・日付を選んでいるか（毎週なら曜日、毎月なら日付か月末。毎日は常に true）
    private static func hasNagStartDay(_ schedule: TimeOfDaySchedule, cycle: CompletionCycle) -> Bool {
        switch cycle {
        case .daily:
            true
        case .weekly:
            !schedule.weekdays.isEmpty
        case .monthly:
            schedule.monthDays.contains(where: MonthDay.range.contains) || schedule.monthEndOffset != nil
        }
    }

    /// 今日から `days` 日ぶんの各日の、`schedule.time` から 0 時まで `rule.interval` ごとの催促（`untilDoneFireDates` の条件どおり）
    private static func dailyWindowFireDates(
        schedule: TimeOfDaySchedule,
        rule: UntilDoneRule,
        completedPeriodStarts: [Date],
        now: Date,
        calendar: Calendar,
        days: Int = untilDoneDays
    ) -> [Date] {
        guard let cycle = CompletionCycle(schedule.repeatRule) else {
            return []
        }
        let today = calendar.startOfDay(for: now)
        var periods: [CompletionPeriod: Bool] = [:]
        var dates: [Date] = []
        for offset in 0..<days {
            guard
                let day = calendar.date(byAdding: .day, value: offset, to: today),
                let nextDay = calendar.date(byAdding: .day, value: 1, to: day),
                let start = calendar.date(bySettingHour: schedule.time.hour, minute: schedule.time.minute, second: 0, of: day)
            else {
                continue
            }
            var date = start
            while date < nextDay {
                if date > now {
                    let period = CompletionPeriod.containing(date, cycle: cycle, rule: rule, calendar: calendar)
                    let isOpen = periods[period] ?? isNagging(
                        in: period,
                        cycle: cycle,
                        schedule: schedule,
                        completedPeriodStarts: completedPeriodStarts,
                        calendar: calendar
                    )
                    periods[period] = isOpen
                    if isOpen, date >= nagStart(in: period, cycle: cycle, schedule: schedule, calendar: calendar) {
                        dates.append(date)
                    }
                }
                date = date.addingTimeInterval(TimeInterval(rule.interval.minutes * 60))
            }
        }
        return dates
    }

    /// `period` の催促をするか（完了済みでなく、催促を始める日時が期間内にある）
    private static func isNagging(
        in period: CompletionPeriod,
        cycle: CompletionCycle,
        schedule: TimeOfDaySchedule,
        completedPeriodStarts: [Date],
        calendar: Calendar
    ) -> Bool {
        !period.isCompleted(byPeriodStarts: completedPeriodStarts)
            && period.contains(nagStart(in: period, cycle: cycle, schedule: schedule, calendar: calendar))
    }

    /// `period` の催促を始める日時。毎日なら期間の始まり（その日の `schedule.time` 以降の窓だけが鳴る）。
    /// 毎週なら、期間の始まり以降で最初の、選んだ曜日の `schedule.time`。期間内に無ければ期間の終わり（その週は鳴らない）。
    /// 毎月なら `monthlyNagStart(inMonthOf:schedule:calendar:)`。その月に無ければ期間の終わり（その月は鳴らない）
    private static func nagStart(
        in period: CompletionPeriod,
        cycle: CompletionCycle,
        schedule: TimeOfDaySchedule,
        calendar: Calendar
    ) -> Date {
        switch cycle {
        case .daily:
            return period.start
        case .weekly:
            return weeklyNagStart(in: period, schedule: schedule, calendar: calendar)
        case .monthly:
            let start = monthlyNagStart(inMonthOf: period.start, schedule: schedule, calendar: calendar)
            return start.map { min($0, period.end) } ?? period.end
        }
    }

    /// 毎週の `period` の催促を始める日時（期間の始まり以降で最初の、選んだ曜日の `schedule.time`）。期間内に無ければ期間の終わり
    private static func weeklyNagStart(in period: CompletionPeriod, schedule: TimeOfDaySchedule, calendar: Calendar) -> Date {
        let weekdays = Set(schedule.weekdays.map(\.rawValue))
        for offset in 0...7 {
            guard
                let day = calendar.date(byAdding: .day, value: offset, to: period.start),
                weekdays.contains(calendar.component(.weekday, from: day)),
                let start = calendar.date(bySettingHour: schedule.time.hour, minute: schedule.time.minute, second: 0, of: day),
                start >= period.start
            else {
                continue
            }
            return min(start, period.end)
        }
        return period.end
    }
}
