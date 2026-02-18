// TODOApp/AppDelegate.swift
import UIKit
import UserNotifications
import SwiftData
import OSLog

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// Set by TODOAppApp once the coordinator is available via .onAppear
    var coordinator: AppCoordinator?

    /// Set by TODOAppApp once the model container is available via .onAppear.
    /// Required by the mark-done notification action handler to create a background ModelContext.
    var modelContainer: ModelContainer?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationService.shared.registerNotificationCategories()
        return true
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when user taps a notification or takes an action.
    /// `nonisolated` required by Swift 6 strict concurrency — system calls this on an arbitrary thread.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        let identifier = response.notification.request.identifier
        // Identifier format: "task-<UUID>"
        guard identifier.hasPrefix("task-"),
              let uuid = UUID(uuidString: String(identifier.dropFirst("task-".count))) else {
            Logger.notifications.error("Received notification with unrecognized identifier format")
            return
        }

        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // User tapped notification body — navigate to task detail
            Task { @MainActor in
                self.coordinator?.navigateTo(taskID: uuid)
            }

        case NotificationService.markDoneActionIdentifier:
            // User tapped "Mark Done" — complete task in background, no foreground launch (FR18)
            Task { @MainActor in
                guard let container = self.modelContainer else {
                    Logger.notifications.error("ModelContainer not available for mark-done action")
                    return
                }
                await Self.completeTaskFromNotification(uuid: uuid, container: container)
            }

        case NotificationService.dismissActionIdentifier:
            // User tapped "Dismiss" button — no state change needed
            Logger.notifications.info("Task notification dismissed via action button")

        case UNNotificationDismissActionIdentifier:
            // User swiped to dismiss — no action needed
            Logger.notifications.info("Notification dismissed by user")

        default:
            Logger.notifications.info("Unhandled notification action received")
        }
    }

    /// Called when a notification fires while the app is in the foreground.
    /// `nonisolated` required by Swift 6 strict concurrency.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner + play sound even when app is in foreground (AC #4)
        completionHandler([.banner, .sound])
    }

    // MARK: - Private Helpers

    /// Complete a task identified by UUID using a background ModelContext.
    /// Called from the mark-done notification action handler.
    /// Static to avoid actor-isolation issues from a nonisolated context.
    private static func completeTaskFromNotification(uuid: UUID, container: ModelContainer) async {
        do {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate { task in task.id == uuid }
            )
            let matches = try context.fetch(descriptor)
            guard let task = matches.first else {
                Logger.notifications.error("Task not found for mark-done notification action")
                return
            }
            task.isCompleted = true
            task.modifiedAt = Date()
            try context.save()
            Logger.notifications.info("Task completed via notification action")

            // Post-mutation side effects (mandatory per architecture)
            await MainActor.run {
                WidgetService.shared.reloadTimelines()
            }
            // Cancel any other pending notifications for this task
            await MainActor.run {
                NotificationService.shared.cancelNotification(for: task)
            }
        } catch {
            Logger.notifications.error("Failed to complete task from notification action")
        }
    }
}
