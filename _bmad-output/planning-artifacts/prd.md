---
stepsCompleted: ['step-01-init', 'step-02-discovery', 'step-02b-vision', 'step-02c-executive-summary', 'step-03-success', 'step-04-journeys', 'step-05-domain', 'step-06-innovation', 'step-07-project-type', 'step-08-scoping', 'step-09-functional', 'step-10-nonfunctional', 'step-11-polish']
inputDocuments: []
workflowType: 'prd'
briefCount: 0
researchCount: 0
brainstormingCount: 0
projectDocsCount: 0
classification:
  projectType: mobile_app
  platform: iOS
  domain: general
  complexity: low
  projectContext: greenfield
vision:
  summary: A clean, focused, iOS-native task management experience for capturing, organizing, and completing daily tasks with minimal friction
  differentiator: iOS-only with deep native integration (Widgets, Siri Shortcuts, Focus Modes, iCloud sync) — no cross-platform compromise
  coreInsight: Most TODO apps sacrifice native feel for cross-platform reach; an iOS-first app can deliver an unmistakably native experience
---

# Product Requirements Document — iOS TODO App

**Author:** Root
**Date:** 2026-02-18
**Platform:** iOS only (iPhone + iPad) · Greenfield · General Productivity

---

## Executive Summary

A focused, iOS-native task management application for iPhone and iPad users who want a task manager that feels like it belongs on their device. Existing task managers optimize for the cross-platform lowest common denominator, sacrificing iOS-native feel and deep Apple platform integration. This product is iOS-first by design: built on SwiftUI, synchronized via iCloud, and integrated with Widgets, Siri Shortcuts, and Focus Modes in ways that cross-platform tools cannot match.

**Target Users:** iPhone and iPad owners who rely on iOS as their primary productivity platform.

**Problem Solved:** Cross-platform task managers deliver a foreign experience on iOS — ported UIs, unreliable widgets, no Siri integration, and sync that fights the platform rather than leveraging it.

**What Makes This Special:** The iOS-only constraint is a feature. No cross-platform compromise means full WidgetKit Home Screen widgets at launch, App Intents-powered Siri capture, transparent iCloud sync, and a SwiftUI interface that responds exactly as iPhone users expect. Single-platform focus enables tighter quality, faster iteration, and an experience that no cross-platform tool can replicate.

---

## Success Criteria

### User Success

- Task captured in under 5 seconds from any iOS surface (widget, app, Siri)
- First-time users complete their first task within 60 seconds of install
- 7-day retention rate ≥60%
- In-app satisfaction prompt average ≥4.5 stars
- Users complete the full capture → organize → remind → complete workflow without leaving iOS

### Business Success

- 500+ downloads in first 30 days post-launch
- 4.5-star App Store rating within 60 days (50+ reviews)
- Day-30 retention ≥30%
- 10% conversion to premium tier (if monetized post-MVP)
- App Store editorial consideration ("New Apps We Love" or equivalent)

### Technical Success

- App cold launch <400ms on iPhone XS or newer
- iCloud sync completes within 3 seconds on standard connection
- Zero task data loss across restarts, device switches, and offline periods
- Widget reflects task state changes within 15 minutes
- App Store approval on first submission

### Measurable Milestones

| Milestone | MAU Target | Day-30 Retention | Rating |
|---|---|---|---|
| 3 months | 1,000 | — | ≥4.4 |
| 6 months | 5,000 | ≥25% | — |
| 12 months | 15,000 | ≥25% | Featured |

---

## Product Scope & Phased Development

### MVP Strategy

**Approach:** Experience MVP — validate that iOS-only focus produces a measurably better task management experience. Ship when the four core journeys work flawlessly: capture, organize, remind, complete. Success metric: Day-30 retention ≥30% and App Store rating ≥4.5.

**Resources:** 1 iOS developer (Swift/SwiftUI) + optional iOS HIG-familiar designer. No backend required — CloudKit handles all sync.

### Phase 1 — MVP (Launch)

| Feature | Justification |
|---|---|
| Task creation, editing, deletion | Core product lifecycle |
| Inbox + custom lists | Minimum organization for core journeys |
| Due dates + local notifications | Top retention driver |
| iCloud CloudKit sync | Table stakes for iPhone + iPad users |
| Home Screen widget (small + medium) | iOS-native differentiator — ships at launch |
| Siri Shortcuts (App Intents) | iOS-native differentiator — voice capture |
| SwiftUI UI + system light/dark mode | Native feel is the product promise |
| Task completion animation | Retention-driving dopamine loop |
| Zero-friction first-launch onboarding | Converts downloaders to users |

