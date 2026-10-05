//
//  NottiApp.swift
//  notti
//
//  Created by 村石 拓海 on 2024/05/12.
//

import Foundation
import SwiftData
import SwiftUI
import UserNotifications

@main
struct NottiApp: App {
    private let modelContainer: ModelContainer
    /// 通知センターは delegate を弱参照で持つため、ここで保持する
    private let notificationDelegate = NotificationDelegate()

    init() {
        do {
            // UI テストは前回の実行で保存したデータに左右されないよう、メモリ上にだけ保存する
            let inMemory = ProcessInfo.processInfo.arguments.contains(NottiModelContainer.inMemoryLaunchArgument)
            modelContainer = try NottiModelContainer.make(inMemory: inMemory)
        } catch {
            fatalError("ModelContainer を作成できません: \(error)")
        }
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // 撮影モードでは端末の設定によらず同じ配色で撮る。通常の起動では nil（端末の設定のまま）
                .preferredColorScheme(ScreenshotDemo.colorScheme)
                .task {
                    await NotificationReconciler(scheduler: NotificationScheduler())
                        .reconcile(in: modelContainer.mainContext)
                }
        }
        .modelContainer(modelContainer)
    }
}
