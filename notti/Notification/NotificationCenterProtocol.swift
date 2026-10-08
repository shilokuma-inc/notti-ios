//
//  NotificationCenterProtocol.swift
//  notti
//

import UserNotifications

/// `NotificationScheduler` などが使う通知センターの操作
///
/// テストでは偽物に差し替えて、実際の通知センター（許可ダイアログ）を叩かずに登録内容を検証する。
///
/// async の要件は `@concurrent` にしている。呼び出し元（nonisolated(nonsending) や MainActor）へ戻るときに、
/// 呼んだ側が必ず元の executor に戻し直すようにするため。
/// `UNUserNotificationCenter` の async メソッド（Objective-C の completion handler から作られたもの）がそのまま要件を満たすと、
/// 通知センターのコールバックのスレッドのまま呼び出し元に戻り、MainActor のはずの処理がメインスレッド以外で動いてしまう。
nonisolated protocol NotificationCenterProtocol: Sendable {
    @concurrent func add(_ request: UNNotificationRequest) async throws
    @concurrent func pendingNotificationRequests() async -> [UNNotificationRequest]
    @concurrent func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async
    @concurrent func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    /// 現在の許可状態。`UNNotificationSettings` は偽物で作れないため、状態だけを返す
    @concurrent func authorizationStatus() async -> UNAuthorizationStatus
    /// 通知のカテゴリ（アクション）を登録する。登録済みのものは置き換わる
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
    /// 通知センターに表示中の（届いた）通知の identifier。`UNNotification` は偽物で作れないため、identifier だけを返す
    @concurrent func deliveredNotificationIdentifiers() async -> [String]
    /// 通知センターに表示中の通知を消す。消した通知からはアクション（スヌーズ）を選べなくなる
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
}

nonisolated extension UNUserNotificationCenter: NotificationCenterProtocol {
    @concurrent
    func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }

    @concurrent
    func deliveredNotificationIdentifiers() async -> [String] {
        await deliveredNotifications().map(\.request.identifier)
    }
}
