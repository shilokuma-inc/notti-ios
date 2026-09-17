import Foundation
import SwiftData

@Model
final class TaskModel {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var reminderDate: Date
    var reminderIntervalMinutes: Int
    var useSound: Bool
    
    init(title: String, reminderDate: Date, reminderIntervalMinutes: Int = 1, useSound: Bool = true) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.createdAt = Date()
        self.reminderDate = reminderDate
        self.reminderIntervalMinutes = reminderIntervalMinutes
        self.useSound = useSound
    }
}
