//
//  CompletionPeriod.swift
//  notti
//

import Foundation

/// 「完了するまで繰り返す」通知を何ごとに完了するか
nonisolated enum CompletionCycle: Sendable {
    /// 日ごと（繰り返しが毎日）。日の区切りで期間が変わる
    case daily
    /// 週ごと（繰り返しが曜日）。週の始まりで期間が変わる
    case weekly

    /// 繰り返し方に対応する完了の単位。1 回だけの通知は完了するまで繰り返さないので nil
    init?(_ repeatRule: NotificationRepeat) {
        switch repeatRule {
        case .daily: self = .daily
        case .weekdays: self = .weekly
        case .once: return nil
        }
    }
}

/// 完了の期間（日・週）1 つぶん。`start` を含み `end` を含まない
nonisolated struct CompletionPeriod: Hashable, Sendable {
    /// 期間の始まり（日の区切り・週の始まりの日時）。`CompletionRecord.periodStart` に保存する値
    var start: Date
    /// 次の期間の始まり
    var end: Date

    /// `date` を含む期間
    ///
    /// 日ごとなら、`date` 以前で最後の日の区切りから次の日の区切りまで（区切りが 4 時なら、深夜 1 時は前の日の期間）。
    /// 週ごとなら、`date` 以前で最後の週の始まりから 7 日後の週の始まりまで
    ///
    /// - Parameter calendar: 日付と曜日を数える暦。タイムゾーンもここから取る
    static func containing(_ date: Date, cycle: CompletionCycle, rule: UntilDoneRule, calendar: Calendar) -> Self {
        switch cycle {
        case .daily:
            var start = boundary(rule.dayBoundary, onDayOf: date, calendar: calendar)
            if start > date {
                start = boundary(rule.dayBoundary, onDayOf: adding(days: -1, to: date, calendar: calendar), calendar: calendar)
            }
            let end = boundary(rule.dayBoundary, onDayOf: adding(days: 1, to: start, calendar: calendar), calendar: calendar)
            return Self(start: start, end: end)
        case .weekly:
            let weekday = calendar.component(.weekday, from: date)
            let daysSinceWeekStart = (weekday - rule.weekStart.weekday.rawValue + 7) % 7
            let weekStartDay = adding(days: -daysSinceWeekStart, to: date, calendar: calendar)
            var start = boundary(rule.weekStart.time, onDayOf: weekStartDay, calendar: calendar)
            if start > date {
                start = boundary(rule.weekStart.time, onDayOf: adding(days: -7, to: weekStartDay, calendar: calendar), calendar: calendar)
            }
            let end = boundary(rule.weekStart.time, onDayOf: adding(days: 7, to: start, calendar: calendar), calendar: calendar)
            return Self(start: start, end: end)
        }
    }

    /// `date` がこの期間に入っているか
    func contains(_ date: Date) -> Bool {
        start <= date && date < end
    }

    /// 完了の記録の期間の始まり（`CompletionRecord.periodStart`）のどれかがこの期間に入っていれば、完了済み
    ///
    /// 始まりの日時の一致ではなく期間に入っているかで見るので、後から日の区切り・週の始まりを変えても、
    /// 変える前の記録はそれを含む新しい期間の完了として扱われる
    func isCompleted(byPeriodStarts periodStarts: some Sequence<Date>) -> Bool {
        periodStarts.contains { contains($0) }
    }

    /// `day` と同じ日の `time` の日時。夏時間の切り替えでその時刻が無い日は、その直後の時刻にする
    private static func boundary(_ time: TimeOfDay, onDayOf day: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day)
            ?? calendar.startOfDay(for: day)
    }

    private static func adding(days: Int, to date: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date.addingTimeInterval(TimeInterval(days * 24 * 60 * 60))
    }
}
