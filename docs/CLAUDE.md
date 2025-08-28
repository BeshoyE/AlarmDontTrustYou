
# Alarm App — Architecture & Engineering Guide
_Last updated: 2025-08-14_

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

```

UI (SwiftUI Views)
↓
Presentation (ViewModels, App Router)
↓
Domain (pure Swift: entities, use cases, policies)
↓
Infrastructure (services: notifications, camera/QR, motion, persistence, logging)

```

**Rules**
- Views never call services directly. Views → ViewModels only.
- ViewModels orchestrate state; side-effects go via **protocol-typed** services.
- Domain is **pure Swift** (no SwiftUI/AVFoundation/CoreMotion).
- Infrastructure implements protocols; constructed centrally (`DependencyContainer`).
- Dependency direction is **down only**.

---

## 2) Project Structure (filesystem)

```

alarm-app/
├─ README.md
├─ docs/
│  ├─ 01-brief.md
│  ├─ orientation.md
│  ├─ mvp-1.md
│  ├─ mvp-2.md
│  ├─ mvp-3.md
│  ├─ architecture.md             ← this file
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
├─ E2E\_Ringing\_QR\_Success.swift
├─ E2E\_Stack\_QR\_Steps\_Math.swift
└─ StateRestorationTests.swift         # MVP 3

````

> **ADR-001 (module strategy):** Keep a monolith through V1/MVP2. If the app grows, split into Swift Packages: `Domain`, `Data` (infra+persistence), `App` (UI+Presentation), `TestSupport`.

---

## 3) Concurrency Policy

- `@MainActor`: all ViewModels & `AppRouter`.
- Services: non-Main unless required; use `async/await`.
- **Clock abstraction** keeps time deterministic in tests:
  ```swift
  protocol Clock { func now() -> Date }
````

* No main-thread I/O or heavy CPU work.

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

## 5) Service Contracts (protocols the app targets)

```swift
protocol NotificationScheduling {
  func requestAuthorization() async throws
  func schedule(alarm: Alarm) async throws
  func cancel(alarmId: UUID) async
  func pendingAlarmIds() async -> [UUID]
  func refreshAll(from alarms: [Alarm]) async
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

protocol PersistenceStore {
  func saveAlarm(_ alarm: Alarm) throws
  func deleteAlarm(id: UUID) throws
  func loadAlarms() throws -> [Alarm]
  func appendRun(_ run: AlarmRun) throws
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

> Concrete implementations live under `Infrastructure/Services/*` and are wired in `DependencyContainer`.

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

## 9) Persistence (SwiftData)

* Store `Alarm`, `AlarmRun`, and V1+ `Challenge` with minimal mapping.
* Migration: MVP 1 → V1 wraps `expectedQR` into `[Challenge]` with `.qr(expected:)`.
* All persistence APIs are `async` and `throws`. No main-thread I/O.

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

**PR Acceptance Checklist**

* [ ] Unit tests for new logic; UI/E2E if user-visible.
* [ ] Dependency direction respected.
* [ ] No main-thread I/O.
* [ ] Logs where failure is possible.
* [ ] Docs updated if contracts/schema changed.



