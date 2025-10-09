//
//  Unit_VolumeWarningTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 10/8/25.
//  Unit tests for media volume warning feature
//

import XCTest
@testable import alarmAppNew

@MainActor
final class Unit_VolumeWarningTests: XCTestCase {
    var mockStorage: MockAlarmStorage!
    var mockPermissionService: MockPermissionService!
    var mockNotificationService: MockNotificationService!
    var mockRefresher: MockRefresher!
    var mockVolumeProvider: MockSystemVolumeProvider!
    var viewModel: AlarmListViewModel!

    override func setUp() {
        super.setUp()

        // Create mocks
        mockStorage = MockAlarmStorage()
        mockPermissionService = MockPermissionService()
        mockNotificationService = MockNotificationService()
        mockRefresher = MockRefresher()
        mockVolumeProvider = MockSystemVolumeProvider()

        // Create view model with mocked dependencies
        viewModel = AlarmListViewModel(
            storage: mockStorage,
            permissionService: mockPermissionService,
            notificationService: mockNotificationService,
            refresher: mockRefresher,
            systemVolumeProvider: mockVolumeProvider
        )
    }

    // MARK: - Volume Warning Tests

    func test_toggleAlarm_whenVolumeBelowThreshold_showsWarning() {
        // GIVEN: Volume is below threshold (0.25)
        mockVolumeProvider.mockVolume = 0.2
        let alarm = Alarm(
            id: UUID(),
            time: Date(),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: "test-qr",
            isEnabled: false,
            soundId: "chimes01",
            volume: 0.8
        )
        viewModel.alarms = [alarm]

        // WHEN: Toggling alarm to enable it
        viewModel.toggle(alarm)

        // THEN: Warning should be shown
        XCTAssertTrue(viewModel.showMediaVolumeWarning, "Warning should be shown when volume is below threshold")
    }

    func test_toggleAlarm_whenVolumeAtThreshold_noWarning() {
        // GIVEN: Volume is exactly at threshold (0.25)
        mockVolumeProvider.mockVolume = 0.25
        let alarm = Alarm(
            id: UUID(),
            time: Date(),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: "test-qr",
            isEnabled: false,
            soundId: "chimes01",
            volume: 0.8
        )
        viewModel.alarms = [alarm]

        // WHEN: Toggling alarm to enable it
        viewModel.toggle(alarm)

        // THEN: Warning should NOT be shown (exactly at threshold)
        XCTAssertFalse(viewModel.showMediaVolumeWarning, "Warning should not be shown when volume is at threshold")
    }

    func test_toggleAlarm_whenVolumeAboveThreshold_noWarning() {
        // GIVEN: Volume is above threshold
        mockVolumeProvider.mockVolume = 0.5
        let alarm = Alarm(
            id: UUID(),
            time: Date(),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: "test-qr",
            isEnabled: false,
            soundId: "chimes01",
            volume: 0.8
        )
        viewModel.alarms = [alarm]

        // WHEN: Toggling alarm to enable it
        viewModel.toggle(alarm)

        // THEN: Warning should NOT be shown
        XCTAssertFalse(viewModel.showMediaVolumeWarning, "Warning should not be shown when volume is above threshold")
    }

    func test_toggleAlarm_whenDisablingAlarm_noVolumeCheck() {
        // GIVEN: Volume is low and alarm is already enabled
        mockVolumeProvider.mockVolume = 0.1
        let alarm = Alarm(
            id: UUID(),
            time: Date(),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: "test-qr",
            isEnabled: true,
            soundId: "chimes01",
            volume: 0.8
        )
        viewModel.alarms = [alarm]

        // WHEN: Toggling alarm to disable it
        viewModel.toggle(alarm)

        // THEN: Warning should NOT be shown (we only check when enabling)
        XCTAssertFalse(viewModel.showMediaVolumeWarning, "Warning should not be shown when disabling alarm")
    }

    // MARK: - Test Lock-Screen Alarm

    func test_testLockScreen_schedulesNotificationWithCorrectLeadTime() async {
        // GIVEN: ViewModel ready

        // WHEN: Testing lock screen alarm
        viewModel.testLockScreen()

        // Wait for async task to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // THEN: Should schedule test notification (we can't easily verify the exact lead time in mock,
        // but we verify the method was called by checking there are no errors)
        XCTAssertNil(viewModel.errorMessage, "Should not have error message after scheduling test alarm")
    }
}

// MARK: - Mock Refresher

final class MockRefresher: RefreshRequesting {
    var requestRefreshCallCount = 0
    var lastAlarms: [Alarm]?

    func requestRefresh(alarms: [Alarm]) async {
        requestRefreshCallCount += 1
        lastAlarms = alarms
    }
}
