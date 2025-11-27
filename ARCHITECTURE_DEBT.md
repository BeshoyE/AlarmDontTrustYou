# Architecture Technical Debt

**Generated:** 2025-11-03
**Based on:** CLAUDE.md, claude-guardrails.md
**Codebase Snapshot:** CODEBASE_EXPORT.md (2025-11-03)

---

## Executive Summary

This document catalogs **8 confirmed architectural violations** discovered through comprehensive codebase analysis. While the application demonstrates strong adherence to modern Swift concurrency patterns in several key areas (`AlarmRunStore`, `GlobalLimitGuard`, `AlarmKitScheduler`), there are critical deviations from the architectural mandates that could impact production reliability, maintainability, and performance.

### Violation Count by Severity

| Severity | Count | Description |
|----------|-------|-------------|
| **CRITICAL** | 3 | Main-thread blocking, race conditions, production bugs |
| **HIGH** | 3 | Core architecture violations, hard to fix later |
| **MEDIUM** | 1 | Technical debt, maintenance burden |
| **LOW** | 1 | Consistency and polish |

---

## Severity Classification

### CRITICAL (Blocks Production / Causes Runtime Bugs)

These violations can cause **immediate production issues**: UI freezes, data corruption, or crashes.

1. **DismissedRegistry Main-Thread Blocking** → UI freezes during I/O
2. **PersistenceService Synchronous Methods** → Main-thread blocking
3. **Silent `try?` in Critical Path** → Data loss risk

### HIGH (Violates Core Architecture / Hard to Fix Later)

These violations break clean architecture principles and create technical debt that compounds over time.

4. **View Layer Contamination (2 instances)** → Dependency inversion violation
5. **Init Purity Violation** → App launch performance degradation
6. **Protocol Misplacement** → Code organization / reusability issues

### MEDIUM (Technical Debt / Maintenance Issues)

These reduce code quality but have workarounds.

7. **Redundant Coordinator** → Confusion, potential for bugs

### LOW (Polish / Consistency Issues)

Minor violations that don't affect functionality.

8. **AVFoundation Import in ViewModel** → Unused import (cosmetic)

---

## Detailed Violations

---

### Violation 1: DismissedRegistry Main-Thread Blocking ⚠️ **CRITICAL**

**Severity:** CRITICAL
**File:** `/alarmAppNew/Infrastructure/Persistence/DismissedRegistry.swift`
**Lines:** 12 (`@MainActor`), 24-40 (shared mutable state), 28, 41, 61, 76, 92 (I/O calls), 103-120 (synchronous I/O implementation)

#### Description

`DismissedRegistry` is marked as `@MainActor` and performs **synchronous UserDefaults I/O** on the main thread. Every call to `markDismissed()`, `isDismissed()`, `clearAll()`, and `cleanupExpired()` triggers `persistCache()`, which executes `userDefaults.set()` and `JSONEncoder().encode()` **synchronously**.

#### Rule Violated

> **CLAUDE.md §3 - Concurrency Policy:**
> "**No Main-Thread Blocking:** Do not perform I/O or heavy CPU work on the main thread."

> **claude-guardrails.md:**
> "All new services managing shared mutable state **MUST** be implemented as **Swift `actor`** types."

#### Code Example

```swift
// Lines 12-29
@MainActor  // ❌ WRONG: Main-thread for I/O service
final class DismissedRegistry {
    private var cache: [String: DismissedOccurrence] = [:]  // Shared mutable state

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadCache()  // ❌ Synchronous I/O in init
    }

    // Line 32
    func markDismissed(alarmId: UUID, occurrenceKey: String) {
        cache[key] = occurrence
        persistCache()  // ❌ Main-thread I/O
    }
}

// Lines 113-120
private func persistCache() {
    guard let encoded = try? JSONEncoder().encode(cache) else { return }
    userDefaults.set(encoded, forKey: storageKey)  // ❌ Blocking I/O
}
```

#### Impact

- **UI Freezes:** Every dismissal check and registration causes main-thread stalls
- **Performance Degradation:** UserDefaults encoding/decoding blocks UI updates
- **Race Conditions:** Main-thread-only access prevents safe concurrent usage

