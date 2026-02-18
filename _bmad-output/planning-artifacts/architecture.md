---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
inputDocuments: ['_bmad-output/planning-artifacts/prd.md']
workflowType: 'architecture'
project_name: 'workspace'
user_name: 'Root'
date: '2026-02-18'
lastStep: 8
status: 'complete'
completedAt: '2026-02-18'
---

# Architecture Decision Document — iOS TODO App

**Author:** Root
**Date:** 2026-02-18
**Platform:** iOS only (iPhone + iPad) · Greenfield · SwiftUI / SwiftData / CloudKit

---

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**

The PRD defines 43 functional requirements across 8 categories. Architecturally, each category maps cleanly to a discrete layer or module:

| FR Category | FR Count | Architectural Layer |
|---|---|---|
| Task Management (FR1–FR9) | 9 | Domain model + SwiftData + ViewModel |
| List Organization (FR10–FR16) | 7 | Domain model + SwiftData + ViewModel |
| Notifications & Reminders (FR17–FR20) | 4 | NotificationService (UserNotifications) |
| Widget Surface (FR21–FR25) | 5 | WidgetKit extension target |
| Siri & Voice Capture (FR26–FR28) | 3 | AppIntents extension target |
| Sync & Data (FR29–FR33) | 5 | CloudKit / SwiftData sync layer |
| Onboarding (FR34–FR36) | 3 | OnboardingCoordinator + AppStorage flags |
| System Integration (FR37–FR39) | 3 | CoreSpotlight (Growth) + URL scheme |
| Appearance & Settings (FR40–FR43) | 4 | SwiftUI environment + AppStorage |

**Non-Functional Requirements (architecturally significant):**

- **NFR1 — <400ms cold launch:** Demands lazy SwiftData initialization; no sync blocking on main thread at startup.
- **NFR2 — 100ms UI response:** All SwiftData queries and CloudKit operations must run off the main actor; UI updates via `@Observable` / `@Query` macros.
- **NFR3 — 3s iCloud sync round-trip:** Acceptable for CloudKit private database without custom batching.
- **NFR6 — Zero task data loss:** SwiftData persistent store must be the primary truth; CloudKit is an additive mirror.
- **NFR11–NFR15 — Privacy:** No third-party SDKs. PrivacyInfo.xcprivacy declares "Data Not Collected." No analytics, no telemetry.
- **NFR16–NFR20 — Accessibility:** VoiceOver labels, Dynamic Type, WCAG 2.1 AA contrast, Reduce Motion.
- **NFR24 — CloudKit off main thread:** All `ModelContext` saves and CKDatabase operations must be on a background actor.

**Scale & Complexity:**

- Primary domain: iOS native mobile application
- Complexity level: **Low** (single-user, single CloudKit container, no backend, no auth system to design)
- Estimated architectural components: 5 targets (main app, WidgetKit extension, App Intents extension, shared framework, test target)

### Technical Constraints & Dependencies

- **iOS 17+ minimum** — enables SwiftData (no Core Data fallback needed; ~80%+ device coverage as of 2026)
- **Swift 6 / Xcode 16** — strict concurrency; all `@MainActor` / background actor isolation must be explicit
- **No custom backend** — CloudKit private database handles all sync; no REST API to design
- **Single developer** — architecture must minimize framework surface area and tooling overhead
- **App Store distribution only** — requires entitlements: iCloud, Siri, Push Notifications (local), App Intents

### Cross-Cutting Concerns Identified

1. **Concurrency Safety** — Swift 6 strict concurrency affects every layer; `@Observable` classes and SwiftData `ModelContext` must be actor-isolated correctly
2. **Data Persistence & Sync** — SwiftData + CloudKit mirroring must be configured at app initialization; affects task, list, and settings storage
3. **Notification Lifecycle** — notification scheduling, cancellation, and rescheduling after offline recovery is a system-wide concern
4. **Widget Timeline Invalidation** — any task state change must call `WidgetCenter.shared.reloadAllTimelines()`; this is a cross-cutting side-effect of every task mutation
5. **Accessibility** — VoiceOver labels and Dynamic Type are a UI-level concern applied to every view
6. **Reduce Motion** — animation suppression is a SwiftUI environment value consumed by every animated view

---

## Starter Template Evaluation

### Primary Technology Domain

**Native iOS application** — no cross-platform framework applies. The project starts from an Xcode new project wizard target, not a third-party CLI starter. This is standard for Swift/SwiftUI iOS development.

### Starter Options Considered

| Option | Notes |
|---|---|
| `Xcode → New Project → App (SwiftUI + SwiftData)` | Official Apple template; includes SwiftData stack, CloudKit entitlement checkbox, and all required capabilities |
| Third-party SwiftUI boilerplate (GitHub) | Unmaintained relative to Swift evolution pace; introduces unknown opinions |
| React Native / Flutter | Explicitly excluded by iOS-only constraint and PRD |

### Selected Starter: Xcode New Project — App template (SwiftUI + SwiftData + CloudKit)

