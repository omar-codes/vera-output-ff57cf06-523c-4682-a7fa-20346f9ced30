// Features/Tasks/TaskListView.swift
import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext

    // @Query for Inbox: tasks where list == nil, sorted by sortOrder then createdAt
    @Query(
        filter: #Predicate<TaskItem> { task in task.list == nil },
        sort: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
    )
    private var tasks: [TaskItem]

    @State private var viewModel = TaskListViewModel()

    var body: some View {
        Group {
            if tasks.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(tasks) { task in
                        TaskRowView(task: task)
                            .onTapGesture {
                                coordinator.navigateTo(taskID: task.id)
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Inbox")
        .navigationDestination(for: UUID.self) { _ in
            // TaskDetailView added in Story 1.4
            Text("Task Detail — Story 1.4")
        }
        .sheet(isPresented: Bindable(coordinator).isShowingAddTask) {
            // AddTaskView added in Story 1.4
            Text("Add Task — Story 1.4")
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    coordinator.isShowingAddTask = true
                } label: {
                    Image(systemName: "plus")
                        .accessibilityLabel("Add task")
                }
            }
        }
        .alert("Error", isPresented: Bindable(viewModel).showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No tasks in Inbox")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Tap + to add your first task")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No tasks in Inbox. Tap plus to add your first task.")
    }
}