#### Recommended Fix

**Step 1:** Remove `@MainActor` and convert to non-Main `actor`:

```swift
actor DismissedRegistry {  // ✅ Actor for thread-safe shared state
    private var cache: [String: DismissedOccurrence] = [:]
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) async {
        self.userDefaults = userDefaults
        await loadCache()  // ✅ Async I/O
    }

    func markDismissed(alarmId: UUID, occurrenceKey: String) async {
        cache[key] = occurrence
        await persistCache()  // ✅ Async I/O
    }

    private func persistCache() async {
        // Perform I/O off main thread
        await Task.detached {
            guard let encoded = try? JSONEncoder().encode(self.cache) else { return }
            self.userDefaults.set(encoded, forKey: self.storageKey)
        }.value
    }
}
```

**Step 2:** Update all call sites to use `await`:
- `DependencyContainer.swift` line 92: `await DismissedRegistry()`
- All method calls: `await dismissedRegistry.markDismissed(...)`

**Estimated Effort:** 2-3 hours (implementation + call-site updates + testing)

**Related Violations:** Similar pattern correctly implemented in `AlarmRunStore.swift` (use as reference)

---

### Violation 2: PersistenceService Synchronous Methods ⚠️ **CRITICAL**

**Severity:** CRITICAL
**File:** `/alarmAppNew/Services/PersistenceService.swift`
**Lines:** 24 (`loadAlarms()`), 76 (`saveAlarms(_:)`), 80 (`defaults.synchronize()`)

#### Description

`PersistenceService` is correctly implemented as an `actor` (line 12), but its methods are **synchronous** (`throws`, not `async throws`). This means the I/O operations (lines 26, 32, 78-80) execute **synchronously** within the actor, blocking any thread that awaits the actor.

#### Rule Violated

> **CLAUDE.md §9 - Persistence:**
> "Error Contract: All persistence APIs are `async` and `throws PersistenceStoreError`. No main-thread I/O."

#### Code Example

```swift
// Lines 12, 24, 76
actor PersistenceService: PersistenceStore {
    func loadAlarms() throws -> [Alarm] {  // ❌ Should be `async throws`
        guard let data = defaults.data(forKey: userDefaultsKey) else {
            return []
        }
        var alarms = try JSONDecoder().decode([Alarm].self, from: data)
        // ... repair logic ...
        return alarms
    }

    func saveAlarms(_ alarms: [Alarm]) throws {  // ❌ Should be `async throws`
        let data = try JSONEncoder().encode(alarms)
        defaults.set(data, forKey: userDefaultsKey)
        defaults.synchronize()  // ❌ BLOCKING synchronous write
    }
}
```

#### Impact

- **Main-Thread Risk:** If called from `@MainActor` context, the synchronous work blocks the main thread
- **Contract Violation:** Architecture spec requires `async throws`, implementation is `throws`
- **No Parallelism:** Synchronous I/O prevents concurrent reads/writes

#### Recommended Fix

**Step 1:** Update method signatures to `async throws`:

```swift
actor PersistenceService: PersistenceStore {
    func loadAlarms() async throws -> [Alarm] {  // ✅ async throws
        // Wrap in Task.detached for truly async I/O
        return try await Task.detached(priority: .userInitiated) { [defaults, key = userDefaultsKey] in
            guard let data = defaults.data(forKey: key) else { return [] }
            return try JSONDecoder().decode([Alarm].self, from: data)
        }.value
    }

    func saveAlarms(_ alarms: [Alarm]) async throws {  // ✅ async throws
        let data = try JSONEncoder().encode(alarms)
        await Task.detached(priority: .userInitiated) { [defaults, key = userDefaultsKey] in
            defaults.set(data, forKey: key)
            defaults.synchronize()
        }.value
    }
}
```

**Step 2:** Update `PersistenceStore` protocol (line 13-16 in `Domain/Protocols/PersistenceStore.swift`):

```swift
public protocol PersistenceStore: Actor {
    func loadAlarms() async throws -> [Alarm]  // ✅ async
    func saveAlarms(_ alarms: [Alarm]) async throws  // ✅ async
}
```

