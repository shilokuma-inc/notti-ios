//
//  NotificationSetting+Link.swift
//  notti
//

import Foundation

extension NotificationSetting {
    /// 紐づけて開くアプリの URL。紐づけが無いか、保存値が開ける形でなければ nil
    var linkDestination: URL? {
        LinkURL.url(from: linkURL)
    }

    /// 紐づけたアプリがあるか。あれば通知に「アプリを開く」のアクションを付ける
    var hasLink: Bool {
        linkDestination != nil
    }
}
