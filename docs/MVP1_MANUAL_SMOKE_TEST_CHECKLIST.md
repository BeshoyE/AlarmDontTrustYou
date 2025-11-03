# MVP 1 — QR-Only Manual Smoke Test Checklist

This checklist must be completed on a **physical iOS device** (not simulator) before declaring MVP 1 complete.

**Target:** 2025-08-19
**Definition of Done:** ≥95% of fired alarms require valid QR scan + 3-day dogfood with no crashes.

---

## Prerequisites

- [ ] Physical iPhone running iOS 17+ (minimum supported version)
- [ ] Printed QR code or QR code displayed on another device
- [ ] TestFlight build or Debug build installed
- [ ] All permissions granted (Notifications, Camera, AlarmKit)

---

## Test Session 1: Basic Functionality (30 minutes)

### 1.1 Alarm Creation & QR Setup
- [ ] Create new alarm for 2 minutes in the future
- [ ] Add QR challenge
- [ ] Scan QR code using camera (verify torch toggle works)
- [ ] Save alarm
- [ ] Verify alarm appears in list with correct time
- [ ] Verify alarm toggle is enabled

### 1.2 Alarm Firing (Foreground)
- [ ] Keep app in foreground
- [ ] Wait for alarm to fire
- [ ] Verify fullscreen ringing view appears
- [ ] Verify audio plays continuously
- [ ] Verify "Scan Code to Dismiss" button visible
- [ ] Tap button to begin scan
- [ ] Verify QR scanner opens with camera preview

### 1.3 QR Validation
- [ ] Scan **incorrect** QR code
- [ ] Verify error message displays ("Invalid QR code")
- [ ] Verify returns to scanning state after 1 second
- [ ] Scan **correct** QR code
- [ ] Verify validation spinner appears
- [ ] Verify success screen displays
- [ ] Verify audio stops
- [ ] Verify returns to alarm list

### 1.4 Alarm Run Persistence
- [ ] Navigate to Settings → Diagnostics
- [ ] Tap "Export Logs"
- [ ] Verify share sheet appears
- [ ] Verify JSON contains `fired`, `dismiss_success_qr` events for alarm

---

## Test Session 2: Background & Lock Screen (30 minutes)

### 2.1 App Killed Scenario
- [ ] Create alarm for 2 minutes in future
- [ ] Add QR challenge and scan code
- [ ] Save alarm
- [ ] **Force-kill app** (swipe up from app switcher)
- [ ] Wait for alarm to fire
- [ ] Verify lock screen notification appears
- [ ] Verify notification sound plays
- [ ] Tap notification
- [ ] Verify app cold-starts to ringing view
- [ ] Scan correct QR code
- [ ] Verify dismissal succeeds

### 2.2 Background Scenario
- [ ] Create alarm for 2 minutes in future
- [ ] Add QR challenge
- [ ] Save alarm
- [ ] Press home button (app backgrounds)
- [ ] Wait for alarm to fire
- [ ] Verify notification appears
- [ ] Tap notification
- [ ] Verify app returns to ringing view
- [ ] Verify audio plays
- [ ] Scan correct QR code
- [ ] Verify dismissal succeeds

### 2.3 Lock Screen Scenario
- [ ] Create alarm for 2 minutes in future
- [ ] Add QR challenge
- [ ] Save alarm
- [ ] Lock device (power button)
- [ ] Wait for alarm to fire
- [ ] Verify lock screen notification appears
- [ ] Verify sound plays
- [ ] Unlock device and tap notification
- [ ] Verify navigates to ringing view
- [ ] Scan correct QR code
- [ ] Verify dismissal succeeds

---

## Test Session 3: Edge Cases & Resilience (45 minutes)

