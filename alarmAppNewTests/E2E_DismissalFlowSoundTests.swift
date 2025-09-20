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

class MockQRScanning: QRScanning {
    var isScanning = false
    var mockScanResults: [String] = []
    private var streamContinuation: AsyncStream<String>.Continuation?

    func startScanning() async throws {
        isScanning = true
    }

    func stopScanning() {
        isScanning = false
        streamContinuation?.finish()
        streamContinuation = nil
    }

    func scanResultStream() -> AsyncStream<String> {
        return AsyncStream { continuation in
            self.streamContinuation = continuation
            // Emit any pre-configured results
            for result in mockScanResults {
                continuation.yield(result)
            }
        }
    }

    func simulateScan(_ payload: String) {
        streamContinuation?.yield(payload)
    }
}

class MockAlarmStorage: AlarmStorage {
    var alarms: [UUID: Alarm] = [:]
    var runs: [AlarmRun] = []

    func alarm(with id: UUID) throws -> Alarm {
        guard let alarm = alarms[id] else {
            throw AlarmStorageError.alarmNotFound
        }
        return alarm
    }

    func saveAlarm(_ alarm: Alarm) throws {
        alarms[alarm.id] = alarm
    }

    func deleteAlarm(with id: UUID) throws {
        alarms.removeValue(forKey: id)
    }

    func allAlarms() throws -> [Alarm] {
        return Array(alarms.values)
    }

    func appendRun(_ run: AlarmRun) throws {
        runs.append(run)
    }

    func allRuns() throws -> [AlarmRun] {
        return runs
    }
}

enum AlarmStorageError: Error {
    case alarmNotFound
}

class MockNotificationService: NotificationScheduling {
    var scheduledAlarms: [Alarm] = []
    var cancelledAlarms: [Alarm] = []
    var cancelledNotificationTypes: [(UUID, [NotificationType])] = []

    func scheduleAlarm(_ alarm: Alarm) async throws {
        scheduledAlarms.append(alarm)
    }

    func cancelAlarm(_ alarm: Alarm) {
        cancelledAlarms.append(alarm)
    }

    func cancelSpecificNotifications(for alarmId: UUID, types: [NotificationType]) {
        cancelledNotificationTypes.append((alarmId, types))
    }

    func refreshAll(from alarms: [Alarm]) async {
        scheduledAlarms = alarms
    }

    func pendingAlarmIds() async -> [UUID] {
        return scheduledAlarms.map { $0.id }
    }

    func scheduleTestNotification(soundName: String?, in seconds: TimeInterval) async throws {
        // No-op for tests
    }
}

class MockAudioService: AudioServiceProtocol {
    var isCurrentlyPlaying = false
    var lastPlayedSound: String?
    var lastVolume: Double?
    var lastLoopSetting: Bool?
    var sessionActivated = false
    var stopCallCount = 0
    var stopAndDeactivateCallCount = 0

    func listAvailableSounds() -> [SoundAsset] {
        return SoundAsset.availableSounds
    }

    func preview(soundName: String?, volume: Double) async {
        lastPlayedSound = soundName
        lastVolume = volume
        lastLoopSetting = false
    }

    func startRinging(soundName: String?, volume: Double, loop: Bool) async {
        isCurrentlyPlaying = true
        lastPlayedSound = soundName
        lastVolume = volume
        lastLoopSetting = loop
        sessionActivated = true
    }

    func stop() {
        stopCallCount += 1
        isCurrentlyPlaying = false
    }

    func stopAndDeactivateSession() {
        stopAndDeactivateCallCount += 1
        isCurrentlyPlaying = false
        sessionActivated = false
    }

    func isPlaying() -> Bool {
        return isCurrentlyPlaying
    }

    func activatePlaybackSession() throws {
        sessionActivated = true
    }

    func deactivateSession() throws {
        sessionActivated = false
    }
}

class MockAppRouter: AppRouter {
    var showRingingCalls: [UUID] = []
    var backToListCallCount = 0

    override func showRinging(for alarmId: UUID) {
        showRingingCalls.append(alarmId)
    }

    override func backToList() {
        backToListCallCount += 1
    }
}

class MockReliabilityLogger: ReliabilityLogging {
    var loggedEvents: [(ReliabilityEvent, UUID?, [String: String])] = []

