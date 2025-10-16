//
//  AlarmIntentBridge.swift
//  alarmAppNew
//
//  Bridge for observing and routing alarm intents from app group.
//  No singletons, idempotent operation, clean separation of concerns.
//

import Foundation
import SwiftUI

/// Bridge for handling alarm intents written to app group by OpenForChallengeIntent
@MainActor
final class AlarmIntentBridge: ObservableObject {
    /// Currently pending alarm ID detected from intent
    @Published private(set) var pendingAlarmId: UUID?

    /// App group identifier matching the one used by OpenForChallengeIntent
    private static let appGroupIdentifier = "group.com.beshoy.alarmAppNew"

    /// Shared defaults for reading intent data
    private let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)

    /// Keys used for storing intent data
    private enum Keys {
        static let pendingAlarmIntent = "pendingAlarmIntent"
        static let pendingAlarmIntentTimestamp = "pendingAlarmIntentTimestamp"
    }

    /// Maximum age of intent timestamp to consider valid (30 seconds)
    private let maxIntentAge: TimeInterval = 30

    init() {
        // No OS work in initializer - keeps it pure
    }

    /// Check for pending alarm intent in app group and route if valid
    /// This method is idempotent and safe to call repeatedly
    func checkForPendingIntent() {
        guard let sharedDefaults = sharedDefaults else {
            // App group not configured - expected in dev/test
            return
        }

        // Read intent data from app group
        guard let alarmIdString = sharedDefaults.string(forKey: Keys.pendingAlarmIntent),
              let timestamp = sharedDefaults.object(forKey: Keys.pendingAlarmIntentTimestamp) as? Date else {
            // No pending intent
            return
        }

        // Validate timestamp freshness
        let age = abs(timestamp.timeIntervalSinceNow)
        guard age <= maxIntentAge else {
            // Intent is too old - clear it and ignore
            clearPendingIntent()
            print("AlarmIntentBridge: Ignoring stale intent (age: \(Int(age))s)")
            return
        }

        // Parse alarm ID
        guard let alarmId = UUID(uuidString: alarmIdString) else {
            print("AlarmIntentBridge: Invalid alarm ID format: \(alarmIdString)")
            clearPendingIntent()
            return
        }

        // Update published property
        pendingAlarmId = alarmId

        // Clear the intent data (consumed)
        clearPendingIntent()

        // Post notification for routing
        // Pass the intent's alarm ID (which could be pre-migration) as the intent ID
        NotificationCenter.default.post(
            name: .alarmIntentReceived,
            object: nil,
            userInfo: ["intentAlarmId": alarmId]
        )

        print("AlarmIntentBridge: Processing intent for alarm \(alarmId.uuidString.prefix(8))...")
    }

    /// Clear pending intent data from app group
    private func clearPendingIntent() {
        sharedDefaults?.removeObject(forKey: Keys.pendingAlarmIntent)
        sharedDefaults?.removeObject(forKey: Keys.pendingAlarmIntentTimestamp)
    }
}