//
//  NottiApp.swift
//  notti
//
//  Created by 村石 拓海 on 2024/05/12.
//

import SwiftUI

@main
struct NottiApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // 撮影モードでは端末の設定によらず同じ配色で撮る。通常の起動では nil（端末の設定のまま）
                .preferredColorScheme(ScreenshotDemo.colorScheme)
        }
    }
}
