//
//  FakeNotificationCenter.swift
//  nottiTests
//

import Foundation
@testable import notti
import UserNotifications

/// 保留中の通知を identifier ごとに保持する偽の通知センター
///
/// `UNNotificationRequest` は Sendable ではないため actor にすると隔離境界を越えられない。
/// 本物の通知センターと同じく nonisolated に呼べるよう、状態は NSLock で守って `@unchecked Sendable` にしている。
final class FakeNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: UNNotificationRequest]
    private var removedIdentifiersStorage: [[String]] = []

    init(pending: [UNNotificationRequest] = []) {
        storage = Dictionary(uniqueKeysWithValues: pending.map { ($0.identifier, $0) })
    }

    /// 保留中の通知（identifier → request）
    var pending: [String: UNNotificationRequest] {
        lock.withLock { storage }
    }

    /// `removePendingNotificationRequests` に渡された identifier（呼ばれた順）
    var removedIdentifiers: [[String]] {
        lock.withLock { removedIdentifiersStorage }
    }

    func add(_ request: UNNotificationRequest) async throws {
        lock.withLock { storage[request.identifier] = request }
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        lock.withLock { Array(storage.values) }
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async {
        lock.withLock {
            removedIdentifiersStorage.append(identifiers)
            for identifier in identifiers {
                storage[identifier] = nil
            }
        }
    }
}
