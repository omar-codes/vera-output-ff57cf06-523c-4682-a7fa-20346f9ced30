# Story 1.7: Uncomplete Task

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an iPhone user,
I want to mark a completed task back to incomplete,
So that I can reopen tasks that weren't actually finished.

## Acceptance Criteria

1. **Given** a completed task is visible in the list **When** the user taps the completed indicator **Then**:
   - `TaskListViewModel.uncompleteTask(_:)` is called
   - `TaskRepository.updateTask(_:)` sets `isCompleted = false` and `modifiedAt = Date()` on a background context
   - `WidgetService.shared.reloadTimelines()` is called
   - The task moves back to the incomplete visual state (no strikethrough, primary color, unfilled circle)

2. **Given** an uncomplete operation fails **When** an error is thrown **Then**:
   - Errors are caught by the ViewModel, logged privately via `Logger` (no task content)
   - A generic "Something went wrong" banner is shown
   - The UI never displays raw error messages

3. **Given** a task is uncompleted locally **When** iCloud sync runs on another device **Then**:
   - The conflict resolution rule is applied: `isCompleted` is additive — sync will NOT re-complete the task; only another explicit local user action can set it back to `true`
   - CloudKit last-write-wins on `modifiedAt` governs `isCompleted = false` propagation

## Tasks / Subtasks

