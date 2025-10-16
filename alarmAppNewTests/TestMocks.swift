//
//  TestMocks.swift
//  alarmAppNewTests
//
//  Created by Claude Code on 9/25/25.
//  Shared mock classes for all test targets
//

import XCTest
@testable import alarmAppNew
import UserNotifications
import Combine

// MARK: - QR Scanning Mock

final class MockQRScanning: QRScanning {
    var shouldThrowOnStart = false
    var scanResults: [String] = []
    var isScanning = false
    private var continuation: AsyncStream<String>.Continuation?

    func startScanning() async throws {
        if shouldThrowOnStart {
            throw QRScanningError.permissionDenied
        }
        isScanning = true
    }

    func stopScanning() {
        isScanning = false
        continuation?.finish()
    }

    func scanResultStream() -> AsyncStream<String> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    // Test helpers
    func simulateScan(_ payload: String) {
        continuation?.yield(payload)
    }

    func simulateError() {
        continuation?.finish()
    }
}

// MARK: - Notification Service Mock

final class MockNotificationService: AlarmScheduling {
    var cancelledAlarmIds: [UUID] = []
    var scheduledAlarms: [Alarm] = []
    var cancelledSpecificTypes: [(UUID, [NotificationType])] = []
    var cancelledNotificationTypes: [(UUID, [NotificationType])] = []
    var getRequestIdsCalls: [(UUID, String)] = []
    var cleanupAfterDismissCalls: [(UUID, String)] = []
    var cleanupStaleCallCount = 0

    func scheduleAlarm(_ alarm: Alarm) async throws {
        scheduledAlarms.append(alarm)
    }

    func cancelAlarm(_ alarm: Alarm) async {
        cancelledAlarmIds.append(alarm.id)
    }

    func cancelOccurrence(alarmId: UUID, occurrenceKey: String) async {
        // Track occurrence-specific cancellations
        cancelledAlarmIds.append(alarmId)
    }

    func getRequestIds(alarmId: UUID, occurrenceKey: String) async -> [String] {
        getRequestIdsCalls.append((alarmId, occurrenceKey))
        return []  // Override in tests as needed
    }

    func removeRequests(withIdentifiers ids: [String]) async {
        // Mock implementation
    }

    func cleanupAfterDismiss(alarmId: UUID, occurrenceKey: String) async {
        cleanupAfterDismissCalls.append((alarmId, occurrenceKey))
    }

    func cleanupStaleDeliveredNotifications() async {
        cleanupStaleCallCount += 1
    }

    func cancelSpecificNotifications(for alarmId: UUID, types: [NotificationType]) {
        cancelledSpecificTypes.append((alarmId, types))
        cancelledNotificationTypes.append((alarmId, types))
    }

    func refreshAll(from alarms: [Alarm]) async {}

    func pendingAlarmIds() async -> [UUID] {
        return []
    }

    func scheduleAlarmImmediately(_ alarm: Alarm) async throws {}

    func scheduleTestNotification(soundName: String?, in seconds: TimeInterval) async throws {}
    func scheduleTestSystemDefault() async throws {}
    func scheduleTestCriticalSound() async throws {}
    func scheduleTestCustomSound(soundName: String?) async throws {}
    func ensureNotificationCategoriesRegistered() {}
    func dumpNotificationSettings() async {}
    func validateSoundBundle() {}
    func scheduleTestDefault() async throws {}
    func scheduleTestCustom() async throws {}
    func dumpNotificationCategories() async {}
    func runCompleteSoundTriage() async throws {}
    func scheduleBareDefaultTest() async throws {}
    func scheduleBareDefaultTestNoInterruption() async throws {}
    func scheduleBareDefaultTestNoCategory() async throws {}
    func scheduleOneOffTestAlarm(leadTime: TimeInterval) async throws {}
}

// MARK: - Alarm Storage Mock

