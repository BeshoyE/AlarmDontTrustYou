//
//  ChainedNotificationScheduler.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/1/25.
//

import Foundation
import UserNotifications
import UIKit
import os.log
import os.signpost

// MARK: - Protocol Definition

public protocol ChainedNotificationScheduling {
    func scheduleChain(for alarm: Alarm, fireDate: Date) async -> ScheduleOutcome
    func cancelChain(alarmId: UUID) async
    func cancelOccurrence(alarmId: UUID, occurrenceKey: String) async
    func getIdentifiers(alarmId: UUID) -> [String]
    func getAllTrackedIdentifiers() -> Set<String>
    func requestAuthorization() async throws
    func cleanupStaleChains() async
}

// MARK: - Implementation

public final class ChainedNotificationScheduler: ChainedNotificationScheduling {
    private let notificationCenter: UNUserNotificationCenter
    private let soundCatalog: SoundCatalogProviding
    private let notificationIndex: NotificationIndexProviding
    private let chainPolicy: ChainPolicy
    private let globalLimitGuard: GlobalLimitGuard
    private let clock: Clock

    private let log = OSLog(subsystem: "alarmAppNew", category: "ChainedNotificationScheduler")
    private let signpostLog = OSLog(subsystem: "alarmAppNew", category: "ChainScheduling")

    public init(
        notificationCenter: UNUserNotificationCenter = .current(),
        soundCatalog: SoundCatalogProviding,
        notificationIndex: NotificationIndexProviding,
        chainPolicy: ChainPolicy,
        globalLimitGuard: GlobalLimitGuard = GlobalLimitGuard(),
        clock: Clock = SystemClock()
    ) {
        self.notificationCenter = notificationCenter
        self.soundCatalog = soundCatalog
        self.notificationIndex = notificationIndex
        self.chainPolicy = chainPolicy
        self.globalLimitGuard = globalLimitGuard
        self.clock = clock
    }

    // MARK: - Public Interface

    public func scheduleChain(for alarm: Alarm, fireDate: Date) async -> ScheduleOutcome {
        let signpostID = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "ScheduleBatch",
                   signpostID: signpostID, "alarmId=%@", alarm.id.uuidString)
        defer {
            os_signpost(.end, log: signpostLog, name: "ScheduleBatch", signpostID: signpostID)
        }

        // Step 1: Compute anchor and base interval (use single clock reading)
        let now = clock.now()
        let minLeadTime = TimeInterval(chainPolicy.settings.minLeadTimeSec)
        let anchor = fireDate  // Domain-determined alarm time (must be strictly future)

        // ANCHOR INTEGRITY: Log received anchor for comparison with Domain
        os_log("SCHED received_anchor: %@ for alarm %@",
               log: log, type: .info,
               anchor.ISO8601Format(), alarm.id.uuidString.prefix(8).description)

        // Guard: Domain should never give us a past anchor
        guard anchor > now else {
            os_log("ANCHOR_PAST_GUARD: Domain gave past anchor for alarm %@: anchor=%@ now=%@",
                   log: log, type: .error, alarm.id.uuidString,
                   anchor.ISO8601Format(), now.ISO8601Format())
            return .unavailable(reason: .invalidConfiguration)
        }

        // Calculate interval respecting both domain decision and lead time
        let deltaFromNow = anchor.timeIntervalSince(now)
        // Use ceil to avoid pre-anchor fires, then apply minimum constraints
        let baseInterval = max(ceil(deltaFromNow), minLeadTime, 1.0)  // ceil prevents early fire, 1.0 is iOS minimum

        // Log the timing calculation for debugging
        os_log("Chain timing for alarm %@: anchor=%@ now=%@ delta=%.1fs leadTime=%.1fs baseInterval=%.1fs",
               log: log, type: .info, alarm.id.uuidString,
               anchor.ISO8601Format(), now.ISO8601Format(), deltaFromNow, minLeadTime, baseInterval)

