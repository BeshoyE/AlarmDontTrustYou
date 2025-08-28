# V2 — Accountability & Bedtime Flow

## 1. Goal
Add external accountability and bedtime behavior without monetization risk.

## 2. Scope (Include)
- Buddy contact with consent + quiet hours; **push/SMS** (Twilio/APNs).
- Photo **proof** of predefined object on success; **post-alarm check-in** (made-bed photo).
- Simple backend + auth; `/events/*` endpoints; signed URL uploads.
- Bedtime flow: schedule, “I’m in bed” notification action, buddy ping, analytics.
- Expanded tests: network mocks (Twilio/Uploads), e2e for success/fail + bedtime confirm.

## 3. Out of Scope (This Version)
- Payments/penalties; Roulette sends.
- Sleep-stage smart wake (HealthKit).

## 4. Definition of Done
- Buddy notified on success/fail in <10s; quiet hours respected.
- Photo proof upload ≥99% success on poor networks (queued retry).
- Bedtime confirm round-trip recorded and visible in history.

## 5. Flags (Turn On Selectively)
| Flag      | Default | Notes                                     |
|-----------|---------|-------------------------------------------|
| buddy     | on      | Enable SMS/push w/ quiet hours + consent  |
| proof     | on      | Photo proof + post-alarm check-in         |
| bedtime   | on      | Bedtime schedule + confirm flow           |
| payments  | off     | V3                                        |
| roulette  | off     | V3                                        |
| smartWake | off     | V3                                        |

## 6. Backend/Plumbing Checklist
- Auth + DB (Firestore or Supabase) wired.
- Endpoints: `POST /events/alarm`, `POST /events/proof`, `POST /events/bedtime`.
- Storage: signed URLs, short TTL; delete on request.
- Twilio/APNs provider abstraction + retry/backoff; delivery status persisted.
- Analytics: bedtime scheduled/delivered/confirmed; buddy alerts.

## 7. Test Plan
- Unit: buddy quiet-hours filter; consent gate; upload signer.
- Integration: Twilio mock; storage upload; APNs token registration.
- E2E: (a) success + proof + buddy notify; (b) failure + buddy notify; (c) bedtime confirm.

## 8. AI Prompt Templates
- Backend/API:
  > Implement the endpoints in **§2.10 API** and persist **§2.3 entities** (Proof, BuddyContact, Notification, BedtimeEvent). Provide Twilio/APNs mocks and retry logic with idempotency keys.
- Bedtime UX:
  > Build a notification action “I’m in bed” and handle it via `UNUserNotificationCenterDelegate` as in **§2.6.2 Bedtime**.

## 9. References
- MVP Spec §2.1 (M1, M3 parts), §2.2 (Screens 4–8, 11), §2.3, §2.6.2, §2.8.
