// Features/Tasks/TaskRowView.swift
import SwiftUI

struct TaskRowView: View {
    let task: TaskItem

    private var isOverdue: Bool {
        guard let dueDate = task.dueDate, !task.isCompleted else { return false }
        return dueDate < Date()
    }

    var body: some View {
        HStack(spacing: 12) {
            // Completion indicator (tap area expanded in Story 1.6)
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(task.isCompleted ? Color.accentColor : .secondary)
                .accessibilityLabel(task.isCompleted ? "Completed" : "Incomplete")
                .accessibilityAddTraits(.isButton)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                if let dueDate = task.dueDate {
                    Text(dueDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(isOverdue ? Color.red : .secondary)
                        .accessibilityLabel(isOverdue
                            ? "Overdue: \(dueDate.formatted(date: .abbreviated, time: .omitted))"
                            : "Due: \(dueDate.formatted(date: .abbreviated, time: .omitted))"
                        )
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Tap to open task details")
    }

    private var accessibilityLabel: String {
        var label = task.title
        if task.isCompleted { label += ", completed" }
        if let dueDate = task.dueDate {
            if isOverdue {
                label += ", overdue"
            } else {
                label += ", due \(dueDate.formatted(date: .abbreviated, time: .omitted))"
            }
        }
        return label
    }
}
