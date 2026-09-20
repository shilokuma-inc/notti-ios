import SwiftUI
import SwiftData

struct TaskCreateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var reminderDate: Date
    @State private var intervalMinutes = 5
    @State private var useSound = true
    
    let intervals = [1, 5, 10, 15, 30, 60]
    
    init(initialDate: Date? = nil) {
        if let initial = initialDate {
            _reminderDate = State(initialValue: initial)
        } else {
            _reminderDate = State(initialValue: Date().addingTimeInterval(3600)) // 1時間後
        }
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
            .navigationTitle("タスク追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        saveTask()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                Task {
                    await NotificationManager.shared.requestAuthorization()
                }
            }
        }
    }
    
    private func saveTask() {
        let newTask = TaskModel(
            title: title.trimmingCharacters(in: .whitespaces),
            reminderDate: reminderDate,
            reminderIntervalMinutes: intervalMinutes,
            useSound: useSound
        )
        modelContext.insert(newTask)
        try? modelContext.save()
        
        NotificationManager.shared.scheduleNotifications(for: newTask)
        dismiss()
    }
}
