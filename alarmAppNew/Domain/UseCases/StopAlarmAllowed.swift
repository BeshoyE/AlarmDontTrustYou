//
//  StopAlarmAllowed.swift
//  alarmAppNew
//
//  Pure domain use case for determining if an alarm can be stopped.
//  This enforces the business rule that alarms with challenges must
//  complete all challenges before the stop button is enabled.
//

import Foundation

/// State of challenge validation for an alarm.
public struct ChallengeStackState {
    /// The challenges configured for the alarm
    public let requiredChallenges: [Challenges]

    /// The challenges that have been completed
    public let completedChallenges: Set<Challenges>

    /// Whether challenges are currently being validated
    public let isValidating: Bool

    public init(
        requiredChallenges: [Challenges],
        completedChallenges: Set<Challenges>,
        isValidating: Bool = false
    ) {
        self.requiredChallenges = requiredChallenges
        self.completedChallenges = completedChallenges
        self.isValidating = isValidating
    }

    /// Check if all required challenges have been completed
    public var allChallengesCompleted: Bool {
        // If no challenges required, considered complete
        guard !requiredChallenges.isEmpty else { return true }

        // Check that every required challenge is in the completed set
        return requiredChallenges.allSatisfy { challenge in
            completedChallenges.contains(challenge)
        }
    }

    /// Get the next challenge that needs to be completed
    public var nextChallenge: Challenges? {
        // Return first challenge that hasn't been completed
        return requiredChallenges.first { challenge in
            !completedChallenges.contains(challenge)
        }
    }

    /// Get progress as a fraction (0.0 to 1.0)
    public var progress: Double {
        guard !requiredChallenges.isEmpty else { return 1.0 }
        return Double(completedChallenges.count) / Double(requiredChallenges.count)
    }
}

/// Use case for determining if an alarm can be stopped.
///
/// This enforces the core business rule that alarms with challenges
/// must have all challenges validated before the stop action is allowed.
public struct StopAlarmAllowed {

    /// Determine if the stop action is allowed for an alarm.
    ///
    /// - Parameter challengeState: The current state of challenge validation
    /// - Returns: True if the alarm can be stopped, false otherwise
    public static func execute(challengeState: ChallengeStackState) -> Bool {
        // Core business rule: Stop is only allowed when all challenges are validated
        return challengeState.allChallengesCompleted
    }

    /// Determine if the stop action is allowed based on alarm configuration.
    ///
    /// This variant is used when we only have the alarm configuration,
    /// not the current validation state.
    ///
    /// - Parameters:
    ///   - alarm: The alarm to check
    ///   - completedChallenges: Set of challenges that have been completed
    /// - Returns: True if the alarm can be stopped, false otherwise
    public static func execute(
        alarm: Alarm,
        completedChallenges: Set<Challenges>
    ) -> Bool {
        let state = ChallengeStackState(
            requiredChallenges: alarm.challengeKind,
            completedChallenges: completedChallenges
        )
        return execute(challengeState: state)
    }

    /// Get a human-readable reason why stop is not allowed.
    ///
    /// - Parameter challengeState: The current state of challenge validation
    /// - Returns: Reason string if stop is not allowed, nil if stop is allowed
    public static func reasonForDenial(challengeState: ChallengeStackState) -> String? {
        // If stop is allowed, no reason for denial
        guard !execute(challengeState: challengeState) else { return nil }

        // If currently validating, indicate that
        if challengeState.isValidating {
            return "Challenge validation in progress"
        }

        // If no challenges completed yet
        if challengeState.completedChallenges.isEmpty {
            return "Complete all challenges to stop the alarm"
        }

        // Some challenges completed but not all
        if let nextChallenge = challengeState.nextChallenge {
            return "Complete \(nextChallenge.displayName) challenge to continue"
        }

        // Generic message
        let remaining = challengeState.requiredChallenges.count - challengeState.completedChallenges.count
        return "Complete \(remaining) more challenge(s) to stop the alarm"
    }

    /// Calculate the minimum time before stop could be allowed.
    ///
    /// This is useful for UI hints about when the stop button might become available.
    ///
    /// - Parameters:
    ///   - challengeState: The current state of challenge validation
    ///   - estimatedTimePerChallenge: Estimated seconds per challenge (default 10)
    /// - Returns: Estimated seconds until stop could be allowed, or nil if already allowed
    public static func estimatedTimeUntilAllowed(
        challengeState: ChallengeStackState,
        estimatedTimePerChallenge: TimeInterval = 10
    ) -> TimeInterval? {
        // If already allowed, no wait time
        guard !execute(challengeState: challengeState) else { return nil }

        // Calculate remaining challenges
        let remainingCount = challengeState.requiredChallenges.count - challengeState.completedChallenges.count

        // Estimate time based on remaining challenges
        return TimeInterval(remainingCount) * estimatedTimePerChallenge
    }
}

// MARK: - Challenge Progress Tracking

/// Helper to track challenge completion progress.
public struct ChallengeProgress {
    public let total: Int
    public let completed: Int

    public init(state: ChallengeStackState) {
        self.total = state.requiredChallenges.count
        self.completed = state.completedChallenges.count
    }

    public var remaining: Int {
        return total - completed
    }

    public var percentComplete: Int {
        guard total > 0 else { return 100 }
        return (completed * 100) / total
    }

    public var isComplete: Bool {
        return completed >= total
    }

    public var displayText: String {
        if isComplete {
            return "All challenges completed"
        } else if completed == 0 {
            return "\(total) challenge\(total == 1 ? "" : "s") to complete"
        } else {
            return "\(completed) of \(total) challenges completed"
        }
    }
}