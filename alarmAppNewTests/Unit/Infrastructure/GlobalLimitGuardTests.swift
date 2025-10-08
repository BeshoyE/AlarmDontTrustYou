//
//  GlobalLimitGuardTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/1/25.
//

import XCTest
import UserNotifications
@testable import alarmAppNew

final class GlobalLimitGuardTests: XCTestCase {

    private var mockNotificationCenter: MockNotificationCenter!
    private var config: GlobalLimitConfig!
    private var limitGuard: GlobalLimitGuard!

    override func setUp() {
        super.setUp()
        mockNotificationCenter = MockNotificationCenter()
        config = GlobalLimitConfig(safetyBuffer: 4, maxSystemLimit: 64)
        limitGuard = GlobalLimitGuard(config: config, notificationCenter: mockNotificationCenter)
    }

    override func tearDown() {
        mockNotificationCenter = nil
        config = nil
        limitGuard = nil
        super.tearDown()
    }

    // MARK: - Configuration Tests

    func test_globalLimitConfig_availableThreshold_calculatesCorrectly() {
        let config = GlobalLimitConfig(safetyBuffer: 10, maxSystemLimit: 100)
        XCTAssertEqual(config.availableThreshold, 90)
    }

    func test_globalLimitConfig_defaultValues_areReasonable() {
        let defaultConfig = GlobalLimitConfig()
        XCTAssertEqual(defaultConfig.safetyBuffer, 4)
        XCTAssertEqual(defaultConfig.maxSystemLimit, 64)
        XCTAssertEqual(defaultConfig.availableThreshold, 60)
    }

    // MARK: - Available Slots Calculation Tests

    func test_availableSlots_noPendingNotifications_returnsThreshold() async {
        mockNotificationCenter.pendingRequests = []

        let available = await limitGuard.availableSlots()

        XCTAssertEqual(available, config.availableThreshold) // 60
    }

    func test_availableSlots_somePendingNotifications_returnsRemaining() async {
        let pendingRequests = Array(0..<20).map { createMockRequest(identifier: "pending-\($0)") }
        mockNotificationCenter.pendingRequests = pendingRequests

        let available = await limitGuard.availableSlots()

        XCTAssertEqual(available, 40) // 60 - 20
    }

    func test_availableSlots_nearLimit_returnsLowNumber() async {
        let pendingRequests = Array(0..<58).map { createMockRequest(identifier: "pending-\($0)") }
        mockNotificationCenter.pendingRequests = pendingRequests

        let available = await limitGuard.availableSlots()

        XCTAssertEqual(available, 2) // 60 - 58
    }

    func test_availableSlots_atLimit_returnsZero() async {
        let pendingRequests = Array(0..<60).map { createMockRequest(identifier: "pending-\($0)") }
        mockNotificationCenter.pendingRequests = pendingRequests

        let available = await limitGuard.availableSlots()

        XCTAssertEqual(available, 0)
    }

    func test_availableSlots_overLimit_returnsZero() async {
        let pendingRequests = Array(0..<70).map { createMockRequest(identifier: "pending-\($0)") }
        mockNotificationCenter.pendingRequests = pendingRequests

        let available = await limitGuard.availableSlots()

        XCTAssertEqual(available, 0)
    }

    func test_availableSlots_notificationCenterError_returnsConservativeFallback() async {
        mockNotificationCenter.shouldThrowOnPendingRequests = true

        let available = await limitGuard.availableSlots()

        XCTAssertEqual(available, 1) // Conservative fallback
    }

    // MARK: - Reservation Tests

    func test_reserve_sufficientSlots_grantsFullRequest() async {
        mockNotificationCenter.pendingRequests = Array(0..<10).map { createMockRequest(identifier: "pending-\($0)") }

        let granted = await limitGuard.reserve(5)

        XCTAssertEqual(granted, 5)
    }

    func test_reserve_insufficientSlots_grantsPartial() async {
        mockNotificationCenter.pendingRequests = Array(0..<58).map { createMockRequest(identifier: "pending-\($0)") }

        let granted = await limitGuard.reserve(5)

        XCTAssertEqual(granted, 2) // Only 2 available (60 - 58)
    }

    func test_reserve_noSlotsAvailable_grantsZero() async {
        mockNotificationCenter.pendingRequests = Array(0..<60).map { createMockRequest(identifier: "pending-\($0)") }

        let granted = await limitGuard.reserve(3)

        XCTAssertEqual(granted, 0)
    }

    func test_reserve_zeroRequested_grantsZero() async {
        mockNotificationCenter.pendingRequests = []

        let granted = await limitGuard.reserve(0)

        XCTAssertEqual(granted, 0)
    }

    func test_reserve_negativeRequested_grantsZero() async {
        mockNotificationCenter.pendingRequests = []

        let granted = await limitGuard.reserve(-5)

        XCTAssertEqual(granted, 0)
    }

