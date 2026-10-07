//
//  NotificationRow.swift
//  notti
//

import SwiftUI

/// 一覧の 1 行。文言といつ鳴らすか（間隔、または時刻と繰り返し）を出し、ON/OFF を切り替える。文言部分のタップで編集する
/// おやすみ時間のせいで鳴らない通知と、日時を過ぎた 1 回だけの通知には、その旨を添える
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
                    Text(setting.scheduleLabel())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if isSilent {
                        Label("おやすみ時間中のため鳴りません", systemImage: "moon.zzz")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    // 一覧を開いたまま日時を過ぎても出るよう、分が変わるたびに判定し直す
                    TimelineView(.everyMinute) { timeline in
                        if setting.isOnceExpired(now: timeline.date) {
                            Label("日時を過ぎたため鳴りません", systemImage: "clock.badge.xmark")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
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
