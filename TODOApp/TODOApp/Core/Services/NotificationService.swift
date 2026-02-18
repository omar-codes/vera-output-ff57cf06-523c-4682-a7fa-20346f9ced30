// Core/Services/NotificationService.swift
import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    // Full implementation in Story 2.1
    func scheduleNotification(for task: TaskItem) {
        // No-op stub — implemented in Story 2.1
        Logger.notifications.info("Notification schedule requested (stub)")
    }

    func cancelNotification(for task: TaskItem) {
        // No-op stub — implemented in Story 2.1
        Logger.notifications.info("Notification cancel requested (stub)")
    }
}
