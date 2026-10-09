//
//  PendingLimitNotice.swift
//  notti
//

import SwiftUI

/// 登録する通知が上限（64 件）を超えるときの警告
struct PendingLimitNotice: View {
    let requestCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("通知の数が上限を超えています", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text(
                """
                登録できる通知は \(NotificationScheduler.pendingLimit) 件までですが、\(requestCount) 件になっています。\
                おやすみ時間があると 1 時間ごとの通知は 1 件で最大 24 件使い、「完了するまで繰り返す」通知は \
                催促を \(NotificationTriggerPlan.untilDoneDays) 日ぶん先に登録するため、一部の通知が鳴らないことがあります。\
                催促の間隔を長くすると減らせます。
                """
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        PendingLimitNotice(requestCount: 72)
    }
}
