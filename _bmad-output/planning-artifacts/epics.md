---
stepsCompleted: ['step-01-validate-prerequisites']
inputDocuments:
  - '_bmad-output/planning-artifacts/prd.md'
  - '_bmad-output/planning-artifacts/architecture.md'
---

# workspace — Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for the iOS TODO App, decomposing the requirements from the PRD and Architecture document into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1: Users can create a new task with a title
FR2: Users can edit the title of an existing task
FR3: Users can delete a task
FR4: Users can mark a task as complete
FR5: Users can mark a completed task as incomplete
FR6: Users can view all tasks in a list
FR7: Users can set a due date on a task
FR8: Users can set a reminder time on a task
FR9: Users can view overdue tasks distinctly from current tasks
FR10: Users can create a custom list
FR11: Users can rename a custom list
FR12: Users can delete a custom list
FR13: Users can move a task from one list to another
FR14: Users can view an Inbox list that receives all newly captured tasks by default
FR15: Users can view tasks filtered by a specific list
FR16: Users can reorder tasks within a list
FR17: The system delivers a local notification at the user-specified reminder time for a task with a due date
FR18: Users can take a "Mark Done" action directly from a notification without opening the app
FR19: Users can dismiss or snooze a task notification from the notification banner
FR20: The system reschedules notifications after the device reconnects following an offline period
FR21: Users can add a Home Screen widget that displays tasks due today
FR22: The widget displays in a small (2×2) size configuration
FR23: The widget displays in a medium (4×2) size configuration
FR24: Users can tap a task in the widget to open it directly in the app
FR25: The widget reflects task completion state changes within 15 minutes
FR26: Users can capture a new task via Siri using a voice phrase
FR27: Users can configure a custom Siri Shortcut phrase for task capture
FR28: Tasks created via Siri are added to the user's Inbox list
FR29: Users can access their tasks on any iOS device signed into the same iCloud account
FR30: Users can create, edit, and complete tasks while offline
FR31: The system syncs offline changes to iCloud when network connectivity is restored
FR32: The system preserves all tasks across app restarts and device reboots
FR33: The system resolves sync conflicts without data loss
FR34: New users can create their first task without creating an account or providing an email
FR35: The app guides new users to add a Home Screen widget after creating their first task
FR36: The app prompts users to enable notifications when they first set a due date
FR37: Users can navigate to a specific task via iOS Spotlight search *(Growth)*
FR38: Users can configure Focus Mode filters to show only relevant lists in the widget *(Growth)*
FR39: Users can access the app via a custom URL scheme for Shortcuts automation
FR40: Users can view the app in light mode
FR41: Users can view the app in dark mode
FR42: The app follows the system appearance setting by default
FR43: Users can view their iCloud sync status

### NonFunctional Requirements

NFR1: App cold launch completes in <400ms on iPhone XS or newer
NFR2: All user actions (task create, complete, list navigation) respond within 100ms
NFR3: iCloud sync round-trip completes within 3 seconds on standard broadband
NFR4: Home Screen widget timeline refreshes within 15 minutes of any task state change
NFR5: Widget tap-to-open deep link launches the app within 200ms
NFR6: Zero task data loss — all tasks survive app crashes, OS terminations, and device reboots
NFR7: Offline-created tasks sync within 60 seconds of network restoration
NFR8: iCloud sync conflicts resolved without deleting or corrupting task data
NFR9: Local notifications fire within 60 seconds of their scheduled time
NFR10: Widget displays accurate task state within 15 minutes of any state change
NFR11: All task data stored in user's private iCloud container — inaccessible to other apps or users
NFR12: No user data transmitted to any third-party server in MVP
NFR13: App includes a complete PrivacyInfo.xcprivacy manifest declaring all data access patterns
NFR14: No analytics, crash reporting, or telemetry SDKs access user task content in MVP
NFR15: App Store privacy nutrition label: "Data Not Collected"
NFR16: All interactive elements support VoiceOver with accurate, descriptive labels
NFR17: Full Dynamic Type support — all text scales with user's preferred font size
NFR18: Color contrast meets WCAG 2.1 AA (4.5:1 normal text, 3:1 large text)
NFR19: Reduce Motion setting suppresses all animations
NFR20: All task actions operable without multi-finger gestures
NFR21: Siri Shortcuts respond within 2 seconds of voice phrase completion
NFR22: App Intents appear in the Shortcuts app within 24 hours of install
NFR23: WidgetKit timeline provides entries for at least the next 24 hours on each refresh
NFR24: CloudKit operations run on background threads — never block the main thread
NFR25: Local notification scheduling survives app backgrounding and device relock

### Additional Requirements

