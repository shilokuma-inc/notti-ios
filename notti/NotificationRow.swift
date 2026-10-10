//
//  NotificationRow.swift
//  notti
//

import SwiftUI

/// 一覧の 1 行。文言といつ鳴らすか（間隔、または時刻と繰り返し）を出し、ON/OFF を切り替える。文言部分のタップで編集する
/// おやすみ時間のせいで鳴らない通知と、日時を過ぎた 1 回だけの通知には、その旨を添える
/// 完了するまで繰り返す ON の通知には、今の期間（今日・今週）の完了の状態と、完了・取り消しのボタンを出す
struct NotificationRow: View {
    let setting: NotificationSetting
    @Binding var isEnabled: Bool
    /// ON なのに、おやすみ時間のせいで一度も鳴らない
    let isSilent: Bool
    let onEdit: () -> Void
    /// 今の期間を完了にする（true）・完了を取り消す（false）
    var onSetCompleted: (Bool) -> Void = { _ in }

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
                        if isEnabled, let status = setting.completionStatusLabel(now: timeline.date) {
                            Text(status)
                                .font(.caption)
                                .foregroundStyle(setting.isCurrentPeriodCompleted(now: timeline.date) == true ? .green : .secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isEnabled {
                // 日・週が変わったら未完了に戻るよう、分が変わるたびに判定し直す
                TimelineView(.everyMinute) { timeline in
                    if let isCompleted = setting.isCurrentPeriodCompleted(now: timeline.date) {
                        completionButton(isCompleted: isCompleted)
                    }
                }
            }
            Toggle("通知", isOn: $isEnabled)
                .labelsHidden()
        }
    }

    private func completionButton(isCompleted: Bool) -> some View {
        Button {
            onSetCompleted(!isCompleted)
        } label: {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isCompleted ? .green : .secondary)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(isCompleted ? "完了を取り消す" : "完了にする")
        .accessibilityIdentifier("completionButton")
    }
}
