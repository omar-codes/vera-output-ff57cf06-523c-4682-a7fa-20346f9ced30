// Core/Repositories/ListRepositoryProtocol.swift
import Foundation

protocol ListRepositoryProtocol: Sendable {
    func fetchLists() async throws -> [TaskList]
    func createList(name: String, colorHex: String) async throws -> TaskList
    func updateList(_ list: TaskList) async throws
    func deleteList(_ list: TaskList) async throws
}