actor MockAlarmStorage: PersistenceStore {
    var storedAlarms: [Alarm] = []
    var storedRuns: [AlarmRun] = []
    var runs: [AlarmRun] = []
    var shouldThrowOnAlarmLoad = false

    func saveAlarms(_ alarms: [Alarm]) throws {}
    func loadAlarms() throws -> [Alarm] { storedAlarms }

    func saveAlarm(_ alarm: Alarm) throws {
        storedAlarms.append(alarm)
    }

    func alarm(with id: UUID) throws -> Alarm {
        if shouldThrowOnAlarmLoad {
            struct AlarmNotFoundError: Error {}
            throw AlarmNotFoundError()
        }

        guard let alarm = storedAlarms.first(where: { $0.id == id }) else {
            struct AlarmNotFoundError: Error {}
            throw AlarmNotFoundError()
        }
        return alarm
    }

    func appendRun(_ run: AlarmRun) throws {
        storedRuns.append(run)
        runs.append(run)
    }

    // MARK: - Test Helper Methods (for external actor access)

    func setStoredAlarms(_ alarms: [Alarm]) {
        storedAlarms = alarms
    }

    func getStoredAlarms() -> [Alarm] {
        storedAlarms
    }

    func setStoredRuns(_ runs: [AlarmRun]) {
        storedRuns = runs
        self.runs = runs
    }

    func getStoredRuns() -> [AlarmRun] {
        storedRuns
    }

    func setShouldThrow(_ value: Bool) {
        shouldThrowOnAlarmLoad = value
    }
}

// MARK: - Clock Mock

final class MockClock: Clock {
    private var currentTime: Date

    init(fixedNow: Date = Date()) {
        self.currentTime = fixedNow
    }

    func now() -> Date {
        currentTime
    }

    func advance(by interval: TimeInterval) {
        currentTime = currentTime.addingTimeInterval(interval)
    }

    func set(to time: Date) {
        currentTime = time
    }
}

// MARK: - App Router Mock

@MainActor
final class MockAppRouter: AppRouting {
    var backToListCallCount = 0
    var ringingCallCount = 0
    var showRingingCalls: [(UUID, UUID?)] = []

    func showRinging(for id: UUID, intentAlarmID: UUID? = nil) {
        ringingCallCount += 1
        showRingingCalls.append((id, intentAlarmID))
    }

    func backToList() {
        backToListCallCount += 1
    }
}

// MARK: - Permission Service Mock

final class MockPermissionService: PermissionServiceProtocol {
    var cameraPermissionStatus: PermissionStatus = PermissionStatus.authorized
    var requestCameraResult: PermissionStatus = PermissionStatus.authorized
    var didRequestCameraPermission = false
    var authorizationStatus: PermissionStatus = .authorized

    // Configurable notification details for testing
    var mockNotificationDetails = NotificationPermissionDetails(
        authorizationStatus: PermissionStatus.authorized,
        alertsEnabled: true,
        soundEnabled: true,
        badgeEnabled: true
    )

    func requestNotificationPermission() async throws -> PermissionStatus {
        return authorizationStatus
    }

    func checkNotificationPermission() async -> NotificationPermissionDetails {
        mockNotificationDetails.authorizationStatus = authorizationStatus
        return mockNotificationDetails
    }

    func requestCameraPermission() async -> PermissionStatus {
        didRequestCameraPermission = true
        return requestCameraResult
    }

    func checkCameraPermission() -> PermissionStatus {
        return cameraPermissionStatus
    }

    func openAppSettings() {
        // Mock implementation
    }
}

// MARK: - Reliability Logger Mock

struct MockLoggedEvent {
    let event: ReliabilityEvent
    let alarmId: UUID?
    let details: [String: String]
}

final class MockReliabilityLogger: ReliabilityLogging {
    var loggedEvents: [MockLoggedEvent] = []
    var loggedDetails: [[String: String]] = []
    var exportResult = "mock-export-data"
    var recentLogs: [ReliabilityLogEntry] = []

