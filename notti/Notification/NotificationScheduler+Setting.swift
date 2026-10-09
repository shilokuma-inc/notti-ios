//
//  NotificationScheduler+Setting.swift
//  notti
//

import Foundation

extension NotificationScheduler {
    /// 設定の種類に合わせて、登録するトリガーを決める（間隔は今のおやすみ時間で、時刻指定はおやすみ時間を適用せずに）
    ///
    /// 完了するまで繰り返す通知は、毎日・曜日のトリガーの代わりに催促の日時を登録する（最初の催促が設定した時刻）
    ///
    /// - Parameter now: 1 回だけの通知の日時が過ぎたかどうか、催促のどの日時から登録するかの基準
    func plan(for setting: NotificationSetting, now: Date = .now) -> NotificationTriggerPlan {
        switch setting.kind {
        case .interval:
            plan(startDate: setting.startDate, interval: setting.interval)
        case .timeOfDay where setting.completionCycle != nil:
            plan(
                schedule: setting.timeOfDaySchedule,
                rule: setting.untilDoneRule,
                completedPeriodStarts: setting.completions.map(\.periodStart),
                now: now
            )
        case .timeOfDay:
            plan(schedule: setting.timeOfDaySchedule, now: now)
        }
    }

    /// 設定の種類に合わせて通知を登録する。登録済みの同じ設定の通知は置き換える
    ///
    /// - Returns: 登録したトリガー
    @discardableResult
    func schedule(_ setting: NotificationSetting, now: Date = .now) async throws -> NotificationTriggerPlan {
        switch setting.kind {
        case .interval:
            try await schedule(id: setting.id, message: setting.message, interval: setting.interval, startDate: setting.startDate)
        case .timeOfDay where setting.completionCycle != nil:
            try await schedule(
                id: setting.id,
                message: setting.message,
                schedule: setting.timeOfDaySchedule,
                rule: setting.untilDoneRule,
                completedPeriodStarts: setting.completions.map(\.periodStart),
                now: now
            )
        case .timeOfDay:
            try await schedule(id: setting.id, message: setting.message, schedule: setting.timeOfDaySchedule, now: now)
        }
    }
}