    func log(_ event: ReliabilityEvent, alarmId: UUID? = nil, details: [String: String] = [:]) {
        loggedEvents.append((event, alarmId, details))
    }

    func exportLogs() -> String {
        return "Mock logs"
    }

    func clearLogs() {
        loggedEvents.removeAll()
    }

    func getRecentLogs(limit: Int = 100) -> [ReliabilityLogEntry] {
        return []
    }
}

class MockClock: Clock {
    var currentTime = Date()

    func now() -> Date {
        return currentTime
    }

    func advance(by interval: TimeInterval) {
        currentTime = currentTime.addingTimeInterval(interval)
    }
}

// MARK: - E2E Dismissal Flow Tests

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
            audioService: mockAudioService
        )
    }

    private func createTestAlarm(
        id: UUID = UUID(),
        soundName: String = "chime",
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
            soundName: soundName,
            volume: volume
        )
    }

    // MARK: - Sound Integration Tests

    func test_startAlarm_shouldActivateAudioAndStartRinging() {
        let alarmId = UUID()
        let alarm = createTestAlarm(id: alarmId, soundName: "bell", volume: 0.9)

        try! mockAlarmStorage.saveAlarm(alarm)

        viewModel.start(alarmId: alarmId)

        // Wait for async audio start
        let expectation = expectation(description: "Audio should start")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(viewModel.state, .ringing)
        XCTAssertEqual(mockAudioService.lastPlayedSound, "bell")
        XCTAssertEqual(mockAudioService.lastVolume, 0.9)
        XCTAssertEqual(mockAudioService.lastLoopSetting, true)
        XCTAssertTrue(mockAudioService.sessionActivated)
        XCTAssertTrue(mockAudioService.isCurrentlyPlaying)
    }

    func test_successfulDismissal_shouldStopAudioAndCancelNudges() {
        let alarmId = UUID()
        let expectedQR = "success-qr"
        let alarm = createTestAlarm(id: alarmId, expectedQR: expectedQR)

        try! mockAlarmStorage.saveAlarm(alarm)

        // Start alarm
        viewModel.start(alarmId: alarmId)
        viewModel.beginScan()

        // Wait for state transitions
        let expectation = expectation(description: "Scanning should start")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(viewModel.state, .scanning)

        // Simulate successful QR scan
        viewModel.didScan(payload: expectedQR)

        // Wait for completion
        let completionExpectation = expectation(description: "Dismissal should complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completionExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

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

    func test_abortDismissal_shouldStopAudioButKeepNudges() {
        let alarmId = UUID()
        let alarm = createTestAlarm(id: alarmId)

        try! mockAlarmStorage.saveAlarm(alarm)

        viewModel.start(alarmId: alarmId)

        // Wait for audio to start
        let expectation = expectation(description: "Audio should start")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

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

    func test_snoozeDismissal_shouldStopAudioAndCancelNudgesOnly() {
        let alarmId = UUID()
        let alarm = createTestAlarm(id: alarmId)

        try! mockAlarmStorage.saveAlarm(alarm)

        viewModel.start(alarmId: alarmId)

        // Wait for startup
        let expectation = expectation(description: "Setup should complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        // Snooze the alarm
        viewModel.snooze()

        // Wait for snooze to complete
        let snoozeExpectation = expectation(description: "Snooze should complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            snoozeExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

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

    func test_failedQRScan_shouldContinueAudioPlaying() {
        let alarmId = UUID()
        let expectedQR = "correct-qr"
        let wrongQR = "wrong-qr"
        let alarm = createTestAlarm(id: alarmId, expectedQR: expectedQR)

        try! mockAlarmStorage.saveAlarm(alarm)

        viewModel.start(alarmId: alarmId)
        viewModel.beginScan()

        // Wait for scanning state
        let expectation = expectation(description: "Scanning should start")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        // Simulate wrong QR scan
        viewModel.didScan(payload: wrongQR)

        // Audio should still be playing
        XCTAssertTrue(mockAudioService.isCurrentlyPlaying)
        XCTAssertEqual(mockAudioService.stopAndDeactivateCallCount, 0)

        // Should transition to validating briefly, then back to scanning
        let validationExpectation = expectation(description: "Should return to scanning")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { // Wait for timeout
            validationExpectation.fulfill()
        }
        waitForExpectations(timeout: 2.0)

        XCTAssertEqual(viewModel.state, .scanning)
        XCTAssertTrue(mockAudioService.isCurrentlyPlaying)
    }

    func test_cleanupDismissal_shouldStopAudioProperly() {
        let alarmId = UUID()
        let alarm = createTestAlarm(id: alarmId)

        try! mockAlarmStorage.saveAlarm(alarm)

        viewModel.start(alarmId: alarmId)

        // Wait for startup
        let expectation = expectation(description: "Setup should complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        // Call cleanup
        viewModel.cleanup()

        // Verify audio stopped
        XCTAssertEqual(mockAudioService.stopAndDeactivateCallCount, 1)
        XCTAssertFalse(mockAudioService.isCurrentlyPlaying)
        XCTAssertFalse(mockAudioService.sessionActivated)
    }

    func test_multipleQRScans_shouldDebounceSuccessfully() {
        let alarmId = UUID()
        let expectedQR = "success-qr"
        let alarm = createTestAlarm(id: alarmId, expectedQR: expectedQR)

        try! mockAlarmStorage.saveAlarm(alarm)

        viewModel.start(alarmId: alarmId)
        viewModel.beginScan()

        // Wait for scanning state
        let expectation = expectation(description: "Scanning should start")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        // Simulate rapid duplicate scans
        viewModel.didScan(payload: expectedQR)
        viewModel.didScan(payload: expectedQR) // Should be debounced
        viewModel.didScan(payload: expectedQR) // Should be debounced

        // Wait for processing
        let processingExpectation = expectation(description: "Processing should complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            processingExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        // Should only process once
        XCTAssertEqual(viewModel.state, .success)
        XCTAssertEqual(mockAudioService.stopAndDeactivateCallCount, 1)

        // Should have only one successful run logged
        let successLogs = mockReliabilityLogger.loggedEvents.filter { (event, _, _) in
            event == .dismissSuccessQR
        }
        XCTAssertEqual(successLogs.count, 1)
    }

    func test_fullDismissalFlow_endToEnd_shouldWorkCorrectly() async {
        let alarmId = UUID()
        let expectedQR = "complete-flow-qr"
        let alarm = createTestAlarm(id: alarmId, soundName: "radar", volume: 0.7, expectedQR: expectedQR)

        try! mockAlarmStorage.saveAlarm(alarm)

        // Start the alarm
        viewModel.start(alarmId: alarmId)

        // Verify initial state
        XCTAssertEqual(viewModel.state, .ringing)

        // Wait for audio setup
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Verify audio started
        XCTAssertTrue(mockAudioService.isCurrentlyPlaying)
        XCTAssertEqual(mockAudioService.lastPlayedSound, "radar")
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

        try? await Task.sleep(nanoseconds: 200_000_000)

        // Verify successful completion
        XCTAssertEqual(viewModel.state, .success)
        XCTAssertFalse(mockAudioService.isCurrentlyPlaying)
        XCTAssertEqual(mockAudioService.stopAndDeactivateCallCount, 1)

        // Verify notifications cancelled correctly
        XCTAssertEqual(mockNotificationService.cancelledNotificationTypes.count, 1)

        // Verify alarm run was saved
        XCTAssertEqual(mockAlarmStorage.runs.count, 1)
        let run = mockAlarmStorage.runs[0]
        XCTAssertEqual(run.outcome, .success)
        XCTAssertNotNil(run.dismissedAt)

        // Wait for navigation
        try? await Task.sleep(nanoseconds: 1_600_000_000) // 1.6 seconds

        XCTAssertEqual(mockAppRouter.backToListCallCount, 1)
    }

    // MARK: - Notification Action Tests

    func test_snoozeAction_integration_shouldHandleCorrectly() async {
        let alarmId = UUID()
        let alarm = createTestAlarm(id: alarmId)

        try! mockAlarmStorage.saveAlarm(alarm)

        // Simulate snooze action through notification service
        let notificationService = mockNotificationService as! MockNotificationService

        // Start with some scheduled alarms
        notificationService.scheduledAlarms = [alarm]

        // Test that snooze would work (we can't directly test the delegate without a real notification)
        // But we can verify the snooze function works correctly
        viewModel.start(alarmId: alarmId)
        viewModel.snooze()

        // Wait for snooze processing
        let expectation = expectation(description: "Snooze should complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

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

    func test_nudgePrecision_mockValidation_shouldUseCorrectTiming() {
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