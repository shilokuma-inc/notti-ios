import Foundation
import UserNotifications
import SwiftData

@MainActor
class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Task {
            await checkAuthorization()
        }
    }
    
    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            self.isAuthorized = granted
        } catch {
            print("Error requesting notification authorization: \(error)")
        }
    }
    
    func checkAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }
    
    func scheduleNotifications(for task: TaskModel) {
        guard isAuthorized else { return }
        
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "リマインダー: \(task.title)"
        content.body = "このタスクは完了しましたか？アプリを開いて完了にしてください！"
        if task.useSound {
            content.sound = .default
        }
        
        // Schedule up to 60 notifications (iOS limit is 64 pending notifications per app)
        // This simulates a repeating alarm until cancelled.
        let maxNotifications = 60
        for i in 0..<maxNotifications {
            let triggerDate = task.reminderDate.addingTimeInterval(TimeInterval(i * task.reminderIntervalMinutes * 60))
            
            // Only schedule if the date is in the future
            if triggerDate > Date() {
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                
                let request = UNNotificationRequest(identifier: "\(task.id.uuidString)-\(i)", content: content, trigger: trigger)
                center.add(request) { error in
                    if let error = error {
                        print("Error scheduling notification: \(error)")
                    }
                }
            }
        }
    }
    
    func cancelNotifications(for task: TaskModel) {
        let center = UNUserNotificationCenter.current()
        let maxNotifications = 60
        var identifiers: [String] = []
        for i in 0..<maxNotifications {
            identifiers.append("\(task.id.uuidString)-\(i)")
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // アプリ起動中（フォアグラウンド）でも通知バナーと音を鳴らすための設定
        completionHandler([.banner, .sound, .list])
    }
}
