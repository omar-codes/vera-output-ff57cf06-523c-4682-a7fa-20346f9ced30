// Features/Tasks/TaskListViewModel.swift
import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class TaskListViewModel {
    var showError: Bool = false
    var errorMessage: String = ""

    private let repository: TaskRepositoryProtocol

    init(modelContainer: ModelContainer) {
        self.repository = TaskRepository(modelContainer: modelContainer)
    }

    func createTask(title: String, listID: UUID? = nil) async {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            _ = try await repository.createTask(title: trimmed, listID: listID)
            WidgetService.shared.reloadTimelines()
        } catch {
            handleError(error)
        }
    }

    func deleteTask(_ task: TaskItem) async {
        do {
            NotificationService.shared.cancelNotification(for: task)
            try await repository.deleteTask(task)
            WidgetService.shared.reloadTimelines()
        } catch {
            handleError(error)
        }
    }

    func completeTask(_ task: TaskItem) async {
        do {
            NotificationService.shared.cancelNotification(for: task)
            try await repository.completeTask(task)
            WidgetService.shared.reloadTimelines()
        } catch {
            handleError(error)
        }
    }

    func uncompleteTask(_ task: TaskItem) async {
        do {
            task.isCompleted = false
            task.modifiedAt = Date()
            try await repository.updateTask(task)
            WidgetService.shared.reloadTimelines()
        } catch {
            handleError(error)
        }
    }

    func handleError(_ error: Error) {
        Logger.data.error("TaskList operation failed")
        errorMessage = "Something went wrong. Please try again."
        showError = true
    }
}
