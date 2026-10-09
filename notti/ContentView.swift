//
//  ContentView.swift
//  notti
//
//  Created by 村石 拓海 on 2024/05/12.
//

import SwiftData
import SwiftUI

/// 登録した通知の一覧
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.notificationScheduler) private var scheduler
    @Environment(\.notificationAuthorizer) private var authorizer
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \NotificationSetting.createdAt) private var settings: [NotificationSetting]
    @StoredQuietHours private var quietHours
    @State private var isAdding = false
    @State private var editingSetting: NotificationSetting?
    @State private var isEditingQuietHours = false
    @State private var authorization = NotificationAuthorization.allowed

    private var actions: NotificationSettingActions {
        NotificationSettingActions(scheduler: scheduler)
    }

    var body: some View {
        NavigationStack {
            List {
                if authorization == .denied {
                    Section {
                        NotificationDeniedNotice()
                    }
                }
                let requestCount = settings.requestCount(quietHours: quietHours)
                if requestCount > NotificationScheduler.pendingLimit {
                    Section {
                        PendingLimitNotice(requestCount: requestCount)
                    }
                }
                ForEach(settings) { setting in
                    NotificationRow(
                        setting: setting,
                        isEnabled: isEnabledBinding(for: setting),
                        isSilent: setting.isSilent(quietHours: quietHours),
                        onEdit: { editingSetting = setting },
                        onSetCompleted: { isCompleted in
                            if isCompleted {
                                actions.complete(setting, in: modelContext)
                            } else {
                                actions.undoCompletion(setting, in: modelContext)
                            }
                        }
                    )
                }
                .onDelete { offsets in
                    actions.delete(offsets.map { settings[$0] }, from: modelContext)
                }
            }
            .overlay {
                if settings.isEmpty && authorization != .denied {
                    ContentUnavailableView(
                        "通知がありません",
                        systemImage: "bell.slash",
                        description: Text("右上の ＋ から、繰り返し通知する文言を追加できます")
                    )
                }
            }
            .navigationTitle("通知")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("おやすみ時間", systemImage: quietHours.isActive ? "moon.fill" : "moon") {
                        isEditingQuietHours = true
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("追加", systemImage: "plus") {
                        isAdding = true
                    }
                }
            }
            .sheet(isPresented: $isAdding, onDismiss: requestAuthorizationIfEnabled) {
                NotificationEditView()
            }
            .sheet(item: $editingSetting, onDismiss: requestAuthorizationIfEnabled) { setting in
                NotificationEditView(setting: setting)
            }
            .sheet(isPresented: $isEditingQuietHours) {
                QuietHoursView()
            }
            .task {
                authorization = await authorizer.authorization()
            }
            .onChange(of: scenePhase) { _, phase in
                // 設定アプリで許可を変えて戻ってきたときに案内を更新する
                if phase == .active {
                    actions.disableExpiredOnce(settings, in: modelContext)
                    Task {
                        authorization = await authorizer.authorization()
                    }
                    // 「完了するまで繰り返す」通知の催促は先に登録した日数ぶんしか無いので、前面に戻るたびに補充する
                    Task {
                        await NotificationReconciler(scheduler: scheduler).reconcile(in: modelContext)
                    }
                }
            }
            .task(id: actions.nextOnceDate(in: settings)) {
                // 一覧を開いたまま 1 回だけの通知の日時を過ぎたら、その場で OFF にする
                guard let date = actions.nextOnceDate(in: settings) else {
                    return
                }
                do {
                    try await Task.sleep(for: .seconds(max(date.timeIntervalSinceNow, 0) + 1))
                } catch {
                    return
                }
                actions.disableExpiredOnce(settings, in: modelContext)
            }
        }
    }

    /// ON の通知があるときだけ許可を求める（通知を使い始めた時点で尋ねる）
    private func requestAuthorizationIfEnabled() {
        guard settings.contains(where: \.isEnabled) else {
            return
        }
        Task {
            authorization = await authorizer.requestIfNeeded()
        }
    }

    private func isEnabledBinding(for setting: NotificationSetting) -> Binding<Bool> {
        Binding {
            setting.isEnabled
        } set: { isEnabled in
            actions.setEnabled(isEnabled, for: setting)
            requestAuthorizationIfEnabled()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: NotificationSetting.self, inMemory: true)
}
