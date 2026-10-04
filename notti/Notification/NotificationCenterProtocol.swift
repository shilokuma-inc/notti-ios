//
//  NotificationCenterProtocol.swift
//  notti
//

import UserNotifications

/// `NotificationScheduler` が使う通知センターの操作
///
/// テストでは偽物に差し替えて、実際の通知センター（許可ダイアログ）を叩かずに登録内容を検証する。
nonisolated protocol NotificationCenterProtocol: Sendable {
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async
}

nonisolated extension UNUserNotificationCenter: NotificationCenterProtocol {}
