//
//  ContentView.swift
//  notti
//
//  Created by 村石 拓海 on 2024/05/12.
//

import SwiftData
import SwiftUI

/// 登録した通知の一覧
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.notificationScheduler) private var scheduler
    @Query(sort: \NotificationSetting.createdAt) private var settings: [NotificationSetting]

    private var actions: NotificationSettingActions {
        NotificationSettingActions(scheduler: scheduler)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(settings) { setting in
                    NotificationRow(setting: setting) { isEnabled in
                        actions.setEnabled(isEnabled, for: setting)
                    }
                }
                .onDelete { offsets in
                    actions.delete(offsets.map { settings[$0] }, from: modelContext)
                }
            }
            .overlay {
                if settings.isEmpty {
                    ContentUnavailableView(
                        "通知がありません",
                        systemImage: "bell.slash",
                        description: Text("登録した文言を、設定した間隔で繰り返し通知します")
                    )
                }
            }
            .navigationTitle("通知")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: NotificationSetting.self, inMemory: true)
}