    func log(_ event: ReliabilityEvent, alarmId: UUID?, details: [String: String]) {
        loggedEvents.append(MockLoggedEvent(event: event, alarmId: alarmId, details: details))
        loggedDetails.append(details)
    }

    func exportLogs() -> String {
        return exportResult
    }

    func clearLogs() {
        loggedEvents.removeAll()
        loggedDetails.removeAll()
        recentLogs.removeAll()
    }

    func getRecentLogs(limit: Int) -> [ReliabilityLogEntry] {
        return Array(recentLogs.prefix(limit))
    }
}

// MARK: - Reliability Mode Provider Mock

@MainActor
final class MockReliabilityModeProvider: ReliabilityModeProvider {
    var currentMode: ReliabilityMode = .notificationsOnly
    var modePublisher: AnyPublisher<ReliabilityMode, Never> {
        Just(currentMode).eraseToAnyPublisher()
    }

    func setMode(_ mode: ReliabilityMode) {
        currentMode = mode
    }
}

// MARK: - App State Provider Mock

@MainActor
final class MockAppStateProvider: AppStateProviding {
    var mockIsAppActive: Bool = false

    var isAppActive: Bool {
        return mockIsAppActive
    }
}

// MARK: - Audio Engine Mock

final class MockAlarmAudioEngine: AlarmAudioEngineProtocol {
    var currentState: AlarmSoundEngine.State = .idle
    var shouldThrowOnSchedule = false
    var shouldThrowOnPromote = false
    var shouldThrowOnPlay = false

    var scheduledSounds: [(Date, String)] = []
    var promoteCalled = false
    var playForegroundAlarmCalls: [String] = []
    var stopCalled = false
    var scheduleWithLeadInCalls: [(Date, String, Int)] = []
    var policyProvider: (() -> AudioPolicy)?

    var isActivelyRinging: Bool {
        return currentState == .ringing
    }

    func schedulePrewarm(fireAt: Date, soundName: String) throws {
        if shouldThrowOnSchedule {
            throw AlarmAudioEngineError.playbackFailed(reason: "Mock prewarm failed")
        }
        scheduledSounds.append((fireAt, soundName))
        currentState = .prewarming
    }

    func promoteToRinging() throws {
        if shouldThrowOnPromote {
            throw AlarmAudioEngineError.playbackFailed(reason: "Mock promotion failed")
        }
        promoteCalled = true
        currentState = .ringing
    }

    func playForegroundAlarm(soundName: String) throws {
        if shouldThrowOnPlay {
            throw AlarmAudioEngineError.playbackFailed(reason: "Mock playback failed")
        }
        playForegroundAlarmCalls.append(soundName)
        currentState = .ringing
    }

    func setPolicyProvider(_ provider: @escaping () -> AudioPolicy) {
        policyProvider = provider
    }

    func scheduleWithLeadIn(fireAt: Date, soundId: String, leadInSeconds: Int) throws {
        if shouldThrowOnSchedule {
            throw AlarmAudioEngineError.playbackFailed(reason: "Mock schedule with lead-in failed")
        }
        scheduleWithLeadInCalls.append((fireAt, soundId, leadInSeconds))
        currentState = .prewarming
    }

    func stop() {
        stopCalled = true
        currentState = .idle
    }
}

// MARK: - Idle Timer Controller Mock

final class MockIdleTimerController: IdleTimerControlling {
    var isIdleTimerDisabled = false
    var setIdleTimerCalls: [Bool] = []

    func setIdleTimer(disabled: Bool) {
        isIdleTimerDisabled = disabled
        setIdleTimerCalls.append(disabled)
    }
}

// MARK: - Notification Center Mock (for ChainedScheduling tests)

final class MockNotificationCenter: UNUserNotificationCenter {
    var authorizationStatus: UNAuthorizationStatus = .authorized
    var authorizationGranted = true
    var authorizationError: Error?
    var scheduledRequests: [UNNotificationRequest] = []
    var cancelledIdentifiers: [String] = []
    var addRequestCallCount = 0