- **Starter Template**: Architecture specifies Xcode New Project → App (SwiftUI + SwiftData + CloudKit). First implementation story must create this Xcode project from the template.
- Swift 6 strict concurrency (`-strict-concurrency=complete`) required across all targets
- iOS 17.0 minimum deployment target; arm64; Xcode 16
- SwiftData with CloudKit mirroring via `ModelConfiguration(cloudKitContainerIdentifier:)`
- Five targets required: main app target, WidgetKit extension, App Intents extension, unit test target, UI test target
- App Group (`group.com.<team>.todoapp`) must be configured before widget and App Intents targets can share ModelContainer — Day 1 Xcode configuration step
- MVVM + `@Observable` + `@MainActor` pattern for all ViewModels
- `@Query` macro for reactive list display in views (never `fetch()` in `onAppear`)
- Feature-folder project organization (`Features/Tasks/`, `Features/Lists/`, `Features/Notifications/`, `Features/Onboarding/`, `Features/Settings/`)
- All CloudKit / SwiftData writes through `TaskRepository` or `ListRepository` protocols
- Mandatory post-mutation side effects after every task state change: `WidgetService.shared.reloadTimelines()` + `NotificationService` reschedule/cancel
- `NotificationService` singleton is the single access point for all `UNUserNotificationCenter` operations
- `AppCoordinator` handles `NavigationStack` routing and deep link (`onOpenURL`) handling
- URL scheme: `todoapp://` with routes `todoapp://create-task` and `todoapp://open-task?id=<uuid>`
- `PrivacyInfo.xcprivacy` must be included in app bundle root declaring "Data Not Collected"
- Required entitlements: `com.apple.developer.icloud-services` (CloudKit), `com.apple.developer.siri`, push notifications (local)
- `os_log` / `Logger` for logging — never log task titles or list names (privacy)
- `AppStorageKeys.swift` constants file to prevent key typo conflicts across agents
- `AppConstants.swift` for bundle identifier, iCloud container identifier, App Group identifier
- No third-party dependencies in MVP
- Inbox is a query filter (`task.list == nil`), not a `TaskList` model row
- `isCompleted` conflict resolution is additive: once `true`, never reverted via sync; only explicit user action can set back to `false`
- All animations conditioned on `@Environment(\.accessibilityReduceMotion)`
- XCTest + Swift Testing for unit/integration tests; XCUITest for UI automation

### FR Coverage Map

| FR | Epic | Story |
|---|---|---|
| FR1 | Epic 1 | Story 1.3 |
| FR2 | Epic 1 | Story 1.4 |
| FR3 | Epic 1 | Story 1.5 |
| FR4 | Epic 1 | Story 1.6 |
| FR5 | Epic 1 | Story 1.7 |
| FR6 | Epic 1 | Story 1.3 |
| FR7 | Epic 2 | Story 2.1 |
| FR8 | Epic 2 | Story 2.1 |
| FR9 | Epic 1 | Story 1.3 |
| FR10 | Epic 3 | Story 3.1 |
| FR11 | Epic 3 | Story 3.2 |
| FR12 | Epic 3 | Story 3.3 |
| FR13 | Epic 3 | Story 3.4 |
| FR14 | Epic 1 | Story 1.3 |
| FR15 | Epic 3 | Story 3.1 |
| FR16 | Epic 3 | Story 3.5 |
| FR17 | Epic 2 | Story 2.2 |
| FR18 | Epic 2 | Story 2.3 |
| FR19 | Epic 2 | Story 2.3 |
| FR20 | Epic 2 | Story 2.4 |
| FR21 | Epic 5 | Story 5.1 |
| FR22 | Epic 5 | Story 5.1 |
| FR23 | Epic 5 | Story 5.1 |
| FR24 | Epic 5 | Story 5.2 |
| FR25 | Epic 5 | Story 5.3 |
| FR26 | Epic 6 | Story 6.1 |
| FR27 | Epic 6 | Story 6.2 |
| FR28 | Epic 6 | Story 6.1 |
| FR29 | Epic 4 | Story 4.2 |
| FR30 | Epic 4 | Story 4.1 |
| FR31 | Epic 4 | Story 4.1 |
| FR32 | Epic 4 | Story 4.1 |
| FR33 | Epic 4 | Story 4.2 |
| FR34 | Epic 7 | Story 7.1 |
| FR35 | Epic 7 | Story 7.2 |
| FR36 | Epic 7 | Story 7.3 |
| FR37 | Deferred (Growth) | — |
| FR38 | Deferred (Growth) | — |
| FR39 | Epic 1 | Story 1.2 |
| FR40 | Epic 8 | Story 8.1 |
| FR41 | Epic 8 | Story 8.1 |
| FR42 | Epic 8 | Story 8.1 |
| FR43 | Epic 8 | Story 8.2 |

## Epic List

- **Epic 1**: Project Foundation & Core Task CRUD
- **Epic 2**: Due Dates, Reminders & Notifications
- **Epic 3**: List Organization
- **Epic 4**: Offline-First Persistence & iCloud Sync
- **Epic 5**: Home Screen Widget
- **Epic 6**: Siri & Voice Capture (App Intents)
- **Epic 7**: First-Launch Onboarding
- **Epic 8**: Appearance, Settings & App Store Readiness

---

## Epic 1: Project Foundation & Core Task CRUD

Establish the Xcode project scaffold with all required targets, configure SwiftData + CloudKit, implement the core data models and repositories, wire up the navigation shell, and deliver full task CRUD with Inbox display — so a developer has a running app where tasks can be created, viewed, edited, deleted, and marked complete/incomplete from day one.

### Story 1.1: Xcode Project Initialization & Target Configuration

As a developer,
I want a fully configured Xcode project with all required targets and capabilities,
So that I have a clean, compilable foundation before writing any feature code.

**Acceptance Criteria:**

**Given** a developer opens Xcode 16
**When** they follow the initialization steps
**Then** an Xcode project named `TODOApp` exists with:
- Product name: `TODOApp`
- Bundle identifier: `com.<team>.todoapp`
- Interface: SwiftUI
- Language: Swift
- SwiftData checkbox enabled
- iOS 17.0 deployment target
- arm64 architecture
**And** the project compiles and runs on a simulator without errors

