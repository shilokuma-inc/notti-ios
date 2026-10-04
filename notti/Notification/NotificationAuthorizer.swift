//
//  NotificationAuthorizer.swift
//  notti
//

import OSLog
import UserNotifications

/// 通知の許可状態
nonisolated enum NotificationAuthorization: Equatable, Sendable {
    /// まだ尋ねていない
    case notDetermined
    /// 通知を出せる（仮許可・一時的な許可を含む）
    case allowed
    /// 拒否されている。設定アプリで許可してもらう必要がある
    case denied

    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .authorized, .provisional, .ephemeral:
            self = .allowed
        @unknown default:
            self = .allowed
        }
    }
}

/// 通知の許可を確認・リクエストする
nonisolated struct NotificationAuthorizer: Sendable {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "notti", category: "Notification")
    static let options: UNAuthorizationOptions = [.alert, .sound, .badge]

    private let center: any NotificationCenterProtocol

    init(center: any NotificationCenterProtocol = UNUserNotificationCenter.current()) {
        self.center = center
    }

    /// 現在の許可状態
    func authorization() async -> NotificationAuthorization {
        NotificationAuthorization(await center.authorizationStatus())
    }

    /// まだ尋ねていなければ許可を求める。尋ねた後（または尋ねる必要が無いとき）の許可状態を返す
    func requestIfNeeded() async -> NotificationAuthorization {
        let current = await authorization()
        guard current == .notDetermined else {
            return current
        }
        do {
            _ = try await center.requestAuthorization(options: Self.options)
        } catch {
            Self.logger.error("通知の許可を求められません: \(error.localizedDescription, privacy: .public)")
        }
        return await authorization()
    }
}
