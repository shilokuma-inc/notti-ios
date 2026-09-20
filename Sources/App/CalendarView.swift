import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskModel.reminderDate) private var allTasks: [TaskModel]
    
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var taskToComplete: TaskModel?
    @State private var showingCompleteAlert = false
    @State private var editingTask: TaskModel?
    @State private var showingCreateView = false
    
    let daysOfWeek = ["日", "月", "火", "水", "木", "金", "土"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Calendar Header
                HStack {
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(.green)
                            .padding()
                    }
                    Spacer()
                    Text(currentMonth, format: .dateTime.year().month())
                        .font(.title2.bold())
                    Spacer()
                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.green)
                            .padding()
                    }
                }
                
                // Days of week
                HStack {
                    ForEach(daysOfWeek, id: \.self) { day in
                        Text(day)
                            .frame(maxWidth: .infinity)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
                
                // Calendar Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(extractDates(), id: \.self) { dateValue in
                        CardView(value: dateValue)
                            .onTapGesture {
                                if dateValue.day != -1 {
                                    selectedDate = dateValue.date
                                }
                            }
                    }
                }
                .padding(.horizontal)
                
                Divider().padding(.top)
                
                // Task List for Selected Date
                List {
                    let tasksForSelectedDate = tasks(for: selectedDate)
                    if tasksForSelectedDate.isEmpty {
                        Text("予定はありません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(tasksForSelectedDate) { task in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(task.title)
                                        .font(.headline)
                                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                                        .overlay(
                                            Group {
                                                if task.isCompleted {
                                                    Rectangle()
                                                        .fill(Color.secondary)
                                                        .frame(height: 2.5) // 太めのライン
                                                        .offset(y: 1)
                                                }
                                            }
                                        )
                                    Text(task.reminderDate, style: .time)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if !task.isCompleted {
                                        editingTask = task
                                    }
                                }
                                Spacer()
                                if !task.isCompleted {
                                    Button(action: {
                                        taskToComplete = task
                                        showingCompleteAlert = true
                                    }) {
                                        Image(systemName: "circle")
                                            .font(.title2)
                                            .foregroundStyle(.green)
                                    }
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .alert("タスクの完了確認", isPresented: $showingCompleteAlert, presenting: taskToComplete) { task in
                    Button("キャンセル", role: .cancel) { }
                    Button("完了にする", action: {
                        markAsCompleted(task)
                    })
                } message: { task in
                    Text("「\(task.title)」を完了してもよろしいですか？\n(完了するとリマインダーも停止します)")
                }
            }
            .navigationTitle("カレンダー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingCreateView = true }) {
                        Image(systemName: "plus")
                            .foregroundStyle(.green)
                    }
                }
            }
            .sheet(isPresented: $showingCreateView) {
                // カレンダーで選択している日付を初期値として渡す
                TaskCreateView(initialDate: selectedDate)
            }
            .sheet(item: $editingTask) { task in
                TaskEditView(task: task)
            }
        }
    }
    
    @ViewBuilder
    func CardView(value: DateValue) -> some View {
        VStack(spacing: 4) {
            if value.day != -1 {
                Text("\(value.day)")
                    .font(.body)
                    .frame(width: 32, height: 32)
                    .background(
                        isSameDay(date1: value.date, date2: selectedDate) ? Color.green.opacity(0.2) : Color.clear
                    )
                    .clipShape(Circle())
                
                if hasTask(on: value.date) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(.clear)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .frame(height: 44)
        .contentShape(Rectangle())
    }
    
    // Date Helpers
    private func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            self.currentMonth = newMonth
        }
    }
    
    private func tasks(for date: Date) -> [TaskModel] {
        allTasks.filter { isSameDay(date1: $0.reminderDate, date2: date) }
    }
    
    private func hasTask(on date: Date) -> Bool {
        allTasks.contains { !$0.isCompleted && isSameDay(date1: $0.reminderDate, date2: date) }
    }
    
    private func isSameDay(date1: Date, date2: Date) -> Bool {
        Calendar.current.isDate(date1, inSameDayAs: date2)
    }
    
    private func extractDates() -> [DateValue] {
        let calendar = Calendar.current
        
        let currentMonth = self.currentMonth
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else { return [] }
        
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        
        var days = range.compactMap { day -> DateValue in
            let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)!
            return DateValue(day: day, date: date)
        }
        
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        for _ in 0..<(firstWeekday - 1) {
            days.insert(DateValue(day: -1, date: Date()), at: 0)
        }
        
        return days
    }
    
    private func markAsCompleted(_ task: TaskModel) {
        task.isCompleted = true
        NotificationManager.shared.cancelNotifications(for: task)
        try? modelContext.save()
    }
}

struct DateValue: Identifiable, Hashable {
    var id = UUID().uuidString
    var day: Int
    var date: Date
}
