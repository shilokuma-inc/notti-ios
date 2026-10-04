//
//  NotificationEditView.swift
//  notti
//

import SwiftData
import SwiftUI

/// 通知の追加・編集画面。文言と間隔を入力して保存する
struct NotificationEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.notificationScheduler) private var scheduler

    /// 編集する設定。nil なら追加
    private let setting: NotificationSetting?
    @State private var message: String
    @State private var interval: NotificationInterval

    init(setting: NotificationSetting? = nil) {
        self.setting = setting
        _message = State(initialValue: setting?.message ?? "")
        _interval = State(initialValue: setting?.interval ?? .oneHour)
    }

    private var canSave: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("文言") {
                    TextField("例: 水を飲む", text: $message, axis: .vertical)
                        .accessibilityIdentifier("messageField")
                }
                Section {
                    Picker("間隔", selection: $interval) {
                        ForEach(NotificationInterval.allCases) { interval in
                            Text(interval.label).tag(interval)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("間隔")
                } footer: {
                    Text("保存した時刻から数えて、この間隔で繰り返し通知します")
                }
            }
            .navigationTitle(setting == nil ? "通知を追加" : "通知を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        NotificationSettingActions(scheduler: scheduler)
                            .save(message: message, interval: interval, to: setting, in: modelContext)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

#Preview {
    NotificationEditView()
        .modelContainer(for: NotificationSetting.self, inMemory: true)
}
