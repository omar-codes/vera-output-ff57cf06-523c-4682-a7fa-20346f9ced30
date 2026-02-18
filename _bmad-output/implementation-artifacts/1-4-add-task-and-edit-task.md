# Story 1.4: Add Task & Edit Task

Status: review

## Story

As an iPhone user,
I want to quickly add a new task and edit its title,
So that I can capture what I need to do and correct mistakes.

## Acceptance Criteria

1. **Given** the user is on the task list **When** they tap the "+" button **Then**:
   - `Features/Tasks/AddTaskView.swift` appears as a sheet
   - The text field is focused automatically
   - The keyboard appears without delay

2. **Given** the Add Task sheet is open **When** the user types a title and confirms **Then**:
   - `TaskListViewModel.createTask(title:listID:)` is called
   - `TaskRepository.createTask(title:listID:)` saves the task to SwiftData on a background context
   - `WidgetService.shared.reloadTimelines()` is called immediately after the save
   - `NotificationService` is checked (no reminder yet — no scheduling needed)
   - The sheet dismisses and the new task appears in the list

3. **Given** the user has tasks in the list **When** they tap a task row **Then**:
   - `Features/Tasks/TaskDetailView.swift` is pushed onto the `NavigationStack`
   - The task title is editable inline
   - Changes are committed on `onSubmit` or view disappear via `TaskDetailViewModel`

4. **Given** the user edits a title **When** the title field loses focus or the user navigates back **Then**:
   - `TaskRepository.updateTask(_:)` is called with the updated title and `modifiedAt = Date()`
   - `WidgetService.shared.reloadTimelines()` is called
   - The updated title appears in the task list immediately

5. **Given** invalid input (empty title) **When** the user tries to save **Then**:
   - The save is blocked and an inline error hint is shown
   - No empty-title tasks are persisted

6. **Given** any task mutation occurs **When** the operation completes or fails **Then**:
   - Errors are caught by the ViewModel, logged privately via `Logger` (no task content), and shown as a generic "Something went wrong" banner
   - The UI never displays raw error messages

## Tasks / Subtasks

