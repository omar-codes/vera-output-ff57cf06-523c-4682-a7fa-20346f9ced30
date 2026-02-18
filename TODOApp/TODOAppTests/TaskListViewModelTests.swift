import Testing
import SwiftData
@testable import TODOApp

@Suite("TaskListViewModel")
@MainActor
struct TaskListViewModelTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([TaskItem.self, TaskList.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test func createTaskWithValidTitleSucceeds() async throws {
        let container = try makeContainer()
        let viewModel = TaskListViewModel(modelContainer: container)

        await viewModel.createTask(title: "Buy groceries")

        #expect(viewModel.showError == false)

        // Verify task was persisted
        let repo = TaskRepository(modelContainer: container)
        let tasks = try await repo.fetchTasks(in: nil)
        #expect(tasks.count == 1)
        #expect(tasks[0].title == "Buy groceries")
    }

    @Test func createTaskWithEmptyTitleDoesNotPersist() async throws {
        let container = try makeContainer()
        let viewModel = TaskListViewModel(modelContainer: container)

        await viewModel.createTask(title: "   ")

        #expect(viewModel.showError == false)

        // Verify no task was persisted
        let repo = TaskRepository(modelContainer: container)
        let tasks = try await repo.fetchTasks(in: nil)
        #expect(tasks.count == 0)
    }

    @Test func createTaskTrimsWhitespaceFromTitle() async throws {
        let container = try makeContainer()
        let viewModel = TaskListViewModel(modelContainer: container)

        await viewModel.createTask(title: "  Call dentist  ")

        let repo = TaskRepository(modelContainer: container)
        let tasks = try await repo.fetchTasks(in: nil)
        #expect(tasks.count == 1)
        #expect(tasks[0].title == "Call dentist")
    }

    @Test func deleteTaskRemovesFromList() async throws {
        let container = try makeContainer()
        let viewModel = TaskListViewModel(modelContainer: container)

        // Create a task first via repository
        let repo = TaskRepository(modelContainer: container)
        let task = try await repo.createTask(title: "To Delete", listID: nil)

        // Verify task exists
        let tasksBefore = try await repo.fetchTasks(in: nil)
        #expect(tasksBefore.count == 1)

        // Delete via ViewModel
        await viewModel.deleteTask(task)

        // Verify task is gone and no error
        #expect(viewModel.showError == false)
        let tasksAfter = try await repo.fetchTasks(in: nil)
        #expect(tasksAfter.count == 0)
    }

    @Test func deleteTaskDoesNotAffectParentList() async throws {
        let container = try makeContainer()
        let taskRepo = TaskRepository(modelContainer: container)
        let listRepo = ListRepository(modelContainer: container)
        let viewModel = TaskListViewModel(modelContainer: container)

        // Create a list and assign a task to it
        let list = try await listRepo.createList(name: "Work", colorHex: "007AFF")
        let task = try await taskRepo.createTask(title: "Work Task", listID: list.id)

        // Delete the task
        await viewModel.deleteTask(task)

        // Verify list still exists, task is gone
        let listsAfter = try await listRepo.fetchLists()
        #expect(listsAfter.count == 1)
        #expect(listsAfter[0].name == "Work")

        let tasksInList = try await taskRepo.fetchTasks(in: list)
        #expect(tasksInList.count == 0)
    }

    @Test func completeTaskSetsIsCompleted() async throws {
        let container = try makeContainer()
        let viewModel = TaskListViewModel(modelContainer: container)

        let repo = TaskRepository(modelContainer: container)
        let task = try await repo.createTask(title: "To Complete", listID: nil)
        #expect(task.isCompleted == false)

        await viewModel.completeTask(task)

        #expect(viewModel.showError == false)
        #expect(task.isCompleted == true)
    }

    @Test func completeTaskAlreadyCompletedNoError() async throws {
        let container = try makeContainer()
        let viewModel = TaskListViewModel(modelContainer: container)

        let repo = TaskRepository(modelContainer: container)
        let task = try await repo.createTask(title: "Already Done", listID: nil)

        // Complete once
        await viewModel.completeTask(task)
        #expect(task.isCompleted == true)

        // Complete again — should not error
        await viewModel.completeTask(task)
        #expect(viewModel.showError == false)
        #expect(task.isCompleted == true)
    }

    @Test func uncompleteTaskSetsIsCompletedFalse() async throws {
        let container = try makeContainer()
        let viewModel = TaskListViewModel(modelContainer: container)

        let repo = TaskRepository(modelContainer: container)
        let task = try await repo.createTask(title: "To Uncomplete", listID: nil)

        // Complete the task first
        await viewModel.completeTask(task)
        #expect(task.isCompleted == true)

        // Now uncomplete it
        await viewModel.uncompleteTask(task)

        #expect(viewModel.showError == false)
        #expect(task.isCompleted == false)
    }

    @Test func uncompleteTaskAlreadyIncompleteNoError() async throws {
        let container = try makeContainer()
        let viewModel = TaskListViewModel(modelContainer: container)

        let repo = TaskRepository(modelContainer: container)
        let task = try await repo.createTask(title: "Already Incomplete", listID: nil)
        #expect(task.isCompleted == false)

        // Uncomplete an already-incomplete task — should not error
        await viewModel.uncompleteTask(task)

        #expect(viewModel.showError == false)
        #expect(task.isCompleted == false)
    }
}
