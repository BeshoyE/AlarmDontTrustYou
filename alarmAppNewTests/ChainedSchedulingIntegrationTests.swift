//
//  ChainedSchedulingIntegrationTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/1/25.
//

import XCTest
import UserNotifications
@testable import alarmAppNew

/// E2E integration tests for chained notification scheduling
/// Tests the complete flow from NotificationService → ChainedScheduler → UNUserNotificationCenter
final class ChainedSchedulingIntegrationTests: XCTestCase {

    private var mockNotificationCenter: MockNotificationCenter!
    private var mockSoundCatalog: MockSoundCatalog!
    private var testNotificationIndex: NotificationIndex!
    private var chainPolicy: ChainPolicy!
    private var mockGlobalLimitGuard: MockGlobalLimitGuard!
    private var mockClock: MockClock!
    private var chainedScheduler: ChainedNotificationScheduler!
    private var mockSettingsService: MockSettingsService!
    private var mockPermissionService: MockPermissionService!
    private var mockReliabilityLogger: MockReliabilityLogger!
    private var mockAppRouter: AppRouter!
    private var mockPersistence: MockAlarmStorage!
    private var mockAppStateProvider: AppStateProvider!
    private var notificationService: NotificationService!

    private let testAlarmId = UUID()
    private let testFireDate = Date(timeIntervalSince1970: 1696156800) // Fixed for reproducibility

    override func setUp() async throws {
        try await super.setUp()

        // Set up chained scheduler dependencies
        mockNotificationCenter = MockNotificationCenter()
        mockSoundCatalog = MockSoundCatalog()

        let testSuiteName = "test-integration-\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: testSuiteName)!
        testNotificationIndex = NotificationIndex(defaults: testDefaults)

        let settings = ChainSettings(
            maxChainCount: 5,
            ringWindowSec: 300,
            fallbackSpacingSec: 30,
            minLeadTimeSec: 10
        )
        chainPolicy = ChainPolicy(settings: settings)

        mockGlobalLimitGuard = MockGlobalLimitGuard()
        mockClock = MockClock(fixedNow: testFireDate.addingTimeInterval(-3600))

        chainedScheduler = ChainedNotificationScheduler(
            notificationCenter: mockNotificationCenter,
            soundCatalog: mockSoundCatalog,
            notificationIndex: testNotificationIndex,
            chainPolicy: chainPolicy,
            globalLimitGuard: mockGlobalLimitGuard,
            clock: mockClock
        )

        // Set up NotificationService dependencies
        mockSettingsService = MockSettingsService()
        mockPermissionService = MockPermissionService()
        mockReliabilityLogger = MockReliabilityLogger()
        mockAppRouter = AppRouter()
        mockPersistence = MockAlarmStorage()
        mockAppStateProvider = AppStateProvider()

        notificationService = NotificationService(
            permissionService: mockPermissionService,
            appStateProvider: mockAppStateProvider,
            reliabilityLogger: mockReliabilityLogger,
            appRouter: mockAppRouter,
            persistenceService: mockPersistence,
            chainedScheduler: chainedScheduler,
            settingsService: mockSettingsService
        )
    }

    override func tearDown() async throws {
        mockNotificationCenter = nil
        mockSoundCatalog = nil
        testNotificationIndex = nil
        chainPolicy = nil
        mockGlobalLimitGuard = nil
        mockClock = nil
        chainedScheduler = nil
        mockSettingsService = nil
        mockPermissionService = nil
        mockReliabilityLogger = nil
        mockAppRouter = nil
        mockPersistence = nil
        mockAppStateProvider = nil
        notificationService = nil
        try await super.tearDown()
    }

    // MARK: - Feature Flag Tests

    func test_scheduleAlarm_withFeatureFlagEnabled_usesChainedScheduler() async throws {
        // Given: Feature flag enabled, authorized permissions
        await mockSettingsService.setUseChainedScheduling(true)
        mockPermissionService.authorizationStatus = .authorized
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 5

        let alarm = createTestAlarm()

        // When: Schedule alarm
        try await notificationService.scheduleAlarm(alarm)

        // Then: Chained scheduler was used (multiple notifications scheduled)
        XCTAssertGreaterThan(mockNotificationCenter.scheduledRequests.count, 1,
                            "Chained scheduler should create multiple notifications")
        XCTAssertEqual(mockGlobalLimitGuard.reserveCallCount, 1,
                      "Should have called reserve on global limit guard")
    }

    func test_scheduleAlarm_withFeatureFlagDisabled_usesLegacyPath() async throws {
        // Given: Feature flag disabled, authorized permissions
        await mockSettingsService.setUseChainedScheduling(false)
        mockPermissionService.authorizationStatus = .authorized

        let alarm = createTestAlarm()

        // When: Schedule alarm
        try await notificationService.scheduleAlarm(alarm)

        // Then: Legacy scheduler was used (single notification + nudges)
        // Legacy creates: 1 main + 3 nudges = 4 notifications
        XCTAssertEqual(mockNotificationCenter.addRequestCallCount, 4,
                      "Legacy path should create 4 notifications (main + 3 nudges)")
        XCTAssertEqual(mockGlobalLimitGuard.reserveCallCount, 0,
                      "Legacy path should not use global limit guard")
    }

    // MARK: - Permission Handling Tests

