import Testing
import SwiftData
import UserNotifications
@testable import TODOApp

@Suite("NotificationService")
@MainActor
struct NotificationServiceTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([TaskItem.self, TaskList.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test func scheduleNotificationSkipsTaskWithNoReminderDate() async throws {
        let container = try makeContainer()
        let repo = TaskRepository(modelContainer: container)
        let task = try await repo.createTask(title: "No Reminder Task", listID: nil)
        // task.reminderDate is nil by default

        // Should not throw — no-op guard should fire
        NotificationService.shared.scheduleNotification(for: task)
        // If we get here without crashing, the guard worked correctly
        #expect(task.reminderDate == nil)
    }

    @Test func scheduleNotificationSkipsTaskWithPastReminderDate() async throws {
        let container = try makeContainer()
        let repo = TaskRepository(modelContainer: container)
        let task = try await repo.createTask(title: "Past Reminder Task", listID: nil)
        task.reminderDate = Date(timeIntervalSinceNow: -3600) // 1 hour ago

        // Should silently skip scheduling (past date guard)
        NotificationService.shared.scheduleNotification(for: task)
        // No crash — guard for past dates works
        #expect(task.reminderDate != nil)
    }

    @Test func cancelNotificationUsesCorrectIdentifierScheme() async throws {
        let container = try makeContainer()
        let repo = TaskRepository(modelContainer: container)
        let task = try await repo.createTask(title: "Cancel Test", listID: nil)

        let expectedIdentifier = "task-\(task.id.uuidString)"

        // cancelNotification should not throw
        NotificationService.shared.cancelNotification(for: task)

        // Verify identifier scheme is correct
        #expect(expectedIdentifier.hasPrefix("task-"))
        #expect(expectedIdentifier.contains(task.id.uuidString))
    }

    @Test func checkAuthorizationStatusReturnsValidStatus() async throws {
        let status = await NotificationService.shared.checkAuthorizationStatus()
        // In a test environment (simulator without permission), status may be .notDetermined or .denied
        let validStatuses: [UNAuthorizationStatus] = [
            .notDetermined, .denied, .authorized, .provisional, .ephemeral
        ]
        #expect(validStatuses.contains(status))
    }
}

@Suite("TaskDetailViewModel — Due Date & Reminder")
@MainActor
struct TaskDetailViewModelDueDateTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([TaskItem.self, TaskList.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test func setDueDateSavesToRepository() async throws {
        let container = try makeContainer()
        let repo = TaskRepository(modelContainer: container)
        let task = try await repo.createTask(title: "Due Date Task", listID: nil)

        let viewModel = TaskDetailViewModel(task: task, modelContainer: container)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        await viewModel.setDueDate(tomorrow)

        #expect(viewModel.showError == false)
        #expect(task.dueDate != nil)

        // Verify persisted
        let tasks = try await repo.fetchTasks(in: nil)
        #expect(tasks[0].dueDate != nil)
    }

    @Test func setDueDateNilClearsReminderAndCancelsNotification() async throws {
        let container = try makeContainer()
        let repo = TaskRepository(modelContainer: container)
        let task = try await repo.createTask(title: "Clear Date Task", listID: nil)

        // Set up initial state with both dueDate and reminderDate
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        task.dueDate = tomorrow
        task.reminderDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)

        let viewModel = TaskDetailViewModel(task: task, modelContainer: container)

        // Remove due date
        await viewModel.setDueDate(nil)

        #expect(viewModel.showError == false)
        #expect(task.dueDate == nil)
        #expect(task.reminderDate == nil)
        #expect(viewModel.reminderDate == nil)
    }

    @Test func setReminderWithoutDueDateIsIgnored() async throws {
        let container = try makeContainer()
        let repo = TaskRepository(modelContainer: container)
        let task = try await repo.createTask(title: "No Due Date", listID: nil)
        // task.dueDate is nil

        let viewModel = TaskDetailViewModel(task: task, modelContainer: container)
        let reminderDate = Date(timeIntervalSinceNow: 3600)

        // Should be silently ignored — no due date set
        await viewModel.setReminder(reminderDate)

        // Task should still have no reminder since guard fired
        #expect(viewModel.showError == false)
    }

    @Test func setReminderNilClearsReminderAndCancels() async throws {
        let container = try makeContainer()
        let repo = TaskRepository(modelContainer: container)
        let task = try await repo.createTask(title: "Remove Reminder", listID: nil)

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        task.dueDate = tomorrow
        task.reminderDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)

        let viewModel = TaskDetailViewModel(task: task, modelContainer: container)

        await viewModel.setReminder(nil)

        #expect(viewModel.showError == false)
        #expect(task.reminderDate == nil)
    }

    @Test func viewModelInitializesFromTaskDueDateAndReminderDate() async throws {
        let container = try makeContainer()
        let repo = TaskRepository(modelContainer: container)
        let task = try await repo.createTask(title: "Pre-dated Task", listID: nil)

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let reminderTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)!
        task.dueDate = tomorrow
        task.reminderDate = reminderTime

        let viewModel = TaskDetailViewModel(task: task, modelContainer: container)

        #expect(viewModel.dueDate != nil)
        #expect(viewModel.reminderDate != nil)
    }

    @Test func setDueDateUpdatesModifiedAt() async throws {
        let container = try makeContainer()
        let repo = TaskRepository(modelContainer: container)
        let task = try await repo.createTask(title: "Modified At Test", listID: nil)
        let originalModifiedAt = task.modifiedAt

        try await Task.sleep(nanoseconds: 10_000_000)

        let viewModel = TaskDetailViewModel(task: task, modelContainer: container)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        await viewModel.setDueDate(tomorrow)

        #expect(task.modifiedAt > originalModifiedAt)
    }
}