    override func notificationSettings() async -> UNNotificationSettings {
        let settings = MockUNNotificationSettings(authorizationStatus: authorizationStatus)
        return settings
    }

    override func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        if let error = authorizationError {
            throw error
        }
        return authorizationGranted
    }

    override func add(_ request: UNNotificationRequest) async throws {
        addRequestCallCount += 1
        scheduledRequests.append(request)
    }

    override func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        cancelledIdentifiers.append(contentsOf: identifiers)
    }

    override func pendingNotificationRequests() async -> [UNNotificationRequest] {
        return scheduledRequests
    }
}

final class MockUNNotificationSettings: UNNotificationSettings {
    private let _authorizationStatus: UNAuthorizationStatus

    init(authorizationStatus: UNAuthorizationStatus) {
        self._authorizationStatus = authorizationStatus
        super.init()
    }

    override var authorizationStatus: UNAuthorizationStatus {
        return _authorizationStatus
    }
}

// MARK: - Sound Catalog Mock

final class MockSoundCatalog: SoundCatalogProviding {
    var soundInfo: SoundInfo?

    func safeInfo(for soundId: String) -> SoundInfo? {
        return soundInfo
    }
}

// MARK: - Global Limit Guard Mock

final class MockGlobalLimitGuard: GlobalLimitGuard {
    var reserveReturnValue: Int = 0
    var reserveCallCount = 0
    var finalizeCallCount = 0

    override func reserve(_ count: Int) async -> Int {
        reserveCallCount += 1
        return reserveReturnValue
    }

    override func finalize(_ actualScheduled: Int) {
        finalizeCallCount += 1
    }
}

// MARK: - Chained Scheduler Mock

final class MockChainedScheduler: ChainedNotificationScheduling {
    var storedIdentifiers: [UUID: [String]] = [:]

    func getIdentifiers(alarmId: UUID) -> [String] {
        return storedIdentifiers[alarmId] ?? []
    }

    // Stub implementations for required protocol methods
    func scheduleChain(for alarm: Alarm, fireDate: Date) async -> ScheduleOutcome {
        return ScheduleOutcome(requested: 0, scheduled: 0, failureReasons: [])
    }

    func cancelChain(alarmId: UUID) async {}
    func cancelOccurrence(alarmId: UUID, occurrenceKey: String) async {}
    func requestAuthorization() async throws {}
    func cleanupStaleChains() async {}
}

// MARK: - Settings Service Mock

final class MockSettingsService: SettingsServiceProtocol {
    var useChainedScheduling: Bool = false
    var audioPolicy: AudioPolicy = AudioPolicy(capability: .foregroundAssist, allowRouteOverrideAtAlarm: true)
    var reliabilityMode: ReliabilityMode = .notificationsOnly

    func setUseChainedScheduling(_ value: Bool) {
        useChainedScheduling = value
    }

    func setAudioPolicy(_ policy: AudioPolicy) {
        audioPolicy = policy
    }

    func setReliabilityMode(_ mode: ReliabilityMode) {
        reliabilityMode = mode
    }
}

// MARK: - System Volume Provider Mock

final class MockSystemVolumeProvider: SystemVolumeProviding {
    var mockVolume: Float = 0.5

    func currentMediaVolume() -> Float {
        return mockVolume
    }
}

// MARK: - Mock Alarm Factory

final class MockAlarmFactory: AlarmFactory {
    func makeNewAlarm() -> Alarm {
        Alarm(
            id: UUID(),
            time: Date().addingTimeInterval(3600),
            label: "Test Alarm",
            repeatDays: [],
            challengeKind: [],
            expectedQR: nil,
            stepThreshold: nil,
            mathChallenge: nil,
            isEnabled: true,
            soundId: "ringtone1",
            soundName: nil,
            volume: 0.8,
            externalAlarmId: nil
        )
    }
}

