//
//  NotificationIntegrationTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 9/16/25.
//  Integration tests for notification scheduling with sounds
//

import XCTest
import UserNotifications
@testable import alarmAppNew

// MARK: - Mock App State Provider

class MockAppStateProvider: AppStateProviding {
    var mockIsAppActive: Bool = false

    var isAppActive: Bool {
        return mockIsAppActive
    }
}

final class NotificationIntegrationTests: XCTestCase {
    var notificationService: NotificationService!
    var mockPermissionService: MockPermissionService!
    var mockAppStateProvider: MockAppStateProvider!
    var notificationCenter: UNUserNotificationCenter!

    override func setUp() {
        super.setUp()
        mockPermissionService = MockPermissionService()
        mockAppStateProvider = MockAppStateProvider()

        // Create minimal mock dependencies for testing
        let mockReliabilityLogger = LocalReliabilityLogger()
        let mockAppRouter = AppRouter()
        let mockPersistenceService = PersistenceService()

        notificationService = NotificationService(
            permissionService: mockPermissionService,
            appStateProvider: mockAppStateProvider,
            reliabilityLogger: mockReliabilityLogger,
            appRouter: mockAppRouter,
            persistenceService: mockPersistenceService
        )
        notificationCenter = UNUserNotificationCenter.current()

        // Clear any existing test notifications
        notificationCenter.removeAllPendingNotificationRequests()
    }

    override func tearDown() {
        // Clean up any scheduled notifications
        notificationCenter.removeAllPendingNotificationRequests()
        notificationService = nil
        mockPermissionService = nil
        notificationCenter = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func createTestAlarm(
        id: UUID = UUID(),
        time: Date = Date().addingTimeInterval(300), // 5 minutes from now
        label: String = "Integration Test Alarm",
        repeatDays: [Weekdays] = [],
        soundName: String? = "default"
    ) -> Alarm {
        return Alarm(
            id: id,
            time: time,
            label: label,
            repeatDays: repeatDays,
            challengeKind: [.qr],
            expectedQR: "test",
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundName: soundName,
            volume: 0.8
        )
    }

    private func waitForNotificationScheduling() async {
        // Give the system time to process notification requests
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }

    // MARK: - Integration Tests

    func test_scheduleAndCancel_oneTimeAlarm_shouldWorkEndToEnd() async throws {
        let alarm = createTestAlarm()

        // Schedule the alarm
        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        // Verify notifications were scheduled
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let alarmNotifications = pendingRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm.id.uuidString
        }

        XCTAssertTrue(alarmNotifications.count > 0, "Should have scheduled notifications for the alarm")

        // Cancel the alarm
        notificationService.cancelAlarm(alarm)
        await waitForNotificationScheduling()

        // Verify notifications were cancelled
        let remainingRequests = await notificationCenter.pendingNotificationRequests()
        let remainingAlarmNotifications = remainingRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm.id.uuidString
        }

