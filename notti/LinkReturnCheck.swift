//
//  LinkReturnCheck.swift
//  notti
//

import SwiftUI

/// 紐づけたアプリからのっちに戻ったときに、完了するまで繰り返す通知が済んだかを聞く（Q3）
///
/// 聞くのは、紐づけたアプリを開いた後にのっちが一度バックグラウンドに回り、そこから前面に戻ったときだけ。
/// 通知のアクションで開くときはいったんのっちが前面に出るが、そのときは開いた後にまだバックグラウンドに回っていないので聞かない。
/// 開いた日時を含む期間がまだ今の期間で、完了していなければ「完了にする」「まだ」を聞く。複数あれば 1 件ずつ聞く
struct LinkReturnCheck: ViewModifier {
    /// 済んだかを聞く対象の候補（一覧の設定すべて）
    let settings: [NotificationSetting]

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.notificationScheduler) private var scheduler
    /// 起動した日時。起動してから一度もバックグラウンドに回っていなければ、これより前に開いたものを聞く（OS に終了された後の起動）
    @State private var launchedAt = Date.now
    /// 最後にバックグラウンドに回った日時
    @State private var backgroundedAt: Date?
    /// 今聞いている設定
    @State private var asking: NotificationSetting?

    private var actions: NotificationSettingActions {
        NotificationSettingActions(scheduler: scheduler)
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase, initial: true) { _, phase in
                switch phase {
                case .background:
                    backgroundedAt = .now
                case .active:
                    askNext()
                case .inactive:
                    break
                @unknown default:
                    break
                }
            }
            .alert(
                Text("「\(asking?.message ?? "")」は済みましたか？"),
                isPresented: Binding { asking != nil } set: { isPresented in
                    if !isPresented {
                        asking = nil
                    }
                },
                presenting: asking
            ) { setting in
                Button("完了にする") {
                    actions.completeLinkReturn(setting, in: modelContext)
                    askNextAfterDismissal()
                }
                Button("まだ", role: .cancel) {
                    actions.finishLinkReturn(setting, in: modelContext)
                    askNextAfterDismissal()
                }
            } message: { _ in
                Text("紐づけたアプリから戻りました。済んでいれば、今の期間を完了にします")
            }
    }

    /// 聞く対象を 1 件探して聞く。聞かなくてよくなったもの（期間が替わった・完了済みなど）は、開いた日時を消す
    private func askNext(now: Date = .now) {
        guard asking == nil else {
            return
        }
        let reference = backgroundedAt ?? launchedAt
        for setting in settings where setting.linkOpenedAt != nil {
            switch setting.linkReturnDecision(backgroundedAt: reference, now: now, calendar: scheduler.calendar) {
            case .notReturned:
                continue
            case .discard:
                actions.finishLinkReturn(setting, in: modelContext)
            case .ask:
                asking = setting
                return
            }
        }
    }

    /// アラートが閉じきってから次を聞く（閉じている途中で次のアラートを出すと出ないため）
    private func askNextAfterDismissal() {
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            askNext()
        }
    }
}

extension View {
    /// 紐づけたアプリから戻ったときに、完了するまで繰り返す通知が済んだかを聞く
    func linkReturnCheck(settings: [NotificationSetting]) -> some View {
        modifier(LinkReturnCheck(settings: settings))
    }
}
