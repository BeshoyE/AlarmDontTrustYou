//
//  ActiveAlarmPolicyProvider.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/8/25.
//  Computes active alarm windows from chain configuration (no magic numbers)
//

import Foundation

/// Protocol for determining if an alarm occurrence is currently active
/// (i.e., should be protected from cancellation during refreshAll)
public protocol ActiveAlarmPolicyProviding {
    /// Compute the active window duration for an alarm occurrence
    /// Returns the number of seconds from the occurrence fire time during which
    /// the alarm is considered "active" and should not be cancelled
    func activeWindowSeconds(for alarmId: UUID, occurrenceKey: String) -> TimeInterval
}

/// Default implementation that derives the active window from chain configuration
/// Formula: window = min(((count-1) * spacing) + leadIn + tolerance, maxCap)
///
/// Rationale:
/// - The chain spans from first notification to last notification
/// - Duration = (count-1) * spacing (e.g., 12 notifications * 10s = 110s from first to last)
/// - Add leadIn (minLeadTimeSec) for scheduling overhead
/// - Add tolerance for device/OS delays
/// - Cap at ringWindowSec to prevent unbounded windows
public final class ActiveAlarmPolicyProvider: ActiveAlarmPolicyProviding {
    private let chainPolicy: ChainPolicy
    private let toleranceSeconds: TimeInterval

    /// Initialize with chain policy and tolerance
    /// - Parameters:
    ///   - chainPolicy: The chain configuration policy (provides spacing, count, leadIn)
    ///   - toleranceSeconds: Additional buffer for device/OS delays (default: 10s)
    public init(chainPolicy: ChainPolicy, toleranceSeconds: TimeInterval = 10.0) {
        self.chainPolicy = chainPolicy
        self.toleranceSeconds = toleranceSeconds
    }

    public func activeWindowSeconds(for alarmId: UUID, occurrenceKey: String) -> TimeInterval {
        // Compute the chain configuration using the same logic as scheduling
        // Default spacing is 10s (this is what ChainedNotificationScheduler uses)
        let defaultSpacing = 10
        let chainConfig = chainPolicy.computeChain(spacingSeconds: defaultSpacing)

        // Calculate the duration from first to last notification in the chain
        // For a chain of N notifications spaced S seconds apart:
        // - First fires at T=0
        // - Last fires at T=(N-1)*S
        // - Total span = (N-1) * S
        let chainSpan = TimeInterval((chainConfig.chainCount - 1) * chainConfig.spacingSeconds)

        // Add leadIn time (scheduling overhead)
        let leadIn = TimeInterval(chainPolicy.settings.minLeadTimeSec)

        // Add tolerance for device delays
        let tolerance = toleranceSeconds

        // Compute total active window
        let computedWindow = chainSpan + leadIn + tolerance

        // Cap at the ring window to prevent unbounded windows
        let maxCap = TimeInterval(chainPolicy.settings.ringWindowSec)
        let activeWindow = min(computedWindow, maxCap)

        return activeWindow
    }
}
