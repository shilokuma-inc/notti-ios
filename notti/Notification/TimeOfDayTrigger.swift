//
//  TimeOfDayTrigger.swift
//  notti
//

import Foundation

/// 時刻指定の通知のトリガー 1 本ぶん。1 本につき `UNCalendarNotificationTrigger` を 1 本登録する
nonisolated enum TimeOfDayTrigger: Hashable, Sendable {
    /// 毎日この時刻に鳴らす
    case daily(TimeOfDay)
    /// 毎週この曜日のこの時刻に鳴らす
    case weekly(Weekday, TimeOfDay)
    /// この日時（年・月・日・時・分）に 1 回だけ鳴らす
    case once(DateComponents)

    /// `UNCalendarNotificationTrigger(dateMatching:repeats:)` に渡す日時。タイムゾーンは持たせず、端末のローカル時刻で解釈させる
    var dateComponents: DateComponents {
        switch self {
        case let .daily(time):
            DateComponents(hour: time.hour, minute: time.minute)
        case let .weekly(weekday, time):
            DateComponents(hour: time.hour, minute: time.minute, weekday: weekday.rawValue)
        case let .once(components):
            components
        }
    }

    /// `date` に 1 回だけ鳴らすトリガー。分未満は切り捨て、その時刻が `now` 以前なら鳴らせないので nil
    ///
    /// - Parameter calendar: 日時を年・月・日・時・分に分ける暦。タイムゾーンもここから取る
    static func once(at date: Date, now: Date, calendar: Calendar) -> Self? {
        let components = calendar.dateComponents([.era, .year, .month, .day, .hour, .minute], from: date)
        guard let fireDate = calendar.date(from: components), fireDate > now else {
            return nil
        }
        return .once(components)
    }

    /// 繰り返すかどうか
    var repeats: Bool {
        switch self {
        case .daily, .weekly:
            true
        case .once:
            false
        }
    }
}