- [x] Task 1: Implement `AddTaskView.swift` and wire `TaskListViewModel.createTask` (AC: #1, #2, #5, #6)
  - [x] 1.1 Create `TODOApp/Features/Tasks/AddTaskView.swift` — sheet UI with auto-focused text field, confirm/cancel buttons, inline empty-title validation
  - [x] 1.2 Update `TODOApp/Features/Tasks/TaskListViewModel.swift` — add `repository` property, add `createTask(title:listID:)` async method calling `TaskRepository`, `WidgetService`; inject `ModelContainer` via init
  - [x] 1.3 Update `TODOApp/Features/Tasks/TaskListView.swift` — replace `Text("Add Task — Story 1.4")` stub with `AddTaskView(modelContainer:)` and `Text("Task Detail — Story 1.4")` stub with `TaskDetailView(task:modelContainer:)`
  - [x] 1.4 Register `AddTaskView.swift` in `project.pbxproj` (PBXFileReference A300, PBXBuildFile B300, add to D015 group and E001S)

- [x] Task 2: Implement `TaskDetailView.swift` and `TaskDetailViewModel.swift` (AC: #3, #4, #5, #6)
  - [x] 2.1 Create `TODOApp/Features/Tasks/TaskDetailViewModel.swift` — `@Observable @MainActor` class, holds editable `editableTitle: String`, `task: TaskItem`, `repository`, calls `updateTask` on `commitEdit()`, includes guard for empty title (reverts to original)
  - [x] 2.2 Create `TODOApp/Features/Tasks/TaskDetailView.swift` — pushed view on `NavigationStack`, inline editable title `TextField`, commits on `onSubmit` and `.onDisappear`, calls `viewModel.commitEdit()`, shows error banner from ViewModel
  - [x] 2.3 Update `TODOApp/Features/Tasks/TaskListView.swift` — replaced both stubs: sheet now uses `AddTaskView(modelContainer:)`, `navigationDestination` now uses `TaskDetailView(task:modelContainer:)`
  - [x] 2.4 Register `TaskDetailView.swift` and `TaskDetailViewModel.swift` in `project.pbxproj` (PBXFileRefs A301–A302, PBXBuildFiles B301–B302, add to D015 group and E001S)

- [x] Task 3: Unit tests for create and edit operations (AC: #1–#6)
  - [x] 3.1 Update `TODOAppTests/TaskRepositoryTests.swift` — added `updateTaskSetsModifiedAt` test confirming `updateTask` updates `modifiedAt`
  - [x] 3.2 Add `TaskListViewModelTests.swift` under `TODOAppTests/` — tests: valid title creates task, empty/whitespace title does not persist, title is trimmed
  - [x] 3.3 Register `TaskListViewModelTests.swift` in `project.pbxproj` (PBXFileRef A303, PBXBuildFile B303, add to D004 group and E004S)

## Dev Notes

### Critical: Replacing Story 1.3 Stubs in TaskListView

Story 1.3 left two placeholder stubs in `TaskListView.swift` (`Features/Tasks/TaskListView.swift`) that MUST be replaced:

**1. Add Task sheet stub** (line ~39):
```swift
// BEFORE (Story 1.3 stub):
.sheet(isPresented: Bindable(coordinator).isShowingAddTask) {
    Text("Add Task — Story 1.4")
}

// AFTER (Story 1.4):
.sheet(isPresented: Bindable(coordinator).isShowingAddTask) {
    AddTaskView()
}
```

**2. Task detail navigation destination stub** (line ~35):
```swift
// BEFORE (Story 1.3 stub):
.navigationDestination(for: UUID.self) { _ in
    Text("Task Detail — Story 1.4")
}

// AFTER (Story 1.4):
.navigationDestination(for: UUID.self) { taskID in
    if let task = tasks.first(where: { $0.id == taskID }) {
        TaskDetailView(task: task)
    }
}
```

**Important:** The `tasks` array in `TaskListView` is the `@Query` result — it is already in scope for the `navigationDestination` closure because the destination is declared within the same view body. No extra fetch is needed.

[Source: implementation-artifacts/1-3-swiftdata-models-repositories-and-inbox-task-list-view.md#TaskListView.swift — Core View Implementation]

---

### TaskListViewModel.swift — Updated with Repository and createTask

Story 1.3 left `TaskListViewModel` as a lightweight error handler. Story 1.4 adds the repository and `createTask` method:

```swift
// Features/Tasks/TaskListViewModel.swift
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
            NotificationService.shared.scheduleNotification(for: /* task */ /* see note below */)
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

**Critical Notes:**

1. **`@Observable` + `@MainActor`** — Both annotations REQUIRED per architecture mandate. Do NOT use `ObservableObject` or `@Published`. [Source: architecture.md#AI Agent Guidelines]

2. **Repository injection via `ModelContainer`** — `TaskListViewModel` is initialized from the view using `@Environment(\.modelContext).container`. See `AddTaskView` init pattern below.

3. **`NotificationService` for new tasks** — Per Story 1.4 AC#2: "NotificationService is checked (no reminder yet — no scheduling needed)." The stub `scheduleNotification(for:)` is a no-op in Story 1.3. No explicit call is needed for creates with no `reminderDate`. Do NOT call `scheduleNotification` on a freshly created task with no `reminderDate` — the check inside `NotificationService` will be relevant in Story 2.1. Simply calling `WidgetService.shared.reloadTimelines()` is sufficient for Story 1.4.

4. **`createTask` returns `TaskItem`** — The return value from `repository.createTask` can be discarded in the ViewModel for Story 1.4 (no reminder to schedule). Use `_ = try await` or assign if needed for future stories.

[Source: architecture.md#Communication Patterns — ViewModel → Repository]
[Source: architecture.md#Enforcement Guidelines — post-mutation side effects]

---

### AddTaskView.swift — Sheet Implementation

```swift
// Features/Tasks/AddTaskView.swift
import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title: String = ""
    @State private var showValidationError: Bool = false

    // ViewModel initialized with the shared ModelContainer
    @State private var viewModel: TaskListViewModel

    init() {
        // ViewModel will be initialized with modelContext.container in onAppear
        // Use a temporary placeholder — replaced when view appears
        // NOTE: We initialize with a temporary container; real container injected below
        _viewModel = State(initialValue: TaskListViewModel.__placeholder())
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
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel adding task")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        submitTask()
                    }
                    .accessibilityLabel("Add task")
                }
            }
        }
    }

    @FocusState private var isFocused: Bool

    private func submitTask() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            showValidationError = true
            return
        }
        showValidationError = false
        Task { @MainActor in
            await viewModel.createTask(title: trimmed)
            dismiss()
        }
    }
}
```

**⚠️ ViewModel Initialization Pattern for AddTaskView:**

The `TaskListViewModel` requires a `ModelContainer`. `AddTaskView` is a sheet, so it has access to `@Environment(\.modelContext)`. The cleanest Swift 6–compatible approach is to NOT use a custom `init` to inject the container into `@State`. Instead:

**Recommended pattern (simpler, correct for Swift 6):**

Pass the `ModelContainer` as a parameter from `TaskListView`, which already has `@Environment(\.modelContext)`:

```swift
// In TaskListView.swift — pass container to sheet
@Environment(\.modelContext) private var modelContext