**Given** the base project exists
**When** the developer adds extension targets
**Then** the following targets exist in the project:
- `TODOApp` (main app target)
- `TODOAppWidgetExtension` (WidgetKit extension)
- `TODOAppIntents` (App Intents extension)
- `TODOAppTests` (unit/integration test target)
- `TODOAppUITests` (XCUITest target)
**And** all targets have iOS 17.0 deployment target

**Given** the targets are created
**When** the developer configures capabilities
**Then** the main app target has the following capabilities enabled:
- iCloud with CloudKit container `iCloud.com.<team>.todoapp`
- Siri
- Push Notifications
**And** the App Group `group.com.<team>.todoapp` is added to the main app, widget, and App Intents targets
**And** `TODOApp.entitlements` contains the correct entitlement keys

**Given** the App Group is configured
**When** the developer adds Swift 6 concurrency settings
**Then** `SWIFT_STRICT_CONCURRENCY = complete` is set in the project build settings
**And** the project compiles with zero concurrency warnings/errors

**Given** the project builds successfully
**When** the developer adds the privacy manifest
**Then** `PrivacyInfo.xcprivacy` exists in the app bundle root
**And** it declares "Data Not Collected" for all data types
**And** App Store Connect privacy nutrition label is pre-configured as "Data Not Collected"

### Story 1.2: Core Constants, App Entry Point & Navigation Shell

As a developer,
I want the app entry point, core constants, and navigation shell implemented,
So that the app launches with a working NavigationStack and deep link routing foundation.

**Acceptance Criteria:**

**Given** the project is initialized
**When** the developer creates core constant files
**Then** `Core/Utilities/AppStorageKeys.swift` exists with string constants for all `@AppStorage` keys:
- `AppStorageKeys.hasCompletedOnboarding`
- `AppStorageKeys.selectedListID`
**And** `Core/Utilities/AppConstants.swift` exists with:
- `AppConstants.bundleIdentifier`
- `AppConstants.iCloudContainerIdentifier` (`iCloud.com.<team>.todoapp`)
- `AppConstants.appGroupIdentifier` (`group.com.<team>.todoapp`)
- `AppConstants.urlScheme` (`todoapp`)
**And** `Core/Utilities/Logger+App.swift` exists with `Logger` category constants (never logs user content)

**Given** the constants exist
**When** the developer implements `TODOAppApp.swift`
**Then** the `@main` App struct:
- Configures a `ModelContainer` with `TaskItem` and `TaskList` models
- Enables CloudKit mirroring via `ModelConfiguration(cloudKitContainerIdentifier: AppConstants.iCloudContainerIdentifier)`
- Injects the container via `.modelContainer()` on the root scene
- Instantiates `AppCoordinator` as an `@Observable` class owned by the App struct
**And** the app launches without crashing on a simulator

**Given** the app entry point is wired
**When** the developer implements `AppCoordinator.swift`
**Then** `AppCoordinator` is an `@Observable` `@MainActor` class that:
- Owns a `NavigationPath` for programmatic navigation
- Exposes `navigateTo(taskID: UUID)` method
- Handles `todoapp://create-task` URL scheme (opens add task sheet)
- Handles `todoapp://open-task?id=<uuid>` URL scheme (navigates to task detail)
**And** the App struct registers `.onOpenURL` forwarding to `AppCoordinator`

**Given** the coordinator exists
**When** the app launches
**Then** a `NavigationStack` is presented at the root using `NavigationPath` from `AppCoordinator`
**And** the app displays a placeholder content view (replaced in Story 1.3)
**And** the URL scheme `todoapp://` is registered in `Info.plist`

### Story 1.3: SwiftData Models, Repositories & Inbox Task List View

As a developer,
I want the data models, repository protocols/implementations, and Inbox task list view implemented,
So that users can see their tasks in the Inbox and the persistence layer is fully wired.

**Acceptance Criteria:**

**Given** the project foundation exists
**When** the developer implements `Core/Models/TaskItem.swift`
**Then** `TaskItem` is a `@Model final class` with:
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

**Given** the models exist
**When** the developer implements repositories
**Then** `Core/Repositories/TaskRepositoryProtocol.swift` defines:
- `fetchTasks(in list: TaskList?) async throws -> [TaskItem]`
- `createTask(title: String, listID: UUID?) async throws -> TaskItem`
- `updateTask(_ task: TaskItem) async throws`
- `deleteTask(_ task: TaskItem) async throws`
- `completeTask(_ task: TaskItem) async throws`
**And** `Core/Repositories/TaskRepository.swift` implements the protocol using a background `ModelContext`
**And** `Core/Repositories/ListRepositoryProtocol.swift` and `ListRepository.swift` follow the same pattern
**And** repositories never operate on `@MainActor`; they receive an injected background `ModelContext`

**Given** repositories exist
**When** the developer implements the task list view
**Then** `Features/Tasks/TaskListView.swift` uses `@Query` to reactively display tasks
**And** the Inbox displays tasks where `task.list == nil`
**And** overdue tasks (dueDate < now, isCompleted == false) are visually distinct (e.g., red due date label)
**And** `Features/Tasks/TaskListViewModel.swift` is `@Observable @MainActor`
**And** `Features/Tasks/TaskRowView.swift` displays task title, due date (if set), and completion indicator

