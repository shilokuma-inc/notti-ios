import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            TaskListView()
                .tabItem {
                    Label("タスク", systemImage: "checklist")
                }
            
            CalendarView()
                .tabItem {
                    Label("カレンダー", systemImage: "calendar")
                }
        }
    }
}
