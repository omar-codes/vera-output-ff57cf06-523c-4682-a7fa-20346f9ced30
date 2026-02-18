import SwiftUI
import SwiftData

@main
struct TODOAppApp: App {
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            // Models added in Story 1.3: TaskItem, TaskList
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
