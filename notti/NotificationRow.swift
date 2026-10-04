//
//  NotificationRow.swift
//  notti
//

import SwiftUI

/// 一覧の 1 行。文言と間隔を出し、ON/OFF を切り替える。文言部分のタップで編集する
struct NotificationRow: View {
    let setting: NotificationSetting
    @Binding var isEnabled: Bool
    let onEdit: () -> Void

    var body: some View {
        HStack {
            Button {
                onEdit()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(setting.message)
                    Text(setting.interval.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Toggle("通知", isOn: $isEnabled)
                .labelsHidden()
        }
    }
}
