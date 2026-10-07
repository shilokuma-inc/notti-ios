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

    /// - ON の設定で、未登録か内容（文言・トリガー）が食い違うもの → 登録し直す
    ///   （おやすみ時間が無く登録時刻から数え直しになる場合は、起点日時も登録し直した時刻にする）
    /// - ON の設定で、内容が一致するもの → そのまま（登録し直すと起点から数え直しになるため）
    /// - それ以外の登録済みの通知（OFF の設定・削除済みの設定・おやすみ時間の変更で不要になった時刻のもの・
    ///   時刻指定の通知で選ばなくなった曜日のもの） → 消す
    ///
    /// 時刻指定の通知も同じ手順で突き合わせる。1 回だけの通知は、日時を過ぎていれば期待する通知が無い
    /// （届いた後は OS が保留から外すので、登録し直さない）
    func reconcile(in context: ModelContext, now: Date = .now) async {
        let settings: [NotificationSetting]
        do {
            settings = try context.fetch(FetchDescriptor<NotificationSetting>())
        } catch {
            Self.logger.error("通知設定を読み込めません: \(error.localizedDescription, privacy: .public)")
            return
        }

        let pending = await scheduler.pendingNotifications()
        var expectedIdentifiers = Set<String>()
        var needsSave = false
        for setting in settings where setting.isEnabled {
            let plan = scheduler.plan(for: setting, now: now)
            let expected = NotificationScheduler.expectedNotifications(id: setting.id, message: setting.message, plan: plan)
            expectedIdentifiers.formUnion(expected.keys)
            let identifier = NotificationScheduler.identifier(for: setting.id)
            let actual = pending.filter { $0.key == identifier || $0.key.hasPrefix(identifier + "-") }
            if actual == expected {
                continue
            }
            if case .repeatingInterval = plan {
                setting.startDate = now
                needsSave = true
            }
            do {
                try await scheduler.schedule(setting, now: now)
            } catch {
                Self.logger.error("通知を登録できません: \(error.localizedDescription, privacy: .public)")
            }
        }
        let stale = Set(pending.keys).subtracting(expectedIdentifiers)
        if !stale.isEmpty {
            await scheduler.remove(identifiers: stale.sorted())
        }
        if needsSave {
            save(context)
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
