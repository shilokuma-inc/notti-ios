//
//  NotificationSetting.swift
//  notti
//

import Foundation
import SwiftData

/// ユーザーが登録した通知 1 件ぶんの設定
///
/// 時刻指定の項目（`kindRawValue` 以降）は後から足したもの。既存の保存データを間隔の通知として読めるよう、
/// すべて既定値を持たせて軽量マイグレーションで済ませている
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
        onceDate: Date? = nil
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
}
