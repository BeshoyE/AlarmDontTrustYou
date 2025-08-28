# V3 — Monetization & Advanced Behavior

## 1. Goal
Enable penalties, (optional) buddy payouts, Roulette Mode, and smart wake.

## 2. Scope (Include)
- **Payments**: Stripe Customer + PaymentMethod; failure → debit; webhooks for final status.
- **Payouts (optional)**: Stripe Connect Standard to buddy (feature-flagged).
- **Roulette Mode**: randomly select pre-approved contact; templates; max/week; quiet hours; dry-run.
- **Sleep Tracking**: HealthKit permission; 15–30 min smart wake window; choose lightest stage within window.
- Analytics & flags for A/B across penalties and roulette.

## 3. Out of Scope (This Version)
- New social graphs; public timelines; community features.

## 4. Definition of Done
- All payment paths covered by webhook tests; no duplicate charges.
- Roulette respects quiet hours + max/week; dry-run logs full trace.
- Smart wake window adjusts fire time inside window ≥80% of nights with shared data.

## 5. Flags (Turn On Gradually)
| Flag      | Default | Notes                                        |
|-----------|---------|----------------------------------------------|
| payments  | on      | Stripe debit; kill-switch.                   |
| payouts   | off     | If implemented via Stripe Connect.           |
| roulette  | on      | With rate-limits + dry-run first.            |
| smartWake | on      | HealthKit required; watch-first if needed.   |
| buddy     | on      | From V2                                      |
| proof     | on      | From V2                                      |
| bedtime   | on      | From V2                                      |

## 6. Compliance/Safety
- **App Store**: review policy for monetary penalties (IAP vs Stripe). Keep kill-switch and remote flags.
- **SMS**: rate-limit, consent, quiet hours; opt-out keyword for buddies/roulette contacts.
- **Health**: HealthKit privacy; explain use; allow revoke; minimize retention.

## 7. Backend/Plumbing Checklist
- Stripe: customer setup, payment method attach, idempotent debits; webhooks `/webhooks/stripe`.
- Optional Connect: buddy onboarding; payouts; 1099 handling (Stripe standard).
- Roulette: seeded RNG; eligibility filter; template merge; Twilio send + status callbacks.
- Data: `PenaltyRule`, `Payment`, `RouletteConfig`, `RoulettePick`, `SleepSession`.
- Analytics: debit_{created|succeeded|failed}, roulette_{sent|blocked}, smartWake_fired.

## 8. Test Plan
- Unit: roulette selector (seeded), rate-limit/max/week, quiet-hours filter.
- Integration: Stripe sandbox debits + webhook retries/idempotency; Twilio status callbacks.
- E2E: failure → debit → (optional) payout; failure → roulette send; smart-wake within window.

## 9. AI Prompt Templates
- Payments:
  > Implement Stripe debit per **§2.6.3 Payments** and entities in **§2.3**. Add webhook handler with idempotency and retries; write integration tests.
- Roulette:
  > Build Roulette flow per **§2.6.4** using `RouletteConfig`/`RoulettePick`. Enforce quiet hours + max/week; provide dry-run that logs but doesn’t send SMS.
- Smart Wake:
  > Read HealthKit sleep; compute next fire time within a user-set window; prefer light stage; fall back to scheduled time if no data.

## 10. References
- MVP Spec §2.1 (M2, M5, M4), §2.2 (Screens 7, 9, 10), §2.3, §2.6.3–2.6.4, §2.7, §2.8–2.10.
