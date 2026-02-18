# Story 1.5: Delete Task

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an iPhone user,
I want to delete a task I no longer need,
So that my task list stays clean and relevant.

## Acceptance Criteria

1. **Given** the user is viewing the task list **When** they swipe left on a task row **Then**:
   - A destructive "Delete" swipe action appears on the task row
   - The action is visually red/destructive

2. **Given** the delete swipe action is visible **When** the user taps "Delete" **Then**:
   - `TaskListViewModel.deleteTask(_:)` is called
   - `TaskRepository.deleteTask(_:)` removes the task from SwiftData on a background context
   - `NotificationService.shared.cancelNotification(for:)` is called (cancels any pending reminder)
   - `WidgetService.shared.reloadTimelines()` is called
   - The task row is removed from the list with an animation

3. **Given** a task in a custom list is deleted **When** the deletion completes **Then**:
   - The `TaskList` is NOT affected — only the `TaskItem` is removed
   - No cascade deletion of the parent list occurs

4. **Given** the user is in `TaskDetailView` **When** they tap a delete button/action **Then**:
   - The same deletion flow executes (repository delete + notification cancel + widget reload)
   - The user is navigated back to the task list after deletion

5. **Given** any delete operation fails **When** an error is thrown **Then**:
   - Errors are caught by the ViewModel, logged privately via `Logger` (no task content)
   - A generic "Something went wrong" banner is shown
   - The UI never displays raw error messages

## Tasks / Subtasks

