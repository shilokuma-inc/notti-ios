//
//  NotificationSetting+Plan.swift
//  notti
//

import Foundation

extension NotificationSetting {
    /// `quietHours` のもとで登録するトリガー。時刻指定の通知はおやすみ時間を適用しない
    ///
    /// - Parameter now: 1 回だけの通知の日時が過ぎたかどうかの基準
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
        case .timeOfDay:
            NotificationTriggerPlan.make(
                timeOfDay: timeOfDay,
                repeatRule: repeatRule,
                weekdays: weekdays,
                once: onceDate.flatMap { TimeOfDayTrigger.once(at: $0, now: now, calendar: calendar) }
            )
        }
    }

    /// ON なのに、おやすみ時間のせいで一度も鳴らない
    func isSilent(quietHours: QuietHours, calendar: Calendar = .current) -> Bool {
        isEnabled && plan(quietHours: quietHours, calendar: calendar).isSilent
    }
}

extension Sequence<NotificationSetting> {
    /// ON の通知をすべて登録したときの通知の数。`NotificationScheduler.pendingLimit` を超えると一部が鳴らない
    func requestCount(quietHours: QuietHours, calendar: Calendar = .current, now: Date = .now) -> Int {
        filter(\.isEnabled)
            .map { $0.plan(quietHours: quietHours, calendar: calendar, now: now).requestCount }
            .reduce(0, +)
    }
}
