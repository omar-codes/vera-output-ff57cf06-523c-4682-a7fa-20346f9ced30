// Core/Models/TaskItem.swift
import Foundation
import SwiftData

@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var isCompleted: Bool
    var dueDate: Date?
    var reminderDate: Date?
    var createdAt: Date
    var modifiedAt: Date
    var list: TaskList?
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        reminderDate: Date? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        list: TaskList? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.reminderDate = reminderDate
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.list = list
        self.sortOrder = sortOrder
    }
}
