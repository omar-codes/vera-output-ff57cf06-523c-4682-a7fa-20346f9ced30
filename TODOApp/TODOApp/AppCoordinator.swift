// TODOApp/AppCoordinator.swift
import SwiftUI
import Observation

@MainActor
@Observable
final class AppCoordinator {
    var navigationPath = NavigationPath()
    var isShowingAddTask: Bool = false
    var pendingTaskID: UUID? = nil

    func navigateTo(taskID: UUID) {
        pendingTaskID = taskID
        navigationPath.append(taskID)
    }

    func handleURL(_ url: URL) {
        guard url.scheme == AppConstants.urlScheme else { return }

        switch url.host {
        case AppConstants.URLRoutes.createTask:
            isShowingAddTask = true

        case AppConstants.URLRoutes.openTask:
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let idString = components.queryItems?.first(where: { $0.name == AppConstants.URLRoutes.taskIDQueryParam })?.value,
               let uuid = UUID(uuidString: idString) {
                navigateTo(taskID: uuid)
            } else {
                Logger.navigation.error("Invalid open-task URL — missing or malformed id parameter")
            }

        default:
            Logger.navigation.info("Unrecognized URL route received")
        }
    }
}
