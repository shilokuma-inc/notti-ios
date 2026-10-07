//
//  NotificationTriggerPlan.swift
//  notti
//

import Foundation

/// 通知 1 件ぶんを、どのトリガーで登録するか
nonisolated enum NotificationTriggerPlan: Equatable, Sendable {
    /// 登録した時刻から、この秒数ごとに繰り返す 1 本（`UNTimeIntervalNotificationTrigger`）
    case repeatingInterval(TimeInterval)
    /// 毎日これらの時刻に鳴らす。時刻ごとに 1 本（`UNCalendarNotificationTrigger`）。空なら一度も鳴らない
    case dailyTimes([TimeOfDay])
    /// 時刻指定の通知。トリガーごとに 1 本（`UNCalendarNotificationTrigger`）。空なら一度も鳴らない（1 回だけの日時を過ぎたなど）
    case timeOfDay([TimeOfDayTrigger])

    /// おやすみ時間のせいで一度も鳴らない（24 時間間隔の起点がおやすみ時間に入っているなど）。
    /// 時刻指定の通知はおやすみ時間を適用しないので、ここには含めない
    var isSilent: Bool {
        self == .dailyTimes([])
    }

    /// 起点日時・間隔・おやすみ時間から、登録するトリガーを決める
    ///
    /// - おやすみ時間が無い（無効、または開始 = 終了）: 間隔の繰り返し 1 本
    /// - おやすみ時間がある: 「起点の時刻 + k×間隔」（起点の分を保つ）のうち、おやすみ時間に入らない時刻。
    ///   1 時間間隔なら最大 24 本、24 時間間隔なら 0〜1 本。間隔は 24 時間の約数を前提にしている
    ///
    /// - Parameters:
    ///   - calendar: 時刻の計算に使う暦
    ///   - timeZone: 起点日時をどの地域の時刻として読むか。`calendar` のタイムゾーンを上書きする
    static func make(
        startDate: Date,
        interval: NotificationInterval,
        quietHours: QuietHours,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> Self {
        guard quietHours.isActive else {
            return .repeatingInterval(interval.timeInterval)
        }
        var calendar = calendar
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: startDate)
        let startHour = components.hour ?? 0
        let minute = components.minute ?? 0
        let hours = Set(stride(from: 0, to: 24, by: interval.hours).map { (startHour + $0) % 24 })
        let times = hours
            .map { TimeOfDay(hour: $0, minute: minute) }
            .filter { !quietHours.contains($0) }
            .sorted()
        return .dailyTimes(times)
    }

    /// 時刻指定の通知の時刻と繰り返し方から、登録するトリガーを決める
    ///
    /// - 毎日: その時刻に繰り返す 1 本
    /// - 曜日: 選んだ曜日ごとに 1 本（最大 7 本）。曜日が無ければ 0 本
    /// - 1 回だけ: `once` の 1 本。日時が無い・過ぎている（`once` が nil）なら 0 本
    ///
    /// おやすみ時間は適用しない（ユーザーが時刻を明示しているため）
    ///
    /// - Parameter once: 1 回だけの通知のトリガー（`TimeOfDayTrigger.once(at:now:calendar:)`）
    static func make(timeOfDay: TimeOfDay, repeatRule: NotificationRepeat, weekdays: Set<Weekday>, once: TimeOfDayTrigger?) -> Self {
        switch repeatRule {
        case .daily:
            .timeOfDay([.daily(timeOfDay)])
        case .weekdays:
            .timeOfDay(weekdays.sorted().map { .weekly($0, timeOfDay) })
        case .once:
            .timeOfDay(once.map { [$0] } ?? [])
        }
    }
}
