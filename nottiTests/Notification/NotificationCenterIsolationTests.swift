//
//  NotificationCenterIsolationTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import Testing
import UserNotifications

/// 本物の通知センターを呼んだ後も、呼び出し元の MainActor に戻ることを確かめる
///
/// `UNUserNotificationCenter` の async メソッドがプロトコルの要件をそのまま満たしていると、
/// 通知センターのコールバックのスレッドのまま戻り、起動時の突き合わせ（MainActor）がメインスレッド以外で動いて落ちた。
/// 登録済みの通知を読むだけなので、許可ダイアログは出ず、登録内容も変わらない。
@MainActor
struct NotificationCenterIsolationTests {
    @Test
    func pendingNotificationsReturnsOnMainThread() async {
        let scheduler = NotificationScheduler(center: UNUserNotificationCenter.current())

        _ = await scheduler.pendingNotifications()

        #expect(pthread_main_np() != 0)
    }
}