**Given** the task list view is implemented
**When** the app launches on a simulator
**Then** the Inbox view appears with empty state (no tasks yet)
**And** all VoiceOver accessibility labels on interactive elements are present and descriptive (NFR16)
**And** all text uses Dynamic Type styles (NFR17)

### Story 1.4: Add Task & Edit Task

As an iPhone user,
I want to quickly add a new task and edit its title,
So that I can capture what I need to do and correct mistakes.

**Acceptance Criteria:**

**Given** the user is on the task list
**When** they tap the "+" button
**Then** `Features/Tasks/AddTaskView.swift` appears as a sheet
**And** the text field is focused automatically
**And** the keyboard appears without delay

**Given** the Add Task sheet is open
**When** the user types a title and confirms
**Then** `TaskListViewModel.createTask(title:listID:)` is called
**And** `TaskRepository.createTask(title:listID:)` saves the task to SwiftData on a background context
**And** `WidgetService.shared.reloadTimelines()` is called immediately after the save
**And** `NotificationService` is checked (no reminder yet — no scheduling needed)
**And** the sheet dismisses and the new task appears in the list

**Given** the user has tasks in the list
**When** they tap a task row
**Then** `Features/Tasks/TaskDetailView.swift` is pushed onto the `NavigationStack`
**And** the task title is editable inline
**And** changes are committed on `onSubmit` or view disappear via `TaskDetailViewModel`

**Given** the user edits a title
**When** the title field loses focus or the user navigates back
**Then** `TaskRepository.updateTask(_:)` is called with the updated title and `modifiedAt = Date()`
**And** `WidgetService.shared.reloadTimelines()` is called
**And** the updated title appears in the task list immediately

**Given** invalid input (empty title)
**When** the user tries to save
**Then** the save is blocked and an inline error hint is shown
**And** no empty-title tasks are persisted

**Given** any task mutation occurs
**When** the operation completes or fails
**Then** errors are caught by the ViewModel, logged privately via `Logger` (no task content), and shown as a generic "Something went wrong" banner
**And** the UI never displays raw error messages

### Story 1.5: Delete Task

As an iPhone user,
I want to delete a task I no longer need,
So that my task list stays clean and relevant.

**Acceptance Criteria:**

**Given** the user is viewing the task list
**When** they swipe left on a task row
**Then** a destructive "Delete" action appears in the swipe actions

**Given** the delete swipe action is visible
**When** the user taps "Delete"
**Then** `TaskRepository.deleteTask(_:)` is called on a background context
**And** any pending `UNUserNotificationCenter` notification for this task is cancelled via `NotificationService`
**And** `WidgetService.shared.reloadTimelines()` is called
**And** the task row is removed from the list with an animation

**Given** a task in a custom list is deleted
**When** the deletion completes
**Then** the `TaskList` is not affected (only the task is removed, not the list)

**Given** the user is in task detail view
**When** they tap a delete button/action
**Then** the same deletion flow executes and the user is navigated back to the list

### Story 1.6: Complete Task

As an iPhone user,
I want to mark a task as complete with a satisfying interaction,
So that I feel rewarded for finishing something.

**Acceptance Criteria:**

**Given** the user sees an incomplete task in the list
**When** they tap the completion circle/button on the task row
**Then** `TaskRepository.completeTask(_:)` is called setting `isCompleted = true` and `modifiedAt = Date()`
**And** a checkmark scale + opacity spring animation plays on the row (conditioned on `@Environment(\.accessibilityReduceMotion)` — no animation if Reduce Motion is on)
**And** `NotificationService` cancels any pending reminder for this task
**And** `WidgetService.shared.reloadTimelines()` is called
**And** the task visually transitions to a completed state (strikethrough title, muted color)

**Given** a completed task is visible
**When** the list shows completed tasks
**Then** completed tasks are visually distinct from incomplete tasks

**Given** the Reduce Motion accessibility setting is enabled
**When** a task is completed
**Then** no animation plays — the state change is instant

### Story 1.7: Uncomplete Task

As an iPhone user,
I want to mark a completed task back to incomplete,
So that I can reopen tasks that weren't actually finished.

**Acceptance Criteria:**

**Given** a completed task is visible in the list
**When** the user taps the completed indicator
**Then** `isCompleted` is set to `false` and `modifiedAt = Date()` via `TaskRepository.updateTask(_:)`
**And** `WidgetService.shared.reloadTimelines()` is called
**And** the task moves back to the incomplete visual state

**Given** a task is uncompleted locally
**When** iCloud sync runs on another device
**Then** the conflict resolution rule is applied: `isCompleted` is additive — sync will not re-complete the task; only local user action sets it back to `false`

---

## Epic 2: Due Dates, Reminders & Notifications

Deliver due date and reminder time setting on tasks, schedule local notifications, support "Mark Done" from the notification banner, handle notification dismissal/snooze, and reschedule notifications after offline recovery — fulfilling the top retention driver identified in the PRD.

### Story 2.1: Set Due Date & Reminder Time on a Task

As an iPhone user,
I want to set a due date and reminder time on a task,
So that I'm notified at the right moment to act.

**Acceptance Criteria:**

**Given** the user is in `TaskDetailView`
**When** they tap "Add Due Date"
**Then** a `DatePicker` is shown for selecting a due date
**And** after selecting a date, an optional "Add Reminder" row appears
**And** the due date is displayed in the task detail and in the task row (FR7)

