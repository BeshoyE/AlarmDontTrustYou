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