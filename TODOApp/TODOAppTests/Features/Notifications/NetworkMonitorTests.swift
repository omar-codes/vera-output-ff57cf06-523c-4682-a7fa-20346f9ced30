import Testing
import SwiftData
@testable import TODOApp

@Suite("NetworkMonitor")
@MainActor
struct NetworkMonitorTests {

    @Test func initialIsConnectedIsFalse() {
        // 4.1: Verify isConnected initial state is false
        let monitor = NetworkMonitor()
        #expect(monitor.isConnected == false)
    }

    @Test func initialModelContainerIsNil() {
        // Verify modelContainer starts as nil before injection
        let monitor = NetworkMonitor()
        #expect(monitor.modelContainer == nil)
    }

    @Test func startMonitoringDoesNotCrash() {
        // 4.1: startMonitoring() must not crash
        let monitor = NetworkMonitor()
        monitor.startMonitoring()
        // If we reach here without crashing, startMonitoring works correctly
        #expect(Bool(true))
    }

    @Test func modelContainerInjectionWorks() throws {
        // Verify modelContainer can be injected after initialization
        let schema = Schema([TaskItem.self, TaskList.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])

        let monitor = NetworkMonitor()
        monitor.modelContainer = container

        #expect(monitor.modelContainer != nil)
    }
}
