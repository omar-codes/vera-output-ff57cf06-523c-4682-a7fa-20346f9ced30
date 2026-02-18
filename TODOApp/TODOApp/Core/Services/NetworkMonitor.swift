// Core/Services/NetworkMonitor.swift
import Foundation
import Network
import SwiftData

/// Monitors network connectivity and triggers notification rescheduling on offline → online transition.
/// FR20: Reschedule notifications after device reconnects following an offline period.
@MainActor
@Observable
final class NetworkMonitor {
    var isConnected: Bool = false
    var modelContainer: ModelContainer?

    private var monitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.todoapp.network-monitor")
    private var previousStatus: NWPath.Status = .requiresConnection

    /// Start monitoring network path changes.
    /// Must be called after `modelContainer` is injected (from `TODOAppApp.onAppear`).
    func startMonitoring() {
        let monitor = NWPathMonitor()
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let wasOffline = self.previousStatus != .satisfied
            let isNowOnline = path.status == .satisfied
            self.previousStatus = path.status

            Task { @MainActor in
                self.isConnected = isNowOnline
                if wasOffline && isNowOnline {
                    // Transitioned from offline to online — reschedule pending notifications (FR20)
                    guard let container = self.modelContainer else { return }
                    let context = ModelContext(container)
                    NotificationService.shared.rescheduleAllPendingNotifications(using: context)
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit {
        monitor?.cancel()
    }
}
