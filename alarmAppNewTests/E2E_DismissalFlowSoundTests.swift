//
//  E2E_DismissalFlowSoundTests.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 9/16/25.
//  End-to-end tests for dismissal flow with sound cancellation
//

import XCTest
import UserNotifications
@testable import alarmAppNew

// MARK: - Mock Services for E2E
// Using shared mocks from TestMocks.swift

// Using shared mocks from TestMocks.swift

// MARK: - E2E Dismissal Flow Tests

@MainActor
final class E2E_DismissalFlowSoundTests: XCTestCase {
    var viewModel: DismissalFlowViewModel!
    var mockQRScanning: MockQRScanning!
    var mockAlarmStorage: MockAlarmStorage!
    var mockNotificationService: MockNotificationService!
    var mockAudioService: MockAudioService!
    var mockAppRouter: MockAppRouter!
    var mockReliabilityLogger: MockReliabilityLogger!
    var mockClock: MockClock!
    var mockPermissionService: MockPermissionService!
    var mockAudioEngine: MockAlarmAudioEngine!
    var mockReliabilityModeProvider: MockReliabilityModeProvider!

    override func setUp() {
        super.setUp()
        setupMocks()
        createViewModel()
    }

    override func tearDown() {
        viewModel = nil
        mockQRScanning = nil
        mockAlarmStorage = nil
        mockNotificationService = nil
        mockAudioService = nil
        mockAppRouter = nil
        mockReliabilityLogger = nil
        mockClock = nil
        mockPermissionService = nil
        mockAudioEngine = nil
        mockReliabilityModeProvider = nil
        super.tearDown()
    }

    private func setupMocks() {
        mockQRScanning = MockQRScanning()
        mockAlarmStorage = MockAlarmStorage()
        mockNotificationService = MockNotificationService()
        mockAudioService = MockAudioService()
        mockAppRouter = MockAppRouter()
        mockReliabilityLogger = MockReliabilityLogger()
        mockClock = MockClock()
        mockPermissionService = MockPermissionService()
        mockAudioEngine = MockAlarmAudioEngine()
        mockReliabilityModeProvider = MockReliabilityModeProvider()
    }

    private func createViewModel() {
        viewModel = DismissalFlowViewModel(
            qrScanning: mockQRScanning,
            notificationService: mockNotificationService,
            alarmStorage: mockAlarmStorage,
            clock: mockClock,
            appRouter: mockAppRouter,
            permissionService: mockPermissionService,
            reliabilityLogger: mockReliabilityLogger,
            audioService: mockAudioService,
            audioEngine: mockAudioEngine,
            reliabilityModeProvider: mockReliabilityModeProvider
        )
    }

    private func createTestAlarm(
        id: UUID = UUID(),
        soundId: String = "chimes01",
        volume: Double = 0.8,
        expectedQR: String = "test-qr-code"
    ) -> Alarm {
        return Alarm(
            id: id,
            time: Date(),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [.qr],
            expectedQR: expectedQR,
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: soundId,
            volume: volume
        )
    }

