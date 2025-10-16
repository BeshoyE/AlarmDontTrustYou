//
//  ActiveAlarmDetector.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/8/25.
//  Detects active alarms from delivered notifications and routes to dismissal flow
//

import Foundation

/// Detects if any alarm is currently active (firing) based on delivered notifications
/// Uses protocol-based dependencies for testability
@MainActor
public final class ActiveAlarmDetector {
    private let deliveredNotificationsReader: DeliveredNotificationsReading
    private let activeAlarmPolicy: ActiveAlarmPolicyProviding
    private let dismissedRegistry: DismissedRegistry
    private let alarmStorage: PersistenceStore

    init(
        deliveredNotificationsReader: DeliveredNotificationsReading,
        activeAlarmPolicy: ActiveAlarmPolicyProviding,
        dismissedRegistry: DismissedRegistry,
        alarmStorage: PersistenceStore
    ) {
        self.deliveredNotificationsReader = deliveredNotificationsReader
        self.activeAlarmPolicy = activeAlarmPolicy
        self.dismissedRegistry = dismissedRegistry
        self.alarmStorage = alarmStorage
    }

    /// Check for any currently active alarm
    /// Returns (Alarm, OccurrenceKey) if an active alarm is found, nil otherwise
    func checkForActiveAlarm() async -> (Alarm, OccurrenceKey)? {
        let now = Date()

        // Get delivered notifications from the system
        let delivered = await deliveredNotificationsReader.getDeliveredNotifications()

        // Check each delivered notification to see if it's within the active window
        for notification in delivered {
            // Parse the identifier to extract alarm ID and occurrence key
            guard let alarmId = OccurrenceKeyFormatter.parseAlarmId(from: notification.identifier),
                  let occurrenceKey = OccurrenceKeyFormatter.parse(fromIdentifier: notification.identifier) else {
                continue
            }

            // Check if this occurrence has already been dismissed
            let occurrenceKeyString = OccurrenceKeyFormatter.key(from: occurrenceKey.date)
            if dismissedRegistry.isDismissed(alarmId: alarmId, occurrenceKey: occurrenceKeyString) {
                print("🔍 ActiveAlarmDetector: Skipping dismissed occurrence \(notification.identifier.prefix(50))...")
                continue
            }

            // Compute the active window for this occurrence
            let activeWindowSeconds = activeAlarmPolicy.activeWindowSeconds(for: alarmId, occurrenceKey: notification.identifier)
            let occurrenceDate = occurrenceKey.date
            let activeUntil = occurrenceDate.addingTimeInterval(activeWindowSeconds)

            // Check if we're currently within the active window
            if now >= occurrenceDate && now <= activeUntil {
                // Found an active alarm! Load the full alarm object
                do {
                    let alarms = try await alarmStorage.loadAlarms()
                    if let alarm = alarms.first(where: { $0.id == alarmId }) {
                        print("✅ ActiveAlarmDetector: Found active alarm \(alarmId.uuidString.prefix(8)) at occurrence \(occurrenceKeyString)")
                        return (alarm, occurrenceKey)
                    }
                } catch {
                    print("❌ ActiveAlarmDetector: Failed to load alarms: \(error)")
                }
            }
        }

        // No active alarms found
        return nil
    }
}
