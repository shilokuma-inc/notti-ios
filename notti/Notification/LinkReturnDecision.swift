//
//  LinkReturnDecision.swift
//  notti
//

import Foundation

/// 紐づけたアプリからのっちに戻ったときに、完了するまで繰り返す通知が済んだかを聞くかどうか
nonisolated enum LinkReturnDecision: Equatable, Sendable {
    /// 開いていないか、開いた後にまだのっちがバックグラウンドに回っていない（開く直前に前面に出ただけ）。何もしない
    case notReturned
    /// 聞く。`period` は開いた日時を含む完了の期間で、「完了にする」ならこの期間を完了にする
    case ask(period: CompletionPeriod)
    /// 聞かずに開いた日時を消す（期間が替わった・完了済み・OFF・完了するまで繰り返さなくなった）
    case discard
}

extension NotificationSetting {
    /// 紐づけたアプリから戻ったときに、済んだかを聞くかどうか
    ///
    /// - Parameters:
    ///   - backgroundedAt: のっちが最後にバックグラウンドに回った日時（起動してから一度も回っていなければ起動した日時）。
    ///     開いた日時がこれより後なら、開いた後にまだ戻っていない
    ///   - now: 今。開いた日時を含む期間がまだ今の期間かどうかを決める
    ///   - calendar: 完了の期間の計算に使う暦
    func linkReturnDecision(backgroundedAt: Date, now: Date, calendar: Calendar) -> LinkReturnDecision {
        guard let openedAt = linkOpenedAt else {
            return .notReturned
        }
        guard openedAt <= backgroundedAt else {
            return .notReturned
        }
        guard isEnabled, let period = completionPeriod(containing: openedAt, calendar: calendar) else {
            return .discard
        }
        guard period.contains(now), !isCompleted(period) else {
            return .discard
        }
        return .ask(period: period)
    }
}
