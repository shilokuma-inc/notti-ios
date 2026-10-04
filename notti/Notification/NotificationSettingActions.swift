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

    /// 設定の内容どおりに通知を登録する（OFF なら止める）
    func sync(_ setting: NotificationSetting) async {
        guard setting.isEnabled else {
            await scheduler.remove(id: setting.id)
            return
        }
        do {
            try await scheduler.schedule(id: setting.id, message: setting.message, interval: setting.interval)
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
