//
//  NotificationDeniedNotice.swift
//  notti
//

import SwiftUI
import UIKit

/// 通知が拒否されているときに一覧の先頭に出す案内。設定アプリの通知設定へのリンクを付ける
struct NotificationDeniedNotice: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("通知が許可されていません", systemImage: "bell.slash.fill")
                .font(.headline)
            Text("設定アプリで notti の通知を許可してください。許可するまで通知は届きません。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("設定アプリを開く") {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    openURL(url)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        NotificationDeniedNotice()
    }
}
