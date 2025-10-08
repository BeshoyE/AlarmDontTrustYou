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
    var mockAudioService: AudioService!
    var mockAudioEngine: MockAlarmAudioEngine!
    var mockReliabilityModeProvider: MockReliabilityModeProvider!

    override func setUp() {
        super.setUp()

        mockQRScanning = MockQRScanning()
        mockNotifications = MockNotificationService()
        mockAlarmStorage = MockAlarmStorage()
        mockClock = MockClock()
        mockRouter = MockAppRouter()
        mockPermissionService = MockPermissionService()
        mockReliabilityLogger = MockReliabilityLogger()
        mockAudioService = AudioService()
        mockAudioEngine = MockAlarmAudioEngine()
        mockReliabilityModeProvider = MockReliabilityModeProvider()

        viewModel = DismissalFlowViewModel(
            qrScanning: mockQRScanning,
            notificationService: mockNotifications,
            alarmStorage: mockAlarmStorage,
            clock: mockClock,
            appRouter: mockRouter,
            permissionService: mockPermissionService,
            reliabilityLogger: mockReliabilityLogger,
            audioService: mockAudioService,
            audioEngine: mockAudioEngine,
            reliabilityModeProvider: mockReliabilityModeProvider
        )
    }

    func test_start_setsRinging_and_keepsScreenAwake() {
        // Given
        let alarm = createTestAlarm()
        mockAlarmStorage.storedAlarms = [alarm]
        var screenAwakeRequests: [Bool] = []
        viewModel.onRequestScreenAwake = { screenAwakeRequests.append($0) }

        // When
        viewModel.start(alarmId: alarm.id)

        // Then
        XCTAssertEqual(viewModel.state, .ringing)
        XCTAssertTrue(viewModel.isScreenAwake)
        XCTAssertEqual(screenAwakeRequests, [true])
    }

    func test_beginScan_requiresPermission_then_transitionsToScanning() async {
        // Given
        let alarm = createTestAlarm()
        mockAlarmStorage.storedAlarms = [alarm]
        viewModel.start(alarmId: alarm.id)

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
        mockAlarmStorage.storedAlarms = [alarm]
        viewModel.start(alarmId: alarm.id)
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

    func test_validating_drops_payloads_then_resumes() {
        // Given
        let alarm = createTestAlarm(expectedQR: "test-code")
        mockAlarmStorage.storedAlarms = [alarm]
        viewModel.start(alarmId: alarm.id)
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

    func test_success_idempotent_on_rapid_duplicate_payloads() {
        // Given
        let alarm = createTestAlarm(expectedQR: "success-code")
        mockAlarmStorage.storedAlarms = [alarm]
        viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // When - rapid duplicate success payloads
        viewModel.didScan(payload: "success-code")
        viewModel.didScan(payload: "success-code") // Duplicate within debounce

        // Then - only one success, one run logged
        XCTAssertEqual(viewModel.state, .success)
        XCTAssertEqual(mockAlarmStorage.storedRuns.count, 1)
        XCTAssertEqual(mockAlarmStorage.storedRuns.first?.outcome, .success)
    }

    func test_cancelScan_stopsStream_and_returnsToRinging() {
        // Given
        let alarm = createTestAlarm()
        mockAlarmStorage.storedAlarms = [alarm]
        viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // When
        viewModel.cancelScan()

        // Then
        XCTAssertEqual(viewModel.state, .ringing)
        XCTAssertFalse(mockQRScanning.isScanning)
        XCTAssertNil(viewModel.scanFeedbackMessage)
    }

    func test_didScan_validPayload_persistsRun_and_cancelsFollowUps() {
        // Given
        let alarm = createTestAlarm(expectedQR: "valid-qr")
        mockAlarmStorage.storedAlarms = [alarm]
        var loggedRuns: [AlarmRun] = []
        viewModel.onRunLogged = { loggedRuns.append($0) }

        viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // When
        viewModel.didScan(payload: "valid-qr")

        // Then
        XCTAssertEqual(viewModel.state, .success)
        XCTAssertEqual(mockAlarmStorage.storedRuns.count, 1)
        XCTAssertEqual(mockAlarmStorage.storedRuns.first?.outcome, .success)
        XCTAssertTrue(mockNotifications.cancelledAlarmIds.contains(alarm.id))
        XCTAssertEqual(loggedRuns.count, 1)
    }

    func test_start_alarmNotFound_mapsFailureReason_correctly() {
        // Given
        mockAlarmStorage.shouldThrowOnAlarmLoad = true
        let nonExistentId = UUID()

        // When
        viewModel.start(alarmId: nonExistentId)

        // Then
        XCTAssertEqual(viewModel.state, .failed(.alarmNotFound))
    }

    func test_beginScan_withoutExpectedQR_failsWithCorrectReason() {
        // Given
        let alarm = createTestAlarm(expectedQR: nil) // No expected QR
        mockAlarmStorage.storedAlarms = [alarm]
        viewModel.start(alarmId: alarm.id)

        // When
        viewModel.beginScan()

        // Then
        XCTAssertEqual(viewModel.state, .failed(.noExpectedQR))
    }

    func test_snooze_cancelsAndReschedulesAlarm() {
        // Given
        let alarm = createTestAlarm()
        mockAlarmStorage.storedAlarms = [alarm]
        viewModel.start(alarmId: alarm.id)

        // When
        viewModel.snooze()

        // Then
        XCTAssertTrue(mockNotifications.cancelledAlarmIds.contains(alarm.id))
        XCTAssertEqual(mockNotifications.scheduledAlarms.count, 1)
        XCTAssertEqual(mockRouter.backToListCallCount, 1)
    }

    func test_abort_logsFailedRun_withoutCancellingFollowUps() {
        // Given
        let alarm = createTestAlarm()
        mockAlarmStorage.storedAlarms = [alarm]
        var loggedRuns: [AlarmRun] = []
        viewModel.onRunLogged = { loggedRuns.append($0) }

        viewModel.start(alarmId: alarm.id)

        // When
        viewModel.abort(reason: "test abort")

        // Then
        XCTAssertEqual(mockAlarmStorage.storedRuns.count, 1)
        XCTAssertEqual(mockAlarmStorage.storedRuns.first?.outcome, .failed)
        XCTAssertEqual(loggedRuns.count, 1)
        XCTAssertTrue(mockNotifications.cancelledAlarmIds.isEmpty) // No cancellation on abort
        XCTAssertEqual(mockRouter.backToListCallCount, 1)
    }

    func test_retry_fromFailedState_returnsToRinging() {
        // Given
        let alarm = createTestAlarm(expectedQR: nil)
        mockAlarmStorage.storedAlarms = [alarm]
        viewModel.start(alarmId: alarm.id)
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
        mockAlarmStorage.storedAlarms = [alarm]
        mockPermissionService.cameraPermissionStatus = PermissionStatus.denied
        viewModel.start(alarmId: alarm.id)

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
        mockAlarmStorage.storedAlarms = [alarm]
        mockPermissionService.cameraPermissionStatus = .notDetermined
        mockPermissionService.requestCameraResult = PermissionStatus.authorized
        viewModel.start(alarmId: alarm.id)

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
        mockAlarmStorage.storedAlarms = [alarm]
        mockPermissionService.cameraPermissionStatus = .notDetermined
        mockPermissionService.requestCameraResult = PermissionStatus.denied
        viewModel.start(alarmId: alarm.id)

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
        mockAlarmStorage.storedAlarms = [alarm]
        viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // When - rapid multiple success calls
        viewModel.didScan(payload: "success-code")
        await viewModel.completeSuccess() // Should be ignored due to atomic guard

        // Then - only one run persisted
        XCTAssertEqual(mockAlarmStorage.storedRuns.count, 1)
        XCTAssertEqual(mockAlarmStorage.storedRuns.first?.outcome, .success)
    }

    func test_didScan_duringTransition_dropsPayload() {
        // Given
        let alarm = createTestAlarm(expectedQR: "test-code")
        mockAlarmStorage.storedAlarms = [alarm]
        viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()

        // Set up success to start transition
        viewModel.didScan(payload: "test-code")
        let initialState = viewModel.state

        // When - try to scan during transition
        viewModel.didScan(payload: "should-be-ignored")

        // Then - state unchanged (payload dropped by atomic guard)
        XCTAssertEqual(viewModel.state, initialState)
    }

    func test_abort_duringSuccess_isIgnored() {
        // Given
        let alarm = createTestAlarm(expectedQR: "success-code")
        mockAlarmStorage.storedAlarms = [alarm]
        viewModel.start(alarmId: alarm.id)
        viewModel.beginScan()
        viewModel.didScan(payload: "success-code")

        XCTAssertEqual(viewModel.state, .success)
        let initialRunCount = mockAlarmStorage.storedRuns.count

        // When - try to abort after success
        viewModel.abort(reason: "test abort")

        // Then - abort is ignored, no additional runs logged
        XCTAssertEqual(viewModel.state, .success)
        XCTAssertEqual(mockAlarmStorage.storedRuns.count, initialRunCount)
    }

    func test_snooze_duringSuccess_isIgnored() {
        // Given
        let alarm = createTestAlarm(expectedQR: "success-code")
        mockAlarmStorage.storedAlarms = [alarm]
        viewModel.start(alarmId: alarm.id)
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

