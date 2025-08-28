# V1 — Core Wake Reliability (Target: 2025-08-31)

## 1. Goal
Prove the app wakes users reliably and can’t be trivially cheated.

## 2. Scope (Include)
- Alarms: create/edit/delete, repeat, label, sound, volume, vibrate.
- Challenges: QR, Steps, Math with **enforced order**.
- Dismissal flow UI (sequential steps, failure timeout).
- Local notifications; re-register on launch/background.
- Local persistence only (no auth/backend).
- Basic Settings (minimal).
- Minimal analytics (local log + optional console export).
- Tests: unit (scheduling + validators), one happy-path e2e.

## 3. Out of Scope (This Version)
- Buddy notifications (SMS/push), photo proof, post-alarm check-in.
- Payments/penalties, Roulette Mode.
- Bedtime flow, sleep-stage smart wake.
- Backend services (APIs, DB, auth).

## 4. Definition of Done
- ≥95% of fired alarms complete all selected challenges in testing.
- Works if app closed/killed; alarm + flow still run.
- Dark-room QR scan succeeds; step target validated in airplane mode.
- No crashes across 3 consecutive days of scheduled test alarms.

## 5. Flags (All Off in V1 Build)
| Flag         | Default | Notes                          |
|--------------|---------|--------------------------------|
| buddy        | off     | Defer to V2                    |
| proof        | off     | Defer to V2                    |
| payments     | off     | Defer to V3                    |
| roulette     | off     | Defer to V3                    |
| bedtime      | off     | Defer to V2                    |
| smartWake    | off     | Defer to V3                    |

## 6. Test Plan
- Unit: alarm scheduler; math/steps/QR validators.
- E2E: dismissal flow happy-path with 1 challenge stack.
- Smoke script: nightly run across 3 devices; record outcomes.

## 7. AI Prompt Templates
- Scaffold core app:
  > Use **§2.3 Data Model (User/Alarm/Challenge/AlarmRun)** and **§2.6.1 Alarm Dismissal** from the MVP spec to build SwiftUI views and local scheduler. No backend. Generate unit tests for math/steps/qr validators.
- Reliability checks:
  > Write tests to confirm notification re-registration on app relaunch/background per iOS 17+ constraints.

## 8. References
- MVP Spec §2.1 (M0), §2.2 (Screens 1–3), §2.3, §2.6.1, §2.5 (Alarm reliability).
