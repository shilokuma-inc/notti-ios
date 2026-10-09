//
//  NotificationSetting.swift
//  notti
//

import Foundation
import SwiftData

/// ユーザーが登録した通知 1 件ぶんの設定
///
/// 時刻指定の項目（`kindRawValue` 以降）は後から足したもの。既存の保存データを間隔の通知として読めるよう、
/// すべて既定値を持たせて軽量マイグレーションで済ませている。「完了するまで繰り返す」の項目（`repeatsUntilDone` 以降）も同じ
@Model
final class NotificationSetting {
    /// 通知の identifier の元にする安定した ID
    @Attribute(.unique) var id: UUID
    /// 通知の文言
    var message: String
    /// 繰り返す間隔（時間）。1 または 24。種類が間隔のときに使う
    var intervalHours: Int
    /// 通知を鳴らすかどうか
    var isEnabled: Bool
    /// 起点日時。ここから `intervalHours` 時間ごとに鳴らす（ON にした時刻で更新する）。種類が間隔のときに使う
    var startDate: Date
    /// 登録した日時。一覧の並び順に使う
    var createdAt: Date
    /// 通知の種類（`NotificationKind` の raw 値）
    var kindRawValue: String = NotificationKind.interval.rawValue
    /// 鳴らす時刻の時（0〜23）。種類が時刻指定で、繰り返しが毎日・曜日のときに使う
    var hour: Int = 9
    /// 鳴らす時刻の分（0〜59）。種類が時刻指定で、繰り返しが毎日・曜日のときに使う
    var minute: Int = 0
    /// 時刻指定の繰り返し方（`NotificationRepeat` の raw 値）
    var repeatRawValue: String = NotificationRepeat.daily.rawValue
    /// 繰り返しが曜日のときに鳴らす曜日（`Weekday.bit` の和）
    var weekdayMask: Int = 0
    /// 繰り返しが 1 回だけのときに鳴らす日時
    var onceDate: Date?
    /// 完了するまで繰り返すかどうか。種類が時刻指定で、繰り返しが毎日・曜日のときに使う
    var repeatsUntilDone: Bool = false
    /// 完了するまで催促する間隔（分）。`NagInterval` の raw 値
    var nagIntervalMinutes: Int = NagInterval.default.rawValue
    /// 日の区切りの時（0〜23）
    var dayBoundaryHour: Int = 0
    /// 日の区切りの分（0〜59）
    var dayBoundaryMinute: Int = 0
    /// 週が始まる曜日（`Weekday` の raw 値）
    var weekStartWeekdayRawValue: Int = Weekday.monday.rawValue
    /// 週が始まる時刻の時（0〜23）
    var weekStartHour: Int = 0
    /// 週が始まる時刻の分（0〜59）
    var weekStartMinute: Int = 0
    /// 完了の記録。通知を削除したら一緒に消す
    @Relationship(deleteRule: .cascade, inverse: \CompletionRecord.setting)
    var completions: [CompletionRecord] = []

    init(
        id: UUID = UUID(),
        message: String,
        intervalHours: Int = 1,
        isEnabled: Bool = true,
        startDate: Date = .now,
        createdAt: Date = .now,
        kind: NotificationKind = .interval,
        hour: Int = 9,
        minute: Int = 0,
        repeatRule: NotificationRepeat = .daily,
        weekdays: Set<Weekday> = [],
        onceDate: Date? = nil,
        repeatsUntilDone: Bool = false,
        untilDoneRule: UntilDoneRule = UntilDoneRule()
    ) {
        self.id = id
        self.message = message
        self.intervalHours = intervalHours
        self.isEnabled = isEnabled
        self.startDate = startDate
        self.createdAt = createdAt
        self.kindRawValue = kind.rawValue
        self.hour = hour
        self.minute = minute
        self.repeatRawValue = repeatRule.rawValue
        self.weekdayMask = Weekday.mask(of: weekdays)
        self.onceDate = onceDate
        self.repeatsUntilDone = repeatsUntilDone
        self.nagIntervalMinutes = untilDoneRule.interval.minutes
        self.dayBoundaryHour = untilDoneRule.dayBoundary.hour
        self.dayBoundaryMinute = untilDoneRule.dayBoundary.minute
        self.weekStartWeekdayRawValue = untilDoneRule.weekStart.weekday.rawValue
        self.weekStartHour = untilDoneRule.weekStart.time.hour
        self.weekStartMinute = untilDoneRule.weekStart.time.minute
    }

    /// 繰り返す間隔。保存値が選択肢に無い場合は 1 時間として扱う
    var interval: NotificationInterval {
        get { NotificationInterval(rawValue: intervalHours) ?? .oneHour }
        set { intervalHours = newValue.hours }
    }

    /// 通知の種類。保存値が選択肢に無い場合は間隔として扱う
    var kind: NotificationKind {
        get { NotificationKind(rawValue: kindRawValue) ?? .interval }
        set { kindRawValue = newValue.rawValue }
    }

    /// 時刻指定の繰り返し方。保存値が選択肢に無い場合は毎日として扱う
    var repeatRule: NotificationRepeat {
        get { NotificationRepeat(rawValue: repeatRawValue) ?? .daily }
        set { repeatRawValue = newValue.rawValue }
    }

    /// 繰り返しが曜日のときに鳴らす曜日
    var weekdays: Set<Weekday> {
        get { Weekday.set(fromMask: weekdayMask) }
        set { weekdayMask = Weekday.mask(of: newValue) }
    }

    /// 毎日・曜日の通知を鳴らす時刻
    var timeOfDay: TimeOfDay {
        get { TimeOfDay(hour: hour, minute: minute) }
        set {
            hour = newValue.hour
            minute = newValue.minute
        }
    }

    /// 完了するまで催促する間隔。保存値が選択肢に無い場合は既定の間隔として扱う
    var nagInterval: NagInterval {
        get { NagInterval(rawValue: nagIntervalMinutes) ?? .default }
        set { nagIntervalMinutes = newValue.minutes }
    }

    /// 日の区切りの時刻
    var dayBoundary: TimeOfDay {
        get { TimeOfDay(hour: dayBoundaryHour, minute: dayBoundaryMinute) }
        set {
            dayBoundaryHour = newValue.hour
            dayBoundaryMinute = newValue.minute
        }
    }

    /// 週の始まり。保存値の曜日が範囲外なら月曜として扱う
    var weekStart: WeekStart {
        get {
            WeekStart(
                weekday: Weekday(rawValue: weekStartWeekdayRawValue) ?? .monday,
                time: TimeOfDay(hour: weekStartHour, minute: weekStartMinute)
            )
        }
        set {
            weekStartWeekdayRawValue = newValue.weekday.rawValue
            weekStartHour = newValue.time.hour
            weekStartMinute = newValue.time.minute
        }
    }

    /// 催促の決まり（間隔・日の区切り・週の始まり）
    var untilDoneRule: UntilDoneRule {
        get { UntilDoneRule(interval: nagInterval, dayBoundary: dayBoundary, weekStart: weekStart) }
        set {
            nagInterval = newValue.interval
            dayBoundary = newValue.dayBoundary
            weekStart = newValue.weekStart
        }
    }
}