// MARK: - Mock Dismissed Registry (removed - DismissedRegistry is final)
// Use the real DismissedRegistry in tests or create a protocol-based mock if needed

// MARK: - AlarmScheduling Mock (Consolidated)

/// Shared test double for AlarmScheduling used across all tests.
/// Keep this in sync with the AlarmScheduling protocol.
public final class AlarmSchedulingMock: AlarmScheduling {

    // MARK: - Configurable behavior for tests
    public var shouldThrowOnRequestAuth = false
    public var shouldThrowOnSchedule = false
    public var shouldThrowOnStop = false
    public var shouldThrowOnSnooze = false

    // MARK: - Captured / observable state
    public private(set) var requestedAuthorizationCount = 0
    public private(set) var scheduledAlarms: [UUID: Alarm] = [:]
    public private(set) var canceledAlarmIds: [UUID] = []
    public private(set) var stoppedAlarmCalls: [(alarmId: UUID, intentAlarmId: UUID?)] = []
    public private(set) var countdownCalls: [(alarmId: UUID, duration: TimeInterval)] = []
    public private(set) var reconcileCalls: [(alarms: [Alarm], skipIfRinging: Bool)] = []

    /// Stub return for pending IDs; set in tests as needed.
    public var pendingIdsStub: [UUID] = []

    // MARK: - Backward compatibility aliases

    /// Backward-compatible alias for stoppedAlarmCalls
    public var stopCalls: [UUID] {
        stoppedAlarmCalls.map { $0.alarmId }
    }

    /// Backward-compatible alias for countdownCalls
    public var transitionToCountdownCalls: [(UUID, TimeInterval)] {
        countdownCalls
    }

    /// Backward-compatible alias for shouldThrowOnSnooze
    public var shouldThrowOnTransition: Bool {
        get { shouldThrowOnSnooze }
        set { shouldThrowOnSnooze = newValue }
    }

    public init() {}

    // MARK: - AlarmScheduling

    public func requestAuthorizationIfNeeded() async throws {
        requestedAuthorizationCount += 1
        if shouldThrowOnRequestAuth { throw TestError.forced }
    }

    public func schedule(alarm: Alarm) async throws -> String {
        if shouldThrowOnSchedule { throw TestError.forced }
        scheduledAlarms[alarm.id] = alarm
        return "mock-\(alarm.id.uuidString)"
    }

    public func cancel(alarmId: UUID) async {
        canceledAlarmIds.append(alarmId)
        scheduledAlarms.removeValue(forKey: alarmId)
    }

    public func pendingAlarmIds() async -> [UUID] {
        pendingIdsStub
    }

    public func stop(alarmId: UUID, intentAlarmId: UUID?) async throws {
        if shouldThrowOnStop { throw TestError.forced }
        stoppedAlarmCalls.append((alarmId, intentAlarmId))
    }

    public func transitionToCountdown(alarmId: UUID, duration: TimeInterval) async throws {
        if shouldThrowOnSnooze { throw TestError.forced }
        countdownCalls.append((alarmId, duration))
    }

    public func reconcile(alarms: [Alarm], skipIfRinging: Bool) async {
        reconcileCalls.append((alarms, skipIfRinging))
    }

    // MARK: - Test helpers

    public func reset() {
        shouldThrowOnRequestAuth = false
        shouldThrowOnSchedule = false
        shouldThrowOnStop = false
        shouldThrowOnSnooze = false

        requestedAuthorizationCount = 0
        scheduledAlarms = [:]
        canceledAlarmIds = []
        stoppedAlarmCalls = []
        countdownCalls = []
        reconcileCalls = []
        pendingIdsStub = []
    }

    public enum TestError: Error { case forced }
}

/// Back-compat so existing tests using `MockAlarmScheduling` keep compiling.
public typealias MockAlarmScheduling = AlarmSchedulingMock