//
//  NotificationSettingActions.swift
//  notti
//

import Foundation
import OSLog
import SwiftData

/// 画面での通知設定の操作を、保存内容と通知センターの登録に反映する
///
/// 保存内容はその場で書き換え（画面がすぐ追従するように）、通知センターへの反映は戻り値の `Task` で行う。
struct NotificationSettingActions {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "notti", category: "Notification")

    let scheduler: NotificationScheduler

    /// 通知の ON/OFF を切り替える。ON にした時刻を新しい起点日時にする（Q1「設定した時刻から N 時間ごと」）
    @discardableResult
    func setEnabled(_ isEnabled: Bool, for setting: NotificationSetting, now: Date = .now) -> Task<Void, Never> {
        setting.isEnabled = isEnabled
        if isEnabled {
            setting.startDate = now
        }
        return Task {
            await sync(setting)
        }
    }

    /// 追加・編集画面の入力を保存し、通知を登録し直す
    ///
    /// 編集で文言か間隔が変わった ON の通知は、保存した時刻を新しい起点にする。変更が無ければ登録し直さない。
    ///
    /// - Parameter setting: 編集中の設定。nil なら新しく追加する（追加した通知は ON で、追加した時刻が起点になる）
    /// - Returns: 保存した設定と、通知センターへの反映
    @discardableResult
    func save(
        message: String,
        interval: NotificationInterval,
        to setting: NotificationSetting?,
        in context: ModelContext,
        now: Date = .now
    ) -> (setting: NotificationSetting, task: Task<Void, Never>) {
        let message = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let target: NotificationSetting
        if let setting {
            // 登録し直すと登録した時刻から数え直しになるため、変更が無ければ何もしない
            guard setting.message != message || setting.interval != interval else {
                return (setting, Task {})
            }
            target = setting
            target.message = message
            target.interval = interval
            if target.isEnabled {
                target.startDate = now
            }
        } else {
            target = NotificationSetting(message: message, intervalHours: interval.hours, startDate: now, createdAt: now)
            context.insert(target)
        }
        save(context)
        let task = Task {
            await sync(target)
        }
        return (target, task)
    }

    /// 通知設定を削除し、登録済みの通知も止める
    @discardableResult
    func delete(_ settings: [NotificationSetting], from context: ModelContext) -> Task<Void, Never> {
        let ids = settings.map(\.id)
        for setting in settings {
            context.delete(setting)
        }
        save(context)
        return Task {
            for id in ids {
                await scheduler.remove(id: id)
            }
        }
    }

    /// おやすみ時間を変えたときに、すべての通知を登録し直す
    ///
    /// おやすみ時間が無くなって登録時刻から数え直しになる通知は、起点日時を登録し直した時刻にする。
    /// おやすみ時間がある通知は時計の時刻で鳴るので、起点日時は変えない。
    @discardableResult
    func rescheduleAll(_ settings: [NotificationSetting], in context: ModelContext, now: Date = .now) -> Task<Void, Never> {
        for setting in settings where setting.isEnabled {
            if case .repeatingInterval = scheduler.plan(startDate: setting.startDate, interval: setting.interval) {
                setting.startDate = now
            }
        }
        save(context)
        let count = requestCount(for: settings)
        if count > NotificationScheduler.pendingLimit {
            Self.logger.warning("登録する通知が上限を超えています: \(count) 件")
        }
        return Task {
            for setting in settings {
                await sync(setting)
            }
        }
    }

    /// ON の通知をすべて登録したときの通知の数。`NotificationScheduler.pendingLimit` を超えると一部が鳴らない
    func requestCount(for settings: [NotificationSetting]) -> Int {
        settings
            .filter(\.isEnabled)
            .map { scheduler.plan(startDate: $0.startDate, interval: $0.interval).requestCount }
            .reduce(0, +)
    }

    /// 設定の内容どおりに通知を登録する（OFF なら止める）
    func sync(_ setting: NotificationSetting) async {
        guard setting.isEnabled else {
            await scheduler.remove(id: setting.id)
            return
        }
        do {
            try await scheduler.schedule(id: setting.id, message: setting.message, interval: setting.interval, startDate: setting.startDate)
        } catch {
            Self.logger.error("通知を登録できません: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            Self.logger.error("通知設定を保存できません: \(error.localizedDescription, privacy: .public)")
        }
    }
}
