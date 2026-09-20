import SwiftUI
import SwiftData

@main
struct NottiApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TaskModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .tint(.green)
        }
        .modelContainer(sharedModelContainer)
    }
}
