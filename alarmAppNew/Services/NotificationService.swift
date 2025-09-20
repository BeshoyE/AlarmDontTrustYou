//
//  NotificationService.swift
//  alarmAppNew
//
//  Created by Beshoy Eskarous on 7/7/25.
//

import UserNotifications
import SwiftUI
import UIKit

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
  func cancelAlarm(_ alarm: Alarm)
  func cancelSpecificNotifications(for alarmId: UUID, types: [NotificationType])
  func refreshAll(from alarms: [Alarm]) async
  func pendingAlarmIds() async -> [UUID]
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
}

enum NotificationType: String, CaseIterable {
  case main = "main"
  case preAlarm = "pre_alarm"
  case nudge1 = "nudge_1"
  case nudge2 = "nudge_2"
  case nudge3 = "nudge_3"
}

class NotificationService: NSObject, NotificationScheduling, UNUserNotificationCenterDelegate {
  private let center = UNUserNotificationCenter.current()
  private let permissionService: PermissionServiceProtocol
  private let appStateProvider: AppStateProviding
  private let reliabilityLogger: ReliabilityLogging
  private let appRouter: AppRouter
  private let persistenceService: AlarmStorage

  init(permissionService: PermissionServiceProtocol, appStateProvider: AppStateProviding, reliabilityLogger: ReliabilityLogging, appRouter: AppRouter, persistenceService: AlarmStorage) {
    self.permissionService = permissionService
    self.appStateProvider = appStateProvider
    self.reliabilityLogger = reliabilityLogger
    self.appRouter = appRouter
    self.persistenceService = persistenceService
    super.init()
  }

  func ensureNotificationCategoriesRegistered() {
    setupNotificationCategories()
    print("NotificationService: Categories registered/re-registered")
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
    // Build actions
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

    // Build category
    let alarmCategory = UNNotificationCategory(
      identifier: "ALARM_CATEGORY",
      actions: [openAction, returnToDismissalAction, snoozeAction],
      intentIdentifiers: [],
      options: [.customDismissAction]
    )

    // Register categories
    center.setNotificationCategories([alarmCategory])
  }

