//
//  NotificationSetting+Completion.swift
//  notti
//

import Foundation

extension NotificationSetting {
    /// 完了するまで繰り返すときの完了の単位。完了するまで繰り返さない通知（間隔・1 回だけ・トグルが OFF）は nil
    var completionCycle: CompletionCycle? {
        guard kind == .timeOfDay, repeatsUntilDone else {
            return nil
        }
        return CompletionCycle(repeatRule)
    }

    /// `date` を含む完了の期間。完了するまで繰り返さない通知は nil
    func completionPeriod(containing date: Date, calendar: Calendar = .current) -> CompletionPeriod? {
        completionCycle.map { CompletionPeriod.containing(date, cycle: $0, rule: untilDoneRule, calendar: calendar) }
    }

    /// `period` を完了済みか
    func isCompleted(_ period: CompletionPeriod) -> Bool {
        period.isCompleted(byPeriodStarts: completions.map(\.periodStart))
    }
}
