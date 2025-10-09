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

final class MockNotificationService: NotificationScheduling {
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

final class MockAlarmStorage: AlarmStorage {
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
            throw AlarmStorageError.alarmNotFound
        }

        guard let alarm = storedAlarms.first(where: { $0.id == id }) else {
            throw AlarmStorageError.alarmNotFound
        }
        return alarm
    }

    func appendRun(_ run: AlarmRun) throws {
        storedRuns.append(run)
        runs.append(run)
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
    var dismissalCallCount = 0
    var ringingCallCount = 0
    var showRingingCalls: [UUID] = []

    func showDismissal(for id: UUID) {
        dismissalCallCount += 1
    }

    func showRinging(for id: UUID) {
        ringingCallCount += 1
        showRingingCalls.append(id)
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
            throw MockAudioError.prewarmFailed
        }
        scheduledSounds.append((fireAt, soundName))
        currentState = .prewarming
    }

    func promoteToRinging() throws {
        if shouldThrowOnPromote {
            throw MockAudioError.promotionFailed
        }
        promoteCalled = true
        currentState = .ringing
    }

    func playForegroundAlarm(soundName: String) throws {
        if shouldThrowOnPlay {
            throw MockAudioError.playbackFailed
        }
        playForegroundAlarmCalls.append(soundName)
        currentState = .ringing
    }

    func setPolicyProvider(_ provider: @escaping () -> AudioPolicy) {
        policyProvider = provider
    }

    func scheduleWithLeadIn(fireAt: Date, soundId: String, leadInSeconds: Int) throws {
        if shouldThrowOnSchedule {
            throw MockAudioError.prewarmFailed
        }
        scheduleWithLeadInCalls.append((fireAt, soundId, leadInSeconds))
        currentState = .prewarming
    }

    func stop() {
        stopCalled = true
        currentState = .idle
    }
}

// MARK: - Audio Service Mock

final class MockAudioService: AudioServiceProtocol {
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

// MARK: - Mock Error Types

enum MockAudioError: Error {
    case prewarmFailed
    case promotionFailed
    case playbackFailed
}