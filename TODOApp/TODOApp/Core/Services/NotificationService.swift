// Core/Services/NotificationService.swift
import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

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

    /// Check current authorization status without prompting.
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
}
