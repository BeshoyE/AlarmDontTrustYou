//
//  AlarmKitScheduler.swift
//  alarmAppNew
//
//  iOS 26+ AlarmKit implementation of AlarmScheduling protocol.
//  Uses system alarms with native stop/snooze support.
//

import Foundation
import AlarmKit

/// AlarmKit-based implementation for iOS 26+
/// Uses domain UUIDs directly as AlarmKit IDs - no external mapping needed
@available(iOS 26.0, *)
final class AlarmKitScheduler: AlarmScheduling {
    private let presentationBuilder: AlarmPresentationBuilding
    private var hasActivated = false
    private var alarmStateObserver: Task<Void, Never>?

    // Internal error types for AlarmKit operations (private to this implementation)
    private enum InternalError: Error {
        case notAuthorized
        case schedulingFailed
        case alarmNotFound
        case invalidConfiguration
        case systemLimitExceeded
        case permissionDenied
        case ambiguousAlarmState
        case alreadyHandledBySystem
    }

    // Map internal errors to domain-level AlarmSchedulingError
    private func mapToDomainError(_ error: InternalError) -> AlarmSchedulingError {
        switch error {
        case .notAuthorized: return .notAuthorized
        case .schedulingFailed: return .schedulingFailed
        case .alarmNotFound: return .alarmNotFound
        case .invalidConfiguration: return .invalidConfiguration
        case .systemLimitExceeded: return .systemLimitExceeded
        case .permissionDenied: return .permissionDenied
        case .ambiguousAlarmState: return .ambiguousAlarmState
        case .alreadyHandledBySystem: return .alreadyHandledBySystem
        }
    }

    init(presentationBuilder: AlarmPresentationBuilding) {
        self.presentationBuilder = presentationBuilder
        // No OS work in init - activation is explicit
    }

    /// Activate the scheduler (idempotent)
    @MainActor
    func activate() async {
        guard !hasActivated else { return }

        // Observe alarm state changes from AlarmKit
        // AlarmManager.alarmUpdates provides an async sequence of alarm changes
        alarmStateObserver = Task {
            for await updatedAlarms in AlarmManager.shared.alarmUpdates {
                // alarmUpdates yields array of alarms, not single alarm
                for updatedAlarm in updatedAlarms {
                    await handleAlarmStateUpdate(updatedAlarm)
                }
            }
        }

        hasActivated = true
        print("AlarmKitScheduler: Activated with state observation")
    }

    /// One-time migration: reconcile AlarmKit daemon state with domain alarms
    /// Cancels orphaned alarms and schedules missing enabled alarms using domain UUIDs
    @MainActor
    func reconcileAlarmsAfterMigration(persisted: [Alarm]) async {
        let migrationKey = "AlarmKitIDMigrationDone.v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            print("AlarmKitScheduler: Migration already completed")
            return
        }

        print("AlarmKitScheduler: Starting migration reconciliation...")

        // 1) Fetch daemon state (what AlarmKit thinks is scheduled)
        let daemonAlarms: [AlarmKit.Alarm]
        do {
            daemonAlarms = try AlarmManager.shared.alarms
            print("AlarmKitScheduler: Found \(daemonAlarms.count) alarms in daemon")
        } catch {
            print("AlarmKitScheduler: Migration failed to fetch daemon alarms: \(error)")
            return
        }
        let daemonIDs = Set(daemonAlarms.map { $0.id })
        let persistedIDs = Set(persisted.map { $0.id })

        // 2) Cancel stale daemon alarms that aren't in our store (orphans from old mapping)
        let orphans = daemonIDs.subtracting(persistedIDs)
        for orphanID in orphans {
            do {
                try await AlarmManager.shared.cancel(id: orphanID)
                print("AlarmKitScheduler: Cancelled orphan daemon alarm \(orphanID)")
            } catch {
                print("AlarmKitScheduler: Failed to cancel orphan \(orphanID): \(error)")
            }
        }

        // 3) Schedule every enabled domain alarm missing from daemon (using domain UUID)
        for alarm in persisted where alarm.isEnabled {
            if !daemonIDs.contains(alarm.id) {
                do {
                    _ = try await schedule(alarm: alarm)
                    print("AlarmKitScheduler: Scheduled missing alarm \(alarm.id)")
                } catch {
                    print("AlarmKitScheduler: Failed to schedule \(alarm.id): \(error)")
                }
            } else {
                print("AlarmKitScheduler: Alarm \(alarm.id) already in daemon, skipping")
            }
        }