**Step 3:** Update all call sites to use `await`.

**Estimated Effort:** 3-4 hours (protocol update + implementation + extensive call-site updates + testing)

**Related Violations:** `AlarmRunStore.swift` correctly implements `async throws` methods—use as reference pattern.

---

### Violation 3: Silent `try?` in Critical Dismissal Path ⚠️ **CRITICAL**

**Severity:** CRITICAL
**File:** `/alarmAppNew/ViewModels/DismissalFlowViewModel.swift`
**Lines:** 386 (`try? await Task.sleep`), 499 (`try? await alarmStorage.saveAlarms`)

#### Description

The `DismissalFlowViewModel` uses `try?` to silently swallow errors in two critical paths:

1. **Line 386:** `try? await Task.sleep(nanoseconds: 1_000_000_000)` in the QR mismatch feedback flow
2. **Line 499:** `try? await alarmStorage.saveAlarms([updatedAlarm])` when disabling one-time alarms

The second violation is **particularly dangerous**: If saving fails, the one-time alarm won't be disabled, causing it to **fire again** the next day.

#### Rule Violated

> **CLAUDE.md §5.5 - Error Handling Strategy:**
> "NEVER: Use empty `catch {}` blocks or silent `try?` without rethrow/log/fallback."

> **claude-guardrails.md:**
> "Silent catches (`catch {}`) and `try?` without logging or rethrow are strictly forbidden in production code."

#### Code Example

```swift
// Line 496-501 in completeSuccess()
if alarm.repeatDays.isEmpty {
    var updatedAlarm = alarm
    updatedAlarm.isEnabled = false
    try? await alarmStorage.saveAlarms([updatedAlarm])  // ❌ Silent failure
    print("DismissalFlow: One-time alarm dismissed and disabled")
}

// Line 383-391 in didScan(payload:)
Task {
    try? await Task.sleep(nanoseconds: 1_000_000_000)  // ❌ Silent cancellation ignored
    await MainActor.run {
        // ... transition logic ...
    }
}
```

#### Impact

- **Data Loss:** One-time alarm won't be disabled if save fails → alarm fires again
- **Silent Failures:** User has no feedback that something went wrong
- **Debugging Hell:** No logs or errors to diagnose production issues

#### Recommended Fix

**For Line 499 (Critical):**

```swift
if alarm.repeatDays.isEmpty {
    var updatedAlarm = alarm
    updatedAlarm.isEnabled = false
    do {
        try await alarmStorage.saveAlarms([updatedAlarm])
        print("✅ DismissalFlow: One-time alarm disabled successfully")
    } catch {
        print("❌ DismissalFlow: CRITICAL - Failed to disable one-time alarm: \(error)")
        reliabilityLogger.logError(
            "save_alarm_failed",
            details: ["alarmId": alarm.id.uuidString, "error": "\(error)"]
        )
        // Show user-facing error
        phase = .failed("Failed to save alarm. It may fire again.")
    }
}
```

**For Line 386 (Less Critical):**

```swift
Task {
    do {
        try await Task.sleep(nanoseconds: 1_000_000_000)
    } catch is CancellationError {
        print("📋 DismissalFlow: Feedback delay cancelled (expected)")
        return  // Early exit on cancellation
    } catch {
        print("⚠️ DismissalFlow: Unexpected Task.sleep error: \(error)")
    }

    await MainActor.run {
        // ... transition logic ...
    }
}
```

**Estimated Effort:** 1 hour (fix + add error handling + test failure scenarios)

**Priority:** **MUST FIX BEFORE MVP1 LAUNCH** (data integrity issue)

---

### Violation 4a: AlarmsListView Layer Contamination 🔴 **HIGH**

**Severity:** HIGH
**File:** `/alarmAppNew/Views/AlarmsListView.swift`
**Lines:** 9 (`import UserNotifications`), 137-147 (direct `UNUserNotificationCenter` calls)

#### Description

The UI layer (`AlarmsListView`) directly imports and calls Infrastructure-layer framework APIs (`UserNotifications`). This violates the **strict layering** mandated by CLAUDE.md: Views → ViewModels → Domain → Infrastructure.