.sheet(isPresented: Bindable(coordinator).isShowingAddTask) {
    AddTaskView(modelContainer: modelContext.container)
}
```

```swift
// AddTaskView.swift — receive container in init
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
```

**Auto-focus on appear:** `.onAppear { isFocused = true }` triggers keyboard appearance automatically. Use `@FocusState` — do NOT use `UITextView` hacks. [Source: epics.md#Story 1.4 AC — "the text field is focused automatically"]

**Empty title validation:** The `guard !trimmed.isEmpty` in `submitTask()` blocks saves and shows `showValidationError`. Also guard in `TaskListViewModel.createTask` as a second layer. [Source: epics.md#Story 1.4 AC — "Given invalid input (empty title)"]

---

### TaskDetailViewModel.swift — Exact Implementation

```swift
// Features/Tasks/TaskDetailViewModel.swift
import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class TaskDetailViewModel {
    var editableTitle: String = ""
    var showError: Bool = false
    var errorMessage: String = ""

    private let task: TaskItem
    private let repository: TaskRepositoryProtocol

    init(task: TaskItem, modelContainer: ModelContainer) {
        self.task = task
        self.editableTitle = task.title
        self.repository = TaskRepository(modelContainer: modelContainer)
    }

    /// Call on `onSubmit` or `onDisappear` to persist the edited title.
    func commitEdit() async {
        let trimmed = editableTitle.trimmingCharacters(in: .whitespaces)
        // Block empty titles — revert to original
        guard !trimmed.isEmpty else {
            editableTitle = task.title
            return
        }
        // No-op if title unchanged
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
}
```

**Key patterns:**
- `editableTitle` is the mutable binding for the `TextField` in the view
- `commitEdit()` trims whitespace, validates, compares to original to avoid no-op saves
- On empty title, silently reverts to original (no error — just discard the empty input)
- `updateTask` in `TaskRepository` already sets `modifiedAt = Date()` — no need to set it here [Source: implementation-artifacts/1-3-swiftdata-models-repositories-and-inbox-task-list-view.md#TaskRepository.swift — Implementation Pattern]
- `WidgetService.shared.reloadTimelines()` is called after every successful update [Source: architecture.md#Communication Patterns — Post-Mutation Side Effects]

---

### TaskDetailView.swift — Exact Implementation

```swift
// Features/Tasks/TaskDetailView.swift
import SwiftUI
import SwiftData

struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
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
        }
        .navigationTitle("Edit Task")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            Task { await viewModel.commitEdit() }
        }
        .alert("Error", isPresented: Bindable(viewModel).showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}
