//
//  NotificationCenterProtocol.swift
//  notti
//

import UserNotifications

/// `NotificationScheduler` などが使う通知センターの操作
///
/// テストでは偽物に差し替えて、実際の通知センター（許可ダイアログ）を叩かずに登録内容を検証する。
nonisolated protocol NotificationCenterProtocol: Sendable {
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    /// 現在の許可状態。`UNNotificationSettings` は偽物で作れないため、状態だけを返す
    func authorizationStatus() async -> UNAuthorizationStatus
}

nonisolated extension UNUserNotificationCenter: NotificationCenterProtocol {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }
}
