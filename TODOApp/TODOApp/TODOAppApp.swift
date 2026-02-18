import SwiftUI
import SwiftData

@main
struct TODOAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var coordinator = AppCoordinator()
    @State private var networkMonitor = NetworkMonitor()

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
                .onAppear {
                    // Pass coordinator reference to AppDelegate for notification tap routing
                    appDelegate.coordinator = coordinator
                    // Pass model container to AppDelegate for mark-done notification action (Story 2.3)
                    appDelegate.modelContainer = sharedModelContainer
                    // Inject container and start network monitoring for offline recovery (Story 2.4 — FR20)
                    networkMonitor.modelContainer = sharedModelContainer
                    networkMonitor.startMonitoring()
                }
        }
        .modelContainer(sharedModelContainer)
        .onOpenURL { url in
            coordinator.handleURL(url)
        }
    }
}
