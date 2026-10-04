//
//  NotificationScheduler.swift
//  notti
//

import Foundation
import UserNotifications

/// 通知設定 1 件ぶんの繰り返し通知を、通知センターへ登録・置き換え・削除する
nonisolated struct NotificationScheduler: Sendable {
    private let center: any NotificationCenterProtocol

    init(center: any NotificationCenterProtocol = UNUserNotificationCenter.current()) {
        self.center = center
    }

    /// `message` を `interval` ごとに繰り返し通知する。登録済みの同じ `id` の通知は置き換える
    ///
    /// 最初の通知は登録した時刻から `interval` 後に鳴る（14:23 に登録して 1 時間なら 15:23, 16:23…）。
    func schedule(id: UUID, message: String, interval: NotificationInterval) async throws {
        await remove(id: id)

        let content = UNMutableNotificationContent()
        content.body = message
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval.timeInterval, repeats: true)
        let request = UNNotificationRequest(identifier: Self.identifier(for: id), content: content, trigger: trigger)
        try await center.add(request)
    }

    /// `id` の通知を止める。おやすみ時間用に派生させた identifier（`<id>-<hour>`）の通知も消す
    func remove(id: UUID) async {
        let identifier = Self.identifier(for: id)
        let derivedPrefix = identifier + "-"
        let pending = await center.pendingNotificationRequests()
        let derived = pending.map(\.identifier).filter { $0.hasPrefix(derivedPrefix) }
        await center.removePendingNotificationRequests(withIdentifiers: [identifier] + derived)
    }

    /// 通知センターに登録済みの通知（identifier → 内容）
    func pendingNotifications() async -> [String: PendingNotification] {
        let requests = await center.pendingNotificationRequests()
        return Dictionary(requests.map { request in
            let trigger = request.trigger as? UNTimeIntervalNotificationTrigger
            let notification = PendingNotification(
                body: request.content.body,
                timeInterval: trigger?.timeInterval,
                repeats: request.trigger?.repeats ?? false
            )
            return (request.identifier, notification)
        }) { first, _ in first }
    }

    /// identifier を指定して通知を止める
    func remove(identifiers: [String]) async {
        await center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// 通知設定ごとの固定の identifier
    static func identifier(for id: UUID) -> String {
        id.uuidString
    }
}

/// 通知センターに登録済みの通知 1 件の内容。保存済みの設定と食い違っていないかを調べるのに使う
nonisolated struct PendingNotification: Equatable, Sendable {
    var body: String
    /// `UNTimeIntervalNotificationTrigger` の間隔。ほかのトリガーなら nil
    var timeInterval: TimeInterval?
    var repeats: Bool
}
