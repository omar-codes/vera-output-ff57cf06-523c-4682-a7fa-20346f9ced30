// Core/Repositories/TaskRepository.swift
import Foundation
import SwiftData

final class TaskRepository: TaskRepositoryProtocol {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func fetchTasks(in list: TaskList?) async throws -> [TaskItem] {
        let context = ModelContext(modelContainer)
        let listID = list?.id
        let descriptor: FetchDescriptor<TaskItem>
        if let listID {
            descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate { task in task.list?.id == listID },
                sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
            )
        } else {
            // Inbox: tasks with no list
            descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate { task in task.list == nil },
                sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
            )
        }
        return try context.fetch(descriptor)
    }

    func createTask(title: String, listID: UUID?) async throws -> TaskItem {
        let context = ModelContext(modelContainer)
        let task = TaskItem(title: title)
        if let listID {
            let descriptor = FetchDescriptor<TaskList>(
                predicate: #Predicate { list in list.id == listID }
            )
            task.list = try context.fetch(descriptor).first
        }
        context.insert(task)
        try context.save()
        Logger.data.info("Task created successfully")
        return task
    }

    func updateTask(_ task: TaskItem) async throws {
        let context = ModelContext(modelContainer)
        task.modifiedAt = Date()
        try context.save()
        Logger.data.info("Task updated successfully")
    }

    func deleteTask(_ task: TaskItem) async throws {
        let context = ModelContext(modelContainer)
        context.delete(task)
        try context.save()
        Logger.data.info("Task deleted successfully")
    }

    func completeTask(_ task: TaskItem) async throws {
        let context = ModelContext(modelContainer)
        task.isCompleted = true
        task.modifiedAt = Date()
        try context.save()
        Logger.data.info("Task completed successfully")
    }
}
