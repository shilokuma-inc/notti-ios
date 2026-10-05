//
//  NotificationScheduler+Environment.swift
//  notti
//

import SwiftUI

extension EnvironmentValues {
    /// 画面から通知を登録・削除するスケジューラ。プレビューやテストでは差し替えられる
    @Entry var notificationScheduler = NotificationScheduler()
    /// 画面から通知の許可を確認・リクエストする。プレビューやテストでは差し替えられる
    @Entry var notificationAuthorizer = NotificationAuthorizer()
}
