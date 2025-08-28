# MVP 1 — QR-Only Wake Reliability
_Target: 2025-08-19_

## 1) Mission
Ship a minimal, reliable alarm that **cannot be dismissed** until the user scans a pre-registered QR code. No backend, no subscriptions.

## 2) Problem → Solution
- **Problem:** People silence or snooze alarms too easily.
- **Solution:** Require scanning a specific QR payload to dismiss. Keep the system simple, offline-first, and robust.

## 3) In Scope
- Alarm CRUD: time, repeat, label, sound, volume, vibrate, enable/disable.
- **QR challenge only** (AVFoundation); exact payload match.
- Dismissal flow: **Ringing (fullscreen) → QR Scanner → Success → Dismiss**.
- Local notifications; **re-register** pending alarms on app launch and when app becomes active.
- Local persistence (SwiftData) for alarms + runs + QR payload.
- Basic Settings: default sound, haptics, 12/24h.
- Local reliability log (append events to file or DB).
- Tests: unit (scheduler + QR validator + persistence round-trip), 1 E2E.
- Accessibility & performance basics.

## 4) Out of Scope (MVP 1)
- Steps, Math, multi-challenge stacks.
- Buddy/accountability, photo proof.
- Payments/penalties.
- Bedtime flow, smart wake.
- Any backend/auth.

## 5) UX Spec (flows)
### 5.1 Create/Edit Alarm
- Fields: time, repeat days, label, sound, volume, vibrate, **QR Setup**.
- **QR Setup:** “Save this code’s value” → open scanner → on success, store payload in `Alarm.expectedQR`.

### 5.2 Ringing & Dismissal
- Fullscreen RingingView (screen awake, system volume respected).
- Primary CTA: **“Scan Code to Dismiss.”**
- Scanner screen with torch toggle; if scanned payload == expected → success → stop alarm → mark run success.

### 5.3 Permission UX
- **Notifications**: hard-block scheduling if disabled; inline warning + deep link to Settings.
- **Camera**: block dismissal until granted; explain why and offer Settings deep link.

## 6) Minimal Data Model (Swift / Domain)
- `Alarm { id, time, repeatDays[], label, sound, volume, vibrate, isEnabled, expectedQR:String? }`
- `AlarmRun { id, alarmId, firedAt, dismissedAt?, outcome: success|fail }`

> For full contracts, see `docs/architecture.md` §4–5.

## 7) Services (protocols to implement)
- `NotificationScheduling`: request auth, schedule/cancel, refreshAll, pending IDs.
- `QRScanning`: start/stop, `AsyncStream<String>` of payloads.
- `PersistenceStore`: save/load alarms; append runs.
- `Clock`: `now()` for deterministic time math in tests.

(Concrete implementations live under `Infrastructure/Services/*` and are wired in `DependencyContainer`.)

## 8) App Lifecycle Rules
- On app launch **and** when `scenePhase == .active`: `NotificationScheduling.refreshAll(from: alarms)`.
- Always include a notification action/deeplink back to Ringing/Scanner (“Return to Dismissal”).

## 9) Anti-Cheat Hygiene (MVP-appropriate)
- Preflight check before scheduling: notifications authorized; block + explain if not.
- Ringing cannot be dismissed without QR success (no alternative buttons).
- Log permission changes to local reliability log.

## 10) Definition of Done
- ≥95% of fired alarms require a **valid QR scan** to dismiss in internal testing.
- Works if app is killed/closed: alarm still fires; tapping notification returns to Ringing/Scanner.
- Dark-room QR scan succeeds (torch toggle available).
- No crashes across **3 consecutive days** of scheduled alarms.

## 11) Test Plan
**Unit**
- `ScheduleNextFire` (one-time vs repeat; DST/timezone edges).
- QR validator: exact match vs wrong/case mismatch; empty expected.
- Persistence round-trip: create → save → load → equality.
- Preflight: notifications disabled → scheduling blocked.

**Integration**
- Notification scheduling round-trip with a mock center.
- Storage migration ready for V1 (wrap `expectedQR` into a single-item challenge later).

**UI/E2E**
- Set alarm (1 min ahead) → rings → scan valid QR → dismiss → run outcome recorded.

**Manual Smoke**
- Dark room; Do Not Disturb; volume low; airplane mode; device lock/unlock during ringing.

## 12) Local Reliability Log (MVP scope)
- Events: `scheduled`, `fired`, `dismiss_success_qr`, `dismiss_fail_qr`, `notifications_status_changed`.
- Store locally (JSON/CSV). Export via share sheet (optional).

## 13) Accessibility & Perf
- Min tap target 44pt; Dynamic Type friendly.
- VoiceOver labels on critical buttons (“Scan Code to Dismiss”, “Toggle Torch”).
- No blocking disk I/O on main thread; camera session starts fast (<300ms target).

## 14) Build Order (no-code checklist)
1. **Models & Storage**
   - Create `Alarm`, `AlarmRun` (Domain).
   - SwiftData schema + `PersistenceStore` impl.
2. **Scheduling**
   - `NotificationScheduling` with request auth + schedule + refreshAll.
   - Re-register on launch/active.
3. **UI Scaffolding**
   - `AlarmList`, `AlarmForm`, `Ringing` skeletons.
4. **QR Setup & Dismissal**
   - `QRScanning` service; save expected payload in `Alarm`.
   - Ringing → Scanner → validate → stop.
5. **Reliability Log**
   - Append events; simple export (optional).
6. **Tests**
   - Unit (scheduler, QR, persistence) + one E2E.

## 15) Apple APIs & Search Hints
- **Notifications:** `UNUserNotificationCenter requestAuthorization(options: [.alert, .sound])`, `UNTimeIntervalNotificationTrigger` / `UNCalendarNotificationTrigger`, `getNotificationSettings`.
- **QR:** `AVCaptureSession` + `AVCaptureMetadataOutput` (`metadataObjectTypes = [.qr]`), torch via `AVCaptureDevice`.
- **Lifecycle:** `scenePhase` changes in SwiftUI, app launch re-registration pattern.

_Search terms:_  
“UNUserNotificationCenter schedule calendar trigger iOS 17”  
“AVCaptureMetadataOutput QR SwiftUI sample”  
“SwiftUI scenePhase app becomes active re-register notifications”

## 16) Risks & Mitigations
- **Notifications off** → block creation; show deep link.  
- **Camera denied** → block dismissal; deep link + rationale.  
- **User mutes phone** → preflight “Volume reminder” UX; can’t force volume.

## 17) Acceptance Checklist (must pass before ship)
- [ ] All unit & E2E tests pass locally.
- [ ] 3-day internal dogfood across 3 devices with no crashes.
- [ ] Notification/camera rationales reviewed; App Privacy strings set.
- [ ] Reliability log shows expected events.

## 18) What’s Next (V1 Core preview)
- Add **Steps** and **Math** challenges.
- Challenge **stack** with enforced order + timeouts/lockouts.
- Extend models to `[Challenge]`; migrate `expectedQR` → `.qr(expected:)`.