    func test_scheduleAlarm_withDeniedPermissions_throwsPermissionError() async {
        // Given: Permissions denied
        mockPermissionService.authorizationStatus = .denied
        mockNotificationCenter.authorizationStatus = .denied
        await mockSettingsService.setUseChainedScheduling(true)

        let alarm = createTestAlarm()

        // When/Then: Should throw permission denied error
        do {
            try await notificationService.scheduleAlarm(alarm)
            XCTFail("Should have thrown NotificationError.permissionDenied")
        } catch let error as NotificationError {
            XCTAssertEqual(error, .permissionDenied)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Global Limit Tests

    func test_scheduleAlarm_withGlobalLimitExceeded_throwsSystemLimitError() async {
        // Given: Global limit exceeded (no slots available)
        await mockSettingsService.setUseChainedScheduling(true)
        mockPermissionService.authorizationStatus = .authorized
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 0 // No slots available

        let alarm = createTestAlarm()

        // When/Then: Should throw system limit exceeded error
        do {
            try await notificationService.scheduleAlarm(alarm)
            XCTFail("Should have thrown NotificationError.systemLimitExceeded")
        } catch let error as NotificationError {
            XCTAssertEqual(error, .systemLimitExceeded)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_scheduleAlarm_withPartialSlotsAvailable_trimsChain() async throws {
        // Given: Only 3 slots available (out of 5 requested)
        await mockSettingsService.setUseChainedScheduling(true)
        mockPermissionService.authorizationStatus = .authorized
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 3

        let alarm = createTestAlarm()

        // When: Schedule alarm
        try await notificationService.scheduleAlarm(alarm)

        // Then: Should schedule 3 notifications (trimmed)
        XCTAssertEqual(mockNotificationCenter.scheduledRequests.count, 3,
                      "Should have scheduled 3 notifications (trimmed from 5)")

        // And: Should log trimmed outcome
        let loggedEvents = mockReliabilityLogger.loggedEvents.filter { $0.details["event"] == "chained_schedule_trimmed" }
        XCTAssertEqual(loggedEvents.count, 1, "Should have logged trimmed outcome")
    }

    // MARK: - Identifier & Index Tests

    func test_scheduleAlarm_createsStableIdentifiers() async throws {
        // Given: Chained scheduling enabled
        await mockSettingsService.setUseChainedScheduling(true)
        mockPermissionService.authorizationStatus = .authorized
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 5

        let alarm = createTestAlarm()

        // When: Schedule alarm
        try await notificationService.scheduleAlarm(alarm)

        // Then: All identifiers should follow the stable format
        let scheduledIDs = mockNotificationCenter.scheduledRequests.map { $0.identifier }
        for id in scheduledIDs {
            XCTAssertTrue(id.starts(with: "alarm-\(alarm.id.uuidString)-occ-"),
                         "Identifier should follow stable format: \(id)")
        }
    }

    func test_scheduleAlarm_savesIdentifiersToIndex() async throws {
        // Given: Chained scheduling enabled
        await mockSettingsService.setUseChainedScheduling(true)
        mockPermissionService.authorizationStatus = .authorized
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 5

        let alarm = createTestAlarm()

        // When: Schedule alarm
        try await notificationService.scheduleAlarm(alarm)

        // Then: Identifiers should be saved to index
        let savedIdentifiers = testNotificationIndex.loadIdentifiers(alarmId: alarm.id)
        XCTAssertEqual(savedIdentifiers.count, 5,
                      "Should have saved 5 identifiers to index")
    }

    // MARK: - Logging Tests

    func test_scheduleAlarm_logsOutcomeWithContext() async throws {
        // Given: Chained scheduling enabled
        await mockSettingsService.setUseChainedScheduling(true)
        mockPermissionService.authorizationStatus = .authorized
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 5

        let alarm = createTestAlarm()

        // When: Schedule alarm
        try await notificationService.scheduleAlarm(alarm)

        // Then: Should have logged outcome with structured context
        let scheduledEvents = mockReliabilityLogger.loggedEvents.filter {
            $0.details["event"] == "chained_schedule_success"
        }
        XCTAssertEqual(scheduledEvents.count, 1, "Should have logged success outcome")

        let event = scheduledEvents[0]
        XCTAssertEqual(event.alarmId, alarm.id)
        XCTAssertNotNil(event.details["fireDate"])
        XCTAssertEqual(event.details["count"], "5")
        XCTAssertEqual(event.details["useChainedScheduling"], "true")
    }

    // MARK: - Async Preservation Tests

    func test_scheduleAlarm_preservesAsyncBehavior() async throws {
        // Given: Chained scheduling enabled
        await mockSettingsService.setUseChainedScheduling(true)
        mockPermissionService.authorizationStatus = .authorized
        mockNotificationCenter.authorizationStatus = .authorized
        mockGlobalLimitGuard.reserveReturnValue = 5

        let alarm = createTestAlarm()

        // When: Schedule alarm (should not block)
        let startTime = Date()
        try await notificationService.scheduleAlarm(alarm)
        let endTime = Date()

        // Then: Should complete quickly (async, no blocking)
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 1.0,
                         "Scheduling should complete quickly without blocking")
    }

    // MARK: - Helper Methods

    private func createTestAlarm() -> Alarm {
        return Alarm(
            id: testAlarmId,
            time: testFireDate,
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: "test-qr-code",
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: "chimes01",
            soundName: nil,
            volume: 0.8
        )
    }
}
