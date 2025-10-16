//
//  DismissalFlowViewModelTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 9/6/25.
//  Unit tests using only public intents - no private state manipulation
//

import XCTest
@testable import alarmAppNew
import UserNotifications
import Combine

@MainActor
class DismissalFlowViewModelTests: XCTestCase {
    var viewModel: DismissalFlowViewModel!
    var mockQRScanning: MockQRScanning!
    var mockNotifications: MockNotificationService!
    var mockAlarmStorage: MockAlarmStorage!
    var mockClock: MockClock!
    var mockRouter: MockAppRouter!
    var mockPermissionService: MockPermissionService!
    var mockReliabilityLogger: MockReliabilityLogger!
    var mockAudioEngine: MockAlarmAudioEngine!
    var mockReliabilityModeProvider: MockReliabilityModeProvider!
    var mockDismissedRegistry: DismissedRegistry!
    var mockSettingsService: MockSettingsService!
    var mockAlarmScheduler: MockAlarmScheduling!
    var mockAlarmRunStore: AlarmRunStore!
    var mockIdleTimerController: MockIdleTimerController!

    override func setUp() {
        super.setUp()

        mockQRScanning = MockQRScanning()
        mockNotifications = MockNotificationService()
        mockAlarmStorage = MockAlarmStorage()
        mockClock = MockClock()
        mockRouter = MockAppRouter()
        mockPermissionService = MockPermissionService()
        mockReliabilityLogger = MockReliabilityLogger()
        mockAudioEngine = MockAlarmAudioEngine()
        mockReliabilityModeProvider = MockReliabilityModeProvider()
        mockDismissedRegistry = DismissedRegistry()
        mockSettingsService = MockSettingsService()
        mockAlarmScheduler = MockAlarmScheduling()
        mockAlarmRunStore = AlarmRunStore()
        mockIdleTimerController = MockIdleTimerController()

        viewModel = DismissalFlowViewModel(
            qrScanning: mockQRScanning,
            notificationService: mockNotifications,
            alarmStorage: mockAlarmStorage,
            clock: mockClock,
            appRouter: mockRouter,
            permissionService: mockPermissionService,
            reliabilityLogger: mockReliabilityLogger,
            audioEngine: mockAudioEngine,
            reliabilityModeProvider: mockReliabilityModeProvider,
            dismissedRegistry: mockDismissedRegistry,
            settingsService: mockSettingsService,
            alarmScheduler: mockAlarmScheduler,
            alarmRunStore: mockAlarmRunStore,
            idleTimerController: mockIdleTimerController
        )
    }

