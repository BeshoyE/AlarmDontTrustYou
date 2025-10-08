//
//  GlobalLimitGuard.swift
//  alarmAppNew
//
//  Created by Claude Code on 10/1/25.
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

public final class GlobalLimitGuard {
    private let config: GlobalLimitConfig
    private let notificationCenter: UNUserNotificationCenter
    private let log = OSLog(subsystem: "alarmAppNew", category: "GlobalLimitGuard")

    // Atomic slot reservation
    private let mutex = DispatchSemaphore(value: 1)
    private var reservedSlots = 0

    public init(
        config: GlobalLimitConfig = GlobalLimitConfig(),
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.config = config
        self.notificationCenter = notificationCenter
    }

    // MARK: - Public Interface

    public func reserve(_ count: Int) async -> Int {
        let granted = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                self.mutex.wait()
                defer { self.mutex.signal() }

                Task {
                    let available = await self.computeAvailableSlots()
                    let granted = min(count, max(0, available - self.reservedSlots))

                    self.reservedSlots += granted

                    os_log("Reserved %d of %d requested slots (available: %d, reserved: %d)",
                           log: self.log, type: .info, granted, count, available, self.reservedSlots)

                    continuation.resume(returning: granted)
                }
            }
        }

        return granted
    }

    public func finalize(_ actualScheduled: Int) {
        mutex.wait()
        defer { mutex.signal() }

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
    public var currentReservedSlots: Int {
        mutex.wait()
        defer { mutex.signal() }
        return reservedSlots
    }

    public func resetReservations() {
        mutex.wait()
        defer { mutex.signal() }
        reservedSlots = 0
    }
}
#endif