- [x] Task 1: Add `uncompleteTask(_:)` to `TaskListViewModel` (AC: #1, #2)
  - [x] 1.1 Add `uncompleteTask(_ task: TaskItem) async` to `TaskListViewModel.swift` — sets `task.isCompleted = false` and `task.modifiedAt = Date()` then calls `repository.updateTask(task)`, then calls `WidgetService.shared.reloadTimelines()`; catches errors via `handleError(_:)`

- [x] Task 2: Wire uncomplete tap in `TaskRowView` (AC: #1)
  - [x] 2.1 Add `onUncomplete: (() -> Void)? = nil` callback parameter to `TaskRowView`
  - [x] 2.2 Update the completion `Button` action: when `task.isCompleted == true`, call `onUncomplete()` instead of `onComplete()`
  - [x] 2.3 Ensure the accessibility label on the button still reads "Mark incomplete" for completed tasks (already implemented in Story 1.6 — verify it remains correct)
  - [x] 2.4 No animation needed for uncomplete (only complete has the spring animation) — the `.onChange(of: task.isCompleted)` reset already handles resetting `animateCheckmark`

- [x] Task 3: Pass uncomplete callback from `TaskListView` to `TaskRowView` (AC: #1)
  - [x] 3.1 In `TaskListView.swift`, update `TaskRowView` call to include `onUncomplete:` closure that calls `Task { @MainActor in await viewModel?.uncompleteTask(task) }`

- [x] Task 4: Unit tests for uncomplete task (AC: #1, #2)
  - [x] 4.1 Add `uncompleteTaskSetsIsCompletedFalse` test to `TaskListViewModelTests.swift` — creates task, completes it, calls `viewModel.uncompleteTask(task)`, verifies `isCompleted == false` and `showError == false`
  - [x] 4.2 Add `uncompleteTaskAlreadyIncompleteNoError` test — creates task (already `isCompleted = false`), calls `uncompleteTask`, verifies no error and `isCompleted` remains `false`

- [x] Task 5: Verify `project.pbxproj` (AC: #1)
  - [x] 5.1 No new files are created in Story 1.7 — all changes are modifications to existing files. No `project.pbxproj` changes needed.

## Dev Notes

### TaskListViewModel.swift — Adding uncompleteTask

Add the `uncompleteTask` method following the **exact** same pattern as `deleteTask` and `completeTask`. The key difference from `completeTask` is that uncomplete calls `repository.updateTask(_:)` (not `completeTask`), sets the two properties directly, and does NOT cancel notifications (since the task is being re-opened, notifications are irrelevant until a reminder is set again).

```swift
// Features/Tasks/TaskListViewModel.swift — UPDATED for Story 1.7
func uncompleteTask(_ task: TaskItem) async {
    do {
        task.isCompleted = false
        task.modifiedAt = Date()
        try await repository.updateTask(task)
        WidgetService.shared.reloadTimelines()
    } catch {
        handleError(error)
    }
}
```

**Side-effect ordering for uncomplete:**
1. Mutate `task.isCompleted = false` and `task.modifiedAt = Date()` directly on the model object (same actor — `@MainActor` ViewModel)
2. `repository.updateTask(task)` — persists the changes via a background `ModelContext`
3. `WidgetService.shared.reloadTimelines()` — widget must reflect the reopened state

**Why NOT call `NotificationService`:** An uncompleted task has no `reminderDate` set (reminders are an Epic 2 feature). In MVP scope (Epic 1), there is no notification to reschedule. If a reminder exists (post-Epic 2), the developer extending Story 2.1 will handle rescheduling. Do NOT add notification logic here.

**Why `repository.updateTask` not `completeTask`:** `TaskRepositoryProtocol.completeTask(_:)` hardcodes `isCompleted = true`. Uncomplete is a generic update — use `updateTask(_:)` after setting the properties in the ViewModel.

[Source: epics.md#Story 1.7 AC — "isCompleted is set to false and modifiedAt = Date() via TaskRepository.updateTask(_:)"]
[Source: architecture.md#Communication Patterns — Post-Mutation Side Effects — MANDATORY after every task mutation]
[Source: Core/Repositories/TaskRepositoryProtocol.swift — `updateTask(_ task: TaskItem) async throws`]

---

### TaskRowView.swift — Adding onUncomplete Callback

The current `TaskRowView` (Story 1.6 state) has an `onComplete` callback and the completion button already shows "Mark incomplete" as accessibility label when `task.isCompleted == true`. Story 1.7 adds:
1. An `onUncomplete` callback parameter (same pattern as `onComplete`)
2. Conditional dispatch: when tapped, if `task.isCompleted == true` → call `onUncomplete()`; if `task.isCompleted == false` → call `onComplete()`

**No animation for uncomplete:** The spring animation only plays on completing (the satisfying checkmark pulse). Uncomplete is a neutral state change — no animation needed. The existing `.onChange(of: task.isCompleted)` that resets `animateCheckmark = false` already handles the cleanup.

```swift
// Features/Tasks/TaskRowView.swift — UPDATED for Story 1.7
struct TaskRowView: View {
    let task: TaskItem
    var onComplete: (() -> Void)? = nil
    var onUncomplete: (() -> Void)? = nil   // ← NEW: callback for uncomplete tap

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateCheckmark: Bool = false

    // ... (isOverdue, accessibilityLabel unchanged) ...

    var body: some View {
        HStack(spacing: 12) {
            Button {
                if task.isCompleted {
                    // Tapping a completed task → uncomplete it (no animation)
                    onUncomplete?()
                } else {
                    // Tapping an incomplete task → complete it (with optional animation)
                    if let onComplete {
                        if !reduceMotion {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                animateCheckmark = true
                            }
                        }
                        onComplete()
                    }
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? Color.accentColor : .secondary)
                    .scaleEffect(animateCheckmark ? 1.25 : 1.0)
            }
            .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")
            .buttonStyle(.plain)

            // ... (rest of VStack unchanged) ...
        }
        .padding(.vertical, 4)
        .onChange(of: task.isCompleted) { _, _ in
            animateCheckmark = false
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Tap to open task details")
    }
    // ... (accessibilityLabel computed property unchanged) ...
}
```

**CRITICAL — Current button logic in Story 1.6:** The Story 1.6 button calls `onComplete()` unconditionally when tapped. This works only because `TaskListView` only shows the completion button tap path — but now we need to distinguish the two directions. The fix is to check `task.isCompleted` inside the button action and dispatch accordingly.

**Backward compatibility:** Both `onComplete` and `onUncomplete` are optional (`= nil`). Existing call sites that don't provide either (previews, other views) continue to work — the button is a no-op if neither callback is provided.

[Source: architecture.md#Frontend/UI Architecture — Animations: only complete has spring animation]
[Source: implementation-artifacts/1-6-complete-task.md#TaskRowView.swift — accessibilityLabel "Mark incomplete" for completed state confirms Story 1.7 readiness]
[Source: epics.md#Story 1.7 AC — "task moves back to the incomplete visual state"]

---

### TaskListView.swift — Wiring the Uncomplete Callback

The `TaskListView` `ForEach` already passes `onComplete`. Add `onUncomplete` to complete both directions:

```swift
// In TaskListView.swift — inside List { ForEach(tasks) { task in ... } }
// BEFORE (Story 1.6):
TaskRowView(task: task, onComplete: {
    Task { @MainActor in
        await viewModel?.completeTask(task)
    }
})

// AFTER (Story 1.7):
TaskRowView(task: task, onComplete: {
    Task { @MainActor in
        await viewModel?.completeTask(task)
    }
}, onUncomplete: {
    Task { @MainActor in
        await viewModel?.uncompleteTask(task)
    }
})
```

**No other changes needed in `TaskListView.swift`.** The `@Query` reactive binding automatically re-renders the row when `isCompleted` changes — the incomplete visual state (no strikethrough, primary color, unfilled circle) appears immediately because `TaskRowView` already conditions all visual state on `task.isCompleted`.

[Source: Features/Tasks/TaskListView.swift — current ForEach with TaskRowView pattern (Story 1.6)]
[Source: architecture.md#Enforcement Guidelines — "Always call WidgetService.shared.reloadTimelines() after every task mutation"]

---

### project.pbxproj — Changes for Story 1.7

**No new files are created in Story 1.7.** All changes are modifications to existing files:
- `TaskListViewModel.swift` — add `uncompleteTask(_:)` method
- `TaskRowView.swift` — add `onUncomplete` callback + conditional dispatch
- `TaskListView.swift` — pass `onUncomplete` closure to `TaskRowView`
- `TaskListViewModelTests.swift` — add 2 new uncomplete tests

**No new PBXFileReference, PBXBuildFile, or PBXGroup entries required.** All files are already registered from Stories 1.3–1.6.

[Source: implementation-artifacts/1-6-complete-task.md#project.pbxproj — "Story 1.7 should use A400/B400 range (first story to need new files after Story 1.5)"]

---

### TaskListViewModelTests.swift — New Tests for Story 1.7

Add these tests to the existing `TaskListViewModelTests.swift` file (append to the `@Suite("TaskListViewModel")` `@MainActor` struct):

```swift
@Test func uncompleteTaskSetsIsCompletedFalse() async throws {
    let container = try makeContainer()
    let viewModel = TaskListViewModel(modelContainer: container)

    let repo = TaskRepository(modelContainer: container)
    let task = try await repo.createTask(title: "To Uncomplete", listID: nil)

    // Complete the task first
    await viewModel.completeTask(task)
    #expect(task.isCompleted == true)

    // Now uncomplete it
    await viewModel.uncompleteTask(task)

    #expect(viewModel.showError == false)
    #expect(task.isCompleted == false)
}

@Test func uncompleteTaskAlreadyIncompleteNoError() async throws {
    let container = try makeContainer()
    let viewModel = TaskListViewModel(modelContainer: container)

    let repo = TaskRepository(modelContainer: container)
    let task = try await repo.createTask(title: "Already Incomplete", listID: nil)
    #expect(task.isCompleted == false)

    // Uncomplete an already-incomplete task — should not error
    await viewModel.uncompleteTask(task)

    #expect(viewModel.showError == false)
    #expect(task.isCompleted == false)
}
```

**Note:** `uncompleteTask` calls `repository.updateTask(_:)`. The `TaskRepository.updateTask` implementation creates a background `ModelContext` per operation. In tests, this correctly uses the in-memory container — no mocking needed. The `WidgetService.shared.reloadTimelines()` and `NotificationService` stubs are no-ops and don't affect test assertions.

[Source: architecture.md#Structure Patterns — Test Location: mirroring source folder structure]
[Source: TODOApp/TODOAppTests/TaskListViewModelTests.swift — existing `@Suite @MainActor struct` pattern with `makeContainer()` helper]

---

### iCloud Conflict Resolution for Uncomplete

The epic explicitly documents the conflict resolution rule for this story:

> `isCompleted` conflict resolution is additive: once `true`, never reverted via sync; only explicit user action can set back to `false`

This means:
- When the user uncompletes a task and it syncs, `modifiedAt` is updated — CloudKit last-write-wins on the `modifiedAt` field governs whether the `isCompleted = false` propagates to other devices
- If **both** devices are online and one completes while the other uncompletes simultaneously, the last-write-wins on `modifiedAt` resolves the conflict
- The architecture's additive rule means: **sync cannot re-complete a task that a user explicitly uncompleted** — it only flows in the "true wins" direction for concurrent edits without a clear `modifiedAt` winner

**No code changes required for conflict resolution** — this is handled by the `modifiedAt = Date()` timestamp update in `uncompleteTask` and CloudKit's built-in sync mechanism. Documenting it here so the developer understands the data contract.

[Source: architecture.md#Data Architecture — Conflict Resolution: "isCompleted is additive: once true, never set back to false via sync"]
[Source: epics.md#Story 1.7 AC — "isCompleted is additive — sync will not re-complete the task; only local user action sets it back to false"]

---

### Swift 6 Concurrency Requirements

1. **`Button { ... }` pattern** — The button action closure is synchronous. `onUncomplete()` is a `(() -> Void)?` called synchronously. The actual async work is in `TaskListView`'s closure: `Task { @MainActor in await viewModel?.uncompleteTask(task) }`.

2. **Property mutation from `@MainActor`** — `task.isCompleted = false` and `task.modifiedAt = Date()` are set from `TaskListViewModel` which is `@MainActor`. SwiftData `@Model` objects retrieved from `@Query` on the main context are accessible from `@MainActor`. This pattern is consistent with how `completeTask` works.

3. **`repository.updateTask(_:)` creates its own `ModelContext`** — The repository creates a new background `ModelContext(modelContainer)` per operation. Setting properties on the main-actor task object and then saving via a background context is the established pattern (consistent with Stories 1.4–1.6).

4. **`@State private var animateCheckmark`** — No changes needed. The existing `.onChange(of: task.isCompleted)` reset ensures `animateCheckmark = false` when the task is uncompleted, preventing stale animation state.

[Source: architecture.md#AI Agent Guidelines — Swift 6 strict concurrency]
[Source: implementation-artifacts/1-6-complete-task.md#Swift 6 Concurrency Requirements]

---

### Previous Story Intelligence (Story 1.6)

**Key learnings from Story 1.6 that directly affect this story:**

1. **`onComplete: (() -> Void)? = nil` pattern** — Story 1.6 established the optional callback on `TaskRowView`. Story 1.7 adds `onUncomplete` using the identical pattern. Do NOT change `onComplete` to non-optional — backward compatibility matters for previews and other callers.

2. **`Button` dispatch inside `TaskRowView`** — The current Story 1.6 button calls `onComplete` unconditionally. Story 1.7 MUST change this to a conditional: `if task.isCompleted { onUncomplete?() } else { /* existing complete logic */ }`. This is the only behavioral change in `TaskRowView`.

3. **Animation gating** — Only the `onComplete` path has `withAnimation(.spring)`. The `onUncomplete` path is instant — no animation. The `.onChange(of: task.isCompleted)` reset handles cleanup.

4. **Accessibility label "Mark incomplete"** — Already set in Story 1.6 for completed tasks. No change needed. VoiceOver will correctly announce the button's purpose in both directions.

5. **`handleError(_:)` reuse** — `uncompleteTask` should use the same `handleError(error)` in its `catch` block — identical to `completeTask` and `deleteTask`.

6. **No new files** — Story 1.6 confirmed all files are already registered in `project.pbxproj`. Story 1.7 makes the same observation.

[Source: implementation-artifacts/1-6-complete-task.md]

---

### Project Structure Notes

**Files to MODIFY in this story (no new files):**
```
TODOApp/TODOApp/Features/Tasks/TaskListViewModel.swift  ← Add uncompleteTask(_:) method
TODOApp/TODOApp/Features/Tasks/TaskRowView.swift        ← Add onUncomplete callback + conditional dispatch
TODOApp/TODOApp/Features/Tasks/TaskListView.swift       ← Pass onUncomplete closure to TaskRowView
TODOApp/TODOAppTests/TaskListViewModelTests.swift       ← Add 2 new uncomplete tests
```

**Files NOT to touch:**
- `TaskRepository.swift` — `updateTask` already implemented (Story 1.3); do NOT add `uncompleteTask` method
- `TaskRepositoryProtocol.swift` — `updateTask(_:)` already declared; no changes needed
- `TaskDetailView.swift` — no uncomplete UI in detail view for this story (list-only in Epic 1)
- `TaskDetailViewModel.swift` — no uncomplete action in detail view for this story
- `NotificationService.swift` — no notification changes for uncomplete in Epic 1
- `WidgetService.swift` — no changes needed
- `project.pbxproj` — no new files to register

**Architecture alignment:**
- All uncomplete flows go through `TaskRepository.updateTask(_:)` — never direct `modelContext` manipulation in views [Source: architecture.md#Architectural Boundaries]
- `WidgetService.shared.reloadTimelines()` MANDATORY after every task mutation [Source: architecture.md#Enforcement Guidelines]
- `@MainActor` ViewModel `uncompleteTask` method — called from view's `Task { @MainActor in }` block [Source: architecture.md#AI Agent Guidelines]
- No `withAnimation` for uncomplete — only the complete direction has the spring animation [Source: architecture.md#Frontend/UI Architecture — Animations]

---

### References

- [Source: epics.md#Story 1.7] — Full BDD acceptance criteria for uncomplete task
- [Source: architecture.md#Data Architecture — Conflict Resolution] — `isCompleted` additive rule; `modifiedAt` governs last-write-wins
- [Source: architecture.md#Communication Patterns — Post-Mutation Side Effects] — `WidgetService.reloadTimelines()` mandatory after every mutation
- [Source: architecture.md#Enforcement Guidelines] — NEVER skip WidgetService reload; NEVER call UNUserNotificationCenter directly from views
- [Source: architecture.md#AI Agent Guidelines] — `@Observable` + `@MainActor` for all ViewModels; `@Query` for reactive list display
- [Source: architecture.md#Process Patterns — Error Handling] — Generic "Something went wrong"; never raw error to user; Logger never logs task content
- [Source: implementation-artifacts/1-6-complete-task.md] — `onComplete` callback pattern; TaskListViewModel structure; no new files/pbxproj changes; animation gating
- [Source: Core/Repositories/TaskRepositoryProtocol.swift] — `updateTask(_:)` already declared; use for uncomplete
- [Source: Core/Repositories/TaskRepository.swift] — `updateTask` already implemented (Story 1.3); do NOT reimplement
- [Source: Features/Tasks/TaskRowView.swift] — `onComplete` callback pattern; accessibilityLabel "Mark incomplete" for completed state

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

No debug issues encountered. Implementation followed Dev Notes exactly.

### Completion Notes List

- ✅ Added `uncompleteTask(_ task: TaskItem) async` to `TaskListViewModel.swift` — sets `task.isCompleted = false` and `task.modifiedAt = Date()` on the `@MainActor` ViewModel, then calls `repository.updateTask(task)` and `WidgetService.shared.reloadTimelines()`; catches errors via `handleError(_:)`. No `NotificationService` call per Dev Notes (no reminder to cancel in Epic 1 scope).
- ✅ Updated `TaskRowView.swift` — added `onUncomplete: (() -> Void)? = nil` optional callback; updated `Button` action to conditionally dispatch: `if task.isCompleted { onUncomplete?() }` else `{ existing complete logic with animation }`. Accessibility label "Mark incomplete" for completed tasks unchanged and correct. No animation on uncomplete path; existing `.onChange(of: task.isCompleted)` reset handles cleanup.
- ✅ Updated `TaskListView.swift` — added `onUncomplete` closure to `TaskRowView` call: `Task { @MainActor in await viewModel?.uncompleteTask(task) }`. Consistent with `onComplete` closure pattern.
- ✅ Added `uncompleteTaskSetsIsCompletedFalse` test to `TaskListViewModelTests.swift` — completes task first, then uncompletes, verifies `isCompleted == false` and `showError == false`.
- ✅ Added `uncompleteTaskAlreadyIncompleteNoError` test — calls `uncompleteTask` on already-incomplete task, verifies idempotent with no error.
- ✅ No new files created; no `project.pbxproj` changes needed — all modified files already registered from Stories 1.3–1.6.
- ✅ All Acceptance Criteria satisfied: AC#1 (`uncompleteTask` called, `isCompleted = false` + `modifiedAt = Date()` via `repository.updateTask`, `WidgetService.reloadTimelines()`, reactive `@Query` updates visual state), AC#2 (errors caught, logged privately, generic banner shown), AC#3 (`modifiedAt = Date()` update governs CloudKit last-write-wins propagation).

### File List

TODOApp/TODOApp/Features/Tasks/TaskListViewModel.swift (MODIFIED)
TODOApp/TODOApp/Features/Tasks/TaskRowView.swift (MODIFIED)
TODOApp/TODOApp/Features/Tasks/TaskListView.swift (MODIFIED)
TODOApp/TODOAppTests/TaskListViewModelTests.swift (MODIFIED)
_bmad-output/implementation-artifacts/sprint-status.yaml (MODIFIED)

## Change Log

- 2026-02-18: Story 1.7 implemented — `uncompleteTask(_:)` added to `TaskListViewModel`; `onUncomplete` callback + conditional dispatch added to `TaskRowView`; `onUncomplete` closure wired in `TaskListView`; 2 unit tests added to `TaskListViewModelTests`. No new files; no pbxproj changes. Status set to review. (claude-sonnet-4-6)
