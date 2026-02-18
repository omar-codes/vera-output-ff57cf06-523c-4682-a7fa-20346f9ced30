import SwiftUI
import SwiftData

@main
struct TODOAppApp: App {
    @State private var coordinator = AppCoordinator()

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TaskItem.self,
            TaskList.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitContainerIdentifier: AppConstants.iCloudContainerIdentifier
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // fatalError is acceptable here — ModelContainer failure is unrecoverable at launch
            Logger.app.critical("ModelContainer initialization failed: \(error.localizedDescription)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(coordinator)
        }
        .modelContainer(sharedModelContainer)
        .onOpenURL { url in
            coordinator.handleURL(url)
        }
    }
}
