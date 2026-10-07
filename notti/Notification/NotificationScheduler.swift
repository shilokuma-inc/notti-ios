//
//  NotificationScheduler.swift
//  notti
//

import Foundation
import UserNotifications

/// 通知設定 1 件ぶんの繰り返し通知を、通知センターへ登録・置き換え・削除する
nonisolated struct NotificationScheduler: Sendable {
    /// 通知センターに登録しておける通知の上限。超えた分は OS に破棄される
    static let pendingLimit = 64

    private let center: any NotificationCenterProtocol
    private let quietHours: @Sendable () -> QuietHours
    private let calendar: Calendar

    /// - Parameters:
    ///   - quietHours: 登録時に参照するおやすみ時間。既定は保存済みの値
    ///   - calendar: 鳴らす時刻の計算に使う暦（タイムゾーンもここから取る）
    init(
        center: any NotificationCenterProtocol = UNUserNotificationCenter.current(),
        quietHours: @escaping @Sendable () -> QuietHours = { QuietHours.load(from: .standard) },
        calendar: Calendar = .current
    ) {
        self.center = center
        self.quietHours = quietHours
        self.calendar = calendar
    }

    /// 起点日時と間隔から、今のおやすみ時間で登録するトリガーを決める
    func plan(startDate: Date, interval: NotificationInterval) -> NotificationTriggerPlan {
        NotificationTriggerPlan.make(
            startDate: startDate,
            interval: interval,
            quietHours: quietHours(),
            calendar: calendar,
            timeZone: calendar.timeZone
        )
    }

    /// `message` を `startDate` から `interval` ごとに繰り返し通知する。登録済みの同じ `id` の通知は置き換える
    ///
    /// - おやすみ時間が無ければ、登録した時刻から `interval` ごと（14:23 に登録して 1 時間なら 15:23, 16:23…）
    /// - おやすみ時間があれば、起点の時刻から `interval` ごとの時刻のうち、おやすみ時間外の時刻に毎日鳴らす
    ///
    /// - Returns: 登録したトリガー
    @discardableResult
    func schedule(id: UUID, message: String, interval: NotificationInterval, startDate: Date) async throws -> NotificationTriggerPlan {
        await remove(id: id)

        let content = UNMutableNotificationContent()
        content.body = message
        content.sound = .default
        let plan = plan(startDate: startDate, interval: interval)
        switch plan {
        case let .repeatingInterval(timeInterval):
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: true)
            try await center.add(UNNotificationRequest(identifier: Self.identifier(for: id), content: content, trigger: trigger))
        case let .dailyTimes(times):
            for time in times {
                let components = DateComponents(hour: time.hour, minute: time.minute)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let identifier = Self.identifier(for: id, hour: time.hour)
                try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
            }
        case .timeOfDay:
            // `plan(startDate:interval:)` からは作られない。時刻指定の通知の登録は別途スケジューラに足す
            break
        }
        return plan
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
            let intervalTrigger = request.trigger as? UNTimeIntervalNotificationTrigger
            let calendarTrigger = request.trigger as? UNCalendarNotificationTrigger
            let notification = PendingNotification(
                body: request.content.body,
                timeInterval: intervalTrigger?.timeInterval,
                hour: calendarTrigger?.dateComponents.hour,
                minute: calendarTrigger?.dateComponents.minute,
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

    /// おやすみ時間があるときの、鳴らす時（hour）ごとの identifier
    static func identifier(for id: UUID, hour: Int) -> String {
        "\(identifier(for: id))-\(hour)"
    }

    /// `plan` どおりに登録したときの通知（identifier → 内容）。登録済みの通知と食い違っていないかを調べるのに使う
    static func expectedNotifications(id: UUID, message: String, plan: NotificationTriggerPlan) -> [String: PendingNotification] {
        switch plan {
        case let .repeatingInterval(timeInterval):
            return [identifier(for: id): PendingNotification(body: message, timeInterval: timeInterval, repeats: true)]
        case let .dailyTimes(times):
            return Dictionary(uniqueKeysWithValues: times.map { time in
                let notification = PendingNotification(body: message, hour: time.hour, minute: time.minute, repeats: true)
                return (identifier(for: id, hour: time.hour), notification)
            })
        case .timeOfDay:
            // 時刻指定の通知の identifier は、スケジューラが時刻指定の通知を登録するようになってから決める
            return [:]
        }
    }
}

/// 通知センターに登録済みの通知 1 件の内容。保存済みの設定と食い違っていないかを調べるのに使う
nonisolated struct PendingNotification: Equatable, Sendable {
    var body: String
    /// `UNTimeIntervalNotificationTrigger` の間隔。ほかのトリガーなら nil
    var timeInterval: TimeInterval?
    /// `UNCalendarNotificationTrigger` の時・分。ほかのトリガーなら nil
    var hour: Int?
    var minute: Int?
    var repeats: Bool
}

nonisolated extension NotificationTriggerPlan {
    /// 登録する通知の数
    var requestCount: Int {
        switch self {
        case .repeatingInterval:
            1
        case let .dailyTimes(times):
            times.count
        case let .timeOfDay(triggers):
            triggers.count
        }
    }
}
