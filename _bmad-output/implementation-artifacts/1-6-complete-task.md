# Story 1.6: Complete Task

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an iPhone user,
I want to mark a task as complete with a satisfying interaction,
So that I feel rewarded for finishing something.

## Acceptance Criteria

1. **Given** the user sees an incomplete task in the list **When** they tap the completion circle/button on the task row **Then**:
   - `TaskListViewModel.completeTask(_:)` is called
   - `TaskRepository.completeTask(_:)` sets `isCompleted = true` and `modifiedAt = Date()` on a background context
   - A checkmark scale + opacity spring animation plays on the row (conditioned on `@Environment(\.accessibilityReduceMotion)` — no animation if Reduce Motion is on)
   - `NotificationService.shared.cancelNotification(for:)` is called (cancels any pending reminder)
   - `WidgetService.shared.reloadTimelines()` is called
   - The task visually transitions to completed state (strikethrough title, muted color) — already implemented in `TaskRowView` via `task.isCompleted`

2. **Given** a completed task is visible **When** the list renders **Then**:
   - Completed tasks show strikethrough title and muted (`.secondary`) text color
   - The completion circle shows `checkmark.circle.fill` with `Color.accentColor`
   - (Already implemented in `TaskRowView` — no changes needed there for visual state)

3. **Given** the Reduce Motion accessibility setting is enabled **When** a task is completed **Then**:
   - No animation plays — the state change is instant
   - `@Environment(\.accessibilityReduceMotion)` check gates the `withAnimation(.spring)` call

4. **Given** any complete operation fails **When** an error is thrown **Then**:
   - Errors are caught by the ViewModel, logged privately via `Logger` (no task content)
   - A generic "Something went wrong" banner is shown
   - The UI never displays raw error messages

## Tasks / Subtasks

