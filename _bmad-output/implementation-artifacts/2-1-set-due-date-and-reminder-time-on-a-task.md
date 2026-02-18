# Story 2.1: Set Due Date & Reminder Time on a Task

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an iPhone user,
I want to set a due date and reminder time on a task,
So that I'm notified at the right moment to act.

## Acceptance Criteria

1. **Given** the user is in `TaskDetailView` **When** they tap "Add Due Date" **Then**:
   - A `DatePicker` is shown for selecting a due date
   - After selecting a date, an optional "Add Reminder" row appears
   - The due date is displayed in the task detail and in the task row (FR7) — `TaskRowView` already shows `task.dueDate`; overdue goes red; no change to `TaskRowView` needed

2. **Given** the user taps "Add Reminder" **When** they select a reminder time **Then**:
   - The `reminderDate` is stored on `TaskItem` via `TaskRepository.updateTask(_:)` (via `TaskDetailViewModel.setReminder(_:)`)
   - `NotificationService.shared.scheduleNotification(for: task)` is called immediately after the save
   - `WidgetService.shared.reloadTimelines()` is called (FR8)

3. **Given** the user changes or removes a due date **When** the update is saved **Then**:
   - The existing notification (if any) is cancelled via `NotificationService.shared.cancelNotification(for: task)`
   - A new notification is scheduled only if a `reminderDate` is still present

4. **Given** notification permission has not been granted **When** the user sets their first reminder **Then**:
   - `NotificationService` requests system permission (`UNUserNotificationCenter.requestAuthorization`) if status is `.notDetermined`
   - If permission is denied, the task still saves with its `reminderDate` but no notification is scheduled
   - A subtle inline hint indicates notifications are disabled (graceful degradation)

5. **Given** any operation fails **When** an error is thrown **Then**:
   - Errors are caught by `TaskDetailViewModel`, logged privately via `Logger` (no task content), and shown as "Something went wrong. Please try again."
   - The UI never displays raw error messages

## Tasks / Subtasks