#### Rule Violated

> **CLAUDE.md §1 - Architectural Style:**
> "Views never call services directly. Views → ViewModels only."

> **claude-guardrails.md - UIKit Isolation:**
> "Never import UserNotifications in: `Views/*` or `ViewModels/*`."

#### Code Example

```swift
// Line 9
import UserNotifications  // ❌ Infrastructure import in UI layer

// Lines 134-147 - Toolbar menu
Button("Request Notification Permission", systemImage: "bell.badge") {
    Task {
        let center = UNUserNotificationCenter.current()  // ❌ Direct framework call
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            print("🔔 requestAuthorization returned: \(granted)")
            // ...
        } catch {
            print("❌ requestAuthorization error: \(error)")
        }
    }
}
```

#### Impact

- **Testability:** Can't mock notification requests in UI tests
- **Architecture Erosion:** Sets bad precedent for new features
- **Maintenance:** Notification logic scattered across UI and service layers

#### Recommended Fix

**Step 1:** Move notification request to `PermissionService`:

```swift
// In PermissionService.swift
func requestNotificationPermissionExplicit() async throws -> Bool {
    let center = UNUserNotificationCenter.current()
    return try await center.requestAuthorization(options: [.alert, .sound, .badge])
}
```

**Step 2:** Update View to call ViewModel method:

```swift
// In AlarmsListView.swift
Button("Request Notification Permission", systemImage: "bell.badge") {
    Task {
        await vm.requestNotificationPermission()  // ✅ Via ViewModel
    }
}
```

**Step 3:** Add ViewModel method:

```swift
// In AlarmListViewModel.swift
@MainActor
func requestNotificationPermission() async {
    do {
        let granted = try await container.permissionService.requestNotificationPermissionExplicit()
        print("🔔 Permission granted: \(granted)")
        refreshPermission()  // Update UI state
    } catch {
        print("❌ Permission request failed: \(error)")
    }
}
```

**Estimated Effort:** 1-2 hours (refactor + update tests)

**Related Violations:** Same pattern in `QRScannerView` (Violation 4b)

---

### Violation 4b: QRScannerView Layer Contamination 🔴 **HIGH**

**Severity:** HIGH
**File:** `/alarmAppNew/Views/QRScannerView.swift`
**Lines:** 10 (`import AVFoundation`), 106-107 (`AVCaptureDevice` calls)

#### Description

The UI layer directly imports `AVFoundation` and calls `AVCaptureDevice.default(for: .video)` to control the camera torch. This logic belongs in the Infrastructure layer (`QRScanningService`).

#### Rule Violated

> **CLAUDE.md §1:**
> "Views never call services directly. Views → ViewModels only."

> **claude-guardrails.md:**
> "No `import AVFoundation` in: `Views/*` or `ViewModels/*`."

#### Code Example

```swift
// Line 10
import AVFoundation  // ❌ Infrastructure framework in View

// Lines 102-120
private func setTorch(_ on: Bool) {
    #if targetEnvironment(simulator)
    return
    #else
    guard let device = AVCaptureDevice.default(for: .video),  // ❌ Direct hardware call
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
```

#### Impact

- **Cannot Test:** Torch logic tied to real hardware, can't mock
- **Architecture Violation:** Hardware access in UI layer
- **Code Duplication:** Any other view needing torch must duplicate this

#### Recommended Fix

**Step 1:** Add torch control to `QRScanningService`:

```swift
// In QRScanningService.swift (Infrastructure layer)
func setTorch(enabled: Bool) async throws {
    #if targetEnvironment(simulator)
    return
    #endif

    guard let device = AVCaptureDevice.default(for: .video),
          device.hasTorch else {
        throw QRScanningError.torchUnavailable
    }

    try device.lockForConfiguration()
    defer { device.unlockForConfiguration() }

    if enabled {
        try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
    } else {
        device.torchMode = .off
    }
}
```

**Step 2:** Update `QRScanning` protocol:

```swift
protocol QRScanning {
    func startScanning() async throws
    func stopScanning()
    func scanResultStream() -> AsyncStream<String>
    func setTorch(enabled: Bool) async throws  // ✅ New method
}
```

