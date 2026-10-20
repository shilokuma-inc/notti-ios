//
//  NotificationSetting+Label.swift
//  notti
//

import Foundation

extension NotificationSetting {
    /// 一覧に出す、いつ鳴らすかの表記（例: 「1 時間ごと」「毎日 9:00」「毎週 月・金 21:30」「10月25日 9:30 に 1 回」
    /// 「毎月 1・15 日・月末 9:00」）
    ///
    /// 完了するまで繰り返す通知には、催促の間隔を添える（例: 「毎日 21:00・完了まで 30 分ごと」）
    ///
    /// - Parameter now: 1 回だけの日時に年を添えるかどうかの基準（今年でなければ年を出す）
    func scheduleLabel(now: Date = .now, calendar: Calendar = .current) -> String {
        switch kind {
        case .interval:
            return interval.label
        case .timeOfDay:
            break
        }
        let label = timeOfDayLabel(now: now, calendar: calendar)
        return completionCycle == nil ? label : "\(label)・完了まで \(nagInterval.label)"
    }

    /// 完了するまで繰り返す通知の、今の期間（今日・今週・今月）を完了済みか。完了するまで繰り返さない通知は nil
    func isCurrentPeriodCompleted(now: Date = .now, calendar: Calendar = .current) -> Bool? {
        completionPeriod(containing: now, calendar: calendar).map(isCompleted)
    }

    /// 一覧に出す、今の期間の完了の状態（例: 「今日は完了済み」「今週はまだ完了していません」「今月は完了済み」）。完了するまで繰り返さない通知は nil
    func completionStatusLabel(now: Date = .now, calendar: Calendar = .current) -> String? {
        guard let cycle = completionCycle, let isCompleted = isCurrentPeriodCompleted(now: now, calendar: calendar) else {
            return nil
        }
        let period = switch cycle {
        case .daily: "今日"
        case .weekly: "今週"
        case .monthly: "今月"
        }
        return isCompleted ? "\(period)は完了済み" : "\(period)はまだ完了していません"
    }

    /// 時刻指定の通知の、いつ鳴らすかの表記
    private func timeOfDayLabel(now: Date, calendar: Calendar) -> String {
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
        case .monthly:
            guard let days = Self.monthlyDaysLabel(monthDays: monthDays, monthEndOffset: monthEndOffset) else {
                return "毎月（日付なし）"
            }
            return "毎月 \(days) \(time)"
        }
    }

    /// 毎月の鳴らす日の表記（例: 「10・27 日」「月末」「月末の 3 日前」「1・15 日・月末」）。日付は小さい順。日付も月末も無ければ nil
    private static func monthlyDaysLabel(monthDays: Set<Int>, monthEndOffset: Int?) -> String? {
        var parts: [String] = []
        if !monthDays.isEmpty {
            parts.append("\(monthDays.sorted().map(String.init).joined(separator: "・")) 日")
        }
        if let monthEndOffset {
            parts.append(monthEndOffset == 0 ? "月末" : "月末の \(monthEndOffset) 日前")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "・")
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
