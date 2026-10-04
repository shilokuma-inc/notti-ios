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
    @State private var isAdding = false
    @State private var editingSetting: NotificationSetting?

    private var actions: NotificationSettingActions {
        NotificationSettingActions(scheduler: scheduler)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(settings) { setting in
                    NotificationRow(setting: setting, isEnabled: isEnabledBinding(for: setting)) {
                        editingSetting = setting
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
                        description: Text("右上の ＋ から、繰り返し通知する文言を追加できます")
                    )
                }
            }
            .navigationTitle("通知")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("追加", systemImage: "plus") {
                        isAdding = true
                    }
                }
            }
            .sheet(isPresented: $isAdding) {
                NotificationEditView()
            }
            .sheet(item: $editingSetting) { setting in
                NotificationEditView(setting: setting)
            }
        }
    }

    private func isEnabledBinding(for setting: NotificationSetting) -> Binding<Bool> {
        Binding {
            setting.isEnabled
        } set: { isEnabled in
            actions.setEnabled(isEnabled, for: setting)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: NotificationSetting.self, inMemory: true)
}
