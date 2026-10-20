//
//  LinkOpener.swift
//  notti
//

import Foundation
import Observation
import OSLog
import UIKit

/// 紐づけたアプリの URL を開く。開けなかったら、のっちの画面で知らせるために `isShowingFailure` を立てる
///
/// UIKit の `UIApplication` に触るのはこの型の中だけにする。テストでは `openURL` を差し替え、Simulator の外のアプリが開くかには頼らない。
/// 通知のアクション（`NotificationDelegate`）と一覧の画面で同じものを使い、`NottiApp` が保持する
@MainActor
@Observable
final class LinkOpener {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "notti", category: "Notification")

    /// 開けなかったことを画面で知らせているか。知らせを閉じたら false に戻す
    var isShowingFailure = false

    /// URL を開き、開けたかどうかを返す
    @ObservationIgnored private let openURL: @MainActor (URL) async -> Bool

    /// - Parameter openURL: URL を開く処理。既定は `UIApplication.shared.open(_:options:)`
    init(openURL: @escaping @MainActor (URL) async -> Bool = LinkOpener.openWithSystem) {
        self.openURL = openURL
    }

    /// `url` を開く。開けなかったら（アプリが入っていない・URL が違うなど）知らせる
    ///
    /// - Returns: 開けたかどうか
    @discardableResult
    func open(_ url: URL) async -> Bool {
        let isOpened = await openURL(url)
        if !isOpened {
            Self.logger.notice("紐づけたアプリを開けません: \(url.absoluteString, privacy: .private)")
            isShowingFailure = true
        }
        return isOpened
    }

    /// OS に URL を開かせる。Universal Link は対応するアプリが入っていればアプリで、無ければ Safari で開く
    static func openWithSystem(_ url: URL) async -> Bool {
        await UIApplication.shared.open(url, options: [:])
    }
}
