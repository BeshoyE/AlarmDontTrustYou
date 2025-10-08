//
//  NotificationService.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/7/25.
//

import UserNotifications
import SwiftUI
import UIKit
import os.log

// MARK: - App Lifecycle Tracking

@MainActor
protocol AppLifecycleTracking {
  var isActive: Bool { get }
  func startTracking()
  func stopTracking()
}

@MainActor
final class AppLifecycleTracker: NSObject, AppLifecycleTracking {
  private(set) var isActive: Bool = true

  func startTracking() {
    // Idempotent - safe to call multiple times
    NotificationCenter.default.removeObserver(self)

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(willResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(didEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(didBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )

    // Initialize with current state
    isActive = UIApplication.shared.applicationState == .active
    print("🔄 AppLifecycleTracker: Started tracking, initial state: \(isActive ? "active" : "inactive")")
  }

  func stopTracking() {
    NotificationCenter.default.removeObserver(self)
    print("🔄 AppLifecycleTracker: Stopped tracking")
  }

  @objc private func willResignActive() {
    isActive = false
    print("🔄 AppLifecycleTracker: willResignActive - isActive = false")
  }

  @objc private func didEnterBackground() {
    isActive = false
    print("🔄 AppLifecycleTracker: didEnterBackground - isActive = false")
  }

  @objc private func didBecomeActive() {
    isActive = true
    print("🔄 AppLifecycleTracker: didBecomeActive - isActive = true")
  }

  deinit {
    // Note: deinit is not MainActor isolated, so we use NotificationCenter directly
    NotificationCenter.default.removeObserver(self)
    print("🔄 AppLifecycleTracker: Deallocated and removed observers")
  }
}

// MARK: - Legacy App State Abstraction (deprecated - use AppLifecycleTracking)

@MainActor
protocol AppStateProviding {
  var isAppActive: Bool { get }
}

@MainActor
final class AppStateProvider: AppStateProviding {
  var isAppActive: Bool {
    UIApplication.shared.applicationState == .active
  }
}

// MARK: - Notification Scheduling Protocol
protocol NotificationScheduling {
  func scheduleAlarm(_ alarm: Alarm) async throws
  func cancelAlarm(_ alarm: Alarm) async
  func cancelOccurrence(alarmId: UUID, occurrenceKey: String) async
  func cancelSpecificNotifications(for alarmId: UUID, types: [NotificationType])
  func refreshAll(from alarms: [Alarm]) async
  func pendingAlarmIds() async -> [UUID]
  func scheduleAlarmImmediately(_ alarm: Alarm) async throws
  func scheduleTestNotification(soundName: String?, in seconds: TimeInterval) async throws
  func scheduleTestSystemDefault() async throws
  func scheduleTestCriticalSound() async throws
  func scheduleTestCustomSound(soundName: String?) async throws
  func ensureNotificationCategoriesRegistered()

  // Sound Triage System
  func dumpNotificationSettings() async
  func validateSoundBundle()
  func scheduleTestDefault() async throws
  func scheduleTestCustom() async throws
  func dumpNotificationCategories() async
  func runCompleteSoundTriage() async throws

  // Bare Default Diagnostic Tests
  func scheduleBareDefaultTest() async throws
  func scheduleBareDefaultTestNoInterruption() async throws
  func scheduleBareDefaultTestNoCategory() async throws

  // Background Audio Scheduling - removed, handled by DismissalFlow at fire time

  // MARK: - Occurrence Cleanup (Post-Dismissal)
  /// Get notification request IDs for a specific alarm occurrence
  func getRequestIds(alarmId: UUID, occurrenceKey: String) async -> [String]

  /// Remove notification requests by identifiers (both pending and delivered)
  func removeRequests(withIdentifiers ids: [String]) async

  /// Clean up all notifications for a dismissed occurrence
  func cleanupAfterDismiss(alarmId: UUID, occurrenceKey: String) async

  /// Clean up stale delivered notifications on app startup
  func cleanupStaleDeliveredNotifications() async
}

enum NotificationType: String, CaseIterable {
  case main = "main"
  case preAlarm = "pre_alarm"
  case nudge1 = "nudge_1"
  case nudge2 = "nudge_2"
  case nudge3 = "nudge_3"
}

// MARK: - Notification Classification

private enum Categories {
  static let alarm = "ALARM_CATEGORY"
  static let alarmTest = "ALARM_TEST_CATEGORY"
}

enum NotificationClassification {
  case realAlarm(UUID)
  case test
  case other
}

extension NotificationClassification: Equatable {
  var alarmId: UUID? {
    if case let .realAlarm(id) = self { return id }
    return nil
  }
}

// MARK: - UUID Extension for Type-Checker Performance

private extension UUID {
  var short8: String { String(self.uuidString.prefix(8)) }
}

class NotificationService: NSObject, NotificationScheduling, UNUserNotificationCenterDelegate {
  private let center = UNUserNotificationCenter.current()
  private let permissionService: PermissionServiceProtocol
  private let appStateProvider: AppStateProviding
  private let reliabilityLogger: ReliabilityLogging
  private let appRouter: AppRouter
  private let persistenceService: AlarmStorage
  private let chainedScheduler: ChainedNotificationScheduling
  private let settingsService: SettingsServiceProtocol
  private let audioEngine: AlarmAudioEngineProtocol
  private let dismissedRegistry: DismissedRegistry
  private let chainSettingsProvider: ChainSettingsProviding

  init(
    permissionService: PermissionServiceProtocol,
    appStateProvider: AppStateProviding,
    reliabilityLogger: ReliabilityLogging,
    appRouter: AppRouter,
    persistenceService: AlarmStorage,
    chainedScheduler: ChainedNotificationScheduling,
    settingsService: SettingsServiceProtocol,
    audioEngine: AlarmAudioEngineProtocol,
    dismissedRegistry: DismissedRegistry,
    chainSettingsProvider: ChainSettingsProviding = DefaultChainSettingsProvider()
  ) {
    self.permissionService = permissionService
    self.appStateProvider = appStateProvider
    self.reliabilityLogger = reliabilityLogger
    self.appRouter = appRouter
    self.persistenceService = persistenceService
    self.chainedScheduler = chainedScheduler
    self.settingsService = settingsService
    self.audioEngine = audioEngine
    self.dismissedRegistry = dismissedRegistry
    self.chainSettingsProvider = chainSettingsProvider
    super.init()
  }

  func ensureNotificationCategoriesRegistered() {
    setupNotificationCategories()
    print("NotificationService: Categories registered/re-registered")
  }

  // MARK: - Notification Classification Helper

  private func classifyNotification(_ content: UNNotificationContent) -> NotificationClassification {
    // Test category first
    if content.categoryIdentifier == Categories.alarmTest {
      return .test
    }

    // Dual-era compatibility (one release only)
    if content.categoryIdentifier == Categories.alarm {
      // Check for explicit test flag
      if content.userInfo["isTest"] as? Bool == true {
        return .test
      }

      // Check for valid alarm ID
      if let alarmIdString = content.userInfo["alarmId"] as? String,
         let alarmId = UUID(uuidString: alarmIdString) {
        return .realAlarm(alarmId)
      }
    }

    return .other
  }

  private func logNotificationEvent(_ event: String, _ classification: NotificationClassification, categoryId: String, action: String? = nil) {
    reliabilityLogger.log(
      .notificationsStatusChanged,
      alarmId: nil,
      details: [
        "event": event,
        "categoryId": categoryId,
        "actionId": action ?? "none",
        "isTest": "\(classification == .test)",
        "alarmId": classification.alarmId?.uuidString ?? "none"
      ]
    )
  }

  // MARK: - Centralized Content Setup

  private func configureNotificationContent(for alarm: Alarm, type: NotificationType) -> UNMutableNotificationContent {
    let content = UNMutableNotificationContent()

    // Universal userInfo injection - every notification gets alarmId and category
    content.userInfo = ["alarmId": alarm.id.uuidString, "type": type.rawValue]
    content.categoryIdentifier = "ALARM_CATEGORY"

    // Unified sound attachment for all notification types
    content.sound = validateSoundAttachment(createNotificationSound(for: alarm.soundName), alarmId: alarm.id)

    // iOS 15+ Time-sensitive interruption level for urgent notifications
    if #available(iOS 15, *) {
      switch type {
      case .main, .nudge1, .nudge2, .nudge3:
        content.interruptionLevel = .timeSensitive
      case .preAlarm:
        content.interruptionLevel = .active
      }
    }

    switch type {
    case .preAlarm:
      content.title = "Upcoming Alarm"
      content.body = "\(alarm.label) will ring in 5 minutes. Keep the app open for reliable dismissal."
    case .main:
      content.title = alarm.label
      content.body = "Tap to dismiss your alarm"
    case .nudge1:
      content.title = "⚠️ \(alarm.label)"
      content.body = "Your alarm is still ringing! Return to dismiss it."
    case .nudge2:
      content.title = "🚨 \(alarm.label)"
      content.body = "URGENT: Please dismiss your alarm now!"
    case .nudge3:
      content.title = "🔴 \(alarm.label)"
      content.body = "CRITICAL: Your alarm has been ringing for 5 minutes!"
    }

    return content
  }

  private func setupNotificationCategories() {
    // Build actions for real alarms
    let openAction = UNNotificationAction(
      identifier: "OPEN_ALARM",
      title: "Open",
      options: [.foreground]
    )

    let returnToDismissalAction = UNNotificationAction(
      identifier: "RETURN_TO_DISMISSAL",
      title: "Return to Dismissal",
      options: [.foreground]
    )

    let snoozeAction = UNNotificationAction(
      identifier: "SNOOZE_ALARM",
      title: "Snooze 5 min",
      options: []
    )

    // Real alarm category (unchanged behavior)
    let alarmCategory = UNNotificationCategory(
      identifier: Categories.alarm,
      actions: [openAction, returnToDismissalAction, snoozeAction],
      intentIdentifiers: [],
      options: [.customDismissAction]
    )

    // Test category - NO dismissal actions (prevents accidental routing)
    let testCategory = UNNotificationCategory(
      identifier: Categories.alarmTest,
      actions: [], // Empty - no dismissal routing possible
      intentIdentifiers: [],
      options: []
    )

    // Register both categories
    center.setNotificationCategories([alarmCategory, testCategory])
  }

  @MainActor
  private func presentRingingWhenReady(_ id: UUID) async {
    print("🔍 presentRingingWhenReady: Starting wait for scene activation (alarm: \(id.uuidString.prefix(8)))")

    for attempt in 0..<10 {
      if let s = UIApplication.shared.connectedScenes.first as? UIWindowScene,
         s.activationState == .foregroundActive {
        print("✅ presentRingingWhenReady: Scene is active, routing now (attempt: \(attempt + 1))")
        break
      }
      print("⏳ presentRingingWhenReady: Scene not active, waiting... (attempt: \(attempt + 1))")
      try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
    }

    print("🔍 presentRingingWhenReady: Calling appRouter.showRinging for alarm: \(id.uuidString.prefix(8))")
    appRouter.showRinging(for: id)
    print("✅ presentRingingWhenReady: appRouter.showRinging completed")
  }


  func scheduleAlarm(_ alarm: Alarm) async throws {
    // DEFENSIVE: Ensure categories are registered before any scheduling
    // This prevents race conditions where scheduling happens before categories are ready
    ensureNotificationCategoriesRegistered()

    // Settings diagnostics - log current notification settings for observability
    await logNotificationSettings(alarmId: alarm.id)

    // Check permissions before scheduling
    let permissionDetails = await permissionService.checkNotificationPermission()

    guard permissionDetails.authorizationStatus == .authorized else {
      throw NotificationError.permissionDenied
    }

    // Warn if notifications are authorized but muted
    if permissionDetails.isAuthorizedButMuted {
      // Log warning - sound is disabled
      print("Warning: Notifications authorized but sound is disabled")
    }

    // Check feature flag for chained scheduling
    #if DEBUG
    print("🔍 [DIAG] useChainedScheduling: \(await settingsService.useChainedScheduling)")
    #endif

    guard await settingsService.useChainedScheduling else {
      // Fall back to legacy single-notification path
      print("📊 NotificationService: Using legacy scheduling (feature flag disabled)")
      return try await scheduleLegacyAlarm(alarm)
    }

    // CRITICAL: Compute next fire date from Domain logic
    // Pass the EXACT Date to Infrastructure - no normalization, no reconstruction
    guard let nextFireDate = computeNextFireDate(for: alarm) else {
      print("❌ NotificationService: No valid next fire date for alarm \(alarm.id)")
      throw NotificationError.invalidConfiguration
    }

    // Use chained notification scheduler with Domain-computed date
    print("📊 NotificationService: Using chained scheduling for alarm \(alarm.id)")
    print("📊 DOMAIN anchor: \(nextFireDate.ISO8601Format()) for alarm \(alarm.id.uuidString.prefix(8))")
    let outcome = await chainedScheduler.scheduleChain(for: alarm, fireDate: nextFireDate)

    #if DEBUG
    print("🔍 [DIAG] Chain outcome: \(outcome)")
    #endif

    // Log outcome with structured context for prod triage
    logScheduleOutcome(outcome, alarmId: alarm.id, fireDate: alarm.time)

    // Handle outcome
    switch outcome {
    case .scheduled(let count):
      // Success - count notifications scheduled
      print("✅ NotificationService: Scheduled \(count) notifications for alarm \(alarm.id)")
      return

    case .trimmed(let original, let scheduled):
      // Partial success - log warning but don't throw
      print("⚠️ NotificationService: Trimmed chain for alarm \(alarm.id): \(original) → \(scheduled)")
      reliabilityLogger.log(
        .scheduled,
        alarmId: alarm.id,
        details: [
          "outcome": "trimmed",
          "original": "\(original)",
          "scheduled": "\(scheduled)",
          "fireDate": alarm.time.description
        ]
      )
      return

    case .unavailable(.permissions):
      print("❌ NotificationService: Permissions denied for alarm \(alarm.id)")
      throw NotificationError.permissionDenied

    case .unavailable(.globalLimit):
      print("❌ NotificationService: Global limit exceeded for alarm \(alarm.id)")
      throw NotificationError.systemLimitExceeded

    case .unavailable(.invalidConfiguration):
      print("❌ NotificationService: Invalid configuration for alarm \(alarm.id) - domain gave past anchor")
      throw NotificationError.invalidConfiguration

    case .unavailable(.other(let error)):
      print("❌ NotificationService: Scheduling failed for alarm \(alarm.id): \(error)")
      throw error
    }
  }

  // MARK: - Legacy Scheduling (Fallback)

  private func scheduleLegacyAlarm(_ alarm: Alarm) async throws {
    if alarm.repeatDays.isEmpty {
      // One-time alarm
      try await scheduleOneTimeAlarm(alarm)
    } else {
      // Repeating alarm
      try await scheduleRepeatingAlarm(alarm)
    }
  }

  private func scheduleOneTimeAlarm(_ alarm: Alarm) async throws {
    let alarmTime = alarm.time
    let now = Date()

    // Schedule pre-alarm reminder (5 minutes before)
    let preAlarmTime = alarmTime.addingTimeInterval(-5 * 60)
    if preAlarmTime > now {
      try await scheduleNotification(
        for: alarm,
        type: .preAlarm,
        time: preAlarmTime,
        repeats: false
      )
    }

    // Schedule main alarm
    try await scheduleNotification(
      for: alarm,
      type: .main,
      time: alarmTime,
      repeats: false
    )

    // Background audio scheduling removed - handled by DismissalFlow at fire time

    // Schedule nudge notifications (30 seconds, 2 minutes, 5 minutes after)
    try await scheduleNotification(
      for: alarm,
      type: .nudge1,
      time: alarmTime.addingTimeInterval(30),
      repeats: false
    )

    try await scheduleNotification(
      for: alarm,
      type: .nudge2,
      time: alarmTime.addingTimeInterval(2 * 60),
      repeats: false
    )

    try await scheduleNotification(
      for: alarm,
      type: .nudge3,
      time: alarmTime.addingTimeInterval(5 * 60),
      repeats: false
    )
  }

  private func scheduleRepeatingAlarm(_ alarm: Alarm) async throws {
    for day in alarm.repeatDays {
      let dayComponent = day.rawValue

      // Schedule pre-alarm reminder for each day
      try await scheduleNotification(
        for: alarm,
        type: .preAlarm,
        weekday: dayComponent,
        timeOffset: -5 * 60,
        repeats: true
      )

      // Schedule main alarm for each day
      try await scheduleNotification(
        for: alarm,
        type: .main,
        weekday: dayComponent,
        timeOffset: 0,
        repeats: true
      )

      // Note: Background audio for repeating alarms is scheduled closer to fire time
      // to maintain reliability within the 5-10 minute scheduling window

      // Schedule nudge notifications for each day
      try await scheduleNotification(
        for: alarm,
        type: .nudge1,
        weekday: dayComponent,
        timeOffset: 30,
        repeats: true
      )

      try await scheduleNotification(
        for: alarm,
        type: .nudge2,
        weekday: dayComponent,
        timeOffset: 2 * 60,
        repeats: true
      )

      try await scheduleNotification(
        for: alarm,
        type: .nudge3,
        weekday: dayComponent,
        timeOffset: 5 * 60,
        repeats: true
      )
    }
  }

  private func scheduleNotification(
    for alarm: Alarm,
    type: NotificationType,
    time: Date,
    repeats: Bool
  ) async throws {
    let content = configureNotificationContent(for: alarm, type: type)
    let trigger = createOptimalTrigger(for: type, time: time, repeats: repeats)
    let identifier = notificationIdentifier(for: alarm.id, type: type)

    let request = UNNotificationRequest(
      identifier: identifier,
      content: content,
      trigger: trigger
    )

    try await center.add(request)
  }

  private func scheduleNotification(
    for alarm: Alarm,
    type: NotificationType,
    weekday: Int,
    timeOffset: TimeInterval,
    repeats: Bool
  ) async throws {
    let content = configureNotificationContent(for: alarm, type: type)

    // For repeating nudges, we need to use calendar triggers but include seconds for short offsets
    let baseTime = alarm.time.addingTimeInterval(timeOffset)
    let dateComponents: Set<Calendar.Component> = (type == .nudge1 || type == .nudge2 || type == .nudge3) ?
    [.weekday, .hour, .minute, .second] :
    [.weekday, .hour, .minute]

    var dateComps = Calendar.current.dateComponents(dateComponents, from: baseTime)
    dateComps.weekday = weekday

    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComps, repeats: repeats)
    let identifier = notificationIdentifier(for: alarm.id, type: type, weekday: weekday)

    let request = UNNotificationRequest(
      identifier: identifier,
      content: content,
      trigger: trigger
    )

    try await center.add(request)
  }

