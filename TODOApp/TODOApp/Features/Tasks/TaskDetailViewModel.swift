// Features/Tasks/TaskDetailViewModel.swift
import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class TaskDetailViewModel {
    var editableTitle: String = ""
    var showError: Bool = false
    var errorMessage: String = ""
    var isDismissed: Bool = false

    // Story 2.1 — Due date & reminder state
    var dueDate: Date?
    var reminderDate: Date?
    var notificationsDisabledHint: Bool = false

    private let task: TaskItem
    private let repository: TaskRepositoryProtocol

    init(task: TaskItem, modelContainer: ModelContainer) {
        self.task = task
        self.editableTitle = task.title
        self.dueDate = task.dueDate
        self.reminderDate = task.reminderDate
        self.repository = TaskRepository(modelContainer: modelContainer)
    }

    /// Call on `onSubmit` or `onDisappear` to persist the edited title.
    func commitEdit() async {
        guard !isDismissed else { return }
        let trimmed = editableTitle.trimmingCharacters(in: .whitespaces)
        // Block empty titles — revert to original
        guard !trimmed.isEmpty else {
            editableTitle = task.title
            return
        }
        // No-op if title unchanged
        guard trimmed != task.title else { return }
        task.title = trimmed
        do {
            try await repository.updateTask(task)
            WidgetService.shared.reloadTimelines()
        } catch {
            Logger.data.error("TaskDetail update failed")
            errorMessage = "Something went wrong. Please try again."
            showError = true
        }
    }

    func deleteTask() async {
        do {
            NotificationService.shared.cancelNotification(for: task)
            try await repository.deleteTask(task)
            WidgetService.shared.reloadTimelines()
            isDismissed = true
        } catch {
            Logger.data.error("TaskDetail delete failed")
            errorMessage = "Something went wrong. Please try again."
            showError = true
        }
    }

    /// Set or remove the due date. Removing the due date also clears the reminder.
    func setDueDate(_ date: Date?) async {
        task.dueDate = date
        task.modifiedAt = Date()

        if date == nil {
            // Removing due date also clears reminder and cancels notification
            task.reminderDate = nil
            reminderDate = nil
            NotificationService.shared.cancelNotification(for: task)
        } else if task.reminderDate != nil {
            // Reschedule notification if reminder exists for the updated due date
            NotificationService.shared.scheduleNotification(for: task)
        }

        do {
            try await repository.updateTask(task)
            WidgetService.shared.reloadTimelines()
        } catch {
            Logger.data.error("TaskDetail setDueDate failed")
            errorMessage = "Something went wrong. Please try again."
            showError = true
        }
    }

    /// Set or remove the reminder time. Requires a due date to be set first.
    func setReminder(_ date: Date?) async {
        guard task.dueDate != nil || date == nil else {
            // Cannot set reminder without a due date
            return
        }

        if let date {
            // Request permission first (may show system dialog)
            let authorized = await NotificationService.shared.requestPermissionIfNeeded()
            task.reminderDate = date
            task.modifiedAt = Date()

            do {
                try await repository.updateTask(task)
                WidgetService.shared.reloadTimelines()
            } catch {
                Logger.data.error("TaskDetail setReminder failed")
                errorMessage = "Something went wrong. Please try again."
                showError = true
                return
            }

            if authorized {
                NotificationService.shared.scheduleNotification(for: task)
                notificationsDisabledHint = false
            } else {
                // Task saved but no notification scheduled — graceful degradation
                notificationsDisabledHint = true
            }
        } else {
            // Remove reminder
            task.reminderDate = nil
            task.modifiedAt = Date()
            NotificationService.shared.cancelNotification(for: task)
            do {
                try await repository.updateTask(task)
                WidgetService.shared.reloadTimelines()
            } catch {
                Logger.data.error("TaskDetail clearReminder failed")
                errorMessage = "Something went wrong. Please try again."
                showError = true
            }
            notificationsDisabledHint = false
        }
    }
}