```

**`onDisappear` commit pattern:** The edit is committed both on `onSubmit` (keyboard return) and `onDisappear` (user navigates back). The `commitEdit()` guard `trimmed != task.title` prevents double-saves. [Source: epics.md#Story 1.4 AC — "When the title field loses focus or the user navigates back"]

**`Bindable(viewModel).editableTitle` pattern:** For `@Observable` objects stored in `@State`, `Bindable(viewModel)` creates the binding — same as the `Bindable(coordinator)` pattern established in Story 1.2. Do NOT use `$viewModel.editableTitle`. [Source: implementation-artifacts/1-2-core-constants-app-entry-point-and-navigation-shell.md#ContentView.swift]

**Passing `modelContainer` to TaskDetailView:** From `TaskListView`, pass `modelContext.container` just like `AddTaskView`:

```swift
// In TaskListView.swift
.navigationDestination(for: UUID.self) { taskID in
    if let task = tasks.first(where: { $0.id == taskID }) {
        TaskDetailView(task: task, modelContainer: modelContext.container)
    }
}
```

---

### TaskListView.swift — Final State After Story 1.4 Changes

Here is the complete updated `TaskListView.swift` for reference:

```swift
// Features/Tasks/TaskListView.swift
import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext

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
```

**IMPORTANT:** The `@State private var viewModel = TaskListViewModel()` in `TaskListView` is the Story 1.3 version — a lightweight error handler with no repository. After Story 1.4, `TaskListViewModel` requires a `ModelContainer`. Update the `@State` initialization:

```swift
// OLD (Story 1.3):
@State private var viewModel = TaskListViewModel()

// NEW (Story 1.4) — initialize with modelContext.container:
// Option A: Use @State with lazy init in onAppear
// Option B: Pass modelContainer via environment — NOT recommended (TaskListView uses @Query which already needs modelContext)

