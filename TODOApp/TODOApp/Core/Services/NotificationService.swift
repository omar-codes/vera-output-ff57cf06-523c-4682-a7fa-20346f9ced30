// Core/Services/NotificationService.swift
import Foundation
import UserNotifications
import SwiftData

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    /// Category identifier used for all task reminder notifications.
    static let taskReminderCategoryIdentifier = "TASK_REMINDER"

    /// Action identifier for the "Mark Done" quick action (Story 2.3).
    /// Background action — does NOT bring app to foreground (FR18).
    static let markDoneActionIdentifier = "mark-done"

    /// Action identifier for the custom "Dismiss" quick action (Story 2.3).
    static let dismissActionIdentifier = "dismiss"

    private let center = UNUserNotificationCenter.current()

    private init() {}

    /// Schedule a local notification for a task's reminderDate.
    /// Only schedules if `task.reminderDate` is set and in the future.
    func scheduleNotification(for task: TaskItem) {
        guard let reminderDate = task.reminderDate, reminderDate > Date() else {
            Logger.notifications.info("No future reminderDate — skipping schedule")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = task.title
        if let dueDate = task.dueDate {
            content.body = "Due \(dueDate.formatted(date: .abbreviated, time: .omitted))"
        } else {
            content.body = "You have a reminder for this task."
        }
        content.sound = .default
        content.categoryIdentifier = NotificationService.taskReminderCategoryIdentifier

        var triggerComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        triggerComponents.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

        let identifier = "task-\(task.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error {
                Logger.notifications.error("Failed to schedule notification")
                _ = error
            }
        }
        Logger.notifications.info("Notification scheduled for task ID")
    }

    /// Cancel any pending notification for a task.
    func cancelNotification(for task: TaskItem) {
        let identifier = "task-\(task.id.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        Logger.notifications.info("Notification cancelled for task ID")
    }

    /// Request notification permission if not yet determined.
    /// Returns true if authorized (granted now or previously).
    func requestPermissionIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                Logger.notifications.info("Notification permission request completed")
                return granted
            } catch {
                Logger.notifications.error("Notification permission request failed")
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    /// Register notification categories with UNUserNotificationCenter.
    /// Called once at app launch. Includes "Mark Done" and "Dismiss" quick actions (Story 2.3).
    func registerNotificationCategories() {
        // Background action — options: [] means no foreground launch (FR18: without opening the app)
        let markDoneAction = UNNotificationAction(
            identifier: NotificationService.markDoneActionIdentifier,
            title: "Mark Done",
            options: []
        )
        // Destructive styling for visual differentiation; behavior is still a no-op dismiss
        let dismissAction = UNNotificationAction(
            identifier: NotificationService.dismissActionIdentifier,
            title: "Dismiss",
            options: [.destructive]
        )
        let taskReminderCategory = UNNotificationCategory(
            identifier: NotificationService.taskReminderCategoryIdentifier,
            actions: [markDoneAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]   // required for UNNotificationDismissActionIdentifier callback
        )
        center.setNotificationCategories([taskReminderCategory])
        Logger.notifications.info("Notification categories registered with actions")
    }

    /// Check current authorization status without prompting.
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    /// Reschedule notifications for all incomplete tasks with a future reminderDate.
    /// Called after network reconnection (FR20 — offline recovery).
    /// Idempotent: scheduling with an existing identifier replaces the pending request.
    /// - Parameter context: A ModelContext (background recommended) to fetch tasks from SwiftData.
    func rescheduleAllPendingNotifications(using context: ModelContext) {
        let now = Date()
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { task in
                !task.isCompleted && task.reminderDate != nil
            }
        )
        do {
            let tasks = try context.fetch(descriptor)
            // Filter to only future reminderDate (optional comparison not directly supported in SwiftData predicate)
            let futureTasks = tasks.filter { $0.reminderDate! > now }
            futureTasks.forEach { scheduleNotification(for: $0) }
            Logger.notifications.info("Rescheduled notifications for \(futureTasks.count) tasks after reconnect")
        } catch {
            Logger.notifications.error("Failed to fetch tasks for notification reschedule")
        }
    }
}