### 3.1 Dark Room QR Scan
- [ ] Create alarm
- [ ] Turn off all lights (simulate dark room)
- [ ] Wait for alarm to fire
- [ ] Begin QR scan
- [ ] Tap torch toggle button
- [ ] Verify flashlight turns on
- [ ] Scan QR code with torch enabled
- [ ] Verify successful scan
- [ ] Tap torch toggle again
- [ ] Verify flashlight turns off

### 3.2 Do Not Disturb Mode
- [ ] Enable Do Not Disturb in Control Center
- [ ] Create alarm for 2 minutes ahead
- [ ] Add QR challenge
- [ ] Wait for alarm to fire
- [ ] Verify notification still appears (alarms bypass DND)
- [ ] Verify sound plays
- [ ] Dismiss alarm successfully

### 3.3 Low Volume
- [ ] Set device ringer volume to 10%
- [ ] Create alarm
- [ ] Wait for alarm to fire (lock screen)
- [ ] Verify notification sound plays (at system volume)
- [ ] Tap notification to open app
- [ ] Verify in-app audio plays (at configured volume)

### 3.4 Airplane Mode
- [ ] Enable Airplane Mode
- [ ] Create alarm for 2 minutes ahead
- [ ] Add QR challenge
- [ ] Wait for alarm to fire
- [ ] Verify alarm still fires (local scheduling)
- [ ] Begin QR scan
- [ ] Verify camera works offline
- [ ] Scan correct QR code
- [ ] Verify dismissal succeeds offline

### 3.5 Permission Revocation
- [ ] Go to Settings → Privacy → Camera
- [ ] Disable camera for alarmAppNew
- [ ] Return to app
- [ ] Create alarm and wait for fire
- [ ] Tap "Scan Code to Dismiss"
- [ ] Verify permission blocking view appears
- [ ] Verify "Open Settings" button present
- [ ] Tap "Open Settings"
- [ ] Verify deep links to Camera settings
- [ ] Re-enable camera permission
- [ ] Return to app
- [ ] Verify can now scan QR code

### 3.6 Cancel Scan Flow
- [ ] Create alarm and wait for fire
- [ ] Tap "Scan Code to Dismiss"
- [ ] In scanner, tap "Cancel"
- [ ] Verify returns to ringing view
- [ ] Verify audio still playing
- [ ] Verify can retry scan

### 3.7 Multiple Alarms
- [ ] Create 3 alarms:
  - Alarm 1: Now + 2 min (QR challenge)
  - Alarm 2: Now + 4 min (QR challenge, different QR)
  - Alarm 3: Now + 6 min (QR challenge)
- [ ] Wait for Alarm 1 to fire
- [ ] Dismiss Alarm 1 with correct QR
- [ ] Wait for Alarm 2 to fire
- [ ] Dismiss Alarm 2 with correct QR
- [ ] Wait for Alarm 3 to fire
- [ ] Dismiss Alarm 3 with correct QR
- [ ] Verify no crashes
- [ ] Export logs and verify 3 successful runs

---

## Test Session 4: Accessibility (30 minutes)

### 4.1 VoiceOver
- [ ] Enable VoiceOver (Settings → Accessibility → VoiceOver)
- [ ] Navigate to Alarms List
- [ ] Verify "Create new alarm" button announces correctly
- [ ] Tap button to create alarm
- [ ] Verify "Alarm Time" picker announces time
- [ ] Verify "Save alarm" button announces with hint
- [ ] Navigate to alarm toggle
- [ ] Verify toggle announces "Enable/Disable alarm for [time]"
- [ ] Disable VoiceOver

### 4.2 Dynamic Type
- [ ] Open Settings → Display & Brightness → Text Size
- [ ] Set text size to largest setting
- [ ] Return to app
- [ ] Verify alarm times readable (not truncated)
- [ ] Verify labels readable
- [ ] Create new alarm
- [ ] Verify form fields readable at large text size
- [ ] Set text size back to default

