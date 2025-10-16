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