**Given** the user taps "Add Reminder"
**When** they select a reminder time
**Then** the `reminderDate` is stored on `TaskItem` via `TaskRepository.updateTask(_:)`
**And** `NotificationService.scheduleNotification(for: task)` is called immediately after the save
**And** `WidgetService.shared.reloadTimelines()` is called (FR8)

**Given** the user changes or removes a due date
**When** the update is saved
**Then** the existing notification (if any) is cancelled via `NotificationService`
**And** a new notification is scheduled if a reminder date is still present

**Given** the notification permission has not been granted
**When** the user sets their first reminder
**Then** `NotificationService` triggers the system permission prompt (FR36)
**And** if permission is denied, the task still saves with its reminder date but no notification is scheduled
**And** a subtle UI hint indicates that notifications are disabled (graceful degradation)

### Story 2.2: Local Notification Delivery

As an iPhone user,
I want to receive a local notification when my reminder fires,
So that I'm prompted to act on the task at the right time.

**Acceptance Criteria:**

**Given** a task has a `reminderDate` set and notification permission is granted
**When** the `reminderDate` arrives
**Then** a local notification fires via `UNUserNotificationCenter` (NFR9 — within 60 seconds of scheduled time)
**And** the notification title is the task title
**And** the notification body references the due date
**And** the notification includes the notification identifier `"task-\(task.id.uuidString)"`

**Given** the notification fires
**When** the user taps the notification body
**Then** the app opens to `TaskDetailView` for that task via `AppCoordinator.navigateTo(taskID:)` (FR24 deep link pattern)

**Given** the device is locked or the app is backgrounded
**When** the reminder fires
**Then** the notification still appears on the lock screen and notification banner (NFR25)

### Story 2.3: "Mark Done" & Dismiss from Notification Banner

As an iPhone user,
I want to complete or dismiss a task directly from the notification banner,
So that I don't have to open the app for simple actions.

**Acceptance Criteria:**

**Given** a task notification appears in the banner
**When** the user long-presses or expands the notification
**Then** a "Mark Done" quick action button is visible (FR18)
**And** a "Dismiss" action is visible (FR19)

**Given** the user taps "Mark Done" from the notification
**When** the action is processed by `UNNotificationResponse` in `AppDelegate`
**Then** `TaskRepository.completeTask(_:)` is called on a background `ModelContext`
**And** `WidgetService.shared.reloadTimelines()` is called
**And** the notification is removed from Notification Center
**And** the task appears as completed the next time the app is opened

**Given** the user taps "Dismiss"
**When** the action is processed
**Then** the notification is dismissed without changing the task's completion state

### Story 2.4: Reschedule Notifications After Offline Recovery

As an iPhone user,
I want reminders to fire correctly after my device was offline,
So that I never miss a task notification due to connectivity issues.

**Acceptance Criteria:**

**Given** the device was offline and reconnects
**When** the network is restored
**Then** `NotificationService` reschedules any pending notifications for tasks whose `reminderDate` is in the future (FR20)
**And** tasks with a `reminderDate` in the past that were not completed while offline surface as overdue (FR9 visual distinction)

**Given** a task had its reminder fire while the device was offline
**When** the device comes back online
**Then** the notification fires within 60 seconds of reconnection (NFR7 — offline sync within 60 seconds)

---

## Epic 3: List Organization

Deliver full list management — create, rename, delete custom lists, move tasks between lists, filter task view by list, and reorder tasks within a list — enabling the power-organizer user journey.

### Story 3.1: Create Custom List & Filter by List

As an iPhone user,
I want to create custom lists and view tasks filtered by list,
So that I can organize my tasks by project or context.

**Acceptance Criteria:**

**Given** the user is in the sidebar or main navigation
**When** they tap "New List"
**Then** `Features/Lists/AddListView.swift` appears as a sheet
**And** the user can enter a list name and choose an accent color (from `ListColorPicker`)
**And** on confirmation, `ListRepository.createList(name:colorHex:)` is called on a background context
**And** the new list appears in `Features/Lists/ListSidebarView.swift` (FR10)

**Given** custom lists exist in the sidebar
**When** the user taps a list
**Then** `TaskListView` filters to show only tasks belonging to that list via a `@Query` predicate
**And** the Inbox entry always shows tasks where `task.list == nil` (FR14, FR15)

**Given** any list is selected
**When** the user adds a new task from that context
**Then** the task is automatically assigned to that list (not Inbox)

### Story 3.2: Rename a Custom List

As an iPhone user,
I want to rename a custom list,
So that I can keep my organization current as my projects evolve.

**Acceptance Criteria:**

**Given** a custom list exists
**When** the user long-presses or swipes to reveal an "Edit" action on the list row
**Then** `Features/Lists/EditListView.swift` appears with the current name pre-filled

**Given** the edit sheet is open
**When** the user changes the name and confirms
**Then** `ListRepository` updates the list's `name` and `modifiedAt` via `updateList(_:)`
**And** the updated name appears in the sidebar immediately
**And** `WidgetService.shared.reloadTimelines()` is called (FR11)

**Given** the user clears the name field
**When** they try to confirm
**Then** the rename is blocked and an inline validation message is shown

### Story 3.3: Delete a Custom List

As an iPhone user,
I want to delete a custom list I no longer need,
So that my sidebar stays uncluttered.

**Acceptance Criteria:**

**Given** a custom list exists in the sidebar
**When** the user swipes left on the list row and taps "Delete"
**Then** a confirmation alert appears: "Delete '[list name]'? All tasks in this list will also be deleted."

