# Story 2.2: Local Notification Delivery

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an iPhone user,
I want to receive a local notification when my reminder fires,
So that I'm prompted to act on the task at the right time.

## Acceptance Criteria

1. **Given** a task has a `reminderDate` set and notification permission is granted **When** the `reminderDate` arrives **Then**:
   - A local notification fires via `UNUserNotificationCenter` within 60 seconds of the scheduled time (NFR9)
   - The notification `title` equals the task title
   - The notification `body` references the due date (e.g., "Due Feb 18, 2026")
   - The notification `identifier` is `"task-\(task.id.uuidString)"` — exactly matching the identifier used in `NotificationService.scheduleNotification(for:)` implemented in Story 2.1

2. **Given** the notification fires **When** the user taps the notification body **Then**:
   - The app opens to `TaskDetailView` for that specific task
   - Navigation is routed via `AppCoordinator.navigateTo(taskID:)` using the `todoapp://open-task?id=<uuid>` URL scheme pattern
   - `UNNotificationResponse` is handled in an `AppDelegate`-style handler registered via `UNUserNotificationCenterDelegate`

3. **Given** the device is locked or the app is backgrounded **When** the reminder fires **Then**:
   - The notification still appears on the lock screen and as a notification banner (NFR25)
   - No special handling required — `UNCalendarNotificationTrigger` with `repeats: false` survives app backgrounding and device relock by design

4. **Given** `UNUserNotificationCenterDelegate` is registered **When** the app is in the foreground and a notification fires **Then**:
   - The app presents the notification as a banner (`.banner` presentation option) rather than silently discarding it
   - `userNotificationCenter(_:willPresent:withCompletionHandler:)` is implemented to allow foreground delivery

5. **Given** any error occurs in delegate handling **When** an error is thrown **Then**:
   - Errors are caught and logged privately via `Logger` (no task content logged)
   - The UI is not shown raw error messages

## Tasks / Subtasks

