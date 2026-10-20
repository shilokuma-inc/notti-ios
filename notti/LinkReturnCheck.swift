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
///
/// アラートは付けた画面の上にしか出ないので、一覧からシートを開いている間と、開けなかったときの知らせを出している間は聞かずに待ち、
/// 閉じてから聞く（シートの裏で聞こうとすると、閉じるまで出ないうえに、聞いている途中のまま次を聞けなくなるため）
struct LinkReturnCheck: ViewModifier {
    /// 済んだかを聞く対象の候補（一覧の設定すべて）
    let settings: [NotificationSetting]
    /// 一覧から追加・編集・おやすみ時間のシートを開いている
    let isPresentingSheet: Bool

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.notificationScheduler) private var scheduler
    @Environment(LinkOpener.self) private var linkOpener
    /// 起動した日時。起動してから一度もバックグラウンドに回っていなければ、これより前に開いたものを聞く（OS に終了された後の起動）
    @State private var launchedAt = Date.now
    /// 最後にバックグラウンドに回った日時
    @State private var backgroundedAt: Date?
    /// 今聞いている設定
    @State private var asking: NotificationSetting?
    /// 今聞いている設定の文言。アラートが閉じる途中で `asking` が nil になっても、タイトルが空にならないよう別に持つ
    @State private var askingMessage = ""

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
            .onChange(of: isPresentingSheet) { _, isPresenting in
                if !isPresenting {
                    askNextAfterDismissal()
                }
            }
            .onChange(of: linkOpener.isShowingFailure) { _, isShowing in
                if !isShowing {
                    askNextAfterDismissal()
                }
            }
            .alert(
                Text("「\(askingMessage)」は済みましたか？"),
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
        guard asking == nil, !isPresentingSheet, !linkOpener.isShowingFailure, scenePhase == .active else {
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
                askingMessage = setting.message
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
    ///
    /// - Parameter isPresentingSheet: シートを開いている間は聞かずに待ち、閉じてから聞く
    func linkReturnCheck(settings: [NotificationSetting], isPresentingSheet: Bool) -> some View {
        modifier(LinkReturnCheck(settings: settings, isPresentingSheet: isPresentingSheet))
    }
}
