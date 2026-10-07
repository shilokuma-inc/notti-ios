//
//  NotificationSetting+Label.swift
//  notti
//

import Foundation

extension NotificationSetting {
    /// 一覧に出す、いつ鳴らすかの表記（例: 「1 時間ごと」「毎日 9:00」「毎週 月・金 21:30」「10月25日 9:30 に 1 回」）
    ///
    /// - Parameter now: 1 回だけの日時に年を添えるかどうかの基準（今年でなければ年を出す）
    func scheduleLabel(now: Date = .now, calendar: Calendar = .current) -> String {
        switch kind {
        case .interval:
            return interval.label
        case .timeOfDay:
            break
        }
        let time = Self.label(of: timeOfDay)
        switch repeatRule {
        case .daily:
            return "毎日 \(time)"
        case .weekdays:
            if weekdays.count == Weekday.allCases.count {
                return "毎日 \(time)"
            }
            let days = weekdays.sorted().map(\.shortLabel).joined(separator: "・")
            return "毎週 \(days) \(time)"
        case .once:
            guard let onceDate else {
                return "1 回だけ（日時なし）"
            }
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: onceDate)
            let year = components.year == calendar.component(.year, from: now) ? "" : "\(components.year ?? 0)年"
            let time = Self.label(of: TimeOfDay(hour: components.hour ?? 0, minute: components.minute ?? 0))
            return "\(year)\(components.month ?? 0)月\(components.day ?? 0)日 \(time) に 1 回"
        }
    }

    /// ON の 1 回だけの通知で、日時が無いか過ぎている（もう鳴らない）
    ///
    /// - Parameter now: 日時が過ぎたかどうかの基準。分未満は切り捨てて比べる
    func isOnceExpired(now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard isEnabled, kind == .timeOfDay, repeatRule == .once else {
            return false
        }
        return onceDate.flatMap { TimeOfDayTrigger.once(at: $0, now: now, calendar: calendar) } == nil
    }

    private static func label(of time: TimeOfDay) -> String {
        String(format: "%d:%02d", time.hour, time.minute)
    }
}
