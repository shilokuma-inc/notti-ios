//
//  NotificationSetting+Plan.swift
//  notti
//

import Foundation

extension NotificationSetting {
    /// `quietHours` のもとで登録するトリガー
    func plan(quietHours: QuietHours, calendar: Calendar = .current) -> NotificationTriggerPlan {
        NotificationTriggerPlan.make(
            startDate: startDate,
            interval: interval,
            quietHours: quietHours,
            calendar: calendar,
            timeZone: calendar.timeZone
        )
    }

    /// ON なのに、おやすみ時間のせいで一度も鳴らない
    func isSilent(quietHours: QuietHours, calendar: Calendar = .current) -> Bool {
        isEnabled && plan(quietHours: quietHours, calendar: calendar).isSilent
    }
}

extension Sequence<NotificationSetting> {
    /// ON の通知をすべて登録したときの通知の数。`NotificationScheduler.pendingLimit` を超えると一部が鳴らない
    func requestCount(quietHours: QuietHours, calendar: Calendar = .current) -> Int {
        filter(\.isEnabled)
            .map { $0.plan(quietHours: quietHours, calendar: calendar).requestCount }
            .reduce(0, +)
    }
}
