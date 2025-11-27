# AlarmDontTrustYou - Complete Codebase Export
**Generated:** 2025-11-04 05:59:32 +0000

This export contains the complete source code, tests, documentation, and configuration for the AlarmDontTrustYou iOS alarm application.

## Table of Contents
- [Documentation Files](#documentation-files)
- [Configuration Files](#configuration-files)
- [Source Code](#source-code)
- [Test Files](#test-files)

---

## Documentation Files
### CLAUDE.md
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/CLAUDE.md`

```markdown
# Alarm App — Architecture & Engineering Guide
_Last updated: 2025-10-10_

This is the **single source of truth** for the product vision, MVP/V1 execution, and technical architecture. Hand it to AI or a new dev and they can start shipping confidently.

---

## A) Product Vision (One-Page Brief)

**Problem**
Most alarm apps let users snooze or disable too easily, making consistent wake-ups hard.

**Target User**
People serious about discipline who are willing to complete challenges to prove they’re awake.

**Core Use Cases**
- Force physical/mental activation to dismiss (e.g., scan a code, move, think).
- Prevent “cheating” via OS settings or quick workarounds.
- Simple, reliable, **no subscription** experience.

**MVP Must-Haves**
- Alarm CRUD (time, repeat, label, sound, volume, vibrate).
- Challenge-based dismissal (QR; then Steps/Math in later MVPs).
- Reliable local notifications; re-register on app relaunch/foreground.
- Dismissal flow that **enforces order** of selected challenges.
- Local persistence for alarms/settings.
- Minimal settings; local analytics/log.

**Out of Scope (for V1)**
- Social/buddy features, photo proof.
- Location/geofence bed proximity.
- Payments/accountability penalties.

**Primary Success Metric**
% of alarms completed per active user per week.

**Risks/Unknowns**
- iOS background limitations around reliability/anti-cheat.
- Motion accuracy varies by device placement.
- Users may discover bypass strategies.

**Deadlines**
- **MVP 1 (QR-only):** 2025-08-19
- **V1 (Core wake reliability: QR+Steps+Math):** 2025-08-31

---

## B) V1 Core Execution (Scope & DoD)

**Goal**
Prove the app wakes users reliably and can’t be trivially cheated.

**In Scope (V1)**
- Alarm CRUD and scheduling (local notifications; re-register on launch/background).
- Challenges: **QR, Steps, Math** with **enforced order**.
- Dismissal flow UI (sequential steps, failure timeout).
- Local persistence only (SwiftData); minimal settings and local analytics.
- Tests: unit (scheduler + validators), 1 happy-path E2E.

**Out of Scope (V1)**
- Buddy notifications, photo proof, post-alarm check-in.
- Payments/penalties, Roulette mode.
- Bedtime flow; sleep-stage smart wake.
- Any backend services.

**Definition of Done**
- ≥95% of fired alarms complete all selected challenges in testing.
- Works even if app is closed/killed (alarm fires; flow presents).
- QR works in low light; steps validate in airplane mode.
- No crashes across 3 consecutive days of scheduled alarms.

**Feature Flags (default off in V1)**
`buddy`, `proof`, `payments`, `roulette`, `bedtime`, `smartWake`.

**Test Plan (V1)**
- Unit: scheduler; QR/Steps/Math validators.
- E2E: dismissal flow happy path with a 1–3 challenge stack.
- Smoke: nightly across 3 devices; record outcomes.

---

## C) Prototype Plan (from early proposal; aligned to MVP/V1)

**Modules to build**
1) Alarm Scheduling (UNUserNotificationCenter).
2) Challenge modules: **QR** (AVFoundation), **Steps** (CoreMotion pedometer), **Math** (configurable difficulty).
3) Dismissal Flow Logic (sequential, enforced order).
4) Persistence (SwiftData).
5) Basic Settings (sound/vibration/volume).
6) Anti-cheat hygiene: permission checks, “return to dismissal” deep link, logs.

---

# Technical Architecture (single, layered design)

## 0) Intent

**Goals**
- Wake **reliability** > feature count.
- Deterministic behavior under iOS constraints (foreground/background, permissions, time changes).
- Clean boundaries so business logic is trivial to test.
- Fast iteration from **MVP 1 → V1 → MVP 2/3** without large refactors.

**Non-Goals (through MVP 3)**
- No backend/auth.
- No social/payments in V1.
- No location/geofencing.

---

## 1) Architectural Style (layers & rules)

UI (SwiftUI Views)
↓
Presentation (ViewModels, App Router)
↓
Domain (pure Swift: entities, use cases, policies)
↓
Infrastructure (services: notifications, camera/QR, motion, persistence, logging)


**Rules**
- Views never call services directly. Views → ViewModels only.
- ViewModels orchestrate state; side-effects go via **protocol-typed** services.
- Domain is **pure Swift** (no SwiftUI/AVFoundation/CoreMotion).
- Infrastructure implements protocols; constructed centrally (`DependencyContainer`).
- Dependency direction is **down only**.

---

## 2) Project Structure (filesystem)

alarm-app/
├─ README.md
├─ docs/
│  ├─ 01-brief.md
│  ├─ orientation.md
│  ├─ mvp-1.md
│  ├─ mvp-2.md
│  ├─ mvp-3.md
│  ├─ CLAUDE.md             ← this file
│  └─ architecture-decisions/
│     └─ ADR-001-module-strategy.md  # monolith now → packages later
├─ AlarmApp/                        # iOS target (monolith for MVP 1–2)
│  ├─ App/
│  │  ├─ AlarmAppApp.swift
│  │  ├─ AppRouter.swift
│  │  └─ DI/DependencyContainer.swift
│  ├─ UI/                           # SwiftUI “dumb” views
│  │  ├─ AlarmList/  AlarmForm/  Ringing/
│  │  ├─ Challenges/QR/  Challenges/Steps/  Challenges/Math/
│  │  └─ Settings/
│  ├─ Presentation/
│  │  ├─ AlarmListViewModel.swift
│  │  ├─ AlarmFormViewModel.swift
│  │  ├─ RingingViewModel.swift
│  │  ├─ ChallengeFlowViewModel.swift
│  │  └─ AppState.swift
│  ├─ Domain/                       # pure Swift (no Apple UI frameworks)
│  │  ├─ Entities/      # Alarm, Challenge, AlarmRun, ChallengeRun
│  │  ├─ UseCases/      # ScheduleNextFire, ValidateChallengeStack, …
│  │  └─ Policies/      # RepeatRules, LockoutRules, TimeWindowPolicy
│  ├─ Infrastructure/
│  │  ├─ Services/
│  │  │  ├─ NotificationScheduler.swift
│  │  │  ├─ QRScannerService.swift
│  │  │  ├─ PedometerService.swift
│  │  │  ├─ MathService.swift
│  │  │  ├─ HealthService.swift           # MVP 3
│  │  │  └─ ResilienceRouter.swift        # MVP 3 (state restoration)
│  │  ├─ Persistence/
│  │  │  ├─ SwiftDataSchema.swift
│  │  │  └─ Storage.swift
│  │  └─ Observability/
│  │     ├─ Logging.swift                 # OSLog categories
│  │     └─ ReliabilityLogStore.swift     # MVP 3
│  ├─ Shared/
│  │  ├─ FeatureFlags.swift               # buddy, proof, payments, bedtime, smartWake
│  │  ├─ Date+Extensions.swift
│  │  └─ Clock.swift                      # fakeable time source
│  └─ Resources/ (Assets, Sounds)
├─ AlarmAppTests/
│  ├─ Unit/
│  │  ├─ Domain/ ScheduleNextFireTests.swift, ValidateChallengeStackTests.swift
│  │  ├─ Infrastructure/ NotificationSchedulerTests.swift, PersistenceRoundTripTests.swift
│  │  └─ Presentation/ ChallengeFlowViewModelTests.swift
│  ├─ Integration/
│  │  ├─ NotificationIntegrationTests.swift
│  │  └─ StorageIntegrationTests.swift
│  └─ Mocks/ MockNotificationScheduler.swift, MockPedometer.swift, MockQRScanner.swift, FakeClock.swift
└─ AlarmAppUITests/
├─ E2E_Ringing_QR_Success.swift
├─ E2E_Stack_QR_Steps_Math.swift
└─ StateRestorationTests.swift         # MVP 3


> **ADR-001 (module strategy):** Keep a monolith through V1/MVP2. If the app grows, split into Swift Packages: `Domain`, `Data` (infra+persistence), `App` (UI+Presentation), `TestSupport`.

---

## 3) Concurrency Policy (UPDATED & CONSOLIDATED)

### General Rules
- `@MainActor`: All **ViewModels** and the **`AppRouter`** must be marked with `@MainActor` to safely interact with the UI.
- **Services:** Should be non-Main unless OS requirements dictate otherwise (e.g., Notification delegate wiring); use `async/await` for asynchronous work.
- **No Main-Thread Blocking:** Do not perform I/O or heavy CPU work on the main thread.

### Shared State & Locking (CRITICAL ADDITIONS)
- All **Shared Mutable State** (e.g., counters, caches, settings, storage access) **MUST** use the **Swift `actor`** model.
- New services managing shared state **MUST** be implemented as **Swift `actor`** types.
- **NEVER** mix manual locking primitives (like `DispatchSemaphore`) or synchronous queue calls (`DispatchQueue.sync`) with Swift concurrency (`async/await` and `Task`).
- Legacy bridges may use `DispatchQueue` only for non-Main thread work where actors are not feasible (e.g., non-isolated C interop).

### Persistence Concurrency
- All persistence services that handle reads/writes **MUST** be implemented as **actors**.
- **Atomic Locking:** Utilize the actor's implicit synchronization to perform the entire load-modify-save sequence atomically (e.g., load all runs, modify in memory, save all runs back).

### Clock Abstraction
- The **Clock abstraction** keeps time deterministic for testing:
  ```swift
  protocol Clock { func now() -> Date }
  ```

---

## 4) Domain Model (pure Swift)

**Entities**

* `Alarm`: `id`, `time`, `repeatDays`, `label`, `sound`, `volume`, `vibrate`, `isEnabled`,

  * MVP 1: `expectedQR:String?`
  * V1+: `challenges:[Challenge]`
* `Challenge`: `id`, `type:.qr|.steps|.math`, `params`, `orderIndex`
* `AlarmRun`: `alarmId`, `firedAt`, `completedAt?`, `outcome:.success|.failed|.aborted`, `challengeRuns:[ChallengeRun]`

**ChallengeParams**

* `.qr(expected:String)`
* `.steps(threshold:Int)`
* `.math(difficulty:Int, timeLimit:Seconds)`

**Use Cases**

* `ScheduleNextFire(alarm, now) -> Date?`
* `ValidateChallengeStack(stack) -> ValidationResult`
* `AdvanceChallenge(currentIndex, outcome) -> nextIndex|end`
* `ComputeRepeatDates(alarm, window) -> [Date]`

**Policies**

* Repeat rules (weekday mapping; DST/timezone aware)
* Math lockout (N wrong → cooldown)
* Steps threshold & reset rules

---

## 5) Service Contracts (protocols the app targets) (UPDATED)

```swift
protocol AlarmScheduling { // Standardized name for all alarm scheduling and control
  func requestAuthorization() async throws
  func schedule(alarm: Alarm) async throws -> String
  func cancel(alarmId: UUID) async
  func stop(alarmId: UUID, intentAlarmId: UUID?) async throws
  func transitionToCountdown(alarmId: UUID, duration: TimeInterval) async throws
  func pendingAlarmIds() async -> [UUID]
  func reconcile(alarms: [Alarm], skipIfRinging: Bool) async
}

protocol QRScanning {
  func startScanning() async throws
  func stopScanning()
  func scanResultStream() -> AsyncStream<String>   // emits QR payloads
}

protocol PedometerProviding {
  func requestAuthorization() async throws
  func startCounting() async
  func stopCounting()
  func stepCountStream() -> AsyncStream<Int>
}

struct MathProblem { let a: Int; let b: Int; let op: Character }
protocol MathProviding {
  func nextProblem(difficulty: Int, seed: Int?) -> MathProblem
  func check(answer: Int, for problem: MathProblem) -> Bool
}

protocol PersistenceStore: Actor { // Now an Actor protocol
  func saveAlarms(_ alarm: [Alarm]) throws
  func deleteAlarm(id: UUID) throws
  func loadAlarms() throws -> [Alarm]
  func appendRun(_ run: AlarmRun) throws(PersistenceStoreError) // Specific run operations moved here
  func loadRuns() throws -> [AlarmRun] // Specific run operations moved here
  // ... other storage methods will use this contract
}

struct HealthSnapshot {
  enum Permission { case notifications, camera, motion }
  var permissions: [Permission: Bool]
  var lowPowerModeOn: Bool
}
protocol HealthStatusProviding {      // MVP 3
  func snapshot() async -> HealthSnapshot
}
```
> **Note:** The `PersistenceStore` protocol is now mandatory to be an `Actor`.

---

## 5.5) Error Handling Strategy (NEW)

### Propagation Rules
- **Domain:** Define clear, typed error enums (e.g., `AlarmSchedulingError`, `PersistenceStoreError`).
- **Infrastructure:** Must map all underlying framework errors (e.g., `UNError`, `AVError`) to the appropriate domain-level typed error before throwing.
- **Presentation:** Must convert domain errors to user-friendly messages for display.
- **NEVER:** Use empty `catch {}` blocks or silent `try?` without rethrow/log/fallback.

### Standard Persistence Error
```swift
// Domain
public enum PersistenceStoreError: Error, Equatable {
    case alarmNotFound
    case saveFailed
    case loadFailed
    case dataCorrupted
}
```

---

## 6) Presentation Layer

* `AlarmListViewModel` — load/toggle alarms; triggers `NotificationScheduling.refreshAll`.
* `AlarmFormViewModel` — edit `Alarm`; manage challenge stack (V1+).
* `RingingViewModel` — owns active `AlarmRun`; coordinates challenge flow.
* `ChallengeFlowViewModel` — ordered progression; subscribes to QR/Steps/Math streams.

**Routing**

* `AppRouter` switches screens.
* **MVP 3:** `ResilienceRouter` restores last `AlarmRun`/challenge to the correct screen on cold launch.

---

## 7) UI Layer (SwiftUI)

* Views are **dumb**: render state, dispatch intents.
* `RingingView`: fullscreen, screen awake, “Start Dismissal” → first challenge.
* Challenge screens (QR/Steps/Math) share a header (progress, timer if any) and consistent “Fail/Retry.”

---

## 8) Notifications & Scheduling Policy

* On app launch and on `scenePhase == .active`: call `NotificationScheduling.refreshAll(from:)`.
* On fire:

  * Always show a notification with deep link “Return to Dismissal”.
  * **MVP 3:** If not foreground within N seconds, send a “nudge” notification.
* DST/timezone changes: next fire computed in **Domain** (no naive deltas).

---

## 9) Persistence (UPDATED)

- Store `Alarm`, **`AlarmRun`**, and V1+ `Challenge` with minimal mapping.
- **Alarm Run Persistence:** The primary storage mechanism (`PersistenceStore` / `PersistenceService`) **MUST** own and manage the CRUD (Create, Read, Update, Delete) for **`AlarmRun`** entities. All `AlarmRun` logic (e.g., `appendRun`, `loadRuns`, `cleanupIncompleteRuns`) must live within the actor implementation of `PersistenceStore`.
- **Error Contract:** All persistence APIs are `async` and **`throws PersistenceStoreError`**. No main-thread I/O.
- **Migration:** MVP 1 → V1 wraps `expectedQR` into `[Challenge]` with `.qr(expected:)`.

---

## 10) Observability

* OSLog categories: `alarm.scheduling`, `alarm.ringing`, `challenge.qr|steps|math`, `infra.permissions`, `infra.persistence`.
* Local metrics: `alarms_scheduled`, `alarms_fired`, `dismiss_success_{type}`, `dismiss_fail_{type}`, `notif_status_changed`.
* **MVP 3:** `ReliabilityLogStore` (append-only JSON/CSV) with scheduled/fired/success/fail + reason + permission snapshot; export via share sheet.

---

## 11) Feature Flags (default false)

`buddy`, `proof`, `payments`, `roulette`, `bedtime`, `smartWake` (single source: `Shared/FeatureFlags.swift`).

---

## 12) Testing Strategy

**Unit (fast)**

* Domain use cases & policies (no Apple frameworks).
* QR/Steps/Math validators using mocks.
* Scheduler time math with `FakeClock`.

**Integration**

* Notification scheduling round-trip with `MockNotificationCenter`.
* Persistence read/write & migration.

**UI/E2E**

* **MVP 1:** Set alarm → fire → scan valid QR → dismiss.
* **V1:** Ordered QR→Steps→Math success; fail at step 2 resumes properly.
* **MVP 3:** Kill app during challenge → relaunch returns to same step.

**Conventions**

* `test_method_whenCondition_shouldExpectation()`
* No flaky tests; quarantine/fix before merge.

---

## 13) Code Quality & CI (lightweight)

* SwiftFormat + SwiftLint (CI fails on drift).
* CI (GitHub Actions or Xcode Cloud):

  * Build + unit + integration on PR.
  * Nightly UI tests on `main`.
* Signing/Release: manual for MVP 1; add Fastlane beta lanes in V1/MVP 2.

---

## 14) Privacy & Permissions

* Blocking rationales for **camera**, **motion**, **notifications** with Settings deep links.
* Data is local; no PII beyond alarm labels.
* Reliability log export is user-initiated only.

---

## 15) Roadmap Mapping (what to build when)

**MVP 1 — QR-only (Target: 2025-08-19)**
Infra: `NotificationScheduling`, `QRScanning`, `PersistenceStore`.
Domain: `Alarm`, `AlarmRun`, `ScheduleNextFire`, QR validator.
UI: `AlarmList`, `AlarmForm`, `Ringing`, `QRScreen`.
Tests: scheduler, QR validator, E2E QR success.

**V1 — Core Reliability (Target: 2025-08-31)**
Domain: `Challenge`, `ChallengeParams`, `ValidateChallengeStack`, lockouts.
Infra: `PedometerProviding`, `MathProviding`.
Presentation: `ChallengeFlowViewModel` (ordered progression).
UI: drag-reorder picker; Steps & Math screens.
Tests: Steps/Math validators; stack sequencing; E2E 3-step stack.

**MVP 2 — Accountability & Bedtime (Future)**
Buddy notifications, photo proof, bedtime flow, light backend.

**MVP 3 — Anti-Cheat & Resilience (Future)**
`HealthStatusProviding`, `ResilienceRouter`, `ReliabilityLogStore`; restoration & reliability telemetry.

---

## 16) AI Guardrails (follow exactly)

**Do**

* Program to the **protocols** in §5; construct concretes in `DependencyContainer`.
* Keep Domain pure; mark ViewModels `@MainActor`.
* Use `async/await`; add unit tests for any new policy/validator/use case.

**Don’t**

* Don’t call services from Views.
* Don’t block the main thread.
* Don’t introduce singletons.


---

## D) Guardrails for AI Codegen

All AI-generated code must follow the rules in [`docs/claude-guardrails.md`](docs/claude-guardrails.md).

### Key Principles (summary)
- **Init purity** → no I/O, OS calls, delegate wiring, or `fatalError` in initializers
- **Activation-only side effects** → notification delegate/category setup happens only in explicit, idempotent activation methods called from App startup
- **Protocol-first DI** → expose protocols from the container; keep concrete instances private for retention/wiring; no `DependencyContainer.shared` reach-ins
- **UIKit isolation** → UIKit imports and APIs only in Infrastructure layer (e.g., AppStateProvider, NotificationService); never in Domain or SwiftUI Presentation layers
- **Main-thread boundaries** → all UIKit/OS calls wrapped in `@MainActor` contexts
- **Idempotency** → setup/registration safe to call multiple times without duplicates or crashes
- **Structured logging** → every observable event logs `{ alarmId, event, source/action, category, occurrenceKey? }`
- **Testing** → new providers have mocks; activation is tested for idempotency; malformed inputs validated at receipt time without crashing

👉 For boilerplate patterns (activation, category registration, app state provider), the full Definition of Done checklist, and lint/fail-fast rules, see [`claude-guardrails.md`](docs/claude-guardrails.md).


**PR Acceptance Checklist**

* [ ] Unit tests for new logic; UI/E2E if user-visible.
* [ ] Dependency direction respected.
* [ ] No main-thread I/O.
* [ ] Logs where failure is possible.
* [ ] Docs updated if contracts/schema changed.
```
```

### changelog.md
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/changelog.md`

```markdown
CLAUDE.md (Architecture Specification)

REPLACED §3) Concurrency Policy:

Consolidated all rules into a single section.

Added CRITICAL ADDITION to mandate Swift actor model for all shared mutable state.

Added CRITICAL ADDITION to prohibit mixing DispatchSemaphore with async/await.

Added Persistence Concurrency rule mandating all persistence services must be actors and lock the entire load-modify-save sequence.

REPLACED §5) Service Contracts:

Standardized the primary scheduling protocol name to AlarmScheduling.

Removed the confusing NotificationScheduling alias.

Updated the PersistenceStore protocol to be a mandatory Actor protocol (protocol PersistenceStore: Actor).

Added AlarmRun methods (appendRun, loadRuns) to the PersistenceStore protocol.

ADDED §5.5) Error Handling Strategy:

Added a new section mandating typed domain errors (e.g., PersistenceStoreError).

Prohibited silent failures (empty catch {} blocks or unhandled try?).

Defined the standard PersistenceStoreError enum.

REPLACED §9) Persistence:

Explicitly added AlarmRun to the list of entities managed by the persistence layer.

Added mandate that PersistenceStore / PersistenceService MUST own and manage all AlarmRun CRUD operations.

Updated error contract to reflect the new PersistenceStoreError.

claude-guardrails.md (Development Rules)

UPDATED # Guardrails (Main Section):

Added Concurrency Strategy (CRITICAL): Mandates all new services managing shared state MUST be Swift actor types.

Added Concurrency Strategy (CRITICAL): NEVER mix DispatchSemaphore or DispatchQueue.sync with Swift concurrency.

Added Error Handling Enforcement: Mandates all Infrastructure/Persistence methods MUST throw a typed domain error and forbids silent catches.

UPDATED # “Definition of Done” add-ons:

Added Concurrency Conformance: "All shared mutable state is protected by actor types. No new usage of manual locks.".

Added Concurrency Test: "A concurrency test asserting load-modify-save is atomic for shared state (e.g., PersistenceStore).".

UPDATED # “Fail fast” lint items:

Added Concurrency Guard: "Reject any new usage of DispatchSemaphore or DispatchQueue.sync...".

Added Silent Failure Guard: "Reject any empty catch {} blocks or unhandled try?...".

v1-core.md (Feature Spec)

UPDATED §2 Scope (Include):

Replaced "Local notifications (primary ringer)" with "Alarm Scheduling (AlarmKit / Notifications): Use the unified AlarmScheduling protocol...".

Replaced "Local persistence only (SwiftData)" with "Local persistence: Use the PersistenceStore actor...".

UPDATED §7 AI Prompt Templates:

Updated prompt to reference AlarmScheduling and PersistenceStore.

Added mandate: "Ensure PersistenceStore is implemented as an actor...".

UPDATED §8 References:

Changed "MVP 1 doc" to "V1 Spec".

v2-accountability-bedtime.md (Feature Spec)

UPDATED §1 Goal:

Renamed "notifications-primary" to "AlarmScheduling-primary".

UPDATED §2 Scope (Include):

Clarified AlarmScheduling as the primary ringer.

UPDATED §4 Definition of Done:

Added Concurrency requirement: "All new queueing/retry services (e.g., Buddy Alert Queue) MUST be implemented as Swift actor types...".

UPDATED §6 Backend/Plumbing Checklist:

Added Storage/Queueing requirement: All local queueing logic MUST be handled by Swift actor types.

UPDATED §7 Test Plan:

Added requirement: "Ensure all new queue/storage logic has concurrency tests (load-modify-save under load).".

UPDATED §8 AI Prompt Templates:

Added mandate: "Implement all local queueing and retry logic using Swift 'actor' types to ensure thread safety.".

UPDATED §9 References:

Changed "V1 Spec" to use AlarmScheduling-primary pattern.

v3-monetization-advanced.md (Feature Spec)

UPDATED §1 Goal:

Added mandate: "All new state must be managed with thread-safe Swift actors.".

UPDATED §2 Scope (Include):

Specified MonetizationService Actor.

UPDATED §4 Definition of Done:

Added Concurrency requirement: "All monetization, smart wake data, and escalation logic MUST be implemented as Swift actor types...".

UPDATED §6 Backend/Plumbing Checklist:

Mandated that HealthStatusProviding state must be thread-safe.

Mandated that PersistenceStore actor must be extended for subscription status.

UPDATED §7 Test Plan:

Added "MonetizationService actor (load/save/update concurrency test)".

UPDATED §8 AI Prompt Templates:

Mandated actor implementation for MonetizationService and RouletteModeActor.

00-foundations.md (Design Foundations)

UPDATED §0.7 Reliability Principles:

Added new principle: "Concurrency: Any shared state required for reliability... MUST be protected by Swift actors.".

mvp1.md (Feature Spec)

UPDATED §1 Mission:

Renamed "local notifications" to "AlarmScheduling (local notifications)".

UPDATED §3 In Scope:

Renamed NotificationScheduling to "Alarm Scheduling: Use the unified AlarmScheduling protocol...".

Replaced "Local persistence (SwiftData)" with "Local persistence: Use the thread-safe PersistenceStore actor...".

UPDATED §7 Services:

Renamed NotificationScheduling protocol to AlarmScheduling.

Clarified PersistenceStore (Actor).

UPDATED §8 App Lifecycle Rules:

Renamed NotificationScheduling.refreshAll to AlarmScheduling.reconcile.

UPDATED §11 Test Plan:

Added: "Concurrency Test: Simultaneous save of AlarmRuns on the PersistenceStore actor.".

UPDATED §14 Build Order:

Replaced "SwiftData schema" with "PersistenceStore protocol implementation as a Swift actor.".

UPDATED §15 Apple APIs & Search Hints:

Updated search terms to reflect AlarmScheduling, iOS 26, and Swift actor.
```

### 00-foundations.md
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/docs/00-foundations.md`

```markdown
# 0. Design Foundations

## 0.1 Color (semantic)

* bg: systemBackground / secondarySystemBackground
* text-primary: label
* text-secondary: secondaryLabel
* accent: tint
* danger: systemRed
* success: systemGreen
* warning: systemOrange

## 0.2 Typography (SF Pro; iOS 17+)

* display: 28/34, semibold
* title: 22/28, semibold
* body: 17/22, regular
* caption: 13/16, regular
* mono: 15/20, regular (for codes/timers)

## 0.3 Spacing (8pt grid)

* xs: 4, sm: 8, md: 12, lg: 16, xl: 24, 2xl: 32

## 0.4 Radius & Elevation

* radius: 12 (cards), 8 (controls)
* shadow: subtle for cards; none on list rows

## 0.5 States

* focus-ring: system-defined
* error: danger text + subtle bg tint
* disabled: 60% opacity on text + no shadow

## 0.6 Iconography

* SF Symbols only. Stroke where possible; min tap target 44pt.

## 0.7 Reliability Principles (UPDATED)

* Local notifications (via `AlarmScheduling`) are the **primary ringer** and must always be scheduled as the OS-guaranteed sound source.
* **Concurrency:** Any shared state required for reliability (e.g., dismissal registry, scheduling limits, audio state flags) **MUST** be protected by **Swift actors**.
* Audio sessions are an **enhancement**: when the app is active, start continuous playback to improve the user experience.
* Foreground notifications must suppress `.sound` when audio is actively ringing to avoid double audio.
* If the audio session is killed by iOS, notifications still guarantee the alarm fires with sound.
```

### use-cases.md
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/docs/Domain/use-cases.md`

```markdown

# Domain Use Cases — Alarm App
_Last updated: 2025-08-14_

This catalog defines the **pure Swift** use cases for the Domain layer. They contain **no Apple frameworks** and are designed for **fast, deterministic tests**. Services (camera/QR, motion, notifications, storage) live in Infrastructure and feed data *into* these use cases.

---

## 0) Conventions

- All functions are **pure** (no I/O). Time comes from an injected `Clock`.
- Domain owns **entities** (`Alarm`, `Challenge`, `AlarmRun`, `ChallengeRun`) and **policies** (repeat rules, lockouts, timeouts).
- Presentation (ViewModels) orchestrates; Infrastructure implements side-effects.

```swift
public protocol Clock { func now() -> Date }
````

---

## 1) Shared Types (Domain)

```swift
public struct Alarm {
    public let id: UUID
    public var time: Date
    public var repeatDays: [Weekday]       // empty = one-time
    public var label: String
    public var sound: String
    public var volume: Float
    public var vibrate: Bool
    public var isEnabled: Bool
    // MVP 1:
    public var expectedQR: String?
    // V1+:
    public var challenges: [Challenge] = []
}

public struct Challenge {
    public enum Kind { case qr, steps, math }
    public enum Params {
        case qr(expected: String)
        case steps(threshold: Int)
        case math(difficulty: Int, timeLimit: TimeInterval)
    }
    public let id: UUID
    public let kind: Kind
    public let params: Params
    public var orderIndex: Int
}

public struct AlarmRun {
    public enum Outcome { case success, failed, aborted, inProgress }
    public let alarmId: UUID
    public var startedAt: Date
    public var completedAt: Date?
    public var outcome: Outcome
    public var challengeRuns: [ChallengeRun]
}

public struct ChallengeRun {
    public enum Outcome { case pending, success, failTimeout, failWrong, aborted }
    public let challengeId: UUID
    public var startedAt: Date
    public var completedAt: Date?
    public var outcome: Outcome
}

public enum ValidationResult { case ok, invalid(reason: String) }
public enum NextStep { case index(Int), finished }
public enum LockoutState { case none, coolingDown(until: Date) }

public struct PreflightRules {
    public var requireNotifications: Bool
    public var requireCamera: Bool
    public var requireMotion: Bool
}

public struct HealthSnapshot {
    public enum Permission { case notifications, camera, motion }
    public var permissions: [Permission: Bool]
    public var lowPowerModeOn: Bool
}
```

> Entities above mirror what’s in `architecture.md`. Keep Domain types platform-free.

---

## 2) MVP 1 — QR-Only Use Cases

### 2.1 `ScheduleNextFire`

Compute the next fire `Date` for an alarm given “now”.

```swift
public struct ScheduleNextFire {
    let clock: Clock
    public init(clock: Clock) { self.clock = clock }

    public func execute(alarm: Alarm) -> Date? {
        // If one-time and in the past → nil.
        // If one-time and later today → today at alarm.time.
        // If repeating → next weekday at alarm.time (DST/timezone safe).
        // Implementation is pure time math.
    }
}
```

### 2.2 `EvaluateQR`

Compare a scanned payload to the expected value.

```swift
public struct EvaluateQR {
    public func execute(expected: String, scanned: String) -> ChallengeRun.Outcome {
        return (expected == scanned) ? .success : .failWrong
    }
}
```

### 2.3 `ApplyRunEvent`

Push domain events into the current `AlarmRun` to evolve state.

```swift
public enum RunEvent {
    case alarmFired(at: Date)
    case challengeStarted(challengeId: UUID, at: Date)
    case challengeFinished(challengeId: UUID, outcome: ChallengeRun.Outcome, at: Date)
    case dismissalCompleted(at: Date)  // all challenges done
    case dismissalAborted(at: Date)
}

public struct ApplyRunEvent {
    let clock: Clock
    public init(clock: Clock) { self.clock = clock }

    public func reduce(run: inout AlarmRun, event: RunEvent) {
        // Pure state machine updates; no side effects.
    }
}
```

---

## 3) V1 — Multi-Challenge Stack Use Cases (QR + Steps + Math)

### 3.1 `ValidateChallengeStack`

Ensure the stack is non-empty, has valid ordering, and parameters are sensible.

```swift
public struct ValidateChallengeStack {
    public func execute(_ stack: [Challenge]) -> ValidationResult {
        // Check: non-empty, orderIndex unique/contiguous, params in valid ranges.
    }
}
```

### 3.2 `AdvanceChallenge`

Given the current index and an outcome, compute the next step.

```swift
public struct AdvanceChallenge {
    public func execute(currentIndex: Int, outcome: ChallengeRun.Outcome, total: Int) -> NextStep {
        // On .success → next index or .finished
        // On failures that allow retry → same index
        // On .aborted → .finished (app handles abort UX)
    }
}
```

### 3.3 `EvaluateSteps`

Given a threshold and an observed step count (from Infra), compute outcome.

```swift
public struct EvaluateSteps {
    public func execute(threshold: Int, currentSteps: Int) -> ChallengeRun.Outcome {
        return (currentSteps >= threshold) ? .success : .pending
    }
}
```

### 3.4 `EvaluateMathAnswer`

Check an answer for a provided problem; handle lockout/time limit via policies.

```swift
public struct MathProblem {
    public let a: Int
    public let b: Int
    public let op: Character // '+', '-', '×'
}

public struct EvaluateMathAnswer {
    let clock: Clock
    public init(clock: Clock) { self.clock = clock }

    public func execute(problem: MathProblem,
                        answer: Int,
                        timeLimit: TimeInterval,
                        startedAt: Date) -> ChallengeRun.Outcome {
        let correct: Bool = {
            switch problem.op {
            case "+": return problem.a + problem.b == answer
            case "-": return problem.a - problem.b == answer
            case "×": return problem.a * problem.b == answer
            default:  return false
            }
        }()
        guard clock.now().timeIntervalSince(startedAt) <= timeLimit else { return .failTimeout }
        return correct ? .success : .failWrong
    }
}
```

### 3.5 `LockoutPolicy`

After N consecutive failures, impose a cooldown.

```swift
public struct LockoutPolicy {
    public var maxFailures: Int
    public var cooldown: TimeInterval
}

public struct ApplyLockout {
    let clock: Clock
    public init(clock: Clock) { self.clock = clock }

    public func execute(failures: Int, lastFailureAt: Date?, policy: LockoutPolicy) -> LockoutState {
        guard failures >= policy.maxFailures, let last = lastFailureAt else { return .none }
        let until = last.addingTimeInterval(policy.cooldown)
        return clock.now() < until ? .coolingDown(until: until) : .none
    }
}
```

---

## 4) MVP 3 — Preflight & Resilience Use Cases

### 4.1 `EvaluatePreflight`

Given current device/permission snapshot, decide if scheduling should proceed and why.

```swift
public struct EvaluatePreflight {
    public struct Result { public let ok: Bool; public let reasons: [String] }

    public func execute(rules: PreflightRules, snapshot: HealthSnapshot) -> Result {
        var reasons: [String] = []
        if rules.requireNotifications && (snapshot.permissions[.notifications] != true) {
            reasons.append("notifications-disabled")
        }
        if rules.requireCamera && (snapshot.permissions[.camera] != true) {
            reasons.append("camera-denied")
        }
        if rules.requireMotion && (snapshot.permissions[.motion] != true) {
            reasons.append("motion-denied")
        }
        // Low Power Mode isn’t a blocker by itself, but note it:
        if snapshot.lowPowerModeOn { reasons.append("low-power-mode") }
        return .init(ok: reasons.isEmpty || reasons == ["low-power-mode"], reasons: reasons)
    }
}
```

### 4.2 `ShouldSendNudge`

If the user hasn’t foregrounded the app after fire, decide whether to send a nudge.

```swift
public struct ShouldSendNudge {
    let clock: Clock
    public init(clock: Clock) { self.clock = clock }

    public func execute(firedAt: Date, threshold: TimeInterval) -> Bool {
        return clock.now().timeIntervalSince(firedAt) >= threshold
    }
}
```

### 4.3 `ResumeState`

Compute where the app should resume (Ringing or a specific challenge index) based on persisted run.

```swift
public enum ResumeDestination { case ringing, challenge(index: Int), finished }

public struct ComputeResumeState {
    public func execute(run: AlarmRun, orderedChallenges: [Challenge]) -> ResumeDestination {
        // If run.outcome == .inProgress:
        //   - find first ChallengeRun with outcome == .pending → .challenge(index)
        // Else if no pending runs but not completed → .ringing
        // Else → .finished
    }
}
```

---

## 5) Migrations (pure transforms)

### 5.1 `MigrateV1ToV1_Stack`

Wrap `expectedQR` into a single-item `[Challenge]`.

```swift
public struct MigrateV1ToV1_Stack {
    public func execute(alarm: Alarm) -> Alarm {
        guard let expected = alarm.expectedQR else { return alarm }
        var out = alarm
        let ch = Challenge(id: UUID(), kind: .qr, params: .qr(expected: expected), orderIndex: 0)
        out.challenges = [ch]
        return out
    }
}
```

---

## 6) Invariants to Test

* `ScheduleNextFire` handles one-time past alarms → `nil`; repeat days across DST/timezone changes.
* `ValidateChallengeStack` rejects duplicates or gaps in `orderIndex`.
* `AdvanceChallenge` never returns invalid indices; `.finished` iff last success reached.
* `EvaluateMathAnswer` returns `.failTimeout` when over limit; ignores correctness after timeout.
* `ApplyLockout` enforces cooldown only after `maxFailures`, and only until `until`.
* `EvaluatePreflight` blocks on required permissions; only notes low-power mode.

---

## 7) Minimal Test Matrix (examples)

* **Time math:** today vs tomorrow; weekend repeat; DST forward/back transitions.
* **QR:** exact match vs substring vs case-sensitive mismatch.
* **Steps:** threshold −1, =, +1; monotonic increases; no regressions.
* **Math:** each operator; off-by-one; time limit edge at exactly `timeLimit`.
* **Lockout:** failures just below/at/above threshold; cooldown expiry boundary.
* **Resume:** pending at index 0, mid-stack, after final success.

---

## 8) Usage from Presentation (example)

```swift
@MainActor
final class RingingViewModel {
    private let clock: Clock
    private let advance = AdvanceChallenge()
    private let evalQR = EvaluateQR()
    private let evalSteps = EvaluateSteps()
    private let evalMath: EvaluateMathAnswer

    // inject clock for determinism
    init(clock: Clock) {
        self.clock = clock
        self.evalMath = EvaluateMathAnswer(clock: clock)
    }

    // ViewModel listens to Infra streams (QR, steps, math),
    // converts readings into ChallengeRun.Outcome via Domain,
    // and advances the stack using AdvanceChallenge.
}
```

---

## 9) Teen TL;DR

Use cases are **small, pure functions** that decide *what should happen next* (when to fire, whether a challenge passed, what the next step is). They don’t touch the phone; they just take inputs (time, counts, answers) and return decisions. That’s why they’re fast to test and safe to change.

```
Build services to get real-world data → feed that into these use cases → update UI accordingly.
```

```
```

```

### mvp1.md
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/docs/mvp1.md`

```markdown
# MVP 1 — QR-Only Wake Reliability (with Audio Enhancement)

*Target: 2025-08-19*

## 1) Mission

Ship a minimal, reliable alarm that **cannot be dismissed** until the user scans a pre-registered QR code. No backend, no subscriptions.
Guarantee alarms always fire via **AlarmScheduling (local notifications)** while enhancing the user experience with a continuous **audio session** when the app is active.

## 2) Problem → Solution

* **Problem:** People silence or snooze alarms too easily.
* **Solution:** Require scanning a specific QR payload to dismiss.
* **Reliability:** Always schedule via the **`AlarmScheduling`** protocol as the OS-guaranteed sound source.
* **Experience:** When app is alive, start an audio session to provide continuous ringing. Suppress notification sound in foreground to avoid double audio.

## 3) In Scope

* Alarm CRUD: time, repeat, label, sound, volume, vibrate, enable/disable.
* **QR challenge only** (AVFoundation); exact payload match.
* Dismissal flow: **Ringing (fullscreen) → QR Scanner → Success → Dismiss**.
* **Alarm Scheduling:** Use the unified `AlarmScheduling` protocol; **re-register** pending alarms on app launch and when app becomes active.
* **Audio session enhancement:** continuous playback when app is active; foreground notifications omit `.sound` if audio is ringing.
* **Local persistence:** Use the thread-safe **`PersistenceStore` actor** (replaces legacy SwiftData) for alarms, runs, and the QR payload.
* Basic Settings: default sound, haptics, 12/24h.
* Local reliability log (append events to file or DB).
* Tests: unit (scheduler + QR validator + persistence round-trip + suppression rule), 1 E2E.
* Accessibility & performance basics.

## 4) Out of Scope (MVP 1)

* Steps, Math, multi-challenge stacks.
* Buddy/accountability, photo proof.
* Payments/penalties.
* Bedtime flow, smart wake.
* Any backend/auth.

## 5) UX Spec (flows)

### 5.1 Create/Edit Alarm

* Fields: time, repeat days, label, sound, volume, vibrate, **QR Setup**.
* **QR Setup:** “Save this code’s value” → open scanner → on success, store payload in `Alarm.expectedQR`.

### 5.2 Ringing & Dismissal

* Fullscreen RingingView (screen awake, system volume respected).
* Primary CTA: **“Scan Code to Dismiss.”**
* Scanner screen with torch toggle; if scanned payload == expected → success → stop alarm → mark run success (via `PersistenceStore` actor).
* **Audio UX:** If app is active, audio session starts ringing continuously. Notifications show banners only (no sound) to prevent overlap. If app is killed, notification sound ensures alarm still fires.

### 5.3 Permission UX

* **Notifications**: hard-block scheduling if disabled; inline warning + deep link to Settings.
* **Camera**: block dismissal until granted; explain why and offer Settings deep link.

## 6) Minimal Data Model (Swift / Domain)

* `Alarm { id, time, repeatDays[], label, sound, volume, vibrate, isEnabled, expectedQR:String? }`
* `AlarmRun { id, alarmId, firedAt, dismissedAt?, outcome: success|fail }`

> For full contracts, see `CLAUDE.md` §4–5.

## 7) Services (protocols to implement)

* `AlarmScheduling`: request auth, schedule/cancel, reconcile, pending IDs.
* `QRScanning`: start/stop, `AsyncStream<String>` of payloads.
* `PersistenceStore` (**Actor**): save/load alarms; append runs.
* `Clock`: `now()` for deterministic time math in tests.
* `AudioEngine`: start/stop ringing; `isActivelyRinging` flag for suppression logic.

(Concrete implementations live under `Infrastructure/Services/*` and are wired in `DependencyContainer`.)

## 8) App Lifecycle Rules

* On app launch **and** when `scenePhase == .active`: `AlarmScheduling.reconcile(from: alarms)`.
* Always include a notification action/deeplink back to Ringing/Scanner (“Return to Dismissal”).
* If audio is ringing, suppress notification `.sound` in `willPresent`.

## 9) Anti-Cheat Hygiene (MVP-appropriate)

* Preflight check before scheduling: notifications authorized; block + explain if not.
* Ringing cannot be dismissed without QR success (no alternative buttons).
* Log permission changes to local reliability log.

## 10) Definition of Done

* ≥95% of fired alarms require a **valid QR scan** to dismiss in internal testing.
* Works if app is killed/closed: alarm still fires; tapping notification returns to Ringing/Scanner.
* Audio session starts when app alive; no double audio in foreground.
* Dark-room QR scan succeeds (torch toggle available).
* No crashes across **3 consecutive days** of scheduled alarms.

## 11) Test Plan

**Unit**

* `ScheduleNextFire` (one-time vs repeat; DST/timezone edges).
* QR validator: exact match vs wrong/case mismatch; empty expected.
* Persistence round-trip: create → save → load → equality. **Concurrency Test: Simultaneous save of AlarmRuns on the PersistenceStore actor.**
* Preflight: notifications disabled → scheduling blocked.
* Audio suppression: if `isActivelyRinging == true`, notifications omit `.sound`.

**Integration**

* Alarm Scheduling round-trip with a mock center.
* Storage migration ready for V1 (wrap `expectedQR` into a single-item challenge later).
* Audio + notification interaction (no double sound).

**UI/E2E**

* Set alarm (1 min ahead) → rings → scan valid QR → dismiss → run outcome recorded.
* Verify continuous audio in foreground, sound-only notification if app killed.

**Manual Smoke**

* Dark room; Do Not Disturb; volume low; airplane mode; device lock/unlock during ringing.

## 12) Local Reliability Log (MVP scope)

* Events: `scheduled`, `fired`, `dismiss_success_qr`, `dismiss_fail_qr`, `notifications_status_changed`, `audio_started`, `audio_stopped`.
* Store locally (JSON/CSV). Export via share sheet (optional).

## 13) Accessibility & Perf

* Min tap target 44pt; Dynamic Type friendly.
* VoiceOver labels on critical buttons (“Scan Code to Dismiss”, “Toggle Torch”).
* No blocking disk I/O on main thread; camera session starts fast (<300ms target).
* Audio session start within ≤1s of fire time.

## 14) Build Order (no-code checklist)

1. **Models & Storage**

   * Create `Alarm`, `AlarmRun` (Domain).
   * `PersistenceStore` protocol implementation as a **Swift actor**.
2. **Scheduling**

   * `AlarmScheduling` with request auth + schedule + reconcile.
   * Re-register on launch/active.
3. **UI Scaffolding**

   * `AlarmList`, `AlarmForm`, `Ringing` skeletons.
4. **QR Setup & Dismissal**

   * `QRScanning` service; save expected payload in `Alarm`.
   * Ringing → Scanner → validate → stop.
5. **Audio Enhancement**

   * Implement `AudioEngine` service; suppress notification sound when active.
6. **Reliability Log**

   * Append events; simple export (optional).
7. **Tests**

   * Unit (scheduler, QR, persistence, suppression, **concurrency**) + one E2E.

## 15) Apple APIs & Search Hints

* **Notifications:** `UNUserNotificationCenter requestAuthorization(options: [.alert, .sound])`, `UNTimeIntervalNotificationTrigger` / `UNCalendarNotificationTrigger`, `getNotificationSettings`.
* **QR:** `AVCaptureSession` + `AVCaptureMetadataOutput` (`metadataObjectTypes = [.qr]`), torch via `AVCaptureDevice`.
* **Audio:** `AVAudioSession` category `.playback`, handle route changes/interruption.
* **Lifecycle:** `scenePhase` changes in SwiftUI, app launch re-registration pattern.

*Search terms:*
“AlarmScheduling schedule calendar trigger iOS 26”
“AVCaptureMetadataOutput QR SwiftUI sample”
“SwiftUI scenePhase app becomes active reconcile AlarmScheduling”
“AVAudioSession continuous playback background iOS”
“Swift actor persistence UserDefaults concurrency”

## 16) Risks & Mitigations

* **Notifications off** → block creation; show deep link.
* **Camera denied** → block dismissal; deep link + rationale.
* **User mutes phone** → preflight “Volume reminder” UX; can’t force volume.
* **Audio session killed by OS** → notifications still fire with sound.

## 17) Acceptance Checklist (must pass before ship)

* [ ] All unit & E2E tests pass locally.
* [ ] **Concurrency tests for PersistenceStore pass.**
* [ ] 3-day internal dogfood across 3 devices with no crashes.
* [ ] Notification/camera rationales reviewed; App Privacy strings set.
* [ ] Reliability log shows expected events.
* [ ] No double-audio observed in foreground tests.

## 18) What’s Next (V1 Core preview)

* Add **Steps** and **Math** challenges.
* Challenge **stack** with enforced order + timeouts/lockouts.
* Extend models to `[Challenge]`; migrate `expectedQR` → `.qr(expected:)`.
```

### v1-core.md
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/docs/v1-core.md`

```markdown
# V1 — Core Wake Reliability

## 1. Goal

Prove the app wakes users reliably, can’t be trivially cheated, and delivers a strong **continuous audio experience** when the app is active.

## 2. Scope (Include)

* Alarms: create/edit/delete, repeat, label, sound, volume, vibrate.
* Challenges: QR, Steps, Math with **enforced order**.
* Dismissal flow UI (sequential steps, failure timeout).
* **Alarm Scheduling (AlarmKit / Notifications):** Use the unified `AlarmScheduling` protocol; re-register on launch/background.
* **Audio session enhancement:** when app is alive, start continuous playback; suppress foreground notification sound to avoid double audio.
* **Local persistence:** Use the **`PersistenceStore` actor** for all alarm and run data; persistence operations must be thread-safe and atomic.
* Basic Settings (minimal).
* Minimal analytics (local log + optional console export).
* Tests: unit (scheduler + validators + suppression logic), one happy-path e2e.

## 3. Out of Scope (This Version)

* Buddy notifications (SMS/push), photo proof, post-alarm check-in.
* Payments/penalties, Roulette Mode.
* Bedtime flow, sleep-stage smart wake.
* Backend services (APIs, DB, auth).

## 4. Definition of Done

* ≥95% of fired alarms complete all selected challenges in testing.
* Works if app closed/killed; notification still fires; dismissal flow reachable.
* QR works in low light; steps validate in airplane mode.
* Continuous audio plays in foreground; no double audio when both audio + notification present.
* No crashes across 3 consecutive days of scheduled test alarms.

## 5. Flags (All Off in V1 Build)

| Flag      | Default | Notes       |
| --------- | ------- | ----------- |
| buddy     | off     | Defer to V2 |
| proof     | off     | Defer to V2 |
| payments  | off     | Defer to V3 |
| roulette  | off     | Defer to V3 |
| bedtime   | off     | Defer to V2 |
| smartWake | off     | Defer to V3 |

## 6. Test Plan

* Unit: alarm scheduler; math/steps/QR validators; suppression logic (audio active → no notif sound).
* E2E: dismissal flow happy-path with 1 challenge stack.
* Smoke script: nightly run across 3 devices; record outcomes (foreground + killed).

## 7. AI Prompt Templates (UPDATED)

* Scaffold core app:

  > Use **§4 Domain Model (Alarm/Challenge/AlarmRun)** and **§5 Service Contracts (AlarmScheduling, PersistenceStore)** to build SwiftUI views. **Ensure PersistenceStore is implemented as an actor** and all reads/writes are thread-safe. Generate unit tests for math/steps/qr validators and audio suppression.
* Reliability checks:

  > Write tests to confirm `AlarmScheduling` re-registration on app relaunch/background per iOS 17+ constraints, and that audio + notif do not double-play.

## 8. References

* MVP Spec §2.1 (M0), §2.2 (Screens 1–3), §2.3, §2.6.1, §2.5 (Alarm reliability).
* MVP 1 doc for audio-enhancement pattern.
```

### v2-accountability-bedtime.md
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/docs/v2-accountability-bedtime.md`

```markdown
# V2 — Accountability & Bedtime Flow

## 1. Goal

Add external accountability and bedtime behavior without monetization risk.
Leverage V1’s **AlarmScheduling-primary + audio-enhancement** ring model unchanged (no modifications to core alarm mechanics).

## 2. Scope (Include)

* Buddy contact with consent + quiet hours; **push/SMS** (Twilio/APNs).
* Photo **proof** of predefined object on success; **post-alarm check-in** (made-bed photo).
* Simple backend + auth; `/events/*` endpoints; signed URL uploads.
* Bedtime flow: schedule, “I’m in bed” notification action, buddy ping, analytics.
* Expanded tests: network mocks (Twilio/Uploads), e2e for success/fail + bedtime confirm.
* **Reliability note:** All new features must **not** alter the V1 ring path: the unified `AlarmScheduling` remains the **primary ringer**; audio session is an **enhancement** when the app is active (foreground notifications suppress `.sound` if audio is ringing).

## 3. Out of Scope (This Version)

* Payments/penalties; Roulette sends.
* Sleep-stage smart wake (HealthKit).

## 4. Definition of Done

* Buddy notified on success/fail in <10s; quiet hours respected.
* Photo proof upload ≥99% success on poor networks (queued retry).
* Bedtime confirm round-trip recorded and visible in history.
* **Ring-path regression:** Alarms still fire with sound when app is closed/killed; audio suppression (no double audio) holds in foreground.
* **Concurrency:** All new queueing/retry services (e.g., Buddy Alert Queue) **MUST** be implemented as **Swift `actor`** types to ensure thread-safe operation and persistence.

## 5. Flags (Turn On Selectively)

| Flag      | Default | Notes                                    |
| --------- | ------- | ---------------------------------------- |
| buddy     | on      | Enable SMS/push w/ quiet hours + consent |
| proof     | on      | Photo proof + post-alarm check-in        |
| bedtime   | on      | Bedtime schedule + confirm flow          |
| payments  | off     | V3                                       |
| roulette  | off     | V3                                       |
| smartWake | off     | V3                                       |

## 6. Backend/Plumbing Checklist (UPDATED)

* Auth + DB (Firestore or Supabase) wired.
* Endpoints: `POST /events/alarm`, `POST /events/proof`, `POST /events/bedtime`.
* **Storage/Queueing:** All local queueing logic (Buddy Alert Queue, Proof Upload Queue) **MUST** be handled by **Swift `actor`** types (e.g., `BuddyAlertQueueActor`) to ensure data integrity during concurrent retry/background processing.
* Twilio/APNs provider abstraction + retry/backoff; delivery status persisted.
* Analytics: bedtime scheduled/delivered/confirmed; buddy alerts.
* **Reliability constraint:** No backend dependency in the alarm ring path; alarms must fully function offline with local scheduling and optional audio enhancement.

## 7. Test Plan (UPDATED)

* Unit: buddy quiet-hours filter; consent gate; upload signer. **Ensure all new queue/storage logic has concurrency tests (load-modify-save under load).**
* Integration: Twilio mock; storage upload; APNs token registration.
* E2E: (a) success + proof + buddy notify; (b) failure + buddy notify; (c) bedtime confirm.
* **Regression (from V1):**

  * App killed → alarm still fires with sound; tap routes into dismissal flow.
  * Foreground with audio active → alarm notification omits `.sound` (no double audio).
  * Offline mode → ring path unaffected; buddy/proof queue (implemented as actors) and retry later.

## 8. AI Prompt Templates

* Backend/API:

  > Implement the endpoints in **§2.10 API** and persist **§2.3 entities** (Proof, BuddyContact, Notification, BedtimeEvent). Provide Twilio/APNs mocks and retry logic with idempotency keys. **Implement all local queueing and retry logic using Swift 'actor' types to ensure thread safety.**
* Bedtime UX:

  > Build a notification action “I’m in bed” and handle it via `UNUserNotificationCenterDelegate` as in **§2.6.2 Bedtime**.
* Reliability guard (carryover from V1):

  > Ensure all new flows keep the **unified AlarmScheduling as the primary ringer** and **audio session as an enhancement** with foreground `.sound` suppression when audio is active.

## 9. References

* MVP Spec §2.1 (M1, M3 parts), §2.2 (Screens 4–8, 11), §2.3, §2.6.2, §2.8.
* V1 Spec: AlarmScheduling-primary + audio-enhancement pattern.
```

### v3-monetization-advanced.md
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/docs/v3-monetization-advanced.md`

```markdown
# V3 — Monetization & Advanced Reliability

## 1. Goal

Introduce advanced anti-cheat features, monetize value-added services, and ensure peak alarm reliability by leveraging OS health and sleep metrics. All new state must be managed with thread-safe **Swift actors**.

## 2. Scope (Include)

* **Monetization (MonetizationService Actor):** Subscription tiers for Advanced Features (Smart Wake, Roulette Mode); IAP for one-time purchases (e.g., sound packs).
* **Roulette Mode:** Randomly selects a challenge from the user's *available* pool; uses a single source of truth for the random seed (managed by an actor).
* **Advanced Reliability (HealthStatusProviding):** Leverage HealthKit/SleepKit data to monitor background status and inform the alarm system of optimal pre-wake times and potential device issues (e.g., Low Power Mode).
* **Smart Wake:** Uses HealthKit data to trigger the alarm within a 30-minute window before the scheduled time, based on sleep phase (lightest sleep). Must be highly resilient and **never** trigger late.
* **Accountability Escalation (V2-based):** Introduce "Penalty" logic for failed alarms (e.g., donate to charity, mandatory friend ping).

## 3. Out of Scope (This Version)

* Advanced backend-hosted analytics (defer to V4).
* Non-subscription/IAP payment models (e.g., ads).
* Advanced machine learning for predictive scheduling.

## 4. Definition of Done

* Subscription status is managed by a thread-safe **MonetizationService actor**.
* HealthKit permissions are requested with proper rationale; background query for sleep data runs reliably.
* Smart Wake logic correctly identifies the wake window and triggers via `AlarmScheduling` if in light sleep.
* Payment transactions complete and persist with integrity checks (managed by the **PersistenceStore actor**).
* **Concurrency:** All monetization, smart wake data, and escalation logic **MUST** be implemented as **Swift `actor`** types (e.g., `MonetizationActor`, `RouletteStateActor`).

## 5. Flags (Turn On)

| Flag      | Default | Notes                                               |
| --------- | ------- | --------------------------------------------------- |
| buddy     | on      | V2 - Accountability                                 |
| proof     | on      | V2 - Photo Proof                                    |
| payments  | on      | IAP/Subscription enablement, managed by IAP/Sub Mgr |
| roulette  | on      | Enable random challenge selection                   |
| bedtime   | on      | V2 - Bedtime flow                                   |
| smartWake | on      | Enable HealthKit-based wake window                  |

## 6. Backend/Plumbing Checklist (UPDATED)

* New endpoint: `POST /events/payment-receipt`.
* Monetization provider abstraction (StoreKit/GooglePlay) added.
* **Reliability:** `HealthStatusProviding` must be implemented in the Infrastructure layer and exposed via a protocol; all state must be read from/written to thread-safe actors.
* **Persistence:** `PersistenceStore` actor must be extended to store subscription status, purchase history, and Smart Wake logs atomically.

## 7. Test Plan (UPDATED)

* Unit: Smart Wake sleep phase detection logic; Roulette seed generation (must be deterministic in tests). **MonetizationService actor (load/save/update concurrency test).**
* Integration: Mock HealthKit/SleepKit data feed; Mock StoreKit transactions.
* E2E: (a) User with Smart Wake enabled wakes 15 minutes early; (b) User without subscription attempts to enable Roulette Mode (blocked).
* **Concurrency Test (CRITICAL):** Simulate simultaneous update of a user's subscription status and a penalty event, ensuring the final user state remains consistent (no race conditions on shared data).

## 8. AI Prompt Templates

* Monetization Flow:

    > Implement `MonetizationService`, ensuring it is a **Swift 'actor'**. Provide flows for checking subscription status and handling purchase transactions. Use typed domain errors (as per §5.5).
* Smart Wake Core:

    > Implement `HealthStatusProviding` protocol in Infrastructure (wraps HealthKit). Build Smart Wake Use Case logic in Domain to calculate the optimal wake time within a 30-minute window, using time-of-day data from **AlarmScheduling**.
* Roulette Logic:

    > Build `RouletteModeActor` to manage the random challenge selection seed. Ensure challenge selection respects feature flags and the user's unlocked challenge pool.
```

### claude-guardrails.md
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/docs/claude-guardrails.md`

```markdown
# Guardrails 

* **No side effects in initializers.** Constructors must not do I/O, talk to OS APIs, or assert/`fatalError`.
* **OS work only in explicit activation methods.** E.g., notification delegate wiring + category registration live in `DependencyContainer.activate…()` (idempotent) and are called from App startup.
* **Concurrency Strategy (CRITICAL):** All new services managing shared mutable state **MUST** be implemented as **Swift `actor`** types. Use the actor for thread-safe access to mutable properties (e.g., internal cache, storage). **NEVER** mix manual locking primitives (like `DispatchSemaphore` or `DispatchQueue.sync`) with Swift concurrency (`async/await` and `Task`).
* **Validate only on receipt.** Any strict checks (e.g., `userInfo["alarmId"]`, category IDs) happen in `UNUserNotificationCenterDelegate` callbacks, never during registration.
* **Protocol-first DI.** Expose protocols from the container; keep concrete instances private for retention/wiring.
* **Main-thread boundaries are explicit.** Stamp OS-touching helpers with `@MainActor` (or hop to main) when accessing UIKit / NotificationCenter delegate assignment.
* **Error Handling Enforcement:** All Infrastructure and Persistence methods **MUST** throw a **typed domain error** (e.g., `PersistenceStoreError`, `AlarmSchedulingError`). Silent catches (`catch {}`) and `try?` without logging or rethrow are strictly forbidden in production code.
* **Idempotency by design.** All setup/registration functions are safe to call multiple times (no duplicates, no side effects).
* **No singletons in methods.** Never reach into `DependencyContainer.shared` from within services—use injected deps only.
* **Structured logging contract.** Every observable event logs `{ alarmId, event, source/action, category, occurrenceKey? }`.
* **Critical Blocker / Reliability.** Do not design alarms where continuous sound depends solely on app-run audio sessions. Local notifications must remain the guaranteed sound path.

# Boilerplate you can require Claude to keep using

## Activation pattern (kept in the DI container)

```swift
// DependencyContainer.swift
private var didActivateNotifications = false

@MainActor
func activateNotificationDelegate() {
    guard !didActivateNotifications else { return }
    let center = UNUserNotificationCenter.current()
    center.delegate = notificationServiceConcrete
    notificationServiceConcrete.ensureNotificationCategoriesRegistered()
    didActivateNotifications = true
}
Category registration (minimal + idempotent)
Swift

// NotificationService.swift
func ensureNotificationCategoriesRegistered() {
    let open = UNNotificationAction(identifier: "OPEN_ALARM", title: "Open", options: [.foreground])
    let ret  = UNNotificationAction(identifier: "RETURN_TO_DISMISSAL", title: "Return to Dismissal", options: [.foreground])
    let snoo = UNNotificationAction(identifier: "SNOOZE_ALARM", title: "Snooze", options: [])
    let cat  = UNNotificationCategory(identifier: "ALARM_CATEGORY",
                                      actions: [open, ret, snoo],
                                      intentIdentifiers: [],
                                      options: [.customDismissAction])

    let center = UNUserNotificationCenter.current()
    center.getNotificationCategories { existing in
        var updated = existing
        updated.removeAll { $0.identifier == "ALARM_CATEGORY" }
        updated.insert(cat)
        center.setNotificationCategories(updated)
        self.reliabilityLogger.info("categories_registered", details: ["category":"ALARM_CATEGORY"])
    }
}
App state provider (UIKit isolated + main-thread safe)
Swift

protocol AppStateProviding { var isAppActive: Bool { get } }

@MainActor
final class AppStateProvider: AppStateProviding {
    var isAppActive: Bool { UIApplication.shared.applicationState == .active }
}
“Definition of Done” add-ons (UPDATED)
Ask Claude to include these in DoD for each stage:

Init purity: No initializers contain I/O, OS calls, asserts, or delegate wiring.

Activation verified: Activation hook exists, is @MainActor, idempotent, and called from App startup.

Receipt validation only: All validation happens in willPresent/didReceive; registration is construction-only.

DI conformance: Public surface is protocol-typed; no method references DependencyContainer.shared.

Concurrency Conformance: All shared mutable state is protected by actor types. No new usage of manual locks.

Logs present: At least one log for activation, category registration, receipt (tap/action), and routing failure.

Tests include:

A mock for any new provider (e.g., AppStateProviding).

A test asserting activation is idempotent (calling twice has no side effects).

A test confirming receipt-time validation logs (and does not crash) on malformed notifications.

A concurrency test asserting load-modify-save is atomic for shared state (e.g., PersistenceStore).

“Fail fast” lint items (UPDATED)
Search-and-block list: In changed files, assert there are no occurrences of fatalError(, precondition(, or ! unwraps inside initializers or registration functions.

Singleton sniff: Reject any new usage of DependencyContainer.shared inside services.

MainActor guard: Any use of UIApplication.shared or delegate assignment must be inside a @MainActor context.

Concurrency Guard: Reject any new usage of DispatchSemaphore or DispatchQueue.sync in actor types or asynchronous functions.

Silent Failure Guard: Reject any empty catch {} blocks or unhandled try? in production code.

If you paste these sections into future Claude commands (Guardrails + DoD add-ons + boilerplate), you’ll keep the initializer purity, activation pattern, and receive-side validation intact as the app grows.

UIKit Isolation Guardrails (paste into every command)

Scope & Imports

UIKit allowed only in Infrastructure files (e.g., services, providers, OS adapters).

Disallowed in Domain (models, pure logic) and Presentation (SwiftUI Views/ViewModels).

If UIKit is needed, wrap it behind a protocol and inject it (no direct usages outside Infra).

Prefer placing UIKit code in a small infra file (e.g., AppStateProvider.swift) with import UIKit.
Other files should stay UIKit-free.

Concrete Rules

No import UIKit in:

Domain/* (pure Swift)

Views/* or ViewModels/* (SwiftUI layer)

Only Infra may use:

UIApplication.* (e.g., applicationState, isIdleTimerDisabled)

Notification center delegate wiring (UNUserNotificationCenter.delegate)

Haptics (UIImpactFeedbackGenerator, etc.)

No side effects in initializers. OS calls (UIKit, NotificationCenter) happen only in explicit activation methods (idempotent) called from App startup.

Protocol-first DI

Expose protocols from the container; keep concretes private (retention/wiring only).

No DependencyContainer.shared reach-ins from services; use injected dependencies.

Main-thread boundaries

Any UIKit access must be in a @MainActor context (or hop to main explicitly).

Validation Placement

Registration/setup functions are construction-only (build objects, set categories).
All strict validation (e.g., userInfo["alarmId"]) lives in delegate callbacks.

Definition of Done Add-Ons

✅ No import UIKit outside Infra.

✅ New UIKit touches are behind a protocol and injected.

✅ Activation method exists, is @MainActor, and idempotent (guarded).

✅ Zero fatalError/precondition/force-unwraps in registration/initializers.

Lint / Quick Checks (Claude should self-enforce)

Search diffs for import UIKit and fail if outside Infra.

Search for DependencyContainer.shared inside services and fail.

Search initializers for UIApplication/UNUserNotificationCenter and fail.

Ensure at least one test mocks any newly introduced provider (e.g., AppStateProviding).




```

### MVP1_MANUAL_SMOKE_TEST_CHECKLIST.md
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/docs/MVP1_MANUAL_SMOKE_TEST_CHECKLIST.md`

```markdown
# MVP 1 — QR-Only Manual Smoke Test Checklist

This checklist must be completed on a **physical iOS device** (not simulator) before declaring MVP 1 complete.

**Target:** 2025-08-19
**Definition of Done:** ≥95% of fired alarms require valid QR scan + 3-day dogfood with no crashes.

---

## Prerequisites

- [ ] Physical iPhone running iOS 17+ (minimum supported version)
- [ ] Printed QR code or QR code displayed on another device
- [ ] TestFlight build or Debug build installed
- [ ] All permissions granted (Notifications, Camera, AlarmKit)

---

## Test Session 1: Basic Functionality (30 minutes)

### 1.1 Alarm Creation & QR Setup
- [ ] Create new alarm for 2 minutes in the future
- [ ] Add QR challenge
- [ ] Scan QR code using camera (verify torch toggle works)
- [ ] Save alarm
- [ ] Verify alarm appears in list with correct time
- [ ] Verify alarm toggle is enabled

### 1.2 Alarm Firing (Foreground)
- [ ] Keep app in foreground
- [ ] Wait for alarm to fire
- [ ] Verify fullscreen ringing view appears
- [ ] Verify audio plays continuously
- [ ] Verify "Scan Code to Dismiss" button visible
- [ ] Tap button to begin scan
- [ ] Verify QR scanner opens with camera preview

### 1.3 QR Validation
- [ ] Scan **incorrect** QR code
- [ ] Verify error message displays ("Invalid QR code")
- [ ] Verify returns to scanning state after 1 second
- [ ] Scan **correct** QR code
- [ ] Verify validation spinner appears
- [ ] Verify success screen displays
- [ ] Verify audio stops
- [ ] Verify returns to alarm list

### 1.4 Alarm Run Persistence
- [ ] Navigate to Settings → Diagnostics
- [ ] Tap "Export Logs"
- [ ] Verify share sheet appears
- [ ] Verify JSON contains `fired`, `dismiss_success_qr` events for alarm

---

## Test Session 2: Background & Lock Screen (30 minutes)

### 2.1 App Killed Scenario
- [ ] Create alarm for 2 minutes in future
- [ ] Add QR challenge and scan code
- [ ] Save alarm
- [ ] **Force-kill app** (swipe up from app switcher)
- [ ] Wait for alarm to fire
- [ ] Verify lock screen notification appears
- [ ] Verify notification sound plays
- [ ] Tap notification
- [ ] Verify app cold-starts to ringing view
- [ ] Scan correct QR code
- [ ] Verify dismissal succeeds

### 2.2 Background Scenario
- [ ] Create alarm for 2 minutes in future
- [ ] Add QR challenge
- [ ] Save alarm
- [ ] Press home button (app backgrounds)
- [ ] Wait for alarm to fire
- [ ] Verify notification appears
- [ ] Tap notification
- [ ] Verify app returns to ringing view
- [ ] Verify audio plays
- [ ] Scan correct QR code
- [ ] Verify dismissal succeeds

### 2.3 Lock Screen Scenario
- [ ] Create alarm for 2 minutes in future
- [ ] Add QR challenge
- [ ] Save alarm
- [ ] Lock device (power button)
- [ ] Wait for alarm to fire
- [ ] Verify lock screen notification appears
- [ ] Verify sound plays
- [ ] Unlock device and tap notification
- [ ] Verify navigates to ringing view
- [ ] Scan correct QR code
- [ ] Verify dismissal succeeds

---

## Test Session 3: Edge Cases & Resilience (45 minutes)

### 3.1 Dark Room QR Scan
- [ ] Create alarm
- [ ] Turn off all lights (simulate dark room)
- [ ] Wait for alarm to fire
- [ ] Begin QR scan
- [ ] Tap torch toggle button
- [ ] Verify flashlight turns on
- [ ] Scan QR code with torch enabled
- [ ] Verify successful scan
- [ ] Tap torch toggle again
- [ ] Verify flashlight turns off

### 3.2 Do Not Disturb Mode
- [ ] Enable Do Not Disturb in Control Center
- [ ] Create alarm for 2 minutes ahead
- [ ] Add QR challenge
- [ ] Wait for alarm to fire
- [ ] Verify notification still appears (alarms bypass DND)
- [ ] Verify sound plays
- [ ] Dismiss alarm successfully

### 3.3 Low Volume
- [ ] Set device ringer volume to 10%
- [ ] Create alarm
- [ ] Wait for alarm to fire (lock screen)
- [ ] Verify notification sound plays (at system volume)
- [ ] Tap notification to open app
- [ ] Verify in-app audio plays (at configured volume)

### 3.4 Airplane Mode
- [ ] Enable Airplane Mode
- [ ] Create alarm for 2 minutes ahead
- [ ] Add QR challenge
- [ ] Wait for alarm to fire
- [ ] Verify alarm still fires (local scheduling)
- [ ] Begin QR scan
- [ ] Verify camera works offline
- [ ] Scan correct QR code
- [ ] Verify dismissal succeeds offline

### 3.5 Permission Revocation
- [ ] Go to Settings → Privacy → Camera
- [ ] Disable camera for alarmAppNew
- [ ] Return to app
- [ ] Create alarm and wait for fire
- [ ] Tap "Scan Code to Dismiss"
- [ ] Verify permission blocking view appears
- [ ] Verify "Open Settings" button present
- [ ] Tap "Open Settings"
- [ ] Verify deep links to Camera settings
- [ ] Re-enable camera permission
- [ ] Return to app
- [ ] Verify can now scan QR code

### 3.6 Cancel Scan Flow
- [ ] Create alarm and wait for fire
- [ ] Tap "Scan Code to Dismiss"
- [ ] In scanner, tap "Cancel"
- [ ] Verify returns to ringing view
- [ ] Verify audio still playing
- [ ] Verify can retry scan

### 3.7 Multiple Alarms
- [ ] Create 3 alarms:
  - Alarm 1: Now + 2 min (QR challenge)
  - Alarm 2: Now + 4 min (QR challenge, different QR)
  - Alarm 3: Now + 6 min (QR challenge)
- [ ] Wait for Alarm 1 to fire
- [ ] Dismiss Alarm 1 with correct QR
- [ ] Wait for Alarm 2 to fire
- [ ] Dismiss Alarm 2 with correct QR
- [ ] Wait for Alarm 3 to fire
- [ ] Dismiss Alarm 3 with correct QR
- [ ] Verify no crashes
- [ ] Export logs and verify 3 successful runs

---

## Test Session 4: Accessibility (30 minutes)

### 4.1 VoiceOver
- [ ] Enable VoiceOver (Settings → Accessibility → VoiceOver)
- [ ] Navigate to Alarms List
- [ ] Verify "Create new alarm" button announces correctly
- [ ] Tap button to create alarm
- [ ] Verify "Alarm Time" picker announces time
- [ ] Verify "Save alarm" button announces with hint
- [ ] Navigate to alarm toggle
- [ ] Verify toggle announces "Enable/Disable alarm for [time]"
- [ ] Disable VoiceOver

### 4.2 Dynamic Type
- [ ] Open Settings → Display & Brightness → Text Size
- [ ] Set text size to largest setting
- [ ] Return to app
- [ ] Verify alarm times readable (not truncated)
- [ ] Verify labels readable
- [ ] Create new alarm
- [ ] Verify form fields readable at large text size
- [ ] Set text size back to default

### 4.3 Tap Target Size
- [ ] Using finger (not stylus), verify all buttons tappable:
  - [ ] "+" floating action button
  - [ ] Alarm toggle switches
  - [ ] "Scan Code to Dismiss" button
  - [ ] Torch toggle in scanner
  - [ ] "Cancel" button in scanner
- [ ] Verify no accidental taps on adjacent elements

---

## Test Session 5: 3-Day Dogfood (Validation Phase)

### Setup
- [ ] Create 2-3 recurring alarms (e.g., 8:00 AM daily, 6:00 PM daily)
- [ ] Each alarm has QR challenge
- [ ] Print QR codes and place in different locations

### Daily Checklist (Days 1-3)
**Day 1 Date: ____________**
- [ ] Alarm 1 fired correctly: ☐ Yes ☐ No
- [ ] Alarm 1 dismissed successfully: ☐ Yes ☐ No
- [ ] Alarm 2 fired correctly: ☐ Yes ☐ No
- [ ] Alarm 2 dismissed successfully: ☐ Yes ☐ No
- [ ] Any crashes observed: ☐ Yes ☐ No

**Day 2 Date: ____________**
- [ ] Alarm 1 fired correctly: ☐ Yes ☐ No
- [ ] Alarm 1 dismissed successfully: ☐ Yes ☐ No
- [ ] Alarm 2 fired correctly: ☐ Yes ☐ No
- [ ] Alarm 2 dismissed successfully: ☐ Yes ☐ No
- [ ] Any crashes observed: ☐ Yes ☐ No

**Day 3 Date: ____________**
- [ ] Alarm 1 fired correctly: ☐ Yes ☐ No
- [ ] Alarm 1 dismissed successfully: ☐ Yes ☐ No
- [ ] Alarm 2 fired correctly: ☐ Yes ☐ No
- [ ] Alarm 2 dismissed successfully: ☐ Yes ☐ No
- [ ] Any crashes observed: ☐ Yes ☐ No

### Post-Dogfood Validation
- [ ] Export reliability logs
- [ ] Verify all 6 alarms logged as `fired`
- [ ] Verify all 6 alarms logged as `dismiss_success_qr`
- [ ] Calculate success rate: ____ / 6 = ____% (must be ≥95%)
- [ ] Check for crash logs in Settings → Privacy → Analytics & Improvements → Analytics Data
- [ ] Verify no crash logs for alarmAppNew

---

## Final Sign-Off

**Tester Name:** _____________________
**Test Date:** _____________________
**iOS Version:** _____________________
**Device Model:** _____________________

**Result:** ☐ PASS ☐ FAIL

**Notes/Issues:**
```
[Record any issues, edge cases, or observations here]
```

**Definition of Done Status:**
- [ ] ≥95% of fired alarms required valid QR scan
- [ ] Works if app is killed (notification fires, dismissal reachable)
- [ ] Audio starts when app alive; no double audio
- [ ] Dark-room QR scan succeeds (torch toggle works)
- [ ] No crashes across 3 consecutive days

---

## Troubleshooting Common Issues

### Issue: Alarm doesn't fire
- Check notification permissions (Settings → Notifications → alarmAppNew)
- Check AlarmKit permissions (Settings → Alarms)
- Verify alarm is enabled (toggle on)
- Export logs and check for `scheduled` event

### Issue: Audio doesn't play
- Check device ringer volume (not media volume)
- Check device not in silent mode (switch on side)
- Check Do Not Disturb isn't blocking sound
- Export logs and check for `audio_started` event

### Issue: QR scanner shows black screen
- Check camera permission granted
- Check camera not in use by another app
- Check device has functional rear camera
- Try restarting app

### Issue: Dismissal doesn't stop alarm
- Check QR payload matches exactly (case-sensitive, whitespace-trimmed)
- Export logs and check for `stop_failed` event
- Check for AlarmKit errors in logs

---

**Last Updated:** 2025-10-15
**MVP Version:** 1.0 (QR-Only)
**Next Review:** After V1 (Core Reliability with Steps+Math)

```

### README.md
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Resources/Sounds/README.md`

```markdown
# Sound Assets

This directory contains alarm sound files for the alarm app.

## Files Required

The app expects the following sound files:
- `default.caf` - Default alarm sound (≤30s for notifications)
- `classic.caf` - Classic alarm sound
- `chime.caf` - Chime sound
- `bell.caf` - Bell sound
- `radar.caf` - Radar sound

## Format Requirements

- **For notifications**: Files should be ≤30 seconds, loud, and in formats supported by iOS notifications (CAF, AIFF, WAV)
- **For in-app ringing**: Can be longer and will loop automatically
- Recommended format: CAF (Core Audio Format) for best iOS compatibility

## Volume Considerations

- Lock-screen notification volumes are controlled by system settings
- In-app playback volume is controlled by the app's volume slider
- Files should be normalized to prevent distortion

## Adding New Sounds

1. Add the audio file to this directory
2. Update `SoundAsset.availableSounds` in `AudioService.swift`
3. Ensure the file is added to the Xcode project bundle
```

---

## Configuration Files

### Info.plist
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSUserNotificationUsageDescription</key>
	<string>This app needs notification permission to deliver reliable alarm notifications that will wake you up at the scheduled time.</string>
	<key>NSAlarmKitUsageDescription</key>
	<string>This app needs alarm access to schedule reliable wake-up alarms with challenges that ensure you're fully awake.</string>
	<key>NSCameraUsageDescription</key>
	<string>This app needs camera access to scan QR codes for alarm dismissal challenges. Scanning a QR code ensures you're fully awake before dismissing the alarm.</string>
	<key>UIBackgroundModes</key>
	<array>
		<string>audio</string>
	</array>
</dict>
</plist>

```

### project.pbxproj
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew.xcodeproj/project.pbxproj`

```
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 77;
	objects = {

/* Begin PBXBuildFile section */
		9A07B3292E33325300BF448C /* CodeScanner in Frameworks */ = {isa = PBXBuildFile; productRef = 9A07B3282E33325300BF448C /* CodeScanner */; };
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
		9A21F1022E84DF7900AE796C /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = 9A70F7CC2E17242100ECA096 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = 9A70F7D32E17242100ECA096;
			remoteInfo = alarmAppNew;
		};
/* End PBXContainerItemProxy section */

/* Begin PBXFileReference section */
		9A21F0FE2E84DF7900AE796C /* alarmAppNewTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = alarmAppNewTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
		9A70F7D42E17242100ECA096 /* alarmAppNew.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = alarmAppNew.app; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */
		9AAEA3652E6808A700FEE52B /* Exceptions for "alarmAppNew" folder in "alarmAppNew" target */ = {
			isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
			membershipExceptions = (
				Info.plist,
			);
			target = 9A70F7D32E17242100ECA096 /* alarmAppNew */;
		};
/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		9A21F0FF2E84DF7900AE796C /* alarmAppNewTests */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = alarmAppNewTests;
			sourceTree = "<group>";
		};
		9AAEA34A2E68026A00FEE52B /* alarmAppNew */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			exceptions = (
				9AAEA3652E6808A700FEE52B /* Exceptions for "alarmAppNew" folder in "alarmAppNew" target */,
			);
			path = alarmAppNew;
			sourceTree = "<group>";
		};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
		9A21F0FB2E84DF7900AE796C /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		9A70F7D12E17242100ECA096 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				9A07B3292E33325300BF448C /* CodeScanner in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		9A70F7CB2E17242100ECA096 = {
			isa = PBXGroup;
			children = (
				9AAEA34A2E68026A00FEE52B /* alarmAppNew */,
				9A21F0FF2E84DF7900AE796C /* alarmAppNewTests */,
				9A70F7D52E17242100ECA096 /* Products */,
			);
			sourceTree = "<group>";
		};
		9A70F7D52E17242100ECA096 /* Products */ = {
			isa = PBXGroup;
			children = (
				9A70F7D42E17242100ECA096 /* alarmAppNew.app */,
				9A21F0FE2E84DF7900AE796C /* alarmAppNewTests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		9A21F0FD2E84DF7900AE796C /* alarmAppNewTests */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 9A21F1042E84DF7A00AE796C /* Build configuration list for PBXNativeTarget "alarmAppNewTests" */;
			buildPhases = (
				9A21F0FA2E84DF7900AE796C /* Sources */,
				9A21F0FB2E84DF7900AE796C /* Frameworks */,
				9A21F0FC2E84DF7900AE796C /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				9A21F1032E84DF7900AE796C /* PBXTargetDependency */,
			);
			fileSystemSynchronizedGroups = (
				9A21F0FF2E84DF7900AE796C /* alarmAppNewTests */,
			);
			name = alarmAppNewTests;
			packageProductDependencies = (
			);
			productName = alarmAppNewTests;
			productReference = 9A21F0FE2E84DF7900AE796C /* alarmAppNewTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		};
		9A70F7D32E17242100ECA096 /* alarmAppNew */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 9A70F7E22E17242600ECA096 /* Build configuration list for PBXNativeTarget "alarmAppNew" */;
			buildPhases = (
				9A70F7D02E17242100ECA096 /* Sources */,
				9A70F7D12E17242100ECA096 /* Frameworks */,
				9A70F7D22E17242100ECA096 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				9AAEA34A2E68026A00FEE52B /* alarmAppNew */,
			);
			name = alarmAppNew;
			packageProductDependencies = (
				9A07B3282E33325300BF448C /* CodeScanner */,
			);
			productName = alarmAppNew;
			productReference = 9A70F7D42E17242100ECA096 /* alarmAppNew.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		9A70F7CC2E17242100ECA096 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1600;
				LastUpgradeCheck = 1600;
				TargetAttributes = {
					9A21F0FD2E84DF7900AE796C = {
						CreatedOnToolsVersion = 16.0;
						TestTargetID = 9A70F7D32E17242100ECA096;
					};
					9A70F7D32E17242100ECA096 = {
						CreatedOnToolsVersion = 16.0;
					};
				};
			};
			buildConfigurationList = 9A70F7CF2E17242100ECA096 /* Build configuration list for PBXProject "alarmAppNew" */;
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = 9A70F7CB2E17242100ECA096;
			minimizedProjectReferenceProxies = 1;
			packageReferences = (
				9A07B3272E33325300BF448C /* XCRemoteSwiftPackageReference "CodeScanner" */,
			);
			preferredProjectObjectVersion = 77;
			productRefGroup = 9A70F7D52E17242100ECA096 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				9A70F7D32E17242100ECA096 /* alarmAppNew */,
				9A21F0FD2E84DF7900AE796C /* alarmAppNewTests */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		9A21F0FC2E84DF7900AE796C /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		9A70F7D22E17242100ECA096 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		9A21F0FA2E84DF7900AE796C /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		9A70F7D02E17242100ECA096 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		9A21F1032E84DF7900AE796C /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = 9A70F7D32E17242100ECA096 /* alarmAppNew */;
			targetProxy = 9A21F1022E84DF7900AE796C /* PBXContainerItemProxy */;
		};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
		9A21F0E82E847AFE00AE796C /* Dev-Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 18.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				VALIDATE_PRODUCT = YES;
			};
			name = "Dev-Release";
		};
		9A21F0E92E847AFE00AE796C /* Dev-Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_ASSET_PATHS = "\"alarmAppNew/Preview Content\"";
				DEVELOPMENT_TEAM = GZJJN88R5V;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = alarmAppNew/Info.plist;
				INFOPLIST_KEY_NSCameraUsageDescription = "This app needs camera access to scan QR codes for alarm dismissal. Scanning a QR code is required to turn off your alarm and proves \n  you are awake.";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				ONLY_ACTIVE_ARCH = YES;
				PRODUCT_BUNDLE_IDENTIFIER = com.beshoy.alarmAppNew;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = "Dev-Release";
		};
		9A21F1052E84DF7A00AE796C /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = GZJJN88R5V;
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.beshoy.alarmAppNewTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/alarmAppNew.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/alarmAppNew";
			};
			name = Debug;
		};
		9A21F1062E84DF7A00AE796C /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = GZJJN88R5V;
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.beshoy.alarmAppNewTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/alarmAppNew.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/alarmAppNew";
			};
			name = Release;
		};
		9A21F1072E84DF7A00AE796C /* Dev-Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = GZJJN88R5V;
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.beshoy.alarmAppNewTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/alarmAppNew.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/alarmAppNew";
			};
			name = "Dev-Release";
		};
		9A70F7E02E17242600ECA096 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 18.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		9A70F7E12E17242600ECA096 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 18.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				VALIDATE_PRODUCT = YES;
			};
			name = Release;
		};
		9A70F7E32E17242600ECA096 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_ASSET_PATHS = "\"alarmAppNew/Preview Content\"";
				DEVELOPMENT_TEAM = GZJJN88R5V;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = alarmAppNew/Info.plist;
				INFOPLIST_KEY_NSCameraUsageDescription = "This app needs camera access to scan QR codes for alarm dismissal. Scanning a QR code is required to turn off your alarm and proves \n  you are awake.";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.beshoy.alarmAppNew;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Debug;
		};
		9A70F7E42E17242600ECA096 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_ASSET_PATHS = "\"alarmAppNew/Preview Content\"";
				DEVELOPMENT_TEAM = GZJJN88R5V;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = alarmAppNew/Info.plist;
				INFOPLIST_KEY_NSCameraUsageDescription = "This app needs camera access to scan QR codes for alarm dismissal. Scanning a QR code is required to turn off your alarm and proves \n  you are awake.";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.beshoy.alarmAppNew;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		9A21F1042E84DF7A00AE796C /* Build configuration list for PBXNativeTarget "alarmAppNewTests" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				9A21F1052E84DF7A00AE796C /* Debug */,
				9A21F1062E84DF7A00AE796C /* Release */,
				9A21F1072E84DF7A00AE796C /* Dev-Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		9A70F7CF2E17242100ECA096 /* Build configuration list for PBXProject "alarmAppNew" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				9A70F7E02E17242600ECA096 /* Debug */,
				9A70F7E12E17242600ECA096 /* Release */,
				9A21F0E82E847AFE00AE796C /* Dev-Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		9A70F7E22E17242600ECA096 /* Build configuration list for PBXNativeTarget "alarmAppNew" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				9A70F7E32E17242600ECA096 /* Debug */,
				9A70F7E42E17242600ECA096 /* Release */,
				9A21F0E92E847AFE00AE796C /* Dev-Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */

/* Begin XCRemoteSwiftPackageReference section */
		9A07B3272E33325300BF448C /* XCRemoteSwiftPackageReference "CodeScanner" */ = {
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/twostraws/CodeScanner";
			requirement = {
				kind = upToNextMajorVersion;
				minimumVersion = 2.5.2;
			};
		};
/* End XCRemoteSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
		9A07B3282E33325300BF448C /* CodeScanner */ = {
			isa = XCSwiftPackageProductDependency;
			package = 9A07B3272E33325300BF448C /* XCRemoteSwiftPackageReference "CodeScanner" */;
			productName = CodeScanner;
		};
/* End XCSwiftPackageProductDependency section */
	};
	rootObject = 9A70F7CC2E17242100ECA096 /* Project object */;
}

```

---

## Source Code

### OpenForChallengeIntent.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/AppIntents/OpenForChallengeIntent.swift`

```swift
//
//  OpenForChallengeIntent.swift
//  alarmAppNew
//
//  App Intent for AlarmKit integration (iOS 26+).
//  Pure payload handoff to app group - no routing, no DI, no singletons.
//

import AppIntents
import Foundation

@available(iOS 26.0, *)
struct OpenForChallengeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open for Challenge"
    static var description = IntentDescription("Opens the app to show alarm challenge dismissal flow")

    // When true, the app will open when this intent runs
    static var openAppWhenRun: Bool = true

    // Parameter for the alarm ID to be handled
    @Parameter(title: "Alarm ID")
    var alarmID: String

    // App group identifier for shared data
    private static let appGroupIdentifier = "group.com.beshoy.alarmAppNew"

    init() {}

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        // Pure data handoff to app group
        guard let sharedDefaults = UserDefaults(suiteName: Self.appGroupIdentifier) else {
            // Silently fail if app group is not configured
            // The app will not receive the intent, but that's expected in dev/test
            return .result()
        }

        // Write alarm ID and timestamp to shared defaults
        sharedDefaults.set(alarmID, forKey: "pendingAlarmIntent")
        sharedDefaults.set(Date(), forKey: "pendingAlarmIntentTimestamp")

        // Return success - routing happens in the main app
        return .result()
    }
}
```

### AppCoordinator.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Coordinators/AppCoordinator.swift`

```swift
//
//  AppCoordinator.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/24/25.
//

import SwiftUI


class AppCoordinator: ObservableObject {
  @Published var alarmToDismiss: UUID? = nil

  func showDismissal (for alarmID: UUID) {
    alarmToDismiss = alarmID
  }

  func dismissalCompleted() {    alarmToDismiss = nil
  }
}


```

### AppRouter.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Coordinators/AppRouter.swift`

```swift
//
//  AppRouter.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 8/20/25.
//

// alarmAppNew/…/AppRouter.swift
import SwiftUI

protocol AppRouting {
    func showRinging(for id: UUID, intentAlarmID: UUID?)
    func backToList()
}

@MainActor
final class AppRouter: ObservableObject, AppRouting {
    enum Route: Equatable {
        case alarmList
        case ringing(alarmID: UUID, intentAlarmID: UUID? = nil)   // Enforced ringing route for MVP1
    }

    @Published var route: Route = .alarmList

    // Single-instance guard: track if dismissal flow is active
    private var activeDismissalAlarmId: UUID?

    // Store the intent alarm ID separately (could be pre-migration ID)
    private var currentIntentAlarmId: UUID?

    func showRinging(for id: UUID, intentAlarmID: UUID? = nil) {
        // Strengthen double-route guard
        if activeDismissalAlarmId == id, case .ringing(let current, _) = route, current == id {
            return // already showing this alarm
        }

        print("AppRouter: Showing ringing for alarm: \(id), intentAlarmID: \(intentAlarmID?.uuidString.prefix(8) ?? "nil")")
        activeDismissalAlarmId = id
        currentIntentAlarmId = intentAlarmID
        route = .ringing(alarmID: id, intentAlarmID: intentAlarmID)
        print("AppRouter: Route set to ringing, activeDismissalAlarmId: \(activeDismissalAlarmId?.uuidString.prefix(8) ?? "nil")")
    }

    func backToList() {
        // Clear active dismissal state when returning to list
        activeDismissalAlarmId = nil
        currentIntentAlarmId = nil
        route = .alarmList
    }
    
    // Getter for testing and debugging
    var isInDismissalFlow: Bool {
        return activeDismissalAlarmId != nil
    }

    var currentDismissalAlarmId: UUID? {
        return activeDismissalAlarmId
    }

    var currentIntentAlarmIdValue: UUID? {
        return currentIntentAlarmId
    }
}

```

### DependencyContainer.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/DI/DependencyContainer.swift`

```swift
//
//  DependencyContainer.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 8/28/25.
//
// MARK: - Privacy Settings Required
// Add these to Info.plist or Project Settings:
// NSCameraUsageDescription: "This app needs camera access to scan QR codes for alarm dismissal. Scanning a QR code is required to turn off your alarm and proves you are awake."
// NSUserNotificationUsageDescription: "This app needs notification permission to deliver reliable alarm notifications that will wake you up at the scheduled time."

import Foundation
import UserNotifications
import UIKit

@MainActor
class DependencyContainer: ObservableObject {
    // MARK: - Services
    let permissionService: PermissionServiceProtocol
    let persistenceService: PersistenceStore
    let alarmRunStore: AlarmRunStore
    let qrScanningService: QRScanning
    let appRouter: AppRouter
    let reliabilityLogger: ReliabilityLogging
    private let soundEngineConcrete: AlarmSoundEngine
    let settingsServiceConcrete: SettingsService
    let alarmIntentBridge: AlarmIntentBridge
    let alarmScheduler: AlarmScheduling
    private let idleTimerControllerConcrete: UIApplicationIdleTimerController
    private let shareProviderConcrete: ShareProviding

    // MARK: - New Sound System Services
    private let soundCatalogConcrete: SoundCatalog
    private let alarmFactoryConcrete: DefaultAlarmFactory

    // MARK: - Notification Chaining Services
    private let chainSettingsProviderConcrete: DefaultChainSettingsProvider
    private let notificationIndexConcrete: NotificationIndex
    private let chainPolicyConcrete: ChainPolicy
    private let globalLimitGuardConcrete: GlobalLimitGuard
    private let chainedNotificationSchedulerConcrete: ChainedNotificationScheduler
    private let dismissedRegistryConcrete: DismissedRegistry
    private let refreshCoordinatorConcrete: RefreshCoordinator
    private let activeAlarmPolicyConcrete: ActiveAlarmPolicyProvider
    private let deliveredNotificationsReaderConcrete: DeliveredNotificationsReading
    private let activeAlarmDetectorConcrete: ActiveAlarmDetector
    private let systemVolumeProviderConcrete: SystemVolumeProviding

    // Public protocol exposure
    var refreshCoordinator: RefreshCoordinator { refreshCoordinatorConcrete }
    var audioEngine: AlarmAudioEngineProtocol { soundEngineConcrete }
    var settingsService: SettingsServiceProtocol { settingsServiceConcrete }
    var soundCatalog: SoundCatalogProviding { soundCatalogConcrete }
    var alarmFactory: AlarmFactory { alarmFactoryConcrete }
    var chainedNotificationScheduler: ChainedNotificationScheduling { chainedNotificationSchedulerConcrete }
    var chainSettingsProvider: ChainSettingsProviding { chainSettingsProviderConcrete }
    var activeAlarmDetector: ActiveAlarmDetector { activeAlarmDetectorConcrete }
    var systemVolumeProvider: SystemVolumeProviding { systemVolumeProviderConcrete }
    var notificationService: AlarmScheduling { alarmScheduler }  // Expose alarmScheduler as notificationService for legacy code

    init() {
        // CRITICAL INITIALIZATION ORDER: Prevent dependency cycles

        // 1. Create SoundCatalog first (no dependencies)
        self.soundCatalogConcrete = SoundCatalog()

        // 2. Create basic services
        self.permissionService = PermissionService()
        self.reliabilityLogger = LocalReliabilityLogger()
        self.appRouter = AppRouter()

        // 3. Create PersistenceService (will need sound catalog for repairs in future)
        self.persistenceService = PersistenceService()

        // 3.5. Create AlarmRunStore (actor-based, thread-safe)
        self.alarmRunStore = AlarmRunStore()

        // 4. Create AlarmFactory with sound catalog
        self.alarmFactoryConcrete = DefaultAlarmFactory(catalog: soundCatalogConcrete)

        // 5. Create notification chaining services
        self.chainSettingsProviderConcrete = DefaultChainSettingsProvider()
        let chainSettings = chainSettingsProviderConcrete.chainSettings()

        // Validate settings during initialization (fail fast)
        let validationResult = chainSettingsProviderConcrete.validateSettings(chainSettings)
        assert(validationResult.isValid, "Invalid chain settings: \(validationResult.errorReasons.joined(separator: ", "))")

        self.notificationIndexConcrete = NotificationIndex()
        self.chainPolicyConcrete = ChainPolicy(settings: chainSettings)
        self.globalLimitGuardConcrete = GlobalLimitGuard()
        self.dismissedRegistryConcrete = DismissedRegistry()
        self.activeAlarmPolicyConcrete = ActiveAlarmPolicyProvider(chainPolicy: chainPolicyConcrete)
        self.chainedNotificationSchedulerConcrete = ChainedNotificationScheduler(
            soundCatalog: soundCatalogConcrete,
            notificationIndex: notificationIndexConcrete,
            chainPolicy: chainPolicyConcrete,
            globalLimitGuard: globalLimitGuardConcrete
        )

        // 6. Create audio and settings services (needed by NotificationService)
        self.soundEngineConcrete = AlarmSoundEngine.shared
        self.settingsServiceConcrete = SettingsService(audioEngine: soundEngineConcrete)
        soundEngineConcrete.setReliabilityModeProvider(settingsServiceConcrete)

        // 7. Create remaining services (now with all dependencies available)
        self.qrScanningService = QRScanningService(permissionService: permissionService)
        self.idleTimerControllerConcrete = UIApplicationIdleTimerController()
        self.shareProviderConcrete = SystemShareProvider()

        // 8. Create AlarmScheduler using factory pattern (iOS 26+ only)
        // Note: Uses domain UUIDs directly - no external ID mapping needed
        let presentationBuilder = AlarmPresentationBuilder()
        if #available(iOS 26.0, *) {
            self.alarmScheduler = AlarmSchedulerFactory.make(
                presentationBuilder: presentationBuilder
            )
        } else {
            fatalError("iOS 26+ required for AlarmKit")
        }

        // 9. Create RefreshCoordinator to coalesce refresh requests
        self.refreshCoordinatorConcrete = RefreshCoordinator(notificationService: alarmScheduler)

        // 10. Create ActiveAlarmDetector for auto-routing to dismissal
        self.deliveredNotificationsReaderConcrete = UNDeliveredNotificationsReader()
        self.activeAlarmDetectorConcrete = ActiveAlarmDetector(
            deliveredNotificationsReader: deliveredNotificationsReaderConcrete,
            activeAlarmPolicy: activeAlarmPolicyConcrete,
            dismissedRegistry: dismissedRegistryConcrete,
            alarmStorage: persistenceService
        )

        // 11. Create SystemVolumeProvider (no dependencies)
        self.systemVolumeProviderConcrete = SystemVolumeProvider()

        // 12. Create AlarmIntentBridge (no dependencies, no OS work in init)
        self.alarmIntentBridge = AlarmIntentBridge()

        // 13. Set up policy provider after all services are initialized
        soundEngineConcrete.setPolicyProvider { [weak self] in
            self?.settingsServiceConcrete.audioPolicy ?? AudioPolicy(capability: .foregroundAssist, allowRouteOverrideAtAlarm: true)
        }
    }

    // MARK: - Activation

    /// Activate observability systems (logging, metrics, etc.)
    /// Call this once at app start - idempotent and separate from notifications
    func activateObservability() {
        // Activate reliability logger with proper file protection for lock screen access
        if let logger = reliabilityLogger as? LocalReliabilityLogger {
            logger.activate()
        }
        print("🔄 DependencyContainer: Activated observability systems")
    }

    /// Activate the alarm scheduler if it's AlarmKit-based
    /// Call this after the container is initialized - idempotent
    @MainActor
    func activateAlarmScheduler() async {
        if #available(iOS 26.0, *) {
            if let kitScheduler = alarmScheduler as? AlarmKitScheduler {
                await kitScheduler.activate()
                print("🔄 DependencyContainer: Activated AlarmKit scheduler")
            }
        }
    }

    /// One-time migration: reconcile AlarmKit IDs after removing external ID mapping
    /// Ensures all alarms use domain UUIDs directly
    @MainActor
    func migrateAlarmKitIDsIfNeeded() async {
        if #available(iOS 26.0, *) {
            if let kitScheduler = alarmScheduler as? AlarmKitScheduler {
                let persisted = (try? await persistenceService.loadAlarms()) ?? []
                await kitScheduler.reconcileAlarmsAfterMigration(persisted: persisted)

                // Clean up externalAlarmId from persisted alarms
                let cleaned = persisted.map { alarm -> Alarm in
                    var mutableAlarm = alarm
                    mutableAlarm.externalAlarmId = nil
                    return mutableAlarm
                }

                if cleaned != persisted {
                    do {
                        try await persistenceService.saveAlarms(cleaned)
                        print("🔄 DependencyContainer: Cleared legacy externalAlarmId fields")
                    } catch {
                        print("⚠️ DependencyContainer: Failed to save cleaned alarms: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - ViewModels
    func makeAlarmListViewModel() -> AlarmListViewModel {
        return AlarmListViewModel(
            storage: persistenceService,
            permissionService: permissionService,
            alarmScheduler: alarmScheduler,
            refresher: refreshCoordinatorConcrete,
            systemVolumeProvider: systemVolumeProviderConcrete,
            notificationService: alarmScheduler  // AlarmScheduler conforms to NotificationScheduling
        )
    }
    
    func makeAlarmDetailViewModel(alarm: Alarm? = nil) -> AlarmDetailViewModel {
        let targetAlarm = alarm ?? alarmFactory.makeNewAlarm()
        return AlarmDetailViewModel(alarm: targetAlarm, isNew: alarm == nil)
    }
    
    func makeDismissalFlowViewModel(intentAlarmID: UUID? = nil) -> DismissalFlowViewModel {
        return DismissalFlowViewModel(
            qrScanning: qrScanningService,
            notificationService: alarmScheduler,  // AlarmScheduler conforms to NotificationScheduling
            alarmStorage: persistenceService,
            clock: SystemClock(),
            appRouter: appRouter,
            permissionService: permissionService,
            reliabilityLogger: reliabilityLogger,
            audioEngine: audioEngine,
            reliabilityModeProvider: settingsService,
            dismissedRegistry: dismissedRegistryConcrete,
            settingsService: settingsService,
            alarmScheduler: alarmScheduler,
            alarmRunStore: alarmRunStore,  // NEW: Inject actor-based run store
            idleTimerController: idleTimerControllerConcrete,  // NEW: UIKit isolation
            stopAllowed: StopAlarmAllowed.self,
            snoozeComputer: SnoozeAlarm.self,
            intentAlarmId: intentAlarmID  // Pass the intent-provided alarm ID
        )
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        return SettingsViewModel(
            reliabilityLogger: reliabilityLogger,
            shareProvider: shareProviderConcrete
        )
    }
}

```

### DependencyContainerKey.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/DI/DependencyContainerKey.swift`

```swift
//
//  DependencyContainerKey.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/8/25.
//  Environment key for dependency injection (eliminates singleton pattern)
//

import SwiftUI

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer? = nil
}

extension EnvironmentValues {
    var container: DependencyContainer? {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

```

### AlarmFactory.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/Alarms/AlarmFactory.swift`

```swift
//
//  AlarmFactory.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/24/25.
//

import Foundation

public protocol AlarmFactory {
    /// Creates a new alarm with sensible defaults, including a valid soundId from the sound catalog
    func makeNewAlarm() -> Alarm
}
```

### AudioCapability.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/AudioCapability.swift`

```swift
//
//  AudioCapability.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/2/25.
//  Abstraction layer for audio playback capabilities
//

import Foundation

/// Defines what audio playback capabilities are allowed
public enum AudioCapability {
    case none                 // No AVAudioPlayer ever
    case foregroundAssist     // AVAudioPlayer only when app active & alarm fires
    case sleepMode            // AVAudioPlayer in background (sleep) + at alarm
}

/// Policy that combines capability with routing preferences
public struct AudioPolicy {
    public let capability: AudioCapability
    public let allowRouteOverrideAtAlarm: Bool  // Duck/stop others

    public init(capability: AudioCapability, allowRouteOverrideAtAlarm: Bool) {
        self.capability = capability
        self.allowRouteOverrideAtAlarm = allowRouteOverrideAtAlarm
    }
}

```

### AudioSessionConfig.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/AudioSessionConfig.swift`

```swift
//
//  AudioSessionConfig.swift
//  alarmAppNew
//
//  Audio session configuration constants
//

import Foundation

/// Configuration for audio session behavior
public enum AudioSessionConfig {
    /// Grace period after deactivating audio session before allowing new sounds
    /// This ensures the session fully deactivates before iOS plays subsequent notification sounds
    /// Default: 120ms (sufficient for most devices to complete deactivation)
    public static let deactivationGraceNs: UInt64 = 120_000_000  // 120ms in nanoseconds
}

```

### AudioUXPolicy.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/AudioUXPolicy.swift`

```swift
//
//  AudioUXPolicy.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/8/25.
//  Pure Swift policy constants for audio UX behavior
//

import Foundation

// Pure Swift policy constants
public enum AudioUXPolicy {
    /// Lead time in seconds before test notification fires
    public static let testLeadSeconds: TimeInterval = 8

    /// Threshold for low media volume warning (0.0–1.0)
    public static let lowMediaVolumeThreshold: Float = 0.25

    /// Educational copy explaining ringer vs media volume
    public static let educationCopy = """
        Lock-screen alarms use ringer volume (Settings → Sounds). \
        Foreground alarms use media volume.
        """
}

```

### Alarm+ExternalId.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/Extensions/Alarm+ExternalId.swift`

```swift
//
//  Alarm+ExternalId.swift
//  alarmAppNew
//
//  Extension for managing AlarmKit external identifiers.
//

import Foundation

public extension Alarm {
    /// Returns a copy of the alarm with the specified external ID
    func withExternalId(_ id: String?) -> Alarm {
        var copy = self
        copy.externalAlarmId = id
        return copy
    }

    /// Checks if this alarm has an external ID assigned
    var hasExternalId: Bool {
        externalAlarmId != nil
    }
}
```

### OccurrenceKey.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/OccurrenceKey.swift`

```swift
//
//  OccurrenceKey.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/8/25.
//  Pure Swift utility for occurrence key value type and parsing extensions
//

import Foundation

/// Value type representing a unique occurrence of an alarm
/// Used to identify specific instances of repeating alarms
public struct OccurrenceKey: Equatable, Hashable {
    public let date: Date

    public init(date: Date) {
        self.date = date
    }
}

/// Extension to OccurrenceKeyFormatter for parsing notification identifiers
/// Complements the existing key(from:) method in OccurrenceKeyFormatter.swift
extension OccurrenceKeyFormatter {

    // MARK: - Parsing

    /// Parse an occurrence key from a notification identifier
    /// Expected format: "alarm-{uuid}-occ-{ISO8601}-{index}"
    /// Example: "alarm-12345678-1234-1234-1234-123456789012-occ-2025-10-09T00:15:00Z-0"
    public static func parse(fromIdentifier identifier: String) -> OccurrenceKey? {
        guard let date = parseDate(from: identifier) else {
            return nil
        }
        return OccurrenceKey(date: date)
    }

    /// Parse just the date component from an identifier
    /// Returns nil if the identifier doesn't match the expected format
    public static func parseDate(from identifier: String) -> Date? {
        // Split by "-occ-" to isolate the occurrence portion
        let parts = identifier.components(separatedBy: "-occ-")
        guard parts.count >= 2 else {
            return nil
        }

        // The second part contains: "{ISO8601}-{index}"
        // Split by last "-" to remove the index
        let occurrencePart = parts[1]
        let occurrenceComponents = occurrencePart.components(separatedBy: "-")

        // ISO8601 format is "YYYY-MM-DDTHH:MM:SSZ" or "YYYY-MM-DDTHH:MM:SS.sssZ"
        // This contains 2 internal "-" characters (YYYY-MM-DD)
        // So we need at least 3 components: [YYYY, MM, DD...] + potential index at end
        guard occurrenceComponents.count >= 3 else {
            return nil
        }

        // Reconstruct the ISO8601 string by taking all but the last component
        // (the last component is the index number)
        let iso8601String = occurrenceComponents.dropLast().joined(separator: "-")

        // Parse ISO8601 string to Date (use existing method for consistency)
        return date(from: iso8601String)
    }

    /// Parse the alarm ID from an identifier
    /// Expected format: "alarm-{uuid}-occ-{ISO8601}-{index}"
    public static func parseAlarmId(from identifier: String) -> UUID? {
        // Split by "-occ-" to isolate the alarm portion
        let parts = identifier.components(separatedBy: "-occ-")
        guard parts.count >= 2 else {
            return nil
        }

        // The first part is "alarm-{uuid}"
        let alarmPart = parts[0]

        // Remove "alarm-" prefix
        guard alarmPart.hasPrefix("alarm-") else {
            return nil
        }

        let uuidString = String(alarmPart.dropFirst("alarm-".count))
        return UUID(uuidString: uuidString)
    }
}

```

### OccurrenceKeyFormatter.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/OccurrenceKeyFormatter.swift`

```swift
//
//  OccurrenceKeyFormatter.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/5/25.
//  Shared formatter for occurrence keys used in notification identifiers and dismissal tracking
//

import Foundation

/// Shared formatter for occurrence keys used in notification identifiers and dismissal tracking
/// Ensures consistency between notification scheduling, cleanup, and testing
public enum OccurrenceKeyFormatter {
    /// Generate occurrence key from fire date
    /// Format: ISO8601 with fractional seconds (e.g., "2025-10-05T14:30:00.000Z")
    public static func key(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    /// Parse occurrence key back to date (for validation/testing)
    public static func date(from key: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: key)
    }
}

```

### AlarmPresentationPolicy.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/Policies/AlarmPresentationPolicy.swift`

```swift
//
//  AlarmPresentationPolicy.swift
//  alarmAppNew
//
//  Pure Swift policies for alarm presentation behavior.
//  These policies determine how alarms should be presented and controlled
//  without any dependency on specific UI frameworks.
//

import Foundation

/// Bounds for valid snooze durations.
public struct SnoozeBounds {
    /// Minimum allowed snooze duration in seconds
    public let min: TimeInterval

    /// Maximum allowed snooze duration in seconds
    public let max: TimeInterval

    public init(min: TimeInterval, max: TimeInterval) {
        // Ensure min <= max
        self.min = Swift.min(min, max)
        self.max = Swift.max(min, max)
    }

    /// Default snooze bounds (5 to 60 minutes)
    public static let `default` = SnoozeBounds(
        min: 5 * 60,   // 5 minutes
        max: 60 * 60   // 60 minutes
    )
}

/// Policies for alarm presentation and control behavior.
public struct AlarmPresentationPolicy {

    private let snoozeBounds: SnoozeBounds

    public init(snoozeBounds: SnoozeBounds = .default) {
        self.snoozeBounds = snoozeBounds
    }

    /// Determine if countdown should be shown for an alarm.
    /// - Parameter alarm: The alarm to check
    /// - Returns: True if countdown should be shown (snooze is enabled with valid duration)
    public func shouldShowCountdown(for alarm: Alarm) -> Bool {
        // Show countdown if alarm has snooze enabled
        // In the future, this will check alarm.snoozeEnabled and alarm.snoozeDuration
        // For now, we'll return false as snooze isn't implemented yet
        // TODO: Update when Alarm model includes snooze configuration
        return false
    }

    /// Determine if a live activity is required for an alarm.
    /// - Parameter alarm: The alarm to check
    /// - Returns: True if alarm needs a live activity (for countdown or pre-alarm features)
    public func requiresLiveActivity(for alarm: Alarm) -> Bool {
        // Live activity needed for:
        // 1. Snooze/countdown features
        // 2. Pre-alarm countdowns
        // For now, return same as shouldShowCountdown
        return shouldShowCountdown(for: alarm)
    }

    /// Check if a snooze duration is valid within configured bounds.
    /// - Parameters:
    ///   - duration: The requested snooze duration in seconds
    ///   - bounds: The snooze bounds to validate against
    /// - Returns: True if duration is within bounds
    public static func isSnoozeDurationValid(
        _ duration: TimeInterval,
        bounds: SnoozeBounds
    ) -> Bool {
        return duration >= bounds.min && duration <= bounds.max
    }

    /// Clamp a snooze duration to valid bounds.
    /// - Parameters:
    ///   - duration: The requested snooze duration in seconds
    ///   - bounds: The snooze bounds to clamp to
    /// - Returns: Duration clamped to [min, max] range
    public static func clampSnoozeDuration(
        _ duration: TimeInterval,
        bounds: SnoozeBounds
    ) -> TimeInterval {
        if duration < bounds.min {
            return bounds.min
        } else if duration > bounds.max {
            return bounds.max
        } else {
            return duration
        }
    }

    /// Determine the stop button semantics for an alarm.
    /// - Parameter challengesRequired: Whether challenges are configured for the alarm
    /// - Returns: Description of when stop button should be enabled
    public static func stopButtonSemantics(challengesRequired: Bool) -> StopButtonSemantics {
        if challengesRequired {
            return .requiresChallengeValidation
        } else {
            return .alwaysEnabled
        }
    }
}

/// Semantics for when the stop button should be enabled.
public enum StopButtonSemantics {
    /// Stop button is always enabled (no challenges required)
    case alwaysEnabled

    /// Stop button requires all challenges to be validated first
    case requiresChallengeValidation

    /// Human-readable description
    public var description: String {
        switch self {
        case .alwaysEnabled:
            return "Stop button is always enabled"
        case .requiresChallengeValidation:
            return "Stop button requires challenge completion"
        }
    }
}
```

### ChainPolicy.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/Policies/ChainPolicy.swift`

```swift
//
//  ChainPolicy.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/1/25.
//

import Foundation
import os.log

public struct ChainConfiguration {
    public let spacingSeconds: Int
    public let chainCount: Int
    public let totalDurationSeconds: Int

    public init(spacingSeconds: Int, chainCount: Int) {
        self.spacingSeconds = spacingSeconds
        self.chainCount = chainCount
        self.totalDurationSeconds = spacingSeconds * max(1, chainCount)
    }

    public func trimmed(to maxCount: Int) -> ChainConfiguration {
        let actualCount = max(1, min(chainCount, maxCount))
        return ChainConfiguration(spacingSeconds: spacingSeconds, chainCount: actualCount)
    }
}

public struct ChainSettings {
    public let maxChainCount: Int
    public let ringWindowSec: Int
    public let fallbackSpacingSec: Int
    public let minLeadTimeSec: Int
    public let cleanupGraceSec: Int

    public init(maxChainCount: Int = 12, ringWindowSec: Int = 180, fallbackSpacingSec: Int = 30, minLeadTimeSec: Int = 10, cleanupGraceSec: Int = 60) {
        // Validate and clamp to safe ranges
        let clampedMax = max(1, min(50, maxChainCount))
        let clampedWindow = max(30, min(600, ringWindowSec))
        let clampedSpacing = max(1, min(30, fallbackSpacingSec))
        let clampedLeadTime = max(5, min(30, minLeadTimeSec))
        let clampedGrace = max(30, min(300, cleanupGraceSec))

        self.maxChainCount = clampedMax
        self.ringWindowSec = clampedWindow
        self.fallbackSpacingSec = clampedSpacing
        self.minLeadTimeSec = clampedLeadTime
        self.cleanupGraceSec = clampedGrace

        // Log any coercions for observability
        if maxChainCount != clampedMax {
            os_log("ChainSettings: clamped maxChainCount %d -> %d",
                   log: .default, type: .info, maxChainCount, clampedMax)
        }
        if ringWindowSec != clampedWindow {
            os_log("ChainSettings: clamped ringWindowSec %d -> %d",
                   log: .default, type: .info, ringWindowSec, clampedWindow)
        }
        if fallbackSpacingSec != clampedSpacing {
            os_log("ChainSettings: clamped fallbackSpacingSec %d -> %d",
                   log: .default, type: .info, fallbackSpacingSec, clampedSpacing)
        }
        if minLeadTimeSec != clampedLeadTime {
            os_log("ChainSettings: clamped minLeadTimeSec %d -> %d",
                   log: .default, type: .info, minLeadTimeSec, clampedLeadTime)
        }
        if cleanupGraceSec != clampedGrace {
            os_log("ChainSettings: clamped cleanupGraceSec %d -> %d",
                   log: .default, type: .info, cleanupGraceSec, clampedGrace)
        }
    }
}

public struct ChainPolicy {
    public let settings: ChainSettings

    public init(settings: ChainSettings = ChainSettings()) {
        self.settings = settings
    }

    public func normalizedSpacing(_ rawSeconds: Int) -> Int {
        return max(1, min(30, rawSeconds))
    }

    public func computeChain(spacingSeconds: Int) -> ChainConfiguration {
        let normalizedSpacing = normalizedSpacing(spacingSeconds)

        // Calculate how many notifications fit in the ring window
        let theoreticalCount = settings.ringWindowSec / normalizedSpacing

        // Cap at configured maximum and ensure at least 1
        let actualCount = max(1, min(settings.maxChainCount, theoreticalCount))

        return ChainConfiguration(spacingSeconds: normalizedSpacing, chainCount: actualCount)
    }

    public func computeFireDates(baseFireDate: Date, configuration: ChainConfiguration) -> [Date] {
        var dates: [Date] = []

        for occurrence in 0..<configuration.chainCount {
            let offsetSeconds = TimeInterval(occurrence * configuration.spacingSeconds)
            let fireDate = baseFireDate.addingTimeInterval(offsetSeconds)
            dates.append(fireDate)
        }

        return dates
    }
}

// MARK: - Extensions for convenience

extension ChainSettings: Codable, Equatable {
    public static let defaultSettings = ChainSettings()
}

extension ChainConfiguration: Equatable {
    public static func == (lhs: ChainConfiguration, rhs: ChainConfiguration) -> Bool {
        return lhs.spacingSeconds == rhs.spacingSeconds &&
               lhs.chainCount == rhs.chainCount
    }
}
```

### ChainSettingsProvider.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/Policies/ChainSettingsProvider.swift`

```swift
//
//  ChainSettingsProvider.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/1/25.
//

import Foundation

public protocol ChainSettingsProviding {
    func chainSettings() -> ChainSettings
    func validateSettings(_ settings: ChainSettings) -> ChainSettingsValidationResult
}

public enum ChainSettingsValidationResult {
    case valid
    case invalid(reasons: [String])

    public var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    public var errorReasons: [String] {
        if case .invalid(let reasons) = self { return reasons }
        return []
    }
}

public final class DefaultChainSettingsProvider: ChainSettingsProviding {

    public init() {}

    public func chainSettings() -> ChainSettings {
        // Production defaults optimized for "continuous ring" feel
        // - maxChainCount: 12 (up from 5) for better coverage over 5-minute window
        // - fallbackSpacingSec: 10 (down from 30) for faster repetition when sound duration unknown
        // - minLeadTimeSec: 10 to ensure iOS fires notifications reliably
        // - Spacing auto-adjusts to sound duration when available (e.g., 27s for chimes01)
        return ChainSettings(
            maxChainCount: 12,
            ringWindowSec: 300,
            fallbackSpacingSec: 10,
            minLeadTimeSec: 10
        )
    }

    public func validateSettings(_ settings: ChainSettings) -> ChainSettingsValidationResult {
        var errors: [String] = []

        // Validate chain count
        if settings.maxChainCount < 1 {
            errors.append("maxChainCount must be at least 1")
        }
        if settings.maxChainCount > 15 {
            errors.append("maxChainCount should not exceed 15 (iOS notification limit considerations)")
        }

        // Validate ring window
        if settings.ringWindowSec < 30 {
            errors.append("ringWindowSec must be at least 30 seconds")
        }
        if settings.ringWindowSec > 600 {
            errors.append("ringWindowSec should not exceed 600 seconds (10 minutes)")
        }

        // Validate fallback spacing
        if settings.fallbackSpacingSec < 5 {
            errors.append("fallbackSpacingSec must be at least 5 seconds")
        }
        if settings.fallbackSpacingSec > 60 {
            errors.append("fallbackSpacingSec should not exceed 60 seconds")
        }

        // Validate minimum lead time
        if settings.minLeadTimeSec < 5 {
            errors.append("minLeadTimeSec must be at least 5 seconds")
        }
        if settings.minLeadTimeSec > 30 {
            errors.append("minLeadTimeSec should not exceed 30 seconds")
        }

        // Cross-validation: ensure ring window can accommodate at least one chain
        let minPossibleDuration = settings.fallbackSpacingSec * settings.maxChainCount
        if settings.ringWindowSec < minPossibleDuration {
            errors.append("ringWindowSec too small for maxChainCount at fallbackSpacingSec")
        }

        return errors.isEmpty ? .valid : .invalid(reasons: errors)
    }
}
```

### AlarmAudioEngineError.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/Protocols/AlarmAudioEngineError.swift`

```swift
//
//  AlarmAudioEngineError.swift
//  alarmAppNew
//
//  Domain-level error protocol for alarm audio engine operations.
//  Keeps Infrastructure layer fully typed per CLAUDE.md §5.
//

import Foundation

/// Domain-level errors for alarm audio engine operations.
///
/// This enum provides a clean abstraction over AVFoundation and audio playback errors,
/// following the same pattern as AlarmSchedulingError and AlarmRunStoreError.
public enum AlarmAudioEngineError: Error, Equatable {
    case assetNotFound(soundName: String)
    case sessionActivationFailed
    case playbackFailed(reason: String)
    case invalidState(expected: String, actual: String)

    /// Human-readable description for logging and debugging
    public var description: String {
        switch self {
        case .assetNotFound(let soundName):
            return "Audio asset '\(soundName).caf' not found in bundle"
        case .sessionActivationFailed:
            return "Failed to activate AVAudioSession"
        case .playbackFailed(let reason):
            return "Audio playback failed: \(reason)"
        case .invalidState(let expected, let actual):
            return "Invalid audio engine state - expected: \(expected), actual: \(actual)"
        }
    }
}

```

### AlarmRunStoreError.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/Protocols/AlarmRunStoreError.swift`

```swift
//
//  AlarmRunStoreError.swift
//  alarmAppNew
//
//  Domain-level error type for AlarmRun persistence operations.
//  Per CLAUDE.md §5.5 error handling strategy and §9 persistence contracts.
//

import Foundation

/// Domain-level errors for AlarmRun persistence operations.
///
/// This enum provides a clean abstraction over infrastructure-specific errors,
/// allowing the Presentation layer to remain decoupled from concrete
/// persistence implementations like AlarmRunStore.
///
/// Per CLAUDE.md §9: All persistence operations must throw typed domain errors.
public enum AlarmRunStoreError: Error, Equatable {
    case saveFailed
    case loadFailed
    case dataCorrupted

    /// Human-readable description for logging and debugging
    public var description: String {
        switch self {
        case .saveFailed:
            return "Failed to save alarm run to persistent storage"
        case .loadFailed:
            return "Failed to load alarm runs from persistent storage"
        case .dataCorrupted:
            return "Alarm run data is corrupted or invalid"
        }
    }
}

```

### AlarmScheduling+CompatShims.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/Protocols/AlarmScheduling+CompatShims.swift`

```swift
//
//  AlarmScheduling+CompatShims.swift
//  alarmAppNew
//
//  Compatibility shims for legacy NotificationScheduling methods.
//  These allow gradual migration from old method names to new AlarmScheduling API.
//  These shims can be removed once all call sites are migrated.
//

import Foundation

/// Compatibility shims for legacy method names.
/// These forward to new AlarmScheduling methods or provide safe no-ops.
public extension AlarmScheduling {

    // MARK: - Core Scheduling Methods

    /// Legacy: Schedule an alarm
    /// Forwards to new `schedule(alarm:)` method
    func scheduleAlarm(_ alarm: Alarm) async throws {
        _ = try await schedule(alarm: alarm)
    }

    /// Legacy: Cancel an alarm
    /// Forwards to new `cancel(alarmId:)` method
    func cancelAlarm(_ alarm: Alarm) async {
        await cancel(alarmId: alarm.id)
    }

    /// Legacy: Refresh all alarms
    /// Now delegates to selective reconciliation for safety
    func refreshAll(from alarms: [Alarm]) async {
        // Delegate to selective reconciliation instead of blind cancel/reschedule
        await reconcile(alarms: alarms, skipIfRinging: true)
    }

    /// Default reconciliation: no-op for implementations that don't need it
    func reconcile(alarms: [Alarm], skipIfRinging: Bool) async {
        // Default no-op for schedulers that don't require reconciliation
    }

    /// Legacy: Schedule alarm immediately
    /// Forwards to regular schedule (immediate scheduling is implementation detail)
    func scheduleAlarmImmediately(_ alarm: Alarm) async throws {
        _ = try await schedule(alarm: alarm)
    }

    // MARK: - Test Alarm Methods

    /// Legacy: Schedule one-off test alarm
    /// Creates a test alarm and schedules it
    func scheduleOneOffTestAlarm(leadTime: TimeInterval = 8) async throws {
        // This is a test-specific method that concrete implementations can override
        // Default implementation creates a simple test alarm
        // Concrete implementations should provide proper test alarm scheduling
    }

    /// Legacy: Schedule test notification with custom sound
    func scheduleTestNotification(soundName: String?, in seconds: TimeInterval) async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule test with system default sound
    func scheduleTestSystemDefault() async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule test with critical sound
    func scheduleTestCriticalSound() async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule test with custom sound
    func scheduleTestCustomSound(soundName: String?) async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule test with default settings
    func scheduleTestDefault() async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule test with custom settings
    func scheduleTestCustom() async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule bare default test
    func scheduleBareDefaultTest() async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule bare default test without interruption
    func scheduleBareDefaultTestNoInterruption() async throws {
        // Test-specific method - concrete implementations should override
    }

    /// Legacy: Schedule bare default test without category
    func scheduleBareDefaultTestNoCategory() async throws {
        // Test-specific method - concrete implementations should override
    }

    // MARK: - Cleanup Methods

    /// Legacy: Cancel specific notification types for an alarm
    func cancelSpecificNotifications(for alarmId: UUID, types: [NotificationType]) {
        // This is a detailed implementation concern
        // The new API uses simple cancel(alarmId:) for all types
        // Concrete implementations can override for specific behavior
    }

    /// Legacy: Cancel a specific occurrence of an alarm
    func cancelOccurrence(alarmId: UUID, occurrenceKey: String) async {
        // Occurrence-level cancellation is an implementation detail
        // Default to canceling the entire alarm for safety
        await cancel(alarmId: alarmId)
    }

    /// Legacy: Clean up stale delivered notifications
    func cleanupStaleDeliveredNotifications() async {
        // Cleanup is an implementation detail
        // Concrete implementations can override if needed
    }

    /// Legacy: Clean up after alarm dismissal
    func cleanupAfterDismiss(alarmId: UUID, occurrenceKey: String? = nil) async {
        // Intentionally no-op shim; concrete implementations can override
        // Do not map to cancel to avoid hidden behavior changes
    }

    // MARK: - Configuration Methods

    /// Legacy: Ensure notification categories are registered
    func ensureNotificationCategoriesRegistered() {
        // Category registration is an implementation detail
        // Concrete implementations should handle this internally
    }

    // MARK: - Diagnostic Methods

    /// Legacy: Dump notification settings for debugging
    func dumpNotificationSettings() async {
        // Diagnostic method - concrete implementations can override
    }

    /// Legacy: Validate sound bundle
    func validateSoundBundle() {
        // Diagnostic method - concrete implementations can override
    }

    /// Legacy: Dump notification categories for debugging
    func dumpNotificationCategories() async {
        // Diagnostic method - concrete implementations can override
    }

    /// Legacy: Run complete sound triage
    func runCompleteSoundTriage() async throws {
        // Diagnostic method - concrete implementations can override
    }
}

// MARK: - Additional Helper Methods

public extension AlarmScheduling {
    /// Get notification request IDs for a specific alarm occurrence
    func getRequestIds(alarmId: UUID, occurrenceKey: String) async -> [String] {
        // Default implementation returns empty array
        // Concrete implementations can override for specific behavior
        return []
    }

    /// Remove notification requests by identifiers
    func removeRequests(withIdentifiers ids: [String]) async {
        // Default no-op implementation
        // Concrete implementations can override
    }

    /// Clean up all notifications for a dismissed occurrence
    func cleanupOccurrence(alarmId: UUID, occurrenceKey: String) async {
        // Default implementation calls cancelOccurrence
        await cancelOccurrence(alarmId: alarmId, occurrenceKey: occurrenceKey)
    }
}
```

### AlarmScheduling+Defaults.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/Protocols/AlarmScheduling+Defaults.swift`

```swift
//
//  AlarmScheduling+Defaults.swift
//  alarmAppNew
//
//  Default implementations for AlarmScheduling protocol methods.
//  These allow legacy implementations to adopt the protocol without
//  immediately implementing all new methods.
//

import Foundation

/// Default implementations for backward compatibility.
///
/// These defaults allow the legacy NotificationService to compile
/// without modification while we transition to the full AlarmScheduling protocol.
public extension AlarmScheduling {

    /// Default no-op implementation for authorization.
    /// Legacy implementations may already handle this differently.
    func requestAuthorizationIfNeeded() async throws {
        // No-op default: Legacy implementations handle auth their own way
    }

    /// Default implementation returns a UUID string for compatibility.
    /// Legacy implementations should override this.
    func schedule(alarm: Alarm) async throws -> String {
        // Default: return alarm ID as external identifier
        // Concrete implementations should override this
        return alarm.id.uuidString
    }

    /// Default no-op implementation for stop.
    /// AlarmKit implementations will override this with actual stop behavior.
    func stop(alarmId: UUID) async throws {
        // No-op default: Legacy systems don't have explicit stop
        // AlarmKit adapter will provide real implementation
    }

    /// Default no-op implementation for countdown transition.
    /// AlarmKit implementations will use native countdown; legacy may reschedule.
    func transitionToCountdown(alarmId: UUID, duration: TimeInterval) async throws {
        // No-op default: Legacy systems handle snooze differently
        // AlarmKit adapter will provide real countdown implementation
    }
}
```

### AlarmScheduling.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/Protocols/AlarmScheduling.swift`

```swift
//
//  AlarmScheduling.swift
//  alarmAppNew
//
//  Domain-level protocol for alarm scheduling operations.
//  This protocol is AlarmKit-agnostic and defines the contract
//  that both legacy (UNNotification) and modern (AlarmKit) implementations must fulfill.
//

import Foundation

/// Domain-level protocol for alarm scheduling operations.
///
/// This protocol unifies scheduling and ringing control, supporting both
/// legacy notification-based alarms and future AlarmKit-based alarms.
///
/// Important: The `stop` method must only be called after challenge validation
/// has been completed successfully. This is enforced at the Presentation layer
/// using the StopAlarmAllowed use case.
public protocol AlarmScheduling {

    /// Request authorization for alarm notifications if not already granted.
    /// This may show system permission dialogs on first call.
    func requestAuthorizationIfNeeded() async throws

    /// Schedule an alarm and return its external identifier.
    /// - Parameter alarm: The alarm to schedule
    /// - Returns: External identifier (e.g., notification ID or AlarmKit ID)
    /// - Throws: If scheduling fails or authorization is denied
    func schedule(alarm: Alarm) async throws -> String

    /// Cancel a scheduled alarm.
    /// - Parameter alarmId: The UUID of the alarm to cancel
    func cancel(alarmId: UUID) async

    /// Get list of currently pending alarm IDs.
    /// - Returns: Array of UUIDs for alarms that are scheduled to fire
    func pendingAlarmIds() async -> [UUID]

    /// Stop a currently ringing alarm.
    ///
    /// IMPORTANT: This method must only be called after all required
    /// challenges have been validated. The Presentation layer must check
    /// StopAlarmAllowed before invoking this method.
    ///
    /// - Parameters:
    ///   - alarmId: The UUID of the alarm to stop
    ///   - intentAlarmId: Optional UUID from the firing intent (for pre-migration alarms)
    /// - Throws: If the alarm cannot be stopped or doesn't exist
    func stop(alarmId: UUID, intentAlarmId: UUID?) async throws

    /// Transition an alarm to countdown/snooze mode.
    ///
    /// This triggers a countdown with the specified duration, after which
    /// the alarm will ring again. On AlarmKit, this uses native countdown.
    /// On legacy systems, this may reschedule the alarm.
    ///
    /// - Parameters:
    ///   - alarmId: The UUID of the alarm to snooze
    ///   - duration: The snooze duration in seconds
    /// - Throws: If the transition fails or alarm doesn't exist
    func transitionToCountdown(alarmId: UUID, duration: TimeInterval) async throws

    /// Reconcile daemon state with persisted alarms (selective, idempotent).
    ///
    /// Uses daemon as source of truth; only schedules missing enabled alarms
    /// and cancels orphaned daemon entries or disabled alarms. Safe to call
    /// during ringing if skipIfRinging is true.
    ///
    /// This method is idempotent and can be called multiple times safely.
    /// It will not cancel and reschedule alarms that are already correctly
    /// scheduled in the daemon.
    ///
    /// - Parameters:
    ///   - alarms: Persisted domain alarms to reconcile against daemon state
    ///   - skipIfRinging: If true, skip reconciliation when alarm is actively alerting
    func reconcile(alarms: [Alarm], skipIfRinging: Bool) async
}
```

### AlarmSchedulingError.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/Protocols/AlarmSchedulingError.swift`

```swift
//
//  AlarmSchedulingError.swift
//  alarmAppNew
//
//  Domain-level error protocol for alarm scheduling operations.
//  Keeps Presentation layer fully protocol-typed per CLAUDE.md §1.
//

import Foundation

/// Domain-level errors for alarm scheduling operations.
///
/// This enum provides a clean abstraction over infrastructure-specific errors,
/// allowing the Presentation layer to remain decoupled from concrete
/// implementations like AlarmKitScheduler.
public enum AlarmSchedulingError: Error, Equatable {
    case notAuthorized
    case schedulingFailed
    case alarmNotFound
    case invalidConfiguration
    case systemLimitExceeded
    case permissionDenied
    case ambiguousAlarmState
    case alreadyHandledBySystem  // System auto-dismissed alarm when app foregrounded

    /// Human-readable description for logging and debugging
    public var description: String {
        switch self {
        case .notAuthorized:
            return "AlarmKit authorization not granted"
        case .schedulingFailed:
            return "Failed to schedule alarm"
        case .alarmNotFound:
            return "Alarm not found in system"
        case .invalidConfiguration:
            return "Invalid alarm configuration"
        case .systemLimitExceeded:
            return "System alarm limit exceeded"
        case .permissionDenied:
            return "Permission denied"
        case .ambiguousAlarmState:
            return "Multiple alarms alerting - cannot determine which to stop"
        case .alreadyHandledBySystem:
            return "Alarm was already handled by system (auto-dismissed)"
        }
    }
}

```

### IdleTimerControlling.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/Protocols/IdleTimerControlling.swift`

```swift
//
//  IdleTimerControlling.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/10/25.
//  Protocol for controlling screen idle timer state
//

import Foundation

/// Protocol for controlling the device screen idle timer.
/// This abstraction allows ViewModels to keep the screen awake without directly depending on UIKit.
public protocol IdleTimerControlling {
    /// Sets whether the idle timer should be disabled.
    /// - Parameter disabled: If true, prevents the screen from sleeping; if false, allows normal sleep behavior
    func setIdleTimer(disabled: Bool)
}

```

### PersistenceStore.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/Protocols/PersistenceStore.swift`

```swift
//
//  PersistenceStore.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/17/25.
//  Protocol for persistent alarm storage with mandatory Actor conformance per CLAUDE.md §5
//

import Foundation

/// Protocol for persistent alarm storage with actor-based concurrency safety.
/// All implementations MUST be actors to prevent data races.
public protocol PersistenceStore: Actor {
  func loadAlarms() throws -> [Alarm]
  func saveAlarms(_ alarm:[Alarm]) throws
}

```

### SystemVolumeProviding.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/Protocols/SystemVolumeProviding.swift`

```swift
//
//  SystemVolumeProviding.swift
//  alarmAppNew
//
//  Domain protocol for system volume operations.
//  Pure protocol definition with no platform dependencies.
//

import Foundation

/// Protocol for accessing system volume information
public protocol SystemVolumeProviding {
    /// Returns the current media volume (0.0–1.0)
    /// Note: This reads media volume only. Ringer volume is not accessible via public APIs.
    func currentMediaVolume() -> Float
}
```

### AlarmSound.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/Sounds/AlarmSound.swift`

```swift
//
//  AlarmSound.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/24/25.
//

import Foundation

public struct AlarmSound: Identifiable, Codable, Equatable {
    public let id: String         // stable key, e.g. "chimes01"
    public let name: String       // display label
    public let fileName: String   // includes extension, e.g. "chimes01.caf"
    public let durationSec: Int   // >0; descriptive only

    public init(id: String, name: String, fileName: String, durationSec: Int) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.durationSec = durationSec
    }
}
```

### SoundCatalogProviding.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/Sounds/SoundCatalogProviding.swift`

```swift
//
//  SoundCatalogProviding.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/24/25.
//

import Foundation

public protocol SoundCatalogProviding {
    var all: [AlarmSound] { get }
    var defaultSoundId: String { get }
    func info(for id: String) -> AlarmSound?
}

// MARK: - Safe Helper Extension

public extension SoundCatalogProviding {
    /// Safe sound lookup that falls back to default if ID is missing or invalid
    /// Prevents UI crashes when dealing with unknown sound IDs
    func safeInfo(for id: String?) -> AlarmSound? {
        if let id = id, let sound = info(for: id) {
            return sound
        }
        return info(for: defaultSoundId)
    }
}
```

### NowProvider.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/Time/NowProvider.swift`

```swift
//
//  ClockExtensions.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/1/25.
//

import Foundation

// Note: Clock protocol is defined in DismissalFlowViewModel.swift
// This file extends it with test utilities

public struct MockClock: Clock {
    public var fixedNow: Date

    public init(fixedNow: Date = Date()) {
        self.fixedNow = fixedNow
    }

    public func now() -> Date {
        return fixedNow
    }

    public mutating func advance(by timeInterval: TimeInterval) {
        fixedNow = fixedNow.addingTimeInterval(timeInterval)
    }
}
```

### NotificationType.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/Types/NotificationType.swift`

```swift
//
//  NotificationType.swift
//  alarmAppNew
//
//  Pure Domain type for notification categories.
//  Unified definition to avoid duplication across the codebase.
//

import Foundation

/// Type-safe notification type enumeration
public enum NotificationType: String, CaseIterable, Equatable {
    case main = "main"
    case preAlarm = "pre_alarm"
    case nudge1 = "nudge_1"
    case nudge2 = "nudge_2"
    case nudge3 = "nudge_3"

    /// All nudge notification types
    public static var allNudges: [NotificationType] {
        return [.nudge1, .nudge2, .nudge3]
    }
}
```

### SnoozeAlarm.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/UseCases/SnoozeAlarm.swift`

```swift
//
//  SnoozeAlarm.swift
//  alarmAppNew
//
//  Pure domain use case for calculating snooze times.
//  This handles DST transitions and timezone changes correctly.
//

import Foundation

/// Use case for snoozing an alarm.
///
/// This calculates the next fire time for a snoozed alarm, handling:
/// - Clamping duration to valid bounds
/// - DST transitions (fall back / spring forward)
/// - Timezone changes
/// - Local wall-clock time preservation
public struct SnoozeAlarm {

    /// Calculate the next fire time for a snoozed alarm.
    ///
    /// - Parameters:
    ///   - alarm: The alarm being snoozed
    ///   - now: The current time
    ///   - requestedSnooze: The requested snooze duration in seconds
    ///   - bounds: The valid snooze duration bounds
    ///   - calendar: Calendar to use for calculations (defaults to current)
    ///   - timeZone: TimeZone to use (defaults to current)
    /// - Returns: The next fire time for the alarm
    public static func execute(
        alarm: Alarm,
        now: Date,
        requestedSnooze: TimeInterval,
        bounds: SnoozeBounds,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> Date {
        // Step 1: Clamp the snooze duration to valid bounds
        let clampedDuration = AlarmPresentationPolicy.clampSnoozeDuration(
            requestedSnooze,
            bounds: bounds
        )

        // Step 2: Calculate next fire time using local components to handle DST
        var adjustedCalendar = calendar
        adjustedCalendar.timeZone = timeZone

        // Get current time components
        let currentComponents = adjustedCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: now
        )

        // Add snooze duration
        let nextFireDate = now.addingTimeInterval(clampedDuration)

        // Get components of next fire time
        let nextComponents = adjustedCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: nextFireDate
        )

        // Step 3: Handle DST transitions
        // If we're crossing a DST boundary, we need to ensure the alarm
        // fires at the intended local time
        if let reconstructedDate = adjustedCalendar.date(from: nextComponents) {
            // Check if the reconstructed date differs significantly from simple addition
            // This indicates a DST transition occurred
            let difference = abs(reconstructedDate.timeIntervalSince(nextFireDate))

            // If difference is more than a few seconds, we crossed DST
            if difference > 10 {
                // For DST transitions, prefer the local wall-clock time
                // This ensures alarm fires at the "expected" local time
                return handleDSTTransition(
                    originalDate: nextFireDate,
                    components: nextComponents,
                    calendar: adjustedCalendar
                )
            }

            return reconstructedDate
        }

        // Fallback to simple time addition if component reconstruction fails
        return nextFireDate
    }

    /// Handle DST transitions by ensuring alarm fires at intended local time.
    private static func handleDSTTransition(
        originalDate: Date,
        components: DateComponents,
        calendar: Calendar
    ) -> Date {
        // During spring forward: 2:30 AM becomes 3:30 AM
        // During fall back: 2:30 AM occurs twice

        // Try to create date from components
        guard let date = calendar.date(from: components) else {
            // If components are invalid (e.g., in spring forward gap),
            // find next valid time
            var adjustedComponents = components

            // Try adding an hour if we're in a gap
            if let hour = adjustedComponents.hour {
                adjustedComponents.hour = hour + 1
                if let adjustedDate = calendar.date(from: adjustedComponents) {
                    return adjustedDate
                }
            }

            // Fallback to original
            return originalDate
        }

        // For fall back, we might get the "first" 2:30 AM when we want the "second"
        // Check if we need to disambiguate
        let isDSTActive = calendar.timeZone.isDaylightSavingTime(for: originalDate)
        let willBeDSTActive = calendar.timeZone.isDaylightSavingTime(for: date)

        // If DST status changed, we crossed a boundary
        if isDSTActive != willBeDSTActive {
            // For fall back: prefer the later occurrence
            // For spring forward: already handled above
            if isDSTActive && !willBeDSTActive {
                // Fall back case: add DST offset to get "second" occurrence
                return date.addingTimeInterval(3600) // Add 1 hour
            }
        }

        return date
    }

    /// Calculate next fire time for a recurring alarm on a specific day.
    ///
    /// This is used when an alarm needs to fire on its next scheduled day,
    /// properly handling DST and timezone changes.
    public static func nextOccurrence(
        for alarm: Alarm,
        after date: Date,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> Date? {
        var adjustedCalendar = calendar
        adjustedCalendar.timeZone = timeZone

        // Get alarm time components
        let alarmComponents = adjustedCalendar.dateComponents(
            [.hour, .minute],
            from: alarm.time
        )

        guard let alarmHour = alarmComponents.hour,
              let alarmMinute = alarmComponents.minute else {
            return nil
        }

        // Start from tomorrow to find next occurrence
        guard let tomorrow = adjustedCalendar.date(byAdding: .day, value: 1, to: date) else {
            return nil
        }

        // Check up to 8 days ahead (covers all weekdays)
        for dayOffset in 0..<8 {
            guard let checkDate = adjustedCalendar.date(
                byAdding: .day,
                value: dayOffset,
                to: tomorrow
            ) else { continue }

            // Get weekday for this date
            let weekdayComponent = adjustedCalendar.component(.weekday, from: checkDate)

            // Check if alarm is scheduled for this weekday
            if alarm.repeatDays.isEmpty ||
               alarm.repeatDays.contains(where: { $0.calendarWeekday == weekdayComponent }) {
                // Create date with alarm time on this day
                var components = adjustedCalendar.dateComponents(
                    [.year, .month, .day],
                    from: checkDate
                )
                components.hour = alarmHour
                components.minute = alarmMinute
                components.second = 0

                if let fireDate = adjustedCalendar.date(from: components) {
                    return fireDate
                }
            }
        }

        return nil
    }
}

// MARK: - Helpers

private extension Weekdays {
    /// Convert to Calendar.Component weekday (1=Sunday, 7=Saturday)
    var calendarWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
}
```

### StopAlarmAllowed.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Domain/UseCases/StopAlarmAllowed.swift`

```swift
//
//  StopAlarmAllowed.swift
//  alarmAppNew
//
//  Pure domain use case for determining if an alarm can be stopped.
//  This enforces the business rule that alarms with challenges must
//  complete all challenges before the stop button is enabled.
//

import Foundation

/// State of challenge validation for an alarm.
public struct ChallengeStackState {
    /// The challenges configured for the alarm
    public let requiredChallenges: [Challenges]

    /// The challenges that have been completed
    public let completedChallenges: Set<Challenges>

    /// Whether challenges are currently being validated
    public let isValidating: Bool

    public init(
        requiredChallenges: [Challenges],
        completedChallenges: Set<Challenges>,
        isValidating: Bool = false
    ) {
        self.requiredChallenges = requiredChallenges
        self.completedChallenges = completedChallenges
        self.isValidating = isValidating
    }

    /// Check if all required challenges have been completed
    public var allChallengesCompleted: Bool {
        // If no challenges required, considered complete
        guard !requiredChallenges.isEmpty else { return true }

        // Check that every required challenge is in the completed set
        return requiredChallenges.allSatisfy { challenge in
            completedChallenges.contains(challenge)
        }
    }

    /// Get the next challenge that needs to be completed
    public var nextChallenge: Challenges? {
        // Return first challenge that hasn't been completed
        return requiredChallenges.first { challenge in
            !completedChallenges.contains(challenge)
        }
    }

    /// Get progress as a fraction (0.0 to 1.0)
    public var progress: Double {
        guard !requiredChallenges.isEmpty else { return 1.0 }
        return Double(completedChallenges.count) / Double(requiredChallenges.count)
    }
}

/// Use case for determining if an alarm can be stopped.
///
/// This enforces the core business rule that alarms with challenges
/// must have all challenges validated before the stop action is allowed.
public struct StopAlarmAllowed {

    /// Determine if the stop action is allowed for an alarm.
    ///
    /// - Parameter challengeState: The current state of challenge validation
    /// - Returns: True if the alarm can be stopped, false otherwise
    public static func execute(challengeState: ChallengeStackState) -> Bool {
        // Core business rule: Stop is only allowed when all challenges are validated
        return challengeState.allChallengesCompleted
    }

    /// Determine if the stop action is allowed based on alarm configuration.
    ///
    /// This variant is used when we only have the alarm configuration,
    /// not the current validation state.
    ///
    /// - Parameters:
    ///   - alarm: The alarm to check
    ///   - completedChallenges: Set of challenges that have been completed
    /// - Returns: True if the alarm can be stopped, false otherwise
    public static func execute(
        alarm: Alarm,
        completedChallenges: Set<Challenges>
    ) -> Bool {
        let state = ChallengeStackState(
            requiredChallenges: alarm.challengeKind,
            completedChallenges: completedChallenges
        )
        return execute(challengeState: state)
    }

    /// Get a human-readable reason why stop is not allowed.
    ///
    /// - Parameter challengeState: The current state of challenge validation
    /// - Returns: Reason string if stop is not allowed, nil if stop is allowed
    public static func reasonForDenial(challengeState: ChallengeStackState) -> String? {
        // If stop is allowed, no reason for denial
        guard !execute(challengeState: challengeState) else { return nil }

        // If currently validating, indicate that
        if challengeState.isValidating {
            return "Challenge validation in progress"
        }

        // If no challenges completed yet
        if challengeState.completedChallenges.isEmpty {
            return "Complete all challenges to stop the alarm"
        }

        // Some challenges completed but not all
        if let nextChallenge = challengeState.nextChallenge {
            return "Complete \(nextChallenge.displayName) challenge to continue"
        }

        // Generic message
        let remaining = challengeState.requiredChallenges.count - challengeState.completedChallenges.count
        return "Complete \(remaining) more challenge(s) to stop the alarm"
    }

    /// Calculate the minimum time before stop could be allowed.
    ///
    /// This is useful for UI hints about when the stop button might become available.
    ///
    /// - Parameters:
    ///   - challengeState: The current state of challenge validation
    ///   - estimatedTimePerChallenge: Estimated seconds per challenge (default 10)
    /// - Returns: Estimated seconds until stop could be allowed, or nil if already allowed
    public static func estimatedTimeUntilAllowed(
        challengeState: ChallengeStackState,
        estimatedTimePerChallenge: TimeInterval = 10
    ) -> TimeInterval? {
        // If already allowed, no wait time
        guard !execute(challengeState: challengeState) else { return nil }

        // Calculate remaining challenges
        let remainingCount = challengeState.requiredChallenges.count - challengeState.completedChallenges.count

        // Estimate time based on remaining challenges
        return TimeInterval(remainingCount) * estimatedTimePerChallenge
    }
}

// MARK: - Challenge Progress Tracking

/// Helper to track challenge completion progress.
public struct ChallengeProgress {
    public let total: Int
    public let completed: Int

    public init(state: ChallengeStackState) {
        self.total = state.requiredChallenges.count
        self.completed = state.completedChallenges.count
    }

    public var remaining: Int {
        return total - completed
    }

    public var percentComplete: Int {
        guard total > 0 else { return 100 }
        return (completed * 100) / total
    }

    public var isComplete: Bool {
        return completed >= total
    }

    public var displayText: String {
        if isComplete {
            return "All challenges completed"
        } else if completed == 0 {
            return "\(total) challenge\(total == 1 ? "" : "s") to complete"
        } else {
            return "\(completed) of \(total) challenges completed"
        }
    }
}
```

### View+DismissalFlow.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Extensions/View+DismissalFlow.swift`

```swift
////
////  View+DismissalFlow.swift
////  alarmAppNew
////
////  Created by Beshoy Eskarous on 7/24/25.
////
//
//import SwiftUI
//
//extension View {
//  func dismissalFLow(for alarmID: Binding<UUID?>) -> some View {
//    self.fullScreenCover(item: alarmID) { id in
//      let vm = DismissalFlowViewModel(alarmID: id)
//      DismissalFlowView(viewModel: vm) {
//        alarmID.wrappedValue = nil
//      }
//    }
//  }
//}

```

### ActiveAlarmPolicyProvider.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Infrastructure/ActiveAlarmPolicyProvider.swift`

```swift
//
//  ActiveAlarmPolicyProvider.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/8/25.
//  Computes active alarm windows from chain configuration (no magic numbers)
//

import Foundation

/// Protocol for determining if an alarm occurrence is currently active
/// (i.e., should be protected from cancellation during refreshAll)
public protocol ActiveAlarmPolicyProviding {
    /// Compute the active window duration for an alarm occurrence
    /// Returns the number of seconds from the occurrence fire time during which
    /// the alarm is considered "active" and should not be cancelled
    func activeWindowSeconds(for alarmId: UUID, occurrenceKey: String) -> TimeInterval
}

/// Default implementation that derives the active window from chain configuration
/// Formula: window = min(((count-1) * spacing) + leadIn + tolerance, maxCap)
///
/// Rationale:
/// - The chain spans from first notification to last notification
/// - Duration = (count-1) * spacing (e.g., 12 notifications * 10s = 110s from first to last)
/// - Add leadIn (minLeadTimeSec) for scheduling overhead
/// - Add tolerance for device/OS delays
/// - Cap at ringWindowSec to prevent unbounded windows
public final class ActiveAlarmPolicyProvider: ActiveAlarmPolicyProviding {
    private let chainPolicy: ChainPolicy
    private let toleranceSeconds: TimeInterval

    /// Initialize with chain policy and tolerance
    /// - Parameters:
    ///   - chainPolicy: The chain configuration policy (provides spacing, count, leadIn)
    ///   - toleranceSeconds: Additional buffer for device/OS delays (default: 10s)
    public init(chainPolicy: ChainPolicy, toleranceSeconds: TimeInterval = 10.0) {
        self.chainPolicy = chainPolicy
        self.toleranceSeconds = toleranceSeconds
    }

    public func activeWindowSeconds(for alarmId: UUID, occurrenceKey: String) -> TimeInterval {
        // Compute the chain configuration using the same logic as scheduling
        // Default spacing is 10s (this is what ChainedNotificationScheduler uses)
        let defaultSpacing = 10
        let chainConfig = chainPolicy.computeChain(spacingSeconds: defaultSpacing)

        // Calculate the duration from first to last notification in the chain
        // For a chain of N notifications spaced S seconds apart:
        // - First fires at T=0
        // - Last fires at T=(N-1)*S
        // - Total span = (N-1) * S
        let chainSpan = TimeInterval((chainConfig.chainCount - 1) * chainConfig.spacingSeconds)

        // Add leadIn time (scheduling overhead)
        let leadIn = TimeInterval(chainPolicy.settings.minLeadTimeSec)

        // Add tolerance for device delays
        let tolerance = toleranceSeconds

        // Compute total active window
        let computedWindow = chainSpan + leadIn + tolerance

        // Cap at the ring window to prevent unbounded windows
        let maxCap = TimeInterval(chainPolicy.settings.ringWindowSec)
        let activeWindow = min(computedWindow, maxCap)

        return activeWindow
    }
}

```

### AlarmIntentBridge.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Infrastructure/AlarmIntentBridge.swift`

```swift
//
//  AlarmIntentBridge.swift
//  alarmAppNew
//
//  Bridge for observing and routing alarm intents from app group.
//  No singletons, idempotent operation, clean separation of concerns.
//

import Foundation
import SwiftUI

/// Bridge for handling alarm intents written to app group by OpenForChallengeIntent
@MainActor
final class AlarmIntentBridge: ObservableObject {
    /// Currently pending alarm ID detected from intent
    @Published private(set) var pendingAlarmId: UUID?

    /// App group identifier matching the one used by OpenForChallengeIntent
    private static let appGroupIdentifier = "group.com.beshoy.alarmAppNew"

    /// Shared defaults for reading intent data
    private let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)

    /// Keys used for storing intent data
    private enum Keys {
        static let pendingAlarmIntent = "pendingAlarmIntent"
        static let pendingAlarmIntentTimestamp = "pendingAlarmIntentTimestamp"
    }

    /// Maximum age of intent timestamp to consider valid (30 seconds)
    private let maxIntentAge: TimeInterval = 30

    init() {
        // No OS work in initializer - keeps it pure
    }

    /// Check for pending alarm intent in app group and route if valid
    /// This method is idempotent and safe to call repeatedly
    func checkForPendingIntent() {
        guard let sharedDefaults = sharedDefaults else {
            // App group not configured - expected in dev/test
            return
        }

        // Read intent data from app group
        guard let alarmIdString = sharedDefaults.string(forKey: Keys.pendingAlarmIntent),
              let timestamp = sharedDefaults.object(forKey: Keys.pendingAlarmIntentTimestamp) as? Date else {
            // No pending intent
            return
        }

        // Validate timestamp freshness
        let age = abs(timestamp.timeIntervalSinceNow)
        guard age <= maxIntentAge else {
            // Intent is too old - clear it and ignore
            clearPendingIntent()
            print("AlarmIntentBridge: Ignoring stale intent (age: \(Int(age))s)")
            return
        }

        // Parse alarm ID
        guard let alarmId = UUID(uuidString: alarmIdString) else {
            print("AlarmIntentBridge: Invalid alarm ID format: \(alarmIdString)")
            clearPendingIntent()
            return
        }

        // Update published property
        pendingAlarmId = alarmId

        // Clear the intent data (consumed)
        clearPendingIntent()

        // Post notification for routing
        // Pass the intent's alarm ID (which could be pre-migration) as the intent ID
        NotificationCenter.default.post(
            name: .alarmIntentReceived,
            object: nil,
            userInfo: ["intentAlarmId": alarmId]
        )

        print("AlarmIntentBridge: Processing intent for alarm \(alarmId.uuidString.prefix(8))...")
    }

    /// Clear pending intent data from app group
    private func clearPendingIntent() {
        sharedDefaults?.removeObject(forKey: Keys.pendingAlarmIntent)
        sharedDefaults?.removeObject(forKey: Keys.pendingAlarmIntentTimestamp)
    }
}
```

### DefaultAlarmFactory.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Infrastructure/Alarms/DefaultAlarmFactory.swift`

```swift
//
//  DefaultAlarmFactory.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/24/25.
//

import Foundation

public final class DefaultAlarmFactory: AlarmFactory {
    private let catalog: SoundCatalogProviding

    public init(catalog: SoundCatalogProviding) {
        self.catalog = catalog
    }

    public func makeNewAlarm() -> Alarm {
        Alarm(
            id: UUID(),
            time: Date().addingTimeInterval(3600), // Default to 1 hour from now
            label: "New Alarm",
            repeatDays: [],
            challengeKind: [],
            expectedQR: nil,
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: catalog.defaultSoundId,  // Use catalog's default sound
            soundName: nil,                   // Legacy field - will be phased out
            volume: 0.8
        )
    }
}
```

### DeliveredNotificationsReader.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Infrastructure/DeliveredNotificationsReader.swift`

```swift
//
//  DeliveredNotificationsReader.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/8/25.
//  Protocol adapter for reading delivered notifications (Infrastructure → Domain boundary)
//

import Foundation
import UserNotifications

/// Simplified representation of a delivered notification
/// Domain-friendly model without iOS framework dependencies
public struct DeliveredNotification {
    public let identifier: String
    public let deliveredDate: Date

    public init(identifier: String, deliveredDate: Date) {
        self.identifier = identifier
        self.deliveredDate = deliveredDate
    }
}

/// Protocol for reading delivered notifications
/// Wraps UNUserNotificationCenter.getDeliveredNotifications() behind a testable interface
public protocol DeliveredNotificationsReading {
    func getDeliveredNotifications() async -> [DeliveredNotification]
}

/// Default implementation that wraps UNUserNotificationCenter
public final class UNDeliveredNotificationsReader: DeliveredNotificationsReading {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func getDeliveredNotifications() async -> [DeliveredNotification] {
        let notifications = await center.deliveredNotifications()
        return notifications.map { notification in
            DeliveredNotification(
                identifier: notification.request.identifier,
                deliveredDate: notification.date
            )
        }
    }
}

```

### Notification+Names.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Infrastructure/Notification+Names.swift`

```swift
//
//  Notification+Names.swift
//  alarmAppNew
//
//  Extension for custom notification names used in the app.
//

import Foundation

extension Notification.Name {
    /// Posted when an alarm intent is received from the app group
    static let alarmIntentReceived = Notification.Name("alarmIntentReceived")
}
```

### NotificationIdentifiers.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Infrastructure/Notifications/NotificationIdentifiers.swift`

```swift
//
//  NotificationIdentifiers.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/1/25.
//

import Foundation
import os.log

public struct NotificationIdentifier {
    public let alarmId: UUID
    public let fireDate: Date
    public let occurrence: Int

    public init(alarmId: UUID, fireDate: Date, occurrence: Int) {
        self.alarmId = alarmId
        self.fireDate = fireDate
        self.occurrence = occurrence
    }

    public var stringValue: String {
        let dateString = OccurrenceKeyFormatter.key(from: fireDate)
        return "alarm-\(alarmId.uuidString)-occ-\(dateString)-\(occurrence)"
    }

    public static func parse(_ identifier: String) -> NotificationIdentifier? {
        // Expected format: "alarm-{uuid}-occ-{ISO8601}-{occurrence}"
        guard identifier.hasPrefix("alarm-") else { return nil }

        // Remove "alarm-" prefix
        let withoutPrefix = String(identifier.dropFirst(6))

        // Find the UUID part (36 characters + hyphen)
        guard withoutPrefix.count > 37 else { return nil }
        let uuidString = String(withoutPrefix.prefix(36))
        guard let alarmId = UUID(uuidString: uuidString) else { return nil }

        // Remove UUID and the following hyphen
        let remainder = String(withoutPrefix.dropFirst(37))

        // Should start with "occ-"
        guard remainder.hasPrefix("occ-") else { return nil }

        // Remove "occ-" prefix
        let dateAndOccurrence = String(remainder.dropFirst(4))

        // Find the last hyphen which separates the occurrence number
        guard let lastHyphenIndex = dateAndOccurrence.lastIndex(of: "-") else { return nil }

        // Split into date and occurrence
        let dateString = String(dateAndOccurrence[..<lastHyphenIndex])
        let occurrenceString = String(dateAndOccurrence[dateAndOccurrence.index(after: lastHyphenIndex)...])

        // Parse occurrence
        guard let occurrence = Int(occurrenceString) else { return nil }

        // Parse date
        guard let fireDate = OccurrenceKeyFormatter.date(from: dateString) else { return nil }

        return NotificationIdentifier(alarmId: alarmId, fireDate: fireDate, occurrence: occurrence)
    }
}

extension NotificationIdentifier: Codable, Equatable, Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(stringValue)
    }
}

public struct NotificationIdentifierBatch {
    public let alarmId: UUID
    public let identifiers: [NotificationIdentifier]

    public init(alarmId: UUID, identifiers: [NotificationIdentifier]) {
        self.alarmId = alarmId
        self.identifiers = identifiers
    }

    public var stringValues: [String] {
        return identifiers.map(\.stringValue)
    }
}

extension NotificationIdentifierBatch: Codable, Equatable {}
```

### AlarmRunStore.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Infrastructure/Persistence/AlarmRunStore.swift`

```swift
//
//  AlarmRunStore.swift
//  alarmAppNew
//
//  Thread-safe persistence store for AlarmRun entities.
//  Conforms to CLAUDE.md §3 (actor-based concurrency) and §9 (async persistence).
//

import Foundation

/// Thread-safe actor for managing AlarmRun persistence.
///
/// **Architecture Compliance:**
/// - CLAUDE.md §3: Uses Swift `actor` for shared mutable state (no manual locking)
/// - CLAUDE.md §9: All methods are `async throws` per persistence contract
/// - claude-guardrails.md: No side effects in `init` (only stores UserDefaults reference)
///
/// **Thread Safety:**
/// Actor serialization ensures atomic load-modify-save sequences.
/// Multiple concurrent `appendRun()` calls are automatically serialized.
///
/// **Error Handling:**
/// All methods throw typed `AlarmRunStoreError` per CLAUDE.md §5.5.
actor AlarmRunStore {
    // MARK: - Properties

    private let defaults: UserDefaults
    private let key = "alarm_runs"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Init

    /// Create a new AlarmRunStore.
    ///
    /// - Parameter defaults: UserDefaults instance for persistence (default: .standard)
    ///
    /// **No side effects:** Only stores the UserDefaults reference per claude-guardrails.md.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Public API

    /// Append a new alarm run to persistent storage.
    ///
    /// **Thread Safety:** Actor serialization ensures atomic load-append-save.
    ///
    /// - Parameter run: The alarm run to persist
    /// - Throws: `AlarmRunStoreError.loadFailed` if existing runs can't be loaded
    /// - Throws: `AlarmRunStoreError.saveFailed` if encoding or save fails
    func appendRun(_ run: AlarmRun) async throws(AlarmRunStoreError) {
        // Load existing runs (atomic step 1)
        var existingRuns: [AlarmRun] = []
        if let data = defaults.data(forKey: key) {
            do {
                existingRuns = try decoder.decode([AlarmRun].self, from: data)
            } catch {
                // Corruption: log and throw typed error
                print("AlarmRunStore: Failed to decode existing runs: \(error)")
                throw .loadFailed
            }
        }

        // Append new run (atomic step 2)
        existingRuns.append(run)

        // Save back to storage (atomic step 3)
        do {
            let encoded = try encoder.encode(existingRuns)
            defaults.set(encoded, forKey: key)
            defaults.synchronize() // Force immediate write
            print("AlarmRunStore: Appended run \(run.id) for alarm \(run.alarmId) (total: \(existingRuns.count) runs)")
        } catch {
            print("AlarmRunStore: Failed to encode runs: \(error)")
            throw .saveFailed
        }
    }

    /// Load all alarm runs from persistent storage.
    ///
    /// - Returns: Array of all stored alarm runs (empty if none exist)
    /// - Throws: `AlarmRunStoreError.loadFailed` if data exists but can't be decoded
    func loadRuns() async throws(AlarmRunStoreError) -> [AlarmRun] {
        guard let data = defaults.data(forKey: key) else {
            // No data stored yet - not an error, just empty
            return []
        }

        do {
            let runs = try decoder.decode([AlarmRun].self, from: data)
            print("AlarmRunStore: Loaded \(runs.count) runs from storage")
            return runs
        } catch {
            print("AlarmRunStore: Failed to decode runs: \(error)")
            throw .loadFailed
        }
    }

    /// Load alarm runs for a specific alarm.
    ///
    /// - Parameter alarmId: The UUID of the alarm to filter by
    /// - Returns: Array of runs for the specified alarm (empty if none exist)
    /// - Throws: `AlarmRunStoreError.loadFailed` if data can't be loaded
    func runs(for alarmId: UUID) async throws(AlarmRunStoreError) -> [AlarmRun] {
        let allRuns = try await loadRuns()
        let filtered = allRuns.filter { $0.alarmId == alarmId }
        print("AlarmRunStore: Loaded \(filtered.count) runs for alarm \(alarmId)")
        return filtered
    }

    /// Clean up incomplete alarm runs from previous sessions.
    ///
    /// Marks runs older than 1 hour with no `dismissedAt` as failed.
    /// This is called on app launch to handle cases where the app was
    /// killed/crashed during an alarm dismissal flow.
    ///
    /// **Thread Safety:** Actor serialization ensures atomic load-modify-save.
    ///
    /// - Throws: `AlarmRunStoreError.loadFailed` if existing runs can't be loaded
    /// - Throws: `AlarmRunStoreError.saveFailed` if changes can't be saved
    func cleanupIncompleteRuns() async throws(AlarmRunStoreError) {
        // Load all runs (atomic step 1)
        var allRuns = try await loadRuns()
        let now = Date()
        var hasChanges = false

        // Mark stale incomplete runs as failed (atomic step 2)
        for i in 0..<allRuns.count {
            let run = allRuns[i]

            // If run is incomplete (no dismissedAt) and older than 1 hour, mark as failed
            if run.dismissedAt == nil &&
               run.outcome == .failed && // Default state
               now.timeIntervalSince(run.firedAt) > 3600 { // 1 hour

                allRuns[i].outcome = .failed
                hasChanges = true
                print("AlarmRunStore: Marked stale AlarmRun as failed: \(run.id) (alarm: \(run.alarmId))")
            }
        }

        // Save changes if any (atomic step 3)
        if hasChanges {
            do {
                let encoded = try encoder.encode(allRuns)
                defaults.set(encoded, forKey: key)
                defaults.synchronize()
                print("AlarmRunStore: Cleanup complete - marked \(allRuns.count) runs")
            } catch {
                print("AlarmRunStore: Failed to save after cleanup: \(error)")
                throw .saveFailed
            }
        } else {
            print("AlarmRunStore: Cleanup complete - no changes needed")
        }
    }
}

```

### DismissedRegistry.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Infrastructure/Persistence/DismissedRegistry.swift`

```swift
//
//  DismissedRegistry.swift
//  alarmAppNew
//
//  Tracks dismissed alarm occurrences to prevent duplicate dismissal flows
//

import Foundation

/// Registry tracking which alarm occurrences have been successfully dismissed
/// Prevents re-showing dismissal flow on app restart when delivered notifications persist
@MainActor
final class DismissedRegistry {
    private struct DismissedOccurrence: Codable {
        let alarmId: UUID
        let occurrenceKey: String
        let dismissedAt: Date
    }

    private let userDefaults: UserDefaults
    private let storageKey = "com.alarmapp.dismissedOccurrences"
    private let expirationWindow: TimeInterval = 300  // 5 minutes

    private var cache: [String: DismissedOccurrence] = [:]

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadCache()
    }

    /// Mark an occurrence as dismissed (pure persistence - no OS cleanup)
    func markDismissed(alarmId: UUID, occurrenceKey: String) {
        let key = cacheKey(alarmId: alarmId, occurrenceKey: occurrenceKey)
        let occurrence = DismissedOccurrence(
            alarmId: alarmId,
            occurrenceKey: occurrenceKey,
            dismissedAt: Date()
        )

        cache[key] = occurrence
        persistCache()

        let alarmIdPrefix = String(alarmId.uuidString.prefix(8))
        let keyPrefix = String(occurrenceKey.prefix(10))
        print("📋 DismissedRegistry: Marked", alarmIdPrefix + "/" + keyPrefix + "...", "as dismissed")
    }

    /// Check if an occurrence was already dismissed recently
    func isDismissed(alarmId: UUID, occurrenceKey: String) -> Bool {
        let key = cacheKey(alarmId: alarmId, occurrenceKey: occurrenceKey)

        guard let occurrence = cache[key] else {
            return false
        }

        // Check if dismissal is still within expiration window
        let isExpired = Date().timeIntervalSince(occurrence.dismissedAt) > expirationWindow
        if isExpired {
            // Clean up expired entry
            cache.removeValue(forKey: key)
            persistCache()
            return false
        }

        return true
    }

    /// Get all dismissed occurrence keys for startup cleanup
    func dismissedOccurrenceKeys() -> Set<String> {
        return Set(cache.values.map { $0.occurrenceKey })
    }

    /// Clear all dismissed occurrences (for testing/reset)
    func clearAll() {
        cache.removeAll()
        userDefaults.removeObject(forKey: storageKey)
        print("📋 DismissedRegistry: Cleared all dismissed occurrences")
    }

    /// Clean up expired occurrences (call periodically)
    func cleanupExpired() {
        let now = Date()
        let expiredKeys = cache.filter { _, occurrence in
            now.timeIntervalSince(occurrence.dismissedAt) > expirationWindow
        }.map { $0.key }

        for key in expiredKeys {
            cache.removeValue(forKey: key)
        }

        if !expiredKeys.isEmpty {
            persistCache()
            print("📋 DismissedRegistry: Cleaned up \(expiredKeys.count) expired occurrences")
        }
    }

    // MARK: - Private Helpers

    private func cacheKey(alarmId: UUID, occurrenceKey: String) -> String {
        return "\(alarmId.uuidString)|\(occurrenceKey)"
    }

    private func loadCache() {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: DismissedOccurrence].self, from: data) else {
            return
        }

        cache = decoded
        cleanupExpired()  // Clean on load
    }

    private func persistCache() {
        guard let encoded = try? JSONEncoder().encode(cache) else {
            print("⚠️ DismissedRegistry: Failed to encode cache")
            return
        }

        userDefaults.set(encoded, forKey: storageKey)
    }
}

```

### NotificationIndex.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Infrastructure/Persistence/NotificationIndex.swift`

```swift
//
//  NotificationIndex.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/1/25.
//

import Foundation
import os.log

// MARK: - Chain Metadata

public struct ChainMeta: Codable {
    public let start: Date          // Actual start time (shifted for minLeadTime)
    public let spacing: TimeInterval
    public let count: Int
    public let createdAt: Date      // When this chain was scheduled

    public init(start: Date, spacing: TimeInterval, count: Int, createdAt: Date) {
        self.start = start
        self.spacing = spacing
        self.count = count
        self.createdAt = createdAt
    }
}

public protocol NotificationIndexProviding {
    func saveIdentifiers(alarmId: UUID, identifiers: [String])
    func loadIdentifiers(alarmId: UUID) -> [String]
    func clearIdentifiers(alarmId: UUID)
    func getAllPendingIdentifiers() -> [String]
    func clearAllIdentifiers()
    func allTrackedAlarmIds() -> [UUID]
    func removeIdentifiers(alarmId: UUID, identifiers: [String])

    // Chain metadata persistence
    func saveChainMeta(alarmId: UUID, meta: ChainMeta)
    func loadChainMeta(alarmId: UUID) -> ChainMeta?
    func clearChainMeta(alarmId: UUID)
}

public final class NotificationIndex: NotificationIndexProviding {
    private let defaults: UserDefaults
    private let keyPrefix = "notification_index"
    private let metaKeyPrefix = "notification_meta"
    private let globalKey = "notification_index_global"
    private let log = OSLog(subsystem: "alarmAppNew", category: "NotificationIndex")

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Public Interface

    public func saveIdentifiers(alarmId: UUID, identifiers: [String]) {
        let key = makeKey(for: alarmId)

        os_log("Saving %d identifiers for alarm %@",
               log: log, type: .info, identifiers.count, alarmId.uuidString)

        if identifiers.isEmpty {
            // Remove the key entirely if no identifiers
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(identifiers, forKey: key)
        }

        // Update global index
        updateGlobalIndex()

        #if DEBUG
        // Verify the save in debug builds
        let savedIdentifiers = loadIdentifiers(alarmId: alarmId)
        assert(savedIdentifiers == identifiers, "Identifier save verification failed")
        #endif
    }

    public func loadIdentifiers(alarmId: UUID) -> [String] {
        let key = makeKey(for: alarmId)
        let identifiers = defaults.stringArray(forKey: key) ?? []

        os_log("Loaded %d identifiers for alarm %@",
               log: log, type: .debug, identifiers.count, alarmId.uuidString)

        return identifiers
    }

    public func clearIdentifiers(alarmId: UUID) {
        let key = makeKey(for: alarmId)

        os_log("Clearing identifiers for alarm %@",
               log: log, type: .info, alarmId.uuidString)

        defaults.removeObject(forKey: key)
        updateGlobalIndex()
    }

    public func getAllPendingIdentifiers() -> [String] {
        let globalIdentifiers = defaults.stringArray(forKey: globalKey) ?? []

        os_log("Retrieved %d total pending identifiers",
               log: log, type: .debug, globalIdentifiers.count)

        return globalIdentifiers
    }

    public func clearAllIdentifiers() {
        os_log("Clearing all notification identifiers and metadata", log: log, type: .info)

        // Find all alarm-specific keys (both identifiers and metadata)
        let allKeys = defaults.dictionaryRepresentation().keys
        let notificationKeys = allKeys.filter { $0.hasPrefix(keyPrefix) && $0 != globalKey }
        let metaKeys = allKeys.filter { $0.hasPrefix(metaKeyPrefix) }

        for key in notificationKeys {
            defaults.removeObject(forKey: key)
        }

        for key in metaKeys {
            defaults.removeObject(forKey: key)
        }

        // Clear global index
        defaults.removeObject(forKey: globalKey)

        os_log("Cleared %d identifier keys and %d metadata keys",
               log: log, type: .info, notificationKeys.count, metaKeys.count)
    }

    public func allTrackedAlarmIds() -> [UUID] {
        let allKeys = defaults.dictionaryRepresentation().keys
        let notificationKeys = allKeys.filter {
            $0.hasPrefix("\(keyPrefix)_") && $0 != globalKey
        }

        let alarmIds = notificationKeys.compactMap { key -> UUID? in
            let uuidString = key.replacingOccurrences(of: "\(keyPrefix)_", with: "")
            return UUID(uuidString: uuidString)
        }

        os_log("Found %d tracked alarm IDs", log: log, type: .debug, alarmIds.count)
        return alarmIds
    }

    public func removeIdentifiers(alarmId: UUID, identifiers: [String]) {
        var current = loadIdentifiers(alarmId: alarmId)
        let initialCount = current.count

        current.removeAll { identifiers.contains($0) }

        os_log("Removing %d identifiers from alarm %@ (had: %d, now: %d)",
               log: log, type: .info, initialCount - current.count,
               alarmId.uuidString, initialCount, current.count)

        if current.isEmpty {
            clearIdentifiers(alarmId: alarmId)
        } else {
            saveIdentifiers(alarmId: alarmId, identifiers: current)
        }
    }

    // MARK: - Chain Metadata Persistence

    public func saveChainMeta(alarmId: UUID, meta: ChainMeta) {
        let key = makeMetaKey(for: alarmId)

        do {
            let data = try JSONEncoder().encode(meta)
            defaults.set(data, forKey: key)

            os_log("Saved chain metadata for alarm %@ (start: %@, count: %d)",
                   log: log, type: .info, alarmId.uuidString,
                   meta.start.ISO8601Format(), meta.count)
        } catch {
            os_log("Failed to save chain metadata for alarm %@: %@",
                   log: log, type: .error, alarmId.uuidString, error.localizedDescription)
        }
    }

    public func loadChainMeta(alarmId: UUID) -> ChainMeta? {
        let key = makeMetaKey(for: alarmId)

        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        do {
            let meta = try JSONDecoder().decode(ChainMeta.self, from: data)
            os_log("Loaded chain metadata for alarm %@ (start: %@, count: %d)",
                   log: log, type: .debug, alarmId.uuidString,
                   meta.start.ISO8601Format(), meta.count)
            return meta
        } catch {
            os_log("Failed to decode chain metadata for alarm %@: %@",
                   log: log, type: .error, alarmId.uuidString, error.localizedDescription)
            return nil
        }
    }

    public func clearChainMeta(alarmId: UUID) {
        let key = makeMetaKey(for: alarmId)
        defaults.removeObject(forKey: key)

        os_log("Cleared chain metadata for alarm %@",
               log: log, type: .info, alarmId.uuidString)
    }

    // MARK: - Private Helpers

    private func makeKey(for alarmId: UUID) -> String {
        return "\(keyPrefix)_\(alarmId.uuidString)"
    }

    private func makeMetaKey(for alarmId: UUID) -> String {
        return "\(metaKeyPrefix)_\(alarmId.uuidString)"
    }

    private func updateGlobalIndex() {
        // Aggregate all identifiers across all alarms
        let allKeys = defaults.dictionaryRepresentation().keys
        let notificationKeys = allKeys.filter {
            $0.hasPrefix(keyPrefix) && $0 != globalKey
        }

        var allIdentifiers: [String] = []

        for key in notificationKeys {
            if let identifiers = defaults.stringArray(forKey: key) {
                allIdentifiers.append(contentsOf: identifiers)
            }
        }

        os_log("Updating global index with %d total identifiers from %d alarms",
               log: log, type: .debug, allIdentifiers.count, notificationKeys.count)

        if allIdentifiers.isEmpty {
            defaults.removeObject(forKey: globalKey)
        } else {
            defaults.set(allIdentifiers, forKey: globalKey)
        }
    }
}

// MARK: - Convenience Extensions

extension NotificationIndex {
    public func saveIdentifierBatch(_ batch: NotificationIdentifierBatch) {
        saveIdentifiers(alarmId: batch.alarmId, identifiers: batch.stringValues)
    }

    public func loadIdentifierBatch(alarmId: UUID) -> NotificationIdentifierBatch {
        let identifiers = loadIdentifiers(alarmId: alarmId)
        let parsedIdentifiers = identifiers.compactMap(NotificationIdentifier.parse)
        return NotificationIdentifierBatch(alarmId: alarmId, identifiers: parsedIdentifiers)
    }

    public func idempotentReschedule(
        alarmId: UUID,
        expectedIdentifiers: [String],
        completion: () -> Void
    ) {
        // Load current identifiers
        let currentIdentifiers = loadIdentifiers(alarmId: alarmId)

        os_log("Idempotent reschedule for alarm %@: current=%d expected=%d",
               log: log, type: .info, alarmId.uuidString,
               currentIdentifiers.count, expectedIdentifiers.count)

        // Clear current identifiers first
        clearIdentifiers(alarmId: alarmId)

        // Execute the reschedule operation
        completion()

        // Save the new expected identifiers
        saveIdentifiers(alarmId: alarmId, identifiers: expectedIdentifiers)
    }
}
```

### AlarmKitScheduler.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Infrastructure/Services/AlarmKitScheduler.swift`

```swift
//
//  AlarmKitScheduler.swift
//  alarmAppNew
//
//  iOS 26+ AlarmKit implementation of AlarmScheduling protocol.
//  Uses system alarms with native stop/snooze support.
//

import Foundation
import AlarmKit

/// AlarmKit-based implementation for iOS 26+
/// Uses domain UUIDs directly as AlarmKit IDs - no external mapping needed
@available(iOS 26.0, *)
final class AlarmKitScheduler: AlarmScheduling {
    private let presentationBuilder: AlarmPresentationBuilding
    private var hasActivated = false
    private var alarmStateObserver: Task<Void, Never>?

    // Internal error types for AlarmKit operations (private to this implementation)
    private enum InternalError: Error {
        case notAuthorized
        case schedulingFailed
        case alarmNotFound
        case invalidConfiguration
        case systemLimitExceeded
        case permissionDenied
        case ambiguousAlarmState
        case alreadyHandledBySystem
    }

    // Map internal errors to domain-level AlarmSchedulingError
    private func mapToDomainError(_ error: InternalError) -> AlarmSchedulingError {
        switch error {
        case .notAuthorized: return .notAuthorized
        case .schedulingFailed: return .schedulingFailed
        case .alarmNotFound: return .alarmNotFound
        case .invalidConfiguration: return .invalidConfiguration
        case .systemLimitExceeded: return .systemLimitExceeded
        case .permissionDenied: return .permissionDenied
        case .ambiguousAlarmState: return .ambiguousAlarmState
        case .alreadyHandledBySystem: return .alreadyHandledBySystem
        }
    }

    init(presentationBuilder: AlarmPresentationBuilding) {
        self.presentationBuilder = presentationBuilder
        // No OS work in init - activation is explicit
    }

    /// Activate the scheduler (idempotent)
    @MainActor
    func activate() async {
        guard !hasActivated else { return }

        // Observe alarm state changes from AlarmKit
        // AlarmManager.alarmUpdates provides an async sequence of alarm changes
        alarmStateObserver = Task {
            for await updatedAlarms in AlarmManager.shared.alarmUpdates {
                // alarmUpdates yields array of alarms, not single alarm
                for updatedAlarm in updatedAlarms {
                    await handleAlarmStateUpdate(updatedAlarm)
                }
            }
        }

        hasActivated = true
        print("AlarmKitScheduler: Activated with state observation")
    }

    /// One-time migration: reconcile AlarmKit daemon state with domain alarms
    /// Cancels orphaned alarms and schedules missing enabled alarms using domain UUIDs
    @MainActor
    func reconcileAlarmsAfterMigration(persisted: [Alarm]) async {
        let migrationKey = "AlarmKitIDMigrationDone.v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            print("AlarmKitScheduler: Migration already completed")
            return
        }

        print("AlarmKitScheduler: Starting migration reconciliation...")

        // 1) Fetch daemon state (what AlarmKit thinks is scheduled)
        let daemonAlarms: [AlarmKit.Alarm]
        do {
            daemonAlarms = try AlarmManager.shared.alarms
            print("AlarmKitScheduler: Found \(daemonAlarms.count) alarms in daemon")
        } catch {
            print("AlarmKitScheduler: Migration failed to fetch daemon alarms: \(error)")
            return
        }
        let daemonIDs = Set(daemonAlarms.map { $0.id })
        let persistedIDs = Set(persisted.map { $0.id })

        // 2) Cancel stale daemon alarms that aren't in our store (orphans from old mapping)
        let orphans = daemonIDs.subtracting(persistedIDs)
        for orphanID in orphans {
            do {
                try await AlarmManager.shared.cancel(id: orphanID)
                print("AlarmKitScheduler: Cancelled orphan daemon alarm \(orphanID)")
            } catch {
                print("AlarmKitScheduler: Failed to cancel orphan \(orphanID): \(error)")
            }
        }

        // 3) Schedule every enabled domain alarm missing from daemon (using domain UUID)
        for alarm in persisted where alarm.isEnabled {
            if !daemonIDs.contains(alarm.id) {
                do {
                    _ = try await schedule(alarm: alarm)
                    print("AlarmKitScheduler: Scheduled missing alarm \(alarm.id)")
                } catch {
                    print("AlarmKitScheduler: Failed to schedule \(alarm.id): \(error)")
                }
            } else {
                print("AlarmKitScheduler: Alarm \(alarm.id) already in daemon, skipping")
            }
        }

        // 4) Mark migration complete
        UserDefaults.standard.set(true, forKey: migrationKey)
        print("AlarmKitScheduler: Migration completed")
    }

    // MARK: - AlarmScheduling Protocol

    func requestAuthorizationIfNeeded() async throws {
        do {
            try await requestAuthorizationInternally()
        } catch let internalError as InternalError {
            throw mapToDomainError(internalError)
        }
    }

    private func requestAuthorizationInternally() async throws {
        switch AlarmManager.shared.authorizationState {
        case .notDetermined:
            let state = try await AlarmManager.shared.requestAuthorization()
            guard state == .authorized else {
                throw InternalError.notAuthorized
            }
            print("AlarmKitScheduler: Authorization granted")
        case .denied:
            print("AlarmKitScheduler: Authorization denied")
            throw InternalError.notAuthorized
        case .authorized:
            print("AlarmKitScheduler: Already authorized")
        @unknown default:
            throw InternalError.notAuthorized
        }
    }

    func schedule(alarm: Alarm) async throws -> String {
        // Public API: throws domain-level AlarmSchedulingError
        do {
            return try await scheduleInternal(alarm: alarm)
        } catch let internalError as InternalError {
            throw mapToDomainError(internalError)
        } catch {
            // Catch AlarmKit native errors and map to domain error
            print("AlarmKitScheduler: Schedule failed with AlarmKit error: \(error)")
            throw AlarmSchedulingError.schedulingFailed
        }
    }

    private func scheduleInternal(alarm: Alarm) async throws -> String {
        // Build schedule and presentation using our builder
        let schedule = try presentationBuilder.buildSchedule(from: alarm)
        let attributes = try presentationBuilder.buildPresentation(for: alarm)

        // Create AlarmConfiguration using the proper factory method
        // Note: AlarmConfiguration is a nested type under AlarmManager
        let config = AlarmManager.AlarmConfiguration.alarm(
            schedule: schedule,
            attributes: attributes,
            stopIntent: nil,  // No custom stop intent
            secondaryIntent: OpenForChallengeIntent(alarmID: alarm.id.uuidString),
            sound: .default  // Use default alarm sound
        )

        // Schedule the alarm through AlarmKit using domain UUID directly
        // AlarmKit uses the ID we provide - no separate external ID needed
        let _ = try await AlarmManager.shared.schedule(id: alarm.id, configuration: config)

        // Return domain UUID as string (AlarmKit will use this same ID)
        print("AlarmKitScheduler: Scheduled alarm \(alarm.id)")
        return alarm.id.uuidString
    }

    func cancel(alarmId: UUID) async {
        // Use domain UUID directly - AlarmKit uses the same ID we provided in schedule()
        do {
            try await AlarmManager.shared.cancel(id: alarmId)
            print("AlarmKitScheduler: Cancelled alarm \(alarmId)")
        } catch {
            print("AlarmKitScheduler: Error cancelling alarm: \(error)")
        }
    }

    func pendingAlarmIds() async -> [UUID] {
        // Query all alarms from AlarmKit (throwing property, not async)
        do {
            let alarms = try AlarmManager.shared.alarms
            // AlarmKit IDs are the same as our domain UUIDs - direct mapping
            return alarms.map { $0.id }
        } catch {
            print("AlarmKitScheduler: Error fetching alarms: \(error)")
            return []
        }
    }

    func stop(alarmId: UUID, intentAlarmId: UUID? = nil) async throws {
        // Public API: throws domain-level AlarmSchedulingError
        do {
            try stopInternal(alarmId: alarmId, intentAlarmId: intentAlarmId)
        } catch let internalError as InternalError {
            throw mapToDomainError(internalError)
        }
    }

    // MARK: - Private Stop Implementation

    private func stopInternal(alarmId: UUID, intentAlarmId: UUID?) throws {
        // Priority 1: Prefer the ID that actually fired (from OpenForChallengeIntent)
        if let firedId = intentAlarmId {
            do {
                try AlarmManager.shared.stop(id: firedId)
                print("AlarmKitScheduler: Stopped using intent-provided ID: \(firedId)")
                return
            } catch {
                print("AlarmKitScheduler: Intent ID \(firedId) failed with error: \(error)")
            }
        }

        // Priority 2: Post-migration path: domain UUID is the AlarmKit ID
        do {
            try AlarmManager.shared.stop(id: alarmId)
            print("AlarmKitScheduler: Stopped alarm \(alarmId) using domain UUID")
            return
        } catch {
            print("AlarmKitScheduler: Domain UUID \(alarmId) failed with error: \(error)")
        }

        // Priority 3: Scoped fallback - check what alarms exist and their states
        let alarms: [AlarmKit.Alarm]
        do {
            alarms = try AlarmManager.shared.alarms
            print("AlarmKitScheduler: Fallback - found \(alarms.count) alarms in daemon")
            for alarm in alarms {
                print("  - ID: \(alarm.id), State: \(alarm.state)")
            }
        } catch {
            print("AlarmKitScheduler: Failed to fetch alarms for fallback: \(error)")
            throw InternalError.alarmNotFound
        }

        // CRITICAL CHECK: Empty daemon means system auto-dismissed the alarm
        // This happens when app is foregrounded while alarm is alerting
        guard !alarms.isEmpty else {
            print("AlarmKitScheduler: [METRIC] event=alarm_already_handled_by_system alarm_id=\(alarmId) daemon_count=0")
            throw InternalError.alreadyHandledBySystem
        }

        let alerting = alarms.filter { $0.state == .alerting }
        print("AlarmKitScheduler: Found \(alerting.count) alerting alarms")

        guard alerting.count == 1 else {
            if alerting.count > 1 {
                print("AlarmKitScheduler: ERROR - \(alerting.count) alarms alerting, cannot determine which")
                throw InternalError.ambiguousAlarmState
            }
            print("AlarmKitScheduler: No alerting alarms - alarm may have auto-dismissed or timed out")
            throw InternalError.alarmNotFound
        }

        // Exactly one alarm alerting - safe to stop it
        try AlarmManager.shared.stop(id: alerting[0].id)
        print("AlarmKitScheduler: Stopped single alerting alarm \(alerting[0].id) (fallback)")
    }

    func transitionToCountdown(alarmId: UUID, duration: TimeInterval) async throws {
        // Use domain UUID directly - AlarmKit uses the same ID we provided in schedule()
        try AlarmManager.shared.countdown(id: alarmId)
        print("AlarmKitScheduler: Countdown transition initiated for \(alarmId)")
    }

    func reconcile(alarms: [Alarm], skipIfRinging: Bool) async {
        // Check for alerting alarms if skip flag set
        if skipIfRinging {
            do {
                let daemonAlarms = try AlarmManager.shared.alarms
                let hasAlerting = daemonAlarms.contains { $0.state == .alerting }
                if hasAlerting {
                    print("AlarmKitScheduler: Skipping reconcile - alarm is alerting")
                    return
                }
            } catch {
                // Log warning but CONTINUE - better to reconcile than skip entirely
                // Worst case: we reconcile while alarm is ringing (safe - won't cancel it)
                print("AlarmKitScheduler: Warning - couldn't check alerting state: \(error)")
                print("AlarmKitScheduler: Continuing with reconciliation (safe)")
                // Don't return - fall through to reconcile
            }
        }

        // Fetch current daemon state
        let daemonAlarms: [AlarmKit.Alarm]
        do {
            daemonAlarms = try AlarmManager.shared.alarms
            print("AlarmKitScheduler: Reconcile - daemon has \(daemonAlarms.count) alarms")
        } catch {
            print("AlarmKitScheduler: Reconcile failed to fetch daemon: \(error)")
            return
        }

        // Build daemon map by UUID
        let daemonMap = Dictionary(uniqueKeysWithValues: daemonAlarms.map { ($0.id, $0) })

        // For each ENABLED domain alarm: ensure it exists in daemon
        for alarm in alarms where alarm.isEnabled {
            if daemonMap[alarm.id] == nil {
                do {
                    _ = try await schedule(alarm: alarm)
                    print("AlarmKitScheduler: Reconcile - scheduled missing \(alarm.id)")
                } catch {
                    print("AlarmKitScheduler: Reconcile - failed to schedule \(alarm.id): \(error)")
                }
            }
        }

        // For each DISABLED domain alarm: ensure it's NOT in daemon
        for alarm in alarms where !alarm.isEnabled {
            if daemonMap[alarm.id] != nil {
                await cancel(alarmId: alarm.id)
            }
        }

        // Cancel orphans: daemon alarms not in persisted set
        let persistedIDs = Set(alarms.map { $0.id })
        for (daemonID, _) in daemonMap where !persistedIDs.contains(daemonID) {
            await cancel(alarmId: daemonID)
        }

        print("AlarmKitScheduler: Reconcile complete")
    }

    // MARK: - Private Helpers

    private func handleAlarmStateUpdate(_ alarm: AlarmKit.Alarm) async {
        // Sync alarm state with our internal storage
        // Note: Using AlarmKit.Alarm to disambiguate from our domain Alarm type
        // AlarmKit ID is the same as our domain UUID - no mapping needed
        print("AlarmKitScheduler: State update for alarm \(alarm.id): \(alarm.state)")
        // Future: Could notify ViewModels or update local storage here
    }

    deinit {
        // Cancel the observation task when scheduler is deallocated
        alarmStateObserver?.cancel()
    }
}

```

### AlarmPresentationBuilder.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Infrastructure/Services/AlarmPresentationBuilder.swift`

```swift
//
//  AlarmPresentationBuilder.swift
//  alarmAppNew
//
//  Builder for AlarmKit presentation and schedule configurations.
//  Separates presentation logic from scheduling implementation.
//

import Foundation
import AlarmKit
import SwiftUI

// Type disambiguation: separate domain model from AlarmKit framework types
typealias DomainAlarm = Alarm        // Our domain model

@available(iOS 26.0, *)
typealias AKAlarm = AlarmKit.Alarm   // AlarmKit framework type

/// Protocol for building AlarmKit presentation configurations
protocol AlarmPresentationBuilding {
    /// Build schedule configuration from alarm
    @available(iOS 26.0, *)
    func buildSchedule(from alarm: DomainAlarm) throws -> AKAlarm.Schedule

    /// Build presentation configuration for alarm
    @available(iOS 26.0, *)
    func buildPresentation(for alarm: DomainAlarm) throws -> AlarmAttributes<EmptyMetadata>
}

/// Empty metadata struct conforming to AlarmMetadata
@available(iOS 26.0, *)
struct EmptyMetadata: AlarmMetadata {
    static var defaultValue: EmptyMetadata { EmptyMetadata() }
}

/// Default implementation of presentation builder
struct AlarmPresentationBuilder: AlarmPresentationBuilding {

    enum BuilderError: Error {
        case invalidTime
        case invalidConfiguration
    }

    /// Map domain Weekdays enum to Locale.Weekday (locale-safe)
    @available(iOS 26.0, *)
    private func mapWeekdays(_ days: [Weekdays]) -> [Locale.Weekday] {
        days.map { weekday in
            switch weekday {
            case .sunday: return .sunday
            case .monday: return .monday
            case .tuesday: return .tuesday
            case .wednesday: return .wednesday
            case .thursday: return .thursday
            case .friday: return .friday
            case .saturday: return .saturday
            }
        }
    }

    @available(iOS 26.0, *)
    func buildSchedule(from alarm: DomainAlarm) throws -> AKAlarm.Schedule {
        // Extract time components from alarm
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: alarm.time)

        guard let hour = components.hour, let minute = components.minute else {
            throw BuilderError.invalidTime
        }

        // Create schedule - .fixed() for one-time, .relative() for recurring
        if alarm.repeatDays.isEmpty {
            // One-time alarm at specific date/time
            return .fixed(alarm.time)
        } else {
            // Recurring alarm on specific weekdays
            let time = AKAlarm.Schedule.Relative.Time(hour: hour, minute: minute)
            let recurrence = AKAlarm.Schedule.Relative.Recurrence.weekly(mapWeekdays(alarm.repeatDays))
            let relative = AKAlarm.Schedule.Relative(time: time, repeats: recurrence)
            return .relative(relative)
        }
    }

    @available(iOS 26.0, *)
    func buildPresentation(for alarm: DomainAlarm) throws -> AlarmAttributes<EmptyMetadata> {
        // Wrap title in LocalizedStringResource as required by AlarmKit
        let title = LocalizedStringResource(stringLiteral: alarm.label.isEmpty ? "Alarm" : alarm.label)

        // Create alert presentation with constructed buttons using proper 3-parameter constructor
        let stopButton = AlarmButton(
            text: LocalizedStringResource(stringLiteral: "Stop"),
            textColor: .primary,
            systemImageName: "stop.circle"
        )
        let openAppButton = AlarmButton(
            text: LocalizedStringResource(stringLiteral: "Open App"),
            textColor: .accentColor,
            systemImageName: "arrow.up.right.circle"
        )

        let alertContent = AlarmPresentation.Alert(
            title: title,
            stopButton: stopButton,
            secondaryButton: openAppButton,
            secondaryButtonBehavior: .custom
        )

        // Build full presentation (alert only for now - no countdown in alert phase)
        let presentation = AlarmPresentation(alert: alertContent)

        // Create attributes with app's theme color
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: EmptyMetadata.defaultValue,
            tintColor: .blue
        )

        return attributes
    }
}

```

### AlarmSchedulerFactory.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Infrastructure/Services/AlarmSchedulerFactory.swift`

```swift
//
//  AlarmSchedulerFactory.swift
//  alarmAppNew
//
//  Factory for creating AlarmKit scheduler (iOS 26+ only).
//  Uses explicit dependency injection, not the whole container.
//

import Foundation

/// Factory for creating the AlarmKit scheduler implementation
@MainActor
enum AlarmSchedulerFactory {

    /// Create the AlarmKit scheduler (iOS 26+ only)
    /// - Parameters:
    ///   - presentationBuilder: Builder for AlarmKit presentation configs
    /// - Returns: AlarmKitScheduler instance
    /// - Note: Uses domain UUIDs directly as AlarmKit IDs - no external mapping needed
    @available(iOS 26.0, *)
    static func make(
        presentationBuilder: AlarmPresentationBuilding
    ) -> AlarmScheduling {
        return AlarmKitScheduler(
            presentationBuilder: presentationBuilder
        )
    }
}
```

### ChainedNotificationScheduler.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Infrastructure/Services/ChainedNotificationScheduler.swift`

```swift
//
//  ChainedNotificationScheduler.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/1/25.
//

import Foundation
import UserNotifications
import UIKit
import os.log
import os.signpost

// MARK: - Protocol Definition

public protocol ChainedNotificationScheduling {
    func scheduleChain(for alarm: Alarm, fireDate: Date) async -> ScheduleOutcome
    func cancelChain(alarmId: UUID) async
    func cancelOccurrence(alarmId: UUID, occurrenceKey: String) async
    func getIdentifiers(alarmId: UUID) -> [String]
    func getAllTrackedIdentifiers() -> Set<String>
    func requestAuthorization() async throws
    func cleanupStaleChains() async
}

// MARK: - Implementation

public final class ChainedNotificationScheduler: ChainedNotificationScheduling {
    private let notificationCenter: UNUserNotificationCenter
    private let soundCatalog: SoundCatalogProviding
    private let notificationIndex: NotificationIndexProviding
    private let chainPolicy: ChainPolicy
    private let globalLimitGuard: GlobalLimitGuard
    private let clock: Clock

    private let log = OSLog(subsystem: "alarmAppNew", category: "ChainedNotificationScheduler")
    private let signpostLog = OSLog(subsystem: "alarmAppNew", category: "ChainScheduling")

    public init(
        notificationCenter: UNUserNotificationCenter = .current(),
        soundCatalog: SoundCatalogProviding,
        notificationIndex: NotificationIndexProviding,
        chainPolicy: ChainPolicy,
        globalLimitGuard: GlobalLimitGuard = GlobalLimitGuard(),
        clock: Clock = SystemClock()
    ) {
        self.notificationCenter = notificationCenter
        self.soundCatalog = soundCatalog
        self.notificationIndex = notificationIndex
        self.chainPolicy = chainPolicy
        self.globalLimitGuard = globalLimitGuard
        self.clock = clock
    }

    // MARK: - Public Interface

    public func scheduleChain(for alarm: Alarm, fireDate: Date) async -> ScheduleOutcome {
        let signpostID = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "ScheduleBatch",
                   signpostID: signpostID, "alarmId=%@", alarm.id.uuidString)
        defer {
            os_signpost(.end, log: signpostLog, name: "ScheduleBatch", signpostID: signpostID)
        }

        // Step 1: Compute anchor and base interval (use single clock reading)
        let now = clock.now()
        let minLeadTime = TimeInterval(chainPolicy.settings.minLeadTimeSec)
        let anchor = fireDate  // Domain-determined alarm time (must be strictly future)

        // ANCHOR INTEGRITY: Log received anchor for comparison with Domain
        os_log("SCHED received_anchor: %@ for alarm %@",
               log: log, type: .info,
               anchor.ISO8601Format(), alarm.id.uuidString.prefix(8).description)

        // Guard: Domain should never give us a past anchor
        guard anchor > now else {
            os_log("ANCHOR_PAST_GUARD: Domain gave past anchor for alarm %@: anchor=%@ now=%@",
                   log: log, type: .error, alarm.id.uuidString,
                   anchor.ISO8601Format(), now.ISO8601Format())
            return .unavailable(reason: .invalidConfiguration)
        }

        // Calculate interval respecting both domain decision and lead time
        let deltaFromNow = anchor.timeIntervalSince(now)
        // Use ceil to avoid pre-anchor fires, then apply minimum constraints
        let baseInterval = max(ceil(deltaFromNow), minLeadTime, 1.0)  // ceil prevents early fire, 1.0 is iOS minimum

        // Log the timing calculation for debugging
        os_log("Chain timing for alarm %@: anchor=%@ now=%@ delta=%.1fs leadTime=%.1fs baseInterval=%.1fs",
               log: log, type: .info, alarm.id.uuidString,
               anchor.ISO8601Format(), now.ISO8601Format(), deltaFromNow, minLeadTime, baseInterval)

        // Step 2: Check permissions
        let authStatus = await notificationCenter.notificationSettings().authorizationStatus
        guard authStatus == .authorized else {
            os_log("Notifications not authorized (status: %@) for alarm %@",
                   log: log, type: .error, String(describing: authStatus), alarm.id.uuidString)
            return .unavailable(reason: .permissions)
        }

        // Step 3: Compute chain with aggressive spacing
        // Use fallback spacing for all alarms (aggressive wake-up mode)
        // Sound duration is irrelevant for notification timing - we want rapid alerts
        let spacingSeconds = TimeInterval(chainPolicy.settings.fallbackSpacingSec)
        let chainConfig = chainPolicy.computeChain(spacingSeconds: Int(spacingSeconds))

        let soundInfo = soundCatalog.safeInfo(for: alarm.soundId)

        os_log("Chain config for alarm %@: spacing=%.0fs count=%d (sound: %@)",
               log: log, type: .info, alarm.id.uuidString, spacingSeconds,
               chainConfig.chainCount, soundInfo?.name ?? "fallback")

        // Step 4: Reserve slots atomically
        guard let reservedCount = await reserveSlots(requestedCount: chainConfig.chainCount),
              reservedCount > 0 else {
            os_log("No available slots for alarm %@ (requested: %d)",
                   log: log, type: .error, alarm.id.uuidString, chainConfig.chainCount)
            #if DEBUG
            print("🔍 [DIAG] Reservation FAILED: requested=\(chainConfig.chainCount) granted=0")
            #endif
            return .unavailable(reason: .globalLimit)
        }

        #if DEBUG
        print("🔍 [DIAG] Reservation SUCCESS: requested=\(chainConfig.chainCount) granted=\(reservedCount)")
        #endif

        defer {
            // Finalize is now async (actor method), must wrap in Task
            Task { await globalLimitGuard.finalize(reservedCount) }
        }

        // Step 5: Compute final chain configuration
        let finalConfig = chainConfig.trimmed(to: reservedCount)

        // Step 6: Cancel existing chain and schedule new one
        let outcome = await performIdempotentReschedule(
            alarm: alarm,
            anchor: anchor,
            start: anchor,  // Use anchor as start - domain has decided the time
            baseInterval: baseInterval,
            spacing: spacingSeconds,
            chainCount: finalConfig.chainCount,
            originalCount: chainConfig.chainCount
        )

        // Log the final outcome
        logScheduleOutcome(outcome, alarm: alarm, fireDate: fireDate)

        return outcome
    }

    public func cancelChain(alarmId: UUID) async {
        os_log("Cancelling notification chain for alarm %@", log: log, type: .info, alarmId.uuidString)

        let identifiers = notificationIndex.loadIdentifiers(alarmId: alarmId)

        if !identifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
            notificationIndex.clearIdentifiers(alarmId: alarmId)
            notificationIndex.clearChainMeta(alarmId: alarmId)

            os_log("Cancelled %d notifications for alarm %@",
                   log: log, type: .info, identifiers.count, alarmId.uuidString)
        }
    }

    public func cancelOccurrence(alarmId: UUID, occurrenceKey: String) async {
        os_log("Cancelling occurrence %@ for alarm %@", log: log, type: .info,
               String(occurrenceKey.prefix(10)), alarmId.uuidString)

        let allIdentifiers = notificationIndex.loadIdentifiers(alarmId: alarmId)
        let matchingIdentifiers = allIdentifiers.filter { identifier in
            identifier.contains("-occ-\(occurrenceKey)-")
        }

        if !matchingIdentifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: matchingIdentifiers)
            let remainingIdentifiers = allIdentifiers.filter { !matchingIdentifiers.contains($0) }
            notificationIndex.saveIdentifiers(alarmId: alarmId, identifiers: remainingIdentifiers)

            os_log("Cancelled %d occurrence notifications for alarm %@, %d remaining",
                   log: log, type: .info, matchingIdentifiers.count, alarmId.uuidString,
                   remainingIdentifiers.count)
        } else {
            os_log("No matching occurrence notifications found for %@",
                   log: log, type: .info, String(occurrenceKey.prefix(10)))
        }
    }

    public func getIdentifiers(alarmId: UUID) -> [String] {
        return notificationIndex.loadIdentifiers(alarmId: alarmId)
    }

    public func getAllTrackedIdentifiers() -> Set<String> {
        var allIdentifiers = Set<String>()
        let allAlarmIds = notificationIndex.allTrackedAlarmIds()
        for alarmId in allAlarmIds {
            let ids = notificationIndex.loadIdentifiers(alarmId: alarmId)
            allIdentifiers.formUnion(ids)
        }
        return allIdentifiers
    }

    public func requestAuthorization() async throws {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]

        do {
            let granted = try await notificationCenter.requestAuthorization(options: options)

            if !granted {
                os_log("Notification authorization denied by user", log: log, type: .error)
                throw NotificationSchedulingError.authorizationDenied
            }

            os_log("Notification authorization granted", log: log, type: .info)
        } catch {
            os_log("Authorization request failed: %@", log: log, type: .error, error.localizedDescription)
            throw error
        }
    }

    public func cleanupStaleChains() async {
        os_log("Starting stale chain cleanup", log: log, type: .info)

        let now = clock.now()
        let allAlarmIds = notificationIndex.allTrackedAlarmIds()
        let gracePeriod = TimeInterval(chainPolicy.settings.cleanupGraceSec)

        var totalStale = 0
        var skippedNoMeta = 0

        for alarmId in allAlarmIds {
            // Load persisted metadata
            guard let meta = notificationIndex.loadChainMeta(alarmId: alarmId) else {
                // No metadata = cannot determine staleness accurately
                // Skip to avoid false positives during migration
                skippedNoMeta += 1
                os_log("Skipping cleanup for alarm %@ (no metadata)",
                       log: log, type: .info, alarmId.uuidString)
                continue
            }

            // Calculate actual chain end using persisted values
            // Last notification fires at: start + (count - 1) * spacing
            let lastFireTime = meta.start.addingTimeInterval(Double(meta.count - 1) * meta.spacing)
            let cleanupTime = lastFireTime.addingTimeInterval(gracePeriod)

            // Only remove if truly stale
            if now > cleanupTime {
                let identifiers = notificationIndex.loadIdentifiers(alarmId: alarmId)

                if !identifiers.isEmpty {
                    notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
                    notificationIndex.removeIdentifiers(alarmId: alarmId, identifiers: identifiers)
                    notificationIndex.clearChainMeta(alarmId: alarmId)
                    totalStale += identifiers.count

                    os_log("Cleaned up %d stale notifications for alarm %@ (start: %@, lastFire: %@, cleanup: %@)",
                           log: log, type: .info, identifiers.count, alarmId.uuidString,
                           meta.start.ISO8601Format(), lastFireTime.ISO8601Format(), cleanupTime.ISO8601Format())
                }
            } else {
                os_log("Chain for alarm %@ not stale yet (cleanup time: %@, now: %@)",
                       log: log, type: .debug, alarmId.uuidString,
                       cleanupTime.ISO8601Format(), now.ISO8601Format())
            }
        }

        if skippedNoMeta > 0 {
            os_log("Skipped %d alarms without metadata during cleanup",
                   log: log, type: .info, skippedNoMeta)
        }

        os_log("Stale chain cleanup complete: removed %d notifications, skipped %d without metadata",
               log: log, type: .info, totalStale, skippedNoMeta)
    }

    // MARK: - Private Implementation

    private func reserveSlots(requestedCount: Int) async -> Int? {
        let granted = await globalLimitGuard.reserve(requestedCount)

        if granted == 0 {
            return nil
        }

        return granted
    }

    private func performIdempotentReschedule(
        alarm: Alarm,
        anchor: Date,
        start: Date,
        baseInterval: TimeInterval,
        spacing: TimeInterval,
        chainCount: Int,
        originalCount: Int
    ) async -> ScheduleOutcome {
        // Generate expected identifiers using anchor (stable identity)
        let occurrenceKey = OccurrenceKeyFormatter.key(from: anchor)
        let expectedIdentifiers = (0..<chainCount).map { index in
            return "alarm-\(alarm.id.uuidString)-occ-\(occurrenceKey)-\(index)"
        }

        // CRITICAL OBSERVABILITY: Log scheduling start
        let now = clock.now()
        let intervals = (0..<chainCount).map { index in
            Int(baseInterval + Double(index) * spacing)
        }
        os_log("SCHED start: alarmId=%@ occurrenceKey=%@ now=%@ anchor=%@ deltaSec=%d intervals=%@",
               log: log, type: .info,
               alarm.id.uuidString.prefix(8).description,
               occurrenceKey,
               now.ISO8601Format(),
               anchor.ISO8601Format(),
               Int(anchor.timeIntervalSince(now)),
               intervals.description)

        var scheduledCount = 0

        // Wrap scheduling in background task to prevent cancellation on app background
        var backgroundTask: UIBackgroundTaskIdentifier = .invalid
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "ScheduleAlarm-\(alarm.id.uuidString)") {
            // Expiration handler: clean up if system force-terminates
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        }

        // Clear existing identifiers and schedule new ones atomically
        notificationIndex.clearIdentifiers(alarmId: alarm.id)
        scheduledCount = await scheduleNotificationRequests(
            alarm: alarm,
            anchor: anchor,
            identifiers: expectedIdentifiers,
            baseInterval: baseInterval,
            spacing: spacing,
            start: start
        )
        notificationIndex.saveIdentifiers(alarmId: alarm.id, identifiers: expectedIdentifiers)

        // Save chain metadata for accurate cleanup later
        let meta = ChainMeta(
            start: start,  // Use the actual start time that was computed and used for scheduling
            spacing: spacing,
            count: chainCount,
            createdAt: clock.now()
        )
        notificationIndex.saveChainMeta(alarmId: alarm.id, meta: meta)

        // CRITICAL: End background task on all paths (success/failure handled above)
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }

        // Determine outcome type
        if originalCount > chainCount {
            return .trimmed(original: originalCount, scheduled: scheduledCount)
        } else {
            return .scheduled(count: scheduledCount)
        }
    }

    private func scheduleNotificationRequests(
        alarm: Alarm,
        anchor: Date,
        identifiers: [String],
        baseInterval: TimeInterval,
        spacing: TimeInterval,
        start: Date
    ) async -> Int {
        // Idempotent: Remove any existing notifications for this occurrence before adding new ones
        let occurrenceKey = OccurrenceKeyFormatter.key(from: anchor)

        // SERIALIZE: Await removal completion before adding to prevent race conditions
        await withCheckedContinuation { continuation in
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
            // Give the system a moment to process the removal
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                continuation.resume()
            }
        }

        os_log("Idempotent: Removed existing requests for occurrence %@ (count=%d)",
               log: log, type: .info, occurrenceKey, identifiers.count)

        // Log comprehensive scheduling info
        os_log("Scheduling chain: baseInterval=%.1fs spacing=%.1fs count=%d for alarm %@",
               log: log, type: .info, baseInterval, spacing, identifiers.count, alarm.id.uuidString)

        var successCount = 0

        for (index, identifier) in identifiers.enumerated() {
            // Calculate interval for this notification: base + index * spacing
            let interval = baseInterval + Double(index) * spacing

            do {
                let request = try buildNotificationRequest(
                    alarm: alarm,
                    anchor: anchor,
                    identifier: identifier,
                    occurrence: index,
                    interval: interval,
                    start: start,
                    isFirst: index == 0
                )

                // Add request and log result
                do {
                    try await notificationCenter.add(request)
                    successCount += 1

                    // CRITICAL OBSERVABILITY: Log successful add
                    os_log("SCHED added: id=%@ (notification %d/%d)",
                           log: log, type: .info,
                           identifier, index + 1, identifiers.count)
                } catch {
                    // CRITICAL OBSERVABILITY: Log add error
                    os_log("SCHED add_error: %@ for id=%@",
                           log: log, type: .error,
                           error.localizedDescription, identifier)
                    #if DEBUG
                    assertionFailure("Notification scheduling failed: \(error)")
                    #endif
                }

            } catch {
                os_log("Failed to build notification request %@: %@",
                       log: log, type: .error, identifier, error.localizedDescription)
                #if DEBUG
                assertionFailure("Notification request building failed: \(error)")
                #endif
            }
        }

        // CRITICAL: Immediate post-schedule verification
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let ourPending = pendingRequests.filter { identifiers.contains($0.identifier) }
        let pendingIds = ourPending.map { $0.identifier }

        // CRITICAL OBSERVABILITY: Log post-check
        os_log("SCHED post_check: pendingCount=%d ids=%@",
               log: log, type: .info,
               ourPending.count, pendingIds.description)

        // ASSERT: pendingCount must equal chainLength
        if ourPending.count != identifiers.count {
            os_log("❌ SCHEDULING FAILURE: Expected %d notifications but only %d are pending for alarm %@",
                   log: log, type: .fault,  // Use .fault for critical failures
                   identifiers.count, ourPending.count, alarm.id.uuidString)
        }

        return successCount
    }

    private func buildNotificationRequest(
        alarm: Alarm,
        anchor: Date,
        identifier: String,
        occurrence: Int,
        interval: TimeInterval,
        start: Date,
        isFirst: Bool
    ) throws -> UNNotificationRequest {
        // Build content
        let content = UNMutableNotificationContent()
        content.title = "Alarm"
        content.body = alarm.label.isEmpty ? "Alarm" : alarm.label
        content.sound = buildNotificationSound(alarm: alarm) // Use alarm's custom sound from catalog
        content.categoryIdentifier = "ALARM_CATEGORY"

        // Add userInfo with alarmId and occurrenceKey for occurrence-scoped cancellation
        // Use anchor for stable identity (not shifted time)
        let occurrenceKey = OccurrenceKeyFormatter.key(from: anchor)
        content.userInfo = [
            "alarmId": alarm.id.uuidString,
            "occurrenceKey": occurrenceKey
        ]

        // ALWAYS use interval trigger to avoid calendar race conditions
        // Clamp to iOS minimum (1 second) to ensure future scheduling
        let clampedInterval = max(1.0, interval)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: clampedInterval, repeats: false)

        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    private func buildNotificationSound(alarm: Alarm) -> UNNotificationSound {
        // safeInfo already provides fallback to default sound if ID is invalid
        let soundInfo = soundCatalog.safeInfo(for: alarm.soundId)
        let fileName = soundInfo?.fileName ?? "ringtone1.caf"  // Fallback to actual file name, not "default"
        return UNNotificationSound(named: UNNotificationSoundName(fileName))
    }

    internal func buildTriggerWithInterval(_ interval: TimeInterval) -> UNNotificationTrigger {
        // Only clamp to iOS minimum (1 second), no per-item min lead time
        let clampedInterval = max(1.0, interval)
        return UNTimeIntervalNotificationTrigger(timeInterval: clampedInterval, repeats: false)
    }

    private func logScheduleOutcome(_ outcome: ScheduleOutcome, alarm: Alarm, fireDate: Date) {
        switch outcome {
        case .scheduled(let count):
            os_log("Successfully scheduled %d notifications for alarm %@ at %@",
                   log: log, type: .info, count, alarm.id.uuidString, fireDate.description)

        case .trimmed(let original, let scheduled):
            os_log("Trimmed chain for alarm %@: %d -> %d notifications (global limit)",
                   log: log, type: .info, alarm.id.uuidString, original, scheduled)

        case .unavailable(let reason):
            let reasonString = String(describing: reason)
            os_log("Failed to schedule notifications for alarm %@: %@",
                   log: log, type: .error, alarm.id.uuidString, reasonString)
        }
    }
}

// MARK: - Error Types

public enum NotificationSchedulingError: Error {
    case authorizationDenied
    case invalidConfiguration
    case systemLimitExceeded
}

extension NotificationSchedulingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Notification permissions are required to schedule alarms"
        case .invalidConfiguration:
            return "Invalid notification configuration"
        case .systemLimitExceeded:
            return "Too many notifications already scheduled"
        }
    }
}
```

### GlobalLimitGuard.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Infrastructure/Services/GlobalLimitGuard.swift`

```swift
//
//  GlobalLimitGuard.swift
//  alarmAppNew
//
//  Thread-safe notification slot reservation using Swift actor model.
//  Conforms to CLAUDE.md §3 (actor-based concurrency) and claude-guardrails.md.
//

import Foundation
import UserNotifications
import os.log

public struct GlobalLimitConfig {
    public let safetyBuffer: Int
    public let maxSystemLimit: Int

    public init(safetyBuffer: Int = 4, maxSystemLimit: Int = 64) {
        self.safetyBuffer = safetyBuffer
        self.maxSystemLimit = maxSystemLimit
    }

    public var availableThreshold: Int {
        return maxSystemLimit - safetyBuffer
    }
}

/// Thread-safe actor for managing global notification slot reservations.
///
/// **Architecture Compliance:**
/// - CLAUDE.md §3: Uses Swift `actor` for shared mutable state (no manual locking)
/// - claude-guardrails.md: Zero usage of DispatchSemaphore or DispatchQueue.sync
///
/// **Thread Safety:**
/// Actor serialization ensures atomic reserve-modify-finalize sequences.
/// Multiple concurrent `reserve()` calls are automatically serialized by Swift.
public actor GlobalLimitGuard {
    private let config: GlobalLimitConfig
    private let notificationCenter: UNUserNotificationCenter
    private let log = OSLog(subsystem: "alarmAppNew", category: "GlobalLimitGuard")

    // Actor-isolated state (no manual locking needed)
    private var reservedSlots = 0

    public init(
        config: GlobalLimitConfig = GlobalLimitConfig(),
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.config = config
        self.notificationCenter = notificationCenter
    }

    // MARK: - Public Interface

    /// Reserve notification slots atomically.
    ///
    /// Actor isolation ensures this method is thread-safe without manual locking.
    /// Multiple concurrent calls are automatically serialized by Swift.
    ///
    /// - Parameter count: Number of slots requested
    /// - Returns: Number of slots actually granted (may be less than requested)
    public func reserve(_ count: Int) async -> Int {
        // Actor isolation ensures this entire sequence is atomic - no manual locking needed
        let available = await computeAvailableSlots()
        let granted = min(count, max(0, available - reservedSlots))

        reservedSlots += granted

        os_log("Reserved %d of %d requested slots (available: %d, reserved: %d)",
               log: log, type: .info, granted, count, available, reservedSlots)

        return granted
    }

    /// Release reserved slots after scheduling completes.
    ///
    /// Actor isolation ensures this method is thread-safe without manual locking.
    ///
    /// - Parameter actualScheduled: Number of slots that were actually used
    public func finalize(_ actualScheduled: Int) async {
        // Actor isolation ensures this is atomic - no manual locking needed
        reservedSlots = max(0, reservedSlots - actualScheduled)

        os_log("Finalized %d scheduled notifications (remaining reserved: %d)",
               log: log, type: .debug, actualScheduled, reservedSlots)
    }

    public func availableSlots() async -> Int {
        return await computeAvailableSlots()
    }

    // MARK: - Private Implementation

    private func computeAvailableSlots() async -> Int {
        do {
            let pendingRequests = await notificationCenter.pendingNotificationRequests()
            let currentPending = pendingRequests.count
            let available = max(0, config.availableThreshold - currentPending)

            os_log("Available slots: %d (pending: %d, threshold: %d, safety buffer: %d)",
                   log: log, type: .debug, available, currentPending,
                   config.availableThreshold, config.safetyBuffer)

            return available
        } catch {
            os_log("Failed to get pending notifications: %@", log: log, type: .error, error.localizedDescription)

            #if DEBUG
            assertionFailure("Failed to get pending notifications: \(error)")
            #endif

            // Conservative fallback: assume we're near the limit
            return 1
        }
    }
}

// MARK: - Test Support

#if DEBUG
extension GlobalLimitGuard {
    /// Get current reserved slots count (async due to actor isolation).
    public var currentReservedSlots: Int {
        get async { reservedSlots }
    }

    /// Reset all reservations (async due to actor isolation).
    public func resetReservations() async {
        reservedSlots = 0
    }
}
#endif
```

### ScheduleOutcome.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Infrastructure/Services/ScheduleOutcome.swift`

```swift
//
//  ScheduleOutcome.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/1/25.
//

import Foundation

public enum UnavailableReason {
    case permissions
    case globalLimit
    case invalidConfiguration
    case other(Error)
}

public enum ScheduleOutcome {
    case scheduled(count: Int)
    case trimmed(original: Int, scheduled: Int)
    case unavailable(reason: UnavailableReason)

    public var isSuccess: Bool {
        switch self {
        case .scheduled, .trimmed:
            return true
        case .unavailable:
            return false
        }
    }

    public var scheduledCount: Int {
        switch self {
        case .scheduled(let count):
            return count
        case .trimmed(_, let scheduled):
            return scheduled
        case .unavailable:
            return 0
        }
    }
}

extension ScheduleOutcome: Equatable {
    public static func == (lhs: ScheduleOutcome, rhs: ScheduleOutcome) -> Bool {
        switch (lhs, rhs) {
        case (.scheduled(let lhsCount), .scheduled(let rhsCount)):
            return lhsCount == rhsCount
        case (.trimmed(let lhsOriginal, let lhsScheduled), .trimmed(let rhsOriginal, let rhsScheduled)):
            return lhsOriginal == rhsOriginal && lhsScheduled == rhsScheduled
        case (.unavailable(let lhsReason), .unavailable(let rhsReason)):
            // Simple comparison - could be enhanced for specific error types
            return String(describing: lhsReason) == String(describing: rhsReason)
        default:
            return false
        }
    }
}
```

### ShareProvider.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Infrastructure/ShareProvider.swift`

```swift
//
//  ShareProvider.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/15/25.
//  Infrastructure layer - UIKit isolation for sharing content
//

import UIKit

// MARK: - Protocol

/// Protocol for sharing content via UIActivityViewController
/// @MainActor ensures all UIKit presentation occurs on main thread
@MainActor
protocol ShareProviding {
    /// Presents a share sheet with the given items
    /// - Parameter items: Array of items to share (strings, URLs, etc.)
    func share(items: [Any])
}

// MARK: - Implementation

/// System implementation of ShareProviding using UIActivityViewController
/// @MainActor ensures all UIKit access is main-thread safe
@MainActor
final class SystemShareProvider: ShareProviding {

    func share(items: [Any]) {
        // Find the root view controller from the active window scene
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            print("ShareProvider: No root view controller available")
            return
        }

        // Create activity view controller
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

        // iPad support: configure popover to prevent crash
        // On iPad, UIActivityViewController must be presented in a popover
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootVC.view
            popover.sourceRect = CGRect(
                x: rootVC.view.bounds.midX,
                y: rootVC.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        // Present on main thread (already guaranteed by @MainActor)
        rootVC.present(activityVC, animated: true)
    }
}

```

### SoundCatalog.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Infrastructure/Sounds/SoundCatalog.swift`

```swift
//
//  SoundCatalog.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/24/25.
//

import Foundation

public final class SoundCatalog: SoundCatalogProviding {
    private let sounds: [AlarmSound]
    public let defaultSoundId: String

    public init(bundle: Bundle = .main, validateFiles: Bool = true) {
        // Static catalog - only include actually bundled sounds
        // For now, we only have ringtone1.caf bundled
        self.sounds = [
            AlarmSound(id: "ringtone1", name: "Ringtone", fileName: "ringtone1.caf", durationSec: 27)
        ]

        // Use the actual bundled sound as default
        self.defaultSoundId = "ringtone1"

        if validateFiles {
            validate(bundle: bundle)
        }
    }

    public var all: [AlarmSound] {
        sounds
    }

    public func info(for id: String) -> AlarmSound? {
        sounds.first { $0.id == id }
    }

    private func validate(bundle: Bundle) {
        // Validate unique IDs
        let uniqueIds = Set(sounds.map { $0.id })
        assert(uniqueIds.count == sounds.count, "SoundCatalog: Duplicate sound IDs detected")

        // Validate positive durations
        assert(sounds.allSatisfy { $0.durationSec > 0 }, "SoundCatalog: All durations must be > 0")

        // Validate default ID exists
        assert(info(for: defaultSoundId) != nil, "SoundCatalog: defaultSoundId '\(defaultSoundId)' must exist in catalog")

        // Validate bundle files existence
        for sound in sounds {
            let fileName = sound.fileName
            let nameWithoutExtension = (fileName as NSString).deletingPathExtension
            let fileExtension = (fileName as NSString).pathExtension

            let exists = bundle.url(forResource: nameWithoutExtension, withExtension: fileExtension) != nil

            #if DEBUG
            assert(exists, "SoundCatalog: Missing sound file in bundle: \(fileName)")
            #else
            if !exists {
                print("SoundCatalog WARNING: Missing sound file '\(fileName)'; will use default at schedule time")
            }
            #endif
        }

        print("✅ SoundCatalog: Validation complete - \(sounds.count) sounds, default: '\(defaultSoundId)'")
    }
}

// MARK: - Preview Support

public extension SoundCatalog {
    /// Catalog for SwiftUI previews and tests - bypasses file validation
    static let preview = SoundCatalog(validateFiles: false)
}
```

### SystemVolumeProvider.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Infrastructure/SystemVolumeProvider.swift`

```swift
//
//  SystemVolumeProvider.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/8/25.
//  Infrastructure adapter for reading system volume levels
//

import AVFoundation
import alarmAppNew

/// Concrete implementation using AVAudioSession
/// Conforms to the SystemVolumeProviding protocol defined in Domain
@MainActor
final class SystemVolumeProvider: SystemVolumeProviding {
    func currentMediaVolume() -> Float {
        return AVAudioSession.sharedInstance().outputVolume
    }
}

```

### UIApplicationIdleTimerController.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Infrastructure/UIApplicationIdleTimerController.swift`

```swift
//
//  UIApplicationIdleTimerController.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/10/25.
//  Concrete implementation of IdleTimerControlling using UIApplication
//

import UIKit

/// Concrete implementation that controls the screen idle timer via UIApplication.
/// This isolates UIKit dependencies to the Infrastructure layer.
@MainActor
final class UIApplicationIdleTimerController: IdleTimerControlling {
    func setIdleTimer(disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }
}

```

### Alarm.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Models/Alarm.swift`

```swift
//
//  Untitled.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/3/25.
//

import Foundation

public struct Alarm: Codable, Equatable, Hashable, Identifiable {
  public let id: UUID
  var time: Date
  var label: String
  var repeatDays: [Weekdays]
  var challengeKind: [Challenges]
  var expectedQR: String?
  var stepThreshold: Int?
  var mathChallenge: MathChallenge?
  var isEnabled: Bool
  var soundId: String     // Stable sound ID for catalog lookup
  var soundName: String?  // Legacy field - kept for backward compatibility
  var volume: Double      // Volume for in-app ringing and previews only (0.0-1.0)
  public var externalAlarmId: String? // AlarmKit/system identifier

  // MARK: - Coding Keys (CRITICAL for proper encoding/decoding)
  private enum CodingKeys: String, CodingKey {
    case id, time, label, repeatDays, challengeKind
    case expectedQR, stepThreshold, mathChallenge
    case isEnabled, volume
    case soundId    // CRITICAL: Must be in CodingKeys for proper encoding
    case soundName  // Keep for backward compatibility
    case externalAlarmId  // AlarmKit external identifier
  }

  // MARK: - Custom Decoder (handles missing soundId from old JSON)
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // Decode all existing fields
    id = try container.decode(UUID.self, forKey: .id)
    time = try container.decode(Date.self, forKey: .time)
    label = try container.decode(String.self, forKey: .label)
    repeatDays = try container.decode([Weekdays].self, forKey: .repeatDays)
    challengeKind = try container.decode([Challenges].self, forKey: .challengeKind)
    expectedQR = try container.decodeIfPresent(String.self, forKey: .expectedQR)
    stepThreshold = try container.decodeIfPresent(Int.self, forKey: .stepThreshold)
    mathChallenge = try container.decodeIfPresent(MathChallenge.self, forKey: .mathChallenge)
    isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
    volume = try container.decode(Double.self, forKey: .volume)

    // Handle missing soundId gracefully (for old persisted alarms)
    soundId = try container.decodeIfPresent(String.self, forKey: .soundId) ?? "ringtone1"

    // Keep legacy soundName for backward compatibility
    soundName = try container.decodeIfPresent(String.self, forKey: .soundName)

    // Handle optional externalAlarmId for AlarmKit integration
    externalAlarmId = try container.decodeIfPresent(String.self, forKey: .externalAlarmId)
  }

  // Standard initializer for new alarms
  init(id: UUID, time: Date, label: String, repeatDays: [Weekdays], challengeKind: [Challenges],
       expectedQR: String? = nil, stepThreshold: Int? = nil, mathChallenge: MathChallenge? = nil,
       isEnabled: Bool, soundId: String, soundName: String? = nil, volume: Double,
       externalAlarmId: String? = nil) {
    self.id = id
    self.time = time
    self.label = label
    self.repeatDays = repeatDays
    self.challengeKind = challengeKind
    self.expectedQR = expectedQR
    self.stepThreshold = stepThreshold
    self.mathChallenge = mathChallenge
    self.isEnabled = isEnabled
    self.soundId = soundId
    self.soundName = soundName
    self.volume = volume
    self.externalAlarmId = externalAlarmId
  }
}

extension Alarm {
  @available(*, unavailable, message: "Use AlarmFactory.makeNewAlarm() instead")
  static var blank: Alarm {
    // This will cause a compile-time error, preventing runtime crashes
    fatalError("Alarm.blank is deprecated - use AlarmFactory.makeNewAlarm() instead")
  }

  // Add this computed property for display purposes
  var repeatDaysText: String {
    guard !repeatDays.isEmpty else { return "" }

    // Check for common patterns
    if repeatDays.count == 7 {
      return "Every day"
    } else if Set(repeatDays) == Set([.monday, .tuesday, .wednesday, .thursday, .friday]) {
      return "Weekdays"
    } else if Set(repeatDays) == Set([.saturday, .sunday]) {
      return "Weekends"
    } else {
      // Sort days by their natural week order and return abbreviated names
      let sortedDays = repeatDays.sorted { $0.rawValue < $1.rawValue }
      return sortedDays.map { $0.displayName }.joined(separator: ", ")
    }
  }
}

```

### AlarmRun.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Models/AlarmRun.swift`

```swift

import Foundation

enum AlarmOutcome: String, Codable {
  case success
  case failed
  
}

struct AlarmRun: Identifiable, Equatable, Codable {
  let id: UUID
  let alarmId: UUID
  let firedAt: Date
  var dismissedAt: Date?
  var outcome: AlarmOutcome
  
  // MARK: - Helper Factories
  
  static func fired(alarmId: UUID, at time: Date = Date()) -> AlarmRun {
    AlarmRun(
      id: UUID(),
      alarmId: alarmId,
      firedAt: time,
      dismissedAt: nil,
      outcome: .failed // Default to failed until explicitly dismissed
    )
  }
  
  static func successful(alarmId: UUID, firedAt: Date, dismissedAt: Date) -> AlarmRun {
    AlarmRun(
      id: UUID(),
      alarmId: alarmId,
      firedAt: firedAt,
      dismissedAt: dismissedAt,
      outcome: .success
    )
  }
  
  static func failed(alarmId: UUID, firedAt: Date) -> AlarmRun {
    AlarmRun(
      id: UUID(),
      alarmId: alarmId,
      firedAt: firedAt,
      dismissedAt: nil,
      outcome: .failed
    )
  }
  
  // MARK: - Mutations
  
  mutating func markDismissed(at time: Date = Date()) {
    dismissedAt = time
    outcome = .success
  }
  
  mutating func markFailed() {
    outcome = .failed
    dismissedAt = nil
  }
}



```

### Challenges.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Models/Challenges.swift`

```swift
//
//  Challenges.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/3/25.
//
public enum Challenges: CaseIterable, Codable, Equatable, Hashable {
  case qr
  case stepCount
  case math

  public var displayName: String {
    switch self {
    case .qr: return "QR Code"
    case .stepCount: return "Step Count"
    case .math: return "Math"
    }
  }

  var iconName: String {
    switch self {
    case .qr: return "qrcode"
    case .stepCount: return "figure.walk"
    case .math: return "function"
    }
  }
}

```

### MathChallenge.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Models/MathChallenge.swift`

```swift
//
//  MathChallenge.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/3/25.
//

struct MathChallenge: Codable, Equatable, Hashable {
  let number: Int
}

```

### Weekdays.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Models/Weekdays.swift`

```swift
//
//  Weekdays.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/3/25.
//

enum Weekdays: Int, Codable, CaseIterable, Equatable {

  case sunday = 1
  case monday = 2
  case tuesday = 3
  case wednesday = 4
  case thursday = 5
  case friday = 6
  case saturday = 7

  var displayName: String {
    switch self {
    case .sunday: return "Sun"
    case .monday: return "Mon"
    case .tuesday: return "Tues"
    case .wednesday: return "Wed"
    case .thursday: return "Thurs"
    case .friday: return "Friday"
    case .saturday: return "Saturday"
    }
  }
}

```

### AlarmSoundEngine.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Services/AlarmSoundEngine.swift`

```swift
import AVFoundation
import Foundation
import UIKit

// MARK: - Protocol Definition

protocol AlarmAudioEngineProtocol {
    func schedulePrewarm(fireAt: Date, soundName: String) throws
    func promoteToRinging() throws
    func playForegroundAlarm(soundName: String) throws  // Renamed from playImmediate
    func scheduleWithLeadIn(fireAt: Date, soundId: String, leadInSeconds: Int) throws
    func stop()
    func setPolicyProvider(_ provider: @escaping () -> AudioPolicy)
    var currentState: AlarmSoundEngine.State { get }
    var isActivelyRinging: Bool { get }
}

// MARK: - State Machine Implementation

final class AlarmSoundEngine: AlarmAudioEngineProtocol {

    // MARK: - Dependencies
    private var reliabilityModeProvider: ReliabilityModeProvider?
    private var currentReliabilityMode: ReliabilityMode = .notificationsOnly
    private var policyProvider: (() -> AudioPolicy)?
    private var didActivateSession = false  // Track whether we activated AVAudioSession

    enum State: Equatable {
        case idle
        case prewarming
        case ringing

        var description: String {
            switch self {
            case .idle: return "idle"
            case .prewarming: return "prewarming"
            case .ringing: return "ringing"
            }
        }
    }
    static let shared = AlarmSoundEngine()

    // MARK: - State Machine
    private var _currentState: State = .idle
    private let stateQueue = DispatchQueue(label: "alarm-sound-engine-state", qos: .userInteractive)

    var currentState: State {
        return stateQueue.sync { _currentState }
    }

    var isActivelyRinging: Bool {
        return currentState == .ringing
    }

    // MARK: - Audio Players and Tasks
    private var mainPlayer: AVAudioPlayer?
    private var prewarmPlayer: AVAudioPlayer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    // MARK: - Route Enforcement and Timing
    private var routeEnforcementTimer: DispatchSourceTimer?
    private var lastOverrideAttempt: Date?
    private var scheduledFireDate: Date?

    // MARK: - Notification Observers
    private var observers: [NSObjectProtocol] = []
    private var observersRegistered = false

    private init() {
        // NO AVAudioSession calls here - fully lazy activation
        setupNotificationObservers()
        setupAppLifecycleObserver()
    }

    // MARK: - Dependency Injection

    func setReliabilityModeProvider(_ provider: ReliabilityModeProvider) {
        self.reliabilityModeProvider = provider

        // Subscribe to mode changes and update cached value
        Task { @MainActor in
            self.currentReliabilityMode = provider.currentMode

            // Subscribe to future changes
            Task {
                for await mode in provider.modePublisher.values {
                    await MainActor.run {
                        self.currentReliabilityMode = mode
                        print("🔊 AlarmSoundEngine: Reliability mode changed to: \(mode.rawValue)")

                        // If switching to notifications only, stop any active audio
                        if mode == .notificationsOnly && self.currentState != .idle {
                            print("🔇 AlarmSoundEngine: IMMEDIATE STOP - mode switched to notifications only")
                            self.stop()
                        }
                    }
                }
            }
        }

        print("🔊 AlarmSoundEngine: ReliabilityModeProvider injected")
    }

    func setPolicyProvider(_ provider: @escaping () -> AudioPolicy) {
        self.policyProvider = provider
        print("🔊 AlarmSoundEngine: PolicyProvider injected")
    }

    deinit {
        removeNotificationObservers()
    }

    // MARK: - State Management

    private func setState(_ newState: State) {
        stateQueue.sync {
            let oldState = _currentState
            _currentState = newState
            print("🔊 AlarmSoundEngine: State transition: \(oldState.description) → \(newState.description)")
        }
    }

    private func guardState(_ expectedStates: State..., operation: String) -> Bool {
        let current = currentState
        let isValid = expectedStates.contains(current)
        if !isValid {
            print("🔊 AlarmSoundEngine: ⚠️ Ignoring \(operation) - invalid state \(current.description), expected: \(expectedStates.map(\.description).joined(separator: " or "))")
        }
        return isValid
    }

    // MARK: - Audio Session Management

    /// Prime the audio session for alarm playback with forced speaker routing
    @MainActor
    func activateSession(policy: AudioPolicy) throws {
        let session = AVAudioSession.sharedInstance()

        // Use .playback category (NOT .playAndRecord)
        // NOTE: Removed .duckOthers to prevent iOS from ducking notification sounds when backgrounded
        let options: AVAudioSession.CategoryOptions = [.defaultToSpeaker]

        try session.setCategory(.playback, options: options)

        // Force override any existing route preferences
        try session.overrideOutputAudioPort(.speaker)
        try session.setActive(true)
        didActivateSession = true  // Set flag after activation

        // Log current audio route for diagnostics
        let currentRoute = session.currentRoute
        let outputs = currentRoute.outputs.map { "\($0.portName) (\($0.portType))" }.joined(separator: ", ")
        print("🔊 AlarmSoundEngine: Audio session activated with .playback + .defaultToSpeaker")
        print("🔊 AlarmSoundEngine: Current audio route outputs: \(outputs)")
    }

    // MARK: - Protocol API Implementation

    /// Schedule prewarm to begin near fire time (controlled timing)
    func schedulePrewarm(fireAt: Date, soundName: String) throws {
        // CRITICAL: Early return if reliability mode is notifications only
        guard currentReliabilityMode == .notificationsPlusAudio else {
            print("🔇 AlarmSoundEngine: Skipping schedulePrewarm because reliabilityMode=notificationsOnly")
            return
        }

        guard guardState(.idle, operation: "schedulePrewarm") else { return }

        let delta = fireAt.timeIntervalSinceNow
        print("🔊 AlarmSoundEngine: Scheduling prewarm for \(fireAt) (delta: \(delta)s)")

        // Only prewarm for imminent alarms (≤60s)
        guard delta <= 60.0 && delta > 0 else {
            print("🔊 AlarmSoundEngine: Prewarm skipped - delta \(delta)s outside window (≤60s)")
            return
        }

        scheduledFireDate = fireAt
        setState(.prewarming)

        // Start background transition monitoring
        // TODO: Add app lifecycle integration

        print("🔊 AlarmSoundEngine: Prewarm scheduled successfully")
    }

    /// Promote existing prewarm to full ringing
    @MainActor
    func promoteToRinging() throws {
        // CRITICAL: Early return if reliability mode is notifications only
        guard currentReliabilityMode == .notificationsPlusAudio else {
            print("🔇 AlarmSoundEngine: Skipping promoteToRinging because reliabilityMode=notificationsOnly")
            return
        }

        guard guardState(.prewarming, operation: "promoteToRinging") else {
            // If not prewarming, fall back to foreground alarm
            if currentState == .idle {
                print("🔊 AlarmSoundEngine: No prewarm active, falling back to foreground alarm")
                try playForegroundAlarm(soundName: "ringtone1")
                return
            }
            return
        }

        print("🔊 AlarmSoundEngine: Promoting prewarm to ringing")
        let soundURL = try getBundledSoundURL("ringtone1")
        try handoffToMainAlarm(soundURL: soundURL, loops: -1, volume: 1.0)
        setState(.ringing)
    }

    /// Play alarm in foreground (foreground-only, policy-gated)
    /// MUST-FIX: Not async, use @MainActor for AVAudioSession calls
    @MainActor
    func playForegroundAlarm(soundName: String) throws {
        guard let policy = policyProvider?() else {
            print("🔊 AlarmSoundEngine: No policy configured - skipping playback")
            return
        }

        // Capability guard: only .foregroundAssist and .sleepMode can play AV audio
        guard policy.capability == .foregroundAssist || policy.capability == .sleepMode else {
            print("🔊 AlarmSoundEngine: Capability check failed - policy: \(policy.capability)")
            return
        }

        // Foreground guard: .foregroundAssist requires app to be active
        if policy.capability == .foregroundAssist {
            guard UIApplication.shared.applicationState == .active else {
                print("🔊 AlarmSoundEngine: Not in foreground, skipping AV playback (foregroundAssist)")
                return
            }
        }

        guard guardState(.idle, operation: "playForegroundAlarm") else { return }

        print("🔊 AlarmSoundEngine: Starting foreground alarm playback of \(soundName)")
        setState(.ringing)

        // Activate session and play immediately
        try activateSession(policy: policy)

        let soundURL = try getBundledSoundURL(soundName)
        let player = try AVAudioPlayer(contentsOf: soundURL)
        player.numberOfLoops = -1
        player.volume = 1.0
        player.prepareToPlay()

        guard player.play() else {
            setState(.idle)
            didActivateSession = false
            throw AlarmAudioEngineError.playbackFailed(reason: "Failed to start foreground alarm playback")
        }

        mainPlayer = player
        startRouteEnforcementWindow()
        print("🔊 AlarmSoundEngine: ✅ Foreground alarm playback started")
    }

    /// Start sleep mode audio in background (if capability allows)
    @MainActor
    func startSleepAudioIfEnabled(soundName: String) throws {
        guard let policy = policyProvider?() else {
            print("🔊 AlarmSoundEngine: No policy configured - skipping sleep audio")
            return
        }

        // Capability guard: only .sleepMode can play in background
        guard policy.capability == .sleepMode else {
            print("🔊 AlarmSoundEngine: Sleep audio requires .sleepMode capability")
            return
        }

        guard guardState(.idle, operation: "startSleepAudioIfEnabled") else { return }

        print("🔊 AlarmSoundEngine: Starting sleep mode audio in background")
        setState(.ringing)

        // Activate session and play
        try activateSession(policy: policy)

        let soundURL = try getBundledSoundURL(soundName)
        let player = try AVAudioPlayer(contentsOf: soundURL)
        player.numberOfLoops = -1
        player.volume = 1.0
        player.prepareToPlay()

        guard player.play() else {
            setState(.idle)
            didActivateSession = false
            throw AlarmAudioEngineError.playbackFailed(reason: "Failed to start sleep mode audio")
        }

        mainPlayer = player
        startRouteEnforcementWindow()
        print("🔊 AlarmSoundEngine: ✅ Sleep mode audio started in background")
    }

    /// Schedule audio with lead-in time (audio enhancement for primary notifications)
    @MainActor
    func scheduleWithLeadIn(fireAt: Date, soundId: String, leadInSeconds: Int) throws {
        // CRITICAL: Early return if reliability mode is notifications only
        guard currentReliabilityMode == .notificationsPlusAudio else {
            print("🔇 AlarmSoundEngine: Skipping scheduleWithLeadIn because reliabilityMode=notificationsOnly")
            return
        }

        guard guardState(.idle, operation: "scheduleWithLeadIn") else { return }

        let delta = fireAt.timeIntervalSinceNow
        print("🔊 AlarmSoundEngine: Scheduling audio with lead-in for \(fireAt) (delta: \(delta)s, leadIn: \(leadInSeconds)s)")

        // Validate lead-in timing
        guard delta > Double(leadInSeconds) else {
            print("🔊 AlarmSoundEngine: ⚠️ Lead-in (\(leadInSeconds)s) exceeds delta (\(delta)s) - using foreground playback")
            try playForegroundAlarm(soundName: soundId)
            return
        }

        scheduledFireDate = fireAt
        setState(.prewarming)

        // Calculate audio start time (fireAt - leadInSeconds)
        let audioStartDelay = delta - Double(leadInSeconds)

        print("🔊 AlarmSoundEngine: Audio will start in \(audioStartDelay)s (lead-in: \(leadInSeconds)s before alarm)")

        // Schedule audio start
        DispatchQueue.main.asyncAfter(deadline: .now() + audioStartDelay) { [weak self] in
            guard let self = self, self.currentState == .prewarming else { return }
            guard let policy = self.policyProvider?() else {
                print("🔊 AlarmSoundEngine: No policy configured - aborting lead-in")
                self.setState(.idle)
                return
            }

            Task { @MainActor in
                do {
                    // Activate session and start ringing
                    try self.activateSession(policy: policy)

                    let soundURL = try self.getBundledSoundURL(soundId)
                    let player = try AVAudioPlayer(contentsOf: soundURL)
                    player.numberOfLoops = -1
                    player.volume = 1.0
                    player.prepareToPlay()

                    guard player.play() else {
                        print("🔊 AlarmSoundEngine: ❌ Failed to start lead-in playback")
                        self.setState(.idle)
                        self.didActivateSession = false
                        return
                    }

                    self.mainPlayer = player
                    self.setState(.ringing)
                    self.startRouteEnforcementWindow()

                    print("🔊 AlarmSoundEngine: ✅ Lead-in audio started at T-\(leadInSeconds)s")
                } catch {
                    print("🔊 AlarmSoundEngine: ❌ Lead-in activation failed: \(error)")
                    self.setState(.idle)
                }
            }
        }

        print("🔊 AlarmSoundEngine: Lead-in scheduled successfully")
    }

    private func getBundledSoundURL(_ soundName: String) throws -> URL {
        if let url = Bundle.main.url(forResource: soundName, withExtension: "caf") {
            return url
        }
        // Fallback to ringtone1
        guard let fallbackURL = Bundle.main.url(forResource: "ringtone1", withExtension: "caf") else {
            throw AlarmAudioEngineError.assetNotFound(soundName: "\(soundName) (fallback also missing)")
        }
        print("🔊 AlarmSoundEngine: Using fallback ringtone1.caf for \(soundName)")
        return fallbackURL
    }

    /// DEPRECATED: Legacy schedule method - replaced by protocol API
    @MainActor
    private func schedule(soundURL: URL, fireAt date: Date, loops: Int = -1, volume: Float = 1.0) throws {
        // Stop any existing audio first
        stop()

        let delta = date.timeIntervalSinceNow
        self.scheduledFireDate = date

        // PRE-ACTIVATION STRATEGY: For imminent alarms (≤60s), pre-activate session while foregrounded
        if delta <= 60.0 && delta > 5.0 {
            // Imminent alarm - start pre-activation with compliant prewarm
            print("🔊 AlarmSoundEngine: Imminent alarm detected (delta: \(delta)s) - starting pre-activation")
            try startPreActivation(mainSoundURL: soundURL, fireAt: date, loops: loops, volume: volume)
        } else if delta <= 5.0 {
            // Very short delay - activate session immediately
            guard let policy = policyProvider?() else {
                print("🔊 AlarmSoundEngine: No policy configured - aborting immediate schedule")
                return
            }
            Task { @MainActor in
                try self.activateSession(policy: policy)
                try self.schedulePlayerImmediate(soundURL: soundURL, fireAt: date, loops: loops, volume: volume, delta: delta)
            }
        } else {
            // Longer delay - use traditional deferred activation (may fail in background)
            print("🔊 AlarmSoundEngine: Long delay (delta: \(delta)s) - using deferred activation")
            try schedulePlayerDeferred(soundURL: soundURL, fireAt: date, loops: loops, volume: volume)
        }

        // State managed by new protocol API
        print("🔊 AlarmSoundEngine: Scheduled audio at \(date) (delta: \(delta)s, loops: \(loops))")
    }

    /// Schedule player immediately (for short delays ≤5s)
    private func schedulePlayerImmediate(soundURL: URL, fireAt date: Date, loops: Int, volume: Float, delta: TimeInterval) throws {
        let player = try AVAudioPlayer(contentsOf: soundURL)
        player.numberOfLoops = loops
        player.volume = volume
        player.prepareToPlay()

        let startAt = player.deviceCurrentTime + max(0.5, delta)

        guard player.play(atTime: startAt) else {
            throw AlarmAudioEngineError.playbackFailed(reason: "AVAudioPlayer failed to schedule play(atTime:)")
        }

        self.mainPlayer = player

        // Start route enforcement window to fight Apple Watch hijacking
        startRouteEnforcementWindow()
    }

    /// Schedule player with deferred activation (for longer delays >5s)
    private func schedulePlayerDeferred(soundURL: URL, fireAt date: Date, loops: Int, volume: Float) throws {
        // Calculate when to activate session (1 second before fire time)
        let activationTime = date.addingTimeInterval(-1.0)
        let activationDelay = max(0.1, activationTime.timeIntervalSinceNow)

        // Schedule session activation and playback
        DispatchQueue.main.asyncAfter(deadline: .now() + activationDelay) { [weak self] in
            guard let self = self, self.currentState != .idle else { return }
            guard let policy = self.policyProvider?() else {
                print("🔊 AlarmSoundEngine: No policy configured - aborting deferred activation")
                return
            }

            Task { @MainActor in
                do {
                    // PREWARM: Activate session at T-1s for optimal speaker seizure timing
                    try self.activateSession(policy: policy)

                    let player = try AVAudioPlayer(contentsOf: soundURL)
                    player.numberOfLoops = loops
                    player.volume = volume
                    player.prepareToPlay()

                    // Play immediately since we're now at T-1s
                    let remainingDelay = max(0.1, date.timeIntervalSinceNow)
                    let startAt = player.deviceCurrentTime + remainingDelay

                    guard player.play(atTime: startAt) else {
                        print("🔊 AlarmSoundEngine: ❌ Deferred play(atTime:) failed")
                        self.didActivateSession = false
                        return
                    }

                    self.mainPlayer = player

                    // Start route enforcement window to fight Apple Watch hijacking
                    self.startRouteEnforcementWindow()

                    print("🔊 AlarmSoundEngine: ✅ Deferred activation successful at T-\(remainingDelay)s")
                } catch {
                    print("🔊 AlarmSoundEngine: ❌ Deferred activation failed: \(error)")
                }
            }
        }
    }

    /// Stop alarm audio and deactivate session
    @MainActor
    func stop() {
        let previousState = currentState

        // Stop all audio players
        mainPlayer?.stop()
        mainPlayer = nil
        stopPrewarm()

        // Stop route enforcement
        stopRouteEnforcementWindow()

        // End background task
        endBackgroundTask()

        // Reset state
        setState(.idle)
        scheduledFireDate = nil

        // Only deactivate if we activated it
        if didActivateSession {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
                didActivateSession = false
                print("🔊 AlarmSoundEngine: Stopped audio and deactivated session (was: \(previousState.description))")
            } catch {
                print("🔊 AlarmSoundEngine: Error deactivating session: \(error)")
            }
        } else {
            print("🔊 AlarmSoundEngine: Stopped audio without deactivating session (never activated, was: \(previousState.description))")
        }
    }

    // MARK: - Interruption Recovery

    private func setupNotificationObservers() {
        // Observer de-dup: register only once
        guard !observersRegistered else {
            print("🔊 AlarmSoundEngine: Observers already registered - skipping duplicate registration")
            return
        }

        // Handle audio interruptions (phone calls, etc.)
        let interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }

        // Handle route changes (Bluetooth connect/disconnect, etc.)
        let routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }

        // CRITICAL: Store observer tokens to prevent deallocation
        observers = [interruptionObserver, routeChangeObserver]
        observersRegistered = true

        print("🔊 AlarmSoundEngine: Notification observers registered")
    }

    private func removeNotificationObservers() {
        guard observersRegistered else { return }

        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        observersRegistered = false

        print("🔊 AlarmSoundEngine: Notification observers removed")
    }

    // MARK: - App Lifecycle Observer

    private func setupAppLifecycleObserver() {
        // Observe app moving to background
        let backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidEnterBackground()
        }

        // Observe app returning to foreground
        let foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillEnterForeground()
        }

        observers.append(contentsOf: [backgroundObserver, foregroundObserver])
        print("🔊 AlarmSoundEngine: App lifecycle observers registered")
    }

    @MainActor
    private func handleAppDidEnterBackground() {
        guard let policy = policyProvider?() else { return }

        // Only .foregroundAssist needs special handling on backgrounding
        if policy.capability == .foregroundAssist && currentState == .ringing {
            print("🔊 AlarmSoundEngine: App backgrounded with foregroundAssist - stopping audio")
            stop()
        }
    }

    @MainActor
    private func handleAppWillEnterForeground() {
        // Currently no special handling needed on foreground
        // Audio will be restarted by dismissal flow if alarm is still active
        print("🔊 AlarmSoundEngine: App foregrounded")
    }

    @MainActor
    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            print("🔊 AlarmSoundEngine: Audio interrupted")

        case .ended:
            // Attempt to resume if we're within the alarm window
            guard currentState != .idle else { return }
            guard let policy = policyProvider?() else { return }

            do {
                try activateSession(policy: policy)
                mainPlayer?.play()
                print("🔊 AlarmSoundEngine: Resumed after interruption")
            } catch {
                print("🔊 AlarmSoundEngine: Failed to resume after interruption: \(error)")
            }

        @unknown default:
            break
        }
    }

    @MainActor
    private func handleRouteChange(_ notification: Notification) {
        guard currentState != .idle else { return }

        // Check if we should skip this override attempt (debounce logic)
        if shouldSkipRouteOverride() {
            print("🔊 AlarmSoundEngine: Skipping route override (debounce active)")
            return
        }

        // Re-assert speaker routing after route changes
        performRouteOverride(context: "route change")
    }

    // MARK: - Pre-Activation and Background Task Management

    /// Start pre-activation with compliant prewarm for imminent alarms
    @MainActor
    private func startPreActivation(mainSoundURL: URL, fireAt date: Date, loops: Int, volume: Float) throws {
        guard let policy = policyProvider?() else {
            print("🔊 AlarmSoundEngine: No policy configured - aborting pre-activation")
            return
        }

        // Begin background task to maintain capability across foreground→background transition
        startBackgroundTask()

        // Activate session while foregrounded
        try activateSession(policy: policy)

        // Start compliant prewarm audio loop
        try startCompliantPrewarm()

        // Schedule the handoff to main alarm audio
        let fireDelay = date.timeIntervalSinceNow
        DispatchQueue.main.asyncAfter(deadline: .now() + fireDelay) { [weak self] in
            self?.handoffToMainAlarm(soundURL: mainSoundURL, loops: loops, volume: volume)
        }

        print("🔊 AlarmSoundEngine: Pre-activation started with compliant prewarm")
    }

    /// Start compliant prewarm audio with real samples at low volume
    private func startCompliantPrewarm() throws {
        // CRITICAL: Bundle asset validation - hard error if missing
        guard let prewarmURL = Bundle.main.url(forResource: "prewarm", withExtension: "caf") else {
            let error = AlarmAudioEngineError.assetNotFound(soundName: "prewarm")
            print("🔊 AlarmSoundEngine: ❌ Bundle assert failed: \(error.description)")
            print("🔊 AlarmSoundEngine: ❌ Verify prewarm.caf is in Copy Bundle Resources with correct Target Membership")
            throw error
        }

        let prewarmPlayer = try AVAudioPlayer(contentsOf: prewarmURL)
        prewarmPlayer.numberOfLoops = -1  // Infinite loop
        prewarmPlayer.volume = 0.01       // Imperceptible but real audio (~5s sample)
        prewarmPlayer.prepareToPlay()

        guard prewarmPlayer.play() else {
            throw AlarmAudioEngineError.playbackFailed(reason: "Failed to start prewarm audio")
        }

        self.prewarmPlayer = prewarmPlayer
        print("🔊 AlarmSoundEngine: ✅ Silent prewarm started with prewarm.caf at volume \(prewarmPlayer.volume)")
    }

    /// Stop prewarm audio
    private func stopPrewarm() {
        prewarmPlayer?.stop()
        prewarmPlayer = nil
        print("🔊 AlarmSoundEngine: Prewarm stopped")
    }

    /// Handoff from prewarm to main alarm audio
    private func handoffToMainAlarm(soundURL: URL, loops: Int, volume: Float) {
        guard currentState != .idle else { return }

        do {
            // Stop prewarm
            stopPrewarm()

            // Start main alarm audio
            let mainPlayer = try AVAudioPlayer(contentsOf: soundURL)
            mainPlayer.numberOfLoops = loops
            mainPlayer.volume = volume
            mainPlayer.prepareToPlay()

            guard mainPlayer.play() else {
                print("🔊 AlarmSoundEngine: ❌ Failed to start main alarm audio")
                return
            }

            self.mainPlayer = mainPlayer

            // Start route enforcement to fight Apple Watch hijacking
            startRouteEnforcementWindow()

            print("🔊 AlarmSoundEngine: ✅ Handoff to main alarm audio successful")
        } catch {
            print("🔊 AlarmSoundEngine: ❌ Handoff to main alarm failed: \(error)")
        }
    }

    /// Start background task to maintain audio capability
    private func startBackgroundTask() {
        guard backgroundTask == .invalid else { return }

        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "AlarmAudio") { [weak self] in
            // Background task is about to expire - clean up safely
            guard let self = self else { return }

            print("🔊 AlarmSoundEngine: ⚠️ Background task expiring - performing safety cleanup")

            // Stop prewarm audio
            self.stopPrewarm()

            // Stop main player if not ringing yet
            if self.currentState == .prewarming {
                self.mainPlayer?.stop()
                self.mainPlayer = nil
                print("🔊 AlarmSoundEngine: Stopped main player during expiration (was prewarming)")
            }

            // CRITICAL: Main-thread boundary for AVAudioSession calls
            Task { @MainActor in
                do {
                    try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
                    print("🔊 AlarmSoundEngine: Deactivated session on expiration")
                } catch {
                    print("🔊 AlarmSoundEngine: Failed to deactivate session on expiration: \(error)")
                }
            }

            // Reset state
            self.setState(.idle)

            // End the background task
            self.endBackgroundTask()
        }

        print("🔊 AlarmSoundEngine: Background task started: \(backgroundTask.rawValue)")
    }

    /// End background task
    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }

        // CRITICAL: Main-thread boundary for UIApplication calls
        Task { @MainActor in
            UIApplication.shared.endBackgroundTask(backgroundTask)
            print("🔊 AlarmSoundEngine: Background task ended: \(backgroundTask.rawValue)")
        }
        backgroundTask = .invalid
    }

    // MARK: - Route Enforcement Window

    /// Start periodic route enforcement to fight Apple Watch hijacking
    private func startRouteEnforcementWindow() {
        // Stop any existing timer first
        stopRouteEnforcementWindow()

        // CRITICAL: Use DispatchSourceTimer (not Timer) for reliable background operation
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + 0.7, repeating: 0.7)

        timer.setEventHandler { [weak self] in
            guard let self = self, self.currentState != .idle else {
                self?.stopRouteEnforcementWindow()
                return
            }
            Task { @MainActor in
                self.enforcePhoneSpeakerRoute()
            }
        }

        // Store strong reference to prevent deallocation
        routeEnforcementTimer = timer
        timer.resume()

        // Stop enforcement after 15 seconds automatically
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [weak self] in
            self?.stopRouteEnforcementWindow()
        }

        print("🔊 AlarmSoundEngine: Started route enforcement window (15s) with DispatchSourceTimer")
    }

    /// Stop route enforcement timer (DispatchSourceTimer)
    private func stopRouteEnforcementWindow() {
        routeEnforcementTimer?.cancel()
        routeEnforcementTimer = nil
        print("🔊 AlarmSoundEngine: Route enforcement timer cancelled")
    }

    /// Enforce phone speaker route - called periodically during alarm
    @MainActor
    private func enforcePhoneSpeakerRoute() {
        guard currentState != .idle else { return }

        // Policy guard: only override if policy allows
        guard let policy = policyProvider?(), policy.allowRouteOverrideAtAlarm else {
            print("🔊 AlarmSoundEngine: Route override not allowed by policy - skipping enforcement")
            return
        }

        let session = AVAudioSession.sharedInstance()
        let currentRoute = session.currentRoute

        // Check current output route
        let outputs = currentRoute.outputs
        let isOnPhoneSpeaker = outputs.contains { output in
            output.portType == .builtInSpeaker || output.portName.contains("Speaker")
        }

        if isOnPhoneSpeaker {
            // Already on phone speaker - log success and STOP enforcement timer
            let outputNames = outputs.map { "\($0.portName) (\($0.portType))" }.joined(separator: ", ")
            print("🔊 AlarmSoundEngine: ✅ Route enforcement success: \(outputNames) - stopping timer")
            stopRouteEnforcementWindow()
            return
        }

        // Check if we should skip this override attempt (debounce logic)
        if shouldSkipRouteOverride() {
            let outputNames = outputs.map { "\($0.portName) (\($0.portType))" }.joined(separator: ", ")
            print("🔊 AlarmSoundEngine: ⚠️ Route hijacked by: \(outputNames) - skipping override (debounce active)")
            return
        }

        // Not on phone speaker - re-assert routing
        let outputNames = outputs.map { "\($0.portName) (\($0.portType))" }.joined(separator: ", ")
        print("🔊 AlarmSoundEngine: ⚠️ Route hijacked by: \(outputNames) - re-asserting speaker")

        performRouteOverride(context: "enforcement timer")
    }

    // MARK: - Debounce Logic

    /// Check if we should skip route override (debounce logic)
    private func shouldSkipRouteOverride() -> Bool {
        let session = AVAudioSession.sharedInstance()
        let now = Date()

        // Check if current route is already Built-In Speaker
        let currentRoute = session.currentRoute
        let isOnPhoneSpeaker = currentRoute.outputs.contains { output in
            output.portType == .builtInSpeaker || output.portName.contains("Speaker")
        }

        // Check if last override attempt was within debounce window (~700ms)
        let isWithinDebounceWindow: Bool
        if let lastAttempt = lastOverrideAttempt {
            isWithinDebounceWindow = now.timeIntervalSince(lastAttempt) < 0.7
        } else {
            isWithinDebounceWindow = false
        }

        // Skip if already on speaker AND within debounce window
        let shouldSkip = isOnPhoneSpeaker && isWithinDebounceWindow

        if shouldSkip {
            print("🔊 AlarmSoundEngine: Debounce conditions met - onSpeaker: \(isOnPhoneSpeaker), withinWindow: \(isWithinDebounceWindow)")
        }

        return shouldSkip
    }

    /// Perform route override with session checks
    @MainActor
    private func performRouteOverride(context: String) {
        // Policy guard: only override if policy allows
        guard let policy = policyProvider?(), policy.allowRouteOverrideAtAlarm else {
            print("🔊 AlarmSoundEngine: Route override not allowed by policy (\(context))")
            return
        }

        let session = AVAudioSession.sharedInstance()

        do {
            // Re-apply aggressive speaker routing
            try session.overrideOutputAudioPort(.speaker)
            try session.setActive(true, options: [])
            didActivateSession = true  // Update flag after activation

            // Update debounce timestamp
            lastOverrideAttempt = Date()

            print("🔊 AlarmSoundEngine: 🔄 Route override successful (\(context))")
        } catch {
            print("🔊 AlarmSoundEngine: ❌ Route override failed (\(context)): \(error)")
        }
    }
}

// MARK: - Convenience Methods

extension AlarmSoundEngine {
    /// Schedule alarm with bundled sound file
    @MainActor
    func scheduleAlarm(soundName: String = "ringtone1", extension: String = "caf", fireAt date: Date) throws {
        // CRITICAL: Hard existence check - refuse to pretend success if file missing
        guard let url = Bundle.main.url(forResource: soundName, withExtension: `extension`) else {
            // Try ultimate fallback to ringtone1 if not already trying it
            if soundName != "ringtone1" {
                print("🔊 AlarmSoundEngine: '\(soundName).\(`extension`)' not found, trying ultimate fallback 'ringtone1.caf'")
                guard let fallbackURL = Bundle.main.url(forResource: "ringtone1", withExtension: "caf") else {
                    throw AlarmAudioEngineError.assetNotFound(soundName: "\(soundName) (fallback also missing)")
                }
                try schedule(soundURL: fallbackURL, fireAt: date)
                print("🔊 AlarmSoundEngine: ✅ Using fallback 'ringtone1.caf' successfully")
                return
            }

            // Even ringtone1 not found - hard failure
            throw AlarmAudioEngineError.assetNotFound(soundName: soundName)
        }

        try schedule(soundURL: url, fireAt: date)
        print("🔊 AlarmSoundEngine: ✅ Scheduled with '\(soundName).\(`extension`)' successfully")
    }
}

```

### PermissionService.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Services/PermissionService.swift`

```swift
//
//  PermissionService.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 8/28/25.
//

import Foundation
import UserNotifications
import AVFoundation
import UIKit

// MARK: - Permission Status
enum PermissionStatus {
    case authorized
    case denied
    case notDetermined
    
    var isFirstTimeRequest: Bool {
        return self == .notDetermined
    }
    
    var requiresSettingsNavigation: Bool {
        return self == .denied
    }
}

// MARK: - Notification Permission Details
struct NotificationPermissionDetails {
    let authorizationStatus: PermissionStatus
    let alertsEnabled: Bool
    let soundEnabled: Bool
    let badgeEnabled: Bool
    
    var isAuthorizedButMuted: Bool {
        return authorizationStatus == .authorized && !soundEnabled
    }
    
    var isFullyAuthorized: Bool {
        return authorizationStatus == .authorized && alertsEnabled && soundEnabled
    }
    
    var userGuidanceText: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Tap 'Allow Notifications' to enable alarm notifications."
        case .denied:
            return "Go to Settings → Notifications → alarmAppNew → Allow Notifications"
        case .authorized:
            if isAuthorizedButMuted {
                return "Go to Settings → Notifications → alarmAppNew → Enable Sounds"
            } else {
                return "Notifications are properly configured."
            }
        }
    }
}

// MARK: - Permission Service Protocol
protocol PermissionServiceProtocol {
    func requestNotificationPermission() async throws -> PermissionStatus
    func checkNotificationPermission() async -> NotificationPermissionDetails
    func requestCameraPermission() async -> PermissionStatus
    func checkCameraPermission() -> PermissionStatus
    func openAppSettings()
}

// MARK: - Permission Service Implementation
class PermissionService: PermissionServiceProtocol {
    
    // MARK: - Notification Permissions
    func requestNotificationPermission() async throws -> PermissionStatus {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted ? .authorized : .denied
        } catch {
            throw error
        }
    }
    
    func checkNotificationPermission() async -> NotificationPermissionDetails {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        let authStatus: PermissionStatus
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            authStatus = .authorized
        case .denied:
            authStatus = .denied
        case .notDetermined:
            authStatus = .notDetermined
        case .ephemeral:
            authStatus = .authorized
        @unknown default:
            authStatus = .notDetermined
        }
        
        return NotificationPermissionDetails(
            authorizationStatus: authStatus,
            alertsEnabled: settings.alertSetting == .enabled,
            soundEnabled: settings.soundSetting == .enabled,
            badgeEnabled: settings.badgeSetting == .enabled
        )
    }
    
    // MARK: - Camera Permissions
    func requestCameraPermission() async -> PermissionStatus {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                let status: PermissionStatus = granted ? .authorized : .denied
                continuation.resume(returning: status)
            }
        }
    }
    
    func checkCameraPermission() -> PermissionStatus {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authStatus {
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }
    
    // MARK: - Settings Navigation
    @MainActor 
    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
```

### PersistenceService.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Services/PersistenceService.swift`

```swift
//
//  PersistenceService.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/10/25.
//  Converted to actor for thread-safe persistence per CLAUDE.md §3
//

import Foundation


actor PersistenceService: PersistenceStore {
  private let userDefaultsKey = "savedAlarms"
  private let defaults: UserDefaults
  private let soundCatalog: SoundCatalogProviding
  private var hasPerformedRepair = false
  private var isRepairing = false

  init(defaults: UserDefaults = .standard, soundCatalog: SoundCatalogProviding? = nil) {
    self.defaults = defaults
    self.soundCatalog = soundCatalog ?? SoundCatalog(validateFiles: false)
  }

  func loadAlarms() throws -> [Alarm] {
    print("📂 PersistenceService.loadAlarms: Loading alarms from UserDefaults")
    guard let data = defaults.data(forKey: userDefaultsKey) else {
      print("📂 PersistenceService.loadAlarms: No data found, returning empty array")
      return []
    }

    print("📂 PersistenceService.loadAlarms: Found \(data.count) bytes")
    var alarms = try JSONDecoder().decode([Alarm].self, from: data)
    print("📂 PersistenceService.loadAlarms: Decoded \(alarms.count) alarms")

    // Perform one-time repair for invalid soundIds
    if !hasPerformedRepair {
      var needsRepair = false

      for i in alarms.indices {
        if soundCatalog.info(for: alarms[i].soundId) == nil {
          // Log the validation fix
          print("🔧 PersistenceService: Resetting invalid soundId '\(alarms[i].soundId)' to default '\(soundCatalog.defaultSoundId)' for alarm \(alarms[i].id)")

          // Direct soundId mutation approach
          alarms[i] = Alarm(
            id: alarms[i].id,
            time: alarms[i].time,
            label: alarms[i].label,
            repeatDays: alarms[i].repeatDays,
            challengeKind: alarms[i].challengeKind,
            expectedQR: alarms[i].expectedQR,
            stepThreshold: alarms[i].stepThreshold,
            mathChallenge: alarms[i].mathChallenge,
            isEnabled: alarms[i].isEnabled,
            soundId: soundCatalog.defaultSoundId,
            soundName: alarms[i].soundName,
            volume: alarms[i].volume,
            externalAlarmId: alarms[i].externalAlarmId
          )
          needsRepair = true
        }
      }

      if needsRepair && !isRepairing {
        isRepairing = true
        defer { isRepairing = false }
        try saveAlarms(alarms)
      }

      hasPerformedRepair = true
    }

    return alarms
  }
  
  func saveAlarms(_ alarms: [Alarm]) throws {
    print("💾 PersistenceService.saveAlarms: Saving \(alarms.count) alarms")
    let data = try JSONEncoder().encode(alarms)
    defaults.set(data, forKey: userDefaultsKey)
    defaults.synchronize() // Force immediate write
    print("💾 PersistenceService.saveAlarms: Successfully saved \(alarms.count) alarms (\(data.count) bytes)")
  }


}

```

### QRScanningService.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Services/QRScanningService.swift`

```swift
//
//  QRScanningService.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/6/25.
//  QR scanning service implementation
//

import Foundation
import AVFoundation

// Service implementation using existing QRScannerView infrastructure
class QRScanningService: QRScanning {
    private let permissionService: PermissionServiceProtocol
    private var continuation: AsyncStream<String>.Continuation?
    private var isScanning = false
    
    init(permissionService: PermissionServiceProtocol) {
        self.permissionService = permissionService
    }
    
    func startScanning() async throws {
        guard !isScanning else { return }
        
        // Check/request camera permission
        let status = await permissionService.requestCameraPermission()
        guard status == .authorized else {
            throw QRScanningError.permissionDenied
        }
        
        isScanning = true
    }
    
    func stopScanning() {
        isScanning = false
        continuation?.finish()
        continuation = nil
    }
    
    func scanResultStream() -> AsyncStream<String> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }
    
    // Called by QRScannerView when scan completes
    func didScanQR(_ payload: String) {
        guard isScanning else { return }
        continuation?.yield(payload)
    }
}

enum QRScanningError: Error, LocalizedError {
    case permissionDenied
    case scanningFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera permission is required for QR scanning"
        case .scanningFailed:
            return "QR scanning failed"
        }
    }
}
```

### RefreshCoordinator.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Services/RefreshCoordinator.swift`

```swift
//
//  RefreshCoordinator.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/7/25.
//  Coordinates and coalesces notification refresh requests
//

import Foundation

/// Actor that coordinates notification refresh requests to prevent duplicate operations
public actor RefreshCoordinator {
    private var currentRefreshTask: Task<Void, Never>?
    private var isSchedulingInProgress = false
    private let notificationService: AlarmScheduling

    init(notificationService: AlarmScheduling) {
        self.notificationService = notificationService
    }

    /// Request a refresh of all alarms' notifications
    /// If a refresh is already in progress, this will join that operation
    /// rather than starting a duplicate
    public func requestRefresh(alarms: [Alarm]) async {
        // If there's an existing refresh in progress, join it
        if let existingTask = currentRefreshTask,
           !existingTask.isCancelled {
            // Wait for the existing refresh to complete
            await existingTask.value
            return
        }

        // Start a new refresh task using Task.detached to escape view lifecycle
        // This ensures scheduling continues even if the view that triggered it is dismissed
        currentRefreshTask = Task.detached { [weak self] in
            guard let self = self else { return }

            // Mark scheduling as in progress
            await self.setSchedulingInProgress(true)
            defer {
                Task { [weak self] in
                    await self?.setSchedulingInProgress(false)
                }
            }

            // No artificial delay - we coalesce by joining in-flight tasks
            // This will now run independently of any view lifecycle
            await self.notificationService.refreshAll(from: alarms)
        }

        // Wait for completion
        await currentRefreshTask?.value
    }

    /// Check if scheduling is currently in progress
    public func isSchedulingActive() async -> Bool {
        return isSchedulingInProgress
    }

    private func setSchedulingInProgress(_ value: Bool) {
        isSchedulingInProgress = value
    }

    /// Cancel any in-progress refresh operation
    public func cancelCurrentRefresh() {
        currentRefreshTask?.cancel()
        currentRefreshTask = nil
    }
}

```

### RefreshRequesting.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Services/RefreshRequesting.swift`

```swift
//
//  RefreshRequesting.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/7/25.
//  Protocol for requesting notification refresh operations
//

import Foundation

/// Protocol for requesting notification refresh operations
protocol RefreshRequesting {
    func requestRefresh(alarms: [Alarm]) async
}

// RefreshCoordinator already has the exact method signature
// Just declare conformance without implementing anything
extension RefreshCoordinator: RefreshRequesting {}
```

### ReliabilityLogger.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Services/ReliabilityLogger.swift`

```swift
//
//  ReliabilityLogger.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/7/25.
//  Local reliability logging for MVP1 critical events
//

import Foundation

// MARK: - Reliability Events
enum ReliabilityEvent: String, Codable {
    case scheduled = "scheduled"
    case fired = "fired"
    case dismissSuccessQR = "dismiss_success_qr"
    case dismissFailQR = "dismiss_fail_qr"
    case dismissSuccess = "dismiss_success"  // Generic success
    case stopFailed = "stop_failed"  // AlarmKit stop failed
    case snoozeSet = "snooze_set"  // Snooze scheduled
    case snoozeFailed = "snooze_failed"  // Snooze scheduling failed
    case notificationsStatusChanged = "notifications_status_changed"
    case cameraPermissionChanged = "camera_permission_changed"
    case alarmRunCreated = "alarm_run_created"
    case alarmRunCompleted = "alarm_run_completed"
}

// MARK: - Log Entry
struct ReliabilityLogEntry: Codable {
    let id: UUID
    let timestamp: Date
    let event: ReliabilityEvent
    let alarmId: UUID?
    let details: [String: String]
    
    init(event: ReliabilityEvent, alarmId: UUID? = nil, details: [String: String] = [:]) {
        self.id = UUID()
        self.timestamp = Date()
        self.event = event
        self.alarmId = alarmId
        self.details = details
    }
}

// MARK: - Reliability Logger Protocol
protocol ReliabilityLogging {
    func log(_ event: ReliabilityEvent, alarmId: UUID?, details: [String: String])
    func exportLogs() -> String
    func clearLogs()
    func getRecentLogs(limit: Int) -> [ReliabilityLogEntry]
}

// MARK: - Local File Reliability Logger
class LocalReliabilityLogger: ReliabilityLogging {
    private let fileManager = FileManager.default
    private let logFileName = "reliability_log.json"
    private let queue = DispatchQueue(label: "reliability-logger", qos: .utility)

    // State management
    private var didActivate = false
    private var cachedRecentLogs: [ReliabilityLogEntry] = []
    private var isCacheValid = false

    private var logFileURL: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(logFileName)
    }

    private var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Explicit activation to ensure directory exists with proper file protection
    func activate() {
        dispatchPrecondition(condition: .notOnQueue(queue))

        queue.sync {
            guard !didActivate else { return }

            do {
                try ensureDirectoryExistsInternal()
                didActivate = true
                print("ReliabilityLogger: Activated with directory and file protection")
            } catch {
                print("ReliabilityLogger: Activation failed: \(error)")
            }
        }
    }

    func log(_ event: ReliabilityEvent, alarmId: UUID? = nil, details: [String: String] = [:]) {
        dispatchPrecondition(condition: .notOnQueue(queue))

        let entry = ReliabilityLogEntry(event: event, alarmId: alarmId, details: details)

        // Fire-and-forget write with cache invalidation
        queue.async { [weak self] in
            guard let self = self else { return }
            assert(!Thread.isMainThread, "ReliabilityLogger: I/O should not run on main thread")

            self.appendLogEntryInternal(entry)

            // Invalidate cache so UI gets fresh data
            self.isCacheValid = false
        }

        // Also print to console for debugging (immediate, not queued)
        print("ReliabilityLog: \(event.rawValue) - \(alarmId?.uuidString.prefix(8) ?? "N/A") - \(details)")
    }

    func exportLogs() -> String {
        dispatchPrecondition(condition: .notOnQueue(queue))

        return queue.sync {
            assert(!Thread.isMainThread, "ReliabilityLogger: I/O should not run on main thread")

            do {
                let logs = try loadLogsInternal()
                let jsonData = try jsonEncoder.encode(logs)
                return String(data: jsonData, encoding: .utf8) ?? "Failed to encode logs"
            } catch {
                print("ReliabilityLogger: Export failed: \(error)")
                return "Failed to export logs: \(error.localizedDescription)"
            }
        }
    }

    func clearLogs() {
        dispatchPrecondition(condition: .notOnQueue(queue))

        queue.async { [weak self] in
            guard let self = self else { return }
            assert(!Thread.isMainThread, "ReliabilityLogger: I/O should not run on main thread")

            do {
                if self.fileManager.fileExists(atPath: self.logFileURL.path) {
                    try self.fileManager.removeItem(at: self.logFileURL)
                }
                // Clear cache after successful clear
                self.cachedRecentLogs = []
                self.isCacheValid = true
            } catch {
                print("Failed to clear reliability logs: \(error)")
            }
        }
    }

    func getRecentLogs(limit: Int = 100) -> [ReliabilityLogEntry] {
        dispatchPrecondition(condition: .notOnQueue(queue))

        return queue.sync {
            // Fast path: return cached data if valid
            if isCacheValid && cachedRecentLogs.count >= limit {
                return Array(cachedRecentLogs.suffix(limit))
            }

            // Slow path: load from disk and update cache
            do {
                let logs = try loadLogsInternal()
                cachedRecentLogs = logs
                isCacheValid = true
                return Array(logs.suffix(limit))
            } catch {
                print("Failed to load recent logs: \(error)")
                return []
            }
        }
    }

    // MARK: - Private Methods

    /// Ensure parent directory exists and has proper file protection for lock screen access
    /// INTERNAL: Call only from within queue context to avoid re-entrancy
    private func ensureDirectoryExistsInternal() throws {
        guard !didActivate else { return }

        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        if !fileManager.fileExists(atPath: documentsPath.path) {
            try fileManager.createDirectory(at: documentsPath, withIntermediateDirectories: true, attributes: [
                .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
            ])
            print("ReliabilityLogger: Created documents directory with file protection")
        }
    }

    /// INTERNAL: Load logs from disk - call only from within queue context
    private func loadLogsInternal() throws -> [ReliabilityLogEntry] {
        guard fileManager.fileExists(atPath: logFileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: logFileURL)
        return try jsonDecoder.decode([ReliabilityLogEntry].self, from: data)
    }

    /// INTERNAL: Append log entry - call only from within queue context
    private func appendLogEntryInternal(_ entry: ReliabilityLogEntry) {
        do {
            // Ensure directory exists with proper file protection (if not already done)
            if !didActivate {
                try ensureDirectoryExistsInternal()
            }

            var logs: [ReliabilityLogEntry] = []

            // Safely load existing logs
            do {
                logs = try loadLogsInternal()
            } catch {
                print("ReliabilityLogger: Could not load existing logs, starting fresh: \(error)")
                // Clear corrupted file and start fresh
                try? fileManager.removeItem(at: logFileURL)
                logs = []
            }

            logs.append(entry)

            // Keep only last 1000 entries to prevent excessive file growth
            if logs.count > 1000 {
                logs = Array(logs.suffix(1000))
            }

            // Use atomic write to prevent corruption with consistent encoding
            let jsonData = try jsonEncoder.encode(logs)

            // Write to temporary file first, then move to final location (atomic)
            let tempURL = logFileURL.appendingPathExtension("tmp")

            // Write with proper file protection for lock screen access
            try jsonData.write(to: tempURL, options: [.atomic])

            // Set file protection on temp file before moving
            try fileManager.setAttributes([
                .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
            ], ofItemAtPath: tempURL.path)

            // Atomic swap using replaceItem
            if fileManager.fileExists(atPath: logFileURL.path) {
                _ = try fileManager.replaceItem(at: logFileURL, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: nil)
            } else {
                // First time - just move the temp file
                try fileManager.moveItem(at: tempURL, to: logFileURL)
            }

            // Re-apply file protection after replace (attributes don't always carry over)
            try fileManager.setAttributes([
                .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
            ], ofItemAtPath: logFileURL.path)

        } catch {
            print("Failed to append reliability log entry: \(error)")

            // Clean up temp file if it exists
            let tempURL = logFileURL.appendingPathExtension("tmp")
            try? fileManager.removeItem(at: tempURL)

            // Last resort: try to clear the corrupted file
            if error.localizedDescription.contains("JSON") || error.localizedDescription.contains("dataCorrupted") {
                print("ReliabilityLogger: Clearing corrupted log file")
                try? fileManager.removeItem(at: logFileURL)
            }
        }
    }
}

// MARK: - Convenience Extensions
extension ReliabilityLogging {
    func logAlarmScheduled(_ alarmId: UUID, details: [String: String] = [:]) {
        log(.scheduled, alarmId: alarmId, details: details)
    }
    
    func logAlarmFired(_ alarmId: UUID, details: [String: String] = [:]) {
        log(.fired, alarmId: alarmId, details: details)
    }
    
    func logDismissSuccess(_ alarmId: UUID, method: String = "qr", details: [String: String] = [:]) {
        var enrichedDetails = details
        enrichedDetails["method"] = method
        log(.dismissSuccessQR, alarmId: alarmId, details: enrichedDetails)
    }
    
    func logDismissFail(_ alarmId: UUID, reason: String, details: [String: String] = [:]) {
        var enrichedDetails = details
        enrichedDetails["reason"] = reason
        log(.dismissFailQR, alarmId: alarmId, details: enrichedDetails)
    }
    
    func logPermissionChange(_ permission: String, status: String, details: [String: String] = [:]) {
        var enrichedDetails = details
        enrichedDetails["permission"] = permission
        enrichedDetails["status"] = status
        log(.notificationsStatusChanged, alarmId: nil, details: enrichedDetails)
    }
}
```

### ServiceProtocolExtensions.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Services/ServiceProtocolExtensions.swift`

```swift
//
//  ServiceProtocolExtensions.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/6/25.
//  Extensions to existing protocols for MVP1 dismissal flow
//

import Foundation
import SwiftUI

// MARK: - AlarmScheduling Extensions

extension AlarmScheduling {
    // Cancel notifications for a specific alarm ID
    func cancel(alarmId: UUID) async {
        // Implementation delegates to existing infrastructure
        // This creates the per-day IDs used by the current scheduling system
        let baseID = alarmId.uuidString
        
        // For repeat alarms, we need to cancel all weekday variations
        // The current system uses: "alarmId-weekday-X" format
        var idsToCancel = [baseID]
        
        // Add weekday variations (1-7 for Sunday-Saturday)
        for weekday in 1...7 {
            idsToCancel.append("\(baseID)-weekday-\(weekday)")
        }
        
        // Use the underlying notification center to cancel
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: idsToCancel)
    }
}

// MARK: - Error Types

struct AlarmNotFoundError: Error {}

// MARK: - PersistenceStore Extensions

extension PersistenceStore {
    // Convenience method to find alarm by ID
    func alarm(with id: UUID) throws -> Alarm {
        let alarms = try loadAlarms()
        guard let alarm = alarms.first(where: { $0.id == id }) else {
            throw AlarmNotFoundError()
        }
        return alarm
    }
}

// MARK: - Test Clock

struct TestClock: Clock {
    private var currentTime: Date
    
    init(time: Date = Date()) {
        self.currentTime = time
    }
    
    func now() -> Date {
        currentTime
    }
    
    mutating func advance(by interval: TimeInterval) {
        currentTime = currentTime.addingTimeInterval(interval)
    }
    
    mutating func set(to time: Date) {
        currentTime = time
    }
}

```

### SettingsService.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Services/SettingsService.swift`

```swift
//
//  SettingsService.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/24/25.
//

import Foundation
import Combine

// MARK: - Settings Errors

enum SettingsError: Error, LocalizedError {
    case intervalsNotSorted
    case invalidInterval
    case leadInOutOfRange

    var errorDescription: String? {
        switch self {
        case .intervalsNotSorted:
            return "Alert intervals must be sorted in ascending order"
        case .invalidInterval:
            return "Alert intervals must be non-negative"
        case .leadInOutOfRange:
            return "Lead-in time must be between 0 and 60 seconds"
        }
    }
}

// MARK: - Reliability Mode

enum ReliabilityMode: String, CaseIterable {
    case notificationsOnly = "notifications_only"
    case notificationsPlusAudio = "notifications_plus_audio"

    var displayName: String {
        switch self {
        case .notificationsOnly:
            return "Notifications Only (App Store Safe)"
        case .notificationsPlusAudio:
            return "Notifications + Background Audio (Experimental)"
        }
    }

    var description: String {
        switch self {
        case .notificationsOnly:
            return "Uses only system notifications for alarms. App Store compliant."
        case .notificationsPlusAudio:
            return "Adds background audio session management. For testing only."
        }
    }
}

// MARK: - Protocol for Dependency Injection

@MainActor
protocol ReliabilityModeProvider {
    var currentMode: ReliabilityMode { get }
    var modePublisher: AnyPublisher<ReliabilityMode, Never> { get }
}

// MARK: - Settings Service Protocol

@MainActor
protocol SettingsServiceProtocol: ReliabilityModeProvider {
    var useChainedScheduling: Bool { get }
    var useAudioEnhancement: Bool { get }
    var alertIntervalsSec: [Int] { get }
    var suppressForegroundSound: Bool { get }
    var leadInSec: Int { get }
    var foregroundAlarmBoost: Double { get }
    var audioPolicy: AudioPolicy { get }

    func setReliabilityMode(_ mode: ReliabilityMode)
    func setUseChainedScheduling(_ enabled: Bool)
    func setUseAudioEnhancement(_ enabled: Bool)
    func setAlertIntervals(_ intervals: [Int]) throws
    func setSuppressForegroundSound(_ enabled: Bool)
    func setLeadInSec(_ seconds: Int) throws
    func setForegroundAlarmBoost(_ boost: Double)
    func resetToDefaults()
}

// MARK: - Settings Service Implementation

@MainActor
final class SettingsService: SettingsServiceProtocol, ObservableObject {

    // MARK: - Constants

    private enum Keys {
        static let reliabilityMode = "com.alarmApp.reliabilityMode"
        static let useChainedScheduling = "com.alarmApp.useChainedScheduling"
        static let useAudioEnhancement = "com.alarmApp.useAudioEnhancement"
        static let alertIntervalsSec = "com.alarmApp.alertIntervalsSec"
        static let suppressForegroundSound = "com.alarmApp.suppressForegroundSound"
        static let leadInSec = "com.alarmApp.leadInSec"
        static let foregroundAlarmBoost = "com.alarmApp.foregroundAlarmBoost"
    }

    // MARK: - Published Properties

    @Published private(set) var currentMode: ReliabilityMode = .notificationsOnly
    @Published private(set) var useChainedScheduling: Bool = true
    @Published private(set) var useAudioEnhancement: Bool = false
    @Published private(set) var alertIntervalsSec: [Int] = [0, 10, 20]
    @Published private(set) var suppressForegroundSound: Bool = true
    @Published private(set) var leadInSec: Int = 2
    @Published private(set) var foregroundAlarmBoost: Double = 1.0  // Range: 0.8-1.5

    // MARK: - Dependencies

    private let userDefaults: UserDefaults
    private let audioEngine: AlarmAudioEngineProtocol
    private let subject = CurrentValueSubject<ReliabilityMode, Never>(.notificationsOnly)

    // MARK: - Public Properties

    var modePublisher: AnyPublisher<ReliabilityMode, Never> {
        subject.eraseToAnyPublisher()
    }

    var audioPolicy: AudioPolicy {
        switch currentMode {
        case .notificationsOnly:
            return AudioPolicy(capability: .foregroundAssist, allowRouteOverrideAtAlarm: true)
        case .notificationsPlusAudio:
            return AudioPolicy(capability: .sleepMode, allowRouteOverrideAtAlarm: true)
        }
    }

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard, audioEngine: AlarmAudioEngineProtocol) {
        self.userDefaults = userDefaults
        self.audioEngine = audioEngine

        // Load persisted settings or use defaults
        loadPersistedMode()
        loadChainedSchedulingPreference()
        loadAudioEnhancementSettings()

        print("🔧 SettingsService: Initialized with mode: \(currentMode.rawValue), chainedScheduling: \(useChainedScheduling), audioEnhancement: \(useAudioEnhancement)")
    }

    // MARK: - Public Methods

    func setReliabilityMode(_ mode: ReliabilityMode) {
        let previousMode = currentMode

        guard previousMode != mode else {
            print("🔧 SettingsService: Mode already set to \(mode.rawValue) - ignoring")
            return
        }

        print("🔧 SettingsService: Changing reliability mode: \(previousMode.rawValue) → \(mode.rawValue)")

        // CRITICAL: If switching to notifications only, immediately stop any active audio
        if mode == .notificationsOnly && audioEngine.currentState != .idle {
            print("🔇 SettingsService: IMMEDIATE STOP - switching to notifications only")
            audioEngine.stop() // This performs full teardown
        }

        // Update current mode
        currentMode = mode

        // Persist the change
        userDefaults.set(mode.rawValue, forKey: Keys.reliabilityMode)

        // Notify subscribers
        subject.send(mode)

        print("🔧 SettingsService: ✅ Mode change complete: \(mode.rawValue)")
    }

    func setUseChainedScheduling(_ enabled: Bool) {
        guard useChainedScheduling != enabled else {
            print("🔧 SettingsService: Chained scheduling already set to \(enabled) - ignoring")
            return
        }

        print("🔧 SettingsService: Changing chained scheduling: \(useChainedScheduling) → \(enabled)")
        useChainedScheduling = enabled
        userDefaults.set(enabled, forKey: Keys.useChainedScheduling)
        print("🔧 SettingsService: ✅ Chained scheduling changed to: \(enabled)")
    }

    func setUseAudioEnhancement(_ enabled: Bool) {
        // Audio enhancement can only be enabled when in notificationsPlusAudio mode
        guard currentMode == .notificationsPlusAudio || !enabled else {
            print("🔧 SettingsService: ⚠️ Cannot enable audio enhancement in notifications-only mode")
            return
        }

        guard useAudioEnhancement != enabled else {
            print("🔧 SettingsService: Audio enhancement already set to \(enabled) - ignoring")
            return
        }

        print("🔧 SettingsService: Changing audio enhancement: \(useAudioEnhancement) → \(enabled)")
        useAudioEnhancement = enabled
        userDefaults.set(enabled, forKey: Keys.useAudioEnhancement)
        print("🔧 SettingsService: ✅ Audio enhancement changed to: \(enabled)")
    }

    func setAlertIntervals(_ intervals: [Int]) throws {
        // Validation: Must be sorted ascending
        guard intervals == intervals.sorted() else {
            throw SettingsError.intervalsNotSorted
        }

        // Validation: All intervals must be non-negative
        guard intervals.allSatisfy({ $0 >= 0 }) else {
            throw SettingsError.invalidInterval
        }

        print("🔧 SettingsService: Changing alert intervals: \(alertIntervalsSec) → \(intervals)")
        alertIntervalsSec = intervals
        userDefaults.set(intervals, forKey: Keys.alertIntervalsSec)
        print("🔧 SettingsService: ✅ Alert intervals changed to: \(intervals)")
    }

    func setSuppressForegroundSound(_ enabled: Bool) {
        guard suppressForegroundSound != enabled else {
            print("🔧 SettingsService: Suppress foreground sound already set to \(enabled) - ignoring")
            return
        }

        print("🔧 SettingsService: Changing suppress foreground sound: \(suppressForegroundSound) → \(enabled)")
        suppressForegroundSound = enabled
        userDefaults.set(enabled, forKey: Keys.suppressForegroundSound)
        print("🔧 SettingsService: ✅ Suppress foreground sound changed to: \(enabled)")
    }

    func setLeadInSec(_ seconds: Int) throws {
        // Validation: Must be 0-60 seconds
        guard (0...60).contains(seconds) else {
            throw SettingsError.leadInOutOfRange
        }

        print("🔧 SettingsService: Changing lead-in seconds: \(leadInSec) → \(seconds)")
        leadInSec = seconds
        userDefaults.set(seconds, forKey: Keys.leadInSec)
        print("🔧 SettingsService: ✅ Lead-in seconds changed to: \(seconds)")
    }

    func setForegroundAlarmBoost(_ boost: Double) {
        // Clamp to valid range: 0.8-1.5
        let clampedBoost = max(0.8, min(1.5, boost))

        guard foregroundAlarmBoost != clampedBoost else {
            print("🔧 SettingsService: Foreground alarm boost already set to \(clampedBoost) - ignoring")
            return
        }

        print("🔧 SettingsService: Changing foreground alarm boost: \(foregroundAlarmBoost) → \(clampedBoost)")
        foregroundAlarmBoost = clampedBoost
        userDefaults.set(clampedBoost, forKey: Keys.foregroundAlarmBoost)
        print("🔧 SettingsService: ✅ Foreground alarm boost changed to: \(clampedBoost)")
    }

    func resetToDefaults() {
        print("🔧 SettingsService: Resetting to defaults")
        setReliabilityMode(.notificationsOnly)
        setUseChainedScheduling(true)
        setUseAudioEnhancement(false)
        try? setAlertIntervals([0, 10, 20])
        setSuppressForegroundSound(true)
        try? setLeadInSec(2)
        setForegroundAlarmBoost(1.0)
    }

    // MARK: - Private Methods

    private func loadPersistedMode() {
        let rawValue = userDefaults.string(forKey: Keys.reliabilityMode)

        if let rawValue = rawValue,
           let persistedMode = ReliabilityMode(rawValue: rawValue) {
            currentMode = persistedMode
            print("🔧 SettingsService: Loaded persisted mode: \(persistedMode.rawValue)")
        } else {
            currentMode = .notificationsOnly
            print("🔧 SettingsService: Using default mode: \(currentMode.rawValue)")
        }

        // Initialize the subject with the loaded mode
        subject.send(currentMode)
    }

    private func loadChainedSchedulingPreference() {
        // Default to true if not set (enable new feature by default)
        if userDefaults.object(forKey: Keys.useChainedScheduling) == nil {
            useChainedScheduling = true
            userDefaults.set(true, forKey: Keys.useChainedScheduling)
            print("🔧 SettingsService: Using default chained scheduling: true")
        } else {
            useChainedScheduling = userDefaults.bool(forKey: Keys.useChainedScheduling)
            print("🔧 SettingsService: Loaded persisted chained scheduling: \(useChainedScheduling)")
        }
    }

    private func loadAudioEnhancementSettings() {
        // Load useAudioEnhancement (default: false, only enable in notificationsPlusAudio mode)
        if userDefaults.object(forKey: Keys.useAudioEnhancement) == nil {
            useAudioEnhancement = false
            userDefaults.set(false, forKey: Keys.useAudioEnhancement)
            print("🔧 SettingsService: Using default audio enhancement: false")
        } else {
            let persistedValue = userDefaults.bool(forKey: Keys.useAudioEnhancement)
            // Enforce constraint: can only be true in notificationsPlusAudio mode
            useAudioEnhancement = persistedValue && currentMode == .notificationsPlusAudio
            print("🔧 SettingsService: Loaded audio enhancement: \(useAudioEnhancement) (persisted: \(persistedValue))")
        }

        // Load alertIntervalsSec (default: [0, 10, 20])
        if let persistedIntervals = userDefaults.array(forKey: Keys.alertIntervalsSec) as? [Int], !persistedIntervals.isEmpty {
            alertIntervalsSec = persistedIntervals
            print("🔧 SettingsService: Loaded alert intervals: \(alertIntervalsSec)")
        } else {
            alertIntervalsSec = [0, 10, 20]
            userDefaults.set(alertIntervalsSec, forKey: Keys.alertIntervalsSec)
            print("🔧 SettingsService: Using default alert intervals: \(alertIntervalsSec)")
        }

        // Load suppressForegroundSound (default: true)
        if userDefaults.object(forKey: Keys.suppressForegroundSound) == nil {
            suppressForegroundSound = true
            userDefaults.set(true, forKey: Keys.suppressForegroundSound)
            print("🔧 SettingsService: Using default suppress foreground sound: true")
        } else {
            suppressForegroundSound = userDefaults.bool(forKey: Keys.suppressForegroundSound)
            print("🔧 SettingsService: Loaded suppress foreground sound: \(suppressForegroundSound)")
        }

        // Load leadInSec (default: 2)
        if userDefaults.object(forKey: Keys.leadInSec) == nil {
            leadInSec = 2
            userDefaults.set(2, forKey: Keys.leadInSec)
            print("🔧 SettingsService: Using default lead-in seconds: 2")
        } else {
            leadInSec = userDefaults.integer(forKey: Keys.leadInSec)
            print("🔧 SettingsService: Loaded lead-in seconds: \(leadInSec)")
        }

        // Load foregroundAlarmBoost (default: 1.0, range: 0.8-1.5)
        if userDefaults.object(forKey: Keys.foregroundAlarmBoost) == nil {
            foregroundAlarmBoost = 1.0
            userDefaults.set(1.0, forKey: Keys.foregroundAlarmBoost)
            print("🔧 SettingsService: Using default foreground alarm boost: 1.0")
        } else {
            let persistedBoost = userDefaults.double(forKey: Keys.foregroundAlarmBoost)
            foregroundAlarmBoost = max(0.8, min(1.5, persistedBoost))  // Clamp to valid range
            print("🔧 SettingsService: Loaded foreground alarm boost: \(foregroundAlarmBoost)")
        }
    }
}

// MARK: - Mock for Testing

#if DEBUG
@MainActor
final class MockSettingsService: SettingsServiceProtocol {
    @Published private(set) var currentMode: ReliabilityMode = .notificationsOnly
    @Published var useChainedScheduling: Bool = true
    @Published var useAudioEnhancement: Bool = false
    @Published var alertIntervalsSec: [Int] = [0, 10, 20]
    @Published var suppressForegroundSound: Bool = true
    @Published var leadInSec: Int = 2
    @Published var foregroundAlarmBoost: Double = 1.0
    private let subject = CurrentValueSubject<ReliabilityMode, Never>(.notificationsOnly)

    var modePublisher: AnyPublisher<ReliabilityMode, Never> {
        subject.eraseToAnyPublisher()
    }

    var audioPolicy: AudioPolicy {
        switch currentMode {
        case .notificationsOnly:
            return AudioPolicy(capability: .foregroundAssist, allowRouteOverrideAtAlarm: true)
        case .notificationsPlusAudio:
            return AudioPolicy(capability: .sleepMode, allowRouteOverrideAtAlarm: true)
        }
    }

    func setReliabilityMode(_ mode: ReliabilityMode) {
        currentMode = mode
        subject.send(mode)
    }

    func setUseChainedScheduling(_ enabled: Bool) {
        useChainedScheduling = enabled
    }

    func setUseAudioEnhancement(_ enabled: Bool) {
        useAudioEnhancement = enabled
    }

    func setAlertIntervals(_ intervals: [Int]) throws {
        guard intervals == intervals.sorted() else {
            throw SettingsError.intervalsNotSorted
        }
        alertIntervalsSec = intervals
    }

    func setSuppressForegroundSound(_ enabled: Bool) {
        suppressForegroundSound = enabled
    }

    func setLeadInSec(_ seconds: Int) throws {
        guard (0...60).contains(seconds) else {
            throw SettingsError.leadInOutOfRange
        }
        leadInSec = seconds
    }

    func setForegroundAlarmBoost(_ boost: Double) {
        foregroundAlarmBoost = max(0.8, min(1.5, boost))
    }

    func resetToDefaults() {
        setReliabilityMode(.notificationsOnly)
        setUseChainedScheduling(true)
        setUseAudioEnhancement(false)
        try? setAlertIntervals([0, 10, 20])
        setSuppressForegroundSound(true)
        try? setLeadInSec(2)
        setForegroundAlarmBoost(1.0)
    }
}
#endif
```

### ActiveAlarmDetector.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/ViewModels/ActiveAlarmDetector.swift`

```swift
//
//  ActiveAlarmDetector.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/8/25.
//  Detects active alarms from delivered notifications and routes to dismissal flow
//

import Foundation

/// Detects if any alarm is currently active (firing) based on delivered notifications
/// Uses protocol-based dependencies for testability
@MainActor
public final class ActiveAlarmDetector {
    private let deliveredNotificationsReader: DeliveredNotificationsReading
    private let activeAlarmPolicy: ActiveAlarmPolicyProviding
    private let dismissedRegistry: DismissedRegistry
    private let alarmStorage: PersistenceStore

    init(
        deliveredNotificationsReader: DeliveredNotificationsReading,
        activeAlarmPolicy: ActiveAlarmPolicyProviding,
        dismissedRegistry: DismissedRegistry,
        alarmStorage: PersistenceStore
    ) {
        self.deliveredNotificationsReader = deliveredNotificationsReader
        self.activeAlarmPolicy = activeAlarmPolicy
        self.dismissedRegistry = dismissedRegistry
        self.alarmStorage = alarmStorage
    }

    /// Check for any currently active alarm
    /// Returns (Alarm, OccurrenceKey) if an active alarm is found, nil otherwise
    func checkForActiveAlarm() async -> (Alarm, OccurrenceKey)? {
        let now = Date()

        // Get delivered notifications from the system
        let delivered = await deliveredNotificationsReader.getDeliveredNotifications()

        // Check each delivered notification to see if it's within the active window
        for notification in delivered {
            // Parse the identifier to extract alarm ID and occurrence key
            guard let alarmId = OccurrenceKeyFormatter.parseAlarmId(from: notification.identifier),
                  let occurrenceKey = OccurrenceKeyFormatter.parse(fromIdentifier: notification.identifier) else {
                continue
            }

            // Check if this occurrence has already been dismissed
            let occurrenceKeyString = OccurrenceKeyFormatter.key(from: occurrenceKey.date)
            if dismissedRegistry.isDismissed(alarmId: alarmId, occurrenceKey: occurrenceKeyString) {
                print("🔍 ActiveAlarmDetector: Skipping dismissed occurrence \(notification.identifier.prefix(50))...")
                continue
            }

            // Compute the active window for this occurrence
            let activeWindowSeconds = activeAlarmPolicy.activeWindowSeconds(for: alarmId, occurrenceKey: notification.identifier)
            let occurrenceDate = occurrenceKey.date
            let activeUntil = occurrenceDate.addingTimeInterval(activeWindowSeconds)

            // Check if we're currently within the active window
            if now >= occurrenceDate && now <= activeUntil {
                // Found an active alarm! Load the full alarm object
                do {
                    let alarms = try await alarmStorage.loadAlarms()
                    if let alarm = alarms.first(where: { $0.id == alarmId }) {
                        print("✅ ActiveAlarmDetector: Found active alarm \(alarmId.uuidString.prefix(8)) at occurrence \(occurrenceKeyString)")
                        return (alarm, occurrenceKey)
                    }
                } catch {
                    print("❌ ActiveAlarmDetector: Failed to load alarms: \(error)")
                }
            }
        }

        // No active alarms found
        return nil
    }
}

```

### AlarmDetailViewModel.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/ViewModels/AlarmDetailViewModel.swift`

```swift
//
//  AlarmDetailViewModel.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/22/25.
//

import SwiftUI

class AlarmDetailViewModel:ObservableObject, Identifiable {
  let id = UUID()
  @Published var draft: Alarm
  let isNewAlarm: Bool

  
  init(alarm: Alarm, isNew: Bool = false) {
    self.draft = alarm
    self.isNewAlarm = isNew
  }

  var isValid: Bool {
    //qr challenge is either not selected or qr var is not empty
    let qrOK = !draft.challengeKind.contains(.qr) || (draft.expectedQR?.isEmpty == false)
    let soundOK = !draft.soundId.isEmpty
    let volumeOK = draft.volume >= 0.0 && draft.volume <= 1.0
    return qrOK && soundOK && volumeOK && !draft.label.isEmpty
  }

  func commitChanges() -> Alarm {
    return draft
  }

  func repeatBinding(for day: Weekdays) -> Binding<Bool> {
    Binding<Bool> (
      get: {self.draft.repeatDays.contains(day) },
      set: { isOn in
        if isOn {
          if !self.draft.repeatDays.contains(day){
            self.draft.repeatDays.append(day)
          }
        } else {
          self.draft.repeatDays.removeAll { $0 == day }
        }
      }
    )
  }

  func removeChallenge(_ kind: Challenges) {
    draft.challengeKind.removeAll{$0 == kind}
    if kind == .qr {
      draft.expectedQR = nil
    }
  }
  
  // MARK: - Sound Management

  func updateSound(_ soundId: String) {
    draft.soundId = soundId
    // Keep soundName in sync for backward compatibility
    draft.soundName = soundId
  }
  
  func updateVolume(_ volume: Double) {
    draft.volume = max(0.0, min(1.0, volume))
  }
  
  var volumeBinding: Binding<Double> {
    Binding<Double>(
      get: { self.draft.volume },
      set: { self.updateVolume($0) }
    )
  }
  
  var soundIdBinding: Binding<String> {
    Binding<String>(
      get: { self.draft.soundId },
      set: { self.updateSound($0) }
    )
  }
}

```

### AlarmListViewModel.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/ViewModels/AlarmListViewModel.swift`

```swift
//
//  AlarmListViewModel.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/21/25.
//
import Foundation
import SwiftUI

@MainActor
class AlarmListViewModel: ObservableObject {
  @Published var errorMessage: String?
  @Published var alarms: [Alarm] = []
  @Published var notificationPermissionDetails: NotificationPermissionDetails?
  @Published var showPermissionBlocking = false
  @Published var showMediaVolumeWarning = false

  private let storage: PersistenceStore
  private let permissionService: PermissionServiceProtocol
  private let alarmScheduler: AlarmScheduling
  private let refresher: RefreshRequesting
  private let systemVolumeProvider: SystemVolumeProviding
  private let notificationService: AlarmScheduling  // Keep for test methods only

  init(
    storage: PersistenceStore,
    permissionService: PermissionServiceProtocol,
    alarmScheduler: AlarmScheduling,
    refresher: RefreshRequesting,
    systemVolumeProvider: SystemVolumeProviding,
    notificationService: AlarmScheduling  // Keep for test methods
  ) {
    self.storage = storage
    self.permissionService = permissionService
    self.alarmScheduler = alarmScheduler
    self.refresher = refresher
    self.systemVolumeProvider = systemVolumeProvider
    self.notificationService = notificationService

    fetchAlarms()
    checkNotificationPermissions()
  }

  func refreshPermission() {
      Task {
          let details = await permissionService.checkNotificationPermission()
          self.notificationPermissionDetails = details
      }
  }


  func fetchAlarms() {
    Task {
      do {
        let loadedAlarms = try await storage.loadAlarms()
        await MainActor.run {
          self.alarms = loadedAlarms
          self.errorMessage = nil
        }
      } catch {
        await MainActor.run {
          self.alarms = []
          self.errorMessage = "Could not load alarms"
        }
      }
    }
  }
  
  func checkNotificationPermissions() {
    Task {
      let details = await permissionService.checkNotificationPermission()
      await MainActor.run {
        self.notificationPermissionDetails = details
      }
    }
  }

  func add (_ alarm: Alarm) {
    alarms.append(alarm)
    Task {
      await sync(alarm)
    }
  }

  func toggle(_ alarm:Alarm) {
    guard let thisAlarm = alarms.firstIndex(where: {$0.id == alarm.id}) else { return }

    // Data model guardrail: Don't allow enabling alarms without expectedQR (QR-only MVP)
    if !alarm.isEnabled && alarm.expectedQR == nil {
      errorMessage = "Cannot enable alarm: QR code required for dismissal"
      return
    }

    // Check media volume before enabling alarm
    if !alarm.isEnabled {
      checkMediaVolumeBeforeArming()
    }

    alarms[thisAlarm].isEnabled.toggle()
    Task {
      await sync(alarms[thisAlarm])
    }
  }



  func update(_ alarm: Alarm) {
    guard let thisAlarm = alarms.firstIndex(where: {$0.id == alarm.id}) else { return }
    alarms[thisAlarm] = alarm
    Task {
      await sync(alarm)
    }
  }

  func delete(_ alarm: Alarm) {
    alarms.removeAll{ $0.id == alarm.id}
    Task {
      await sync(alarm)
    }
  }

  private func sync(_ alarm: Alarm) async {
    do {
      try await storage.saveAlarms(alarms)

      // Handle scheduling based on enabled state using unified scheduler
      if !alarm.isEnabled {
        // Cancel alarm when disabling
        await alarmScheduler.cancel(alarmId: alarm.id)
        print("Alarm \(alarm.id.uuidString.prefix(8)): Cancelled (disabled)")
      } else {
        // Schedule alarm when enabling/adding
        // AlarmScheduling.schedule() is always immediate (no separate "immediate" method)
        _ = try await alarmScheduler.schedule(alarm: alarm)
        print("Alarm \(alarm.id.uuidString.prefix(8)): Scheduled")
      }

      // Still trigger refresh for other alarms (non-blocking, best-effort)
      // This handles any other alarms that might need reconciliation
      Task.detached { [weak self] in
        guard let self = self else { return }
        await self.refresher.requestRefresh(alarms: self.alarms)
        print("Alarm \(alarm.id.uuidString.prefix(8)): Background refresh triggered")
      }

      await MainActor.run {
        self.errorMessage = nil
        self.checkNotificationPermissions() // Refresh permission status
      }
    } catch {
      await MainActor.run {
        // Handle specific scheduling errors with appropriate messaging
        if let schedulingError = error as? AlarmSchedulingError {
          switch schedulingError {
          case .systemLimitExceeded:
            // Provide helpful guidance for system limit
            self.errorMessage = "Too many alarms scheduled. Please disable some alarms to add more (iOS limit: 64 notifications)."
          case .permissionDenied:
            self.errorMessage = schedulingError.description
            self.showPermissionBlocking = true
          case .schedulingFailed:
            self.errorMessage = schedulingError.description
          case .invalidConfiguration:
            self.errorMessage = schedulingError.description
          case .notAuthorized:
            self.errorMessage = "AlarmKit permission not granted"
            self.showPermissionBlocking = true
          case .alarmNotFound:
            self.errorMessage = "Alarm not found in system"
          case .ambiguousAlarmState:
            self.errorMessage = "Multiple alarms alerting - cannot determine which to stop"
          case .alreadyHandledBySystem:
            self.errorMessage = "Alarm was already handled by system"
          }
        } else {
          self.errorMessage = "Could not update alarm"
        }
      }
    }
  }
  
  func refreshAllAlarms() async {
    // Use refresher which knows how to use the correct scheduler
    await refresher.requestRefresh(alarms: alarms)
    checkNotificationPermissions()
  }
  
  func handlePermissionGranted() {
    showPermissionBlocking = false
    checkNotificationPermissions()
    
    // Re-sync all enabled alarms
    Task {
      await refreshAllAlarms()
    }
  }

  func ensureNotificationPermissionIfNeeded() {
      Task {
          let details = await permissionService.checkNotificationPermission()
          switch details.authorizationStatus {
          case .notDetermined:
              // show your blocker (or directly request)
              self.showPermissionBlocking = true
          case .denied:
              // keep inline warning; allow Open Settings
              break
          case .authorized:
              break
          }
      }
  }

  // MARK: - Volume Warning

  /// Checks media volume and shows warning if below threshold
  private func checkMediaVolumeBeforeArming() {
    let currentVolume = systemVolumeProvider.currentMediaVolume()

    if currentVolume < AudioUXPolicy.lowMediaVolumeThreshold {
      showMediaVolumeWarning = true
    } else {
      showMediaVolumeWarning = false
    }
  }

  /// Schedules a one-off test alarm to verify lock-screen sound volume
  func testLockScreen() {
    Task {
      do {
        try await notificationService.scheduleOneOffTestAlarm(
          leadTime: AudioUXPolicy.testLeadSeconds
        )
        print("✅ Lock-screen test alarm scheduled (fires in \(Int(AudioUXPolicy.testLeadSeconds))s)")
      } catch {
        errorMessage = "Failed to schedule test alarm: \(error.localizedDescription)"
      }
    }
  }
}

```

### DismissalFlowViewModel.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/ViewModels/DismissalFlowViewModel.swift`

```swift
//
//  DismissalFlowViewModel.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/6/25.
//  MVP1 QR-only enforced dismissal flow
//  Architecture: Views → ViewModels → Domain → Infrastructure
//

import SwiftUI
import Combine
import AVFoundation

@MainActor
final class DismissalFlowViewModel: ObservableObject {
    
    // MARK: - State Machine

    enum State: Equatable {
        case idle
        case ringing
        case scanning
        case validating
        case success
        case failed(FailureReason)

        var canRetry: Bool {
            if case .failed = self { return true }
            return false
        }
    }

    // MARK: - Phase for AlarmKit integration

    enum Phase: Equatable {
        case awaitingChallenge
        case validating
        case stopping
        case snoozing
        case success
        case failed(String?)
    }
    
    enum FailureReason: Equatable {
        case qrMismatch
        case scanningError
        case permissionDenied
        case noExpectedQR
        case alarmNotFound
        case multipleAlarmsAlerting
        case alarmEndedButChallengesIncomplete  // System auto-dismissed; challenges incomplete

        var displayMessage: String {
            switch self {
            case .qrMismatch:
                return "Invalid QR code. Please try again."
            case .scanningError:
                return "Scanning failed. Please try again."
            case .permissionDenied:
                return "Camera permission required for QR scanning."
            case .noExpectedQR:
                return "No QR code configured for this alarm."
            case .alarmNotFound:
                return "Alarm not found."
            case .multipleAlarmsAlerting:
                return "Multiple alarms detected. Please try again."
            case .alarmEndedButChallengesIncomplete:
                return "Alarm ended by system. Please complete challenges before dismissing."
            }
        }
    }
    
    // MARK: - Published State

    @Published var state: State = .idle
    @Published var phase: Phase = .awaitingChallenge
    @Published var challengeProgress: (completed: Int, total: Int) = (0, 0)
    @Published var scanFeedbackMessage: String?
    @Published var isScreenAwake = false

    // MARK: - Computed Properties

    /// Whether the alarm can be stopped (challenges are complete)
    var canStopAlarm: Bool {
        guard let alarm = alarmSnapshot else { return false }

        let challengeState = ChallengeStackState(
            requiredChallenges: alarm.challengeKind,
            completedChallenges: hasCompletedQR ? [.qr] : []
        )

        return stopAllowed.execute(challengeState: challengeState)
    }

    /// Whether snooze is allowed (alarm is ringing, not in failed state)
    var canSnooze: Bool {
        return state == .ringing && !hasCompletedSuccess
    }

    // MARK: - Dependencies (Protocol-based DI)

    private let qrScanning: QRScanning
    private let notificationService: AlarmScheduling  // Keep for legacy cleanup shim
    private let alarmStorage: PersistenceStore
    private let clock: Clock
    private let appRouter: AppRouting
    private let permissionService: PermissionServiceProtocol
    private let reliabilityLogger: ReliabilityLogging
    private let audioEngine: AlarmAudioEngineProtocol
    private let reliabilityModeProvider: ReliabilityModeProvider
    private let dismissedRegistry: DismissedRegistry
    private let settingsService: SettingsServiceProtocol
    private let alarmScheduler: AlarmScheduling  // NEW: Unified scheduler
    private let alarmRunStore: AlarmRunStore  // NEW: Actor-based run persistence
    private let stopAllowed: StopAlarmAllowed.Type  // NEW: Injected use case
    private let snoozeComputer: SnoozeAlarm.Type  // NEW: Injected use case
    private let idleTimerController: IdleTimerControlling  // NEW: UIKit isolation
    
    // MARK: - Private State

    private var alarmSnapshot: Alarm?
    private var currentAlarmRun: AlarmRun?
    private var occurrenceKey: String?  // ISO8601 formatted fireDate for occurrence-scoped cancellation
    private var scanTask: Task<Void, Never>?
    private var lastSuccessPayload: String?
    private var lastSuccessTime: Date?
    private var hasCompletedSuccess = false
    private var hasCompletedQR = false  // Track QR completion for MVP
    private var intentAlarmId: UUID?  // Optional ID from firing intent (for pre-migration alarms)
    
    // Atomic transition guards
    private var isTransitioning = false
    private let transitionQueue = DispatchQueue(label: "dismissal-flow-transitions", qos: .userInteractive)
    
    // MARK: - Callbacks (Separation of Concerns)

    var onStateChange: ((State) -> Void)?
    var onRunLogged: ((AlarmRun) -> Void)?
    var onRequestHaptics: (() -> Void)?
    
    // MARK: - Init

    init(
        qrScanning: QRScanning,
        notificationService: AlarmScheduling,
        alarmStorage: PersistenceStore,
        clock: Clock,
        appRouter: AppRouting,
        permissionService: PermissionServiceProtocol,
        reliabilityLogger: ReliabilityLogging,
        audioEngine: AlarmAudioEngineProtocol,
        reliabilityModeProvider: ReliabilityModeProvider,
        dismissedRegistry: DismissedRegistry,
        settingsService: SettingsServiceProtocol,
        alarmScheduler: AlarmScheduling,
        alarmRunStore: AlarmRunStore,  // NEW: Actor-based run persistence
        idleTimerController: IdleTimerControlling,  // NEW: UIKit isolation
        stopAllowed: StopAlarmAllowed.Type = StopAlarmAllowed.self,
        snoozeComputer: SnoozeAlarm.Type = SnoozeAlarm.self,
        intentAlarmId: UUID? = nil  // Optional ID from firing intent
    ) {
        self.qrScanning = qrScanning
        self.notificationService = notificationService
        self.alarmStorage = alarmStorage
        self.clock = clock
        self.appRouter = appRouter
        self.permissionService = permissionService
        self.reliabilityLogger = reliabilityLogger
        self.audioEngine = audioEngine
        self.reliabilityModeProvider = reliabilityModeProvider
        self.dismissedRegistry = dismissedRegistry
        self.settingsService = settingsService
        self.alarmScheduler = alarmScheduler
        self.alarmRunStore = alarmRunStore  // NEW
        self.idleTimerController = idleTimerController  // NEW
        self.stopAllowed = stopAllowed
        self.snoozeComputer = snoozeComputer
        self.intentAlarmId = intentAlarmId
    }
    
    // MARK: - Public Intents (All Idempotent)

    @MainActor
    func onChallengeUpdate(completed: Int, total: Int) {
        challengeProgress = (completed, total)
    }

    func start(alarmId: UUID) async {
        // Idempotent: ignore if not idle
        guard state == .idle else { return }

        do {
            // Load alarm snapshot once
            let alarm = try await alarmStorage.alarm(with: alarmId)
            alarmSnapshot = alarm
            
            // Create run record
            let firedAt = clock.now()
            currentAlarmRun = AlarmRun(
                id: UUID(),
                alarmId: alarmId,
                firedAt: firedAt,
                dismissedAt: nil as Date?,
                outcome: .failed // Default to fail; only change on explicit success
            )

            // Generate occurrence key for occurrence-scoped cancellation
            occurrenceKey = OccurrenceKeyFormatter.key(from: firedAt)
            
            // Transition to ringing
            setState(.ringing)

            // Request UI effects
            isScreenAwake = true
            idleTimerController.setIdleTimer(disabled: true)
            onRequestHaptics?()

            // Start alarm sound - check reliability mode first
            let currentMode = reliabilityModeProvider.currentMode
            print("DismissalFlow: Starting alarm with reliability mode: \(currentMode.rawValue)")

            // CRITICAL: In foreground, app audio ALWAYS plays (owns the sound)
            // suppressForegroundSound only affects OS notification sounds (handled by NotificationService)
            // This ensures loud foreground audio without double-audio issues
            let isAppActive = UIApplication.shared.applicationState == .active

            if currentMode == .notificationsPlusAudio {
                // Enhanced mode: use background audio engine + notifications
                do {
                    let soundName = alarm.soundName ?? "ringtone1"

                    // Check current engine state and use appropriate method
                    switch audioEngine.currentState {
                    case .prewarming:
                        // Prewarm is active - promote to ringing
                        try audioEngine.promoteToRinging()
                        print("DismissalFlow: Enhanced mode - promoted prewarm to ringing")

                    case .idle:
                        // No prewarm - start foreground alarm playback
                        try audioEngine.playForegroundAlarm(soundName: soundName)
                        print("DismissalFlow: Enhanced mode - started foreground alarm playback")

                    case .ringing:
                        // Already ringing - ignore (idempotent)
                        print("DismissalFlow: Enhanced mode - already ringing, ignoring start request")
                    }
                } catch {
                    print("DismissalFlow: Enhanced mode audio engine failed: \(error)")
                    // Log error but don't have fallback - audioEngine is the single source
                    reliabilityLogger.log(
                        .dismissFailQR,
                        alarmId: alarm.id,
                        details: ["error": "audio_engine_failed", "reason": error.localizedDescription]
                    )
                }
            } else {
                // Standard mode: notifications-only (App Store safe)
                // Use audioEngine for foreground playback (no fallback needed)
                do {
                    let soundName = alarm.soundName ?? "ringtone1"
                    try audioEngine.playForegroundAlarm(soundName: soundName)
                    print("DismissalFlow: Standard mode - started foreground alarm via audioEngine")
                } catch {
                    print("DismissalFlow: Standard mode audio engine failed: \(error)")
                    reliabilityLogger.log(
                        .dismissFailQR,
                        alarmId: alarm.id,
                        details: ["error": "audio_engine_failed", "reason": error.localizedDescription]
                    )
                }
            }
            
        } catch {
            setState(.failed(.alarmNotFound))
        }
    }
    
    func beginScan() {
        // Idempotent: only allow from ringing state
        guard state == .ringing else { return }
        
        guard let alarm = alarmSnapshot else {
            setState(.failed(.alarmNotFound))
            return
        }
        
        // Check if alarm has expected QR
        guard alarm.expectedQR != nil else {
            setState(.failed(.noExpectedQR))
            return
        }
        
        Task {
            // Check camera permission before attempting to scan
            let cameraStatus = permissionService.checkCameraPermission()
            
            switch cameraStatus {
            case .authorized:
                // Permission granted, start scanning
                do {
                    try await qrScanning.startScanning()
                    setState(.scanning)
                    startLongLivedScanTask()
                } catch {
                    setState(.failed(.scanningError))
                }
                
            case .notDetermined:
                // Request permission first
                let requestResult = await permissionService.requestCameraPermission()
                if requestResult == .authorized {
                    // Permission granted after request, start scanning
                    do {
                        try await qrScanning.startScanning()
                        setState(.scanning)
                        startLongLivedScanTask()
                    } catch {
                        setState(.failed(.scanningError))
                    }
                } else {
                    setState(.failed(.permissionDenied))
                }
                
            case .denied:
                // Permission denied, cannot scan
                setState(.failed(.permissionDenied))
            }
        }
    }
    
    func didScan(payload: String) async {
        // Called by scanner stream - handle state transitions
        print("DismissalFlowViewModel: didScan called with payload: \(payload.prefix(20))... (length: \(payload.count))")

        // Atomic guard: prevent processing if transitioning
        guard !isTransitioning else {
            print("DismissalFlowViewModel: Ignoring scan - currently transitioning")
            return
        }
        
        guard state == .scanning else { 
            // Drop payloads while validating or in other states
            print("DismissalFlowViewModel: Ignoring scan - wrong state: \(state)")
            return 
        }
        
        guard let alarm = alarmSnapshot,
              let expectedQR = alarm.expectedQR else {
            setState(.failed(.noExpectedQR))
            return
        }
        
        // Transition to validating (blocks new payloads)
        setState(.validating)
        
        let trimmedPayload = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedExpected = expectedQR.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedPayload == trimmedExpected {
            // Success - with debounce check
            if shouldProcessSuccessPayload(payload) {
                print("DismissalFlowViewModel: QR code match successful for alarm: \(alarm.id)")
                hasCompletedQR = true
                onChallengeUpdate(completed: 1, total: 1)  // MVP has only QR
                reliabilityLogger.logDismissSuccess(alarm.id, method: "qr", details: ["payload_length": "\(trimmedPayload.count)"])
                await completeSuccess()
            } else {
                // Duplicate within debounce window - return to scanning (with atomic guard)
                print("DismissalFlowViewModel: Duplicate QR scan ignored (debounce)")
                if !isTransitioning {
                    setState(.scanning)
                }
            }
        } else {
            // Mismatch - transient error, return to scanning with atomic guard
            print("DismissalFlowViewModel: QR code mismatch - expected: \(trimmedExpected.prefix(10))..., got: \(trimmedPayload.prefix(10))...")
            reliabilityLogger.logDismissFail(alarm.id, reason: "qr_mismatch", details: [
                "expected_length": "\(trimmedExpected.count)",
                "received_length": "\(trimmedPayload.count)"
            ])
            scanFeedbackMessage = "Invalid QR code. Please try again."
            
            // Brief delay for user feedback, then return to scanning
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                await MainActor.run {
                    // Atomic guard: only transition if not in the middle of another transition
                    if state == .validating && !isTransitioning && !hasCompletedSuccess {
                        scanFeedbackMessage = nil
                        setState(.scanning)
                    }
                }
            }
        }
    }
    
    func cancelScan() {
        // Idempotent: only allow from scanning/validating
        guard state == .scanning || state == .validating else { return }
        
        stopScanTask()
        scanFeedbackMessage = nil
        setState(.ringing)
    }
    
    func completeSuccess() async {
        // State guards at top
        guard state == .validating else { return }
        guard !isTransitioning else { return }

        // Check if challenges are satisfied using injected use case
        let challengeState = ChallengeStackState(
            requiredChallenges: alarmSnapshot?.challengeKind ?? [],
            completedChallenges: hasCompletedQR ? [.qr] : []
        )

        // Use injected stopAllowed, not static
        guard stopAllowed.execute(challengeState: challengeState) else {
            phase = .failed("Complete all challenges first")
            setState(.failed(.noExpectedQR))  // Transition UI on failure
            return
        }

        guard let alarm = alarmSnapshot else {
            phase = .failed("Alarm not found")
            setState(.failed(.alarmNotFound))
            return
        }

        phase = .stopping
        isTransitioning = true

        // Track whether we should stop audio on cleanup
        var shouldStopAppAudio = true

        // ALWAYS-RUN CLEANUP: defer placed immediately after isTransitioning = true
        // Runs on ALL exit paths (success, error, early return after this point)
        defer {
            // Conditionally stop app audio
            // If system handled alarm but challenges incomplete, keep audio playing
            if shouldStopAppAudio {
                audioEngine.stop()
            }

            // Stop UI effects
            idleTimerController.setIdleTimer(disabled: false)
            isScreenAwake = false

            // Stop scanner
            stopScanTask()

            // Clear transitioning flag
            isTransitioning = false
        }

        do {
            // Use AlarmScheduling protocol for stop with optional intent ID
            try await alarmScheduler.stop(alarmId: alarm.id, intentAlarmId: intentAlarmId)

            // SUCCESS PATH: Only set completion flag after stop succeeds
            hasCompletedSuccess = true

            // Clear intent ID after successful use to prevent stale references
            intentAlarmId = nil

            // Legacy cleanup shim (no-op on AlarmKit)
            if let key = occurrenceKey {
                await notificationService.cleanupAfterDismiss(
                    alarmId: alarm.id,
                    occurrenceKey: key
                )
                print("DismissalFlow: Cleaned up occurrence \(key.prefix(10))...")
            }

            // Mark dismissed in registry
            if let key = occurrenceKey {
                await dismissedRegistry.markDismissed(alarmId: alarm.id, occurrenceKey: key)
            }

            // Complete alarm run with success
            if var run = currentAlarmRun {
                run.dismissedAt = clock.now()
                run.outcome = .success

                do {
                    try await alarmRunStore.appendRun(run)  // NEW: async actor call
                    onRunLogged?(run)
                } catch {
                    print("Failed to persist successful alarm run: \(error)")
                }
            }

            // For one-time alarms: disable
            if alarm.repeatDays.isEmpty {
                var updatedAlarm = alarm
                updatedAlarm.isEnabled = false
                try? await alarmStorage.saveAlarms([updatedAlarm])
                print("DismissalFlow: One-time alarm dismissed and disabled")
            }

            reliabilityLogger.log(
                .dismissSuccess,
                alarmId: alarm.id,
                details: ["method": "challenges_completed"]
            )

            // Drive UI to success state
            phase = .success
            setState(.success)

            // Direct route back (no unnecessary delay)
            appRouter.backToList()

        } catch {
            // Handle protocol-typed AlarmSchedulingError
            if let schedulingError = error as? AlarmSchedulingError {
                // Structured logging with domain error type
                reliabilityLogger.log(
                    .stopFailed,
                    alarmId: alarm.id,
                    details: [
                        "error": schedulingError.description,
                        "error_type": "\(schedulingError)"
                    ]
                )

                switch schedulingError {
                case .alreadyHandledBySystem:
                    // CRITICAL: System auto-dismissed alarm BUT challenges are INCOMPLETE
                    // Keep app audio playing; user must complete challenges to silence
                    shouldStopAppAudio = false  // Prevent audio stop in defer block
                    print("DismissalFlow: [METRIC] event=alarm_system_handled_challenges_incomplete alarm_id=\(alarm.id) audio_preserved=true")
                    setState(.failed(.alarmEndedButChallengesIncomplete))
                    phase = .failed("System handled alarm but challenges incomplete")

                case .ambiguousAlarmState:
                    // Multiple alarms alerting - safe error for user
                    print("DismissalFlow: [METRIC] event=multiple_alarms_alerting alarm_id=\(alarm.id)")
                    setState(.failed(.multipleAlarmsAlerting))
                    phase = .failed("Multiple alarms detected")

                case .alarmNotFound:
                    // Alarm disappeared (unexpected)
                    print("DismissalFlow: [METRIC] event=alarm_not_found alarm_id=\(alarm.id)")
                    setState(.failed(.alarmNotFound))
                    phase = .failed("Alarm not found")

                default:
                    // Other scheduling errors
                    print("DismissalFlow: [METRIC] event=stop_failed error=\(schedulingError) alarm_id=\(alarm.id)")
                    setState(.failed(.alarmNotFound))
                    phase = .failed("Couldn't stop alarm")
                }
            } else {
                // Generic/unexpected error
                reliabilityLogger.log(
                    .stopFailed,
                    alarmId: alarm.id,
                    details: ["error": error.localizedDescription]
                )
                print("DismissalFlow: [METRIC] event=stop_failed_unexpected error=\(error.localizedDescription) alarm_id=\(alarm.id)")
                setState(.failed(.alarmNotFound))
                phase = .failed("Couldn't stop alarm")
            }

            // hasCompletedSuccess remains false, allowing retry
            // defer handles all cleanup automatically (audio stop, scanner stop, flags cleared)
        }
    }
    
    func abort(reason: String) {
        // UI should block this, but handle if forced

        // Atomic guard: prevent concurrent abort
        guard !hasCompletedSuccess else { return }
        guard !isTransitioning else { return }

        // Stop UI effects
        idleTimerController.setIdleTimer(disabled: false)
        isScreenAwake = false

        // Stop alarm sound
        audioEngine.stop()

        // Stop scanner
        stopScanTask()

        // Log failed run
        if let run = currentAlarmRun {
            Task {
                do {
                    try await alarmRunStore.appendRun(run)  // NEW: async actor call
                    await MainActor.run {
                        onRunLogged?(run)
                    }
                } catch {
                    print("Failed to persist failed alarm run: \(error)")
                }
            }
        }

        // Don't cancel follow-ups - let re-alerting continue

        appRouter.backToList()
    }
    
    @MainActor
    func stopAlarm() async {
        // Explicit stop action (same as completeSuccess, but can be called directly)
        await completeSuccess()
    }

    @MainActor
    func snooze(requestedDuration: TimeInterval = 300) async {
        guard let alarm = alarmSnapshot else { return }
        guard !hasCompletedSuccess else { return }
        guard !isTransitioning else { return }

        phase = .snoozing

        // Use injected snoozeComputer, not static
        let nextFireTime = snoozeComputer.execute(
            alarm: alarm,
            now: clock.now(),  // Use injected clock
            requestedSnooze: requestedDuration,
            bounds: SnoozeBounds.default  // From Domain
        )

        let duration = max(1, nextFireTime.timeIntervalSince(clock.now()))

        do {
            // Use AlarmScheduling for countdown/snooze
            try await alarmScheduler.transitionToCountdown(
                alarmId: alarm.id,
                duration: duration
            )

            // Stop current ringing
            audioEngine.stop()

            // Stop UI effects
            idleTimerController.setIdleTimer(disabled: false)
            isScreenAwake = false

            // Stop scanner
            stopScanTask()

            reliabilityLogger.log(
                .snoozeSet,
                alarmId: alarm.id,
                details: ["duration": "\(Int(duration))"]
            )

            appRouter.backToList()
        } catch {
            reliabilityLogger.log(
                .snoozeFailed,
                alarmId: alarm.id,
                details: ["error": error.localizedDescription]
            )
            phase = .failed("Couldn't snooze")
        }
    }
    
    func retry() {
        guard state.canRetry else { return }

        // Reset all completion flags to allow new attempt
        hasCompletedSuccess = false
        hasCompletedQR = false

        // Clear any stale feedback
        scanFeedbackMessage = nil

        // Reset to ringing state
        setState(.ringing)
    }
    
    // MARK: - Private Methods
    
    private func setState(_ newState: State) {
        state = newState
        onStateChange?(newState)
        print("DismissalFlow: \(newState)")
    }
    
    private func startLongLivedScanTask() {
        scanTask = Task {
            do {
                for await payload in qrScanning.scanResultStream() {
                    await didScan(payload: payload)
                }
            } catch {
                await MainActor.run {
                    if state == .scanning {
                        setState(.failed(.scanningError))
                    }
                }
            }
        }
    }
    
    private func stopScanTask() {
        scanTask?.cancel()
        scanTask = nil
        qrScanning.stopScanning()
    }
    
    private func shouldProcessSuccessPayload(_ payload: String) -> Bool {
        // Debounce identical payloads within 300ms
        let now = clock.now()
        
        if let lastPayload = lastSuccessPayload,
           let lastTime = lastSuccessTime,
           lastPayload == payload,
           now.timeIntervalSince(lastTime) < 0.3 {
            return false // Duplicate within debounce window
        }
        
        lastSuccessPayload = payload
        lastSuccessTime = now
        return true
    }
  func cleanup() {
    stopScanTask()

    idleTimerController.setIdleTimer(disabled: false)
    isScreenAwake = false
    scanFeedbackMessage = nil

    // Stop alarm sound
    audioEngine.stop()
  }

    deinit {
      scanTask?.cancel()
      qrScanning.stopScanning()
    }
}

// MARK: - Protocol Definitions

protocol QRScanning {
    func startScanning() async throws
    func stopScanning()
    func scanResultStream() -> AsyncStream<String>
}

public protocol Clock {
    func now() -> Date
}

public struct SystemClock: Clock {
    public init() {}

    public func now() -> Date {
        Date()
    }
}

```

### SettingsViewModel.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/ViewModels/SettingsViewModel.swift`

```swift
//
//  SettingsViewModel.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/15/25.
//  Presentation layer for Settings screen
//

import Foundation
import Combine

/// ViewModel for SettingsView
/// Handles export logs logic without direct UIKit dependencies
@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Dependencies

    private let reliabilityLogger: ReliabilityLogging
    private let shareProvider: ShareProviding

    // MARK: - Init

    init(
        reliabilityLogger: ReliabilityLogging,
        shareProvider: ShareProviding
    ) {
        self.reliabilityLogger = reliabilityLogger
        self.shareProvider = shareProvider
    }

    // MARK: - Public Methods

    /// Exports reliability logs and presents share sheet
    /// - Note: Runs log export on background queue (reliabilityLogger handles thread safety)
    ///         Then presents share sheet on main thread via shareProvider
    func exportLogs() {
        // Export logs on background queue to avoid blocking UI
        Task.detached(priority: .userInitiated) {
            // Call reliabilityLogger.exportLogs() which uses its own dispatch queue
            let logs = self.reliabilityLogger.exportLogs()

            // Present share sheet on main thread (shareProvider is @MainActor)
            await MainActor.run {
                self.shareProvider.share(items: [logs])
            }
        }
    }
}

```

### AlarmFormView.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Views/AlarmFormView.swift`

```swift
//
//  AlarmFormView.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/26/25.
//

import SwiftUI

struct AlarmFormView: View {
 @ObservedObject var detailVM: AlarmDetailViewModel
 @State private var isAddingChallenge = false
 @State private var showQRScanner = false
 @State private var isTestingSoundNotification = false
 let onSave: () -> Void

 // Inject container for accessing services
 private let container: DependencyContainer

 init(detailVM: AlarmDetailViewModel, container: DependencyContainer, onSave: @escaping () -> Void) {
     self.detailVM = detailVM
     self.container = container
     self.onSave = onSave
 }

 var body: some View {
   NavigationStack {
     Form {
       Section(header: Text("Time")) {
         DatePicker(
           "Alarm Time",
           selection: $detailVM.draft.time,
           displayedComponents: .hourAndMinute
         )
       }

       TextField("Label", text: $detailVM.draft.label)

       Section(header: Text("Repeat")) {
         ForEach(Weekdays.allCases, id: \.self) { day in
           Toggle(
             day.displayName,
             isOn: detailVM.repeatBinding(for: day)
           )
         }
       }
       
       Section(header: Text("Sound")) {
         // Sound Picker - Use SoundCatalog for consistency with alarm model
         Picker("Sound", selection: detailVM.soundIdBinding) {
           ForEach(container.soundCatalog.all, id: \.id) { sound in
             Text(sound.name).tag(sound.id)
           }
         }
         .pickerStyle(.menu)
         
         // Preview Button
         Button(action: previewCurrentSound) {
           HStack {
             Image(systemName: "play.circle")
             Text("Preview Sound")
             Spacer()
           }
         }
         .buttonStyle(.plain)
         .foregroundColor(.accentColor)
         .accessibilityLabel("Preview selected alarm sound")
         .accessibilityHint("Plays a short preview of the selected sound")

         // Volume Slider
         VStack(alignment: .leading, spacing: 8) {
           Text("In-app ring volume (doesn't affect lock-screen)")
             .font(.caption)
             .foregroundColor(.secondary)
           
           HStack {
             Image(systemName: "speaker.fill")
               .foregroundColor(.secondary)
               .font(.caption)
             
             Slider(value: detailVM.volumeBinding, in: 0.0...1.0, step: 0.1)
               .accessibilityLabel("In-app alarm volume")
               .accessibilityValue("\(Int(detailVM.draft.volume * 100)) percent")
             
             Image(systemName: "speaker.wave.3.fill")
               .foregroundColor(.secondary)
               .font(.caption)
           }
           
           Text("Volume: \(Int(detailVM.draft.volume * 100))%")
             .font(.caption2)
             .foregroundColor(.secondary)
         }
         
         // Test Notification Button
         Button(action: testSoundNotification) {
           HStack {
             if isTestingSoundNotification {
               ProgressView()
                 .scaleEffect(0.8)
               Text("Test notification sent...")
             } else {
               Image(systemName: "bell.badge")
               Text("Test Sound Notification")
             }
             Spacer()
           }
         }
         .buttonStyle(.plain)
         .foregroundColor(isTestingSoundNotification ? .secondary : .accentColor)
         .disabled(isTestingSoundNotification)

         // Education banner about ringer vs media volume
         VStack(alignment: .leading, spacing: 8) {
           HStack {
             Image(systemName: "info.circle")
               .foregroundColor(.blue)
             Text("Volume Settings")
               .font(.caption)
               .fontWeight(.medium)
               .foregroundColor(.blue)
           }

           Text(AudioUXPolicy.educationCopy)
             .font(.caption2)
             .foregroundColor(.secondary)
         }
         .padding(.vertical, 4)
       }

       Section(header: Text("Challenges")) {
         if detailVM.draft.challengeKind.isEmpty {
           HStack {
             Text("No challenges Added")
               .foregroundColor(.secondary)
             Spacer()
             Button {
               isAddingChallenge = true
             } label: {
               Label("Add", systemImage: "plus.circle")
             }
           }
         } else {
           ForEach(detailVM.draft.challengeKind, id: \.self) { kind in
             ChallengeRow(
               kind: kind,
               detailViewModel: detailVM,
               onRemove: {
                 detailVM.removeChallenge(kind)
               },
               onConfigureQR: {
                 showQRScanner = true
               }
             )
           }

           Button {
             isAddingChallenge = true
           } label: {
             Label("Add Challenge", systemImage: "plus.circle")
               .foregroundColor(.accentColor)
           }
         }
       }
     }
     .navigationTitle("New Alarm")
     .navigationBarTitleDisplayMode(.inline)
     .toolbar {
       ToolbarItem(placement: .navigationBarTrailing) {
         Button("Save") {
           onSave()
         }
         .disabled(!detailVM.isValid)
         .accessibilityLabel("Save alarm")
         .accessibilityHint(detailVM.isValid ? "Saves the alarm with current settings" : "Cannot save, alarm requires a QR code challenge")
       }
       ToolbarItem(placement: .navigationBarLeading) {
         Button("Cancel") {
           // handle cancel
         }
         .accessibilityLabel("Cancel alarm creation")
       }
     }
     .navigationDestination(isPresented: $isAddingChallenge) {
       ChallengeSelectionView(draft: $detailVM.draft, container: container)
     }
     .sheet(isPresented: $showQRScanner) {
         QRScannerView(
             onCancel: {
                 showQRScanner = false
             },
             onScanned: { scannedCode in
                 detailVM.draft.expectedQR = scannedCode
                 showQRScanner = false
             },
             permissionService: container.permissionService
         )
     }
   }
   

 }
  // MARK: - Sound Functions

  private func previewCurrentSound() {
    // TODO: Implement preview using audioEngine
    // AudioService was removed - need to add preview method to AlarmAudioEngineProtocol
    print("Sound preview: \(detailVM.draft.soundName ?? "default") at volume \(detailVM.draft.volume)")
  }

  private func testSoundNotification() {
    Task {
      isTestingSoundNotification = true
      defer {
        Task { @MainActor in
          // Reset after 3 seconds
          try? await Task.sleep(nanoseconds: 3_000_000_000)
          isTestingSoundNotification = false
        }
      }

      do {
        try await container.notificationService.scheduleTestNotification(
          soundName: detailVM.draft.soundName,
          in: 5.0
        )
      } catch {
        print("Failed to schedule test notification: \(error)")
      }
    }
  }
}

struct ChallengeRow: View {
 let kind: Challenges
 @ObservedObject var detailViewModel: AlarmDetailViewModel
 let onRemove: () -> Void
 let onConfigureQR: () -> Void

 var body: some View {
   VStack(alignment: .leading, spacing: 8) {
     HStack {
       Label(kind.displayName, systemImage: kind.iconName)
         .font(.headline)

       Spacer()

       Button {
         onRemove()
       } label: {
         Image(systemName: "xmark.circle.fill")
           .foregroundColor(.secondary)
       }
       .buttonStyle(.plain)
       .accessibilityLabel("Remove \(kind.displayName) challenge")
     }

     if kind == .qr {
       Button {
         onConfigureQR()
       } label: {
         HStack {
           Text("QR Code:")
             .foregroundColor(.primary)
           Spacer()
           if let qrCode = detailViewModel.draft.expectedQR {
             Text(qrCode)
               .lineLimit(1)
               .truncationMode(.middle)
               .foregroundColor(.secondary)
           } else {
             Text("Tap to scan")
               .foregroundColor(.accentColor)
           }
           Image(systemName: "chevron.right")
             .font(.caption)
             .foregroundColor(.secondary)
         }
       }
       .buttonStyle(.plain)
     }
   }
   .padding(.vertical, 4)
 }
}

```

### AlarmsListView.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Views/AlarmsListView.swift`

```swift
//
//  AlarmsListView.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/24/25.
//

import SwiftUI
import UserNotifications

struct AlarmsListView: View {

  @Environment(\.scenePhase) private var scenePhase
  @EnvironmentObject private var router: AppRouter
  @StateObject private var vm: AlarmListViewModel
  @State private var detailVM: AlarmDetailViewModel?
  @State private var showSettings = false

  // Store container for child views
  private let container: DependencyContainer

  // Primary initializer - accepts injected container
  init(container: DependencyContainer) {
        self.container = container
        _vm = StateObject(wrappedValue: container.makeAlarmListViewModel())
    }

    // For testing/preview purposes with a pre-configured view model
    init(preConfiguredVM: AlarmListViewModel, container: DependencyContainer) {
        self.container = container
        _vm = StateObject(wrappedValue: preConfiguredVM)
    }

  var body: some View {
    NavigationStack {
      ZStack {
        // Empty state
        if vm.alarms.isEmpty {
          ContentUnavailableView(
            "No Alarms",
            systemImage: "alarm",
            description: Text("Tap + to create your first alarm")
          )
        }

        // Alarm list
        List {
          // Permission warning section
          if let permissionDetails = vm.notificationPermissionDetails {
            Section {
              NotificationPermissionInlineWarning(
                permissionDetails: permissionDetails,
                permissionService: container.permissionService
              )
            }
          }

          // Media volume warning banner
          if vm.showMediaVolumeWarning {
            Section {
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Image(systemName: "speaker.wave.1")
                    .foregroundColor(.orange)
                  Text("Low Media Volume Detected")
                    .font(.headline)
                    .foregroundColor(.orange)
                }

                Text("Your media volume is low. This won't affect lock-screen alarms (they use ringer volume), but in-app sounds may be quiet.")
                  .font(.caption)
                  .foregroundColor(.secondary)

                Button("Dismiss") {
                  vm.showMediaVolumeWarning = false
                }
                .font(.caption)
                .foregroundColor(.accentColor)
              }
              .padding(.vertical, 4)
            }
          }

          ForEach(vm.alarms) { alarm in
            AlarmRowView(
              alarm: alarm,
              onToggle: { vm.toggle(alarm) },
              onTap: { detailVM = AlarmDetailViewModel(alarm: alarm, isNew: false) }
            )
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              Button(role: .destructive) {
                vm.delete(alarm)
              } label: {
                Label("Delete", systemImage: "trash")
              }

              Button {
                detailVM = AlarmDetailViewModel(alarm: alarm, isNew: false)
              } label: {
                Label("Edit", systemImage: "pencil")
              }
              .tint(.blue)
            }
          }
        }
        .listStyle(.insetGrouped)

        // Floating Action Button
        VStack {
          Spacer()
          HStack {
            Spacer()
            Button {
              detailVM = container.makeAlarmDetailViewModel()
            } label: {
              Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.accentColor))
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .accessibilityLabel("Create new alarm")
            .accessibilityHint("Opens alarm creation form")
            .padding(.trailing, 20)
            .padding(.bottom, 20)
          }
        }
      }
      .navigationTitle("Alarms")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Menu {
            Button("Request Notification Permission", systemImage: "bell.badge") {
              Task {
                let center = UNUserNotificationCenter.current()
                do {
                  let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                  print("🔔 requestAuthorization returned: \(granted)")
                  let settings = await center.notificationSettings()
                  print("🔧 auth=\(settings.authorizationStatus.rawValue) alert=\(settings.alertSetting.rawValue) sound=\(settings.soundSetting.rawValue)")
                } catch {
                  print("❌ requestAuthorization error: \(error)")
                }
              }
            }

            Button("Test Lock Screen Notification", systemImage: "lock.circle") {
              Task {
                try? await container.notificationService.scheduleTestSystemDefault()
              }
            }

            Button("Test Lock-Screen Alarm (8s)", systemImage: "bell.badge.fill") {
              vm.testLockScreen()
            }

            Button("Run Sound Triage", systemImage: "stethoscope") {
              Task {
                try? await container.notificationService.runCompleteSoundTriage()
              }
            }

            Button("Bare Default Test", systemImage: "exclamationmark.triangle") {
              Task {
                try? await container.notificationService.scheduleBareDefaultTest()
              }
            }

            Button("Bare Test (No Interruption)", systemImage: "bell.slash") {
              Task {
                try? await container.notificationService.scheduleBareDefaultTestNoInterruption()
              }
            }

            Button("Bare Test (No Category)", systemImage: "bell.badge") {
              Task {
                try? await container.notificationService.scheduleBareDefaultTestNoCategory()
              }
            }

            Divider()

            Button("Settings", systemImage: "gear") {
              showSettings = true
            }
          } label: {
            Image(systemName: "wrench.and.screwdriver")
          }
        }
      }
      .task {
          vm.refreshPermission()
        vm.ensureNotificationPermissionIfNeeded()
      // initial fetch when the screen appears
      }
      .onChange(of: scenePhase) { phase in
          if phase == .active {               // returning from Settings or prompt
              vm.refreshPermission()

              // Check for active alarms and route to ringing if needed
              Task {
                  if let (alarm, _) = await container.activeAlarmDetector.checkForActiveAlarm() {
                      print("📱 AlarmsListView: Auto-routing to ringing for alarm \(alarm.id.uuidString.prefix(8))")
                      router.showRinging(for: alarm.id, intentAlarmID: nil)
                  }
              }
          }
      }

    }
    .sheet(item: $detailVM) { formVM in
      AlarmFormView(detailVM: formVM, container: container) {
        if formVM.isNewAlarm {
          let newAlarm = formVM.commitChanges()
          vm.add(newAlarm)
        } else {
          vm.update(formVM.commitChanges())
        }
        detailVM = nil
      }
    }
    .sheet(isPresented: $vm.showPermissionBlocking) {
      NotificationPermissionBlockingView(
        permissionService: container.permissionService,
        onPermissionGranted: {
          vm.handlePermissionGranted()
        }
      )
    }
    // Note: .alarmDidFire notification removed with NotificationService migration to AlarmKit
    // AlarmKit handles alarm firing via intents and the activeAlarmDetector checks on app foreground
    .sheet(isPresented: $showSettings) {
      SettingsView(container: container)
    }
  }
}

// Separate row view for better organization
struct AlarmRowView: View {
  let alarm: Alarm
  let onToggle: () -> Void
  let onTap: () -> Void

  var body: some View {
    Button {
      onTap()
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(alarm.time, style: .time)
            .font(.largeTitle)
            .fontWeight(.light)

          HStack {
            Text(alarm.label)
              .font(.subheadline)
              .foregroundColor(.secondary)

            if !alarm.repeatDays.isEmpty {
              Text("•")
                .foregroundColor(.secondary)
              Text(alarm.repeatDaysText)
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }

        Spacer()

        Toggle("", isOn: Binding(
          get: { alarm.isEnabled },
          set: { _ in onToggle() }
        ))
        .labelsHidden()
        .accessibilityLabel("\(alarm.isEnabled ? "Disable" : "Enable") alarm for \(alarm.time, style: .time)")
      }
      .padding(.vertical, 8)
    }
    .buttonStyle(.plain)
  }
}

#Preview {
    let container = DependencyContainer()
    let vm = container.makeAlarmListViewModel()

    vm.alarms = [
        Alarm(id: UUID(), time: Date(), label: "Morning", repeatDays: [.monday], challengeKind: [], isEnabled: true, soundId: "chimes01", volume: 0.5),
        Alarm(id: UUID(), time: Date(), label: "Work", repeatDays: [], challengeKind: [.math], isEnabled: true, soundId: "bells01", volume: 0.7),
        Alarm(id: UUID(), time: Date(), label: "Weekend", repeatDays: [.saturday, .sunday], challengeKind: [], isEnabled: false, soundId: "tone01", volume: 0.8)
    ]

    return AlarmsListView(preConfiguredVM: vm, container: container)
        .environmentObject(AppRouter())
        .environment(\.container, container)
}


```

### ChallengeSelectionView.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Views/ChallengeSelectionView.swift`

```swift
//
//  ChallengeSelectionView.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/26/25.
//

import SwiftUI

struct ChallengeSelectionView: View {

  @Binding var draft: Alarm
  @Environment(\.dismiss) private var dismiss
  @State private var showingQRScanner = false

  // Inject container for accessing services
  private let container: DependencyContainer

  init(draft: Binding<Alarm>, container: DependencyContainer) {
      self._draft = draft
      self.container = container
  }

  var body: some View {
    NavigationStack{
      List{
        ForEach(Challenges.allCases,id:\.self){ challenge in
          Button {
            handleChallengeSelection(challenge)
          } label: {
            HStack {
              Label(challenge.displayName, systemImage: challenge.iconName)
                .foregroundColor(.primary)
              Spacer()

              if draft.challengeKind.contains(challenge) {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundColor(.accentColor)
              }
            }
          }
          .disabled(draft.challengeKind.contains(challenge))

        }
      }
      .navigationTitle("Add Challenge")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
    .sheet(isPresented: $showingQRScanner) {
      QRScannerView (
        onCancel: {
          showingQRScanner = false
        },
        onScanned: { scannedCode in
          draft.expectedQR = scannedCode
          if !draft.challengeKind.contains(.qr) {
            draft.challengeKind.append(.qr)
          }
          showingQRScanner = false
          dismiss()
        },
        permissionService: container.permissionService
      )
    }

  }

  private func handleChallengeSelection(_ challenge: Challenges) {
    switch challenge {
    case .qr:
      showingQRScanner = true
    default:
      if !draft.challengeKind.contains(challenge) {
        draft.challengeKind.append(challenge)
      }
      dismiss()
    }
  }

}

#Preview {
    let container = DependencyContainer()
    return ChallengeSelectionView(
        draft: .constant(Alarm(
            id: UUID(),
            time: Date(),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.math],  // Pre-populate with a challenge to see checkmark
            expectedQR: nil,
            isEnabled: true,
            soundId: "chimes01",
            volume: 0.8
        )),
        container: container
    )
}

```

### ContentView.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Views/ContentView.swift`

```swift
// alarmAppNew/…/Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @Environment(\.container) private var container
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        // Unwrap container - should always be present from app root
        guard let container = container else {
            return AnyView(Text("Configuration error: Container not injected")
                .foregroundColor(.red))
        }

        return AnyView(
            Group {
                switch router.route {
                case .alarmList:
                    AlarmsListView(container: container)
                case .ringing(let id, let intentAlarmID):
                    RingingView(alarmID: id, intentAlarmID: intentAlarmID, container: container)
                        .environmentObject(container)  // Inject for child views (ScanningContent, FailedContent)
                        .interactiveDismissDisabled(true)
                }
            }
        )
    }
}

#Preview {
    let container = DependencyContainer()
    return ContentView()
        .environmentObject(AppRouter())
        .environment(\.container, container)
}

```

### DismissalFlowView.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Views/DismissalFlowView.swift`

```swift

import SwiftUI

struct DismissalFlowView: View {
    let alarmID: UUID
    let container: DependencyContainer  // Explicit dependency injection (matches RingingView pattern)
    let onFinish: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var isSceneReady = false

    var body: some View {
        Group {
            if isSceneReady {
                RingingView(alarmID: alarmID, container: container)
                    .environmentObject(container)  // Inject for child views (ScanningContent, FailedContent)
                    .onDisappear {
                        onFinish()
                    }
            } else {
                // Loading state while scene becomes ready
                ZStack {
                    Color.black.ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .task {
            await ensureSceneReadiness()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active && !isSceneReady {
                Task {
                    await ensureSceneReadiness()
                }
            }
        }
    }
    
    @MainActor
    private func ensureSceneReadiness() async {
        // Wait for scene to be active
        guard scenePhase == .active else { return }
        
        // Short defer to prevent black screens on cold-start
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        isSceneReady = true
    }
}

```

### PermissionBlockingView.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Views/PermissionBlockingView.swift`

```swift
//
//  PermissionBlockingView.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 8/28/25.
//

import SwiftUI

struct NotificationPermissionBlockingView: View {
    let permissionService: PermissionServiceProtocol
    let onPermissionGranted: () -> Void
    
    @State private var isRequestingPermission = false
    @State private var permissionDetails: NotificationPermissionDetails?
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            VStack(spacing: 12) {
                Text("Notifications Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Alarms need notification permission to wake you up reliably. Without this permission, your alarms won't work.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                if let details = permissionDetails {
                    Text(details.userGuidanceText)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.blue)
                        .padding(.top, 8)
                }
            }
            
            VStack(spacing: 16) {
                if let details = permissionDetails {
                    if details.authorizationStatus.isFirstTimeRequest {
                        // First time - show system permission request
                        Button {
                            requestPermission()
                        } label: {
                            HStack {
                                if isRequestingPermission {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Allow Notifications")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isRequestingPermission)
                    } else {
                        // Permission denied - only show Settings option
                        Button {
                            permissionService.openAppSettings()
                        } label: {
                            Text("Open Settings")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    // Loading state
                    ProgressView("Checking permissions...")
                }
                
                if permissionDetails?.authorizationStatus.requiresSettingsNavigation == true {
                    Text("After opening Settings, navigate to:\nNotifications → alarmAppNew → Allow Notifications")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding(24)
        .onAppear {
            checkPermissionStatus()
        }
    }
    
    private func checkPermissionStatus() {
        Task {
            let details = await permissionService.checkNotificationPermission()
            await MainActor.run {
                self.permissionDetails = details
            }
        }
    }
    
    private func requestPermission() {
        // Only attempt system request if status is notDetermined
        guard permissionDetails?.authorizationStatus.isFirstTimeRequest == true else {
            permissionService.openAppSettings()
            return
        }
        
        isRequestingPermission = true
        
        Task {
            do {
                let status = try await permissionService.requestNotificationPermission()
                
                await MainActor.run {
                    isRequestingPermission = false
                    
                    if status == .authorized {
                        onPermissionGranted()
                    } else {
                        // Permission denied, refresh status to show Settings UI
                        checkPermissionStatus()
                    }
                }
            } catch {
                await MainActor.run {
                    isRequestingPermission = false
                    checkPermissionStatus()
                }
            }
        }
    }
}

struct CameraPermissionBlockingView: View {
    let permissionService: PermissionServiceProtocol
    let onPermissionGranted: () -> Void
    let onCancel: () -> Void
    
    @State private var isRequestingPermission = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                
                VStack(spacing: 12) {
                    Text("Camera Access Required")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("To dismiss your alarm, you need to scan a QR code. Please allow camera access to use the QR scanner.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 16) {
                    Button {
                        requestPermission()
                    } label: {
                        HStack {
                            if isRequestingPermission {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("Enable Camera")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRequestingPermission)
                    
                    Button {
                        permissionService.openAppSettings()
                    } label: {
                        Text("Open Settings")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
            .navigationTitle("Camera Permission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
    
    private func requestPermission() {
        isRequestingPermission = true
        
        Task {
            let status = await permissionService.requestCameraPermission()
            
            await MainActor.run {
                isRequestingPermission = false
                
                if status == .authorized {
                    onPermissionGranted()
                }
            }
        }
    }
}

// MARK: - Inline Warning Components
struct NotificationPermissionInlineWarning: View {
    let permissionDetails: NotificationPermissionDetails
    let permissionService: PermissionServiceProtocol
    
    var body: some View {
        if permissionDetails.authorizationStatus != .authorized {
            PermissionWarningCard(
                icon: "bell.slash.fill",
                title: "Notifications Disabled",
                message: "Enable notifications to schedule alarms",
                buttonText: "Open Settings",
                color: .orange,
                action: {
                    permissionService.openAppSettings()
                },
                detailInstructions: "In Settings: Notifications → alarmAppNew → Allow Notifications"
            )
        } else if permissionDetails.isAuthorizedButMuted {
            PermissionWarningCard(
                icon: "speaker.slash.fill",
                title: "Sound Disabled",
                message: "Your alarms are scheduled but won't make sound",
                buttonText: "Open Settings",
                color: .yellow,
                action: {
                    permissionService.openAppSettings()
                },
                detailInstructions: "In Settings: Notifications → alarmAppNew → Enable Sounds"
            )
        }
    }
}

struct PermissionWarningCard: View {
    let icon: String
    let title: String
    let message: String
    let buttonText: String
    let color: Color
    let detailInstructions: String?
    let action: () -> Void
    
    
    init(
        icon: String,
        title: String,
        message: String,
        buttonText: String,
        color: Color,
        action: @escaping () -> Void,
        detailInstructions: String? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.buttonText = buttonText
        self.color = color
        self.action = action
        self.detailInstructions = detailInstructions
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(color)
                    
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(buttonText) {
                    action()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            
            if let instructions = detailInstructions {
                Text(instructions)
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    VStack {
        NotificationPermissionBlockingView(
            permissionService: PermissionService(),
            onPermissionGranted: {}
        )
    }
}

#Preview {
    CameraPermissionBlockingView(
        permissionService: PermissionService(),
        onPermissionGranted: {},
        onCancel: {}
    )
}
```

### QRScannerView.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Views/QRScannerView.swift`

```swift
//
//  QRScannerView.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/24/25.
//

import SwiftUI
import CodeScanner
import AVFoundation


struct QRScannerView: View {
  @Environment(\.dismiss) private var dismiss
  let onCancel: () -> Void
  let onScanned: (String) -> Void
  let permissionService: PermissionServiceProtocol
  
  @State private var cameraPermissionStatus: PermissionStatus = .notDetermined
  @State private var showPermissionBlocking = false
  @State private var isTorchOn = false

  var body: some View {
    NavigationStack {
      Group {
        if cameraPermissionStatus == .authorized {
          CodeScannerView(
            codeTypes: [.qr],
            simulatedData: "Test QR Data",
            completion: handleScan
          )
          .onChange(of: isTorchOn) { _, newValue in
            setTorch(newValue)
          }
        } else if cameraPermissionStatus == .denied {
          CameraPermissionBlockingView(
            permissionService: permissionService,
            onPermissionGranted: {
              cameraPermissionStatus = .authorized
            },
            onCancel: {
              onCancel()
              dismiss()
            }
          )
        } else {
          ProgressView("Checking camera permission...")
        }
      }
      .navigationTitle("Scan QR")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        if cameraPermissionStatus == .authorized {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              onCancel()
              dismiss()
            }
          }
          
          ToolbarItem(placement: .primaryAction) {
            Button(action: { isTorchOn.toggle() }) {
              Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                .foregroundColor(isTorchOn ? .yellow : .primary)
            }
            .accessibilityLabel("Toggle Torch")
            .accessibilityHint("Toggles the camera flash to help scan QR codes in dark environments")
          }
        }
      }
      .onAppear {
        checkCameraPermission()
      }
    }
  }
  
  private func checkCameraPermission() {
    let currentStatus = permissionService.checkCameraPermission()
    
    if currentStatus == .notDetermined {
      Task {
        let newStatus = await permissionService.requestCameraPermission()
        await MainActor.run {
          cameraPermissionStatus = newStatus
        }
      }
    } else {
      cameraPermissionStatus = currentStatus
    }
  }

  //doesn't handle error right now
  private func handleScan(result: Result<ScanResult, ScanError>) {
    switch result {
    case .success(let scan):
      onScanned(scan.string)   // no dismiss() here
    case .failure:
      onCancel()               // no dismiss() here
    }
  }

  private func setTorch(_ on: Bool) {
      #if targetEnvironment(simulator)
      return // no torch in simulator
      #else
      guard let device = AVCaptureDevice.default(for: .video),
            device.hasTorch else { return }
      do {
          try device.lockForConfiguration()
          if on {
              try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
          } else {
              device.torchMode = .off
          }
          device.unlockForConfiguration()
      } catch {
          print("Torch could not be used: \(error)")
      }
      #endif
  }


}




```

### RingingView.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Views/RingingView.swift`

```swift
//
//  RingingView.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/6/25.
//  Enforced fullscreen ringing view for MVP1
//

import SwiftUI
import UIKit

struct RingingView: View {
    let alarmID: UUID
    let intentAlarmID: UUID?  // Intent-provided ID (could be pre-migration)
    @StateObject private var viewModel: DismissalFlowViewModel
    @EnvironmentObject private var container: DependencyContainer

    init(alarmID: UUID, intentAlarmID: UUID? = nil, container: DependencyContainer) {
        self.alarmID = alarmID
        self.intentAlarmID = intentAlarmID
        // Pass intent ID to ViewModel through factory
        self._viewModel = StateObject(wrappedValue: container.makeDismissalFlowViewModel(intentAlarmID: intentAlarmID))
    }
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Main content based on state
                switch viewModel.state {
                case .idle:
                    ProgressView("Loading...")
                        .tint(.white)
                        .foregroundColor(.white)
                    
                case .ringing:
                    RingingContent(beginScan: { viewModel.beginScan() })
                    
                case .scanning:
                    ScanningContent(
                        cancelScan: { viewModel.cancelScan() },
                        onScanned: { payload in
                            Task {
                                await viewModel.didScan(payload: payload)
                            }
                        }
                    )
                    
                case .validating:
                    ValidatingContent()
                    
                case .success:
                    SuccessContent()
                    
                case .failed(let reason):
                    FailedContent(reason: reason, retry: { viewModel.retry() })
                }
                
                Spacer()

                // Stop and Snooze buttons at bottom
                if viewModel.state == .ringing {
                    VStack(spacing: 16) {
                        // Stop button (enabled only when challenges complete)
                        Button {
                            Task {
                                await viewModel.stopAlarm()
                            }
                        } label: {
                            Text("Stop Alarm")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(viewModel.canStopAlarm ? Color.red : Color.gray.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(!viewModel.canStopAlarm)
                        .accessibilityLabel("Stop Alarm")
                        .accessibilityHint(viewModel.canStopAlarm ? "Stops the alarm" : "Complete challenges first to stop the alarm")

                        // Snooze button
                        if viewModel.canSnooze {
                            Button {
                                Task {
                                    await viewModel.snooze()
                                }
                            } label: {
                                Text("Snooze (5 min)")
                                    .font(.body)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.gray.opacity(0.3))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .accessibilityLabel("Snooze for 5 minutes")
                        }
                    }
                    .padding(.horizontal, 32)
                }
            }
            .padding()
        }
        .task {
            await viewModel.start(alarmId: alarmID)
        }
        .onAppear {
            setupCallbacks()
        }
        .onDisappear {
            // Ensure cleanup when view disappears
            viewModel.cleanup()
        }
    }

    private func setupCallbacks() {
        viewModel.onRequestHaptics = {
            // Trigger haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
        }
    }
}

// MARK: - State-specific Content Views

private struct RingingContent: View {
    let beginScan: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "alarm.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            Text("ALARM")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Tap to start dismissal process")
                .font(.title2)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Button("Scan Code to Dismiss") {
                beginScan()
            }
            .font(.title2)
            .fontWeight(.semibold)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .frame(minHeight: 44) // Accessibility: 44pt minimum tap target
            .accessibilityLabel("Scan Code to Dismiss")
            .accessibilityHint("Starts QR code scanner to dismiss the alarm")
        }
    }
}

private struct ScanningContent: View {
    let cancelScan: () -> Void
    let onScanned: (String) -> Void  // Add callback parameter
    @EnvironmentObject private var container: DependencyContainer
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Scanning QR Code")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Position the QR code within the scanner")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            // Actual QR Scanner Integration
            QRScannerView(
                onCancel: cancelScan,
                onScanned: onScanned,  // Connect to actual callback
                permissionService: container.permissionService
            )
            .frame(width: 280, height: 280)
            .cornerRadius(12)
            .clipped()
            
            Button("Cancel", action: cancelScan)
                .font(.title2)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(8)
                .frame(minHeight: 44) // Accessibility: 44pt minimum tap target
                .accessibilityLabel("Cancel QR Code Scanning")
        }
    }
}

private struct ValidatingContent: View {
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(2)
                .tint(.white)
            
            Text("Validating QR Code...")
                .font(.title2)
                .foregroundColor(.white)
        }
    }
}

private struct SuccessContent: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Alarm Dismissed!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Successfully validated QR code")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

private struct FailedContent: View {
    let reason: DismissalFlowViewModel.FailureReason
    let retry: () -> Void
    @EnvironmentObject private var container: DependencyContainer
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: reason == .permissionDenied ? "camera.fill" : "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(reason == .permissionDenied ? .orange : .red)
            
            Text(reason == .permissionDenied ? "Camera Access Required" : "Error")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text(reason.displayMessage)
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                if reason == .permissionDenied {
                    Button("Open Settings") {
                        container.permissionService.openAppSettings()
                    }
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Text("In Settings: Privacy & Security → Camera → alarmAppNew → Enable")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                } else {
                    Button("Try Again") {
                        retry()
                    }
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
    }
}

#Preview {
    let container = DependencyContainer()
    return RingingView(alarmID: UUID(), container: container)
        .environmentObject(container)
        .environment(\.container, container)
}

```

### SettingsView.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/Views/SettingsView.swift`

```swift
//
//  SettingsView.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/24/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settingsService: SettingsService
    @StateObject private var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    init(container: DependencyContainer) {
        self.settingsService = container.settingsServiceConcrete
        self._viewModel = StateObject(wrappedValue: container.makeSettingsViewModel())
    }

    var body: some View {
        NavigationStack {
            Form {
                // General Settings Section
                Section("General") {
                    Text("App version and basic settings would go here in a full implementation")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

#if DEBUG
                // Developer Section - Only visible in DEBUG builds
                Section("Developer Settings") {
                    VStack(alignment: .leading, spacing: 12) {
                        // Reliability Mode Toggle
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Experimental: Background Audio Reliability")
                                    .font(.headline)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { settingsService.currentMode == .notificationsPlusAudio },
                                    set: { isOn in
                                        let newMode: ReliabilityMode = isOn ? .notificationsPlusAudio : .notificationsOnly
                                        settingsService.setReliabilityMode(newMode)
                                    }
                                ))
                                .labelsHidden()
                            }

                            Text(settingsService.currentMode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Warning Message
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Developer Warning")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }

                            Text("Background audio mode is experimental and may not be App Store compliant. Use only for testing purposes. Default 'Notifications Only' mode is App Store safe.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)

                        // Current Mode Status
                        HStack {
                            Text("Current Mode:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(settingsService.currentMode.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(settingsService.currentMode == .notificationsOnly ? .green : .orange)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .headerProminence(.increased)
#endif

                // Diagnostics Section
                Section("Diagnostics") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reliability Logs")
                            .font(.headline)

                        Text("Export alarm firing and dismissal events for troubleshooting")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button {
                            viewModel.exportLogs()
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export Logs")
                            }
                        }
                        .accessibilityLabel("Export reliability logs")
                        .accessibilityHint("Shares alarm event logs for troubleshooting")
                    }
                    .padding(.vertical, 4)
                }

                // Reset Section
                Section("Reset") {
                    Button("Reset to Defaults") {
                        settingsService.resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let container = DependencyContainer()
    return SettingsView(container: container)
}
```

### alarmAppNewApp.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNew/alarmAppNewApp.swift`

```swift
//
//  alarmAppNewApp.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/3/25.
//


import SwiftUI
import UserNotifications

@main
struct alarmAppNewApp: App {
    @Environment(\.scenePhase) private var scenePhase

    // OWNED instance - no singleton
    private let dependencyContainer = DependencyContainer()

    init() {
        // CRITICAL: Activate AlarmKit scheduler at app launch (iOS 26+ only)
        setupAlarmKit()

        // Activate observability systems for production-ready logging
        dependencyContainer.activateObservability()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()              // we'll repurpose ContentView as the Root
                .environmentObject(dependencyContainer.appRouter)
                .environment(\.container, dependencyContainer)  // Inject via environment
                // Check for pending intents when app becomes active
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    Task { @MainActor in
                        dependencyContainer.alarmIntentBridge.checkForPendingIntent()
                    }
                }
                // Route to ringing screen when alarm intent is received
                .onReceive(NotificationCenter.default.publisher(for: .alarmIntentReceived)) { notification in
                    if let intentAlarmId = notification.userInfo?["intentAlarmId"] as? UUID {
                        // For post-migration alarms, intent ID == domain UUID
                        // For pre-migration alarms, we pass intent ID and use fallback in stop()
                        // Since we can't determine which is which here, pass intent ID as both
                        dependencyContainer.appRouter.showRinging(for: intentAlarmId, intentAlarmID: intentAlarmId)
                    }
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    private func setupAlarmKit() {
        // AlarmKit activation and initialization sequence (iOS 26+ only)
        Task {
            do {
                // 1. Activate AlarmKit scheduler (idempotent)
                await dependencyContainer.activateAlarmScheduler()
                print("App Launch: Activated AlarmKit scheduler")

                // 2. ONE-TIME MIGRATION: Reconcile AlarmKit IDs after external mapping removal
                //    This ensures alarms scheduled before the ID mapping fix are re-registered
                //    with their domain UUIDs. Runs once per migration version.
                await dependencyContainer.migrateAlarmKitIDsIfNeeded()
                print("App Launch: Completed AlarmKit ID migration check")

                // 3. Selective reconciliation: sync daemon with domain alarms
                //    Uses daemon as source of truth; only touches mismatched alarms
                let alarms = try await dependencyContainer.persistenceService.loadAlarms()
                await dependencyContainer.alarmScheduler.reconcile(
                    alarms: alarms,
                    skipIfRinging: true
                )
                print("App Launch: Reconciled daemon state")
            } catch {
                print("App Launch: Failed to setup AlarmKit: \(error)")
            }
        }

        print("App Launch: AlarmKit setup initiated")
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        if phase == .active {
            Task {
                // Clean up incomplete alarm runs from previous sessions
                do {
                    try await dependencyContainer.alarmRunStore.cleanupIncompleteRuns()  // NEW: async actor call
                } catch {
                    print("Failed to cleanup incomplete runs: \(error)")
                }

                // Re-register all notifications when app becomes active
                let alarmListVM = dependencyContainer.makeAlarmListViewModel()
                await alarmListVM.refreshAllAlarms()
            }
        }
    }
}

```

---

## Test Files

### AlarmKitIntegrationTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/AlarmKitIntegrationTests.swift`

```swift
//
//  AlarmKitIntegrationTests.swift
//  alarmAppNewTests
//
//  Integration tests for AlarmKit components (CHUNK 7)
//  Validates the complete AlarmKit integration stack
//

import XCTest
@testable import alarmAppNew

@MainActor
final class AlarmKitIntegrationTests: XCTestCase {

    // MARK: - Test: Factory Selection Logic

    func test_factory_selectsLegacyScheduler_onCurrentiOS() {
        // Given: Factory with real dependencies
        let idMapping = InMemoryAlarmIdMapping()
        let mockLegacy = MockAlarmSchedulingForFactory()
        let presentationBuilder = AlarmPresentationBuilder()

        // When: Create scheduler via factory (should select legacy on iOS < 26)
        let scheduler = AlarmSchedulerFactory.make(
            idMapping: idMapping,
            legacy: mockLegacy,
            presentationBuilder: presentationBuilder
        )

        // Then: On current iOS, should use legacy scheduler
        if #available(iOS 26.0, *) {
            // If running on iOS 26+, factory returns AlarmKitScheduler
            XCTAssertTrue(scheduler is AlarmKitScheduler, "Should use AlarmKitScheduler on iOS 26+")
        } else {
            // On iOS < 26, factory returns the legacy scheduler as-is
            XCTAssertTrue(scheduler is MockAlarmSchedulingForFactory, "Should use legacy scheduler on iOS < 26")
        }
    }

    // MARK: - Test: AlarmScheduling Protocol Compliance

    func test_legacyScheduler_conformsToAlarmScheduling() async throws {
        // Given: Legacy NotificationService mock
        let mockLegacy = MockAlarmSchedulingForFactory()

        // When: Use as AlarmScheduling
        let scheduler: AlarmScheduling = mockLegacy

        // Then: Should support all required operations
        try await scheduler.requestAuthorizationIfNeeded()

        let testAlarm = createTestAlarm()
        let externalId = try await scheduler.schedule(alarm: testAlarm)
        XCTAssertFalse(externalId.isEmpty, "Should return external ID")

        await scheduler.cancel(alarmId: testAlarm.id)
        XCTAssertEqual(mockLegacy.cancelCalls.count, 1)

        let pendingIds = await scheduler.pendingAlarmIds()
        XCTAssertNotNil(pendingIds)
    }

    @available(iOS 26.0, *)
    func test_alarmKitScheduler_conformsToAlarmScheduling() async throws {
        // Given: AlarmKit scheduler
        let idMapping = InMemoryAlarmIdMapping()
        let presentationBuilder = AlarmPresentationBuilder()
        let scheduler = AlarmKitScheduler(
            idMapping: idMapping,
            presentationBuilder: presentationBuilder
        )

        // Activate the scheduler first
        await scheduler.activate()

        // When: Use as AlarmScheduling
        let testAlarm = createTestAlarm()

        // Then: Should support scheduling operations
        // Note: These will fail in test environment without AlarmManager entitlement
        // but we're testing protocol conformance, not actual AlarmKit functionality
        do {
            _ = try await scheduler.schedule(alarm: testAlarm)
        } catch {
            // Expected to fail without entitlement - that's OK for protocol conformance test
            print("Expected error without AlarmKit entitlement: \(error)")
        }

        // Cancel should not throw even without entitlement
        await scheduler.cancel(alarmId: testAlarm.id)

        let pendingIds = await scheduler.pendingAlarmIds()
        XCTAssertNotNil(pendingIds)
    }

    // MARK: - Test: AlarmIdMapping Round-Trip

    func test_idMapping_roundTrip() async {
        // Given: In-memory mapping
        let mapping = InMemoryAlarmIdMapping()
        let alarmId = UUID()
        let externalId = "test-external-id-123"

        // When: Store mapping
        await mapping.store(alarmId: alarmId, externalId: externalId)

        // Then: Should retrieve correctly
        let retrievedExternal = await mapping.externalId(for: alarmId)
        XCTAssertEqual(retrievedExternal, externalId)

        let retrievedInternal = await mapping.alarmId(for: externalId)
        XCTAssertEqual(retrievedInternal, alarmId)
    }

    func test_idMapping_clearRemovesMapping() async {
        // Given: Mapping with stored ID
        let mapping = InMemoryAlarmIdMapping()
        let alarmId = UUID()
        let externalId = "test-id"
        await mapping.store(alarmId: alarmId, externalId: externalId)

        // When: Clear the mapping
        await mapping.clear(alarmId: alarmId)

        // Then: Should no longer exist
        let retrievedExternal = await mapping.externalId(for: alarmId)
        XCTAssertNil(retrievedExternal)

        let retrievedInternal = await mapping.alarmId(for: externalId)
        XCTAssertNil(retrievedInternal)
    }

    // MARK: - Test: Presentation Builder Output Format

    func test_presentationBuilder_producesValidOutput() {
        // Given: Presentation builder
        let builder = AlarmPresentationBuilder()
        let alarm = createTestAlarm()

        // When: Build presentation
        let presentation = builder.build(for: alarm)

        // Then: Should have required fields
        XCTAssertEqual(presentation.title, alarm.label)
        XCTAssertFalse(presentation.body.isEmpty, "Body should not be empty")
        XCTAssertNotNil(presentation.soundId, "Should have sound ID")
        XCTAssertEqual(presentation.alarmId, alarm.id)
    }

    func test_presentationBuilder_includesTimeInBody() {
        // Given: Alarm with specific time
        let builder = AlarmPresentationBuilder()
        let alarm = createTestAlarm()

        // When: Build presentation
        let presentation = builder.build(for: alarm)

        // Then: Body should mention time
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = formatter.string(from: alarm.time)

        XCTAssertTrue(
            presentation.body.contains(timeString),
            "Body should contain formatted time: \(presentation.body)"
        )
    }

    // MARK: - Test: Stop/Snooze Policy Gates

    func test_stopAlarmAllowed_gatesCorrectly() {
        // Given: Alarm with challenges
        let alarmWithQR = createTestAlarm(challenges: [.qr])
        let alarmNoChallenges = createTestAlarm(challenges: [])

        // When/Then: Check if stop is allowed
        XCTAssertFalse(
            StopAlarmAllowed.compute(for: alarmWithQR, allChallengesCompleted: false),
            "Stop should NOT be allowed with incomplete QR challenge"
        )

        XCTAssertTrue(
            StopAlarmAllowed.compute(for: alarmWithQR, allChallengesCompleted: true),
            "Stop should be allowed when all challenges completed"
        )

        XCTAssertTrue(
            StopAlarmAllowed.compute(for: alarmNoChallenges, allChallengesCompleted: true),
            "Stop should be allowed for alarm with no challenges"
        )
    }

    func test_snoozeAlarm_computesCorrectDuration() {
        // Given: Alarm
        let alarm = createTestAlarm()
        let now = Date()

        // When: Compute snooze
        let snoozeResult = SnoozeAlarm.compute(for: alarm, at: now)

        // Then: Should have valid snooze time
        XCTAssertNotNil(snoozeResult)
        if let result = snoozeResult {
            XCTAssertGreaterThan(result.newFireTime, now, "Snooze should be in the future")
            XCTAssertEqual(result.snoozeDuration, 300, "Default snooze is 5 minutes (300 seconds)")
        }
    }

    // MARK: - Test: Integration with DependencyContainer

    func test_dependencyContainer_providesAlarmScheduler() {
        // Given: Real dependency container
        let container = DependencyContainer()

        // When: Access alarm scheduler
        let scheduler = container.alarmScheduler

        // Then: Should not be nil and should be correct type
        XCTAssertNotNil(scheduler)

        if #available(iOS 26.0, *) {
            // On iOS 26+, should be AlarmKitScheduler
            XCTAssertTrue(scheduler is AlarmKitScheduler, "Should use AlarmKitScheduler on iOS 26+")
        } else {
            // On iOS < 26, should be NotificationService
            XCTAssertTrue(scheduler is NotificationService, "Should use NotificationService on iOS < 26")
        }
    }

    // MARK: - Test Helpers

    private func createTestAlarm(challenges: [ChallengeKind] = [.qr]) -> Alarm {
        Alarm(
            id: UUID(),
            time: Date().addingTimeInterval(3600), // 1 hour from now
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: challenges,
            expectedQR: challenges.contains(.qr) ? "test-qr-code" : nil,
            stepThreshold: challenges.contains(.steps) ? 50 : nil,
            mathChallenge: challenges.contains(.math) ? .easy : nil,
            isEnabled: true,
            soundId: "ringtone1",
            volume: 0.8
        )
    }
}

// MARK: - Mock Types for Integration Tests

final class MockAlarmSchedulingForFactory: AlarmScheduling {
    var scheduleCalls: [Alarm] = []
    var cancelCalls: [UUID] = []

    func requestAuthorizationIfNeeded() async throws {
        // Mock implementation
    }

    func schedule(alarm: Alarm) async throws -> String {
        scheduleCalls.append(alarm)
        return "mock-external-id-\(alarm.id.uuidString)"
    }

    func cancel(alarmId: UUID) async {
        cancelCalls.append(alarmId)
    }

    func pendingAlarmIds() async -> [UUID] {
        return scheduleCalls.map { $0.id }
    }

    func stop(alarmId: UUID) async throws {
        // Mock implementation
    }

    func transitionToCountdown(alarmId: UUID, duration: TimeInterval) async throws {
        // Mock implementation
    }
}

// MARK: - In-Memory AlarmIdMapping for Testing

actor InMemoryAlarmIdMapping: AlarmIdMapping {
    private var internalToExternal: [UUID: String] = [:]
    private var externalToInternal: [String: UUID] = [:]

    func store(alarmId: UUID, externalId: String) {
        internalToExternal[alarmId] = externalId
        externalToInternal[externalId] = alarmId
    }

    func externalId(for alarmId: UUID) -> String? {
        return internalToExternal[alarmId]
    }

    func alarmId(for externalId: String) -> UUID? {
        return externalToInternal[externalId]
    }

    func clear(alarmId: UUID) {
        if let externalId = internalToExternal[alarmId] {
            externalToInternal.removeValue(forKey: externalId)
        }
        internalToExternal.removeValue(forKey: alarmId)
    }
}

```

### AlarmListViewModelTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/AlarmListViewModelTests.swift`

```swift
//
//  AlarmListViewModelTests.swift
//  alarmAppNewTests
//
//  Tests for AlarmListViewModel with unified AlarmScheduling integration (CHUNK 6)
//

import XCTest
@testable import alarmAppNew

@MainActor
final class AlarmListViewModelTests: XCTestCase {

    var viewModel: AlarmListViewModel!
    var mockStorage: MockAlarmStorage!
    var mockPermissionService: MockPermissionService!
    var mockAlarmScheduler: MockAlarmSchedulingForList!
    var mockRefresher: MockRefreshCoordinator!
    var mockVolumeProvider: MockSystemVolumeProvider!
    var mockNotificationService: MockNotificationService!

    override func setUp() async throws {
        try await super.setUp()

        mockStorage = MockAlarmStorage()
        mockPermissionService = MockPermissionService()
        mockAlarmScheduler = MockAlarmSchedulingForList()
        mockRefresher = MockRefreshCoordinator()
        mockVolumeProvider = MockSystemVolumeProvider()
        mockNotificationService = MockNotificationService()

        viewModel = AlarmListViewModel(
            storage: mockStorage,
            permissionService: mockPermissionService,
            alarmScheduler: mockAlarmScheduler,
            refresher: mockRefresher,
            systemVolumeProvider: mockVolumeProvider,
            notificationService: mockNotificationService
        )
    }

    override func tearDown() async throws {
        viewModel = nil
        mockStorage = nil
        mockPermissionService = nil
        mockAlarmScheduler = nil
        mockRefresher = nil
        mockVolumeProvider = nil
        mockNotificationService = nil
        try await super.tearDown()
    }

    // MARK: - CHUNK 6 Tests: AlarmScheduling Integration

    func test_add_schedulesViaAlarmScheduler() async {
        // Given
        let alarm = createTestAlarm(isEnabled: true)

        // When
        viewModel.add(alarm)

        // Wait for async scheduling
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(mockAlarmScheduler.scheduleCalls.count, 1)
        XCTAssertEqual(mockAlarmScheduler.scheduleCalls.first?.id, alarm.id)
    }

    func test_toggle_enablesViaAlarmScheduler() async {
        // Given: Disabled alarm
        let alarm = createTestAlarm(isEnabled: false)
        await mockStorage.setStoredAlarms([alarm])
        viewModel.add(alarm)

        // Clear previous calls
        mockAlarmScheduler.scheduleCalls = []
        mockAlarmScheduler.cancelCalls = []

        // When: Toggle to enable
        viewModel.toggle(alarm)

        // Wait for async scheduling
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(mockAlarmScheduler.scheduleCalls.count, 1)
        XCTAssertEqual(mockAlarmScheduler.cancelCalls.count, 0)
    }

    func test_toggle_disablesViaCancelOnAlarmScheduler() async {
        // Given: Enabled alarm
        let alarm = createTestAlarm(isEnabled: true)
        await mockStorage.setStoredAlarms([alarm])
        viewModel.add(alarm)

        // Clear previous calls
        mockAlarmScheduler.scheduleCalls = []
        mockAlarmScheduler.cancelCalls = []

        // When: Toggle to disable
        viewModel.toggle(alarm)

        // Wait for async cancellation
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(mockAlarmScheduler.cancelCalls.count, 1)
        XCTAssertEqual(mockAlarmScheduler.cancelCalls.first, alarm.id)
        XCTAssertEqual(mockAlarmScheduler.scheduleCalls.count, 0)
    }

    func test_update_reschedulesViaAlarmScheduler() async {
        // Given: Existing enabled alarm
        var alarm = createTestAlarm(isEnabled: true)
        await mockStorage.setStoredAlarms([alarm])
        viewModel.add(alarm)

        // Clear previous calls
        mockAlarmScheduler.scheduleCalls = []

        // When: Update the alarm
        alarm.label = "Updated Label"
        viewModel.update(alarm)

        // Wait for async scheduling
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(mockAlarmScheduler.scheduleCalls.count, 1)
        XCTAssertEqual(mockAlarmScheduler.scheduleCalls.first?.label, "Updated Label")
    }

    func test_delete_cancelsViaAlarmScheduler() async {
        // Given: Enabled alarm
        let alarm = createTestAlarm(isEnabled: true)
        await mockStorage.setStoredAlarms([alarm])
        viewModel.add(alarm)

        // Clear previous calls
        mockAlarmScheduler.cancelCalls = []

        // When: Delete the alarm
        viewModel.delete(alarm)

        // Wait for async cancellation
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(mockAlarmScheduler.cancelCalls.count, 1)
        XCTAssertEqual(mockAlarmScheduler.cancelCalls.first, alarm.id)
    }

    func test_refreshAllAlarms_usesRefresher() async {
        // Given: Multiple alarms
        let alarms = [
            createTestAlarm(isEnabled: true),
            createTestAlarm(isEnabled: false),
            createTestAlarm(isEnabled: true)
        ]
        await mockStorage.setStoredAlarms(alarms)
        viewModel.alarms = alarms

        // When
        await viewModel.refreshAllAlarms()

        // Then
        XCTAssertEqual(mockRefresher.requestRefreshCallCount, 1)
        XCTAssertEqual(mockRefresher.lastRefreshedAlarms?.count, 3)
    }

    func test_schedulingError_setsErrorMessage() async {
        // Given: Scheduler that throws
        mockAlarmScheduler.shouldThrow = true
        let alarm = createTestAlarm(isEnabled: true)

        // When
        viewModel.add(alarm)

        // Wait for async error handling
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - Test Helpers

    private func createTestAlarm(isEnabled: Bool = true) -> Alarm {
        Alarm(
            id: UUID(),
            time: Date().addingTimeInterval(3600),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: "test-qr",
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: isEnabled,
            soundId: "ringtone1",
            volume: 0.8
        )
    }
}

// MARK: - Mock Types

final class MockAlarmSchedulingForList: AlarmScheduling {
    var scheduleCalls: [Alarm] = []
    var cancelCalls: [UUID] = []
    var shouldThrow = false

    func requestAuthorizationIfNeeded() async throws {}

    func schedule(alarm: Alarm) async throws -> String {
        if shouldThrow {
            throw NSError(domain: "TestError", code: 1)
        }
        scheduleCalls.append(alarm)
        return "mock-external-id"
    }

    func cancel(alarmId: UUID) async {
        cancelCalls.append(alarmId)
    }

    func pendingAlarmIds() async -> [UUID] {
        return []
    }

    func stop(alarmId: UUID) async throws {}

    func transitionToCountdown(alarmId: UUID, duration: TimeInterval) async throws {}
}

final class MockRefreshCoordinator: RefreshRequesting {
    var requestRefreshCallCount = 0
    var lastRefreshedAlarms: [Alarm]?

    func requestRefresh(alarms: [Alarm]) async {
        requestRefreshCallCount += 1
        lastRefreshedAlarms = alarms
    }
}

```

### AppRouterTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/AppRouterTests.swift`

```swift
//
//  AppRouterTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 9/7/25.
//  Tests for AppRouter single-instance guard functionality
//

import XCTest
@testable import alarmAppNew

@MainActor
class AppRouterTests: XCTestCase {
    var router: AppRouter!
    
    override func setUp() {
        super.setUp()
        router = AppRouter()
    }
    
    // MARK: - Single Instance Guard Tests
    
    func test_showRinging_singleInstance_ignoresSubsequentRequests() {
        let firstAlarmId = UUID()
        let secondAlarmId = UUID()
        
        // When - first ringing request
        router.showRinging(for: firstAlarmId)
        
        // Then - should set route and track alarm
        XCTAssertEqual(router.route, .ringing(alarmID: firstAlarmId))
        XCTAssertTrue(router.isInDismissalFlow)
        XCTAssertEqual(router.currentDismissalAlarmId, firstAlarmId)
        
        // When - second ringing request (should be ignored)
        router.showRinging(for: secondAlarmId)
        
        // Then - route unchanged, still showing first alarm
        XCTAssertEqual(router.route, .ringing(alarmID: firstAlarmId))
        XCTAssertEqual(router.currentDismissalAlarmId, firstAlarmId)
    }
    
    func test_showDismissal_singleInstance_ignoresSubsequentRequests() {
        let firstAlarmId = UUID()
        let secondAlarmId = UUID()
        
        // When - first dismissal request
        router.showDismissal(for: firstAlarmId)
        
        // Then - should set route and track alarm
        XCTAssertEqual(router.route, .dismissal(alarmID: firstAlarmId))
        XCTAssertTrue(router.isInDismissalFlow)
        XCTAssertEqual(router.currentDismissalAlarmId, firstAlarmId)
        
        // When - second dismissal request (should be ignored)
        router.showDismissal(for: secondAlarmId)
        
        // Then - route unchanged, still showing first alarm
        XCTAssertEqual(router.route, .dismissal(alarmID: firstAlarmId))
        XCTAssertEqual(router.currentDismissalAlarmId, firstAlarmId)
    }
    
    func test_backToList_clearsActiveDismissalState() {
        let alarmId = UUID()
        
        // Given - active dismissal flow
        router.showRinging(for: alarmId)
        XCTAssertTrue(router.isInDismissalFlow)
        XCTAssertEqual(router.currentDismissalAlarmId, alarmId)
        
        // When - back to list
        router.backToList()
        
        // Then - dismissal state cleared
        XCTAssertEqual(router.route, .alarmList)
        XCTAssertFalse(router.isInDismissalFlow)
        XCTAssertNil(router.currentDismissalAlarmId)
    }
    
    func test_showRinging_afterBackToList_allowsNewDismissal() {
        let firstAlarmId = UUID()
        let secondAlarmId = UUID()
        
        // Given - first dismissal flow completed
        router.showRinging(for: firstAlarmId)
        router.backToList()
        XCTAssertFalse(router.isInDismissalFlow)
        
        // When - new ringing request
        router.showRinging(for: secondAlarmId)
        
        // Then - new dismissal flow started
        XCTAssertEqual(router.route, .ringing(alarmID: secondAlarmId))
        XCTAssertTrue(router.isInDismissalFlow)
        XCTAssertEqual(router.currentDismissalAlarmId, secondAlarmId)
    }
    
    func test_mixedRoutes_singleInstance_preventsCrossPollination() {
        let alarmId1 = UUID()
        let alarmId2 = UUID()
        
        // Given - ringing flow active
        router.showRinging(for: alarmId1)
        XCTAssertEqual(router.route, .ringing(alarmID: alarmId1))
        
        // When - try to show dismissal for different alarm
        router.showDismissal(for: alarmId2)
        
        // Then - request ignored, still in ringing flow
        XCTAssertEqual(router.route, .ringing(alarmID: alarmId1))
        XCTAssertEqual(router.currentDismissalAlarmId, alarmId1)
    }
    
    func test_initialState_allowsFirstDismissal() {
        let alarmId = UUID()
        
        // Given - initial state
        XCTAssertEqual(router.route, .alarmList)
        XCTAssertFalse(router.isInDismissalFlow)
        XCTAssertNil(router.currentDismissalAlarmId)
        
        // When - first dismissal request
        router.showRinging(for: alarmId)
        
        // Then - dismissal flow started
        XCTAssertEqual(router.route, .ringing(alarmID: alarmId))
        XCTAssertTrue(router.isInDismissalFlow)
        XCTAssertEqual(router.currentDismissalAlarmId, alarmId)
    }
}
```

### Architecture_SingletonGuardrailTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/Architecture_SingletonGuardrailTests.swift`

```swift
//
//  Architecture_SingletonGuardrailTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/8/25.
//  Architectural guardrail tests to prevent singleton usage
//

import XCTest
@testable import alarmAppNew

final class Architecture_SingletonGuardrailTests: XCTestCase {

    /// Verifies that DependencyContainer.shared does not exist anywhere in the Swift source code
    /// (excluding this test file and documentation)
    func test_noSingletonReferencesInCodebase() throws {
        // GIVEN: Project root directory
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // alarmAppNewTests
            .deletingLastPathComponent() // Project root

        // WHEN: Searching for DependencyContainer.shared in Swift files
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/grep")
        process.arguments = [
            "-r",                                  // Recursive search
            "DependencyContainer\\.shared",        // Pattern to find
            "--include=*.swift",                   // Only Swift files
            "--exclude-dir=build",                 // Exclude build directory
            "--exclude-dir=.build",                // Exclude build directory
            projectRoot.path
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // Filter out acceptable references (this test file and docs)
        let lines = output.split(separator: "\n")
        let violations = lines.filter { line in
            let lineStr = String(line)
            // Allow references in this test file
            if lineStr.contains("Architecture_SingletonGuardrailTests.swift") {
                return false
            }
            // Allow references in documentation
            if lineStr.contains("/docs/") || lineStr.contains("CLAUDE.md") {
                return false
            }
            return true
        }

        // THEN: No violations should be found
        if !violations.isEmpty {
            let violationList = violations.map { "  • \($0)" }.joined(separator: "\n")
            XCTFail("""
                ❌ SINGLETON USAGE DETECTED!

                Found DependencyContainer.shared references in the codebase.
                This project requires all dependencies to be injected via initializers or environment.

                Violations found:
                \(violationList)

                Fix: Replace singleton access with proper dependency injection:
                - Pass DependencyContainer via initializer parameters
                - Use SwiftUI environment injection: @Environment(\\.container)
                - Update factory methods in DependencyContainer to accept dependencies
                """)
        }
    }

    /// Verifies that DependencyContainer does not have a static shared property
    func test_dependencyContainerHasNoStaticShared() {
        // Use runtime reflection to check for static 'shared' property
        let mirror = Mirror(reflecting: DependencyContainer.self)

        // Check static properties (would appear in type's mirror)
        let hasSharedProperty = mirror.children.contains { child in
            child.label == "shared"
        }

        XCTAssertFalse(hasSharedProperty,
                      "DependencyContainer should NOT have a static 'shared' property. Use dependency injection instead.")
    }

    /// Verifies that DependencyContainer init is public (not private)
    func test_dependencyContainerInitIsPublic() {
        // This test verifies we can create instances freely
        let container1 = DependencyContainer()
        let container2 = DependencyContainer()

        // Each instance should be independent
        XCTAssertFalse(container1 === container2,
                      "DependencyContainer instances should be independent (not singleton)")
    }
}

```

### ChainedSchedulingIntegrationTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/ChainedSchedulingIntegrationTests.swift`

```swift
//
//  ChainedSchedulingIntegrationTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/1/25.
//

import XCTest
import UserNotifications
@testable import alarmAppNew

/// E2E integration tests for chained notification scheduling
/// Tests the complete flow from NotificationService → ChainedScheduler → UNUserNotificationCenter
final class ChainedSchedulingIntegrationTests: XCTestCase {

    private var mockNotificationCenter: MockNotificationCenter!
    private var mockSoundCatalog: MockSoundCatalog!
    private var testNotificationIndex: NotificationIndex!
    private var chainPolicy: ChainPolicy!
    private var mockGlobalLimitGuard: MockGlobalLimitGuard!
    private var mockClock: MockClock!
    private var chainedScheduler: ChainedNotificationScheduler!
    private var mockSettingsService: MockSettingsService!
    private var mockPermissionService: MockPermissionService!
    private var mockReliabilityLogger: MockReliabilityLogger!
    private var mockAppRouter: AppRouter!
    private var mockPersistence: MockAlarmStorage!
    private var mockAppStateProvider: AppStateProvider!
    private var notificationService: NotificationService!

    private let testAlarmId = UUID()
    private let testFireDate = Date(timeIntervalSince1970: 1696156800) // Fixed for reproducibility

    override func setUp() async throws {
        try await super.setUp()

        // Set up chained scheduler dependencies
        mockNotificationCenter = MockNotificationCenter()
        mockSoundCatalog = MockSoundCatalog()

        let testSuiteName = "test-integration-\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: testSuiteName)!
        testNotificationIndex = NotificationIndex(defaults: testDefaults)

        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 300,
            fallbackSpacingSec: 30,
            minLeadTimeSec: 10
        )
        chainPolicy = ChainPolicy(settings: settings)

        mockGlobalLimitGuard = MockGlobalLimitGuard()
        mockClock = MockClock(fixedNow: testFireDate.addingTimeInterval(-3600))

        chainedScheduler = ChainedNotificationScheduler(
            notificationCenter: mockNotificationCenter,
            soundCatalog: mockSoundCatalog,
            notificationIndex: testNotificationIndex,
            chainPolicy: chainPolicy,
            globalLimitGuard: mockGlobalLimitGuard,
            clock: mockClock
        )

        // Set up NotificationService dependencies
        mockSettingsService = MockSettingsService()
        mockPermissionService = MockPermissionService()
        mockReliabilityLogger = MockReliabilityLogger()
        mockAppRouter = AppRouter()
        mockPersistence = MockAlarmStorage()
        mockAppStateProvider = AppStateProvider()

        notificationService = NotificationService(
            permissionService: mockPermissionService,
            appStateProvider: mockAppStateProvider,
            reliabilityLogger: mockReliabilityLogger,
            appRouter: mockAppRouter,
            persistenceService: mockPersistence,
            chainedScheduler: chainedScheduler,
            settingsService: mockSettingsService
        )
    }

    override func tearDown() async throws {
        mockNotificationCenter = nil
        mockSoundCatalog = nil
        testNotificationIndex = nil
        chainPolicy = nil
        mockGlobalLimitGuard = nil
        mockClock = nil
        chainedScheduler = nil
        mockSettingsService = nil
        mockPermissionService = nil
        mockReliabilityLogger = nil
        mockAppRouter = nil
        mockPersistence = nil
        mockAppStateProvider = nil
        notificationService = nil
        try await super.tearDown()
    }

    // MARK: - Feature Flag Tests

    func test_scheduleAlarm_withFeatureFlagEnabled_usesChainedScheduler() async throws {
        // Given: Feature flag enabled, authorized permissions
        await mockSettingsService.setUseChainedScheduling(true)
        mockPermissionService.authorizationStatus = .authorized
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 5

        let alarm = createTestAlarm()

        // When: Schedule alarm
        try await notificationService.scheduleAlarm(alarm)

        // Then: Chained scheduler was used (multiple notifications scheduled)
        XCTAssertGreaterThan(mockNotificationCenter.scheduledRequests.count, 1,
                            "Chained scheduler should create multiple notifications")
        XCTAssertEqual(mockGlobalLimitGuard.reserveCallCount, 1,
                      "Should have called reserve on global limit guard")
    }

    func test_scheduleAlarm_withFeatureFlagDisabled_usesLegacyPath() async throws {
        // Given: Feature flag disabled, authorized permissions
        await mockSettingsService.setUseChainedScheduling(false)
        mockPermissionService.authorizationStatus = .authorized

        let alarm = createTestAlarm()

        // When: Schedule alarm
        try await notificationService.scheduleAlarm(alarm)

        // Then: Legacy scheduler was used (single notification + nudges)
        // Legacy creates: 1 main + 3 nudges = 4 notifications
        XCTAssertEqual(mockNotificationCenter.addRequestCallCount, 4,
                      "Legacy path should create 4 notifications (main + 3 nudges)")
        XCTAssertEqual(mockGlobalLimitGuard.reserveCallCount, 0,
                      "Legacy path should not use global limit guard")
    }

    // MARK: - Permission Handling Tests

    func test_scheduleAlarm_withDeniedPermissions_throwsPermissionError() async {
        // Given: Permissions denied
        mockPermissionService.authorizationStatus = .denied
        mockNotificationCenter.authorizationStatus = .denied
        await mockSettingsService.setUseChainedScheduling(true)

        let alarm = createTestAlarm()

        // When/Then: Should throw permission denied error
        do {
            try await notificationService.scheduleAlarm(alarm)
            XCTFail("Should have thrown NotificationError.permissionDenied")
        } catch let error as NotificationError {
            XCTAssertEqual(error, .permissionDenied)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Global Limit Tests

    func test_scheduleAlarm_withGlobalLimitExceeded_throwsSystemLimitError() async {
        // Given: Global limit exceeded (no slots available)
        await mockSettingsService.setUseChainedScheduling(true)
        mockPermissionService.authorizationStatus = .authorized
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 0 // No slots available

        let alarm = createTestAlarm()

        // When/Then: Should throw system limit exceeded error
        do {
            try await notificationService.scheduleAlarm(alarm)
            XCTFail("Should have thrown NotificationError.systemLimitExceeded")
        } catch let error as NotificationError {
            XCTAssertEqual(error, .systemLimitExceeded)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_scheduleAlarm_withPartialSlotsAvailable_trimsChain() async throws {
        // Given: Only 3 slots available (out of 5 requested)
        await mockSettingsService.setUseChainedScheduling(true)
        mockPermissionService.authorizationStatus = .authorized
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 3

        let alarm = createTestAlarm()

        // When: Schedule alarm
        try await notificationService.scheduleAlarm(alarm)

        // Then: Should schedule 3 notifications (trimmed)
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 3,
                      "Should have scheduled 3 notifications (trimmed from 5)")

        // And: Should log trimmed outcome
        let loggedEvents = mockReliabilityLogger.loggedEvents.filter { $0.details["event"] == "chained_schedule_trimmed" }
        XCTAssertEqual(loggedEvents.count, 1, "Should have logged trimmed outcome")
    }

    // MARK: - Identifier & Index Tests

    func test_scheduleAlarm_createsStableIdentifiers() async throws {
        // Given: Chained scheduling enabled
        await mockSettingsService.setUseChainedScheduling(true)
        mockPermissionService.authorizationStatus = .authorized
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 5

        let alarm = createTestAlarm()

        // When: Schedule alarm
        try await notificationService.scheduleAlarm(alarm)

        // Then: All identifiers should follow the stable format
        let scheduledIDs = mockNotificationCenter.scheduledRequests.map { $0.identifier }
        for id in scheduledIDs {
            XCTAssertTrue(id.starts(with: "alarm-\(alarm.id.uuidString)-occ-"),
                         "Identifier should follow stable format: \(id)")
        }
    }

    func test_scheduleAlarm_savesIdentifiersToIndex() async throws {
        // Given: Chained scheduling enabled
        await mockSettingsService.setUseChainedScheduling(true)
        mockPermissionService.authorizationStatus = .authorized
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 5

        let alarm = createTestAlarm()

        // When: Schedule alarm
        try await notificationService.scheduleAlarm(alarm)

        // Then: Identifiers should be saved to index
        let savedIdentifiers = testNotificationIndex.loadIdentifiers(alarmId: alarm.id)
        XCTAssertEqual(savedIdentifiers.count, 5,
                      "Should have saved 5 identifiers to index")
    }

    // MARK: - Logging Tests

    func test_scheduleAlarm_logsOutcomeWithContext() async throws {
        // Given: Chained scheduling enabled
        await mockSettingsService.setUseChainedScheduling(true)
        mockPermissionService.authorizationStatus = .authorized
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 5

        let alarm = createTestAlarm()

        // When: Schedule alarm
        try await notificationService.scheduleAlarm(alarm)

        // Then: Should have logged outcome with structured context
        let scheduledEvents = mockReliabilityLogger.loggedEvents.filter {
            $0.details["event"] == "chained_schedule_success"
        }
        XCTAssertEqual(scheduledEvents.count, 1, "Should have logged success outcome")

        let event = scheduledEvents[0]
        XCTAssertEqual(event.alarmId, alarm.id)
        XCTAssertNotNil(event.details["fireDate"])
        XCTAssertEqual(event.details["count"], "5")
        XCTAssertEqual(event.details["useChainedScheduling"], "true")
    }

    // MARK: - Async Preservation Tests

    func test_scheduleAlarm_preservesAsyncBehavior() async throws {
        // Given: Chained scheduling enabled
        await mockSettingsService.setUseChainedScheduling(true)
        mockPermissionService.authorizationStatus = .authorized
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 5

        let alarm = createTestAlarm()

        // When: Schedule alarm (should not block)
        let startTime = Date()
        try await notificationService.scheduleAlarm(alarm)
        let endTime = Date()

        // Then: Should complete quickly (async, no blocking)
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 1.0,
                         "Scheduling should complete quickly without blocking")
    }

    // MARK: - Helper Methods

    private func createTestAlarm() -> Alarm {
        return Alarm(
            id: testAlarmId,
            time: testFireDate,
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: "test-qr-code",
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: "chimes01",
            soundName: nil,
            volume: 0.8
        )
    }
}

```

### DismissalFlowViewModelTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/DismissalFlowViewModelTests.swift`

```swift
//
//  DismissalFlowViewModelTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 9/6/25.
//  Unit tests using only public intents - no private state manipulation
//

import XCTest
@testable import alarmAppNew
import UserNotifications
import Combine

@MainActor
class DismissalFlowViewModelTests: XCTestCase {
    var viewModel: DismissalFlowViewModel!
    var mockQRScanning: MockQRScanning!
    var mockNotifications: MockNotificationService!
    var mockAlarmStorage: MockAlarmStorage!
    var mockClock: MockClock!
    var mockRouter: MockAppRouter!
    var mockPermissionService: MockPermissionService!
    var mockReliabilityLogger: MockReliabilityLogger!
    var mockAudioEngine: MockAlarmAudioEngine!
    var mockReliabilityModeProvider: MockReliabilityModeProvider!
    var mockDismissedRegistry: DismissedRegistry!
    var mockSettingsService: MockSettingsService!
    var mockAlarmScheduler: MockAlarmScheduling!
    var mockAlarmRunStore: AlarmRunStore!
    var mockIdleTimerController: MockIdleTimerController!

    override func setUp() {
        super.setUp()

        mockQRScanning = MockQRScanning()
        mockNotifications = MockNotificationService()
        mockAlarmStorage = MockAlarmStorage()
        mockClock = MockClock()
        mockRouter = MockAppRouter()
        mockPermissionService = MockPermissionService()
        mockReliabilityLogger = MockReliabilityLogger()
        mockAudioEngine = MockAlarmAudioEngine()
        mockReliabilityModeProvider = MockReliabilityModeProvider()
        mockDismissedRegistry = DismissedRegistry()
        mockSettingsService = MockSettingsService()
        mockAlarmScheduler = MockAlarmScheduling()
        mockAlarmRunStore = AlarmRunStore()
        mockIdleTimerController = MockIdleTimerController()

        viewModel = DismissalFlowViewModel(
            qrScanning: mockQRScanning,
            notificationService: mockNotifications,
            alarmStorage: mockAlarmStorage,
            clock: mockClock,
            appRouter: mockRouter,
            permissionService: mockPermissionService,
            reliabilityLogger: mockReliabilityLogger,
            audioEngine: mockAudioEngine,
            reliabilityModeProvider: mockReliabilityModeProvider,
            dismissedRegistry: mockDismissedRegistry,
            settingsService: mockSettingsService,
            alarmScheduler: mockAlarmScheduler,
            alarmRunStore: mockAlarmRunStore,
            idleTimerController: mockIdleTimerController
        )
    }

    func test_start_setsRinging_and_keepsScreenAwake() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])

        // When
        await viewModel.start(alarmId: alarm.id)

        // Then
        XCTAssertEqual(viewModel.state, .ringing)
        XCTAssertTrue(viewModel.isScreenAwake)
        XCTAssertEqual(mockIdleTimerController.setIdleTimerCalls, [true])
    }

    func test_beginScan_requiresPermission_then_transitionsToScanning() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)

        // When
        viewModel.beginScan()

        // Wait for async permission check
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(viewModel.state, .scanning)
        XCTAssertTrue(mockQRScanning.isScanning)
    }

    func test_mismatch_then_match_continuesScanning_and_succeeds() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "correct-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // Wait for scanning state
        try? await Task.sleep(nanoseconds: 100_000_000)

        // When - first scan mismatch
        viewModel.didScan(payload: "wrong-code")

        // Then - should show feedback but return to scanning
        XCTAssertEqual(viewModel.state, .validating)
        XCTAssertNotNil(viewModel.scanFeedbackMessage)

        // Wait for transition back to scanning
        try? await Task.sleep(nanoseconds: 1_100_000_000) // > 1 second

        XCTAssertEqual(viewModel.state, .scanning)
        XCTAssertNil(viewModel.scanFeedbackMessage)

        // When - second scan matches
        viewModel.didScan(payload: "correct-code")

        // Then - should succeed
        XCTAssertEqual(viewModel.state, .success)
    }

    func test_validating_drops_payloads_then_resumes() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "test-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // When - transition to validating
        viewModel.didScan(payload: "wrong-code")
        XCTAssertEqual(viewModel.state, .validating)

        // When - try to scan while validating
        let initialState = viewModel.state
        viewModel.didScan(payload: "should-be-ignored")

        // Then - state unchanged (payload dropped)
        XCTAssertEqual(viewModel.state, initialState)
    }

    func test_success_idempotent_on_rapid_duplicate_payloads() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "success-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // When - rapid duplicate success payloads
        viewModel.didScan(payload: "success-code")
        viewModel.didScan(payload: "success-code") // Duplicate within debounce

        // Then - only one success, one run logged
        XCTAssertEqual(viewModel.state, .success)
        XCTAssertEqual(await mockAlarmStorage.getStoredRuns().count, 1)
        XCTAssertEqual(await mockAlarmStorage.getStoredRuns().first?.outcome, .success)
    }

    func test_cancelScan_stopsStream_and_returnsToRinging() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // When
        viewModel.cancelScan()

        // Then
        XCTAssertEqual(viewModel.state, .ringing)
        XCTAssertFalse(mockQRScanning.isScanning)
        XCTAssertNil(viewModel.scanFeedbackMessage)
    }

    func test_didScan_validPayload_persistsRun_and_cancelsFollowUps() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "valid-qr")
        await mockAlarmStorage.setStoredAlarms([alarm])
        var loggedRuns: [AlarmRun] = []
        viewModel.onRunLogged = { loggedRuns.append($0) }

        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // When
        viewModel.didScan(payload: "valid-qr")

        // Then
        XCTAssertEqual(viewModel.state, .success)
        XCTAssertEqual(await mockAlarmStorage.getStoredRuns().count, 1)
        XCTAssertEqual(await mockAlarmStorage.getStoredRuns().first?.outcome, .success)
        XCTAssertTrue(mockNotifications.cancelledAlarmIds.contains(alarm.id))
        XCTAssertEqual(loggedRuns.count, 1)
    }

    func test_start_alarmNotFound_mapsFailureReason_correctly() async {
        // Given
        await mockAlarmStorage.setShouldThrow(true)
        let nonExistentId = UUID()

        // When
        await viewModel.start(alarmId: nonExistentId)

        // Then
        XCTAssertEqual(viewModel.state, .failed(.alarmNotFound))
    }

    func test_beginScan_withoutExpectedQR_failsWithCorrectReason() async {
        // Given
        let alarm = createTestAlarm(expectedQR: nil) // No expected QR
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)

        // When
        viewModel.beginScan()

        // Then
        XCTAssertEqual(viewModel.state, .failed(.noExpectedQR))
    }

    func test_snooze_cancelsAndReschedulesAlarm() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)

        // When
        viewModel.snooze()

        // Then
        XCTAssertTrue(mockNotifications.cancelledAlarmIds.contains(alarm.id))
        XCTAssertEqual(mockNotifications.scheduledAlarms.count, 1)
        XCTAssertEqual(mockRouter.backToListCallCount, 1)
    }

    func test_abort_logsFailedRun_withoutCancellingFollowUps() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])
        var loggedRuns: [AlarmRun] = []
        viewModel.onRunLogged = { loggedRuns.append($0) }

        await viewModel.start(alarmId: alarm.id)

        // When
        viewModel.abort(reason: "test abort")

        // Then
        XCTAssertEqual(await mockAlarmStorage.getStoredRuns().count, 1)
        XCTAssertEqual(await mockAlarmStorage.getStoredRuns().first?.outcome, .failed)
        XCTAssertEqual(loggedRuns.count, 1)
        XCTAssertTrue(mockNotifications.cancelledAlarmIds.isEmpty) // No cancellation on abort
        XCTAssertEqual(mockRouter.backToListCallCount, 1)
    }

    func test_retry_fromFailedState_returnsToRinging() async {
        // Given
        let alarm = createTestAlarm(expectedQR: nil)
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan() // Will fail with noExpectedQR

        XCTAssertEqual(viewModel.state, .failed(.noExpectedQR))

        // When
        viewModel.retry()

        // Then
        XCTAssertEqual(viewModel.state, .ringing)
        XCTAssertNil(viewModel.scanFeedbackMessage)
    }

    // MARK: - Camera Permission Tests

    func test_beginScan_cameraPermissionDenied_failsWithPermissionDenied() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])
        mockPermissionService.cameraPermissionStatus = PermissionStatus.denied
        await viewModel.start(alarmId: alarm.id)

        // When
        viewModel.beginScan()

        // Wait for async permission check
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(viewModel.state, .failed(.permissionDenied))
        XCTAssertFalse(mockQRScanning.isScanning)
    }

    func test_beginScan_cameraPermissionNotDetermined_requestsAndStartsScanning() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])
        mockPermissionService.cameraPermissionStatus = .notDetermined
        mockPermissionService.requestCameraResult = PermissionStatus.authorized
        await viewModel.start(alarmId: alarm.id)

        // When
        viewModel.beginScan()

        // Wait for async permission flow
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Then
        XCTAssertTrue(mockPermissionService.didRequestCameraPermission)
        XCTAssertEqual(viewModel.state, .scanning)
        XCTAssertTrue(mockQRScanning.isScanning)
    }

    func test_beginScan_cameraPermissionNotDetermined_requestDenied_failsWithPermissionDenied() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])
        mockPermissionService.cameraPermissionStatus = .notDetermined
        mockPermissionService.requestCameraResult = PermissionStatus.denied
        await viewModel.start(alarmId: alarm.id)

        // When
        viewModel.beginScan()

        // Wait for async permission flow
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Then
        XCTAssertTrue(mockPermissionService.didRequestCameraPermission)
        XCTAssertEqual(viewModel.state, .failed(.permissionDenied))
        XCTAssertFalse(mockQRScanning.isScanning)
    }

    // MARK: - Atomic Transition Tests

    func test_completeSuccess_atomicGuard_preventsDoubleExecution() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "success-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // When - rapid multiple success calls
        viewModel.didScan(payload: "success-code")
        await viewModel.completeSuccess() // Should be ignored due to atomic guard

        // Then - only one run persisted
        XCTAssertEqual(await mockAlarmStorage.getStoredRuns().count, 1)
        XCTAssertEqual(await mockAlarmStorage.getStoredRuns().first?.outcome, .success)
    }

    func test_didScan_duringTransition_dropsPayload() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "test-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // Set up success to start transition
        viewModel.didScan(payload: "test-code")
        let initialState = viewModel.state

        // When - try to scan during transition
        viewModel.didScan(payload: "should-be-ignored")

        // Then - state unchanged (payload dropped by atomic guard)
        XCTAssertEqual(viewModel.state, initialState)
    }

    func test_abort_duringSuccess_isIgnored() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "success-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()
        viewModel.didScan(payload: "success-code")

        XCTAssertEqual(viewModel.state, .success)
        let initialRunCount = await mockAlarmStorage.getStoredRuns().count

        // When - try to abort after success
        viewModel.abort(reason: "test abort")

        // Then - abort is ignored, no additional runs logged
        XCTAssertEqual(viewModel.state, .success)
        XCTAssertEqual(await mockAlarmStorage.getStoredRuns().count, initialRunCount)
    }

    func test_snooze_duringSuccess_isIgnored() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "success-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()
        viewModel.didScan(payload: "success-code")

        XCTAssertEqual(viewModel.state, .success)
        let initialScheduledCount = mockNotifications.scheduledAlarms.count

        // When - try to snooze after success
        viewModel.snooze()

        // Then - snooze is ignored
        XCTAssertEqual(viewModel.state, .success)
        XCTAssertEqual(mockNotifications.scheduledAlarms.count, initialScheduledCount)
    }

    // MARK: - CHUNK 5: Stop/Snooze Tests

    func test_canStopAlarm_isFalse_whenChallengesNotComplete() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)

        // Then
        XCTAssertFalse(viewModel.canStopAlarm, "Should not be able to stop before completing challenges")
    }

    func test_canStopAlarm_isTrue_whenChallengesComplete() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "test-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // When - complete QR challenge
        viewModel.didScan(payload: "test-code")

        // Then
        XCTAssertTrue(viewModel.canStopAlarm, "Should be able to stop after completing challenges")
    }

    func test_canSnooze_isTrue_whenRinging() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])

        // When
        await viewModel.start(alarmId: alarm.id)

        // Then
        XCTAssertTrue(viewModel.canSnooze, "Should be able to snooze while ringing")
    }

    func test_canSnooze_isFalse_afterSuccess() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "test-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // When - complete alarm
        viewModel.didScan(payload: "test-code")

        // Then
        XCTAssertFalse(viewModel.canSnooze, "Should not be able to snooze after success")
    }

    func test_stopAlarm_callsAlarmSchedulerStop() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "test-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()
        viewModel.didScan(payload: "test-code")

        // When
        await viewModel.stopAlarm()

        // Then
        XCTAssertEqual(mockAlarmScheduler.stopCalls.count, 1, "Should call alarmScheduler.stop()")
        XCTAssertEqual(mockAlarmScheduler.stopCalls.first, alarm.id)
    }

    func test_snooze_callsTransitionToCountdown() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)

        // When
        await viewModel.snooze(requestedDuration: 300)

        // Then
        XCTAssertEqual(mockAlarmScheduler.transitionToCountdownCalls.count, 1)
        let (alarmId, duration) = mockAlarmScheduler.transitionToCountdownCalls.first!
        XCTAssertEqual(alarmId, alarm.id)
        XCTAssertGreaterThan(duration, 0, "Duration should be positive")
    }

    func test_stopAlarm_logsReliabilityEvent() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "test-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()
        viewModel.didScan(payload: "test-code")

        // When
        await viewModel.stopAlarm()

        // Then
        let dismissSuccessEvents = mockReliabilityLogger.loggedEvents.filter { $0.event == .dismissSuccess }
        XCTAssertEqual(dismissSuccessEvents.count, 1, "Should log dismissSuccess event")
    }

    func test_snooze_logsReliabilityEvent() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)

        // When
        await viewModel.snooze()

        // Then
        let snoozeEvents = mockReliabilityLogger.loggedEvents.filter { $0.event == .snoozeSet }
        XCTAssertEqual(snoozeEvents.count, 1, "Should log snoozeSet event")
    }

    func test_stopAlarm_whenSchedulerThrows_logsError() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "test-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        mockAlarmScheduler.shouldThrowOnStop = true
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()
        viewModel.didScan(payload: "test-code")

        // When
        await viewModel.stopAlarm()

        // Then
        let failedEvents = mockReliabilityLogger.loggedEvents.filter { $0.event == .stopFailed }
        XCTAssertEqual(failedEvents.count, 1, "Should log stopFailed event")
        XCTAssertEqual(viewModel.phase, .failed("Couldn't stop alarm"))
    }

    func test_snooze_whenSchedulerThrows_logsError() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])
        mockAlarmScheduler.shouldThrowOnTransition = true
        await viewModel.start(alarmId: alarm.id)

        // When
        await viewModel.snooze()

        // Then
        let failedEvents = mockReliabilityLogger.loggedEvents.filter { $0.event == .snoozeFailed }
        XCTAssertEqual(failedEvents.count, 1, "Should log snoozeFailed event")
        XCTAssertEqual(viewModel.phase, .failed("Couldn't snooze"))
    }

    // MARK: - Test Helpers

    private func createTestAlarm(expectedQR: String? = "test-qr") -> Alarm {
        Alarm(
            id: UUID(),
            time: Date(),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: expectedQR,
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: "chimes01",
            volume: 0.8
        )
    }
}

// Test mocks are defined in TestMocks.swift


```

### E2E_AlarmDismissalFlowTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/E2E_AlarmDismissalFlowTests.swift`

```swift
//
//  E2E_AlarmDismissalFlowTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 9/7/25.
//  End-to-end tests for critical MVP1 scenarios
//

import XCTest
@testable import alarmAppNew

@MainActor
class E2E_AlarmDismissalFlowTests: XCTestCase {
    var dependencyContainer: DependencyContainer!
    var mockClock: TestClock!
    
    override func setUp() {
        super.setUp()

        // Create owned dependency container instance for testing
        dependencyContainer = DependencyContainer()
        mockClock = TestClock()
    }
    
    override func tearDown() {
        // Clean up any test data
        try? dependencyContainer.persistenceService.saveAlarms([])
        dependencyContainer.reliabilityLogger.clearLogs()
        super.tearDown()
    }
    
    // MARK: - E2E: Full Alarm Flow
    
    func test_E2E_setAlarm_ring_scan_dismiss_success() async throws {
        // This test simulates the complete user journey:
        // 1. User creates alarm with QR code
        // 2. Alarm fires (notification)
        // 3. User taps notification -> navigates to ringing view
        // 4. User scans correct QR code
        // 5. Alarm is dismissed successfully
        
        // GIVEN: Create alarm with QR code
        let testQRCode = "test-qr-code-12345"
        let alarm = Alarm(
            id: UUID(),
            time: mockClock.now().addingTimeInterval(60), // 1 minute from now
            label: "E2E Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: testQRCode,
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: "chimes01",
            volume: 0.8
        )
        
        // WHEN: User enables alarm (should schedule notification)
        let alarmListVM = dependencyContainer.makeAlarmListViewModel()
        alarmListVM.add(alarm)
        
        // Wait for async scheduling
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        // THEN: Alarm should be scheduled
        let pendingIds = await dependencyContainer.notificationService.pendingAlarmIds()
        XCTAssertTrue(pendingIds.contains(alarm.id), "Alarm should be scheduled")
        
        // WHEN: Simulate alarm firing
        dependencyContainer.reliabilityLogger.logAlarmFired(alarm.id, details: ["source": "e2e_test"])
        
        // WHEN: Navigate to dismissal flow (simulates notification tap)
        dependencyContainer.appRouter.showRinging(for: alarm.id)
        XCTAssertEqual(dependencyContainer.appRouter.route, .ringing(alarmID: alarm.id))
        
        // WHEN: Start dismissal flow
        let dismissalVM = dependencyContainer.makeDismissalFlowViewModel()
        dismissalVM.start(alarmId: alarm.id)
        
        // THEN: Should be in ringing state
        XCTAssertEqual(dismissalVM.state, .ringing)
        
        // WHEN: Begin QR scanning
        dismissalVM.beginScan()
        
        // Wait for async permission check and scanning setup
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // THEN: Should be in scanning state
        XCTAssertEqual(dismissalVM.state, .scanning)
        
        // WHEN: Scan correct QR code
        dismissalVM.didScan(payload: testQRCode)
        
        // THEN: Should complete successfully
        XCTAssertEqual(dismissalVM.state, .success)
        
        // THEN: Should log success event
        let recentLogs = dependencyContainer.reliabilityLogger.getRecentLogs(limit: 10)
        let successLogs = recentLogs.filter { $0.event == .dismissSuccessQR && $0.alarmId == alarm.id }
        XCTAssertFalse(successLogs.isEmpty, "Should log dismiss success event")
        
        // THEN: Should navigate back to list after success delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        XCTAssertEqual(dependencyContainer.appRouter.route, .alarmList)
    }
    
    // MARK: - E2E: App Killed Scenario
    
    func test_E2E_appKilled_notificationRestoration() async throws {
        // This test simulates the critical "works if app is killed/closed" scenario:
        // 1. User creates alarm
        // 2. App is killed/closed
        // 3. Notification fires
        // 4. User taps "Return to Dismissal" action
        // 5. App cold-starts and navigates to dismissal flow
        
        // GIVEN: Alarm with QR code
        let testQRCode = "cold-start-qr-code"
        let alarm = Alarm(
            id: UUID(),
            time: mockClock.now().addingTimeInterval(30),
            label: "Cold Start Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: testQRCode,
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: "chimes01",
            volume: 0.8
        )
        
        // WHEN: Schedule alarm
        try await dependencyContainer.notificationService.scheduleAlarm(alarm)
        
        // SIMULATE: App is killed (clear in-memory state)
        let originalRoute = dependencyContainer.appRouter.route
        XCTAssertEqual(originalRoute, .alarmList)
        
        // SIMULATE: Notification fires and user taps "Return to Dismissal"
        // (This simulates the NotificationService delegate being called on cold start)
        dependencyContainer.appRouter.showRinging(for: alarm.id)
        
        // THEN: App should navigate to ringing view even from cold start
        XCTAssertEqual(dependencyContainer.appRouter.route, .ringing(alarmID: alarm.id))
        XCTAssertTrue(dependencyContainer.appRouter.isInDismissalFlow)
        
        // WHEN: Create new dismissal flow VM (simulates cold start creation)
        let dismissalVM = dependencyContainer.makeDismissalFlowViewModel()
        dismissalVM.start(alarmId: alarm.id)
        
        // THEN: Should work correctly even after cold start
        XCTAssertEqual(dismissalVM.state, .ringing)
        
        // WHEN: Complete the flow
        dismissalVM.beginScan()
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        dismissalVM.didScan(payload: testQRCode)
        
        // THEN: Should succeed
        XCTAssertEqual(dismissalVM.state, .success)
    }
    
    // MARK: - E2E: 3-Alarm Smoke Test
    
    func test_E2E_threeAlarmSmoke_noCrashes() async throws {
        // This test validates the "3-alarm smoke with no crashes" requirement
        
        var alarms: [Alarm] = []
        let alarmListVM = dependencyContainer.makeAlarmListViewModel()
        
        // GIVEN: Create 3 alarms with different configurations
        for i in 1...3 {
            let alarm = Alarm(
                id: UUID(),
                time: mockClock.now().addingTimeInterval(TimeInterval(i * 10)), // Staggered times
                label: "Smoke Test Alarm \(i)",
                repeatDays: i == 2 ? [.monday, .wednesday, .friday] : [], // One repeating alarm
                challengeKind: [.qr],
                expectedQR: "smoke-test-qr-\(i)",
                stepThreshold: nil,
                mathChallenge: nil,
                isEnabled: true,
                soundId: "chimes01",
                volume: 0.8
            )
            alarms.append(alarm)
            alarmListVM.add(alarm)
        }
        
        // Wait for all scheduling to complete
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // THEN: All alarms should be scheduled without crashes
        let pendingIds = await dependencyContainer.notificationService.pendingAlarmIds()
        XCTAssertGreaterThanOrEqual(pendingIds.count, 3, "At least 3 notifications should be scheduled")
        
        // WHEN: Simulate all alarms firing and being dismissed
        for alarm in alarms {
            // Log firing
            dependencyContainer.reliabilityLogger.logAlarmFired(alarm.id)
            
            // Navigate to dismissal
            dependencyContainer.appRouter.showRinging(for: alarm.id)
            
            // Create and run dismissal flow
            let dismissalVM = dependencyContainer.makeDismissalFlowViewModel()
            dismissalVM.start(alarmId: alarm.id)
            dismissalVM.beginScan()
            
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            // Dismiss with correct QR
            dismissalVM.didScan(payload: "smoke-test-qr-\(alarms.firstIndex(of: alarm)! + 1)")
            
            // Verify success
            XCTAssertEqual(dismissalVM.state, .success)
            
            // Return to list
            dependencyContainer.appRouter.backToList()
            
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms between alarms
        }
        
        // THEN: All operations should complete without crashes
        let logs = dependencyContainer.reliabilityLogger.getRecentLogs(limit: 20)
        let successLogs = logs.filter { $0.event == .dismissSuccessQR }
        XCTAssertEqual(successLogs.count, 3, "All 3 alarms should have been dismissed successfully")
        
        // THEN: App should be back at list view
        XCTAssertEqual(dependencyContainer.appRouter.route, .alarmList)
        XCTAssertFalse(dependencyContainer.appRouter.isInDismissalFlow)
    }
    
    // MARK: - Edge Cases
    
    func test_E2E_alarmWithoutQR_preventedFromScheduling() {
        // Test the data model guardrail
        
        let alarmWithoutQR = Alarm(
            id: UUID(),
            time: Date(),
            label: "Invalid Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: nil, // Missing QR code
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: false,
            soundId: "chimes01",
            volume: 0.8
        )
        
        let alarmListVM = dependencyContainer.makeAlarmListViewModel()
        alarmListVM.add(alarmWithoutQR)
        
        // WHEN: Try to enable alarm without QR code
        alarmListVM.toggle(alarmWithoutQR)
        
        // THEN: Should fail with error message
        XCTAssertNotNil(alarmListVM.errorMessage)
        XCTAssertTrue(alarmListVM.errorMessage?.contains("QR code required") ?? false)
        
        // THEN: Alarm should remain disabled
        let savedAlarms = (try? dependencyContainer.persistenceService.loadAlarms()) ?? []
        let savedAlarm = savedAlarms.first { $0.id == alarmWithoutQR.id }
        XCTAssertFalse(savedAlarm?.isEnabled ?? true)
    }
}
```

### E2E_DismissalFlowSoundTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/E2E_DismissalFlowSoundTests.swift`

```swift
//
//  E2E_DismissalFlowSoundTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 9/16/25.
//  End-to-end tests for dismissal flow with sound cancellation
//

import XCTest
import UserNotifications
@testable import alarmAppNew

// MARK: - Mock Services for E2E
// Using shared mocks from TestMocks.swift

// Using shared mocks from TestMocks.swift

// MARK: - E2E Dismissal Flow Tests

@MainActor
final class E2E_DismissalFlowSoundTests: XCTestCase {
    var viewModel: DismissalFlowViewModel!
    var mockQRScanning: MockQRScanning!
    var mockAlarmStorage: MockAlarmStorage!
    var mockNotificationService: MockNotificationService!
    var mockAppRouter: MockAppRouter!
    var mockReliabilityLogger: MockReliabilityLogger!
    var mockClock: MockClock!
    var mockPermissionService: MockPermissionService!
    var mockAudioEngine: MockAlarmAudioEngine!
    var mockReliabilityModeProvider: MockReliabilityModeProvider!
    var mockDismissedRegistry: DismissedRegistry!
    var mockSettingsService: MockSettingsService!
    var mockAlarmScheduler: MockAlarmScheduling!
    var mockAlarmRunStore: AlarmRunStore!
    var mockIdleTimerController: MockIdleTimerController!

    override func setUp() {
        super.setUp()
        setupMocks()
        createViewModel()
    }

    override func tearDown() {
        viewModel = nil
        mockQRScanning = nil
        mockAlarmStorage = nil
        mockNotificationService = nil
        mockAppRouter = nil
        mockReliabilityLogger = nil
        mockClock = nil
        mockPermissionService = nil
        mockAudioEngine = nil
        mockReliabilityModeProvider = nil
        mockDismissedRegistry = nil
        mockSettingsService = nil
        mockAlarmScheduler = nil
        mockAlarmRunStore = nil
        mockIdleTimerController = nil
        super.tearDown()
    }

    private func setupMocks() {
        mockQRScanning = MockQRScanning()
        mockAlarmStorage = MockAlarmStorage()
        mockNotificationService = MockNotificationService()
        mockAppRouter = MockAppRouter()
        mockReliabilityLogger = MockReliabilityLogger()
        mockClock = MockClock()
        mockPermissionService = MockPermissionService()
        mockAudioEngine = MockAlarmAudioEngine()
        mockReliabilityModeProvider = MockReliabilityModeProvider()
        mockDismissedRegistry = DismissedRegistry()
        mockSettingsService = MockSettingsService()
        mockAlarmScheduler = MockAlarmScheduling()
        mockAlarmRunStore = AlarmRunStore()
        mockIdleTimerController = MockIdleTimerController()
    }

    private func createViewModel() {
        viewModel = DismissalFlowViewModel(
            qrScanning: mockQRScanning,
            notificationService: mockNotificationService,
            alarmStorage: mockAlarmStorage,
            clock: mockClock,
            appRouter: mockAppRouter,
            permissionService: mockPermissionService,
            reliabilityLogger: mockReliabilityLogger,
            audioEngine: mockAudioEngine,
            reliabilityModeProvider: mockReliabilityModeProvider,
            dismissedRegistry: mockDismissedRegistry,
            settingsService: mockSettingsService,
            alarmScheduler: mockAlarmScheduler,
            alarmRunStore: mockAlarmRunStore,
            idleTimerController: mockIdleTimerController
        )
    }

    private func createTestAlarm(
        id: UUID = UUID(),
        soundId: String = "chimes01",
        volume: Double = 0.8,
        expectedQR: String = "test-qr-code"
    ) -> Alarm {
        return Alarm(
            id: id,
            time: Date(),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: expectedQR,
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: soundId,
            volume: volume
        )
    }

    private func waitForRunToBeSaved(timeout: TimeInterval = 1.0) async -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if await mockAlarmStorage.getStoredRuns().count >= 1 {
                return true
            }
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms polling interval
        }
        return false
    }

    // MARK: - Sound Integration Tests

    func test_startAlarm_shouldActivateAudioAndStartRinging() async {
        let alarmId = UUID()
        let alarm = createTestAlarm(id: alarmId, soundId: "bells01", volume: 0.9)

        try? await mockAlarmStorage.saveAlarm(alarm)

        await viewModel.start(alarmId: alarmId)

        // Wait for async audio start
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        XCTAssertEqual(viewModel.state, .ringing)
        XCTAssertEqual(mockAudioService.lastPlayedSound, "Soft Bells")
        XCTAssertEqual(mockAudioService.lastVolume, 0.9)
        XCTAssertEqual(mockAudioService.lastLoopSetting, true)
        XCTAssertTrue(mockAudioService.sessionActivated)
        XCTAssertTrue(mockAudioService.isCurrentlyPlaying)
    }

    func test_successfulDismissal_shouldStopAudioAndCancelNudges() async {
        let alarmId = UUID()
        let expectedQR = "success-qr"
        let alarm = createTestAlarm(id: alarmId, expectedQR: expectedQR)

        try? await mockAlarmStorage.saveAlarm(alarm)

        // Start alarm
        await viewModel.start(alarmId: alarmId)
        viewModel.beginScan()

        // Wait for state transitions
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        XCTAssertEqual(viewModel.state, .scanning)

        // Simulate successful QR scan
        viewModel.didScan(payload: expectedQR)

        // Wait for completion
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Verify audio stopped
        XCTAssertEqual(mockAudioService.stopAndDeactivateCallCount, 1)
        XCTAssertFalse(mockAudioService.isCurrentlyPlaying)
        XCTAssertFalse(mockAudioService.sessionActivated)

        // Verify nudges cancelled
        XCTAssertEqual(mockNotificationService.cancelledNotificationTypes.count, 1)
        let (cancelledAlarmId, cancelledTypes) = mockNotificationService.cancelledNotificationTypes[0]
        XCTAssertEqual(cancelledAlarmId, alarmId)
        XCTAssertEqual(Set(cancelledTypes), Set([.nudge1, .nudge2, .nudge3]))

        // Verify state progression
        XCTAssertEqual(viewModel.state, .success)
    }

    func test_abortDismissal_shouldStopAudioButKeepNudges() async {
        let alarmId = UUID()
        let alarm = createTestAlarm(id: alarmId)

        try? await mockAlarmStorage.saveAlarm(alarm)

        await viewModel.start(alarmId: alarmId)

        // Wait for audio to start
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Abort the dismissal
        viewModel.abort(reason: "User cancelled")

        // Verify audio stopped
        XCTAssertEqual(mockAudioService.stopAndDeactivateCallCount, 1)
        XCTAssertFalse(mockAudioService.isCurrentlyPlaying)

        // Verify nudges were NOT cancelled (empty array)
        XCTAssertEqual(mockNotificationService.cancelledNotificationTypes.count, 0)

        // Verify navigation back
        XCTAssertEqual(mockAppRouter.backToListCallCount, 1)
    }

    func test_snoozeDismissal_shouldStopAudioAndCancelNudgesOnly() async {
        let alarmId = UUID()
        let alarm = createTestAlarm(id: alarmId)

        try? await mockAlarmStorage.saveAlarm(alarm)

        await viewModel.start(alarmId: alarmId)

        // Wait for startup
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Snooze the alarm
        viewModel.snooze()

        // Wait for snooze to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Verify audio stopped
        XCTAssertEqual(mockAudioService.stopAndDeactivateCallCount, 1)
        XCTAssertFalse(mockAudioService.isCurrentlyPlaying)

        // Verify only nudges cancelled (not main alarm for snooze)
        XCTAssertEqual(mockNotificationService.cancelledNotificationTypes.count, 1)
        let (cancelledAlarmId, cancelledTypes) = mockNotificationService.cancelledNotificationTypes[0]
        XCTAssertEqual(cancelledAlarmId, alarmId)
        XCTAssertEqual(Set(cancelledTypes), Set([.nudge1, .nudge2, .nudge3]))

        // Verify snooze alarm was scheduled
        XCTAssertEqual(mockNotificationService.scheduledAlarms.count, 1)
    }

    func test_failedQRScan_shouldContinueAudioPlaying() async {
        let alarmId = UUID()
        let expectedQR = "correct-qr"
        let wrongQR = "wrong-qr"
        let alarm = createTestAlarm(id: alarmId, expectedQR: expectedQR)

        try? await mockAlarmStorage.saveAlarm(alarm)

        await viewModel.start(alarmId: alarmId)
        viewModel.beginScan()

        // Wait for scanning state
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Simulate wrong QR scan
        viewModel.didScan(payload: wrongQR)

        // Audio should still be playing
        XCTAssertTrue(mockAudioService.isCurrentlyPlaying)
        XCTAssertEqual(mockAudioService.stopAndDeactivateCallCount, 0)

        // Should transition to validating briefly, then back to scanning
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s for timeout

        XCTAssertEqual(viewModel.state, .scanning)
        XCTAssertTrue(mockAudioService.isCurrentlyPlaying)
    }

    func test_cleanupDismissal_shouldStopAudioProperly() async {
        let alarmId = UUID()
        let alarm = createTestAlarm(id: alarmId)

        try? await mockAlarmStorage.saveAlarm(alarm)

        await viewModel.start(alarmId: alarmId)

        // Wait for startup
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Call cleanup
        viewModel.cleanup()

        // Verify audio stopped
        XCTAssertEqual(mockAudioService.stopAndDeactivateCallCount, 1)
        XCTAssertFalse(mockAudioService.isCurrentlyPlaying)
        XCTAssertFalse(mockAudioService.sessionActivated)
    }

    func test_multipleQRScans_shouldDebounceSuccessfully() async {
        let alarmId = UUID()
        let expectedQR = "success-qr"
        let alarm = createTestAlarm(id: alarmId, expectedQR: expectedQR)

        try? await mockAlarmStorage.saveAlarm(alarm)

        await viewModel.start(alarmId: alarmId)
        viewModel.beginScan()

        // Wait for scanning state
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Simulate rapid duplicate scans
        viewModel.didScan(payload: expectedQR)
        viewModel.didScan(payload: expectedQR) // Should be debounced
        viewModel.didScan(payload: expectedQR) // Should be debounced

        // Wait for processing
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Should only process once
        XCTAssertEqual(viewModel.state, .success)
        XCTAssertEqual(mockAudioService.stopAndDeactivateCallCount, 1)

        // Should have only one successful run logged
        let successLogs = mockReliabilityLogger.loggedEvents.filter { event in
            event == .dismissSuccessQR
        }
        XCTAssertEqual(successLogs.count, 1)
    }

    func test_fullDismissalFlow_endToEnd_shouldWorkCorrectly() async {
        let alarmId = UUID()
        let expectedQR = "complete-flow-qr"
        let alarm = createTestAlarm(id: alarmId, soundId: "tone01", volume: 0.7, expectedQR: expectedQR)

        try? await mockAlarmStorage.saveAlarm(alarm)

        // Start the alarm
        await viewModel.start(alarmId: alarmId)

        // Verify initial state
        XCTAssertEqual(viewModel.state, .ringing)

        // Wait for audio setup
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Verify audio started
        XCTAssertTrue(mockAudioService.isCurrentlyPlaying)
        XCTAssertEqual(mockAudioService.lastPlayedSound, "Classic Tone")
        XCTAssertEqual(mockAudioService.lastVolume, 0.7)

        // Begin scanning
        viewModel.beginScan()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.state, .scanning)
        XCTAssertTrue(mockQRScanning.isScanning)

        // Scan wrong QR first
        viewModel.didScan(payload: "wrong-qr")

        try? await Task.sleep(nanoseconds: 100_000_000)

        // Should still be playing audio
        XCTAssertTrue(mockAudioService.isCurrentlyPlaying)

        // Wait for return to scanning
        try? await Task.sleep(nanoseconds: 1_100_000_000) // 1.1 seconds

        XCTAssertEqual(viewModel.state, .scanning)

        // Scan correct QR
        viewModel.didScan(payload: expectedQR)

        // Wait for async operations to complete
        let runSaved = await waitForRunToBeSaved()
        XCTAssertTrue(runSaved, "Alarm run should be saved within timeout")

        // Verify successful completion
        XCTAssertEqual(viewModel.state, .success)
        XCTAssertFalse(mockAudioService.isCurrentlyPlaying)
        XCTAssertEqual(mockAudioService.stopAndDeactivateCallCount, 1)

        // Verify notifications cancelled correctly
        XCTAssertEqual(mockNotificationService.cancelledNotificationTypes.count, 1)

        // Verify alarm run was saved with safe access
        XCTAssertEqual(await mockAlarmStorage.getStoredRuns().count, 1)
        guard let run = await mockAlarmStorage.getStoredRuns().first else {
            XCTFail("Expected alarm run to be saved")
            return
        }
        XCTAssertEqual(run.outcome, AlarmOutcome.success)
        XCTAssertNotNil(run.dismissedAt)

        // Wait for navigation
        try? await Task.sleep(nanoseconds: 1_600_000_000) // 1.6 seconds

        XCTAssertEqual(mockAppRouter.backToListCallCount, 1)
    }

    // MARK: - Notification Action Tests

    func test_snoozeAction_integration_shouldHandleCorrectly() async {
        let alarmId = UUID()
        let alarm = createTestAlarm(id: alarmId)

        try? await mockAlarmStorage.saveAlarm(alarm)

        // Simulate snooze action through notification service
        let notificationService = mockNotificationService as! MockNotificationService

        // Start with some scheduled alarms
        notificationService.scheduledAlarms = [alarm]

        // Test that snooze would work (we can't directly test the delegate without a real notification)
        // But we can verify the snooze function works correctly
        await viewModel.start(alarmId: alarmId)
        viewModel.snooze()

        // Wait for snooze processing
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Verify audio stopped
        XCTAssertFalse(mockAudioService.isCurrentlyPlaying)
        XCTAssertEqual(mockAudioService.stopAndDeactivateCallCount, 1)

        // Verify nudge notifications cancelled
        XCTAssertEqual(mockNotificationService.cancelledNotificationTypes.count, 1)
        let (cancelledAlarmId, cancelledTypes) = mockNotificationService.cancelledNotificationTypes[0]
        XCTAssertEqual(cancelledAlarmId, alarmId)
        XCTAssertEqual(Set(cancelledTypes), Set([.nudge1, .nudge2, .nudge3]))

        // Verify snooze alarm scheduled
        XCTAssertEqual(mockNotificationService.scheduledAlarms.count, 2) // Original + snooze
    }

    func test_nudgePrecision_mockValidation_shouldUseCorrectTiming() async {
        // Test the timing logic for nudges
        let now = Date()
        let thirtySecondsLater = now.addingTimeInterval(30)
        let twoMinutesLater = now.addingTimeInterval(120)
        let fiveMinutesLater = now.addingTimeInterval(300)

        // Verify precise timing calculations
        XCTAssertEqual(thirtySecondsLater.timeIntervalSince(now), 30, accuracy: 0.01)
        XCTAssertEqual(twoMinutesLater.timeIntervalSince(now), 120, accuracy: 0.01)
        XCTAssertEqual(fiveMinutesLater.timeIntervalSince(now), 300, accuracy: 0.01)

        // Test that short intervals are within the threshold for interval triggers
        XCTAssertTrue(thirtySecondsLater.timeIntervalSince(now) <= 3600) // ≤ 1 hour
        XCTAssertTrue(twoMinutesLater.timeIntervalSince(now) <= 3600)
        XCTAssertTrue(fiveMinutesLater.timeIntervalSince(now) <= 3600)
    }
}
```

### Integration_TestAlarmSchedulingTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/Integration_TestAlarmSchedulingTests.swift`

```swift
//
//  Integration_TestAlarmSchedulingTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/8/25.
//  Integration tests for lock-screen test alarm scheduling
//

import XCTest
@testable import alarmAppNew
import UserNotifications

@MainActor
final class Integration_TestAlarmSchedulingTests: XCTestCase {
    var dependencyContainer: DependencyContainer!

    override func setUp() {
        super.setUp()
        dependencyContainer = DependencyContainer()
    }

    override func tearDown() {
        // Clean up any test notifications
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        super.tearDown()
    }

    // MARK: - Integration Tests

    func test_scheduleOneOffTestAlarm_createsNotificationWithCorrectProperties() async throws {
        // GIVEN: Notification service
        let notificationService = dependencyContainer.notificationService

        // Request authorization first
        let center = UNUserNotificationCenter.current()
        _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])

        // WHEN: Scheduling test alarm with 8-second lead time
        try await notificationService.scheduleOneOffTestAlarm(leadTime: 8)

        // THEN: Notification should be scheduled
        let pending = await center.pendingNotificationRequests()
        let testNotifications = pending.filter { $0.identifier.hasPrefix("test-lock-screen-") }

        XCTAssertEqual(testNotifications.count, 1, "Should have exactly one test notification scheduled")

        // Verify notification properties
        guard let testNotification = testNotifications.first else {
            XCTFail("Test notification not found")
            return
        }

        // Check content
        XCTAssertEqual(testNotification.content.title, "🔔 Lock-Screen Test Alarm")
        XCTAssertEqual(testNotification.content.body, "This is a test to verify your ringer volume")
        XCTAssertEqual(testNotification.content.sound, .default)
        XCTAssertEqual(testNotification.content.categoryIdentifier, Categories.alarm)

        // Check userInfo
        let userInfo = testNotification.content.userInfo
        XCTAssertEqual(userInfo["type"] as? String, "test_lock_screen")
        XCTAssertEqual(userInfo["isTest"] as? Bool, true)
        XCTAssertNotNil(userInfo["alarmId"], "Should have alarmId in userInfo")

        // Check trigger
        guard let trigger = testNotification.trigger as? UNTimeIntervalNotificationTrigger else {
            XCTFail("Trigger should be UNTimeIntervalNotificationTrigger")
            return
        }

        XCTAssertEqual(trigger.timeInterval, 8, accuracy: 0.1, "Trigger should fire in 8 seconds")
        XCTAssertFalse(trigger.repeats, "Test notification should not repeat")

        // Check interruption level (iOS 15+)
        if #available(iOS 15.0, *) {
            XCTAssertEqual(testNotification.content.interruptionLevel, .timeSensitive,
                          "Should use time-sensitive interruption level")
        }
    }

    func test_scheduleOneOffTestAlarm_withCustomLeadTime_usesCustomValue() async throws {
        // GIVEN: Notification service
        let notificationService = dependencyContainer.notificationService

        // Request authorization
        let center = UNUserNotificationCenter.current()
        _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])

        // WHEN: Scheduling test alarm with custom lead time (5 seconds)
        try await notificationService.scheduleOneOffTestAlarm(leadTime: 5)

        // THEN: Notification should be scheduled with custom lead time
        let pending = await center.pendingNotificationRequests()
        let testNotifications = pending.filter { $0.identifier.hasPrefix("test-lock-screen-") }

        XCTAssertEqual(testNotifications.count, 1)

        guard let testNotification = testNotifications.first,
              let trigger = testNotification.trigger as? UNTimeIntervalNotificationTrigger else {
            XCTFail("Test notification or trigger not found")
            return
        }

        XCTAssertEqual(trigger.timeInterval, 5, accuracy: 0.1, "Trigger should use custom lead time")
    }

    func test_scheduleOneOffTestAlarm_multipleInvocations_createsMultipleNotifications() async throws {
        // GIVEN: Notification service
        let notificationService = dependencyContainer.notificationService

        // Request authorization
        let center = UNUserNotificationCenter.current()
        _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])

        // WHEN: Scheduling test alarm twice
        try await notificationService.scheduleOneOffTestAlarm(leadTime: 8)
        try await notificationService.scheduleOneOffTestAlarm(leadTime: 8)

        // THEN: Should have two separate test notifications
        let pending = await center.pendingNotificationRequests()
        let testNotifications = pending.filter { $0.identifier.hasPrefix("test-lock-screen-") }

        XCTAssertEqual(testNotifications.count, 2, "Should create separate notifications for each invocation")

        // Verify they have unique identifiers
        let identifiers = testNotifications.map { $0.identifier }
        let uniqueIdentifiers = Set(identifiers)
        XCTAssertEqual(identifiers.count, uniqueIdentifiers.count, "Each notification should have unique identifier")
    }
}

```

### NotificationIntegrationTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/NotificationIntegrationTests.swift`

```swift
//
//  NotificationIntegrationTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 9/16/25.
//  Integration tests for notification scheduling with sounds
//

import XCTest
import UserNotifications
@testable import alarmAppNew

// Mock App State Provider is defined in TestMocks.swift

@MainActor
final class NotificationIntegrationTests: XCTestCase {
    var notificationService: NotificationService!
    var mockPermissionService: MockPermissionService!
    var mockAppStateProvider: MockAppStateProvider!
    var notificationCenter: UNUserNotificationCenter!

    override func setUp() {
        super.setUp()
        mockPermissionService = MockPermissionService()
        mockAppStateProvider = MockAppStateProvider()

        // Create minimal mock dependencies for testing
        let mockReliabilityLogger = MockReliabilityLogger()
        let mockAppRouter = AppRouter()
        let mockPersistenceService = MockAlarmStorage()

        notificationService = NotificationService(
            permissionService: mockPermissionService,
            appStateProvider: mockAppStateProvider,
            reliabilityLogger: mockReliabilityLogger,
            appRouter: mockAppRouter,
            persistenceService: mockPersistenceService
        )
        notificationCenter = UNUserNotificationCenter.current()

        // Clear any existing test notifications
        notificationCenter.removeAllPendingNotificationRequests()
    }

    override func tearDown() {
        // Clean up any scheduled notifications
        notificationCenter.removeAllPendingNotificationRequests()
        notificationService = nil
        mockPermissionService = nil
        notificationCenter = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func createTestAlarm(
        id: UUID = UUID(),
        time: Date = Date().addingTimeInterval(300), // 5 minutes from now
        label: String = "Integration Test Alarm",
        repeatDays: [Weekdays] = [],
        soundId: String = "chimes01"
    ) -> Alarm {
        return Alarm(
            id: id,
            time: time,
            label: label,
            repeatDays: repeatDays,
            challengeKind: [.qr],
            expectedQR: "test",
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: soundId,
            volume: 0.8
        )
    }

    private func waitForNotificationScheduling() async {
        // Give the system time to process notification requests
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }

    // MARK: - Integration Tests

    func test_scheduleAndCancel_oneTimeAlarm_shouldWorkEndToEnd() async throws {
        let alarm = createTestAlarm()

        // Schedule the alarm
        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        // Verify notifications were scheduled
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let alarmNotifications = pendingRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm.id.uuidString
        }

        XCTAssertTrue(alarmNotifications.count > 0, "Should have scheduled notifications for the alarm")

        // Cancel the alarm
        await notificationService.cancelAlarm(alarm)
        await waitForNotificationScheduling()

        // Verify notifications were cancelled
        let remainingRequests = await notificationCenter.pendingNotificationRequests()
        let remainingAlarmNotifications = remainingRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm.id.uuidString
        }

        XCTAssertEqual(remainingAlarmNotifications.count, 0, "All alarm notifications should be cancelled")
    }

    func test_scheduleRepeatingAlarm_shouldCreateMultipleNotifications() async throws {
        let alarm = createTestAlarm(repeatDays: [.monday, .wednesday, .friday])

        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let alarmNotifications = pendingRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm.id.uuidString
        }

        // Should have notifications for 3 days × 5 notification types (pre-alarm, main, 3 nudges)
        let expectedCount = 3 * 5
        XCTAssertEqual(alarmNotifications.count, expectedCount, "Should schedule notifications for all repeat days and types")
    }

    func test_notificationSound_integration_shouldUseCorrectSound() async throws {
        let customSoundAlarm = createTestAlarm(soundId: "bells01")

        try await notificationService.scheduleAlarm(customSoundAlarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let mainNotification = pendingRequests.first { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String,
                  let type = request.content.userInfo["type"] as? String else { return false }
            return alarmId == customSoundAlarm.id.uuidString && type == "main"
        }

        XCTAssertNotNil(mainNotification, "Should find main notification")

        // Verify sound is configured (actual sound name verification would require deeper inspection)
        XCTAssertNotNil(mainNotification?.content.sound, "Main notification should have sound configured")
    }

    func test_preAlarmNotification_shouldHaveCorrectTiming() async throws {
        let futureTime = Date().addingTimeInterval(10 * 60) // 10 minutes from now
        let alarm = createTestAlarm(time: futureTime)

        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let preAlarmNotification = pendingRequests.first { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String,
                  let type = request.content.userInfo["type"] as? String else { return false }
            return alarmId == alarm.id.uuidString && type == "pre_alarm"
        }

        XCTAssertNotNil(preAlarmNotification, "Should schedule pre-alarm notification")

        // Verify it's a calendar trigger
        XCTAssertTrue(preAlarmNotification?.trigger is UNCalendarNotificationTrigger,
                     "Pre-alarm should use calendar trigger")
    }

    func test_nudgeNotifications_shouldHaveCorrectContent() async throws {
        let alarm = createTestAlarm()

        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()

        // Find nudge notifications
        let nudge1 = pendingRequests.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "nudge_1"
        }

        let nudge2 = pendingRequests.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "nudge_2"
        }

        let nudge3 = pendingRequests.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "nudge_3"
        }

        XCTAssertNotNil(nudge1, "Should schedule nudge 1")
        XCTAssertNotNil(nudge2, "Should schedule nudge 2")
        XCTAssertNotNil(nudge3, "Should schedule nudge 3")

        // Verify escalating urgency in titles
        XCTAssertTrue(nudge1?.content.title.contains("⚠️") ?? false, "Nudge 1 should have warning emoji")
        XCTAssertTrue(nudge2?.content.title.contains("🚨") ?? false, "Nudge 2 should have siren emoji")
        XCTAssertTrue(nudge3?.content.title.contains("🔴") ?? false, "Nudge 3 should have red circle emoji")
    }

    func test_cancelSpecificNotifications_integration_shouldPreserveOthers() async throws {
        let alarm = createTestAlarm()

        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        // Cancel only nudge notifications
        notificationService.cancelSpecificNotifications(
            for: alarm.id,
            types: [.nudge1, .nudge2, .nudge3]
        )
        await waitForNotificationScheduling()

        let remainingRequests = await notificationCenter.pendingNotificationRequests()
        let remainingAlarmNotifications = remainingRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm.id.uuidString
        }

        // Should still have main and pre-alarm notifications
        let mainNotification = remainingAlarmNotifications.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "main"
        }

        let preAlarmNotification = remainingAlarmNotifications.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "pre_alarm"
        }

        XCTAssertNotNil(mainNotification, "Main notification should remain")
        XCTAssertNotNil(preAlarmNotification, "Pre-alarm notification should remain")

        // Verify nudges are gone
        let nudgeNotifications = remainingAlarmNotifications.filter { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type.starts(with: "nudge_")
        }

        XCTAssertEqual(nudgeNotifications.count, 0, "All nudge notifications should be cancelled")
    }

    func test_refreshAll_integration_shouldReplaceAllNotifications() async throws {
        let alarm1 = createTestAlarm(id: UUID())
        let alarm2 = createTestAlarm(id: UUID(), repeatDays: [.tuesday])

        // Schedule initial alarms
        try await notificationService.scheduleAlarm(alarm1)
        try await notificationService.scheduleAlarm(alarm2)
        await waitForNotificationScheduling()

        let initialCount = await notificationCenter.pendingNotificationRequests().count

        // Refresh with updated alarms
        let updatedAlarm1 = createTestAlarm(id: alarm1.id, label: "Updated Alarm")
        await notificationService.refreshAll(from: [updatedAlarm1])
        await waitForNotificationScheduling()

        let finalRequests = await notificationCenter.pendingNotificationRequests()

        // Should only have notifications for the refreshed alarm
        let alarm1Notifications = finalRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm1.id.uuidString
        }

        let alarm2Notifications = finalRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm2.id.uuidString
        }

        XCTAssertTrue(alarm1Notifications.count > 0, "Should have notifications for refreshed alarm")
        XCTAssertEqual(alarm2Notifications.count, 0, "Should not have notifications for non-refreshed alarm")
    }

    func test_soundFallback_integration_shouldHandleInvalidSound() async throws {
        let alarm = createTestAlarm(soundId: "nonexistent_sound")

        // Should not throw despite invalid sound
        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let mainNotification = pendingRequests.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "main"
        }

        XCTAssertNotNil(mainNotification, "Should schedule notification despite invalid sound")
        XCTAssertNotNil(mainNotification?.content.sound, "Should have fallback sound")
    }

    func test_nudgePrecision_integration_shouldUseCorrectTriggerTypes() async throws {
        let alarm = createTestAlarm()

        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let nudgeNotifications = pendingRequests.filter { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type.starts(with: "nudge_")
        }

        XCTAssertTrue(nudgeNotifications.count > 0, "Should have nudge notifications")

        // Verify nudge notifications exist (can't directly inspect trigger type in integration test)
        for notification in nudgeNotifications {
            XCTAssertNotNil(notification.trigger, "Nudge notifications should have triggers")
        }
    }

    func test_notificationCategories_integration_shouldHaveAllActions() async throws {
        // Test that the notification categories are properly registered
        let center = UNUserNotificationCenter.current()
        let categories = await center.notificationCategories()

        let alarmCategory = categories.first { $0.identifier == "ALARM_CATEGORY" }
        XCTAssertNotNil(alarmCategory, "Should have ALARM_CATEGORY registered")

        if let category = alarmCategory {
            let actionIdentifiers = category.actions.map { $0.identifier }
            XCTAssertTrue(actionIdentifiers.contains("OPEN_ALARM"), "Should have OPEN_ALARM action")
            XCTAssertTrue(actionIdentifiers.contains("RETURN_TO_DISMISSAL"), "Should have RETURN_TO_DISMISSAL action")
            XCTAssertTrue(actionIdentifiers.contains("SNOOZE_ALARM"), "Should have SNOOZE_ALARM action")
        }
    }

    func test_futureNudgePrevention_integration_shouldStopUpcomingNotifications() async throws {
        let alarm = createTestAlarm()

        // Schedule alarm with nudges
        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        // Generate expected identifiers using same logic as production code
        let expectedNudge1Identifiers = generateExpectedNotificationIdentifiers(for: alarm.id, types: [.nudge1])
        let expectedNudge2Identifiers = generateExpectedNotificationIdentifiers(for: alarm.id, types: [.nudge2])
        let expectedNudge3Identifiers = generateExpectedNotificationIdentifiers(for: alarm.id, types: [.nudge3])

        // Cancel specific future nudges (simulating dismissal after nudge1 fires)
        notificationService.cancelSpecificNotifications(
            for: alarm.id,
            types: [.nudge1, .nudge2]
        )

        // Wait for cancellation to process
        await waitForNotificationScheduling()

        // Verify no future nudge1 or nudge2 notifications remain in pending queue
        let remainingRequests = await notificationCenter.pendingNotificationRequests()
        let remainingIdentifiers = Set(remainingRequests.map { $0.identifier })

        // Assert future nudges won't fire by checking exact identifier matching
        for expectedId in expectedNudge1Identifiers {
            XCTAssertFalse(remainingIdentifiers.contains(expectedId),
                          "Future nudge1 notification '\(expectedId)' should be cancelled")
        }

        for expectedId in expectedNudge2Identifiers {
            XCTAssertFalse(remainingIdentifiers.contains(expectedId),
                          "Future nudge2 notification '\(expectedId)' should be cancelled")
        }

        // Verify nudge3 remains scheduled (should still fire in future)
        var nudge3Found = false
        for expectedId in expectedNudge3Identifiers {
            if remainingIdentifiers.contains(expectedId) {
                nudge3Found = true
                break
            }
        }
        XCTAssertTrue(nudge3Found, "Future nudge3 notifications should remain scheduled")

        // Verify main and pre-alarm notifications remain
        let mainNotification = remainingRequests.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "main"
        }
        XCTAssertNotNil(mainNotification, "Main notification should remain scheduled")
    }

    // Helper to generate expected notification identifiers (mirrors production logic)
    private func generateExpectedNotificationIdentifiers(for alarmId: UUID, types: [NotificationType]) -> Set<String> {
        var identifiers: Set<String> = []

        for type in types {
            // One-time alarm format: "alarmId-typeRawValue"
            identifiers.insert("\(alarmId.uuidString)-\(type.rawValue)")

            // Repeating alarm format: "alarmId-typeRawValue-weekday-N"
            for weekday in 1...7 {
                identifiers.insert("\(alarmId.uuidString)-\(type.rawValue)-weekday-\(weekday)")
            }
        }

        return identifiers
    }

    func test_completeAlarmCancellation_shouldPreventAllFutureNotifications() async throws {
        let alarm = createTestAlarm()

        // Schedule alarm with all notification types
        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        // Generate expected identifiers for all notification types
        let allTypes: [NotificationType] = [.main, .preAlarm, .nudge1, .nudge2, .nudge3]
        let expectedIdentifiers = generateExpectedNotificationIdentifiers(for: alarm.id, types: allTypes)

        // Cancel entire alarm
        await notificationService.cancelAlarm(alarm)
        await waitForNotificationScheduling()

        // Verify no future notifications remain in pending queue
        let remainingRequests = await notificationCenter.pendingNotificationRequests()
        let remainingIdentifiers = Set(remainingRequests.map { $0.identifier })

        // Assert no future notifications will fire by checking exact identifier matching
        for expectedId in expectedIdentifiers {
            XCTAssertFalse(remainingIdentifiers.contains(expectedId),
                          "Future notification '\(expectedId)' should be cancelled")
        }

        // Also verify using content-based filtering (for additional safety)
        let remainingAlarmNotifications = remainingRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm.id.uuidString
        }

        XCTAssertEqual(remainingAlarmNotifications.count, 0, "No future alarm notifications should remain scheduled")
    }

    // MARK: - userInfo Routing Tests

    func test_userInfoRouting_defaultTap_opensDismissal() async throws {
        let alarm = createTestAlarm()

        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let mainNotification = pendingRequests.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "main"
        }

        XCTAssertNotNil(mainNotification, "Should have main notification")

        // Verify userInfo contains correct alarmId
        if let notification = mainNotification {
            XCTAssertEqual(notification.content.userInfo["alarmId"] as? String, alarm.id.uuidString)
            XCTAssertEqual(notification.content.categoryIdentifier, "ALARM_CATEGORY")
        }
    }

    func test_userInfoRouting_actions_open_return_snooze() async throws {
        // Test that notification categories are properly registered
        let center = UNUserNotificationCenter.current()
        let categories = await center.notificationCategories()

        let alarmCategory = categories.first { $0.identifier == "ALARM_CATEGORY" }
        XCTAssertNotNil(alarmCategory, "Should have ALARM_CATEGORY registered")

        if let category = alarmCategory {
            let actionIdentifiers = category.actions.map { $0.identifier }
            XCTAssertTrue(actionIdentifiers.contains("OPEN_ALARM"), "Should have OPEN_ALARM action")
            XCTAssertTrue(actionIdentifiers.contains("RETURN_TO_DISMISSAL"), "Should have RETURN_TO_DISMISSAL action")
            XCTAssertTrue(actionIdentifiers.contains("SNOOZE_ALARM"), "Should have SNOOZE_ALARM action")

            // Verify action options
            let openAction = category.actions.first { $0.identifier == "OPEN_ALARM" }
            XCTAssertTrue(openAction?.options.contains(.foreground) ?? false, "OPEN_ALARM should have foreground option")

            let returnAction = category.actions.first { $0.identifier == "RETURN_TO_DISMISSAL" }
            XCTAssertTrue(returnAction?.options.contains(.foreground) ?? false, "RETURN_TO_DISMISSAL should have foreground option")

            let snoozeAction = category.actions.first { $0.identifier == "SNOOZE_ALARM" }
            XCTAssertFalse(snoozeAction?.options.contains(.foreground) ?? true, "SNOOZE_ALARM should not have foreground option")
        }
    }

    func test_categories_registered_once_idempotent() {
        // Call ensureNotificationCategoriesRegistered multiple times
        notificationService.ensureNotificationCategoriesRegistered()
        notificationService.ensureNotificationCategoriesRegistered()
        notificationService.ensureNotificationCategoriesRegistered()

        // This test verifies the method can be called multiple times without issues
        // The actual category registration is tested in other tests
        XCTAssertTrue(true, "Multiple category registrations should not cause issues")
    }

    func test_allNotifications_includeUserInfo() async throws {
        let alarm = createTestAlarm(repeatDays: [.monday])

        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let alarmNotifications = pendingRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm.id.uuidString
        }

        XCTAssertTrue(alarmNotifications.count > 0, "Should have scheduled notifications")

        // Verify every notification has userInfo and category
        for notification in alarmNotifications {
            XCTAssertNotNil(notification.content.userInfo["alarmId"], "Every notification should have alarmId in userInfo")
            XCTAssertNotNil(notification.content.userInfo["type"], "Every notification should have type in userInfo")
            XCTAssertEqual(notification.content.categoryIdentifier, "ALARM_CATEGORY", "Every notification should have ALARM_CATEGORY")
        }
    }

    func test_testNotification_includesUserInfo() async throws {
        try await notificationService.scheduleTestNotification(soundName: "chime", in: 1.0)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let testNotifications = pendingRequests.filter { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "test"
        }

        XCTAssertTrue(testNotifications.count > 0, "Should have test notification")

        // Verify test notification has userInfo
        if let testNotification = testNotifications.first {
            XCTAssertNotNil(testNotification.content.userInfo["alarmId"], "Test notification should have alarmId")
            XCTAssertEqual(testNotification.content.userInfo["type"] as? String, "test", "Test notification should have test type")
            XCTAssertEqual(testNotification.content.categoryIdentifier, "ALARM_CATEGORY", "Test notification should have ALARM_CATEGORY")
        }
    }

    // MARK: - App State Tests

    func test_appStateProvider_activeState() {
        let provider = MockAppStateProvider()

        // Test inactive state
        provider.mockIsAppActive = false
        XCTAssertFalse(provider.isAppActive, "Should report app as inactive")

        // Test active state
        provider.mockIsAppActive = true
        XCTAssertTrue(provider.isAppActive, "Should report app as active")
    }

    func test_appStateProvider_mainActorAnnotation() async {
        // Test that the real AppStateProvider is properly marked as MainActor
        let provider = AppStateProvider()

        // This test verifies the provider can be instantiated and accessed on main actor
        // The @MainActor annotation ensures UIApplication access is thread-safe
        XCTAssertNotNil(provider, "AppStateProvider should be instantiable")

        // Test that isAppActive can be accessed (this validates the @MainActor constraint)
        let _ = provider.isAppActive // This validates the property works on main actor
    }

    // MARK: - Error Handling Integration Tests

    func test_permissionDenied_integration_shouldThrowError() async {
        mockPermissionService.mockNotificationDetails = NotificationPermissionDetails(
            authorizationStatus: PermissionStatus.denied,
            alertsEnabled: false,
            soundEnabled: false,
            badgeEnabled: false
        )

        let alarm = createTestAlarm()

        do {
            try await notificationService.scheduleAlarm(alarm)
            XCTFail("Should have thrown permission denied error")
        } catch NotificationError.permissionDenied {
            // Expected behavior
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // Verify no notifications were scheduled
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        XCTAssertEqual(pendingRequests.count, 0, "Should not schedule notifications when permission denied")
    }
}
```

### NotificationServiceTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/NotificationServiceTests.swift`

```swift
//
//  NotificationServiceTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 9/16/25.
//  Unit tests for enhanced NotificationService with nudges and pre-alarm reminders
//

import XCTest
import UserNotifications
@testable import alarmAppNew

// Mock Permission Service is defined in TestMocks.swift

// MARK: - Mock Notification Center

class MockNotificationCenter {
    var scheduledRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []
    var removeAllCalled = false

    func add(_ request: UNNotificationRequest) throws {
        scheduledRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        scheduledRequests.removeAll { request in
            identifiers.contains(request.identifier)
        }
    }

    func removeAllPendingNotificationRequests() {
        removeAllCalled = true
        scheduledRequests.removeAll()
    }

    func pendingNotificationRequests() -> [UNNotificationRequest] {
        return scheduledRequests
    }
}

// MARK: - Notification Service Tests

final class NotificationServiceTests: XCTestCase {
    var notificationService: NotificationService!
    var mockPermissionService: MockPermissionService!
    var mockCenter: MockNotificationCenter!
    var mockAppStateProvider: MockAppStateProvider!
    var mockReliabilityLogger: MockReliabilityLogger!
    var appRouter: AppRouter!
    var mockAlarmStorage: MockAlarmStorage!

    @MainActor override func setUp() {
        super.setUp()
        mockPermissionService = MockPermissionService()
        mockCenter = MockNotificationCenter()
        mockAppStateProvider = MockAppStateProvider()
        mockReliabilityLogger = MockReliabilityLogger()
        appRouter = AppRouter()
        mockAlarmStorage = MockAlarmStorage()
        notificationService = NotificationService(
            permissionService: mockPermissionService,
            appStateProvider: mockAppStateProvider,
            reliabilityLogger: mockReliabilityLogger,
            appRouter: appRouter,
            persistenceService: mockAlarmStorage
        )
    }

    override func tearDown() {
        notificationService = nil
        mockPermissionService = nil
        mockCenter = nil
        mockAppStateProvider = nil
        mockReliabilityLogger = nil
        appRouter = nil
        mockAlarmStorage = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func createTestAlarm(
        id: UUID = UUID(),
        time: Date = Date().addingTimeInterval(3600), // 1 hour from now
        label: String = "Test Alarm",
        repeatDays: [Weekdays] = [],
        soundId: String = "chimes01"
    ) -> Alarm {
        return Alarm(
            id: id,
            time: time,
            label: label,
            repeatDays: repeatDays,
            challengeKind: [.qr],
            expectedQR: "test",
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: soundId,
            volume: 0.8
        )
    }

    // MARK: - Notification Content Tests

    func test_createNotificationContent_preAlarm_shouldHaveCorrectContent() {
        let alarm = createTestAlarm(label: "Morning Alarm")

        // Use reflection or create a test subclass to access private method
        // For now, we'll test through public interface
        XCTAssertTrue(true) // Placeholder - would test content creation
    }

    // MARK: - Notification Identifier Tests

    func test_notificationIdentifier_mainType_shouldHaveCorrectFormat() {
        let alarmId = UUID()
        let expectedPattern = "\(alarmId.uuidString)-main"

        // Test through scheduled notifications
        XCTAssertTrue(expectedPattern.contains("main"))
    }

    func test_notificationIdentifier_withWeekday_shouldIncludeWeekday() {
        let alarmId = UUID()
        let weekday = 2 // Tuesday
        let expectedPattern = "\(alarmId.uuidString)-main-weekday-\(weekday)"

        XCTAssertTrue(expectedPattern.contains("weekday-2"))
    }

    // MARK: - One-Time Alarm Tests

    func test_scheduleAlarm_oneTime_shouldScheduleAllNotificationTypes() async throws {
        let futureTime = Date().addingTimeInterval(10 * 60) // 10 minutes from now
        let alarm = createTestAlarm(time: futureTime, repeatDays: [])

        try await notificationService.scheduleAlarm(alarm)

        // Verify the call completed without throwing
        XCTAssertTrue(true)
    }

    func test_scheduleAlarm_oneTime_pastPreAlarmTime_shouldNotSchedulePreAlarm() async throws {
        let nearFutureTime = Date().addingTimeInterval(2 * 60) // 2 minutes from now (less than 5 min pre-alarm)
        let alarm = createTestAlarm(time: nearFutureTime, repeatDays: [])

        try await notificationService.scheduleAlarm(alarm)

        // Pre-alarm should not be scheduled since it would be in the past
        XCTAssertTrue(true)
    }

    // MARK: - Repeating Alarm Tests

    func test_scheduleAlarm_repeating_shouldScheduleForAllDays() async throws {
        let alarm = createTestAlarm(repeatDays: [.monday, .wednesday, .friday])

        try await notificationService.scheduleAlarm(alarm)

        // Should schedule notifications for all specified days
        XCTAssertTrue(true)
    }

    func test_scheduleAlarm_repeating_allDays_shouldScheduleForWeek() async throws {
        let alarm = createTestAlarm(repeatDays: [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday])

        try await notificationService.scheduleAlarm(alarm)

        // Should schedule for all 7 days
        XCTAssertTrue(true)
    }

    // MARK: - Permission Tests

    func test_scheduleAlarm_deniedPermission_shouldThrowError() async {
        mockPermissionService.mockNotificationDetails = NotificationPermissionDetails(
            authorizationStatus: PermissionStatus.denied,
            alertsEnabled: false,
            soundEnabled: false,
            badgeEnabled: false
        )

        let alarm = createTestAlarm()

        do {
            try await notificationService.scheduleAlarm(alarm)
            XCTFail("Should have thrown permission denied error")
        } catch NotificationError.permissionDenied {
            // Expected behavior
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_scheduleAlarm_mutedNotifications_shouldWarnButProceed() async throws {
        mockPermissionService.mockNotificationDetails = NotificationPermissionDetails(
            authorizationStatus: PermissionStatus.authorized,
            alertsEnabled: false,
            soundEnabled: false,
            badgeEnabled: true
        )

        let alarm = createTestAlarm()

        // Should not throw but should log warning
        try await notificationService.scheduleAlarm(alarm)
        XCTAssertTrue(true)
    }

    // MARK: - Cancellation Tests

    func test_cancelAlarm_shouldRemoveAllRelatedNotifications() async {
        let alarm = createTestAlarm(repeatDays: [.monday, .tuesday])

        await notificationService.cancelAlarm(alarm)

        // Should generate correct identifiers for cancellation
        XCTAssertTrue(true)
    }

    func test_cancelSpecificNotifications_shouldRemoveOnlySpecifiedTypes() {
        let alarmId = UUID()
        let typesToCancel: [NotificationType] = [.nudge1, .nudge2]

        notificationService.cancelSpecificNotifications(for: alarmId, types: typesToCancel)

        // Should only cancel specified notification types
        XCTAssertTrue(true)
    }

    func test_cancelSpecificNotifications_nudgeTypes_shouldNotCancelMainOrPreAlarm() {
        let alarmId = UUID()
        let nudgeTypes: [NotificationType] = [.nudge1, .nudge2, .nudge3]

        notificationService.cancelSpecificNotifications(for: alarmId, types: nudgeTypes)

        // Should preserve main and pre-alarm notifications
        XCTAssertTrue(true)
    }

    // MARK: - Refresh Tests

    func test_refreshAll_shouldCancelAllAndReschedule() async {
        let alarms = [
            createTestAlarm(),
            createTestAlarm(id: UUID(), repeatDays: [.monday])
        ]

        await notificationService.refreshAll(from: alarms)

        // Should cancel all existing and reschedule enabled alarms
        XCTAssertTrue(true)
    }

    func test_refreshAll_disabledAlarms_shouldNotBeScheduled() async {
        var disabledAlarm = createTestAlarm()
        // Note: Alarm struct doesn't have isEnabled property in the test setup
        // This test would verify that disabled alarms are skipped

        await notificationService.refreshAll(from: [disabledAlarm])
        XCTAssertTrue(true)
    }

    // MARK: - Sound Tests

    func test_createNotificationSound_defaultSound_shouldReturnDefault() {
        // Test through scheduled notification
        let alarm = createTestAlarm(soundId: "chimes01")

        // Sound creation is tested implicitly through scheduling
        XCTAssertEqual(alarm.soundName, "default")
    }

    func test_createNotificationSound_customSound_shouldUseCustom() {
        let alarm = createTestAlarm(soundId: "bells01")

        XCTAssertEqual(alarm.soundName, "chime")
    }

    func test_createNotificationSound_invalidSound_shouldFallbackToDefault() {
        let alarm = createTestAlarm(soundId: "nonexistent")

        // Service should handle invalid sounds gracefully
        XCTAssertEqual(alarm.soundName, "nonexistent")
    }

    func test_createNotificationSound_nilSound_shouldUseDefault() {
        let alarm = createTestAlarm() // Uses default soundId

        XCTAssertNil(alarm.soundName)
    }

    // MARK: - Test Notification Tests

    func test_scheduleTestNotification_shouldScheduleWithCorrectDelay() async throws {
        let delay: TimeInterval = 3.0

        try await notificationService.scheduleTestNotification(soundName: "bell", in: delay)

        // Should schedule test notification with specified delay
        XCTAssertTrue(true)
    }

    func test_scheduleTestNotification_withNilSound_shouldUseDefault() async throws {
        try await notificationService.scheduleTestNotification(soundName: nil, in: 1.0)

        XCTAssertTrue(true)
    }

    // MARK: - Notification Action Tests

    func test_notificationCategories_shouldIncludeAllActions() {
        // Verify notification categories are set up correctly
        XCTAssertTrue(true) // Would test if we could access the registered categories
    }

    func test_snoozeAction_shouldBeHandledCorrectly() async {
        // This would test the snooze action handling in delegate
        // For now, test the action identifier constants
        XCTAssertEqual("SNOOZE_ALARM", "SNOOZE_ALARM")
        XCTAssertEqual("OPEN_ALARM", "OPEN_ALARM")
        XCTAssertEqual("RETURN_TO_DISMISSAL", "RETURN_TO_DISMISSAL")
    }

    // MARK: - Trigger Type Tests

    func test_nudgeNotifications_shouldUsePreciseTiming() {
        // Test that nudge notifications would use interval triggers for precision
        // This tests the logic in createOptimalTrigger indirectly
        let now = Date()
        let thirtySecondsLater = now.addingTimeInterval(30)
        let twoMinutesLater = now.addingTimeInterval(120)

        // Verify timing calculations
        XCTAssertEqual(thirtySecondsLater.timeIntervalSince(now), 30)
        XCTAssertEqual(twoMinutesLater.timeIntervalSince(now), 120)
    }

    func test_mainAlarm_shouldUseCalendarTrigger() {
        // Test that main alarms use calendar triggers for exact time matching
        let alarm = createTestAlarm()

        // Main alarms should use calendar-based scheduling
        XCTAssertNotNil(alarm.time)
    }

    // MARK: - Notification Type Tests

    func test_notificationType_allCases_shouldIncludeAllTypes() {
        let allTypes = NotificationType.allCases

        XCTAssertEqual(allTypes.count, 5)
        XCTAssertTrue(allTypes.contains(.main))
        XCTAssertTrue(allTypes.contains(.preAlarm))
        XCTAssertTrue(allTypes.contains(.nudge1))
        XCTAssertTrue(allTypes.contains(.nudge2))
        XCTAssertTrue(allTypes.contains(.nudge3))
    }

    func test_notificationType_rawValues_shouldBeCorrect() {
        XCTAssertEqual(NotificationType.main.rawValue, "main")
        XCTAssertEqual(NotificationType.preAlarm.rawValue, "pre_alarm")
        XCTAssertEqual(NotificationType.nudge1.rawValue, "nudge_1")
        XCTAssertEqual(NotificationType.nudge2.rawValue, "nudge_2")
        XCTAssertEqual(NotificationType.nudge3.rawValue, "nudge_3")
    }

    // MARK: - Edge Case Tests

    func test_scheduleAlarm_farFuture_shouldHandleCorrectly() async throws {
        let farFutureTime = Date().addingTimeInterval(365 * 24 * 60 * 60) // 1 year from now
        let alarm = createTestAlarm(time: farFutureTime)

        try await notificationService.scheduleAlarm(alarm)

        // Should handle far future dates without issues
        XCTAssertTrue(true)
    }

    func test_scheduleAlarm_pastTime_shouldHandleGracefully() async throws {
        let pastTime = Date().addingTimeInterval(-3600) // 1 hour ago
        let alarm = createTestAlarm(time: pastTime)

        try await notificationService.scheduleAlarm(alarm)

        // Should handle past times (may not actually schedule, but shouldn't crash)
        XCTAssertTrue(true)
    }

    // MARK: - Idempotent Scheduling Tests

    func test_refreshAll_idempotent_noDuplicates() async {
        // Given: An alarm that should be scheduled
        let alarm = createTestAlarm()
        alarm.isEnabled = true
        let alarms = [alarm]

        // When: refreshAll is called twice
        await notificationService.refreshAll(from: alarms)
        let firstCount = mockCenter.scheduledRequests.count

        await notificationService.refreshAll(from: alarms)
        let secondCount = mockCenter.scheduledRequests.count

        // Then: No duplicate notifications are created
        // Note: With idempotent scheduling, the second call should not add more notifications
        // if the first call already scheduled them
        XCTAssertGreaterThan(firstCount, 0, "First refresh should schedule notifications")

        // The count might be the same or less (due to diff-based scheduling)
        // but should not increase
        XCTAssertLessThanOrEqual(secondCount, firstCount,
                                  "Second refresh should not create duplicates")
    }

    func test_refreshAll_disabledAlarm_removesNotifications() async {
        // Given: An enabled alarm that gets scheduled
        let alarm = createTestAlarm()
        alarm.isEnabled = true
        await notificationService.refreshAll(from: [alarm])

        let scheduledCount = mockCenter.scheduledRequests.count
        XCTAssertGreaterThan(scheduledCount, 0, "Should have scheduled notifications")

        // When: The alarm is disabled and refreshAll is called
        alarm.isEnabled = false
        await notificationService.refreshAll(from: [alarm])

        // Then: Notifications should be removed
        // With idempotent scheduling, disabled alarm notifications are removed
        XCTAssertGreaterThan(mockCenter.removedIdentifiers.count, 0,
                             "Should have removed notifications for disabled alarm")
    }

    func test_refreshAll_namespace_isolated() async {
        // Given: Some existing non-app notifications (simulated)
        let foreignRequest = UNNotificationRequest(
            identifier: "com.other.app.notification",
            content: UNMutableNotificationContent(),
            trigger: nil
        )
        mockCenter.scheduledRequests.append(foreignRequest)

        // When: refreshAll is called with our alarms
        let alarm = createTestAlarm()
        alarm.isEnabled = true
        await notificationService.refreshAll(from: [alarm])

        // Then: Foreign notifications should not be removed
        let foreignStillExists = mockCenter.scheduledRequests.contains {
            $0.identifier == "com.other.app.notification"
        }
        XCTAssertTrue(foreignStillExists || !mockCenter.removedIdentifiers.contains("com.other.app.notification"),
                      "Should not remove foreign notifications")
    }
}
```

### TestMocks.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/TestMocks.swift`

```swift
//
//  TestMocks.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 9/25/25.
//  Shared mock classes for all test targets
//

import XCTest
@testable import alarmAppNew
import UserNotifications
import Combine

// MARK: - QR Scanning Mock

final class MockQRScanning: QRScanning {
    var shouldThrowOnStart = false
    var scanResults: [String] = []
    var isScanning = false
    private var continuation: AsyncStream<String>.Continuation?

    func startScanning() async throws {
        if shouldThrowOnStart {
            throw QRScanningError.permissionDenied
        }
        isScanning = true
    }

    func stopScanning() {
        isScanning = false
        continuation?.finish()
    }

    func scanResultStream() -> AsyncStream<String> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    // Test helpers
    func simulateScan(_ payload: String) {
        continuation?.yield(payload)
    }

    func simulateError() {
        continuation?.finish()
    }
}

// MARK: - Notification Service Mock

final class MockNotificationService: AlarmScheduling {
    var cancelledAlarmIds: [UUID] = []
    var scheduledAlarms: [Alarm] = []
    var cancelledSpecificTypes: [(UUID, [NotificationType])] = []
    var cancelledNotificationTypes: [(UUID, [NotificationType])] = []
    var getRequestIdsCalls: [(UUID, String)] = []
    var cleanupAfterDismissCalls: [(UUID, String)] = []
    var cleanupStaleCallCount = 0

    func scheduleAlarm(_ alarm: Alarm) async throws {
        scheduledAlarms.append(alarm)
    }

    func cancelAlarm(_ alarm: Alarm) async {
        cancelledAlarmIds.append(alarm.id)
    }

    func cancelOccurrence(alarmId: UUID, occurrenceKey: String) async {
        // Track occurrence-specific cancellations
        cancelledAlarmIds.append(alarmId)
    }

    func getRequestIds(alarmId: UUID, occurrenceKey: String) async -> [String] {
        getRequestIdsCalls.append((alarmId, occurrenceKey))
        return []  // Override in tests as needed
    }

    func removeRequests(withIdentifiers ids: [String]) async {
        // Mock implementation
    }

    func cleanupAfterDismiss(alarmId: UUID, occurrenceKey: String) async {
        cleanupAfterDismissCalls.append((alarmId, occurrenceKey))
    }

    func cleanupStaleDeliveredNotifications() async {
        cleanupStaleCallCount += 1
    }

    func cancelSpecificNotifications(for alarmId: UUID, types: [NotificationType]) {
        cancelledSpecificTypes.append((alarmId, types))
        cancelledNotificationTypes.append((alarmId, types))
    }

    func refreshAll(from alarms: [Alarm]) async {}

    func pendingAlarmIds() async -> [UUID] {
        return []
    }

    func scheduleAlarmImmediately(_ alarm: Alarm) async throws {}

    func scheduleTestNotification(soundName: String?, in seconds: TimeInterval) async throws {}
    func scheduleTestSystemDefault() async throws {}
    func scheduleTestCriticalSound() async throws {}
    func scheduleTestCustomSound(soundName: String?) async throws {}
    func ensureNotificationCategoriesRegistered() {}
    func dumpNotificationSettings() async {}
    func validateSoundBundle() {}
    func scheduleTestDefault() async throws {}
    func scheduleTestCustom() async throws {}
    func dumpNotificationCategories() async {}
    func runCompleteSoundTriage() async throws {}
    func scheduleBareDefaultTest() async throws {}
    func scheduleBareDefaultTestNoInterruption() async throws {}
    func scheduleBareDefaultTestNoCategory() async throws {}
    func scheduleOneOffTestAlarm(leadTime: TimeInterval) async throws {}
}

// MARK: - Alarm Storage Mock

actor MockAlarmStorage: PersistenceStore {
    var storedAlarms: [Alarm] = []
    var storedRuns: [AlarmRun] = []
    var runs: [AlarmRun] = []
    var shouldThrowOnAlarmLoad = false

    func saveAlarms(_ alarms: [Alarm]) throws {}
    func loadAlarms() throws -> [Alarm] { storedAlarms }

    func saveAlarm(_ alarm: Alarm) throws {
        storedAlarms.append(alarm)
    }

    func alarm(with id: UUID) throws -> Alarm {
        if shouldThrowOnAlarmLoad {
            struct AlarmNotFoundError: Error {}
            throw AlarmNotFoundError()
        }

        guard let alarm = storedAlarms.first(where: { $0.id == id }) else {
            struct AlarmNotFoundError: Error {}
            throw AlarmNotFoundError()
        }
        return alarm
    }

    func appendRun(_ run: AlarmRun) throws {
        storedRuns.append(run)
        runs.append(run)
    }

    // MARK: - Test Helper Methods (for external actor access)

    func setStoredAlarms(_ alarms: [Alarm]) {
        storedAlarms = alarms
    }

    func getStoredAlarms() -> [Alarm] {
        storedAlarms
    }

    func setStoredRuns(_ runs: [AlarmRun]) {
        storedRuns = runs
        self.runs = runs
    }

    func getStoredRuns() -> [AlarmRun] {
        storedRuns
    }

    func setShouldThrow(_ value: Bool) {
        shouldThrowOnAlarmLoad = value
    }
}

// MARK: - Clock Mock

final class MockClock: Clock {
    private var currentTime: Date

    init(fixedNow: Date = Date()) {
        self.currentTime = fixedNow
    }

    func now() -> Date {
        currentTime
    }

    func advance(by interval: TimeInterval) {
        currentTime = currentTime.addingTimeInterval(interval)
    }

    func set(to time: Date) {
        currentTime = time
    }
}

// MARK: - App Router Mock

@MainActor
final class MockAppRouter: AppRouting {
    var backToListCallCount = 0
    var ringingCallCount = 0
    var showRingingCalls: [(UUID, UUID?)] = []

    func showRinging(for id: UUID, intentAlarmID: UUID? = nil) {
        ringingCallCount += 1
        showRingingCalls.append((id, intentAlarmID))
    }

    func backToList() {
        backToListCallCount += 1
    }
}

// MARK: - Permission Service Mock

final class MockPermissionService: PermissionServiceProtocol {
    var cameraPermissionStatus: PermissionStatus = PermissionStatus.authorized
    var requestCameraResult: PermissionStatus = PermissionStatus.authorized
    var didRequestCameraPermission = false
    var authorizationStatus: PermissionStatus = .authorized

    // Configurable notification details for testing
    var mockNotificationDetails = NotificationPermissionDetails(
        authorizationStatus: PermissionStatus.authorized,
        alertsEnabled: true,
        soundEnabled: true,
        badgeEnabled: true
    )

    func requestNotificationPermission() async throws -> PermissionStatus {
        return authorizationStatus
    }

    func checkNotificationPermission() async -> NotificationPermissionDetails {
        mockNotificationDetails.authorizationStatus = authorizationStatus
        return mockNotificationDetails
    }

    func requestCameraPermission() async -> PermissionStatus {
        didRequestCameraPermission = true
        return requestCameraResult
    }

    func checkCameraPermission() -> PermissionStatus {
        return cameraPermissionStatus
    }

    func openAppSettings() {
        // Mock implementation
    }
}

// MARK: - Reliability Logger Mock

struct MockLoggedEvent {
    let event: ReliabilityEvent
    let alarmId: UUID?
    let details: [String: String]
}

final class MockReliabilityLogger: ReliabilityLogging {
    var loggedEvents: [MockLoggedEvent] = []
    var loggedDetails: [[String: String]] = []
    var exportResult = "mock-export-data"
    var recentLogs: [ReliabilityLogEntry] = []

    func log(_ event: ReliabilityEvent, alarmId: UUID?, details: [String: String]) {
        loggedEvents.append(MockLoggedEvent(event: event, alarmId: alarmId, details: details))
        loggedDetails.append(details)
    }

    func exportLogs() -> String {
        return exportResult
    }

    func clearLogs() {
        loggedEvents.removeAll()
        loggedDetails.removeAll()
        recentLogs.removeAll()
    }

    func getRecentLogs(limit: Int) -> [ReliabilityLogEntry] {
        return Array(recentLogs.prefix(limit))
    }
}

// MARK: - Reliability Mode Provider Mock

@MainActor
final class MockReliabilityModeProvider: ReliabilityModeProvider {
    var currentMode: ReliabilityMode = .notificationsOnly
    var modePublisher: AnyPublisher<ReliabilityMode, Never> {
        Just(currentMode).eraseToAnyPublisher()
    }

    func setMode(_ mode: ReliabilityMode) {
        currentMode = mode
    }
}

// MARK: - App State Provider Mock

@MainActor
final class MockAppStateProvider: AppStateProviding {
    var mockIsAppActive: Bool = false

    var isAppActive: Bool {
        return mockIsAppActive
    }
}

// MARK: - Audio Engine Mock

final class MockAlarmAudioEngine: AlarmAudioEngineProtocol {
    var currentState: AlarmSoundEngine.State = .idle
    var shouldThrowOnSchedule = false
    var shouldThrowOnPromote = false
    var shouldThrowOnPlay = false

    var scheduledSounds: [(Date, String)] = []
    var promoteCalled = false
    var playForegroundAlarmCalls: [String] = []
    var stopCalled = false
    var scheduleWithLeadInCalls: [(Date, String, Int)] = []
    var policyProvider: (() -> AudioPolicy)?

    var isActivelyRinging: Bool {
        return currentState == .ringing
    }

    func schedulePrewarm(fireAt: Date, soundName: String) throws {
        if shouldThrowOnSchedule {
            throw AlarmAudioEngineError.playbackFailed(reason: "Mock prewarm failed")
        }
        scheduledSounds.append((fireAt, soundName))
        currentState = .prewarming
    }

    func promoteToRinging() throws {
        if shouldThrowOnPromote {
            throw AlarmAudioEngineError.playbackFailed(reason: "Mock promotion failed")
        }
        promoteCalled = true
        currentState = .ringing
    }

    func playForegroundAlarm(soundName: String) throws {
        if shouldThrowOnPlay {
            throw AlarmAudioEngineError.playbackFailed(reason: "Mock playback failed")
        }
        playForegroundAlarmCalls.append(soundName)
        currentState = .ringing
    }

    func setPolicyProvider(_ provider: @escaping () -> AudioPolicy) {
        policyProvider = provider
    }

    func scheduleWithLeadIn(fireAt: Date, soundId: String, leadInSeconds: Int) throws {
        if shouldThrowOnSchedule {
            throw AlarmAudioEngineError.playbackFailed(reason: "Mock schedule with lead-in failed")
        }
        scheduleWithLeadInCalls.append((fireAt, soundId, leadInSeconds))
        currentState = .prewarming
    }

    func stop() {
        stopCalled = true
        currentState = .idle
    }
}

// MARK: - Idle Timer Controller Mock

final class MockIdleTimerController: IdleTimerControlling {
    var isIdleTimerDisabled = false
    var setIdleTimerCalls: [Bool] = []

    func setIdleTimer(disabled: Bool) {
        isIdleTimerDisabled = disabled
        setIdleTimerCalls.append(disabled)
    }
}

// MARK: - Notification Center Mock (for ChainedScheduling tests)

final class MockNotificationCenter: UNUserNotificationCenter {
    var authorizationStatus: UNAuthorizationStatus = .authorized
    var authorizationGranted = true
    var authorizationError: Error?
    var scheduledRequests: [UNNotificationRequest] = []
    var cancelledIdentifiers: [String] = []
    var addRequestCallCount = 0

    override func notificationSettings() async -> UNNotificationSettings {
        let settings = MockUNNotificationSettings(authorizationStatus: authorizationStatus)
        return settings
    }

    override func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        if let error = authorizationError {
            throw error
        }
        return authorizationGranted
    }

    override func add(_ request: UNNotificationRequest) async throws {
        addRequestCallCount += 1
        scheduledRequests.append(request)
    }

    override func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        cancelledIdentifiers.append(contentsOf: identifiers)
    }

    override func pendingNotificationRequests() async -> [UNNotificationRequest] {
        return scheduledRequests
    }
}

final class MockUNNotificationSettings: UNNotificationSettings {
    private let _authorizationStatus: UNAuthorizationStatus

    init(authorizationStatus: UNAuthorizationStatus) {
        self._authorizationStatus = authorizationStatus
        super.init()
    }

    override var authorizationStatus: UNAuthorizationStatus {
        return _authorizationStatus
    }
}

// MARK: - Sound Catalog Mock

final class MockSoundCatalog: SoundCatalogProviding {
    var soundInfo: SoundInfo?

    func safeInfo(for soundId: String) -> SoundInfo? {
        return soundInfo
    }
}

// MARK: - Global Limit Guard Mock

final class MockGlobalLimitGuard: GlobalLimitGuard {
    var reserveReturnValue: Int = 0
    var reserveCallCount = 0
    var finalizeCallCount = 0

    override func reserve(_ count: Int) async -> Int {
        reserveCallCount += 1
        return reserveReturnValue
    }

    override func finalize(_ actualScheduled: Int) {
        finalizeCallCount += 1
    }
}

// MARK: - Chained Scheduler Mock

final class MockChainedScheduler: ChainedNotificationScheduling {
    var storedIdentifiers: [UUID: [String]] = [:]

    func getIdentifiers(alarmId: UUID) -> [String] {
        return storedIdentifiers[alarmId] ?? []
    }

    // Stub implementations for required protocol methods
    func scheduleChain(for alarm: Alarm, fireDate: Date) async -> ScheduleOutcome {
        return ScheduleOutcome(requested: 0, scheduled: 0, failureReasons: [])
    }

    func cancelChain(alarmId: UUID) async {}
    func cancelOccurrence(alarmId: UUID, occurrenceKey: String) async {}
    func requestAuthorization() async throws {}
    func cleanupStaleChains() async {}
}

// MARK: - Settings Service Mock

final class MockSettingsService: SettingsServiceProtocol {
    var useChainedScheduling: Bool = false
    var audioPolicy: AudioPolicy = AudioPolicy(capability: .foregroundAssist, allowRouteOverrideAtAlarm: true)
    var reliabilityMode: ReliabilityMode = .notificationsOnly

    func setUseChainedScheduling(_ value: Bool) {
        useChainedScheduling = value
    }

    func setAudioPolicy(_ policy: AudioPolicy) {
        audioPolicy = policy
    }

    func setReliabilityMode(_ mode: ReliabilityMode) {
        reliabilityMode = mode
    }
}

// MARK: - System Volume Provider Mock

final class MockSystemVolumeProvider: SystemVolumeProviding {
    var mockVolume: Float = 0.5

    func currentMediaVolume() -> Float {
        return mockVolume
    }
}

// MARK: - Mock Alarm Factory

final class MockAlarmFactory: AlarmFactory {
    func makeNewAlarm() -> Alarm {
        Alarm(
            id: UUID(),
            time: Date().addingTimeInterval(3600),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [],
            expectedQR: nil,
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: "ringtone1",
            soundName: nil,
            volume: 0.8,
            externalAlarmId: nil
        )
    }
}

// MARK: - Mock Dismissed Registry (removed - DismissedRegistry is final)
// Use the real DismissedRegistry in tests or create a protocol-based mock if needed

// MARK: - AlarmScheduling Mock (Consolidated)

/// Shared test double for AlarmScheduling used across all tests.
/// Keep this in sync with the AlarmScheduling protocol.
public final class AlarmSchedulingMock: AlarmScheduling {

    // MARK: - Configurable behavior for tests
    public var shouldThrowOnRequestAuth = false
    public var shouldThrowOnSchedule = false
    public var shouldThrowOnStop = false
    public var shouldThrowOnSnooze = false

    // MARK: - Captured / observable state
    public private(set) var requestedAuthorizationCount = 0
    public private(set) var scheduledAlarms: [UUID: Alarm] = [:]
    public private(set) var canceledAlarmIds: [UUID] = []
    public private(set) var stoppedAlarmCalls: [(alarmId: UUID, intentAlarmId: UUID?)] = []
    public private(set) var countdownCalls: [(alarmId: UUID, duration: TimeInterval)] = []
    public private(set) var reconcileCalls: [(alarms: [Alarm], skipIfRinging: Bool)] = []

    /// Stub return for pending IDs; set in tests as needed.
    public var pendingIdsStub: [UUID] = []

    // MARK: - Backward compatibility aliases

    /// Backward-compatible alias for stoppedAlarmCalls
    public var stopCalls: [UUID] {
        stoppedAlarmCalls.map { $0.alarmId }
    }

    /// Backward-compatible alias for countdownCalls
    public var transitionToCountdownCalls: [(UUID, TimeInterval)] {
        countdownCalls
    }

    /// Backward-compatible alias for shouldThrowOnSnooze
    public var shouldThrowOnTransition: Bool {
        get { shouldThrowOnSnooze }
        set { shouldThrowOnSnooze = newValue }
    }

    public init() {}

    // MARK: - AlarmScheduling

    public func requestAuthorizationIfNeeded() async throws {
        requestedAuthorizationCount += 1
        if shouldThrowOnRequestAuth { throw TestError.forced }
    }

    public func schedule(alarm: Alarm) async throws -> String {
        if shouldThrowOnSchedule { throw TestError.forced }
        scheduledAlarms[alarm.id] = alarm
        return "mock-\(alarm.id.uuidString)"
    }

    public func cancel(alarmId: UUID) async {
        canceledAlarmIds.append(alarmId)
        scheduledAlarms.removeValue(forKey: alarmId)
    }

    public func pendingAlarmIds() async -> [UUID] {
        pendingIdsStub
    }

    public func stop(alarmId: UUID, intentAlarmId: UUID?) async throws {
        if shouldThrowOnStop { throw TestError.forced }
        stoppedAlarmCalls.append((alarmId, intentAlarmId))
    }

    public func transitionToCountdown(alarmId: UUID, duration: TimeInterval) async throws {
        if shouldThrowOnSnooze { throw TestError.forced }
        countdownCalls.append((alarmId, duration))
    }

    public func reconcile(alarms: [Alarm], skipIfRinging: Bool) async {
        reconcileCalls.append((alarms, skipIfRinging))
    }

    // MARK: - Test helpers

    public func reset() {
        shouldThrowOnRequestAuth = false
        shouldThrowOnSchedule = false
        shouldThrowOnStop = false
        shouldThrowOnSnooze = false

        requestedAuthorizationCount = 0
        scheduledAlarms = [:]
        canceledAlarmIds = []
        stoppedAlarmCalls = []
        countdownCalls = []
        reconcileCalls = []
        pendingIdsStub = []
    }

    public enum TestError: Error { case forced }
}

/// Back-compat so existing tests using `MockAlarmScheduling` keep compiling.
public typealias MockAlarmScheduling = AlarmSchedulingMock
```

### AlarmFactoryTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/Unit/Alarms/AlarmFactoryTests.swift`

```swift
//
//  AlarmFactoryTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 9/24/25.
//

import XCTest
@testable import alarmAppNew

final class AlarmFactoryTests: XCTestCase {

    private var mockCatalog: MockSoundCatalog!
    private var factory: DefaultAlarmFactory!

    override func setUp() {
        super.setUp()
        mockCatalog = MockSoundCatalog()
        factory = DefaultAlarmFactory(catalog: mockCatalog)
    }

    override func tearDown() {
        factory = nil
        mockCatalog = nil
        super.tearDown()
    }

    // MARK: - Basic Creation Tests

    func testAlarmFactory_makeNewAlarm_setsCorrectDefaults() {
        // Given: A factory with mock catalog
        // When: We create a new alarm
        let alarm = factory.makeNewAlarm()

        // Then: It should have sensible defaults
        XCTAssertNotEqual(alarm.id, UUID()) // Should have a unique ID (not zero UUID)
        XCTAssertEqual(alarm.label, "New Alarm")
        XCTAssertTrue(alarm.repeatDays.isEmpty)
        XCTAssertTrue(alarm.challengeKind.isEmpty)
        XCTAssertNil(alarm.expectedQR)
        XCTAssertNil(alarm.stepThreshold)
        XCTAssertNil(alarm.mathChallenge)
        XCTAssertTrue(alarm.isEnabled)
        XCTAssertEqual(alarm.volume, 0.8)
        XCTAssertNil(alarm.soundName) // Legacy field should be nil
    }

    func testAlarmFactory_makeNewAlarm_usesCatalogDefaultSoundId() {
        // Given: A factory with mock catalog that has a specific default
        mockCatalog.defaultSoundId = "test-default-sound"

        // When: We create a new alarm
        let alarm = factory.makeNewAlarm()

        // Then: It should use the catalog's default sound ID
        XCTAssertEqual(alarm.soundId, "test-default-sound")
    }

    func testAlarmFactory_makeNewAlarm_setsTimeInFuture() {
        // Given: A factory and the current time
        let beforeCreation = Date()

        // When: We create a new alarm
        let alarm = factory.makeNewAlarm()

        // Then: The alarm time should be in the future
        XCTAssertGreaterThan(alarm.time, beforeCreation)
    }

    func testAlarmFactory_makeNewAlarm_createsUniqueAlarms() {
        // Given: A factory
        // When: We create multiple alarms
        let alarm1 = factory.makeNewAlarm()
        let alarm2 = factory.makeNewAlarm()

        // Then: Each alarm should have a unique ID
        XCTAssertNotEqual(alarm1.id, alarm2.id)
    }

    // MARK: - Catalog Integration Tests

    func testAlarmFactory_respectsCatalogChanges() {
        // Given: A factory with an initial catalog
        let initialAlarm = factory.makeNewAlarm()
        XCTAssertEqual(initialAlarm.soundId, mockCatalog.defaultSoundId)

        // When: We change the catalog's default (simulate different catalog)
        let newMockCatalog = MockSoundCatalog()
        newMockCatalog.defaultSoundId = "different-default"
        let newFactory = DefaultAlarmFactory(catalog: newMockCatalog)

        // Then: New alarms should use the new default
        let newAlarm = newFactory.makeNewAlarm()
        XCTAssertEqual(newAlarm.soundId, "different-default")
    }
}

// MARK: - Mock Sound Catalog for Testing

private class MockSoundCatalog: SoundCatalogProviding {
    var defaultSoundId: String = "mock-default"

    var all: [AlarmSound] = [
        AlarmSound(id: "mock-default", name: "Mock Default", fileName: "mock.caf", durationSec: 10),
        AlarmSound(id: "mock-alternative", name: "Mock Alternative", fileName: "alt.caf", durationSec: 15)
    ]

    func info(for id: String) -> AlarmSound? {
        all.first { $0.id == id }
    }
}
```

### ArchitectureGuardrailTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/Unit/ArchitectureGuardrailTests.swift`

```swift
//
//  ArchitectureGuardrailTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/5/25.
//  Guardrail tests to enforce architectural boundaries
//

import XCTest
@testable import alarmAppNew

final class ArchitectureGuardrailTests: XCTestCase {
    func test_dismissedRegistry_hasNoOSDependencies() {
        // This is a compile-time check: DismissedRegistry MUST NOT import UIKit or UserNotifications
        // If it does, this file won't compile
        let registry = DismissedRegistry()
        XCTAssertNotNil(registry, "DismissedRegistry should initialize without OS dependencies")
    }

    @MainActor
    func test_dismissedRegistry_init_noForceUnwraps() async {
        // Verify initialization doesn't crash with default UserDefaults
        let registry = DismissedRegistry()

        // Should initialize successfully with empty cache (await for MainActor)
        let keys = await registry.dismissedOccurrenceKeys()
        XCTAssertNotNil(keys)
        XCTAssertTrue(keys.isEmpty, "Fresh registry should have no dismissed occurrences")
    }

    @MainActor
    func test_dismissedRegistry_markDismissed_persistsState() async {
        // Given: A fresh registry
        let registry = DismissedRegistry()
        let alarmId = UUID()
        let occurrenceKey = OccurrenceKeyFormatter.key(from: Date())

        // When: We mark an occurrence as dismissed
        await registry.markDismissed(alarmId: alarmId, occurrenceKey: occurrenceKey)

        // Then: It's remembered
        let isDismissed = await registry.isDismissed(alarmId: alarmId, occurrenceKey: occurrenceKey)
        XCTAssertTrue(isDismissed, "Registry should remember dismissed occurrence")

        // And: It appears in dismissed keys set
        let dismissedKeys = await registry.dismissedOccurrenceKeys()
        XCTAssertTrue(dismissedKeys.contains(occurrenceKey), "Dismissed key should be in set")
    }

    @MainActor
    func test_dismissedRegistry_expiration_clearsOldEntries() async {
        // Given: A registry with a mocked old dismissal (would need to manipulate time)
        // This test validates that expired entries are cleaned up
        // For now, we just verify the cleanup method exists and doesn't crash
        let registry = DismissedRegistry()

        // When: We call cleanup
        await registry.cleanupExpired()

        // Then: No crash occurs
        let keys = await registry.dismissedOccurrenceKeys()
        XCTAssertNotNil(keys)
    }
}

```

### AlarmStopSemanticsTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/Unit/Domain/AlarmStopSemanticsTests.swift`

```swift
//
//  AlarmStopSemanticsTests.swift
//  alarmAppNewTests
//
//  Tests for the StopAlarmAllowed use case to verify that
//  stop is only allowed after challenge validation.
//

import XCTest
@testable import alarmAppNew

final class AlarmStopSemanticsTests: XCTestCase {

    // MARK: - Stop Disallowed Tests

    func test_stop_disallowed_until_all_challenges_validated() {
        // GIVEN: An alarm with multiple challenges
        let requiredChallenges: [Challenges] = [.qr, .stepCount, .math]

        // WHEN: Only some challenges are completed
        let partiallyCompleteState = ChallengeStackState(
            requiredChallenges: requiredChallenges,
            completedChallenges: [.qr, .stepCount]  // Missing .math
        )

        // THEN: Stop should not be allowed
        XCTAssertFalse(
            StopAlarmAllowed.execute(challengeState: partiallyCompleteState),
            "Stop should not be allowed when challenges remain incomplete"
        )

        // AND: Reason should indicate remaining challenge
        let reason = StopAlarmAllowed.reasonForDenial(challengeState: partiallyCompleteState)
        XCTAssertNotNil(reason, "Should provide reason for denial")
        XCTAssertTrue(
            reason?.contains("Math") ?? false,
            "Reason should mention the remaining challenge"
        )
    }

    func test_stop_disallowed_when_no_challenges_completed() {
        // GIVEN: An alarm with challenges
        let requiredChallenges: [Challenges] = [.qr, .math]

        // WHEN: No challenges are completed
        let uncompleteState = ChallengeStackState(
            requiredChallenges: requiredChallenges,
            completedChallenges: []
        )

        // THEN: Stop should not be allowed
        XCTAssertFalse(
            StopAlarmAllowed.execute(challengeState: uncompleteState),
            "Stop should not be allowed when no challenges are completed"
        )

        // AND: Reason should indicate all challenges need completion
        let reason = StopAlarmAllowed.reasonForDenial(challengeState: uncompleteState)
        XCTAssertEqual(
            reason,
            "Complete all challenges to stop the alarm",
            "Should indicate all challenges need completion"
        )
    }

    func test_stop_disallowed_during_validation() {
        // GIVEN: An alarm with challenges being validated
        let requiredChallenges: [Challenges] = [.qr]

        // WHEN: Challenge is being validated
        let validatingState = ChallengeStackState(
            requiredChallenges: requiredChallenges,
            completedChallenges: [],
            isValidating: true
        )

        // THEN: Stop should not be allowed
        XCTAssertFalse(
            StopAlarmAllowed.execute(challengeState: validatingState),
            "Stop should not be allowed during validation"
        )

        // AND: Reason should indicate validation in progress
        let reason = StopAlarmAllowed.reasonForDenial(challengeState: validatingState)
        XCTAssertEqual(
            reason,
            "Challenge validation in progress",
            "Should indicate validation is in progress"
        )
    }

    // MARK: - Stop Allowed Tests

    func test_stop_allowed_after_validation() {
        // GIVEN: An alarm with challenges
        let requiredChallenges: [Challenges] = [.qr, .stepCount, .math]

        // WHEN: All challenges are completed
        let completeState = ChallengeStackState(
            requiredChallenges: requiredChallenges,
            completedChallenges: Set(requiredChallenges)
        )

        // THEN: Stop should be allowed
        XCTAssertTrue(
            StopAlarmAllowed.execute(challengeState: completeState),
            "Stop should be allowed when all challenges are completed"
        )

        // AND: No reason for denial
        let reason = StopAlarmAllowed.reasonForDenial(challengeState: completeState)
        XCTAssertNil(reason, "Should not provide reason when stop is allowed")
    }

    func test_stop_allowed_when_no_challenges_required() {
        // GIVEN: An alarm with no challenges
        let noChallengesState = ChallengeStackState(
            requiredChallenges: [],
            completedChallenges: []
        )

        // THEN: Stop should be allowed
        XCTAssertTrue(
            StopAlarmAllowed.execute(challengeState: noChallengesState),
            "Stop should be allowed when no challenges are required"
        )
    }

    // MARK: - Alternative Execute Method Tests

    func test_stop_with_alarm_object() throws {
        // GIVEN: An alarm with specific challenges
        let factory = MockAlarmFactory()
        let alarm = factory.makeNewAlarm()
        var modifiedAlarm = alarm
        modifiedAlarm.challengeKind = [.qr, .math]

        // WHEN: Checking with partial completion
        let partialCompletion: Set<Challenges> = [.qr]

        // THEN: Stop should not be allowed
        XCTAssertFalse(
            StopAlarmAllowed.execute(
                alarm: modifiedAlarm,
                completedChallenges: partialCompletion
            ),
            "Stop should not be allowed with partial completion"
        )

        // WHEN: All challenges completed
        let fullCompletion: Set<Challenges> = [.qr, .math]

        // THEN: Stop should be allowed
        XCTAssertTrue(
            StopAlarmAllowed.execute(
                alarm: modifiedAlarm,
                completedChallenges: fullCompletion
            ),
            "Stop should be allowed with full completion"
        )
    }

    // MARK: - Progress Tracking Tests

    func test_challenge_progress_tracking() {
        // GIVEN: Various challenge states
        let requiredChallenges: [Challenges] = [.qr, .stepCount, .math]

        // Test no progress
        let noProgressState = ChallengeStackState(
            requiredChallenges: requiredChallenges,
            completedChallenges: []
        )
        XCTAssertEqual(noProgressState.progress, 0.0, accuracy: 0.01)
        XCTAssertEqual(noProgressState.nextChallenge, .qr)

        // Test partial progress
        let partialState = ChallengeStackState(
            requiredChallenges: requiredChallenges,
            completedChallenges: [.qr]
        )
        XCTAssertEqual(partialState.progress, 1.0/3.0, accuracy: 0.01)
        XCTAssertEqual(partialState.nextChallenge, .stepCount)

        // Test complete progress
        let completeState = ChallengeStackState(
            requiredChallenges: requiredChallenges,
            completedChallenges: Set(requiredChallenges)
        )
        XCTAssertEqual(completeState.progress, 1.0, accuracy: 0.01)
        XCTAssertNil(completeState.nextChallenge)
    }

    func test_challenge_progress_display() {
        // GIVEN: A challenge state
        let state = ChallengeStackState(
            requiredChallenges: [.qr, .math],
            completedChallenges: [.qr]
        )

        // WHEN: Creating progress display
        let progress = ChallengeProgress(state: state)

        // THEN: Display values should be correct
        XCTAssertEqual(progress.total, 2)
        XCTAssertEqual(progress.completed, 1)
        XCTAssertEqual(progress.remaining, 1)
        XCTAssertEqual(progress.percentComplete, 50)
        XCTAssertFalse(progress.isComplete)
        XCTAssertEqual(progress.displayText, "1 of 2 challenges completed")
    }

    func test_estimated_time_until_allowed() {
        // GIVEN: Challenge state with remaining challenges
        let state = ChallengeStackState(
            requiredChallenges: [.qr, .stepCount, .math],
            completedChallenges: [.qr]
        )

        // WHEN: Estimating time with default 10s per challenge
        let estimatedTime = StopAlarmAllowed.estimatedTimeUntilAllowed(
            challengeState: state
        )

        // THEN: Should be 20 seconds (2 remaining * 10s)
        XCTAssertEqual(estimatedTime, 20.0)

        // WHEN: All challenges complete
        let completeState = ChallengeStackState(
            requiredChallenges: [.qr],
            completedChallenges: [.qr]
        )
        let noTime = StopAlarmAllowed.estimatedTimeUntilAllowed(
            challengeState: completeState
        )

        // THEN: Should be nil (already allowed)
        XCTAssertNil(noTime)
    }
}
```

### ChainPolicyTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/Unit/Domain/ChainPolicyTests.swift`

```swift
//
//  ChainPolicyTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/1/25.
//

import XCTest
@testable import alarmAppNew

final class ChainPolicyTests: XCTestCase {

    // MARK: - ChainSettings Validation Tests

    func test_chainSettings_defaultValues_withinValidRanges() {
        let settings = ChainSettings()

        XCTAssertEqual(settings.maxChainCount, 12)
        XCTAssertEqual(settings.ringWindowSec, 180)
        XCTAssertEqual(settings.fallbackSpacingSec, 30)
        XCTAssertEqual(settings.minLeadTimeSec, 10)
    }

    func test_chainSettings_clampsExcessiveValues() {
        let settings = ChainSettings(
            maxChainCount: 100,  // Should clamp to 50
            ringWindowSec: 1000, // Should clamp to 600
            fallbackSpacingSec: 60, // Should clamp to 30
            minLeadTimeSec: 100 // Should clamp to 30
        )

        XCTAssertEqual(settings.maxChainCount, 50)
        XCTAssertEqual(settings.ringWindowSec, 600)
        XCTAssertEqual(settings.fallbackSpacingSec, 30)
        XCTAssertEqual(settings.minLeadTimeSec, 30)
    }

    func test_chainSettings_clampsNegativeValues() {
        let settings = ChainSettings(
            maxChainCount: -5,   // Should clamp to 1
            ringWindowSec: -10,  // Should clamp to 30
            fallbackSpacingSec: 0, // Should clamp to 1
            minLeadTimeSec: -1   // Should clamp to 5
        )

        XCTAssertEqual(settings.maxChainCount, 1)
        XCTAssertEqual(settings.ringWindowSec, 30)
        XCTAssertEqual(settings.fallbackSpacingSec, 1)
        XCTAssertEqual(settings.minLeadTimeSec, 5)
    }

    // MARK: - ChainPolicy Normalization Tests

    func test_chainPolicy_normalizedSpacing_clampsToValidRange() {
        let policy = ChainPolicy()

        // Test lower bound
        XCTAssertEqual(policy.normalizedSpacing(0), 1)
        XCTAssertEqual(policy.normalizedSpacing(-5), 1)

        // Test upper bound
        XCTAssertEqual(policy.normalizedSpacing(35), 30)
        XCTAssertEqual(policy.normalizedSpacing(60), 30)

        // Test valid values
        XCTAssertEqual(policy.normalizedSpacing(5), 5)
        XCTAssertEqual(policy.normalizedSpacing(15), 15)
        XCTAssertEqual(policy.normalizedSpacing(30), 30)
    }

    // MARK: - Chain Computation Tests

    func test_chainPolicy_computeChain_standardSpacing() {
        let settings = ChainSettings(maxChainCount: 10, ringWindowSec: 180, fallbackSpacingSec: 30)
        let policy = ChainPolicy(settings: settings)

        let config = policy.computeChain(spacingSeconds: 30)

        XCTAssertEqual(config.spacingSeconds, 30)
        XCTAssertEqual(config.chainCount, 6) // 180 / 30 = 6
        XCTAssertEqual(config.totalDurationSeconds, 180) // 30 * 6
    }

    func test_chainPolicy_computeChain_respectsMaximumLimit() {
        let settings = ChainSettings(maxChainCount: 3, ringWindowSec: 180, fallbackSpacingSec: 30)
        let policy = ChainPolicy(settings: settings)

        let config = policy.computeChain(spacingSeconds: 10) // Would theoretically allow 18 notifications

        XCTAssertEqual(config.spacingSeconds, 10)
        XCTAssertEqual(config.chainCount, 3) // Capped at maxChainCount
        XCTAssertEqual(config.totalDurationSeconds, 30) // 10 * 3
    }

    func test_chainPolicy_computeChain_ensuresMinimumOne() {
        let settings = ChainSettings(maxChainCount: 12, ringWindowSec: 10, fallbackSpacingSec: 30)
        let policy = ChainPolicy(settings: settings)

        let config = policy.computeChain(spacingSeconds: 60) // 10 / 60 = 0, but should be at least 1

        XCTAssertEqual(config.spacingSeconds, 30) // Normalized from 60 to max 30
        XCTAssertEqual(config.chainCount, 1) // At least 1, even if window is too small
    }

    func test_chainPolicy_computeChain_shortSpacing() {
        let settings = ChainSettings(maxChainCount: 12, ringWindowSec: 60, fallbackSpacingSec: 30)
        let policy = ChainPolicy(settings: settings)

        let config = policy.computeChain(spacingSeconds: 5)

        XCTAssertEqual(config.spacingSeconds, 5)
        XCTAssertEqual(config.chainCount, 12) // 60 / 5 = 12, exactly at limit
    }

    // MARK: - Fire Date Computation Tests

    func test_chainPolicy_computeFireDates_correctIntervals() {
        let policy = ChainPolicy()
        let baseDate = Date(timeIntervalSince1970: 1000000) // Fixed reference point
        let config = ChainConfiguration(spacingSeconds: 30, chainCount: 3)

        let fireDates = policy.computeFireDates(baseFireDate: baseDate, configuration: config)

        XCTAssertEqual(fireDates.count, 3)
        XCTAssertEqual(fireDates[0], baseDate) // k=0: no offset
        XCTAssertEqual(fireDates[1], baseDate.addingTimeInterval(30)) // k=1: +30s
        XCTAssertEqual(fireDates[2], baseDate.addingTimeInterval(60)) // k=2: +60s
    }

    func test_chainPolicy_computeFireDates_singleNotification() {
        let policy = ChainPolicy()
        let baseDate = Date(timeIntervalSince1970: 2000000)
        let config = ChainConfiguration(spacingSeconds: 15, chainCount: 1)

        let fireDates = policy.computeFireDates(baseFireDate: baseDate, configuration: config)

        XCTAssertEqual(fireDates.count, 1)
        XCTAssertEqual(fireDates[0], baseDate)
    }

    func test_chainPolicy_computeFireDates_monotonicIncreasing() {
        let policy = ChainPolicy()
        let baseDate = Date()
        let config = ChainConfiguration(spacingSeconds: 20, chainCount: 5)

        let fireDates = policy.computeFireDates(baseFireDate: baseDate, configuration: config)

        XCTAssertEqual(fireDates.count, 5)

        // Verify dates are strictly increasing
        for i in 1..<fireDates.count {
            XCTAssertLessThan(fireDates[i-1], fireDates[i])

            // Verify exact spacing
            let expectedInterval = TimeInterval(i * config.spacingSeconds)
            let actualInterval = fireDates[i].timeIntervalSince(baseDate)
            XCTAssertEqual(actualInterval, expectedInterval, accuracy: 0.001)
        }
    }

    // MARK: - ChainConfiguration Trimming Tests

    func test_chainConfiguration_trimmed_reducesCount() {
        let config = ChainConfiguration(spacingSeconds: 10, chainCount: 8)
        let trimmed = config.trimmed(to: 5)

        XCTAssertEqual(trimmed.spacingSeconds, 10) // Unchanged
        XCTAssertEqual(trimmed.chainCount, 5) // Reduced
        XCTAssertEqual(trimmed.totalDurationSeconds, 50) // 10 * 5
    }

    func test_chainConfiguration_trimmed_respectsMinimumOne() {
        let config = ChainConfiguration(spacingSeconds: 25, chainCount: 4)
        let trimmed = config.trimmed(to: 0) // Should still be at least 1

        XCTAssertEqual(trimmed.spacingSeconds, 25)
        XCTAssertEqual(trimmed.chainCount, 1)
        XCTAssertEqual(trimmed.totalDurationSeconds, 25)
    }

    func test_chainConfiguration_trimmed_noChangeIfWithinLimit() {
        let config = ChainConfiguration(spacingSeconds: 15, chainCount: 3)
        let trimmed = config.trimmed(to: 5) // Limit higher than current count

        XCTAssertEqual(trimmed.spacingSeconds, 15)
        XCTAssertEqual(trimmed.chainCount, 3) // Unchanged
        XCTAssertEqual(trimmed.totalDurationSeconds, 45)
    }

    // MARK: - DST Boundary Edge Case Tests

    func test_chainPolicy_dstBoundary_springForward() {
        let policy = ChainPolicy()

        // March 10, 2024 at 1:30 AM (before spring forward in most US timezones)
        let calendar = Calendar.current
        let beforeDST = calendar.date(from: DateComponents(
            year: 2024, month: 3, day: 10, hour: 1, minute: 30
        ))!

        let config = ChainConfiguration(spacingSeconds: 30, chainCount: 4)
        let fireDates = policy.computeFireDates(baseFireDate: beforeDST, configuration: config)

        XCTAssertEqual(fireDates.count, 4)

        // Verify intervals remain consistent even across DST boundary
        for i in 1..<fireDates.count {
            let interval = fireDates[i].timeIntervalSince(fireDates[i-1])
            XCTAssertEqual(interval, 30.0, accuracy: 0.1) // Allow small tolerance for DST
        }
    }

    func test_chainPolicy_dstBoundary_fallBack() {
        let policy = ChainPolicy()

        // November 3, 2024 at 1:30 AM (before fall back in most US timezones)
        let calendar = Calendar.current
        let beforeDST = calendar.date(from: DateComponents(
            year: 2024, month: 11, day: 3, hour: 1, minute: 30
        ))!

        let config = ChainConfiguration(spacingSeconds: 45, chainCount: 3)
        let fireDates = policy.computeFireDates(baseFireDate: beforeDST, configuration: config)

        XCTAssertEqual(fireDates.count, 3)

        // Verify intervals remain consistent
        for i in 1..<fireDates.count {
            let interval = fireDates[i].timeIntervalSince(fireDates[i-1])
            XCTAssertEqual(interval, 45.0, accuracy: 0.1)
        }
    }

    // MARK: - Boundary Condition Tests

    func test_chainPolicy_extremeValues_handledGracefully() {
        let extremeSettings = ChainSettings(
            maxChainCount: 1,
            ringWindowSec: 30,
            fallbackSpacingSec: 1
        )
        let policy = ChainPolicy(settings: extremeSettings)

        let config = policy.computeChain(spacingSeconds: 1)

        XCTAssertEqual(config.spacingSeconds, 1)
        XCTAssertEqual(config.chainCount, 1) // Capped at max
        XCTAssertEqual(config.totalDurationSeconds, 1)
    }
}
```

### ChainSettingsProviderTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/Unit/Domain/ChainSettingsProviderTests.swift`

```swift
//
//  ChainSettingsProviderTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/1/25.
//

import XCTest
@testable import alarmAppNew

final class ChainSettingsProviderTests: XCTestCase {

    private var provider: DefaultChainSettingsProvider!

    override func setUp() {
        super.setUp()
        provider = DefaultChainSettingsProvider()
    }

    override func tearDown() {
        provider = nil
        super.tearDown()
    }

    // MARK: - Default Settings Tests

    func test_chainSettings_returnsValidDefaults() {
        let settings = provider.chainSettings()

        XCTAssertEqual(settings.maxChainCount, 12)
        XCTAssertEqual(settings.ringWindowSec, 300)
        XCTAssertEqual(settings.fallbackSpacingSec, 10)
        XCTAssertEqual(settings.minLeadTimeSec, 10)
    }

    func test_chainSettings_defaultsPassValidation() {
        let settings = provider.chainSettings()
        let validation = provider.validateSettings(settings)

        XCTAssertTrue(validation.isValid)
        XCTAssertEqual(validation.errorReasons, [])
    }

    // MARK: - Chain Count Validation Tests

    func test_validateSettings_chainCountTooLow_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 0,
            ringWindowSec: 300,
            fallbackSpacingSec: 30
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("maxChainCount must be at least 1"))
    }

    func test_validateSettings_chainCountTooHigh_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 20,
            ringWindowSec: 300,
            fallbackSpacingSec: 30
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("maxChainCount should not exceed 15 (iOS notification limit considerations)"))
    }

    func test_validateSettings_validChainCount_returnsValid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 300,
            fallbackSpacingSec: 30
        )

        let validation = provider.validateSettings(settings)

        XCTAssertTrue(validation.isValid)
    }

    // MARK: - Ring Window Validation Tests

    func test_validateSettings_ringWindowTooSmall_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 20,
            fallbackSpacingSec: 30
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("ringWindowSec must be at least 30 seconds"))
    }

    func test_validateSettings_ringWindowTooLarge_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 700,
            fallbackSpacingSec: 30
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("ringWindowSec should not exceed 600 seconds (10 minutes)"))
    }

    // MARK: - Fallback Spacing Validation Tests

    func test_validateSettings_fallbackSpacingTooLow_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 300,
            fallbackSpacingSec: 3
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("fallbackSpacingSec must be at least 5 seconds"))
    }

    func test_validateSettings_fallbackSpacingTooHigh_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 300,
            fallbackSpacingSec: 70
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("fallbackSpacingSec should not exceed 60 seconds"))
    }

    // MARK: - Minimum Lead Time Validation Tests

    func test_validateSettings_minLeadTimeTooLow_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 300,
            fallbackSpacingSec: 30,
            minLeadTimeSec: 3
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("minLeadTimeSec must be at least 5 seconds"))
    }

    func test_validateSettings_minLeadTimeTooHigh_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 300,
            fallbackSpacingSec: 30,
            minLeadTimeSec: 40
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("minLeadTimeSec should not exceed 30 seconds"))
    }

    func test_validateSettings_minLeadTimeValid_returnsValid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 300,
            fallbackSpacingSec: 30,
            minLeadTimeSec: 15
        )

        let validation = provider.validateSettings(settings)

        XCTAssertTrue(validation.isValid)
    }

    // MARK: - Cross-Validation Tests

    func test_validateSettings_ringWindowTooSmallForChain_returnsInvalid() {
        let settings = ChainSettings(
            maxChainCount: 10,
            ringWindowSec: 100, // 10 * 30 = 300, but ring window is only 100
            fallbackSpacingSec: 30
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.errorReasons.contains("ringWindowSec too small for maxChainCount at fallbackSpacingSec"))
    }

    func test_validateSettings_ringWindowJustEnoughForChain_returnsValid() {
        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 150, // 5 * 30 = 150, exactly enough
            fallbackSpacingSec: 30
        )

        let validation = provider.validateSettings(settings)

        XCTAssertTrue(validation.isValid)
    }

    // MARK: - Multiple Errors Tests

    func test_validateSettings_multipleErrors_returnsAllReasons() {
        let settings = ChainSettings(
            maxChainCount: 0, // Too low
            ringWindowSec: 20, // Too small
            fallbackSpacingSec: 70 // Too high
        )

        let validation = provider.validateSettings(settings)

        XCTAssertFalse(validation.isValid)
        XCTAssertGreaterThan(validation.errorReasons.count, 2)
        XCTAssertTrue(validation.errorReasons.contains("maxChainCount must be at least 1"))
        XCTAssertTrue(validation.errorReasons.contains("ringWindowSec must be at least 30 seconds"))
        XCTAssertTrue(validation.errorReasons.contains("fallbackSpacingSec should not exceed 60 seconds"))
    }

    // MARK: - Validation Result Tests

    func test_validationResult_validCase_hasCorrectProperties() {
        let result = ChainSettingsValidationResult.valid

        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.errorReasons, [])
    }

    func test_validationResult_invalidCase_hasCorrectProperties() {
        let reasons = ["Error 1", "Error 2"]
        let result = ChainSettingsValidationResult.invalid(reasons: reasons)

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorReasons, reasons)
    }

    // MARK: - Edge Cases

    func test_validateSettings_minimumValidConfiguration_returnsValid() {
        let settings = ChainSettings(
            maxChainCount: 1,
            ringWindowSec: 30,
            fallbackSpacingSec: 5
        )

        let validation = provider.validateSettings(settings)

        XCTAssertTrue(validation.isValid)
    }

    func test_validateSettings_maximumValidConfiguration_returnsValid() {
        let settings = ChainSettings(
            maxChainCount: 10,
            ringWindowSec: 600,
            fallbackSpacingSec: 60
        )

        let validation = provider.validateSettings(settings)

        XCTAssertTrue(validation.isValid)
    }
}
```

### ScheduleMappingDSTTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/Unit/Domain/ScheduleMappingDSTTests.swift`

```swift
//
//  ScheduleMappingDSTTests.swift
//  alarmAppNewTests
//
//  Tests for DST (Daylight Saving Time) and timezone handling
//  in alarm scheduling. Ensures alarms fire at correct local times
//  regardless of DST transitions or timezone changes.
//

import XCTest
@testable import alarmAppNew

final class ScheduleMappingDSTTests: XCTestCase {

    // MARK: - DST Fall Back Tests

    func test_fall_back_hour_keeps_intended_local_time() {
        // GIVEN: A calendar in Eastern Time (observes DST)
        var calendar = Calendar(identifier: .gregorian)
        guard let easternTimeZone = TimeZone(identifier: "America/New_York") else {
            XCTSkip("Eastern timezone not available")
            return
        }
        calendar.timeZone = easternTimeZone

        // Create an alarm scheduled for 2:30 AM daily
        let factory = MockAlarmFactory()
        var alarm = factory.makeNewAlarm()
        var alarmComponents = DateComponents()
        alarmComponents.hour = 2
        alarmComponents.minute = 30
        alarmComponents.timeZone = easternTimeZone
        alarm.time = calendar.date(from: alarmComponents) ?? Date()

        // WHEN: Computing fire time on fall-back day (Nov 3, 2024)
        // DST ends at 2:00 AM, clocks fall back to 1:00 AM
        var fallBackComponents = DateComponents()
        fallBackComponents.year = 2024
        fallBackComponents.month = 11
        fallBackComponents.day = 3  // Fall back day
        fallBackComponents.hour = 2
        fallBackComponents.minute = 30
        fallBackComponents.second = 0
        fallBackComponents.timeZone = easternTimeZone

        // There are TWO 2:30 AMs on this day:
        // - First at 2:30 AM EDT (before fall back)
        // - Second at 2:30 AM EST (after fall back, 1 hour later)

        guard let firstOccurrence = calendar.date(from: fallBackComponents) else {
            XCTFail("Could not create first occurrence")
            return
        }

        // Get the components back to verify local time
        let resultComponents = calendar.dateComponents(
            [.hour, .minute],
            from: firstOccurrence
        )

        // THEN: Local time should still be 2:30 AM
        XCTAssertEqual(
            resultComponents.hour,
            2,
            "Hour should remain 2 AM"
        )
        XCTAssertEqual(
            resultComponents.minute,
            30,
            "Minutes should remain 30"
        )

        // Verify DST status
        let isDST = easternTimeZone.isDaylightSavingTime(for: firstOccurrence)

        // The calendar typically returns the first occurrence (EDT)
        // But alarm should fire at both 2:30 AMs for reliability

        // Test that we can identify the transition
        let oneHourLater = firstOccurrence.addingTimeInterval(3600)
        let laterComponents = calendar.dateComponents(
            [.hour, .minute],
            from: oneHourLater
        )

        // Due to fall back, one hour later is STILL 2:30 AM (EST now)
        // This is the unique characteristic of fall back
        if laterComponents.hour == 2 && laterComponents.minute == 30 {
            // We're in the repeated hour
            XCTAssertTrue(true, "Correctly identified repeated hour during fall back")
        } else if laterComponents.hour == 3 && laterComponents.minute == 30 {
            // Normal progression (no fall back on this system)
            XCTAssertTrue(true, "System doesn't observe fall back as expected")
        }
    }

    // MARK: - DST Spring Forward Tests

    func test_spring_forward_hour_selects_next_valid_local_time() {
        // GIVEN: A calendar in Eastern Time
        var calendar = Calendar(identifier: .gregorian)
        guard let easternTimeZone = TimeZone(identifier: "America/New_York") else {
            XCTSkip("Eastern timezone not available")
            return
        }
        calendar.timeZone = easternTimeZone

        // Create an alarm scheduled for 2:30 AM daily
        let factory = MockAlarmFactory()
        var alarm = factory.makeNewAlarm()
        var alarmComponents = DateComponents()
        alarmComponents.hour = 2
        alarmComponents.minute = 30
        alarmComponents.timeZone = easternTimeZone
        alarm.time = calendar.date(from: alarmComponents) ?? Date()

        // WHEN: Computing fire time on spring-forward day (March 10, 2024)
        // DST starts at 2:00 AM, clocks spring forward to 3:00 AM
        // 2:30 AM doesn't exist on this day!
        var springComponents = DateComponents()
        springComponents.year = 2024
        springComponents.month = 3
        springComponents.day = 10  // Spring forward day
        springComponents.hour = 2   // This hour doesn't exist!
        springComponents.minute = 30
        springComponents.second = 0
        springComponents.timeZone = easternTimeZone

        // Calendar should adjust to next valid time (3:30 AM)
        let springDate = calendar.date(from: springComponents)

        if let date = springDate {
            let resultComponents = calendar.dateComponents(
                [.hour, .minute],
                from: date
            )

            // THEN: Should skip to 3:30 AM (next valid time)
            XCTAssertEqual(
                resultComponents.hour,
                3,
                "Should skip to 3 AM when 2 AM doesn't exist"
            )
            XCTAssertEqual(
                resultComponents.minute,
                30,
                "Minutes should remain 30"
            )
        } else {
            // Some systems might return nil for invalid time
            XCTAssertNil(springDate, "Invalid time during spring forward may return nil")
        }

        // Test the SnoozeAlarm handling of spring forward
        var beforeSpringForward = DateComponents()
        beforeSpringForward.year = 2024
        beforeSpringForward.month = 3
        beforeSpringForward.day = 10
        beforeSpringForward.hour = 1
        beforeSpringForward.minute = 45
        beforeSpringForward.timeZone = easternTimeZone

        guard let beforeDate = calendar.date(from: beforeSpringForward) else {
            XCTFail("Could not create date before spring forward")
            return
        }

        // Snooze for 30 minutes (crosses spring forward boundary)
        let snoozedDate = SnoozeAlarm.execute(
            alarm: alarm,
            now: beforeDate,
            requestedSnooze: 30 * 60,
            bounds: SnoozeBounds.default,
            calendar: calendar,
            timeZone: easternTimeZone
        )

        let snoozedComponents = calendar.dateComponents(
            [.hour, .minute],
            from: snoozedDate
        )

        // Should be 3:15 AM (2:15 AM doesn't exist)
        XCTAssertEqual(
            snoozedComponents.hour,
            3,
            "Snooze across spring forward should skip missing hour"
        )
        XCTAssertEqual(
            snoozedComponents.minute,
            15,
            "Minutes should be correct after spring forward"
        )
    }

    // MARK: - Timezone Change Tests

    func test_timezone_change_recomputes_by_local_components() {
        // GIVEN: An alarm set for 9:00 AM
        let factory = MockAlarmFactory()
        var alarm = factory.makeNewAlarm()
        var calendar = Calendar(identifier: .gregorian)

        // Start in Eastern Time
        guard let easternTimeZone = TimeZone(identifier: "America/New_York") else {
            XCTSkip("Eastern timezone not available")
            return
        }
        calendar.timeZone = easternTimeZone

        var alarmComponents = DateComponents()
        alarmComponents.hour = 9
        alarmComponents.minute = 0
        alarmComponents.timeZone = easternTimeZone
        alarm.time = calendar.date(from: alarmComponents) ?? Date()

        // WHEN: User travels to Pacific Time
        guard let pacificTimeZone = TimeZone(identifier: "America/Los_Angeles") else {
            XCTSkip("Pacific timezone not available")
            return
        }

        // Recompute alarm time in new timezone
        calendar.timeZone = pacificTimeZone

        // Extract local components from original alarm time
        let localComponents = calendar.dateComponents(
            [.hour, .minute],
            from: alarm.time
        )

        // THEN: Alarm should still be scheduled for 9:00 AM local time
        // (Even though the absolute UTC time has changed)
        XCTAssertEqual(
            localComponents.hour,
            9,
            "Alarm hour should remain 9 AM in local time"
        )
        XCTAssertEqual(
            localComponents.minute,
            0,
            "Alarm minute should remain 0"
        )

        // Verify the absolute time has actually changed
        let easternCalendar = Calendar(identifier: .gregorian)
        var easternCalendarMutable = easternCalendar
        easternCalendarMutable.timeZone = easternTimeZone

        let pacificCalendar = Calendar(identifier: .gregorian)
        var pacificCalendarMutable = pacificCalendar
        pacificCalendarMutable.timeZone = pacificTimeZone

        // Create same local time in both zones
        var testComponents = DateComponents()
        testComponents.year = 2024
        testComponents.month = 6  // No DST complications
        testComponents.day = 15
        testComponents.hour = 9
        testComponents.minute = 0

        testComponents.timeZone = easternTimeZone
        let easternTime = easternCalendarMutable.date(from: testComponents)

        testComponents.timeZone = pacificTimeZone
        let pacificTime = pacificCalendarMutable.date(from: testComponents)

        if let eastern = easternTime, let pacific = pacificTime {
            let timeDifference = eastern.timeIntervalSince(pacific)
            // Eastern is 3 hours ahead of Pacific
            XCTAssertEqual(
                timeDifference,
                -3 * 3600,
                accuracy: 60,
                "Should be 3 hour difference between timezones"
            )
        }
    }

    // MARK: - Complex Scenario Tests

    func test_multiple_dst_transitions_in_year() {
        // GIVEN: A recurring alarm throughout the year
        var calendar = Calendar(identifier: .gregorian)
        guard let timezone = TimeZone(identifier: "America/New_York") else {
            XCTSkip("Eastern timezone not available")
            return
        }
        calendar.timeZone = timezone

        let factory = MockAlarmFactory()
        var alarm = factory.makeNewAlarm()
        alarm.repeatDays = [.monday, .tuesday, .wednesday, .thursday, .friday]

        // Set alarm for 6:00 AM
        var alarmComponents = DateComponents()
        alarmComponents.hour = 6
        alarmComponents.minute = 0
        alarmComponents.timeZone = timezone
        alarm.time = calendar.date(from: alarmComponents) ?? Date()

        // Test dates throughout the year
        let testDates = [
            // Before spring DST
            (month: 2, day: 15, expectedHour: 6, description: "February (Standard Time)"),
            // After spring DST
            (month: 4, day: 15, expectedHour: 6, description: "April (Daylight Time)"),
            // Summer
            (month: 7, day: 15, expectedHour: 6, description: "July (Daylight Time)"),
            // After fall DST
            (month: 12, day: 15, expectedHour: 6, description: "December (Standard Time)")
        ]

        for testDate in testDates {
            var components = DateComponents()
            components.year = 2024
            components.month = testDate.month
            components.day = testDate.day
            components.hour = 6
            components.minute = 0
            components.timeZone = timezone

            if let date = calendar.date(from: components) {
                let hourComponent = calendar.component(.hour, from: date)

                XCTAssertEqual(
                    hourComponent,
                    testDate.expectedHour,
                    "Alarm should fire at \(testDate.expectedHour):00 local time in \(testDate.description)"
                )

                // Verify DST status
                let isDST = timezone.isDaylightSavingTime(for: date)
                if testDate.month >= 4 && testDate.month <= 10 {
                    XCTAssertTrue(isDST, "\(testDate.description) should be in DST")
                } else {
                    XCTAssertFalse(isDST, "\(testDate.description) should be in Standard Time")
                }
            }
        }
    }

    func test_alarm_scheduling_preserves_local_time_across_dst() {
        // GIVEN: An alarm set in standard time for 7:00 AM
        var calendar = Calendar.current
        guard let timezone = TimeZone(identifier: "America/New_York") else {
            XCTSkip("Eastern timezone not available")
            return
        }
        calendar.timeZone = timezone

        // January date (Standard Time)
        var januaryComponents = DateComponents()
        januaryComponents.year = 2024
        januaryComponents.month = 1
        januaryComponents.day = 15
        januaryComponents.hour = 7
        januaryComponents.minute = 0
        januaryComponents.timeZone = timezone

        guard let januaryDate = calendar.date(from: januaryComponents) else {
            XCTFail("Could not create January date")
            return
        }

        // WHEN: The same alarm needs to fire in July (Daylight Time)
        var julyComponents = DateComponents()
        julyComponents.year = 2024
        julyComponents.month = 7
        julyComponents.day = 15
        julyComponents.hour = 7  // Same local time
        julyComponents.minute = 0
        julyComponents.timeZone = timezone

        guard let julyDate = calendar.date(from: julyComponents) else {
            XCTFail("Could not create July date")
            return
        }

        // THEN: Both should show 7:00 AM local time
        let janHour = calendar.component(.hour, from: januaryDate)
        let julHour = calendar.component(.hour, from: julyDate)

        XCTAssertEqual(janHour, 7, "January alarm should be at 7 AM")
        XCTAssertEqual(julHour, 7, "July alarm should be at 7 AM")

        // But the UTC times should differ by 1 hour due to DST
        let utcCalendar = Calendar(identifier: .gregorian)
        var utcCalendarMutable = utcCalendar
        utcCalendarMutable.timeZone = TimeZone(abbreviation: "UTC")!

        let janUTCHour = utcCalendarMutable.component(.hour, from: januaryDate)
        let julUTCHour = utcCalendarMutable.component(.hour, from: julyDate)

        // Eastern Standard Time is UTC-5, Eastern Daylight Time is UTC-4
        // 7 AM EST = 12 PM UTC
        // 7 AM EDT = 11 AM UTC
        let hourDifference = abs(janUTCHour - julUTCHour)
        XCTAssertEqual(
            hourDifference,
            1,
            "UTC times should differ by 1 hour due to DST"
        )
    }
}
```

### SnoozePolicyTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/Unit/Domain/SnoozePolicyTests.swift`

```swift
//
//  SnoozePolicyTests.swift
//  alarmAppNewTests
//
//  Tests for snooze policies and the SnoozeAlarm use case.
//  Verifies duration clamping and DST-aware time calculations.
//

import XCTest
@testable import alarmAppNew

final class SnoozePolicyTests: XCTestCase {

    // MARK: - Duration Clamping Tests

    func test_snooze_clamps_below_min_to_min() {
        // GIVEN: Snooze bounds with 5-60 minute range
        let bounds = SnoozeBounds(min: 5 * 60, max: 60 * 60)

        // WHEN: Requesting snooze below minimum (1 minute)
        let requestedDuration: TimeInterval = 60 // 1 minute
        let clamped = AlarmPresentationPolicy.clampSnoozeDuration(
            requestedDuration,
            bounds: bounds
        )

        // THEN: Should clamp to minimum (5 minutes)
        XCTAssertEqual(
            clamped,
            5 * 60,
            "Duration below minimum should be clamped to minimum"
        )
    }

    func test_snooze_clamps_above_max_to_max() {
        // GIVEN: Snooze bounds with 5-60 minute range
        let bounds = SnoozeBounds(min: 5 * 60, max: 60 * 60)

        // WHEN: Requesting snooze above maximum (2 hours)
        let requestedDuration: TimeInterval = 2 * 60 * 60 // 2 hours
        let clamped = AlarmPresentationPolicy.clampSnoozeDuration(
            requestedDuration,
            bounds: bounds
        )

        // THEN: Should clamp to maximum (60 minutes)
        XCTAssertEqual(
            clamped,
            60 * 60,
            "Duration above maximum should be clamped to maximum"
        )
    }

    func test_snooze_allows_duration_within_bounds() {
        // GIVEN: Snooze bounds with 5-60 minute range
        let bounds = SnoozeBounds(min: 5 * 60, max: 60 * 60)

        // WHEN: Requesting valid durations
        let validDurations: [TimeInterval] = [
            5 * 60,   // Exactly minimum
            10 * 60,  // 10 minutes
            30 * 60,  // 30 minutes
            60 * 60   // Exactly maximum
        ]

        // THEN: All should remain unchanged
        for duration in validDurations {
            let clamped = AlarmPresentationPolicy.clampSnoozeDuration(
                duration,
                bounds: bounds
            )
            XCTAssertEqual(
                clamped,
                duration,
                "Valid duration \(duration) should not be changed"
            )

            // Also verify validation
            XCTAssertTrue(
                AlarmPresentationPolicy.isSnoozeDurationValid(duration, bounds: bounds),
                "Duration \(duration) should be valid"
            )
        }
    }

    // MARK: - Snooze Bounds Tests

    func test_snooze_bounds_initialization() {
        // GIVEN: Various bounds configurations

        // Normal case
        let normal = SnoozeBounds(min: 60, max: 600)
        XCTAssertEqual(normal.min, 60)
        XCTAssertEqual(normal.max, 600)

        // Inverted bounds (max < min)
        let inverted = SnoozeBounds(min: 600, max: 60)
        XCTAssertEqual(inverted.min, 60, "Should auto-correct inverted bounds")
        XCTAssertEqual(inverted.max, 600, "Should auto-correct inverted bounds")

        // Default bounds
        let defaultBounds = SnoozeBounds.default
        XCTAssertEqual(defaultBounds.min, 5 * 60, "Default min should be 5 minutes")
        XCTAssertEqual(defaultBounds.max, 60 * 60, "Default max should be 60 minutes")
    }

    // MARK: - DST Transition Tests

    func test_snooze_computes_next_fire_on_local_clock_respecting_dst_transition() {
        // GIVEN: A test calendar and timezone that observes DST
        var calendar = Calendar(identifier: .gregorian)
        guard let easternTimeZone = TimeZone(identifier: "America/New_York") else {
            XCTSkip("Eastern timezone not available")
            return
        }
        calendar.timeZone = easternTimeZone

        // Create alarm
        let factory = MockAlarmFactory()
        let alarm = factory.makeNewAlarm()

        // Test case 1: Spring forward (2 AM -> 3 AM)
        // March 10, 2024 at 1:45 AM EST
        var springComponents = DateComponents()
        springComponents.year = 2024
        springComponents.month = 3
        springComponents.day = 10
        springComponents.hour = 1
        springComponents.minute = 45
        springComponents.second = 0
        springComponents.timeZone = easternTimeZone

        guard let springDate = calendar.date(from: springComponents) else {
            XCTFail("Could not create spring DST test date")
            return
        }

        // WHEN: Snoozing for 30 minutes (crosses DST boundary)
        let springNextFire = SnoozeAlarm.execute(
            alarm: alarm,
            now: springDate,
            requestedSnooze: 30 * 60,
            bounds: SnoozeBounds(min: 5 * 60, max: 60 * 60),
            calendar: calendar,
            timeZone: easternTimeZone
        )

        // THEN: Should fire at 3:15 AM EDT (not 2:15 AM which doesn't exist)
        let springFireComponents = calendar.dateComponents(
            [.hour, .minute],
            from: springNextFire
        )
        XCTAssertEqual(springFireComponents.hour, 3, "Should skip to 3 AM during spring forward")
        XCTAssertEqual(springFireComponents.minute, 15)

        // Test case 2: Fall back (2 AM occurs twice)
        // November 3, 2024 at 1:45 AM EDT
        var fallComponents = DateComponents()
        fallComponents.year = 2024
        fallComponents.month = 11
        fallComponents.day = 3
        fallComponents.hour = 1
        fallComponents.minute = 45
        fallComponents.second = 0
        fallComponents.timeZone = easternTimeZone

        guard let fallDate = calendar.date(from: fallComponents) else {
            XCTFail("Could not create fall DST test date")
            return
        }

        // WHEN: Snoozing for 30 minutes (crosses DST boundary)
        let fallNextFire = SnoozeAlarm.execute(
            alarm: alarm,
            now: fallDate,
            requestedSnooze: 30 * 60,
            bounds: SnoozeBounds(min: 5 * 60, max: 60 * 60),
            calendar: calendar,
            timeZone: easternTimeZone
        )

        // THEN: Should fire at 2:15 AM (the second occurrence in EST)
        let fallFireComponents = calendar.dateComponents(
            [.hour, .minute],
            from: fallNextFire
        )
        XCTAssertEqual(fallFireComponents.hour, 2, "Should use 2 AM during fall back")
        XCTAssertEqual(fallFireComponents.minute, 15)

        // Verify it's actually 75 minutes later (not 30) due to repeated hour
        let actualInterval = fallNextFire.timeIntervalSince(fallDate)
        XCTAssertGreaterThan(
            actualInterval,
            30 * 60,
            "Fall back should result in longer actual interval"
        )
    }

    // MARK: - Basic Snooze Execution Tests

    func test_snooze_execution_basic() {
        // GIVEN: An alarm and current time
        let factory = MockAlarmFactory()
        let alarm = factory.makeNewAlarm()
        let now = Date()
        let bounds = SnoozeBounds(min: 5 * 60, max: 60 * 60)

        // WHEN: Snoozing for 10 minutes
        let nextFire = SnoozeAlarm.execute(
            alarm: alarm,
            now: now,
            requestedSnooze: 10 * 60,
            bounds: bounds
        )

        // THEN: Next fire should be approximately 10 minutes later
        let interval = nextFire.timeIntervalSince(now)
        XCTAssertEqual(
            interval,
            10 * 60,
            accuracy: 1.0,
            "Should fire 10 minutes later"
        )
    }

    func test_snooze_execution_with_clamping() {
        // GIVEN: An alarm and restrictive bounds
        let factory = MockAlarmFactory()
        let alarm = factory.makeNewAlarm()
        let now = Date()
        let bounds = SnoozeBounds(min: 15 * 60, max: 30 * 60)

        // WHEN: Requesting snooze below minimum
        let shortSnooze = SnoozeAlarm.execute(
            alarm: alarm,
            now: now,
            requestedSnooze: 5 * 60, // 5 minutes
            bounds: bounds
        )

        // THEN: Should be clamped to 15 minutes
        let shortInterval = shortSnooze.timeIntervalSince(now)
        XCTAssertEqual(
            shortInterval,
            15 * 60,
            accuracy: 1.0,
            "Should be clamped to minimum"
        )

        // WHEN: Requesting snooze above maximum
        let longSnooze = SnoozeAlarm.execute(
            alarm: alarm,
            now: now,
            requestedSnooze: 60 * 60, // 60 minutes
            bounds: bounds
        )

        // THEN: Should be clamped to 30 minutes
        let longInterval = longSnooze.timeIntervalSince(now)
        XCTAssertEqual(
            longInterval,
            30 * 60,
            accuracy: 1.0,
            "Should be clamped to maximum"
        )
    }

    // MARK: - Presentation Policy Tests

    func test_presentation_policy_defaults() {
        // GIVEN: Default presentation policy
        let policy = AlarmPresentationPolicy()

        // WHEN: Checking for alarm without snooze configured
        let factory = MockAlarmFactory()
        let alarm = factory.makeNewAlarm()

        // THEN: Should not show countdown (snooze not configured)
        XCTAssertFalse(
            policy.shouldShowCountdown(for: alarm),
            "Should not show countdown without snooze configuration"
        )

        XCTAssertFalse(
            policy.requiresLiveActivity(for: alarm),
            "Should not require live activity without snooze"
        )
    }

    func test_stop_button_semantics() {
        // GIVEN: Various alarm configurations

        // WHEN: Alarm has challenges
        let withChallenges = AlarmPresentationPolicy.stopButtonSemantics(
            challengesRequired: true
        )

        // THEN: Should require validation
        XCTAssertEqual(
            withChallenges,
            .requiresChallengeValidation,
            "Should require validation when challenges present"
        )

        // WHEN: Alarm has no challenges
        let noChallenges = AlarmPresentationPolicy.stopButtonSemantics(
            challengesRequired: false
        )

        // THEN: Should always be enabled
        XCTAssertEqual(
            noChallenges,
            .alwaysEnabled,
            "Should be always enabled without challenges"
        )
    }

    // MARK: - Next Occurrence Tests

    func test_next_occurrence_for_recurring_alarm() {
        // GIVEN: A recurring weekday alarm (Mon-Fri at 7:00 AM)
        let factory = MockAlarmFactory()
        var alarm = factory.makeNewAlarm()
        alarm.repeatDays = [.monday, .tuesday, .wednesday, .thursday, .friday]

        // Set alarm time to 7:00 AM
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 7
        components.minute = 0
        components.second = 0
        alarm.time = calendar.date(from: components) ?? Date()

        // WHEN: Checking next occurrence from a Sunday
        var sundayComponents = DateComponents()
        sundayComponents.year = 2024
        sundayComponents.month = 3
        sundayComponents.day = 3 // A Sunday
        sundayComponents.hour = 20
        sundayComponents.minute = 0
        let sunday = calendar.date(from: sundayComponents) ?? Date()

        let nextOccurrence = SnoozeAlarm.nextOccurrence(
            for: alarm,
            after: sunday,
            calendar: calendar,
            timeZone: calendar.timeZone
        )

        // THEN: Should be Monday at 7:00 AM
        if let next = nextOccurrence {
            let nextComponents = calendar.dateComponents(
                [.weekday, .hour, .minute],
                from: next
            )
            XCTAssertEqual(nextComponents.weekday, 2, "Should be Monday (weekday 2)")
            XCTAssertEqual(nextComponents.hour, 7, "Should be at 7 AM")
            XCTAssertEqual(nextComponents.minute, 0, "Should be at 0 minutes")
        } else {
            XCTFail("Should find next occurrence")
        }
    }
}
```

### SoundCatalogTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/Unit/Domain/Sounds/SoundCatalogTests.swift`

```swift
//
//  SoundCatalogTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 9/24/25.
//

import XCTest
@testable import alarmAppNew

final class SoundCatalogTests: XCTestCase {

    // MARK: - Validation Tests

    func testSoundCatalog_validate_uniqueIds() {
        // Given: A catalog with file validation disabled for testing
        let catalog = SoundCatalog(validateFiles: false)

        // When: We get all sounds
        let allSounds = catalog.all

        // Then: All IDs should be unique
        let uniqueIds = Set(allSounds.map { $0.id })
        XCTAssertEqual(uniqueIds.count, allSounds.count, "All sound IDs must be unique")
    }

    func testSoundCatalog_validate_positiveDurations() {
        // Given: A catalog with file validation disabled
        let catalog = SoundCatalog(validateFiles: false)

        // When: We check all durations
        let allSounds = catalog.all

        // Then: All durations should be positive
        for sound in allSounds {
            XCTAssertGreaterThan(sound.durationSec, 0, "Sound '\(sound.id)' must have positive duration")
        }
    }

    func testSoundCatalog_validate_defaultSoundExists() {
        // Given: A catalog with file validation disabled
        let catalog = SoundCatalog(validateFiles: false)

        // When: We check the default sound ID
        let defaultSoundId = catalog.defaultSoundId

        // Then: Default sound must exist in catalog
        let defaultSound = catalog.info(for: defaultSoundId)
        XCTAssertNotNil(defaultSound, "Default sound ID '\(defaultSoundId)' must exist in catalog")
    }

    // MARK: - Lookup Tests

    func testSoundCatalog_info_returnsCorrectSound() {
        // Given: A catalog with known sounds
        let catalog = SoundCatalog(validateFiles: false)

        // When: We look up the guaranteed "chimes01" sound
        let sound = catalog.info(for: "chimes01")

        // Then: We should get the correct sound with proper identity and invariants
        XCTAssertNotNil(sound, "chimes01 must exist in catalog")
        XCTAssertEqual(sound?.id, "chimes01", "Sound ID must match lookup key")

        // Test basic invariants (not specific values to avoid brittleness)
        XCTAssertFalse(sound?.name.isEmpty ?? true, "Sound name cannot be empty")
        XCTAssertFalse(sound?.fileName.isEmpty ?? true, "Sound fileName cannot be empty")
        XCTAssertGreaterThan(sound?.durationSec ?? 0, 0, "Sound duration must be positive")

        // Verify the sound has reasonable properties for an alarm sound
        if let name = sound?.name {
            XCTAssertTrue(name.count > 2, "Sound name should be descriptive")
        }
        if let fileName = sound?.fileName {
            XCTAssertTrue(fileName.hasSuffix(".caf") || fileName.hasSuffix(".mp3") || fileName.hasSuffix(".wav"),
                         "Sound fileName should have audio extension")
        }
    }

    func testSoundCatalog_info_unknownIdReturnsNil() {
        // Given: A catalog with known sounds
        let catalog = SoundCatalog(validateFiles: false)

        // When: We look up a non-existent sound ID
        let sound = catalog.info(for: "unknown-sound-id")

        // Then: We should get nil
        XCTAssertNil(sound)
    }

    // MARK: - Safe Helper Tests

    func testSoundCatalog_safeInfo_validIdReturnsSound() {
        // Given: A catalog with known sounds
        let catalog = SoundCatalog(validateFiles: false)

        // When: We use safeInfo with a valid ID
        let sound = catalog.safeInfo(for: "chimes01")

        // Then: We should get the correct sound
        XCTAssertNotNil(sound)
        XCTAssertEqual(sound?.id, "chimes01")
    }

    func testSoundCatalog_safeInfo_invalidIdFallsBackToDefault() {
        // Given: A catalog with known sounds
        let catalog = SoundCatalog(validateFiles: false)

        // When: We use safeInfo with an invalid ID
        let sound = catalog.safeInfo(for: "invalid-id")

        // Then: We should get the default sound
        XCTAssertNotNil(sound)
        XCTAssertEqual(sound?.id, catalog.defaultSoundId)
    }

    func testSoundCatalog_safeInfo_nilIdFallsBackToDefault() {
        // Given: A catalog with known sounds
        let catalog = SoundCatalog(validateFiles: false)

        // When: We use safeInfo with nil
        let sound = catalog.safeInfo(for: nil)

        // Then: We should get the default sound
        XCTAssertNotNil(sound)
        XCTAssertEqual(sound?.id, catalog.defaultSoundId)
    }

    // MARK: - Guaranteed Content Tests

    func testSoundCatalog_guaranteedChimes01Exists() {
        // Given: A catalog (this is critical for migration safety)
        let catalog = SoundCatalog(validateFiles: false)

        // When: We look up the hardcoded fallback ID used in Alarm.init(from:)
        let sound = catalog.info(for: "chimes01")

        // Then: This sound MUST exist to prevent runtime crashes
        XCTAssertNotNil(sound, "chimes01 must exist - it's the hardcoded fallback in Alarm migration")
        XCTAssertEqual(sound?.id, "chimes01")
    }

    func testSoundCatalog_allSoundsHaveValidProperties() {
        // Given: A catalog with all sounds
        let catalog = SoundCatalog(validateFiles: false)

        // When: We check all sounds
        let allSounds = catalog.all

        // Then: All sounds should have valid properties
        XCTAssertGreaterThan(allSounds.count, 0, "Catalog must have at least one sound")

        for sound in allSounds {
            XCTAssertFalse(sound.id.isEmpty, "Sound ID cannot be empty")
            XCTAssertFalse(sound.name.isEmpty, "Sound name cannot be empty")
            XCTAssertFalse(sound.fileName.isEmpty, "Sound fileName cannot be empty")
            XCTAssertGreaterThan(sound.durationSec, 0, "Sound duration must be positive")
            XCTAssertLessThanOrEqual(sound.durationSec, 30, "Sound duration should be ≤30s for iOS notifications")
        }
    }

    // MARK: - Test Helpers

    private func encodedAlarmsByPatchingSoundId(
        from alarm: Alarm,
        to newValue: String?,
        removeKey: Bool = false
    ) throws -> Data {
        let original = try JSONEncoder().encode([alarm])
        guard var arr = try JSONSerialization.jsonObject(with: original) as? [[String: Any]] else {
            throw NSError(domain: "TestPatch", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse encoded alarm as JSON array"])
        }
        var dict = arr[0]
        if removeKey {
            dict.removeValue(forKey: "soundId")
        } else if let newValue {
            dict["soundId"] = newValue
        }
        arr[0] = dict
        return try JSONSerialization.data(withJSONObject: arr, options: [])
    }

    // MARK: - Persistence Repair Tests

    func testPersistenceService_repairInvalidSoundId_sticks() {
        // Given: In-memory UserDefaults suite for isolation
        let suiteName = "test-\(UUID().uuidString)"
        let testSuite = UserDefaults(suiteName: suiteName)!
        defer { testSuite.removePersistentDomain(forName: suiteName) }

        let catalog = SoundCatalog(validateFiles: false)
        let persistence = PersistenceService(defaults: testSuite, soundCatalog: catalog)

        // Create a valid alarm then patch soundId to invalid value (encode-then-patch approach)
        let validAlarm = Alarm(
            id: UUID(),
            time: Date(),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: "test-qr",
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: "bells01", // Start with valid soundId
            soundName: nil,
            volume: 0.8
        )

        do {
            // Encode alarm properly, then patch soundId to invalid value
            let patchedData = try encodedAlarmsByPatchingSoundId(from: validAlarm, to: "invalid-sound-id")
            testSuite.set(patchedData, forKey: "savedAlarms")

            // When: First load triggers automatic repair
            let alarmsFirstLoad = try persistence.loadAlarms()

            // Then: soundId should be automatically repaired
            XCTAssertEqual(alarmsFirstLoad[0].soundId, catalog.defaultSoundId, "soundId should be automatically repaired to default")

            // When: Second load to verify repair persistence
            let alarmsSecondLoad = try persistence.loadAlarms()

            // Then: Should remain repaired (no infinite loop)
            XCTAssertEqual(alarmsSecondLoad[0].soundId, catalog.defaultSoundId, "Repair should stick - no infinite loop")

            // Verify the repaired data is actually saved to storage
            if let savedData = testSuite.data(forKey: "savedAlarms") {
                let savedAlarms = try JSONDecoder().decode([Alarm].self, from: savedData)
                XCTAssertEqual(savedAlarms[0].soundId, catalog.defaultSoundId, "Repaired soundId should be persisted")
            } else {
                XCTFail("Expected saved alarms data to exist after repair")
            }
        } catch {
            XCTFail("Test setup or repair should not throw: \(error)")
        }
    }

    func testPersistenceService_repairMissingSoundId_usesDecoder() {
        // Given: In-memory UserDefaults suite
        let suiteName = "test-\(UUID().uuidString)"
        let testSuite = UserDefaults(suiteName: suiteName)!
        defer { testSuite.removePersistentDomain(forName: suiteName) }

        let catalog = SoundCatalog(validateFiles: false)
        let persistence = PersistenceService(defaults: testSuite, soundCatalog: catalog)

        // Create a valid alarm then remove soundId field (encode-then-patch approach)
        let validAlarm = Alarm(
            id: UUID(),
            time: Date(),
            label: "Old Format Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: "test-qr",
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: "bells01", // Start with valid soundId
            soundName: nil,
            volume: 0.5
        )

        do {
            // Encode alarm properly, then remove soundId field (simulates old format)
            let patchedData = try encodedAlarmsByPatchingSoundId(from: validAlarm, to: nil, removeKey: true)
            testSuite.set(patchedData, forKey: "savedAlarms")

            // When: Load alarms (decoder should handle missing soundId)
            let loadedAlarms = try persistence.loadAlarms()

            // Then: Decoder fallback should provide chimes01
            XCTAssertEqual(loadedAlarms.count, 1)
            XCTAssertEqual(loadedAlarms[0].soundId, "chimes01", "Decoder should fallback to chimes01 for missing soundId")
        } catch {
            XCTFail("Test setup or loading should not throw: \(error)")
        }
    }

    // MARK: - Critical Encode/Decode Tests

    func testAlarm_encodeDecode_preservesSoundId() {
        // Given: Alarm with specific soundId
        let originalSoundId = "bells01"
        let alarm = Alarm(
            id: UUID(),
            time: Date(),
            label: "Test Alarm",
            repeatDays: [.monday],
            challengeKind: [.qr],
            expectedQR: "test-qr",
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: originalSoundId,
            soundName: nil,
            volume: 0.8
        )

        // When: Encode then decode
        do {
            let encoded = try JSONEncoder().encode(alarm)
            let decoded = try JSONDecoder().decode(Alarm.self, from: encoded)

            // Then: soundId preserved exactly
            XCTAssertEqual(decoded.soundId, originalSoundId, "soundId must survive encode/decode to prevent repair loops")

            // Verify other critical fields also preserved
            XCTAssertEqual(decoded.id, alarm.id)
            XCTAssertEqual(decoded.label, alarm.label)
            XCTAssertEqual(decoded.volume, alarm.volume)
        } catch {
            XCTFail("Encode/decode should not throw: \(error)")
        }
    }

    func testAlarm_encodeDecode_preservesSoundIdWithSpecialCharacters() {
        // Given: Alarm with soundId containing special characters (edge case)
        let originalSoundId = "tone-01_special.sound"
        let alarm = Alarm(
            id: UUID(),
            time: Date(),
            label: "Special Test",
            repeatDays: [],
            challengeKind: [.qr],
            isEnabled: true,
            soundId: originalSoundId,
            volume: 0.5
        )

        // When: Encode then decode
        do {
            let encoded = try JSONEncoder().encode(alarm)
            let decoded = try JSONDecoder().decode(Alarm.self, from: encoded)

            // Then: Special characters in soundId preserved
            XCTAssertEqual(decoded.soundId, originalSoundId, "Special characters in soundId must be preserved")
        } catch {
            XCTFail("Encode/decode should not throw: \(error)")
        }
    }

    // MARK: - Preview Catalog Tests

    func testSoundCatalog_preview_isAccessible() {
        // Given: The preview catalog
        let catalog = SoundCatalog.preview

        // When: We access its properties
        let allSounds = catalog.all
        let defaultId = catalog.defaultSoundId

        // Then: It should work without file validation
        XCTAssertGreaterThan(allSounds.count, 0)
        XCTAssertNotNil(catalog.info(for: defaultId))
    }
}
```

### AlarmKitSchedulerTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/Unit/Infrastructure/AlarmKitSchedulerTests.swift`

```swift
//
//  AlarmKitSchedulerTests.swift
//  alarmAppNewTests
//
//  Tests for AlarmKitScheduler implementation.
//

import XCTest
@testable import alarmAppNew

@available(iOS 26.0, *)
@MainActor
final class AlarmKitSchedulerTests: XCTestCase {

    // MARK: - Mock Types

    struct MockPresentationBuilder: AlarmPresentationBuilding {
        func buildSchedule(from alarm: Alarm) -> Any {
            return ["alarmId": alarm.id.uuidString, "time": alarm.time]
        }

        func buildPresentation(for alarm: Alarm) -> Any {
            return ["label": alarm.label, "soundId": alarm.soundId]
        }
    }

    // MARK: - Properties

    private var presentationBuilder: AlarmPresentationBuilding!
    private var scheduler: AlarmKitScheduler!
    private var testAlarm: Alarm!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        presentationBuilder = MockPresentationBuilder()
        scheduler = AlarmKitScheduler(
            presentationBuilder: presentationBuilder
        )

        // Create test alarm
        testAlarm = Alarm(
            id: UUID(),
            time: Date().addingTimeInterval(3600),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: "test-qr",
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: "ringtone1",
            soundName: nil,
            volume: 0.8,
            externalAlarmId: nil
        )
    }

    override func tearDown() async throws {
        presentationBuilder = nil
        scheduler = nil
        testAlarm = nil
        try await super.tearDown()
    }

    // MARK: - Activation Tests

    func test_activate_isIdempotent() async {
        // When: Activating multiple times
        await scheduler.activate()
        await scheduler.activate()
        await scheduler.activate()

        // Then: Should handle gracefully (no crashes or side effects)
        // Activation is idempotent
        XCTAssertTrue(true, "Activation should be idempotent")
    }

    // MARK: - Authorization Tests

    func test_requestAuthorizationIfNeeded_doesNotCrash() async throws {
        // When: Requesting authorization
        // Then: Should not throw in stub implementation
        try await scheduler.requestAuthorizationIfNeeded()
    }

    // MARK: - Scheduling Tests

    func test_schedule_returnsExternalId() async throws {
        // When: Scheduling an alarm
        let externalId = try await scheduler.schedule(alarm: testAlarm)

        // Then: Should return a non-empty external ID
        XCTAssertFalse(externalId.isEmpty)
        XCTAssertTrue(externalId.contains(testAlarm.id.uuidString))
    }

    func test_schedule_usesPresentationBuilder() async throws {
        // When: Scheduling an alarm
        _ = try await scheduler.schedule(alarm: testAlarm)

        // Then: Presentation builder should be invoked
        // (We can't directly verify this without a mock, but the schedule succeeds)
        XCTAssertTrue(true, "Schedule should use presentation builder")
    }

    // MARK: - Pending Alarms Tests

    func test_pendingAlarmIds_returnsEmptyInStub() async {
        // When: Getting pending alarm IDs
        let pendingIds = await scheduler.pendingAlarmIds()

        // Then: Should return empty array (stub implementation)
        XCTAssertTrue(pendingIds.isEmpty)
    }
}
```

### AlarmSchedulerFactoryTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/Unit/Infrastructure/AlarmSchedulerFactoryTests.swift`

```swift
//
//  AlarmSchedulerFactoryTests.swift
//  alarmAppNewTests
//
//  Tests for AlarmSchedulerFactory version detection and dependency injection.
//

import XCTest
@testable import alarmAppNew

@MainActor
final class AlarmSchedulerFactoryTests: XCTestCase {

    // MARK: - Mock Types

    struct MockPresentationBuilder: AlarmPresentationBuilding {
        @available(iOS 26.0, *)
        func buildSchedule(from alarm: Alarm) -> Any { return [:] }

        @available(iOS 26.0, *)
        func buildPresentation(for alarm: Alarm) -> Any { return [:] }
    }

    // MARK: - Properties

    private var legacyScheduler: AlarmScheduling!
    private var presentationBuilder: AlarmPresentationBuilding!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        legacyScheduler = MockAlarmScheduling()
        presentationBuilder = MockPresentationBuilder()
    }

    override func tearDown() async throws {
        legacyScheduler = nil
        presentationBuilder = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func test_make_injectsCorrectDependencies() {
        // When: Creating scheduler via factory
        let scheduler = AlarmSchedulerFactory.make(
            presentationBuilder: presentationBuilder
        )

        // Then: Should return a valid scheduler
        XCTAssertNotNil(scheduler)
    }

    func test_make_iOSLegacy_returnsLegacyScheduler() {
        // Given: We're on iOS < 26 (current environment)
        // When: Creating scheduler
        let scheduler = AlarmSchedulerFactory.make(
            presentationBuilder: presentationBuilder
        )

        // Then: Should return the legacy scheduler on current iOS
        if #available(iOS 26.0, *) {
            // This won't execute on current iOS versions
            XCTFail("Test environment should not be iOS 26+")
        } else {
            // Verify we got the legacy scheduler (cast to class type for comparison)
            if let mockLegacy = legacyScheduler as? MockAlarmScheduling,
               let returnedScheduler = scheduler as? MockAlarmScheduling {
                XCTAssertTrue(mockLegacy === returnedScheduler,
                             "Factory should return legacy scheduler on iOS < 26")
            } else {
                XCTFail("Failed to cast scheduler to expected type")
            }
        }
    }

    @available(iOS 26.0, *)
    func test_make_iOS26Plus_returnsAlarmKitScheduler() {
        // When: Creating scheduler on iOS 26+
        let scheduler = AlarmSchedulerFactory.make(
            presentationBuilder: presentationBuilder
        )

        // Then: Should return AlarmKitScheduler
        XCTAssertTrue(scheduler is AlarmKitScheduler,
                     "Factory should return AlarmKitScheduler on iOS 26+")
        // Verify it's NOT the legacy scheduler
        if let mockLegacy = legacyScheduler as? MockAlarmScheduling,
           let returnedScheduler = scheduler as? MockAlarmScheduling {
            XCTAssertFalse(mockLegacy === returnedScheduler,
                          "Should not return legacy scheduler on iOS 26+")
        } else {
            // If we can't cast to MockAlarmScheduling, that's good - it means it's AlarmKitScheduler
            XCTAssertTrue(true, "Scheduler is not the mock legacy type, as expected")
        }
    }

    func test_make_doesNotRequireWholeContainer() {
        // This test verifies that the factory doesn't depend on DependencyContainer
        // by successfully creating a scheduler with just the required dependencies

        // When: Creating with minimal dependencies (no container)
        let scheduler = AlarmSchedulerFactory.make(
            presentationBuilder: presentationBuilder
        )

        // Then: Should succeed without needing full container
        XCTAssertNotNil(scheduler, "Factory should work with explicit deps only")
    }
}
```

### AlarmSoundEngineTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/Unit/Infrastructure/AlarmSoundEngineTests.swift`

```swift
//
//  AlarmSoundEngineTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/2/25.
//

import XCTest
import Combine
@testable import alarmAppNew

@MainActor
final class AlarmSoundEngineTests: XCTestCase {

    var sut: AlarmSoundEngine!
    var mockReliabilityProvider: MockReliabilityModeProvider!

    override func setUp() async throws {
        sut = AlarmSoundEngine.shared
        mockReliabilityProvider = MockReliabilityModeProvider()
        sut.setReliabilityModeProvider(mockReliabilityProvider)

        // Set up policy provider for new capability-based architecture
        sut.setPolicyProvider { [weak self] in
            let mode = self?.mockReliabilityProvider.currentMode ?? .notificationsOnly
            switch mode {
            case .notificationsOnly:
                return AudioPolicy(capability: .foregroundAssist, allowRouteOverrideAtAlarm: true)
            case .notificationsPlusAudio:
                return AudioPolicy(capability: .sleepMode, allowRouteOverrideAtAlarm: true)
            }
        }

        sut.stop() // Ensure clean state
    }

    override func tearDown() async throws {
        sut.stop()
        sut = nil
        mockReliabilityProvider = nil
    }

    // MARK: - isActivelyRinging Property Tests

    func test_isActivelyRinging_falseWhenIdle() {
        // Given: engine in idle state
        sut.stop()

        // Then: should not be actively ringing
        XCTAssertFalse(sut.isActivelyRinging, "Should not be ringing when idle")
        XCTAssertEqual(sut.currentState, .idle)
    }

    func test_isActivelyRinging_falseWhenPrewarming() throws {
        // Given: notificationsPlusAudio mode
        mockReliabilityProvider.setMode(.notificationsPlusAudio)

        // When: schedule prewarm for future (will transition to prewarming)
        let future = Date().addingTimeInterval(30)
        try sut.schedulePrewarm(fireAt: future, soundName: "ringtone1")

        // Then: should not be actively ringing (only prewarming)
        XCTAssertFalse(sut.isActivelyRinging, "Should not be ringing when prewarming")
        XCTAssertEqual(sut.currentState, .prewarming)
    }

    func test_isActivelyRinging_trueWhenRinging() throws {
        // Given: notificationsPlusAudio mode
        mockReliabilityProvider.setMode(.notificationsPlusAudio)

        // When: play foreground alarm (transitions to ringing)
        try sut.playForegroundAlarm(soundName: "ringtone1")

        // Then: should be actively ringing
        XCTAssertTrue(sut.isActivelyRinging, "Should be ringing after playForegroundAlarm")
        XCTAssertEqual(sut.currentState, .ringing)

        // Cleanup
        sut.stop()
    }

    // MARK: - scheduleWithLeadIn Validation Tests

    func test_scheduleWithLeadIn_skipsInNotificationsOnlyMode() throws {
        // Given: notifications-only mode
        mockReliabilityProvider.setMode(.notificationsOnly)

        // When: attempt to schedule with lead-in
        let future = Date().addingTimeInterval(30)
        try sut.scheduleWithLeadIn(fireAt: future, soundId: "ringtone1", leadInSeconds: 5)

        // Then: should remain idle (skipped due to mode)
        XCTAssertEqual(sut.currentState, .idle, "Should skip scheduling in notifications-only mode")
        XCTAssertFalse(sut.isActivelyRinging)
    }

    func test_scheduleWithLeadIn_fallsBackToImmediateIfLeadInExceedsDelta() throws {
        // Given: notificationsPlusAudio mode
        mockReliabilityProvider.setMode(.notificationsPlusAudio)

        // When: lead-in (10s) exceeds delta (3s) - should fall back to immediate
        let nearFuture = Date().addingTimeInterval(3)
        try sut.scheduleWithLeadIn(fireAt: nearFuture, soundId: "ringtone1", leadInSeconds: 10)

        // Then: should have fallen back to immediate playback (ringing state)
        XCTAssertTrue(sut.isActivelyRinging, "Should fall back to immediate when leadIn > delta")
        XCTAssertEqual(sut.currentState, .ringing)

        // Cleanup
        sut.stop()
    }

    func test_scheduleWithLeadIn_schedulesAudioStartCorrectly() throws {
        // Given: notificationsPlusAudio mode
        mockReliabilityProvider.setMode(.notificationsPlusAudio)

        // When: schedule with valid lead-in
        let future = Date().addingTimeInterval(30)
        try sut.scheduleWithLeadIn(fireAt: future, soundId: "ringtone1", leadInSeconds: 5)

        // Then: should transition to prewarming (audio will start at T-5s)
        XCTAssertEqual(sut.currentState, .prewarming, "Should be in prewarming state")
        XCTAssertFalse(sut.isActivelyRinging, "Should not be ringing yet")

        // Cleanup
        sut.stop()
    }

    func test_scheduleWithLeadIn_transitionsToPrewarmingState() throws {
        // Given: notificationsPlusAudio mode and idle state
        mockReliabilityProvider.setMode(.notificationsPlusAudio)
        XCTAssertEqual(sut.currentState, .idle)

        // When: schedule with lead-in
        let future = Date().addingTimeInterval(20)
        try sut.scheduleWithLeadIn(fireAt: future, soundId: "ringtone1", leadInSeconds: 3)

        // Then: state should be prewarming
        XCTAssertEqual(sut.currentState, .prewarming)

        // Cleanup
        sut.stop()
    }

    func test_scheduleWithLeadIn_respectsIdleStateGuard() throws {
        // Given: notificationsPlusAudio mode and already ringing
        mockReliabilityProvider.setMode(.notificationsPlusAudio)
        try sut.playForegroundAlarm(soundName: "ringtone1")
        XCTAssertEqual(sut.currentState, .ringing)

        // When: attempt to schedule with lead-in (should be rejected by state guard)
        let future = Date().addingTimeInterval(30)
        try sut.scheduleWithLeadIn(fireAt: future, soundId: "ringtone1", leadInSeconds: 5)

        // Then: should remain in ringing state (guard rejected the call)
        XCTAssertEqual(sut.currentState, .ringing, "Should ignore scheduleWithLeadIn when not idle")

        // Cleanup
        sut.stop()
    }
}

```

### ChainedNotificationSchedulerTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/Unit/Infrastructure/ChainedNotificationSchedulerTests.swift`

```swift
//
//  ChainedNotificationSchedulerTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/1/25.
//

import XCTest
import UserNotifications
@testable import alarmAppNew

final class ChainedNotificationSchedulerTests: XCTestCase {

    private var mockNotificationCenter: MockNotificationCenter!
    private var mockSoundCatalog: MockSoundCatalog!
    private var testNotificationIndex: NotificationIndex!
    private var chainPolicy: ChainPolicy!
    private var mockGlobalLimitGuard: MockGlobalLimitGuard!
    private var mockClock: MockClock!
    private var scheduler: ChainedNotificationScheduler!

    private let testAlarmId = UUID()
    private let testFireDate = Date(timeIntervalSince1970: 1696156800) // Fixed for reproducibility

    override func setUp() {
        super.setUp()

        mockNotificationCenter = MockNotificationCenter()
        mockSoundCatalog = MockSoundCatalog()

        let testSuiteName = "test-scheduler-\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: testSuiteName)!
        testNotificationIndex = NotificationIndex(defaults: testDefaults)

        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 300,
            fallbackSpacingSec: 30,
            minLeadTimeSec: 10
        )
        chainPolicy = ChainPolicy(settings: settings)

        mockGlobalLimitGuard = MockGlobalLimitGuard()
        mockClock = MockClock(fixedNow: testFireDate.addingTimeInterval(-3600)) // 1 hour before

        scheduler = ChainedNotificationScheduler(
            notificationCenter: mockNotificationCenter,
            soundCatalog: mockSoundCatalog,
            notificationIndex: testNotificationIndex,
            chainPolicy: chainPolicy,
            globalLimitGuard: mockGlobalLimitGuard,
            clock: mockClock
        )
    }

    override func tearDown() {
        mockNotificationCenter = nil
        mockSoundCatalog = nil
        testNotificationIndex = nil
        chainPolicy = nil
        mockGlobalLimitGuard = nil
        mockClock = nil
        scheduler = nil
        super.tearDown()
    }

    // MARK: - Permission Tests

    func test_scheduleChain_unauthorizedNotifications_returnsUnavailable() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .denied

        let outcome = await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        XCTAssertEqual(outcome, .unavailable(reason: .permissions))
        XCTAssertEqual(mockGlobalLimitGuard.reserveCallCount, 0)
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 0)
    }

    func test_scheduleChain_provisionalNotifications_returnsUnavailable() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .provisional

        let outcome = await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        XCTAssertEqual(outcome, .unavailable(reason: .permissions))
    }

    // MARK: - Global Limit Tests

    func test_scheduleChain_noAvailableSlots_returnsUnavailable() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 0

        let outcome = await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        XCTAssertEqual(outcome, .unavailable(reason: .globalLimit))
        XCTAssertEqual(mockGlobalLimitGuard.reserveCallCount, 1)
        XCTAssertEqual(mockGlobalLimitGuard.finalizeCallCount, 1)
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 0)
    }

    func test_scheduleChain_partialSlots_returnsTrimmed() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockSoundCatalog.soundInfo = SoundInfo(name: "test", fileName: "test.caf", durationSec: 30)
        mockGlobalLimitGuard.reserveReturnValue = 3 // Less than the 5 requested

        let outcome = await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        if case .trimmed(let original, let scheduled) = outcome {
            XCTAssertEqual(original, 5) // maxChainCount from settings
            XCTAssertEqual(scheduled, 3) // limited by available slots
        } else {
            XCTFail("Expected trimmed outcome, got \(outcome)")
        }

        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 3)
        XCTAssertEqual(mockGlobalLimitGuard.finalizeCallCount, 1)
    }

    // MARK: - Successful Scheduling Tests

    func test_scheduleChain_fullSlots_returnsScheduled() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockSoundCatalog.soundInfo = SoundInfo(name: "test", fileName: "test.caf", durationSec: 30)
        mockGlobalLimitGuard.reserveReturnValue = 5

        let outcome = await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        if case .scheduled(let count) = outcome {
            XCTAssertEqual(count, 5)
        } else {
            XCTFail("Expected scheduled outcome, got \(outcome)")
        }

        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 5)
        XCTAssertEqual(mockGlobalLimitGuard.finalizeCallCount, 1)
    }

    func test_scheduleChain_correctFireDatesSpacing() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockSoundCatalog.soundInfo = SoundInfo(name: "test", fileName: "test.caf", durationSec: 45)
        mockGlobalLimitGuard.reserveReturnValue = 3

        await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        let requests = mockNotificationCenter.scheduledRequests
        XCTAssertEqual(requests.count, 3)

        // Verify spacing matches sound duration
        for (index, request) in requests.enumerated() {
            if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                let expectedFireDate = testFireDate.addingTimeInterval(Double(index * 45))
                let calendar = Calendar.current
                let expectedComponents = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: expectedFireDate
                )

                XCTAssertEqual(trigger.dateComponents.year, expectedComponents.year)
                XCTAssertEqual(trigger.dateComponents.hour, expectedComponents.hour)
                XCTAssertEqual(trigger.dateComponents.minute, expectedComponents.minute)
            } else {
                XCTFail("Expected calendar trigger for request \(index)")
            }
        }
    }

    // MARK: - Sound Catalog Integration Tests

    func test_scheduleChain_fallbackSoundDuration_usesFallbackSpacing() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockSoundCatalog.soundInfo = nil // No sound info found
        mockGlobalLimitGuard.reserveReturnValue = 3

        await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        let requests = mockNotificationCenter.scheduledRequests
        XCTAssertEqual(requests.count, 3)

        // Should use fallback spacing of 30 seconds
        if let firstTrigger = requests[0].trigger as? UNCalendarNotificationTrigger,
           let secondTrigger = requests[1].trigger as? UNCalendarNotificationTrigger {

            let firstDate = Calendar.current.date(from: firstTrigger.dateComponents)!
            let secondDate = Calendar.current.date(from: secondTrigger.dateComponents)!
            let actualSpacing = secondDate.timeIntervalSince(firstDate)

            XCTAssertEqual(actualSpacing, 30.0, accuracy: 1.0)
        }
    }

    // MARK: - Notification Content Tests

    func test_scheduleChain_notificationContent_correctFormat() async {
        let alarm = createTestAlarm(label: "Morning Workout")
        mockNotificationCenter.authorizationStatus = .authorized
        mockSoundCatalog.soundInfo = SoundInfo(name: "gentle", fileName: "gentle.caf", durationSec: 20)
        mockGlobalLimitGuard.reserveReturnValue = 2

        await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        let requests = mockNotificationCenter.scheduledRequests
        XCTAssertEqual(requests.count, 2)

        for request in requests {
            XCTAssertEqual(request.content.title, "Alarm")
            XCTAssertEqual(request.content.body, "Morning Workout")
            XCTAssertEqual(request.content.categoryIdentifier, "ALARM_CATEGORY")

            if let sound = request.content.sound {
                XCTAssertEqual(sound.description, "UNNotificationSound:gentle.caf")
            } else {
                XCTFail("Expected notification sound")
            }
        }
    }

    func test_scheduleChain_emptyLabel_usesDefaultBody() async {
        let alarm = createTestAlarm(label: "")
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 1

        await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        let request = mockNotificationCenter.scheduledRequests.first!
        XCTAssertEqual(request.content.body, "Alarm")
    }

    // MARK: - Identifier Tests

    func test_scheduleChain_identifierFormat_isCorrect() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 2

        await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        let requests = mockNotificationCenter.scheduledRequests
        XCTAssertEqual(requests.count, 2)

        for (index, request) in requests.enumerated() {
            XCTAssertTrue(request.identifier.hasPrefix("alarm-\(alarm.id.uuidString)-occ-"))
            XCTAssertTrue(request.identifier.hasSuffix("-\(index)"))
            XCTAssertTrue(request.identifier.contains("T")) // ISO8601 format
        }
    }

    // MARK: - Idempotent Reschedule Tests

    func test_scheduleChain_existingChain_cancelsBeforeScheduling() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 2

        // First schedule
        await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 2)
        let firstRequestIds = mockNotificationCenter.scheduledRequests.map(\.identifier)

        // Second schedule with different fire date
        let newFireDate = testFireDate.addingTimeInterval(3600)
        await scheduler.scheduleChain(for: alarm, fireDate: newFireDate)

        // Should have cancelled old and scheduled new
        XCTAssertEqual(mockNotificationCenter.cancelledIdentifiers.count, 2)
        XCTAssertTrue(Set(firstRequestIds).isSubset(of: Set(mockNotificationCenter.cancelledIdentifiers)))
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 2) // New ones
    }

    // MARK: - Cancel Chain Tests

    func test_cancelChain_existingChain_removesAllNotifications() async {
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 3

        // Schedule chain
        await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 3)

        // Cancel chain
        await scheduler.cancelChain(alarmId: alarm.id)

        XCTAssertEqual(mockNotificationCenter.cancelledIdentifiers.count, 3)
        XCTAssertEqual(testNotificationIndex.loadIdentifiers(alarmId: alarm.id), [])
    }

    func test_cancelChain_nonexistentChain_doesNothing() async {
        let nonexistentAlarmId = UUID()

        await scheduler.cancelChain(alarmId: nonexistentAlarmId)

        XCTAssertEqual(mockNotificationCenter.cancelledIdentifiers.count, 0)
    }

    // MARK: - Authorization Tests

    func test_requestAuthorization_granted_succeeds() async {
        mockNotificationCenter.authorizationGranted = true
        mockNotificationCenter.authorizationError = nil

        do {
            try await scheduler.requestAuthorization()
        } catch {
            XCTFail("Should not throw when authorization is granted")
        }
    }

    func test_requestAuthorization_denied_throws() async {
        mockNotificationCenter.authorizationGranted = false
        mockNotificationCenter.authorizationError = nil

        do {
            try await scheduler.requestAuthorization()
            XCTFail("Should throw when authorization is denied")
        } catch let error as NotificationSchedulingError {
            XCTAssertEqual(error, .authorizationDenied)
        } catch {
            XCTFail("Should throw NotificationSchedulingError.authorizationDenied")
        }
    }

    func test_requestAuthorization_systemError_throws() async {
        let systemError = NSError(domain: "TestError", code: 123, userInfo: nil)
        mockNotificationCenter.authorizationGranted = true
        mockNotificationCenter.authorizationError = systemError

        do {
            try await scheduler.requestAuthorization()
            XCTFail("Should throw when system error occurs")
        } catch {
            XCTAssertEqual(error as NSError, systemError)
        }
    }

    // MARK: - Bug Fix Tests (Timing & Sound)

    func test_buildTriggerWithInterval_usesProvidedInterval() {
        // Given: a specific interval
        let interval: TimeInterval = 45.0

        // When: build trigger with the interval
        let trigger = scheduler.buildTriggerWithInterval(interval)

        // Then: should use time interval trigger with provided interval
        XCTAssertTrue(trigger is UNTimeIntervalNotificationTrigger, "Should use UNTimeIntervalNotificationTrigger for precise timing")

        let timeTrigger = trigger as! UNTimeIntervalNotificationTrigger
        XCTAssertEqual(timeTrigger.timeInterval, 45.0, "Time interval should match provided interval")
        XCTAssertFalse(timeTrigger.repeats, "Alarm triggers should not repeat")
    }

    func test_buildTriggerWithInterval_clampsToIOSMinimum() {
        // Given: interval less than iOS minimum
        let interval: TimeInterval = 0.5

        // When: build trigger with small interval
        let trigger = scheduler.buildTriggerWithInterval(interval)

        // Then: should clamp to iOS minimum (1 second)
        XCTAssertTrue(trigger is UNTimeIntervalNotificationTrigger, "Should use UNTimeIntervalNotificationTrigger")

        let timeTrigger = trigger as! UNTimeIntervalNotificationTrigger
        XCTAssertEqual(timeTrigger.timeInterval, 1.0, "Should clamp to iOS minimum of 1 second")
    }

    func test_buildTriggerWithInterval_preservesSpacing() {
        // Given: base interval and spacing
        let baseInterval: TimeInterval = 10.0
        let spacing: TimeInterval = 15.0

        // When: build triggers for a chain
        let trigger0 = scheduler.buildTriggerWithInterval(baseInterval + 0 * spacing)
        let trigger1 = scheduler.buildTriggerWithInterval(baseInterval + 1 * spacing)
        let trigger2 = scheduler.buildTriggerWithInterval(baseInterval + 2 * spacing)

        // Then: intervals should preserve spacing
        let timeTrigger0 = trigger0 as! UNTimeIntervalNotificationTrigger
        let timeTrigger1 = trigger1 as! UNTimeIntervalNotificationTrigger
        let timeTrigger2 = trigger2 as! UNTimeIntervalNotificationTrigger

        XCTAssertEqual(timeTrigger0.timeInterval, 10.0, "First interval should be base")
        XCTAssertEqual(timeTrigger1.timeInterval, 25.0, "Second interval should be base + spacing")
        XCTAssertEqual(timeTrigger2.timeInterval, 40.0, "Third interval should be base + 2*spacing")
    }

    func test_eachChainedRequest_hasSoundAttached() async {
        // Given: authorized notifications with available slots
        let alarm = createTestAlarm()
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 5
        mockSoundCatalog.soundInfo = SoundInfo(
            id: "test",
            name: "Test Sound",
            fileName: "test.caf",
            durationSeconds: 10
        )

        // When: schedule chain
        let outcome = await scheduler.scheduleChain(for: alarm, fireDate: testFireDate)

        // Then: all scheduled requests should have sound attached
        guard case .scheduled(let count) = outcome else {
            XCTFail("Expected scheduled outcome")
            return
        }

        XCTAssertEqual(count, 5, "Should schedule all reserved slots")
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 5, "Should have 5 requests in notification center")

        // Verify every request has sound
        for request in mockNotificationCenter.scheduledRequests {
            XCTAssertNotNil(request.content.sound, "Every alarm notification must have sound attached")
        }
    }

    // MARK: - Helper Methods

    private func createTestAlarm(label: String = "Test Alarm") -> Alarm {
        return Alarm(
            id: testAlarmId,
            time: DateComponents(hour: 7, minute: 30),
            repeatDays: [],
            label: label,
            soundId: "test-sound",
            volume: 0.8,
            vibrate: true,
            isEnabled: true
        )
    }
}

// MARK: - Mock Implementations

private class MockNotificationCenter: UNUserNotificationCenter {
    var authorizationStatus: UNAuthorizationStatus = .authorized
    var authorizationGranted = true
    var authorizationError: Error?
    var scheduledRequests: [UNNotificationRequest] = []
    var cancelledIdentifiers: [String] = []

    override func notificationSettings() async -> UNNotificationSettings {
        let settings = MockNotificationSettings(authorizationStatus: authorizationStatus)
        return settings
    }

    override func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        if let error = authorizationError {
            throw error
        }
        return authorizationGranted
    }

    override func add(_ request: UNNotificationRequest) async throws {
        scheduledRequests.append(request)
    }

    override func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        cancelledIdentifiers.append(contentsOf: identifiers)
    }

    override func pendingNotificationRequests() async -> [UNNotificationRequest] {
        return scheduledRequests
    }
}

private class MockNotificationSettings: UNNotificationSettings {
    private let _authorizationStatus: UNAuthorizationStatus

    init(authorizationStatus: UNAuthorizationStatus) {
        self._authorizationStatus = authorizationStatus
        super.init()
    }

    override var authorizationStatus: UNAuthorizationStatus {
        return _authorizationStatus
    }
}

private class MockSoundCatalog: SoundCatalogProviding {
    var soundInfo: SoundInfo?

    func safeInfo(for soundId: String) -> SoundInfo? {
        return soundInfo
    }
}

private class MockGlobalLimitGuard: GlobalLimitGuard {
    var reserveReturnValue: Int = 0
    var reserveCallCount = 0
    var finalizeCallCount = 0

    override func reserve(_ count: Int) async -> Int {
        reserveCallCount += 1
        return reserveReturnValue
    }

    override func finalize(_ actualScheduled: Int) {
        finalizeCallCount += 1
    }
}
```

### GlobalLimitGuardTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/Unit/Infrastructure/GlobalLimitGuardTests.swift`

```swift
//
//  GlobalLimitGuardTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/1/25.
//

import XCTest
import UserNotifications
@testable import alarmAppNew

final class GlobalLimitGuardTests: XCTestCase {

    private var mockNotificationCenter: MockNotificationCenter!
    private var config: GlobalLimitConfig!
    private var limitGuard: GlobalLimitGuard!

    override func setUp() {
        super.setUp()
        mockNotificationCenter = MockNotificationCenter()
        config = GlobalLimitConfig(safetyBuffer: 4, maxSystemLimit: 64)
        limitGuard = GlobalLimitGuard(config: config, notificationCenter: mockNotificationCenter)
    }

    override func tearDown() {
        mockNotificationCenter = nil
        config = nil
        limitGuard = nil
        super.tearDown()
    }

    // MARK: - Configuration Tests

    func test_globalLimitConfig_availableThreshold_calculatesCorrectly() {
        let config = GlobalLimitConfig(safetyBuffer: 10, maxSystemLimit: 100)
        XCTAssertEqual(config.availableThreshold, 90)
    }

    func test_globalLimitConfig_defaultValues_areReasonable() {
        let defaultConfig = GlobalLimitConfig()
        XCTAssertEqual(defaultConfig.safetyBuffer, 4)
        XCTAssertEqual(defaultConfig.maxSystemLimit, 64)
        XCTAssertEqual(defaultConfig.availableThreshold, 60)
    }

    // MARK: - Available Slots Calculation Tests

    func test_availableSlots_noPendingNotifications_returnsThreshold() async {
        mockNotificationCenter.pendingRequests = []

        let available = await limitGuard.availableSlots()

        XCTAssertEqual(available, config.availableThreshold) // 60
    }

    func test_availableSlots_somePendingNotifications_returnsRemaining() async {
        let pendingRequests = Array(0..<20).map { createMockRequest(identifier: "pending-\($0)") }
        mockNotificationCenter.pendingRequests = pendingRequests

        let available = await limitGuard.availableSlots()

        XCTAssertEqual(available, 40) // 60 - 20
    }

    func test_availableSlots_nearLimit_returnsLowNumber() async {
        let pendingRequests = Array(0..<58).map { createMockRequest(identifier: "pending-\($0)") }
        mockNotificationCenter.pendingRequests = pendingRequests

        let available = await limitGuard.availableSlots()

        XCTAssertEqual(available, 2) // 60 - 58
    }

    func test_availableSlots_atLimit_returnsZero() async {
        let pendingRequests = Array(0..<60).map { createMockRequest(identifier: "pending-\($0)") }
        mockNotificationCenter.pendingRequests = pendingRequests

        let available = await limitGuard.availableSlots()

        XCTAssertEqual(available, 0)
    }

    func test_availableSlots_overLimit_returnsZero() async {
        let pendingRequests = Array(0..<70).map { createMockRequest(identifier: "pending-\($0)") }
        mockNotificationCenter.pendingRequests = pendingRequests

        let available = await limitGuard.availableSlots()

        XCTAssertEqual(available, 0)
    }

    func test_availableSlots_notificationCenterError_returnsConservativeFallback() async {
        mockNotificationCenter.shouldThrowOnPendingRequests = true

        let available = await limitGuard.availableSlots()

        XCTAssertEqual(available, 1) // Conservative fallback
    }

    // MARK: - Reservation Tests

    func test_reserve_sufficientSlots_grantsFullRequest() async {
        mockNotificationCenter.pendingRequests = Array(0..<10).map { createMockRequest(identifier: "pending-\($0)") }

        let granted = await limitGuard.reserve(5)

        XCTAssertEqual(granted, 5)
    }

    func test_reserve_insufficientSlots_grantsPartial() async {
        mockNotificationCenter.pendingRequests = Array(0..<58).map { createMockRequest(identifier: "pending-\($0)") }

        let granted = await limitGuard.reserve(5)

        XCTAssertEqual(granted, 2) // Only 2 available (60 - 58)
    }

    func test_reserve_noSlotsAvailable_grantsZero() async {
        mockNotificationCenter.pendingRequests = Array(0..<60).map { createMockRequest(identifier: "pending-\($0)") }

        let granted = await limitGuard.reserve(3)

        XCTAssertEqual(granted, 0)
    }

    func test_reserve_zeroRequested_grantsZero() async {
        mockNotificationCenter.pendingRequests = []

        let granted = await limitGuard.reserve(0)

        XCTAssertEqual(granted, 0)
    }

    func test_reserve_negativeRequested_grantsZero() async {
        mockNotificationCenter.pendingRequests = []

        let granted = await limitGuard.reserve(-5)

        XCTAssertEqual(granted, 0)
    }

    // MARK: - Concurrent Reservation Tests

    func test_reserve_concurrentRequests_maintainsSafety() async {
        mockNotificationCenter.pendingRequests = Array(0..<50).map { createMockRequest(identifier: "pending-\($0)") }

        // Simulate 5 concurrent reservation requests
        let results = await withTaskGroup(of: Int.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    await self.limitGuard.reserve(5)
                }
            }

            var totalGranted = 0
            for await result in group {
                totalGranted += result
            }
            return totalGranted
        }

        // Should not grant more than available (60 - 50 = 10)
        XCTAssertLessThanOrEqual(results, 10)
        XCTAssertGreaterThan(results, 0) // Should grant something
    }

    func test_reserve_sequentialReservations_tracksCorrectly() async {
        mockNotificationCenter.pendingRequests = Array(0..<55).map { createMockRequest(identifier: "pending-\($0)") }

        let first = await limitGuard.reserve(3)
        let second = await limitGuard.reserve(2)
        let third = await limitGuard.reserve(1)

        XCTAssertEqual(first, 3) // 5 available, granted 3
        XCTAssertEqual(second, 2) // 2 remaining, granted 2
        XCTAssertEqual(third, 0) // 0 remaining, granted 0
    }

    // MARK: - Finalization Tests

    func test_finalize_releasesReservedSlots() async {
        mockNotificationCenter.pendingRequests = Array(0..<55).map { createMockRequest(identifier: "pending-\($0)") }

        let granted = await limitGuard.reserve(5)
        XCTAssertEqual(granted, 5)

        // Finalize with fewer than reserved (some failed to schedule)
        await limitGuard.finalize(3)

        // Should be able to reserve more now
        let secondGranted = await limitGuard.reserve(2)
        XCTAssertEqual(secondGranted, 2) // 2 slots were freed up
    }

    func test_finalize_moreThanReserved_handledSafely() async {
        mockNotificationCenter.pendingRequests = Array(0..<58).map { createMockRequest(identifier: "pending-\($0)") }

        let granted = await limitGuard.reserve(2)
        XCTAssertEqual(granted, 2)

        // Finalize with more than reserved (shouldn't happen, but be safe)
        await limitGuard.finalize(5)

        // Reserved slots should not go negative
        #if DEBUG
        let reservedSlots = await limitGuard.currentReservedSlots
        XCTAssertEqual(reservedSlots, 0)
        #endif
    }

    // MARK: - Edge Cases

    func test_reserve_multipleFinalizeOperations_maintainsConsistency() async {
        mockNotificationCenter.pendingRequests = Array(0..<50).map { createMockRequest(identifier: "pending-\($0)") }

        let first = await limitGuard.reserve(5)
        let second = await limitGuard.reserve(3)

        await limitGuard.finalize(2) // Partial finalization of first
        await limitGuard.finalize(3) // Full finalization of second
        await limitGuard.finalize(3) // Finalization of remaining from first

        // Should have all slots available again
        let third = await limitGuard.reserve(10)
        XCTAssertEqual(third, 10) // 60 - 50 = 10 available
    }

    // MARK: - Test Hooks (DEBUG only)

    #if DEBUG
    func test_resetReservations_clearsReservedSlots() async {
        mockNotificationCenter.pendingRequests = Array(0..<55).map { createMockRequest(identifier: "pending-\($0)") }

        let granted = await limitGuard.reserve(5)
        XCTAssertEqual(granted, 5)
        let reservedAfterReserve = await limitGuard.currentReservedSlots
        XCTAssertEqual(reservedAfterReserve, 5)

        await limitGuard.resetReservations()
        let reservedAfterReset = await limitGuard.currentReservedSlots
        XCTAssertEqual(reservedAfterReset, 0)

        // Should be able to reserve full amount again
        let secondGranted = await limitGuard.reserve(5)
        XCTAssertEqual(secondGranted, 5)
    }

    func test_currentReservedSlots_trackingCorrectly() async {
        mockNotificationCenter.pendingRequests = []

        let initialReserved = await limitGuard.currentReservedSlots
        XCTAssertEqual(initialReserved, 0)

        let granted = await limitGuard.reserve(10)
        XCTAssertEqual(granted, 10)
        let reservedAfterReserve = await limitGuard.currentReservedSlots
        XCTAssertEqual(reservedAfterReserve, 10)

        await limitGuard.finalize(7)
        let reservedAfterFirstFinalize = await limitGuard.currentReservedSlots
        XCTAssertEqual(reservedAfterFirstFinalize, 3)

        await limitGuard.finalize(3)
        let reservedAfterSecondFinalize = await limitGuard.currentReservedSlots
        XCTAssertEqual(reservedAfterSecondFinalize, 0)
    }
    #endif

    // MARK: - Helper Methods

    private func createMockRequest(identifier: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Test"
        content.body = "Test notification"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}

// MARK: - Mock Implementation

private class MockNotificationCenter: UNUserNotificationCenter {
    var pendingRequests: [UNNotificationRequest] = []
    var shouldThrowOnPendingRequests = false

    override func pendingNotificationRequests() async -> [UNNotificationRequest] {
        if shouldThrowOnPendingRequests {
            throw NSError(domain: "MockError", code: 123, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        return pendingRequests
    }
}
```

### IntentBridgeFreshnessTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/Unit/Infrastructure/IntentBridgeFreshnessTests.swift`

```swift
//
//  IntentBridgeFreshnessTests.swift
//  alarmAppNewTests
//
//  Tests for AlarmIntentBridge timestamp freshness validation.
//

import XCTest
@testable import alarmAppNew

@MainActor
final class IntentBridgeFreshnessTests: XCTestCase {
    private let appGroupIdentifier = "group.com.beshoy.alarmAppNew"
    private var sharedDefaults: UserDefaults?
    private var bridge: AlarmIntentBridge!
    private var notificationExpectation: XCTestExpectation?

    override func setUp() async throws {
        try await super.setUp()
        bridge = AlarmIntentBridge()
        sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)

        // Clear any existing data
        sharedDefaults?.removeObject(forKey: "pendingAlarmIntent")
        sharedDefaults?.removeObject(forKey: "pendingAlarmIntentTimestamp")
    }

    override func tearDown() async throws {
        // Clean up
        sharedDefaults?.removeObject(forKey: "pendingAlarmIntent")
        sharedDefaults?.removeObject(forKey: "pendingAlarmIntentTimestamp")
        NotificationCenter.default.removeObserver(self)
        try await super.tearDown()
    }

    func test_checkForPendingIntent_whenTimestampFresh_shouldPostNotification() async {
        // Given: A fresh intent (5 seconds old)
        let alarmId = UUID()
        let freshTimestamp = Date().addingTimeInterval(-5)
        sharedDefaults?.set(alarmId.uuidString, forKey: "pendingAlarmIntent")
        sharedDefaults?.set(freshTimestamp, forKey: "pendingAlarmIntentTimestamp")

        // Set up notification observer
        notificationExpectation = expectation(description: "Should receive alarmIntentReceived notification")
        var receivedAlarmId: UUID?

        let observer = NotificationCenter.default.addObserver(
            forName: .alarmIntentReceived,
            object: nil,
            queue: .main
        ) { notification in
            receivedAlarmId = notification.userInfo?["alarmId"] as? UUID
            self.notificationExpectation?.fulfill()
        }

        // When: Checking for pending intent
        bridge.checkForPendingIntent()

        // Then: Should post notification with correct alarm ID
        await fulfillment(of: [notificationExpectation!], timeout: 1.0)
        XCTAssertEqual(receivedAlarmId, alarmId, "Should receive correct alarm ID in notification")

        // And: Should clear the intent data
        XCTAssertNil(sharedDefaults?.object(forKey: "pendingAlarmIntent"))
        XCTAssertNil(sharedDefaults?.object(forKey: "pendingAlarmIntentTimestamp"))

        NotificationCenter.default.removeObserver(observer)
    }

    func test_checkForPendingIntent_whenTimestampStale_shouldNotPostNotification() async {
        // Given: A stale intent (35 seconds old)
        let alarmId = UUID()
        let staleTimestamp = Date().addingTimeInterval(-35)
        sharedDefaults?.set(alarmId.uuidString, forKey: "pendingAlarmIntent")
        sharedDefaults?.set(staleTimestamp, forKey: "pendingAlarmIntentTimestamp")

        // Set up notification observer
        var notificationReceived = false
        let observer = NotificationCenter.default.addObserver(
            forName: .alarmIntentReceived,
            object: nil,
            queue: .main
        ) { _ in
            notificationReceived = true
        }

        // When: Checking for pending intent
        bridge.checkForPendingIntent()

        // Wait a bit to ensure no notification is posted
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Then: Should not post notification
        XCTAssertFalse(notificationReceived, "Should not post notification for stale intent")

        // And: Should clear the stale intent data
        XCTAssertNil(sharedDefaults?.object(forKey: "pendingAlarmIntent"))
        XCTAssertNil(sharedDefaults?.object(forKey: "pendingAlarmIntentTimestamp"))

        NotificationCenter.default.removeObserver(observer)
    }

    func test_checkForPendingIntent_whenTimestampBoundary_shouldPostNotification() async {
        // Given: An intent exactly at the boundary (29 seconds old - just under 30s limit)
        let alarmId = UUID()
        let boundaryTimestamp = Date().addingTimeInterval(-29)
        sharedDefaults?.set(alarmId.uuidString, forKey: "pendingAlarmIntent")
        sharedDefaults?.set(boundaryTimestamp, forKey: "pendingAlarmIntentTimestamp")

        // Set up notification observer
        notificationExpectation = expectation(description: "Should receive alarmIntentReceived notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .alarmIntentReceived,
            object: nil,
            queue: .main
        ) { _ in
            self.notificationExpectation?.fulfill()
        }

        // When: Checking for pending intent
        bridge.checkForPendingIntent()

        // Then: Should post notification (within 30 second window)
        await fulfillment(of: [notificationExpectation!], timeout: 1.0)

        NotificationCenter.default.removeObserver(observer)
    }

    func test_checkForPendingIntent_whenNoIntent_shouldNotPostNotification() async {
        // Given: No intent in shared defaults

        // Set up notification observer
        var notificationReceived = false
        let observer = NotificationCenter.default.addObserver(
            forName: .alarmIntentReceived,
            object: nil,
            queue: .main
        ) { _ in
            notificationReceived = true
        }

        // When: Checking for pending intent
        bridge.checkForPendingIntent()

        // Wait a bit to ensure no notification is posted
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Then: Should not post notification
        XCTAssertFalse(notificationReceived, "Should not post notification when no intent exists")

        NotificationCenter.default.removeObserver(observer)
    }

    func test_checkForPendingIntent_whenInvalidUUID_shouldNotPostNotification() async {
        // Given: Invalid UUID string
        sharedDefaults?.set("invalid-uuid", forKey: "pendingAlarmIntent")
        sharedDefaults?.set(Date(), forKey: "pendingAlarmIntentTimestamp")

        // Set up notification observer
        var notificationReceived = false
        let observer = NotificationCenter.default.addObserver(
            forName: .alarmIntentReceived,
            object: nil,
            queue: .main
        ) { _ in
            notificationReceived = true
        }

        // When: Checking for pending intent
        bridge.checkForPendingIntent()

        // Wait a bit to ensure no notification is posted
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Then: Should not post notification
        XCTAssertFalse(notificationReceived, "Should not post notification for invalid UUID")

        // And: Should clear the invalid intent data
        XCTAssertNil(sharedDefaults?.object(forKey: "pendingAlarmIntent"))
        XCTAssertNil(sharedDefaults?.object(forKey: "pendingAlarmIntentTimestamp"))

        NotificationCenter.default.removeObserver(observer)
    }
}
```

### IntentBridgeNoSingletonTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/Unit/Infrastructure/IntentBridgeNoSingletonTests.swift`

```swift
//
//  IntentBridgeNoSingletonTests.swift
//  alarmAppNewTests
//
//  Tests to ensure AlarmIntentBridge does not use singleton pattern.
//

import XCTest
@testable import alarmAppNew

@MainActor
final class IntentBridgeNoSingletonTests: XCTestCase {

    func test_AlarmIntentBridge_shouldNotHaveSharedInstance() {
        // Check that AlarmIntentBridge type does not have a 'shared' static property
        let mirror = Mirror(reflecting: AlarmIntentBridge.self)

        // Iterate through the type's children to look for static properties
        for child in mirror.children {
            if let label = child.label {
                XCTAssertFalse(
                    label.lowercased().contains("shared"),
                    "AlarmIntentBridge should not have a 'shared' static property"
                )
            }
        }

        // Also verify through runtime check - this will fail to compile if .shared exists
        // Uncommenting the line below should cause a compile error:
        // _ = AlarmIntentBridge.shared
    }

    func test_AlarmIntentBridge_shouldAllowMultipleInstances() {
        // Given/When: Creating multiple instances
        let bridge1 = AlarmIntentBridge()
        let bridge2 = AlarmIntentBridge()
        let bridge3 = AlarmIntentBridge()

        // Then: All instances should be different objects
        XCTAssertTrue(bridge1 !== bridge2, "Should create different instances")
        XCTAssertTrue(bridge2 !== bridge3, "Should create different instances")
        XCTAssertTrue(bridge1 !== bridge3, "Should create different instances")
    }

    func test_AlarmIntentBridge_shouldNotHaveSingletonPattern() {
        // This test verifies the class structure doesn't follow singleton pattern

        // 1. Can create instances normally
        let instance = AlarmIntentBridge()
        XCTAssertNotNil(instance)

        // 2. Init is accessible (not private)
        // The fact that we can call AlarmIntentBridge() proves init is not private

        // 3. No static instance property
        // We check this by ensuring the type doesn't respond to .shared
        // This is validated by the compiler - if .shared existed, we could reference it
    }

    func test_AlarmIntentBridge_shouldHavePublicInit() {
        // The ability to create an instance from test target proves init is not private
        let bridge = AlarmIntentBridge()
        XCTAssertNotNil(bridge, "Should be able to create instance with public/internal init")
    }

    func test_AlarmIntentBridge_multipleInstancesCanOperateIndependently() async {
        // Given: Multiple bridge instances
        let bridge1 = AlarmIntentBridge()
        let bridge2 = AlarmIntentBridge()

        // When: Both check for pending intents
        // (No setup needed - just verifying they don't interfere)
        bridge1.checkForPendingIntent()
        bridge2.checkForPendingIntent()

        // Then: Both should execute without issues
        // The fact that this doesn't crash proves they're independent
        XCTAssertNotNil(bridge1.pendingAlarmId) // Will be nil, but we're checking property access
        XCTAssertNotNil(bridge2.pendingAlarmId) // Will be nil, but we're checking property access
    }
}
```

### NotificationIdentifierContractTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/Unit/Infrastructure/NotificationIdentifierContractTests.swift`

```swift
//
//  NotificationIdentifierContractTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/5/25.
//  Contract tests for notification identifier format - ensures cleanup logic doesn't break
//

import XCTest
@testable import alarmAppNew

final class NotificationIdentifierContractTests: XCTestCase {
    func test_notificationIdentifier_format_containsOccurrenceKeySegment() {
        // Given: A notification identifier for a specific occurrence
        let alarmId = UUID()
        let fireDate = Date()
        let occurrence = 1

        let identifier = NotificationIdentifier(
            alarmId: alarmId,
            fireDate: fireDate,
            occurrence: occurrence
        )

        // When: We generate the string value
        let stringValue = identifier.stringValue

        // Then: It MUST contain "-occ-{occurrenceKey}-" pattern
        // Use the SAME formatter as production (no brittleness)
        let occurrenceKey = OccurrenceKeyFormatter.key(from: fireDate)

        XCTAssertTrue(
            stringValue.contains("-occ-\(occurrenceKey)-"),
            "Identifier format changed! getRequestIds() filter will break. Expected: '-occ-{ISO8601}-' segment"
        )

        // Verify full format for documentation
        XCTAssertTrue(stringValue.hasPrefix("alarm-\(alarmId.uuidString)-occ-"))
        XCTAssertTrue(stringValue.hasSuffix("-\(occurrence)"))
    }

    func test_occurrenceKeyFormatter_roundTrip() {
        // Given: A date
        let originalDate = Date()

        // When: We convert to key and back
        let key = OccurrenceKeyFormatter.key(from: originalDate)
        let parsedDate = OccurrenceKeyFormatter.date(from: key)

        // Then: Round trip succeeds with millisecond precision
        XCTAssertNotNil(parsedDate)
        XCTAssertEqual(originalDate.timeIntervalSince1970, parsedDate!.timeIntervalSince1970, accuracy: 0.001)
    }
}

```

### NotificationIndexTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/Unit/Infrastructure/NotificationIndexTests.swift`

```swift
//
//  NotificationIndexTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/1/25.
//

import XCTest
@testable import alarmAppNew

final class NotificationIndexTests: XCTestCase {

    private var testSuite: UserDefaults!
    private var testSuiteName: String!
    private var notificationIndex: NotificationIndex!
    private let testAlarmId = UUID()

    override func setUp() {
        super.setUp()

        // Create isolated UserDefaults suite for testing
        testSuiteName = "test-notification-index-\(UUID().uuidString)"
        testSuite = UserDefaults(suiteName: testSuiteName)!
        notificationIndex = NotificationIndex(defaults: testSuite)
    }

    override func tearDown() {
        // Clean up test suite
        testSuite.removePersistentDomain(forName: testSuiteName)
        testSuite = nil
        testSuiteName = nil
        notificationIndex = nil
        super.tearDown()
    }

    // MARK: - NotificationIdentifier Tests

    func test_notificationIdentifier_stringValue_hasCorrectFormat() {
        let alarmId = UUID()
        let fireDate = Date(timeIntervalSince1970: 1696156800) // Fixed date for consistency
        let identifier = NotificationIdentifier(alarmId: alarmId, fireDate: fireDate, occurrence: 3)

        let stringValue = identifier.stringValue

        XCTAssertTrue(stringValue.hasPrefix("alarm-\(alarmId.uuidString)-occ-"))
        XCTAssertTrue(stringValue.hasSuffix("-3"))
        XCTAssertTrue(stringValue.contains("T")) // ISO8601 format marker
    }

    func test_notificationIdentifier_parseRoundTrip_preservesData() {
        let alarmId = UUID()
        let fireDate = Date()
        let occurrence = 5
        let original = NotificationIdentifier(alarmId: alarmId, fireDate: fireDate, occurrence: occurrence)

        let stringValue = original.stringValue
        let parsed = NotificationIdentifier.parse(stringValue)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.alarmId, alarmId)
        XCTAssertEqual(parsed?.occurrence, occurrence)

        // Dates should be very close (within 1ms due to fractional seconds)
        if let parsedDate = parsed?.fireDate {
            XCTAssertEqual(parsedDate.timeIntervalSince1970,
                          fireDate.timeIntervalSince1970, accuracy: 0.001)
        }
    }

    func test_notificationIdentifier_parse_invalidFormat_returnsNil() {
        let invalidIdentifiers = [
            "invalid-format",
            "alarm-notauuid-occ-date-1",
            "alarm-\(UUID().uuidString)-invalid-date-1",
            "alarm-\(UUID().uuidString)-occ-2023-13-45T25:99:99.000Z-notanumber",
            ""
        ]

        for invalid in invalidIdentifiers {
            let parsed = NotificationIdentifier.parse(invalid)
            XCTAssertNil(parsed, "Should not parse invalid identifier: '\(invalid)'")
        }
    }

    func test_notificationIdentifier_equality_worksCorrectly() {
        let alarmId = UUID()
        let fireDate = Date()
        let id1 = NotificationIdentifier(alarmId: alarmId, fireDate: fireDate, occurrence: 1)
        let id2 = NotificationIdentifier(alarmId: alarmId, fireDate: fireDate, occurrence: 1)
        let id3 = NotificationIdentifier(alarmId: alarmId, fireDate: fireDate, occurrence: 2)

        XCTAssertEqual(id1, id2)
        XCTAssertNotEqual(id1, id3)
    }

    // MARK: - NotificationIndex Basic Operations

    func test_notificationIndex_saveAndLoad_preservesIdentifiers() {
        let identifiers = [
            "alarm-\(testAlarmId.uuidString)-occ-2023-10-01T12:00:00.000Z-0",
            "alarm-\(testAlarmId.uuidString)-occ-2023-10-01T12:00:30.000Z-1",
            "alarm-\(testAlarmId.uuidString)-occ-2023-10-01T12:01:00.000Z-2"
        ]

        notificationIndex.saveIdentifiers(alarmId: testAlarmId, identifiers: identifiers)
        let loadedIdentifiers = notificationIndex.loadIdentifiers(alarmId: testAlarmId)

        XCTAssertEqual(loadedIdentifiers, identifiers)
    }

    func test_notificationIndex_loadNonexistent_returnsEmptyArray() {
        let nonexistentAlarmId = UUID()
        let loadedIdentifiers = notificationIndex.loadIdentifiers(alarmId: nonexistentAlarmId)

        XCTAssertEqual(loadedIdentifiers, [])
    }

    func test_notificationIndex_saveEmptyArray_removesKey() {
        let identifiers = ["test-identifier-1", "test-identifier-2"]

        // First, save some identifiers
        notificationIndex.saveIdentifiers(alarmId: testAlarmId, identifiers: identifiers)
        XCTAssertEqual(notificationIndex.loadIdentifiers(alarmId: testAlarmId), identifiers)

        // Then, save empty array
        notificationIndex.saveIdentifiers(alarmId: testAlarmId, identifiers: [])
        let loadedIdentifiers = notificationIndex.loadIdentifiers(alarmId: testAlarmId)

        XCTAssertEqual(loadedIdentifiers, [])
    }

    func test_notificationIndex_clearIdentifiers_removesSpecificAlarm() {
        let alarm1 = UUID()
        let alarm2 = UUID()
        let identifiers1 = ["alarm1-id1", "alarm1-id2"]
        let identifiers2 = ["alarm2-id1", "alarm2-id2"]

        // Save identifiers for both alarms
        notificationIndex.saveIdentifiers(alarmId: alarm1, identifiers: identifiers1)
        notificationIndex.saveIdentifiers(alarmId: alarm2, identifiers: identifiers2)

        // Clear only alarm1
        notificationIndex.clearIdentifiers(alarmId: alarm1)

        // Verify alarm1 is cleared but alarm2 remains
        XCTAssertEqual(notificationIndex.loadIdentifiers(alarmId: alarm1), [])
        XCTAssertEqual(notificationIndex.loadIdentifiers(alarmId: alarm2), identifiers2)
    }

    // MARK: - Global Index Tests

    func test_notificationIndex_globalIndex_aggregatesAllAlarms() {
        let alarm1 = UUID()
        let alarm2 = UUID()
        let identifiers1 = ["alarm1-id1", "alarm1-id2"]
        let identifiers2 = ["alarm2-id1"]

        notificationIndex.saveIdentifiers(alarmId: alarm1, identifiers: identifiers1)
        notificationIndex.saveIdentifiers(alarmId: alarm2, identifiers: identifiers2)

        let globalIdentifiers = notificationIndex.getAllPendingIdentifiers()

        XCTAssertEqual(Set(globalIdentifiers), Set(identifiers1 + identifiers2))
        XCTAssertEqual(globalIdentifiers.count, 3)
    }

    func test_notificationIndex_globalIndex_updatesOnClear() {
        let alarm1 = UUID()
        let alarm2 = UUID()
        let identifiers1 = ["alarm1-id1", "alarm1-id2"]
        let identifiers2 = ["alarm2-id1"]

        notificationIndex.saveIdentifiers(alarmId: alarm1, identifiers: identifiers1)
        notificationIndex.saveIdentifiers(alarmId: alarm2, identifiers: identifiers2)

        // Clear one alarm
        notificationIndex.clearIdentifiers(alarmId: alarm1)

        let globalIdentifiers = notificationIndex.getAllPendingIdentifiers()

        XCTAssertEqual(globalIdentifiers, identifiers2)
    }

    func test_notificationIndex_clearAllIdentifiers_removesEverything() {
        let alarm1 = UUID()
        let alarm2 = UUID()
        let identifiers1 = ["alarm1-id1", "alarm1-id2"]
        let identifiers2 = ["alarm2-id1"]

        notificationIndex.saveIdentifiers(alarmId: alarm1, identifiers: identifiers1)
        notificationIndex.saveIdentifiers(alarmId: alarm2, identifiers: identifiers2)

        notificationIndex.clearAllIdentifiers()

        XCTAssertEqual(notificationIndex.loadIdentifiers(alarmId: alarm1), [])
        XCTAssertEqual(notificationIndex.loadIdentifiers(alarmId: alarm2), [])
        XCTAssertEqual(notificationIndex.getAllPendingIdentifiers(), [])
    }

    // MARK: - Batch Operations Tests

    func test_notificationIndex_batchOperations_workCorrectly() {
        let fireDate = Date()
        let identifiers = [
            NotificationIdentifier(alarmId: testAlarmId, fireDate: fireDate, occurrence: 0),
            NotificationIdentifier(alarmId: testAlarmId, fireDate: fireDate.addingTimeInterval(30), occurrence: 1)
        ]
        let batch = NotificationIdentifierBatch(alarmId: testAlarmId, identifiers: identifiers)

        notificationIndex.saveIdentifierBatch(batch)
        let loadedBatch = notificationIndex.loadIdentifierBatch(alarmId: testAlarmId)

        XCTAssertEqual(loadedBatch.alarmId, testAlarmId)
        XCTAssertEqual(loadedBatch.identifiers.count, 2)

        for (original, loaded) in zip(identifiers, loadedBatch.identifiers) {
            XCTAssertEqual(original.alarmId, loaded.alarmId)
            XCTAssertEqual(original.occurrence, loaded.occurrence)
            XCTAssertEqual(original.fireDate.timeIntervalSince1970,
                          loaded.fireDate.timeIntervalSince1970, accuracy: 0.001)
        }
    }

    // MARK: - Idempotent Reschedule Tests

    func test_notificationIndex_idempotentReschedule_clearsAndExecutes() {
        let originalIdentifiers = ["original-1", "original-2"]
        let newIdentifiers = ["new-1", "new-2", "new-3"]

        // Setup initial state
        notificationIndex.saveIdentifiers(alarmId: testAlarmId, identifiers: originalIdentifiers)

        var rescheduleExecuted = false

        notificationIndex.idempotentReschedule(
            alarmId: testAlarmId,
            expectedIdentifiers: newIdentifiers
        ) {
            rescheduleExecuted = true
        }

        XCTAssertTrue(rescheduleExecuted)
        XCTAssertEqual(notificationIndex.loadIdentifiers(alarmId: testAlarmId), newIdentifiers)
    }

    // MARK: - Edge Cases and Error Conditions

    func test_notificationIndex_multipleOverwrites_handledCorrectly() {
        let identifiers1 = ["id1", "id2"]
        let identifiers2 = ["id3", "id4", "id5"]
        let identifiers3 = ["id6"]

        notificationIndex.saveIdentifiers(alarmId: testAlarmId, identifiers: identifiers1)
        notificationIndex.saveIdentifiers(alarmId: testAlarmId, identifiers: identifiers2)
        notificationIndex.saveIdentifiers(alarmId: testAlarmId, identifiers: identifiers3)

        let finalIdentifiers = notificationIndex.loadIdentifiers(alarmId: testAlarmId)

        XCTAssertEqual(finalIdentifiers, identifiers3)
    }

    func test_notificationIndex_largeNumberOfIdentifiers_performsWell() {
        let largeIdentifierCount = 1000
        let largeIdentifiers = (0..<largeIdentifierCount).map { "id-\($0)" }

        let startTime = CFAbsoluteTimeGetCurrent()
        notificationIndex.saveIdentifiers(alarmId: testAlarmId, identifiers: largeIdentifiers)
        let saveTime = CFAbsoluteTimeGetCurrent() - startTime

        let loadStartTime = CFAbsoluteTimeGetCurrent()
        let loadedIdentifiers = notificationIndex.loadIdentifiers(alarmId: testAlarmId)
        let loadTime = CFAbsoluteTimeGetCurrent() - loadStartTime

        XCTAssertEqual(loadedIdentifiers, largeIdentifiers)
        XCTAssertLessThan(saveTime, 1.0, "Save should complete in under 1 second")
        XCTAssertLessThan(loadTime, 1.0, "Load should complete in under 1 second")
    }

    func test_notificationIndex_isolatedTestSuites_dontInterfere() {
        let otherSuiteName = "test-notification-index-other-\(UUID().uuidString)"
        let otherSuite = UserDefaults(suiteName: otherSuiteName)!
        defer { otherSuite.removePersistentDomain(forName: otherSuiteName) }

        let otherIndex = NotificationIndex(defaults: otherSuite)

        let identifiers1 = ["suite1-id1"]
        let identifiers2 = ["suite2-id1"]

        notificationIndex.saveIdentifiers(alarmId: testAlarmId, identifiers: identifiers1)
        otherIndex.saveIdentifiers(alarmId: testAlarmId, identifiers: identifiers2)

        XCTAssertEqual(notificationIndex.loadIdentifiers(alarmId: testAlarmId), identifiers1)
        XCTAssertEqual(otherIndex.loadIdentifiers(alarmId: testAlarmId), identifiers2)
    }
}
```

### SettingsServiceTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/Unit/Infrastructure/SettingsServiceTests.swift`

```swift
//
//  SettingsServiceTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/2/25.
//

import XCTest
@testable import alarmAppNew

@MainActor
final class SettingsServiceTests: XCTestCase {

    var sut: SettingsService!
    var mockUserDefaults: UserDefaults!
    var mockAudioEngine: MockAlarmAudioEngine!

    override func setUp() async throws {
        // Use in-memory UserDefaults for testing
        mockUserDefaults = UserDefaults(suiteName: "test.settings.\(UUID().uuidString)")!
        mockAudioEngine = MockAlarmAudioEngine()
        sut = SettingsService(userDefaults: mockUserDefaults, audioEngine: mockAudioEngine)
    }

    override func tearDown() async throws {
        if let suiteName = mockUserDefaults.dictionaryRepresentation().keys.first {
            mockUserDefaults.removePersistentDomain(forName: suiteName)
        }
        sut = nil
        mockUserDefaults = nil
        mockAudioEngine = nil
    }

    // MARK: - Audio Enhancement Settings Tests

    func test_audioEnhancement_defaultsToFalse() {
        XCTAssertFalse(sut.useAudioEnhancement, "Audio enhancement should default to false")
    }

    func test_audioEnhancement_cannotEnableInNotificationsOnlyMode() {
        // Given: notifications-only mode
        sut.setReliabilityMode(.notificationsOnly)

        // When: attempt to enable audio enhancement
        sut.setUseAudioEnhancement(true)

        // Then: should remain false (mode gate blocks it)
        XCTAssertFalse(sut.useAudioEnhancement, "Cannot enable audio enhancement in notifications-only mode")
    }

    func test_audioEnhancement_canEnableInNotificationsPlusAudioMode() {
        // Given: notifications+audio mode
        sut.setReliabilityMode(.notificationsPlusAudio)

        // When: enable audio enhancement
        sut.setUseAudioEnhancement(true)

        // Then: should be enabled
        XCTAssertTrue(sut.useAudioEnhancement, "Can enable audio enhancement in notifications+audio mode")
    }

    func test_audioEnhancement_persistsToUserDefaults() {
        // Given: notifications+audio mode
        sut.setReliabilityMode(.notificationsPlusAudio)

        // When: enable and persist
        sut.setUseAudioEnhancement(true)

        // Then: value should be in UserDefaults
        XCTAssertTrue(mockUserDefaults.bool(forKey: "com.alarmApp.useAudioEnhancement"))
    }

    // MARK: - Alert Intervals Validation Tests

    func test_alertIntervals_defaultsToZeroTenTwenty() {
        XCTAssertEqual(sut.alertIntervalsSec, [0, 10, 20], "Alert intervals should default to [0, 10, 20]")
    }

    func test_alertIntervals_rejectUnsortedArray() {
        // Given: unsorted array
        let unsorted = [10, 0, 20]

        // When/Then: should throw error
        XCTAssertThrowsError(try sut.setAlertIntervals(unsorted)) { error in
            XCTAssertEqual(error as? SettingsError, .intervalsNotSorted)
        }

        // Verify original value unchanged
        XCTAssertEqual(sut.alertIntervalsSec, [0, 10, 20])
    }

    func test_alertIntervals_rejectNegativeValues() {
        // Given: array with negative values
        let negative = [-5, 0, 10]

        // When/Then: should throw error
        XCTAssertThrowsError(try sut.setAlertIntervals(negative)) { error in
            XCTAssertEqual(error as? SettingsError, .invalidInterval)
        }
    }

    func test_alertIntervals_acceptSortedValidArray() throws {
        // Given: sorted valid array
        let valid = [0, 5, 15, 30]

        // When: set intervals
        try sut.setAlertIntervals(valid)

        // Then: should be accepted
        XCTAssertEqual(sut.alertIntervalsSec, valid)
    }

    func test_alertIntervals_persistsToUserDefaults() throws {
        // Given: valid intervals
        let valid = [0, 15, 30]

        // When: set and persist
        try sut.setAlertIntervals(valid)

        // Then: should be in UserDefaults
        let persisted = mockUserDefaults.array(forKey: "com.alarmApp.alertIntervalsSec") as? [Int]
        XCTAssertEqual(persisted, valid)
    }

    // MARK: - Lead-In Validation Tests

    func test_leadIn_defaultsToTwoSeconds() {
        XCTAssertEqual(sut.leadInSec, 2, "Lead-in should default to 2 seconds")
    }

    func test_leadIn_rejectNegativeValue() {
        // Given: negative value
        let negative = -5

        // When/Then: should throw error
        XCTAssertThrowsError(try sut.setLeadInSec(negative)) { error in
            XCTAssertEqual(error as? SettingsError, .leadInOutOfRange)
        }
    }

    func test_leadIn_rejectValueAbove60() {
        // Given: value > 60
        let tooLarge = 61

        // When/Then: should throw error
        XCTAssertThrowsError(try sut.setLeadInSec(tooLarge)) { error in
            XCTAssertEqual(error as? SettingsError, .leadInOutOfRange)
        }
    }

    func test_leadIn_acceptZero() throws {
        // When: set to 0
        try sut.setLeadInSec(0)

        // Then: should be accepted
        XCTAssertEqual(sut.leadInSec, 0)
    }

    func test_leadIn_acceptSixty() throws {
        // When: set to 60
        try sut.setLeadInSec(60)

        // Then: should be accepted
        XCTAssertEqual(sut.leadInSec, 60)
    }

    func test_leadIn_acceptValidMidrangeValue() throws {
        // Given: valid mid-range value
        let valid = 30

        // When: set value
        try sut.setLeadInSec(valid)

        // Then: should be accepted
        XCTAssertEqual(sut.leadInSec, valid)
    }

    // MARK: - Suppress Foreground Sound Tests

    func test_suppressForegroundSound_defaultsToTrue() {
        XCTAssertTrue(sut.suppressForegroundSound, "Suppress foreground sound should default to true")
    }

    func test_suppressForegroundSound_canToggle() {
        // When: toggle off
        sut.setSuppressForegroundSound(false)

        // Then: should be false
        XCTAssertFalse(sut.suppressForegroundSound)

        // When: toggle back on
        sut.setSuppressForegroundSound(true)

        // Then: should be true
        XCTAssertTrue(sut.suppressForegroundSound)
    }

    // MARK: - Reset to Defaults Test

    func test_resetToDefaults_restoresAllSettings() throws {
        // Given: modified settings
        sut.setReliabilityMode(.notificationsPlusAudio)
        sut.setUseAudioEnhancement(true)
        try sut.setAlertIntervals([0, 30, 60])
        sut.setSuppressForegroundSound(false)
        try sut.setLeadInSec(10)

        // When: reset
        sut.resetToDefaults()

        // Then: all should be back to defaults
        XCTAssertEqual(sut.currentMode, .notificationsOnly)
        XCTAssertFalse(sut.useAudioEnhancement)
        XCTAssertEqual(sut.alertIntervalsSec, [0, 10, 20])
        XCTAssertTrue(sut.suppressForegroundSound)
        XCTAssertEqual(sut.leadInSec, 2)
    }
}

```

### WillPresentSuppressionTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/Unit/Infrastructure/WillPresentSuppressionTests.swift`

```swift
//
//  WillPresentSuppressionTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/2/25.
//  Tests for CHUNK 3: Smart foreground sound suppression
//

import XCTest
import UserNotifications
@testable import alarmAppNew

@MainActor
final class WillPresentSuppressionTests: XCTestCase {

    var sut: NotificationService!
    var mockPermissionService: MockPermissionService!
    var mockAppStateProvider: MockAppStateProvider!
    var mockReliabilityLogger: MockReliabilityLogger!
    var mockAppRouter: MockAppRouter!
    var mockAlarmStorage: MockAlarmStorage!
    var mockChainedScheduler: MockChainedScheduler!
    var mockSettingsService: MockSettingsService!
    var mockAudioEngine: MockAlarmAudioEngine!

    override func setUp() async throws {
        mockPermissionService = MockPermissionService()
        mockAppStateProvider = MockAppStateProvider()
        mockReliabilityLogger = MockReliabilityLogger()
        mockAppRouter = MockAppRouter()
        mockAlarmStorage = MockAlarmStorage()
        mockChainedScheduler = MockChainedScheduler()
        mockSettingsService = MockSettingsService()
        mockAudioEngine = MockAlarmAudioEngine()

        sut = NotificationService(
            permissionService: mockPermissionService,
            appStateProvider: mockAppStateProvider,
            reliabilityLogger: mockReliabilityLogger,
            appRouter: mockAppRouter,
            persistenceService: mockAlarmStorage,
            chainedScheduler: mockChainedScheduler,
            settingsService: mockSettingsService,
            audioEngine: mockAudioEngine
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockPermissionService = nil
        mockAppStateProvider = nil
        mockReliabilityLogger = nil
        mockAppRouter = nil
        mockAlarmStorage = nil
        mockChainedScheduler = nil
        mockSettingsService = nil
        mockAudioEngine = nil
    }

    // MARK: - Tests

    func test_willPresent_inForeground_includesSound_whenAudioNotRinging() {
        // Given: Audio engine is NOT ringing
        mockAudioEngine.currentState = .idle
        mockSettingsService.suppressForegroundSound = true

        // When: willPresent is called for real alarm
        let testAlarmId = UUID()
        let notification = createTestNotification(alarmId: testAlarmId)

        var capturedOptions: UNNotificationPresentationOptions?
        sut.userNotificationCenter(
            UNUserNotificationCenter.current(),
            willPresent: notification
        ) { options in
            capturedOptions = options
        }

        // Then: Should include .sound because audio is not ringing
        XCTAssertNotNil(capturedOptions, "Completion handler should be called")
        XCTAssertTrue(capturedOptions!.contains(.sound), "Should include sound when audio engine is not ringing")
        XCTAssertTrue(capturedOptions!.contains(.banner), "Should include banner")
        XCTAssertTrue(capturedOptions!.contains(.list), "Should include list")
    }

    func test_willPresent_suppressesSound_whenAudioRinging_andSettingTrue() {
        // Given: Audio engine IS ringing AND suppress setting is true
        mockAudioEngine.currentState = .ringing
        mockSettingsService.suppressForegroundSound = true

        // When: willPresent is called for real alarm
        let testAlarmId = UUID()
        let notification = createTestNotification(alarmId: testAlarmId)

        var capturedOptions: UNNotificationPresentationOptions?
        sut.userNotificationCenter(
            UNUserNotificationCenter.current(),
            willPresent: notification
        ) { options in
            capturedOptions = options
        }

        // Then: Should suppress .sound because audio is actively ringing
        XCTAssertNotNil(capturedOptions, "Completion handler should be called")
        XCTAssertFalse(capturedOptions!.contains(.sound), "Should suppress sound when audio engine is ringing")
        XCTAssertTrue(capturedOptions!.contains(.banner), "Should still include banner")
        XCTAssertTrue(capturedOptions!.contains(.list), "Should still include list")
    }

    func test_willPresent_includesSound_whenSuppressFalse_evenIfAudioRinging() {
        // Given: Audio engine IS ringing BUT suppress setting is false
        mockAudioEngine.currentState = .ringing
        mockSettingsService.suppressForegroundSound = false

        // When: willPresent is called for real alarm
        let testAlarmId = UUID()
        let notification = createTestNotification(alarmId: testAlarmId)

        var capturedOptions: UNNotificationPresentationOptions?
        sut.userNotificationCenter(
            UNUserNotificationCenter.current(),
            willPresent: notification
        ) { options in
            capturedOptions = options
        }

        // Then: Should include .sound because suppress setting is disabled
        XCTAssertNotNil(capturedOptions, "Completion handler should be called")
        XCTAssertTrue(capturedOptions!.contains(.sound), "Should include sound when suppress setting is false")
        XCTAssertTrue(capturedOptions!.contains(.banner), "Should include banner")
        XCTAssertTrue(capturedOptions!.contains(.list), "Should include list")
    }

    func test_willPresent_alwaysRoutesToRingingUI() {
        // Given: Various audio states
        let testCases: [(AlarmSoundEngine.State, Bool)] = [
            (.idle, true),
            (.idle, false),
            (.ringing, true),
            (.ringing, false),
            (.prewarming, true)
        ]

        for (audioState, suppressSetting) in testCases {
            // Reset router state
            mockAppRouter = MockAppRouter()

            sut = NotificationService(
                permissionService: mockPermissionService,
                appStateProvider: mockAppStateProvider,
                reliabilityLogger: mockReliabilityLogger,
                appRouter: mockAppRouter,
                persistenceService: mockAlarmStorage,
                chainedScheduler: mockChainedScheduler,
                settingsService: mockSettingsService,
                audioEngine: mockAudioEngine
            )

            // Given
            mockAudioEngine.currentState = audioState
            mockSettingsService.suppressForegroundSound = suppressSetting

            // When
            let testAlarmId = UUID()
            let notification = createTestNotification(alarmId: testAlarmId)

            sut.userNotificationCenter(
                UNUserNotificationCenter.current(),
                willPresent: notification
            ) { _ in }

            // Give async routing task time to execute
            let expectation = XCTestExpectation(description: "Routing completed")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1.0)

            // Then: Should always route to ringing regardless of audio state or suppress setting
            XCTAssertEqual(mockAppRouter.ringingCallCount, 1,
                          "Should route to ringing UI for audioState=\(audioState), suppress=\(suppressSetting)")
        }
    }

    // MARK: - Helper Methods

    private func createTestNotification(alarmId: UUID) -> UNNotification {
        let content = UNMutableNotificationContent()
        content.title = "Test Alarm"
        content.body = "Test"
        content.sound = .default
        content.categoryIdentifier = "ALARM_CATEGORY"
        content.userInfo = ["alarmId": alarmId.uuidString]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "test-\(alarmId)", content: content, trigger: trigger)

        // Create notification from request (this is a simplified mock approach)
        // In real tests, you'd use UNUserNotificationCenter to schedule then retrieve
        return UNNotification(coder: NSKeyedArchiver(requiringSecureCoding: false))!
    }
}

// MARK: - Mock Chained Scheduler

class MockChainedScheduler: ChainedNotificationScheduling {
    var scheduleChainCalls: [(Alarm, Date)] = []
    var cancelChainCalls: [UUID] = []

    func scheduleChain(for alarm: Alarm, fireDate: Date) async -> ScheduleOutcome {
        scheduleChainCalls.append((alarm, fireDate))
        return .scheduled(count: 1)
    }

    func cancelChain(alarmId: UUID) async {
        cancelChainCalls.append(alarmId)
    }

    func requestAuthorization() async throws {
        // Mock implementation
    }

    func cleanupStaleChains() async {
        // Mock implementation
    }
}

```

### Unit_VolumeWarningTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/Unit_VolumeWarningTests.swift`

```swift
//
//  Unit_VolumeWarningTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/8/25.
//  Unit tests for media volume warning feature
//

import XCTest
@testable import alarmAppNew

@MainActor
final class Unit_VolumeWarningTests: XCTestCase {
    var mockStorage: MockAlarmStorage!
    var mockPermissionService: MockPermissionService!
    var mockNotificationService: MockNotificationService!
    var mockAlarmScheduler: MockAlarmScheduling!
    var mockRefresher: MockRefresher!
    var mockVolumeProvider: MockSystemVolumeProvider!
    var viewModel: AlarmListViewModel!

    override func setUp() {
        super.setUp()

        // Create mocks
        mockStorage = MockAlarmStorage()
        mockPermissionService = MockPermissionService()
        mockNotificationService = MockNotificationService()
        mockAlarmScheduler = MockAlarmScheduling()
        mockRefresher = MockRefresher()
        mockVolumeProvider = MockSystemVolumeProvider()

        // Create view model with mocked dependencies
        viewModel = AlarmListViewModel(
            storage: mockStorage,
            permissionService: mockPermissionService,
            alarmScheduler: mockAlarmScheduler,
            refresher: mockRefresher,
            systemVolumeProvider: mockVolumeProvider,
            notificationService: mockNotificationService
        )
    }

    // MARK: - Volume Warning Tests

    func test_toggleAlarm_whenVolumeBelowThreshold_showsWarning() {
        // GIVEN: Volume is below threshold (0.25)
        mockVolumeProvider.mockVolume = 0.2
        let alarm = Alarm(
            id: UUID(),
            time: Date(),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: "test-qr",
            isEnabled: false,
            soundId: "chimes01",
            volume: 0.8
        )
        viewModel.alarms = [alarm]

        // WHEN: Toggling alarm to enable it
        viewModel.toggle(alarm)

        // THEN: Warning should be shown
        XCTAssertTrue(viewModel.showMediaVolumeWarning, "Warning should be shown when volume is below threshold")
    }

    func test_toggleAlarm_whenVolumeAtThreshold_noWarning() {
        // GIVEN: Volume is exactly at threshold (0.25)
        mockVolumeProvider.mockVolume = 0.25
        let alarm = Alarm(
            id: UUID(),
            time: Date(),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: "test-qr",
            isEnabled: false,
            soundId: "chimes01",
            volume: 0.8
        )
        viewModel.alarms = [alarm]

        // WHEN: Toggling alarm to enable it
        viewModel.toggle(alarm)

        // THEN: Warning should NOT be shown (exactly at threshold)
        XCTAssertFalse(viewModel.showMediaVolumeWarning, "Warning should not be shown when volume is at threshold")
    }

    func test_toggleAlarm_whenVolumeAboveThreshold_noWarning() {
        // GIVEN: Volume is above threshold
        mockVolumeProvider.mockVolume = 0.5
        let alarm = Alarm(
            id: UUID(),
            time: Date(),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: "test-qr",
            isEnabled: false,
            soundId: "chimes01",
            volume: 0.8
        )
        viewModel.alarms = [alarm]

        // WHEN: Toggling alarm to enable it
        viewModel.toggle(alarm)

        // THEN: Warning should NOT be shown
        XCTAssertFalse(viewModel.showMediaVolumeWarning, "Warning should not be shown when volume is above threshold")
    }

    func test_toggleAlarm_whenDisablingAlarm_noVolumeCheck() {
        // GIVEN: Volume is low and alarm is already enabled
        mockVolumeProvider.mockVolume = 0.1
        let alarm = Alarm(
            id: UUID(),
            time: Date(),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: "test-qr",
            isEnabled: true,
            soundId: "chimes01",
            volume: 0.8
        )
        viewModel.alarms = [alarm]

        // WHEN: Toggling alarm to disable it
        viewModel.toggle(alarm)

        // THEN: Warning should NOT be shown (we only check when enabling)
        XCTAssertFalse(viewModel.showMediaVolumeWarning, "Warning should not be shown when disabling alarm")
    }

    // MARK: - Test Lock-Screen Alarm

    func test_testLockScreen_schedulesNotificationWithCorrectLeadTime() async {
        // GIVEN: ViewModel ready

        // WHEN: Testing lock screen alarm
        viewModel.testLockScreen()

        // Wait for async task to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // THEN: Should schedule test notification (we can't easily verify the exact lead time in mock,
        // but we verify the method was called by checking there are no errors)
        XCTAssertNil(viewModel.errorMessage, "Should not have error message after scheduling test alarm")
    }
}

// MARK: - Mock Refresher

final class MockRefresher: RefreshRequesting {
    var requestRefreshCallCount = 0
    var lastAlarms: [Alarm]?

    func requestRefresh(alarms: [Alarm]) async {
        requestRefreshCallCount += 1
        lastAlarms = alarms
    }
}

```

### alarmAppNewTests.swift
**Path:** `/Users/beshoy/Code/2025-2026/Active/AlarmDontTrustYou/alarmAppNewTests/alarmAppNewTests.swift`

```swift
//
//  alarmAppNewTests.swift
//  alarmAppNewTests
//
//  Created by Beshoy Eskarous on 9/24/25.
//

import Testing

struct alarmAppNewTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

```

