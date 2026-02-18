import Testing
import SwiftData
@testable import TODOApp

// Unit and integration tests implemented starting Story 1.3
struct TODOAppTests {

    @Test func appLaunches() async throws {
        // Placeholder: verifies test target compiles and links correctly
        #expect(true)
    }

}

// MARK: - Story 1.3 Model Tests

@Suite("TaskItem Model")
struct TaskItemModelTests {

    @Test func defaultInitialization() {
        let task = TaskItem(title: "Test Task")
        #expect(task.title == "Test Task")
        #expect(task.isCompleted == false)
        #expect(task.dueDate == nil)
        #expect(task.reminderDate == nil)
        #expect(task.list == nil)
        #expect(task.sortOrder == 0)
    }

    @Test func customInitialization() {
        let id = UUID()
        let task = TaskItem(
            id: id,
            title: "Custom Task",
            isCompleted: true,
            sortOrder: 5
        )
        #expect(task.id == id)
        #expect(task.title == "Custom Task")
        #expect(task.isCompleted == true)
        #expect(task.sortOrder == 5)
    }

    @Test func uniqueIDsGenerated() {
        let task1 = TaskItem(title: "Task 1")
        let task2 = TaskItem(title: "Task 2")
        #expect(task1.id != task2.id)
    }
}

@Suite("TaskList Model")
struct TaskListModelTests {

    @Test func defaultInitialization() {
        let list = TaskList(name: "My List")
        #expect(list.name == "My List")
        #expect(list.colorHex == "007AFF")
        #expect(list.sortOrder == 0)
        #expect(list.tasks.isEmpty)
    }

    @Test func customColorHex() {
        let list = TaskList(name: "Red List", colorHex: "FF0000")
        #expect(list.colorHex == "FF0000")
    }

    @Test func uniqueIDsGenerated() {
        let list1 = TaskList(name: "List 1")
        let list2 = TaskList(name: "List 2")
        #expect(list1.id != list2.id)
    }
}

// MARK: - Story 1.2 Tests

@Suite("AppStorageKeys")
struct AppStorageKeysTests {

    @Test func hasCompletedOnboardingKey() {
        #expect(AppStorageKeys.hasCompletedOnboarding == "hasCompletedOnboarding")
    }

    @Test func selectedListIDKey() {
        #expect(AppStorageKeys.selectedListID == "selectedListID")
    }
}

@Suite("AppConstants")
struct AppConstantsTests {

    @Test func urlScheme() {
        #expect(AppConstants.urlScheme == "todoapp")
    }

    @Test func urlRoutesCreateTask() {
        #expect(AppConstants.URLRoutes.createTask == "create-task")
    }

    @Test func urlRoutesOpenTask() {
        #expect(AppConstants.URLRoutes.openTask == "open-task")
    }

    @Test func urlRoutesTaskIDQueryParam() {
        #expect(AppConstants.URLRoutes.taskIDQueryParam == "id")
    }

    @Test func bundleIdentifierNotEmpty() {
        #expect(!AppConstants.bundleIdentifier.isEmpty)
    }

    @Test func iCloudContainerIdentifierPrefixed() {
        #expect(AppConstants.iCloudContainerIdentifier.hasPrefix("iCloud."))
    }

    @Test func appGroupIdentifierPrefixed() {
        #expect(AppConstants.appGroupIdentifier.hasPrefix("group."))
    }
}

@Suite("AppCoordinator")
@MainActor
struct AppCoordinatorTests {

    @Test func initialState() {
        let coordinator = AppCoordinator()
        #expect(coordinator.isShowingAddTask == false)
        #expect(coordinator.pendingTaskID == nil)
    }

    @Test func handleCreateTaskURL() {
        let coordinator = AppCoordinator()
        let url = URL(string: "todoapp://create-task")!
        coordinator.handleURL(url)
        #expect(coordinator.isShowingAddTask == true)
    }

    @Test func handleOpenTaskURLWithValidID() {
        let coordinator = AppCoordinator()
        let uuid = UUID()
        let url = URL(string: "todoapp://open-task?id=\(uuid.uuidString)")!
        coordinator.handleURL(url)
        #expect(coordinator.pendingTaskID == uuid)
    }

    @Test func handleOpenTaskURLWithInvalidID() {
        let coordinator = AppCoordinator()
        let url = URL(string: "todoapp://open-task?id=not-a-uuid")!
        coordinator.handleURL(url)
        #expect(coordinator.pendingTaskID == nil)
    }

    @Test func handleOpenTaskURLMissingID() {
        let coordinator = AppCoordinator()
        let url = URL(string: "todoapp://open-task")!
        coordinator.handleURL(url)
        #expect(coordinator.pendingTaskID == nil)
    }

    @Test func handleUnknownSchemeIsIgnored() {
        let coordinator = AppCoordinator()
        let url = URL(string: "https://example.com/create-task")!
        coordinator.handleURL(url)
        #expect(coordinator.isShowingAddTask == false)
        #expect(coordinator.pendingTaskID == nil)
    }

    @Test func handleUnrecognizedRoute() {
        let coordinator = AppCoordinator()
        let url = URL(string: "todoapp://unknown-route")!
        coordinator.handleURL(url)
        #expect(coordinator.isShowingAddTask == false)
        #expect(coordinator.pendingTaskID == nil)
    }

    @Test func navigateToSetsTaskID() {
        let coordinator = AppCoordinator()
        let uuid = UUID()
        coordinator.navigateTo(taskID: uuid)
        #expect(coordinator.pendingTaskID == uuid)
    }
}
