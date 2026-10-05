//
//  NotificationRow.swift
//  notti
//

import SwiftUI

/// 一覧の 1 行。文言と間隔を出し、ON/OFF を切り替える。文言部分のタップで編集する
/// おやすみ時間のせいで鳴らない通知には、その旨を添える
struct NotificationRow: View {
    let setting: NotificationSetting
    @Binding var isEnabled: Bool
    /// ON なのに、おやすみ時間のせいで一度も鳴らない
    let isSilent: Bool
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
                    if isSilent {
                        Label("おやすみ時間中のため鳴りません", systemImage: "moon.zzz")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
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
