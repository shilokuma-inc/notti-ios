//
//  NotificationReconciler.swift
//  notti
//

import Foundation
import OSLog
import SwiftData

/// 保存済みの通知設定と、通知センターに登録済みの通知を突き合わせて整合させる
///
/// アプリ起動時に呼ぶ。OS 側の登録はアプリの再インストールや別経路の変更で保存内容とずれることがあるため。
struct NotificationReconciler {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "notti", category: "Notification")

    let scheduler: NotificationScheduler

    /// - ON の設定で、未登録か内容（文言・間隔）が食い違うもの → 登録し直す（起点日時は登録し直した時刻にする）
    /// - ON の設定で、内容が一致するもの → そのまま（登録し直すと起点から数え直しになるため）
    /// - それ以外の登録済みの通知（OFF の設定・削除済みの設定のもの） → 消す
    func reconcile(in context: ModelContext, now: Date = .now) async {
        let settings: [NotificationSetting]
        do {
            settings = try context.fetch(FetchDescriptor<NotificationSetting>())
        } catch {
            Self.logger.error("通知設定を読み込めません: \(error.localizedDescription, privacy: .public)")
            return
        }

        let pending = await scheduler.pendingNotifications()
        var stale = Set(pending.keys)
        var isRescheduled = false
        for setting in settings where setting.isEnabled {
            let identifier = NotificationScheduler.identifier(for: setting.id)
            stale.remove(identifier)
            if pending[identifier] == expectedNotification(for: setting) {
                continue
            }
            setting.startDate = now
            isRescheduled = true
            do {
                try await scheduler.schedule(id: setting.id, message: setting.message, interval: setting.interval)
            } catch {
                Self.logger.error("通知を登録できません: \(error.localizedDescription, privacy: .public)")
            }
        }
        if !stale.isEmpty {
            await scheduler.remove(identifiers: stale.sorted())
        }
        if isRescheduled {
            save(context)
        }
    }

    private func expectedNotification(for setting: NotificationSetting) -> PendingNotification {
        PendingNotification(body: setting.message, timeInterval: setting.interval.timeInterval, repeats: true)
    }

    private func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            Self.logger.error("通知設定を保存できません: \(error.localizedDescription, privacy: .public)")
        }
    }
}
