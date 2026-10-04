//
//  NotificationRow.swift
//  notti
//

import SwiftUI

/// 一覧の 1 行。文言と間隔を出し、ON/OFF を切り替える
struct NotificationRow: View {
    let setting: NotificationSetting
    @Binding var isEnabled: Bool

    var body: some View {
        Toggle(isOn: $isEnabled) {
            VStack(alignment: .leading, spacing: 4) {
                Text(setting.message)
                Text(setting.interval.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