**Rationale for Selection:**
The Apple-provided template wires up the `ModelContainer` with `.cloudKitContainerOptions` in a single checkbox. It generates a correctly-structured `@main` App entry point, Scene configuration, and basic `ContentView`. Starting here avoids manual boilerplate errors and stays current with Swift/SwiftUI changes.

**Initialization Command:**

```bash
# In Xcode 16:
# File → New → Project → iOS → App
# Product Name: TODOApp
# Team: <developer team>
# Bundle Identifier: com.<team>.todoapp
# Interface: SwiftUI
# Language: Swift
# ☑ Use SwiftData
# ☑ Include Tests
# After creation, add iCloud capability and check CloudKit
```

**Architectural Decisions Provided by Starter:**

**Language & Runtime:**
- Swift 6.0 with strict concurrency enabled (`-strict-concurrency=complete`)
- iOS 17.0 deployment target
- arm64 architecture

**UI Framework:**
- SwiftUI — entire UI surface; no UIKit unless required for a missing SwiftUI API

**Persistence:**
- SwiftData with CloudKit mirroring via `ModelConfiguration(cloudKitContainerIdentifier:)`

**Build Tooling:**
- Xcode 16 build system; Swift Package Manager for any dependencies (none planned for MVP)

**Testing Framework:**
- XCTest for unit and integration tests; Swift Testing framework for new tests
- XCUITest for UI tests

**Code Organization:**
- Feature-folder structure within the single app target (described in Project Structure section)

**Development Experience:**
- Xcode Previews for rapid SwiftUI iteration
- Swift compiler strict concurrency warnings as errors
- Instruments for performance profiling (cold launch, memory, CloudKit activity)

**Note:** Project initialization using the Xcode template should be the first implementation story.

---

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**

1. SwiftData as persistence layer (iOS 17+ required)
2. CloudKit private database for sync (no custom backend)
3. Swift 6 strict concurrency model — all context operations actor-isolated
4. MVVM + `@Observable` as UI architecture pattern
5. `UserNotifications` framework, local-only (no APNs backend)

**Important Decisions (Shape Architecture):**

6. WidgetKit as a separate app extension target sharing a SwiftData model
7. App Intents framework (not legacy SiriKit) for Siri capture
8. No third-party dependencies in MVP
9. Feature-folder project organization
10. `AppStorage` for lightweight user preferences (not SwiftData)

**Deferred Decisions (Post-MVP):**

- CoreSpotlight indexing (Growth feature)
- Focus Filters / WidgetConfigurationIntent (Growth feature)
- StoreKit 2 for IAP (Phase 3)
- Mac Catalyst or macOS target (Phase 3)
- CloudKit public database or shared zones for collaboration (Phase 3)

---

### Data Architecture

**Persistence Layer: SwiftData (iOS 17+)**

- `@Model` classes define the schema; SwiftData generates SQLite backing store
- `ModelContainer` configured at app launch with CloudKit mirroring enabled
- Single `ModelConfiguration` pointing to the app's iCloud container (`iCloud.com.<team>.todoapp`)

**Data Models:**

```swift
// TaskItem — primary domain entity
@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var isCompleted: Bool
    var dueDate: Date?
    var reminderDate: Date?
    var createdAt: Date
    var modifiedAt: Date
    var list: TaskList?            // optional relationship
    var sortOrder: Int             // for manual reordering
}

// TaskList — user-created collection
@Model
final class TaskList {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String           // list accent color
    var createdAt: Date
    var sortOrder: Int
    @Relationship(deleteRule: .cascade) var tasks: [TaskItem]
}
```

**Inbox Handling:** The "Inbox" is not a `TaskList` model row. It is a query filter (`task.list == nil`). This avoids deletion edge cases and matches the user's mental model.

**Conflict Resolution:**
- CloudKit last-write-wins for `title`, `dueDate`, `reminderDate`, `sortOrder`, `colorHex`
- `isCompleted` is additive: once `true`, never set back to `false` via sync (only explicit user action)
- `modifiedAt` timestamp drives last-write-wins

**Caching Strategy:** SwiftData's in-memory fetch cache is sufficient for this data volume (hundreds to low thousands of tasks). No additional caching layer.

**Migration Approach:** SwiftData lightweight migrations via `VersionedSchema` and `SchemaMigrationPlan` as the model evolves post-MVP. Document schema versions in `DataMigration/`.

---

### Authentication & Security

**Authentication: None (iCloud Account)**

There is no app-level authentication system. User identity is the iCloud account on the device — verified by CloudKit at the OS level. The app never handles credentials.

**Authorization:** All data is stored in the user's private CloudKit container — inaccessible to other users by design. No authorization logic needed in the app.

**Data Encryption:**
- Data at rest: encrypted by iOS file system encryption (NSFileProtectionComplete) via SwiftData default store attributes
- Data in transit: CloudKit uses TLS; no additional encryption needed

**API Security:** Not applicable — no custom backend or external API calls in MVP.