- [x] Task 1: Add `deleteTask(_:)` to `TaskListViewModel` and wire swipe-to-delete in `TaskListView` (AC: #1, #2, #3, #5)
  - [x] 1.1 Add `deleteTask(_ task: TaskItem) async` method to `TaskListViewModel.swift` — calls `repository.deleteTask(_:)`, then `NotificationService.shared.cancelNotification(for:)`, then `WidgetService.shared.reloadTimelines()`; catches errors with `handleError(_:)`
  - [x] 1.2 Add `.swipeActions(edge: .trailing)` on `TaskRowView` inside `ForEach` in `TaskListView.swift` — destructive `Button("Delete", role: .destructive)` that calls `viewModel.deleteTask(task)` via `Task { @MainActor in }`
  - [x] 1.3 Ensure `TaskListView` has access to the shared `TaskListViewModel` with repository (currently `TaskListView` uses a lightweight `viewModel`; update to pass `modelContainer` so it can call `deleteTask`)

- [x] Task 2: Add delete action to `TaskDetailView` with back-navigation (AC: #4, #5)
  - [x] 2.1 Add `deleteTask()` method to `TaskDetailViewModel.swift` — calls `repository.deleteTask(task)`, then `NotificationService.shared.cancelNotification(for: task)`, then `WidgetService.shared.reloadTimelines()`; sets `isDismissed = true` on success
  - [x] 2.2 Add `isDismissed: Bool = false` observable property to `TaskDetailViewModel`
  - [x] 2.3 Add toolbar delete button (`.destructiveAction` or `.navigationBarTrailing`) to `TaskDetailView.swift` — calls `Task { @MainActor in await viewModel.deleteTask() }`, and use `.onChange(of: viewModel.isDismissed)` to call `dismiss()` when set to `true`

- [x] Task 3: Unit tests for delete operations (AC: #1–#5)
  - [x] 3.1 Add `deleteTaskRemovesFromList` test to `TaskListViewModelTests.swift` — creates task, calls `viewModel.deleteTask(task)`, verifies 0 tasks remain
  - [x] 3.2 Add `deleteTaskDoesNotAffectParentList` test — creates a `TaskList`, assigns a task to it, deletes the task, verifies the list still exists with 0 tasks
  - [x] 3.3 Register no new test files needed (use existing `TaskListViewModelTests.swift`)

- [x] Task 4: Register new/modified files in `project.pbxproj` (no new source files in this story — all modifications to existing files; no pbxproj changes needed for Story 1.5)

## Dev Notes

### TaskListView.swift — Adding Swipe-to-Delete

The current `TaskListView.swift` (Story 1.4 state) has a `List { ForEach(tasks) { task in TaskRowView(task:).onTapGesture { ... } } }` pattern. Add `.swipeActions` on the `ForEach` content:

```swift
// In TaskListView.swift — inside List { ForEach(tasks) { task in ... } }
TaskRowView(task: task)
    .onTapGesture {
        coordinator.navigateTo(taskID: task.id)
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
        Button(role: .destructive) {
            Task { @MainActor in
                await viewModel.deleteTask(task)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .accessibilityLabel("Delete task")
    }
```

**Critical: TaskListView needs a ViewModel with repository access.**

Current `TaskListView` (after Story 1.4) uses `@State private var viewModel = TaskListViewModel()` — the lightweight version (no repository) OR a container-injected version. Per Story 1.4 Dev Notes, the recommendation was to keep `TaskListView`'s viewModel as the lightweight one, with `AddTaskView` owning the repository-injected ViewModel.

**For Story 1.5, `TaskListView` MUST have a repository-backed ViewModel** to call `deleteTask`. Update `TaskListView`:

```swift
// BEFORE (lightweight, no repo):
@State private var viewModel = TaskListViewModel()

// AFTER (Story 1.5 — inject via onAppear or pass from parent):
@Environment(\.modelContext) private var modelContext
@State private var viewModel: TaskListViewModel?

// In body, use optional chaining, OR:
// Simplest correct approach — initialize lazily:
@State private var viewModel: TaskListViewModel = TaskListViewModel.__placeholder()
// Replaced in .onAppear:
.onAppear {
    if viewModel needs replacing {
        viewModel = TaskListViewModel(modelContainer: modelContext.container)
    }
}
```

**Recommended pattern (cleanest for Swift 6):** Since `TaskListView` already has `@Environment(\.modelContext)`, initialize the ViewModel with a custom init that uses `@Environment`:

```swift
// TaskListView.swift — UPDATED for Story 1.5
struct TaskListView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<TaskItem> { task in task.list == nil },
        sort: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
    )
    private var tasks: [TaskItem]

    // Repository-backed ViewModel — initialized from modelContext in .task modifier
    @State private var viewModel: TaskListViewModel?

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
            // Initialize viewModel once with the modelContainer
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
    // ... emptyStateView unchanged
}
```

**Alternative (simpler):** Pass `modelContainer` from the parent `ContentView` or from the `NavigationStack` root. This is the pattern used for `AddTaskView` and `TaskDetailView`. If `ContentView` already injects `modelContext`, `TaskListView` could receive `modelContainer` as a parameter.

**Simplest approach that avoids optional unwrapping:** Initialize `TaskListViewModel` with a container in `.task` modifier, but store it non-optionally by splitting the init. The `@State` lazy initialization via `.task` is the Swift 6–correct approach.

**⚠️ IMPORTANT:** Whatever pattern is chosen, ensure `@State var viewModel` is NOT `TaskListViewModel()` (no-arg init) after this story — `TaskListViewModel` now requires a `ModelContainer` for `deleteTask`. If the no-arg init was used for error handling only and `createTask` was only in `AddTaskView`, add `deleteTask` to the same ViewModel and ensure repository access.

[Source: architecture.md#AI Agent Guidelines — "All CloudKit/SwiftData writes through TaskRepository"]
[Source: architecture.md#Communication Patterns — Post-Mutation Side Effects]

---

### TaskListViewModel.swift — Adding deleteTask

Add the `deleteTask` method following the exact same pattern as `createTask`:

```swift
// Features/Tasks/TaskListViewModel.swift — UPDATED for Story 1.5
import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class TaskListViewModel {
    var showError: Bool = false
    var errorMessage: String = ""

    private let repository: TaskRepositoryProtocol

    init(modelContainer: ModelContainer) {
        self.repository = TaskRepository(modelContainer: modelContainer)
    }

    func createTask(title: String, listID: UUID? = nil) async {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            _ = try await repository.createTask(title: trimmed, listID: listID)
            WidgetService.shared.reloadTimelines()
        } catch {
            handleError(error)
        }
    }

    func deleteTask(_ task: TaskItem) async {
        do {
            NotificationService.shared.cancelNotification(for: task)
            try await repository.deleteTask(task)
            WidgetService.shared.reloadTimelines()
        } catch {
            handleError(error)
        }
    }

    func handleError(_ error: Error) {
        Logger.data.error("TaskList operation failed")
        errorMessage = "Something went wrong. Please try again."
        showError = true
    }
}
```

**Side-effect ordering for delete:**
1. Cancel notification FIRST (before repository delete) — prevents race condition where notification fires after task is gone from DB
2. `repository.deleteTask(_:)` — removes from SwiftData
3. `WidgetService.shared.reloadTimelines()` — ensures widget no longer shows deleted task

**`@Query` reactivity:** The `@Query` in `TaskListView` will automatically update and remove the deleted task row from the list. The animation is handled by SwiftUI's `List` + `ForEach` — no manual animation code needed. The swipe action itself provides the visual removal affordance.

[Source: architecture.md#Communication Patterns — Post-Mutation Side Effects — MANDATORY after every task mutation]
[Source: architecture.md#Enforcement Guidelines — "Always call WidgetService.shared.reloadTimelines() after every task mutation"]

---

### TaskDetailViewModel.swift — Adding deleteTask with dismissal

Extend `TaskDetailViewModel` to support deletion with navigation-back:

```swift
// Features/Tasks/TaskDetailViewModel.swift — UPDATED for Story 1.5
import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class TaskDetailViewModel {
    var editableTitle: String = ""
    var showError: Bool = false
    var errorMessage: String = ""
    var isDismissed: Bool = false   // ← NEW: set to true after successful delete

    private let task: TaskItem
    private let repository: TaskRepositoryProtocol

    init(task: TaskItem, modelContainer: ModelContainer) {
        self.task = task
        self.editableTitle = task.title
        self.repository = TaskRepository(modelContainer: modelContainer)
    }

    func commitEdit() async {
        let trimmed = editableTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            editableTitle = task.title
            return
        }
        guard trimmed != task.title else { return }
        task.title = trimmed
        do {
            try await repository.updateTask(task)
            WidgetService.shared.reloadTimelines()
        } catch {
            Logger.data.error("TaskDetail update failed")
            errorMessage = "Something went wrong. Please try again."
            showError = true
        }
    }

    func deleteTask() async {   // ← NEW
        do {
            NotificationService.shared.cancelNotification(for: task)
            try await repository.deleteTask(task)
            WidgetService.shared.reloadTimelines()
            isDismissed = true
        } catch {
            Logger.data.error("TaskDetail delete failed")
            errorMessage = "Something went wrong. Please try again."
            showError = true
        }
    }
}
```

**`isDismissed` pattern:** The view observes `viewModel.isDismissed` and calls `dismiss()` when it becomes `true`. This is the correct way to programmatically dismiss a pushed `NavigationStack` view from a ViewModel in SwiftUI + `@Observable`. Do NOT use `@Environment(\.dismiss)` in the ViewModel directly (ViewModels must not hold SwiftUI environment values).

[Source: architecture.md#Frontend/UI Architecture — ViewModels are @MainActor isolated; Views are passive]

---

### TaskDetailView.swift — Adding Delete Button

```swift
// Features/Tasks/TaskDetailView.swift — UPDATED for Story 1.5
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
```

**`.onChange(of:)` dismiss pattern:** Using `.onChange(of: viewModel.isDismissed)` to observe the `@Observable` ViewModel's `isDismissed` property and trigger `dismiss()` from the view. This keeps the navigation logic in the view while the ViewModel drives the state change. This is the correct Swift 6 + `@Observable` pattern.

**`@Environment(\.dismiss)` in `TaskDetailView`:** This was not present in Story 1.4. Add it as a stored property. It is safe to hold on the View (not in the ViewModel).

**`Button(role: .destructive)`:** The `.destructive` role automatically styles the button text red. Placing it in a separate `Section` visually separates it from the title editing section and matches iOS conventions for destructive actions.

**`onDisappear` + delete race:** The `onDisappear` will call `commitEdit()` when the view is dismissed after deletion. The `commitEdit()` guard `guard trimmed != task.title else { return }` will short-circuit because by the time `onDisappear` fires after `isDismissed = true`, the task may already be deleted from the context. This is safe — `commitEdit()` catches errors and does not crash on deleted objects (SwiftData will throw but error is handled).

However, to be extra safe, guard against committing an edit on a deleted task:

```swift
func commitEdit() async {
    guard !isDismissed else { return }  // ← Skip edit if task was deleted
    let trimmed = editableTitle.trimmingCharacters(in: .whitespaces)
    // ... rest unchanged
}
```

Add this guard to `TaskDetailViewModel.commitEdit()`.

[Source: epics.md#Story 1.5 AC#4 — "the user is navigated back to the list"]
[Source: architecture.md#Communication Patterns — Post-Mutation Side Effects]

---

### TaskListView Swipe Action — Accessibility

Per NFR16 (VoiceOver), the delete swipe action must have an accessibility label. The `Label("Delete", systemImage: "trash")` provides both a visual icon and a text label that VoiceOver reads. The `.accessibilityLabel("Delete task")` on the `Button` provides additional context. Both are included in the implementation above.

Per NFR17 (Dynamic Type): Swipe action labels use system fonts and scale automatically.

Per NFR20 (single-finger operations): Swipe-to-delete is a single-finger gesture. The `allowsFullSwipe: true` parameter on `.swipeActions` also allows a full swipe gesture as an alternative activation, which is appropriate for a destructive action with an established iOS pattern.

[Source: architecture.md#Requirements Coverage Validation — NFR16-NFR20 Accessibility]

---

### project.pbxproj — Changes for Story 1.5

**No new files are created in Story 1.5.** All changes are modifications to existing files:
- `TaskListView.swift` — add swipe-to-delete
- `TaskListViewModel.swift` — add `deleteTask` method
- `TaskDetailView.swift` — add delete button + `isDismissed` observer
- `TaskDetailViewModel.swift` — add `deleteTask` method + `isDismissed` property
- `TaskListViewModelTests.swift` — add delete tests

**No new PBXFileReference, PBXBuildFile, or PBXGroup entries required.** All files are already registered in `project.pbxproj` from Stories 1.3 and 1.4. Do NOT add new ID entries.

**Next story ID range:** Story 1.6 should use `A400`/`B400` range (since Story 1.4 used A300/B300 and Story 1.5 adds no new files).

[Source: implementation-artifacts/1-4-add-task-and-edit-task.md#project.pbxproj — New Files to Register]

---

### TaskListViewModelTests.swift — New Tests for Story 1.5

Add these tests to the existing `TaskListViewModelTests.swift` file (append to the `@Suite("TaskListViewModel")` struct):

```swift
@Test func deleteTaskRemovesFromList() async throws {
    let container = try makeContainer()
    let viewModel = TaskListViewModel(modelContainer: container)

    // Create a task first via repository
    let repo = TaskRepository(modelContainer: container)
    let task = try await repo.createTask(title: "To Delete", listID: nil)

    // Verify task exists
    let tasksBefore = try await repo.fetchTasks(in: nil)
    #expect(tasksBefore.count == 1)

    // Delete via ViewModel
    await viewModel.deleteTask(task)

    // Verify task is gone and no error
    #expect(viewModel.showError == false)
    let tasksAfter = try await repo.fetchTasks(in: nil)
    #expect(tasksAfter.count == 0)
}

@Test func deleteTaskDoesNotAffectParentList() async throws {
    let container = try makeContainer()
    let taskRepo = TaskRepository(modelContainer: container)
    let listRepo = ListRepository(modelContainer: container)
    let viewModel = TaskListViewModel(modelContainer: container)

    // Create a list and assign a task to it
    let list = try await listRepo.createList(name: "Work", colorHex: "007AFF")
    let task = try await taskRepo.createTask(title: "Work Task", listID: list.id)

    // Delete the task
    await viewModel.deleteTask(task)

    // Verify list still exists, task is gone
    let listsAfter = try await listRepo.fetchLists()
    #expect(listsAfter.count == 1)
    #expect(listsAfter[0].name == "Work")

    let tasksInList = try await taskRepo.fetchTasks(in: list)
    #expect(tasksInList.count == 0)
}
```

**Note:** `deleteTask` in ViewModel calls `NotificationService.shared.cancelNotification(for:)` first. In tests, `NotificationService.shared` is a stub that no-ops, so no mocking needed for Story 1.5.

[Source: architecture.md#Structure Patterns — Test Location: mirroring source folder structure]

---

### Swift 6 Concurrency Requirements

1. **`Button(role: .destructive) { Task { @MainActor in ... } }`** — Button action closures are synchronous. Wrap the async `deleteTask()` call in `Task { @MainActor in ... }`. The `@MainActor` annotation keeps the task on the main actor consistent with ViewModel isolation.

2. **`NotificationService.shared.cancelNotification(for:)` before `repository.deleteTask(_:)`** — `NotificationService` is `@MainActor` (see `Core/Services/NotificationService.swift` line 5). Calling it from `TaskListViewModel` (which is also `@MainActor`) is safe and correct. No actor-switching needed.

3. **`@Observable` + `.onChange(of:)` pattern** — For `@Observable` classes stored in `@State`, property changes are automatically tracked. `.onChange(of: viewModel.isDismissed)` correctly observes the `isDismissed` Bool property. Use the two-argument closure form `{ _, isDismissed in ... }` (Swift 5.9+/iOS 17+).

4. **Deleted task SwiftData object lifecycle** — After `repository.deleteTask(task)`, the `TaskItem` object is marked for deletion but the Swift reference still exists momentarily. The `@Query` in `TaskListView` will reflect the deletion on the next run loop. The animation is automatic from `List` + `ForEach` with the `@Query` binding.

5. **`@State private var viewModel: TaskListViewModel?` optional pattern** — If using the `.task` modifier to initialize the ViewModel, the optional unwrapping must be guarded everywhere the ViewModel is used. Consider using a non-optional default initializer pattern or passing via environment.

[Source: architecture.md#Implementation Patterns — Process Patterns — Error Handling]
[Source: architecture.md#AI Agent Guidelines — Swift 6 strict concurrency]

---

### Previous Story Intelligence (Story 1.4)

**Learnings from Story 1.4 that directly affect this story:**

1. **`Bindable(viewModel).propertyName` for `@Observable` bindings** — Use `Bindable(viewModel).showError` for the alert `isPresented` binding. Use `Bindable(viewModel).isDismissed` would also work but `.onChange(of:)` is cleaner for the dismiss action since we don't need a two-way binding. [Source: implementation-artifacts/1-4-add-task-and-edit-task.md#Swift 6 Concurrency Requirements]

2. **`@Environment(\.dismiss)` in views (not ViewModels)** — `TaskDetailView` needs `@Environment(\.dismiss)` to call `dismiss()` in response to ViewModel's `isDismissed = true`. Story 1.4's `TaskDetailView` did NOT have `@Environment(\.dismiss)` — add it for Story 1.5.

3. **`onDisappear` + async task pattern** — Story 1.4 established `onDisappear { Task { await viewModel.commitEdit() } }`. For Story 1.5, add the `guard !isDismissed` check in `commitEdit()` to avoid saving a deleted task's title.

4. **`ModelContainer` injection pattern** — All ViewModels receive `ModelContainer` via `init`. The repository creates a new background `ModelContext` per operation. `deleteTask` follows this same pattern — no special handling needed.

5. **ID ranges used to date:** Story 1.1: A100–, Story 1.2: A106–A109, Story 1.3: A200–A212/B200–B212, Story 1.4: A300–A303/B300–B303. **Story 1.5 adds no new files** — use A400/B400 range starting in Story 1.6.

[Source: implementation-artifacts/1-4-add-task-and-edit-task.md]

---

### Git Intelligence Summary

Recent git commits show Stories 1.1–1.4 are complete. The codebase has:
- `TaskRepository.deleteTask(_:)` fully implemented (Story 1.3)
- `NotificationService.shared.cancelNotification(for:)` stub available (Story 1.3, no-op)
- `WidgetService.shared.reloadTimelines()` available as `@MainActor` singleton (Story 1.3)
- `TaskListViewModel` with `createTask` and error handling (Story 1.4)
- `TaskDetailViewModel` with `commitEdit` pattern (Story 1.4)
- All existing files already registered in `project.pbxproj`

No new file registrations needed. All changes are additive modifications to existing files.

---

### Project Structure Notes

**Files to MODIFY in this story (no new files):**
```
TODOApp/TODOApp/Features/Tasks/TaskListView.swift          ← Add .swipeActions + viewModel init fix
TODOApp/TODOApp/Features/Tasks/TaskListViewModel.swift     ← Add deleteTask(_:) method
TODOApp/TODOApp/Features/Tasks/TaskDetailView.swift        ← Add delete button + .onChange(of: isDismissed)
TODOApp/TODOApp/Features/Tasks/TaskDetailViewModel.swift   ← Add deleteTask() + isDismissed + commitEdit guard
TODOApp/TODOAppTests/TaskListViewModelTests.swift          ← Add 2 new delete tests
```

**Files NOT to touch:**
- `TaskRepository.swift` — `deleteTask` already implemented
- `NotificationService.swift` — `cancelNotification` stub already exists
- `WidgetService.swift` — no changes needed
- `project.pbxproj` — no new files to register

**Architecture alignment:**
- All delete flows go through `TaskRepository.deleteTask(_:)` — never direct `modelContext.delete()` in views [Source: architecture.md#Architectural Boundaries — App Target Boundary]
- `NotificationService` is always called before repository delete to prevent notification-after-deletion [Source: architecture.md#Notification Boundary — NotificationService is the single point of access]
- `WidgetService.shared.reloadTimelines()` MANDATORY after every task mutation — delete is a mutation [Source: architecture.md#Enforcement Guidelines]
- `@MainActor` ViewModel `deleteTask` method — called from view's `Task { @MainActor in }` block [Source: architecture.md#AI Agent Guidelines]

---

### References

- [Source: epics.md#Story 1.5] — Full BDD acceptance criteria for delete task
- [Source: architecture.md#Communication Patterns — Post-Mutation Side Effects] — `NotificationService` cancel + `WidgetService.reloadTimelines()` after delete
- [Source: architecture.md#Notification Boundary] — `NotificationService.shared.cancelNotification(for:)` is the only correct cancel path
- [Source: architecture.md#Enforcement Guidelines] — NEVER skip WidgetService reload; NEVER call UNUserNotificationCenter directly from views
- [Source: architecture.md#AI Agent Guidelines] — `@Observable` + `@MainActor` for all ViewModels; `@Query` for reactive list display
- [Source: architecture.md#Process Patterns — Error Handling] — Generic "Something went wrong"; never raw error to user; Logger never logs task content
- [Source: architecture.md#Structure Patterns — Feature-Folder Organization] — No new subdirectories; all new files flat in `Features/Tasks/`
- [Source: implementation-artifacts/1-4-add-task-and-edit-task.md] — Story 1.4 patterns for ViewModel init, Bindable, onDisappear
- [Source: implementation-artifacts/1-3-swiftdata-models-repositories-and-inbox-task-list-view.md] — `TaskRepository.deleteTask(_:)` implementation; `WidgetService.shared` is `@MainActor`

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

No debug issues encountered. Implementation followed Dev Notes exactly.

### Completion Notes List

- ✅ Added `deleteTask(_ task: TaskItem) async` to `TaskListViewModel.swift` — calls `NotificationService.shared.cancelNotification(for:)` first, then `repository.deleteTask(_:)`, then `WidgetService.shared.reloadTimelines()`, catches errors via `handleError(_:)`
- ✅ Updated `TaskListView.swift` — changed `@State private var viewModel` to `TaskListViewModel?`, initialized lazily in `.task` modifier with `modelContext.container`. Added `.swipeActions(edge: .trailing, allowsFullSwipe: true)` with destructive `Button` + `Label("Delete", systemImage: "trash")` + `.accessibilityLabel("Delete task")`
- ✅ Added `isDismissed: Bool = false` to `TaskDetailViewModel.swift`
- ✅ Added `deleteTask() async` to `TaskDetailViewModel.swift` — same side-effect ordering; sets `isDismissed = true` on success
- ✅ Added `guard !isDismissed else { return }` to `commitEdit()` in `TaskDetailViewModel.swift` — prevents saving a deleted task on `onDisappear`
- ✅ Updated `TaskDetailView.swift` — added `@Environment(\.dismiss)`, destructive "Delete Task" `Button` in a separate `Section`, `.onChange(of: viewModel.isDismissed)` that calls `dismiss()` when true
- ✅ Added `deleteTaskRemovesFromList` test to `TaskListViewModelTests.swift` — verifies task count goes to 0 after delete, no error shown
- ✅ Added `deleteTaskDoesNotAffectParentList` test to `TaskListViewModelTests.swift` — verifies parent `TaskList` persists and task count in list is 0
- ✅ No new files created — no `project.pbxproj` changes required (all files already registered from Stories 1.3 and 1.4)

### File List

TODOApp/TODOApp/Features/Tasks/TaskListView.swift (MODIFIED)
TODOApp/TODOApp/Features/Tasks/TaskListViewModel.swift (MODIFIED)
TODOApp/TODOApp/Features/Tasks/TaskDetailView.swift (MODIFIED)
TODOApp/TODOApp/Features/Tasks/TaskDetailViewModel.swift (MODIFIED)
TODOApp/TODOAppTests/TaskListViewModelTests.swift (MODIFIED)
_bmad-output/implementation-artifacts/sprint-status.yaml (MODIFIED)

## Change Log

- 2026-02-18: Story 1.5 implemented — deleteTask added to TaskListViewModel and TaskDetailViewModel; swipe-to-delete added to TaskListView; delete button with back-navigation added to TaskDetailView; 2 unit tests added to TaskListViewModelTests; no new files or pbxproj changes (claude-sonnet-4-6)
