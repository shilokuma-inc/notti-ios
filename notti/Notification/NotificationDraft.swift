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
    /// 完了するまで繰り返すかどうか。時刻指定で、繰り返しが毎日・曜日のときに使う
    var repeatsUntilDone = false
    /// 完了するまで繰り返すときの催促の間隔・日の区切り・週の始まり
    var untilDoneRule = UntilDoneRule()
}

extension NotificationSetting {
    /// 保存済みの内容を、編集画面の入力の形にしたもの
    var draft: NotificationDraft {
        NotificationDraft(
            message: message,
            kind: kind,
            interval: interval,
            schedule: timeOfDaySchedule,
            repeatsUntilDone: repeatsUntilDone,
            untilDoneRule: untilDoneRule
        )
    }

    /// 入力の内容を書き写す（ON/OFF・起点日時・登録日時・完了の記録は変えない）
    func apply(_ draft: NotificationDraft) {
        message = draft.message
        kind = draft.kind
        interval = draft.interval
        timeOfDay = draft.schedule.time
        repeatRule = draft.schedule.repeatRule
        weekdays = draft.schedule.weekdays
        onceDate = draft.schedule.onceDate
        repeatsUntilDone = draft.repeatsUntilDone
        untilDoneRule = draft.untilDoneRule
    }
}

extension NotificationDraft {
    /// 保存できない理由
    nonisolated enum Problem: Equatable, Sendable {
        /// 文言が空
        case emptyMessage
        /// 曜日を選んで繰り返すのに、曜日を 1 つも選んでいない
        case noWeekday
        /// 1 回だけの日時が無いか、過ぎている
        case pastOnceDate
        /// 完了するまで繰り返す毎週の通知で、曜日を 2 つ以上選んでいる（催促を始める曜日は 1 つ）
        case multipleWeekdaysUntilDone
    }

    /// 完了するまで繰り返す設定が効く（時刻指定で、繰り返しが毎日・曜日）
    var isUntilDoneAvailable: Bool {
        kind == .timeOfDay && schedule.repeatRule != .once
    }

    /// 保存できない理由。保存できるなら nil
    ///
    /// - Parameter now: 1 回だけの日時が過ぎたかどうかの基準。分未満は切り捨てて比べる
    func problem(now: Date = .now, calendar: Calendar = .current) -> Problem? {
        if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .emptyMessage
        }
        guard kind == .timeOfDay else {
            return nil
        }
        switch schedule.repeatRule {
        case .daily:
            return nil
        case .weekdays:
            if schedule.weekdays.isEmpty {
                return .noWeekday
            }
            return repeatsUntilDone && schedule.weekdays.count > 1 ? .multipleWeekdaysUntilDone : nil
        case .once:
            let trigger = schedule.onceDate.flatMap { TimeOfDayTrigger.once(at: $0, now: now, calendar: calendar) }
            return trigger == nil ? .pastOnceDate : nil
        }
    }
}