        // 4) Mark migration complete
        UserDefaults.standard.set(true, forKey: migrationKey)
        print("AlarmKitScheduler: Migration completed")
    }

    // MARK: - AlarmScheduling Protocol

    func requestAuthorizationIfNeeded() async throws {
        do {
            try await requestAuthorizationInternally()
        } catch let internalError as InternalError {
            throw mapToDomainError(internalError)
        }
    }

    private func requestAuthorizationInternally() async throws {
        switch AlarmManager.shared.authorizationState {
        case .notDetermined:
            let state = try await AlarmManager.shared.requestAuthorization()
            guard state == .authorized else {
                throw InternalError.notAuthorized
            }
            print("AlarmKitScheduler: Authorization granted")
        case .denied:
            print("AlarmKitScheduler: Authorization denied")
            throw InternalError.notAuthorized
        case .authorized:
            print("AlarmKitScheduler: Already authorized")
        @unknown default:
            throw InternalError.notAuthorized
        }
    }

    func schedule(alarm: Alarm) async throws -> String {
        // Public API: throws domain-level AlarmSchedulingError
        do {
            return try await scheduleInternal(alarm: alarm)
        } catch let internalError as InternalError {
            throw mapToDomainError(internalError)
        } catch {
            // Catch AlarmKit native errors and map to domain error
            print("AlarmKitScheduler: Schedule failed with AlarmKit error: \(error)")
            throw AlarmSchedulingError.schedulingFailed
        }
    }

    private func scheduleInternal(alarm: Alarm) async throws -> String {
        // Build schedule and presentation using our builder
        let schedule = try presentationBuilder.buildSchedule(from: alarm)
        let attributes = try presentationBuilder.buildPresentation(for: alarm)

        // Create AlarmConfiguration using the proper factory method
        // Note: AlarmConfiguration is a nested type under AlarmManager
        let config = AlarmManager.AlarmConfiguration.alarm(
            schedule: schedule,
            attributes: attributes,
            stopIntent: nil,  // No custom stop intent
            secondaryIntent: OpenForChallengeIntent(alarmID: alarm.id.uuidString),
            sound: .default  // Use default alarm sound
        )

        // Schedule the alarm through AlarmKit using domain UUID directly
        // AlarmKit uses the ID we provide - no separate external ID needed
        let _ = try await AlarmManager.shared.schedule(id: alarm.id, configuration: config)

        // Return domain UUID as string (AlarmKit will use this same ID)
        print("AlarmKitScheduler: Scheduled alarm \(alarm.id)")
        return alarm.id.uuidString
    }

    func cancel(alarmId: UUID) async {
        // Use domain UUID directly - AlarmKit uses the same ID we provided in schedule()
        do {
            try await AlarmManager.shared.cancel(id: alarmId)
            print("AlarmKitScheduler: Cancelled alarm \(alarmId)")
        } catch {
            print("AlarmKitScheduler: Error cancelling alarm: \(error)")
        }
    }

    func pendingAlarmIds() async -> [UUID] {
        // Query all alarms from AlarmKit (throwing property, not async)
        do {
            let alarms = try AlarmManager.shared.alarms
            // AlarmKit IDs are the same as our domain UUIDs - direct mapping
            return alarms.map { $0.id }
        } catch {
            print("AlarmKitScheduler: Error fetching alarms: \(error)")
            return []
        }
    }

    func stop(alarmId: UUID, intentAlarmId: UUID? = nil) async throws {
        // Public API: throws domain-level AlarmSchedulingError
        do {
            try stopInternal(alarmId: alarmId, intentAlarmId: intentAlarmId)
        } catch let internalError as InternalError {
            throw mapToDomainError(internalError)
        }
    }

    // MARK: - Private Stop Implementation

    private func stopInternal(alarmId: UUID, intentAlarmId: UUID?) throws {
        // Priority 1: Prefer the ID that actually fired (from OpenForChallengeIntent)
        if let firedId = intentAlarmId {
            do {
                try AlarmManager.shared.stop(id: firedId)
                print("AlarmKitScheduler: Stopped using intent-provided ID: \(firedId)")
                return
            } catch {
                print("AlarmKitScheduler: Intent ID \(firedId) failed with error: \(error)")
            }
        }

        // Priority 2: Post-migration path: domain UUID is the AlarmKit ID
        do {
            try AlarmManager.shared.stop(id: alarmId)
            print("AlarmKitScheduler: Stopped alarm \(alarmId) using domain UUID")
            return
        } catch {
            print("AlarmKitScheduler: Domain UUID \(alarmId) failed with error: \(error)")
        }

        // Priority 3: Scoped fallback - check what alarms exist and their states
        let alarms: [AlarmKit.Alarm]
        do {
            alarms = try AlarmManager.shared.alarms
            print("AlarmKitScheduler: Fallback - found \(alarms.count) alarms in daemon")
            for alarm in alarms {
                print("  - ID: \(alarm.id), State: \(alarm.state)")
            }
        } catch {
            print("AlarmKitScheduler: Failed to fetch alarms for fallback: \(error)")
            throw InternalError.alarmNotFound
        }

        // CRITICAL CHECK: Empty daemon means system auto-dismissed the alarm
        // This happens when app is foregrounded while alarm is alerting
        guard !alarms.isEmpty else {
            print("AlarmKitScheduler: [METRIC] event=alarm_already_handled_by_system alarm_id=\(alarmId) daemon_count=0")
            throw InternalError.alreadyHandledBySystem
        }

        let alerting = alarms.filter { $0.state == .alerting }
        print("AlarmKitScheduler: Found \(alerting.count) alerting alarms")

        guard alerting.count == 1 else {
            if alerting.count > 1 {
                print("AlarmKitScheduler: ERROR - \(alerting.count) alarms alerting, cannot determine which")
                throw InternalError.ambiguousAlarmState
            }
            print("AlarmKitScheduler: No alerting alarms - alarm may have auto-dismissed or timed out")
            throw InternalError.alarmNotFound
        }

        // Exactly one alarm alerting - safe to stop it
        try AlarmManager.shared.stop(id: alerting[0].id)
        print("AlarmKitScheduler: Stopped single alerting alarm \(alerting[0].id) (fallback)")
    }

    func transitionToCountdown(alarmId: UUID, duration: TimeInterval) async throws {
        // Use domain UUID directly - AlarmKit uses the same ID we provided in schedule()
        try AlarmManager.shared.countdown(id: alarmId)
        print("AlarmKitScheduler: Countdown transition initiated for \(alarmId)")
    }

    func reconcile(alarms: [Alarm], skipIfRinging: Bool) async {
        // Check for alerting alarms if skip flag set
        if skipIfRinging {
            do {
                let daemonAlarms = try AlarmManager.shared.alarms
                let hasAlerting = daemonAlarms.contains { $0.state == .alerting }
                if hasAlerting {
                    print("AlarmKitScheduler: Skipping reconcile - alarm is alerting")
                    return
                }
            } catch {
                // Log warning but CONTINUE - better to reconcile than skip entirely
                // Worst case: we reconcile while alarm is ringing (safe - won't cancel it)
                print("AlarmKitScheduler: Warning - couldn't check alerting state: \(error)")
                print("AlarmKitScheduler: Continuing with reconciliation (safe)")
                // Don't return - fall through to reconcile
            }
        }

        // Fetch current daemon state
        let daemonAlarms: [AlarmKit.Alarm]
        do {
            daemonAlarms = try AlarmManager.shared.alarms
            print("AlarmKitScheduler: Reconcile - daemon has \(daemonAlarms.count) alarms")
        } catch {
            print("AlarmKitScheduler: Reconcile failed to fetch daemon: \(error)")
            return
        }

        // Build daemon map by UUID
        let daemonMap = Dictionary(uniqueKeysWithValues: daemonAlarms.map { ($0.id, $0) })

        // For each ENABLED domain alarm: ensure it exists in daemon
        for alarm in alarms where alarm.isEnabled {
            if daemonMap[alarm.id] == nil {
                do {
                    _ = try await schedule(alarm: alarm)
                    print("AlarmKitScheduler: Reconcile - scheduled missing \(alarm.id)")
                } catch {
                    print("AlarmKitScheduler: Reconcile - failed to schedule \(alarm.id): \(error)")
                }
            }
        }

        // For each DISABLED domain alarm: ensure it's NOT in daemon
        for alarm in alarms where !alarm.isEnabled {
            if daemonMap[alarm.id] != nil {
                await cancel(alarmId: alarm.id)
            }
        }

        // Cancel orphans: daemon alarms not in persisted set
        let persistedIDs = Set(alarms.map { $0.id })
        for (daemonID, _) in daemonMap where !persistedIDs.contains(daemonID) {
            await cancel(alarmId: daemonID)
        }

        print("AlarmKitScheduler: Reconcile complete")
    }

    // MARK: - Private Helpers

    private func handleAlarmStateUpdate(_ alarm: AlarmKit.Alarm) async {
        // Sync alarm state with our internal storage
        // Note: Using AlarmKit.Alarm to disambiguate from our domain Alarm type
        // AlarmKit ID is the same as our domain UUID - no mapping needed
        print("AlarmKitScheduler: State update for alarm \(alarm.id): \(alarm.state)")
        // Future: Could notify ViewModels or update local storage here
    }

    deinit {
        // Cancel the observation task when scheduler is deallocated
        alarmStateObserver?.cancel()
    }
}
