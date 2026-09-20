import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("通知の許可状況")) {
                    HStack {
                        Text("ローカル通知")
                        Spacer()
                        if notificationManager.isAuthorized {
                            Text("許可されています").foregroundColor(.green)
                        } else {
                            Text("許可されていません").foregroundColor(.red)
                        }
                    }
                    
                    if !notificationManager.isAuthorized {
                        Button("設定アプリを開く") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }
                
                Section(footer: Text("iOSの制限により、このアプリはタスクごとに最大60回までの連続通知をスケジュールします。タスクが完了したら必ずタスクの左側にある完了ボタンを押してください。")) {
                    EmptyView()
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await notificationManager.checkAuthorization()
                }
            }
        }
    }
}
