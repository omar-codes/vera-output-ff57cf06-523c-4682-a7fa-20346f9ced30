# Story 2.4: Reschedule Notifications After Offline Recovery

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an iPhone user,
I want reminders to fire correctly after my device was offline,
So that I never miss a task notification due to connectivity issues.

## Acceptance Criteria

1. **Given** the device was offline and reconnects **When** the network is restored **Then**:
   - `NotificationService` reschedules any pending notifications for tasks whose `reminderDate` is in the future (FR20)
   - Tasks with a `reminderDate` in the past that were not completed while offline surface as overdue (FR9 visual distinction — existing behavior, no new code needed)

2. **Given** a task had its reminder fire while the device was offline **When** the device comes back online **Then**:
   - The notification fires within 60 seconds of reconnection (NFR7 — offline sync within 60 seconds)

3. **Given** the app is in the foreground or background when network is restored **When** `NotificationService.rescheduleAllPendingNotifications()` runs **Then**:
   - Only tasks with `reminderDate > Date()` and `isCompleted == false` are scheduled
   - Tasks already completed are skipped (no spurious notifications)
   - Tasks with past `reminderDate` and `isCompleted == false` are NOT rescheduled (they are overdue — FR9 handles visual distinction)

## Tasks / Subtasks

- [x] Task 1: Add `rescheduleAllPendingNotifications()` to `NotificationService` (AC: #1, #2, #3)
  - [x] 1.1 Implement `func rescheduleAllPendingNotifications(using context: ModelContext)` on `NotificationService`
  - [x] 1.2 Fetch all incomplete tasks with a future `reminderDate` using `FetchDescriptor<TaskItem>` with predicate: `!task.isCompleted && task.reminderDate != nil`
  - [x] 1.3 For each matching task call `scheduleNotification(for:)` — this replaces any existing pending notification with the same identifier (`"task-\(task.id.uuidString)"`) idempotently
  - [x] 1.4 Log count of tasks rescheduled via `Logger.notifications` (no task content)
  - [x] 1.5 Method signature must accept a `ModelContext` parameter — do NOT create a new `ModelContainer` inside `NotificationService`

- [x] Task 2: Observe network connectivity changes and trigger reschedule (AC: #1, #2)
  - [x] 2.1 Create `NetworkMonitor.swift` in `Core/Services/` using `Network.framework` (`NWPathMonitor`)
  - [x] 2.2 `NetworkMonitor` is a `@MainActor` `@Observable` class with a `isConnected: Bool` published property (follows architecture MVVM pattern)
  - [x] 2.3 On transition from offline → online (`path.status == .satisfied` after prior `.unsatisfied` or `.requiresConnection`), call `NotificationService.shared.rescheduleAllPendingNotifications(using:)` with a new background `ModelContext` from the injected `ModelContainer`
  - [x] 2.4 `NetworkMonitor` must receive `ModelContainer` injection — inject it from `TODOAppApp` the same way `AppDelegate.modelContainer` is injected via `.onAppear`
  - [x] 2.5 `NWPathMonitor` must run on a background `DispatchQueue`, not the main queue (use `queue: DispatchQueue(label: "com.todoapp.network-monitor")`)
  - [x] 2.6 Dispatch main-actor work (`rescheduleAllPendingNotifications`) via `Task { @MainActor in ... }` from the NWPathMonitor callback
  - [x] 2.7 Cancel `NWPathMonitor` on `deinit`

- [x] Task 3: Instantiate and wire `NetworkMonitor` in `TODOAppApp` (AC: #1)
  - [x] 3.1 Add `@State private var networkMonitor = NetworkMonitor()` to `TODOAppApp`
  - [x] 3.2 In `.onAppear`, set `networkMonitor.modelContainer = sharedModelContainer`
  - [x] 3.3 Call `networkMonitor.startMonitoring()` in `.onAppear` (or in `NetworkMonitor.init()` — see Dev Notes)
  - [x] 3.4 Inject `networkMonitor` into the environment via `.environment(networkMonitor)` for any views that need connectivity state (optional — only if a view needs to observe it)

- [x] Task 4: Add unit tests (AC: all)
  - [x] 4.1 `NetworkMonitorTests.swift` in `TODOAppTests/Features/Notifications/` — verify `isConnected` initial state and that `startMonitoring()` does not crash
  - [x] 4.2 `NotificationServiceTests.swift` — add `rescheduleAllPendingNotificationsSkipsCompletedTasks` test: create two `TaskItem` objects in an in-memory `ModelContainer` — one `isCompleted = true`, one `isCompleted = false`, both with future `reminderDate`; call `rescheduleAllPendingNotifications(using:)` and verify no crash, completed task not scheduled
  - [x] 4.3 `NotificationServiceTests.swift` — add `rescheduleAllPendingNotificationsSkipsPastReminderDates` test: task with `reminderDate` in the past should be excluded from scheduling
  - [x] 4.4 Register `NetworkMonitorTests.swift` in `project.pbxproj` (required — new file)

- [x] Task 5: Update `project.pbxproj` for new files (AC: prerequisite)
  - [x] 5.1 Add `NetworkMonitor.swift` to `TODOApp` main app target in `project.pbxproj`
  - [x] 5.2 Add `NetworkMonitorTests.swift` to `TODOAppTests` target in `project.pbxproj`

## Dev Notes

### Core Architecture for Offline Recovery

Story 2.4 implements FR20: "The system reschedules notifications after the device reconnects following an offline period." The mechanism is:

1. **`NWPathMonitor`** (Network framework) detects offline → online transition
2. **`NetworkMonitor`** service calls `NotificationService.rescheduleAllPendingNotifications(using:)`
3. **`NotificationService`** fetches all incomplete tasks with future `reminderDate` from SwiftData and re-schedules their `UNUserNotificationCenter` notifications

**Why reschedule is needed:** iOS `UNCalendarNotificationTrigger` notifications are stored locally and fire even offline — EXCEPT when the device was completely powered down, in airplane mode with reboot, or the notification was cleared during an OS process kill during offline period. Rescheduling on reconnect is a defensive guarantee. It is idempotent: adding a `UNNotificationRequest` with an existing identifier replaces the existing pending request.

[Source: epics.md#Story 2.4 — FR20, NFR7]
[Source: architecture.md#Communication Patterns — Post-mutation side effects; NotificationService singleton]

---

### `NetworkMonitor` Implementation

```swift
// Core/Services/NetworkMonitor.swift — NEW FILE
import Foundation
import Network
import SwiftData

@MainActor
@Observable
final class NetworkMonitor {
    var isConnected: Bool = false
    var modelContainer: ModelContainer?

    private var monitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.todoapp.network-monitor")
    private var previousStatus: NWPath.Status = .requiresConnection

    func startMonitoring() {
        let monitor = NWPathMonitor()
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let wasOffline = self.previousStatus != .satisfied
            let isNowOnline = path.status == .satisfied
            self.previousStatus = path.status

            Task { @MainActor in
                self.isConnected = isNowOnline
                if wasOffline && isNowOnline {
                    // Transitioned from offline to online — reschedule pending notifications
                    guard let container = self.modelContainer else { return }
                    let context = ModelContext(container)
                    NotificationService.shared.rescheduleAllPendingNotifications(using: context)
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit {
        monitor?.cancel()
    }
}
```

**Swift 6 Concurrency Notes:**
- `@MainActor @Observable` — same pattern as all services/ViewModels in the project
- `NWPathMonitor.pathUpdateHandler` is called on `monitorQueue` (background thread) — use `Task { @MainActor in ... }` to switch context for `isConnected` updates and `NotificationService` call
- `[weak self]` capture to avoid retain cycle in the closure

[Source: architecture.md#Communication Patterns — @Observable @MainActor pattern for services]
[Source: architecture.md#Enforcement Guidelines — Never block main thread; CloudKit operations on background threads]

---

### `NotificationService.rescheduleAllPendingNotifications(using:)` Implementation

```swift
// Core/Services/NotificationService.swift — MODIFIED: add this method
/// Reschedule notifications for all incomplete tasks with a future reminderDate.
/// Called after network reconnection (FR20 — offline recovery).
/// Idempotent: scheduling with an existing identifier replaces the pending request.
/// - Parameter context: A ModelContext (background recommended) to fetch tasks from SwiftData.
func rescheduleAllPendingNotifications(using context: ModelContext) {
    // Fetch all incomplete tasks that have a reminderDate set
    let now = Date()
    let descriptor = FetchDescriptor<TaskItem>(
        predicate: #Predicate { task in
            !task.isCompleted && task.reminderDate != nil
        }
    )
    do {
        let tasks = try context.fetch(descriptor)
        // Filter to only future reminderDate (can't filter nil optionals in SwiftData predicate)
        let futureTasks = tasks.filter { $0.reminderDate! > now }
        futureTasks.forEach { scheduleNotification(for: $0) }
        Logger.notifications.info("Rescheduled notifications for \(futureTasks.count) tasks after reconnect")
    } catch {
        Logger.notifications.error("Failed to fetch tasks for notification reschedule")
    }
}
```

**SwiftData Predicate Limitation:** `#Predicate` cannot compare `Optional<Date>` with `Date` directly in some compiler versions. The safest approach is to predicate on `!isCompleted` and `reminderDate != nil`, then filter the Swift array for `reminderDate! > now`. This avoids a runtime crash on the optional comparison.

**Idempotency:** `UNUserNotificationCenter.add(_:)` with an identifier that matches an already-pending request **replaces** the existing request. This is the correct iOS behavior — no need to cancel before rescheduling.

[Source: epics.md#Story 2.4 AC — "reschedules any pending notifications for tasks whose reminderDate is in the future"]
[Source: Apple Developer Documentation — UNUserNotificationCenter.add(_:withCompletionHandler:) — "If a request with the same identifier already exists, the new request supersedes the existing one"]

---

### `TODOAppApp.swift` Changes

```swift
// TODOApp/TODOAppApp.swift — MODIFIED
@main
struct TODOAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var coordinator = AppCoordinator()
    @State private var networkMonitor = NetworkMonitor()  // ← NEW

    let sharedModelContainer: ModelContainer = { /* unchanged */ }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(coordinator)
                // .environment(networkMonitor)  ← add if any view needs to observe isConnected
                .onAppear {
                    appDelegate.coordinator = coordinator
                    appDelegate.modelContainer = sharedModelContainer
                    // ← NEW: inject container and start monitoring
                    networkMonitor.modelContainer = sharedModelContainer
                    networkMonitor.startMonitoring()
                }
        }
        .modelContainer(sharedModelContainer)
        .onOpenURL { url in
            coordinator.handleURL(url)
        }
    }
}
```

**Important:** `.onAppear` fires only once for the root `WindowGroup` view — `startMonitoring()` is called once at app launch, which is correct. Do NOT call `startMonitoring()` in `NetworkMonitor.init()` as the `modelContainer` won't be set yet.

[Source: implementation-artifacts/2-3-mark-done-and-dismiss-from-notification-banner.md — same injection pattern for `appDelegate.modelContainer`]
[Source: architecture.md#App Target Boundary — TODOAppApp owns the main ModelContainer and injects it]

---

### What Happens for Tasks with Past `reminderDate`

Per AC #1 and the epics specification:
- Tasks with `reminderDate` **in the past** and `isCompleted == false` → surface as **overdue** (FR9 visual distinction)
- The overdue visual state is already implemented in `TaskListView` via the overdue predicate in `TaskListViewModel` — **no new code needed**
- `rescheduleAllPendingNotifications` intentionally skips past `reminderDate` tasks (filtering `reminderDate! > now`)
- These tasks will appear with a red/overdue indicator in the task list when the user opens the app

This is correct per AC #1: "Tasks with a reminderDate in the past that were not completed while offline surface as overdue (FR9 visual distinction)."

[Source: epics.md#Story 1.3 AC — "overdue tasks (dueDate < now, isCompleted == false) are visually distinct"]
[Source: epics.md#Story 2.4 AC — "Tasks with a reminderDate in the past that were not completed while offline surface as overdue"]

---

### Network Framework Import

`Network.framework` does NOT require any additional Xcode capability or entitlement — it is available as part of the iOS SDK and is automatically linked. Just `import Network`.

[Source: Apple Developer Documentation — Network framework — "Available in iOS 12.0+"]

---

### Previous Story Intelligence (Story 2.3)

Key patterns established that apply to Story 2.4:

1. **`AppDelegate.modelContainer` injection pattern is proven** — `TODOAppApp.onAppear` sets `appDelegate.modelContainer = sharedModelContainer`. `NetworkMonitor.modelContainer` follows the same injection pattern from `TODOAppApp.onAppear`.

2. **Background `ModelContext` pattern** — `let context = ModelContext(container)` creates a fresh background context. This is the established pattern for all non-view SwiftData operations. Story 2.4 uses the same pattern in `rescheduleAllPendingNotifications(using:)`.

3. **`NotificationService` is `@MainActor` singleton** — calling `NotificationService.shared.rescheduleAllPendingNotifications(using:)` from `Task { @MainActor in }` in `NetworkMonitor`'s path handler is correct.

4. **`scheduleNotification(for:)` uses the identifier `"task-\(task.id.uuidString)"`** — this is the established format from Story 2.2. `rescheduleAllPendingNotifications` calls `scheduleNotification(for:)` which already generates this identifier.

5. **No new files were added in Story 2.3** — Story 2.4 adds `NetworkMonitor.swift` and `NetworkMonitorTests.swift`. Both must be registered in `project.pbxproj`.

6. **Test file `NotificationServiceTests.swift` exists at** `TODOApp/TODOAppTests/Features/Notifications/NotificationServiceTests.swift` — append Story 2.4 tests to this file.

[Source: implementation-artifacts/2-3-mark-done-and-dismiss-from-notification-banner.md]

---

### Git Intelligence

Recent commits:
- `7803b06 Story 1.4 - 2.1` — Stories 1.4 through 2.1 implemented
- `ebf3036 stories 1.2 and 1.3` — Foundation stories

Story 2.4 adds **two new files** and modifies **three existing files**:
- **NEW:** `TODOApp/TODOApp/Core/Services/NetworkMonitor.swift`
- **NEW:** `TODOApp/TODOAppTests/Features/Notifications/NetworkMonitorTests.swift`
- **MODIFIED:** `TODOApp/TODOApp/Core/Services/NotificationService.swift` — add `rescheduleAllPendingNotifications(using:)`
- **MODIFIED:** `TODOApp/TODOApp/TODOAppApp.swift` — add `@State networkMonitor`, inject `modelContainer`, call `startMonitoring()`
- **MODIFIED:** `TODOApp/TODOApp.xcodeproj/project.pbxproj` — register both new files

---

### Project Structure Notes

**New files to CREATE:**
```
TODOApp/TODOApp/Core/Services/NetworkMonitor.swift          ← NWPathMonitor wrapper; triggers reschedule on reconnect
TODOApp/TODOAppTests/Features/Notifications/NetworkMonitorTests.swift  ← unit tests
```

**Files to MODIFY:**
```
TODOApp/TODOApp/Core/Services/NotificationService.swift     ← add rescheduleAllPendingNotifications(using:)
TODOApp/TODOApp/TODOAppApp.swift                            ← add networkMonitor @State; inject container; startMonitoring()
TODOApp/TODOApp.xcodeproj/project.pbxproj                   ← register both new files
```

**Files NOT to touch:**
- `AppDelegate.swift` — no changes; mark-done handler from Story 2.3 is complete
- `TaskListView.swift` / `TaskListViewModel.swift` — overdue visual state already implemented (FR9)
- `TaskItem.swift` — model unchanged
- `TaskRepository.swift` — no new repository methods needed
- `WidgetService.swift` — no changes (reschedule does not trigger widget reload — notifications != widget state)

**Architecture alignment:**
- `NetworkMonitor` → `Core/Services/` (cross-cutting service, not feature-specific) [Source: architecture.md#Shared Code Placement]
- `@Observable @MainActor` pattern for service class [Source: architecture.md#Frontend / UI Architecture]
- Background `ModelContext` from injected `ModelContainer` [Source: architecture.md#Communication Patterns]
- `NotificationService` remains the single access point for all `UNUserNotificationCenter` operations [Source: architecture.md#Notification Boundary]
- Post-mutation rule: `WidgetService.shared.reloadTimelines()` is NOT called in `rescheduleAllPendingNotifications` — rescheduling notifications is not a task state mutation; widget content does not change

---

### References

- [Source: epics.md#Story 2.4] — Full BDD acceptance criteria (reschedule, overdue, 60-second reconnect)
- [Source: epics.md#FR20] — "The system reschedules notifications after the device reconnects following an offline period"
- [Source: epics.md#FR9] — "Users can view overdue tasks distinctly from current tasks" (existing behavior, no new code)
- [Source: epics.md#NFR7] — "Offline-created tasks sync within 60 seconds of network restoration"
- [Source: epics.md#NFR9] — "Local notifications fire within 60 seconds of their scheduled time"
- [Source: architecture.md#Notification Boundary] — "NotificationService is the single access point for all UNUserNotificationCenter operations"
- [Source: architecture.md#Communication Patterns] — Background ModelContext pattern; post-mutation side effects
- [Source: architecture.md#Structure Patterns] — Core/Services/ for cross-cutting services
- [Source: architecture.md#Enforcement Guidelines] — Never log user content; WidgetService.reloadTimelines after mutation
- [Source: implementation-artifacts/2-3-mark-done-and-dismiss-from-notification-banner.md] — ModelContainer injection pattern; NotificationService @MainActor
- [Source: implementation-artifacts/2-2-local-notification-delivery.md] — scheduleNotification identifier format "task-\(task.id.uuidString)"
- [Source: Apple Developer Documentation — NWPathMonitor] — Network.framework for connectivity monitoring
- [Source: Apple Developer Documentation — UNUserNotificationCenter.add(_:)] — Replacing existing requests by identifier (idempotent)

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

None — implementation proceeded without errors.

### Completion Notes List

- Implemented `rescheduleAllPendingNotifications(using:)` on `NotificationService` (FR20). Method fetches incomplete tasks with non-nil `reminderDate` via SwiftData `FetchDescriptor`, filters to future dates in Swift (due to `Optional<Date>` predicate limitation), and calls `scheduleNotification(for:)` which is idempotent by identifier.
- Created `NetworkMonitor` (`@MainActor @Observable`) using `NWPathMonitor` from `Network.framework`. Detects offline→online transition (previous status != `.satisfied`, new status == `.satisfied`) and triggers reschedule via `Task { @MainActor in }` from the background monitor queue.
- Wired `NetworkMonitor` into `TODOAppApp`: added `@State private var networkMonitor`, injected `sharedModelContainer` and called `startMonitoring()` from `.onAppear` (same pattern as `AppDelegate.modelContainer` injection from Story 2.3).
- Added 4 unit tests: `NetworkMonitorTests` (2 tests — initial state, `startMonitoring()` no crash, model container injection), `NotificationServiceTests` (2 new tests — skip completed tasks, skip past reminder dates).
- Registered both new files in `project.pbxproj`: `PBXBuildFile`, `PBXFileReference`, `PBXGroup` children, and `PBXSourcesBuildPhase` entries for both targets.
- `Network.framework` requires no additional capability/entitlement — available as part of iOS 12+ SDK via `import Network`.
- Task 3.4 (environment injection): `networkMonitor` is NOT injected into the environment since no view currently needs to observe `isConnected`. Comment in Dev Notes preserved.

### File List

- TODOApp/TODOApp/Core/Services/NetworkMonitor.swift (NEW)
- TODOApp/TODOAppTests/Features/Notifications/NetworkMonitorTests.swift (NEW)
- TODOApp/TODOApp/Core/Services/NotificationService.swift (MODIFIED — added `rescheduleAllPendingNotifications(using:)` and `import SwiftData`)
- TODOApp/TODOApp/TODOAppApp.swift (MODIFIED — added `@State private var networkMonitor`, container injection, `startMonitoring()` call)
- TODOApp/TODOApp.xcodeproj/project.pbxproj (MODIFIED — registered `NetworkMonitor.swift` and `NetworkMonitorTests.swift`)
- TODOApp/TODOAppTests/Features/Notifications/NotificationServiceTests.swift (MODIFIED — added Story 2.4 tests)
- _bmad-output/implementation-artifacts/sprint-status.yaml (MODIFIED — story status updated)

### Change Log

- 2026-02-18: Story 2.4 implemented — offline recovery notification reschedule. Added `NetworkMonitor` service using `NWPathMonitor`, wired into `TODOAppApp`, added `rescheduleAllPendingNotifications(using:)` to `NotificationService`. 6 new unit tests added across `NetworkMonitorTests` and `NotificationServiceTests`.