**Privacy:**
- `PrivacyInfo.xcprivacy` declares: no data collection, no tracking, no third-party SDK data access
- App Store privacy nutrition label: "Data Not Collected"

---

### API & Communication Patterns

No external REST/GraphQL API. Internal communication patterns:

**SwiftData → UI:** `@Query` macro in views for reactive data binding; `@Observable` ViewModels for derived/computed state not directly expressible as a `@Query`

**UI → Persistence:** ViewModels call repository methods; repository methods use an injected `ModelContext`

**App → WidgetKit:** `WidgetCenter.shared.reloadAllTimelines()` called after every task mutation (create, edit, complete, delete)

**App → Notifications:** `NotificationService` singleton owns all `UNUserNotificationCenter` operations; called by ViewModel after task save

**App → Siri / App Intents:** `AppIntentHandler` in the App Intents extension reads from a shared `ModelContainer` (same CloudKit container, same App Group)

**URL Scheme (Shortcuts):**
- Scheme: `todoapp://`
- Handled in `App.onOpenURL` modifier
- Supported actions: `todoapp://create`, `todoapp://open?taskID=<uuid>`

**Error Handling Standard:**
- CloudKit errors: silent retry with exponential back-off (handled by CloudKit SDK internally)
- SwiftData errors: logged to `os_log`; user shown generic "Something went wrong" banner (not raw error)
- Notification permission denied: graceful degradation — task still saves, no notification scheduled; UI surface shows permission prompt hint

---

### Frontend / UI Architecture

**Pattern: MVVM with `@Observable`**

```
View (SwiftUI)
  └── ViewModel (@Observable class, @MainActor)
        └── Repository (protocol + concrete impl)
              └── ModelContext (SwiftData, background actor)
```

**State Management:**
- `@Query` for list/task collections directly in views (SwiftData reactive queries)
- `@Observable` ViewModel for computed state: filtered counts, validation state, onboarding progress
- `@AppStorage` for lightweight preferences: `hasCompletedOnboarding: Bool`, `selectedListID: String?`
- No external state management library (Redux, TCA) — data volume does not justify it

**Component Architecture:**
- Feature folders, not type folders (see Project Structure)
- Views are passive — they render ViewModel state and forward user actions
- ViewModels are `@MainActor` isolated
- Repositories are not `@MainActor`; they receive a background `ModelContext`

**Navigation:**
- `NavigationStack` with `NavigationPath` for programmatic navigation
- No third-party navigation library
- Deep link routing handled in `AppCoordinator` (`@Observable` class owned by the App struct)

**Performance:**
- `LazyVStack` / `List` for task lists (avoid eager rendering)
- `@Query` predicate filtering happens in SwiftData (SQLite), not in Swift
- Avoid `.task` modifiers that trigger CloudKit fetches on every view appear; use repository-level caching

**Animations:**
- Task completion: checkmark scale + opacity animation wrapped in `withAnimation(.spring)`
- Conditioned on `@Environment(\.accessibilityReduceMotion)`

---

### Infrastructure & Deployment

**Distribution:** App Store only. No TestFlight-specific builds in MVP; ad-hoc distribution for internal testing.

**CI/CD:** Not required for solo MVP developer. Optional: Xcode Cloud free tier for automated builds on push to `main`.

**Environment Configuration:**
- No `.env` files — no backend, no API keys in MVP
- Bundle identifier and iCloud container identifier differ between Debug and Release schemes via Xcode build settings
- `DEBUG` flag for `os_log` verbosity control

**Monitoring & Logging:**
- `os_log` / `Logger` (OSLog framework) for structured logging — never logs task content (privacy)
- Xcode Organizer for crash reports post-launch
- No third-party crash reporting (Crashlytics, Sentry) — maintains "Data Not Collected" privacy label

**Scaling:** Not applicable for MVP. CloudKit scales automatically. No server-side scaling decisions.

**App Store Submission Checklist (architectural artifacts):**
- `PrivacyInfo.xcprivacy` in the app bundle root
- Entitlements: `com.apple.developer.icloud-services` (CloudKit), `com.apple.developer.siri`, push notifications (local)
- App Group shared between main target and App Intents extension: `group.com.<team>.todoapp`

---

## Implementation Patterns & Consistency Rules

### Critical Conflict Points Identified

8 areas where AI agents could make different choices without explicit rules.

---

### Naming Patterns

**Swift Type Naming (PascalCase):**
- Models: `TaskItem`, `TaskList` (not `Task` — conflicts with Swift concurrency `Task`)
- ViewModels: `TaskListViewModel`, `TaskDetailViewModel`
- Views: `TaskRowView`, `TaskDetailView`, `ListSidebarView`
- Repositories: `TaskRepository`, `ListRepository`
- Services: `NotificationService`, `WidgetService`
- Extensions: `TaskItem+Notifications.swift`, `Date+Formatting.swift`

**Swift Member Naming (camelCase):**
- Properties: `isCompleted`, `dueDate`, `reminderDate`, `sortOrder`
- Methods: `createTask(title:listID:)`, `completeTask(_:)`, `scheduleNotification(for:)`
- Async methods: `fetchTasks() async throws -> [TaskItem]`

