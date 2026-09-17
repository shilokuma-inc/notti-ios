import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TaskModel> { !$0.isCompleted }, sort: \TaskModel.createdAt, order: .reverse)
    private var activeTasks: [TaskModel]
    
    @State private var showingCreateView = false
    @State private var showingSettings = false
    @State private var taskToComplete: TaskModel?
    @State private var showingCompleteAlert = false
    @State private var editingTask: TaskModel?
    
    var body: some View {
        NavigationStack {
            List {
                if activeTasks.isEmpty {
                    ContentUnavailableView("タスクがありません", systemImage: "checkmark.circle", description: Text("右上の＋ボタンから新しいタスクを追加してください。"))
                } else {
                    ForEach(activeTasks) { task in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(.headline)
                                Text("リマインド: \(task.reminderDate, style: .time) から \(task.reminderIntervalMinutes)分おき")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingTask = task
                            }
                            Spacer()
                            Button(action: {
                                taskToComplete = task
                                showingCompleteAlert = true
                            }) {
                                Image(systemName: "circle")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteTasks)
                }
            }
            .alert("タスクの完了確認", isPresented: $showingCompleteAlert, presenting: taskToComplete) { task in
                Button("キャンセル", role: .cancel) { }
                Button("完了にする", action: {
                    markAsCompleted(task)
                })
            } message: { task in
                Text("「\(task.title)」を完了してもよろしいですか？\n(完了するとリマインダーも停止します)")
            }
            .navigationTitle("おせっかいアプリ")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.green)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingCreateView = true }) {
                        Image(systemName: "plus")
                            .foregroundStyle(.green)
                    }
                }
            }
            .sheet(isPresented: $showingCreateView) {
                TaskCreateView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(item: $editingTask) { task in
                TaskEditView(task: task)
            }
        }
    }
    
    private func markAsCompleted(_ task: TaskModel) {
        task.isCompleted = true
        NotificationManager.shared.cancelNotifications(for: task)
        try? modelContext.save()
    }
    
    private func deleteTasks(offsets: IndexSet) {
        for index in offsets {
            let task = activeTasks[index]
            NotificationManager.shared.cancelNotifications(for: task)
            modelContext.delete(task)
        }
        try? modelContext.save()
    }
}
