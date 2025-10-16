# V1 — Core Wake Reliability

## 1. Goal

Prove the app wakes users reliably, can’t be trivially cheated, and delivers a strong **continuous audio experience** when the app is active.

## 2. Scope (Include)

* Alarms: create/edit/delete, repeat, label, sound, volume, vibrate.
* Challenges: QR, Steps, Math with **enforced order**.
* Dismissal flow UI (sequential steps, failure timeout).
* **Alarm Scheduling (AlarmKit / Notifications):** Use the unified `AlarmScheduling` protocol; re-register on launch/background.
* **Audio session enhancement:** when app is alive, start continuous playback; suppress foreground notification sound to avoid double audio.
* **Local persistence:** Use the **`PersistenceStore` actor** for all alarm and run data; persistence operations must be thread-safe and atomic.
* Basic Settings (minimal).
* Minimal analytics (local log + optional console export).
* Tests: unit (scheduler + validators + suppression logic), one happy-path e2e.

## 3. Out of Scope (This Version)

* Buddy notifications (SMS/push), photo proof, post-alarm check-in.
* Payments/penalties, Roulette Mode.
* Bedtime flow, sleep-stage smart wake.
* Backend services (APIs, DB, auth).

## 4. Definition of Done

* ≥95% of fired alarms complete all selected challenges in testing.
* Works if app closed/killed; notification still fires; dismissal flow reachable.
* QR works in low light; steps validate in airplane mode.
* Continuous audio plays in foreground; no double audio when both audio + notification present.
* No crashes across 3 consecutive days of scheduled test alarms.

## 5. Flags (All Off in V1 Build)

| Flag      | Default | Notes       |
| --------- | ------- | ----------- |
| buddy     | off     | Defer to V2 |
| proof     | off     | Defer to V2 |
| payments  | off     | Defer to V3 |
| roulette  | off     | Defer to V3 |
| bedtime   | off     | Defer to V2 |
| smartWake | off     | Defer to V3 |

## 6. Test Plan

* Unit: alarm scheduler; math/steps/QR validators; suppression logic (audio active → no notif sound).
* E2E: dismissal flow happy-path with 1 challenge stack.
* Smoke script: nightly run across 3 devices; record outcomes (foreground + killed).

## 7. AI Prompt Templates (UPDATED)

* Scaffold core app:

  > Use **§4 Domain Model (Alarm/Challenge/AlarmRun)** and **§5 Service Contracts (AlarmScheduling, PersistenceStore)** to build SwiftUI views. **Ensure PersistenceStore is implemented as an actor** and all reads/writes are thread-safe. Generate unit tests for math/steps/qr validators and audio suppression.
* Reliability checks:

  > Write tests to confirm `AlarmScheduling` re-registration on app relaunch/background per iOS 17+ constraints, and that audio + notif do not double-play.

## 8. References

* MVP Spec §2.1 (M0), §2.2 (Screens 1–3), §2.3, §2.6.1, §2.5 (Alarm reliability).
* MVP 1 doc for audio-enhancement pattern.