**Given** the user confirms deletion
**When** the deletion executes
**Then** `ListRepository.deleteList(_:)` is called, which cascades to delete all `TaskItem` records in that list (cascade delete rule on the relationship)
**And** all pending notifications for deleted tasks are cancelled via `NotificationService`
**And** `WidgetService.shared.reloadTimelines()` is called
**And** the list disappears from the sidebar (FR12)

**Given** the user cancels the deletion alert
**When** they tap "Cancel"
**Then** nothing is deleted

### Story 3.4: Move a Task to a Different List

As an iPhone user,
I want to move a task from one list to another (or to Inbox),
So that I can reorganize tasks without deleting and recreating them.

**Acceptance Criteria:**

**Given** the user is in `TaskDetailView`
**When** they tap a "Move to List" control
**Then** a picker/sheet lists all available lists plus "Inbox"

**Given** the user selects a target list (or Inbox)
**When** the move is confirmed
**Then** `task.list` is updated to the selected `TaskList` (or `nil` for Inbox) via `TaskRepository.updateTask(_:)`
**And** `WidgetService.shared.reloadTimelines()` is called
**And** the task disappears from its previous list view and appears in the new one (FR13)

### Story 3.5: Reorder Tasks Within a List

As an iPhone user,
I want to manually reorder tasks within a list,
So that I can prioritize what to work on next.

**Acceptance Criteria:**

**Given** a list with multiple tasks is displayed
**When** the user activates edit mode or uses drag-to-reorder handles
**Then** tasks can be dragged to new positions within the list

**Given** the user drops a task in a new position
**When** the reorder completes
**Then** `sortOrder` values are updated for all affected tasks via `TaskRepository.updateTask(_:)` calls
**And** `WidgetService.shared.reloadTimelines()` is called
**And** the order persists after app restart and across iCloud sync (FR16)

---

## Epic 4: Offline-First Persistence & iCloud Sync

Guarantee that tasks are always stored locally first (fully functional without network), sync transparently to iCloud via CloudKit, and resolve conflicts without data loss — making the app trustworthy for users in low-connectivity environments.

### Story 4.1: Offline-First Local Persistence

As an iPhone user,
I want the app to work fully without an internet connection,
So that I can capture and manage tasks anywhere, even on job sites or in the subway.

**Acceptance Criteria:**

**Given** the device has no network connection
**When** the user creates, edits, completes, or deletes a task
**Then** all operations succeed immediately using the local SwiftData SQLite store (FR30)
**And** no network spinner, error state, or "sync failed" message appears
**And** UI response time is within 100ms (NFR2)

**Given** the device was offline and tasks were created
**When** network connectivity is restored
**Then** CloudKit sync begins automatically in the background (FR31)
**And** changes sync within 60 seconds of reconnection (NFR7)
**And** no user action is required to trigger sync

**Given** the app is force-quit or the device is rebooted
**When** the app is next launched
**Then** all tasks are present exactly as they were before the restart (FR32 — NFR6 zero data loss)

**Given** the app is in the background
**When** CloudKit delivers a push notification of remote changes
**Then** the ModelContainer processes the changes in the background
**And** the UI reflects the changes on next foreground via `@Query` reactive binding

### Story 4.2: iCloud Multi-Device Sync & Conflict Resolution

As an iPhone user,
I want my tasks to appear on all my iOS devices signed into the same iCloud account,
So that I always have my full task list available regardless of which device I'm using.

**Acceptance Criteria:**

**Given** two devices share the same iCloud account
**When** a task is created on Device A
**Then** the task appears on Device B within 3 seconds on a standard broadband connection (NFR3) (FR29)

**Given** the same task is edited on two devices while one is offline
**When** both devices sync
**Then** the conflict is resolved by last-write-wins on `title`, `dueDate`, `reminderDate`, `sortOrder`, `colorHex` — determined by `modifiedAt` timestamp (FR33)
**And** `isCompleted` uses additive resolution: if either device set it `true`, it stays `true` after sync (NFR8)
**And** no task data is lost or corrupted

**Given** iCloud account is not signed in on the device
**When** the app launches
**Then** the app functions normally using local SwiftData only
**And** sync status in Settings indicates iCloud is unavailable (FR43)

---

## Epic 5: Home Screen Widget

Deliver small (2×2) and medium (4×2) Home Screen widgets that display today's tasks, support tap-to-open deep linking, and refresh within 15 minutes of any task state change — the primary iOS-native differentiator.

### Story 5.1: Widget Extension Target & Small/Medium Widget Display

As an iPhone user,
I want a Home Screen widget that shows my tasks due today,
So that I can see what's on my plate without opening the app.

**Acceptance Criteria:**

**Given** the `TODOAppWidgetExtension` target is configured with the shared App Group
**When** the `TaskWidgetProvider` (TimelineProvider) is implemented
**Then** it reads tasks from the shared SwiftData store via a read-only `ModelContainer` using the App Group
**And** the provider generates timeline entries for the next 24 hours minimum (NFR23)
**And** the refresh policy is set to `.after(Date().addingTimeInterval(15 * 60))` (NFR4)

**Given** the TimelineProvider generates entries
**When** the user adds the widget to their Home Screen
**Then** a small (2×2) widget (`WidgetFamily.systemSmall`) appears showing tasks due today (FR22)
**And** a medium (4×2) widget (`WidgetFamily.systemMedium`) appears showing more tasks (FR23) (FR21)
**And** `TODOAppWidgetBundle.swift` registers both sizes