  @MainActor
  private func presentRingingWhenReady(_ id: UUID) async {
    for _ in 0..<10 {
      if let s = UIApplication.shared.connectedScenes.first as? UIWindowScene,
         s.activationState == .foregroundActive { break }
      try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
    }
    appRouter.showRinging(for: id)
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

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let content = notification.request.content

    // Phase 4: Enhanced delegate logging with exactly-once completion handler
    var completed = false
    defer {
      assert(completed, "completionHandler must be called exactly once")
    }

    print("📥 willPresent: id=\(notification.request.identifier) cat=\(content.categoryIdentifier) userInfo=\(content.userInfo)")

    let isAlarmCategory = content.categoryIdentifier == "ALARM_CATEGORY"

    // Early validation for ALARM_CATEGORY notifications
    if isAlarmCategory {
      guard let alarmIdString = content.userInfo["alarmId"] as? String,
            let alarmId = UUID(uuidString: alarmIdString) else {
        print("🔔 ❌ Missing or invalid alarmId in alarm notification")
        reliabilityLogger.log(
          .notificationsStatusChanged,
          alarmId: nil,
          details: ["error": "missing_alarmId", "userInfo": String(describing: content.userInfo)]
        )
        completed = true
        completionHandler([])
        return
      }

      // For alarm notifications, ALWAYS allow sound regardless of app state
      print("🔔 Alarm category detected - ALWAYS allowing [.banner, .list, .sound] for reliable wake-up")
      reliabilityLogger.log(
        .notificationsStatusChanged,
        alarmId: alarmId,
        details: ["event": "willPresent_alarm", "presentation": "allowed"]
      )

      completed = true
      completionHandler([.banner, .list, .sound])
      print("✅ willPresent → [.banner,.list,.sound]")

      // Route to enforced ringing flow for alarm handling
      Task {
        await MainActor.run {
          print("NotificationService: Routing to ringing for alarm: \(alarmId)")
        }

        // Check if this is a test notification
        if let typeString = content.userInfo["type"] as? String, typeString.contains("test") {
          // For test notifications, try to present ringing but handle gracefully if alarm not found
          await presentRingingWhenReady(alarmId)
          // Note: presentRingingWhenReady handles missing alarms gracefully in AppRouter
        } else {
          // For real alarms, always try to present
          await presentRingingWhenReady(alarmId)
        }

        // Log the event
        await MainActor.run {
          reliabilityLogger.logAlarmFired(alarmId, details: ["source": "willPresent"])
        }
      }
    } else {
      // For non-alarm notifications, use default behavior
      print("ℹ️ Non-alarm notification - using default presentation")
      completed = true
      completionHandler([.banner, .list])
      print("ℹ️ willPresent → non-alarm default")
    }
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    let content = response.notification.request.content

    // Early validation - ensure this is an ALARM_CATEGORY notification with valid userInfo
    guard content.categoryIdentifier == "ALARM_CATEGORY" else {
      reliabilityLogger.log(
        .notificationsStatusChanged,
        alarmId: nil,
        details: ["error": "invalid_category", "category": content.categoryIdentifier, "action": response.actionIdentifier]
      )
      completionHandler()
      return
    }

    guard let alarmIdString = content.userInfo["alarmId"] as? String,
          let alarmId = UUID(uuidString: alarmIdString) else {
      reliabilityLogger.log(
        .notificationsStatusChanged,
        alarmId: nil,
        details: ["error": "missing_alarmId", "userInfo": String(describing: content.userInfo), "action": response.actionIdentifier]
      )
      completionHandler()
      return
    }

    print("NotificationService: didReceive response for alarm: \(alarmId), action: \(response.actionIdentifier)")

    switch response.actionIdentifier {
    case UNNotificationDefaultActionIdentifier, "OPEN_ALARM", "RETURN_TO_DISMISSAL":
      // Route to dismissal flow (guaranteed main thread)
      Task { @MainActor in
        print("NotificationService: Routing to ringing from notification tap/action for alarm: \(alarmId)")
        await presentRingingWhenReady(alarmId)

        // Log the event
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

    completionHandler()
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

  func cancelAlarm(_ alarm: Alarm) {
    let allIdentifiers = generateAllNotificationIdentifiers(for: alarm)

    // Remove pending notifications
    center.removePendingNotificationRequests(withIdentifiers: allIdentifiers)

    // Remove delivered notifications
    Task {
      await removeDeliveredNotifications(for: alarm.id, types: NotificationType.allCases)
    }
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

  func refreshAll(from alarms: [Alarm]) async {
    // Cancel all pending notifications
    center.removeAllPendingNotificationRequests()

    // Re-schedule all enabled alarms
    for alarm in alarms where alarm.isEnabled {
      do {
        try await scheduleAlarm(alarm)
      } catch {
        print("Failed to schedule alarm \(alarm.id): \(error)")
      }
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

    // Generate exact expected identifiers using the same logic as scheduling
    let expectedIdentifiers = generateExpectedIdentifiers(for: alarmId, types: types)

    // Find delivered notifications that match our exact identifiers
    var identifiersToRemove: [String] = []
    for notification in deliveredNotifications {
      let identifier = notification.request.identifier
      if expectedIdentifiers.contains(identifier) {
        identifiersToRemove.append(identifier)
      }
    }

    if !identifiersToRemove.isEmpty {
      center.removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
      print("NotificationService: Removed \(identifiersToRemove.count) delivered notifications for alarm \(alarmId)")
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
    content.userInfo = ["alarmId": testAlarmId.uuidString, "type": "test_default"]
    content.categoryIdentifier = "ALARM_CATEGORY"

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
    content.userInfo = ["alarmId": testAlarmId.uuidString, "type": "test_critical"]
    content.categoryIdentifier = "ALARM_CATEGORY"

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

    content.userInfo = ["alarmId": testAlarmId.uuidString, "type": "test_custom"]
    content.categoryIdentifier = "ALARM_CATEGORY"

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
    content.categoryIdentifier = "ALARM_CATEGORY"
    content.userInfo = ["alarmId": id.uuidString, "type": type]

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
    content.categoryIdentifier = "ALARM_CATEGORY"
    content.userInfo = ["alarmId": id.uuidString, "type": "test_custom"]

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

    // 2) Register a simple category
    let cat = UNNotificationCategory(identifier: "TEST_CAT", actions: [], intentIdentifiers: [], options: [])
    center.setNotificationCategories([cat])

    // 3) Minimal content with default sound
    let content = UNMutableNotificationContent()
    content.title = "🔔 Bare Default Test"
    content.body = "Should ring with default sound on lock"
    content.sound = .default
    content.categoryIdentifier = "TEST_CAT"
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

    // 2) Register a simple category
    let cat = UNNotificationCategory(identifier: "TEST_CAT", actions: [], intentIdentifiers: [], options: [])
    center.setNotificationCategories([cat])

    // 3) Minimal content with default sound - NO interruptionLevel set
    let content = UNMutableNotificationContent()
    content.title = "🔔 Bare Default Test (No Interruption)"
    content.body = "Should ring with default sound on lock"
    content.sound = .default
    content.categoryIdentifier = "TEST_CAT"
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

  var errorDescription: String? {
    switch self {
    case .permissionDenied:
      return "Notification permission is required to schedule alarms"
    case .schedulingFailed:
      return "Failed to schedule notification"
    }
  }
}

extension Notification.Name {
  static let alarmDidFire = Notification.Name("alarmDidFire")
}