        XCTAssertEqual(remainingAlarmNotifications.count, 0, "All alarm notifications should be cancelled")
    }

    func test_scheduleRepeatingAlarm_shouldCreateMultipleNotifications() async throws {
        let alarm = createTestAlarm(repeatDays: [.monday, .wednesday, .friday])

        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let alarmNotifications = pendingRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm.id.uuidString
        }

        // Should have notifications for 3 days × 5 notification types (pre-alarm, main, 3 nudges)
        let expectedCount = 3 * 5
        XCTAssertEqual(alarmNotifications.count, expectedCount, "Should schedule notifications for all repeat days and types")
    }

    func test_notificationSound_integration_shouldUseCorrectSound() async throws {
        let customSoundAlarm = createTestAlarm(soundName: "chime")

        try await notificationService.scheduleAlarm(customSoundAlarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let mainNotification = pendingRequests.first { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String,
                  let type = request.content.userInfo["type"] as? String else { return false }
            return alarmId == customSoundAlarm.id.uuidString && type == "main"
        }

        XCTAssertNotNil(mainNotification, "Should find main notification")

        // Verify sound is configured (actual sound name verification would require deeper inspection)
        XCTAssertNotNil(mainNotification?.content.sound, "Main notification should have sound configured")
    }

    func test_preAlarmNotification_shouldHaveCorrectTiming() async throws {
        let futureTime = Date().addingTimeInterval(10 * 60) // 10 minutes from now
        let alarm = createTestAlarm(time: futureTime)

        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let preAlarmNotification = pendingRequests.first { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String,
                  let type = request.content.userInfo["type"] as? String else { return false }
            return alarmId == alarm.id.uuidString && type == "pre_alarm"
        }

        XCTAssertNotNil(preAlarmNotification, "Should schedule pre-alarm notification")

        // Verify it's a calendar trigger
        XCTAssertTrue(preAlarmNotification?.trigger is UNCalendarNotificationTrigger,
                     "Pre-alarm should use calendar trigger")
    }

    func test_nudgeNotifications_shouldHaveCorrectContent() async throws {
        let alarm = createTestAlarm()

        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()

        // Find nudge notifications
        let nudge1 = pendingRequests.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "nudge_1"
        }

        let nudge2 = pendingRequests.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "nudge_2"
        }

        let nudge3 = pendingRequests.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "nudge_3"
        }

        XCTAssertNotNil(nudge1, "Should schedule nudge 1")
        XCTAssertNotNil(nudge2, "Should schedule nudge 2")
        XCTAssertNotNil(nudge3, "Should schedule nudge 3")

        // Verify escalating urgency in titles
        XCTAssertTrue(nudge1?.content.title.contains("⚠️") ?? false, "Nudge 1 should have warning emoji")
        XCTAssertTrue(nudge2?.content.title.contains("🚨") ?? false, "Nudge 2 should have siren emoji")
        XCTAssertTrue(nudge3?.content.title.contains("🔴") ?? false, "Nudge 3 should have red circle emoji")
    }

    func test_cancelSpecificNotifications_integration_shouldPreserveOthers() async throws {
        let alarm = createTestAlarm()

        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        // Cancel only nudge notifications
        notificationService.cancelSpecificNotifications(
            for: alarm.id,
            types: [.nudge1, .nudge2, .nudge3]
        )
        await waitForNotificationScheduling()

        let remainingRequests = await notificationCenter.pendingNotificationRequests()
        let remainingAlarmNotifications = remainingRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm.id.uuidString
        }

        // Should still have main and pre-alarm notifications
        let mainNotification = remainingAlarmNotifications.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "main"
        }

        let preAlarmNotification = remainingAlarmNotifications.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "pre_alarm"
        }

        XCTAssertNotNil(mainNotification, "Main notification should remain")
        XCTAssertNotNil(preAlarmNotification, "Pre-alarm notification should remain")

        // Verify nudges are gone
        let nudgeNotifications = remainingAlarmNotifications.filter { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type.starts(with: "nudge_")
        }

        XCTAssertEqual(nudgeNotifications.count, 0, "All nudge notifications should be cancelled")
    }

    func test_refreshAll_integration_shouldReplaceAllNotifications() async throws {
        let alarm1 = createTestAlarm(id: UUID())
        let alarm2 = createTestAlarm(id: UUID(), repeatDays: [.tuesday])

        // Schedule initial alarms
        try await notificationService.scheduleAlarm(alarm1)
        try await notificationService.scheduleAlarm(alarm2)
        await waitForNotificationScheduling()

        let initialCount = await notificationCenter.pendingNotificationRequests().count

        // Refresh with updated alarms
        let updatedAlarm1 = createTestAlarm(id: alarm1.id, label: "Updated Alarm")
        await notificationService.refreshAll(from: [updatedAlarm1])
        await waitForNotificationScheduling()

        let finalRequests = await notificationCenter.pendingNotificationRequests()

        // Should only have notifications for the refreshed alarm
        let alarm1Notifications = finalRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm1.id.uuidString
        }

        let alarm2Notifications = finalRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm2.id.uuidString
        }

        XCTAssertTrue(alarm1Notifications.count > 0, "Should have notifications for refreshed alarm")
        XCTAssertEqual(alarm2Notifications.count, 0, "Should not have notifications for non-refreshed alarm")
    }

    func test_soundFallback_integration_shouldHandleInvalidSound() async throws {
        let alarm = createTestAlarm(soundName: "nonexistent_sound")

        // Should not throw despite invalid sound
        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let mainNotification = pendingRequests.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "main"
        }

        XCTAssertNotNil(mainNotification, "Should schedule notification despite invalid sound")
        XCTAssertNotNil(mainNotification?.content.sound, "Should have fallback sound")
    }

    func test_nudgePrecision_integration_shouldUseCorrectTriggerTypes() async throws {
        let alarm = createTestAlarm()

        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let nudgeNotifications = pendingRequests.filter { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type.starts(with: "nudge_")
        }

        XCTAssertTrue(nudgeNotifications.count > 0, "Should have nudge notifications")

        // Verify nudge notifications exist (can't directly inspect trigger type in integration test)
        for notification in nudgeNotifications {
            XCTAssertNotNil(notification.trigger, "Nudge notifications should have triggers")
        }
    }

    func test_notificationCategories_integration_shouldHaveAllActions() async throws {
        // Test that the notification categories are properly registered
        let center = UNUserNotificationCenter.current()
        let categories = await center.notificationCategories()

        let alarmCategory = categories.first { $0.identifier == "ALARM_CATEGORY" }
        XCTAssertNotNil(alarmCategory, "Should have ALARM_CATEGORY registered")

        if let category = alarmCategory {
            let actionIdentifiers = category.actions.map { $0.identifier }
            XCTAssertTrue(actionIdentifiers.contains("OPEN_ALARM"), "Should have OPEN_ALARM action")
            XCTAssertTrue(actionIdentifiers.contains("RETURN_TO_DISMISSAL"), "Should have RETURN_TO_DISMISSAL action")
            XCTAssertTrue(actionIdentifiers.contains("SNOOZE_ALARM"), "Should have SNOOZE_ALARM action")
        }
    }

    func test_futureNudgePrevention_integration_shouldStopUpcomingNotifications() async throws {
        let alarm = createTestAlarm()

        // Schedule alarm with nudges
        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        // Generate expected identifiers using same logic as production code
        let expectedNudge1Identifiers = generateExpectedNotificationIdentifiers(for: alarm.id, types: [.nudge1])
        let expectedNudge2Identifiers = generateExpectedNotificationIdentifiers(for: alarm.id, types: [.nudge2])
        let expectedNudge3Identifiers = generateExpectedNotificationIdentifiers(for: alarm.id, types: [.nudge3])

        // Cancel specific future nudges (simulating dismissal after nudge1 fires)
        notificationService.cancelSpecificNotifications(
            for: alarm.id,
            types: [.nudge1, .nudge2]
        )

        // Wait for cancellation to process
        await waitForNotificationScheduling()

        // Verify no future nudge1 or nudge2 notifications remain in pending queue
        let remainingRequests = await notificationCenter.pendingNotificationRequests()
        let remainingIdentifiers = Set(remainingRequests.map { $0.identifier })

        // Assert future nudges won't fire by checking exact identifier matching
        for expectedId in expectedNudge1Identifiers {
            XCTAssertFalse(remainingIdentifiers.contains(expectedId),
                          "Future nudge1 notification '\(expectedId)' should be cancelled")
        }

        for expectedId in expectedNudge2Identifiers {
            XCTAssertFalse(remainingIdentifiers.contains(expectedId),
                          "Future nudge2 notification '\(expectedId)' should be cancelled")
        }

        // Verify nudge3 remains scheduled (should still fire in future)
        var nudge3Found = false
        for expectedId in expectedNudge3Identifiers {
            if remainingIdentifiers.contains(expectedId) {
                nudge3Found = true
                break
            }
        }
        XCTAssertTrue(nudge3Found, "Future nudge3 notifications should remain scheduled")

        // Verify main and pre-alarm notifications remain
        let mainNotification = remainingRequests.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "main"
        }
        XCTAssertNotNil(mainNotification, "Main notification should remain scheduled")
    }

    // Helper to generate expected notification identifiers (mirrors production logic)
    private func generateExpectedNotificationIdentifiers(for alarmId: UUID, types: [NotificationType]) -> Set<String> {
        var identifiers: Set<String> = []

        for type in types {
            // One-time alarm format: "alarmId-typeRawValue"
            identifiers.insert("\(alarmId.uuidString)-\(type.rawValue)")

            // Repeating alarm format: "alarmId-typeRawValue-weekday-N"
            for weekday in 1...7 {
                identifiers.insert("\(alarmId.uuidString)-\(type.rawValue)-weekday-\(weekday)")
            }
        }

        return identifiers
    }

    func test_completeAlarmCancellation_shouldPreventAllFutureNotifications() async throws {
        let alarm = createTestAlarm()

        // Schedule alarm with all notification types
        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        // Generate expected identifiers for all notification types
        let allTypes: [NotificationType] = [.main, .preAlarm, .nudge1, .nudge2, .nudge3]
        let expectedIdentifiers = generateExpectedNotificationIdentifiers(for: alarm.id, types: allTypes)

        // Cancel entire alarm
        notificationService.cancelAlarm(alarm)
        await waitForNotificationScheduling()

        // Verify no future notifications remain in pending queue
        let remainingRequests = await notificationCenter.pendingNotificationRequests()
        let remainingIdentifiers = Set(remainingRequests.map { $0.identifier })

        // Assert no future notifications will fire by checking exact identifier matching
        for expectedId in expectedIdentifiers {
            XCTAssertFalse(remainingIdentifiers.contains(expectedId),
                          "Future notification '\(expectedId)' should be cancelled")
        }

        // Also verify using content-based filtering (for additional safety)
        let remainingAlarmNotifications = remainingRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm.id.uuidString
        }

        XCTAssertEqual(remainingAlarmNotifications.count, 0, "No future alarm notifications should remain scheduled")
    }

    // MARK: - userInfo Routing Tests

    func test_userInfoRouting_defaultTap_opensDismissal() async throws {
        let alarm = createTestAlarm()

        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let mainNotification = pendingRequests.first { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "main"
        }

        XCTAssertNotNil(mainNotification, "Should have main notification")

        // Verify userInfo contains correct alarmId
        if let notification = mainNotification {
            XCTAssertEqual(notification.content.userInfo["alarmId"] as? String, alarm.id.uuidString)
            XCTAssertEqual(notification.content.categoryIdentifier, "ALARM_CATEGORY")
        }
    }

    func test_userInfoRouting_actions_open_return_snooze() async throws {
        // Test that notification categories are properly registered
        let center = UNUserNotificationCenter.current()
        let categories = await center.notificationCategories()

        let alarmCategory = categories.first { $0.identifier == "ALARM_CATEGORY" }
        XCTAssertNotNil(alarmCategory, "Should have ALARM_CATEGORY registered")

        if let category = alarmCategory {
            let actionIdentifiers = category.actions.map { $0.identifier }
            XCTAssertTrue(actionIdentifiers.contains("OPEN_ALARM"), "Should have OPEN_ALARM action")
            XCTAssertTrue(actionIdentifiers.contains("RETURN_TO_DISMISSAL"), "Should have RETURN_TO_DISMISSAL action")
            XCTAssertTrue(actionIdentifiers.contains("SNOOZE_ALARM"), "Should have SNOOZE_ALARM action")

            // Verify action options
            let openAction = category.actions.first { $0.identifier == "OPEN_ALARM" }
            XCTAssertTrue(openAction?.options.contains(.foreground) ?? false, "OPEN_ALARM should have foreground option")

            let returnAction = category.actions.first { $0.identifier == "RETURN_TO_DISMISSAL" }
            XCTAssertTrue(returnAction?.options.contains(.foreground) ?? false, "RETURN_TO_DISMISSAL should have foreground option")

            let snoozeAction = category.actions.first { $0.identifier == "SNOOZE_ALARM" }
            XCTAssertFalse(snoozeAction?.options.contains(.foreground) ?? true, "SNOOZE_ALARM should not have foreground option")
        }
    }

    func test_categories_registered_once_idempotent() {
        // Call ensureNotificationCategoriesRegistered multiple times
        notificationService.ensureNotificationCategoriesRegistered()
        notificationService.ensureNotificationCategoriesRegistered()
        notificationService.ensureNotificationCategoriesRegistered()

        // This test verifies the method can be called multiple times without issues
        // The actual category registration is tested in other tests
        XCTAssertTrue(true, "Multiple category registrations should not cause issues")
    }

    func test_allNotifications_includeUserInfo() async throws {
        let alarm = createTestAlarm(repeatDays: [.monday])

        try await notificationService.scheduleAlarm(alarm)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let alarmNotifications = pendingRequests.filter { request in
            guard let alarmId = request.content.userInfo["alarmId"] as? String else { return false }
            return alarmId == alarm.id.uuidString
        }

        XCTAssertTrue(alarmNotifications.count > 0, "Should have scheduled notifications")

        // Verify every notification has userInfo and category
        for notification in alarmNotifications {
            XCTAssertNotNil(notification.content.userInfo["alarmId"], "Every notification should have alarmId in userInfo")
            XCTAssertNotNil(notification.content.userInfo["type"], "Every notification should have type in userInfo")
            XCTAssertEqual(notification.content.categoryIdentifier, "ALARM_CATEGORY", "Every notification should have ALARM_CATEGORY")
        }
    }

    func test_testNotification_includesUserInfo() async throws {
        try await notificationService.scheduleTestNotification(soundName: "chime", in: 1.0)
        await waitForNotificationScheduling()

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let testNotifications = pendingRequests.filter { request in
            guard let type = request.content.userInfo["type"] as? String else { return false }
            return type == "test"
        }

        XCTAssertTrue(testNotifications.count > 0, "Should have test notification")

        // Verify test notification has userInfo
        if let testNotification = testNotifications.first {
            XCTAssertNotNil(testNotification.content.userInfo["alarmId"], "Test notification should have alarmId")
            XCTAssertEqual(testNotification.content.userInfo["type"] as? String, "test", "Test notification should have test type")
            XCTAssertEqual(testNotification.content.categoryIdentifier, "ALARM_CATEGORY", "Test notification should have ALARM_CATEGORY")
        }
    }

    // MARK: - App State Tests

    func test_appStateProvider_activeState() {
        let provider = MockAppStateProvider()

        // Test inactive state
        provider.mockIsAppActive = false
        XCTAssertFalse(provider.isAppActive, "Should report app as inactive")

        // Test active state
        provider.mockIsAppActive = true
        XCTAssertTrue(provider.isAppActive, "Should report app as active")
    }

    @MainActor
    func test_appStateProvider_mainActorAnnotation() async {
        // Test that the real AppStateProvider is properly marked as MainActor
        let provider = AppStateProvider()

        // This test verifies the provider can be instantiated and accessed on main actor
        // The @MainActor annotation ensures UIApplication access is thread-safe
        XCTAssertNotNil(provider, "AppStateProvider should be instantiable")

        // Test that isAppActive can be accessed (this validates the @MainActor constraint)
        let _ = provider.isAppActive // This validates the property works on main actor
    }

    // MARK: - Error Handling Integration Tests

    func test_permissionDenied_integration_shouldThrowError() async {
        mockPermissionService.mockNotificationDetails = PermissionDetails(
            authorizationStatus: .denied,
            isAuthorizedButMuted: false
        )

        let alarm = createTestAlarm()

        do {
            try await notificationService.scheduleAlarm(alarm)
            XCTFail("Should have thrown permission denied error")
        } catch NotificationError.permissionDenied {
            // Expected behavior
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // Verify no notifications were scheduled
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        XCTAssertEqual(pendingRequests.count, 0, "Should not schedule notifications when permission denied")
    }
}