- [x] Task 1: Wire `UNUserNotificationCenterDelegate` in `TODOAppApp.swift` or a dedicated `AppDelegate` (AC: #2, #3, #4)
  - [x] 1.1 Create `TODOApp/AppDelegate.swift` as a `UIApplicationDelegate` conforming class with `@MainActor` — registered via `@UIApplicationDelegateAdaptor(AppDelegate.self)` in `TODOAppApp.swift`
  - [x] 1.2 In `AppDelegate` (or `TODOAppApp.init`), call `UNUserNotificationCenter.current().delegate = <self or singleton>` — MUST be set before app finishes launching (Apple requirement)
  - [x] 1.3 Implement `userNotificationCenter(_:didReceive:withCompletionHandler:)` to handle notification tap: extract task UUID from `response.notification.request.identifier` (`"task-\(uuid)"` → strip prefix), call `AppCoordinator.shared` or post a notification to route to `TaskDetailView`
  - [x] 1.4 Implement `userNotificationCenter(_:willPresent:withCompletionHandler:)` to allow foreground banner delivery: call `completionHandler([.banner, .sound])` to show notification even when app is in foreground

- [x] Task 2: Implement notification response routing to `AppCoordinator` (AC: #2)
  - [x] 2.1 Extract `taskID: UUID` from `response.notification.request.identifier` — identifier format is `"task-\(task.id.uuidString)"`; use `String.dropFirst("task-".count)` and `UUID(uuidString:)`
  - [x] 2.2 Route to `AppCoordinator.navigateTo(taskID:)` — the `AppCoordinator` is `@State` on `TODOAppApp`; the delegate needs access to it; use `@Environment` injection or a `NotificationCenter` post (`Notification.Name.taskOpenRequested`) that `AppCoordinator` observes
  - [x] 2.3 Handle the `UNNotificationDefaultActionIdentifier` (user taps the notification body) — this is the standard tap action; distinguish from custom actions added in Story 2.3 (Mark Done / Dismiss)
  - [x] 2.4 Register `AppDelegate` PBX entries in `project.pbxproj`

- [x] Task 3: Extend `NotificationService` with `categoryIdentifier` for future action support (AC: #2, Story 2.3 prep)
  - [x] 3.1 Add a `UNNotificationCategory` with identifier `"TASK_REMINDER"` registered via `UNUserNotificationCenter.current().setNotificationCategories(_:)` at app launch — this category will have actions added in Story 2.3 ("Mark Done", "Dismiss")
  - [x] 3.2 Set `content.categoryIdentifier = "TASK_REMINDER"` in `NotificationService.scheduleNotification(for:)` — enables Story 2.3 to attach quick actions without changing the delivery mechanism
  - [x] 3.3 Add `registerNotificationCategories()` method to `NotificationService` — called once at app launch in `AppDelegate.application(_:didFinishLaunchingWithOptions:)` or in `TODOAppApp.init`

- [x] Task 4: Add unit tests for notification delivery infrastructure (AC: #1, #2, #4)
  - [x] 4.1 Add to `NotificationServiceTests.swift`: `scheduleNotificationSetsCorrectCategoryIdentifier` — verifies `content.categoryIdentifier == "TASK_REMINDER"` on a scheduled request
  - [x] 4.2 Add `notificationIdentifierParsing` tests — verify UUID extraction from `"task-\(uuid.uuidString)"` identifier string round-trip
  - [x] 4.3 Add `willPresentNotificationReturnsCorrectOptions` — if delegate logic is unit-testable, verify `.banner` and `.sound` are returned

- [x] Task 5: Register new files in `project.pbxproj` (AC: all)
  - [x] 5.1 Add `AppDelegate.swift` PBXFileReference (e.g., `A500`) and PBXBuildFile (`B500`) to main app target Sources
  - [x] 5.2 No changes to `NotificationService.swift` PBX entries — already registered as A208/B208

## Dev Notes

### Architecture: How `UNUserNotificationCenterDelegate` Integrates with SwiftUI App

The `TODOAppApp` struct uses the SwiftUI `App` protocol — there is no `UIApplicationDelegate` by default. To handle `UNUserNotificationCenterDelegate` callbacks, there are two approaches:

**Chosen Approach: `@UIApplicationDelegateAdaptor`**

```swift
// TODOApp/TODOAppApp.swift — MODIFIED
import SwiftUI
import SwiftData

@main
struct TODOAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var coordinator = AppCoordinator()

    let sharedModelContainer: ModelContainer = { /* unchanged */ }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(coordinator)
                .onAppear {
                    // Pass coordinator reference to AppDelegate for notification routing
                    appDelegate.coordinator = coordinator
                }
        }
        .modelContainer(sharedModelContainer)
        .onOpenURL { url in
            coordinator.handleURL(url)
        }
    }
}
```

```swift
// TODOApp/AppDelegate.swift — NEW
import UIKit
import UserNotifications
import SwiftData
import OSLog

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// Set by TODOAppApp once coordinator is available
    var coordinator: AppCoordinator?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationService.shared.registerNotificationCategories()
        return true
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when user taps a notification (or takes an action)
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        let identifier = response.notification.request.identifier
        // Identifier format: "task-<UUID>"
        guard identifier.hasPrefix("task-"),
              let uuid = UUID(uuidString: String(identifier.dropFirst("task-".count))) else {
            Logger.notifications.error("Received notification with unrecognized identifier format")
            return
        }

        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification body — navigate to task detail
            Task { @MainActor in
                coordinator?.navigateTo(taskID: uuid)
            }

        case UNNotificationDismissActionIdentifier:
            // User dismissed — no action needed (Story 2.3 adds explicit Dismiss action)
            Logger.notifications.info("Notification dismissed by user")

        default:
            // Custom action identifiers handled in Story 2.3 ("mark-done", "dismiss")
            Logger.notifications.info("Unhandled notification action received")
        }
    }

    /// Called when a notification fires while the app is in the foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner + play sound even when app is in foreground
        completionHandler([.banner, .sound])
    }
}
```

**Why `nonisolated`:** `UNUserNotificationCenterDelegate` methods are called on an arbitrary thread by the system. In Swift 6 strict concurrency, these delegate methods must be `nonisolated` (or the class must not be `@MainActor`). The `Task { @MainActor in }` inside re-dispatches to the main actor for safe `coordinator` access.

**Why `@UIApplicationDelegateAdaptor`:** This is the standard SwiftUI + `UIApplicationDelegate` bridge. The `appDelegate` property on `TODOAppApp` gives access to the delegate instance for passing `coordinator`.

[Source: architecture.md#Process Patterns — Navigation from Notifications: "UNNotificationResponse handled in AppDelegate.userNotificationCenter(_:didReceive:)"]
[Source: architecture.md#Process Patterns — "Routes via AppCoordinator.navigateTo(taskID:)"]
[Source: Apple Developer Documentation — UNUserNotificationCenterDelegate]

---

### Notification Identifier Parsing — Critical Constraint

The identifier scheme `"task-\(task.id.uuidString)"` was established in Story 2.1 and is used in `NotificationService.scheduleNotification(for:)` and `NotificationService.cancelNotification(for:)`. Story 2.2 MUST parse this format without modification.

```swift
// CORRECT parsing (used in AppDelegate.userNotificationCenter(_:didReceive:))
let identifier = response.notification.request.identifier
guard identifier.hasPrefix("task-"),
      let uuid = UUID(uuidString: String(identifier.dropFirst("task-".count))) else {
    // Log and bail — do not crash
    return
}
// uuid is now the TaskItem.id

// WRONG — do NOT use:
// let uuid = UUID(uuidString: identifier)  // fails — has "task-" prefix
// identifier.split(separator: "-").last    // wrong — UUID contains dashes
```

**Key:** `identifier.dropFirst("task-".count)` removes exactly 5 characters (`t`, `a`, `s`, `k`, `-`) leaving the canonical UUID string (e.g., `"550E8400-E29B-41D4-A716-446655440000"`).

[Source: implementation-artifacts/2-1-set-due-date-and-reminder-time-on-a-task.md — NotificationService.swift identifier scheme]
[Source: architecture.md#Notification Boundary — "notification identifier scheme: task-\(task.id.uuidString)"]

---

### Category Registration for Story 2.3 Preparation

Story 2.3 adds "Mark Done" and "Dismiss" quick actions to notification banners. These require a `UNNotificationCategory` to be registered **before** any notifications are scheduled. Story 2.2 registers the category with no actions (placeholder), then Story 2.3 adds the actual `UNNotificationAction` objects.

```swift
// Core/Services/NotificationService.swift — MODIFIED: add registerNotificationCategories()

/// Register notification categories with UNUserNotificationCenter.
/// Called once at app launch. Story 2.3 will add UNNotificationActions to this category.
func registerNotificationCategories() {
    let taskReminderCategory = UNNotificationCategory(
        identifier: NotificationService.taskReminderCategoryIdentifier,
        actions: [],          // Story 2.3 will add "Mark Done" and "Dismiss" actions here
        intentIdentifiers: [],
        options: [.customDismissAction]   // .customDismissAction needed for Story 2.3's Dismiss action
    )
    center.setNotificationCategories([taskReminderCategory])
    Logger.notifications.info("Notification categories registered")
}

// Add static constant for category identifier — used in scheduleNotification and Story 2.3:
static let taskReminderCategoryIdentifier = "TASK_REMINDER"
```

**Update `scheduleNotification(for:)` in `NotificationService`** to set `content.categoryIdentifier`:

```swift
// In scheduleNotification(for:), after content.sound = .default, ADD:
content.categoryIdentifier = NotificationService.taskReminderCategoryIdentifier
```

This change to `NotificationService.scheduleNotification(for:)` is the ONLY modification to the existing notification scheduling path. All other `NotificationService` code is unchanged.

[Source: epics.md#Story 2.3 — "Mark Done" and "Dismiss" notification quick actions]
[Source: Apple Developer Documentation — UNNotificationCategory, UNNotificationAction]

---

### `AppCoordinator` Access Pattern from `AppDelegate`

`AppCoordinator` is a `@State` property on `TODOAppApp` — it is not a singleton. The delegate needs a reference to route notification taps. The approach used is:

```swift
// In TODOAppApp.body, pass coordinator to AppDelegate via .onAppear:
.onAppear {
    appDelegate.coordinator = coordinator
}
```

**Alternative considered and rejected: `NotificationCenter` post**

```swift
// Alternative: post to NotificationCenter, AppCoordinator observes
// REJECTED — adds observer management complexity; direct reference is simpler and type-safe
```

**Why this is safe under Swift 6:**
- `coordinator` property on `AppDelegate` is accessed only within `Task { @MainActor in }` blocks
- The `@State` `coordinator` on `TODOAppApp` is `@MainActor`; setting `appDelegate.coordinator = coordinator` in `.onAppear` (which runs on `@MainActor`) is safe
- All reads of `coordinator` in delegate methods are wrapped in `Task { @MainActor in }` to re-isolate

[Source: architecture.md#Frontend/UI Architecture — "AppCoordinator is @Observable @MainActor class owned by the App struct"]
[Source: architecture.md#Core Architectural Decisions — Swift 6 strict concurrency]

---

### NFR9 Compliance: Notification Fires Within 60 Seconds

NFR9 states: "Local notifications fire within 60 seconds of their scheduled time."

`UNCalendarNotificationTrigger` with `repeats: false` satisfies NFR9 by design — iOS fires calendar triggers at the exact specified time (±system scheduling latency, typically <1 second). The 60-second tolerance in NFR9 covers device wake-from-sleep scenarios.

No additional developer action is required to meet NFR9 beyond what was implemented in Story 2.1 (`UNCalendarNotificationTrigger` with `dateComponents` including year/month/day/hour/minute and `second = 0`).

**NFR25 Compliance (notification survives backgrounding):**
`UNCalendarNotificationTrigger` stores the pending notification in the system notification queue, not in the app's process. The notification fires even if the app is killed. No explicit "background mode" entitlement is needed for local notifications.

[Source: epics.md#Story 2.2 AC — "Given the device is locked or the app is backgrounded... notification still appears (NFR25)"]
[Source: architecture.md#NFR25 — "Local notification scheduling survives app backgrounding and device relock"]

---

### `UNNotificationDefaultActionIdentifier` vs Custom Action

When a user taps the notification banner body (not a quick action button), `response.actionIdentifier` is `UNNotificationDefaultActionIdentifier` (value: `"com.apple.UNNotificationDefaultActionIdentifier"`).

Story 2.3 will add:
- `"mark-done"` action (tapping "Mark Done" button)
- `UNNotificationDismissActionIdentifier` (swiping to dismiss — Story 2.3 notes this is automatic via `.customDismissAction` category option)

Story 2.2 only handles `UNNotificationDefaultActionIdentifier` — the tap-to-open scenario.

```swift
// Proper action identifier handling (defensive pattern, extensible for Story 2.3):
switch response.actionIdentifier {
case UNNotificationDefaultActionIdentifier:
    // Story 2.2: open task detail
    Task { @MainActor in coordinator?.navigateTo(taskID: uuid) }

case "mark-done":
    // Story 2.3: complete task from notification
    // (not implemented in Story 2.2 — guard prevents crash)
    Logger.notifications.info("mark-done action received — handled in Story 2.3")

default:
    Logger.notifications.info("Unknown notification action: \(response.actionIdentifier)")
}
```

[Source: epics.md#Story 2.3 — "Mark Done" quick action from notification banner]
[Source: Apple Developer Documentation — UNNotificationDefaultActionIdentifier]

---

### Previous Story Intelligence (Story 2.1)

Key patterns from Story 2.1 that directly impact Story 2.2:

1. **`NotificationService` is `@MainActor`** — `scheduleNotification`, `cancelNotification`, `requestPermissionIfNeeded`, `checkAuthorizationStatus` are all `@MainActor`. The new `registerNotificationCategories()` method follows the same isolation.

2. **`center.add(request)` is fire-and-forget** — The completion handler in `scheduleNotification` runs on a background thread. Never update `@Observable` properties inside it. Story 2.2 does not add to this closure.

3. **Notification identifier format confirmed**: `"task-\(task.id.uuidString)"` — hardcoded, no variation.

4. **`NotificationService.checkAuthorizationStatus()`** exists — can be used in `AppDelegate` to guard routing logic if needed, but the default action tap routing does not require an auth check (notification was already delivered).

5. **`TaskDetailView` navigation** — Story 2.1 confirmed `AppCoordinator.navigateTo(taskID:)` is the correct navigation entry point. Story 2.2 calls this from `AppDelegate`.

6. **`NotificationPermissionView.swift`** created in Story 2.1 at `Features/Notifications/` — Story 2.2 does NOT modify this view; it is unchanged and reserved for Story 7.3 wiring.

7. **No changes to `TaskDetailView`, `TaskDetailViewModel`, `TaskListView`, or any `Task` or `TaskList` model** — Story 2.2 is purely infrastructure (delegate + category registration).

[Source: implementation-artifacts/2-1-set-due-date-and-reminder-time-on-a-task.md]

---

### Git Intelligence

Recent commits:
- `7803b06 Story 1.4 - 2.1` — Epic 1 and Story 2.1 implementation committed together
- `ebf3036 stories 1.2 and 1.3` — Foundation stories

Working tree as of last commit: `TODOApp/TODOApp/Core/Services/NotificationService.swift` is implemented with full scheduling/cancellation/permission logic from Story 2.1. All Epic 1 and Story 2.1 files are committed.

Story 2.2 creates **one new file** (`AppDelegate.swift`) and modifies **two existing files** (`NotificationService.swift` and `TODOAppApp.swift`) plus `project.pbxproj`.

---

### iOS API Notes — UNUserNotificationCenterDelegate

**Setting the delegate:** Must be set before `application(_:didFinishLaunchingWithOptions:)` returns. With `@UIApplicationDelegateAdaptor`, setting `UNUserNotificationCenter.current().delegate = self` in `application(_:didFinishLaunchingWithOptions:)` satisfies this.

**`nonisolated` on delegate methods:** Swift 6 strict concurrency requires that `UNUserNotificationCenterDelegate` methods — which are called by the system on arbitrary threads — be `nonisolated`. The pattern `Task { @MainActor in }` safely dispatches `AppCoordinator` access back to the main actor.

```swift
// Swift 6 correct pattern:
nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    defer { completionHandler() }
    Task { @MainActor in
        // Safe to access @MainActor-isolated coordinator here
        self.coordinator?.navigateTo(taskID: uuid)
    }
}
```

**Foreground presentation options:** `.banner` requires iOS 14+. Since our minimum is iOS 17, this is always available. The combination `[.banner, .sound]` shows the notification as a banner with sound.

**`UNNotificationCategory` registration timing:** Must be called before any notification is delivered (not before scheduling). Calling `setNotificationCategories` in `application(_:didFinishLaunchingWithOptions:)` guarantees this.

[Source: Apple Developer Documentation — UNUserNotificationCenter.delegate, UNNotificationPresentationOptions]
[Source: architecture.md#Core Architectural Decisions — "iOS 17.0 minimum deployment target"]

---

### Project Structure Notes

**Files to CREATE in this story:**
```
TODOApp/TODOApp/AppDelegate.swift                                   ← NEW
TODOApp/TODOAppTests/Features/Notifications/AppDelegateTests.swift  ← NEW (optional, for routing tests)
```

**Files to MODIFY in this story:**
```
TODOApp/TODOApp/TODOAppApp.swift                          ← Add @UIApplicationDelegateAdaptor, pass coordinator to delegate
TODOApp/TODOApp/Core/Services/NotificationService.swift   ← Add registerNotificationCategories(), taskReminderCategoryIdentifier, set content.categoryIdentifier
TODOApp/TODOApp.xcodeproj/project.pbxproj                 ← Register AppDelegate.swift (A500/B500)
```

**Files NOT to touch:**
- `AppCoordinator.swift` — `navigateTo(taskID:)` already implemented (Story 1.2); no changes needed
- `Features/Tasks/TaskDetailView.swift` — navigation target; no changes needed
- `Features/Tasks/TaskDetailViewModel.swift` — no changes needed
- `Core/Models/TaskItem.swift` — no changes needed
- `Core/Repositories/TaskRepository.swift` — no changes needed
- `Features/Notifications/NotificationPermissionView.swift` — reserved for Story 7.3; no changes
- `WidgetService.swift` — no changes needed (notification tap does not trigger widget reload)

**Architecture alignment:**
- `UNUserNotificationCenterDelegate` is implemented in `AppDelegate` — NOT in a View or ViewModel [Source: architecture.md#Process Patterns — Navigation from Notifications]
- Navigation from notification tap routes through `AppCoordinator.navigateTo(taskID:)` — same entry point as URL scheme deep links [Source: architecture.md#Process Patterns]
- `NotificationService` remains the single access point for `UNUserNotificationCenter` scheduling operations [Source: architecture.md#Notification Boundary]
- `AppDelegate` ONLY handles delegate callbacks — it does NOT directly call `UNUserNotificationCenter.add()` or any scheduling logic
- Privacy: never log task title or UUID in user-visible messages [Source: architecture.md#Process Patterns — Logging]

---

### References

- [Source: epics.md#Story 2.2] — Full BDD acceptance criteria (notification delivery, tap routing, background delivery, foreground presentation)
- [Source: epics.md#Epic 2] — "Deliver due date and reminder time setting on tasks, schedule local notifications..."
- [Source: architecture.md#Notification Boundary] — "NotificationService is the single access point for all UNUserNotificationCenter operations"; "Navigation from Notifications: UNNotificationResponse handled in AppDelegate.userNotificationCenter(_:didReceive:)"
- [Source: architecture.md#Process Patterns — Navigation from Notifications] — "Routes via AppCoordinator.navigateTo(taskID:)"
- [Source: architecture.md#Core Architectural Decisions] — Swift 6 strict concurrency, iOS 17+ minimum
- [Source: architecture.md#API & Communication Patterns] — URL scheme `todoapp://open-task?id=<uuid>` pattern; AppCoordinator.navigateTo
- [Source: architecture.md#Enforcement Guidelines] — Never log user content; all mutations through repositories
- [Source: implementation-artifacts/2-1-set-due-date-and-reminder-time-on-a-task.md] — NotificationService full implementation, identifier scheme, @MainActor isolation notes
- [Source: TODOApp/TODOApp/Core/Services/NotificationService.swift] — Current implementation (scheduleNotification, cancelNotification, requestPermissionIfNeeded, checkAuthorizationStatus confirmed present)
- [Source: TODOApp/TODOApp/AppCoordinator.swift] — navigateTo(taskID:) confirmed implemented; handleURL confirms URL scheme routing
- [Source: TODOApp/TODOApp/TODOAppApp.swift] — Current App entry point; @State coordinator; no @UIApplicationDelegateAdaptor yet
- [Source: TODOApp/TODOApp.xcodeproj/project.pbxproj] — Next PBX identifier range: A500+/B500+ for new files

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

### Completion Notes List

- Created `AppDelegate.swift` with `@MainActor final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate` registered via `@UIApplicationDelegateAdaptor` in `TODOAppApp.swift`.
- Delegate sets itself as `UNUserNotificationCenter.current().delegate` in `application(_:didFinishLaunchingWithOptions:)` (before app finishes launching — Apple requirement met).
- Both delegate methods are `nonisolated` per Swift 6 strict concurrency requirements; coordinator access inside `didReceive` uses `Task { @MainActor in }` to safely re-isolate.
- `AppCoordinator` reference passed to `AppDelegate` via `.onAppear` in `TODOAppApp.body` — type-safe direct reference, no notification center indirection needed.
- Added `taskReminderCategoryIdentifier = "TASK_REMINDER"` static constant and `registerNotificationCategories()` to `NotificationService`. `content.categoryIdentifier` now set in `scheduleNotification(for:)`.
- Category registered with `.customDismissAction` option to support Story 2.3's Dismiss quick action.
- Unit tests added: `scheduleNotificationSetsCorrectCategoryIdentifier`, `notificationIdentifierParsingRoundTrip`, `notificationIdentifierParsingRejectsInvalidFormat`, `registerNotificationCategoriesDoesNotCrash` in `NotificationServiceTests.swift`; full `AppDelegateTests.swift` suite for identifier parsing and delegate instantiation.
- All new files registered in `project.pbxproj` (A500/B500 for `AppDelegate.swift`, A501/B501 for `AppDelegateTests.swift`).
- `TODOApp/TODOAppApp.swift` updated: added `@UIApplicationDelegateAdaptor` and `.onAppear` coordinator pass-through.

### File List

- `TODOApp/TODOApp/AppDelegate.swift` (NEW)
- `TODOApp/TODOApp/TODOAppApp.swift` (MODIFIED)
- `TODOApp/TODOApp/Core/Services/NotificationService.swift` (MODIFIED)
- `TODOApp/TODOAppTests/Features/Notifications/NotificationServiceTests.swift` (MODIFIED)
- `TODOApp/TODOAppTests/Features/Notifications/AppDelegateTests.swift` (NEW)
- `TODOApp/TODOApp.xcodeproj/project.pbxproj` (MODIFIED)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (MODIFIED)

## Change Log

- 2026-02-18: Story 2.2 implemented — wired `UNUserNotificationCenterDelegate` via `AppDelegate` (`@UIApplicationDelegateAdaptor`), implemented notification tap routing to `AppCoordinator.navigateTo(taskID:)`, added `TASK_REMINDER` category registration to `NotificationService` for Story 2.3 prep, set `content.categoryIdentifier` in `scheduleNotification`, added unit tests for identifier parsing and category registration.
