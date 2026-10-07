//
//  NotificationScheduler+Setting.swift
//  notti
//

import Foundation

extension NotificationScheduler {
    /// 設定の種類に合わせて、登録するトリガーを決める（間隔は今のおやすみ時間で、時刻指定はおやすみ時間を適用せずに）
    ///
    /// - Parameter now: 1 回だけの通知の日時が過ぎたかどうかの基準
    func plan(for setting: NotificationSetting, now: Date = .now) -> NotificationTriggerPlan {
        switch setting.kind {
        case .interval:
            plan(startDate: setting.startDate, interval: setting.interval)
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
        case .timeOfDay:
            try await schedule(id: setting.id, message: setting.message, schedule: setting.timeOfDaySchedule, now: now)
        }
    }
}
