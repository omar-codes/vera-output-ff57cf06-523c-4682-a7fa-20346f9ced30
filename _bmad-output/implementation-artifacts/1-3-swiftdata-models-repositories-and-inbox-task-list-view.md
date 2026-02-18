# Story 1.3: SwiftData Models, Repositories & Inbox Task List View

Status: review

## Story

As a developer,
I want the data models, repository protocols/implementations, and Inbox task list view implemented,
So that users can see their tasks in the Inbox and the persistence layer is fully wired.

## Acceptance Criteria

1. **Given** the project foundation exists **When** the developer implements `Core/Models/TaskItem.swift` **Then** `TaskItem` is a `@Model final class` with:
   - `@Attribute(.unique) var id: UUID`
   - `var title: String`
   - `var isCompleted: Bool`
   - `var dueDate: Date?`
   - `var reminderDate: Date?`
   - `var createdAt: Date`
   - `var modifiedAt: Date`
   - `var list: TaskList?`
   - `var sortOrder: Int`
   **And** `Core/Models/TaskList.swift` is a `@Model final class` with:
   - `@Attribute(.unique) var id: UUID`
   - `var name: String`
   - `var colorHex: String`
   - `var createdAt: Date`
   - `var sortOrder: Int`
   - `@Relationship(deleteRule: .cascade) var tasks: [TaskItem]`
   **And** `Core/Models/DataMigration/SchemaV1.swift` defines a `VersionedSchema` for the current schema

2. **Given** the models exist **When** the developer implements repositories **Then**:
   - `Core/Repositories/TaskRepositoryProtocol.swift` defines:
     - `fetchTasks(in list: TaskList?) async throws -> [TaskItem]`
     - `createTask(title: String, listID: UUID?) async throws -> TaskItem`
     - `updateTask(_ task: TaskItem) async throws`
     - `deleteTask(_ task: TaskItem) async throws`
     - `completeTask(_ task: TaskItem) async throws`
   - `Core/Repositories/TaskRepository.swift` implements the protocol using a background `ModelContext`
   - `Core/Repositories/ListRepositoryProtocol.swift` and `ListRepository.swift` follow the same pattern
   - Repositories never operate on `@MainActor`; they receive an injected background `ModelContext`

3. **Given** repositories exist **When** the developer implements the task list view **Then**:
   - `Features/Tasks/TaskListView.swift` uses `@Query` to reactively display tasks
   - The Inbox displays tasks where `task.list == nil`
   - Overdue tasks (`dueDate < now`, `isCompleted == false`) are visually distinct (e.g., red due date label)
   - `Features/Tasks/TaskListViewModel.swift` is `@Observable @MainActor`
   - `Features/Tasks/TaskRowView.swift` displays task title, due date (if set), and completion indicator

4. **Given** the task list view is implemented **When** the app launches on a simulator **Then**:
   - The Inbox view appears with empty state (no tasks yet)
   - All VoiceOver accessibility labels on interactive elements are present and descriptive (NFR16)
   - All text uses Dynamic Type styles (NFR17)

## Tasks / Subtasks