**SwiftData Field Naming:**
- Use camelCase matching Swift properties; SwiftData generates the SQLite column names
- Foreign key relationships: named after the related type (`var list: TaskList?`, not `var taskListID`)

**File Naming:**
- Views: `TaskRowView.swift`, `TaskDetailView.swift`
- ViewModels: `TaskListViewModel.swift`
- Repositories: `TaskRepository.swift`
- Services: `NotificationService.swift`
- Models: `TaskItem.swift`, `TaskList.swift`
- Extensions: `TaskItem+Formatting.swift`
- Tests: mirror source path — `TaskRepositoryTests.swift` in `Tests/TaskTests/`

**URL Scheme Route Naming:** lowercase kebab-case: `todoapp://create-task`, `todoapp://open-task?id=<uuid>`

---

### Structure Patterns

**Feature-Folder Organization:**
All files for a feature live in one folder. Do NOT organize by type (all ViewModels together, all Views together).

```
Features/
  Tasks/           # task CRUD, completion, detail
  Lists/           # list creation, management, sidebar
  Notifications/   # notification scheduling, permission
  Widgets/         # widget timeline provider, entry views
  AppIntents/      # Siri intent handlers
  Onboarding/      # first-launch flow
  Settings/        # sync status, appearance
```

**Shared Code Placement:**
- `Core/Models/` — SwiftData model definitions (`TaskItem.swift`, `TaskList.swift`)
- `Core/Repositories/` — data access protocols and concrete implementations
- `Core/Services/` — cross-cutting services (NotificationService, WidgetService)
- `Core/Extensions/` — Swift/Foundation/SwiftUI extensions
- `Core/Utilities/` — non-service helpers (DateFormatter, ColorParser)

**Test Location:** Co-located test target, mirroring source folder structure:
```
TODOAppTests/
  Features/Tasks/TaskRepositoryTests.swift
  Features/Notifications/NotificationServiceTests.swift
  Core/Models/TaskItemTests.swift
```

---

### Format Patterns

**Date Handling:**
- Store all dates as `Date` (UTC) in SwiftData — never as strings
- Display formatting: use `Date.FormatStyle` (`.dateTime`, `.relative`) — never `DateFormatter` directly in views
- ISO 8601 representation (for URL scheme and App Intents): `date.ISO8601Format()`

**UUID Handling:**
- All model IDs are `UUID` typed — never `String` representations stored in SwiftData
- URL scheme passes UUIDs as `uuidString`: `todoapp://open-task?id=550E8400-E29B-41D4-A716-446655440000`

**Boolean Naming:**
- All Boolean properties prefixed with `is` or `has`: `isCompleted`, `hasCompletedOnboarding`

**Optional Handling:**
- Never force-unwrap (`!`) outside of test code
- `guard let` for early exits in ViewModels; `if let` for inline optionals in views

**Color Storage:**
- `TaskList.colorHex` stored as a 6-digit hex string (e.g., `"FF6B6B"`) — never as `Color` directly (not Codable in SwiftData)
- Conversion via `Color(hex:)` extension in `Core/Extensions/Color+Hex.swift`

---

### Communication Patterns

**ViewModel → Repository (async/await):**
```swift
// Always async, always throws, always called from @MainActor ViewModel
func createTask(title: String, listID: UUID?) async throws {
    try await repository.createTask(title: title, listID: listID)
    WidgetService.shared.reloadTimelines()
    NotificationService.shared.scheduleIfNeeded(...)
}
```

**Post-Mutation Side Effects (mandatory after every task state change):**
1. `WidgetCenter.shared.reloadAllTimelines()` — keep widget current
2. `NotificationService` reschedule/cancel as appropriate

This is NOT optional. Every create/edit/complete/delete path MUST trigger both side effects.

**Repository Protocol Pattern:**
```swift
protocol TaskRepositoryProtocol {
    func fetchTasks(in list: TaskList?) async throws -> [TaskItem]
    func createTask(title: String, listID: UUID?) async throws -> TaskItem
    func updateTask(_ task: TaskItem) async throws
    func deleteTask(_ task: TaskItem) async throws
    func completeTask(_ task: TaskItem) async throws
}
```

**SwiftData ModelContext Actor Isolation:**
- Main `ModelContext` — injected via SwiftUI `.modelContainer()` modifier; used by `@Query` macros
- Background `ModelContext` — created by `ModelContainer.newContext()` for writes from App Intents / Notification actions; never hold a strong reference across suspension points

**Event/Notification Naming (NotificationCenter, not UNUserNotificationCenter):**
- Swift `Notification.Name` extension constants: `Notification.Name.taskCompleted`, `Notification.Name.listDeleted`
- Post format: `NotificationCenter.default.post(name: .taskCompleted, object: taskID)`

---

### Process Patterns

