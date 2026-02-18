// Features/Tasks/AddTaskView.swift
import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var showValidationError: Bool = false
    @FocusState private var isFocused: Bool
    @State private var viewModel: TaskListViewModel

    init(modelContainer: ModelContainer) {
        _viewModel = State(initialValue: TaskListViewModel(modelContainer: modelContainer))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Task title", text: $title)
                    .font(.body)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .focused($isFocused)
                    .onSubmit { submitTask() }
                    .accessibilityLabel("Task title")
                    .accessibilityHint("Enter the name of your task")

                if showValidationError {
                    Text("Title cannot be empty")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .accessibilityLabel("Error: Title cannot be empty")
                }

                Divider()
                    .padding(.horizontal, 16)

                Spacer()
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel adding task")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { submitTask() }
                        .accessibilityLabel("Add task")
                }
            }
            .onAppear { isFocused = true }
        }
        .alert("Error", isPresented: Bindable(viewModel).showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private func submitTask() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            showValidationError = true
            return
        }
        showValidationError = false
        Task { @MainActor in
            await viewModel.createTask(title: trimmed)
            if !viewModel.showError {
                dismiss()
            }
        }
    }
}
