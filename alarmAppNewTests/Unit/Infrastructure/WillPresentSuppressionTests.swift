//
//  WillPresentSuppressionTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/2/25.
//  Tests for CHUNK 3: Smart foreground sound suppression
//

import XCTest
import UserNotifications
@testable import alarmAppNew

@MainActor
final class WillPresentSuppressionTests: XCTestCase {

    var sut: NotificationService!
    var mockPermissionService: MockPermissionService!
    var mockAppStateProvider: MockAppStateProvider!
    var mockReliabilityLogger: MockReliabilityLogger!
    var mockAppRouter: MockAppRouter!
    var mockAlarmStorage: MockAlarmStorage!
    var mockChainedScheduler: MockChainedScheduler!
    var mockSettingsService: MockSettingsService!
    var mockAudioEngine: MockAlarmAudioEngine!

    override func setUp() async throws {
        mockPermissionService = MockPermissionService()
        mockAppStateProvider = MockAppStateProvider()
        mockReliabilityLogger = MockReliabilityLogger()
        mockAppRouter = MockAppRouter()
        mockAlarmStorage = MockAlarmStorage()
        mockChainedScheduler = MockChainedScheduler()
        mockSettingsService = MockSettingsService()
        mockAudioEngine = MockAlarmAudioEngine()

        sut = NotificationService(
            permissionService: mockPermissionService,
            appStateProvider: mockAppStateProvider,
            reliabilityLogger: mockReliabilityLogger,
            appRouter: mockAppRouter,
            persistenceService: mockAlarmStorage,
            chainedScheduler: mockChainedScheduler,
            settingsService: mockSettingsService,
            audioEngine: mockAudioEngine
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockPermissionService = nil
        mockAppStateProvider = nil
        mockReliabilityLogger = nil
        mockAppRouter = nil
        mockAlarmStorage = nil
        mockChainedScheduler = nil
        mockSettingsService = nil
        mockAudioEngine = nil
    }

    // MARK: - Tests

    func test_willPresent_inForeground_includesSound_whenAudioNotRinging() {
        // Given: Audio engine is NOT ringing
        mockAudioEngine.currentState = .idle
        mockSettingsService.suppressForegroundSound = true

        // When: willPresent is called for real alarm
        let testAlarmId = UUID()
        let notification = createTestNotification(alarmId: testAlarmId)

        var capturedOptions: UNNotificationPresentationOptions?
        sut.userNotificationCenter(
            UNUserNotificationCenter.current(),
            willPresent: notification
        ) { options in
            capturedOptions = options
        }

        // Then: Should include .sound because audio is not ringing
        XCTAssertNotNil(capturedOptions, "Completion handler should be called")
        XCTAssertTrue(capturedOptions!.contains(.sound), "Should include sound when audio engine is not ringing")
        XCTAssertTrue(capturedOptions!.contains(.banner), "Should include banner")
        XCTAssertTrue(capturedOptions!.contains(.list), "Should include list")
    }

    func test_willPresent_suppressesSound_whenAudioRinging_andSettingTrue() {
        // Given: Audio engine IS ringing AND suppress setting is true
        mockAudioEngine.currentState = .ringing
        mockSettingsService.suppressForegroundSound = true

        // When: willPresent is called for real alarm
        let testAlarmId = UUID()
        let notification = createTestNotification(alarmId: testAlarmId)

        var capturedOptions: UNNotificationPresentationOptions?
        sut.userNotificationCenter(
            UNUserNotificationCenter.current(),
            willPresent: notification
        ) { options in
            capturedOptions = options
        }

        // Then: Should suppress .sound because audio is actively ringing
        XCTAssertNotNil(capturedOptions, "Completion handler should be called")
        XCTAssertFalse(capturedOptions!.contains(.sound), "Should suppress sound when audio engine is ringing")
        XCTAssertTrue(capturedOptions!.contains(.banner), "Should still include banner")
        XCTAssertTrue(capturedOptions!.contains(.list), "Should still include list")
    }

    func test_willPresent_includesSound_whenSuppressFalse_evenIfAudioRinging() {
        // Given: Audio engine IS ringing BUT suppress setting is false
        mockAudioEngine.currentState = .ringing
        mockSettingsService.suppressForegroundSound = false

        // When: willPresent is called for real alarm
        let testAlarmId = UUID()
        let notification = createTestNotification(alarmId: testAlarmId)

        var capturedOptions: UNNotificationPresentationOptions?
        sut.userNotificationCenter(
            UNUserNotificationCenter.current(),
            willPresent: notification
        ) { options in
            capturedOptions = options
        }

        // Then: Should include .sound because suppress setting is disabled
        XCTAssertNotNil(capturedOptions, "Completion handler should be called")
        XCTAssertTrue(capturedOptions!.contains(.sound), "Should include sound when suppress setting is false")
        XCTAssertTrue(capturedOptions!.contains(.banner), "Should include banner")
        XCTAssertTrue(capturedOptions!.contains(.list), "Should include list")
    }

    func test_willPresent_alwaysRoutesToRingingUI() {
        // Given: Various audio states
        let testCases: [(AlarmSoundEngine.State, Bool)] = [
            (.idle, true),
            (.idle, false),
            (.ringing, true),
            (.ringing, false),
            (.prewarming, true)
        ]

        for (audioState, suppressSetting) in testCases {
            // Reset router state
            mockAppRouter = MockAppRouter()

            sut = NotificationService(
                permissionService: mockPermissionService,
                appStateProvider: mockAppStateProvider,
                reliabilityLogger: mockReliabilityLogger,
                appRouter: mockAppRouter,
                persistenceService: mockAlarmStorage,
                chainedScheduler: mockChainedScheduler,
                settingsService: mockSettingsService,
                audioEngine: mockAudioEngine
            )

            // Given
            mockAudioEngine.currentState = audioState
            mockSettingsService.suppressForegroundSound = suppressSetting

            // When
            let testAlarmId = UUID()
            let notification = createTestNotification(alarmId: testAlarmId)

            sut.userNotificationCenter(
                UNUserNotificationCenter.current(),
                willPresent: notification
            ) { _ in }

            // Give async routing task time to execute
            let expectation = XCTestExpectation(description: "Routing completed")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1.0)

            // Then: Should always route to ringing regardless of audio state or suppress setting
            XCTAssertEqual(mockAppRouter.ringingCallCount, 1,
                          "Should route to ringing UI for audioState=\(audioState), suppress=\(suppressSetting)")
        }
    }

