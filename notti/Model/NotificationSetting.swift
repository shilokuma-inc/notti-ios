//
//  NotificationSetting.swift
//  notti
//

import Foundation
import SwiftData

/// ユーザーが登録した通知 1 件ぶんの設定
@Model
final class NotificationSetting {
    /// 通知の identifier の元にする安定した ID
    @Attribute(.unique) var id: UUID
    /// 通知の文言
    var message: String
    /// 繰り返す間隔（時間）。1 または 24
    var intervalHours: Int
    /// 通知を鳴らすかどうか
    var isEnabled: Bool
    /// 起点日時。ここから `intervalHours` 時間ごとに鳴らす（ON にした時刻で更新する）
    var startDate: Date
    /// 登録した日時。一覧の並び順に使う
    var createdAt: Date

    init(
        id: UUID = UUID(),
        message: String,
        intervalHours: Int = 1,
        isEnabled: Bool = true,
        startDate: Date = .now,
        createdAt: Date = .now
    ) {
        self.id = id
        self.message = message
        self.intervalHours = intervalHours
        self.isEnabled = isEnabled
        self.startDate = startDate
        self.createdAt = createdAt
    }
}
