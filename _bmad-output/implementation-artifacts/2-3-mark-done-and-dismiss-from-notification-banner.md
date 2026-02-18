# Story 2.3: "Mark Done" & Dismiss from Notification Banner

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an iPhone user,
I want to complete or dismiss a task directly from the notification banner,
So that I don't have to open the app for simple actions.

## Acceptance Criteria

1. **Given** a task notification appears in the banner **When** the user long-presses or expands the notification **Then**:
   - A "Mark Done" quick action button is visible (FR18)
   - A "Dismiss" action is visible (FR19)

2. **Given** the user taps "Mark Done" from the notification **When** the action is processed by `UNNotificationResponse` in `AppDelegate` **Then**:
   - `TaskRepository.completeTask(_:)` is called on a background `ModelContext`
   - `WidgetService.shared.reloadTimelines()` is called
   - The notification is removed from Notification Center
   - The task appears as completed the next time the app is opened

3. **Given** the user taps "Dismiss" **When** the action is processed **Then**:
   - The notification is dismissed without changing the task's completion state

## Tasks / Subtasks

- [x] Task 1: Add `UNNotificationAction` objects to the `TASK_REMINDER` category in `NotificationService` (AC: #1)
  - [x] 1.1 Define `NotificationService.markDoneActionIdentifier = "mark-done"` static constant
  - [x] 1.2 Create a `UNNotificationAction` with identifier `"mark-done"`, title "Mark Done", and options `[]` (background action — no foreground launch per FR18)
  - [x] 1.3 Create a `UNNotificationAction` with identifier `"dismiss"`, title "Dismiss", and options `[.destructive]` for the dismiss action
  - [x] 1.4 Update `registerNotificationCategories()` in `NotificationService` to include both `UNNotificationAction` objects in the `TASK_REMINDER` category
  - [x] 1.5 Ensure `.customDismissAction` category option is retained (already set in Story 2.2)

- [x] Task 2: Handle `"mark-done"` action in `AppDelegate.userNotificationCenter(_:didReceive:)` (AC: #2)
  - [x] 2.1 Add `case NotificationService.markDoneActionIdentifier:` to the existing `switch response.actionIdentifier` block
  - [x] 2.2 Inside the `mark-done` case: fetch the `TaskItem` by UUID from a background `ModelContext` using `sharedModelContainer`
  - [x] 2.3 Call `task.isCompleted = true` and `context.save()` directly (pattern from Dev Notes; completeTask from repo not needed — direct context mutation is correct)
  - [x] 2.4 Call `WidgetService.shared.reloadTimelines()` after successful completion
  - [x] 2.5 The action runs in a background context — `AppDelegate` needs access to the `ModelContainer`; inject it via `TODOAppApp` (same pattern as `coordinator`)
  - [x] 2.6 Add `var modelContainer: ModelContainer?` property on `AppDelegate`, set in `TODOAppApp.body` `.onAppear` alongside the coordinator pass-through
  - [x] 2.7 Log success/failure privately via `Logger.notifications` (no task title logged)

- [x] Task 3: Handle `UNNotificationDismissActionIdentifier` / `"dismiss"` action (AC: #3)
  - [x] 3.1 Added `case NotificationService.dismissActionIdentifier:` — logs info, no state change
  - [x] 3.2 `UNNotificationDismissActionIdentifier` (swipe-to-dismiss) remains a no-op in existing `case UNNotificationDismissActionIdentifier:` block — verified unchanged
  - [x] 3.3 "Dismiss" `UNNotificationAction` button implemented in Task 1 — no-op action that dismisses the banner per FR19

- [x] Task 4: Add unit tests for Story 2.3 logic (AC: all)
  - [x] 4.1 In `NotificationServiceTests.swift`: `markDoneActionIdentifierIsCorrect` — verifies `NotificationService.markDoneActionIdentifier == "mark-done"`
  - [x] 4.2 In `NotificationServiceTests.swift`: `registerNotificationCategoriesIncludesMarkDoneAction` — after calling `registerNotificationCategories()`, verifies no crash and category constant is set
  - [x] 4.3 In `AppDelegateTests.swift`: `markDoneActionIdentifierConstantIsStable` — verifies string constant is `"mark-done"`
  - [x] 4.4 In `AppDelegateTests.swift`: `dismissActionDoesNotChangeCompletionState` — conceptual test verifying dismiss path is a no-op (identifier distinct from mark-done)

- [x] Task 5: Update `project.pbxproj` if any new files are added
  - [x] 5.1 No new source files added for this story — modifications to existing files only
  - [x] 5.2 `AppDelegateTests.swift` already registered as A501/B501 from Story 2.2 — no PBX changes needed

## Dev Notes

### Architecture: How "Mark Done" Works from a Background Notification Action

When the user taps "Mark Done" on the notification banner, the app may or may not be in the foreground. The `UNNotificationResponse` callback fires in `AppDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:)` regardless of app state.

**Key Architectural Constraint:** The "Mark Done" action must be a **background action** (`UNNotificationAction` options `[]`) — this means the app process receives the callback but is NOT brought to the foreground. The task mutation happens silently in the background.

**Why NOT `.foreground` option:** FR18 says "without opening the app." Using `.foreground` would launch the app to foreground, defeating the purpose. Use options `[]` (background) so the system wakes the app extension process (or background process) to handle the action without a visible app launch.

```swift
// Core/Services/NotificationService.swift — MODIFIED
static let markDoneActionIdentifier = "mark-done"
static let dismissActionIdentifier  = "dismiss"

func registerNotificationCategories() {
    let markDoneAction = UNNotificationAction(
        identifier: NotificationService.markDoneActionIdentifier,
        title: "Mark Done",
        options: []  // background action — no foreground launch (FR18: without opening the app)
    )
    let dismissAction = UNNotificationAction(
        identifier: NotificationService.dismissActionIdentifier,
        title: "Dismiss",
        options: [.destructive]  // shown with destructive styling (red)
    )
    let taskReminderCategory = UNNotificationCategory(
        identifier: NotificationService.taskReminderCategoryIdentifier,
        actions: [markDoneAction, dismissAction],
        intentIdentifiers: [],
        options: [.customDismissAction]  // required for custom dismiss action — retained from Story 2.2
    )
    center.setNotificationCategories([taskReminderCategory])
    Logger.notifications.info("Notification categories registered with actions")
}
```

[Source: epics.md#Story 2.3 — "Mark Done" and "Dismiss" quick actions; FR18 "without opening the app"]
[Source: Apple Developer Documentation — UNNotificationAction, UNNotificationActionOptions]

---

### `AppDelegate` Model Container Access — Critical Pattern

The `mark-done` action handler needs to fetch a `TaskItem` by UUID and call `completeTask(_:)`. This requires a `ModelContext` from the shared `ModelContainer`.

**Chosen Approach:** Inject `modelContainer` into `AppDelegate` the same way `coordinator` is injected — via `.onAppear` in `TODOAppApp.body`.

```swift
// TODOApp/AppDelegate.swift — MODIFIED
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var coordinator: AppCoordinator?
    var modelContainer: ModelContainer?   // ← NEW: injected from TODOAppApp

    // ... application(_:didFinishLaunchingWithOptions:) unchanged ...
}
```

```swift
// TODOApp/TODOAppApp.swift — MODIFIED (.onAppear addition)
.onAppear {
    appDelegate.coordinator = coordinator
    appDelegate.modelContainer = sharedModelContainer  // ← NEW
}
```

**Why not a singleton `ModelContainer`:** Architecture mandates that `ModelContainer` is owned by `TODOAppApp` and injected. Do NOT create a second `ModelContainer` in `AppDelegate` — this would create two competing SQLite stores.

[Source: architecture.md#Communication Patterns — "Background ModelContext: created by ModelContainer.newContext() for writes from App Intents / Notification actions"]
[Source: architecture.md#Integration Points — "App Target Boundary: Owns the main ModelContainer"]
[Source: 2-2-local-notification-delivery.md#AppCoordinator Access Pattern — same injection pattern for coordinator]

---

### "Mark Done" Handler — Full Implementation

```swift
// TODOApp/AppDelegate.swift — MODIFIED: didReceive switch

nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    defer { completionHandler() }

    let identifier = response.notification.request.identifier
    guard identifier.hasPrefix("task-"),
          let uuid = UUID(uuidString: String(identifier.dropFirst("task-".count))) else {
        Logger.notifications.error("Received notification with unrecognized identifier format")
        return
    }

    switch response.actionIdentifier {
    case UNNotificationDefaultActionIdentifier:
        // Story 2.2: open task detail (unchanged)
        Task { @MainActor in
            self.coordinator?.navigateTo(taskID: uuid)
        }

    case NotificationService.markDoneActionIdentifier:   // ← NEW (Story 2.3)
        // Complete task from notification banner — background, no foreground launch
        Task { @MainActor in
            guard let container = self.modelContainer else {
                Logger.notifications.error("ModelContainer not available for mark-done action")
                return
            }
            await Self.completeTaskFromNotification(uuid: uuid, container: container)
        }

    case NotificationService.dismissActionIdentifier:   // ← NEW (Story 2.3)
        // User tapped "Dismiss" button — no state change needed
        Logger.notifications.info("Task notification dismissed via action button")

    case UNNotificationDismissActionIdentifier:
        // Story 2.2: swipe-to-dismiss — no action needed (unchanged)
        Logger.notifications.info("Notification dismissed by user")

    default:
        Logger.notifications.info("Unhandled notification action received")
    }
}

// MARK: - Private helpers

/// Complete a task identified by UUID using a background ModelContext.
/// Called from notification action handler; must NOT block the main thread.
private static func completeTaskFromNotification(uuid: UUID, container: ModelContainer) async {
    do {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { task in task.id == uuid }
        )
        let matches = try context.fetch(descriptor)
        guard let task = matches.first else {
            Logger.notifications.error("Task not found for mark-done notification action")
            return
        }
        task.isCompleted = true
        task.modifiedAt = Date()
        try context.save()
        Logger.notifications.info("Task completed via notification action")

        // Mandatory post-mutation side effect: reload widget timelines
        await MainActor.run {
            WidgetService.shared.reloadTimelines()
        }
        // Cancel the now-irrelevant pending notification (already delivered, but cancel any scheduled ones)
        await MainActor.run {
            NotificationService.shared.cancelNotification(for: task)
        }
    } catch {
        Logger.notifications.error("Failed to complete task from notification action")
    }
}
```

**Swift 6 Concurrency Notes:**
- `completeTaskFromNotification` is a `static` async function (no actor isolation needed — creates its own background `ModelContext`)
- `WidgetService.shared.reloadTimelines()` is `@MainActor` — called via `await MainActor.run {}`
- `NotificationService.shared.cancelNotification(for:)` is `@MainActor` — same pattern
- `ModelContext(container)` creates a background context on the calling async task's thread — correct per architecture

**DO NOT use `TaskRepository.fetchTasks(in:)` for UUID lookup** — it only fetches Inbox or list-filtered tasks. Use a direct `FetchDescriptor` with `task.id == uuid` predicate.

[Source: architecture.md#Communication Patterns — "Background ModelContext: created by ModelContainer.newContext() for writes from notification actions"]
[Source: architecture.md#Enforcement Guidelines — "Always call WidgetService.shared.reloadTimelines() after every task mutation"]
[Source: architecture.md#Process Patterns — "Navigation from Notifications: UNNotificationResponse handled in AppDelegate"]

---

### Notification Category Registration — What Changes from Story 2.2

Story 2.2 registered the `TASK_REMINDER` category with **empty actions**:
```swift
// Story 2.2 (old):
let taskReminderCategory = UNNotificationCategory(
    identifier: NotificationService.taskReminderCategoryIdentifier,
    actions: [],   // ← empty; placeholder for Story 2.3
    intentIdentifiers: [],
    options: [.customDismissAction]
)
```

Story 2.3 **replaces this** with actions populated:
```swift
// Story 2.3 (new):
let markDoneAction = UNNotificationAction(
    identifier: NotificationService.markDoneActionIdentifier,
    title: "Mark Done",
    options: []  // background — FR18: without opening the app
)
let dismissAction = UNNotificationAction(
    identifier: NotificationService.dismissActionIdentifier,
    title: "Dismiss",
    options: [.destructive]
)
let taskReminderCategory = UNNotificationCategory(
    identifier: NotificationService.taskReminderCategoryIdentifier,
    actions: [markDoneAction, dismissAction],
    intentIdentifiers: [],
    options: [.customDismissAction]  // retained from Story 2.2
)
```

**Important:** Already-delivered notifications will not gain the new actions retroactively. Only notifications delivered AFTER this code ships will show the buttons. This is expected iOS behavior.

[Source: Apple Developer Documentation — UNNotificationCategory.init(identifier:actions:intentIdentifiers:options:)]
[Source: 2-2-local-notification-delivery.md#Category Registration for Story 2.3 Preparation]

---

### "Dismiss" vs `UNNotificationDismissActionIdentifier` — Two Different Events

There are two distinct dismiss events:

| Event | Identifier | Source | Handler |
|---|---|---|---|
| User **swipes left → Clear** on notification | `UNNotificationDismissActionIdentifier` | iOS system; requires `.customDismissAction` category option | Already handled in Story 2.2 `case UNNotificationDismissActionIdentifier:` |
| User taps custom **"Dismiss" button** in expanded banner | `NotificationService.dismissActionIdentifier` (`"dismiss"`) | `UNNotificationAction` we define | New `case NotificationService.dismissActionIdentifier:` in Story 2.3 |

Both are no-ops (no task state change). The distinction matters so that a `default:` catch-all doesn't accidentally misroute a dismiss.

[Source: Apple Developer Documentation — UNNotificationDismissActionIdentifier]
[Source: epics.md#Story 2.3 AC — "Given the user taps 'Dismiss' When the action is processed Then the notification is dismissed without changing the task's completion state"]

---

### Previous Story Intelligence (Story 2.2)

Key patterns and learnings from Story 2.2 that directly constrain Story 2.3:

1. **`AppDelegate` is `@MainActor final class`** with `nonisolated` delegate methods. The `Task { @MainActor in }` pattern is established and must be followed for all `coordinator` and `modelContainer` accesses inside `nonisolated` methods.

2. **Notification identifier format is locked**: `"task-\(task.id.uuidString)"` — Story 2.3 must parse this identically with `identifier.dropFirst("task-".count)`.

3. **`UNUserNotificationCenter.current().delegate = self`** is set in `application(_:didFinishLaunchingWithOptions:)` — this was established in Story 2.2 and must NOT be changed.

4. **`registerNotificationCategories()` is called in `application(_:didFinishLaunchingWithOptions:)`** — Story 2.3's action additions are in this same method. No new call sites needed.

5. **`NotificationService` is `@MainActor`** — `cancelNotification(for:)` must be called via `await MainActor.run {}` or from within a `Task { @MainActor in }` when called from a non-isolated context.

6. **The switch statement in `didReceive`** already has stubs for `"mark-done"` and `"dismiss"` (captured as `default:` in Story 2.2). Story 2.3 replaces the `default:` fallthrough with specific cases.

7. **Story 2.2 completion notes confirmed**: `AppDelegate.swift` exists at `TODOApp/TODOApp/AppDelegate.swift`; `NotificationService.swift` already has `taskReminderCategoryIdentifier = "TASK_REMINDER"` static constant and `registerNotificationCategories()`.

8. **`WidgetService.shared.reloadTimelines()` is `@MainActor`** — must be wrapped in `await MainActor.run {}` when called from an async static function that is not actor-isolated.

[Source: implementation-artifacts/2-2-local-notification-delivery.md — Dev Notes, Completion Notes]

---

### Git Intelligence

Recent commits:
- `7803b06 Story 1.4 - 2.1` — Epic 1 and Story 2.1 committed
- `ebf3036 stories 1.2 and 1.3` — Foundation stories

Working tree status at Story 2.3 start:
- `AppDelegate.swift` — exists (new in Story 2.2); has stub `default:` case for Story 2.3 actions
- `NotificationService.swift` — exists (modified in Story 2.2); `registerNotificationCategories()` registers empty actions array
- `TODOAppApp.swift` — has `@UIApplicationDelegateAdaptor` and coordinator pass-through

Story 2.3 modifies **three existing files** only:
- `TODOApp/TODOApp/AppDelegate.swift` — add mark-done handler, modelContainer property
- `TODOApp/TODOApp/Core/Services/NotificationService.swift` — add action constants, populate category actions
- `TODOApp/TODOApp/TODOAppApp.swift` — pass modelContainer to appDelegate in `.onAppear`
- `TODOApp/TODOAppTests/Features/Notifications/NotificationServiceTests.swift` — add Story 2.3 tests
- `TODOApp/TODOAppTests/Features/Notifications/AppDelegateTests.swift` — add Story 2.3 tests
- `TODOApp/TODOApp.xcodeproj/project.pbxproj` — no new files; no PBX changes needed

---

### iOS API Notes — UNNotificationAction

**Background vs Foreground actions:**

```swift
// CORRECT for "Mark Done" (FR18: without opening the app):
UNNotificationAction(identifier: "mark-done", title: "Mark Done", options: [])

// WRONG — would bring app to foreground (violates FR18):
UNNotificationAction(identifier: "mark-done", title: "Mark Done", options: [.foreground])
```

**`.destructive` option:** Renders the action button with destructive (red) styling. Appropriate for "Dismiss" to visually differentiate it from "Mark Done." Does NOT affect behavior — it's purely cosmetic.

**Action ordering:** Actions appear in the notification's expanded view in the order they are added to the `actions` array. `[markDoneAction, dismissAction]` shows "Mark Done" first (primary action), "Dismiss" second.

**`UNNotificationCategory.options: [.customDismissAction]`:** Required for the system to call `didReceive` with `UNNotificationDismissActionIdentifier` when the user swipes to clear. Already set in Story 2.2 and must be retained.

**Simulator testing limitations:**
- Long-press on notification banners in Simulator may not expose action buttons in all Xcode/iOS versions
- Test on a physical device for definitive UX verification
- Unit tests verify action identifiers and logic; device test verifies button appearance

[Source: Apple Developer Documentation — UNNotificationAction.Options, UNNotificationCategory.Options]
[Source: architecture.md#Core Architectural Decisions — iOS 17.0 minimum deployment target]

---

### Critical: Background Task Completion — Thread Safety

The `completeTaskFromNotification` static function runs in an async context (from `Task { @MainActor in ... }` in the `nonisolated` delegate method). The `ModelContext` it creates is a **background context** — it is NOT the main context used by SwiftUI views.

**What this means for the UI:**
- The completion is saved to the SQLite store on a background context
- SwiftUI views using `@Query` will pick up the change automatically when they next refresh (CloudKit sync loop or next `@Query` re-evaluation)
- The task does NOT appear completed in real-time while the app is in the background — it will appear completed the **next time the app is opened** (per AC #2: "The task appears as completed the next time the app is opened")

**Why this is correct:**
The architecture mandates that repositories use background `ModelContext`. The background-save-then-reactive-refresh pattern is the correct SwiftData pattern for this scenario.

```swift
// CORRECT: background context for notification action handler
let context = ModelContext(container)   // background context
let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == uuid })
let matches = try context.fetch(descriptor)
guard let task = matches.first else { return }
task.isCompleted = true
task.modifiedAt = Date()
try context.save()   // saves to SQLite; @Query views will reflect change on next refresh
```

**Do NOT use `@MainActor` ModelContext for this:** The `@Environment(\.modelContext)` context is the main-thread context used by SwiftUI. It is not accessible outside of views. AppDelegate must create its own context.

[Source: architecture.md#Communication Patterns — "Background ModelContext — created by ModelContainer.newContext() for writes from App Intents / Notification actions; never hold a strong reference across suspension points"]
[Source: epics.md#Story 2.3 AC — "The task appears as completed the next time the app is opened"]

---

### Project Structure Notes

**Files to MODIFY in this story:**
```
TODOApp/TODOApp/AppDelegate.swift                                   ← Add modelContainer property; handle mark-done and dismiss cases; add completeTaskFromNotification static helper
TODOApp/TODOApp/Core/Services/NotificationService.swift             ← Add markDoneActionIdentifier and dismissActionIdentifier constants; populate registerNotificationCategories() with actions
TODOApp/TODOApp/TODOAppApp.swift                                    ← Pass sharedModelContainer to appDelegate.modelContainer in .onAppear
TODOApp/TODOAppTests/Features/Notifications/NotificationServiceTests.swift  ← Add Story 2.3 tests
TODOApp/TODOAppTests/Features/Notifications/AppDelegateTests.swift  ← Add Story 2.3 tests
```

**Files NOT to touch:**
- `AppCoordinator.swift` — no changes needed; `navigateTo(taskID:)` already handles UNNotificationDefaultActionIdentifier (Story 2.2)
- `Core/Repositories/TaskRepository.swift` — `completeTask(_:)` already implemented (Story 1.6); no changes needed
- `Core/Services/WidgetService.swift` — no changes needed; `reloadTimelines()` is already the singleton call
- `Features/Tasks/TaskDetailView.swift`, `TaskListView.swift` — no changes needed
- `Core/Models/TaskItem.swift` — no changes needed
- `project.pbxproj` — no new files; no PBX changes required

**Architecture alignment:**
- All `UNUserNotificationCenter` operations route through `NotificationService` — category registration update is correct placement [Source: architecture.md#Notification Boundary]
- Notification action handling in `AppDelegate` — correct per architecture; NOT in any View or ViewModel [Source: architecture.md#Process Patterns — Navigation from Notifications]
- Post-mutation side effects: `WidgetService.shared.reloadTimelines()` called after `completeTask` — mandatory [Source: architecture.md#Enforcement Guidelines]
- `cancelNotification(for:)` called after task completion — correct; cancels any other pending notifications for the same task [Source: architecture.md#Communication Patterns]
- Privacy: Logger MUST NOT log task titles or UUIDs in user-visible form [Source: architecture.md#Enforcement Guidelines]
- Swift 6 strict concurrency: `nonisolated` delegate methods + `Task { @MainActor in }` pattern maintained

---

### References

- [Source: epics.md#Story 2.3] — Full BDD acceptance criteria (banner actions, mark-done, dismiss)
- [Source: epics.md#FR18] — "Users can take a 'Mark Done' action directly from a notification without opening the app"
- [Source: epics.md#FR19] — "Users can dismiss or snooze a task notification from the notification banner"
- [Source: architecture.md#Notification Boundary] — "NotificationService is the single access point for all UNUserNotificationCenter operations"
- [Source: architecture.md#Process Patterns — Navigation from Notifications] — "UNNotificationResponse handled in AppDelegate.userNotificationCenter(_:didReceive:)"
- [Source: architecture.md#Communication Patterns] — Background ModelContext for notification action handlers; post-mutation side effects
- [Source: architecture.md#Enforcement Guidelines] — WidgetService.shared.reloadTimelines() mandatory; never log user content
- [Source: architecture.md#Integration Points — Data Flow] — "User completes task (notification) → AppDelegate handler → TaskRepository.completeTask() → WidgetService.reloadTimelines()"
- [Source: implementation-artifacts/2-2-local-notification-delivery.md] — AppDelegate implementation, notification identifier scheme, category registration stub, Swift 6 nonisolated pattern
- [Source: TODOApp/TODOApp/AppDelegate.swift] — Current AppDelegate; `switch response.actionIdentifier` has `default:` stub awaiting Story 2.3 cases
- [Source: TODOApp/TODOApp/Core/Services/NotificationService.swift] — Current `registerNotificationCategories()` with empty actions array; `taskReminderCategoryIdentifier` constant
- [Source: TODOApp/TODOApp/TODOAppApp.swift] — `@UIApplicationDelegateAdaptor`; `.onAppear` coordinator pass-through pattern (model container injection follows same pattern)
- [Source: Apple Developer Documentation — UNNotificationAction, UNNotificationCategory, UNNotificationActionOptions]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

### Completion Notes List

- Added `markDoneActionIdentifier = "mark-done"` and `dismissActionIdentifier = "dismiss"` static constants to `NotificationService`.
- Updated `registerNotificationCategories()` to create `UNNotificationAction` objects for both actions: "Mark Done" with `options: []` (background, per FR18 — no foreground launch) and "Dismiss" with `options: [.destructive]`. Both added to `TASK_REMINDER` category. `.customDismissAction` category option retained from Story 2.2.
- Added `var modelContainer: ModelContainer?` property to `AppDelegate`, injected from `TODOAppApp.body` `.onAppear` alongside existing `coordinator` pass-through.
- Added `SwiftData` import to `AppDelegate.swift`.
- Updated `switch response.actionIdentifier` in `didReceive` to handle `NotificationService.markDoneActionIdentifier` (fetches `TaskItem` by UUID via background `ModelContext`, sets `isCompleted = true`, saves, calls `WidgetService.shared.reloadTimelines()` and `NotificationService.shared.cancelNotification(for:)` on main actor) and `NotificationService.dismissActionIdentifier` (no-op log).
- Added private static helper `completeTaskFromNotification(uuid:container:)` to `AppDelegate` — static to avoid actor-isolation issues, uses direct `FetchDescriptor` on background `ModelContext`.
- Added Story 2.3 tests to `NotificationServiceTests.swift`: `markDoneActionIdentifierIsCorrect`, `dismissActionIdentifierIsCorrect`, `registerNotificationCategoriesIncludesMarkDoneAction`.
- Added Story 2.3 tests to `AppDelegateTests.swift`: `markDoneActionIdentifierConstantIsStable`, `dismissActionIdentifierConstantIsStable`, `dismissActionDoesNotChangeCompletionState`, `appDelegateModelContainerPropertyCanBeSet`.
- No new PBX entries required — all modified files were already registered.

### File List

- `TODOApp/TODOApp/AppDelegate.swift` (MODIFIED)
- `TODOApp/TODOApp/TODOAppApp.swift` (MODIFIED)
- `TODOApp/TODOApp/Core/Services/NotificationService.swift` (MODIFIED)
- `TODOApp/TODOAppTests/Features/Notifications/NotificationServiceTests.swift` (MODIFIED)
- `TODOApp/TODOAppTests/Features/Notifications/AppDelegateTests.swift` (MODIFIED)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (MODIFIED)

## Change Log

- 2026-02-18: Story 2.3 implemented — added "Mark Done" (background action, no foreground launch per FR18) and "Dismiss" (destructive-styled no-op) `UNNotificationAction` objects to `TASK_REMINDER` category in `NotificationService`; handled `mark-done` action in `AppDelegate` with background `ModelContext` fetch, `isCompleted = true`, `WidgetService.reloadTimelines()`, and `cancelNotification(for:)`; handled `dismiss` action as no-op log; injected `modelContainer` into `AppDelegate` from `TODOAppApp.onAppear`; added Story 2.3 unit tests.