- [x] Task 1: Add `completeTask(_:)` to `TaskListViewModel` (AC: #1, #4)
  - [x] 1.1 Add `completeTask(_ task: TaskItem) async` to `TaskListViewModel.swift` — calls `NotificationService.shared.cancelNotification(for: task)`, then `repository.completeTask(task)`, then `WidgetService.shared.reloadTimelines()`; catches errors via `handleError(_:)`

- [x] Task 2: Wire completion tap in `TaskRowView` to trigger completion with animation (AC: #1, #2, #3)
  - [x] 2.1 Add `onComplete: () -> Void` callback parameter to `TaskRowView`
  - [x] 2.2 Make the completion circle `Image` a `Button` (or add `.onTapGesture`) that calls `onComplete()`
  - [x] 2.3 Add `@Environment(\.accessibilityReduceMotion) private var reduceMotion` to `TaskRowView`
  - [x] 2.4 Add `@State private var isAnimating: Bool = false` to `TaskRowView` for spring animation
  - [x] 2.5 On tap: if `!reduceMotion`, trigger `withAnimation(.spring(response: 0.3, dampingFraction: 0.6))` toggling `isAnimating`, apply `.scaleEffect` and `.opacity` modifiers to the checkmark icon

- [x] Task 3: Pass completion callback from `TaskListView` to `TaskRowView` (AC: #1)
  - [x] 3.1 In `TaskListView.swift`, update `TaskRowView(task: task)` call to include `onComplete:` closure that calls `Task { @MainActor in await viewModel?.completeTask(task) }`
  - [x] 3.2 Ensure the `onTapGesture` for opening detail view is NOT triggered when tapping the completion circle — use a `Button` on the circle to intercept the tap before it propagates to `onTapGesture`

- [x] Task 4: Unit tests for complete task (AC: #1, #3, #4)
  - [x] 4.1 Add `completeTaskSetsIsCompleted` test to `TaskListViewModelTests.swift` — creates task, calls `viewModel.completeTask(task)`, verifies `isCompleted == true` and `showError == false`
  - [x] 4.2 Add `completeTaskAlreadyCompleted` test — creates a task, completes it once, completes it again, verifies no error and `isCompleted` stays `true`

- [x] Task 5: Register new/modified files in `project.pbxproj`
  - [x] 5.1 No new files are created in Story 1.6 — all changes are modifications to existing files. No `project.pbxproj` changes needed.

## Dev Notes

### TaskListViewModel.swift — Adding completeTask

Add the `completeTask` method following the **exact** same pattern as `deleteTask`:

```swift
// Features/Tasks/TaskListViewModel.swift — UPDATED for Story 1.6
func completeTask(_ task: TaskItem) async {
    do {
        NotificationService.shared.cancelNotification(for: task)
        try await repository.completeTask(task)
        WidgetService.shared.reloadTimelines()
    } catch {
        handleError(error)
    }
}
```

**Side-effect ordering for complete:**
1. Cancel notification FIRST — prevents a reminder from firing for a task the user just completed
2. `repository.completeTask(task)` — sets `isCompleted = true`, `modifiedAt = Date()`
3. `WidgetService.shared.reloadTimelines()` — widget must reflect completed state

`repository.completeTask(_:)` is ALREADY IMPLEMENTED in `TaskRepository.swift` (Story 1.3). Do NOT reimplement it.

[Source: architecture.md#Communication Patterns — Post-Mutation Side Effects — MANDATORY after every task mutation]
[Source: Core/Repositories/TaskRepository.swift — `completeTask` sets `isCompleted = true`, `modifiedAt = Date()`, calls `context.save()`]

---

### TaskRowView.swift — Making Completion Circle Tappable with Animation

The current `TaskRowView` (Story 1.5 state) already renders the correct completed visual state (`checkmark.circle.fill`, strikethrough, muted color). Story 1.6 adds:
1. A tap target on the circle to trigger completion
2. A spring animation on the checkmark icon
3. Reduce Motion check

**CRITICAL:** The row already has `.onTapGesture` in `TaskListView` to open detail. The completion circle tap must NOT propagate to that gesture. Using a `Button` for the circle intercepts the tap correctly.

**IMPORTANT:** `TaskRowView` currently uses `.accessibilityElement(children: .combine)` which merges all child elements. When adding a `Button`, the accessibility hint "Tap to open task details" will need updating — the combined element hint should reflect the primary action (open details), while the completion button gets its own accessibility label.

```swift
// Features/Tasks/TaskRowView.swift — UPDATED for Story 1.6
import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    var onComplete: (() -> Void)? = nil   // ← NEW: callback for completion tap

    @Environment(\.accessibilityReduceMotion) private var reduceMotion  // ← NEW

    @State private var animateCheckmark: Bool = false  // ← NEW: drives spring animation

    private var isOverdue: Bool {
        guard let dueDate = task.dueDate, !task.isCompleted else { return false }
        return dueDate < Date()
    }

    var body: some View {
        HStack(spacing: 12) {
            // Completion button — tappable circle; tap does NOT propagate to row onTapGesture
            Button {
                if let onComplete {
                    if !reduceMotion {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            animateCheckmark = true
                        }
                    }
                    onComplete()
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? Color.accentColor : .secondary)
                    .scaleEffect(animateCheckmark ? 1.25 : 1.0)   // spring scale pulse
            }
            .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")
            .buttonStyle(.plain)  // ← Prevents button styling from affecting HStack layout

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
        .onChange(of: task.isCompleted) { _, _ in
            // Reset animation state when task completion changes externally
            animateCheckmark = false
        }
        // Note: Remove .accessibilityElement(children: .combine) OR keep it but update hint
        // Recommended: Keep .combine but update hint to reflect dual actions
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

**`Button` vs `onTapGesture` interaction:** Using a `Button` with `.buttonStyle(.plain)` inside a `List` row correctly intercepts taps on the button area without preventing the parent `onTapGesture` (which navigates to detail view) from working on the rest of the row. This is the standard SwiftUI pattern for rows with multiple tap targets.

**Animation reset:** The `.onChange(of: task.isCompleted)` resets `animateCheckmark = false` when the task is uncompleted (Story 1.7) or when state changes from an external source (e.g., CloudKit sync). This prevents stale animation state.

**`onComplete` optional parameter:** Defaults to `nil` for backward compatibility with any existing `TaskRowView` call sites that don't need completion (e.g., widget views, previews). Always provide the callback in `TaskListView`.

[Source: architecture.md#Frontend/UI Architecture — Animations: "checkmark scale + opacity animation wrapped in `withAnimation(.spring)`"]
[Source: architecture.md#Frontend/UI Architecture — "Conditioned on `@Environment(\.accessibilityReduceMotion)`"]
[Source: epics.md#Story 1.6 AC — "checkmark scale + opacity spring animation plays on the row"]

---

### TaskListView.swift — Wiring the Completion Callback

The `TaskListView` already has the `ForEach` with `TaskRowView`. Update the `TaskRowView` call to pass the `onComplete` callback:

```swift
// In TaskListView.swift — inside List { ForEach(tasks) { task in ... } }
// BEFORE:
TaskRowView(task: task)
    .onTapGesture {
        coordinator.navigateTo(taskID: task.id)
    }
    .swipeActions(...)

// AFTER (Story 1.6):
TaskRowView(task: task, onComplete: {
    Task { @MainActor in
        await viewModel?.completeTask(task)
    }
})
.onTapGesture {
    coordinator.navigateTo(taskID: task.id)
}
.swipeActions(...)
```

**No other changes needed in `TaskListView.swift`.** The `@Query` reactive binding will automatically re-render the row when `isCompleted` changes — showing strikethrough and muted color immediately.

[Source: features/Tasks/TaskListView.swift — current ForEach with TaskRowView pattern]
[Source: architecture.md#Enforcement Guidelines — "Always call WidgetService.shared.reloadTimelines() after every task mutation"]

---

### project.pbxproj — Changes for Story 1.6

**No new files are created in Story 1.6.** All changes are modifications to existing files:
- `TaskListViewModel.swift` — add `completeTask(_:)` method
- `TaskRowView.swift` — add `onComplete` callback + Button + animation
- `TaskListView.swift` — pass `onComplete` closure to `TaskRowView`
- `TaskListViewModelTests.swift` — add 2 new completion tests

**No new PBXFileReference, PBXBuildFile, or PBXGroup entries required.** All files are already registered from Stories 1.3–1.5.

**Next story ID range:** Story 1.7 should use `A400`/`B400` range (first story to need new files after Story 1.5).

[Source: implementation-artifacts/1-5-delete-task.md#project.pbxproj — "Story 1.6 should use A400/B400 range (first story to need new files)"]

---

### TaskListViewModelTests.swift — New Tests for Story 1.6

Add these tests to the existing `TaskListViewModelTests.swift` file (append to the `@Suite("TaskListViewModel")` `@MainActor` struct):

```swift
@Test func completeTaskSetsIsCompleted() async throws {
    let container = try makeContainer()
    let viewModel = TaskListViewModel(modelContainer: container)

    let repo = TaskRepository(modelContainer: container)
    let task = try await repo.createTask(title: "To Complete", listID: nil)
    #expect(task.isCompleted == false)

    await viewModel.completeTask(task)

    #expect(viewModel.showError == false)
    #expect(task.isCompleted == true)
}

@Test func completeTaskAlreadyCompletedNoError() async throws {
    let container = try makeContainer()
    let viewModel = TaskListViewModel(modelContainer: container)

    let repo = TaskRepository(modelContainer: container)
    let task = try await repo.createTask(title: "Already Done", listID: nil)

    // Complete once
    await viewModel.completeTask(task)
    #expect(task.isCompleted == true)

    // Complete again — should not error
    await viewModel.completeTask(task)
    #expect(viewModel.showError == false)
    #expect(task.isCompleted == true)
}
```

**Note:** `completeTask` in ViewModel calls `NotificationService.shared.cancelNotification(for:)` first. In tests, `NotificationService.shared` is a stub that no-ops — no mocking needed.

[Source: architecture.md#Structure Patterns — Test Location: mirroring source folder structure]
[Source: TODOApp/TODOAppTests/TaskListViewModelTests.swift — existing `@Suite @MainActor struct` pattern with `makeContainer()` helper]

---

### Swift 6 Concurrency Requirements

1. **`Button { Task { @MainActor in ... } }` pattern** — Button action closures are synchronous. Wrap the async `completeTask()` call in `Task { @MainActor in ... }`. Both `TaskRowView` callback and `TaskListView` site must use this pattern.

2. **`@Environment(\.accessibilityReduceMotion)` in Views only** — Never pass this to ViewModels. Read it in `TaskRowView` directly where the animation decision is made.

3. **`@State private var animateCheckmark`** — `@State` is `@MainActor`-isolated in Swift 6 SwiftUI. No actor annotation needed on the property; it's automatically on the main actor as part of the `View` struct.

4. **`withAnimation` from `@MainActor`** — All `withAnimation` calls must happen on the main actor. Since `Button` actions run on the main actor in SwiftUI, this is automatically safe.

5. **`repository.completeTask(_:)` creates its own `ModelContext`** — The repository pattern creates a new `ModelContext(modelContainer)` per operation. This is safe from any calling actor (consistent with all other story patterns).

[Source: architecture.md#AI Agent Guidelines — Swift 6 strict concurrency]
[Source: implementation-artifacts/1-5-delete-task.md#Swift 6 Concurrency Requirements]

---

### Previous Story Intelligence (Story 1.5)

**Key learnings from Story 1.5 that directly affect this story:**

1. **`TaskListView` ViewModel initialization pattern** — `@State private var viewModel: TaskListViewModel?` initialized in `.task` modifier. Use `viewModel?.completeTask(task)` with optional chaining. Pattern already established and working.

2. **Side-effect ordering** — Story 1.5 established: cancel notification FIRST, then repository call, then widget reload. **Follow the same ordering for `completeTask`.**

3. **`handleError(_:)` reuse** — `TaskListViewModel.handleError(_:)` logs privately and sets `showError = true`. `completeTask` should use `handleError(error)` in its `catch` block — same as `deleteTask`.

4. **No new files needed** — Story 1.5 made the same observation. Story 1.6 likewise requires no new files. All modified files are already in `project.pbxproj`.

5. **`Button` in `List` rows** — Story 1.5 used `Button(role: .destructive)` in `TaskDetailView`. Story 1.6 uses `Button` with `.buttonStyle(.plain)` in `TaskRowView` inside a `List`. The `.plain` button style is critical to avoid the default button styling changing the row layout.

[Source: implementation-artifacts/1-5-delete-task.md]

---

### Git Intelligence Summary

Git log shows Stories 1.1–1.5 are committed. The codebase has:
- `TaskRepository.completeTask(_:)` fully implemented (Story 1.3) — sets `isCompleted = true`, `modifiedAt = Date()`, saves context
- `NotificationService.shared.cancelNotification(for:)` available (no-op stub from Story 1.3)
- `WidgetService.shared.reloadTimelines()` available as `@MainActor` singleton (Story 1.3)
- `TaskListViewModel` with `createTask`, `deleteTask`, and `handleError` (Story 1.4/1.5)
- `TaskRowView` with strikethrough/muted color for `isCompleted` state and comment "tap area expanded in Story 1.6"
- `TaskListView` with `TaskRowView` in `ForEach` and `.swipeActions` pattern (Story 1.5)
- All existing files registered in `project.pbxproj`

The `TaskRowView` comment `// Completion indicator (tap area expanded in Story 1.6)` explicitly anticipates this story's change.

---

### Project Structure Notes

**Files to MODIFY in this story (no new files):**
```
TODOApp/TODOApp/Features/Tasks/TaskListViewModel.swift  ← Add completeTask(_:) method
TODOApp/TODOApp/Features/Tasks/TaskRowView.swift        ← Add onComplete callback + Button + animation
TODOApp/TODOApp/Features/Tasks/TaskListView.swift       ← Pass onComplete closure to TaskRowView
TODOApp/TODOAppTests/TaskListViewModelTests.swift       ← Add 2 new completion tests
```

**Files NOT to touch:**
- `TaskRepository.swift` — `completeTask` already implemented (Story 1.3)
- `TaskDetailViewModel.swift` — no completion action in detail view (Story 1.7 handles uncomplete; completion is list-only)
- `TaskDetailView.swift` — no completion UI in detail view for this story
- `NotificationService.swift` — `cancelNotification` stub already exists
- `WidgetService.swift` — no changes needed
- `project.pbxproj` — no new files to register

**Architecture alignment:**
- All complete flows go through `TaskRepository.completeTask(_:)` — never direct `modelContext` manipulation in views [Source: architecture.md#Architectural Boundaries]
- `NotificationService` always called before repository write [Source: architecture.md#Notification Boundary]
- `WidgetService.shared.reloadTimelines()` MANDATORY after every task mutation [Source: architecture.md#Enforcement Guidelines]
- `@Environment(\.accessibilityReduceMotion)` check before ALL animations [Source: architecture.md#Enforcement Guidelines]
- `@MainActor` ViewModel `completeTask` method — called from view's `Task { @MainActor in }` block [Source: architecture.md#AI Agent Guidelines]

---

### References

- [Source: epics.md#Story 1.6] — Full BDD acceptance criteria for complete task
- [Source: architecture.md#Communication Patterns — Post-Mutation Side Effects] — `NotificationService` cancel + `WidgetService.reloadTimelines()` after complete
- [Source: architecture.md#Frontend/UI Architecture — Animations] — checkmark scale + opacity spring; conditioned on accessibilityReduceMotion
- [Source: architecture.md#Enforcement Guidelines] — NEVER skip WidgetService reload; NEVER call UNUserNotificationCenter directly from views
- [Source: architecture.md#AI Agent Guidelines] — `@Observable` + `@MainActor` for all ViewModels; `@Query` for reactive list display
- [Source: architecture.md#Process Patterns — Error Handling] — Generic "Something went wrong"; never raw error to user; Logger never logs task content
- [Source: implementation-artifacts/1-5-delete-task.md] — Side-effect ordering pattern; TaskListViewModel structure; no new files/pbxproj changes
- [Source: Core/Repositories/TaskRepository.swift] — `completeTask` already implemented; do NOT reimplement
- [Source: Features/Tasks/TaskRowView.swift] — Comment "tap area expanded in Story 1.6" confirms completion circle upgrade

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

None — implementation completed without errors.

### Completion Notes List

- Implemented `completeTask(_ task: TaskItem) async` in `TaskListViewModel` following the exact side-effect ordering pattern from `deleteTask`: cancel notification → repository write → widget reload → error handling via `handleError(_:)`.
- Updated `TaskRowView` to add an `onComplete: (() -> Void)? = nil` callback parameter (optional for backward compatibility), replaced the completion indicator `Image` with a `Button` using `.buttonStyle(.plain)` to correctly intercept taps without propagating to the parent `onTapGesture`. Added `@Environment(\.accessibilityReduceMotion)` check gating the `withAnimation(.spring(response: 0.3, dampingFraction: 0.6))` spring animation. Added `.onChange(of: task.isCompleted)` to reset animation state when task state changes externally.
- Updated `TaskListView` `ForEach` to pass `onComplete` closure calling `Task { @MainActor in await viewModel?.completeTask(task) }` to each `TaskRowView`.
- Added 2 new tests to `TaskListViewModelTests`: `completeTaskSetsIsCompleted` (verifies `isCompleted == true`, `showError == false`) and `completeTaskAlreadyCompletedNoError` (verifies idempotent completion with no error).
- No new files created; no `project.pbxproj` changes needed — all modified files already registered.
- All Acceptance Criteria satisfied: AC#1 (completeTask called, repository sets isCompleted, animation, notification cancel, widget reload), AC#2 (completed visual state already in TaskRowView via task.isCompleted), AC#3 (reduceMotion check gates animation), AC#4 (errors caught, logged privately, generic banner shown).

### File List

- TODOApp/TODOApp/Features/Tasks/TaskListViewModel.swift
- TODOApp/TODOApp/Features/Tasks/TaskRowView.swift
- TODOApp/TODOApp/Features/Tasks/TaskListView.swift
- TODOApp/TODOAppTests/TaskListViewModelTests.swift

## Change Log

- 2026-02-18: Story 1.6 implemented — added `completeTask(_:)` to `TaskListViewModel`, wired tappable completion circle with spring animation and Reduce Motion support in `TaskRowView`, passed `onComplete` closure in `TaskListView`, added 2 unit tests for completion scenarios. No new files; no pbxproj changes. Status set to review.