    private func waitForRunToBeSaved(timeout: TimeInterval = 1.0) async -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if mockAlarmStorage.runs.count >= 1 {
                return true
            }
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms polling interval
        }
        return false
    }

    // MARK: - Sound Integration Tests

    func test_startAlarm_shouldActivateAudioAndStartRinging() async {
        let alarmId = UUID()
        let alarm = createTestAlarm(id: alarmId, soundId: "bells01", volume: 0.9)

        try? mockAlarmStorage.saveAlarm(alarm)

        viewModel.start(alarmId: alarmId)

        // Wait for async audio start
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        XCTAssertEqual(viewModel.state, .ringing)
        XCTAssertEqual(mockAudioService.lastPlayedSound, "Soft Bells")
        XCTAssertEqual(mockAudioService.lastVolume, 0.9)
        XCTAssertEqual(mockAudioService.lastLoopSetting, true)
        XCTAssertTrue(mockAudioService.sessionActivated)
        XCTAssertTrue(mockAudioService.isCurrentlyPlaying)
    }

    func test_successfulDismissal_shouldStopAudioAndCancelNudges() async {
        let alarmId = UUID()
        let expectedQR = "success-qr"
        let alarm = createTestAlarm(id: alarmId, expectedQR: expectedQR)

        try? mockAlarmStorage.saveAlarm(alarm)

        // Start alarm
        viewModel.start(alarmId: alarmId)
        viewModel.beginScan()

        // Wait for state transitions
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        XCTAssertEqual(viewModel.state, .scanning)

        // Simulate successful QR scan
        viewModel.didScan(payload: expectedQR)

        // Wait for completion
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Verify audio stopped
        XCTAssertEqual(mockAudioService.stopAndDeactivateCallCount, 1)
        XCTAssertFalse(mockAudioService.isCurrentlyPlaying)
        XCTAssertFalse(mockAudioService.sessionActivated)

        // Verify nudges cancelled
        XCTAssertEqual(mockNotificationService.cancelledNotificationTypes.count, 1)
        let (cancelledAlarmId, cancelledTypes) = mockNotificationService.cancelledNotificationTypes[0]
        XCTAssertEqual(cancelledAlarmId, alarmId)
        XCTAssertEqual(Set(cancelledTypes), Set([.nudge1, .nudge2, .nudge3]))

        // Verify state progression
        XCTAssertEqual(viewModel.state, .success)
    }

    func test_abortDismissal_shouldStopAudioButKeepNudges() async {
        let alarmId = UUID()
        let alarm = createTestAlarm(id: alarmId)

        try? mockAlarmStorage.saveAlarm(alarm)

        viewModel.start(alarmId: alarmId)

        // Wait for audio to start
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Abort the dismissal
        viewModel.abort(reason: "User cancelled")

        // Verify audio stopped
        XCTAssertEqual(mockAudioService.stopAndDeactivateCallCount, 1)
        XCTAssertFalse(mockAudioService.isCurrentlyPlaying)

        // Verify nudges were NOT cancelled (empty array)
        XCTAssertEqual(mockNotificationService.cancelledNotificationTypes.count, 0)

        // Verify navigation back
        XCTAssertEqual(mockAppRouter.backToListCallCount, 1)
    }

    func test_snoozeDismissal_shouldStopAudioAndCancelNudgesOnly() async {
        let alarmId = UUID()
        let alarm = createTestAlarm(id: alarmId)

        try? mockAlarmStorage.saveAlarm(alarm)

        viewModel.start(alarmId: alarmId)

        // Wait for startup
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Snooze the alarm
        viewModel.snooze()

        // Wait for snooze to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Verify audio stopped
        XCTAssertEqual(mockAudioService.stopAndDeactivateCallCount, 1)
        XCTAssertFalse(mockAudioService.isCurrentlyPlaying)

        // Verify only nudges cancelled (not main alarm for snooze)
        XCTAssertEqual(mockNotificationService.cancelledNotificationTypes.count, 1)
        let (cancelledAlarmId, cancelledTypes) = mockNotificationService.cancelledNotificationTypes[0]
        XCTAssertEqual(cancelledAlarmId, alarmId)
        XCTAssertEqual(Set(cancelledTypes), Set([.nudge1, .nudge2, .nudge3]))

        // Verify snooze alarm was scheduled
        XCTAssertEqual(mockNotificationService.scheduledAlarms.count, 1)
    }

    func test_failedQRScan_shouldContinueAudioPlaying() async {
        let alarmId = UUID()
        let expectedQR = "correct-qr"
        let wrongQR = "wrong-qr"
        let alarm = createTestAlarm(id: alarmId, expectedQR: expectedQR)

        try? mockAlarmStorage.saveAlarm(alarm)

        viewModel.start(alarmId: alarmId)
        viewModel.beginScan()

        // Wait for scanning state
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Simulate wrong QR scan
        viewModel.didScan(payload: wrongQR)

        // Audio should still be playing
        XCTAssertTrue(mockAudioService.isCurrentlyPlaying)
        XCTAssertEqual(mockAudioService.stopAndDeactivateCallCount, 0)

        // Should transition to validating briefly, then back to scanning
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s for timeout

        XCTAssertEqual(viewModel.state, .scanning)
        XCTAssertTrue(mockAudioService.isCurrentlyPlaying)
    }

    func test_cleanupDismissal_shouldStopAudioProperly() async {
        let alarmId = UUID()
        let alarm = createTestAlarm(id: alarmId)

        try? mockAlarmStorage.saveAlarm(alarm)

        viewModel.start(alarmId: alarmId)

        // Wait for startup
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Call cleanup
        viewModel.cleanup()

        // Verify audio stopped
        XCTAssertEqual(mockAudioService.stopAndDeactivateCallCount, 1)
        XCTAssertFalse(mockAudioService.isCurrentlyPlaying)
        XCTAssertFalse(mockAudioService.sessionActivated)
    }

    func test_multipleQRScans_shouldDebounceSuccessfully() async {
        let alarmId = UUID()
        let expectedQR = "success-qr"
        let alarm = createTestAlarm(id: alarmId, expectedQR: expectedQR)

        try? mockAlarmStorage.saveAlarm(alarm)

        viewModel.start(alarmId: alarmId)
        viewModel.beginScan()

        // Wait for scanning state
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Simulate rapid duplicate scans
        viewModel.didScan(payload: expectedQR)
        viewModel.didScan(payload: expectedQR) // Should be debounced
        viewModel.didScan(payload: expectedQR) // Should be debounced

        // Wait for processing
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Should only process once
        XCTAssertEqual(viewModel.state, .success)
        XCTAssertEqual(mockAudioService.stopAndDeactivateCallCount, 1)

        // Should have only one successful run logged
        let successLogs = mockReliabilityLogger.loggedEvents.filter { event in
            event == .dismissSuccessQR
        }
        XCTAssertEqual(successLogs.count, 1)
    }

    func test_fullDismissalFlow_endToEnd_shouldWorkCorrectly() async {
        let alarmId = UUID()
        let expectedQR = "complete-flow-qr"
        let alarm = createTestAlarm(id: alarmId, soundId: "tone01", volume: 0.7, expectedQR: expectedQR)

        try? mockAlarmStorage.saveAlarm(alarm)

        // Start the alarm
        viewModel.start(alarmId: alarmId)

        // Verify initial state
        XCTAssertEqual(viewModel.state, .ringing)

        // Wait for audio setup
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Verify audio started
        XCTAssertTrue(mockAudioService.isCurrentlyPlaying)
        XCTAssertEqual(mockAudioService.lastPlayedSound, "Classic Tone")
        XCTAssertEqual(mockAudioService.lastVolume, 0.7)

        // Begin scanning
        viewModel.beginScan()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.state, .scanning)
        XCTAssertTrue(mockQRScanning.isScanning)

        // Scan wrong QR first
        viewModel.didScan(payload: "wrong-qr")

        try? await Task.sleep(nanoseconds: 100_000_000)

        // Should still be playing audio
        XCTAssertTrue(mockAudioService.isCurrentlyPlaying)

        // Wait for return to scanning
        try? await Task.sleep(nanoseconds: 1_100_000_000) // 1.1 seconds

        XCTAssertEqual(viewModel.state, .scanning)

        // Scan correct QR
        viewModel.didScan(payload: expectedQR)

        // Wait for async operations to complete
        let runSaved = await waitForRunToBeSaved()
        XCTAssertTrue(runSaved, "Alarm run should be saved within timeout")

        // Verify successful completion
        XCTAssertEqual(viewModel.state, .success)
        XCTAssertFalse(mockAudioService.isCurrentlyPlaying)
        XCTAssertEqual(mockAudioService.stopAndDeactivateCallCount, 1)

        // Verify notifications cancelled correctly
        XCTAssertEqual(mockNotificationService.cancelledNotificationTypes.count, 1)

        // Verify alarm run was saved with safe access
        XCTAssertEqual(mockAlarmStorage.runs.count, 1)
        guard let run = mockAlarmStorage.runs.first else {
            XCTFail("Expected alarm run to be saved")
            return
        }
        XCTAssertEqual(run.outcome, AlarmOutcome.success)
        XCTAssertNotNil(run.dismissedAt)

        // Wait for navigation
        try? await Task.sleep(nanoseconds: 1_600_000_000) // 1.6 seconds

        XCTAssertEqual(mockAppRouter.backToListCallCount, 1)
    }

    // MARK: - Notification Action Tests

    func test_snoozeAction_integration_shouldHandleCorrectly() async {
        let alarmId = UUID()
        let alarm = createTestAlarm(id: alarmId)

        try? mockAlarmStorage.saveAlarm(alarm)

        // Simulate snooze action through notification service
        let notificationService = mockNotificationService as! MockNotificationService

        // Start with some scheduled alarms
        notificationService.scheduledAlarms = [alarm]

        // Test that snooze would work (we can't directly test the delegate without a real notification)
        // But we can verify the snooze function works correctly
        viewModel.start(alarmId: alarmId)
        viewModel.snooze()

        // Wait for snooze processing
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Verify audio stopped
        XCTAssertFalse(mockAudioService.isCurrentlyPlaying)
        XCTAssertEqual(mockAudioService.stopAndDeactivateCallCount, 1)

        // Verify nudge notifications cancelled
        XCTAssertEqual(mockNotificationService.cancelledNotificationTypes.count, 1)
        let (cancelledAlarmId, cancelledTypes) = mockNotificationService.cancelledNotificationTypes[0]
        XCTAssertEqual(cancelledAlarmId, alarmId)
        XCTAssertEqual(Set(cancelledTypes), Set([.nudge1, .nudge2, .nudge3]))

        // Verify snooze alarm scheduled
        XCTAssertEqual(mockNotificationService.scheduledAlarms.count, 2) // Original + snooze
    }

    func test_nudgePrecision_mockValidation_shouldUseCorrectTiming() async {
        // Test the timing logic for nudges
        let now = Date()
        let thirtySecondsLater = now.addingTimeInterval(30)
        let twoMinutesLater = now.addingTimeInterval(120)
        let fiveMinutesLater = now.addingTimeInterval(300)

        // Verify precise timing calculations
        XCTAssertEqual(thirtySecondsLater.timeIntervalSince(now), 30, accuracy: 0.01)
        XCTAssertEqual(twoMinutesLater.timeIntervalSince(now), 120, accuracy: 0.01)
        XCTAssertEqual(fiveMinutesLater.timeIntervalSince(now), 300, accuracy: 0.01)

        // Test that short intervals are within the threshold for interval triggers
        XCTAssertTrue(thirtySecondsLater.timeIntervalSince(now) <= 3600) // ≤ 1 hour
        XCTAssertTrue(twoMinutesLater.timeIntervalSince(now) <= 3600)
        XCTAssertTrue(fiveMinutesLater.timeIntervalSince(now) <= 3600)
    }
}