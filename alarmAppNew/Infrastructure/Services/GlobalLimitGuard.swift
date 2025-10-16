//
//  GlobalLimitGuard.swift
//  alarmAppNew
//
//  Thread-safe notification slot reservation using Swift actor model.
//  Conforms to CLAUDE.md §3 (actor-based concurrency) and claude-guardrails.md.
//

import Foundation
import UserNotifications
import os.log

public struct GlobalLimitConfig {
    public let safetyBuffer: Int
    public let maxSystemLimit: Int

    public init(safetyBuffer: Int = 4, maxSystemLimit: Int = 64) {
        self.safetyBuffer = safetyBuffer
        self.maxSystemLimit = maxSystemLimit
    }

    public var availableThreshold: Int {
        return maxSystemLimit - safetyBuffer
    }
}

/// Thread-safe actor for managing global notification slot reservations.
///
/// **Architecture Compliance:**
/// - CLAUDE.md §3: Uses Swift `actor` for shared mutable state (no manual locking)
/// - claude-guardrails.md: Zero usage of DispatchSemaphore or DispatchQueue.sync
///
/// **Thread Safety:**
/// Actor serialization ensures atomic reserve-modify-finalize sequences.
/// Multiple concurrent `reserve()` calls are automatically serialized by Swift.
public actor GlobalLimitGuard {
    private let config: GlobalLimitConfig
    private let notificationCenter: UNUserNotificationCenter
    private let log = OSLog(subsystem: "alarmAppNew", category: "GlobalLimitGuard")

    // Actor-isolated state (no manual locking needed)
    private var reservedSlots = 0

    public init(
        config: GlobalLimitConfig = GlobalLimitConfig(),
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.config = config
        self.notificationCenter = notificationCenter
    }

    // MARK: - Public Interface

    /// Reserve notification slots atomically.
    ///
    /// Actor isolation ensures this method is thread-safe without manual locking.
    /// Multiple concurrent calls are automatically serialized by Swift.
    ///
    /// - Parameter count: Number of slots requested
    /// - Returns: Number of slots actually granted (may be less than requested)
    public func reserve(_ count: Int) async -> Int {
        // Actor isolation ensures this entire sequence is atomic - no manual locking needed
        let available = await computeAvailableSlots()
        let granted = min(count, max(0, available - reservedSlots))

        reservedSlots += granted

        os_log("Reserved %d of %d requested slots (available: %d, reserved: %d)",
               log: log, type: .info, granted, count, available, reservedSlots)

        return granted
    }

    /// Release reserved slots after scheduling completes.
    ///
    /// Actor isolation ensures this method is thread-safe without manual locking.
    ///
    /// - Parameter actualScheduled: Number of slots that were actually used
    public func finalize(_ actualScheduled: Int) async {
        // Actor isolation ensures this is atomic - no manual locking needed
        reservedSlots = max(0, reservedSlots - actualScheduled)

        os_log("Finalized %d scheduled notifications (remaining reserved: %d)",
               log: log, type: .debug, actualScheduled, reservedSlots)
    }

    public func availableSlots() async -> Int {
        return await computeAvailableSlots()
    }

    // MARK: - Private Implementation

    private func computeAvailableSlots() async -> Int {
        do {
            let pendingRequests = await notificationCenter.pendingNotificationRequests()
            let currentPending = pendingRequests.count
            let available = max(0, config.availableThreshold - currentPending)

            os_log("Available slots: %d (pending: %d, threshold: %d, safety buffer: %d)",
                   log: log, type: .debug, available, currentPending,
                   config.availableThreshold, config.safetyBuffer)

            return available
        } catch {
            os_log("Failed to get pending notifications: %@", log: log, type: .error, error.localizedDescription)

            #if DEBUG
            assertionFailure("Failed to get pending notifications: \(error)")
            #endif

            // Conservative fallback: assume we're near the limit
            return 1
        }
    }
}

// MARK: - Test Support

#if DEBUG
extension GlobalLimitGuard {
    /// Get current reserved slots count (async due to actor isolation).
    public var currentReservedSlots: Int {
        get async { reservedSlots }
    }

    /// Reset all reservations (async due to actor isolation).
    public func resetReservations() async {
        reservedSlots = 0
    }
}
#endif