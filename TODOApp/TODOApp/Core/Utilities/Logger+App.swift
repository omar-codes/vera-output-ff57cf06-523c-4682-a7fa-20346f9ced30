// Core/Utilities/Logger+App.swift
import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.unknown.todoapp"

    /// General app lifecycle events
    static let app = Logger(subsystem: subsystem, category: "App")

    /// Navigation and deep link events
    static let navigation = Logger(subsystem: subsystem, category: "Navigation")

    /// Data persistence and repository events
    static let data = Logger(subsystem: subsystem, category: "Data")

    /// Notification scheduling and delivery events
    static let notifications = Logger(subsystem: subsystem, category: "Notifications")

    /// Widget timeline events
    static let widget = Logger(subsystem: subsystem, category: "Widget")
}