**Error Handling:**
```swift
// ViewModel pattern — wrap throws, show user-facing banner
func handleAction() {
    Task { @MainActor in
        do {
            try await repository.someAction()
        } catch {
            Logger.app.error("Action failed: \(error)")
            self.errorMessage = "Something went wrong. Please try again."
        }
    }
}
```
- Never expose raw `Error` or `LocalizedError` descriptions to the user
- `Logger` calls MUST NOT include task titles or user content (privacy)

**Loading States:**
- `isLoading: Bool` property on ViewModel for full-screen loads (first fetch only)
- Individual operation in-flight state via `Task` handle stored on ViewModel for cancellation
- No global loading state — each feature manages its own

**Navigation from Notifications:**
- `UNNotificationResponse` handled in `AppDelegate.userNotificationCenter(_:didReceive:)`
- Routes via `AppCoordinator.navigateTo(taskID:)`

**Widget Timeline Provider:**
- `TimelineProvider.getTimeline(in:completion:)` must be synchronous in its completion call — fetch data before calling completion
- Provide entries for the next 24 hours minimum (NFR23)
- Request refresh policy: `.after(Date().addingTimeInterval(15 * 60))` — 15-minute max staleness (NFR4)

**Enforcement Guidelines:**

All AI agents MUST:
- Annotate every `@Observable` ViewModel class with `@MainActor`
- Call `WidgetService.shared.reloadTimelines()` after every task mutation
- Never log user-generated content (task titles, list names) via `Logger`
- Use `@Query` for collection display in views — never manual `fetch()` in `onAppear`
- Respect the `Notification.Name` constants — never use raw string notification names

---

## Project Structure & Boundaries

### Complete Project Directory Structure

```
TODOApp/                                    # Xcode project root
├── TODOApp.xcodeproj/
│   ├── project.pbxproj
│   └── xcshareddata/xcschemes/
│       ├── TODOApp.xcscheme
│       └── TODOAppTests.xcscheme
│
├── TODOApp/                                # Main app target
│   ├── TODOAppApp.swift                    # @main entry point, ModelContainer setup
│   ├── AppCoordinator.swift                # Navigation routing, deep link handling
│   ├── Info.plist
│   ├── TODOApp.entitlements                # iCloud, Siri, Push
│   ├── PrivacyInfo.xcprivacy               # "Data Not Collected" manifest
│   │
│   ├── Core/
│   │   ├── Models/
│   │   │   ├── TaskItem.swift              # @Model: id, title, isCompleted, dueDate, ...
│   │   │   ├── TaskList.swift              # @Model: id, name, colorHex, tasks relationship
│   │   │   └── DataMigration/
│   │   │       └── SchemaV1.swift          # VersionedSchema for future migrations
│   │   ├── Repositories/
│   │   │   ├── TaskRepositoryProtocol.swift
│   │   │   ├── TaskRepository.swift        # SwiftData-backed implementation
│   │   │   ├── ListRepositoryProtocol.swift
│   │   │   └── ListRepository.swift
│   │   ├── Services/
│   │   │   ├── NotificationService.swift   # UNUserNotificationCenter wrapper
│   │   │   └── WidgetService.swift         # WidgetCenter.reloadAllTimelines()
│   │   ├── Extensions/
│   │   │   ├── Color+Hex.swift             # Color(hex:) initializer
│   │   │   ├── Date+Relative.swift         # Relative display formatting
│   │   │   └── TaskItem+Notifications.swift # scheduleNotification helpers
│   │   └── Utilities/
│   │       └── Logger+App.swift            # os_log Logger category constants
│   │
│   ├── Features/
│   │   ├── Tasks/
│   │   │   ├── TaskListView.swift          # FR6, FR9: task list, overdue distinction
│   │   │   ├── TaskListViewModel.swift     # @MainActor, @Observable
│   │   │   ├── TaskRowView.swift           # FR4, FR5: swipe-to-complete, row UI
│   │   │   ├── TaskDetailView.swift        # FR2, FR7, FR8: edit, due date, reminder
│   │   │   ├── TaskDetailViewModel.swift
│   │   │   ├── AddTaskView.swift           # FR1: quick-add sheet
│   │   │   └── TaskCompletionAnimation.swift # NFR19: Reduce Motion aware
│   │   ├── Lists/
│   │   │   ├── ListSidebarView.swift       # FR14, FR15: Inbox + custom lists
│   │   │   ├── ListSidebarViewModel.swift
│   │   │   ├── AddListView.swift           # FR10: create list sheet
│   │   │   ├── EditListView.swift          # FR11: rename list
│   │   │   └── ListColorPicker.swift       # color selection component
│   │   ├── Notifications/
│   │   │   ├── NotificationPermissionView.swift  # FR36: permission prompt
│   │   │   └── NotificationPermissionViewModel.swift
│   │   ├── Onboarding/
│   │   │   ├── OnboardingView.swift        # FR34: no-account first launch
│   │   │   ├── OnboardingViewModel.swift
│   │   │   └── WidgetOnboardingNudgeView.swift  # FR35: widget suggestion
│   │   └── Settings/
│   │       ├── SettingsView.swift          # FR43: iCloud sync status
│   │       └── SettingsViewModel.swift
│   │
│   └── Resources/
│       ├── Assets.xcassets/
│       │   ├── AppIcon.appiconset/
│       │   └── Colors/                     # semantic color assets
│       └── Localizable.xcstrings           # localization (en base)
│
├── TODOAppWidgetExtension/                 # WidgetKit extension target
│   ├── TODOAppWidgetBundle.swift           # @main for widget extension
│   ├── TaskWidget.swift                    # FR21–FR25: small + medium widget
│   ├── TaskWidgetProvider.swift            # TimelineProvider implementation
│   ├── TaskWidgetEntryView.swift           # widget UI (small + medium)
│   └── TODOAppWidgetExtension.entitlements # shared App Group, iCloud
│
├── TODOAppIntents/                         # App Intents extension target
│   ├── CreateTaskIntent.swift              # FR26–FR28: Siri task capture
│   ├── OpenTaskIntent.swift                # URL scheme bridging
│   └── TODOAppIntents.entitlements         # shared App Group, Siri
│
├── TODOAppTests/                           # XCTest + Swift Testing unit tests
│   ├── Features/
│   │   ├── Tasks/
│   │   │   ├── TaskRepositoryTests.swift
│   │   │   └── TaskListViewModelTests.swift
│   │   ├── Lists/
│   │   │   └── ListRepositoryTests.swift
│   │   └── Notifications/
│   │       └── NotificationServiceTests.swift
│   └── Core/
│       ├── Models/
│       │   └── TaskItemTests.swift
│       └── Extensions/
│           └── ColorHexTests.swift
│
└── TODOAppUITests/                         # XCUITest UI automation
    ├── OnboardingUITests.swift
    ├── TaskCaptureUITests.swift
    └── TaskCompletionUITests.swift
```