  // MARK: - UNUserNotificationCenterDelegate

  @MainActor
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let content = notification.request.content
    let classification = classifyNotification(content)

    // Phase 4: Enhanced delegate logging with exactly-once completion handler
    var completed = false // MUST-FIX #1: var not let
    defer {
      assert(completed, "completionHandler must be called exactly once")
    }

    // Extract values for type-checker performance
    let notifId: String = notification.request.identifier
    let categoryId: String = content.categoryIdentifier
    print("📥 willPresent: id=", notifId, "cat=", categoryId, "userInfo=", content.userInfo)

    switch classification {
    case .realAlarm(let alarmId):
      // Extract common values to avoid type-checker complexity
      let alarmIdPrefix: String = alarmId.short8
      let occurrenceKey: String? = content.userInfo["occurrenceKey"] as? String

      // Check dismissed registry: skip routing if this occurrence was already dismissed
      if let key = occurrenceKey {
        if dismissedRegistry.isDismissed(alarmId: alarmId, occurrenceKey: key) {
          let keyPrefix: String = String(key.prefix(10))
          print("🔍 Occurrence", alarmIdPrefix + "/" + keyPrefix + "...", "already dismissed, skipping flow")

          // Delivered notifications will be cleaned up by NotificationService.cleanupAfterDismiss()
          // No need to do it here - just prevent presentation

          completed = true
          completionHandler([])  // Empty presentation options - don't show notification
          return
        }
      } else {
        // Fallback: check alarm runs for legacy compatibility
        do {
          let runs = try persistenceService.runs(for: alarmId)
          let now = Date()
          let recentSuccess = runs.first { (run: AlarmRun) in
            guard run.outcome == .success else { return false }
            let timeSinceFired = now.timeIntervalSince(run.firedAt)
            return timeSinceFired < 300
          }

          if recentSuccess != nil {
            print("⚠️ Legacy: Alarm", alarmIdPrefix, "already dismissed (missing occurrenceKey)")
            completed = true
            completionHandler([])
            return
          }
        } catch {
          print("⚠️ Failed to check alarm runs:", error)
        }
      }

      // Get current policy for capability-based audio handling
      let policy = settingsService.audioPolicy

      // Foreground Assist: Play AV audio if app is active and capability allows
      // Check suppressForegroundSound setting BEFORE playing audio
      if policy.capability == .foregroundAssist &&
         UIApplication.shared.applicationState == .active &&
         !settingsService.suppressForegroundSound {
        do {
          // Fetch alarm to get sound name
          if let alarm = try? persistenceService.alarm(with: alarmId) {
            let soundName = alarm.soundName ?? "ringtone1"
            try audioEngine.playForegroundAlarm(soundName: soundName)
            print("🔔 Foreground Assist: Started AV audio for alarm", alarmIdPrefix)
          }
        } catch {
          print("⚠️ Foreground Assist: Failed to play AV audio -", error)
          // Continue with notification sound as fallback
        }
      } else if settingsService.suppressForegroundSound && UIApplication.shared.applicationState == .active {
        print("🔔 Foreground Assist: Suppressing foreground sound (setting enabled)")
      }

      // Smart sound suppression: suppress notification sound ONLY if audio engine is actively ringing
      // SINGLE SOURCE: Only check audioEngine.isActivelyRinging (engine handles policy internally)
      let audioRinging: Bool = audioEngine.isActivelyRinging
      let suppressSetting: Bool = settingsService.suppressForegroundSound
      let shouldSuppressSound = audioRinging && suppressSetting

      let options: UNNotificationPresentationOptions = shouldSuppressSound
        ? [.banner, .list]              // Audio engine is providing sound
        : [.banner, .list, .sound]      // Notifications provide sound

      // Extract values for type-checker performance
      let optsStr: String = String(describing: options)
      let capabilityStr: String = String(describing: policy.capability)
      print("🔔 Real alarm detected - capability:", capabilityStr, "options:", optsStr)

      #if DEBUG
      print("🔍 [DIAG] willPresent - audioRinging:", audioRinging, "suppressSetting:", suppressSetting, "opts:", optsStr)
      #endif

      completed = true
      completionHandler(options)

      logNotificationEvent("willPresent_real", classification, categoryId: content.categoryIdentifier)

      // willPresent is for presentation options only - NO routing
      // User must explicitly tap notification to trigger didReceive → routing

    case .test:
      // Test notification - allow sound but NO routing
      print("📥 Test notification - allowing sound, no dismissal routing")
      completed = true
      completionHandler([.banner, .list, .sound])

      logNotificationEvent("willPresent_test", classification, categoryId: content.categoryIdentifier)
      // No routing for tests - this fixes the bug!

    case .other:
      // Unknown notification - default handling
      print("ℹ️ Non-alarm notification - using default presentation")
      completed = true
      completionHandler([.banner, .list])

      logNotificationEvent("willPresent_other", classification, categoryId: content.categoryIdentifier)
    }
  }

  @MainActor
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    let content = response.notification.request.content
    let classification = classifyNotification(content)

    let actionId: String = response.actionIdentifier
    print("NotificationService: didReceive response, action:", actionId)

    switch classification {
    case .realAlarm(let alarmId):
      // Extract common values to avoid type-checker complexity
      let alarmIdPrefix: String = alarmId.short8
      let occurrenceKey: String? = content.userInfo["occurrenceKey"] as? String

      // Real alarm - handle routing based on action
      logNotificationEvent("didReceive_real", classification, categoryId: content.categoryIdentifier, action: response.actionIdentifier)

      // Check if this occurrence was already dismissed
      if let key = occurrenceKey {
        if dismissedRegistry.isDismissed(alarmId: alarmId, occurrenceKey: key) {
          let keyPrefix: String = String(key.prefix(10))
          print("🔍 didReceive: Occurrence", alarmIdPrefix + "/" + keyPrefix + "...", "already dismissed, skipping routing")
          // Delivered notifications cleaned up by NotificationService.cleanupAfterDismiss()
          completionHandler()
          return
        }
      } else {
        // Legacy fallback: check AlarmRun history
        do {
          let runs: [AlarmRun] = try persistenceService.loadRuns()
          let now = Date()
          let isDismissed = runs.contains(where: { (run: AlarmRun) in
            guard run.alarmId == alarmId else { return false }
            guard run.dismissedAt != nil else { return false }
            let timeSinceFired = abs(now.timeIntervalSince(run.firedAt))
            return timeSinceFired < 120  // Within last 2 minutes
          })
          if isDismissed {
            print("🔍 didReceive: Alarm", alarmIdPrefix, "recently completed (legacy check), skipping routing")
            completionHandler()
            return
          }
        } catch {
          print("⚠️ Failed to check alarm runs in didReceive:", error)
        }
      }

      // CHUNK 2.6: Strengthen guards before routing
      // Log warning if occurrenceKey missing (legacy mode)
      if occurrenceKey == nil {
        print("⚠️ didReceive: Missing occurrenceKey for alarm", alarmIdPrefix, "- using legacy mode")
      }

      // Final validation: only route on explicit user actions
      // (Snooze and unknown actions handled below in switch)
      guard [UNNotificationDefaultActionIdentifier, "OPEN_ALARM", "RETURN_TO_DISMISSAL", "SNOOZE_ALARM"].contains(response.actionIdentifier) else {
        print("⚠️ didReceive: Non-routing action", response.actionIdentifier, "for alarm", alarmIdPrefix)
        completionHandler()
        return
      }

      switch response.actionIdentifier {
      case UNNotificationDefaultActionIdentifier, "OPEN_ALARM", "RETURN_TO_DISMISSAL":
        // Route to dismissal flow (guaranteed main thread)
        Task {
          print("🔍 NotificationService: Routing to ringing from notification tap for alarm:", alarmIdPrefix)
          await presentRingingWhenReady(alarmId)
          print("✅ NotificationService: Notification tap routing completed for alarm:", alarmIdPrefix)

          let source = getSourceName(for: response.actionIdentifier)
          reliabilityLogger.logAlarmFired(alarmId, details: ["source": source])
        }

      case "SNOOZE_ALARM":
        // Handle snooze in background
        Task {
          await handleSnoozeAction(alarmId: alarmId)
        }

      default:
        print("NotificationService: Unknown action identifier: \(response.actionIdentifier)")
        reliabilityLogger.log(
          .notificationsStatusChanged,
          alarmId: alarmId,
          details: ["error": "unknown_action", "action": response.actionIdentifier]
        )
      }

      completionHandler() // MUST-FIX #4: Call on every path

    case .test:
      // Test notification tapped - log and return (NO routing)
      print("🧪 Test notification tapped - not routing to dismissal flow")
      logNotificationEvent("didReceive_test", classification, categoryId: content.categoryIdentifier, action: response.actionIdentifier)
      completionHandler() // MUST-FIX #4: Call on every path

    case .other:
      // Unknown notification category
      print("⚠️ Unknown notification category tapped: \(content.categoryIdentifier)")
      logNotificationEvent("didReceive_other", classification, categoryId: content.categoryIdentifier, action: response.actionIdentifier)
      completionHandler() // MUST-FIX #4: Call on every path
    }
  }

  private func getSourceName(for actionIdentifier: String) -> String {
    switch actionIdentifier {
    case UNNotificationDefaultActionIdentifier:
      return "notification_tap"
    case "OPEN_ALARM":
      return "open_action"
    case "RETURN_TO_DISMISSAL":
      return "return_action"
    default:
      return "unknown_action"
    }
  }

  private func handleSnoozeAction(alarmId: UUID) async {
    do {
      // Load the alarm
      let alarm = try await persistenceService.alarm(with: alarmId)

      // Cancel current nudge notifications but keep main alarm pattern
      cancelSpecificNotifications(for: alarmId, types: [.nudge1, .nudge2, .nudge3])

      // Create snooze alarm (5 minutes from now)
      let snoozeTime = Date().addingTimeInterval(5 * 60)
      var snoozeAlarm = alarm
      snoozeAlarm.time = snoozeTime

      // Schedule the snooze alarm
      try await scheduleAlarm(snoozeAlarm)

      // Log the snooze event
      await reliabilityLogger.log(
        .scheduled,
        alarmId: alarmId,
        details: ["action": "snooze", "snooze_duration": "300"]
      )

      print("NotificationService: Snoozed alarm \(alarmId) for 5 minutes")

    } catch {
      print("NotificationService: Failed to handle snooze for alarm \(alarmId): \(error)")
    }
  }

  func cancelAlarm(_ alarm: Alarm) async {
    let alarmIdShort = alarm.id.uuidString.prefix(8)

    // Step 1: Clear the chain index
    if await settingsService.useChainedScheduling {
      await chainedScheduler.cancelChain(alarmId: alarm.id)
    }

    // Step 2: Remove ALL pending notifications by prefix (orphan cleanup)
    let pending = await center.pendingNotificationRequests()
    let alarmPrefix = "alarm-\(alarm.id.uuidString)"
    let legacyPrefix = alarm.id.uuidString

    let toRemove = pending.compactMap { request -> String? in
      let id = request.identifier
      if id.hasPrefix(alarmPrefix) || id.hasPrefix(legacyPrefix) {
        return id
      }
      return nil
    }

    let pendingRemoved = toRemove.count
    if !toRemove.isEmpty {
      center.removePendingNotificationRequests(withIdentifiers: toRemove)
    }

    // Step 3: Count delivered before removal
    let deliveredBefore = await center.deliveredNotifications()
    let deliveredForAlarm = deliveredBefore.filter { notif in
      if let alarmId = notif.request.content.userInfo["alarmId"] as? String {
        return alarmId == alarm.id.uuidString
      }
      return false
    }
    let deliveredRemoved = deliveredForAlarm.count

    // Remove delivered notifications
    await removeDeliveredNotifications(for: alarm.id, types: NotificationType.allCases)

    print("📊 cancelAlarm \(alarmIdShort): removed {pending:\(pendingRemoved), delivered:\(deliveredRemoved)}")
  }

  func cancelOccurrence(alarmId: UUID, occurrenceKey: String) async {
    // Occurrence-scoped cancellation: only cancel notifications for this specific occurrence
    // Used for repeating alarms to avoid nuking future occurrences

    if await settingsService.useChainedScheduling {
      // Delegate to chained scheduler for occurrence-scoped cancellation
      await chainedScheduler.cancelOccurrence(alarmId: alarmId, occurrenceKey: occurrenceKey)

      // Extract values for type-checker performance
      let alarmIdPrefix: String = alarmId.short8
      let keyPrefix: String = String(occurrenceKey.prefix(10))
      print("📊 NotificationService: Canceled occurrence", alarmIdPrefix + "/" + keyPrefix + "...")
    } else {
      // Legacy path: time-window fallback
      print("⚠️ NotificationService: cancelOccurrence called in legacy mode - using time-window fallback")
      // For legacy, we don't have fine-grained occurrence tracking, so just clear delivered
    }

    // Remove delivered notifications for this occurrence
    await removeDeliveredNotifications(for: alarmId, types: NotificationType.allCases)
  }

  // MARK: - Occurrence Cleanup Implementation

  func getRequestIds(alarmId: UUID, occurrenceKey: String) async -> [String] {
    guard await settingsService.useChainedScheduling else {
      return []  // Legacy mode doesn't support occurrence-scoped cleanup
    }

    // Primary path: Filter chained scheduler index by occurrence key
    let allIdentifiers = chainedScheduler.getIdentifiers(alarmId: alarmId)
    let filtered = allIdentifiers.filter { identifier in
      identifier.contains("-occ-\(occurrenceKey)-")
    }

    // Fallback: If index returns empty, scan pending/delivered (resilience against index mismatch)
    if filtered.isEmpty {
      let alarmIdPrefix = alarmId.short8
      print("⚠️ getRequestIds: Index empty for", alarmIdPrefix, "- using fallback scan")

      let pending = await center.pendingNotificationRequests()
      let delivered = await fetchDeliveredNotifications()

      let matchingPending = pending.filter { request in
        guard let key = request.content.userInfo["occurrenceKey"] as? String else { return false }
        return key == occurrenceKey
      }.map { $0.identifier }

      let matchingDelivered = delivered.filter { notification in
        guard let key = notification.request.content.userInfo["occurrenceKey"] as? String else { return false }
        return key == occurrenceKey
      }.map { $0.request.identifier }

      return Array(Set(matchingPending + matchingDelivered))  // Deduplicate
    }

    return filtered
  }

  func removeRequests(withIdentifiers ids: [String]) async {
    guard !ids.isEmpty else { return }

    // Remove from both pending and delivered
    center.removePendingNotificationRequests(withIdentifiers: ids)
    center.removeDeliveredNotifications(withIdentifiers: ids)
  }

  func cleanupAfterDismiss(alarmId: UUID, occurrenceKey: String) async {
    // Get all notification IDs for this occurrence
    let ids = await getRequestIds(alarmId: alarmId, occurrenceKey: occurrenceKey)

    guard !ids.isEmpty else {
      let alarmIdPrefix = alarmId.short8
      let keyPrefix = String(occurrenceKey.prefix(10))
      print("⚠️ dismiss_cleanup: No IDs found for", alarmIdPrefix + "/" + keyPrefix + "...")
      return
    }

    // Count before removal for logging
    let pendingBefore = await center.pendingNotificationRequests()
    let deliveredBefore = await fetchDeliveredNotifications()
    let pendingCount = pendingBefore.filter { ids.contains($0.identifier) }.count
    let deliveredCount = deliveredBefore.filter { ids.contains($0.request.identifier) }.count

    // Remove notifications
    await removeRequests(withIdentifiers: ids)

    // Structured logging with correlation IDs
    let alarmIdPrefix = alarmId.short8
    let keyPrefix = String(occurrenceKey.prefix(10))
    print("🧹 dismiss_cleanup: alarm=\(alarmIdPrefix) occ=\(keyPrefix)... removed_pending=\(pendingCount) removed_delivered=\(deliveredCount)")
  }

  func cleanupStaleDeliveredNotifications() async {
    let delivered = await fetchDeliveredNotifications()
    let dismissedKeys = await dismissedRegistry.dismissedOccurrenceKeys()

    // Filter delivered notifications whose occurrence keys are in dismissed set
    let toRemove = delivered.filter { notification in
      guard let key = notification.request.content.userInfo["occurrenceKey"] as? String else {
        return false
      }
      return dismissedKeys.contains(key)
    }.map { $0.request.identifier }

    guard !toRemove.isEmpty else {
      print("🧹 startup_cleanup: No stale notifications found")
      return
    }

    // Remove both delivered and pending (in case any are still scheduled)
    center.removeDeliveredNotifications(withIdentifiers: toRemove)
    center.removePendingNotificationRequests(withIdentifiers: toRemove)

    print("🧹 startup_cleanup: removed=\(toRemove.count)")
  }

  func cancelSpecificNotifications(for alarmId: UUID, types: [NotificationType]) {
    var identifiersToCancel: [String] = []

    for type in types {
      identifiersToCancel.append(notificationIdentifier(for: alarmId, type: type))

      // For repeating alarms, also cancel weekday-specific notifications
      for weekday in 1...7 {
        identifiersToCancel.append(notificationIdentifier(for: alarmId, type: type, weekday: weekday))
      }
    }

    // Remove pending notifications (not yet delivered)
    center.removePendingNotificationRequests(withIdentifiers: identifiersToCancel)

    // Remove delivered notifications (delivered but possibly not yet presented)
    Task {
      await removeDeliveredNotifications(for: alarmId, types: types)
    }
  }

  // MARK: - Immediate Scheduling (Critical Path)

  func scheduleAlarmImmediately(_ alarm: Alarm) async throws {
    print("📊 scheduleAlarmImmediately: Starting for alarm \(alarm.id.uuidString.prefix(8))")

    // Guard: Only schedule enabled alarms
    guard alarm.isEnabled else {
      print("📊 scheduleAlarmImmediately: Alarm \(alarm.id.uuidString.prefix(8)) is disabled, skipping")
      return
    }

    // Use existing scheduleAlarm which has all the proper protections:
    // - Domain anchor computation
    // - Background task wrapper in ChainedNotificationScheduler
    // - Serialized remove-then-add
    // - Interval-only triggers
    try await scheduleAlarm(alarm)

    // CRITICAL POST-CHECK: Verify notifications were actually scheduled
    let pending = await center.pendingNotificationRequests()
    let alarmIdString = alarm.id.uuidString
    let ourPending = pending.filter { request in
      request.content.userInfo["alarmId"] as? String == alarmIdString ||
      request.identifier.contains(alarmIdString)
    }

    print("📊 IMMEDIATE post_check: alarm=\(alarm.id.uuidString.prefix(8)) pendingCount=\(ourPending.count) ids=\(ourPending.map { $0.identifier })")

    // For chained scheduling, we expect 3 notifications (base + 2 follow-ups)
    // For legacy, we expect at least 1
    let expectedMinimum = await settingsService.useChainedScheduling ? 3 : 1

    if ourPending.count < expectedMinimum {
      print("❌ CRITICAL FAILURE: Expected at least \(expectedMinimum) notifications but only \(ourPending.count) are pending for alarm \(alarm.id.uuidString.prefix(8))")
      throw NotificationError.schedulingFailed
    }

    print("✅ scheduleAlarmImmediately: Successfully scheduled \(ourPending.count) notifications for alarm \(alarm.id.uuidString.prefix(8))")
  }

  func refreshAll(from alarms: [Alarm]) async {
    print("📊 refreshAll: STARTING with \(alarms.count) alarms")

    // Step 1: Compute desired identifiers for all enabled alarms
    var desiredByAlarm: [UUID: Set<String>] = [:]
    var allDesired = Set<String>()

    for alarm in alarms where alarm.isEnabled {
      let identifiers = await computeDesiredIdentifiers(for: alarm)
      desiredByAlarm[alarm.id] = identifiers
      allDesired.formUnion(identifiers)
    }

    // Step 2: Fetch pending from OS and our index, union them (handles OS lag)
    let pendingRequests = await center.pendingNotificationRequests()
    let osPending = Set(pendingRequests.compactMap { request in
      let id = request.identifier
      return isOurNotification(id) ? id : nil
    })

    // Also include what we have in our notification index (handles OS lag window)
    let indexedIdentifiers = chainedScheduler.getAllTrackedIdentifiers()

    // Union OS pending with our index (covers OS lag window)
    let ourPending = osPending.union(indexedIdentifiers)

    // Step 3: Compute diff
    let planned = allDesired.count
    let toAdd = allDesired.subtracting(ourPending)
    let toRemove = ourPending.subtracting(allDesired)

    // Step 4: Apply changes atomically (remove then add)
    if !toRemove.isEmpty {
      center.removePendingNotificationRequests(withIdentifiers: Array(toRemove))
    }

    // Step 5: Schedule only missing notifications per alarm
    var addedSuccess = 0
    for alarm in alarms where alarm.isEnabled {
      guard let alarmDesired = desiredByAlarm[alarm.id] else { continue }
      let missingForAlarm = alarmDesired.intersection(toAdd)

      if !missingForAlarm.isEmpty {
        do {
          try await scheduleMissingIdentifiers(for: alarm, identifiers: missingForAlarm)
          addedSuccess += missingForAlarm.count
        } catch {
          print("Failed to schedule missing notifications for alarm \(alarm.id.uuidString.prefix(8)): \(error)")
        }
      }
    }

    // Step 6: Get actual pending count after operations
    let pendingAfter = await center.pendingNotificationRequests()
    let pendingAfterCount = pendingAfter.filter { isOurNotification($0.identifier) }.count

    // Step 7: Structured logging with accurate metrics
    print("📊 refreshAll: planned=\(planned) pending_before=\(ourPending.count) added_success=\(addedSuccess) removed=\(toRemove.count) pending_after=\(pendingAfterCount)")

    // Log details for debugging
    if addedSuccess > 0 || toRemove.count > 0 {
      reliabilityLogger.log(
        .notificationsStatusChanged,
        alarmId: nil,
        details: [
          "event": "refresh_all_diff",
          "planned": "\(planned)",
          "pending_before": "\(ourPending.count)",
          "added_success": "\(addedSuccess)",
          "removed_count": "\(toRemove.count)",
          "pending_after": "\(pendingAfterCount)"
        ]
      )
    }
  }

  func pendingAlarmIds() async -> [UUID] {
    let requests = await center.pendingNotificationRequests()
    return requests.compactMap { request in
      // Use userInfo instead of identifier parsing
      guard let alarmIdString = request.content.userInfo["alarmId"] as? String else {
        return nil
      }
      return UUID(uuidString: alarmIdString)
    }
  }

  // MARK: - Outcome Logging

  /// Logs ScheduleOutcome with structured context for production triage
  private func logScheduleOutcome(_ outcome: ScheduleOutcome, alarmId: UUID, fireDate: Date) {
    let outcomeString: String
    let details: [String: String]

    switch outcome {
    case .scheduled(let count):
      outcomeString = "scheduled(\(count))"
      details = [
        "event": "chained_schedule_success",
        "outcome": outcomeString,
        "count": "\(count)",
        "fireDate": fireDate.ISO8601Format(),
        "useChainedScheduling": "true"
      ]

    case .trimmed(let original, let scheduled):
      outcomeString = "trimmed(\(original)→\(scheduled))"
      details = [
        "event": "chained_schedule_trimmed",
        "outcome": outcomeString,
        "original": "\(original)",
        "scheduled": "\(scheduled)",
        "fireDate": fireDate.ISO8601Format(),
        "useChainedScheduling": "true"
      ]

    case .unavailable(let reason):
      let reasonString = String(describing: reason)
      outcomeString = "unavailable(\(reasonString))"
      details = [
        "event": "chained_schedule_failed",
        "outcome": outcomeString,
        "reason": reasonString,
        "fireDate": fireDate.ISO8601Format(),
        "useChainedScheduling": "true"
      ]
    }

    reliabilityLogger.log(
      .scheduled,
      alarmId: alarmId,
      details: details
    )

    print("📊 NotificationService: Outcome logged for alarm \(alarmId): \(outcomeString)")
  }

  // MARK: - Settings Diagnostics

  /// Logs current notification settings for observability - non-blocking
  private func logNotificationSettings(alarmId: UUID) async {
    let settings = await withCheckedContinuation { continuation in
      center.getNotificationSettings { settings in
        continuation.resume(returning: settings)
      }
    }

    var settingsDetails: [String: String] = [
      "event": "settings_fetched",
      "authorizationStatus": "\(settings.authorizationStatus)",
      "alertSetting": "\(settings.alertSetting)",
      "soundSetting": "\(settings.soundSetting)"
    ]

    // iOS 15+ specific settings
    if #available(iOS 15, *) {
      settingsDetails["timeSensitiveSetting"] = "\(settings.timeSensitiveSetting)"
    }

    reliabilityLogger.log(
      .scheduled,
      alarmId: alarmId,
      details: settingsDetails
    )
  }

  // MARK: - Sound Validation

  /// Validates sound attachment and provides fallback with structured logging
  private func validateSoundAttachment(_ sound: UNNotificationSound, alarmId: UUID) -> UNNotificationSound {
    // For custom sounds, verify the underlying file exists
    if sound != .default && sound != .defaultCritical {
      // UNNotificationSound doesn't expose the file name directly, but our createNotificationSound
      // already does the validation. If we reach here with a custom sound, it passed validation.
      reliabilityLogger.log(
        .scheduled,
        alarmId: alarmId,
        details: ["event": "sound_attached", "sound_type": "custom", "validation": "passed"]
      )
      return sound
    } else {
      // Default sound - log for observability
      reliabilityLogger.log(
        .scheduled,
        alarmId: alarmId,
        details: ["event": "sound_attached", "sound_type": "default", "validation": "fallback"]
      )
      return sound
    }
  }

  // MARK: - Private Helpers

  /// Fetches delivered notifications using proper Swift concurrency wrapper around callback-based API
  private func fetchDeliveredNotifications() async -> [UNNotification] {
    return await withCheckedContinuation { continuation in
      center.getDeliveredNotifications { notifications in
        continuation.resume(returning: notifications)
      }
    }
  }

  /// Prevents future nudges from firing by removing delivered notifications that match exact identifiers.
  /// Note: This is preventive, not retractive - already-presented banners remain visible (iOS system behavior).
  /// Cancels both pending and delivered notifications using occurrence-scoped identifiers for precision.
  /// Aligns with CLAUDE.md §3 (async) and §5 (protocol contracts).
  private func removeDeliveredNotifications(for alarmId: UUID, types: [NotificationType]) async {
    let deliveredNotifications = await fetchDeliveredNotifications()

    // Determine which identifier format to use based on chained scheduling setting
    let useChainedScheduling = await settingsService.useChainedScheduling

    var identifiersToRemove: [String] = []

    if useChainedScheduling {
      // Chained scheduling: identifiers follow pattern "alarm-{uuid}-occ-{ISO8601}-{occurrence}"
      // Match any delivered notification whose identifier starts with "alarm-{alarmId}"
      let prefix = "alarm-\(alarmId.uuidString)-occ-"
      for notification in deliveredNotifications {
        let identifier = notification.request.identifier
        if identifier.hasPrefix(prefix) {
          identifiersToRemove.append(identifier)
        }
      }
    } else {
      // Legacy scheduling: use exact identifier matching
      let expectedIdentifiers = generateExpectedIdentifiers(for: alarmId, types: types)
      for notification in deliveredNotifications {
        let identifier = notification.request.identifier
        if expectedIdentifiers.contains(identifier) {
          identifiersToRemove.append(identifier)
        }
      }
    }

    if !identifiersToRemove.isEmpty {
      center.removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
      print("NotificationService: Removed \(identifiersToRemove.count) delivered notifications for alarm \(alarmId) (chained: \(useChainedScheduling))")
    }
  }

  /// Generates exact notification identifiers using the same logic as scheduling for precise matching
  private func generateExpectedIdentifiers(for alarmId: UUID, types: [NotificationType]) -> Set<String> {
    var expectedIdentifiers: Set<String> = []

    for type in types {
      // One-time alarm identifier
      expectedIdentifiers.insert(notificationIdentifier(for: alarmId, type: type))

      // Repeating alarm identifiers (all possible weekdays)
      for weekday in 1...7 {
        expectedIdentifiers.insert(notificationIdentifier(for: alarmId, type: type, weekday: weekday))
      }
    }

    return expectedIdentifiers
  }

  private func createOptimalTrigger(for type: NotificationType, time: Date, repeats: Bool) -> UNNotificationTrigger {
    let now = Date()
    let timeInterval = time.timeIntervalSince(now)

    // For nudges and short intervals (≤ 1 hour), use interval trigger for precision
    if !repeats && timeInterval <= 3600 && timeInterval > 0 {
      switch type {
      case .nudge1, .nudge2, .nudge3:
        return UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
      default:
        break
      }
    }

    // For main alarms and pre-alarms, use calendar trigger for exact time matching
    let dateComponents: Set<Calendar.Component> = repeats ?
    [.hour, .minute] :
    [.year, .month, .day, .hour, .minute, .second]

    let dateComps = Calendar.current.dateComponents(dateComponents, from: time)
    return UNCalendarNotificationTrigger(dateMatching: dateComps, repeats: repeats)
  }


  private func notificationIdentifier(for alarmId: UUID, type: NotificationType, weekday: Int? = nil) -> String {
    let base = "\(alarmId.uuidString)-\(type.rawValue)"
    if let weekday = weekday {
      return "\(base)-weekday-\(weekday)"
    }
    return base
  }

  private func generateAllNotificationIdentifiers(for alarm: Alarm) -> [String] {
    var identifiers: [String] = []

    for type in NotificationType.allCases {
      if alarm.repeatDays.isEmpty {
        // One-time alarm
        identifiers.append(notificationIdentifier(for: alarm.id, type: type))
      } else {
        // Repeating alarm
        for day in alarm.repeatDays {
          identifiers.append(notificationIdentifier(for: alarm.id, type: type, weekday: day.rawValue))
        }
      }
    }

    return identifiers
  }

  // MARK: - Idempotent Scheduling Helpers

  /// Compute all expected notification identifiers for an alarm
  private func computeDesiredIdentifiers(for alarm: Alarm) async -> Set<String> {
    // If disabled, return empty set immediately
    guard alarm.isEnabled else { return [] }

    // Check if using chained scheduling
    if await settingsService.useChainedScheduling {
      // Always compute from Domain schedule (source of truth)
      guard let nextFireDate = computeNextFireDate(for: alarm) else {
        return []
      }

      // Get chain configuration from POLICY, not magic numbers
      let chainSettings = chainSettingsProvider.chainSettings()
      let spacingSeconds = chainSettings.fallbackSpacingSec

      // Compute chain count based on window and spacing
      let chainCount = min(
        chainSettings.maxChainCount,
        chainSettings.ringWindowSec / max(1, spacingSeconds)
      )

      // Generate identifiers based on actual next fire date
      let occurrenceKey = OccurrenceKeyFormatter.key(from: nextFireDate)
      var identifiers = Set<String>()

      for i in 0..<chainCount {
        let id = "alarm-\(alarm.id.uuidString)-occ-\(occurrenceKey)-\(i)"
        identifiers.insert(id)
      }

      return identifiers
    } else {
      // Legacy mode: use existing identifier generation
      return Set(generateAllNotificationIdentifiers(for: alarm))
    }
  }

  /// Check if an identifier belongs to our app's namespace
  private func isOurNotification(_ identifier: String) -> Bool {
    // Chained format: alarm-{uuid}-occ-{key}-{n}
    if identifier.hasPrefix("alarm-") {
      return true
    }

    // Legacy format: {uuid}-{type} or {uuid}-{type}-weekday-{n}
    // Check if it starts with a valid UUID
    let components = identifier.components(separatedBy: "-")
    if components.count >= 2,
       let firstComponent = components.first,
       UUID(uuidString: firstComponent) != nil {
      return true
    }

    return false
  }

  /// Schedule only the missing notifications for an alarm
  private func scheduleMissingIdentifiers(for alarm: Alarm, identifiers: Set<String>) async throws {
    // For chained scheduling, we need to re-run the full schedule
    // because notifications are interdependent
    if await settingsService.useChainedScheduling {
      // The chained scheduler will handle deduplication internally
      try await scheduleAlarm(alarm)
    } else {
      // For legacy mode, we can be more surgical
      // But since legacy schedules all types at once, easier to just reschedule
      try await scheduleAlarm(alarm)
    }
  }

  /// Normalize a date to have 0 seconds and nanoseconds
  private func normalizeToMinute(_ date: Date) -> Date {
    let calendar = Calendar.current
    var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    components.second = 0
    components.nanosecond = 0
    return calendar.date(from: components) ?? date
  }

  /// Compute next fire date for an alarm
  private func computeNextFireDate(for alarm: Alarm) -> Date? {
    let now = Date()
    let calendar = Calendar.current

    if alarm.repeatDays.isEmpty {
      // One-time alarm: Pure domain logic - today if future, tomorrow if past
      var components = calendar.dateComponents([.year, .month, .day], from: now)
      let timeComponents = calendar.dateComponents([.hour, .minute], from: alarm.time)
      components.hour = timeComponents.hour
      components.minute = timeComponents.minute
      components.second = 0

      guard let candidate = calendar.date(from: components) else { return nil }

      // Simple rule: If candidate > now, use today; otherwise tomorrow
      let fireDate: Date
      let policyReason: String
      if candidate > now {
        fireDate = candidate
        policyReason = "TODAY_SINGLE"
      } else {
        fireDate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        policyReason = "TOMORROW_SINGLE"
      }

      // Log domain decision
      os_log("NextOccurrence: policy=%@ now=%@ candidate=%@ anchor=%@",
             log: OSLog.default, type: .info, policyReason,
             now.ISO8601Format(), candidate.ISO8601Format(), fireDate.ISO8601Format())

      return fireDate
    } else {
      // Repeating alarm - find next occurrence
      let weekday = calendar.component(.weekday, from: now)
      let alarmTime = calendar.dateComponents([.hour, .minute], from: alarm.time)

      // Check each day starting from today to find the next occurrence
      for dayOffset in 0..<7 {
        let targetWeekday = ((weekday - 1 + dayOffset) % 7) + 1
        let targetDay = Weekdays(rawValue: targetWeekday)

        if alarm.repeatDays.contains(targetDay ?? .sunday) {
          var components = calendar.dateComponents([.year, .month, .day], from: now)
          components.hour = alarmTime.hour
          components.minute = alarmTime.minute
          components.second = 0

          guard let candidate = calendar.date(from: components) else { continue }
          let fireDate = calendar.date(byAdding: .day, value: dayOffset, to: candidate) ?? candidate

          // For today (dayOffset=0), check if time is still in the future
          if dayOffset == 0 && fireDate <= now {
            continue  // Skip today, try next matching day
          }

          // Found valid future occurrence
          let policyReason = dayOffset == 0 ? "TODAY_REPEAT" : "NEXT_WEEKDAY_REPEAT"

          os_log("NextOccurrence: policy=%@ now=%@ dayOffset=%d anchor=%@",
                 log: OSLog.default, type: .info, policyReason,
                 now.ISO8601Format(), dayOffset, fireDate.ISO8601Format())

          return fireDate
        }
      }
    }

    return nil
  }

  private func createNotificationSound(for soundName: String?) -> UNNotificationSound {
    print("🔊 NotificationService: createNotificationSound called with: '\(soundName ?? "nil")'")

    guard let soundName = soundName, !soundName.isEmpty, soundName != "default" else {
      print("🔊 NotificationService: Using system default sound (soundName was: '\(soundName ?? "nil")')")
      return .default
    }

    // Find the sound asset - updated to use actual bundled files
    let soundAssets = [
      "ringtone1": "ringtone1.caf",
      "classic": "ringtone1.caf",  // Fallback mapping
      "chime": "ringtone1.caf",    // Fallback mapping
      "bell": "ringtone1.caf",     // Fallback mapping
      "radar": "ringtone1.caf"     // Fallback mapping
    ]

    guard let fileName = soundAssets[soundName] else {
      print("🔊 NotificationService: ❌ Unknown sound '\(soundName)' - available: \(Array(soundAssets.keys)) - falling back to default")
      return .default
    }

    print("🔊 NotificationService: Mapped '\(soundName)' to file '\(fileName)'")

    // Check if file exists in bundle
    let nameWithoutExtension = String(fileName.prefix(upTo: fileName.lastIndex(of: ".") ?? fileName.endIndex))
    let fileExtension = String(fileName.suffix(from: fileName.index(after: fileName.lastIndex(of: ".") ?? fileName.startIndex)))

    guard let fileURL = Bundle.main.url(forResource: nameWithoutExtension, withExtension: fileExtension) else {
      print("🔊 NotificationService: ❌ Sound file '\(fileName)' not found in bundle - falling back to default")
      print("🔊 NotificationService: Searched for: name='\(nameWithoutExtension)' ext='\(fileExtension)'")
      return .default
    }

    print("🔊 NotificationService: ✅ Found sound file at: \(fileURL.path)")

    // Check file size and provide warnings for iOS notification limits
    do {
      let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
      if let fileSize = attributes[.size] as? Int64 {
        print("🔊 NotificationService: File size: \(fileSize) bytes (\(Double(fileSize) / 1024.0 / 1024.0) MB)")
        if fileSize > 5 * 1024 * 1024 { // 5MB warning threshold
          print("🔊 NotificationService: ⚠️ Large file detected - iOS notification sounds should be ≤30 seconds")
        }
      }
    } catch {
      print("🔊 NotificationService: Could not check file attributes: \(error)")
    }

    let customSound = UNNotificationSound(named: UNNotificationSoundName(fileName))
    print("🔊 NotificationService: ✅ Created custom UNNotificationSound with name: '\(fileName)'")
    return customSound
  }

  // MARK: - Test Notification Helper

  /// Test system default sound (should always work)
  func scheduleTestSystemDefault() async throws {
    print("🔔 Testing SYSTEM DEFAULT notification sound...")

    let content = UNMutableNotificationContent()
    content.title = "🔔 System Default Test"
    content.body = "Testing iOS system default notification sound"
    content.sound = .default // Explicit system default

    print("🔔 Notification content configured:")
    print("  - title: '\(content.title)'")
    print("  - body: '\(content.body)'")
    print("  - sound: \(content.sound)")
    print("  - categoryIdentifier: '\(content.categoryIdentifier)'")

    // iOS 15+ Time-sensitive for testing
    if #available(iOS 15, *) {
      content.interruptionLevel = .timeSensitive
      print("  - interruptionLevel: .timeSensitive")
    } else {
      print("  - interruptionLevel: not available (iOS < 15)")
    }

    let testAlarmId = UUID()
    content.userInfo = ["alarmId": testAlarmId.uuidString, "type": "test_default", "isTest": true]
    content.categoryIdentifier = Categories.alarmTest

    print("  - userInfo: \(content.userInfo)")

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2.0, repeats: false)
    let request = UNNotificationRequest(
      identifier: "test-default-\(testAlarmId.uuidString)",
      content: content,
      trigger: trigger
    )

    print("🔔 Scheduling notification with identifier: \(request.identifier)")
    try await center.add(request)
    print("🔔 ✅ System default test notification scheduled for 2 seconds")

    // Log current notification settings
    await logNotificationSettings(alarmId: testAlarmId)
  }

  /// Test with critical alert sound (may require special entitlement)
  func scheduleTestCriticalSound() async throws {
    print("🔔 Testing CRITICAL SOUND notification...")

    let content = UNMutableNotificationContent()
    content.title = "🔔 Critical Sound Test"
    content.body = "Testing iOS critical alert sound (may need entitlement)"
    content.sound = .defaultCritical // Critical sound that should bypass silent mode

    // iOS 15+ Time-sensitive for testing
    if #available(iOS 15, *) {
      content.interruptionLevel = .critical
    }

    let testAlarmId = UUID()
    content.userInfo = ["alarmId": testAlarmId.uuidString, "type": "test_critical", "isTest": true]
    content.categoryIdentifier = Categories.alarmTest

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 4.0, repeats: false)
    let request = UNNotificationRequest(
      identifier: "test-critical-\(testAlarmId.uuidString)",
      content: content,
      trigger: trigger
    )

    try await center.add(request)
    print("🔔 ✅ Critical sound test notification scheduled for 4 seconds")
  }

  /// Test custom sound with full diagnostics
  func scheduleTestCustomSound(soundName: String?) async throws {
    print("🔔 Testing CUSTOM sound: '\(soundName ?? "nil")'...")

    let content = UNMutableNotificationContent()
    content.title = "🔔 Custom Sound Test"
    content.body = "Testing custom notification sound: \(soundName ?? "none")"

    let testAlarmId = UUID()

    // DIAGNOSTIC: Call createNotificationSound directly and log result
    let sound = createNotificationSound(for: soundName)
    print("🔊 createNotificationSound returned: \(sound)")

    // Use sound validation with full logging
    content.sound = validateSoundAttachment(sound, alarmId: testAlarmId)

    // iOS 15+ Time-sensitive for testing
    if #available(iOS 15, *) {
      content.interruptionLevel = .timeSensitive
    }

    content.userInfo = ["alarmId": testAlarmId.uuidString, "type": "test_custom", "isTest": true]
    content.categoryIdentifier = Categories.alarmTest

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 4.0, repeats: false)
    let request = UNNotificationRequest(
      identifier: "test-custom-\(testAlarmId.uuidString)",
      content: content,
      trigger: trigger
    )

    try await center.add(request)

    // Log the test for observability
    reliabilityLogger.log(
      .scheduled,
      alarmId: testAlarmId,
      details: ["event": "test_custom_sound", "sound_name": soundName ?? "default", "delay_seconds": "4.0"]
    )

    print("🔔 Custom sound test notification scheduled for 4 seconds with sound '\(soundName ?? "default")'")
  }

  /// Enhanced test helper for QA verification of sound behavior
  func scheduleTestNotificationWithSound(soundName: String?) async throws {
    try await scheduleTestCustomSound(soundName: soundName)
  }

  /// Legacy test helper - maintained for backward compatibility
  func scheduleTestNotification(soundName: String?, in seconds: TimeInterval = 5.0) async throws {
    try await scheduleTestNotificationWithSound(soundName: soundName)
  }

  // MARK: - Sound Resolution (for diagnostics)
  // Background audio scheduling removed - handled by DismissalFlow at fire time

  /// Resolve sound names to actual bundled asset files
  private func resolveSoundToActualFile(_ soundName: String?) -> String {
    // Handle nil, empty, or "default" - these need to map to actual bundle files
    guard let soundName = soundName, !soundName.isEmpty, soundName != "default" else {
      print("🔊 NotificationService: Mapping 'default'/nil sound to 'ringtone1'")
      return "ringtone1"
    }

    // Map any unknown sounds to known assets (fallback chain)
    let knownSounds = ["ringtone1", "classic", "chime", "bell", "radar"]
    if knownSounds.contains(soundName) {
      return "ringtone1" // All our current sounds map to ringtone1 for now
    }

    // Unknown sound - use fallback
    print("🔊 NotificationService: Unknown sound '\(soundName)' - falling back to 'ringtone1'")
    return "ringtone1"
  }

  // stopAlarmAudio removed - handled directly by DismissalFlow via protocol

  // Removed scheduleNextRepeatingAlarmAudio - background audio now handled by DismissalFlow at fire time

  // MARK: - Sound Triage System (Device Only)

  /// Phase 1: Comprehensive notification settings audit
  func dumpNotificationSettings() async {
    let settings = await withCheckedContinuation { continuation in
      center.getNotificationSettings { settings in
        continuation.resume(returning: settings)
      }
    }

    // Header with device context and hardware warnings
    print("📱 Device: \(UIDevice.current.model) - iOS \(UIDevice.current.systemVersion)")
    print("🛑 Hardware mute mutes notification sounds (Time Sensitive breaks Focus, not the mute switch)")
    print("")

    print("""
      🔧 Full notification settings audit:
        authorizationStatus: \(settings.authorizationStatus.rawValue) (target: 2=authorized)
        alertSetting: \(settings.alertSetting.rawValue) (target: 2=enabled)
        soundSetting: \(settings.soundSetting.rawValue) (target: 2=enabled)
        badgeSetting: \(settings.badgeSetting.rawValue)
        lockScreenSetting: \(settings.lockScreenSetting.rawValue)
        notificationCenterSetting: \(settings.notificationCenterSetting.rawValue)
        carPlaySetting: \(settings.carPlaySetting.rawValue)
      """ )

    if #available(iOS 15.0, *) {
      let timeSensitiveText = settings.timeSensitiveSetting.rawValue == 0 ?
        "\(settings.timeSensitiveSetting.rawValue) (0=notSupported)" :
        "\(settings.timeSensitiveSetting.rawValue) (target: 2=enabled)"
      print("""
        timeSensitiveSetting: \(timeSensitiveText)
        criticalAlertSetting: \(settings.criticalAlertSetting.rawValue) (ignore unless entitled)
        scheduledDeliverySetting: \(settings.scheduledDeliverySetting.rawValue) (target: 2=enabled for immediate)
        """)
    } else {
      print("        timeSensitiveSetting: N/A (iOS 15+ only)")
    }

    // Check for provisional authorization (delivers quietly)
    if settings.authorizationStatus == .provisional {
      print("⚠️  PROVISIONAL AUTH - Delivers quietly (no sound, no banners)")
    }

    // Warning messages for common issues
    if settings.soundSetting != .enabled {
      print("⚠️  SOUND DISABLED - This will prevent lock screen audio!")
    }
    if #available(iOS 15.0, *), settings.timeSensitiveSetting == .disabled {
      print("⚠️  TIME SENSITIVE DISABLED - May be suppressed by Focus modes!")
    }
    if #available(iOS 15.0, *), settings.scheduledDeliverySetting != .enabled {
      print("⚠️  SCHEDULED SUMMARY ENABLED - Turn off for immediate delivery!")
    }

    print("")
    print("📋 REQUIRED iOS SETTINGS PATH:")
    print("   Settings → Notifications → alarmAppNew → Allow Notifications ON")
    print("   → Sounds ON → Time Sensitive ON → Deliver Immediately")
    print("⚠️  API cannot read 'Deliver in Summary/Deliver Quietly' - user must verify this screen")
  }

  /// Phase 2: Bundle validation for custom sounds
  func validateSoundBundle() {
    print("🔊 Sound bundle validation:")

    // Check bundle path existence with exact case matching
    let bundlePath = Bundle.main.path(forResource: "ringtone1", ofType: "caf")
    print("  📁 Bundle.main.path(forResource:\"ringtone1\", ofType:\"caf\"): \(bundlePath ?? "nil")")

    if let path = bundlePath, let url = Bundle.main.url(forResource: "ringtone1", withExtension: "caf") {
      print("  ✅ Found custom sound: \(url.lastPathComponent)")
      print("  📁 Full path: \(url.path)")

      // Check file attributes and sound constraints
      do {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let fileSize = attributes[.size] as? Int64 {
          let sizeInMB = Double(fileSize) / 1024.0 / 1024.0
          print("  📏 File size: \(fileSize) bytes (\(String(format: "%.2f", sizeInMB)) MB)")

          // Sound constraint checks
          print("  🔍 Sound constraints check:")
          print("    • Duration: Must be <30 seconds (iOS requirement)")
          print("    • Format: Uncompressed PCM/IMA4 in CAF container")
          print("    • Case: Exact match 'ringtone1.caf' required")
          print("    • Location: Bundle root (not in asset catalog)")

          if fileSize > 10 * 1024 * 1024 {
            print("  ⚠️  File > 10MB - likely exceeds 30 second duration limit")
          }
        }
      } catch {
        print("  ⚠️  Could not read file attributes: \(error)")
      }
    } else {
      print("  ❌ ringtone1.caf NOT found in main bundle")
      print("  💡 Required checks:")
      print("    1. File in Copy Bundle Resources with correct Target Membership")
      print("    2. Exact case: 'ringtone1.caf' (case-sensitive)")
      print("    3. Format: CAF/AIFF/WAV, <30s, uncompressed PCM/IMA4")
      print("    4. Location: Bundle root (not asset catalog)")
    }
  }

  /// Phase 3: A/B Sound Testing with identical content except sound
  private func configureBaseContent(_ content: UNMutableNotificationContent, id: UUID, label: String, type: String) {
    content.title = "🔔 \(label)"
    content.body = "Lock now — should play sound"
    content.categoryIdentifier = Categories.alarmTest // Use test category
    content.userInfo = ["alarmId": id.uuidString, "type": type, "isTest": true] // Add isTest flag

    if #available(iOS 15.0, *) {
      content.interruptionLevel = .timeSensitive
    }
  }

  /// Test A: System default sound (5 second delay)
  func scheduleTestDefault() async throws {
    let id = UUID()

    // Cancel any existing test requests first
    let testId = "test-default-\(id)"
    center.removePendingNotificationRequests(withIdentifiers: [testId])

    let content = UNMutableNotificationContent()
    configureBaseContent(content, id: id, label: "Default Sound", type: "test_default")

    // Set sound and log the actual object at schedule time
    content.sound = .default
    print("🧪 Test A - Default Sound:")
    print("  🔊 Schedule time sound: \(content.sound?.debugDescription ?? "nil")")
    print("  📋 category: \(content.categoryIdentifier)")
    if #available(iOS 15.0, *) {
      print("  🚨 interruptionLevel: .timeSensitive")
    }
    print("  ⏱️  trigger: 5 seconds")

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5.0, repeats: false)
    let request = UNNotificationRequest(identifier: testId, content: content, trigger: trigger)

    // EXPLICIT ASSERT: Prove this is default sound type
    print("  🔒 ASSERT final sound_type=default")
    print("  🔒 ASSERT: Final sound before add → \(content.sound?.debugDescription ?? "nil")")

    try await center.add(request)
    print("  ✅ Scheduled Test A")
  }

  /// Test B: Custom sound (11 second delay - staggered timing)
  func scheduleTestCustom() async throws {
    let id = UUID()

    // Verify bundle path exists before proceeding
    guard Bundle.main.path(forResource: "ringtone1", ofType: "caf") != nil else {
      print("  ❌ Cannot schedule Test B - ringtone1.caf not found in bundle")
      throw NotificationError.schedulingFailed
    }

    // Cancel any existing test requests first
    let testId = "test-custom-\(id)"
    center.removePendingNotificationRequests(withIdentifiers: [testId])

    // SURGICAL FIX: Complete bypass of all helpers for Test B
    let content = UNMutableNotificationContent()

    // Manual content setup (bypass configureBaseContent to avoid any sound touching)
    content.title = "🔔 Custom Sound"
    content.body = "Lock now — should play CUSTOM ringtone1.caf sound"
    content.categoryIdentifier = Categories.alarmTest
    content.userInfo = ["alarmId": id.uuidString, "type": "test_custom", "isTest": true]

    // Set Time Sensitive BEFORE sound assignment
    if #available(iOS 15.0, *) {
      content.interruptionLevel = .timeSensitive
    }

    // DIRECT CUSTOM SOUND ASSIGNMENT - NO HELPERS
    content.sound = UNNotificationSound(named: UNNotificationSoundName("ringtone1.caf"))

    print("🧪 Test B - Custom Sound (SURGICAL):")
    print("  🔊 Schedule time sound: \(content.sound?.debugDescription ?? "nil")")
    print("  📋 category: \(content.categoryIdentifier)")
    if #available(iOS 15.0, *) {
      print("  🚨 interruptionLevel: .timeSensitive")
    }
    print("  ⏱️  trigger: 11 seconds (staggered)")

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 11.0, repeats: false)
    let request = UNNotificationRequest(identifier: testId, content: content, trigger: trigger)

    // EXPLICIT ASSERT: Prove this is custom sound type
    print("  🔒 ASSERT final sound_type=custom name=ringtone1.caf")
    print("  🔒 ASSERT: custom sound preserved → \(content.sound?.debugDescription ?? "nil")")

    try await center.add(request)
    print("  ✅ Scheduled Test B")
  }

  /// Bare Default Test: Bulletproof diagnostic to isolate root cause
  func scheduleBareDefaultTest() async throws {
    let center = UNUserNotificationCenter.current()

    // 1) Request non-provisional authorization up front
    do {
      let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
      print("auth request granted=\(granted)")
    } catch {
      print("auth request error:", error)
    }

    // Then read *actual* settings inside callback
    center.getNotificationSettings { s in
      print("🔍 BARE TEST - Real Settings:",
            "auth=\(s.authorizationStatus.rawValue)",     // 2=authorized, 3=provisional(quiet)
            "sound=\(s.soundSetting.rawValue)",            // 2=enabled
            "alert=\(s.alertSetting.rawValue)",            // 2=enabled
            "lock=\(s.lockScreenSetting.rawValue)",        // 2=enabled
            "timeSensitive=\(s.timeSensitiveSetting.rawValue)") // 0/1/2

      // CRITICAL: Check for provisional auth trap
      if s.authorizationStatus.rawValue == 3 {
        print("⚠️ PROVISIONAL AUTH DETECTED - This causes quiet delivery!")
      }
    }

    // 2) Register test category (use existing test category)
    let testCategory = UNNotificationCategory(identifier: Categories.alarmTest, actions: [], intentIdentifiers: [], options: [])
    center.setNotificationCategories([testCategory])

    // 3) Minimal content with default sound
    let content = UNMutableNotificationContent()
    content.title = "🔔 Bare Default Test"
    content.body = "Should ring with default sound on lock"
    content.sound = .default
    content.categoryIdentifier = Categories.alarmTest
    content.userInfo = ["alarmId": UUID().uuidString, "type": "test_bare_default", "isTest": true]
    if #available(iOS 15.0, *) { content.interruptionLevel = .timeSensitive } // not .passive

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 6, repeats: false)
    let request = UNNotificationRequest(identifier: "bare-default-\(UUID().uuidString)",
                                        content: content, trigger: trigger)

    do {
      try await center.add(request)
      print("🟢 scheduled bare-default; lock device now")
    } catch {
      print("🔴 add error:", error)  // <-- surface scheduling failures
    }

    print("📊 INTERPRETATION:")
    print("   • Rings: iOS settings fine → issue in main triage pipeline")
    print("   • Silent but banner shows: quiet delivery (provisional/Focus/Sounds off)")
    print("   • Nothing appears: authorization/scheduling issue")
  }

  /// Bare Default Test WITHOUT interruptionLevel: Eliminates .timeSensitive as a variable
  func scheduleBareDefaultTestNoInterruption() async throws {
    let center = UNUserNotificationCenter.current()

    // 1) Request non-provisional authorization up front
    do {
      let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
      print("auth request granted=\(granted)")
    } catch {
      print("auth request error:", error)
    }

    // Then read *actual* settings inside callback
    center.getNotificationSettings { s in
      print("🔍 BARE TEST NO-INTERRUPTION - Real Settings:",
            "auth=\(s.authorizationStatus.rawValue)",     // 2=authorized, 3=provisional(quiet)
            "sound=\(s.soundSetting.rawValue)",            // 2=enabled
            "alert=\(s.alertSetting.rawValue)",            // 2=enabled
            "lock=\(s.lockScreenSetting.rawValue)",        // 2=enabled
            "timeSensitive=\(s.timeSensitiveSetting.rawValue)") // 0/1/2

      // CRITICAL: Check for provisional auth trap
      if s.authorizationStatus.rawValue == 3 {
        print("⚠️ PROVISIONAL AUTH DETECTED - This causes quiet delivery!")
      }
    }

    // 2) Register test category (use existing test category)
    let testCategory = UNNotificationCategory(identifier: Categories.alarmTest, actions: [], intentIdentifiers: [], options: [])
    center.setNotificationCategories([testCategory])

    // 3) Minimal content with default sound - NO interruptionLevel set
    let content = UNMutableNotificationContent()
    content.title = "🔔 Bare Default Test (No Interruption)"
    content.body = "Should ring with default sound on lock"
    content.sound = .default
    content.categoryIdentifier = Categories.alarmTest
    content.userInfo = ["alarmId": UUID().uuidString, "type": "test_bare_no_interruption", "isTest": true]
    // NOTE: Deliberately NOT setting interruptionLevel to eliminate that variable

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 8, repeats: false)
    let request = UNNotificationRequest(identifier: "bare-default-no-interruption-\(UUID().uuidString)",
                                        content: content, trigger: trigger)

    do {
      try await center.add(request)
      print("🟢 scheduled bare-default NO-INTERRUPTION; lock device now")
    } catch {
      print("🔴 add error:", error)  // <-- surface scheduling failures
    }

    print("📊 INTERPRETATION:")
    print("   • Rings: iOS settings fine → issue in main triage pipeline")
    print("   • Silent but banner shows: quiet delivery (provisional/Focus/Sounds off)")
    print("   • Nothing appears: authorization/scheduling issue")
  }

  /// Bare Default Test WITHOUT category: Eliminates category interference
  func scheduleBareDefaultTestNoCategory() async throws {
    let center = UNUserNotificationCenter.current()

    // 1) Request non-provisional authorization up front
    do {
      let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
      print("auth request granted=\(granted)")
    } catch {
      print("auth request error:", error)
    }

    // Then read *actual* settings inside callback
    center.getNotificationSettings { s in
      print("🔍 BARE TEST NO-CATEGORY - Real Settings:",
            "auth=\(s.authorizationStatus.rawValue)",     // 2=authorized, 3=provisional(quiet)
            "sound=\(s.soundSetting.rawValue)",            // 2=enabled
            "alert=\(s.alertSetting.rawValue)",            // 2=enabled
            "lock=\(s.lockScreenSetting.rawValue)",        // 2=enabled
            "timeSensitive=\(s.timeSensitiveSetting.rawValue)") // 0/1/2

      // CRITICAL: Check for provisional auth trap
      if s.authorizationStatus.rawValue == 3 {
        print("⚠️ PROVISIONAL AUTH DETECTED - This causes quiet delivery!")
      }
    }

    // 2) NO category registration - skip entirely

    // 3) Minimal content with default sound - NO category
    let content = UNMutableNotificationContent()
    content.title = "🔔 Bare Default Test (No Category)"
    content.body = "Should ring with default sound on lock"
    content.sound = .default
    // NOTE: Deliberately NOT setting categoryIdentifier to eliminate category interference
    if #available(iOS 15.0, *) { content.interruptionLevel = .timeSensitive }

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
    let request = UNNotificationRequest(identifier: "bare-default-no-category-\(UUID().uuidString)",
                                        content: content, trigger: trigger)

    do {
      try await center.add(request)
      print("🟢 scheduled bare-default NO-CATEGORY; lock device now")
    } catch {
      print("🔴 add error:", error)  // <-- surface scheduling failures
    }

    print("📊 INTERPRETATION:")
    print("   • Rings: iOS settings fine → issue in main triage pipeline")
    print("   • Silent but banner shows: quiet delivery (provisional/Focus/Sounds off)")
    print("   • Nothing appears: authorization/scheduling issue")
  }

  /// Phase 5: Category registration check
  func dumpNotificationCategories() async {
    // Ensure activation first (idempotent)
    await MainActor.run {
      // Access the container to activate delegate
      print("🔄 Ensuring notification delegate is activated...")
    }

    let categories = await withCheckedContinuation { continuation in
      center.getNotificationCategories { categories in
        continuation.resume(returning: categories)
      }
    }

    print("🏷️  Registered notification categories:")
    if categories.isEmpty {
      print("  ❌ NO categories registered!")
    } else {
      for category in categories {
        print("  ✅ \(category.identifier)")
        if !category.actions.isEmpty {
          print("    Actions: \(category.actions.map(\.identifier).joined(separator: ", "))")
        }
      }
    }

    let hasAlarmCategory = categories.contains { $0.identifier == "ALARM_CATEGORY" }
    if !hasAlarmCategory {
      print("  ⚠️  ALARM_CATEGORY not found - willPresent may take non-alarm path!")
    }
  }

  /// Complete triage suite - run all phases
  func runCompleteSoundTriage() async throws {
    print("🚀 Starting Complete Sound Triage (Device Only)")
    print("📱 Reminder: Test on PHYSICAL DEVICE, not simulator!")
    print("🔧 Ensure: Sounds ON, Focus OFF, Summary OFF, Ring mode, Volume > 50%")
    print("")

    // Cancel any existing test requests first
    print("🧹 Canceling any existing test requests...")
    center.removeAllPendingNotificationRequests()

    // Check pending requests count
    let pendingRequests = await withCheckedContinuation { continuation in
      center.getPendingNotificationRequests { requests in
        continuation.resume(returning: requests)
      }
    }
    print("📊 Pending requests after cleanup: \(pendingRequests.count)")
    print("")

    print("== Phase 1: Settings Audit ==")
    await dumpNotificationSettings()
    print("")

    print("== Phase 2: Bundle Validation ==")
    validateSoundBundle()
    print("")

    print("== Phase 5: Category Check ==")
    await dumpNotificationCategories()
    print("")

    print("== Phase 3: A/B Sound Tests ==")
    print("🔄 Scheduling Test A (default) and Test B (custom)...")
    try await scheduleTestDefault()
    try await scheduleTestCustom()
    print("")

    print("🔒 LOCK YOUR DEVICE NOW!")
    print("🎵 Listen for: Test A at 5s, Test B at 11s (staggered)")
    print("")
    print("📊 SUCCESS MATRIX:")
    print("   • A rings, B silent → custom sound pipeline bug")
    print("   • Both silent, willPresent shows .sound → device settings (Focus/Summary/mute/volume/provisional)")
    print("   • Logger errors while locked → file protection/atomic swap/concurrency")
    print("")
    print("💡 REMEMBER: willPresent only proves foreground sound path; lock behavior = device settings")
    print("🔍 Check willPresent logs for delegate behavior during test")
  }

}


// MARK: - Notification Errors
enum NotificationError: Error, LocalizedError {
  case permissionDenied
  case schedulingFailed
  case systemLimitExceeded
  case invalidConfiguration

  var errorDescription: String? {
    switch self {
    case .permissionDenied:
      return "Notification permission is required to schedule alarms"
    case .schedulingFailed:
      return "Failed to schedule notification"
    case .systemLimitExceeded:
      return "Too many alarms scheduled. Please disable some alarms to add more."
    case .invalidConfiguration:
      return "Invalid alarm configuration - alarm time is in the past"
    }
  }
}

extension Notification.Name {
  static let alarmDidFire = Notification.Name("alarmDidFire")
}