**Explicitly deferred from MVP:** recurring tasks, sub-tasks/checklists, tags/filters, Spotlight Search, Focus Mode integration, Lock Screen widget, collaboration/shared lists, IAP/monetization.

### Phase 2 — Growth (3–6 months, trigger: Day-30 retention ≥25%)

Recurring tasks · Sub-tasks / checklists · Tags and smart filters · Spotlight Search · Lock Screen widget · Focus Mode integration · Siri natural language parsing

### Phase 3 — Expansion (6–12 months, trigger: 5,000+ MAU)

Apple Watch companion · iPad split-view and drag-and-drop · Shared lists / collaboration · Shortcuts automation · Premium tier / IAP · Mac Catalyst or native macOS app

### Risk Mitigation

| Risk | Mitigation |
|---|---|
| CloudKit sync complexity | Use private CloudKit database; test offline→online and multi-device pre-launch |
| WidgetKit reliability | Build widget first; allocate 20% of build time to device widget testing |
| iOS 16 vs iOS 17 SwiftData | Target iOS 17 + SwiftData; ~80% device coverage acceptable |
| Crowded category | iOS-only is the differentiator; target Apple enthusiast communities |
| App Store rejection | Follow HIG strictly; submit privacy manifest early; budget 2-week review buffer |

---

## User Journeys

### Journey 1: Maya — The Overwhelmed Professional (Primary User, Success Path)

Maya is a 32-year-old product manager. Her tasks live scattered across Notes, her email inbox, and whatever app she downloaded last month. She carries low-grade anxiety that something important is slipping through the cracks.

**Opening Scene:** On her commute, Maya opens the app for the first time, taps "+", and speaks: "Remind me to send the Q2 budget to finance tomorrow at 9am." Task captured in 4 seconds. Relief sets in.

**Rising Action:** That evening she creates a "Work" list, moves the budget task there, and sets a due date. The next morning a Home Screen widget shows 3 tasks for today. At 9am, a notification fires.

**Climax:** Maya sends the budget, marks it done with a satisfying swipe. The widget updates instantly. For the first time her task manager feels like *her phone*.

**Resolution:** Three weeks later, Maya has a consistent capture habit, a 5-star review, and has recommended the app to two colleagues: "It's the only app that actually feels like it was made for iPhone."

*Requirements revealed:* task capture, list management, due dates, local notifications, widget, task completion, iCloud sync

---

### Journey 2: Marcus — The Forgetful Dad (Primary User, Offline Recovery)

Marcus is a 41-year-old contractor who works in areas with spotty coverage. He's lost tasks twice when sync failed in other apps — he doesn't trust any of them.

**Opening Scene:** On a job site with no signal, Marcus adds 4 tasks: pick up kids, call the bank, buy lumber, pay invoice. The app responds instantly — no spinner, no error.

**Rising Action:** At home his tasks are there. When his phone reconnects, iCloud syncs silently. He checks his iPad — everything is present.

**Climax:** "Pay invoice" was added offline with today's due date. Notification fires correctly. He pays with 20 minutes to spare.

**Resolution:** Marcus trusts the app because it never dropped a task. He becomes a Day-30 retained user.

*Requirements revealed:* offline-first persistence, CloudKit sync, notification delivery after reconnect

---

### Journey 3: Jordan — The Power Organizer (Primary User, Growth Discovery)

Jordan is a 28-year-old freelancer who has tried every task app. Cross-platform apps feel "bloated"; simple iOS apps feel "too shallow."

**Opening Scene:** Jordan installs skeptically. She creates 5 lists in 2 minutes. Sets a Siri Shortcut — works on the first try.

**Rising Action:** She discovers widget customization, adds a "Today" widget. Searches Spotlight — tasks appear. She wishes for tags and recurring tasks (post-MVP) but the core is smooth enough.

**Climax:** She configures the app in her Work Focus — only Work tasks show in the widget. Her daily workflow changes. She recommends the app to her newsletter audience.

**Resolution:** Jordan becomes a power advocate. The iOS-native depth is exactly what she was looking for.

*Requirements revealed:* Siri Shortcuts, Spotlight, Focus Mode integration, widget customization

---

