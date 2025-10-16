# MVP 1 — QR-Only Wake Reliability (with Audio Enhancement)

*Target: 2025-08-19*

## 1) Mission

Ship a minimal, reliable alarm that **cannot be dismissed** until the user scans a pre-registered QR code. No backend, no subscriptions.
Guarantee alarms always fire via **AlarmScheduling (local notifications)** while enhancing the user experience with a continuous **audio session** when the app is active.

## 2) Problem → Solution

* **Problem:** People silence or snooze alarms too easily.
* **Solution:** Require scanning a specific QR payload to dismiss.
* **Reliability:** Always schedule via the **`AlarmScheduling`** protocol as the OS-guaranteed sound source.
* **Experience:** When app is alive, start an audio session to provide continuous ringing. Suppress notification sound in foreground to avoid double audio.

## 3) In Scope

* Alarm CRUD: time, repeat, label, sound, volume, vibrate, enable/disable.
* **QR challenge only** (AVFoundation); exact payload match.
* Dismissal flow: **Ringing (fullscreen) → QR Scanner → Success → Dismiss**.
* **Alarm Scheduling:** Use the unified `AlarmScheduling` protocol; **re-register** pending alarms on app launch and when app becomes active.
* **Audio session enhancement:** continuous playback when app is active; foreground notifications omit `.sound` if audio is ringing.
* **Local persistence:** Use the thread-safe **`PersistenceStore` actor** (replaces legacy SwiftData) for alarms, runs, and the QR payload.
* Basic Settings: default sound, haptics, 12/24h.
* Local reliability log (append events to file or DB).
* Tests: unit (scheduler + QR validator + persistence round-trip + suppression rule), 1 E2E.
* Accessibility & performance basics.

## 4) Out of Scope (MVP 1)

* Steps, Math, multi-challenge stacks.
* Buddy/accountability, photo proof.
* Payments/penalties.
* Bedtime flow, smart wake.
* Any backend/auth.

## 5) UX Spec (flows)

### 5.1 Create/Edit Alarm

* Fields: time, repeat days, label, sound, volume, vibrate, **QR Setup**.
* **QR Setup:** “Save this code’s value” → open scanner → on success, store payload in `Alarm.expectedQR`.

### 5.2 Ringing & Dismissal

* Fullscreen RingingView (screen awake, system volume respected).
* Primary CTA: **“Scan Code to Dismiss.”**
* Scanner screen with torch toggle; if scanned payload == expected → success → stop alarm → mark run success (via `PersistenceStore` actor).
* **Audio UX:** If app is active, audio session starts ringing continuously. Notifications show banners only (no sound) to prevent overlap. If app is killed, notification sound ensures alarm still fires.

### 5.3 Permission UX

* **Notifications**: hard-block scheduling if disabled; inline warning + deep link to Settings.
* **Camera**: block dismissal until granted; explain why and offer Settings deep link.

## 6) Minimal Data Model (Swift / Domain)

* `Alarm { id, time, repeatDays[], label, sound, volume, vibrate, isEnabled, expectedQR:String? }`
* `AlarmRun { id, alarmId, firedAt, dismissedAt?, outcome: success|fail }`

> For full contracts, see `CLAUDE.md` §4–5.

## 7) Services (protocols to implement)

* `AlarmScheduling`: request auth, schedule/cancel, reconcile, pending IDs.
* `QRScanning`: start/stop, `AsyncStream<String>` of payloads.
* `PersistenceStore` (**Actor**): save/load alarms; append runs.
* `Clock`: `now()` for deterministic time math in tests.
* `AudioEngine`: start/stop ringing; `isActivelyRinging` flag for suppression logic.

(Concrete implementations live under `Infrastructure/Services/*` and are wired in `DependencyContainer`.)

## 8) App Lifecycle Rules

* On app launch **and** when `scenePhase == .active`: `AlarmScheduling.reconcile(from: alarms)`.
* Always include a notification action/deeplink back to Ringing/Scanner (“Return to Dismissal”).
* If audio is ringing, suppress notification `.sound` in `willPresent`.

## 9) Anti-Cheat Hygiene (MVP-appropriate)

* Preflight check before scheduling: notifications authorized; block + explain if not.
* Ringing cannot be dismissed without QR success (no alternative buttons).
* Log permission changes to local reliability log.

## 10) Definition of Done

* ≥95% of fired alarms require a **valid QR scan** to dismiss in internal testing.
* Works if app is killed/closed: alarm still fires; tapping notification returns to Ringing/Scanner.
* Audio session starts when app alive; no double audio in foreground.
* Dark-room QR scan succeeds (torch toggle available).
* No crashes across **3 consecutive days** of scheduled alarms.

