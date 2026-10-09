//
//  NotificationScheduler.swift
//  notti
//

import Foundation
import UserNotifications

/// 通知設定 1 件ぶんの通知を、通知センターへ登録・置き換え・削除する
///
/// identifier は設定の ID（`<id>`）を元にする。1 件の設定から複数の通知を作るときは `<id>-<接尾辞>` にし、`remove(id:)` でまとめて消す。
/// - 間隔（おやすみ時間なし）: `<id>`
/// - 間隔（おやすみ時間あり）: `<id>-<hour>`（hour は 0〜23）
/// - 時刻指定: 毎日 `<id>-daily` / 曜日 `<id>-weekday<1〜7>` / 1 回だけ `<id>-once`
/// - 完了するまで繰り返す催促: `<id>-nag<yyyyMMddHHmm>`（鳴らす日時ごと。日付を指定した 1 回きり）
/// - スヌーズ: `<id>-snooze`（通知のアクションから予約する。設定の登録し直しでは消さない）
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

    /// 時刻指定の通知のトリガーを決める。おやすみ時間は適用しない
    ///
    /// - Parameter now: 1 回だけの通知の日時が過ぎたかどうかの基準
    func plan(schedule: TimeOfDaySchedule, now: Date = .now) -> NotificationTriggerPlan {
        NotificationTriggerPlan.make(schedule: schedule, now: now, calendar: calendar)
    }

    /// 「完了するまで繰り返す」通知の催促のトリガーを決める
    ///
    /// - Parameters:
    ///   - completedPeriodStarts: 完了の記録の期間の始まり。完了済みの期間には催促しない
    ///   - now: これより後の日時だけ登録する
    func plan(
        schedule: TimeOfDaySchedule,
        rule: UntilDoneRule,
        completedPeriodStarts: [Date],
        now: Date = .now
    ) -> NotificationTriggerPlan {
        NotificationTriggerPlan.make(
            schedule: schedule,
            rule: rule,
            completedPeriodStarts: completedPeriodStarts,
            now: now,
            calendar: calendar
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
        let plan = plan(startDate: startDate, interval: interval)
        try await register(id: id, message: message, plan: plan)
        return plan
    }

    /// `message` を `schedule` の時刻に通知する（毎日・曜日・1 回だけ）。登録済みの同じ `id` の通知は置き換える
    ///
    /// 1 回だけの日時が過ぎていれば、登録済みの通知を消すだけで何も登録しない
    ///
    /// - Returns: 登録したトリガー
    @discardableResult
    func schedule(id: UUID, message: String, schedule: TimeOfDaySchedule, now: Date = .now) async throws -> NotificationTriggerPlan {
        let plan = plan(schedule: schedule, now: now)
        try await register(id: id, message: message, plan: plan)
        return plan
    }

    /// 「完了するまで繰り返す」通知の催促を登録する。登録済みの同じ `id` の通知（毎日・曜日のトリガーも）は置き換える
    ///
    /// - Returns: 登録したトリガー
    @discardableResult
    func schedule(
        id: UUID,
        message: String,
        schedule: TimeOfDaySchedule,
        rule: UntilDoneRule,
        completedPeriodStarts: [Date],
        now: Date = .now
    ) async throws -> NotificationTriggerPlan {
        let plan = plan(schedule: schedule, rule: rule, completedPeriodStarts: completedPeriodStarts, now: now)
        try await register(id: id, message: message, plan: plan)
        return plan
    }

    /// 登録済みの同じ `id` の通知を消してから、`plan` どおりに登録する。スヌーズで予約した通知は残す
    private func register(id: UUID, message: String, plan: NotificationTriggerPlan) async throws {
        await remove(id: id, keepingSnooze: true)

        let content = Self.content(id: id, message: message)
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
        case let .timeOfDay(triggers):
            for trigger in triggers {
                let calendarTrigger = UNCalendarNotificationTrigger(dateMatching: trigger.dateComponents, repeats: trigger.repeats)
                let identifier = Self.identifier(for: id, trigger: trigger)
                try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: calendarTrigger))
            }
        case let .untilDone(dates):
            for components in dates {
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let identifier = Self.identifier(for: id, nagAt: components)
                try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
            }
        }
    }

    /// `id` の通知を止める。派生させた identifier（`<id>-<hour>` や時刻指定の `<id>-daily` など）の通知も消す
    ///
    /// 止めるとき（`keepingSnooze` が false）は、通知センターに表示中の通知も消す。
    /// OFF・削除した設定の通知からスヌーズを選んで、もう一度鳴らないようにするため。
    /// - Parameter keepingSnooze: スヌーズで予約した通知（`<id>-snooze`）と表示中の通知を残す。登録し直すときに使う
    func remove(id: UUID, keepingSnooze: Bool = false) async {
        let identifier = Self.identifier(for: id)
        let derivedPrefix = identifier + "-"
        let pending = await center.pendingNotificationRequests()
        let derived = pending.map(\.identifier).filter { $0.hasPrefix(derivedPrefix) && !(keepingSnooze && Self.isSnooze($0)) }
        await center.removePendingNotificationRequests(withIdentifiers: [identifier] + derived)
        guard !keepingSnooze else {
            return
        }
        let delivered = await center.deliveredNotificationIdentifiers().filter { $0 == identifier || $0.hasPrefix(derivedPrefix) }
        if !delivered.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: delivered)
        }
    }

    /// 通知センターに登録済みの通知（identifier → 内容）
    func pendingNotifications() async -> [String: PendingNotification] {
        let requests = await center.pendingNotificationRequests()
        return Dictionary(requests.map { request in
            let intervalTrigger = request.trigger as? UNTimeIntervalNotificationTrigger
            let calendarTrigger = request.trigger as? UNCalendarNotificationTrigger
            let components = calendarTrigger?.dateComponents
            let notification = PendingNotification(
                body: request.content.body,
                timeInterval: intervalTrigger?.timeInterval,
                hour: components?.hour,
                minute: components?.minute,
                weekday: components?.weekday,
                year: components?.year,
                month: components?.month,
                day: components?.day,
                repeats: request.trigger?.repeats ?? false,
                categoryIdentifier: request.content.categoryIdentifier
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

    /// 時刻指定の通知の、トリガーごとの identifier
    static func identifier(for id: UUID, trigger: TimeOfDayTrigger) -> String {
        switch trigger {
        case .daily:
            "\(identifier(for: id))-daily"
        case let .weekly(weekday, _):
            "\(identifier(for: id))-weekday\(weekday.rawValue)"
        case .once:
            "\(identifier(for: id))-once"
        }
    }

    /// 「完了するまで繰り返す」通知の催促の、鳴らす日時ごとの identifier（`<id>-nag<yyyyMMddHHmm>`）
    static func identifier(for id: UUID, nagAt components: DateComponents) -> String {
        let fields = [components.year, components.month, components.day, components.hour, components.minute].map { $0 ?? 0 }
        let stamp = String(format: "%04d%02d%02d%02d%02d", fields[0], fields[1], fields[2], fields[3], fields[4])
        return "\(identifier(for: id))-nag\(stamp)"
    }

    /// スヌーズで予約する通知の identifier
    static func snoozeIdentifier(for id: UUID) -> String {
        "\(identifier(for: id))-snooze"
    }

    /// スヌーズで予約した通知の identifier かどうか
    static func isSnooze(_ identifier: String) -> Bool {
        identifier.hasSuffix("-snooze")
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
        case let .timeOfDay(triggers):
            return Dictionary(uniqueKeysWithValues: triggers.map { trigger in
                let components = trigger.dateComponents
                let notification = PendingNotification(
                    body: message,
                    hour: components.hour,
                    minute: components.minute,
                    weekday: components.weekday,
                    year: components.year,
                    month: components.month,
                    day: components.day,
                    repeats: trigger.repeats
                )
                return (identifier(for: id, trigger: trigger), notification)
            })
        case let .untilDone(dates):
            return Dictionary(dates.map { components in
                let notification = PendingNotification(
                    body: message,
                    hour: components.hour,
                    minute: components.minute,
                    year: components.year,
                    month: components.month,
                    day: components.day,
                    repeats: false
                )
                return (identifier(for: id, nagAt: components), notification)
            }) { first, _ in first }
        }
    }
}

// MARK: - スヌーズ

nonisolated extension NotificationScheduler {
    /// 登録する通知に付けるカテゴリ。スヌーズのアクションを持つ
    static let categoryIdentifier = "notti.reminder"
    /// スヌーズのアクション
    static let snoozeActionIdentifier = "notti.snooze"
    /// スヌーズしてから、もう一度鳴らすまでの時間（10 分）
    static let snoozeInterval: TimeInterval = 600
    /// 通知の userInfo に入れる設定の ID のキー。スヌーズの identifier を作るのに使う
    static let settingIDKey = "settingID"

    /// 通知のカテゴリ。アクションは「10 分後にもう一度」の 1 つ
    static var categories: Set<UNNotificationCategory> {
        let snooze = UNNotificationAction(identifier: snoozeActionIdentifier, title: "10 分後にもう一度")
        return [UNNotificationCategory(identifier: categoryIdentifier, actions: [snooze], intentIdentifiers: [])]
    }

    /// 通知のカテゴリを通知センターに登録する。アプリ起動時に呼ぶ
    func registerCategories() {
        center.setNotificationCategories(Self.categories)
    }

    /// `id` の通知を `interval` 後にもう一度鳴らす。スヌーズで予約済みの通知は置き換える
    func snooze(id: UUID, message: String, after interval: TimeInterval = snoozeInterval) async throws {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let content = Self.content(id: id, message: message)
        try await center.add(UNNotificationRequest(identifier: Self.snoozeIdentifier(for: id), content: content, trigger: trigger))
    }

    /// 通知の内容。スヌーズできるようカテゴリと設定の ID を付ける
    fileprivate static func content(id: UUID, message: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.body = message
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = [settingIDKey: id.uuidString]
        return content
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
    /// `UNCalendarNotificationTrigger` の曜日（1 = 日曜）。曜日を指定しないトリガーなら nil
    var weekday: Int?
    /// `UNCalendarNotificationTrigger` の年・月・日。日付を指定しない（繰り返す）トリガーなら nil
    var year: Int?
    var month: Int?
    var day: Int?
    var repeats: Bool
    /// 通知のカテゴリ。スヌーズのアクションを付ける前に登録した通知は空文字になり、整合で登録し直す
    var categoryIdentifier = NotificationScheduler.categoryIdentifier
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
        case let .untilDone(dates):
            dates.count
        }
    }
}
