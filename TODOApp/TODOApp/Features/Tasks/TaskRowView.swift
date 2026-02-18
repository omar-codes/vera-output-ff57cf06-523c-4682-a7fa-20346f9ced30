// Features/Tasks/TaskRowView.swift
import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    var onComplete: (() -> Void)? = nil
    var onUncomplete: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var animateCheckmark: Bool = false

    private var isOverdue: Bool {
        guard let dueDate = task.dueDate, !task.isCompleted else { return false }
        return dueDate < Date()
    }

    var body: some View {
        HStack(spacing: 12) {
            // Completion button — tappable circle; tap does NOT propagate to row onTapGesture
            Button {
                if task.isCompleted {
                    onUncomplete?()
                } else {
                    if let onComplete {
                        if !reduceMotion {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                animateCheckmark = true
                            }
                        }
                        onComplete()
                    }
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? Color.accentColor : .secondary)
                    .scaleEffect(animateCheckmark ? 1.25 : 1.0)
            }
            .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")
            .buttonStyle(.plain)

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
        .onChange(of: task.isCompleted) { _, _ in
            animateCheckmark = false
        }
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