---

### Architectural Boundaries

**App Target Boundary:**
- Owns the main `ModelContainer` (configured with CloudKit mirroring)
- Provides `ModelContext` to all views via `.modelContainer()` environment modifier
- Handles `UNUserNotificationCenter` delegate
- Handles URL scheme `onOpenURL`

**WidgetKit Extension Boundary:**
- Read-only access to shared SwiftData store via App Group (`group.com.<team>.todoapp`)
- Creates its own `ModelContainer` with the same container identifier
- Does NOT write to the store — widget is display-only
- Communicates state needs back to the app via widget tap (URL scheme deep link)

**App Intents Extension Boundary:**
- Read/write access to shared SwiftData store via App Group
- Creates tasks using a background `ModelContext` from shared `ModelContainer`
- Must post `WidgetCenter.shared.reloadAllTimelines()` after creating a task
- No UI — responds to Siri with a `IntentResultValue` confirmation string

**Notification Boundary:**
- `NotificationService` is the single point of access for all `UNUserNotificationCenter` operations
- Views and ViewModels NEVER access `UNUserNotificationCenter` directly
- `NotificationService` manages the notification identifier scheme: `"task-\(task.id.uuidString)"`

---

### Requirements to Structure Mapping

**FR1–FR9 (Task Management):**
- `Features/Tasks/` — all task CRUD views and view models
- `Core/Repositories/TaskRepository.swift` — persistence layer
- `Core/Models/TaskItem.swift` — data model

**FR10–FR16 (List Organization):**
- `Features/Lists/` — list management views and view models
- `Core/Repositories/ListRepository.swift`
- `Core/Models/TaskList.swift`

**FR17–FR20 (Notifications):**
- `Features/Notifications/` — permission UI
- `Core/Services/NotificationService.swift` — all scheduling logic

**FR21–FR25 (Widget):**
- `TODOAppWidgetExtension/` — entire widget target

**FR26–FR28 (Siri):**
- `TODOAppIntents/` — entire App Intents target

**FR29–FR33 (Sync):**
- `TODOAppApp.swift` — `ModelContainer` CloudKit configuration
- `Core/Models/DataMigration/` — schema versioning

**FR34–FR36 (Onboarding):**
- `Features/Onboarding/` — onboarding views and view models
- `@AppStorage("hasCompletedOnboarding")` flag

**FR39 (URL scheme):**
- `AppCoordinator.swift` — `onOpenURL` handler

**FR40–FR43 (Appearance/Settings):**
- `Features/Settings/` — settings view and view model
- SwiftUI `.preferredColorScheme` environment (system default by FR42)

---

### Integration Points

**Internal Communication:**

```
App Launch
  └── TODOAppApp configures ModelContainer (CloudKit)
        └── ModelContext injected into NavigationStack root
              └── Views use @Query for reactive task/list display
                    └── User actions → ViewModel → Repository → ModelContext
                          └── Side effects: WidgetService + NotificationService
```

**External Integrations:**

| Integration | Entry Point | Scope |
|---|---|---|
| CloudKit (private DB) | `ModelContainer` init in `TODOAppApp` | All task + list data sync |
| WidgetKit | `TODOAppWidgetBundle` in widget extension | Read-only display + tap URL |
| App Intents / Siri | `TODOAppIntents` extension | Task creation via voice |
| UserNotifications | `NotificationService` | Local reminders only |
| URL Scheme | `AppCoordinator.onOpenURL` | Shortcuts automation, widget taps |

