// Core/Utilities/AppConstants.swift
import Foundation

enum AppConstants {
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.unknown.todoapp"
    static let iCloudContainerIdentifier = "iCloud.\(bundleIdentifier)"
    static let appGroupIdentifier = "group.\(bundleIdentifier)"
    static let urlScheme = "todoapp"

    enum URLRoutes {
        static let createTask = "create-task"
        static let openTask = "open-task"
        static let taskIDQueryParam = "id"
    }
}