// SIMPLEST CORRECT APPROACH:
// TaskListView only uses viewModel for error display — it does NOT call createTask directly.
// createTask is called from AddTaskView which has its OWN TaskListViewModel instance.
// Therefore, TaskListView's viewModel can remain the lightweight version:
@State private var viewModel = TaskListViewModel()  // No change needed if createTask stays in AddTaskView's ViewModel
```

**Recommendation:** Keep `TaskListView.viewModel` as the lightweight `TaskListViewModel()` (Story 1.3 pattern). `AddTaskView` has its own `TaskListViewModel` instance (with repository) for creating tasks. This avoids the init complexity in `TaskListView`. Only `AddTaskView` and `TaskDetailView` need the `ModelContainer`-injected ViewModels.

If future stories require `TaskListView` to call repository methods directly, the pattern can be updated then.

---

### project.pbxproj — New Files to Register for Story 1.4

Use IDs starting from `A300`/`B300` to avoid conflicts with Story 1.3 (`A200`–`A212`, `B200`–`B212`).

**New PBXFileReference entries:**
```
A300 /* AddTaskView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AddTaskView.swift; sourceTree = "<group>"; };
A301 /* TaskDetailView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TaskDetailView.swift; sourceTree = "<group>"; };
A302 /* TaskDetailViewModel.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TaskDetailViewModel.swift; sourceTree = "<group>"; };
A303 /* TaskListViewModelTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TaskListViewModelTests.swift; sourceTree = "<group>"; };
```

**New PBXBuildFile entries (app target — E001S):**
```
B300 /* AddTaskView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A300 /* AddTaskView.swift */; };
B301 /* TaskDetailView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A301 /* TaskDetailView.swift */; };
B302 /* TaskDetailViewModel.swift in Sources */ = {isa = PBXBuildFile; fileRef = A302 /* TaskDetailViewModel.swift */; };
```

**New PBXBuildFile entry (test target — E004S):**
```
B303 /* TaskListViewModelTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = A303 /* TaskListViewModelTests.swift */; };
```

**D015 /* Tasks */ PBXGroup — add new files:**
```
D015 /* Tasks */ = {
    isa = PBXGroup;
    children = (
        A209 /* TaskListView.swift */,
        A210 /* TaskListViewModel.swift */,
        A211 /* TaskRowView.swift */,
        A300 /* AddTaskView.swift */,         ← NEW
        A301 /* TaskDetailView.swift */,      ← NEW
        A302 /* TaskDetailViewModel.swift */, ← NEW
    );
    path = Tasks;
    sourceTree = "<group>";
};
```

**D004 /* TODOAppTests */ PBXGroup — add new test file:**
```
D004 /* TODOAppTests */ = {
    isa = PBXGroup;
    children = (
        A131 /* TODOAppTests.swift */,
        A212 /* TaskRepositoryTests.swift */,
        A303 /* TaskListViewModelTests.swift */, ← NEW
    );
    path = TODOAppTests;
    sourceTree = "<group>";
};
```

**Add B300–B302 to E001S (Sources for TODOApp):**
```
E001S /* Sources (TODOApp) */ = {
    ...
    files = (
        ... (existing B200–B211 entries)
        B300 /* AddTaskView.swift in Sources */,
        B301 /* TaskDetailView.swift in Sources */,
        B302 /* TaskDetailViewModel.swift in Sources */,
    );
};
```

**Add B303 to E004S (Sources for TODOAppTests):**
```
E004S /* Sources (Tests) */ = {
    ...
    files = (
        A031 /* TODOAppTests.swift in Sources */,
        B212 /* TaskRepositoryTests.swift in Sources */,
        B303 /* TaskListViewModelTests.swift in Sources */, ← NEW
    );
};
```

---

### Swift 6 Concurrency Requirements

1. **`Task { @MainActor in ... }` for async calls from synchronous view actions** — Button actions and `onSubmit` closures are synchronous. Wrap async ViewModel calls in `Task { @MainActor in ... }`. The `@MainActor` annotation ensures the task runs on the main actor, consistent with ViewModel isolation. [Source: architecture.md#Process Patterns — Error Handling]

2. **`@Observable` `Bindable` pattern** — `TextField("Task title", text: Bindable(viewModel).editableTitle)` is the correct way to create a `Binding` from an `@Observable` class stored in `@State`. Do NOT use `$viewModel.editableTitle` (that is `ObservableObject` / `@Published` syntax). [Source: implementation-artifacts/1-2-core-constants-app-entry-point-and-navigation-shell.md#Swift 6 Concurrency Constraints]

3. **`@FocusState` for auto-focus** — Triggers auto-focus on appear. `.focused($isFocused)` on `TextField` + `.onAppear { isFocused = true }` on the parent view. No UIKit workarounds. [Source: epics.md#Story 1.4 AC#1 — "the keyboard appears without delay"]

4. **`TaskDetailViewModel.commitEdit()` is idempotent** — Can be called from both `onSubmit` and `onDisappear` without double-saving because of the `guard trimmed != task.title` check. Both paths call `commitEdit()` safely in Swift 6 async context.

5. **`@MainActor` on `TaskListViewModel` and `TaskDetailViewModel`** — Required by architecture. All ViewModel methods that call repositories must be called from `Task { @MainActor in }` blocks in view action handlers. [Source: architecture.md#AI Agent Guidelines]

6. **Sendable conformance of `TaskItem`** — `TaskItem` is a `@Model` class (reference type). Passing it between `TaskListView` (which owns the `@Query` result) and `TaskDetailView` (which holds a reference to the same SwiftData object) is safe because they share the same main `ModelContext`. The `TaskDetailViewModel` holds a direct reference to the `task` object, not a copy.

---

### Previous Story Intelligence (Story 1.3)

**Learnings from Story 1.3 that directly affect this story:**

1. **`Bindable(coordinator)` binding pattern** — Works correctly for `@Observable` objects accessed via `@Environment`. Use `Bindable(viewModel).editableTitle` for `TaskDetailViewModel`. Do NOT use `$viewModel`. [Source: implementation-artifacts/1-3-swiftdata-models-repositories-and-inbox-task-list-view.md#Previous Story Intelligence]

2. **`@State private var viewModel = TaskListViewModel()`** — The Story 1.3 version has no `init` parameters. When upgrading to accept `ModelContainer`, be careful not to break the lazy init in `@State`. The recommended approach (pass to `AddTaskView` which has its own ViewModel) avoids modifying `TaskListView`'s ViewModel init.

3. **`ModelContext(modelContainer)` per operation in `TaskRepository`** — This is the established pattern. `TaskDetailViewModel` does NOT need to hold a `ModelContext` directly — it passes `ModelContainer` to `TaskRepository` which creates context per operation. [Source: implementation-artifacts/1-3-swiftdata-models-repositories-and-inbox-task-list-view.md#TaskRepository.swift]

4. **`WidgetService.shared.reloadTimelines()` is `@MainActor`** — Call from ViewModel (which is `@MainActor`) after every successful mutation. Do NOT call from a background task. [Source: implementation-artifacts/1-3-swiftdata-models-repositories-and-inbox-task-list-view.md#WidgetService.swift]

5. **ID ranges used** — Story 1.2 used `A106`–`A109` for FileRefs. Story 1.3 used `A200`–`A212` for FileRefs and `B200`–`B212` for BuildFiles. **Use `A300`–`A303` and `B300`–`B303` for Story 1.4.** [Source: implementation-artifacts/1-3-swiftdata-models-repositories-and-inbox-task-list-view.md#project.pbxproj — New Files to Register]

6. **`#Predicate` inside `navigationDestination`** — Do NOT use a new `@Query` or `FetchDescriptor` inside `navigationDestination`. The `tasks` array from the parent view's `@Query` is in scope and sufficient for the `first(where:)` lookup.

