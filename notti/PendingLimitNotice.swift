//
//  PendingLimitNotice.swift
//  notti
//

import SwiftUI

/// 登録する通知が上限（64 件）を超えるときの警告
///
/// 数が増えやすい通知の作りを並べて知らせる。おやすみ時間の 1 時間ごと、毎月の日付（日付ごとに繰り返す 1 件ずつ）と
/// 月末（N 日前）（1 回きりを `NotificationTriggerPlan.monthEndMonths` か月ぶん）、「完了するまで繰り返す」の催促
/// （`NotificationTriggerPlan.untilDoneDays` 日ぶん）。数字は定数から出し、作りを変えたときに文言がずれないようにする
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
                おやすみ時間があると 1 時間ごとの通知は 1 件で最大 24 件使い、\
                毎月の通知は日付ごとに 1 件（\(MonthDay.range.count) 日すべてで \(MonthDay.range.count) 件）と\
                月末の分を \(NotificationTriggerPlan.monthEndMonths) か月ぶん（\(NotificationTriggerPlan.monthEndMonths) 件）、\
                「完了するまで繰り返す」通知は催促を \(NotificationTriggerPlan.untilDoneDays) 日ぶん先に登録するため、\
                一部の通知が鳴らないことがあります。催促の間隔を長くするか、毎月の日付を減らすと減らせます。
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
