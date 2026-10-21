//
//  NotificationDelegate.swift
//  notti
//

import Foundation
import OSLog
import SwiftData
import UserNotifications

/// 通知センターの delegate。アプリを開いている間も通知をバナーで出し、スヌーズのアクションでもう一度通知する。
/// 「完了」のアクションでは、アプリを開かずに完了を保存する。「アプリを開く」のアクションでは、紐づけたアプリの URL を開く
///
/// 通知センターは delegate を弱参照で持つため、`NottiApp` が保持する。
/// delegate メソッドは任意のスレッドから呼ばれるので、型ごと nonisolated にしている（状態は持たない）。
/// ただし通知への応答（`userNotificationCenter(_:didReceive:withCompletionHandler:)`）だけは、メインスレッドで完了を知らせる。
nonisolated final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "notti", category: "Notification")

    /// アプリ表示中に届いた通知の出し方
    static let foregroundPresentationOptions: UNNotificationPresentationOptions = [.banner, .list, .sound]

    private let scheduler: NotificationScheduler
    /// 完了を保存する先。アプリと同じ container を使い、表示中の一覧がそのまま追従するようにする（`mainContext` に保存する）
    private let modelContainer: ModelContainer?
    /// 紐づけたアプリの URL を開く。開けなかったときの知らせは、一覧の画面と同じものに出す
    private let linkOpener: LinkOpener?

    init(
        scheduler: NotificationScheduler = NotificationScheduler(),
        modelContainer: ModelContainer? = nil,
        linkOpener: LinkOpener? = nil
    ) {
        self.scheduler = scheduler
        self.modelContainer = modelContainer
        self.linkOpener = linkOpener
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        Self.foregroundPresentationOptions
    }

    /// 通知をタップしたとき・アクションを選んだときに呼ばれる
    ///
    /// UIKit は `completionHandler` の中でスナップショットを更新し、メインスレッド以外で呼ばれるとアサーションで落ちる。
    /// async 版で実装すると、型が nonisolated のため `completionHandler` が Swift Concurrency のスレッドで呼ばれてしまう。
    /// そのため completion handler 版で実装し、`respond` でメインスレッドから呼ぶ。
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        let content = response.notification.request.content
        respond(
            actionIdentifier: response.actionIdentifier,
            settingID: content.userInfo[NotificationScheduler.settingIDKey] as? String,
            message: content.body,
            categoryIdentifier: content.categoryIdentifier,
            deliveredAt: response.notification.date,
            completionHandler: completionHandler
        )
    }

    /// 通知のアクションに応えてから、メインスレッドで `completionHandler` を呼ぶ
    func respond(
        actionIdentifier: String,
        settingID: String?,
        message: String,
        categoryIdentifier: String = NotificationScheduler.categoryIdentifier,
        deliveredAt: Date = .now,
        completionHandler: @escaping @Sendable () -> Void
    ) {
        Task { @MainActor in
            await handle(
                actionIdentifier: actionIdentifier,
                settingID: settingID,
                message: message,
                categoryIdentifier: categoryIdentifier,
                deliveredAt: deliveredAt
            )
            completionHandler()
        }
    }

    /// 通知のアクションに応える
    ///
    /// - スヌーズ: `NotificationScheduler.snoozeInterval` 後に、同じカテゴリでもう一度通知する
    /// - 完了: 通知が届いた期間を完了にし、通知を登録し直し終えてから戻る
    /// - アプリを開く: 設定の ID から紐づけた URL を引いて開く（URL は通知に入れないので、後から URL を変えても新しい URL が開く）。
    ///   設定が見つからない・紐づけが外れていれば、のっちを開くだけにする
    ///
    /// - Parameters:
    ///   - settingID: 通知の userInfo に入れた設定の ID
    ///   - deliveredAt: 通知が届いた日時。完了にする期間を決める
    func handle(
        actionIdentifier: String,
        settingID: String?,
        message: String,
        categoryIdentifier: String = NotificationScheduler.categoryIdentifier,
        deliveredAt: Date = .now
    ) async {
        guard let id = settingID.flatMap(UUID.init(uuidString:)) else {
            return
        }
        switch actionIdentifier {
        case NotificationScheduler.snoozeActionIdentifier:
            do {
                try await scheduler.snooze(id: id, message: message, categoryIdentifier: categoryIdentifier)
            } catch {
                Self.logger.error("スヌーズの通知を登録できません: \(error.localizedDescription, privacy: .public)")
            }
        case NotificationScheduler.completeActionIdentifier:
            await complete(id: id, deliveredAt: deliveredAt)
        case NotificationScheduler.openLinkActionIdentifier:
            await openLink(id: id)
        default:
            break
        }
    }

    /// `id` の設定の、`deliveredAt` を含む期間を完了にする。設定が見つからなければ何もしない
    @MainActor
    private func complete(id: UUID, deliveredAt: Date) async {
        guard let modelContainer, let setting = fetchSetting(id: id, in: modelContainer.mainContext) else {
            return
        }
        let context = modelContainer.mainContext
        await NotificationSettingActions(scheduler: scheduler).complete(setting, in: context, periodContaining: deliveredAt).value
    }

    /// `id` の設定に紐づけたアプリの URL を開く。設定が見つからない・紐づけが無ければ何もしない（のっちが開くだけになる）
    ///
    /// 完了するまで繰り返す通知なら、開いた日時を保存し、のっちに戻ったときに済んだかを聞く
    @MainActor
    private func openLink(id: UUID) async {
        guard let modelContainer, let linkOpener, let setting = fetchSetting(id: id, in: modelContainer.mainContext) else {
            return
        }
        await NotificationSettingActions(scheduler: scheduler).openLink(of: setting, with: linkOpener, in: modelContainer.mainContext)
    }

    /// `id` の設定。見つからない・読み込めなければ nil
    @MainActor
    private func fetchSetting(id: UUID, in context: ModelContext) -> NotificationSetting? {
        do {
            return try context.fetch(FetchDescriptor<NotificationSetting>(predicate: #Predicate { $0.id == id })).first
        } catch {
            Self.logger.error("通知設定を読み込めません: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