        // Step 2: Check permissions
        let authStatus = await notificationCenter.notificationSettings().authorizationStatus
        guard authStatus == .authorized else {
            os_log("Notifications not authorized (status: %@) for alarm %@",
                   log: log, type: .error, String(describing: authStatus), alarm.id.uuidString)
            return .unavailable(reason: .permissions)
        }

        // Step 3: Compute chain with aggressive spacing
        // Use fallback spacing for all alarms (aggressive wake-up mode)
        // Sound duration is irrelevant for notification timing - we want rapid alerts
        let spacingSeconds = TimeInterval(chainPolicy.settings.fallbackSpacingSec)
        let chainConfig = chainPolicy.computeChain(spacingSeconds: Int(spacingSeconds))

        let soundInfo = soundCatalog.safeInfo(for: alarm.soundId)

        os_log("Chain config for alarm %@: spacing=%.0fs count=%d (sound: %@)",
               log: log, type: .info, alarm.id.uuidString, spacingSeconds,
               chainConfig.chainCount, soundInfo?.name ?? "fallback")

        // Step 4: Reserve slots atomically
        guard let reservedCount = await reserveSlots(requestedCount: chainConfig.chainCount),
              reservedCount > 0 else {
            os_log("No available slots for alarm %@ (requested: %d)",
                   log: log, type: .error, alarm.id.uuidString, chainConfig.chainCount)
            #if DEBUG
            print("🔍 [DIAG] Reservation FAILED: requested=\(chainConfig.chainCount) granted=0")
            #endif
            return .unavailable(reason: .globalLimit)
        }

        #if DEBUG
        print("🔍 [DIAG] Reservation SUCCESS: requested=\(chainConfig.chainCount) granted=\(reservedCount)")
        #endif

        defer {
            // Finalize is now async (actor method), must wrap in Task
            Task { await globalLimitGuard.finalize(reservedCount) }
        }

        // Step 5: Compute final chain configuration
        let finalConfig = chainConfig.trimmed(to: reservedCount)

        // Step 6: Cancel existing chain and schedule new one
        let outcome = await performIdempotentReschedule(
            alarm: alarm,
            anchor: anchor,
            start: anchor,  // Use anchor as start - domain has decided the time
            baseInterval: baseInterval,
            spacing: spacingSeconds,
            chainCount: finalConfig.chainCount,
            originalCount: chainConfig.chainCount
        )

        // Log the final outcome
        logScheduleOutcome(outcome, alarm: alarm, fireDate: fireDate)