**Given** no tasks are due today
**When** the widget renders
**Then** an empty state message is shown (e.g., "Nothing due today")

**Given** tasks are due today
**When** the widget renders
**Then** task titles are shown with their completion status
**And** all widget elements have VoiceOver accessibility labels (NFR16)
**And** text uses Dynamic Type where supported by WidgetKit (NFR17)

### Story 5.2: Widget Tap-to-Open Deep Link

As an iPhone user,
I want to tap a task in the widget to open it in the app,
So that I can quickly act on a specific task from my Home Screen.

**Acceptance Criteria:**

**Given** the widget is displaying tasks
**When** the user taps a specific task row in the widget
**Then** a `Link(destination: URL(string: "todoapp://open-task?id=\(task.id.uuidString)"))` deep link is activated (FR24)
**And** the app opens to `TaskDetailView` for that task via `AppCoordinator`
**And** the app launches within 200ms of the tap (NFR5)

**Given** the user taps the widget background (not a specific task)
**When** the app opens
**Then** it opens to the Inbox or main task list (default behavior)

### Story 5.3: Widget Timeline Refresh on Task State Change

As an iPhone user,
I want the widget to reflect my latest task state,
So that my Home Screen always shows accurate information.

**Acceptance Criteria:**

**Given** a task is created, edited, completed, or deleted in the app
**When** the mutation is saved to SwiftData
**Then** `WidgetService.shared.reloadTimelines()` (which calls `WidgetCenter.shared.reloadAllTimelines()`) is called immediately (FR25)
**And** this call happens after every task mutation — no exceptions (mandatory post-mutation side effect)

**Given** `reloadAllTimelines()` is called
**When** the system processes the reload request
**Then** the widget reflects the updated task state within 15 minutes (NFR4 / NFR10)

**Given** a task's `reminderDate` passes
**When** the widget timeline's natural refresh interval is reached
**Then** the widget updates to reflect that the task is now overdue (based on pre-generated timeline entries)

---

## Epic 6: Siri & Voice Capture (App Intents)

Implement the App Intents extension to enable Siri voice task capture, support custom Siri Shortcut phrases, and route created tasks to the Inbox — the second primary iOS-native differentiator.

### Story 6.1: Siri Task Capture via App Intents

As an iPhone user,
I want to create a task by speaking to Siri,
So that I can capture tasks hands-free in under 5 seconds.

**Acceptance Criteria:**

**Given** the `TODOAppIntents` extension target is configured with the shared App Group
**When** `CreateTaskIntent.swift` is implemented
**Then** it conforms to `AppIntent` with:
- `title` parameter for the task title (String)
- `perform()` method that creates a `TaskItem` via a background `ModelContext` from the shared `ModelContainer`
- Returns an `IntentResultValue` confirmation string (e.g., "Added '[title]' to your Inbox")
**And** the created task has `list = nil` (goes to Inbox) (FR28)
**And** `WidgetCenter.shared.reloadAllTimelines()` is called after the task is created

**Given** Siri is invoked with a task capture phrase
**When** the App Intent processes the request
**Then** the response returns within 2 seconds (NFR21)
**And** the App Intent appears in the Shortcuts app within 24 hours of install (NFR22)
**And** Siri's response uses the confirmation string (never exposes raw errors) (FR26)

**Given** the task is created via Siri
**When** the user opens the app
**Then** the task appears in the Inbox with the title spoken to Siri

### Story 6.2: Custom Siri Shortcut Phrase

As an iPhone user,
I want to configure a custom Siri phrase for task capture,
So that I can use a phrase that feels natural to me.

**Acceptance Criteria:**

**Given** the App Intent is implemented
**When** the user opens Settings → Siri & Search (iOS system settings) or the Shortcuts app
**Then** the "Create Task" App Intent is listed and available for shortcut customization (FR27)

**Given** the user adds the App Intent to Shortcuts with a custom phrase
**When** they invoke the custom phrase via Siri
**Then** `CreateTaskIntent.perform()` executes with the provided title parameter
**And** the same Inbox routing and widget reload side effect apply

---

## Epic 7: First-Launch Onboarding

Deliver a frictionless first-launch experience — no account creation, zero-friction first task, widget nudge, and notification permission prompt — converting casual downloaders into retained users.

### Story 7.1: Zero-Friction First Launch & First Task Creation

As a new iPhone user,
I want to create my first task immediately without any signup or account setup,
So that I get value from the app in under 60 seconds.

**Acceptance Criteria:**

**Given** the app is launched for the first time (`hasCompletedOnboarding == false`)
**When** `OnboardingView.swift` is presented
**Then** no account creation, email, or login is required (FR34)
**And** the first screen shows a prompt like "What do you want to get done today?" with a pre-focused text field
**And** the user can type a task and confirm immediately

**Given** the user confirms their first task
**When** the task is saved via `OnboardingViewModel`
**Then** `TaskRepository.createTask(title:listID:nil)` creates the task in the Inbox
**And** `@AppStorage(AppStorageKeys.hasCompletedOnboarding)` is set to `true`
**And** the user transitions to the main `TaskListView` (Inbox) with the task visible
**And** `WidgetService.shared.reloadTimelines()` is called

**Given** the first task was created in under 60 seconds
**When** measured from app open to task visible in list
**Then** the success criterion from the PRD is met (first task within 60 seconds of install)

### Story 7.2: Widget Nudge After First Task