    // MARK: - Concurrent Reservation Tests

    func test_reserve_concurrentRequests_maintainsSafety() async {
        mockNotificationCenter.pendingRequests = Array(0..<50).map { createMockRequest(identifier: "pending-\($0)") }

        // Simulate 5 concurrent reservation requests
        let results = await withTaskGroup(of: Int.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    await self.limitGuard.reserve(5)
                }
            }

            var totalGranted = 0
            for await result in group {
                totalGranted += result
            }
            return totalGranted
        }

        // Should not grant more than available (60 - 50 = 10)
        XCTAssertLessThanOrEqual(results, 10)
        XCTAssertGreaterThan(results, 0) // Should grant something
    }

    func test_reserve_sequentialReservations_tracksCorrectly() async {
        mockNotificationCenter.pendingRequests = Array(0..<55).map { createMockRequest(identifier: "pending-\($0)") }

        let first = await limitGuard.reserve(3)
        let second = await limitGuard.reserve(2)
        let third = await limitGuard.reserve(1)

        XCTAssertEqual(first, 3) // 5 available, granted 3
        XCTAssertEqual(second, 2) // 2 remaining, granted 2
        XCTAssertEqual(third, 0) // 0 remaining, granted 0
    }

    // MARK: - Finalization Tests

    func test_finalize_releasesReservedSlots() async {
        mockNotificationCenter.pendingRequests = Array(0..<55).map { createMockRequest(identifier: "pending-\($0)") }

        let granted = await limitGuard.reserve(5)
        XCTAssertEqual(granted, 5)

        // Finalize with fewer than reserved (some failed to schedule)
        limitGuard.finalize(3)

        // Should be able to reserve more now
        let secondGranted = await limitGuard.reserve(2)
        XCTAssertEqual(secondGranted, 2) // 2 slots were freed up
    }

    func test_finalize_moreThanReserved_handledSafely() async {
        mockNotificationCenter.pendingRequests = Array(0..<58).map { createMockRequest(identifier: "pending-\($0)") }

        let granted = await limitGuard.reserve(2)
        XCTAssertEqual(granted, 2)

        // Finalize with more than reserved (shouldn't happen, but be safe)
        limitGuard.finalize(5)

        // Reserved slots should not go negative
        #if DEBUG
        XCTAssertEqual(limitGuard.currentReservedSlots, 0)
        #endif
    }

    // MARK: - Edge Cases

    func test_reserve_multipleFinalizeOperations_maintainsConsistency() async {
        mockNotificationCenter.pendingRequests = Array(0..<50).map { createMockRequest(identifier: "pending-\($0)") }

        let first = await limitGuard.reserve(5)
        let second = await limitGuard.reserve(3)

        limitGuard.finalize(2) // Partial finalization of first
        limitGuard.finalize(3) // Full finalization of second
        limitGuard.finalize(3) // Finalization of remaining from first

        // Should have all slots available again
        let third = await limitGuard.reserve(10)
        XCTAssertEqual(third, 10) // 60 - 50 = 10 available
    }

    // MARK: - Test Hooks (DEBUG only)

    #if DEBUG
    func test_resetReservations_clearsReservedSlots() async {
        mockNotificationCenter.pendingRequests = Array(0..<55).map { createMockRequest(identifier: "pending-\($0)") }

        let granted = await limitGuard.reserve(5)
        XCTAssertEqual(granted, 5)
        XCTAssertEqual(limitGuard.currentReservedSlots, 5)

        limitGuard.resetReservations()
        XCTAssertEqual(limitGuard.currentReservedSlots, 0)

        // Should be able to reserve full amount again
        let secondGranted = await limitGuard.reserve(5)
        XCTAssertEqual(secondGranted, 5)
    }

    func test_currentReservedSlots_trackingCorrectly() async {
        mockNotificationCenter.pendingRequests = []

        XCTAssertEqual(limitGuard.currentReservedSlots, 0)

        let granted = await limitGuard.reserve(10)
        XCTAssertEqual(granted, 10)
        XCTAssertEqual(limitGuard.currentReservedSlots, 10)

        limitGuard.finalize(7)
        XCTAssertEqual(limitGuard.currentReservedSlots, 3)

        limitGuard.finalize(3)
        XCTAssertEqual(limitGuard.currentReservedSlots, 0)
    }
    #endif

    // MARK: - Helper Methods

    private func createMockRequest(identifier: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Test"
        content.body = "Test notification"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}

// MARK: - Mock Implementation

private class MockNotificationCenter: UNUserNotificationCenter {
    var pendingRequests: [UNNotificationRequest] = []
    var shouldThrowOnPendingRequests = false

    override func pendingNotificationRequests() async -> [UNNotificationRequest] {
        if shouldThrowOnPendingRequests {
            throw NSError(domain: "MockError", code: 123, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        return pendingRequests
    }
}