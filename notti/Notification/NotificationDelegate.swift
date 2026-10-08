//
//  NotificationDelegate.swift
//  notti
//

import Foundation
import OSLog
import UserNotifications

/// 通知センターの delegate。アプリを開いている間も通知をバナーで出し、スヌーズのアクションでもう一度通知する
///
/// 通知センターは delegate を弱参照で持つため、`NottiApp` が保持する。
/// delegate メソッドは任意のスレッドから呼ばれるので、型ごと nonisolated にしている（状態は持たない）。
/// ただし通知への応答（`userNotificationCenter(_:didReceive:withCompletionHandler:)`）だけは、メインスレッドで完了を知らせる。
nonisolated final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "notti", category: "Notification")

    /// アプリ表示中に届いた通知の出し方
    static let foregroundPresentationOptions: UNNotificationPresentationOptions = [.banner, .list, .sound]

    private let scheduler: NotificationScheduler

    init(scheduler: NotificationScheduler = NotificationScheduler()) {
        self.scheduler = scheduler
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        Self.foregroundPresentationOptions
    }

    /// 通知をタップしたとき・アクションを選んだときに呼ばれる
    ///
    /// UIKit は `completionHandler` の中でスナップショットを更新し、メインスレッド以外で呼ばれるとアサーションで落ちる。
    /// async 版で実装すると、型が nonisolated のため `completionHandler` が Swift Concurrency のスレッドで呼ばれてしまう。
    /// そのため completion handler 版で実装し、`respond` でメインスレッドから呼ぶ。
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        let content = response.notification.request.content
        respond(
            actionIdentifier: response.actionIdentifier,
            settingID: content.userInfo[NotificationScheduler.settingIDKey] as? String,
            message: content.body,
            completionHandler: completionHandler
        )
    }

    /// 通知のアクションに応えてから、メインスレッドで `completionHandler` を呼ぶ
    func respond(
        actionIdentifier: String,
        settingID: String?,
        message: String,
        completionHandler: @escaping @Sendable () -> Void
    ) {
        Task { @MainActor in
            await handle(actionIdentifier: actionIdentifier, settingID: settingID, message: message)
            completionHandler()
        }
    }

    /// 通知のアクションに応える。スヌーズなら `NotificationScheduler.snoozeInterval` 後にもう一度通知する
    ///
    /// - Parameter settingID: 通知の userInfo に入れた設定の ID
    func handle(actionIdentifier: String, settingID: String?, message: String) async {
        guard actionIdentifier == NotificationScheduler.snoozeActionIdentifier,
              let id = settingID.flatMap(UUID.init(uuidString:)) else {
            return
        }
        do {
            try await scheduler.snooze(id: id, message: message)
        } catch {
            Self.logger.error("スヌーズの通知を登録できません: \(error.localizedDescription, privacy: .public)")
        }
    }
}
