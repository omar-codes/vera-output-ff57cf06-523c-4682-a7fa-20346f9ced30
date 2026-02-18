// Features/Tasks/TaskDetailView.swift
import SwiftUI
import SwiftData

struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFieldFocused: Bool

    @State private var viewModel: TaskDetailViewModel

    init(task: TaskItem, modelContainer: ModelContainer) {
        _viewModel = State(initialValue: TaskDetailViewModel(task: task, modelContainer: modelContainer))
    }

    var body: some View {
        Form {
            Section("Title") {
                TextField("Task title", text: Bindable(viewModel).editableTitle)
                    .font(.body)
                    .focused($titleFieldFocused)
                    .onSubmit {
                        Task { await viewModel.commitEdit() }
                    }
                    .accessibilityLabel("Task title")
                    .accessibilityHint("Edit the task title")
            }

            // Due Date section
            Section {
                if viewModel.dueDate == nil {
                    Button("Add Due Date") {
                        let tomorrow = Calendar.current.date(
                            byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())
                        ) ?? Date()
                        let defaultDate = Calendar.current.date(
                            bySettingHour: 12, minute: 0, second: 0, of: tomorrow
                        ) ?? tomorrow
                        viewModel.dueDate = defaultDate
                        Task { await viewModel.setDueDate(defaultDate) }
                    }
                    .accessibilityLabel("Add due date")
                } else {
                    DatePicker(
                        "Due Date",
                        selection: Binding(
                            get: { viewModel.dueDate ?? Date() },
                            set: { newDate in
                                viewModel.dueDate = newDate
                                Task { await viewModel.setDueDate(newDate) }
                            }
                        ),
                        displayedComponents: [.date]
                    )
                    .accessibilityLabel("Due date")

                    Button("Remove Due Date", role: .destructive) {
                        viewModel.dueDate = nil
                        viewModel.reminderDate = nil
                        Task { await viewModel.setDueDate(nil) }
                    }
                    .accessibilityLabel("Remove due date")
                }
            } header: {
                Text("Due Date")
            }

            // Reminder section — only visible when a due date is set
            if viewModel.dueDate != nil {
                Section {
                    if viewModel.reminderDate == nil {
                        Button("Add Reminder") {
                            let defaultReminder = Calendar.current.date(
                                bySettingHour: 9, minute: 0, second: 0,
                                of: viewModel.dueDate ?? Date()
                            ) ?? Date()
                            viewModel.reminderDate = defaultReminder
                            Task { await viewModel.setReminder(defaultReminder) }
                        }
                        .accessibilityLabel("Add reminder")
                    } else {
                        DatePicker(
                            "Reminder",
                            selection: Binding(
                                get: { viewModel.reminderDate ?? Date() },
                                set: { newDate in
                                    viewModel.reminderDate = newDate
                                    Task { await viewModel.setReminder(newDate) }
                                }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .accessibilityLabel("Reminder time")

                        Button("Remove Reminder", role: .destructive) {
                            viewModel.reminderDate = nil
                            Task { await viewModel.setReminder(nil) }
                        }
                        .accessibilityLabel("Remove reminder")
                    }

                    if viewModel.notificationsDisabledHint {
                        Text("Notifications are disabled. Enable them in Settings to receive reminders.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Notifications are disabled. Go to Settings to enable reminders.")
                    }
                } header: {
                    Text("Reminder")
                }
            }

            Section {
                Button(role: .destructive) {
                    Task { @MainActor in
                        await viewModel.deleteTask()
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("Delete Task")
                        Spacer()
                    }
                }
                .accessibilityLabel("Delete task")
            }
        }
        .navigationTitle("Edit Task")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            Task { await viewModel.commitEdit() }
        }
        .onChange(of: viewModel.isDismissed) { _, isDismissed in
            if isDismissed {
                dismiss()
            }
        }
        .alert("Error", isPresented: Bindable(viewModel).showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}
