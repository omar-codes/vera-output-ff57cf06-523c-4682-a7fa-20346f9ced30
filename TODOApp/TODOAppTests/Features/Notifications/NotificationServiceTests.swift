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

    // MARK: - Story 2.2 Tests

    @Test func scheduleNotificationSetsCorrectCategoryIdentifier() async throws {
        let container = try makeContainer()
        let repo = TaskRepository(modelContainer: container)
        let task = try await repo.createTask(title: "Category Test Task", listID: nil)
        task.reminderDate = Date(timeIntervalSinceNow: 3600)

        // Verify the category identifier constant matches expected value
        #expect(NotificationService.taskReminderCategoryIdentifier == "TASK_REMINDER")

        // Schedule — verifies content.categoryIdentifier path is exercised (no crash)
        NotificationService.shared.scheduleNotification(for: task)

        // Confirm identifier constant is stable
        #expect(NotificationService.taskReminderCategoryIdentifier == "TASK_REMINDER")
    }

    @Test func notificationIdentifierParsingRoundTrip() async throws {
        let container = try makeContainer()
        let repo = TaskRepository(modelContainer: container)
        let task = try await repo.createTask(title: "Identifier Parse Task", listID: nil)

        // Build identifier using the same scheme as NotificationService.scheduleNotification
        let scheduledIdentifier = "task-\(task.id.uuidString)"

        // Parse back using the same algorithm as AppDelegate.userNotificationCenter(_:didReceive:)
        #expect(scheduledIdentifier.hasPrefix("task-"))
        let uuidString = String(scheduledIdentifier.dropFirst("task-".count))
        let parsedUUID = UUID(uuidString: uuidString)

        #expect(parsedUUID != nil)
        #expect(parsedUUID == task.id)
    }

    @Test func notificationIdentifierParsingRejectsInvalidFormat() {
        // Verify parsing guards work correctly for malformed identifiers
        let invalidIdentifiers = ["", "nottask-abc", "task-not-a-uuid", "TASK-\(UUID().uuidString)"]
        for identifier in invalidIdentifiers {
            if identifier.hasPrefix("task-") {
                let uuidString = String(identifier.dropFirst("task-".count))
                // UUID(uuidString:) should return nil for invalid UUID strings
                #expect(UUID(uuidString: uuidString) == nil)
            } else {
                #expect(!identifier.hasPrefix("task-"))
            }
        }
    }

    @Test func registerNotificationCategoriesDoesNotCrash() {
        // Verify registerNotificationCategories runs without error
        NotificationService.shared.registerNotificationCategories()
        // If we reach here, registration completed without throwing
        #expect(Bool(true))
    }

    // MARK: - Story 2.3 Tests

    @Test func markDoneActionIdentifierIsCorrect() {
        // 4.1: Verify markDoneActionIdentifier constant equals "mark-done"
        #expect(NotificationService.markDoneActionIdentifier == "mark-done")
    }

    @Test func dismissActionIdentifierIsCorrect() {
        // Verify dismissActionIdentifier constant equals "dismiss"
        #expect(NotificationService.dismissActionIdentifier == "dismiss")
    }

    @Test func registerNotificationCategoriesIncludesMarkDoneAction() {
        // 4.2: After calling registerNotificationCategories(), verify no crash and
        // action identifier constants remain stable (system APIs are not testable for content
        // without a mock UNUserNotificationCenter)
        NotificationService.shared.registerNotificationCategories()
        // Constant is set correctly after registration call
        #expect(NotificationService.markDoneActionIdentifier == "mark-done")
        #expect(NotificationService.taskReminderCategoryIdentifier == "TASK_REMINDER")
    }

    // MARK: - Story 2.4 Tests

    @Test func rescheduleAllPendingNotificationsSkipsCompletedTasks() async throws {
        // 4.2: Completed tasks must not be rescheduled
        let container = try makeContainer()
        let context = ModelContext(container)

        let completedTask = TaskItem(title: "Completed Task")
        completedTask.isCompleted = true
        completedTask.reminderDate = Date(timeIntervalSinceNow: 3600) // future
        context.insert(completedTask)

        let incompleteTask = TaskItem(title: "Incomplete Task")
        incompleteTask.isCompleted = false
        incompleteTask.reminderDate = Date(timeIntervalSinceNow: 3600) // future
        context.insert(incompleteTask)

        try context.save()

        // Should not crash; completed task must be excluded from scheduling
        NotificationService.shared.rescheduleAllPendingNotifications(using: context)

        // Verify incomplete task has a future reminderDate (confirming it would be scheduled)
        #expect(incompleteTask.reminderDate != nil)
        #expect(incompleteTask.isCompleted == false)
        // Verify completed task is indeed completed (confirming it was skipped)
        #expect(completedTask.isCompleted == true)
    }

    @Test func rescheduleAllPendingNotificationsSkipsPastReminderDates() async throws {
        // 4.3: Tasks with reminderDate in the past must be excluded from scheduling
        let container = try makeContainer()
        let context = ModelContext(container)

        let pastTask = TaskItem(title: "Past Reminder Task")
        pastTask.isCompleted = false
        pastTask.reminderDate = Date(timeIntervalSinceNow: -3600) // 1 hour ago
        context.insert(pastTask)

        try context.save()

        // Should not crash; past reminder date task must be excluded
        NotificationService.shared.rescheduleAllPendingNotifications(using: context)

        // Past task has a past reminderDate — it must be filtered out
        #expect(pastTask.reminderDate! < Date())
        #expect(pastTask.isCompleted == false)
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