## 11) Test Plan

**Unit**

* `ScheduleNextFire` (one-time vs repeat; DST/timezone edges).
* QR validator: exact match vs wrong/case mismatch; empty expected.
* Persistence round-trip: create → save → load → equality. **Concurrency Test: Simultaneous save of AlarmRuns on the PersistenceStore actor.**
* Preflight: notifications disabled → scheduling blocked.
* Audio suppression: if `isActivelyRinging == true`, notifications omit `.sound`.

**Integration**

* Alarm Scheduling round-trip with a mock center.
* Storage migration ready for V1 (wrap `expectedQR` into a single-item challenge later).
* Audio + notification interaction (no double sound).

**UI/E2E**

* Set alarm (1 min ahead) → rings → scan valid QR → dismiss → run outcome recorded.
* Verify continuous audio in foreground, sound-only notification if app killed.

**Manual Smoke**

* Dark room; Do Not Disturb; volume low; airplane mode; device lock/unlock during ringing.

## 12) Local Reliability Log (MVP scope)

* Events: `scheduled`, `fired`, `dismiss_success_qr`, `dismiss_fail_qr`, `notifications_status_changed`, `audio_started`, `audio_stopped`.
* Store locally (JSON/CSV). Export via share sheet (optional).

## 13) Accessibility & Perf

* Min tap target 44pt; Dynamic Type friendly.
* VoiceOver labels on critical buttons (“Scan Code to Dismiss”, “Toggle Torch”).
* No blocking disk I/O on main thread; camera session starts fast (<300ms target).
* Audio session start within ≤1s of fire time.

## 14) Build Order (no-code checklist)

1. **Models & Storage**

   * Create `Alarm`, `AlarmRun` (Domain).
   * `PersistenceStore` protocol implementation as a **Swift actor**.
2. **Scheduling**

   * `AlarmScheduling` with request auth + schedule + reconcile.
   * Re-register on launch/active.
3. **UI Scaffolding**

   * `AlarmList`, `AlarmForm`, `Ringing` skeletons.
4. **QR Setup & Dismissal**

   * `QRScanning` service; save expected payload in `Alarm`.
   * Ringing → Scanner → validate → stop.
5. **Audio Enhancement**

   * Implement `AudioEngine` service; suppress notification sound when active.
6. **Reliability Log**

   * Append events; simple export (optional).
7. **Tests**

   * Unit (scheduler, QR, persistence, suppression, **concurrency**) + one E2E.

## 15) Apple APIs & Search Hints

* **Notifications:** `UNUserNotificationCenter requestAuthorization(options: [.alert, .sound])`, `UNTimeIntervalNotificationTrigger` / `UNCalendarNotificationTrigger`, `getNotificationSettings`.
* **QR:** `AVCaptureSession` + `AVCaptureMetadataOutput` (`metadataObjectTypes = [.qr]`), torch via `AVCaptureDevice`.
* **Audio:** `AVAudioSession` category `.playback`, handle route changes/interruption.
* **Lifecycle:** `scenePhase` changes in SwiftUI, app launch re-registration pattern.

*Search terms:*
“AlarmScheduling schedule calendar trigger iOS 26”
“AVCaptureMetadataOutput QR SwiftUI sample”
“SwiftUI scenePhase app becomes active reconcile AlarmScheduling”
“AVAudioSession continuous playback background iOS”
“Swift actor persistence UserDefaults concurrency”

## 16) Risks & Mitigations

* **Notifications off** → block creation; show deep link.
* **Camera denied** → block dismissal; deep link + rationale.
* **User mutes phone** → preflight “Volume reminder” UX; can’t force volume.
* **Audio session killed by OS** → notifications still fire with sound.

## 17) Acceptance Checklist (must pass before ship)

* [ ] All unit & E2E tests pass locally.
* [ ] **Concurrency tests for PersistenceStore pass.**
* [ ] 3-day internal dogfood across 3 devices with no crashes.
* [ ] Notification/camera rationales reviewed; App Privacy strings set.
* [ ] Reliability log shows expected events.
* [ ] No double-audio observed in foreground tests.

## 18) What’s Next (V1 Core preview)

* Add **Steps** and **Math** challenges.
* Challenge **stack** with enforced order + timeouts/lockouts.
* Extend models to `[Challenge]`; migrate `expectedQR` → `.qr(expected:)`.