// Features/Notifications/NotificationPermissionView.swift
import SwiftUI

struct NotificationPermissionView: View {
    let onContinue: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge")
                .font(.system(size: 48))
                .foregroundStyle(.accent)
                .accessibilityHidden(true)

            Text("Enable Notifications")
                .font(.title2.bold())

            Text("Enable notifications to get reminders when tasks are due.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Continue") {
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Continue to enable notifications")

            Button("Not Now") {
                onDismiss()
            }
            .foregroundStyle(.secondary)
            .accessibilityLabel("Dismiss notification permission prompt")
        }
        .padding()
    }
}