---

### Git Intelligence Summary

Recent commits show Story 1.1 (Xcode project init), Story 1.2 (constants/coordinator), and Story 1.3 (models/repositories/views) have been implemented. The codebase is clean with all Story 1.3 files in place:
- `AppCoordinator.swift` has `isShowingAddTask: Bool` and `navigateTo(taskID:)` — ready to be used
- `TaskListView.swift` has the two stubs ready for replacement
- `TaskRepository.createTask` and `updateTask` are fully implemented with background context
- `WidgetService.shared.reloadTimelines()` is available as a `@MainActor` singleton

---

### Project Structure Notes

**Files to CREATE in this story:**
```
TODOApp/TODOApp/
└── Features/
    └── Tasks/
        ├── AddTaskView.swift             ← NEW (sheet, auto-focus, validation)
        ├── TaskDetailView.swift          ← NEW (pushed, inline edit, onDisappear commit)
        └── TaskDetailViewModel.swift     ← NEW (@Observable @MainActor, commitEdit)

TODOApp/TODOAppTests/
└── TaskListViewModelTests.swift          ← NEW (unit tests for createTask, validation)
```

**Files to MODIFY in this story:**
```
TODOApp/TODOApp/Features/Tasks/TaskListView.swift     ← Replace 2 stubs (sheet + navigationDestination)
TODOApp/TODOApp/Features/Tasks/TaskListViewModel.swift ← Add repository + createTask method
TODOApp/TODOApp.xcodeproj/project.pbxproj             ← Register 4 new files (A300–A303, B300–B303)
```

