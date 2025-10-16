//
//  AlarmListViewModelTests.swift
//  alarmAppNewTests
//
//  Tests for AlarmListViewModel with unified AlarmScheduling integration (CHUNK 6)
//

import XCTest
@testable import alarmAppNew

@MainActor
final class AlarmListViewModelTests: XCTestCase {

    var viewModel: AlarmListViewModel!
    var mockStorage: MockAlarmStorage!
    var mockPermissionService: MockPermissionService!
    var mockAlarmScheduler: MockAlarmSchedulingForList!
    var mockRefresher: MockRefreshCoordinator!
    var mockVolumeProvider: MockSystemVolumeProvider!
    var mockNotificationService: MockNotificationService!

    override func setUp() async throws {
        try await super.setUp()

        mockStorage = MockAlarmStorage()
        mockPermissionService = MockPermissionService()
        mockAlarmScheduler = MockAlarmSchedulingForList()
        mockRefresher = MockRefreshCoordinator()
        mockVolumeProvider = MockSystemVolumeProvider()
        mockNotificationService = MockNotificationService()

        viewModel = AlarmListViewModel(
            storage: mockStorage,
            permissionService: mockPermissionService,
            alarmScheduler: mockAlarmScheduler,
            refresher: mockRefresher,
            systemVolumeProvider: mockVolumeProvider,
            notificationService: mockNotificationService
        )
    }

    override func tearDown() async throws {
        viewModel = nil
        mockStorage = nil
        mockPermissionService = nil
        mockAlarmScheduler = nil
        mockRefresher = nil
        mockVolumeProvider = nil
        mockNotificationService = nil
        try await super.tearDown()
    }

    // MARK: - CHUNK 6 Tests: AlarmScheduling Integration

    func test_add_schedulesViaAlarmScheduler() async {
        // Given
        let alarm = createTestAlarm(isEnabled: true)

        // When
        viewModel.add(alarm)

        // Wait for async scheduling
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(mockAlarmScheduler.scheduleCalls.count, 1)
        XCTAssertEqual(mockAlarmScheduler.scheduleCalls.first?.id, alarm.id)
    }

    func test_toggle_enablesViaAlarmScheduler() async {
        // Given: Disabled alarm
        let alarm = createTestAlarm(isEnabled: false)
        await mockStorage.setStoredAlarms([alarm])
        viewModel.add(alarm)

        // Clear previous calls
        mockAlarmScheduler.scheduleCalls = []
        mockAlarmScheduler.cancelCalls = []

        // When: Toggle to enable
        viewModel.toggle(alarm)

        // Wait for async scheduling
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(mockAlarmScheduler.scheduleCalls.count, 1)
        XCTAssertEqual(mockAlarmScheduler.cancelCalls.count, 0)
    }

    func test_toggle_disablesViaCancelOnAlarmScheduler() async {
        // Given: Enabled alarm
        let alarm = createTestAlarm(isEnabled: true)
        await mockStorage.setStoredAlarms([alarm])
        viewModel.add(alarm)

        // Clear previous calls
        mockAlarmScheduler.scheduleCalls = []
        mockAlarmScheduler.cancelCalls = []

        // When: Toggle to disable
        viewModel.toggle(alarm)

        // Wait for async cancellation
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(mockAlarmScheduler.cancelCalls.count, 1)
        XCTAssertEqual(mockAlarmScheduler.cancelCalls.first, alarm.id)
        XCTAssertEqual(mockAlarmScheduler.scheduleCalls.count, 0)
    }

    func test_update_reschedulesViaAlarmScheduler() async {
        // Given: Existing enabled alarm
        var alarm = createTestAlarm(isEnabled: true)
        await mockStorage.setStoredAlarms([alarm])
        viewModel.add(alarm)

        // Clear previous calls
        mockAlarmScheduler.scheduleCalls = []

        // When: Update the alarm
        alarm.label = "Updated Label"
        viewModel.update(alarm)

        // Wait for async scheduling
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(mockAlarmScheduler.scheduleCalls.count, 1)
        XCTAssertEqual(mockAlarmScheduler.scheduleCalls.first?.label, "Updated Label")
    }

    func test_delete_cancelsViaAlarmScheduler() async {
        // Given: Enabled alarm
        let alarm = createTestAlarm(isEnabled: true)
        await mockStorage.setStoredAlarms([alarm])
        viewModel.add(alarm)

        // Clear previous calls
        mockAlarmScheduler.cancelCalls = []

        // When: Delete the alarm
        viewModel.delete(alarm)

        // Wait for async cancellation
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(mockAlarmScheduler.cancelCalls.count, 1)
        XCTAssertEqual(mockAlarmScheduler.cancelCalls.first, alarm.id)
    }

    func test_refreshAllAlarms_usesRefresher() async {
        // Given: Multiple alarms
        let alarms = [
            createTestAlarm(isEnabled: true),
            createTestAlarm(isEnabled: false),
            createTestAlarm(isEnabled: true)
        ]
        await mockStorage.setStoredAlarms(alarms)
        viewModel.alarms = alarms

        // When
        await viewModel.refreshAllAlarms()

        // Then
        XCTAssertEqual(mockRefresher.requestRefreshCallCount, 1)
        XCTAssertEqual(mockRefresher.lastRefreshedAlarms?.count, 3)
    }

    func test_schedulingError_setsErrorMessage() async {
        // Given: Scheduler that throws
        mockAlarmScheduler.shouldThrow = true
        let alarm = createTestAlarm(isEnabled: true)

        // When
        viewModel.add(alarm)

        // Wait for async error handling
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - Test Helpers

    private func createTestAlarm(isEnabled: Bool = true) -> Alarm {
        Alarm(
            id: UUID(),
            time: Date().addingTimeInterval(3600),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: "test-qr",
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: isEnabled,
            soundId: "ringtone1",
            volume: 0.8
        )
    }
}

// MARK: - Mock Types

final class MockAlarmSchedulingForList: AlarmScheduling {
    var scheduleCalls: [Alarm] = []
    var cancelCalls: [UUID] = []
    var shouldThrow = false

    func requestAuthorizationIfNeeded() async throws {}

    func schedule(alarm: Alarm) async throws -> String {
        if shouldThrow {
            throw NSError(domain: "TestError", code: 1)
        }
        scheduleCalls.append(alarm)
        return "mock-external-id"
    }

    func cancel(alarmId: UUID) async {
        cancelCalls.append(alarmId)
    }

    func pendingAlarmIds() async -> [UUID] {
        return []
    }

    func stop(alarmId: UUID) async throws {}

    func transitionToCountdown(alarmId: UUID, duration: TimeInterval) async throws {}
}

final class MockRefreshCoordinator: RefreshRequesting {
    var requestRefreshCallCount = 0
    var lastRefreshedAlarms: [Alarm]?

    func requestRefresh(alarms: [Alarm]) async {
        requestRefreshCallCount += 1
        lastRefreshedAlarms = alarms
    }
}