### Journey 4: Alex — New User Onboarding (Primary User, First Launch)

Alex is a 19-year-old student who has never used a dedicated task manager.

**Opening Scene:** Alex opens the app. No account creation, no email. A prompt: "What do you want to get done today?" Alex types "Study for physics exam." First task in 8 seconds.

**Rising Action:** The app nudges: "Add it to a list?" Alex creates "School." A contextual tip surfaces the widget. Alex adds it to the Home Screen.

**Climax:** The exam reminder fires. Alex marks it done. Satisfying animation plays.

**Resolution:** Alex uses the app through the semester. Zero-friction onboarding converted a casual downloader.

*Requirements revealed:* no-account first launch, onboarding widget nudge, notification permission prompt, task completion UX

---

### Journey Requirements Summary

| Capability | Release | Journeys |
|---|---|---|
| Task capture (text + Siri) | MVP | Maya, Jordan |
| List creation and management | MVP | Maya, Jordan, Alex |
| Due dates + local notifications | MVP | Maya, Marcus |
| Offline-first persistence | MVP | Marcus |
| iCloud CloudKit sync | MVP | Marcus, Maya |
| Home Screen widget (small + medium) | MVP | Maya, Jordan, Alex |
| Siri Shortcuts (App Intents) | MVP | Maya, Jordan |
| Task completion animation | MVP | Maya, Alex |
| First-launch onboarding | MVP | Alex |
| Spotlight Search | Growth | Jordan |
| Focus Mode widget filtering | Growth | Jordan |

---

## Mobile App Technical Requirements

### Architecture Overview

iOS-native SwiftUI application distributed exclusively via the App Store. No Android, no web, no cross-platform framework. The iOS-only constraint enables full use of Apple platform APIs unavailable to cross-platform tools.

| Component | Technology | Notes |
|---|---|---|
| UI Framework | SwiftUI | iOS 16+ deployment target |
| Local persistence | SwiftData (iOS 17+) | Core Data fallback for iOS 16 — finalize in architecture phase |
| Sync | CloudKit private database | No custom backend for MVP |
| Widgets | WidgetKit | Small + medium home screen; Lock Screen in Growth |
| Voice / Siri | App Intents (iOS 16+) | Not legacy SiriKit |
| Notifications | UserNotifications | Local only — no APNs backend in MVP |
| Search | CoreSpotlight | Growth feature |
| Concurrency | Swift async/await | No completion handlers |

### Platform Requirements

- **Minimum iOS:** 16.0 (~90% active iPhones)
- **Devices:** iPhone (primary) + iPad (adaptive layout)
- **Architecture:** arm64 · **Xcode:** 15+ · **Swift:** 5.9+

### Device Permissions

| Permission | Purpose | Release |
|---|---|---|
| Notifications | Due date reminders | MVP |
| iCloud / CloudKit | Cross-device sync | MVP |
| Siri / App Intents | Voice task capture | MVP |
| Spotlight Indexing | Task search | Growth |
| Focus Filters | Widget list filtering | Growth |

No camera, microphone, location, contacts, or health data accessed.

### Offline & Sync Behavior

- Tasks stored locally first — fully functional without network
- CloudKit sync is additive and transparent; no "sync failed" UI states
- Conflict resolution: last-write-wins for title/body; completion state is additive (never un-completes)
- Offline-created tasks sync within 60 seconds of network restoration

### Notifications

- Local only in MVP — no APNs backend, no push server
- "Mark Done" quick action available directly from notification banner
- No marketing or engagement push notifications in MVP

### App Store Compliance

- Privacy manifest (PrivacyInfo.xcprivacy) required — "Data Not Collected"
- No third-party analytics or telemetry in MVP
- Required entitlements: iCloud, Push Notifications (local), Siri
- Age rating: 4+ · No IAP in MVP (StoreKit 2 if added later)
- Deep link URL scheme for Shortcuts automation

---

## Functional Requirements

### Task Management

- FR1: Users can create a new task with a title
- FR2: Users can edit the title of an existing task
- FR3: Users can delete a task
- FR4: Users can mark a task as complete
- FR5: Users can mark a completed task as incomplete
- FR6: Users can view all tasks in a list
- FR7: Users can set a due date on a task
- FR8: Users can set a reminder time on a task
- FR9: Users can view overdue tasks distinctly from current tasks

### List Organization

