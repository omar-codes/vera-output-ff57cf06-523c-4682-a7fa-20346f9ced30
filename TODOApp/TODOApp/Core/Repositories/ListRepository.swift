// Core/Repositories/ListRepository.swift
import Foundation
import SwiftData

final class ListRepository: ListRepositoryProtocol {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func fetchLists() async throws -> [TaskList] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<TaskList>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    func createList(name: String, colorHex: String) async throws -> TaskList {
        let context = ModelContext(modelContainer)
        let list = TaskList(name: name, colorHex: colorHex)
        context.insert(list)
        try context.save()
        Logger.data.info("List created successfully")
        return list
    }

    func updateList(_ list: TaskList) async throws {
        let context = ModelContext(modelContainer)
        try context.save()
        Logger.data.info("List updated successfully")
    }

    func deleteList(_ list: TaskList) async throws {
        let context = ModelContext(modelContainer)
        context.delete(list)
        try context.save()
        Logger.data.info("List deleted — cascade deletes tasks")
    }
}
