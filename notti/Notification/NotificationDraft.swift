//
//  NotificationDraft.swift
//  notti
//

import Foundation

/// 追加・編集画面で入力する通知の内容。`NotificationSettingActions.save(_:to:in:now:)` に渡す
nonisolated struct NotificationDraft: Equatable, Sendable {
    /// 通知の文言
    var message: String
    /// 通知の種類
    var kind: NotificationKind = .interval
    /// 種類が間隔のときの間隔
    var interval: NotificationInterval = .oneHour
    /// 種類が時刻指定のときの時刻と繰り返し
    var schedule = TimeOfDaySchedule(time: TimeOfDay(hour: 9, minute: 0), repeatRule: .daily)
}

extension NotificationSetting {
    /// 保存済みの内容を、編集画面の入力の形にしたもの
    var draft: NotificationDraft {
        NotificationDraft(message: message, kind: kind, interval: interval, schedule: timeOfDaySchedule)
    }

    /// 入力の内容を書き写す（ON/OFF・起点日時・登録日時は変えない）
    func apply(_ draft: NotificationDraft) {
        message = draft.message
        kind = draft.kind
        interval = draft.interval
        timeOfDay = draft.schedule.time
        repeatRule = draft.schedule.repeatRule
        weekdays = draft.schedule.weekdays
        onceDate = draft.schedule.onceDate
    }
}
