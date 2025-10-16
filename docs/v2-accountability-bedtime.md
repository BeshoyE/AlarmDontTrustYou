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