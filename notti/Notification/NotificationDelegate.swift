//
//  NotificationDelegate.swift
//  notti
//

import UserNotifications

/// 通知センターの delegate。アプリを開いている間も通知をバナーで出す
///
/// 通知センターは delegate を弱参照で持つため、`NottiApp` が保持する。
/// delegate メソッドは任意のスレッドから呼ばれるので、型ごと nonisolated にしている（状態は持たない）。
nonisolated final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    /// アプリ表示中に届いた通知の出し方
    static let foregroundPresentationOptions: UNNotificationPresentationOptions = [.banner, .list, .sound]

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        Self.foregroundPresentationOptions
    }
}
