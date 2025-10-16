//
//  OpenForChallengeIntent.swift
//  alarmAppNew
//
//  App Intent for AlarmKit integration (iOS 26+).
//  Pure payload handoff to app group - no routing, no DI, no singletons.
//

import AppIntents
import Foundation

@available(iOS 26.0, *)
struct OpenForChallengeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open for Challenge"
    static var description = IntentDescription("Opens the app to show alarm challenge dismissal flow")

    // When true, the app will open when this intent runs
    static var openAppWhenRun: Bool = true

    // Parameter for the alarm ID to be handled
    @Parameter(title: "Alarm ID")
    var alarmID: String

    // App group identifier for shared data
    private static let appGroupIdentifier = "group.com.beshoy.alarmAppNew"

    init() {}

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        // Pure data handoff to app group
        guard let sharedDefaults = UserDefaults(suiteName: Self.appGroupIdentifier) else {
            // Silently fail if app group is not configured
            // The app will not receive the intent, but that's expected in dev/test
            return .result()
        }

        // Write alarm ID and timestamp to shared defaults
        sharedDefaults.set(alarmID, forKey: "pendingAlarmIntent")
        sharedDefaults.set(Date(), forKey: "pendingAlarmIntentTimestamp")

        // Return success - routing happens in the main app
        return .result()
    }
}