**Data Flow:**

```
User creates task (app)
  → TaskListViewModel.createTask()
  → TaskRepository.createTask() [background ModelContext]
  → ModelContext.save() → SwiftData SQLite
  → CloudKit sync (automatic, background)
  → WidgetService.reloadTimelines() → WidgetKit extension re-fetches
  → NotificationService.schedule() → UNUserNotificationCenter

User completes task (notification)
  → UNNotificationResponse with "Mark Done" action
  → AppDelegate handler
  → TaskRepository.completeTask() [background ModelContext]
  → WidgetService.reloadTimelines()
  → NotificationService.cancel(for: task)
```

---

## Architecture Validation Results

### Coherence Validation

**Decision Compatibility:**
All technology choices are from Apple's native stack and are designed to work together. SwiftData + CloudKit integration is a first-party Apple feature. App Intents and WidgetKit both consume SwiftData via shared App Group. Swift 6 strict concurrency is enforced uniformly across all targets. No external dependency conflicts exist (no external dependencies in MVP).

**Pattern Consistency:**
The MVVM + `@Observable` + `@Query` pattern is consistent across all feature folders. Naming conventions are uniform (PascalCase types, camelCase members, feature-folder organization). Error handling pattern (ViewModel catches, logs privately, shows generic message) is applied consistently. The side-effect rule (WidgetService + NotificationService after every mutation) is explicitly documented and enforceable via code review.

**Structure Alignment:**
The project structure maps 1:1 to the feature areas in the PRD. Extension targets are properly separated. Shared code lives in `Core/`. The structure supports Xcode's target membership model and App Group entitlements.

---

### Requirements Coverage Validation

**Functional Requirements Coverage:**

| FR Range | Coverage | Notes |
|---|---|---|
| FR1–FR9 (Task CRUD) | Full | SwiftData model + TaskRepository + TaskListViewModel |
| FR10–FR16 (Lists) | Full | TaskList model + ListRepository + ListSidebarViewModel |
| FR17–FR20 (Notifications) | Full | NotificationService + AppDelegate delegate |
| FR21–FR25 (Widget) | Full | WidgetKit extension target + TimelineProvider |
| FR26–FR28 (Siri) | Full | App Intents extension + CreateTaskIntent |
| FR29–FR33 (Sync) | Full | CloudKit-backed ModelContainer; offline = local SQLite first |
| FR34–FR36 (Onboarding) | Full | OnboardingView + AppStorage flag |
| FR37–FR38 (Growth) | Deferred | CoreSpotlight + Focus Filters post-MVP |
| FR39 (URL scheme) | Full | AppCoordinator.onOpenURL |
| FR40–FR43 (Appearance) | Full | SwiftUI environment + SettingsView |

**Non-Functional Requirements Coverage:**

| NFR | Coverage |
|---|---|
| NFR1 (<400ms launch) | ModelContainer init is async; no blocking sync on startup |
| NFR2 (100ms UI) | @Query is reactive; all writes on background ModelContext |
| NFR3 (3s sync) | CloudKit private DB; no custom batching needed |
| NFR4 (15min widget) | Widget reload policy set to 15-minute interval |
| NFR6 (zero data loss) | SwiftData local-first; CloudKit is additive mirror |
| NFR7 (60s offline sync) | CloudKit automatic push sync on reconnect |
| NFR8 (no corrupt sync) | Last-write-wins + additive completion state |
| NFR9 (60s notification) | UNUserNotificationCenter local scheduling |
| NFR11–NFR12 (privacy) | Private CloudKit container; no third-party SDKs |
| NFR13 (PrivacyInfo) | PrivacyInfo.xcprivacy in project root |
| NFR14–NFR15 (no telemetry) | No external SDKs; os_log only |
| NFR16–NFR20 (accessibility) | VoiceOver labels required in all views; Dynamic Type; Reduce Motion check |
| NFR21–NFR22 (Siri speed) | App Intents respond synchronously; no network dependency |
| NFR23 (widget 24h entries) | TimelineProvider generates 24h of entries per refresh |
| NFR24 (CloudKit off main) | All ModelContext operations on background actor |
| NFR25 (notification persistence) | UNUserNotificationCenter survives backgrounding by design |

---

### Implementation Readiness Validation

**Decision Completeness:** All critical decisions are documented with technology names and versions (Swift 6, iOS 17+, Xcode 16, SwiftData, CloudKit private DB, WidgetKit, App Intents). No ambiguous "TBD" decisions remain for MVP scope.

**Structure Completeness:** Complete Xcode project tree defined including all source files, 3 targets (main app, widget extension, App Intents extension), test target, and UI test target. Every FR maps to a specific file.

**Pattern Completeness:** All 8 identified conflict points are addressed with explicit rules and code examples. The critical post-mutation side-effect rule is called out as mandatory with enforcement guidance.

---

