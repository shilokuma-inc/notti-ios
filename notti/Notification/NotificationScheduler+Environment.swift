//
//  NotificationScheduler+Environment.swift
//  notti
//

import SwiftUI

extension EnvironmentValues {
    /// 画面から通知を登録・削除するスケジューラ。プレビューやテストでは差し替えられる
    @Entry var notificationScheduler = NotificationScheduler()
}
