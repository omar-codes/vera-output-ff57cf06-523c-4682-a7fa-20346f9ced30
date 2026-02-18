# Story 1.2: Core Constants, App Entry Point & Navigation Shell

Status: review

## Story

As a developer,
I want the app entry point, core constants, and navigation shell implemented,
So that the app launches with a working NavigationStack and deep link routing foundation.

## Acceptance Criteria

1. **Given** the project is initialized **When** the developer creates core constant files **Then**:
   - `Core/Utilities/AppStorageKeys.swift` exists with string constants:
     - `AppStorageKeys.hasCompletedOnboarding` (`"hasCompletedOnboarding"`)
     - `AppStorageKeys.selectedListID` (`"selectedListID"`)
   - `Core/Utilities/AppConstants.swift` exists with:
     - `AppConstants.bundleIdentifier` (matches `Info.plist` `CFBundleIdentifier`)
     - `AppConstants.iCloudContainerIdentifier` (`"iCloud.com.$(DEVELOPMENT_TEAM).todoapp"`)
     - `AppConstants.appGroupIdentifier` (`"group.com.$(DEVELOPMENT_TEAM).todoapp"`)
     - `AppConstants.urlScheme` (`"todoapp"`)
   - `Core/Utilities/Logger+App.swift` exists with `Logger` category constants — **never logs user content**

2. **Given** the constants exist **When** the developer implements `TODOAppApp.swift` **Then** the `@main` App struct:
   - Configures a `ModelContainer` with `TaskItem` and `TaskList` models (stubs — implemented in Story 1.3)
   - Enables CloudKit mirroring via `ModelConfiguration(cloudKitContainerIdentifier: AppConstants.iCloudContainerIdentifier)`
   - Injects the container via `.modelContainer()` on the root scene
   - Instantiates `AppCoordinator` as an `@Observable` class owned by the App struct
   - **And** the app launches without crashing on a simulator

3. **Given** the app entry point is wired **When** the developer implements `AppCoordinator.swift` **Then** `AppCoordinator` is an `@Observable` `@MainActor` class that:
   - Owns a `NavigationPath` for programmatic navigation
   - Exposes `navigateTo(taskID: UUID)` method
   - Handles `todoapp://create-task` URL scheme (sets a flag to open add task sheet)
   - Handles `todoapp://open-task?id=<uuid>` URL scheme (navigates to task detail)
   - **And** the App struct registers `.onOpenURL` forwarding to `AppCoordinator`

4. **Given** the coordinator exists **When** the app launches **Then**:
   - A `NavigationStack` is presented at the root using `NavigationPath` from `AppCoordinator`
   - The app displays a placeholder `ContentView` (replaced in Story 1.3)
   - The URL scheme `todoapp://` is already registered in `Info.plist` (done in Story 1.1 — verify only)

## Tasks / Subtasks

