//
//  NotificationDelegateTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import Testing
import UserNotifications

struct NotificationDelegateTests {
    /// アプリ表示中もバナーで出し、通知センターに残し、音も鳴らす
    @Test
    func foregroundPresentationShowsBanner() {
        let options = NotificationDelegate.foregroundPresentationOptions
        #expect(options.contains(.banner))
        #expect(options.contains(.list))
        #expect(options.contains(.sound))
    }

    /// UIKit は通知への応答の完了ハンドラをメインスレッドで呼ぶよう求める（ほかのスレッドで呼ぶとアサーションで落ちる）
    @Test(arguments: [UNNotificationDefaultActionIdentifier, NotificationScheduler.snoozeActionIdentifier])
    func respondCallsCompletionHandlerOnMainThread(actionIdentifier: String) async {
        let delegate = NotificationDelegate(scheduler: .fake(FakeNotificationCenter()))

        // 通知センターと同じく、メインスレッド以外から呼ぶ
        let isMainThread = await Task.detached {
            await withCheckedContinuation { continuation in
                delegate.respond(actionIdentifier: actionIdentifier, settingID: UUID().uuidString, message: "歩数") {
                    continuation.resume(returning: Thread.isMainThread)
                }
            }
        }.value

        #expect(isMainThread)
    }

    /// スヌーズの通知を登録し終えてから完了を知らせる
    @Test
    func respondSchedulesSnoozeBeforeCompletion() async {
        let center = FakeNotificationCenter()
        let delegate = NotificationDelegate(scheduler: .fake(center))
        let id = UUID()

        let isScheduled = await withCheckedContinuation { continuation in
            delegate.respond(
                actionIdentifier: NotificationScheduler.snoozeActionIdentifier,
                settingID: id.uuidString,
                message: "歩数"
            ) {
                continuation.resume(returning: center.pending["\(id.uuidString)-snooze"] != nil)
            }
        }

        #expect(isScheduled)
    }
}