**Step 3:** Update View to call service via ViewModel:

```swift
// In QRScannerView.swift
.onChange(of: isTorchOn) { _, newValue in
    Task {
        try? await qrScanningService.setTorch(enabled: newValue)  // ✅ Via service
    }
}
```

**Estimated Effort:** 1-2 hours

---

### Violation 5: Init Purity - DependencyContainer I/O 🔴 **HIGH**

**Severity:** HIGH
**File:** `/alarmAppNew/DI/DependencyContainer.swift` (line 65)
**File:** `/alarmAppNew/Infrastructure/Sounds/SoundCatalog.swift` (lines 14-27, 37-66)

#### Description

`DependencyContainer.init()` calls `SoundCatalog()`, which performs **disk I/O** (`bundle.url(forResource:...)`) during initialization to validate sound files. This violates the "init purity" rule and adds blocking I/O to the app's critical startup path.

#### Rule Violated

> **claude-guardrails.md - Init Purity:**
> "**No side effects in initializers.** Constructors must not do I/O, talk to OS APIs, or assert/`fatalError`."

#### Code Example

```swift
// DependencyContainer.swift, line 65
init() {
    self.soundCatalogConcrete = SoundCatalog()  // ❌ Triggers I/O in init
    // ...
}

// SoundCatalog.swift, lines 14-27
public init(bundle: Bundle = .main, validateFiles: Bool = true) {
    self.sounds = [
        AlarmSound(id: "ringtone1", name: "Ringtone", fileName: "ringtone1.caf", durationSec: 27)
    ]
    self.defaultSoundId = "ringtone1"

    if validateFiles {
        validate(bundle: bundle)  // ❌ I/O in init
    }
}

// Lines 49-54
for sound in sounds {
    let exists = bundle.url(forResource: nameWithoutExtension, withExtension: fileExtension) != nil  // ❌ Disk I/O
    assert(exists, "SoundCatalog: Missing sound file in bundle: \(fileName)")
}
```

#### Impact

- **App Launch Slowdown:** Disk I/O on every app start
- **Testability:** Hard to test without real bundle files
- **Crash Risk:** `assert()` in init can crash app on bad data

#### Recommended Fix

**Step 1:** Add `validateFiles: false` to DependencyContainer init:

```swift
// DependencyContainer.swift, line 65
init() {
    self.soundCatalogConcrete = SoundCatalog(validateFiles: false)  // ✅ No I/O in init
    // ...
}
```

**Step 2:** Add explicit `activate()` method to perform validation:

```swift
// DependencyContainer.swift
func activateSoundCatalog() {
    soundCatalogConcrete.validate()  // ✅ Explicit activation
}

// SoundCatalog.swift
func validate() {
    validate(bundle: .main)
}
```

**Step 3:** Call `activateSoundCatalog()` in `alarmAppNewApp.swift` after container creation:

```swift
// alarmAppNewApp.swift
init() {
    // ... existing setup ...
    dependencyContainer.activateSoundCatalog()
}
```

**Estimated Effort:** 1 hour (minimal changes, already has `validateFiles` flag)

**Related Patterns:** This is similar to the existing `activateAlarmScheduler()` pattern (line 55 in `alarmAppNewApp.swift`)

---

### Violation 6: Protocol Misplacement in ViewModel 🔴 **HIGH**

**Severity:** HIGH
**File:** `/alarmAppNew/ViewModels/DismissalFlowViewModel.swift`
**Lines:** 745-753 (`QRScanning` and `Clock` protocols)

#### Description

Two service protocols (`QRScanning` and `Clock`) are defined **inside the ViewModel file** instead of in the `Domain/` layer. This violates the separation of concerns and makes the protocols hard to discover and reuse.

#### Rule Violated

> **CLAUDE.md §5 - Service Contracts:**
> "Service Contracts (protocols the app targets)" belong in the Domain layer, not Presentation.

> **CLAUDE.md §2 - Project Structure:**
> "`Domain/Protocols/` - Service contracts (QRScanning, Clock, etc.)"

#### Code Example

