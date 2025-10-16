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



