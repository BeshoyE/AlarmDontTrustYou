//
//  Integration_TestAlarmSchedulingTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/8/25.
//  Integration tests for lock-screen test alarm scheduling
//

import XCTest
@testable import alarmAppNew
import UserNotifications

@MainActor
final class Integration_TestAlarmSchedulingTests: XCTestCase {
    var dependencyContainer: DependencyContainer!

    override func setUp() {
        super.setUp()
        dependencyContainer = DependencyContainer()
    }

    override func tearDown() {
        // Clean up any test notifications
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        super.tearDown()
    }

    // MARK: - Integration Tests

    func test_scheduleOneOffTestAlarm_createsNotificationWithCorrectProperties() async throws {
        // GIVEN: Notification service
        let notificationService = dependencyContainer.notificationService

        // Request authorization first
        let center = UNUserNotificationCenter.current()
        _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])

        // WHEN: Scheduling test alarm with 8-second lead time
        try await notificationService.scheduleOneOffTestAlarm(leadTime: 8)

        // THEN: Notification should be scheduled
        let pending = await center.pendingNotificationRequests()
        let testNotifications = pending.filter { $0.identifier.hasPrefix("test-lock-screen-") }

        XCTAssertEqual(testNotifications.count, 1, "Should have exactly one test notification scheduled")

        // Verify notification properties
        guard let testNotification = testNotifications.first else {
            XCTFail("Test notification not found")
            return
        }

        // Check content
        XCTAssertEqual(testNotification.content.title, "🔔 Lock-Screen Test Alarm")
        XCTAssertEqual(testNotification.content.body, "This is a test to verify your ringer volume")
        XCTAssertEqual(testNotification.content.sound, .default)
        XCTAssertEqual(testNotification.content.categoryIdentifier, Categories.alarm)

        // Check userInfo
        let userInfo = testNotification.content.userInfo
        XCTAssertEqual(userInfo["type"] as? String, "test_lock_screen")
        XCTAssertEqual(userInfo["isTest"] as? Bool, true)
        XCTAssertNotNil(userInfo["alarmId"], "Should have alarmId in userInfo")

        // Check trigger
        guard let trigger = testNotification.trigger as? UNTimeIntervalNotificationTrigger else {
            XCTFail("Trigger should be UNTimeIntervalNotificationTrigger")
            return
        }

        XCTAssertEqual(trigger.timeInterval, 8, accuracy: 0.1, "Trigger should fire in 8 seconds")
        XCTAssertFalse(trigger.repeats, "Test notification should not repeat")

        // Check interruption level (iOS 15+)
        if #available(iOS 15.0, *) {
            XCTAssertEqual(testNotification.content.interruptionLevel, .timeSensitive,
                          "Should use time-sensitive interruption level")
        }
    }

    func test_scheduleOneOffTestAlarm_withCustomLeadTime_usesCustomValue() async throws {
        // GIVEN: Notification service
        let notificationService = dependencyContainer.notificationService

        // Request authorization
        let center = UNUserNotificationCenter.current()
        _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])

        // WHEN: Scheduling test alarm with custom lead time (5 seconds)
        try await notificationService.scheduleOneOffTestAlarm(leadTime: 5)

        // THEN: Notification should be scheduled with custom lead time
        let pending = await center.pendingNotificationRequests()
        let testNotifications = pending.filter { $0.identifier.hasPrefix("test-lock-screen-") }

        XCTAssertEqual(testNotifications.count, 1)

        guard let testNotification = testNotifications.first,
              let trigger = testNotification.trigger as? UNTimeIntervalNotificationTrigger else {
            XCTFail("Test notification or trigger not found")
            return
        }

        XCTAssertEqual(trigger.timeInterval, 5, accuracy: 0.1, "Trigger should use custom lead time")
    }

    func test_scheduleOneOffTestAlarm_multipleInvocations_createsMultipleNotifications() async throws {
        // GIVEN: Notification service
        let notificationService = dependencyContainer.notificationService

        // Request authorization
        let center = UNUserNotificationCenter.current()
        _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])

        // WHEN: Scheduling test alarm twice
        try await notificationService.scheduleOneOffTestAlarm(leadTime: 8)
        try await notificationService.scheduleOneOffTestAlarm(leadTime: 8)

        // THEN: Should have two separate test notifications
        let pending = await center.pendingNotificationRequests()
        let testNotifications = pending.filter { $0.identifier.hasPrefix("test-lock-screen-") }

        XCTAssertEqual(testNotifications.count, 2, "Should create separate notifications for each invocation")

        // Verify they have unique identifiers
        let identifiers = testNotifications.map { $0.identifier }
        let uniqueIdentifiers = Set(identifiers)
        XCTAssertEqual(identifiers.count, uniqueIdentifiers.count, "Each notification should have unique identifier")
    }
}