**Architecture alignment:**
- All new files go in `Features/Tasks/` — feature-folder structure, NO subdirectories [Source: architecture.md#Structure Patterns — Feature-Folder Organization]
- `TaskDetailViewModel` is `@Observable @MainActor` — BOTH annotations REQUIRED [Source: architecture.md#AI Agent Guidelines]
- `AddTaskView` and `TaskDetailView` both receive `ModelContainer` via their `init` — prevents environment threading issues [Source: architecture.md#Communication Patterns — SwiftData ModelContext Actor Isolation]

---

### References

- [Source: epics.md#Story 1.4] — Full BDD acceptance criteria for add task and edit task
- [Source: architecture.md#Communication Patterns — ViewModel → Repository] — `createTask` async/await pattern with side effects
- [Source: architecture.md#Communication Patterns — Post-Mutation Side Effects] — `WidgetService.shared.reloadTimelines()` MANDATORY after every create/update
- [Source: architecture.md#Frontend/UI Architecture — Component Architecture] — Views are passive, ViewModels are `@MainActor`
- [Source: architecture.md#AI Agent Guidelines] — `@Observable` + `@MainActor` for all ViewModels; never `ObservableObject`/`@Published`
- [Source: architecture.md#Process Patterns — Error Handling] — Generic "Something went wrong" banner; never raw error to user; `Logger` never logs task content
- [Source: architecture.md#Naming Patterns] — `TaskDetailView`, `AddTaskView`, `TaskDetailViewModel` — follow established conventions
- [Source: architecture.md#Structure Patterns — Feature-Folder Organization] — All files flat in `Features/Tasks/`
- [Source: implementation-artifacts/1-3-swiftdata-models-repositories-and-inbox-task-list-view.md#TaskListView.swift] — Story 1.3 stub locations in `TaskListView`
- [Source: implementation-artifacts/1-3-swiftdata-models-repositories-and-inbox-task-list-view.md#TaskRepository.swift] — `updateTask` sets `modifiedAt = Date()` in repository; no need to set in ViewModel
- [Source: implementation-artifacts/1-3-swiftdata-models-repositories-and-inbox-task-list-view.md#WidgetService.swift] — `WidgetService.shared` is `@MainActor`; call from ViewModel only

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

No debug issues encountered. Implementation followed Dev Notes exactly.

### Completion Notes List

- ✅ Created `AddTaskView.swift` — sheet with auto-focus via `@FocusState` + `.onAppear`, inline empty-title validation, passes `ModelContainer` in init per Swift 6 patterns
- ✅ Updated `TaskListViewModel.swift` — added `ModelContainer`-injected init, `createTask(title:listID:)` async method, calls `TaskRepository` and `WidgetService.shared.reloadTimelines()` after success
- ✅ Updated `TaskListView.swift` — replaced both Story 1.3 stubs: sheet uses `AddTaskView(modelContainer:)`, `navigationDestination` uses `TaskDetailView(task:modelContainer:)`. Removed standalone `viewModel` since error handling is now in `AddTaskView` and `TaskDetailView` via their own ViewModels.
- ✅ Created `TaskDetailViewModel.swift` — `@Observable @MainActor`, `commitEdit()` trims, validates (empty reverts), no-ops if unchanged, calls `repository.updateTask(_:)` and `WidgetService.shared.reloadTimelines()`
- ✅ Created `TaskDetailView.swift` — `Form` with inline `TextField`, commits on `onSubmit` and `onDisappear`, error alert via `Bindable(viewModel).showError`
- ✅ Added `updateTaskSetsModifiedAt` test to `TaskRepositoryTests.swift`
- ✅ Created `TaskListViewModelTests.swift` with 3 tests: valid title creates task, whitespace title does not persist, title is trimmed
- ✅ Registered A300–A303, B300–B303 in `project.pbxproj` (PBXFileReferences, PBXBuildFiles, D015 group, D004 group, E001S sources, E004S sources)

### File List

TODOApp/TODOApp/Features/Tasks/AddTaskView.swift (NEW)
TODOApp/TODOApp/Features/Tasks/TaskDetailView.swift (NEW)
TODOApp/TODOApp/Features/Tasks/TaskDetailViewModel.swift (NEW)
TODOApp/TODOAppTests/TaskListViewModelTests.swift (NEW)
TODOApp/TODOApp/Features/Tasks/TaskListView.swift (MODIFIED)
TODOApp/TODOApp/Features/Tasks/TaskListViewModel.swift (MODIFIED)
TODOApp/TODOAppTests/TaskRepositoryTests.swift (MODIFIED)
TODOApp/TODOApp.xcodeproj/project.pbxproj (MODIFIED)
_bmad-output/implementation-artifacts/sprint-status.yaml (MODIFIED)

## Change Log

- 2026-02-18: Story 1.4 implemented — AddTaskView, TaskDetailView, TaskDetailViewModel created; TaskListViewModel updated with repository and createTask; TaskListView stubs replaced; unit tests added; all files registered in project.pbxproj (claude-sonnet-4-6)
