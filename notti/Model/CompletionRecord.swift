//
//  CompletionRecord.swift
//  notti
//

import Foundation
import SwiftData

/// 「完了するまで繰り返す」通知を完了した記録。完了した期間（日・週）ごとに 1 件
///
/// 履歴の表示はしないが、期間が完了済みかどうかの判定に使い、記録そのものも残しておく
@Model
final class CompletionRecord {
    /// 完了した期間の始まり（日の区切り・週の始まりの日時）
    var periodStart: Date
    /// 完了にした日時
    var completedAt: Date
    /// 完了した通知。通知を削除すると記録も一緒に消える（`NotificationSetting.completions` の削除ルール）
    var setting: NotificationSetting?

    init(periodStart: Date, completedAt: Date, setting: NotificationSetting? = nil) {
        self.periodStart = periodStart
        self.completedAt = completedAt
        self.setting = setting
    }
}