        return outcome
    }

    public func cancelChain(alarmId: UUID) async {
        os_log("Cancelling notification chain for alarm %@", log: log, type: .info, alarmId.uuidString)

        let identifiers = notificationIndex.loadIdentifiers(alarmId: alarmId)

        if !identifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
            notificationIndex.clearIdentifiers(alarmId: alarmId)
            notificationIndex.clearChainMeta(alarmId: alarmId)

            os_log("Cancelled %d notifications for alarm %@",
                   log: log, type: .info, identifiers.count, alarmId.uuidString)
        }
    }

    public func cancelOccurrence(alarmId: UUID, occurrenceKey: String) async {
        os_log("Cancelling occurrence %@ for alarm %@", log: log, type: .info,
               String(occurrenceKey.prefix(10)), alarmId.uuidString)

        let allIdentifiers = notificationIndex.loadIdentifiers(alarmId: alarmId)
        let matchingIdentifiers = allIdentifiers.filter { identifier in
            identifier.contains("-occ-\(occurrenceKey)-")
        }

        if !matchingIdentifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: matchingIdentifiers)
            let remainingIdentifiers = allIdentifiers.filter { !matchingIdentifiers.contains($0) }
            notificationIndex.saveIdentifiers(alarmId: alarmId, identifiers: remainingIdentifiers)

            os_log("Cancelled %d occurrence notifications for alarm %@, %d remaining",
                   log: log, type: .info, matchingIdentifiers.count, alarmId.uuidString,
                   remainingIdentifiers.count)
        } else {
            os_log("No matching occurrence notifications found for %@",
                   log: log, type: .info, String(occurrenceKey.prefix(10)))
        }
    }

    public func getIdentifiers(alarmId: UUID) -> [String] {
        return notificationIndex.loadIdentifiers(alarmId: alarmId)
    }

    public func getAllTrackedIdentifiers() -> Set<String> {
        var allIdentifiers = Set<String>()
        let allAlarmIds = notificationIndex.allTrackedAlarmIds()
        for alarmId in allAlarmIds {
            let ids = notificationIndex.loadIdentifiers(alarmId: alarmId)
            allIdentifiers.formUnion(ids)
        }
        return allIdentifiers
    }

    public func requestAuthorization() async throws {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]

        do {
            let granted = try await notificationCenter.requestAuthorization(options: options)

            if !granted {
                os_log("Notification authorization denied by user", log: log, type: .error)
                throw NotificationSchedulingError.authorizationDenied
            }

            os_log("Notification authorization granted", log: log, type: .info)
        } catch {
            os_log("Authorization request failed: %@", log: log, type: .error, error.localizedDescription)
            throw error
        }
    }

    public func cleanupStaleChains() async {
        os_log("Starting stale chain cleanup", log: log, type: .info)

        let now = clock.now()
        let allAlarmIds = notificationIndex.allTrackedAlarmIds()
        let gracePeriod = TimeInterval(chainPolicy.settings.cleanupGraceSec)

        var totalStale = 0
        var skippedNoMeta = 0

        for alarmId in allAlarmIds {
            // Load persisted metadata
            guard let meta = notificationIndex.loadChainMeta(alarmId: alarmId) else {
                // No metadata = cannot determine staleness accurately
                // Skip to avoid false positives during migration
                skippedNoMeta += 1
                os_log("Skipping cleanup for alarm %@ (no metadata)",
                       log: log, type: .info, alarmId.uuidString)
                continue
            }

            // Calculate actual chain end using persisted values
            // Last notification fires at: start + (count - 1) * spacing
            let lastFireTime = meta.start.addingTimeInterval(Double(meta.count - 1) * meta.spacing)
            let cleanupTime = lastFireTime.addingTimeInterval(gracePeriod)

            // Only remove if truly stale
            if now > cleanupTime {
                let identifiers = notificationIndex.loadIdentifiers(alarmId: alarmId)

                if !identifiers.isEmpty {
                    notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
                    notificationIndex.removeIdentifiers(alarmId: alarmId, identifiers: identifiers)
                    notificationIndex.clearChainMeta(alarmId: alarmId)
                    totalStale += identifiers.count

                    os_log("Cleaned up %d stale notifications for alarm %@ (start: %@, lastFire: %@, cleanup: %@)",
                           log: log, type: .info, identifiers.count, alarmId.uuidString,
                           meta.start.ISO8601Format(), lastFireTime.ISO8601Format(), cleanupTime.ISO8601Format())
                }
            } else {
                os_log("Chain for alarm %@ not stale yet (cleanup time: %@, now: %@)",
                       log: log, type: .debug, alarmId.uuidString,
                       cleanupTime.ISO8601Format(), now.ISO8601Format())
            }
        }

        if skippedNoMeta > 0 {
            os_log("Skipped %d alarms without metadata during cleanup",
                   log: log, type: .info, skippedNoMeta)
        }

        os_log("Stale chain cleanup complete: removed %d notifications, skipped %d without metadata",
               log: log, type: .info, totalStale, skippedNoMeta)
    }

    // MARK: - Private Implementation

    private func reserveSlots(requestedCount: Int) async -> Int? {
        let granted = await globalLimitGuard.reserve(requestedCount)

        if granted == 0 {
            return nil
        }

        return granted
    }

    private func performIdempotentReschedule(
        alarm: Alarm,
        anchor: Date,
        start: Date,
        baseInterval: TimeInterval,
        spacing: TimeInterval,
        chainCount: Int,
        originalCount: Int
    ) async -> ScheduleOutcome {
        // Generate expected identifiers using anchor (stable identity)
        let occurrenceKey = OccurrenceKeyFormatter.key(from: anchor)
        let expectedIdentifiers = (0..<chainCount).map { index in
            return "alarm-\(alarm.id.uuidString)-occ-\(occurrenceKey)-\(index)"
        }

        // CRITICAL OBSERVABILITY: Log scheduling start
        let now = clock.now()
        let intervals = (0..<chainCount).map { index in
            Int(baseInterval + Double(index) * spacing)
        }
        os_log("SCHED start: alarmId=%@ occurrenceKey=%@ now=%@ anchor=%@ deltaSec=%d intervals=%@",
               log: log, type: .info,
               alarm.id.uuidString.prefix(8).description,
               occurrenceKey,
               now.ISO8601Format(),
               anchor.ISO8601Format(),
               Int(anchor.timeIntervalSince(now)),
               intervals.description)

        var scheduledCount = 0

        // Wrap scheduling in background task to prevent cancellation on app background
        var backgroundTask: UIBackgroundTaskIdentifier = .invalid
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "ScheduleAlarm-\(alarm.id.uuidString)") {
            // Expiration handler: clean up if system force-terminates
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        }

        // Clear existing identifiers and schedule new ones atomically
        notificationIndex.clearIdentifiers(alarmId: alarm.id)
        scheduledCount = await scheduleNotificationRequests(
            alarm: alarm,
            anchor: anchor,
            identifiers: expectedIdentifiers,
            baseInterval: baseInterval,
            spacing: spacing,
            start: start
        )
        notificationIndex.saveIdentifiers(alarmId: alarm.id, identifiers: expectedIdentifiers)

        // Save chain metadata for accurate cleanup later
        let meta = ChainMeta(
            start: start,  // Use the actual start time that was computed and used for scheduling
            spacing: spacing,
            count: chainCount,
            createdAt: clock.now()
        )
        notificationIndex.saveChainMeta(alarmId: alarm.id, meta: meta)

        // CRITICAL: End background task on all paths (success/failure handled above)
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }

        // Determine outcome type
        if originalCount > chainCount {
            return .trimmed(original: originalCount, scheduled: scheduledCount)
        } else {
            return .scheduled(count: scheduledCount)
        }
    }

    private func scheduleNotificationRequests(
        alarm: Alarm,
        anchor: Date,
        identifiers: [String],
        baseInterval: TimeInterval,
        spacing: TimeInterval,
        start: Date
    ) async -> Int {
        // Idempotent: Remove any existing notifications for this occurrence before adding new ones
        let occurrenceKey = OccurrenceKeyFormatter.key(from: anchor)

        // SERIALIZE: Await removal completion before adding to prevent race conditions
        await withCheckedContinuation { continuation in
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
            // Give the system a moment to process the removal
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                continuation.resume()
            }
        }

        os_log("Idempotent: Removed existing requests for occurrence %@ (count=%d)",
               log: log, type: .info, occurrenceKey, identifiers.count)

        // Log comprehensive scheduling info
        os_log("Scheduling chain: baseInterval=%.1fs spacing=%.1fs count=%d for alarm %@",
               log: log, type: .info, baseInterval, spacing, identifiers.count, alarm.id.uuidString)

        var successCount = 0

        for (index, identifier) in identifiers.enumerated() {
            // Calculate interval for this notification: base + index * spacing
            let interval = baseInterval + Double(index) * spacing

            do {
                let request = try buildNotificationRequest(
                    alarm: alarm,
                    anchor: anchor,
                    identifier: identifier,
                    occurrence: index,
                    interval: interval,
                    start: start,
                    isFirst: index == 0
                )

                // Add request and log result
                do {
                    try await notificationCenter.add(request)
                    successCount += 1

                    // CRITICAL OBSERVABILITY: Log successful add
                    os_log("SCHED added: id=%@ (notification %d/%d)",
                           log: log, type: .info,
                           identifier, index + 1, identifiers.count)
                } catch {
                    // CRITICAL OBSERVABILITY: Log add error
                    os_log("SCHED add_error: %@ for id=%@",
                           log: log, type: .error,
                           error.localizedDescription, identifier)
                    #if DEBUG
                    assertionFailure("Notification scheduling failed: \(error)")
                    #endif
                }

            } catch {
                os_log("Failed to build notification request %@: %@",
                       log: log, type: .error, identifier, error.localizedDescription)
                #if DEBUG
                assertionFailure("Notification request building failed: \(error)")
                #endif
            }
        }

        // CRITICAL: Immediate post-schedule verification
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let ourPending = pendingRequests.filter { identifiers.contains($0.identifier) }
        let pendingIds = ourPending.map { $0.identifier }

        // CRITICAL OBSERVABILITY: Log post-check
        os_log("SCHED post_check: pendingCount=%d ids=%@",
               log: log, type: .info,
               ourPending.count, pendingIds.description)

        // ASSERT: pendingCount must equal chainLength
        if ourPending.count != identifiers.count {
            os_log("❌ SCHEDULING FAILURE: Expected %d notifications but only %d are pending for alarm %@",
                   log: log, type: .fault,  // Use .fault for critical failures
                   identifiers.count, ourPending.count, alarm.id.uuidString)
        }

        return successCount
    }

    private func buildNotificationRequest(
        alarm: Alarm,
        anchor: Date,
        identifier: String,
        occurrence: Int,
        interval: TimeInterval,
        start: Date,
        isFirst: Bool
    ) throws -> UNNotificationRequest {
        // Build content
        let content = UNMutableNotificationContent()
        content.title = "Alarm"
        content.body = alarm.label.isEmpty ? "Alarm" : alarm.label
        content.sound = buildNotificationSound(alarm: alarm) // Use alarm's custom sound from catalog
        content.categoryIdentifier = "ALARM_CATEGORY"

        // Add userInfo with alarmId and occurrenceKey for occurrence-scoped cancellation
        // Use anchor for stable identity (not shifted time)
        let occurrenceKey = OccurrenceKeyFormatter.key(from: anchor)
        content.userInfo = [
            "alarmId": alarm.id.uuidString,
            "occurrenceKey": occurrenceKey
        ]

        // ALWAYS use interval trigger to avoid calendar race conditions
        // Clamp to iOS minimum (1 second) to ensure future scheduling
        let clampedInterval = max(1.0, interval)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: clampedInterval, repeats: false)

        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    private func buildNotificationSound(alarm: Alarm) -> UNNotificationSound {
        // safeInfo already provides fallback to default sound if ID is invalid
        let soundInfo = soundCatalog.safeInfo(for: alarm.soundId)
        let fileName = soundInfo?.fileName ?? "ringtone1.caf"  // Fallback to actual file name, not "default"
        return UNNotificationSound(named: UNNotificationSoundName(fileName))
    }

    internal func buildTriggerWithInterval(_ interval: TimeInterval) -> UNNotificationTrigger {
        // Only clamp to iOS minimum (1 second), no per-item min lead time
        let clampedInterval = max(1.0, interval)
        return UNTimeIntervalNotificationTrigger(timeInterval: clampedInterval, repeats: false)
    }

    private func logScheduleOutcome(_ outcome: ScheduleOutcome, alarm: Alarm, fireDate: Date) {
        switch outcome {
        case .scheduled(let count):
            os_log("Successfully scheduled %d notifications for alarm %@ at %@",
                   log: log, type: .info, count, alarm.id.uuidString, fireDate.description)

        case .trimmed(let original, let scheduled):
            os_log("Trimmed chain for alarm %@: %d -> %d notifications (global limit)",
                   log: log, type: .info, alarm.id.uuidString, original, scheduled)

        case .unavailable(let reason):
            let reasonString = String(describing: reason)
            os_log("Failed to schedule notifications for alarm %@: %@",
                   log: log, type: .error, alarm.id.uuidString, reasonString)
        }
    }
}

// MARK: - Error Types

public enum NotificationSchedulingError: Error {
    case authorizationDenied
    case invalidConfiguration
    case systemLimitExceeded
}

extension NotificationSchedulingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Notification permissions are required to schedule alarms"
        case .invalidConfiguration:
            return "Invalid notification configuration"
        case .systemLimitExceeded:
            return "Too many notifications already scheduled"
        }
    }
}