    func test_start_setsRinging_and_keepsScreenAwake() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])

        // When
        await viewModel.start(alarmId: alarm.id)

        // Then
        XCTAssertEqual(viewModel.state, .ringing)
        XCTAssertTrue(viewModel.isScreenAwake)
        XCTAssertEqual(mockIdleTimerController.setIdleTimerCalls, [true])
    }

    func test_beginScan_requiresPermission_then_transitionsToScanning() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)

        // When
        viewModel.beginScan()

        // Wait for async permission check
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(viewModel.state, .scanning)
        XCTAssertTrue(mockQRScanning.isScanning)
    }

    func test_mismatch_then_match_continuesScanning_and_succeeds() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "correct-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // Wait for scanning state
        try? await Task.sleep(nanoseconds: 100_000_000)

        // When - first scan mismatch
        viewModel.didScan(payload: "wrong-code")

        // Then - should show feedback but return to scanning
        XCTAssertEqual(viewModel.state, .validating)
        XCTAssertNotNil(viewModel.scanFeedbackMessage)

        // Wait for transition back to scanning
        try? await Task.sleep(nanoseconds: 1_100_000_000) // > 1 second

        XCTAssertEqual(viewModel.state, .scanning)
        XCTAssertNil(viewModel.scanFeedbackMessage)

        // When - second scan matches
        viewModel.didScan(payload: "correct-code")

        // Then - should succeed
        XCTAssertEqual(viewModel.state, .success)
    }

    func test_validating_drops_payloads_then_resumes() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "test-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // When - transition to validating
        viewModel.didScan(payload: "wrong-code")
        XCTAssertEqual(viewModel.state, .validating)

        // When - try to scan while validating
        let initialState = viewModel.state
        viewModel.didScan(payload: "should-be-ignored")

        // Then - state unchanged (payload dropped)
        XCTAssertEqual(viewModel.state, initialState)
    }

    func test_success_idempotent_on_rapid_duplicate_payloads() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "success-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // When - rapid duplicate success payloads
        viewModel.didScan(payload: "success-code")
        viewModel.didScan(payload: "success-code") // Duplicate within debounce

        // Then - only one success, one run logged
        XCTAssertEqual(viewModel.state, .success)
        XCTAssertEqual(await mockAlarmStorage.getStoredRuns().count, 1)
        XCTAssertEqual(await mockAlarmStorage.getStoredRuns().first?.outcome, .success)
    }

    func test_cancelScan_stopsStream_and_returnsToRinging() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // When
        viewModel.cancelScan()

        // Then
        XCTAssertEqual(viewModel.state, .ringing)
        XCTAssertFalse(mockQRScanning.isScanning)
        XCTAssertNil(viewModel.scanFeedbackMessage)
    }

    func test_didScan_validPayload_persistsRun_and_cancelsFollowUps() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "valid-qr")
        await mockAlarmStorage.setStoredAlarms([alarm])
        var loggedRuns: [AlarmRun] = []
        viewModel.onRunLogged = { loggedRuns.append($0) }

        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // When
        viewModel.didScan(payload: "valid-qr")

        // Then
        XCTAssertEqual(viewModel.state, .success)
        XCTAssertEqual(await mockAlarmStorage.getStoredRuns().count, 1)
        XCTAssertEqual(await mockAlarmStorage.getStoredRuns().first?.outcome, .success)
        XCTAssertTrue(mockNotifications.cancelledAlarmIds.contains(alarm.id))
        XCTAssertEqual(loggedRuns.count, 1)
    }

    func test_start_alarmNotFound_mapsFailureReason_correctly() async {
        // Given
        await mockAlarmStorage.setShouldThrow(true)
        let nonExistentId = UUID()

        // When
        await viewModel.start(alarmId: nonExistentId)

        // Then
        XCTAssertEqual(viewModel.state, .failed(.alarmNotFound))
    }

    func test_beginScan_withoutExpectedQR_failsWithCorrectReason() async {
        // Given
        let alarm = createTestAlarm(expectedQR: nil) // No expected QR
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)

        // When
        viewModel.beginScan()

        // Then
        XCTAssertEqual(viewModel.state, .failed(.noExpectedQR))
    }

    func test_snooze_cancelsAndReschedulesAlarm() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)

        // When
        viewModel.snooze()

        // Then
        XCTAssertTrue(mockNotifications.cancelledAlarmIds.contains(alarm.id))
        XCTAssertEqual(mockNotifications.scheduledAlarms.count, 1)
        XCTAssertEqual(mockRouter.backToListCallCount, 1)
    }

    func test_abort_logsFailedRun_withoutCancellingFollowUps() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])
        var loggedRuns: [AlarmRun] = []
        viewModel.onRunLogged = { loggedRuns.append($0) }

        await viewModel.start(alarmId: alarm.id)

        // When
        viewModel.abort(reason: "test abort")

        // Then
        XCTAssertEqual(await mockAlarmStorage.getStoredRuns().count, 1)
        XCTAssertEqual(await mockAlarmStorage.getStoredRuns().first?.outcome, .failed)
        XCTAssertEqual(loggedRuns.count, 1)
        XCTAssertTrue(mockNotifications.cancelledAlarmIds.isEmpty) // No cancellation on abort
        XCTAssertEqual(mockRouter.backToListCallCount, 1)
    }

    func test_retry_fromFailedState_returnsToRinging() async {
        // Given
        let alarm = createTestAlarm(expectedQR: nil)
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan() // Will fail with noExpectedQR

        XCTAssertEqual(viewModel.state, .failed(.noExpectedQR))

        // When
        viewModel.retry()

        // Then
        XCTAssertEqual(viewModel.state, .ringing)
        XCTAssertNil(viewModel.scanFeedbackMessage)
    }

    // MARK: - Camera Permission Tests

    func test_beginScan_cameraPermissionDenied_failsWithPermissionDenied() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])
        mockPermissionService.cameraPermissionStatus = PermissionStatus.denied
        await viewModel.start(alarmId: alarm.id)

        // When
        viewModel.beginScan()

        // Wait for async permission check
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(viewModel.state, .failed(.permissionDenied))
        XCTAssertFalse(mockQRScanning.isScanning)
    }

    func test_beginScan_cameraPermissionNotDetermined_requestsAndStartsScanning() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])
        mockPermissionService.cameraPermissionStatus = .notDetermined
        mockPermissionService.requestCameraResult = PermissionStatus.authorized
        await viewModel.start(alarmId: alarm.id)

        // When
        viewModel.beginScan()

        // Wait for async permission flow
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Then
        XCTAssertTrue(mockPermissionService.didRequestCameraPermission)
        XCTAssertEqual(viewModel.state, .scanning)
        XCTAssertTrue(mockQRScanning.isScanning)
    }

    func test_beginScan_cameraPermissionNotDetermined_requestDenied_failsWithPermissionDenied() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])
        mockPermissionService.cameraPermissionStatus = .notDetermined
        mockPermissionService.requestCameraResult = PermissionStatus.denied
        await viewModel.start(alarmId: alarm.id)

        // When
        viewModel.beginScan()

        // Wait for async permission flow
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Then
        XCTAssertTrue(mockPermissionService.didRequestCameraPermission)
        XCTAssertEqual(viewModel.state, .failed(.permissionDenied))
        XCTAssertFalse(mockQRScanning.isScanning)
    }

    // MARK: - Atomic Transition Tests

    func test_completeSuccess_atomicGuard_preventsDoubleExecution() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "success-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // When - rapid multiple success calls
        viewModel.didScan(payload: "success-code")
        await viewModel.completeSuccess() // Should be ignored due to atomic guard

        // Then - only one run persisted
        XCTAssertEqual(await mockAlarmStorage.getStoredRuns().count, 1)
        XCTAssertEqual(await mockAlarmStorage.getStoredRuns().first?.outcome, .success)
    }

    func test_didScan_duringTransition_dropsPayload() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "test-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // Set up success to start transition
        viewModel.didScan(payload: "test-code")
        let initialState = viewModel.state

        // When - try to scan during transition
        viewModel.didScan(payload: "should-be-ignored")

        // Then - state unchanged (payload dropped by atomic guard)
        XCTAssertEqual(viewModel.state, initialState)
    }

    func test_abort_duringSuccess_isIgnored() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "success-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()
        viewModel.didScan(payload: "success-code")

        XCTAssertEqual(viewModel.state, .success)
        let initialRunCount = await mockAlarmStorage.getStoredRuns().count

        // When - try to abort after success
        viewModel.abort(reason: "test abort")

        // Then - abort is ignored, no additional runs logged
        XCTAssertEqual(viewModel.state, .success)
        XCTAssertEqual(await mockAlarmStorage.getStoredRuns().count, initialRunCount)
    }

    func test_snooze_duringSuccess_isIgnored() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "success-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()
        viewModel.didScan(payload: "success-code")

        XCTAssertEqual(viewModel.state, .success)
        let initialScheduledCount = mockNotifications.scheduledAlarms.count

        // When - try to snooze after success
        viewModel.snooze()

        // Then - snooze is ignored
        XCTAssertEqual(viewModel.state, .success)
        XCTAssertEqual(mockNotifications.scheduledAlarms.count, initialScheduledCount)
    }

    // MARK: - CHUNK 5: Stop/Snooze Tests

    func test_canStopAlarm_isFalse_whenChallengesNotComplete() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)

        // Then
        XCTAssertFalse(viewModel.canStopAlarm, "Should not be able to stop before completing challenges")
    }

    func test_canStopAlarm_isTrue_whenChallengesComplete() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "test-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // When - complete QR challenge
        viewModel.didScan(payload: "test-code")

        // Then
        XCTAssertTrue(viewModel.canStopAlarm, "Should be able to stop after completing challenges")
    }

    func test_canSnooze_isTrue_whenRinging() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])

        // When
        await viewModel.start(alarmId: alarm.id)

        // Then
        XCTAssertTrue(viewModel.canSnooze, "Should be able to snooze while ringing")
    }

    func test_canSnooze_isFalse_afterSuccess() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "test-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // When - complete alarm
        viewModel.didScan(payload: "test-code")

        // Then
        XCTAssertFalse(viewModel.canSnooze, "Should not be able to snooze after success")
    }

    func test_stopAlarm_callsAlarmSchedulerStop() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "test-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()
        viewModel.didScan(payload: "test-code")

        // When
        await viewModel.stopAlarm()

        // Then
        XCTAssertEqual(mockAlarmScheduler.stopCalls.count, 1, "Should call alarmScheduler.stop()")
        XCTAssertEqual(mockAlarmScheduler.stopCalls.first, alarm.id)
    }

    func test_snooze_callsTransitionToCountdown() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)

        // When
        await viewModel.snooze(requestedDuration: 300)

        // Then
        XCTAssertEqual(mockAlarmScheduler.transitionToCountdownCalls.count, 1)
        let (alarmId, duration) = mockAlarmScheduler.transitionToCountdownCalls.first!
        XCTAssertEqual(alarmId, alarm.id)
        XCTAssertGreaterThan(duration, 0, "Duration should be positive")
    }

    func test_stopAlarm_logsReliabilityEvent() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "test-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()
        viewModel.didScan(payload: "test-code")

        // When
        await viewModel.stopAlarm()

        // Then
        let dismissSuccessEvents = mockReliabilityLogger.loggedEvents.filter { $0.event == .dismissSuccess }
        XCTAssertEqual(dismissSuccessEvents.count, 1, "Should log dismissSuccess event")
    }

    func test_snooze_logsReliabilityEvent() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])
        await viewModel.start(alarmId: alarm.id)

        // When
        await viewModel.snooze()

        // Then
        let snoozeEvents = mockReliabilityLogger.loggedEvents.filter { $0.event == .snoozeSet }
        XCTAssertEqual(snoozeEvents.count, 1, "Should log snoozeSet event")
    }

    func test_stopAlarm_whenSchedulerThrows_logsError() async {
        // Given
        let alarm = createTestAlarm(expectedQR: "test-code")
        await mockAlarmStorage.setStoredAlarms([alarm])
        mockAlarmScheduler.shouldThrowOnStop = true
        await viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()
        viewModel.didScan(payload: "test-code")

        // When
        await viewModel.stopAlarm()

        // Then
        let failedEvents = mockReliabilityLogger.loggedEvents.filter { $0.event == .stopFailed }
        XCTAssertEqual(failedEvents.count, 1, "Should log stopFailed event")
        XCTAssertEqual(viewModel.phase, .failed("Couldn't stop alarm"))
    }

    func test_snooze_whenSchedulerThrows_logsError() async {
        // Given
        let alarm = createTestAlarm()
        await mockAlarmStorage.setStoredAlarms([alarm])
        mockAlarmScheduler.shouldThrowOnTransition = true
        await viewModel.start(alarmId: alarm.id)

        // When
        await viewModel.snooze()

        // Then
        let failedEvents = mockReliabilityLogger.loggedEvents.filter { $0.event == .snoozeFailed }
        XCTAssertEqual(failedEvents.count, 1, "Should log snoozeFailed event")
        XCTAssertEqual(viewModel.phase, .failed("Couldn't snooze"))
    }

    // MARK: - Test Helpers

    private func createTestAlarm(expectedQR: String? = "test-qr") -> Alarm {
        Alarm(
            id: UUID(),
            time: Date(),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: expectedQR,
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: "chimes01",
            volume: 0.8
        )
    }
}

// Test mocks are defined in TestMocks.swift

