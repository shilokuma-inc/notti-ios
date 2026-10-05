//
//  QuietHoursView.swift
//  notti
//

import SwiftData
import SwiftUI

/// おやすみ時間（通知しない時間帯）の設定画面。完了ですべての通知を登録し直す
struct QuietHoursView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.notificationScheduler) private var scheduler
    @StoredQuietHours private var storedQuietHours
    @Query private var settings: [NotificationSetting]
    @State private var isEnabled: Bool
    @State private var start: Date
    @State private var end: Date

    init() {
        let stored = QuietHours.load(from: .standard)
        _isEnabled = State(initialValue: stored.isEnabled)
        _start = State(initialValue: Self.date(from: stored.start))
        _end = State(initialValue: Self.date(from: stored.end))
    }

    private var draft: QuietHours {
        QuietHours(isEnabled: isEnabled, start: Self.time(from: start), end: Self.time(from: end))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("おやすみ時間を使う", isOn: $isEnabled)
                } footer: {
                    Text("おやすみ時間のあいだは通知しません。オフのときは 24 時間通知します。")
                }
                if isEnabled {
                    Section {
                        DatePicker("開始", selection: $start, displayedComponents: .hourAndMinute)
                        DatePicker("終了", selection: $end, displayedComponents: .hourAndMinute)
                    } footer: {
                        Text("日をまたぐ時間帯（例: 23:00〜7:00）も指定できます。開始と終了が同じときは通知を止めません。")
                    }
                }
                let requestCount = settings.requestCount(quietHours: draft)
                if requestCount > NotificationScheduler.pendingLimit {
                    Section {
                        PendingLimitNotice(requestCount: requestCount)
                    }
                }
            }
            .navigationTitle("おやすみ時間")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        save()
                        dismiss()
                    }
                }
            }
        }
    }

    private func save() {
        let draft = draft
        guard draft != storedQuietHours else {
            return
        }
        storedQuietHours = draft
        NotificationSettingActions(scheduler: scheduler).rescheduleAll(settings, in: modelContext)
    }

    private static func date(from time: TimeOfDay) -> Date {
        Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: .now) ?? .now
    }

    private static func time(from date: Date) -> TimeOfDay {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return TimeOfDay(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }
}

#Preview {
    QuietHoursView()
        .modelContainer(for: NotificationSetting.self, inMemory: true)
}
