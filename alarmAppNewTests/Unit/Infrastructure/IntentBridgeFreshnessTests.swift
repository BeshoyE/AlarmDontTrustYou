//
//  IntentBridgeFreshnessTests.swift
//  alarmAppNewTests
//
//  Tests for AlarmIntentBridge timestamp freshness validation.
//

import XCTest
@testable import alarmAppNew

@MainActor
final class IntentBridgeFreshnessTests: XCTestCase {
    private let appGroupIdentifier = "group.com.beshoy.alarmAppNew"
    private var sharedDefaults: UserDefaults?
    private var bridge: AlarmIntentBridge!
    private var notificationExpectation: XCTestExpectation?

    override func setUp() async throws {
        try await super.setUp()
        bridge = AlarmIntentBridge()
        sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)

        // Clear any existing data
        sharedDefaults?.removeObject(forKey: "pendingAlarmIntent")
        sharedDefaults?.removeObject(forKey: "pendingAlarmIntentTimestamp")
    }

    override func tearDown() async throws {
        // Clean up
        sharedDefaults?.removeObject(forKey: "pendingAlarmIntent")
        sharedDefaults?.removeObject(forKey: "pendingAlarmIntentTimestamp")
        NotificationCenter.default.removeObserver(self)
        try await super.tearDown()
    }

    func test_checkForPendingIntent_whenTimestampFresh_shouldPostNotification() async {
        // Given: A fresh intent (5 seconds old)
        let alarmId = UUID()
        let freshTimestamp = Date().addingTimeInterval(-5)
        sharedDefaults?.set(alarmId.uuidString, forKey: "pendingAlarmIntent")
        sharedDefaults?.set(freshTimestamp, forKey: "pendingAlarmIntentTimestamp")

        // Set up notification observer
        notificationExpectation = expectation(description: "Should receive alarmIntentReceived notification")
        var receivedAlarmId: UUID?

        let observer = NotificationCenter.default.addObserver(
            forName: .alarmIntentReceived,
            object: nil,
            queue: .main
        ) { notification in
            receivedAlarmId = notification.userInfo?["alarmId"] as? UUID
            self.notificationExpectation?.fulfill()
        }

        // When: Checking for pending intent
        bridge.checkForPendingIntent()

        // Then: Should post notification with correct alarm ID
        await fulfillment(of: [notificationExpectation!], timeout: 1.0)
        XCTAssertEqual(receivedAlarmId, alarmId, "Should receive correct alarm ID in notification")

        // And: Should clear the intent data
        XCTAssertNil(sharedDefaults?.object(forKey: "pendingAlarmIntent"))
        XCTAssertNil(sharedDefaults?.object(forKey: "pendingAlarmIntentTimestamp"))

        NotificationCenter.default.removeObserver(observer)
    }

    func test_checkForPendingIntent_whenTimestampStale_shouldNotPostNotification() async {
        // Given: A stale intent (35 seconds old)
        let alarmId = UUID()
        let staleTimestamp = Date().addingTimeInterval(-35)
        sharedDefaults?.set(alarmId.uuidString, forKey: "pendingAlarmIntent")
        sharedDefaults?.set(staleTimestamp, forKey: "pendingAlarmIntentTimestamp")

        // Set up notification observer
        var notificationReceived = false
        let observer = NotificationCenter.default.addObserver(
            forName: .alarmIntentReceived,
            object: nil,
            queue: .main
        ) { _ in
            notificationReceived = true
        }

        // When: Checking for pending intent
        bridge.checkForPendingIntent()

        // Wait a bit to ensure no notification is posted
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Then: Should not post notification
        XCTAssertFalse(notificationReceived, "Should not post notification for stale intent")

        // And: Should clear the stale intent data
        XCTAssertNil(sharedDefaults?.object(forKey: "pendingAlarmIntent"))
        XCTAssertNil(sharedDefaults?.object(forKey: "pendingAlarmIntentTimestamp"))

        NotificationCenter.default.removeObserver(observer)
    }

    func test_checkForPendingIntent_whenTimestampBoundary_shouldPostNotification() async {
        // Given: An intent exactly at the boundary (29 seconds old - just under 30s limit)
        let alarmId = UUID()
        let boundaryTimestamp = Date().addingTimeInterval(-29)
        sharedDefaults?.set(alarmId.uuidString, forKey: "pendingAlarmIntent")
        sharedDefaults?.set(boundaryTimestamp, forKey: "pendingAlarmIntentTimestamp")

        // Set up notification observer
        notificationExpectation = expectation(description: "Should receive alarmIntentReceived notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .alarmIntentReceived,
            object: nil,
            queue: .main
        ) { _ in
            self.notificationExpectation?.fulfill()
        }

        // When: Checking for pending intent
        bridge.checkForPendingIntent()

        // Then: Should post notification (within 30 second window)
        await fulfillment(of: [notificationExpectation!], timeout: 1.0)

        NotificationCenter.default.removeObserver(observer)
    }

    func test_checkForPendingIntent_whenNoIntent_shouldNotPostNotification() async {
        // Given: No intent in shared defaults

        // Set up notification observer
        var notificationReceived = false
        let observer = NotificationCenter.default.addObserver(
            forName: .alarmIntentReceived,
            object: nil,
            queue: .main
        ) { _ in
            notificationReceived = true
        }

        // When: Checking for pending intent
        bridge.checkForPendingIntent()

        // Wait a bit to ensure no notification is posted
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Then: Should not post notification
        XCTAssertFalse(notificationReceived, "Should not post notification when no intent exists")

        NotificationCenter.default.removeObserver(observer)
    }

    func test_checkForPendingIntent_whenInvalidUUID_shouldNotPostNotification() async {
        // Given: Invalid UUID string
        sharedDefaults?.set("invalid-uuid", forKey: "pendingAlarmIntent")
        sharedDefaults?.set(Date(), forKey: "pendingAlarmIntentTimestamp")

        // Set up notification observer
        var notificationReceived = false
        let observer = NotificationCenter.default.addObserver(
            forName: .alarmIntentReceived,
            object: nil,
            queue: .main
        ) { _ in
            notificationReceived = true
        }

        // When: Checking for pending intent
        bridge.checkForPendingIntent()

        // Wait a bit to ensure no notification is posted
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Then: Should not post notification
        XCTAssertFalse(notificationReceived, "Should not post notification for invalid UUID")

        // And: Should clear the invalid intent data
        XCTAssertNil(sharedDefaults?.object(forKey: "pendingAlarmIntent"))
        XCTAssertNil(sharedDefaults?.object(forKey: "pendingAlarmIntentTimestamp"))

        NotificationCenter.default.removeObserver(observer)
    }
}