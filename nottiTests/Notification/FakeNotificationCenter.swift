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
    private var statusStorage: UNAuthorizationStatus
    private var requestedOptionsStorage: [UNAuthorizationOptions] = []
    private var categoriesStorage: Set<UNNotificationCategory> = []
    private let grantsAuthorization: Bool

    /// - Parameters:
    ///   - status: 許可状態の初期値
    ///   - grantsAuthorization: 許可を求められたときにユーザーが許可するかどうか
    init(
        pending: [UNNotificationRequest] = [],
        status: UNAuthorizationStatus = .authorized,
        grantsAuthorization: Bool = true
    ) {
        storage = Dictionary(uniqueKeysWithValues: pending.map { ($0.identifier, $0) })
        statusStorage = status
        self.grantsAuthorization = grantsAuthorization
    }

    /// 保留中の通知（identifier → request）
    var pending: [String: UNNotificationRequest] {
        lock.withLock { storage }
    }

    /// `removePendingNotificationRequests` に渡された identifier（呼ばれた順）
    var removedIdentifiers: [[String]] {
        lock.withLock { removedIdentifiersStorage }
    }

    /// `requestAuthorization` に渡された options（呼ばれた順）
    var requestedOptions: [UNAuthorizationOptions] {
        lock.withLock { requestedOptionsStorage }
    }

    /// `setNotificationCategories` で登録したカテゴリ
    var categories: Set<UNNotificationCategory> {
        lock.withLock { categoriesStorage }
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

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        lock.withLock {
            requestedOptionsStorage.append(options)
            statusStorage = grantsAuthorization ? .authorized : .denied
            return grantsAuthorization
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        lock.withLock { statusStorage }
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        lock.withLock { categoriesStorage = categories }
    }
}

extension NotificationScheduler {
    /// テスト用の暦。東京時間で固定する
    static let testCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    /// 偽の通知センターを使うスケジューラ。おやすみ時間は保存済みの値に左右されないよう引数で固定する
    static func fake(_ center: FakeNotificationCenter, quietHours: QuietHours = .default) -> Self {
        Self(center: center, quietHours: { quietHours }, calendar: testCalendar)
    }
}