### Gap Analysis Results

**Critical Gaps:** None — all MVP-scope requirements have architectural coverage.

**Important (document before coding):**
- App Group identifier (`group.com.<team>.todoapp`) must be established before widget and App Intents targets can share the ModelContainer. This is a Day 1 Xcode configuration step.
- `@AppStorage` keys should be defined as string constants in a single file (`Core/Utilities/AppStorageKeys.swift`) to avoid typo conflicts across agents.

**Nice-to-Have:**
- A `MockTaskRepository` conforming to `TaskRepositoryProtocol` for SwiftUI Previews and unit tests would improve development experience.
- `AppConstants.swift` for bundle identifier, iCloud container identifier, and App Group identifier — centralizes the values that differ between Debug and Release.

---

### Architecture Completeness Checklist

**Requirements Analysis**
- [x] Project context thoroughly analyzed (PRD fully read; 43 FRs, 25 NFRs mapped)
- [x] Scale and complexity assessed (Low complexity; single-user, no backend)
- [x] Technical constraints identified (iOS 17+, Swift 6, no third-party SDKs)
- [x] Cross-cutting concerns mapped (concurrency, widget invalidation, notification lifecycle, accessibility)

**Architectural Decisions**
- [x] Critical decisions documented (SwiftData, CloudKit, MVVM, App Intents, WidgetKit)
- [x] Technology stack fully specified (Swift 6, iOS 17+, Xcode 16, SwiftData, CloudKit private DB)
- [x] Integration patterns defined (shared App Group, ModelContainer access per target)
- [x] Performance considerations addressed (NFR1–NFR5 all addressed architecturally)

**Implementation Patterns**
- [x] Naming conventions established (types, files, SwiftData fields, URL routes)
- [x] Structure patterns defined (feature-folder, Core separation, extension targets)
- [x] Communication patterns specified (ViewModel→Repository, post-mutation side effects)
- [x] Process patterns documented (error handling, loading states, widget timeline)

**Project Structure**
- [x] Complete directory structure defined (all files named and located)
- [x] Component boundaries established (3 targets + shared Core)
- [x] Integration points mapped (CloudKit, WidgetKit, App Intents, Notifications, URL scheme)
- [x] Requirements to structure mapping complete (every FR range mapped to file paths)

---

### Architecture Readiness Assessment

**Overall Status: READY FOR IMPLEMENTATION**

**Confidence Level:** High — all MVP requirements have clear architectural coverage; technology stack is mature and well-documented; no custom backend to design; patterns are explicit with code examples.

**Key Strengths:**
- iOS-only constraint eliminated all cross-platform complexity — 100% of architectural decisions use Apple-first APIs
- SwiftData + CloudKit combination reduces data layer complexity to near-zero vs. a custom backend
- Feature-folder structure maps directly to PRD feature areas; new AI agents can navigate to any feature with one lookup
- Explicit post-mutation side-effect rule prevents the most common source of widget/notification staleness bugs
- No third-party dependencies means no version drift, no supply chain risk, and a clean "Data Not Collected" privacy story

**Areas for Future Enhancement (post-MVP):**
- CoreSpotlight indexing (Growth) — `CSSearchableItemAttributeSet` for task search
- Focus Filters (Growth) — `WidgetConfigurationIntent` + `FocusFilterIntent` for list-scoped widget
- `SchemaMigrationPlan` implementation as SwiftData schema evolves
- Mac Catalyst / SwiftUI multiplatform target (Phase 3) — would require revisiting App Group and CloudKit container naming

---

### Implementation Handoff

**AI Agent Guidelines:**
- Follow all architectural decisions exactly as documented — do not introduce UIKit, Combine, or Core Data
- Use `@Observable` + `@MainActor` for all ViewModels — do not use `ObservableObject` + `@Published`
- Use `@Query` for reactive list display in views — do not call `try modelContext.fetch()` in `onAppear`
- All CloudKit / SwiftData writes go through `TaskRepository` or `ListRepository` — never directly in views
- Always call `WidgetService.shared.reloadTimelines()` and update `NotificationService` after every task mutation
- Never log task titles or list names — use `os_log` with privacy-sensitive logging (`%{private}@`)
- Refer to this document for all architectural questions before making decisions

**First Implementation Priority:**
```bash
# 1. Create Xcode project from template (see Starter Template section)
# 2. Configure App Group: group.com.<team>.todoapp
# 3. Add iCloud + CloudKit capability to main target
# 4. Implement Core/Models/TaskItem.swift + TaskList.swift
# 5. Implement Core/Repositories/TaskRepository.swift
# 6. Wire ModelContainer in TODOAppApp.swift with CloudKit options
# 7. Build Features/Tasks/ (list + detail + add views)
# 8. Build Features/Lists/ (sidebar + add/edit)
# 9. Implement NotificationService + permission flow
# 10. Implement WidgetKit extension target
# 11. Implement App Intents extension (Siri)
# 12. Implement Onboarding flow
# 13. Polish, accessibility audit, TestFlight, App Store submission
```
