import Testing
import SwiftData
@testable import TODOApp

@Suite("TaskRepository")
struct TaskRepositoryTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([TaskItem.self, TaskList.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test func createTaskInInbox() async throws {
        let container = try makeContainer()
        let repo = TaskRepository(modelContainer: container)

        let task = try await repo.createTask(title: "Inbox Task", listID: nil)

        #expect(task.title == "Inbox Task")
        #expect(task.isCompleted == false)
        #expect(task.list == nil)
    }

    @Test func fetchInboxTasks() async throws {
        let container = try makeContainer()
        let repo = TaskRepository(modelContainer: container)

        _ = try await repo.createTask(title: "Task A", listID: nil)
        _ = try await repo.createTask(title: "Task B", listID: nil)

        let tasks = try await repo.fetchTasks(in: nil)
        #expect(tasks.count == 2)
    }

    @Test func fetchTasksInList() async throws {
        let container = try makeContainer()
        let taskRepo = TaskRepository(modelContainer: container)
        let listRepo = ListRepository(modelContainer: container)

        let list = try await listRepo.createList(name: "Work", colorHex: "007AFF")
        _ = try await taskRepo.createTask(title: "Work Task", listID: list.id)
        _ = try await taskRepo.createTask(title: "Inbox Task", listID: nil)

        let workTasks = try await taskRepo.fetchTasks(in: list)
        let inboxTasks = try await taskRepo.fetchTasks(in: nil)

        #expect(workTasks.count == 1)
        #expect(inboxTasks.count == 1)
    }

    @Test func completeTask() async throws {
        let container = try makeContainer()
        let repo = TaskRepository(modelContainer: container)

        let task = try await repo.createTask(title: "To Complete", listID: nil)
        #expect(task.isCompleted == false)

        try await repo.completeTask(task)
        #expect(task.isCompleted == true)
    }

    @Test func deleteTask() async throws {
        let container = try makeContainer()
        let repo = TaskRepository(modelContainer: container)

        _ = try await repo.createTask(title: "To Delete", listID: nil)
        let tasks = try await repo.fetchTasks(in: nil)
        #expect(tasks.count == 1)

        try await repo.deleteTask(tasks[0])
        let remaining = try await repo.fetchTasks(in: nil)
        #expect(remaining.count == 0)
    }
}

@Suite("ListRepository")
struct ListRepositoryTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([TaskItem.self, TaskList.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test func createList() async throws {
        let container = try makeContainer()
        let repo = ListRepository(modelContainer: container)

        let list = try await repo.createList(name: "Personal", colorHex: "FF0000")
        #expect(list.name == "Personal")
        #expect(list.colorHex == "FF0000")
    }

    @Test func fetchLists() async throws {
        let container = try makeContainer()
        let repo = ListRepository(modelContainer: container)

        _ = try await repo.createList(name: "List 1", colorHex: "007AFF")
        _ = try await repo.createList(name: "List 2", colorHex: "34C759")

        let lists = try await repo.fetchLists()
        #expect(lists.count == 2)
    }

    @Test func deleteListCascadesTasks() async throws {
        let container = try makeContainer()
        let listRepo = ListRepository(modelContainer: container)
        let taskRepo = TaskRepository(modelContainer: container)

        let list = try await listRepo.createList(name: "To Delete", colorHex: "007AFF")
        _ = try await taskRepo.createTask(title: "Task in list", listID: list.id)

        let tasksBefore = try await taskRepo.fetchTasks(in: list)
        #expect(tasksBefore.count == 1)

        try await listRepo.deleteList(list)

        let listsAfter = try await listRepo.fetchLists()
        #expect(listsAfter.count == 0)
    }
}
