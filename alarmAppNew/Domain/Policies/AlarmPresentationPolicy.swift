//
//  AlarmPresentationPolicy.swift
//  alarmAppNew
//
//  Pure Swift policies for alarm presentation behavior.
//  These policies determine how alarms should be presented and controlled
//  without any dependency on specific UI frameworks.
//

import Foundation

/// Bounds for valid snooze durations.
public struct SnoozeBounds {
    /// Minimum allowed snooze duration in seconds
    public let min: TimeInterval

    /// Maximum allowed snooze duration in seconds
    public let max: TimeInterval

    public init(min: TimeInterval, max: TimeInterval) {
        // Ensure min <= max
        self.min = Swift.min(min, max)
        self.max = Swift.max(min, max)
    }

    /// Default snooze bounds (5 to 60 minutes)
    public static let `default` = SnoozeBounds(
        min: 5 * 60,   // 5 minutes
        max: 60 * 60   // 60 minutes
    )
}

/// Policies for alarm presentation and control behavior.
public struct AlarmPresentationPolicy {

    private let snoozeBounds: SnoozeBounds

    public init(snoozeBounds: SnoozeBounds = .default) {
        self.snoozeBounds = snoozeBounds
    }

    /// Determine if countdown should be shown for an alarm.
    /// - Parameter alarm: The alarm to check
    /// - Returns: True if countdown should be shown (snooze is enabled with valid duration)
    public func shouldShowCountdown(for alarm: Alarm) -> Bool {
        // Show countdown if alarm has snooze enabled
        // In the future, this will check alarm.snoozeEnabled and alarm.snoozeDuration
        // For now, we'll return false as snooze isn't implemented yet
        // TODO: Update when Alarm model includes snooze configuration
        return false
    }

    /// Determine if a live activity is required for an alarm.
    /// - Parameter alarm: The alarm to check
    /// - Returns: True if alarm needs a live activity (for countdown or pre-alarm features)
    public func requiresLiveActivity(for alarm: Alarm) -> Bool {
        // Live activity needed for:
        // 1. Snooze/countdown features
        // 2. Pre-alarm countdowns
        // For now, return same as shouldShowCountdown
        return shouldShowCountdown(for: alarm)
    }

    /// Check if a snooze duration is valid within configured bounds.
    /// - Parameters:
    ///   - duration: The requested snooze duration in seconds
    ///   - bounds: The snooze bounds to validate against
    /// - Returns: True if duration is within bounds
    public static func isSnoozeDurationValid(
        _ duration: TimeInterval,
        bounds: SnoozeBounds
    ) -> Bool {
        return duration >= bounds.min && duration <= bounds.max
    }

    /// Clamp a snooze duration to valid bounds.
    /// - Parameters:
    ///   - duration: The requested snooze duration in seconds
    ///   - bounds: The snooze bounds to clamp to
    /// - Returns: Duration clamped to [min, max] range
    public static func clampSnoozeDuration(
        _ duration: TimeInterval,
        bounds: SnoozeBounds
    ) -> TimeInterval {
        if duration < bounds.min {
            return bounds.min
        } else if duration > bounds.max {
            return bounds.max
        } else {
            return duration
        }
    }

    /// Determine the stop button semantics for an alarm.
    /// - Parameter challengesRequired: Whether challenges are configured for the alarm
    /// - Returns: Description of when stop button should be enabled
    public static func stopButtonSemantics(challengesRequired: Bool) -> StopButtonSemantics {
        if challengesRequired {
            return .requiresChallengeValidation
        } else {
            return .alwaysEnabled
        }
    }
}

/// Semantics for when the stop button should be enabled.
public enum StopButtonSemantics {
    /// Stop button is always enabled (no challenges required)
    case alwaysEnabled

    /// Stop button requires all challenges to be validated first
    case requiresChallengeValidation

    /// Human-readable description
    public var description: String {
        switch self {
        case .alwaysEnabled:
            return "Stop button is always enabled"
        case .requiresChallengeValidation:
            return "Stop button requires challenge completion"
        }
    }
}