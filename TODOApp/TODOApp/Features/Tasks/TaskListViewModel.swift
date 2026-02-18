// Features/Tasks/TaskListViewModel.swift
import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class TaskListViewModel {
    var showError: Bool = false
    var errorMessage: String = ""

    // Repository injected in Story 1.4 when create/edit operations are added
    // For Story 1.3, the ViewModel is a lightweight error handler only
    // Tasks are driven by @Query in TaskListView directly

    func handleError(_ error: Error) {
        Logger.data.error("TaskList operation failed")
        errorMessage = "Something went wrong. Please try again."
        showError = true
    }
}
