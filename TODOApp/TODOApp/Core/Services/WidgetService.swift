// Core/Services/WidgetService.swift
import Foundation
import WidgetKit

@MainActor
final class WidgetService {
    static let shared = WidgetService()

    private init() {}

    func reloadTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
        Logger.widget.info("Widget timelines reload requested")
    }
}