```swift
// Lines 745-753 in DismissalFlowViewModel.swift (Presentation layer)
protocol QRScanning {  // ❌ Should be in Domain/Protocols/QRScanning.swift
    func startScanning() async throws
    func stopScanning()
    func scanResultStream() -> AsyncStream<String>
}

public protocol Clock {  // ❌ Should be in Domain/Time/Clock.swift
    func now() -> Date
}
```

#### Impact

- **Discoverability:** Hard to find these protocols (they're hidden in a ViewModel)
- **Reusability:** Other ViewModels can't easily import them
- **Architecture Confusion:** Protocols in wrong layer

#### Recommended Fix

**Step 1:** Create `/alarmAppNew/Domain/Protocols/QRScanning.swift`:

```swift
import Foundation

public protocol QRScanning {
    func startScanning() async throws
    func stopScanning()
    func scanResultStream() -> AsyncStream<String>
}
```

**Step 2:** Create `/alarmAppNew/Domain/Time/Clock.swift`:

```swift
import Foundation

public protocol Clock {
    func now() -> Date
}

public struct SystemClock: Clock {
    public init() {}
    public func now() -> Date { Date() }
}

public struct FakeClock: Clock {
    public let fixedNow: Date
    public init(fixedNow: Date) { self.fixedNow = fixedNow }
    public func now() -> Date { fixedNow }
}
```

**Step 3:** Remove protocol definitions from `DismissalFlowViewModel.swift` (lines 745-761).

**Step 4:** Update imports in `DismissalFlowViewModel.swift` (if needed).

**Estimated Effort:** 30 minutes (simple file moves)

**Priority:** Should be fixed before V1 (when challenge sequencing needs these protocols)

---

### Violation 7: Redundant AppCoordinator 🟡 **MEDIUM**

**Severity:** MEDIUM
**File:** `/alarmAppNew/Coordinators/AppCoordinator.swift`
**Lines:** 11 (class definition, missing `@MainActor`)

#### Description

Both `AppCoordinator.swift` and `AppRouter.swift` exist in the `Coordinators/` directory. CLAUDE.md specifies `AppRouter` as the single source of truth for routing (§6). `AppCoordinator` is a redundant class with `@Published` state but is **not marked `@MainActor`**, which is a secondary violation.

#### Rule Violated

> **CLAUDE.md §6 - Presentation Layer:**
> "`AppRouter` switches screens."

> **CLAUDE.md §2 - Project Structure:**
> "`App/AppRouter.swift`" (single router, not multiple coordinators)

> **CLAUDE.md §3 - Concurrency Policy:**
> "`@MainActor`: All **ViewModels** and the **`AppRouter`** must be marked with `@MainActor`."

#### Code Example

```swift
// AppCoordinator.swift, lines 11-20
class AppCoordinator: ObservableObject {  // ❌ Not @MainActor
    @Published var alarmToDismiss: UUID? = nil  // @Published state without @MainActor

    func showDismissal(for alarmID: UUID) {
        alarmToDismiss = alarmID
    }

    func dismissalCompleted() {
        alarmToDismiss = nil
    }
}
```

#### Impact

- **Confusion:** Two routing classes with unclear ownership
- **Concurrency Bug:** `@Published` without `@MainActor` can cause data races
- **Maintenance Burden:** Changes may need to be applied to both coordinators

#### Recommended Fix

**Option 1 (Preferred):** Delete `AppCoordinator.swift` entirely and migrate functionality to `AppRouter`.

**Step 1:** Check if `AppCoordinator` is used anywhere:

```bash
grep -r "AppCoordinator" alarmAppNew/
```

**Step 2:** If no references found, delete the file:

```bash
rm alarmAppNew/Coordinators/AppCoordinator.swift
```

**Step 3:** If references exist, migrate logic to `AppRouter` and update call sites.

**Option 2 (If keeping):** Add `@MainActor` annotation:

```swift
@MainActor
class AppCoordinator: ObservableObject {
    @Published var alarmToDismiss: UUID? = nil
    // ...
}
```

**Estimated Effort:** 30 minutes (deletion) or 1 hour (migration)

---

### Violation 8: AVFoundation Import in ViewModel 🟢 **LOW**

**Severity:** LOW
**File:** `/alarmAppNew/ViewModels/DismissalFlowViewModel.swift`
**Line:** 12 (`import AVFoundation`)

#### Description

`DismissalFlowViewModel` imports `AVFoundation` but doesn't appear to use any of its APIs directly. This is a cosmetic violation—the import should be removed.

#### Rule Violated

> **CLAUDE.md §1:**
> "Domain is **pure Swift** (no SwiftUI/AVFoundation/CoreMotion)."
> (This extends to Presentation layer, which should only use protocols)

#### Code Example

```swift
// Line 12
import AVFoundation  // ❌ Unused import
```

#### Impact

- **Cosmetic:** No functional impact
- **Code Smell:** Suggests past refactoring left unused imports

#### Recommended Fix

**Step 1:** Remove the import:

```swift
// DismissalFlowViewModel.swift, line 12
// DELETE: import AVFoundation
```

**Step 2:** Build to confirm no compilation errors.

**Estimated Effort:** 5 minutes

---

## Compliance Highlights ✅

Despite the violations above, the codebase demonstrates **excellent adherence** to architectural principles in several key areas. These should be preserved and used as reference patterns:

### ✅ Excellent Patterns to Preserve

1. **AlarmRunStore.swift (lines 24-158)**
   - **Perfect actor implementation:** Non-Main actor, `async throws` methods, atomic load-modify-save
   - **Typed errors:** Uses `AlarmRunStoreError` enum
   - **No main-thread blocking:** All I/O is async
   - **Reference for:** How `DismissedRegistry` and `PersistenceService` should be written

2. **GlobalLimitGuard.swift (lines 36-115)**
   - **Correct actor isolation:** Protects shared `reservedSlots` state
   - **No DispatchSemaphore:** Comments explicitly state compliance with CLAUDE.md §3
   - **Thread-safe:** Safe for concurrent `reserveSlot()`/`releaseSlot()` calls
   - **Reference for:** Actor-based concurrency patterns

3. **AlarmKitScheduler.swift (lines 15-361)**
   - **Clean protocol implementation:** Implements `AlarmScheduling` protocol
   - **Proper error mapping:** Maps internal errors to domain `AlarmSchedulingError`
   - **Async/await throughout:** All methods correctly use `async throws`
   - **Reference for:** Service layer architecture

4. **UIApplicationIdleTimerController.swift**
   - **Perfect UIKit isolation:** UIKit code in Infrastructure, exposed via protocol
   - **Correct `@MainActor`:** UI APIs marked correctly
   - **Reference for:** How to isolate UIKit/AVFoundation in Infrastructure layer

5. **AlarmScheduling Protocol (Domain/Protocols/AlarmScheduling.swift)**
   - **Correct naming:** `AlarmScheduling` (not `NotificationScheduling`)
   - **Clean contract:** All 7 required methods present
   - **Reference for:** Protocol design in Domain layer

6. **All ViewModels**
   - **Correct `@MainActor`:** `AlarmListViewModel`, `DismissalFlowViewModel`, `SettingsViewModel` all marked
   - **Reference for:** Presentation layer concurrency

---

## Recommended Remediation Order

### Pre-MVP1 Launch (MUST FIX) 🚨

**These violations can cause production bugs, data loss, or poor UX.**

| # | Violation | Estimated Effort | Priority Justification |
|---|-----------|-----------------|------------------------|
| 3 | Silent `try?` in dismissal path | 1 hour | Data loss risk: one-time alarms won't be disabled |
| 1 | DismissedRegistry main-thread blocking | 2-3 hours | UI freezes during dismissal checks |
| 2 | PersistenceService sync methods | 3-4 hours | Contract violation + main-thread risk |

**Total Pre-Launch Effort:** 6-8 hours

### Post-MVP1, Pre-V1 (SHOULD FIX) 🟡

**These violate core architecture and create technical debt that compounds.**

| # | Violation | Estimated Effort | Rationale |
|---|-----------|-----------------|-----------|
| 4a | AlarmsListView layer contamination | 1-2 hours | Sets bad precedent for V1 features |
| 4b | QRScannerView layer contamination | 1-2 hours | Same pattern as 4a, fix together |
| 6 | Protocol misplacement | 30 min | Blocks clean challenge sequencer in V1 |
| 5 | Init purity violation | 1 hour | App launch performance + testability |

**Total Pre-V1 Effort:** 3.5-5.5 hours

### V2 Cleanup (CAN DEFER) 🟢

**These are polish items with low impact.**

| # | Violation | Estimated Effort | Rationale |
|---|-----------|-----------------|-----------|
| 7 | Redundant AppCoordinator | 30 min - 1 hour | Low risk, but adds confusion |
| 8 | Unused AVFoundation import | 5 min | Cosmetic only |

**Total V2 Cleanup Effort:** 35 min - 1 hour

---

## Implementation Strategy

### Week 1: Critical Path (Pre-Launch)

**Monday-Tuesday: Violation 3 (Silent `try?`)**
- Fix line 499 first (critical data loss path)
- Add error handling and user-facing error messages
- Test one-time alarm disable flow
- Test TaskCancellation handling

**Wednesday-Thursday: Violation 1 (DismissedRegistry)**
- Convert to non-Main actor
- Update all call sites to `await`
- Add concurrency tests

**Friday: Violation 2 (PersistenceService)**
- Update protocol to `async throws`
- Update implementation
- Update call sites
- Run full test suite

### Week 2: Architecture Cleanup (Pre-V1)

**Monday:** Violations 4a & 4b (Layer contamination)
- Extract torch control to QRScanningService
- Move notification requests to PermissionService
- Update ViewModels to mediate

**Tuesday:** Violation 6 (Protocol location)
- Create Domain/Protocols/QRScanning.swift
- Create Domain/Time/Clock.swift
- Remove from ViewModel

**Wednesday:** Violation 5 (Init purity)
- Add `validateFiles: false` flag
- Create `activateSoundCatalog()` method
- Update app launch sequence

### Week 3: Polish (V2)

**Anytime:** Violations 7 & 8
- Delete AppCoordinator (or add `@MainActor`)
- Remove unused AVFoundation import

---

## Testing Requirements

For each fix, add the following tests:

### Violation 1 (DismissedRegistry)
- **Test:** Concurrent `markDismissed()` calls don't lose data
- **Test:** Actor doesn't block main thread (performance test)

### Violation 2 (PersistenceService)
- **Test:** Concurrent `loadAlarms()` + `saveAlarms()` don't corrupt data
- **Test:** Async methods don't block main thread

### Violation 3 (Silent `try?`)
- **Test:** Save failure prevents one-time alarm disable
- **Test:** User sees error message when save fails
- **Test:** Task cancellation doesn't crash

### Violations 4a & 4b (Layer contamination)
- **Test:** Mock PermissionService for notification requests
- **Test:** Mock QRScanningService for torch control

---

## References

- **CLAUDE.md** - Architecture Specification (§1-16)
- **claude-guardrails.md** - Development Rules & DoD Checklist
- **CODEBASE_EXPORT.md** - Complete code snapshot (2025-11-03)
- **AlarmRunStore.swift** - Reference actor implementation
- **GlobalLimitGuard.swift** - Reference shared state actor
- **UIApplicationIdleTimerController.swift** - Reference UIKit isolation

---

## Appendix: Violation Detection Methodology

This analysis was performed by:
1. Reading CLAUDE.md and claude-guardrails.md to extract architectural rules
2. Exporting the complete codebase to CODEBASE_EXPORT.md
3. Systematically verifying each reported violation with file reads and line number confirmation
4. Cross-referencing with compliant implementations (AlarmRunStore, GlobalLimitGuard)
5. Assessing severity based on production impact and technical debt burden

**Files Verified:**
- DismissedRegistry.swift
- PersistenceService.swift
- AlarmsListView.swift
- QRScannerView.swift
- DismissalFlowViewModel.swift
- DependencyContainer.swift
- SoundCatalog.swift
- AppCoordinator.swift

**Confirmation:** All 8 violations confirmed with exact line numbers and code examples.

---

**End of Document**
