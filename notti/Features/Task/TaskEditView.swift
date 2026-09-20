import SwiftUI
import SwiftData

struct TaskEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let task: TaskModel
    
    @State private var title: String
    @State private var reminderDate: Date
    @State private var intervalMinutes: Int
    @State private var useSound: Bool
    
    @State private var showingConfirmAlert = false
    
    let intervals = [1, 5, 10, 15, 30, 60]
    
    init(task: TaskModel) {
        self.task = task
        _title = State(initialValue: task.title)
        _reminderDate = State(initialValue: task.reminderDate)
        _intervalMinutes = State(initialValue: task.reminderIntervalMinutes)
        _useSound = State(initialValue: task.useSound)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("タスク内容")) {
                    TextField("何をしますか？", text: $title)
                }
                
                Section(header: Text("リマインド設定")) {
                    DatePicker("開始時間", selection: $reminderDate, displayedComponents: [.date, .hourAndMinute])
                    
                    Picker("通知間隔", selection: $intervalMinutes) {
                        ForEach(intervals, id: \.self) { interval in
                            Text("\(interval)分おき").tag(interval)
                        }
                    }
                    
                    Toggle("通知音を鳴らす", isOn: $useSound)
                }
            }
            .navigationTitle("タスクの変更")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundStyle(.green)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("変更") {
                        showingConfirmAlert = true
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    .foregroundStyle(.green)
                }
            }
            .alert("タスクの変更確認", isPresented: $showingConfirmAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("変更する", action: saveChanges)
            } message: {
                Text("予定の日時などの内容を変更してもよろしいですか？")
            }
        }
    }
    
    private func saveChanges() {
        // 古い通知をキャンセル
        NotificationManager.shared.cancelNotifications(for: task)
        
        // データの更新
        task.title = title.trimmingCharacters(in: .whitespaces)
        task.reminderDate = reminderDate
        task.reminderIntervalMinutes = intervalMinutes
        task.useSound = useSound
        
        try? modelContext.save()
        
        // 新しい通知をスケジュール
        NotificationManager.shared.scheduleNotifications(for: task)
        dismiss()
    }
}