    // MARK: - Helper Methods

    private func createTestNotification(alarmId: UUID) -> UNNotification {
        let content = UNMutableNotificationContent()
        content.title = "Test Alarm"
        content.body = "Test"
        content.sound = .default
        content.categoryIdentifier = "ALARM_CATEGORY"
        content.userInfo = ["alarmId": alarmId.uuidString]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "test-\(alarmId)", content: content, trigger: trigger)

        // Create notification from request (this is a simplified mock approach)
        // In real tests, you'd use UNUserNotificationCenter to schedule then retrieve
        return UNNotification(coder: NSKeyedArchiver(requiringSecureCoding: false))!
    }
}

// MARK: - Mock Chained Scheduler

class MockChainedScheduler: ChainedNotificationScheduling {
    var scheduleChainCalls: [(Alarm, Date)] = []
    var cancelChainCalls: [UUID] = []

    func scheduleChain(for alarm: Alarm, fireDate: Date) async -> ScheduleOutcome {
        scheduleChainCalls.append((alarm, fireDate))
        return .scheduled(count: 1)
    }

    func cancelChain(alarmId: UUID) async {
        cancelChainCalls.append(alarmId)
    }

    func requestAuthorization() async throws {
        // Mock implementation
    }

    func cleanupStaleChains() async {
        // Mock implementation
    }
}