As a new iPhone user,
I want to be guided toward adding the Home Screen widget after my first task,
So that I discover the app's native iOS integration immediately.

**Acceptance Criteria:**

**Given** the user has just created their first task (onboarding complete)
**When** the Inbox appears for the first time
**Then** `WidgetOnboardingNudgeView.swift` surfaces a contextual tip: "Add a widget to see your tasks on your Home Screen" (FR35)

**Given** the nudge is displayed
**When** the user taps "Show Me How"
**Then** the system widget gallery is opened (if possible via `UIApplication.shared.open` to Widgetkit system URL) or instructions are shown
**And** the nudge is dismissible and only shown once (`@AppStorage` flag)

**Given** the user dismisses the nudge
**When** the app is reopened
**Then** the nudge is not shown again

### Story 7.3: Notification Permission Prompt at First Reminder

As a new iPhone user,
I want the app to ask for notification permission when I set my first reminder,
So that the permission request feels contextual and relevant.

**Acceptance Criteria:**

**Given** the user sets a `reminderDate` on a task for the first time
**When** `NotificationService.scheduleNotification(for:)` is called
**Then** `UNUserNotificationCenter.requestAuthorization(options:)` is invoked if authorization status is `.notDetermined` (FR36)
**And** `NotificationPermissionView.swift` provides a pre-prompt explanation before the system dialog: "Enable notifications to get reminders when tasks are due"

**Given** the user grants notification permission
**When** the permission is granted
**Then** the notification is scheduled immediately
**And** a success indicator is shown

**Given** the user denies notification permission
**When** the denial occurs
**Then** the task still saves with the reminder date
**And** a non-intrusive hint shows: "Notifications are disabled. Enable them in Settings to receive reminders."
**And** the app never shows the system prompt again (iOS blocks re-prompting)

---

## Epic 8: Appearance, Settings & App Store Readiness

Deliver light/dark mode support following system appearance, an iCloud sync status view in Settings, and complete all App Store submission requirements — ensuring the app passes first-submission review.

### Story 8.1: Light/Dark Mode & System Appearance

As an iPhone user,
I want the app to look great in both light and dark mode and follow my system preference,
So that the app feels native to my device at all times.

**Acceptance Criteria:**

**Given** the device is in light mode
**When** the app is open
**Then** the app displays in light mode using semantic SwiftUI colors and system color assets (FR40)

**Given** the device is in dark mode
**When** the app is open
**Then** the app displays in dark mode with appropriate contrast (FR41, NFR18 — WCAG 2.1 AA)

**Given** no explicit appearance override is set in the app
**When** the system appearance changes
**Then** the app transitions to the new mode immediately following the system setting (FR42)
**And** `Assets.xcassets/Colors/` contains semantic color assets for all custom colors with light/dark variants

**Given** the app uses Dynamic Type
**When** the user increases their font size in iOS Settings
**Then** all text in the app scales appropriately without truncation or layout breaks (NFR17)

### Story 8.2: Settings View & iCloud Sync Status

As an iPhone user,
I want to view my iCloud sync status in the app,
So that I can confirm my tasks are being backed up and synced.

**Acceptance Criteria:**

**Given** the user navigates to `Features/Settings/SettingsView.swift`
**When** iCloud is signed in and CloudKit is operational
**Then** a "Synced with iCloud" status indicator is shown with the last sync time (FR43)

**Given** iCloud is not signed in or CloudKit is unavailable
**When** the user views Settings
**Then** a "iCloud Sync Unavailable" status is shown with a brief explanation
**And** no error codes or technical details are exposed to the user

**Given** the settings view is open
**When** the user views it
**Then** `SettingsViewModel` fetches the CloudKit account status via `CKContainer.accountStatus(completionHandler:)` on a background thread (NFR24)
**And** the UI is updated on `@MainActor` with the result

### Story 8.3: Accessibility Audit & App Store Submission Readiness

As a developer,
I want to confirm the app meets all accessibility and App Store requirements,
So that it passes App Store review on the first submission and reaches users with disabilities.

**Acceptance Criteria:**

**Given** the full app is implemented
**When** an accessibility audit is run using Xcode Accessibility Inspector
**Then** all interactive elements have VoiceOver labels that accurately describe their purpose (NFR16)
**And** all text uses Dynamic Type styles (`Font.body`, `.headline`, etc. — no hardcoded sizes) (NFR17)
**And** color contrast for all text meets WCAG 2.1 AA (4.5:1 normal, 3:1 large) (NFR18)
**And** all task actions (create, complete, delete) are operable with a single tap — no multi-finger gestures required (NFR20)
**And** `@Environment(\.accessibilityReduceMotion)` is checked before all animations (NFR19)

**Given** the accessibility audit passes
**When** the App Store submission checklist is reviewed
**Then** `PrivacyInfo.xcprivacy` is present in the app bundle and declares "Data Not Collected" (NFR13)
**And** entitlements file includes: iCloud/CloudKit, Siri, Push Notifications (local) (Architecture requirement)
**And** the App Group `group.com.<team>.todoapp` is correctly configured for all three targets
**And** the app's privacy nutrition label in App Store Connect matches `PrivacyInfo.xcprivacy`
**And** no third-party SDKs are linked that would conflict with the privacy label (NFR12, NFR14, NFR15)
**And** the URL scheme `todoapp://` is registered in `Info.plist`
**And** the app has been tested on a physical device for widget rendering, Siri capture, and notification delivery
