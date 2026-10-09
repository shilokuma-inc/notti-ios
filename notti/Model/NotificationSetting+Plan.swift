//
//  NotificationSetting+Plan.swift
//  notti
//

import Foundation

extension NotificationSetting {
    /// 時刻指定の通知をいつ鳴らすか
    var timeOfDaySchedule: TimeOfDaySchedule {
        TimeOfDaySchedule(time: timeOfDay, repeatRule: repeatRule, weekdays: weekdays, onceDate: onceDate)
    }

    /// `quietHours` のもとで登録するトリガー。時刻指定の通知はおやすみ時間を適用しない
    ///
    /// 完了するまで繰り返す通知は、`now` の時点で登録する催促（完了済みの期間を除き、先に登録する日数ぶん）。
    /// `NotificationScheduler.plan(for:now:)` と同じトリガーになる
    ///
    /// - Parameter now: 1 回だけの通知の日時が過ぎたかどうか、催促のどの日時から登録するかの基準
    func plan(quietHours: QuietHours, calendar: Calendar = .current, now: Date = .now) -> NotificationTriggerPlan {
        switch kind {
        case .interval:
            NotificationTriggerPlan.make(
                startDate: startDate,
                interval: interval,
                quietHours: quietHours,
                calendar: calendar,
                timeZone: calendar.timeZone
            )
        case .timeOfDay where completionCycle != nil:
            NotificationTriggerPlan.make(
                schedule: timeOfDaySchedule,
                rule: untilDoneRule,
                completedPeriodStarts: completions.map(\.periodStart),
                now: now,
                calendar: calendar
            )
        case .timeOfDay:
            NotificationTriggerPlan.make(schedule: timeOfDaySchedule, now: now, calendar: calendar)
        }
    }

    /// ON なのに、おやすみ時間のせいで一度も鳴らない
    func isSilent(quietHours: QuietHours, calendar: Calendar = .current) -> Bool {
        isEnabled && plan(quietHours: quietHours, calendar: calendar).isSilent
    }
}

extension Sequence<NotificationSetting> {
    /// ON の通知をすべて登録したときの通知の数。`NotificationScheduler.pendingLimit` を超えると一部が鳴らない
    ///
    /// 完了するまで繰り返す通知は、`now` の時点で登録する催促の数で数える（その日の催促が進むと減り、完了すると次の期間の分になる）。
    /// 超えたときに通知ごとに枠を配分はしない（OS は鳴るのが早いものから残す）
    func requestCount(quietHours: QuietHours, calendar: Calendar = .current, now: Date = .now) -> Int {
        filter(\.isEnabled)
            .map { $0.plan(quietHours: quietHours, calendar: calendar, now: now).requestCount }
            .reduce(0, +)
    }
}
