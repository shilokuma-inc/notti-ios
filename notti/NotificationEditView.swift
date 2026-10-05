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
    @StoredQuietHours private var quietHours

    /// 編集する設定。nil なら追加
    private let setting: NotificationSetting?
    @State private var message: String
    @State private var interval: NotificationInterval

    init(setting: NotificationSetting? = nil) {
        self.setting = setting
        _message = State(initialValue: setting?.message ?? "")
        _interval = State(initialValue: setting?.interval ?? .oneHour)
    }

    /// 保存すると、おやすみ時間のせいで一度も鳴らなくなる
    ///
    /// 追加・変更して保存すると保存した時刻が起点になる。変更が無ければ起点は今のまま。
    private var isSilentAfterSave: Bool {
        let isChanged = setting.map { $0.message != trimmedMessage || $0.interval != interval } ?? true
        let startDate = isChanged ? .now : setting?.startDate ?? .now
        let calendar = Calendar.current
        let plan = NotificationTriggerPlan.make(
            startDate: startDate,
            interval: interval,
            quietHours: quietHours,
            calendar: calendar,
            timeZone: calendar.timeZone
        )
        return plan.isSilent
    }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedMessage.isEmpty
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("保存した時刻から数えて、この間隔で繰り返し通知します")
                        if isSilentAfterSave {
                            Label("起点の時刻がおやすみ時間に入るため、この通知は鳴りません", systemImage: "moon.zzz")
                                .foregroundStyle(.orange)
                        }
                    }
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