### 4.3 Tap Target Size
- [ ] Using finger (not stylus), verify all buttons tappable:
  - [ ] "+" floating action button
  - [ ] Alarm toggle switches
  - [ ] "Scan Code to Dismiss" button
  - [ ] Torch toggle in scanner
  - [ ] "Cancel" button in scanner
- [ ] Verify no accidental taps on adjacent elements

---

## Test Session 5: 3-Day Dogfood (Validation Phase)

### Setup
- [ ] Create 2-3 recurring alarms (e.g., 8:00 AM daily, 6:00 PM daily)
- [ ] Each alarm has QR challenge
- [ ] Print QR codes and place in different locations

### Daily Checklist (Days 1-3)
**Day 1 Date: ____________**
- [ ] Alarm 1 fired correctly: ☐ Yes ☐ No
- [ ] Alarm 1 dismissed successfully: ☐ Yes ☐ No
- [ ] Alarm 2 fired correctly: ☐ Yes ☐ No
- [ ] Alarm 2 dismissed successfully: ☐ Yes ☐ No
- [ ] Any crashes observed: ☐ Yes ☐ No

**Day 2 Date: ____________**
- [ ] Alarm 1 fired correctly: ☐ Yes ☐ No
- [ ] Alarm 1 dismissed successfully: ☐ Yes ☐ No
- [ ] Alarm 2 fired correctly: ☐ Yes ☐ No
- [ ] Alarm 2 dismissed successfully: ☐ Yes ☐ No
- [ ] Any crashes observed: ☐ Yes ☐ No

**Day 3 Date: ____________**
- [ ] Alarm 1 fired correctly: ☐ Yes ☐ No
- [ ] Alarm 1 dismissed successfully: ☐ Yes ☐ No
- [ ] Alarm 2 fired correctly: ☐ Yes ☐ No
- [ ] Alarm 2 dismissed successfully: ☐ Yes ☐ No
- [ ] Any crashes observed: ☐ Yes ☐ No

### Post-Dogfood Validation
- [ ] Export reliability logs
- [ ] Verify all 6 alarms logged as `fired`
- [ ] Verify all 6 alarms logged as `dismiss_success_qr`
- [ ] Calculate success rate: ____ / 6 = ____% (must be ≥95%)
- [ ] Check for crash logs in Settings → Privacy → Analytics & Improvements → Analytics Data
- [ ] Verify no crash logs for alarmAppNew

---

## Final Sign-Off

**Tester Name:** _____________________
**Test Date:** _____________________
**iOS Version:** _____________________
**Device Model:** _____________________

**Result:** ☐ PASS ☐ FAIL

**Notes/Issues:**
```
[Record any issues, edge cases, or observations here]
```

**Definition of Done Status:**
- [ ] ≥95% of fired alarms required valid QR scan
- [ ] Works if app is killed (notification fires, dismissal reachable)
- [ ] Audio starts when app alive; no double audio
- [ ] Dark-room QR scan succeeds (torch toggle works)
- [ ] No crashes across 3 consecutive days

---

## Troubleshooting Common Issues

### Issue: Alarm doesn't fire
- Check notification permissions (Settings → Notifications → alarmAppNew)
- Check AlarmKit permissions (Settings → Alarms)
- Verify alarm is enabled (toggle on)
- Export logs and check for `scheduled` event

### Issue: Audio doesn't play
- Check device ringer volume (not media volume)
- Check device not in silent mode (switch on side)
- Check Do Not Disturb isn't blocking sound
- Export logs and check for `audio_started` event

### Issue: QR scanner shows black screen
- Check camera permission granted
- Check camera not in use by another app
- Check device has functional rear camera
- Try restarting app

### Issue: Dismissal doesn't stop alarm
- Check QR payload matches exactly (case-sensitive, whitespace-trimmed)
- Export logs and check for `stop_failed` event
- Check for AlarmKit errors in logs

---

**Last Updated:** 2025-10-15
**MVP Version:** 1.0 (QR-Only)
**Next Review:** After V1 (Core Reliability with Steps+Math)
