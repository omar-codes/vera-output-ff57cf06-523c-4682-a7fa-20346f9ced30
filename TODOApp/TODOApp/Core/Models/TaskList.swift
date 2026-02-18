// Core/Models/TaskList.swift
import Foundation
import SwiftData

@Model
final class TaskList {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date
    var sortOrder: Int
    @Relationship(deleteRule: .cascade) var tasks: [TaskItem]

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "007AFF",
        createdAt: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.tasks = []
    }
}