- FR10: Users can create a custom list
- FR11: Users can rename a custom list
- FR12: Users can delete a custom list
- FR13: Users can move a task from one list to another
- FR14: Users can view an Inbox list that receives all newly captured tasks by default
- FR15: Users can view tasks filtered by a specific list
- FR16: Users can reorder tasks within a list

### Notifications & Reminders

- FR17: The system delivers a local notification at the user-specified reminder time for a task with a due date
- FR18: Users can take a "Mark Done" action directly from a notification without opening the app
- FR19: Users can dismiss or snooze a task notification from the notification banner
- FR20: The system reschedules notifications after the device reconnects following an offline period

### Widget Surface

- FR21: Users can add a Home Screen widget that displays tasks due today
- FR22: The widget displays in a small (2×2) size configuration
- FR23: The widget displays in a medium (4×2) size configuration
- FR24: Users can tap a task in the widget to open it directly in the app
- FR25: The widget reflects task completion state changes within 15 minutes

### Siri & Voice Capture

- FR26: Users can capture a new task via Siri using a voice phrase
- FR27: Users can configure a custom Siri Shortcut phrase for task capture
- FR28: Tasks created via Siri are added to the user's Inbox list

### Sync & Data

- FR29: Users can access their tasks on any iOS device signed into the same iCloud account
- FR30: Users can create, edit, and complete tasks while offline
- FR31: The system syncs offline changes to iCloud when network connectivity is restored
- FR32: The system preserves all tasks across app restarts and device reboots
- FR33: The system resolves sync conflicts without data loss

### Onboarding

- FR34: New users can create their first task without creating an account or providing an email
- FR35: The app guides new users to add a Home Screen widget after creating their first task
- FR36: The app prompts users to enable notifications when they first set a due date

### System Integration

- FR37: Users can navigate to a specific task via iOS Spotlight search *(Growth)*
- FR38: Users can configure Focus Mode filters to show only relevant lists in the widget *(Growth)*
- FR39: Users can access the app via a custom URL scheme for Shortcuts automation

### Appearance & Settings

- FR40: Users can view the app in light mode
- FR41: Users can view the app in dark mode
- FR42: The app follows the system appearance setting by default
- FR43: Users can view their iCloud sync status

---

## Non-Functional Requirements

### Performance

- NFR1: App cold launch completes in <400ms on iPhone XS or newer
- NFR2: All user actions (task create, complete, list navigation) respond within 100ms
- NFR3: iCloud sync round-trip completes within 3 seconds on standard broadband
- NFR4: Home Screen widget timeline refreshes within 15 minutes of any task state change
- NFR5: Widget tap-to-open deep link launches the app within 200ms

### Reliability & Data Integrity

- NFR6: Zero task data loss — all tasks survive app crashes, OS terminations, and device reboots
- NFR7: Offline-created tasks sync within 60 seconds of network restoration
- NFR8: iCloud sync conflicts resolved without deleting or corrupting task data
- NFR9: Local notifications fire within 60 seconds of their scheduled time
- NFR10: Widget displays accurate task state within 15 minutes of any state change

### Security & Privacy

- NFR11: All task data stored in user's private iCloud container — inaccessible to other apps or users
- NFR12: No user data transmitted to any third-party server in MVP
- NFR13: App includes a complete PrivacyInfo.xcprivacy manifest declaring all data access patterns
- NFR14: No analytics, crash reporting, or telemetry SDKs access user task content in MVP
- NFR15: App Store privacy nutrition label: "Data Not Collected"

### Accessibility

- NFR16: All interactive elements support VoiceOver with accurate, descriptive labels
- NFR17: Full Dynamic Type support — all text scales with user's preferred font size
- NFR18: Color contrast meets WCAG 2.1 AA (4.5:1 normal text, 3:1 large text)
- NFR19: Reduce Motion setting suppresses all animations
- NFR20: All task actions operable without multi-finger gestures

### System Integration Quality

- NFR21: Siri Shortcuts respond within 2 seconds of voice phrase completion
- NFR22: App Intents appear in the Shortcuts app within 24 hours of install
- NFR23: WidgetKit timeline provides entries for at least the next 24 hours on each refresh
- NFR24: CloudKit operations run on background threads — never block the main thread
- NFR25: Local notification scheduling survives app backgrounding and device relock

---

*This PRD is the capability contract for all downstream UX, architecture, and development work. Any capability not listed in Functional Requirements does not exist in the product unless explicitly added.*
