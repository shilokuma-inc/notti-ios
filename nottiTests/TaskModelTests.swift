import Foundation
import SwiftData
import Testing

@testable import notti

@MainActor
struct TaskModelTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: TaskModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func 既定値で作られたタスクは未完了で通知音が有効になる() {
        let task = TaskModel(title: "洗濯物を取り込む", reminderDate: Date())

        #expect(task.isCompleted == false)
        #expect(task.reminderIntervalMinutes == 1)
        #expect(task.useSound)
    }

    @Test func 指定した通知間隔と通知音の設定が保持される() {
        let reminderDate = Date(timeIntervalSince1970: 1_700_000_000)
        let task = TaskModel(
            title: "ゴミを出す",
            reminderDate: reminderDate,
            reminderIntervalMinutes: 15,
            useSound: false
        )

        #expect(task.title == "ゴミを出す")
        #expect(task.reminderDate == reminderDate)
        #expect(task.reminderIntervalMinutes == 15)
        #expect(task.useSound == false)
    }

    // TaskListView は未完了のタスクだけを新しい順に表示するので、その取得条件を検証する
    @Test func 未完了のタスクだけが作成日の新しい順に取得できる() throws {
        let context = try makeContext()
        let done = TaskModel(title: "完了済み", reminderDate: Date())
        done.isCompleted = true
        let older = TaskModel(title: "古い未完了", reminderDate: Date())
        older.createdAt = Date(timeIntervalSince1970: 1_000)
        let newer = TaskModel(title: "新しい未完了", reminderDate: Date())
        newer.createdAt = Date(timeIntervalSince1970: 2_000)
        for task in [done, older, newer] {
            context.insert(task)
        }

        let descriptor = FetchDescriptor<TaskModel>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let tasks = try context.fetch(descriptor)

        #expect(tasks.map(\.title) == ["新しい未完了", "古い未完了"])
    }
}