- [x] Task 1: Implement `NotificationService.scheduleNotification(for:)` and `requestPermissionIfNeeded()` (AC: #2, #4)
  - [x] 1.1 Replace the no-op `scheduleNotification(for: task)` stub in `Core/Services/NotificationService.swift` with real implementation: creates a `UNMutableNotificationContent` with title = task title, body referencing due date, identifier `"task-\(task.id.uuidString)"`, schedules via `UNCalendarNotificationTrigger` from `reminderDate`
  - [x] 1.2 Add `requestPermissionIfNeeded() async -> Bool` method — calls `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])` if current status is `.notDetermined`; returns `true` if authorized
  - [x] 1.3 Replace the no-op `cancelNotification(for: task)` stub with real implementation — calls `UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["task-\(task.id.uuidString)"])`
  - [x] 1.4 Add `checkAuthorizationStatus() async -> UNAuthorizationStatus` helper for UI hint decision

- [x] Task 2: Update `TaskDetailViewModel` with due date and reminder methods (AC: #1, #2, #3, #4, #5)
  - [x] 2.1 Add `var dueDate: Date?` observable property, initialized from `task.dueDate`
  - [x] 2.2 Add `var reminderDate: Date?` observable property, initialized from `task.reminderDate`
  - [x] 2.3 Add `var notificationsDisabledHint: Bool = false` observable property for graceful-degradation UI hint
  - [x] 2.4 Add `setDueDate(_ date: Date?) async` — sets `task.dueDate`, `task.modifiedAt = Date()`; if `date == nil`, also clears `task.reminderDate` and cancels notification; calls `repository.updateTask(task)` and `WidgetService.shared.reloadTimelines()`; catches errors via inline error handling
  - [x] 2.5 Add `setReminder(_ date: Date?) async` — requires `task.dueDate != nil` first; sets `task.reminderDate`; calls `NotificationService.shared.requestPermissionIfNeeded()`; if authorized: calls `scheduleNotification(for: task)`; if denied: sets `notificationsDisabledHint = true`; calls `repository.updateTask(task)` and `WidgetService.shared.reloadTimelines()`; catches errors

- [x] Task 3: Update `TaskDetailView` with due date and reminder UI (AC: #1, #2, #3, #4)
  - [x] 3.1 Add a `Section("Due Date")` to the `Form`: shows "Add Due Date" button if `viewModel.dueDate == nil`, or a `DatePicker("Due Date", ...)` bound via custom Binding with inline `Task { await viewModel.setDueDate(newDate) }` if set; add a "Remove Due Date" button when a date is set
  - [x] 3.2 Add a conditional `Section("Reminder")` visible only when `viewModel.dueDate != nil`: shows "Add Reminder" button if `viewModel.reminderDate == nil`, or a `DatePicker("Reminder", ...)` bound to reminder date if set; add "Remove Reminder" button
  - [x] 3.3 Add inline hint text: `if viewModel.notificationsDisabledHint { Text("Notifications are disabled. Enable them in Settings to receive reminders.").font(.caption).foregroundStyle(.secondary) }`
  - [x] 3.4 Due date changes wired via `Binding.set` closure that calls `Task { await viewModel.setDueDate(newDate) }` immediately on picker change
  - [x] 3.5 Reminder changes wired via `Binding.set` closure that calls `Task { await viewModel.setReminder(newDate) }` immediately on picker change
  - [x] 3.6 VoiceOver accessibility labels added to all new controls per NFR16

- [x] Task 4: Create `Features/Notifications/` folder and `NotificationPermissionView.swift` (AC: #4)
  - [x] 4.1 Created `TODOApp/Features/Notifications/NotificationPermissionView.swift` — minimal View with "Enable Notifications" title, description text, "Continue" and "Not Now" buttons with callbacks; establishes `Features/Notifications/` folder structure for Story 7.3
  - [x] 4.2 Inline hint in `TaskDetailView` (`notificationsDisabledHint`) provides graceful degradation per AC#4; `NotificationPermissionView` registered for future wiring in Story 7.3

- [x] Task 5: Register new files in `project.pbxproj` (AC: #1, #2, #3)
  - [x] 5.1 Added `PBXFileReference` A400 (NotificationPermissionView.swift), `PBXBuildFile` B400, new `Notifications` subgroup D016 under D014 Features, added B400 to E001S Sources build phase
  - [x] 5.2 No changes to `Core/Services/NotificationService.swift` PBX entries — already registered (A208/B208)
  - [x] 5.3 No changes to `Features/Tasks/TaskDetailView.swift` or `TaskDetailViewModel.swift` entries — already registered (A301/B301, A302/B302)

- [x] Task 6: Add unit tests for `NotificationService` and `TaskDetailViewModel` (AC: #1, #2, #3, #4)
  - [x] 6.1 Created `TODOAppTests/Features/Notifications/NotificationServiceTests.swift` — registered as A401/B401 in project.pbxproj; new test group D017 under D004
  - [x] 6.2 Test `scheduleNotificationSkipsTaskWithNoReminderDate` — confirms guard fires for nil reminderDate; Test `scheduleNotificationSkipsTaskWithPastReminderDate` — confirms guard fires for past dates
  - [x] 6.3 Test `cancelNotificationUsesCorrectIdentifierScheme` — verifies identifier pattern `"task-\(task.id.uuidString)"`
  - [x] 6.4 Created `TaskDetailViewModelDueDateTests` suite: `setDueDateSavesToRepository`, `setDueDateNilClearsReminderAndCancelsNotification`, `setReminderWithoutDueDateIsIgnored`, `setReminderNilClearsReminderAndCancels`, `viewModelInitializesFromTaskDueDateAndReminderDate`, `setDueDateUpdatesModifiedAt`

## Dev Notes

### NotificationService.swift — Full Implementation

Replace the existing no-op stubs in `Core/Services/NotificationService.swift`:

```swift
// Core/Services/NotificationService.swift
import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    /// Schedule a local notification for a task's reminderDate.
    /// Only schedules if `task.reminderDate` is set and in the future.
    func scheduleNotification(for task: TaskItem) {
        guard let reminderDate = task.reminderDate, reminderDate > Date() else {
            Logger.notifications.info("No future reminderDate — skipping schedule")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = task.title   // NOTE: epics.md#Story 2.2 AC says title = task title
        if let dueDate = task.dueDate {
            content.body = "Due \(dueDate.formatted(date: .abbreviated, time: .omitted))"
        } else {
            content.body = "You have a reminder for this task."
        }
        content.sound = .default

        var triggerComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        triggerComponents.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

        let identifier = "task-\(task.id.uuidString)"  // Architecture: "task-\(task.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error {
                Logger.notifications.error("Failed to schedule notification")
                // Note: error NOT logged with task content per privacy rules
                _ = error
            }
        }
        Logger.notifications.info("Notification scheduled for task ID")
    }

    func cancelNotification(for task: TaskItem) {
        let identifier = "task-\(task.id.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        Logger.notifications.info("Notification cancelled for task ID")
    }

    /// Request notification permission if not yet determined.
    /// Returns true if authorized (granted now or previously).
    func requestPermissionIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                Logger.notifications.info("Notification permission request completed")
                return granted
            } catch {
                Logger.notifications.error("Notification permission request failed")
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    /// Check current authorization status without prompting.
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
}
```

**Key constraints:**
- Notification identifier scheme MUST be `"task-\(task.id.uuidString)"` — this is hardcoded in the architecture and used by Story 2.3 ("Mark Done") and Story 2.4 (reschedule after offline)
- `scheduleNotification` must NEVER log the task title — privacy rule from `architecture.md#Process Patterns`
- The `center.add(request)` callback is on a background thread — no UI updates inside the callback
- `requestAuthorization` can be called as `async throws` in iOS 17+ (no completion handler needed)

[Source: architecture.md#Notification Boundary — "NotificationService is the single access point for all UNUserNotificationCenter operations"]
[Source: epics.md#Story 2.1 AC — notification identifier = `"task-\(task.id.uuidString)"`]
[Source: epics.md#Story 2.2 AC — notification title = task title, body references due date]
[Source: architecture.md#Enforcement Guidelines — "Never log user-generated content"]

---

### TaskDetailViewModel.swift — Due Date & Reminder Methods

Extend the existing `TaskDetailViewModel` with new observable properties and async methods:

```swift
// Features/Tasks/TaskDetailViewModel.swift — UPDATED for Story 2.1
@MainActor
@Observable
final class TaskDetailViewModel {
    // EXISTING properties (unchanged)
    var editableTitle: String = ""
    var showError: Bool = false
    var errorMessage: String = ""
    var isDismissed: Bool = false

    // NEW: Story 2.1 — Due date & reminder state
    var dueDate: Date?
    var reminderDate: Date?
    var notificationsDisabledHint: Bool = false  // graceful degradation

    private let task: TaskItem
    private let repository: TaskRepositoryProtocol

    init(task: TaskItem, modelContainer: ModelContainer) {
        self.task = task
        self.editableTitle = task.title
        self.dueDate = task.dueDate           // NEW: initialize from model
        self.reminderDate = task.reminderDate  // NEW: initialize from model
        self.repository = TaskRepository(modelContainer: modelContainer)
    }

    // EXISTING methods unchanged: commitEdit(), deleteTask()

    // NEW: Story 2.1
    func setDueDate(_ date: Date?) async {
        task.dueDate = date
        task.modifiedAt = Date()

        // If removing the due date, also clear reminder and cancel notification
        if date == nil {
            task.reminderDate = nil
            reminderDate = nil
            NotificationService.shared.cancelNotification(for: task)
        } else if task.reminderDate != nil && date != nil {
            // Reschedule notification if reminder exists on the newly changed date
            // (Existing notification for this task-ID is overwritten by add() call)
            NotificationService.shared.scheduleNotification(for: task)
        }

        do {
            try await repository.updateTask(task)
            WidgetService.shared.reloadTimelines()
        } catch {
            Logger.data.error("TaskDetail setDueDate failed")
            errorMessage = "Something went wrong. Please try again."
            showError = true
        }
    }

    func setReminder(_ date: Date?) async {
        guard task.dueDate != nil || date == nil else {
            // Cannot set reminder without a due date
            return
        }

        if let date {
            // Request permission first
            let authorized = await NotificationService.shared.requestPermissionIfNeeded()
            task.reminderDate = date
            task.modifiedAt = Date()

            do {
                try await repository.updateTask(task)
                WidgetService.shared.reloadTimelines()
            } catch {
                Logger.data.error("TaskDetail setReminder failed")
                errorMessage = "Something went wrong. Please try again."
                showError = true
                return
            }

            if authorized {
                NotificationService.shared.scheduleNotification(for: task)
                notificationsDisabledHint = false
            } else {
                // Task saved but no notification scheduled — graceful degradation (FR36 / Story 2.1 AC #4)
                notificationsDisabledHint = true
            }
        } else {
            // Remove reminder
            task.reminderDate = nil
            task.modifiedAt = Date()
            NotificationService.shared.cancelNotification(for: task)
            do {
                try await repository.updateTask(task)
                WidgetService.shared.reloadTimelines()
            } catch {
                Logger.data.error("TaskDetail clearReminder failed")
                errorMessage = "Something went wrong. Please try again."
                showError = true
            }
            notificationsDisabledHint = false
        }
    }
}
```

**CRITICAL ordering rule for `setReminder`:**
1. `requestPermissionIfNeeded()` FIRST (system dialog shown before saving)
2. Set `task.reminderDate` and `modifiedAt`
3. `repository.updateTask(task)` — save to SwiftData
4. `WidgetService.shared.reloadTimelines()` — mandatory post-mutation side effect
5. ONLY THEN call `scheduleNotification` — after save succeeds

This ordering ensures the task is persisted before the notification is scheduled. If the app is killed after save but before schedule, Story 2.4 handles rescheduling on reconnect.

**Why `requestPermissionIfNeeded` is async:** It presents a system dialog which requires `await`. Since `TaskDetailViewModel` is `@MainActor`, this is safe to await on the main actor — the dialog is presented by the system, not blocking the main thread in the classic sense.

[Source: epics.md#Story 2.1 — "NotificationService triggers the system permission prompt (FR36)"]
[Source: architecture.md#Process Patterns — Error Handling: "wrap throws, show user-facing banner"]
[Source: architecture.md#Communication Patterns — "Post-Mutation Side Effects: mandatory after every task mutation"]

---

### TaskDetailView.swift — Due Date & Reminder UI

Extend the existing `Form` in `TaskDetailView` with new sections between the title section and the delete section:

```swift
// Features/Tasks/TaskDetailView.swift — UPDATED for Story 2.1

struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFieldFocused: Bool
    @State private var viewModel: TaskDetailViewModel

    init(task: TaskItem, modelContainer: ModelContainer) {
        _viewModel = State(initialValue: TaskDetailViewModel(task: task, modelContainer: modelContainer))
    }

    var body: some View {
        Form {
            // EXISTING: Title section (unchanged)
            Section("Title") {
                TextField("Task title", text: Bindable(viewModel).editableTitle)
                    .font(.body)
                    .focused($titleFieldFocused)
                    .onSubmit { Task { await viewModel.commitEdit() } }
                    .accessibilityLabel("Task title")
                    .accessibilityHint("Edit the task title")
            }

            // NEW: Due Date section
            Section {
                if viewModel.dueDate == nil {
                    Button("Add Due Date") {
                        // Set to tomorrow at noon as a sensible default
                        let tomorrow = Calendar.current.date(
                            byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())
                        ) ?? Date()
                        viewModel.dueDate = Calendar.current.date(
                            bySettingHour: 12, minute: 0, second: 0, of: tomorrow
                        ) ?? tomorrow
                        Task { await viewModel.setDueDate(viewModel.dueDate) }
                    }
                    .accessibilityLabel("Add due date")
                } else {
                    DatePicker(
                        "Due Date",
                        selection: Binding(
                            get: { viewModel.dueDate ?? Date() },
                            set: { newDate in
                                viewModel.dueDate = newDate
                                Task { await viewModel.setDueDate(newDate) }
                            }
                        ),
                        displayedComponents: [.date]
                    )
                    .accessibilityLabel("Due date")

                    Button("Remove Due Date", role: .destructive) {
                        viewModel.dueDate = nil
                        viewModel.reminderDate = nil
                        Task { await viewModel.setDueDate(nil) }
                    }
                    .accessibilityLabel("Remove due date")
                }
            } header: {
                Text("Due Date")
            }

            // NEW: Reminder section — only visible when a due date is set
            if viewModel.dueDate != nil {
                Section {
                    if viewModel.reminderDate == nil {
                        Button("Add Reminder") {
                            // Default reminder = due date at 9 AM
                            let defaultReminder = Calendar.current.date(
                                bySettingHour: 9, minute: 0, second: 0,
                                of: viewModel.dueDate ?? Date()
                            ) ?? Date()
                            viewModel.reminderDate = defaultReminder
                            Task { await viewModel.setReminder(defaultReminder) }
                        }
                        .accessibilityLabel("Add reminder")
                    } else {
                        DatePicker(
                            "Reminder",
                            selection: Binding(
                                get: { viewModel.reminderDate ?? Date() },
                                set: { newDate in
                                    viewModel.reminderDate = newDate
                                    Task { await viewModel.setReminder(newDate) }
                                }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .accessibilityLabel("Reminder time")

                        Button("Remove Reminder", role: .destructive) {
                            viewModel.reminderDate = nil
                            Task { await viewModel.setReminder(nil) }
                        }
                        .accessibilityLabel("Remove reminder")
                    }

                    // Graceful degradation hint (FR36 / AC #4)
                    if viewModel.notificationsDisabledHint {
                        Text("Notifications are disabled. Enable them in Settings to receive reminders.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Notifications are disabled. Go to Settings to enable reminders.")
                    }
                } header: {
                    Text("Reminder")
                }
            }

            // EXISTING: Delete section (unchanged)
            Section {
                Button(role: .destructive) {
                    Task { @MainActor in await viewModel.deleteTask() }
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
            if isDismissed { dismiss() }
        }
        .alert("Error", isPresented: Bindable(viewModel).showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}
```

**UI notes:**
- The "Add Due Date" button sets a sensible default date (tomorrow noon) rather than opening a picker immediately — this is a common iOS pattern; adjust if design calls for immediate picker presentation
- `DatePicker` with `displayedComponents: [.date]` for due date (date-only); `[.date, .hourAndMinute]` for reminder (full datetime needed for notification scheduling)
- `Binding` wrapper is used (not `Bindable`) because `viewModel.dueDate` is `Date?` — optional bindings require custom `Binding` or a non-optional intermediate; the pattern above is clean and correct
- The `Task { await viewModel.setDueDate(...) }` call inside the `Binding.set` triggers the async save immediately on user change
- `Section` visibility conditional on `viewModel.dueDate != nil` for the Reminder section is standard SwiftUI — no special handling needed

[Source: epics.md#Story 2.1 AC — "DatePicker is shown for selecting a due date"; "optional Add Reminder row appears after selecting a date"]
[Source: architecture.md#Frontend/UI Architecture — "Views are passive; render ViewModel state and forward user actions"]

---

### NotificationPermissionView.swift (Optional Pre-Prompt View)

Per Story 7.3 in the epics, `NotificationPermissionView.swift` lives at `Features/Notifications/`. For Story 2.1, the primary requirement is the graceful degradation hint inline in `TaskDetailView`. The `NotificationPermissionView` shown here is a minimal implementation:

```swift
// Features/Notifications/NotificationPermissionView.swift
import SwiftUI

struct NotificationPermissionView: View {
    let onContinue: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge")
                .font(.system(size: 48))
                .foregroundStyle(.accent)
                .accessibilityHidden(true)

            Text("Enable Notifications")
                .font(.title2.bold())

            Text("Enable notifications to get reminders when tasks are due.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Continue") {
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Continue to enable notifications")

            Button("Not Now") {
                onDismiss()
            }
            .foregroundStyle(.secondary)
            .accessibilityLabel("Dismiss notification permission prompt")
        }
        .padding()
    }
}
```

**Note:** This view is created in Story 2.1 to establish the `Features/Notifications/` folder and the file path referenced in the architecture. However, in Story 2.1's scope, the main flow does not require it to be presented as a sheet — the `requestPermissionIfNeeded()` call in `TaskDetailViewModel.setReminder` directly triggers the system dialog. This view is wired up in Story 7.3 (Notification Permission Prompt at First Reminder).

[Source: architecture.md#Project Structure — `Features/Notifications/NotificationPermissionView.swift`]
[Source: epics.md#Story 7.3 — Full NotificationPermissionView integration spec]

---

### project.pbxproj — Changes for Story 2.1

Story 2.1 creates **one new file** in the `Features/` area: `NotificationPermissionView.swift` in `Features/Notifications/`.

**New entries needed in `project.pbxproj`:**

1. **New PBXFileReference** (in the file references section):
```
A400 /* NotificationPermissionView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = NotificationPermissionView.swift; sourceTree = "<group>"; };
```

2. **New PBXBuildFile** (in the build files section):
```
B400 /* NotificationPermissionView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A400 /* NotificationPermissionView.swift */; };
```

3. **New PBXGroup for Notifications folder** (child of D014 `Features` group):
```
D016 /* Notifications */ = {
    isa = PBXGroup;
    children = (
        A400 /* NotificationPermissionView.swift */,
    );
    path = Notifications;
    sourceTree = "<group>";
};
```

4. **Add D016 to D014 Features group children:**
```
// In D014 Features group, add: D016 /* Notifications */,
```

5. **Add B400 to Sources build phase** (in the `PBXSourcesBuildPhase`):
```
B400 /* NotificationPermissionView.swift in Sources */,
```

**Files that do NOT need PBX changes** (already registered in previous stories):
- `Core/Services/NotificationService.swift` — registered as A208/B208 in Story 1.x
- `Features/Tasks/TaskDetailView.swift` — registered as A301/B301 in Story 1.4
- `Features/Tasks/TaskDetailViewModel.swift` — registered as A302/B302 in Story 1.4

**Test file for `NotificationServiceTests.swift`:**
- If `TODOAppTests/Features/Notifications/` folder needs creation, a new group and file reference are needed
- PBXFileReference: `A401 /* NotificationServiceTests.swift */`
- PBXBuildFile: `B401 /* NotificationServiceTests.swift in Sources */` (in test target's Sources build phase)
- New test group: `D017 /* Notifications */ = { ... path = Notifications; ... }`

[Source: TODOApp/TODOApp.xcodeproj/project.pbxproj — current pattern A300-A303/B300-B303 for Story 1.4 files; D014/D015 group structure]

---

### NotificationService — @MainActor Isolation Note

The current `NotificationService` is `@MainActor`. This is correct because `scheduleNotification` and `cancelNotification` are called from `@MainActor` ViewModels. However, `UNUserNotificationCenter.current()` methods themselves run off the main thread internally.

**Critical:** The `center.add(request) { error in ... }` completion handler runs on a background thread. Do NOT update `@Observable` properties inside this closure. The pattern above logs privately and discards the error — the `center.add` call is fire-and-forget from the UI perspective.

**Swift 6 note:** `UNUserNotificationCenter.requestAuthorization(options:)` has an async variant that works with `await` on iOS 16+. Use `try await center.requestAuthorization(options:)` (no completion handler) — cleaner and Swift 6 compatible. The `checkAuthorizationStatus()` helper uses `await center.notificationSettings()` — same pattern.

[Source: architecture.md#Core Architectural Decisions — Swift 6 strict concurrency]

---

### Previous Story Intelligence (Epics 1.4–1.7)

Key patterns established in Epic 1 that MUST be followed in this story:

1. **TaskDetailViewModel pattern:**
   - `@MainActor @Observable final class` — already correct
   - `private let task: TaskItem` — already present; `dueDate` and `reminderDate` are set directly on this reference
   - Repository calls via `try await repository.updateTask(task)` — same pattern as `commitEdit`
   - `WidgetService.shared.reloadTimelines()` AFTER successful save — never before, never on error path

2. **`handleError(_:)` pattern from `TaskListViewModel`:** `TaskDetailViewModel` does NOT use `handleError` (it inline-sets `showError = true` and `errorMessage`). Maintain consistency with existing `TaskDetailViewModel` pattern — do NOT refactor to use `handleError`.

3. **`NotificationService.shared.cancelNotification(for: task)` already called in `deleteTask()` in `TaskDetailViewModel`** — this confirms the existing call site is correct and `cancelNotification` is the right method name for Story 2.1.

4. **`completeTask` in `TaskListViewModel` already calls `NotificationService.shared.cancelNotification(for: task)`** — when a task is completed, any pending reminder is cancelled. Story 2.1's `setDueDate(nil)` must also cancel: `NotificationService.shared.cancelNotification(for: task)`.

5. **No `project.pbxproj` changes for existing files** — TaskDetailView.swift, TaskDetailViewModel.swift, NotificationService.swift are already registered. Only `NotificationPermissionView.swift` needs registration.

[Source: implementation-artifacts/1-4-add-task-and-edit-task.md]
[Source: implementation-artifacts/1-7-uncomplete-task.md]

---

### Git Intelligence

Recent commits show Stories 1.2 and 1.3 were the last committed work (Stories 1.4–1.7 are modified/untracked in working tree per git status). This means:

- `NotificationService.swift` stub (with `scheduleNotification` and `cancelNotification` as no-ops) was implemented in Story 1.x and is in the current codebase — confirmed by reading the file above
- `TaskDetailViewModel.deleteTask()` already calls `NotificationService.shared.cancelNotification(for: task)` — Story 2.1 must ensure `setDueDate(nil)` does the same
- The `TaskRowView` already renders `task.dueDate` with overdue styling (red color) — **no changes to `TaskRowView` needed for Story 2.1**; the due date display in the row is already implemented

[Source: git log — last 5 commits; current working tree state from git status]

---

### iOS API Notes — UserNotifications Framework

For iOS 17+ (our minimum deployment target), the following APIs are available and MUST be used:

```swift
// ✅ CORRECT: async/await APIs (iOS 17+)
let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
let settings = await UNUserNotificationCenter.current().notificationSettings()

// ❌ WRONG: Completion handler APIs (use only if async variant unavailable)
UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in ... }
```

**`UNCalendarNotificationTrigger` vs `UNTimeIntervalNotificationTrigger`:**
- Use `UNCalendarNotificationTrigger` for calendar-based reminders (specific date+time) — required for due date reminders
- The `dateComponents` must include `.year, .month, .day, .hour, .minute` for a one-time trigger at an exact date and time
- Set `.second = 0` to ensure the trigger fires at the start of the minute (cleaner UX)

**NFR25 compliance:** `UNCalendarNotificationTrigger` with `repeats: false` automatically survives app backgrounding, device relock, and app kill by design — no special handling needed.

[Source: Apple Developer Documentation — UNUserNotificationCenter, UNCalendarNotificationTrigger]
[Source: architecture.md#NFR25 — "Local notification scheduling survives app backgrounding and device relock"]

---

### Project Structure Notes

**Files to CREATE in this story:**
```
TODOApp/TODOApp/Features/Notifications/NotificationPermissionView.swift  ← NEW (minimal)
TODOApp/TODOAppTests/Features/Notifications/NotificationServiceTests.swift ← NEW (tests)
```

**Files to MODIFY in this story:**
```
TODOApp/TODOApp/Core/Services/NotificationService.swift       ← Replace stubs with real implementation
TODOApp/TODOApp/Features/Tasks/TaskDetailView.swift           ← Add due date + reminder UI sections
TODOApp/TODOApp/Features/Tasks/TaskDetailViewModel.swift      ← Add dueDate, reminderDate props + setDueDate/setReminder methods
TODOApp/TODOApp.xcodeproj/project.pbxproj                     ← Register new files
```

**Files NOT to touch:**
- `Core/Models/TaskItem.swift` — `dueDate: Date?` and `reminderDate: Date?` already defined
- `Core/Repositories/TaskRepositoryProtocol.swift` — `updateTask(_:)` already declared
- `Core/Repositories/TaskRepository.swift` — `updateTask` already implemented (Story 1.3)
- `Features/Tasks/TaskRowView.swift` — already renders `task.dueDate` with overdue red styling; no changes needed
- `Features/Tasks/TaskListView.swift` — no changes needed; row display already handles due dates
- `Features/Tasks/TaskListViewModel.swift` — no changes needed; `completeTask` already cancels notifications
- `Core/Services/WidgetService.swift` — no changes needed
- `AppCoordinator.swift` — no changes needed

**Architecture alignment:**
- `NotificationService.shared` is the ONLY place where `UNUserNotificationCenter` is accessed — never in views or ViewModels directly [Source: architecture.md#Notification Boundary]
- `WidgetService.shared.reloadTimelines()` MANDATORY after `setDueDate` and `setReminder` saves [Source: architecture.md#Enforcement Guidelines]
- `@MainActor @Observable` `TaskDetailViewModel` owns all state for the detail view [Source: architecture.md#Frontend/UI Architecture]
- `task.reminderDate` and `task.dueDate` are mutated directly on the `@MainActor` ViewModel (same actor), then persisted via `repository.updateTask(task)` [Source: architecture.md#Communication Patterns]
- Privacy: Never log task title or reminder date values via `Logger` [Source: architecture.md#Process Patterns — Logging]

---

### References

- [Source: epics.md#Story 2.1] — Full BDD acceptance criteria for this story
- [Source: epics.md#Epic 2] — "Deliver due date and reminder time setting on tasks, schedule local notifications..."
- [Source: architecture.md#Notification Boundary] — NotificationService is single access point; identifier scheme `"task-\(task.id.uuidString)"`
- [Source: architecture.md#Data Architecture — TaskItem model] — `dueDate: Date?`, `reminderDate: Date?` already on model
- [Source: architecture.md#Communication Patterns — Post-Mutation Side Effects] — `WidgetService` + `NotificationService` after every mutation
- [Source: architecture.md#Project Structure — Features/Notifications/] — folder and files defined
- [Source: architecture.md#Enforcement Guidelines] — No direct UNUserNotificationCenter in views; always WidgetService after mutation; never log user content
- [Source: architecture.md#Frontend/UI Architecture — State Management] — `@Observable` ViewModel; `@Query` for collection display; `Binding` for DatePicker
- [Source: implementation-artifacts/1-4-add-task-and-edit-task.md] — TaskDetailView/ViewModel existing patterns
- [Source: implementation-artifacts/1-7-uncomplete-task.md] — most recent story context; file registration patterns
- [Source: Core/Services/NotificationService.swift] — existing stub (confirmed no-op with schedule/cancel methods)
- [Source: Features/Tasks/TaskDetailView.swift] — existing Form structure + alert pattern
- [Source: Features/Tasks/TaskDetailViewModel.swift] — existing `deleteTask` pattern (calls `cancelNotification`)
- [Source: Core/Models/TaskItem.swift] — `dueDate: Date?`, `reminderDate: Date?` confirmed present
- [Source: TODOApp/TODOApp.xcodeproj/project.pbxproj] — A300–A303/B300–B303 range used; D014/D015 group structure; use A400+/B400+ for new files

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

No debug issues encountered. Implementation followed Dev Notes exactly.

### Completion Notes List

- ✅ Implemented `NotificationService.scheduleNotification(for:)` — real `UNCalendarNotificationTrigger` with `"task-\(task.id.uuidString)"` identifier, title=task.title, body references dueDate; guards for nil/past reminderDate; `center.add()` fire-and-forget with private error logging
- ✅ Implemented `NotificationService.cancelNotification(for:)` — calls `removePendingNotificationRequests` with correct identifier scheme
- ✅ Added `NotificationService.requestPermissionIfNeeded() async -> Bool` — async/await iOS 17+ API, checks current status before requesting, returns true if authorized/provisional/ephemeral
- ✅ Added `NotificationService.checkAuthorizationStatus() async -> UNAuthorizationStatus` — non-prompting status check
- ✅ Extended `TaskDetailViewModel` with `dueDate: Date?`, `reminderDate: Date?`, `notificationsDisabledHint: Bool` observable properties; initialized from task in `init`
- ✅ Added `TaskDetailViewModel.setDueDate(_ date: Date?) async` — clears reminder+cancels notification when nil; reschedules if reminder exists on updated date; saves via repository; calls WidgetService
- ✅ Added `TaskDetailViewModel.setReminder(_ date: Date?) async` — guards dueDate required; calls `requestPermissionIfNeeded()` first; saves; schedules notification if authorized else sets `notificationsDisabledHint`; handles removal path
- ✅ Updated `TaskDetailView` with Due Date section (Add/DatePicker/Remove) and conditional Reminder section (Add/DatePicker/Remove + disabled hint); all controls have VoiceOver accessibility labels
- ✅ Created `NotificationPermissionView.swift` at `Features/Notifications/` — minimal pre-prompt UI for Story 7.3 wiring
- ✅ Registered A400/B400 (NotificationPermissionView), D016 (Notifications group), A401/B401 (NotificationServiceTests), D017 (test Notifications group) in project.pbxproj
- ✅ Created `NotificationServiceTests.swift` with 4 tests: schedule skips nil/past reminder, cancel identifier scheme, authorization status validity
- ✅ Created `TaskDetailViewModelDueDateTests` suite with 6 tests: setDueDate saves, nil clears reminder+notification, setReminder without dueDate ignored, nil reminder clears+cancels, init from task model, modifiedAt updated

### File List

TODOApp/TODOApp/Core/Services/NotificationService.swift (MODIFIED)
TODOApp/TODOApp/Features/Tasks/TaskDetailViewModel.swift (MODIFIED)
TODOApp/TODOApp/Features/Tasks/TaskDetailView.swift (MODIFIED)
TODOApp/TODOApp/Features/Notifications/NotificationPermissionView.swift (NEW)
TODOApp/TODOAppTests/Features/Notifications/NotificationServiceTests.swift (NEW)
TODOApp/TODOApp.xcodeproj/project.pbxproj (MODIFIED)
_bmad-output/implementation-artifacts/sprint-status.yaml (MODIFIED)

## Change Log

- 2026-02-18: Story 2.1 implemented — NotificationService real implementation (scheduleNotification, cancelNotification, requestPermissionIfNeeded, checkAuthorizationStatus); TaskDetailViewModel extended with dueDate/reminderDate/notificationsDisabledHint properties and setDueDate/setReminder async methods; TaskDetailView updated with Due Date and Reminder sections; NotificationPermissionView.swift created; unit tests added for NotificationService and TaskDetailViewModel due date/reminder flows; all new files registered in project.pbxproj (claude-sonnet-4-6)
