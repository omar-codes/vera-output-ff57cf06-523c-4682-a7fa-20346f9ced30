// Core/Repositories/TaskRepositoryProtocol.swift
import Foundation

protocol TaskRepositoryProtocol: Sendable {
    func fetchTasks(in list: TaskList?) async throws -> [TaskItem]
    func createTask(title: String, listID: UUID?) async throws -> TaskItem
    func updateTask(_ task: TaskItem) async throws
    func deleteTask(_ task: TaskItem) async throws
    func completeTask(_ task: TaskItem) async throws
}