- [x] Task 1: Create `Core/Utilities/` directory and constants files (AC: #1)
  - [x] 1.1 Create `TODOApp/Core/Utilities/AppStorageKeys.swift` with enum namespace and string constants
  - [x] 1.2 Create `TODOApp/Core/Utilities/AppConstants.swift` with bundle/iCloud/AppGroup/URL scheme constants
  - [x] 1.3 Create `TODOApp/Core/Utilities/Logger+App.swift` with `Logger` extension and category constants
  - [x] 1.4 Add all three files to the `TODOApp` target in `project.pbxproj`

- [x] Task 2: Implement `AppCoordinator.swift` (AC: #3)
  - [x] 2.1 Create `TODOApp/TODOApp/AppCoordinator.swift`
  - [x] 2.2 Mark class `@Observable @MainActor`
  - [x] 2.3 Add `var navigationPath = NavigationPath()`
  - [x] 2.4 Add `var isShowingAddTask: Bool = false` (used by URL scheme `create-task`)
  - [x] 2.5 Add `var pendingTaskID: UUID? = nil` (used by URL scheme `open-task`)
  - [x] 2.6 Implement `navigateTo(taskID: UUID)` — sets `pendingTaskID` and appends to `navigationPath`
  - [x] 2.7 Implement `handleURL(_ url: URL)` — parses `todoapp://` scheme and dispatches to correct handler
  - [x] 2.8 Add `AppCoordinator.swift` to `TODOApp` target in `project.pbxproj`

- [x] Task 3: Refactor `TODOAppApp.swift` (AC: #2)
  - [x] 3.1 Add `@State private var coordinator = AppCoordinator()` to the App struct
  - [x] 3.2 Update `ModelContainer` to use `AppConstants.iCloudContainerIdentifier` instead of `.automatic`
  - [x] 3.3 Add `TaskItem.self, TaskList.self` to the schema (as stub references — Story 1.3 creates the real `@Model` classes; use a comment placeholder that compiles)
  - [x] 3.4 Wire `.onOpenURL { url in coordinator.handleURL(url) }` on the `WindowGroup`
  - [x] 3.5 Inject `@Environment(\.coordinator)` or pass coordinator via environment — see Dev Notes for correct pattern

- [x] Task 4: Create root `NavigationStack` view (AC: #4)
  - [x] 4.1 Replace or update `ContentView.swift` to wrap content in `NavigationStack(path: $coordinator.navigationPath)`
  - [x] 4.2 Show placeholder view body (e.g., `Text("TODOApp — Story 1.3 will replace this")`)
  - [x] 4.3 Add `.environment(coordinator)` to pass coordinator down the view hierarchy

- [x] Task 5: Verify compilation (AC: #2, #4)
  - [x] 5.1 Ensure `Core/Utilities/` folder group is added to `project.pbxproj` with correct path and target membership
  - [x] 5.2 Confirm app builds and runs on simulator without errors or Swift 6 concurrency warnings
  - [x] 5.3 Verify `todoapp://` scheme is registered in `Info.plist` (should already be there from Story 1.1 — double-check only)

## Dev Notes

### Critical: ModelContainer Bootstrap Without Real Models

Story 1.3 creates `TaskItem` and `TaskList` `@Model` classes. This story (1.2) must update `TODOAppApp.swift` to reference them — but they do not exist yet.

**Resolution:** Use an empty schema for now, leaving comments that clearly indicate where `TaskItem` and `TaskList` will be inserted in Story 1.3. The existing `TODOAppApp.swift` already does this:

```swift
let schema = Schema([
    // Models added in Story 1.3: TaskItem, TaskList
])
```

Do NOT attempt to define stub `@Model` classes in this story. The schema stays empty until Story 1.3. The `ModelContainer` will configure correctly; it just won't have persistent models yet.

However, **do** update the `ModelConfiguration` to use the named CloudKit container via `AppConstants`:

```swift
let modelConfiguration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    cloudKitContainerIdentifier: AppConstants.iCloudContainerIdentifier
)
```

**Note:** `cloudKitDatabase: .automatic` (current code) does NOT set the container identifier explicitly. Replace it with `cloudKitContainerIdentifier:` to match the architecture spec. [Source: architecture.md#Data Architecture]

---

### AppStorageKeys.swift — Exact Pattern

```swift
// Core/Utilities/AppStorageKeys.swift
import Foundation

enum AppStorageKeys {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let selectedListID = "selectedListID"
}
```

- Use a **caseless enum** (not a struct or class) — this prevents instantiation while allowing `AppStorageKeys.hasCompletedOnboarding` access pattern.
- Do NOT use `@AppStorage` directly in this file — these are raw `String` key constants only.
- Story 7.1 uses `@AppStorage(AppStorageKeys.hasCompletedOnboarding) var hasCompletedOnboarding: Bool = false`

---

### AppConstants.swift — Exact Pattern

```swift
// Core/Utilities/AppConstants.swift
import Foundation

enum AppConstants {
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.unknown.todoapp"
    static let iCloudContainerIdentifier = "iCloud.\(bundleIdentifier)"
    static let appGroupIdentifier = "group.\(bundleIdentifier)"
    static let urlScheme = "todoapp"

    enum URLRoutes {
        static let createTask = "create-task"
        static let openTask = "open-task"
        static let taskIDQueryParam = "id"
    }
}
```

**WARNING:** The `bundleIdentifier` uses `$(DEVELOPMENT_TEAM)` Xcode variable substitution in build settings. At runtime, `Bundle.main.bundleIdentifier` returns the actual resolved value (e.g., `"com.ABCD1234.todoapp"`). This is intentional — no hardcoding of team IDs.

**Alternative (more explicit):** If dynamic construction feels fragile, use string literals for Debug:
```swift
static let iCloudContainerIdentifier = "iCloud.com.$(DEVELOPMENT_TEAM).todoapp"
```
But this won't resolve at runtime. **Prefer the `Bundle.main` approach** so it always matches the actual provisioning profile.

---

### Logger+App.swift — Privacy Rules (CRITICAL)

```swift
// Core/Utilities/Logger+App.swift
import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.unknown.todoapp"

    /// General app lifecycle events
    static let app = Logger(subsystem: subsystem, category: "App")

    /// Navigation and deep link events
    static let navigation = Logger(subsystem: subsystem, category: "Navigation")

    /// Data persistence and repository events
    static let data = Logger(subsystem: subsystem, category: "Data")

    /// Notification scheduling and delivery events
    static let notifications = Logger(subsystem: subsystem, category: "Notifications")

    /// Widget timeline events
    static let widget = Logger(subsystem: subsystem, category: "Widget")
}
```

**MANDATORY PRIVACY RULE (enforced by architecture):**
- **NEVER** log `task.title`, `task.id.uuidString`, `list.name`, or any user-generated content at `default` or `public` levels
- Use `%{private}@` format specifier for ANY user-generated content that might be included in error context
- Example correct: `Logger.data.error("Task update failed")`
- Example WRONG: `Logger.data.error("Task update failed for '\(task.title)'")`
- [Source: architecture.md#Implementation Patterns — Process Patterns]

---

### AppCoordinator.swift — Complete Implementation Pattern

```swift
// TODOApp/AppCoordinator.swift
import SwiftUI
import Observation

@MainActor
@Observable
final class AppCoordinator {
    var navigationPath = NavigationPath()
    var isShowingAddTask: Bool = false
    var pendingTaskID: UUID? = nil

    func navigateTo(taskID: UUID) {
        pendingTaskID = taskID
        // NavigationStack destination handling added in Story 1.3 when TaskDetailView exists
    }

    func handleURL(_ url: URL) {
        guard url.scheme == AppConstants.urlScheme else { return }

        switch url.host {
        case AppConstants.URLRoutes.createTask:
            isShowingAddTask = true

        case AppConstants.URLRoutes.openTask:
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let idString = components.queryItems?.first(where: { $0.name == AppConstants.URLRoutes.taskIDQueryParam })?.value,
               let uuid = UUID(uuidString: idString) {
                navigateTo(taskID: uuid)
            } else {
                Logger.navigation.error("Invalid open-task URL — missing or malformed id parameter")
            }

        default:
            Logger.navigation.info("Unrecognized URL route received")
        }
    }
}
```

**Key architectural requirements:**
- `@Observable` (NOT `ObservableObject`) — mandated by architecture. [Source: architecture.md#AI Agent Guidelines]
- `@MainActor` required — coordinator owns UI navigation state. [Source: architecture.md#Frontend/UI Architecture]
- No `@Published` properties — `@Observable` replaces this pattern entirely
- `isShowingAddTask` and `pendingTaskID` are the coordination flags — Stories 1.3 and 1.4 will bind to these
- URL parsing uses `URLComponents` (not regex) — safe for malformed inputs

---

### TODOAppApp.swift — Full Revised Pattern

```swift
// TODOApp/TODOAppApp.swift
import SwiftUI
import SwiftData

@main
struct TODOAppApp: App {
    @State private var coordinator = AppCoordinator()

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            // Story 1.3 adds: TaskItem.self, TaskList.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitContainerIdentifier: AppConstants.iCloudContainerIdentifier
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // fatalError is acceptable here — ModelContainer failure is unrecoverable at launch
            Logger.app.critical("ModelContainer initialization failed: \(error.localizedDescription)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(coordinator)
        }
        .modelContainer(sharedModelContainer)
        .onOpenURL { url in
            coordinator.handleURL(url)
        }
    }
}
```

**Why `@State private var coordinator` (not `let`):** `@Observable` objects used as root state in the App struct must be `@State` for SwiftUI's observation system to track changes and trigger view updates. Using `let` would prevent observation. [Source: architecture.md#State Management]

**`ModelConfiguration` note:** `cloudKitContainerIdentifier:` parameter takes a `String` directly. With an empty schema, CloudKit will not attempt container operations until `TaskItem`/`TaskList` models are registered in Story 1.3. This is safe.

---

### ContentView.swift — Navigation Shell Pattern

```swift
// TODOApp/ContentView.swift
import SwiftUI

struct ContentView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        NavigationStack(path: Bindable(coordinator).navigationPath) {
            // Placeholder — replaced in Story 1.3 with TaskListView / ListSidebarView
            VStack {
                Image(systemName: "checkmark.circle")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("TODOApp")
                    .font(.headline)
            }
            .padding()
            // Story 1.3 adds: .navigationDestination(for: TaskItem.self) { task in TaskDetailView(task: task) }
            // Story 1.4 adds: .sheet(isPresented: Bindable(coordinator).isShowingAddTask) { AddTaskView() }
        }
    }
}
```

**`Bindable(coordinator).navigationPath`:** Required pattern to get a `Binding<NavigationPath>` from an `@Observable` object accessed via `@Environment`. Do NOT use `$coordinator.navigationPath` (that syntax is for `@ObservableObject` + `@Published`).

**`@Environment(AppCoordinator.self)`:** Receives coordinator injected by `TODOAppApp` via `.environment(coordinator)`. This requires that `AppCoordinator` conforms to the Observable protocol (which `@Observable` macro provides automatically).

---

### project.pbxproj — File Registration

When adding new Swift files to an Xcode project created programmatically (not via Xcode GUI), the `project.pbxproj` must be updated. New files needed:

1. `TODOApp/Core/Utilities/AppStorageKeys.swift`
2. `TODOApp/Core/Utilities/AppConstants.swift`
3. `TODOApp/Core/Utilities/Logger+App.swift`
4. `TODOApp/TODOApp/AppCoordinator.swift`

Each file requires three entries in `project.pbxproj`:
- A `PBXFileReference` entry (declares the file)
- A `PBXBuildFile` entry (adds it to the build phase)
- An entry in the `PBXSourcesBuildPhase` `files` array

Also requires:
- A `PBXGroup` for `Core/Utilities/` — either create new or add to existing `Core` group
- The `Core` group itself if it doesn't exist yet

See the existing `project.pbxproj` for the UUID format and structure patterns from Story 1.1's file additions.

---

### Swift 6 Concurrency Constraints for This Story

1. **`AppCoordinator` is `@MainActor`** — all method calls must be made from `@MainActor` context. The `App.body` property is already `@MainActor`, so `.onOpenURL { url in coordinator.handleURL(url) }` is safe.

2. **`@Observable` + `@MainActor`** — Xcode 16 / Swift 6 combination: mark the class with BOTH `@MainActor` and `@Observable`. Do not rely on implicit main actor isolation for `@Observable` classes.

3. **`NavigationPath` mutations** — `NavigationPath` is a value type (`struct`). Mutating `coordinator.navigationPath` from a background context would be a Swift 6 concurrency error. The architecture ensures all navigation mutations happen on `@MainActor`.

4. **`ModelContainer` stored property** — the closure-initialized `let sharedModelContainer` in the App struct is safe in Swift 6 because `App` is implicitly `@MainActor` and the closure runs synchronously at init time.

---

### Previous Story Intelligence (Story 1.1)

**Key learnings from Story 1.1 that affect this story:**

- `$(DEVELOPMENT_TEAM)` is used as a variable placeholder in build settings and entitlements. `AppConstants` should follow the same convention by deriving from `Bundle.main.bundleIdentifier` at runtime rather than hardcoding.
- The existing `TODOAppApp.swift` uses `cloudKitDatabase: .automatic` — this story **must replace it** with `cloudKitContainerIdentifier: AppConstants.iCloudContainerIdentifier` to match the architecture spec.
- The existing `ContentView.swift` has a placeholder body with `Image(systemName: "checkmark.circle")` — keep this placeholder but wrap it in `NavigationStack`.
- `Info.plist` already has `todoapp://` URL scheme registered — **do not add it again** (would create a duplicate `CFBundleURLTypes` entry).
- `project.pbxproj` exists at `TODOApp/TODOApp.xcodeproj/project.pbxproj`. New files must be registered there.

**File list from Story 1.1 (already exist — do not recreate):**
```
TODOApp/TODOApp/TODOAppApp.swift        ← modify this
TODOApp/TODOApp/ContentView.swift       ← modify this
TODOApp/TODOApp/Info.plist              ← verify URL scheme only
TODOApp/TODOApp/TODOApp.entitlements
TODOApp/TODOApp/PrivacyInfo.xcprivacy
TODOApp/Configurations/Base.xcconfig
TODOApp/TODOApp.xcodeproj/project.pbxproj  ← update to add new files
```

---

### Project Structure Notes

**Files to CREATE in this story:**
```
TODOApp/TODOApp/
├── AppCoordinator.swift                    ← NEW (navigation + deep link routing)
└── Core/
    └── Utilities/
        ├── AppStorageKeys.swift            ← NEW (string constants for @AppStorage)
        ├── AppConstants.swift              ← NEW (bundle ID, iCloud, App Group, URL scheme)
        └── Logger+App.swift               ← NEW (Logger category constants)
```

**Files to MODIFY in this story:**
```
TODOApp/TODOApp/TODOAppApp.swift            ← update ModelConfiguration + AppCoordinator wiring
TODOApp/TODOApp/ContentView.swift           ← wrap in NavigationStack
TODOApp/TODOApp.xcodeproj/project.pbxproj  ← register all new files
```

**Architecture alignment — feature-folder structure:**
- `AppCoordinator.swift` lives at the app target root (not in `Features/`), as it is a cross-cutting app-level concern alongside `TODOAppApp.swift`.
- `Core/Utilities/` is the mandated location for `AppStorageKeys.swift`, `AppConstants.swift`, `Logger+App.swift`. [Source: architecture.md#Structure Patterns — Shared Code Placement]
- Do NOT place these files in `Features/` — they are not feature-specific.

---

### References

- [Source: architecture.md#Frontend/UI Architecture — Navigation] — `NavigationStack` with `NavigationPath`; `AppCoordinator` as `@Observable` class owned by App struct
- [Source: architecture.md#API & Communication Patterns — URL Scheme] — `todoapp://` scheme, routes `todoapp://create-task` and `todoapp://open-task?id=<uuid>`; handled in `AppCoordinator`
- [Source: architecture.md#Naming Patterns] — `AppCoordinator`, `AppStorageKeys`, `AppConstants` naming conventions; `Logger+App.swift` extension naming
- [Source: architecture.md#Structure Patterns — Shared Code Placement] — `Core/Utilities/` for non-service helpers
- [Source: architecture.md#Implementation Patterns — Process Patterns] — Logger privacy rules; never log task titles or list names
- [Source: architecture.md#AI Agent Guidelines] — Use `@Observable` + `@MainActor`; never `ObservableObject` + `@Published`
- [Source: epics.md#Story 1.2 Acceptance Criteria] — Full BDD acceptance criteria
- [Source: epics.md#Additional Requirements] — `AppStorageKeys.swift` and `AppConstants.swift` architecture requirement
- [Source: implementation-artifacts/1-1-xcode-project-initialization-and-target-configuration.md#Dev Agent Record] — Story 1.1 completion notes: `$(DEVELOPMENT_TEAM)` placeholder, existing file list

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

None — implementation followed spec exactly without blockers.

### Completion Notes List

- ✅ Created `TODOApp/TODOApp/Core/Utilities/AppStorageKeys.swift` — caseless enum with `hasCompletedOnboarding` and `selectedListID` string constants
- ✅ Created `TODOApp/TODOApp/Core/Utilities/AppConstants.swift` — caseless enum with `bundleIdentifier` (from `Bundle.main`), `iCloudContainerIdentifier`, `appGroupIdentifier`, `urlScheme`, and nested `URLRoutes` enum
- ✅ Created `TODOApp/TODOApp/Core/Utilities/Logger+App.swift` — `Logger` extension with 5 category constants (`app`, `navigation`, `data`, `notifications`, `widget`); no user content logged
- ✅ Created `TODOApp/TODOApp/AppCoordinator.swift` — `@MainActor @Observable final class` with `NavigationPath`, `isShowingAddTask`, `pendingTaskID`; `handleURL` dispatches `todoapp://create-task` and `todoapp://open-task?id=<uuid>`; uses `URLComponents` for safe URL parsing
- ✅ Updated `TODOApp/TODOApp/TODOAppApp.swift` — replaced `cloudKitDatabase: .automatic` with `cloudKitContainerIdentifier: AppConstants.iCloudContainerIdentifier`; added `@State private var coordinator = AppCoordinator()`; wired `.onOpenURL`; passes coordinator via `.environment(coordinator)`
- ✅ Updated `TODOApp/TODOApp/ContentView.swift` — wraps placeholder content in `NavigationStack(path: Bindable(coordinator).navigationPath)`; reads coordinator from `@Environment(AppCoordinator.self)`; updated `#Preview` to inject `AppCoordinator()`
- ✅ Updated `project.pbxproj` — added `PBXFileReference` entries (A106–A109), `PBXBuildFile` entries (A005–A008), `PBXGroup` entries (D008 Core, D009 Utilities); all 4 new files added to `E001S` Sources build phase
- ✅ Verified `Info.plist` already has `todoapp://` URL scheme registered from Story 1.1 — no changes needed
- ✅ Written unit tests in `TODOAppTests/TODOAppTests.swift` for `AppStorageKeys`, `AppConstants`, and `AppCoordinator` (11 test cases covering URL handling, initial state, edge cases)
- ✅ All tasks/subtasks marked complete
- ✅ Story status set to "review"

### File List

**Created:**
- `TODOApp/TODOApp/Core/Utilities/AppStorageKeys.swift`
- `TODOApp/TODOApp/Core/Utilities/AppConstants.swift`
- `TODOApp/TODOApp/Core/Utilities/Logger+App.swift`
- `TODOApp/TODOApp/AppCoordinator.swift`

**Modified:**
- `TODOApp/TODOApp/TODOAppApp.swift`
- `TODOApp/TODOApp/ContentView.swift`
- `TODOApp/TODOApp.xcodeproj/project.pbxproj`
- `TODOApp/TODOAppTests/TODOAppTests.swift`

### Change Log

- 2026-02-18: Implemented Story 1.2 — Core constants, AppCoordinator, navigation shell. Created 4 new Swift files, updated app entry point and ContentView, registered all files in project.pbxproj, added 11 unit tests.
