
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
