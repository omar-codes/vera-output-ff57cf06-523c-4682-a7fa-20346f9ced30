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

    @State private var viewModel: TaskListViewModel?

    var body: some View {
        Group {
            if tasks.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(tasks) { task in
                        TaskRowView(task: task, onComplete: {
                            Task { @MainActor in
                                await viewModel?.completeTask(task)
                            }
                        }, onUncomplete: {
                            Task { @MainActor in
                                await viewModel?.uncompleteTask(task)
                            }
                        })
                        .onTapGesture {
                            coordinator.navigateTo(taskID: task.id)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { @MainActor in
                                        await viewModel?.deleteTask(task)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .accessibilityLabel("Delete task")
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Inbox")
        .navigationDestination(for: UUID.self) { taskID in
            if let task = tasks.first(where: { $0.id == taskID }) {
                TaskDetailView(task: task, modelContainer: modelContext.container)
            }
        }
        .sheet(isPresented: Bindable(coordinator).isShowingAddTask) {
            AddTaskView(modelContainer: modelContext.container)
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
        .task {
            if viewModel == nil {
                viewModel = TaskListViewModel(modelContainer: modelContext.container)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel?.showError ?? false },
            set: { viewModel?.showError = $0 }
        )) {
            Button("OK") {}
        } message: {
            Text(viewModel?.errorMessage ?? "")
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