- [x] Task 1: Create SwiftData model files (AC: #1)
  - [x] 1.1 Create `TODOApp/Core/Models/TaskItem.swift` — `@Model final class` with all required properties
  - [x] 1.2 Create `TODOApp/Core/Models/TaskList.swift` — `@Model final class` with cascade delete relationship
  - [x] 1.3 Create `TODOApp/Core/Models/DataMigration/` directory and `SchemaV1.swift` — `VersionedSchema`
  - [x] 1.4 Update `TODOApp/TODOApp/TODOAppApp.swift` — add `TaskItem.self, TaskList.self` to the `Schema([])` array
  - [x] 1.5 Register all 3 new files in `project.pbxproj` (PBXFileReference + PBXBuildFile + Sources entries)
  - [x] 1.6 Create `Core/Models/` and `Core/Models/DataMigration/` PBXGroup entries in `project.pbxproj`

- [x] Task 2: Implement repository protocols and implementations (AC: #2)
  - [x] 2.1 Create `TODOApp/Core/Repositories/TaskRepositoryProtocol.swift` — protocol definition
  - [x] 2.2 Create `TODOApp/Core/Repositories/TaskRepository.swift` — `SwiftData`-backed implementation (background `ModelContext`)
  - [x] 2.3 Create `TODOApp/Core/Repositories/ListRepositoryProtocol.swift` — protocol definition
  - [x] 2.4 Create `TODOApp/Core/Repositories/ListRepository.swift` — `SwiftData`-backed implementation
  - [x] 2.5 Register all 4 repository files in `project.pbxproj`
  - [x] 2.6 Create `Core/Repositories/` PBXGroup entry in `project.pbxproj`

- [x] Task 3: Create Core/Services stubs for side effects (AC: #3)
  - [x] 3.1 Create `TODOApp/Core/Services/WidgetService.swift` — singleton with `reloadTimelines()` stub
  - [x] 3.2 Create `TODOApp/Core/Services/NotificationService.swift` — singleton stub (full implementation in Story 2.x)
  - [x] 3.3 Register both service files in `project.pbxproj`
  - [x] 3.4 Create `Core/Services/` PBXGroup entry in `project.pbxproj`

- [x] Task 4: Implement task list views (AC: #3, #4)
  - [x] 4.1 Create `TODOApp/Features/Tasks/TaskListView.swift` — `@Query`-driven, Inbox filter (`list == nil`), empty state
  - [x] 4.2 Create `TODOApp/Features/Tasks/TaskListViewModel.swift` — `@Observable @MainActor` class
  - [x] 4.3 Create `TODOApp/Features/Tasks/TaskRowView.swift` — title, due date (overdue highlight), completion indicator
  - [x] 4.4 Register all 3 view files in `project.pbxproj`
  - [x] 4.5 Create `Features/` and `Features/Tasks/` PBXGroup entries in `project.pbxproj`

- [x] Task 5: Wire up navigation shell in ContentView (AC: #4)
  - [x] 5.1 Update `TODOApp/TODOApp/ContentView.swift` — replace placeholder with `TaskListView`, add `navigationDestination` for `TaskItem`, wire `isShowingAddTask` sheet stub
  - [x] 5.2 Add `.navigationTitle("Inbox")` and navigation bar items

- [x] Task 6: Add unit tests (AC: #1–#4)
  - [x] 6.1 Update `TODOAppTests/TODOAppTests.swift` — add `TaskItem` model property tests, `TaskList` cascade rule tests
  - [x] 6.2 Add `TaskRepositoryTests.swift` for repository logic (in-memory `ModelContainer`)
  - [x] 6.3 Register test files in `project.pbxproj` with correct test target membership

## Dev Notes

### Critical: Updating TODOAppApp.swift Schema

The `TODOAppApp.swift` currently has an empty schema with a comment ready for this story:

```swift
let schema = Schema([
    // Story 1.3 adds: TaskItem.self, TaskList.self
])
```

**Replace it with:**

```swift
let schema = Schema([
    TaskItem.self,
    TaskList.self,
])
```

This is the ONLY change to `TODOAppApp.swift` in this story. The `ModelConfiguration` with CloudKit is already correct from Story 1.2.
[Source: implementation-artifacts/1-2-core-constants-app-entry-point-and-navigation-shell.md#Critical: ModelContainer Bootstrap Without Real Models]

---

### TaskItem.swift — Exact Implementation

```swift
// Core/Models/TaskItem.swift
import Foundation
import SwiftData

@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var isCompleted: Bool
    var dueDate: Date?
    var reminderDate: Date?
    var createdAt: Date
    var modifiedAt: Date
    var list: TaskList?
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        reminderDate: Date? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        list: TaskList? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.reminderDate = reminderDate
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.list = list
        self.sortOrder = sortOrder
    }
}
```

**Critical notes:**
- Use `@Model` macro (NOT `@Model class`) — `@Model` is applied to the class declaration
- Model name MUST be `TaskItem` (not `Task`) — `Task` conflicts with Swift concurrency's `Task` type [Source: architecture.md#Naming Patterns]
- `@Attribute(.unique)` on `id` ensures CloudKit upsert semantics work correctly
- `list: TaskList?` is the relationship property — SwiftData generates the foreign key
- `sortOrder: Int` defaults to 0; updated by Story 1.5 reorder feature
- **Do NOT use `@Published`** — SwiftData `@Model` classes use a different observation mechanism

---

### TaskList.swift — Exact Implementation

```swift
// Core/Models/TaskList.swift
import Foundation
import SwiftData

@Model
final class TaskList {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date
    var sortOrder: Int
    @Relationship(deleteRule: .cascade) var tasks: [TaskItem]

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "007AFF",
        createdAt: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.tasks = []
    }
}
```

**Critical notes:**
- `@Relationship(deleteRule: .cascade)` is REQUIRED — when a `TaskList` is deleted, all its tasks must be deleted too [Source: epics.md#Story 1.3 AC, Story 3.3 AC]
- `colorHex` is `String` (6-digit hex e.g. `"007AFF"`), NOT `Color` — `Color` is not Codable in SwiftData [Source: architecture.md#Format Patterns — Color Storage]
- `tasks` initialized to `[]` (empty array) in `init` — required by SwiftData
- Model name MUST be `TaskList` (not `List`) — `List` is a SwiftUI view type

---

### SchemaV1.swift — VersionedSchema

```swift
// Core/Models/DataMigration/SchemaV1.swift
import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [TaskItem.self, TaskList.self]
    }
}
```

**Purpose:** This is a future-proofing file. It enables SwiftData `SchemaMigrationPlan` when the schema changes post-MVP. Do not reference this in `TODOAppApp.swift` yet — the `ModelContainer` uses `Schema([TaskItem.self, TaskList.self])` directly. This file just documents the V1 schema.
[Source: architecture.md#Data Architecture — Migration Approach]

---

### TaskRepositoryProtocol.swift — Exact Definition

```swift
// Core/Repositories/TaskRepositoryProtocol.swift
import Foundation

protocol TaskRepositoryProtocol: Sendable {
    func fetchTasks(in list: TaskList?) async throws -> [TaskItem]
    func createTask(title: String, listID: UUID?) async throws -> TaskItem
    func updateTask(_ task: TaskItem) async throws
    func deleteTask(_ task: TaskItem) async throws
    func completeTask(_ task: TaskItem) async throws
}
```

**Swift 6 concurrency note:** Protocol must be `Sendable` because implementations are passed across actor boundaries.

---

### TaskRepository.swift — Implementation Pattern

```swift
// Core/Repositories/TaskRepository.swift
import Foundation
import SwiftData

final class TaskRepository: TaskRepositoryProtocol {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func fetchTasks(in list: TaskList?) async throws -> [TaskItem] {
        let context = ModelContext(modelContainer)
        let listID = list?.id
        let descriptor: FetchDescriptor<TaskItem>
        if let listID {
            descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate { task in task.list?.id == listID },
                sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
            )
        } else {
            // Inbox: tasks with no list
            descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate { task in task.list == nil },
                sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
            )
        }
        return try context.fetch(descriptor)
    }

    func createTask(title: String, listID: UUID?) async throws -> TaskItem {
        let context = ModelContext(modelContainer)
        let task = TaskItem(title: title)
        if let listID {
            let descriptor = FetchDescriptor<TaskList>(
                predicate: #Predicate { list in list.id == listID }
            )
            task.list = try context.fetch(descriptor).first
        }
        context.insert(task)
        try context.save()
        Logger.data.info("Task created successfully")
        return task
    }

    func updateTask(_ task: TaskItem) async throws {
        let context = ModelContext(modelContainer)
        task.modifiedAt = Date()
        try context.save()
        Logger.data.info("Task updated successfully")
    }

    func deleteTask(_ task: TaskItem) async throws {
        let context = ModelContext(modelContainer)
        context.delete(task)
        try context.save()
        Logger.data.info("Task deleted successfully")
    }

    func completeTask(_ task: TaskItem) async throws {
        let context = ModelContext(modelContainer)
        task.isCompleted = true
        task.modifiedAt = Date()
        try context.save()
        Logger.data.info("Task completed successfully")
    }
}
```

**IMPORTANT:** Never log task titles or task IDs at `default` or `public` log levels. The examples above use `Logger.data.info()` with generic messages only. [Source: architecture.md#Process Patterns — Error Handling]

**Background context note:** In Story 1.3, `ModelContext(modelContainer)` creates a new context per operation — this is appropriate for a background context. The main context used by `@Query` views is separate and managed by the `.modelContainer()` environment modifier. [Source: architecture.md#Communication Patterns — SwiftData ModelContext Actor Isolation]

---

### ListRepositoryProtocol.swift & ListRepository.swift

```swift
// Core/Repositories/ListRepositoryProtocol.swift
import Foundation

protocol ListRepositoryProtocol: Sendable {
    func fetchLists() async throws -> [TaskList]
    func createList(name: String, colorHex: String) async throws -> TaskList
    func updateList(_ list: TaskList) async throws
    func deleteList(_ list: TaskList) async throws
}
```

```swift
// Core/Repositories/ListRepository.swift
import Foundation
import SwiftData

final class ListRepository: ListRepositoryProtocol {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func fetchLists() async throws -> [TaskList] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<TaskList>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    func createList(name: String, colorHex: String) async throws -> TaskList {
        let context = ModelContext(modelContainer)
        let list = TaskList(name: name, colorHex: colorHex)
        context.insert(list)
        try context.save()
        Logger.data.info("List created successfully")
        return list
    }

    func updateList(_ list: TaskList) async throws {
        let context = ModelContext(modelContainer)
        try context.save()
        Logger.data.info("List updated successfully")
    }

    func deleteList(_ list: TaskList) async throws {
        let context = ModelContext(modelContainer)
        context.delete(list)
        try context.save()
        Logger.data.info("List deleted successfully — cascade deletes tasks")
    }
}
```

---

### WidgetService.swift — Stub for Story 1.3

Stories 1.4–1.7 require `WidgetService.shared.reloadTimelines()` after every mutation. Create a minimal stub now so the service is available:

```swift
// Core/Services/WidgetService.swift
import Foundation
import WidgetKit

@MainActor
final class WidgetService {
    static let shared = WidgetService()

    private init() {}

    func reloadTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
        Logger.widget.info("Widget timelines reload requested")
    }
}
```

**Note:** `WidgetKit` must be linked to the main app target. The `WidgetCenter` API is available in the app target (not just the widget extension). [Source: architecture.md#Communication Patterns — App → WidgetKit]

---

### NotificationService.swift — Stub for Story 1.3

Full implementation is in Story 2.1. Create a minimal singleton stub now:

```swift
// Core/Services/NotificationService.swift
import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    // Full implementation in Story 2.1
    func scheduleNotification(for task: TaskItem) {
        // No-op stub — implemented in Story 2.1
        Logger.notifications.info("Notification schedule requested (stub)")
    }

    func cancelNotification(for task: TaskItem) {
        // No-op stub — implemented in Story 2.1
        Logger.notifications.info("Notification cancel requested (stub)")
    }
}
```

---

### TaskListView.swift — Core View Implementation

```swift
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
        .navigationDestination(for: UUID.self) { taskID in
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
```

**Critical `@Query` note:** The `#Predicate` for Inbox (`task.list == nil`) is how the Inbox works — it is NOT a `TaskList` row, it is a filter predicate. Never add an "Inbox" `TaskList` to the database. [Source: architecture.md#Data Architecture — Inbox Handling, epics.md#Additional Requirements]

**`@Query` is MANDATORY for collection display.** Do not use `viewModel.tasks: [TaskItem]` fetched manually in `.task { }` or `onAppear`. Use `@Query` so SwiftUI reactively updates when SwiftData changes. [Source: architecture.md#AI Agent Guidelines]

---

### TaskListViewModel.swift — Exact Pattern

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

    // Repository injected in Story 1.4 when create/edit operations are added
    // For Story 1.3, the ViewModel is a lightweight error handler only
    // Tasks are driven by @Query in TaskListView directly

    func handleError(_ error: Error) {
        Logger.data.error("TaskList operation failed")
        errorMessage = "Something went wrong. Please try again."
        showError = true
    }
}
```

**Pattern notes:**
- `@Observable` (NOT `ObservableObject`) — mandated by architecture [Source: architecture.md#AI Agent Guidelines]
- `@MainActor` required on all ViewModels [Source: architecture.md#Frontend/UI Architecture]
- No `@Published` — `@Observable` replaces this pattern entirely
- The ViewModel does NOT hold a `[TaskItem]` array — that lives in the `@Query` in the View

---

### TaskRowView.swift — Row UI

```swift
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
```

**Overdue visual distinction (FR9):** `dueDate < Date()` with `isCompleted == false` → red due date label. This is the minimum viable implementation; the full overdue section in Story 2.1 builds on this.

**Accessibility (NFR16):** All interactive elements have descriptive VoiceOver labels. The row uses `.accessibilityElement(children: .combine)` to merge child elements into a single accessible unit.

**Dynamic Type (NFR17):** All text uses system font styles (`.body`, `.caption`) — never hardcoded sizes.

---

### ContentView.swift — Replace Placeholder with TaskListView

Update `ContentView.swift` to replace the current placeholder with `TaskListView`:

```swift
// TODOApp/ContentView.swift
import SwiftUI

struct ContentView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        NavigationStack(path: Bindable(coordinator).navigationPath) {
            TaskListView()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppCoordinator())
        .modelContainer(for: [TaskItem.self, TaskList.self], inMemory: true)
}
```

**Preview note:** Add `.modelContainer(for:inMemory:true)` to the preview so `@Query` in `TaskListView` has a valid context. Without this, Xcode Previews will crash.

---

### AppCoordinator.swift — Update navigateTo for TaskItem

In Story 1.2, `navigateTo(taskID:)` just sets `pendingTaskID`. Story 1.3 introduces `TaskItem` into `NavigationPath`. Update the coordinator to push the UUID onto the path:

```swift
func navigateTo(taskID: UUID) {
    pendingTaskID = taskID
    navigationPath.append(taskID)
}
```

**Note:** `NavigationStack` with a `UUID` destination requires a `.navigationDestination(for: UUID.self)` modifier — which `TaskListView` provides. Full `TaskDetailView` is Story 1.4.

---

### project.pbxproj — New Files to Register

Story 1.3 creates the following new files, all requiring registration in `project.pbxproj`:

**New PBXFileReference entries** (add to file reference section, using next available IDs after A109):
```
A110 /* TaskItem.swift */
A111_SKIP (A111 is TODOAppWidgetBundle.swift — already used)
```

**Use IDs starting from A200 for Story 1.3 files to avoid conflicts:**

| ID    | Comment                  | Path                                      |
|-------|--------------------------|-------------------------------------------|
| A200  | TaskItem.swift           | TaskItem.swift                            |
| A201  | TaskList.swift           | TaskList.swift                            |
| A202  | SchemaV1.swift           | SchemaV1.swift                            |
| A203  | TaskRepositoryProtocol.swift | TaskRepositoryProtocol.swift          |
| A204  | TaskRepository.swift     | TaskRepository.swift                      |
| A205  | ListRepositoryProtocol.swift | ListRepositoryProtocol.swift          |
| A206  | ListRepository.swift     | ListRepository.swift                      |
| A207  | WidgetService.swift      | WidgetService.swift                       |
| A208  | NotificationService.swift | NotificationService.swift                |
| A209  | TaskListView.swift       | TaskListView.swift                        |
| A210  | TaskListViewModel.swift  | TaskListViewModel.swift                   |
| A211  | TaskRowView.swift        | TaskRowView.swift                         |
| A212  | TaskRepositoryTests.swift | TaskRepositoryTests.swift                |

**New PBXBuildFile entries** (using IDs B200–B212):
```
B200 /* TaskItem.swift in Sources */ = {isa = PBXBuildFile; fileRef = A200; };
B201 /* TaskList.swift in Sources */ = ...
... (etc for all app target files)
B212 /* TaskRepositoryTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = A212; };
```

**New PBXGroup entries needed:**
- `D010 /* Models */` — child of D008 (Core), contains A200, A201, D011
- `D011 /* DataMigration */` — child of D010, contains A202
- `D012 /* Repositories */` — child of D008 (Core), contains A203–A206
- `D013 /* Services */` — child of D008 (Core), contains A207, A208
- `D014 /* Features */` — child of D001 (TODOApp group), contains D015
- `D015 /* Tasks */` — child of D014, contains A209–A211

**Add B200–B211 to E001S (Sources for TODOApp) and B212 to E004S (Sources for TODOAppTests).**

**WidgetKit framework linkage:** `WidgetService.swift` uses `WidgetKit`. Add `WidgetKit.framework` to the `C001` Frameworks build phase in `project.pbxproj`. Add a `PBXFileReference` for the framework:
```
FWID1 /* WidgetKit.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = WidgetKit.framework; path = System/Library/Frameworks/WidgetKit.framework; sourceTree = SDKROOT; };
```
And a `PBXBuildFile`:
```
FWBF1 /* WidgetKit.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = FWID1; };
```

---

### Swift 6 Concurrency Requirements

1. **Repositories are NOT `@MainActor`** — they create a `ModelContext(modelContainer)` per operation. This context is created on whatever thread calls the async function. SwiftData `ModelContext` created from a `ModelContainer` off the main actor is fully supported and required by NFR24. [Source: architecture.md#Communication Patterns — SwiftData ModelContext Actor Isolation]

2. **`@MainActor @Observable` ViewModels** — both annotations are REQUIRED together in Swift 6. Do not rely on implicit main actor isolation. [Source: implementation-artifacts/1-2-core-constants-app-entry-point-and-navigation-shell.md#Swift 6 Concurrency Constraints]

3. **`#Predicate` macro** — SwiftData `#Predicate` compiles to a SQL WHERE clause. The expression `task.list == nil` is valid in `#Predicate`. Do NOT write `task.list == Optional.none` or any other form. Test the exact predicate forms with a real `ModelContainer` to catch compilation issues.

4. **`@Query` is always on `@MainActor`** — views are `@MainActor` by default in SwiftUI, so `@Query` in a `View` is fine.

5. **`WidgetService` and `NotificationService` as `@MainActor` singletons** — these call `WidgetCenter` and `UNUserNotificationCenter` which are safe to call from any thread, but the singleton pattern with `@MainActor` matches the call site (ViewModels are `@MainActor`). [Source: architecture.md#Enforcement Guidelines]

6. **`Sendable` protocol conformance on repositories** — Both `TaskRepository` and `ListRepository` must conform to `Sendable` (required by their protocols). Since they hold a `ModelContainer` (which is `Sendable`), this is automatically satisfied when marked `final`.

---

### Previous Story Intelligence (Story 1.2)

**Learnings from Story 1.2 that directly affect this story:**

1. **UUID pattern in `project.pbxproj`** — Story 1.2 used `A106`–`A109` for FileRefs and `A005`–`A008` for BuildFiles. Use `A200`+ for FileRefs and `B200`+ for BuildFiles to stay clearly out of Story 1.2's range. [Source: implementation-artifacts/1-2-core-constants-app-entry-point-and-navigation-shell.md#project.pbxproj — File Registration]

2. **PBXGroup structure** — `D008` is `Core`, `D009` is `Utilities`. New groups `D010`–`D015` should be added as sub-groups of `D008` (for `Models`, `Repositories`, `Services`) and `D001` (for `Features/Tasks`). The `path` attribute on each PBXGroup is the actual folder name, not the full path — Xcode resolves relative to parent group.

3. **`Bindable(coordinator).isShowingAddTask`** — The binding pattern from Story 1.2 `ContentView.swift` works correctly for `@Observable` objects accessed via `@Environment`. Use the same pattern for any new `@Observable` bindings. Do NOT use `$coordinator.isShowingAddTask`.

4. **`TODOAppApp.swift`** — the file is clean with a one-line change needed (schema). No other modifications required in this story.

5. **Test file location** — tests go in `TODOApp/TODOAppTests/` and use `@testable import TODOApp`. The test target is `E004S`. New test files (like `TaskRepositoryTests.swift`) should be added to `D004` PBXGroup and `E004S` Sources.

6. **Concurrency in tests** — `@Suite` structs with `@MainActor` work as shown in `TODOAppTests.swift`. For repository tests (not `@MainActor`), use async `@Test` functions with `await`.

---

### Project Structure Notes

**Files to CREATE in this story:**
```
TODOApp/TODOApp/
├── Core/
│   ├── Models/
│   │   ├── TaskItem.swift                    ← NEW (@Model)
│   │   ├── TaskList.swift                    ← NEW (@Model, cascade delete)
│   │   └── DataMigration/
│   │       └── SchemaV1.swift                ← NEW (VersionedSchema)
│   ├── Repositories/
│   │   ├── TaskRepositoryProtocol.swift      ← NEW (protocol)
│   │   ├── TaskRepository.swift              ← NEW (SwiftData impl)
│   │   ├── ListRepositoryProtocol.swift      ← NEW (protocol)
│   │   └── ListRepository.swift              ← NEW (SwiftData impl)
│   └── Services/
│       ├── WidgetService.swift               ← NEW (singleton, WidgetKit)
│       └── NotificationService.swift         ← NEW (stub singleton)
└── Features/
    └── Tasks/
        ├── TaskListView.swift                ← NEW (@Query, Inbox filter)
        ├── TaskListViewModel.swift           ← NEW (@Observable @MainActor)
        └── TaskRowView.swift                 ← NEW (row UI, overdue highlight)

TODOApp/TODOAppTests/
└── TaskRepositoryTests.swift                 ← NEW (unit tests, in-memory ModelContainer)
```

**Files to MODIFY in this story:**
```
TODOApp/TODOApp/TODOAppApp.swift              ← Add TaskItem.self, TaskList.self to Schema
TODOApp/TODOApp/ContentView.swift             ← Replace placeholder with TaskListView()
TODOApp/TODOApp/AppCoordinator.swift          ← Update navigateTo to append UUID to navigationPath
TODOApp/TODOApp.xcodeproj/project.pbxproj    ← Register all new files + WidgetKit framework
```

**Architecture alignment:**
- `Core/Models/` — mandated location for SwiftData model definitions [Source: architecture.md#Structure Patterns — Shared Code Placement]
- `Core/Repositories/` — mandated location for data access protocols and implementations
- `Core/Services/` — mandated location for cross-cutting services
- `Features/Tasks/` — feature-folder structure; ALL task-related views and view models belong here
- **Do NOT** create `Features/Tasks/ViewModels/` or `Features/Tasks/Views/` subdirectories — feature-folder means flat within the feature folder [Source: architecture.md#Structure Patterns — Feature-Folder Organization]

---

### References

- [Source: epics.md#Story 1.3 Acceptance Criteria] — Full BDD acceptance criteria for models, repositories, task list view
- [Source: architecture.md#Data Architecture] — `TaskItem` and `TaskList` model definitions with exact field names and types
- [Source: architecture.md#Data Architecture — Inbox Handling] — Inbox is `task.list == nil` predicate, NOT a `TaskList` row
- [Source: architecture.md#Communication Patterns — Repository Protocol Pattern] — `TaskRepositoryProtocol` exact method signatures
- [Source: architecture.md#Communication Patterns — SwiftData ModelContext Actor Isolation] — Background context pattern for repository implementations
- [Source: architecture.md#Communication Patterns — Post-Mutation Side Effects] — WidgetService + NotificationService mandatory after every mutation
- [Source: architecture.md#Structure Patterns — Feature-Folder Organization] — `Features/Tasks/` flat structure
- [Source: architecture.md#Structure Patterns — Shared Code Placement] — `Core/Models/`, `Core/Repositories/`, `Core/Services/`
- [Source: architecture.md#Naming Patterns] — `TaskItem` (not `Task`), `TaskList` (not `List`)
- [Source: architecture.md#Format Patterns — Color Storage] — `colorHex: String` not `Color`
- [Source: architecture.md#AI Agent Guidelines] — `@Observable` + `@MainActor` for all ViewModels; `@Query` for collection display; never `fetch()` in `onAppear`
- [Source: architecture.md#Frontend/UI Architecture — Performance] — `@Query` predicate filtering in SwiftData (not Swift)
- [Source: architecture.md#Enforcement Guidelines] — WidgetService call required after every task mutation
- [Source: epics.md#Additional Requirements] — Inbox is `task.list == nil`; `isCompleted` conflict resolution is additive
- [Source: implementation-artifacts/1-2-core-constants-app-entry-point-and-navigation-shell.md#Dev Agent Record] — Story 1.2 completion state; existing AppCoordinator pattern; `Bindable(coordinator)` binding pattern

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

No debug issues encountered. All implementation followed story Dev Notes exactly.

### Completion Notes List

- Implemented `TaskItem` and `TaskList` SwiftData `@Model` classes with all required properties per AC#1. `TaskList` has `@Relationship(deleteRule: .cascade)` on `tasks`. `colorHex` is `String` not `Color`.
- Implemented `SchemaV1` as a `VersionedSchema` enum for future migration readiness (not referenced in `TODOAppApp.swift` directly yet).
- Updated `TODOAppApp.swift` schema to include `TaskItem.self, TaskList.self`.
- Implemented `TaskRepositoryProtocol` and `TaskRepository` (background `ModelContext` per operation, `Sendable`).
- Implemented `ListRepositoryProtocol` and `ListRepository` following same pattern.
- Created `WidgetService` singleton (`@MainActor`, links `WidgetKit.framework`) with `reloadTimelines()` stub.
- Created `NotificationService` singleton stub (`@MainActor`) with no-op `scheduleNotification` and `cancelNotification`.
- Implemented `TaskListView` with `@Query(filter: #Predicate { $0.list == nil })` for Inbox, empty state view, toolbar with add button, VoiceOver accessibility labels (NFR16), Dynamic Type styles (NFR17).
- Implemented `TaskListViewModel` as `@Observable @MainActor` lightweight error handler.
- Implemented `TaskRowView` with overdue highlight (red due date when `dueDate < now && !isCompleted`), strikethrough for completed tasks, combined accessibility element.
- Updated `ContentView.swift` to replace placeholder with `TaskListView()` inside `NavigationStack`. Preview updated with `.modelContainer(for:inMemory:true)`.
- Updated `AppCoordinator.navigateTo(taskID:)` to append UUID to `navigationPath`.
- Added `TaskItem` and `TaskList` model tests, repository tests using in-memory `ModelContainer` covering create, fetch, complete, delete.
- Added `WidgetKit.framework` to main app Frameworks build phase in `project.pbxproj`.
- All 13 new source files and 1 new test file registered in `project.pbxproj` with correct PBXFileReference, PBXBuildFile, PBXGroup, and Sources build phase entries.

### File List

**New Files:**
- `TODOApp/TODOApp/Core/Models/TaskItem.swift`
- `TODOApp/TODOApp/Core/Models/TaskList.swift`
- `TODOApp/TODOApp/Core/Models/DataMigration/SchemaV1.swift`
- `TODOApp/TODOApp/Core/Repositories/TaskRepositoryProtocol.swift`
- `TODOApp/TODOApp/Core/Repositories/TaskRepository.swift`
- `TODOApp/TODOApp/Core/Repositories/ListRepositoryProtocol.swift`
- `TODOApp/TODOApp/Core/Repositories/ListRepository.swift`
- `TODOApp/TODOApp/Core/Services/WidgetService.swift`
- `TODOApp/TODOApp/Core/Services/NotificationService.swift`
- `TODOApp/TODOApp/Features/Tasks/TaskListView.swift`
- `TODOApp/TODOApp/Features/Tasks/TaskListViewModel.swift`
- `TODOApp/TODOApp/Features/Tasks/TaskRowView.swift`
- `TODOApp/TODOAppTests/TaskRepositoryTests.swift`

**Modified Files:**
- `TODOApp/TODOApp/TODOAppApp.swift` — Added `TaskItem.self, TaskList.self` to Schema
- `TODOApp/TODOApp/ContentView.swift` — Replaced placeholder with `TaskListView()`; updated preview
- `TODOApp/TODOApp/AppCoordinator.swift` — Updated `navigateTo(taskID:)` to append UUID to `navigationPath`
- `TODOApp/TODOAppTests/TODOAppTests.swift` — Added `TaskItem` and `TaskList` model tests
- `TODOApp/TODOApp.xcodeproj/project.pbxproj` — Registered all new files, groups, and WidgetKit.framework
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — Updated `1-3` to `in-progress` → `review`

## Change Log

- 2026-02-18: Story 1.3 implemented — SwiftData models, repositories, services stubs, TaskListView/ViewModel/RowView, ContentView navigation wired, unit tests added (Date: 2026-02-18)
